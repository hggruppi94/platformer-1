extends SceneTree

# Checks the Far Future, Dash and Rex's portal world (scripts/far_future.gd, scripts/captain_glitch.gd,
# scenes/portal_worlds/far_future.tscn): its quake waits for Glenmoor to be mended, then its portal rises on the fault
# line behind Rex and Dash's lab on flat, clear ground; inside, Lumen City is fading (washed out, dim neon) and every
# Time Core brings some colour back; Rex and Dash say what to do; the hover lifts carry you up to the gallery and the
# roof, the three Chrono Fuses fix by hand or by bubble and power the Swap-o-Tron (core one); the Skyway's racing line
# lies on its deck, clear in every lane, a whole race brings core two, and falling off mid-race pops you back up; the
# fading people get pinned back into time by walking up or by a bubble, the hover steps up to the balcony are short
# hops, and all six is core three; Captain Glitch sleeps until all three, wakes when you come near, drops chaos bursts,
# shrugs off bubbles until he crashes down and his clock glows, calls goblins, and popping him mends the city; and it
# all stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_far_future.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.far_future_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.far_future_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/far_future.tscn"
const ID := "far_future"

var failures := 0
var game: Node
var portals: Node
var rem: Node
var quests: Node
var clock: Node
var races: Node


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
	portals = root.get_node("Portals")
	rem = root.get_node("Remnants")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	races = root.get_node("Races")
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(w)
	if not game.has_item("skateboard"):
		game.items.append("skateboard")

	check(ResourceLoader.exists(WORLD) and portals.is_built(ID), "the Far Future's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_fuses()
	await _check_folk()
	await _check_race()
	await _check_captain()
	await _check_home()
	_check_saving()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _check_quake() -> void:
	check(not portals.quake_due(ID), "no Far Future quake before Glenmoor is mended")
	portals.cleared_worlds.append("glenmoor")
	check(portals.next_due() == ID, "then its quake is due (Dark Hollow, being optional, doesn't hold it up)")
	portals.quake(ID, true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal far_future") as Node3D
	check(p != null and portals.is_open(ID), "its portal rises in the Void")
	if p == null:
		return
	check(p.get_node_or_null("Fault Line") != null, "...out of the long glowing fault line")
	var w: Dictionary = portals.world(ID)
	var ground: Vector3 = rem.ground_at(w.at)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	var lab := Vector2(99, -16)
	check(w.at.distance_to(lab) < 22.0 and w.at.x > lab.x + 8.0, "...just past the hedge behind Rex and Dash's lab (%.0f m)" % w.at.distance_to(lab))
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot((lab - w.at).normalized()) > 0.9, "...facing back past the lab, towards town")
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
	# Nothing solid on the fault line between the portal and the lab
	var fault_clear := true
	for k in 4:
		var at: Vector3 = p.to_global(Vector3(0, 0, 2.0 + k))
		var fq := PhysicsShapeQueryParameters3D.new()
		var fs := SphereShape3D.new()
		fs.radius = 0.6
		fq.shape = fs
		fq.transform = Transform3D(Basis(), at + Vector3(0, 1.0, 0))
		var hits := space.intersect_shape(fq, 4).filter(func(h: Dictionary) -> bool: return not (h.collider as Node).is_in_group("player"))
		if not hits.is_empty():
			fault_clear = false
			print("  (on the fault line at %s: %s)" % [at, (hits[0].collider as Node).get_path()])
	check(fault_clear, "the fault line runs over open ground")
	var nearest := INF
	var tracks: Dictionary = races.TRACKS
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
	var apart := INF
	for o in portals.WORLDS:
		if o.id != ID and portals.is_built(o.id):
			apart = minf(apart, w.at.distance_to(o.at))
	check(apart > 20.0, "...and well apart from the other portals (%.0f m)" % apart)
	check(portals._portal_offer(ID) == "step through to The Far Future", "it offers a trip to the Far Future (%s)" % portals._portal_offer(ID))


func _check_inside() -> void:
	portals.enter(ID)
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == ID, "stepping through takes you to the Far Future")
	var names := ["WayHome/Way Home/Spot", "TimeStone/Time Stone/Spot", "Vein1/Remnant Vein/Spot", "Rex/Model", "Rex/Spot",
		"Dash/Model", "Dash/Spot", "SwapOTron/Swap-o-Tron", "Captain Glitch", "Captain Glitch/Visual/Chest Clock",
		"Tomorrow Clock", "Dash's Lab", "Fading Plaza", "Skyway", "Skyline", "Hover Traffic", "Race skyway_run"]
	for i in 3:
		names.append("Fuse%d/Fuse" % (i + 1))
		names.append("Fuse%d/Spot" % (i + 1))
		names.append("Socket%d/Core" % (i + 1))
	for i in 2:
		names.append("Lift%d/Pad" % (i + 1))
		names.append("Lift%d/Spot" % (i + 1))
	for i in 6:
		names.append("Folk%d/Model" % (i + 1))
		names.append("Folk%d/Spot" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "the Far Future has %s" % n)
	var player := _player()
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["TimeStone", "WayHome", "Vein1", "Rex", "Dash", "SwapOTron", "Fuse1", "Fuse2", "Fuse3", "Lift1", "Lift2",
			"Lift1Top", "Lift2Top", "Folk1", "Folk2", "Folk3", "Folk4", "Folk5", "Folk6", "Captain", "Socket1"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	for n in ["Rex", "Dash", "Folk1", "Folk2", "Folk3", "Folk4", "Folk5", "Folk6", "Lift1Top", "Lift2Top"]:
		var at := (s.get_node(n) as Node3D).global_position + Vector3(0, 1.0, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.35
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, at)
		q.exclude = [player.get_rid()]
		var hits := space.intersect_shape(q, 4).filter(func(h: Dictionary) -> bool:
			return not (s.get_node(n) as Node).is_ancestor_of(h.collider))
		check(hits.is_empty(), "%s isn't standing inside anything" % n)
	# Fading: washed out and dim, and this copy's look is its own
	check(s.cores() == 0 and absf(s.fade - s.FADED) < 0.01, "no cores yet, and the city's badly faded (%.2f)" % s.fade)
	var env: Environment = (s.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(env.adjustment_enabled and env.adjustment_saturation < 0.4, "...its colours washed out (saturation %.2f)" % env.adjustment_saturation)
	check(s._neon.size() > 5 and float((s._neon[0][0] as StandardMaterial3D).emission_energy_multiplier) < float(s._neon[0][1]) * 0.5,
		"...and its neon dimmed (%d neon materials)" % s._neon.size())
	var fresh := (load(WORLD) as PackedScene).instantiate()
	var fresh_env: Environment = (fresh.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(fresh_env != env and fresh_env.adjustment_saturation == 1.0, "this copy's fading doesn't change the portal's preview")
	fresh.free()
	var blinked := false
	for i in 240:
		await process_frame
		for t in s._towers:
			if not (t as Node3D).visible:
				blinked = true
		if blinked:
			break
	check(blinked, "the far towers flicker out of time")
	# Rex and Dash
	var first: Array = s.rex_lines()
	check("Far Future" in str(first[0]) and "Time Core" in " ".join(first) and "FADING" in " ".join(first), "Rex says hello, that it's fading, and the cores")
	check("Still to do" in " ".join(s.rex_lines()), "...and after that, what's left to do")
	var dash: Array = s.dash_lines()
	check("Swap-o-Tron" in " ".join(dash) and "Chrono Fuse" in " ".join(dash) and "gallery" in " ".join(dash), "Dash explains the fuses in his lab")
	check(s.get_node("Rex/Spot").what() == "talk to Rex" and s.get_node("Dash/Spot").what() == "talk to Dash", "you can talk to them")
	var lab := (s.get_node("Dash's Lab") as Node3D).global_position
	check((s.get_node("Dash") as Node3D).global_position.distance_to(lab) < 8.0, "Dash is in his lab")
	var cap := s.get_node("Captain Glitch") as Node
	check(cap.process_mode == Node.PROCESS_MODE_DISABLED and not s.captain_awake, "Captain Glitch is a flickering statue for now")


func _check_fuses() -> void:
	var s := current_scene
	var player := _player()
	check(not s.swap_o_tron_on(), "the Swap-o-Tron's dead")
	# The hover lifts
	for i in 2:
		var pad := (s.get_node("Lift%d" % (i + 1)) as Node3D).global_position
		player.global_position = pad + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		await _physics(4)
		check(s.get_node("Lift%d/Spot" % (i + 1)).what() == "ride the hover lift up", "hover lift %d offers a ride up" % (i + 1))
		s.get_node("Lift%d/Spot" % (i + 1)).use()
		check(player.input_locked, "...holding you while it lifts")
		await create_timer(s.LIFT_TIME + 0.3).timeout
		await _physics(20)
		var top := (s.get_node("Lift%dTop" % (i + 1)) as Node3D).global_position
		check(not player.input_locked and player.is_on_floor() and player.global_position.distance_to(top + Vector3(0, 0.9, 0)) < 1.2,
			"...and sets you down up top (%.1f m up)" % top.y)
	var fuse2 := (s.get_node("Fuse2") as Node3D).global_position
	var g1 := (s.get_node("Lift1Top") as Node3D).global_position
	check(Vector2(fuse2.x - g1.x, fuse2.z - g1.z).length() < 4.0 and absf(fuse2.y - g1.y) < 0.3, "the gallery fuse is a short walk from the lift")
	var fuse3 := (s.get_node("Fuse3") as Node3D).global_position
	var g2 := (s.get_node("Lift2Top") as Node3D).global_position
	check(absf(fuse3.y - g2.y) < 0.3, "the roof fuse is on the roof, with the lift's top")
	# Fix them: by hand, by hand, by bubble
	check(s.get_node("Fuse1/Spot").what() == "fit a new Chrono Fuse", "a blown fuse offers a new one")
	s.get_node("Fuse1/Spot").use()
	check(s.is_fuse_fixed(0) and s.get_node("Fuse1/Spot").what() == "", "one fixed")
	s.get_node("Fuse2/Spot").use()
	check(s.fuses_fixed() == 2 and not s.is_core_home(0), "two: not yet")
	check((s.get_node("Fuse3/Hit") as Node).shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit", "a bubble fits the third")
	check((s.get_node("Fuse3/Hit") as Node).shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "...and bounces off once it's in")
	check(s.swap_o_tron_on() and s.is_core_home(0) and s.cores() == 1, "all three: the Swap-o-Tron hums and the first core's home")
	check(s.get_node_or_null("Socket1/Core/Glow Ball") != null, "...glowing in its socket on the clock")
	await create_timer(2.3).timeout
	check(s.fade < s.FADED - 0.1, "the city brightens a little (%.2f)" % s.fade)


func _check_folk() -> void:
	var s := current_scene
	var player := _player()
	# The hover steps up to the balcony are easy hops
	var prev := (s.get_node("Fading Plaza") as Node3D).global_position.y
	var worst := 0.0
	var gap := 0.0
	var last := Vector3.ZERO
	for i in 4:
		var st := s.get_node("Fading Plaza/Hover Step %d" % (i + 1)) as Node3D
		var p := st.global_position
		worst = maxf(worst, p.y + 0.11 - prev)
		if i > 0:
			gap = maxf(gap, Vector2(p.x - last.x, p.z - last.z).length())
		prev = p.y + 0.11
		last = p
	var bal := (s.get_node("Folk5") as Node3D).global_position
	worst = maxf(worst, bal.y - prev)
	check(worst < 1.3 and gap < 2.6, "the hover steps up to the balcony are short hops (highest %.2f m, widest %.1f m)" % [worst, gap])
	# Walking up pins someone; a bubble pins someone; a pinned one talks
	var f1 := (s.get_node("Folk1") as Node3D).global_position
	player.global_position = f1 + Vector3(4.0, 0.9, 0)
	await _physics(4)
	check(not s.is_pinned(0), "a few steps off, they're still fading")
	player.global_position = f1 + Vector3(1.4, 0.9, 0)
	await _frames(3)
	check(s.is_pinned(0) and (s.get_node("Folk1/Model") as Node3D).visible, "walk right up and your watch pins them back into time")
	check(not (s.get_node("Folk1/Fading") as Node3D).visible, "...and they stop fading")
	check((s.get_node("Folk5/Hit") as Node).shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit" and s.is_pinned(4), "a bubble pins one up on the balcony")
	check(s.get_node("Folk1/Spot").what() == "talk to Juno", "a pinned one's happy to talk")
	for i in 6:
		if not s.is_pinned(i):
			s.pin(i)
	check(s.pinned() == 6 and s.is_core_home(2) and s.cores() == 2, "all six: the third core's home")
	root.get_node("Dialogue").end()


func _check_race() -> void:
	var s := current_scene
	var t: Node3D = races.track_node("skyway_run")
	for k in 30:
		if t and t.ready_to_race:
			break
		await physics_frame
	check(t != null and t.ready_to_race, "the Skyway Run is laid out in the Far Future")
	if t == null:
		return
	check(races.unlocked("skyway_run") and races.track_node("lake_loop") == null, "it's open, and the Void's tracks aren't here")
	var low := 0
	for a in t.line:
		if absf(a.y - 10.0) > 0.2:
			low += 1
	check(low == 0, "the whole racing line lies on the Skyway's deck, ten metres up (%d points off it)" % low)
	var L: float = t.length
	check(L > 220.0 and L < 420.0, "a lap is a good length (%.0f m)" % L)
	var space: PhysicsDirectSpaceState3D = (s as Node3D).get_world_3d().direct_space_state
	var blocked: Array[String] = []
	var edges := 0
	for i in t.line.size():
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 1) % t.line.size()]
		for side in [-3.0, 0.0, 3.0]:
			var off: Vector3 = t.side_at(t.dist[i]) * side
			for h in [0.6, 1.3]:
				var q := PhysicsRayQueryParameters3D.create(a + off + Vector3.UP * h, b + off + Vector3.UP * h)
				q.exclude = [_player().get_rid()]
				var hit: Dictionary = space.intersect_ray(q)
				if not hit.is_empty() and hit.collider is StaticBody3D and blocked.size() < 12:
					blocked.append("%s at (%.0f, %.0f)" % [(hit.collider as Node).name, a.x, a.z])
			# the deck's under every lane
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(a + off + Vector3.UP * 0.5, a + off + Vector3.DOWN * 1.0))
			if down.is_empty():
				edges += 1
	check(blocked.is_empty(), "nothing in the way, in any lane (%s)" % ", ".join(blocked))
	check(edges == 0, "...and there's deck under every lane all the way round (%d gaps)" % edges)
	var starter := t.get_node_or_null("Countdown") as Node3D
	check(starter != null and starter.global_position.y < 1.0, "Countdown starts it, on the ground under the sky road")
	if starter:
		var q := PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.4
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, starter.global_position + Vector3(0, 1.0, 0))
		var hits := space.intersect_shape(q, 4).filter(func(h: Dictionary) -> bool: return not starter.is_ancestor_of(h.collider) and not t.is_ancestor_of(h.collider))
		check(hits.is_empty(), "...not standing inside anything")
		var fade_sp := (s.get_node("Fading Plaza") as Node3D).global_position
		check(Vector2(starter.global_position.x - fade_sp.x, starter.global_position.z - fade_sp.z).length() > 13.0, "...and off the plaza")
	# A whole race
	var p := _player()
	p.global_position = t.point_at(-3.0) + Vector3.UP * 0.9
	await _physics(4)
	check(races.start("skyway_run"), "saying go to Countdown starts the race")
	check(p.global_position.y > 9.5, "...up on the grid on the sky road")
	await _physics(int(races.COUNTDOWN * 60) + 10)
	check(races.state == races.State.RACING, "GO: the race is on")
	check(not (s.get_node("Rex") as Node3D).visible, "(Rex and Dash are racing, so they're not by the way in too)")
	# Fall off: popped back up
	p.global_position = Vector3(t.line[10].x + 12.0, 1.0, t.line[10].z)
	await _frames(3)
	check(p.global_position.y > 9.5, "fall off the Skyway mid-race and you're popped back up onto it")
	for lap in int(races.TRACKS.skyway_run.laps):
		for i in range(1, t.cp_dist.size() + 1):
			var d: float = t.cp_dist[i % t.cp_dist.size()]
			p.global_position = t.point_at(d - 2.0) + Vector3.UP * 0.85
			p.velocity = t.dir_at(d) * 7.0
			await _physics(4)
			p.global_position = t.point_at(d) + Vector3.UP * 0.85
			await _physics(3)
			if races.state != races.State.RACING:
				break
	check(races.state == races.State.RESULTS, "two laps and it's finished")
	await _frames(2)
	check(s.is_core_home(1) and s.cores() == 3, "finishing brings the second core home: all three")
	await _physics(int(races.RESULTS_TIME * 60) + 20)
	if game.riding:
		game.toggle_skateboard()
	await _physics(10)
	check((s.get_node("Rex") as Node3D).visible, "Rex is back by the way in")


func _check_captain() -> void:
	var s := current_scene
	var player := _player()
	var c := s.get_node("Captain Glitch") as CharacterBody3D
	player.global_position = Vector3(0, 1.0, 40)
	await _physics(10)
	check(not s.captain_awake, "Captain Glitch sleeps on until you come near")
	var m := (s.get_node("Captain") as Node3D).global_position
	player.global_position = m + Vector3(0, 1.0, 10)
	await _frames(4)
	check(s.captain_awake and c.process_mode == Node.PROCESS_MODE_INHERIT, "with all three cores, he wakes up")
	check(c.get_node_or_null("BossMeter") != null and (c.get_node("BossMeter") as Node3D).visible, "...with his name over him")
	await _physics(20)
	check(c.global_position.y > m.y + 2.0, "he floats up off the dais")
	check(c.shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "in the air, bubbles bounce off his armour")
	# A volley of chaos bursts
	c.set("_timer", 0.0)
	await _physics(3)
	var bursts := s.find_children("*", "ChaosBurst", true, false).size()
	check(bursts >= 2, "he marks the ground with chaos bursts (%d)" % bursts)
	# Crash down: a ring to jump, and his clock glows
	c.set("_volleys", 99)
	c.call("_set_state", 2)                          # (SLAM)
	var landed := false
	for i in 60:
		await physics_frame
		if c.call("is_open"):
			landed = true
			break
	check(landed and absf(c.global_position.y - m.y) < 0.2, "he crashes down onto the dais, dazed")
	check(s.find_children("*", "ShockRing", true, false).size() > 0, "...with a ring rolling out to jump")
	check(c.shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit" and int(c.get("hits")) == 1, "while his clock glows, a bubble counts")
	# A stomp counts too
	player.global_position = c.global_position + Vector3(0, 4.6, 0)
	player.velocity = Vector3(0, -3.0, 0)
	c.call("_touch_player")
	check(int(c.get("hits")) == 2 and player.velocity.y > 5.0, "...and so does a stomp on his helmet (bouncing you off)")
	player.global_position = c.global_position + Vector3(0, 4.6, 0)
	player.velocity = Vector3(0, -3.0, 0)
	c.call("_touch_player")
	await _physics(2)
	check(int(c.get("hits")) == 3, "(three hits in one go)")
	await _physics(4)
	check(not c.call("is_open"), "three hits and he glitches back up into the air")
	check(c.get("minions").size() == 2, "at three hits he calls two Time Goblins out of a rift")
	var before: int = rem.count
	player.global_position = Vector3(0, 1.0, 40)
	while not c.get("defeated"):
		c.call("_set_state", 3)                      # (OPEN)
		c.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared(ID), "popping Captain Glitch mends the Far Future")
	check(rem.count == before + int(portals.world(ID).reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(c.get("minions").filter(func(g) -> bool: return is_instance_valid(g) and g.get("defeated") != true).is_empty(), "...and his goblins pop with him")
	await create_timer(s.THANKS_AFTER + 0.4).timeout
	check(s.fade < 0.01, "the colour floods back and every light comes on (%.2f)" % s.fade)
	var env: Environment = (s.get_node("WorldEnvironment") as WorldEnvironment).environment
	check(env.adjustment_saturation > 1.0, "...brighter than ever")
	var all_on := true
	for t in s._towers:
		all_on = all_on and (t as Node3D).visible
	check(all_on, "...and the far towers stop flickering")
	check("Void" in " ".join(s.thank_lines()) and "Agent of Chaos" in " ".join(s.thank_lines()) and "body" in " ".join(s.thank_lines()),
		"Rex thanks you: the captain's fled to the Void, his master's waiting, and maybe his own body")
	check(root.get_node("Dialogue").is_active(), "Rex thanks you")
	root.get_node("Dialogue").end()
	check("Swap-o-Tron" in " ".join(s.dash_lines()) and "Lumen City" in " ".join(s.rex_lines()), "they talk about the mended city after")


func _check_home() -> void:
	portals.time_left = 0.4
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "when time's up you go home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal far_future") as Node3D
	check(p != null and _player().global_position.distance_to(p.global_position) < 6.0, "...right by the Far Future's portal")
	portals.enter(ID)
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.cores() == 3 and s.get_node_or_null("Captain Glitch") == null and s.fade < 0.01,
		"going back, it's all still done, and the city's bright")
	check(s.swap_o_tron_on() and s.pinned() == 6, "the Swap-o-Tron's on and everyone's in time")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared(ID) and portals.found == found and portals.is_open(ID), "the Far Future's progress loads back")


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
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)
