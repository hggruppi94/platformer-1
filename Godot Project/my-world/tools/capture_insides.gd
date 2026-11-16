extends SceneTree

# Pictures for the buildings' insides (16 Nov 2026): Stars Hollow's rooms you walk straight into (scripts/insides.gd)
# and the Void's rooms behind its domes' doors (tools/build_interiors.gd). With --studio it shoots each baked
# furniture prop on its own instead: the very detailed version (models/props/_preview/<name>_high_preview.glb, made
# with tools/build_prop_furniture.py --preview, not used by the game) beside the light baked one the game draws.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_insides.gd -- <folder> [--studio] [--before]
#
# --all also shoots every other Stars Hollow room (from the doorway and from inside) and the Void's other rooms.
# --before shoots Stars Hollow with the insides off (the old solid boxes), for a before and after.
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.insides_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.insides_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const PROPS := ["diner_booth", "diner_stool", "mayor_desk", "bookshelf", "armchair", "school_desk"]
const INSIDES := preload("res://scripts/insides.gd")
# --all: the Void's other rooms, each from its door and from the middle looking back round
const VOID_ROOMS := ["museum", "library", "potion_shop", "book_store", "pet_shop", "gaming_station", "dashs_house",
	"melanies_house", "empty_home_2", "haunted_house", "toy_store"]

# Stars Hollow: [name, building, eye, look at (both in the building's own space, +Z its front), hour]
const EARTH_VIEWS := [
	["earth_01_diner_from_the_street", "Hollow Diner", Vector3(3.5, 1.8, 11.0), Vector3(0, 1.6, 0), 11.0],
	["earth_02_diner_doorway", "Hollow Diner", Vector3(0.6, 1.6, 6.2), Vector3(0, 1.2, -2.0), 11.0],
	["earth_03_diner_inside", "Hollow Diner", Vector3(-1.6, 1.65, 3.2), Vector3(1.0, 1.1, -3.0), 11.0],
	["earth_04_diner_counter", "Hollow Diner", Vector3(-3.8, 1.5, 0.6), Vector3(1.5, 0.9, -2.6), 11.0],
	["earth_05_diner_booths", "Hollow Diner", Vector3(1.2, 1.5, -1.2), Vector3(4.2, 0.6, 2.4), 11.0],
	["earth_06_diner_at_night", "Hollow Diner", Vector3(3.5, 1.8, 11.0), Vector3(0, 1.6, 0), 21.5],
]
# The Void's rooms: [name, scene, eye, look at]
const VOID_VIEWS := [
	["void_01_town_hall_from_the_door", "res://scenes/interiors/town_hall.tscn", Vector3(0, 1.8, 8.6), Vector3(0, 1.8, -4.0)],
	["void_02_town_hall_desk", "res://scenes/interiors/town_hall.tscn", Vector3(2.6, 1.9, -2.2), Vector3(0, 1.4, -6.6)],
	["void_03_town_hall_map", "res://scenes/interiors/town_hall.tscn", Vector3(-1.5, 2.6, -3.0), Vector3(0, 3.2, -9.3)],
	["void_04_town_hall_clock", "res://scenes/interiors/town_hall.tscn", Vector3(3.0, 1.8, 1.0), Vector3(8.5, 2.0, -3.0)],
	["void_05_town_hall_benches", "res://scenes/interiors/town_hall.tscn", Vector3(-4.5, 2.6, -6.5), Vector3(1.0, 0.6, 3.0)],
]

