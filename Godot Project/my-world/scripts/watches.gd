extends Node

# Autoload "Watches": the lost watches hunt. Everyone who arrives on Galaxity, the brain planet outside time, has a
# watch that tracks time the way it worked on their own planet or in their own time (story/how-it-fits.md, the time
# arc), and twenty chosen kids have lost theirs round Galaxity. Each one is a small glowing model that spins where it
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
		"place": "Balanced on top of the Market Square fountain's water ball",
		"hint": "It likes the sound of splashing, right in the middle of everything.",
		"note": "Mo's, from a desert planet where water is precious. Drip, drip, drip: that's about lunchtime."},
	{"id": "seashell", "name": "Tide Shell", "scene": "town", "pos": Vector3(0, -0.1, 2), "how": "wade",
		"place": "Out in the middle of the lake",
		"hint": "It floats where the boats bob. You'll get your feet wet.",
		"note": "Coral's, from an ocean world with no land at all. It counts the tides. It's high tide. Probably."},
	{"id": "cuckoo", "name": "Cuckoo Locket", "scene": "town", "pos": Vector3(124.5, 8.5, 3), "how": "climb",
		"place": "Up on the tree house deck",
		"hint": "Up among the leaves, where you can see the whole neighbourhood.",
		"note": "Greta's, from a mountain village on Earth, about 1750. The tiny bird pops out to say hello, never the time."},
	{"id": "digital", "name": "Beep Band", "scene": "town", "pos": Vector3(100.45, 5.43, 6.21), "how": "zipline",
		"place": "Hanging off the zipline's cable, halfway down",
		"hint": "Snagged on something fast and whirry. Hold on tight!",
		"note": "Zack's, from Earth in 1985. It beeps every hour on the hour, and it has a calculator!"},
	{"id": "sundial", "name": "Sundial Pendant", "scene": "town", "pos": Vector3(125, 10.8, 54), "how": "climb",
		"place": "On top of the rock wall",
		"hint": "Where the sun hits first, after a long climb.",
		"note": "Tilly's, from a time so long ago people told the time by shadows. It only works when it's sunny."},
	{"id": "moon_phase", "name": "Moon-Nap Dial", "scene": "town", "pos": Vector3(-56, 18.8, -55), "how": "climb",
		"place": "Up in the Cloud Nest",
		"hint": "Nesting somewhere soft, high above the Secret Gardens.",
		"note": "Luna's, from a moon with four moons of its own. It counts time in moon-naps. This one says: nap."},
	{"id": "robot", "name": "Bolt Watch", "scene": "town", "pos": Vector3(-10, 17.3, -120.6), "how": "grind",
		"place": "Over the long rail on the castle hill",
		"hint": "Along a grind line, up on the way to school.",
		"note": "A robot's watch. Or a watch's robot? It says BEEP BOOP, which means quarter past."},
	{"id": "many_hands", "name": "Watch of Many Hands", "scene": "town", "pos": Vector3(40.5, 5.0, 59), "how": "skate",
		"place": "High over the Skate Park's west quarter pipe",
		"hint": "You'll need big air at the Skate Park for this one.",
		"note": "Professor Pockets', from a planet with 37 hours in a day. Every hand is a different hour. Which one's lunch?"},
	{"id": "egg_timer", "name": "Chef's Egg Timer", "scene": "town", "pos": Vector3(-128, 0.9, 8), "how": "walk",
		"place": "In the middle of the Gloop King's court",
		"hint": "Somebody gooey and royal is sitting on it, out west.",
		"note": "Chef Pepper's, from the year 3000. It dings when the soup is ready, and when someone needs a hug."},
	{"id": "backwards", "name": "Backwards Watch", "scene": "town", "pos": Vector3(122, 0.8, -196), "how": "walk",
		"place": "In the far field, where the Agent of Chaos stomps",
		"hint": "Near someone very big, whose clock runs the wrong way too.",
		"note": "Its owner says they got here tomorrow. Nobody knows what that means. Its hands go round backwards."},
	{"id": "candle", "name": "Candle Clock", "scene": "town", "pos": Vector3(-120, 0.8, -110), "how": "walk",
		"place": "In the Spooky Woods",
		"hint": "Somewhere dark and twisty, where a light would help.",
		"note": "Wick's, from a castle on Earth, ages ago. It burns one stripe an hour, but it's never been lit."},
	{"id": "hourglass", "name": "Hourglass Charm", "scene": "town", "pos": Vector3(56.4, -0.5, -86.3), "how": "wade",
		"place": "In the pond under the castle's east waterfall",
		"hint": "Where falling water lands, under the castle rock.",
		"note": "Sandy's, from a planet where a day is one hourglass long. Flip it over and it's tomorrow."},
	{"id": "pocket", "name": "Railway Pocket Watch", "scene": "town", "pos": Vector3(-72, 8.4, 16), "how": "beam",
		"place": "On top of the Town Hall's dome",
		"hint": "On a very important roof. You'll need a lift from above.",
		"note": "Bertie's, a railway boy from Earth in 1895. Still ticking, still very serious about being on time."},
	{"id": "star_chart", "name": "Star-Chart Dial", "scene": "town", "pos": Vector3(105, 24.1, -88), "how": "beam",
		"place": "On top of the Observatory dome",
		"hint": "Closer to the stars than the telescope is.",
		"note": "Nova's, a sailor from a world with no sun. She told the time by which stars were up."},
	{"id": "orrery", "name": "Orrery Charm", "scene": "town", "pos": Vector3(28, 76.3, -147), "how": "beam",
		"place": "On the very top of the castle's tallest spire",
		"hint": "The highest point of the school. Nobody climbs up there.",
		"note": "Tiny planets round a tiny sun. Its owner said it shows where everyone is from. Which is... everywhere?"},
	{"id": "galaxy", "name": "Spiral Galaxy Watch", "scene": "town", "pos": Vector3(10, 115, -180), "how": "sky",
		"place": "Way up in the sky over the castle",
		"hint": "Above the clouds over the school. Only a ship could get there.",
		"note": "It goes round once every hundred million years. Its owner, Stella, is very, very patient."},
	{"id": "crystal_ring", "name": "Humming Crystal Ring", "scene": "town", "pos": Vector3(-110, 100, 20), "how": "sky",
		"place": "High in the sky over the west fields",
		"hint": "It's humming somewhere up where the mothership cruises.",
		"note": "Kit's, from the far, far future. It hums the same note every second. Somebody fixed it with a hair clip."},
	{"id": "beads", "name": "Bead Calendar", "scene": "school", "pos": Vector3(6, 13.0, -23.2), "how": "walk",
		"place": "On the sill of the school's big top-floor window",
		"hint": "At school, by a window with a view of the mountains.",
		"note": "Every bead is a day, and someone counted 3,000 of them. That's a long time. They must have had a lot of fun."},
	{"id": "flower", "name": "Flower Clock", "scene": "school", "pos": Vector3(-12, 1.5, 33), "how": "walk",
		"place": "On the potting table in the school's greenhouse",
		"hint": "Somewhere warm and green, at school.",
		"note": "Petal's, from a garden planet. Each petal opens at a different hour, so you tell the time by smelling it."},
	{"id": "glowworm", "name": "Glow-Worm Lantern", "scene": "scary", "pos": Vector3(-21, 0.9, -15), "how": "walk",
		"place": "At the edge of the Scary World's clearing",
		"hint": "In a scary place, if you're brave enough to go in. Look along the edge.",
		"note": "Its glow-worms shine brighter as the day goes on. They're always sleepy, so it's always nearly bedtime."},
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
	return {"watches_new": str(to_give().size()), "watches_given": str(given), "watches_left": str(WATCHES.size() - given)}


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
	var tail := "Dash collects these." if given_count() == 0 and n == 1 else "%d of %d found." % [n, WATCHES.size()]
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
# returns are said after the conversation's own)
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
		lines.append("That's all twenty. Every watch back where it can be looked after. Thanks, {player}.")
	else:
		var nxt := next_reward()
		if not nxt.is_empty():
			lines.append("Bring me %d more and I'll have something else for you." % (int(nxt.at) - given))
	Audio.play("level_up", -4.0, 0.0)
	handed_in.emit(given)
	return lines


const REWARD_LINES := {
	5: "Five! You're good at this. Here, some sparkles. Little bits of broken time, from my pocket.",
	10: "Ten?! Okay, I tinkered with your Star Popper. Don't tell anyone. It ticks now. Just a bit.",
	15: "Fifteen! You've earned this. A Tick-Tock Sticker! It goes on a sash, like Rex's.",
	20: "Twenty. ALL of them. I made you one, from bits of all the others: the Time Keeper. It keeps your time.",
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
		if w.scene == here and not is_found(w.id):
			var p := WatchPickup.new()
			p.id = w.id
			p.name = "Watch " + str(w.id)
			p.sky = w.how == "sky"
			holder.add_child(p)
			p.global_position = w.pos


# -----------------------------------------------------------------------------
# How each one looks, built from shapes in the alien palette. About 0.3 m across, dial facing +Z.
# -----------------------------------------------------------------------------
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
	_card_note.custom_minimum_size.x = 520 * k
	(_card.get_node("Centre") as Control).offset_top = 90 * k
