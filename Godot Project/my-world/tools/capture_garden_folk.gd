extends SceneTree

# Screenshots of the Tuftlings (scripts/garden_folk.gd) in the Secret Garden: Tuftling Hollow from above and from the
# glade, each named Tuftling close up by their burrow, a row of all eight, and a few of the crowd about the garden.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_garden_folk.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.garden_folk_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.garden_folk_capture_backup.cfg"
const GARDEN := "res://scenes/secret_garden/secret_garden.tscn"

var out_dir := "user://garden_folk_shots"
var cam: Camera3D


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
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	clock.pulls_home = false
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	change_scene_to_file(GARDEN)
	await _frames(14)
	var sg := current_scene as Node3D
	var folk := sg.get_node("Tuftlings")
	var guard := 600
	while not folk.get("ready_done") and guard > 0:
		guard -= 1
		await _frames(1)
	var p := sg.find_child("Player", true, false) as CharacterBody3D
	var gt: Vector2 = load("res://scripts/secret_garden_groves.gd").GREAT_TREE
	var land := load("res://scripts/secret_garden_land.gd")
	var tree := Vector3(gt.x, land.height(gt.x, gt.y), gt.y)
	# (the player stands by the tree, so everyone nearby is awake, then out of the pictures)
	p.global_position = tree + Vector3(0, 1, 9)
	await _physics(60)
	p.global_position = tree + Vector3(0, 40, 0)
	p.set_physics_process(false)
	p.visible = false
	cam = Camera3D.new()
	cam.fov = 50
	sg.add_child(cam)
	cam.make_current()
	await _view("01_tuftling_hollow_from_above", tree + Vector3(24, 26, 24), tree, 20)
	await _view("02_tuftling_hollow", tree + Vector3(20, 3.2, 6), tree + Vector3(0, 1, 0), 10)
	# Each named one, stood still in front of their door, looking at the camera
	var homes: Dictionary = folk.homes
	var i := 3
	for id in folk.FOLK:
		var w := folk.folk[id] as Node3D
		var h: Dictionary = homes[id]
		var fwd := Vector3(sin(h.face), 0, cos(h.face))
		w.set("resting", true)
		w.global_position = (h.door as Vector3) + fwd * 0.6
		w.rotation.y = h.face
		var ap := w.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.play("idle")
		# (the hidden player waits overhead, so they count as near and stay drawn)
		p.global_position = w.global_position + Vector3(0, 12, 0)
		folk.set("_pace_t", 0.0)
		await _physics(4)
		var at := w.global_position
		await _view("%02d_%s" % [i, id], at + fwd * 1.5 + Vector3(0, 0.6, 0) + fwd.cross(Vector3.UP) * 0.45,
			at + Vector3(0, 0.45, 0) - fwd * 0.8, 6)
		i += 1
	# All eight in a row on the glade
	var fh: Dictionary = homes[folk.FOLK.keys()[0]]
	var row_at: Vector3 = (fh.door as Vector3) + Vector3(sin(fh.face), 0, cos(fh.face)) * 3.0
	var n := 0
	for id in folk.FOLK:
		var w := folk.folk[id] as Node3D
		w.set("resting", true)
		var x := (n - 3.5) * 0.85
		w.global_position = Vector3(row_at.x + x, land.height(row_at.x + x, row_at.z) + 0.02, row_at.z)
		w.rotation.y = 0.0
		w.visible = true
		var ap := w.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			ap.play("cheer" if ap.has_animation("cheer") and n % 2 == 0 else "wave")
		n += 1
	p.global_position = row_at + Vector3(0, 12, 0)
	folk.set("_pace_t", 0.0)
	await _physics(4)
	await _view("11_all_eight", row_at + Vector3(0, 0.9, 4.2), row_at + Vector3(0, 0.45, 0), 14)
	# A couple of the crowd, wherever they've wandered
	var shots := 0
	for c in folk.crowd:
		if shots >= 3:
			break
		var w := c as Node3D
		p.global_position = w.global_position + Vector3(0, 12, 0)
		folk.set("_pace_t", 0.0)
		await _frames(2)
		if not w.visible:
			continue
		var at := w.global_position
		var back := Vector3(sin(w.rotation.y), 0, cos(w.rotation.y))
		await _view("%02d_crowd_%s" % [12 + shots, str(w.name).to_snake_case()], at + back * 2.4 + Vector3(0.6, 1.0, 0),
			at + Vector3(0, 0.4, 0), 6)
		shots += 1
	_finish()


func _view(file: String, at: Vector3, look: Vector3, settle := 8) -> void:
	cam.make_current()
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam.global_position = at
	cam.look_at(look)
	for k in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _physics(n: int) -> void:
	for k in n:
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
