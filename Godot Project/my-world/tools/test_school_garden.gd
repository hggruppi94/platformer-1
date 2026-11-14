extends SceneTree

# Checks the castle school's Entrance Garden keeps her on the map (tools/build_school.gd, scripts/fall_catch.gd):
# a double jump over the hedges used to drop her off the edge into nothing, falling forever. Since the palace
# campus (Nov 2026) it checks the whole grounds' edges.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_school_garden.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SCHOOL := "res://scenes/school/school.tscn"
const Z_S := 24.0               # the school's front wall (build_school.gd)
const CAMPUS := Rect2(-72, -40, 150, 103)       # the grounds (build_school.gd CAMPUS)
const BOWL := Rect2(38, 26, 36, 31)             # the sunken festival lawn and the steps down to it
const POOL := Rect2(39, -27.5, 28, 13)          # round the pool (53, -21), radii 13 by 5.5

var failures := 0
var school: Node3D
var player
var space: PhysicsDirectSpaceState3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(SCHOOL)
	for i in 5:
		await process_frame
	await _physics(3)
	school = current_scene as Node3D
	player = school.find_child("Player", true, false)
	space = school.get_world_3d().direct_space_state
	check(player != null, "she's in the school")

	# --- Ground everywhere on the campus (the sunken festival lawn and the pool are lower on purpose) ---
	var holes := []
	for x in range(int(CAMPUS.position.x) + 1, int(CAMPUS.end.x)):
		for z in range(int(CAMPUS.position.y) + 1, int(CAMPUS.end.y)):
			var p := Vector3(x, 30, z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -60, 0)))
			var low := -3.0 if (BOWL.has_point(Vector2(x, z)) or POOL.has_point(Vector2(x, z))) else -0.5
			if hit.is_empty() or (hit.position as Vector3).y < low:
				holes.append(Vector2(x, z))
	check(holes.is_empty(), "ground under every step of the campus: holes at %s" % [holes])

	# --- No way off the edge: from high up, every way out is walled ---
	var leaks := []
	for h in [0.5, 2.0, 4.0, 8.0, 20.0, 40.0]:
		for z in range(int(CAMPUS.position.y) + 1, int(CAMPUS.end.y), 2):
			for side in [[CAMPUS.position.x + 1.0, -1.0], [CAMPUS.end.x - 1.0, 1.0]]:
				var a := Vector3(side[0], h, z)
				if not _blocked(a, a + Vector3(10 * side[1], 0, 0)):
					leaks.append("x%+d h%.0f z%d" % [side[1], h, z])
		for x in range(int(CAMPUS.position.x) + 1, int(CAMPUS.end.x), 2):
			for side in [[CAMPUS.position.y + 1.0, -1.0], [CAMPUS.end.y - 1.0, 1.0]]:
				var a := Vector3(x, h, side[0])
				if not _blocked(a, a + Vector3(0, 0, 10 * side[1])):
					leaks.append("z%+d h%.0f x%d" % [side[1], h, x])
	check(leaks.is_empty(), "walled in all round, even high up: open at %s" % [leaks])

	# --- The real thing: a running double jump at the east edge doesn't get her over ---
	player.global_position = Vector3(CAMPUS.end.x - 2.5, 0.2, 20)
	await _physics(10)
	player.velocity = Vector3(7, 9, 0)
	for i in 120:
		player.velocity.x = 7.0
		await physics_frame
	check(player.global_position.x < CAMPUS.end.x and player.global_position.y > -1.0,
		"a big jump at the east edge keeps her on the campus: she's at %s" % [player.global_position])

	# --- The way out to town still works: its doorway comes before the wall behind it ---
	var exit := school.find_child("ExitToTown", true, false) as Area3D
	var back := school.find_child("Garden Wall Way Out", true, false) as Node3D
	var exit_front: float = exit.global_position.z - ((exit.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.z / 2
	var wall_front: float = back.global_position.z - ((back.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.z / 2
	check(exit_front < wall_front - 0.5, "she reaches the To Town doorway before the wall behind it (%.2f < %.2f)" % [exit_front, wall_front])
	check(not _blocked(Vector3(0, 1, 58), Vector3(0, 1, 65)), "nothing in the way down the path to the doorway")

	# --- The safety net: if she ever falls out anyway, she's put back by the way in ---
	var from_town := school.find_child("FromTown", true, false) as Node3D
	player.global_position = Vector3(CAMPUS.end.x + 15, -5, 30)
	player.velocity = Vector3.ZERO
	var caught := false
	for i in 240:
		await physics_frame
		if player.global_position.distance_to(from_town.global_position) < 2.0:
			caught = true
			break
	check(caught, "falling off the edge puts her back in the garden: she's at %s" % [player.global_position])
	_finish()


func _blocked(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [player.get_rid()]
	return not space.intersect_ray(q).is_empty()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
