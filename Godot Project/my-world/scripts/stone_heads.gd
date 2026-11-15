extends Node3D

# The Hum Heads: five giant stone heads in Rhythm Springs, in the style of the old island statues (Hayden, 15 Nov
# 2026: "Can we add some to melodies world"). Long faces, heavy brows, long noses and pursed lips, each on a stone
# plinth, with a coloured stone topknot, standing in an arc round the north-west edge of the valley and looking in
# at it. Rhythm Springs is a music world, so they sing:
#   - Walk up to one and it hums its own note: its mouth opens, its eyes glow and a note floats up. Their heads turn
#     a little to watch you go by.
#   - While the beat's broken (the world isn't mended) they hum out of tune, wobbling.
#   - Once the beat's back, hum all five and they sing their chord together: 5 sparkles, once (flag "hum_heads_song").
#   - Standing beside one is shade (a "Shade Head <n>" marker on the world, read by rhythm_springs.gd in_shade()).
# Everything's built in code at play time, so the scene isn't rebuilt. No class_name on purpose (tools compile
# class_name scripts before the autoloads exist): preload it. A first draft for Hayden: names, looks and the reward.

const CENTRE := Vector3.ZERO
const RING := 41.0                       # how far out from the valley's middle they stand
const ANGLES := [215.0, 225.0, 235.0, 245.0, 255.0]   # round the north-west edge, clear of the pools and palms
const NOTES := [130.81, 146.83, 164.81, 196.0, 220.0]  # C D E G A, low: a happy hum
const TOPKNOTS := [Color(0.95, 0.42, 0.32), Color(1.0, 0.7, 0.25), Color(0.45, 0.8, 0.55), Color(0.4, 0.65, 0.95),
	Color(0.8, 0.5, 0.9)]
const STONE := Color(0.46, 0.43, 0.42)          # dark grey island stone, so they stand out from the sandstone
const HUM_NEAR := 4.5                    # walk this close and it hums
const WATCH_NEAR := 14.0                 # it turns its head to watch you this close
const HUM_EVERY := 2.5                   # seconds before the same head hums again
const HUM_LEN := 1.3
const SPARKLES := 5
const FLAG := "hum_heads_song"

var world: Node3D
var heads: Array = []                    # [holder, face, mouth, eyes material, player, note label] for each head
var heard := [false, false, false, false, false]
var _cooldown := [0.0, 0.0, 0.0, 0.0, 0.0]
var _humming := [0.0, 0.0, 0.0, 0.0, 0.0]
var _sang_sour := false
var _player: Node3D
var _t := 0.0
var _streams := {}


static func place(w: Node3D) -> Node3D:
	var h := (load("res://scripts/stone_heads.gd") as GDScript).new() as Node3D
	h.name = "Hum Heads"
	h.set("world", w)
	w.add_child(h)
	return h


static func spot(i: int) -> Vector3:
	var a := deg_to_rad(float(ANGLES[i]))
	return CENTRE + Vector3(cos(a), 0, sin(a)) * RING


func is_mended() -> bool:
	return world != null and world.has_method("is_mended") and bool(world.call("is_mended"))


func song_sung() -> bool:
	return Dialogue.flags.get(FLAG, false)


func _ready() -> void:
	for i in ANGLES.size():
		_build(i)


