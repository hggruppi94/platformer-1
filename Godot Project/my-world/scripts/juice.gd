extends Node

# Autoload "Juice": the shared game-feel helper, so every action gives the same kind of satisfying feedback and later
# features reuse it instead of making their own. Each call is safe at any time (no camera, no scene, a test with no
# window, Settings.screen_shake at 0, rumble off) and gentle by default, because this is a kid's game.
#
#   Juice.shake(0.3)                         # a small camera shake (0..1), scaled by Settings.screen_shake
#   Juice.kick(Vector2(0, -1), 0.4)          # one camera nudge in a direction that springs back (a landing, a shot)
#   Juice.hitstop(0.06)                      # a tiny freeze on a big hit (real seconds)
#   Juice.burst(parent, pos, colour)         # a puff of particles (scripts/fx.gd)
#   Juice.dust(parent, pos, 0.5)             # a low ring of dust kicked up off the ground (landings, ollies, bails)
#   Juice.squash(node, 0.25)                 # squash and stretch a node's scale, then spring back
#   Juice.rumble(0.3, 0.15)                  # controller rumble (weak/strong 0..1, seconds), if Settings.rumble
#   Juice.blip("chime", 1.2)                 # a short sound made in code (no .wav: those need LFS)
#   Juice.chime_pickup()                     # the sparkle chime, rising in pitch on quick pickups
#   Juice.hit(pos, colour, amount)           # the usual mix for a pop: burst + shake + rumble (+ hitstop if big)
#
# Settings > Assist has "Screen shake" (0 to 100%) and "Controller rumble". Reduce motion turns the shake off too.
# tools/test_juice.gd checks every call with both off and both on.

const MAX_OFFSET := 0.35                      # metres of camera wobble at full shake
const DECAY := 2.6                            # how fast the shake settles (per second)
const CHIME_WINDOW := 0.9                     # pickups closer than this together climb the scale
const CHIME_STEPS := [1.0, 1.122, 1.26, 1.335, 1.498, 1.682, 1.888, 2.0]   # a major scale, up an octave
const RATE := 22050
const KICK_OFFSET := 0.12                     # metres a full-strength kick moves the camera
const KICK_RETURN := 14.0                     # how fast a kick springs back (per second)
const DUST := Color(0.74, 0.68, 0.8, 0.85)             # a soft lilac grey, so it shows on the pale pastel ground

var trauma := 0.0                             # 0..1, eases off by itself; the shake is trauma squared
var _t := 0.0
var _cam: Camera3D
var _cam_offset := Vector2.ZERO               # what this shake added to the camera's h/v offset, taken off again
var _kick := Vector2.ZERO                     # the nudge still being worked off, in metres
var _stop_until := 0
var _stop_scale := 1.0
var _chime_at := -10.0
var _chime_i := 0
var _players: Array[AudioStreamPlayer] = []
var _blips := {}
var calls := 0                                # how many juice calls so far (tools/test_juice.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)


func shake_scale() -> float:
	return 0.0 if Settings.reduce_motion else clampf(float(Settings.get("screen_shake")), 0.0, 1.0)


# -----------------------------------------------------------------------------
# Camera shake
# -----------------------------------------------------------------------------
func shake(amount := 0.3) -> void:
	calls += 1
	if shake_scale() <= 0.0:
		return
	trauma = clampf(maxf(trauma, amount * shake_scale()), 0.0, 1.0)


func kick(dir: Vector2, amount := 0.4) -> void:
	# One push of the camera in a screen direction (Godot's way round: Vector2.DOWN is down), easing back on its own. A shake wobbles;
	# a kick says which way something hit: down for a landing, back for a shot. Kicks add up but never past one
	# full kick, and the Screen shake slider and Reduce motion scale them the same way as the shake.
	calls += 1
	if shake_scale() <= 0.0 or dir == Vector2.ZERO:
		return
	_kick = (_kick + dir.normalized() * KICK_OFFSET * clampf(amount, 0.0, 1.0) * shake_scale()).limit_length(KICK_OFFSET)


func kicked() -> Vector2:
	return _kick


