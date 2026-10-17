extends Node3D

# Builds the alien undergrowth when the scene loads (MultiMesh data can't be baked from a headless build):
# giant teal and purple leaves, glowing blue mushrooms and magenta/violet ferns, as in Sofi's picture.
# Where each plant goes, its kind, size, turn and colour are written by tools/build_town.gd (_foliage).
# Big mushroom caps are solid, so you can hop across them.

enum { LEAVES, FERN, MUSHROOM }

@export var positions: PackedVector3Array
@export var kinds: PackedInt32Array
@export var sizes: PackedFloat32Array
@export var yaws: PackedFloat32Array
@export var colors: PackedColorArray
@export var stem_color := Color(0.85, 0.6, 0.85)
@export var leaf_glow := 0.22               # how much leaves and ferns light up in their own colour
@export var fern_glow := 0.35
@export var cap_glow := 0.8                 # mushroom caps
@export var max_lights := 14                # the biggest mushrooms also light the ground around them
@export var solid_cap_size := 2.2           # mushrooms at least this tall get a solid cap

const PLANT_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform float glow = 0.1;
uniform float sway = 0.06;
void vertex() {
	// Gentle wind: tips move more than the base, each plant on its own beat
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = sin(TIME * 1.3 + o.x * 0.37 + o.z * 0.29) * sway * UV.y * UV.y;
	VERTEX.x += w;
	VERTEX.z += w * 0.6;
}
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;                  // 0 on the midrib, 1 at the edge
	float rib = 1.0 - smoothstep(0.0, 0.07, across);
	float veins = smoothstep(0.82, 1.0, sin((UV.y * 16.0 - across * 3.0) * 3.14159)) * step(0.1, UV.y) * (1.0 - across);
	vec3 c = COLOR.rgb * (0.65 + 0.5 * (1.0 - across));
	c = mix(c, COLOR.rgb * 0.4 + vec3(0.55), rib * 0.55 + veins * 0.3);
	ALBEDO = c;
	ROUGHNESS = 0.55;
	EMISSION = COLOR.rgb * glow * (0.6 + rib);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}"""

const CAP_SHADER := """shader_type spatial;
uniform float glow = 1.5;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	// Brighter toward the rim, with a scatter of little glowing dots
	float rim = smoothstep(0.2, 1.0, length(lp.xz));
	vec3 cell = floor(lp * 7.0);
	float rnd = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float dot_ = step(0.86, rnd) * (1.0 - smoothstep(0.18, 0.32, length(fract(lp * 7.0) - 0.5)));
	vec3 c = COLOR.rgb * (0.55 + 0.45 * rim);
	ALBEDO = mix(c, vec3(0.85, 1.0, 1.0), dot_);
	ROUGHNESS = 0.25;
	EMISSION = (COLOR.rgb * (0.5 + 0.8 * rim) + vec3(0.7, 1.0, 1.0) * dot_ * 1.5) * glow;
}"""


func _ready() -> void:
	var leaves: Array[Transform3D] = []
	var leaf_cols: Array[Color] = []
	var fronds: Array[Transform3D] = []
	var frond_cols: Array[Color] = []
	var stems: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var cap_cols: Array[Color] = []
	var lights := 0
	for i in positions.size():
		var p := positions[i]
		var s := sizes[i]
		var base := Basis(Vector3.UP, yaws[i])
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 7919 + 13
		match kinds[i]:
			LEAVES:
				# A clump of 4-7 giant leaves fanning out from one spot
				var n := rng.randi_range(4, 7)
				for k in n:
					var b := base * Basis(Vector3.UP, TAU * k / n + rng.randf_range(-0.3, 0.3))
					b = b * Basis(Vector3.RIGHT, rng.randf_range(0.12, 0.5))          # lean outward
					var ls := s * rng.randf_range(0.7, 1.1)
					leaves.append(Transform3D(b * Basis.from_scale(Vector3.ONE * ls), p + Vector3(0, -0.05, 0)))
					leaf_cols.append(colors[i].lerp(colors[i].lightened(0.25), rng.randf() * 0.5))
			FERN:
				var n := rng.randi_range(8, 12)
				for k in n:
					var b := base * Basis(Vector3.UP, TAU * k / n + rng.randf_range(-0.2, 0.2))
					b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.25))
					var fs := s * rng.randf_range(0.75, 1.1)
					fronds.append(Transform3D(b * Basis.from_scale(Vector3.ONE * fs), p + Vector3(0, -0.03, 0)))
					frond_cols.append(colors[i].lerp(colors[i].darkened(0.3), rng.randf() * 0.6))
			MUSHROOM:
				var h := s
				var r := s * 0.09
				var cap_r := s * rng.randf_range(0.45, 0.6)
				var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(),
					rng.randf_range(0.0, 0.12))
				var b := base * tilt
				stems.append(Transform3D(b * Basis.from_scale(Vector3(r, h, r)), p + b * Vector3(0, h / 2 - 0.1, 0)))
				var top := p + b * Vector3(0, h - 0.1, 0)
				caps.append(Transform3D(b * Basis.from_scale(Vector3(cap_r, cap_r * 0.5, cap_r)), top))
				cap_cols.append(colors[i])
				if s >= solid_cap_size:
					var body := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					var cyl := CylinderShape3D.new()
					cyl.radius = cap_r * 0.9
					cyl.height = cap_r * 0.35
					cs.shape = cyl
					cs.position = top + Vector3(0, cap_r * 0.17, 0)
					body.add_child(cs)
					var cs2 := CollisionShape3D.new()
					var stem_shape := CylinderShape3D.new()
					stem_shape.radius = r
					stem_shape.height = h
					cs2.shape = stem_shape
					cs2.position = p + Vector3(0, h / 2, 0)
					body.add_child(cs2)
					add_child(body)
				if s >= solid_cap_size and lights < max_lights:
					var light := OmniLight3D.new()
					light.light_color = colors[i].lightened(0.3)
					light.light_energy = 1.4
					light.omni_range = cap_r * 4.0
					light.position = top - Vector3(0, 0.6, 0)
					add_child(light)
					lights += 1

	_add_multimesh(_leaf_mesh(), leaves, leaf_cols, _plant_material(leaf_glow, 0.05))
	_add_multimesh(_fern_mesh(), fronds, frond_cols, _plant_material(fern_glow, 0.08))
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = stem_color
	stem_mat.roughness = 0.5
	stem_mat.emission_enabled = true
	stem_mat.emission = stem_color
	stem_mat.emission_energy_multiplier = 0.25
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.75
	stem_mesh.bottom_radius = 1.0
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 10
	stem_mesh.rings = 1
	var stem_cols: Array[Color] = []
	stem_cols.resize(stems.size())
	stem_cols.fill(Color.WHITE)
	_add_multimesh(stem_mesh, stems, stem_cols, stem_mat)
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.0
	cap_mesh.height = 1.0
	cap_mesh.is_hemisphere = true
	cap_mesh.radial_segments = 24
	cap_mesh.rings = 8
	var cap_mat := ShaderMaterial.new()
	var cap_sh := Shader.new()
	cap_sh.code = CAP_SHADER
	cap_mat.shader = cap_sh
	cap_mat.set_shader_parameter("glow", cap_glow)
	_add_multimesh(cap_mesh, caps, cap_cols, cap_mat)


func _plant_material(glow: float, sway: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PLANT_SHADER
	m.shader = sh
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("sway", sway)
	return m


func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D], cols: Array[Color], material: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)


func _leaf_mesh() -> ArrayMesh:
	# One giant leaf, 1 unit long: a short stalk rising steeply, then a broad cupped blade that arcs over and droops.
	# UV.x runs across the blade (0.5 = midrib), UV.y along it (0 = base, 1 = tip).
	const ROWS := 26
	const COLS := 7
	const WIDTH := 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine: Array[Vector3] = []
	var tangent: Array[Vector3] = []
	var p := Vector3.ZERO
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var a := deg_to_rad(82.0 - 95.0 * pow(t, 1.6))          # elevation of the midrib
		var d := Vector3(0, sin(a), cos(a))
		spine.append(p)
		tangent.append(d)
		p += d / ROWS
	var grid := []
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var blade := clampf((t - 0.16) / 0.84, 0.0, 1.0)
		var w := 0.02 + WIDTH * 0.5 * pow(sin(PI * pow(blade, 0.75)), 0.85)
		var n: Vector3 = Vector3.RIGHT.cross(tangent[r]) * -1.0  # surface normal (up side of the blade)
		var row := []
		for c in COLS:
			var u := float(c) / (COLS - 1)
			var across := (u - 0.5) * 2.0
			var cup := across * across * w * 0.3 + sin(t * 30.0 + across * 2.0) * 0.006 * absf(across)
			row.append(spine[r] + Vector3.RIGHT * across * w + n * cup)
		grid.append(row)
	for r in ROWS:
		for c in COLS - 1:
			var quad := [Vector2i(r, c), Vector2i(r, c + 1), Vector2i(r + 1, c + 1), Vector2i(r + 1, c)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var q: Vector2i = quad[idx]
				st.set_uv(Vector2(float(q.y) / (COLS - 1), float(q.x) / ROWS))
				st.add_vertex(grid[q.x][q.y])
	st.generate_normals()
	return st.commit()


func _fern_mesh() -> ArrayMesh:
	# One fern frond, 1 unit long: an arching stem with pairs of narrow leaflets that shrink toward the tip.
	const SEGS := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := Vector3.ZERO
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var a := deg_to_rad(62.0 - 100.0 * pow(t, 1.4))
		var d := Vector3(0, sin(a), cos(a))
		pts.append(p)
		tans.append(d)
		p += d / SEGS
	for i in SEGS:
		var t := float(i) / SEGS
		var n: Vector3 = Vector3.RIGHT.cross(tans[i]) * -1.0
		# stem: a thin strip
		var sw := 0.012 * (1.0 - t * 0.7)
		_tri(st, pts[i] - Vector3.RIGHT * sw, pts[i] + Vector3.RIGHT * sw, pts[i + 1], Vector2(0.45, t), Vector2(0.55, t),
			Vector2(0.5, t + 1.0 / SEGS))
		if t < 0.08:
			continue
		var length := 0.2 * pow(1.0 - t, 0.55) + 0.02
		var base_w := 0.035 * (1.0 - t * 0.6)
		for side: float in [-1.0, 1.0]:
			var root := pts[i].lerp(pts[i + 1], 0.5)
			var tip := root + Vector3.RIGHT * side * length + tans[i] * length * 0.45 - n * length * 0.25
			var a := root - tans[i] * base_w
			var b := root + tans[i] * base_w
			var mid := root.lerp(tip, 0.5) + n * 0.01
			var u_tip := 0.5 + side * 0.5
			var u_mid := 0.5 + side * 0.25
			_tri(st, a, b, mid, Vector2(0.5, t), Vector2(0.5, t), Vector2(u_mid, t))
			_tri(st, a, mid, tip, Vector2(0.5, t), Vector2(u_mid, t), Vector2(u_tip, t))
			_tri(st, b, tip, mid, Vector2(0.5, t), Vector2(u_tip, t), Vector2(u_mid, t))
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
