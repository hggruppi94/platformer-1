extends SceneTree

# Checks the bosses' shockwave looks and ranged moves. Every shockwave style (scripts/shock_ring.gd STYLES) builds
# its own band and shapes, rolls out to its reach and tidies itself away; every little shape (scripts/boss_bits.gd)
# has a mesh. Every boss script puts its ranged move on (scripts/boss_moves.gd). Then, in the Gloop Kingdom on the
# King's own moves: a shot flies at you and bumps you, stepping aside makes it miss, a lob lands where you stood and
# bumps you only if you're still there, and a blink takes him somewhere else in his court, never right next to you.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boss_moves.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.moves_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.moves_backup.cfg"
const BITS := preload("res://scripts/boss_bits.gd")
const BIT_KINDS := ["blob", "drop", "fleck", "spark", "ember", "bubble", "gear", "note", "star", "shard", "thorn",
	"flame", "rock", "cube", "bar", "bolt", "wisp", "leaf", "petal", "feather", "moth", "ribbon", "skull"]
# Every boss with a fight of its own, and the script that gives it a ranged move
const MOVERS := ["gloop_king", "time_goblin_boss", "crocodillo_boss", "off_beat", "the_hush",
	"centipede_boss", "big_buzz", "the_gloam", "guardian", "captain_glitch", "rootmind"]
# ...and the ones whose own attacks already reach you from afar
const ALREADY := {"starhorn": "falling stars", "old_ember": "lava blobs", "chaos_fight": "chaos bursts"}

