extends SceneTree

# Pictures of the climb up the inside of Grandfather Tock's Clockwork Tower (23 Nov 2026, scripts/clock_tower.gd): the
# Gearworks floor, the walkway spiralling up the wall, the Swinging Hands, a Cog Spool rolling down,
# the goblin snipers on the brass column, the long drop from the top, the Gear Lift and the Clock Floor up top.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_tower_climb.gd -- <folder>
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.tower_climb_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tower_climb_capture_backup.cfg"
const WORLD := "res://scenes/bosses/clock_tower.tscn"

var out_dir := "user://tower_climb_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	change_scene_to_file(WORLD)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	s.set_process(false)
	s.set_physics_process(false)
	var player := s.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(0, 0.5, 2)             # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	var up := Vector3(0, 1.6, 0)
	for k in 2:
		s.call("_spawn_spool")
	var spools: Array = s.get("spools")
	spools[0].s = 0.8
	spools[1].s = 0.62
	for sp in spools:
		s.call("_place_spool", sp)
	for sw in s.get("_swings") as Array:
		(sw.pivot as Node3D).rotation.x = 0.25 * (1 if int(sw.k) % 2 == 0 else -1)
	var pp := func(t: float, r := 23.7) -> Vector3: return s.call("path_point", t, r)
	var ledge: float = s.call("ledge_s")
	var bs: float = s.call("bridge_s")
	var sniper := s.find_child("Sniper Goblin 2", true, false) as Node3D
	var views := []
	views.append(["01_gearworks_looking_up", Vector3(4, 1.6, 56), Vector3(0, 22, 72)])
	views.append(["02_walkway_start", pp.call(0.02) + up, pp.call(0.09) + up * 1.6])
	views.append(["03_swinging_hands", pp.call(0.12) + up * 1.3, pp.call(0.18) + up * 2.2])
	views.append(["04_cog_spool_coming", pp.call(0.72) + up, (spools[0].node as Node3D).global_position])
	views.append(["06_sniper", pp.call(0.42) + up, sniper.global_position + Vector3(0, 0.6, 0)])
	views.append(["07_long_drop", pp.call(0.97, 21.9) + up * 1.2, Vector3(-6, 0, 74)])
	views.append(["08_gear_lift", Vector3(5, 3, 46), Vector3(0, 1, 54)])
	views.append(["09_clock_floor_from_bridge", pp.call(bs, 22.0) + up * 1.4, Vector3(0, 31, 80)])
	views.append(["10_outside_climb_wide", Vector3(0, 16, 50), Vector3(0, 14, 84)])
	# The Clockwork Passage (its pistons and shutters posed, since the tower's frozen for the pictures)
	var pis: Array = s.get("_pistons")
	for k in pis.size():
		pis[k].e = [0.9, 0.0, 0.5][k % 3]
		s.call("_place_ram", pis[k])
	var shs: Array = s.get("_shutters")
	(shs[0].plate as Node3D).position.y = 0.4
	var ps := func(u: float, r := -1.0) -> Vector3: return s.call("passage_point", u, r)
	var mid: float = s.call("pass_mid")
	views.append(["11_walkway_shut", pp.call(ledge - 0.035) + up, pp.call(ledge + 0.01) + up * 0.8])
	views.append(["12_into_the_passage", pp.call(ledge, 26.0) + up, pp.call(ledge, 31.5) + up * 0.7])
	views.append(["13_pistons", ps.call(0.04) + up, ps.call(0.24) + up * 0.6])
	views.append(["14_tick_tock_shutters", ps.call(0.34) + up, ps.call(0.52) + up * 0.6])
	views.append(["15_key_room", ps.call(0.66, PASS_IN_R) + up, ps.call(0.66, 37.0) + up * 0.5])
	views.append(["16_cog_door", ps.call(0.8) + up, ps.call(0.93) + up * 0.9])
	views.append(["17_passage_way_out", pp.call(float(s.call("exit_s")), mid) + up, pp.call(float(s.call("exit_s")), 22.0) + up * 0.6])
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	_finish()


const PASS_IN_R := 29.0


func _shot(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0)
