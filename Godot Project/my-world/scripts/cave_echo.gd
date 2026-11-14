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
# Nothing here touches the music or the voices. tools/test_bumps.gd checks it in a test tunnel.

const CHECK_EVERY := 0.15             # seconds between looks round
const ROOF_UP := 14.0                 # a roof this far over her head counts
const NAMES := ["Tunnel", "Cave", "Cavern", "Burrow", "Undergarden", "Grotto", "Shortcut"]
const WET := 0.32                     # the reverb's wet level all the way in
const ECHO_DB := -13.0                # the echo's tap, all the way in
const BED_DB := -17.0                 # the cave bed's level all the way in
const FADE := 2.0                     # how fast it eases (per second, 0..1)
const RATE := 22050
const BED_SECONDS := 6.0

var player: CharacterBody3D
var inside := false                   # closed in right now (tests read it)
var amount := 0.0                     # 0..1, eased
var why := ""                         # what made it a cave (tests read it)

var _t := 0.0
var _reverb: AudioEffectReverb
var _delay: AudioEffectDelay
var _bed: AudioStreamPlayer
static var _bed_sound: AudioStreamWAV


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


func _exit_tree() -> void:
	# Through a door or a portal: take the effects off the bus, so nowhere else echoes
	_remove_effects()
	amount = 0.0
	inside = false


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
	if roof.is_in_group("race_roof") or roof.is_in_group("echo"):
		return "tunnel"
	var path := str(roof.get_path())
	for n in NAMES:
		if path.contains(n):
			return "tunnel"
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
