extends "res://scripts/crocodillo_boss.gd"

# The Stormram, Glenmoor's boss (plan item 19a world 6, scripts/glenmoor.gd): the Boulderdillo's wild cousin from the
# highlands. A great shaggy armadillo-ram with a woolly fleece over its banded shell, big curly horns and a little
# storm cloud that follows it about. It charges in a WHIRLWIND: when it curls up, a twister spins up round it and it
# tears across the glen, and that spinning is what's been spinning Glenmoor's seasons round too fast.
#
# Everything the Boulderdillo does (pinball charges that end in a gust ring to jump, wool too thick for bubbles or
# stomps until it's dizzy, little ones called in at a third and two-thirds, crosser past half), plus:
#   - it sleeps on the Standing Stones until Glenmoor's three Spring Bells are rung (the world wakes it), and it
#     doesn't come back once popped: popping it tells the world, which mends (Portals.clear), and it never sets the
#     Boulderdillo's flag
#   - rolling into it (a roll on foot) only bounces you off its whirlwind, unless it's dizzy
#   - its little ones are Squalldillos: small Crocodillos with a puff of cloud on their backs
# Kid-safe like every enemy here: bumps only, and it's popped in a bubble.

const WOOL := Color(0.9, 0.86, 0.8)
const HORN := Color(0.62, 0.52, 0.42)
const STORM := Color(0.55, 0.6, 0.72)

var world: Node                                # Glenmoor, told when it's popped
var asleep := true
var _twister: Node3D
var _cloud: Node3D


func _ready() -> void:
	title = "Stormram"
	minion_name = "Squalldillos"
	bar_colour = STORM
	super()
	respawns = false
	if asleep:
		process_mode = Node.PROCESS_MODE_DISABLED
		_bar_shown(false)


func wake() -> void:
	if not asleep:
		return
	asleep = false
	process_mode = Node.PROCESS_MODE_INHERIT
	_bar_shown(true)
	Juice.shake(0.3)
	Juice.rumble(0.5, 0.4, 0.4)
	Audio.play_at("stomp", global_position, 4.0, -0.4)
	Game.message("The Stormram wakes up with a BLEAT and a gust! Dodge its whirlwind charges, jump the gusts, then pop it while it's dizzy!")


func _bar_shown(on: bool) -> void:
	if _bar:
		_bar.visible = on


func _boulders() -> void:
	# (The Boulderdillo grows boulders here: the Stormram grows wool, horns, a storm cloud and its whirlwind)
	var wool := StandardMaterial3D.new()
	wool.albedo_color = WOOL
	wool.roughness = 1.0
	var horn := StandardMaterial3D.new()
	horn.albedo_color = HORN
	horn.roughness = 0.7
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var shell := body.get_child(2) as Node3D                  # the banded shell (tools/build_crocodillo.gd)
	for n in 14:                                              # a shaggy fleece over its back
		var m := MeshInstance3D.new()
		m.name = "Wool%d" % n
		m.mesh = _puff(rng.randf_range(0.14, 0.2))
		m.material_override = wool
		var d := Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.3, 0.9), -1.0).normalized()
		m.position = d * 0.58
		shell.add_child(m)
	for n in 16:                                              # and on the rolled-up ball
		var m := MeshInstance3D.new()
		m.name = "BallWool%d" % n
		m.mesh = _puff(rng.randf_range(0.16, 0.22))
		m.material_override = wool
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		m.position = d * 0.68
		ball.add_child(m)
	var head := body.get_node("Head") as Node3D
	for side in [-1.0, 1.0]:                                  # big curly ram's horns, a spiral of shrinking beads
		var h := Node3D.new()
		h.name = "Horn %s" % ("L" if side < 0 else "R")
		h.position = Vector3(side * 0.13, 0.14, -0.02)
		head.add_child(h)
		for k in 7:
			var a := k * 0.85
			var r := 0.11 - k * 0.006
			var m := MeshInstance3D.new()
			m.mesh = _puff(0.055 - k * 0.004)
			m.material_override = horn
			m.position = Vector3(side * (0.05 + sin(a) * r), cos(a) * r, -sin(a * 0.5) * 0.06)
			h.add_child(m)
	var fringe := MeshInstance3D.new()                        # a woolly fringe over its eyes, like a highland cow's
	fringe.name = "Fringe"
	fringe.mesh = _puff(0.12)
	fringe.material_override = wool
	fringe.scale = Vector3(1.3, 0.6, 0.8)
	fringe.position = Vector3(0, 0.12, 0.08)
	head.add_child(fringe)
	# Its own little storm cloud, bobbing over it
	_cloud = Node3D.new()
	_cloud.name = "Storm Cloud"
	_cloud.position = Vector3(0, 2.0, 0)
	visual.add_child(_cloud)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = STORM
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


func _slam(reach: float) -> void:
	# A gust of wind instead of a rock slam (the ShockRing to jump), with leaves and petals flying out
	Audio.play_at("fwump", global_position, 4.0, -0.3)
	Juice.blip("whoosh", 0.7, -2.0)
	if player and global_position.distance_to(player.global_position) < 30.0:
		Juice.shake(0.25)
		Juice.rumble(0.3, 0.2, 0.4)
	ShockRing.spawn(get_parent(), global_position, reach, STORM.lightened(0.3), damage, 0.8)
	Juice.burst(get_parent(), global_position + Vector3(0, 0.6, 0), Color(1.0, 0.75, 0.85), 14, 0.08, 5.0, 1.0)


func shot(power: int, point: Vector3, dir: Vector3) -> String:
	if not defeated and state != State.DIZZY and not _told_shell:
		_told_shell = true
		Game.message("Boing! Its wool's far too thick. Dodge its whirlwind, then pop it while it's dizzy!")
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
