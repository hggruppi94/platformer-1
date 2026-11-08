extends SceneTree

# Checks the time quakes and portal worlds (scripts/portals.gd, scripts/portal_world.gd) and Shard Isle, the first
# world (scripts/shard_isle.gd, scenes/portal_worlds/shard_isle.tscn): no quake before the First Night is done; then
# one shakes the Void and Shard Isle's portal rises out of a crack on the ground, once; the portal's preview window
# wakes up near it (a copy of the world with no player in it) and sleeps when you walk off; stepping through is free,
# extra time costs Remnants; inside, the Void's clock stands still, the timer counts down and shows, the Time Stone
# sells time, falling off floats you back, the Remnant vein needs the tool; the three Echo Crystals and the Heart
# Stone clear the world (with its reward and the Portal Plaza in the Void); running out of time pulls you gently
# home by the portal with what you found; the way home always works; and it all saves, loads, and an old save starts
# with no quakes.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_portals.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.portals_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.portals_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const ISLE := "res://scenes/portal_worlds/shard_isle.tscn"

var failures := 0
var game: Node
var portals: Node
var rem: Node
var dialogue: Node
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
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)

	check(ResourceLoader.exists(ISLE), "Shard Isle's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_preview()
	await _check_inside()
	await _check_clearing()
	await _check_time_up()
	await _check_way_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(portals.next_due() == "", "no time quake before the First Night is done")
	await create_timer(portals.QUAKE_DELAY + 1.0).timeout
	check(current_scene.get_node_or_null("Portals/Portal shard_isle") == null, "...so no portal yet")
	check(not portals.is_built("lanternmoor") and not portals.quake_due("lanternmoor"), "worlds that aren't built never quake")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	check(portals.next_due() == "shard_isle", "once the First Night's done, Shard Isle's quake is due")
	var quaked := [""]
	portals.quaked.connect(func(id: String) -> void: quaked[0] = id, CONNECT_ONE_SHOT)
	await create_timer(1.5).timeout
	check(portals.is_open("shard_isle"), "the quake comes in the Void (a few seconds after arriving)")
	var p := current_scene.get_node_or_null("Portals/Portal shard_isle") as Node3D
	check(p != null, "a portal is put into the town")
	await create_timer(4.0).timeout
	check(quaked[0] == "shard_isle", "the quake finishes (portal risen)")
	if p == null:
		return
	var w: Dictionary = portals.world("shard_isle")
	check(absf(p.global_position.x - w.at.x) < 0.01 and absf(p.global_position.z - w.at.y) < 0.01, "the portal is at its spot")
	var ground: Vector3 = rem.ground_at(w.at)
	check(absf(p.global_position.y - ground.y) < 0.05 and ground.y > -0.5, "...on dry ground (y %.2f)" % ground.y)
	check(absf((p.get_node("Ring") as Node3D).position.y) < 0.01, "the ring has risen out of the crack")
	check(p.get_node_or_null("Spot") != null, "the portal can be used")
	check(portals._portal_offer("shard_isle") == "step through to Shard Isle", "it offers a trip to Shard Isle")
	check(portals.next_due() == "", "the quake only happens once")
	# Nothing else should be standing where it rose
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	q.shape = sphere
	q.transform = Transform3D(Basis(), p.global_position + Vector3(0, 3.5, 0))
	var hits := space.intersect_shape(q, 16)
	var others := hits.filter(func(h: Dictionary) -> bool:
		var c: Node = h.collider
		return not p.is_ancestor_of(c) and not c.is_in_group("player"))
	check(others.is_empty(), "nothing else stands in the portal's way (%d)" % others.size())


func _check_preview() -> void:
	var p := current_scene.get_node("Portals/Portal shard_isle") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	player.global_position = p.global_position + p.global_basis.z * 30.0 + Vector3(0, 1, 0)
	await _frames(3)
	check(p.get_node_or_null("Preview") == null, "far away, the preview is asleep")
	player.global_position = p.global_position + p.global_basis.z * 6.0 + Vector3(0, 1, 0)
	await _frames(3)
	var view := p.get_node_or_null("Preview") as SubViewport
	check(view != null, "up close, the portal shows a preview window")
	if view:
		var copy := view.get_child(0)
		check(copy != null and copy.has_meta("preview"), "...a copy of Shard Isle")
		check(copy.get_node_or_null("Player") == null, "...with no player in it")
		check(copy.get_node_or_null("HeartStone/Heart") == null and copy.get_node_or_null("Echo1").get_child_count() > 0,
			"...that only shows the Echo Crystals, nothing to use")
		check(view.get_node_or_null("Cam") != null, "...seen from a circling camera")
		check((p.get_node("Ring/Swirl") as MeshInstance3D).material_override.albedo_texture != null, "...on the portal's swirl")
	player.global_position = p.global_position + p.global_basis.z * 30.0 + Vector3(0, 1, 0)
	await _frames(3)
	check(p.get_node_or_null("Preview") == null, "walking off puts it to sleep again")
	# Going in through the portal's question
	player.global_position = p.global_position + p.global_basis.z * 2.0 + Vector3(0, 1, 0)
	portals._use_portal("shard_isle")
	check(dialogue.is_active(), "using the portal asks first")
	dialogue.end()
	await _frames(4)
	check(current_scene.scene_file_path == TOWN, "saying \"Not now\" keeps you in the Void")


func _check_inside() -> void:
	rem.count = 3
	check(not portals.enter("shard_isle", 5), "can't buy more time than you have Remnants for")
	check(portals.enter("shard_isle", 2), "stepping through with extra time")
	check(rem.count == 1, "...spends the Remnants (%d left)" % rem.count)
	await _frames(12)
	await _physics(4)
	check(current_scene.scene_file_path == ISLE, "the portal takes you to Shard Isle")
	check(portals.here == "shard_isle", "the game knows you're there")
	check(absf(portals.time_left - (portals.FREE_SECONDS + 2 * portals.SECONDS_PER_REMNANT)) < 2.0,
		"the free time plus two minutes (%.0f s)" % portals.time_left)
	var m0: float = clock.minutes
	await create_timer(1.2).timeout
	check(not clock.running and absf(clock.minutes - m0) < 0.001, "the Void's clock stands still while you're away")
	check(portals.time_left < portals.FREE_SECONDS + 2 * portals.SECONDS_PER_REMNANT - 0.9, "the portal timer counts down")
	check(portals.timer_text().begins_with("⏳ Shard Isle"), "the timer shows on screen (%s)" % portals.timer_text())
	var s := current_scene
	for n in ["WayHome/Way Home/Spot", "TimeStone/Time Stone/Spot", "HeartStone/Heart/Spot", "Echo1/Spot", "Echo2/Spot",
			"Echo3/Spot", "Vein1/Remnant Vein/Spot"]:
		check(s.get_node_or_null(n) != null, "Shard Isle has %s" % n.get_slice("/", 0))
	var player := s.get_tree().get_first_node_in_group("player") as Node3D
	var entrance := s.get_node("Entrance") as Node3D
	check(player.global_position.distance_to(entrance.global_position) < 2.0, "you arrive at the entrance")
	# Every islet and the Heart Stone stand on something, and the Echo Crystals can be reached by stepping stones
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["Echo1", "Echo2", "Echo3", "HeartStone", "TimeStone", "Vein1", "WayHome"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.0, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	check(_hops_ok(s), "every stepping stone is a short hop from the last")
	# The Time Stone
	var before: float = portals.time_left
	s.get_node("TimeStone/Time Stone/Spot").use()
	check(rem.count == 0 and portals.time_left > before + 55.0, "the Time Stone turns a Remnant into a minute")
	s.get_node("TimeStone/Time Stone/Spot").use()
	check(portals.time_left < before + 65.0, "...and does nothing without one")
	# The vein needs the tool
	check(s.get_node("Vein1/Remnant Vein/Spot").what() == "look at the glowing crystals", "the vein needs Bramble's tool")
	dialogue.set_flag("harvest_tool_built")
	s.get_node("Vein1/Remnant Vein/Spot").use()
	check(rem.count == 2, "with the tool, the vein gives two Remnants")
	check(s.get_node("Vein1/Remnant Vein/Spot").what() == "", "...once a Void day")
	dialogue.flags.erase("harvest_tool_built")
	# Falling off floats you back
	player.global_position = Vector3(0, -40, 0)
	await _physics(3)
	check(player.global_position.y > -2.0, "falling off the island floats you back up")


func _hops_ok(s: Node) -> bool:
	# From the main island's rim to each islet, no gap between stones is longer or higher than a jump
	var stones := s.get_children().filter(func(c: Node) -> bool: return str(c.name).begins_with("Stone"))
	if stones.size() < 6:
		return false
	for st in stones:
		var near := INF
		var p: Vector3 = (st as Node3D).global_position
		for o in stones:
			if o != st:
				near = minf(near, p.distance_to((o as Node3D).global_position))
		var rim := Vector2(p.x, p.z).length() - 14.0
		near = minf(near, absf(rim) + absf(p.y) + 1.0) if rim < 2.5 else near
		var to_islet := INF
		for n in ["Echo1", "Echo2", "Echo3"]:
			var c: Vector3 = (s.get_node(n) as Node3D).global_position
			to_islet = minf(to_islet, Vector2(p.x - c.x, p.z - c.z).length() - 5.0)
		if to_islet < 2.5:
			near = minf(near, 3.0)
		if near > 3.4:
			print("  stone at %s: nearest step %.2f" % [p, near])
			return false
	return true


func _check_clearing() -> void:
	var s := current_scene
	check(s.get_node("HeartStone/Heart/Spot").what() == "look at the Heart Stone", "the Heart Stone waits for the Echo Crystals")
	s.get_node("HeartStone/Heart/Spot").use()
	check(not portals.is_cleared("shard_isle"), "...and doesn't mend without them")
	for i in 3:
		s.get_node("Echo%d/Spot" % (i + 1)).use()
	check(s.echoes_found() == 3, "all three Echo Crystals found")
	check(not (s.get_node("Echo1/Echo") as Node3D).visible, "found ones are gone from their stands")
	check(portals.has_found("shard_isle", "echo_2"), "found things are remembered")
	var r0: int = rem.count
	s.get_node("HeartStone/Heart/Spot").use()
	check(portals.is_cleared("shard_isle"), "setting them in the Heart Stone mends Shard Isle")
	check(rem.count == r0 + int(portals.world("shard_isle").reward_remnants), "...with its reward of Remnants")
	check((s.get_node("HeartStone/Heart/Socket0") as Node3D).visible, "the Heart Stone lights up with the crystals")
	await _frames(2)


func _check_time_up() -> void:
	portals.time_left = 0.4
	await create_timer(1.0).timeout
	await _frames(12)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "when time runs out, the portal pulls you home to the Void")
	check(portals.here == "" and clock.running, "...and the Void's clock runs again")
	var p := current_scene.get_node_or_null("Portals/Portal shard_isle") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by its portal (%.1f m)" %
		(player.global_position.distance_to(p.global_position) if p else -1.0))
	check(current_scene.get_node_or_null("Portals/Portal Plaza") != null, "clearing Shard Isle grew the Portal Plaza in the Void")
	var w: Dictionary = portals.world("shard_isle")
	var worst := 0.0
	var base: float = rem.ground_at(w.at).y
	for k in 12:
		var a := k * TAU / 12.0
		worst = maxf(worst, absf(rem.ground_at(w.at + Vector2(cos(a), sin(a)) * 7.5).y - base))
	check(worst < 0.4, "the plaza sits on flat ground (worst step %.2f)" % worst)
	check(portals.timer_text() == "", "no timer in the Void")
	# Back in: found things stay found, and the time starts fresh
	portals.enter("shard_isle")
	await _frames(12)
	check(current_scene.scene_file_path == ISLE and absf(portals.time_left - portals.FREE_SECONDS) < 2.0, "back in with the free time")
	check(not (current_scene.get_node("Echo2/Echo") as Node3D).visible, "the Echo Crystals are still found")


func _check_way_home() -> void:
	current_scene.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)
	check(current_scene.scene_file_path == TOWN and portals.here == "", "the way home takes you back any time")


func _check_saving() -> void:
	game.save_game()
	var quakes: Array = portals.quakes.duplicate()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	check(portals.quakes.is_empty(), "(cleared before loading)")
	game.load_game()
	check(portals.quakes == quakes and portals.is_cleared("shard_isle") and portals.found == found, "quakes, cleared worlds and found things load back")
	# A save made inside a world keeps its time left
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data["portals"]["here"] = "shard_isle"
	data["portals"]["time_left"] = 99.0
	_write(data)
	game.load_game()
	check(absf(portals.time_left - 99.0) < 0.01, "a save made in a portal world keeps its time")
	# An old save from before the quakes
	data.erase("portals")
	_write(data)
	game.load_game()
	check(portals.quakes.is_empty() and portals.cleared_worlds.is_empty() and portals.time_left == 0.0, "an old save has had no quakes yet")


func _write(data) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()


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
