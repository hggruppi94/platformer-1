extends RefCounted

# Moving flames from the sparkle pack (Hayden, 23 Nov 2026: "Dont forget about the texture pack that we used to make
# the trees sparkly. It also has interesting cosmic and fire vfx. Can you look at places we could apply that in the
# game, such as campfires, torches"). No class_name: preload it.
#
# The builders make every flame as a little glowing shape (a ball, a cone, a bonfire of cones). Each one gets a
# "Pixel Flame" beside it: a quad that always turns to face the camera round its upright (so it never tips over when
# you look down at it) and plays scenes/fx/game_flame.png, the pixelfx flame (source_art/fx/game-flame.js: licking
# tongues, puffs and embers, 40 frames at 20 fps). The old shape is made see-through (transparency 1), so it can still
# be hidden or shown by the game as before and the pixel flame goes with it; its light is untouched.
#
# A flame is found by its material ("Torch Flame", "Lamp Flame", "Candle Flame") or by being called "Flame", and only
# while it glows (an unlit beacon's flame doesn't). Its colour turns the pack's orange fire to its own: Dark Hollow's
# lamps burn green. A "Flame" that's a group of shapes (Rhythm Springs' little bonfires) gets three flames side by side.
# WorldDetail dresses each place as it loads, before still pieces are merged, and every flame added later
# (scripts/world_detail.gd _on_added: a beacon lit, a stone flaring). Every dressed flame has meta "fire_fx".

const SHEET := preload("res://scenes/fx/game_flame.png")
const META := "fire_fx"
const NAME := "Pixel Flame"
const FLAME_MATS := ["Torch Flame", "Lamp Flame", "Candle Flame"]
const SOURCE_HUE := 0.07        # the pack's fire is orange; a flame of another colour turns it this far round
const TALL := 1.6               # the pixel flame's licking body is this many times the old flame's height...
const BODY := 32.0 / 80.0       # ...and its body is this much of the sheet's height (the rest is embers above)
const WIDE := 48.0 / 80.0       # the sheet's width over its height
const FAR := 60.0               # fades out by here, and isn't drawn past it
const BIGGEST := 3.0            # a "Flame" bigger than this across isn't a flame (a lantern, a whole beacon)

const SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : source_color, filter_nearest;
uniform float hue_shift = 0.0;
uniform float saturation = 1.0;
uniform float bright = 1.25;
uniform float far = 60.0;
varying float frame;
varying float fade;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	// Its own spot is the flame's foot; its scale says how wide and tall the whole sheet is.
	vec3 base = MODEL_MATRIX[3].xyz;
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 to_cam = cam - base;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	// The sheet's foot (row 72 of 80) sits on the spot: the quad's middle is 0.4 of its height above it.
	vec3 world = base + right * VERTEX.x * w + vec3(0.0, (VERTEX.y + 0.4) * h, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	float phase = fract(sin(dot(base.xz + base.y, vec2(12.9898, 78.233))) * 43758.5453) * 2.0;
	frame = floor(mod(TIME + phase, 2.0) / 0.05);
	fade = 1.0 - smoothstep(far * 0.7, far, length(cam - base));
}

