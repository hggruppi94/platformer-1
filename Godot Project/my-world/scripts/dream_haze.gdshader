shader_type canvas_item;

// Shard Isle's dream haze (scripts/shard_sky.gd): the edges of the screen shimmer softly through the rainbow and
// ripple a little, as if the whole island is a dream, while the middle (where you're looking) stays clear.
// strength is the everyday haze; trip goes up to 1 for a moment each time you step through a Warp Ring, when the
// picture swirls and splits into colours, then settles. melt is 0 with Reduce motion (nothing moves the picture),
// colour is lower with Reduce flashing.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.35;
uniform float trip = 0.0;
uniform float melt = 1.0;
uniform float colour = 1.0;

vec3 hue_turn(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float cs = cos(a);
	return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 m = uv - vec2(0.5);
	float r = length(m * vec2(1.5, 1.0));
	float ang = atan(m.y, m.x);
	float edge = smoothstep(0.38, 0.95, r) * strength;
	float all_k = trip;
	// Ripples: gentle waves at the edges, and a swirl round the middle on a trip
	vec2 wave = vec2(sin(uv.y * 11.0 + TIME * 1.3), cos(uv.x * 9.0 + TIME * 1.1)) * 0.006 * edge;
	float swirl = all_k * (0.35 * (1.0 - smoothstep(0.0, 0.8, r))) * sin(TIME * 2.0 + r * 8.0);
	vec2 sm = vec2(cos(swirl) * m.x - sin(swirl) * m.y, sin(swirl) * m.x + cos(swirl) * m.y);
	vec2 u = vec2(0.5) + sm + (wave + vec2(sin(r * 30.0 - TIME * 4.0)) * 0.004 * all_k) * melt;
	u = mix(uv, u, melt);
	// Colours split apart a little: red one way, blue the other
	float split = (0.0025 * edge + 0.012 * all_k) * colour;
	vec2 dir = normalize(m + vec2(0.0001)) * split;
	vec3 c;
	c.r = textureLod(screen_tex, u + dir, 0.0).r;
	c.g = textureLod(screen_tex, u, 0.0).g;
	c.b = textureLod(screen_tex, u - dir, 0.0).b;
	// The rainbow shimmer round the edge, flowing slowly
	float k = clamp(edge * 0.55 + all_k * 0.4, 0.0, 1.0) * colour;
	c = mix(c, hue_turn(c, ang * 2.0 + TIME * 0.6 + r * 5.0), k);
	c += (0.5 + 0.5 * cos(6.28318 * (vec3(r * 1.5 - TIME * 0.12) + vec3(0.0, 0.33, 0.67)))) * (edge * 0.05 + all_k * 0.06) * colour;
	COLOR = vec4(c, 1.0);
}
