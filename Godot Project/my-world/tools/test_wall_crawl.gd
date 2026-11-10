extends SceneTree

# Checks the centipede's two gifts once Dark Hollow is mended. Wall crawl (scripts/wall_crawl.gd): locked before; walk
# into a wall and keep going and you start up it (no button); push towards it to climb and you pull yourself over the
# top; climb up into a ceiling and you carry on along it upside down, and drop where it ends; Jump hops off and Roll
# lets go; invisible edge-of-the-world walls ("Fence") can't be climbed. Her holes (scripts/centipede_holes.gd): only
# once she's your friend, six in the Void, each on flat dry ground clear of the races, the townsfolk's paths, trees and
# portals; walking up to one finds it; knocking offers the holes you've found, her corner and Dark Hollow; travelling
# gulps you up and pops you out by the other hole; her corner in the school offers the holes too and takes you to one;
# and from a hole you can go to her corner. Her thank-you teaches both.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_wall_crawl.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.wall_crawl_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.wall_crawl_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const ID := "dark_hollow"
const Y0 := 300.0                                  # the climbing frame floats high over the Void, away from everything

var failures := 0
var game: Node
var portals: Node
var dialogue: Node
var holes_script: GDScript


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	dialogue = root.get_node("Dialogue")
	holes_script = load("res://scripts/centipede_holes.gd")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}

	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	check(current_scene.get_node_or_null("Portals/Centipede Holes") == null, "no centipede holes in the Void before Dark Hollow's mended")
	await _crawl()
	await _holes()
	_finish()


