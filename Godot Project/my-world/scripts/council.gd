extends Node

# The Seer and the Wizard Lizard (Hayden, Nov 12 2026, from the lore bible's part 3: "the seer still isnt in the game
# and needs to be added", "lets make the wizard lizard the school principal", then "only wizard lizard is principal,
# seer is just that. part of the council"). A "Council" node under the Watches autoload, so dialogue can reach it
# ("Watches/Council.fortune") without a new autoload.
#
# - **The Seer** lives in the Observatory on its hill in the Void (scenes/interiors/observatory.tscn, built by
#   tools/build_interiors.gd; how she looks: scripts/seer.gd; what she says: dialogue/seer.json). She sits on the
#   Council, the few who watch the stars and try to see what's coming; their round table is in her Observatory.
#   Ask her for a fortune and her lantern shows what the player's up to next, in a seer's roundabout way (fortune()):
#   only ever the step they're already on, never anything that hasn't happened yet (the no-spoilers rule).
# - **The Wizard Lizard** is the principal of the castle school. His office is on the school's 3rd floor (Office 3
#   of the middle row, put in here at play time: no school rebuild), with his warm napping rock under a heat lamp. On
#   the days of Turtle Independence he's out in the Secret Gardens with the turtles instead (scripts/episodes.gd).

const EPISODES := preload("res://scripts/episodes.gd")    # his look, the same as in the Secret Gardens
const SCHOOL := "res://scenes/school/school.tscn"
const FLOOR_3 := "Floor 3"
# His office: the third of the middle row of offices, x -7..3, z 0..9 on the 3rd floor, its door on the west side
const OFFICE_MIN := Vector2(-7.0, 0.0)
const OFFICE_MAX := Vector2(3.0, 9.0)
const LIZARD_AT := Vector2(0.3, 4.5)                     # behind his desk, looking at the door
const LIZARD_LOOK := Vector2(-7.0, 4.5)
const ROCK_AT := Vector2(1.6, 7.6)
const SEER_BOTTLES := ["seer_chosen", "seer_oak", "seer_bike", "seer_bodies", "seer_giant", "seer_goodbye",
	"seer_portals", "seer_watch"]

var _scene: Node


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s == _scene:
		return
	_scene = s
	if s and s.scene_file_path == SCHOOL:
		_place_school.call_deferred(s)


# -----------------------------------------------------------------------------
# The Wizard Lizard: principal
# -----------------------------------------------------------------------------
static func lizard_away() -> bool:
	# Out in the Secret Gardens with the turtles while Turtle Independence is on (episodes.gd puts him there)
	return Quests.is_started("turtle_independence") and not Quests.is_done("turtle_independence")


func principal() -> Node3D:
	var s := get_tree().current_scene
	if s == null or s.scene_file_path != SCHOOL:
		return null
	return s.get_node_or_null("%s/Principal's Office/The Wizard Lizard" % FLOOR_3) as Node3D


