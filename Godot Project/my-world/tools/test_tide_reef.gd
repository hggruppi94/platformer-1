extends SceneTree

# Checks the Tide Reef, Otto the octopus's portal world (scripts/tide_reef.gd, scripts/riptide_gloop.gd,
# scenes/portal_worlds/tide_reef.tscn): its quake waits for Rhythm Springs to be mended, then its portal rises by the
# lake's south-east shore on flat, clear ground; inside, the tide's out (dry pools, pale corals) and Otto waits by the way
# in; nothing only he can do works until you've met him, and then his bubble follows you; his eight arms open the Clam
# Vault; in the Kelp Grotto a wrong hole finds junk and the one with the glint finds the pearl; his bubble steps go up
# the Coral Spire in easy hops, pop after you stand on one and come back; the pearl on top is yours and a bubble
# carries you down; the Riptide Gloop sleeps until all three pearls are found, then wakes when you come near; it's too
# slippery to pop until Otto holds it; its riptide drags you along the ground; popping it mends the world (the tide
# comes in, the pools fill, the corals bloom, Otto's proud); slice two: Otto teaches you to swim and the sea floods
# right over the reef, you can't walk along the bottom before then (only paddle), you swim up and dive, float where you
# stop, hop out at the top, the view goes blue and muffled under, the five sea lanterns light when you swim to them
# and then the Reef Chest pays out once; and it all stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_tide_reef.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.tide_reef_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tide_reef_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/tide_reef.tscn"

