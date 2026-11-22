extends "res://scripts/time_goblin_boss.gd"

# The Dawn Snatcher, Lanternmoor's boss (plan item 19a world 3, scripts/lanternmoor.gd). Since 15 Nov 2026 (Hayden:
# "the portal worlds bosses each need new unique designs instead of being copy paste of old bosses") he isn't a big
# Time Goblin in a clock hat any more: he's a giant night magpie, a thief who loves anything that shines. Glossy
# black feathers with a sheen of teal and purple, a white belly, a robber's mask across his eyes, a long swishing tail,
# a striped scarf, and over his shoulder a swag bag with the stolen dawn glowing gold out of the top. That's why the
# sun won't rise. He still fights the way he did (he rewinds time to undo a hit, flaps out rings to jump, whistles up
# Time Goblins, gets cross past half), and popping him doesn't count as popping Tock: he tells the world, which mends
# (Portals.clear) and lets the dawn out. Kid-safe: bumps, and a bubble at the end. His look is built here in code on
# Grandfather Tock's scene (strip() takes Tock off), on the same legs, arms and head the goblin code swings, so his
# legs walk and his wings pump; his wings also flap on their own.

const PARTS := preload("res://scripts/boss_parts.gd")
const DAWN := Color(1.0, 0.72, 0.35)

var world: Node                               # Lanternmoor, told when he's popped
var _wings: Array[Node3D] = []
var _tail: Node3D
var _sun: Node3D


func _ready() -> void:
	title = "The Dawn Snatcher"
	short_title = "The Snatcher"
	bar_colour = Color(1.0, 0.7, 0.35)
	ring_colour = Color(1.0, 0.75, 0.4)
	ring_style = "dawn"
	throw_look = "feather"                                   # a spread of night feathers, and he flits away
	throw_moves = ["fan", "blink", "fan"]
	cross_line = "%s is cross now! He flaps faster."
	super()
	PARTS.strip(visual)
	_magpie()


