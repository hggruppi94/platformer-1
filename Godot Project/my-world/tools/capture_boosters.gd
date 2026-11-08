extends SceneTree

# Screenshots of the boosters (scripts/boosters.gd): strips, ramps and coin lines round the Void and Stars Hollow,
# the hero flying off a booster ramp on the board and rushing along a strip on foot, and the map and minimap with an
# arrow for each. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boosters.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.boosters_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.boosters_capture_backup.cfg"

var out_dir := "user://boosters_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	game.needs_creator = false
	game.riding = false
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Settings").tips = false
	root.get_node("Dialogue").reset()
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(1, 11 * 60.0, true)
	await _town()
	await _earth()
	_finish()


func _find(s: Node, kind: String, where: String) -> Node3D:
	for n in s.get_node("Boosters").get_children():
		if str(n.get_meta("kind")) == kind and str(n.get_meta("where")) == where:
			return n as Node3D
	return null


func _setup(path: String) -> CharacterBody3D:
	change_scene_to_file(path)
	for i in 10:
		await process_frame
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()
	return p


func _town() -> void:
	var boosters := root.get_node("Boosters")
	var p: CharacterBody3D = await _setup(boosters.SCENES.town)
	var s := current_scene
	p.set_physics_process(false)
	p.global_position = Vector3(0, -50, 0)
	var strip := _find(s, "strip", "the lake's south shore")
	var d: Vector3 = strip.get_meta("dir")
	await _view("01_galaxity_boost_strip_by_the_lake", strip.global_position - d * 6.0 + Vector3(3.0, 2.4, 0), strip.global_position + d * 2.0)
	var coin := _find(s, "coins", "between the meadow rails")
	d = coin.get_meta("dir")
	await _view("02_galaxity_booster_coins_between_rails", coin.global_position - d * 5.0 + Vector3(-2.5, 1.5, 2.0), coin.global_position + d * 4.0)
	var ramp := _find(s, "ramp", "the south meadow")
	d = ramp.get_meta("dir")
	var side := Vector3(-d.z, 0, d.x)
	await _view("03_galaxity_booster_ramp", ramp.global_position - d * 4.0 + side * 4.0 + Vector3.UP * 2.2, ramp.global_position)
	var park := _find(s, "strip", "the way into the Skate Park")
	d = park.get_meta("dir")
	await _view("04_galaxity_strip_into_the_skate_park", park.global_position - d * 7.0 + Vector3.UP * 3.0, park.global_position + d * 8.0)

	# Flying off the ramp on the board
	var game := root.get_node("Game")
	p.set_physics_process(true)
	game.riding = true
	game.equipment_changed.emit()
	for i in 4:
		await physics_frame
	d = ramp.get_meta("dir")
	p.global_position = ramp.global_position - d * 6.0 + Vector3.UP * 0.9
	p.velocity = d * 8.0
	p.get_node("Visual").rotation.y = atan2(d.x, d.z)
	var sk := p.get_node("Skate")
	sk.set("_yaw", atan2(d.x, d.z))
	var flying := false
	for i in 120:
		await physics_frame
		flying = flying or p.global_position.y > ramp.global_position.y + 1.8
		if flying and p.velocity.y <= 0.5:
			break                                       # the top of the jump
	p.get_node("HUD").visible = true
	cam.global_position = p.global_position + side * 6.0 - d * 3.0 + Vector3.DOWN * 0.5
	cam.look_at(p.global_position)
	await _shot("05_big_air_off_a_booster_ramp")
	p.get_node("HUD").visible = false
	game.riding = false
	game.equipment_changed.emit()
	for i in 4:
		await physics_frame

	# Rushing along a strip on foot
	d = strip.get_meta("dir")
	p.global_position = strip.global_position - d * 3.0 + Vector3.UP * 0.9
	p.velocity = d * 5.0
	p.get_node("Visual").rotation.y = atan2(d.x, d.z)
	for i in 14:
		await physics_frame
	side = Vector3(-d.z, 0, d.x)
	cam.global_position = p.global_position + side * 4.0 + d * 3.0 + Vector3.UP * 1.0
	cam.look_at(p.global_position)
	await _shot("06_rushing_along_a_strip_on_foot")

	# The map and the minimap
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(30, 1.0, 44)
	for i in 20:
		await physics_frame
	var settings := root.get_node("Settings")
	settings.minimap = true
	p.get_node("HUD").visible = true
	var pc := p.find_child("Camera3D", true, false) as Camera3D
	if pc:
		pc.make_current()
	for i in 20:
		await process_frame
	await _shot("07_minimap_arrows")
	var menu := root.get_node("PlayerMenu")
	menu.open("map")
	for i in 12:
		await process_frame
	await _shot("08_map_boosters_galaxity")
	menu.close()
	settings.minimap = false
	for i in 4:
		await process_frame


func _earth() -> void:
	var boosters := root.get_node("Boosters")
	var p: CharacterBody3D = await _setup(boosters.SCENES.earth)
	var s := current_scene
	p.set_physics_process(false)
	p.global_position = Vector3(0, -50, 0)
	var coin := _find(s, "coins", "down Lookout Hill")
	var d: Vector3 = coin.get_meta("dir")
	await _view("09_earth_coins_down_lookout_hill", coin.global_position - d * 6.0 + Vector3(0, 4.0, 5.0), coin.global_position + d * 16.0)
	var strip := _find(s, "strip", "into the Big Air Kicker")
	d = strip.get_meta("dir")
	await _view("10_earth_strip_into_the_big_air_kicker", strip.global_position - d * 8.0 + Vector3(2.0, 3.0, 4.0), strip.global_position + d * 6.0)
	var lane := _find(s, "strip", "Maple Lane")
	d = lane.get_meta("dir")
	await _view("11_earth_maple_lane", lane.global_position - d * 8.0 + Vector3(0, 3.0, 3.0), lane.global_position + d * 10.0)
	var ramp := _find(s, "ramp", "by the playground")
	d = ramp.get_meta("dir")
	var side := Vector3(-d.z, 0, d.x)
	await _view("12_earth_booster_ramp", ramp.global_position - d * 4.0 + side * 4.0 + Vector3.UP * 2.2, ramp.global_position)
	p.set_physics_process(true)
	p.global_position = Vector3(-60, 1.0, 40)
	for i in 10:
		await physics_frame
	var menu := root.get_node("PlayerMenu")
	menu.open("map")
	for i in 12:
		await process_frame
	await _shot("13_map_boosters_stars_hollow")
	menu.close()


func _view(file: String, at: Vector3, look: Vector3, frames := 12) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in frames:
		await process_frame
	await _shot(file)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
