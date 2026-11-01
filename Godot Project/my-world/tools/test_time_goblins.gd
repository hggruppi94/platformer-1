extends SceneTree

# Checks the Time Goblins and their boss, Grandfather Tock (tools/build_time_goblin.gd, scripts/time_goblin.gd,
# scripts/time_goblin_boss.gd, placed by scripts/bosses.gd): the Goblin Clockyard is in town and on the map with its
# goblins about; a goblin's watch runs backwards; it blinks back in time to where it was, leaving ghosts, then is
# dizzy and can't blink again for a while; it dodges a bubble by blinking; it pops while dizzy; it snatches a sparkle
# when it bumps you and gives it back when popped. Tock is big, has a meter, rewinds a hit when he blinks, chimes rings
# you have to jump, calls goblins at two-thirds and one-third, and is remembered once popped.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_time_goblins.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	p.global_position = Vector3(-72, 2, 80)                 # well away from the clockyard to start with

	# --- In town ---
	var yard := town.get_node_or_null("Goblin Clockyard") as Node3D
	check(yard != null, "the Goblin Clockyard is in town")
	check(yard != null and yard.is_in_group("map_landmarks") and yard.call("map_name") == "Goblin Clockyard",
		"...and on the map")
	check(yard != null and yard.find_children("Clock *", "", false, false).size() == 7, "...with its ring of old clocks")
	var goblins := town.find_children("Time Goblin *", "", true, false)
	check(goblins.size() == 8, "Time Goblins are about (%d)" % goblins.size())
	var tock := town.find_child("Grandfather Tock", true, false)
	check(tock != null and tock.is_in_group("bosses"), "Grandfather Tock keeps the clockyard")
	var off := []
	for g in goblins:
		var at := (g as Node3D).global_position
		var under: Vector3 = root.get_node("Bosses").ground(town, at.x, at.z)
		if absf(at.y - under.y) > 1.0:
			off.append("%s at %s, ground %.1f" % [g.name, at, under.y])
	check(off.is_empty(), "every goblin stands on the ground %s" % [off])

	# --- The watch runs backwards ---
	var g0 := goblins[0] as CharacterBody3D
	var minute := g0.get_node("Visual/Watch/Minute") as Node3D
	var r0 := minute.rotation.z
	await _physics(20)
	check(minute.rotation.z > r0, "a goblin's pocket watch runs backwards")

	# --- Blinking back in time ---
	g0.set_physics_process(false)
	g0._hist.clear()
	var start := g0.global_position
	for i in 30:                                            # 3 s of walking east, remembered every 0.1 s
		g0.global_position = start + Vector3(i * 0.2, 0, 0)
		g0._hist_t = 0.0
		g0._remember(0.0)
	g0._blink_cd = 0.0
	g0.state = 0
	var before := town.find_children("TimeGhost", "", true, false).size()
	check(g0.blink(), "a goblin can blink back in time")
	var back := g0.global_position.x - start.x
	check(absf(back - 29 * 0.2 + 20 * 0.2) < 0.25, "...to where it was two seconds ago (%.1f m back)" % (29 * 0.2 - back))
	check(town.find_children("TimeGhost", "", true, false).size() > before, "...leaving ghosts along the way")
	check(g0.state == 3, "...and it's dizzy afterwards")
	check(not g0.can_blink(), "...and can't blink again straight away")
	g0.set_physics_process(true)

	# --- Popping it while it's dizzy ---
	var xp: int = game.xp
	var level: int = game.level
	g0.shot(1, g0.global_position, Vector3.FORWARD)
	check(g0.defeated, "a bubble pops a dizzy goblin")
	check(game.xp > xp or game.level > level, "...for XP")

	# --- Dodging a bubble ---
	var g1 := goblins[1] as CharacterBody3D
	g1.blink_chance = 1.0
	g1._blink_cd = 0.0
	g1.state = 0
	g1._hist.clear()
	for i in 30:
		g1._hist.append(g1.global_position + Vector3(0, 0, -0.1 * (30 - i)))
	p.global_position = g1.global_position + Vector3(0, 0.3, 8.0)
	await _physics(2)
	var aim := (g1.global_position + Vector3(0, 0.5, 0)) - (p.global_position + Vector3(0, 0.5, 0))
	(load("res://scripts/star_bubble.gd") as GDScript).fire(town, p.global_position + Vector3(0, 0.5, 0) + aim.normalized() * 1.0, aim, p)
	for i in 60:
		await physics_frame
		if g1._blink_cd > 0.0:
			break
	check(g1._blink_cd > 0.0 and not g1.defeated, "a goblin blinks out of a bubble's way")

	# --- Snatching a sparkle ---
	var g2 := goblins[2] as CharacterBody3D
	g2.player = p
	game.sparkles = 5
	p._invulnerable_timer = 0.0
	p.global_position = g2.global_position + Vector3(0.6, 0.8, 0)
	p.velocity = Vector3.ZERO
	g2._touch_player()
	check(game.sparkles == 4 and g2.carried == 1, "a goblin that bumps you snatches a sparkle")
	check(g2.state == 2, "...and runs off giggling")
	await _physics(2)
	check(g2.get_node("Loot").visible, "...holding it up over its head")
	g2.shot(1, g2.global_position, Vector3.FORWARD)
	check(game.sparkles == 5, "pop it and you get the sparkle back")

	# --- Grandfather Tock ---
	p.global_position = tock.global_position + Vector3(0, 1, 12)
	tock.player = p
	await _physics(3)
	check(tock.size > 2.0 and _height(tock) > 3.5, "Tock is big (%.1f m)" % _height(tock))
	check(tock.get_node_or_null("BossMeter") != null, "he has a meter with his name")
	check(tock.get_node_or_null("Visual/Head/Clock/Pendulum") != null, "he wears a grandfather clock with a pendulum")
	tock.shot(1, tock.global_position, Vector3.FORWARD)
	check(tock.hits == 1, "a bubble hits him")
	tock._blink_cd = 0.0
	tock.state = 0
	for i in 25:                                            # (he may have blinked already, from the stray bubble)
		tock._hist.append(tock.global_position)
	var blinked: bool = tock.blink()
	check(blinked and tock.hits == 0, "when he blinks back in time he rewinds the hit too (blinked %s, hits %d, %d spots)"
		% [blinked, tock.hits, tock._hist.size()])
	tock.shot(3, tock.global_position, Vector3.FORWARD)
	await _frames(2)
	check(town.find_children("Tock's Goblin *", "", true, false).size() == 2, "at a third he whistles up two goblins")
	tock.shot(3, tock.global_position, Vector3.FORWARD)
	await _frames(2)
	check(town.find_children("Tock's Goblin *", "", true, false).size() == 4, "...and two more at two-thirds")
	check(tock._cross, "past half he gets cross (quicker, more chimes)")

	# His chimes: rings to jump (his goblins popped and him held still, so nothing else bumps the player meanwhile)
	for h in town.find_children("Tock's Goblin *", "", true, false):
		h.shot(1, (h as Node3D).global_position, Vector3.FORWARD)
	for g in town.get_tree().get_nodes_in_group("time_goblins"):
		g.set_physics_process(false)
	await _physics(2)
	var hp: int = game.hp
	p.global_position = tock.global_position + Vector3(4.0, 3.0, 0.0)
	p.velocity = Vector3.ZERO
	tock._strike()
	p._invulnerable_timer = 0.0
	await _physics(30)
	check(game.hp >= hp and not p.is_recovering(), "jumping over his chime ring is safe")
	p.global_position = tock.global_position + Vector3(5.0, 0.8, 0.0)
	for i in 60:
		await physics_frame
		if p.is_on_floor():
			break
	p._invulnerable_timer = 0.0
	tock._strike()
	var bumped := false
	for i in 90:
		await physics_frame
		if p.is_recovering():
			bumped = true
			break
	check(bumped, "standing where the ring rolls past gets you bumped")
	game.hp = hp
	tock.set_physics_process(true)
	tock.shot(3, tock.global_position, Vector3.FORWARD)
	check(tock.defeated, "...and enough bubbles pop him")
	check(root.get_node("Dialogue").flags.has("popped_grandfather_tock"), "popping Tock is remembered")
	_end()


func _height(n: Node) -> float:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.get_parent().name == "BossMeter" or mi.get_parent().get_parent() \
				and mi.get_parent().get_parent().name == "BossMeter":
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y


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
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
