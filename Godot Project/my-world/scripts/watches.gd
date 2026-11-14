extends Node

# Autoload "Watches": the lost watches hunt. Everyone who arrives on the Void, the brain planet outside time, has a
# watch that tracks time the way it worked on their own planet or in their own time (story/how-it-fits.md, the time
# arc), and twenty chosen kids have lost theirs round the Void. Each one is a small glowing model that spins where it
# fell (scripts/watch_pickup.gd), placed so finding them all takes every way of getting about: walking and jumping,
# wading, climbing, the zipline, grinding, skating, beaming down from the mothership onto roofs and flying it high
# into the sky, the school, and the edge of the Scary World.
#
# Picking one up shows a card with a one-line note about whose it was and when they came from. Dash collects them
# ("trying to work out when everyone is from"): talk to him with watches in your pocket and he takes them
# (dialogue/dash.json, "watches_to_give" and "do": "watches_hand_in"), with rewards at 5, 10, 15 and 20. The Bag sheet
# of the player menu has a Watches page (scripts/player_menu.gd), and found ones show on the town map
# (scripts/map_screen.gd).
#
# Like the skate letters, everything is a Dialogue flag, so it's saved with the game and old saves just have none:
# "watch_found_<id>", "watch_given_<id>" and "watch_reward_<count>".
#
# The pickups aren't in the built scenes: this puts them into whichever scene is showing, from WATCHES, so the
# builders and their big .tscn files don't change. tools/test_lost_watches.gd checks every one can be reached.

signal found_watch(id: String)
signal handed_in(count: int)

const SCENES := {"town": "res://scenes/town/town.tscn", "school": "res://scenes/school/school.tscn",
	"scary": "res://scenes/scary_world/scary_world.tscn"}

# Every watch: its look (built in model()), which scene and where (its middle), how you get to it ("how", which
# tools/test_lost_watches.gd checks), where that is in words (for the Bag once it's found), a vague hint (for the
# Bag before), and the note about its owner.
#   how: "walk" (stand under it), "jump" (a jump up from what's under it), "wade" (out in the water), "climb" (on top
#   of something climbed), "zipline" (in reach from the zipline), "grind" (over a grind rail), "skate" (air off a
#   quarter pipe), "beam" (on a roof: beam down from the mothership onto it), "sky" (fly the mothership through it)
const WATCHES := [
	{"id": "water_clock", "name": "Drip Clock", "scene": "town", "pos": Vector3(-72, 3.95, 42), "how": "jump",
		"place": "On the Market Square fountain",
		"hint": "Where the water splashes.",
		"note": "Mo's, from a desert planet. Drip, drip!"},
	{"id": "seashell", "name": "Tide Shell", "scene": "town", "pos": Vector3(0, -0.1, 2), "how": "wade",
		"place": "In the middle of the lake",
		"hint": "Where the boats bob.",
		"note": "Coral's, from an ocean world. It counts tides."},
	{"id": "cuckoo", "name": "Cuckoo Locket", "scene": "town", "pos": Vector3(124.5, 8.5, 3), "how": "climb",
		"place": "On the tree house deck",
		"hint": "Up in the leaves.",
		"note": "Greta's, from 1750. A bird pops out!"},
	{"id": "digital", "name": "Beep Band", "scene": "town", "pos": Vector3(100.45, 5.43, 6.21), "how": "zipline",
		"place": "Halfway down the zipline",
		"hint": "On something fast and whirry!",
		"note": "Zack's, from 1985. It has a calculator!"},
	{"id": "sundial", "name": "Sundial Pendant", "scene": "town", "pos": Vector3(125, 10.8, 54), "how": "climb",
		"place": "On top of the rock wall",
		"hint": "After a long climb.",
		"note": "Tilly's sundial watch. Sunny days only!"},
	{"id": "moon_phase", "name": "Moon-Nap Dial", "scene": "town", "pos": Vector3(-56, 18.8, -55), "how": "climb",
		"place": "Up in the Cloud Nest",
		"hint": "High above the Secret Gardens.",
		"note": "Luna's. It counts in moon-naps. Nap time!"},
	{"id": "robot", "name": "Bolt Watch", "scene": "town", "pos": Vector3(21.2, 17.2, -86.8), "how": "grind",
		"place": "On the castle hill rail",   # moved 12 Nov: its old rail went in the 11 Nov rail tidy
		"hint": "On a grind line to school.",
		"note": "A robot watch. BEEP BOOP!"},
	{"id": "many_hands", "name": "Watch of Many Hands", "scene": "town", "pos": Vector3(40.5, 5.0, 59), "how": "skate",
		"place": "High over the Skate Park ramp",
		"hint": "You'll need BIG air!",
		"note": "Professor Pockets'. 37 hours a day!"},
	{"id": "egg_timer", "name": "Chef's Egg Timer", "scene": "town", "pos": Vector3(-128, 0.9, 8), "how": "walk",
		"place": "By the Gloop King's gate",
		"hint": "Near a gooey gate.",
		"note": "Chef Pepper's. It dings for soup and hugs!"},
	{"id": "backwards", "name": "Backwards Watch", "scene": "town", "pos": Vector3(122, 0.8, -196), "how": "walk",
		"place": "In the far field, behind the castle hill",
		"hint": "Out in the far field.",
		"note": "Its hands go backwards!"},
	{"id": "candle", "name": "Candle Clock", "scene": "town", "pos": Vector3(-120, 0.8, -110), "how": "walk",
		"place": "In the Spooky Woods",
		"hint": "Somewhere dark and twisty.",
		"note": "Wick's candle watch. Never lit!"},
	{"id": "hourglass", "name": "Hourglass Charm", "scene": "town", "pos": Vector3(56.4, -0.5, -86.3), "how": "wade",
		"place": "Under the castle waterfall",
		"hint": "Where the water falls.",
		"note": "Sandy's hourglass. Flip it: tomorrow!"},
	{"id": "pocket", "name": "Railway Pocket Watch", "scene": "town", "pos": Vector3(-72, 8.4, 16), "how": "beam",
		"place": "On top of the Town Hall's dome",
		"hint": "On a very important roof!",
		"note": "Bertie's, from 1895. Always on time!"},
	{"id": "star_chart", "name": "Star-Chart Dial", "scene": "town", "pos": Vector3(105, 24.1, -88), "how": "beam",
		"place": "On top of the Observatory dome",
		"hint": "Close to the stars.",
		"note": "Nova's star watch."},
	{"id": "orrery", "name": "Orrery Charm", "scene": "town", "pos": Vector3(28, 76.3, -147), "how": "beam",
		"place": "On the castle's tallest spire",
		"hint": "The top of the school!",
		"note": "Tiny planets round a tiny sun!"},
	{"id": "galaxy", "name": "Spiral Galaxy Watch", "scene": "town", "pos": Vector3(10, 115, -180), "how": "sky",
		"place": "Way up in the sky over the castle",
		"hint": "Above the clouds. Take a ship!",
		"note": "Stella's. One tick every million years!"},
	{"id": "crystal_ring", "name": "Humming Crystal Ring", "scene": "town", "pos": Vector3(-110, 100, 20), "how": "sky",
		"place": "High in the sky over the west fields",
		"hint": "Up where the mothership flies.",
		"note": "Kit's, from the future. Fixed with a hair clip!"},
	{"id": "beads", "name": "Bead Calendar", "scene": "school", "pos": Vector3(6, 13.0, -23.2), "how": "walk",
		"place": "At the school's top window",
		"hint": "By a mountain view.",
		"note": "3,000 beads, one for each day!"},
	{"id": "flower", "name": "Flower Clock", "scene": "school", "pos": Vector3(-12, 1.5, 33), "how": "walk",
		"place": "In the school greenhouse",
		"hint": "Somewhere warm and green, at school.",
		"note": "Petal's flower watch. Smell the time!"},
	{"id": "glowworm", "name": "Glow-Worm Lantern", "scene": "scary", "pos": Vector3(-21, 0.9, -15), "how": "walk",
		"place": "At the edge of the clearing in Dusk's Embrace",
		"hint": "In a scary place. Look along the edge.",
		"note": "Glow-worm watch. Always nearly bedtime!"},
]

