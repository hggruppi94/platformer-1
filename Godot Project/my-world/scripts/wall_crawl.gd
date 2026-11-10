extends Node

# Wall crawl, the player's own: the lonely centipede's gift once Dark Hollow is mended (scripts/dark_hollow.gd). Hayden
# picked it on 10 Nov 2026 ("Both": wall crawl as her ability, and her gulp as a way to get about, which is
# scripts/centipede_holes.gd). She scuttles up the walls and along the ceilings of the Sliver, and now so can you.
#
# No button (every pad button's taken, and it's kinder for small hands), like Pip's glow and the Spring Step:
#   - Keep walking into a wall for a moment (GRAB_HOLD) and you start up it; jump at one and you catch on at once.
#   - On a wall, push towards it to climb, away from it to climb down, and sideways to scuttle along it. Round inside
#     corners you follow the new wall. At the top you pull yourself over.
#   - Climb up into a ceiling and you carry on along it upside down, steering as on the ground. Where it runs out you
#     drop.
#   - Jump hops you off (back from a wall; down from a ceiling), Roll just lets go, and getting bumped knocks you off.
# Invisible edge-of-the-world walls can't be climbed (CLIMB_NOT, group "no_climb"), nor anything that moves.
#
# Made by the player (scenes/player/player.gd _ready), which hands its physics over to physics() while active.

const WORLD := "dark_hollow"              # the world whose mending unlocks it
const GRAB_HOLD := 0.22                   # seconds of walking into a wall on the ground before you start up it
const REGRAB := 0.4                       # after letting go, this long before you catch on again
const REACH := 0.75                       # from her middle, how far a wall can be to catch on (her radius is 0.35)
const CLIMB := 4.2                        # metres a second up, down and along a wall
const CEILING_SPEED := 4.6                # ...and along a ceiling
const ACCEL := 22.0
const STICK := 1.5                        # a little push into the surface so she stays on it
const STEEP := 0.35                       # a surface counts as a wall when its normal's y is within this of 0
const HANG := 0.86                        # her middle hangs this far under a ceiling
const HOP_OFF := 5.0                      # hopping back off a wall
const MANTLE_UP := 6.2                    # pulling herself over the top
const MANTLE_ON := 3.2
const CLIMB_NOT := ["WorldBounds", "Edge", "Fence", "Garden Wall"]   # names of invisible walls round the worlds
const TICK_EVERY := 0.16

enum Mode { WALL, CEILING }

var player: CharacterBody3D
var active := false
var mode := Mode.WALL
var normal := Vector3.BACK                # the surface she's on, pointing out at her
var climbed := 0.0                        # (for the tests: metres climbed so far)
var crawls := 0                           # (for the tests: times she's caught on)
var _push := 0.0                          # how long she's walked into a wall on the ground
var _regrab := 0.0
var _tick := 0.0
var _vel := Vector3.ZERO


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func _space() -> PhysicsDirectSpaceState3D:
	return player.get_world_3d().direct_space_state


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	q.collide_with_areas = false
	return _space().intersect_ray(q)


static func climbable(collider: Object) -> bool:
	# Only still, solid things that are really there: not the invisible walls round a world, not anyone moving about
	if collider == null or not (collider is StaticBody3D or collider is CSGShape3D):
		return false
	if collider is AnimatableBody3D:
		return false
	var n := collider as Node
	while n != null:
		if n.is_in_group("no_climb"):
			return false
		for bit in CLIMB_NOT:
			if String(n.name).begins_with(bit):
				return false
		n = n.get_parent()
	return true


func _wall_hit(from: Vector3, dir: Vector3, reach := REACH) -> Dictionary:
	# A wall straight ahead of `from` along dir (flat), or {}
	var hit := _ray(from, from + dir * reach)
	if hit.is_empty():
		return {}
	var n: Vector3 = hit.normal
	if absf(n.y) > STEEP or not climbable(hit.collider):
		return {}
	return hit


