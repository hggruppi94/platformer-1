extends "res://scripts/crocodillo_boss.gd"

# The Stormram, Glenmoor's boss (plan item 19a world 6, scripts/glenmoor.gd). Since 15 Nov 2026 (Hayden: "the portal
# worlds bosses each need new unique designs instead of being copy paste of old bosses") it isn't a woolly Crocodillo
# any more: it's a great ram on four legs whose fleece is a storm cloud, pale on top and grey underneath, with little
# lightning bolts crackling in it, a long dark face with glowing eyes, gold-rimmed hooves and huge curling golden
# horns, and its own little storm cloud bobbing over it. It charges in a WHIRLWIND: when it curls up it's a whirling
# ball of cloud with its horns sticking out, a twister spins up round it and it tears across the glen, and that
# spinning is what's been spinning Glenmoor's days round too fast. Its look is built in _boulders() on the
# Boulderdillo's scene (strip() takes the Crocodillo off), on the same legs, head, jaw, tail and ball it moves.
#
# Everything the Boulderdillo does (pinball charges that end in a gust ring to jump, wool too thick for bubbles or
# stomps until it's dizzy, little ones called in at a third and two-thirds, crosser past half), plus:
#   - it sleeps on the Standing Stones until Glenmoor's three Spring Bells are rung (the world wakes it), and it
#     doesn't come back once popped: popping it tells the world, which mends (Portals.clear), and it never sets the
#     Boulderdillo's flag
#   - rolling into it (a roll on foot) only bounces you off its whirlwind, unless it's dizzy
#   - its little ones are Squalldillos: small Crocodillos with a puff of cloud on their backs (they stay Crocodillos)
# Kid-safe like every enemy here: bumps only, and it's popped in a bubble.

const PARTS := preload("res://scripts/boss_parts.gd")
const STORM := Color(0.55, 0.6, 0.72)

var world: Node                                # Glenmoor, told when it's popped
var asleep := true
var _twister: Node3D
var _cloud: Node3D
var _bolts: Array = []                         # the little lightning bolts in its fleece, flickering


func _ready() -> void:
	title = "Stormram"
	minion_name = "Squalldillos"
	bar_colour = STORM
	throw_moves = ["shot", "shot", "fan"]                    # balls of storm lightning
	throw_look = "bolt"
	throw_colour = Color(1.0, 0.95, 0.5)
	super()
	respawns = false
	if asleep:
		process_mode = Node.PROCESS_MODE_DISABLED
		_bar_shown(false)


func _moves_ok() -> bool:
	return not asleep and super()


func wake() -> void:
	if not asleep:
		return
	asleep = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_bar_shown(true)
	Juice.shake(0.3)
	Juice.rumble(0.5, 0.4, 0.4)
	Audio.play_at("stomp", global_position, 4.0, -0.4)
	Game.message("The Stormram! Dodge, then pop it when it's dizzy!")


func _bar_shown(on: bool) -> void:
	if _bar:
		_bar.visible = on


