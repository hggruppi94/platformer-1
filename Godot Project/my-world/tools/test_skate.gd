extends SceneTree

# Checks the skating (scenes/player/skate.gd) in the Practice Park (scenes/skate/test_park.tscn): pushing builds
# speed, a held ollie goes higher than a tap, a halfpipe sends her straight up and back down onto the same ramp, the
# Grind button locks her onto a rail and the end of the rail sends her off it, the balance needle tips her off if
# nobody steers and doesn't if someone does, landing sideways is a bail that does no damage and she gets back up,
# and Y on a controller near a rail doesn't step her off the board. Then the tricks (scenes/player/skate_tricks.gd):
# flips, grabs and spins score, a combo multiplies and pays out after landing, the same trick again is worth less,
# landing mid-flip is a bail that loses the combo, manuals link combos, and a full special meter gives the special.
# Then every rider (scripts/rides.gd): each gets their own model, ride and tricks, pushes along and pops, the
# Skaters' Corner swaps who's skating, and stepping off makes you your own hero again.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const PARK := "res://scenes/skate/test_park.tscn"

var failures := 0
var game: Node
var p: CharacterBody3D
var s: Node
var arm: Node3D
var _kept_settings := []


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
	game = root.get_node("Game")
	# These checks are about the strict rules and the Classic buttons (tools/test_skate_help.gd checks the forgiving
	# assists and the Simple layout), whatever the player has picked. Only set here, never saved.
	var settings := root.get_node("Settings")
	_kept_settings = [settings.skate_assist, settings.control_style]
	settings.skate_assist = 2
	settings.control_style = "classic"
	game._resume = {}
	game.pending_message = ""
	var had_board: bool = game.has_item("skateboard")
	change_scene_to_file(PARK)
	await _frames(6)
	var park := current_scene
	p = park.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	arm = p.get_node("SpringArm3D")
	s.rng.seed = 7
	check(game.riding and game.has_item("skateboard"), "she arrives in the Practice Park on her board")
	await _physics(10)
	check(s.state == s.State.ROLL and s._grounded, "...rolling on the ground")

	# --- Pushing ---
	_place(Vector3(-30, 0.9, 38), PI)                 # the open south-west corner, facing north
	Input.action_press("move_forward")
	await _physics(120)
	var speed := _flat(p.velocity)
	check(speed > 7.0 and speed < 10.5, "holding forward pushes her up to speed (%.1f m/s)" % speed)
	Input.action_release("move_forward")
	await _physics(60)
	check(_flat(p.velocity) > speed * 0.85, "...and letting go she glides on (%.1f m/s)" % _flat(p.velocity))

	# --- Ollies: a tap is a hop, a held crouch goes higher ---
	_place(Vector3(-30, 0.9, 38), 0.0)
	await _physics(10)
	var tap := await _ollie(1)
	_place(Vector3(-30, 0.9, 38), 0.0)
	await _physics(10)
	var big := await _ollie(40)
	check(tap > 0.4, "a tap of Jump ollies (%.2f m up)" % tap)
	check(big > tap + 0.5, "...holding it first pops higher (%.2f m)" % big)

	# --- The halfpipe: straight up off the steep top, back down onto the same ramp ---
	_place(Vector3(24, 0.9, -6), PI / 2)              # the flat bottom, facing the east wall
	p.velocity = Vector3(11, 0, 0)
	s._yaw = PI / 2
	var peak := 0.0
	var vert := false
	var max_x := 0.0
	var bails := [0]
	var count_bail := func() -> void: bails[0] += 1
	s.bailed.connect(count_bail)
	for i in 150:
		await physics_frame
		peak = maxf(peak, p.global_position.y)
		max_x = maxf(max_x, p.global_position.x)
		if s._vert:
			vert = true
	check(vert and peak > 4.0, "riding up the halfpipe sends her into a vert air (%.1f m up)" % peak)
	check(max_x < 27.0 + 3.4 + 0.5, "...straight up, not over the top onto the deck")
	check(bails[0] == 0 and s.state == s.State.ROLL and p.global_position.x < 27.5, "...and she lands back on the ramp and rolls down")

	# --- Grinding a rail ---
	var rail := park.find_child("Flat Rail", true, false).get_node("Rail") as GrindRail   # 10 m long, 0.55 m up, along X
	var r0: Vector3 = rail.point_at(0.0)
	_place(r0 + Vector3(1.0, 1.6, 0.0), PI / 2)       # just above it, moving along it
	p.velocity = Vector3(6, -1, 0)
	s._pop()
	Input.action_press("skate_grind")
	await _physics(8)
	Input.action_release("skate_grind")
	check(s.state == s.State.GRIND and s._rail == rail, "pressing Grind over a rail locks her onto it")
	var feet_y := p.global_position.y - 0.8
	check(absf(feet_y - r0.y) < 0.15, "...with her board on top of the rail")
	var start_x := p.global_position.x
	var left := false
	for i in 200:
		await physics_frame
		if s.state != s.State.GRIND:
			left = true
			break
		s.balance = 0.0                                 # hold the needle still: this part is about the rail itself
	check(p.global_position.x > start_x + 7.0, "she slides along the rail (%.1f m)" % (p.global_position.x - start_x))
	check(left and s.state == s.State.AIR, "...and flies off the end of it")
	await _physics(60)
	check(s.state == s.State.ROLL, "...and lands")

	# --- Balance: tips her off if nobody steers, not if someone does ---
	_place(r0 + Vector3(0.5, 1.4, 0.0), PI / 2)
	p.velocity = Vector3(2.5, -1, 0)
	s._pop()
	s._try_grind()
	s._rail_speed = 2.0
	game.hp = game.max_hp
	var fell := false
	for i in 400:
		await physics_frame
		s._rail_offset = 2.0                            # keep her on the rail: just watch the needle
		if s.state == s.State.BAIL:
			fell = true
			break
	check(fell, "left alone, the balance needle tips her off the rail (%.1f s)" % (s._grind_time))
	check(game.hp == game.max_hp, "...and a bail doesn't hurt her")
	await _physics(120)
	check(s.state == s.State.ROLL and p.board.top_level == false, "...she hops back on her board after a moment")
	_place(r0 + Vector3(0.5, 1.4, 0.0), PI / 2)
	p.velocity = Vector3(2.5, -1, 0)
	s._pop()
	s._try_grind()
	var held := true
	for i in 360:                                     # six seconds of steering against the lean
		s._rail_offset = 2.0
		var lean: float = s.balance
		Input.action_release("move_left")
		Input.action_release("move_right")
		if lean > 0.05:
			Input.action_press("move_left")
		elif lean < -0.05:
			Input.action_press("move_right")
		await physics_frame
		if s.state != s.State.GRIND:
			held = false
			break
	Input.action_release("move_left")
	Input.action_release("move_right")
	check(held, "steering against the lean keeps her on for six seconds")
	s._leave_rail(Vector3.ZERO)
	s.state = s.State.AIR
	await _physics(60)

	# --- Landing sideways is a bail ---
	_place(Vector3(-30, 3.0, 30), 0.0)
	p.velocity = Vector3(0, 2, -7)                    # flying north...
	s._pop()
	s._yaw = PI / 2                                   # ...turned sideways
	bails[0] = 0
	await _physics(80)
	check(bails[0] == 1, "landing sideways is a bail")
	_place(Vector3(-30, 3.0, 30), 0.0)
	await _physics(120)
	p.velocity = Vector3(0, 2, -7)
	s._pop()
	s._yaw = PI                                       # facing the way she's flying (north is -Z, yaw PI)
	bails[0] = 0
	await _physics(80)
	check(bails[0] == 0 and s.state == s.State.ROLL, "...landing straight is clean")
	p.velocity = Vector3(0, 2, -7)
	s._pop()
	s._yaw = 0.0                                      # backwards
	await _physics(80)
	check(bails[0] == 0, "...and so is landing backwards (she rides away fakie)")

	# --- Tricks and combos ---
	var t: SkateTricks = s.tricks
	t.lose()
	t.score = 0
	await _big_air()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	check(t.flipping() and t.flip.name == "Kickflip", "Flip in the air with no direction is a kickflip")
	await _until_rolling()
	check(t.combo.size() == 1 and t.combo[0].name == "Kickflip", "...and landing it puts it in the combo")
	await _physics(40)
	check(t.score == 100 and t.combo.is_empty(), "...which pays out a moment after she rolls away (%d points)" % t.score)

	# Two flips and a grab in one air, with a 360: names, a multiplier, and the repeat worth less
	t.score = 0
	await _big_air(true)
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	await _physics(30)
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	await _physics(30)
	Input.action_press("skate_grab")
	await _physics(20)
	check(not t.grab.is_empty() and t.grab.name == "Indy", "holding Grab is a grab")
	Input.action_release("skate_grab")
	s._air_spin = TAU                                 # as if she'd spun all the way round
	s._yaw = s._yaw + TAU
	await _until_rolling()
	var names := t.names()
	check(names == "Kickflip + Kickflip + Indy + 360", "a combo keeps every trick in order (%s)" % names)
	check(t.combo[1].points == 50, "...the second kickflip is worth half")
	var expect := (100 + 50 + int(t.combo[2].points) + 250) * 4
	await _physics(40)
	check(t.score == expect, "...and it pays out its points times 4 tricks (%d)" % t.score)

	# Landing in the middle of a flip is a bail, and the combo's lost
	t.score = 0
	await _big_air()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	await _physics(30)
	p.global_position.y = 1.4                         # suddenly right over the ground...
	p.velocity.y = -3.0
	Input.action_press("skate_flip")                  # ...flipping again, with no time to finish it
	await _physics(2)
	Input.action_release("skate_flip")
	bails[0] = 0
	await _physics(60)
	check(bails[0] == 1 and t.score == 0, "landing in the middle of a flip is a bail, and the combo's gone")
	await _physics(100)

	# A grind links into the combo
	t.score = 0
	_place(r0 + Vector3(1.0, 2.8, 0.0), PI / 2)
	p.velocity = Vector3(6, 3, 0)
	s._pop()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	await _physics(30)
	p.global_position = r0 + Vector3(3.0, 1.3, 0.0)   # coming down over the rail
	p.velocity = Vector3(6, -2, 0)
	s._try_grind()
	check(s.state == s.State.GRIND and t.live.get("name", "") == "50-50", "grinding with no direction is a 50-50")
	for i in 40:
		s.balance = 0.0
		await physics_frame
	check(t.names() == "Kickflip + 50-50" and t.multiplier() == 2, "...and it joins the kickflip in one combo")
	s._rail_offset = rail.length() - 0.1
	await _until_rolling()
	await _physics(40)
	check(t.score > (100 + 50) * 2, "...which pays out together (%d)" % t.score)

	# Manuals: forward then back quickly while rolling
	t.score = 0
	_place(Vector3(-30, 0.9, 40), PI)
	p.velocity = Vector3(0, 0, -6)
	await _physics(5)
	Input.action_press("move_forward")
	await _physics(3)
	Input.action_release("move_forward")
	Input.action_press("move_back")
	await _physics(3)
	Input.action_release("move_back")
	check(s._manual == 1 and t.live.name == "Manual", "forward then back quickly starts a manual")
	await _physics(30)
	s.balance = 0.0
	check(s.state == s.State.ROLL and s._manual == 1 and s.balancing(), "...she balances along on two wheels")
	Input.action_press("jump")
	await _physics(1)
	Input.action_release("jump")
	await _physics(5)
	check(s.state == s.State.AIR and t.names().begins_with("Manual"), "...and an ollie out of it keeps the combo going")
	await _until_rolling()
	await _physics(60)
	check(t.score > 0, "...which pays out after the landing (%d)" % t.score)

	# The special: a full meter, then Flip and Grab together
	t.special = 1.0
	await _big_air()
	Input.action_press("skate_flip")
	Input.action_press("skate_grab")
	await _physics(2)
	Input.action_release("skate_flip")
	Input.action_release("skate_grab")
	check(t.flipping() and t.flip.name == "Galaxy Twirl" and t.special == 0.0, "a full special meter and Flip + Grab together: the Galaxy Twirl")
	await _until_rolling()
	await _physics(40)
	check(t.best_combo >= 1000, "...worth a thousand points")

	# --- Y on a controller near a rail grinds, it doesn't step her off ---
	_place(r0 + Vector3(2.0, 0.0, 0.6), PI / 2)
	p.global_position.y = 0.85
	p.velocity = Vector3.ZERO
	await _physics(10)
	await _pad_press(JOY_BUTTON_Y)
	check(game.riding, "Y on a controller next to a rail doesn't step her off the board")
	if s.state == s.State.GRIND:
		s._leave_rail(Vector3.ZERO)
		s.state = s.State.AIR
	await _physics(60)
	_place(Vector3(-30, 0.9, 38), 0.0)
	await _physics(20)
	await _press("toggle_skateboard")
	check(not game.riding and p.motion_mode == CharacterBody3D.MOTION_MODE_GROUNDED, "out in the open, the board key steps her off")
	await _press("toggle_skateboard")
	check(game.riding, "...and back on")

	# --- Everyone rides ---
	var corner := park.find_child("RiderSelect", true, false) as Area3D
	check(corner != null, "the Practice Park has a Skaters' Corner")
	for id in Rides.ORDER:
		p.set_rider(id)
		await _physics(2)
		var r := Rides.ride(id)
		var model := p.get("model") as Node3D
		var ride_node := p.get_node("Visual/Skateboard") as Node3D
		var ok_model: bool = model != null and model.scene_file_path == r.model
		var ok_ride: bool = ride_node.get_child_count() > 0 and ride_node.visible
		check(ok_model and ok_ride and s.ride.rider == r.rider and game.riding,
			"%s rides: %s" % [r.rider, r.name])
		_place(Vector3(-30, 0.9, 38), PI)
		Input.action_press("move_forward")
		await _physics(150)
		Input.action_release("move_forward")
		var sp := _flat(p.velocity)
		var base_y := p.global_position.y
		Input.action_press("jump")
		await _physics(1)
		Input.action_release("jump")
		var top := base_y
		for i in 40:
			await physics_frame
			top = maxf(top, p.global_position.y)
		check(sp > float(r.push_speed) * 0.8 and top > base_y + 0.4,
			"...pushes along (%.1f m/s) and pops (%.2f m)" % [sp, top - base_y])
		await _until_rolling()
		await _big_air()
		Input.action_press("skate_flip")
		await _physics(2)
		Input.action_release("skate_flip")
		check(t.flipping() and t.flip.name == r.tricks.flips[""][0], "...with their own tricks (%s)" % t.flip.get("name", "none"))
		await _until_rolling()
		await _physics(40)
		check(s.state == s.State.ROLL, "...and lands it")
	# Pip glides down slowly while Jump is held
	p.set_rider("pip")
	await _big_air()
	Input.action_press("jump")
	var slowest := 0.0
	for i in 90:
		await physics_frame
		slowest = minf(slowest, p.velocity.y)
	Input.action_release("jump")
	check(slowest > -3.0, "Pip glides down gently while Jump is held (falling at most %.1f m/s)" % -slowest)
	await _until_rolling()
	# The Skaters' Corner: Interact there swaps to the next skater
	p.set_rider("nina")
	await _physics(2)
	_place(corner.global_position + Vector3(0, 0.2, 0), PI)
	await _physics(10)
	await _press("interact")
	check(p.get("rider") == "dash", "Interact at the Skaters' Corner swaps Nina for Dash")
	# Stepping off makes you your own hero again
	_place(Vector3(-30, 0.9, 38), PI)
	await _physics(20)
	await _press("toggle_skateboard")
	check(not game.riding and p.get("rider") == "hero" and (p.get("model") as Node3D).name == "Hero",
		"stepping off the ride makes you your own hero again, on foot")
	await _press("toggle_skateboard")
	check(game.riding and s.ride.rider == Hero.display_name(game.hero), "...and back on, it's their own board")
	if not had_board:
		game.items.erase("skateboard")
	_end()


