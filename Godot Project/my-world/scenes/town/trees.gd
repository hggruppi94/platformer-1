extends Node3D

# Builds the town's trees when the scene loads (MultiMesh data can't be baked from a headless build).
# Positions/sizes/colors and the look (bark, glow, canopy shape) are written by tools/build_town.gd.

@export var positions: PackedVector3Array
@export var sizes: PackedFloat32Array
@export var colors: PackedColorArray
@export var bark_color := Color(0.45, 0.3, 0.18)
@export var glow := 0.0                    # how much the canopies light up in their own colour
@export var canopy_stretch := 1.15         # canopy height / width

const LEAVES_SHADER := """shader_type spatial;
render_mode cull_back;
uniform float glow = 0.0;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * glow;
}"""


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
		var half_h := s * canopy_stretch * 0.5               # canopy is a unit sphere scaled by s (wide) x s*stretch (tall)
		var canopy_y := 1.4 + half_h * 1.4                   # canopy centre above the ground
		canopies.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s * canopy_stretch, s)),
			p + Vector3(0, canopy_y, 0)))
		canopies.set_instance_color(i, colors[i])
		# The trunk runs from a little below the ground up to the canopy's centre, so the two always meet
		var bottom := -0.3
		var trunk_h := canopy_y - bottom
		trunks.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, trunk_h, 1)),
			p + Vector3(0, bottom + trunk_h / 2, 0)))

	var leaves := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = LEAVES_SHADER
	leaves.shader = sh
	leaves.set_shader_parameter("glow", glow)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = bark_color
	var a := MultiMeshInstance3D.new()
	a.multimesh = canopies
	a.material_override = leaves
	add_child(a)
	var b := MultiMeshInstance3D.new()
	b.multimesh = trunks
	b.material_override = bark
	add_child(b)
