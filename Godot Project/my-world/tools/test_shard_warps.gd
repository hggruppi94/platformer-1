extends SceneTree

# Checks Shard Isle's Warp Rings (scripts/shard_warps.gd): the six new islands are there, each well clear of the
# builder's own islands and of each other, with solid ground under every landing and every ring on its island; the
# main island's Warp Circle is on open ground; a wrong ring takes you to a lookout, dims, and the lookout's ring
# takes you back where you came from; the right rings in turn take you to Skyhook Isle, Underside Isle and Prism
# Isle; the white rings go home; the Prism Chest pays once (not on a practice trip); the right rings wear a star once
# Prism Isle's found; the new islands get the baked rock; and you can stand on each island (really dropped onto it).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_shard_warps.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.shard_warps_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.shard_warps_test_backup.cfg"

var failures := 0
var game: Node
var portals: Node
var p: CharacterBody3D
var world: Node3D
var warps: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _load() -> void:
	change_scene_to_file(str(portals.world("shard_isle").scene))
	await _frames(10)
	await _physics(20)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	warps = world.get_node_or_null("Warps")


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at + Vector3(0, -4, 0))
	q.exclude = [p.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3.INF


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals.home_calls.enabled = false
	portals.practice = false
	await _load()
	check(warps != null, "Shard Isle has its Warp Rings")
	if warps == null:
		_finish()
		return
	var W: Dictionary = warps.ISLANDS
	var builder := {"Main Island": [Vector3.ZERO, 14.0], "Islet Echo1": [Vector3(25, 2, -6), 5.0],
		"Islet Echo2": [Vector3(-5, 4, -27), 5.0], "Islet Echo3": [Vector3(-24, 1.2, 9), 5.0],
		"Lonely Shard": [Vector3(18, 4.5, 18), 3.0]}
	var made := 0
	for id: String in W:
		if id == "main":
			continue
		var g := world.find_child("Islet Warp *", false, false)
		var at: Vector3 = W[id].at
		var r := float(W[id].r)
		for k in world.get_children():
			if str(k.name).begins_with("Islet Warp") and (k as Node3D).position.is_equal_approx(at):
				made += 1
		var clear := true
		for n: String in builder:
			var b: Array = builder[n]
			var gap := Vector2(at.x - b[0].x, at.z - b[0].z).length() - r - float(b[1])
			if gap < 4.0 and absf(at.y - float(b[0].y)) < 14.0:
				clear = false
				print("  ", id, " too close to ", n)
		for o: String in W:
			if o == id or o == "main":
				continue
			var ob: Vector3 = W[o].at
			if at.distance_to(ob) < r + float(W[o].r) + 8.0:
				clear = false
				print("  ", id, " too close to ", o)
		check(clear, "%s is well clear of every other island" % id)
		check(_ground(warps.landing(id)) != Vector3.INF, "%s: solid ground where you land" % id)
	check(made == 6, "six new islands built (%d)" % made)
	# Every ring stands on its island, on ground
	var on_ground := true
	for key: String in warps._rings:
		var g := warps._rings[key] as Node3D
		var hit := _ground(g.global_position + Vector3(0, 0.5, 0))
		if hit == Vector3.INF or absf(hit.y - g.global_position.y) > 0.5:
			on_ground = false
			print("  ring off its ground: ", key)
	check(on_ground, "every ring stands on its island (%d rings)" % warps._rings.size())
	# The main circle's on open ground: nothing solid from the builder within its reach
	var space := world.get_world_3d().direct_space_state
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.4
	sq.shape = sph
	sq.transform = Transform3D(Basis(), Vector3(-5, 1.5, -5.5))
	sq.exclude = [p.get_rid()]
	var blockers := []
	for h in space.intersect_shape(sq, 32):
		var c := h.collider as Node
		if not str(c.get_parent().name).begins_with("Warp Ring") and not str(c.get_parent().name).begins_with("Main Island"):
			blockers.append(str(c.get_path()))
	check(blockers.is_empty(), "the main Warp Circle is on open ground %s" % str(blockers))
	# The new islands wear the baked rock
	await _frames(3)
	var dressed := 0
	for k in world.get_children():
		if str(k.name).begins_with("Islet Warp") and k.has_node("Detailed Island Rock"):
			dressed += 1
	check(dressed == 6, "the new islands have the baked rock (%d)" % dressed)

	# --- The dream sky: its sky, far islands, monoliths and jellies, nothing solid, clear of everything ---
	var sky := world.get_node_or_null("Dream Sky")
	check(sky != null, "Shard Isle has its dream sky")
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var smat := we.environment.sky.sky_material as ShaderMaterial if we and we.environment and we.environment.sky else null
	check(smat != null and smat.shader != null and smat.shader.resource_path.ends_with("dream_sky.gdshader"), "the sky is the dream sky")
	check(sky.islands.size() == 9 and sky.monoliths.size() == 4 and sky.jellies.size() == 7, "9 Dream Islands, 4 monoliths, 7 jellies")
	var near_far := INF
	for g: Node3D in sky.islands:
		near_far = minf(near_far, Vector2(g.global_position.x, g.global_position.z).length())
	check(near_far > 240.0, "the Dream Islands are far off (nearest %.0f m)" % near_far)
	var jelly_gap := INF
	for g: Node3D in sky.jellies:
		for t in [0.0, 120.0, 400.0, 900.0]:
			var at: Vector3 = sky.jelly_at(g, t)
			for id: String in warps.ISLANDS:
				jelly_gap = minf(jelly_gap, at.distance_to(warps.top(id)))
			jelly_gap = minf(jelly_gap, at.length())
	check(jelly_gap > 25.0, "the sky jellies keep clear of every island (closest %.1f m)" % jelly_gap)
	check(sky.find_children("*", "CollisionObject3D", true, false).is_empty(), "nothing in the dream sky is solid")
	check(sky.motes != null and sky.motes.multimesh.instance_count == sky.MOTES, "the dream motes float about")
	var trips0: int = sky.trips

	# --- Wrong ring: a lookout, dimmed, and back ---
	var sparkles0: int = game.sparkles
	warps.warp("main", "green")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("overlook")) < 1.5, "the green ring takes you to Echo Overlook")
	check(sky.trips == trips0 + 1, "stepping through a ring sets off the dream swirl")
	check(warps.is_dim("main", "green"), "the green ring goes dim")
	warps.warp("overlook", "back")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("main")) < 1.5, "the lookout's ring takes you back to the Main Island")
	# --- The right way ---
	warps.warp("main", "pink")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("skyhook")) < 1.5, "the pink ring takes you to Skyhook Isle")
	check(not warps.is_dim("main", "pink"), "the right ring doesn't go dim")
	await _physics(30)
	check(p.global_position.distance_to(warps.landing("skyhook")) < 1.8 and p.is_on_floor(), "you stand on Skyhook Isle")
	warps.warp("skyhook", "gold")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("drift")) < 1.5, "a wrong ring from Skyhook goes to Drift Rock")
	warps.warp("drift", "back")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("skyhook")) < 1.5, "and back to Skyhook Isle")
	warps.warp("skyhook", "blue")
	await _physics(30)
	check(p.global_position.distance_to(warps.landing("underside")) < 1.8 and p.is_on_floor(), "the blue ring: you stand on Underside Isle")
	check(p.global_position.y > float(world.get("fall_below")) + 10.0, "Underside Isle is well above the fall catch")
	check(not portals.has_found("shard_isle", "warp_prism"), "Prism Isle's not found yet")
	warps.warp("underside", "gold")
	await _physics(30)
	check(p.global_position.distance_to(warps.landing("prism")) < 1.8 and p.is_on_floor(), "the gold ring: you stand on Prism Isle")
	check(portals.has_found("shard_isle", "warp_prism"), "Prism Isle's found")
	var star := warps.ring_at("main", "pink").get_node("Star") as Node3D
	check(star.visible, "the right ring at the main circle wears a star now")
	check(not (warps.ring_at("main", "blue").get_node("Star") as Node3D).visible, "a wrong ring has no star")
	# --- The chest ---
	var rem0: int = root.get_node("Remnants").count
	warps.open_chest()
	check(game.sparkles == sparkles0 + warps.CHEST_SPARKLES, "the Prism Chest pays %d sparkles" % warps.CHEST_SPARKLES)
	check(root.get_node("Remnants").count == rem0 + warps.CHEST_REMNANTS, "and %d Remnants" % warps.CHEST_REMNANTS)
	warps.open_chest()
	check(game.sparkles == sparkles0 + warps.CHEST_SPARKLES, "only once")
	warps.warp("prism", "white")
	await _physics(3)
	check(p.global_position.distance_to(warps.landing("main")) < 1.5, "the white ring takes you home to the Main Island")

	# --- Next visit: the star's still there, nothing dim ---
	await _load()
	check(warps.found_prism() and (warps.ring_at("main", "pink").get_node("Star") as Node3D).visible, "next visit the star's still there")
	check(not warps.is_dim("main", "green"), "and every ring's bright again")
	check(warps.chest_open(), "the chest stays open")

	# --- A practice trip pays nothing ---
	portals.found.erase("shard_isle")
	portals.practice = true
	await _load()
	var s1: int = game.sparkles
	warps.open_chest()
	check(game.sparkles == s1, "no sparkles from the chest on a practice trip")
	portals.practice = false
	print("RESULT ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if failures else 0)
