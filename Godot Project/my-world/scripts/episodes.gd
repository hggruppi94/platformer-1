extends Node

# The quests from the show's first episodes (plan item 5; story/how-it-fits.md, "The first episodes"). The node is
# "Episodes" under the Watches autoload (scripts/watches.gd makes it, like the Lab), so dialogue reaches it as
# "Watches/Episodes.<method>" and no new autoload was needed (a new one would hit the project.godot pull clash on
# Hayden's PC).
#
# One quest per episode, one after another, like a season:
#   0.001 "We need a slide, Mr. Palmer" -> quests/slide_mystery.json. Melanie asks for a water slide, Mr. Palmer says
#         no (he's teaching patience), the old slide's mystery leads to the Haunted House, a fancy stranger says "think
#         outside the box", the door's tried and something giggly escapes (the pilot's cliffhanger: a seed for later).
#         Melanie's new plan, the floating cloud slide with a toy store on top, wins a yes: it unlocks the Cloud Water
#         Slide the town builder already made (Game.give_item("cloud_slide"), scripts/unlockable.gd).
#   2     "Emergency Prep" -> quests/emergency_prep.json. Leo packs a kit and stocks his bunker, then a wail sends him
#         into a panic. It's only Rook howling at the mothership: the false alarm, and ways to calm a worried brain.
#   3     "Doggie Bill of Rights" -> quests/dog_rights.json. Rex, who's lived in a dog's body for a while now, writes
#         dogs' rights, the town signs, and Mr. Palmer agrees to one. A DOGS WELCOME sign and a doggy fountain appear.
#   4     "Turtle Independence" -> quests/turtle_independence.json. The visit after that, the hero arrives with a turtle
#         shell on their back. The Wizard Lizard explains (a different version of you, with purpose and value), and
#         the little lake turtles choose their own shells, which is their independence.
#   5     "Aftershock" -> quests/aftershock.json. Back on Earth one evening a smaller quake makes Willow Pond glow, and
#         a Nina from another world climbs out: freckled, orange-haired, in a striped beanie. She looks sweeter than
#         Nina and plays mean tricks round Stars Hollow. She's not one of Nina's parts. She goes back through the pond.
#
# Everything is put into the scenes at play time (people, quest spots, props), like the lab and the lost watches, so
# no builder or .tscn changed. Progress is the quests' own Dialogue flags, so the save needs nothing new.

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const CHECK_EVERY := 0.3

# Galaxity spots ([x, z]). The Haunted House is at (-112, -128) facing the town, with the old slide beside it
# (tools/build_town.gd HAUNTED_HOUSE, _old_slide).
const MELANIE_AT := Vector2(-67.0, 28.5)              # by the Town Hall steps, waiting to see Mr. Palmer
const GOLDWHISTLE_AT := Vector2(-101.5, -114.5)        # on the path to the Haunted House
const SLIDE_SIGN_AT := Vector2(-95.7, -122.5)          # the old slide's CLOSED sign
const GOO_AT := Vector2(-105.0, -119.5)                # a glowing puddle near the Haunted House door
const HOUSE_DOOR_AT := Vector2(-107.0, -122.0)         # just in front of its door
const LEO_AT := Vector2(-58.0, 31.0)                   # at the Market's northeast corner, checking his list
const BUNKER_AT := Vector2(11.0, 35.0)                 # Leo's emergency bunker, in the meadow south of the lake (clear of
const LEO_BUNKER_AT := Vector2(15.5, 38.0)             # the Lake Loop and Meadow Wiggle race lines)
const FOUNTAIN_SIGN_AT := Vector2(-73.2, 48.9)         # the DOGS WELCOME sign and doggy fountain, by the Market fountain
const FOUNTAIN := Vector2(-72.0, 42.0)                 # (tools/build_town.gd MARKET; its stalls stand 12 m out)
const LIZARD_AT := Vector2(-75.5, -24.0)               # in the Secret Gardens
const TURTLES_AT := Vector2(-24.0, 21.0)               # three little turtles on the lake's south shore
const KIT := [                                         # Leo's kit: [flag, where, action, what it looks like]
	["prep_water", Vector2(-72.0, 44.5), "pick up the water jug", "jug"],
	["prep_torch", Vector2(-12.0, -33.0), "pick up the torch", "torch"],
	["prep_blanket", Vector2(-75.0, 4.0), "pick up the cozy blanket", "blanket"],
	["prep_snacks", Vector2(21.0, 19.0), "pick up the snack box", "snacks"],
]
const SHELLS := [                                      # the turtles' shells: [flag, where, action, what it is]
	["turtle_cup", Vector2(-72.0, 72.0), "pick up the big teacup", "cup"],
	["turtle_bucket", Vector2(24.0, 22.0), "pick up the bucket", "bucket"],
	["turtle_pot", Vector2(-77.0, -40.0), "pick up the flower pot", "pot"],
]
# Earth spots ([x, z]): Willow Pond's east bank by the dock (EarthLand.POND, routines/earth_places.json "dock")
const POND_SPOT_AT := Vector2(-61.5, 5.0)
const OTHER_NINA_AT := Vector2(-64.0, 8.0)
const TRICKS := [                                      # the other Nina's tricks: [flag, where, action, what it looks like]
	["aftershock_lights", Vector2(2.5, 4.5), "untangle the lights", "tangle"],
	["aftershock_pies", Vector2(-1.8, -46.0), "swap the mud pies for real ones", "mud_pies"],
	["aftershock_sign", Vector2(-21.8, 0.0), "fix the sign", "sign"],
]
const AFTERSHOCK_FROM := 19 * 60.0                     # Earth evening, before the oak's own tremors begin
const AFTERSHOCK_TO := 23 * 60.0 + 30.0

