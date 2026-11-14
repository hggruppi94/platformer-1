extends RefCounted

# The gate to Dusk's Embrace, somewhere it makes sense (Hayden, 14 Nov 2026: "Dusk's embrace entrance needs to be in
# a spot that makes more sense"). It used to stand on its own out in the open meadow at the woods' far edge: a straight
# bit of wall with nothing behind it, that you could just walk round. Now:
#   - it's the old back gate of the Haunted House's garden, BEHIND_HOUSE metres straight out from the house's back
#     wall in the Spooky Woods, facing the house, with a path of old stepping stones from the house to it
#   - the wall runs all the way round a sunken hollow behind it (RING), so the gate's the only way in and there's no
#     "behind" to walk round to
#   - through the bars you see why it's called that: the hollow's stuck at dusk. Dark ground, dead twisted trees, the
#     hollow log, a purple mist welling up over the wall (you can see it from the Market), fireflies, and now and then
#     a pair of eyes that blink
# WorldDetail calls move() as the town loads. Everything that looks for the gate ("Scary World Gate", its Talk,
# "FromScaryWorld" for coming back out) finds it by name, so they all follow it. The builder (tools/build_town.gd
# _scary_gate) says the same spot, so a rebuild agrees.

const BEHIND_HOUSE := 19.0       # metres from the house's middle to the gate, out of its back
const RING := 11.0               # the walled hollow's radius (the gate's in its wall)
const OPENING := 3.3             # half the gap in the ring the gate and its posts fill
const WALL_H := 4.6


static func spot(scene: Node) -> Transform3D:
	# Where the gate goes: out of the Haunted House's back, facing it
	var house := scene.get_node_or_null("Haunted House") as Node3D
	if house == null:
		var g := scene.get_node_or_null("Scary World Gate") as Node3D
		return g.global_transform if g else Transform3D()
	var back := -house.global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var at := house.global_position + back * BEHIND_HOUSE
	at.y = _ground(scene, at)
	return Transform3D(Basis(Vector3.UP, atan2(-back.x, -back.z)), at)


static func move(scene: Node) -> bool:
	var gate := scene.get_node_or_null("Scary World Gate") as Node3D
	if gate == null or gate.has_meta("dusk_gate"):
		return false
	gate.set_meta("dusk_gate", true)
	# Someone just back from Dusk's Embrace was put at the way out before it moved: they move with it
	var out := gate.get_node_or_null("FromScaryWorld") as Node3D
	var old_out := out.global_position if out else Vector3.INF
	gate.global_transform = spot(scene)
	var player := scene.find_child("Player", true, false) as Node3D
	if out and player and player.global_position.distance_to(old_out) < 2.5:
		player.global_position = out.global_position + Vector3(0, 0.2, 0)
		player.global_rotation.y = out.global_rotation.y
	# The old straight walls either side go (look and collision): the ring takes their place
	for c in gate.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and ((c as MeshInstance3D).mesh as BoxMesh).size.x > 10.0:
			(c as MeshInstance3D).visible = false
		if c is StaticBody3D:
			var cs := c.get_child(0) as CollisionShape3D if c.get_child_count() > 0 else null
			if cs and cs.shape is BoxShape3D and (cs.shape as BoxShape3D).size.x > 10.0:
				c.process_mode = Node.PROCESS_MODE_DISABLED
				cs.disabled = true
	var hollow := Node3D.new()
	hollow.name = "Dusk Hollow"
	gate.add_child(hollow)
	var stone := _find_material(gate, "Old Wall Stone")
	_ring(scene, gate, hollow, stone)
	_inside(scene, gate, hollow)
	_path(scene, gate)
	return true


static func _ground(scene: Node, at: Vector3) -> float:
	var world := (scene as Node3D).get_world_3d()
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80, at.z), Vector3(at.x, -40, at.z))
	q.collision_mask = 1
	for i in 6:
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return 0.0
		var n := String((hit.collider as Node).name).to_lower()
		var p := String((hit.collider as Node).get_parent().name).to_lower()
		if n.contains("ground") or p.contains("terrain"):
			return hit.position.y
		var ex := q.exclude
		ex.append((hit.collider as CollisionObject3D).get_rid())
		q.exclude = ex
	return at.y


static func _find_material(gate: Node, name: String) -> Material:
	for c in gate.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override \
				and (c as MeshInstance3D).material_override.resource_name == name:
			return (c as MeshInstance3D).material_override
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.3, 0.36)
	m.roughness = 0.95
	return m


