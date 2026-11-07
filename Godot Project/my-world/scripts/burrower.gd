extends Node

# The plant girl's way of getting about (Hayden: "plant girl grows in and out of the ground to move around"): put one
# under her (scenes/town/characters.tscn, next to her Routine). Her routine (scripts/routine.gd) moves her body as
# usual; this only changes how it looks. When she starts to move she dives into the ground (a puff of soil, her
# "burrow" animation, her model sinking out of sight), a little mound of soil with a sprig on top travels along
# where she is, and when she stops she sprouts back up (another puff, her "sprout" animation, a springy pop) and
# carries on with whatever she's doing. When the routine simply puts her somewhere new (sleeping, loading, nobody
# watching) she sprouts up there too.
#
# It never moves the body itself, so routines, talking and tests treat her like anyone else.

const DEPTH := 2.3                       # metres her model sinks: the antlers' tips go under too
const SINK_TIME := 0.55
const RISE_TIME := 0.5
const START_MOVING := 0.05               # metres a frame's worth of movement has to add up to before she dives
const STOPPED_FOR := 0.25                # seconds without moving before she comes up
const JUMP := 3.0                        # metres in one frame: she was put somewhere, not moving there
const SOIL := Color(0.36, 0.24, 0.16)

enum { UP, SINKING, UNDER, RISING }

var state := UP
var _body: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _mound: Node3D
var _last := Vector3.ZERO
var _moved := 0.0                        # how far she's gone since she last stood still
var _still := 0.0                        # how long she's stood still
var _t := 0.0                            # time into a sink or a rise


func _ready() -> void:
	_body = get_parent() as Node3D
	_model = _body.get_node_or_null("Model") as Node3D
	_anim = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_last = _body.global_position
	_mound = _make_mound()
	_mound.visible = false
	_body.add_child.call_deferred(_mound)


func is_under() -> bool:
	return state == SINKING or state == UNDER


func _physics_process(delta: float) -> void:
	if _model == null:
		return
	var now := _body.global_position
	var step := Vector2(now.x - _last.x, now.z - _last.z).length()
	_last = now
	if step > JUMP:                                     # put somewhere new: pop up there
		_moved = 0.0
		_still = 0.0
		if _body.is_visible_in_tree():
			_rise()
		return
	if step > 0.0005:
		_moved += step
		_still = 0.0
	else:
		_still += delta
		if _still > STOPPED_FOR:
			_moved = 0.0
	match state:
		UP:
			if _moved > START_MOVING:
				_sink()
		SINKING:
			_t += delta
			var k := minf(_t / SINK_TIME, 1.0)
			_model.position.y = -DEPTH * k * k                     # slow at first, then down she goes
			_mound.scale = Vector3.ONE * maxf(k, 0.05)
			if k >= 1.0:
				state = UNDER
				_model.visible = false
				_play("under")
		UNDER:
			_mound.rotation.y += delta * 2.0                       # the sprig on top wiggles round as she goes
			if _still > STOPPED_FOR:
				_rise()
		RISING:
			_t += delta
			var k := minf(_t / RISE_TIME, 1.0)
			var back := 1.70158                                    # ease out with a little overshoot: a springy pop
			var e := 1.0 + (back + 1.0) * pow(k - 1.0, 3) + back * pow(k - 1.0, 2)
			_model.position.y = -DEPTH * (1.0 - e)
			_mound.scale = Vector3.ONE * maxf(1.0 - k, 0.05)
			if k >= 1.0:
				state = UP
				_model.position.y = 0.0
				_mound.visible = false
				_play("idle")
			elif _moved > START_MOVING and _t > 0.15:               # off again before she was all the way up
				_sink()


func _sink() -> void:
	state = SINKING
	_t = 0.0
	_model.visible = true
	_mound.visible = true
	_play("burrow")
	_puff()


func _rise() -> void:
	state = RISING
	_t = 0.0
	_model.visible = true
	_model.position.y = -DEPTH
	_mound.visible = true
	_play("sprout")
	_puff()


func _play(anim: String) -> void:
	if _anim and _anim.has_animation(anim):
		_anim.play(anim, 0.1)


func _puff() -> void:
	var juice := get_node_or_null("/root/Juice")
	if juice and _body.is_inside_tree():
		juice.call("dust", _body.get_parent(), _body.global_position, 0.6, SOIL)


func _make_mound() -> Node3D:
	# A little hump of soil with a curly green sprig poking out of it, which is all you see of her underground
	var g := Node3D.new()
	g.name = "Mound"
	var soil := StandardMaterial3D.new()
	soil.albedo_color = SOIL
	soil.roughness = 1.0
	var hump := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	s.radial_segments = 12
	s.rings = 6
	hump.mesh = s
	hump.material_override = soil
	hump.scale = Vector3(1.0, 0.3, 1.0)
	g.add_child(hump)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.35, 0.7, 0.2)
	for k in 3:
		var sprig := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.035
		c.height = 0.32
		c.radial_segments = 6
		sprig.mesh = c
		sprig.material_override = leaf
		sprig.position = Vector3(0, 0.25, 0)
		sprig.rotation = Vector3(0.45, k * TAU / 3, 0)
		g.add_child(sprig)
	for k in 4:                                            # a few crumbs round the edge
		var crumb := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.07
		b.height = 0.12
		crumb.mesh = b
		crumb.material_override = soil
		crumb.position = Vector3(cos(k * 1.7) * 0.5, 0.02, sin(k * 1.7) * 0.5)
		g.add_child(crumb)
	return g
