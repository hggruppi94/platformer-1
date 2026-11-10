extends SceneTree

# Checks the secrets at the bottom of deep water (scripts/sunken_secrets.gd): 24 of them, three kinds, one of each
# in every place with deep water. Each deep pool put in at play time is sunk into flat, clear ground (in the Void, off
# the races, paths, trees, portals and the plaza's friends): the ground over it is cut away (scripts/ground_hole.gd),
# paving round it is level with the ground, you can walk straight in, and its water is deep enough to swim in; every
# secret lies under at least 2 m of water; the Tide Reef's only turn up once its sea is in; you can only reach one by
# swimming down (floating on the top before Otto's taught you isn't enough); finding one reads it out and counts it
# once; you can climb back out of a pool; a whole set of watches or bottles pays out once; and Dash
# takes the pieces and, with all eight, works out what cracked the Shift.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_sunken_secrets.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.sunken_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.sunken_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var portals: Node
var dialogue: Node
var sunken: Node


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
	sunken = root.get_node("Watches/Sunken")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	var fn := root.get_node("FirstNight")
	root.get_node("Quests").state[fn.ID] = {"step": 0, "done": true, "since_day": 1}

	check(sunken.SECRETS.size() == 24, "24 secrets (%d)" % sunken.SECRETS.size())
	var places: Array = sunken.POOLS.keys() + sunken.NATURAL.keys()
	var all_ok := true
	for kind in sunken.KINDS:
		check(sunken.of_kind(kind).size() == 8, "eight %s" % sunken.KINDS[kind].set)
		for p in places:
			var here: Array = sunken.SECRETS.filter(func(s: Dictionary) -> bool: return s.kind == kind and s.place == p)
			all_ok = all_ok and here.size() == 1
	check(all_ok, "...one of each kind in each of the %d places with deep water" % places.size())
	var ids := {}
	for s in sunken.SECRETS:
		ids[s.id] = true
	check(ids.size() == 24, "...each with its own id")

	# Every world with all its friends in the Void (the plaza, Flurry, Otto, Melody's stage), so the pool's checked
	# against all of them
	for id in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef"]:
		portals.cleared_worlds.append(id)
		portals.note_found(id, "swim_taught")

	# The deep pools
	for key in sunken.POOLS:
		var p: Dictionary = sunken.POOLS[key]
		change_scene_to_file(p.scene)
		await _frames(14)
		await _physics(6)
		await _check_pool(key, p)

	# The town's pool: swimming down to its secrets
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(6)
	await _check_swimming()

	# Willow Pond and the Tide Reef
	for key in sunken.NATURAL:
		change_scene_to_file(sunken.NATURAL[key].scene)
		await _frames(14)
		await _physics(10)
		await _frames(4)
		var holder := current_scene.find_child("Sunken Secrets", true, false)
		var n := 0
		var deep := true
		for s in sunken.SECRETS:
			if s.place != key:
				continue
			var pick := holder.get_node_or_null("Secret " + str(s.id)) as Node3D if holder else null
			if pick:
				n += 1
				var w: Node = sunken.SWIM.water_at(self, pick.global_position)
				deep = deep and w != null and float(w.get("water_y")) - pick.global_position.y > 2.0
		check(n == 3 and deep, "%s: its three secrets lie under deep water (%d)" % [key, n])

	# ...the Tide Reef's only once its sea's in
	portals.cleared_worlds.erase("tide_reef")
	change_scene_to_file(sunken.NATURAL["tide_reef"].scene)
	await _frames(14)
	await _physics(10)
	var reef := current_scene.find_child("Sunken Secrets", true, false)
	check(reef != null and reef.get_child_count() == 1, "...and while the Tide Reef's tide is stuck out, they aren't there yet")
	portals.cleared_worlds.append("tide_reef")

	_check_sets()
	_check_dash()
	_finish()


