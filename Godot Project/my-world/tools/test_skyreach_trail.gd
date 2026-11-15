extends SceneTree

# Checks the Skyreach Trail and the Starhorn (scripts/skyreach_trail.gd, scripts/starhorn.gd, the cleft in
# scripts/bosses.gd): the cleft stands at the foot of the mountains with room to come out and nothing on the map; inside,
# you can really walk the whole trail from the bottom to the summit; it's the longest trail (300 m+); the cliffs are too
# steep to climb and wall crawl can't take them; the Waystones light as you pass and catch you if you fall; a faint
# starts you at the last one; the Starhorn sleeps until you're on the summit; its phases only go forwards, never get
# skipped by a burst, and each starts with a roar it can't be hit in; in phase 2 its shield is up until the three Star
# Shards are broken, which knocks it over; walking away puts it back to sleep with all its puff back; calming it gives
# the reward once and remembers it; and the way home lands you in front of the cleft.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skyreach_trail.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.skyreach_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.skyreach_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
# (loaded once the game's running: they use the autoloads, which a --script tool can't compile against up front)
var TRAIL: GDScript
var HORN: GDScript

var failures := 0
var game: Node
var bosses: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(500.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	bosses = root.get_node("Bosses")
	TRAIL = load("res://scripts/skyreach_trail.gd")
	HORN = load("res://scripts/starhorn.gd")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Dialogue").flags.erase("starhorn_calmed")

	# --- The cleft in town ---
	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	var gate := town.get_node_or_null("Skyreach Cleft/Cleft") as Node3D
	check(gate != null, "the cleft stands at the foot of the mountains")
	if gate == null:
		_finish()
		return
	check(gate.global_position.z < -240.0, "...far to the north (z %.0f)" % gate.global_position.z)
	var out: Dictionary = bosses.lair_out("skyreach")
	var outp: Vector3 = out.position
	var ground_out: Vector3 = bosses.ground(town, outp.x, outp.z)
	var space := town.get_world_3d().direct_space_state
	check(_clear(space, ground_out), "...with nothing solid where you come out in front of it")
	check(absf(ground_out.y - gate.global_position.y) < 1.0, "...and flat ground there")
	var sign := gate.get_node_or_null("Lair Sign") as Label3D
	check(sign != null and sign.visibility_range_end > 0.0 and sign.visibility_range_end <= 15.0,
		"...and its sign can only be read up close")
	var named := false
	for n in get_nodes_in_group("map_landmarks"):
		if n.has_method("map_name") and str(n.call("map_name")).contains("Skyreach"):
			named = true
	check(not named, "...and it isn't on the map")
	var spot := gate.get_node("Lair Spot")
	check(str(spot.offer.call()) == "go in to the Skyreach Trail", "it offers the way in")
	bosses.set_meta("lair_resume", 3)
	spot.act.call()
	await _frames(10)
	await _physics(6)
	var lair := current_scene as Node3D
	check(lair.scene_file_path == bosses.LAIRS["skyreach"].scene, "it takes you to the Skyreach Trail")
	var p := lair.find_child("Player", true, false) as CharacterBody3D
	check(p.global_position.z < 6.0 and p.global_position.y < 3.0, "...at the very bottom (a fresh trip starts there)")
	var boss := lair.get_node("The Starhorn") as CharacterBody3D
	check(boss.process_mode == Node.PROCESS_MODE_DISABLED and int(boss.get("state")) == HORN.State.SLEEP,
		"the Starhorn's asleep on top")
	check(TRAIL.trail_length() > 300.0, "it's a long trail (%.0f m)" % TRAIL.trail_length())

	# --- The cliffs: too steep, and no wall crawl ---
	var steep := true
	for body_name in ["Edge Mountain"]:
		var body := lair.get_node_or_null(body_name) as StaticBody3D
		check(body != null and str(body.name).begins_with("Edge"), "the cliffs are a body wall crawl leaves alone")
		var faces: PackedVector3Array = ((body.get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
		var flat := 0
		for i in range(0, faces.size(), 3):
			var nrm := (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).normalized()
			var area := (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).length()
			# (a walkable bit just under the top is all right: the summit's ring wall stops you there; so is the kerb-high
			# lip at the very bottom, where the trail leaves the meadow)
			var high := maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y))
			if area > 0.05 and absf(nrm.y) > cos(deg_to_rad(44.0)) and faces[i].y < TRAIL.TOP - 5.0 and high > 1.0:
				flat += 1
		steep = flat == 0
		check(steep, "...and too steep to walk up anywhere below the top (%d walkable bits)" % flat)

	# --- Really walking the whole trail ---
	for e in get_nodes_in_group("enemies"):
		if e != boss:
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
	await _physics(4)
	var a := 0.0
	var steps := 0
	var stuck := 0
	var last := p.global_position
	var lit_seen := 0
	var start: Vector3 = TRAIL.trail_point(0.0)
	while p.global_position.distance_to(start) > 3.0 and steps < 900:
		_steer(p, (start - p.global_position) * Vector3(1, 0, 1))
		await physics_frame
		steps += 1
	while a < TRAIL.TURNS - 0.02 and steps < 9000:
		var best := a
		var bd := INF
		for k in 30:
			var t := clampf(a - 0.05 + 0.01 * k, 0.0, TRAIL.TURNS)
			var d: float = p.global_position.distance_to(TRAIL.trail_point(t) + Vector3(0, 1, 0))
			if d < bd:
				bd = d
				best = t
		a = maxf(a, best)
		var target: Vector3 = TRAIL.trail_point(minf(a + 3.5 / TRAIL.trail_r(a), TRAIL.TURNS))
		_steer(p, (target - p.global_position) * Vector3(1, 0, 1))
		await physics_frame
		steps += 1
		if steps % 90 == 0:
			if p.global_position.distance_to(last) < 1.0:
				stuck += 1
			last = p.global_position
		lit_seen = maxi(lit_seen, int(lair.get("stone_at")))
	# ...then in onto the summit
	var top: Vector3 = TRAIL.summit()
	while Vector2(p.global_position.x - top.x, p.global_position.z - top.z).length() > HORN.WAKE + 4.0 and steps < 9800:
		_steer(p, (top - p.global_position) * Vector3(1, 0, 1))
		await physics_frame
		steps += 1
	_release()
	check(a >= TRAIL.TURNS - 0.05 and stuck < 3, "you can really walk the whole trail (to %.2f of %.2f, %d stuck)" % [a, TRAIL.TURNS, stuck])
	check(p.global_position.y > TRAIL.TOP - 0.5, "...and up onto the summit (%.1f m up)" % p.global_position.y)
	check(lit_seen >= 3, "the Waystones light as you go by (%d)" % lit_seen)
	await _physics(10)
	check(int(boss.get("state")) == HORN.State.SLEEP or lair.get("awake"), "(it's still asleep at the summit's edge)")

	# --- Falling off ---
	var stone_y: float = (lair.get("stones")[lair.get("stone_at")].get_meta("spot") as Vector3).y
	p.global_position = Vector3(top.x + 70, 2.0, top.z)
	p.velocity = Vector3.ZERO
	await _physics(30)
	check(absf(p.global_position.y - stone_y) < 3.0, "falling off floats you back to the last Waystone")
	check(int(bosses.get_meta("lair_resume", 0)) == int(lair.get("stone_at")), "...and a faint would start you there too")

	# --- Waking it ---
	game.hp = game.max_hp
	p.global_position = top + Vector3(0, 1.0, 10.0)
	p.velocity = Vector3.ZERO
	await _physics(8)
	check(lair.get("awake") and int(boss.get("state")) != HORN.State.SLEEP, "on the summit it wakes up")
	var bar := boss.get("_bar") as Node
	check(bar != null and bar.visible, "...with its meter")

	# --- Phases: one-way, never skipped, a roar to start each ---
	check(boss.phase_for(0) == 0 and boss.phase_for(6) == 1 and boss.phase_for(12) == 2, "18 pops in three phases")
	boss.set("state", HORN.State.DAZED)
	check(boss.shot(30, boss.global_position, Vector3.FORWARD) == "hit", "puffed out, a bubble counts")
	check(int(boss.get("hits")) <= 3, "...but at most 3 a daze (%d)" % boss.get("hits"))
	boss.set("hits", 5)
	boss.set("_daze_hits", 0)
	boss.set("state", HORN.State.DAZED)
	boss.hurt(3)
	check(int(boss.get("hits")) == 6, "a burst stops at the phase's edge, never skipping it (%d)" % boss.get("hits"))
	check(int(boss.get("phase")) == 1 and int(boss.get("state")) == HORN.State.TURN, "...and it rears up and roars into phase 2")
	check(boss.shot(3, boss.global_position, Vector3.FORWARD) == "miss", "...and can't be hit while it roars")
	boss.set("_state_t", 0.0)
	await _physics(3)
	check(bool(boss.get("shield_on")), "in phase 2 its antlers shield it")
	var shards: Array = boss.get("shards")
	var lit := 0
	for s in shards:
		if boss.shard_lit(s):
			lit += 1
	check(shards.size() == 3 and lit == 3, "...and three Star Shards light up round the summit")
	for s in shards:
		check(Vector2((s as Node3D).global_position.x - top.x, (s as Node3D).global_position.z - top.z).length() < TRAIL.SUMMIT_R - 3.0,
			"...%s stands on the summit" % (s as Node).name)
	boss.set("state", HORN.State.DAZED)
	check(boss.shot(1, boss.global_position, Vector3.FORWARD) == "miss", "shielded, bubbles boing off even when it's puffed out")
	(shards[0] as Node).call("shot", 1, (shards[0] as Node3D).global_position, Vector3.FORWARD)
	check(not boss.shard_lit(shards[0]), "a bubble breaks a shard")
	p.global_position = (shards[1] as Node3D).global_position + Vector3(0, 2.0, 0)
	await _physics(3)
	check(not boss.shard_lit(shards[1]), "...and so does jumping into one")
	boss.break_shard(shards[2])
	check(int(boss.get("state")) == HORN.State.STAGGER and not bool(boss.get("shield_on")), "all three knock it over, shield down")
	boss.set("_daze_hits", 0)
	check(boss.shot(1, boss.global_position, Vector3.FORWARD) == "hit", "...and then it can be popped")
	check(int(boss.get("phase")) == 1, "it never goes back a phase")

	# --- Walking away ---
	p.global_position = TRAIL.trail_point(TRAIL.TURNS * 0.5) + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(4)
	check(int(boss.get("state")) == HORN.State.SLEEP and int(boss.get("hits")) == 0 and int(boss.get("phase")) == 0,
		"walk back down and it settles back to sleep, all its puff back")

	# --- Calming it ---
	var sparkles: int = game.sparkles
	var remnants: int = root.get_node("Remnants").count
	boss.set("state", HORN.State.STAGGER)
	boss.set("phase", 2)
	boss.set("hits", 17)
	boss.set("_daze_hits", 0)
	boss.call("_find_player")
	boss.hurt(1)
	await _physics(4)
	check(bool(boss.get("defeated")) and lair.get("popped"), "18 pops calm it")
	check(root.get_node("Dialogue").flags.get("starhorn_calmed", false), "...and it's remembered")
	check(game.sparkles - sparkles == 40 and root.get_node("Remnants").count - remnants == 5, "...for 40 sparkles and 5 Remnants")
	check(game.has_item("shop:starhorn_antlers"), "...and the Starhorn Antlers")
	var tspot := lair.get_node("Treasure Spot")
	check(str(tspot.offer.call()) == "open the treasure", "the Star Chest opens now")
	var before: int = game.sparkles
	tspot.act.call()
	check(game.sparkles - before == 25, "...for 25 sparkles")
	check(lair.get_node_or_null("Treasure Way Out") != null, "a way home appears by the chest")

	# --- A second time: no second reward ---
	var b2: CharacterBody3D = HORN.new()
	lair.add_child(b2)
	b2.set("home", top)
	b2.global_position = top
	b2.set("state", HORN.State.STAGGER)
	b2.set("hits", 17)
	b2.set("phase", 2)
	b2.call("_find_player")
	sparkles = game.sparkles
	b2.hurt(1)
	check(game.sparkles == sparkles, "calming it again gives no second reward")
	b2.queue_free()

	# --- Home ---
	var hspot := lair.get_node("Treasure Way Out/Home Spot")
	hspot.act.call()
	await _frames(10)
	await _physics(30)
	town = current_scene as Node3D
	check(town.scene_file_path == TOWN, "the way home takes you back to the Void")
	check(not bosses.has_meta("lair_resume"), "...and the next trip starts at the bottom again")
	p = town.find_child("Player", true, false) as CharacterBody3D
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(outp.x, outp.z)) < 1.5,
		"...in front of the cleft")
	_finish()


func _clear(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	sq.shape = cap
	sq.transform = Transform3D(Basis(), at + Vector3(0, 1.1, 0))
	sq.collide_with_areas = false
	return space.intersect_shape(sq, 4).is_empty()


func _steer(p: CharacterBody3D, want: Vector3) -> void:
	if want.length() < 0.01:
		_release()
		return
	want = want.normalized()
	var b: Basis = p.get_node("SpringArm3D").global_transform.basis
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
	var ix := rgt.dot(want)
	var iy := -fwd.dot(want)
	_release()
	if ix > 0:
		Input.action_press("move_right", ix)
	else:
		Input.action_press("move_left", -ix)
	if iy > 0:
		Input.action_press("move_back", iy)
	else:
		Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	_release()
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