func _process(delta: float) -> void:
	_t += delta
	# The hit-pause ends on the real clock, whatever the game speed
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = _stop_scale
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	if cam != _cam:
		_unshake()
		_cam = cam
	if _cam == null or not is_instance_valid(_cam):
		trauma = 0.0
		_kick = Vector2.ZERO
		return
	if trauma <= 0.0 and _kick == Vector2.ZERO and _cam_offset == Vector2.ZERO:
		return
	trauma = maxf(trauma - DECAY * delta * 0.5, 0.0)
	# The kick eases back the real-time way, so a hit-pause doesn't hold it out
	var real := delta / maxf(Engine.time_scale, 0.05)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-KICK_RETURN * real))
	if _kick.length() < 0.002:
		_kick = Vector2.ZERO
	var k := trauma * trauma * MAX_OFFSET
	var want := Vector2(sin(_t * 47.0) + 0.5 * sin(_t * 83.0), cos(_t * 53.0) + 0.5 * cos(_t * 71.0)) * k * 0.66 + Vector2(_kick.x, -_kick.y)
	_cam.h_offset += want.x - _cam_offset.x
	_cam.v_offset += want.y - _cam_offset.y
	_cam_offset = want


func _unshake() -> void:
	if _cam and is_instance_valid(_cam):
		_cam.h_offset -= _cam_offset.x
		_cam.v_offset -= _cam_offset.y
	_cam_offset = Vector2.ZERO


# -----------------------------------------------------------------------------
# Hit-pause
# -----------------------------------------------------------------------------
func hitstop(seconds := 0.05) -> void:
	# A tiny freeze on a big hit. Never longer than a tenth of a second, never while paused, and never with
	# Reduce motion. Works with the gadget wheel's slow-down and the Assist game speed: it puts back what was there.
	calls += 1
	if Settings.reduce_motion or get_tree().paused or seconds <= 0.0:
		return
	if _stop_until == 0:
		_stop_scale = Engine.time_scale
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(minf(seconds, 0.1) * 1000.0))
	Engine.time_scale = minf(_stop_scale, 0.05)


func stopped() -> bool:
	return _stop_until > 0


# -----------------------------------------------------------------------------
# Particles, squash, rumble
# -----------------------------------------------------------------------------
func burst(parent: Node, pos: Vector3, colour: Color, amount := 12, size := 0.1, speed := 3.0, life := 0.8) -> void:
	calls += 1
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	Fx.burst(parent, pos, colour, amount, size, speed, -5.0, life)


func dust(parent: Node, pos: Vector3, amount := 0.5, colour := DUST) -> void:
	# A low ring of dust puffs rolling out over the ground and fading, so it reads as kicked up rather than a
	# firework. `amount` 0..1 is how hard (a little hop to a big drop). Made of a few plain spheres moved by a tween,
	# not one-shot particles: those emit only a few of their puffs in their first frames, so a short burst at someone's
	# feet hardly showed.
	calls += 1
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var a := clampf(amount, 0.0, 1.0)
	var root := Node3D.new()
	root.name = "Dust"
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.06, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var n := 6 + int(8 * a)
	var reach := 0.5 + 1.1 * a
	var size := 0.18 + 0.22 * a
	var life := 0.45 + 0.3 * a
	var tw := root.create_tween().set_parallel()
	for i in n:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
		var ang := TAU * (i + randf() * 0.5) / n
		var out := Vector3(cos(ang), 0, sin(ang))
		puff.position = out * 0.15
		puff.scale = Vector3.ONE * size * 0.4
		var r := reach * randf_range(0.7, 1.0)
		tw.tween_property(puff, "position", out * r + Vector3(0, randf_range(0.05, 0.25) * (1.0 + a), 0), life) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * size * randf_range(0.8, 1.2), life * 0.4) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * size * 0.1, life * 0.6).set_delay(life * 0.4)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)


func squash(node: Node3D, amount := 0.25, time := 0.22) -> void:
	# Squash flat and wide, then spring back past round to normal (keeps the node's own scale)
	calls += 1
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var base: Vector3 = node.get_meta("juice_scale", node.scale)
	node.set_meta("juice_scale", base)
	var old: Tween = node.get_meta("juice_tween") if node.has_meta("juice_tween") else null
	if old and old.is_valid():
		old.kill()
	var tw := node.create_tween()
	tw.tween_property(node, "scale", base * Vector3(1.0 + amount * 0.6, 1.0 - amount, 1.0 + amount * 0.6), time * 0.3)
	tw.tween_property(node, "scale", base * Vector3(1.0 - amount * 0.25, 1.0 + amount * 0.35, 1.0 - amount * 0.25), time * 0.35)
	tw.tween_property(node, "scale", base, time * 0.35)
	# Forget the size once it's back, so a node whose own scale changes later (a hero made taller) isn't put back
	tw.tween_callback(func() -> void:
		if is_instance_valid(node) and node.has_meta("juice_tween") and node.get_meta("juice_tween") == tw:
			node.remove_meta("juice_scale"))
	node.set_meta("juice_tween", tw)


