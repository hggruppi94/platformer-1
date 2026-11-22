extends SceneTree

# Checks the bosses' own lairs (scripts/boss_lair.gd, scripts/clock_tower.gd, scripts/boulder_canyon.gd, the gates in
# scripts/bosses.gd): Tock and the Boulderdillo aren't out in town any more; the Tower Door stands in the Goblin
# Clockyard and the Canyon Mouth in Boulder Hollow, each with a way in and room to come out; inside, you can really walk
# from the way in to the arena; the hazards (pendulums, the floor hand, rolling boulders, falling rocks) bump you; the
# boss sleeps until you come in and fights when you do; popping it opens the treasure once a visit and puts a way home
# by it; saving inside saves you there; and the way home lands you on the ground in front of the gate.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boss_lairs.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.lairs_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lairs_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var bosses: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
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
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)

	change_scene_to_file(TOWN)
	await _frames(8)
	await _physics(4)
	var town := current_scene as Node3D
	check(town.find_child("Grandfather Tock", true, false) == null, "Grandfather Tock isn't out in the Clockyard any more")
	check(town.find_child("The Boulderdillo", true, false) == null, "...and the Boulderdillo isn't out in Boulder Hollow")
	check(town.find_children("Time Goblin *", "", true, false).size() == 8, "the Time Goblins still roam the Void")
	await _lair(town, "clock_tower", "Goblin Clockyard/Tower Door", "Grandfather Tock", "popped_grandfather_tock", 0.0)
	town = current_scene as Node3D
	await _lair(town, "boulder_canyon", "Boulder Hollow/Canyon Mouth", "The Boulderdillo", "popped_boulderdillo", 2.25)
	_finish()


