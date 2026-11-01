extends SceneTree

# Checks the Star Popper on the board (scripts/star_popper.gd with scenes/player/skate.gd): Shoot works from the hip
# while rolling, in the air, grinding and in a manual, Aim works on the board too (steering then goes from where
# she's going, not the camera, and not in a race, where Aim is the power-up), each
# Gloop or Crocodillo popped is a "Pop!" trick in the combo (worth points, its own multiplier entry, half for a
# repeat) and fills some of the special meter, a big bubble still costs 1 MP, and her arm points the popper without
# turning the board. The Skate Park's two new goals ("Pop 3 Gloops in one combo", "Pop a Gloop off a grind") pay once,
# there are sleepy Gloops round the park and by the town rails, riders with no hand free can't shoot, Shoot doesn't
# clash with a skate button on keys or a controller (old settings that clash are put right), and the tip and Coach
# Bruno's lesson say how.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate_popper.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.skate_popper_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.skate_popper_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	dialogue = root.get_node("Dialogue")
	settings.use_layout("classic")
	settings.race_intros = false
	settings.last_device = "keyboard"
	settings.tips = false
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_"):
			dialogue.flags.erase(f)
	if not game.has_item("skateboard"):
		game.items.append("skateboard")

	# --- The controls: Shoot never shares a button with a skate trick ---
	var board_actions := ["jump", "toggle_skateboard", "skate_grind", "skate_flip", "skate_grab"]
	for style in ["classic", "simple"]:
		settings.use_layout(style)
		var key_clash := []
		var pad_clash := []
		for a in board_actions:
			if settings.bindings[a] == settings.bindings["shoot"]:
				key_clash.append(a)
			if settings.pad_bindings[a] == settings.pad_bindings["shoot"]:
				pad_clash.append(a)
		check(key_clash.is_empty() and pad_clash.is_empty(),
			"%s layout: Shoot (%s / %s) shares nothing with the skate buttons%s" % [style, settings.key_name("shoot"),
			settings.pad_name("shoot"), "" if key_clash.is_empty() and pad_clash.is_empty() else " (%s)" % str(key_clash + pad_clash)])
	settings.use_layout("classic")
	check("shoot" in settings.PAD_GROUPS[1], "Shoot is one of the buttons used on the board, so remapping checks it there")
	var clash: String = settings.rebind_pad("shoot", JOY_BUTTON_B)
	check(clash == "skate_grab" and settings.pad_name("skate_grab") == "RT",
		"moving Shoot onto B swaps the grab onto RT (clash: %s)" % clash)
	settings.use_layout("classic")
	# Settings from before: Shoot was put on X (Roll on foot) back when it was only for walking, but X flips on the board
	var old := ConfigFile.new()
	for a in settings.default_pad_bindings():
		old.set_value("pad", a, settings.default_pad_bindings()[a])
		old.set_value("keys", a, settings.default_bindings().get(a, 0))
	old.set_value("pad", "shoot", JOY_BUTTON_X)
	old.set_value("pad", "dash", settings.PAD_RT)
	old.save(SETTINGS)
	settings.load_settings()
	settings.apply()
	check(settings.pad_name("shoot") == "RT" and settings.pad_name("skate_flip") == "X" and settings.pad_name("dash") == "X",
		"old settings with Shoot on a skate button get Shoot back on RT (shoot %s, flip %s, roll %s)" % [
		settings.pad_name("shoot"), settings.pad_name("skate_flip"), settings.pad_name("dash")])
	settings.use_layout("classic")

	# --- In town, on the board ---
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var s: Node = p.get_node("Skate")
	var popper = p.get("popper")
	var t: SkateTricks = s.tricks
	var park := town.get_node("Skate Park") as Node3D
	var c := park.global_position
	await _physics(3)
	var skate_gloops: Array[Node] = park.find_children("Skate Gloop *", "", false, false)
	var in_park := 0
	var by_rails := 0
	for g in skate_gloops:
		var d := Vector2((g as Node3D).global_position.x - c.x, (g as Node3D).global_position.z - c.z).length()
		if d < park.RADIUS:
			in_park += 1
		else:
			by_rails += 1
	check(in_park >= 4, "sleepy Gloops wander the Skate Park (%d)" % in_park)
	check(by_rails >= 4, "...and the town rails nearest it (%d)" % by_rails)
	check(skate_gloops.size() > 0 and float(skate_gloops[0].get("sight_range")) == 0.0
		and float(skate_gloops[0].get("wander_speed")) < 1.0, "...slow ones that never chase her")
	# Out of the way: each check brings one up close and keeps it still
	var gloops: Array[Node] = []
	for g in skate_gloops:
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)
		gloops.append(g)
	for g in town.find_children("Gloop *", "", true, false) + town.find_children("Crocodillo *", "", true, false):
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)

	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var floor_at := c + Vector3(0, 0.25, 0)
	check(popper.can_shoot(), "she can shoot on the board")

	# --- Aiming on the board: the camera's free to look round, the board keeps going where it was going ---
	_put(p, s, floor_at + Vector3(-6, 0.85, 1.5), s.State.ROLL)
	p.velocity = Vector3(4, 0, 0)
	await _physics(5)
	var boom := p.get("spring_arm") as SpringArm3D
	var look := Vector3(cos(1.2), 0, -sin(1.2))         # about 70 degrees to her left of where she's going
	Input.action_press("aim")
	await _physics(15)
	boom.rotation = Vector3(-0.1, atan2(-look.x, -look.z), 0)
	await _physics(15)
	check(popper.aiming and popper.aim_blend == 1.0 and is_equal_approx(float(boom.get("aim")), 1.0),
		"holding Aim on the board aims: the camera moves in over her shoulder")
	check(popper._cross.visible, "...the crosshair shows")
	var cam_f := -boom.global_transform.basis.z
	check(Vector2(cam_f.x, cam_f.z).normalized().dot(Vector2(look.x, look.z)) > 0.98,
		"...and the camera stays where it's pointed (it doesn't swing back behind her)")
	var steer: Vector3 = s._camera_dir(Vector2(0, -1))
	var going := Vector3(p.velocity.x, 0, p.velocity.z).normalized()
	check(steer.dot(going) > 0.98, "...holding forward keeps going where she's going, not where the camera looks")
	check(s._camera_dir(Vector2(-1, 0)).dot(going.cross(Vector3.UP) * -1.0) > 0.98, "...and left carves to her left")
	popper._cooldown = 0.0
	var aimed: Node3D = popper.shoot(false)
	var bdir: Vector3 = (aimed.get("velocity") as Vector3).normalized() if aimed else Vector3.ZERO
	check(aimed != null and Vector2(bdir.x, bdir.z).normalized().dot(Vector2(look.x, look.z)) > 0.9,
		"...and a shot goes to the crosshair, off to the side")
	await _physics(10)
	var aim_pose = popper.get("_arm")
	check(aim_pose != null and aim_pose.influence > 0.9 and absf(float(aim_pose.twist)) > 0.4,
		"...her body twists round to the crosshair (%.2f rad)" % (float(aim_pose.twist) if aim_pose else 0.0))
	var races := root.get_node("Races")
	races.state = races.State.RESULTS             # in a race, Aim is the power-up button (scripts/races.gd)
	races._results = 30.0
	await _physics(20)
	check(not popper.aiming, "...but in a race Aim uses the power-up instead")
	races.state = races.State.IDLE
	Input.action_release("aim")
	if aimed and is_instance_valid(aimed):
		aimed.queue_free()
	await _physics(20)

	# --- Rolling: a Pop! of its own, paid out like a combo ---
	_put(p, s, floor_at + Vector3(-5, 0.85, 1.5), s.State.ROLL)
	await _physics(10)
	var yaw_before: float = s._yaw
	var g0 := _stage(p, gloops[0], floor_at + Vector3(2.5, 0, 0.5))
	var banked := []
	t.banked.connect(func(pts: int, names: String) -> void: banked.append([pts, names]))
	var score: int = t.score
	popper.shoot(false)
	await _physics(30)
	check(g0.defeated, "a shot from the hip while rolling pops a Gloop ahead")
	check(absf(s._yaw - yaw_before) < 0.01, "...without turning the board")
	check(popper._raise > 0.0 and popper._prop.visible, "...the popper shows in her hand")
	var arm = popper._arm
	check(arm != null and arm.influence > 0.5 and arm.hand_at.distance_to(p.global_position) < 1.5,
		"...and her arm comes up to point it")
	await _physics(40)
	check(banked.size() > 0 and String(banked[-1][1]).contains("Pop!") and t.score > score,
		"the Pop! is a trick, paid out once she rolls on (%s)" % (str(banked[-1]) if banked.size() > 0 else "nothing paid"))

	# --- In the air, mid-flip: Pop! joins the combo, paid out when she lands ---
	_put(p, s, floor_at + Vector3(-4, 3.5, -2), s.State.AIR)
	p.velocity = Vector3(0, 4, 0)
	t.start_flip("")
	var g1 := _stage(p, gloops[1], floor_at + Vector3(2.5, 0, -2))
	var special: float = t.special
	popper.shoot(false)
	await _physics(25)
	check(g1.defeated, "a shot in the air pops one too")
	var pop_entry := t.combo.filter(func(e: Dictionary) -> bool: return e.name == "Pop!")
	check(pop_entry.size() == 1 and int(pop_entry[0].points) == 250, "...it's a Pop! in the combo, worth 250")
	check(t.special > special + 0.1, "...and fills some of the special meter (%.2f -> %.2f)" % [special, t.special])
	banked.clear()
	for i in 90:
		await physics_frame
		if banked.size() > 0:
			break
	check(banked.size() > 0 and String(banked[-1][1]).contains("Pop!") and String(banked[-1][1]).contains("Kickflip"),
		"...landing pays out the flip and the Pop! together (%s)" % (str(banked[-1]) if banked.size() > 0 else "nothing paid"))

	# --- Grinding: Pop a Gloop off a grind (a Skate Park goal) ---
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_goal_"):
			dialogue.flags.erase(f)
	var sparkles: int = game.sparkles
	var rail := park.get_node("Flat Rail").find_children("*", "GrindRail", true, false)[0] as GrindRail
	var on := rail.point_at(rail.length() * 0.25)
	_put(p, s, on + Vector3(0, 1.4, 0), s.State.AIR)
	p.velocity = Vector3(5, -1, 0)
	s._yaw = PI / 2
	s._grind_buffer = 0.2
	check(s._try_grind(), "she locks onto the park's flat rail")
	await _physics(2)
	var g2 := _stage(p, gloops[2], rail.point_at(rail.length() * 0.9) + Vector3(0, -0.5, 1.6))
	popper.shoot(false)
	await _physics(20)
	check(g2.defeated, "a shot while grinding pops a Gloop beside the rail")
	check(s.state == s.State.GRIND or t.names().contains("Pop!"), "...she keeps grinding (or rode off the end) with Pop! in the combo (%s)" % t.names())
	check(park.is_done("grind_pop") and game.sparkles >= sparkles + 4, "\"Pop a Gloop off a grind\" is done, for 4 sparkles")
	s._leave_rail(Vector3.ZERO)
	t.bank()

	# --- A manual: shooting keeps it going ---
	_put(p, s, floor_at + Vector3(-5, 0.85, 1.5), s.State.ROLL)
	await _physics(10)
	p.velocity = Vector3(3, 0, 0)
	s._yaw = PI / 2
	s._start_manual(1)
	var g3 := _stage(p, gloops[3], floor_at + Vector3(3, 0, 1.5))
	popper.shoot(false)
	await _physics(20)
	check(g3.defeated and s._manual != 0, "a shot in a manual pops one, and she stays in the manual")
	check(t.names().contains("Pop!") and t.multiplier() >= 2, "...Pop! adds to the multiplier (x%d: %s)" % [t.multiplier(), t.names()])
	s._end_manual()
	t.bank()

	# --- Three in one combo, and repeats worth half ---
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_goal_"):
			dialogue.flags.erase(f)
	sparkles = game.sparkles
	t.lose()
	_put(p, s, floor_at + Vector3(-5, 4, 1.5), s.State.AIR)
	p.velocity = Vector3(0, 8, 0)
	for k in 3:
		var g := _stage(p, gloops[4 + k], floor_at + Vector3(3, 0, -2.0 + 2.0 * k))
		popper._cooldown = 0.0
		popper.shoot(false)
		await _physics(24)
		check(g.defeated, "pop %d of 3 in one air" % (k + 1))
	var pts := t.combo.filter(func(e: Dictionary) -> bool: return e.name == "Pop!").map(func(e: Dictionary) -> int: return int(e.points))
	check(pts.size() == 3 and pts[1] == pts[0] / 2 and pts[2] == pts[1] / 2,
		"each Pop! again in one combo is worth half (%s)" % str(pts))
	check(park.is_done("pop3") and game.sparkles >= sparkles + 5, "\"Pop 3 Gloops in one combo\" is done, for 5 sparkles")
	var before: int = game.sparkles
	t.popped.emit("gloop", false)
	check(game.sparkles == before, "...the goals only pay once")
	await _physics(60)
	t.bank()

	# --- A Crocodillo is a Croc Pop! ---
	var croc := town.find_children("Crocodillo *", "", true, false)[0] as CharacterBody3D
	var CROC: GDScript = load("res://scripts/crocodillo.gd")
	_put(p, s, floor_at + Vector3(-5, 0.85, 1.5), s.State.ROLL)
	await _physics(5)
	_stage(p, croc, floor_at + Vector3(2, 0, 1.5))
	croc._set_state(CROC.State.WANDER)
	(croc.get_node("Visual/Ball") as Node3D).visible = false
	(croc.get_node("Visual/Body") as Node3D).visible = true
	croc.hits = 1
	await _physics(2)
	popper.shoot(false)
	await _physics(20)
	check(croc.defeated and t.names().contains("Croc Pop!"), "popping a Crocodillo is a Croc Pop! (%s)" % t.names())
	t.bank()

	# --- The big bubble still costs 1 MP ---
	game.mp = game.max_mp
	var mp: int = game.mp
	var shots: int = popper.shots
	_put(p, s, floor_at + Vector3(-5, 0.85, 1.5), s.State.ROLL)
	await _physics(3)
	Input.action_press("shoot")
	await _physics(80)
	check(popper.charge >= 1.0, "holding Shoot on the board charges a big bubble")
	Input.action_release("shoot")
	await _physics(2)
	check(game.mp == mp - 1 and popper.shots == shots + 2, "...a tap blows a bubble, letting go the big one for 1 MP (%d -> %d)" % [mp, game.mp])

	# --- The whole-body ride pose: twist, head, balancing arm, kick, a crouch to charge, and it blends out ---
	await _physics(90)                                   # let the last shot's pose blend away first
	_put(p, s, floor_at + Vector3(-5, 0.85, 1.5), s.State.ROLL)
	await _physics(5)
	var pose = popper._arm
	await _physics(2)
	var g9 := _stage(p, gloops[9 % gloops.size()], floor_at + Vector3(1, 0, 6.5))   # off to her left side
	var steps := []
	var last: float = pose.influence
	popper._cooldown = 0.0
	popper.shoot(false)
	for i in 14:
		await physics_frame
		steps.append(absf(pose.influence - last))
		last = pose.influence
	check(steps.max() < 0.16, "the pose eases in rather than popping on (biggest step %.2f a frame)" % steps.max())
	check(pose.influence > 0.95 and pose.ride_weight > 0.95, "...and is all the way on after about 0.15 s")
	check(absf(pose.twist) > 0.3, "she twists round towards a shot off to the side (%.0f degrees)" % rad_to_deg(pose.twist))
	check(rad_to_deg(pose.chest_turned) > 8.0, "...her chest turns with it (%.0f degrees)" % rad_to_deg(pose.chest_turned))
	check(rad_to_deg(pose.left_arm_turned) > 15.0, "...and her other arm swings out for balance (%.0f degrees)" % rad_to_deg(pose.left_arm_turned))
	check(pose.points.dot(popper.arm_dir()) > 0.9, "...while the popper still points at the shot (%.2f)" % pose.points.dot(popper.arm_dir()))
	check(absf(s._yaw - PI / 2) < 0.01, "...and the board keeps going the way it was")
	pose.kick(false)
	await _physics(2)
	var small: float = pose.lean
	await _physics(30)
	var settled: float = pose.lean
	pose.kick(true)
	await _physics(2)
	var big: float = pose.lean
	check(small > 0.05 and big > small * 1.5 and settled < 0.01,
		"each shot kicks her back a little, a big bubble more, then she settles (%.0f, %.0f, %.0f degrees)" % [
		rad_to_deg(small), rad_to_deg(big), rad_to_deg(settled)])
	# A turn mid-flip: the arm swings round smoothly instead of snapping
	popper._raise = popper.SHOW_AFTER_SHOT
	await _physics(15)
	popper._shot_dir = Vector3(0, 0, -1)
	await _physics(1)
	var swing: float = pose.points.angle_to(Vector3(0, 0, -1))
	await _physics(20)
	check(swing > 0.3 and pose.points.angle_to(Vector3(0, 0, -1)) < 0.35,
		"a new direction: the arm follows through over a few frames (%.0f then %.0f degrees off)" % [rad_to_deg(swing),
		rad_to_deg(pose.points.angle_to(Vector3(0, 0, -1)))])
	# Charging a big bubble: a little crouch
	Input.action_press("shoot")
	await _physics(60)
	check(s._crouch > 0.05, "charging a big bubble, she crouches a little (%.2f)" % s._crouch)
	game.mp = 0
	Input.action_release("shoot")
	await _physics(2)
	game.mp = game.max_mp
	# And when it's over, it's the plain skate pose again
	popper._raise = 0.0
	await _physics(30)
	check(pose.influence < 0.01, "after the shot the pose blends all the way out (%.2f)" % pose.influence)
	check(not popper._prop.visible, "...back to the plain skate pose, with the popper put away")
	g9.set_physics_process(false)

	# --- Simple controls: Shoot is the same ---
	settings.use_layout("simple")
	popper._cooldown = 0.0
	shots = popper.shots
	Input.action_press("shoot")
	await _physics(2)
	Input.action_release("shoot")
	await _physics(2)
	check(popper.shots == shots + 1, "with the Simple controls, Shoot still shoots on the board")
	settings.use_layout("classic")

	# --- Not while she's tumbling in a bail ---
	s.bail()
	check(not popper.can_shoot(), "no shooting mid-bail")
	await _physics(120)

	# --- Who can: riders with a hand free ---
	var RIDES: GDScript = load("res://scripts/rides.gd")
	var no_hands := []
	var no_arm := []
	for id in RIDES.ORDER:
		p.set_rider(id)
		await _physics(4)
		var ride: Dictionary = RIDES.ride(id)
		if not bool(ride.get("popper", true)):
			no_hands.append(id)
			check(not popper.can_shoot(), "%s can't shoot on their ride (no hand free)" % id)
			continue
		check(popper.can_shoot(), "%s can shoot on their ride" % id)
		popper._cooldown = 0.0
		var dir_before: float = s._yaw
		popper.shoot(false)
		await _physics(8)
		if popper._arm == null or not popper._prop.visible:
			no_arm.append(id)
		check(absf(s._yaw - dir_before) < 0.01, "...without the ride turning")
	print("INFO  no hand free: %s; shoots without an arm to point: %s" % [", ".join(no_hands), ", ".join(no_arm) if no_arm else "none"])
	check(no_hands == ["rex", "rook", "pip"], "only Rex, Rook and Pip can't (%s)" % ", ".join(no_hands))
	check(no_arm.is_empty(), "every other rider holds the popper up as they shoot (%s)" % ", ".join(no_arm))
	p.set_rider("hero")
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)

	# --- Away from the park, pops still count in combos but not for the park's goals ---
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_goal_"):
			dialogue.flags.erase(f)
	p.global_position = c + Vector3(80, 5, 0)
	await _physics(2)
	t.popped.emit("gloop", true)
	check(not park.is_done("grind_pop"), "pops away from the park don't count for its goals")

	# --- The board, the tip and the lesson ---
	var board := park.find_child("Goals", true, false) as Label3D
	check(board.text.contains("Pop 3 Gloops in one combo") and board.text.contains("Pop a Gloop off a grind"),
		"the goals board lists the two new goals")
	var tips: Node = root.get_node("Tips")
	check(tips.TIPS.has("skate_shoot") and String(tips.TIPS.skate_shoot.text).contains("{shoot}"), "there's a tip for shooting on the board")
	var lesson: Node = root.get_node("SkateLesson")
	check(String(lesson.STEPS[-1].text).contains("{shoot}"), "Coach Bruno's combo step says Pops count")
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_"):
			dialogue.flags.erase(f)
	_end()


