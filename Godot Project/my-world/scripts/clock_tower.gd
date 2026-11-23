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
# The climb (Hayden, 23 Nov 2026: "multiple levels that knock you down to the bottom ... with sniper enemies, rolling
# boulder obstacles"): since then the Clock Floor is at the TOP of the tower, and the Cog Gate leads into the
# Gearworks, the tower's hollow bottom. A walkway spirals up the inside of the tower wall, nearly two turns, to a
# bridge onto the Clock Floor. Its edge is open on the inside, so anything that knocks you off drops you all the way
# back down to the Gearworks floor (falls never hurt; the climb is the cost). On the way up:
#   - Swinging Hands: four giant clock hands on the lower stretch swing in and out across the walkway. Time it.
#   - Cog Spools: big brass spools roll down the upper stretch, one every SPOOL_EVERY seconds. Jump them, or duck into
#     one of the alcoves cut into the wall (the first is the Halfway Ledge).
#   - Goblin snipers: four Time Goblins on perches round the middle column wind up and shoot slow amber bolts at you
#     (a bump, never more) whenever they can see you on the walkway. Bubbles pop them, like any goblin.
#   - The Gear Lift on the Gearworks floor takes you back up to the Halfway Ledge once you've reached it, and to the
#     top once you've been there, so a fall is never the whole climb again.
# Ideas only from open-source turrets (TurretGodot, MIT: turn towards the target at a limited speed; a souls-like
# demo, Unlicense: look along an eyeline before shooting). All the names and the look are first drafts for Hayden.

const GOBLIN := "res://scenes/enemies/time_goblin.tscn"
const TOCK := "res://scenes/enemies/time_goblin_boss.tscn"
const TELL := preload("res://scripts/boss_tell.gd")
const BOLT := preload("res://scripts/gorilla_bolt.gd")

const CENTRE := Vector3(0, 0, 68)              # the middle of the tower (and of the Clock Floor, up at TOP)
const TOP := 30.0
const ARENA := Vector3(0, TOP, 68)
const ARENA_R := 18.0
const DECK_R := 19.6                            # the Clock Floor's deck (the rail posts stand just inside it)
const DAIS := Vector3(0, TOP, 80)
# The spiral walkway: angle a (measured round from +Z, so a point is CENTRE + (sin a, 0, cos a) * r) goes down as you
# climb, from A0 (just east of the door) round nearly two turns to the top, then a flat landing on past the bridge
const R_IN := 21.6
const R_OUT := 25.8
const R_MID := 23.7
const A0 := PI - 0.62
const SWEEP := 2.0 * TAU - 1.24                 # how far round the climbing part goes
const LANDING_A := 0.95                         # the flat landing at the top, past where the climb ends
const STEP_A := 0.03                            # one slice of the walkway (alcoves line up with these)
const DEPTH := 0.6                              # how thick the walkway is
const SHAFT_R := 26.3                           # the middle of the tower's wall (1 m thick, inner face at R_OUT)
const SHAFT_H := TOP + 18.0                     # how high the wall stops you (it's drawn up to TOP; the bays above)
const DOOR_HALF := 0.14                         # the way in from the Cog Gate (radians each side of south)
const DOOR_H := 9.0
const ALCOVE_S := [0.47, 0.58, 0.67, 0.76, 0.85]   # the first is the Halfway Ledge
const ALCOVE_DEEP := 28.4
const ALCOVE_H := 3.8
const HAND_S := [0.1, 0.18, 0.26, 0.34]         # the Swinging Hands
const SWING_ARM := 5.4
const SWING_HIGH := 6.6                         # the pivot over the walkway
const SWING_AMP := 0.42
const SWING_PERIOD := 2.8
const SPOOL_START := 0.99                       # Cog Spools come out of a hatch here and roll down...
const SPOOL_END := 0.52                         # ...and tip off the edge here, just above the Halfway Ledge
const SPOOL_R := 0.85
const SPOOL_LEN := 3.4
const SPOOL_SPEED := 6.5
const SPOOL_EVERY := 11.0
const KNOCK_IN := 9.0                           # a knock off the walkway: in towards the middle, and down you go
const KNOCK_UP := 5.0
const KNOCK_STUN := 1.1
const SNIPERS := [[0.4, 10.5], [2.0, 14.0], [3.6, 18.0], [5.2, 22.0]]   # [angle round the column, perch height]
const PERCH_R := 5.2
const SNIPER_RANGE := 34.0
const SNIPER_TURN := 2.0                        # radians a second
const SNIPER_EVERY := 3.6
const SNIPER_COLOUR := Color(1.0, 0.68, 0.28)
const LIFT_AT := Vector3(0, 0, 54)
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
var hazards := true                             # the climb's hands, spools and snipers (tests switch them off)
var best := 0.0                                 # how far up the climb you've got this visit (in s)
var spools: Array = []                          # [{node, s, roll}]
var _spool_cd := 3.0
var _swings: Array = []                         # [{pivot, s, k}]
var _snipers: Array = []                        # [{goblin, cd, aim, perch}]
var _alcoves: Array = []                        # [{j, a, s, y}]
var _knocked := false
var _knock_y := 0.0
var _bonk_said := false


