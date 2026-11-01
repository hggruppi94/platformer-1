extends SceneTree

# Screenshots of the gap bonuses (scripts/skate_gaps.gd), through the game's own camera with the HUD: flying the
# Hollow Skate Yard's gap, landing it ("GAP! Hollow Yard Gap" in the combo), flying off the Big Air Kicker at the foot
# of Lookout Hill, and the gaps list on the Skate page. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_gaps.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.gaps_capture_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://gap_shots"
var gaps: Node
var p: CharacterBody3D
var s: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	gaps = root.get_node("Gaps")
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Settings").tips = false
	for id in gaps.all_ids():
		root.get_node("Dialogue").flags.erase("gap_" + id)
	clock.pulls_home = false
	clock.day = 1
	clock.set_earth_time(15 * 60.0, true)
	change_scene_to_file(EARTH)
	for i in 8:
		await process_frame
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	game.riding = true
	game.equipment_changed.emit()
	for i in 4:
		await physics_frame
	s = p.get_node("Skate")
	await _jump("Hollow Skate Yard/Gap Kicker", 11.0, 0.0, "01_flying_the_hollow_yard_gap", "02_gap_hollow_yard_gap_landed")
	await _jump("Big Air Kicker", 15.0, 6.0, "03_lookout_launch", "04_gap_lookout_launch_landed")
	root.get_node("PlayerMenu").open("skate")
	for i in 6:
		await process_frame
	for sc in root.get_node("PlayerMenu").find_children("*", "ScrollContainer", true, false):
		(sc as ScrollContainer).scroll_vertical = 100000
	for i in 4:
		await process_frame
	await _shot("05_gaps_on_the_skate_page")
	root.get_node("PlayerMenu").close()
	_finish()


func _jump(piece: String, speed: float, back_extra: float, first: String, second: String) -> void:
	# Rolls at the kicker; a shot mid-air (half a second up), then one just after the gap lands
	var k: Node3D = gaps._piece(current_scene, piece)
	var fwd: Vector3 = k.global_basis.z.normalized()
	var start: Vector3 = k.global_position - fwd * (8.0 + back_extra)
	start.y = maxf(k.global_position.y, EarthLand.height(start.x, start.z)) + 1.0
	p.global_position = start
	var yaw := atan2(fwd.x, fwd.z)
	s.set("_yaw", yaw)
	s.set("_shown_yaw", yaw)
	s.set("state", 0)
	p.visual.rotation.y = yaw
	p.spring_arm.rotation.y = atan2(-fwd.x, -fwd.z)
	for i in 3:
		await physics_frame
	var landed := [false]
	var on_gap := func(_id: String, _pts: int) -> void: landed[0] = true
	gaps.landed_gap.connect(on_gap)
	var air := 0
	var took_air := false
	for i in 400:
		if i < 50 and s.state == 0:
			p.velocity = fwd * speed + Vector3.UP * p.velocity.y
		await physics_frame
		air = air + 1 if s.state == 1 else 0
		if air == 30 and not took_air:
			took_air = true
			await _shot(first, 0)
		if landed[0]:
			for f in 8:
				await physics_frame
			await _shot(second, 0)
			break
	gaps.landed_gap.disconnect(on_gap)
	for i in 90:
		await physics_frame


func _shot(file: String, settle := 2) -> void:
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	for id in gaps.all_ids():
		root.get_node("Dialogue").flags.erase("gap_" + id)
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