func _input_dir() -> Vector3:
	# The stick, camera-relative and flat, as on foot
	if player.input_locked:
		return Vector3.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var b: Basis = player.spring_arm.global_transform.basis
	var forward := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var right := Vector3(b.x.x, 0, b.x.z).normalized()
	return right * v.x - forward * v.y


func _can() -> bool:
	if player == null or not unlocked() or Game.riding or player.carried or player.input_locked:
		return false
	if player.burrow and player.burrow.active or player.swim and player.swim.active:
		return false
	if player.popper and player.popper.aiming:
		return false
	return float(player.get("_stun_timer")) <= 0.0


func check(delta: float) -> bool:
	# Called by the player every physics frame on foot: should she catch onto a wall? Starts it if so.
	_regrab -= delta
	if _regrab > 0.0 or not _can():
		_push = 0.0
		return false
	var dir := _input_dir()
	if dir.length() < 0.5:
		_push = 0.0
		return false
	dir = dir.normalized()
	var hit := _wall_hit(player.global_position + Vector3(0, 0.25, 0), dir)
	if hit.is_empty() or dir.dot(-(hit.normal as Vector3)) < 0.6:
		_push = 0.0
		return false
	if player.is_on_floor():
		_push += delta
		if _push < GRAB_HOLD:
			return false
	_push = 0.0
	start(hit.normal)
	return true


func start(n: Vector3, on_ceiling := false) -> void:
	active = true
	crawls += 1
	mode = Mode.CEILING if on_ceiling else Mode.WALL
	normal = Vector3(n.x, 0, n.z).normalized() if not on_ceiling else Vector3.DOWN
	_vel = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.sprinting = false
	if player.has_method("_end_roll"):
		player.call("_end_roll")
	Audio.play_at("step_stone", player.global_position, -6.0, 0.2)
	Juice.blip("tick", 1.4, -12.0)


func stop(push := Vector3.ZERO) -> void:
	if not active:
		return
	active = false
	_regrab = REGRAB
	player.velocity = push
	player.set("_air_jump_used", false)          # a free double jump on the way off, like on landing


func physics(delta: float) -> void:
	# Her physics while she's crawling. The player calls this instead of its own walking.
	if not _can() and not player.input_locked:
		stop()
		return
	if not player.input_locked:
		if Input.is_action_just_pressed("jump"):
			if mode == Mode.WALL:
				stop(normal * HOP_OFF + Vector3.UP * player.jump_velocity * 0.8)
			else:
				stop(Vector3.DOWN * 1.0)
			Audio.play("jump", -4.0)
			return
		if Input.is_action_just_pressed("dash"):
			stop()
			return
	if mode == Mode.WALL:
		_on_wall(delta)
	else:
		_on_ceiling(delta)
	if active:
		_look(delta)


func _on_wall(delta: float) -> void:
	var dir := _input_dir()
	var into := -normal
	var up_amt := dir.dot(into)                                 # towards the wall: up; away: down
	var side := dir - into * up_amt
	var want := (Vector3.UP * up_amt + side) * CLIMB
	if want.length() > CLIMB:
		want = want.normalized() * CLIMB
	_vel = _vel.move_toward(want, ACCEL * delta)
	player.velocity = _vel + into * STICK
	var before := player.global_position.y
	player.move_and_slide()
	climbed += maxf(0.0, player.global_position.y - before)
	# Round an inside corner: a wall she's bumped into sideways becomes the one she's on
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		var cn := c.get_normal()
		if absf(cn.y) <= STEEP and cn.dot(normal) < 0.8 and climbable(c.get_collider()) and side.dot(-cn) > 0.3:
			normal = Vector3(cn.x, 0, cn.z).normalized()
			break
	var p := player.global_position
	# Up into a ceiling: carry on along it, upside down
	if _vel.y > 0.5:
		var top := _ray(p, p + Vector3.UP * (HANG + 0.25))
		if not top.is_empty() and (top.normal as Vector3).y < -0.6 and climbable(top.collider):
			mode = Mode.CEILING
			normal = Vector3.DOWN
			_vel = Vector3.ZERO
			Juice.blip("tick", 1.6, -12.0)
			return
	# Down onto the floor: back on her feet
	if _vel.y < -0.2 and player.is_on_floor():
		stop()
		return
	# Still on the wall? Follow its face as it curves (castle towers, cave walls)
	var mid := _wall_hit(p + Vector3(0, 0.25, 0), into)
	if not mid.is_empty():
		var nn: Vector3 = mid.normal
		normal = normal.slerp(Vector3(nn.x, 0, nn.z).normalized(), 0.5).normalized()
		return
	var low := _wall_hit(p + Vector3(0, -0.55, 0), into)
	if not low.is_empty() and _vel.y >= -0.1:
		# Her middle's past the top but her feet aren't: pull herself up and over
		stop(Vector3.UP * MANTLE_UP + into * MANTLE_ON)
		Juice.squash(player.model, -0.15, 0.2)
		return
	stop()                                                      # the wall ran out round a corner: off she drops