# Handing them to Dash: at each count, what you get (once). Sparkles, a Star Popper colour, a sash sticker, and the
# Time Keeper, a watch of your own to wear round your neck or on your wrist.
const REWARDS := [
	{"at": 5, "sparkles": 15, "text": "15 sparkles"},
	{"at": 10, "popper": "clockwork", "text": "a Clockwork colour for your Star Popper"},
	{"at": 15, "shop": "watch_sticker", "sparkles": 10, "text": "a Tick-Tock Sticker for your sash, and 10 sparkles"},
	{"at": 20, "shop": "time_keeper_watch", "also": "time_keeper_pendant", "text": "the Time Keeper, a watch of your own"},
]

const PICK_RADIUS := 1.5                 # how near her middle has to come
const SKY_RADIUS := 9.0                  # ...or the mothership's, flying it (it's big)

var _scene: Node
var _card: CanvasLayer
var _card_panel: PanelContainer
var _card_icon: SubViewportContainer
var _card_title: Label
var _card_note: Label
var _card_t := 0.0


func _ready() -> void:
	_build_card()
	# Rex and Dash's lab and its quest, where the hero's watch finds time ripples (scripts/lab.gd). It lives here so
	# dialogue can reach it ("Watches/Lab.tune_watch") without a new autoload.
	var lab := (load("res://scripts/lab.gd") as GDScript).new() as Node
	lab.name = "Lab"
	add_child(lab)
	# The quests from the show's first episodes (scripts/episodes.gd): the same trick, "Watches/Episodes.<method>"
	var episodes := (load("res://scripts/episodes.gd") as GDScript).new() as Node
	episodes.name = "Episodes"
	add_child(episodes)
	# Secrets at the bottom of deep water, for swimmers (scripts/sunken_secrets.gd): "Watches/Sunken.hand_in"
	var sunken := (load("res://scripts/sunken_secrets.gd") as GDScript).new() as Node
	sunken.name = "Sunken"
	add_child(sunken)
	# Rare fish for the Aquarium, for swimmers too (scripts/rare_fish.gd, quests/aquarium.json)
	var fish := (load("res://scripts/rare_fish.gd") as GDScript).new() as Node
	fish.name = "Fish"
	add_child(fish)
	# The Seer and the Wizard Lizard, principal (scripts/council.gd): "Watches/Council.fortune"
	var council := (load("res://scripts/council.gd") as GDScript).new() as Node
	council.name = "Council"
	add_child(council)


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		if s:
			_place_in.call_deferred(s)
	if _card_t > 0.0:
		_card_t -= delta
		_card_panel.modulate.a = clampf(_card_t / 0.5, 0.0, 1.0)
		if _card_t <= 0.0:
			_card.visible = false