func lair_id() -> String:
	return "clock_tower"


func arena() -> Vector3:
	return ARENA


func wake_range() -> float:
	return 15.0


func wake_height() -> float:
	return 6.0                                  # (not from the Gearworks under his floor)


func player_low() -> bool:
	return _player != null and _player.global_position.y < global_position.y + TOP + 1.9


func treasure() -> int:
	return 12


func _build() -> void:
	_environment(Color(0.1, 0.16, 0.26), Color(0.95, 0.66, 0.38), Color(0.15, 0.1, 0.08), Color(0.6, 0.48, 0.38), 0.004)
	_floor(Vector2(70, 110), Vector3(0, 0, 45), Color(0.28, 0.17, 0.12), Color(0.4, 0.26, 0.17), "Tower Floor")
	_bounds(32.0, -8.0, 98.0)
	_plan_alcoves()
	_walk()
	_cog_gate()
	_shaft()
	_spiral()
	_climb_bits()
	_clock_floor()
	_sky_cogs()
	_goblins()
	_place_snipers()


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
		_box(w, "Gear Wall", Vector3(1.0, 10.0, 46.0), Vector3(side * 12.0, 5.0, 22.4), _wood())
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
	g.position = Vector3(0, 0, -7.5)                          # (built at z 46; moved back out of the tower's door)
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
	# Up at the top now: a deck to stand on (its underside a giant gear, seen from the Gearworks) and an unseen fence
	# round its edge, open only at the bridge
	_cyl(self, "Clock Deck", DECK_R, DECK_R, 1.0, ARENA + Vector3(0, -0.5, 0), _mat("Deck Wood", Color(0.34, 0.2, 0.14), 0.8))
	_gear(self, 15.0, ARENA + Vector3(0, -1.15, 0), Vector3.UP, 0.12)
	var fence := Node3D.new()
	fence.name = "Deck Fence"
	add_child(fence)
	for k in 64:
		var a := TAU * (k + 0.5) / 64.0
		if absf(angle_difference(a, PI)) < 0.1:
			continue
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.0 * (DECK_R + 0.3) * sin(PI / 64.0) + 0.1, 3.0, 0.3)
		_solid(fence, "Edge", bs, ARENA + Vector3(sin(a), 0, cos(a)) * (DECK_R + 0.3) + Vector3(0, 1.5, 0), Vector3(0, a, 0))
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
		_gear(s, _rng.randf_range(3.0, 6.0), Vector3(_rng.randf_range(-40, 40), TOP + _rng.randf_range(26, 40), _rng.randf_range(10, 110)),
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
	tock.set("leash_range", 17.0)                 # (he stays on his deck, up at the top)
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
	for sp in spools:
		_spool_off(sp)
	spools.clear()


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
	_climb_step(delta, p)
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


# -----------------------------------------------------------------------------
# The climb: a spiral walkway round the inside of the tower, from the Gearworks floor up to the Clock Floor
# -----------------------------------------------------------------------------
# A spot on the climb is "s": 0 where it leaves the floor, 1 where it reaches the top, a bit more along the landing.
func _a_of(s: float) -> float:
	return A0 - s * SWEEP


func _y_of(s: float) -> float:
	return clampf(s, 0.0, 1.0) * TOP


func s_end() -> float:
	return ceilf((SWEEP + LANDING_A) / STEP_A) * STEP_A / SWEEP


func bridge_s() -> float:
	return (A0 - PI + 2.0 * TAU) / SWEEP                      # where the landing passes the bridge (due south)


func _local(a: float, r: float, y: float) -> Vector3:
	return CENTRE + Vector3(sin(a) * r, y, cos(a) * r)


func path_point(s: float, r := R_MID) -> Vector3:
	# The top of the walkway at s (in the world)
	return global_transform * _local(_a_of(s), r, _y_of(s))


func s_at(pos: Vector3) -> float:
	# How far up the climb a spot is (its feet, for the player): the turn of the spiral nearest its height
	var rel := global_transform.affine_inverse() * pos - CENTRE
	var feet := rel.y - 0.9
	var s0 := (A0 - atan2(rel.x, rel.z)) / SWEEP
	var best_s := 0.0
	var best_d := INF
	for k in range(-2, 4):
		var s := s0 + k * TAU / SWEEP
		if s < -0.15 or s > s_end() + 0.05:
			continue
		var d := absf(_y_of(s) - feet)
		if d < best_d:
			best_d = d
			best_s = s
	return clampf(best_s, 0.0, s_end())


func radius_of(pos: Vector3) -> float:
	var rel := global_transform.affine_inverse() * pos - CENTRE
	return Vector2(rel.x, rel.z).length()


func _plan_alcoves() -> void:
	# Each alcove is lined up with a slice of the walkway, so its floor is the walkway's own
	for s in ALCOVE_S:
		var j := roundi(float(s) * SWEEP / STEP_A)
		var sc := j * STEP_A / SWEEP
		_alcoves.append({"j": j, "a": A0 - j * STEP_A, "s": sc, "y": _y_of(sc)})


func ledge_s() -> float:
	return float(_alcoves[0].s)


func _alcove_at(j: int) -> bool:
	for al in _alcoves:
		if j >= int(al.j) - 2 and j <= int(al.j) + 1:
			return true
	return false


func _quad(st: SurfaceTool, faces: PackedVector3Array, v: Array, n: Vector3, col: Color, solid: bool) -> void:
	st.set_color(col)
	st.set_normal(n)
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(v[i])
		if solid:
			faces.append(v[i])


func _spiral() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var n := int(ceilf((SWEEP + LANDING_A) / STEP_A))
	var plank_a := Color(0.62, 0.42, 0.26)
	var plank_b := Color(0.55, 0.36, 0.22)
	var rim := Color(0.9, 0.66, 0.28)
	var stone := Color(0.3, 0.17, 0.13)
	for j in n:
		var a0 := A0 - j * STEP_A
		var a1 := A0 - (j + 1) * STEP_A
		var y0 := _y_of(j * STEP_A / SWEEP)
		var y1 := _y_of((j + 1) * STEP_A / SWEEP)
		var ro := ALCOVE_DEEP if _alcove_at(j) else R_OUT
		var r_rim := R_IN + 0.3
		# The top: a brass edge on the inside (where you'd fall), then planks
		_quad(st, faces, [_local(a0, R_IN, y0), _local(a1, R_IN, y1), _local(a1, r_rim, y1), _local(a0, r_rim, y0)], Vector3.UP, rim, true)
		_quad(st, faces, [_local(a0, r_rim, y0), _local(a1, r_rim, y1), _local(a1, ro, y1), _local(a0, ro, y0)], Vector3.UP,
			plank_a if j % 2 == 0 else plank_b, true)
		# The inside face (down to the floor where it's low, so nobody walks under its first bit)
		var b0 := 0.0 if y0 < 3.0 else y0 - DEPTH
		var b1 := 0.0 if y1 < 3.0 else y1 - DEPTH
		var inward := -Vector3(sin((a0 + a1) / 2.0), 0, cos((a0 + a1) / 2.0))
		_quad(st, faces, [_local(a0, R_IN, y0), _local(a0, R_IN, b0), _local(a1, R_IN, b1), _local(a1, R_IN, y1)], inward, stone, true)
		# The outside face and the underside
		_quad(st, faces, [_local(a0, ro, y0), _local(a1, ro, y1), _local(a1, ro, maxf(y1 - DEPTH, 0.0)), _local(a0, ro, maxf(y0 - DEPTH, 0.0))],
			-inward, stone, true)
		if y0 >= 3.0:
			_quad(st, faces, [_local(a0, R_IN, y0 - DEPTH), _local(a0, ro, y0 - DEPTH), _local(a1, ro, y1 - DEPTH), _local(a1, R_IN, y1 - DEPTH)],
				Vector3.DOWN, stone, true)
	var mi := MeshInstance3D.new()
	mi.name = "Tower Climb"
	mi.mesh = st.commit()
	var m := _mat("Tower Planks", Color(1, 1, 1), 0.8)
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_solid(self, "Tower Climb Body", shape, Vector3.ZERO)


func _shaft() -> void:
	# The tower's round wall: pieces round the circle, with the door from the Cog Gate and a hole for each alcove
	var cuts: Array = [[PI, DOOR_HALF, -1.0, DOOR_H]]
	for al in _alcoves:
		cuts.append([fposmod(float(al.a), TAU), 0.06, float(al.y) - 0.3, float(al.y) + ALCOVE_H])
	var edges: Array = [0.0, TAU]
	for c in cuts:
		edges.append(fposmod(float(c[0]) - float(c[1]), TAU))
		edges.append(fposmod(float(c[0]) + float(c[1]), TAU))
	edges.sort()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit := BoxMesh.new()
	var body := StaticBody3D.new()
	body.name = "Tower Shaft Body"
	add_child(body)
	for e in edges.size() - 1:
		var lo: float = edges[e]
		var hi: float = edges[e + 1]
		if hi - lo < 0.001:
			continue
		var pieces := maxi(1, ceili((hi - lo) * SHAFT_R / 2.4))
		for p in pieces:
			var p0 := lo + (hi - lo) * p / pieces
			var p1 := lo + (hi - lo) * (p + 1) / pieces
			var mid := (p0 + p1) / 2.0
			# Which heights are open here
			var spans: Array = [[0.0, SHAFT_H]]
			for c in cuts:
				if absf(angle_difference(mid, float(c[0]))) < float(c[1]):
					var next: Array = []
					for sp in spans:
						if float(c[3]) <= sp[0] or float(c[2]) >= sp[1]:
							next.append(sp)
							continue
						if float(c[2]) > sp[0]:
							next.append([sp[0], float(c[2])])
						if float(c[3]) < sp[1]:
							next.append([float(c[3]), sp[1]])
					spans = next
			var width := 2.0 * SHAFT_R * sin((p1 - p0) / 2.0) + 0.06
			for sp in spans:
				var h: float = sp[1] - sp[0]
				var basis := Basis(Vector3.UP, mid)
				var at := _local(mid, SHAFT_R, (sp[0] + sp[1]) / 2.0)
				var bs := BoxShape3D.new()
				bs.size = Vector3(width, h, 1.0)
				var cs := CollisionShape3D.new()
				cs.shape = bs
				cs.transform = Transform3D(basis, at)
				body.add_child(cs)
				var top := minf(sp[1], TOP + 0.4)
				if top > sp[0]:
					var vh: float = top - sp[0]
					var xf := Transform3D(basis.scaled(Vector3(width, vh, 1.0)), _local(mid, SHAFT_R, sp[0] + vh / 2.0))
					st.append_from(unit, 0, xf)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Tower Shaft"
	mi.mesh = st.commit()
	mi.material_override = _mat("Tower Stone", Color(0.4, 0.22, 0.17), 0.85)
	add_child(mi)
	# A brass lintel over the door
	var lintel := _box(self, "Door Lintel", Vector3(8.2, 0.8, 1.3), _local(PI, SHAFT_R, DOOR_H + 0.4), _brass(), false)
	lintel.basis = Basis(Vector3.UP, PI)


func _climb_bits() -> void:
	var bits := Node3D.new()
	bits.name = "Climb Bits"
	add_child(bits)
	var stone := _mat("Tower Stone", Color(0.4, 0.22, 0.17), 0.85)
	# The alcoves: side walls, a back and a roof outside the wall, and a lamp. The first is the Halfway Ledge.
	for i in _alcoves.size():
		var al: Dictionary = _alcoves[i]
		var a := float(al.a)
		var y := float(al.y)
		for side in [-1.0, 1.0]:
			var sa: float = a + float(side) * 0.06
			var w := _box(bits, "Alcove Side", Vector3(0.25, ALCOVE_H + 0.3, 1.9), _local(sa, 27.75, y + ALCOVE_H / 2.0), stone, false)
			w.basis = Basis(Vector3.UP, sa)
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.25, ALCOVE_H + 0.3, 1.9)
			_solid(bits, "Alcove Side Body", bs, w.position, Vector3(0, sa, 0))
		var back := _box(bits, "Alcove Back", Vector3(3.6, ALCOVE_H + 0.3, 0.3), _local(a, 28.55, y + ALCOVE_H / 2.0), stone, false)
		back.basis = Basis(Vector3.UP, a)
		var bb := BoxShape3D.new()
		bb.size = Vector3(3.6, ALCOVE_H + 0.3, 0.3)
		_solid(bits, "Alcove Back Body", bb, back.position, Vector3(0, a, 0))
		var roof := _box(bits, "Alcove Top", Vector3(3.6, 0.3, 2.6), _local(a, 27.5, y + ALCOVE_H + 0.15), stone, false)
		roof.basis = Basis(Vector3.UP, a)
		_ball(bits, "Alcove Lamp", 0.22, _local(a, 28.2, y + ALCOVE_H - 0.6), _teal(), false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.9)
		l.light_energy = 1.0
		l.omni_range = 4.5
		l.position = _local(a, 27.6, y + ALCOVE_H - 0.8)
		bits.add_child(l)
		if i == 0:
			_sign(bits, "HALFWAY LEDGE\nthe Gear Lift brings you back here", _local(a + 0.035, 27.7, y), a + PI, Color(0.32, 0.18, 0.12))
	# The bridge from the top landing onto the Clock Floor
	_box(bits, "Bridge", Vector3(4.6, 0.5, 4.0), _local(PI, 20.35, TOP - 0.25), _brass())
	# The brass column up the middle, with gears turning on it
	_cyl(bits, "Brass Column", 3.0, 3.4, TOP - 1.0, CENTRE + Vector3(0, (TOP - 1.0) / 2.0, 0), _brass())
	_gear(bits, 4.4, CENTRE + Vector3(0, 6.0, 0), Vector3.UP, 0.5)
	_gear(bits, 4.6, CENTRE + Vector3(0, 26.5, 0), Vector3.UP, -0.4)
	# Gears on the wall, high over the walkway, and teal lamps along it
	for k in 8:
		var s := 0.06 + k * 0.12
		var a := _a_of(s)
		_gear(bits, _rng.randf_range(1.6, 2.6), _local(a, 25.6, _y_of(s) + 9.0), -Vector3(sin(a), 0, cos(a)),
			_rng.randf_range(0.3, 0.8) * (1.0 if k % 2 == 0 else -1.0))
	for k in 11:
		var s := 0.03 + k * 0.095
		var a := _a_of(s)
		var at := _local(a, 25.5, _y_of(s) + 3.2)
		_ball(bits, "Climb Lamp", 0.28, at, _teal(), false)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.9)
		l.light_energy = 1.6
		l.omni_range = 10.0
		l.position = at - Vector3(sin(a), 0, cos(a)) * 0.6
		bits.add_child(l)
	var warm := OmniLight3D.new()
	warm.light_color = Color(1.0, 0.7, 0.4)
	warm.light_energy = 2.0
	warm.omni_range = 34.0
	warm.position = CENTRE + Vector3(0, 12.0, 0)
	bits.add_child(warm)
	# The Gearworks floor: gears laid flush in it, and its sign
	for at in [Vector3(-9, 0.02, 0), Vector3(8, 0.02, 7), Vector3(4, 0.02, -10)]:
		_gear(bits, _rng.randf_range(2.5, 3.5), CENTRE + at, Vector3.UP, _rng.randf_range(-0.3, 0.3))
	_sign(bits, "THE GEARWORKS\nclimb to the Clock Floor!", Vector3(-6.0, 0, 50.0), PI, Color(0.32, 0.18, 0.12))
	# The hatch the Cog Spools come out of
	var ha := _a_of(SPOOL_START)
	var hatch := _box(bits, "Spool Hatch", Vector3(3.8, 2.4, 0.3), _local(ha, 25.7, _y_of(SPOOL_START) + 1.2), _wood(), false)
	hatch.basis = Basis(Vector3.UP, ha)
	_gear(bits, 0.9, _local(ha, 25.5, _y_of(SPOOL_START) + 2.9), -Vector3(sin(ha), 0, cos(ha)), 1.2)
	# The Swinging Hands: giant clock hands on pivots over the lower walkway, sweeping across it
	for k in HAND_S.size():
		var s := float(HAND_S[k])
		var a := _a_of(s)
		var tangent := Vector3(cos(a), 0, -sin(a))
		var radial := Vector3(sin(a), 0, cos(a))
		var mount := Node3D.new()
		mount.name = "Hand Mount"
		mount.transform = Transform3D(Basis(tangent, Vector3.UP, radial), _local(a, R_MID, _y_of(s) + SWING_HIGH))
		bits.add_child(mount)
		_box(mount, "Hand Beam", Vector3(0.5, 0.5, R_OUT - R_MID + 0.4), Vector3(0, 0.2, (R_OUT - R_MID) / 2.0), _wood(), false)
		var pivot := Node3D.new()
		pivot.name = "Swinging Hand"
		mount.add_child(pivot)
		_cyl(pivot, "Hand Pin", 0.35, 0.35, 0.5, Vector3.ZERO, _brass(), false).rotation.z = PI / 2.0
		_box(pivot, "Hand Rod", Vector3(0.22, SWING_ARM, 0.18), Vector3(0, -SWING_ARM / 2.0, 0), _mat("Clock Ink", Color(0.12, 0.08, 0.14)), false)
		var blade := _box(pivot, "Hand Blade", Vector3(1.8, 1.6, 0.25), Vector3(0, -SWING_ARM, 0), _mat("Clock Ink", Color(0.12, 0.08, 0.14)), false)
		var tip := _box(pivot, "Hand Tip", Vector3(1.2, 1.2, 0.22), Vector3(0, -SWING_ARM - 0.9, 0), _teal(), false)
		tip.rotation.z = PI / 4.0
		_swings.append({"pivot": pivot, "blade": blade, "s": s, "k": k})
	# The Gear Lift: once you've got somewhere, it brings you back there
	var lift := Node3D.new()
	lift.name = "Gear Lift"
	lift.position = LIFT_AT
	bits.add_child(lift)
	_cyl(lift, "Lift Plate", 1.7, 1.8, 0.2, Vector3(0, 0.1, 0), _brass(), false)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		_box(lift, "Lift Post", Vector3(0.2, 3.4, 0.2), Vector3(cos(a), 0, sin(a)) * 1.55 + Vector3(0, 1.7, 0), _wood(), false)
	_gear(lift, 1.5, Vector3(0, 3.5, 0), Vector3.UP, 0.8)
	var spot := USE_SPOT.make(LIFT_AT, _lift_offer, _ride_lift, 2.2, 2.6)
	spot.name = "Lift Spot"
	add_child(spot)


