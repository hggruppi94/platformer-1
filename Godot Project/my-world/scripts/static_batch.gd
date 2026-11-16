extends RefCounted

# Static batching (15 Nov 2026, the detailed props pipeline; Hayden: "How do AAA games have such detailed assets that
# dont slow down my pc?"). The builders make every house, shop and fence out of lots of little boxes, cylinders and
# balls, each its own MeshInstance3D. The graphics card is asked to draw each one separately (and again for every
# shadow split), so Stars Hollow asked for about 4,500 draws a frame, and that, not the number of triangles, is what
# slows a PC down. Big games merge pieces that never move into one mesh per material ("static batching"), which is
# what this does at load time, without touching a built scene.
#
# The approach follows what we read in open-source Godot work (godotengine/godot-benchmarks measures draw calls this
# way; the MultiMesh scatter add-ons such as arcaneenergy/godot-multimesh-scatter batch copies of one mesh) and the
# engines' own docs: draw calls first, then triangles.
#
# How it stays safe for the rest of the game:
#   - Only pieces nobody can find by name are merged: a builder's unnamed MeshInstance3D ("@MeshInstance3D@12"). Code
#     and tests look things up by name, so anything with a real name is left exactly as it is.
#   - Nothing under a node with a script (quest_show, seasons, doors, people, rides...), a body that moves, or in a
#     group, and nothing with metas, a skeleton, see-through materials or its own children.
#   - Siblings are merged into one mesh under their own parent, so hiding or moving a parent (a house, a season's
#     dressing) still hides or moves its merged mesh.
#   - The pieces themselves stay in the tree, visible, with their collision and materials. They're only taken out of
#     drawing (render layers 0), so paint, rays, "what's this made of" (Surfaces) and tests see them as before.
#   - Small merged pieces fade out far away (visibility ranges), like a game's level of detail.

const MERGED_META := "static_batch"
const MIN_PIECES := 2                   # a parent needs at least this many pieces to be worth merging
const SMALL_R := 2.5                    # a merged mesh this small (bounding radius, m) fades out at...
const SMALL_END := 70.0                 # ...this distance
const MID_R := 6.0                      # and one this small at...
const MID_END := 140.0
const PEOPLE_END := 90.0               # townsfolk aren't drawn past this (m)
const FADE := 8.0                       # metres of fade at the end (dithered, no pop)
const BODY_OK := ["Node3D", "StaticBody3D", "Area3D", "Marker3D"]
# Scripts that never touch the pieces under them (a map name, the lake's wading), so what's under them can be merged
const SAFE_SCRIPTS := ["res://scripts/landmark.gd", "res://scripts/water.gd"]
const SAFE_GROUPS := [&"map_landmarks", &"water"]
const WATCH := preload("res://scripts/batch_watch.gd")


static func batch(scene: Node) -> Dictionary:
	# Merges what it can in the scene. Returns counts (tests and the frame budget check read them).
	var sky := scene.get_node_or_null("Sky")
	var by_parent := {}
	var allowed := {}                   # node -> bool, so each ancestor chain is checked once
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		# The sky's clouds and stars are see-through, but so far off that the order they're drawn in can't show
		if not _piece_ok(mi, sky != null and sky.is_ancestor_of(mi)):
			continue
		var p := mi.get_parent()
		if not _chain_ok(p, scene, allowed):
			continue
		if not by_parent.has(p):
			by_parent[p] = []
		by_parent[p].append(mi)
	var merged := 0
	var pieces := 0
	var watch := WATCH.on(scene)
	for p: Node3D in by_parent:
		var list: Array = by_parent[p]
		if list.size() < MIN_PIECES:
			continue
		var made := _merge(p, list)
		if not made.is_empty():
			merged += made.size()
			pieces += list.size()
			watch.add(p, list, made)
	var faded := far_fade(scene.get_node_or_null("Characters"), PEOPLE_END)
	return {"meshes": merged, "pieces": pieces, "people_faded": faded}


