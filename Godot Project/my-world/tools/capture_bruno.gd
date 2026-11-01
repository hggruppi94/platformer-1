extends SceneTree

# Pictures of Bruno (tools/build_bruno.py, from Sofi's drawing): on Earth as a person (tools/build_earth.gd) with his
# sisters and at the Skate Yard, then in Galaxity as his hippo self: close up, with Nina, about his day at the Skate
# Park, riding his SK8 Deck (scripts/rides.gd), coaching the skate lesson with Rook (scripts/skate_lesson.gd), and when
# the stress gets to him and his Godfather voice comes out.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_bruno.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.bruno_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.bruno_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://bruno_shots"
var cam: Camera3D
var clock: Node
var game: Node


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
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	dialogue.reset()
	root.get_node("Quests").reset()
	root.get_node("Settings").last_device = "keyboard"
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")

	# Earth: Bruno as a person, with Nina and Prue, at noon on the green
	game.next_spawn = "Entrance"
	clock.earth_minutes = 12 * 60.0
	change_scene_to_file(EARTH)
	await _frames(8)
	await create_timer(1.0).timeout
	_hide_player()
	_new_cam()
	var kids: Array[Node3D] = []
	for n in ["Nina", "Bruno", "Prue"]:
		var k := current_scene.find_child(n, true, false) as Node3D
		var r: Node = k.get_node_or_null("Routine")
		if r:
			r.process_mode = Node.PROCESS_MODE_DISABLED
		k.visible = true
		kids.append(k)
	for i in kids.size():
		kids[i].global_position = Vector3(1.2 - i * 1.2, 0.03, -6.5)
		kids[i].global_rotation = Vector3(0, PI, 0)
	await _shot_at("01_earth_the_blastoffs", Vector3(0, 1.3, -10.6), Vector3(0, 0.95, -6.5), 50.0)
	await _shot_at("02_earth_bruno_close", Vector3(-0.2, 1.25, -8.3), Vector3(0, 1.0, -6.5), 40.0)
	kids[1].global_rotation = Vector3(0, PI * 0.25, 0)
	await _shot_at("03_earth_bruno_side_board", Vector3(-2.0, 1.2, -8.2), Vector3(0, 0.85, -6.5), 45.0)

	# Galaxity: his hippo self, by the Blastoffs' house in the morning next to Nina
	game.next_spawn = ""
	change_scene_to_file(TOWN)
	await _frames(8)
	clock.set_time(1, 7 * 60.0 + 45.0, true)
	await create_timer(1.0).timeout
	_hide_player()
	_new_cam()
	root.get_node("Tips").clear()
	game.message("")
	var bruno := _npc("bruno_alien")
	var nina := _npc("nina")
	for n in [bruno, nina]:
		var r: Node = n.get_node_or_null("Routine")
		if r:
			r.process_mode = Node.PROCESS_MODE_DISABLED
		n.visible = true
	var spot := Vector3(66.0, 0.0, 4.0)
	spot.y = _ground(spot)
	bruno.global_position = spot
	nina.global_position = spot + Vector3(1.1, 0, 0)
	for n in [bruno, nina]:
		n.global_rotation = Vector3(0, 0, 0)
	await _shot_at("04_galaxity_bruno_close", spot + Vector3(-0.1, 1.15, 1.9), spot + Vector3(0, 1.0, 0), 40.0)
	await _shot_at("05_galaxity_bruno_and_nina", spot + Vector3(0.55, 1.2, 3.6), spot + Vector3(0.55, 0.8, 0), 45.0)
	bruno.global_rotation = Vector3(0, -PI * 0.75, 0)
	await _shot_at("06_galaxity_bruno_back", spot + Vector3(-0.3, 1.3, 2.2), spot + Vector3(0, 0.95, 0), 45.0)
	bruno.global_rotation = Vector3.ZERO

	# Talking to him (his lisp)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	(player.get_node("HUD") as CanvasLayer).visible = true
	player.visible = true
	player.global_position = spot + Vector3(0, 0.5, 1.6)
	dialogue.talk_to(bruno.get_node("Talk"))
	await create_timer(1.5).timeout
	await _shot_at("07_talking_to_bruno", spot + Vector3(1.4, 1.6, 3.4), spot + Vector3(0, 1.0, 0), 50.0)
	dialogue.end()
	await _frames(2)

	# His routine: the Skate Park in the afternoon
	for r in [bruno.get_node_or_null("Routine"), nina.get_node_or_null("Routine")]:
		if r:
			r.process_mode = Node.PROCESS_MODE_INHERIT
	clock.set_time(1, 15 * 60.0, true)
	clock.jumped.emit()
	await create_timer(1.0).timeout
	var at := bruno.global_position
	_hide_player()
	await _shot_at("08_skate_park_afternoon", at + Vector3(3.0, 2.2, 4.5), at + Vector3(0, 0.8, 0), 55.0)

	# Riding his SK8 Deck
	player.visible = true
	player.set_rider("bruno")
	game.riding = true
	game.equipment_changed.emit()
	var pad := current_scene.find_child("Lesson Pad", true, false) as Node3D
	player.global_position = pad.global_position + Vector3(-4.0, 1.0, -4.0)
	player.velocity = Vector3.ZERO
	await _frames(20)
	var feet := player.global_position
	await _shot_at("09_riding_the_sk8_deck", feet + Vector3(2.0, 1.2, 1.6), feet + Vector3(0, 0.6, 0), 50.0)

	# Coach Bruno (and Rook) at the Lesson Pad, then two bails on one step and the Godfather voice comes out
	var lesson := root.get_node("SkateLesson")
	for st in lesson.STEPS:
		dialogue.flags.erase("skate_lesson_" + st.id)
	player.set_rider("hero")
	game.riding = true
	game.equipment_changed.emit()
	lesson.start()
	await _frames(10)
	(player.get_node("HUD") as CanvasLayer).visible = true
	(player.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	var arm := player.get_node("SpringArm3D") as Node3D
	player.global_position = pad.global_position + Vector3(-1.2, 1.0, -3.5)
	arm.rotation = Vector3(-0.3, 0.4 + PI, 0)
	await _player_shot("10_coach_bruno_and_rook", 30)
	lesson._on_bailed()
	lesson._on_bailed()
	await _player_shot("11_bruno_under_stress", 30)
	lesson.stop()
	_finish()


func _npc(id: String) -> Node3D:
	for r in current_scene.find_children("Routine", "", true, false):
		if r.get("character_id") == id:
			return r.get_parent() as Node3D
	return null


func _ground(at: Vector3) -> float:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 20, 0), at + Vector3(0, -20, 0))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else at.y


func _hide_player() -> void:
	var player := current_scene.find_child("Player", true, false) as Node3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	player.global_position += Vector3(0, 0, 40)


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()


func _shot_at(file: String, from: Vector3, look: Vector3, fov: float) -> void:
	cam.make_current()
	cam.global_position = from
	cam.look_at(look)
	cam.fov = fov
	await create_timer(0.4).timeout
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _player_shot(file: String, frames: int) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