func _lift_offer() -> String:
	if best >= 1.0:
		return "ride the Gear Lift to the top"
	if not _alcoves.is_empty() and best >= ledge_s() - 0.01:
		return "ride the Gear Lift to the Halfway Ledge"
	return ""


func _ride_lift() -> void:
	var p := _player as CharacterBody3D
	if p == null:
		return
	var to := path_point(bridge_s()) if best >= 1.0 else path_point(ledge_s(), 27.0)
	Fx.burst(self, p.global_position, Color(0.9, 0.7, 0.3), 14, 0.1, 3.0, 2.0)
	p.global_position = to + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	Juice.blip("whoosh", 1.0, -4.0)
	Fx.burst(self, to + Vector3(0, 0.6, 0), Color(0.9, 0.7, 0.3), 14, 0.1, 3.0, 2.0)


func _place_snipers() -> void:
	# Little perches round the brass column, each with a Time Goblin on it who throws glowing bolts at you
	for k in SNIPERS.size():
		var a := float(SNIPERS[k][0])
		var h := float(SNIPERS[k][1])
		var dir := Vector3(sin(a), 0, cos(a))
		_cyl(self, "Sniper Perch", 2.0, 2.0, 0.4, CENTRE + dir * PERCH_R + Vector3(0, h - 0.2, 0), _wood())
		var brace := _box(self, "Perch Brace", Vector3(0.4, 0.4, 2.4), CENTRE + dir * 3.9 + Vector3(0, h - 0.6, 0), _brass(), false)
		brace.basis = Basis(Vector3.UP, a)
		var g := (load(GOBLIN) as PackedScene).instantiate() as Node3D
		g.name = "Sniper Goblin %d" % (k + 1)
		g.position = CENTRE + dir * PERCH_R + Vector3(0, h + 0.3, 0)
		g.set("wander_radius", 0.0)
		g.set("wander_speed", 0.0)
		g.set("chase_speed", 0.0)
		g.set("flee_speed", 0.0)
		g.set("sight_range", 0.0)
		add_child(g)
		_snipers.append({"goblin": g, "cd": 2.0 + k * 0.9, "wind": -1.0})