var _scene: Node
var _check := 0.0
var _t := 0.0
var _guests := {}                                      # id -> its node, while it's in the scene
var _pond_glow: Node3D
var _spirit: Node3D
var _spirit_t := 0.0
var _rook_howled := false


func _ready() -> void:
	Dialogue.flag_set.connect(_on_flag)


func _process(delta: float) -> void:
	_t += delta
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_guests.clear()
		_pond_glow = null
		_spirit = null
		if s and (s.scene_file_path == TOWN or s.scene_file_path == EARTH):
			_place_in.call_deferred(s)
		return
	if _spirit and is_instance_valid(_spirit):
		_fly_spirit(delta)
	if _pond_glow and is_instance_valid(_pond_glow):
		_pond_glow.visible = Quests.on_step("aftershock", "pond")
		_pond_glow.rotation.y += delta * 0.6
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK_EVERY
	if s == null or not s is Node3D:
		return
	if s.scene_file_path == TOWN or s.scene_file_path == EARTH:
		_update_guests()
	if s.scene_file_path == EARTH:
		_maybe_aftershock()


# -----------------------------------------------------------------------------
# Who's around, and when
# -----------------------------------------------------------------------------
func guests() -> Dictionary:
	# Everyone the episode quests bring, with where they stand and whether they're around right now
	return {
		"melanie": {"scene": TOWN, "name": "Melanie", "at": MELANIE_AT, "face": Vector2(-72.0, 24.0),
			"here": Quests.is_done("first_night") or Quests.is_started("slide_mystery"),
			"look": {"body": "cat", "colors": {"fur": 16, "eyes": 13, "accent": 18, "top": 18, "bottoms": 15},
				"hairstyle": 0, "extras": true, "height": 0.95},
			"outfit": {"face": "heart_shades"}},
		"goldwhistle": {"scene": TOWN, "name": "Mr. Goldwhistle", "at": GOLDWHISTLE_AT, "face": Vector2(-90.0, -105.0),
			"here": Quests.on_step("slide_mystery", "rich") or Quests.on_step("slide_mystery", "door"),
			"look": {"body": "alien", "colors": {"fur": 11, "top": 6, "bottoms": 6}, "height": 1.18, "head": 0.9},
			"outfit": {"neck": "bow_tie", "face": "star_glasses"}},
		"leo": {"scene": TOWN, "name": "Leo",
			"at": LEO_BUNKER_AT if _leo_at_bunker() else LEO_AT,
			"face": BUNKER_AT if _leo_at_bunker() else Vector2(-72.0, 49.0),
			"here": Quests.is_done("slide_mystery"),
			"look": {"body": "bunny", "colors": {"fur": 8, "eyes": 15, "top": 10, "bottoms": 15, "shoes": 3},
				"hairstyle": 0, "extras": false, "height": 0.92},
			"outfit": {"face": "space_goggles", "back": "jetpack"}},
		"wizard_lizard": {"scene": TOWN, "name": "The Wizard Lizard", "at": LIZARD_AT, "face": Vector2(-72.0, -20.0),
			"here": Quests.is_started("turtle_independence"),
			"look": {"body": "dino", "colors": {"fur": 12, "eyes": 7, "top": 16, "bottoms": 16}, "extras": true,
				"height": 1.05, "head": 1.1},
			"outfit": {"head": "witch_hat", "neck": "crystal_necklace"}},
		"other_nina": {"scene": EARTH, "name": "Nina?", "at": OTHER_NINA_AT, "face": Vector2(-58.0, 12.0),
			"here": _other_nina_here(),
			"look": {"colors": {"fur": 1, "hair": 10, "brows": 10, "top": 6, "bottoms": 6, "shoes": 6},
				"hairstyle": 2, "extras": false, "height": 0.96, "head": 1.02},
			"extras": [{"kind": "turtleneck", "color": Color(0.1, 0.09, 0.11)},
				{"kind": "striped_beanie", "color": Color(0.85, 0.15, 0.2)},
				{"kind": "freckles", "color": Color(0.6, 0.35, 0.22)}]},
	}


