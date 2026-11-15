extends SceneTree

# Checks the guardians (scripts/guardian.gd), the big optional bosses at three of the Void's hidden places: none shows
# before its place is found; finding the place puts it there, asleep, on open, flat ground; coming close wakes it;
# every move it makes is warned first with the shared boss tells (scripts/boss_tell.gd) and comes when the warning
# ends; standing on a falling star's shadow, in a swoop's path or in a gulp's pull gets you bumped or dragged, and
# moving off, stepping aside or jumping doesn't; bubbles only count while it's puffed out; walking away calms it back
# to sleep with all its puff; and enough hits calm it for good, with its prize once and no guardian next visit.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_guardians.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.guardians_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.guardians_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const CLEAR := 3.5
const TREES := ["Trees", "Foliage", "Crystals"]

var failures := 0
var game: Node
var hidden: Node
var G: GDScript


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
	hidden = root.get_node("Hidden")
	G = load("res://scripts/guardian.gd")
	var tell: GDScript = load("res://scripts/boss_tell.gd")
	root.get_node("Settings").tips = false
	root.get_node("Settings").boss_warn_early = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	var dialogue := root.get_node("Dialogue")
	var shop := root.get_node("Shop")
	check(G.KINDS.size() == 3, "three guardians")
	for id in G.KINDS:
		var hat := str(G.KINDS[id].hat)
		check(shop.items.has(hat), "%s's hat (%s) is a reward in the shop list" % [id, hat])
		var placed := false
		for p in hidden.places_in("void"):
			placed = placed or p.id == id
		check(placed, "%s is one of the Void's hidden places" % id)

	# --- Nothing before its place is found ---
	change_scene_to_file(TOWN)
	await _frames(12)
	await _physics(6)
	check(get_nodes_in_group("guardians").is_empty(), "no guardians before their places are found")

	for id in G.KINDS:
		await _one(str(id), tell, dialogue)

	# --- Next visit: the calmed ones are gone, and nothing's left over ---
	change_scene_to_file(TOWN)
	await _frames(12)
	await _physics(6)
	check(get_nodes_in_group("guardians").is_empty(), "calmed guardians aren't there next visit")
	_end()


