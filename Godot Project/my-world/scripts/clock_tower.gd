extends "res://scripts/boss_lair.gd"

# The Clockwork Tower, Grandfather Tock's own lair (Hayden, 15 Nov 2026: "I want the time goblins, and the crocodillo
# boss to get their own arenas as well"). The way in is the Tower Door, a giant grandfather clock in the middle of the
# Goblin Clockyard (scripts/bosses.gd). Inside, from the door (south) to Tock (north, +z):
#   - The Pendulum Walk: a plank walk between walls of turning gears, with three giant pendulums swinging across it.
#     Time it and run under, or get knocked back (a bump, never more). Four Time Goblins live along it.
#   - The Cog Gate: two brass towers with gears turning on top.
#   - The Clock Floor: his arena, a giant clock face lying on the floor in front of a giant clock on the far wall. He
#     sits on his dais until you come in, then hops down and the usual fight is on (scripts/time_goblin_boss.gd).
#     Its own trick: the floor's long hand sweeps round BACKWARDS once he's up (quicker when he's cross). Jump it.
#   - Pop him and the hand stops, the big clock runs the right way again, and the Cuckoo Chest by his dais opens.
# All the names and the look are first drafts for Hayden.

const GOBLIN := "res://scenes/enemies/time_goblin.tscn"
const TOCK := "res://scenes/enemies/time_goblin_boss.tscn"

const ARENA := Vector3(0, 0, 68)
const ARENA_R := 18.0
const DAIS := Vector3(0, 0, 80)
const PENDULUMS := [14.0, 22.0, 30.0]           # z of each pendulum across the walk
const PIVOT_Y := 12.0
const ARM := 10.8                               # pivot to bob
const SWING := 0.55                             # how far each swings (radians)
const SWING_TIME := 3.2                         # seconds for a whole swing there and back
const BOB_R := 1.0
const HAND_LEN := 17.0
const HAND_TURN := 10.0                         # seconds for the floor hand to go all the way round (7 when he's cross)

var hand: Node3D                                # the floor's long hand
var hand_on := false
var _bobs: Array[Node3D] = []
var _gears: Array = []                          # [gear, speed]
var _face_hands: Array[Node3D] = []
var _tick := 0.0


func lair_id() -> String:
	return "clock_tower"


func arena() -> Vector3:
	return ARENA


func wake_range() -> float:
	return 15.0


func treasure() -> int:
	return 12


func _build() -> void:
	_environment(Color(0.1, 0.16, 0.26), Color(0.95, 0.66, 0.38), Color(0.15, 0.1, 0.08), Color(0.6, 0.48, 0.38), 0.004)
	_floor(Vector2(64, 110), Vector3(0, 0, 45), Color(0.28, 0.17, 0.12), Color(0.4, 0.26, 0.17), "Tower Floor")
	_bounds(28.0, -8.0, 98.0)
	_walk()
	_cog_gate()
	_clock_floor()
	_sky_cogs()
	_goblins()


func _wood() -> StandardMaterial3D:
	return _mat("Tower Wood", Color(0.42, 0.2, 0.15), 0.7)


func _brass() -> StandardMaterial3D:
	return _mat("Brass", Color(0.88, 0.64, 0.26), 0.3, 0.05, 0.85)


func _teal() -> StandardMaterial3D:
	return _mat("Tock Glow", Color(0.35, 1.0, 0.88), 0.4, 1.4)


func _gear(parent: Node3D, r: float, at: Vector3, face: Vector3, speed: float, m: Material = null) -> Node3D:
	# A gear: a disc with teeth round it and a hub, turning about its axle (face = which way the axle points)
	var g := Node3D.new()
	g.name = "Gear"
	parent.add_child(g)
	g.position = at
	if face.abs().is_equal_approx(Vector3.UP) == false:
		g.basis = Basis.looking_at(face, Vector3.UP if absf(face.y) < 0.9 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI / 2)
	var mat: Material = m if m else _brass()
	var disc := _cyl(g, "Disc", r, r, 0.25, Vector3.ZERO, mat, false)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var teeth := maxi(8, int(r * 6.0))
	for k in teeth:
		var a := TAU * k / teeth
		var t := _box(g, "Tooth", Vector3(r * 0.22, 0.24, r * 0.2), Vector3(cos(a), 0, sin(a)) * (r + r * 0.08), mat, false)
		t.rotation.y = -a
	_cyl(g, "Hub", r * 0.25, r * 0.25, 0.4, Vector3.ZERO, _wood(), false)
	_gears.append([g, speed])
	return g


