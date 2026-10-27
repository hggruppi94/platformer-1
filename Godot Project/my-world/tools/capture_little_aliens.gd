extends SceneTree

# Screenshots of the little aliens (scripts/little_aliens.gd): the Market Square from the player's own camera with
# aliens on the ground, the roofs and the walls and saucers overhead; all seven in a row; a saucer up close with its
# pilot; climbers on a wall; the homes by the lake; and the Market at night.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_little_aliens.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const MARKET := Vector3(-72, 0, 42)
const HOMES := Vector3(80, 0, 0)

var out_dir := "user://little_alien_shots"
var cam: Camera3D
var crowd: Node3D
var walkers: Array[Node3D] = []
var flyers: Array[Node3D] = []
var space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(180.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	for i in 4:
		await physics_frame
	var clock := root.get_node("Clock")
	clock.set_time(1, 11 * 60.0, true)
	var town := current_scene as Node3D
	space = town.get_world_3d().direct_space_state
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var arm := p.get_node("SpringArm3D") as SpringArm3D
	crowd = town.find_child("LittleAliens", true, false) as Node3D
	for c in crowd.get_children():
		(walkers if c.name.begins_with("LittleAlien") else flyers).append(c)
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)

	# 1. The Market Square from the player's own camera: aliens everywhere, saucers overhead
	p.global_position = _ground(MARKET + Vector3(0, 0, 20)) + Vector3(0, 1.0, 0)
	(p.get_node("Visual") as Node3D).rotation.y = PI
	arm.rotation = Vector3(-0.12, 0.0, 0)
	_scatter(MARKET + Vector3(0, 0, 6), 0, 22, 50.0)
	_hover(0, MARKET + Vector3(-6, 9, 4))
	_hover(1, MARKET + Vector3(9, 13, -6))
	_hover(7, MARKET + Vector3(3, 5, 10))
	await _game_view("01_market_square", 30)

	# 2. All seven in a row on the grass, waving and looking about
	var row_at := _ground(MARKET + Vector3(0, 0, 12))
	p.global_position = row_at + Vector3(-12, 1, 12)
	for i in 7:
		var w := walkers[i]
		w.place(_ground(row_at + Vector3((i - 3) * 0.9, 0, 0)), Vector3.UP, Vector3(0, 0, 1))
		w.set_physics_process(false)
		var anim := w.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play("wave" if i % 3 == 1 else "idle")
	cam.make_current()
	await _view("02_all_seven", row_at + Vector3(0, 1.0, 5.0), row_at + Vector3(0, 0.4, 0))
	for i in 7:
		walkers[i].set_physics_process(true)

	# 3. A saucer up close with its pilot under the dome
	var s_at := MARKET + Vector3(-20, 0, 30)
	_hover(2, _ground(s_at) + Vector3(0, 2.2, 0))
	await _view("03_saucer_close_up", _ground(s_at) + Vector3(2.4, 3.0, 2.6), _ground(s_at) + Vector3(0, 2.3, 0))

	# 4. Climbers on a wall
	var wall := _castle_wall()
	if not wall.is_empty():
		var n: Vector3 = wall.normal
		var side := n.cross(Vector3.UP).normalized()
		for i in 5:
			var w := walkers[10 + i]
			w.place(wall.position + side * (i - 2) * 1.1 + Vector3.UP * (0.6 * (i % 3) - 0.3), n, Vector3.UP + side * (i - 2) * 0.3)
			w.visible = true
		var w0: Vector3 = wall.position
		p.global_position = w0 + n * 12.0
		await _view("04_wall_climbers", w0 + n * 5.0 + Vector3(0, -0.3, 0) + side * 2.0, w0 + Vector3(0, 0.2, 0))

	# 5. Up on the roofs of the homes by the lake
	p.global_position = _ground(HOMES + Vector3(-10, 0, 30)) + Vector3(0, 1, 0)
	_scatter(HOMES, 14, 30, 60.0)
	_hover(3, HOMES + Vector3(4, 12, 6))
	_hover(8, HOMES + Vector3(-6, 6, 12))
	await _view("05_homes_and_roofs", HOMES + Vector3(-14, 12, 34), HOMES + Vector3(0, 3, 0))

	# 6. The Market at night: the saucers' lights
	clock.set_time(1, 21 * 60.0 + 30.0, true)
	p.global_position = _ground(MARKET + Vector3(0, 0, 20)) + Vector3(0, 1.0, 0)
	_scatter(MARKET + Vector3(0, 0, 6), 0, 14, 16.0)
	_hover(0, MARKET + Vector3(-5, 6, 6))
	_hover(1, MARKET + Vector3(7, 9, -4))
	_hover(4, MARKET + Vector3(1, 4, 12))
	await _game_view("06_market_at_night", 30)
	_finish()


# Drops walkers [from, to) near a spot, the way the game does (some on walls, some on roofs, some on the ground)
func _scatter(at: Vector3, from: int, to: int, spread: float) -> void:
	for i in range(from, mini(to, walkers.size())):
		walkers[i].visible = true
		crowd._drop(walkers[i], at + Vector3(randf_range(-spread, spread) * 0.3, 0, randf_range(-spread, spread) * 0.3))


func _hover(i: int, at: Vector3) -> void:
	var f := flyers[i]
	f.global_position = at
	f.velocity = Vector3.ZERO
	f.state = f.State.HOVER
	f._timer = 30.0
	f.rotation = Vector3.ZERO
	f._hull.rotation = Vector3.ZERO


func _castle_wall() -> Dictionary:
	# The castle school's north face, looking in from the town over its hill (tools/build_town.gd CASTLE_HILL)
	for k in 12:
		var x := 15.0 + (k - 6) * 4.0
		var from := Vector3(x, 22.0, -60.0)
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(x, 22.0, -150.0))
		var hit := space.intersect_ray(q)
		if hit and absf((hit.normal as Vector3).y) < 0.3 and LittleAliens.walkable(hit):
			return hit
	return {}


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 150, at.z), Vector3(at.x, -10, at.z))
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, 0, at.z)


func _game_view(file: String, frames: int) -> void:
	(cam.get_parent().find_child("Player", true, false).get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _view(file: String, at: Vector3, look: Vector3) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
