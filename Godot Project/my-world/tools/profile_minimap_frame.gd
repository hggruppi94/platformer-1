extends SceneTree

# What the minimap costs in every place in the game (a diagnosis tool, 23 Nov 2026). It loads each place in turn with
# your own progress (read from your save, which is put aside and back as the tests do, and never written), lets it
# settle, then measures the frame with the minimap on and with it switched off in Settings (what a player can do), in
# pairs so slow drift cancels out, and times the minimap's own helpers. It also notes the worst frame while the place's
# map picture is taken (a place you go through a door or portal into gets one the first time).
# --draws times the minimap's drawing each frame; --parts switches each of its parts off in turn; --shot <folder>
# saves a picture of each place's screen.
# Run it with a window:
#   godot --path "Godot Project/my-world" --script res://tools/profile_minimap_frame.gd [-- <only scenes whose path has this>]
# The budget each place is checked against is MINIMAP_BUDGET_MS of frame time: more than that and it's FAIL.

const SAVE := "user://save.json"
const BACKUP := "user://save.minimap_frame_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.minimap_frame_backup.cfg"
const FOLDERS := ["res://scenes/town", "res://scenes/earth", "res://scenes/school", "res://scenes/secret_garden",
	"res://scenes/scary_world", "res://scenes/portal_worlds", "res://scenes/races", "res://scenes/bosses",
	"res://scenes/interiors"]
const SAMPLE := 90
const SETTLE := 20
const PAIRS := 6
const MINIMAP_BUDGET_MS := 0.5

var rows := []
var fails := 0


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	create_timer(3000.0, true, false, true).timeout.connect(func() -> void:
		print("TIMED OUT")
		_finish())
	_run.call_deferred()


func _scenes() -> Array:
	var out := []
	for dir in FOLDERS:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tscn"):
				out.append(dir + "/" + f)
	var args := Array(OS.get_cmdline_user_args())
	var si := args.find("--shot")
	if si >= 0 and si + 1 < args.size():
		args.remove_at(si + 1)                         # (the folder after --shot isn't a place filter)
	var only := args.filter(func(a: String) -> bool: return not a.begins_with("--"))
	if not only.is_empty():
		out = out.filter(func(p: String) -> bool: return only[0] in p)
	return out


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game.hold_saves = true
	game.load_game()                                   # your progress: followed quests, met people, open races...
	game.hold_saves = true
	game.needs_creator = false
	game.pending_message = ""
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.minimap = true
	root.get_node("Clock").set("pulls_home", false)
	var tm := root.get_node("TownMap")
	print("GPU: ", RenderingServer.get_video_adapter_name())
	print("followed: ", root.get_node("Quests").live_followed())
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for path in _scenes():
		change_scene_to_file(path)
		# The worst frame while it settles (the map picture is taken 0.6 s in, the first time)
		var worst := 0.0
		var t_end := Time.get_ticks_msec() + 4500
		var last := Time.get_ticks_usec()
		while Time.get_ticks_msec() < t_end:
			await process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
		var lw := current_scene.get_node_or_null("Mesh LODs") if current_scene else null
		var t0 := Time.get_ticks_msec()
		while lw and lw.busy() and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
		if current_scene == null:
			continue
		var player := current_scene.find_child("Player", true, false)
		if player and player.has_method("lock_input"):
			game.hold_controls(&"profile", true)
		await _frames(SETTLE)
		var shown: bool = tm._mini_layer.visible
		var si := OS.get_cmdline_user_args().find("--shot")
		if si >= 0 and shown:
			# A picture of the screen, minimap and all, to see it still looks right
			await RenderingServer.frame_post_draw
			var dir := str(OS.get_cmdline_user_args()[si + 1])
			DirAccess.make_dir_recursive_absolute(dir)
			root.get_texture().get_image().save_png(dir.path_join(path.get_file().get_basename() + ".png"))
		if tm.on_earth() and "_earth_tex" in tm:
			print("    earth picture made: %s  failed: %s  drawn layer showing: %s  window %s" % [tm._earth_tex != null,
				tm._earth_bake_failed, tm._mini_earth.visible, tm._mini_tex.size])
		var on_ms := 0.0
		var off_ms := 0.0
		var gpu_d := 0.0
		var cpu_d := 0.0
		for p in PAIRS:
			var on_s := await _sample()
			on_ms += on_s.frame_ms
			settings.minimap = false                  # what a player can do: Settings > Display > Minimap off
			await _frames(SETTLE)
			var off_s := await _sample()
			off_ms += off_s.frame_ms
			gpu_d += (on_s.gpu - off_s.gpu) / PAIRS
			cpu_d += (on_s.cpu - off_s.cpu) / PAIRS
			settings.minimap = true
			await _frames(SETTLE)
		on_ms /= PAIRS
		off_ms /= PAIRS
		if "--draws" in OS.get_cmdline_user_args() and shown:
			await _draw_times(tm)
		if "--parts" in OS.get_cmdline_user_args() and shown:
			await _parts(tm)
		var calls := _time_calls(tm)
		var cost := on_ms - off_ms
		var ok := cost <= MINIMAP_BUDGET_MS
		fails += 0 if ok else 1
		rows.append([path.get_file(), on_ms, off_ms, cost, shown, calls, worst])
		print("    render: gpu %+5.2f ms  cpu %+5.2f ms" % [gpu_d, cpu_d])
		print("%s %-28s minimap %s  frame on %6.2f ms  off %6.2f ms  costs %+5.2f ms  helpers %s  worst settling frame %6.1f ms" % [
			"PASS" if ok else "FAIL", path.get_file(), "shown " if shown else "hidden", on_ms, off_ms, cost, calls, worst])
		game.hold_controls(&"profile", false)
	print("RESULT " + ("PASSED" if fails == 0 else "FAILED (%d)" % fails))
	_finish()


