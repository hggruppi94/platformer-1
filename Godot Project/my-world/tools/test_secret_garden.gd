extends SceneTree

# Checks the real Secret Garden (scripts/secret_garden.gd, scenes/secret_garden/secret_garden.tscn) and its hidden way
# in (scripts/secret_garden_way.gd). In town: the old ivy wall at the foot of the hill's north cliff stands on flat, dry,
# open ground, off the paths, and it's just a wall at first. The wren waits up on the hill, hops on along its trail as
# you catch up and flies down to the wall; you dig up the key where it pecks, the ivy parts and the door opens, and from
# then on it's on the map. In the garden (rebuilt 26 Nov 2026 as a hillside estate): it's big (at least 270 m by 300 m
# inside its walls) with all its gardens, nothing solid sits on any sleeping seed, and you can really walk from the door
# up to the Overlook in front of the Old House (not into it), through the maze to its heart, up the lookout, the temple's
# steps, over every bridge, the Treetop Walk, round the tallest supertree and down into the Sunken Garden, waking every
# seed on foot; that wakes the garden and pays once, saving in there comes back in, and the old door takes you home
# onto the ground in front of the wall.
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
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
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
	check(p.global_position.distance_to(Vector3(0, 1.0, 4.0)) < 1.5, "...just inside its old door")
	var face := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	check(face.z > 0.9, "...facing up into the garden")
	var wx: float = sg.WALL_X
	var wz: Vector2 = sg.WALL_Z
	check(wx * 2.0 >= 270.0 and wz.y - wz.x >= 300.0, "it's big: %.0f by %.0f m inside its walls" % [wx * 2.0, wz.y - wz.x])
	var parts: Dictionary = sg.parts
	check(parts.size() == 4, "...built in four parts: the estate, the waters, the groves and the garden rooms")
	var est: Node3D = parts.get("estate")
	var wat: Node3D = parts.get("waters")
	var gro: Node3D = parts.get("groves")
	var rms: Node3D = parts.get("rooms")
	for pair in [[est, "Old House"], [est, "Overlook Terrace"], [est, "Formal Garden"], [est, "Water Stairs"],
			[est, "Tulip Slope"], [est, "Cypress Walk"], [wat, "Temple Lake"], [wat, "Lake Temple"], [wat, "Palladian Bridge"],
			[wat, "Lily Pond"], [wat, "Japanese Garden"], [wat, "Rose Arches"], [gro, "Great Tree"], [gro, "Treetop Walk"],
			[gro, "Glasshouse"], [gro, "Supertree Grove"], [rms, "Hedge Maze"], [rms, "Maze Lookout"], [rms, "Potager"],
			[rms, "Rill Court"], [rms, "Sunken Garden"]]:
		check(pair[0] != null and (pair[0] as Node).get_node_or_null(pair[1]) != null, "...with the %s" % pair[1])
	check(sg.get_node_or_null("Sleeping Seeds") != null and sg.seed_at.size() == 5, "...and each of the five seeds put in its place")
	space = sg.get_world_3d().direct_space_state

	# Nothing solid sits on any sleeping seed
	for id in sg.seeds:
		var at: Vector3 = sg.seeds[id].at
		sq.transform = Transform3D(Basis(), at + Vector3(0, 1.1, 0))
		check(space.intersect_shape(sq, 4).is_empty(), "nothing solid on the %s seed" % id)

	# Hayden (27 Nov 2026): proper collision, baked detail, more pink and white flowers spread out (not all pink)
	while int(sg.solidified) < 0:
		await physics_frame
	await _physics(2)
	check(int(sg.solidified) > 200, "the rocks, roots, roofs and rims are solid (%d bodies added)" % int(sg.solidified))
	for where in ["Waters/Lily Pond", "Groves/Great Tree", "Estate/Old House"]:
		var n := sg.get_node_or_null(where)
		check(n != null and not n.find_children("Solid *", "StaticBody3D", true, false).is_empty(), "...in the %s too" % where.get_file())
	var counts: Array = sg.flower_counts
	var all := 0
	var pink_white := 0
	var used := 0
	for i in counts.size():
		all += int(counts[i])
		var c: Color = sg.FLOWER_COLOURS[i][0]
		if (c.r > 0.9 and c.b > 0.55 and c.g < 0.9) or (c.r > 0.95 and c.g > 0.9):
			pink_white += int(counts[i])
		if int(counts[i]) > 0:
			used += 1
	var share := float(pink_white) / maxf(all, 1)
	check(all > 3000, "wild flowers all over the garden (%d)" % all)
	check(share > 0.4 and share < 0.6, "...about half pink and white (%.0f%%), mixed with other colours" % (share * 100.0))
	check(used >= 8, "...in %d colours" % used)
	var mixed := 0
	var patches := sg.get_node("Wildflowers").get_children().filter(func(n): return String(n.name).begins_with("Patch"))
	for patch in patches:
		var kinds := 0
		for c in (patch as Node).get_children():
			if String(c.name).begins_with("Flower Heads"):
				kinds += 1
		if kinds >= 4:
			mixed += 1
	check(patches.size() > 30 and mixed > patches.size() * 0.8, "...spread out, mixed in nearly every patch (%d of %d)" % [mixed, patches.size()])
	var white_trees := 0
	var pink_trees := 0
	var white_parts := 0
	for part in [est, wat, gro, rms]:
		var here := 0
		for t in (part as Node).find_children("Tree Leaf blossom*", "MultiMeshInstance3D", true, false):
			var n: int = (t.get_meta("transforms", []) as Array).size()
			if String(t.name).ends_with("blossom_white"):
				white_trees += n
				here += n
			elif String(t.name).ends_with("blossom"):
				pink_trees += n
		if here > 0:
			white_parts += 1
	check(white_trees > 0 and pink_trees > 0 and white_parts >= 3, "white and pink blossom trees all round (%d white, %d pink leaf balls, white in %d parts)" % [white_trees, pink_trees, white_parts])
	var plain := 0
	for mat_name in ["Estate Stone", "Door Wood"]:
		for g in sg.find_children("*", "MeshInstance3D", true, false):
			var m2 := (g as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			if m2 and String(m2.resource_name) == mat_name and not m2.normal_enabled:
				plain += 1
	check(plain == 0, "the garden's own walls and door wear baked detail (%d plain left)" % plain)
	var sparkles: int = game.sparkles
	var remnants: int = root.get_node("Remnants").count

	# Really walk from the door all the way up to the Overlook in front of the house: round Temple Lake, up the Tulip
	# Slope, beside the Water Stairs, along the Cypress Walk, across the Formal Garden and up a stair
	var route := [Vector3(0, 0, 16), Vector3(-22, 0, 22), Vector3(-42, 0, 36), Vector3(-47, 0, 58), Vector3(-44, 0, 78),
		Vector3(-36, 0, 94), Vector3(-14, 0, 100), Vector3(0, 0, 102), Vector3(0, 0, 138), Vector3(7.5, 0, 143),
		Vector3(7.5, 0, 197), Vector3(0, 0, 202), Vector3(0, 0, 245), Vector3(46, 0, 246), Vector3(46, 0, 268),
		Vector3(46, 0, 288), Vector3(30, 0, 288)]
	var res := await _walk(p, route, 120.0)
	check(res.ok and p.global_position.y > 23.6 and p.is_on_floor(),
		"you can walk from the door right up to the Overlook in front of the Old House (%.1f m up)" % (p.global_position.y - 0.9))
	res = await _walk(p, [Vector3(20, 0, 310)], 4.0)
	check(not res.ok and p.global_position.z < 302.0, "...but not into the Old House (it's shut up)")
	res = await _walk(p, [Vector3(12, 0, 287.4), Vector3(0, 0, 287.2), Vector3(0, 0, 269.8)], 20.0)
	check(res.ok and absf(p.global_position.y - 0.9 - 18.0) < 0.6, "...and down the grand stair to the Formal Garden")

	# The maze: it can be solved, and you can really walk it to its heart
	var n: int = rms.MAZE_N
	var cs: float = rms.MAZE_CELL
	var mo: Vector2 = rms.MAZE_ORIGIN
	var east_w: Array = rms.maze_east
	var north_w: Array = rms.maze_north
	var start := Vector2i(n - 1, rms.maze_entry_row)
	var prev := {start: start}
	var queue := [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var nbs := []
		if c.x < n - 1 and not east_w[c.x][c.y]: nbs.append(c + Vector2i(1, 0))
		if c.x > 0 and not east_w[c.x - 1][c.y]: nbs.append(c + Vector2i(-1, 0))
		if c.y < n - 1 and not north_w[c.x][c.y]: nbs.append(c + Vector2i(0, 1))
		if c.y > 0 and not north_w[c.x][c.y - 1]: nbs.append(c + Vector2i(0, -1))
		for nc: Vector2i in nbs:
			if not prev.has(nc):
				prev[nc] = c
				queue.append(nc)
	var heart := Vector2i(n / 2, n / 2)
	check(prev.has(heart), "the maze has a way through to its heart")
	check(prev.size() == n * n, "...and every cell can be reached (%d of %d)" % [prev.size(), n * n])
	var mroute: Array[Vector2i] = []
	var c2 := heart
	while c2 != start:
		mroute.push_front(c2)
		c2 = prev[c2]
	mroute.push_front(start)
	check(mroute.size() > 12, "...and it's a proper maze (%d cells to the heart)" % mroute.size())
	var msteps := [Vector3(-13, 0, 266), Vector3(-13, 0, 261.5), Vector3(-58, 0, 262), Vector3(-70, 0, 262), Vector3(rms.maze_entry.x + 1.5, 0, rms.maze_entry.y)]
	for v in mroute:
		msteps.append(Vector3(mo.x + (v.x + 0.5) * cs, 0, mo.y + (v.y + 0.5) * cs))
	msteps.append(Vector3(rms.maze_heart.x, 0, rms.maze_heart.y - 1.5))
	res = await _walk(p, msteps, 90.0)
	check(res.ok, "you can walk from the Formal Garden into the maze and through it to its heart")
	await _physics(4)
	check(dialogue.flags.has("sg_seed_maze"), "...where the maze seed wakes as you get to it")

	# The maze's lookout: up its stair
	var ls: Dictionary = rms.stairs[0]
	_put(p, ls.foot)
	await _physics(6)
	res = await _walk(p, [ls.foot, ls.top, Vector3(rms.LOOKOUT.x, 0, rms.LOOKOUT.z)], 20.0)
	check(res.ok and p.global_position.y > rms.LOOKOUT.y + 0.6, "you can walk up the lookout's stair (%.1f m up)" % (p.global_position.y - 0.9))

	# The temple's steps (the walk seed) from the lake path
	_put(p, Vector3(-40, 0, 86))
	await _physics(6)
	var wseed: Vector3 = sg.seeds["walk"].at
	res = await _walk(p, [Vector3(-30, 0, 81), wseed], 20.0)
	await _physics(4)
	check(res.ok and dialogue.flags.has("sg_seed_walk"), "you can walk up the lake temple's steps, where the walk seed wakes")

	# Over every bridge
	for part in [est, wat, gro, rms]:
		for b in part.bridges:
			var a: Vector3 = b.from
			var e: Vector3 = b.to
			var dir := (e - a).normalized()
			_put(p, a - dir * 2.0)
			await _physics(6)
			var w := await _walk(p, [a - dir * 1.0, (a + e) / 2.0, e + dir * 0.8], 20.0, true)
			check(w.ok and w.top - 0.9 - (a.y + e.y) / 2.0 > b.rise * 0.7, "you can walk over the %s (%.1f m up at its top)" % [b.name, w.top - 0.9])
	# The green bridge goes to the Lily Pond's island, where the pond seed is
	var pseed: Vector3 = sg.seeds["pond"].at
	for b in wat.bridges:
		if b.name == "Green Bridge":
			_put(p, b.to)
	await _physics(6)
	res = await _walk(p, [pseed], 10.0)
	await _physics(4)
	check(dialogue.flags.has("sg_seed_pond"), "...and on the Lily Pond's island the pond seed wakes")

	# The Treetop Walk, from its foot up into the Great Tree's crown
	var wp: Array = gro.walk_pts
	var w0: Vector3 = wp[0]
	var w1: Vector3 = wp[1]
	_put(p, w0 - (w1 - w0).normalized() * 2.0)
	await _physics(6)
	var tsteps := []
	for q in wp:
		tsteps.append(q)
	tsteps.append(sg.seeds["tree"].at)
	res = await _walk(p, tsteps, 60.0, true)
	await _physics(4)
	check(res.ok and p.global_position.y > gro.crown_y() + 0.5, "you can walk the Treetop Walk up into the Great Tree's crown (%.1f m up)" % (p.global_position.y - 0.9))
	check(dialogue.flags.has("sg_seed_tree"), "...where the tree seed wakes")

	# Up the ramp round the tallest supertree
	var sp: Array = gro.spiral_pts
	var s0: Vector3 = sp[0]
	_put(p, s0 + Vector3(2.0, 0, -1.5))
	await _physics(6)
	var ssteps := []
	for q in sp:
		ssteps.append(q)
	ssteps.append(sg.seeds["flower"].at)
	res = await _walk(p, ssteps, 90.0, true)
	await _physics(4)
	check(res.ok and p.global_position.y > gro.SUPER_PAD + gro.TALLEST.y - 1.2, "you can walk up round the tallest supertree to its canopy (%.1f m up)" % (p.global_position.y - 0.9))

	# Down the quarry's ramp to the Sunken Garden's floor
	var rp: Array = rms.ramp_pts
	var r0: Vector3 = rp[0]
	var r1: Vector3 = rp[1]
	_put(p, r0 - (r1 - r0).normalized() * 2.0)
	await _physics(6)
	res = await _walk(p, rp, 40.0, true)
	check(res.ok and p.global_position.y - 0.9 < 2.6, "you can walk down the ramp into the Sunken Garden (%.1f m up)" % (p.global_position.y - 0.9))

	# The garden waking
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


func _walk(p: CharacterBody3D, steps: Array, seconds: float, keep_line := false) -> Dictionary:
	# Steers her along steps (x, z), like a player on the stick; ok if she got to the last one. top is the highest she
	# got. keep_line steers back onto the line between steps, so she walks over a bridge, not round it.
	var wpi := 0
	var top := p.global_position.y
	var from := p.global_position
	for i in int(60 * seconds):
		await physics_frame
		top = maxf(top, p.global_position.y)
		var aim: Vector3 = steps[wpi]
		var want: Vector3 = aim - p.global_position
		want.y = 0
		if want.length() < 0.7:
			if wpi == steps.size() - 1:
				_release()
				return {"ok": true, "top": top}
			from = Vector3(aim.x, p.global_position.y, aim.z)
			wpi += 1
			continue
		if keep_line:
			var line := Vector3(aim.x - from.x, 0, aim.z - from.z)
			if line.length() > 0.1:
				var ln := line.normalized()
				var rel := Vector3(p.global_position.x - from.x, 0, p.global_position.z - from.z)
				var off := rel - ln * rel.dot(ln)
				want = ln * 1.0 - off * 1.5
		_steer(p, want.normalized())
	_release()
	var hit := ""
	for k in p.get_slide_collision_count():
		var col := p.get_slide_collision(k).get_collider() as Node
		if col:
			hit += " " + str(col.get_path())
	print("  (stopped at %s, on the way to step %d of %d: %s; touching%s)" % [p.global_position.snapped(Vector3.ONE * 0.1), wpi, steps.size(), steps[wpi], hit])
	return {"ok": false, "top": top}


func _put(p: CharacterBody3D, at: Vector3) -> void:
	# Puts her on the ground at (x, z)
	var land: Script = load("res://scripts/secret_garden_land.gd")
	p.global_position = Vector3(at.x, land.height(at.x, at.z) + 1.0, at.z)
	p.velocity = Vector3.ZERO


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
