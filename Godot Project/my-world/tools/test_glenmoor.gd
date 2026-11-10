extends SceneTree

# Checks Glenmoor, Heather's portal world (scripts/glenmoor.gd, scripts/stormram.gd, scenes/portal_worlds/glenmoor.tscn):
# its quake waits for the Tide Reef to be mended, then its portal rises in the meadow past the farm on flat, clear
# ground; inside, the seasons spin (grass, leaves, snow) and each Spring Bell slows them; Heather and Isla say what to
# do; Fluffkins trot away from you, only get into the Fold through its gate, and five in rings the first bell; a plant
# sung to in full bloom stays, out of bloom it doesn't, and five rings the second; the hill race needs the cairns in
# order, Isla wins if you dawdle, and beating her rings the third; Ben Bonnie can be stood on; the Stormram sleeps
# until all three bells are rung, then wakes when you come near, shrugs off bubbles unless dizzy, and popping it mends
# the world (spring opens on Earth, the seasons settle on spring); and it all stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_glenmoor.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.glenmoor_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.glenmoor_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/glenmoor.tscn"

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
	clock.seasons_open = ["autumn", "winter", "summer"]      # as a new game would have it, past Rhythm Springs
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs"]:
		portals.cleared_worlds.append(w)

	check(ResourceLoader.exists(WORLD) and portals.is_built("glenmoor"), "Glenmoor's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_seasons()
	await _check_fluffkins()
	await _check_garden()
	await _check_race()
	await _check_stormram()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("glenmoor"), "no Glenmoor quake before the Tide Reef is mended")
	portals.cleared_worlds.append("tide_reef")
	check(portals.next_due() == "glenmoor", "then its quake is due")
	portals.quake("glenmoor", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal glenmoor") as Node3D
	check(p != null and portals.is_open("glenmoor"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("glenmoor")
	var ground: Vector3 = rem.ground_at(w.at)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	var farm: Vector2 = root.get_node("Farm").GARDEN
	check(w.at.x < farm.x - 25.0 and w.at.distance_to(farm) < 60.0, "...in the meadow past the farm (%s)" % w.at)
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
	var trees := current_scene.find_child("Trees", true, false) as Node3D
	var tree := INF
	if trees:
		for tp in trees.get("positions"):
			var g: Vector3 = trees.global_transform * tp
			tree = minf(tree, w.at.distance_to(Vector2(g.x, g.z)))
	check(tree > 6.0, "...with no tree growing through it (nearest %.1f m)" % tree)
	var caves := Vector2(-97, -46)                       # the Rootwell, the way down to the Undergardens
	check(w.at.distance_to(caves) > 16.0, "...and clear of the Undergardens (%.0f m)" % w.at.distance_to(caves))
	var apart := INF
	for o in portals.WORLDS:
		if o.id != "glenmoor" and portals.is_built(o.id):
			apart = minf(apart, w.at.distance_to(o.at))
	check(apart > 20.0, "...and well apart from the other portals (%.0f m)" % apart)
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot(-w.at.normalized()) > 0.8, "...facing back towards town")
	check(portals._portal_offer("glenmoor") == "step through to Glenmoor", "it offers a trip to Glenmoor (%s)" % portals._portal_offer("glenmoor"))


func _check_inside() -> void:
	portals.enter("glenmoor")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "glenmoor", "stepping through takes you to Glenmoor")
	var names := ["WayHome/Way Home/Spot", "TimeStone/Time Stone/Spot", "Vein1/Remnant Vein/Spot", "Heather/Model", "Heather/Spot",
		"Isla Runner/Model", "Isla Runner/Spot", "Fluffkins", "Fold", "RaceLine", "RaceStart", "Hill", "Ben Bonnie/Slope",
		"The Stormram", "The Stormram/Visual/Whirlwind", "The Stormram/Visual/Storm Cloud", "Glen HUD/Season", "Glen HUD/Race",
		"Wee Loch", "Heather's Croft", "Standing Stones"]
	for i in 5:
		names.append("Bed%d/Plant" % (i + 1))
		names.append("Bed%d/Spot" % (i + 1))
		names.append("Fluffkins/Fluffkin %d" % (i + 1))
	for i in 6:
		names.append("Cairn%d" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "Glenmoor has %s" % n)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	check(not s.is_mended() and s.bells() == 0, "no Spring Bells rung yet")
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["TimeStone", "WayHome", "Vein1", "Heather", "Isla", "Fold", "RaceStart", "Stormram", "Bed1", "Bed5", "Cairn1", "Cairn3", "Cairn6"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	var first: Array = s.heather_lines()
	check("Glenmoor" in str(first[0]) and "Stormram" in " ".join(first) and "Spring Bells" in " ".join(first),
		"Heather says hello, what's wrong, and the three bells")
	check("Still to do" in " ".join(s.heather_lines()), "...and after that, what's left to do")
	var isla: Array = s.isla_lines()
	check("Isla" in str(isla[0]) and "Ben Bonnie" in " ".join(isla) and "cairns" in " ".join(isla), "Isla says hello and explains the hill race")
	check(s.get_node("Isla Runner/Spot").what() == "race Isla up Ben Bonnie", "after hello, Isla offers a race up Ben Bonnie")
	var storm := s.get_node("The Stormram") as Node
	check(storm.get("asleep") and storm.process_mode == Node.PROCESS_MODE_DISABLED, "the Stormram's fast asleep on the Standing Stones")


func _check_seasons() -> void:
	var s := current_scene
	# They spin round: in a few seconds it's another season
	var was: String = s.season()
	var k0: float = s.season_k
	await create_timer(s.spin_len() * 1.1).timeout
	check(s.season() != was or absf(s.season_k - k0) > 0.9, "the seasons spin round (%s -> %s)" % [was, s.season()])
	check("spinning" in s.season_words(), "the season card says they're spinning (%s)" % s.season_words())
	# Each season looks different: snow on the hills only in winter, the grass and leaves change colour
	var grass := s._mats["Glen Grass"] as StandardMaterial3D
	var leaves := s._mats["Leaves"] as StandardMaterial3D
	s.set_season(0.3)
	var spring_grass := grass.albedo_color
	var spring_leaves := leaves.albedo_color
	var snow_spring: bool = (s._snow[0] as Node3D).visible
	s.set_season(3.3)
	check(not snow_spring and (s._snow[0] as Node3D).visible and s.season() == "winter", "snow on the hills in winter, not in spring (%d caps)" % s._snow.size())
	check(grass.albedo_color.s < 0.15 and grass.albedo_color.v > 0.85 and spring_grass.s > 0.4, "the glen goes white in winter")
	s.set_season(2.3)
	check(leaves.albedo_color.r > spring_leaves.r - 0.2 and leaves.albedo_color.g < 0.6 and s.season() == "autumn", "the rowans turn red and gold in autumn")
	# And the preview's copy never changes: this world has its own materials
	var fresh := (load(WORLD) as PackedScene).instantiate()
	var own := true
	for mi in fresh.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m and m.resource_name == "Glen Grass":
			own = own and m != grass
	fresh.free()
	check(own, "this copy's seasons don't change the portal's preview")
	check(s.SPIN[0] < s.SPIN[1] and s.SPIN[1] < s.SPIN[2] and s.SPIN[2] < s.SPIN[3], "each Spring Bell slows the spin")


func _check_fluffkins() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var fold := s.get_node("Fold") as Node3D
	var c := fold.global_position
	var r := float(fold.get_meta("radius"))
	# Walk up behind one and it trots away from you
	var f := s.fluffkin(0) as Node3D
	f.global_position = Vector3(-6, 0, 22)
	player.global_position = Vector3(-6, 0.9, 25.5)
	await _physics(4)
	var before := f.global_position
	for i in 30:
		s.fluff_step(player, 1.0 / 30.0)
		player.global_position = f.global_position + Vector3(0, 0.9, 3.0)     # (walking after it)
	var moved := f.global_position - before
	check(moved.length() > 2.5 and moved.z < -2.0, "a Fluffkin trots away from you (%.1f m)" % moved.length())
	# Left alone it only grazes slowly
	player.global_position = Vector3(30, 0.9, 30)
	before = f.global_position
	for i in 30:
		s.fluff_step(player, 1.0 / 30.0)
	check(f.global_position.distance_to(before) < 1.0, "left alone, it just grazes")
	# The Fold's wall keeps it out except at the gate
	var back := Vector3(-1, 0, 0)                     # the far side from the gate (which faces east)
	f.global_position = c + back * (r + 1.4)
	player.global_position = c + back * (r + 4.0) + Vector3(0, 0.9, 0)
	for i in 60:
		s.fluff_step(player, 1.0 / 30.0)
		player.global_position = f.global_position + back * 2.5 + Vector3(0, 0.9, 0)
	check(not s.is_penned(0) and Vector2(f.global_position.x - c.x, f.global_position.z - c.z).length() > r, "the Fold's wall keeps it out (no jumping the wall)")
	var gate := Vector3(1, 0, 0)
	f.global_position = c + gate * (r + 2.0)
	for i in 90:
		player.global_position = f.global_position + gate * 2.5 + Vector3(0, 0.9, 0)
		s.fluff_step(player, 1.0 / 30.0)
		if s.is_penned(0):
			break
	check(s.is_penned(0) and s.penned() == 1, "herded in through the gate, it's penned")
	for i in 30:
		s.fluff_step(player, 1.0 / 30.0)
	check(Vector2(f.global_position.x - c.x, f.global_position.z - c.z).length() < r - 1.0, "...and it stays in the Fold")
	for i in range(1, 5):
		s.pen_fluff(i)
	check(s.has_bell(0) and s.bells() == 1, "all five Fluffkins in: the Fold's Spring Bell rings")
	check(s.spin_len() == s.SPIN[1], "...and the seasons slow down")


func _check_garden() -> void:
	var s := current_scene
	var spot := s.get_node("Bed1/Spot")
	check(spot.what() == "sing to the plant", "each bed offers a song for its plant")
	# Out of bloom: too early, or too late
	s._t = 0.2 * s.GROW_CYCLE                              # (bed 1's a sprout...)
	check(not s.in_bloom(0) and not s.tend(0) and not s.is_held(0), "singing to a sprout doesn't work")
	s._t = 0.92 * s.GROW_CYCLE                             # (...then wilting)
	check(s.grow_phase(0) > s.BLOOM_TO and not s.tend(0), "nor to a wilting plant")
	# In bloom it stays
	for b in 5:
		var tries := 0
		while not s.in_bloom(b) and tries < 200:
			s._t += 0.05
			tries += 1
		check(s.in_bloom(b) and s.tend(b) and s.is_held(b), "plant %d, sung to in full bloom, stays in bloom" % (b + 1))
		if b == 0:
			var plant := s.get_node("Bed1/Plant") as Node3D
			s._t += s.GROW_CYCLE * 0.4
			s._show_plants()
			check(s.grow_phase(0) == 0.65 and (plant.get_node("Stem/Bloom") as Node3D).scale.x > 0.9, "...for good, even as time goes on")
	check(s.has_bell(1) and s.bells() == 2, "all five in bloom: the garden's Spring Bell rings")
	check(s.get_node("Bed2/Spot").what() == "", "...and the beds have nothing more to ask")


func _check_race() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	# Ben Bonnie: gentle enough to walk up, and you can stand on it
	var hill := s.get_node("Hill") as Node3D
	var slope := atan(float(hill.get_meta("height")) / (float(hill.get_meta("radius")) - float(hill.get_meta("top_radius"))))
	check(rad_to_deg(slope) < 30.0, "Ben Bonnie's slope is gentle (%.0f degrees)" % rad_to_deg(slope))
	var c3 := (s.get_node("Cairn3") as Node3D).global_position
	player.global_position = c3 + Vector3(0, 1.5, 0)
	player.velocity = Vector3.ZERO
	await _physics(40)
	check(player.is_on_floor() and absf(player.global_position.y - 0.9 - c3.y) < 0.8, "you can stand on the hill by the third cairn (%.1f m up)" % c3.y)
	var top := (s.get_node("Cairn6") as Node3D).global_position
	check(top.y > 7.0 and bool(s.get_node("Cairn6").get_meta("summit")), "the last cairn's on the summit (%.0f m up)" % top.y)
	var widest := 0.0
	for i in 5:
		var a := (s.get_node("Cairn%d" % (i + 1)) as Node3D).global_position
		var b := (s.get_node("Cairn%d" % (i + 2)) as Node3D).global_position
		widest = maxf(widest, a.distance_to(b))
	check(widest < 30.0, "the cairns are a short run apart (widest %.0f m)" % widest)
	# Running cairn to cairn beats Isla's time with room to spare (you run at 5 m/s; she runs her line at ISLA_SPEED)
	var run := 0.0
	var prev := (s.get_node("RaceStart") as Node3D).global_position
	for i in 6:
		var at := (s.get_node("Cairn%d" % (i + 1)) as Node3D).global_position
		run += Vector2(at.x - prev.x, at.z - prev.z).length()
		prev = at
	var hers: float = s._race_line.curve.get_baked_length() / s.ISLA_SPEED
	check(run / 5.0 < hers * 0.85, "running it takes %.0f s, Isla takes %.0f s: you can win" % [run / 5.0, hers])
	# Start: a countdown, then go
	s.get_node("Isla Runner/Spot").use()
	check(s.racing and not s.race_go and player.input_locked, "racing Isla: a countdown, and you wait on the line")
	check((s.get_node("Glen HUD/Race") as Control).visible, "...with the race card showing")
	s._countdown = 0.05
	await create_timer(0.3).timeout
	check(s.race_go and not player.input_locked, "...then GO")
	# Cairns only count in order
	player.global_position = c3 + Vector3(0, 1.0, 0)
	await _physics(4)
	check(s.race_next == 0, "reaching the third cairn first doesn't count: they go in order")
	for i in 6:
		var at := (s.get_node("Cairn%d" % (i + 1)) as Node3D).global_position
		player.global_position = at + Vector3(0.6, 1.0, 0)
		await _physics(3)
	check(not s.racing and s.has_bell(2) and s.bells() == 3, "past all six cairns to the top before Isla: the hill's Spring Bell rings")
	check(not player.input_locked, "...and you can move")
	# A race where you dawdle: Isla wins
	await create_timer(2.7).timeout
	s.start_race()
	s._countdown = 0.05
	await create_timer(0.3).timeout
	s._isla_d = s._race_line.curve.get_baked_length() - 0.1
	await create_timer(0.3).timeout
	check(not s.racing and s.race_next == 0, "dawdle and Isla gets to the top first (no harm done)")
	var isla := s.get_node("Isla Runner") as Node3D
	await create_timer(2.8).timeout
	check(isla.global_position.distance_to((s.get_node("Isla") as Node3D).global_position) < 0.5, "...and she jogs back down for another go")


func _check_stormram() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var storm := s.get_node("The Stormram") as CharacterBody3D
	player.global_position = Vector3(0, 0.9, 30)
	await _physics(10)
	check(storm.get("asleep"), "the Stormram sleeps on until you come near")
	player.global_position = (s.get_node("Stormram") as Node3D).global_position + Vector3(0, 0.6, 14)
	await _frames(4)
	check(not storm.get("asleep") and storm.process_mode == Node.PROCESS_MODE_INHERIT, "with all three bells, it wakes up")
	check(str(storm.get("title")) == "Stormram" and storm.get_node_or_null("BossMeter") != null, "...with its own name over it")
	# Its charges: a whirlwind spins up round it
	storm.set("_cooldown", 0.0)
	var spun := false
	for i in 200:
		await physics_frame
		if (storm.get_node("Visual/Whirlwind") as Node3D).visible:
			spun = true
			break
	check(spun, "it curls up and charges in a whirlwind")
	# Wool too thick: bubbles only count while it's dizzy
	await _physics(2)
	storm.call("_set_state", 4)                            # (DIZZY)
	var hits0: int = storm.get("hits")
	check(storm.shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit" and int(storm.get("hits")) == hits0 + 1, "a bubble while it's dizzy counts")
	storm.call("_set_state", 3)                            # (ROLL)
	check(storm.shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "...while it's charging, bubbles bounce off its wool")
	var before: int = rem.count
	player.global_position = Vector3(0, 0.9, 30)
	while not storm.get("defeated"):
		storm.call("_set_state", 4)
		storm.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("glenmoor"), "popping the Stormram mends Glenmoor")
	check(rem.count == before + int(portals.world("glenmoor").reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(clock.season_open("spring"), "...and spring opens on Earth")
	check(not root.get_node("Dialogue").flags.has("popped_boulderdillo"), "(it's not the Boulderdillo)")
	await create_timer(3.4).timeout
	check(s.season() == "spring" and s.season_k < 0.01, "the seasons stop spinning and settle on spring")
	var k: float = s.season_k
	await create_timer(1.0).timeout
	check(s.season_k == k and "here to stay" in s.season_words(), "...and stay there")
	for b in 5:
		check(s.in_bloom(b), "plant %d's in bloom" % (b + 1))
	check(root.get_node("Dialogue").is_active(), "Heather thanks you")
	root.get_node("Dialogue").end()
	check(not s.racing, "(no race going)")


func _check_home() -> void:
	portals.time_left = 0.4
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "when time's up you go home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal glenmoor") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by Glenmoor's portal")
	portals.enter("glenmoor")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.bells() == 3 and s.get_node_or_null("The Stormram") == null and s.season() == "spring",
		"going back, it's all still done, and it's spring")
	await create_timer(1.0).timeout
	check(s.season() == "spring", "...staying spring")
	check(s.penned() == 5 and s.held() == 5, "the Fluffkins are in the Fold and the plants in bloom")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("glenmoor") and portals.found == found and portals.is_open("glenmoor"), "Glenmoor's progress loads back")
	check(clock.season_open("spring"), "...and spring stays open")


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