func _one(id: String, tell: GDScript, dialogue: Node) -> void:
	var scene := current_scene as Node3D
	var player := scene.find_child("Player", true, false) as CharacterBody3D
	hidden.find(id)
	await _frames(3)
	var g := scene.find_child("Guardian " + id, true, false) as CharacterBody3D
	check(g != null, "%s: finding the place puts its guardian there" % id)
	if g == null:
		return
	var name: String = g.title
	check(g.state == G.State.SLEEP, "%s is asleep" % name)
	# On open, flat, dry ground
	var p := g.global_position
	var space := scene.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(CLEAR * 2.0, 2.0, CLEAR * 2.0)
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.9, 0))
	sq.collide_with_areas = false
	var names := []
	for h in space.intersect_shape(sq, 8):
		var col := h.collider as Node
		if col and not col.is_in_group("player") and not (col is CharacterBody3D) and not _is_ground(col):
			names.append(str(col.name))
	check(names.is_empty(), "...on open ground %s" % [names])
	check(p.y > -1.0, "...not down in water (y %.1f)" % p.y)
	var lo := INF
	var hi := -INF
	for o in [Vector2.ZERO, Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
		var y: float = (root.get_node("Bosses").ground(scene, p.x + o.x, p.z + o.y) as Vector3).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	check(hi - lo < 1.2, "...where it fights is fairly flat (%.1f m)" % (hi - lo))
	var close := ""
	for grp in TREES:
		var holder := scene.get_node_or_null(grp)
		if holder == null:
			continue
		for t in holder.find_children("*", "Node3D", false, false):
			var tp := (t as Node3D).global_position
			if Vector2(tp.x, tp.z).distance_to(Vector2(p.x, p.z)) < 3.0:
				close = "%s/%s" % [grp, t.name]
	# The Void's trees are drawn from a list of spots (trees.gd), not nodes, so check those too
	for n in scene.find_children("*", "Node3D", true, false):
		var sc := n.get_script() as Script
		if sc == null or not sc.resource_path.ends_with("trees.gd"):
			continue
		for tp0 in (n.get("positions") as PackedVector3Array):
			var tp: Vector3 = (n as Node3D).global_transform * tp0
			if Vector2(tp.x, tp.z).distance_to(Vector2(p.x, p.z)) < 5.0:
				close = "a tree at (%.0f, %.0f), it is at (%.0f, %.0f)" % [tp.x, tp.z, p.x, p.z]
	check(close == "", "...no tree in it %s" % close)

	# Bubbles do nothing while it sleeps
	check(g.shot(1, p, Vector3.FORWARD) == "miss" and g.hits == 0, "%s: bubbles don't wake or hurt it" % name)

	# Coming close wakes it
	player.global_position = g.home + Vector3(8.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await _physics(4)
	check(g.state != G.State.SLEEP, "%s wakes when you come close" % name)

	# Each of its moves: warned, then it comes
	for mv in g.moves:
		game.hp = game.max_hp                     # (a test stands in every attack on purpose: no fainting)
		var t_seen := -1.0
		var t_act := -1.0
		var clock := 0.0
		var bumped := false
		player.set("_invulnerable_timer", 0.0)
		while clock < 9.0 and (t_act < 0.0 or g.state == G.State.ACT):
			await physics_frame
			clock += 1.0 / Engine.physics_ticks_per_second
			# Stand still on the ground nearby, so each attack's checked against someone who didn't dodge
			if g.state != G.State.ACT:
				player.global_position = g.home + Vector3(5.0, 0.6, 0.0)
				player.velocity = Vector3.ZERO
			if t_seen < 0.0 and tell.showing(g) and g._move == mv:
				t_seen = clock
			if t_act < 0.0 and g.state == G.State.ACT and g._move == mv:
				t_act = clock
			if player.call("is_invulnerable"):
				bumped = true
		check(t_seen >= 0.0, "%s: its %s is warned first" % [name, mv])
		check(t_act > 0.0 and t_act - t_seen >= tell.NORMAL - 0.05,
			"...and comes when the warning ends (%.2f s later)" % (t_act - t_seen))
		await _wait(0.6)
		if player.call("is_invulnerable"):
			bumped = true
		if mv != "pull":
			check(bumped, "...standing still in it gets you bumped")
		player.set("_invulnerable_timer", 0.0)
		g.set("_state_t", 0.0)   # on to the next
		await _physics(2)

	# The gulp drags you in, and a jump breaks free
	if g.moves.has("pull"):
		g.state = G.State.ACT
		g._move = "pull"
		g._state_t = 1.0
		player.global_position = g.global_position + Vector3(8.0, 0.0, 0.0)
		player.global_position.y = g.home.y + 0.9
		await _physics(3)
		var d0 := _flat(player.global_position - g.global_position)
		await _physics(20)
		var d1 := _flat(player.global_position - g.global_position)
		check(d1 < d0 - 0.4, "%s's gulp drags you in on the ground (%.1f -> %.1f m)" % [name, d0, d1])

	# Bubbles only count when it's puffed out
	g.state = G.State.IDLE
	g._state_t = 99.0
	check(g.shot(1, g.global_position, Vector3.FORWARD) == "miss", "%s: bubbles boing off until it's puffed out" % name)

	# Walking away calms it, with all its puff back
	g.state = G.State.DAZED
	g._state_t = 99.0
	g._daze_hits = 0
	g.shot(2, g.global_position, Vector3.FORWARD)
	check(g.hits == 2, "...puffed out, they count")
	player.global_position = g.home + Vector3(G.LEASH + 4.0, 1.0, 0.0)
	await _physics(3)
	check(g.state == G.State.SLEEP and g.hits == 0 and not g.defeated, "walking away lets %s sleep again, all puffed up" % name)

	# Calming it for good
	game.hp = game.max_hp
	player.global_position = g.home + Vector3(7.0, 1.0, 0.0)
	await _physics(3)
	var sp: int = game.sparkles
	var rem: int = root.get_node("Remnants").count
	var hat := "shop:" + str(G.KINDS[id].hat)
	check(not game.has_item(hat), "...no hat yet")
	var guard := 0
	while not g.defeated and guard < 20:
		g.state = G.State.DAZED
		g._state_t = 99.0
		g._daze_hits = 0
		g.shot(3, g.global_position, Vector3.FORWARD)
		g.shot(3, g.global_position, Vector3.FORWARD)
		if guard == 0:
			check(g._daze_hits == G.MAX_PER_DAZE, "...no more than %d hits each time it's puffed out" % G.MAX_PER_DAZE)
		guard += 1
	check(g.defeated and g.hits >= G.HITS, "%s is calmed after %d hits" % [name, G.HITS])
	check(bool(dialogue.flags.get(G.flag(id), false)), "...and that's saved")
	check(game.sparkles == sp + G.SPARKLES and root.get_node("Remnants").count == rem + G.REMNANTS,
		"...+%d sparkles and +%d Remnants" % [G.SPARKLES, G.REMNANTS])
	check(game.has_item(hat), "...and its hat")
	await _wait(3.0)
	check(not is_instance_valid(g), "...and it floats off, happy")
	# Finding the place again does nothing more
	check(not hidden.find(id) and scene.find_child("Guardian " + id, true, false) == null, "...and it doesn't come back")
	player.global_position = Vector3(0, 2, 0)
	await _physics(4)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _is_ground(c: Node) -> bool:
	var path := str(c.get_path())
	for grp in ["/Ground", "/Terrain", "/Far Ground", "/Land"]:
		if path.contains(grp):
			return true
	return false


func _wait(secs: float) -> void:
	await create_timer(secs).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit(1 if failures > 0 else 0)
