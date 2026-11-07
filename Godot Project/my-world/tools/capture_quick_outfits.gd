extends SceneTree

# Screenshots of the quick outfit wheel (scripts/quick_outfits.gd): the wardrobe with its skin and saved outfit rows,
# the wheel open, the sparkle puff as the hero changes, and a few bodies in a saved outfit with a skin. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_quick_outfits.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.quick_outfits_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.quick_outfits_capture_backup.cfg"

var out_dir := "user://quick_outfits_shots"
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	game.hero = Hero.blank()
	game.hero.name = "Sky"
	game.outfits = {"hero": {}}
	game.saved_outfits = []
	for id in ["sk8_beanie", "super_cape", "galaxy_tee", "moon_boots", "star_glasses", "butterfly_wings", "tutu",
			"rainbow_sneakers", "cozy_scarf"]:
		if not game.has_item("shop:" + id):
			game.items.append("shop:" + id)
	for id in Skins.ORDER:
		if not game.has_item("skin:" + id):
			game.items.append("skin:" + id)
	root.get_node("Settings").tips = false
	root.get_node("Dialogue").reset()
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(1, 11 * 60.0, true)
	var qo := root.get_node("QuickOutfits")
	var shop := root.get_node("Shop")
	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(12)
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(50, 1.0, 44)
	await _frames(10)
	# Three saved outfits
	game.outfits.hero = {"head": "sk8_beanie", "back": "super_cape", "top": "galaxy_tee", "feet": "moon_boots"}
	qo.save_slot(0, "Skater")
	game.outfits.hero = {"face": "star_glasses", "back": "butterfly_wings", "bottoms": "tutu", "feet": "rainbow_sneakers"}
	game.hero["skin"] = "starlight"
	qo.save_slot(1, "Starlight Party")
	game.outfits.hero = {"neck": "cozy_scarf", "head": "sk8_beanie"}
	game.hero["skin"] = "champion"
	qo.save_slot(3, "Race Day")
	game.hero.erase("skin")
	game.outfits.hero = {}
	game.equipment_changed.emit()
	shop.open("Wardrobe")
	shop.outfit_slot = 1
	shop._fill()
	await _frames(10)
	await _shot("01_wardrobe_skins_and_saved_outfits")
	shop.close()
	await _frames(6)
	qo.open_wheel()
	qo.point(qo.slot_angle(1))
	await _frames(4)
	await _shot("02_outfit_wheel")
	qo.close(true)
	await create_timer(0.3, true, false, true).timeout
	await _shot("03_sparkle_puff")
	await create_timer(1.2, true, false, true).timeout
	await _shot("04_changed_into_starlight_party")
	# A few bodies in the same saved outfit and skin
	var cam := Camera3D.new()
	cam.fov = 40
	current_scene.add_child(cam)
	p.get_node("HUD").visible = false
	for body in ["bunny", "cat", "dino", "earth_kid", "moth", "cow"]:
		game.hero.body = body
		p.set_rider("hero", false)
		qo.wear(3 if body in ["dino", "moth"] else 1)
		await _frames(12)
		var face := Vector3.FORWARD.rotated(Vector3.UP, (p.get_node("Visual") as Node3D).global_rotation.y + PI)
		cam.global_position = p.global_position + face * 4.0 + Vector3.UP * 1.1
		cam.look_at(p.global_position + Vector3.UP * 0.75)
		cam.make_current()
		await _frames(4)
		await _shot("05_body_%s" % body)
	game.hero.body = "hippo"
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