func _check_pool(key: String, p: Dictionary) -> void:
	var pool := current_scene.find_child(str(p.name), true, false) as Node3D
	check(pool != null, "%s: %s is there" % [key, p.name])
	if pool == null:
		return
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var g: float = pool.get_meta("ground")
	var walls := pool.get_node("Walls") as StaticBody3D
	# Flat all round it (rays that skip the pool's own walls and paving)
	var flat := true
	var rim: float = pool.get_meta("rim")
	for k in 16:
		var a := k * TAU / 16.0
		for r in [rim + 0.4, rim + 1.0]:
			var from := pool.global_position + Vector3(cos(a) * r, 30.0, sin(a) * r)
			var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -60, 0))
			q.exclude = [walls.get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty() or absf((hit.position as Vector3).y - g) >= 0.8:      # (the paving follows a gentle slope)
				flat = false
	check(flat, "...on flat ground")
	# Sunk into it: the ground over the pool is gone, and the paving round it is level with the ground
	var bed: float = pool.get_meta("bed")
	var sunk := true
	var level := true
	for k in 8:
		var a := (k + 0.1) * TAU / 8.0          # (a little off the paving's seams: a ray straight down a seam can slip through)
		for r in [0.0, 1.0, 2.6]:
			var from := pool.global_position + Vector3(cos(a) * r, 6.0, sin(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -40, 0)))
			sunk = sunk and not hit.is_empty() and (hit.position as Vector3).y < g - 2.0
		for r in [sunken.POOL_R + sunken.POOL_WALL + 0.1, rim - 0.2]:
			var from := pool.global_position + Vector3(cos(a) * r, 6.0, sin(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -40, 0)))
			level = level and not hit.is_empty() and absf((hit.position as Vector3).y - g) < 0.2
	check(sunk, "...sunk into the ground: no ground left over it, the bottom %.1f m down" % (g - bed))
	check(level, "...with paving round it level with the ground (out to %.1f m)" % rim)
	# Nothing else in the way
	var cq := PhysicsShapeQueryParameters3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.4
	cyl.height = 5.0
	cq.shape = cyl
	cq.transform = Transform3D(Basis(), pool.global_position + Vector3(0, 2.9, 0))
	cq.collide_with_areas = true
	cq.exclude = [walls.get_rid()]
	var others := space.intersect_shape(cq, 8).filter(func(h: Dictionary) -> bool:
		return not (h.collider as Node).is_in_group("player"))
	check(others.is_empty(), "...with nothing else standing in it (%s)" % [others.map(func(h: Dictionary) -> String: return str(h.collider.name))])
	var at := Vector2(pool.global_position.x, pool.global_position.z)
	for n in current_scene.find_children("*", "Node3D", true, false):
		if str(n.name) in ["WayHome", "TimeStone"] or str(n.name).begins_with("Vein"):
			var d := Vector2(n.global_position.x, n.global_position.z).distance_to(at)
			check(d > 6.0, "...clear of the %s (%.1f m)" % [n.name, d])
	var trees := current_scene.find_child("Trees", true, false) as Node3D
	if trees and trees.get("positions") != null:
		var tree := INF
		for tp in trees.get("positions"):
			var gp: Vector3 = trees.global_transform * tp
			tree = minf(tree, Vector2(gp.x, gp.z).distance_to(at))
		check(tree > 6.0, "...with no tree growing through it (%.1f m)" % tree)
	check(absf(float(pool.get_node("Water").get("water_y")) - (g - sunken.SURFACE_DROP)) < 0.01,
		"...its water's surface just under the ground")
	var water := pool.get_node("Water")
	check(float(water.get("water_y")) - bed >= 3.0, "...water deep enough to swim down in (%.1f m)" % (float(water.get("water_y")) - bed))
	var holder := current_scene.find_child("Sunken Secrets", true, false)
	var n := 0
	for s in sunken.SECRETS:
		if s.place == key and holder.get_node_or_null("Secret " + str(s.id)):
			var pick := holder.get_node("Secret " + str(s.id)) as Node3D
			var flat_d := Vector2(pick.global_position.x, pick.global_position.z).distance_to(at)
			if flat_d < sunken.POOL_R - 0.5 and pick.global_position.y < bed + 0.6:
				n += 1
	check(n == 3, "...and its three secrets on the bottom (%d)" % n)
	if key == "town":
		_check_town_spot(at)
	await _check_walk_in(pool)


