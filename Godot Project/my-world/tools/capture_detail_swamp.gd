extends SceneTree

# Pictures for the swamps' baked props (24 Nov 2026, tools/build_prop_swamp.py, scripts/detail_props.gd
# dress_swamp()): the Mothmire past Lanternmoor's moor and the Poison Mire past Dusk's Embrace. With --old-props it
# shoots the same spots with everything the pipeline adds turned off, so the two sets make a before and after. With
# --birdseye it shoots the whole world from straight above and from high up at a slant instead (no fog, a little
# brighter, so a night world still reads).
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_detail_swamp.gd -- <folder> lanternmoor|dusk [--old-props] [--birdseye]
#
# Opens a window (not --headless). Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_swamp_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_swamp_capture_backup.cfg"
const WORLDS := {"lanternmoor": "res://scenes/portal_worlds/lanternmoor.tscn",
	"dusk": "res://scenes/scary_world/scary_world.tscn"}

var out_dir := "user://detail_swamp_shots"
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
	var which := "dusk" if "dusk" in args else "lanternmoor"
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Settings").minimap = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var detail := root.get_node("WorldDetail")
	if "--old-props" in args:
		detail.detail_props = false
		detail.batching = false
		detail.lods = false
		detail.plant_shadows = true
	change_scene_to_file(WORLDS[which])
	for i in 16:
		await process_frame
	await create_timer(3.5).timeout
	var lw := current_scene.get_node_or_null("Mesh LODs")
	while lw and lw.busy():
		await process_frame
	var s := current_scene
	var sw := s.get_node("Swamp") as Node3D
	var player := s.find_child("Player", true, false) as Node3D
	if player:
		player.visible = false
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 3000
	s.add_child(cam)
	cam.make_current()
	if "--birdseye" in args:
		await _birdseye(s, sw, which)
		_finish()
		return
	var c: Vector3 = sw.get("centre")
	var views := []
	views.append(["01_swamp_over", c + Vector3(0, 30, 34), c])
	# A boardwalk: from beside its first plank, looking along it
	var pl: Node3D = null
	for mi in sw.get_node("Boardwalks").get_children():
		if mi is MeshInstance3D and str(mi.name).begins_with("Plank"):
			pl = mi
			break
	if pl:
		var f := pl.global_transform.basis.z.normalized()
		var sd := pl.global_transform.basis.x.normalized()
		views.append(["02_boardwalk", pl.global_position - f * 3.0 + sd * 1.6 + Vector3(0, 1.6, 0), pl.global_position + f * 5.0])
	var t := sw.get_node("Swamp Trees").get_child(2) as Node3D
	views.append(["03_tree", t.global_position + (c - t.global_position).normalized() * 6.0 + Vector3(0, 2.5, 0), t.global_position + Vector3(0, 3.5, 0)])
	var ch := sw.get_node("Swamp Chest/Chest") as Node3D
	views.append(["04_chest", ch.global_position + ch.global_transform.basis.z * 2.4 + Vector3(0.8, 1.3, 0), ch.global_position + Vector3(0, 0.4, 0)])
	var lo := sw.get_node("Lookout") as Node3D
	views.append(["05_lookout", lo.global_position + (c - lo.global_position).normalized() * 14.0 + Vector3(0, 6.0, 0), lo.global_position + Vector3(0, 7.0, 0)])
	if sw.has_node("Old Mire Hut/Hut"):
		var h := sw.get_node("Old Mire Hut/Hut") as Node3D
		views.append(["06_hut", h.global_position - h.global_transform.basis.z * 6.0 + Vector3(1.5, 2.5, 0), h.global_position + Vector3(0, 2.0, 0)])
	if sw.has_node("Stepping Stones") and sw.get_node("Stepping Stones").get_child_count() > 2:
		var st := sw.get_node("Stepping Stones").get_child(1) as Node3D
		views.append(["06_stones", st.global_position + Vector3(2.5, 2.2, 2.5), st.global_position])
		for b in sw.get_node("Stepping Stones").get_children():
			if str(b.name).begins_with("Sinker"):
				var sk := b as Node3D
				views.append(["06b_sinker", sk.global_position + Vector3(1.3, 1.9, 1.3), sk.global_position + Vector3(0, 0.3, 0)])
				break
	if sw.has_node("Log Bridges") and sw.get_node("Log Bridges").get_child_count() > 0:
		var lg := sw.get_node("Log Bridges").get_child(0) as Node3D
		views.append(["07_log", lg.global_position + lg.global_transform.basis.x * 4.0 + Vector3(0, 2.0, 0), lg.global_position])
	if sw.has_node("Islands"):
		var isl := sw.get_node("Islands").get_child(0) as Node3D
		views.append(["08_island", isl.global_position + (c - isl.global_position).normalized() * 9.0 + Vector3(0, 4.0, 0), isl.global_position])
	s.set_process(false)
	sw.set_process(false)
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await _shot(v[0])
	_finish()


func _birdseye(s: Node, sw: Node3D, which: String) -> void:
	# The whole world: everything you can reach (the map's own bounds) and the swamp's circle
	var b: Dictionary = root.get_node("TownMap").snap_bounds(s)
	var mid: Vector2 = b.center
	var size := float(b.size)
	var c: Vector3 = sw.get("centre")
	var r := float(sw.get("radius"))
	var lo := Vector2(mid.x - size / 2.0, mid.y - size / 2.0).min(Vector2(c.x - r, c.z - r))
	var hi := Vector2(mid.x + size / 2.0, mid.y + size / 2.0).max(Vector2(c.x + r, c.z + r))
	mid = (lo + hi) / 2.0
	size = maxf(hi.x - lo.x, hi.y - lo.y) * 1.05
	var we := s.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we and we.environment:
		var env := we.environment.duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.ambient_light_energy = maxf(env.ambient_light_energy, 1.0) * 1.6
		env.tonemap_exposure = 1.25
		we.environment = env
	DisplayServer.window_set_size(Vector2i(1400, 1400))
	await process_frame
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.near = 0.5
	cam.far = 1200.0
	cam.global_position = Vector3(mid.x, 400.0, mid.y)
	cam.rotation = Vector3(-PI / 2.0, 0, 0)
	await _shot("%s_birdseye_top" % which)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 50
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	await process_frame
	cam.global_position = Vector3(mid.x, size * 0.75, mid.y + size * 0.75)
	cam.look_at(Vector3(mid.x, 0, mid.y))
	await _shot("%s_birdseye_slant" % which)


func _shot(file: String) -> void:
	for i in 12:
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
