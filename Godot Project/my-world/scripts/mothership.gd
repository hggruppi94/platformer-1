extends Node3D

# The mothership: a big flying saucer cruising over the town (scene built by tools/build_mothership.gd).
#
# On its own it flies a slow, wide loop round the town, banking into the turn and bobbing gently, its rim lights
# chasing round. Nina can fly it too: on the Mothership Pad (scripts/mothership_pad.gd) she calls it with Interact, it
# comes down to hover over the pad and beams her up into the cockpit under the glass dome. Then the move keys fly it
# the way the camera faces, Jump climbs, Roll sinks, and Interact beams her back down to the ground below.
#
# Everything that moves it goes through fly(), which takes a wanted velocity, so the autopilot and Nina steer it the
# same way.

enum State { CRUISING, COMING, BEAMING_UP, PILOTED, BEAMING_DOWN }

@export var autopilot := true                    # cruising round the loop by itself
@export var loop_center := Vector2(0, -60)       # x, z the loop goes round
@export var loop_radius := 140.0
@export var cruise_height := 95.0
@export var cruise_speed := 9.0                  # metres a second
@export var max_speed := 30.0
@export var acceleration := 6.0
@export var turn_rate := 0.8                     # how quickly it swings round to face where it's going

@export_group("Piloting")
@export var pilot_speed := 24.0                  # top speed with Nina at the controls
@export var pilot_accel := 14.0                  # snappier than the autopilot, so it answers the keys
@export var climb_speed := 12.0
@export var hover_height := 24.0                 # how high over the pad it waits to beam her up
@export var beam_time := 1.8                     # seconds to float up (or down) the beam
@export var wait_time := 12.0                    # how long it hovers over the pad before giving up and cruising on
@export var min_altitude := 16.0                 # metres above whatever is under it, so it can't scrape the town
@export var max_altitude := 180.0
@export var bounds := Rect2(-135, -245, 270, 340) # x, z it stays inside (the town's edge walls are at +-146, -256/106)
@export var camera_distance := 55.0              # the camera pulls back this far while flying, to see the whole ship
@export var camera_lift := 9.0                   # ...and looks from this much higher, over the dome at the town ahead

var state := State.CRUISING
var velocity := Vector3.ZERO
var pilot: CharacterBody3D
var _angle := 0.0                                # where it is round the loop
var _t := 0.0
var _lights: Array[MeshInstance3D] = []
var _lit := {}                                   # rim light material -> its full glow
var _pad := Vector3.ZERO                         # the ground spot it was called to
var _wait := 0.0
var _beam_t := 0.0
var _beam_from := Vector3.ZERO
var _beam_to := Vector3.ZERO
var _arm_length := 5.0                           # the camera's normal distance, put back when she gets off
var _arm_tween: Tween
var _boost := 0.0                                # seconds of a sky race's boost ring left (scripts/races.gd)

@onready var hull: Node3D = $Hull
@onready var cockpit: Node3D = $Hull/Cockpit
@onready var beam: MeshInstance3D = $Beam


func _ready() -> void:
	add_to_group("vehicles")
	add_to_group("mothership")
	_angle = atan2(global_position.z - loop_center.y, global_position.x - loop_center.x)
	for l in $Hull/RimLights.get_children():
		var mi := l as MeshInstance3D
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.material_override = m
		_lit[m] = m.emission_energy_multiplier
		_lights.append(mi)
	beam.visible = false


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.CRUISING:
			if autopilot:
				_cruise(delta)
		State.COMING:
			_come(delta)
		State.BEAMING_UP, State.BEAMING_DOWN:
			fly(Vector3.ZERO, delta, pilot_accel)
			_beam(delta)
		State.PILOTED:
			_pilot(delta)
	_animate()


func boost(seconds: float) -> void:
	# A boost ring in the sky race: faster for a moment, past its usual top speed
	_boost = maxf(_boost, seconds)


func boosting() -> bool:
	return _boost > 0.0


func is_piloted() -> bool:
	return state == State.PILOTED


func fly(want: Vector3, delta: float, accel := -1.0) -> void:
	# Ease toward the wanted velocity, turn to face the way it's going, and lean into turns
	want = want.limit_length(max_speed * (1.5 if _boost > 0.0 else 1.0))
	velocity = velocity.move_toward(want, (acceleration if accel < 0.0 else accel) * delta)
	global_position += velocity * delta
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.5:
		var yaw := atan2(flat.x, flat.y)
		var turn := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y += turn * (1.0 - exp(-turn_rate * delta))
		hull.rotation.z = lerpf(hull.rotation.z, clampf(-turn * 0.6, -0.25, 0.25), 1.0 - exp(-2.0 * delta))
	else:
		hull.rotation.z = lerpf(hull.rotation.z, 0.0, 1.0 - exp(-2.0 * delta))     # level out when it stops