# -----------------------------------------------------------------------------
# The climb's dangers
# -----------------------------------------------------------------------------
func _climb_step(delta: float, p: CharacterBody3D) -> void:
	for sw in _swings:
		(sw.pivot as Node3D).rotation.x = sin(_t * TAU / SWING_PERIOD + int(sw.k) * 1.7) * SWING_AMP
	_spool_step(delta)
	if p == null:
		return
	var r := radius_of(p.global_position)
	var local_y := (global_transform.affine_inverse() * p.global_position).y - 0.9
	if p.is_on_floor():
		if r > 20.5 and local_y < TOP + 3.0:
			best = maxf(best, s_at(p.global_position))
		elif r < DECK_R and local_y > TOP - 0.6:
			best = maxf(best, s_end())
		if _knocked and _knock_y - local_y > 8.0 and not _bonk_said:
			_bonk_said = true
			Game.message("Bonk! All the way back to the bottom.")
		_knocked = false
	if not hazards or popped:
		return
	_sniper_step(delta, p, r, local_y)
	if p.call("is_invulnerable"):
		return
	for sw in _swings:
		var b := (sw.blade as Node3D).global_transform.affine_inverse() * p.global_position
		if absf(b.x) < 1.25 and absf(b.y) < 1.7 and absf(b.z) < 0.53:
			_knock_off(p)
			return
	for sp in spools:
		if float(sp.s) > 0.95:
			continue
		var node := sp.node as Node3D
		var rel := p.global_position - node.global_position
		var a := _a_of(float(sp.s))
		var radial := Vector3(sin(a), 0, cos(a))
		var along := rel.dot(radial)
		var flat := rel - radial * along
		flat.y = 0.0
		if absf(along) < SPOOL_LEN / 2.0 + 0.2 and flat.length() < SPOOL_R + 0.5 and p.global_position.y - 0.9 < node.global_position.y + 0.6:
			_knock_off(p)
			return