func _place(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	s._yaw = yaw
	if s.state == s.State.BAIL:
		s._end_bail()
	s.state = s.State.ROLL
	arm.rotation.y = yaw + PI                         # camera behind her


func _ollie(hold_frames: int) -> float:
	var base := p.global_position.y
	Input.action_press("jump")
	await _physics(hold_frames)
	Input.action_release("jump")
	var top := base
	for i in 90:
		await physics_frame
		top = maxf(top, p.global_position.y)
	return top - base


func _big_air(slow := false) -> void:
	# Up high over the open south-west corner, flying north, facing the way she's going
	_place(Vector3(-30, 6.0, 38), PI)
	p.velocity = Vector3(0, 8, -3 if slow else -6)
	s._pop()
	await _physics(2)


func _until_rolling() -> void:
	for i in 300:
		if s.state == s.State.ROLL:
			return
		await physics_frame


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _pad_press(button: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button as JoyButton
	e.pressed = true
	Input.parse_input_event(e)
	await _physics(3)
	var r := InputEventJoypadButton.new()
	r.button_index = button as JoyButton
	r.pressed = false
	Input.parse_input_event(r)
	await _physics(3)


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
	if not _kept_settings.is_empty():
		root.get_node("Settings").skate_assist = _kept_settings[0]
		root.get_node("Settings").control_style = _kept_settings[1]
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
