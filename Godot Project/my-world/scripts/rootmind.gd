extends "res://scripts/portal_world.gd"

# The Rootmind, Bramble's home world (plan items 19a world 1 and 22; scene built by tools/build_rootmind.gd). A
# hive-mind plant world where every plant has eyes, and they all blink together in waves, like one big slow heartbeat.
# Its time is running backwards: the blooms have closed, petals drift up off the floor, and the hive's newest seedling
# is shrinking back into a seed. The goal: wake the three **Sun Blooms** (up the leaf climb, in the tall grass, at the
# end of the root tunnel), then calm the **Thornknot**, a tangle of weeds out of step with the hive coiled round the
# seedling. It isn't fought: when the hive blinks, one of its knots glows in step for a moment, and humming along
# (Interact, or a bubble from the Star Popper) calms it. Out of step, it lashes a ring of thorns across the floor to
# jump. Three knots calm and it rejoins the hive; time runs forwards, the seedling grows, the giant flowers open, and
# Portals.clear() gives the reward (Remnants, and watching flowers round the Rootmind's portal and your garden).
#
# Bramble is here, by the arrival, quieter than in the Void: talk to her for what to do next.

const BLOOMS := ["Bloom1", "Bloom2", "Bloom3"]
const BLOOM_NAMES := ["the High Bloom", "the Whisper Bloom", "the Root Bloom"]
const BLOOM_COLOURS := [Color(1.0, 0.8, 0.35), Color(1.0, 0.55, 0.8), Color(0.7, 0.6, 1.0)]
const HIVE_BEAT := 4.0             # seconds between the hive's blinks (each starts at the Heart Glade and ripples out)
const WAVE_SPEED := 14.0           # metres a second the blink travels outwards
const IN_STEP := 1.8               # seconds after a blink when a knot glows and can be calmed
const LASH_AT := 2.6               # seconds after a blink when the Thornknot lashes, out of step
const KNOTS := 3
const KNOT_RING := 4.6             # the Thornknot coils round the seedling this far out
const FIGHT_NEAR := 14.0           # walking this close to it with all three blooms awake starts the calming
const SLIDE_TIME := 3.4
const THORN_PURPLE := Color(0.5, 0.25, 0.55)
const KNOT_GLOW := Color(0.6, 1.0, 0.45)
const KNOT_IDLE := Color(0.55, 0.22, 0.4)

const THORN_KNOT := preload("res://scripts/thorn_knot.gd")

var calming := false               # the Thornknot is up and listening for the hive
var _t := 0.0
var _beat := -1
var _lashed := -1
var _seed := 1.0
var _sliding := false
var _rustle := 0.0
var _plants: Array = []
var _blades: Array = []
var _knot_mats: Array = []


func picture() -> void:
	# In the portal's preview: the closed blooms waiting, the shrinking seedling and the Thornknot round it
	for i in BLOOMS.size():
		var m := get_node_or_null(BLOOMS[i]) as Node3D
		if m:
			m.add_child(bloom_model(BLOOM_COLOURS[i]))
	_add_seedling()
	_add_thornknot()
	_gather()


func setup() -> void:
	for i in BLOOMS.size():
		var m := get_node_or_null(BLOOMS[i]) as Node3D
		if m == null:
			continue
		var b := bloom_model(BLOOM_COLOURS[i])
		b.name = "Bloom"
		m.add_child(b)
		var spot := USE_SPOT.make(Vector3.ZERO, _bloom_offer.bind(i), _wake_bloom.bind(i), 2.2, 2.6)
		spot.name = "Spot"
		m.add_child(spot)
	var slide := get_node_or_null("Slide") as Node3D
	if slide:
		var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if _sliding else "ride a leaf down the vine",
			slide_down, 1.8, 1.8)
		spot.name = "Spot"
		slide.add_child(spot)
	_add_bramble()
	_add_seedling()
	_add_thornknot()
	_gather()
	_refresh()
	if not Portals.is_cleared(world_id) and blooms_awake() == 0:
		Game.message.call_deferred("The Rootmind: every plant here is watching you, and blinking. Talk to Bramble, by the way in.")


