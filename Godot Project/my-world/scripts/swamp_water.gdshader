shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

// Swamp water (scripts/swamp.gd): murky, still water with drifting scum. Lanternmoor's Mothmire is dark teal murk you
// can wade through; Dusk's Embrace's Poison Mire is the same shader turned acid green and glowing.
//
// Before writing it we compared open-source Godot water (Hayden's rule): Malidos/Stylized-Water-Shader (CC0: read the
// depth texture, work out how much water lies between the surface and the bed, and tint by it, so shallows show the
// bed and the middle goes murky; a noisy foam edge where the water meets things), paddy-exe/Godot-3D-Stylized-Water
// (MIT: the same idea, simpler, a foam rim from linearised depth) and Chrisknyfe/boujie_water_shader (MIT: Gerstner
// waves, refraction: lovely for the sea, far too lively for a still bog). This takes the first two's depth tint and
// edge, adds no waves at all, and swaps foam for slow patches of duckweed scum and (poison only) glowing specks and
// bubble rings. Everything is worked out in the shader from world position, so it needs no textures.

uniform vec4 murk : source_color = vec4(0.14, 0.24, 0.24, 1.0);      // the shallows' colour
uniform vec4 deep : source_color = vec4(0.03, 0.07, 0.08, 1.0);      // the middle, where you can't see the bed
uniform vec4 scum : source_color = vec4(0.26, 0.36, 0.18, 1.0);      // the duckweed (or goo) floating on top
uniform vec4 glow_colour : source_color = vec4(0.5, 1.0, 0.3, 1.0);
uniform float glow : hint_range(0.0, 4.0) = 0.0;                      // >0 for the poison: specks and rings shine
uniform float scum_amount : hint_range(0.0, 1.0) = 0.45;
uniform float sheen = 0.55;                                          // how much of the sky it mirrors
uniform float murk_depth = 0.45;                                      // metres of water to go fully murky
uniform float flow = 0.03;                                            // how fast the scum drifts
uniform float motion = 1.0;                                           // Reduce motion turns this down
uniform float clear_alpha : hint_range(0.0, 1.0) = 0.6;
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
	// How much water is between the surface here and whatever's under it (the bed, a leg, a stone)
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * ndc;
	behind.xyz /= behind.w;
	float thick = clamp(VERTEX.z - behind.z, 0.0, 20.0);
	float murky = 1.0 - exp(-thick / max(murk_depth, 0.01));

	float t = TIME * flow * motion;
	vec2 uv = wpos.xz * 0.32;
	float n = fbm(uv + vec2(t, t * 0.6));
	float patches = smoothstep(0.72 - scum_amount * 0.3, 0.8 - scum_amount * 0.2, n);
	// A ring of scum hugging anything that pokes out of the water (stones, stilts, reeds, legs)
	float edge = 1.0 - smoothstep(0.0, 0.18 + 0.12 * vnoise(wpos.xz * 2.5), thick);
	float weed = clamp(max(patches, edge * 0.85), 0.0, 1.0);

	// Little ripples, made from the noise's slope (no waves: it's a still bog)
	float e = 0.05;
	float h0 = fbm(wpos.xz * 1.4 + vec2(t * 3.0, -t * 2.0));
	float hx = fbm((wpos.xz + vec2(e, 0.0)) * 1.4 + vec2(t * 3.0, -t * 2.0));
	float hz = fbm((wpos.xz + vec2(0.0, e)) * 1.4 + vec2(t * 3.0, -t * 2.0));
	vec3 nm = normalize(vec3((h0 - hx) * 2.5, (h0 - hz) * 2.5, 1.0));
	NORMAL_MAP = mix(nm, vec3(0.0, 0.0, 1.0), weed * 0.7) * 0.5 + 0.5;

	vec3 col = mix(murk.rgb, deep.rgb, murky);
	col = mix(col, scum.rgb * (0.8 + 0.4 * vnoise(wpos.xz * 6.0)), weed);
	ALBEDO = col;
	ROUGHNESS = mix(0.06 + 0.3 * (0.55 - sheen), 0.85, weed);
	SPECULAR = sheen;
	METALLIC = 0.0;
	ALPHA = clamp(mix(clear_alpha, 0.97, murky) + weed, 0.0, 1.0);

	if (glow > 0.0) {
		// Poison: specks that pulse, and rings where a bubble's just popped
		vec2 cell = floor(wpos.xz * 2.2);
		float r = hash(cell);
		// A little round dot somewhere in the cell, not the whole square
		vec2 dot_at = (cell + 0.25 + 0.5 * vec2(hash(cell + 1.7), hash(cell + 5.1))) / 2.2;
		float dot_r = 0.05 + 0.05 * hash(cell + 9.4);
		float speck = step(0.9, r) * (1.0 - smoothstep(dot_r * 0.6, dot_r, length(wpos.xz - dot_at)));
		speck *= 0.5 + 0.5 * sin(TIME * 2.5 * motion + r * 40.0);
		vec2 bc = floor(wpos.xz / 3.0);
		vec2 bcentre = (bc + vec2(hash(bc), hash(bc + 7.3))) * 3.0;
		float life = fract(TIME * 0.35 * motion + hash(bc + 3.1));
		float ring = 1.0 - smoothstep(0.0, 0.08, abs(length(wpos.xz - bcentre) - life * 1.4));
		ring *= (1.0 - life) * step(0.5, hash(bc + 11.0));
		EMISSION = glow_colour.rgb * glow * (0.12 + 0.25 * weed + speck * 1.4 + ring * 1.2);
	}
}
