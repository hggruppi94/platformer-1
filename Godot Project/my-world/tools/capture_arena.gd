extends SceneTree

# Screenshots of the new enemies and the Star Arena: the Glorps in Glorp Meadow, the Fizzlers on the Static Field, the
# shadow ghosts out at night, the Arena Gate, the arena inside (tunnel, floor, stands, Blip and the Round Board), a
# Gloop round, a Glorp splitting, and the three arena bosses (Mama Glorp, Big Buzz, the Gloam in a spotlight).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_arena.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.arena_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.arena_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://arena_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var arena := root.get_node("Arena")
	var wilds := root.get_node("Wilds")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").no_damage = true
	root.get_node("Quests").state["first_night"] = {"step": 99, "since_day": 1, "done": true}
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)

	# Out in the Void by day
	change_scene_to_file(TOWN)
	await _frames(14)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	_new_cam()
	var meadow := wilds.MEADOW as Vector2
	p.global_position = Vector3(meadow.x + 14, 1, meadow.y + 14)
	await _physics(30)
	var g0 := town.find_child("Glorp 1", true, false) as Node3D
	await _view("01_glorp_meadow", Vector3(meadow.x + 10, 4.5, meadow.y + 10), Vector3(meadow.x, 0.8, meadow.y))
	await _view("02_a_glorp_close", g0.global_position + Vector3(2.6, 1.6, 2.6), g0.global_position + Vector3(0, 0.9, 0))
	g0.call("shot", 1, g0.global_position, Vector3(1, 0, 0))
	await _physics(10)
	await _view("03_a_glorp_splits", g0.global_position + Vector3(4.5, 2.6, 4.5), g0.global_position + Vector3(0, 0.6, 0), 2)

	var field := wilds.FIELD as Vector2
	p.global_position = Vector3(field.x + 14, 1, field.y + 14)
	await _physics(30)
	await _view("04_the_static_field", Vector3(field.x + 11, 5, field.y + 11), Vector3(field.x, 1, field.y))
	var f1 := town.find_child("Fizzler 1", true, false) as Node3D
	f1.set("charging", 0.5)
	await _view("05_a_fizzler_crackling", f1.global_position + Vector3(2.4, 0.8, 2.4), f1.global_position + Vector3(0, 0.6, 0), 3)

	# Night: the shadow ghosts are out
	clock.set_time(3, 22 * 60.0, true)
	await _frames(10)
	await create_timer(2.5).timeout                         # (Wilds looks every 2 s and lets them out)
	await _physics(30)
	var ghost := (town.get_node("Night Ghosts") as Node3D).get_child(0) as Node3D
	await _view("06_shadow_ghosts_at_night", ghost.global_position + Vector3(4, 2.0, 4), ghost.global_position + Vector3(0, 1.0, 0), 10)
	clock.set_time(3, 11 * 60.0, true)
	await _frames(10)

	# The Arena Gate
	var gate := town.get_node("Arena Gate") as Node3D
	var face := Vector3(arena.GATE_FACING.x, 0, arena.GATE_FACING.y)
	p.global_position = gate.global_position + face * 12.0 + Vector3(0, 1, 0)
	await _physics(10)
	await _view("07_the_arena_gate", gate.global_position + face * 15.0 + face.cross(Vector3.UP) * 6.0 + Vector3(0, 4, 0), gate.global_position + Vector3(0, 3, 0), 10)

	# In
	arena.enter()
	await _frames(16)
	var lv := current_scene as Node3D
	p = lv.find_child("Player", true, false) as CharacterBody3D
	var hud := p.get_node("HUD") as CanvasLayer
	hud.visible = false
	_new_cam()
	await _view("08_down_the_tunnel", Vector3(0, 2.2, 38), Vector3(0, 1.5, 0), 12)
	await _view("09_the_arena_from_above", Vector3(28, 30, 28), Vector3(0, 0, 0), 12)
	await _view("10_blip_and_the_round_board", Vector3(0, 2.6, 29), Vector3(0, 1.8, 21), 8)

	# A Gloop round, through the game's own camera
	hud.visible = true
	(p.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	lv.start_round("gloops")
	await create_timer(4.5).timeout
	await _physics(30)
	await _shot("11_pop_100_gloops")
	for i in 7:
		var e: Node = lv._live[0] if lv._live.size() > 0 else null
		if e:
			e.call("shot", 3, Vector3.ZERO, Vector3.FORWARD)
		await _physics(4)
	await _physics(20)
	await _shot("12_the_count_goes_up")
	lv.stop_round(true)
	await _physics(10)

	# The bosses
	hud.visible = false
	lv.start_round("mama_glorp")
	await create_timer(3.6).timeout
	await _physics(30)
	var b := lv.boss as Node3D
	_new_cam()
	await _view("13_mama_glorp", b.global_position + Vector3(6, 4, 8), b.global_position + Vector3(0, 2.4, 0))
	for i in 3:
		b.call("shot", 1, b.global_position, Vector3(1, 0, 0))
		await _physics(8)
	await _view("14_mama_glorp_splits_off_babies", b.global_position + Vector3(8, 5, 10), b.global_position + Vector3(0, 1.6, 0), 10)
	lv.stop_round(true)
	await _physics(10)

	lv.start_round("big_buzz")
	await create_timer(3.6).timeout
	await _physics(40)
	b = lv.boss as Node3D
	await _view("15_big_buzz_up_high", b.global_position + Vector3(7, 0.5, 9), b.global_position + Vector3(0, 1.2, 0))
	lv.stop_round(true)
	await _physics(10)

	lv.start_round("gloam")
	await create_timer(3.6).timeout
	await _physics(40)
	b = lv.boss as Node3D
	await _view("16_the_gloam_in_the_dark", b.global_position + Vector3(7, 4, 9), b.global_position + Vector3(0, 2.8, 0), 10)
	# Into a beam
	for i in 45:
		var beam: Vector3 = lv.beam_at(0)
		b.global_position = Vector3(beam.x, b.global_position.y, beam.z)
		await physics_frame
	b.process_mode = Node.PROCESS_MODE_DISABLED                  # (hold it there, pale, for the picture)
	await _view("17_the_gloam_caught_in_a_spotlight", b.global_position + Vector3(7, 4, 9), b.global_position + Vector3(0, 2.8, 0), 10)
	await _view("18_the_arena_with_the_lights_down", Vector3(26, 24, 26), Vector3(0, 0, 0), 6)
	lv.stop_round(true)
	_finish()


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	root.get_node("Settings").no_damage = false
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
