extends SceneTree

# Checks the Lily Pond in the Void's south meadow and the friends on its shore (scripts/pond_friends.gd; the Meshy
# trial of Nov 25, 2026): Hermez the crane (models/characters/hermez.glb, tools/build_hermez.py) and, once his model's
# in, Rolo the rhino.
# - each model loads, has an AnimationPlayer with "idle" and "walk", a rig, and its baked detail (normal, AO and tint
#   textures on its materials, eyes left crisp),
# - the pond is in the town, on the map, on flat ground, clear of every path and everything solid,
# - each friend stands on the ground at its edge, faces out of the pond, plays "idle", has a talk spot that talks
#   from its own dialogue file (no conversation longer than three lines), and is solid,
# - you can walk up to each from the meadow.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_pond_friends.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.pond_friends_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pond_friends_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const POND_FRIENDS := preload("res://scripts/pond_friends.gd")

var failures := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	_check_models()
	_check_dialogue()
	change_scene_to_file(TOWN)
	await _frames(20)
	await _physics(4)
	await _check_pond()
	_finish()


func _check_models() -> void:
	check(POND_FRIENDS.has_model("hermez"), "Hermez's model is in the project")
	for id in POND_FRIENDS.FRIENDS:
		if not POND_FRIENDS.has_model(id):
			print("SKIP  %s: no model yet" % id)
			continue
		var f: Dictionary = POND_FRIENDS.FRIENDS[id]
		var m := (load(str(f.model)) as PackedScene).instantiate() as Node3D
		root.add_child(m)
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(ap != null, "%s: has an AnimationPlayer" % id)
		if ap:
			for a in ["idle", "walk"]:
				check(ap.has_animation(a), "%s: has a '%s' animation (%s)" % [id, a, ap.get_animation_list()])
		var skel: Skeleton3D = null
		for n in m.find_children("*", "Skeleton3D", true, false):
			skel = n
		check(skel != null and skel.get_bone_count() >= 15, "%s: is rigged (%d bones)" % [id, skel.get_bone_count() if skel else 0])
		# Baked detail: every textured material has a normal map and occlusion, the eyes have none
		var detailed := 0
		var crisp_ok := true
		var top := 0.0
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			top = maxf(top, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).end.y)
			for s in mesh.get_surface_count():
				var mat := mesh.surface_get_material(s) as StandardMaterial3D
				if mat == null:
					continue
				if mat.normal_enabled and mat.normal_texture and mat.ao_enabled and mat.ao_texture:
					detailed += 1
				if mat.resource_name in ["Iris", "Pupil", "Eye White", "Eye Shine"] and mat.normal_texture:
					crisp_ok = false
		check(detailed >= 3, "%s: baked detail on its materials (%d)" % [id, detailed])
		check(crisp_ok, "%s: the eyes stay crisp" % id)
		check(top > 0.9 and top < 2.2, "%s: a sensible height for a friend (%.2f m)" % [id, top])
		m.queue_free()


func _check_dialogue() -> void:
	for id in POND_FRIENDS.FRIENDS:
		var res := load("res://dialogue/%s.json" % id) as JSON
		check(res != null and res.data is Dictionary, "%s: has a dialogue file" % id)
		if res == null:
			continue
		var longest := 0
		for c in res.data.conversations:
			if c.has("lines"):
				longest = maxi(longest, c.lines.size())
			for r in c.get("rotate", []):
				longest = maxi(longest, (r as Array).size())
		check(longest > 0 and longest <= 3, "%s: no conversation longer than three lines (%d)" % [id, longest])


