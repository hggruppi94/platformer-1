extends SceneTree

# Screenshots of the wardrobe's picture of who you're dressing (scripts/shop.gd _wardrobe_preview()): the hero in two
# outfits, and Dash. Taken in the Clothing Boutique. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_wardrobe.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const BOUTIQUE := "res://scenes/interiors/clothing_boutique.tscn"

var out_dir := "user://wardrobe_shots"


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
	for id in ["sk8_beanie", "galaxy_tee", "super_cape", "star_glasses", "moon_boots"]:
		if not game.has_item("shop:" + id):
			game.items.append("shop:" + id)
	game.outfits["hero"] = {}
	game.outfits["dash"] = {"head": "sk8_beanie", "back": "super_cape"}
	change_scene_to_file(BOUTIQUE)
	for i in 8:
		await process_frame
	game.message("")
	var shop := root.get_node("Shop")
	shop.open("Wardrobe")
	await _shot("01_wardrobe_hero")
	shop.cycle("head", 1)
	shop.cycle("top", 1)
	shop.cycle("back", 1)
	await _shot("02_wardrobe_hero_dressed")
	shop.cycle_who(1)
	await _shot("03_wardrobe_friend")
	shop.close()
	_finish()


func _shot(file: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
