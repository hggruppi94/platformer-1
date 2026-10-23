extends SceneTree

# Generates sound effects for the world (res://audio/sfx/<name>.wav), synthesized from scratch like the rest of the
# game's placeholder sounds (tools/make_placeholder_audio.py makes the older ones; this one needs nothing but Godot).
# Same building blocks: tones and sweeps, filtered noise, envelopes. Re-running it makes the same sounds.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/make_world_sfx.gd
#
# Real recordings can simply overwrite the .wav files.

const SR := 22050
const DIR := "res://audio/sfx/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 2026
	var sounds := {
		"zipline": _zipline(),
		# Walking through things
		"rustle": _rustle(0.32, 900.0, 4200.0),         # pushing through giant leaves
		"swish": _rustle(0.22, 2200.0, 7000.0),         # ferns and tall grass
		"bloop": _bloop(),                              # a small mushroom lighting up
		"boing": _boing(),                              # bouncing off a big mushroom cap
		"fwump": _fwump(),                              # landing in a cloud
		"splash": _splash(0.55),                        # into water
		"bubbles": _bubbles(),                          # the bubble bath gurgling
		"pop": _pop(),                                  # a bubble popping
		"steam": _steam(),                              # hot spring bubbling
		"waterfall": _waterfall(),                      # loops (scripts/ambient_loop.gd)
		# Footsteps on different ground (scenes/player/player.gd picks one by scripts/surfaces.gd)
		"step_grass": _step(0.06, 600.0, 3500.0, 0.0),
		"step_wood": _step(0.07, 150.0, 1200.0, 210.0),
		"step_stone": _step(0.045, 1200.0, 6000.0, 0.0),
		"step_water": _splash(0.16),
		"step_cloud": _step(0.09, 100.0, 900.0, 0.0),
		"step_crystal": _chime(),
		"beam": _beam(),                                # the mothership's tractor beam
		# Skating (scenes/player/skate.gd). The roll and grind loop, so they're made to join up end to start.
		"skate_roll": _skate_roll(),
		"skate_grind": _skate_grind(),
		"skate_pop": _skate_pop(),                      # the tail snapping down for an ollie
		"skate_land": _skate_land(),                    # four wheels slapping down
		"skate_bail": _skate_bail(),                    # a cartoon wipeout
	}
	for name in sounds:
		_write(name, sounds[name])
	quit()


# -----------------------------------------------------------------------------
# The sounds
# -----------------------------------------------------------------------------
func _zipline() -> PackedFloat32Array:
	# A rolling whir along the cable: filtered noise with a fast flutter, and a rising metallic hum
	var n := int(0.9 * SR)
	var whir := _lowpass(_highpass(_noise(n), 300.0), 2600.0)
	var hum := _sweep(180.0, 320.0, n, "tri")
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var flutter := 0.65 + 0.35 * sin(TAU * 38.0 * t)
		var shape := sin(PI * float(i) / n)                # swell in and out
		out[i] = (whir[i] * flutter * 0.8 + hum[i] * 0.25) * shape
	return _norm(out, 0.6)


func _rustle(dur: float, lo: float, hi: float) -> PackedFloat32Array:
	# Leafy rustle: band-passed noise in a few quick crackly bursts
	var n := int(dur * SR)
	var x := _lowpass(_highpass(_noise(n), lo), hi)
	var out := PackedFloat32Array()
	out.resize(n)
	var bursts := [0.0, 0.3, 0.55, 0.75]
	for i in n:
		var t := float(i) / n
		var e := 0.0
		for b in bursts:
			if t >= b:
				e = maxf(e, exp(-(t - b) * 14.0))
		out[i] = x[i] * e * (1.0 - t * 0.6) * (0.6 + 0.4 * rng.randf())
	return _norm(out, 0.55)


func _bloop() -> PackedFloat32Array:
	var n := int(0.22 * SR)
	return _norm(_mul(_sweep(320.0, 760.0, n), _env(n, 0.004, 0.15)), 0.6)