func _boulders() -> void:
	# (The Boulderdillo grows boulders here.) The Stormram takes the Crocodillo's look right off (strip()) and is built
	# fresh on the same nodes: the walk code swings LegL/LegR/ArmL/ArmR, sways the Tail, opens the Jaw and spins the
	# Ball, so moving those pivots turns the upright Crocodillo into a ram on four legs.
	PARTS.strip(body)
	PARTS.strip(ball)
	var fleece := PARTS.mat(Color(0.86, 0.88, 0.95), 1.0)                 # storm-cloud fleece, pale on top
	var cloud := PARTS.mat(STORM, 1.0)                                     # and stormy grey underneath
	var face := PARTS.mat(Color(0.24, 0.26, 0.36), 0.7)
	var muzzle := PARTS.mat(Color(0.4, 0.42, 0.52), 0.8)
	var horn := PARTS.mat(Color(0.95, 0.78, 0.35), 0.35, 0.25, 1.0, 0.5)  # golden horns that catch the lightning
	var hoof := PARTS.mat(Color(0.18, 0.18, 0.24), 0.4)
	var eye := PARTS.mat(Color(0.85, 0.95, 1.0), 0.2, 2.5)
	var bolt := PARTS.mat(Color(1.0, 0.95, 0.45), 0.3, 3.0)
	# Its fleece and storm cloud get baked curls of wool once they're built (scripts/detail_props.gd)
	(load("res://scripts/detail_props.gd") as GDScript).call_deferred("dress_surfaces", self, [[fleece, "boss_fleece"], [cloud, "boss_fleece"]])
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	# A huge cloud of a fleece, longer than it's tall
	var coat := PARTS.pivot(body, Vector3(0, 1.2, 0), "Fleece")
	for n in 26:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var at := Vector3(d.x * 0.42, d.y * 0.32, d.z * 0.62)
		PARTS.ball(coat, rng.randf_range(0.2, 0.3), at, fleece if d.y > -0.2 else cloud)
	_bolts = []
	for n in 4:                                              # little lightning bolts crackling in its fleece
		var z := PARTS.pivot(coat, Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.1, 0.35), rng.randf_range(-0.5,
			0.5)), "Bolt%d" % n, Vector3(0, rng.randf_range(0, TAU), 0))
		PARTS.box(z, Vector3(0.05, 0.16, 0.03), Vector3(0.0, 0.08, 0.3), bolt, Vector3(0, 0, 0.5))
		PARTS.box(z, Vector3(0.05, 0.16, 0.03), Vector3(0.04, -0.06, 0.3), bolt, Vector3(0, 0, -0.5))
		_bolts.append(z)
	# Four legs: the front pair on the arms' pivots, the back pair on the legs', slate grey with gold-rimmed hooves
	for n in ["ArmL", "ArmR", "LegL", "LegR"]:
		var p := body.get_node(n) as Node3D
		var side: float = -1.0 if n.ends_with("L") else 1.0
		var front: bool = n.begins_with("Arm")
		p.position = Vector3(side * 0.28, 0.9, 0.42 if front else -0.42)
		p.rotation = Vector3.ZERO
		# A woolly puff hangs down over the top of each leg, so the legs look short and sturdy, not like stilts
		PARTS.ball(p, 0.2, Vector3(0, -0.06, 0), cloud, Vector3(1.0, 1.35, 1.0))
		PARTS.cyl(p, 0.1, 0.085, 0.62, Vector3(0, -0.5, 0), face)
		PARTS.cyl(p, 0.12, 0.13, 0.12, Vector3(0, -0.84, 0.01), hoof)
		PARTS.ring(p, 0.1, 0.14, Vector3(0, -0.79, 0.01), horn)
	# The head: long and dark, a woolly fringe, glowing eyes, little ears and great curling golden horns
	var head := body.get_node("Head") as Node3D
	head.position = Vector3(0, 1.42, 0.86)
	PARTS.ball(head, 0.22, Vector3(0, 0.0, 0.0), face, Vector3(0.85, 0.95, 1.2), "Face")
	PARTS.ball(head, 0.16, Vector3(0, -0.07, 0.2), muzzle, Vector3(0.9, 0.8, 1.0), "Muzzle")
	for side in [-1.0, 1.0]:
		PARTS.ball(head, 0.045, Vector3(side * 0.13, 0.06, 0.15), eye)
		PARTS.box(head, Vector3(0.1, 0.03, 0.05), Vector3(side * 0.12, 0.12, 0.16), face, Vector3(0, 0, side * 0.4))
		PARTS.ball(head, 0.03, Vector3(side * 0.05, -0.08, 0.36), hoof)                  # nostrils
		PARTS.ball(head, 0.08, Vector3(side * 0.22, 0.05, -0.05), face, Vector3(1.2, 0.4, 0.6)).rotation.z = side * -0.5
		var h := PARTS.pivot(head, Vector3(side * 0.15, 0.13, -0.06), "Horn %s" % ("L" if side < 0 else "R"))
		for k in 11:                                            # a spiral of beads, curling back, down and round
			var a := k * 0.6
			var r := 0.06 + k * 0.016
			PARTS.ball(h, 0.075 - k * 0.004, Vector3(side * (0.04 + k * 0.022), cos(a) * r, -sin(a) * r), horn)
	for k in 4:
		PARTS.ball(head, 0.1, Vector3((k - 1.5) * 0.08, 0.2, 0.05), fleece)
	var jaw := head.get_node("Jaw") as Node3D
	PARTS.box(jaw, Vector3(0.18, 0.05, 0.2), Vector3(0, -0.06, 0.22), muzzle)
	# A puff of a tail
	var tail := body.get_node("Tail") as Node3D
	tail.position = Vector3(0, 1.3, -0.68)
	PARTS.ball(tail, 0.14, Vector3(0, 0, -0.06), fleece)
	# Curled up, it's a whirling ball of storm cloud with its horns sticking out
	for n in 22:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		PARTS.ball(ball, rng.randf_range(0.2, 0.28), d * 0.56, fleece if d.y > 0.0 else cloud)
	for side in [-1.0, 1.0]:
		for k in 8:
			var a := k * 0.7
			PARTS.ball(ball, 0.08 - k * 0.005, Vector3(side * (0.6 + k * 0.02), cos(a) * (0.1 + k * 0.02),
				0.35 - sin(a) * (0.1 + k * 0.02)), horn)
	PARTS.ball(ball, 0.05, Vector3(-0.12, 0.2, 0.68), eye)
	PARTS.ball(ball, 0.05, Vector3(0.12, 0.2, 0.68), eye)
	# Its own little storm cloud, bobbing over it
	_cloud = Node3D.new()
	_cloud.name = "Storm Cloud"
	_cloud.position = Vector3(0, 2.4, 0)
	visual.add_child(_cloud)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = STORM.darkened(0.15)
	grey.roughness = 1.0
	for k in 5:
		var m := MeshInstance3D.new()
		m.mesh = _puff(0.28 + 0.06 * (k % 2))
		m.material_override = grey
		m.position = Vector3((k - 2) * 0.24, 0.05 * (k % 2), 0.08 * ((k * 7) % 3 - 1))
		_cloud.add_child(m)
	# The whirlwind: three see-through cones, only spinning while it charges
	_twister = Node3D.new()
	_twister.name = "Whirlwind"
	_twister.visible = false
	visual.add_child(_twister)
	var swirl := StandardMaterial3D.new()
	swirl.albedo_color = Color(0.85, 0.9, 1.0, 0.28)
	swirl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swirl.cull_mode = BaseMaterial3D.CULL_DISABLED
	swirl.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 3:
		var m := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 1.0 + k * 0.15
		c.bottom_radius = 0.35 + k * 0.1
		c.height = 1.9
		c.radial_segments = 9
		c.cap_top = false
		c.cap_bottom = false
		m.mesh = c
		m.material_override = swirl
		m.position.y = 0.9 + k * 0.08
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_twister.add_child(m)