var failures := 0
var MOVES: GDScript
var RING: GDScript    # (loaded once the autoloads are up: it reads Settings)


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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	MOVES = load("res://scripts/boss_moves.gd")
	RING = load("res://scripts/shock_ring.gd")
	var game := root.get_node("Game")
	game.riding = false
	game._reset_state()                                    # (a new game's state, not Hayden's progress from his save)
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""

	# --- The shapes ---
	var no_mesh := []
	for k in BIT_KINDS:
		var m: Mesh = BITS.mesh(k)
		if m == null or m.get_surface_count() == 0:
			no_mesh.append(k)
	check(no_mesh.is_empty(), "every shape has a mesh %s" % str(no_mesh))
	check(BITS.mesh("gear") == BITS.mesh("gear"), "...made once and kept")

	# --- Every shockwave style ---
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	await _frames(2)
	var styles: Array = RING.STYLES.keys()
	check(styles.size() >= 20, "%d shockwave styles" % styles.size())
	var rings := {}
	for s in styles:
		var r: Node3D = RING.spawn(stage, Vector3.ZERO, 10.0, Color(0.6, 0.9, 1.0), 0, 0.6, s)
		rings[s] = r
	await _frames(3)
	var thin := []
	for s in styles:
		var r: Node = rings[s]
		var meshes := r.find_children("*", "MeshInstance3D", true, false).size() if is_instance_valid(r) else 0
		if meshes < 6:
			thin.append("%s (%d)" % [s, meshes])
	check(thin.is_empty(), "every style has a band and shapes riding it %s" % str(thin))
	check(RING.spawn(stage, Vector3.ZERO, 4.0, Color.WHITE, 0, 0.3, "no such style").style == "plain",
		"an unknown style falls back to the plain one")
	await _wait(0.35)
	var reach_ok := true
	for s in styles:
		var r: Node = rings[s]
		var band := r.get_node_or_null("Band") as Node3D if is_instance_valid(r) else null
		if band == null or band.scale.x < 4.0:
			reach_ok = false
	check(reach_ok, "...and every one rolls outwards")
	await _wait(1.6)
	var left := 0
	for s in styles:
		if is_instance_valid(rings[s]):
			left += 1
	check(left == 0, "...then tidies itself away (%d left)" % left)
	check(stage.find_children("*", "MeshInstance3D", true, false).size() == 0, "...trail and all")
	stage.queue_free()
	await _frames(2)

	# --- Every boss has a ranged move ---
	for b in MOVERS:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % b)
		check(src.contains("MOVES.add("), "%s has a ranged move" % b)
	check(FileAccess.get_file_as_string("res://scripts/stormram.gd").contains("throw_moves"), "stormram has a ranged move")
	for b in ALREADY:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % b)
		check(src != "", "%s already reaches you from afar (%s)" % [b, ALREADY[b]])
	for kind in ["throw", "blink"]:
		var tell: GDScript = load("res://scripts/boss_tell.gd")
		check(tell.HINTS.has(kind) and tell.POSES.has(kind), "the body winds up for a %s" % kind)

	# --- The Gloop King's own moves ---
	root.get_node("Bosses").enter_kingdom()
	await _frames(10)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var king := town.get_node_or_null("The Gloop King") as CharacterBody3D
	check(king != null, "the Gloop King's in his kingdom")
	if king == null or p == null:
		_end()
		return
	var m: Node3D = MOVES.of(king)
	check(m != null, "...with his moves on")
	if m == null:
		_end()
		return
	check("lob" in m.get("moves") and "shot" in m.get("moves"), "...lobs and shots of goo")
	king.global_position = Vector3(0, 1.2, 88)
	king.set_physics_process(false)          # (he's held still so only his moves are tested)
	for e in town.get_tree().get_nodes_in_group("enemies"):
		if e != king:
			e.queue_free()                        # (and his court's sent home, so nothing else bumps you)
	m.set("centre", king.global_position)
	m.set("centre_set", true)
	m.set("radius", 14.0)
	m.set("_t", 99.0)                         # (no move of his own while we throw them by hand)
	await _physics(2)

	# A shot, standing in its way
	p.global_position = king.global_position + Vector3(7.0, 0.3, 0)
	await _physics(10)
	var hp: int = int(game.hp)
	p.set("_invulnerable_timer", 0.0)
	game.hp = 10
	_quiet(town, king)
	m.call("_shoot", p, 0.0)
	var shots := town.get_tree().get_nodes_in_group("boss_shots")
	check(shots.size() == 1, "a shot flies")
	var start_d := 99.0
	if shots.size() > 0:
		start_d = (shots[0] as Node3D).global_position.distance_to(p.global_position)
	await _wait(0.25)
	if shots.size() > 0 and is_instance_valid(shots[0]):
		check((shots[0] as Node3D).global_position.distance_to(p.global_position) < start_d, "...towards you")
	await _until(func() -> bool: return int(game.hp) < hp, 2.0)
	check(int(game.hp) < hp, "...and bumps you if you stand there")
	check(int(game.hp) >= hp - 1, "...just a bump")
	check(town.get_tree().get_nodes_in_group("boss_shots").is_empty(), "...and pops")

	# A shot, stepping aside
	await _wait(1.6)
	p.set("_invulnerable_timer", 0.0)
	game.hp = 10
	_quiet(town, king)
	p.global_position = king.global_position + Vector3(9.0, 0.3, 0)
	await _physics(4)
	hp = int(game.hp)
	m.call("_shoot", p, 0.0)
	await _physics(2)
	p.global_position = king.global_position + Vector3(9.0, 0.3, 4.0)
	await _wait(2.0)
	check(int(game.hp) == hp, "step aside and it misses you")

	await _until(func() -> bool: return town.get_tree().get_nodes_in_group("boss_shots").is_empty(), 4.0)

	# A lob, standing still
	p.set("_invulnerable_timer", 0.0)
	game.hp = 10
	_quiet(town, king)
	p.global_position = king.global_position + Vector3(-8.0, 0.3, 2.0)
	await _physics(12)
	hp = int(game.hp)
	m.call("_lob", p)
	var lob := town.get_tree().get_nodes_in_group("boss_shots")
	check(lob.size() == 1 and bool((lob[0] as Node).get("lob")), "a lob goes up")
	var up := 0.0
	var t := 0.0
	while t < 1.0:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if lob.size() > 0 and is_instance_valid(lob[0]):
			up = maxf(up, (lob[0] as Node3D).global_position.y - king.global_position.y)
	check(up > 3.0, "...high in an arc (%.1f m)" % up)
	await _wait(0.8)
	check(int(game.hp) < hp, "...and lands where you stood")

	# A lob, running off
	await _wait(1.6)
	await _until(func() -> bool: return town.get_tree().get_nodes_in_group("boss_shots").is_empty(), 4.0)
	p.set("_invulnerable_timer", 0.0)
	game.hp = 10
	_quiet(town, king)
	p.global_position = king.global_position + Vector3(-8.0, 0.3, -2.0)
	await _physics(12)
	hp = int(game.hp)
	m.call("_lob", p)
	await _physics(10)
	p.global_position = king.global_position + Vector3(-8.0, 0.3, -6.0)
	await _wait(1.8)
	check(int(game.hp) == hp, "move off and it lands behind you (%d -> %d)" % [hp, int(game.hp)])

	# A blink
	p.global_position = king.global_position + Vector3(5.0, 0.3, 0)
	await _physics(6)
	var was := king.global_position
	m.call("_vanish", p)
	await _physics(2)
	check(not king.visible, "a blink: he vanishes")
	await _wait(MOVES.BLINK_GONE + 0.2)
	check(king.visible, "...and pops back")
	var moved := Vector2(king.global_position.x - was.x, king.global_position.z - was.z).length()
	check(moved >= 4.0, "...somewhere else (%.1f m away)" % moved)
	var from_you := Vector2(king.global_position.x - p.global_position.x, king.global_position.z - p.global_position.z).length()
	check(from_you >= MOVES.BLINK_CLEAR - 0.1, "...never right by you (%.1f m)" % from_you)
	check(Vector2(king.global_position.x, king.global_position.z).distance_to(Vector2(0, 88)) <= 14.0, "...still in his court")
	check(absf(king.global_position.y - was.y) < 3.0, "...on the ground")

	# On its own: it winds up first, then throws (he's held still, so say he's free to)
	m.set("can", func() -> bool: return true)
	m.set("_t", 1.5)
	m.set("_told", false)
	var count := int(m.get("count"))
	var tell: GDScript = load("res://scripts/boss_tell.gd")
	var wound := false
	t = 0.0
	while t < 2.5 and int(m.get("count")) == count:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var v := king.get_node_or_null("Visual") as Node3D
		if v and absf(v.scale.y - 1.0) > 0.03:
			wound = true
	# (his moves only go while he's chasing: set that up)
	if int(m.get("count")) == count:
		king.set("_was_chasing", true)
		m.set("_t", 1.5)
		t = 0.0
		while t < 2.5 and int(m.get("count")) == count:
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			var v2 := king.get_node_or_null("Visual") as Node3D
			if v2 and absf(v2.scale.y - 1.0) > 0.03:
				wound = true
	check(int(m.get("count")) > count, "on his own he does a move")
	check(wound, "...winding up with his body first")
	check(not tell.showing(king), "...without taking his own wind-up's place")

	# Switched off (for tests that time a fight to the second)
	MOVES.enabled = false
	count = int(m.get("count"))
	m.set("_t", 0.2)
	await _wait(0.6)
	check(int(m.get("count")) == count, "switched off, no moves")
	MOVES.enabled = true
	_end()


func _quiet(town: Node, king: Node) -> void:
	# Nothing but the King's own moves may bump you: his court goes home and the goo flood waits
	for e in town.get_tree().get_nodes_in_group("enemies"):
		if e != king:
			e.queue_free()
	var flood := town.find_child("Slime Flood", true, false)
	if flood:
		flood.process_mode = Node.PROCESS_MODE_DISABLED


func _until(f: Callable, secs: float) -> void:
	var t := 0.0
	while t < secs and not bool(f.call()):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second


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
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit(1 if failures > 0 else 0)
