extends SceneTree

# Screenshots of the day 1 playtest polish (Hayden, 11 Nov 2026): the old oak's runes as made-up glyphs (by day and
# glowing), the courts and the soccer field with no rails on them, a railing along a boardwalk, the hero standing in
# tall grass (it only parts right round her now), and town spots where a tree or plant used to grow through
# something. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_day1_polish.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.day1_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://day1_polish_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	root.get_node("Settings").tips = false
	game.riding = false
	game._resume = {}
	game.pending_message = ""

	# The Void
	change_scene_to_file(TOWN)
	await _wait_for_scene(TOWN)
	await create_timer(4.6).timeout                  # the plants' second look (foliage.gd RECHECK)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	for n in ["Basketball Court", "Tennis Court", "Soccer Field"]:
		var a := town.find_child(n, false, false) as Node3D
		if a:
			await _view("void_" + n.to_lower().replace(" ", "_"), a.global_position + Vector3(-14, 11, 22), a.global_position)
	var bw := town.find_child("Boardwalk South", false, false)
	await _view("void_boardwalk_railing", Vector3(-1.5, 2.6, 14.0), Vector3(-8.0, 0.5, 0.0))
	# Tall grass round the hero (the first meadow, tools/build_town.gd GRASS_PATCHES)
	var g := Vector3(10, 0, 58)
	var ground := _ground(g)
	if player:
		player.global_position = ground + Vector3(0, 1.0, 0)
		RenderingServer.global_shader_parameter_set("nina_pos", player.global_position)
	await _view("void_tall_grass_round_the_hero", ground + Vector3(2.8, 2.0, 3.2), ground + Vector3(0, 0.6, 0), 20)
	# Where trees were left out
	var trees := town.find_child("Trees", true, false)
	var out: PackedInt32Array = trees.get("left_out")
	var pos: PackedVector3Array = trees.get("positions")
	for k in mini(out.size(), 3):
		var p := pos[out[k]]
		await _view("void_tree_left_out_%d" % k, p + Vector3(8, 6, 9), p + Vector3(0, 2, 0))

	# Earth: the old oak's runes
	change_scene_to_file(EARTH)
	await _wait_for_scene(EARTH)
	await create_timer(1.5).timeout
	var oak := current_scene.find_child("Old Oak", true, false) as Node3D
	if oak:
		await _view("earth_oak_runes_by_day", oak.global_transform * Vector3(0.6, 2.3, 4.4), oak.global_transform * Vector3(0, 2.0, 1.2), 12)
		var runes := oak.get_node("Oak Runes")
		var m := (runes.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
		var hum := root.get_node("HummingOak")
		hum.set("_rune_mat", null)                    # (so its own glow doesn't change it back for the shot)
		m.emission_energy_multiplier = 2.5
		await _view("earth_oak_runes_glowing", oak.global_transform * Vector3(0.6, 2.3, 4.4), oak.global_transform * Vector3(0, 2.0, 1.2), 12)
		await _view("earth_oak_runes_up_the_trunk", oak.global_transform * Vector3(-2.5, 4.5, 4.0), oak.global_transform * Vector3(0, 4.2, 0), 6)
	_finish()


func _ground(p: Vector3) -> Vector3:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 80, 0), p - Vector3(0, 80, 0))
	var hit := space.intersect_ray(q)
	return hit.position if hit else p


func _make_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		_make_cam()
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	for i in 6:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