var failures := 0
var game: Node
var portals: Node
var rem: Node
var quests: Node
var clock: Node


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
	portals = root.get_node("Portals")
	rem = root.get_node("Remnants")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.cleared_worlds.append(w)

	check(ResourceLoader.exists(WORLD) and portals.is_built("tide_reef"), "the Tide Reef's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_otto()
	await _check_vault()
	await _check_grotto()
	await _check_spire()
	await _check_riptide()
	await _check_mended()
	await _check_swim()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("tide_reef"), "no Tide Reef quake before Glenmoor is mended")
	portals.cleared_worlds.append("glenmoor")
	check(portals.next_due() == "tide_reef", "then its quake is due")
	portals.quake("tide_reef", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal tide_reef") as Node3D
	check(p != null and portals.is_open("tide_reef"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("tide_reef")
	var ground: Vector3 = rem.ground_at(w.at)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	check(w.at.x > 40.0 and w.at.y > 17.0 and w.at.y < 36.0, "...by the lake's south-east shore (%s)" % w.at)
	var worst := 0.0
	for k in 12:
		var a := k * TAU / 12.0
		worst = maxf(worst, absf(rem.ground_at(w.at + Vector2(cos(a), sin(a)) * 5.5).y - ground.y))
	check(worst < 0.4, "...on flat ground (worst step %.2f)" % worst)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	q.shape = sphere
	q.transform = Transform3D(Basis(), p.global_position + Vector3(0, 3.5, 0))
	var others := space.intersect_shape(q, 16).filter(func(h: Dictionary) -> bool:
		var c: Node = h.collider
		return not p.is_ancestor_of(c) and not c.is_in_group("player"))
	check(others.is_empty(), "nothing else stands in the portal's way (%d)" % others.size())
	# Well off every race's track on the ground (their props go in at play time, but the tracks themselves have none)
	var nearest := INF
	var tracks: Dictionary = root.get_node("Races").TRACKS
	for id in tracks:
		var t: Dictionary = tracks[id]
		if t.get("sky", false) or str(t.get("scene", TOWN)) != TOWN:
			continue
		var line: Array = t.points
		for i in line.size():
			var a: Vector2 = line[i]
			var b: Vector2 = line[(i + 1) % line.size()]
			var k := clampf((w.at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			nearest = minf(nearest, w.at.distance_to(a.lerp(b, k)))
	check(nearest > 8.0, "...well off the race tracks (%.1f m)" % nearest)
	# ...and off the paths the townsfolk walk (routines/places.json), so nobody strolls through it
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a := Vector2(pa[0], pa[pa.size() - 1])
		var b := Vector2(pb[0], pb[pb.size() - 1])
		var k := 0.0 if a == b else clampf((w.at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		path = minf(path, w.at.distance_to(a.lerp(b, k)))
	check(path > 6.0, "...and off the townsfolk's paths (%.1f m)" % path)
	# ...and no tree grows through it (scenes/town/trees.gd: they have nothing solid, so the shape check can't see them)
	var trees := current_scene.find_child("Trees", true, false) as Node3D
	var tree := INF
	if trees:
		for tp in trees.get("positions"):
			var g: Vector3 = trees.global_transform * tp
			tree = minf(tree, w.at.distance_to(Vector2(g.x, g.z)))
	check(tree > 6.0, "...with no tree growing through it (nearest %.1f m)" % tree)
	var apart := INF
	for o in portals.WORLDS:
		if o.id != "tide_reef" and portals.is_built(o.id):
			apart = minf(apart, w.at.distance_to(o.at))
	check(apart > 20.0, "...and well apart from the other portals (%.0f m)" % apart)
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot(-w.at.normalized()) > 0.8, "...facing back towards the lake and town")
	check(portals._portal_offer("tide_reef") == "step through to The Tide Reef", "it offers a trip to the Tide Reef (%s)" % portals._portal_offer("tide_reef"))


func _check_inside() -> void:
	portals.enter("tide_reef")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "tide_reef", "stepping through takes you to the Tide Reef")
	var names := ["WayHome/Way Home/Spot", "TimeStone/Time Stone/Spot", "Vein1/Remnant Vein/Spot", "Otto the Octopus/Model",
		"Otto the Octopus/Spot", "Vault/Spot", "Clam Vault/Lid", "BubblePad/Spot", "Pearl3/Tide Pearl", "RideTop/Spot",
		"BubbleRide", "The Riptide Gloop", "RiptideGloop/Snoring", "RiptideGloop/Spot", "Tide Pools", "Sea Life", "Corals",
		"Coral Spire", "Kelp Grotto", "Deep Basin", "OttoPerch"]
	for i in 8:
		names.append("Clam Vault/Latch%d" % (i + 1))
		names.append("Step%d/Bubble" % (i + 1))
	for i in 3:
		names.append("Hole%d/Spot" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "the Tide Reef has %s" % n)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["TimeStone", "WayHome", "Vein1", "Otto", "Vault", "Hole1", "Hole2", "Hole3", "BubblePad", "Pearl3", "RideTop", "OttoPerch", "RiptideGloop"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.4, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	# The tide's out
	check(s.tide == 0.0 and not s.is_mended(), "the tide's stuck out")
	var pool := (s.get_node("Tide2") as Node3D).global_position
	check(not s.in_tide_pool(pool + Vector3(0, 0.9, 0)), "...so the tide pools are dry")
	check((s.get_node("Tide Pools/Pool2/Cracks") as Node3D).visible and not (s.get_node("Tide Pools/Pool2/Surface") as Node3D).visible,
		"...cracked, with no water in them")
	check(not (s.get_node("Sea Life") as Node3D).visible, "...no bubbles or fish")
	var faded: bool = s._corals.size() > 0
	for c in s._corals:
		var full: Color = c[1]
		faded = faded and (c[0] as StandardMaterial3D).albedo_color.is_equal_approx(s.pale(full))
	check(faded, "...and the corals have gone pale (%d colours)" % s._corals.size())
	check((s.riptide as Node).process_mode == Node.PROCESS_MODE_DISABLED and not s.riptide_awake, "the Riptide Gloop's fast asleep in the Deep Basin")


func _check_otto() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var home: Vector3 = s.otto_at()
	check(not s.met_otto(), "you haven't met Otto yet")
	# Nothing only he can do works without him
	check(s.get_node("Vault/Spot").what() == "look at the Clam Vault", "before you've met him the Clam Vault is only something to look at")
	s.open_vault()
	check(not s.vault_open(), "...and it won't open")
	check(not s.try_hole(s.right_hole) and not s.has_pearl(1), "...the grotto's pearl is too deep to reach")
	s.blow_steps()
	check(not s.steps_up, "...and there are no steps up the spire")
	# Wander off: he stays where the tide left him
	player.global_position = Vector3(-14, 0.9, 10)
	await _frames(40)
	check(s.otto_at().distance_to(home) < 0.3, "Otto can't get anywhere by himself: he stays put")
	# Say hello
	player.global_position = home + Vector3(0, 0.9, 2.2)
	await _physics(6)
	var spot := s.get_node("Otto the Octopus/Spot")
	check(spot.what() == "talk to Otto", "Otto offers a talk")
	spot.use()
	await _frames(2)
	var dialogue := root.get_node("Dialogue")
	check(dialogue.is_active() and s.met_otto(), "he says hello (and that he's no use)")
	dialogue.end()
	await _frames(2)
	var later: Array = s.otto_lines()
	check("Still to find" in " ".join(later) and "Clam Vault" in " ".join(later), "after that he says what's left to find")
	# Now his bubble comes along
	player.global_position = Vector3(-14, 0.9, 10)
	var t := 0
	while not s.otto_near(player.global_position, 3.6) and t < 600:
		await process_frame
		t += 1
	check(s.otto_near(player.global_position, 3.6), "with a friend to go with, Otto's bubble follows you (%d frames)" % t)
	check(absf(s.otto_at().y - home.y) < 0.01, "...floating level")


func _bring_otto(to: Vector3) -> void:
	# Stand somewhere and wait for Otto's bubble to float over
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	player.global_position = to
	player.velocity = Vector3.ZERO
	var t := 0
	while not s.otto_near(to, 4.0) and t < 900:
		await process_frame
		t += 1


func _check_vault() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var vault := (s.get_node("Vault") as Node3D).global_position
	# Too far ahead of him: wait
	player.global_position = vault + Vector3(0, 0.9, 0)
	await _physics(2)
	s._otto.global_position = Vector3(30, s.otto_at().y, 30)
	s.open_vault()
	check(not s.vault_open(), "the vault waits for Otto's bubble to catch up")
	await _bring_otto(vault + Vector3(0, 0.9, 0))
	var spot := s.get_node("Vault/Spot")
	check(spot.what() == "ask Otto to open the Clam Vault", "with Otto there, you can ask him to open it")
	spot.use()
	check(s.vault_open() and s._reaches.size() == 8, "eight latches, eight arms: one reaches out to each")
	await create_timer(2.8).timeout
	check((s.get_node("Clam Vault/Lid") as Node3D).rotation.z > 0.9, "...they all turn at once and the lid swings up")
	check(s.get_node_or_null("Pearl1/Tide Pearl") != null and spot.what() == "", "...and there's the first Tide Pearl")
	player.global_position = (s.get_node("Pearl1") as Node3D).global_position + Vector3(0, 0.9, 0.3)
	await _frames(4)
	check(s.has_pearl(0) and s.pearls() == 1 and s.get_node_or_null("Pearl1/Tide Pearl") == null, "walk into it and it's yours")
	check("One pearl" in str(s.otto_lines()[0]), "Otto can hardly believe he helped")


func _check_grotto() -> void:
	var s := current_scene
	var right: int = s.right_hole
	var wrong := (right + 1) % 3
	check((s.get_node("Hole%d/Glint" % (right + 1)) as Node3D).visible and not (s.get_node("Hole%d/Eyes" % (right + 1)) as Node3D).visible,
		"one hole in the Kelp Grotto has a pearly glint in it")
	check((s.get_node("Hole%d/Eyes" % (wrong + 1)) as Node3D).visible and not (s.get_node("Hole%d/Glint" % (wrong + 1)) as Node3D).visible,
		"...and the others have eyes blinking back")
	await _bring_otto((s.get_node("Hole%d" % (wrong + 1)) as Node3D).global_position + Vector3(-0.8, 0.9, 0))
	check(s.get_node("Hole%d/Spot" % (wrong + 1)).what() == "ask Otto to reach in here", "you choose the hole, Otto reaches")
	check(not s.try_hole(wrong) and s.wrong_tries == 1 and not s.has_pearl(1), "the wrong hole: he pulls out junk, and nothing's lost")
	await _bring_otto((s.get_node("Hole%d" % (right + 1)) as Node3D).global_position + Vector3(-0.8, 0.9, 0))
	check(s.try_hole(right) and s.has_pearl(1) and s.pearls() == 2, "the hole with the glint: he reaches the second Tide Pearl")
	check(not (s.get_node("Hole%d/Glint" % (right + 1)) as Node3D).visible and s.get_node("Hole%d/Spot" % (right + 1)).what() == "", "...and the glint's gone")
	check("Two pearls" in str(s.otto_lines()[0]), "Otto: nobody ever asked him to help before")


func _check_spire() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var pad := (s.get_node("BubblePad") as Node3D).global_position
	var top := (s.get_node("Pearl3") as Node3D).global_position
	check(top.y > 9.0, "the third pearl's high on top of the Coral Spire (%.0f m up)" % top.y)
	await _bring_otto(pad + Vector3(0, 0.9, 0))
	var spot := s.get_node("BubblePad/Spot")
	check(spot.what() == "ask Otto to blow bubble steps", "at the Bubble Pad you can ask Otto for steps")
	spot.use()
	check(s.steps_up, "he starts blowing")
	await create_timer(2.4).timeout
	var all_on := true
	for st in s._steps:
		all_on = all_on and st.on and (st.body as Node3D).visible
	check(all_on and s._steps.size() == 8, "eight bubble steps spiral up the spire")
	check(s.otto_near(pad, 3.5), "...while Otto stays at the pad")
	# Every hop is an easy one
	var ok := true
	var prev := pad
	var widest := 0.0
	var highest := 0.0
	for i in 8:
		var at := (s.get_node("Step%d" % (i + 1)) as Node3D).global_position
		widest = maxf(widest, Vector2(at.x - prev.x, at.z - prev.z).length())
		highest = maxf(highest, at.y - prev.y)
		prev = at
	highest = maxf(highest, top.y - prev.y)
	ok = widest < 3.4 and highest < 1.6
	check(ok, "each a short hop from the last (widest %.1f m, highest %.1f m)" % [widest, highest])
	# Jump onto the first one for real
	var s1 := (s.get_node("Step1") as Node3D).global_position
	player.global_position = pad + Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	await _physics(20)
	var dir := Vector3(s1.x - player.global_position.x, 0, s1.z - player.global_position.z).normalized()
	player.velocity = dir * 3.0 + Vector3(0, 6.5, 0)
	for i in 60:
		await physics_frame
		player.velocity.x = dir.x * 3.0
		player.velocity.z = dir.z * 3.0
		if player.global_position.y > s1.y + 0.6 and Vector2(player.global_position.x - s1.x, player.global_position.z - s1.z).length() < 0.6:
			break
	player.velocity = Vector3.ZERO
	await _physics(20)
	check(player.is_on_floor() and s.step_under(player) == 0, "the first step's a jump up from the pad, and it holds you (%.1f m)" % player.global_position.y)
	# ...but not for long
	await create_timer(s.STEP_HOLD + 0.5).timeout
	check(not s._steps[0].on, "a moment after you land on it, it pops")
	await _physics(30)
	check(player.global_position.y < 1.5, "...and you drop back down, unhurt")
	await create_timer(s.STEP_BACK + 0.3).timeout
	check(s._steps[0].on, "Otto blows it again")
	# On top: the pearl, then the ride
	player.global_position = top + Vector3(0, 0.9, 0.3)
	await _frames(4)
	check(s.has_pearl(2) and s.pearls() == 3, "on top, the spire's pearl is yours: that's all three")
	var ride := s.get_node("RideTop/Spot")
	check(ride.what() == "ride a bubble down", "a bubble's waiting to carry you down")
	ride.use()
	check(s.riding and bool(player.get("carried")) and player.input_locked, "...and off you float")
	var t := 0
	var peak := 0.0
	while s.riding and t < 1500:
		await physics_frame
		peak = maxf(peak, player.global_position.y)
		t += 1
	await _physics(50)
	check(not s.riding and not bool(player.get("carried")) and t < 1500, "...all the way down (%.1f s)" % (t / 60.0))
	check(player.global_position.y < 2.0 and player.is_on_floor(), "...POP, onto the sea bed")
	check(not player.input_locked and portals.has_found("tide_reef", "rode_bubble"), "...and you can move again")
	check(not s.steps_up, "the steps pop behind you, so Otto can come along again")


func _check_riptide() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var g := s.riptide as CharacterBody3D
	var basin := (s.get_node("RiptideGloop") as Node3D).global_position
	check(not s.riptide_awake, "the Riptide Gloop waits until you come near")
	player.global_position = basin + Vector3(0, 0.9, 13)
	await _frames(4)
	check(s.riptide_awake and g.process_mode == Node.PROCESS_MODE_INHERIT and s.get_node_or_null("RiptideGloop/Snoring") == null,
		"with all three pearls, it wakes up")
	check(str(g.get("title")) == "Riptide Gloop" and not portals.has_found("tide_reef", "x") and not root.get_node("Dialogue").flags.has("popped_gloop_king"),
		"(it's the King's cousin, not the King)")
	# Too slippery
	check(not g.held and g.shot(3, g.global_position, Vector3.FORWARD) == "bounce" and g.hits == 0, "it's too slippery: bubbles slide right off")
	check("eight arms" in " ".join(s.otto_lines()), "Otto's frightened... and then he has an idea")
	# Keep well back while Otto works out what he can do
	player.global_position = basin + Vector3(26, 0.9, 26)
	var t := 0
	while s.grabs == 0 and t < 1500:
		await process_frame
		t += 1
	check(s.grabs == 1 and g.held, "Otto floats to the basin's edge, wraps his arms round it and HOLDS it (%.1f s)" % (t / 60.0))
	check(s.otto_near((s.get_node("OttoPerch") as Node3D).global_position, 3.0), "...from his perch at the edge of the fight")
	var at := g.global_position
	await _physics(30)
	check(g.global_position.distance_to(at) < 0.3, "held, it can't go anywhere")
	check(g.shot(1, g.global_position, Vector3.FORWARD) == "hit" and g.hits == 1, "...and now a bubble counts")
	var hp: int = game.hp
	player.global_position = g.global_position + Vector3(0, 0.3, 3.0)
	await _physics(20)
	check(game.hp == hp, "...and it can't bump you while he's got it")
	player.global_position = basin + Vector3(26, 0.9, 26)
	await create_timer(s.HOLD_TIME).timeout
	await _physics(4)
	check(not g.held and g.shot(1, g.global_position, Vector3.FORWARD) == "bounce" and g.hits == 1, "then it slips free, and it's slippery again")
	# The riptide: dragged along the ground, free in the air
	player.global_position = g.global_position + Vector3(9, 0.9, 0)
	player.velocity = Vector3.ZERO
	await _physics(20)
	g.player = player
	var d0 := player.global_position.distance_to(g.global_position)
	g.start_pull()
	for i in 30:
		g.pull_step(1.0 / 60.0)
	var d1 := player.global_position.distance_to(g.global_position)
	check(g.pulling and d1 < d0 - 1.0, "its riptide drags you towards it along the ground (%.1f m)" % (d0 - d1))
	player.global_position.y += 3.0
	await _physics(2)
	var d2 := player.global_position.distance_to(g.global_position)
	g.pull_step(0.5)
	check(absf(player.global_position.distance_to(g.global_position) - d2) < 0.05, "...but not while you're in the air: jump to break free")
	g.pulling = false
	# Hold after hold until it pops
	player.global_position = basin + Vector3(26, 0.9, 26)
	var before: int = rem.count
	t = 0
	while not s.is_mended() and t < 3000:
		await process_frame
		t += 1
		if g.held and not g.defeated:
			g.shot(1, g.global_position, Vector3.FORWARD)
	check(g.defeated and portals.is_cleared("tide_reef") and s.grabs >= 2, "pop it while Otto holds it and the Tide Reef is mended (%d holds)" % s.grabs)
	check(rem.count == before + int(portals.world("tide_reef").reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(not root.get_node("Dialogue").flags.has("popped_gloop_king"), "...and it doesn't count as popping the Gloop King")


func _check_mended() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var dialogue := root.get_node("Dialogue")
	await create_timer(s.PROUD_AFTER + 0.6).timeout
	check(dialogue.is_active() and portals.has_found("tide_reef", "thanked"), "Otto's proud: he held it, with HIS arms")
	check("no use" in " ".join(s.proud_lines()) and "always need a friend" in " ".join(s.proud_lines()),
		"...he was never no use, and he still needs a friend (nothing about him was 'fixed')")
	dialogue.end()
	await create_timer(3.0).timeout
	check(s.tide > 0.99, "the tide comes all the way back in")
	var pool := (s.get_node("Tide2") as Node3D).global_position
	player.global_position = pool + Vector3(0, 0.9, 0)
	await _physics(20)
	check(s.in_tide_pool(player.global_position), "the tide pools are full: you can wade in them")
	check((s.get_node("Tide Pools/Pool2/Surface") as Node3D).visible and not (s.get_node("Tide Pools/Pool2/Cracks") as Node3D).visible,
		"...no more cracks")
	check((s.get_node("Sea Life") as Node3D).visible, "bubbles and leaping fish are back")
	var bloom: bool = s._corals.size() > 0
	for c in s._corals:
		bloom = bloom and (c[0] as StandardMaterial3D).albedo_color.is_equal_approx(c[1])
	check(bloom, "the corals are in full colour again")
	check((s.get_node("WorldEnvironment") as WorldEnvironment).environment.fog_density < 0.003, "and the dusty haze has cleared")
	var t := 0
	while not s.otto_near(player.global_position, 4.0) and t < 900:
		await process_frame
		t += 1
	check(s.otto_near(player.global_position, 4.0), "Otto's bubble still comes along with you")
	var chat: Array = s.otto_lines()
	check(chat.size() == 2 and not "no use, really" in " ".join(chat), "...and he's happy to chat")


func _check_swim() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var dialogue := root.get_node("Dialogue")
	var t := 0
	while not dialogue.is_active() and t < 600:
		await process_frame
		t += 1
	check(dialogue.is_active() and portals.has_found("tide_reef", "swim_taught"), "after his thank-you, Otto teaches you to swim")
	var lesson := " ".join(s.teach_lines())
	check("{jump}" in lesson and "{dash}" in lesson and "never run out of air" in lesson, "...how to swim up, dive and hop out, and that you can't run out of air")
	check(s.flood == 0.0, "...and the sea waits for him to finish")
	dialogue.end()
	await create_timer(s.FLOOD_TIME + 1.5).timeout
	check(s.flood == 1.0 and absf(s.sea_level() - s.SEA_TOP) < 0.01, "then the sea comes right back in, over everything (%.1f m)" % s.sea_level())
	var sea := s.get_node("The Sea")
	check(sea.covers(0, 0) and sea.covers(40, 0) and float(sea.get("water_y")) > 12.0, "...the whole reef is water to swim in")
	check(s.SEA_TOP < 18.0 - 1.0, "...and the reef's fence is taller than the sea, so nobody swims off the edge")
	check((s.get_node("Light Shafts") as Node3D).visible and (s.get_node("Sea Surface") as Node3D).visible, "...with light shafts down through it")
	check((s.get_node("Sea Lanterns/Sea Lantern 1") as Node3D).visible and not (s.get_node("Reef Chest") as Node3D).visible,
		"five sea lanterns drifted in; the chest isn't here yet")
	var swim: Node = player.get("swim")
	# Swimming in open water, away from the houses
	player.global_position = Vector3(4.0, 6.0, 22.0)
	player.velocity = Vector3.ZERO
	await _physics(20)
	check(player.call("is_swimming"), "out of your depth, you swim")
	check(swim.under and (swim.get("_helmet") as Node3D).visible, "...with Otto's bubble round your head")
	await _frames(4)
	var env := (s.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(swim.view_under and env.fog_density > 0.02, "the view goes blue-green and hazy under the water")
	var master := AudioServer.get_bus_index("Master")
	check(AudioServer.get_bus_effect_count(master) > 0 and AudioServer.get_bus_effect(master, AudioServer.get_bus_effect_count(master) - 1) is AudioEffectLowPassFilter,
		"...and sounds go muffled")
	var y0 := player.global_position.y
	await _physics(90)
	check(absf(player.global_position.y - y0) < 0.4, "let go of everything and you stay where you are (moved %.2f m)" % (player.global_position.y - y0))
	Input.action_press("dash")
	await _physics(60)
	Input.action_release("dash")
	var y1 := player.global_position.y
	check(y1 < y0 - 1.5, "hold Roll to dive (%.1f m down)" % (y0 - y1))
	Input.action_press("jump")
	await _physics(70)
	var y2 := player.global_position.y
	check(y2 > y1 + 1.5, "hold Jump to swim up (%.1f m up)" % (y2 - y1))
	var top := 0
	while player.global_position.y < s.SEA_TOP - 0.8 and top < 400:
		await physics_frame
		top += 1
	await _physics(40)
	Input.action_release("jump")
	await _physics(20)
	check(player.call("is_swimming") and absf(player.global_position.y - (s.SEA_TOP - swim.FLOAT)) < 0.35 and not swim.under,
		"swim up to the top and you float there, head out (%.2f m)" % player.global_position.y)
	await _frames(4)
	check(not swim.view_under and env.fog_density < 0.01, "...and the view's clear again")
	Input.action_press("jump")
	await _physics(3)
	Input.action_release("jump")
	check(not player.call("is_swimming") and player.velocity.y > 2.0, "press Jump at the top to hop out")
	await _physics(90)
	check(player.call("is_swimming"), "...and you splash back in")
	# Moving about
	player.global_position = Vector3(4.0, 5.0, 22.0)
	player.velocity = Vector3.ZERO
	await _physics(10)
	var x0 := player.global_position
	Input.action_press("move_forward")
	await _physics(60)
	Input.action_release("move_forward")
	var moved := Vector2(player.global_position.x - x0.x, player.global_position.z - x0.z).length()
	check(moved > 2.0 and moved < 5.5, "you swim along, slower than running (%.1f m in a second)" % moved)
	# Otto comes with you, up and down
	var h := 0
	while absf(s.otto_at().y - (player.global_position.y - 0.4)) > 1.0 and h < 600:
		await process_frame
		h += 1
	check(absf(s.otto_at().y - player.global_position.y) < 1.5, "Otto's bubble floats up and down with you")
	# The sea lanterns
	var before_r: int = rem.count
	var before_s: int = game.sparkles
	for i in s.LAMPS.size():
		player.global_position = s.LAMPS[i] + Vector3(1.0, -0.6, 0)
		player.velocity = Vector3.ZERO
		await _physics(8)
	check(s.lamps_lit() == 5, "swim up to each sea lantern and it lights (%d of 5)" % s.lamps_lit())
	var chest := s.get_node("Reef Chest") as Node3D
	check(chest.visible, "...then the Reef Chest has washed into the Deep Basin")
	check("chest" in " ".join(s.otto_lines()).to_lower(), "...and Otto says to go and open it")
	s.get_node("Reef Chest/Spot").use()
	check(s.chest_open() and rem.count == before_r + s.CHEST_REMNANTS and game.sparkles == before_s + s.CHEST_SPARKLES,
		"open it for %d Remnants and %d sparkles" % [s.CHEST_REMNANTS, s.CHEST_SPARKLES])
	dialogue.end()
	s.open_chest()
	check(rem.count == before_r + s.CHEST_REMNANTS, "...only once")
	# Before Otto's taught you, deep water is only for paddling along the top
	portals.cleared_worlds.erase("tide_reef")
	player.global_position = Vector3(4.0, 4.0, 22.0)
	player.velocity = Vector3.ZERO
	Input.action_press("dash")
	await _physics(240)
	Input.action_release("dash")
	check(player.call("is_swimming") and absf(player.global_position.y - (s.SEA_TOP - swim.FLOAT)) < 0.4,
		"before you can swim, deep water just floats you up to paddle along the top, and Roll doesn't dive (%.2f m)" % player.global_position.y)
	portals.cleared_worlds.append("tide_reef")
	player.global_position = Vector3(0, 13.6, 36)
	player.velocity = Vector3.ZERO
	await _physics(10)


func _check_home() -> void:
	portals.time_left = 0.4
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "when time's up you go home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal tide_reef") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by the Tide Reef's portal")
	portals.enter("tide_reef")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.pearls() == 3 and s.get_node_or_null("The Riptide Gloop") == null and s.tide == 1.0
		and s.vault_open() and s.get_node_or_null("Pearl3/Tide Pearl") == null,
		"going back, it's all still done: the tide's in, the vault's open, and no Riptide Gloop")
	check(s.flood == 1.0 and s.lamps_lit() == 5 and s.chest_open() and (s.get_node("Reef Chest/Lid") as Node3D).rotation.x < -1.0,
		"...the reef's still under the sea, the lanterns lit and the chest open")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("tide_reef") and portals.found == found and portals.is_open("tide_reef"), "the Tide Reef's progress loads back")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")
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
