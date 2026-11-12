extends SceneTree

# Screenshots of the time quakes and Shard Isle (scripts/portals.gd, scripts/shard_isle.gd): the portal rising out of
# its crack, the portal with its preview window, Shard Isle from the air, arriving (with the portal timer), the
# stepping stones out to an Echo Crystal, the Time Stone, the Heart Stone before and after it's mended, and the Portal
# Plaza back in the Void. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_portals.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.portals_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.portals_capture_backup.cfg"

var out_dir := "user://portal_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	clock.set_time(3, 10 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	await _void_quake()
	await _isle()
	await _plaza()
	_finish()


func _void_quake() -> void:
	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(12)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var hud = p.get_node("HUD")
	hud.visible = false
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()
	var w: Dictionary = portals.world("shard_isle")
	var at: Vector3 = root.get_node("Remnants").ground_at(w.at)
	var front := Vector3(sin(w.yaw), 0, cos(w.yaw))
	p.global_position = at + front * 5.0 + Vector3(0, 0.5, 0)
	p.get_node("Visual").rotation.y = w.yaw + PI
	_look(at + front * 11.0 + Vector3(0, 6.0, 0), at + Vector3(0, 1.5, 0))
	await create_timer(portals.QUAKE_DELAY + 1.4).timeout          # the quake: the crack opens, the ring is rising
	await _shot("01_time_quake_portal_rising")
	await create_timer(4.0).timeout
	await _frames(20)
	_look(at + front * 9.5 + Vector3(2.5, 3.0, 0), at + Vector3(0, 2.6, 0))
	await create_timer(1.0).timeout
	await _shot("02_portal_with_its_preview")
	_look(at + front * 4.0 + Vector3(0, 2.8, 0), at + Vector3(0, 2.6, 0))
	await create_timer(0.5).timeout
	await _shot("03_preview_close_up")


func _isle() -> void:
	portals.enter("shard_isle")
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	await create_timer(1.0).timeout
	# Arriving, as the player sees it (the HUD and the portal timer on)
	await _shot("04_arriving_on_shard_isle")
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()
	_look(Vector3(30, 26, 38), Vector3(0, 0, -4))
	await _shot("05_shard_isle_from_the_air")
	var e := (s.get_node("Echo1") as Node3D).global_position
	p.global_position = e + Vector3(-6, 0.5, 2)
	_look(e + Vector3(-12, 4.5, 6), e + Vector3(0, 1.2, 0))
	await _frames(4)
	await _shot("06_stepping_stones_to_an_echo_crystal")
	var ts := (s.get_node("WayHome") as Node3D).global_position
	p.global_position = ts + Vector3(-3.5, 0.5, 3.5)
	_look(ts + Vector3(-4.5, 4.0, 5.0), ts + Vector3(0, -0.5, 0))
	await _frames(4)
	await _shot("07_the_way_home_crack")
	var h := (s.get_node("HeartStone") as Node3D).global_position
	p.global_position = h + Vector3(2.5, 0.5, 3.0)
	_look(h + Vector3(5, 4, 7), h + Vector3(0, 1.6, 0))
	await _frames(4)
	await _shot("08_heart_stone_out_of_tune")
	for i in 3:
		s.get_node("Echo%d/Spot" % (i + 1)).use()
	s.get_node("HeartStone/Heart/Spot").use()
	await create_timer(0.6).timeout
	await _shot("09_heart_stone_mended")
	_look(Vector3(0, 5, 16), Vector3(-5, 1.5, 6))
	await _frames(4)
	await _shot("10_the_way_home_and_the_time_stone")


func _plaza() -> void:
	portals.go_home()
	await _frames(16)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()
	var w: Dictionary = portals.world("shard_isle")
	var at: Vector3 = root.get_node("Remnants").ground_at(w.at)
	var front := Vector3(sin(w.yaw), 0, cos(w.yaw))
	_look(at + front * 15.0 + Vector3(0, 10.0, 0), at + Vector3(0, 1.0, 0))
	await create_timer(1.0).timeout
	await _shot("11_portal_plaza_in_the_void")


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
