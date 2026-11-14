extends Node

# Cave sounds and echo (Hayden, 14 Nov 2026: "Have cave sounds/echo when inside tunnels"). A "CaveEcho" node on the
# player (scenes/player/player.gd) that checks a few times a second whether the hero is somewhere closed in:
#   - a dark cave (a "cave_dark" zone from scripts/cave_kit.gd: the Undergardens, the Glimmer Caves, Pip's dark spots),
#   - under a tunnel roof (a race circuit's road tunnels, group "race_roof"), or a secret shortcut tunnel
#     (the circuit's shortcut_at()),
#   - under anything named like a tunnel or a cave, or in a node's group "echo" (for new places),
#   - or burrowing underground with Bramble.
# Inside, every sound effect (footsteps, landings, bumps, boards) gets a roomy reverb and a soft echo on the SFX bus,
# both easing in over about half a second, and a quiet cave bed fades up: a low hollow hum with water dripping now and
# then, made in code like Juice's sounds (no .wav: those need LFS). Out again, it all eases away.
#
# Underground music (Hayden, 14 Nov 2026: "Can the music change when you go underground? like ambient sound"): in a
# real cave or burrowing (not a race's road tunnel or a shortcut: their music keeps going), the place's music fades
# away (Audio.underground()) and soft cave music fades up instead: slow, echoing chords with a twinkle now and then,
# made in code too (make_pad(), a slice a frame so nothing ever stutters). Back up top, the place's
# music comes back. The voices are never touched. tools/test_bumps.gd checks it in a test tunnel and a test cave.

const CHECK_EVERY := 0.15             # seconds between looks round
const ROOF_UP := 14.0                 # a roof this far over her head counts
const NAMES := ["Tunnel", "Cave", "Cavern", "Burrow", "Undergarden", "Grotto", "Shortcut"]
const WET := 0.32                     # the reverb's wet level all the way in
const ECHO_DB := -13.0                # the echo's tap, all the way in
const BED_DB := -17.0                 # the cave bed's level all the way in
const FADE := 2.0                     # how fast it eases (per second, 0..1)
const RATE := 22050
const BED_SECONDS := 6.0
const PAD_DB := -9.0                  # the cave music all the way in (on the Music bus)
const MUSIC_FADE := 0.6               # how fast the music changes over (per second, 0..1): slower than the echo
const PAD_RATE := 16000
const PAD_CHORD := 4.0                # seconds a chord rings
# Slow chords for the dark (A minor, F, C, E minor: low root plus three notes), each fading into the next
const PAD_CHORDS := [[110.0, 220.0, 261.63, 329.63], [87.31, 174.61, 220.0, 261.63],
	[130.81, 196.0, 261.63, 329.63], [82.41, 196.0, 246.94, 329.63]]
const MUSIC_WHY := ["cave", "burrow"]  # what changes the music over (tunnels and shortcuts only echo)

var player: CharacterBody3D
var inside := false                   # closed in right now (tests read it)
var amount := 0.0                     # 0..1, eased
var why := ""                         # what made it a cave (tests read it)
var music_amount := 0.0               # 0..1, eased: how far the music's changed over to the cave music

var _t := 0.0
var _reverb: AudioEffectReverb
var _delay: AudioEffectDelay
var _bed: AudioStreamPlayer
var _pad: AudioStreamPlayer
static var _bed_sound: AudioStreamWAV
static var _pad_sound: AudioStreamWAV
static var _pad_build := {}             # the cave music, being made a slice a frame (pad_ready())
const PAD_SLICE := 2000                 # samples made a frame (a few ms)


func setup(p: CharacterBody3D) -> void:
	player = p


func _ready() -> void:
	_bed = AudioStreamPlayer.new()
	_bed.name = "Cave Bed"
	_bed.bus = "SFX"
	if _bed_sound == null:
		_bed_sound = make_bed()
	_bed.stream = _bed_sound
	_bed.volume_db = -80.0
	add_child(_bed)
	_pad = AudioStreamPlayer.new()
	_pad.name = "Cave Music"
	_pad.bus = "Music"
	_pad.volume_db = -80.0
	add_child(_pad)


