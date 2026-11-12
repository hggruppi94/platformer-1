extends SceneTree

# Checks the new enemies out in the Void (scripts/wilds.gd, scripts/glorp.gd, scripts/fizzler.gd, and shadow ghosts in
# the Spooky Woods at night). Glorp Meadow and the Static Field are on flat, dry ground, off the paths, races and trees,
# and on the map. A Glorp really splits: the big one into two, each of those into two, and the littlest pop for good,
# while the first comes back later. A stomp pops a Glorp too. Fizzlers zip about, zap a ring of static when you're close
# (only a bump, and only if you're on the ground), sometimes blink away from a bubble, pop, and come back. At night six
# shadow ghosts come out in the Spooky Woods, a new lot each night, and they fade away in the morning.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_wilds.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.wilds_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.wilds_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var wilds: Node
var bosses: Node
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
	wilds = root.get_node("Wilds")
	bosses = root.get_node("Bosses")
	clock = root.get_node("Clock")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	clock.set("pulls_home", false)
	clock.minutes = 12 * 60.0

	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(10)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	p.global_position = Vector3(0, 30, 0)                        # (well out of the way while things are looked at)

	# --- Where they live ---
	var meadow := town.get_node_or_null("Glorp Meadow") as Node3D
	var field := town.get_node_or_null("Static Field") as Node3D
	check(meadow != null and meadow.get("label") == "Glorp Meadow", "Glorp Meadow is in the Void, on the map")
	check(field != null and field.get("label") == "Static Field", "the Static Field is in the Void, on the map")
	check(field.find_child("Fizzing Crack", true, false) != null, "...with a fizzing crack in the ground")
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var trees := town.find_child("Trees", true, false) as Node3D
	var races := root.get_node("Races")
	for spot in [["Glorp Meadow", wilds.MEADOW, wilds.GLORP_SPOTS], ["the Static Field", wilds.FIELD, wilds.FIZZLER_SPOTS]]:
		var at: Vector2 = spot[1]
		var lo := INF
		var hi := -INF
		for q in spot[2]:
			var g: Vector3 = bosses.ground(town, q.x, q.y)
			lo = minf(lo, g.y)
			hi = maxf(hi, g.y)
		check(hi - lo < 1.2, "%s's spots are on flat ground (%.2f m up and down)" % [spot[0], hi - lo])
		var wet := false
		for w in get_nodes_in_group("water"):
			for q in spot[2]:
				if w.has_method("covers") and w.covers(q.x, q.y):
					wet = true
		check(not wet, "...and dry")
		var path := INF
		for l in places.links:
			var pa: Array = places.points[l[0]]
			var pb: Array = places.points[l[1]]
			var a2 := Vector2(pa[0], pa[pa.size() - 1])
			var b2 := Vector2(pb[0], pb[pb.size() - 1])
			var kk := 0.0 if a2 == b2 else clampf((at - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
			path = minf(path, at.distance_to(a2.lerp(b2, kk)))
		check(path > 12.0, "...well off the townsfolk's paths (%.0f m)" % path)
		var race := INF
		for id in races.TRACKS:
			var t: Dictionary = races.TRACKS[id]
			if t.has("points"):
				for q in t.points:
					race = minf(race, at.distance_to(Vector2(q.x, q.z) if q is Vector3 else Vector2(q)))
		check(race > 14.0, "...and the race tracks (%.0f m)" % race)
		var tree := INF
		for tp in trees.get("positions"):
			var tg: Vector3 = trees.global_transform * tp
			for q in spot[2]:
				tree = minf(tree, (q as Vector2).distance_to(Vector2(tg.x, tg.z)))
		check(tree > 3.0, "...and no tree right on top of one (nearest %.1f m)" % tree)
	var portals := root.get_node("Portals")
	var near := INF
	for w in portals.WORLDS:
		for c in [wilds.MEADOW, wilds.FIELD]:
			near = minf(near, (c as Vector2).distance_to(w.at))
	check(near > 20.0, "both are clear of every portal (%.0f m)" % near)

	# --- Glorps ---
	var glorps := meadow.get_children().filter(func(n: Node) -> bool: return n.is_in_group("glorps"))
	check(glorps.size() == 4, "four Glorps in the meadow (%d)" % glorps.size())
	var g0 := glorps[0] as CharacterBody3D
	await _physics(30)
	check(g0.is_on_floor() or absf(g0.global_position.y - bosses.ground(town, g0.global_position.x, g0.global_position.z).y) < 0.8,
		"...sitting on the ground")
	check(absf(float(g0.get("size")) - 1.5) < 0.01, "...big ones")
	var goo: Array = g0.get("_goo")
	var main: Color = (goo[0] as ShaderMaterial).get_shader_parameter("green")
	check(main.b > main.g, "...in purple goo, not a Gloop's green")
	var home: Vector3 = g0.get("home")
	g0.call("shot", 1, g0.global_position, Vector3(1, 0, 0))
	await _physics(4)
	var bits := meadow.get_children().filter(func(n: Node) -> bool: return n.is_in_group("glorps") and str(n.name).begins_with("Glorp Bit") \
		and not bool(n.get("defeated")))
	check(bits.size() == 2, "popping a big Glorp splits it into two (%d)" % bits.size())
	check(bits.all(func(b: Node) -> bool: return absf(float(b.get("size")) - 0.99) < 0.01 and not bool(b.get("respawns"))),
		"...each two-thirds its size, and they don't come back once popped")
	await _physics(30)
	check(bits.all(func(b: Node) -> bool: return (b as Node3D).global_position.distance_to(g0.global_position) > 0.5),
		"...and they bounce apart")
	(bits[0] as Node).call("shot", 1, Vector3.ZERO, Vector3(1, 0, 0))
	await _physics(4)
	var littles := meadow.get_children().filter(func(n: Node) -> bool: return n.is_in_group("glorps") \
		and absf(float(n.get("size")) - 0.6534) < 0.01 and not bool(n.get("defeated")))
	check(littles.size() == 2, "a middle-sized one splits again, into two little ones (%d)" % littles.size())
	var before := meadow.get_children().filter(func(n: Node) -> bool: return n.is_in_group("glorps") and not bool(n.get("defeated"))).size()
	(littles[0] as Node).call("shot", 1, Vector3.ZERO, Vector3(1, 0, 0))
	await _physics(4)
	var after := meadow.get_children().filter(func(n: Node) -> bool: return n.is_in_group("glorps") and not bool(n.get("defeated"))).size()
	check(after == before - 1, "...and the littlest pop for good")
	# A stomp
	var l2 := littles[1] as CharacterBody3D
	p.global_position = l2.global_position + Vector3(0, 1.6, 0)
	p.velocity = Vector3(0, -3, 0)
	var stomped := false
	for i in 60:
		await physics_frame
		if bool(l2.get("defeated")):
			stomped = true
			break
	check(stomped, "jumping on a Glorp pops it")
	p.global_position = Vector3(0, 30, 0)
	g0.set("respawn_clear", 0.0)
	(g0.get("_respawn_timer") as Timer).start(0.2)
	await create_timer(0.5).timeout
	check(not bool(g0.get("defeated")) and g0.global_position.distance_to(home) < 0.6, "the first big Glorp comes back later, at home")

	# --- Fizzlers ---
	var fizz := field.get_children().filter(func(n: Node) -> bool: return n.is_in_group("fizzlers"))
	check(fizz.size() == 5, "five Fizzlers in the Static Field (%d)" % fizz.size())
	var f0 := fizz[0] as CharacterBody3D
	var f_home: Vector3 = f0.get("home")
	await _physics(60)
	check(f0.global_position.distance_to(f_home) < 9.0, "...zipping about near home")
	var hover: float = f0.global_position.y - bosses.ground(town, f0.global_position.x, f0.global_position.z).y
	check(hover > -0.3 and hover < 0.6, "...floating at its own height (origin %.2f m off the ground)" % hover)
	# Up close it crackles up and lets off a ring of static
	for f in fizz:
		(f as Node).process_mode = Node.PROCESS_MODE_DISABLED if f != f0 else Node.PROCESS_MODE_INHERIT
	f0.set("_zap_cd", 0.0)
	var gnd := bosses.ground(town, f0.global_position.x + 2.0, f0.global_position.z) as Vector3
	p.global_position = gnd + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	var charged := false
	var ringed := false
	for i in 120:
		await physics_frame
		p.global_position = Vector3(f0.global_position.x + 2.0, p.global_position.y, f0.global_position.z)
		charged = charged or float(f0.get("charging")) > 0.0
		if town.find_children("ShockRing", "", true, false).size() > 0:
			ringed = true
			break
	check(charged and ringed, "close up, a Fizzler crackles up and lets off a ring of static to jump")
	p.global_position = Vector3(0, 30, 0)
	# Bubbles: sometimes it blinks away
	f0.set("blink_chance", 1.0)
	f0.set("_blink_wait", 0.0)
	var was := f0.global_position
	check(str(f0.call("shot", 1, f0.global_position, Vector3(1, 0, 0))) == "miss" and f0.global_position.distance_to(was) > 1.0,
		"now and then it blinks away from a bubble")
	f0.set("blink_chance", 0.0)
	var xp: int = game.xp + game.level * 100000
	check(str(f0.call("shot", 1, f0.global_position, Vector3(1, 0, 0))) == "hit" and bool(f0.get("defeated")), "...but a bubble pops it")
	check(game.xp + game.level * 100000 > xp, "...for some XP")
	f0.set("respawn_clear", 0.0)
	f0.set("_respawn_left", 0.05)
	await _physics(10)
	check(not bool(f0.get("defeated")) and f0.global_position.distance_to(f_home) < 0.6, "...and it comes back later")
	for f in fizz:
		(f as Node).process_mode = Node.PROCESS_MODE_INHERIT

	# --- Shadow ghosts at night ---
	check(wilds.ghosts_now() == 0, "by day there are no shadow ghosts in the woods")
	clock.minutes = 22 * 60.0
	await create_timer(2.4).timeout
	check(clock.is_night() and wilds.ghosts_now() == 6, "at night six come out in the Spooky Woods (%d)" % wilds.ghosts_now())
	var ghost := town.get_node("Night Ghosts").get_child(0) as Node3D
	var gg: Vector3 = bosses.ground(town, ghost.global_position.x, ghost.global_position.z)
	check(Vector2(ghost.global_position.x, ghost.global_position.z).distance_to(wilds.WOODS) < 25.0, "...among the trees")
	check(absf(ghost.global_position.y - gg.y) < 1.0, "...floating over the ground")
	ghost.call("pop")
	await create_timer(3.0).timeout
	check(wilds.ghosts_now() == 5, "popping one takes it away for the night (%d)" % wilds.ghosts_now())
	clock.minutes = 6 * 60.0 + 30.0
	clock.day += 1
	await create_timer(2.4).timeout
	await create_timer(1.0).timeout
	check(not clock.is_night() and wilds.ghosts_now() == 0, "in the morning they fade away")
	clock.minutes = 22 * 60.0
	await create_timer(2.4).timeout
	check(wilds.ghosts_now() == 6, "...and a whole new lot comes out the next night")
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
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
