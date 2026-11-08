extends SceneTree

# Screenshots of the human-kid creator (scripts/creator.gd, scripts/hero.gd, scripts/hair_kit.gd): the Body tab as a
# girl and as a boy, the Hair tab, every one of the twenty new hairstyles close up (front and from behind), a hat over
# a big style, and a hero from before the human kids after it's been changed into one. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_human_creator.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.human_capture_backup.json"
const HOUSE := "res://scenes/interiors/my_house.tscn"

var out_dir := "user://human_creator_shots"
var game: Node
var creator: Node
var player: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	creator = root.get_node("Creator")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hero = Hero.blank(true)
	game.outfits = {"hero": {}}
	game.next_spawn = "BedSpawn"
	change_scene_to_file(HOUSE)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 10 * 60.0, true)
	game.message("")
	player = current_scene.find_child("Player", true, false) as Node3D

	creator.open(true)
	await _shot("01_body_girl", 8)
	creator.set_girl(false)
	await _shot("02_body_boy", 8)
	creator._tab = "Hair"
	creator._changed()
	await _shot("03_hair_tab_boy", 6)
	creator.set_girl(true)
	game.hero.merge({"hairstyle": Hairstyles.GIRL_STYLES[1], "colors": {"hair": 10, "fur": 3}}, true)
	creator._changed()
	await _shot("04_hair_tab_girl", 6)
	creator._tab = "Face"
	creator._changed()
	await _shot("05_face_tab", 6)

	# Every style, close up, front and back: girls on the girl, boys on the boy, each in a different hair colour
	var hair_colours := [4, 10, 6, 11, 17, 5, 9, 14, 3, 16]
	var skins := [1, 21, 3, 22, 4, 23, 5, 24, 2, 3]
	var cam := Camera3D.new()
	cam.fov = 32
	current_scene.add_child(cam)
	cam.make_current()
	creator._layer.visible = false
	for girl in [true, false]:
		var styles: Array = Hairstyles.GIRL_STYLES if girl else Hairstyles.BOY_STYLES
		for k in styles.size():
			game.hero = Hero.blank(girl)
			game.hero.merge({"name": "Kid", "hairstyle": styles[k], "colors": {"hair": hair_colours[k], "fur": skins[k]}}, true)
			player.call("set_rider", "hero", false)
			game.equipment_changed.emit()
			var nm := Hairstyles.name_of(styles[k]).to_lower().replace(" ", "_").replace("-", "_")
			for view in ["front", "back"]:
				_aim(cam, 0.0 if view == "front" else PI * 0.8)
				await _shot("hair_%s_%02d_%s_%s" % ["girl" if girl else "boy", k + 1, nm, view], 5)

	# A hat over big hair, and over a bun (tucked away)
	game.hero = Hero.blank(false)
	game.hero.merge({"hairstyle": Hairstyles.BOY_STYLES[0], "colors": {"hair": 11}}, true)
	game.outfits = {"hero": {"head": "propeller_cap"}}
	player.call("set_rider", "hero", false)
	game.equipment_changed.emit()
	_aim(cam, 0.5)
	await _shot("hat_over_hero_spikes", 6)
	game.hero = Hero.blank(true)
	game.hero.merge({"hairstyle": Hairstyles.GIRL_STYLES[2], "colors": {"hair": 17}}, true)
	game.outfits = {"hero": {"head": "sk8_beanie"}}
	player.call("set_rider", "hero", false)
	game.equipment_changed.emit()
	await _shot("hat_over_space_buns", 6)

	# An old hero (a purple hippo with afro puffs) after it's been changed into a human kid
	game.outfits = {"hero": {}}
	game.hero = Hero.migrate({"name": "Luna", "pronouns": "she", "body": "hippo", "hairstyle": 8,
		"colors": {"fur": 16, "hair": 18, "eyes": 13}})
	player.call("set_rider", "hero", false)
	game.equipment_changed.emit()
	_aim(cam, 0.3, 2.4, 0.9)
	await _shot("old_hippo_hero_now_human", 6)

	# The title screen's save slots: this hero in slot 1, a second game in slot 2 (made just for the picture, and
	# taken away after), slot 3 empty
	game.hero.merge({"name": "Luna"}, true)
	game.needs_creator = false
	game.save_game()
	var made_two := not FileAccess.file_exists(game.slot_path(2))
	if made_two:
		var two := FileAccess.open(game.slot_path(2), FileAccess.WRITE)
		two.store_string(JSON.stringify({"hero": Hero.blank(false).merged({"name": "Max"}, true), "level": 4, "day": 9,
			"play_time": 5400.0}))
		two.close()
	change_scene_to_file("res://scenes/title/title.tscn")
	for i in 10:
		await process_frame
	await _shot("title_menu", 30)
	current_scene.call("open_slots")
	await _shot("title_save_slots", 10)
	if made_two:
		DirAccess.remove_absolute(game.slot_path(2))
	_finish()


func _aim(cam: Camera3D, turn: float, dist := 1.25, height := 1.18) -> void:
	# The camera in front of the hero's face (turn: round them, 0 is face on)
	var visual := player.get_node("Visual") as Node3D
	var yaw := visual.rotation.y + turn
	var front := Vector3(sin(yaw), 0, cos(yaw))
	var s := float(game.hero.get("height", 1.0))
	var feet := player.global_position - Vector3(0, 0.8, 0)      # (the player's middle is 0.8 m up)
	var head := feet + Vector3(0, height * s, 0)
	cam.global_position = head + front * dist + Vector3(0, 0.05, 0)
	cam.look_at(head)
	cam.make_current()


func _shot(file: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