func _exit_tree() -> void:
	# Through a door or a portal: take the effects off the bus, so nowhere else echoes
	_remove_effects()
	amount = 0.0
	inside = false
	music_amount = 0.0
	_music(0.0)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	_t -= delta
	if _t <= 0.0:
		_t = CHECK_EVERY
		why = closed_in()
		inside = why != ""
	var real := delta / maxf(Engine.time_scale, 0.05)
	amount = move_toward(amount, 1.0 if inside else 0.0, FADE * real)
	_apply()
	var under := pad_ready() and inside and why in MUSIC_WHY
	var was := music_amount
	music_amount = move_toward(music_amount, 1.0 if under else 0.0, MUSIC_FADE * real)
	if music_amount != was or (music_amount > 0.0 and not _pad.playing):
		_music(music_amount)


func pad_ready() -> bool:
	# Made a slice a frame, the first time anyone's anywhere (about two seconds), so nothing ever stutters
	if _pad_sound == null:
		if _pad_build.is_empty():
			_pad_build = pad_begin()
		if pad_step(_pad_build, PAD_SLICE):
			_pad_sound = pad_finish(_pad_build)
			_pad_build = {}
	return _pad_sound != null


func _music(k: float) -> void:
	# The place's music down, the cave music up (or back again)
	var audio := get_node_or_null("/root/Audio")
	if audio and audio.has_method("underground"):
		audio.underground(k)
	if _pad == null:
		return
	if k <= 0.0:
		if _pad.playing:
			_pad.stop()
		return
	if not _pad.playing and _pad_sound:
		_pad.stream = _pad_sound
		_pad.play()
	_pad.volume_db = lerpf(-50.0, PAD_DB, sqrt(k))


func closed_in() -> String:
	# What makes this a cave or a tunnel, or "" if it isn't one
	var at := player.global_position
	if player.get("burrow") and bool(player.burrow.get("active")):
		return "burrow"
	for z in get_tree().get_nodes_in_group("cave_dark"):
		if z is Node3D and z.is_inside_tree() and _in_box(z, at + Vector3(0, 0.5, 0)):
			return "cave"
	var scene := get_tree().current_scene
	if scene and scene.has_method("shortcut_at") and int(scene.shortcut_at(at)) >= 0:
		return "shortcut"
	var space := player.get_world_3d().direct_space_state if player.get_world_3d() else null
	if space == null:
		return ""
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.9, at + Vector3.UP * ROOF_UP)
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return ""
	var roof := hit.collider as Node
	if roof == null:
		return ""
	if roof.is_in_group("race_roof"):
		return "tunnel"
	if roof.is_in_group("underground"):
		return "cave"
	if roof.is_in_group("echo"):
		return "tunnel"
	var path := str(roof.get_path())
	for n in NAMES:
		if path.contains(n):
			return "tunnel" if n in ["Tunnel", "Shortcut"] else "cave"
	return ""


static func _in_box(zone: Node3D, p: Vector3) -> bool:
	# The same box test as scripts/cave_kit.gd in_zone: a "size" meta round the zone's middle
	var size: Vector3 = zone.get_meta("size", Vector3.ZERO)
	var local := zone.global_transform.affine_inverse() * p
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5


func _apply() -> void:
	if amount <= 0.0:
		if _reverb:
			_remove_effects()
		if _bed.playing:
			_bed.stop()
		return
	if _reverb == null:
		_add_effects()
	_reverb.wet = WET * amount
	_reverb.dry = 1.0
	_delay.tap1_level_db = lerpf(-60.0, ECHO_DB, amount)
	_delay.tap2_level_db = lerpf(-60.0, ECHO_DB - 6.0, amount)
	if not _bed.playing:
		_bed.play()
	_bed.volume_db = lerpf(-50.0, BED_DB, amount)


func _add_effects() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0:
		return
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.75
	_reverb.damping = 0.35
	_reverb.predelay_msec = 40.0
	_reverb.spread = 0.8
	_reverb.wet = 0.0
	_delay = AudioEffectDelay.new()
	_delay.dry = 1.0
	_delay.tap1_active = true
	_delay.tap1_delay_ms = 190.0
	_delay.tap1_level_db = -60.0
	_delay.tap2_active = true
	_delay.tap2_delay_ms = 380.0
	_delay.tap2_level_db = -60.0
	_delay.feedback_active = false
	AudioServer.add_bus_effect(bus, _delay)
	AudioServer.add_bus_effect(bus, _reverb)