func _check_walk_in(pool: Node3D) -> void:
	# Walk up to it across the paving and straight in: she drops in with a splash and swims
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	var g: float = pool.get_meta("ground")
	var out := Vector3(1, 0, 0)
	player.global_position = pool.global_position + out * (sunken.POOL_R + sunken.POOL_WALL + 1.2) + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	var stood := false
	for i in 30:
		await physics_frame
		stood = stood or (player.is_on_floor() and absf(player.global_position.y - g) < 1.2)
	var t := 0
	while t < 240 and not player.call("is_swimming"):
		if player.is_on_floor():
			player.global_position -= out * 0.05          # (walking in: 3 m/s towards the middle)
		await physics_frame
		t += 1
	check(stood and player.call("is_swimming"), "...and you can walk straight in off the paving and swim")
	player.global_position = pool.global_position + out * 12.0 + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	await _physics(10)


func _check_town_spot(at: Vector2) -> void:
	var nearest := INF
	var tracks: Dictionary = root.get_node("Races").TRACKS
	for id in tracks:
		var t: Dictionary = tracks[id]
		if t.get("sky", false) or str(t.get("scene", TOWN)) != TOWN:
			continue
		var line: Array = t.points
		for i in line.size():
			var a: Vector2 = line[i]
			var b: Vector2 = line[(i + 1) % line.size()]
			var k := clampf((at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			nearest = minf(nearest, at.distance_to(a.lerp(b, k)))
	check(nearest > 10.0, "...well off the race tracks (%.1f m)" % nearest)
	var places: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://routines/places.json"))
	var path := INF
	for l in places.links:
		var pa: Array = places.points[l[0]]
		var pb: Array = places.points[l[1]]
		var a := Vector2(pa[0], pa[pa.size() - 1])
		var b := Vector2(pb[0], pb[pb.size() - 1])
		var k := 0.0 if a == b else clampf((at - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		path = minf(path, at.distance_to(a.lerp(b, k)))
	check(path > 8.0, "...off the townsfolk's paths (%.1f m)" % path)
	var apart := INF
	for o in portals.WORLDS:
		apart = minf(apart, at.distance_to(o.at))
	check(apart > 12.0, "...clear of every portal (%.1f m)" % apart)
	for who in ["Otto", "Flurry", "Portal Plaza"]:
		var n := current_scene.find_child(who, true, false) as Node3D
		if n:
			var d := Vector2(n.global_position.x, n.global_position.z).distance_to(at)
			check(d > 9.0, "...and not on %s (%.1f m)" % [who, d])


func _check_swimming() -> void:
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var pool := current_scene.find_child("The Wishing Well", true, false) as Node3D
	var holder := current_scene.find_child("Sunken Secrets", true, false)
	var s: Dictionary = sunken.secret("old_first")
	var pick := holder.get_node("Secret old_first") as Node3D
	var top: float = float(pool.get_node("Water").get("water_y"))
	var swim: Node = player.get("swim")
	# Before Otto's taught you: you float on top, and it's too far down to reach
	portals.cleared_worlds.erase("tide_reef")
	player.global_position = Vector3(pick.global_position.x, top - 0.5, pick.global_position.z)
	player.velocity = Vector3.ZERO
	Input.action_press("dash")
	await _physics(150)
	Input.action_release("dash")
	check(player.call("is_swimming") and not sunken.is_found("old_first"), "before you can swim, you float on top and can't reach the bottom")
	# After: dive down to it
	portals.cleared_worlds.append("tide_reef")
	Input.action_press("dash")
	var t := 0
	while not sunken.is_found("old_first") and t < 300:
		await physics_frame
		t += 1
	Input.action_release("dash")
	check(sunken.is_found("old_first") and not holder.has_node("Secret old_first"), "dive down and it's yours: %s" % s.name)
	await _frames(2)
	check(dialogue.is_active(), "...and it's read out")
	dialogue.end()
	var again: Array = sunken.lines_for(s)
	check(sunken.found_of("watch") == 1 and " ".join(again).contains("1 of 8"), "...counted once: 1 of 8")
	# Out again over the side: swim onto the ledge inside by the steps, stand up and jump out over the wall
	var mid := Vector3(pool.global_position.x, 0, pool.global_position.z)
	var la: float = sunken.LEDGE_AT
	var ledge: Vector3 = mid + Vector3(cos(la), 0, sin(la)) * (sunken.POOL_R - 0.6)
	var g: float = pool.get_meta("ground")
	player.global_position = mid + Vector3(0, top - 0.5, 0)
	player.velocity = Vector3.ZERO
	await _physics(10)
	player.global_position = Vector3(ledge.x, top - sunken.LEDGE + 1.0, ledge.z)
	player.velocity = Vector3.ZERO
	await _physics(40)
	check(not player.call("is_swimming") and player.is_on_floor(), "swim onto the ledge inside and you can stand up on it")
	var away := Vector3(ledge.x - mid.x, 0, ledge.z - mid.z).normalized()
	t = 0
	var r_out: float = sunken.POOL_R + sunken.POOL_WALL
	while t < 120 and Vector2(player.global_position.x - mid.x, player.global_position.z - mid.z).length() < r_out + 0.3:
		if t == 0 or t == 18:
			Input.action_press("jump")
		elif t == 6 or t == 24:
			Input.action_release("jump")
		player.velocity.x = away.x * 4.0
		player.velocity.z = away.z * 4.0
		await physics_frame
		t += 1
	Input.action_release("jump")
	await _physics(60)
	var out := Vector2(player.global_position.x - mid.x, player.global_position.z - mid.z).length()
	check(not player.call("is_swimming") and out > r_out and player.is_on_floor() and absf(player.global_position.y - g) < 1.0,
		"...and jump out onto the paving (%.1f m out)" % out)


func _check_sets() -> void:
	var before: int = root.get_node("Remnants").count
	for s in sunken.of_kind("watch"):
		dialogue.set_flag("sunk_" + str(s.id))
	dialogue.flags.erase("sunk_old_metronome")
	sunken.pick_up("old_metronome")
	if dialogue.is_active():
		dialogue.end()
	check(root.get_node("Remnants").count == before + sunken.WATCH_REWARD, "all eight watches of the first chosen: %d Remnants" % sunken.WATCH_REWARD)
	sunken.pick_up("old_metronome")
	check(root.get_node("Remnants").count == before + sunken.WATCH_REWARD, "...only once")
	for s in sunken.of_kind("bottle"):
		dialogue.set_flag("sunk_" + str(s.id))
	var lines: Array = sunken.lines_for(sunken.secret("seer_watch"))
	check(" ".join(lines).contains("See you then"), "all eight of the seer's bottles: a last note from the seer")


func _check_dash() -> void:
	var w := root.get_node("Watches")
	check(w.condition_ok({"sunk_to_give": false}), "no pieces yet: Dash doesn't ask")
	dialogue.set_flag("sunk_piece_ball")
	check(w.condition_ok({"sunk_to_give": true}) and not w.condition_ok({"sunk_to_give": false}), "a piece found: Dash wants to see it")
	var first: Array = sunken.hand_in()
	check(sunken.given_count() == 1 and " ".join(first).contains("1 of 8"), "he takes it (1 of 8)")
	var rem: int = root.get_node("Remnants").count
	var sp: int = game.sparkles
	for s in sunken.of_kind("piece"):
		dialogue.set_flag("sunk_" + str(s.id))
	var last: Array = sunken.hand_in()
	check(sunken.given_count() == 8 and " ".join(last).contains("cracked the Shift"), "with all eight, Dash works out what cracked the Shift")
	check(root.get_node("Remnants").count == rem + int(sunken.PIECE_REWARD.remnants) and game.sparkles == sp + int(sunken.PIECE_REWARD.sparkles),
		"...and gives you %d Remnants and %d sparkles" % [sunken.PIECE_REWARD.remnants, sunken.PIECE_REWARD.sparkles])
	check(sunken.hand_in().is_empty() and not w.condition_ok({"sunk_to_give": true}), "...once")
	var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/dash.json"))
	var asks: Array = (file.conversations as Array).filter(func(c: Dictionary) -> bool: return str(c.get("do", "")) == "Watches/Sunken.hand_in")
	check(asks.size() == 2, "Dash's lines for it are in his dialogue")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	for a in ["jump", "dash"]:
		Input.action_release(a)
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
