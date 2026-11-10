extends RefCounted

# Cuts a round hole straight down through whatever ground is under a spot, at play time, so something can be sunk
# into it (the deep pools in scripts/sunken_secrets.gd). Nothing in a builder or a scene changes: the grounds are
# copied and the copies are cut.
#   - A ground made of triangles (the Void's terrain: a grid mesh and its trimesh collision) loses every triangle that
#     touches the hole. The grid's triangles are 2 m across, so the hole's edge is jagged: `cut()` says how far out
#     it reached, and the caller covers that with a rim.
#   - A round slab (the portal worlds' floors: a CylinderMesh and a CylinderShape3D) is made again with a neat round
#     hole in its top and bottom. Shard Isle's rock cone under its top gets a hole in its top too, and where its
#     sloping side passes through the hole the side is pushed out round it, so it never shows inside the pool.
#   - Small things lying in the hole (flower patches, a root, an eyeplant, crystals hanging under Shard Isle, the Void's
#     foliage) are hidden.
# No class_name on purpose (see scripts/use_spot.gd): load it with preload.

const SEGS := 64                     # round the hole
const RINGS := 10                    # from the hole out to a slab's edge, so no triangle is too long and thin
const BIG := 25.0                    # anything wider than this is ground, never a little thing to hide


# Cut a hole of radius `r` round `centre` (x, z) through ground lying between `bottom` and `top` (world heights).
# Returns how far out from the centre the ground was taken away (at least `r`).
static func cut(scene: Node, centre: Vector2, r: float, bottom: float, top: float) -> float:
	var reach := r
	var touched := {}
	for n in scene.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape == null or not _upright(cs.global_transform) or _skip(cs):
			continue
		var h := _local(cs.global_transform, centre)
		var lo := bottom - cs.global_position.y
		var hi := top - cs.global_position.y
		if cs.shape is ConcavePolygonShape3D:
			var res := _cut_faces((cs.shape as ConcavePolygonShape3D).get_faces(), h, r, lo, hi)
			if res.removed:
				var s := ConcavePolygonShape3D.new()
				s.backface_collision = (cs.shape as ConcavePolygonShape3D).backface_collision
				s.set_faces(res.faces)
				cs.shape = s
				reach = maxf(reach, res.reach)
				touched[cs] = true
		elif cs.shape is CylinderShape3D:
			var c := cs.shape as CylinderShape3D
			if h.length() + r < c.radius - 0.2 and -c.height * 0.5 < hi and c.height * 0.5 > lo:
				var tris := _slab(c.radius, c.radius, c.height, h, r, true, true, lo, hi)
				var s := ConcavePolygonShape3D.new()
				s.backface_collision = true
				var faces := PackedVector3Array()
				for v in tris:
					faces.append(v.p)
				s.set_faces(faces)
				cs.shape = s
				touched[cs] = true
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not _upright(mi.global_transform) or _skip(mi):
			continue
		var h := _local(mi.global_transform, centre)
		var lo := bottom - mi.global_position.y
		var hi := top - mi.global_position.y
		if mi.mesh is CylinderMesh:
			var c := mi.mesh as CylinderMesh
			if maxf(c.top_radius, c.bottom_radius) * 2.0 < BIG:
				continue
			var cut_top := c.height * 0.5 > lo - 0.1 and c.height * 0.5 < hi + 0.1 and h.length() + r < c.top_radius - 0.2
			var cut_bottom := -c.height * 0.5 > lo - 0.1 and -c.height * 0.5 < hi + 0.1 and h.length() + r < c.bottom_radius - 0.2
			if not cut_top and not cut_bottom and not _side_crosses(c, h, r, lo, hi):
				continue
			var tris := _slab(c.top_radius, c.bottom_radius, c.height, h, r, cut_top, cut_bottom, lo, hi)
			var mat := c.material
			mi.mesh = _mesh_of(tris)
			if mat:
				mi.mesh.surface_set_material(0, mat)
			touched[mi] = true
		elif mi.mesh is ArrayMesh:
			var am := mi.mesh as ArrayMesh
			var bb := mi.global_transform * am.get_aabb()
			if bb.size.x < BIG and bb.size.z < BIG:
				continue
			if centre.x < bb.position.x or centre.x > bb.end.x or centre.y < bb.position.z or centre.y > bb.end.z:
				continue
			var made := ArrayMesh.new()
			var any := false
			for i in am.get_surface_count():
				var arrays := am.surface_get_arrays(i)
				if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_INDEX] == null:
					any = false                       # (a headless run keeps no mesh data: nothing to show anyway)
					break
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var kept := PackedInt32Array()
				for t in range(0, index.size(), 3):
					var a := verts[index[t]]
					var b := verts[index[t + 1]]
					var cc := verts[index[t + 2]]
					if _touches(a, b, cc, h, r, lo, hi):
						any = true
						for v in [a, b, cc]:
							reach = maxf(reach, Vector2(v.x, v.z).distance_to(h))
					else:
						kept.append_array([index[t], index[t + 1], index[t + 2]])
				arrays[Mesh.ARRAY_INDEX] = kept
				made.add_surface_from_arrays(am.surface_get_primitive_type(i), arrays)
				made.surface_set_material(i, am.surface_get_material(i))
			if any:
				mi.mesh = made
				touched[mi] = true
	# Little things lying in the hole
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if touched.has(gi) or not gi.is_visible_in_tree() or _skip(gi):
			continue
		var bb := gi.global_transform * gi.get_aabb()
		if gi is MultiMeshInstance3D and (bb.size.x > BIG or bb.size.z > BIG):
			_clear_instances(gi as MultiMeshInstance3D, centre, r, bottom, top)
			continue
		if bb.size.x > BIG or bb.size.z > BIG or bb.end.y < bottom - 0.5 or bb.position.y > top + 1.5:
			continue
		var near := Vector2(clampf(centre.x, bb.position.x, bb.end.x), clampf(centre.y, bb.position.z, bb.end.z))
		if near.distance_to(centre) < r:
			gi.visible = false
	return reach