func _leo_at_bunker() -> bool:
	return Quests.on_step("emergency_prep", "bunker") or Quests.on_step("emergency_prep", "alarm") \
		or Quests.is_done("emergency_prep")


func _other_nina_here() -> bool:
	for step in ["meet", "tricks", "nina", "face"]:
		if Quests.on_step("aftershock", step):
			return true
	return false


func guest(id: String) -> Node3D:
	var n: Node3D = _guests.get(id)
	return n if n and is_instance_valid(n) else null


func _update_guests() -> void:
	var path := _scene.scene_file_path
	var all := guests()
	for id in all:
		var g: Dictionary = all[id]
		if g.scene != path:
			continue
		var n := guest(id)
		if g.here and n == null:
			n = _make_guest(id, g)
			_scene.add_child(n)
			_guests[id] = n
		elif not g.here and n:
			if id == "other_nina" and Quests.is_done("aftershock"):
				_splash(n.global_position)
			n.queue_free()
			_guests.erase(id)
			continue
		if n and not Dialogue.is_active():
			var want := _ground(Vector3(g.at.x, 0, g.at.y))
			if Vector2(n.global_position.x, n.global_position.z).distance_to(g.at) > 0.5:
				n.global_position = want                    # Leo moves to his bunker
			var f: Vector2 = g.face
			n.rotation.y = atan2(f.x - g.at.x, f.y - g.at.y)


func _make_guest(id: String, g: Dictionary) -> Node3D:
	# Made the same way as the Earth townsfolk (scripts/townsfolk.gd), from the hero bodies, with a talk spot
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = str(g.name).replace("?", "").replace(".", "")
	p.set("look", g.look)
	p.set("outfit", g.get("outfit", {}))
	p.set("extras", g.get("extras", []))
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", id)
	talk.set("display_name", g.name)
	talk.set("name_height", 2.1)
	p.add_child(talk)
	p.position = _ground(Vector3(g.at.x, 0, g.at.y))
	var f: Vector2 = g.face
	p.rotation.y = atan2(f.x - g.at.x, f.y - g.at.y)
	return p


# -----------------------------------------------------------------------------
# Putting things in the scene
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.get_node_or_null("Episodes") != null:
		return
	_scene = s
	var holder := Node3D.new()
	holder.name = "Episodes"
	s.add_child(holder)
	if s.scene_file_path == TOWN:
		_place_town(holder)
		_arrive_in_galaxity()
	else:
		_place_earth(holder)
	_update_guests()


func _place_town(holder: Node3D) -> void:
	# The slide mystery's clues and the Haunted House door
	_spot(holder, "slide_mystery", "look", "slide_clue_sign", SLIDE_SIGN_AT, "read the old notice",
		"The notice is faded: \"CLOSED after The Incident. Nobody is to talk about The Incident. By order of the Mayor.\" What incident?",
		_paper())
	_spot(holder, "slide_mystery", "look", "slide_clue_goo", GOO_AT, "look at the glowing puddle",
		"A puddle of green goo, glowing and... giggling? It's not Gloop goo. The trail leads right up to the Haunted House door.",
		_goo())
	_spot(holder, "slide_mystery", "door", "slide_spirit", HOUSE_DOOR_AT, "try the old door", "", null)
	# Leo's kit, and his bunker
	for k in KIT:
		_spot(holder, "emergency_prep", "kit", str(k[0]), k[1], str(k[2]), "", _thing(str(k[3])))
	_bunker(holder)
	_spot(holder, "emergency_prep", "bunker", "prep_stored", BUNKER_AT + Vector2(0, 3.6), "stock the bunker",
		"You stack the kit on the bunker's shelves: water, torch, blanket, snacks. Leo ticks them off his list, twice.", null)
	# The turtles' shells, and the turtles
	for k in SHELLS:
		_spot(holder, "turtle_independence", "shells", str(k[0]), k[1], str(k[2]), "", _thing(str(k[3])))
	_turtles(holder)
	_spot(holder, "turtle_independence", "give", "turtle_given", TURTLES_AT + Vector2(0, -1.5), "let the turtles choose",
		"", null)
	# The Doggie Bill of Rights, once it's law
	if Quests.is_done("dog_rights"):
		_dogs_welcome(holder)


