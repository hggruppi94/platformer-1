extends StaticBody3D

# An ammo crate (Arsenal places them round Galaxity, CRATES in scripts/arsenal.gd): a lilac box wrapped in bubble wrap
# with a gold star on top. Pop it with any gadget, splash it, or just walk into it, and it bursts in a shower of
# bubble-wrap bits and fills every gadget she has halfway back up (at least one shot each). It's back the next day
# (and whenever the town loads again).

const SIZE := 1.0

var opened := false
var _box: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("ammo_crates")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * SIZE
	cs.shape = shape
	cs.position.y = SIZE / 2.0
	add_child(cs)
	_box = build_crate()
	add_child(_box)
	# Walking into it pops it too
	var touch := Area3D.new()
	touch.monitorable = false
	var ts := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = SIZE * 0.95
	ts.shape = sphere
	ts.position.y = SIZE / 2.0
	touch.add_child(ts)
	add_child(touch)
	touch.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			shot(1, global_position, Vector3.UP))
	Clock.day_changed.connect(func(_d: int) -> void: refill())


func _process(delta: float) -> void:
	if opened:
		return
	_t += delta
	(_box.get_node("Star") as Node3D).rotation.y = _t * 2.0


func shot(_power: int, _point: Vector3, _dir: Vector3) -> String:
	# Any gadget (or a bump) pops it open
	if opened:
		return "miss"
	opened = true
	var filled := 0
	for id in Arsenal.owned:
		if Arsenal.max_ammo(id) > 0:
			filled += Arsenal.refill(id, maxi(1, roundi(Arsenal.max_ammo(id) / 2.0)))
	Game.message("Ammo crate! Your gadgets are topped up." if filled > 0 else "Ammo crate! (Your gadgets are already full.)")
	var at := global_position + Vector3(0, SIZE / 2.0, 0)
	Fx.burst(get_parent(), at, Color(0.85, 0.95, 1.0), 22, 0.07, 4.0, -4.0, 0.7)
	Fx.burst(get_parent(), at, Color(0.62, 0.5, 0.95), 12, 0.08, 3.5, -5.0, 0.6)
	Fx.burst(get_parent(), at, Color(1.0, 0.82, 0.3), 8, 0.05, 3.0, -2.0, 0.6)
	Audio.play_at("crate", at, -2.0, 0.1)
	_box.visible = false
	set_collision_layer_value(1, false)
	return "hit"


func refill() -> void:
	opened = false
	_box.visible = true
	set_collision_layer_value(1, true)


static func build_crate() -> Node3D:
	# A lilac crate with gold corners, wrapped in see-through bubble wrap (rows of little domes), a gold star on top
	var root := Node3D.new()
	var lilac := StarPopper._mat(Color(0.62, 0.5, 0.95), 0.6)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.3, 0.5)
	var box := StarPopper._part(root, BoxMesh.new(), lilac, Vector3(0, SIZE / 2.0, 0), Vector3.ZERO)
	(box.mesh as BoxMesh).size = Vector3.ONE * SIZE * 0.96
	for x in [-1, 1]:
		for z in [-1, 1]:
			var post := StarPopper._part(root, BoxMesh.new(), gold, Vector3(x, 0, z) * SIZE * 0.47 + Vector3(0, SIZE / 2.0, 0),
				Vector3.ZERO)
			(post.mesh as BoxMesh).size = Vector3(0.07, SIZE, 0.07)
	var wrap := StarPopper._glass()
	wrap.albedo_color = Color(0.9, 0.97, 1.0, 0.35)
	var bump := SphereMesh.new()
	bump.radius = 0.045
	bump.height = 0.05
	bump.radial_segments = 6
	bump.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bump
	var spots: Array[Transform3D] = []
	var n := 5
	for face in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP]:
		var basis := Basis.looking_at(-face, Vector3.UP if absf(face.y) < 0.9 else Vector3.FORWARD)
		for i in n:
			for j in n:
				var local := Vector3((i - (n - 1) / 2.0) * SIZE / n, (j - (n - 1) / 2.0) * SIZE / n, SIZE * 0.49)
				var pos: Vector3 = basis * local + Vector3(0, SIZE / 2.0, 0)
				spots.append(Transform3D(basis, pos))
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = wrap
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	var star := MeshInstance3D.new()
	star.name = "Star"
	star.mesh = StarBubble.star_mesh()
	star.material_override = gold
	star.scale = Vector3.ONE * 0.35
	star.position = Vector3(0, SIZE + 0.25, 0)
	root.add_child(star)
	return root
