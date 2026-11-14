extends SceneTree

# Screenshots for the 14 Nov 2026 look pass (scripts/world_detail.gd and friends): the Void's mountains, the ground up
# close in the Void, Stars Hollow and a few portal worlds, the waterfalls and their coves, the gate to Dusk's Embrace,
# Flurry's tail, the Rainbow Ray's beam and plants parting round the hero. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_world_detail.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://detail_shots"
var cam: Camera3D
var player: CharacterBody3D
var only: PackedStringArray = []      # shot name starts to take (the second argument, comma separated); empty = all


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)

	# The Void
	change_scene_to_file(TOWN)
	await _frames(14)
	_grab_player()
	_new_cam()
	await _view("01_mountains_from_the_lake", _at(0, 30, 3.0), Vector3(0, 40, -260), 14)
	await _view("02_mountains_past_the_castle", _at(-60, -60, 14.0), Vector3(40, 50, -300))
	await _view("03_mountains_close", _at(60, -180, 6.0), Vector3(80, 50, -300))
	await _view("04_ground_meadow", _at(20, 70, 1.7), _at(32, 50, 0.0))
	await _view("05_ground_market_edge", _at(-40, 60, 1.7), _at(-52, 44, 0.0))
	await _view("06_ground_castle_ramp", _at(0, -55, 2.0), _at(10, -80, 0.0))
	await _view("07_plateau_falls", _at(-20, -20, 4.0), _at(-46, -32, 5.0))
	await _view("08_castle_fall_east", _at(66, -78, 4.0), _at(48, -98, 7.0))
	await _view("09_castle_fall_west", _at(-46, -86, 4.0), _at(-30, -106, 7.0))
	await _falls_shots("4")
	var gate := current_scene.find_child("Scary World Gate", true, false) as Node3D
	if gate:
		var gb := gate.global_transform.basis
		var gp := gate.global_position
		await _view("10_dusks_embrace_gate", gp + gb.z * 12.0 + gb.x * 3.0 + Vector3(0, 3.0, 0), gp + Vector3(0, 2.0, -6.0))
		await _view("11_dusks_embrace_from_afar", gp + gb.z * 40.0 + gb.x * 12.0 + Vector3(0, 16.0, 0), gp - gb.z * 8.0)
		await _view("11b_dusks_embrace_through_the_bars", gp + gb.z * 2.2 + Vector3(0, 1.7, 0), gp - gb.z * 10.0 + Vector3(0, 1.0, 0))
		await _view("11c_dusks_embrace_from_the_market", _at(-72, 20, 14.0), gp + Vector3(0, 4, 0))
	# Plants parting round her
	if not (any_from("12") or any_from("13") or any_from("14") or any_from("15") or any_from("16")):
		await _later()
		return
	var grass := Vector3(10, 0, 58)
	player.global_position = _at(grass.x, grass.z, 0.3)
	player.velocity = Vector3.ZERO
	await _physics(10)
	await _view("12_plants_round_her", player.global_position + Vector3(2.5, 1.6, 2.5), player.global_position + Vector3(0, 0.6, 0))
	# The Rainbow Ray's beam, out over the meadow
	await _rainbow()
	# Flurry, on her own in front of the camera
	await _flurry()

	await _later()


func _later() -> void:
	var clock := root.get_node("Clock")
	# Stars Hollow
	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	if not (any_from("2") or any_from("5") or any_from("6") or any_from("3")):
		_finish()
		return
	change_scene_to_file(EARTH)
	await _frames(14)
	_grab_player()
	_new_cam()
	var pp := player.global_position
	await _view("20_earth_ground", pp + Vector3(0, 1.7, 0), pp + Vector3(8, 0, -12))
	await _view("21_earth_ground_wide", pp + Vector3(0, 6, 0), pp + Vector3(30, 0, -40))
	await _falls_shots("5")

	# Rhythm Springs' falls
	if any_from("6"):
		change_scene_to_file("res://scenes/portal_worlds/rhythm_springs.tscn")
		await _frames(16)
		_grab_player()
		_new_cam()
		await _falls_shots("6")
	# A few portal worlds
	for w in ["shard_isle", "rootmind", "glenmoor", "frozen_moment"]:
		if not any_from("3%d" % ["shard_isle", "rootmind", "glenmoor", "frozen_moment"].find(w)):
			continue
		change_scene_to_file("res://scenes/portal_worlds/%s.tscn" % w)
		await _frames(16)
		_grab_player()
		_new_cam()
		var q := player.global_position
		var f := -player.global_transform.basis.z
		f.y = 0
		f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
		await _view("3%d_%s_ground" % [["shard_isle", "rootmind", "glenmoor", "frozen_moment"].find(w), w],
			q + Vector3(0, 2.0, 0) - f * 1.5, q + f * 14.0)
	_finish()


