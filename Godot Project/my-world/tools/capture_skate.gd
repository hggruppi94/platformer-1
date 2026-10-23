extends SceneTree

# Screenshots of the skating in the Practice Park (scenes/skate/test_park.tscn): the park from above, Nina rolling
# with the camera behind her, crouching for an ollie, flying over a rail, a vert air in the halfpipe, grinding the
# handrail with the balance meter up, and a bail with stars round her head.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skate.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const PARK := "res://scenes/skate/test_park.tscn"

var out_dir := "user://skate_shots"
var cam: Camera3D
var p: CharacterBody3D
var s: Node
var arm: SpringArm3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
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
	arm = p.get_node("SpringArm3D") as SpringArm3D
	s.rng.seed = 3
	cam = Camera3D.new()
	cam.fov = 55
	park.add_child(cam)
	game.message("")

	# 1. The whole park from above the start
	cam.make_current()
	await _view("01_practice_park", Vector3(8, 26, 44), Vector3(0, 0, -6))

	# 2. Rolling toward the funbox, camera behind her
	_place(Vector3(0, 0.9, 12), PI)
	p.velocity = Vector3(0, 0, -8)
	await _game_view("02_rolling", 12)

	# 3. Crouched, charging an ollie
	_place(Vector3(-9, 0.9, 21), PI)
	p.velocity = Vector3(0, 0, -6)
	Input.action_press("jump")
	await _game_view("03_charging_an_ollie", 20)

	# 4. Popped, flying over the flat rail (seen from the side)
	Input.action_release("jump")
	_place(Vector3(-6, 3.0, 16), -PI / 2)
	p.velocity = Vector3(-5, 0, 0)
	s._pop()
	s._yaw = -PI / 2
	p.set_physics_process(false)
	s._pose(1.0)
	cam.make_current()
	await _view("04_ollie_over_the_rail", Vector3(-6, 1.8, 23), Vector3(-6.5, 1.8, 16))
	p.set_physics_process(true)

	# 5. A vert air over the halfpipe's east wall, from across the flat bottom
	_place(Vector3(30.0, 6.8, -6), PI / 2)
	s._pop()
	s._vert = true
	s._yaw = PI * 1.1
	p.set_physics_process(false)
	s._pose(1.0)
	await _view("05_vert_air", Vector3(23.5, 2.2, 5), Vector3(29, 5.0, -6))
	p.set_physics_process(true)

	# 6. Grinding the handrail down the stairs, with the balance meter
	var hr := park.find_child("Stair Set", true, false).find_child("Handrail East", true, false) as GrindRail
	var at: Vector3 = hr.point_at(hr.length() * 0.45)
	_place(at + Vector3(0, 1.2, 0), 0.0)
	p.velocity = Vector3(0, -1, 5)
	s._pop()
	s._try_grind()
	s.balance = 0.35
	s._balance_vel = 0.0
	s.set_process(false)
	arm.rotation = Vector3(-0.3, PI + 0.5, 0)
	arm._since_look = 0.0
	await _game_view("06_handrail_grind", 6)

	# 7. A bail: tumbling, the board shooting off, stars round her head
	_place(Vector3(-20, 0.9, 32), PI / 2)
	p.velocity = Vector3(5, 0, 0)
	await _physics(4)
	s.bail()
	await _physics(16)
	cam.make_current()
	await _view("07_bail", p.global_position + Vector3(-1.5, 1.6, 4.2), p.global_position + Vector3(0.4, 0.2, 0))
	_finish()


func _place(pos: Vector3, yaw: float) -> void:
	if s.state == s.State.BAIL:
		s._end_bail()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s.state = s.State.ROLL
	s._yaw = yaw
	p.get_node("Visual").basis = Basis(Vector3.UP, yaw)
	arm.rotation = Vector3(-0.3, yaw + PI, 0)


func _game_view(file: String, frames: int) -> void:
	# What the player sees: Nina's own camera
	(p.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