# -----------------------------------------------------------------------------
# The Pendulum Walk
# -----------------------------------------------------------------------------
func _walk() -> void:
	var w := Node3D.new()
	w.name = "Pendulum Walk"
	add_child(w)
	_box(w, "Planks", Vector3(8.0, 0.02, 40.0), Vector3(0, 0.01, 24.0), _mat("Planks", Color(0.62, 0.44, 0.28), 0.8), false)
	for z in range(6, 44, 2):
		_box(w, "Plank Line", Vector3(8.0, 0.025, 0.06), Vector3(0, 0.013, z), _mat("Plank Line", Color(0.3, 0.2, 0.12)), false)
	# Walls of turning gears both sides
	for side in [-1.0, 1.0]:
		_box(w, "Gear Wall", Vector3(1.0, 10.0, 46.0), Vector3(side * 12.0, 5.0, 23.0), _wood())
		for k in 6:
			var z := 6.0 + k * 7.0
			_gear(w, _rng.randf_range(1.4, 2.6), Vector3(side * 11.3, _rng.randf_range(3.0, 7.5), z), Vector3(-side, 0, 0),
				_rng.randf_range(0.4, 1.0) * (1.0 if k % 2 == 0 else -1.0))
	# Lamps along it
	for k in 4:
		for side in [-1.0, 1.0]:
			var at := Vector3(side * 10.8, 3.4, 9.0 + k * 10.0)
			_ball(w, "Lamp", 0.3, at, _teal(), false)
			var l := OmniLight3D.new()
			l.light_color = Color(0.5, 1.0, 0.9)
			l.light_energy = 1.4
			l.omni_range = 9.0
			l.position = at
			w.add_child(l)
	# The pendulums: a beam over the walk on two posts, a long arm and a heavy brass bob
	for z in PENDULUMS:
		for side in [-1.0, 1.0]:
			_box(w, "Pendulum Post", Vector3(0.7, PIVOT_Y + 0.6, 0.7), Vector3(side * 9.0, (PIVOT_Y + 0.6) / 2.0, z), _wood())
		_box(w, "Pendulum Beam", Vector3(19.0, 0.7, 0.9), Vector3(0, PIVOT_Y + 0.3, z), _wood(), false)
		var pivot := Node3D.new()
		pivot.name = "Pendulum"
		pivot.position = Vector3(0, PIVOT_Y, z)
		w.add_child(pivot)
		_box(pivot, "Arm", Vector3(0.18, ARM, 0.18), Vector3(0, -ARM / 2.0, 0), _brass(), false)
		var bob := _cyl(pivot, "Bob", BOB_R, BOB_R, 0.5, Vector3(0, -ARM, 0), _brass(), false)
		bob.rotation.x = PI / 2.0
		_cyl(pivot, "Bob Glow", BOB_R * 0.5, BOB_R * 0.5, 0.56, Vector3(0, -ARM, 0), _teal(), false).rotation.x = PI / 2.0
		_bobs.append(pivot)
	_sign(w, "THE CLOCKWORK TOWER\nmind the pendulums!", Vector3(-6.0, 0, 7.0), PI, Color(0.32, 0.18, 0.12))


func bob_position(k: int) -> Vector3:
	var p := _bobs[k]
	return p.global_transform * Vector3(0, -ARM, 0)


func _swing(k: int) -> float:
	return sin(_t * TAU / SWING_TIME + k * 2.1) * SWING


# -----------------------------------------------------------------------------
# The Cog Gate and the Clock Floor
# -----------------------------------------------------------------------------
func _cog_gate() -> void:
	var g := Node3D.new()
	g.name = "Cog Gate"
	add_child(g)
	for side in [-1.0, 1.0]:
		_box(g, "Gate Tower", Vector3(3.0, 9.0, 3.0), Vector3(side * 7.0, 4.5, 46.0), _wood())
		_gear(g, 1.8, Vector3(side * 7.0, 10.3, 46.0), Vector3(0, 0, -1), side * 0.8)
	_box(g, "Gate Beam", Vector3(17.0, 1.2, 1.4), Vector3(0, 8.5, 46.0), _wood(), false)
	var face := _cyl(g, "Gate Clock", 1.3, 1.3, 0.2, Vector3(0, 8.5, 45.2), _mat("Clock Cream", Color(0.98, 0.94, 0.82), 0.6, 0.3), false)
	face.rotation.x = PI / 2.0


