extends SceneTree

# Close-up screenshots of one character model on its own (face, three-quarter, body) in its idle animation, to check
# the model as the game renders it. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_character.gd -- <model name> <output folder>
#
# e.g. -- mr_palmer C:/temp/shots loads res://models/characters/mr_palmer.glb. The folder defaults to user://.

var out_dir := "user://"
var model := "mr_palmer"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		model = args[0]
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(900, 900))
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-40, -30, 0)
	world.add_child(sun)
	var body: Node3D = load("res://models/characters/%s.glb" % model).instantiate()
	world.add_child(body)
	var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	# Godot faces +Z for glTF -Y forward, so the camera sits on +Z.
	var shots := [
		["face", Vector3(0, 1.36, 0.75), Vector3(0, 1.34, 0)],
		["face_34", Vector3(0.5, 1.38, 0.55), Vector3(0, 1.34, 0)],
		["body_34", Vector3(1.1, 0.95, 1.1), Vector3(0, 0.75, 0)],
		["rosette", Vector3(0.9, 0.75, 0.6), Vector3(0.25, 0.65, 0.2)],
		["full", Vector3(1.5, 1.2, 3.2), Vector3(0, 0.9, 0)],
	]
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in 12:
			await process_frame
		var img := root.get_texture().get_image()
		var path: String = out_dir.path_join("%s_%s.png" % [model, s[0]])
		img.save_png(path)
		print("SHOT ", path)
	quit()