func _lair(town: Node3D, id: String, gate_path: String, boss_name: String, flag: String, lane: float) -> void:
	var gate := town.get_node_or_null(gate_path) as Node3D
	check(gate != null, "%s stands in town" % gate_path)
	if gate == null:
		return
	var out: Dictionary = bosses.lair_out(id)
	var outp: Vector3 = out.position
	var ground_out: Vector3 = bosses.ground(town, outp.x, outp.z)
	var sq := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	sq.shape = cap
	sq.transform = Transform3D(Basis(), ground_out + Vector3(0, 1.1, 0))
	sq.collide_with_areas = false
	var space := town.get_world_3d().direct_space_state
	check(space.intersect_shape(sq, 4).is_empty(), "...with nothing solid where you come out in front of it")
	check(absf(ground_out.y - gate.global_position.y) < 1.0, "...and flat ground there")
	var spot := gate.get_node_or_null("Lair Spot")
	var want := "go in to %s" % bosses.LAIRS[id].name
	check(spot != null and str(spot.offer.call()) == want, "...and it offers the way in (%s)" % want)
	spot.act.call()
	await _frames(10)
	await _physics(6)
	var lair := current_scene as Node3D
	check(lair.scene_file_path == bosses.LAIRS[id].scene, "it takes you into %s" % bosses.LAIRS[id].name)
	var p := lair.find_child("Player", true, false) as CharacterBody3D
	check(p != null and p.global_position.z < 6.0 and p.global_position.z > 0.0, "...just inside the way in")
	var boss := lair.get_node_or_null(boss_name) as CharacterBody3D
	check(boss != null and boss.process_mode == Node.PROCESS_MODE_DISABLED and not lair.get("awake"),
		"%s is there, asleep until you come in" % boss_name)
	var arena: Vector3 = lair.call("arena")

	# --- Really walking from the way in to the arena (other enemies held still) ---
	for e in get_nodes_in_group("enemies"):
		if e != boss:
			(e as Node).process_mode = Node.PROCESS_MODE_DISABLED
			(e as Node3D).global_position += Vector3(0, -60, 0)
	p.global_position = Vector3(lane if id == "boulder_canyon" else -7.8, 1.0, 3.0)
	p.velocity = Vector3.ZERO
	await _physics(6)
	var stuck := 0.0
	var last := p.global_position
	var steps := 0
	while p.global_position.z < arena.z - lair.call("wake_range") - 2.0 and steps < 1200:
		# (in the tower: along the edge, past where the pendulums reach, then in through the Cog Gate's middle)
		var lane_x := lane if id == "boulder_canyon" else (-7.8 if p.global_position.z < 36.0 else 0.0)
		_steer(p, Vector3(clampf((lane_x - p.global_position.x) * 0.5, -0.6, 0.6), 0, 1).normalized())
		await physics_frame
		steps += 1
		if steps % 60 == 0:
			if p.global_position.distance_to(last) < 0.5:
				stuck += 1
			last = p.global_position
	_release()
	check(p.global_position.z >= arena.z - float(lair.call("wake_range")) - 2.0 and stuck < 2,
		"you can really walk from the way in to the arena (got to z %.1f)" % p.global_position.z)
	check(game.hp == game.max_hp or not p.is_recovering(), "...along the safe side without a bump")

	# --- Its hazards ---
	if id == "clock_tower":
		p._invulnerable_timer = 0.0
		var hit := false
		for i in 40:
			var b: Vector3 = lair.call("bob_position", 0)
			p.global_position = Vector3(b.x, 1.0, b.z)
			p.velocity = Vector3.ZERO
			await physics_frame
			if p.is_recovering():
				hit = true
				break
		check(hit, "a swinging pendulum knocks you back")
	else:
		p._invulnerable_timer = 0.0
		p.global_position = Vector3(0, 1.0, 20.0)
		await _physics(2)
		var hit := false
		for i in 400:
			p.global_position = Vector3(0, 1.0, 20.0)
			p.velocity = Vector3.ZERO
			await physics_frame
			if p.is_recovering():
				hit = true
				break
		var rolling: Array = lair.get("rolling")
		check(hit, "a boulder rolling down the lane bumps you (%d rolling)" % rolling.size())
	game.hp = game.max_hp

	# --- Waking it up ---
	p._invulnerable_timer = 0.0
	p.global_position = arena + Vector3(0, 1.0, -8.0)
	p.velocity = Vector3.ZERO
	await _physics(4)
	check(lair.get("awake") and boss.process_mode != Node.PROCESS_MODE_DISABLED, "come into the arena and it wakes up")
	await _physics(60)
	check(boss.global_position.distance_to(arena) < 22.0, "...and comes down into the arena to fight")
	if id == "clock_tower":
		check(lair.get("hand_on"), "the floor's long hand starts sweeping round")
		var hand := lair.get("hand") as Node3D
		var r0 := hand.rotation.y
		await _physics(30)
		check(hand.rotation.y != r0, "...and it really turns")
		boss.set_physics_process(false)
		p._invulnerable_timer = 0.0
		var hit := false
		for i in 30:
			var dir := hand.global_transform.basis.z
			p.global_position = hand.global_position + Vector3(dir.x, 0, dir.z) * 9.0 + Vector3(0, 0.95, 0)
			p.velocity = Vector3.ZERO
			await physics_frame
			if p.is_recovering():
				hit = true
				break
		check(hit, "...and standing on the floor where it sweeps gets you bumped")
		boss.set_physics_process(true)
	else:
		check(lair.get("rocks_on"), "rocks start falling from the rim")
		boss.set_physics_process(false)
		game.hp = game.max_hp
		p._invulnerable_timer = 0.0
		var spot_at := arena + Vector3(5, 0, 0)
		p.global_position = spot_at + Vector3(0, 0.95, 0)
		p.velocity = Vector3.ZERO
		lair.set("_fall_t", 99.0)
		lair.call("drop_rock", spot_at)
		check(lair.find_child("Rock Coming", true, false) != null, "...each one wobbles on the rim over where it will land")
		var hit := false
		for i in 150:
			p.global_position = spot_at + Vector3(0, 0.95, 0)
			await physics_frame
			if p.is_recovering():
				hit = true
				break
		check(hit, "...and staying on the shadow gets you bumped")
		await _physics(30)
		check(lair.find_child("Fallen Rock", true, false) != null, "...and the rock stays lying there a while")
		boss.set_physics_process(true)
	game.hp = game.max_hp

	# --- Popping it ---
	var sparkles: int = game.sparkles
	var tspot := lair.get_node("Treasure Spot")
	check(str(tspot.offer.call()) == "", "the treasure won't open before it's popped")
	boss.set_physics_process(false)
	if id == "boulder_canyon":
		check(boss.shot(1, boss.global_position, Vector3.FORWARD) == "bounce", "bubbles boing off the Boulderdillo till it's dizzy")
		boss.set("state", 4)                                  # (dizzy)
	boss.shot(int(boss.get("stomps_to_defeat")), boss.global_position, Vector3.FORWARD)
	await _physics(4)
	check(boss.get("defeated") and lair.get("popped"), "enough pops beat %s" % boss_name)
	check(root.get_node("Dialogue").flags.has(flag), "...and it's remembered (%s)" % flag)
	if id == "clock_tower":
		check(not lair.get("hand_on"), "...and the floor hand stops")
	else:
		check(not lair.get("rocks_on"), "...and the rocks stop falling")
	check(str(tspot.offer.call()) == "open the treasure", "the treasure can be opened now")
	tspot.act.call()
	check(game.sparkles - sparkles >= 12, "...for sparkles (%d)" % (game.sparkles - sparkles))
	check(str(tspot.offer.call()) == "", "...once")
	check(lair.get_node_or_null("Treasure Way Out") != null, "a way home appears by the treasure")

	# --- Saving inside, then home ---
	game.hold_saves = false
	game.save_game()
	game.hold_saves = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(str(data.get("scene", "")) == bosses.LAIRS[id].scene, "saving in there saves you there")
	var hspot := lair.get_node("Treasure Way Out/Home Spot")
	check(str(hspot.offer.call()) == "go home to the Void", "the way home offers to take you home")
	hspot.act.call()
	await _frames(10)
	await _physics(30)
	town = current_scene as Node3D
	check(town.scene_file_path == TOWN, "it takes you back to the Void")
	p = town.find_child("Player", true, false) as CharacterBody3D
	var g2: Vector3 = bosses.ground(town, outp.x, outp.z)
	check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(outp.x, outp.z)) < 1.5
		and absf(p.global_position.y - g2.y - 0.9) < 0.6,
		"...standing on the ground in front of its way in (%.1f m up)" % (p.global_position.y - g2.y))
	check(town.find_child(boss_name, true, false) == null, "...and the boss isn't out in town")


func _steer(p: CharacterBody3D, want: Vector3) -> void:
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