static func _clear_instances(mmi: MultiMeshInstance3D, centre: Vector2, r: float, bottom: float, top: float) -> void:
	# A big field of little things (the Void's foliage): shrink away just the ones standing in the hole, on a copy
	var mm := mmi.multimesh
	if mm == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
		return
	var copy: MultiMesh = null
	for i in mm.instance_count:
		var p := mmi.global_transform * mm.get_instance_transform(i).origin
		if p.y < bottom - 0.5 or p.y > top + 1.5 or Vector2(p.x, p.z).distance_to(centre) > r + 0.6:
			continue
		if copy == null:
			copy = mm.duplicate()
			mmi.multimesh = copy
		copy.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), mm.get_instance_transform(i).origin))


static func _skip(n: Node) -> bool:
	# Never anyone's body, or what they carry
	var p := n
	while p:
		if p is CharacterBody3D or p.is_in_group("player"):
			return true
		p = p.get_parent()
	return false


static func _upright(t: Transform3D) -> bool:
	return t.basis.y.normalized().is_equal_approx(Vector3.UP) and is_equal_approx(t.basis.get_scale().x, 1.0)


static func _local(t: Transform3D, centre: Vector2) -> Vector2:
	var p := t.affine_inverse() * Vector3(centre.x, t.origin.y, centre.y)
	return Vector2(p.x, p.z)


static func _touches(a: Vector3, b: Vector3, c: Vector3, h: Vector2, r: float, lo: float, hi: float) -> bool:
	# Does this triangle reach into the hole (in plan) somewhere between lo and hi?
	if maxf(a.y, maxf(b.y, c.y)) < lo or minf(a.y, minf(b.y, c.y)) > hi:
		return false
	var p := [Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)]
	for i in 3:
		var e0: Vector2 = p[i]
		var e1: Vector2 = p[(i + 1) % 3]
		var k := 0.0 if e0 == e1 else clampf((h - e0).dot(e1 - e0) / (e1 - e0).length_squared(), 0.0, 1.0)
		if h.distance_to(e0.lerp(e1, k)) < r:
			return true
	return Geometry2D.point_is_inside_triangle(h, p[0], p[1], p[2])


static func _cut_faces(faces: PackedVector3Array, h: Vector2, r: float, lo: float, hi: float) -> Dictionary:
	var kept := PackedVector3Array()
	var removed := false
	var reach := r
	for t in range(0, faces.size(), 3):
		if _touches(faces[t], faces[t + 1], faces[t + 2], h, r, lo, hi):
			removed = true
			for k in 3:
				reach = maxf(reach, Vector2(faces[t + k].x, faces[t + k].z).distance_to(h))
		else:
			kept.append_array([faces[t], faces[t + 1], faces[t + 2]])
	return {"faces": kept, "removed": removed, "reach": reach}


static func _side_crosses(c: CylinderMesh, h: Vector2, r: float, lo: float, hi: float) -> bool:
	# Does the slab's (or cone's) side pass through the hole anywhere between lo and hi?
	var d := h.length()
	for k in 11:
		var y := lerpf(-c.height * 0.5, c.height * 0.5, k / 10.0)
		if y < lo or y > hi:
			continue
		var rho := lerpf(c.bottom_radius, c.top_radius, k / 10.0)
		if absf(rho - d) < r:
			return true
	return false


