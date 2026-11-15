extends SceneTree

# Screenshots of the Hum Heads in Rhythm Springs (scripts/stone_heads.gd): the row of five round the valley's edge,
# a close-up, one humming at you, and all five singing together in the mended golden evening. Opens a window (not
# --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_hum_heads.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.hum_heads_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.hum_heads_capture_backup.cfg"

var out_dir := "user://hum_heads_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
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
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)                       # late morning in the Void
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _heads()
	_finish()


func _heads() -> void:
	game_go("res://scenes/portal_worlds/rhythm_springs.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var hh := s.get_node("Hum Heads")
	var p := s.find_child("Player", true, false) as Node3D
	_cam_in(s)
	var mid: Vector3 = hh.spot(2)
	var inward := -mid.normalized()
	var side := inward.cross(Vector3.UP)
	p.global_position = mid + inward * 14.0 + Vector3(0, 0.9, 0)
	await _frames(10)
	_look(mid + inward * 20.0 + Vector3(0, 6.0, 0), mid + Vector3(0, 2.5, 0))
	await _frames(20)
	await _shot("01_the_hum_heads_round_the_edge")
	var one: Vector3 = hh.spot(1)
	var in1 := -one.normalized()
	_look(one + in1 * 5.5 + in1.cross(Vector3.UP) * 2.0 + Vector3(0, 2.6, 0), one + Vector3(0, 3.0, 0))
	await _frames(10)
	await _shot("02_close_up")
	p.global_position = one + in1 * 3.0 + Vector3(0, 0.9, 0)
	await _frames(12)
	_look(one + in1 * 6.0 - in1.cross(Vector3.UP) * 3.0 + Vector3(0, 2.8, 0), one + Vector3(0, 2.6, 0) + in1 * 1.5)
	await _frames(4)
	await _shot("03_humming_at_you_out_of_tune")
	portals.cleared_worlds.append("rhythm_springs")
	s.call("set_cool", 1.0)
	p.global_position = mid + inward * 12.0 + Vector3(0, 0.9, 0)
	await _frames(30)
	hh.sing_together()
	await _frames(14)
	_look(mid + inward * 17.0 + side * 6.0 + Vector3(0, 4.5, 0), mid + Vector3(0, 3.0, 0))
	await _frames(2)
	await _shot("04_singing_together_in_the_evening")


func game_go(path: String) -> void:
	root.get_node("Game").go(path, "", "")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
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