func _cruise(delta: float) -> void:
	# Aim a little ahead round the loop, at cruising height
	_angle += cruise_speed / loop_radius * delta
	var ahead := _angle + 0.25
	var goal := Vector3(loop_center.x + cos(ahead) * loop_radius, cruise_height,
		loop_center.y + sin(ahead) * loop_radius)
	fly((goal - global_position).normalized() * cruise_speed, delta)


# -----------------------------------------------------------------------------
# Being called down to the pad and beaming Nina up
# -----------------------------------------------------------------------------
func summon(pad: Vector3) -> bool:
	# Called from the Mothership Pad: come and hover over it. Says no if someone's already flying it.
	if state != State.CRUISING:
		return state == State.COMING and pad.is_equal_approx(_pad)
	state = State.COMING
	_pad = pad
	_wait = wait_time
	return true


func is_coming() -> bool:
	return state == State.COMING


func _come(delta: float) -> void:
	# Head for the spot over the pad, slowing as it gets close so it settles into a hover
	var goal := _pad + Vector3(0, hover_height, 0)
	var to := goal - global_position
	var speed := minf(max_speed, to.length() * 0.7)
	fly(to.normalized() * speed if to.length() > 0.2 else Vector3.ZERO, delta, 12.0)
	if to.length() > 3.0:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and not player.get("carried") and _flat(player.global_position - _pad).length() < 4.0 \
			and absf(player.global_position.y - _pad.y) < 4.0:
		board(player)
		return
	_wait -= delta
	if _wait <= 0.0:                                 # she wandered off: go back to cruising
		_resume_cruise()


func board(player: CharacterBody3D) -> void:
	# The beam comes on and lifts her up into the cockpit
	pilot = player
	if Game.riding:
		Game.toggle_skateboard()                     # step off the skateboard first
	pilot.set("carried", true)
	pilot.set("input_locked", true)
	pilot.velocity = Vector3.ZERO
	pilot.set_meta("save_spot", _pad + Vector3(0, 0.9, 0))   # a save made up here puts her back on the pad
	var anim := pilot.get("anim") as AnimationPlayer
	if anim and anim.has_animation("fall"):
		anim.play("fall")
	_beam_from = pilot.global_position
	_beam_t = 0.0
	state = State.BEAMING_UP
	Audio.play("beam")
	_camera_to(camera_distance)


func _beam(delta: float) -> void:
	_beam_t = minf(_beam_t + delta / beam_time, 1.0)
	var k := smoothstep(0.0, 1.0, _beam_t)
	var seat := _seat_position()
	var from := _beam_from if state == State.BEAMING_UP else seat
	var to := seat if state == State.BEAMING_UP else _beam_to
	if is_instance_valid(pilot):
		pilot.global_position = from.lerp(to, k)
		var visual := pilot.get_node_or_null("Visual") as Node3D
		if visual:
			visual.rotation.y += delta * 2.5         # she turns slowly as she floats
	_show_beam(_ground_under(global_position))
	if _beam_t < 1.0:
		return
	beam.visible = false
	if state == State.BEAMING_UP:
		state = State.PILOTED
		Game.message("You're flying the mothership! %s to fly, %s to go up, %s to go down, %s to beam down." % [
			_move_keys(), Settings.prompt("jump"), Settings.prompt("dash"), Settings.prompt("interact")])
	else:
		_let_off()


# -----------------------------------------------------------------------------
# Flying it
# -----------------------------------------------------------------------------
func _pilot(delta: float) -> void:
	if not is_instance_valid(pilot):
		_resume_cruise()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# The same as Nina's walking: the keys go the way the camera is looking, flattened so looking down doesn't sink it
	var arm := pilot.get_node("SpringArm3D") as Node3D
	var forward := -arm.global_transform.basis.z
	var right := arm.global_transform.basis.x
	forward.y = 0
	right.y = 0
	var dir := right.normalized() * input.x - forward.normalized() * input.y
	var lift := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("dash") else 0.0)
	_boost -= delta
	var top := pilot_speed * (1.6 if _boost > 0.0 else 1.0)
	fly(dir * top + Vector3.UP * lift * climb_speed, delta, pilot_accel * (2.0 if _boost > 0.0 else 1.0))
	_keep_inside()
	_seat()


