extends SceneTree

# Screenshots of Hayden's 13 Nov 2026 playtest fixes: Dash showing you round his gadget stall (scripts/shop_tour.gd)
# step by step, his window opening at the top with its scroll bar, the player menu's scroll bar, and the Star Popper's
# ammo readout (full, running low, empty). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_dash_shop.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.dash_shop_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://dash_shop_shots"
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	var arsenal := root.get_node("Arsenal")
	var shop := root.get_node("Shop")
	var dialogue := root.get_node("Dialogue")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	settings.tips = false
	settings.last_device = "keyboard"
	arsenal.reset()
	dialogue.flags.erase(shop.TOUR_FLAG)
	dialogue.set_flag("schematic_popper")
	dialogue.set_flag("schematic_fizz")
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	var player := town.find_child("Player", true, false) as CharacterBody3D
	var stall := town.get_node_or_null("Gadget Stall") as Node3D
	if stall:
		player.global_position = stall.global_position + stall.global_basis.z * 4.0 + Vector3(0, 0.5, 0)
	for i in 20:
		await process_frame
	game.sparkles = 14
	shop.auto_tour = true
	shop.open("Gadget")
	var tour = shop.tour
	for i in tour.STEPS.size():
		for f in 6:
			await process_frame
		await _shot("%02d_dash_tour_step_%d" % [i + 1, i + 1])
		tour._next.pressed.emit()
	for f in 4:
		await process_frame
	shop.buy("star_popper")
	shop.buy("fizz_flinger")
	shop.close()
	shop.open("Gadget")
	for f in 6:
		await process_frame
	await _shot("08_window_opens_at_the_top_with_a_scroll_bar")
	shop.close()
	shop.open("Workbench")
	for f in 6:
		await process_frame
	await _shot("09_workbench_scroll_bar")
	shop.close()
	var pm := root.get_node("PlayerMenu")
	pm.call("open", "quests")
	for f in 8:
		await process_frame
	await _shot("10_player_menu_scroll_bar")
	pm.call("close")
	arsenal.select("popper")
	for f in 4:
		await process_frame
	await _shot("11_star_popper_full")
	arsenal.ammo["popper"] = 6
	arsenal.changed.emit()
	for f in 4:
		await process_frame
	await _shot("12_star_popper_running_low")
	arsenal.ammo["popper"] = 0
	arsenal.changed.emit()
	for f in 4:
		await process_frame
	await _shot("13_star_popper_empty")
	_finish()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Shop").auto_tour = false
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit()
