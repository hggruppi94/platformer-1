extends SceneTree

# Checks the real Secret Garden (scripts/secret_garden.gd, scenes/secret_garden/secret_garden.tscn) and its hidden way
# in (scripts/secret_garden_way.gd). In town: the old ivy wall at the foot of the hill's north cliff stands on flat, dry,
# open ground, off the paths, and it's just a wall at first. The wren waits up on the hill, hops on along its trail as
# you catch up and flies down to the wall; you dig up the key where it pecks, the ivy parts and the door opens, and from
# then on it's on the map. In the garden: it's big (at least 130 m by 140 m inside its walls), you come in facing up
# the Rose Walk, you can really walk to the Fountain Lawn and through the maze to its heart, the giant flowers are each
# a hop from the last, nothing solid sits on any sleeping seed, waking all five wakes the garden and pays once, saving in
# there comes back in, and the old door takes you home onto the ground in front of the wall.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_secret_garden.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.secret_garden_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.secret_garden_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var bosses: Node
var way: Node


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
	bosses = root.get_node("Bosses")
	way = root.get_node("Farm/SecretGarden")
	var dialogue := root.get_node("Dialogue")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	for f in dialogue.flags.keys():
		if str(f).begins_with("sg_"):
			dialogue.flags.erase(f)

	# --- In town: the old wall ---
	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	var wall := town.get_node_or_null("Ivy Wall") as Node3D
	check(wall != null, "the old ivy wall is there at the foot of the hill")
	if wall == null:
		_finish()
		return
	var door: Vector2 = way.DOOR
	var out: Dictionary = way.way_out()
	var outp: Vector3 = out.position
	var lo := INF
	var hi := -INF
	for k in 9:
		for r in [0.0, 2.0, 4.0]:
			var a := PI + (k - 4) * 0.35                   # (in front of it, the north side, away from the cliff)
			var gp: Vector3 = bosses.ground(town, outp.x + sin(a) * r, outp.z + cos(a) * r)
			lo = minf(lo, gp.y)
			hi = maxf(hi, gp.y)
	check(hi - lo < 0.8, "...on flat ground in front of it (%.2f m up and down)" % (hi - lo))
	var wet := false
	for w in get_nodes_in_group("water"):
		if w.has_method("covers") and (w.covers(outp.x, outp.z) or w.covers(door.x, door.y)):
			wet = true
	check(not wet, "...and dry")
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a2 := Vector2(pa[0], pa[pa.size() - 1])
		var b2 := Vector2(pb[0], pb[pb.size() - 1])
		var kk := 0.0 if a2 == b2 else clampf((door - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
		path = minf(path, door.distance_to(a2.lerp(b2, kk)))
	check(path > 6.0, "...off the townsfolk's paths (%.1f m), so nobody walks into it" % path)
	var trees := town.find_child("Trees", true, false) as Node3D
	var tree := INF
	if trees:
		for tp in trees.get("positions"):
			var tg: Vector3 = trees.global_transform * tp
			tree = minf(tree, door.distance_to(Vector2(tg.x, tg.z)))
	check(tree > 4.5, "...with no tree growing through it (nearest %.1f m)" % tree)
	var space := town.get_world_3d().direct_space_state
	var ground_out: Vector3 = bosses.ground(town, outp.x, outp.z)
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	sq.shape = cap
	sq.transform = Transform3D(Basis(), ground_out + Vector3(0, 1.1, 0))
	sq.collide_with_areas = false
	check(space.intersect_shape(sq, 4).is_empty(), "...and nothing solid where you come out in front of it")
	check(not _on_map("Secret Garden"), "it isn't on the map till you've found it")
	var spot := wall.find_child("Wall Spot", true, false)
	check(spot != null and str(spot.offer.call()) == "look at the old wall", "at first it's just an old wall")
	spot.act.call()
	await _frames(4)
	check(current_scene == town and not dialogue.flags.has("sg_found"), "...and without the key it doesn't open")

	# --- The wren's trail ---
	var wren := wall.get_node_or_null("Wren") as Node3D
	check(wren != null, "a little wren is waiting")
	var trail: Array = way.TRAIL
	var on_hill := true
	for k in trail.size() - 1:
		var gk: Vector3 = bosses.ground(town, trail[k].x, trail[k].y)
		on_hill = on_hill and gk.y > 9.0
	check(on_hill, "...up on the Secret Gardens' hill, where everyone goes")
	var foot: Vector3 = bosses.ground(town, trail[trail.size() - 1].x, trail[trail.size() - 1].y)
	check(foot.y < ground_out.y + 1.0, "...and its trail ends down at the foot of the cliff, by the wall")
	check(wren.global_position.distance_to(bosses.ground(town, trail[0].x, trail[0].y)) < 0.5, "...at the start of its trail")
	var p := town.find_child("Player", true, false) as CharacterBody3D
	p.global_position = bosses.ground(town, trail[0].x + 12.0, trail[0].y) + Vector3(0, 1.0, 0)
	await _physics(10)
	check(way.wren_at() == 0, "it waits while you're further off")
	var hops := 0
	for k in trail.size() - 1:
		var wp := wren.global_position
		p.global_position = wp + Vector3(2.5, 1.0, 0)
		p.velocity = Vector3.ZERO
		for i in 150:
			await physics_frame
			if way.wren_at() > k and not way.get("_flying"):
				break
		if way.wren_at() > k:
			hops += 1
	check(dialogue.flags.has("sg_wren_seen"), "you notice it wants you to follow")
	check(hops == trail.size() - 1, "each time you catch up it hops on, all the way down to the wall (%d hops)" % hops)
	var mound := wall.get_node_or_null("Key Mound") as Node3D
	check(mound != null, "it pecks at the ground by the wall")
	var key_spot := mound.find_child("Key Spot", true, false) if mound else null
	check(key_spot != null and str(key_spot.offer.call()) == "dig where the wren is pecking", "...where you can dig")
	if key_spot:
		key_spot.act.call()
	check(dialogue.flags.has("sg_key"), "digging there finds the old key")
	await _physics(4)
	check(str(spot.offer.call()) == "part the ivy", "with the key, the ivy can be parted")
	spot.act.call()
	check(dialogue.flags.has("sg_found"), "...and there's the door: the Secret Garden's found")
	check(str(spot.offer.call()) == "go in to the Secret Garden", "...which takes you in from now on")
	await _physics(4)

	# --- In ---
	p.global_position = ground_out + Vector3(0, 1.0, 0)
	spot.act.call()
	await _frames(10)
	await _physics(6)
	var sg := current_scene as Node3D
	check(sg.scene_file_path == root.get_node("Farm").SECRET_GARDEN, "going in takes you to the Secret Garden")
	p = sg.find_child("Player", true, false) as CharacterBody3D
	check(p.global_position.distance_to(Vector3(0, 1.0, 3.0)) < 1.5, "...just inside its old door")
	var face := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	check(face.z > 0.9, "...facing up the Rose Walk")
	var wx: float = sg.WALL_X
	var wz: Vector2 = sg.WALL_Z
	check(wx * 2.0 >= 130.0 and wz.y - wz.x >= 140.0, "it's big: %.0f by %.0f m inside its walls" % [wx * 2.0, wz.y - wz.x])
	for n in ["Rose Walk", "Fountain Lawn", "Hedge Maze", "Lily Pond", "Giant Flowers", "Great Tree", "Sleeping Seeds"]:
		check(sg.get_node_or_null(n) != null, "...with the %s" % n)
	space = sg.get_world_3d().direct_space_state

	# Nothing solid sits on any sleeping seed, and each one's on the ground (or a flower)
	for id in sg.seeds:
		var at: Vector3 = sg.seeds[id].at
		sq.transform = Transform3D(Basis(), at + Vector3(0, 1.1, 0))
		check(space.intersect_shape(sq, 4).is_empty(), "nothing solid on the %s seed" % id)

	# The maze can be solved: from the way in to the heart, along open sides only
	var n: int = sg.MAZE_CELLS
	var open: Array = sg.maze_open
	var start := Vector2i(n - 1, n / 2)
	var heart := Vector2i(n / 2, n / 2)
	var dirs := {"n": Vector2i(0, 1), "s": Vector2i(0, -1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
	var prev := {start: start}
	var queue := [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in open[c.y * n + c.x]:
			var nc: Vector2i = c + dirs[d]
			if nc.x < 0 or nc.y < 0 or nc.x >= n or nc.y >= n or prev.has(nc):
				continue
			prev[nc] = c
			queue.append(nc)
	check(prev.has(heart), "the maze has a way through to its heart")
	check(prev.size() == n * n, "...and every cell can be reached")
	check("e" in open[start.y * n + start.x], "...in from the side facing the fountain")
	var route: Array[Vector2i] = []
	var c2 := heart
	while c2 != start:
		route.push_front(c2)
		c2 = prev[c2]
	route.push_front(start)
	check(route.size() > 6, "...and it's a proper maze (%d cells to the heart)" % route.size())

	# The giant flowers: each a hop up from the last, with nothing overhead
	var tops: Array = sg.flower_tops
	var radii: Array = sg.flower_radii
	var hop_ok: bool = tops.size() == 9 and tops[0].y <= 1.2
	var worst := 0.0
	for k in range(1, tops.size()):
		var gap: float = Vector2(tops[k].x - tops[k - 1].x, tops[k].z - tops[k - 1].z).length() - radii[k] - radii[k - 1]
		var rise: float = tops[k].y - tops[k - 1].y
		worst = maxf(worst, gap)
		if gap > 1.6 or rise > 1.0 or gap < 0.3:
			hop_ok = false
	check(hop_ok, "the giant flowers are each a hop from the last (widest gap %.2f m)" % worst)
	check(tops[tops.size() - 1].y > 7.0, "...up to the tallest, %.1f m up" % tops[tops.size() - 1].y)

	# Really walk: up the Rose Walk to the fountain, then round to the maze and through it to the heart
	var mz: Vector3 = sg.MAZE
	var size: float = n * sg.MAZE_CELL
	var cell := func(v: Vector2i) -> Vector3:
		return mz + Vector3(-size / 2.0 + (v.x + 0.5) * sg.MAZE_CELL, 0, -size / 2.0 + (v.y + 0.5) * sg.MAZE_CELL)
	var steps := [Vector3(0, 0, 34), Vector3(-12, 0, 40), Vector3(-17, 0, 52), mz + Vector3(size / 2.0 + 1.5, 0, cell.call(start).z - mz.z)]
	for v in route:
		steps.append(cell.call(v))
	p.global_position = Vector3(0, 1.0, 3.0)
	p.velocity = Vector3.ZERO
	await _physics(10)
	var wpi := 0
	var got_there := false
	for i in 60 * 70:
		await physics_frame
		var want: Vector3 = steps[wpi] - p.global_position
		want.y = 0
		if want.length() < 0.8:
			if wpi == steps.size() - 1:
				got_there = true
				break
			wpi += 1
		_steer(p, want.normalized())
	_release()
	check(got_there, "you can walk up the Rose Walk, past the fountain and through the maze to its heart (step %d of %d)" % [wpi, steps.size()])
	await _physics(10)
	check(dialogue.flags.has("sg_seed_maze"), "...where the sleeping seed wakes as you get to it")

	# The rest of the seeds, and the garden waking
	var sparkles: int = game.sparkles
	var remnants: int = root.get_node("Remnants").count
	for id in ["walk", "pond", "flower", "tree"]:
		check(not sg.awake, "the garden's still asleep before the %s seed" % id)
		var at: Vector3 = sg.seeds[id].at
		p.global_position = at + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(3)
		check(dialogue.flags.has("sg_seed_" + id), "the %s seed wakes when you get to it" % id)
	check(sg.awake and dialogue.flags.has("sg_awake"), "all five awake: the whole garden wakes up")
	check(game.sparkles - sparkles == sg.WAKE_SPARKLES and root.get_node("Remnants").count - remnants == sg.WAKE_REMNANTS,
		"...and pays %d sparkles and %d Remnants" % [game.sparkles - sparkles, root.get_node("Remnants").count - remnants])
	sparkles = game.sparkles
	sg.call("_wake_garden")
	check(game.sparkles == sparkles, "...only once")

	# --- Saving in there brings you back in ---
	game.hold_saves = false
	game.save_game()
	game.hold_saves = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(str(data.get("scene", "")) == root.get_node("Farm").SECRET_GARDEN, "saving in the garden saves you there")

	# --- Home through the old door ---
	var home := sg.find_child("Door Spot", true, false)
	check(home != null and str(home.offer.call()) == "go back out through the old door", "the old door offers the way home")
	home.act.call()
	await _frames(10)
	await _physics(30)
	town = current_scene as Node3D
	check(town.scene_file_path == TOWN, "it takes you back to the Void")
	p = town.find_child("Player", true, false) as CharacterBody3D
	var g2: Vector3 = bosses.ground(town, outp.x, outp.z)
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(outp.x, outp.z)) < 1.5
		and absf(p.global_position.y - g2.y - 0.9) < 0.5 and p.is_on_floor(),
		"...standing on the ground in front of the ivy wall (%.1f m off the ground)" % (p.global_position.y - g2.y))
	wall = town.get_node("Ivy Wall")
	check(wall.get_node_or_null("Wren") == null, "the wren's gone off about its business")
	check(_on_map("Secret Garden"), "the Secret Garden's on the map now")
	spot = wall.find_child("Wall Spot", true, false)
	check(str(spot.offer.call()) == "go in to the Secret Garden", "...and its door takes you straight in")
	spot.act.call()
	await _frames(10)
	await _physics(4)
	sg = current_scene as Node3D
	check(sg.awake and sg.seeds_woken() == 5, "next time in, it's still awake")
	_finish()


func _on_map(label: String) -> bool:
	for n in get_nodes_in_group("map_landmarks"):
		if n.has_method("map_name") and n.map_name() == label:
			return true
	return false


func _steer(p: CharacterBody3D, want: Vector3) -> void:
	# Like a player on the stick: through the camera's frame
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