func _boing() -> PackedFloat32Array:
	# A springy wobble that rises and settles
	var n := int(0.5 * SR)
	var y := PackedFloat32Array()
	y.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / SR
		var f := 220.0 + 260.0 * (1.0 - exp(-t * 9.0)) + 60.0 * sin(TAU * 11.0 * t) * exp(-t * 4.0)
		ph += TAU * f / SR
		y[i] = sin(ph) * exp(-t * 5.5) * minf(1.0, t / 0.004)
	return _norm(y, 0.7)


func _fwump() -> PackedFloat32Array:
	# A soft, airy thump: low noise and a falling low tone
	var n := int(0.4 * SR)
	var puff := _mul(_lowpass(_noise(n), 500.0), _env(n, 0.01, 0.25, 2.0))
	var thump := _mul(_sweep(130.0, 60.0, n), _env(n, 0.005, 0.15))
	return _norm(_add(puff, thump, 0, 0.8), 0.6)


func _splash(dur: float) -> PackedFloat32Array:
	# Water: a bright noisy burst with little droplet blips after it
	var n := int(dur * SR)
	var y := _mul(_lowpass(_highpass(_noise(n), 500.0), 6000.0), _env(n, 0.003, dur * 0.35, 3.0))
	for k in int(dur * 18):
		var at := int(rng.randf_range(0.05, 0.9) * n)
		var m := int(0.03 * SR)
		y = _add(y, _mul(_sweep(rng.randf_range(900.0, 1600.0), rng.randf_range(1800.0, 2600.0), m), _env(m, 0.002, 0.02)), at, 0.25)
	return _norm(y, 0.6)


func _pop() -> PackedFloat32Array:
	var n := int(0.07 * SR)
	return _norm(_mul(_sweep(700.0, 2200.0, n), _env(n, 0.001, 0.03)), 0.5)


func _bubbles() -> PackedFloat32Array:
	# A gurgle: lots of little rising blips at random
	var n := int(1.2 * SR)
	var y := _mul(_lowpass(_noise(n), 400.0), _env(n, 0.2, 0.9, 1.5), 0.3)
	for k in 26:
		var at := int(rng.randf_range(0.0, 0.9) * n)
		var m := int(rng.randf_range(0.03, 0.07) * SR)
		var f := rng.randf_range(300.0, 900.0)
		y = _add(y, _mul(_sweep(f, f * 1.8, m), _env(m, 0.002, 0.03)), at, rng.randf_range(0.2, 0.6))
	return _norm(y, 0.5)


func _steam() -> PackedFloat32Array:
	# Hot spring: a breathy hiss with slow low bubbling under it
	var n := int(1.4 * SR)
	var hiss := _mul(_highpass(_noise(n), 3000.0), _env(n, 0.3, 1.0, 1.2), 0.5)
	for k in 10:
		var at := int(rng.randf_range(0.0, 0.85) * n)
		var m := int(0.08 * SR)
		var f := rng.randf_range(120.0, 260.0)
		hiss = _add(hiss, _mul(_sweep(f, f * 1.5, m), _env(m, 0.004, 0.05)), at, 0.5)
	return _norm(hiss, 0.45)


