extends "res://scripts/gloop_king.gd"

# Tuskwinter, the Frozen Moment's boss (plan item 23, scripts/frozen_moment.gd). The file and node names still say
# "frost_gloop" / "The Frost Gloop" because saves and tests know them; nobody sees those. Since 15 Nov 2026 (Hayden:
# "the portal worlds bosses each need new unique designs instead of being copy paste of old bosses") it isn't a
# blue Gloop King any more: it's a huge grumpy frost walrus with icicle tusks, a frosty beard of whiskers, snow on its
# back, a crown of icicles and a pocket watch frozen solid on a chain round one tusk (it's been hoarding the stopped
# moment). It still fights the way it did: it belly-flops a ring of frost to jump, calls in little Snow Gloops, wakes
# once the three frozen moments are thawed, and popping it tells the world, which mends (Portals.clear). Kid-safe:
# a normal bump, no falling damage. Its look is built here in code on the Gloop King scene's Body (strip() takes the
# goo off), so the fight's own squash and bob still move it, and its flippers paddle as it moves.

const PARTS := preload("res://scripts/boss_parts.gd")
const FROST := Color(0.6, 0.85, 1.0)
const BOSS_NAME := "Tuskwinter"

var world: Node                               # the Frozen Moment, told when it's popped
var _flippers: Array[Node3D] = []
var _watch_hand: Node3D


func _ready() -> void:
	title = BOSS_NAME
	ring_colour = FROST
	ring_style = "frost"
	throw_look = "blob"                                      # snowballs
	throw_moves = ["lob", "fan"]
	super()
	_frost_puddle()
	var body := visual.get_node("Body") as Node3D
	PARTS.strip(visual)
	for d in _drops:                                         # no goo, so no drips
		(d.mesh as Node).queue_free()
	_drops.clear()
	_walrus(body)


func _frost_puddle() -> void:
	# The puddle under it is a patch of frost now
	var puddle := get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.85, 0.95, 1.0, 0.55)
		puddle.material_override = pm


