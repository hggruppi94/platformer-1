extends SceneTree

# Screenshots of the spray paint (scripts/spray_can.gd, scripts/paint.gd): the cans out with the palette, a picture
# sprayed on a wall and one on the ground, the same from above, half of it washed off, and the paint still there
# after a trip home to Earth and back. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_spray.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.spray_capture_backup.cfg"

var out_dir := "user://spray_shots"
var _save := ""
var _backup := ""
var _had_save := false
var paint: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	var game := root.get_node("Game")
	paint = root.get_node("Paint")
	_save = game.save_path()
	_backup = _save.get_basename() + ".spray_capture_backup.json"
	_had_save = FileAccess.file_exists(_save)
	if _had_save and not FileAccess.file_exists(_backup):
		DirAccess.copy_absolute(_save, _backup)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	game.give_item("spray_can")
	game.hero["void_feature"] = "antennae"          # (no "you've changed" message on landing)
	root.get_node("Portals").quakes.append("shard_isle")   # (and no time quake in the middle of it)
	game.go("res://scenes/town/town.tscn", "", "")
	await _frames(30)
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	var can = p.get("spray")
	var space := p.get_world_3d().direct_space_state
	# A wall to paint: the side of the Potion Shop's dome by the Market Square (the nearest solid thing round her)
	var best := {}
	for spot in [Vector3(-84, 0, 40), Vector3(-70, 0, 30), Vector3(-95, 0, 30)]:
		var at := _ground(space, spot.x, spot.z) + Vector3(0, 1.4, 0)
		for k in 24:
			var dir := Vector3(sin(k * TAU / 24), 0, cos(k * TAU / 24))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + dir * 14.0))
			if hit.is_empty() or not paint.paintable(hit.collider, hit.position) or absf((hit.normal as Vector3).y) > 0.3:
				continue
			var d := at.distance_to(hit.position)
			if d > 6.0 and (best.is_empty() or d < best.d):
				best = {"d": d, "hit": hit}
		if not best.is_empty():
			break
	if best.is_empty():
		print("NO WALL")
		_finish()
		return
	var wall: Dictionary = best.hit
	var n: Vector3 = wall.normal
	n.y = 0
	n = n.normalized()
	var w_at: Vector3 = wall.position - Vector3.UP.cross(n).normalized() * 2.2   # left of its door and sign
	print("wall ", wall.collider.name, " at ", w_at)
	# Stand 5 m in front of it
	var stand := w_at + n * 5.0
	p.global_position = _ground(space, stand.x, stand.z) + Vector3(0, 0.1, 0)
	p.get("visual").rotation.y = atan2(-n.x, -n.z)
	p.spring_arm.rotation.y = atan2(n.x, n.z)
	p.spring_arm.rotation.x = -0.05
	await _physics(10)
	can.set_active(true)
	await _physics(20)
	# A picture on the wall: a rainbow, a heart and a sun (made of strokes, like spraying it)
	var right := Vector3.UP.cross(n).normalized()
	var on_wall := func(u: float, v: float) -> Dictionary:
		var at: Vector3 = w_at + right * u + Vector3(0, v, 0)
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(at + n * 2.5, at - n * 2.5))
	var bands := [0, 1, 2, 3, 5, 6]
	for b in bands.size():
		var r := 2.0 - b * 0.22
		var line := []
		for i in 40:
			var a := PI * i / 39.0
			line.append(Vector2(cos(a) * r, sin(a) * r - 0.2))
		_stroke(on_wall, line, bands[b], 0.24)
	var heart := []
	for i in 60:
		var t := TAU * i / 59.0
		heart.append(Vector2(16 * pow(sin(t), 3), 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)) * 0.022
			+ Vector2(-2.9, 0.1))
	_stroke(on_wall, heart, 7, 0.16)
	_fill(on_wall, Vector2(-2.9, 0.15), 0.25, 7, 0.2)
	_ring(on_wall, Vector2(2.9, 1.0), 0.35, 2, 0.2)
	_fill(on_wall, Vector2(2.9, 1.0), 0.3, 2, 0.2)
	for k in 8:
		var a := TAU * k / 8.0
		_stroke(on_wall, [Vector2(2.9, 1.0) + Vector2(cos(a), sin(a)) * 0.5,
			Vector2(2.9, 1.0) + Vector2(cos(a), sin(a)) * 0.8], 1, 0.12)
	await _physics(5)
	# Spray a bit for real so the can puffs on the shot
	p.spring_arm.rotation.x = -0.12
	Input.action_press("shoot")
	await _physics(12)
	await _shot("01_cans_out_wall_picture")
	Input.action_release("shoot")
	# On the ground behind her: a big smiley and a hopscotch
	var fwd := n
	var g_at := p.global_position + fwd * 4.0
	var on_ground := func(u: float, v: float) -> Dictionary:
		var at: Vector3 = g_at + right * u + fwd * v
		return space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at - Vector3(0, 3, 0)))
	_ring(on_ground, Vector2.ZERO, 1.6, 2, 0.26)
	_fill(on_ground, Vector2(-0.55, 0.55), 0.18, 9, 0.2)
	_fill(on_ground, Vector2(0.55, 0.55), 0.18, 9, 0.2)
	var smile := []
	for i in 30:
		var a := PI + PI * i / 29.0
		smile.append(Vector2(cos(a), sin(a) * 0.9) * 0.9 + Vector2(0, -0.1))
	_stroke(on_ground, smile, 0, 0.2)
	for k in 5:
		var c := Vector2(0, 2.6 + k * 0.9)
		var sq := [c + Vector2(-0.4, -0.4), c + Vector2(0.4, -0.4), c + Vector2(0.4, 0.4), c + Vector2(-0.4, 0.4),
			c + Vector2(-0.4, -0.4)]
		_stroke(on_ground, sq, [4, 3, 6, 1, 8][k], 0.14)
	p.spring_arm.rotation.y = atan2(-n.x, -n.z)
	p.get("visual").rotation.y = atan2(n.x, n.z)
	p.spring_arm.rotation.x = -0.6
	await _physics(20)
	await _shot("02_on_the_ground")
	# From above, with her own camera put aside
	can.set_active(false)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = p.global_position + n * 2.0 + Vector3(0, 9, 0)
	cam.look_at(p.global_position + fwd * 3.0 - n * 0.5, Vector3.UP)
	cam.make_current()
	await _shot("03_from_above")
	cam.global_position = p.global_position + fwd * 1.5 + Vector3(0, 3.0, 0)
	cam.look_at(w_at + Vector3(0, 0.6, 0), Vector3.UP)
	await _shot("04_the_wall")
	print("dabs ", paint.count())
	# Half of the rainbow washed off
	for i in 30:
		var hit: Dictionary = on_wall.call(0.2 + i * 0.07, 1.2 - i * 0.02)
		if not hit.is_empty():
			paint.wash(hit.position, 0.55)
	await _shot("05_washed_with_water")
	# Still there after a trip home to Earth and back
	var eye := p.global_position + fwd * 1.5 + Vector3(0, 3.0, 0)
	game.go("res://scenes/earth/earth.tscn", "", "")
	await _frames(20)
	game.go("res://scenes/town/town.tscn", "", "")
	await _frames(30)
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = eye
	cam.look_at(w_at + Vector3(0, 0.6, 0), Vector3.UP)
	cam.make_current()
	await _physics(10)
	await _shot("06_still_there_after_a_trip_home")
	print("dabs after coming back ", paint.count())
	_finish()