func _gather() -> void:
	_plants = []
	var plants := get_node_or_null("Eyeplants")
	if plants:
		for p in plants.get_children():
			var head := p.get_node_or_null("Head") as Node3D
			if head:
				_plants.append([head, Vector2(p.position.x, p.position.z).length()])
	_blades = []
	var meadow := get_node_or_null("Tall Meadow")
	if meadow:
		for b in meadow.get_children():
			_blades.append([b, (b as Node3D).rotation.y, randf() * TAU])


# The Sun Blooms -----------------------------------------------------------------------------------------------------
func bloom_id(i: int) -> String:
	return "bloom_%d" % (i + 1)


func is_awake(i: int) -> bool:
	return Portals.has_found(world_id, bloom_id(i))


func blooms_awake() -> int:
	var n := 0
	for i in BLOOMS.size():
		if is_awake(i):
			n += 1
	return n


func _bloom_offer(i: int) -> String:
	return "wake %s" % BLOOM_NAMES[i] if not is_awake(i) else ""


func _wake_bloom(i: int) -> void:
	if is_awake(i):
		return
	Portals.note_found(world_id, bloom_id(i))
	var m := get_node_or_null(BLOOMS[i]) as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.8, 0), BLOOM_COLOURS[i], 24, 0.08, 3.0, -1.0, 1.0)
	Juice.blip("chime", 0.8 + i * 0.25, -5.0)
	var n := blooms_awake()
	Game.message("%s opens and turns to the light! (%d of 3)" % [BLOOM_NAMES[i].capitalize(), n] if n < 3
		else "All three Sun Blooms are awake! The hive is nearly in step... but something in the Heart Glade isn't.")
	_refresh()


func _refresh() -> void:
	for i in BLOOMS.size():
		var b := get_node_or_null("%s/Bloom" % BLOOMS[i]) as Node3D
		if b:
			_open_bloom(b, is_awake(i) or Portals.is_cleared(world_id))
	var knot := get_node_or_null("Thornknot/Tangle") as Node3D
	var mended := Portals.is_cleared(world_id)
	if knot:
		(knot.get_node("Thorns") as Node3D).visible = not mended
		(knot.get_node("Flowers") as Node3D).visible = mended
		for k in KNOTS:
			var kn := knot.get_node_or_null("Knot%d" % k) as Node3D
			if kn:
				(kn.get_node("Calm") as Node3D).visible = knot_calm(k) or mended
				(kn.get_node("Burr") as Node3D).visible = not (knot_calm(k) or mended)
	var buds := get_node_or_null("Giant Buds")
	if buds:
		for f in buds.get_children():
			(f.get_node("Bud") as Node3D).visible = not mended
			(f.get_node("Open") as Node3D).visible = mended
	if mended:
		_seed = 1.8


static func _open_bloom(b: Node3D, open: bool) -> void:
	var petals := b.get_node_or_null("Petals")
	if petals == null:
		return
	for p in petals.get_children():
		(p as Node3D).rotation.x = -0.25 if open else -1.3        # flat out open, or standing up shut round its face
	(b.get_node("Light") as OmniLight3D).light_energy = 2.2 if open else 0.2
	for e in ["EyeL", "EyeR"]:
		(b.get_node("Face/" + e) as Node3D).scale.y = 1.0 if open else 0.12