func _place_earth(holder: Node3D) -> void:
	_spot(holder, "aftershock", "pond", "aftershock_pond", POND_SPOT_AT, "look at the glowing pond",
		"The water swirls lilac, like the portal does... and a girl climbs out onto the bank, not even wet. She waves.", null)
	_pond_glow = _make_pond_glow()
	holder.add_child(_pond_glow)
	_pond_glow.global_position = _ground(Vector3(-72.0, 0, 3.0)) + Vector3(0, 0.15, 0)
	for k in TRICKS:
		_spot(holder, "aftershock", "tricks", str(k[0]), k[1], str(k[2]), _trick_message(str(k[0])), _thing(str(k[3])))


func _spot(holder: Node3D, quest: String, step: String, flag: String, at: Vector2, action: String, message: String,
		before: Node3D) -> Area3D:
	# A quest spot (scripts/quest_spot.gd): it only offers itself on its quest's step, and its "Before" child (the thing
	# to pick up) only shows while it's waiting to be used
	var spot := Area3D.new()
	spot.name = "Episode Spot " + flag
	if before:
		before.name = "Before"
		spot.add_child(before)
	spot.set_script(load("res://scripts/quest_spot.gd"))
	spot.set("quest", quest)
	spot.set("step", step)
	spot.set("flag", flag)
	spot.set("action", action)
	spot.set("done_message", message)
	spot.set("radius", 2.0)
	holder.add_child(spot)
	spot.global_position = _ground(Vector3(at.x, 0, at.y))
	return spot


func _ground(p: Vector3) -> Vector3:
	if _scene == null or not _scene is Node3D:
		return p
	var space := (_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 40, 0), p + Vector3(0, -40, 0))
	var got := space.intersect_ray(q)
	return got.position if not got.is_empty() else p


# -----------------------------------------------------------------------------
# What happens when
# -----------------------------------------------------------------------------
func _on_flag(f: String) -> void:
	# (The kit's and the shells' notes count what's been found, so they're written when the flag's set)
	if KIT.any(func(k: Array) -> bool: return str(k[0]) == f):
		Game.message(_kit_message(f))
	elif SHELLS.any(func(k: Array) -> bool: return str(k[0]) == f):
		Game.message(_shell_message(f))
	match f:
		"slide_spirit":
			_release_spirit()
		"prep_stored":
			_rook_howl.call_deferred()
		"turtle_done_talk":
			_take_shell_off_unless_kept()
	if Quests.is_done("dog_rights") and _scene and _scene.scene_file_path == TOWN:
		var holder := _scene.get_node_or_null("Episodes")
		if holder and holder.get_node_or_null("Dogs Welcome") == null:
			_dogs_welcome(holder)


func _arrive_in_galaxity() -> void:
	# Turtle Independence starts the visit after the Doggie Bill of Rights is done: the hero arrives with a shell
	if Quests.is_done("dog_rights") and not Quests.is_started("turtle_independence"):
		if Dialogue.flags.has("turtle_next_visit"):
			start_turtle_day()
		else:
			Dialogue.set_flag("turtle_next_visit")
	elif Quests.is_started("turtle_independence") and not Quests.is_done("turtle_independence"):
		_wear_shell()


func start_turtle_day() -> void:
	_wear_shell()
	Dialogue.set_flag("turtle_start")
	Juice.blip("sparkle", 0.8, -6.0)
	Game.message("You feel... heavier? There's a turtle shell on your back! Pip's wings feel funny too, and Dash can't stop sniffing things. What's going on?")
	Game.save_game()


func _wear_shell() -> void:
	var was := str(Game.outfit.get("back", ""))
	if was == "turtle_shell":
		return
	if not Dialogue.flags.has("turtle_back_saved"):
		Dialogue.flags["turtle_back_was:" + was] = true           # put back afterwards (an empty one too)
		Dialogue.flags["turtle_back_saved"] = true
	Game.outfit["back"] = "turtle_shell"
	Game.equipment_changed.emit()


func _take_shell_off_unless_kept() -> void:
	# Keeping it: it's theirs now (the quest's reward). Letting it go: whatever was on their back before goes back on.
	if Dialogue.flags.has("turtle_keep_shell"):
		return
	var was := ""
	for f in Dialogue.flags:
		if str(f).begins_with("turtle_back_was:"):
			was = str(f).trim_prefix("turtle_back_was:")
	if was == "":
		Game.outfit.erase("back")
	else:
		Game.outfit["back"] = was
	Game.equipment_changed.emit()


