extends SceneTree

# Checks Heather's grow and her blossom orchard, Glenmoor's reward (scripts/grow.gd, Portals._blossom_orchard(),
# glenmoor.gd thank_lines()): before Glenmoor's mended the move's a secret (not on the Controls list, pressing it does
# nothing) and there's no orchard; once it's mended Heather teaches it, saying how; on grass a Bloomstalk shoots up
# under the hero and flings them high, it's solid to stand on and its cap bounces you again, only three at once, and
# they wilt after a while; on paving nothing grows; holding Interact with nothing near grows too, but not next to
# someone to talk to; near your garden it gives the crops a boost, once a Void hour; the orchard stands by Glenmoor's
# portal on flat, clear ground off the races and paths; and Heather talks about it in town.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_grow.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.grow_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.grow_test_backup.cfg"
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
	await _check_grow()
	await _check_hold()
	await _check_orchard()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _check_locked() -> void:
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	var p := _player()
	var g := p.get_node_or_null("Grow")
	check(g != null, "the player has a Grow node")
	check(settings.default_bindings().get("grow") == KEY_H and settings.default_pad_bindings().get("grow") == -1,
		"Grow is on H (and holding Interact: no pad button of its own)")
	check(not settings.action_shown("grow"), "Grow isn't on the Controls list before Glenmoor is mended")
	check(not g.try_grow() and g.grows == 0, "pressing it does nothing yet")
	check(current_scene.get_node_or_null("Portals/Blossom Orchard") == null, "and there's no orchard in the Void yet")


func _check_teaching() -> void:
	portals.enter("glenmoor")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.thank_lines().any(func(l: String) -> bool: return l.contains("{grow_how}")), "Heather's thank-you says how to grow")
	settings.last_device = "keys"
	check(settings.grow_how() == "press H, or hold %s" % settings.prompt("interact"), "...on a keyboard: %s" % settings.grow_how())
	settings.last_device = "pad"
	check(settings.grow_how() == "hold %s" % settings.prompt("interact"), "...on a controller: %s" % settings.grow_how())
	settings.last_device = "keys"
	s.mend()
	check(portals.is_cleared("glenmoor"), "mending Glenmoor...")
	check(settings.action_shown("grow"), "...puts Grow on the Controls list")
	await create_timer(s.TEACH_AFTER + 0.6).timeout
	check(dialogue.is_active(), "...and Heather teaches it a moment after")
	check(not dialogue.current_line().contains("{"), "(her lines are filled in: %s)" % dialogue.current_line())
	dialogue.end()
	await _frames(4)