static func far_fade(root: Node, end: float) -> int:
	# Townsfolk far off are a few pixels high: like a big game's crowd, they stop being drawn past "end" metres (with
	# a short dithered fade). Only how they're drawn changes: they still walk, talk and are found by name.
	if root == null:
		return 0
	var n := 0
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if g.visibility_range_end > 0.0 or g is Label3D:
			continue
		g.visibility_range_end = end
		g.visibility_range_end_margin = FADE
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		n += 1
	return n


static func _piece_ok(mi: MeshInstance3D, see_through_ok := false) -> bool:
	if mi.mesh == null or mi.get_script() != null or mi.get_child_count() > 0:
		return false
	var n := String(mi.name)
	if not (n.begins_with("@") or n.begins_with("MeshInstance3D")):
		return false
	if not mi.get_groups().is_empty() or not mi.get_meta_list().is_empty():
		return false
	if not mi.visible or mi.layers != 1 or mi.skin != null:
		return false
	if (mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).get_blend_shape_count() > 0) or mi.visibility_range_end > 0.0:
		return false
	if mi.mesh is ArrayMesh and mi.mesh.get_surface_count() == 0:
		return false
	for s in mi.mesh.get_surface_count():
		var m := _material(mi, s)
		if m == null or (_see_through(m) and not (see_through_ok and m is BaseMaterial3D)):
			return false
	return true


static func _chain_ok(p: Node, scene: Node, allowed: Dictionary) -> bool:
	if allowed.has(p):
		return allowed[p]
	var ok := true
	if p == scene:
		ok = true
	elif p == null or not (p is Node3D):
		ok = false
	elif p.get_script() != null and not ((p.get_script() as Script).resource_path in SAFE_SCRIPTS):
		ok = false
	elif not _groups_ok(p):
		ok = false
	elif not (p.get_class() in BODY_OK):
		ok = false
	elif p.has_meta("model_source") or p.has_meta("no_batch"):
		ok = false
	else:
		ok = _chain_ok(p.get_parent(), scene, allowed)
	allowed[p] = ok
	return ok


static func _groups_ok(p: Node) -> bool:
	for g in p.get_groups():
		if not (g in SAFE_GROUPS) and not String(g).begins_with("_"):
			return false
	return true


static func _material(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override:
		return mi.material_override
	var m := mi.get_surface_override_material(s)
	if m:
		return m
	return mi.mesh.surface_get_material(s)


static func _see_through(m: Material) -> bool:
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or b.albedo_color.a < 1.0
	return m is ShaderMaterial          # a shader can do anything (time, vertex moves): leave it alone


static func _merge(p: Node3D, list: Array) -> Array:
	# One SurfaceTool per (material, shadow setting), every piece added in the parent's own space.
	var tools := {}
	var inv := p.global_transform.affine_inverse() if p.is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in list:
		var xf := inv * mi.global_transform
		for s in mi.mesh.get_surface_count():
			if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var key := [_material(mi, s), mi.cast_shadow]
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = st
			(tools[key] as SurfaceTool).append_from(mi.mesh, s, xf)
		mi.layers = 0                    # still there for rays, paint and tests, just not drawn
		mi.set_meta(MERGED_META, true)
	var made: Array = []
	for key in tools:
		var st := tools[key] as SurfaceTool
		var mesh := st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var out := MeshInstance3D.new()
		out.name = "Batched %d" % made.size()
		out.mesh = mesh
		out.material_override = key[0]
		out.cast_shadow = key[1]
		out.set_meta(MERGED_META, true)
		var r := mesh.get_aabb().size.length() * 0.5
		if r < SMALL_R:
			out.visibility_range_end = SMALL_END
		elif r < MID_R:
			out.visibility_range_end = MID_END
		if out.visibility_range_end > 0.0:
			out.visibility_range_end_margin = FADE
			out.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		p.add_child(out)
		made.append(out)
	return made