func _maybe_aftershock() -> void:
	# Aftershock comes one Earth evening after Turtle Independence: a smaller quake, and Willow Pond starts to glow
	if not Quests.is_done("turtle_independence") or Quests.is_started("aftershock") or not Clock.on_earth:
		return
	var m := Clock.earth_minutes
	if m >= AFTERSHOCK_FROM and m <= AFTERSHOCK_TO:
		aftershock_now()


func aftershock_now() -> void:
	if EarthTown.has_method("tremor") and EarthTown.on_earth_scene():
		EarthTown.tremor()
	Juice.shake(0.25)
	Juice.rumble(0.4, 0.4, 0.2)
	Dialogue.set_flag("aftershock_start")
	Game.message("Another rumble: an aftershock! Over in the park, Willow Pond is glowing lilac, like the portal does...")
	Game.save_game()


func _release_spirit() -> void:
	# The pilot's cliffhanger: the door creaks, and something small, green and giggly zooms out and away over the trees
	if _scene == null or _scene.scene_file_path != TOWN:
		return
	Audio.play("door", -4.0)
	Audio.play("gloop_giggle", -2.0, 0.0)
	Juice.shake(0.2)
	_spirit = Node3D.new()
	_spirit.name = "Escaped Spirit"
	var wisp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	wisp.mesh = sm
	wisp.material_override = _glow(Color(0.55, 1.0, 0.6), 3.0)
	_spirit.add_child(wisp)
	for s in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.06
		em.height = 0.12
		eye.mesh = em
		eye.material_override = _mat(Color(0.1, 0.05, 0.15))
		eye.position = Vector3(s * 0.12, 0.08, 0.3)
		_spirit.add_child(eye)
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 1.0, 0.6)
	l.light_energy = 2.5
	l.omni_range = 6.0
	_spirit.add_child(l)
	_scene.add_child(_spirit)
	_spirit.global_position = _ground(Vector3(HOUSE_DOOR_AT.x, 0, HOUSE_DOOR_AT.y)) + Vector3(0, 1.4, 0)
	_spirit_t = 0.0
	Game.message("The door creaks open... and something small, green and GIGGLING zooms out past you, up over the trees, and away towards town!")


func _fly_spirit(delta: float) -> void:
	_spirit_t += delta
	var away := Vector3(0.6, 0.35, 0.7).normalized()
	_spirit.global_position += (away * 9.0 + Vector3(sin(_spirit_t * 6.0) * 4.0, 0, cos(_spirit_t * 5.0) * 4.0)) * delta
	if Engine.get_process_frames() % 6 == 0:
		Fx.burst(_scene, _spirit.global_position, Color(0.55, 1.0, 0.6), 3, 0.06, 0.6, 0.0, 0.6)
	if _spirit_t > 6.0:
		_spirit.queue_free()
		_spirit = null


func _rook_howl() -> void:
	# The false alarm: a long wail from across the lake. Leo freezes. (It's Rook, howling at the mothership.)
	if _scene == null or _scene.scene_file_path != TOWN:
		return
	Audio.play("bark", -2.0, 0.0)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: Audio.play("bark", -4.0, 0.0))
	Juice.shake(0.12)
	Game.message("AWOOOOOOOOO! A long wail echoes over the lake. Leo's ears shoot straight up and he doesn't move.")


func _splash(at: Vector3) -> void:
	Audio.play("splash", -3.0)
	if _scene:
		Fx.burst(_scene, at + Vector3(0, 0.5, 0), Color(0.75, 0.6, 1.0), 24, 0.1, 3.0, -2.0, 1.0)


# -----------------------------------------------------------------------------
# Messages
# -----------------------------------------------------------------------------
func _kit_message(flag: String) -> String:
	var got := KIT.filter(func(k: Array) -> bool: return Dialogue.flags.has(str(k[0])) or str(k[0]) == flag).size()
	var what: String = {"prep_water": "A big water jug", "prep_torch": "A wind-up torch", "prep_blanket": "A cozy blanket",
		"prep_snacks": "A box of crunchy snacks"}.get(flag, "That")
	return "%s for Leo's kit! (%d of %d)" % [what, got, KIT.size()] if got < KIT.size() \
		else "%s. That's the whole kit! Take it to Leo's bunker in the meadow." % what


func _shell_message(flag: String) -> String:
	var got := SHELLS.filter(func(k: Array) -> bool: return Dialogue.flags.has(str(k[0])) or str(k[0]) == flag).size()
	var what: String = {"turtle_cup": "A teacup big enough to live in", "turtle_bucket": "A sturdy blue bucket",
		"turtle_pot": "A painted flower pot"}.get(flag, "That")
	return "%s! (%d of %d)" % [what, got, SHELLS.size()] if got < SHELLS.size() \
		else "%s. That's three shells! Take them to the little turtles on the lake shore." % what


