extends SceneTree

# Screenshots of the real Secret Garden (scripts/secret_garden.gd) and its hidden way in (scripts/secret_garden_way.gd):
# the wren on the hill, the old ivy wall, the door open, then the rebuilt garden (VIEWS) and the garden awake. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_secret_garden.gd -- <output folder> [<view prefix>]
#
# With a view prefix ("07", "1", "awake") it goes straight into the garden and takes only those.
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.secret_garden_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.secret_garden_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

const LAND := preload("res://scripts/secret_garden_land.gd")
const GARDEN := "res://scenes/secret_garden/secret_garden.tscn"
# The rebuilt garden's views (26 Nov 2026): [file, camera (x, height over the ground, z), looking at (the same)]
const VIEWS := [
	["05_inside_the_door", Vector3(0, 2.2, 6), Vector3(0, 14, 120)],
	["06_from_above", Vector3(0, 150, -70), Vector3(0, 0, 150)],
	["07_the_old_house", Vector3(14, 5, 262), Vector3(0, 10, 305)],
	["08_the_grand_stair", Vector3(-9, 1.8, 262), Vector3(0, 4, 285)],
	["09_the_overlook", Vector3(-42, 2.2, 289), Vector3(20, 1.5, 292)],
	["10_from_the_overlook", Vector3(0, 3.6, 290), Vector3(0, -6, 150)],
	["11_the_formal_garden", Vector3(26, 6, 244), Vector3(0, 0.5, 262)],
	["12_the_great_fountain", Vector3(9, 2.2, 250), Vector3(0, 3, 261)],
	["13_the_cypress_walk", Vector3(0, 1.8, 203), Vector3(0, 3.5, 240)],
	["14_the_water_stairs", Vector3(15, 4, 138), Vector3(0, 3, 176)],
	["15_the_water_stairs_top", Vector3(-4, 3.0, 197), Vector3(0, -3, 160)],
	["16_the_tulip_slope", Vector3(22, 5, 94), Vector3(-6, 0, 128)],
	["17_the_whole_hill", Vector3(120, 70, 40), Vector3(0, 0, 180)],
	["20_temple_lake", Vector3(20, 3.0, 30), Vector3(-22, 2, 84)],
	["21_the_lake_temple", Vector3(-12, 2.0, 72), Vector3(-22, 3.5, 84)],
	["22_palladian_bridge", Vector3(68, 3.0, 44), Vector3(50, 2.5, 52)],
	["23_the_lily_pond", Vector3(-55, 2.4, 46), Vector3(-80, 1, 54)],
	["24_green_bridge", Vector3(-58, 1.8, 57), Vector3(-70, 2, 52)],
	["25_koi_pond", Vector3(-95, 2.4, 106), Vector3(-104, 1.5, 124)],
	["26_moon_bridge", Vector3(-86, 2.0, 96), Vector3(-93, 1.2, 102)],
	["27_dry_garden_tea_house", Vector3(-74, 3.0, 106), Vector3(-86, 1, 126)],
	["28_rose_walk", Vector3(76, 1.8, 26), Vector3(88, 2, 60)],
	["29_waters_from_above", Vector3(-20, 80, -20), Vector3(-30, 0, 75)],
	["30_the_great_tree", Vector3(-52, 3.0, 150), Vector3(-80, 9, 165)],
	["31_treetop_walk", Vector3(-46, 6.0, 154), Vector3(-70, 9, 150)],
	["32_on_the_crown_deck", Vector3(-82, 12.6, 162), Vector3(-40, 4, 150)],
	["33_the_glasshouse", Vector3(92, 3.0, 136), Vector3(92, 6, 170)],
	["34_inside_the_glasshouse", Vector3(90, 1.8, 162), Vector3(98, 4, 176)],
	["35_supertree_grove", Vector3(70, 2.4, 98), Vector3(95, 12, 126)],
	["36_atop_the_supertree", Vector3(91, 25.4, 124), Vector3(20, 10, 200)],
	["37_the_hedge_maze", Vector3(-67, 8.0, 247), Vector3(-96, -2, 260)],
	["38_the_potager", Vector3(56, 5, 196), Vector3(90, 0, 218)],
	["39_the_rill_court", Vector3(62, 2.2, 262), Vector3(110, 1, 264)],
	["40_the_sunken_garden", Vector3(-76, 3.0, 196), Vector3(-92, -6, 214)],
	["41_sunken_garden_floor", Vector3(-100, 1.8, 204), Vector3(-92, 3, 222)],
	["42_the_arboretum", Vector3(-30, 4, 140), Vector3(-110, 4, 175)],
]

