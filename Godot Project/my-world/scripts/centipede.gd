extends Node3D
class_name Centipede

# The thing Behind the Walls: a long centipede with a human head that crawls along the ceiling.
# For now it is NOT a threat. It stalks Nina from overhead, lowers its head on a long neck to stare at her and
# whispers, and recoils if she gets right up to its face. It has no collision, so it can never block the passage.
#
# Later it becomes an enemy: flip `hostile` on and fill in _hunt() (see the bottom of this file).
#
# Scene: scenes/creatures/centipede.tscn (the Head is built by tools/build_centipede.gd); the body is built here
# at runtime so segment count and size stay tweakable. The crawl route is a closed loop of `route` points, in the
# parent's space, at ceiling height.

@export_group("Body")
@export var segment_count := 26
@export var spacing := 0.4                  # metres between segments along the route
@export var neck_count := 12                # front segments that bend down when it lowers its head
@export var body_color := Color(0.09, 0.06, 0.11)
@export var sheen_color := Color(0.45, 0.2, 0.6)
@export var leg_color := Color(0.42, 0.16, 0.12)

@export_group("Behaviour")
@export var route: PackedVector3Array       # closed loop along the ceiling, parent space
@export var territory: NodePath             # Area3D; it only takes notice of Nina while she is inside
@export var crawl_speed := 1.2
@export var stalk_speed := 2.2
@export var reach := 3.8                    # how far (horizontally) it can lower its head from where its body stops
@export var face_distance := 1.4            # how close to Nina's face its head comes
@export var recoil_distance := 0.75         # get this close to its face and it pulls back and scuttles off
@export var lines: PackedStringArray = [
	"...you can see me.",
	"Not yet. You're still so small.",
	"Grow, little one. I'll wait.",
	"Do they know you come up here?",
	"I like the way you move.",
	"Soon.",
]

@export_group("Later")
@export var hostile := false                # when true it hunts Nina (not implemented yet: see _hunt)
@export var damage := 3

const CEILING_GAP := 0.24                   # body hangs this far below the route line

var _pts: Array[Vector3] = []               # route in world space
var _cum: Array[float] = []                 # cumulative length at each point
var _length := 0.0
var _s := 0.0                               # head's distance along the loop
var _watch := 0.0                           # 0 = crawling, 1 = head fully lowered and staring
var _recoil := 0.0                          # >0 while scuttling away
var _player: Node3D
var _t := 0.0
var _skitter_timer := 0.0
var _whisper_timer := 4.0
var _line := 0
var _blink := 0.0
var _next_blink := 3.0
var _head_goal := Vector3.ZERO              # where the lowered head hangs; held still so she can walk up to it
var _has_goal := false
var _arc_u: Array[float] = []

var _segs: Array[Node3D] = []
var _legs: Array = []                       # per segment: [left pivot, right pivot]
var _area: Area3D

@onready var head: Node3D = $Head
@onready var eyes: Array = [$Head/EyeL, $Head/EyeR]
@onready var lids: Array = [$Head/LidL, $Head/LidR]


func _ready() -> void:
	add_to_group("creatures")
	var parent := get_parent() as Node3D
	for p in route:
		_pts.append(parent.to_global(p) if parent else p)
	if _pts.size() < 2:
		push_warning("Centipede needs a route")
		set_physics_process(false)
		return
	_pts.append(_pts[0])                    # close the loop
	_cum.append(0.0)
	for i in range(1, _pts.size()):
		_length += _pts[i].distance_to(_pts[i - 1])
		_cum.append(_length)
	_s = _length * 0.35
	if not territory.is_empty():
		_area = get_node_or_null(territory) as Area3D
	_build_body()
	_place(0.0)


# ----------------------------------------------------------------------------- route helpers
func _at(d: float) -> Vector3:
	d = fposmod(d, _length)
	var i := _cum.bsearch(d) - 1
	i = clampi(i, 0, _pts.size() - 2)
	var seg := _cum[i + 1] - _cum[i]
	var f := (d - _cum[i]) / seg if seg > 0.0 else 0.0
	return _pts[i].lerp(_pts[i + 1], f) + Vector3.DOWN * CEILING_GAP


func _tangent(d: float) -> Vector3:
	var v := _at(d + 0.15) - _at(d - 0.15)
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD


