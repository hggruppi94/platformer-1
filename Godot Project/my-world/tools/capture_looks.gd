extends SceneTree

# Screenshots of looks and friends' outfits (scripts/clothes.gd): Nina with two different looks, each friend dressed
# up (the clothes fitted to them), and the wardrobe open on Dash. Taken in the Clothing Boutique.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_looks.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const BOUTIQUE := "res://scenes/interiors/clothing_boutique.tscn"
const DRESSED := {
	"dash": {"head": "sk8_beanie", "neck": "cozy_scarf", "top": "galaxy_tee", "hands": "hero_gloves", "back": "super_cape"},
	"rook": {"face": "space_goggles", "neck": "bow_tie", "top": "stripy_shirt", "feet": "rainbow_sneakers"},
	"pip": {"head": "flower_crown", "face": "heart_shades", "neck": "crystal_necklace", "hands": "cozy_mittens"},
	"bramble": {"face": "star_glasses", "top": "sunny_shirt", "bottoms": "tutu", "feet": "moon_boots", "back": "jetpack"},
	"green_man": {"head": "propeller_cap", "face": "star_glasses", "neck": "cozy_scarf", "hands": "garden_gloves", "back": "butterfly_wings"},
	"mr_palmer": {"head": "crystal_tiara", "face": "heart_shades", "top": "stripy_shirt", "feet": "sparkle_slippers"},
	"rex": {"head": "propeller_cap"},
}

var out_dir := "user://looks_shots"
var cam: Camera3D
var game: Node


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
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	for who in DRESSED:
		for slot in DRESSED[who]:
			if not game.has_item("shop:" + DRESSED[who][slot]):
				game.items.append("shop:" + DRESSED[who][slot])
		game.outfits[who] = DRESSED[who].duplicate()
	game.looks = {"pip": {"hair": 5}, "rook": {"accent": 2}}
	change_scene_to_file(BOUTIQUE)
	for i in 6:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.get_node("HUD").visible = false
	game.message("")
	cam = Camera3D.new()
	cam.fov = 50
	current_scene.add_child(cam)
	var at := Vector3(0, 0.85, 1.0)

	# 1 and 2: Nina with two new looks
	game.outfit = {"face": "star_glasses", "top": "stripy_shirt"}
	game.looks["nina"] = {"hair": 4, "fur": 1, "eyes": 1, "accent": 2}
	await _pose(p, "nina", at, "01_nina_purple_hair")
	game.outfit = {"head": "sk8_beanie", "top": "galaxy_tee"}
	game.looks["nina"] = {"hair": 1, "fur": 5, "eyes": 2, "accent": 4, "blush": 1}
	await _pose(p, "nina", at, "02_nina_blonde_mint")

	# 3 on: each friend dressed up
	var n := 3
	for who in DRESSED:
		await _pose(p, who, at, "%02d_%s_dressed_up" % [n, who])
		n += 1

	# The wardrobe, open on Dash
	p.set_rider("nina")
	var shop := root.get_node("Shop")
	shop.open("Wardrobe")
	shop.cycle_who(1)
	for i in 4:
		await process_frame
	cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join("%02d_wardrobe_dash.png" % n))
	print("SHOT wardrobe")
	shop.close()
	_finish()


func _pose(p: Node3D, who: String, at: Vector3, file: String) -> void:
	game.riding = true
	p.set_rider(who)
	game.equipment_changed.emit()
	(p.get_node("Visual/Skateboard") as Node3D).visible = false      # just them, no ride
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.set_physics_process(false)
	var v := p.get_node("Visual") as Node3D
	v.basis = Basis.IDENTITY
	v.position = Vector3.ZERO
	var model := p.get("model") as Node3D
	model.rotation.y = 0.0
	cam.make_current()
	var tall := 1.0 if who != "mr_palmer" else 1.2
	cam.global_position = at + Vector3(0.7, 0.4 * tall, 2.8 * tall)
	cam.look_at(at + Vector3(0, -0.05 + 0.15 * (tall - 1.0), 0))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)
	p.set_physics_process(true)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
