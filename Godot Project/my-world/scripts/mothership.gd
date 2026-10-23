extends Node3D

# The mothership: a big flying saucer cruising over the town (scene built by tools/build_mothership.gd).
#
# For now it flies itself: a slow, wide loop round the town, banking into the turn and bobbing gently, its rim lights
# chasing round. Everything that moves it goes through fly(), which takes a wanted velocity, so a pilot (Nina, later)
# can steer it by switching autopilot off and calling fly() with her controls instead.

@export var autopilot := true
@export var loop_center := Vector2(0, -60)       # x, z the loop goes round
@export var loop_radius := 140.0
@export var cruise_height := 95.0
@export var cruise_speed := 9.0                  # metres a second
@export var max_speed := 30.0
@export var acceleration := 6.0
@export var turn_rate := 0.8                     # how quickly it swings round to face where it's going

var velocity := Vector3.ZERO
var _angle := 0.0                                # where it is round the loop
var _t := 0.0
var _lights: Array[MeshInstance3D] = []
var _lit := {}                                   # rim light material -> its full glow

@onready var hull: Node3D = $Hull


func _ready() -> void:
	add_to_group("vehicles")
	_angle = atan2(global_position.z - loop_center.y, global_position.x - loop_center.x)
	for l in $Hull/RimLights.get_children():
		var mi := l as MeshInstance3D
		var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.material_override = m
		_lit[m] = m.emission_energy_multiplier
		_lights.append(mi)


func _process(delta: float) -> void:
	_t += delta
	if autopilot:
		# Aim a little ahead round the loop, at cruising height
		_angle += cruise_speed / loop_radius * delta
		var ahead := _angle + 0.25
		var goal := Vector3(loop_center.x + cos(ahead) * loop_radius, cruise_height,
			loop_center.y + sin(ahead) * loop_radius)
		fly((goal - global_position).normalized() * cruise_speed, delta)
	_animate()


func fly(want: Vector3, delta: float) -> void:
	# Ease toward the wanted velocity, turn to face the way it's going, and lean into turns
	want = want.limit_length(max_speed)
	velocity = velocity.move_toward(want, acceleration * delta)
	global_position += velocity * delta
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.5:
		var yaw := atan2(flat.x, flat.y)
		var turn := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y += turn * (1.0 - exp(-turn_rate * delta))
		hull.rotation.z = lerpf(hull.rotation.z, clampf(-turn * 0.6, -0.25, 0.25), 1.0 - exp(-2.0 * delta))


func _animate() -> void:
	var calm := 0.3 if Settings.reduce_motion else 1.0
	hull.position.y = sin(_t * 0.6) * 0.8 * calm
	# Rim lights chase round the edge (just a soft pulse when flashing is turned down)
	var n := _lights.size()
	for i in n:
		var m := _lights[i].material_override as StandardMaterial3D
		var wave := 0.5 + 0.5 * sin(_t * (1.5 if Settings.reduce_flashing else 5.0) - float(i) / n * TAU * 2.0)
		m.emission_energy_multiplier = _lit[m] * lerpf(0.35, 1.0, wave)
