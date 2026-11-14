extends SceneTree

# Checks swimming (scripts/swim.gd), Otto's gift once the Tide Reef is mended, out of the Tide Reef: Willow Pond has a
# deep middle; before the Tide Reef's mended deep water only floats you up to paddle along the top (Roll doesn't dive,
# nobody walks along the bottom), and afterwards you dive and swim up there too, with the bubble round your head and the
# view going blue and muffled; out of your depth only (the Void's lake is shallow: you wade); out again, everything's
# as it was; and Otto waits on the Portal Plaza in the Void once the reef's mended. (The flooded reef itself is in
# tools/test_tide_reef.gd.)
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_swim.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.swim_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.swim_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var portals: Node


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
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	var fn := root.get_node("FirstNight")
	root.get_node("Quests").state[fn.ID] = {"step": 0, "done": true, "since_day": 1}

	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(4)
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var swim: Node = player.get("swim")
	var pond := Vector3(EarthLand.POND.x, 0, EarthLand.POND.y)
	var depth := EarthLand.WATER_Y - EarthLand.height(pond.x, pond.z)
	check(depth > 2.5, "Willow Pond has a deep middle to swim in (%.1f m)" % depth)
	check(EarthLand.WATER_Y - EarthLand.height(-74.0, 0.0) < 1.6, "...out past the dock (the dock end's still in the shallows)")
	# Before Otto teaches you: just paddling along the top
	player.global_position = pond + Vector3(0, EarthLand.height(pond.x, pond.z) + 1.0, 0)
	player.velocity = Vector3.ZERO
	Input.action_press("dash")
	await _physics(180)
	Input.action_release("dash")
	var top: float = EarthLand.WATER_Y - swim.FLOAT
	check(player.call("is_swimming") and absf(player.global_position.y - top) < 0.35,
		"before you can swim, you float up and paddle along the top (%.2f m), and Roll doesn't dive" % player.global_position.y)
	check(not swim.under and not (swim.get("_helmet") as Node3D).visible, "...head out, no bubble")
	var x0 := player.global_position
	Input.action_press("move_forward")
	await _physics(60)
	Input.action_release("move_forward")
	var paddled := Vector2(player.global_position.x - x0.x, player.global_position.z - x0.z).length()
	check(paddled > 1.2 and paddled < 3.6, "paddling's slow (%.1f m in a second)" % paddled)
	# After: diving
	portals.cleared_worlds.append("tide_reef")
	player.global_position = pond + Vector3(0, top, 0)
	player.velocity = Vector3.ZERO
	await _physics(10)
	Input.action_press("dash")
	await _physics(50)
	Input.action_release("dash")
	check(player.call("is_swimming") and player.global_position.y < top - 1.2, "once Otto's taught you, hold Roll to dive (%.2f m)" % player.global_position.y)
	check(swim.under and (swim.get("_helmet") as Node3D).visible, "...with his bubble round your head")
	await _physics(60)
	await _frames(4)
	check(swim.view_under, "...and the camera comes down after you, so the view goes under the water too")
	var hp: int = game.hp
	await _physics(240)
	check(game.hp == hp and player.call("is_swimming"), "stay under as long as you like: nobody ever drowns")
	# Out again
	player.global_position = Vector3(-6, 1.0, 22)
	player.velocity = Vector3.ZERO
	await _physics(20)
	await _frames(4)
	check(not player.call("is_swimming") and not (swim.get("_helmet") as Node3D).visible and not swim.view_under,
		"out of the water, you walk again and everything's back to normal")
	var master := AudioServer.get_bus_index("Master")
	var muffled := false
	for i in AudioServer.get_bus_effect_count(master):
		muffled = muffled or AudioServer.get_bus_effect(master, i) is AudioEffectLowPassFilter
	check(not muffled, "...and the sound isn't muffled any more")
	check(not root.get_node("Settings").SECRET_ACTIONS.has("swim") and not InputMap.has_action("swim"),
		"no new button to learn: Jump and Roll do it")

	# The Void: its lake is shallow, so you wade; Otto's on the Portal Plaza
	portals.cleared_worlds.append("shard_isle")
	change_scene_to_file(TOWN)
	await _frames(12)
	await _physics(4)
	player = current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	player.global_position = Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	await _physics(40)
	check(not player.call("is_swimming") and player.call("in_zone", "water"), "the Void's lake is too shallow to swim: you wade")
	var otto := current_scene.find_child("Otto", true, false) as Node3D
	var w: Dictionary = portals.world("shard_isle")
	check(otto != null and otto.get_parent().name == "Portals" or (otto != null and Vector2(otto.global_position.x, otto.global_position.z).distance_to(w.at) < 6.0),
		"Otto waits on the Portal Plaza once the Tide Reef's mended")
	if otto:
		var ground: Vector3 = root.get_node("Remnants").ground_at(Vector2(otto.global_position.x, otto.global_position.z))
		check(absf(otto.global_position.y - ground.y) < 0.3, "...on the ground")
		var flurry := current_scene.find_child("Flurry", true, false) as Node3D
		check(flurry == null or flurry.global_position.distance_to(otto.global_position) > 2.8, "...not on top of Flurry")
		var trees := current_scene.find_child("Trees", true, false) as Node3D
		var tree := INF
		for tp in trees.get("positions"):
			var gp: Vector3 = trees.global_transform * tp
			tree = minf(tree, Vector2(gp.x, gp.z).distance_to(Vector2(otto.global_position.x, otto.global_position.z)))
		check(tree > 3.0, "...and not in a tree (nearest %.1f m)" % tree)
	var first: Array = portals.otto_hub_lines()
	check("Willow Pond" in " ".join(first) and portals.has_found("tide_reef", "otto_in_hub"), "he tells you where to go for a dive")
	check(not portals.otto_hub_lines().is_empty(), "...and chats after that")
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("dash")
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