# -----------------------------------------------------------------------------
# A round slab (or cone) with a round hole: its triangles, each vertex {p, n}
# -----------------------------------------------------------------------------
static func _slab(top_r: float, bottom_r: float, height: float, h: Vector2, r: float, cut_top: bool,
		cut_bottom: bool, lo: float, hi: float) -> Array:
	var tris: Array = []
	var y_top := height * 0.5
	var y_bottom := -height * 0.5
	if cut_top:
		_holed_cap(tris, y_top, top_r, h, r, Vector3.UP)
	else:
		_cap(tris, y_top, top_r, Vector3.UP)
	if cut_bottom:
		_holed_cap(tris, y_bottom, bottom_r, h, r, Vector3.DOWN)
	else:
		_cap(tris, y_bottom, bottom_r, Vector3.DOWN)
	# The side, pushed out round the hole where it would cross it
	var rows := 12
	var grid: Array = []
	for k in rows + 1:
		var t := float(k) / rows
		var y := lerpf(y_bottom, y_top, t)
		var rho := lerpf(bottom_r, top_r, t)
		var row: Array = []
		for i in SEGS:
			var a := i * TAU / SEGS
			var q := Vector2(cos(a), sin(a)) * rho
			if y > lo and y < hi and q.distance_to(h) < r:
				q = h + (q - h).normalized() * r
			row.append(Vector3(q.x, y, q.y))
		grid.append(row)
	var slope := (bottom_r - top_r) / maxf(height, 0.001)
	for k in rows:
		for i in SEGS:
			var j := (i + 1) % SEGS
			var a := i * TAU / SEGS
			var n := Vector3(cos(a), slope, sin(a)).normalized()
			_tri(tris, grid[k][i], grid[k][j], grid[k + 1][i], n)
			_tri(tris, grid[k][j], grid[k + 1][j], grid[k + 1][i], n)
	# The hole's own wall through the slab (where both caps are cut)
	if cut_top and cut_bottom:
		for i in SEGS:
			var a0 := i * TAU / SEGS
			var a1 := (i + 1) * TAU / SEGS
			var p0 := h + Vector2(cos(a0), sin(a0)) * r
			var p1 := h + Vector2(cos(a1), sin(a1)) * r
			var n := -Vector3(cos(a0), 0, sin(a0))
			var v := [Vector3(p0.x, y_bottom, p0.y), Vector3(p1.x, y_bottom, p1.y), Vector3(p1.x, y_top, p1.y), Vector3(p0.x, y_top, p0.y)]
			_tri(tris, v[0], v[1], v[2], n)
			_tri(tris, v[0], v[2], v[3], n)
	return tris


static func _cap(tris: Array, y: float, rad: float, n: Vector3) -> void:
	var mid := Vector3(0, y, 0)
	for i in SEGS:
		var a0 := i * TAU / SEGS
		var a1 := (i + 1) * TAU / SEGS
		_tri(tris, mid, Vector3(cos(a0) * rad, y, sin(a0) * rad), Vector3(cos(a1) * rad, y, sin(a1) * rad), n)


static func _holed_cap(tris: Array, y: float, rad: float, h: Vector2, r: float, n: Vector3) -> void:
	# Rays out from the hole's middle: from the hole's edge to the slab's edge, in RINGS steps
	var rows: Array = []
	for i in SEGS:
		var a := i * TAU / SEGS
		var dir := Vector2(cos(a), sin(a))
		var b := h.dot(dir)
		var out := -b + sqrt(maxf(b * b - (h.length_squared() - rad * rad), 0.0))
		var row: Array = []
		for k in RINGS + 1:
			var d := lerpf(r, out, float(k) / RINGS)
			var q := h + dir * d
			row.append(Vector3(q.x, y, q.y))
		rows.append(row)
	for i in SEGS:
		var j := (i + 1) % SEGS
		for k in RINGS:
			_tri(tris, rows[i][k], rows[j][k], rows[i][k + 1], n)
			_tri(tris, rows[j][k], rows[j][k + 1], rows[i][k + 1], n)


static func _tri(tris: Array, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# Godot draws a face from the side it winds clockwise from: turn it to face n
	if (c - a).cross(b - a).dot(n) < 0.0:
		var s := b
		b = c
		c = s
	for v in [a, b, c]:
		tris.append({"p": v, "n": n})


static func _mesh_of(tris: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in tris:
		st.set_normal(v.n)
		st.set_uv(Vector2(v.p.x, v.p.z) * 0.1)
		st.add_vertex(v.p)
	return st.commit()
