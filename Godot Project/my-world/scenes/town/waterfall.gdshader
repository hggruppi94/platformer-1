shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(0.75, 0.92, 1.0, 0.85);
void fragment() {
	float s = fract(UV.y * 5.0 + UV.x * 0.7 - TIME * 1.4);
	ALBEDO = mix(color.rgb, vec3(1.0), smoothstep(0.75, 1.0, s) * 0.7);
	ALPHA = color.a;
}