extends SceneTree

# Screenshots of the race intros (scripts/race_intro.gd): for each track, the title over the swing round the start,
# a moment of the flyover and one rival's hello; the Lake Loop, Meadow Wiggle and Observatory Hill in Galaxity, the
# Pumpkin Run in Stars Hollow, and the Sky Rings. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_race_intros.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_intros_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://race_intro_shots"
var races: Node


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
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	races = root.get_node("Races")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	settings.tips = false
	settings.race_intros = true
	races.reset()
	for k in races.TRACKS:
		races.finished_once[k] = true
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	clock.pulls_home = false

	change_scene_to_file(TOWN)
	await _frames(10)
	var n := 1
	for id in ["lake_loop", "meadow_wiggle", "observatory_hill"]:
		var tn: Node3D = races.track_node(id)
		for i in 60:
			if tn and tn.ready_to_race:
				break
			await physics_frame
		races.start(id)
		n = await _poses(id, n)
		races._end(false)
		await _physics(4)

	# The Sky Rings: in the mothership, through the start ring
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var sky: Node3D = races.track_node("sky_rings")
	var ship: Node3D = get_first_node_in_group("mothership")
	ship.global_position = p.global_position + Vector3.UP * 20.0
	ship.board(p)
	for i in 240:
		if ship.is_piloted():
			break
		await physics_frame
	var s0: Vector3 = sky.point_at(0.0)
	var sf: Vector3 = sky.dir_at(0.0)
	ship.global_position = s0 - sf * 20.0
	await _physics(3)
	ship.global_position = s0 + sf * 2.0
	await _physics(3)
	if races.intro.playing():
		n = await _poses("sky_rings", n)
	races._end(false)
	ship.beam_down()
	await _physics(60)

	# The Pumpkin Run in Stars Hollow, on an autumn afternoon
	game.riding = false
	clock.day = 1
	clock.set_earth_time(15 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(10)
	var et: Node3D = races.track_node("pumpkin_run")
	for i in 60:
		if et.ready_to_race:
			break
		await physics_frame
	races.start("pumpkin_run")
	n = await _poses("pumpkin_run", n)
	races._end(false)
	_finish()


func _poses(id: String, n: int) -> int:
	# Three moments of the intro: the title, halfway round the flyover, and the second rival's hello
	var intro: Node = races.intro
	var times := [1.8, intro.TITLE_TIME + intro.FLY_TIME * 0.45, intro.TITLE_TIME + intro.FLY_TIME + intro.RIVAL_TIME * 1.5]
	var names := ["title", "flyover", "rival"]
	for k in times.size():
		intro._t = times[k]
		if k > 0:
			for l in [intro._title, intro._blurb]:
				l.modulate.a = 0.0
		intro._place_camera()
		await _frames(1)
		intro._t = times[k]
		intro._place_camera()
		# The fades are tweens, so show the words straight away for the picture
		for l in [intro._title, intro._blurb]:
			l.modulate.a = 1.0 if k == 0 else 0.0
		intro._caption.modulate.a = 1.0
		await _shot("%02d_%s_%s" % [n, id, names[k]])
		n += 1
	return n


func _frames(c: int) -> void:
	for i in c:
		await process_frame


func _physics(c: int) -> void:
	for i in c:
		await physics_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