func _knock_off(p: CharacterBody3D) -> void:
	# A knock off the walkway, in towards the middle: no bump to your hearts, just the long way down
	if p.call("is_invulnerable"):
		return
	var rel := global_transform.affine_inverse() * p.global_position - CENTRE
	var out := Vector3(rel.x, 0, rel.z).normalized()
	out = global_transform.basis * out
	p.velocity = -out * KNOCK_IN + Vector3.UP * KNOCK_UP
	p.set("_stun_timer", KNOCK_STUN)
	p.set("_invulnerable_timer", KNOCK_STUN + 0.3)
	_knocked = true
	_knock_y = (global_transform.affine_inverse() * p.global_position).y - 0.9
	Juice.shake(0.35)
	Juice.blip("thud", 0.9, -2.0)
	Juice.rumble(0.5, 0.3, 0.3)


func _spool_step(delta: float) -> void:
	if hazards and not popped:
		_spool_cd -= delta
		if _spool_cd <= 0.0:
			_spool_cd = SPOOL_EVERY
			var start := path_point(SPOOL_START)
			if _player == null or _player.global_position.distance_to(start) > 5.0:
				_spawn_spool()
	var ds := SPOOL_SPEED / (SWEEP * R_MID) * delta
	for sp in spools.duplicate():
		sp.s = float(sp.s) - ds
		if float(sp.s) <= SPOOL_END:
			_spool_off(sp)
			spools.erase(sp)
			continue
		_place_spool(sp)
		sp.roll = float(sp.roll) + SPOOL_SPEED / SPOOL_R * delta
		(sp.node.get_node("Roll/Spin") as Node3D).rotation.y = float(sp.roll)


