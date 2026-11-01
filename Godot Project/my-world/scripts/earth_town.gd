extends Node

# Autoload "EarthTown": the things in Stars Hollow (scenes/earth/earth.tscn) that are added when it loads, so the
# town's builder doesn't need to change for them.
#
# - Shops: a "Press F to shop" spot at the counters of the bakery and the toy shop (walk in), and at the doors of the
#   Hollow Diner and the Corner Market, for their stalls in shop/items.json. They take sparkles, like Galaxity's
#   market: it's the one money the player has, it's earned in both worlds (Earth's notice board pays in it too), and
#   nobody on Earth seems to think shiny bits of broken time are a strange way to pay. A second, Earth-only money
#   would split what the player earns between two purses for no fun.
# - Story hints that something's going on with the old oak:
#   - It hums. Quiet in the evening, louder towards midnight, loudest in the Shift, with a faint green glow in its
#     branches to match (made here in code, so there's no sound file: Hayden's wav files go through LFS).
#   - Small tremors, once or twice a night between 10 PM and midnight, at times picked for each Earth day: a low
#     rumble, a little shake of the camera and the oak's leaves falling. People talk about them after (Dialogue flag
#     "earth_tremor") and Mr. Palmer says it's "the pipes".
#   - A lilac envelope on Mr. Palmer's porch table, addressed to "His Honour the Mayor, Mr. Palmer ... Galaxity"
#     (Dialogue flag "read_palmer_letter"; he has a line about his "pen pal").

const EARTH := "res://scenes/earth/earth.tscn"
# Shop spots: the stall, the building, and where in its own space (+Z is its front; the walk-in ones' floors are
# found from their "Inside" marker)
const SHOPS := [
	["Bakery", "Bakery", Vector3(0, 0, -1.2)],
	["Toy Shop", "Toy Shop", Vector3(-1.2, 0, -1.8)],
	["Diner", "Hollow Diner", Vector3(2.0, 0, 5.2)],
	["Corner Market", "Corner Market", Vector3(2.0, 0, 5.2)],
]
const OAK := Vector3(-2.5, 0, -1.5)       # the old oak, in the "Portal Home" group's space (tools/build_earth.gd _portal)
const HUM_FROM := 21 * 60.0               # the hum starts, very quietly...
const HUM_LOUD := 24 * 60.0               # ...and is loud by midnight (and all through the Shift)
const MIX_RATE := 22050
const HUM_LOOP := 4.0                     # seconds: every note and wobble in the hum fits a whole number of times
const TREMOR_FROM := 22 * 60.0
const TREMOR_TO := 23 * 60.0 + 50.0

var tremors_felt := 0
var _hum: AudioStreamPlayer3D
var _rumble: AudioStreamPlayer3D
static var _hum_sound: AudioStreamWAV     # made once, the first time Earth loads
static var _rumble_sound: AudioStreamWAV
var _glow: OmniLight3D
var _shake := 0.0
var _camera: Camera3D
var _last_minutes := -1.0
var _told_hum := 0
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	_hum = null
	_glow = null
	_last_minutes = -1.0
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EARTH:
		return
	_place_shops(scene)
	_place_oak(scene)
	_place_letter(scene)


func on_earth_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == EARTH


# -----------------------------------------------------------------------------
# Shops
# -----------------------------------------------------------------------------
func _place_shops(scene: Node) -> void:
	for s in SHOPS:
		var building := scene.get_node_or_null(str(s[1])) as Node3D
		if building == null or building.get_node_or_null("Shop " + str(s[0])) != null:
			continue
		var spot := (load("res://scripts/shop_stall.gd") as GDScript).new() as Area3D
		spot.name = "Shop " + str(s[0])
		spot.set("stall", str(s[0]))
		var inside := building.get_node_or_null("Inside") as Node3D
		var at: Vector3 = s[2]
		spot.position = at + Vector3(0, inside.position.y if inside else 0.0, 0)
		building.add_child(spot)


# -----------------------------------------------------------------------------
# The old oak: its hum and glow, and the tremors
# -----------------------------------------------------------------------------
func _place_oak(scene: Node) -> void:
	var home := scene.get_node_or_null("Portal Home") as Node3D
	if home == null:
		return
	var holder := Node3D.new()
	holder.name = "Oak Hum"
	home.add_child(holder)
	holder.position = OAK + Vector3(0, 3.0, 0)
	# The hum loops a sound made once in code. It used to be made as it played (an AudioStreamGenerator fed each
	# frame), and that could lock up the whole game: now and then the audio thread got stuck mixing it.
	if _hum_sound == null:
		_hum_sound = _make_hum()
		_rumble_sound = _make_rumble()
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = _hum_sound
	_hum.bus = "SFX"
	_hum.unit_size = 6.0
	_hum.max_distance = 70.0
	_hum.volume_db = -60.0
	holder.add_child(_hum)
	_rumble = AudioStreamPlayer3D.new()
	_rumble.stream = _rumble_sound
	_rumble.bus = "SFX"
	_rumble.unit_size = 10.0
	_rumble.max_distance = 90.0
	holder.add_child(_rumble)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.55, 1.0, 0.6)
	_glow.omni_range = 7.0
	_glow.light_energy = 0.0
	holder.add_child(_glow)
	_hum.play()


