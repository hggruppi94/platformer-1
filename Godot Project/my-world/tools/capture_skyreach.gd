extends SceneTree

# Shots of the Skyreach Trail and the Starhorn (scripts/skyreach_trail.gd, scripts/starhorn.gd) and the cleft that leads
# there in the Void (scripts/bosses.gd). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skyreach.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.skyreach_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.skyreach_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://skyreach_shots"
var cam: Camera3D
var _had_save := false


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
	game._resume = {}
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	root.get_node("Clock").set_time(2, 15 * 60.0, true)
	var portals := root.get_node("Portals")
	portals.quakes = portals.WORLDS.map(func(w: Dictionary) -> String: return str(w.id))   # (no quake cutscene over the shots)
	var bosses := root.get_node("Bosses")
	var trail: GDScript = load("res://scripts/skyreach_trail.gd")

	# The cleft in the Void
	change_scene_to_file(TOWN)
	await _frames(60)
	await create_timer(1.5).timeout
	var s := current_scene as Node3D
	_hide_hud(s)
	cam = _cam(s)
	var l: Dictionary = bosses.LAIRS["skyreach"]
	var g: Vector3 = bosses.ground(s, l.at.x, l.at.y)
	cam.global_position = g + Vector3(5.0, 3.5, 14.0)
	cam.look_at(g + Vector3(0, 3.5, 0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("01_cleft_far")
	cam.global_position = g + Vector3(1.5, 2.0, 6.5)
	cam.look_at(g + Vector3(-1.0, 2.2, 0), Vector3.UP)
	await create_timer(1.0).timeout
	await _shot("02_cleft_close")

	# The trail
	change_scene_to_file(str(l.scene))
	await _frames(60)
	await create_timer(1.0).timeout
	s = current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	_hide_hud(s)
	cam = _cam(s)
	var top: Vector3 = trail.summit()
	cam.global_position = Vector3(-8.0, 6.0, -4.0)
	cam.look_at(Vector3(10.0, 14.0, 70.0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("03_the_mountain")
	cam.global_position = top + Vector3(-95.0, 20.0, -60.0)
	cam.look_at(top + Vector3(0, -14, 0), Vector3.UP)
	await create_timer(1.0).timeout
	await _shot("04_from_afar")
	# Along the trail, from just behind where you'd be
	for k in 3:
		var a: float = [0.6, 3.6, 7.6][k]
		var at: Vector3 = trail.trail_point(a)
		var behind: Vector3 = trail.trail_point(a - 0.12)
		p.global_position = at + Vector3(0, 1.0, 0)
		cam.global_position = behind + Vector3(0, 3.0, 0) + trail.out_dir(a) * 1.5
		cam.look_at(trail.trail_point(a + 0.25) + Vector3(0, 1.5, 0), Vector3.UP)
		await create_timer(1.0).timeout
		await _shot("05_trail_%d" % (k + 1))
	# The summit, the Starhorn asleep
	p.global_position = top + Vector3(0, 1.0, 24.0)
	cam.global_position = top + Vector3(14.0, 9.0, 22.0)
	cam.look_at(top + Vector3(0, 3.0, 0), Vector3.UP)
	await create_timer(1.5).timeout
	await _shot("06_summit_asleep")
	var boss := s.get_node("The Starhorn") as CharacterBody3D
	cam.global_position = top + Vector3(7.0, 5.0, 9.0)
	cam.look_at(top + Vector3(0, 3.5, 0), Vector3.UP)
	await create_timer(0.8).timeout
	await _shot("07_starhorn_close")
	# Awake, the fight, its warnings
	p.global_position = top + Vector3(3.0, 1.0, 11.0)
	await create_timer(3.0).timeout
	cam.global_position = top + Vector3(18.0, 14.0, 20.0)
	cam.look_at(top + Vector3(0, 1.0, 2.0), Vector3.UP)
	for t in 4:
		await create_timer(1.0).timeout
		await _shot("08_fight_%d" % (t + 1))
	# Phase 2: the shield and the Star Shards
	boss.set("hits", 5)
	boss.set("_daze_hits", 0)
	boss.set("state", 4)                          # (dazed)
	boss.hurt(1)
	await create_timer(3.2).timeout
	cam.global_position = top + Vector3(-20.0, 13.0, 18.0)
	cam.look_at(top + Vector3(0, 2.0, 0), Vector3.UP)
	await create_timer(0.6).timeout
	await _shot("09_shield_and_shards")
	# Calmed: the reward and the chest
	boss.set("state", 6)                          # (knocked over)
	boss.set("phase", 2)
	boss.set("hits", 17)
	boss.set("_daze_hits", 0)
	boss.set("shield_on", false)
	boss.hurt(1)
	await create_timer(1.0).timeout
	await _shot("10_calmed")
	await create_timer(2.5).timeout
	var chest := s.get("_chest") as Node3D
	s.get_node("Treasure Spot").act.call()
	cam.global_position = chest.global_position + Vector3(3.0, 2.4, -4.5)
	cam.look_at(chest.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	await create_timer(1.2).timeout
	await _shot("11_star_chest")
	_finish()


func _hide_hud(s: Node) -> void:
	var p := s.find_child("Player", true, false)
	if p and p.get_node_or_null("HUD"):
		p.get_node("HUD").visible = false


func _cam(s: Node3D) -> Camera3D:
	var c := Camera3D.new()
	c.fov = 60
	c.far = 800.0
	s.add_child(c)
	c.make_current()
	return c


func _frames(count: int) -> void:
	for i in count:
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
