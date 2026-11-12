extends SceneTree

# Close-ups of one Stars Hollow person on their own, made just as the Earth town makes them (scripts/townsfolk.gd,
# from the look, extras and outfit tools/build_earth.gd gave them in scenes/earth/earth.tscn), to check how they
# look without loading the whole town: the face from the front, three-quarter and side, the back, and head to toe.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_townsfolk.gd -- <name> <output folder>
#
# e.g. -- Nina C:/temp/shots. Nothing is saved, so the save is never touched.

const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://townsfolk_shots"
var who := "Nina"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		who = args[0]
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(900, 900))
	_run.call_deferred()


func _props(name: String) -> Dictionary:
	# Their look, extras and outfit, read straight out of the built scene (no need to make the whole town)
	var state := (load(EARTH) as PackedScene).get_state()
	for i in state.get_node_count():
		if str(state.get_node_name(i)) != name:
			continue
		var got := {}
		for k in state.get_node_property_count(i):
			got[str(state.get_node_property_name(i, k))] = state.get_node_property_value(i, k)
		if got.has("look"):
			return got
	return {}


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.66, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.35
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.75
	sun.rotation_degrees = Vector3(-35, 25, 0)
	world.add_child(sun)
	var props := _props(who)
	if props.is_empty():
		push_error("No one called %s in %s" % [who, EARTH])
		quit(1)
		return
	var p := Node3D.new()
	p.set_script(load("res://scripts/townsfolk.gd"))
	for k in ["look", "extras", "outfit", "model_path"]:
		if props.has(k):
			p.set(k, props[k])
	world.add_child(p)
	var cam := Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	cam.current = true
	var h: float = p.call("height") / 1.39             # the body's head is ~1.1 m up as drawn
	var head := Vector3(0, 1.12 * h, 0)
	# The body faces +Z
	var shots := [
		["1_face", head + Vector3(0, 0.03, 1.0), head],
		["2_face_34", head + Vector3(0.62, 0.06, 0.78), head],
		["3_side", head + Vector3(1.0, 0.03, 0.0), head],
		["4_back", Vector3(0.0, 1.0 * h, -2.0), Vector3(0, 0.75 * h, 0)],
		["5_body", Vector3(0.0, 0.85 * h, 1.7), Vector3(0, 0.7 * h, 0)],
		["6_full", Vector3(1.1, 1.1 * h, 2.6), Vector3(0, 0.72 * h, 0)],
	]
	for i in 20:
		await process_frame
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in 8:
			await process_frame
		var img := root.get_texture().get_image()
		var path: String = out_dir.path_join("%s_%s.png" % [who.to_lower(), s[0]])
		img.save_png(path)
		print("SHOT ", path)
	quit()
