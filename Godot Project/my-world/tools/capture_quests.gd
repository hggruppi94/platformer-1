extends SceneTree

# Screenshots of Rex's campaign (res://quests/rex_campaign.json): Rex asking Nina for help, the quest note and log,
# the "I'm REX! He's the dog!" report, hanging posters, the rally at the fountain, Mr. Palmer's window, the ending
# and Nina's sash. Opens a window (screenshots need rendering, so not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_quests.gd -- <output folder>
#
# The folder defaults to user://quest_shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const Q := "rex_campaign"
const ASKED := ["asked_dash", "asked_bramble", "asked_pip", "asked_rook"]
const POSTERS := ["poster_1", "poster_2", "poster_3", "poster_4"]

var out_dir := "user://quest_shots"
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var player: Node3D
var cam: Camera3D
var talkers := {}
var spots := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(220.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.pending_message = ""
	game.items.clear()
	dialogue.reset()
	quests.reset()
	change_scene_to_file(TOWN)
	await _frames(5)
	await _in_town()
	player.get_node("HUD").visible = false

	# Day 1: Rex asks (she voted for him), the note, the log
	await _at(1, 10 * 60 + 30.0)
	dialogue.flags["voted_rex"] = true
	dialogue.talks["rex"] = 2
	await _talk_until("rex", "", "01_rex_asks_nina_to_help")
	await _finish_talk([0])
	await create_timer(0.4).timeout
	await _capture("02_new_quest_note")
	dialogue.flags["asked_dash"] = true
	dialogue.flags["asked_bramble"] = true
	quests.toggle_log()
	await _frames(4)
	await _capture("03_quest_log")
	quests.toggle_log()

	# The report, with the dog gag
	for f in ASKED:
		dialogue.flags[f] = true
	quests.load_data({Q: {"step": 1, "since_day": 1}})
	await _at(1, 15 * 60.0)
	await _talk_until("rex", "I'm REX! He's the dog!", "04_im_rex_hes_the_dog")
	await _finish_talk()

	# Day 2: posters
	quests.load_data({Q: {"step": 2, "since_day": 1}})
	await _at(2, 10 * 60.0)
	await _near_spot(1)
	await _capture("05_poster_spot_prompt")
	_press("interact")
	await create_timer(0.6).timeout
	await _look_at_spot(1, Vector3(2.2, 1.0, 2.6))
	await _capture("06_poster_on_a_signpost")
	for f in POSTERS:
		dialogue.flags[f] = true
	quests.load_data({Q: {"step": 3, "since_day": 2}})
	await _near_spot(4)
	await _look_at_spot(4, Vector3(0, 0.9, 4.2))
	await _capture("07_poster_on_the_market_noticeboard")

	# The rally at the fountain, in the evening
	await _at(2, 18 * 60 + 40.0)
	await _talk_until("rex", "", "08_rally_at_the_fountain_pick_a_line", Vector3(-72, 0, 42))
	await _finish_talk([1])

	# Day 3: Mr. Palmer's window, and his answer
	quests.load_data({Q: {"step": 4, "since_day": 2}})
	await _at(3, 10 * 60.0)
	var win := talkers["mr_palmer"].get_parent() as Node3D
	player.global_position = win.global_position + win.global_basis.z * 0.5 + Vector3(0, 0.6, 0)
	player.get_node("Visual").rotation.y = win.global_rotation.y + PI
	for i in 8:
		await physics_frame
	cam.global_position = win.global_position + win.global_basis.z * 6.0 - win.global_basis.x * 2.5 + Vector3(0, 2.4, 0)
	cam.look_at(win.global_position + Vector3(0, 2.2, -1.2))
	await _frames(4)
	await _capture("09_mr_palmers_window")
	_press("interact")
	await _frames(3)
	await _advance_until("the answer is no")
	await _capture("10_mr_palmer_says_not_this_year")
	await _finish_talk()

	# The ending
	quests.check()
	await _talk_until("rex", "about listening", "11_rex_learns_its_about_listening")
	await _finish_talk()
	await create_timer(0.5).timeout
	await _capture("12_quest_complete_note")
	# Nina in her sash next to Future Mayor Rex, in the open by the fountain
	var rex := talkers["rex"].get_parent() as Node3D
	var nina_at := _ground(Vector2(-72.8, 57.0)) + Vector3(0, 0.85, 0)
	player.global_position = nina_at
	player.get_node("Visual").rotation.y = 0.0
	for i in 6:
		await physics_frame
	rex.global_position = _ground(Vector2(-70.9, 57.3))
	rex.rotation.y = -0.6
	cam.global_position = nina_at + Vector3(1.0, 0.9, 4.6)
	cam.look_at(nina_at + Vector3(1.0, 0.2, 0))
	await _frames(3)
	await _capture("13_future_mayor_rex_and_ninas_sash")
	cam.global_position = nina_at + Vector3(0, 0.45, 1.9)
	cam.look_at(nina_at + Vector3(0, 0.1, 0))
	await _frames(4)
	await _capture("14_sash_close_up")
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()


func _at(day: int, minutes: float) -> void:
	clock.set_time(day, minutes, true)
	quests.check()
	await create_timer(2.5).timeout                  # sky, lamps and routines catch up


func _talk_until(id: String, text: String, file: String, look := Vector3.INF) -> void:
	# Talk to id and go on until a line has `text` in it ("" = up to the first question), then take the picture
	await _stand_by(id, look)
	if dialogue._nearest == talkers[id]:
		_press("interact")
	else:
		dialogue.talk_to(talkers[id])
	await _frames(3)
	await _advance_until(text)
	await create_timer(0.8).timeout
	await _capture(file)


func _advance_until(text: String) -> void:
	var guard := 60
	while dialogue.is_active() and not dialogue._choosing and guard > 0:
		guard -= 1
		dialogue._finish_typing()
		if text != "" and dialogue._text.text.contains(text):
			return
		_press("interact")
		await _frames(3)
	dialogue._finish_typing()


func _finish_talk(picks: Array = []) -> void:
	while dialogue.is_active():
		if dialogue._choosing:
			dialogue.current_choices()[picks.pop_front() if picks.size() else 0].pressed.emit()
		else:
			dialogue._finish_typing()
			_press("interact")
		await _frames(3)
	await create_timer(0.3).timeout


func _stand_by(id: String, look := Vector3.INF) -> void:
	# Nina a step from them, the camera off to the side looking at the two of them (or at `look` past them)
	await _in_town()
	for i in 4:
		await physics_frame
	var who := talkers[id].get_parent() as Node3D
	var at := who.global_position
	var side := Vector3(1.7, 0, 0.6).normalized()
	for k in 24:
		var s := Vector3(1.7, 0, 0.6).normalized().rotated(Vector3.UP, k * TAU / 24.0)
		var spot := at + s * 1.7
		var others := talkers.values().filter(func(t: Node3D) -> bool:
			return t != talkers[id] and t.global_position.distance_to(spot) < 3.2)
		if others.is_empty():
			side = s
			break
	player.global_position = at + side * 1.7 + Vector3(0, 0.6, 0)
	player.set("velocity", Vector3.ZERO)
	player.get_node("Visual").rotation.y = atan2(-side.x, -side.z)
	for i in 8:
		await physics_frame
	var mid := (at + player.global_position) / 2.0
	var across := side.cross(Vector3.UP).normalized()
	if look != Vector3.INF:
		var away := Vector3(mid.x - look.x, 0, mid.z - look.z).normalized()
		cam.global_position = mid + away * 4.5 + across * 2.0 + Vector3(0, 2.2, 0)
		cam.look_at(Vector3(look.x, mid.y + 0.6, look.z).lerp(mid, 0.6))
	else:
		cam.global_position = mid + across * 4.2 + Vector3(0, 1.7, 0)
		cam.look_at(mid + Vector3(0, 0.6, 0))
	await _frames(3)


func _near_spot(k: int) -> void:
	await _in_town()
	var spot: Area3D = spots[k]
	var to_cam := Vector3(1.3, 0, 0.4)
	player.global_position = spot.global_position + to_cam + Vector3(0, 0.8, 0)
	player.set("velocity", Vector3.ZERO)
	player.get_node("Visual").rotation.y = atan2(-to_cam.x, -to_cam.z)
	for i in 10:
		await physics_frame
	cam.global_position = spot.global_position + Vector3(5.0, 2.6, 3.0)
	cam.look_at(spot.global_position + Vector3(0, 1.4, 0))
	await _frames(4)


func _look_at_spot(k: int, offset: Vector3) -> void:
	var spot: Area3D = spots[k]
	var poster := spot.get_node("Done").get_child(0) as Node3D
	var p := poster.global_position
	var out := poster.global_basis.z
	cam.global_position = p + out * offset.z + poster.global_basis.x * offset.x + Vector3(0, offset.y, 0)
	cam.look_at(p)
	await _frames(4)


func _ground(xz: Vector2) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 80, xz.y), Vector3(xz.x, -20, xz.y))
	var skip: Array[RID] = TownPaths.skip_rids(current_scene)
	skip.append((player as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(xz.x, 0, xz.y)


func _in_town() -> void:
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		await _frames(5)
	player = current_scene.find_child("Player", true, false)
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		talkers[t.get("character_id")] = t
	for s in current_scene.find_children("Poster Spot *", "Area3D", true, false):
		spots[int(str(s.name).get_slice(" ", 2))] = s
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		cam = Camera3D.new()
		cam.fov = 60
		current_scene.add_child(cam)
	cam.make_current()


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file, "  ", clock.call("time_string"))
