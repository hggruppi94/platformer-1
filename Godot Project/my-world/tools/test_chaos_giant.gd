extends SceneTree

# Checks the Agent of Chaos (scripts/chaos_giant.gd, models/characters/chaos_giant.glb): he's in town, giant-sized,
# out at the northeast edge well away from the castle, the skate park, the Observatory, the spawn and the town's
# invisible edge walls; he stomps along his patrol with his walk, stands on the ground, broods and lets the chaos
# out; he's solid; he only shows off at the player when they come near (he never goes after them); and the map
# names him.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_chaos_giant.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const GiantScript := preload("res://scripts/chaos_giant.gd")

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
	var g := town.find_child("ChaosGiant", true, false) as Node3D
	check(g != null, "the Agent of Chaos is in town")
	if g == null:
		_end()
		return
	check(g.call("map_name") == GiantScript.NAME and GiantScript.NAME != "", "he's called \"%s\"" % GiantScript.NAME)
	var anim := g.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(anim != null and anim.has_animation("idle") and anim.has_animation("walk") and anim.has_animation("chaos"),
		"his model has idle, walk and chaos")

	# Giant-sized: about seven kids tall.
	var box := AABB()
	var first := true
	for m in g.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	check(box.size.y > 9.0 and box.size.y < 14.0, "he's a giant (%.1f m tall)" % box.size.y)

	# Out at the edge, clear of everything the player needs.
	var a: Vector3 = g.patrol_a
	var b: Vector3 = g.patrol_b
	var clear := {"the castle hill": [Vector2(15, -150), 70.0], "the Observatory": [Vector2(105, -88), 45.0],
		"the skate park": [Vector2(50, 58), 60.0], "the spawn": [Vector2(-72, 80), 60.0],
		"the Mothership Pad": [Vector2(118, -42), 40.0], "the Haunted House": [Vector2(-112, -128), 40.0]}
	for what in clear:
		var gap := INF
		for i in 11:
			var q := a.lerp(b, i / 10.0)
			gap = minf(gap, Vector2(q.x, q.z).distance_to(clear[what][0]))
		check(gap > clear[what][1], "his patrol keeps clear of %s (%.0f m)" % [what, gap])
	var inside := true
	for q in [a, b]:
		inside = inside and q.x > -140 and q.x < 140 and q.z > -250 and q.z < 104
	check(inside, "his patrol is inside the town's edge walls")

	var body := g.get_node_or_null("Body") as CollisionObject3D
	check(body != null and body.find_child("*", false) is CollisionShape3D, "he's solid (you can't walk through his legs)")

	# He walks his patrol, on the ground. Keep the player far away so he doesn't stop for them.
	p.global_position = Vector3(-72, 2, 80)
	g.set("_cooldown", 0.0)
	g.call("_walk")
	var start := g.global_position
	await _physics(240)
	var moved := Vector2(g.global_position.x - start.x, g.global_position.z - start.z).length()
	check(moved > 2.0, "he stomps along (%.1f m in 4 s)" % moved)
	check(anim.current_animation in ["walk", "idle", "chaos"], "playing his %s" % anim.current_animation)
	check(absf(g.global_position.y) < 1.5, "he stands on the ground (y %.2f)" % g.global_position.y)
	var off := _off_path(g.global_position, a, b)
	check(off < 3.0, "he keeps to his patrol (%.1f m off it)" % off)

	# Over a minute he's mostly on the move: short broods at the ends, the odd outburst, never stuck standing.
	var walking := 0
	var longest_still := 0
	var still := 0
	for i in 3600:
		await physics_frame
		if g.get("_state") == GiantScript.State.WALK and anim.current_animation == "walk":
			walking += 1
			still = 0
		else:
			still += 1
			longest_still = maxi(longest_still, still)
	check(walking > 3600 * 0.6, "he's walking %d%% of a minute" % (walking * 100 / 3600))
	check(longest_still < 60 * 12, "he never stands still for long (longest %.1f s)" % (longest_still / 60.0))

	# Ends of the walk: he broods or lets the chaos out, then sets off back the other way.
	g.global_position = Vector3(b.x, g.global_position.y, b.z)
	g.set("_to_b", true)
	g.call("_walk")
	await _physics(10)
	check(g.get("_state") != GiantScript.State.WALK or not g.get("_to_b"), "at the end of his walk he turns back")

	# The player comes near: he stops and shows off, but never goes after them, and nothing hurts them.
	g.call("_walk")
	g.set("_cooldown", 0.0)
	var here := g.global_position
	p.global_position = here + Vector3(0, 1, 15)
	p.velocity = Vector3.ZERO
	await _physics(20)
	check(g.get("_state") == GiantScript.State.CHAOS and anim.current_animation == "chaos",
		"he lets the chaos out when the player comes near")
	var before := g.global_position
	await _physics(90)
	check(g.global_position.distance_to(before) < 0.3, "he stays put while showing off (he doesn't chase)")
	check(is_instance_valid(p) and p.is_inside_tree(), "the player is fine")
	_end()


func _off_path(q: Vector3, a: Vector3, b: Vector3) -> float:
	var p2 := Vector2(q.x, q.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var t := clampf((p2 - a2).dot(b2 - a2) / (b2 - a2).length_squared(), 0.0, 1.0)
	return p2.distance_to(a2.lerp(b2, t))


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
