extends SceneTree

# Screenshots of the character creator (scripts/creator.gd) and the player's own house (scripts/home_decor.gd): each
# tab of the creator with a hero being made, a "Surprise me" hero, My House as it starts and decorated, the Decorate
# window, and Nina in town as a friend.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_creator.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const HOUSE := "res://scenes/interiors/my_house.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://creator_shots"
var game: Node
var creator: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	creator = root.get_node("Creator")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hero = Hero.blank()
	game.home = {}
	game.next_spawn = "BedSpawn"
	change_scene_to_file(HOUSE)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 10 * 60.0, true)
	game.message("")

	# The creator, tab by tab, building one hero
	creator.open(true)
	await _shot("01_creator_body", 6)
	game.hero.merge({"body": "moth", "height": 1.05, "head": 1.1}, true)
	creator.step_body(0)
	await _shot("02_creator_body_moth", 6)
	creator._tab = "Hair"
	game.hero.merge({"hairstyle": 8, "colors": {"hair": 18}}, true)
	creator._changed()
	await _shot("03_creator_hair", 6)
	creator._tab = "Colours"
	creator._part = "fur"
	game.hero.colors["fur"] = 17
	creator._changed()
	await _shot("04_creator_colours", 6)
	creator._tab = "Clothes"
	game.hero.colors["top"] = 14
	game.outfits["hero"] = {"face": "star_glasses", "back": "butterfly_wings"}
	creator._changed()
	await _shot("05_creator_clothes", 6)
	creator._tab = "Name"
	game.hero.merge({"name": "Luna", "pronouns": "she"}, true)
	creator._changed()
	await _shot("06_creator_name", 6)
	seed(9)
	creator.surprise()
	await _shot("07_surprise_me", 6)
	game.hero.merge({"name": "Luna"}, true)
	creator.close()
	for i in 4:
		await process_frame

	# My House, as it starts and decorated, with the Decorate window
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.get_node("HUD").visible = false
	var cam := Camera3D.new()
	cam.fov = 60
	current_scene.add_child(cam)
	cam.global_position = Vector3(0, 5.5, 7.5)
	cam.look_at(Vector3(0, 0.5, -1.5))
	cam.make_current()
	await _shot("08_my_house", 8)
	game.home = {"walls": 1, "floor": 4, "rug": 3, "blanket": 4, "spot1": "fish_tank", "spot2": "arcade",
		"spot3": "drum_kit", "spot4": "telescope", "spot5": "beanbag", "spot6": "easel"}
	game.equipment_changed.emit()
	await _shot("09_my_house_decorated", 8)
	var shop := root.get_node("Shop")
	shop.open("Decorate")
	await _shot("10_decorate_window", 4)
	shop.close()

	# Nina in town, at the Market in the morning
	game.next_spawn = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 10 * 60.0, true)
	for i in 10:
		await process_frame
	var nina := current_scene.find_child("Nina", true, false) as Node3D
	var tcam := Camera3D.new()
	tcam.fov = 50
	current_scene.add_child(tcam)
	tcam.global_position = nina.global_position + Vector3(2.5, 1.6, 3.5)
	tcam.look_at(nina.global_position + Vector3(0, 0.9, 0))
	tcam.make_current()
	await _shot("11_nina_in_town", 8)
	_finish()


func _shot(file: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
