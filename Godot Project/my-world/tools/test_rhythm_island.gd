extends SceneTree

# Checks Rhythm Springs' island (tools/build_rhythm_springs.gd, its ground scripts/rhythm_land.gd): the island rises in
# terraces with cliffs, and you arrive on the beach on solid ground and really walk (on the stick, through the camera's
# frame) up the torch path to the Springs Gate on its terrace and down into the valley, out along the pier, up the
# Pavilion Bluff and the pavilion's steps, up the ramp to the first stilt treehouse, round its deck and over both rope
# bridges to the third, in through the crystal cave's mouth, up both tiers of the North Highlands, up the East Headland
# and out along the overlook, along the bamboo grove's path on the West Terrace into the legend hut, and out to the
# islet. The cliffs are too steep to walk up.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_rhythm_island.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.rhythm_island_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rhythm_island_test_backup.cfg"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"
const B := preload("res://tools/build_rhythm_springs.gd")
const L := preload("res://scripts/rhythm_land.gd")

var failures := 0
var game: Node
var world: Node3D
var p: CharacterBody3D


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
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	change_scene_to_file(WORLD)
	await _frames(10)
	await _physics(10)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	check(world != null and p != null, "Rhythm Springs loads with the player in it")
	if p == null:
		_finish()
		return

	# The island's parts
	for n in ["Island Ground", "Sea", "WorldBounds Fence", "Springs Gate", "Pavilion", "Stilt Huts", "Crystal Cave",
			"Bamboo Grove", "Pier", "Flower Glade", "Legend Hut", "Tide Pools", "Islet", "Overlook", "Waterfall Grotto",
			"Lighthouse"]:
		check(world.find_child(n, true, false) != null, "the island has its " + n)
	var falls := world.find_children("Waterfall", "", true, false)
	var ridge := false
	for f in falls:
		ridge = ridge or str(f.get_meta("fall_id", "")) == "ridge_falls"
	check(ridge, "the ridge's waterfall is marked for its secret cove")
	for n in ["Shade Pavilion", "Shade Hut 1", "Shade Hut 2", "Shade Hut 3", "Shade Cave", "Shade Legend Hut"]:
		check(world.find_child(n, true, false) != null, n + " cools you down")
	check(B.HUTS.size() == 3, "three stilt treehouses")
	_check_detail()

	# The island isn't flat: terraces with cliffs between them
	check(L.height(L.at(262, 105).x, L.at(262, 105).z) > 20.0, "the North Highlands' upper tier is over 20 m up")
	check(L.height(L.at(0, 100).x, L.at(0, 100).z) > 11.0, "the East Headland is 12 m up")
	check(absf(L.height(B.GATE.x, B.GATE.z) - B.GATE.y) < 0.3, "the Springs Gate stands on its terrace, %.1f m up" % B.GATE.y)
	check(L.slope(L.at(276, 66.2).x, L.at(276, 66.2).z) > 2.0, "the highlands' cliff is steep (%.1f m a metre)" % L.slope(L.at(276, 66.2).x, L.at(276, 66.2).z))
	check(B.shore_r(PI / 2.0) > 100.0, "the island is big (%.0f m to the southern beach)" % B.shore_r(PI / 2.0))

	# It makes sense as a place (Hayden: "does it make sense geographically?")
	_check_geography()

	# Where you arrive is on the ground
	await _settle()
	check(absf(_feet() - L.height(B.ARRIVE.x, B.ARRIVE.z)) < 0.6 and p.is_on_floor(), "you arrive standing on the beach (feet at %.2f)" % _feet())

	# Up the torch path to the gate on its terrace, through it and down into the valley
	await _route("up the torch path, through the Springs Gate and down into the valley", B.ARRIVE,
		[Vector3(0, 0, 80), B.GATE, Vector3(0, 0, 62), Vector3(0, 0, 40)], 0.0)
	# Out along the pier
	await _route("along the beach and out to the end of the pier", B.ARRIVE,
		[Vector3(B.PIER_X, 0, B.ARRIVE.z - 0.5), Vector3(B.PIER_X, 0, B.PIER_END - 4.0)], 0.0)
	# Up the Pavilion Bluff's ramp, then up the pavilion's steps onto its raised deck
	var pin := Vector3(-B.PAVILION.x, 0, -B.PAVILION.z).normalized()
	await _route("up the Pavilion Bluff's ramp", L.at(44, 66), [L.at(46, 72), L.at(50, 87)], 6.0)
	await _route("up the pavilion's steps onto its deck", B.PAVILION + pin * 14.0,
		[B.PAVILION + pin * 11.0, B.PAVILION + pin * 4.0, B.PAVILION + pin * 1.8], B.PAVILION.y + B.PAV_DECK)
	# Up the ramp, round the decks and over the rope bridges
	var in_dir := Vector3(-B.HUTS[0].x, 0, -B.HUTS[0].z).normalized()
	var steps: Array = [B.HUTS[0] + in_dir * (B.HUT_R + 12.0), B.HUTS[0] + in_dir * 3.3 + Vector3(0, B.HUT_DECK, 0)]
	for i in B.HUTS.size() - 1:
		var from: Vector3 = B.HUTS[i]
		var to: Vector3 = B.HUTS[i + 1]
		var last: Vector3 = steps[steps.size() - 1]
		steps.append_array(_round_deck(from, last - from, to - from))
		steps.append(to - (to - from).normalized() * 3.3 + Vector3(0, B.HUT_DECK, 0))
	await _route("up the ramp to the first treehouse, round its deck and over both rope bridges to the third",
		B.HUTS[0] + in_dir * (B.HUT_R + 16.0), steps, B.HUT_DECK)
	check(absf(_feet() - B.HUT_DECK) < 0.3, "...standing up on the third treehouse's deck (feet at %.2f)" % _feet())
	# In through the crystal cave's mouth
	var face := Vector3(-B.CAVE.x, 0, -B.CAVE.z).normalized()
	await _route("in through the crystal cave's mouth", B.CAVE + face * 16.0,
		[B.CAVE + face * 10.0, B.CAVE + face * 5.0], 0.0)
	# Up both tiers of the North Highlands
	await _route("up the ramp onto the North Highlands' lower tier", L.at(234, 50), [L.at(236, 57), L.at(240, 70), L.at(246, 82), L.at(250, 78)], 10.0)
	await _route("on across it and up to the upper tier, 22 m up", L.at(300, 72, 10), [L.at(302, 76), L.at(292, 80), L.at(280, 88), L.at(276, 94)], 22.0)
	# Up the East Headland and out along the overlook
	var ov := world.find_child("OverlookEnd", true, false) as Node3D
	await _route("up the East Headland's ramp", L.at(-18, 64), [L.at(-16, 70), L.at(-10, 84), L.at(-5, 96), L.at(-2, 104)], 12.0)
	if ov:
		var o: Vector3 = ov.global_position
		var odir := Vector3(o.x, 0, o.z).normalized()
		await _route("out along the overlook boardwalk to its end", L.at(1, 108), [o - odir * 26.0, o - odir * 8.0, o], 12.0)
	# Into the flower glade, between two of its giant flowers
	var ga := 0.2 + TAU / 22.0
	var gd := Vector3(cos(ga), 0, sin(ga))
	await _route("in between the giant flowers to the middle of the glade", B.GLADE + gd * 12.0,
		[B.GLADE + gd * 4.0, B.GLADE], 0.0)
	# Up onto the West Terrace, along the bamboo grove's path, and into the legend hut by its open side
	await _route("up the West Terrace's ramp to the bamboo grove", L.at(182, 50), [L.at(184, 57), L.at(189, 75), L.at(B.GROVE_A, B.GROVE_FROM + 4.0)], B.TERRACE_Y)
	var hut := B.LEGEND_HUT
	var open := (L.at(196, 80) - Vector3(hut.x, 0, hut.z)).normalized()
	await _route("along the grove's path and into the legend hut to its drum", L.at(B.GROVE_A, B.GROVE_FROM + 2.0, 7.0),
		[L.at(B.GROVE_A, 86.0), L.at(196, 80), hut + open * 4.0, hut + open * 1.4], B.TERRACE_Y)
	await _route("on to the end of the bamboo grove", L.at(B.GROVE_A, B.GROVE_FROM + 2.0, 7.0), [L.at(B.GROVE_A, B.GROVE_TO - 3.0)], B.TERRACE_Y)
	# The cliffs can't be walked up
	await _route_blocked("straight up the North Highlands' cliff", L.at(276, 58), L.at(276, 76))
	await _route_blocked("straight up the East Headland's cliff", L.at(8, 70), L.at(8, 92))
	# Out along the sandbar to the islet, and you can't step off it into the deep sea
	var from: Vector3 = B.bar_from()
	var islet: Vector3 = B.islet_at()
	var bar := (islet - from).normalized()
	await _route("out along the sandbar to the islet", from - bar * 6.0, [from, islet - bar * 3.0, islet + Vector3(0, 0, 2.5)], -1.0)
	var mid := from.lerp(islet, 0.55)
	await _route_blocked("off the side of the sandbar into the deep sea", mid, mid + bar.cross(Vector3.UP) * 6.0)
	await _route_blocked("off the islet's far side into the deep sea", islet, islet + bar * 12.0)
	var fence_at := bar * (B.shore_r(atan2(bar.z, bar.x)) - 3.0)
	await _route_blocked("through the fence beside the sandbar out onto the sea", fence_at + bar.cross(Vector3.UP) * 3.0 - bar * 3.0,
		fence_at + bar.cross(Vector3.UP) * 3.0 + bar * 8.0)
	_finish()


