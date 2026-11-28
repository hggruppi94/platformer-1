extends SceneTree

# Pictures for the whole game's detail treatment (16 Nov 2026): the Void's Market Square with its six detailed stalls
# (scripts/detail_props.gd dress_void), by day and at night, and a wide view of the town. With --old-props it shoots
# the same spots with everything the pipeline adds turned off (no detailed props, no merging, no LODs), so the two sets
# make a before and after. With --studio it shoots each stall on its own: the very detailed version
# (models/props/_preview/market_stall_<kind>_high_preview.glb, from the build script's --preview, not used by the game)
# beside the light baked one the game draws.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_all.gd -- <folder> [--old-props] [--studio]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_all_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_all_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const MARKET := Vector3(-72, 0.0, 42)           # the fountain (tools/build_town.gd MARKET)
const STALLS := [["fruit", 30.0], ["sweets", 60.0], ["crystals", 120.0], ["flowers", 150.0], ["records", 210.0],
	["toys", 330.0]]

var out_dir := "user://detail_all_shots"
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
	if "--studio" in args:
		await _studio()
		_finish()
		return
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
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	change_scene_to_file(TOWN)
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position = Vector3(40, 2, 120)            # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 3000
	current_scene.add_child(cam)
	cam.make_current()
	var views := [["01_market", MARKET + Vector3(4, 5.5, 25), MARKET + Vector3(0, 1.2, 0), 11.0]]
	var i := 2
	for st in STALLS:
		var d := Vector3(cos(deg_to_rad(st[1])), 0, sin(deg_to_rad(st[1])))
		var side := d.cross(Vector3.UP) * 1.4
		views.append(["%02d_stall_%s" % [i, st[0]], MARKET + d * 7.6 + side + Vector3(0, 1.75, 0),
			MARKET + d * 12.0 + Vector3(0, 1.3, 0), 15.0])
		i += 1
	views.append(["08_market_dusk", MARKET + Vector3(-14, 3.0, 16), MARKET + Vector3(2, 1.5, -2), 18.2])
	views.append(["09_market_night", MARKET + Vector3(4, 5.5, 25), MARKET + Vector3(0, 1.2, 0), 22.0])
	views.append(["10_over_the_void", Vector3(0, 60, 110), Vector3(0, 0, 0), 11.0])
	views.append(["11_gloop_kingdom_view", Vector3(-112, 9, -3), Vector3(-230, 22, -3), 11.0])
	for v in views:
		clock.set_time(3, v[3] * 60.0, true)
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])


func _studio() -> void:
	# Each stall twice on a plain floor: left the very detailed version, right the one the game draws
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 35, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	w.add_child(sun)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.48, 0.66)
	floor_m.material_override = fm
	w.add_child(floor_m)
	cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.make_current()
	for st in STALLS:
		var kind: String = st[0]
		var hi_path := "res://models/props/_preview/market_stall_%s_high_preview.glb" % kind
		var lo_path := "res://models/props/void_town/market_stall_%s.glb" % kind
		if not ResourceLoader.exists(lo_path):
			continue
		var parts := []
		for side in [-1.0, 1.0]:
			var path := hi_path if side < 0 else lo_path
			if not ResourceLoader.exists(path):
				continue
			var m := (load(path) as PackedScene).instantiate() as Node3D
			m.position = Vector3(side * 1.6, 0, 0)
			w.add_child(m)
			parts.append(m)
		cam.global_position = Vector3(0, 2.3, 7.4)
		cam.look_at(Vector3(0, 1.2, 0))
		await _shot("studio_" + kind)
		cam.global_position = Vector3(1.6, 1.7, 2.4)
		cam.look_at(Vector3(1.6, 1.0, 0))
		await _shot("studio_%s_close_game" % kind)
		cam.global_position = Vector3(-1.6, 1.7, 2.4)
		cam.look_at(Vector3(-1.6, 1.0, 0))
		await _shot("studio_%s_close_detailed" % kind)
		for x in parts:
			x.queue_free()
		await process_frame


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