var out_dir := "user://secret_garden_shots"
var only := ""
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1700.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var way := root.get_node("Farm/SecretGarden")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	for f in dialogue.flags.keys():
		if str(f).begins_with("sg_"):
			dialogue.flags.erase(f)

	if only != "":
		# straight into the garden
		change_scene_to_file(GARDEN)
		await _frames(14)
		await _garden()
		_finish()
		return
	# The wren up on the hill, then the old wall at the foot of the cliff
	change_scene_to_file(TOWN)
	await _frames(12)
	var wall := current_scene.get_node("Ivy Wall") as Node3D
	var wren := wall.get_node("Wren") as Node3D
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	(p.get_node("HUD") as CanvasLayer).visible = false
	p.global_position = wren.global_position + Vector3(7, 1, 6)
	_new_cam()
	await _view("01_the_wren_on_the_hill", wren.global_position + Vector3(1.2, 0.8, 1.6), wren.global_position + Vector3(0, 0.3, 0))
	var door: Vector2 = way.DOOR
	var base: Vector3 = root.get_node("Bosses").ground(current_scene, door.x, door.y - 3.0)
	# (straight to the end of its trail: the flights themselves are slow to wait for in a capture)
	var last: int = way.TRAIL.size() - 1
	way.set("_wren_at", last)
	wren.global_position = root.get_node("Bosses").ground(current_scene, way.TRAIL[last].x, way.TRAIL[last].y)
	way.call("_show_key")
	p.global_position = base + Vector3(3, 1, -6)
	await _view("02_the_old_ivy_wall", base + Vector3(-1.0, 1.9, -5.0), base + Vector3(0, 2.0, 3.0))
	await _view("03_the_wren_pecking", wren.global_position + Vector3(1.5, 1.0, -1.5), wren.global_position + Vector3(0, 0.2, 0))
	var mound := wall.get_node("Key Mound")
	mound.find_child("Key Spot", true, false).act.call()
	var spot := wall.find_child("Wall Spot", true, false)
	spot.act.call()
	await _frames(30)
	await _view("04_the_door_open", base + Vector3(0.6, 1.8, -4.5), base + Vector3(0, 1.8, 3.0))

	# In
	spot.act.call()
	await _frames(14)
	await _garden()
	_finish()


func _garden() -> void:
	var sg := current_scene as Node3D
	var p := sg.find_child("Player", true, false) as CharacterBody3D
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	root.get_node("Settings").minimap = false
	# (the player out of the way, so it isn't in the pictures)
	p.global_position = Vector3(0, 60, -30)
	p.set_physics_process(false)
	_new_cam()
	for v in VIEWS:
		if only != "" and not str(v[0]).begins_with(only):
			continue
		await _view(v[0], _up(v[1]), _up(v[2]), 10)
	if only == "" or only == "awake":
		for id in sg.seeds:
			sg.wake_seed(id)
		await _frames(200)
		await _view("99_the_garden_awake", _up(Vector3(30, 9, 20)), _up(Vector3(0, 6, 80)), 10)


func _up(v: Vector3) -> Vector3:
	# Views are given as heights over the ground there
	return Vector3(v.x, LAND.height(v.x, v.z) + v.y, v.z)


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.make_current()
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
