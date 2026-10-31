extends Node

# Autoload "Schematics": the real unlocks (Hayden, Oct 31: "I want the weapon and skateboard unlocks to be
# significant"). Dash's gadget stall is open from The First Night, but a gadget only goes on sale once its
# schematic's been found, and the new rides (the Overboard, the Bike, the Rocket Board, the Rocket Bike and the Flying
# Saucer) are the same at Zippy's Tune-Up. One or two schematics turn up each night, in the place that night shows off
# (the 7-night plan in /mnt/project-files/roadmap/galaxity-plan.md, F4), and they stay there until they're found.
#
# Like the lost watches (scripts/watches.gd), the pickups are put into whichever scene is showing at play time
# (scripts/schematic_pickup.gd), so no builder or .tscn changed. What's been found is a Dialogue flag
# ("schematic_<id>"), so a save needs nothing new and an old save just has none. Gadgets an old save already owns
# stay owned. Rides that have been bought are items ("ride:<id>"), and the one the hero rides is Game.hero_ride.

signal found_one(id: String)

const SCENES := {"town": "res://scenes/town/town.tscn", "school": "res://scenes/school/school.tscn"}
const PICK_RADIUS := 1.6                  # how near her middle has to come
const SKY_RADIUS := 10.0                  # ...or the mothership's, for the one in the sky

# kind: "gadget" (its id in Arsenal.GADGETS) or "ride" (its id in Rides.HERO_RIDES). "at" is x, z, dropped onto the
# ground when it's placed; "sky" is a point in the air that only the mothership can reach.
const LIST := [
	{"id": "fizz", "kind": "gadget", "what": "fizz", "night": 2, "scene": "town", "at": Vector2(28, 21),
		"hint": "On the promenade by the portal, where Pip looks after the lamps."},
	{"id": "disco", "kind": "gadget", "what": "disco", "night": 3, "scene": "town", "at": Vector2(-8, 58),
		"hint": "Out in the south meadow, beside the Meadow Wiggle."},
	{"id": "overboard", "kind": "ride", "what": "overboard", "night": 3, "scene": "town", "at": Vector2(34, 58),
		"hint": "In the south meadow too, on the side nearest the lake."},
	{"id": "jelly", "kind": "gadget", "what": "jelly", "night": 4, "scene": "town", "at": Vector2(97, -63),
		"hint": "Halfway up Observatory Hill."},
	{"id": "bike", "kind": "ride", "what": "bike", "night": 4, "scene": "town", "at": Vector2(84, -98),
		"hint": "Round the far side of Observatory Hill."},
	{"id": "buzz", "kind": "gadget", "what": "buzz", "night": 5, "scene": "town", "at": Vector2(122, -36),
		"hint": "Right beside the Mothership Pad."},
	{"id": "rocket_board", "kind": "ride", "what": "rocket_board", "night": 5, "scene": "town",
		"sky": Vector3(60, 46, 24), "hint": "Floating high over town, on the Sky Rings' way. Only a ship can reach it."},
	{"id": "plush", "kind": "gadget", "what": "plush", "night": 6, "scene": "school", "at": Vector2(-4, 30),
		"hint": "At the castle school, in the Entrance Garden."},
	{"id": "rocket_bike", "kind": "ride", "what": "rocket_bike", "night": 6, "scene": "town", "at": Vector2(-20, -108),
		"hint": "On the way up to the castle school, by the long rail."},
	{"id": "rainbow", "kind": "gadget", "what": "rainbow", "night": 7, "scene": "town", "at": Vector2(-114, -104),
		"hint": "Deep in the Spooky Woods."},
	{"id": "saucer", "kind": "ride", "what": "saucer", "night": 7, "scene": "town", "at": Vector2(112, -186),
		"hint": "In the far field, near someone very, very big."},
]

# What each ride costs at Zippy's Tune-Up (the shop keeps prices at 20 or under)
const RIDE_PRICES := {"overboard": 14, "bike": 16, "rocket_board": 18, "rocket_bike": 20, "saucer": 20}

var _scene: Node


func _ready() -> void:
	_register_shop()


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		if s:
			_place_in.call_deferred(s)


# -----------------------------------------------------------------------------
# What's been found
# -----------------------------------------------------------------------------
func entry(id: String) -> Dictionary:
	for e in LIST:
		if e.id == id:
			return e
	return {}


func is_found(id: String) -> bool:
	return Dialogue.flags.has("schematic_" + id)


func out_tonight(id: String) -> bool:
	# A schematic is out from its own night on (an old save on a later night gets every one up to it at once)
	var e := entry(id)
	return not e.is_empty() and Nights.night() >= int(e.night)


func for_thing(kind: String, what: String) -> Dictionary:
	for e in LIST:
		if e.kind == kind and e.what == what:
			return e
	return {}


func gadget_unlocked(g: String) -> bool:
	# A gadget can be bought once its schematic's found (the Star Popper's given; one she has stays hers)
	var e := for_thing("gadget", g)
	return e.is_empty() or is_found(str(e.id)) or Arsenal.owns(g)


func ride_unlocked(r: String) -> bool:
	var e := for_thing("ride", r)
	return e.is_empty() or is_found(str(e.id)) or owns_ride(r)


