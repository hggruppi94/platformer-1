extends SceneTree

# Checks Lanternmoor, Pip's portal world (scripts/lanternmoor.gd, scenes/portal_worlds/lanternmoor.tscn): its quake
# waits for the Frozen Moment to be mended, then its portal rises in the Spooky Woods on flat, clear ground; inside,
# it's night, Pip's there, says what to do and lends you moth wings; Moon Rock is too far to reach without them, and
# with them you glide there from the Tall Lantern Tree; the five lanterns (Interact or a bubble) light the first beacon;
# the runaway lights flit away from you but stay in the grove, and catching all three lights the third beacon; the Dawn
# Snatcher sleeps until all three are lit, then wakes when you come near; popping him mends the world (its reward, the
# sunrise) without counting as popping Grandfather Tock; and what you've done stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_lanternmoor.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.lanternmoor_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lanternmoor_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/lanternmoor.tscn"

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
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind"]:
		portals.cleared_worlds.append(w)

	check(ResourceLoader.exists(WORLD) and portals.is_built("lanternmoor"), "Lanternmoor's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_wings()
	await _check_lanterns()
	await _check_lights()
	await _check_snatcher()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("lanternmoor"), "no Lanternmoor quake before the Frozen Moment is mended")
	portals.cleared_worlds.append("frozen_moment")
	check(portals.next_due() == "lanternmoor", "then its quake is due")
	portals.quake("lanternmoor", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal lanternmoor") as Node3D
	check(p != null and portals.is_open("lanternmoor"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("lanternmoor")
	var ground: Vector3 = rem.ground_at(w.at)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	check(w.at.x < -80.0 and w.at.y < -80.0, "...out in the Spooky Woods, north-west (%s)" % w.at)
	check(w.at.distance_to(Vector2(-112, -128)) > 20.0, "...well clear of the Haunted House")
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
	# Its front faces back towards the town, so you walk up to it from the path
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot(-w.at.normalized()) > 0.8, "...facing back towards the town")
	check(portals._portal_offer("lanternmoor") == "step through to Lanternmoor", "it offers a trip to Lanternmoor (%s)" % portals._portal_offer("lanternmoor"))


func _check_inside() -> void:
	portals.enter("lanternmoor")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "lanternmoor", "stepping through takes you to Lanternmoor")
	var names := ["WayHome/Way Home/Spot", "TimeStone/Time Stone/Spot", "Vein1/Remnant Vein/Spot", "Beacon1/Beacon",
		"Beacon2/Spot", "Beacon3/Beacon", "Launch/Spot", "Pip/Model", "Pip/Spot", "The Dawn Snatcher", "Snatcher/Snoring",
		"Stars", "Moths", "Moon/Moon"]
	for i in 5:
		names.append("Lantern%d/Spot" % (i + 1))
		names.append("Lantern%d/Hit" % (i + 1))
	for i in 3:
		names.append("Runaway Light %d/Hit" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "Lanternmoor has %s" % n)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	check(s.dawn == 0.0 and not s.is_morning(), "it's night: the sun won't rise")
	var space := (s as Node3D).get_world_3d().direct_space_state
	var spots := ["Beacon1", "Beacon2", "Beacon3", "TimeStone", "WayHome", "Vein1", "Pip", "Snatcher", "Launch"]
	for i in 5:
		spots.append("Lantern%d" % (i + 1))
	for n in spots:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)


