extends "res://scripts/gloop_king.gd"

# Mama Glorp: the biggest Glorp there is, and the Glorps' boss (every enemy gets a bigger boss version: Hayden, Nov 1,
# 2026). She only lives in the Star Arena (scripts/arena_level.gd): one of its three bosses you meet nowhere else.
# Purple goo like her little ones (scripts/glorp.gd), a big pink bow instead of a crown, and she belly-flops like the
# Gloop King (a ring of goo: jump it). Her own trick: every time you hit her, a Glorp splits off her and bounces out
# (and those split again when popped). Past half her goo she's cross: quicker, flopping more often, two waves a flop.
# HITS hits pop her. Kid-safe like every Gloop: a bump, never more.
#
# Made in code: MOTHER.make() (the Gloop King's scene with this script).

const GLORP := preload("res://scripts/glorp.gd")
const HITS := 9
const BOW := Color(1.0, 0.45, 0.75)

var world: Node                               # the arena, told when she's popped
var babies := 0                               # Glorps she's split off


static func make() -> CharacterBody3D:
	var g := (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate() as CharacterBody3D
	g.set_script(load("res://scripts/glorp_mother.gd"))
	g.name = "Mama Glorp"
	g.set("size", 2.6)
	g.set("stomps_to_defeat", HITS)
	g.set("respawns", false)
	g.set("xp_reward", 50)
	g.set("sight_range", 40.0)
	g.set("leash_range", 80.0)
	g.set("wander_radius", 4.0)
	g.set("chase_speed", 2.8)
	return g


func _ready() -> void:
	title = "Mama Glorp"
	ring_colour = GLORP.MAIN
	color = GLORP.POP
	goldness = 0.5
	super()
	for m in _goo:
		m.set_shader_parameter("deep", GLORP.DEEP)
		m.set_shader_parameter("green", GLORP.MAIN)
		m.set_shader_parameter("gold", GLORP.SWIRL)
	var puddle := get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.55, 0.3, 0.8, 0.5)
		puddle.material_override = pm
	var crown := get_node_or_null("Visual/Body/Crown") as Node3D
	if crown:
		crown.visible = false
		_bow(crown.get_parent() as Node3D, crown.position)


func _bow(on: Node3D, at: Vector3) -> void:
	# A big pink bow on top, where the King wears his crown
	var bow := Node3D.new()
	bow.name = "Bow"
	bow.position = at + Vector3(0, -0.02, 0)
	on.add_child(bow)
	var m := StandardMaterial3D.new()
	m.albedo_color = BOW
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = BOW
	m.emission_energy_multiplier = 0.15
	for side in [-1.0, 1.0]:
		var loop := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.2
		loop.mesh = sm
		loop.material_override = m
		loop.position = Vector3(side * 0.15, 0.06, 0)
		loop.rotation.z = side * 0.5
		loop.scale = Vector3(1.4, 0.8, 0.6)
		bow.add_child(loop)
	var knot := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.07
	km.height = 0.14
	knot.mesh = km
	knot.material_override = m
	knot.position = Vector3(0, 0.06, 0)
	bow.add_child(knot)


func _hurt_message(_stomped: bool) -> void:
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Juice.burst(get_parent(), global_position + Vector3(0, 1.2 * size, 0), GLORP.POP, 10, 0.1, 3.0, 0.6)
	var left := stomps_to_defeat - hits
	Game.message("Mama Glorp wobbles, and a Glorp splits off! %d more to pop her." % left if left > 1 \
		else "One more and Mama Glorp pops!")
	_split_off()
	# Like the King's court: at two-thirds and one-third she calls two more of her little ones
	var due := 0
	if hits * 3 >= stomps_to_defeat * 2:
		due = 2
	elif hits * 3 >= stomps_to_defeat:
		due = 1
	while _calls_made < due:
		_calls_made += 1
		_call_court(2)


func _split_off() -> void:
	if not is_inside_tree():
		return
	_court.assign(_court.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	if _court.size() >= MAX_COURT + 2:
		return
	var g := GLORP.make(0.99)
	g.name = "Glorp Bit"
	g.set("respawns", false)
	var a := randf() * TAU
	var out := Vector3(cos(a), 0, sin(a))
	var where := global_position + out * (1.4 * size) + Vector3(0, 0.6, 0)
	var parent := get_parent() as Node3D
	g.position = parent.to_local(where) if parent else where
	get_parent().add_child(g)
	g.velocity = out * 4.0 + Vector3.UP * 5.0
	_court.append(g)
	babies += 1


func _call_court(count: int) -> void:
	_court.assign(_court.filter(func(n: Node) -> bool: return is_instance_valid(n)))
	for i in count:
		if _court.size() >= MAX_COURT + 2:
			return
		var g := GLORP.make(1.5)
		g.set("respawns", false)
		var a := randf() * TAU
		var where := global_position + Vector3(cos(a), 0.4, sin(a)) * (1.6 * size)
		var parent := get_parent() as Node3D
		g.position = parent.to_local(where) if parent else where
		get_parent().add_child(g)
		_court.append(g)
	Game.message("Mama Glorp calls her little ones!")
	Audio.play_at("gloop_giggle", global_position, 4.0, -0.3)


func _defeated() -> void:
	Game.message("You popped Mama Glorp! Splat... and a hundred tiny giggles.")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("boss_popped"):
		world.call("boss_popped", self)
