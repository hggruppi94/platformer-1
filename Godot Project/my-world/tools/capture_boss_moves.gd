extends SceneTree

# Screenshots of every boss shockwave's own look (scripts/shock_ring.gd STYLES) and of the bosses' ranged moves
# (scripts/boss_moves.gd): the Gloop King's goo shot, fan and lob, and a blink. Taken in the Gloop King's court, each
# ring stopped halfway out. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_boss_moves.gd -- <output folder>
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.moves_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.moves_capture_backup.cfg"
# Each style in the colour its boss gives it
const COLOURS := {
	"plain": Color(1, 1, 1), "goo": Color(0.45, 0.9, 0.3), "frost": Color(0.6, 0.9, 1.0), "tide": Color(0.3, 0.7, 1.0),
	"chime": Color(0.3, 0.9, 0.8), "dawn": Color(1.0, 0.7, 0.3), "rubble": Color(0.75, 0.6, 0.45),
	"gust": Color(0.85, 0.9, 1.0), "beat": Color(1.0, 0.45, 0.8), "glitch": Color(0.7, 0.3, 1.0),
	"static": Color(1.0, 0.95, 0.4), "gloom": Color(0.45, 0.3, 0.7), "hush": Color(0.7, 0.75, 1.0),
	"chaos": Color(0.85, 0.25, 0.95), "star": Color(0.7, 0.85, 1.0), "lava": Color(1.0, 0.4, 0.1),
	"energy": Color(0.4, 0.85, 1.0), "thorn": Color(0.5, 0.8, 0.3), "moth": Color(0.95, 0.85, 0.5),
	"bubble": Color(0.5, 0.9, 0.8), "ribbon": Color(1.0, 0.5, 0.6)}

var out_dir := "user://moves_shots"
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var RING: GDScript = load("res://scripts/shock_ring.gd")
	var MOVES: GDScript = load("res://scripts/boss_moves.gd")
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Portals").home_calls.enabled = false
	root.get_node("Clock").pulls_home = false
	root.get_node("Bosses").enter_kingdom()
	await _frames(14)
	await _physics(4)
	var scene := current_scene as Node3D
	var player := scene.find_child("Player", true, false) as CharacterBody3D
	var king := scene.get_node_or_null("The Gloop King") as CharacterBody3D
	for e in get_nodes_in_group("enemies"):
		if e != king:
			e.queue_free()
	var flood := scene.find_child("Slime Flood", true, false)
	if flood:
		flood.process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 2000
	scene.add_child(cam)
	var mid := Vector3(0, 1.2, 88)
	if king:
		king.global_position = mid + Vector3(0, 0, -14)
		king.set_physics_process(false)
	player.global_position = mid + Vector3(0, 0.3, 18)
	player.set("_invulnerable_timer", 999.0)
	player.set_physics_process(false)
	await _physics(4)

	# Every shockwave
	var n := 0
	for style in RING.STYLES:
		var r: Node3D = RING.spawn(scene, mid, 9.0, COLOURS.get(style, Color.WHITE), 0, 1.6, style)
		await _wait(0.85)
		r.process_mode = Node.PROCESS_MODE_DISABLED       # (held still: frames are slow here)
		n += 1
		await _view("%02d_ring_%s" % [n, style], mid + Vector3(0, 3.2, 9.0), mid + Vector3(0, 0, -0.5))
		r.queue_free()
		await _frames(2)

	# The King's moves, frozen in the air
	if king:
		var m: Node3D = MOVES.of(king)
		m.set("_t", 999.0)
		player.global_position = king.global_position + Vector3(4.0, 0.0, 11.0)
		player.set("_invulnerable_timer", 0.0)            # (so she isn't blinking; nothing reaches her anyway)
		await _physics(2)
		for kind in ["shot", "fan", "lob"]:
			if kind == "lob":
				m.call("_lob", player)
			else:
				for i in ([-1, 0, 1] if kind == "fan" else [0]):
					m.call("_shoot", player, MOVES.FAN_SPREAD * i)
			await _wait(0.6 if kind != "lob" else 0.45)
			for s in get_nodes_in_group("boss_shots"):
				s.process_mode = Node.PROCESS_MODE_DISABLED
			n += 1
			var line: Vector3 = (player.global_position - king.global_position)
			var side: Vector3 = Vector3(-line.z, 0, line.x).normalized()
			var at: Vector3 = king.global_position + line * 0.4
			await _view("%02d_king_%s" % [n, kind], at + side * 10.0 + Vector3(0, 4.0 if kind == "lob" else 2.5, 0), at + Vector3(0, 3.0 if kind == "lob" else 1.2, 0))
			for s in get_nodes_in_group("boss_shots"):
				s.queue_free()
			await _frames(2)
		m.set("centre", king.global_position)
		m.set("centre_set", true)
		m.call("_vanish", player)
		await _wait(0.05)
		n += 1
		await _view("%02d_king_blink" % n, king.global_position + Vector3(7.0, 3.5, 6.0), king.global_position + Vector3(0, 1.5, 0), 2)
	_finish()


func _view(file: String, at: Vector3, look: Vector3, settle := 6) -> void:
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false               # (no HUD or messages over the pictures)
	cam.make_current()
	cam.global_position = at
	cam.look_at(look)
	for i in settle:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


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
