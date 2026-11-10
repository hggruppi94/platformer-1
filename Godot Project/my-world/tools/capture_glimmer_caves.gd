extends SceneTree

# Screenshots of Lanternmoor's reward: the hollow that opens in the moor, and the Glimmer Caves under it
# (scripts/glimmer_caves.gd) lit by Pip's glow (scripts/pip_glow.gd): the Moth Hall, the Crystal Gallery's woken
# crystals, the glow bridge over the Chasm, the Echo Pool, the Mushroom Grotto, the Moonroot Chamber and its Moon
# Cache, the Gloomie Squeeze, Lantern Roots, the caves without the glow, and the hero glowing in the Void at night.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_glimmer_caves.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.glimmer_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.glimmer_capture_backup.cfg"

var out_dir := "user://glimmer_shots"
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
	clock.set_time(3, 12 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	portals.note_found("lanternmoor", "met_pip")
	await _caves()
	await _void_night()
	_finish()


func _caves() -> void:
	portals.enter("lanternmoor")
	await _frames(30)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var c: Node = s.get("caves")
	_cam_in(s)
	p.global_position = Vector3(10, 0.9, 40)
	await _frames(40)                                         # (the rock's noise texture is made a moment late)
	_look(Vector3(-1, 4.5, 46), Vector3(8, 0, 37))
	await _shot("01_the_hollow_opens_in_the_moor")
	_look(Vector3(8, 3.5, 40.5), Vector3(8, -9, 36))
	await _shot("02_looking_down_the_hollow")
	# Wake the crystals on a walk round first, so the caverns you've been through stay lit
	for room in ["moth_hall", "gallery", "chasm", "echo_pool", "grotto", "moonroot", "lantern_roots"]:
		p.global_position = c.ROOMS[room] + Vector3(0, 1.0, 0)
		await _frames(6)
	for x in [-30, -24, -15, -6]:
		p.global_position = Vector3(x, -9, [10, 20, 27, 30][[-30, -24, -15, -6].find(x)])
		await _frames(4)
	p.global_position = Vector3(10, -8.1, 28)
	await _frames(30)
	_look(Vector3(8, -6.0, 36), Vector3(9, -8.0, 26))
	await _shot("03_the_moth_hall_in_the_glow")
	p.global_position = Vector3(9, -12.1, 2)
	await _frames(30)
	_look(Vector3(14, -9.0, 8), Vector3(10, -12, -5))
	await _shot("04_the_crystal_gallery")
	var a: Vector3 = c.BRIDGE[0]
	var b: Vector3 = c.BRIDGE[1]
	p.global_position = a.lerp(b, 0.45) + Vector3(0, 0.95, 0)
	await _frames(40)
	_look(a + Vector3(-3.5, 2.2, 2.5), b + Vector3(0, -1.5, 0))
	await _shot("05_the_glow_bridge_over_the_chasm")
	p.global_position = Vector3(-3, -30.1, -21)
	await _frames(30)
	_look(Vector3(-5, -27.5, -18), Vector3(2.5, -31, -27))
	await _shot("06_the_echo_pool")
	var m: Dictionary = c.BOUNCERS[2]
	p.global_position = m.at + Vector3(0, 1.2, 0)
	await _physics(40)
	_look(Vector3(21, -10.5, -31), p.global_position + Vector3(0, -1.5, 0))
	await _shot("07_bouncing_in_the_mushroom_grotto")
	p.global_position = Vector3(28, -7.6, -15)
	await _frames(30)
	_look(Vector3(26.5, -5.5, -10.5), Vector3(31.5, -8, -17.5))
	await _shot("08_the_moonroot_chamber")
	var gl: Vector3 = c.gloomies[1].get_meta("home")
	p.global_position = Vector3(-18.5, -9.4, 24.5)          # in the Squeeze itself, just along from the Gloomie
	await _physics(20)
	_look(Vector3(-14.5, -8.4, 27.2), gl + Vector3(0, 0.3, 0))
	await _shot("09_gloomies_in_the_squeeze")
	p.global_position = Vector3(-21, -11.1, -9)
	await _frames(30)
	_look(Vector3(-19, -9.0, -6), Vector3(-26, -10.5, -14))
	await _shot("10_lantern_roots")
	portals.cleared_worlds.erase("lanternmoor")              # no glow: how dark it really is
	p.global_position = Vector3(9, -12.1, 2)
	await _frames(60)
	_look(Vector3(14, -9.0, 8), Vector3(10, -12, -5))
	await _shot("11_the_gallery_without_the_glow")
	portals.cleared_worlds.append("lanternmoor")
	await _frames(10)


func _void_night() -> void:
	portals.go_home()
	await _frames(40)
	var clock := root.get_node("Clock")
	clock.set_time(clock.day, 23 * 60.0 + 20.0, true)
	await _frames(60)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	_look(p.global_position + p.global_basis.z * 3.2 + Vector3(1.2, 1.6, 0), p.global_position + Vector3(0, 0.9, 0))
	await _frames(20)
	await _shot("12_glowing_softly_in_the_void_at_night")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 60
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
