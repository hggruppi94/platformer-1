extends SceneTree

# Screenshots of the friend spots and the Seam (scripts/friend_spots.gd, 17 Nov 2026): each of the five shut (with
# the friend's name over its stone) and then open, and the Seam's two ends. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_friend_spots.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.friend_spots_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.friend_spots_capture_backup.cfg"

var out_dir := "user://friend_spot_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var FS: GDScript


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	FS = load("res://scripts/friend_spots.gd")
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	root.get_node("Hidden").guardians = false
	portals = root.get_node("Portals")
	portals.home_calls.enabled = false
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs"]:
		portals.cleared_worlds.append(w)
	var n := 1
	for s in FS.SPOTS:
		await _load(str(s.world))
		var spot = get_nodes_in_group("friend_spots")[0]
		var p := get_first_node_in_group("player") as CharacterBody3D
		var front: Vector3 = spot.global_transform * (Vector3(0, 0, -2.0) if s.id == "lonely_shard" else Vector3(0, 0, 4.0))
		var from: Vector3
		var look: Vector3
		if s.id == "lonely_shard":
			from = spot.global_transform * Vector3(7.0, 3.5, -5.0)
			look = spot.global_transform * Vector3(0, 2.5, 7.0)
		else:
			from = spot.global_transform * Vector3(3.5, 3.2, 6.5)
			look = spot.target() + Vector3(0, 0.2, 0)
		await _pose(p, front, from, look, "%02d_%s_shut" % [n, s.id])
		spot.open_up()
		await _frames(150)
		await _pose(p, front, from, look, "%02d_%s_open" % [n + 1, s.id], true)
		n += 2
	# The Seam: Glenmoor's end in the hot spring's nook, and Lanternmoor's
	root.get_node("Dialogue").flags["seam_found"] = true
	for w in ["glenmoor", "lanternmoor"]:
		await _load(w)
		var p := get_first_node_in_group("player") as CharacterBody3D
		var g := get_nodes_in_group("seam")[0] as Node3D
		var spot = get_nodes_in_group("friend_spots")[0]
		var away: Vector3 = spot.global_transform * Vector3(0, 0, 6.0)
		var from: Vector3 = spot.global_transform * Vector3(-2.2, 2.6, 1.2)
		if w == "lanternmoor":
			from = g.global_position + spot.global_basis * Vector3(-3.0, 3.5, 5.0)
		await _pose(p, away, from, g.global_position, "%02d_seam_in_%s" % [n, w])
		n += 1
	_finish()


func _load(id: String) -> void:
	change_scene_to_file(str(portals.world(id).scene))
	await _frames(40)
	var p := get_first_node_in_group("player") as CharacterBody3D
	if p:
		var hud = p.get_node_or_null("HUD")
		if hud:
			hud.visible = false
	for c in current_scene.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 900
	current_scene.add_child(cam)
	cam.make_current()


func _pose(p: CharacterBody3D, at: Vector3, from: Vector3, to: Vector3, file: String, keep := false) -> void:
	if not keep and p:
		p.global_position = at + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	await _frames(20)
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
