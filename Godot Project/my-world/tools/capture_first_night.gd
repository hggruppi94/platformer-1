extends SceneTree

# Screenshots of "The First Night" (res://quests/first_night.json, scripts/first_night.gd), step by step: Nina at the
# door, Mr. Palmer at the gazebo, the quest log, Nina going home, the ground cracking open at midnight, the fall, the
# night the sky cracked beat by beat (scripts/void_arrival.gd), the watch on the hero's wrist, Dash by his stall, Rex and Coach Rook at the Skate Park, the map's
# stars, the Gloop King, the cheer, the Gloop Crown, waking in bed, and Nina asking if it will happen again.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_first_night.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.first_night_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const Q := "first_night"

var out_dir := "user://first_night_shots"
var cam: Camera3D
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var fn: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fn = root.get_node("FirstNight")
	var creator := root.get_node("Creator")
	root.get_node("Settings").tips = false

	# --- Earth, 8 PM: a new hero, and Nina at the door ---
	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	game.hero["name"] = "Sunny"
	game.hero["body"] = "bunny" if Hero.BODIES.has("bunny") else game.hero.get("body", "kid")
	creator.close()
	await _frames(10)
	await _physics(40)
	var player := _player()
	var nina := _body("nina_earth")
	var home := current_scene.find_child("My Home", true, false) as Node3D
	player.global_position = nina.global_position + Vector3(0, 0.5, 2.6)
	_face(player, nina.global_position)
	_face(nina, player.global_position)
	await _physics(4)
	_make_cam()
	await _view("01_nina_knocks_at_the_door", home.global_position + Vector3(4.5, 3.2, -1.0), nina.global_position + Vector3(0, 1.0, 0), 20)
	await _talk_until("nina_earth", "Nina Blastoff")
	await _view("02_nina_says_hello", player.global_position + Vector3(2.5, 1.6, 2.0), nina.global_position + Vector3(0, 0.9, 0))
	await _end_talk()

	var palmer := _body("palmer_earth")
	player.global_position = palmer.global_position + Vector3(1.6, 0.5, 1.6)
	_face(player, palmer.global_position)
	_face(palmer, player.global_position)
	await _physics(4)
	await _talk_until("palmer_earth", "opens your menu")
	await _view("03_mr_palmer_at_the_gazebo", palmer.global_position + Vector3(4.0, 2.2, 3.5), palmer.global_position + Vector3(0, 1.0, 0))
	await _end_talk()
	await _talk_through("theo")
	await _talk_through("lionel")
	await _frames(6)

	# The quest log, on the next step
	var menu := root.get_node("PlayerMenu")
	menu.open("quests")
	await _frames(6)
	await _shot("04_the_quest_log")
	menu.close()
	await _frames(4)
	for f in ["fn_board_look", "fn_board_follow", "fn_board_job"]:
		dialogue.set_flag(f)
	await _frames(6)

	# --- The evening: Nina goes home, nothing says what's coming ---
	nina = _body("nina_earth")
	player.global_position = nina.global_position + Vector3(0, 0.5, 2.2)
	_face(player, nina.global_position)
	_face(nina, player.global_position)
	await _physics(4)
	await _talk_until("nina_earth", "spaghetti")
	await _view("05_nina_goes_home_for_dinner", player.global_position + Vector3(2.5, 1.6, 2.0), nina.global_position + Vector3(0, 0.9, 0))
	await _end_talk()

	# --- Midnight: the ground cracks open under them ---
	var oak := current_scene.find_child("Old Oak", true, false) as Node3D
	var green: Vector3 = (oak.global_position if oak else _place("old_oak")) + Vector3(-14.0, 0, 12.0)
	player.global_position = green + Vector3(0, 0.5, 0)
	clock.set_earth_time(23 * 60.0 + 57.0, true)
	await _physics(10)
	_make_cam()
	await _view("06_a_quiet_night_in_stars_hollow", player.global_position + Vector3(5.0, 3.0, 6.0), player.global_position + Vector3(0, 1.0, 0), 20)
	clock.set_earth_time(0.5, true)
	var wait := 300
	while not fn.arrival._falling and wait > 0:
		wait -= 1
		await process_frame
	await create_timer(2.8).timeout
	await _view("07_the_ground_cracks_open", player.global_position + Vector3(4.0, 3.5, 5.0), player.global_position, 1)
	await create_timer(0.9).timeout
	await _view("08_falling", player.global_position + Vector3(2.0, 4.5, 2.5), player.global_position + Vector3(0, -1.0, 0), 1)

	# --- The Void: the night the sky cracked (its own camera) ---
	await _wait_for_scene(TOWN, 900)
	var beats := [[1.5, "09_dawn_in_the_market_square"], [5.0, "10_the_sky_splits_open"], [8.6, "11_seven_streaks_of_light"],
		[10.4, "12_mr_palmer_and_the_onlookers"], [12.4, "13_rexs_ears_go_flat"], [16.5, "14_the_little_aliens_come_running"],
		[20.6, "15_tally_counts_seven"], [26.4, "16_the_night_the_sky_cracked"]]
	wait = 600
	while not fn.arrival.playing() and wait > 0:
		wait -= 1
		await process_frame
	for b in beats:
		while fn.arrival.playing() and float(fn.arrival._t) < float(b[0]):    # (the cutscene's own clock: slow
			await process_frame                                                # renderers fall behind real time)
		await _shot(b[1], 1)
	while fn.arrival.playing():
		await process_frame
	await _frames(10)
	player = _player()
	await _physics(10)
	cam = null
	_make_cam()
	var hand := player.global_position + Vector3(0, 0.9, 0)
	await _view("17_a_watch_on_the_wrist", hand + player.global_basis.z * 1.3 + player.global_basis.x * 0.5 + Vector3(0, 0.1, 0), hand, 20)
	var tally := _body("tally")
	var tally_node := tally if tally else player
	await _view("18_greeted_by_little_aliens", player.global_position + Vector3(-4.0, 3.0, 6.0), player.global_position + Vector3(0, 0.8, 0), 10)
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get_parent() and t.get_parent().name == "Tally":
			tally_node = t.get_parent()
	if tally_node != player:
		player.global_position = tally_node.global_position + Vector3(1.4, 0.5, 1.4)
		_face(player, tally_node.global_position)
	dialogue.set_flag("fn_met_tally")
	await _frames(10)
	var dash: Node3D

	# --- The Void day ---
	dash = _body("dash")
	_snap("dash")
	await _physics(6)
	player.global_position = dash.global_position + Vector3(2.0, 0.5, 1.0)
	_face(player, dash.global_position)
	_face(dash, player.global_position)
	await _physics(4)
	await _talk_until("dash", "gadget stall")
	var stall := current_scene.find_child("Gadget Stall", true, false) as Node3D
	await _view("19_dash_by_his_gadget_stall", dash.global_position + Vector3(5.0, 3.0, 4.0),
		(stall.global_position if stall else dash.global_position) + Vector3(0, 1.0, 0))
	await _end_talk()
	_snap("rex")
	await _physics(6)
	var rex := _body("rex")
	player.global_position = rex.global_position + Vector3(1.8, 0.5, 1.8)
	_face(player, rex.global_position)
	_face(rex, player.global_position)
	await _physics(4)
	await _talk_until("rex", "Every great citizen skates")
	await _view("20_rex_at_the_skate_park", rex.global_position + Vector3(4.0, 2.2, 4.0), rex.global_position + Vector3(0, 0.8, 0))
	await _end_talk()
	await create_timer(1.0).timeout
	var lesson := root.get_node("SkateLesson")
	if lesson.active:
		player = _player()
		await _physics(10)
		await _view("21_coach_bruno_s_lesson", player.global_position + Vector3(3.0, 2.5, 4.5), player.global_position + Vector3(0, 0.8, 0), 20)
		lesson.complete("push")
		await create_timer(2.0).timeout
		lesson.complete("ollie")
		await create_timer(0.3).timeout
		lesson.stop()
	game.riding = false
	# Half the day done, for the log
	dialogue.set_flag("fn_gloops")
	dialogue.set_flag("fn_stall")
	await _frames(4)
	menu.open("quests")
	await _frames(6)
	await _shot("22_the_void_day_checklist")
	menu.close()
	await _frames(4)
	for f in ["fn_request", "fn_fountain_watch", "fn_zippy"]:
		dialogue.set_flag(f)
	await _frames(6)
	menu.open("map")
	await _frames(8)
	await _shot("23_the_map_star_on_the_gloop_king")
	menu.close()
	await _frames(4)

	# --- The Gloop King ---
	# (in his own kingdom, through the Gloop Gate: scripts/gloop_kingdom.gd)
	root.get_node("Bosses").enter_kingdom()
	await _frames(12)
	await _physics(4)
	current_scene.call("wake")
	await _physics(60)
	var king := current_scene.find_child("The Gloop King", true, false) as Node3D
	player = _player()
	player.global_position = king.global_position + Vector3(6.0, 0.8, 6.0)
	_face(player, king.global_position)
	await _physics(40)
	await _view("24_the_gloop_king", player.global_position + Vector3(4.0, 3.0, 6.0), king.global_position + Vector3(0, 1.5, 0), 10)
	var guard := 40
	while not king.defeated and guard > 0:
		guard -= 1
		king.shot(1, king.global_position, Vector3.FORWARD)
		await _physics(2)
	await _frames(8)
	await _view("25_hooray", player.global_position + Vector3(3.0, 2.5, 5.0), player.global_position + Vector3(0, 1.2, 0), 4)
	await create_timer(1.0).timeout
	current_scene.call("go_home")
	await _frames(12)
	await _physics(10)
	player = _player()
	_snap("dash")
	await _physics(6)
	dash = _body("dash")
	player.global_position = dash.global_position + Vector3(1.8, 0.5, 1.8)
	_face(player, dash.global_position)
	_face(dash, player.global_position)
	await _physics(4)
	await _talk_until("dash", "Agent of Chaos")
	await _view("26_dash_and_the_agent_of_chaos", player.global_position + Vector3(-2.0, 2.0, 4.0), dash.global_position + Vector3(0, 1.0, 0))
	await _end_talk()
	await _frames(6)
	var head := player.global_position + Vector3(0, 1.2, 0)
	await _view("27_the_gloop_crown", head + player.global_basis.z * 2.2 + Vector3(0.4, 0.4, 0), head, 20)

	# --- Pulled home, into bed ---
	clock.pulls_home = true
	clock.end_shift()
	await _wait_for_scene(EARTH, 240)
	await _frames(10)
	player = _player()
	await _physics(20)
	_make_cam()
	var bed := current_scene.find_child("SleepSpot", true, false) as Node3D
	await _view("28_waking_up_in_bed", bed.global_position + Vector3(2.5, 2.6, 3.2), bed.global_position + Vector3(0, 0.6, 0), 10)
	nina = _body("nina_earth")
	player.global_position = nina.global_position + Vector3(0, 0.5, 2.0)
	_face(player, nina.global_position)
	_face(nina, player.global_position)
	await _physics(4)
	await _talk_until("nina_earth", "happen again")
	await _view("29_will_it_happen_again", nina.global_position + Vector3(3.0, 1.8, 3.2), nina.global_position + Vector3(0, 0.9, 0))
	await _end_talk()
	await _frames(6)
	_finish()


