extends Node3D

# Builds the town's trees when the scene loads (MultiMesh data can't be baked from a headless build).
# Positions/sizes/colors are written by tools/build_town.gd.

@export var positions: PackedVector3Array
@export var sizes: PackedFloat32Array
@export var colors: PackedColorArray


func _ready() -> void:
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radial_segments = 12
	canopy_mesh.rings = 6
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6

	var canopies := MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.use_colors = true
	canopies.mesh = canopy_mesh
	canopies.instance_count = positions.size()
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk_mesh
	trunks.instance_count = positions.size()
	for i in positions.size():
		var p := positions[i]
		var s := sizes[i]
		canopies.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * 1.15, s)), p + Vector3(0, 1.6 + s, 0)))
		canopies.set_instance_color(i, colors[i])
		trunks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, 1.8 + s * 0.5, 1)), p + Vector3(0, 1.0, 0)))

	var leaves := StandardMaterial3D.new()
	leaves.vertex_color_use_as_albedo = true
	leaves.vertex_color_is_srgb = true
	leaves.roughness = 0.9
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.45, 0.3, 0.18)
	var a := MultiMeshInstance3D.new()
	a.multimesh = canopies
	a.material_override = leaves
	add_child(a)
	var b := MultiMeshInstance3D.new()
	b.multimesh = trunks
	b.material_override = bark
	add_child(b)
