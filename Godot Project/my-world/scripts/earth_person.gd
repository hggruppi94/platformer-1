extends Node3D

# A placeholder person in the Earth town: a simple body built from shapes (no model yet), standing about and
# breathing. Their talk spot (scripts/talker.gd) turns them to face Nina while they talk.

@export var skin := Color(0.85, 0.68, 0.55)
@export var shirt := Color(0.3, 0.45, 0.75)
@export var trousers := Color(0.25, 0.25, 0.3)
@export var hair := Color(0.3, 0.2, 0.12)
@export var height := 1.75
@export var glasses := false
@export var tie := Color(0, 0, 0, 0)               # a tie, if it's not see-through
@export var grey_hair := false

var _t := 0.0
var _body: Node3D


func _ready() -> void:
	_t = randf() * TAU
	_body = Node3D.new()
	add_child(_body)
	var s := height / 1.75
	_part(CapsuleMesh.new(), trousers, Vector3(0, 0.45, 0) * s, Vector3(0.36, 0.9, 0.24) * s)
	_part(CapsuleMesh.new(), shirt, Vector3(0, 1.1, 0) * s, Vector3(0.48, 0.7, 0.3) * s)
	for side in [-1, 1]:
		_part(CapsuleMesh.new(), shirt, Vector3(side * 0.3, 1.05, 0) * s, Vector3(0.14, 0.62, 0.14) * s)
		_part(SphereMesh.new(), skin, Vector3(side * 0.3, 0.72, 0) * s, Vector3(0.11, 0.11, 0.11) * s)
	_part(SphereMesh.new(), skin, Vector3(0, 1.58, 0) * s, Vector3(0.36, 0.4, 0.36) * s)
	_part(SphereMesh.new(), Color(0.7, 0.7, 0.72) if grey_hair else hair, Vector3(0, 1.68, -0.03) * s, Vector3(0.38, 0.28, 0.38) * s)
	for side in [-1, 1]:
		_part(SphereMesh.new(), Color(0.1, 0.08, 0.08), Vector3(side * 0.07, 1.6, 0.17) * s, Vector3(0.04, 0.05, 0.03) * s)
	if glasses:
		for side in [-1, 1]:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.035
			ring.outer_radius = 0.045
			_part(ring, Color(0.15, 0.15, 0.18), Vector3(side * 0.07, 1.6, 0.18) * s, Vector3.ONE * s, Vector3(PI / 2, 0, 0))
	if tie.a > 0.0:
		_part(BoxMesh.new(), tie, Vector3(0, 1.15, 0.16) * s, Vector3(0.07, 0.35, 0.02) * s)


func _part(mesh: Mesh, color: Color, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	if mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = 0.5
		(mesh as CapsuleMesh).height = 1.0
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = 0.5
		(mesh as SphereMesh).height = 1.0
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if not mesh is TorusMesh:
		mi.scale = size
	_body.add_child(mi)


func _process(delta: float) -> void:
	_t += delta
	_body.scale.y = 1.0 + 0.012 * sin(_t * 1.8)       # breathing