# -----------------------------------------------------------------------------
# What's been found and given
# -----------------------------------------------------------------------------
func watch(id: String) -> Dictionary:
	for w in WATCHES:
		if w.id == id:
			return w
	return {}


func is_found(id: String) -> bool:
	return Dialogue.flags.has("watch_found_" + id)


func is_given(id: String) -> bool:
	return Dialogue.flags.has("watch_given_" + id)


func found_count() -> int:
	return WATCHES.filter(func(w: Dictionary) -> bool: return is_found(w.id)).size()


func given_count() -> int:
	return WATCHES.filter(func(w: Dictionary) -> bool: return is_given(w.id)).size()


func remaining() -> int:
	# Still lost somewhere (the nightly request board, scripts/requests.gd, stops asking for one at 0)
	return WATCHES.size() - found_count()


func to_give() -> Array:
	# Found but still in her pocket
	return WATCHES.filter(func(w: Dictionary) -> bool: return is_found(w.id) and not is_given(w.id))


func next_reward() -> Dictionary:
	for r in REWARDS:
		if given_count() < int(r.at):
			return r
	return {}


func found_in_town() -> Array:
	# For the map: [{pos, name}] of the ones found in town
	var out := []
	for w in WATCHES:
		if w.scene == "town" and is_found(w.id):
			out.append({"pos": w.pos, "name": w.name})
	return out


func condition_ok(when: Dictionary) -> bool:
	# Dialogue "when" keys (scripts/dialogue.gd): "watches_to_give" (true: she has some for Dash, false: none),
	# "no_watches_yet" (none found at all), "watches_found" (at least this many found) and "watches_given" (at least
	# this many handed in)
	var sunken := get_node_or_null("Sunken")             # "sunk_to_give", "sunk_given": the sunken pieces for Dash
	if sunken and not sunken.condition_ok(when):
		return false
	if when.has("watches_to_give") and bool(when["watches_to_give"]) != (not to_give().is_empty()):
		return false
	if when.has("no_watches_yet") and bool(when["no_watches_yet"]) != (found_count() == 0):
		return false
	if when.has("watches_found") and found_count() < int(when["watches_found"]):
		return false
	if when.has("watches_given") and given_count() < int(when["watches_given"]):
		return false
	return true


func fill() -> Dictionary:
	# Words dialogue can use: {watches_new}, {watches_given}, {watches_left}
	var given := given_count()
	var words := {"watches_new": str(to_give().size()), "watches_given": str(given), "watches_left": str(WATCHES.size() - given)}
	var sunken := get_node_or_null("Sunken")
	if sunken:
		words.merge(sunken.fill())                      # {pieces_given}
	return words


# -----------------------------------------------------------------------------
# Finding one
# -----------------------------------------------------------------------------
func pick_up(id: String, at := Vector3.ZERO) -> void:
	if is_found(id) or watch(id).is_empty():
		return
	Dialogue.set_flag("watch_found_" + id)
	var w := watch(id)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("sparkle", 1.0, -6.0)
	Juice.shake(0.1)
	Juice.rumble(0.3, 0.15)
	var s := get_tree().current_scene
	if s:
		Fx.burst(s, at, Color(1.0, 0.85, 0.35), 18, 0.07, 3.5, -2.0, 0.8)
		Fx.burst(s, at, Color(0.5, 1.0, 0.9), 10, 0.05, 2.5, -1.0, 0.7)
	var n := found_count()
	var tail := ("Dash still collects these, in Lumen City." if Dialogue.flags.has("dash_goodbye") else "Dash collects these.") \
		if given_count() == 0 and n == 1 else "%d of %d found." % [n, WATCHES.size()]
	show_card(w, tail)
	found_watch.emit(id)
	var board := get_node_or_null("/root/Requests")      # "Find a lost watch" on the nightly request board
	if board and board.has_method("note"):
		board.call("note", "watch")
	Game.save_game()


func show_card(w: Dictionary, tail := "") -> void:
	_card_title.text = "A lost watch: %s!" % w.name
	_card_note.text = str(w.note) + ("\n" + tail if tail != "" else "")
	for c in _card_icon.get_children():
		c.queue_free()
	_card_icon.add_child(icon_viewport(str(w.id), true, 120))
	_card_panel.modulate.a = 1.0
	_card.visible = true
	_card_t = 7.0
	_apply_card_look()


# -----------------------------------------------------------------------------
# Handing them to Dash (dialogue/dash.json: "do": "watches_hand_in" runs this as the talk starts; the lines it
# returns are said after the conversation's own). Once everyone's home he takes them in Lumen City instead
# (scripts/far_future.gd hand_ins())
# -----------------------------------------------------------------------------
func watches_hand_in() -> Array:
	var giving := to_give()
	if giving.is_empty():
		return []
	for w in giving:
		Dialogue.set_flag("watch_given_" + str(w.id))
	var lines: Array = []
	var given := given_count()
	for r in REWARDS:
		if given >= int(r.at) and not Dialogue.flags.has("watch_reward_%d" % int(r.at)):
			Dialogue.set_flag("watch_reward_%d" % int(r.at))
			_give(r)
			lines.append(REWARD_LINES.get(int(r.at), "Here, this is for you."))
			lines.append("(You got %s!)" % r.text)
	if given == WATCHES.size():
		lines.append("All twenty! Thanks, {player}!")
	else:
		var nxt := next_reward()
		if not nxt.is_empty():
			lines.append("Bring %d more for a prize!" % (int(nxt.at) - given))
	Audio.play("level_up", -4.0, 0.0)
	handed_in.emit(given)
	return lines


