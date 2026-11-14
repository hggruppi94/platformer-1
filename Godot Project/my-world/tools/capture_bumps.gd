extends SceneTree

# Screenshots of the bumps and boinks (scripts/bumps.gd): running into a crate and a mushroom on foot (the bounce, the
# puff of smoke, the squash) and a bonk on a board. Built in the Practice Park. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_bumps.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.bumps_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.bumps_capture_backup.cfg"
const PARK := "res://scenes/skate/test_park.tscn"

var out_dir := "user://bumps_shots"
var _had_save := false
var p: CharacterBody3D
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	game._resume = {}
	root.get_node("Settings").tips = false
	change_scene_to_file(PARK)
	await _frames(20)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	if game.riding:
		game.toggle_skateboard()
	await _physics(5)
	var at := _ground(Vector3(0, 0, 0))
	print("ground ", at)
	_box("Bump Crate", at + Vector3(0, 0.9, -4), Vector3(3, 1.8, 1.2), Color(0.72, 0.5, 0.3))
	_box("Bump Mushroom", at + Vector3(8, 1.2, -4), Vector3(3, 2.4, 1.2), Color(1.0, 0.55, 0.8))
	await _bump(at + Vector3(0, 0.85, -2.6), "01_bonk_a_crate")
	await _physics(60)
	await _bump(at + Vector3(8, 0.85, -2.6), "02_boink_off_a_mushroom")
	await _physics(60)
	if not game.riding:
		game.toggle_skateboard()
	await _physics(5)
	await _bump(at + Vector3(0, 0.85, -1.2), "03_bump_on_a_board", 11.0, 4)
	_finish()


func _ground(xz: Vector3) -> Vector3:
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 60, xz.z), Vector3(xz.x, -20, xz.z))
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(xz.x, 0, xz.z)


func _box(name: String, at: Vector3, size: Vector3, colour: Color) -> void:
	var b := StaticBody3D.new()
	b.name = name
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mesh.material = mat
	mi.mesh = mesh
	b.add_child(mi)
	current_scene.add_child(b)
	b.global_position = at


func _bump(from: Vector3, file: String, speed := 9.0, after := 3) -> void:
	p.global_position = from
	p.velocity = Vector3.ZERO
	var arm := p.get_node("SpringArm3D") as Node3D
	arm.rotation.y = 1.1                      # from the side a little, so the puff shows past her
	p.visual.rotation.y = PI
	if game.riding:
		var s := p.get_node("Skate")
		s._yaw = PI
		s.state = s.State.ROLL
	await _physics(20)
	p.remove_meta("bump_wait")
	if p.has_meta("last_bump"):
		p.remove_meta("last_bump")
	for i in 30:
		if not p.has_meta("last_bump"):
			p.velocity = Vector3(0, p.velocity.y, -speed)
		await physics_frame
		if p.has_meta("last_bump"):
			break
	await _physics(after)
	await _shot(file)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file, " ", p.get_meta("last_bump", {}))


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
