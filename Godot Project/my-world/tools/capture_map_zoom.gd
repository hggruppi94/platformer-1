extends SceneTree

# Screenshots of the reworked big map (scripts/map_screen.gd): the Void at full size and zoomed in with two
# followed quests' stars and the "Show on the map" list, some kinds switched off, Earth, and the pictures from
# above that the portal worlds, a race circuit and the Secret Garden get, with the corner minimap in a world.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_map_zoom.gd -- <output folder>
#
# Your own save is put aside and put back afterwards (and Settings' map switches are put back as they were).

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const PLACES := [["shard_isle", "res://scenes/portal_worlds/shard_isle.tscn"], ["lanternmoor", "res://scenes/portal_worlds/lanternmoor.tscn"],
	["dark_hollow", "res://scenes/portal_worlds/dark_hollow.tscn"], ["tide_reef", "res://scenes/portal_worlds/tide_reef.tscn"],
	["lake_loop", "res://scenes/races/lake_loop.tscn"], ["secret_garden", "res://scenes/secret_garden/secret_garden.tscn"]]

var out_dir := "user://map_zoom_shots"
var map: Node
var settings: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	map = root.get_node("TownMap")
	settings = root.get_node("Settings")
	var hide_was: Array = settings.map_hide.duplicate()
	settings.map_hide = []
	settings.apply()
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	quests.load_data({"rex_campaign": {"step": 0, "since_day": 1}, "pip_lamps": {"step": 0, "since_day": 1}})
	quests.follow("rex_campaign")
	quests.follow("pip_lamps")
	dialogue.flags["oak_woken"] = true
	for id in ["dash", "rex", "pip", "bramble", "tally", "nina", "melody", "heather", "mr_palmer", "bruno"]:
		dialogue.talks[id] = 1
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as Node3D
	player.global_position = Vector3(-60, 2, 58)
	player.get_node("Visual").rotation.y = PI * 0.75
	clock.set_time(1, 14 * 60.0, true)
	await create_timer(2.0).timeout
	map.zoom = 1.0
	map.toggle()
	await _shot("01_void_whole_map_two_quests")
	map.zoom_by(3.0)
	map.find_me()
	await _shot("02_void_zoomed_in")
	map.set_shown("people", false)
	map.set_shown("places", false)
	map.set_shown("quest:pip_lamps", false)
	await _shot("03_void_zoomed_people_places_pip_hidden")
	settings.map_hide = []
	map.zoom_by(1.5)
	map.move_by(Vector2(500, -900))
	await _shot("04_void_zoomed_far_stars_on_the_edge")
	map.toggle()
	map.zoom = 1.0
	change_scene_to_file(EARTH)
	for i in 6:
		await process_frame
	await create_timer(2.0).timeout
	map.toggle()
	await _shot("05_earth_whole_map")
	map.zoom_by(2.5)
	map.find_me()
	await _shot("06_earth_zoomed")
	map.toggle()
	var n := 7
	for p in PLACES:
		map.zoom = 1.0
		change_scene_to_file(p[1])
		for i in 6:
			await process_frame
		await create_timer(3.0).timeout
		map.toggle()
		await create_timer(0.5).timeout
		await _shot("%02d_%s_map" % [n, p[0]])
		n += 1
		map.toggle()
		if p[0] == "shard_isle" or p[0] == "lake_loop":
			settings.minimap = true
			await create_timer(1.0).timeout
			await _shot("%02d_%s_corner_minimap" % [n, p[0]])
			n += 1
	settings.map_hide = hide_was
	_finish()


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
