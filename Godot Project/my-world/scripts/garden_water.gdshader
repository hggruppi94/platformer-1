shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

// The rebuilt Secret Garden's water (26 Nov 2026): Temple Lake, the Lily Pond, the koi pond, the pools and the streams.
// Clear, still garden water: the shallows show the bed through a green-blue tint, the middle goes deep, little ripples
// run over it and a soft pale edge hugs the shore and anything standing in it. It's the same depth trick as
// scripts/swamp_water.gdshader (from Malidos/Stylized-Water-Shader, CC0, and paddy-exe/Godot-3D-Stylized-Water, MIT:
// read the depth texture and tint by how much water lies between the surface and the bed), made clear and bright, with a
// flow along x for the streams (flow_dir).

uniform vec4 shallow : source_color = vec4(0.36, 0.62, 0.58, 1.0);
uniform vec4 deep : source_color = vec4(0.12, 0.32, 0.38, 1.0);
uniform vec4 edge_colour : source_color = vec4(0.85, 0.93, 0.92, 1.0);
uniform float clear_depth = 0.9;                // metres of water to go fully deep
uniform float sheen = 0.6;
uniform float ripple = 1.0;
uniform vec2 flow_dir = vec2(0.0, 0.0);         // metres a second the ripples drift (a stream)
uniform float motion = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * ndc;
	behind.xyz /= behind.w;
	float thick = clamp(VERTEX.z - behind.z, 0.0, 30.0);
	float deepness = 1.0 - exp(-thick / max(clear_depth, 0.01));

	float t = TIME * motion;
	vec2 drift = flow_dir * t + vec2(t * 0.05, t * 0.03);
	float e = 0.05;
	vec2 p = wpos.xz * 0.9 - drift * 0.9;
	float h0 = fbm(p);
	float hx = fbm(p + vec2(e, 0.0));
	float hz = fbm(p + vec2(0.0, e));
	vec3 nm = normalize(vec3((h0 - hx) * 3.0 * ripple, (h0 - hz) * 3.0 * ripple, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;

	// A soft pale line where it meets the shore and anything in it, breaking up a little
	float edge = 1.0 - smoothstep(0.0, 0.12 + 0.1 * vnoise(wpos.xz * 3.0 + t * 0.2), thick);
	vec3 col = mix(shallow.rgb, deep.rgb, deepness);
	col = mix(col, edge_colour.rgb, edge * 0.55);
	ALBEDO = col;
	ROUGHNESS = 0.04 + 0.2 * (1.0 - sheen);
	SPECULAR = sheen;
	METALLIC = 0.0;
	ALPHA = clamp(mix(0.55, 0.94, deepness) + edge * 0.3, 0.0, 1.0);
}
