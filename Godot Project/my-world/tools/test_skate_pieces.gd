extends SceneTree

# Checks that every skate piece you can ride (tools/skate_kit.gd: quarter pipes, the funbox, kickers, ledges) can be
# seen, in the town's Skate Park and the Practice Park: each solid piece has a mesh beside its collision, shown, with a
# solid (not see-through) material, and every face of it faces outward. A face built inside out is invisible from
# where you'd look at it (Godot only draws the front of a face), though she can still ride it: that's how the quarter
# pipes' curves went invisible. The rails and edges you grind are checked for a mesh too.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate_pieces.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const PARK := "res://scenes/skate/test_park.tscn"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(3)
	await _check_place("the Skate Park", current_scene.find_child("Skate Park", true, false))
	change_scene_to_file(PARK)
	await _frames(6)
	await _physics(3)
	await _check_place("the Practice Park", current_scene)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _check_place(place: String, where: Node) -> void:
	check(where != null, "%s is there" % place)
	if where == null:
		return
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var pieces := 0
	for body in where.find_children("*", "StaticBody3D", true, false):
		var i: int = body.get_index()
		var mi := body.get_parent().get_child(i - 1) as MeshInstance3D if i > 0 else null
		if mi == null:
			continue                                  # not a skate_kit piece (the rings, a sign...)
		pieces += 1
		var piece := String(mi.get_parent().name)
		var mat := mi.material_override as StandardMaterial3D
		check(mi.is_visible_in_tree() and mi.mesh != null and mi.mesh.get_surface_count() > 0,
			"%s, %s: has a mesh, shown" % [place, piece])
		check(mat != null and mat.albedo_color.a > 0.99 and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"%s, %s: solid colour, not see-through" % [place, piece])
		var inside_out := 0
		var faces := 0
		var arrays := mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if idx != null and idx.size() > 0 else v.size()
		var xf := mi.global_transform
		for k in range(0, count, 3):
			var a: Vector3 = xf * v[idx[k] if idx != null and idx.size() > 0 else k]
			var b: Vector3 = xf * v[idx[k + 1] if idx != null and idx.size() > 0 else k + 1]
			var c: Vector3 = xf * v[idx[k + 2] if idx != null and idx.size() > 0 else k + 2]
			var front := (c - a).cross(b - a)            # the side Godot draws (corners clockwise)
			if front.length() < 0.0001:
				continue
			front = front.normalized()
			faces += 1
			# Out from the front of the face: nothing of the same piece in the way. Inside out, it's the piece itself.
			var from := (a + b + c) / 3.0 + front * 0.02
			var q := PhysicsRayQueryParameters3D.create(from, from + front * 30.0)
			var hit := space.intersect_ray(q)
			if hit and hit.collider == body:
				inside_out += 1
		check(faces > 0 and inside_out == 0, "%s, %s: every face faces outward (%d of %d inside out)" % [place, piece,
			inside_out, faces])
	check(pieces >= 3, "%s: found its ramps and boxes (%d)" % [place, pieces])
	var rails := 0
	for r in where.find_children("*", "GrindRail", true, false):
		if r.get_parent().name == "EdgeRails":
			continue                                    # the edges of things (scripts/edge_rails.gd): the edge is what you see
		rails += 1
		var shown := false
		for m in r.get_parent().find_children("*", "MeshInstance3D", true, false):
			if (m as MeshInstance3D).is_visible_in_tree() and (m as MeshInstance3D).mesh != null:
				shown = true
		check(shown, "%s, %s: the %s you grind can be seen" % [place, r.get_parent().name, r.name])
	check(rails >= 3, "%s: found its rails and edges (%d)" % [place, rails])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
