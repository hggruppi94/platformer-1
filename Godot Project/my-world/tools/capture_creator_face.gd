extends SceneTree

# Screenshots of the character creator's new bodies, face sculpting and secret heroes (scripts/creator.gd,
# scripts/face_sculpt.gd): the Body tab on a new body with the secret hint, the Face tab with ready-made faces and the
# sliders pushed, and the Body tab once the dog-kid's been found.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_creator_face.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const HOUSE := "res://scenes/interiors/my_house.tscn"

var out_dir := "user://creator_face_shots"
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
	var dialogue := root.get_node("Dialogue")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hero = Hero.blank()
	game.home = {}
	game.next_spawn = "BedSpawn"
	dialogue.flags.erase("skate_lesson_done")
	game.items.erase("secret:dog")
	change_scene_to_file(HOUSE)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 10 * 60.0, true)
	game.message("")

	creator.open(true)
	game.hero.merge({"body": "bunny", "hairstyle": 0}, true)
	creator.step_body(0)
	await _shot("01_body_bunny_and_secret_hint", 6)
	creator._tab = "Face"
	game.hero.merge({"body": "cat"}, true)
	creator.step_body(0)
	FaceSculpt.apply_preset(game.hero, 2)
	creator._changed()
	await _shot("02_face_cat_goofball", 6)
	game.hero.merge({"body": "earth_kid", "hairstyle": 6, "colors": {"hair": 3}}, true)
	creator.step_body(0)
	game.hero.merge({"eyes": 1.6, "eye_gap": 1.0, "nose": 0.6, "ears": 2.6, "mouth": 1.3}, true)
	creator._changed()
	await _shot("03_face_earth_kid_big_ears", 6)
	game.hero.merge({"body": "dino", "hairstyle": 0}, true)
	creator.step_body(0)
	FaceSculpt.apply_preset(game.hero, 1)
	creator._changed()
	await _shot("04_face_dino_big_eyed_cutie", 6)
	game.hero.merge({"body": "hippo", "hairstyle": 1}, true)
	creator.step_body(0)
	FaceSculpt.apply_preset(game.hero, 3)
	creator._changed()
	await _shot("05_face_hippo_snooty", 6)
	# Finding the dog-kid
	dialogue.set_flag("skate_lesson_done")
	for i in 4:
		await process_frame
	creator._tab = "Body"
	game.hero.merge({"body": "dog", "hairstyle": 0}, true)
	FaceSculpt.apply_preset(game.hero, 0)
	creator.step_body(0)
	await _shot("06_secret_dog_kid_found", 6)
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
