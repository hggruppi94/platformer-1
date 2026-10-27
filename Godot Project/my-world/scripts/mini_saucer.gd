extends Node3D

# A little alien zipping about the town in its own tiny flying saucer (or, with jetpack on, just floating along with
# little jets under its boots, like the red one on Hayden's sheet). Spawned by scripts/little_aliens.gd.
#
# The saucer is a little cousin of the mothership (tools/build_mothership.gd): a grey disc 1.7 m across, a glass dome
# with the pilot sitting under it, and a ring of gold and blue lights chasing round its rim. It's built here from
# shapes, once, and shared by every saucer.
#
# It flies from one random spot to the next over the town: cruising, banking into turns, hovering to look about,
# sometimes landing on a roof or the grass for a bit, sometimes swooping past the player, and now and then doing
# something silly (a spin on the spot, a sudden dart, a loop up and over). It feels ahead with a ray and climbs over
# anything in its way.

const LIGHTS := 12

@export var jetpack := false
@export var area := Rect2(-130, -240, 260, 330)  # x, z it flies over (inside the town's edge walls)

enum State { FLY, HOVER, LANDED, TRICK }

var pilot: Node3D
var state := State.HOVER
var velocity := Vector3.ZERO
var exclude: Array[RID] = []
var _target := Vector3.ZERO
var _timer := 1.0
var _speed := 8.0
var _t := 0.0
var _trick := ""
var _trick_t := 0.0
var _hull: Node3D
var _lights: Array[MeshInstance3D] = []
var _player: Node3D

static var _meshes := {}                        # built once, shared by every saucer
static var _alive := 0                          # ...and let go when the last one leaves


func _ready() -> void:
	_alive += 1
	_t = randf() * 10.0
	_hull = Node3D.new()
	_hull.name = "Hull"
	add_child(_hull)
	if jetpack:
		_build_jets()
	else:
		_build_saucer()
	if pilot:
		_hull.add_child(pilot)
		pilot.position = Vector3(0, 0.08, 0) if not jetpack else Vector3(0, -0.3, 0)
		var anim := pilot.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var pose := "float" if jetpack else "sit"
		if anim and anim.has_animation(pose):
			anim.get_animation(pose).loop_mode = Animation.LOOP_LINEAR
			anim.play(pose)
			anim.speed_scale = randf_range(0.85, 1.15)
	_timer = randf_range(0.5, 3.0)


func _exit_tree() -> void:
	_alive -= 1
	if _alive == 0:
		_meshes = {}


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_t += delta
	_timer -= delta
	var want := Vector3.ZERO
	match state:
		State.FLY:
			var to := _target - global_position
			if to.length() < 1.5:
				_arrive()
			else:
				want = to.normalized() * minf(_speed, to.length() * 1.2 + 1.0)
				want = _avoid(want)
		State.HOVER:
			want = Vector3(sin(_t * 0.9), sin(_t * 1.7) * 0.4, cos(_t * 0.7)) * 0.5
			if _timer <= 0.0:
				_next()
		State.LANDED:
			if _timer <= 0.0:
				_target = global_position + Vector3(randf_range(-4, 4), randf_range(6, 12), randf_range(-4, 4))
				_speed = 4.0
				state = State.FLY
		State.TRICK:
			want = _do_trick(delta)
	var accel := 2.5 if state != State.TRICK else 8.0
	velocity = velocity.lerp(want, minf(1.0, accel * delta))
	global_position += velocity * delta
	global_position.x = clampf(global_position.x, area.position.x, area.end.x)
	global_position.z = clampf(global_position.z, area.position.y, area.end.y)
	_pose(delta)