# Wall crawl -----------------------------------------------------------------------------------------------------------
func _box(parent: Node3D, name: String, size: Vector3, at: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	b.global_position = at
	return b


func _crawl() -> void:
	var s := current_scene as Node3D
	var frame := Node3D.new()
	frame.name = "Climbing Frame"
	s.add_child(frame)
	_box(frame, "Floor", Vector3(40, 1, 40), Vector3(0, Y0 - 0.5, 0))
	_box(frame, "Wall A", Vector3(6, 5, 4), Vector3(-8, Y0 + 2.5, -6.5))                # 5 m tall, nothing on top
	_box(frame, "Wall B", Vector3(6, 6, 1), Vector3(8, Y0 + 3.0, -5))                 # 6 m, with a roof out over you
	_box(frame, "Roof B", Vector3(6, 0.5, 8.5), Vector3(8, Y0 + 6.25, -1.25))           # its underside at 6 m, to z = 3
	_box(frame, "Fence", Vector3(6, 6, 1), Vector3(0, Y0 + 3.0, 8))                    # an invisible edge-of-the-world wall
	var p := _player()
	var crawl: Node = p.get("wall_crawl")
	check(crawl != null, "the hero has a WallCrawl node")
	var arm := p.get("spring_arm") as Node3D
	arm.rotation = Vector3.ZERO                       # the camera looks north (-Z), so "forward" walks north
	# Locked
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	Input.action_press("move_forward")
	await create_timer(1.2).timeout
	Input.action_release("move_forward")
	check(not crawl.active and p.global_position.y < Y0 + 1.5, "before Dark Hollow's mended, walking into a wall just stops you (y %.1f)" % (p.global_position.y - Y0))
	portals.cleared_worlds.append(ID)
	check(crawl.unlocked(), "once it's mended, wall crawl's unlocked")
	# A tap into a wall doesn't grab
	await _stand(p, Vector3(-8, Y0 + 0.85, -3.8))
	Input.action_press("move_forward")
	await _physics(6)
	Input.action_release("move_forward")
	await _physics(4)
	check(not crawl.active, "just bumping into a wall doesn't start a climb")
	# Up and over
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	var before: int = crawl.crawls
	Input.action_press("move_forward")
	var started := false
	for i in 60:
		await physics_frame
		if crawl.active:
			started = true
			break
	check(started and crawl.crawls == before + 1, "keep walking into the wall and you start up it, no button")
	check(started and Vector3(crawl.normal).dot(Vector3.BACK) > 0.95, "...holding on to its face")
	var top := -INF
	var mantled := false
	for i in 240:
		await physics_frame
		top = maxf(top, p.global_position.y)
		if started and not crawl.active:
			mantled = true
			break
	await create_timer(0.8).timeout
	Input.action_release("move_forward")
	await _physics(10)
	check(mantled, "climbing up, you reach the top")
	check(p.is_on_floor() and p.global_position.y > Y0 + 5.5 and p.global_position.z < -4.5, "...and pull yourself over onto it (at %s)" % (p.global_position - Vector3(0, Y0, 0)))
	check(float(crawl.climbed) > 3.5, "...climbing about 4 m (%.1f m)" % crawl.climbed)
	# Down again: pull away from the wall and you climb down to the floor
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		if crawl.active:
			break
	await create_timer(0.5).timeout
	Input.action_release("move_forward")
	var high := p.global_position.y
	Input.action_press("move_back")
	await create_timer(1.6).timeout
	Input.action_release("move_back")
	await _physics(4)
	check(high > Y0 + 1.5 and not crawl.active and p.global_position.y < Y0 + 1.2, "pull away from the wall and you climb back down to the floor (from %.1f)" % (high - Y0))
	# Sideways
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		if crawl.active:
			break
	Input.action_release("move_forward")
	var x0 := p.global_position.x
	Input.action_press("move_right")
	await create_timer(0.5).timeout
	Input.action_release("move_right")
	check(crawl.active and p.global_position.x > x0 + 1.0, "push sideways and you scuttle along the wall (%.1f m)" % (p.global_position.x - x0))
	# Jump hops off
	_press("jump")
	await _physics(3)
	check(not crawl.active and p.velocity.z > 2.0, "Jump hops you back off the wall")
	await _physics(60)
	# Roll lets go
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
		if crawl.active:
			break
	Input.action_release("move_forward")
	await create_timer(0.3).timeout
	_press("dash")
	await _physics(3)
	check(not crawl.active, "Roll lets go")
	await _physics(40)
	# Up into a ceiling and along it upside down
	await _stand(p, Vector3(8, Y0 + 0.85, -2.5))
	Input.action_press("move_forward")
	var ceiling := false
	for i in 300:
		await physics_frame
		if crawl.active and int(crawl.mode) == 1:
			ceiling = true
			break
	Input.action_release("move_forward")
	check(ceiling, "climb up into a ceiling and you carry on along it")
	await create_timer(0.5).timeout
	var tumble := p.get("tumble") as Node3D
	check(crawl.active and absf(wrapf(tumble.rotation.z, -PI, PI)) > 2.8, "...upside down")
	var under := p.global_position.y
	check(under > Y0 + 4.8 and under < Y0 + 5.4, "...hanging just under it (%.2f m up)" % (under - Y0))
	Input.action_press("move_back")
	var dropped_at := INF
	for i in 300:
		await physics_frame
		if not crawl.active:
			dropped_at = p.global_position.z
			break
	Input.action_release("move_back")
	check(dropped_at > 2.0 and dropped_at < 4.5, "walk along it and you drop where it ends (z %.1f)" % dropped_at)
	await create_timer(1.2).timeout
	check(p.is_on_floor() and absf(tumble.rotation.z) < 0.1, "...landing the right way up")
	# Invisible walls
	await _stand(p, Vector3(0, Y0 + 0.85, 5.0))
	Input.action_press("move_back")
	await create_timer(1.2).timeout
	Input.action_release("move_back")
	check(not crawl.active and p.global_position.y < Y0 + 1.5, "the invisible walls round a world can't be climbed")
	# Not while talking
	await _stand(p, Vector3(-8, Y0 + 0.85, -2.5))
	game.hold_controls(&"test", true)
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	Input.action_release("move_forward")
	game.hold_controls(&"test", false)
	check(not crawl.active, "not while something's holding the controls")
	frame.queue_free()
	await _physics(2)


func _stand(p: CharacterBody3D, at: Vector3) -> void:
	if p.wall_crawl.active:
		p.wall_crawl.stop()
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.wall_crawl.set("_regrab", 0.0)
	await _physics(4)                                # (is_on_floor() still says where she was until she's moved)
	for i in 60:
		await physics_frame
		if p.is_on_floor():
			break
	await _physics(3)


# Her holes ------------------------------------------------------------------------------------------------------------
func _holes() -> void:
	game.hold_saves = false
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var holes := current_scene.get_node_or_null("Portals/Centipede Holes") as Node3D
	check(holes != null, "once Dark Hollow's mended, the centipede's holes are in the Void")
	if holes == null:
		return
	var list: Array = holes_script.HOLES
	check(list.size() == 6, "six of them")
	_placement(holes, list)
	check(holes_script.found_count() == 0, "none found to begin with")
	var p := _player()
	# Find the market's
	var m: Dictionary = holes_script.hole("market")
	p.global_position = Vector3(m.at.x + 2.5, m.y + 1.0, m.at.y)
	p.velocity = Vector3.ZERO
	await _physics(10)
	await _frames(4)
	check(holes_script.found("market"), "walk up to one and you've found it")
	var head := holes.heads["market"] as Node3D
	await create_timer(0.8).timeout
	check(head.visible and head.position.y > 0.2, "...and her head pops up out of it to look at you")
	check(holes.spots["market"].what() == "knock on the centipede's hole", "...and you can knock on it")
	var lines: Array = holes.lines("market")
	var texts := _choice_texts(lines)
	check("Dark Hollow, please!" in texts and "Your corner in the castle school." in texts and "Not now, thanks." in texts, "knocking offers Dark Hollow, her corner and not now (%s)" % [texts])
	check(not texts.any(func(t: String) -> bool: return t.contains("Skate Park")), "...but not holes you haven't found")
	# Find the Skate Park's too
	var k: Dictionary = holes_script.hole("skate_park")
	p.global_position = Vector3(k.at.x + 2.5, k.y + 1.0, k.at.y)
	await _physics(10)
	check(holes_script.found("skate_park"), "find another")
	p.global_position = Vector3(m.at.x + 1.5, m.y + 1.0, m.at.y)
	p.velocity = Vector3.ZERO
	await _physics(10)
	texts = _choice_texts(holes.lines("market"))
	check("Pop me out by the Skate Park." in texts, "...and now the market's hole can take you there")
	# Travel
	await _talk(func() -> void: holes.knock("market"), "Skate Park")
	var last: Dictionary = dialogue.choice_log.back() if dialogue.choice_log.size() > 0 else {}
	check(str(last.get("what", "")) == "centipede_travel" and str(last.get("answer", "")) == "skate_park", "your pick is recorded")
	await _frames(2)
	check(holes.gulping and p.input_locked, "she comes up out of the hole and gulps you up")
	await create_timer(1.6).timeout
	check(root.get_node_or_null("Gulp") != null, "GULP! The screen closes like a mouth")
	await create_timer(2.0).timeout
	var land: Array = holes_script.landing("skate_park")
	var at: Vector3 = land[0]
	var d := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
	check(current_scene.scene_file_path == TOWN and d < 1.0, "...and PTOO! out you pop by the Skate Park's hole (%.1f m off)" % d)
	check(not p.input_locked and not holes.gulping, "...free to walk again")
	await create_timer(1.2).timeout
	check(root.get_node_or_null("Gulp") == null, "...and the mouth's opened again on the world")
	await _physics(20)
	check(p.is_on_floor() and absf(p.global_position.y - (Remnants_ground(k) + 0.8)) < 0.6, "...standing on the ground")
	# From a hole to her corner in the school
	await _talk(func() -> void: holes.knock("skate_park"), "corner")
	await _wait_for_scene(SCHOOL)
	await _physics(10)
	p = _player()
	var corner := current_scene.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner") as Node3D
	check(current_scene.scene_file_path == SCHOOL and corner != null and p.global_position.distance_to(corner.to_global(corner.CORNER)) < 6.0, "a hole can take you to her corner in the castle school")
	await _physics(10)
	await _frames(6)
	# Her corner offers the holes
	texts = _choice_texts(corner.lines())
	check("Dark Hollow, please!" in texts and "Pop me out by the Market." in texts and "Pop me out by the Skate Park." in texts, "her corner offers Dark Hollow and the holes you've found (%s)" % [texts])
	await _talk(func() -> void: corner.talk(), "Market")
	await _wait_for_scene(TOWN)
	await _physics(20)
	p = _player()
	land = holes_script.landing("market")
	at = land[0]
	d = Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
	check(current_scene.scene_file_path == TOWN and d < 1.5, "...and takes you to one (%.1f m off the market's hole)" % d)
	await create_timer(1.0).timeout
	check(root.get_node_or_null("Gulp") == null and not p.input_locked, "...with the gulp gone and you free to walk")
	# Her thank-you teaches both
	var dh: GDScript = load("res://scripts/dark_hollow.gd")
	var thanks: String = " ".join(dh.new().thank_lines())
	check(thanks.contains("climb") and thanks.contains("ceiling") and thanks.contains("knock"), "her thank-you teaches wall crawl and her holes")


func Remnants_ground(h: Dictionary) -> float:
	return (root.get_node("Remnants").ground_at(h.at) as Vector3).y


func _placement(holes: Node3D, list: Array) -> void:
	var rem := root.get_node("Remnants")
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var tracks: Dictionary = root.get_node("Races").TRACKS
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var trees := current_scene.find_child("Trees", true, false) as Node3D
	for h in list:
		var at: Vector2 = h.at
		var g: Vector3 = rem.ground_at(at)
		var worst := 0.0
		for j in 8:
			var b := j * TAU / 8.0
			worst = maxf(worst, absf(rem.ground_at(at + Vector2(cos(b), sin(b)) * 2.0).y - g.y))
		var wet := false
		for w in get_nodes_in_group("water"):
			if w.has_method("covers") and w.covers(at.x, at.y):
				wet = true
		var q := PhysicsShapeQueryParameters3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.8
		q.shape = sp
		q.transform = Transform3D(Basis(), g + Vector3(0, 2.4, 0))
		var hits := space.intersect_shape(q, 8).filter(func(x: Dictionary) -> bool:
			var c: Node = x.collider
			return not c.is_in_group("player") and not (c is Area3D) and not holes.is_ancestor_of(c))
		var race := INF
		for tid in tracks:
			var t: Dictionary = tracks[tid]
			if t.get("sky", false) or str(t.get("scene", TOWN)) != TOWN:
				continue
			var line: Array = t.points
			for i in line.size():
				var a: Vector2 = line[i]
				var b2: Vector2 = line[(i + 1) % line.size()]
				var kk := clampf((at - a).dot(b2 - a) / (b2 - a).length_squared(), 0.0, 1.0)
				race = minf(race, at.distance_to(a.lerp(b2, kk)))
		var path := INF
		for l in places.links:
			var pa: Array = places.points[l[0]]
			var pb: Array = places.points[l[1]]
			var a := Vector2(pa[0], pa[pa.size() - 1])
			var b3 := Vector2(pb[0], pb[pb.size() - 1])
			var kk := 0.0 if a == b3 else clampf((at - a).dot(b3 - a) / (b3 - a).length_squared(), 0.0, 1.0)
			path = minf(path, at.distance_to(a.lerp(b3, kk)))
		var tree := INF
		if trees:
			for tp in trees.get("positions"):
				var tg: Vector3 = trees.global_transform * tp
				tree = minf(tree, at.distance_to(Vector2(tg.x, tg.z)))
		var port := INF
		for w in portals.WORLDS:
			port = minf(port, at.distance_to(w.at))
		var ok := worst < 0.3 and not wet and hits.is_empty() and race > 5.0 and path > 3.5 and tree > 3.0 and port > 8.0 \
			and absf(g.y - float(h.y)) < 0.3
		check(ok, "the hole by %s is on flat dry ground, clear of things, races (%.0f m), paths (%.0f m), trees (%.0f m) and portals (%.0f m)" % [h.name, race, path, tree, port])


func _choice_texts(lines: Array) -> Array:
	for l in lines:
		if l is Dictionary and l.has("choice"):
			return (l.choice as Array).map(func(c: Dictionary) -> String: return str(c.text))
	return []


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _talk(start: Callable, pick: String) -> void:
	start.call()
	await _frames(2)
	var guard := 400
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var chosen: Control = buttons[0]
			for b in buttons:
				if str(b.text).to_lower().contains(pick.to_lower()):
					chosen = b
			chosen.grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")
			await _frames(1)
			_press("interact")
		await _frames(2)
	await create_timer(0.25).timeout


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _wait_for_scene(path: String) -> void:
	for i in 900:
		if current_scene and current_scene.scene_file_path == path and _player() != null:
			await _frames(4)
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "dash"]:
		Input.action_release(a)
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