static func _ring(scene: Node, gate: Node3D, hollow: Node3D, stone: Material) -> void:
	# The wall round the hollow, in the gate's own space: its middle is RING behind the gate, and it leaves a gap
	# just the width of the gate and its posts
	var centre := Vector3(0, 0, -RING)
	var start := asin(OPENING / RING)
	var n := 16
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color(0.1, 0.15, 0.15)
	moss.roughness = 1.0
	var pts := []
	for i in n + 1:
		var a := lerpf(start, TAU - start, i / float(n))
		var local := centre + Vector3(sin(a), 0, cos(a)) * RING
		var world := gate.global_transform * local
		local.y = _ground(scene, world) - gate.global_position.y
		pts.append(local)
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var mid := (a + b) / 2.0
		var length := Vector2(b.x - a.x, b.z - a.z).length() + 0.5
		var h := WALL_H + rng.randf_range(-0.6, 0.5) - (1.4 if i % 5 == 3 else 0.0)   # crumbled down here and there
		var yaw := atan2(b.x - a.x, b.z - a.z) + PI / 2.0
		var w := MeshInstance3D.new()
		w.name = "Ring Wall %d" % i
		var bm := BoxMesh.new()
		bm.size = Vector3(length, h + 1.2, 1.3)
		w.mesh = bm
		w.material_override = stone
		w.position = mid + Vector3(0, (h + 1.2) / 2.0 - 1.2, 0)
		w.rotation.y = yaw
		hollow.add_child(w)
		var body := StaticBody3D.new()
		body.name = "Ring Wall Body"
		body.add_to_group("no_climb")                 # (wall crawl doesn't get you over: the gate's the way in)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(length, h + 1.2 + 3.0, 1.3)
		cs.shape = bx
		cs.position.y = 1.5
		body.add_child(cs)
		w.add_child(body)
		# Moss along the top, and a pillar at each join
		var top := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(length, 0.12, 1.32)
		top.mesh = tb
		top.material_override = moss
		top.position.y = (h + 1.2) / 2.0
		w.add_child(top)
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.6, h + 1.9, 1.6)
		pillar.mesh = pm
		pillar.material_override = stone
		pillar.position = b + Vector3(0, (h + 1.9) / 2.0 - 1.2, 0)
		pillar.rotation.y = yaw
		hollow.add_child(pillar)


static func _inside(scene: Node, gate: Node3D, hollow: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	var centre := Vector3(0, 0, -RING)
	var floor_y := _ground(scene, gate.global_transform * centre) - gate.global_position.y
	# The dusky ground: a dark violet floor a hair over the grass, darkest in the middle
	var dusk := StandardMaterial3D.new()
	dusk.albedo_color = Color(0.1, 0.06, 0.16)
	dusk.roughness = 1.0
	var floor_mi := MeshInstance3D.new()
	floor_mi.name = "Dusk Floor"
	var cm := CylinderMesh.new()
	cm.top_radius = RING - 0.4
	cm.bottom_radius = RING - 0.4
	cm.height = 0.6
	cm.radial_segments = 32
	floor_mi.mesh = cm
	floor_mi.material_override = dusk
	floor_mi.position = centre + Vector3(0, floor_y - 0.22, 0)
	hollow.add_child(floor_mi)
	# Dead, twisted trees
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.13, 0.1, 0.16)
	bark.roughness = 1.0
	for k in 6:
		var a := k * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var r := rng.randf_range(3.0, RING - 2.5)
		var at := centre + Vector3(sin(a) * r, floor_y, cos(a) * r)
		_dead_tree(hollow, at, rng.randf_range(5.0, 8.5), bark, rng)
	# The hollow log
	var log := MeshInstance3D.new()
	log.name = "Hollow Log"
	var lm := CylinderMesh.new()
	lm.top_radius = 0.7
	lm.bottom_radius = 0.8
	lm.height = 5.0
	log.mesh = lm
	log.material_override = bark
	log.position = centre + Vector3(1.5, floor_y + 0.6, -2.0)
	log.rotation = Vector3(0, 0.6, PI / 2.0)
	hollow.add_child(log)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.55
	hm.bottom_radius = 0.55
	hm.height = 0.05
	hole.mesh = hm
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0, 0, 0)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole.material_override = black
	hole.position = Vector3(0, 2.52, 0)
	log.add_child(hole)
	# The mist welling up, purple and dark, higher than the wall so it shows from far off
	for k in 9:
		var m := MeshInstance3D.new()
		m.name = "Dusk Mist"
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 16
		s.rings = 8
		m.mesh = s
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.32, 0.12, 0.45, 0.16 + 0.05 * (k % 3))
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mm.disable_receive_shadows = true
		m.material_override = mm
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, RING * 0.55)
		m.position = centre + Vector3(sin(a) * r, floor_y + rng.randf_range(1.0, 5.5), cos(a) * r)
		var size := rng.randf_range(4.0, 7.0)
		m.scale = Vector3(size, size * 0.55, size)
		hollow.add_child(m)
	var light := OmniLight3D.new()
	light.name = "Dusk Glow"
	light.light_color = Color(0.65, 0.3, 1.0)
	light.light_energy = 1.6
	light.omni_range = RING * 1.2
	light.position = centre + Vector3(0, floor_y + 3.0, 0)
	hollow.add_child(light)
	# Fireflies drifting about
	var flies := CPUParticles3D.new()
	flies.name = "Fireflies"
	flies.amount = 26
	flies.lifetime = 4.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(RING * 0.7, 2.0, RING * 0.7)
	flies.gravity = Vector3(0, 0.05, 0)
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.4
	flies.spread = 180.0
	var fm := SphereMesh.new()
	fm.radius = 0.05
	fm.height = 0.1
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.85, 1.0, 0.5)
	fmat.emission_enabled = true
	fmat.emission = Color(0.85, 1.0, 0.5)
	fmat.emission_energy_multiplier = 3.0
	fm.material = fmat
	flies.mesh = fm
	flies.position = centre + Vector3(0, floor_y + 2.0, 0)
	hollow.add_child(flies)
	# Eyes in the dark that blink now and then (scenery: the centipede's friends, or just the dusk)
	for k in 3:
		var eyes := Node3D.new()
		eyes.name = "Eyes %d" % k
		var a := PI + rng.randf_range(-1.0, 1.0)
		var r := rng.randf_range(RING * 0.5, RING * 0.85)
		eyes.position = centre + Vector3(sin(a) * r, floor_y + rng.randf_range(0.6, 2.4), cos(a) * r)
		eyes.rotation.y = atan2(-eyes.position.x, -(eyes.position.z))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.85, 0.3)
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for s in [-1.0, 1.0]:
			var e := MeshInstance3D.new()
			var em := SphereMesh.new()
			em.radius = 0.09
			em.height = 0.12
			e.mesh = em
			e.material_override = glow
			e.position = Vector3(s * 0.16, 0, 0)
			eyes.add_child(e)
		hollow.add_child(eyes)
		_blink(eyes, rng.randf_range(0.0, 3.0))