func rumble(weak := 0.3, seconds := 0.15, strong := 0.0) -> void:
	calls += 1
	if not bool(Settings.get("rumble")):
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(weak, 0.0, 1.0) * 0.7, clampf(strong, 0.0, 1.0) * 0.6, minf(seconds, 0.5))


func hit(parent: Node, pos: Vector3, colour: Color, big := false) -> void:
	# The usual mix for something popping
	burst(parent, pos, colour, 18 if big else 10, 0.12 if big else 0.08, 4.0 if big else 2.5)
	shake(0.45 if big else 0.18)
	rumble(0.5 if big else 0.25, 0.25 if big else 0.1, 0.4 if big else 0.0)
	if big:
		hitstop(0.07)


# -----------------------------------------------------------------------------
# Little sounds, made in code
# -----------------------------------------------------------------------------
func blip(kind: String, pitch := 1.0, volume_db := -8.0) -> void:
	# "chime" (pickups), "pop" (bubbles), "tick" (countdowns, menus), "whoosh" (boosts, portals), "thud" (landings),
	# "sparkle" (rewards), "buzz" (grinds), "rewind" (a Time Goblin blinking back in time). Each made once, then played at any pitch.
	calls += 1
	if not _blips.has(kind):
		_blips[kind] = _make(kind)
	var stream: AudioStream = _blips[kind]
	if stream == null:
		return
	var p := _players[0]
	for q in _players:
		if not q.playing:
			p = q
			break
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()


func chime_pickup() -> void:
	# Sparkles picked up quickly one after another climb the scale
	var now := Time.get_ticks_msec() / 1000.0
	_chime_i = mini(_chime_i + 1, CHIME_STEPS.size() - 1) if now - _chime_at < CHIME_WINDOW else 0
	_chime_at = now
	blip("chime", CHIME_STEPS[_chime_i], -7.0)


func chime_step() -> int:
	return _chime_i


func _make(kind: String) -> AudioStreamWAV:
	var length := {"chime": 0.28, "pop": 0.12, "tick": 0.05, "whoosh": 0.4, "thud": 0.14, "sparkle": 0.6, "buzz": 0.3, "rewind": 0.45}
	if not length.has(kind):
		return null
	var n := int(RATE * float(length[kind]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	for i in n:
		var t := float(i) / RATE
		var f := t / float(length[kind])                      # 0..1 through the sound
		var env := 1.0 - f
		var v := 0.0
		match kind:
			"chime":
				v = (sin(TAU * 1320.0 * t) + 0.4 * sin(TAU * 2640.0 * t)) * pow(env, 2.0)
			"pop":
				phase += TAU * lerpf(900.0, 300.0, f) / RATE
				v = sin(phase) * pow(env, 3.0)
			"tick":
				v = sin(TAU * 1800.0 * t) * env
			"whoosh":
				v = rng.randf_range(-1.0, 1.0) * sin(PI * f) * 0.6
			"thud":
				phase += TAU * lerpf(160.0, 60.0, f) / RATE
				v = sin(phase) * pow(env, 2.0)
			"sparkle":
				var note: float = [1.0, 1.26, 1.5, 2.0][mini(int(f * 4.0), 3)]
				v = sin(TAU * 990.0 * note * t) * pow(1.0 - fmod(f * 4.0, 1.0), 1.5) * env
			"buzz":
				v = (fmod(t * 110.0, 1.0) * 2.0 - 1.0) * 0.4 * sin(PI * f) + rng.randf_range(-0.2, 0.2) * sin(PI * f)
			"rewind":
				# a falling warble with quick clock ticks over it, like a tape wound backwards
				phase += TAU * lerpf(1400.0, 300.0, f) * (1.0 + 0.08 * sin(TAU * 18.0 * t)) / RATE
				var tick := 1.0 if fmod(t, 0.06) < 0.006 else 0.0
				v = sin(phase) * sin(PI * f) * 0.6 + tick * 0.5
		var s := int(clampf(v * 0.5, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