# Where next: mostly another spot over the town, sometimes past the player, sometimes down for a landing
func _next() -> void:
	var space := get_world_3d().direct_space_state
	var r := randf()
	var near_player := _player != null and r < 0.3
	var centre := _player.global_position if near_player else global_position
	var reach := 25.0 if near_player else 70.0
	var x := clampf(centre.x + randf_range(-reach, reach), area.position.x, area.end.x)
	var z := clampf(centre.z + randf_range(-reach, reach), area.position.y, area.end.y)
	var ground := _ground(space, x, z)
	if r > 0.85 and not jetpack and ground.has("position"):
		# Down for a landing, on whatever's there (a roof, the grass, a mushroom cap)
		_target = ground.position + Vector3(0, 0.3, 0)
		_speed = 6.0
	else:
		var floor_y: float = ground.position.y if ground.has("position") else 0.0
		var height := randf_range(3.0, 7.0) if near_player else randf_range(6.0, 30.0)
		if jetpack:
			height = randf_range(2.0, 9.0)
		_target = Vector3(x, floor_y + height, z)
		_speed = randf_range(3.0, 5.0) if jetpack else randf_range(6.0, 14.0)
	state = State.FLY


func _arrive() -> void:
	var space := get_world_3d().direct_space_state
	var below := _ray(space, global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 0.9)
	if below and not jetpack:
		state = State.LANDED
		_timer = randf_range(4.0, 10.0)
		velocity = Vector3.ZERO
		global_position = below.position + Vector3(0, 0.12, 0)
	elif randf() < 0.3:
		_start_trick()
	else:
		state = State.HOVER
		_timer = randf_range(1.0, 4.0)


func _start_trick() -> void:
	state = State.TRICK
	_trick = ["spin", "dart", "loop"].pick_random() if not jetpack else ["spin", "loop"].pick_random()
	_trick_t = 0.0
	if _trick == "dart":
		var a := randf() * TAU
		velocity = Vector3(cos(a), randf_range(-0.1, 0.3), sin(a)) * 22.0


func _do_trick(delta: float) -> Vector3:
	_trick_t += delta
	match _trick:
		"spin":
			_hull.rotation.y += delta * 14.0 * sin(PI * clampf(_trick_t / 1.6, 0.0, 1.0))
			if _trick_t > 1.6:
				_end_trick()
			return Vector3(0, sin(_trick_t * 6.0) * 1.5, 0)
		"dart":
			if _trick_t > 0.5:
				_end_trick()
			return velocity
		"loop":
			# Up and over, the hull rolling all the way round
			var k := clampf(_trick_t / 1.4, 0.0, 1.0)
			_hull.rotation.x = -TAU * k
			if _trick_t > 1.4:
				_hull.rotation.x = 0.0
				_end_trick()
			var f := Vector3(sin(rotation.y), 0, cos(rotation.y))
			return f * cos(TAU * k) * 8.0 + Vector3.UP * sin(TAU * k) * 8.0
	_end_trick()
	return Vector3.ZERO


func _end_trick() -> void:
	state = State.HOVER
	_timer = randf_range(0.5, 2.0)


func _avoid(want: Vector3) -> Vector3:
	# Something ahead (a tower, a tree, a hill): go up and over it
	var space := get_world_3d().direct_space_state
	var ahead := _ray(space, global_position, global_position + want.normalized() * 6.0)
	if ahead:
		want = Vector3(want.x * 0.3, maxf(want.y, 0.0) + 6.0, want.z * 0.3)
	var below := _ray(space, global_position, global_position + Vector3.DOWN * 1.5)
	if below and state == State.FLY and _target.y > below.position.y + 1.0:
		want.y = maxf(want.y, 3.0)
	return want


func _pose(delta: float) -> void:
	# Face where it's going and bank into turns; bob a little; chase the rim lights round
	var flat := Vector3(velocity.x, 0, velocity.z)
	if flat.length() > 0.5:
		var yaw := atan2(flat.x, flat.z)
		var turn := wrapf(yaw - rotation.y, -PI, PI)
		rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, 2.5 * delta))
		if state != State.TRICK:
			_hull.rotation.z = lerpf(_hull.rotation.z, clampf(-turn * 0.8, -0.5, 0.5), minf(1.0, 3.0 * delta))
			_hull.rotation.x = lerpf(_hull.rotation.x, clampf(flat.length() * 0.02, 0.0, 0.2), minf(1.0, 3.0 * delta))
	elif state != State.TRICK:
		_hull.rotation.z = lerpf(_hull.rotation.z, 0.0, minf(1.0, 3.0 * delta))
		_hull.rotation.x = lerpf(_hull.rotation.x, 0.0, minf(1.0, 3.0 * delta))
	_hull.position.y = 0.0 if state == State.LANDED else sin(_t * 2.3) * 0.08
	var lit := int(_t * 10.0) % LIGHTS
	for k in _lights.size():
		_lights[k].visible = (k - lit + LIGHTS) % LIGHTS > 2 or jetpack


