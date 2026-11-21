class_name ChaosBurst
extends Node3D

# One of the Agent of Chaos's chaos bursts (scripts/chaos_fight.gd): glitch cubes gather in the air over a spot,
# spinning tighter as a warning, then it pops in a shower of glitchy purple and gold cubes. Standing under them when it
# pops gets you bumped (jumping doesn't help, moving off does). Kid-safe: sparkles and cubes, no fire, no smoke.

const RADIUS := 2.2

var warn := 1.3
var damage := 2
var _t := 0.0
const CUBES := 8

var _mark: Node3D
var _crackle := 0.0
var _done := false


func _ready() -> void:
	# No mark on the ground: a knot of glitch cubes gathers in the air over the spot, spinning in tighter and faster,
	# crackling, then pops. Where they gather is where it'll pop.
	_mark = Node3D.new()
	_mark.name = "Gathering"
	add_child(_mark)
	for i in CUBES:
		var cube := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE * 0.32
		cube.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.75, 0.3, 1.0), Color(1.0, 0.8, 0.3), Color(0.3, 0.9, 1.0)][i % 3]
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 1.5
		cube.material_override = m
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mark.add_child(cube)
	_place_cubes(0.0)
	Juice.blip("tick", 0.8, -10.0)


func _place_cubes(k: float) -> void:
	var spin := _t * lerpf(2.0, 9.0, k)
	var r := lerpf(RADIUS, 0.5, k)
	for i in _mark.get_child_count():
		var c := _mark.get_child(i) as Node3D
		var a := spin + TAU * float(i) / CUBES
		c.position = Vector3(sin(a) * r, lerpf(2.6, 1.0, k) + 0.25 * sin(_t * 7.0 + i), cos(a) * r)
		c.rotation = Vector3(_t * 3.0 + i, _t * 4.0, 0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _done:
		return
	var k := clampf(_t / warn, 0.0, 1.0)
	_place_cubes(k)
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = lerpf(0.35, 0.1, k)
		Juice.blip("buzz", lerpf(0.9, 1.6, k), -16.0)
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
