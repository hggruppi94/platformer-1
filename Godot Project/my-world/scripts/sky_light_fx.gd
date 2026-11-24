extends RefCounted
# The pixel-art light for the Seraph's beams from the sky: the column of light itself (scenes/fx/sky_beam.png, a
# loop) and the splash where it lands (scenes/fx/light_splash.png, played once). Both sheets were made with the
# pixelfx pack (MIT), like the flames and the trees' twinkles; their sources and how to remake them are in
# source_art/fx/sky-beam.js and light-splash.js.
# Each is a quad that turns to face the camera round its upright (like the flames in fire_fx.gd), so it reads
# from every side and stays standing straight. No class_name on purpose: preload it.

const BEAM_SHEET := preload("res://scenes/fx/sky_beam.png")
const SPLASH_SHEET := preload("res://scenes/fx/light_splash.png")

# Each sheet: its grid, its frames, and how far up the sheet its foot (the pack's origin) is.
const BEAM := {"grid": Vector2(9, 3), "frames": 24, "fps": 20.0, "foot": 2.0 / 192.0, "wide": 64.0 / 192.0}
const SPLASH := {"grid": Vector2(9, 4), "frames": 29, "fps": 20.0, "foot": 28.0 / 176.0, "wide": 224.0 / 176.0}
# The column's visible light is about this much of the beam sheet's width (the rest is its dithered fringe and glow).
const BEAM_CORE := 27.0 / 64.0
# The splash's shockwave reaches about this much of the splash sheet's width at its widest.
const SPLASH_RING := 180.0 / 224.0

const SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D sheet : source_color, filter_nearest;
uniform vec2 grid = vec2(9.0, 3.0);
uniform float frames = 24.0;
uniform float fps = 20.0;
uniform bool looping = true;
uniform float frame_now = 0.0;
uniform float foot = 0.0;
uniform float alpha = 1.0;
uniform float bright = 1.3;

void vertex() {
	// Its own spot is the foot; its scale says how wide and tall the whole sheet is.
	vec3 base = MODEL_MATRIX[3].xyz;
	float w = length(MODEL_MATRIX[0].xyz);
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - base;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
	// The quad's middle is half its height above its bottom, and the foot is that far up from the bottom.
	vec3 world = base + right * VERTEX.x * w + vec3(0.0, (VERTEX.y + 0.5 - foot) * h, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float f = looping ? floor(mod(TIME * fps, frames)) : clamp(floor(frame_now), 0.0, frames - 1.0);
	vec2 cell = vec2(mod(f, grid.x), floor(f / grid.x));
	vec4 tex = texture(sheet, (UV + cell) / grid);
	// The pack's grey dust puffs read as dark blocks against the bright marble, so they're only a faint haze here.
	float grey = 1.0 - smoothstep(0.08, 0.2, max(max(tex.r, tex.g), tex.b) - min(min(tex.r, tex.g), tex.b));
	float dull = grey * (1.0 - smoothstep(0.75, 0.9, max(max(tex.r, tex.g), tex.b)));
	ALBEDO = tex.rgb * bright;
	ALPHA = tex.a * alpha * (1.0 - dull * 0.75);
}"""

static var _shader: Shader
static var _quad: QuadMesh


static func _mat(sheet: Texture2D, info: Dictionary, looping: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("sheet", sheet)
	m.set_shader_parameter("grid", info.grid)
	m.set_shader_parameter("frames", float(info.frames))
	m.set_shader_parameter("fps", info.fps)
	m.set_shader_parameter("looping", looping)
	m.set_shader_parameter("foot", info.foot)
	return m


static func _sprite(name: String, mat: ShaderMaterial) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _quad
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the quad round its foot, so the culling box has to cover where it can end up.
	mi.extra_cull_margin = 4.0
	return mi


static func beam(radius: float, height: float) -> MeshInstance3D:
	# The column of light, its foot at the node's spot. Grow it in with set_beam_width().
	var mi := _sprite("Pixel Beam", _mat(BEAM_SHEET, BEAM, true))
	mi.set_meta("radius", radius)
	mi.scale = Vector3(radius * 2.0 / BEAM_CORE, height, 1.0)
	return mi


static func set_beam_width(mi: MeshInstance3D, k: float) -> void:
	# k 0 is a hairline, 1 its full width; the shader reads only the scale's length, so it can't go to zero.
	var r := float(mi.get_meta("radius", 1.0))
	mi.scale.x = maxf(0.01, r * 2.0 / BEAM_CORE * k)


static func splash(parent: Node, at: Vector3, radius: float, soft: bool) -> MeshInstance3D:
	# The splash where a beam lands, played once and then gone.
	var mat := _mat(SPLASH_SHEET, SPLASH, false)
	mat.set_shader_parameter("alpha", 0.75 if soft else 1.0)
	var mi := _sprite("Light Splash", mat)
	var w := radius * 2.0 / SPLASH_RING
	mi.scale = Vector3(w, w / float(SPLASH.wide), 1.0)
	mi.add_to_group("light_splashes")
	parent.add_child(mi)
	mi.global_position = at
	var n := float(SPLASH.frames)
	var tw := mi.create_tween()
	tw.tween_method(func(f: float) -> void: mat.set_shader_parameter("frame_now", f), 0.0, n, n / SPLASH.fps)
	tw.tween_callback(mi.queue_free)
	return mi
