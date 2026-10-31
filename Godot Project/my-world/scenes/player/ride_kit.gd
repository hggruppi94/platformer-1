class_name RideKit
extends RefCounted

# Builds what each rider rides (scripts/rides.gd "kit"), under the player's Ride node (scenes/player/player.gd):
# Nina's skateboard, Dash's BMX, four-paw roller skates for Rex and Rook (all four paws, or both hands and feet), Pip's glowing
# hover disc, Bramble's scooter, the Green Man's leaf board and Mr. Palmer's Mayor-mobile. Simple shapes, in the
# same bright colours as the rest of the game.
#
# Skates sit on the rider's feet: build() returns them as "feet" ([skate node, skeleton, bone index] each), and
# scenes/player/skate.gd moves each one under its foot every frame, so they follow the stride.

const SKATEBOARD := "res://scenes/items/skateboard.tscn"
const BIKE := "res://models/props/bike.glb"


static func build(kit: String, ride: Node3D, model: Node3D) -> Dictionary:
	for c in ride.get_children():
		c.free()
	var out := {"feet": [], "anim": null}
	match kit:
		"board":
			ride.add_child(load(SKATEBOARD).instantiate())
		"bmx":
			var bike: Node3D = load(BIKE).instantiate()
			ride.add_child(bike)
			out.anim = bike.find_child("AnimationPlayer", true, false)
			if out.anim and (out.anim as AnimationPlayer).has_animation("ride"):
				(out.anim as AnimationPlayer).get_animation("ride").loop_mode = Animation.LOOP_LINEAR
				(out.anim as AnimationPlayer).play("ride")
		"skates":
			out.feet = _skates(ride, model, ["foot.L", "foot.R"], 1.0)
		"paw_skates":
			# A four-legged rider's paws (Rex), or a two-legged one's hands and feet (Rook rolling on all fours)
			var skel := _skeleton(model)
			if skel and skel.find_bone("paw_front.L") >= 0:
				out.feet = _skates(ride, model, ["paw_front.L", "paw_front.R", "paw_back.L", "paw_back.R"], 0.7)
			else:
				out.feet = _skates(ride, model, ["hand.L", "hand.R", "foot.L", "foot.R"], 0.8)
		"hover":
			_hover(ride)
		"scooter":
			_scooter(ride)
		"leaf":
			_leaf(ride)
		"segway":
			_segway(ride)
		# The hero's own rides, unlocked with schematics (scripts/schematics.gd, Rides.HERO_RIDES)
		"overboard":
			_overboard(ride)
		"rocket_board":
			ride.add_child(load(SKATEBOARD).instantiate())
			out.flames = _rockets(ride, [Vector3(-0.07, 0.17, -0.36), Vector3(0.07, 0.17, -0.36)], 0.045)
		"rocket_bike":
			var rb: Node3D = load(BIKE).instantiate()
			ride.add_child(rb)
			out.anim = rb.find_child("AnimationPlayer", true, false)
			if out.anim and (out.anim as AnimationPlayer).has_animation("ride"):
				(out.anim as AnimationPlayer).get_animation("ride").loop_mode = Animation.LOOP_LINEAR
				(out.anim as AnimationPlayer).play("ride")
			out.flames = _rockets(ride, [Vector3(0, 0.62, -0.62)], 0.08)
		"saucer":
			_saucer(ride)
	return out


static func _mat(color: Color, rough := 0.5, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _wheel(parent: Node3D, radius: float, width: float, pos: Vector3, m: Material) -> MeshInstance3D:
	# A wheel rolling along +Z (its axle across, along X)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = width
	c.radial_segments = 16
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	mi.rotation = Vector3(0, 0, PI / 2)
	parent.add_child(mi)
	return mi


static func _rod(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = m
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) / 2)
	parent.add_child(mi)


static func _skates(ride: Node3D, model: Node3D, bones: Array, size: float) -> Array:
	# A roller skate per foot (or paw): a boot frame and four wheels
	var feet := []
	var skel := _skeleton(model)
	var frame := _mat(Color(0.98, 0.45, 0.75), 0.4)
	var wheel := _mat(Color(0.7, 1.0, 0.5), 0.5, 0.0, 0.4)
	for b in bones:
		var skate := Node3D.new()
		skate.name = "Skate " + b
		ride.add_child(skate)
		_box(skate, Vector3(0.12, 0.05, 0.26) * size, Vector3(0, 0.06 * size, 0), frame)
		for z in [-0.09, 0.09]:
			for x in [-0.045, 0.045]:
				_wheel(skate, 0.035 * size, 0.03 * size, Vector3(x, 0.035, z) * size, wheel)
		var bone := skel.find_bone(b) if skel else -1
		feet.append([skate, skel, bone])
	return feet


