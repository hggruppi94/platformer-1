extends Node3D

# Hallow's Eve on Maple Lane (scripts/festival.gd puts this up on the evening of 28 Autumn, 5 to 9 PM, and takes it down
# after). At every house's gate (Festival.HALLOWS_DOORS, the places in routines/earth_places.json) a glowing
# jack-o'-lantern on a little post and a knock spot: Interact says "Trick or treat!" and whoever lives there gives a
# treat and a sparkle (Festival.knock()). Nina, Bruno, Prue and their friends go door to door too (their routines'
# "hallows" blocks).

const POST_H := 0.9

var _mats := {}


func _ready() -> void:
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	for door in Festival.HALLOWS_DOORS:
		if not paths.points.has(door):
			push_warning("Hallow's Eve: no place called %s" % door)
			continue
		var p: Vector2 = paths.points[door]
		var at := Vector3(p.x, EarthLand.height(p.x, p.y), p.y)
		var node := Node3D.new()
		node.name = "Lantern " + door
		add_child(node)
		# (beside the gate, a step off the path, so nobody walks into it)
		node.position = at + Vector3(1.4, 0, 0)
		_lantern(node)
		var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
		spot.name = "Door " + door
		spot.set("verb", "trick-or-treat")
		spot.set("radius", 2.2)
		spot.set("jobs", Festival)
		spot.position = at
		add_child(spot)


func _lantern(node: Node3D) -> void:
	# A post with a grinning jack-o'-lantern on top, glowing orange
	_box(node, Vector3(0.12, POST_H, 0.12), Vector3(0, POST_H / 2.0, 0), _mat(Color(0.35, 0.25, 0.18)))
	var r := 0.26
	var pumpkin := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = r
	ball.height = r * 2.0
	pumpkin.mesh = ball
	pumpkin.material_override = _mat(Color(0.95, 0.5, 0.12), 0.6)
	pumpkin.scale = Vector3(1.15, 0.85, 1.15)
	pumpkin.position = Vector3(0, POST_H + r * 0.8, 0)
	node.add_child(pumpkin)
	var glow := _mat(Color(1.0, 0.75, 0.2), 3.0)
	for sx in [-1.0, 1.0]:
		_box(node, Vector3(0.07, 0.07, 0.02), Vector3(sx * 0.09, POST_H + r * 0.95, r * 1.12), glow)
		_box(node, Vector3(0.07, 0.07, 0.02), Vector3(sx * 0.09, POST_H + r * 0.95, -r * 1.12), glow)
	_box(node, Vector3(0.22, 0.05, 0.02), Vector3(0, POST_H + r * 0.6, r * 1.12), glow)
	_box(node, Vector3(0.22, 0.05, 0.02), Vector3(0, POST_H + r * 0.6, -r * 1.12), glow)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position = Vector3(0, POST_H + r, 0)
	node.add_child(light)


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%s" % [c, glow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
