extends SceneTree

# Screenshots of Nina walking through things: tall grass parting round her, wading in the bubble bath, sinking into
# a cloud, wading in the lake, the hot springs, a waterfall's mist. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_walk_through.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://walk_through_shots"
var town: Node3D
var player
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame
	root.get_node("Clock").set_time(1, 11 * 60.0, true)
	town = current_scene as Node3D
	player = town.find_child("Player", true, false)
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	cam.make_current()

	# Tall grass: walking through a meadow, the blades parting round her
	var grass := Vector3(-5, 0, 88)
	await _walk_into(grass + Vector3(3, 0, 0), Vector3(-1, 0, 0), 30)
	await _look(player.global_position, Vector3(4, 2.2, 4))
	await _shot("01_tall_grass_parting")

	# Giant leaves: pushing through
	var foliage := town.find_child("Foliage", true, false)
	var pos: PackedVector3Array = foliage.get("positions")
	var kinds: PackedInt32Array = foliage.get("kinds")
	var sizes: PackedFloat32Array = foliage.get("sizes")
	for i in pos.size():
		if kinds[i] == 0 and sizes[i] > 3.5 and Vector2(pos[i].x, pos[i].z).length() > 70:
			await _walk_into(pos[i] + Vector3(2.5, 0, 0), Vector3(-1, 0, 0), 25)
			await _look(player.global_position, Vector3(4, 2.5, 3))
			await _shot("02_pushing_through_giant_leaves")
			break

	# The bubble bath: wading, bubbles bursting round her
	var tub := town.find_child("Magic Bubble Bath", true, false) as Node3D
	player.global_position = tub.global_position + Vector3(1.0, 2.0, 0.5)
	player.velocity = Vector3.ZERO
	await _physics(50)
	await _walk(Vector3(-1, 0, -0.3), 18)
	await _look(player.global_position, Vector3(4.5, 3.2, 4.5))
	await _shot("03_wading_in_the_bubble_bath")

	# A Cloud Nest cloud: sinking into the fluff
	var cloud: Area3D
	for z in town.find_child("Cloud Nest", true, false).find_children("*", "Area3D", true, false):
		if z.get("kind") == "cloud":
			cloud = z
			break
	player.global_position = cloud.global_position + Vector3(0, 3.0, 0)
	player.velocity = Vector3.ZERO
	await _physics(40)
	await _walk(Vector3(1, 0, 0), 12)
	await _look(player.global_position, Vector3(5, 3, 5))
	await _shot("04_in_a_cloud")

	# The lake: wading in the shallows, ripples spreading
	for zz in range(17, 4, -1):
		var p := _ground(Vector2(-30, zz))
		if p.y < -0.9:
			player.global_position = p + Vector3(0, 1.0, 0)
			break
	player.velocity = Vector3.ZERO
	await _physics(20)
	await _walk(Vector3(-1, 0, 0), 20)
	await _look(player.global_position, Vector3(4, 2.5, 5))
	await _shot("05_wading_in_the_lake")

	# The hot springs, now down on the ground in front of the caves
	var spring: Area3D
	for z in town.find_child("Hot Springs", true, false).find_children("*", "Area3D", true, false):
		if z.get("kind") == "spring":
			spring = z
			break
	player.global_position = spring.global_position + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	await _physics(30)
	await _walk(Vector3(1, 0, 0), 10)
	await _look(player.global_position, Vector3(4, 3, 6))
	await _shot("06_hot_spring_steam")

	# A waterfall's mist
	var mist := town.find_child("Waterfalls", true, false).find_child("Mist 1", false, false) as Node3D
	player.global_position = Vector3(140, 2, 100)
	cam.global_position = mist.global_position + Vector3(10, 6, 10)
	cam.look_at(mist.global_position + Vector3(0, 4, 0))
	await create_timer(1.5).timeout
	await _shot("07_waterfall_mist")
	_finish()


func _ground(xz: Vector2) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 40, xz.y), Vector3(xz.x, -10, xz.y))
	q.exclude = [player.get_rid()]
	var hit := town.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(xz.x, 0, xz.y)


func _walk_into(start: Vector3, dir: Vector3, frames: int) -> void:
	player.global_position = _ground(Vector2(start.x, start.z)) + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	await _physics(10)
	await _walk(dir, frames)


func _walk(dir: Vector3, frames: int) -> void:
	# Push forward with the camera turned to face `dir`, and stop on the last frame (still mid-stride)
	(player.get_node("SpringArm3D") as Node3D).rotation.y = atan2(-dir.x, -dir.z)
	Input.action_press("move_forward")
	await _physics(frames)
	Input.action_release("move_forward")


func _look(at: Vector3, offset: Vector3) -> void:
	cam.global_position = at + offset
	cam.look_at(at + Vector3(0, 0.3, 0))


func _shot(file: String) -> void:
	for i in 3:
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
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
