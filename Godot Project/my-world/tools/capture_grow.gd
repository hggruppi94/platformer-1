extends SceneTree

# Screenshots of Glenmoor's reward: Heather's grow (a Bloomstalk shooting up and flinging the hero high, on the glen's
# grass), her blossom orchard by Glenmoor's portal in the Void, and spring in Stars Hollow (tulips where the pumpkins
# were, the Tulip Field, pastel lights, a tulip-planting job). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_grow.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.grow_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.grow_capture_backup.cfg"

var out_dir := "user://grow_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var clock: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
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
	portals = root.get_node("Portals")
	clock = root.get_node("Clock")
	clock.set("pulls_home", false)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.cleared_worlds.append(w)
		portals.quakes.append(w)
	await _grow()
	await _orchard()
	await _spring_town()
	_finish()


func _grow() -> void:
	clock.set_time(3, 11 * 60.0, true)
	portals.enter("glenmoor")
	await _frames(30)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var dlg := root.get_node("Dialogue")
	if dlg.is_active():
		dlg.end()
	p.global_position = Vector3(6.0, 0.9, 14.0)
	await create_timer(1.0).timeout
	_cam_in(s)
	var g := p.get_node("Grow")
	g.try_grow()
	# Frame from the hero's spot each time: they're moving fast, so fixed angles miss them.
	await create_timer(0.08).timeout
	var base := Vector3(6.0, p.global_position.y - 0.8, 14.0)
	_look(base + Vector3(5.0, 2.5, 6.5), (base + p.global_position) / 2.0 + Vector3(0, 0.6, 0))
	await _shot("01_grow_a_bloomstalk_shoots_up")
	await create_timer(0.35).timeout
	_look(base + Vector3(10.0, 2.0, 13.0), (base + p.global_position) / 2.0 + Vector3(0, 1.0, 0))
	await _shot("02_and_flings_you_up_high")
	for k in 2:
		await create_timer(1.6).timeout
		p.global_position = Vector3(-1.0 + k * 3.5, 0.9, 9.0 - k * 2.0)
		p.velocity = Vector3.ZERO
		await create_timer(0.8).timeout
		g.cooldown = 0.0
		g.try_grow()
	await create_timer(2.5).timeout
	_look(Vector3(14.0, 5.0, 26.0), Vector3(2.0, 2.0, 12.0))
	await _shot("03_bloomstalks_on_the_glen")


func _orchard() -> void:
	clock.set_time(3, 11 * 60.0, true)
	game_go("res://scenes/town/town.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	var o := s.get_node("Portals/Blossom Orchard") as Node3D
	p.global_position = o.global_position + Vector3(10.0, 1.0, 10.0)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(o.global_position + Vector3(12.0, 5.0, 12.0), o.global_position + Vector3(0, 2.0, 0))
	await _shot("04_heathers_blossom_orchard")
	var portal := s.get_node("Portals/Portal glenmoor") as Node3D
	_look(portal.global_position + portal.global_basis.z * 14.0 + Vector3(0, 5.0, 0), (portal.global_position + o.global_position) / 2.0 + Vector3(0, 2.0, 0))
	await _shot("05_the_orchard_by_glenmoors_portal")


func _spring_town() -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of("spring", 3, 1), 12 * 60.0, true)
	clock.earth_minutes = 12 * 60.0
	game_go("res://scenes/earth/earth.tscn")
	await _frames(40)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	p.global_position = Vector3(0, 1, 18)
	await create_timer(1.0).timeout
	_cam_in(s)
	_look(Vector3(3, 11, 27), Vector3(0, 0.5, 2))
	await _shot("06_the_green_in_spring")
	var patch := s.find_child("Pumpkin Patch", true, false) as Node3D
	_look(patch.global_position + Vector3(4, 4.5, 11), patch.global_position + Vector3(0, 1.0, 0))
	await _shot("07_the_tulip_field")
	var seasons := s.get_node("Seasons")
	var bunch := s.get_node("Seasons/Spring Tulips").get_child(0) as Node3D
	_look(bunch.global_position + Vector3(1.6, 1.0, 1.6), bunch.global_position + Vector3(0, 0.3, 0))
	await _shot("08_tulips_where_the_pumpkins_were")
	var jobs := root.get_node("EarthJobs")
	for d in 60:
		jobs.roll(hash("grow_capture:%d" % d))
		var plant: Array = jobs.list.filter(func(r: Dictionary) -> bool: return r.kind == "rake")
		if not plant.is_empty():
			jobs.list.clear()
			jobs.list.append(plant[0])
			break
	jobs._place_props()
	await _frames(4)
	var holes := s.get_tree().get_nodes_in_group("earth_job_props")
	if holes.size() > 1:
		var first := holes[0] as Node3D
		holes.sort_custom(func(x: Node3D, y: Node3D) -> bool:
			return x.global_position.distance_to(first.global_position) < y.global_position.distance_to(first.global_position))
		holes[1].call("_on_body", p)
		var second := holes[1] as Node3D
		var mid := (first.global_position + second.global_position) / 2.0
		var house := s.get_node_or_null(str(jobs.list[0].house)) as Node3D
		var away := (mid - house.global_position) if house else Vector3(1, 0, 1)
		away.y = 0.0
		# Houses crowd the bulbs, so pick the first angle round them with a clear view.
		var space := s.get_world_3d().direct_space_state
		var spot := mid + Vector3(4.0, 3.0, 0)
		for i in 12:
			var dir := Vector3(cos(i * TAU / 12.0), 0, sin(i * TAU / 12.0))
			var at := mid + dir * 4.5 + Vector3(0, 2.6, 0)
			var q := PhysicsRayQueryParameters3D.create(mid + Vector3(0, 0.4, 0), at)
			q.exclude = [p.get_rid()]
			if space.intersect_ray(q).is_empty():
				spot = at
				break
		# The clear ray finds no walls, but a house can stand behind the bulbs, so look from
		# the far side, back towards it, from higher up.
		var back := mid * 2.0 - spot
		back.y = mid.y + 3.5
		_look(back, mid + Vector3(0, 0.2, 0))
		await _shot("09_planting_tulip_bulbs")


func game_go(path: String) -> void:
	root.get_node("Game").go(path, "", "")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


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
