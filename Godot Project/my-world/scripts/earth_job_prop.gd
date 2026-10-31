extends Area3D

# Something a notice board job wants, put in the Earth town by scripts/earth_jobs.gd while the job's on: a pile of
# leaves to rake ("leaves": walk or skate through it and it's swept up in a swirl), a pumpkin to pick ("pumpkin": a
# soft glow round it so it stands out from the ones that stay), or a lost cat ("cat": sitting with its tail swishing
# and its eyes glowing, a proper Halloween cat; find it and it trots along after you until it's home). Built from shapes.

const COATS := {"orange": Color(0.95, 0.55, 0.2), "grey": Color(0.55, 0.55, 0.6), "black": Color(0.12, 0.11, 0.14)}

var kind := "leaves"
var job: Dictionary
var spot := 0
var coat := "orange"
var following := false

var _look: Node3D
var _tail: Node3D
var _t := 0.0
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	monitorable = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1 if kind == "cat" else 0.9
	cs.shape = sphere
	cs.position.y = 0.5
	add_child(cs)
	_look = Node3D.new()
	add_child(_look)
	_t = randf() * 10.0
	match kind:
		"leaves":
			_leaves()
		"pumpkin":
			_pumpkin()
		"cat":
			_cat()
	body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if not b.is_in_group("player") or following:
		return
	EarthJobs.collect(job, spot)
	match kind:
		"leaves":
			for c in [Color(0.95, 0.5, 0.15), Color(0.8, 0.25, 0.15), Color(0.95, 0.75, 0.25)]:
				Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, c, 12, 0.1, 3.0, -3.0, 1.1)
			queue_free()
		"pumpkin":
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(1.0, 0.7, 0.3), 10, 0.08, 2.0, -2.0, 0.8)
			queue_free()
		"cat":
			following = true


func _process(delta: float) -> void:
	_t += delta
	match kind:
		"pumpkin":
			_look.position.y = absf(sin(_t * 2.5)) * 0.06
		"cat":
			_tail.rotation.z = sin(_t * (6.0 if following else 2.2)) * 0.5
			if following:
				_follow(delta)


func _follow(delta: float) -> void:
	# Trot after the player, a little way behind, and sit when they stop
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length() > 30.0:
		global_position = player.global_position + Vector3(1.0, 0, 1.0)     # (left far behind: catch up at once)
		return
	if to.length() > 1.8:
		var step := minf(to.length() - 1.8, (3.0 + to.length() * 0.6) * delta)
		global_position += to.normalized() * step
		_look.rotation.y = lerp_angle(_look.rotation.y, atan2(to.x, to.z), minf(delta * 10.0, 1.0))
		_look.position.y = absf(sin(_t * 12.0)) * 0.05
		if _space == null:
			_space = get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 3.0)
		q.exclude = [player.get_rid()]
		q.collide_with_areas = false
		var hit := _space.intersect_ray(q)
		if hit:
			global_position.y = hit.position.y
	else:
		_look.position.y = 0.0


# --- Looks ---------------------------------------------------------------------
func _leaves() -> void:
	# A heap of autumn leaves: a squashed mound with leaf-coloured lumps on it
	var cols := [Color(0.92, 0.45, 0.12), Color(0.78, 0.22, 0.12), Color(0.95, 0.72, 0.22), Color(0.6, 0.35, 0.15)]
	_ball(0.55, Vector3(0, 0.12, 0), cols[0], Vector3(1.2, 0.45, 1.0))
	for k in 9:
		var a := k * 2.4
		var r := 0.15 + (k % 3) * 0.17
		_ball(0.2, Vector3(cos(a) * r, 0.22 + (2 - k % 3) * 0.05, sin(a) * r), cols[k % 4], Vector3(1.3, 0.35, 1.0))


func _pumpkin() -> void:
	var p := _ball(0.36, Vector3(0, 0.27, 0), Color(0.98, 0.55, 0.12), Vector3(1.15, 0.8, 1.15), 0.5)
	p.name = "Pumpkin"
	var stem := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.05
	c.height = 0.16
	stem.mesh = c
	stem.material_override = _mat(Color(0.3, 0.45, 0.2))
	stem.position.y = 0.58
	_look.add_child(stem)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.35)
	glow.light_energy = 0.9
	glow.omni_range = 2.2
	glow.position.y = 0.9
	_look.add_child(glow)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.5
	t.outer_radius = 0.56
	ring.mesh = t
	ring.material_override = _mat(Color(1.0, 0.85, 0.4), 2.0)
	ring.position.y = 0.03
	_look.add_child(ring)


func _cat() -> void:
	# Sitting up: a round body, a head with pointy ears, glowing eyes and a long tail that swishes
	var fur: Color = COATS.get(coat, COATS.orange)
	_ball(0.17, Vector3(0, 0.2, -0.02), fur, Vector3(1.0, 1.15, 1.25))
	_ball(0.13, Vector3(0, 0.43, 0.08), fur)
	for sx in [-1, 1]:
		var ear := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.08, 0.1, 0.04)
		ear.mesh = p
		ear.material_override = _mat(fur)
		ear.position = Vector3(sx * 0.07, 0.56, 0.07)
		ear.rotation.z = -sx * 0.25
		_look.add_child(ear)
		_ball(0.028, Vector3(sx * 0.05, 0.45, 0.19), Color(0.75, 1.0, 0.35), Vector3(1, 1.3, 0.6), 3.0)   # eyes
		_ball(0.035, Vector3(sx * 0.07, 0.03, 0.12), fur)                                              # paws
	_ball(0.02, Vector3(0, 0.41, 0.21), Color(1.0, 0.6, 0.65))                                            # nose
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.08, -0.2)
	_look.add_child(_tail)
	var tail := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.025
	c.bottom_radius = 0.035
	c.height = 0.38
	tail.mesh = c
	tail.material_override = _mat(fur)
	tail.position = Vector3(0, 0.17, -0.06)
	tail.rotation.x = -0.35
	_tail.add_child(tail)


func _ball(r: float, at: Vector3, c: Color, squash := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = _mat(c, glow)
	mi.position = at
	mi.scale = squash
	_look.add_child(mi)
	return mi


static func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m
