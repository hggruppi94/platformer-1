extends Node

# Flurry's frost breath, the player's own: the Frozen Moment's reward (scripts/frozen_moment.gd). Like Bramble's
# burrow (scripts/burrow.gd) it's locked until her world's mended: before Portals.is_cleared("frozen_moment"),
# pressing Frost breath does nothing and the Controls list doesn't show it (Settings.action_shown()). Flurry teaches
# it in the Void (Portals.flurry_hub_lines()).
#
# Press Frost breath on foot and the hero huffs a cone of sparkly frost out in front of them:
# - over water (anything in the "water" group: the Void's lakes, Willow Pond and Whisper Creek) it freezes round ice
#   floes on the surface, an ice bridge to walk or skate across. They're slippery (group "ice", player.gd on_ice()).
#   Each lasts ICE_LASTS seconds, then melts away (with a warning wobble first); only MAX_FLOES at once, oldest first.
# - enemies in the cone are chilled, slowed right down like the Freeze mod (Arsenal.chill()).
# A short breath between huffs (COOLDOWN). Made by the player (scenes/player/player.gd _ready).

const WORLD := "frozen_moment"            # the world whose mending unlocks it
const REACH := 8.0                        # how far the frost goes
const CONE := 0.6                         # radians either side of straight ahead, for enemies
const COOLDOWN := 0.7
const FLOE_R := 1.7                       # an ice floe's radius
const FLOE_EVERY := 2.2                   # metres between floes along the breath
const ICE_LASTS := 25.0
const MAX_FLOES := 40
const FROST := Color(0.75, 0.92, 1.0)

var player: CharacterBody3D
var cooldown := 0.0
var floes: Array[Node3D] = []             # the ice out there now, oldest first
var huffs := 0                            # (for the tests)


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func can_breathe() -> bool:
	if not unlocked() or player == null or cooldown > 0.0:
		return false
	if Game.riding or player.carried or player.input_locked:
		return false
	if player.burrow and player.burrow.active:
		return false
	return true


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	for f in floes.duplicate():
		if not is_instance_valid(f):
			floes.erase(f)
			continue
		var left: float = float(f.get_meta("until")) - Time.get_ticks_msec() / 1000.0
		if left <= 0.0:
			_melt(f)
		elif left < 3.0:
			# About to melt: it wobbles and goes see-through, so nobody's surprised
			(f.get_node("Look") as Node3D).position.y = sin(left * 20.0) * 0.03


func try_breathe() -> bool:
	# Called by the player when Frost breath is pressed
	if not can_breathe():
		return false
	breathe()
	return true


func breathe() -> void:
	cooldown = COOLDOWN
	huffs += 1
	var fwd := forward()
	var mouth := player.global_position + Vector3(0, 0.6, 0) + fwd * 0.5
	_puff(mouth, fwd)
	Audio.play("frost", -4.0)
	# Freeze the water ahead
	var d := 1.6
	while d <= REACH:
		var at := player.global_position + fwd * d
		var w := water_under(at.x, at.z)
		if w:
			freeze_at(Vector3(at.x, float(w.get("water_y")), at.z))
		d += FLOE_EVERY
	# Chill the enemies in the cone
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not n.is_inside_tree():
			continue
		var to := n.global_position - player.global_position
		to.y = 0.0
		if to.length() < REACH and (to.length() < 1.2 or fwd.angle_to(to.normalized()) < CONE):
			Arsenal.chill(n)


func forward() -> Vector3:
	# Where the hero's facing, flat
	var visual := player.get_node_or_null("Visual") as Node3D
	var yaw := visual.global_rotation.y if visual else player.global_rotation.y
	return Vector3(sin(yaw), 0, cos(yaw))


func water_under(x: float, z: float) -> Node:
	for w in get_tree().get_nodes_in_group("water"):
		if w.has_method("covers") and w.call("covers", x, z):
			return w
	return null


func freeze_at(at: Vector3) -> Node3D:
	# A floe of ice on the water: or, where there's one already, it just freezes over fresh
	for f in floes:
		if is_instance_valid(f) and Vector2(f.global_position.x - at.x, f.global_position.z - at.z).length() < FLOE_R:
			f.set_meta("until", Time.get_ticks_msec() / 1000.0 + ICE_LASTS)
			return f
	var f := floe_model()
	get_tree().current_scene.add_child(f)
	f.global_position = at
	f.rotation.y = randf() * TAU
	f.set_meta("until", Time.get_ticks_msec() / 1000.0 + ICE_LASTS)
	floes.append(f)
	var look := f.get_node("Look") as Node3D
	look.scale = Vector3(0.2, 1, 0.2)
	var tw := f.create_tween()
	tw.tween_property(look, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	while floes.size() > MAX_FLOES:
		_melt(floes[0])
	return f


func _melt(f: Node3D) -> void:
	floes.erase(f)
	if not is_instance_valid(f):
		return
	Fx.burst(f.get_parent(), f.global_position + Vector3.UP * 0.2, FROST, 8, 0.07, 1.5, -2.0, 0.6)
	f.queue_free()


func _puff(from: Vector3, fwd: Vector3) -> void:
	# The breath itself: a spray of frosty little balls rolling out ahead and fading, made of spheres moved by one
	# tween (one-shot particles hardly show: see Juice.dust)
	var scene := get_tree().current_scene
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(FROST, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = FROST
	m.emission_energy_multiplier = 1.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var side := fwd.cross(Vector3.UP)
	for k in 14:
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12 + randf() * 0.1
		s.height = s.radius * 2.0
		s.radial_segments = 8
		s.rings = 4
		b.mesh = s
		b.material_override = m
		scene.add_child(b)
		b.global_position = from
		var to := from + fwd * randf_range(REACH * 0.5, REACH) + side * randf_range(-1.6, 1.6) + Vector3(0, randf_range(-0.6, 0.3), 0)
		var tw := b.create_tween().set_parallel()
		tw.tween_property(b, "global_position", to, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(b, "scale", Vector3.ONE * 2.2, 0.5)
		tw.chain().tween_callback(b.queue_free)


static func floe_model() -> Node3D:
	# A round slab of pale blue ice floating on the water, solid and slippery, with a few frosty cracks on top
	var f := StaticBody3D.new()
	f.name = "Ice Floe"
	f.add_to_group("ice")
	f.add_to_group("frost_ice")
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = FLOE_R
	cy.height = 0.3
	cs.shape = cy
	f.add_child(cs)
	var look := Node3D.new()
	look.name = "Look"
	f.add_child(look)
	var slab := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = FLOE_R
	c.bottom_radius = FLOE_R * 1.05
	c.height = 0.3
	c.radial_segments = 10
	slab.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.86, 1.0, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = Color(0.55, 0.8, 1.0)
	m.emission_energy_multiplier = 0.25
	slab.material_override = m
	look.add_child(slab)
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(1, 1, 1)
	crack.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var line := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.04, 0.01, FLOE_R * (0.8 + 0.3 * k))
		line.mesh = b
		line.material_override = crack
		line.position = Vector3(0, 0.155, 0)
		line.rotation.y = k * 1.1
		look.add_child(line)
	return f
