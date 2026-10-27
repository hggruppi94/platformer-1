extends SceneTree

# Screenshots of the Agent of Chaos (scripts/chaos_giant.gd): looking up at him from a kid's height, a wide view of
# him at the town's northeast edge behind the castle hill, letting the chaos out over the player, mid-stomp from the
# side, and at night with his glowing cracks.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_chaos_giant.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://chaos_giant_shots"
var cam: Camera3D
var giant: Node3D
var anim: AnimationPlayer
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
	giant = town.find_child("ChaosGiant", true, false) as Node3D
	anim = giant.find_child("AnimationPlayer", true, false) as AnimationPlayer
	giant.set_physics_process(false)                  # each shot poses him by hand
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	var mid: Vector3 = (giant.patrol_a + giant.patrol_b) / 2.0
	var at := _ground(mid)
	giant.global_position = at
	giant.rotation.y = PI * 0.75                      # facing southwest, toward the town

	# 1. From a kid's height, a few steps in front of him, looking up
	p.global_position = at + Vector3(40, 1, 40)       # out of the way
	anim.play("idle")
	var front := Vector3(sin(giant.rotation.y), 0, cos(giant.rotation.y))
	var eye := _ground(at + front * 13.0) + Vector3(0, 1.3, 0)
	await _view("01_looking_up", eye, at + Vector3(0, 7.5, 0), 0.9)

	# 2. Wide: him out in the field at the edge of town, the castle hill off to one side, the mountains behind
	await _view("02_town_edge", at + Vector3(-30, 22, 62), at + Vector3(-6, 4, 0), 0.6)

	# 3. Letting the chaos out, seen from over the player's shoulder
	p.global_position = _ground(at + front * 18.0) + Vector3(0, 1.0, 0)
	(p.get_node("Visual") as Node3D).rotation.y = giant.rotation.y + PI
	arm.rotation = Vector3(0.3, giant.rotation.y, 0)     # the camera looks back at him, tipped up
	anim.play("chaos")
	await _game_view("03_chaos_over_the_player", 40)

	# 4. Mid-stomp, from the side
	p.global_position = at + Vector3(40, 1, 40)
	anim.play("walk", -1, 0.6)
	var side := Vector3(cos(giant.rotation.y), 0, -sin(giant.rotation.y))
	await _view("04_stomping", _ground(at + side * 20.0 + front * 4.0) + Vector3(0, 3.0, 0), at + Vector3(0, 5.5, 0), 0.5)

	# 5. At night: his eyes, cracks and the backwards clock glow
	clock.set_time(1, 22 * 60.0, true)
	anim.play("idle")
	await _view("05_night", _ground(at + front * 16.0 + side * 5.0) + Vector3(0, 2.0, 0), at + Vector3(0, 6.5, 0), 0.6)
	_finish()


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 150, at.z), Vector3(at.x, -10, at.z))
	if giant and giant.get_node_or_null("Body"):
		q.exclude = [(giant.get_node("Body") as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, 0, at.z)


func _game_view(file: String, frames: int) -> void:
	(cam.get_parent().find_child("Player", true, false).get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _view(file: String, at: Vector3, look: Vector3, seconds: float) -> void:
	# seconds: how long the animation runs before the shot, to catch him in a good part of it
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	var t := 0.0
	while t < seconds:
		await process_frame
		t += 1.0 / 60.0
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