func _ground(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Dictionary:
	return _ray(space, Vector3(x, 120, z), Vector3(x, -10, z))


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = exclude
	var hit := space.intersect_ray(q)
	if hit and not LittleAliens.walkable(hit):
		return {}
	return hit


# -----------------------------------------------------------------------------
# Building it
# -----------------------------------------------------------------------------
func _build_saucer() -> void:
	var m := _shared()
	_part(m.disc, m.metal, Vector3.ZERO)
	_part(m.seam, m.under, Vector3(0, -0.02, 0))
	_part(m.belly, m.under, Vector3(0, -0.14, 0))
	_part(m.glow, m.glow_mat, Vector3(0, -0.29, 0))
	_part(m.seat, m.under, Vector3(0, 0.08, 0))
	_part(m.dome, m.glass, Vector3(0, 0.1, 0))
	_part(m.tip, m.gold, Vector3(0, 0.66, 0))
	for k in LIGHTS:
		var a := k * TAU / LIGHTS
		_lights.append(_part(m.light, m.gold if k % 2 == 0 else m.blue, Vector3(sin(a), 0, cos(a)) * 0.85))


func _build_jets() -> void:
	# Two little glowing jet puffs under the boots and a faint trail
	var m := _shared()
	for x in [-0.045, 0.045]:
		_lights.append(_part(m.jet, m.blue, Vector3(x, -0.34, 0)))


func _part(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if mesh != _meshes.light else \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hull.add_child(mi)
	return mi


static func _shared() -> Dictionary:
	if not _meshes.is_empty():
		return _meshes
	var disc := SphereMesh.new()                       # the grey disc
	disc.radius = 0.86
	disc.height = 0.3
	disc.radial_segments = 40
	disc.rings = 12
	var seam := CylinderMesh.new()
	seam.top_radius = 0.85
	seam.bottom_radius = 0.85
	seam.height = 0.03
	seam.radial_segments = 40
	var belly := SphereMesh.new()
	belly.radius = 0.55
	belly.height = 0.3
	belly.radial_segments = 32
	belly.rings = 10
	var glow := CylinderMesh.new()                     # the light underneath
	glow.top_radius = 0.3
	glow.bottom_radius = 0.3
	glow.height = 0.03
	var seat := CylinderMesh.new()
	seat.top_radius = 0.42
	seat.bottom_radius = 0.46
	seat.height = 0.06
	seat.radial_segments = 32
	var dome := SphereMesh.new()                       # glass, tall enough for a sitting alien and its hood
	dome.radius = 0.5
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 12
	var tip := SphereMesh.new()
	tip.radius = 0.04
	tip.height = 0.08
	var light := SphereMesh.new()
	light.radius = 0.06
	light.height = 0.12
	light.radial_segments = 8
	light.rings = 4
	var jet := SphereMesh.new()
	jet.radius = 0.035
	jet.height = 0.12
	jet.radial_segments = 8
	jet.rings = 4
	_meshes = {
		"disc": disc, "seam": seam, "belly": belly, "glow": glow, "seat": seat, "dome": dome, "tip": tip,
		"light": light, "jet": jet,
		# The mothership's own colours (tools/build_mothership.gd), so they look like they came from it
		"metal": _mat(Color(0.66, 0.68, 0.75), 0.3, 0.7),
		"under": _mat(Color(0.5, 0.53, 0.6), 0.4, 0.6),
		"gold": _mat(Color(1.0, 0.82, 0.35), 0.3, 0.0, 2.5),
		"blue": _mat(Color(0.5, 0.88, 1.0), 0.3, 0.0, 2.5),
		"glow_mat": _mat(Color(0.55, 0.9, 1.0), 0.2, 0.0, 3.0),
		"glass": _mat(Color(0.58, 0.82, 0.96, 0.3), 0.05, 0.1),
	}
	return _meshes


static func _mat(color: Color, rough: float, metal: float, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