func owns_ride(r: String) -> bool:
	return r == "board" or Game.has_item("ride:" + r)


func found_count() -> int:
	return LIST.filter(func(e: Dictionary) -> bool: return is_found(str(e.id))).size()


func next_hint() -> Dictionary:
	# The first schematic that's out and not found yet (for the Goals page), or {}
	for e in LIST:
		if out_tonight(str(e.id)) and not is_found(str(e.id)):
			return e
	return {}


func thing_name(e: Dictionary) -> String:
	if str(e.kind) == "gadget":
		return Arsenal.gadget_name(str(e.what))
	return str(Rides.HERO_RIDES.get(str(e.what), {}).get("name", str(e.what).capitalize()))


func note_for(kind: String, what: String) -> String:
	# The line under a locked thing in the shop: where its schematic is, once it's out
	var e := for_thing(kind, what)
	if e.is_empty() or is_found(str(e.id)) or (kind == "gadget" and Arsenal.owns(what)) or (kind == "ride" and owns_ride(what)):
		return ""
	if out_tonight(str(e.id)):
		return "[Schematic] " + str(e.hint)
	return "[Schematic] Not out yet. Maybe on night %d..." % int(e.night)


func pick_up(id: String, at := Vector3.ZERO) -> void:
	if is_found(id) or entry(id).is_empty():
		return
	var e := entry(id)
	Dialogue.set_flag("schematic_" + id)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("chime", 1.0, -6.0)
	Juice.shake(0.12)
	Juice.rumble(0.35, 0.2)
	var s := get_tree().current_scene
	if s:
		Fx.burst(s, at, Color(0.45, 0.75, 1.0), 20, 0.07, 3.5, -2.0, 0.8)
		Fx.burst(s, at, Color(1.0, 1.0, 1.0), 10, 0.05, 2.5, -1.0, 0.7)
	if str(e.kind) == "gadget":
		Game.message("A schematic for the %s! Dash can build it now: find his gadget stall in the Market Square." % thing_name(e))
	else:
		Game.message("A schematic for the %s! Zippy can build it now, at the Tune-Up by the race board." % thing_name(e))
	found_one.emit(id)
	Game.save_game()


# -----------------------------------------------------------------------------
# Rides: buying one at Zippy's Tune-Up, and riding it
# -----------------------------------------------------------------------------
func _register_shop() -> void:
	Shop.register_kind("ride", {"can_buy": _can_buy_ride, "buy": _buy_ride, "button": "Build it!",
		"note": func(it: Dictionary) -> String: return note_for("ride", str(it.ride))})
	for r in RIDE_PRICES:
		var item_id := "ride_" + str(r)
		var ride: Dictionary = Rides.HERO_RIDES[r]
		Shop.items[item_id] = {"id": item_id, "name": str(ride.name), "stall": "Tune-Up", "kind": "ride", "ride": r,
			"price": int(RIDE_PRICES[r]), "text": str(ride.says)}


func _can_buy_ride(it: Dictionary) -> String:
	var r := str(it.ride)
	if owns_ride(r):
		return "You have this one"
	if not ride_unlocked(r):
		return "Find its schematic"
	if not Game.has_item("skateboard"):
		return "Needs a skateboard"
	return ""


func _buy_ride(it: Dictionary) -> String:
	var r := str(it.ride)
	Game.give_item("ride:" + r)
	use_ride(r)
	return "Your %s is ready! It's what you ride now. Swap rides on the Skate page of your menu (%s)." % [str(it.name),
		Settings.prompt("player_menu")]


func rides_owned() -> Array[String]:
	var out: Array[String] = []
	for r in Rides.HERO_ORDER:
		if owns_ride(str(r)):
			out.append(str(r))
	return out


func use_ride(r: String) -> void:
	# Ride this from now on (the hero only: friends at the Skaters' Corner keep their own rides)
	if not owns_ride(r):
		return
	Game.hero_ride = r
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get("rider") == "hero" and player.has_method("set_rider"):
		player.set_rider("hero", false)
	Game.equipment_changed.emit()


# -----------------------------------------------------------------------------
# Putting them out
# -----------------------------------------------------------------------------
func _place_in(scene: Node) -> void:
	if not is_instance_valid(scene) or not scene is Node3D:
		return
	var key := ""
	for k in SCENES:
		if scene.scene_file_path == SCENES[k]:
			key = k
	if key == "":
		return
	for e in LIST:
		var id := str(e.id)
		if str(e.scene) != key or is_found(id) or not out_tonight(id) or scene.get_node_or_null("Schematic " + id):
			continue
		var p := (load("res://scripts/schematic_pickup.gd") as GDScript).new() as Node3D
		p.name = "Schematic " + id
		p.set("id", id)
		p.set("sky", e.has("sky"))
		scene.add_child(p)
		if e.has("sky"):
			p.global_position = e.sky
		else:
			var xz: Vector2 = e.at
			p.global_position = Vector3(xz.x, 0.0, xz.y)
			p.call("drop")


func refresh() -> void:
	# Put out any that a new night has brought (Nights calls this when a night starts)
	if get_tree().current_scene:
		_place_in(get_tree().current_scene)
