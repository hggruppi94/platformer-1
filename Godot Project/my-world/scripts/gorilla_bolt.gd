extends Area3D

# A cyber gorilla's blaster bolt (scripts/cyber_gorilla.gd): a fat, slow, glowing light-blue blob that flies straight
# along the arrows the gorilla showed on the ground before it fired, so stepping aside always dodges it. It's slow on
# purpose (SPEED), so even the littlest players can see it coming. It bumps whoever it hits (1, never more), and pops
# on anything solid, or after LIFE seconds.

const SPEED := 11.0
const LIFE := 2.4
const RADIUS := 0.32
const COLOUR := Color(0.4, 0.85, 1.0)
const PLAYER_AXIS := 0.45          # half the straight part of the player's capsule (1.6 high, 0.35 round)
const PLAYER_RADIUS := 0.35

var dir := Vector3.FORWARD
var damage := 1
var shooter: Node3D
var _t := 0.0
var _done := false
var _core: MeshInstance3D


func _ready() -> void:
	add_to_group("gorilla_bolts")
	monitorable = false
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	add_child(cs)
	_core = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = RADIUS
	m.height = RADIUS * 2.0
	_core.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.96, 1.0)
	mat.emission_enabled = true
	mat.emission = COLOUR
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core.material_override = mat
	add_child(_core)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = RADIUS * 1.7
	hm.height = RADIUS * 3.4
	halo.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(COLOUR, 0.3)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.emission_enabled = true
	hmat.emission = COLOUR
	halo.material_override = hmat
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = COLOUR
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	global_position += dir * SPEED * delta
	var w := 1.0 + sin(_t * 30.0) * (0.0 if Settings.reduce_motion else 0.12)
	_core.scale = Vector3(w, w, 2.0 - w)
	_touch_player()
	if _t >= LIFE:
		fizzle()


func _touch_player() -> void:
	# The player is checked by distance to her capsule, not by body_entered: other things that bump her (shock rings,
	# chaos bursts) do the same, and an Area3D moved by hand every frame doesn't always see her body.
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or _done:
		return
	var foot := p.global_position + Vector3(0, -PLAYER_AXIS, 0)
	var head := p.global_position + Vector3(0, PLAYER_AXIS, 0)
	var along := clampf((global_position - foot).dot(Vector3.UP), 0.0, head.y - foot.y)
	if global_position.distance_to(foot + Vector3.UP * along) <= PLAYER_RADIUS + RADIUS:
		_on_body(p)


func _on_body(body: Node3D) -> void:
	if _done or body == shooter:
		return
	if body.is_in_group("player"):
		if body.has_method("is_recovering") and body.call("is_recovering"):
			return                                          # she's still blinking from a bump: fly on through

		if not body.call("is_invulnerable"):
			body.call("hurt", damage, global_position - dir)
		fizzle()
	elif body is StaticBody3D or body is CSGShape3D:
		fizzle()


func fizzle() -> void:
	if _done:
		return
	_done = true
	set_deferred("monitoring", false)
	if is_inside_tree():
		Fx.burst(get_parent(), global_position, COLOUR, 10, 0.05, 3.0, 0.0, 0.35)
	queue_free()