var _keep := {}
var _acc := {}


func _t(name: String, f: Callable) -> void:
	var t0 := Time.get_ticks_usec()
	f.call()
	_acc[name] = _acc.get(name, 0) + Time.get_ticks_usec() - t0


func _timed_mini(tm: Node) -> void:
	# The minimap's own draw, timed (this runs inside the overlay's draw, so drawing is allowed)
	_t("ALL", func(): tm._draw_mini())
	var c: Control = tm._mini_overlay
	var scale: float = tm._mini_scale_px()
	var offset: Vector2 = tm._mini_origin
	_t("races", func(): tm._draw_races(c, offset, scale, false))
	_t("places", func(): tm._draw_mini_places(c, offset, scale))
	_t("boosters", func(): tm._draw_boosters(c, offset, scale, false))
	_t("arrow", func(): tm._arrow(c, Vector2(110, 110), tm.nina_facing(), 10.0))
	_t("stars", func():
		for q in tm._mini_marks:
			tm._star(c, offset + tm.to_map(q.pos) * scale, 8.0, q.colour))
	_t("people", func():
		for pp in tm.people():
			c.draw_circle(offset + tm.to_map(pp.pos) * scale, 4.0, Color.WHITE))
	_acc["n_stars"] = tm._mini_marks.size()
	_acc["n_people"] = tm.people().size()
	_acc["frames"] = _acc.get("frames", 0) + 1


func _timed_compass(tm: Node) -> void:
	var t0 := Time.get_ticks_usec()
	tm._draw_compass()
	_acc["compass"] = _acc.get("compass", 0) + Time.get_ticks_usec() - t0


func _draw_times(tm: Node) -> void:
	var mini_cb := Callable(tm, "_draw_mini")
	var comp_cb := Callable(tm, "_draw_compass")
	var a := _timed_mini.bind(tm)
	var b := _timed_compass.bind(tm)
	tm._mini_overlay.draw.disconnect(mini_cb)
	tm._mini_overlay.draw.connect(a)
	tm._mini_frame.draw.disconnect(comp_cb)
	tm._mini_frame.draw.connect(b)
	_acc = {}
	await _frames(120)
	tm._mini_overlay.draw.disconnect(a)
	tm._mini_overlay.draw.connect(mini_cb)
	tm._mini_frame.draw.disconnect(b)
	tm._mini_frame.draw.connect(comp_cb)
	var n := maxf(1.0, float(_acc.get("frames", 1)))
	var line := "    draw (us a frame):"
	for k in _acc:
		if k.begins_with("n_"):
			line += "  %s %d" % [k, _acc[k]]
		elif k != "frames":
			line += "  %s %.0f" % [k, _acc[k] / n]
	print(line)
	# And TownMap's own _process, timed by calling it the same way the tree does
	var t0 := Time.get_ticks_usec()
	for i in 60:
		tm._process(0.016)
	print("    TownMap._process  %.0f us a call (with its queue_redraws)" % ((Time.get_ticks_usec() - t0) / 60.0))