func _place_school(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null(FLOOR_3) == null:
		return
	var floor_3 := s.get_node(FLOOR_3) as Node3D
	if floor_3.get_node_or_null("Principal's Office") != null:
		return
	var office := Node3D.new()
	office.name = "Principal's Office"
	floor_3.add_child(office)
	# The room's own name over it (found by where it floats: the school has three rows of offices, so three
	# "Office 3"s), and a sign by its door
	var c := (OFFICE_MIN + OFFICE_MAX) / 2
	for l in floor_3.find_children("*", "Label3D", true, false):
		var at := floor_3.to_local((l as Label3D).global_position)
		if (l as Label3D).text.begins_with("Office") and Vector2(at.x, at.z).distance_to(c) < 0.5:
			(l as Label3D).text = "Principal's Office"
	_sign(office, "PRINCIPAL\nThe Wizard Lizard", Vector3(OFFICE_MIN.x - 0.25, 3.3, 4.5), -PI / 2)
	_furnish(office)
	if not lizard_away():
		office.add_child(_lizard())
	# A sign in the foyer, so nobody has to wander every floor looking for him
	var floor_1 := s.get_node_or_null("Floor 1") as Node3D
	if floor_1:
		_sign(floor_1, "Principal's Office: 3rd floor", Vector3(0, 2.2, 15.75), 0.0, 40).name = "Principal Sign"


func _lizard() -> Node3D:
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = "The Wizard Lizard"
	p.set("look", EPISODES.LIZARD_LOOK.duplicate(true))
	p.set("outfit", EPISODES.LIZARD_OUTFIT.duplicate(true))
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", "wizard_lizard")
	talk.set("display_name", "The Wizard Lizard")
	talk.set("name_height", 2.1)
	p.add_child(talk)
	p.position = Vector3(LIZARD_AT.x, 0, LIZARD_AT.y)
	p.rotation.y = atan2(LIZARD_LOOK.x - LIZARD_AT.x, LIZARD_LOOK.y - LIZARD_AT.y)
	return p


func _furnish(office: Node3D) -> void:
	# His things, round the plain desk the school was built with (centre of the room): a high-backed chair, a gold
	# nameplate, a stack of books, his warm napping rock under a heat lamp in the corner, a bookshelf, a rug, a fern,
	# and framed pictures of past classes on the north wall
	var c := (OFFICE_MIN + OFFICE_MAX) / 2
	var wood := _mat(Color(0.45, 0.28, 0.16))
	var gold := _mat(Color(0.95, 0.75, 0.3), 0.3, 0.7)
	_box(office, Vector3(5.6, 0.03, 4.4), Vector3(c.x, 0.015, c.y), _mat(Color(0.45, 0.25, 0.5)))           # rug
	_box(office, Vector3(0.9, 0.5, 0.9), Vector3(LIZARD_AT.x + 0.7, 0.25, LIZARD_AT.y), _mat(Color(0.35, 0.2, 0.45)))
	_box(office, Vector3(0.18, 1.7, 0.9), Vector3(LIZARD_AT.x + 1.15, 0.85, LIZARD_AT.y), wood)             # chair back
	_box(office, Vector3(0.06, 0.14, 0.6), Vector3(c.x - 0.95, 0.87, c.y), gold)                           # nameplate
	var plate := Label3D.new()
	plate.text = "PRINCIPAL"
	plate.font_size = 22
	plate.pixel_size = 0.004
	plate.modulate = Color(0.2, 0.12, 0.05)
	plate.outline_size = 0
	plate.position = Vector3(c.x - 0.985, 0.87, c.y)
	plate.rotation.y = -PI / 2
	office.add_child(plate)
	for k in 4:
		_box(office, Vector3(0.32, 0.07, 0.24), Vector3(c.x + 0.6, 0.84 + k * 0.07, c.y + 0.3),
			_mat([Color(0.7, 0.25, 0.3), Color(0.25, 0.4, 0.75), Color(0.3, 0.6, 0.4), Color(0.85, 0.7, 0.3)][k]), k * 0.3)
	# The warm rock: a big flat stone with a glowing heat lamp hanging over it
	var rock := _ball(office, 0.75, Vector3(ROCK_AT.x, 0.2, ROCK_AT.y), _mat(Color(0.55, 0.5, 0.48), 0.95))
	rock.scale = Vector3(1.3, 0.45, 1.0)
	_box(office, Vector3(0.06, 2.2, 0.06), Vector3(ROCK_AT.x + 0.9, 1.1, ROCK_AT.y + 0.6), wood)
	_box(office, Vector3(0.9, 0.06, 0.06), Vector3(ROCK_AT.x + 0.45, 2.2, ROCK_AT.y + 0.6), wood)
	_ball(office, 0.16, Vector3(ROCK_AT.x, 2.05, ROCK_AT.y + 0.6), _mat(Color(1.0, 0.55, 0.25), 0.3, 0.0, 2.5))
	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.6, 0.3)
	heat.light_energy = 1.2
	heat.omni_range = 3.5
	heat.position = Vector3(ROCK_AT.x, 1.9, ROCK_AT.y + 0.6)
	office.add_child(heat)
	_sign(office, "Nap Rock", Vector3(ROCK_AT.x, 1.0, ROCK_AT.y - 0.9), PI, 26)
	# A bookshelf along the east wall
	_box(office, Vector3(0.45, 2.4, 3.0), Vector3(OFFICE_MAX.x - 0.4, 1.2, OFFICE_MIN.y + 2.0), wood)
	for row in 3:
		for k in 9:
			_box(office, Vector3(0.35, 0.5, 0.2), Vector3(OFFICE_MAX.x - 0.65, 0.5 + row * 0.75, OFFICE_MIN.y + 0.75 + k * 0.3),
				_mat([Color(0.5, 0.3, 0.6), Color(0.3, 0.5, 0.7), Color(0.8, 0.6, 0.3)][(k + row) % 3]))
	# A fern in a pot by the door, and pictures of past classes on the north wall
	_box(office, Vector3(0.5, 0.5, 0.5), Vector3(OFFICE_MIN.x + 0.7, 0.25, OFFICE_MIN.y + 0.8), _mat(Color(0.8, 0.45, 0.35)))
	_ball(office, 0.5, Vector3(OFFICE_MIN.x + 0.7, 0.9, OFFICE_MIN.y + 0.8), _mat(Color(0.3, 0.6, 0.3)))
	for k in 3:
		var x := c.x - 2.0 + k * 2.0
		_box(office, Vector3(1.1, 0.8, 0.05), Vector3(x, 2.2, OFFICE_MIN.y + 0.2), gold)
		_box(office, Vector3(0.95, 0.65, 0.06), Vector3(x, 2.2, OFFICE_MIN.y + 0.21),
			_mat([Color(0.5, 0.7, 0.9), Color(0.7, 0.85, 0.6), Color(0.95, 0.75, 0.8)][k]))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.light_energy = 0.8
	lamp.omni_range = 7.0
	lamp.position = Vector3(c.x, 4.2, c.y)
	office.add_child(lamp)


