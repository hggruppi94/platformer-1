extends SceneTree

# Checks the shape-built bosses' baked parts (25 Nov 2026, tools/build_prop_bosses.py and scripts/detail_props.gd):
# the Gloop King wears the detailed crown, every Time Goblin cog and Grandfather Tock's clock hat are the Clockyard's
# baked cog and clock, and the Boulderdillo's boulders are Boulder Hollow's baked boulder. The old shapes are hidden
# (never freed: the fights still use them), Tock's hand sits on the new face, and with detail off nothing changes.
# Part two: Tuskwinter's hide, Grumblefin's scales, the Dawn Snatcher's feathers and the Stormram's fleece are baked
# skins on their balls (detail_props.gd dress_surfaces), each the old ball's colour, scaled with it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boss_detail.gd
#
# Only makes the bosses in an empty scene: no save or setting is touched.

const DP := preload("res://scripts/detail_props.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _drawn(mi: Node) -> bool:
	return mi is GeometryInstance3D and (mi as GeometryInstance3D).visible and (mi as VisualInstance3D).layers != 0


func _make(what: String) -> Node3D:
	var n: Node3D
	match what:
		"king":
			n = (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate()
		"goblin":
			n = (load("res://scenes/enemies/time_goblin.tscn") as PackedScene).instantiate()
		"tock":
			n = (load("res://scenes/enemies/time_goblin_boss.tscn") as PackedScene).instantiate()
		"boulder":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/crocodillo_boss.gd"))
			n.set("size", 2.6)
		"frost", "riptide":
			n = (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/%s_gloop.gd" % what))
			n.set("size", 2.3)
		"snatcher":
			n = (load("res://scenes/enemies/time_goblin_boss.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/dawn_snatcher.gd"))
			n.set("size", 2.4)
		"stormram":
			n = (load("res://scenes/enemies/crocodillo.tscn") as PackedScene).instantiate()
			n.set_script(load("res://scripts/stormram.gd"))
			n.set("size", 2.2)
	n.position = Vector3(randf_range(-50, 50), 200, randf_range(-50, 50))
	root.add_child(n)
	return n


func _run() -> void:
	var wd: Node = root.get_node_or_null("WorldDetail")
	check(wd != null and DP.on(), "the detail pipeline is on")
	var king := _make("king")
	var goblin := _make("goblin")
	var tock := _make("tock")
	var boulder := _make("boulder")
	var skinned := {"frost": 2, "riptide": 2, "snatcher": 2, "stormram": 20}
	var skin_bosses := {}
	for w in skinned:
		skin_bosses[w] = _make(w)
	for i in 4:
		await process_frame
	for n in [king, goblin, tock, boulder] + skin_bosses.values():
		n.process_mode = Node.PROCESS_MODE_DISABLED

	# The Gloop King's crown
	var crown := king.get_node_or_null("Visual/Body/Crown")
	check(crown != null and crown.has_node("Detailed Crown"), "the Gloop King wears the detailed crown")
	if crown:
		var old := crown.get_children().filter(func(c): return c is MeshInstance3D)
		check(old.size() > 0 and old.all(func(c): return not _drawn(c)), "his old crown shapes aren't drawn (%d)" % old.size())
	check(DP.dress_king_crown(king) and crown.find_children("Detailed Crown", "", false, false).size() == 1,
		"dressing him again changes nothing")

	# The goblins' cogs and Tock's hat
	for g in [goblin, tock]:
		var cogs := (g as Node).find_children("Cog", "Node3D", true, false)
		var done := cogs.filter(func(c): return c.has_node("Detailed Cog"))
		check(cogs.size() > 0 and done.size() == cogs.size(), "%s: every cog is the baked cog (%d of %d)" % [
			g.name, done.size(), cogs.size()])
		var bare := 0
		for c in done:
			for p in c.get_children():
				if p is MeshInstance3D and _drawn(p):
					bare += 1
		check(bare == 0, "%s: no old cog pieces drawn" % g.name)
	var clock := tock.get_node_or_null("Visual/Head/Clock")
	check(clock != null and clock.has_node("Detailed Clock Case") and clock.has_node("Detailed Clock Hood"),
		"Tock's hat is the baked grandfather clock")
	if clock:
		var hand := clock.get_node_or_null("Hand") as Node3D
		check(hand != null and hand.visible and absf(hand.position.y - DP.HAT_FACE_Y) < 0.01,
			"his clock hand still turns on the new face")
		check(clock.get_node_or_null("Pendulum") == null or (clock.get_node("Pendulum") as Node3D).visible,
			"his pendulum still swings")
		var case := clock.get_node_or_null("Case")
		check(case != null and not _drawn(case), "his old clock case isn't drawn")
	var again := DP.dress_goblin(tock)
	check(again.y == 1 and clock.find_children("Detailed Clock Case", "", false, false).size() == 1,
		"dressing Tock again changes nothing")

	# The Boulderdillo
	var rocks := boulder.find_children("*Boulder*", "MeshInstance3D", true, false).filter(
		func(m): return not String(m.name).begins_with("Detailed"))
	var baked := boulder.find_children("Detailed *Boulder*", "", true, false)
	check(rocks.size() > 0 and baked.size() == rocks.size(), "the Boulderdillo's %d boulders are the baked boulder (%d)" % [
		rocks.size(), baked.size()])
	check(rocks.all(func(m): return not _drawn(m)), "its old boulder balls aren't drawn")

	# Part two: the baked skins
	for w in skinned:
		var b: Node3D = skin_bosses[w]
		var skins := b.find_children("Detailed Skin", "MeshInstance3D", true, false)
		check(skins.size() >= skinned[w], "%s: %d balls wear a baked skin (at least %d)" % [w, skins.size(), skinned[w]])
		var ok := true
		for sk in skins:
			var ball := sk.get_parent() as MeshInstance3D
			var sm := ball.mesh as SphereMesh if ball else null
			var mat := (sk as MeshInstance3D).material_override as StandardMaterial3D
			var old := ball.material_override as StandardMaterial3D if ball else null
			if sm == null or _drawn(ball) or not _drawn(sk) or mat == null or mat.albedo_texture == null or old == null:
				ok = false
			elif absf((sk as Node3D).scale.x - sm.radius) > 0.001:
				ok = false
			elif absf(mat.albedo_color.r - old.albedo_color.r * DP.BOSS_SKIN_GAIN) > 0.01:
				ok = false
		check(ok and skins.size() > 0, "%s: each skin is its ball's size and colour, and the plain ball isn't drawn" % w)
		var before := skins.size()
		DP.dress_surfaces(b, [])
		check(b.find_children("Detailed Skin", "MeshInstance3D", true, false).size() == before,
			"%s: dressing it again changes nothing" % w)

	# Detail off: a new boss is left as built
	if wd:
		wd.set("detail_props", false)
		var plain := _make("king")
		await process_frame
		await process_frame
		var pc := plain.get_node_or_null("Visual/Body/Crown")
		check(pc != null and not pc.has_node("Detailed Crown"), "with detail off the King keeps his old crown")
		var plain_ram := _make("stormram")
		await process_frame
		await process_frame
		check(plain_ram.find_children("Detailed Skin", "", true, false).is_empty(),
			"with detail off the Stormram keeps its plain fleece")
		wd.set("detail_props", true)

	print("\nRESULT %s (%d failed)" % ["FAILED" if failures else "PASSED", failures])
	quit(1 if failures else 0)