# The leaf slide ---------------------------------------------------------------------------------------------------
func slide_down() -> void:
	var m := get_node_or_null("Slide") as Node3D
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if m == null or player == null or _sliding:
		return
	var curve := Curve3D.new()
	for p in m.get_meta("path"):
		curve.add_point(p)
	_sliding = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	Juice.blip("whoosh", 1.2, -4.0)
	var length := curve.get_baked_length()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var d := length * t
		var at := curve.sample_baked(d)
		var ahead := curve.sample_baked(minf(d + 0.5, length))
		player.global_position = at
		var visual := player.get_node_or_null("Visual") as Node3D
		if visual and ahead.distance_to(at) > 0.01:
			visual.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z),
		0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		_sliding = false
		Juice.blip("thud", 1.0, -8.0))


# The Thornknot ----------------------------------------------------------------------------------------------------
func knot_id(k: int) -> String:
	return "knot_%d" % (k + 1)


func knot_calm(k: int) -> bool:
	return Portals.has_found(world_id, knot_id(k))


func knots_calm() -> int:
	var n := 0
	for k in KNOTS:
		if knot_calm(k):
			n += 1
	return n


func in_step() -> bool:
	# Just after the hive blinks: the knots can hear it
	return calming and fmod(_t, HIVE_BEAT) < IN_STEP


func glowing_knot() -> int:
	# The knot that's listening this beat (they take turns), or -1
	if not in_step():
		return -1
	for j in KNOTS:
		var k := (_beat + j) % KNOTS
		if not knot_calm(k):
			return k
	return -1


func _knot_offer(k: int) -> String:
	if Portals.is_cleared(world_id) or knot_calm(k):
		return ""
	if not calming:
		return "look at the thorny tangle"
	return "hum along with the hive" if glowing_knot() == k else ""


func _use_knot(k: int) -> void:
	if not calming:
		Game.message("A grumpy tangle of thorny weeds, blinking all on its own, out of step with everything. %s" %
			("Bramble might know what to do." if blooms_awake() == 3 else "Wake the three Sun Blooms first."))
		Audio.play("ui_back", -8.0)
		return
	knot_hit(k)


func knot_hit(k: int) -> String:
	# Humming along (Interact) or a bubble: it calms if it's this knot's turn and the hive has just blinked
	if Portals.is_cleared(world_id) or knot_calm(k):
		return "bounce"
	if not calming or glowing_knot() != k:
		Juice.blip("pop", 0.7, -10.0)
		return "bounce"
	Portals.note_found(world_id, knot_id(k))
	var kn := get_node_or_null("Thornknot/Tangle/Knot%d" % k) as Node3D
	if kn:
		Fx.burst(self, kn.global_position + Vector3(0, 0.5, 0), KNOT_GLOW, 22, 0.08, 3.0, -1.0, 0.9)
		Juice.squash(kn, 0.3, 0.25)
	Juice.blip("chime", 1.0 + knots_calm() * 0.2, -4.0)
	_refresh()
	if knots_calm() >= KNOTS:
		mend()
	else:
		Game.message("The knot hums along and loosens into flowers. (%d of 3)" % knots_calm())
	return "hit"


func mend() -> void:
	# The Thornknot rejoins the hive: time runs forwards again
	calming = false
	Portals.clear(world_id)
	Fx.burst(self, Vector3(0, 2.5, 0), Color(0.6, 1.0, 0.45), 40, 0.1, 5.0, -1.0, 1.4)
	for i in 3:
		Fx.burst(self, Vector3(0, 2.0, 0), BLOOM_COLOURS[i], 20, 0.08, 4.0, -1.0, 1.2)
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	_refresh()


func _start_calming() -> void:
	calming = true
	_beat = int(_t / HIVE_BEAT)
	_lashed = _beat
	Game.message("The Thornknot! It lashes its thorns out of step: jump them. When the hive blinks, a knot glows: hum along (Interact, or a bubble).")
	Juice.shake(0.12)


