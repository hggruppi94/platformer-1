extends SceneTree

# Pictures of the moving pixel flames (scripts/fire_fx.gd, 23 Nov 2026): Dark Hollow's green lamps, Rhythm Springs'
# torches and a flaring stone's bonfire, Lanternmoor's lit beacons and the Haunted House's candles. Each spot is found
# from the flames themselves (the camera stands a little way off each one and looks at it), and the first is shot four
# times a moment apart so you can see it move. With --no-fire it shoots the same spots with the old flame shapes, for
# a before and after.
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_fire_fx.gd -- <folder> [--no-fire]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.fire_fx_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.fire_fx_capture_backup.cfg"
const FIRE := preload("res://scripts/fire_fx.gd")
const PLACES := [
	["dark_hollow", "res://scenes/portal_worlds/dark_hollow.tscn", 3],
	["rhythm_springs", "res://scenes/portal_worlds/rhythm_springs.tscn", 2],
	["lanternmoor", "res://scenes/portal_worlds/lanternmoor.tscn", 2],
	["haunted_house", "res://scenes/interiors/haunted_house.tscn", 1],
]

var out_dir := "user://fire_fx_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].begins_with("--"):
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(1800.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var args := OS.get_cmdline_user_args()
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Portals").home_calls.enabled = false
	root.get_node("WorldDetail").fire = not ("--no-fire" in args)
	for place: Array in PLACES:
		change_scene_to_file(place[1])
		for i in 16:
			await process_frame
		var s := current_scene as Node3D
		if place[0] == "lanternmoor":
			for i in 3:
				s.light_beacon(i)
		await create_timer(2.0).timeout
		var player := s.find_child("Player", true, false) as Node3D
		if player:
			player.visible = false
		for c in root.find_children("*", "CanvasLayer", true, false):
			(c as CanvasLayer).visible = false
		var targets := _flames(s)
		print("%s: %d flames" % [place[0], targets.size()])
		cam = Camera3D.new()
		cam.fov = 50
		cam.far = 2000
		s.add_child(cam)
		cam.make_current()
		var picked := _spread(targets, int(place[2]))
		for k in picked.size():
			var f: Node3D = picked[k]
			f.visible = true                     # a stone's bonfire is only out while it flares
			var tall := _tall(f)
			var foot := _foot(f)
			var look := foot + Vector3(0, tall * 1.2, 0)
			var away := maxf(tall * 6.0, 1.6)
			var dir := Vector3(1, 0, 0.6).normalized()
			cam.global_position = look + dir * away + Vector3(0, away * 0.25, 0)
			cam.look_at(look)
			var shots := 4 if k == 0 else 1
			for n in shots:
				await _shot("%s_%d%s" % [place[0], k + 1, "" if shots == 1 else "_" + "abcd"[n]])
				await create_timer(0.15).timeout
		# A wider look at the first one with the place round it
		if not picked.is_empty():
			var f0: Node3D = picked[0]
			var t0 := _tall(f0)
			cam.global_position = _foot(f0) + Vector3(6, 3 + t0, 4)
			cam.look_at(_foot(f0) + Vector3(0, t0, 0))
			await _shot(place[0] + "_wide")
	_finish()


func _flames(s: Node) -> Array:
	var out := []
	for n in s.find_children("*", "Node3D", true, false):
		if n.get_node_or_null(FIRE.NAME) != null:
			out.append(n)
		elif n is MeshInstance3D and n.material_override and String(n.material_override.resource_name) in FIRE.FLAME_MATS:
			out.append(n)
		elif n.name == "Flame" and not n.has_meta(FIRE.META) and not (n is MeshInstance3D and n.get_parent().name == "Flame"):
			out.append(n)
	return out


func _spread(list: Array, n: int) -> Array:
	var out := []
	if list.is_empty():
		return out
	for k in n:
		out.append(list[int(float(k) / maxf(n, 1) * list.size()) % list.size()])
	return out


func _foot(f: Node3D) -> Vector3:
	if f is MeshInstance3D:
		var box := (f as MeshInstance3D).get_aabb()
		return f.global_transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	return f.global_position


func _tall(f: Node3D) -> float:
	if f is MeshInstance3D:
		return maxf((f as MeshInstance3D).get_aabb().size.y * f.global_transform.basis.get_scale().y, 0.1)
	return 1.0


func _shot(file: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0)
