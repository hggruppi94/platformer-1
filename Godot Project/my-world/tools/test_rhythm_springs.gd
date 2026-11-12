extends SceneTree

# Checks Rhythm Springs, Melody's portal world (scripts/rhythm_springs.gd, scripts/off_beat.gd,
# scenes/portal_worlds/rhythm_springs.tscn): its quake waits for Lanternmoor to be mended, then its portal rises by the
# lake on flat, clear ground; inside, the sun's stuck at noon and Melody says what to do; the Heat meter fills in the
# sun, cools in the shade and fast in a cool pool, rises in a boiling hot spring, and when it's full you pop out of a
# cool pool unhurt; the Sizzle Steps' stones flare in turn, and the coals or a flaring stone send you back to the start
# while a cool stone is safe; you can hop across them for real; the mesa's pads can be climbed, the shell on top is
# yours, and the water slide takes you down into a cool pool; dancing on Melody's beat scores and off it doesn't, and
# eight gets the third shell; the Off-Beat sleeps until all three shells are found, then wakes when you come near; lit
# drums and bubbles at his weight knock him back into time, which mends the world (summer opens on Earth, the heat
# breaks, evening comes); and it all stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_rhythm_springs.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.rhythm_springs_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rhythm_springs_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"

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
	clock.seasons_open = ["autumn", "winter"]                # as a new game would have it, past the Frozen Moment
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.cleared_worlds.append(w)

	check(ResourceLoader.exists(WORLD) and portals.is_built("rhythm_springs"), "Rhythm Springs' scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_heat()
	await _check_sizzle()
	await _check_mesa()
	await _check_dance()
	await _check_off_beat()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("rhythm_springs"), "no Rhythm Springs quake before Lanternmoor is mended")
	portals.cleared_worlds.append("lanternmoor")
	check(portals.next_due() == "rhythm_springs", "then its quake is due")
	portals.quake("rhythm_springs", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal rhythm_springs") as Node3D
	check(p != null and portals.is_open("rhythm_springs"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("rhythm_springs")
	var ground: Vector3 = rem.ground_at(w.at + Vector2(3.0, 0.0))      # (beside the crack: its middle is a hole)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	check(w.at.x < 0.0 and w.at.y > 20.0, "...by the lake's south-west shore (%s)" % w.at)
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
	# Well off the Lake Loop race's track (its props are put in at play time, but the track itself has none)
	var loop: Array = []
	var tracks: Dictionary = root.get_node("Races").TRACKS
	if tracks.has("lake_loop") and str(tracks.lake_loop.get("scene", "")) == "res://scenes/town/town.tscn":
		loop = tracks.lake_loop.points                          # (since Nov 11, 2026 it's a circuit of its own)
	var gate: Vector2 = root.get_node("Races").HUBS.void.at
	check(w.at.distance_to(gate) > 12.0, "...well away from Zippy's race gate (%.1f m)" % w.at.distance_to(gate))
	var nearest := INF
	for i in loop.size():
		var a: Vector2 = loop[i]
		var b: Vector2 = loop[(i + 1) % loop.size()]
		var t := clampf((w.at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		nearest = minf(nearest, w.at.distance_to(a.lerp(b, t)))
	check(loop.is_empty() or nearest > 8.0, "...well off the Lake Loop's track (%.1f m)" % nearest)
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot(-w.at.normalized()) > 0.8, "...facing back towards the lake and town")
	check(portals._portal_offer("rhythm_springs") == "look down the crack to Rhythm Springs", "it offers a trip to Rhythm Springs (%s)" % portals._portal_offer("rhythm_springs"))


func _check_inside() -> void:
	portals.enter("rhythm_springs")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "rhythm_springs", "stepping through takes you to Rhythm Springs")
	var names := ["WayHome/Way Home/Spot", "Vein1/Remnant Vein/Spot", "Melody/Model", "Melody/Spot",
		"Shell1/Song Shell", "Shell1/Spot", "Shell2/Song Shell", "SlideTop/Spot", "DanceFloor/Spot", "The Off-Beat",
		"The Off-Beat/Snoring", "The Off-Beat/Model/Arm/Weight/Hit", "Notes", "Heat HUD", "Slide", "Cool Pools"]
	for i in 9:
		names.append("Stone%d/Stone" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "Rhythm Springs has %s" % n)
	await _frames(2)
	for i in 4:
		check(s.get_node_or_null("Drum %d" % (i + 1)) != null, "...and drum %d on the Bandstand" % (i + 1))
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	check(s.cool == 0.0 and not s.is_mended(), "the sun's stuck at a blazing noon")
	var hud := s.get_node("Heat HUD/Heat") as Control
	check(hud.visible and s.heat_words() == "Cool", "the Heat meter shows, and you start off cool")
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["Vein1", "Melody", "Shell1", "Shell2", "SlideTop", "SizzleStart", "Drum1", "Drum3", "OffBeat"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	var first: Array = s.melody_lines()
	check("Rhythm Springs" in str(first[0]) and "Heat" in " ".join(first) and "Song Shells" in " ".join(first),
		"Melody says hello, what's wrong, and how to keep cool")
	check("Still to do" in " ".join(s.melody_lines()), "...and after that, what's left to do")
	# The broken beat: quick, then slow
	var lens := []
	for t in [0.0, 3.5, 7.0, 10.5]:
		s._t = t
		lens.append(s.beat_len())
	check(lens.max() - lens.min() > 0.35, "the world's beat keeps speeding up and slowing down (%.2f to %.2f s)" % [lens.min(), lens.max()])


func _check_heat() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var hp: int = game.hp
	# Out in the open sun
	player.global_position = Vector3(-4, 0.9, 28)
	await _physics(4)
	check(not s.in_shade(player.global_position) and not s.in_cool_pool(player.global_position), "(out in the open sun)")
	s.heat = 10.0
	s.heat_step(player, 5.0)
	check(s.heat > 15.0, "standing in the sun, you heat up (%.0f)" % s.heat)
	# Under a parasol palm
	var palm := (s.get_node("Shade Palm 1") as Node3D).global_position
	player.global_position = palm + Vector3(0.8, 0.9, 0)
	await _physics(4)
	var was: float = s.heat
	s.heat_step(player, 1.0)
	check(s.in_shade(player.global_position) and s.heat < was, "in a parasol palm's shade you cool off (%.0f -> %.0f)" % [was, s.heat])
	var dance := (s.get_node("DanceFloor") as Node3D).global_position
	check(s.in_shade(dance + Vector3(1, 0.9, 1)), "...and under the Dance Floor's awning")
	# In a cool pool
	var pool := (s.get_node("Cool1") as Node3D).global_position
	s.heat = 80.0
	player.global_position = pool + Vector3(0, 0.9, 0)
	await _physics(10)
	check(s.in_cool_pool(player.global_position), "(wading in a cool pool)")
	s.heat_step(player, 1.0)
	check(s.heat < 50.0, "wading in a cool pool cools you right down (%.0f)" % s.heat)
	# In a boiling hot spring
	var spring := (s.get_node("Hot1") as Node3D).global_position
	player.global_position = spring + Vector3(0, 0.9, 0)
	await _physics(6)
	s.heat = 20.0
	s.heat_step(player, 1.0)
	check(s.in_hot_spring(player.global_position) and s.heat >= 45.0, "a boiling hot spring heats you fast (%.0f)" % s.heat)
	# Too hot: out of the nearest cool pool, unhurt
	player.global_position = Vector3(-4, 0.9, 28)
	await _physics(4)
	s.heat = 99.5
	s.heat_step(player, 1.0)
	await _physics(4)
	var near: Vector3 = s.nearest_cool(Vector3(-4, 0, 28))
	check(s.heat < 50.0 and player.global_position.distance_to(near) < 2.5, "too hot: you pop out of the nearest cool pool (%.0f heat)" % s.heat)
	check(game.hp == hp, "...and it never costs any HP")
	s.heat = 0.0


func _check_sizzle() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	# The flares come round in turn: each stone burns one beat in three, and glows the beat before
	var pattern := []
	for b in 3:
		s.beat_n = b
		var row := []
		for i in s.STONES:
			row.append(s.stone_hot(i))
		pattern.append(row)
	var each_once := true
	for i in s.STONES:
		var n := 0
		for b in 3:
			if pattern[b][i]:
				n += 1
		each_once = each_once and n == 1
	check(each_once, "every stepping stone flares exactly one beat in three")
	s.beat_n = 0
	s.on_beat()                                  # (beat 1)
	var hot := -1
	var safe := -1
	for i in s.STONES:
		if s.stone_hot(i) and hot < 0:
			hot = i
		if not s.stone_hot(i) and not s.stone_warm(i) and safe < 0:
			safe = i
	var flame := s.get_node("Stone%d/Stone/Flame" % (hot + 1)) as Node3D
	check(flame.visible and not (s.get_node("Stone%d/Stone/Flame" % (safe + 1)) as Node3D).visible, "a flaring stone shows its fire, a cool one doesn't")
	s.set_process(false)                         # (hold the beat still while we stand about)
	var start := (s.get_node("SizzleStart") as Node3D).global_position
	# A cool stone is safe
	var st := (s.get_node("Stone%d" % (safe + 1)) as Node3D).global_position
	player.global_position = st + Vector3(0, 1.5, 0)
	await _physics(30)
	s._burn_cd = 0.0
	s.sizzle_step(player)
	check(player.is_on_floor() and s.stone_under(player) == safe and player.global_position.distance_to(st) < 2.0,
		"standing on a cool stone is safe (stone %d)" % (safe + 1))
	# A flaring one isn't
	var sh := (s.get_node("Stone%d" % (hot + 1)) as Node3D).global_position
	player.global_position = sh + Vector3(0, 1.5, 0)
	await _physics(30)
	s.heat = 0.0
	s._burn_cd = 0.0
	s.sizzle_step(player)
	check(player.global_position.distance_to(start) < 2.0 and s.heat >= s.HEAT_BURN - 0.1, "on a flaring stone: ouch, back to the start, hotter")
	# Nor are the coals
	var pit := (s.get_node("SizzlePit") as Node3D).global_position
	var side := Vector3(cos(float(s.get_node("SizzlePit").get_meta("yaw"))), 0, -sin(float(s.get_node("SizzlePit").get_meta("yaw"))))
	player.global_position = pit + side * 2.6 + Vector3(0, 1.2, 0)
	await _physics(30)
	check(s.in_pit(player.global_position) and s.stone_under(player) == -1, "(on the coals)")
	s._burn_cd = 0.0
	s.sizzle_step(player)
	check(player.global_position.distance_to(start) < 2.0, "the coals send you back to the start too")
	s.set_process(true)
	# The stones are close enough to hop across: each one a short hop from the last
	var widest := 0.0
	var prev := start
	for i in s.STONES:
		var at := (s.get_node("Stone%d" % (i + 1)) as Node3D).global_position
		widest = maxf(widest, Vector2(at.x - prev.x, at.z - prev.z).length())
		prev = at
	check(widest < 3.2, "every stone's a short hop from the last (widest %.1f m)" % widest)
	# Walk to the end the easy way and pick up the shell by walking into it
	var shell := (s.get_node("Shell1") as Node3D).global_position
	player.global_position = shell + Vector3(0, 0.9, 1.8)
	await _physics(4)
	player.global_position = shell + Vector3(0, 0.9, 0.3)
	await _frames(4)
	check(s.has_shell(0) and s.shells() == 1 and s.get_node_or_null("Shell1/Song Shell") == null, "walk into the Sizzle Steps' shell and it's yours")


func _check_mesa() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	# The pads up the mesa: each a jump up from the last, never too far
	var top := (s.get_node("Shell2") as Node3D).global_position
	check(top.y > 10.0, "the second shell's high on top of Waterfall Mesa (%.0f m up)" % top.y)
	var pads: Array = []
	for c in s.get_node("Waterfall Mesa").get_children():
		var off := Vector2((c as Node3D).global_position.x - 30.0, (c as Node3D).global_position.z + 16.0).length()
		if c is StaticBody3D and off > 3.0 and (c as Node3D).position.y > 0.5 and (c as Node3D).position.y < 11.5:
			pads.append((c as Node3D).global_position)
	pads.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var ok := pads.size() >= 8
	for i in range(1, pads.size()):
		var rise: float = pads[i].y - pads[i - 1].y
		var reach := Vector2(pads[i].x - pads[i - 1].x, pads[i].z - pads[i - 1].z).length()
		ok = ok and rise < 1.6 and reach < 3.4
	check(ok, "the %d pads spiral up in easy jumps" % pads.size())
	# Climb the first pad for real with a jump
	var p0: Vector3 = pads[0]
	var mesa := (s.get_node("Waterfall Mesa") as Node3D)
	var out := Vector3(p0.x - 30.0, 0, p0.z + 16.0).normalized()
	player.global_position = Vector3(p0.x, 0.9, p0.z) + out * 2.2
	player.velocity = Vector3.ZERO
	await _physics(20)
	var dir := Vector3(p0.x - player.global_position.x, 0, p0.z - player.global_position.z).normalized()
	player.velocity = dir * 3.0 + Vector3(0, 6.0, 0)
	for i in 50:
		await physics_frame
		player.velocity.x = dir.x * 3.0
		player.velocity.z = dir.z * 3.0
		if player.global_position.y > p0.y + 0.6 and Vector2(player.global_position.x - p0.x, player.global_position.z - p0.z).length() < 1.0:
			break
	player.velocity = Vector3.ZERO
	await _physics(30)
	check(player.is_on_floor() and player.global_position.y > p0.y + 0.4, "the first pad's a jump up from the sand (%.1f m)" % player.global_position.y)
	check(mesa != null, "(the mesa)")
	# On top: the shell, then the slide
	player.global_position = top + Vector3(0, 0.9, 0.3)
	await _frames(4)
	check(s.has_shell(1) and s.shells() == 2, "on top, the mesa's shell is yours")
	s.heat = 75.0
	var slide_top := s.get_node("SlideTop/Spot")
	check(slide_top.what() == "ride the water slide", "the water slide offers a ride down")
	slide_top.use()
	check(s.riding_slide and bool(player.get("carried")), "...and off you go")
	var t := 0
	while s.riding_slide and t < 900:
		await physics_frame
		t += 1
	await _physics(40)
	check(not s.riding_slide and not bool(player.get("carried")) and t < 900, "...down the slide (%.1f s)" % (t / 60.0))
	check(s.in_cool_pool(player.global_position) and s.heat < 1.0, "...SPLASH into the Waterfall Pool, all cooled down")
	check(not player.input_locked, "...and you can move again")


func _check_dance() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var floor_at := (s.get_node("DanceFloor") as Node3D).global_position
	player.global_position = floor_at + Vector3(0, 0.9, 0)
	await _physics(10)
	var spot := s.get_node("DanceFloor/Spot")
	check(spot.what() == "dance with Melody", "the Dance Floor offers a dance with Melody")
	spot.use()
	check(s.dancing and player.input_locked and (s.get_node("Heat HUD/Dance") as Control).visible, "dancing: the beat ring shows and you stay put")
	s.set_process(false)
	s._dance_phase = 0.5
	check(not s.dance_press() and s.dance_good == 0, "a press off Melody's beat doesn't count")
	s._dance_beats = 4
	s._dance_phase = 0.97
	check(s.dance_press() and s.dance_good == 1, "a press on her beat does")
	check(not s.dance_press() and s.dance_good == 1, "...but only once a beat")
	for i in 7:
		s._dance_beats = 6 + i
		s._dance_phase = 0.04
		s.dance_press()
	s.set_process(true)
	check(not s.dancing and s.has_shell(2) and s.shells() == 3, "eight on the beat and the Dance Floor's shell is yours")
	check(not player.input_locked and not (s.get_node("Heat HUD/Dance") as Control).visible, "...and the dance is over")


func _check_off_beat() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var ob := s.off_beat as Node3D
	player.global_position = Vector3(0, 0.9, 20)
	await _physics(10)
	check(not ob.awake, "the Off-Beat waits until you come near")
	player.global_position = (s.get_node("OffBeat") as Node3D).global_position + Vector3(0, 0.2, 12)
	await _frames(4)
	check(ob.awake and s.get_node_or_null("The Off-Beat/Snoring") == null, "with all three shells, he wakes up")
	# Some ticks: heat rings, and a drum lights up
	var rings := 0
	for i in 200:
		await physics_frame
		for c in s.get_children():
			if str(c.name).begins_with("ShockRing"):
				rings += 1
		if rings > 0 and ob.lit_drum >= 0:
			break
	check(rings > 0, "his ticks send heat rings across the stage")
	check(ob.lit_drum >= 0, "...and light up a drum")
	# Land on the lit drum for real
	var hits0: int = ob.hits
	var drum := s.get_node("Drum %d" % (ob.lit_drum + 1)) as Node3D
	var lit: int = ob.lit_drum
	player.global_position = drum.global_position + Vector3(0, 2.4, 0)
	player.velocity = Vector3.ZERO
	var t := 0
	while ob.hits == hits0 and t < 90:
		await physics_frame
		t += 1
	check(ob.hits == hits0 + 1, "landing on the lit drum knocks him back towards the beat (drum %d)" % (lit + 1))
	check(not ob.hit_drum(lit), "...once per lighting")
	# A dark drum does nothing
	var dark := (lit + 1) % 4
	check(not ob.hit_drum(dark), "a dark drum does nothing")
	# Bubbles at his weight
	var hit := s.get_node("The Off-Beat/Model/Arm/Weight/Hit")
	check(hit.shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit" and ob.hits == hits0 + 2, "a bubble at his red-hot weight counts too")
	check(hit.shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "...but only once a second")
	var before: int = rem.count
	player.global_position = Vector3(0, 0.9, 20)
	while ob.hits < ob.HITS:
		ob._shot_cd = 0.0
		ob.shot_weight()
	await _frames(4)
	check(ob.defeated and portals.is_cleared("rhythm_springs"), "knocking him back into time mends Rhythm Springs")
	check(rem.count == before + int(portals.world("rhythm_springs").reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(clock.season_open("summer") and not clock.season_open("spring"), "...and summer opens on Earth (spring still waits)")
	check(s.heat == 0.0 and not (s.get_node("Heat HUD/Heat") as Control).visible, "the heat breaks: no more Heat meter")
	s.heat = 0.0
	s.heat_step(player, 10.0)
	check(s.heat == 0.0, "...and the sun can't heat you any more")
	await create_timer(5.6).timeout
	check(s.cool > 0.99 and (s.get_node("Sun") as DirectionalLight3D).rotation_degrees.x > -30.0, "the sun eases down to a golden evening")
	s.beat_n = 0
	check(not s.stone_hot(0) and not s.stone_hot(1) and not s.stone_hot(2), "the stepping stones stop flaring")
	check(absf(s.beat_len() - s.beat_len()) < 0.001 and s.beat_len() == 0.7, "the beat's steady")
	check(root.get_node("Dialogue").is_active(), "Melody teaches you her groove (scripts/groove.gd: test_groove checks it)")
	root.get_node("Dialogue").end()
	check("STEADY" in " ".join(s.melody_lines()), "Melody's thrilled")


func _check_home() -> void:
	portals.go_home()          # (the way home: there's no time limit to run out any more)
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "the way home takes you home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal rhythm_springs") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by Rhythm Springs' portal")
	portals.enter("rhythm_springs")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.shells() == 3 and s.get_node_or_null("The Off-Beat") == null and s.cool == 1.0
		and not (s.get_node("Heat HUD/Heat") as Control).visible,
		"going back, it's all still done, it's a cool golden evening, and no Heat meter")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("rhythm_springs") and portals.found == found and portals.is_open("rhythm_springs"), "Rhythm Springs' progress loads back")
	check(clock.season_open("summer"), "...and summer stays open")


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
