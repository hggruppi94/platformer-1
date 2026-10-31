class_name DiscoBall
extends Node3D

# One throw of the Disco Ball (scripts/arsenal.gd): it flies in an arc, then floats up over where it landed and spins,
# throwing coloured light about, and every enemy near it stops what it's doing and dances (they bob, sway and twirl
# on the spot, with music notes over their heads) till the music stops. Dancers don't chase or bump into anyone, and
# can still be popped while they dance. The Disco Fever (V5) pops everyone who danced when the song ends.
# Each new dancer is a point for the Disco Ball (Arsenal.add_xp).

const GRAVITY := 18.0
const FLY_LIFE := 2.0
const HOVER := 2.6                        # metres up it floats
const LOOK := 0.25                        # seconds between looks for new dancers
const COLOURS := [Color(1.0, 0.5, 0.8), Color(0.4, 0.9, 1.0), Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 1.0)]

var velocity := Vector3.ZERO
var radius := 6.0
var time := 5.0
var pops_at_end := false                  # Disco Fever
var shooter: CollisionObject3D
var popper: Node
var dancers := {}                         # enemy -> {visual, pos, rot}; tests read it
var danced := 0                           # everyone who's danced to this one
var _flying := true
var _life := FLY_LIFE
var _t := 0.0
var _look := 0.0
var _ball: Node3D
var _lights: Array[OmniLight3D] = []


static func fire(parent: Node, from: Vector3, to: Vector3, by: CollisionObject3D, stats: Dictionary) -> DiscoBall:
	var d := DiscoBall.new()
	d.shooter = by
	d.popper = by.get("popper") if by else null
	d.radius = float(stats.get("radius", 6.0))
	d.time = float(stats.get("time", 5.0))
	d.pops_at_end = bool(stats.get("pops_at_end", false))
	var t := clampf(from.distance_to(to) / 14.0, 0.35, 1.0)
	d.velocity = (to - from) / t + Vector3(0, 0.5 * GRAVITY * t, 0)
	d.set_meta("gadget", "disco")
	parent.add_child(d)
	d.global_position = from
	return d


func _ready() -> void:
	name = "DiscoBall"
	add_to_group("disco_balls")
	_ball = build_ball(0.18)
	add_child(_ball)


func _physics_process(delta: float) -> void:
	_t += delta
	_ball.rotate_y(delta * (2.0 if _flying else 1.4))
	if _flying:
		_fly(delta)
		return
	time -= delta
	# Coloured light swings round (gently, with Reduce flashing on)
	var speed := 0.6 if Settings.reduce_flashing else 2.0
	for i in _lights.size():
		var a := _t * speed + TAU * i / _lights.size()
		_lights[i].position = Vector3(cos(a) * 2.2, -1.2, sin(a) * 2.2)
	_look -= delta
	if _look <= 0.0:
		_look = LOOK
		_find_dancers()
	for e in dancers.keys():
		if not is_instance_valid(e) or e.get("defeated") == true:
			_let_go(e)
			continue
		_dance(e, dancers[e])
	if time <= 0.0:
		_finish()


func _fly(delta: float) -> void:
	_life -= delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to)
	if shooter:
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() and _life > 0.0:
		global_position = to
		return
	_start(hit.position if not hit.is_empty() else global_position)