func _nearest(p: Vector3) -> float:
	# Distance along the loop of the route point closest to p (horizontally)
	var best := 0.0
	var best_d := INF
	var d := 0.0
	while d < _length:
		var q := _at(d)
		var dd := Vector2(q.x - p.x, q.z - p.z).length()
		if dd < best_d:
			best_d = dd
			best = d
		d += 0.5
	return best


# ----------------------------------------------------------------------------- body
func _mat(c: Color, rough: float, metal := 0.0, rim := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.8
	return m


func _build_body() -> void:
	var shell := _mat(body_color, 0.22, 0.35, 0.5)
	var plate := _mat(body_color.lerp(sheen_color, 0.35), 0.3, 0.4)
	var leg := _mat(leg_color, 0.5)
	var seg_mesh := SphereMesh.new()
	seg_mesh.radius = 0.5
	seg_mesh.height = 1.0
	seg_mesh.radial_segments = 14
	seg_mesh.rings = 7
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.022
	leg_mesh.bottom_radius = 0.035
	leg_mesh.height = 1.0
	leg_mesh.radial_segments = 5
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	for i in segment_count:
		var taper := 1.0 - 0.45 * pow(float(i) / segment_count, 2.0)     # thinner toward the tail
		var s := Node3D.new()
		body.add_child(s)
		var shell_mi := MeshInstance3D.new()
		shell_mi.mesh = seg_mesh
		shell_mi.material_override = shell
		shell_mi.scale = Vector3(0.5, 0.26, 0.46) * taper
		s.add_child(shell_mi)
		var band := MeshInstance3D.new()           # a darker plate across the back (+Y faces the floor)
		band.mesh = seg_mesh
		band.material_override = plate
		band.scale = Vector3(0.42, 0.12, 0.3) * taper
		band.position = Vector3(0, 0.08 * taper, 0)
		s.add_child(band)
		var pair := []
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()                  # leg root at the side of the segment
			pivot.position = Vector3(side * 0.2 * taper, 0, 0)
			s.add_child(pivot)
			var upper := MeshInstance3D.new()          # out and up toward the ceiling...
			upper.mesh = leg_mesh
			upper.material_override = leg
			upper.scale = Vector3(1, 0.34 * taper, 1)
			upper.position = Vector3(side * 0.14, -0.08, 0) * taper
			upper.rotation.z = side * 1.15
			pivot.add_child(upper)
			var lower := MeshInstance3D.new()          # ...then a hooked foot gripping it
			lower.mesh = leg_mesh
			lower.material_override = leg
			lower.scale = Vector3(0.8, 0.26 * taper, 0.8)
			lower.position = Vector3(side * 0.31, -0.2, 0) * taper
			lower.rotation.z = side * 0.35
			pivot.add_child(lower)
			pair.append(pivot)
		_legs.append(pair)
		_segs.append(s)
	# Two long feelers behind the head
	for side in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		f.mesh = leg_mesh
		f.material_override = leg
		f.scale = Vector3(0.6, 0.5, 0.6)
		f.position = Vector3(side * 0.09, 0.2, -0.12)
		f.rotation = Vector3(-0.9, 0, side * 0.5)
		head.add_child(f)


# ----------------------------------------------------------------------------- behaviour
func _physics_process(delta: float) -> void:
	_t += delta
	_find_player()
	if hostile:
		_hunt(delta)
		return

	var noticing := _player != null and (_area == null or _area.overlaps_body(_player))
	var speed := crawl_speed
	var want_watch := 0.0
	if _recoil > 0.0:
		_recoil -= delta
		speed = stalk_speed * 1.8
	elif noticing:
		# Crawl overhead toward the nearest point of the route, then lower the head when she's within reach
		var goal := _nearest(_player.global_position)
		var ahead := fposmod(goal - _s, _length)
		var behind := fposmod(_s - goal, _length)
		var gap := minf(ahead, behind)
		var flat := Vector2(_at(_s).x - _player.global_position.x, _at(_s).z - _player.global_position.z).length()
		# Start staring when she's within reach of where it is; keep staring while she stays near its head
		var near_head := _has_goal and Vector2(_head_goal.x - _player.global_position.x,
			_head_goal.z - _player.global_position.z).length() < face_distance + 2.2
		if flat < reach or (_watch > 0.3 and near_head):
			speed = 0.0
			want_watch = 1.0
		else:
			speed = stalk_speed * (1.0 if ahead <= behind else -1.0) * clampf(gap / 2.0, 0.3, 1.0)
	if want_watch > 0.0 and _watch < 0.99:
		speed = 0.0
	if want_watch == 0.0 and _watch > 0.05:
		speed = 0.0                             # pull the head back up before crawling off
	_watch = move_toward(_watch, want_watch, delta * (0.45 if want_watch > _watch else 1.6))
	_s = fposmod(_s + speed * delta, _length)
	_place(speed)

	# Too close to its face: recoil and scuttle away down the passage
	if _watch > 0.6 and _player and head.global_position.distance_to(_player.global_position + Vector3(0, 0.6, 0)) < recoil_distance:
		_recoil = 3.0
		_watch = 0.3
		Audio.play_at("centipede_skitter", head.global_position, 3.0)

	_sounds(delta, absf(speed) > 0.05, noticing)


func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D


func _sounds(delta: float, moving: bool, noticing: bool) -> void:
	_skitter_timer -= delta
	if moving and noticing and _skitter_timer <= 0.0:
		_skitter_timer = 1.0
		Audio.play_at("centipede_skitter", _segs[_segs.size() / 2].global_position, -4.0)
	if _watch > 0.9:
		_whisper_timer -= delta
		if _whisper_timer <= 0.0:
			_whisper_timer = randf_range(7.0, 11.0)
			Audio.play_at("centipede_whisper", head.global_position, 2.0, 0.05)
			if lines.size() > 0:
				Game.message(lines[_line % lines.size()])
				_line += 1
	elif _watch < 0.1:
		_whisper_timer = minf(_whisper_timer, 2.5)    # quick to speak once it's staring again


# ----------------------------------------------------------------------------- posing
func _seg_basis(forward: Vector3, back_dir: Vector3) -> Basis:
	# +Z along the body, +Y out of its back (toward the floor while it clings to the ceiling)
	var z := forward.normalized()
	var x := back_dir.cross(z).normalized()
	if x.length() < 0.01:
		x = Vector3.RIGHT
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _face_target() -> Vector3:
	return _player.global_position + Vector3(0, 0.6, 0) if _player else _at(_s)


func _place(speed: float) -> void:
	var w := smoothstep(0.0, 1.0, _watch)
	# Where the lowered head goes: in front of Nina's face, come from the side the body is on
	var neck_root := _at(_s - neck_count * spacing)
	var head_goal := head.global_position
	if _player and w > 0.0:
		# Pick a spot in front of her face (on the side the body is on) and hold it; only re-aim if she wanders off
		var face := _face_target()
		if not _has_goal or _head_goal.distance_to(face) > face_distance + 1.4:
			var from := Vector3(neck_root.x - face.x, 0, neck_root.z - face.z)
			from = from.normalized() if from.length() > 0.01 else Vector3.FORWARD
			var goal := face + from * face_distance + Vector3(0, 0.25, 0)
			goal.y = minf(goal.y, neck_root.y - 0.6)
			_head_goal = goal if not _has_goal else _head_goal.lerp(goal, 0.05)
			_has_goal = true
		head_goal = _head_goal
	elif w <= 0.0:
		_has_goal = false
	var ctrl := Vector3(head_goal.x, neck_root.y + 0.1, head_goal.z).lerp(neck_root, 0.35)
	var neck_stretch := 1.0
	if w > 0.0:
		# Measure the curve, then space the neck segments evenly along it and stretch them to overlap
		var samples := 24
		var lens: Array[float] = [0.0]
		var prev := neck_root
		for k in samples:
			var q := _bezier(neck_root, ctrl, head_goal, (k + 1.0) / samples)
			lens.append(lens.back() + q.distance_to(prev))
			prev = q
		var arc: float = lens.back()
		_arc_u.resize(neck_count)
		for i in neck_count:
			var want := arc * (1.0 - float(i) / neck_count)
			var k := 0
			while k < samples and lens[k + 1] < want:
				k += 1
			var f := (want - lens[k]) / maxf(lens[k + 1] - lens[k], 0.0001)
			_arc_u[i] = (k + clampf(f, 0.0, 1.0)) / samples
		neck_stretch = clampf((arc / neck_count) / 0.42 * 1.3, 1.0, 3.5)

	for i in _segs.size():
		var d := _s - i * spacing
		var pos := _at(d)
		var basis := _seg_basis(_tangent(d), Vector3.DOWN)
		if i < neck_count and w > 0.0:
			# Bend the neck down along a curve from the ceiling to the lowered head (evenly spaced along it)
			var u := _arc_u[i] if i < _arc_u.size() else 1.0 - float(i) / neck_count
			var curve := _bezier(neck_root, ctrl, head_goal + Vector3(0, 0.15, 0), u)
			var tangent := _bezier(neck_root, ctrl, head_goal, minf(u + 0.05, 1.0)) - _bezier(neck_root, ctrl, head_goal, maxf(u - 0.05, 0.0))
			pos = pos.lerp(curve, w)
			var bent := _seg_basis(tangent, Vector3.DOWN.slerp(-_tangent(d), 0.5))
			basis = Basis(basis.get_rotation_quaternion().slerp(bent.get_rotation_quaternion(), w))
			# Stretch the neck segments along the curve so it reads as one long body, not a string of beads
			basis = basis.scaled_local(Vector3(1.0, 1.0, lerpf(1.0, neck_stretch, w)))
		_segs[i].global_transform = Transform3D(basis, pos)
		# Legs: a rippling stride while crawling, curled and twitching while the neck is down
		var phase := _t * (10.0 if absf(speed) > 0.05 else 1.5) - i * 0.7
		var stride := sin(phase) * (0.45 if absf(speed) > 0.05 else 0.08)
		var curl := w * (1.0 - float(i) / segment_count) * (1.0 if i < neck_count else 0.0)
		for k in 2:
			var side := -1.0 if k == 0 else 1.0
			var pivot: Node3D = _legs[i][k]
			pivot.rotation = Vector3(0, stride * side, side * (0.25 * maxf(0.0, cos(phase)) - curl * 1.2))

	# Head: upside-down at the front while crawling; upright and staring when lowered
	var front := _at(_s + 0.38)
	# crawling: crown toward the floor (the way its back faces), face forward and tipped down: upside-down to Nina
	var crawl_basis := _seg_basis(_tangent(_s).lerp(Vector3.DOWN, 0.35), Vector3.DOWN)
	var crawl_rot := crawl_basis.get_rotation_quaternion()
	var look := Basis.looking_at(_face_target() - head.global_position, Vector3.UP, true) if _player else crawl_basis
	var tilt := Quaternion(Vector3.FORWARD, 0.35 * sin(_t * 0.4))          # an unhurried, curious head tilt
	var stare_rot := look.get_rotation_quaternion() * tilt
	var head_pos := front.lerp(head_goal, w)
	head.global_transform = Transform3D(Basis(crawl_rot.slerp(stare_rot, w)), head_pos)
	_animate_face(w)


func _bezier(a: Vector3, b: Vector3, c: Vector3, u: float) -> Vector3:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


func _animate_face(w: float) -> void:
	# Eyes follow Nina; slow, occasional blinks (it rarely blinks while staring)
	if _player:
		for e in eyes:
			var eye := e as Node3D
			var target := _face_target()
			var local := head.global_transform.affine_inverse() * target
			var dir := (local - eye.position).normalized()
			var yaw := clampf(atan2(dir.x, dir.z), -0.5, 0.5)
			var pitch := clampf(-asin(clampf(dir.y, -1, 1)), -0.4, 0.4)
			eye.rotation = eye.rotation.lerp(Vector3(pitch, yaw, 0), 0.25)
	_next_blink -= get_physics_process_delta_time()
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = randf_range(4.0, 7.0) * (2.5 if w > 0.5 else 1.0)
	_blink = maxf(_blink - get_physics_process_delta_time() * 2.2, 0.0)
	var k := sin(_blink * PI)                     # 0 open → 1 closed → 0 open
	for l in lids:
		var lid := l as Node3D
		lid.scale = Vector3(1, maxf(k, 0.05), 1)


# ----------------------------------------------------------------------------- later: as an enemy
func _hunt(delta: float) -> void:
	# TODO when it becomes an enemy: drop from the ceiling, chase Nina, and call player.hurt(damage, global_position)
	# on contact. For now, hostile mode behaves like normal stalking so switching it on can't break anything.
	hostile = false
	_physics_process(delta)
	hostile = true
