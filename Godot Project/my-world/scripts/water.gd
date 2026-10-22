extends Node3D

# The lake's water (on the Lake node built by tools/build_town.gd). She can wade into the shallows: while her feet
# are under the surface inside the lake's outline she slows down, her steps splash, ripples spread round her and
# splashes fly up as she moves. Jumping in makes a big splash. scenes/player/player.gd reads speed_scale etc.

@export var ellipses: Array[Vector4] = []           # the lake's outline: centre x, centre z, radius x, radius z
@export var water_y := -0.6

var kind := "water"
var speed_scale := 0.6
var gravity_scale := 1.0
var fall_cap := 1000.0

const FEET := 0.8
var _player: CharacterBody3D
var _inside := false
var _fx := 0.0


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	var p := _player.global_position
	var wet := p.y - FEET < water_y and _in_outline(p.x, p.z)
	if wet != _inside:
		_inside = wet
		if wet:
			_player.call("enter_zone", self)
			Audio.play_at("splash", Vector3(p.x, water_y, p.z), -2.0)
			Fx.burst(self, Vector3(p.x, water_y, p.z), Color(0.75, 1.0, 0.85, 0.85), 18, 0.1, 3.0, -8.0, 0.8, 40.0)
		else:
			_player.call("exit_zone", self)
	if not _inside:
		return
	_fx -= delta
	if Vector2(_player.velocity.x, _player.velocity.z).length() > 1.0 and _fx <= 0.0:
		_fx = 0.3
		Fx.ripple(self, Vector3(p.x, water_y + 0.02, p.z))
		Fx.burst(self, Vector3(p.x, water_y + 0.05, p.z), Color(0.8, 1.0, 0.9, 0.8), 5, 0.07, 2.2, -8.0, 0.6, 35.0)


func _in_outline(x: float, z: float) -> bool:
	for e in ellipses:
		var dx := (x - e.x) / e.z
		var dz := (z - e.y) / e.w
		if dx * dx + dz * dz < 1.15:
			return true
	return false


func _exit_tree() -> void:
	if _inside and _player and is_instance_valid(_player):
		_player.call("exit_zone", self)