func _check_grow() -> void:
	# On the glen's grass
	var s := current_scene
	var p := _player()
	var g := p.get_node("Grow")
	p.global_position = Vector3(8.0, 0.9, 20.0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	check(p.is_on_floor() and g.on_soil(), "the glen's grass is soil")
	check(g.try_grow(), "Grow works on the grass")
	check(g.stalks.size() == 1 and is_instance_valid(g.stalks[0]), "...a Bloomstalk shoots up")
	var stalk: Node3D = g.stalks[0]
	check(Vector2(stalk.global_position.x - 8.0, stalk.global_position.z - 20.0).length() < 0.6, "...right under the hero (%s)" % stalk.global_position)
	var y0 := p.global_position.y
	var top := y0
	for i in 60:
		await physics_frame
		top = maxf(top, p.global_position.y)
	check(top > y0 + 5.0, "...and flings them up high (%.1f m)" % (top - y0))
	# It's solid: land back on it and the cap bounces you
	var bounces: int = g.bounces
	for i in 300:
		await physics_frame
		if g.bounces > bounces:
			break
	check(g.bounces > bounces, "landing back on its cap bounces you up again")
	g.cooldown = 0.0
	p.global_position = Vector3(-6.0, 0.9, 22.0)
	p.velocity = Vector3.ZERO
	await _physics(10)
	for k in 3:
		p.global_position = Vector3(-6.0 + k * 4.0, 0.9, 22.0)
		p.velocity = Vector3.ZERO
		for i in 120:
			await physics_frame
			if p.is_on_floor() and i > 4:
				break
		g.cooldown = 0.0
		g.try_grow()
	check(g.stalks.size() == g.MAX_STALKS and g.grows == 4, "only %d Bloomstalks at once (the oldest wilts) (%d out, %d grown)" % [g.MAX_STALKS, g.stalks.size(), g.grows])
	await create_timer(0.6).timeout
	check(not is_instance_valid(stalk), "...and it's gone")
	var last: Node3D = g.stalks[g.stalks.size() - 1]
	last.set_meta("until", Time.get_ticks_msec() / 1000.0 + 0.1)
	await create_timer(0.8).timeout
	check(not is_instance_valid(last) and g.stalks.size() == g.MAX_STALKS - 1, "Bloomstalks wilt away after a while")
	# On paving nothing grows
	for i in 200:
		await physics_frame
		if p.is_on_floor():
			break
	var paving := StaticBody3D.new()
	paving.name = "Paving"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 0.4, 4)
	cs.shape = box
	paving.add_child(cs)
	s.add_child(paving)
	paving.global_position = Vector3(20.0, 0.2, 30.0)
	p.global_position = Vector3(20.0, 1.3, 30.0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	g.cooldown = 0.0
	var before: int = g.grows
	check(p.is_on_floor() and not g.on_soil(), "(standing on paving)")
	check(not g.try_grow() and g.grows == before, "nothing grows on paving")
	paving.queue_free()
	# Not while burrowed, riding or swimming, or while someone's holding the controls
	p.global_position = Vector3(8.0, 0.9, 16.0)
	await _physics(20)
	g.cooldown = 0.0
	game.hold_controls(&"test", true, p)
	check(not g.can_grow(), "not while the controls are held")
	game.hold_controls(&"test", false, p)
	check(g.can_grow(), "(and fine again after)")


func _check_hold() -> void:
	var p := _player()
	var g := p.get_node("Grow")
	for i in 200:
		await physics_frame
		if p.is_on_floor():
			break
	g.cooldown = 0.0
	var before: int = g.grows
	Input.action_press("interact")
	await process_frame
	await create_timer(g.HOLD + 0.3).timeout
	Input.action_release("interact")
	await _frames(2)
	check(g.grows == before + 1, "holding Interact with nothing near grows a Bloomstalk")
	# ...but not standing by Heather (Interact talks to her)
	var heather := current_scene.get_node("Heather") as Node3D
	for i in 300:
		await physics_frame
		if p.is_on_floor():
			break
	p.global_position = heather.global_position + Vector3(1.2, 0.9, 0.8)
	p.velocity = Vector3.ZERO
	await _physics(10)
	await _frames(4)
	g.cooldown = 0.0
	before = g.grows
	check(not g.nothing_near(), "(Heather's in reach)")
	Input.action_press("interact")
	await process_frame
	await create_timer(g.HOLD + 0.3).timeout
	Input.action_release("interact")
	await _frames(2)
	check(g.grows == before, "...holding Interact by someone to talk to doesn't grow anything")
	if dialogue.is_active():
		dialogue.end()
	await _frames(4)


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
	# Grow on the Void's grass, by the orchard
	var p := _player()
	var gr := p.get_node("Grow")
	p.global_position = rem.ground_at(c + Vector2(0, 9.0)) + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	gr.cooldown = 0.0
	check(gr.try_grow(), "Grow works on the Void's grass too")
	# Heather talks about it in town
	clock.set_time(3, 10 * 60.0, true)
	var lines: Array = []
	for i in 6:
		dialogue.talks["clover"] = 5 + i
		var l: Array = dialogue.pick_conversation("clover")
		if " ".join(l.map(func(x) -> String: return str(x))).contains("orchard"):
			lines = l
			break
	check(not lines.is_empty(), "Heather talks about the orchard and her grow in the Void")


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
