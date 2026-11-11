extends SceneTree

# Screenshots of who you meet and in what order (scripts/meetings.gd; tools/test_meetings.gd checks it): Dash's shut
# stall, Rex sending you after Dash, the glowing tyre tracks and a dropped bit, Dash in his lab, the runaway Buzz Bot,
# and Melody asking for Heather. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_meetings.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.meetings_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://meetings_shots"
var game: Node
var dialogue: Node
var quests: Node


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
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	var clock := root.get_node("Clock")
	root.get_node("Settings").tips = false
	game.hold_saves = true
	game._resume = {}
	dialogue.reset()
	quests.reset()
	dialogue.flags["fresh_start"] = true
	dialogue.flags["void_intro_seen"] = true
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(2, 10 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(20)

	# --- Dash's stall, shut ---
	var stall: Node3D = null
	for n in current_scene.find_children("*", "Area3D", true, false):
		if str(n.get("stall")) == "Gadget":
			stall = n
	if stall:
		_look_at(stall.global_position, 4.5)
		await _frames(20)
		stall.use()
		await _frames(4)
		dialogue._finish_typing()
		await _shot("01_dashs_stall_gone_tinkering", 10)
		await _through()

	# --- Rex sends you after his twin ---
	dialogue.flags["first_night_start"] = true
	for f in ["fn_v2", "fn_v3", "fn_v4"]:
		dialogue.flags[f] = true
	quests.check()
	quests.state["first_night"] = {"step": 8, "since_day": clock.day, "done": false}
	dialogue.flags["skate_lesson_push"] = true
	dialogue.flags["skate_lesson_ollie"] = true
	var rex := _talker("rex")
	if rex:
		var rb := rex.get_parent() as Node3D
		rb.global_position = Vector3(41.0, rb.global_position.y, 47.0)       # (at the Skate Park, where his day has him)
		await _frames(4)
		_look_at(rb.global_position, 2.4)
		await _frames(20)
		dialogue.talk_to(rex)
		await _frames(4)
		for i in 2:
			dialogue._finish_typing()
			dialogue._next()
			await _frames(3)
		dialogue._finish_typing()
		await _shot("02_rex_sends_you_after_dash", 10)
		await _through()
	quests.check()
	await _frames(40)

	# --- The tracks and a dropped bit ---
	var part := current_scene.get_node_or_null("Dash's Gadget Bit 2") as Node3D
	if part:
		_look_at(part.global_position, 3.0, Vector3(0.3, 0, 1))
		await _shot("03_tyre_tracks_and_a_dropped_bit", 30)
	for i in 3:
		dialogue.set_flag("bb_part_%d" % (i + 1))
	quests.check()
	await create_timer(4.0).timeout

	# --- Dash in his lab ---
	var dash := _talker("dash")
	if dash:
		var body := dash.get_parent() as Node3D
		body.global_position = Vector3(97.5, body.global_position.y, -16.0)
		_look_at(body.global_position, 2.6, Vector3(-1, 0, 0.3))
		await _frames(20)
		dialogue.talk_to(dash)
		await _frames(4)
		dialogue._finish_typing()
		await _shot("04_dash_in_his_lab", 10)
		await _through()
	quests.check()
	await _frames(40)
	var bot := current_scene.get_node_or_null("Runaway Buzz Bot") as Node3D
	if bot:
		_look_at(Vector3(92.5, bot.global_position.y, -16), 6.0, Vector3(0.4, 0, 1))
		await _shot("05_the_runaway_buzz_bot", 40)

	# --- Melody asks for Heather ---
	dialogue.set_flag("meet_friends_start")
	quests.check()
	await _frames(20)
	var melody := _talker("melody")
	if melody:
		_look_at((melody.get_parent() as Node3D).global_position, 2.6)
		await _frames(20)
		dialogue.talk_to(melody)
		await _frames(4)
		for i in 3:
			dialogue._finish_typing()
			dialogue._next()
			await _frames(3)
		dialogue._finish_typing()
		await _shot("06_melody_wants_heather_to_hear_her_song", 10)
		await _through()
	_finish()


func _look_at(at: Vector3, dist: float, from_dir := Vector3(0, 0, 1)) -> void:
	# Stand the player a little way off, facing it, so the camera behind them looks at it
	var p := current_scene.find_child("Player", true, false) as Node3D
	var d := from_dir.normalized()
	p.global_position = at + d * dist + Vector3.UP * 0.5
	p.get_node("Visual").look_at(Vector3(at.x, p.global_position.y, at.z), Vector3.UP)
	var arm := p.find_child("SpringArm3D", true, false) as Node3D
	if arm:
		arm.global_rotation = Vector3(-0.25, atan2(d.x, d.z), 0)


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _through() -> void:
	var guard := 100
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			dialogue.current_choices()[0].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await _frames(10)


func _shot(file: String, settle := 8) -> void:
	await _frames(settle)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
