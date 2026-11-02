extends SceneTree

# Screenshots of Galaxity's sparkly alien trees (scenes/town/trees.gd): a wide view over town by day, a close-up of
# each kind (orb, spire, parasol), dusk, and a grove at night when the canopies and twinkles light up the dark.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_trees.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.trees_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FAR_AWAY := Vector3(-140, 2, 100)

var out_dir := "user://tree_shots"
var cam: Camera3D


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
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as Node3D
	p.global_position = FAR_AWAY
	clock.set_time(1, 12 * 60.0, true)
	for i in 8:
		await physics_frame
	var trees := town.find_child("Trees", true, false)
	var positions: PackedVector3Array = trees.get("positions")
	var sizes: PackedFloat32Array = trees.get("sizes")
	var kinds = trees.get("kinds")
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)

	# 1. Wide view over town: the trees among the homes and the lake
	await _view("01_town_wide", Vector3(40, 34, 70), Vector3(20, 4, 10))
	await _view("02_meadow_low", Vector3(-30, 6, 60), Vector3(-10, 4, 30))

	# 2. A close-up of each kind: the biggest of that kind, seen from a few metres off
	var names := ["orb", "spire", "parasol"]
	for kind in 3:
		var best := -1
		for i in positions.size():
			if kinds[i] == kind and (best < 0 or sizes[i] > sizes[best]):
				best = i
		if best < 0:
			continue
		var at := positions[best]
		var s := sizes[best]
		await _view("03_%s_tree" % names[kind], at + Vector3(s * 3.5 + 4, 3.5, s * 3.5 + 4), at + Vector3(0, 2.5 + s, 0))

	# 3. Dusk and night: the glow and twinkles in the dark
	clock.set_time(1, 19 * 60.0 + 30.0, true)
	for i in 8:
		await physics_frame
	await _view("04_dusk", Vector3(-30, 6, 60), Vector3(-10, 4, 30))
	clock.set_time(1, 23 * 60.0, true)
	for i in 8:
		await physics_frame
	await _view("05_night", Vector3(-30, 6, 60), Vector3(-10, 4, 30))
	await _view("06_night_wide", Vector3(40, 34, 70), Vector3(20, 4, 10))
	_finish()


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
