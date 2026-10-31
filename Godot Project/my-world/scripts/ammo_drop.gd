extends Area3D

# A little ammo bubble a popped enemy sometimes leaves behind (Arsenal.on_pop): a glowing bubble in a gadget's colour
# with a spinning star inside. It bobs where it is, drifts to her when she's close, and touching it tops that gadget
# up by a quarter (at least one). It fades away after a while if nobody takes it.

const LIFE := 25.0
const PULL := 3.5                         # metres: closer than this, it drifts to her

var gadget := "fizz"
var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	name = "AmmoDrop"
	add_to_group("ammo_drops")
	monitorable = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	cs.shape = sphere
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	var c := Arsenal.colour(gadget)
	var shell := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	shell.mesh = s
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.5)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.35
	m.rim_enabled = true
	shell.material_override = m
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(shell)
	var star := MeshInstance3D.new()
	star.mesh = StarBubble.star_mesh()
	star.material_override = StarBubble._flat(Color(1.0, 0.85, 0.3))
	star.scale = Vector3.ONE * 0.25
	star.name = "Star"
	_visual.add_child(star)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	_visual.position.y = sin(_t * 3.0) * 0.1
	(_visual.get_node("Star") as Node3D).rotation.y = _t * 3.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		var to := p.global_position + Vector3(0, 0.6, 0) - global_position
		if to.length() < maxf(PULL, Arsenal.ammo_pull()):        # (further with a Sparkle Magnet)
			global_position += to.normalized() * minf(to.length(), delta * 8.0)
	if _t > LIFE - 3.0:
		_visual.visible = int(_t * 8.0) % 2 == 0       # blinks before it goes


func _on_body_entered(b: Node3D) -> void:
	if not b.is_in_group("player"):
		return
	var put := Arsenal.refill(gadget, maxi(1, roundi(Arsenal.max_ammo(gadget) / 4.0)))
	if put > 0:
		Game.message("+%d %s" % [put, Arsenal.gadget_name(gadget)])
	Audio.play("pickup", -6.0)
	Fx.burst(get_parent(), global_position, Arsenal.colour(gadget), 10, 0.05, 2.0, 0.0, 0.5)
	queue_free()
