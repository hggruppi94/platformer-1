extends SceneTree

# Checks the Hot Springs' caves go somewhere (scripts/spring_grottos.gd) and the Museum's front door is clear
# (scripts/big_falls.gd _arch): each of the three caves has a tunnel and a grotto with a floor, a pool, its glow and a
# light, nothing solid in its mouth, and you really walk from the pool outside, in through the mouth, to the grotto's
# middle and back out; the plateau's first waterfall leaves out the arch wall that stood on the Museum's doorstep, and
# you really walk from the path up to the Museum's door and in.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_spring_grottos.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.spring_grottos_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.spring_grottos_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const GROTTOS := preload("res://scripts/spring_grottos.gd")

var failures := 0
var game: Node
var p: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Hidden").guardians = false
	change_scene_to_file(TOWN)
	await _frames(20)
	await _physics(30)
	var s := current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	var hs := s.get_node("Hot Springs") as Node3D

	# --- The caves ---
	var grottos := hs.find_children("Spring Grotto *", "Node3D", false, false)
	check(grottos.size() == 3, "three grottos dug behind the Hot Springs' mouths (%d)" % grottos.size())
	var space := s.get_world_3d().direct_space_state
	for g: Node3D in grottos:
		var frame: Transform3D = g.get_meta("frame")
		var out := frame.basis.z.normalized()
		var mid := GROTTOS.middle(g)
		check(g.has_node("Grotto Rock") and g.has_node("Grotto Pool") and g.has_node("Grotto Light"),
			"%s has rock, a pool and a light" % g.name)
		check(g.find_children("Grotto Crystals *", "", false, false).size() == 3, "%s has warm crystals" % g.name)
		var glow_in := false
		for c in hs.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.mesh is SphereMesh and mi.material_override and mi.material_override.resource_name == "Cave Glow" \
					and mi.position.distance_to(mid) < 6.0:
				glow_in = true
		check(glow_in, "%s's glow moved into the grotto" % g.name)
		# a floor all the way in, under the mouth's middle
		var floor_ok := true
		for k in 9:
			var at: Vector3 = (frame.origin + out * 1.0).lerp(mid, k / 8.0)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.6, 0), at - Vector3(0, 3, 0)))
			if hit.is_empty() or absf(hit.position.y - mid.y) > 0.75:
				floor_ok = false
				print("    no floor at ", at.snapped(Vector3.ONE * 0.1), " ", hit.get("position", "nothing"))
		check(floor_ok, "%s has a floor from the mouth to its middle" % g.name)
		# really walk in from the pool outside, and back out
		var pool := frame.origin + out * 4.0
		_put(pool + Vector3(0, 0.6, 0))
		await _physics(10)
		await _walk(frame.origin + out * 0.5, 6.0)
		await _walk(mid, 10.0)
		check(_flat(p.global_position, mid) < 1.2, "%s: you walk in through the mouth to the grotto's middle (%.1f m off)" % [
			g.name, _flat(p.global_position, mid)])
		check(absf(p.global_position.y - mid.y) < 1.8, "...standing on its floor")
		await _walk(pool, 10.0)
		check(_flat(p.global_position, pool) < 1.2, "%s: ...and back out to the pool (stopped at %s, pool %s)" % [g.name,
			p.global_position.snapped(Vector3.ONE * 0.1), pool.snapped(Vector3.ONE * 0.1)])
	# Digging never hides what stands beside the mouths (the baked mouths and rims, the pools outside)
	var hidden := []
	for c in hs.get_children():
		if (String(c.name).begins_with("Detailed Spring") or (c is MeshInstance3D and (c as MeshInstance3D).layers != 0)) \
				and not (c as Node3D).visible:
			hidden.append(c.name)
	check(hidden.is_empty(), "the mouths, rims, pools and glows all still show %s" % [hidden])
	check(int(hs.get_meta("grotto_shapes", 0)) == 6 and int(hs.get_meta("grotto_areas", 0)) == 3,
		"the grottos add three rock shapes and three warm pools (%d shapes, %d areas)" % [
		int(hs.get_meta("grotto_shapes", 0)), int(hs.get_meta("grotto_areas", 0))])

	# --- The Museum's door ---
	var falls := s.get_node_or_null("Big Falls plateau_1")
	check(falls != null and float(falls.get_meta("open_side", 0.0)) != 0.0,
		"the plateau's first fall leaves out the arch wall by the Museum's door")
	var door := s.get_node("Museum/Door") as Area3D
	var walls := 0
	for n in falls.find_children("Arch Wall", "MeshInstance3D", true, false) if falls else []:
		if _flat((n as Node3D).global_position, door.global_position) < 6.0:
			walls += 1
	check(walls == 0, "no arch wall stands by the Museum's door")
	# It's bigger and turned to look out over the lake shore, joined to the falls by a stream (scripts/falls_museum.gd)
	var mus := s.get_node("Museum") as Node3D
	check(absf(mus.global_transform.basis.get_scale().x - 1.2) < 0.01, "the Museum is 1.2 times bigger")
	check(falls != null and _flat((falls.get_meta("info") as Dictionary).edge, Vector3(-44.88, 0, -36.99)) < 0.5,
		"the fall stays where it was (it didn't slide away from the bigger Museum)")
	var stream := s.get_node_or_null("Falls Stream")
	check(stream != null and stream.find_child("Water Gate", true, false) != null
		and stream.find_children("*Stream Water*", "", true, false).size() >= 3,
		"a stream runs from the fall's pool to a water gate in the Museum's side")
	var out := mus.get_node("FromMuseum") as Node3D
	var face := out.global_position - door.global_position
	face.y = 0
	face = face.normalized()
	check(face.dot(Vector3(1, 0, 1).normalized()) > 0.8, "the Museum's door looks out over the lake shore")
	check(_flat(out.global_position, door.global_position) < 6.0 and out.global_position.y < 2.5,
		"the way out is on the ground in front of the door")
	var front := door.global_position + (out.global_position - door.global_position).normalized() * 7.0
	front.y = out.global_position.y
	_put(front + Vector3(0, 0.6, 0))
	await _physics(10)
	var went := [false]
	door.body_entered.connect(func(b: Node3D) -> void:
		if b == p:
			went[0] = true, CONNECT_ONE_SHOT)
	var dest := str(door.get("destination"))
	door.set("destination", "")                 # don't really go in: just see that she gets to the door
	await _walk(door.global_position, 8.0)
	door.set("destination", dest)
	check(went[0], "you walk from the path up to the Museum's door and in (%.1f m off)" % _flat(p.global_position,
		door.global_position))
	_finish()


func _put(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _walk(to: Vector3, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame
		game.hp = 10
		var want := to - p.global_position
		want.y = 0
		if want.length() < 0.6:
			break
		_steer(want.normalized())
	_release()
	await _physics(10)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _steer(want: Vector3) -> void:
	var b: Basis = p.get_node("SpringArm3D").global_transform.basis
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
	var ix := rgt.dot(want)
	var iy := -fwd.dot(want)
	_release()
	if ix > 0:
		Input.action_press("move_right", ix)
	else:
		Input.action_press("move_left", -ix)
	if iy > 0:
		Input.action_press("move_back", iy)
	else:
		Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	_release()
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