func _check_wings() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(float(player.glide_fall) == 0.0 and not s.has_wings(), "no wings before you meet Pip")
	check(s.get_node("Launch/Spot").what() == "look across to Moon Rock", "...and from the Tall Lantern Tree, Moon Rock looks out of reach")
	var launch := (s.get_node("Launch") as Node3D).global_position
	var rock := (s.get_node("Beacon2") as Node3D).global_position
	var gap := Vector2(rock.x - launch.x, rock.z - launch.z).length() - 2.4 - 3.2
	check(gap > 18.0, "Moon Rock is farther than any jump (a %.0f m gap)" % gap)
	var landed := await _leap(player, launch, rock, false)
	check(landed.y < 1.0, "jumping off without wings, you land softly on the moor (%s)" % landed)
	var first: Array = s.pip_lines()
	check("Lanternmoor" in str(first[0]) and "wings" in " ".join(first), "Pip says hello, what's wrong and lends you wings")
	check(s.has_wings() and float(player.glide_fall) > 0.0 and player.get_node_or_null("Visual/Moth Wings") != null,
		"...and you're wearing moth wings")
	check("Still to do" in " ".join(s.pip_lines()), "...and after that, what's left to do")
	landed = await _leap(player, launch, rock, true)
	check(landed.y > 6.0 and Vector2(landed.x - rock.x, landed.z - rock.z).length() < 3.4,
		"holding Jump, you glide all the way to Moon Rock (%s)" % landed)
	check(s.get_node("Beacon2/Spot").what() == "light the beacon", "the beacon there offers to be lit")
	s.get_node("Beacon2/Spot").use()
	check(s.is_beacon_lit(1) and s.beacons_lit() == 1 and s.get_node("Beacon2/Spot").what() == "", "...and lights")
	check(s.get_node_or_null("Beacon2/Beacon/Glow") != null, "...glowing")


func _leap(player: CharacterBody3D, from: Vector3, to: Vector3, glide: bool) -> Vector3:
	# Off the edge of the tree's top towards Moon Rock, with a running jump; holding Jump all the way (glide) or not
	var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
	player.global_position = from + dir * 1.8 + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	player.spring_arm.global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	await _physics(10)
	Input.action_press("move_forward")
	if glide:
		Input.action_press("jump")
	player.velocity = dir * 5.0 + Vector3(0, 6.0, 0)
	await _physics(6)
	var n := 0
	while n < 600 and not (player.is_on_floor() and n > 20):
		await physics_frame
		n += 1
	Input.action_release("move_forward")
	Input.action_release("jump")
	await _physics(6)
	return player.global_position


func _check_lanterns() -> void:
	var s := current_scene
	check(s.get_node("Lantern1/Spot").what() == "light the lantern", "a lantern on the Night Path offers to be lit")
	for i in 4:
		s.get_node("Lantern%d/Spot" % (i + 1)).use()
	check(s.lanterns_lit() == 4 and not s.is_beacon_lit(0), "four lanterns lit, and the path's beacon is still dark")
	check(s.get_node("Lantern1/Spot").what() == "" and s.get_node_or_null("Lantern1/Lantern/Glow") != null, "...lit lanterns glow and are done")
	var said: String = s.get_node("Lantern5/Hit").shot(1, Vector3.ZERO, Vector3.FORWARD)
	check(said == "hit" and s.lanterns_lit() == 5, "a bubble lights the fifth")
	check(s.is_beacon_lit(0) and s.beacons_lit() == 2, "...and the Night Path's beacon blazes up")
	check(s.get_node("Lantern5/Hit").shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "a lit lantern just bounces bubbles")


