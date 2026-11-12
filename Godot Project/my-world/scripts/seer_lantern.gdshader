shader_type spatial;
render_mode cull_back;

// The clouded glass of the Seer's lantern (scripts/seer.gd): soft mist that swirls round inside it, lilac and sea
// green, never still. She says it shows her what might be coming, in swirls.

uniform vec3 mist_a : source_color = vec3(0.78, 0.62, 1.0);
uniform vec3 mist_b : source_color = vec3(0.45, 0.92, 0.9);
uniform float speed = 0.6;
uniform float glow = 1.0;

void fragment() {
	vec2 p = UV * vec2(6.2832, 3.1416);
	float t = TIME * speed;
	float a = sin(p.x * 2.0 + sin(p.y * 3.0 + t) * 1.6 + t) * 0.5 + 0.5;
	float b = sin(p.y * 4.0 - t * 1.3 + sin(p.x * 3.0 - t * 0.7) * 1.2) * 0.5 + 0.5;
	float m = a * b;
	ALBEDO = vec3(0.9, 0.9, 1.0) * 0.25;
	EMISSION = mix(mist_a, mist_b, b) * (0.35 + 1.7 * m) * glow;
	ROUGHNESS = 0.08;
	ALPHA = 0.78 + 0.2 * m;
}
