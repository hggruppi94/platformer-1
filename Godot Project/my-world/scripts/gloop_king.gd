extends "res://scripts/gloop.gd"

# The Gloop King, from Hayden's picture (Oct 29, 2026): the biggest, goldest Gloop, with a little gold crown and a red
# gem. He holds court in his own spot with Gloops around him. He's slow, but every few seconds while he's after you he
# does a royal belly-flop: a big hop that sends a ring of goo across the ground (jump over it). Each hit makes him
# wobble; at two-thirds and one-third of his goo he calls in two more Gloops. Pop him with enough bubbles (a big
# bubble counts for three) or stomps and he's carried off in a bubble like any Gloop, then comes back much later.
# Past half his goo he gets cross (Nov 1, 2026: every boss ramps up): quicker, belly-flops more often, and each flop
# sends a second, wider wave of goo (scripts/shock_ring.gd) after the first.
# Kid-safe: he never does more than a normal bump, and nothing about him is gory.
# Scene: scenes/enemies/gloop_king.tscn (built by tools/build_gloop.gd), placed by tools/build_town.gd.

const NAME := "Gloop King"
const COURTIER := preload("res://scenes/enemies/gloop.tscn")
const MAX_COURT := 4                          # never more than this many called-in Gloops about at once

@export var flop_every := 5.0                 # seconds between belly-flops while he's chasing
@export var flop_reach := 4.5                 # how far the goo ring spreads (metres, at size 1; it grows with size)

const TELL := preload("res://scripts/boss_tell.gd")
const MOVES := preload("res://scripts/boss_moves.gd")   # his throws (and blinks): every boss has a ranged move

var _flop_timer := 3.0
var _flopping := false
var _calls_made := 0
var _court: Array[Node] = []
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _cross := false                           # under half his goo: quicker, flops more often, and a second wave
var _base := []
var title := NAME                             # the name over the meter (the Frost Gloop, scripts/frost_gloop.gd, has its own)
var ring_colour := Color(0.6, 0.85, 0.15)     # the goo ring's colour: green goo for the King
var throw_moves := ["lob", "lob", "shot"]      # lobbed goo blobs, now and then one flicked straight at you
var throw_look := "blob"                      # what he throws (scripts/boss_bits.gd); his cousins set their own
var ring_style := "goo"                        # how his wave looks (scripts/shock_ring.gd STYLES): his cousins set their own
var court_stats := {}                         # set on every Gloop he calls in (his kingdom's fiercer subjects)
var court_call := 2                           # how many he calls in each time


func _ready() -> void:
	super()
	add_to_group("bosses")
	if process_mode != Node.PROCESS_MODE_DISABLED:            # (in his own kingdom the crates go round the court instead)
		Arsenal.supply_boss(self)                             # ammo crates round the fight (scripts/arsenal.gd)
	_make_bar()
	_base = [chase_speed, flop_every]
	MOVES.add(self, {"moves": throw_moves, "every": 6.0, "look": throw_look, "colour": ring_colour,
		"size": 0.55, "from": 1.4 * size,
		"can": func() -> bool: return not defeated and _was_chasing and not _flopping and is_on_floor()})


func _physics_process(delta: float) -> void:
	super(delta)
	if defeated:
		_bar.visible = false
		return
	var near := player != null and global_position.distance_to(player.global_position) < sight_range + 6.0
	_bar.visible = near
	var cam := get_viewport().get_camera_3d()
	if near and cam:
		_bar.global_basis = cam.global_basis                  # the meter always faces you
	_bar_fill.scale.x = maxf(0.001, 1.0 - float(hits) / stomps_to_defeat)
	_bar_fill.position.x = -0.5 * (1.0 - _bar_fill.scale.x)
	if not _cross and hits * 2 >= stomps_to_defeat:
		_cross = true
		chase_speed = _base[0] * 1.25
		flop_every = _base[1] * 0.65
		Game.message("The %s is cross! Flopping faster!" % title)
	# The belly-flop: only while chasing and on the ground
	if _flopping:
		if is_on_floor() and velocity.y <= 0.0:
			_flopping = false
			_land()
		return
	if _was_chasing and is_on_floor() and _squash <= 0.0:
		_flop_timer -= delta
		if _flop_timer <= TELL.lead() and not TELL.showing(self):
			# The warning: a ring on the ground as far as the goo will roll. It lasts through the hop, so it's
			# still there when he lands.
			TELL.warn(self, "jump", flop_reach * size * (1.6 if _cross else 1.0), ring_colour, maxf(_flop_timer, 0.0) + 1.2)
		if _flop_timer <= 0.0:
			_flop_timer = flop_every * randf_range(0.85, 1.2)
			_flopping = true
			velocity.y = 6.5
			Audio.play_at("gloop_giggle", global_position, 2.0, 0.0)


