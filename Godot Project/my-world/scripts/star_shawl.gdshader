shader_type spatial;
render_mode cull_disabled;

// The Seer's shawl (scripts/seer.gd): night-sky cloth stitched with little stars that drift slowly round her
// shoulders and twinkle, each at its own speed, like the sky turning over a whole night.

uniform vec3 deep : source_color = vec3(0.09, 0.06, 0.26);
uniform vec3 dusk : source_color = vec3(0.30, 0.15, 0.46);
uniform vec3 star : source_color = vec3(1.0, 0.93, 0.68);
uniform float density = 11.0;
uniform float drift = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * vec2(density * 2.0, density);
	uv.x += TIME * drift * density;
	vec2 cell = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash(cell);
	vec2 off = vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5;
	float d = length(f - off * 0.55);
	float on = step(0.5, h);
	float big = step(0.93, h);
	float twinkle = 0.45 + 0.55 * sin(TIME * (1.2 + h * 3.0) + h * 40.0);
	float s = on * smoothstep(0.13 + big * 0.08, 0.0, d) * twinkle;
	vec3 base = mix(dusk, deep, smoothstep(0.0, 0.8, UV.y));
	ALBEDO = base + star * s * 0.6;
	EMISSION = star * s * 2.2 + base * 0.08;
	ROUGHNESS = 0.9;
}
