extends SceneTree

# Screenshots of Melody's groove and her stage, Rhythm Springs' reward (scripts/groove.gd, scripts/melody_stage.gd):
# Melody teaching it in Rhythm Springs, the hero grooving with the ring of notes, Gloops dancing, a big on-the-beat
# ring, the stage by her portal in the day, and her evening show with the hero dancing up there with her. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_groove.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.groove_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.groove_capture_backup.cfg"

var out_dir := "user://groove_shots"
var cam: Camera3D
var _had_save := false
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
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
	clock.set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)
	await _teaching()
	await _grooving()
	await _stage()
	_finish()


func _teaching() -> void:
	portals.enter("rhythm_springs")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var mel := (s.get_node("Melody") as Node3D).global_position
	p.global_position = mel + Vector3(-1.2, 0.9, 2.4)
	s.set_cool(1.0)
	s.mend()
	s.set_cool(1.0)
	_cam_in(s)
	await create_timer(s.TEACH_AFTER + 1.5).timeout
	root.get_node("Dialogue")._finish_typing()
	_look(mel + Vector3(-3.4, 2.0, 4.6), mel + Vector3(0.4, 1.0, 0))
	await _frames(4)
	await _shot("01_melody_teaches_her_groove")
	root.get_node("Dialogue").end()


func _grooving() -> void:
	root.get_node("Game").go("res://scenes/town/town.tscn", "", "")
	await _frames(20)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var rem := root.get_node("Remnants")
	var spot: Vector3 = rem.ground_at(Vector2(-18.0, 50.0))
	p.global_position = spot + Vector3(0, 1.0, 0)
	await _physics(20)
	# Three Gloops round the hero
	var gloops: Array = []
	for e in get_nodes_in_group("enemies"):
		if e is CharacterBody3D and str(e.name).begins_with("Gloop") and not e.get("defeated") and gloops.size() < 3:
			gloops.append(e)
	for i in gloops.size():
		var a := i * TAU / 3.0 + 0.5
		(gloops[i] as Node3D).global_position = p.global_position + Vector3(sin(a) * 3.2, 0.3, cos(a) * 3.2)
	await _physics(4)
	_cam_in(s)
	var g := p.get_node("Groove")
	_groove(g)
	await create_timer(0.22).timeout
	_look(p.global_position + Vector3(5.5, 3.2, 6.5), p.global_position + Vector3(0, 0.6, 0))
	await _shot("02_groove_ring_of_notes")
	await create_timer(0.8).timeout
	_look(p.global_position + Vector3(-5.0, 2.6, 5.5), p.global_position + Vector3(0, 0.6, 0))
	await _shot("03_gloops_cant_help_dancing")
	_count = 0
	for k in 4:
		_groove(g)
		await create_timer(0.05).timeout
	g._last_at = g.now()
	await create_timer(0.12).timeout
	_look(p.global_position + Vector3(7.0, 6.0, 8.0), p.global_position)
	await _shot("04_in_the_groove_x4_big_ring")
	for e in gloops:
		(e as Node3D).global_position += Vector3(0, 0, 300)
	await create_timer(0.6).timeout


func _stage() -> void:
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var stage := s.get_node("Portals/Melody's Stage") as Node3D
	var front := stage.global_basis.z
	var portal := s.get_node("Portals/Portal rhythm_springs") as Node3D
	p.global_position = stage.global_position + front * 7.0 + front.cross(Vector3.UP) * 3.0 + Vector3(0, 1.0, 0)
	await _physics(10)
	_look(stage.global_position + front * 10.0 + front.cross(Vector3.UP) * -9.0 + Vector3(0, 9.0, 0),
		stage.global_position.lerp(portal.global_position, 0.35) + Vector3(0, 1.5, 0))
	await _frames(10)
	await _shot("05_melodys_stage_by_her_portal")
	# Evening: the show
	root.get_node("Clock").set_time(3, 19 * 60.0 + 30.0, true)
	await _physics(20)
	p.global_position = stage.global_position + front * 1.9 + front.cross(Vector3.UP) * 1.0 + Vector3(0, 1.2, 0)
	await _physics(20)
	var g := p.get_node("Groove")
	_count = 0
	for k in 4:
		_groove(g)
		await create_timer(0.1).timeout
	await create_timer(0.15).timeout
	_look(stage.global_position + front * 7.5 + front.cross(Vector3.UP) * 2.0 + Vector3(0, 5.0, 0), stage.global_position + Vector3(0, 1.4, 0))
	await _shot("06_melodys_evening_show_dance_off")
	for k in 4:
		_groove(g)
		await create_timer(0.05).timeout
	await create_timer(0.3).timeout
	_look(stage.global_position + front * 6.5 + front.cross(Vector3.UP) * -3.0 + Vector3(0, 4.5, 0), stage.global_position + Vector3(0, 1.4, 0))
	await _shot("07_encore")


var _count := 0


func _groove(g: Node) -> void:
	# On the next beat. (Software rendering here is slow, so the streak is kept up by hand between grooves: in the
	# game a beat is a beat.)
	g.clock_offset += g.BEAT - fposmod(g.now(), g.BEAT)
	g.streak = _count
	if _count > 0:
		g._last_at = g.now() - g.BEAT
	_count += 1
	g.cooldown = 0.0
	g.try_groove()


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
