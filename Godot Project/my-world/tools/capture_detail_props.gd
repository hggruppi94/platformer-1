extends SceneTree

# Pictures for the detailed props pipeline (15 Nov 2026): the town green in Stars Hollow with the detailed lamps,
# benches and gazebo (scripts/detail_props.gd), and with --old-props the builder's old ones, from the same spots, so
# the two sets make a before and after. With --studio it shoots each prop on its own instead: the very detailed
# version (models/props/_preview/<name>_high_preview.glb, made with the build script's --preview, not used by the
# game) beside the light baked one the game draws.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_props.gd -- <folder> [--old-props] [--studio]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.props_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.props_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const PROPS := ["street_lamp", "park_bench", "gazebo"]

# name: [eye, look at, hour]
const VIEWS := [
	["01_green_gazebo", Vector3(9.0, 1.7, 11.0), Vector3(0, 2.6, 0), 11.0],
	["02_gazebo_close", Vector3(3.2, 1.8, 8.2), Vector3(0, 2.8, 0), 15.0],
	["03_gazebo_roof", Vector3(-4.5, 3.0, 7.5), Vector3(0, 4.3, 0), 15.0],
	["04_bench_and_gazebo", Vector3(9.5, 1.3, 7.6), Vector3(5.6, 0.6, 3.6), 11.0],
	["05_lamps_round_the_green", Vector3(-17.0, 1.7, 21.0), Vector3(6, 2.5, 18.5), 11.0],
	["06_lamp_close", Vector3(11.8, 2.3, 20.6), Vector3(14.0, 3.0, 17.1), 16.0],
	["07_main_street", Vector3(-1.5, 1.7, -32), Vector3(0, 2.2, -80), 11.0],
	["08_green_at_dusk", Vector3(12, 2.2, 14), Vector3(-2, 2.5, -2), 18.4],
	["09_green_at_night", Vector3(9.0, 1.7, 11.0), Vector3(0, 2.6, 0), 21.5],
]

var out_dir := "user://props_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
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
	clock.on_earth = true
	clock.set_earth_time(11 * 60.0, true)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
	change_scene_to_file(EARTH)
	for i in 16:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		var hud := player.get_node_or_null("HUD") as CanvasLayer
		if hud:
			hud.visible = false
		player.global_position = Vector3(40, 0.5, 70)          # out of the shots
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false                  # the minimap and the rest of the HUD
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
	current_scene.add_child(cam)
	for v in VIEWS:
		clock.set_earth_time(v[3] * 60.0, true)
		cam.make_current()
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])


func _studio() -> void:
	# Each prop twice on a plain floor: left the very detailed version, right the one the game draws
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
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
	fm.albedo_color = Color(0.42, 0.52, 0.36)
	floor_m.material_override = fm
	w.add_child(floor_m)
	cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.make_current()
	var frames := {"street_lamp": [Vector3(0, 2.6, 7.2), Vector3(0, 2.4, 0), 0.75],
		"park_bench": [Vector3(0, 1.1, 3.6), Vector3(0, 0.45, 0), 1.15],
		"gazebo": [Vector3(0, 4.0, 25.0), Vector3(0, 2.6, 0), 5.3]}
	for p in PROPS:
		var hi_path := "res://models/props/_preview/%s_high_preview.glb" % p
		var lo_path := "res://models/props/%s.glb" % p
		if not ResourceLoader.exists(lo_path):
			continue
		var f: Array = frames[p]
		var at_x: float = f[2]
		var parts := []
		for side in [-1.0, 1.0]:
			var path := hi_path if side < 0 else lo_path
			if not ResourceLoader.exists(path):
				continue
			var m := (load(path) as PackedScene).instantiate() as Node3D
			m.position = Vector3(side * f[2], 0, 0)
			w.add_child(m)
			parts.append(m)
			var tag := Label3D.new()
			tag.text = ("Detailed (%s triangles)" if side < 0 else "What the game draws (%s triangles)") % _tris(m)
			tag.font_size = 64 if p != "gazebo" else 160
			tag.pixel_size = 0.0025
			tag.position = Vector3(side * f[2], -0.05, 1.0 if p != "gazebo" else 5.5)
			tag.rotation_degrees.x = -50
			tag.outline_size = 12
			w.add_child(tag)
			parts.append(tag)
		cam.global_position = f[0]
		cam.look_at(f[1])
		await _shot("studio_" + p)
		var close: Vector3 = (f[0] - f[1]) * 0.42 + f[1] + Vector3(f[2], 0, 0)
		cam.global_position = close
		cam.look_at(f[1] + Vector3(f[2], 0, 0))
		await _shot("studio_%s_close_game" % p)
		cam.global_position = close - Vector3(2 * f[2], 0, 0)
		cam.look_at(f[1] - Vector3(f[2], 0, 0))
		await _shot("studio_%s_close_detailed" % p)
		for x in parts:
			x.queue_free()
		await process_frame


func _tris(n: Node) -> String:
	var t := 0
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var a := m.surface_get_arrays(s)
			var idx = a[Mesh.ARRAY_INDEX]
			t += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return "{0}".format([String.num_int64(t)]) if t < 1000 else "%d,%03d" % [t / 1000, t % 1000]


func _shot(file: String) -> void:
	for i in 10:
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
	quit()
