extends SceneTree

# Checks the skating (scenes/player/skate.gd) in the Practice Park (scenes/skate/test_park.tscn): pushing builds
# speed, a held ollie goes higher than a tap, a halfpipe sends her straight up and back down onto the same ramp, the
# Grind button locks her onto a rail and the end of the rail sends her off it, the balance needle tips her off if
# nobody steers and doesn't if someone does, landing sideways is a bail that does no damage and she gets back up,
# and Y on a controller near a rail doesn't step her off the board.
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
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
