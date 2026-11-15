extends SceneTree

# Close-up shots of the four portal world bosses' own looks (scripts/boss_parts.gd: Tuskwinter, Grumblefin, the Dawn
# Snatcher and the Stormram), each in its own world, from four sides. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_designs.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.boss_designs_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.boss_designs_backup.cfg"
const WORLDS := [
	["frozen_moment", "res://scenes/portal_worlds/frozen_moment.tscn", "The Frost Gloop"],
	["tide_reef", "res://scenes/portal_worlds/tide_reef.tscn", "The Riptide Gloop"],
	["lanternmoor", "res://scenes/portal_worlds/lanternmoor.tscn", "The Dawn Snatcher"],
	["glenmoor", "res://scenes/portal_worlds/glenmoor.tscn", "The Stormram"],
]

var out_dir := "user://boss_design_shots"
var _had_save := false


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
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	for w in WORLDS:
		change_scene_to_file(w[1])
		for i in 60:
			await process_frame
		await create_timer(1.0).timeout
		var s := current_scene as Node3D
		var p := s.find_child("Player", true, false)
		if p and p.get_node_or_null("HUD"):
			p.get_node("HUD").visible = false
		var boss := s.find_child(w[2], true, false) as Node3D
		if boss == null:
			print("NO BOSS in ", w[0])
			continue
		# Anything the boss sleeps in (the walrus's block of ice) would hide it, so it's taken away for the pictures
		for n in s.find_children("*Ice Block*", "", true, false):
			(n as Node3D).visible = false
		var size := float(boss.get("size"))
		var vis := boss.get_node("Visual") as Node3D
		var fwd := vis.global_transform.basis.z.normalized()
		fwd.y = 0
		fwd = fwd.normalized()
		var side := Vector3(fwd.z, 0, -fwd.x)
		var mid := boss.global_position + Vector3(0, 1.1 * size, 0)
		var cam := Camera3D.new()
		cam.fov = 50
		s.add_child(cam)
		cam.make_current()
		var views := [["front", fwd * 1.0 + side * 0.35], ["side", side], ["back", -fwd + side * 0.3], ["high", fwd * 0.8 - side * 0.6]]
		for v in views:
			var dir: Vector3 = (v[1] as Vector3).normalized()
			cam.global_position = mid + dir * 3.6 * size + Vector3(0, 0.9 * size if v[0] != "high" else 2.2 * size, 0)
			cam.look_at(mid, Vector3.UP)
			await create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out_dir.path_join("%s_%s.png" % [w[0], v[0]]))
			print("SHOT ", w[0], " ", v[0])
	_finish()


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