var out_dir := "user://insides_shots"
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
	root.get_node("WorldDetail").insides = not ("--before" in args)
	change_scene_to_file(EARTH)
	await _settle()
	for v in EARTH_VIEWS:
		var b := current_scene.get_node_or_null(str(v[1])) as Node3D
		if b == null:
			continue
		clock.set_earth_time(v[4] * 60.0, true)
		_look(b.global_transform * (v[2] as Vector3), b.global_transform * (v[3] as Vector3))
		await _shot(("before_" if "--before" in args else "") + str(v[0]))
	if "--all" in args and not "--before" in args:
		clock.set_earth_time(11 * 60.0, true)
		var k := 0
		for name in INSIDES.ROOMS:
			if name == "Hollow Diner":
				continue
			if _only() != "" and _only() != str(name):
				continue
			var b := current_scene.get_node_or_null(str(name)) as Node3D
			if b == null:
				continue
			k += 1
			var size: Vector3 = INSIDES.ROOMS[name].size
			var hd := size.z / 2.0
			var tag := "earth_%02d_%s" % [10 + k, str(name).to_snake_case().replace(" ", "_")]
			_look(b.global_transform * Vector3(0.4, 1.6, hd + 3.0), b.global_transform * Vector3(0, 1.3, -hd))
			await _shot(tag + "_doorway")
			_look(b.global_transform * Vector3(size.x * 0.3, min(2.2, size.y - 0.6), hd - 0.9),
				b.global_transform * Vector3(-size.x * 0.25, 0.9, -hd * 0.6))
			await _shot(tag + "_inside")
	if "--before" in args:
		_finish()
		return
	var last := ""
	for v in VOID_VIEWS:
		if v[1] != last:
			last = v[1]
			change_scene_to_file(str(v[1]))
			await _settle()
		_look(v[2], v[3])
		await _shot(str(v[0]))
	if "--all" in args and _only() == "":
		var k := 5
		for id in VOID_ROOMS:
			change_scene_to_file("res://scenes/interiors/%s.tscn" % id)
			await _settle()
			k += 1
			var e := current_scene.get_node_or_null("Entrance") as Node3D
			var from := e.global_position if e else Vector3(0, 0, 6)
			_look(from + Vector3(0.5, 1.7, 0.8), Vector3(0, 1.3, -6.0))
			await _shot("void_%02d_%s_from_the_door" % [k, id])
			_look(Vector3(-2.0, 2.4, -1.0), from + Vector3(4.0, 0.8, -1.0))
			await _shot("void_%02d_%s_looking_round" % [k, id])
	_finish()


func _only() -> String:
	# --only=<building>: just that Stars Hollow room (and no Void rooms)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			return a.trim_prefix("--only=")
	return ""


func _settle() -> void:
	for i in 20:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player:
		player.global_position += Vector3(0, -50, 0)          # out of the shots
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false                  # the minimap and the rest of the HUD
	cam = Camera3D.new()
	cam.fov = 70
	cam.far = 2000
	current_scene.add_child(cam)
	for i in 10:
		await process_frame


func _look(eye: Vector3, at: Vector3) -> void:
	cam.make_current()
	cam.global_position = eye
	cam.look_at(at)


func _studio() -> void:
	# Each prop twice on a plain floor: left the very detailed version, right the one the game draws
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
	fm.albedo_color = Color(0.55, 0.5, 0.45)
	floor_m.material_override = fm
	w.add_child(floor_m)
	cam = Camera3D.new()
	cam.fov = 40
	w.add_child(cam)
	cam.make_current()
	# [eye, look at, half the gap between the two]
	var frames := {"diner_booth": [Vector3(1.4, 1.5, 3.4), Vector3(0, 0.6, 0), 1.0],
		"diner_stool": [Vector3(0.6, 1.1, 2.0), Vector3(0, 0.45, 0), 0.4],
		"mayor_desk": [Vector3(1.2, 1.7, 4.0), Vector3(0, 0.5, 0), 1.15],
		"bookshelf": [Vector3(1.0, 1.6, 4.2), Vector3(0, 1.0, 0), 0.75],
		"armchair": [Vector3(1.0, 1.4, 3.2), Vector3(0, 0.5, 0), 0.65],
		"school_desk": [Vector3(1.3, 1.5, 3.2), Vector3(0, 0.5, 0.25), 0.6]}
	for p in PROPS:
		if "--new" in OS.get_cmdline_user_args() and p in ["diner_booth", "diner_stool", "mayor_desk"]:
			continue
		var hi_path := "res://models/props/_preview/%s_high_preview.glb" % p
		var lo_path := "res://models/props/furniture/%s.glb" % p
		if not ResourceLoader.exists(lo_path):
			continue
		var f: Array = frames[p]
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
			tag.font_size = 48
			tag.pixel_size = 0.0025
			tag.position = Vector3(side * f[2], 0.02, 0.8)
			tag.rotation_degrees.x = -60
			tag.outline_size = 10
			w.add_child(tag)
			parts.append(tag)
		cam.global_position = f[0]
		cam.look_at(f[1])
		await _shot("studio_" + p)
		var close: Vector3 = (f[0] - f[1]) * 0.5 + f[1] + Vector3(f[2], 0, 0)
		cam.global_position = close
		cam.look_at(f[1] + Vector3(f[2], 0, 0))
		await _shot("studio_%s_close_game" % p)
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