func _falls_shots(prefix: String) -> void:
	# Each big waterfall from out front, and its cove from inside looking at the chest and out through the curtain
	var k := 0
	for f in current_scene.get_children():
		if not is_instance_valid(f) or not String(f.name).begins_with("Big Falls"):
			continue
		var info: Dictionary = f.get_meta("info")
		var id: String = info.id
		var out: Vector3 = info.out
		var edge: Vector3 = info.edge
		var front: float = info.front
		var foot: Vector3 = edge + out * front + Vector3(0, info.splash_y, 0)
		await _view("%s%d_%s_falls" % [prefix, k, id], foot + out * (info.width * 1.3) + Vector3(0, 4.0, 0) + info.side * 4.0,
			foot + Vector3(0, (info.lip_y - info.splash_y) * 0.7, 0), 12)
		var inner: float = info.get("inner", info.back)
		var mid: Vector3 = edge + out * ((inner + front) / 2.0) + Vector3(0, info.floor_y + 1.6, 0)
		await _view("%s%d_%s_cove_out" % [prefix, k, id], mid - out * 0.6 + info.side * (info.width * 0.25),
			foot + out * 4.0 + Vector3(0, 1.0, 0))
		var chest := f.find_child("Cove Chest", true, false) as Node3D
		if chest:
			await _view("%s%d_%s_cove_chest" % [prefix, k, id], edge + out * (front - 1.0) + Vector3(0, info.floor_y + 1.9, 0)
				- info.side * 1.2, chest.global_position + Vector3(0, 0.4, 0))
		k += 1


func _rainbow() -> void:
	var ray := (load("res://scripts/rainbow_ray.gd") as GDScript).new() as Node3D
	current_scene.add_child(ray)
	ray.set("shooter", player)
	var from := _at(-10, 66, 1.1)
	var dir := Vector3(0.25, 0.0, -1).normalized()
	cam.make_current()
	cam.global_position = from + Vector3(3.0, 0.9, 1.8)
	cam.look_at(from + dir * 4.5)
	for i in 30:
		ray.call("shine", from, dir, {"radius": 10.0, "time": 1.4})
		await physics_frame
	ray.call("shine", from, dir, {"radius": 10.0, "time": 1.4})
	ray.set_physics_process(false)               # (so the beam's still out when the picture's taken)
	await _shot("13_rainbow_ray", 2)
	ray.set_physics_process(true)
	for i in 7:
		ray.call("shine", from, dir, {"radius": 10.0, "time": 1.4})
		await physics_frame
	ray.call("shine", from, dir, {"radius": 10.0, "time": 1.4})
	ray.set_physics_process(false)
	await _shot("13b_rainbow_ray_later", 2)
	ray.queue_free()


func _flurry() -> void:
	var model: Node3D = load("res://scripts/frozen_moment.gd").flurry_model()
	var spot := player.global_position + Vector3(0, 0, -30)
	spot = _at(spot.x, spot.z, 0.0)
	current_scene.add_child(model)
	model.global_position = spot
	model.rotation.y = PI * 0.75
	await _frames(6)
	await _view("14_flurry_side", spot + Vector3(2.4, 1.0, 0.0), spot + Vector3(0, 0.6, 0))
	await _view("15_flurry_back", spot + Vector3(-1.4, 1.1, -1.6), spot + Vector3(0, 0.55, 0))
	await _view("16_flurry_front", spot + Vector3(1.4, 1.0, 1.6), spot + Vector3(0, 0.6, 0))
	model.queue_free()


func _grab_player() -> void:
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	if player:
		var hud := player.get_node_or_null("HUD") as CanvasLayer
		if hud:
			hud.visible = false


func _at(x: float, z: float, up: float) -> Vector3:
	# A spot "up" metres over whatever's below x, z
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 300, z), Vector3(x, -50, z))
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	var y: float = hit.position.y if hit else 0.0
	return Vector3(x, y + up, z)


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
	current_scene.add_child(cam)
	cam.make_current()


func any_from(start: String) -> bool:
	# Is any shot starting with this wanted?
	if only.is_empty():
		return true
	for o in only:
		if o.begins_with(start) or start.begins_with(o):
			return true
	return false


func want(file: String) -> bool:
	if only.is_empty():
		return true
	for o in only:
		if file.begins_with(o):
			return true
	return false


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	if not want(file):
		return
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
	if not want(file):
		return
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
