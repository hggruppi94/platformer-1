extends SceneTree

# Screenshots of sparkles and shopping: a sparkle in town, the sparkle counter, a stall's shop window, and Nina in
# each hat with stickers on her sash. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_shop.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://shop_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(180.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var shop := root.get_node("Shop")
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	game._resume = {}
	game.pending_message = ""
	game.items.clear()
	game.hat = ""
	game.sparkles = 27
	game.sparkles_taken.clear()
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	clock.set_time(1, 11 * 60.0, true)
	cam = Camera3D.new()
	cam.fov = 55
	current_scene.add_child(cam)

	# A sparkle out in town, with the counter on the HUD (the game's own camera)
	var sp := current_scene.find_child("Sparkle 12", true, false) as Node3D
	player.global_position = sp.global_position + Vector3(0, 0.8, 2.5)
	player.get_node("Visual").rotation.y = PI
	await create_timer(2.0).timeout
	cam.make_current()
	cam.global_position = sp.global_position + Vector3(1.5, 1.8, 5.0)
	cam.look_at(sp.global_position + Vector3(0, 0.9, 0))
	await _shot("01_a_sparkle_and_the_counter")
	var tree := current_scene.find_child("Sparkle 1", true, false) as Node3D
	cam.make_current()
	cam.global_position = tree.global_position + Vector3(-5, 2.5, 6)
	cam.look_at(tree.global_position + Vector3(0, 1.0, 0))
	await _shot("02_sparkle_up_at_the_tree_house")

	# The Crystals stall's shop window
	var stall := current_scene.find_child("Crystals Stall", true, false) as Node3D
	player.global_position = stall.global_position + stall.global_basis.z * 2.4 + Vector3(0, 0.8, 0)
	player.get_node("Visual").rotation.y = stall.global_rotation.y + PI
	await _frames(6)
	cam.global_position = stall.global_position + stall.global_basis.z * 6.0 + Vector3(0, 2.4, 0)
	cam.look_at(stall.global_position + Vector3(0, 1.2, 0))
	game.give_item("campaign_sash")
	shop.open("Crystals")
	await _shot("03_crystals_stall_shop_window")
	shop.close()

	# Nina in each hat, sticker by sticker on her sash
	var stickers := ["star_sticker", "daisy_sticker", "note_sticker", "paw_sticker"]
	var hats := ["propeller_cap", "flower_crown", "crystal_tiara", "headphones"]
	player.global_position = Vector3(-72, 2, 66)
	for k in hats.size():
		game.items.append("shop:" + hats[k])
		game.items.append("shop:" + stickers[k])
		game.hat = hats[k]
		game.equipment_changed.emit()
		player.get_node("Visual").rotation.y = 0.0
		await _frames(4)
		var at := player.global_position
		cam.global_position = at + Vector3(0.5, 0.6, 2.3)
		cam.look_at(at + Vector3(0, 0.25, 0))
		await _shot("%02d_nina_in_the_%s" % [k + 4, hats[k]])
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


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