func _check_geography() -> void:
	# The old volcano's peak is the island's highest point, too steep to climb, with a crater lake on top
	var top := L.peak_top()
	var pk: Array = L.PEAKS[0]
	var c := L.at(pk[0], pk[1])
	var highest := 0.0
	for x in range(-140, 141, 4):
		for z in range(-140, 141, 4):
			highest = maxf(highest, L.height(x, z))
	var rim := 0.0
	for k in 16:
		var a := k * TAU / 16.0
		rim = maxf(rim, L.height(c.x + cos(a) * (L.CRATER_R + 1.0), c.z + sin(a) * (L.CRATER_R + 1.0)))
	check(rim > 35.0 and highest <= rim + 0.5, "the volcano's peak is the highest point (rim %.1f m, highest %.1f m)" % [rim, highest])
	check(top.y < rim - 3.0, "its crater dips in (%.1f m below the rim)" % (rim - top.y))
	var side := c + Vector3(1, 0, 0) * (float(pk[2]) * 0.5)
	check(L.slope(side.x, side.z) > 1.0, "its sides are too steep to walk up (%.1f m a metre)" % L.slope(side.x, side.z))
	check(world.find_child("Crater Lake", true, false) != null and world.find_child("Crater Steam", true, false) != null,
		"a crater lake with steam on top")
	# A spring at its foot feeds the stream over the upper tier to the big waterfall
	var spring := world.find_child("Volcano Spring", true, false) as Node3D
	check(spring != null and absf(spring.position.y - 22.0) < 0.5, "a spring at the peak's foot, on the upper tier")
	check(world.find_child("Spring Stream", true, false) != null and world.find_child("Upper Falls", true, false) != null,
		"its stream runs to the upper falls")
	if spring != null:
		var lip := L.at(B.FALLS_AT, B.cliff_edge(B.FALLS_AT, 70.0, 100.0, 21.0))
		check(Vector2(spring.position.x - lip.x, spring.position.z - lip.z).length() < 20.0, "...the spring is just above the falls")
	# The creek takes the water from the Falls Pool round the valley and out to the sea
	var creek := world.find_child("Creek", true, false)
	check(creek != null and creek.find_child("Creek Water", true, false) != null, "the creek is there")
	var pool := world.find_child("Falls Pool", true, false) as Node3D
	var first: Vector3 = L.at(B.CREEK[0][0], B.CREEK[0][1])
	var last: Vector3 = L.at(B.CREEK[-1][0], B.CREEK[-1][1])
	check(pool != null and Vector2(pool.position.x - first.x, pool.position.z - first.z).length() < 6.0,
		"it starts at the Falls Pool")
	check(L.height(last.x, last.z) < B.SEA_Y, "it ends in the sea (%.1f m)" % L.height(last.x, last.z))
	var dry := true
	var uphill := 0.0
	var prev_h := 0.0
	for i in B.CREEK.size():
		var q := L.at(B.CREEK[i][0], B.CREEK[i][1])
		var h := L.height(q.x, q.z)
		if i > 0:
			uphill = maxf(uphill, h - prev_h)
		prev_h = h
		dry = dry and h < 0.6
	check(dry and uphill < 0.3, "it runs on the low ground all the way and never uphill")
	var wade := creek.find_child("Creek Wading", true, false) if creek != null else null
	check(wade != null and wade.call("covers", first.x, first.z), "you wade in it")
	var crossings := int(creek.get_meta("crossings", 0)) if creek != null else 0
	check(crossings >= 2, "stepping stones take the paths over it (%d)" % crossings)
	# The stilt huts stand in a mangrove marsh at its mouth
	var marsh := world.find_child("Mangrove Marsh", true, false)
	check(marsh != null and marsh.find_children("Mangrove*", "", true, false).size() >= 10, "a mangrove marsh round the stilt huts")
	for i in B.HUTS.size():
		var h: Vector3 = B.HUTS[i]
		check(marsh != null and marsh.call("covers", h.x, h.z), "stilt hut %d stands in the marsh's water" % (i + 1))
	var near_creek := false
	for h: Vector3 in B.HUTS:
		for q in B.CREEK:
			near_creek = near_creek or Vector2(h.x, h.z).distance_to(Vector2(L.at(q[0], q[1]).x, L.at(q[0], q[1]).z)) < 10.0
	check(near_creek, "...where the creek runs out to the sea")
	# Tide pools sit on a rock shelf, not the sand
	var shelf := world.find_child("Rock Shelf", true, false)
	check(shelf != null and shelf.get_child_count() > 20, "the tide pools sit on a shelf of rock")
	if shelf != null:
		var on_rock := 0
		for pool_node in world.find_child("Tide Pools", true, false).get_children():
			if not str(pool_node.name).begins_with("Tide Pool"):
				continue
			for sl in shelf.get_children():
				if str(sl.name).begins_with("Shelf Slab") and Vector2(sl.position.x - pool_node.position.x, sl.position.z - pool_node.position.z).length() < 2.6:
					on_rock += 1
					break
		check(on_rock == B.TIDE_A.size(), "every tide pool is on the rock (%d of %d)" % [on_rock, B.TIDE_A.size()])


