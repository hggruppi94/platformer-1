extends Node3D

# Builds the town's trees when the scene loads (MultiMesh data can't be baked from a headless build).
# Positions/sizes/colors and the look (bark, glow, canopy shape) are written by tools/build_town.gd.
#
# Galaxity's trees are sparkly alien trees, in three kinds picked from each tree's spot so a rebuild keeps them:
# orb trees (a leaning stalk with a glowing ball on top and two little ones on side branches), spire trees (three
# twisted, faceted cones stacked up like a crystal fir) and parasol trees (a tall stalk under a wide flat cap with
# glowing bulbs hanging round its edge). Their canopies shimmer, glow at the rim and glitter with specks of light,
# and twinkles from a pixelfx sprite sheet (scenes/town/tree_twinkle.png, effect pickups/tree-twinkle) wink on and
# off round each one. Nothing here is solid, as before.

@export var positions: PackedVector3Array
@export var sizes: PackedFloat32Array
@export var colors: PackedColorArray
@export var bark_color := Color(0.45, 0.3, 0.18)
@export var glow := 0.0                    # how much the canopies light up in their own colour
@export var canopy_stretch := 1.15         # canopy height / width

enum Kind { ORB, SPIRE, PARASOL }
const TWINKLES_PER_TREE := 8
const TWINKLE_SHEET := preload("res://scenes/town/tree_twinkle.png")

# The canopy: its own colour lit a little brighter at the top, a glowing rim, a slow shimmer of light rolling up
# through it, and specks that flash white one at a time. The specks are cells of a grid in the shape's own space,
# so they stay put on the canopy as the camera moves; each tree's position seeds them so no two trees match.
const LEAVES_SHADER := """shader_type spatial;
render_mode cull_back;
uniform float glow = 0.0;
uniform float specks = 1.0;
varying vec3 local_pos;
varying float seed;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	seed = hash(floor(MODEL_MATRIX[3].xyz * 3.0));
}

void fragment() {
	vec3 base = COLOR.rgb;
	float up = clamp(local_pos.y * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = base * mix(0.55, 1.1, up);
	ROUGHNESS = 0.35;
	SPECULAR = 0.7;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float shimmer = 0.75 + 0.35 * sin(TIME * 0.9 - local_pos.y * 4.0 + seed * 6.283);
	// Soft swirling bands of lighter colour, turning slowly round the canopy
	float swirl = smoothstep(0.55, 1.0, sin(atan(local_pos.z, local_pos.x) * 3.0 + local_pos.y * 5.0 + TIME * 0.4 + seed * 6.283));
	ALBEDO = mix(ALBEDO, mix(base, vec3(1.0), 0.45), swirl * 0.35);
	vec3 cell = floor(local_pos * 9.0);
	float h = hash(cell + seed * 17.0);
	float d = length(fract(local_pos * 9.0) - 0.5);
	float flash = pow(max(sin(TIME * (1.2 + h * 2.5) + h * 40.0), 0.0), 8.0);
	float speck = step(0.72, h) * smoothstep(0.32, 0.04, d) * flash * specks;
	EMISSION = base * glow * shimmer * (1.0 + swirl * 0.5) + mix(base, vec3(1.0), 0.4) * rim * 1.1
		+ vec3(1.0, 0.97, 1.0) * speck * 5.0;
}"""

# A twinkle: a camera-facing quad playing the sprite sheet's 16 frames once, then nothing until its next turn.
# INSTANCE_CUSTOM holds when in its own cycle it starts (x, 0..1) and how long the cycle is (y, seconds).
const TWINKLE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : source_color, filter_nearest;
uniform float frame_time = 0.05;
uniform float far = 110.0;
varying float frame;
varying float fade;

void vertex() {
	float period = max(INSTANCE_CUSTOM.y, 0.8);
	float t = mod(TIME + INSTANCE_CUSTOM.x * period, period);
	frame = floor(t / frame_time);
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y,
		INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	float dist = length((VIEW_MATRIX * MODEL_MATRIX[3]).xyz);
	fade = 1.0 - smoothstep(far * 0.7, far, dist);
}

