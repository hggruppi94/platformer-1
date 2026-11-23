extends SceneTree

# Where the Void's Market spends its frame time (a diagnosis tool, 23 Nov 2026). It stands the player in the Market
# Square at 11 AM with the game's own camera, reads the frame's parts (scripts' _process, physics, rendering on the
# CPU and GPU), then switches off one thing at a time (each autoload, each top-level child of the town) and says how
# much quicker the frame got without it. Run it with a window:
#   godot --path "Godot Project/my-world" --script res://tools/profile_market.gd [-- <spot x> <spot z>]
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.profile_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.profile_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SAMPLE := 60
const SETTLE := 20


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	create_timer(1200.0, true, false, true).timeout.connect(func() -> void:
		print("TIMED OUT")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	change_scene_to_file(TOWN)
	for i in 20:
		await process_frame
	await create_timer(4.0).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	var t0 := Time.get_ticks_msec()
	while lw and lw.busy() and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var args := OS.get_cmdline_user_args()
	var spot := Vector3(-72, 0, 63)
	if args.size() >= 2:
		spot = Vector3(float(args[0]), 0, float(args[1]))
	var player := current_scene.find_child("Player", true, false) as Node3D
	var space := (player as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 60, spot + Vector3.DOWN * 20)
	var hit := space.intersect_ray(q)
	if hit:
		spot = hit.position + Vector3.UP * 0.2
	player.global_position = spot
	player.look_at(Vector3(-72, spot.y, 40), Vector3.UP)
	game.hold_controls(&"profile", true)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	await _frames(SETTLE * 3)
	print("GPU: ", RenderingServer.get_video_adapter_name())
	print("player at ", player.global_position)
	var base := await _sample()
	_line("BASE (everything on)", base, {})
	print("nodes in tree: %d  objects: %d  physics active 3D: %d  collision pairs: %d" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)])
	_count_scripts()
	_time_calls()
	if "--calls-only" in OS.get_cmdline_user_args():
		_finish()
		return
	# One thing off at a time: what the frame saves without it.
	var tried := []
	for c in current_scene.get_children():
		if c == player or c is Camera3D:
			continue
		tried.append(c)
	for n in root.get_children():
		if n == current_scene or not n.get_script():
			continue
		tried.append(n)
	var rows := []
	for n in tried:
		var was: int = n.process_mode
		var vis = n.get("visible")
		# Paired: the frame with it on, just before, against the frame with it off, so slow drift cancels out.
		var on := await _sample()
		n.process_mode = Node.PROCESS_MODE_DISABLED
		await _frames(SETTLE)
		var r := await _sample()
		n.process_mode = was
		await _frames(SETTLE)
		rows.append([on.frame_ms - r.frame_ms, n.name, r, on])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("--- switched off one at a time (frame ms saved, biggest first) ---")
	for row in rows:
		_line("off: %s" % row[1], row[2], row[3])
	print("player ended at ", player.global_position)
	_finish()


func _time_calls() -> void:
	# The minimap's own per-frame work, timed straight (50 calls each).
	var tm := root.get_node("TownMap")
	var s := current_scene
	print("--- per call, microseconds ---")
	print("  followed: %s" % str(root.get_node("Quests").live_followed()))
	for what in [["quest_markers", func(): tm.quest_markers()], ["people", func(): tm.people()],
			["find_children Area3D", func(): s.find_children("*", "Area3D", true, false)],
			["find_children Talk", func(): s.find_children("Talk", "Area3D", true, false)],
			["hidden_found", func(): tm.hidden_found()], ["Boosters.marks", func(): root.get_node("Boosters").marks()],
			["open_tracks", func(): tm.open_tracks()]]:
		var t0 := Time.get_ticks_usec()
		for i in 50:
			what[1].call()
		print("  %-24s %8.1f" % [what[0], (Time.get_ticks_usec() - t0) / 50.0])


func _count_scripts() -> void:
	# How many nodes run _process / _physics_process, by script, biggest first.
	var by := {}
	var stack: Array[Node] = [root]
	while stack:
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var s: Script = n.get_script()
		if s == null:
			continue
		var p := n.is_processing()
		var pp := n.is_physics_processing()
		if not p and not pp:
			continue
		var key := s.resource_path.get_file()
		if not by.has(key):
			by[key] = [0, 0]
		by[key][0] += 1 if p else 0
		by[key][1] += 1 if pp else 0
	var keys := by.keys()
	keys.sort_custom(func(a, b): return by[a][0] + by[a][1] > by[b][0] + by[b][1])
	print("--- scripts running each frame (process, physics) ---")
	for k in keys.slice(0, 30):
		print("  %-32s %4d %4d" % [k, by[k][0], by[k][1]])


func _line(what: String, r: Dictionary, base: Dictionary) -> void:
	var d := ""
	if not base.is_empty():
		d = "  saves %+.2f ms" % (base.frame_ms - r.frame_ms)
	print("%-36s frame %6.2f ms (%5.1f fps)  process %5.2f  physics %5.2f  render cpu %5.2f  gpu %5.2f  draws %5d%s" % [
		what, r.frame_ms, 1000.0 / r.frame_ms, r.process_ms, r.physics_ms, r.cpu_ms, r.gpu_ms, r.draws, d])


func _sample() -> Dictionary:
	var vp := root.get_viewport_rid()
	var proc := 0.0
	var phys := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var draws := 0.0
	var t0 := Time.get_ticks_usec()
	for k in SAMPLE:
		await process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / SAMPLE
	return {"frame_ms": ms, "process_ms": proc * 1000.0 / SAMPLE, "physics_ms": phys * 1000.0 / SAMPLE,
		"cpu_ms": cpu / SAMPLE, "gpu_ms": gpu / SAMPLE, "draws": int(draws / SAMPLE)}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	var game := root.get_node_or_null("Game")
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