# -----------------------------------------------------------------------------
func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _body(id: String) -> Node3D:
	var t := _talker(id)
	return t.get_parent() as Node3D if t else null


func _snap(id: String) -> void:
	# Straight to where their routine wants them (no walking across town for a screenshot)
	for r in get_nodes_in_group("routines"):
		if r.get("character_id") == id:
			r.call("snap")


func _place(id: String) -> Vector3:
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE if clock.on_earth else TownPaths.FILE)
	var v: Vector2 = paths.points.get(id, Vector2.ZERO)
	return Vector3(v.x, 0, v.y)


func _face(n: Node3D, at: Vector3) -> void:
	var d := at - n.global_position
	n.rotation.y = atan2(d.x, d.z)


func _talk_until(id: String, text: String) -> void:
	# Talk, and stop on the first line that has this in it (the box stays up for the shot)
	var t := _talker(id)
	if t == null:
		return
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 200
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if str(dialogue._text.text).contains(text):
			dialogue._finish_typing()
			return
		if dialogue._choosing:
			dialogue.current_choices()[0].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)


func _end_talk() -> void:
	var guard := 200
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			dialogue.current_choices()[0].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.3).timeout


func _talk_through(id: String) -> void:
	var t := _talker(id)
	if t == null:
		return
	dialogue.talk_to(t)
	await _frames(2)
	await _end_talk()


func _make_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		_make_cam()
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 8) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
