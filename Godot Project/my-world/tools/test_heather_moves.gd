extends SceneTree

# Checks Heather's two spring moves and her blossom orchard, Glenmoor's reward (scripts/showers.gd,
# scripts/spring_step.gd, Portals._blossom_orchard(), glenmoor.gd thank_lines()): before Glenmoor's mended both are
# secret (April Showers isn't on the Controls list and does nothing, a quick jump on landing is just a jump) and
# there's no orchard; once it's mended Heather teaches them, saying how; April Showers brings a rain cloud over the
# hero that follows them, then a solid rainbow arches out ahead that you can walk up and stand on, only two at once,
# fading after a while; it's the Friend button with Heather along (scripts/party.gd), not holding Interact; jumping
# again just as you land bounces higher, three in a row higher still, and a jump after a pause is ordinary again; the
# orchard stands by Glenmoor's portal on flat, clear ground off the races and paths; and Heather talks about it in town.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_heather_moves.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.heather_moves_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.heather_moves_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var portals: Node
var settings: Node
var clock: Node
var dialogue: Node
var rem: Node


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
	portals.home_calls.enabled = false      # (this world on its own: no pull home to Stars Hollow, test_home_calls.gd)
	settings = root.get_node("Settings")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	rem = root.get_node("Remnants")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(w)

	await _check_locked()
	await _check_teaching()
	await _check_showers()
	await _check_hold()
	await _check_spring_step()
	await _check_orchard()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _check_locked() -> void:
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var p := _player()
	var g := p.get_node_or_null("Showers")
	check(g != null and p.get_node_or_null("SpringStep") != null, "the player has Showers and SpringStep nodes")
	check(not settings.default_bindings().has("showers") and settings.prompt("showers") == settings.prompt("friend"),
		"April Showers has no button of its own: it's Heather's move, on the Friend button (scripts/party.gd)")
	check(not settings.action_shown("showers"), "April Showers isn't learned before Glenmoor is mended")
	check(not g.try_shower() and g.showers == 0, "pressing it does nothing yet")
	check(p.get_node("SpringStep").bound() == 1.0, "and a jump's just a jump")
	check(current_scene.get_node_or_null("Portals/Blossom Orchard") == null, "and there's no orchard in the Void yet")


func _check_teaching() -> void:
	portals.enter("glenmoor")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.thank_lines().any(func(l: String) -> bool: return l.contains("{showers_how}")), "Heather's thank-you says how to call April Showers")
	settings.last_device = "keys"
	check(settings.showers_how() == "Press %s with Heather along" % settings.prompt("friend"), "...on a keyboard: %s" % settings.showers_how())
	settings.last_device = "pad"
	check(settings.showers_how() == "Press RB with Heather along", "...on a controller: %s" % settings.showers_how())
	settings.last_device = "keys"
	s.mend()
	check(portals.is_cleared("glenmoor"), "mending Glenmoor...")
	check(settings.action_shown("showers"), "...and April Showers is learned")
	await create_timer(s.TEACH_AFTER + 0.6).timeout
	check(dialogue.is_active(), "...and Heather teaches her moves a moment after")
	check(not dialogue.current_line().contains("{"), "(her lines are filled in: %s)" % dialogue.current_line())
	dialogue.end()
	await _frames(4)


func _land(p: CharacterBody3D) -> void:
	for i in 300:
		await physics_frame
		if p.is_on_floor() and i > 2:
			return