func _pic(tm: Node, off: bool) -> void:
	# The minimap's picture of the place swapped for a 1 pixel one (and back): _process puts whichever is current
	# back on the TextureRect every frame, so it's the source that's swapped
	var tex = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)) if off else null
	tm._texture = tex if off else _keep.tex
	if tm._snap.has("tex"):
		tm._snap.tex = tex if off else _keep.snap


func _earth_pic(tm: Node, off: bool) -> void:
	# The Earth Picture drawing nothing at all (and back)
	var cb := Callable(tm, "_draw_mini_earth")
	if off and tm._mini_earth.draw.is_connected(cb):
		tm._mini_earth.draw.disconnect(cb)
	elif not off and not tm._mini_earth.draw.is_connected(cb):
		tm._mini_earth.draw.connect(cb)
	tm._mini_earth.queue_redraw()


func _parts(tm: Node) -> void:
	# Each part of the minimap switched off on its own (paired), to see which one the frame time goes on
	var mini: Control = tm._mini_tex.get_parent()
	_keep = {"tex": tm._texture, "snap": tm._snap.get("tex")}
	var settings := root.get_node("Settings")
	var parts := {
		"setting off": [func(): settings.minimap = false, func(): settings.minimap = true],
		"code paused": [func(): tm.process_mode = Node.PROCESS_MODE_DISABLED, func(): tm.process_mode = Node.PROCESS_MODE_ALWAYS],
		"map picture": [_pic.bind(tm, true), _pic.bind(tm, false)],
		"live overlay": [func(): tm._mini_overlay.visible = false, func(): tm._mini_overlay.visible = true],
		"compass ring": [func(): tm._mini_frame.visible = false, func(): tm._mini_frame.visible = true],
		"round mask": [func(): mini.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED, func(): mini.clip_children = CanvasItem.CLIP_CHILDREN_ONLY],
	}
	if tm.get("_mini_earth") != null:
		parts["earth picture"] = [_earth_pic.bind(tm, true), _earth_pic.bind(tm, false)]
	for name in parts:
		var on_ms := 0.0
		var off_ms := 0.0
		var gpu_d := 0.0
		var cpu_d := 0.0
		for p in PAIRS:
			var on_s := await _sample()
			on_ms += on_s.frame_ms
			parts[name][0].call()
			await _frames(SETTLE)
			off_ms += (await _sample()).frame_ms
			parts[name][1].call()
			await _frames(SETTLE)
		print("    part %-14s saves %+5.2f ms" % [name, (on_ms - off_ms) / PAIRS])


func _time_calls(tm: Node) -> String:
	# The minimap's per-frame helpers, 30 calls each, microseconds a call
	var out := ""
	for what in [["stars", func(): tm.quest_markers()], ["people", func(): tm.people()],
			["races", func(): tm.open_tracks()], ["boosters", func(): root.get_node("Boosters").marks()]]:
		var t0 := Time.get_ticks_usec()
		for i in 30:
			what[1].call()
		out += "%s %.0f us  " % [what[0], (Time.get_ticks_usec() - t0) / 30.0]
	return out.strip_edges()


var gpu_sum := 0.0
var cpu_sum := 0.0


func _sample() -> Dictionary:
	var vp := root.get_viewport_rid()
	var gpu := 0.0
	var cpu := 0.0
	var t0 := Time.get_ticks_usec()
	for k in SAMPLE:
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	return {"frame_ms": (Time.get_ticks_usec() - t0) / 1000.0 / SAMPLE, "gpu": gpu / SAMPLE, "cpu": cpu / SAMPLE}


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
