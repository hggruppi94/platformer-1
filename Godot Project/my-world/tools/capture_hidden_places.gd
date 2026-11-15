extends SceneTree

# Screenshots of the hidden places (scripts/hidden_places.gd): each one up close, each one as you'd first spot it from
# far off, and the card you get when you find one. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_hidden_places.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.hidden_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.hidden_capture_backup.cfg"
const SCENES := {"void": "res://scenes/town/town.tscn", "earth": "res://scenes/earth/earth.tscn"}
# How far back (metres) and how high to stand for the close shot, and how high to look
const CLOSE := {"upside_tree": [24.0, 5.0, 12.0], "sky_swing": [24.0, 5.0, 9.0], "kite_hill": [22.0, 3.0, 18.0],
	"old_lookout": [20.0, 5.0, 9.0], "stuck_balloon": [16.0, 1.8, 12.0], "star_well": [14.0, 4.0, 4.0],
	"sleeping_giant": [14.0, 3.0, 3.0], "bottle_tree": [10.0, 1.8, 5.0]}
const FAR := 70.0                     # metres away for the "from afar" shot, back towards the middle of the world

var out_dir := "user://hidden_shots"
var cam: Camera3D
var player: CharacterBody3D


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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	var hidden := root.get_node("Hidden")
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Portals").home_calls.enabled = false
	clock.pulls_home = false
	var n := 0
	for world in ["void", "earth"]:
		if world == "void":
			clock.on_earth = false
			clock.set_time(3, 11 * 60.0, true)
		else:
			clock.on_earth = true
			clock.set_earth_time(12 * 60.0, true)
		change_scene_to_file(SCENES[world])
		await _frames(16)
		_grab_player(false)
		_new_cam()
		var mid := Vector2(0, -75) if world == "void" else Vector2(-20, -20)
		for p in hidden.places_in(world):
			n += 1
			var at := _ground(p.at.x, p.at.y)
			var c: Array = CLOSE.get(p.id, [12.0, 3.0, 2.0])
			var back := (mid - (p.at as Vector2)).normalized()
			var side := Vector2(-back.y, back.x)
			var eye := _clear_view(p.at, at + Vector3(0, c[2], 0), (back + side * 0.35).normalized(), world, float(c[0])) \
				+ Vector3(0, float(c[1]) - 2.2, 0)
			var look := at + Vector3(0, c[2], 0)
			var kite := current_scene.find_child("Kite", true, false) as Node3D if p.id == "kite_hill" else null
			if kite:
				look = kite.global_position
			await _view("%02d_%s_close" % [n, p.id], eye, look)
			var far := _clear_view(p.at, at + Vector3(0, 8.0, 0), back, world)
			await _view("%02d_%s_from_afar" % [n, p.id], far, at + Vector3(0, 8.0, 0))
		# The card when you find one (the HUD on, standing in it)
		var first: Dictionary = hidden.places_in(world)[0]
		_grab_player(true)
		var spot: Vector2 = first.at + Vector2(0, 2.8)
		player.global_position = _ground(spot.x, spot.y) + Vector3(0, 1.0, 0)
		var cam_back := (mid - (first.at as Vector2)).normalized() * 9.0
		cam.global_position = player.global_position + Vector3(cam_back.x, 3.0, cam_back.y)
		cam.look_at(player.global_position + Vector3(0, 1.5, 0))
		await _physics(8)
		await _shot("%s_found_card" % world, 20)
	_finish()


func _clear_view(at: Vector2, target: Vector3, back: Vector2, world: String, dist := FAR) -> Vector3:
	# Somewhere FAR away at eye height with nothing solid between it and the place, starting with the way back towards
	# the middle of the world and going round (the town's in the way from some sides)
	var inside := Rect2(-136, -246, 272, 342) if world == "void" else Rect2(-142, -142, 224, 234)
	var first := Vector3.ZERO
	for k in 16:
		var a := atan2(back.y, back.x) + float((k + 1) / 2) * (PI / 8.0) * (1.0 if k % 2 == 0 else -1.0)
		var p2: Vector2 = at + Vector2(cos(a), sin(a)) * dist
		if not inside.has_point(p2):
			continue
		var eye := _ground(p2.x, p2.y) + Vector3(0, 2.2, 0)
		if first == Vector3.ZERO:
			first = eye
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		if (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return eye
	return first


func _ground(x: float, z: float) -> Vector3:
	return (root.get_node("Bosses").ground(current_scene, x, z) as Vector3)


func _grab_player(hud_on: bool) -> void:
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	if player:
		var hud := player.get_node_or_null("HUD") as CanvasLayer
		if hud:
			hud.visible = hud_on
	var mini = root.get_node("TownMap").get("_mini_layer")
	if mini:
		mini.visible = hud_on


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
	current_scene.add_child(cam)
	cam.make_current()


func _view(file: String, at: Vector3, look: Vector3, settle := 10) -> void:
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	await _shot(file, settle)


func _shot(file: String, settle := 4) -> void:
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