func _check_showers() -> void:
	var p := _player()
	var g := p.get_node("Showers")
	p.global_position = Vector3(8.0, 0.9, 16.0)
	p.velocity = Vector3.ZERO
	await _land(p)
	check(g.try_shower(), "April Showers works")
	check(is_instance_valid(g.cloud) and g.cloud.get_node_or_null("Rain") != null, "...a rain cloud comes over")
	check(absf(g.cloud.global_position.x - p.global_position.x) < 0.5 and g.cloud.global_position.y > p.global_position.y + 2.0, "...right over the hero")
	check(not g.try_shower(), "(one shower at a time)")
	p.global_position = Vector3(10.0, 0.9, 16.0)
	await create_timer(0.8).timeout
	check(absf(g.cloud.global_position.x - p.global_position.x) < 0.8, "...and it follows them about")
	p.global_position = Vector3(8.0, 0.9, 16.0)
	await _land(p)
	await create_timer(g.RAIN).timeout
	check(g.bridges.size() == 1, "when the rain stops, a rainbow arches out")
	var bow: Node3D = g.bridges[0]
	# Walk it: stand on the middle of it, high up
	var dir: Vector3 = g.ahead()
	var top: Vector3 = Vector3(8.0, 0, 16.0) + dir * g.LENGTH / 2.0
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top + Vector3(0, 10, 0), top + Vector3(0, -5, 0)))
	check(not hit.is_empty() and hit.collider == bow and hit.position.y > 2.0, "...it's solid, arching up high in the middle (%.1f m)" % (hit.position.y if hit else -1.0))
	# Walk up it from its foot
	p.global_position = Vector3(8.0, 0.9, 16.0) + dir * 1.0
	p.velocity = Vector3.ZERO
	await _physics(6)
	var best := p.global_position.y
	for i in 120:
		p.velocity.x = dir.x * 5.0
		p.velocity.z = dir.z * 5.0
		await physics_frame
		best = maxf(best, p.global_position.y)
	check(best > 2.5, "...and you can walk right up it (%.1f m up)" % best)
	await _land(p)
	g.cooldown = 0.0
	g.raining = 0.0
	g.shower()
	g.raining = 0.01
	await _frames(3)
	g.cooldown = 0.0
	g.shower()
	g.raining = 0.01
	await _frames(3)
	check(g.bridges.size() == g.MAX_BRIDGES and g.showers == 3, "only %d rainbows at once (the oldest fades)" % g.MAX_BRIDGES)
	await create_timer(0.6).timeout
	check(not is_instance_valid(bow), "...and it's gone")
	var last: Node3D = g.bridges[g.bridges.size() - 1]
	last.set_meta("until", Time.get_ticks_msec() / 1000.0 + 0.1)
	await create_timer(0.8).timeout
	check(not is_instance_valid(last) and g.bridges.size() == g.MAX_BRIDGES - 1, "rainbows fade away after a while")
	game.hold_controls(&"test", true, p)
	g.cooldown = 0.0
	check(not g.can_shower(), "not while the controls are held")
	game.hold_controls(&"test", false, p)
	check(g.can_shower(), "(and fine again after)")


func _check_hold() -> void:
	# Since the party system it's the Friend button with Heather along (scripts/party.gd); holding Interact doesn't
	var p := _player()
	var g := p.get_node("Showers")
	var party := root.get_node("Party")
	p.global_position = Vector3(8.0, 0.9, 16.0)
	await _land(p)
	g.cooldown = 0.0
	g.raining = 0.0
	var before: int = g.showers
	Input.action_press("interact")
	await process_frame
	await create_timer(0.7).timeout
	Input.action_release("interact")
	await _frames(2)
	check(g.showers == before, "holding Interact doesn't call April Showers any more")
	party.join("heather", true)
	Input.action_press("friend")
	await _physics(2)
	Input.action_release("friend")
	await _frames(2)
	check(g.showers == before + 1, "with Heather along, Friend calls April Showers")
	await create_timer(g.RAIN + 0.3).timeout
	if dialogue.is_active():
		dialogue.end()
	await _frames(4)


func _jump_peak(p: CharacterBody3D, again_on_landing: bool) -> float:
	# Jump (holding Jump all the way up), and say how high it went; land, then (if asked) jump again straight away
	Input.action_press("jump")
	await physics_frame
	var y0 := p.global_position.y
	var top := y0
	for i in 240:
		await physics_frame
		top = maxf(top, p.global_position.y)
		if p.is_on_floor() and i > 3:
			break
	Input.action_release("jump")
	if not again_on_landing:
		await _physics(30)
	else:
		await physics_frame
	return top - y0


