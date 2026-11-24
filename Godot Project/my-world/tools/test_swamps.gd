extends SceneTree

# Checks the two swamps (scripts/swamp.gd) and the Bog Wailers (scripts/bog_wailer.gd).
#   Lanternmoor's Mothmire: the moor's fence opens onto a causeway you really walk down to the Mire Edge; the swamp has
#   its own fence all round but for the way in; the murk slows you and splashes but is never deep enough to swim;
#   the boardwalk takes you to Reed Isle, its broken stretch you wade, Hut Isle, Glow Isle and the Mire Chest (once).
#   Dusk's Embrace's Poison Mire: the clearing's edge still goes round, the causeway leads out, stepping in the goo
#   bumps you and puts you back where you last stood safe, the stepping stones and log hold you, a Sinker Stone
#   wobbles then sinks, a vent's burp and a poison cloud bump you, the Bog Heart chest pays once and its bubble floats
#   you home. Every Bog Wailer stands on the bed, winds up before it calls, calls Mucklings (never more than its
#   limit), is stomped, bubbled and popped, and its Mucklings melt away with it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_swamps.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.swamps_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.swamps_test_backup.cfg"
const LANTERNMOOR := "res://scenes/portal_worlds/lanternmoor.tscn"
const DUSK := "res://scenes/scary_world/scary_world.tscn"
var S: GDScript    # loaded once the autoloads are up (they read Settings, Audio, Arsenal)
var W: GDScript
var D: GDScript

