extends SceneTree

# Screenshots of Remnants and the garden (scripts/remnants.gd, scripts/farm.gd): the garden by My House, a bed
# through every stage, the crops looking back at you, a thirsty plant, the Remnant veins (full and harvested),
# Bramble popping up to help, a tool part, Bramble waiting at the garden, the HUD, the Bag and the market stalls.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_farming.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.farming_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.farming_capture_backup.cfg"

var out_dir := "user://farming_shots"
var cam: Camera3D
var _had_save := false
var farm: Node
var rem: Node
var dialogue: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.sparkles = 24
	root.get_node("Settings").tips = false
	farm = root.get_node("Farm")
	rem = root.get_node("Remnants")
	dialogue = root.get_node("Dialogue")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	await _town()
	_finish()


func _setup() -> CharacterBody3D:
	change_scene_to_file("res://scenes/town/town.tscn")
	for i in 12:
		await process_frame
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()
	return p


func _town() -> void:
	var p: CharacterBody3D = await _setup()
	var s := current_scene as Node3D
	var hud = p.get_node("HUD")
	hud.visible = false
	var garden := s.get_node("Garden") as Node3D
	var g := garden.global_position
	p.set_physics_process(false)
	p.global_position = Vector3(0, -50, 0)

	# 1. The plot as Bramble finds it: six beds of grass inside the fence, by My House
	await _view("01_your_garden_before", g + Vector3(8.0, 5.0, 8.0), g + Vector3(0, 0.3, 0))

	# 2-6. One bed through its stages: dug, seed, sprout, growing, ripe (a Goggle Gourd)
	dialogue.set_flag("harvest_start")
	dialogue.set_flag("harvest_tool_built")
	dialogue.set_flag("garden_tour")
	var stages := [["02_stage_dug", "", 0.0], ["03_stage_seed", "gogglegourd", 1.0], ["04_stage_sprout", "gogglegourd", 180.0],
		["05_stage_growing", "gogglegourd", 420.0], ["06_stage_ripe", "gogglegourd", 720.0]]
	var bed := 1
	var at: Vector3 = garden.to_global(farm.bed_local(bed))
	p.global_position = at + Vector3(-1.5, 0.3, 4.5)
	p.set_physics_process(true)
	for st in stages:
		_set_bed(bed, str(st[1]), float(st[2]), false)
		await _view(str(st[0]), at + Vector3(1.6, 1.4, 2.2), at + Vector3(0, 0.45, 0), 14)

	# 7. The whole garden growing, everyone looking at the player
	_set_bed(0, "blinkberry", 240.0, false)
	_set_bed(1, "gogglegourd", 720.0, false)
	_set_bed(2, "peekaroot", 480.0, false)
	_set_bed(3, "remnant_sprout", 1440.0, false)
	_set_bed(4, "peekaroot", 200.0, true)
	_set_bed(5, "", 0.0, false)
	p.global_position = g + Vector3(4.5, 0.3, 3.0)
	for i in 30:
		await physics_frame
	hud.visible = true
	rem.count = 7
	rem.changed.emit()
	await _view("07_garden_growing", g + Vector3(7.5, 4.0, 6.5), g + Vector3(0, 0.4, 0), 30)
	hud.visible = false

	# 8. Close up: the crops looking back
	await _view("08_they_look_back", g + Vector3(1.3, 1.2, -2.2), g + Vector3(-0.6, 0.5, -0.6), 20)
	# 9. A thirsty one waits, drooping, with a water drop
	var b4: Vector3 = garden.to_global(farm.bed_local(4))
	await _view("09_thirsty_waits", b4 + Vector3(1.5, 1.3, 1.8), b4 + Vector3(0, 0.6, 0), 14)
	# 10. The Remnant sprout, ripe with its crystal
	var b3: Vector3 = garden.to_global(farm.bed_local(3))
	await _view("10_remnant_sprout", b3 + Vector3(1.0, 1.0, 1.4), b3 + Vector3(0, 0.6, 0), 14)

	# 11-13. Remnant veins
	var holder := s.get_node("Remnants") as Node3D
	var vein := holder.get_node("Vein lake_shore") as Node3D
	var v := vein.global_position
	p.global_position = v + Vector3(3.0, 0.3, 2.0)
	for i in 10:
		await physics_frame
	await _view("11_remnant_vein", v + Vector3(5.5, 2.6, 4.5), v + Vector3(0, 1.0, 0))
	# Bramble pops up to help
	rem.veins_taken.erase("lake_shore")
	rem._refresh_veins()
	cam.global_position = v + Vector3(5.0, 2.2, 4.5)
	cam.look_at(v + Vector3(0, 1.0, 0))
	# Slow time right down so the shot catches her all the way up, whatever speed the frames come at
	Engine.time_scale = 0.08
	rem._bramble_visit("lake_shore")
	for i in 400:
		await process_frame
		var helper := holder.get_node_or_null("Bramble Helps") as Node3D
		if helper and helper.get_child_count() > 1:
			var model := helper.get_child(1) as Node3D
			if model.visible and model.position.y > -0.05:
				break
	for i in 6:
		await process_frame
	await _shot("12_bramble_pops_up_to_help")
	Engine.time_scale = 1.0
	await create_timer(3.5).timeout
	await _view("13_vein_harvested", v + Vector3(5.0, 2.6, 4.5), v + Vector3(0, 0.6, 0), 4)
	var castle := holder.get_node("Vein castle_rock") as Node3D
	await _view("14_vein_by_the_castle", castle.global_position + Vector3(6.0, 3.5, 9.0), castle.global_position + Vector3(0, 1.0, 0))

	# 15. A tool part waiting to be found (the parts step)
	dialogue.flags.erase("harvest_tool_built")
	var q := root.get_node("Quests")
	q.reset()
	q.check()
	await _frames(4)
	var part := holder.get_node("Part crystal") as Node3D
	await _view("15_tool_part_hum_crystal", part.global_position + Vector3(2.5, 1.2, 2.5), part.global_position)
	dialogue.set_flag("harvest_tool_built")

	# 16. Bramble waiting at the garden for her tour (her routine's override on that step)
	dialogue.flags.erase("garden_tour")
	for k in ["harvest_part_handle", "harvest_part_scoop", "harvest_part_crystal", "harvest_first_vein"]:
		dialogue.set_flag(k)
	q.check()
	var bramble := s.find_child("Plant Girl", true, false) as Node3D
	var routine := bramble.get_node("Routine")
	routine.call("snap")
	for i in 40:
		await physics_frame
	p.global_position = g + Vector3(6.5, 0.3, 1.0)
	for i in 20:
		await physics_frame
	await _view("16_bramble_at_your_garden", g + Vector3(9.5, 3.0, -2.5), bramble.global_position + Vector3(0, 0.8, 0), 20)
	dialogue.set_flag("garden_tour")

	# 17-19. The Bag, and the market: seeds at the Flowers stall, selling at the Fruit stall
	farm.give_seeds("blinkberry", 2)
	farm.crops["blinkberry"] = 6
	farm.crops["peekaroot"] = 2
	var menu := root.get_node("PlayerMenu")
	menu.open("bag")
	await _frames(14)
	await _shot("17_bag_remnants_and_garden")
	menu.close()
	await _frames(4)
	var shop := root.get_node("Shop")
	shop.open("Flowers")
	await _frames(10)
	await _shot("18_flowers_stall_seeds")
	shop.close()
	shop.open("Fruit")
	await _frames(10)
	await _shot("19_fruit_stall_sells_crops")
	shop.close()
	shop.open("Sweets")
	await _frames(10)
	await _shot("20_sweets_stall_snacks")
	shop.close()


func _set_bed(i: int, crop: String, grown: float, dry: bool) -> void:
	var b: Dictionary = farm.beds[i]
	b.tilled = true
	b.crop = crop
	b.grown = grown
	b.last = farm.now()
	b.water_until = farm.now() if dry else farm.now() + 99999.0
	farm._shown[i] = ""
	farm._refresh()


func _view(file: String, at: Vector3, look: Vector3, frames := 12) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in frames:
		await process_frame
	await _shot(file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