func _land() -> void:
	# A wobble on landing and a ring of goo across the ground. It only bumps you if you're standing on the ground
	# inside the ring; jumping over it is the trick.
	_squash = 0.45
	Audio.play_at("stomp", global_position, 3.0, 0.0)
	if player and global_position.distance_to(player.global_position) < 25.0:
		Juice.shake(0.4)                              # the royal belly-flop shakes the ground
		Juice.rumble(0.4, 0.25, 0.5)
	var reach := flop_reach * size
	_goo_ring(reach)
	if _cross:                                    # cross: a second, wider wave of goo rolls out after the first
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if not defeated and is_inside_tree():
				ShockRing.spawn(get_parent(), global_position, reach * 1.6, ring_colour, damage, 0.9, ring_style))
	if player and not player.is_invulnerable() and player.is_on_floor():
		var d := _flat(player.global_position - global_position)
		if d < reach and d > 0.6 * size:
			player.hurt(damage, global_position)


func _goo_ring(reach: float) -> void:
	# The wave of goo you see roll out (scripts/shock_ring.gd, in his own style). It doesn't bump you itself:
	# _land() already has, if you were standing inside it.
	var ring := ShockRing.spawn(get_parent(), global_position + Vector3(0, 0.05, 0), reach, ring_colour, 0, 0.55, ring_style)
	ring.name = "GooRing"


func _hurt_message(_stomped: bool) -> void:
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Juice.burst(get_parent(), global_position + Vector3(0, 1.2 * size, 0), Color(1.0, 0.85, 0.35), 10, 0.1, 3.0, 0.6)
	var left := stomps_to_defeat - hits
	if left == 1:                               # (his goo bar shows the rest: no pop-up for every hit)
		Game.message("One more and the King pops!")
	# Call in the court at two-thirds and at one-third of his goo
	var due := 0
	if hits * 3 >= stomps_to_defeat * 2:
		due = 2
	elif hits * 3 >= stomps_to_defeat:
		due = 1
	while _calls_made < due:
		_calls_made += 1
		_call_court(court_call)


func _call_court(count: int) -> void:
	# (also called by his kingdom when the fight starts: scripts/gloop_kingdom.gd)
	_court.assign(_court.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	for i in count:
		if _court.size() >= MAX_COURT:
			return
		var g := COURTIER.instantiate() as CharacterBody3D
		g.name = "Courtier Gloop %d" % randi_range(100, 999)
		g.set("respawns", false)
		g.set("xp_reward", 2)
		for k in court_stats:
			g.set(k, court_stats[k])
		get_parent().add_child(g)
		var a := randf() * TAU
		g.global_position = global_position + Vector3(cos(a), 0.4, sin(a)) * (1.6 * size)
		_court.append(g)
	Game.message("The Gloop King calls his court!")
	Audio.play_at("gloop_giggle", global_position, 4.0, -0.2)


func _defeated() -> void:
	Game.message("You popped the Gloop King! (He'll be back. Kings always are.)")
	Dialogue.set_flag("popped_gloop_king")           # remembered for good (the First Night: scripts/first_night.gd)
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	_calls_made = 0
	_cross = false
	chase_speed = _base[0]
	flop_every = _base[1]
	_flopping = false
	_flop_timer = 3.0


func _make_bar() -> void:
	# A little goo meter over his crown so you can see how close he is to popping
	_bar = Node3D.new()
	_bar.name = "GooMeter"
	add_child(_bar)
	_bar.position = Vector3(0, 1.25 * size + 0.5, 0)
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 0.16)
	back.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.no_depth_test = true
	bm.albedo_color = Color(0.08, 0.05, 0.12)
	bm.render_priority = 1
	back.material_override = bm
	_bar.add_child(back)
	var holder := Node3D.new()
	_bar.add_child(holder)
	holder.scale = Vector3(1.5, 0.1, 1.0)
	_bar_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, 1.0)
	_bar_fill.mesh = fq
	var fm := bm.duplicate() as StandardMaterial3D
	fm.albedo_color = ring_colour.lightened(0.1)
	fm.render_priority = 2
	_bar_fill.position.z = 0.01
	_bar_fill.material_override = fm
	holder.add_child(_bar_fill)
	var label := Label3D.new()
	label.text = title
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 10
	label.modulate = Color(1.0, 0.85, 0.35)
	label.outline_modulate = Color(0.2, 0.1, 0.02)
	label.no_depth_test = true
	label.position.y = 0.28
	_bar.add_child(label)
	_bar.visible = false
