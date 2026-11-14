extends SceneTree

# Checks the palace school's floors 2 and 3 (tools/build_school.gd, slice 2): the skybridge over the library holds
# her up, the Nova Lab, mezzanine, gadget wall and window seats are there, and the hidden spiral stair from floor 3's
# secret hallway down to Behind the Walls is solid all the way, with room to stand on it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_school_floors.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SCHOOL := "res://scenes/school/school.tscn"
const FLOOR_H := 6.0
const LIBRARY_AT := Vector2(0, -6)          # build_school.gd
const STAIR := Vector2(28.55, -14)          # build_school.gd HIDDEN_STAIR
const STAIR_START := PI / 2                 # where the top step leaves floor 3
const STAIR_TURNS := 2.0

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

	# --- What's new on floors 2 and 3 ---
	for path in ["Skybridge", "Floor 2/Nova Lab", "Floor 2/Nova Lab Kit", "Floor 2/Library Mezzanine",
			"Floor 2/Gadget Wall", "Floor 3/Window Seats", "Hidden Stair"]:
		check(school.has_node(path), "%s is there" % path)

	# --- The skybridge: a floor at floor 2's height right across the library's hole ---
	var gaps := []
	for z in range(-12, 1):
		for x: float in [-1.5, 0.0, 1.5]:
			var y := _ground(Vector3(x, FLOOR_H + 3, z))
			if absf(y - FLOOR_H) > 0.25:
				gaps.append(Vector2(x, z))
	check(gaps.is_empty(), "the skybridge holds her up all the way across: gaps at %s" % [gaps])
	check(_ground(Vector3(6, FLOOR_H + 3, -6)) < 1.0, "beside the bridge the library's still open below")

	# --- The hidden stair: solid all the way down, a gentle enough slope, and she can stand on it ---
	var bad := []
	var n := 72
	var r := 0.8
	for k in n + 1:
		var t := float(k) / n
		var a := STAIR_START + TAU * STAIR_TURNS * t
		var want := lerpf(2 * FLOOR_H, FLOOR_H, t)
		var p := Vector3(STAIR.x + cos(a) * r, want + 0.6, STAIR.y + sin(a) * r)
		var y := _ground(p)
		if absf(y - want) > 0.2:
			bad.append("t%.2f got %.2f want %.2f" % [t, y, want])
	check(bad.is_empty(), "the stair is solid under every step: %s" % [bad])
	var slope := rad_to_deg(atan(FLOOR_H / (TAU * STAIR_TURNS * r)))
	check(slope < 40.0, "the stair's slope where you walk is %.0f degrees" % slope)
	check(absf(_ground(Vector3(STAIR.x, 2 * FLOOR_H + 1, STAIR.y + 2.2)) - 2 * FLOOR_H) < 0.1,
		"floor 3's hallway is there by the top step")
	check(absf(_ground(Vector3(STAIR.x, FLOOR_H + 1, STAIR.y + 2.2)) - FLOOR_H) < 0.1,
		"floor 2's Behind the Walls is there by the bottom step")
	for t: float in [0.15, 0.4, 0.65, 0.9]:
		var a := STAIR_START + TAU * STAIR_TURNS * t
		var want := lerpf(2 * FLOOR_H, FLOOR_H, t)
		player.global_position = Vector3(STAIR.x + cos(a) * r, want + 1.0, STAIR.y + sin(a) * r)   # (her middle: her feet are 0.8 lower)
		player.velocity = Vector3.ZERO
		await _physics(40)
		var at: Vector3 = player.global_position
		check(at.y > want + 0.2 and Vector2(at.x, at.z).distance_to(STAIR) < 2.0,
			"stood on the stair %.0f%% of the way down, she stays on it (y %.2f, want about %.2f)" % [t * 100, at.y, want])

	_finish()


func _ground(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -20, 0))
	if player:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return -99.0 if hit.is_empty() else (hit.position as Vector3).y


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