# Every frame ------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var preview := has_meta("preview")
	var mended := not preview and Portals.is_cleared(world_id)
	var player: Node3D = null
	if not preview:
		player = get_tree().get_first_node_in_group("player") as Node3D
	var beat := int(_t / HIVE_BEAT)
	var phase := fmod(_t, HIVE_BEAT)
	if beat != _beat:
		_beat = beat
		if calming:
			Juice.blip("tick", 0.6, -12.0)
	_eyes(player, phase)
	_meadow(player, delta)
	_drift(delta, mended)
	_grow(delta, mended)
	if preview or mended:
		return
	# The calming starts once all three blooms are awake and you come near
	if not calming and blooms_awake() == 3 and player and Vector2(player.global_position.x, player.global_position.z).length() < FIGHT_NEAR:
		_start_calming()
	if calming:
		_knots_glow()
		if phase >= LASH_AT and _lashed != beat:
			_lashed = beat
			ShockRing.spawn(self, Vector3(0, 0.3, 0), 15.0, THORN_PURPLE, 1, 1.6)
			Juice.blip("whoosh", 0.6, -8.0)


func _eyes(player: Node3D, phase: float) -> void:
	# The hive blinks together: a wave from the Heart Glade outwards. Every head turns to watch the player
	for e in _plants:
		var head: Node3D = e[0]
		var since := phase - float(e[1]) / WAVE_SPEED
		var shut := since >= 0.0 and since < 0.18
		for n in ["EyeL", "EyeR"]:
			var eye := head.get_node(n) as Node3D
			eye.scale.y = 0.12 if shut else 1.0
		if player:
			var to := player.global_position - head.global_position
			head.rotation.y = lerp_angle(head.rotation.y, atan2(to.x, to.z), 0.08)
	# The Thornknot's own eyes blink when they like (out of step) until it's calm, then with the hive
	var face := get_node_or_null("Thornknot/Tangle/Face") as Node3D
	if face:
		var calm := Portals.is_cleared(world_id) and not has_meta("preview")
		var shut := (phase - KNOT_RING / WAVE_SPEED) >= 0.0 and (phase - KNOT_RING / WAVE_SPEED) < 0.18 if calm \
			else fmod(_t * 1.7 + sin(_t * 0.9), 2.3) < 0.2
		for n in ["EyeL", "EyeR"]:
			(face.get_node(n) as Node3D).scale.y = 0.12 if shut else 1.0


func _meadow(player: Node3D, delta: float) -> void:
	# The tall grass sways, and bends away from you as you brush through it (with a rustle)
	var meadow := get_node_or_null("Tall Meadow") as Node3D
	if meadow == null:
		return
	var at := Vector2.INF
	if player:
		at = Vector2(player.global_position.x - meadow.global_position.x, player.global_position.z - meadow.global_position.z)
	var brushing := false
	_rustle -= delta
	for b in _blades:
		var blade: Node3D = b[0]
		var p := Vector2(blade.position.x, blade.position.z)
		var sway := sin(_t * 1.3 + float(b[2])) * 0.06
		var lean := Vector2(sway, sway * 0.5)
		var off := p - at
		var d := off.length()
		if d < 1.8:
			lean += off.normalized() * (1.0 - d / 1.8) * 0.9
			brushing = brushing or d < 0.9
		# Lean in the world's x/z, whatever way the blade happens to face
		var yaw: float = b[1]
		var local := lean.rotated(yaw)
		blade.rotation = Vector3(local.y, yaw, -local.x)
	if brushing and _rustle <= 0.0 and player and (player as CharacterBody3D).velocity.length() > 1.0:
		_rustle = 0.35
		Juice.blip("whoosh", randf_range(1.6, 2.0), -16.0)


func _drift(delta: float, mended: bool) -> void:
	# Backwards time: petals float up off the floor. Mended: they flutter down like they should
	var petals := get_node_or_null("Backwards Petals")
	if petals == null:
		return
	for p in petals.get_children():
		var n := p as Node3D
		n.position.y += delta * (-0.5 if mended else 0.7)
		n.rotation.y += delta * 0.8
		if not mended and n.position.y > 7.0:
			n.position.y = 0.1
		elif mended and n.position.y < 0.05:
			n.position.y = 7.0


