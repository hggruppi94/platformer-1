extends "res://scripts/crocodillo.gd"

# The Boulderdillo, the Crocodillos' boss (Hayden, Nov 1, 2026: every enemy gets a bigger boss version with ramped-up
# aggression and mechanics). A huge old Crocodillo with boulders grown into its shell, in Boulder Hollow in the far
# northwest (scripts/bosses.gd).
#
# What it does, on top of everything a Crocodillo does:
#   - Pinball rolls: it curls up and rolls at you, and when a roll runs out (or hits a boulder) it SLAMS the ground,
#     sending a ring out to jump, turns towards you and rolls again, three times in a row (four when it's cross).
#     Only after the last one does it uncurl, dizzy.
#   - Thick hide: bubbles boing off it and stomps just bounce you, unless it's dizzy. So: dodge the rolls, jump the
#     rings, then pop or stomp it while the stars are out.
#   - Pebbledillos: at a third and two-thirds it calls in two little Crocodillos (they don't come back once popped).
#   - Gets cross: under half, it rolls faster and one more time.
# Kid-safe: bumps only, popped in a bubble like the rest, and back later.

const NAME := "Boulderdillo"
const PEBBLE := preload("res://scenes/enemies/crocodillo.tscn")
const MAX_PEBBLES := 4

@export var rolls_in_a_row := 3
@export var slam_reach := 7.0

var _rolls_left := 0
var _calls_made := 0
var _pebbles: Array[Node] = []
var _bar: BossBar
var _cross := false
var _base := []


func _ready() -> void:
	super()
	add_to_group("bosses")
	_bar = BossBar.make(self, NAME, Color(0.75, 0.6, 0.45), 2.3 * size + 0.4, 2.0)
	_base = [roll_speed, rolls_in_a_row]
	_boulders()


func _physics_process(delta: float) -> void:
	var was := state
	super(delta)
	if defeated:
		return
	_bar.fill = 1.0 - float(hits) / stomps_to_defeat
	if state == State.CURL and was != State.CURL:
		_rolls_left = rolls_in_a_row - 1                 # a new pinball run starts


func _roll_ended() -> void:
	_slam(slam_reach * (0.7 if _rolls_left > 0 else 1.0))
	if _rolls_left > 0 and player:
		_rolls_left -= 1
		var to_p := player.global_position - global_position
		to_p.y = 0
		if to_p.length() > 0.5:
			_roll_dir = to_p.normalized()
		_state_t = roll_time
		velocity = Vector3.ZERO
		Audio.play_at("roll", global_position, 2.0, -0.1)
		return
	super()


func _slam(reach: float) -> void:
	Audio.play_at("stomp", global_position, 4.0, -0.4)
	Juice.blip("thud", 0.6, -2.0)
	if player and global_position.distance_to(player.global_position) < 30.0:
		Juice.shake(0.35)
		Juice.rumble(0.4, 0.2, 0.5)
	ShockRing.spawn(get_parent(), global_position, reach, Color(0.85, 0.7, 0.45), damage, 0.8)


func shot(power: int, point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	if state != State.DIZZY:
		if not _told_shell:
			_told_shell = true
			Game.message("Boing! Its hide is too thick. Dodge its rolls, then pop it while it's dizzy!")
		return "bounce"
	return super(power, point, dir)


func _stomped() -> void:
	if state != State.DIZZY:
		player.bounce(SHELL_BOUNCE)
		Audio.play_at("boing", global_position)
		return
	super()


func _hurt_message(_stomped: bool) -> void:
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Juice.burst(get_parent(), global_position + Vector3(0, 1.2 * size, 0), Color(0.9, 0.75, 0.5), 10, 0.12, 3.0, 0.6)
	var left := stomps_to_defeat - hits
	_state_t = maxf(_state_t, 1.2)                       # a hit doesn't cut its dizzy spell short
	if not _cross and hits * 2 >= stomps_to_defeat:
		_cross = true
		roll_speed *= 1.25
		rolls_in_a_row += 1
		Game.message("The Boulderdillo is cross now! It rolls faster!")
	elif left > 0:
		Game.message("The Boulderdillo wobbles! %d more to pop it." % left if left > 1 else "One more and it pops!")
	var due := 0
	if hits * 3 >= stomps_to_defeat * 2:
		due = 2
	elif hits * 3 >= stomps_to_defeat:
		due = 1
	while _calls_made < due:
		_calls_made += 1
		_call_pebbles(2)


func _call_pebbles(count: int) -> void:
	_pebbles.assign(_pebbles.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	for i in count:
		if _pebbles.size() >= MAX_PEBBLES:
			return
		var c := PEBBLE.instantiate() as CharacterBody3D
		c.name = "Pebbledillo %d" % randi_range(100, 999)
		c.set("size", 0.6)
		c.set("respawns", false)
		c.set("stomps_to_defeat", 1)
		c.set("damage", 2)
		c.set("xp_reward", 5)
		c.set("roll_speed", 8.0)
		var a := randf() * TAU
		c.position = global_position + Vector3(cos(a), 0.4, sin(a)) * (1.4 * size)
		get_parent().add_child(c)
		_pebbles.append(c)
	Game.message("The Boulderdillo calls the Pebbledillos!")
	Audio.play_at("fwump", global_position, 4.0, -0.2)


func pebbles() -> Array[Node]:
	_pebbles.assign(_pebbles.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	return _pebbles


func _defeated() -> void:
	Game.message("You popped the Boulderdillo! (It'll roll back in later.)")
	Dialogue.set_flag("popped_boulderdillo")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	_calls_made = 0
	_cross = false
	_rolls_left = 0
	roll_speed = _base[0]
	rolls_in_a_row = _base[1]


func _boulders() -> void:
	# Boulders grown into its shell, on the walking body and on the rolled-up ball, so it looks like a rock slide
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.5, 0.44, 0.55)
	rock.roughness = 0.9
	var moss := StandardMaterial3D.new()
	moss.albedo_color = Color(0.3, 0.6, 0.35)
	moss.roughness = 0.95
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var shell := body.get_child(2) as Node3D                  # the banded shell (tools/build_crocodillo.gd)
	for n in 9:
		var m := MeshInstance3D.new()
		m.name = "Boulder%d" % n
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.1, 0.17)
		sm.height = sm.radius * 1.6
		sm.radial_segments = 7
		sm.rings = 4
		m.mesh = sm
		m.material_override = rock if n % 3 else moss
		var d := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.6, 0.8), -1.0).normalized()
		m.position = d * 0.6                                   # on the back of the shell (it bulges out behind)
		m.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
		shell.add_child(m)
	var head := body.get_node("Head") as Node3D
	for n in 3:                                          # a crown of rocks on its head
		var m := MeshInstance3D.new()
		m.name = "CrownRock%d" % n
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.07
		cm.height = 0.22 if n == 1 else 0.16
		cm.radial_segments = 5
		m.mesh = cm
		m.material_override = rock
		m.position = Vector3((n - 1) * 0.09, 0.2, -0.05)
		m.rotation.z = -(n - 1) * 0.35
		head.add_child(m)
	for n in 12:
		var m := MeshInstance3D.new()
		m.name = "BallBoulder%d" % n
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.12, 0.2)
		sm.height = sm.radius * 1.5
		sm.radial_segments = 7
		sm.rings = 4
		m.mesh = sm
		m.material_override = rock if n % 4 else moss
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 1)).normalized()
		m.position = d * 0.7
		ball.add_child(m)