static func _skeleton(model: Node3D) -> Skeleton3D:
	var all := model.find_children("*", "Skeleton3D", true, false)
	return all[0] as Skeleton3D if all.size() > 0 else null


static func _hover(ride: Node3D) -> void:
	# A glowing disc she stands on, with a soft ring of light under it
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.45
	c.bottom_radius = 0.35
	c.height = 0.08
	c.radial_segments = 24
	disc.mesh = c
	disc.material_override = _mat(Color(0.75, 0.6, 1.0), 0.3, 0.3, 1.2)
	disc.position = Vector3(0, 0.2, 0)
	ride.add_child(disc)
	var glow := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.3
	t.outer_radius = 0.42
	glow.mesh = t
	var gm := _mat(Color(1.0, 0.9, 0.5), 0.5, 0.0, 2.5)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	glow.position = Vector3(0, 0.12, 0)
	ride.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.7, 1.0)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position = Vector3(0, 0.05, 0)
	ride.add_child(light)


static func _scooter(ride: Node3D) -> void:
	var deck := _mat(Color(0.5, 0.85, 0.95), 0.4)
	var metal := _mat(Color(0.8, 0.8, 0.86), 0.25, 0.8)
	var grip := _mat(Color(0.95, 0.4, 0.6), 0.6)
	var wheel := _mat(Color(0.98, 0.9, 0.45), 0.5)
	_box(ride, Vector3(0.16, 0.04, 0.6), Vector3(0, 0.1, 0), deck)
	_wheel(ride, 0.06, 0.04, Vector3(0, 0.06, -0.28), wheel)
	_wheel(ride, 0.06, 0.04, Vector3(0, 0.06, 0.3), wheel)
	_rod(ride, Vector3(0, 0.1, 0.3), Vector3(0, 1.0, 0.36), 0.025, metal)
	_rod(ride, Vector3(-0.25, 1.0, 0.36), Vector3(0.25, 1.0, 0.36), 0.025, metal)
	for x in [-0.22, 0.22]:
		_rod(ride, Vector3(x - 0.04, 1.0, 0.36), Vector3(x + 0.04, 1.0, 0.36), 0.035, grip)


static func _leaf(ride: Node3D) -> void:
	# A big curled alien leaf, ridden like a board (sideways)
	var leaf := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	leaf.mesh = s
	leaf.material_override = _mat(Color(0.55, 0.95, 0.35), 0.6)
	leaf.scale = Vector3(0.32, 0.06, 0.85)
	leaf.position = Vector3(0, 0.08, 0)
	ride.add_child(leaf)
	_rod(ride, Vector3(0, 0.12, -0.42), Vector3(0, 0.12, 0.5), 0.012, _mat(Color(0.3, 0.6, 0.25), 0.6))
	_rod(ride, Vector3(0, 0.12, 0.42), Vector3(0, 0.22, 0.56), 0.012, _mat(Color(0.3, 0.6, 0.25), 0.6))


static func _segway(ride: Node3D) -> void:
	# The Mayor-mobile: a platform between two big wheels, a stem up to the handlebar, and a little flag
	var body := _mat(Color(0.95, 0.85, 0.4), 0.35, 0.4)
	var metal := _mat(Color(0.8, 0.8, 0.86), 0.25, 0.8)
	var tyre := _mat(Color(0.2, 0.18, 0.25), 0.8)
	_box(ride, Vector3(0.5, 0.08, 0.32), Vector3(0, 0.14, 0), body)
	for x in [-0.33, 0.33]:
		_wheel(ride, 0.18, 0.1, Vector3(x, 0.18, 0), tyre)
	# The stem leans well forward, clear of his tummy
	_rod(ride, Vector3(0, 0.18, 0.12), Vector3(0, 1.05, 0.5), 0.03, metal)
	_rod(ride, Vector3(-0.3, 1.05, 0.5), Vector3(0.3, 1.05, 0.5), 0.03, metal)
	_rod(ride, Vector3(0.3, 1.05, 0.5), Vector3(0.3, 1.45, 0.5), 0.012, metal)
	_box(ride, Vector3(0.02, 0.14, 0.22), Vector3(0.3, 1.38, 0.6), _mat(Color(0.95, 0.3, 0.45), 0.6))


