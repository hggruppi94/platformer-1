extends Area3D

# Something a notice board job wants, put in the Earth town by scripts/earth_jobs.gd while the job's on: a pile of
# leaves to rake ("leaves": walk or skate through it and it's swept up in a swirl), a pumpkin to pick ("pumpkin": a
# soft glow round it so it stands out from the ones that stay), or a lost cat ("cat": sitting with its tail swishing
# and its eyes glowing, a proper Halloween cat; find it and it trots along after you until it's home). Built from shapes.
# Winter's: snow drifts to shovel, winterberries and snowballs that become snowmen. Summer's: thirsty flowers to water
# ("thirsty": droopy, perking up when you walk into them), strawberries to pick, and heaps of sand on Willow Pond's beach
# that become sandcastles ("sandpile"). Spring's: little dug holes with a tulip bulb in each ("bulb": walk into one and
# a tulip pops up) and rhubarb to pick.

const COATS := {"orange": Color(0.95, 0.55, 0.2), "grey": Color(0.55, 0.55, 0.6), "black": Color(0.12, 0.11, 0.14)}

var kind := "leaves"
var job: Dictionary
var spot := 0
var coat := "orange"
var following := false
var built := false                       # a "snowball" made into a snowman, a "sandpile" into a sandcastle, a "thirsty" flower watered

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
		"drift":
			_drift()
		"berries":
			_berries()
		"snowball":
			if built:
				_look.add_child(load("res://scripts/seasons.gd").snowman_model(0.75))
			else:
				_snowball()
		"strawberries":
			_strawberries()
		"sandpile":
			if built:
				_look.add_child(load("res://scripts/summer_splash.gd").sandcastle_model(0.9))
			else:
				_sandpile()
		"thirsty":
			_flower(built)
		"bulb":
			if built:
				_look.add_child(load("res://scripts/seasons.gd").tulip_model(1.0, spot))
			else:
				_bulb()
		"rhubarb":
			_rhubarb()
	body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if not b.is_in_group("player") or following or built:
		return
	EarthJobs.collect(job, spot)
	match kind:
		"drift":
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, Color(0.95, 0.97, 1.0), 18, 0.1, 3.0, -3.0, 1.0)
			queue_free()
		"berries":
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.9, 0.15, 0.2), 10, 0.07, 2.0, -2.0, 0.8)
			queue_free()
		"strawberries":
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.95, 0.2, 0.25), 10, 0.07, 2.0, -2.0, 0.8)
			queue_free()
		"sandpile":
			# Up pops a sandcastle, in a puff of sand
			built = true
			for c in _look.get_children():
				c.queue_free()
			var sc: Node3D = load("res://scripts/summer_splash.gd").sandcastle_model(0.9)
			_look.add_child(sc)
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.93, 0.82, 0.58), 18, 0.08, 2.5, -3.0, 0.9)
			Juice.squash(sc, 0.3)
		"rhubarb":
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.5, Color(0.9, 0.3, 0.4), 10, 0.07, 2.0, -2.0, 0.8)
			queue_free()
		"bulb":
			# Pop! A tulip, in a puff of soil and petals
			built = true
			for c in _look.get_children():
				c.queue_free()
			var t: Node3D = load("res://scripts/seasons.gd").tulip_model(1.0, spot)
			_look.add_child(t)
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.4, Color(1.0, 0.6, 0.75), 14, 0.07, 2.5, -3.0, 0.8)
			Juice.squash(t, 0.3)
		"thirsty":
			# A shower of water, and the flower stands up straight and bright
			built = true
			Fx.burst(get_parent(), global_position + Vector3.UP * 1.0, Color(0.55, 0.8, 1.0), 16, 0.07, 2.5, -5.0, 0.8)
			for c in _look.get_children():
				c.queue_free()
			_flower(true)
			Juice.squash(_look, 0.3)
		"snowball":
			# Up pops a snowman, with a puff of snow and a little bounce
			built = true
			for c in _look.get_children():
				c.queue_free()
			var sm: Node3D = load("res://scripts/seasons.gd").snowman_model(0.75)
			_look.add_child(sm)
			Fx.burst(get_parent(), global_position + Vector3.UP * 0.6, Color(0.95, 0.97, 1.0), 20, 0.1, 3.0, -2.5, 1.0)
			Juice.squash(sm, 0.3)
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
func _drift() -> void:
	# A heap of snow (winter's leaf piles): a soft white mound with lumps on it
	var snow := Color(0.94, 0.96, 1.0)
	_ball(0.6, Vector3(0, 0.1, 0), snow, Vector3(1.3, 0.5, 1.1))
	for k in 5:
		var a := k * 2.4
		_ball(0.25, Vector3(cos(a) * 0.35, 0.25, sin(a) * 0.3), Color(0.9, 0.93, 0.99), Vector3(1.2, 0.6, 1.0))


func _berries() -> void:
	# A little winterberry bush in the snow: a dark green mound covered in bright red berries, with a soft glow
	_ball(0.4, Vector3(0, 0.3, 0), Color(0.15, 0.35, 0.2), Vector3(1.1, 0.85, 1.1))
	for k in 14:
		var a := k * 2.39
		var h := 0.15 + (k % 4) * 0.12
		_ball(0.06, Vector3(cos(a) * 0.4, h + 0.1, sin(a) * 0.4), Color(0.95, 0.12, 0.18), Vector3.ONE, 0.6)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.4, 0.4)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position.y = 0.6
	_look.add_child(glow)


