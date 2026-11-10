shader_type canvas_item;

// The view from under the water (scripts/swim.gd): the world tinted sea blue-green, lighter towards the top where the
// sun comes down, darker round the edges, with a gentle wobble (none with Reduce motion) and soft light ripples.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.12, 0.5, 0.65, 1.0);
uniform float strength = 0.3;
uniform float wobble = 0.0035;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv += vec2(sin(uv.y * 28.0 + TIME * 1.8), cos(uv.x * 22.0 + TIME * 1.5)) * wobble;
	vec3 c = texture(screen_tex, uv).rgb;
	c = mix(c, tint.rgb, strength);
	float from_top = 1.0 - SCREEN_UV.y;
	c += tint.rgb * 0.22 * from_top * from_top;
	float rip = sin(SCREEN_UV.x * 40.0 + TIME * 1.3 + sin(SCREEN_UV.y * 17.0 + TIME)) * 0.5 + 0.5;
	c += vec3(0.6, 0.9, 1.0) * rip * 0.035 * from_top;
	float vig = smoothstep(0.95, 0.35, distance(SCREEN_UV, vec2(0.5)));
	c *= mix(0.7, 1.0, vig);
	COLOR = vec4(c, 1.0);
}
