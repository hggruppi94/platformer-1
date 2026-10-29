shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// The Gloops' goo, after Hayden's Gloop King picture: glossy green swirled with gold, with an oily rainbow sheen
// (teal, blue, purple) where the surface turns away from you, like a soap film. Built by tools/build_gloop.gd.
//
// The body mesh carries a drip mask in its vertex colours: red is how far a vertex is down one of the goo tongues
// hanging off a layer's edge, green is that tongue's own timing. The tongues slowly stretch down and snap back up
// on a loop, so the whole Gloop looks like it's always oozing. Feet and eye sockets turn the mask off.

uniform vec4 deep : source_color = vec4(0.08, 0.22, 0.1, 1.0);       // dark teal-green in the hollows of the swirl
uniform vec4 green : source_color = vec4(0.27, 0.42, 0.07, 1.0);
uniform vec4 gold : source_color = vec4(0.72, 0.6, 0.1, 1.0);
uniform float goldness : hint_range(0.0, 1.0) = 0.35;   // how much of the swirl is gold; the King is the goldest
uniform float sheen : hint_range(0.0, 1.5) = 1.0;        // strength of the rainbow film
uniform bool use_drip_mask = true;
uniform float sag = 0.03;                                // how far a tongue stretches, in the mesh's own units
uniform float ooze = 1.0;                                // 0 stops the oozing (Reduce motion turns it down)
uniform float flash = 0.0;                               // >0 for a moment after a hit

varying vec3 obj;

void vertex() {
	float m = use_drip_mask ? COLOR.r : 0.0;
	float cyc = fract(TIME * 0.32 + COLOR.g);
	// Stretch slowly for most of the loop, then spring back up quickly as the drop lets go
	float s = smoothstep(0.0, 0.82, cyc) * (1.0 - smoothstep(0.84, 1.0, cyc));
	VERTEX.y -= m * sag * s * ooze;
	obj = VERTEX;
}

void fragment() {
	// Marbled swirl that slides slowly downward, so the goo seems to flow
	float t = TIME * 0.18 * ooze;
	// Mostly sideways bands, bent about, like layers of poured goo
	float bend = sin(obj.x * 8.0 + obj.z * 5.0) * 3.0 + sin(obj.z * 10.0 - obj.x * 4.0 + t) * 2.0;
	float w = sin(obj.y * 18.0 + t * 3.0 + bend);
	w += 0.6 * sin(obj.y * 7.0 - bend * 1.3 + obj.x * 11.0 + t * 2.0);
	float f = clamp(w * 0.32 + 0.5, 0.0, 1.0);
	vec3 base = mix(deep.rgb, green.rgb, smoothstep(0.1, 0.7, f));
	base = mix(base, gold.rgb, smoothstep(1.0 - goldness * 0.5, 1.0, f) * 0.6);
	base = mix(base, gold.rgb * 0.8, smoothstep(0.35, 1.1, obj.y) * goldness * 0.35);   // goldier toward the top

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 film = 0.5 + 0.5 * cos(6.2832 * (vec3(0.0, 0.33, 0.67) + fres * 1.3 + f * 0.6 + 0.55));
	ALBEDO = mix(base, film * 0.55, fres * 0.55 * sheen);
	METALLIC = 0.25;
	ROUGHNESS = 0.07;
	SPECULAR = 0.75;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.04;
	RIM = 0.6;
	RIM_TINT = 0.8;
	EMISSION = film * fres * 0.4 * sheen + base * 0.05 + vec3(0.55, 0.65, 0.2) * flash;
}
