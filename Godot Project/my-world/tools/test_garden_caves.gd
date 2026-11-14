extends SceneTree

# Checks the Undergardens, the caves under the Secret Gardens hill (scripts/garden_caves.gd): the Rootwell is
# tangled shut until Pip's glow is yours and open after; the cave lies wholly inside the hill, under the gardens, with
# rock over it everywhere; you can see down the hole to its floor; the root steps climb all the way up; every room and
# tunnel has floor and head room; the caves are dark and Pip's glow comes on in them; the glow steps and bridges are
# only solid in the glow; each spore sits over a floor; walking into one finds it once and starts the quest; falling
# into the Deep Crack floats you back; the glow wakes the Old Taproot; with all four spores he gives Glowcap seeds and
# the quest ends; Bramble tells you about the caves; and Glowcaps grow in the garden with their own look.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_garden_caves.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.garden_caves_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.garden_caves_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const KIT := preload("res://scripts/cave_kit.gd")

var failures := 0
var game: Node
var portals: Node
var dialogue: Node
var caves: Node
var farm: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(420.0, true, false, true).timeout.connect(func() -> void:
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
	dialogue = root.get_node("Dialogue")
	farm = root.get_node("Farm")
	caves = root.get_node("Farm/Caves")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	var fn := root.get_node("FirstNight")
	root.get_node("Quests").state[fn.ID] = {"step": 0, "done": true, "since_day": 1}

	# --- Before Pip's glow: tangled shut ---------------------------------------------------------------------------
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(6)
	var ug := current_scene.get_node_or_null("Undergardens") as Node3D
	check(ug != null, "the Undergardens are put into the Void")
	var lid := ug.get_node_or_null("The Rootwell/Tangle") as Node3D if ug else null
	check(lid != null and lid.visible, "before Lanternmoor's mended, a tangle of roots covers the Rootwell")
	var hit := _ray(Vector3(caves.MOUTH.x, 30.0, caves.MOUTH.y), Vector3(caves.MOUTH.x, -20.0, caves.MOUTH.y))
	check(not hit.is_empty() and (hit.position as Vector3).y > 11.0,
		"...and it's solid: you can't drop in (lands at %.1f)" % ((hit.position as Vector3).y if not hit.is_empty() else -99.0))
	var peer := ug.get_node_or_null("The Rootwell/Peer") if ug else null
	check(peer != null and str(peer.offer.call()) == "peer down", "...and peering in says it's too dark")
	check(not dialogue.flags.has("undergardens_start"), "...and the quest hasn't started")

	# --- With Pip's glow ---------------------------------------------------------------------------------------------
	portals.cleared_worlds.append("lanternmoor")
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(6)
	ug = current_scene.get_node_or_null("Undergardens") as Node3D
	lid = ug.get_node_or_null("The Rootwell/Tangle") as Node3D
	check(not lid.visible, "with Pip's glow the tangle's gone")
	hit = _ray(Vector3(caves.MOUTH.x, 30.0, caves.MOUTH.y), Vector3(caves.MOUTH.x, -20.0, caves.MOUTH.y))
	var bottom := (hit.position as Vector3).y if not hit.is_empty() else 99.0
	check(bottom < caves.FLOOR + 0.5, "...and you can see right down the Rootwell to the cave floor (%.1f)" % bottom)
	var near := 0
	for e in get_nodes_in_group("enemies"):
		var h = e.get("home")
		if h is Vector3 and (h as Vector3).y > 9.0 and Vector2(h.x, h.z).distance_to(caves.MOUTH) < caves.GLOOP_CLEAR - 0.1:
			near += 1
	check(near == 0, "no Gloop lives near the Rootwell, so none wander in (%d)" % near)
	var g := _terrain_height(Vector2(caves.MOUTH.x - 6.0, caves.MOUTH.y))
	check(g > 11.0, "...which is up on top of the hill (%.1f)" % g)

	# The cave lies inside the hill, with rock over it
	var f: Dictionary = caves._field
	var worst := 99.0
	var worst_at := Vector3.ZERO
	var air := 0
	for k in range(0, f.nz, 2):
		for i in range(0, f.nx, 2):
			var top_air := -99.0
			for j in f.ny:
				if f.d[(k * f.ny + j) * f.nx + i] < 0.0:
					top_air = f.lo.y + j * f.s
			if top_air < -50.0:
				continue
			var x: float = f.lo.x + i * f.s
			var z: float = f.lo.z + k * f.s
			if Vector2(x, z).distance_to(caves.MOUTH) < caves.MOUTH_R + 1.5:
				continue                                     # the way in, of course
			air += 1
			var t := _terrain_height(Vector2(x, z))
			if t - top_air < worst:
				worst = t - top_air
				worst_at = Vector3(x, top_air, z)
	check(air > 200 and worst > 0.9, "the cave is wholly inside the hill, at least 0.9 m of rock over it everywhere (%.2f at %s)" % [worst, worst_at])

	# Floors and head room along the whole loop
	var path := [Vector3(-93.0, 0, -51.0), Vector3(-87.0, 0, -52.0), Vector3(-80.0, 0, -50.0), Vector3(-73.0, 0, -50.0),
		Vector3(-68.0, 0, -48.5), Vector3(-61.0, 0, -44.0), Vector3(-62.0, 0, -39.0), Vector3(-65.0, 0, -34.5),
		Vector3(-69.0, 0, -32.0), Vector3(-79.5, 0, -31.0), Vector3(-83.0, 0, -34.0), Vector3(-84.0, 0, -36.0),
		Vector3(-94.5, 0, -36.5), Vector3(-97.0, 0, -40.5), Vector3(-97.5, 0, -43.5)]
	var ok := true
	var bad := ""
	for p in path:
		var down := _ray(Vector3(p.x, 5.0, p.z), Vector3(p.x, -10.0, p.z))
		var up := _ray(Vector3(p.x, 5.0, p.z), Vector3(p.x, 20.0, p.z))
		if down.is_empty() or up.is_empty():
			ok = false
			bad += " %s(none)" % p
			continue
		var fl := (down.position as Vector3).y
		var room := (up.position as Vector3).y - fl
		if fl < caves.FLOOR - 1.2 or fl > caves.FLOOR + 1.0 or room < 2.4:
			ok = false
			bad += " %s(floor %.1f, room %.1f)" % [p, fl, room]
	check(ok, "every room and tunnel on the loop has a floor and head room" + bad)

	# The root steps: all the way up, each a short hop
	var steps := ug.get_node("Root Steps").get_children()
	var hop_ok := true
	for i in range(1, steps.size()):
		var a := (steps[i - 1] as Node3D).global_position
		var b := (steps[i] as Node3D).global_position
		if b.y - a.y > 0.6 or Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) > 2.0:
			hop_ok = false
	var last := (steps[-1] as Node3D).global_position.y if not steps.is_empty() else 0.0
	check(steps.size() > 12 and hop_ok and last > 10.8, "%d root steps spiral up the shaft, each a short hop, the top one at %.1f m" % [steps.size(), last])
	var first := (steps[0] as Node3D).global_position
	check(Vector2(first.x, first.z).distance_to(caves.MOUTH) < caves.MOUTH_R and first.y < caves.FLOOR + 0.8,
		"...from just over the cave floor")

	# Each spore sits over a floor (or a cap, a shelf, a ledge)
	for sp in caves.SPORES:
		var under := _ray(sp.at, sp.at + Vector3(0, -3.0, 0))
		check(not under.is_empty() and (sp.at as Vector3).y - (under.position as Vector3).y < 1.2,
			"the spore %s has something to stand on under it" % sp.where)

	# --- In the dark, with the glow ---------------------------------------------------------------------------------
	var player := get_first_node_in_group("player") as CharacterBody3D
	var glow: Node = player.pip_glow
	_put(player, Vector3(-80.0, caves.FLOOR + 0.9, -48.0))
	await _physics(10)
	await _frames(4)
	check(glow.in_dark and glow.shining(), "under the hill it's dark, and Pip's glow comes on")
	check(dialogue.flags.has("undergardens_start"), "...and going down there starts the quest")
	check(not caves.taproot_awake(), "the Old Taproot's asleep till the glow reaches him")
	# Glow steps: solid only in the glow
	var dust := ug.get_node("Root Hall/Dust Step1") as Node3D
	await _frames(30)
	check(glow.is_shown(dust), "the moth-dust steps up to the Root Hall's ledge show in the glow")
	_put(player, Vector3(-95.5 + 1.0, caves.FLOOR + 0.9, -37.0 + 5.0))
	await _physics(6)
	await _frames(40)
	check(not glow.is_shown(dust), "...and fade away when you're far off")

	# Falling into the Deep Crack floats you back
	_put(player, Vector3(caves.CRACK.x + 2.0, caves.PIT_FLOOR + 1.0, caves.CRACK.z))
	await _physics(4)
	await _frames(12)
	check(player.global_position.y > caves.FLOOR - 0.2 and player.global_position.x > caves.CRACK.x + caves.CRACK_HALF,
		"falling into the Deep Crack floats you back to its edge")

	# The glow bridge out to the pillar
	_put(player, Vector3(caves.CRACK.x + caves.CRACK_HALF + 1.5, caves.FLOOR + 0.9, caves.CRACK.z))
	await _physics(6)
	await _frames(40)
	var plank := ug.get_node("Deep Crack/Glow Bridge/Plank1") as Node3D
	check(glow.is_shown(plank), "the glow bridge over the Deep Crack shows up in Pip's glow")

	# The spores
	check(caves.spores_found() == 0, "no spores found yet")
	for sp in caves.SPORES:
		_put(player, sp.at + Vector3(0, 0.4, 0))
		await _physics(3)
		await _frames(14)
		check(dialogue.flags.has(sp.flag), "walking into the spore %s finds it" % sp.where)
	check(caves.spores_found() == 4, "all four found")
	check(ug.find_child("Spore ug_*", true, false) == null, "...and they're gone from the caves")

	# The Old Taproot
	_put(player, caves.TAPROOT + Vector3(3.0, 0.9, 0.0))
	await _physics(4)
	await _frames(8)
	check(caves.taproot_awake(), "Pip's glow wakes the Old Taproot")
	var face := ug.get_node("The Old Taproot/Face")
	check(face.get_node("Eyes").visible and not face.get_node("Lids").visible, "...and he opens his eyes")
	var sparkles_before: int = game.sparkles
	var lines: Array = caves.lines()
	await _frames(4)
	# (A real talk: everything he says is a line Dialogue.say() can show, and the spores go in as he says it)
	check(lines.all(func(l) -> bool: return l is String), "his talk is all lines (a {\"do\"} line was dropped and nothing happened)")
	check(lines.size() > 2 and str(lines[-2]).contains("Glowcap seeds"), "with all four spores, his talk hands them in and he says thank you")
	check(int(farm.seeds.get("glowcap", 0)) == caves.GIVE_SEEDS, "...and gives you %d Glowcap seeds" % caves.GIVE_SEEDS)
	check(root.get_node("Quests").is_done("undergardens"), "...and the quest is done")
	check(game.sparkles > sparkles_before, "...with its sparkles")
	check(caves.hand_in().is_empty() and int(farm.seeds.get("glowcap", 0)) == caves.GIVE_SEEDS, "...only once")

	# Coming back: everything remembered
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(6)
	ug = current_scene.get_node_or_null("Undergardens") as Node3D
	var tap := ug.get_node("The Old Taproot/Face")
	check(tap.get_node("Eyes").visible and ug.find_child("Spore ug_*", true, false) == null,
		"next visit he's still awake and the spores stay found")

	# Bramble
	var conv: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/bramble.json")).conversations
	var tells := conv.filter(func(c: Dictionary) -> bool: return str(c.get("set", "")) == "undergardens_start")
	check(tells.size() == 1 and str(tells[0].when.get("mended", "")) == "lanternmoor", "Bramble tells you about the caves once Lanternmoor's mended")

	# Glowcaps in the garden
	check(farm.CROPS.has("glowcap") and farm.ORDER.has("glowcap"), "Glowcap is a crop")
	var look: Node3D = farm.bed_look(5, "glowcap", false)
	check(look.find_children("*", "OmniLight3D", true, false).size() >= 2, "...and a ripe one glows")
	look.free()
	var shop_items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://shop/items.json")).items
	check(shop_items.any(func(it: Dictionary) -> bool: return str(it.get("crop", "")) == "glowcap" and str(it.kind) == "crop_sell"),
		"the Fruit stall buys Glowcaps")
	check(not shop_items.any(func(it: Dictionary) -> bool: return str(it.get("crop", "")) == "glowcap" and str(it.kind) == "seed"),
		"...and no stall sells their seeds (only the Old Taproot has them)")

	# How long building the cave takes (it's done every time the Void loads)
	var t0 := Time.get_ticks_usec()
	var tmp := Node3D.new()
	current_scene.add_child(tmp)
	KIT.build(tmp, caves.SHAPES, {"cell": 0.75, "top": caves.TOP, "seed": 12})
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	tmp.queue_free()
	check(ms < 1500.0, "building the cave takes %.0f ms" % ms)
	_finish()


func _put(p: CharacterBody3D, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO


func _ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	var player := get_first_node_in_group("player") as CollisionObject3D
	if player:
		q.exclude = [player.get_rid()]
	return (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)


func _terrain_height(at: Vector2) -> float:
	# The hill's own ground over a spot (the first thing a ray from high up hits that isn't the cave or its pieces)
	var from := Vector3(at.x, 80.0, at.y)
	var ex: Array[RID] = []
	var player := get_first_node_in_group("player") as CollisionObject3D
	if player:
		ex.append(player.get_rid())
	for n in 6:
		var q := PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -60.0, at.y))
		q.exclude = ex
		var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return -99.0
		var c := hit.collider as Node
		var path := str(c.get_path())
		if path.contains("Terrain") or path.contains("Ground"):
			return (hit.position as Vector3).y
		ex.append(hit.rid)
	return -99.0


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