func _flat(space: PhysicsDirectSpaceState3D, hit: Dictionary) -> bool:
	var n: Vector3 = hit.normal
	n.y = 0
	n = n.normalized()
	var right := Vector3.UP.cross(n).normalized()
	for u in [-2.0, 0.0, 2.0]:
		for v in [-0.6, 0.4, 1.2]:
			var at: Vector3 = hit.position + right * u + Vector3(0, v, 0)
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + n * 0.5, at - n * 0.5))
			if h.is_empty() or h.collider != hit.collider or not paint.paintable(h.collider, h.position) or (h.normal as Vector3).dot(n) < 0.5:
				return false
	return true


func _stroke(on: Callable, pts: Array, colour: int, size: float) -> void:
	for i in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / (size * 0.3)))
		for s in steps:
			var q := a.lerp(b, float(s) / steps)
			var hit: Dictionary = on.call(q.x, q.y)
			if not hit.is_empty():
				paint.dab(hit.position, hit.normal, colour, size * randf_range(0.9, 1.1), randf() * TAU)


func _ring(on: Callable, c: Vector2, r: float, colour: int, size: float) -> void:
	var pts := []
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	_stroke(on, pts, colour, size)


func _fill(on: Callable, c: Vector2, r: float, colour: int, size: float) -> void:
	var k := r
	while k > 0.02:
		_ring(on, c, k, colour, size)
		k -= size * 0.4
	_stroke(on, [c, c + Vector2(0.01, 0)], colour, size)


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Vector3:
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -40, z)))
	return hit.position if not hit.is_empty() else Vector3(x, 0, z)


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("shoot")
	if FileAccess.file_exists(_backup):
		DirAccess.rename_absolute(_backup, _save)
	elif not _had_save and FileAccess.file_exists(_save):
		DirAccess.remove_absolute(_save)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	quit()
