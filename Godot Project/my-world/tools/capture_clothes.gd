extends SceneTree

# Screenshots of Nina's clothes (scripts/clothes.gd): the Clothing Boutique, Nina in her own clothes, three outfits
# head to toe (front, and one from the back for the wings), and her wardrobe open in her house.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_clothes.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const BOUTIQUE := "res://scenes/interiors/clothing_boutique.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"
const OUTFITS := [
	{"head": "sk8_beanie", "face": "star_glasses", "neck": "cozy_scarf", "top": "stripy_shirt", "bottoms": "denim_overalls",
		"feet": "rainbow_sneakers", "hands": "cozy_mittens", "back": "super_cape"},
	{"head": "crystal_tiara", "face": "heart_shades", "neck": "crystal_necklace", "top": "galaxy_tee", "bottoms": "tutu",
		"feet": "sparkle_slippers", "hands": "hero_gloves", "back": "butterfly_wings"},
	{"head": "propeller_cap", "face": "space_goggles", "neck": "bow_tie", "top": "sunny_shirt", "bottoms": "mint_overalls",
		"feet": "moon_boots", "hands": "garden_gloves", "back": "jetpack"},
]

var out_dir := "user://clothes_shots"
var cam: Camera3D
var game: Node


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
	game = root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.outfit = {}
	for o in OUTFITS:
		for slot in o:
			if not game.has_item("shop:" + o[slot]):
				game.items.append("shop:" + o[slot])
	change_scene_to_file(BOUTIQUE)
	for i in 6:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.get_node("HUD").visible = false
	game.message("")
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)

	# 1. The Boutique
	p.global_position = Vector3(0, 0.85, 1.0)
	await _view("01_clothing_boutique", Vector3(0, 3.2, 7.0), Vector3(0, 1.0, -3.0))

	# 2. Nina in her own clothes, then 3 to 5: three outfits, and 6: the last but one from behind (the wings)
	var at := Vector3(0, 0.85, 1.0)
	await _outfit(p, {}, at, 0.0, "02_her_own_clothes")
	await _outfit(p, OUTFITS[0], at, 0.0, "03_skater_outfit")
	await _outfit(p, OUTFITS[1], at, 0.0, "04_party_outfit")
	await _outfit(p, OUTFITS[2], at, 0.0, "05_space_outfit")
	await _outfit(p, OUTFITS[1], at, PI, "06_butterfly_wings_from_behind")

	# 7. Her wardrobe, open at home
	change_scene_to_file(HOUSE)
	for i in 6:
		await process_frame
	p = current_scene.find_child("Player", true, false) as Node3D
	var spot := current_scene.find_child("WardrobeSpot", true, false) as Node3D
	p.global_position = spot.global_position + Vector3(0, 0.85, 0)
	var shop := root.get_node("Shop")
	shop.open("Wardrobe")
	for i in 4:
		await process_frame
	var pc := p.get_node("SpringArm3D/Camera3D") as Camera3D
	pc.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("07_wardrobe.png"))
	print("SHOT 07_wardrobe")
	shop.close()
	_finish()


func _outfit(p: Node3D, outfit: Dictionary, at: Vector3, turn: float, file: String) -> void:
	game.outfit = outfit.duplicate()
	game.equipment_changed.emit()
	p.global_position = at
	(p.get_node("Visual") as Node3D).rotation.y = 0.0           # facing +Z; turn swings the camera round behind her
	var from := Vector3(0.6, 0.5, 2.6).rotated(Vector3.UP, turn)
	await _view(file, at + from, at + Vector3(0, -0.05, 0))


func _view(file: String, from: Vector3, look: Vector3) -> void:
	cam.make_current()
	cam.global_position = from
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