void fragment() {
	if (frame > 15.5) {
		discard;
	}
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec4 tex = texture(sheet, (UV + cell) / 4.0);
	ALBEDO = tex.rgb * mix(vec3(1.0), COLOR.rgb, 0.5) * 2.6;
	ALPHA = tex.a * fade;
}"""

# Filled in _ready: what each tree is made of, so tests and tools can look without reading MultiMeshes (which are
# empty when headless).
var kinds: PackedInt32Array
var twinkle_spots: PackedVector3Array


static func kind_of(p: Vector3) -> Kind:
	# From the spot, not the index, so a tree keeps its kind if the builder adds or drops others.
	var h := absi(int(floor(p.x * 7.31)) * 73856093 ^ int(floor(p.z * 5.17)) * 19349663)
	return (h % 3) as Kind


func _ready() -> void:
	var orbs: Array[Transform3D] = []        # orb tree balls, parasol caps and bulbs: spheres
	var orb_colors: Array[Color] = []
	var cones: Array[Transform3D] = []       # spire tiers
	var cone_colors: Array[Color] = []
	var stalks: Array[Transform3D] = []      # trunks and branches
	var twinkles: Array[Transform3D] = []
	var twinkle_colors: Array[Color] = []
	var twinkle_custom: Array[Color] = []
	var rng := RandomNumberGenerator.new()
	kinds.resize(positions.size())
	for i in positions.size():
		var p := positions[i]
		var s := sizes[i]
		var c := colors[i]
		rng.seed = hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0)))
		var kind := kind_of(p)
		kinds[i] = kind
		var spin := rng.randf() * TAU
		var surface: Array[Vector3] = []      # points on this tree's canopy for its twinkles
		match kind:
			Kind.ORB:
				# A stalk leaning a little, a big ball on top, and two short branches with little balls
				var lean := Basis(Vector3(cos(spin), 0, sin(spin)), rng.randf_range(0.08, 0.2))
				var h := 2.0 + s * 1.5
				var top := p + lean * Vector3(0, h, 0)
				stalks.append(_stalk(p + Vector3(0, -0.3, 0), top, 1.0))
				var r := s * 0.85
				orbs.append(Transform3D(Basis().scaled(Vector3(r, r * 1.05, r)), top + Vector3(0, r * 0.6, 0)))
				orb_colors.append(c)
				surface.append_array(_on_ball(top + Vector3(0, r * 0.6, 0), Vector3(r, r * 1.05, r), 4, rng))
				for side in [-1.0, 1.0]:
					var out := Vector3(cos(spin + side * 1.9), 0, sin(spin + side * 1.9))
					var from := p + lean * Vector3(0, h * rng.randf_range(0.5, 0.62), 0)
					var to := from + out * s * 0.8 + Vector3(0, s * 0.55, 0)
					stalks.append(_stalk(from, to, 0.45))
					var br := s * rng.randf_range(0.32, 0.42)
					orbs.append(Transform3D(Basis().scaled(Vector3.ONE * br), to + Vector3(0, br * 0.5, 0)))
					orb_colors.append(_shifted(c, 0.12 * side))
					surface.append_array(_on_ball(to + Vector3(0, br * 0.5, 0), Vector3.ONE * br, 2, rng))
			Kind.SPIRE:
				# Three faceted cones stacked, each turned against the last and nudged a little off the middle so
				# the spire twists, on a short trunk, with a glowing star ball on its tip
				var base_y := 0.9 + s * 0.2
				stalks.append(_stalk(p + Vector3(0, -0.3, 0), p + Vector3(0, base_y + 0.4, 0), 1.0))
				var y := base_y
				var off := Vector3.ZERO
				for tier in 3:
					var w := s * (1.05 - tier * 0.27)
					var th := s * canopy_stretch * (0.75 - tier * 0.1)
					var basis := Basis(Vector3.UP, spin + tier * 1.1).scaled(Vector3(w, th, w))
					cones.append(Transform3D(basis, p + off + Vector3(0, y + th * 0.5, 0)))
					cone_colors.append(_shifted(c, tier * 0.06))
					surface.append_array(_on_cone(p + off + Vector3(0, y, 0), w, th, 3 - int(tier == 2), rng))
					y += th * 0.6
					off += Vector3(cos(spin + tier * 2.1), 0, sin(spin + tier * 2.1)) * s * 0.12
				var tip := p + off + Vector3(0, y + s * canopy_stretch * 0.2, 0)
				orbs.append(Transform3D(Basis().scaled(Vector3.ONE * s * 0.16), tip))
				orb_colors.append(_shifted(c, 0.5).lightened(0.45))
			Kind.PARASOL:
				# A tall stalk, a wide flat cap, and glowing bulbs hanging round its edge
				var h := 2.6 + s * 1.5
				var top := p + Vector3(0, h, 0)
				stalks.append(_stalk(p + Vector3(0, -0.3, 0), top, 0.9))
				var w := s * 1.45
				var cap := Vector3(w, s * 0.5, w)
				orbs.append(Transform3D(Basis().scaled(cap), top))
				orb_colors.append(c)
				surface.append_array(_on_ball(top, cap, 5, rng, true))
				var bulb_color := _shifted(c, 0.5).lightened(0.3)
				var bulbs := 6 + int(s * 2.0)
				for b in bulbs:
					var a := spin + TAU * b / bulbs
					var hang := top + Vector3(cos(a) * w * 0.82, -s * 0.25 - rng.randf_range(0.1, 0.5), sin(a) * w * 0.82)
					orbs.append(Transform3D(Basis().scaled(Vector3.ONE * s * 0.13), hang))
					orb_colors.append(bulb_color)
					if b % 2 == 0:
						surface.append(hang)
		# Twinkles: on the canopy, each with its own start and a cycle of 1.4 to 3 s, a bit bigger on big trees
		for t in mini(surface.size(), TWINKLES_PER_TREE):
			var at: Vector3 = surface[t]
			twinkles.append(Transform3D(Basis().scaled(Vector3.ONE * (1.1 + s * 0.45)), at))
			twinkle_colors.append(c.lightened(0.4))
			twinkle_custom.append(Color(rng.randf(), rng.randf_range(1.4, 3.0), 0, 0))
			twinkle_spots.append(at)

	var leaves := ShaderMaterial.new()
	leaves.shader = Shader.new()
	leaves.shader.code = LEAVES_SHADER
	leaves.set_shader_parameter("glow", glow)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = bark_color
	bark.roughness = 0.6
	bark.emission_enabled = true
	bark.emission = bark_color.lightened(0.2)
	bark.emission_energy_multiplier = 0.3
	var sparkle := ShaderMaterial.new()
	sparkle.shader = Shader.new()
	sparkle.shader.code = TWINKLE_SHADER
	sparkle.set_shader_parameter("sheet", TWINKLE_SHEET)

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7                    # few sides, so the spires look cut like crystal
	cone.rings = 1
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.12
	stalk.bottom_radius = 0.22
	stalk.height = 1.0
	stalk.radial_segments = 6
	var quad := QuadMesh.new()

	_add("Canopies", sphere, orbs, orb_colors, leaves)
	_add("Spires", cone, cones, cone_colors, leaves)
	_add("Trunks", stalk, stalks, [], bark)
	var tw := _add("Twinkles", quad, twinkles, twinkle_colors, sparkle, twinkle_custom)
	tw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add(node_name: String, mesh: Mesh, xforms: Array[Transform3D], cols: Array, mat: Material,
		custom: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, custom[i])
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = mat
	add_child(inst)
	return inst


func _stalk(from: Vector3, to: Vector3, thick: float) -> Transform3D:
	# A unit cylinder stretched from one point to another (its own y axis runs along it)
	var along := to - from
	var y := along.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * thick, y * along.length(), z * thick), (from + to) * 0.5)


func _shifted(c: Color, hue: float) -> Color:
	return Color.from_hsv(fposmod(c.h + hue, 1.0), c.s, c.v, c.a)


func _on_ball(centre: Vector3, radii: Vector3, n: int, rng: RandomNumberGenerator, top_only := false) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in n:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3 if not top_only else 0.2, 1), rng.randf_range(-1, 1))
		out.append(centre + dir.normalized() * radii * 1.05)
	return out


func _on_cone(base: Vector3, w: float, h: float, n: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in n:
		var up := rng.randf_range(0.1, 0.7)
		var a := rng.randf() * TAU
		out.append(base + Vector3(cos(a) * w * (1.0 - up) * 1.05, h * up, sin(a) * w * (1.0 - up) * 1.05))
	return out
