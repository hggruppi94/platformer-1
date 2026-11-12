extends SceneTree

# Checks the Star Arena (scripts/arena.gd, scripts/arena_level.gd, scenes/bosses/arena.tscn) and its three bosses
# (scripts/glorp_mother.gd, scripts/big_buzz.gd, scripts/the_gloam.gd). In town: the Arena Gate stands at the foot of
# the castle hill on flat, dry, open ground, off the paths, races and trees and clear of the other places put in at play
# time; it's shut until The First Night's done, then takes you in. In the arena: you face in down the tunnel, the floor,
# hatches, spotlights, crowd, Blip and the Round Board are there, and you can walk in to the middle. Blip's menus start a
# round. Every challenge round really plays (enemies out of the hatches, pops counted, Glorp bits too, waves, the clock
# and running out of time, the lights down), the boss rounds are locked until their little ones' round is won, and each
# boss really fights (Mama Glorp's split-offs, Big Buzz only poppable fizzled out, the Gloam only in a spotlight). The
# Champion's Cup opens after all three and gives the Cup hat. Prizes the first time and smaller ones after, best times,
# stopping a round, saving and loading the records, fainting starting it over, and the way out.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_arena.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.arena_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.arena_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var arena: Node
var bosses: Node
var dialogue: Node


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
	arena = root.get_node("Arena")
	bosses = root.get_node("Bosses")
	dialogue = root.get_node("Dialogue")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	settings.no_damage = true
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	var quests := root.get_node("Quests")
	quests.reset()
	arena.reset()

	# --- In town: the gate ---
	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	var gate := town.get_node_or_null("Arena Gate") as Node3D
	check(gate != null, "the Arena Gate stands in the Void")
	if gate == null:
		_finish()
		return
	var at: Vector2 = arena.GATE
	check(Vector2(15, -150).distance_to(at) < 110.0, "...at the foot of the castle school's hill (%.0f m from its middle)" % Vector2(15, -150).distance_to(at))
	check(gate.get("label") == "Star Arena", "...and it's on the map")
	gate.get_parent().remove_child(gate)
	await _physics(2)
	var lo := INF
	var hi := -INF
	for k in 12:
		var a := TAU * k / 12.0
		for r in [0.0, 4.0, 8.0]:
			var g: Vector3 = bosses.ground(town, at.x + cos(a) * r, at.y + sin(a) * r)
			lo = minf(lo, g.y)
			hi = maxf(hi, g.y)
	check(hi - lo < 1.0, "...on flat ground (%.2f m up and down within 8 m)" % (hi - lo))
	var wet := false
	for w in get_nodes_in_group("water"):
		for k in 8:
			var a3 := TAU * k / 8.0
			if w.has_method("covers") and w.covers(at.x + cos(a3) * 9.0, at.y + sin(a3) * 9.0):
				wet = true
	check(not wet, "...and dry")
	# Nothing else solid where it stands (it was taken out for this)
	var space := town.get_world_3d().direct_space_state
	var sq := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(18, 6, 18)
	sq.shape = bs
	sq.transform = Transform3D(Basis(), Vector3(at.x, lo + 3.5, at.y))
	sq.collide_with_areas = false
	check(space.intersect_shape(sq, 4).is_empty(), "...with nothing else solid where it stands")
	town.add_child(gate)
	await _physics(2)
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a2 := Vector2(pa[0], pa[pa.size() - 1])
		var b2 := Vector2(pb[0], pb[pb.size() - 1])
		var kk := 0.0 if a2 == b2 else clampf((at - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
		path = minf(path, at.distance_to(a2.lerp(b2, kk)))
	check(path > 12.0, "...off the townsfolk's paths (%.1f m)" % path)
	var trees := town.find_child("Trees", true, false) as Node3D
	var tree := INF
	if trees:
		for tp in trees.get("positions"):
			var tg: Vector3 = trees.global_transform * tp
			tree = minf(tree, at.distance_to(Vector2(tg.x, tg.z)))
	check(tree > 9.0, "...with no tree growing through it (nearest %.1f m)" % tree)
	var races := root.get_node("Races")
	var race := INF
	for id in races.TRACKS:
		var t: Dictionary = races.TRACKS[id]
		if t.has("points"):
			for q in t.points:
				race = minf(race, at.distance_to(Vector2(q.x, q.z) if q is Vector3 else Vector2(q)))
	check(race > 14.0, "...well off the race tracks (%.0f m)" % race)
	var others := {"the Gloop Gate": bosses.GATE, "the Goblin Clockyard": bosses.CLOCKYARD, "Boulder Hollow": bosses.HOLLOW,
		"the Secret Garden's wall": Vector2(-74, -75.6), "the Glorp Meadow": root.get_node("Wilds").MEADOW}
	for w in root.get_node("Portals").WORLDS:
		others[str(w.name) + "'s portal"] = w.at
	var near_name := ""
	var near := INF
	for k in others:
		var d := at.distance_to(others[k])
		if d < near:
			near = d
			near_name = k
	check(near > 20.0, "...and clear of everything else put in at play time (nearest: %s, %.0f m)" % [near_name, near])
	var out: Dictionary = arena.gate_out()
	var outp: Vector3 = out.position
	var ground_out: Vector3 = bosses.ground(town, outp.x, outp.z)
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	sq.shape = cap
	sq.transform = Transform3D(Basis(), ground_out + Vector3(0, 1.1, 0))
	check(space.intersect_shape(sq, 4).is_empty(), "...and nothing solid where you come out in front of it")

	# Shut before The First Night's done
	var spot := gate.get_node_or_null("Gate Spot")
	check(spot != null and str(spot.offer.call()) == "read the sign", "before The First Night's done it's shut: just a sign")
	check(str((gate.get_node("Gate Sign") as Label3D).text).contains("Opening soon"), "...that says it's opening soon")
	spot.act.call()
	await _frames(6)
	check(current_scene.scene_file_path == TOWN, "...and it doesn't let you in")

	# Opened
	quests.state["first_night"] = {"step": 99, "since_day": 1, "done": true}
	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	town = current_scene as Node3D
	gate = town.get_node("Arena Gate") as Node3D
	spot = gate.get_node("Gate Spot")
	check(str(spot.offer.call()) == "go in to the Star Arena", "after The First Night it offers the way in")
	spot.act.call()
	await _frames(10)
	await _physics(6)
	var lv := current_scene as Node3D
	check(lv.scene_file_path == arena.LEVEL, "going in takes you to the Star Arena")
	var p := lv.find_child("Player", true, false) as CharacterBody3D
	check(p.global_position.distance_to(Vector3(0, 1.0, lv.TUNNEL_END - 4.0)) < 1.5, "...standing at the end of the tunnel")
	var face := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	check(face.z < -0.9, "...facing in towards the floor")
	check(lv.find_child("Hatches", true, false).get_child_count() == 6, "six hatches round the floor")
	check(lv.find_children("Spotlight Tower *", "", true, false).size() == 4, "four spotlight towers")
	check(lv.find_children("Fan *", "", true, false).size() >= 20, "little aliens fill the stands (%d)" % lv.find_children("Fan *", "", true, false).size())
	check(lv.find_child("Blip", true, false) != null and lv.find_child("Round Board", true, false) != null, "Blip and the Round Board are by the tunnel")
	check(not bool((lv.find_child("Gate Bar", true, false).get_child(0) as CollisionShape3D).disabled) == false, "the tunnel's open when no round's on")

	# Really walk in, down the tunnel to the middle of the floor
	await _physics(10)
	var reached := false
	for i in 60 * 20:
		await physics_frame
		var want: Vector3 = Vector3(0, 0, 4) - p.global_position
		want.y = 0
		_steer(p, want.normalized())
		if p.global_position.z < 6.0:
			reached = true
			break
	_release()
	check(reached, "you can walk down the tunnel onto the floor (got to z %.1f)" % p.global_position.z)

	# Talking to Blip: the menus
	check(not arena.is_open("mama_glorp") and not arena.is_open("cup"), "boss rounds are locked to begin with")
	p.global_position = lv.HOST_AT + Vector3(0, 1.0, 1.4)
	await _physics(4)
	await _talk(lv, [0, 0])                                # "A challenge round!" -> "Pop 100 Gloops"
	await _physics(4)
	check(lv.round_id == "gloops", "Blip's menus start a round (picked: Pop 100 Gloops)")
	check(dialogue.choice_log.filter(func(e: Dictionary) -> bool: return str(e.get("what", "")) == "arena_pick").is_empty(),
		"...and the menu picks aren't kept in the choice log")
	check(not bool((lv.find_child("Gate Bar", true, false).get_child(0) as CollisionShape3D).disabled), "a bar of light shuts the tunnel during a round")
	await create_timer(3.4).timeout
	await _physics(4)
	check(lv.alive() == 10, "ten Gloops come out of the hatches (%d)" % lv.alive())
	var on_floor := true
	for e in lv._live:
		var e3 := e as Node3D
		on_floor = on_floor and Vector2(e3.global_position.x, e3.global_position.z).length() < lv.FLOOR_R
	check(on_floor, "...all on the floor")

	# --- Pop 100 Gloops ---
	var sparkles: int = game.sparkles
	var remn: int = root.get_node("Remnants").count
	var popped := await _pop_all(lv, "gloops", 100)
	check(popped, "popping them, the count goes up to 100 and the round's won (%d)" % lv.count)
	check(arena.wins("gloops") == 1 and arena.best("gloops") > 0.0, "...it's on the record, with a best time (%.1f s)" % arena.best("gloops"))
	check(game.sparkles == sparkles + 20 and root.get_node("Remnants").count == remn + 2, "...first-win prize: 20 sparkles and 2 Remnants")
	check(dialogue.flags.has("arena_won_gloops"), "...and a flag for it")
	await _physics(4)
	check(lv.round_id == "" and lv.alive() == 0, "the round's over and the floor's clear")
	check(bool((lv.find_child("Gate Bar", true, false).get_child(0) as CollisionShape3D).disabled), "...and the tunnel's open again")
	check(str((lv.find_child("Board Text", true, false) as Label3D).text).contains("★ Pop 100 Gloops"), "the Round Board shows it won")
	sparkles = game.sparkles
	lv.start_round("gloops")
	await create_timer(3.4).timeout
	await _pop_all(lv, "gloops", 100)
	check(game.sparkles == sparkles + 5, "winning it again pays the smaller prize (5 sparkles)")

	# --- Glorp Splitter: bits count ---
	lv.start_round("glorps")
	await create_timer(3.4).timeout
	await _physics(2)
	var first: Node = lv._live[0]
	first.call("shot", 1, Vector3.ZERO, Vector3(1, 0, 0))
	await _physics(6)
	var bits: Array = lv._live.filter(func(n: Node) -> bool: return str(n.name).begins_with("Glorp Bit"))
	check(lv.count == 1 and bits.size() == 2, "a popped Glorp splits into two bits that join the round (%d)" % bits.size())
	check(absf(float(bits[0].get("size")) - 0.99) < 0.01 if bits.size() > 0 else false, "...each two-thirds its size")
	popped = await _pop_all(lv, "glorps", 40)
	check(popped and arena.wins("glorps") == 1, "pop 40 Glorp bits and the round's won")
	check(arena.is_open("mama_glorp"), "...which opens Mama Glorp's boss round")

	# --- Goblin Waves ---
	lv.start_round("goblins")
	await create_timer(3.4).timeout
	await _physics(2)
	check(lv.alive() == 4 and lv.wave == 1, "Goblin Waves: the first wave is 4 Time Goblins")
	for e in lv._live.duplicate():
		e.call("_defeat")
	await _physics(4)
	check(lv.alive() == 0 and lv.round_id == "goblins", "...pop them and there's a breather")
	await create_timer(2.3).timeout
	await _physics(2)
	check(lv.alive() == 6 and lv.wave == 2, "...then a wave of 6")
	popped = await _pop_all(lv, "goblins", 18, true)
	check(popped and arena.wins("goblins") == 1, "...then 8, and the round's won")

	# --- Fizzler Frenzy: the clock ---
	lv.start_round("fizzlers")
	await create_timer(3.4).timeout
	await _physics(2)
	check(lv.alive() == 6 and lv._live[0].is_in_group("fizzlers"), "Fizzler Frenzy: six Fizzlers out at a time")
	check(str(lv._hud_count.text).contains("⏱"), "...with a clock on the HUD")
	lv.time_left = 0.05
	await _physics(6)
	check(lv.round_id == "" and arena.wins("fizzlers") == 0 and lv.alive() == 0, "running out of time ends the round, no win")
	lv.start_round("fizzlers")
	await create_timer(3.4).timeout
	popped = await _pop_all(lv, "fizzlers", 25)
	check(popped and arena.wins("fizzlers") == 1 and arena.is_open("big_buzz"), "pop 25 in time and it's won, opening Big Buzz")

	# --- Shadow Night: the lights go down ---
	lv.start_round("shadows")
	check(lv.dark and not (lv.find_child("Floodlight", true, false) as Light3D).visible, "Shadow Night brings the lights down")
	await create_timer(3.4).timeout
	popped = await _pop_all(lv, "shadows", 20)
	check(popped and arena.wins("shadows") == 1 and not lv.dark, "pop 20 shadow ghosts and it's won (and the lights come back)")
	check(arena.is_open("gloam") and not arena.is_open("cup"), "...opening the Gloam (the Cup still waits for all three bosses)")

	# --- Mama Glorp ---
	lv.start_round("mama_glorp")
	await create_timer(3.4).timeout
	await _physics(4)
	var mama := lv.boss as CharacterBody3D
	check(mama != null and str(mama.name) == "Mama Glorp" and mama.find_child("Bow", true, false) != null, "Mama Glorp comes out, with her bow")
	check(absf(float(mama.get("size")) - 2.6) < 0.01, "...the biggest Glorp there is")
	for h in 3:
		mama.call("shot", 1, mama.global_position, Vector3(1, 0, 0))
		await _physics(3)
	check(int(mama.get("babies")) == 3, "every hit splits a Glorp off her (%d)" % int(mama.get("babies")))
	check(lv.alive() >= 3, "...and they're in the round (%d)" % lv.alive())
	for h in 6:
		mama.call("shot", 1, mama.global_position, Vector3(1, 0, 0))
		await _physics(3)
	await create_timer(2.4).timeout
	await _physics(2)
	check(arena.wins("mama_glorp") == 1 and lv.round_id == "", "nine hits pop her and the boss round's won")

	# --- Big Buzz ---
	lv.start_round("big_buzz")
	await create_timer(3.4).timeout
	await _physics(4)
	var buzz := lv.boss as CharacterBody3D
	check(buzz != null and str(buzz.name) == "Big Buzz", "Big Buzz comes out")
	await _physics(20)
	check(buzz.global_position.y > 2.0, "...floating high, out of reach (%.1f m)" % buzz.global_position.y)
	check(str(buzz.call("shot", 1, buzz.global_position, Vector3(1, 0, 0))) == "miss" and int(buzz.get("hits")) == 0,
		"...bubbles fizzle off him while he's up")
	var rings_before := lv.find_children("ShockRing", "", true, false).size()
	buzz.set("_state_t", 0.0)
	var dazed := false
	for i in 120:
		await physics_frame
		if int(buzz.get("state")) == 2:
			dazed = true
			break
	check(dazed, "he dives down and slams...")
	check(lv.find_children("ShockRing", "", true, false).size() > rings_before, "...sending a ring of static to jump")
	check(buzz.global_position.y < 1.0, "...then sits fizzled out, low enough to stomp (%.1f m)" % buzz.global_position.y)
	for h in 4:
		buzz.call("shot", 1, buzz.global_position, Vector3(1, 0, 0))
	check(int(buzz.get("hits")) == 3, "...when bubbles count, three at most each time (%d)" % int(buzz.get("hits")))
	await _physics(4)
	check(int(buzz.get("state")) != 2, "...then he blinks away and floats up again")
	check(lv.find_children("Buzz Fizzler", "", true, false).size() >= 1 or lv.alive() >= 3, "at 3 hits he lets off Fizzlers")
	for round in 2:
		buzz.set("state", 0)
		buzz.set("_state_t", 0.0)
		for i in 120:
			await physics_frame
			if int(buzz.get("state")) == 2:
				break
		for h in 3:
			buzz.call("shot", 1, buzz.global_position, Vector3(1, 0, 0))
		await _physics(3)
	await create_timer(2.4).timeout
	await _physics(2)
	check(arena.wins("big_buzz") == 1 and lv.round_id == "", "nine hits pop Big Buzz and it's won")

	# --- The Gloam ---
	lv.start_round("gloam")
	check(lv.dark, "the Gloam's round is in the dark")
	await create_timer(3.4).timeout
	await _physics(4)
	var gloam := lv.boss as CharacterBody3D
	check(gloam != null and str(gloam.name) == "The Gloam", "the Gloam comes out")
	# Keep it out of the beams to start with
	var dark_spot := Vector3.ZERO
	for tries in 40:
		var cand := Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
		if not lv.lit_at(cand + Vector3(0, 3, 0)):
			var ok := true
			for i in 4:
				ok = ok and Vector2(cand.x - lv.beam_at(i).x, cand.z - lv.beam_at(i).z).length() > lv.BEAM_R + 2.0
			if ok:
				dark_spot = cand
				break
	gloam.global_position = Vector3(dark_spot.x, gloam.global_position.y, dark_spot.z)
	await _physics(2)
	check(not bool(gloam.get("lit")) and str(gloam.call("shot", 1, gloam.global_position, Vector3(1, 0, 0))) == "miss",
		"in the dark bubbles go right through it")
	var push: Vector3 = lv.beam_push(lv.beam_at(0) + Vector3(lv.BEAM_R + 0.5, 0, 0))
	check(push.x > 0.0, "it steers away from a beam it's close to")
	var hit_ok := true
	for h in 8:
		gloam.set("_retreat", 0.0)
		var b: Vector3 = lv.beam_at(h % 4)
		gloam.global_position = Vector3(b.x, gloam.global_position.y, b.z)
		await _physics(2)
		if h == 0:
			check(bool(gloam.get("lit")), "caught in a spotlight it goes pale and solid")
		hit_ok = hit_ok and str(gloam.call("shot", 1, gloam.global_position, Vector3(1, 0, 0))) == "hit"
	check(hit_ok, "...and every bubble in the light counts")
	await create_timer(2.4).timeout
	await _physics(2)
	check(arena.wins("gloam") == 1 and lv.round_id == "" and not lv.dark, "eight hits pop the Gloam, it's won and the lights come back")

	# --- The Champion's Cup ---
	check(arena.is_open("cup"), "the Champion's Cup opens once all three bosses are beaten")
	lv.start_round("cup")
	await create_timer(3.4).timeout
	var order: Array[String] = []
	for b in 3:
		var waited := 0
		while (lv.boss == null or not is_instance_valid(lv.boss) or bool(lv.boss.get("defeated"))) and waited < 600:
			await physics_frame
			waited += 1
		var bb := lv.boss as Node3D
		if bb == null:
			break
		order.append(str(bb.name))
		match str(bb.name):
			"Mama Glorp":
				for h in 9:
					bb.call("shot", 1, bb.global_position, Vector3(1, 0, 0))
			"Big Buzz":
				bb.call("hurt", 9)
			"The Gloam":
				check(lv.dark, "...the lights go down for the Gloam")
				for h in 8:
					bb.set("_retreat", 0.0)
					bb.call("hurt", 1, Vector3(1, 0, 0))
		await _physics(4)
	await create_timer(2.6).timeout
	await _physics(2)
	check(order == ["Mama Glorp", "Big Buzz", "The Gloam"], "the Cup is all three, one after another (%s)" % ", ".join(order))
	check(arena.wins("cup") == 1 and game.has_item("shop:champion_cup"), "...and winning it gives the Champion's Cup to wear")
	check(arena.medals() == arena.CHALLENGES.size(), "every round won: %d medals" % arena.medals())

	# --- Stopping a round, and fainting ---
	lv.start_round("gloops")
	await create_timer(3.4).timeout
	p.global_position = lv.HOST_AT + Vector3(0, 1.0, 1.4)
	await _physics(4)
	await _talk(lv, [0])                                   # "Stop the round."
	await _physics(4)
	check(lv.round_id == "" and lv.alive() == 0, "talking to Blip mid-round can stop it")
	lv.start_round("gloops")
	await create_timer(3.4).timeout
	game.faint()
	await _frames(10)
	await _physics(4)
	lv = current_scene as Node3D
	check(lv.scene_file_path == arena.LEVEL and lv.round_id == "" and lv.alive() == 0, "fainting starts the arena over, no round on")

	# --- Saving and loading the records ---
	var data: Dictionary = arena.save_data()
	arena.reset()
	check(arena.wins("gloops") == 0, "(reset clears the records)")
	arena.load_data(data)
	check(arena.wins("gloops") == 2 and arena.wins("cup") == 1 and arena.best("gloops") > 0.0, "the records save and load")
	arena.load_data({"records": {"gloops": "rubbish", "cup": {"wins": -3}}})
	check(arena.wins("gloops") == 0 and arena.wins("cup") == 0, "...and odd ones are ignored")
	arena.load_data(data)

	# --- The way out ---
	var way := lv.get_node_or_null("Way Out")
	check(way != null and str(way.offer.call()) == "go back out to the Void", "the end of the tunnel is the way out")
	way.act.call()
	await _frames(12)
	await _physics(10)
	town = current_scene as Node3D
	check(town.scene_file_path == TOWN, "...back to the Void")
	p = town.find_child("Player", true, false) as CharacterBody3D
	var o: Vector3 = arena.gate_out().position
	var gnd: Vector3 = bosses.ground(town, o.x, o.z)
	check(Vector2(p.global_position.x - o.x, p.global_position.z - o.z).length() < 1.5 and absf(p.global_position.y - 1.0 - gnd.y) < 1.0,
		"...standing on the ground in front of the Arena Gate")
	_finish()


func _pop_all(lv: Node, id: String, goal: int, defeat := false) -> bool:
	# Pop everything that comes out until the round's won (a bubble each, like the Star Popper; goblins with a stomp,
	# since they blink away from bubbles)
	for i in 60 * 120:
		if lv.round_id != id:
			return true
		for e in lv._live.duplicate():
			if is_instance_valid(e) and not bool(e.get("defeated")):
				if defeat and e.has_method("_defeat"):
					e.call("_defeat")
				elif e.has_method("pop"):
					e.call("pop", true)
				else:
					e.call("shot", 3, (e as Node3D).global_position, Vector3(1, 0, 0))
		await physics_frame
	return lv.round_id != id and lv.count >= goal


func _talk(lv: Node, picks: Array) -> void:
	# Talk to Blip and pick from each menu in turn
	lv.talk()
	await _frames(2)
	var guard := 600
	var k := 0
	while guard > 0:
		guard -= 1
		if not dialogue.is_active():
			await _frames(3)
			if not dialogue.is_active():
				break
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks[mini(k, picks.size() - 1)]
			k += 1
			buttons[mini(pick, buttons.size() - 1)].grab_focus()
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


func _steer(p: CharacterBody3D, want: Vector3) -> void:
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
	root.get_node("Settings").no_damage = false
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