void fragment() {
	vec2 cell = vec2(mod(frame, 9.0), floor(frame / 9.0));
	vec4 tex = texture(sheet, (UV + cell) / vec2(9.0, 5.0));
	vec3 hsv = rgb2hsv(tex.rgb);
	// The pack's grey smoke puffs read as dark blocks over a bright sky, so they're only a faint haze here.
	float smoke = (1.0 - smoothstep(0.2, 0.35, hsv.y)) * (1.0 - smoothstep(0.55, 0.75, hsv.z));
	hsv.x = fract(hsv.x + hue_shift);
	hsv.y = clamp(hsv.y * saturation, 0.0, 1.0);
	ALBEDO = hsv2rgb(hsv) * bright;
	ALPHA = tex.a * fade * (1.0 - smoke * 0.8);
}"""

static var _shader: Shader
static var _mats := {}          # hue bucket -> its ShaderMaterial, shared by every flame of that colour
static var _quad: QuadMesh


static func dress(root: Node) -> int:
	# Every flame under root that isn't dressed yet. Returns how many were.
	var n := 0
	for node in root.find_children("*", "Node3D", true, false):
		if check(node):
			n += 1
	if root is Node3D and check(root):
		n += 1
	return n


static func check(node: Node) -> bool:
	# Dresses node if it's a glowing flame not dressed yet.
	if not is_instance_valid(node) or not node.is_inside_tree() or node.has_meta(META):
		return false
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := _material(mi)
		if mat == null or not (mat.resource_name in FLAME_MATS or mi.name == "Flame"):
			return false
		if not _glows(mat) or _too_big(mi):
			return false
		_dress_mesh(mi, mat)
		return true
	if node.name == "Flame" and node.get_class() == "Node3D":
		# A bonfire: a group of glowing shapes.
		var parts: Array[MeshInstance3D] = []
		var col := Color()
		for c in node.get_children():
			if c is MeshInstance3D:
				var m := _material(c)
				if m and _glows(m):
					parts.append(c)
					col = _colour(m)
		if parts.is_empty():
			return false
		_dress_fire(node as Node3D, parts, col)
		return true
	return false


static func is_dressed(node: Node) -> bool:
	return node.has_meta(META)


static func flames_in(root: Node) -> Array:
	# Every pixel flame under root (tests and pictures read them).
	return root.find_children(NAME + "*", "MeshInstance3D", true, false)


static func _dress_mesh(mi: MeshInstance3D, mat: Material) -> void:
	var box := mi.get_aabb()
	var s := mi.global_transform.basis.get_scale()
	var tall := box.size.y * s.y
	var foot := mi.global_transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var h := maxf(tall, 0.06) * TALL / BODY
	_add(mi, foot, h, _colour(mat), NAME)
	mi.transparency = 1.0
	mi.set_meta(META, true)


static func _dress_fire(fire: Node3D, parts: Array[MeshInstance3D], col: Color) -> void:
	var box := AABB()
	var first := true
	for p in parts:
		var b: AABB = p.transform * p.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := fire.global_transform.basis.get_scale()
	var tall := box.size.y * s.y
	var across := maxf(box.size.x * s.x, box.size.z * s.z)
	var middle := fire.global_transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	var h := tall * TALL * 0.8 / BODY      # a bonfire's cones are tall already
	_add(fire, middle, h, col, NAME)
	# Two smaller flames either side, so a bonfire is wider than a torch (they turn with the camera too, so they're set
	# along the fire's own x; from the side they overlap the middle one, which still reads as one fire).
	var side := fire.global_transform.basis.x.normalized() * across * 0.28
	_add(fire, middle + side, h * 0.7, col, NAME + " 2")
	_add(fire, middle - side, h * 0.75, col, NAME + " 3")
	for p in parts:
		p.transparency = 1.0
	fire.set_meta(META, true)
	# Still pieces under a "no_batch" node are never merged (scripts/static_batch.gd), so the shapes stay where the
	# see-through setting can reach them.
	fire.set_meta("no_batch", true)


static func _add(parent: Node3D, foot: Vector3, h: float, col: Color, label: String) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var q := MeshInstance3D.new()
	q.name = label
	q.mesh = _quad
	q.material_override = _material_for(col)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.extra_cull_margin = maxf(h, 1.0)
	q.visibility_range_end = FAR
	q.set_meta(META, true)
	parent.add_child(q)
	q.global_transform = Transform3D(Basis.from_scale(Vector3(h * WIDE, h, h * WIDE)), foot)
	return q


static func _material_for(col: Color) -> ShaderMaterial:
	var hue := 0.0
	var sat := 1.0
	if col.s > 0.25:
		hue = wrapf(col.h - SOURCE_HUE, -0.5, 0.5)
	else:
		sat = 0.35         # a pale flame (a candle drawn nearly white) stays warm but softer
	var key := "%.2f_%.1f" % [hue, sat]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("sheet", SHEET)
	m.set_shader_parameter("hue_shift", hue)
	m.set_shader_parameter("saturation", sat)
	m.set_shader_parameter("far", FAR)
	_mats[key] = m
	return m


static func _material(mi: MeshInstance3D) -> Material:
	if mi.material_override:
		return mi.material_override
	if mi.mesh and mi.mesh.get_surface_count() > 0:
		var m := mi.get_surface_override_material(0)
		return m if m else mi.mesh.surface_get_material(0)
	return null


static func _glows(mat: Material) -> bool:
	if mat is StandardMaterial3D:
		var s := mat as StandardMaterial3D
		return s.emission_enabled and s.emission_energy_multiplier >= 0.3 and s.emission.v > 0.05
	return mat.resource_name in FLAME_MATS


static func _colour(mat: Material) -> Color:
	if mat is StandardMaterial3D:
		var s := mat as StandardMaterial3D
		return s.emission if s.emission_enabled and s.emission.v > 0.05 else s.albedo_color
	return Color(1.0, 0.55, 0.2)


static func _too_big(mi: MeshInstance3D) -> bool:
	var box := mi.get_aabb()
	var s := mi.global_transform.basis.get_scale()
	return maxf(box.size.x * s.x, maxf(box.size.y * s.y, box.size.z * s.z)) > BIGGEST