func hum_level() -> float:
	# 0 (silent) to 1 (the Shift): rising from 9 PM to midnight
	if Clock.in_shift():
		return 1.0
	var m := Clock.earth_minutes
	if m < HUM_FROM:
		return 0.0
	return clampf((m - HUM_FROM) / (HUM_LOUD - HUM_FROM), 0.0, 1.0) * 0.85


func tremor_times(day := -1) -> Array[float]:
	# One or two a night, at times picked for each Earth day (so a reload doesn't change them)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tremors:%d" % (Clock.earth_day() if day < 0 else day))
	var out: Array[float] = []
	for k in (1 if rng.randf() < 0.5 else 2):
		out.append(rng.randf_range(TREMOR_FROM, TREMOR_TO))
	out.sort()
	return out


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		if is_instance_valid(_camera):
			var k := _shake * 0.05
			_camera.h_offset = randf_range(-k, k)
			_camera.v_offset = randf_range(-k, k)
			if _shake == 0.0:
				_camera.h_offset = 0.0
				_camera.v_offset = 0.0
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	if not on_earth_scene() or not Clock.on_earth:
		return
	var level := hum_level()
	if _glow:
		_glow.light_energy = level * (1.2 + 0.4 * sin(Time.get_ticks_msec() * 0.003))
	if _hum:
		_hum.volume_db = -60.0 if level <= 0.0 else lerpf(-26.0, 0.0, level)
	var m := Clock.earth_minutes
	if _last_minutes >= 0.0 and m > _last_minutes and m - _last_minutes < 30.0:
		for t in tremor_times():
			if _last_minutes < t and m >= t:
				tremor()
	_last_minutes = m
	_tell_hum(level)


func _tell_hum(level: float) -> void:
	# Once a night, near the oak when it's humming loudly
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or _hum == null or level < 0.6 or _told_hum == Clock.earth_day():
		return
	if player.global_position.distance_to(_hum.global_position) < 18.0:
		_told_hum = Clock.earth_day()
		Game.message("The old oak is humming, low and deep. It's louder than it was this evening.")


static func _make_hum() -> AudioStreamWAV:
	# A low, wobbling hum (a few notes of an organ that isn't there), as a seamless loop
	var n := int(HUM_LOOP * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / MIX_RATE
		var wobble := 0.6 + 0.4 * sin(TAU * 0.5 * t)
		out[i] = (sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 82.5 * t) * 0.3 + sin(TAU * 110.0 * t + sin(TAU * 0.25 * t)) * 0.2) \
			* wobble * 0.35
	return _wav(out, true)


static func _make_rumble() -> AudioStreamWAV:
	# The tremor's rumble: noise and a deep note, fading out over 1.8 seconds
	var n := int(1.8 * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / MIX_RATE
		var left := minf(1.8 - t, 1.0)
		out[i] = (rng.randf_range(-1.0, 1.0) * 0.35 * left + sin(TAU * 31.0 * t) * 0.4 * left) * 0.35
	return _wav(out, false)


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func tremor() -> void:
	# A small one: a rumble, a little shake, leaves off the oak, and the town will talk about it
	tremors_felt += 1
	Dialogue.flags["earth_tremor"] = true
	_shake = 1.4
	_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_rumble):
		_rumble.play()
	if _hum:
		_hum.volume_db = maxf(_hum.volume_db, -8.0)
		var scene := get_tree().current_scene
		for c in [Color(0.95, 0.5, 0.15), Color(0.8, 0.25, 0.12), Color(0.95, 0.75, 0.25)]:
			Fx.burst(scene, _hum.global_position + Vector3.UP * 1.5, c, 14, 0.1, 1.2, -1.5, 2.5)
	Game.message("A little tremor rumbles under your feet. The old oak's leaves shiver and fall.")


# -----------------------------------------------------------------------------
# Mr. Palmer's letter
# -----------------------------------------------------------------------------
func _place_letter(scene: Node) -> void:
	var house := scene.get_node_or_null("Palmer House") as Node3D
	if house == null or house.get_node_or_null("Palmer's Letter") != null:
		return
	var envelope := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 0.015, 0.16)
	envelope.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.65, 0.95)
	envelope.material_override = m
	envelope.position = Vector3(3.05, 0.83, 4.4)              # (on the table, beside his teacup)
	envelope.rotation.y = 0.3
	house.add_child(envelope)
	var seal := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.025
	s.height = 0.02
	seal.mesh = s
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.4, 1.0, 0.5)
	g.emission_enabled = true
	g.emission = Color(0.4, 1.0, 0.5)
	g.emission_energy_multiplier = 2.5
	seal.material_override = g
	seal.position = Vector3(0, 0.012, 0)
	envelope.add_child(seal)
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = "Palmer's Letter"
	spot.set("verb", "look at the envelope")
	spot.set("radius", 1.4)
	spot.set("jobs", self)
	spot.position = Vector3(3.3, 0.0, 5.4)
	house.add_child(spot)


func talk(spot: Node3D) -> void:
	Dialogue.say(spot, "Envelope", letter_lines(), "palmer_letter")


func letter_lines() -> Array:
	Dialogue.flags["read_palmer_letter"] = true
	return ["(A lilac envelope on Mr. Palmer's porch table, sealed with a blob of green wax that glows, just a little.)",
		"(It's addressed in swirly silver writing: \"To His Honour the Mayor, Mr. Palmer. Town Hall, Market Square, GALAXITY.\")",
		"(Galaxity? The Mayor? How does Mr. Palmer get post from Galaxity?)",
		"(Better not open it. You put it back exactly how it was.)"]
