class_name Fx
extends RefCounted

# Little one-off effects for things Nina passes through: a burst of puffs, bubbles or leaves (burst), and a ripple
# ring spreading on water (ripple). They clean themselves up.

static var _mats := {}


static func burst(parent: Node, pos: Vector3, color: Color, amount := 10, size := 0.12, speed := 1.5,
		gravity := -3.0, life := 0.9, spread := 180.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = life
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = _mat(color)
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	var fade := Curve.new()
	fade.add_point(Vector2(0, 0.4))
	fade.add_point(Vector2(0.25, 1))
	fade.add_point(Vector2(1, 0))
	p.scale_amount_curve = fade
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)


static func ripple(parent: Node, pos: Vector3, color := Color(0.85, 1.0, 0.9, 0.7)) -> void:
	# A ring on the water that spreads out and fades
	if parent == null or not parent.is_inside_tree():
		return
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.45
	t.outer_radius = 0.5
	t.rings = 24
	t.ring_segments = 4
	ring.mesh = t
	var m := _mat(color).duplicate() as StandardMaterial3D
	ring.material_override = m
	parent.add_child(ring)
	ring.global_position = pos
	ring.scale = Vector3(0.4, 0.2, 0.4)
	var tw := ring.create_tween().set_parallel()
	tw.tween_property(ring, "scale", Vector3(2.4, 0.2, 2.4), 0.9)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(ring.queue_free)


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]