var failures := 0
var game: Node
var world: Node3D
var swamp: Node3D
var p: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(500.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _load(path: String) -> void:
	change_scene_to_file(path)
	await _frames(10)
	await _physics(10)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	swamp = world.get_node_or_null(S.NODE) as Node3D if world else null
	_wailers_on(false)                                   # (they get their own checks at the end)
	_dangers_on(false)                                   # (and the lurkers' Mucklings would chase her off the paths)


func _dangers_on(on: bool) -> void:
	var dz := swamp.get_node_or_null("Dangers") if swamp else null
	if dz:
		dz.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _wailers_on(on: bool) -> void:
	if swamp == null:
		return
	for w in (swamp.get("wailers") as Array):
		(w as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	S = load("res://scripts/swamp.gd")
	W = load("res://scripts/bog_wailer.gd")
	D = load("res://scripts/swamp_dangers.gd")
	game = root.get_node("Game")
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.set("no_damage", false)
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	await _lanternmoor()
	await _dusk()
	_finish()


# The Mothmire -------------------------------------------------------------------------------------------------------
func _lanternmoor() -> void:
	await _load(LANTERNMOOR)
	check(swamp != null and str(swamp.get("kind")) == "lanternmoor" and p != null, "Lanternmoor has its swamp, the Mothmire")
	if swamp == null or p == null:
		return
	var lay: Dictionary = S.layout("lanternmoor")
	var fence_left := world.find_children("Fence*", "StaticBody3D", true, false).filter(func(n: Node) -> bool:
		var q := (n as Node3D).global_position
		return not swamp.is_ancestor_of(n) and q.x > 40.0 and absf(q.z) < 4.0)
	check(fence_left.is_empty(), "the moor's fence is open where the causeway goes")
	check(world.find_children("Fence*", "StaticBody3D", true, false).size() >= 45, "...and still goes round everywhere else")
	_check_ring(lay)
	var edge: Vector3 = (swamp.get("islands") as Array)[0].at
	await _route("from the moor down the causeway to the Mire Edge", Vector3(32, 0, 0), [Vector3(44, 0, 0), Vector3(58, 0, 0), edge], 0.0)
	check(bool(swamp.get("arrived")), "arriving says hello (\"%s\")" % str(lay.hello))
	# Wading
	var water := swamp.get("water") as Node3D
	check(water != null and water.is_in_group("water"), "the murk is wading water")
	var isl: Array = swamp.get("islands")
	var wade := _water_spot(isl)
	p.global_position = wade + Vector3(0, 1.0, 0)
	await _settle()
	check(p.call("in_zone", "water"), "standing in the murk you're in it (feet %.2f, surface %.2f)" % [_feet(), S.SURFACE])
	check(not p.call("is_swimming"), "...and it's never deep enough to swim")
	check(_feet() < S.SURFACE and _feet() > S.BED - 0.1, "...your feet on the bed")
	var hp_before: int = game.hp
	await _physics(30)
	check(game.hp == hp_before, "the murk doesn't hurt")
	# The boardwalks: Mire Edge to Reed Isle, the broken stretch (wade), Hut Isle, Glow Isle
	var a: Vector3 = isl[0].at
	var b: Vector3 = isl[1].at
	var c: Vector3 = isl[2].at
	var d: Vector3 = isl[3].at
	var e: Vector3 = isl[int(lay.chest)].at
	await _route("along the boardwalk to Reed Isle", a, [a.lerp(b, 0.5), b], 0.0)
	var mid := b.lerp(c, 0.5)
	await _route("over the broken boardwalk (wading the gap) to Hut Isle", b, [mid, c], 0.0)
	await _route("on to Lantern Isle", c, [c.lerp(d, 0.5), d], 0.0)
	await _route("and on to Glow Isle", d, [d.lerp(e, 0.5), e], 0.0)
	var chest := swamp.get("chest") as Node3D
	var spot := chest.find_child("Chest Spot", true, false)
	var sp: int = game.sparkles
	var rem: int = root.get_node("Remnants").count
	check(str(spot.offer.call()) != "", "the Mire Chest offers \"%s\"" % str(spot.offer.call()))
	spot.act.call()
	check(game.sparkles == sp + int(lay.sparkles) and root.get_node("Remnants").count == rem + int(lay.remnants),
		"the Mire Chest pays %d sparkles and %d Remnant the first time" % [lay.sparkles, lay.remnants])
	check(str(spot.offer.call()) == "", "...and then it's open")
	await _load(LANTERNMOOR)
	spot = (swamp.get("chest") as Node3D).find_child("Chest Spot", true, false)
	sp = game.sparkles
	rem = root.get_node("Remnants").count
	spot.act.call()
	check(game.sparkles == sp + int(lay.again) and root.get_node("Remnants").count == rem, "next visit a few sparkles, no Remnants")
	spot = null
	# Frogs hop off
	var frogs: Array = swamp.get("frogs")
	check(frogs.size() >= 4, "%d frogs" % frogs.size())
	if frogs.size() > 0:
		var f: Node3D = frogs[0]
		var at := f.global_position
		p.global_position = at + Vector3(1.5, 1.0, 0)
		await _physics(40)
		check(f.global_position.distance_to(at) > 1.0, "a frog hops away when you come close")
	await _dangers(lay)
	await _wailers((lay.wailers as Array).size())


func _water_spot(isl: Array) -> Vector3:
	var c: Vector3 = swamp.get("centre")
	for k in 200:
		var a := k * 2.4
		var q := c + Vector3(cos(a), 0, sin(a)) * (4.0 + k * 0.1)
		var dry := false
		for i in isl:
			dry = dry or Vector2(q.x - i.at.x, q.z - i.at.z).length() < float(i.r) + 1.5
		for s in (swamp.get("stones") as Array):
			dry = dry or Vector2(q.x - s.x, q.z - s.z).length() < 2.0
		if not dry and _ground(q) < S.SURFACE - 0.3:
			return q
	return c


func _check_ring(lay: Dictionary) -> void:
	# Rays out from the middle all round: every one meets the swamp's fence, except towards the causeway
	var c: Vector3 = swamp.get("centre")
	var out: Vector3 = ((lay.gap_from as Vector3) - c).normalized()
	var open := 0
	var shut := 0
	var space := world.get_world_3d().direct_space_state
	for k in 72:
		var a := TAU * k / 72.0
		var d := Vector3(cos(a), 0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.5, 0), c + d * (float(lay.r) + 6.0) + Vector3(0, 1.5, 0))
		q.collide_with_areas = false
		var hits := []
		var ex: Array[RID] = [p.get_rid()]
		var hit_fence := false
		for t in 30:
			q.exclude = ex
			var h := space.intersect_ray(q)
			if h.is_empty():
				break
			if str((h.collider as Node).name).begins_with("WorldBounds"):
				hit_fence = true
				break
			ex.append((h.collider as CollisionObject3D).get_rid())
		var towards := absf(d.signed_angle_to(out, Vector3.UP)) < 0.12
		if towards:
			open += 0 if hit_fence else 1
		else:
			shut += 1 if hit_fence else 0
			if not hit_fence:
				print("      (no fence at angle %.2f)" % a)
	check(shut == 72 - _towards_count(out), "the swamp's fence goes all the way round (%d of %d)" % [shut, 72 - _towards_count(out)])
	check(open >= 1, "...but is open towards the causeway")


func _towards_count(out: Vector3) -> int:
	var n := 0
	for k in 72:
		var d := Vector3(cos(TAU * k / 72.0), 0, sin(TAU * k / 72.0))
		n += 1 if absf(d.signed_angle_to(out, Vector3.UP)) < 0.12 else 0
	return n


# The Poison Mire ------------------------------------------------------------------------------------------------------
func _dusk() -> void:
	await _load(DUSK)
	check(swamp != null and bool(swamp.get("poison")) and p != null, "Dusk's Embrace has its swamp, the Poison Mire")
	if swamp == null or p == null:
		return
	var lay: Dictionary = S.layout("dusk")
	var edge_node := world.find_child("Edge", false, false)
	check(edge_node != null and edge_node.get_child_count() >= 30, "the clearing's edge still goes round (%d)" % (edge_node.get_child_count() if edge_node else 0))
	_check_ring(lay)
	var isl: Array = swamp.get("islands")
	var edge: Vector3 = isl[0].at
	await _route("from the clearing through the trees and down the causeway to the Mire Edge", Vector3(-12, 0, 0),
		[Vector3(-26, 0, 0), Vector3(-50, 0, 0), edge], 0.0)
	# Poison bumps you back where you stood safe
	await _settle()
	game.hp = game.max_hp
	var safe: Vector3 = swamp.get("last_safe")
	check(Vector2(safe.x - edge.x, safe.z - edge.z).length() < float(isl[0].r) + 0.5, "standing on the Mire Edge, that's where you're safe")
	await _unhurt()
	var goo := _water_spot(isl)
	p.global_position = goo + Vector3(0, 1.0, 0)
	await _physics(60)
	check(int(swamp.get("bumps")) >= 1, "stepping in the poison bumps you")
	check(game.hp == game.max_hp - 1, "...by one (hp %d)" % game.hp)
	check(Vector2(p.global_position.x - edge.x, p.global_position.z - edge.z).length() < float(isl[0].r) + 0.5 and _feet() > -0.05,
		"...and puts you back on the Mire Edge")
	# The stepping stones and the log hold you
	var stones: Array = swamp.get("stones")
	var want_stones := 0
	var want_sinkers := 0
	for st in (lay.stones as Array):
		want_stones += str(st[2]).length()
		want_sinkers += str(st[2]).count("s")
	check(stones.size() == want_stones, "%d stepping stones" % stones.size())
	var on_all := true
	swamp.set("hazards", false)
	for s in stones:
		p.global_position = s + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(25)
		var ok_here: bool = p.is_on_floor() and absf(_feet() - S.STONE_TOP) < 0.15
		if not ok_here:
			print("      (stone at %s: feet %.2f, floor %s)" % [s, _feet(), p.is_on_floor()])
		on_all = on_all and ok_here
	check(on_all, "every stone holds you up out of the goo")
	swamp.set("hazards", true)
	# A real hop from the Mire Edge onto the first stone and the next
	game.hp = game.max_hp
	await _hop_path(edge, [stones[0], stones[1]], "hop from the Mire Edge onto the first stone and the second")
	var a: Vector3 = isl[1].at
	var b: Vector3 = isl[2].at
	await _route("across the log bridge from Stump Isle to Toadstool Isle", a, [a.lerp(b, 0.5), b], 0.0)
	# A Sinker Stone sinks under you
	var sinkers: Array = swamp.get("sinkers")
	check(sinkers.size() == want_sinkers, "%d Sinker Stones" % sinkers.size())
	var s0: Node3D = sinkers[0]
	p.global_position = b + Vector3(0, 1.0, 0)
	await _settle()
	var bumps: int = swamp.get("bumps")
	var top := s0.global_position + Vector3(0, 0.35, 0)
	p.global_position = top + Vector3(0, 1.0, 0)
	var wobbled := false
	for i in int((S.SINK_AFTER + 0.6) * 60.0):
		await physics_frame
		wobbled = wobbled or str(s0.get_meta("state")) == "wobble"
	check(wobbled, "a Sinker Stone wobbles a moment after you land on it")
	await _physics(int((S.SINK_WOBBLE + 0.8) * 60.0))
	check(int(swamp.get("bumps")) > bumps, "...then sinks, and the poison bumps you back")
	await _physics(int((S.SINK_DOWN + 1.2) * 60.0))
	check(str(s0.get_meta("state")) == "up" and absf(s0.position.y - float(s0.get_meta("rest_y"))) < 0.01, "...and comes back up")
	# A vent's burp and a cloud
	var vents: Array = swamp.get("vents")
	check(vents.size() == (lay.vents as Array).size(), "%d poison vents" % vents.size())
	game.hp = game.max_hp
	p.global_position = b + Vector3(0, 1.0, 0)
	await _settle()
	var v: Node3D = vents[1]
	var ends: Array = swamp.call("way", "logs", 0)
	var stand := _closest(ends[0], ends[1], v.global_position) + Vector3(0, 0.15, 0)
	check(_flat_d(stand, v.global_position) < 3.0, "a vent's burp reaches the log bridge (%.1f m from %s)" % [_flat_d(stand, v.global_position), v.name])
	p.global_position = stand + Vector3(0, 1.0, 0)
	await _settle()
	await _unhurt()
	game.hp = game.max_hp
	var hp0: int = game.hp
	swamp.call("burst_vent", v)
	await _physics(60)
	check(game.hp < hp0, "standing in a vent's burp ring bumps you (hp %d)" % game.hp)
	await _physics(90)
	game.hp = game.max_hp
	var cl: Node3D = (swamp.get("clouds") as Array)[0]
	p.global_position = cl.global_position + Vector3(0, 0.2, 0)
	await _physics(3)
	check(game.hp < game.max_hp, "walking into a poison cloud bumps you")
	await _physics(90)
	# The Bog Heart chest and the bubble home
	var heart: Vector3 = isl[int(lay.chest)].at
	p.global_position = heart + Vector3(0, 1.0, 0)
	await _settle()
	var chest := swamp.get("chest") as Node3D
	var spot := chest.find_child("Chest Spot", true, false)
	var ride := chest.find_child("Bubble Spot", true, false)
	check(str(ride.offer.call()) == "", "the bog bubble waits till the chest's open")
	var sp: int = game.sparkles
	var rem: int = root.get_node("Remnants").count
	spot.act.call()
	check(game.sparkles == sp + int(lay.sparkles) and root.get_node("Remnants").count == rem + int(lay.remnants),
		"the Bog Heart pays %d sparkles and %d Remnants the first time" % [lay.sparkles, lay.remnants])
	check(str(ride.offer.call()) != "", "...then the bubble offers \"%s\"" % str(ride.offer.call()))
	game.hp = game.max_hp
	ride.act.call()
	await _physics(int(4.5 * 60.0))
	await _settle()
	check(Vector2(p.global_position.x - edge.x, p.global_position.z - edge.z).length() < float(isl[0].r) and _feet() > -0.05 and game.hp == game.max_hp,
		"...and floats you home to the Mire Edge, over the goo, unhurt (at %s, hp %d)" % [p.global_position.snapped(Vector3.ONE * 0.1), game.hp])
	await _dangers(lay)
	await _wailers((lay.wailers as Array).size())


# What makes it hard: no rides, dead ends with a Muck Mimic, a sign that fibs, Snap Traps, Lurkers, the giant; and the
# Lookout Tree at the end -----------------------------------------------------------------------------------------------
func _dangers(lay: Dictionary) -> void:
	var dz := swamp.get_node_or_null("Dangers")
	check(dz != null, "the swamp has its dangers")
	_dangers_on(true)
	if dz == null:
		return
	var isl: Array = swamp.get("islands")
	var edge: Vector3 = isl[0].at
	# No rides
	p.global_position = edge + Vector3(0, 1.0, 0)
	await _settle()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	game.riding = true
	game.equipment_changed.emit()
	await _physics(5)
	check(not game.riding, "you're knocked off your ride in the swamp")
	game.toggle_skateboard()
	await _physics(2)
	check(not game.riding and game.ride_blocked() != "", "...and can't get back on (\"%s\")" % game.ride_blocked())
	p.global_position = edge + (edge - (swamp.get("centre") as Vector3)).normalized() * 60.0 + Vector3(0, 30, 0)
	await _physics(2)
	check(game.ride_blocked() == "", "...but you can ride outside it")
	p.global_position = edge + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	# Dead ends with a Muck Mimic
	var mimics: Array = dz.get("mimics")
	check(mimics.size() == (lay.decoys as Array).size(), "%d dead-end islands, each with a Muck Mimic" % mimics.size())
	for i in (lay.decoys as Array):
		check(_reaches(int(i)), "...%s is joined on by a way, so it's a real dead end" % isl[int(i)].name)
	var sign := dz.find_child("Fibbing Sign", true, false) as Node3D
	check(sign != null, "a sign points the wrong way")
	if mimics.size() > 0:
		var m: Node3D = mimics[0]
		p.global_position = m.global_position + Vector3(0, 1.0, 1.5)
		await _settle()
		await _unhurt()
		game.hp = game.max_hp
		var spot := m.find_child("Chest Spot", true, false)
		var before := _mucklings()
		check(str(spot.offer.call()) == "open the chest", "the Mimic looks like a chest (\"%s\")" % str(spot.offer.call()))
		spot.act.call()
		await _physics(10)
		check(game.hp == game.max_hp - 1 and _mucklings() == before + 2, "...but it bites (hp %d) and spits out 2 Mucklings" % game.hp)
		check(str(spot.offer.call()) == "", "...and it won't fall for it twice in a row")
		_clear_mucklings()
	# Snap Traps
	var traps: Array = dz.get("traps")
	check(traps.size() >= isl.size() - 3, "%d Snap Traps hidden in the reeds" % traps.size())
	if traps.size() > 0:
		var t: Node3D = traps[0]
		await _unhurt()
		game.hp = game.max_hp
		var snaps := int(dz.get("snaps"))
		p.global_position = t.global_position + Vector3(0.3, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(4)
		check(str(t.get_meta("state")) == "rattle" or str(t.get_meta("state")) == "shut", "stepping by one, it rattles first")
		await _physics(int((D.TRAP_TELL + 0.2) * 60.0))
		check(int(dz.get("snaps")) == snaps + 1 and game.hp == game.max_hp - 1, "...then SNAPS (a bump of 1, hp %d)" % game.hp)
		p.global_position = edge + Vector3(0, 1.0, 0)    # (step well away, or it'd rattle again as it opens)
		p.velocity = Vector3.ZERO
		await _physics(int((D.TRAP_SHUT + 1.2) * 60.0))
		check(str(t.get_meta("state")) == "open", "...and opens again a while later")
	# Lurkers
	var lurkers: Array = dz.get("lurkers")
	check(lurkers.size() >= 3, "%d Lurkers hide beside the ways" % lurkers.size())
	if lurkers.size() > 0:
		var l: Node3D = lurkers[0]
		var eyes := l.get_node("Eyes") as Node3D
		p.global_position = edge + Vector3(0, 1.0, 0)
		await _physics(3)
		check(not eyes.visible or _flat_d(edge, l.global_position) < D.LURK_SEEN, "...out of sight from far off")
		l.set_meta("again", 0.0)                       # (in case one already came out while we walked past)
		if l.has_meta("out"):
			l.remove_meta("out")
		var before := _mucklings()
		p.global_position = l.global_position + Vector3(2.5, 6.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(3)
		check(_mucklings() == before + 1, "...and one bursts out when you come close")
		p.global_position = edge + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _settle()
		_clear_mucklings()
	# The giant
	var giant := dz.get("giant") as Node3D
	check(giant != null and str(dz.get("giant_state")) == "sleep", "%s sleeps in the mud" % str(dz.get("giant_name")))
	if giant:
		var lair: Vector3 = dz.get("lair")
		var stand := _nearest_land(lair)
		check(_flat_d(stand, lair) < D.GIANT_WAKE, "...near enough an island to wake")
		p.global_position = stand + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(10)
		check(str(dz.get("giant_state")) == "wake", "...and wakes when you come near")
		await _physics(int(2.0 * 60.0))
		check(str(dz.get("giant_state")) == "chase", "...and comes after you")
		var g0 := _flat_d(giant.global_position, stand)
		await _physics(30)
		check(_flat_d(giant.global_position, stand) < g0, "...getting closer")
		var gulps := int(dz.get("gulps"))
		p.global_position = giant.global_position + Vector3(0.5, 2.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(3)
		check(int(dz.get("gulps")) == gulps + 1, "...and if it catches you, GULP")
		await _physics(int(4.6 * 60.0))
		await _settle()
		check(_flat_d(p.global_position, edge) < float(isl[0].r), "...it spits you back out at the Mire Edge")
		for i in 60 * 20:
			if str(dz.get("giant_state")) == "sleep":
				break
			await physics_frame
		check(str(dz.get("giant_state")) == "sleep", "...then wades home and goes back to sleep")
		# Giving up: wake it again and run off out of the swamp
		dz.set("_g_rest", 0.0)
		p.global_position = stand + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _physics(int(2.0 * 60.0))
		p.global_position = edge + (edge - (swamp.get("centre") as Vector3)).normalized() * 30.0 + Vector3(0, 30, 0)
		await _physics(5)
		check(str(dz.get("giant_state")) == "home", "...and it gives up if you get away")
		p.global_position = edge + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _settle()
	# The Lookout Tree, at the end
	var lk := swamp.get("lookout") as Node3D
	check(lk != null, "there's a Lookout Tree by the chest island")
	if lk:
		var foot: Vector3 = swamp.get("lookout_foot")
		var a0 := float(swamp.get("lookout_a0"))
		var mid_r: float = (S.LOOK_IN + S.LOOK_OUT) / 2.0
		var n: int = int(S.LOOK_TURNS * S.LOOK_STEPS)
		var stepa: float = TAU / S.LOOK_STEPS
		var pts: Array = []
		for j in range(1, n + 2):
			var a: float = a0 + (j + 0.5) * stepa
			pts.append(lk.global_position + Vector3(cos(a) * (mid_r + 0.15), 0, sin(a) * (mid_r + 0.15)))
		pts.append(swamp.get("lookout_top"))
		var sp: int = game.sparkles
		await _route("up the Lookout Tree's stair to the top, 14 m up", foot + Vector3(0, 1.4, 0), pts, S.LOOK_TOP, false)
		await _physics(5)
		check(bool(swamp.get("lookout_seen")) and game.sparkles == sp + 3, "...where you can see the whole swamp (✦ 3 the first time)")
		check(_feet() > S.LOOK_TOP - 0.5, "...higher than anything else in the swamp")
		p.global_position = edge + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		await _settle()
	game.hp = game.max_hp


func _hold_mucklings(w: Node, hold: bool) -> void:
	for m in (w.get("mucklings") as Array):
		if is_instance_valid(m):
			(m as Node).process_mode = Node.PROCESS_MODE_DISABLED if hold else Node.PROCESS_MODE_INHERIT


func _mucklings() -> int:
	return world.find_children("Muckling*", "CharacterBody3D", true, false).filter(func(m: Node) -> bool:
		return not bool(m.get("defeated"))).size()


func _clear_mucklings() -> void:
	for m in world.find_children("Muckling*", "CharacterBody3D", true, false):
		m.queue_free()


func _reaches(i: int) -> bool:
	for key in ["walks", "stones"]:
		for w in (S.layout(str(swamp.get("kind")))[key] as Array):
			if int(w[1]) == i or int(w[0]) == i:
				return true
	return false


func _nearest_land(q: Vector3) -> Vector3:
	var best: Vector3 = (swamp.get("islands") as Array)[0].at
	for i in (swamp.get("islands") as Array):
		var at: Vector3 = i.at
		var edge_at := at + (q - at) * Vector3(1, 0, 1)
		edge_at = at + (edge_at - at).normalized() * maxf(float(i.r) - 0.8, 0.0) if (edge_at - at).length() > 0.01 else at
		if _flat_d(edge_at, q) < _flat_d(best, q):
			best = edge_at
	return best


func _hop_path(start: Vector3, steps: Array, what: String) -> void:
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	var bumps: int = swamp.get("bumps")
	var ok := true
	for s in steps:
		var tgt: Vector3 = s
		var got := false
		var jumped := false
		for i in 240:
			await physics_frame
			var want := tgt - p.global_position
			want.y = 0.0
			if want.length() < 0.4 and p.is_on_floor():
				got = true
				break
			if not jumped and p.is_on_floor() and want.length() < 2.2:
				Input.action_press("jump")
				jumped = true
			elif jumped:
				Input.action_release("jump")
			_steer(want.normalized() * (1.0 if want.length() > 0.5 else 0.3))
		_release()
		Input.action_release("jump")
		await _physics(20)
		ok = ok and got and int(swamp.get("bumps")) == bumps
	check(ok, "you can %s without touching the goo" % what)


# The Bog Wailers -----------------------------------------------------------------------------------------------------
func _wailers(n: int) -> void:
	var ws: Array = swamp.get("wailers")
	check(ws.size() == n, "%d Bog Wailer%s in %s" % [ws.size(), "" if n == 1 else "s", swamp.get("lay").title])
	if ws.is_empty():
		return
	var all_floor := true
	for w in ws:
		all_floor = all_floor and (w as CharacterBody3D).is_on_floor()
	check(all_floor, "...standing on the swamp's bed")
	var w := ws[0] as CharacterBody3D
	# Far off it just wanders
	p.global_position = (swamp.get("lay").gap_from as Vector3) + Vector3(0, 1.0, 0)
	await _settle()
	_wailers_on(true)
	var start := w.global_position
	var calls0: int = w.get("calls")
	await _physics(180)
	check(int(w.get("calls")) == calls0, "far off, it doesn't call")
	check(w.global_position.distance_to(start) > 0.2 or float(w.get("_rest")) > 0.0, "it wanders slowly about")
	# Near, it winds up (its head swells), then calls up Mucklings
	game.hp = game.max_hp
	p.global_position = _near_wailer(w, 9.0)
	await _physics(4)
	w.set("_call_cd", 0.0)
	var seen := false
	for i in 120:
		await physics_frame
		if float(w.get("winding")) > 0.0:
			seen = true
			break
	check(seen, "when it hears you it winds up first")
	await _physics(int(W.WIND_UP * 60.0) + 10)
	var mk: Array = w.get("mucklings")
	check(int(w.get("calls")) >= 1 and mk.size() == int(w.get("call_count")), "then it wails and %d Mucklings come up (%d)" % [w.get("call_count"), mk.size()])
	var ok := true
	for m in mk:
		ok = ok and is_instance_valid(m) and int(m.get("damage")) == 1 and not bool(m.get("respawns"))
	check(ok, "...little ones: a bump of 1 and they don't come back")
	# They really come for you (they used to sink back where they came up and sit hidden under the murk)
	game.hp = game.max_hp
	var near_you := 0
	var risen := 0
	var round_you := 0
	for m in mk:
		if is_instance_valid(m) and (m as Node3D).global_position.distance_to(p.global_position) < W.NEAR_YOU + 2.6:
			round_you += 1
	await _physics(180)
	for m in mk:
		if not is_instance_valid(m) or bool(m.get("defeated")):
			continue
		var mm := m as Node3D
		if mm.global_position.distance_to(p.global_position) < 6.0:
			near_you += 1
		var lift := (mm.get_node("Visual") as Node3D).position.y
		if mm.global_position.y + lift > S.SURFACE - 0.35:
			risen += 1
	check(round_you >= 1, "...some come up right round you (%d)" % round_you)
	check(near_you >= 3, "...and the horde comes for you (%d of %d within 6 m after 3 s)" % [near_you, mk.size()])
	check(risen == mk.size(), "...wading with their bodies up out of the water, not hidden under it (%d)" % risen)
	for k in 3:
		w.set("_call_cd", 0.0)
		w.call("start_call")
		await _physics(int((W.WIND_UP + W.WAIL_TIME) * 60.0) + 10)
	mk = (w.get("mucklings") as Array).filter(func(m: Node) -> bool: return is_instance_valid(m) and not bool(m.get("defeated")))
	check(mk.size() <= W.MAX_MUCKLINGS and mk.size() >= 3, "it never has more than %d out at once (%d)" % [W.MAX_MUCKLINGS, mk.size()])
	# A bubble hits it; a stomp on its big head hits it
	var hp0: int = w.get("hp")
	w.call("shot", 1, w.global_position, Vector3.FORWARD)
	check(int(w.get("hp")) == hp0 - 1, "a bubble knocks a bit off it")
	await _physics(30)
	_hold_mucklings(w, true)                             # (a horde of them leaping at her would knock her off the stomp)
	p.global_position = w.global_position + Vector3(0, 4.5, 0)
	p.velocity = Vector3.ZERO
	var stomped := false
	for i in 90:
		await physics_frame
		if int(w.get("hp")) < hp0 - 1:
			stomped = true
			break
	check(stomped, "landing on its big head is a stomp")
	_hold_mucklings(w, false)
	await _physics(30)
	if not bool(w.get("defeated")):
		w.call("shot", 3, w.global_position, Vector3.FORWARD)
	await _physics(10)
	check(bool(w.get("defeated")), "three hits pop it")
	await _physics(10)
	var left := get_nodes_in_group("mucklings").filter(func(m: Node) -> bool:
		return is_instance_valid(m) and m.has_meta("wailer") and m.get_meta("wailer") == w and not bool(m.get("defeated")))
	check(left.is_empty(), "...and its Mucklings melt back into the mud")
	game.hp = game.max_hp


func _closest(a: Vector3, b: Vector3, q: Vector3) -> Vector3:
	var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
	return a.lerp(b, t)


func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _unhurt() -> void:
	# Wait out the blinking after a bump, so the next one counts
	for i in 240:
		if not p.call("is_invulnerable"):
			return
		await physics_frame


func _near_wailer(w: Node3D, d: float) -> Vector3:
	var isl: Array = swamp.get("islands")
	var best: Vector3 = isl[0].at
	var bd := 1e9
	for i in isl:
		var q: Vector3 = i.at
		var e := absf(q.distance_to(w.global_position) - d)
		if e < bd:
			bd = e
			best = q
	if best.distance_to(w.global_position) > float(w.get("hear")) - 1.0:
		best = w.global_position + (best - w.global_position).normalized() * d
	return Vector3(best.x, maxf(_ground(best), S.BED) + 1.0, best.z)


# Helpers -----------------------------------------------------------------------------------------------------------
func _ground(q: Vector3) -> float:
	var r := PhysicsRayQueryParameters3D.create(Vector3(q.x, 10.0, q.z), Vector3(q.x, -10.0, q.z))
	r.exclude = [p.get_rid()]
	r.collide_with_areas = false
	var h := world.get_world_3d().direct_space_state.intersect_ray(r)
	return (h.position as Vector3).y if not h.is_empty() else -100.0


func _route(what: String, start: Vector3, steps: Array, end_y: float, place := true) -> void:
	if place:
		p.global_position = Vector3(start.x, maxf(_ground(start), -1.0) + 1.0, start.z)
	else:
		p.global_position = start
	p.velocity = Vector3.ZERO
	await _settle()
	var bumps: int = swamp.get("bumps")
	swamp.set("hazards", false)                         # (just the walking here: the vents and clouds have their own checks)
	var wpi := 0
	var got := false
	for i in 60 * 60:
		await physics_frame
		game.hp = game.max_hp
		var want: Vector3 = steps[wpi] - p.global_position
		want.y = 0
		if want.length() < (0.45 if what.contains("Lookout") else 0.9):
			if wpi == steps.size() - 1:
				got = true
				break
			wpi += 1
		_steer(want.normalized())
	_release()
	await _physics(10)
	swamp.set("hazards", true)
	if not got:
		print("      (locks %s, carried %s, floating %s, vel %s)" % [p.call("input_locks"), p.get("carried"), swamp.get("_floating"), p.velocity])
		var to: Vector3 = (steps[wpi] - p.global_position) * Vector3(1, 0, 1)
		for hgt in [-0.7, -0.5, -0.3, 0.0, 0.5]:
			var r := PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, hgt, 0), p.global_position + Vector3(0, hgt, 0) + to.normalized() * 1.5)
			r.exclude = [p.get_rid()]
			var h := world.get_world_3d().direct_space_state.intersect_ray(r)
			print("      (blocked at %.1f: %s)" % [hgt, "" if h.is_empty() else "%s %s" % [(h.collider as Node).get_path(), h.position]])
	check(got and absf(_feet() - end_y) < 0.6 and int(swamp.get("bumps")) == bumps,
		"you can walk %s (step %d of %d, at %s)" % [what, wpi + 1, steps.size(), p.global_position.snapped(Vector3.ONE * 0.1)])


func _feet() -> float:
	var shape := (p.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	return p.global_position.y - shape.height / 2.0


func _settle() -> void:
	await _physics(40)


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