func _check_detail() -> void:
	# The baked island props (scripts/detail_props.gd dress_rhythm, tools/build_prop_island.py): every palm, torch,
	# grove lantern and the gate has its detailed one, nothing old is drawn, and the collisions and flames stay
	var props: Dictionary = root.get_node("WorldDetail").last_props
	var palms := world.find_children("Parasol Palm *", "Node3D", true, false)
	var torches := 0
	for f in world.find_children("Flame", "MeshInstance3D", true, false):
		if f.get_parent().get_parent().name == "Torch Paths":
			torches += 1
	check(palms.size() > 40 and props.get("palms", 0) == palms.size(),
		"every palm is detailed (%d of %d)" % [props.get("palms", 0), palms.size()])
	check(torches > 5 and props.get("torches", 0) == torches, "every tiki torch is detailed (%d of %d)" % [props.get("torches", 0), torches])
	check(props.get("lanterns", 0) >= 2, "the bamboo grove's lanterns are detailed (%d)" % props.get("lanterns", 0))
	check(props.get("gate", 0) == 1, "the Springs Gate is detailed")
	var old_drawn := 0
	var flames_hidden := 0
	for g in palms + [world.find_child("Springs Gate", true, false)]:
		for m in (g as Node).get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).layers != 0:
				old_drawn += 1
	for f in world.find_children("Flame", "MeshInstance3D", true, false):
		if f.get_parent().get_parent().name == "Torch Paths" and (f as MeshInstance3D).layers == 0:
			flames_hidden += 1
	check(old_drawn == 0, "none of the old palm or gate pieces are drawn (%d)" % old_drawn)
	check(flames_hidden == 0, "the torches' flames still burn")
	var bodies := 0
	for g in palms:
		bodies += (g as Node).find_children("*", "StaticBody3D", true, false).size()
	check(bodies >= palms.size(), "the palms are still solid (%d bodies)" % bodies)
	# Each detailed palm is as tall as its old one and leans the same way
	var worst := 0.0
	for g in palms:
		var d := (g as Node).get_node_or_null("Detailed Palm") as Node3D
		var top := Vector3.ZERO
		for m in (g as Node).get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).material_override and \
					(m as MeshInstance3D).material_override.resource_name == "Coconut":
				top = m.position + Vector3(0, 0.3, 0)
		if d == null:
			worst = INF
			continue
		var model_top: Vector3 = d.transform * Vector3(0.9, 5.0, 0)
		var off := absf(model_top.y - top.y)
		var lean := Vector2(top.x, top.z)
		if lean.length() > 0.2:
			off += 1.0 - Vector2(model_top.x, model_top.z).normalized().dot(lean.normalized())
		worst = maxf(worst, off)
	check(worst < 0.15, "each detailed palm stands as tall as its old one and leans its way (worst %.2f off)" % worst)


