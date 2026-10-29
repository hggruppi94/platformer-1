extends Node3D

# Tally, the little alien with a clipboard who walks round the Market Square and looks after the request board
# (scripts/requests.gd). The tall curious yellow one of the little aliens (models/characters/little_alien_yellow.glb),
# a bit bigger than the crowd so they read as someone to talk to, holding a clipboard with a pencil. They amble round
# a ring between the benches and the stalls, stop now and then to tick something off, and stop and face the player
# to talk (the same talk as the board: scripts/request_spot.gd).

const MODEL := "res://models/characters/little_alien_yellow.glb"
const RING := 9.0                         # metres from the fountain: clear of the benches (6) and the stalls (12)
const SPEED := 0.9
const SIZE := 1.6

var centre := Vector3.ZERO
var talking := false
var _angle := 0.0
var _dir := 1.0
var _pause := 2.0
var _model: Node3D
var _anim: AnimationPlayer
var _player: Node3D


func _ready() -> void:
	_angle = randf() * TAU
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in ["idle", "walk", "wave"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	LittleAliens.vary_snout(_model)
	_clipboard()
	var name_label := Label3D.new()
	name_label.text = "Tally"
	name_label.font_size = 26
	name_label.pixel_size = 0.01
	name_label.outline_size = 10
	name_label.outline_modulate = Color(0.15, 0.08, 0.2)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position.y = 1.3
	add_child(name_label)
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = "Request Talk"
	spot.set("verb", "talk to Tally")
	spot.set("radius", 2.2)
	add_child(spot)
	global_position = _ring_point(_angle)
	_play("idle")


func _clipboard() -> void:
	# A lilac clipboard with a sheet of paper, a gold clip and a pencil, held in front in both hands
	var board := Node3D.new()
	board.name = "Clipboard"
	board.position = Vector3(0, 0.36, 0.26)
	board.scale = Vector3.ONE * 0.8
	board.rotation.x = -0.6
	add_child(board)
	_part(board, Vector3(0.28, 0.36, 0.02), Vector3.ZERO, Color(0.62, 0.5, 0.95))
	_part(board, Vector3(0.24, 0.3, 0.005), Vector3(0, -0.01, 0.013), Color(0.98, 0.96, 0.9))
	_part(board, Vector3(0.12, 0.04, 0.03), Vector3(0, 0.17, 0.015), Color(1.0, 0.82, 0.35))
	for k in 3:                                                        # ticked lines on the paper
		_part(board, Vector3(0.15, 0.012, 0.006), Vector3(0.03, 0.08 - k * 0.07, 0.017), Color(0.4, 0.35, 0.6))
		_part(board, Vector3(0.025, 0.025, 0.006), Vector3(-0.08, 0.08 - k * 0.07, 0.017), Color(0.4, 0.9, 0.6))
	var pencil := _part(board, Vector3(0.012, 0.2, 0.012), Vector3(0.16, -0.02, 0.03), Color(1.0, 0.75, 0.3))
	pencil.rotation.z = 0.5


func _part(parent: Node3D, size: Vector3, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _ring_point(a: float) -> Vector3:
	return centre + Vector3(cos(a), 0, sin(a)) * RING


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if talking:
		_face(_player.global_position if _player else global_position + basis.z, delta)
		_play("idle")
		return
	if _pause > 0.0:
		_pause -= delta
		_play("idle")
		if _pause <= 0.0 and randf() < 0.25:
			_dir = -_dir                                               # sometimes turns back the way they came
		return
	_angle += _dir * SPEED * delta / RING
	var next := _ring_point(_angle)
	_face(next, delta)
	global_position = next
	_play("walk")
	if randf() < delta / 7.0:
		_pause = randf_range(1.5, 3.5)                                 # stop to tick something off


func _face(to: Vector3, delta: float) -> void:
	var d := to - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), minf(1.0, 8.0 * delta))


func _play(a: String) -> void:
	if _anim and _anim.has_animation(a) and _anim.current_animation != a:
		_anim.play(a, 0.25)


func begin_talk() -> void:
	talking = true


func end_talk() -> void:
	talking = false
	_pause = 1.0