func _check_lights() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	# The Dawn Snatcher doesn't wake with only two beacons lit
	player.global_position = (s.get_node("Snatcher") as Node3D).global_position + Vector3(0, 0, 6)
	await _frames(10)
	check(not s.snatcher_awake and s._snatcher.process_mode == Node.PROCESS_MODE_DISABLED, "with two beacons lit, the Dawn Snatcher snoozes on")
	check(s.get_node("Snatcher/Spot").what() == "look at the sleeping goblin", "...and you can look at him")
	# A runaway light flits away from you...
	var grove := (s.get_node("Beacon3") as Node3D).global_position
	var l: Node3D = s.light_node(0)
	var away: Vector3 = l.global_position - grove
	away.y = 0
	player.global_position = l.global_position - away.normalized() * 4.0
	player.global_position.y = 0.6
	var d0 := Vector2(l.global_position.x - player.global_position.x, l.global_position.z - player.global_position.z).length()
	await _physics(30)
	var d1 := Vector2(l.global_position.x - player.global_position.x, l.global_position.z - player.global_position.z).length()
	check(d1 > d0 + 0.5, "a runaway light flits away when you come near (%.1f -> %.1f m)" % [d0, d1])
	await _physics(120)
	var off := Vector2(l.global_position.x - grove.x, l.global_position.z - grove.z).length()
	check(off <= s.GROVE_R + 0.05, "...but never out of the Lantern Grove (%.1f m from its middle)" % off)
	# ...and you catch it by running into it
	player.global_position = l.global_position - Vector3(0, 0.6, 0)
	await _physics(3)
	check(s.is_light_caught(0) and s.lights_caught() == 1, "run into it and you catch it")
	check(s.light_node(1).get_node("Hit").shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit" and s.is_light_caught(1), "a bubble catches one too")
	player.global_position = s.light_node(2).global_position - Vector3(0, 0.6, 0)
	await _physics(3)
	check(s.lights_caught() == 3, "all three caught")
	await create_timer(1.6).timeout
	check(s.is_beacon_lit(2) and s.beacons_lit() == 3, "they fly home, and the Lantern Grove's beacon lights")
	check(s.light_node(0) == null and s.light_node(2) == null, "...and the runaway lights are gone into it")


func _check_snatcher() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	player.global_position = Vector3(0, 0.6, 20)                          # well away from the hill
	await _physics(10)
	check(not s.snatcher_awake, "the Dawn Snatcher waits until you come near")
	player.global_position = (s.get_node("Snatcher") as Node3D).global_position + Vector3(0, 0, 10)
	await _frames(4)
	var g := s._snatcher as CharacterBody3D
	check(s.snatcher_awake and g.process_mode == Node.PROCESS_MODE_INHERIT, "with all three beacons lit, he wakes up")
	check(g.get("title") == "The Dawn Snatcher" and s.get_node_or_null("Snatcher/Snoring") == null, "...the Dawn Snatcher, with his own name, no longer snoring")
	check(g.get_node_or_null("Visual/Head/Clock/Dawn Glow") != null, "...the dawn glowing in his clock hat")
	await _physics(30)
	var before: int = rem.count
	player.global_position = Vector3(0, 0.6, 20)                          # out of his reach while he's popped
	for i in 8:
		if is_instance_valid(g) and not g.defeated:
			g.shot(1, g.global_position, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("lanternmoor"), "popping him mends Lanternmoor")
	check(rem.count == before + int(portals.world("lanternmoor").reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(not root.get_node("Dialogue").flags.has("popped_grandfather_tock"), "...and it doesn't count as popping Grandfather Tock")
	check(s.get_node_or_null("Rising Sun") != null, "the dawn floats up out of his clock")
	await create_timer(s.DAWN_TIME + 0.6).timeout
	check(s.is_morning() and not (s.get_node("Stars") as Node3D).visible, "the sun comes up and the stars fade")
	var sun := s.get_node("Sun") as DirectionalLight3D
	check(sun.light_energy > 1.0, "...and the moor is bright (light %.2f)" % sun.light_energy)
	check("morning" in " ".join(s.pip_lines()), "Pip's thrilled")
	await create_timer(s.TEACH_AFTER - s.DAWN_TIME).timeout
	var dlg := root.get_node("Dialogue")
	check(dlg.is_active() and s.caves != null, "then Pip teaches you the glow and the Glimmer Caves open (tools/test_glimmer_caves.gd)")
	dlg.end()
	await _physics(30)
	var left := 0
	for n in s.get_children():
		if n is CharacterBody3D and not n.is_in_group("player") and is_instance_valid(n) and not n.get("defeated"):
			left += 1
	check(left == 0, "no goblins are left about (%d)" % left)


func _check_home() -> void:
	portals.time_left = 0.4
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "when time's up you go home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal lanternmoor") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by Lanternmoor's portal")
	portals.enter("lanternmoor")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.beacons_lit() == 3 and s.get_node_or_null("The Dawn Snatcher") == null
		and s.is_morning() and s.get_node_or_null("Morning Sun") != null and s.has_wings(),
		"going back, it's all still done, it's morning, and Pip's wings are still yours there")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("lanternmoor") and portals.found == found and portals.is_open("lanternmoor"), "Lanternmoor's progress loads back")


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
