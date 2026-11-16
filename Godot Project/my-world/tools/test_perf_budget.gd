extends SceneTree

# The frame budget check (15 Nov 2026, the detailed props pipeline). It stands a camera at a few of the most-seen
# spots in Stars Hollow and the Void and reads what the graphics card was asked to draw that frame: draw calls,
# objects and triangles, plus how long the frame took on the CPU and GPU.
#
# Draw calls and triangles are the same on every PC, so those are the checks (a budget per spot, set with some
# room above what's there now). Frame times depend on the PC, so they're only printed, and on Hayden's PC they
# give the real frames-per-second numbers.
#
#   godot --path "Godot Project/my-world" --script res://tools/test_perf_budget.gd [-- --report <file.json> --old-props --no-batch --no-occluders --before --earth]
#
# Run it with a window (not --headless): a headless run draws nothing, so every count reads 0 and the checks are
# skipped. --old-props turns the detailed props off (WorldDetail.detail_props = false) and --no-batch the merging of
# still pieces (WorldDetail.batching), for a before/after; --earth only measures Stars Hollow.
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.perf_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.perf_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

# name: [scene, eye, look at, draw call budget, triangle budget]
const SPOTS := [
	# Stars Hollow, after the 15 Nov 2026 pipeline (merged pieces, detailed props, occluders): on 15 Nov the cloud
	# measured 2,658 / 2,942 / 2,104 / 2,118 draws here (before it: 4,415 / 5,361 / 3,199 / 5,691)
	["earth_green_eye", EARTH, Vector3(0, 1.7, 16), Vector3(0, 2.5, 0), 3100, 3_000_000],
	["earth_green_corner", EARTH, Vector3(17, 1.7, 17), Vector3(-6, 2.0, -6), 3300, 3_000_000],
	["earth_main_street", EARTH, Vector3(0, 1.7, -30), Vector3(0, 2.0, -90), 2500, 3_000_000],
	["earth_over_town", EARTH, Vector3(0, 45, 75), Vector3(0, 0, -10), 2600, 3_000_000],
	# The Void isn't batched yet (7,120 and 8,693 draws, 15.7M and 14.3M triangles): these only stop it getting worse
	["void_market", TOWN, Vector3(-40, 4, 70), Vector3(-30, 2, 30), 7900, 17_500_000],
	["void_over_town", TOWN, Vector3(0, 60, 110), Vector3(0, 0, 0), 9600, 16_000_000],
]
const SETTLE := 20          # frames to wait after moving the camera (shaders compile, LODs settle)
const SAMPLE := 30          # frames to average

var failures := 0
var cam: Camera3D
var report := {}
var report_path := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--report")
	if i >= 0 and i + 1 < args.size():
		report_path = args[i + 1]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
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
	var detail := root.get_node_or_null("WorldDetail")
	var args := OS.get_cmdline_user_args()
	if detail and "--old-props" in args:
		detail.detail_props = false
	if detail and "--no-batch" in args:
		detail.batching = false
	if detail and "--no-occluders" in args:
		detail.occluders = false
	if "--before" in args and detail:       # everything this pipeline added, off: the game as it was
		detail.detail_props = false
		detail.batching = false
		detail.occluders = false
	report["props"] = "old" if "--old-props" in args else "detailed"
	report["batching"] = not ("--no-batch" in args)
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["gpu"] = RenderingServer.get_video_adapter_name()
	var headless := DisplayServer.get_name() == "headless"
	var scene_now := ""
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for s in SPOTS:
		if "--earth" in args and s[1] != EARTH:
			continue
		if s[1] != scene_now:
			scene_now = s[1]
			clock.on_earth = scene_now == EARTH
			if scene_now == EARTH:
				clock.set_earth_time(12 * 60.0, true)
			else:
				clock.set_time(3, 11 * 60.0, true)
			change_scene_to_file(scene_now)
			await _frames(16)
			var player := current_scene.find_child("Player", true, false) as Node3D
			if player:
				var hud := player.get_node_or_null("HUD") as CanvasLayer
				if hud:
					hud.visible = false
			cam = Camera3D.new()
			cam.fov = 70
			cam.far = 2000
			current_scene.add_child(cam)
		if "--no-shadows" in args:          # (diagnostic: how much the sun's shadows cost)
			for l in current_scene.find_children("*", "DirectionalLight3D", true, false):
				(l as DirectionalLight3D).shadow_enabled = false
		if "--no-people" in args:           # (diagnostic: how much the townsfolk cost)
			var ch := current_scene.get_node_or_null("Characters") as Node3D
			if ch:
				ch.visible = false
		cam.make_current()
		cam.global_position = s[2]
		cam.look_at(s[3])
		await _frames(SETTLE)
		var r := await _sample()
		if detail and scene_now == EARTH:
			r["batch"] = detail.last_batch
		report[s[0]] = r
		print("%-20s draws %5d  objects %5d  triangles %9d  cpu %6.2f ms  gpu %6.2f ms  (%.0f fps)" % [
			s[0], r.draws, r.objects, r.triangles, r.cpu_ms, r.gpu_ms, r.fps])
		if headless:
			continue
		check(r.draws <= s[4], "%s: %d draw calls (budget %d)" % [s[0], r.draws, s[4]])
		check(r.triangles <= s[5], "%s: %d triangles (budget %d)" % [s[0], r.triangles, s[5]])
	if headless:
		print("(headless: nothing is drawn, so the budgets weren't checked)")
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _sample() -> Dictionary:
	var draws := 0.0
	var objects := 0.0
	var tris := 0.0
	var cpu := 0.0
	var gpu := 0.0
	var vp := root.get_viewport_rid()
	var t0 := Time.get_ticks_usec()
	for k in SAMPLE:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		tris += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	return {
		"draws": int(draws / SAMPLE), "objects": int(objects / SAMPLE), "triangles": int(tris / SAMPLE),
		"cpu_ms": cpu / SAMPLE, "gpu_ms": gpu / SAMPLE, "fps": SAMPLE / maxf(secs, 0.0001),
	}


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0 if failures == 0 else 1)