func _walrus(body: Node3D) -> void:
	var look := PARTS.pivot(body, Vector3.ZERO, "Walrus")
	var hide := PARTS.mat(Color(0.56, 0.66, 0.84), 0.85)                 # frost-blue hide
	var pale := PARTS.mat(Color(0.82, 0.88, 0.97), 0.9)                  # its muzzle and belly
	var snow := PARTS.mat(Color(0.97, 0.98, 1.0), 1.0)
	var ice := PARTS.mat(Color(0.8, 0.94, 1.0), 0.05, 0.5, 0.85)
	var dark := PARTS.mat(Color(0.08, 0.08, 0.14), 0.3)
	var white := PARTS.mat(Color(1, 1, 1), 0.2, 0.6)
	var gold := PARTS.mat(Color(1.0, 0.8, 0.35), 0.3, 0.2, 1.0, 0.7)
	# Its hide and belly get a baked skin of folds and pores once they're built (scripts/detail_props.gd)
	(load("res://scripts/detail_props.gd") as GDScript).call_deferred("dress_surfaces", self, [[hide, "boss_hide"], [pale, "boss_hide"]])
	# A great round lump of a body, its belly paler
	PARTS.ball(look, 0.5, Vector3(0, 0.45, -0.08), hide, Vector3(1.15, 0.95, 1.3), "Hide")
	PARTS.ball(look, 0.42, Vector3(0, 0.38, 0.12), pale, Vector3(1.05, 0.85, 1.0), "Belly")
	# Snow drifted on its back
	PARTS.ball(look, 0.3, Vector3(0.1, 0.86, -0.25), snow, Vector3(1.3, 0.35, 1.2))
	PARTS.ball(look, 0.22, Vector3(-0.22, 0.8, -0.45), snow, Vector3(1.2, 0.35, 1.1))
	# Its head, low and heavy, with a big whiskery muzzle
	var head := PARTS.pivot(look, Vector3(0, 0.76, 0.42), "Head")
	PARTS.ball(head, 0.34, Vector3.ZERO, hide, Vector3(1.0, 0.92, 0.95))
	for side in [-1.0, 1.0]:
		PARTS.ball(head, 0.16, Vector3(side * 0.12, -0.1, 0.27), pale, Vector3(1.0, 0.9, 0.9))
		for w in 3:                                             # whisker dots, frosted white
			PARTS.ball(head, 0.016, Vector3(side * (0.08 + 0.06 * w), -0.06 - 0.03 * (w % 2), 0.4 - 0.02 * w), white)
		# Eyes, small and cross, with heavy frosty brows
		PARTS.ball(head, 0.055, Vector3(side * 0.15, 0.12, 0.26), dark)
		PARTS.ball(head, 0.018, Vector3(side * 0.135, 0.14, 0.31), white)
		PARTS.box(head, Vector3(0.15, 0.05, 0.07), Vector3(side * 0.15, 0.2, 0.26), snow, Vector3(0, 0, side * 0.35))
		# Icicle tusks, long and clear, curving down past its chin
		PARTS.spike(head, Vector3(side * 0.09, -0.18, 0.34), Vector3(side * 0.12, -1.0, 0.28), 0.55, 0.055, ice)
	PARTS.ball(head, 0.06, Vector3(0, -0.02, 0.38), dark, Vector3(1.5, 0.8, 0.9), "Nose")
	# A crown of icicles round the top of its head
	for k in 7:
		var a := TAU * k / 7.0
		PARTS.spike(head, Vector3(cos(a) * 0.17, 0.27, sin(a) * 0.15 - 0.02), Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.2),
			0.2 + 0.08 * float(k % 2), 0.04, ice)
	# The stopped moment: a gold pocket watch frozen in a lump of ice, hanging on a chain from its left tusk
	var watch := PARTS.pivot(head, Vector3(-0.17, -0.62, 0.52), "Frozen Watch")
	PARTS.cyl(watch, 0.012, 0.012, 0.36, Vector3(0.02, 0.24, -0.04), gold)
	PARTS.cyl(watch, 0.12, 0.12, 0.04, Vector3.ZERO, gold, Vector3(PI / 2, 0, 0))
	PARTS.cyl(watch, 0.1, 0.1, 0.045, Vector3(0, 0, 0.003), PARTS.mat(Color(0.98, 0.96, 0.9), 0.4), Vector3(PI / 2, 0, 0))
	_watch_hand = PARTS.pivot(watch, Vector3(0, 0, 0.03), "Hand")
	PARTS.box(_watch_hand, Vector3(0.012, 0.08, 0.01), Vector3(0, 0.035, 0), dark)
	PARTS.ball(watch, 0.17, Vector3(0, 0, 0.01), PARTS.mat(Color(0.75, 0.92, 1.0), 0.05, 0.3, 0.35))
	# Flippers: two in front it paddles with, two flat ones behind
	for side in [-1.0, 1.0]:
		var f := PARTS.pivot(look, Vector3(side * 0.5, 0.24, 0.3), "Flipper %s" % ("L" if side < 0 else "R"))
		PARTS.ball(f, 0.24, Vector3(side * 0.16, -0.12, 0.05), hide, Vector3(1.0, 0.22, 0.65)).rotation.z = side * 0.4
		_flippers.append(f)
		var b := PARTS.pivot(look, Vector3(side * 0.22, 0.08, -0.66), "Back Flipper %s" % ("L" if side < 0 else "R"))
		PARTS.ball(b, 0.2, Vector3(side * 0.08, -0.04, -0.14), hide, Vector3(0.8, 0.2, 1.1)).rotation.y = side * 0.4
		_flippers.append(b)


func _physics_process(delta: float) -> void:
	super(delta)
	# Flippers paddle while it shuffles along, and its watch's hand only ever twitches (time's stuck)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	for i in _flippers.size():
		var s := 1.0 if i % 2 == 0 else -1.0
		_flippers[i].rotation.x = (sin(_t * 7.0 + i) * 0.5 if moving else sin(_t * 1.5 + i) * 0.08) * s
	if _watch_hand:
		_watch_hand.rotation.z = sin(_t * 20.0) * 0.06 if hits > 0 else 0.0


func _call_court(count: int) -> void:
	var before := _court.size()
	super(count)
	for i in range(before, _court.size()):
		var g := _court[i] as Node
		if is_instance_valid(g):
			g.name = "Snow Gloop %d" % randi_range(100, 999)
			for m in g.get("_goo"):
				m.set_shader_parameter("deep", Color(0.25, 0.4, 0.6))
				m.set_shader_parameter("green", Color(0.75, 0.88, 1.0))
				m.set_shader_parameter("gold", Color(1, 1, 1))


func _hurt_message(stomped: bool) -> void:
	super(stomped)
	var left := stomps_to_defeat - hits
	Game.message("%s shivers! %d more to pop it." % [BOSS_NAME, left] if left > 1 else "One more and %s pops!" % BOSS_NAME)


func _defeated() -> void:
	Game.message("You popped %s! The moment it was holding on to slips free..." % BOSS_NAME)
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()
