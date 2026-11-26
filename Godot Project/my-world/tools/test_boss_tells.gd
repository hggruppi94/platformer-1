extends SceneTree

# Checks the bosses' warnings (scripts/boss_tell.gd): nothing is drawn on the ground or over the boss; the boss's
# body winds up instead (squashes down for "jump", rears back for "dash", stretches up for "drop" while the dropped
# thing falls from high over its spot, puffs up for "pull") and is left as it was after, even when the boss changes its
# own Visual every frame; it goes away by itself; the first time each one's seen a hint says what to do, and only the
# first time; Settings > Assist > Early boss warnings makes them longer. Then a real fight: the Gloop King winds up
# before he hops, and the flop still comes on time. And every boss script with a big attack uses it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boss_tells.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.tells_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.tells_backup.cfg"
var TELL: GDScript    # loaded once the autoloads are up (it reads Settings)
const BOSSES := ["gloop_king", "riptide_gloop", "time_goblin_boss", "crocodillo_boss", "the_hush", "the_gloam",
	"off_beat", "captain_glitch", "big_buzz", "chaos_fight", "starhorn", "old_ember"]

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
	TELL = load("res://scripts/boss_tell.gd")
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	var dialogue := root.get_node("Dialogue")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	settings.boss_warn_early = false

	# --- The setting ---
	check(absf(TELL.lead() - TELL.NORMAL) < 0.001, "warnings start %.1f s before an attack" % TELL.NORMAL)
	settings.boss_warn_early = true
	check(absf(TELL.lead() - TELL.EARLY) < 0.001, "Early boss warnings starts them at %.1f s" % TELL.EARLY)
	settings.boss_warn_early = false
	check(settings._props().has("boss_warn_early"), "...and it's saved with the settings")

	# --- Each shape, on a dummy boss ---
	var stage := Node3D.new()
	root.add_child(stage)
	var boss := Node3D.new()
	boss.name = "Dummy Boss"
	stage.add_child(boss)
	var visual := Node3D.new()
	visual.name = "Visual"
	boss.add_child(visual)
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.position.y = 1.0
	visual.add_child(body)
	await _frames(2)

	for kind in ["jump", "dash", "drop", "pull"]:
		dialogue.flags.erase("tell_seen_" + kind)
	game.pending_message = ""

	var t: Node3D = TELL.warn(boss, "jump", 7.0, Color(0.3, 0.9, 0.4), 0.5)
	await _frames(2)
	check(t != null and t.is_inside_tree() and t.is_in_group("boss_tells"), "a warning goes up")
	check(TELL.showing(boss), "...and the boss knows it's showing")
	check(_drawn(t) == 0, "nothing's drawn for it: no rings, arrows, shadows or \"!\"")
	check(body.material_overlay == null, "...and no glow painted over the boss")
	check(dialogue.flags.has("tell_seen_jump"), "the first wind-up says what to do")
	await _wait(0.35)
	check(visual.scale.y < 0.85 and visual.scale.x > 1.08, "\"jump\": the boss squashes down low (%.2f tall)" % visual.scale.y)
	await _wait(0.35)
	check(not is_instance_valid(t), "it goes away by itself when the attack comes")
	check(visual.scale.is_equal_approx(Vector3.ONE) and visual.position.is_equal_approx(Vector3.ZERO),
		"...and the boss is back to its own shape")
	check(not TELL.showing(boss), "...so the next one can show")

	game.pending_message = ""
	var hinted: int = dialogue.flags.size()
	var _t2: Node3D = TELL.warn(boss, "jump", 4.0, Color.WHITE, 0.2)
	await _frames(2)
	check(dialogue.flags.size() == hinted, "the hint's only said the first time")
	await _wait(0.3)

	# A boss that squashes its own Visual every frame: the wind-up goes on top, and it's left as the boss had it
	var bob := func() -> void:
		visual.scale = Vector3(1.0, 1.1, 1.0)
	process_frame.connect(bob)
	var d: Node3D = TELL.warn(boss, "dash", 12.0, Color.ORANGE, 0.5, {"dir": Vector3.RIGHT, "follow": null, "at": Vector3(0, 0.06, 0)})
	await _wait(0.4)
	check(visual.rotation.x > 0.15, "\"dash\": the boss rears back (%.2f)" % visual.rotation.x)
	check(_drawn(d) == 0, "...no arrows")
	await _wait(0.3)
	check(absf(visual.rotation.x) < 0.001, "...and stands up straight after")
	process_frame.disconnect(bob)
	await _frames(1)
	check(visual.scale.is_equal_approx(Vector3(1.0, 1.1, 1.0)), "a boss's own squash is left as it was")
	visual.scale = Vector3.ONE

	var dr: Node3D = TELL.warn(boss, "drop", 3.0, Color.GRAY, 0.5, {"follow": null, "at": Vector3(4, 0.06, 0)})
	await _frames(2)
	var fall := dr.get_node_or_null("Falling") as Node3D
	var y0 := fall.global_position.y if fall else 0.0
	check(fall != null and y0 > 10.0 and Vector2(fall.global_position.x - 4.0, fall.global_position.z).length() < 0.1,
		"\"drop\": what's dropping is up over where it'll land (%.1f m up)" % y0)
	await _wait(0.4)
	check(fall != null and is_instance_valid(fall) and fall.global_position.y < y0 - 4.0, "...and falls as the attack comes")
	check(visual.scale.y > 1.05, "...while the boss stretches up tall")
	await _wait(0.3)

	var pl: Node3D = TELL.warn(boss, "pull", 8.0, Color.CYAN, 0.6)
	await _wait(0.45)
	check(visual.scale.x > 1.12 and visual.scale.y > 1.1, "\"pull\": the boss puffs up")
	check(_drawn(pl) == 0, "...no arrows")
	await _wait(0.4)

	# Two wind-ups on one body at once (Tuskwinter, 26 Nov 2026: its flop's "jump" and a throw from boss_moves.gd
	# overlapped, each took the other's pose as its base, and it grew giant and flat for good). They add together
	# once, stay in shape however long they overlap, and the boss is left as it was when both are done.
	visual.scale = Vector3.ONE * 2.2
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	var big := Vector3.ONE * 2.2
	var j: Node3D = TELL.warn(boss, "jump", 6.0, Color.WHITE, 1.2)
	await _wait(0.3)
	var th: Node3D = TELL.warn(boss, "throw", 2.0, Color.WHITE, 0.9)
	var widest := 0.0
	var flattest := 99.0
	var until := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < until:
		await process_frame
		widest = maxf(widest, visual.scale.x)
		flattest = minf(flattest, visual.scale.y)
	var most_wide: float = 2.2 * float(TELL.POSES.jump.widen) * float(TELL.POSES.throw.widen) + 0.01
	var most_flat: float = 2.2 * float(TELL.POSES.jump.squash) - 0.01
	check(widest <= most_wide, "two wind-ups at once don't grow on each other (%.2f wide, most %.2f)" % [widest, most_wide])
	check(flattest >= most_flat, "...or flatten it (%.2f tall, least %.2f)" % [flattest, most_flat])
	await _wait(1.0)
	check(not is_instance_valid(j) and not is_instance_valid(th), "...both go away")
	check(visual.scale.is_equal_approx(big) and visual.position.is_equal_approx(Vector3.ZERO)
		and absf(visual.rotation.x) < 0.001, "...and the boss is back to its own size and shape (%s)" % visual.scale)
	check(not visual.has_meta(TELL.STACK), "...with nothing left on it")
	# One that's cleared early (a boss calling queue_free on its wind-ups) still lets the boss go back to its shape
	var q1: Node3D = TELL.warn(boss, "jump", 6.0, Color.WHITE, 2.0)
	var q2: Node3D = TELL.warn(boss, "pull", 6.0, Color.WHITE, 2.0)
	await _wait(0.5)
	q1.queue_free()
	q2.queue_free()
	await _frames(3)
	check(visual.scale.is_equal_approx(big), "wind-ups cleared early leave the boss its own size (%s)" % visual.scale)
	visual.scale = Vector3.ONE

	for kind in ["jump", "dash", "drop", "pull"]:
		check(TELL.HINTS.has(kind) and String(TELL.HINTS[kind]).split(" ").size() <= 5, "the %s hint is short" % kind)
	stage.queue_free()
	await _frames(2)

	# --- Every boss uses it ---
	for b in BOSSES:
		var src := FileAccess.get_file_as_string("res://scripts/%s.gd" % b)
		check(src.contains("TELL.warn("), "%s warns before its big attack" % b)

	# --- A real fight: the Gloop King's flop ---
	root.get_node("Bosses").enter_kingdom()
	await _frames(10)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var king := town.get_node_or_null("The Gloop King") as CharacterBody3D
	check(king != null, "the Gloop King's in his kingdom")
	if king == null:
		_end()
		return
	king.global_position = Vector3(0, 1.2, 88)
	p.global_position = king.global_position + Vector3(6.0, 0.5, 0.0)
	king.set("_flop_timer", 2.0)
	var seen_at := -1.0
	var flop_at := -1.0
	var reach := 0.0
	var clock := 0.0
	while clock < 8.0 and flop_at < 0.0:
		await physics_frame
		clock += 1.0 / Engine.physics_ticks_per_second
		p.global_position = king.global_position + Vector3(6.0, 0.0, 0.0)
		if seen_at < 0.0 and TELL.showing(king):
			seen_at = clock
			reach = float((king.get_meta("boss_tell") as Node3D).get("reach"))
		if bool(king.get("_flopping")):
			flop_at = clock
	check(seen_at >= 0.0, "the King winds up before he flops")
	check(flop_at > 0.0, "...and he still flops")
	check(flop_at - seen_at >= TELL.NORMAL - 0.1, "...%.2f s after it shows" % (flop_at - seen_at))
	var want: float = float(king.get("flop_reach")) * float(king.get("size"))
	check(reach >= want * 0.99, "...for a flop as wide as his goo goes (%.1f m)" % reach)
	_end()


func _drawn(t: Node) -> int:
	# How many things a warning draws of its own (only "drop" draws anything: the thing that's falling)
	if t == null or not is_instance_valid(t):
		return 0
	return t.find_children("*", "MeshInstance3D", true, false).size() + t.find_children("*", "Label3D", true, false).size()


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
