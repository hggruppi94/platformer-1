extends SceneTree

# Screenshots of the town's layout: a labelled map from above, then the Market Square (day and night), the housing
# district, the portal lighting it up in the Shift, the Observatory on its hill, the spooky woods (Haunted House, old
# slide, Scary World gate), a signpost and Sports & Play. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_layout.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const SKIP := ["WorldEnvironment", "Sun", "DayNight", "Terrain", "Far Ground", "WorldBounds", "Sky Objects", "Mountains",
	"Trees", "Foliage", "Crystals", "Enemies", "Player", "Lake", "Happy Places", "Characters", "Waterfalls", "Sailboats"]

var out_dir := "user://layout_shots"
var town: Node3D
var cam: Camera3D
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1500, 1060))
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
	for i in 6:
		await process_frame
	clock = root.get_node("Clock")
	clock.set_time(1, 12 * 60.0, true)
	town = current_scene as Node3D
	var player := town.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-140, 2, 100)
	player.get_node("HUD").visible = false
	cam = Camera3D.new()
	town.add_child(cam)
	cam.make_current()

	# The map from above, labelled
	(town.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled = false
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 290.0
	cam.far = 600.0
	cam.global_position = Vector3(0, 250, -32)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	var layer := CanvasLayer.new()
	town.add_child(layer)
	for n in town.get_children():
		if not n is Node3D or n.name in SKIP or str(n.name).begins_with("Signpost") or str(n.name).begins_with("Boardwalk"):
			continue
		var l := Label.new()
		l.text = str(n.name)
		l.position = cam.unproject_position((n as Node3D).global_position) - Vector2(50, 8)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(1, 1, 0.75))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 6)
		layer.add_child(l)
	await _shot("00_map_from_above")
	layer.queue_free()
	(town.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_enabled = true
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60

	await _view("01_market_square", Vector3(-72, 0, 42), Vector3(0, 22, 46), Vector3(0, 0, -4))
	clock.set_time(1, 21 * 60.0 + 30.0, true)
	await create_timer(2.5).timeout
	await _view("02_market_square_at_night", Vector3(-72, 0, 42), Vector3(10, 14, 34), Vector3(0, 0, -2))
	clock.set_time(2, 9 * 60.0, true)
	await create_timer(2.5).timeout
	await _view("03_housing_district", Vector3(80, 0, 0), Vector3(-44, 26, 34), Vector3(0, 0, -4))
	clock.set_time(2, 20.0, true)                          # the Shift
	await create_timer(3.0).timeout
	await _view("04_portal_lights_the_homes_in_the_shift", Vector3(50, 0, 6), Vector3(-30, 18, 30), Vector3(14, 0, -6))
	clock.set_time(2, 10 * 60.0, true)
	await create_timer(2.5).timeout
	await _view("05_observatory_on_its_hill", Vector3(105, 16, -88), Vector3(-40, 14, 46), Vector3(0, -2, 0))
	await _view("06_haunted_house_old_slide_and_gate", Vector3(-112, 0, -128), Vector3(50, 22, 40), Vector3(-6, 0, -10))
	await _view("07_scary_world_gate", Vector3(-128, 0, -150), Vector3(16, 7, 24), Vector3(0, 2, 0))
	await _view("08_signpost_by_the_dock", Vector3(30, 0, 23), Vector3(4, 3.5, 6), Vector3(0, 2.6, 0))
	await _view("09_sports_and_play", Vector3(80, 0, 66), Vector3(-36, 30, 40), Vector3(0, 0, 0))
	await _view("10_south_meadow_and_lake", Vector3(10, 0, 50), Vector3(20, 14, 28), Vector3(-6, 0, -20))
	_finish()


func _view(file: String, at: Vector3, offset: Vector3, look_shift: Vector3) -> void:
	var g := _ground(Vector2(at.x, at.z)) if at.y == 0 else at
	cam.global_position = g + offset
	cam.look_at(g + look_shift + Vector3(0, 1.0, 0))
	await _shot(file)


func _ground(xz: Vector2) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 80, xz.y), Vector3(xz.x, -20, xz.y))
	q.exclude = TownPaths.skip_rids(town)
	var hit := town.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(xz.x, 0, xz.y)


func _shot(file: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
