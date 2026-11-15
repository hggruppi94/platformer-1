extends SceneTree

# Shots of the bosses' own lairs (scripts/clock_tower.gd, scripts/boulder_canyon.gd) and their ways in out in the Void
# (scripts/bosses.gd). One place a run. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_lairs.gd -- <output folder> town
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_lairs.gd -- <output folder> clock_tower
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_lairs.gd -- <output folder> boulder_canyon
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.lairs_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lairs_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://boss_lair_shots"
var cam: Camera3D
var _had_save := false
var which := "clock_tower"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		which = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game._resume = {}
	root.get_node("Settings").tips = false
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	root.get_node("Clock").set_time(2, 13 * 60.0, true)
	root.get_node("Portals").quakes = ["shard_isle"]
	var bosses := root.get_node("Bosses")
	if which == "town":
		change_scene_to_file(TOWN)
		await _frames(60)
		await create_timer(1.5).timeout
		var s := current_scene as Node3D
		_hide_hud(s)
		cam = _cam(s)
		for id in ["clock_tower", "boulder_canyon"]:
			var l: Dictionary = bosses.LAIRS[id]
			var f: Vector2 = l.facing
			var g: Vector3 = bosses.ground(s, l.at.x, l.at.y)
			var side := Vector3(f.y, 0, -f.x)
			cam.global_position = g + Vector3(f.x, 0, f.y) * 13.0 + side * 4.0 + Vector3(0, 4.0, 0)
			cam.look_at(g + Vector3(0, 3.5, 0), Vector3.UP)
			await create_timer(1.5).timeout
			await _shot("town_%s_gate" % id)
		_finish()
		return
	change_scene_to_file(str(bosses.LAIRS[which].scene))
	await _frames(60)
	await create_timer(1.0).timeout
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	_hide_hud(s)
	cam = _cam(s)
	var arena: Vector3 = s.call("arena")
	# The way in, looking up the level
	cam.global_position = Vector3(3.0, 3.0, 0.5)
	cam.look_at(Vector3(0, 2.5, 26.0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("%s_1_way_in" % which)
	# The hazard stretch from the side, high up
	if which == "boulder_canyon":
		p.global_position = Vector3(2.25, 1.0, 22.0)          # (so the boulders roll)
	cam.global_position = Vector3(-6.5, 9.0, 8.0)
	cam.look_at(Vector3(0, 1.0, 28.0), Vector3.UP)
	for t in 3:
		await create_timer(0.9).timeout
		await _shot("%s_2_run_%d" % [which, t])
	# The arena with its boss asleep
	p.global_position = Vector3(0, 1.0, 40.0)
	cam.global_position = arena + Vector3(0, 9.0, -15.0)
	cam.look_at(arena + Vector3(0, 2.0, 6.0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("%s_3_arena" % which)
	# The fight: wake it, and watch its own trick
	p.global_position = arena + Vector3(4.0, 1.0, -6.0)
	s.call("wake")
	await create_timer(2.5).timeout
	cam.global_position = arena + Vector3(14.0, 11.0, -14.0)
	cam.look_at(arena + Vector3(0, 1.0, 2.0), Vector3.UP)
	for t in 4:
		await create_timer(1.2).timeout
		await _shot("%s_4_fight_%d" % [which, t])
	# Popped: the treasure open
	var boss := s.get("boss") as CharacterBody3D
	boss.set("state", 4)
	boss.shot(int(boss.get("stomps_to_defeat")), boss.global_position, Vector3.FORWARD)
	await create_timer(2.0).timeout
	var chest := s.get("_chest") as Node3D
	cam.global_position = chest.global_position + Vector3(3.0, 2.2, -4.5)
	cam.look_at(chest.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	await create_timer(1.2).timeout
	await _shot("%s_5_treasure" % which)
	_finish()


func _hide_hud(s: Node) -> void:
	var p := s.find_child("Player", true, false)
	if p and p.get_node_or_null("HUD"):
		p.get_node("HUD").visible = false


func _cam(s: Node3D) -> Camera3D:
	var c := Camera3D.new()
	c.fov = 60
	s.add_child(c)
	c.make_current()
	return c


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
