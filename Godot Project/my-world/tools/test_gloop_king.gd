extends SceneTree

# Checks the Gloop King and the restyled Gloops (tools/build_gloop.gd, scripts/gloop.gd, scripts/gloop_king.gd):
# every Gloop wears the new goo (its own copy, so a hit only flashes that one), has big glassy eyes, stubby feet and
# no old grin, and keeps dripping (a drop swells, falls, splats and starts again). The King is in town in his crown,
# much bigger than a Gloop, with his court about him. Bubbles pop him only after six (a big bubble counts for three),
# he calls in more Gloops as he goes, and those don't come back once popped. His belly-flop ring bumps you on the
# ground but not if you jump over it, and he comes back later with all his goo.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_gloop_king.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const GOO := "res://scenes/enemies/gloop_goo.gdshader"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
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
	var enemies := town.find_child("Enemies", true, false)
	var gloops: Array[Node] = []
	for e in enemies.get_children():
		if e.has_method("_drip") and e.name != "The Gloop King":
			gloops.append(e)
	check(gloops.size() >= 10, "the Gloops are still about town (%d)" % gloops.size())

	# --- The new look, on every Gloop ---
	var all_goo := true
	var all_eyes := true
	var all_feet := true
	var no_grin := true
	var all_drips := true
	for g in gloops:
		var body := g.get_node("Visual/Body") as MeshInstance3D
		var m := body.material_override as ShaderMaterial
		all_goo = all_goo and m != null and m.shader.resource_path == GOO
		all_eyes = all_eyes and body.get_node_or_null("EyeL") != null and body.get_node_or_null("EyeR") != null
		all_feet = all_feet and g.get_node("Visual/Feet").get_child_count() == 4
		no_grin = no_grin and body.get_node_or_null("Grin") == null and body.get_node_or_null("Teeth") == null
		all_drips = all_drips and body.get_node("Drips").get_child_count() >= 4 and g.get_node_or_null("Puddle") != null
	check(all_goo, "every Gloop is made of the new goo")
	check(all_eyes, "...with big glassy eyes")
	check(all_feet, "...stubby feet")
	check(no_grin, "...and none has the old toothy grin")
	check(all_drips, "...and drips into a puddle")
	var m0 := (gloops[0].get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	var m1 := (gloops[1].get_node("Visual/Body") as MeshInstance3D).material_override as ShaderMaterial
	check(m0 != m1, "each Gloop has its own goo, so a hit only flashes that one")
	var big := town.find_child("Big Gloop *", true, false)
	check(big != null and absf(float(big.get("goldness")) - 0.6) < 0.01, "big Gloops have goldier goo")

	# --- The King ---
	var king := enemies.get_node_or_null("The Gloop King") as CharacterBody3D
	check(king != null, "the Gloop King is in town")
	if king == null:
		_end()
		return
	check(king.find_child("Crown", true, false) != null and king.find_child("Gem", true, false) != null,
		"...wearing his gold crown with its red gem")
	check(gloops[0].find_child("Crown", true, false) == null, "ordinary Gloops have no crown")
	var kh := _height(king)
	var gh := _height(gloops[0])
	check(kh > gh * 1.8, "he's much bigger than a Gloop (%.1f m to %.1f m)" % [kh, gh])
	check(king.global_position.y > -0.2, "he's on dry land, not in the lake")
	var court := 0
	for g in gloops:
		if (g as Node3D).global_position.distance_to(king.global_position) < 20.0:
			court += 1
	check(court >= 2, "he holds court with Gloops near him (%d)" % court)

	# --- Dripping ---
	# Hold one Gloop still where the player can see it, and watch a drop go round its loop
	var g0 := gloops[0] as CharacterBody3D
	g0.set_physics_process(false)
	g0.player = p
	p.global_position = g0.global_position + Vector3(0, 0, 4)
	var seen_drop := false
	var fell := false
	var splat := false
	var again := false
	var top_y := -INF
	for i in 600:
		g0._t += 1.0 / 60.0
		g0._animate(1.0 / 60.0, 0.0, false)
		var d: Dictionary = g0._drops[0]
		var mesh := d.mesh as Node3D
		if mesh.visible and d.t > 0.0:
			seen_drop = true
			top_y = maxf(top_y, mesh.position.y)
			if mesh.position.y < top_y - 0.1:
				fell = true
			if mesh.scale.y < 0.5 and mesh.position.y < 0.05:
				splat = true
		if splat and d.t == 0.0:
			again = true
			break
	check(seen_drop, "a drop swells on the tip of a goo tongue")
	check(fell, "...falls")
	check(splat, "...splats flat on the ground")
	check(again, "...and the next one starts (it loops)")
	g0.set_physics_process(true)

	# --- Popping the King with bubbles ---
	for g in gloops:
		(g as Node3D).set_physics_process(false)
	king.set_physics_process(false)
	var xp: int = game.xp
	var level: int = game.level
	var meter := king.get_node("GooMeter") as Node3D
	for i in 5:
		king.shot(1, king.global_position, Vector3.FORWARD)
	check(not king.defeated and king.hits == 5, "five bubbles aren't enough for the King")
	var courtiers := town.find_children("Courtier Gloop *", "", true, false)
	check(courtiers.size() == 4, "he calls in his court as he goes (%d more Gloops)" % courtiers.size())
	king.shot(1, king.global_position, Vector3.FORWARD)
	check(king.defeated, "...the sixth pops him")
	check(game.xp >= xp + 40 or game.level > level, "...for lots of XP")
	check(meter != null, "he has a goo meter over his crown")
	for c in courtiers:
		c.shot(1, (c as Node3D).global_position, Vector3.FORWARD)
	await create_timer(3.2).timeout
	check(town.find_children("Courtier Gloop *", "", true, false).is_empty(),
		"popped courtiers are gone for good (they don't respawn)")
	# He comes back later with all his goo
	p.global_position = king.home + Vector3(40, 0, 40)
	king._try_respawn()
	await _frames(2)
	check(not king.defeated and king.hits == 0, "the King comes back later with all his goo")
	king.shot(3, king.global_position, Vector3.FORWARD)
	check(king.hits == 3 and not king.defeated, "a big bubble counts for three")
	king.hits = 0

	# --- The belly-flop ring ---
	king.player = p
	var hp: int = game.hp
	p.global_position = king.global_position + Vector3(4.0, 3.0, 0.0)       # in the air over the ring
	p.velocity = Vector3.ZERO
	await _physics(1)
	king._land()
	check(game.hp == hp, "jumping over the goo ring is safe")
	p.global_position = king.global_position + Vector3(4.0, 0.6, 0.0)
	for i in 60:
		await physics_frame
		if p.is_on_floor():
			break
	check(p.is_on_floor(), "(the player is standing on the ground)")
	p._invulnerable_timer = 0.0
	king._land()
	check(game.hp < hp, "standing in the goo ring gets you bumped")
	await _frames(3)
	check(town.find_children("GooRing", "", true, false).size() > 0, "the ring of goo spreads across the ground")
	game.hp = hp

	# --- Reduce motion calms the oozing ---
	var settings := root.get_node("Settings")
	var was: bool = settings.reduce_motion
	settings.reduce_motion = true
	g0._animate(1.0 / 60.0, 0.0, false)
	check(absf(float(m0.get_shader_parameter("ooze")) - 0.35) < 0.01, "Reduce motion slows the oozing")
	settings.reduce_motion = was
	_end()


func _height(n: Node) -> float:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.name == "Drop":
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
