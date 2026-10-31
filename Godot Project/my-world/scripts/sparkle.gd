extends Area3D

# A sparkle: a little bit of broken time, twinkling where it's fallen. Walk into it to pick it up (+1 sparkle, the
# money: scripts/game.gd). It drifts back the next day. tools/build_town.gd scatters them round town.

const COLORS := [Color(1.0, 0.9, 0.45), Color(0.6, 0.95, 1.0), Color(1.0, 0.65, 0.95)]

var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	shape.shape = sphere
	shape.position.y = 0.8
	add_child(shape)
	_t = randf() * TAU
	_visual = Node3D.new()
	add_child(_visual)
	var m := StandardMaterial3D.new()
	var col: Color = COLORS[abs(hash(name)) % COLORS.size()]
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:                                        # a twinkly star: three thin crossed diamonds
		var d := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.22, 0.55, 0.04)
		d.mesh = p
		d.material_override = m
		d.rotation = Vector3(0, k * PI / 3.0, 0)
		_visual.add_child(d)
		var d2 := d.duplicate() as MeshInstance3D
		d2.rotation.x = PI
		d2.position.y = -0.5
		_visual.add_child(d2)
	var halo := MeshInstance3D.new()                   # a soft glow round it
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.64
	halo.mesh = ball
	var hm := m.duplicate() as StandardMaterial3D
	hm.albedo_color = Color(col, 0.25)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = hm
	halo.position.y = -0.25
	_visual.add_child(halo)
	body_entered.connect(_on_body_entered)
	Clock.day_changed.connect(func(_d: int) -> void: refresh())
	Clock.jumped.connect(refresh)
	refresh()


func refresh() -> void:
	var here := not Game.sparkle_taken(name)
	visible = here
	set_deferred("monitoring", here)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_visual.position.y = 1.0 + sin(_t * 2.0) * 0.12
	_visual.rotation.y = _t * 1.8
	var s := 1.0 + 0.15 * sin(_t * 7.0)
	_visual.scale = Vector3(s, s, s)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or Game.sparkle_taken(name):
		return
	Game.take_sparkle(name)
	Audio.play("pickup", -10.0, 0.2)
	Juice.chime_pickup()                                  # climbs the scale on quick pickups (scripts/juice.gd)
	Juice.burst(get_parent(), global_position, Color(1.0, 0.9, 0.45), 8, 0.05, 2.0, 0.45)
	refresh()
