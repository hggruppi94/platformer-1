shader_type sky;

// The portal worlds' dream skies (scripts/world_sky.gd), Shard Isle's dream sky (dream_sky.gdshader) made to fit each
// world. Its gradient isn't fixed: world_sky.gd copies the world's own sky colours into top/horizon/below every
// frame, so a world that changes its sky (Lanternmoor's dawn, Glenmoor's day and night, the Tide Reef's tide, the Far
// Future's fading) still does, and the dream parts are drawn over it. Stars and the nebula come out as the sky gets
// dark, so a world with a night shows them most then. The light the world gets from the sky (the cubemap passes) is
// just the world's own gradient, so nothing in the world is lit any differently than before.

uniform vec3 top_colour : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 horizon_colour : source_color = vec3(0.8, 0.7, 0.9);
uniform vec3 below_colour : source_color = vec3(0.3, 0.3, 0.4);
uniform vec3 light_top : source_color = vec3(0.2, 0.3, 0.5);
uniform vec3 light_below : source_color = vec3(0.3, 0.3, 0.4);
uniform float deepen = 0.25;          // how much darker the top of the sky is drawn than the light it gives
uniform float motion = 1.0;
uniform float colour = 1.0;
uniform float nebula = 0.5;
uniform float nebula_day = 0.3;       // how much of the nebula still shows in a bright sky
uniform float nebula_hue = 0.0;
uniform float nebula_spread = 1.4;    // how much of the rainbow the nebula goes through
uniform vec3 nebula_tint = vec3(1.0);
uniform float stars = 1.0;
uniform float star_day = 0.1;
uniform float aurora = 0.5;
uniform float aurora_hue = 0.0;
uniform float aurora_spread = 0.25;
uniform float planet = 0.0;
uniform float ring = 1.0;
uniform vec3 planet_dir = vec3(-0.55, 0.42, -0.72);
uniform float planet_size = 0.16;
uniform vec3 planet_a : source_color = vec3(0.95, 0.62, 0.82);
uniform vec3 planet_b : source_color = vec3(0.62, 0.9, 0.95);
uniform float moon = 0.0;
uniform vec3 moon_dir = vec3(0.62, 0.55, 0.56);
uniform float moon_size = 0.045;
uniform vec3 moon_colour : source_color = vec3(0.98, 0.95, 1.0);
uniform float sun_glow = 1.0;

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
	if (AT_CUBEMAP_PASS) {
		COLOR = up > 0.0 ? mix(horizon_colour, light_top, pow(up, 0.6)) : mix(horizon_colour, light_below, pow(-up, 0.7));
	} else {
		vec3 top = top_colour * (1.0 - deepen);
		vec3 c = up > 0.0 ? mix(horizon_colour, top, pow(up, 0.6)) : mix(horizon_colour, below_colour, pow(-up, 0.7));
		// How dark the sky is now: stars and the nebula come out at night
		float lum = dot(top_colour, vec3(0.3, 0.55, 0.15));
		float night = 1.0 - smoothstep(0.12, 0.55, lum);
		float t = TIME * motion;
		// The nebula
		vec3 n1 = rot_y(d, t * 0.006);
		vec3 n2 = rot_y(d, -t * 0.004);
		float warp = fbm(n1 * 2.2 + vec3(0.0, t * 0.01, 0.0));
		float neb = fbm(n2 * 3.0 + warp * 1.6);
		float band = smoothstep(0.42, 0.85, neb) * (1.0 - 0.55 * abs(up)) * nebula * mix(nebula_day, 1.0, night);
		vec3 nc = palette(neb * nebula_spread + nebula_hue + t * 0.008 + d.x * 0.3) * nebula_tint;
		c = mix(c, nc * nc * 1.1, band * 0.6 * colour);
		c += nc * pow(band, 3.0) * 0.5 * colour;
		// Stars
		vec3 sp = d * 160.0;
		vec3 cell = floor(sp);
		float h = hash3(cell);
		if (h > 0.975) {
			vec3 centre = cell + 0.5 + (vec3(hash3(cell + 3.1), hash3(cell + 7.7), hash3(cell + 1.3)) - 0.5) * 0.6;
			float dist = length(sp - centre);
			float tw = 0.6 + 0.4 * sin(t * (1.5 + h * 4.0) + h * 40.0);
			c += vec3(1.0, 0.95, 1.0) * smoothstep(0.35, 0.0, dist) * tw * smoothstep(0.0, 0.3, abs(up))
				* stars * mix(star_day, 1.0, night);
		}
		// Aurora ribbons
		float az = atan(d.z, d.x);
		for (int k = 0; k < 2; k++) {
			float fk = float(k);
			float centre_h = 0.28 + fk * 0.16 + sin(az * (2.0 + fk) + t * (0.07 + fk * 0.03)) * 0.06
				+ (noise3(vec3(az * 3.0, t * 0.05, fk * 5.0)) - 0.5) * 0.08;
			float ribbon = exp(-pow((up - centre_h) / (0.035 + fk * 0.01), 2.0));
			float curtain = 0.5 + 0.5 * sin(az * 26.0 + t * 0.4 + fk * 2.0 + noise3(vec3(az * 8.0, t * 0.1, fk)) * 4.0);
			vec3 ac = palette(az * aurora_spread + aurora_hue + t * 0.02 + fk * 0.4);
			c += ac * ac * ribbon * (0.3 + 0.7 * curtain) * 0.7 * colour * aurora * mix(0.45, 1.0, night);
		}
		// A planet (ringed or not)
		if (planet > 0.0) {
			vec3 pd = normalize(planet_dir);
			float pa = acos(clamp(dot(d, pd), -1.0, 1.0));
			float pr = planet_size;
			vec3 pr_side = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
			vec3 pr_up = cross(pr_side, pd);
			vec2 local = vec2(dot(d - pd, pr_side), dot(d - pd, pr_up));
			if (pa < pr) {
				float shade = sqrt(max(0.0, 1.0 - pow(pa / pr, 2.0)));
				float bands = sin(local.y / pr * 11.0 + sin(local.x / pr * 4.0 + t * 0.05) * 1.5);
				vec3 pc = mix(planet_a, planet_b, 0.5 + 0.5 * bands);
				c = mix(c, pc * (0.45 + 0.65 * shade), smoothstep(pr, pr - 0.004, pa) * planet);
			}
			if (ring > 0.0) {
				vec2 rl = vec2(local.x, local.y + local.x * 0.25);
				float ell = length(vec2(rl.x, rl.y * 4.2));
				float rg = smoothstep(0.012, 0.0, abs(ell - pr * 1.7)) + smoothstep(0.008, 0.0, abs(ell - pr * 1.95)) * 0.6;
				bool behind = pa < pr && rl.y > 0.0;
				if (!behind) {
					c = mix(c, vec3(1.0, 0.92, 0.75), clamp(rg, 0.0, 1.0) * 0.75 * ring * planet);
				}
			}
			c += mix(planet_a, planet_b, 0.5) * smoothstep(pr * 2.2, pr, pa) * 0.08 * planet;
		}
		// A moon
		if (moon > 0.0) {
			vec3 md = normalize(moon_dir);
			float ma = acos(clamp(dot(d, md), -1.0, 1.0));
			c = mix(c, moon_colour * (0.85 + 0.15 * noise3(d * 90.0)), smoothstep(moon_size, moon_size * 0.91, ma) * moon);
			c += moon_colour * smoothstep(moon_size * 3.6, moon_size * 0.9, ma) * 0.14 * moon;
		}
		// The sun's soft glow
		if (LIGHT0_ENABLED && sun_glow > 0.0) {
			float sa = max(dot(d, LIGHT0_DIRECTION), 0.0);
			c += LIGHT0_COLOR * (pow(sa, 600.0) * 1.5 + pow(sa, 12.0) * 0.12) * sun_glow;
		}
		COLOR = c;
	}
}
