extends SceneTree

# Screenshots of the town's Skate Park at midday: the whole park from above, Nina rolling in toward the funbox, a
# vert air going for the K, the goals board, and grinding a bench in the Market Square.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_skate_park.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://skate_park_shots"
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
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	arm = p.get_node("SpringArm3D") as SpringArm3D
	var park := town.get_node("Skate Park") as Node3D
	var c := park.global_position
	game.riding = true
	game.equipment_changed.emit()
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	game.message("")

	# 1. The whole park from above, looking north-east over it
	_place(c + Vector3(-2, 1.2, 12), PI)
	await _view("01_town_skate_park", c + Vector3(-14, 17, 24), c + Vector3(1, 0, -1))

	# 2. Rolling in toward the funbox
	_place(c + Vector3(0, 1.2, 3.5), PI)
	p.velocity = Vector3(0, 0, -6)
	await _game_view("02_rolling_in", 12)

	# 3. A vert air off the east quarter pipe, reaching for the K
	var k := park.get_node("Pickup K") as Node3D
	_place(k.global_position + Vector3(-0.2, -0.4, -1.6), PI / 2)
	s._pop()
	s._vert = true
	s._yaw = PI * 1.15
	p.set_physics_process(false)
	s._pose(1.0)
	await _view("03_vert_for_the_k", c + Vector3(1, 3.5, 8), k.global_position + Vector3(0, -0.5, -1))
	p.set_physics_process(true)

	# 4. The goals board
	var board := park.get_node("GoalBoard") as Node3D
	var front := board.global_transform.basis.z
	await _view("04_goals_board", board.global_position + front * 4.0 + Vector3(0, 2.2, 0), board.global_position + Vector3(0, 2.2, 0))

	# 5. Grinding a bench in the Market Square
	var bench := town.find_child("Bench Grind 0", true, false) as GrindRail
	if bench:
		var at: Vector3 = bench.point_at(0.3)
		_place(at + Vector3(0, 1.2, 0), 0.0)
		p.velocity = Vector3(0, -1, 0)
		s._pop()
		s._try_grind()
		s.balance = 0.1
		var t: Vector3 = bench.tangent_at(0.3)
		arm.rotation = Vector3(-0.3, atan2(-t.x, -t.z) + 0.6, 0)
		arm._since_look = 0.0
		await _game_view("05_bench_grind", 6)
	_finish()


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s.state = s.State.ROLL
	s._yaw = yaw
	p.get_node("Visual").basis = Basis(Vector3.UP, yaw)
	arm.rotation = Vector3(-0.3, yaw + PI, 0)


func _game_view(file: String, frames: int) -> void:
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


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
