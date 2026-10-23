extends SceneTree

# Screenshots of everyone skating (scripts/rides.gd) in the Practice Park: each rider rolling along on their own ride,
# then a few of their tricks in the air (Dash's backflip, Rook's misty flip, Rex's tail spin, Pip gliding, Bramble's
# tailwhip, Mr. Palmer's Superman-style big wave).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_riders.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const PARK := "res://scenes/skate/test_park.tscn"

var out_dir := "user://rider_shots"
var cam: Camera3D
var p: CharacterBody3D
var s: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(PARK)
	for i in 6:
		await process_frame
	var park := current_scene as Node3D
	p = park.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	cam = Camera3D.new()
	cam.fov = 45
	park.add_child(cam)
	game.message("")
	p.get_node("HUD").visible = false

	# Each rider rolling along, seen from the front and side
	var n := 1
	for id in Rides.ORDER:
		p.set_rider(id)
		_place(Vector3(-30, 0.9, 30), PI)
		p.velocity = Vector3(0, 0, -5)
		Input.action_press("move_forward")
		for i in 30:
			await physics_frame
		Input.action_release("move_forward")
		var at := p.global_position
		await _view("%02d_%s" % [n, id], at + Vector3(-2.6, 0.9, -3.4), at + Vector3(0, 0.1, 0))
		n += 1

	# Tricks, held halfway, high over the open corner
	for shot in [["dash", "up", "backflip"], ["rook", "", "misty_flip"], ["rex", "", "tail_spin"], ["bramble", "", "tailwhip"]]:
		p.set_rider(shot[0])
		_place(Vector3(-30, 4.0, 30), PI)
		s._pop()
		s.tricks.start_flip(shot[1])
		s.tricks.flip.time = float(s.tricks.flip.duration) * 0.4
		p.set_physics_process(false)
		s._shown_yaw = PI
		s._pose(1.0)
		await _view("%02d_%s_%s" % [n, shot[0], shot[2]], p.global_position + Vector3(-3.2, 0.4, -2.4), p.global_position)
		p.set_physics_process(true)
		n += 1
	# Mr. Palmer waving big in the air
	p.set_rider("mr_palmer")
	_place(Vector3(-30, 4.0, 30), PI)
	s._pop()
	s.tricks.start_grab("right")
	for i in 20:
		s._pose(0.05)
	p.set_physics_process(false)
	await _view("%02d_mr_palmer_big_wave" % n, p.global_position + Vector3(-3.2, 0.4, -2.4), p.global_position)
	p.set_physics_process(true)
	n += 1
	# Pip gliding down on her wings
	p.set_rider("pip")
	_place(Vector3(-30, 5.0, 30), PI)
	s._pop()
	p.velocity = Vector3(0, -2, -4)
	Input.action_press("jump")
	for i in 10:
		await physics_frame
	Input.action_release("jump")
	p.set_physics_process(false)
	await _view("%02d_pip_gliding" % n, p.global_position + Vector3(-3.4, 0.2, -2.6), p.global_position)
	p.set_physics_process(true)
	_finish()


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s.tricks.lose()
	s.state = s.State.ROLL
	s._yaw = yaw
	s._shown_yaw = yaw
	p.get_node("Visual").basis = Basis(Vector3.UP, yaw)
	(p.get_node("SpringArm3D") as Node3D).rotation = Vector3(-0.3, yaw + PI, 0)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