const REWARD_LINES := {
	5: "Five! Here, some sparkles!",
	10: "Ten! Your Star Popper ticks now!",
	15: "Fifteen! A Tick-Tock Sticker!",
	20: "ALL of them! Here: the Time Keeper!",
}


func _give(r: Dictionary) -> void:
	if r.has("sparkles"):
		Game.add_sparkles(int(r.sparkles), "Dash's thank-you:")
	if r.has("popper"):
		Game.give_item("popper_colour:" + str(r.popper))
		Game.popper_colour = str(r.popper)
		Game.equipment_changed.emit()
	for key in ["shop", "also"]:
		if r.has(key):
			var id := str(r[key])
			if not Game.has_item("shop:" + id):
				Game.items.append("shop:" + id)
	if r.has("shop"):
		Game.equipment_changed.emit()


# -----------------------------------------------------------------------------
# Putting the pickups into the scene
# -----------------------------------------------------------------------------
func out_tonight(id: String) -> bool:
	# A new game brings them out a few at a time (FirstNight.held_back): on the first night only the fountain's (the
	# First Night asks for it), then the first OUT_BY_NIGHT[n] in the list, and every one from night 4
	for n in OUT_BY_NIGHT:
		if FirstNight.held_back(n + 1):
			var i := WATCHES.find_custom(func(w: Dictionary) -> bool: return str(w.id) == id)
			return i >= 0 and i < int(OUT_BY_NIGHT[n])
	return true


func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D:
		return
	var here := ""
	for k in SCENES:
		if SCENES[k] == s.scene_file_path:
			here = k
	if here == "":
		return
	var holder := Node3D.new()
	holder.name = "Lost Watches"
	s.add_child(holder)
	for w in WATCHES:
		if w.scene == here and not is_found(w.id) and out_tonight(str(w.id)):
			var p := WatchPickup.new()
			p.id = w.id
			p.name = "Watch " + str(w.id)
			p.sky = w.how == "sky"
			holder.add_child(p)
			p.global_position = w.pos


# -----------------------------------------------------------------------------
# How each one looks, built from shapes in the alien palette. About 0.3 m across, dial facing +Z.
# -----------------------------------------------------------------------------
const OUT_BY_NIGHT := {1: 1, 2: 8, 3: 14}     # night -> how many are out (the list's first ones), on a new game
const GOLD := Color(1.0, 0.82, 0.3)
const TEAL := Color(0.3, 0.9, 0.82)
const LILAC := Color(0.75, 0.6, 1.0)
const MAGENTA := Color(1.0, 0.35, 0.75)
const LIME := Color(0.7, 1.0, 0.35)
const CREAM := Color(1.0, 0.95, 0.85)
const NAVY := Color(0.12, 0.1, 0.32)
const INK := Color(0.15, 0.1, 0.2)


