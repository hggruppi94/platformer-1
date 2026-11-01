class_name ChaosBurst
extends Node3D

# One of the Agent of Chaos's chaos bursts (scripts/chaos_fight.gd): a glowing mark on the ground that pulses for a
# moment as a warning, then pops in a shower of glitchy purple and gold cubes. Standing on the mark when it pops gets
# you bumped (jumping doesn't help, moving off does). Kid-safe: sparkles and cubes, no fire, no smoke.

const RADIUS := 2.2

var warn := 1.3
var damage := 2
var _t := 0.0
var _mark: MeshInstance3D
var _mat: StandardMaterial3D
var _done := false


func _ready() -> void:
	_mark = MeshInstance3D.new()
	_mark.name = "Mark"
	var c := CylinderMesh.new()
	c.top_radius = RADIUS
	c.bottom_radius = RADIUS
	c.height = 0.04
	c.radial_segments = 32
	_mark.mesh = c
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 0.25, 0.75, 0.45)
	_mark.material_override = _mat
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.position.y = 0.06
	add_child(_mark)
	var edge := MeshInstance3D.new()                # a bright rim so the mark reads from far off
	edge.name = "Rim"
	var t := TorusMesh.new()
	t.inner_radius = RADIUS - 0.12
	t.outer_radius = RADIUS
	t.rings = 40
	t.ring_segments = 6
	edge.mesh = t
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.85, 0.3)
	edge.material_override = em
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	edge.scale = Vector3(1.0, 0.4, 1.0)
	_mark.add_child(edge)
	Juice.blip("tick", 0.8, -10.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _done:
		return
	var k := clampf(_t / warn, 0.0, 1.0)
	_mat.albedo_color.a = 0.35 + 0.45 * k * (0.5 + 0.5 * sin(_t * (10.0 + 20.0 * k)))
	_mark.scale = Vector3(0.6 + 0.4 * k, 1.0, 0.6 + 0.4 * k)
	if _t >= warn:
		_pop()


func _pop() -> void:
	_done = true
	_mark.visible = false
	var parent := get_parent()
	Fx.burst(parent, global_position + Vector3(0, 0.5, 0), Color(0.8, 0.3, 1.0), 18, 0.14, 4.0, -2.0, 0.6)
	Fx.burst(parent, global_position + Vector3(0, 0.5, 0), Color(1.0, 0.8, 0.3), 10, 0.1, 3.5, -2.0, 0.5)
	Audio.play_at("pop", global_position, 2.0, -0.4)
	Juice.blip("thud", 0.8, -6.0)
	for i in 6:                                    # a few glitch cubes tumbling out
		var cube := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * randf_range(0.2, 0.4)
		cube.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.75, 0.3, 1.0), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 1.0)][i % 3]
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.5
		cube.material_override = m
		add_child(cube)
		cube.position = Vector3(0, 0.3, 0)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.8, 1.6), randf_range(-1, 1))
		var tw := cube.create_tween().set_parallel()
		tw.tween_property(cube, "position", dir * 1.6, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(cube, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.5)
		tw.tween_property(cube, "scale", Vector3.ONE * 0.01, 0.3).set_delay(0.3)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.is_invulnerable():
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < RADIUS and p.global_position.y - global_position.y < 3.5:
			p.hurt(damage, global_position)
	get_tree().create_timer(0.7).timeout.connect(queue_free)