func _strawberries() -> void:
	# A strawberry plant: a low green mound with bright red berries and little white flowers, and a soft glow
	_ball(0.4, Vector3(0, 0.2, 0), Color(0.25, 0.55, 0.2), Vector3(1.2, 0.6, 1.2))
	for k in 10:
		var a := k * 2.39
		_ball(0.07, Vector3(cos(a) * 0.38, 0.18 + (k % 3) * 0.06, sin(a) * 0.38), Color(0.95, 0.15, 0.2), Vector3(1, 1.25, 1), 0.5)
	for k in 4:
		var a := k * 1.7 + 0.5
		_ball(0.04, Vector3(cos(a) * 0.2, 0.42, sin(a) * 0.2), Color(1, 1, 0.95))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.5)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position.y = 0.6
	_look.add_child(glow)


func _bulb() -> void:
	# A little hole dug in the ground with a tulip bulb waiting in it, a heap of soil beside it and a soft glow
	_ball(0.3, Vector3(0.3, 0.06, 0), Color(0.38, 0.26, 0.16), Vector3(1.2, 0.45, 1.0))
	_ball(0.26, Vector3(0, 0.0, 0), Color(0.2, 0.13, 0.08), Vector3(1.0, 0.2, 1.0))
	_ball(0.09, Vector3(0, 0.08, 0), Color(0.85, 0.7, 0.5), Vector3(1, 1.3, 1))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.85)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position.y = 0.6
	_look.add_child(glow)


func _rhubarb() -> void:
	# A rhubarb plant: big floppy green leaves on bright red stalks, and a soft glow
	for k in 5:
		var a := k * TAU / 5.0
		_ball(0.05, Vector3(cos(a) * 0.15, 0.25, sin(a) * 0.15), Color(0.85, 0.2, 0.3), Vector3(1, 5.0, 1))
		_ball(0.25, Vector3(cos(a) * 0.3, 0.55, sin(a) * 0.3), Color(0.3, 0.6, 0.22), Vector3(1.2, 0.3, 1.0))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.6)
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position.y = 0.6
	_look.add_child(glow)


func _sandpile() -> void:
	# A heap of damp sand with a little spade stuck in it, waiting to be made into a sandcastle
	_ball(0.5, Vector3(0, 0.1, 0), Color(0.88, 0.74, 0.5), Vector3(1.2, 0.55, 1.1))
	var spade := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.5, 0.05)
	spade.mesh = b
	spade.material_override = _mat(Color(1.0, 0.85, 0.2))
	spade.position = Vector3(0.1, 0.45, 0)
	spade.rotation.z = -0.35
	_look.add_child(spade)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 0.5
	glow.omni_range = 2.5
	glow.position.y = 0.8
	_look.add_child(glow)


func _flower(watered: bool) -> void:
	# A pot of flowers: droopy and brown-ish at the edges while it's thirsty (with a soft blue glow to spot it by),
	# standing tall and bright once it's watered
	var pot := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.16
	c.height = 0.32
	pot.mesh = c
	pot.material_override = _mat(Color(0.75, 0.4, 0.25))
	pot.position.y = 0.16
	_look.add_child(pot)
	var cols := [Color(1.0, 0.45, 0.6), Color(1.0, 0.8, 0.2), Color(0.65, 0.5, 1.0)]
	for k in 3:
		var a := k * TAU / 3.0
		var stem := Node3D.new()
		stem.position = Vector3(cos(a) * 0.08, 0.3, sin(a) * 0.08)
		# (thirsty: bent right over; watered: up, leaning out a little)
		stem.rotation = Vector3(sin(a) * (0.25 if watered else 0.95), 0, -cos(a) * (0.25 if watered else 0.95))
		_look.add_child(stem)
		var s := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.015
		sc.bottom_radius = 0.02
		sc.height = 0.45
		s.mesh = sc
		s.material_override = _mat(Color(0.3, 0.6, 0.25) if watered else Color(0.5, 0.55, 0.25))
		s.position.y = 0.22
		stem.add_child(s)
		var head := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.12 if watered else 0.07
		sp.height = sp.radius * 1.4
		head.mesh = sp
		head.material_override = _mat(cols[k] if watered else cols[k].lerp(Color(0.55, 0.45, 0.3), 0.5), 0.3 if watered else 0.0)
		head.position.y = 0.47
		stem.add_child(head)
		if watered:                                   # (and a leaf on each stem, now it's perked up)
			var leaf := MeshInstance3D.new()
			var lp := SphereMesh.new()
			lp.radius = 0.07
			lp.height = 0.05
			leaf.mesh = lp
			leaf.material_override = _mat(Color(0.3, 0.6, 0.25))
			leaf.position = Vector3(0.06, 0.25, 0)
			leaf.scale = Vector3(1.6, 1.0, 0.8)
			stem.add_child(leaf)
	if not watered:
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.5, 0.75, 1.0)
		glow.light_energy = 0.6
		glow.omni_range = 2.2
		glow.position.y = 0.7
		_look.add_child(glow)


func _snowball() -> void:
	# A big rolled snowball waiting to become a snowman, with a carrot and a hat on top to show what it's for
	_ball(0.45, Vector3(0, 0.4, 0), Color(0.96, 0.97, 1.0), Vector3.ONE)
	_ball(0.06, Vector3(0, 0.9, 0), Color(1.0, 0.5, 0.1), Vector3(1.0, 1.0, 2.5))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.85, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 2.5
	glow.position.y = 0.8
	_look.add_child(glow)


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
