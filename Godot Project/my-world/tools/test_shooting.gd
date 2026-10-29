extends SceneTree

# Checks aiming and shooting with the Star Popper (scripts/star_popper.gd, scripts/star_bubble.gd) in the town:
# Aim and Shoot are in the remapping lists (right and left click, LT and RT), can be moved onto keys, mouse buttons and
# triggers, and old settings get them. A shot from the hip finds a Gloop in front of her and pops it (caught in a
# bubble, floating up) for XP. Holding Aim moves the camera over her shoulder with a crosshair, turns her to face
# where it looks, slows her down and raises her arm with the popper in her hand; aimed shots go to the crosshair.
# Big Gloops take two bubbles; holding Shoot charges a big bubble for 1 MP that pops one at once. Bubbles boing off a
# rolling Crocodillo; out of its ball one makes it dizzy and a second pops it. No shooting on the skateboard or in a
# conversation, and bubbles that hit nothing pop by themselves.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_shooting.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.test_backup.cfg"
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
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
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
	settings.last_device = "keyboard"
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false

	# --- The controls ---
	var rebindable := func(list: Array, action: String) -> bool: return list.any(func(p: Array) -> bool: return p[0] == action)
	check(rebindable.call(settings.REBINDABLE, "aim") and rebindable.call(settings.REBINDABLE, "shoot"),
		"Aim and Shoot are in the key list")
	check(rebindable.call(settings.PAD_REBINDABLE, "aim") and rebindable.call(settings.PAD_REBINDABLE, "shoot"),
		"...and the controller list")
	check(settings.key_name("aim") == "Right click" and settings.key_name("shoot") == "Left click",
		"Aim is right click, Shoot is left click (%s, %s)" % [settings.key_name("aim"), settings.key_name("shoot")])
	check(settings.pad_name("aim") == "LT" and settings.pad_name("shoot") == "RT",
		"...LT and RT on a controller (%s, %s)" % [settings.pad_name("aim"), settings.pad_name("shoot")])
	check(_has_event("shoot", func(e: InputEvent) -> bool: return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT),
		"left click really shoots")
	check(_has_event("aim", func(e: InputEvent) -> bool: return e is InputEventJoypadMotion and e.axis == JOY_AXIS_TRIGGER_LEFT),
		"...and LT really aims")
	settings.rebind("aim", KEY_C)
	check(settings.key_name("aim") == "C" and not _has_event("aim", func(e: InputEvent) -> bool: return e is InputEventMouseButton),
		"Aim can move to a key (C), and right click lets go")
	settings.rebind("shoot", -MOUSE_BUTTON_RIGHT)
	check(settings.key_name("shoot") == "Right click", "Shoot can move to another mouse button")
	settings.rebind_pad("shoot", JOY_BUTTON_RIGHT_SHOULDER)
	check(settings.pad_name("shoot") == "RB" and _has_event("shoot", func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
		and not _has_event("shoot", func(e: InputEvent) -> bool: return e is InputEventJoypadMotion),
		"Shoot can move off the trigger onto RB")
	var clash: String = settings.rebind_pad("jump", settings.PAD_LT)
	check(clash == "aim" and settings.pad_name("jump") == "LT" and settings.pad_name("aim") == "A",
		"putting Jump on LT swaps Aim onto A (clash: %s)" % clash)
	settings.use_layout("classic")
	check(settings.key_name("aim") == "Right click" and settings.pad_name("jump") == "A", "the layout puts them back")
	# Settings saved before there was shooting: Aim and Shoot get their own clicks and triggers
	var old := ConfigFile.new()
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "dash", "interact", "pause"]:
		old.set_value("keys", a, settings.default_bindings()[a])
		old.set_value("pad", a, settings.default_pad_bindings().get(a, -1))
	old.save(SETTINGS)
	settings.load_settings()
	settings.apply()
	check(settings.key_name("aim") == "Right click" and settings.pad_name("shoot") == "RT", "old settings get Aim and Shoot too")
	check(settings.fill("{shoot} {aim}") == "Left click Right click", "tips can say the keys ({shoot} {aim})")

	# --- In town ---
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var popper = p.get("popper")
	check(popper != null, "the player has a Star Popper")
	check(p.find_child("PopperArm", true, false) != null, "...and her arm can point it")
	var gloops: Array[Node] = town.find_children("Gloop *", "", true, false)
	check(gloops.size() >= 3, "there are Gloops to pop (%d)" % gloops.size())
	var flat := _flat_spot(town, p)
	for g in gloops + town.find_children("Crocodillo *", "", true, false):
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)      # out of the way: each check brings one up close

	# --- From the hip: it finds a Gloop in front of her ---
	var g0 := gloops[0] as CharacterBody3D
	_stage(p, g0, flat, Vector3(7, 0, 1.5))
	await _frames(3)
	var xp: int = game.xp
	var level: int = game.level
	var b = popper.shoot(false)
	check(b != null, "Shoot blows a bubble")
	await _physics(40)
	check(g0.defeated, "a shot from the hip finds the Gloop off to one side and pops it")
	check(game.xp > xp or game.level > level, "...for XP")
	check(g0.find_child("CaughtBubble", false, false) != null and g0.get_node("Visual").position.y > 0.05,
		"...it's caught in a bubble and floats up")
	await _physics(60)
	check(not (g0.get_node("Visual") as Node3D).visible and g0.find_child("CaughtBubble", false, false) == null,
		"...then the bubble pops and it's gone")

	# --- Aiming ---
	var g1 := gloops[1] as CharacterBody3D
	_stage(p, g1, flat, Vector3(0, 0, 12))
	var arm := p.get_node("SpringArm3D") as SpringArm3D
	arm.rotation = Vector3(-0.1, 0.0, 0.0)          # looking -Z, away from the Gloop at +Z
	var arm_len := arm.spring_length
	var fov := (arm.get_node("Camera3D") as Camera3D).fov
	settings.last_device = "pad"
	Input.action_press("aim")
	await _physics(20)
	check(popper.aiming and popper.aim_blend > 0.99, "holding Aim aims")
	check(arm.spring_length < arm_len - 1.5 and (arm.get_node("Camera3D") as Camera3D).fov < fov - 5.0,
		"...the camera moves in over her shoulder and zooms a little (%.1f m, %.0f°)" % [arm.spring_length, (arm.get_node("Camera3D") as Camera3D).fov])
	check(arm.position.x > 0.4, "...to her right")
	var cross_on := false
	for c in popper.find_children("*", "Control", true, false):
		cross_on = cross_on or (c as Control).visible
	check(cross_on, "...a crosshair shows")
	var facing := (p.get_node("Visual") as Node3D).global_transform.basis.z
	check(facing.dot(Vector3(0, 0, -1)) > 0.9, "...she turns to face where the camera looks")
	check(popper.move_scale() < 0.6, "...and walks slower")
	check(popper._prop.visible, "...with the popper in her hand")
	var posed = popper._arm
	check(popper._prop.global_position.distance_to(posed.hand_at) < 0.15 and posed.hand_at.distance_to(p.global_position) < 1.2,
		"...right at her hand (%.2f m off)" % popper._prop.global_position.distance_to(posed.hand_at))
	check(posed.points.dot(popper.arm_dir()) > 0.95, "...and her arm points where she aims (%.2f)" % posed.points.dot(popper.arm_dir()))
	# Turn round to the Gloop: aimed shots go where the crosshair is
	arm.rotation = Vector3(0, PI, 0)
	await _physics(4)
	_look_at(arm, _centre(g1))
	await _physics(10)
	_look_at(arm, _centre(g1))
	await _physics(2)
	check(popper._on_target, "the crosshair turns pink on the Gloop")
	g1.stomps_to_defeat = 2                         # a big Gloop
	popper.shoot(false)
	await _physics(40)
	check(not g1.defeated and g1.hits == 1, "a big Gloop takes more than one bubble")
	await _physics(10)
	popper.shoot(false)
	await _physics(40)
	check(g1.defeated, "...and pops on the second one")
	Input.action_release("aim")
	await _physics(20)
	check(not popper.aiming and arm.spring_length > arm_len - 0.2, "letting go of Aim puts the camera back")

	# --- A big bubble: hold Shoot ---
	var g2 := gloops[2] as CharacterBody3D
	_stage(p, g2, flat, Vector3(0, 0, 8))
	g2.stomps_to_defeat = 3
	game.mp = game.max_mp
	var mp: int = game.mp
	var shots: int = popper.shots
	Input.action_press("shoot")
	await _physics(2)
	check(popper.shots == shots + 1, "pressing Shoot blows a bubble straight away")
	await _physics(80)
	check(popper.charge >= 1.0, "holding it charges a big bubble (%.2f)" % popper.charge)
	Input.action_release("shoot")
	await _physics(2)
	check(game.mp == mp - 1 and popper.shots == shots + 2, "letting go blows it, for 1 MP (%d -> %d)" % [mp, game.mp])
	await _physics(50)
	check(g2.defeated, "a big bubble pops a three-bubble Gloop at once")

	# --- The Crocodillo ---
	var croc := town.find_children("Crocodillo *", "", true, false)[0] as CharacterBody3D
	var CROC: GDScript = load("res://scripts/crocodillo.gd")
	_stage(p, croc, flat, Vector3(0, 0, 9))
	croc.state = CROC.State.ROLL
	(croc.get_node("Visual/Ball") as Node3D).visible = true
	(croc.get_node("Visual/Body") as Node3D).visible = false
	await _frames(2)
	popper.shoot(false)
	await _physics(30)
	check(croc.hits == 0 and not croc.defeated, "bubbles boing off a rolling Crocodillo's shell")
	croc._set_state(CROC.State.WANDER)
	(croc.get_node("Visual/Ball") as Node3D).visible = false
	(croc.get_node("Visual/Body") as Node3D).visible = true
	await _physics(10)
	popper.shoot(false)
	await _physics(30)
	check(croc.hits == 1 and croc.state == CROC.State.DIZZY, "out of its ball, a bubble makes it dizzy")
	await _physics(6)
	popper.shoot(false)
	await _physics(30)
	check(croc.defeated, "...and a second pops it")

	# --- When there's no shooting ---
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	check(not popper.can_shoot(), "no shooting on the skateboard")
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	check(popper.can_shoot(), "...back on foot, there is")
	p.set("input_locked", true)
	check(not popper.can_shoot(), "...but not while talking to someone")
	p.set("input_locked", false)
	# Bubbles that miss pop by themselves
	(p.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(5)
	check(get_nodes_in_group("star_bubbles").size() > 0, "a bubble flies off into the distance")
	await _physics(130)
	check(get_nodes_in_group("star_bubbles").is_empty(), "...and pops by itself")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _has_event(action: String, test: Callable) -> bool:
	for e in InputMap.action_get_events(action):
		if test.call(e):
			return true
	return false


func _flat_spot(town: Node, p: CharacterBody3D) -> Vector3:
	# Somewhere open on the town's ground: the middle of the market square
	var spot := town.find_child("Market Square", true, false) as Node3D
	var at := spot.global_position + Vector3(0, 0, 14) if spot else p.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -40, 0))
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _stage(p: CharacterBody3D, enemy: CharacterBody3D, at: Vector3, offset: Vector3) -> void:
	# Her on open ground, the enemy `offset` from her, both standing still; she faces it, roughly
	p.global_position = at + Vector3(0, 0.85, 0)
	p.velocity = Vector3.ZERO
	var spot := at + offset
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 20, 0), spot + Vector3(0, -20, 0))
	q.exclude = [p.get_rid(), enemy.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	enemy.global_position = hit.position if not hit.is_empty() else spot
	enemy.velocity = Vector3.ZERO
	var d := Vector3(offset.x, 0, offset.z).normalized()
	(p.get_node("Visual") as Node3D).rotation.y = atan2(d.x, d.z) + 0.3     # a little off: the shot finds it anyway


func _centre(e: Node3D) -> Vector3:
	return e.global_position + Vector3(0, 0.45 * float(e.get("size") if e.get("size") != null else 1.0), 0)


func _look_at(arm: SpringArm3D, target: Vector3) -> void:
	var cam := arm.get_node("Camera3D") as Camera3D
	var d := (target - cam.global_position).normalized()
	arm.rotation = Vector3(asin(d.y), atan2(-d.x, -d.z), 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