func _on_ceiling(delta: float) -> void:
	var dir := _input_dir()
	_vel = _vel.move_toward(dir * CEILING_SPEED, ACCEL * delta)
	player.velocity = Vector3(_vel.x, STICK, _vel.z)
	player.move_and_slide()
	var p := player.global_position
	var top := _ray(p, p + Vector3.UP * (HANG + 0.4))
	if top.is_empty() or (top.normal as Vector3).y > -0.6 or not climbable(top.collider):
		stop(Vector3(_vel.x, 0, _vel.z) * 0.5)                  # the ceiling's run out: drop
		return
	var hy: float = (top.position as Vector3).y - HANG
	if absf(p.y - hy) > 0.02:
		player.global_position.y = move_toward(p.y, hy, 4.0 * delta)


func _look(delta: float) -> void:
	# Facing the wall and leaning into it, or hanging upside down from the ceiling; little ticks as her feet go
	var k := 1.0 - exp(-12.0 * delta)
	var tumble: Node3D = player.tumble
	var going := _vel.length()
	if mode == Mode.WALL:
		player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(-normal.x, -normal.z), k)
		tumble.rotation.x = lerp_angle(tumble.rotation.x, 0.22, k)
		tumble.rotation.z = lerp_angle(tumble.rotation.z, 0.0, k)
	else:
		if Vector2(_vel.x, _vel.z).length() > 0.3:
			player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(_vel.x, _vel.z), k)
		tumble.rotation.x = lerp_angle(tumble.rotation.x, 0.0, k)
		tumble.rotation.z = lerp_angle(tumble.rotation.z, PI, k)
	tumble.scale = tumble.scale.lerp(Vector3.ONE, k)
	tumble.position.y = lerpf(tumble.position.y, 0.0, k)
	var anim: AnimationPlayer = player.anim
	if anim:
		var target := "run" if going > 0.4 else "idle"
		if anim.assigned_animation != target:
			anim.play(target, 0.2)
		anim.speed_scale = clampf(going / CLIMB, 0.5, 1.4) * 1.3 if target == "run" else 0.8
	_tick -= delta
	if going > 0.6 and _tick <= 0.0:
		_tick = TICK_EVERY
		Audio.play_at("step_stone", player.global_position, -16.0, 0.3)
	RenderingServer.global_shader_parameter_set("nina_pos", player.global_position)


func _process(delta: float) -> void:
	# Off a ceiling, she turns the right way up again (the player only eases her somersault axis back)
	if active or player == null:
		return
	var t: Node3D = player.tumble
	if absf(t.rotation.z) > 0.001:
		t.rotation.z = lerp_angle(t.rotation.z, 0.0, 1.0 - exp(-14.0 * delta))
		if absf(t.rotation.z) < 0.01:
			t.rotation.z = 0.0
