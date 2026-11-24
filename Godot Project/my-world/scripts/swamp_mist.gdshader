shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// Low mist drifting over a swamp (scripts/swamp.gd): big flat sheets just over the water, faded where they meet
// anything (soft edges from the depth texture, so they never show a hard line through a tree) and towards the camera.
// We compared Bauxitedev/volumetric-fog-demo (MIT: fog from billboard particles; slow, and turns with the camera) with
// Godot's own FogVolume; the swamp uses FogVolumes for the real haze (Settings > Lighting Nice and Best) and these
// cheap sheets so the mist still shows on Simple.

uniform vec4 colour : source_color = vec4(0.7, 0.75, 0.9, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform float drift = 0.04;
uniform float motion = 1.0;
uniform float soft = 1.2;                    // metres over which it fades where it meets things
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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * drift * motion;
	float n = vnoise(wpos.xz * 0.08 + vec2(t, t * 0.7)) * 0.6 + vnoise(wpos.xz * 0.21 - vec2(t * 1.6, t)) * 0.4;
	float a = smoothstep(0.35, 0.85, n) * strength;
	// Soft where it meets the ground, a stone, a leg
	float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
#else
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
#endif
	vec4 behind = INV_PROJECTION_MATRIX * ndc;
	behind.xyz /= behind.w;
	a *= clamp((VERTEX.z - behind.z) / soft, 0.0, 1.0);
	// And thin right in front of the camera, so walking through it doesn't fill the screen
	a *= smoothstep(1.5, 7.0, -VERTEX.z);
	// Round the sheet's own edge
	vec2 uv = UV * 2.0 - 1.0;
	a *= 1.0 - smoothstep(0.6, 1.0, length(uv));
	ALBEDO = colour.rgb;
	ALPHA = a;
}
