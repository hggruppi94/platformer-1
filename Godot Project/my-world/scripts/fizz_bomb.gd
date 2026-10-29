class_name FizzBomb
extends Node3D

# One throw of the Fizz Flinger (scripts/arsenal.gd): a little bottle of fizzy soda that flies in an arc and bursts
# where it lands in a big splash of fizz. Every enemy in the splash is told it was shot (shot(power, point, dir)), so
# Gloops get bubbled and pop away and a Crocodillo goes dizzy, the same as with the Star Popper. A rolled-up
# Crocodillo's shell keeps the fizz out. The Mega Fizz (V5) throws three little fizz bombs out of each splash.

const GRAVITY := 18.0
const LIFE := 3.0
const TEAL := Color(0.35, 0.9, 1.0)
const PINK := Color(1.0, 0.5, 0.78)

var velocity := Vector3.ZERO
var radius := 2.6
var power := 1
var splits := false                       # the Mega Fizz's splash throws three little ones
var shooter: CollisionObject3D
var popper: Node                          # whose popped signal pops go to (StarPopper)
var popped_count := 0                     # tests read it
var _life := LIFE
var _bottle: Node3D


static func fire(parent: Node, from: Vector3, to: Vector3, by: CollisionObject3D, stats: Dictionary) -> FizzBomb:
	# Thrown from `from` to land on `to`: quicker for something close, a higher lob for far away
	var f := FizzBomb.new()
	f.shooter = by
	f.radius = float(stats.get("radius", 2.6))
	f.power = int(stats.get("power", 1))
	f.splits = bool(stats.get("splits", false))
	f.popper = by.get("popper") if by else null
	var t := clampf(from.distance_to(to) / 15.0, 0.35, 1.1)
	f.velocity = (to - from) / t + Vector3(0, 0.5 * GRAVITY * t, 0)
	f.set_meta("gadget", "fizz")
	parent.add_child(f)
	f.global_position = from
	return f


func _ready() -> void:
	name = "FizzBomb"
	add_to_group("fizz_bombs")
	_bottle = build_bottle()
	_bottle.scale = Vector3.ONE * (1.4 if radius > 2.0 else 1.0)
	add_child(_bottle)
	var trail := CPUParticles3D.new()      # fizz bubbles fly off it
	trail.amount = 10
	trail.lifetime = 0.4
	trail.local_coords = false
	var bit := SphereMesh.new()
	bit.radius = 0.035
	bit.height = 0.07
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = StarBubble._flat(Color(0.85, 1.0, 1.0, 0.8))
	trail.mesh = bit
	trail.spread = 180.0
	trail.initial_velocity_max = 0.6
	trail.gravity = Vector3(0, 1.0, 0)
	add_child(trail)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		burst(global_position)
		return
	velocity.y -= GRAVITY * delta
	_bottle.rotate_x(delta * 12.0)                 # end over end
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if shooter:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	burst(hit.position + hit.normal * 0.1)


func burst(at: Vector3) -> int:
	# Splash! Everything close enough gets fizzed. Says how many were popped.
	set_physics_process(false)
	var parent := get_parent()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or not e.has_method("shot") or e.get("defeated") or not (e as Node3D).is_visible_in_tree():
			continue
		var c := (e as Node3D).global_position + Vector3(0, 0.4, 0)
		if c.distance_to(at) > radius + 0.4 * float(e.get("size") if e.get("size") != null else 1.0):
			continue
		var away := c - at
		away.y = 0.0
		var what := str(e.shot(power, c, away.normalized() if away.length() > 0.01 else Vector3.FORWARD))
		if what == "hit" and e.get("defeated") == true:
			popped_count += 1
			if popper and popper.has_signal("popped"):
				popper.popped.emit(e, self)
	# A big fizzy splash: a dome of fizz that swells and fades, with bubbles and drops flying out
	Fx.burst(parent, at, TEAL, 26, 0.12, 5.0, -4.0, 0.8)
	Fx.burst(parent, at, Color(0.9, 1.0, 1.0, 0.8), 18, 0.07, 3.5, 2.0, 0.9)
	Fx.burst(parent, at, PINK, 8, 0.06, 3.0, -3.0, 0.6)
	_splash(parent, at)
	Audio.play_at("splash", at, -2.0, 0.15)
	Audio.play_at("pop", at, -4.0, 0.2)
	if splits:
		for k in 3:
			var a := TAU * k / 3.0 + randf() * 0.5
			var mini := FizzBomb.new()
			mini.shooter = shooter
			mini.popper = popper
			mini.radius = radius * 0.6
			mini.power = 1
			mini.velocity = Vector3(cos(a) * 4.0, 7.0, sin(a) * 4.0)
			mini.set_meta("gadget", "fizz")
			parent.add_child(mini)
			mini.global_position = at + Vector3(0, 0.3, 0)
			mini.scale = Vector3.ONE * 0.7
	queue_free()
	return popped_count


func _splash(parent: Node, at: Vector3) -> void:
	var dome := MeshInstance3D.new()
	dome.name = "FizzSplash"
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	dome.mesh = s
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(TEAL, 0.35)
	m.emission_enabled = true
	m.emission = TEAL
	m.emission_energy_multiplier = 0.3 if Settings.reduce_flashing else 0.7
	m.rim_enabled = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = m
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dome)
	dome.global_position = at
	dome.scale = Vector3.ONE * 0.2
	var tw := dome.create_tween()
	tw.tween_property(dome, "scale", Vector3(1.0, 0.7, 1.0) * radius, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(dome.queue_free)


static func build_bottle() -> Node3D:
	# A chubby soda bottle: teal glass, a pink cap, a gold star label. About 0.25 m tall.
	var root := Node3D.new()
	var glass := StarPopper._mat(Color(0.35, 0.9, 1.0), 0.15)
	glass.emission_enabled = true
	glass.emission = Color(0.2, 0.7, 0.9)
	glass.emission_energy_multiplier = 0.5
	var body := StarPopper._part(root, CapsuleMesh.new(), glass, Vector3.ZERO, Vector3.ZERO)
	(body.mesh as CapsuleMesh).radius = 0.07
	(body.mesh as CapsuleMesh).height = 0.22
	var neck := StarPopper._part(root, CylinderMesh.new(), glass, Vector3(0, 0.13, 0), Vector3.ZERO)
	(neck.mesh as CylinderMesh).top_radius = 0.025
	(neck.mesh as CylinderMesh).bottom_radius = 0.05
	(neck.mesh as CylinderMesh).height = 0.07
	var cap := StarPopper._part(root, CylinderMesh.new(), StarPopper._mat(PINK, 0.4), Vector3(0, 0.175, 0), Vector3.ZERO)
	(cap.mesh as CylinderMesh).top_radius = 0.03
	(cap.mesh as CylinderMesh).bottom_radius = 0.03
	(cap.mesh as CylinderMesh).height = 0.03
	var star := MeshInstance3D.new()
	star.mesh = StarBubble.star_mesh()
	star.material_override = StarPopper._mat(Color(1.0, 0.82, 0.3), 0.25, 0.6)
	star.scale = Vector3.ONE * 0.07
	star.position = Vector3(0, 0, 0.072)
	root.add_child(star)
	return root


static func build_prop() -> Node3D:
	# The Fizz Flinger in her hand: a teal sling-mitt with a soda bottle loaded in its cup, nozzle (cup) towards +Z
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "fizz")
	var teal := StarPopper._mat(Color(0.2, 0.65, 0.75), 0.4)
	var pink := StarPopper._mat(PINK, 0.5)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.25, 0.6)
	var arm := StarPopper._part(root, CapsuleMesh.new(), teal, Vector3(0, 0.0, 0.08), Vector3(PI / 2, 0, 0))
	(arm.mesh as CapsuleMesh).radius = 0.055
	(arm.mesh as CapsuleMesh).height = 0.24
	var cup := StarPopper._part(root, CylinderMesh.new(), pink, Vector3(0, 0.03, 0.24), Vector3(0.4, 0, 0))
	(cup.mesh as CylinderMesh).top_radius = 0.09
	(cup.mesh as CylinderMesh).bottom_radius = 0.05
	(cup.mesh as CylinderMesh).height = 0.06
	var rim := StarPopper._part(root, TorusMesh.new(), gold, Vector3(0, 0.045, 0.245), Vector3(0.4, 0, 0))
	(rim.mesh as TorusMesh).inner_radius = 0.08
	(rim.mesh as TorusMesh).outer_radius = 0.095
	var bottle := build_bottle()
	bottle.position = Vector3(0, 0.1, 0.25)
	bottle.rotation = Vector3(0.4, 0, 0)
	bottle.scale = Vector3.ONE * 0.8
	root.add_child(bottle)
	return root