func _spawn_spool() -> void:
	var n := Node3D.new()
	n.name = "Cog Spool"
	add_child(n)
	var roll := Node3D.new()                                  # (its +Y is the spool's axle, out along the radius)
	roll.name = "Roll"
	roll.rotation.x = PI / 2.0
	n.add_child(roll)
	var spin := Node3D.new()
	spin.name = "Spin"
	roll.add_child(spin)
	_cyl(spin, "Spool Barrel", SPOOL_R * 0.8, SPOOL_R * 0.8, SPOOL_LEN - 0.6, Vector3.ZERO, _wood(), false)
	for side in [-1.0, 1.0]:
		_cyl(spin, "Spool Cog", SPOOL_R, SPOOL_R, 0.3, Vector3(0, side * (SPOOL_LEN / 2.0 - 0.15), 0), _brass(), false)
		for t in 10:
			var a := TAU * t / 10.0
			var tooth := _box(spin, "Spool Tooth", Vector3(0.22, 0.3, 0.22), Vector3(cos(a) * SPOOL_R, side * (SPOOL_LEN / 2.0 - 0.15), sin(a) * SPOOL_R),
				_brass(), false)
			tooth.rotation.y = -a
	_cyl(spin, "Spool Band", SPOOL_R * 0.84, SPOOL_R * 0.84, 0.25, Vector3.ZERO, _teal(), false)
	var sp := {"node": n, "s": SPOOL_START, "roll": 0.0}
	spools.append(sp)
	_place_spool(sp)
	Juice.blip("thud", 0.6, -6.0)


