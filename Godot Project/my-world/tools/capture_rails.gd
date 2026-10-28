extends SceneTree

# Screenshots of grinding round town (scripts/grind_rail.gd, scripts/edge_rails.gd, _town_rails in build_town.gd):
# new rails beside the paths and out on the lawns, grinding one, grinding the edge of a bench and the rim of the
# skate park, and pushing up a hill.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_rails.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://rail_shots"
var cam: Camera3D
var p: CharacterBody3D
var s: Node


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
	game.needs_creator = false
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	game.riding = true
	game.equipment_changed.emit()
	for i in 4:
		await process_frame
	game.message("")
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	var rails := town.get_node("Town Rails").find_children("*", "GrindRail", true, false)

	# 1. Two of the new rails out in town
	var r1 := rails[3] as GrindRail
	var m1: Vector3 = r1.point_at(r1.length() * 0.5)
	await _view("01_town_rail", m1 + Vector3(5, 3.0, 6), m1)
	var r2 := rails[40] as GrindRail
	var m2: Vector3 = r2.point_at(r2.length() * 0.5)
	await _view("02_rail_on_the_lawn", m2 + Vector3(-6, 3.5, 5), m2)

	# 3. Grinding one
	await _grind(r1, "03_grinding_a_town_rail")

	# 4. Grinding the edge of something: an edge rail near the Market Square
	var edges := town.get_node("EdgeRails")
	var best: GrindRail = null
	var best_d := INF
	for e in edges.get_children():
		var r := e as GrindRail
		var d: float = r.point_at(0.0).distance_to(Vector3(-72, 0, 49))
		if d < best_d and r.length() > 1.5:
			best_d = d
			best = r
	await _grind(best, "04_grinding_an_edge")
	# 5. The rim of the skate park
	var park := town.get_node("Skate Park") as Node3D
	best = null
	best_d = INF
	for e in edges.get_children():
		var r := e as GrindRail
		var d: float = absf(r.point_at(0.0).distance_to(park.global_position) - 14.5)
		if d < best_d and r.length() > 30.0:
			best_d = d
			best = r
	if best:
		await _grind(best, "05_grinding_the_skate_park_rim")
	_finish()


func _grind(r: GrindRail, file: String) -> void:
	var at: Vector3 = r.point_at(r.length() * 0.35)
	p.global_position = at + Vector3(0, 1.4, 0)
	p.velocity = Vector3(0, -1, 0)
	s.state = s.State.AIR
	s._pop()
	s._try_grind()
	s.balance = 0.1
	for i in 10:
		await physics_frame
	var t: Vector3 = r.tangent_at(s._rail_offset) * s._rail_dir
	(p.get_node("SpringArm3D") as Node3D).rotation = Vector3(-0.3, atan2(-t.x, -t.z) + 0.5, 0)
	(p.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)
	s._leave_rail(Vector3.ZERO)
	s.state = s.State.AIR


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