func _put(p: CharacterBody3D, s: Node, at: Vector3, state: int) -> void:
	# Her somewhere in the park, still, in this state
	s.tricks.lose()
	if s.state == s.State.GRIND:
		s._leave_rail(Vector3.ZERO)
	if s.state == s.State.BAIL:
		s._end_bail()
	s._manual = 0
	p.global_position = at
	p.velocity = Vector3.ZERO
	s.state = state
	s._yaw = PI / 2                                      # facing +X, along the park
	(p.get_node("Visual") as Node3D).rotation.y = PI / 2


func _stage(p: CharacterBody3D, enemy: Node, at: Vector3) -> CharacterBody3D:
	# An enemy on the ground here, standing still and ready to be popped
	var e := enemy as CharacterBody3D
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 6, 0), at + Vector3(0, -6, 0))
	q.exclude = [p.get_rid(), e.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	e.global_position = hit.position if not hit.is_empty() else at
	e.velocity = Vector3.ZERO
	e.set_physics_process(false)
	if e.get("defeated") == true:
		e.set("defeated", false)
		e.set("hits", 0)
		(e.get_node("CollisionShape3D") as CollisionShape3D).disabled = false
		(e.get_node("Visual") as Node3D).visible = true
	return e


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
	Input.action_release("aim")
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	quit(1 if failures > 0 else 0)
