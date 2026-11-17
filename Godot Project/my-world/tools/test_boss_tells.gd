extends SceneTree

# Checks the bosses' warnings (scripts/boss_tell.gd): every shape builds what it should (a ring that fills for "jump",
# arrows for "dash", a growing shadow for "drop", arrows pointing in for "pull"), with a gold "!" and a glow on the
# boss that comes off again; it goes away by itself; the first time each shape's seen a hint says what to do, and only
# the first time; Settings > Assist > Early boss warnings starts them sooner. Then a real fight: the Gloop King's
# ring shows on the ground before he hops, as wide as his flop reaches, and the flop still comes on time. And every
# boss script with a big attack uses it.
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
	var edge := t.get_node_or_null("Mark/Edge") as Node3D
	check(edge != null and absf(float(edge.get_meta("reach")) - 7.0) < 0.01 and _wide(edge) > 13.5, "\"jump\": a ring on the ground as far as it reaches")
	var fill := t.get_node_or_null("Mark/Fill") as Node3D
	check(fill != null, "...with a disc filling out to it")
	var bang := t.get_node_or_null("Bang") as Label3D
	check(bang != null and bang.text == "!" and bang.position.y > 1.5, "a gold \"!\" over the boss")
	check(body.material_overlay != null, "the boss glows")
	check(dialogue.flags.has("tell_seen_jump"), "the first ring says what to do")
	var f0 := _wide(fill)
	await _wait(0.3)
	check(is_instance_valid(fill) and _wide(fill) > f0, "...and it fills as the attack gets nearer")
	await _wait(0.4)
	check(not is_instance_valid(t), "it goes away by itself when the attack comes")
	check(body.material_overlay == null, "...and the glow comes off")
	check(not TELL.showing(boss), "...so the next one can show")

	game.pending_message = ""
	var hinted: int = dialogue.flags.size()
	var _t2: Node3D = TELL.warn(boss, "jump", 4.0, Color.WHITE, 0.2)
	await _frames(2)
	check(dialogue.flags.size() == hinted, "the hint's only said the first time")
	await _wait(0.3)

	var d: Node3D = TELL.warn(boss, "dash", 12.0, Color.ORANGE, 0.4, {"dir": Vector3.RIGHT, "follow": null, "at": Vector3(0, 0.06, 0)})
	await _frames(3)
	var arrows: int = d.get_node("Mark").get_child_count()
	check(arrows >= 3, "\"dash\": a stripe of arrows (%d)" % arrows)
	var fwd := -(d.get_node("Mark") as Node3D).global_basis.z
	check(fwd.dot(Vector3.RIGHT) > 0.95, "...pointing the way it'll charge")
	check(d.get_node("Mark").get_child(0).position.z <= 0.0 and d.get_node("Mark").get_child(0).position.z >= -12.0,
		"...no further than it'll go")
	await _wait(0.5)

	var dr: Node3D = TELL.warn(boss, "drop", 3.0, Color.GRAY, 0.4)
	await _frames(2)
	var shadow := dr.get_node_or_null("Mark/Shadow") as Node3D
	var s0 := _wide(shadow) if shadow else 0.0
	await _wait(0.25)
	check(shadow != null and is_instance_valid(shadow) and _wide(shadow) > s0, "\"drop\": a shadow that grows")
	await _wait(0.3)

	var pl: Node3D = TELL.warn(boss, "pull", 8.0, Color.CYAN, 0.6)
	await _frames(2)
	var a := pl.get_node("Mark").get_child(0) as Node3D
	var r0 := Vector2(a.position.x, a.position.z).length()
	check(pl.get_node("Mark").get_child_count() == 10, "\"pull\": a ring of arrows")
	await _wait(0.2)
	var r1 := Vector2(a.position.x, a.position.z).length()
	check(r1 < r0 or r1 > 7.0, "...sliding in towards the boss")
	await _wait(0.6)

	for kind in ["jump", "dash", "drop", "pull"]:
		check(TELL.HINTS.has(kind) and String(TELL.HINTS[kind]).split(" ").size() <= 6, "the %s hint is short" % kind)

	# On bumpy ground the ring hugs the bumps (a slope under one side: nothing sinks into it)
	var hill := StaticBody3D.new()
	var hs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(20, 2, 20)
	hs.shape = hb
	hill.add_child(hs)
	stage.add_child(hill)
	hill.global_position = Vector3(6, -0.6, 0)
	hill.rotation.z = 0.12
	var flat := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(40, 1, 40)
	fs.shape = fb
	flat.add_child(fs)
	stage.add_child(flat)
	flat.global_position = Vector3(0, -0.5, 0)
	await _physics(3)
	var tb: Node3D = TELL.warn(boss, "jump", 8.0, Color.WHITE, 0.5, {"ground_y": 0.0})
	await _frames(3)
	var em := (tb.get_node("Mark/Edge") as MeshInstance3D).mesh
	var lo := INF
	var hi := -INF
	var space := (stage.get_world_3d()).direct_space_state
	var under := 0
	for v in em.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var w: Vector3 = tb.global_transform * v
		lo = minf(lo, w.y)
		hi = maxf(hi, w.y)
		var q := PhysicsRayQueryParameters3D.create(Vector3(w.x, 5, w.z), Vector3(w.x, -5, w.z))
		var hit := space.intersect_ray(q)
		if hit and float(hit.position.y) > w.y + 0.01:
			under += 1
	check(hi - lo > 0.5, "on a slope the ring follows the ground up and down (%.1f m)" % (hi - lo))
	check(under == 0, "...and none of it's under the ground (%d bits)" % under)
	await _wait(0.6)
	hill.queue_free()
	flat.queue_free()

	# A boss that already had an overlay keeps it
	var keep := StandardMaterial3D.new()
	body.material_overlay = keep
	var t3: Node3D = TELL.warn(boss, "jump", 3.0, Color.WHITE, 0.2)
	await _wait(0.4)
	check(body.material_overlay == keep and not is_instance_valid(t3), "a mesh with its own overlay keeps it")
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
			var tt := king.get_meta("boss_tell") as Node3D
			var e := tt.get_node_or_null("Mark/Edge") as Node3D
			reach = float(e.get_meta("reach")) if e else 0.0
		if bool(king.get("_flopping")):
			flop_at = clock
	check(seen_at >= 0.0, "the King's ring shows on the ground before he flops")
	check(flop_at > 0.0, "...and he still flops")
	check(flop_at - seen_at >= TELL.NORMAL - 0.1, "...%.2f s after it shows" % (flop_at - seen_at))
	var want: float = float(king.get("flop_reach")) * float(king.get("size"))
	check(reach >= want * 0.99, "...and the ring's as wide as his goo goes (%.1f m)" % reach)
	_end()


func _wide(mi: Node3D) -> float:
	# How wide a draped mark is, from its mesh
	var m := mi as MeshInstance3D
	if m == null or m.mesh == null:
		return 0.0
	return m.mesh.get_aabb().size.x


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