func _remove_effects() -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		# By the effect itself, not by its place on the bus, in case something else adds one meanwhile
		for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			var e := AudioServer.get_bus_effect(bus, i)
			if e == _reverb or e == _delay:
				AudioServer.remove_bus_effect(bus, i)
	_reverb = null
	_delay = null


func has_effects() -> bool:
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0 or _reverb == null:
		return false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _reverb:
			return true
	return false


static func make_bed() -> AudioStreamWAV:
	# A low, hollow hum (smoothed noise and a soft deep note) with water drips plinking now and then, looping
	var n := int(RATE * BED_SECONDS)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var drips := []
	var at := 0.4
	while at < BED_SECONDS - 0.4:
		drips.append([at, rng.randf_range(1300.0, 2300.0), rng.randf_range(0.35, 0.7)])
		at += rng.randf_range(0.7, 1.7)
	var low := 0.0
	var low2 := 0.0
	for i in n:
		var t := float(i) / RATE
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.02)
		low2 = lerpf(low2, low, 0.05)
		# The hum loops cleanly: whole cycles of 55 Hz and a slow swell over the loop
		var v := low2 * 2.2 + sin(TAU * 55.0 * t) * 0.12 * (0.7 + 0.3 * sin(TAU * t / BED_SECONDS))
		for d in drips:
			var dt: float = t - float(d[0])
			if dt >= 0.0 and dt < 0.25:
				# a plink that drops a little in pitch as it rings
				v += sin(TAU * float(d[1]) * dt * (1.0 - 0.6 * dt)) * exp(-dt * 22.0) * float(d[2])
		# Ease the very start and end together so the loop doesn't click
		var edge := minf(minf(t, BED_SECONDS - t) / 0.05, 1.0)
		data.encode_s16(i * 2, int(clampf(v * 0.5 * edge, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


static func make_pad() -> AudioStreamWAV:
	# Soft cave music: slow chords that swell and fade into each other (each note a pair of slightly different sines, so
	# it shimmers), and a glassy twinkle now and then, high up, like light on wet rock. Loops without a seam: each chord's
	# swell wraps round the loop's end in time with itself. (All at once here; the game makes it a slice a frame.)
	var b := pad_begin()
	pad_step(b, b.n)
	return pad_finish(b)


static func pad_begin() -> Dictionary:
	var total := PAD_CHORD * PAD_CHORDS.size()
	var n := int(PAD_RATE * total)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var twinkles := []
	var at := 1.3
	var notes := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
	while at < total - 0.6:
		twinkles.append([at, notes[rng.randi() % notes.size()], rng.randf_range(0.08, 0.16)])
		at += rng.randf_range(1.6, 3.4)
	return {"n": n, "i": 0, "total": total, "data": data, "twinkles": twinkles}


static func pad_step(b: Dictionary, count: int) -> bool:
	var n: int = b.n
	var total: float = b.total
	var data: PackedByteArray = b.data
	var twinkles: Array = b.twinkles
	var over := 1.6                                  # how long each chord swells in before its time, and out after
	var span := PAD_CHORD + over * 2.0
	var from: int = b.i
	var to := mini(from + count, n)
	for i in range(from, to):
		var t := float(i) / PAD_RATE
		var v := 0.0
		for c in PAD_CHORDS.size():
			var start := c * PAD_CHORD - over
			var lt := t - start
			if lt < 0.0:
				lt += total
			elif lt >= total:
				lt -= total
			if lt >= span:
				continue
			var env := sin(PI * lt / span)
			env *= env
			var tt := lt + start                     # (each chord's own time keeps running across the loop's end)
			var chord: Array = PAD_CHORDS[c]
			for k in chord.size():
				var f: float = chord[k]
				var a := 0.16 if k == 0 else 0.1
				v += (sin(TAU * f * tt) + sin(TAU * f * 1.003 * tt) * 0.6) * a * env
		for tw in twinkles:
			var dt: float = t - float(tw[0])
			if dt >= 0.0 and dt < 1.4:
				v += sin(TAU * float(tw[1]) * dt) * exp(-dt * 3.0) * float(tw[2]) * minf(dt / 0.01, 1.0)
		data.encode_s16(i * 2, int(clampf(v * 0.55, -1.0, 1.0) * 32767.0))
	b.i = to
	b.data = data                                    # (PackedByteArray is copied on write: put it back)
	return to >= n


static func pad_finish(b: Dictionary) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = PAD_RATE
	w.stereo = false
	w.data = b.data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(b.n)
	return w