static func model(look: String) -> Node3D:
	var g := Node3D.new()
	g.name = "Watch " + look
	var face := Vector3(PI / 2, 0, 0)                    # cylinders stand up, so this turns a disc to face +Z
	match look:
		"water_clock":
			_m(g, _cyl(0.07, 0.07, 0.2), _glass(Color(0.5, 0.9, 1.0, 0.35)), Vector3(0, 0.03, 0))
			_m(g, _cyl(0.06, 0.06, 0.12), _mat(TEAL, 0.2, 0.0, 0.8), Vector3(0, -0.01, 0))
			for y in [-0.08, 0.14]:
				_m(g, _cyl(0.085, 0.085, 0.025), _mat(GOLD, 0.3, 0.6), Vector3(0, y, 0))
			_m(g, _sph(0.025), _mat(TEAL, 0.1, 0.0, 1.0), Vector3(0, -0.13, 0)).set_meta("drip", true)
			for k in 4:                                    # hour lines on the glass
				_m(g, _box(Vector3(0.03, 0.006, 0.006)), _mat(GOLD, 0.3, 0.6), Vector3(0, -0.04 + k * 0.04, 0.072))
		"seashell":
			for k in 7:                                    # a spiral of shrinking puffs
				var a := k * 0.9
				var r := 0.11 - k * 0.012
				_m(g, _sph(r), _mat(Color(1.0, 0.75, 0.85).lerp(CREAM, k / 7.0), 0.4),
					Vector3(cos(a) * (0.06 - k * 0.007), sin(a) * (0.06 - k * 0.007), -k * 0.015))
			_m(g, _cyl(0.05, 0.05, 0.015), _mat(CREAM, 0.3), Vector3(0, 0, 0.1), face)
			_hands(g, Vector3(0, 0, 0.11), 0.04, [0.6, 3.5], INK)
		"cuckoo":
			_m(g, _box(Vector3(0.2, 0.18, 0.1)), _mat(Color(0.65, 0.45, 0.3), 0.6), Vector3.ZERO)
			var roof := PrismMesh.new()
			roof.size = Vector3(0.27, 0.1, 0.13)
			_m(g, roof, _mat(TEAL, 0.4), Vector3(0, 0.14, 0))
			_m(g, _cyl(0.06, 0.06, 0.012), _mat(CREAM, 0.3), Vector3(0, -0.02, 0.055), face)
			_hands(g, Vector3(0, -0.02, 0.063), 0.045, [0.2, 2.0], INK)
			_m(g, _sph(0.03), _mat(Color(1.0, 0.9, 0.3), 0.5), Vector3(0, 0.075, 0.07)).set_meta("bird", true)
			for s in [-1, 1]:                              # pine-cone weights on chains
				_m(g, _cyl(0.003, 0.003, 0.08), _mat(GOLD, 0.3, 0.6), Vector3(s * 0.05, -0.13, 0.0))
				_m(g, _sph(0.018), _mat(Color(0.5, 0.3, 0.2), 0.7), Vector3(s * 0.05, -0.18, 0.0), Vector3.ZERO, Vector3(1, 1.6, 1))
		"digital":
			_m(g, _torus(0.09, 0.11), _mat(MAGENTA, 0.5), Vector3(0, 0, -0.03), Vector3(0, PI / 2, 0), Vector3(1, 1.25, 0.6))
			_m(g, _box(Vector3(0.15, 0.1, 0.04)), _mat(INK, 0.3, 0.4), Vector3(0, 0, 0.08))
			_m(g, _box(Vector3(0.12, 0.06, 0.005)), _mat(LIME, 0.2, 0.0, 1.4), Vector3(0, 0.005, 0.1))
			var digits := Label3D.new()
			digits.text = "12:00"
			digits.font_size = 64
			digits.pixel_size = 0.0006
			digits.modulate = Color(0.1, 0.25, 0.05)
			digits.outline_size = 0
			digits.position = Vector3(0, 0.005, 0.104)
			g.add_child(digits)
			for k in 3:                                    # little buttons
				_m(g, _box(Vector3(0.015, 0.01, 0.01)), _mat(GOLD, 0.3, 0.6), Vector3(-0.04 + k * 0.04, -0.04, 0.1))
		"sundial":
			_m(g, _cyl(0.12, 0.12, 0.02), _mat(Color(0.95, 0.75, 0.45), 0.6), Vector3.ZERO, Vector3(PI / 2 - 0.5, 0, 0))
			var gnomon := PrismMesh.new()
			gnomon.size = Vector3(0.01, 0.1, 0.1)
			gnomon.left_to_right = 0.0
			_m(g, gnomon, _mat(GOLD, 0.3, 0.7), Vector3(0, 0.03, 0.02), Vector3(-0.5, 0, 0))
			for k in 8:
				var a := PI * (k / 7.0)
				_m(g, _box(Vector3(0.008, 0.03, 0.006)), _mat(INK, 0.6),
					Basis(Vector3.RIGHT, -0.5) * Vector3(cos(a) * 0.09, sin(a) * 0.09, 0.012), Vector3(-0.5, 0, a - PI / 2))
			_m(g, _torus(0.02, 0.03), _mat(GOLD, 0.3, 0.7), Vector3(0, 0.14, -0.05))
		"moon_phase":
			_m(g, _cyl(0.13, 0.13, 0.03), _mat(NAVY, 0.4), Vector3.ZERO, face)
			_m(g, _torus(0.12, 0.14), _mat(LILAC, 0.3, 0.5), Vector3.ZERO, face)
			_m(g, _sph(0.06), _mat(CREAM, 0.4, 0.0, 0.8), Vector3(0, 0.02, 0.02))
			_m(g, _sph(0.058), _mat(NAVY, 0.4), Vector3(0.03, 0.035, 0.035))   # the shadow that makes a crescent
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				_m(g, _sph(0.016), _mat(CREAM, 0.4, 0.0, 0.6), Vector3(cos(a) * 0.095, sin(a) * 0.095, 0.02))
		"robot":
			_m(g, _box(Vector3(0.18, 0.18, 0.07)), _mat(Color(0.7, 0.75, 0.85), 0.3, 0.8), Vector3.ZERO)
			_m(g, _box(Vector3(0.14, 0.1, 0.01)), _mat(TEAL, 0.2, 0.0, 1.0), Vector3(0, 0.01, 0.037))
			for s in [-1, 1]:
				_m(g, _sph(0.016), _mat(INK, 0.3), Vector3(s * 0.035, 0.02, 0.045))
				_m(g, _cyl(0.005, 0.005, 0.08), _mat(Color(0.7, 0.75, 0.85), 0.3, 0.8), Vector3(s * 0.06, 0.13, 0))
				_m(g, _sph(0.02), _mat(MAGENTA, 0.3, 0.0, 1.2), Vector3(s * 0.06, 0.18, 0)).set_meta("blink", s)
				for k in 2:                                # bolts in the corners
					_m(g, _sph(0.012), _mat(GOLD, 0.3, 0.7), Vector3(s * 0.075, -0.07 + k * 0.14, 0.036))
			_m(g, _box(Vector3(0.05, 0.008, 0.005)), _mat(INK, 0.3), Vector3(0, -0.015, 0.044))
		"many_hands":
			_m(g, _cyl(0.13, 0.13, 0.03), _mat(LILAC, 0.4), Vector3.ZERO, face)
			_m(g, _torus(0.12, 0.145), _mat(GOLD, 0.3, 0.7), Vector3.ZERO, face)
			var cols := [MAGENTA, TEAL, LIME, GOLD, INK, Color(1.0, 0.55, 0.3), Color(0.4, 0.6, 1.0)]
			for k in 7:
				var hand := _hands(g, Vector3(0, 0, 0.02 + k * 0.003), 0.06 + (k % 3) * 0.025, [k * 0.9], cols[k])
				hand.set_meta("spin", 0.3 + k * 0.25)
		"egg_timer":
			_m(g, _sph(0.1), _mat(CREAM, 0.4), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.25, 1))
			_m(g, _torus(0.095, 0.105), _mat(MAGENTA, 0.4), Vector3(0, 0.0, 0), Vector3.ZERO)
			for k in 12:
				var a := TAU * k / 12.0
				_m(g, _box(Vector3(0.006, 0.02, 0.006)), _mat(INK, 0.5), Vector3(sin(a) * 0.1, 0.025, cos(a) * 0.1))
			_m(g, _cyl(0.045, 0.05, 0.05), _mat(Color(1, 1, 1), 0.6), Vector3(0, 0.14, 0))     # a tiny chef's hat
			_m(g, _sph(0.06), _mat(Color(1, 1, 1), 0.6), Vector3(0, 0.19, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		"backwards":
			_m(g, _cyl(0.13, 0.13, 0.03), _mat(Color(0.25, 0.15, 0.35), 0.4), Vector3.ZERO, face)
			_m(g, _torus(0.12, 0.145), _mat(MAGENTA, 0.3, 0.6), Vector3.ZERO, face)
			for k in 12:
				var a := TAU * k / 12.0
				_m(g, _box(Vector3(0.008, 0.02, 0.006)), _mat(GOLD, 0.3, 0.6), Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.018), Vector3(0, 0, a))
			var hands := _hands(g, Vector3(0, 0, 0.02), 0.08, [0.0, 2.3], GOLD)
			hands.set_meta("spin", -2.5)                    # the wrong way round
			var arrow := PrismMesh.new()
			arrow.size = Vector3(0.04, 0.04, 0.01)
			_m(g, arrow, _mat(LIME, 0.3, 0.0, 1.0), Vector3(-0.07, 0.17, 0), Vector3(0, 0, PI / 2))
			_m(g, _torus(0.165, 0.175), _mat(LIME, 0.3, 0.0, 1.0), Vector3.ZERO, face)
		"candle":
			for k in 6:                                    # one stripe an hour
				_m(g, _cyl(0.045, 0.045, 0.035), _mat(MAGENTA if k % 2 == 0 else CREAM, 0.6), Vector3(0, -0.08 + k * 0.035, 0))
			_m(g, _cyl(0.004, 0.004, 0.03), _mat(INK, 0.6), Vector3(0, 0.15, 0))
			_m(g, _cyl(0.09, 0.075, 0.02), _mat(GOLD, 0.3, 0.6), Vector3(0, -0.11, 0))
			_m(g, _torus(0.015, 0.025), _mat(GOLD, 0.3, 0.6), Vector3(0.09, -0.1, 0), Vector3(PI / 2, 0, 0))
		"hourglass":
			for s in [-1, 1]:
				_m(g, _cyl(0.0 if s < 0 else 0.07, 0.07 if s < 0 else 0.0, 0.11), _glass(Color(0.8, 0.95, 1.0, 0.35)),
					Vector3(0, s * -0.055, 0))
				_m(g, _cyl(0.085, 0.085, 0.02), _mat(TEAL, 0.4), Vector3(0, s * 0.12, 0))
			_m(g, _cyl(0.0, 0.05, 0.05), _mat(GOLD, 0.6, 0.0, 0.5), Vector3(0, -0.085, 0))   # sand below...
			_m(g, _cyl(0.04, 0.0, 0.035), _mat(GOLD, 0.6, 0.0, 0.5), Vector3(0, 0.03, 0))    # ...and some still above
			for k in 3:
				var a := TAU * k / 3.0
				_m(g, _cyl(0.006, 0.006, 0.24), _mat(TEAL, 0.4), Vector3(cos(a) * 0.08, 0, sin(a) * 0.08))
		"pocket":
			_m(g, _cyl(0.12, 0.12, 0.04), _mat(GOLD, 0.25, 0.85), Vector3.ZERO, face)
			_m(g, _cyl(0.1, 0.1, 0.01), _mat(CREAM, 0.3), Vector3(0, 0, 0.02), face)
			for k in 12:
				var a := TAU * k / 12.0
				_m(g, _box(Vector3(0.006, 0.018, 0.004)), _mat(INK, 0.5), Vector3(cos(a) * 0.08, sin(a) * 0.08, 0.026), Vector3(0, 0, a + PI / 2))
			_hands(g, Vector3(0, 0, 0.028), 0.07, [0.4, 4.2], INK)
			_m(g, _cyl(0.015, 0.015, 0.03), _mat(GOLD, 0.25, 0.85), Vector3(0, 0.135, 0))
			for k in 4:                                    # a short chain
				_m(g, _torus(0.008, 0.016), _mat(GOLD, 0.25, 0.85), Vector3(0.02 * k, 0.17 + 0.02 * k, 0),
					Vector3(PI / 2 * (k % 2), 0, 0))
		"star_chart":
			_m(g, _cyl(0.13, 0.13, 0.025), _mat(NAVY, 0.4), Vector3.ZERO, face)
			_m(g, _torus(0.12, 0.145), _mat(TEAL, 0.3, 0.5), Vector3.ZERO, face)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 16:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.02, 0.1)
				_m(g, _sph(0.006 + rng.randf() * 0.006), _mat(CREAM, 0.3, 0.0, 2.0), Vector3(cos(a) * r, sin(a) * r, 0.016))
			for k in 3:                                    # one constellation joined up
				_m(g, _box(Vector3(0.045, 0.003, 0.003)), _mat(LILAC, 0.3, 0.0, 1.0),
					Vector3(-0.04 + k * 0.035, 0.03 + (k % 2) * 0.015, 0.017), Vector3(0, 0, 0.3 - (k % 2) * 0.6))
			var ptr := _hands(g, Vector3(0, 0, 0.02), 0.11, [0.0], GOLD)
			ptr.set_meta("spin", 0.2)
		"orrery":
			_m(g, _sph(0.045), _mat(GOLD, 0.3, 0.3, 1.5), Vector3.ZERO)
			var cols := [TEAL, MAGENTA, LIME]
			for k in 3:
				var ring := Node3D.new()
				ring.rotation = Vector3(0.3 * k, 0, 0.25 * k)
				ring.set_meta("orbit", 1.4 - k * 0.4)
				g.add_child(ring)
				var r := 0.07 + k * 0.035
				_m(ring, _torus(r - 0.002, r + 0.002), _mat(GOLD, 0.3, 0.7), Vector3.ZERO)
				_m(ring, _sph(0.014 + k * 0.004), _mat(cols[k], 0.4), Vector3(r, 0, 0))
			_m(g, _torus(0.015, 0.025), _mat(GOLD, 0.3, 0.7), Vector3(0, 0.17, 0), Vector3(PI / 2, 0, 0))
		"galaxy":
			_m(g, _cyl(0.13, 0.13, 0.025), _mat(Color(0.08, 0.04, 0.15), 0.4), Vector3.ZERO, face)
			_m(g, _torus(0.12, 0.14), _mat(LILAC, 0.3, 0.6), Vector3.ZERO, face)
			var arms := Node3D.new()
			arms.set_meta("spin", 0.6)
			arms.position = Vector3(0, 0, 0.016)
			g.add_child(arms)
			_m(arms, _sph(0.022), _mat(CREAM, 0.3, 0.0, 2.5), Vector3.ZERO)
			for arm in 2:
				for k in 10:
					var a := arm * PI + k * 0.45
					var r := 0.015 + k * 0.009
					_m(arms, _sph(0.007), _mat(LILAC.lerp(MAGENTA, k / 10.0), 0.3, 0.0, 2.0), Vector3(cos(a) * r, sin(a) * r, 0))
		"crystal_ring":
			_m(g, _torus(0.1, 0.125), _mat(Color(0.85, 0.88, 0.95), 0.2, 0.9), Vector3.ZERO, face)
			var gem := PrismMesh.new()
			gem.size = Vector3(0.07, 0.09, 0.07)
			var top := _m(g, gem, _mat(TEAL, 0.1, 0.0, 1.5), Vector3(0, 0.045, 0))
			top.set_meta("bob", true)
			var bottom := _m(g, gem, _mat(TEAL, 0.1, 0.0, 1.5), Vector3(0, -0.045, 0), Vector3(0, 0, PI))
			bottom.set_meta("bob", true)
			_m(g, _box(Vector3(0.012, 0.03, 0.012)), _mat(MAGENTA, 0.4), Vector3(0.11, 0.05, 0), Vector3(0, 0, 0.5))  # the hair clip
		"beads":
			var cols := [MAGENTA, TEAL, LIME, GOLD, LILAC]
			for k in 20:
				var a := TAU * k / 20.0
				_m(g, _sph(0.022), _mat(cols[k % cols.size()], 0.3), Vector3(cos(a) * 0.11, sin(a) * 0.11, 0))
			_m(g, _torus(0.105, 0.115), _mat(CREAM, 0.6), Vector3.ZERO, face)
		"flower":
			_m(g, _cyl(0.04, 0.04, 0.02), _mat(GOLD, 0.4, 0.0, 0.4), Vector3.ZERO, face)
			for k in 12:
				var a := TAU * k / 12.0
				var petal := _m(g, _sph(0.035), _mat(MAGENTA.lerp(LILAC, (k % 3) / 2.0), 0.5),
					Vector3(cos(a) * 0.075, sin(a) * 0.075, -0.003), Vector3(0, 0, a), Vector3(1.4, 0.7, 0.3))
				petal.set_meta("petal", k)
			_hands(g, Vector3(0, 0, 0.012), 0.035, [0.5, 2.6], INK)
			_m(g, _cyl(0.008, 0.008, 0.16), _mat(LIME, 0.5), Vector3(0, -0.15, -0.01))
		"glowworm":
			for y in [-0.1, 0.1]:
				_m(g, _cyl(0.08, 0.08, 0.02), _mat(Color(0.35, 0.3, 0.45), 0.5, 0.5), Vector3(0, y, 0))
			for k in 6:
				var a := TAU * k / 6.0
				_m(g, _cyl(0.006, 0.006, 0.2), _mat(Color(0.35, 0.3, 0.45), 0.5, 0.5), Vector3(cos(a) * 0.07, 0, sin(a) * 0.07))
			for k in 5:
				var worm := _m(g, _sph(0.015), _mat(LIME, 0.3, 0.0, 2.5),
					Vector3(cos(k * 1.7) * 0.035, -0.05 + k * 0.025, sin(k * 1.7) * 0.035), Vector3.ZERO, Vector3(1.8, 1, 1))
				worm.set_meta("worm", k)
			_m(g, _torus(0.04, 0.05), _mat(Color(0.35, 0.3, 0.45), 0.5, 0.5), Vector3(0, 0.15, 0), Vector3(PI / 2, 0, 0))
		_:
			_m(g, _cyl(0.12, 0.12, 0.04), _mat(GOLD, 0.25, 0.85), Vector3.ZERO, face)
	return g


