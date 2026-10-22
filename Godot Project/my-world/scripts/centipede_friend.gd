extends Node3D

# The centipede at home in the Scary World: curled round its hollow log on the ground, breathing slowly, its pale
# face turning to watch Nina. It looks scary, but it's lonely: talk to it (dialogue/centipede.json) and it turns out
# it only ever wanted a friend. Not an enemy: no collision with Nina, and it never moves at her.
#
# The head is the same one as the thing Behind the Walls in the school (scenes/creatures/centipede.tscn); the body is
# built here, curled along `curl` (points in this node's space, head first).

@export var curl: PackedVector3Array = [Vector3(0, 0, 1.6), Vector3(1.4, 0, 1.2), Vector3(2.2, 0, 0), Vector3(1.9, 0, -1.6),
	Vector3(0.4, 0, -2.4), Vector3(-1.4, 0, -2.0), Vector3(-2.4, 0, -0.6), Vector3(-2.2, 0, 1.0), Vector3(-1.0, 0, 2.4)]
@export var segments := 22
@export var body_color := Color(0.16, 0.1, 0.22)
@export var sheen_color := Color(0.55, 0.3, 0.75)
@export var leg_color := Color(0.5, 0.25, 0.2)
@export var head_height := 1.0

var _head: Node3D
var _segs: Array[Node3D] = []
var _t := 0.0
var _player: Node3D


func _ready() -> void:
	_build_body()
	var scene := load("res://scenes/creatures/centipede.tscn") as PackedScene
	var whole := scene.instantiate()                   # only its head: it never enters the tree, so its script stays idle
	_head = whole.get_node("Head") as Node3D
	whole.remove_child(_head)
	whole.free()
	_head.name = "Head"
	add_child(_head)
	_head.position = curl[0] + Vector3(0, head_height, 0)


func _sample(u: float) -> Vector3:
	# A point along the curl, u from 0 (head end) to 1 (tail)
	var f := u * (curl.size() - 1)
	var i := mini(int(f), curl.size() - 2)
	return curl[i].lerp(curl[i + 1], f - i)


func _build_body() -> void:
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = body_color
	body_m.roughness = 0.35
	body_m.rim_enabled = true
	body_m.rim = 0.6
	body_m.rim_tint = 0.8
	var sheen := StandardMaterial3D.new()
	sheen.albedo_color = sheen_color
	sheen.emission_enabled = true
	sheen.emission = sheen_color
	sheen.emission_energy_multiplier = 0.4
	var leg_m := StandardMaterial3D.new()
	leg_m.albedo_color = leg_color
	for k in segments:
		var u := float(k) / (segments - 1)
		var seg := Node3D.new()
		seg.position = _sample(u)
		var ahead := _sample(maxf(u - 0.02, 0.0))
		var behind := _sample(minf(u + 0.02, 1.0))
		var dir := (ahead - behind)
		seg.rotation.y = atan2(dir.x, dir.z)
		add_child(seg)
		var r := lerpf(0.34, 0.18, u)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.4
		ball.mesh = sm
		ball.material_override = body_m
		ball.position.y = r * 0.7
		seg.add_child(ball)
		var stripe := MeshInstance3D.new()
		var st := SphereMesh.new()
		st.radius = r * 0.35
		st.height = r * 0.35
		stripe.mesh = st
		stripe.material_override = sheen
		stripe.position.y = r * 1.35
		seg.add_child(stripe)
		for side in [-1, 1]:                           # a pair of little legs
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.025
			lm.bottom_radius = 0.02
			lm.height = r + 0.25
			leg.mesh = lm
			leg.material_override = leg_m
			leg.position = Vector3(side * (r + 0.05), r * 0.4, 0)
			leg.rotation.z = side * 1.1
			seg.add_child(leg)
		_segs.append(seg)


func _process(delta: float) -> void:
	_t += delta
	for k in _segs.size():                             # slow breathing ripple down the body
		var s := 1.0 + 0.05 * sin(_t * 1.6 - k * 0.45)
		_segs[k].scale = Vector3(s, s, s)
	if _head == null:
		return
	_head.position.y = curl[0].y + head_height + sin(_t * 1.3) * 0.05
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var want := rotation.y
	if _player and _player.global_position.distance_to(_head.global_position) < 10.0:
		var to := _player.global_position - _head.global_position
		want = atan2(to.x, to.z) - global_rotation.y        # its face looks at her (the head faces +Z)
	else:
		want = atan2(curl[0].x - curl[1].x, curl[0].z - curl[1].z)
	_head.rotation.y = lerp_angle(_head.rotation.y, want, minf(1.0, 3.0 * delta))
