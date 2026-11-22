shader_type sky;

// Shard Isle's dream sky (scripts/shard_sky.gd). The island floats in the middle of nowhere, so the sky goes all
// the way round, above and below: a teal-to-lilac gradient with a slowly swirling nebula that drifts through the
// colours, twinkling stars, rainbow aurora ribbons, a big ringed planet and a little moon. motion is how fast
// things drift (lower with Reduce motion), colour is how bright the rainbow parts are (lower with Reduce flashing).
// The light the island gets from the sky (the cubemap passes) only uses the gentle gradient, so it stays steady
// and cheap while the sky itself moves.

uniform vec3 top_colour : source_color = vec3(0.08, 0.17, 0.38);
uniform vec3 horizon_colour : source_color = vec3(0.82, 0.66, 0.92);
uniform vec3 below_colour : source_color = vec3(0.16, 0.28, 0.5);
// The island's light from the sky keeps the builder's brighter gradient, so the island isn't darker than before
uniform vec3 light_top : source_color = vec3(0.32, 0.62, 0.66);
uniform vec3 light_below : source_color = vec3(0.5, 0.68, 0.78);
uniform float motion = 1.0;
uniform float colour = 1.0;
uniform vec3 planet_dir = vec3(-0.55, 0.42, -0.72);
uniform vec3 moon_dir = vec3(0.62, 0.55, 0.56);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * noise3(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return s;
}

vec3 palette(float t) {
	// A soft rainbow that leans teal, pink and gold, like the Warp Rings
	return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0) * t + vec3(0.0, 0.33, 0.67)));
}

vec3 rot_y(vec3 d, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	vec3 base = up > 0.0 ? mix(horizon_colour, top_colour, pow(up, 0.6)) : mix(horizon_colour, below_colour, pow(-up, 0.7));
	if (AT_CUBEMAP_PASS) {
		COLOR = up > 0.0 ? mix(horizon_colour, light_top, pow(up, 0.6)) : mix(horizon_colour, light_below, pow(-up, 0.7));
	} else {
		float t = TIME * motion;
		vec3 c = base;
		// The nebula: two layers of cloud turning slowly in opposite ways, drifting round the colour wheel
		vec3 n1 = rot_y(d, t * 0.006);
		vec3 n2 = rot_y(d, -t * 0.004);
		float warp = fbm(n1 * 2.2 + vec3(0.0, t * 0.01, 0.0));
		float neb = fbm(n2 * 3.0 + warp * 1.6);
		float band = smoothstep(0.42, 0.85, neb) * (1.0 - 0.55 * abs(up));
		vec3 nc = palette(neb * 1.4 + t * 0.008 + d.x * 0.3);
		c = mix(c, nc * nc * 1.1, band * 0.6 * colour);
		c += nc * pow(band, 3.0) * 0.5 * colour;
		// Stars: tiny points that twinkle, stronger away from the horizon
		vec3 sp = d * 160.0;
		vec3 cell = floor(sp);
		float h = hash3(cell);
		if (h > 0.975) {
			vec3 centre = cell + 0.5 + (vec3(hash3(cell + 3.1), hash3(cell + 7.7), hash3(cell + 1.3)) - 0.5) * 0.6;
			float dist = length(sp - centre);
			float tw = 0.6 + 0.4 * sin(t * (1.5 + h * 4.0) + h * 40.0);
			c += vec3(1.0, 0.95, 1.0) * smoothstep(0.35, 0.0, dist) * tw * smoothstep(0.0, 0.3, abs(up));
		}
		// Aurora: rainbow ribbons waving round the sky above the horizon
		float az = atan(d.z, d.x);
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float centre_h = 0.28 + fk * 0.16 + sin(az * (2.0 + fk) + t * (0.07 + fk * 0.03)) * 0.06
				+ (noise3(vec3(az * 3.0, t * 0.05, fk * 5.0)) - 0.5) * 0.08;
			float ribbon = exp(-pow((up - centre_h) / (0.035 + fk * 0.01), 2.0));
			float curtain = 0.5 + 0.5 * sin(az * 26.0 + t * 0.4 + fk * 2.0 + noise3(vec3(az * 8.0, t * 0.1, fk)) * 4.0);
			vec3 ac = palette(az * 0.25 + t * 0.02 + fk * 0.4);
			c += ac * ac * ribbon * (0.3 + 0.7 * curtain) * 0.7 * colour;
		}
		// The big ringed planet, banded and turning
		vec3 pd = normalize(planet_dir);
		float pa = acos(clamp(dot(d, pd), -1.0, 1.0));
		float pr = 0.16;
		vec3 pr_side = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
		vec3 pr_up = cross(pr_side, pd);
		vec2 local = vec2(dot(d - pd, pr_side), dot(d - pd, pr_up));
		if (pa < pr) {
			float shade = sqrt(max(0.0, 1.0 - pow(pa / pr, 2.0)));
			float bands = sin(local.y * 70.0 + sin(local.x * 25.0 + t * 0.05) * 1.5);
			vec3 pc = mix(vec3(0.95, 0.62, 0.82), vec3(0.62, 0.9, 0.95), 0.5 + 0.5 * bands);
			c = mix(c, pc * (0.45 + 0.65 * shade), smoothstep(pr, pr - 0.004, pa));
		}
		// Its ring: a tilted ellipse, in front of the planet below and behind it above
		vec2 rl = vec2(local.x, local.y + local.x * 0.25);
		float ell = length(vec2(rl.x, rl.y * 4.2));
		float ring = smoothstep(0.012, 0.0, abs(ell - 0.27)) + smoothstep(0.008, 0.0, abs(ell - 0.31)) * 0.6;
		bool behind = pa < pr && rl.y > 0.0;
		if (!behind) {
			c = mix(c, vec3(1.0, 0.92, 0.75), clamp(ring, 0.0, 1.0) * 0.75);
		}
		// A little moon
		vec3 md = normalize(moon_dir);
		float ma = acos(clamp(dot(d, md), -1.0, 1.0));
		c = mix(c, vec3(0.98, 0.95, 1.0) * (0.85 + 0.15 * noise3(d * 90.0)), smoothstep(0.045, 0.041, ma));
		c += vec3(0.7, 0.6, 1.0) * smoothstep(0.16, 0.04, ma) * 0.12;
		// The sun: a soft warm glow where the light comes from
		if (LIGHT0_ENABLED) {
			float sa = max(dot(d, LIGHT0_DIRECTION), 0.0);
			c += LIGHT0_COLOR * (pow(sa, 600.0) * 1.5 + pow(sa, 12.0) * 0.12);
		}
		COLOR = c;
	}
}