func _check_pond() -> void:
	var s := current_scene as Node3D
	var pf := root.get_node("Watches/PondFriends")
	var pond: Node3D = pf.pond()
	check(pond != null, "the Lily Pond is in the town")
	if pond == null:
		return
	check(pond.is_in_group("map_landmarks") and pond.map_name() == "Lily Pond", "it's on the map")
	var c := Vector2(pond.global_position.x, pond.global_position.z)
	# Off every path, with room to walk round it
	var paths := TownPaths.get_shared()
	var near := INF
	for l in paths.links:
		near = minf(near, Geometry2D.get_closest_point_to_segment(c, paths.points[l[0]], paths.points[l[1]]).distance_to(c))
	check(near > 10.0, "it's well off every path (%.1f m)" % near)
	# Flat ground round it
	# Ground heights look past the pond's own stones and friends
	var lo := INF
	var hi := -INF
	for o: Vector2 in [Vector2.ZERO, Vector2(7, 0), Vector2(-7, 0), Vector2(0, 7), Vector2(0, -7)]:
		var y: float = _ground(s, pond, c.x + o.x, c.y + o.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(hi - lo < 0.5, "the ground round it is flat (%.2f m)" % (hi - lo))
	# Nothing solid in it but its own stones and friends
	var space := s.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(16, 2.5, 16)
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(Basis.IDENTITY, pond.global_position + Vector3(0, 1.6, 0))
	var others := []
	for h in space.intersect_shape(sq, 16):
		var col := h.collider as Node
		if col and not pond.is_ancestor_of(col) and not str(col.get_path()).contains("Ground") \
				and not col.is_in_group("player") and not (col is CharacterBody3D):
			others.append(str(col.name))
	check(others.is_empty(), "nothing else solid round it %s" % [others])
	var trees: PackedVector3Array = s.get_node("Trees").get("positions")
	var tree_d := INF
	for t in trees:
		tree_d = minf(tree_d, Vector2(t.x, t.z).distance_to(c))
	check(tree_d > 8.0, "no tree in it (nearest %.1f m)" % tree_d)
	# The friends
	for id in POND_FRIENDS.FRIENDS:
		var f: Node3D = pf.friend(id)
		if not POND_FRIENDS.has_model(id):
			check(f == null, "%s isn't there without a model" % id)
			continue
		check(f != null, "%s stands by the pond" % id)
		if f == null:
			continue
		var p: Vector3 = f.global_position
		var g := Vector3(p.x, _ground(s, pond, p.x, p.z), p.z)
		check(absf(g.y - p.y) < 0.15, "%s: on the ground (%.2f vs %.2f)" % [id, p.y, g.y])
		var out := Vector2(p.x, p.z) - c
		var facing := Vector2(sin(f.global_rotation.y), cos(f.global_rotation.y))   # the model's +Z
		check(facing.dot(out.normalized()) > 0.5, "%s: faces out of the pond, to the meadow" % id)
		var talk: Node = f.get_node_or_null("Talk")
		check(talk != null and str(talk.get("character_id")) == id, "%s: has a talk spot" % id)
		check(f.get_node_or_null("Body") is StaticBody3D, "%s: is solid" % id)
		var ap := f.find_child("AnimationPlayer", true, false) as AnimationPlayer
		check(ap != null and ap.current_animation == "idle", "%s: playing idle" % id)
		# A clear way up to them from the meadow: nothing in the way at knee and chest height
		var from := Vector3(p.x, p.y, p.z) + Vector3(out.normalized().x, 0, out.normalized().y) * 7.0
		var clear := true
		for hgt: float in [0.6, 1.2]:
			var rq := PhysicsRayQueryParameters3D.create(from + Vector3(0, hgt, 0), p + Vector3(0, hgt, 0))
			var hit := space.intersect_ray(rq)
			if hit and not f.is_ancestor_of(hit.collider):
				clear = false
		check(clear, "%s: a clear way up to them from the meadow" % id)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


func _ground(s: Node3D, pond: Node3D, x: float, z: float) -> float:
	# The ground's height here, looking through the pond's own stones and the friends standing by it
	var skip: Array[RID] = []
	for b in pond.find_children("*", "CollisionObject3D", true, false):
		skip.append((b as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -20, z))
	q.exclude = skip
	var hit := s.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if hit else -INF