static func animate(g: Node3D, t: float) -> void:
	# The little moving parts: hands going round (backwards on one), planets orbiting, a drip, a blinking robot...
	for n in g.find_children("*", "Node3D", true, false):
		if n.has_meta("spin"):
			(n as Node3D).rotation.z = -t * float(n.get_meta("spin"))
		elif n.has_meta("orbit"):
			(n as Node3D).rotation.y = t * float(n.get_meta("orbit"))
		elif n.has_meta("drip"):
			(n as Node3D).position.y = -0.11 - fmod(t * 0.15, 0.08)
		elif n.has_meta("bob"):
			(n as Node3D).scale = Vector3.ONE * (1.0 + 0.08 * sin(t * 6.0))
		elif n.has_meta("blink"):
			(n as Node3D).visible = fmod(t + (0.5 if int(n.get_meta("blink")) > 0 else 0.0), 1.0) < 0.7
		elif n.has_meta("bird"):
			(n as Node3D).position.z = 0.07 + maxf(0.0, sin(t * 1.5)) * 0.04
		elif n.has_meta("worm"):
			(n as Node3D).position.y = -0.05 + int(n.get_meta("worm")) * 0.025 + sin(t * 2.0 + int(n.get_meta("worm"))) * 0.01


static func _hands(g: Node3D, at: Vector3, length: float, angles: Array, col: Color) -> Node3D:
	# Clock hands on a little pivot (spin it with meta "spin"): one per angle, the later ones shorter
	var pivot := Node3D.new()
	pivot.position = at
	g.add_child(pivot)
	for k in angles.size():
		var l: float = length * (1.0 if k == 0 else 0.65)
		var arm := Node3D.new()
		arm.rotation.z = float(angles[k])
		pivot.add_child(arm)
		_m(arm, _box(Vector3(0.008, l, 0.004)), _mat(col, 0.4), Vector3(0, l / 2.0, 0))
	_m(pivot, _sph(0.01), _mat(col, 0.4), Vector3.ZERO)
	return pivot