func _keep_inside() -> void:
	# Stay over the town and between the lowest and highest it may go, stopping (not bouncing) at the edges
	var p := global_position
	var x := clampf(p.x, bounds.position.x, bounds.end.x)
	var z := clampf(p.z, bounds.position.y, bounds.end.y)
	if x != p.x:
		velocity.x = 0.0
	if z != p.z:
		velocity.z = 0.0
	var floor_y := _ground_under(p).y + min_altitude
	var y := clampf(p.y, floor_y, maxf(max_altitude, floor_y))
	if y != p.y:
		velocity.y = 0.0
	global_position = Vector3(x, y, z)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PILOTED and not get_tree().paused and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		beam_down()


func beam_down() -> void:
	# Hover where it is and float her down to the ground right underneath
	if state != State.PILOTED:
		return
	_beam_to = _ground_under(global_position) + Vector3(0, 0.9, 0)
	_beam_t = 0.0
	state = State.BEAMING_DOWN
	Audio.play("beam")


func _let_off() -> void:
	if is_instance_valid(pilot):
		pilot.global_position = _beam_to
		pilot.velocity = Vector3.ZERO
		pilot.set("carried", false)
		pilot.set("input_locked", false)
		pilot.remove_meta("save_spot")
		Audio.play("land")
		_camera_to(_arm_length)
	pilot = null
	_resume_cruise()


func _resume_cruise() -> void:
	# Back to its loop, picking it up from wherever it is now (it climbs back to cruising height on its own)
	state = State.CRUISING
	beam.visible = false
	_angle = atan2(global_position.z - loop_center.y, global_position.x - loop_center.x)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _seat_position() -> Vector3:
	return cockpit.global_position + Vector3(0, 0.8, 0)       # her middle: the cockpit marker is at her feet


func _seat() -> void:
	# Keep her in the cockpit facing the way the ship faces (models face +Z, and so does the ship)
	pilot.global_position = _seat_position()
	var visual := pilot.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.y = global_rotation.y
	var anim := pilot.get("anim") as AnimationPlayer
	if anim and anim.has_animation("idle") and anim.current_animation != "idle":
		anim.play("idle", 0.3)


func _ground_under(p: Vector3) -> Vector3:
	# The first solid thing straight below (the land, a roof, the castle), or sea level if there's nothing
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.DOWN * 4.0, p + Vector3.DOWN * 400.0)
	if pilot:
		q.exclude = [pilot.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else Vector3(p.x, 0.0, p.z)


func _show_beam(ground: Vector3) -> void:
	# A cone of light from the glow underneath down to the ground; the mesh is 1 m tall, so stretch it to fit
	var top := global_position.y - 3.6
	var length := maxf(top - ground.y, 1.0)
	beam.visible = true
	beam.global_position = Vector3(global_position.x, top - length / 2.0, global_position.z)
	beam.scale = Vector3(1, length, 1)
	var m := beam.material_override as StandardMaterial3D
	if m:
		var pulse := 0.5 if Settings.reduce_flashing else 0.5 + 0.5 * sin(_t * 9.0)
		m.albedo_color.a = lerpf(0.22, 0.38, pulse)


func _camera_to(length: float) -> void:
	# Pull the camera back to see the whole saucer while she flies, and in again when she's off
	if not is_instance_valid(pilot):
		return
	var arm := pilot.get_node_or_null("SpringArm3D") as SpringArm3D
	if arm == null or not "boom_length" in arm:
		return
	# The boom's own length and lift (scenes/player/spring_arm_3d.gd), not spring_length: the arm sets that itself
	var out := length > float(arm.get("boom_length")) + 1.0
	if out:
		_arm_length = arm.get("boom_length")
	if _arm_tween:
		_arm_tween.kill()
	_arm_tween = create_tween().set_parallel()
	_arm_tween.tween_property(arm, "boom_length", length, 1.5).set_trans(Tween.TRANS_SINE)
	_arm_tween.tween_property(arm, "lift", camera_lift if out else 0.0, 1.5).set_trans(Tween.TRANS_SINE)


func _move_keys() -> String:
	return Settings.moves()


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _animate() -> void:
	var calm := 0.3 if Settings.reduce_motion else 1.0
	hull.position.y = sin(_t * 0.6) * 0.8 * calm
	# Rim lights chase round the edge (just a soft pulse when flashing is turned down)
	var n := _lights.size()
	for i in n:
		var m := _lights[i].material_override as StandardMaterial3D
		var wave := 0.5 + 0.5 * sin(_t * (1.5 if Settings.reduce_flashing else 5.0) - float(i) / n * TAU * 2.0)
		m.emission_energy_multiplier = _lit[m] * lerpf(0.35, 1.0, wave)
