extends SceneTree

# Screenshots of the centipede's gifts once Dark Hollow is mended: wall crawl (scripts/wall_crawl.gd) up a wall in the
# Void and along the ceiling of Behind the Walls in the castle school, and her holes round the Void
# (scripts/centipede_holes.gd): her head popping out of one, knocking, the gulp and popping out by another. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_wall_crawl.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.wall_crawl_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.wall_crawl_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"

var out_dir := "user://wall_crawl_shots"
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
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
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	root.get_node("Portals").cleared_worlds.append("dark_hollow")
	var only_wall := OS.get_cmdline_user_args().has("wall")
	await _town(only_wall)
	if not only_wall:
		await _school()
	_finish()


func _town(only_wall := false) -> void:
	change_scene_to_file(TOWN)
	await _frames(30)
	var s := current_scene as Node3D
	var p := _player()
	p.get_node("HUD").visible = false
	var crawl: Node = p.get("wall_crawl")
	# Up a wall: the first tall climbable wall found round the market
	var hit := {}
	for c in [Vector2(-12, -15), Vector2(80, 6), Vector2(-72, 49)]:      # the town square, the homes, the market
		hit = _find_wall(s, c)
		if not hit.is_empty():
			break
	if not hit.is_empty():
		var n: Vector3 = hit.normal
		n.y = 0.0
		n = n.normalized()
		var at: Vector3 = hit.position + n * 0.4
		at.y = (hit.position as Vector3).y + 1.6
		p.global_position = at
		crawl.start(n)
		await _frames(20)
		_cam_in(s)
		var side := n.cross(Vector3.UP)
		_look(at + n * 4.5 + side * 2.5 + Vector3(0, 0.8, 0), at + Vector3(0, 0.2, 0))
		await _frames(10)
		await _shot("01_wall_crawl_up_a_wall")
		crawl.stop()
		cam.queue_free()
		cam = null
		await _frames(20)
	else:
		print("NO WALL")
	if only_wall:
		return
	# A hole, and her head popping out
	var holes := s.get_node_or_null("Portals/Centipede Holes") as Node3D
	if holes == null:
		print("NO HOLES")
		return
	var h: Dictionary = holes.HOLES[0]
	var land: Array = holes.landing(h.id)
	p.global_position = land[0]
	p.visual.rotation.y = float(land[1]) + PI
	await _frames(60)
	var hole_at: Vector3 = (holes.get_node("Hole %s" % h.id) as Node3D).global_position
	_cam_in(s)
	var away := (Vector3(land[0].x, hole_at.y, land[0].z) - hole_at).normalized()
	_look(hole_at + away * 5.0 + away.cross(Vector3.UP) * 2.0 + Vector3(0, 2.2, 0), hole_at + Vector3(0, 0.6, 0))
	await _frames(10)
	await _shot("02_her_hole_by_the_market")
	# Knocking: the choices
	holes.knock(h.id)
	for i in 40:
		await _frames(2)
		if root.get_node("Dialogue")._choosing:
			break
		_press("interact")
	await _frames(20)
	await _shot("03_knock_where_to")
	root.get_node("Dialogue").end()
	await _frames(10)
	# The gulp and popping out by the Skate Park
	root.get_node("Portals").note_found("dark_hollow", "hole_skate_park")
	holes.set("_from", h.id)
	holes.travel("skate_park")
	await create_timer(0.7).timeout
	await _shot("04_she_comes_up_round_you")
	await create_timer(0.9).timeout
	await _shot("05_gulp")
	await create_timer(1.0).timeout
	await _shot("06_along_her_tunnels")
	await create_timer(1.25).timeout
	((p.get("spring_arm") as Node).get("camera") as Camera3D).make_current()
	cam.queue_free()
	cam = null
	await _frames(2)
	await create_timer(0.15).timeout
	await _shot("07_ptoo_by_the_skate_park")
	await create_timer(1.2).timeout
	await _shot("08_out_by_the_skate_park")


func _school() -> void:
	change_scene_to_file(SCHOOL)
	await _frames(30)
	var s := current_scene as Node3D
	var corner := s.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner") as Node3D
	var p := _player()
	p.get_node("HUD").visible = false
	var crawl: Node = p.get("wall_crawl")
	var at := corner.to_global(Vector3(-15.0, 1.0, -22.45))
	var space := s.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3(0, 8, 0))
	q.exclude = [p.get_rid()]
	var up := space.intersect_ray(q)
	if up.is_empty():
		print("NO CEILING")
		return
	p.global_position = (up.position as Vector3) - Vector3(0, 0.86, 0)
	crawl.start(Vector3.DOWN, true)
	p.visual.rotation.y = -PI / 2.0
	await _frames(40)
	_cam_in(s)
	_look(p.global_position + Vector3(3.2, -1.3, 0.9), p.global_position + Vector3(0, -0.2, 0))
	await _frames(10)
	await _shot("09_upside_down_behind_the_walls")


func _find_wall(s: Node3D, around: Vector2) -> Dictionary:
	var space := s.get_world_3d().direct_space_state
	var p := _player()
	var wc: GDScript = load("res://scripts/wall_crawl.gd")
	for r in [6.0, 9.0, 12.0, 15.0, 20.0]:
		for k in 16:
			var a := k * TAU / 16.0
			var from2: Vector2 = around + Vector2(cos(a), sin(a)) * r
			var g: Vector3 = root.get_node("Remnants").ground_at(from2)
			for j in 8:
				var b := j * TAU / 8.0
				var from := g + Vector3(0, 1.2, 0)
				var to := from + Vector3(cos(b), 0, sin(b)) * 5.0
				var q := PhysicsRayQueryParameters3D.create(from, to)
				q.exclude = [p.get_rid()]
				var hit := space.intersect_ray(q)
				if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.1 or not wc.climbable(hit.collider):
					continue
				var hp: Vector3 = hit.position
				var n: Vector3 = hit.normal
				var q2 := PhysicsRayQueryParameters3D.create(hp + n * 0.3 + Vector3(0, 2.6, 0), hp - n * 0.8 + Vector3(0, 2.6, 0))
				q2.exclude = [p.get_rid()]
				if not space.intersect_ray(q2).is_empty():
					return hit                          # still wall 3.5 m up: tall enough to show a climb
	return {}


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventAction.new()
	u.action = action
	Input.parse_input_event(u)


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