func _place_spool(sp: Dictionary) -> void:
	var s := float(sp.s)
	var a := _a_of(s)
	var n := sp.node as Node3D
	n.position = _local(a, R_MID, _y_of(s) + SPOOL_R)
	n.basis = Basis(Vector3.UP, a)                             # (so the Roll's axle, its local +Y turned to +Z, points out)


func _spool_off(sp: Dictionary) -> void:
	var n := sp.node as Node3D
	if is_instance_valid(n):
		Fx.burst(self, n.global_position, Color(0.9, 0.7, 0.3), 16, 0.1, 4.0, 2.0)
		n.queue_free()


func _sniper_step(delta: float, p: CharacterBody3D, r: float, local_y: float) -> void:
	var on_climb := r > 19.5 and r < 25.9 and local_y > 2.0 and local_y < TOP - 1.0
	for sn in _snipers:
		var g := sn.goblin as Node3D
		if not is_instance_valid(g) or bool(g.get("defeated")) or not g.visible:
			continue
		var vis := g.get_node("Visual") as Node3D
		var eye := g.global_position + Vector3(0, 0.8, 0)
		var to := p.global_position - eye
		if float(sn.wind) > 0.0:
			sn.wind = float(sn.wind) - delta
			if float(sn.wind) <= 0.0:
				sn.wind = -1.0
				_fire(g, eye, p)
			continue
		if not on_climb or to.length() > SNIPER_RANGE or not _clear_line(eye, p, g):
			continue
		var want := atan2(to.x, to.z)
		vis.rotation.y = rotate_toward(vis.rotation.y, want, SNIPER_TURN * delta)
		if absf(angle_difference(vis.rotation.y, want)) > 0.35:
			continue
		sn.cd = float(sn.cd) - delta
		if float(sn.cd) <= 0.0:
			sn.cd = SNIPER_EVERY + _rng.randf_range(0.0, 1.5)
			sn.wind = TELL.lead()
			TELL.warn(g, "throw", 1.0, SNIPER_COLOUR, TELL.lead(), {"visual": vis})


func _clear_line(from: Vector3, p: CharacterBody3D, g: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, p.global_position)
	q.exclude = [p.get_rid(), (g as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _fire(g: Node3D, eye: Vector3, p: CharacterBody3D) -> void:
	var aim := p.global_position + Vector3(p.velocity.x, 0, p.velocity.z) * 0.5 * (eye.distance_to(p.global_position) / 14.0)
	var bolt := BOLT.new()
	bolt.name = "Sniper Bolt"
	bolt.dir = (aim - eye).normalized()
	bolt.shooter = g
	bolt.colour = SNIPER_COLOUR
	bolt.speed = 14.0
	bolt.life = 3.2
	add_child(bolt)
	bolt.global_position = eye + bolt.dir * 0.6
	Juice.blip("pop", 1.3, -6.0)