func _trick_message(flag: String) -> String:
	return {
		"aftershock_lights": "Someone tied the gazebo's lights into a hundred little knots. You untangle them, and they twinkle again.",
		"aftershock_pies": "The pies in the bakery's window were mud pies with a cherry on top! You put the real ones back.",
		"aftershock_sign": "The Town Hall's sign said TOWN SMELL. You put the letters back: TOWN HALL. Much better.",
	}.get(flag, "")


# -----------------------------------------------------------------------------
# Props (made from shapes, in the alien palette in Galaxity and autumn colours on Earth)
# -----------------------------------------------------------------------------
func _thing(kind: String) -> Node3D:
	var g := Node3D.new()
	match kind:
		"jug":
			_cyl(g, 0.22, 0.5, Vector3(0, 0.25, 0), _mat(Color(0.5, 0.85, 1.0, 0.7), true))
			_cyl(g, 0.08, 0.12, Vector3(0, 0.56, 0), _mat(Color(0.3, 0.8, 0.75)))
		"torch":
			_cyl(g, 0.07, 0.4, Vector3(0, 0.08, 0), _mat(Color(1.0, 0.85, 0.3)), Vector3(0, 0, PI / 2))
			_cyl(g, 0.1, 0.1, Vector3(0.24, 0.08, 0), _glow(Color(1.0, 0.95, 0.7), 2.0), Vector3(0, 0, PI / 2))
		"blanket":
			_box(g, Vector3(0.7, 0.25, 0.5), Vector3(0, 0.12, 0), _mat(Color(0.95, 0.45, 0.7)))
			_box(g, Vector3(0.72, 0.06, 0.52), Vector3(0, 0.2, 0), _mat(Color(0.75, 0.65, 1.0)))
		"snacks":
			_box(g, Vector3(0.6, 0.35, 0.4), Vector3(0, 0.17, 0), _mat(Color(1.0, 0.75, 0.3)))
			_box(g, Vector3(0.62, 0.06, 0.1), Vector3(0, 0.36, 0), _mat(Color(0.85, 0.3, 0.55)))
		"cup":
			_cyl(g, 0.38, 0.42, Vector3(0, 0.21, 0), _mat(Color(0.95, 0.85, 1.0)), Vector3.ZERO, 0.28)
			_ring(g, 0.15, 0.04, Vector3(0.42, 0.24, 0), _mat(Color(0.95, 0.85, 1.0)), Vector3(PI / 2, 0, 0))
		"bucket":
			_cyl(g, 0.3, 0.45, Vector3(0, 0.22, 0), _mat(Color(0.35, 0.55, 1.0)), Vector3.ZERO, 0.24)
			_ring(g, 0.27, 0.02, Vector3(0, 0.45, 0), _mat(Color(0.8, 0.8, 0.85)), Vector3(0, 0, PI / 2))
		"pot":
			_cyl(g, 0.3, 0.38, Vector3(0, 0.19, 0), _mat(Color(0.85, 0.45, 0.35)), Vector3.ZERO, 0.22)
			_ring(g, 0.3, 0.04, Vector3(0, 0.37, 0), _mat(Color(0.95, 0.85, 0.4)))
		"tangle":
			for k in 7:
				_ring(g, 0.18 + 0.04 * (k % 3), 0.015, Vector3(0.1 * sin(k), 0.3 + 0.05 * k, 0.1 * cos(k * 2.0)),
					_glow([Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.3), Color(0.9, 0.35, 0.2)][k % 3], 1.5),
					Vector3(k * 0.9, k * 0.5, k * 1.3))
		"mud_pies":
			for k in 3:
				_cyl(g, 0.22, 0.08, Vector3(-0.5 + k * 0.5, 0.95, 0), _mat(Color(0.35, 0.22, 0.12)))
				_ball(g, 0.05, Vector3(-0.5 + k * 0.5, 1.03, 0), _mat(Color(0.85, 0.1, 0.2)))
		"sign":                                         # hung over the Town Hall's own sign, above its door (facing east)
			var board := Node3D.new()
			board.position = Vector3(-2.0, 3.24, 0.45)
			board.rotation.y = PI / 2.0
			g.add_child(board)
			_box(board, Vector3(2.4, 0.7, 0.06), Vector3.ZERO, _mat(Color(0.95, 0.9, 0.75)))
			var l := Label3D.new()
			l.text = "TOWN SMELL"
			l.font_size = 48
			l.pixel_size = 0.007
			l.modulate = Color(0.45, 0.25, 0.1)
			l.outline_size = 0
			l.position = Vector3(0, 0, 0.04)
			board.add_child(l)
	return g