static func _overboard(ride: Node3D) -> void:
	# A hoverboard: a slim lilac deck with a glowing teal strip under it, floating on two soft pads of light
	var deck := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.13
	cap.height = 0.9
	deck.mesh = cap
	deck.material_override = _mat(Color(0.78, 0.6, 1.0), 0.3, 0.3)
	deck.rotation.x = PI / 2
	deck.scale = Vector3(1.0, 1.0, 0.22)
	deck.position = Vector3(0, 0.3, 0)                 # up at her feet (its "deck" in Rides.HERO_RIDES), floating
	ride.add_child(deck)
	var glow := _mat(Color(0.4, 1.0, 0.9), 0.5, 0.0, 2.5)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(ride, Vector3(0.06, 0.015, 0.7), Vector3(0, 0.27, 0), glow)
	for z in [-0.28, 0.28]:
		var pad := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.06
		t.outer_radius = 0.1
		pad.mesh = t
		pad.material_override = glow
		pad.position = Vector3(0, 0.2, z)
		ride.add_child(pad)
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.9)
	light.light_energy = 0.7
	light.omni_range = 2.0
	light.position = Vector3(0, 0.1, 0)
	ride.add_child(light)


static func _rockets(ride: Node3D, at: Array, radius: float) -> Node3D:
	# Little rocket tubes pointing backwards, each with a flame out of its end. The flames are returned together as
	# one node, so the skating can make them burn brighter while she pushes and boosts (skate.gd)
	var tube := _mat(Color(0.95, 0.35, 0.55), 0.3, 0.5)
	var fin := _mat(Color(1.0, 0.85, 0.35), 0.4, 0.6)
	var flames := Node3D.new()
	flames.name = "Flames"
	ride.add_child(flames)
	var fire := _mat(Color(1.0, 0.65, 0.2), 0.5, 0.0, 3.0)
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire.albedo_color.a = 0.85
	for p in at:
		var pos: Vector3 = p
		_rod(ride, pos + Vector3(0, 0, 0.16), pos - Vector3(0, 0, 0.02), radius, tube)
		_box(ride, Vector3(radius * 3.0, 0.01, 0.06), pos + Vector3(0, 0, 0.02), fin)
		var pivot := Node3D.new()                  # at the tube's mouth, so a flame grows out backwards from it
		pivot.position = pos - Vector3(0, 0, 0.02)
		flames.add_child(pivot)
		var f := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = radius * 0.9
		cone.bottom_radius = 0.0
		cone.height = 0.22
		f.mesh = cone
		f.material_override = fire
		f.rotation.x = PI / 2                      # wide at the tube, the point out the back
		f.position = Vector3(0, 0, -0.11)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(f)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 0.8
	light.omni_range = 2.0
	light.position = (at[0] as Vector3) - Vector3(0, 0, 0.3)
	flames.add_child(light)
	return flames


static func _saucer(ride: Node3D) -> void:
	# A little flying saucer she stands in: a silver disc with a lilac rim, round lights and a glow underneath, in the
	# mothership's colours
	var hull := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	hull.mesh = s
	hull.material_override = _mat(Color(0.82, 0.84, 0.92), 0.25, 0.8)
	hull.scale = Vector3(1.0, 0.22, 1.0)
	hull.position = Vector3(0, 0.36, 0)          # her feet are on its top (deck 0.42)
	ride.add_child(hull)
	var rim := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.66
	rim.mesh = t
	rim.material_override = _mat(Color(0.75, 0.55, 1.0), 0.3, 0.3, 0.6)
	rim.position.y = 0.36
	ride.add_child(rim)
	var bulbs := _mat(Color(1.0, 0.9, 0.45), 0.4, 0.0, 2.5)
	for i in 8:
		var a := TAU * i / 8.0
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.035
		bs.height = 0.07
		b.mesh = bs
		b.material_override = bulbs
		b.position = Vector3(cos(a) * 0.6, 0.39, sin(a) * 0.6)
		ride.add_child(b)
	var under := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.3
	c.bottom_radius = 0.18
	c.height = 0.06
	under.mesh = c
	var gm := _mat(Color(0.5, 1.0, 0.85), 0.5, 0.0, 2.5)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	under.material_override = gm
	under.position = Vector3(0, 0.24, 0)
	ride.add_child(under)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.85)
	light.light_energy = 1.0
	light.omni_range = 3.0
	light.position = Vector3(0, 0.05, 0)
	ride.add_child(light)