func _build(i: int) -> void:
	var at := spot(i)
	var holder := Node3D.new()
	holder.name = "Head%d" % (i + 1)
	add_child(holder)
	holder.position = at
	holder.rotation.y = atan2(CENTRE.x - at.x, CENTRE.z - at.z)     # facing in, at the valley
	var stone := _mat(STONE.lerp(Color(0.52, 0.45, 0.4), i * 0.2), 0.0, 0.95)
	var dark := _mat(STONE * 0.55, 0.0, 1.0)
	# The plinth and the shoulders
	_box(holder, Vector3(2.6, 0.6, 2.0), _mat(Color(0.36, 0.34, 0.34), 0.0, 1.0), Vector3(0, 0.3, 0))
	_box(holder, Vector3(1.9, 1.4, 1.3), stone, Vector3(0, 1.3, 0))
	for sx in [-1.0, 1.0]:                                          # arms carved down the sides, hands on the tummy
		_box(holder, Vector3(0.18, 1.1, 0.25), dark, Vector3(sx * 0.9, 1.3, 0.35))
		_box(holder, Vector3(0.6, 0.14, 0.12), dark, Vector3(sx * 0.45, 0.95, 0.66))
	# The face (it turns to watch you): a tall long head tipped back a touch
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, 2.0, 0)
	holder.add_child(face)
	var tilt := Node3D.new()
	tilt.rotation.x = -0.06
	face.add_child(tilt)
	_box(tilt, Vector3(1.45, 2.5, 1.2), stone, Vector3(0, 1.25, -0.05))
	_box(tilt, Vector3(1.55, 0.32, 0.4), stone, Vector3(0, 1.85, 0.62))       # the heavy brow
	for sx in [-1.0, 1.0]:
		_box(tilt, Vector3(0.42, 0.26, 0.12), dark, Vector3(sx * 0.36, 1.58, 0.57))   # eye sockets
		_box(tilt, Vector3(0.22, 1.5, 0.3), stone, Vector3(sx * 0.8, 1.25, 0.0))      # long ears
	var eyes := _mat(TOPKNOTS[i], 0.4, 0.4)
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.1
		em.height = 0.16
		eye.mesh = em
		eye.material_override = eyes
		eye.position = Vector3(sx * 0.36, 1.58, 0.63)
		tilt.add_child(eye)
	_box(tilt, Vector3(0.34, 0.95, 0.42), stone, Vector3(0, 1.12, 0.72))      # the long nose
	_box(tilt, Vector3(0.52, 0.18, 0.4), stone, Vector3(0, 0.66, 0.74))       # its wide tip
	_box(tilt, Vector3(0.75, 0.13, 0.22), stone, Vector3(0, 0.44, 0.66))      # pursed top lip
	var mouth := _box(tilt, Vector3(0.5, 0.12, 0.1), _mat(Color(0.12, 0.08, 0.08), 0.0, 1.0), Vector3(0, 0.34, 0.68))
	mouth.name = "Mouth"
	_box(tilt, Vector3(0.7, 0.13, 0.22), stone, Vector3(0, 0.24, 0.64))       # bottom lip
	_box(tilt, Vector3(1.0, 0.3, 0.5), stone, Vector3(0, 0.06, 0.48))         # the big chin
	# The topknot: a squat stone cylinder in its own colour, a little ring on top
	var knot := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = 0.62
	km.bottom_radius = 0.7
	km.height = 0.6
	km.radial_segments = 16
	knot.mesh = km
	knot.material_override = _mat(TOPKNOTS[i], 0.0, 0.9)
	knot.position = Vector3(0, 2.8, -0.05)
	tilt.add_child(knot)
	var ring := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.3
	rm.bottom_radius = 0.38
	rm.height = 0.18
	rm.radial_segments = 12
	ring.mesh = rm
	ring.material_override = _mat(TOPKNOTS[i].darkened(0.2), 0.0, 0.9)
	ring.position = Vector3(0, 3.18, -0.05)
	tilt.add_child(ring)
	# Solid: you can't walk through one (but you can climb up the plinth)
	var body := StaticBody3D.new()
	body.name = "Stone"
	holder.add_child(body)
	for part in [[Vector3(2.6, 0.6, 2.0), Vector3(0, 0.3, 0)], [Vector3(1.9, 1.4, 1.3), Vector3(0, 1.3, 0)],
			[Vector3(1.6, 3.4, 1.5), Vector3(0, 3.7, 0.1)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		cs.shape = bs
		cs.position = part[1]
		body.add_child(cs)
	# Its hum: a note that floats up, and a sound from its mouth
	var note := Label3D.new()
	note.text = "♪"
	note.font_size = 96
	note.pixel_size = 0.012
	note.outline_size = 12
	note.modulate = Color(TOPKNOTS[i], 0.0)
	note.visible = false
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position = Vector3(0, 3.0, 1.0)
	holder.add_child(note)
	var player := AudioStreamPlayer3D.new()
	player.name = "Hum"
	player.bus = "SFX"
	player.unit_size = 6.0
	player.position = Vector3(0, 2.4, 0.8)
	holder.add_child(player)
	# Shade beside it, for the heat (rhythm_springs.gd in_shade() reads markers named "Shade..." on the world)
	if world != null and not world.has_meta("preview"):
		var shade := Marker3D.new()
		shade.name = "Shade Head %d" % (i + 1)
		shade.set_meta("radius", 2.4)
		shade.set_meta("height", 5.0)
		world.add_child.call_deferred(shade)
		shade.set_deferred("position", at)
	heads.append([holder, face, mouth, eyes, player, note])


func _process(delta: float) -> void:
	_t += delta
	if world == null or world.has_meta("preview"):
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	for i in heads.size():
		_cooldown[i] -= delta
		var h: Array = heads[i]
		var holder := h[0] as Node3D
		var to := _player.global_position - holder.global_position
		var flat := Vector2(to.x, to.z).length()
		# Watch you: the face turns towards you a little (never right round)
		var want := 0.0
		if flat < WATCH_NEAR and flat > 0.5:
			var local := holder.global_transform.basis.inverse() * to
			want = clampf(atan2(local.x, local.z), -0.55, 0.55)
		var face := h[1] as Node3D
		face.rotation.y = lerp_angle(face.rotation.y, want, minf(1.0, 2.0 * delta))
		if flat < HUM_NEAR and absf(to.y) < 4.0 and _cooldown[i] <= 0.0:
			hum(i)
		_show_hum(i, delta)


func hum(i: int) -> void:
	# One head hums its note (in tune once the beat's back, wobbly before)
	_cooldown[i] = HUM_EVERY
	_humming[i] = HUM_LEN
	heard[i] = true
	var p := heads[i][4] as AudioStreamPlayer3D
	if p.is_inside_tree():
		p.stream = _hum_stream(i, not is_mended())
		p.play()
	if not heard.has(false):
		_all_heard()


func _all_heard() -> void:
	if not is_mended():
		# Out of tune together: said once a visit, so they know there's something to come back for
		if not _sang_sour:
			_sang_sour = true
			Game.message("Out of tune! Fix the beat.")
		return
	if song_sung():
		return
	sing_together()


func sing_together() -> bool:
	# All five at once: their chord, every eye bright, a burst of notes. 5 sparkles, once
	if song_sung():
		return false
	Dialogue.flags[FLAG] = true
	for i in heads.size():
		_humming[i] = HUM_LEN * 2.0
		_cooldown[i] = HUM_LEN * 2.0
		var p := heads[i][4] as AudioStreamPlayer3D
		if p.is_inside_tree():
			p.stream = _hum_stream(i, false, 2.4)
			p.play()
		if is_inside_tree():
			var holder := heads[i][0] as Node3D
			Fx.burst(get_parent(), holder.global_position + Vector3(0, 3.5, 0.6), TOPKNOTS[i], 14, 0.08, 2.5, -1.5, 0.9)
	if is_inside_tree():
		Juice.blip("sparkle", 1.0, -4.0)
	if not Portals.practice:
		Game.add_sparkles(SPARKLES, "the Hum Heads' song")
	return true


func _show_hum(i: int, delta: float) -> void:
	# While humming: the mouth opens (and wobbles if out of tune), the eyes glow, the note floats up and fades
	_humming[i] = maxf(0.0, _humming[i] - delta)
	var k := clampf(_humming[i] / 0.3, 0.0, 1.0)
	var sour := not is_mended()
	var mouth := heads[i][2] as Node3D
	var open := k * (1.0 + (0.5 * sin(_t * 23.0) if sour else 0.15 * sin(_t * 8.0)))
	mouth.scale = Vector3(1.0 - 0.3 * k, 1.0 + 2.2 * open, 1.0)
	var eyes := heads[i][3] as StandardMaterial3D
	eyes.emission_energy_multiplier = (0.7 if is_mended() else 0.25) + 2.5 * k
	var note := heads[i][5] as Label3D
	var life: float = 1.0 - _humming[i] / HUM_LEN if _humming[i] > 0.0 else 1.0
	note.position.y = 3.0 + life * 1.6
	note.position.x = (0.3 * sin(_t * 17.0) if sour else 0.15 * sin(_t * 4.0)) * k
	note.modulate.a = k
	note.outline_modulate.a = k
	note.visible = k > 0.01


func _hum_stream(i: int, sour: bool, length := HUM_LEN) -> AudioStreamWAV:
	# A hummed "mmm": the note with two softer overtones, a slow wobble, eased in and out. Out of tune it's a bit
	# off the note and wobbles a lot. Made once and kept.
	var key := "%d_%s_%.1f" % [i, sour, length]
	if _streams.has(key):
		return _streams[key]
	var rate := 22050
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var off := (0.06 if i % 2 == 0 else -0.05) if sour else 0.0
	var f: float = NOTES[i] * (1.0 + off)
	var phase := 0.0
	for s in n:
		var t := float(s) / rate
		var wob := (0.035 * sin(TAU * 3.1 * t) if sour else 0.006 * sin(TAU * 5.0 * t))
		phase += TAU * f * (1.0 + wob) / rate
		var env := minf(1.0, t / 0.15) * minf(1.0, (length - t) / 0.4)
		var v := (sin(phase) + 0.45 * sin(phase * 2.0) + 0.2 * sin(phase * 3.0)) / 1.65 * env * 0.6
		var iv := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.encode_s16(s * 2, iv)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	_streams[key] = w
	return w


func _box(parent: Node3D, size: Vector3, m: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _mat(c: Color, glow := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m