func _paper() -> Node3D:
	var g := Node3D.new()
	_box(g, Vector3(0.45, 0.6, 0.02), Vector3(0, 1.25, 0.12), _glow(Color(1.0, 0.95, 0.75), 0.15))
	return g


func _goo() -> Node3D:
	var g := Node3D.new()
	_cyl(g, 0.9, 0.04, Vector3(0, 0.03, 0), _glow(Color(0.3, 0.95, 0.35), 0.5))
	for k in 4:
		_ball(g, 0.08 + 0.03 * k, Vector3(cos(k * 1.7) * 0.4, 0.06, sin(k * 1.7) * 0.4), _glow(Color(0.35, 1.0, 0.4), 0.7))
	return g


func _bunker(holder: Node3D) -> void:
	# Leo's emergency bunker: a grassy mound with a round metal hatch, a periscope and a very thorough sign
	var g := Node3D.new()
	g.name = "Leo's Bunker"
	holder.add_child(g)
	g.global_position = _ground(Vector3(BUNKER_AT.x, 0, BUNKER_AT.y))
	var grass := _mat(Color(0.55, 0.85, 0.35))
	var mound := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 3.2
	mm.height = 3.2
	mm.is_hemisphere = true
	mound.mesh = mm
	mound.material_override = grass
	mound.scale = Vector3(1.0, 0.75, 1.0)
	g.add_child(mound)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.8
	cyl.height = 2.2
	cs.shape = cyl
	cs.position.y = 1.0
	body.add_child(cs)
	g.add_child(body)
	var metal := _mat(Color(0.7, 0.75, 0.85), false, 0.8)
	_cyl(g, 0.9, 0.15, Vector3(0, 1.0, 2.85), metal, Vector3(PI / 2 - 0.35, 0, 0))
	_ring(g, 0.75, 0.06, Vector3(0, 1.0, 2.95), _mat(Color(1.0, 0.85, 0.3)), Vector3(PI / 2 - 0.35, 0, 0))
	_cyl(g, 0.08, 1.4, Vector3(1.2, 2.6, 0.5), metal)
	_box(g, Vector3(0.18, 0.18, 0.45), Vector3(1.2, 3.3, 0.65), metal)
	var post := _box(g, Vector3(0.12, 1.6, 0.12), Vector3(-2.6, 0.8, 3.0), _mat(Color(0.5, 0.35, 0.25)))
	post.name = "Post"
	_box(g, Vector3(1.9, 1.0, 0.08), Vector3(-2.6, 1.7, 3.05), _mat(Color(1.0, 0.85, 0.3)))
	var l := Label3D.new()
	l.text = "EMERGENCY BUNKER\n(Leo's)\nKnock 3 times. Then\nknock 3 more times."
	l.font_size = 36
	l.pixel_size = 0.0045
	l.modulate = Color(0.2, 0.12, 0.25)
	l.outline_size = 0
	l.position = Vector3(-2.6, 1.7, 3.1)
	g.add_child(l)


func _turtles(holder: Node3D) -> void:
	# Three little lake turtles. Galaxity's turtles use things as their shells, and today they get to choose their own
	# (the quest's "give" step); until then they're shy, soft and shell-less, and blink up at you
	var colours := [Color(0.45, 0.85, 0.6), Color(0.6, 0.8, 0.95), Color(0.95, 0.75, 0.5)]
	var shells := ["cup", "bucket", "pot"]
	for i in 3:
		var t := Node3D.new()
		t.name = "Lake Turtle %d" % (i + 1)
		holder.add_child(t)
		var at := TURTLES_AT + Vector2(-1.6 + i * 1.6, 0.5 * (i % 2))
		t.global_position = _ground(Vector3(at.x, 0, at.y))
		t.rotation.y = PI + (i - 1) * 0.3
		var skin := _mat(colours[i])
		_ball(t, 0.28, Vector3(0, 0.22, 0), skin).scale = Vector3(1.0, 0.6, 1.25)
		_ball(t, 0.15, Vector3(0, 0.32, 0.38), skin)
		for s in [-1.0, 1.0]:
			_ball(t, 0.04, Vector3(s * 0.07, 0.38, 0.5), _mat(Color(0.1, 0.07, 0.12)))
			for z in [-0.2, 0.2]:
				_ball(t, 0.08, Vector3(s * 0.22, 0.08, z), skin)
		# Its chosen shell, shown once the turtles have chosen (scripts/quest_show.gd-style: a "flag" check below)
		var shell := _thing(shells[i])
		shell.name = "Chosen Shell"
		shell.position = Vector3(0, 0.25, -0.02)
		shell.rotation.x = PI if shells[i] != "cup" else 0.0
		if shells[i] != "cup":
			shell.position.y = 0.75
		shell.scale = Vector3.ONE * 1.1
		shell.visible = Dialogue.flags.has("turtle_given")
		t.add_child(shell)
		var label := Label3D.new()
		label.text = ["Tiny", "Splash", "Pebble"][i]
		label.font_size = 26
		label.pixel_size = 0.008
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position.y = 1.2
		t.add_child(label)
	var show := func(f: String) -> void:
		if f == "turtle_given":
			for c in holder.get_children():
				if str(c.name).begins_with("Lake Turtle"):
					(c.get_node("Chosen Shell") as Node3D).visible = true
					Fx.burst(_scene, (c as Node3D).global_position + Vector3.UP * 0.6, Color(0.6, 1.0, 0.7), 10, 0.06, 1.5, -1.0, 0.7)
			Audio.play("pickup", -4.0)
			Game.message("Tiny picks the teacup, Splash the bucket, Pebble the flower pot. Nobody told them which. They chose! They wobble off down the shore, very proud.")
	Dialogue.flag_set.connect(show)
	holder.tree_exiting.connect(func() -> void:
		if Dialogue.flag_set.is_connected(show):
			Dialogue.flag_set.disconnect(show))


