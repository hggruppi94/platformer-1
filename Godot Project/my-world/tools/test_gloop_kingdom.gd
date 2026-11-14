extends SceneTree

# Checks the Gloop Kingdom, the Gloop King's own domain (scripts/gloop_kingdom.gd, scenes/bosses/gloop_kingdom.tscn,
# the Gloop Gate in scripts/bosses.gd). In town: the King's no longer in the west fields, and the Gloop Gate stands
# there on flat, dry, open ground, off the races, paths and trees, on the map. Its spot takes you in. In the kingdom:
# you face up the Bog Road, the bog's sticky (slow, never harmful), the moat's pads are each a hop from the last, and you
# can really walk from the way in to his court. The King sits still on his throne until you come into his court; then
# he's up and fighting, facing the way he goes, with ammo crates round the court; the court floods with goo (slow, a bump
# now and then) and the Lily Pads keep you out of it; twelve pops beat him (14 Nov 2026: was six), the Royal Treasure opens (once a visit) and a way home appears by
# the throne. The way home puts you back on the ground in front of the gate. Saving in there and loading comes back in.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_gloop_kingdom.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.kingdom_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.kingdom_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var bosses: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
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
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)

	# --- In town: the gate, and no King in the field ---
	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	check(town.find_child("The Gloop King", true, false) == null, "the Gloop King isn't out in the west fields any more")
	var gate := town.get_node_or_null("Gloop Gate") as Node3D
	check(gate != null, "the Gloop Gate stands in the west fields")
	if gate == null:
		_finish()
		return
	var at: Vector2 = bosses.GATE
	check(gate.is_in_group("map_landmarks") or gate.get("label") == "Gloop Kingdom", "...and it's on the map")
	# (the gate's own mound is solid, so it's set aside while the ground under it is measured)
	gate.get_parent().remove_child(gate)
	await _physics(2)
	var lo := INF
	var hi := -INF
	for k in 12:
		var a := TAU * k / 12.0
		for r in [0.0, 3.0, 6.0, 9.0]:
			var g: Vector3 = bosses.ground(town, at.x + cos(a) * r, at.y + sin(a) * r)
			lo = minf(lo, g.y)
			hi = maxf(hi, g.y)
	town.add_child(gate)
	await _physics(2)
	check(hi - lo < 1.0, "...on flat ground (%.2f m up and down within 9 m)" % (hi - lo))
	var wet := false
	for w in get_nodes_in_group("water"):
		for k in 8:
			var a3 := TAU * k / 8.0
			if w.has_method("covers") and w.covers(at.x + cos(a3) * 8.0, at.y + sin(a3) * 8.0):
				wet = true
	check(not wet, "...and dry")
	var races := root.get_node("Races")
	var hub: Vector2 = races.HUBS["void"].at
	check(at.distance_to(hub) > 30.0, "...well away from the race gate (%.0f m)" % at.distance_to(hub))
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a2 := Vector2(pa[0], pa[pa.size() - 1])
		var b2 := Vector2(pb[0], pb[pb.size() - 1])
		var kk := 0.0 if a2 == b2 else clampf((at - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
		path = minf(path, at.distance_to(a2.lerp(b2, kk)))
	check(path > 7.0, "...off the townsfolk's paths (%.1f m)" % path)
	var trees := town.find_child("Trees", true, false) as Node3D
	var tree := INF
	if trees:
		for tp in trees.get("positions"):
			var tg: Vector3 = trees.global_transform * tp
			tree = minf(tree, at.distance_to(Vector2(tg.x, tg.z)))
	check(tree > 8.0, "...with no tree growing through it (nearest %.1f m)" % tree)
	# Nothing solid in the way out in front of its mouth
	var out: Dictionary = bosses.gate_out()
	var outp: Vector3 = out.position
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
	var spot := gate.get_node_or_null("Gate Spot")
	check(spot != null and str(spot.offer.call()) == "go in to the Gloop Kingdom", "its mouth offers the way in")

	# --- In through the gate ---
	var p := town.find_child("Player", true, false) as CharacterBody3D
	p.global_position = gate.global_position + Vector3(bosses.GATE_RADIUS + 1.0, 0.5, 0)
	spot.act.call()
	await _frames(10)
	await _physics(6)
	var kd := current_scene as Node3D
	check(kd.scene_file_path == bosses.KINGDOM, "going in takes you to the Gloop Kingdom")
	p = kd.find_child("Player", true, false) as CharacterBody3D
	check(p.global_position.distance_to(Vector3(0, 1.0, 3.0)) < 1.5, "...standing at the start of the Bog Road")
	var face := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	check(face.z > 0.9, "...facing up the road, towards the palace")
	var king := kd.get_node_or_null("The Gloop King") as CharacterBody3D
	check(king != null and king.find_child("Crown", true, false) != null, "the King's there, in his crown")
	check(king.process_mode == Node.PROCESS_MODE_DISABLED and not kd.get("awake"), "...sat still on his throne")
	check(Vector2(king.global_position.x, king.global_position.z).distance_to(Vector2(0, 103)) < 2.0,
		"...right up at the top of his court")
	check(kd.find_children("Courtier *", "", true, false).size() == 10, "ten courtiers watch from the stands")
	var guards := kd.find_children("Gloop Guard *", "", true, false)
	check(guards.size() == 4, "four Royal Guards in gold helmets (%d)" % guards.size())
	check(kd.find_child("Bog", true, false) != null and str(kd.find_child("Bog", true, false).get("kind")) == "goo",
		"there's a sticky goo bog either side of the road")
	var rubbish := 0
	for e in get_nodes_in_group("enemies"):
		if str(e.name).begins_with("Courtier"):
			rubbish += 1
	check(rubbish == 0, "the courtiers are only watching (bubbles don't aim at them)")

	# The moat's pads are each a hop from the last
	var pads: Array = kd.get_node("Goo Moat").get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Goo Pad"))
	var hops_ok := pads.size() == 4
	var near_landing := Vector3(0, 0.4, 41.0)
	var prev := near_landing
	for pad in pads:
		var q: Vector3 = (pad as Node3D).position + Vector3(0, 0.25, 0)
		var gap := Vector2(q.x - prev.x, q.z - prev.z).length() - 1.4
		hops_ok = hops_ok and gap < 3.0 and q.y - prev.y < 1.0
		prev = q
	check(hops_ok, "the moat's four bouncy pads are each a short hop from the last")

	# The bog is slow going, but never hurts
	var hp: int = game.hp
	p.global_position = Vector3(-14, 0.6, 20)
	await _physics(12)
	var slow: float = p.call("_zone_min", "speed_scale", 1.0)
	check(slow < 0.6, "wading in the bog is slow going (x%.2f)" % slow)
	await _physics(30)
	check(game.hp == hp, "...and never hurts")

	# Really walk it: from the way in, up the road, over (or through) the moat, through the gate into his court
	# (the guards are held still for this: it's checking the way's open, not fighting them off)
	for g in guards:
		(g as Node).process_mode = Node.PROCESS_MODE_DISABLED
	p.global_position = Vector3(0, 1.0, 3.0)
	p.velocity = Vector3.ZERO
	await _physics(10)
	var reached := false
	var way := [Vector3(0, 0, 40), Vector3(-6, 0, 44), Vector3(-6, 0, 56), Vector3(0, 0, 60), Vector3(0, 0, 80)]
	var wp := 0
	for i in 60 * 50:
		await physics_frame
		if not is_instance_valid(p):
			print("(the scene changed to %s)" % current_scene.scene_file_path)
			break
		var want: Vector3 = way[wp] - p.global_position
		want.y = 0
		if want.length() < 1.0 and wp < way.size() - 1:
			wp += 1
		_steer(p, want.normalized())
		if p.global_position.z > 76.0:
			reached = true
			break
	_release()
	check(reached, "you can walk from the way in, wading the moat, up into his court (got to z %.1f)" % p.global_position.z)
	await _physics(20)
	check(kd.get("awake"), "coming into his court wakes him up")
	check(king.process_mode != Node.PROCESS_MODE_DISABLED, "...and he's up and moving")
	# He faces the way he goes (Hayden, 14 Nov 2026: he faced backwards when his fight started)
	check(absf(king.rotation.y) < 0.01, "his body isn't turned round (only his Visual turns, like every Gloop)")
	await _physics(90)
	var vis := king.get("visual") as Node3D
	var to_p := p.global_position - king.global_position
	to_p.y = 0.0
	var facing := vis.global_basis.z
	facing.y = 0.0
	check(facing.normalized().dot(to_p.normalized()) > 0.5,
		"...and he faces you as he comes after you (%.2f)" % facing.normalized().dot(to_p.normalized()))

	# --- Ammo crates round his court ---
	await _physics(2)
	var crates: Array = get_nodes_in_group("ammo_crates").filter(func(c: Node) -> bool: return c.has_meta("boss_supply"))
	check(crates.size() >= 3, "%d ammo crates round his court" % crates.size())
	check(crates.all(func(c: Node) -> bool:
		var cp := (c as Node3D).global_position
		return Vector2(cp.x, cp.z).distance_to(Vector2(0, 88)) < 18.0 and absf(cp.y) < 1.2), "...on the court floor")
	check(crates.all(func(c: Node) -> bool: return float(c.get("regrow")) > 0.0), "...and they come back after a pop")

	# --- The court floods with goo ---
	king.set_physics_process(false)
	var flood := kd.get_node("Slime Flood")
	check(flood.get("pads").size() >= 6, "the court has Lily Pads to climb onto")
	flood.set("_t", 0.0)
	await _physics(2)
	check(int(flood.get("state")) == 1, "the goo-falls warn you before a flood")
	flood.set("_t", 0.0)
	await _physics(2)
	flood.set("_t", 0.0)
	await _physics(2)
	check(int(flood.get("state")) == 3 and flood.call("is_flooded"), "...then the court fills with goo")
	p.global_position = Vector3(-6.0, 1.0, 84.0)
	p.velocity = Vector3.ZERO
	await _physics(4)
	check(p.call("in_zone", "water") and p.call("_zone_min", "speed_scale", 1.0) < 0.6, "in the goo you're slowed right down")
	await _physics(80)
	check(p.is_recovering(), "...and the goo gives you a bump")
	var pad: Vector3 = flood.call("nearest_pad", p.global_position)
	p.global_position = pad + Vector3(0, 1.05, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	check(p.is_on_floor() and not p.call("in_zone", "water"), "up on a Lily Pad you're out of it")
	king.set_physics_process(true)

	# --- The fight: he takes a lot more popping now ---
	king.set_physics_process(false)
	var sparkles: int = game.sparkles
	var need: int = king.get("stomps_to_defeat")
	check(need >= 12, "the King takes %d pops now (was 6)" % need)
	for i in need - 1:
		king.shot(1, king.global_position, Vector3.FORWARD)
	check(not king.defeated, "%d bubbles aren't enough for the King" % (need - 1))
	king.shot(1, king.global_position, Vector3.FORWARD)
	check(king.defeated, "...the last pops him")
	await _physics(4)
	check(int(flood.get("state")) == 4 or int(flood.get("state")) == 0, "popping him drains the goo")
	await _physics(4)
	check(kd.get("popped"), "popping him opens up the throne room")
	check(kd.get_node_or_null("Throne Way Out") != null, "...with a goo bubble home by the throne")
	var chest := kd.find_child("Royal Treasure", true, false) as Node3D
	var tspot: Node = null
	for c in chest.get_children():
		if c.get("act") is Callable:
			tspot = c
	check(tspot != null and str(tspot.offer.call()) == "open the Royal Treasure", "the Royal Treasure can be opened")
	tspot.act.call()
	var got: int = game.sparkles - sparkles
	check(got >= 12, "...for sparkles (%d)" % got)
	check(str(tspot.offer.call()) == "", "...once")
	check(not king.get("respawns"), "he stays popped for this visit")

	# --- Saving in there brings you back in ---
	game.hold_saves = false
	game.save_game()
	game.hold_saves = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(str(data.get("scene", "")) == bosses.KINGDOM, "saving in the kingdom saves you there")

	# --- Home through the bubble ---
	var home := kd.get_node("Throne Way Out")
	var hspot: Node = home.get_node("Home Spot")
	check(str(hspot.offer.call()) == "go home to the Void", "the bubble offers the way home")
	hspot.act.call()
	await _frames(10)
	await _physics(30)
	town = current_scene as Node3D
	check(town.scene_file_path == TOWN, "it takes you back to the Void")
	p = town.find_child("Player", true, false) as CharacterBody3D
	var g2: Vector3 = bosses.ground(town, outp.x, outp.z)
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(outp.x, outp.z)) < 1.5
		and absf(p.global_position.y - g2.y - 0.9) < 0.5 and p.is_on_floor(),
		"...standing on the ground in front of the Gloop Gate (%.1f m off the ground)" % (p.global_position.y - g2.y))
	check(town.find_child("The Gloop King", true, false) == null, "...and the King isn't out in the field")
	# The second visit the same day: he's back on his throne, but the treasure's empty
	spot = town.get_node("Gloop Gate").get_node("Gate Spot")
	spot.act.call()
	await _frames(10)
	await _physics(4)
	kd = current_scene as Node3D
	king = kd.get_node("The Gloop King") as CharacterBody3D
	check(not king.defeated and not kd.get("awake"), "next time in, he's back on his throne with all his goo")
	kd.call("wake")
	king.set_physics_process(false)
	for i in int(king.get("stomps_to_defeat")):
		king.shot(1, king.global_position, Vector3.FORWARD)
	await _physics(3)
	sparkles = game.sparkles
	chest = kd.find_child("Royal Treasure", true, false) as Node3D
	for c in chest.get_children():
		if c.get("act") is Callable:
			c.act.call()
	check(game.sparkles == sparkles, "...but the Royal Treasure's only full once a visit")
	_finish()


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
