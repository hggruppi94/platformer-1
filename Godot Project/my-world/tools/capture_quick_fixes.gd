extends SceneTree

# Screenshots of the tree house steps, a zipline ride and the castle's new walls. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_quick_fixes.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://quick_fix_shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(180.0, true, false, true).timeout.connect(_finish)
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
	root.get_node("Clock").set_time(1, 10 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as CharacterBody3D
	var tree := town.find_child("Tree House", true, false) as Node3D
	var cam := Camera3D.new()
	cam.fov = 60
	town.add_child(cam)
	cam.make_current()

	# The steps spiralling up outside the deck, Nina halfway up
	var steps: Array[Node3D] = []
	for b in tree.get_children():
		if b is StaticBody3D and (b.get_child(0) as CollisionShape3D).shape is BoxShape3D \
				and is_equal_approx(((b.get_child(0) as CollisionShape3D).shape as BoxShape3D).size.y, 0.25):
			steps.append(b)
	steps.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
	player.global_position = steps[6].global_position + Vector3.UP * 1.0
	cam.global_position = tree.global_position + Vector3(14, 6, 12)
	cam.look_at(tree.global_position + Vector3(0, 5, 0))
	await _shot("01_tree_house_steps")

	# On the deck by the zipline handle, with the prompt
	var zip := tree.find_child("Zipline", false, false) as Area3D
	player.global_position = zip.global_position + Vector3(0.5, 0.2, 0.5)
	await _physics(10)
	cam.global_position = zip.global_position + Vector3(5, 3, 6)
	cam.look_at(zip.global_position + Vector3(0, 0.5, 0))
	await _shot("02_zipline_handle_prompt")

	# Riding: camera following alongside
	zip.call("ride", player)
	for i in 70:
		await physics_frame
	cam.global_position = player.global_position + Vector3(7, 2, 3)
	cam.look_at(player.global_position + Vector3(0, 0.5, 0))
	await _shot("03_zipline_ride")
	while zip.call("is_riding"):
		await physics_frame
	await _physics(60)
	cam.global_position = player.global_position + Vector3(6, 3, 6)
	cam.look_at(player.global_position)
	await _shot("04_zipline_landed")

	# The castle with its two back towers walled on
	var castle := town.get_node("Castle School") as Node3D
	var cc := castle.global_position
	cam.global_position = cc + Vector3(0, 38, -95)              # from behind: the two back towers and their walls
	cam.look_at(cc + Vector3(0, 14, 0))
	await _shot("05_castle_walls_from_behind")
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL            # from above
	cam.size = 90.0
	cam.global_position = cc + Vector3(0, 150, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	await _shot("06_castle_walls_from_above")
	_finish()


func _shot(file: String) -> void:
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
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
