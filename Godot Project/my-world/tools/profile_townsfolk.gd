extends SceneTree

# What the townsfolk cost a frame (a check tool, 23 Nov 2026). It loads a place, stands the player in it, times each
# person's Routine._physics_process by calling it straight, then (with a window) switches parts of the townsfolk off in turn (their
# routines, their animation, the people themselves, the little aliens) and says how much each frame saves, paired on
# and off a few times so drift cancels out. Run it with a window for the drawing part (headless
# gives the script numbers only):
#   godot --path "Godot Project/my-world" --script res://tools/profile_townsfolk.gd [-- earth]
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.townsfolk_backup.json"
const CALLS := 30
const FRAMES := 20
const PAIRS := 2


func _initialize() -> void:
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("TIMED OUT")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	var earth := "earth" in OS.get_cmdline_user_args()
	root.get_node("Clock").on_earth = earth
	root.get_node("Clock").set_time(3, 11 * 60.0, true)
	change_scene_to_file("res://scenes/earth/earth.tscn" if earth else "res://scenes/town/town.tscn")
	for i in 10:
		await process_frame
	await create_timer(4.0).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	if player and not earth:
		player.global_position = Vector3(-72, 2, 63)
	game.hold_controls(&"profile", true)
	for i in 60:
		await physics_frame
	var rows := []
	var total := 0.0
	var routines := get_nodes_in_group("routines")
	for r in routines:
		var body := r.get_parent() as Node3D
		var t0 := Time.get_ticks_usec()
		for i in CALLS:
			r._physics_process(1.0 / 60.0)
		var us := (Time.get_ticks_usec() - t0) / float(CALLS)
		total += us
		var dist := body.global_position.distance_to(player.global_position) if player else -1.0
		rows.append([us, str(r.get("character_id")), dist, r.get("_travelling"), r.get("_present"), str(r.current_block().get("do", ""))])
	rows.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	for row in rows:
		print("  %-14s %7.1f us  %5.0f m  travelling %s  present %s  do %s" % [row[1], row[0], row[2], row[3], row[4], row[5]])
	print("ROUTINES %d people, %.0f us a physics frame altogether" % [rows.size(), total])
	var bodies: Array = routines.map(func(r: Node) -> Node: return r.get_parent())
	var anims := []
	for b in bodies:
		anims.append_array((b as Node).find_children("*", "AnimationPlayer", true, false))
	var aliens := current_scene.find_child("LittleAliens", true, false)
	var t1 := Time.get_ticks_usec()
	for i in CALLS:
		for a in anims:
			if a.active:
				(a as AnimationPlayer).advance(1.0 / 60.0)
	print("ANIMATION %d townsfolk players (%d playing, %d active): %.0f us a frame" % [anims.size(),
		anims.filter(func(a): return a.is_playing()).size(), anims.filter(func(a): return a.active).size(),
		(Time.get_ticks_usec() - t1) / float(CALLS)])
	if DisplayServer.get_name() == "headless":
		_finish()                                   # whole frames only mean something with a window
		return
	var parts := {
		"routines": func(on: bool) -> void:
			for r in routines:
				r.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"animation": func(on: bool) -> void:
			for a in anims:
				a.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED,
		"townsfolk": func(on: bool) -> void:
			for b in bodies:
				b.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
				b.visible = on,
		"little aliens": func(on: bool) -> void:
			if aliens:
				aliens.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
				aliens.visible = on,
	}
	for part in parts:
		var saved := 0.0
		var base := 0.0
		for p in PAIRS:
			var on_ms := await _frame_ms()
			parts[part].call(false)
			var off_ms := await _frame_ms()
			parts[part].call(true)
			saved += on_ms - off_ms
			base += on_ms
		print("OFF %-14s saves %6.2f ms of %6.2f ms a frame" % [part, saved / PAIRS, base / PAIRS])
	_finish()


func _frame_ms() -> float:
	for i in 10:
		await process_frame
	var t0 := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
	return (Time.get_ticks_usec() - t0) / 1000.0 / FRAMES


func _finish() -> void:
	var game := root.get_node_or_null("Game")
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	quit()
