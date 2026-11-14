shader_type canvas_item;

// The flow (scripts/race_flow.gd): a whole set of a race's speed coins and the edges of the screen go soft and
// blurry, slowly melting and drifting through the colours, while the middle (where you're going) stays sharp.
// strength fades it in and out; melt is 0 with Reduce motion (no wobble), colour is lower with Reduce flashing.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
uniform float melt = 1.0;
uniform float colour = 1.0;

vec3 hue_turn(vec3 c, float a) {
	// Turn a colour round the colour wheel (round the grey axis), keeping how bright it is
	vec3 k = vec3(0.57735);
	float cs = cos(a);
	return c * cs + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cs);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_mid = uv - vec2(0.5);
	float r = length(from_mid * vec2(1.5, 1.0));
	float edge = smoothstep(0.3, 0.85, r) * strength;
	// Melting: the edges drift and drip, a little more the further out
	vec2 drip = vec2(sin(uv.y * 9.0 + TIME * 2.1 + sin(uv.x * 5.0 + TIME)), cos(uv.x * 7.0 - TIME * 1.7)) * 0.016;
	drip.y += abs(sin(uv.x * 13.0 + TIME * 0.9)) * 0.018;
	vec2 u = uv + drip * melt * edge;
	// Blur: a ring of samples, wider and softer towards the edge
	float rad = 0.014 * edge;
	float lod = edge * 2.5;
	vec3 acc = textureLod(screen_tex, u, lod).rgb;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		acc += textureLod(screen_tex, u + vec2(cos(a), sin(a)) * rad, lod).rgb;
	}
	vec3 c = acc / 9.0;
	// The colours swirl round the edge
	float ang = atan(from_mid.y, from_mid.x);
	c = mix(c, hue_turn(c, ang * 2.0 + TIME * 1.4 + r * 6.0), edge * 0.6 * colour);
	c += vec3(0.4, 0.22, 0.65) * edge * 0.22 * colour;
	COLOR = vec4(c, 1.0);
}