func _clock_floor() -> void:
	var c := Node3D.new()
	c.name = "Clock Floor"
	c.position = ARENA
	add_child(c)
	var cream := _mat("Clock Cream", Color(0.98, 0.94, 0.82), 0.6, 0.3)
	var ink := _mat("Clock Ink", Color(0.12, 0.08, 0.14))
	_cyl(c, "Dial", ARENA_R, ARENA_R, 0.04, Vector3(0, 0.02, 0), cream, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cyl(c, "Dial Rim", ARENA_R + 0.6, ARENA_R + 0.6, 0.03, Vector3(0, 0.012, 0), _brass(), false)
	var numerals := ["XII", "I", "II", "III", "IIII", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	for k in 12:
		var a := TAU * k / 12.0
		var mark := _box(c, "Hour Mark", Vector3(0.5, 0.03, 1.6), Vector3(sin(a), 0, cos(a)) * (ARENA_R - 1.3) + Vector3(0, 0.05, 0), ink, false)
		mark.rotation.y = a
		var l := Label3D.new()
		l.text = numerals[k]
		l.font_size = 160
		l.pixel_size = 0.01
		l.modulate = Color(0.15, 0.1, 0.18)
		l.position = Vector3(sin(a), 0, cos(a)) * (ARENA_R - 4.0) + Vector3(0, 0.06, 0)
		l.rotation = Vector3(-PI / 2.0, a + PI, 0)
		c.add_child(l)
	# The low rail round it (a way in at the south, where the gate is)
	for k in 40:
		var a := TAU * k / 40.0
		if absf(wrapf(a - PI, -PI, PI)) < 0.32:
			continue
		_cyl(c, "Rail Post", 0.18, 0.18, 1.0, Vector3(sin(a), 0, cos(a)) * (ARENA_R + 1.2) + Vector3(0, 0.5, 0), _brass())
	# The tower's walls round the arena, hung with gears
	var wall := _cyl(c, "Tower Wall", 26.0, 26.0, 18.0, Vector3(0, 9.0, 0), _mat("Tower Wall", Color(0.36, 0.18, 0.14), 0.8), false)
	(wall.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 10:
		var a := TAU * (k + 0.5) / 10.0
		if absf(wrapf(a - PI, -PI, PI)) < 0.6 or absf(a) < 0.4:
			continue
		var at := Vector3(sin(a), 0, cos(a)) * 25.0 + Vector3(0, _rng.randf_range(4.0, 12.0), 0)
		_gear(c, _rng.randf_range(2.0, 3.6), at, -Vector3(sin(a), 0, cos(a)), _rng.randf_range(0.3, 0.7) * (1 if k % 2 else -1))
	# The giant clock on the far wall, running backwards
	var big := Node3D.new()
	big.name = "Big Clock"
	big.position = Vector3(0, 10.0, 24.6)
	c.add_child(big)
	_cyl(big, "Big Face", 8.0, 8.0, 0.4, Vector3.ZERO, cream, false).rotation.x = PI / 2.0
	_cyl(big, "Big Rim", 8.6, 8.6, 0.3, Vector3(0, 0, 0.15), _brass(), false).rotation.x = PI / 2.0
	for k in 12:
		var a := TAU * k / 12.0
		var m := _box(big, "Big Mark", Vector3(0.4, 1.2, 0.1), Vector3(sin(a), cos(a), 0) * 6.8 + Vector3(0, 0, -0.25), ink, false)
		m.rotation.z = -a
	for len in [4.2, 6.4]:
		var h := Node3D.new()
		h.name = "Big Hand"
		h.position = Vector3(0, 0, -0.35 - len * 0.01)
		big.add_child(h)
		_box(h, "Hand", Vector3(0.45 if len < 5.0 else 0.3, len, 0.08), Vector3(0, len / 2.0 - 0.5, 0), ink, false)
		_face_hands.append(h)
	# His dais, at the clock floor's far end
	_cyl(self, "Dais", 2.2, 2.4, 1.0, DAIS + Vector3(0, 0.5, 0), _brass())
	_cyl(self, "Dais Top", 2.0, 2.0, 0.06, DAIS + Vector3(0, 1.02, 0), _wood(), false)
	# The floor's long hand: still, pointing at twelve, until he's up
	hand = Node3D.new()
	hand.name = "Floor Hand"
	hand.position = ARENA + Vector3(0, 0.06, 0)
	add_child(hand)
	_box(hand, "Hand Bar", Vector3(0.55, 0.3, HAND_LEN), Vector3(0, 0.15, HAND_LEN / 2.0 + 0.8), _teal(), false)
	_box(hand, "Hand Tip", Vector3(1.4, 0.3, 1.0), Vector3(0, 0.15, HAND_LEN + 0.6), _teal(), false).rotation.y = PI / 4.0
	_cyl(hand, "Hand Hub", 1.0, 1.0, 0.35, Vector3(0, 0.15, 0), _brass(), false)
	# The Cuckoo Chest, by the dais
	_cuckoo_chest(DAIS + Vector3(-5.0, 0, -1.0))


func _cuckoo_chest(at: Vector3) -> void:
	_chest = Node3D.new()
	_chest.name = "Cuckoo Chest"
	_chest.position = at
	add_child(_chest)
	_box(_chest, "House", Vector3(1.6, 1.6, 1.2), Vector3(0, 0.8, 0), _wood())
	for side in [-1.0, 1.0]:
		var roof := _box(_chest, "Roof", Vector3(1.2, 0.12, 1.4), Vector3(side * 0.42, 1.85, 0), _mat("Roof", Color(0.25, 0.5, 0.4)), false)
		roof.rotation.z = -side * 0.6
	var face := _cyl(_chest, "Little Face", 0.4, 0.4, 0.06, Vector3(0, 1.15, -0.62), _mat("Clock Cream", Color(0.98, 0.94, 0.82), 0.6, 0.3), false)
	face.rotation.x = PI / 2.0
	var lid := Node3D.new()                                   # the little door, hinged on its left
	lid.name = "Lid"
	lid.position = Vector3(-0.3, 0.45, -0.62)
	_chest.add_child(lid)
	_box(lid, "Door", Vector3(0.6, 0.6, 0.06), Vector3(0.3, 0, 0), _brass(), false)
	var bird := Node3D.new()
	bird.name = "Cuckoo"
	bird.position = Vector3(0, 0.45, -0.3)
	bird.visible = false
	_chest.add_child(bird)
	_ball(bird, "Bird", 0.25, Vector3.ZERO, _mat("Cuckoo", Color(0.95, 0.5, 0.65)), false)
	_box(bird, "Beak", Vector3(0.1, 0.08, 0.2), Vector3(0, 0.03, -0.28), _mat("Beak", Color(1.0, 0.8, 0.2)), false)
	_treasure(at)


func _open_look() -> void:
	var lid := _chest.get_node("Lid") as Node3D
	lid.create_tween().tween_property(lid, "rotation:y", 1.8, 0.4).set_trans(Tween.TRANS_BACK)
	var bird := _chest.get_node("Cuckoo") as Node3D
	bird.visible = true
	var tw := bird.create_tween()
	tw.tween_property(bird, "position:z", -1.0, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(bird, "position:z", -0.6, 0.2)
	tw.tween_property(bird, "position:z", -1.0, 0.2)
	Juice.blip("chime", 1.3, -3.0)


func _way_look(b: Node3D) -> void:
	# A Clock Door: a brass frame with a turning teal swirl in it
	for side in [-1.0, 1.0]:
		_box(b, "Door Post", Vector3(0.3, 3.2, 0.3), Vector3(side * 1.1, 1.6, 0), _brass(), false)
	_box(b, "Door Top", Vector3(2.5, 0.35, 0.35), Vector3(0, 3.3, 0), _brass(), false)
	var swirl := _cyl(b, "Swirl", 1.0, 1.0, 0.08, Vector3(0, 1.6, 0), _mat("Door Swirl", Color(0.4, 1.0, 0.9, 0.6), 0.1, 1.2), false)
	swirl.rotation.x = PI / 2.0
	swirl.scale = Vector3(1.0, 1.0, 1.5)


func _sky_cogs() -> void:
	var s := Node3D.new()
	s.name = "Sky Cogs"
	add_child(s)
	for k in 7:
		_gear(s, _rng.randf_range(3.0, 6.0), Vector3(_rng.randf_range(-40, 40), _rng.randf_range(26, 40), _rng.randf_range(10, 110)),
			Vector3(_rng.randf_range(-0.4, 0.4), 1, _rng.randf_range(-0.4, 0.4)).normalized(), _rng.randf_range(0.1, 0.3))


func _goblins() -> void:
	var spots := [Vector3(-3, 0.3, 18), Vector3(3, 0.3, 26), Vector3(-3, 0.3, 34), Vector3(3, 0.3, 39)]
	for k in spots.size():
		var g := (load(GOBLIN) as PackedScene).instantiate() as Node3D
		g.name = "Tower Goblin %d" % (k + 1)
		g.position = spots[k]
		add_child(g)


# -----------------------------------------------------------------------------
# Tock
# -----------------------------------------------------------------------------
func _make_boss() -> CharacterBody3D:
	var tock := (load(TOCK) as PackedScene).instantiate() as CharacterBody3D
	tock.name = "Grandfather Tock"
	tock.set("size", 2.4)
	tock.set("color", Color(0.5, 1.0, 0.9))
	tock.set("stomps_to_defeat", 13)
	tock.set("damage", 2)
	tock.set("xp_reward", 50)
	tock.set("wander_radius", 7.0)
	tock.set("sight_range", 22.0)
	tock.set("leash_range", ARENA_R + 6.0)
	tock.set("wander_speed", 1.2)
	tock.set("chase_speed", 3.3)
	tock.set("blink_cooldown", 7.0)
	tock.set("blink_chance", 0.85)
	tock.set("dizzy_time", 2.4)
	tock.position = DAIS + Vector3(0, 1.4, 0)
	tock.rotation.y = 0.0
	return tock


func _on_wake() -> void:
	boss.set("home", ARENA + Vector3(0, 0.3, 4.0))
	boss.velocity = Vector3(0, 6.5, -6.0)                     # (a big hop, down off his dais)
	hand_on = true
	Game.message("GRANDFATHER TOCK: \"You're LATE!\" Jump the clock hand!")
	Audio.play_at("gloop_giggle", boss.global_position, 4.0, 0.3)


func _on_popped() -> void:
	hand_on = false


func hand_turn_time() -> float:
	return HAND_TURN * (0.7 if is_instance_valid(boss) and bool(boss.get("_cross")) else 1.0)


func _lair_step(delta: float) -> void:
	for gs in _gears:
		(gs[0] as Node3D).rotate_object_local(Vector3.UP, float(gs[1]) * delta)
	for k in _bobs.size():
		_bobs[k].rotation.z = _swing(k)
	var forwards := 1.0 if popped else -1.0                    # backwards until he's popped
	for k in _face_hands.size():
		# Seen from the floor (looking along +z) turning about +z swings the hands to the viewer's right, so this
		# is clockwise once he's popped and backwards before (it was the other way round till 23 Nov 2026).
		_face_hands[k].rotation.z += forwards * delta * (0.15 if k == 0 else 1.6)
	if hand_on:
		hand.rotation.y += delta * TAU / hand_turn_time()      # (seen from above that's backwards round the dial)
		_tick -= delta
		if _tick <= 0.0:
			_tick = 1.0
			Juice.blip("tick", 0.8, -10.0)
	var p := _player as CharacterBody3D
	if p == null or p.call("is_invulnerable"):
		return
	# A swinging bob knocks you back down the walk
	for k in _bobs.size():
		var b := bob_position(k)
		var d := Vector2(p.global_position.x - b.x, p.global_position.z - b.z).length()
		if d < BOB_R + 0.5 and p.global_position.y < b.y + 1.6:
			bump(b + Vector3(0, 0, 1.0))
			return
	# The floor hand: only on the floor, and only where the bar is
	if hand_on and p.is_on_floor() and player_low():
		var rel := p.global_position - hand.global_position
		var dir := hand.global_transform.basis.z
		var along := rel.x * dir.x + rel.z * dir.z
		var side := rel.x * dir.z - rel.z * dir.x
		if along > 1.2 and along < HAND_LEN + 1.2 and absf(side) < 0.75:
			var on := hand.global_position + Vector3(dir.x, 0, dir.z) * along
			bump(on)