func _start(at: Vector3) -> void:
	# Landed: float up and start the music
	_flying = false
	global_position = at
	var tw := create_tween()
	tw.tween_property(self, "global_position", at + Vector3(0, HOVER, 0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ball, "scale", Vector3.ONE * 2.2, 0.5)
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = COLOURS[i]
		l.light_energy = 1.2 if Settings.reduce_flashing else 2.2
		l.omni_range = radius * 0.8
		add_child(l)
		_lights.append(l)
	Audio.play_at("bubbles", at, -3.0, 0.0)
	Juice.burst(get_tree().current_scene, at, Color(0.95, 0.6, 1.0), 16, 0.06, 3.0, 0.7)
	Fx.burst(get_parent(), at + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 16, 0.06, 3.0, -1.0, 0.7)


func _find_dancers() -> void:
	var floor := global_position - Vector3(0, HOVER, 0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if dancers.has(e) or not e is Node3D or e.get("defeated") or not (e as Node3D).is_visible_in_tree():
			continue
		var n := e as Node3D
		var flat := Vector2(n.global_position.x - floor.x, n.global_position.z - floor.z)
		if flat.length() > radius or absf(n.global_position.y - floor.y) > 4.0:
			continue
		if n.has_method("shelled") and n.shelled():
			continue                                   # a rolled-up Crocodillo can't hear the music in its shell
		var v := n.get_node_or_null("Visual") as Node3D
		dancers[n] = {"visual": v, "pos": v.position if v else Vector3.ZERO, "rot": v.rotation if v else Vector3.ZERO,
			"phase": randf() * TAU, "note": _note(n)}
		n.set_physics_process(false)               # no chasing or bumping into anyone while they dance
		if n is CharacterBody3D:
			(n as CharacterBody3D).velocity = Vector3.ZERO
		danced += 1
		Arsenal.add_xp("disco")


func _dance(e: Node3D, d: Dictionary) -> void:
	var v: Node3D = d.visual
	if v == null:
		return
	var ph: float = _t * 6.0 + float(d.phase)
	v.position = d.pos + Vector3(sin(ph * 0.5) * 0.15, absf(sin(ph)) * 0.25, 0)
	v.rotation = d.rot + Vector3(0, ph * 0.35, sin(ph * 0.5) * 0.25)
	var note: Label3D = d.note
	if note:
		note.position.y = 1.4 * float(e.get("size") if e.get("size") != null else 1.0) + sin(ph * 0.5) * 0.15
		note.modulate = COLOURS[int(_t * 2.0 + float(d.phase)) % COLOURS.size()]


func _note(e: Node3D) -> Label3D:
	var l := Label3D.new()
	l.name = "DanceNote"
	l.text = "♪ ♫"
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 12
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	e.add_child(l)
	return l


func _let_go(e: Variant) -> void:
	var d: Dictionary = dancers[e]
	dancers.erase(e)
	if d.note and is_instance_valid(d.note):
		(d.note as Node).queue_free()
	if not is_instance_valid(e):
		return
	var v: Node3D = d.visual
	if v and is_instance_valid(v):
		v.rotation = d.rot
		if e.get("defeated") != true:
			v.position = d.pos            # (a popped one floats off in its bubble from where it was dancing)
	(e as Node3D).set_physics_process(true)


func _finish() -> void:
	set_physics_process(false)
	var keep := dancers.keys()
	for e in keep:
		_let_go(e)
	if pops_at_end:
		# Disco Fever: everyone who's still dancing at the end pops
		for e in keep:
			if is_instance_valid(e) and e.get("defeated") != true and e.has_method("shot"):
				e.shot(99, (e as Node3D).global_position, Vector3.UP)
				if e.get("defeated") == true and popper and popper.has_signal("popped"):
					popper.popped.emit(e, self)
	Fx.burst(get_parent(), global_position, Color(1.0, 0.85, 0.3), 20, 0.07, 3.5, -2.0, 0.8)
	Fx.burst(get_parent(), global_position, Color(1.0, 0.5, 0.8), 14, 0.06, 3.0, -2.0, 0.7)
	Audio.play_at("pop", global_position, -2.0, 0.1)
	queue_free()


func _exit_tree() -> void:
	# Taken away early (a scene change): nobody's left dancing
	for e in dancers.keys():
		_let_go(e)


static func build_ball(r := 0.18) -> Node3D:
	# A mirror ball: silver, shiny, with little coloured tiles that glint
	var root := Node3D.new()
	var mirror := StarPopper._mat(Color(0.85, 0.85, 0.95), 0.05, 1.0)
	var ball := StarPopper._part(root, SphereMesh.new(), mirror, Vector3.ZERO, Vector3.ZERO)
	(ball.mesh as SphereMesh).radius = r
	(ball.mesh as SphereMesh).height = r * 2.0
	(ball.mesh as SphereMesh).radial_segments = 12
	(ball.mesh as SphereMesh).rings = 6
	for i in 14:
		var tile := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 0.32, r * 0.32, r * 0.05)
		tile.mesh = bm
		var c: Color = COLOURS[i % COLOURS.size()]
		var m := StarPopper._mat(c, 0.1, 0.8)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.8
		tile.material_override = m
		var dir := Vector3(cos(i * 2.4) * sin(0.5 + i * 0.19), cos(0.5 + i * 0.19), sin(i * 2.4) * sin(0.5 + i * 0.19)).normalized()
		tile.position = dir * r
		root.add_child(tile)
		tile.look_at_from_position(dir * r, dir * r * 2.0, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var hook := StarPopper._part(root, TorusMesh.new(), StarPopper._mat(Color(1.0, 0.82, 0.3), 0.25, 0.6),
		Vector3(0, r + 0.02, 0), Vector3(PI / 2, 0, 0))
	(hook.mesh as TorusMesh).inner_radius = r * 0.12
	(hook.mesh as TorusMesh).outer_radius = r * 0.22
	return root


static func build_prop() -> Node3D:
	# The Disco Ball launcher in her hand: a pink and lilac little cannon with a mirror ball sitting in its mouth
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "disco")
	var pink := StarPopper._mat(Color(1.0, 0.5, 0.78), 0.45)
	var lilac := StarPopper._mat(Color(0.62, 0.5, 0.95), 0.4)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.25, 0.6)
	var barrel := StarPopper._part(root, CylinderMesh.new(), pink, Vector3(0, 0.03, 0.12), Vector3(PI / 2, 0, 0))
	(barrel.mesh as CylinderMesh).top_radius = 0.08
	(barrel.mesh as CylinderMesh).bottom_radius = 0.06
	(barrel.mesh as CylinderMesh).height = 0.26
	for z in [0.03, 0.2]:
		var band := StarPopper._part(root, TorusMesh.new(), gold, Vector3(0, 0.03, z), Vector3(PI / 2, 0, 0))
		(band.mesh as TorusMesh).inner_radius = 0.065
		(band.mesh as TorusMesh).outer_radius = 0.085
	var grip := StarPopper._part(root, BoxMesh.new(), lilac, Vector3(0, -0.06, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	var ball := build_ball(0.07)
	ball.position = Vector3(0, 0.03, 0.27)
	root.add_child(ball)
	return root