func _grow(delta: float, mended: bool) -> void:
	# The seedling shrinks back towards a seed while time runs backwards; mended, it grows into a sapling
	var s := get_node_or_null("Seedling/Sprout") as Node3D
	if s == null:
		return
	if mended:
		s.scale = s.scale.lerp(Vector3.ONE * 1.8, minf(delta * 1.5, 1.0))
		(s.get_node("Sapling") as Node3D).visible = true
	else:
		_seed = maxf(_seed - delta * 0.002, 0.45)
		s.scale = Vector3.ONE * _seed
		(s.get_node("Sapling") as Node3D).visible = false


func _knots_glow() -> void:
	var g := glowing_knot()
	for k in _knot_mats.size():
		var m: StandardMaterial3D = _knot_mats[k]
		var on := k == g
		m.emission = KNOT_GLOW if on else KNOT_IDLE
		m.emission_energy_multiplier = 2.5 if on else 0.3


# Who and what's here ----------------------------------------------------------------------------------------------
func _add_bramble() -> void:
	var m := get_node_or_null("Bramble") as Node3D
	if m == null:
		return
	var packed := load("res://models/characters/plant_girl.glb") as PackedScene
	if packed:
		var b := packed.instantiate() as Node3D
		b.name = "Model"
		m.add_child(b)
		var anim := b.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation("idle"):
			anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("idle")
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Bramble", _talk_bramble, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func bramble_lines() -> Array:
	# Bramble's quieter here: short, soft lines about what to do next
	if Portals.is_cleared(world_id):
		return ["Listen. Everything's blinking together again. Even the Thornknot.", "Thank you, {player}. Home feels like home."]
	var n := blooms_awake()
	if n == 0:
		return ["Shh... this is home. Can you feel it? Everything blinks together. Almost.",
			"Time's going backwards here. The flowers are closing, and our newest seedling is shrinking back into a seed.",
			"Wake the three Sun Blooms. One up the leaves on the big stem, one hiding in the tall grass, one through the roots."]
	if n < 3:
		var left: Array = []
		for i in BLOOMS.size():
			if not is_awake(i):
				left.append(["up the leaf climb", "in the tall grass", "at the end of the root tunnel"][i])
		return ["%d awake. The hive feels it." % n, "Still sleeping: %s." % " and ".join(left)]
	return ["Now the Thornknot, round the seedling. It's not bad. It just can't hear the rest of us.",
		"Don't fight it. When the whole hive blinks, one of its knots glows. Hum along then.",
		"And when it lashes its thorns... jump."]


func _talk_bramble() -> void:
	var spot := get_node_or_null("Bramble/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Bramble", bramble_lines(), "rootmind_bramble")


func _add_seedling() -> void:
	var m := get_node_or_null("Seedling") as Node3D
	if m:
		var s := seedling_model()
		s.name = "Sprout"
		m.add_child(s)


func _add_thornknot() -> void:
	var m := get_node_or_null("Thornknot") as Node3D
	if m == null:
		return
	var t := thornknot_model()
	t.name = "Tangle"
	m.add_child(t)
	_knot_mats = []
	for k in KNOTS:
		var kn := t.get_node("Knot%d" % k) as Node3D
		_knot_mats.append((kn.get_node("Burr/Ball") as MeshInstance3D).material_override)
		if has_meta("preview"):
			continue
		var body := THORN_KNOT.new() as StaticBody3D
		body.name = "Hit"
		body.world = self
		body.index = k
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.75
		cs.shape = sp
		body.add_child(cs)
		kn.add_child(body)
		var spot := USE_SPOT.make(Vector3(0, -0.9, 0), _knot_offer.bind(k), _use_knot.bind(k), 2.4, 2.4)
		spot.name = "Spot"
		kn.add_child(spot)


