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


# -----------------------------------------------------------------------------
# Building blocks
# -----------------------------------------------------------------------------
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