# -----------------------------------------------------------------------------
# The Seer's fortunes
# -----------------------------------------------------------------------------
func fortune() -> Array:
	# What her lantern shows: the step the player's on now (the first thing they follow), said the way a seer would.
	# Never anything that hasn't happened yet: the to-do list already says this much.
	var out: Array = []
	if bottles_found() > 0 and not Dialogue.flags.has("seer_bottles_talked"):
		# The first time after the player's found one of her bottles in deep water (scripts/sunken_secrets.gd)
		Dialogue.set_flag("seer_bottles_talked")
		out = ["Oh! You've found one of my bottles, haven't you? I can always tell. You've got that damp look.",
			"I write little notes and drop them into deep water, for whoever needs them. The water knows where to take them.",
			"Don't ask me what they mean, dear. I only write down what the lantern shows me. I never argue with it."]
	return out + _reading()


func _reading() -> Array:
	var o := Quests.objectives()
	var opening: String = ["(The Seer lifts her lantern. The mist inside swirls, then settles.)",
		"(The Seer breathes on her lantern's glass. The mist curls round and round.)",
		"(The Seer holds her lantern up to the stars in the dome. Hoot opens one eye.)"][randi() % 3]
	if o.is_empty():
		return [opening, "Hmm. Nothing but a cup of tea and a long, quiet evening. How lovely.",
			"When there's nothing to do, my dear, that's a thing to do too. Have a sit down."]
	var next := ""
	for item in o.items:
		if not item[1]:
			next = str(item[0])
			break
	if next == "":
		return [opening, "The mist says you've done all you set out to do for \"%s\". Go and tell whoever's waiting." % o.name]
	return [opening, "I see... \"%s\". That's the thread you're following." % o.name,
		"And the mist shows me this: %s" % _soften(next),
		["The stars never tell me more than that. Cheeky things.",
			"That's all it'll show me. The rest is yours to find.",
			"Go gently. It'll keep till you get there."][randi() % 3]]


static func _soften(goal: String) -> String:
	# A to-do line, as she'd say it, with a full stop at the end
	var s := goal.strip_edges()
	if s == "":
		return "something small, close by."
	if not s.ends_with(".") and not s.ends_with("!") and not s.ends_with("?"):
		s += "."
	return s


func bottles_found() -> int:
	var n := 0
	for id in SEER_BOTTLES:
		if Dialogue.flags.has("sunk_" + id):
			n += 1
	return n


# -----------------------------------------------------------------------------
# Building bits
# -----------------------------------------------------------------------------
func _mat(c: Color, rough := 0.8, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _sign(parent: Node3D, text: String, pos: Vector3, yaw: float, size := 44) -> Label3D:
	var l := Label3D.new()
	l.name = "Sign " + text.get_slice("\n", 0)
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 10
	l.modulate = Color(1.0, 0.92, 0.6)
	l.outline_modulate = Color(0.15, 0.1, 0.2)
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l
