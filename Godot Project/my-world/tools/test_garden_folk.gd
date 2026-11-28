extends SceneTree

# Checks the Tuftlings, the Secret Garden's little folk (scripts/garden_folk.gd, 28 Nov 2026): Tuftling Hollow's eight
# burrows stand round the Great Tree on the ground, apart, clear of the Treetop Walk, facing the tree and solid; the
# eight named folk (four boys, four girls) and the crowd are in, small, on their feet, with baked detail, fangs and
# claws; they wander (never into the water or off their patch) and wave at you; far ones rest. Every quest's spots
# are on open ground in the garden, and each of the eight quests really plays through: talk to them, use the spots
# they send you to (Tumble hides away and turns up at each), take it back, sparkles paid once.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_garden_folk.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.garden_folk_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.garden_folk_backup.cfg"
const SG := "res://scenes/secret_garden/secret_garden.tscn"
const LAND := preload("res://scripts/secret_garden_land.gd")
const QUESTS := {"folk_fennick": 4, "folk_thistle": 3, "folk_moss": 1, "folk_bluebell": 0, "folk_bracken": 1,
	"folk_clem": 3, "folk_tumble": 3, "folk_rosehip": 4}

var failures := 0
var game: Node
var dialogue: Node
var quests: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	for f in dialogue.flags.keys():
		if str(f).begins_with("folk_"):
			dialogue.flags.erase(f)

	change_scene_to_file(SG)
	await _frames(8)
	var sg := current_scene as Node3D
	var folk: Node3D = null
	for i in 600:
		await physics_frame
		folk = sg.get_node_or_null("Tuftlings") as Node3D
		if folk and folk.ready_done:
			break
	check(folk != null and folk.ready_done, "the Tuftlings move into the Secret Garden")
	if folk == null or not folk.ready_done:
		_finish()
		return
	var p := sg.find_child("Player", true, false) as CharacterBody3D

	# --- Tuftling Hollow ---
	var homes: Dictionary = folk.homes
	check(homes.size() == 8, "eight burrows in Tuftling Hollow (%d)" % homes.size())
	var gt: Vector2 = load("res://scripts/secret_garden_groves.gd").GREAT_TREE
	var tree := Vector2(gt.x, gt.y)
	var ok_ground := true
	var ok_apart := true
	var ok_walk := true
	var ok_face := true
	var ok_near := true
	var ok_solid := true
	var space := sg.get_world_3d().direct_space_state
	for id in homes:
		var h: Dictionary = homes[id]
		var at: Vector3 = h.at
		var a2 := Vector2(at.x, at.z)
		if absf(at.y - LAND.height(at.x, at.z)) > 0.3:
			ok_ground = false
			print("  %s's burrow floats or sinks: %.2f vs %.2f" % [id, at.y, LAND.height(at.x, at.z)])
		for id2 in homes:
			if id2 != id and a2.distance_to(Vector2(homes[id2].at.x, homes[id2].at.z)) < 5.0:
				ok_apart = false
		if folk._walk_dist(a2) < 3.5:
			ok_walk = false
		var to := (tree - a2).normalized()
		var fwd := Vector2(sin(h.face), cos(h.face))
		if to.dot(fwd) < 0.95:
			ok_face = false
		if a2.distance_to(tree) > 21.0:
			ok_near = false
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(sin(h.face), 0, cos(h.face)) * 3.0 + Vector3.UP * 0.5,
			at + Vector3.UP * 0.5)
		var skip: Array[RID] = []
		for w in folk.folk.values() + folk.crowd:
			skip.append((w as CollisionObject3D).get_rid())
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty() or hit.collider != h.node:
			ok_solid = false
			print("  in front of %s the ray hit %s" % [h.node.name, "nothing" if hit.is_empty() else str(hit.collider.name)])
	check(ok_ground, "every burrow sits on the ground")
	check(ok_apart, "...at least 5 m apart")
	check(ok_walk, "...clear of the Treetop Walk")
	check(ok_face, "...each door looking at the Great Tree")
	check(ok_near, "...all round the Great Tree's glade")
	check(ok_solid, "...and solid: you can't walk into one")
	var model := (homes.values()[0].node as Node3D).get_node("Model")
	check(model.find_children("*", "MeshInstance3D", true, false).size() > 0 and _has_detail(model),
		"the burrows are the baked model (normal map, AO)")
	check(_on_map("Tuftling Hollow"), "Tuftling Hollow is on the map")

	# --- The folk ---
	var named: Dictionary = folk.folk
	check(named.size() == 8, "eight named Tuftlings (%d)" % named.size())
	var girls := 0
	for id in folk.FOLK:
		girls += 1 if folk.FOLK[id].girl else 0
	check(girls == 4, "four girls and four boys")
	check(folk.crowd.size() >= 10, "and %d more about the garden" % folk.crowd.size())
	await _physics(90)
	var all: Array = named.values() + folk.crowd
	var on_feet := 0
	var small := true
	var detailed := true
	var fangs := true
	for w in all:
		if (w as CharacterBody3D).is_on_floor() or (w as Node3D).get("resting"):
			on_feet += 1
		var m := (w as Node3D).get_node("Model") as Node3D
		var aabb := _height(m)
		if aabb < 0.5 or aabb > 0.95:
			small = false
			print("  %s is %.2f m tall" % [w.name, aabb])
		if not _has_detail(m):
			detailed = false
		if not _has_mat(m, "Claw"):
			fangs = false
	check(on_feet == all.size(), "they're all on their feet (%d of %d)" % [on_feet, all.size()])
	check(small, "they're small, like the little aliens (0.5 to 0.95 m)")
	check(detailed, "every one wears baked detail")
	check(fangs, "...with fangs and claws")
	check(named.fennick.get_node("Talk").get("character_id") == "folk_fennick", "you can talk to them")
	var recoloured := 0
	for w in folk.crowd:
		for mi in (w as Node3D).find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				if (mi as MeshInstance3D).get_surface_override_material(i) != null:
					recoloured += 1
					break
	check(recoloured >= folk.crowd.size(), "the crowd wear other colours from the named folk")

	# They wander about (near the player, so they're awake), never into water and not far from home
	var f: CharacterBody3D = named.fennick
	p.global_position = f.global_position + Vector3(6, 1, 0)
	var start := {}
	for w in named.values():
		start[w] = (w as Node3D).global_position
	for i in 60 * 20:
		await physics_frame
		for w in named.values():
			if not start.has(w):
				continue
	var moved := 0
	var wet := false
	var strays := false
	for w in named.values():
		var wp := (w as Node3D).global_position
		if wp.distance_to(start[w]) > 0.5:
			moved += 1
		if LAND.in_lake(wp.x, wp.z) != "":
			wet = true
		if Vector2(wp.x - w._home.x, wp.z - w._home.z).length() > w.wander_radius + 1.5:
			strays = true
	check(moved >= 3, "they wander about their homes (%d of 8 moved)" % moved)
	check(not wet, "...never into the water")
	check(not strays, "...and stay near home")
	# Waves when you come close
	p.global_position = f.global_position + Vector3(1.6, 0.9, 0)
	p.velocity = Vector3.ZERO
	f.set("_cooldown", 0.0)
	var waved := false
	for i in 120:
		await physics_frame
		var ap := f.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.current_animation == "wave":
			waved = true
			break
	check(waved, "...and wave when you come close")
	# Far ones rest
	await _frames(40)
	var far: Node3D = folk.crowd[0]
	check(far.global_position.distance_to(p.global_position) < 70.0 or (far.get("resting") and not far.visible),
		"far-off Tuftlings rest and aren't drawn")

	# --- The quests' spots ---
	var spots: Array = folk.spots
	var want := 0
	for q in QUESTS.values():
		want += q
	check(spots.size() == want, "every quest spot found room (%d of %d)" % [spots.size(), want])
	var spots_ok := true
	for s in spots:
		var sp := (s as Node3D).global_position
		if LAND.in_lake(sp.x, sp.z) != "" or absf(sp.x) > LAND.X_HALF or sp.z < 0 or sp.z > LAND.Z_MAX:
			spots_ok = false
			print("  %s is out of reach at %s" % [s.name, sp])
	check(spots_ok, "...all inside the garden, out of the water")
	for id in QUESTS:
		check(not quests.quest(id).is_empty(), "the quest %s is there" % id)

	# --- Every quest played through ---
	var sparkles_before: int = game.sparkles
	for id in QUESTS:
		var who := str(id).trim_prefix("folk_")
		var t: Node3D = named[who]
		await _talk(t)
		check(not quests.current_step(id).is_empty(), "%s gives you a quest" % t.name)
		if id == "folk_tumble":
			await _frames(40)
			check(not t.visible, "...and Tumble runs off to hide")
		if id == "folk_bluebell":
			await _talk(named.fennick)
		var guard := 10
		while not quests.is_done(id) and guard > 0:
			guard -= 1
			var step := str(quests.current_step(id).get("id", ""))
			var used := false
			for s in spots:
				if s.get("quest") == id and s.get("step") == step and s.call("is_open"):
					p.global_position = (s as Node3D).global_position + Vector3(0, 0.9, 0)
					p.velocity = Vector3.ZERO
					await _physics(3)
					var before := s.get_node_or_null("Before") as Node3D
					if before and not before.visible:
						await _frames(2)
					s.call("use")
					used = true
					await _frames(2)
			if not used:
				await _talk(t)
		check(quests.is_done(id), "...%s's quest done" % t.name)
		if id == "folk_tumble":
			await create_timer(0.8).timeout
			check(not t.get("hidden_away") and not folk.call("tumble_hiding"), "...and Tumble's back home")
	check(game.sparkles - sparkles_before == 78, "they paid %d sparkles in all (want 78)" % (game.sparkles - sparkles_before))
	var again: int = game.sparkles
	await _talk(named.fennick)
	check(game.sparkles == again, "...and only once")
	_finish()


func _talk(t: Node3D) -> void:
	var talk := t.get_node("Talk")
	dialogue.talk_to(talk)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		_press("interact")
		await _frames(1)
		_press("interact")
		await _frames(2)
	await _frames(4)


func _height(m: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	return hi - lo


func _has_detail(m: Node) -> bool:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat and mat.normal_enabled and mat.normal_texture != null:
				return true
	return false


func _has_mat(m: Node, nm: String) -> bool:
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat and mat.resource_name == nm:
				return true
	return false


func _on_map(label: String) -> bool:
	for n in get_nodes_in_group("map_landmarks"):
		if n.has_method("map_name") and n.map_name() == label:
			return true
	return false


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
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