static func _blink(eyes: Node3D, delay: float) -> void:
	if not eyes.is_inside_tree():
		return
	var tw := eyes.create_tween().set_loops()
	tw.tween_interval(delay + 2.5)
	tw.tween_property(eyes, "scale:y", 0.05, 0.08)
	tw.tween_property(eyes, "scale:y", 1.0, 0.1)
	tw.tween_interval(1.2)
	tw.tween_property(eyes, "visible", false, 0.0)
	tw.tween_interval(2.0)
	tw.tween_property(eyes, "visible", true, 0.0)


static func _dead_tree(parent: Node3D, at: Vector3, h: float, bark: Material, rng: RandomNumberGenerator) -> void:
	var t := Node3D.new()
	t.name = "Dead Tree"
	t.position = at
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.4
	cm.height = h
	cm.radial_segments = 7
	trunk.mesh = cm
	trunk.material_override = bark
	trunk.position.y = h / 2.0
	trunk.rotation.z = rng.randf_range(-0.12, 0.12)
	t.add_child(trunk)
	for k in 4:
		var b := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		var len := rng.randf_range(1.2, 2.6)
		bm.top_radius = 0.03
		bm.bottom_radius = 0.11
		bm.height = len
		bm.radial_segments = 5
		b.mesh = bm
		b.material_override = bark
		var y := h * rng.randf_range(0.45, 0.9)
		var a := k * TAU / 4.0 + rng.randf_range(-0.4, 0.4)
		b.position = Vector3(sin(a) * len * 0.4, y, cos(a) * len * 0.4)
		b.rotation = Vector3(cos(a) * 0.9, 0, -sin(a) * 0.9)
		t.add_child(b)


static func _path(scene: Node, gate: Node3D) -> void:
	# Old stepping stones from the house's back door to the gate
	var house := scene.get_node_or_null("Haunted House") as Node3D
	if house == null:
		return
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.38, 0.35, 0.42)
	stone.roughness = 0.95
	var from := house.global_position - house.global_transform.basis.z.normalized() * 6.0
	var to := gate.global_position + gate.global_transform.basis.z.normalized() * 2.0
	var n := 7
	var path := Node3D.new()
	path.name = "Dusk Path"
	gate.get_parent().add_child(path)
	for i in n:
		var p := from.lerp(to, i / float(n - 1))
		p += gate.global_transform.basis.x.normalized() * sin(i * 1.7) * 0.5
		p.y = _ground(scene, p) + 0.03
		var s := MeshInstance3D.new()
		s.name = "Stepping Stone"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.6
		cm.height = 0.08
		cm.radial_segments = 9
		s.mesh = cm
		s.material_override = stone
		s.scale = Vector3(1.0, 1.0, 0.75)
		path.add_child(s)
		s.global_position = p
		s.rotation.y = i * 0.9
