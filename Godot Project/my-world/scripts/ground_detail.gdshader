shader_type spatial;

// Ground detail (scripts/world_detail.gd puts this on every big flat ground mesh as a scene loads). It keeps the ground's
// own colour (its material's, times its vertex colours where it had them) and works detail into it from where each
// spot is in the world, so nothing needs a texture and every place gets it at once:
//   - big soft patches a little lighter, darker, bluer or greener, so a field isn't one flat colour from afar
//   - mottling and grain close up, fading out with distance (so it never shimmers)
//   - little flecks (pebbles, moss, petals), a few lighter and a few darker
//   - fine streaks like short grass or sand ripples
//   - layered bands on steep slopes, like rock strata
//   - in the Void, now and then a speck that twinkles (glints)

uniform vec4 base : source_color = vec4(1.0);
uniform bool use_vertex = false;
uniform bool vertex_srgb = true;   // the vertex colours were stored as sRGB (most builders' are)
uniform float roughness = 0.95;
uniform float metallic = 0.0;
uniform float detail = 1.0;          // how strong the close-up detail is
uniform float patches = 1.0;         // how strong the big patches are
uniform float glints = 0.0;          // 0: none, 1: the Void's twinkling specks
uniform vec3 glint_colour = vec3(0.7, 1.0, 1.0);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The same as a StandardMaterial3D with vertex_color_is_srgb: only turned to linear where the output isn't sRGB
	// already (the Compatibility renderer draws straight to sRGB, Forward+ doesn't)
	if (use_vertex && vertex_srgb && !OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), COLOR.rgb * (1.0 / 12.92),
			lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
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
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v / 0.9375;
}

void fragment() {
	vec3 c = base.rgb;
	if (use_vertex) {
		c *= COLOR.rgb;
	}
	float dist = length(VERTEX);
	float near = 1.0 - smoothstep(18.0, 60.0, dist);        // close-up detail fades out with distance
	float mid_range = 1.0 - smoothstep(60.0, 160.0, dist);
	vec2 p = wpos.xz;
	float slope = 1.0 - clamp(wnorm.y, 0.0, 1.0);

	// Big soft patches: lighter and darker, and a little bluer or greener, so a field has some life from afar
	float big = fbm(p * 0.03);
	float hue = fbm(p * 0.017 + vec2(31.0, 7.0));
	vec3 col = c * mix(1.0, 0.82 + 0.34 * big, patches);
	vec3 cool = col * vec3(0.9, 0.98, 1.12);
	vec3 warm = col * vec3(1.08, 1.04, 0.86);
	col = mix(col, cool, smoothstep(0.55, 0.8, hue) * 0.7 * patches);
	col = mix(col, warm, smoothstep(0.45, 0.2, hue) * 0.5 * patches);

	// Mottling and grain
	float mot = fbm(p * 0.35 + vec2(5.0, 11.0));
	col *= mix(1.0, 0.86 + 0.28 * mot, mid_range * detail);
	float grain = vnoise(p * 3.1) * 0.6 + vnoise(p * 7.7 + 3.0) * 0.4;
	col *= mix(1.0, 0.9 + 0.2 * grain, near * detail);

	// Short streaks, like tufts of grass or sand ripples (along one way, wobbling)
	vec2 sp = vec2(p.x * 9.0 + sin(p.y * 0.8) * 2.0, p.y * 1.6);
	float streak = smoothstep(0.62, 0.95, vnoise(sp));
	col = mix(col, col * 1.16, streak * near * detail * (1.0 - slope));

	// Flecks: little dots, mostly darker (pebbles, bits of moss), some lighter (petals, shells)
	vec2 g = p * 2.2;
	vec2 cell = floor(g);
	float r = hash(cell + 19.0);
	vec2 off = (vec2(hash(cell + 7.0), hash(cell + 3.0)) - 0.5) * 0.55;
	float size = mix(0.06, 0.16, hash(cell + 11.0));
	float fleck = step(0.78, r) * (1.0 - smoothstep(size * 0.6, size, length(fract(g) - 0.5 - off)));
	vec3 fleck_col = r > 0.93 ? col * 1.45 + vec3(0.05) : col * 0.62;
	col = mix(col, fleck_col, fleck * near * detail);

	// Steep ground: layered bands like rock strata, a little darker in the creases
	float strata = sin(wpos.y * 2.6 + fbm(p * 0.25) * 5.0) * 0.5 + 0.5;
	float steep = smoothstep(0.3, 0.65, slope);
	col *= mix(1.0, 0.78 + 0.3 * strata, steep * mid_range);

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	ROUGHNESS = roughness;
	METALLIC = metallic;

	// The Void's ground twinkles here and there: a speck that brightens and fades on its own beat
	if (glints > 0.0) {
		vec2 gg = p * 1.3;
		vec2 gc = floor(gg);
		float gr = hash(gc + 41.0);
		vec2 go = (vec2(hash(gc + 5.0), hash(gc + 9.0)) - 0.5) * 0.6;
		float spot = step(0.9, gr) * (1.0 - smoothstep(0.02, 0.06, length(fract(gg) - 0.5 - go)));
		float beat = pow(0.5 + 0.5 * sin(TIME * (1.0 + gr * 2.0) + gr * 40.0), 6.0);
		EMISSION = glint_colour * spot * beat * near * glints * 2.0;
	}
}
