extends SceneTree

# Hayden, 14 Nov 2026: "Jelly mines were making the whole game crash when a bunch of enemies got caught in the same
# mine." Drops ONE Jelly Mine under a big crowd (Gloops, Big Gloops and Glorps that split), with every mod and with
# the Jelly Jamboree's two little mines, and checks the game carries on: lots stuck in one mine, they pop, nobody's
# left frozen, and no mine is left touching an enemy that's gone.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_jelly_crowd.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.jelly_crowd_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.jelly_crowd_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const GLOOP := "res://scenes/enemies/gloop.tscn"

var failures := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(500.0, true, false, true).timeout.connect(func() -> void:
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
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(4)
	var arsenal := root.get_node("Arsenal")
	for m in ["bounce", "freeze", "split", "magnet"]:
		if not m in arsenal.mods_owned:
			arsenal.mods_owned.append(m)
	arsenal.give("jelly", false)
	var runs := [
		{"name": "no mods", "mods": [], "two": false, "count": 30, "glorps": 0},
		{"name": "Jamboree, Bounce + Freeze", "mods": ["bounce", "freeze"], "two": true, "count": 40, "glorps": 0},
		{"name": "Jamboree, Split + Freeze", "mods": ["split", "freeze"], "two": true, "count": 40, "glorps": 0},
		{"name": "Jamboree, Glorps that split", "mods": ["bounce", "split"], "two": true, "count": 20, "glorps": 20},
		{"name": "60 at once", "mods": ["freeze", "magnet"], "two": true, "count": 60, "glorps": 0},
	]
	for r in runs:
		await _crowd(r)
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _crowd(r: Dictionary) -> void:
	seed(21)
	var arsenal := root.get_node("Arsenal")
	arsenal.slots["jelly"] = r.mods.duplicate()
	var p := _player()
	var at := Vector3(-60, 0, 40)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 60, 0), at + Vector3(0, -60, 0))
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = hit.position
	p.global_position = at + Vector3(0, 0.85, 14)
	var packed := load(GLOOP) as PackedScene
	var glorp: GDScript = load("res://scripts/glorp.gd")
	var crowd: Array = []
	for k in int(r.count) + int(r.glorps):
		var g: Node3D
		if k < int(r.count):
			g = packed.instantiate() as Node3D
			if k % 4 == 0:
				g.set("big", true)
		else:
			g = glorp.call("make", 1.2)
		current_scene.add_child(g)
		g.global_position = at + Vector3(randf_range(-1.0, 1.0), 0.6, randf_range(-1.0, 1.0))
		crowd.append(g)
	await _physics(2)
	var jelly: GDScript = load("res://scripts/jelly_mine.gd")
	var mine: Node = jelly.drop(current_scene, at, p, {"radius": 2.6, "time": 0.4, "leaves_two": r.two})
	await _physics(3)
	var stuck: int = mine.stuck.size() if is_instance_valid(mine) else 0
	check(stuck >= 10, "%s: lots stuck in one mine (%d)" % [r.name, stuck])
	var worst := 0
	var slowest := 0
	for f in 360:
		var t0 := Time.get_ticks_msec()
		await physics_frame
		slowest = maxi(slowest, Time.get_ticks_msec() - t0)
		for j in get_nodes_in_group("jelly_mines"):
			for e in j.stuck.keys():
				if not is_instance_valid(e):
					worst += 1
	print("      slowest frame %d ms" % slowest)
	check(worst == 0, "%s: no mine holds an enemy that's gone (%d)" % [r.name, worst])
	var all_now: Array = get_nodes_in_group("enemies").filter(func(e) -> bool:
		return is_instance_valid(e) and (e as Node3D).global_position.distance_to(at) < 12.0)
	var popped := crowd.filter(func(g) -> bool: return not is_instance_valid(g) or g.get("defeated") == true).size()
	check(popped >= stuck - 2, "%s: they pop and the game carries on (%d popped)" % [r.name, popped])
	var frozen := all_now.filter(func(e) -> bool:
		return e.get("defeated") != true and not e.is_physics_processing() and not e.has_meta("jelly_stuck")).size()
	check(frozen == 0, "%s: nobody's left frozen (%d)" % [r.name, frozen])
	for j in get_nodes_in_group("jelly_mines"):
		j.melt()
	await _physics(30)
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e) and (e as Node3D).global_position.distance_to(at) < 14.0:
			e.queue_free()
	await _physics(4)


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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