func _waterfall() -> PackedFloat32Array:
	# A steady rush that loops without a click: 4 s of filtered noise, its ends crossfaded into each other
	var n := int(4.0 * SR)
	var fade := int(0.5 * SR)
	var raw := _lowpass(_highpass(_noise(n + fade), 150.0), 3200.0)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		y[i] = raw[i]
	for i in fade:                                     # the tail fades into the head
		var k := float(i) / fade
		y[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return _norm(y, 0.5)


func _step(dur: float, lo: float, hi: float, knock: float) -> PackedFloat32Array:
	# A footstep: a short filtered scuff, plus a knock for hollow wood
	var n := int(dur * SR)
	var y := _mul(_lowpass(_highpass(_noise(n), lo), hi), _env(n, 0.001, dur * 0.3))
	if knock > 0.0:
		y = _add(y, _mul(_sweep(knock, knock * 0.8, n), _env(n, 0.001, dur * 0.4)), 0, 0.8)
	return _norm(y, 0.4)


func _beam() -> PackedFloat32Array:
	# A tractor beam: a soft rising warble with a shimmer an octave and a fifth above, swelling in and out
	var n := int(1.6 * SR)
	var low := _sweep(220.0, 440.0, n, "tri")
	var high := _sweep(660.0, 1320.0, n)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / SR
		var wobble := 0.7 + 0.3 * sin(TAU * 7.0 * t)
		var shape := sin(PI * float(i) / n)
		out[i] = (low[i] * 0.6 + high[i] * 0.25 * wobble) * shape * wobble
	return _norm(out, 0.55)


func _chime() -> PackedFloat32Array:
	# Crystal: two glassy partials ringing out
	var n := int(0.45 * SR)
	var a := _mul(_sweep(1760.0, 1760.0, n), _env(n, 0.002, 0.3, 2.5))
	var b := _mul(_sweep(2637.0, 2637.0, n), _env(n, 0.002, 0.2, 3.0))
	return _norm(_add(a, b, 0, 0.5), 0.35)


# -----------------------------------------------------------------------------
# Building blocks
# -----------------------------------------------------------------------------
func _skate_roll() -> PackedFloat32Array:
	# Wheels on concrete: a low rumble, with a soft tick each time the wheels roll over a crack
	var n := int(1.2 * SR)
	var y := _mul(_lowpass(_highpass(_noise(n), 60.0), 700.0), _env(n, 0.0, 99.0, 1.0))
	for k in 4:
		var tick := _mul(_lowpass(_noise(int(0.03 * SR)), 1500.0), _env(int(0.03 * SR), 0.001, 0.01))
		y = _add(y, tick, int(k * 0.3 * SR + 0.05 * SR), 0.6)
	return _norm(_seamless(y, int(0.15 * SR)), 0.5)


func _skate_grind() -> PackedFloat32Array:
	# Metal on metal: bright scraping noise with a couple of ringing tones that wobble
	var n := int(1.0 * SR)
	var scrape := _lowpass(_highpass(_noise(n), 1800.0), 7000.0)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in n:
		var t := float(i) / SR
		var rough := 0.6 + 0.4 * sin(TAU * 23.0 * t) * sin(TAU * 7.0 * t)
		y[i] = scrape[i] * rough * 0.7 + 0.18 * sin(TAU * 1310.0 * t) * rough + 0.12 * sin(TAU * 2190.0 * t)
	return _norm(_seamless(y, int(0.12 * SR)), 0.55)


func _skate_pop() -> PackedFloat32Array:
	# A sharp wooden clack with a little thump under it
	var n := int(0.18 * SR)
	var clack := _mul(_lowpass(_highpass(_noise(n), 900.0), 5000.0), _env(n, 0.0005, 0.02))
	var wood := _mul(_sweep(420.0, 300.0, n, "tri"), _env(n, 0.0005, 0.04))
	var thump := _mul(_sweep(120.0, 70.0, n), _env(n, 0.002, 0.06))
	return _norm(_add(_add(clack, wood, 0, 0.7), thump, 0, 0.8), 0.8)


func _skate_land() -> PackedFloat32Array:
	# Two quick slaps (back wheels, then front) and a rattle of the trucks
	var n := int(0.3 * SR)
	var slap := _mul(_lowpass(_noise(int(0.08 * SR)), 2500.0), _env(int(0.08 * SR), 0.001, 0.03))
	var thud := _mul(_sweep(110.0, 55.0, int(0.12 * SR)), _env(int(0.12 * SR), 0.002, 0.05))
	var y := PackedFloat32Array()
	y.resize(n)
	y = _add(y, slap, 0, 1.0)
	y = _add(y, thud, 0, 1.0)
	y = _add(y, slap, int(0.035 * SR), 0.8)
	var rattle := _mul(_highpass(_noise(int(0.15 * SR)), 3000.0), _env(int(0.15 * SR), 0.01, 0.05))
	y = _add(y, rattle, int(0.05 * SR), 0.25)
	return _norm(y, 0.8)


func _skate_bail() -> PackedFloat32Array:
	# A slide whistle going down, a bump, and the board clattering away
	var n := int(0.9 * SR)
	var whistle := _mul(_sweep(1400.0, 300.0, int(0.45 * SR)), _env(int(0.45 * SR), 0.02, 0.3, 1.5))
	var bump := _mul(_sweep(140.0, 50.0, int(0.2 * SR)), _env(int(0.2 * SR), 0.002, 0.08))
	var y := PackedFloat32Array()
	y.resize(n)
	y = _add(y, whistle, 0, 0.6)
	y = _add(y, bump, int(0.42 * SR), 1.0)
	for k in 3:
		var clat := _mul(_lowpass(_highpass(_noise(int(0.05 * SR)), 800.0), 4000.0), _env(int(0.05 * SR), 0.001, 0.015))
		y = _add(y, clat, int((0.5 + k * 0.09 + rng.randf() * 0.03) * SR), 0.7 - k * 0.15)
	return _norm(y, 0.8)


func _seamless(x: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	# Fold the last bit of a sound over its start, so it loops with no click where the end meets the beginning
	var n := x.size() - fade
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = x[i] * w + x[n + i] * (1.0 - w)
	return out


func _noise(n: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = rng.randf_range(-1.0, 1.0)
	return x


func _lowpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * cutoff / SR)
	var y := PackedFloat32Array()
	y.resize(x.size())
	var v := 0.0
	for i in x.size():
		v += a * (x[i] - v)
		y[i] = v
	return y


func _highpass(x: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	var low := _lowpass(x, cutoff)
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = x[i] - low[i]
	return y


func _sweep(f0: float, f1: float, n: int, shape := "sine") -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(n)
	var ph := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / n)
		ph += TAU * f / SR
		match shape:
			"tri":
				y[i] = 2.0 / PI * asin(sin(ph))
			"square":
				y[i] = signf(sin(ph)) * 0.6
			_:
				y[i] = sin(ph)
	return y


func _env(n: int, attack: float, decay: float, curve := 3.0) -> PackedFloat32Array:
	# Attack (seconds) then an exponential-ish decay over `decay` seconds
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var t := float(i) / SR
		e[i] = minf(1.0, t / maxf(attack, 0.0001)) * exp(-curve * maxf(t - attack, 0.0) / maxf(decay, 0.0001))
	return e


func _mul(a: PackedFloat32Array, b: PackedFloat32Array, k := 1.0) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(mini(a.size(), b.size()))
	for i in y.size():
		y[i] = a[i] * b[i] * k
	return y


func _add(a: PackedFloat32Array, b: PackedFloat32Array, at := 0, k := 1.0) -> PackedFloat32Array:
	# b mixed into a copy of a, starting at sample `at` (a grows if b runs past its end)
	var y := a.duplicate()
	if y.size() < at + b.size():
		y.resize(at + b.size())
	for i in b.size():
		y[at + i] += b[i] * k
	return y


func _norm(x: PackedFloat32Array, peak := 0.85) -> PackedFloat32Array:
	var m := 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var y := x.duplicate()
	for i in y.size():
		y[i] = y[i] / m * peak
	return y


func _write(name: String, x: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(x.size() * 2)
	for i in x.size():
		data.encode_s16(i * 2, int(clampf(x[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	var err := w.save_to_wav(ProjectSettings.globalize_path(DIR + name + ".wav"))
	print("sfx  ", name, "  %.2fs" % (float(x.size()) / SR), "  ", error_string(err))