func _magpie() -> void:
	var black := PARTS.mat(Color(0.1, 0.1, 0.18), 0.25, 0.0, 1.0, 0.2)       # glossy black feathers
	var sheen := PARTS.mat(Color(0.2, 0.55, 0.65), 0.2, 0.35, 1.0, 0.3)      # a teal sheen on wings and tail
	var purple := PARTS.mat(Color(0.45, 0.25, 0.65), 0.25, 0.25, 1.0, 0.3)
	var white := PARTS.mat(Color(0.97, 0.97, 1.0), 0.7)
	var mask := PARTS.mat(Color(0.32, 0.12, 0.45), 0.5)
	var gold := PARTS.mat(Color(1.0, 0.8, 0.3), 0.3, 0.4, 1.0, 0.6)
	var beak := PARTS.mat(Color(0.25, 0.25, 0.3), 0.3)
	var leg := PARTS.mat(Color(0.35, 0.33, 0.4), 0.6)
	var body := visual.get_node("Body") as Node3D
	# A round black body with a white belly, and a scarf in purple and gold stripes
	PARTS.ball(body, 0.3, Vector3(0, 0.03, -0.03), black, Vector3(1.0, 1.1, 1.05), "Feathers")
	PARTS.ball(body, 0.24, Vector3(0, -0.04, 0.1), white, Vector3(0.95, 1.0, 0.85), "Belly")
	for k in 3:
		PARTS.ring(body, 0.15, 0.22 - 0.01 * k, Vector3(0, 0.26 - 0.04 * k, 0.0), purple if k % 2 == 0 else gold,
			Vector3.ZERO, "Scarf %d" % k)
	PARTS.box(body, Vector3(0.08, 0.2, 0.03), Vector3(0.12, 0.12, 0.2), purple, Vector3(0.2, 0, -0.3), "Scarf End")
	# A long swishing tail, black with a teal sheen
	_tail = PARTS.pivot(body, Vector3(0, -0.1, -0.28), "Tail", Vector3(-0.55, 0, 0))
	PARTS.box(_tail, Vector3(0.18, 0.035, 0.62), Vector3(0, 0, -0.3), sheen)
	PARTS.box(_tail, Vector3(0.1, 0.04, 0.5), Vector3(0, 0.02, -0.28), black)
	# The swag bag over his shoulder, with the stolen dawn glowing out of the top
	var bag := PARTS.pivot(body, Vector3(0.2, 0.12, -0.26), "Swag Bag", Vector3(0.3, 0, -0.3))
	PARTS.ball(bag, 0.2, Vector3.ZERO, PARTS.mat(Color(0.4, 0.3, 0.55), 0.95), Vector3(1.0, 1.15, 1.0))
	PARTS.ring(bag, 0.1, 0.14, Vector3(0, 0.18, 0), gold)
	PARTS.cyl(bag, 0.015, 0.015, 0.5, Vector3(-0.2, 0.1, 0.18), PARTS.mat(Color(0.6, 0.45, 0.3), 0.8),
		Vector3(0.6, 0, 0.9))
	_sun = PARTS.pivot(bag, Vector3(0, 0.27, 0), "Dawn")
	var glow := PARTS.mat(DAWN, 0.3, 3.0)
	PARTS.ball(_sun, 0.13, Vector3.ZERO, glow)
	for k in 8:
		var a := TAU * k / 8.0
		PARTS.spike(_sun, Vector3(cos(a), sin(a), 0) * 0.12, Vector3(cos(a), sin(a), 0), 0.12, 0.03, glow)
	var light := OmniLight3D.new()
	light.name = "Dawn Glow"
	light.light_color = DAWN
	light.light_energy = 1.6
	light.omni_range = 6.0
	_sun.add_child(light)
	# Stick legs with three toes forward and one back
	for n in ["LegL", "LegR"]:
		var l := visual.get_node(n) as Node3D
		PARTS.cyl(l, 0.025, 0.03, 0.3, Vector3(0, -0.14, 0), leg)
		for t in [-0.5, 0.0, 0.5]:
			PARTS.spike(l, Vector3(0, -0.29, 0), Vector3(sin(t), -0.05, cos(t)), 0.12, 0.018, leg)
		PARTS.spike(l, Vector3(0, -0.29, 0), Vector3(0, -0.05, -1), 0.08, 0.016, leg)
	# Wings on the arms' pivots, so they pump as he walks; their own Flap pivots beat on top of that
	for n in ["ArmL", "ArmR"]:
		var side := -1.0 if n == "ArmL" else 1.0
		var arm := visual.get_node(n) as Node3D
		var w := PARTS.pivot(arm, Vector3(side * 0.02, 0.04, -0.04), "Flap")
		PARTS.ball(w, 0.28, Vector3(side * 0.03, -0.2, -0.03), black, Vector3(0.22, 1.0, 0.62), "Wing")
		PARTS.ball(w, 0.16, Vector3(side * 0.07, -0.08, 0.0), white, Vector3(0.2, 0.9, 0.8), "Patch")
		for f in 4:                                         # teal flight feathers at the tip
			PARTS.box(w, Vector3(0.03, 0.22, 0.07), Vector3(side * 0.04, -0.45 - 0.02 * f, -0.14 + 0.08 * f), sheen,
				Vector3(0.3 - 0.15 * f, 0, 0))
		_wings.append(w)
	# His head: black, with a robber's mask, gold eyes, a sharp beak and a little crest
	var head := visual.get_node("Head") as Node3D
	PARTS.ball(head, 0.21, Vector3(0, 0.02, 0.02), black, Vector3(1.0, 0.95, 1.0), "Skull")
	PARTS.box(head, Vector3(0.4, 0.09, 0.16), Vector3(0, 0.05, 0.13), mask, Vector3.ZERO, "Mask")
	for side in [-1.0, 1.0]:
		PARTS.ball(head, 0.055, Vector3(side * 0.09, 0.06, 0.19), PARTS.mat(Color(1.0, 0.85, 0.3), 0.2, 1.2))
		PARTS.ball(head, 0.025, Vector3(side * 0.09, 0.06, 0.235), PARTS.mat(Color(0.05, 0.05, 0.1), 0.2))
		PARTS.box(head, Vector3(0.1, 0.03, 0.05), Vector3(side * 0.09, 0.14, 0.19), black, Vector3(0, 0, side * 0.45))
		PARTS.box(head, Vector3(0.05, 0.035, 0.03), Vector3(side * 0.22, 0.05, 0.08), mask, Vector3(0, side * 0.6, 0))
	PARTS.spike(head, Vector3(0, -0.02, 0.18), Vector3(0, -0.15, 1), 0.24, 0.06, beak)
	for k in 3:
		PARTS.spike(head, Vector3(0, 0.2, -0.04 * k), Vector3(0, 1, -0.6 - 0.3 * k), 0.14, 0.03, sheen)


func _physics_process(delta: float) -> void:
	super(delta)
	if defeated:
		return
	# Wings beat (harder once he's cross or chasing), his tail swishes and the dawn in his bag turns and glows
	var beat := 9.0 if (_cross or state == State.CHASE) else 4.0
	for i in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = side * (0.25 + 0.35 * absf(sin(_t * beat)))
	if _tail:
		_tail.rotation.y = sin(_t * 2.6) * 0.3
	if _sun:
		_sun.rotation.z += delta * 1.2


func _blinked() -> void:
	if hits > 0:
		hits -= 1
		Game.message("The Dawn Snatcher rewound time! Pop him while he's dizzy.")
	Fx.burst(get_parent(), global_position + Vector3(0, 1.6 * size, 0), DAWN, 18, 0.1, 3.0, 0.0, 0.7)


func _defeated() -> void:
	Game.message("You popped the Dawn Snatcher! His bag falls open, and something golden floats out...")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()
