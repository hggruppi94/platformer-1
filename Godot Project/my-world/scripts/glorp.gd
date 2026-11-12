extends "res://scripts/gloop.gd"

# A Glorp: a Gloop's wobblier cousin, purple goo swirled with pink and teal (Hayden, 12 Nov 2026: "I want to make more
# enemies"; Glorps were named in the story notes but never built). Pop one and it doesn't just pop: it splits into two
# smaller Glorps that bounce apart, and those split again, until the littlest ones pop for good. A whole family from one
# blob! Only the first, biggest one comes back later (`respawns`); the bits it split into are gone once popped.
#
# Uses the Gloop's scene (scenes/enemies/gloop.tscn) with this script, made in code:
#   var g := Glorp.make()            (or GLORP.call("make", size))
# Kid-safe like every Gloop: a bump, never more, and every split is a squishy boing.
#
# Its boss, Mama Glorp (scripts/glorp_mother.gd), only lives in the Star Arena (scripts/arena_level.gd).

const SCENE := "res://scenes/enemies/gloop.tscn"
const SPLIT_INTO := 0.66                      # each half is this much of its parent's size
const SMALLEST := 0.6                         # a Glorp this size or smaller pops for good
const DEEP := Color(0.22, 0.08, 0.38)
const MAIN := Color(0.62, 0.3, 0.9)
const SWIRL := Color(0.4, 0.95, 0.85)         # teal through the purple, where a Gloop has gold
const POP := Color(0.85, 0.5, 1.0)

var split_from := ""                          # the name of the Glorp it split out of ("" for a whole one)


static func make(sz := 1.2) -> CharacterBody3D:
	var g := (load(SCENE) as PackedScene).instantiate() as CharacterBody3D
	g.set_script(load("res://scripts/glorp.gd"))
	g.name = "Glorp"
	g.set("size", sz)
	return g


func _ready() -> void:
	color = POP
	goldness = 0.5
	chase_speed = 3.6
	wander_speed = 1.6
	xp_reward = 3 if size > SMALLEST else 2
	super()
	add_to_group("glorps")
	for m in _goo:
		m.set_shader_parameter("deep", DEEP)
		m.set_shader_parameter("green", MAIN)
		m.set_shader_parameter("gold", SWIRL)
	var puddle := get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.55, 0.3, 0.8, 0.5)
		puddle.material_override = pm


func can_split() -> bool:
	return size * SPLIT_INTO >= SMALLEST - 0.001


func _defeated() -> void:
	# Pop: if it's still big enough it splits into two littler Glorps that boing out either side
	if not can_split() or not is_inside_tree():
		return
	var parent := get_parent()
	var at := global_position
	var face := visual.rotation.y
	for side in [-1.0, 1.0]:
		var g := make(size * SPLIT_INTO)
		g.name = "Glorp Bit"
		g.set("respawns", false)
		(g as Node).set("split_from", str(name))
		var out: Vector3 = Vector3(cos(face), 0, -sin(face)) * float(side)
		var where: Vector3 = at + out * (0.7 * size) + Vector3(0, 0.3, 0)
		g.position = (parent as Node3D).to_local(where) if parent is Node3D else where   # (its home is where it starts)
		parent.add_child(g, true)                     # readable names: "Glorp Bit", "Glorp Bit2"
		g.velocity = out * 4.0 + Vector3.UP * 4.5
	Fx.burst(parent, at + Vector3(0, 0.6 * size, 0), POP, 10, 0.07, 2.5, 0.5, 0.5)
	Audio.play_at("gloop_giggle", at, 0.0, 0.25)


func _hurt_message(stomped: bool) -> void:
	Game.message("Big Glorp! Stomp it again!" if stomped else "Big Glorp! Pop it again!")
