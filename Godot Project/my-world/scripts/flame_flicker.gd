extends Node

# A flame inside a lantern, a cage or a shade (scripts/fire_fx.gd puts one under it instead of a pixel flame, which
# would poke out through the top): the flame's shape breathes a little bigger and smaller and its light brightens and
# dims with it, on two wobbles that never quite repeat. It only nudges what's there by the change since last frame,
# so the game can still dim a light or hide the flame as before. Nothing happens out of sight or far away.

var far := 45.0               # nothing happens further than this from the camera
const SIZE := 0.1               # the flame grows and shrinks by up to this much (a tenth)
const GLOW := 0.18              # its light by up to this much

var flame: Node3D               # the shape that burns
var lights: Array[Light3D] = []
var _size := 1.0
var _glow := 1.0
var _t := 0.0


func _ready() -> void:
	_t = randf() * 50.0
	var group := get_parent().get_parent()
	if group == null or flame == null:
		return
	var at := flame.global_position
	for c in group.find_children("*", "Light3D", true, false):
		if (c as Light3D).global_position.distance_to(at) < 1.5:
			lights.append(c)


func _process(delta: float) -> void:
	if flame == null or not is_instance_valid(flame) or not flame.is_visible_in_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(flame.global_position) > far:
		return
	_t += delta
	var wob := sin(_t * 9.1) * 0.5 + sin(_t * 14.3 + 1.7) * 0.3 + sin(_t * 23.0 + 0.4) * 0.2
	var size := 1.0 + wob * SIZE
	var glow := 1.0 + wob * GLOW
	var r := size / _size
	flame.scale *= Vector3(sqrt(r), r, sqrt(r))
	for l in lights:
		if is_instance_valid(l):
			l.light_energy *= glow / _glow
	_size = size
	_glow = glow