func _route_blocked(what: String, start: Vector3, goal: Vector3) -> void:
	# Walk hard at somewhere you shouldn't get to for 6 s: you mustn't get within 2 m of it, nor fall into the sea
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	for i in 60 * 6:
		await physics_frame
		world.set("heat", 0.0)
		var want := goal - p.global_position
		want.y = 0
		_steer(want.normalized())
	_release()
	await _physics(10)
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).length()
	check(d > 2.0 and _feet() > -0.9, "you can't walk %s (%.1f m short, feet at %.2f)" % [what, d, _feet()])


func _round_deck(at: Vector3, from_v: Vector3, to_v: Vector3) -> Array:
	# Waypoints round a treehouse's deck, 3.3 m out from its middle (the hut's walls go out 2.5 m, the deck 4.3 m),
	# the short way round from where you came onto it to where the next bridge leaves
	var out := []
	var a0 := atan2(from_v.z, from_v.x)
	var a1 := atan2(to_v.z, to_v.x)
	var d := wrapf(a1 - a0, -PI, PI)
	var n := int(ceil(absf(d) / deg_to_rad(20.0)))
	for k in range(1, n + 1):
		var aa := a0 + d * k / n
		out.append(at + Vector3(cos(aa), 0, sin(aa)) * 3.3 + Vector3(0, B.HUT_DECK, 0))
	return out


func _route(what: String, start: Vector3, steps: Array, end_y: float) -> void:
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	var heat_of: Variant = world.get("heat")
	var wpi := 0
	var got := false
	for i in 60 * 40:
		await physics_frame
		if heat_of != null:
			world.set("heat", 0.0)
		var want: Vector3 = steps[wpi] - p.global_position
		want.y = 0
		if want.length() < 0.7:
			if wpi == steps.size() - 1:
				got = true
				break
			wpi += 1
		_steer(want.normalized())
	_release()
	await _physics(10)
	check(got and (end_y < -0.5 or absf(_feet() - end_y) < 0.6),
		"you can walk %s (step %d of %d, feet at %.2f, at %s)" % [what, wpi + 1, steps.size(), _feet(), p.global_position.snapped(Vector3.ONE * 0.1)])


func _feet() -> float:
	# The player's origin is the middle of their capsule: their feet are half its height lower
	var shape := (p.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	return p.global_position.y - shape.height / 2.0


func _settle() -> void:
	await _physics(40)


func _steer(want: Vector3) -> void:
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