# Looks ------------------------------------------------------------------------------------------------------------
static func _ball(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	return s


static func _mat(colour: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit
	return m


static func _eye_pair(parent: Node3D, spread: float, size: float, z: float) -> void:
	var white := _mat(Color(0.98, 0.98, 0.95), 0.0, 0.3)
	var dark := _mat(Color(0.08, 0.06, 0.12), 0.0, 0.2)
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		eye.position = Vector3(side * spread, 0, z)
		parent.add_child(eye)
		var w := MeshInstance3D.new()
		w.mesh = _ball(size, 10)
		w.material_override = white
		eye.add_child(w)
		var p := MeshInstance3D.new()
		p.mesh = _ball(size * 0.55, 8)
		p.material_override = dark
		p.position = Vector3(0, -size * 0.05, size * 0.7)
		eye.add_child(p)


static func bloom_model(colour: Color) -> Node3D:
	# A Sun Bloom: a big flower on a stalk, petals shut tight round a sleepy face until it's woken
	var g := Node3D.new()
	var stalk := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.14
	c.height = 1.6
	c.radial_segments = 6
	stalk.mesh = c
	stalk.material_override = _mat(Color(0.4, 0.68, 0.3))
	stalk.position.y = 0.8
	g.add_child(stalk)
	var head := Node3D.new()
	head.position.y = 1.8
	g.add_child(head)
	var petals := Node3D.new()
	petals.name = "Petals"
	head.add_child(petals)
	var pm := _mat(colour, 0.35, 0.5)
	for j in 7:
		var pivot := Node3D.new()
		pivot.rotation.y = j * TAU / 7.0
		petals.add_child(pivot)
		var petal := MeshInstance3D.new()
		petal.mesh = _ball(0.3, 8)
		petal.material_override = pm
		petal.scale = Vector3(0.7, 0.22, 1.6)
		petal.position = Vector3(0, 0, 0.45)
		pivot.add_child(petal)
	# (the pivots are what open: rotation.x on each, set by _open_bloom)
	for p in petals.get_children():
		(p as Node3D).rotation.x = -1.3
	var face := Node3D.new()
	face.name = "Face"
	head.add_child(face)
	var disc := MeshInstance3D.new()
	disc.mesh = _ball(0.32, 12)
	disc.material_override = _mat(Color(1.0, 0.88, 0.45), 0.6, 0.5)
	disc.scale = Vector3(1, 0.5, 1)
	face.add_child(disc)
	_eye_pair(face, 0.12, 0.08, 0.24)
	for e in ["EyeL", "EyeR"]:
		var eye := face.get_node(e) as Node3D
		eye.position.y = 0.1
		eye.scale.y = 0.12
	var light := OmniLight3D.new()
	light.name = "Light"
	light.light_color = colour
	light.light_energy = 0.2
	light.omni_range = 6.0
	light.position.y = 2.2
	g.add_child(light)
	var sign := Label3D.new()
	sign.text = "Sun Bloom"
	sign.font_size = 40
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position.y = 3.0
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.add_child(sign)
	return g


static func seedling_model() -> Node3D:
	# The hive's newest seedling: a little sprout with two leaves and a bud with big eyes. Sapling is what it grows into
	var g := Node3D.new()
	var green := _mat(Color(0.5, 0.85, 0.35), 0.15)
	var stem := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.09
	c.height = 0.8
	c.radial_segments = 6
	stem.mesh = c
	stem.material_override = green
	stem.position.y = 0.4
	g.add_child(stem)
	for side in [-1.0, 1.0]:
		var leaf := MeshInstance3D.new()
		leaf.mesh = _ball(0.22, 8)
		leaf.material_override = green
		leaf.scale = Vector3(1.6, 0.25, 0.8)
		leaf.position = Vector3(side * 0.28, 0.6, 0)
		leaf.rotation.z = side * 0.4
		g.add_child(leaf)
	var bud := Node3D.new()
	bud.name = "Bud"
	bud.position.y = 0.95
	g.add_child(bud)
	var ball := MeshInstance3D.new()
	ball.mesh = _ball(0.2, 10)
	ball.material_override = _mat(Color(0.75, 0.95, 0.5), 0.3)
	bud.add_child(ball)
	_eye_pair(bud, 0.08, 0.06, 0.15)
	var sapling := Node3D.new()
	sapling.name = "Sapling"
	sapling.visible = false
	g.add_child(sapling)
	var pink := _mat(Color(1.0, 0.65, 0.85), 0.4)
	for k in 5:
		var a := k * TAU / 5.0
		var f := MeshInstance3D.new()
		f.mesh = _ball(0.12, 8)
		f.material_override = pink
		f.position = Vector3(cos(a) * 0.3, 1.15, sin(a) * 0.3)
		sapling.add_child(f)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 1.0, 0.5)
	glow.light_energy = 1.0
	glow.omni_range = 4.0
	glow.position.y = 1.0
	g.add_child(glow)
	return g


static func thornknot_model() -> Node3D:
	# The Thornknot: two tangled rings of dark purple vine with thorns, coiled round the seedling, a grumpy face with
	# eyes that blink on their own, and three knotted burrs (Knot0..2: Burr while it's tangled, Calm once it hums along).
	# Flowers is what it's covered in once it's rejoined the hive.
	var g := Node3D.new()
	var vine := _mat(Color(0.32, 0.18, 0.36), 0.0, 0.8)
	var thorns := Node3D.new()
	thorns.name = "Thorns"
	g.add_child(thorns)
	for k in 3:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = KNOT_RING - 0.35
		t.outer_radius = KNOT_RING + 0.35
		t.rings = 24
		t.ring_segments = 8
		ring.mesh = t
		ring.material_override = vine
		ring.position.y = 0.55 + k * 0.4
		ring.rotation = Vector3([0.08, -0.1, 0.18][k], k * 0.7, [0.06, -0.05, -0.14][k])
		g.add_child(ring)
	var thorn_mat := _mat(Color(0.55, 0.3, 0.5), 0.0, 0.6)
	for k in 28:
		var a := k * TAU / 28.0
		var thorn := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.16
		c.height = 0.75
		c.radial_segments = 5
		thorn.mesh = c
		thorn.material_override = thorn_mat
		var r := KNOT_RING + (0.35 if k % 2 == 0 else -0.35)
		thorn.position = Vector3(cos(a) * r, 0.7 + (k % 3) * 0.2, sin(a) * r)
		thorn.rotation = Vector3(0, -a, (PI / 2.0 if k % 2 == 0 else -PI / 2.0) * 0.8)
		thorns.add_child(thorn)
	var flowers := Node3D.new()
	flowers.name = "Flowers"
	flowers.visible = false
	g.add_child(flowers)
	var colours := [Color(1.0, 0.6, 0.8), Color(1.0, 0.85, 0.4), Color(0.75, 0.65, 1.0)]
	for k in 20:
		var a := k * TAU / 20.0 + 0.1
		var f := MeshInstance3D.new()
		f.mesh = _ball(0.2, 8)
		f.material_override = _mat(colours[k % 3], 0.5)
		f.position = Vector3(cos(a) * KNOT_RING, 1.1 + (k % 2) * 0.25, sin(a) * KNOT_RING)
		flowers.add_child(f)
	# Its face, looking towards the way in (+Z)
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, 1.5, KNOT_RING + 0.2)
	g.add_child(face)
	var lump := MeshInstance3D.new()
	lump.mesh = _ball(0.55, 10)
	lump.material_override = vine
	lump.scale = Vector3(1.3, 0.9, 0.8)
	face.add_child(lump)
	_eye_pair(face, 0.22, 0.13, 0.36)
	var brow := _mat(Color(0.2, 0.1, 0.22))
	for side in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		b.mesh = BoxMesh.new()
		b.material_override = brow
		b.scale = Vector3(0.26, 0.05, 0.05)
		b.position = Vector3(side * 0.22, 0.17, 0.44)
		b.rotation.z = side * -0.35              # grumpy
		face.add_child(b)
	# The three knots, round the sides and back (the face is at the front)
	for k in KNOTS:
		var a := PI / 2.0 + (k + 0.5) * TAU / KNOTS
		var kn := Node3D.new()
		kn.name = "Knot%d" % k
		kn.position = Vector3(cos(a) * (KNOT_RING + 0.5), 1.0, sin(a) * (KNOT_RING + 0.5))
		g.add_child(kn)
		var burr := Node3D.new()
		burr.name = "Burr"
		kn.add_child(burr)
		var ball := MeshInstance3D.new()
		ball.name = "Ball"
		ball.mesh = _ball(0.55, 10)
		ball.material_override = _mat(KNOT_IDLE, 0.3, 0.6)
		burr.add_child(ball)
		for j in 8:
			var sp := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.08
			c.height = 0.4
			c.radial_segments = 5
			sp.mesh = c
			sp.material_override = thorn_mat
			var d := Vector3(cos(j * 2.4), sin(j * 1.3) * 0.8, sin(j * 2.4)).normalized()
			sp.position = d * 0.6
			sp.look_at_from_position(sp.position, d * 2.0, Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT)
			sp.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
			burr.add_child(sp)
		var calm := Node3D.new()
		calm.name = "Calm"
		calm.visible = false
		kn.add_child(calm)
		var bloom := MeshInstance3D.new()
		bloom.mesh = _ball(0.45, 10)
		bloom.material_override = _mat(Color(0.65, 1.0, 0.5), 0.8)
		bloom.scale = Vector3(1, 0.6, 1)
		calm.add_child(bloom)
	# Solid: you can't walk through it to the seedling
	var body := StaticBody3D.new()
	body.name = "Body"
	g.add_child(body)
	for k in 16:
		var a := k * TAU / 16.0
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.55
		cy.height = 1.6
		cs.shape = cy
		cs.position = Vector3(cos(a) * KNOT_RING, 0.8, sin(a) * KNOT_RING)
		body.add_child(cs)
	var sign := Label3D.new()
	sign.text = "Thornknot"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position = Vector3(0, 2.8, KNOT_RING)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.add_child(sign)
	return g


