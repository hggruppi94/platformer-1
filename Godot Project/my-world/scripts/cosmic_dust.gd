extends RefCounted

# Cosmic dust floating in the air (Hayden, 23 Nov 2026: "cosmic dust floating around", from the sparkle pack). No
# class_name: preload it.
#
# A few hundred little glowing motes drift slowly upwards and about in a box round the camera, each one breathing,
# twinkling and now and then flashing a four-point glint: scenes/fx/cosmic_mote.png, the pixelfx mote
# (source_art/fx/cosmic-mote.js: 40 frames at 20 fps, 7 x 6 cells of 24 px). It's one MultiMesh, and the drifting, the
# wrapping round the camera (so there's always dust wherever you go) and the animation are all in the shader, so it
# costs nothing a frame on the CPU. Each place has its own two colours (THEMES): the Void's lilac and teal, Dark
# Hollow's ghostly green, Lanternmoor's gold. Shard Isle has its own dream motes, and Earth has none (it's Earth).
# WorldDetail puts it in as each place loads ("Cosmic Dust", meta "cosmic_dust"); Reduce motion stops the drift.

const SHEET := preload("res://scenes/fx/cosmic_mote.png")
const NAME := "Cosmic Dust"
const BOX := 30.0               # the dust fills a box this wide round the camera
const COUNT := 420
const THEMES := {
	"res://scenes/town/town.tscn": [Color(0.78, 0.68, 1.0), Color(0.45, 1.0, 0.9), 1.0],
	"res://scenes/secret_garden/secret_garden.tscn": [Color(1.0, 0.88, 0.5), Color(0.75, 1.0, 0.6), 0.8],
	"res://scenes/portal_worlds/dark_hollow.tscn": [Color(0.6, 1.0, 0.75), Color(0.75, 0.6, 1.0), 1.0],
	"res://scenes/portal_worlds/lanternmoor.tscn": [Color(1.0, 0.85, 0.45), Color(0.8, 0.65, 1.0), 1.0],
	"res://scenes/portal_worlds/rootmind.tscn": [Color(0.95, 1.0, 0.55), Color(1.0, 0.75, 0.9), 0.8],
	"res://scenes/portal_worlds/frozen_moment.tscn": [Color(0.8, 0.95, 1.0), Color(0.7, 0.8, 1.0), 0.7],
	"res://scenes/portal_worlds/rhythm_springs.tscn": [Color(1.0, 0.7, 0.9), Color(1.0, 0.9, 0.55), 0.7],
	"res://scenes/portal_worlds/tide_reef.tscn": [Color(0.55, 1.0, 1.0), Color(0.75, 0.85, 1.0), 0.8],
	"res://scenes/portal_worlds/glenmoor.tscn": [Color(1.0, 0.92, 0.6), Color(0.65, 0.8, 1.0), 0.7],
	"res://scenes/portal_worlds/far_future.tscn": [Color(0.45, 0.95, 1.0), Color(1.0, 0.5, 0.95), 1.0],
}

const SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : source_color, filter_nearest;
uniform float box = 30.0;
uniform float motion = 1.0;
uniform float strength = 1.0;
uniform vec3 colour_a : source_color = vec3(0.78, 0.68, 1.0);
uniform vec3 colour_b : source_color = vec3(0.45, 1.0, 0.9);
varying float frame;
varying float fade;
varying vec3 tint;

void vertex() {
	// Each mote's own spot in the box is its instance's place; its custom data says its size, speed and colour.
	vec4 c = INSTANCE_CUSTOM;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float t = TIME * motion;
	vec3 drift = vec3(sin(t * 0.13 + c.x * 6.283) * 1.6, t * (0.12 + 0.2 * c.y), cos(t * 0.11 + c.z * 6.283) * 1.6);
	vec3 p = MODEL_MATRIX[3].xyz + drift;
	vec3 corner = cam - vec3(box * 0.5);
	vec3 w = mod(p - corner, vec3(box)) + corner;
	float size = mix(0.7, 1.5, c.y);
	vec3 world = w + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	frame = floor(mod(TIME * 20.0 + c.x * 40.0, 40.0));
	float d = distance(w, cam);
	// Not right in your face, and fading out at the box's edge so none pop in or out as they wrap round.
	fade = smoothstep(1.2, 3.0, d) * (1.0 - smoothstep(box * 0.32, box * 0.48, d));
	tint = mix(colour_a, colour_b, c.z);
}

void fragment() {
	vec2 cell = vec2(mod(frame, 7.0), floor(frame / 7.0));
	vec4 tex = texture(sheet, (UV + cell) / vec2(7.0, 6.0));
	float lum = max(tex.r, max(tex.g, tex.b));
	// The pack's purple turns to the place's colour, and the brightest bits (the core and the glint) stay white.
	ALBEDO = mix(tint * lum, vec3(1.0), smoothstep(0.85, 1.0, lum)) * 2.4 * strength;
	ALPHA = tex.a * fade;
}"""

static var _shader: Shader
static var _quad: QuadMesh


static func place(scene: Node, settings_motion := 1.0) -> MultiMeshInstance3D:
	# Puts the place's dust in (once). Returns it, or null for a place with none.
	if not (scene is Node3D) or not THEMES.has(scene.scene_file_path):
		return null
	var had := scene.get_node_or_null(NAME) as MultiMeshInstance3D
	if had:
		return had
	var theme: Array = THEMES[scene.scene_file_path]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _quad
	mm.instance_count = COUNT
	# The same dust every visit, so pictures and tests always see the same thing.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene.scene_file_path)
	for i in COUNT:
		var at := Vector3(rng.randf(), rng.randf(), rng.randf()) * BOX
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), 0.0))
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("sheet", SHEET)
	m.set_shader_parameter("box", BOX)
	m.set_shader_parameter("motion", settings_motion)
	m.set_shader_parameter("colour_a", theme[0])
	m.set_shader_parameter("colour_b", theme[1])
	m.set_shader_parameter("strength", theme[2])
	var dust := MultiMeshInstance3D.new()
	dust.name = NAME
	dust.multimesh = mm
	dust.material_override = m
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.top_level = true
	# The motes are moved round the camera in the shader, so the box they start in says nothing about where they're
	# drawn: never cull them.
	dust.custom_aabb = AABB(Vector3.ONE * -1.0e5, Vector3.ONE * 2.0e5)
	dust.set_meta("cosmic_dust", true)
	dust.set_meta("no_batch", true)
	scene.add_child(dust)
	return dust


static func set_motion(dust: MultiMeshInstance3D, on: bool) -> void:
	if dust and dust.material_override:
		(dust.material_override as ShaderMaterial).set_shader_parameter("motion", 1.0 if on else 0.0)
