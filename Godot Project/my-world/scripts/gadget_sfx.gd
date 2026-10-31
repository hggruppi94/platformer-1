class_name GadgetSfx
extends RefCounted

# The new gadgets' sounds, made in code when they're first played (Audio falls back to these when there's no
# res://audio/sfx/<name>.wav). They're built the same way tools/make_world_sfx.gd builds the others (tones, sweeps,
# noise and envelopes), but here, because .wav files go through Git LFS and the cloud sessions that make gadgets
# can't upload those. A real recording dropped in as audio/sfx/<name>.wav takes over by itself.

const SR := 22050

static var _made := {}


static func has(name: String) -> bool:
	return name in ["plush_poof", "buzz", "rainbow_hum", "rainbow_pop", "jelly", "frost", "crate"]


static func stream(name: String) -> AudioStreamWAV:
	if _made.has(name):
		return _made[name]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var s := PackedFloat32Array()
	match name:
		"plush_poof":       # a soft, breathy puff with a little rising squeak
			s = _mix(_noise(rng, 0.28, 0.35, 0.02, 0.25), _sweep(0.18, 700.0, 1300.0, 0.25, 0.01, 0.15))
		"buzz":             # a happy little buzz, like a bee with a motor
			s = _buzz(0.45)
		"rainbow_hum":      # a shimmery chord that loops while the ray is on
			s = _hum(1.0)
		"rainbow_pop":      # a bright up-the-scale chime
			s = _mix(_mix(_tone(0.25, 880.0, 0.25, 0.005, 0.2), _tone(0.3, 1108.7, 0.2, 0.06, 0.24)),
				_tone(0.35, 1318.5, 0.2, 0.12, 0.23))
		"jelly":            # a wobbly squelch
			s = _wobble(0.35)
		"frost":            # an icy tinkle with a hiss
			s = _mix(_noise(rng, 0.3, 0.12, 0.01, 0.28), _mix(_tone(0.4, 2093.0, 0.15, 0.0, 0.4), _tone(0.4, 2637.0, 0.12, 0.05, 0.35)))
		"crate":            # bubble wrap: a quick rattle of pops
			s = _crackle(rng, 0.4)
	var w := _wav(s, name == "rainbow_hum")
	_made[name] = w
	return w


static func _env(i: int, n: int, attack: float, release: float) -> float:
	var t := float(i) / SR
	var len := float(n) / SR
	var a := clampf(t / maxf(attack, 0.001), 0.0, 1.0)
	var r := clampf((len - t) / maxf(release, 0.001), 0.0, 1.0)
	return a * r


static func _tone(dur: float, freq: float, vol: float, delay := 0.0, release := 0.1) -> PackedFloat32Array:
	var n := int((dur + delay) * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var d := int(delay * SR)
	for i in n:
		if i < d:
			continue
		var k := i - d
		out[i] = sin(TAU * freq * k / SR) * vol * _env(k, n - d, 0.005, release)
	return out


static func _sweep(dur: float, f0: float, f1: float, vol: float, attack: float, release: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / n)
		phase += TAU * f / SR
		out[i] = sin(phase) * vol * _env(i, n, attack, release)
	return out


static func _noise(rng: RandomNumberGenerator, dur: float, vol: float, attack: float, release: float) -> PackedFloat32Array:
	# Softened noise (a simple low-pass), for puffs and hisses
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i in n:
		last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.25)
		out[i] = last * vol * _env(i, n, attack, release)
	return out


static func _buzz(dur: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f := 220.0 + 30.0 * sin(TAU * 7.0 * t) + 120.0 * t
		phase += TAU * f / SR
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		out[i] = (saw * 0.6 + sin(phase * 2.0) * 0.3) * 0.22 * _env(i, n, 0.02, 0.12) * (0.75 + 0.25 * sin(TAU * 30.0 * t))
	return out


static func _hum(dur: float) -> PackedFloat32Array:
	# Whole cycles of every partial, so the loop joins up
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var v := sin(TAU * 523.0 * t) * 0.5 + sin(TAU * 659.0 * t) * 0.35 + sin(TAU * 784.0 * t) * 0.3
		v *= 0.8 + 0.2 * sin(TAU * 6.0 * t)
		out[i] = v * 0.12
	return out


static func _wobble(dur: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f := 180.0 + 90.0 * sin(TAU * 14.0 * t) * (1.0 - t / dur)
		phase += TAU * f / SR
		out[i] = sin(phase) * 0.35 * _env(i, n, 0.01, 0.15)
	return out


static func _crackle(rng: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in 14:
		var at := rng.randi_range(0, n - 400)
		var vol := rng.randf_range(0.25, 0.5)
		for j in 300:
			out[at + j] += rng.randf_range(-1.0, 1.0) * vol * exp(-float(j) / 40.0)
	return out


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = s.size()
	return w
