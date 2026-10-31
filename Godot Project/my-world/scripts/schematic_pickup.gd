extends Node3D

# One schematic where it was dropped (scripts/schematics.gd puts them in): a glowing blue blueprint, half unrolled,
# with a drawing of the gadget or ride on it in white lines, spinning slowly over a soft blue light so it can be
# spotted from a way off. Come close enough and it's found. The one in the sky ("sky") is big and can only be picked
# up by flying the mothership through it.

const SIZE := 1.0

var id := ""
var sky := false
var _model: Node3D
var _t := 0.0
var _player: Node3D


func _ready() -> void:
	_t = randf() * TAU
	_model = model(id)
	add_child(_model)
	var halo := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.55
	ball.height = 1.1
	halo.mesh = ball
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.45, 0.75, 1.0, 0.16)
	hm.emission_enabled = true
	hm.emission = Color(0.45, 0.75, 1.0)
	hm.emission_energy_multiplier = 1.5
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.name = "Halo"
	halo.position.y = 0.55
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.8, 1.0)
	light.light_energy = 1.4
	light.omni_range = 5.0 if not sky else 16.0
	light.position.y = 0.6
	add_child(light)
	if sky:
		_model.scale *= 5.0
		halo.scale = Vector3.ONE * 5.0
		halo.position.y = 2.5


func drop() -> void:
	# Onto whatever's under it (called once it's in the scene, at its x and z)
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 60, 0)
	var q := PhysicsRayQueryParameters3D.create(from, global_position + Vector3(0, -40, 0))
	var got := space.intersect_ray(q)
	if not got.is_empty():
		global_position = got.position


static func model(which: String) -> Node3D:
	# The blueprint: a sheet curling up at both ends like a scroll, a drawing on it, and a gold seal
	var root := Node3D.new()
	root.name = "Blueprint"
	var paper := _mat(Color(0.2, 0.45, 0.95), 0.6, 0.6)
	var ink := _mat(Color(0.95, 0.98, 1.0), 0.5, 1.6)
	var holder := Node3D.new()
	holder.position.y = 0.75
	holder.rotation.x = -0.35                          # tipped back a little, so the drawing faces out
	root.add_child(holder)
	_box(holder, Vector3(0.62, 0.44, 0.015), Vector3.ZERO, paper)
	for x in [-0.33, 0.33]:                            # the rolled ends
		var roll := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.05
		c.bottom_radius = 0.05
		c.height = 0.5
		roll.mesh = c
		roll.material_override = paper
		roll.position = Vector3(x, 0, 0.01)
		holder.add_child(roll)
	# A border, and a drawing of what it makes (simple lines in white)
	for y in [-0.19, 0.19]:
		_box(holder, Vector3(0.54, 0.012, 0.02), Vector3(0, y, 0.012), ink)
	for x in [-0.27, 0.27]:
		_box(holder, Vector3(0.012, 0.38, 0.02), Vector3(x, 0, 0.012), ink)
	var e: Dictionary = Schematics.entry(which)
	if str(e.get("kind", "gadget")) == "ride":
		_box(holder, Vector3(0.34, 0.03, 0.02), Vector3(0, -0.02, 0.014), ink)          # a deck...
		for x in [-0.12, 0.12]:
			_ring(holder, 0.045, Vector3(x, -0.09, 0.014), ink)                        # ...and wheels
		_box(holder, Vector3(0.012, 0.12, 0.02), Vector3(0.1, 0.06, 0.014), ink)
	else:
		_ring(holder, 0.09, Vector3(-0.05, 0.0, 0.014), ink)                           # a gadget's tank
		_box(holder, Vector3(0.2, 0.04, 0.02), Vector3(0.1, 0.02, 0.014), ink)         # and nozzle
		_box(holder, Vector3(0.03, 0.1, 0.02), Vector3(-0.02, -0.11, 0.014), ink)      # and handle
	var seal := MeshInstance3D.new()
	var s := CylinderMesh.new()
	s.top_radius = 0.05
	s.bottom_radius = 0.05
	s.height = 0.02
	seal.mesh = s
	seal.material_override = _mat(Color(1.0, 0.82, 0.3), 0.3, 0.8)
	seal.rotation.x = PI / 2
	seal.position = Vector3(0.21, -0.14, 0.02)
	holder.add_child(seal)
	return root


static func _mat(c: Color, rough: float, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


static func _ring(parent: Node3D, r: float, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.75
	t.outer_radius = r
	mi.mesh = t
	mi.material_override = m
	mi.rotation.x = PI / 2
	mi.position = pos
	parent.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_model.rotation.y = _t * 1.2
	_model.position.y = sin(_t * 2.0) * 0.08
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	if _reached():
		Schematics.pick_up(id, global_position + Vector3(0, 0.7, 0))
		queue_free()


func _reached() -> bool:
	if sky:
		for ship in get_tree().get_nodes_in_group("mothership"):
			if ship.get("pilot") != null and (ship as Node3D).global_position.distance_to(global_position) < Schematics.SKY_RADIUS:
				return true
		return false
	return _player.global_position.distance_to(global_position + Vector3(0, 0.6, 0)) < Schematics.PICK_RADIUS
