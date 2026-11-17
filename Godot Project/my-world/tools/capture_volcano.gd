extends SceneTree

# Screenshots of the secret volcano tunnel in Rhythm Springs and Old Ember (17 Nov 2026): the crack at the peak's foot,
# the Ember Hall, the tunnel with its steam vents and lava stream, the magma chamber with Old Ember asleep, the fight
# (a lava crack flaring, the Geyser Stones lit), Old Ember calm with the steam lift, and the view from the Crater
# Lookout. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_volcano.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.volcano_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.volcano_capture_backup.cfg"

var out_dir := "user://volcano_shots"
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
	var V: GDScript = load("res://scripts/volcano_depths.gd")
	var L: GDScript = load("res://scripts/rhythm_land.gd")
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var portals := root.get_node("Portals")
	portals.home_calls.enabled = false
	if not portals.is_cleared("rhythm_springs"):
		portals.cleared_worlds.append("rhythm_springs")
	root.get_node("Clock").set("pulls_home", false)
	change_scene_to_file("res://scenes/portal_worlds/rhythm_springs.tscn")
	for i in 900:
		if current_scene != null and current_scene.name == "RhythmSprings":
			break
		await process_frame
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var hud := s.get_node_or_null("Heat HUD")
	if hud:
		hud.visible = false
	var depths := s.get_node(V.NODE) as Node3D
	var boss := depths.get("boss") as CharacterBody3D
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 900
	s.add_child(cam)
	cam.make_current()

	var e: Vector3 = V.mark("entrance")
	var f: Vector3 = depths.call("_crack_facing")
	var side := f.cross(Vector3.UP)
	var hall: Vector3 = V.mark("hall")
	var c: Vector3 = V.mark("chamber")
	var route: Array = []
	for r in V.ROUTE:
		route.append(V.pt(r))
	var mouth: Vector3 = route[route.size() - 1] - c
	mouth.y = 0
	mouth = mouth.normalized()
	var vents: Array = depths.get("_vents")
	var v0: Vector3 = (vents[1] as Node3D).global_position
	var stream := depths.get_node("Ember Tunnel/Lava Stream") as Node3D
	var sa: Vector3 = stream.get_meta("a")
	var sb: Vector3 = stream.get_meta("b")
	var look := depths.find_child("Crater Lookout", true, false) as Node3D
	var stand: Vector3 = look.get_meta("stand")
	var view: Vector3 = look.get_meta("view")
	var arrive: Vector3 = (load("res://tools/build_rhythm_springs.gd") as GDScript).get_script_constant_map()["ARRIVE"]
	var away := Vector3(arrive.x, L.height(arrive.x, arrive.z), arrive.z)   # the beach: out of the boss's way

	# Outside and the tunnel (Old Ember asleep)
	await _pose(p, e + f * 6.0, e + f * 7.0 + side * 2.0 + Vector3(0, 2.2, 0), e + Vector3(0, 1.0, 0), "01_the_crack")
	await _pose(p, e + f * 6.0, e + f * 26.0 + side * 10.0 + Vector3(0, 18.0, 0), L.peak_top(), "02_crack_under_the_peak")
	await _pose(p, hall, hall + (hall - route[1]).normalized() * 3.0 + Vector3(0, 1.8, 0), route[2] + Vector3(0, 0.5, 0), "03_ember_hall")
	await _pose(p, away, route[4] + Vector3(0, 0.3, 0), v0, "04_steam_vent", func() -> void:
		depths.call("puff", vents[1]))
	await _pose(p, away, route[5] + Vector3(0, 0.6, 0), route[7] - Vector3(0, 1.2, 0), "05_lava_stream")
	await _pose(p, away, c + mouth * 10.5 + Vector3(0, 2.2, 0), c + Vector3(0, 1.0, 0), "06_magma_chamber_from_the_way_in")
	await _pose(p, away, c + mouth.rotated(Vector3.UP, 0.6) * 6.5 + Vector3(0, 2.5, 0), c + Vector3(0, 1.2, 0), "07_old_ember_asleep")
	# The fight
	p.global_position = c + mouth * 5.0 + Vector3(0, 1.0, 0)
	await _frames(20)
	p.set("input_locked", true)
	boss.set("state", 1)
	boss.call("_wake")
	await _frames(10)
	boss.set_physics_process(false)          # (holds still for the pictures)
	depths.call("flare_crack", 1)
	await _pose(p, p.global_position - Vector3(0, 1.0, 0), c + mouth.rotated(Vector3.UP, 0.5) * 11.0 + Vector3(0, 6.0, 0), c + Vector3(0, 1.0, 0), "08_old_ember_awake_lava_crack", Callable(), true)
	boss.set("phase", 1)
	boss.set("hits", 5)
	boss.call("_turn_done")
	boss.set("_state_t", 99.0)
	await _pose(p, p.global_position - Vector3(0, 1.0, 0), c + mouth.rotated(Vector3.UP, -0.9) * 8.0 + Vector3(0, 5.0, 0), c, "09_red_hot_and_the_geyser_stones", Callable(), true)
	var st: Array = boss.get("stones")
	(st[0] as Node3D).call("shot", 1, Vector3.ZERO, Vector3.ZERO)
	await _pose(p, p.global_position - Vector3(0, 1.0, 0), (st[0] as Node3D).global_position + mouth * 6.0 + Vector3(0, 3.0, 0),
		(st[0] as Node3D).global_position + Vector3(0, 3.0, 0), "10_geyser", Callable(), true)
	boss.set("state", 4)
	boss.set("phase", 2)
	boss.set("hits", 14)
	boss.set("shield_on", false)
	boss.call("hurt", 1)
	boss.set_physics_process(true)
	p.set("input_locked", false)
	await _frames(30)
	var lift := depths.get_node("Steam Lift") as Node3D
	await _pose(p, away, c + mouth * 7.0 + Vector3(0, 3.2, 0), lift.global_position + Vector3(0, 2.5, 0), "11_old_ember_calm_and_the_steam_lift")
	await _pose(p, stand, stand - view * 3.0 + Vector3(0, 2.0, 0), stand + view * 40.0 - Vector3(0, 14.0, 0), "12_crater_lookout_view")
	await _pose(p, stand, stand + view * 22.0 + Vector3(0, 8.0, 0), stand, "13_crater_lookout_from_outside")
	_finish()


func _pose(p: CharacterBody3D, at: Vector3, from: Vector3, to: Vector3, file: String, then := Callable(), keep := false) -> void:
	if not keep:
		p.global_position = at + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	await _frames(20)
	if then.is_valid():
		then.call()
		await _frames(8)
	await _shot(file)


func _frames(n: int) -> void:
	for i in n:
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