static func eyeflower_model(colour: Color, size := 1.0) -> Node3D:
	# A watching flower for the Void (the Rootmind's reward, Portals._hub_changes): a stalk and a flower with eyes
	var g := Node3D.new()
	var h := 0.9 * size
	var stalk := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.04 * size
	c.bottom_radius = 0.07 * size
	c.height = h
	c.radial_segments = 6
	stalk.mesh = c
	stalk.material_override = _mat(Color(0.4, 0.68, 0.3))
	stalk.position.y = h / 2.0
	g.add_child(stalk)
	var head := Node3D.new()
	head.name = "Head"
	head.position.y = h
	head.scale = Vector3.ONE * size
	g.add_child(head)
	var pm := _mat(colour, 0.25)
	for j in 5:
		var pa := j * TAU / 5.0
		var p := MeshInstance3D.new()
		p.mesh = _ball(0.16, 8)
		p.material_override = pm
		p.scale = Vector3(1, 1, 0.35)
		p.position = Vector3(cos(pa) * 0.2, sin(pa) * 0.2, -0.02)
		head.add_child(p)
	var f := MeshInstance3D.new()
	f.mesh = _ball(0.17, 10)
	f.material_override = _mat(Color(0.6, 0.85, 0.4))
	f.scale = Vector3(1, 1, 0.6)
	head.add_child(f)
	_eye_pair(head, 0.075, 0.065, 0.08)
	return g