static func _puff(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.8
	s.radial_segments = 8
	s.rings = 4
	return s


func _physics_process(delta: float) -> void:
	super(delta)
	if _twister:
		var spinning := not defeated and (state == State.CURL or state == State.ROLL)
		_twister.visible = spinning
		if spinning:
			_twister.rotation.y += delta * 14.0
	if _cloud:
		_cloud.position.y = 2.0 + sin(_t * 2.0) * 0.08
		_cloud.rotation.y += delta * 0.4
	for i in _bolts.size():                             # crackle on and off, more while it's cross or charging
		var b := _bolts[i] as Node3D
		b.visible = sin(_t * (13.0 + 3.0 * i) + i * 2.0) > (0.2 if state == State.ROLL or state == State.CURL else 0.6)


func _slam(reach: float) -> void:
	# A gust of wind instead of a rock slam (the ShockRing to jump), with leaves and petals flying out
	Audio.play_at("fwump", global_position, 4.0, -0.3)
	Juice.blip("whoosh", 0.7, -2.0)
	if player and global_position.distance_to(player.global_position) < 30.0:
		Juice.shake(0.25)
		Juice.rumble(0.3, 0.2, 0.4)
	ShockRing.spawn(get_parent(), global_position, reach, STORM.lightened(0.3), damage, 0.8, "gust")
	Juice.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(1.0, 0.75, 0.85), 14, 0.08, 5.0, 1.0)


func shot(power: int, point: Vector3, dir: Vector3) -> String:
	if not defeated and state != State.DIZZY and not _told_shell:
		_told_shell = true
		Game.message("Boing! Pop it while it's dizzy!")
	return super(power, point, dir)


func _touch_player() -> void:
	# Rolling into it on foot doesn't knock it out in one go like a little Crocodillo: its whirlwind bounces you off,
	# unless it's dizzy (then it counts as a stomp)
	var curled := state == State.CURL or state == State.ROLL
	if not curled and player.is_rolling():
		if state == State.DIZZY:
			_stomped()
		else:
			player.bounce(SHELL_BOUNCE * 0.6)
			Audio.play_at("boing", global_position)
		return
	super()


func _call_pebbles(count: int) -> void:
	var before := pebbles().size()
	super(count)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = STORM
	grey.roughness = 1.0
	for i in range(before, _pebbles.size()):
		var c := _pebbles[i] as Node3D
		if not is_instance_valid(c):
			continue
		c.name = "Squalldillo %d" % randi_range(100, 999)
		var puff := MeshInstance3D.new()
		puff.name = "Cloud Puff"
		puff.mesh = _puff(0.25)
		puff.material_override = grey
		puff.position = Vector3(0, 1.0, 0)
		var v := c.get_node_or_null("Visual") as Node3D
		(v if v else c).add_child(puff)


func _defeated() -> void:
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	for p in pebbles():                                  # its Squalldillos blow away with it
		if is_instance_valid(p) and not p.get("defeated"):
			p.queue_free()
	if world and is_instance_valid(world):
		world.call("mend")
	else:
		Game.message("You popped the Stormram!")