func _dogs_welcome(holder: Node3D) -> void:
	# What the Doggie Bill of Rights won: a DOGS WELCOME sign and a low doggy fountain by the Market fountain
	var g := Node3D.new()
	g.name = "Dogs Welcome"
	holder.add_child(g)
	g.global_position = _ground(Vector3(FOUNTAIN_SIGN_AT.x, 0, FOUNTAIN_SIGN_AT.y))
	g.rotation.y = atan2(FOUNTAIN_SIGN_AT.x - FOUNTAIN.x, FOUNTAIN_SIGN_AT.y - FOUNTAIN.y)      # its face away from the fountain, to the path
	_box(g, Vector3(0.12, 1.8, 0.12), Vector3(-0.8, 0.9, 0), _mat(Color(0.5, 0.35, 0.25)))
	_box(g, Vector3(1.9, 1.0, 0.08), Vector3(-0.8, 1.9, 0.0), _mat(Color(0.3, 0.8, 0.75)))
	var l := Label3D.new()
	l.text = "DOGS WELCOME!\nDoggie Bill of Rights,\nRule 1. Signed: the Town"
	l.font_size = 40
	l.pixel_size = 0.0045
	l.modulate = Color(1.0, 0.97, 0.9)
	l.outline_size = 6
	l.outline_modulate = Color(0.1, 0.2, 0.2)
	l.position = Vector3(-0.8, 1.9, 0.05)
	g.add_child(l)
	_cyl(g, 0.45, 0.25, Vector3(0.9, 0.12, 0), _mat(Color(0.75, 0.7, 0.95)))
	_cyl(g, 0.37, 0.05, Vector3(0.9, 0.25, 0), _mat(Color(0.45, 0.8, 1.0, 0.8), true))
	_cyl(g, 0.06, 0.6, Vector3(0.9, 0.5, -0.3), _mat(Color(0.75, 0.7, 0.95)))
	for s in [-1.0, 1.0]:                                   # a paw print on the bowl
		_ball(g, 0.04, Vector3(0.9 + s * 0.06, 0.2, 0.46), _mat(Color(0.95, 0.5, 0.7)))
	_ball(g, 0.065, Vector3(0.9, 0.12, 0.46), _mat(Color(0.95, 0.5, 0.7)))


func _make_pond_glow() -> Node3D:
	var g := Node3D.new()
	g.name = "Pond Glow"
	_cyl(g, 7.5, 0.05, Vector3.ZERO, _glow(Color(0.7, 0.55, 1.0, 0.45), 1.4, true))
	_ring(g, 4.5, 0.12, Vector3(0, 0.05, 0), _glow(Color(0.85, 0.7, 1.0), 2.0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.6, 1.0)
	l.light_energy = 3.0
	l.omni_range = 14.0
	l.position.y = 1.5
	g.add_child(l)
	g.visible = false
	return g


# -----------------------------------------------------------------------------
# Shapes
# -----------------------------------------------------------------------------
func _mat(c: Color, see_through := false, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	m.metallic = metal
	if see_through or c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _glow(c: Color, energy: float, see_through := false) -> StandardMaterial3D:
	var m := _mat(c, see_through)
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO,
		bottom := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius if bottom < 0.0 else bottom
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ring(parent: Node3D, r: float, thick: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - thick
	tm.outer_radius = r + thick
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi
