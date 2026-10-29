class_name StarBubble
extends Node3D

# One shot from the Star Popper (scripts/star_popper.gd): a shiny soap bubble with a little gold star spinning inside.
# It flies straight, a touch floaty, and pops on whatever it touches. Anything with a shot(power, point, dir) method
# (a Gloop, a Crocodillo) is told it was hit and says what happened: "hit" (it popped on them), "bounce" (an
# armoured shell: the bubble boings off) or "miss". Nothing is ever hurt: enemies get caught in a bubble and pop
# away, like everywhere else in the game.
#
# Big bubbles (a charged shot) are twice the size, count for three hits and carry on through what they pop.

const SPEED := 26.0
const BIG_SPEED := 20.0
const LIFE := 1.7                         # seconds, about 44 m
const RADIUS := 0.16
const RISE := 0.6                         # bubbles float up a little as they go (m/s each second)
const COLORS := [Color(0.35, 0.95, 0.85), Color(1.0, 0.55, 0.85), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.35)]

var velocity := Vector3.ZERO
var power := 1
var big := false
var color := Color(0.35, 0.95, 0.85)
var shooter: CollisionObject3D            # the player: shots never touch her
var _life := LIFE
var _star: Node3D
var _skip: Array[RID] = []                # things a big bubble has already popped through
var _bounces := 0

static var _count := 0                    # every bubble flying, so a held-down trigger can't flood a scene
static var _star_mesh: ArrayMesh


static func flying() -> int:
	return _count


static func fire(parent: Node, from: Vector3, dir: Vector3, by: CollisionObject3D, charged := false) -> StarBubble:
	var b := StarBubble.new()
	b.big = charged
	b.power = 3 if charged else 1
	b.velocity = dir.normalized() * (BIG_SPEED if charged else SPEED)
	b.shooter = by
	b.color = COLORS[randi() % COLORS.size()]
	parent.add_child(b)
	b.global_position = from
	return b


func _enter_tree() -> void:
	_count += 1


func _exit_tree() -> void:
	_count -= 1


func _ready() -> void:
	name = "StarBubble"
	add_to_group("star_bubbles")
	var r := RADIUS * (2.0 if big else 1.0)
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	shell.mesh = sphere
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, 0.55)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.35 if Settings.reduce_flashing else 0.6
	m.rim_enabled = true                  # brighter round the edge, like a soap bubble
	m.rim = 1.0
	m.rim_tint = 0.2
	m.roughness = 0.1
	m.metallic_specular = 1.0
	shell.material_override = m
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var shine := MeshInstance3D.new()     # a white glint near the top
	var dot := SphereMesh.new()
	dot.radius = r * 0.22
	dot.height = r * 0.44
	shine.mesh = dot
	shine.material_override = _flat(Color(1, 1, 1, 0.9))
	shine.position = Vector3(-r * 0.4, r * 0.5, r * 0.45)
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shine)
	_star = MeshInstance3D.new()
	(_star as MeshInstance3D).mesh = star_mesh()
	(_star as MeshInstance3D).material_override = _flat(Color(1.0, 0.8, 0.15))
	(_star as MeshInstance3D).material_override.no_depth_test = true     # it shows through the bubble's skin
	_star.scale = Vector3.ONE * r * 1.6
	add_child(_star)
	# A trail of tiny sparkles behind it
	var trail := CPUParticles3D.new()
	trail.amount = 16 if big else 8
	trail.lifetime = 0.35
	trail.local_coords = false
	var bit := SphereMesh.new()
	bit.radius = 0.03 * (1.6 if big else 1.0)
	bit.height = bit.radius * 2.0
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = _flat(color.lightened(0.4))
	trail.mesh = bit
	trail.spread = 180.0
	trail.initial_velocity_max = 0.4
	trail.gravity = Vector3(0, 0.5, 0)
	var fade := Curve.new()
	fade.add_point(Vector2(0, 1))
	fade.add_point(Vector2(1, 0))
	trail.scale_amount_curve = fade
	add_child(trail)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_pop(global_position, false)
		return
	velocity.y += RISE * delta
	_star.rotate_object_local(Vector3.FORWARD, delta * 9.0)
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var skip := _skip.duplicate()
	if shooter:
		skip.append(shooter.get_rid())
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	var target := _target(hit.collider as Node)
	var what := "miss"
	if target:
		var was_down: bool = target.get("defeated") == true
		what = str(target.shot(power, hit.position, velocity.normalized()))
		if what == "hit" and not was_down and target.get("defeated") == true and shooter and shooter.get("popper"):
			shooter.popper.popped.emit(target, self)       # popped it (on the board, that's a trick: skate.gd)
	if what == "bounce" and _bounces < 2:
		# An armoured shell: boing off it (and come back towards her a bit)
		_bounces += 1
		velocity = velocity.bounce(hit.normal) * 0.7
		global_position = hit.position + hit.normal * 0.05
		Audio.play_at("boing", hit.position, -4.0, 0.15)
		Fx.burst(get_parent(), hit.position, Color(1.0, 0.9, 0.5), 6, 0.05, 2.0, 0.0, 0.3)
		return
	if what == "hit" and big:
		_skip.append((hit.collider as CollisionObject3D).get_rid())    # a big one carries on through
		Fx.burst(get_parent(), hit.position, color, 10, 0.08, 2.5, -1.0, 0.5)
		global_position = to
		return
	_pop(hit.position, what == "hit")


static func _target(n: Node) -> Node:
	# The thing that was hit, or whatever it's part of, if it knows about being shot
	while n:
		if n.has_method("shot"):
			return n
		n = n.get_parent()
	return null


func _pop(at: Vector3, on_someone: bool) -> void:
	# Pop! A ring of sparkles and droplets in its colour
	var parent := get_parent()
	Fx.burst(parent, at, color, 14 if big else 9, 0.07 if big else 0.05, 3.0 if on_someone else 2.0, -2.0, 0.5)
	Fx.burst(parent, at, Color(1.0, 0.9, 0.45), 5, 0.04, 2.5, -1.0, 0.4)
	Audio.play_at("pop", at, -3.0 if on_someone else -9.0, 0.2)
	queue_free()
	set_physics_process(false)


static func carry_off(who: Node3D, visual: Node3D, tint: Color, across: float) -> void:
	# The way a popped enemy goes: caught inside a big bubble, it floats up wobbling, then the bubble pops with a
	# shower of sparkles and it's gone (it comes back later, like after a stomp). `across` is about how wide it is.
	var bubble := MeshInstance3D.new()
	bubble.name = "CaughtBubble"
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	bubble.mesh = sphere
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.95, 1.0, 0.22)
	m.rim_enabled = true
	m.rim = 1.0
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1.0)
	m.emission_energy_multiplier = 0.4
	m.roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble.material_override = m
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	who.add_child(bubble)
	bubble.position = Vector3(0, 0.45 * across, 0)
	bubble.scale = Vector3.ONE * 0.2
	var start := visual.position
	var tw := who.create_tween()
	tw.tween_property(bubble, "scale", Vector3.ONE * across * 1.25, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(f: float) -> void:
		var lift := Vector3(0, 1.8 * f * f, 0)
		visual.position = start + lift
		visual.rotation.z = sin(f * 14.0) * 0.25 * (1.0 - f)      # a bit of a wobble as it goes up
		bubble.position = Vector3(0, 0.45 * across, 0) + lift
		bubble.scale = Vector3.ONE * across * (1.25 + 0.06 * sin(f * 20.0)), 0.0, 1.0, 0.9)
	tw.tween_callback(func() -> void:
		var at := bubble.global_position
		Fx.burst(who.get_parent(), at, tint, 22, 0.13, 3.5, -2.0, 0.8)
		Fx.burst(who.get_parent(), at, Color(1.0, 0.9, 0.45), 14, 0.08, 3.0, -1.0, 0.7)
		Fx.burst(who.get_parent(), at, Color(0.85, 0.95, 1.0, 0.7), 10, 0.1, 2.0, 1.0, 0.6)   # bits of bubble
		Audio.play_at("pop", at, 0.0, 0.1)
		visual.visible = false
		visual.rotation.z = 0.0
		bubble.queue_free())


static func star_mesh() -> ArrayMesh:
	# A flat five-pointed star, one unit across, facing +Z (both sides drawn)
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := PI / 2.0 + TAU * i / 10.0
		var rr := 0.5 if i % 2 == 0 else 0.22
		pts.append(Vector3(cos(a) * rr, sin(a) * rr, 0.0))
	for i in 10:
		for face in [[Vector3.ZERO, pts[i], pts[(i + 1) % 10]], [Vector3.ZERO, pts[(i + 1) % 10], pts[i]]]:
			for v in face:
				st.add_vertex(v)
	_star_mesh = st.commit()
	return _star_mesh


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
