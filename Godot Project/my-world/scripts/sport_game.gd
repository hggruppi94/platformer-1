class_name SportGame
extends Node3D

# What every game in the sports corner (scripts/sports.gd) shares. A game is put on its court (its own child of the
# court's group, so the court's own pieces and their detailed models are untouched) when it's chosen, and freed after.
#
#   setup()      put the hero and the game's things in place (before the countdown)
#   go()         the countdown's over
#   tick(delta)  every physics frame while it's on; call sports.over(score, headline) when it's done
#   action()     Interact was pressed (shoot, kick)
#   status()     [the top line, the score line] for the HUD
#   teardown()   put things back (the host goes home)
#
# Balls fly along worked-out arcs (arc()), not the physics engine: the open-source sports games we read
# (nicolasbize/soccer-course, DotcYuanJia/Godot_BasketballGame) do the same, so a ball always lands where it was
# meant to and never gets stuck in a net.

var sports: Node                     # the Sports autoload
var p: CharacterBody3D               # the hero
var host: Node3D                     # the game's host (Coach Swish, Bonk, Volley, Peak)
var hold := false                    # keep the hero's controls held while it's on (the kicks)
var time := 0.0                      # seconds since GO

var _host_home := Transform3D()


func setup() -> void:
	pass


func go() -> void:
	pass


func tick(delta: float) -> void:
	time += delta


func action() -> void:
	pass


func status() -> Array:
	return ["", ""]


func teardown() -> void:
	if is_instance_valid(host) and _host_home != Transform3D():
		host.transform = _host_home


func send_host(at: Vector3, face_to := Vector3.INF) -> void:
	# The host walks onto the court for the game (back home after: teardown)
	if not is_instance_valid(host):
		return
	if _host_home == Transform3D():
		_host_home = host.transform
	host.global_position = at
	if face_to != Vector3.INF:
		face(host, face_to)
	var name_l := host.get_node_or_null("Best")
	if name_l:
		name_l.visible = false


func place_hero(local: Vector3, look_at_local: Vector3) -> void:
	# The hero onto a spot in the court's space, facing another (her model and the camera turn with her)
	var at := to_global(local)
	p.global_position = at
	p.velocity = Vector3.ZERO
	var to := to_global(look_at_local) - at
	to.y = 0.0
	if to.length() < 0.01:
		return
	# Only her model and the camera turn, the way dusk_gate.gd and player.gd's spawn markers do it (turning her
	# body twists the controls round)
	p.rotation = Vector3.ZERO
	var yaw := atan2(-to.x, -to.z)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.y = yaw + PI                            # models face +Z
	var arm = p.get("spring_arm")
	if arm is Node3D:
		(arm as Node3D).rotation.y = yaw                        # the camera behind her, looking the same way


static func face(node: Node3D, target: Vector3) -> void:
	# Turn to face a spot (models face +Z)
	var to := Vector3(target.x - node.global_position.x, 0.0, target.z - node.global_position.z)
	if to.length() > 0.01:
		node.global_basis = Basis.looking_at(-to.normalized(), Vector3.UP)


static func arc(from: Vector3, to: Vector3, height: float, t: float) -> Vector3:
	# A ball's flight: a straight line from one spot to the other with a hump on top, t from 0 to 1
	var k := clampf(t, 0.0, 1.0)
	return from.lerp(to, k) + Vector3.UP * (4.0 * height * k * (1.0 - k))


func ball(colour: Color, radius := 0.13, stripes := Color(0.2, 0.1, 0.1)) -> Node3D:
	# A ball with a seam round it, in the court's space
	var b := Node3D.new()
	b.name = "Ball"
	add_child(b)
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	mesh_on(b, s, Vector3.ZERO, mat(colour, 0.15))
	var seam := TorusMesh.new()
	seam.inner_radius = radius * 0.98
	seam.outer_radius = radius * 1.04
	mesh_on(b, seam, Vector3.ZERO, mat(stripes))
	var seam2 := mesh_on(b, seam, Vector3.ZERO, mat(stripes))
	seam2.rotation.x = PI / 2.0
	return b


func ring(colour: Color, radius: float) -> MeshInstance3D:
	# A glowing ring lying on the ground (where a ball will land, a target)
	var t := TorusMesh.new()
	t.inner_radius = radius * 0.82
	t.outer_radius = radius
	var r := mesh_on(self, t, Vector3.ZERO, mat(colour, 1.2))
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return r


static func mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func mesh_on(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Piece"                                       # (named, so the town's merging leaves it alone)
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi, true)
	return mi


static func label_on(parent: Node3D, text: String, size: int, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = Color(1, 0.95, 0.75)
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.position = at
	parent.add_child(l)
	return l