func _check_spring_step() -> void:
	var p := _player()
	var st := p.get_node("SpringStep")
	p.global_position = Vector3(-4.0, 0.9, 16.0)
	p.velocity = Vector3.ZERO
	await _land(p)
	await _physics(30)
	var h0: float = await _jump_peak(p, true)
	check(st.chain == 0, "a jump from standing is ordinary (%.2f m)" % h0)
	var h1: float = await _jump_peak(p, true)
	check(st.chain == 1 and h1 > h0 * 1.4, "jump again as you land: a Spring Step, higher (%.2f m)" % h1)
	var h2: float = await _jump_peak(p, false)
	check(h2 > h1 * 1.3, "...and a third in a row is the biggest (%.2f m)" % h2)
	var h3: float = await _jump_peak(p, false)
	check(st.chain == 0 and absf(h3 - h0) < 0.3, "after a pause it's an ordinary jump again (%.2f m)" % h3)
	check(st.steps >= 2, "(%d Spring Steps)" % st.steps)


func _check_orchard() -> void:
	portals.go_home()
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == TOWN, "back in the Void")
	var o := s.get_node_or_null("Portals/Blossom Orchard") as Node3D
	check(o != null, "Heather's blossom orchard stands by Glenmoor's portal")
	if o == null:
		return
	var trees := o.get_children().filter(func(n: Node) -> bool: return str(n.name).begins_with("Blossom Tree"))
	check(trees.size() == 9, "...nine blossom trees (%d)" % trees.size())
	check(o.get_node_or_null("Sign") != null and o.get_node_or_null("Fluffkin 1") != null and o.get_node_or_null("Fluffkin 2") != null,
		"...with a sign and two Fluffkins grazing")
	var floating := 0
	for t in trees:
		var at := (t as Node3D).global_position
		if absf(at.y - rem.ground_at(Vector2(at.x + 0.6, at.z)).y) > 0.3:          # (just beside its trunk)
			floating += 1
	check(floating == 0, "...every tree on the ground (%s)" % ", ".join(trees.map(func(t: Node3D) -> String: return "%.1f/%.1f" % [t.global_position.y, rem.ground_at(Vector2(t.global_position.x + 0.6, t.global_position.z)).y])))
	var c: Vector2 = portals.ORCHARD
	var g0: float = o.global_position.y
	var worst := 0.0
	for t in trees:
		worst = maxf(worst, absf((t as Node3D).global_position.y - g0))
	check(worst < 0.9, "...on flat ground (worst step %.2f)" % worst)
	var w: Dictionary = portals.world("glenmoor")
	check(c.distance_to(w.at) > 10.0 and c.distance_to(w.at) < 25.0, "...near the portal, not in front of it (%.0f m)" % c.distance_to(w.at))
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw)))
	check(front.dot((c - w.at).normalized()) < 0.3, "...and not where you walk up to it")
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
			var k := clampf((c - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			nearest = minf(nearest, c.distance_to(a.lerp(b, k)))
	check(nearest > 14.0, "...well off the race tracks (%.0f m)" % nearest)
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a := Vector2(pa[0], pa[pa.size() - 1])
		var b := Vector2(pb[0], pb[pb.size() - 1])
		var k := 0.0 if a == b else clampf((c - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		path = minf(path, c.distance_to(a.lerp(b, k)))
	check(path > 10.0, "...and off the townsfolk's paths (%.0f m)" % path)
	var town_trees := s.find_child("Trees", true, false) as Node3D
	var tree := INF
	for tp in town_trees.get("positions"):
		var gp: Vector3 = town_trees.global_transform * tp
		tree = minf(tree, c.distance_to(Vector2(gp.x, gp.z)))
	check(tree > 8.0, "...with no town tree in the middle of it (nearest %.0f m)" % tree)
	# April Showers in the Void, by the orchard
	var p := _player()
	var gr := p.get_node("Showers")
	p.global_position = rem.ground_at(c + Vector2(0, 9.0)) + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	gr.cooldown = 0.0
	gr.raining = 0.0
	check(gr.try_shower(), "April Showers works in the Void too")
	# Heather talks about it in town
	clock.set_time(3, 10 * 60.0, true)
	var lines: Array = []
	for i in 6:
		dialogue.talks["clover"] = 5 + i
		var l: Array = dialogue.pick_conversation("clover")
		if " ".join(l.map(func(x) -> String: return str(x))).contains("orchard"):
			lines = l
			break
	check(not lines.is_empty(), "Heather talks about the orchard and her moves in the Void")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("jump")
	Input.action_release("interact")
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