static func _m(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _mat(c: Color, rough := 0.5, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _glass(c: Color) -> StandardMaterial3D:
	var m := _mat(c, 0.05, 0.0, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 20
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 8
	return t


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


# -----------------------------------------------------------------------------
# Little pictures of them, for the card and the Bag: each in its own tiny 3D world, turning slowly. A missing one is
# a dark silhouette.
# -----------------------------------------------------------------------------
func icon_viewport(id: String, found: bool, px := 96) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var holder := WatchIcon.new()
	holder.found = found
	holder.look = id
	vp.add_child(holder)
	return vp


class WatchIcon:
	extends Node3D
	var look := ""
	var found := true
	var _model: Node3D
	var _t := 0.0

	func _ready() -> void:
		_model = Watches.model(look)
		add_child(_model)
		if not found:
			# Every part the same flat dark colour: just its outline shows
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.12, 0.08, 0.2)
			dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			for mi in _model.find_children("*", "GeometryInstance3D", true, false):
				if mi is MeshInstance3D:
					(mi as MeshInstance3D).material_override = dark
				else:
					(mi as GeometryInstance3D).visible = false
		var cam := Camera3D.new()
		cam.position = Vector3(0, 0.0, 0.62)
		cam.fov = 40.0
		add_child(cam)
		var light := DirectionalLight3D.new()
		light.rotation = Vector3(-0.6, 0.5, 0)
		add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.75, 0.7, 0.9)
		env.environment.ambient_light_energy = 0.8
		add_child(env)

	func _process(delta: float) -> void:
		_t += delta
		_model.rotation.y = sin(_t * 0.8) * 0.6
		Watches.animate(_model, _t)


# -----------------------------------------------------------------------------
# The card that pops up when she finds one
# -----------------------------------------------------------------------------
func _build_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 6
	_card.visible = false
	add_child(_card)
	var centre := CenterContainer.new()                  # across the top of the screen, a little way down
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(centre)
	_card_panel = PanelContainer.new()
	_card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_card_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_card_panel.add_child(row)
	_card_icon = SubViewportContainer.new()
	_card_icon.stretch = true
	_card_icon.custom_minimum_size = Vector2(120, 120)
	row.add_child(_card_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_card_title = Label.new()
	_card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	col.add_child(_card_title)
	_card_note = Label.new()
	_card_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_card_note)
	UiStyle.keep_on_screen(_card_panel)               # shrinks to fit at the biggest text sizes (scripts/ui_style.gd)


func _apply_card_look() -> void:
	var k: float = Settings.text_scale
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.07, 0.22, 0.92)
	box.border_color = Color(1.0, 0.82, 0.35)
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14 * k)
	_card_panel.add_theme_stylebox_override("panel", box)
	_card_title.add_theme_font_size_override("font_size", roundi(26 * k))
	_card_note.add_theme_font_size_override("font_size", roundi(19 * k))
	_card_note.custom_minimum_size.x = UiStyle.fit_width(_card_panel, 520 * k + 200.0) - 200.0   # (room for the watch)
	(_card.get_node("Centre") as Control).offset_top = 90 * k
