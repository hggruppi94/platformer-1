extends Node

# Autoload "Schematics": the real unlocks (Hayden, Oct 31: "I want the weapon and skateboard unlocks to be
# significant"). Dash's gadget stall is open from The First Night, but a gadget only goes on sale once its
# blueprint's been found (every gadget, the Star Popper too: nobody starts with one), and the new rides (the Overboard,
# the Bike, the Rocket Board, the Rocket Bike and the Flying Saucer) are the same at Zippy's Tune-Up. The rides'
# schematics turn up on their nights, in the place that night shows off (the 7-night plan in
# /mnt/project-files/roadmap/galaxity-plan.md, F4); the gadgets' blueprints are in the portal worlds (LIST). They stay
# where they are until they're found. In code they're all "schematics"; the player sees "blueprint" for a gadget.
#
# Like the lost watches (scripts/watches.gd), the pickups are put into whichever scene is showing at play time
# (scripts/schematic_pickup.gd), so no builder or .tscn changed. What's been found is a Dialogue flag
# ("schematic_<id>"), so a save needs nothing new and an old save just has none. Gadgets an old save already owns
# stay owned (and a save from before gadgets keeps the Star Popper it started with). Rides that have been bought are items ("ride:<id>"), and the one the hero rides is Game.hero_ride.

signal found_one(id: String)

const SCENES := {"town": "res://scenes/town/town.tscn", "school": "res://scenes/school/school.tscn"}
const PICK_RADIUS := 1.6                  # how near her middle has to come
const SKY_RADIUS := 10.0                  # ...or the mothership's, for the one in the sky

# kind: "gadget" (its id in Arsenal.GADGETS) or "ride" (its id in Rides.HERO_RIDES). "at" is x, z, dropped onto the
# ground when it's placed; "sky" is a point in the air that only the mothership can reach.
# Gadgets (Hayden, 13 Nov 2026 playtest: "Instead of randomly finding blueprints, make them rewards for completing
# races/quests"; before that, since 11 Nov, they were found lying in the portal worlds): every gadget's blueprint is a
# "reward" now, given to you the moment you earn it (award()): for a quest (a Dialogue flag), for winning a race the
# first time (a track id in scripts/races.gd), or as a friend's thank-you when their world's mended (a Portals.WORLDS
# id). They're never put out in the world. A world's hint only names the world once its portal is open, so nothing
# gives away a world before it turns up. Rides stay on their nights.
const LIST := [
	{"id": "popper", "kind": "gadget", "what": "popper", "reward": {"flag": "bb_thanked", "from": "Dash"},
		"hint": "Dash's thank-you for catching his runaway Buzz Bot."},
	{"id": "fizz", "kind": "gadget", "what": "fizz", "reward": {"race": "lake_loop", "from": "Zippy"},
		"hint": "The prize for winning the Lake Loop. Talk to Zippy at the race gate!"},
	{"id": "buzz", "kind": "gadget", "what": "buzz", "reward": {"race": "meadow_wiggle", "from": "Zippy"},
		"hint": "The prize for winning the Meadow Wiggle, at Zippy's race gate."},
	{"id": "rainbow", "kind": "gadget", "what": "rainbow", "reward": {"race": "observatory_hill", "from": "Zippy"},
		"hint": "The prize for winning Observatory Hill, at Zippy's race gate."},
	{"id": "plush", "kind": "gadget", "what": "plush", "reward": {"race": "pumpkin_run", "from": "Pepper"},
		"hint": "The prize for winning the Pumpkin Run. Pepper starts it, on Maple Lane in Stars Hollow."},
	{"id": "disco", "kind": "gadget", "what": "disco", "reward": {"world": "rhythm_springs", "from": "Melody"},
		"hint": "Melody's thank-you, once Rhythm Springs has its beat back."},
	{"id": "jelly", "kind": "gadget", "what": "jelly", "reward": {"world": "tide_reef", "from": "Otto"},
		"hint": "Otto's thank-you, once the tide's back in on the Tide Reef."},
	{"id": "overboard", "kind": "ride", "what": "overboard", "night": 3, "scene": "town", "at": Vector2(34, 58),
		"hint": "In the south meadow, on the side nearest the lake."},
	{"id": "bike", "kind": "ride", "what": "bike", "night": 4, "scene": "town", "at": Vector2(84, -98),
		"hint": "Round the far side of Observatory Hill."},
	{"id": "rocket_board", "kind": "ride", "what": "rocket_board", "night": 5, "scene": "town",
		"sky": Vector3(60, 46, 24), "hint": "Floating high over town, on the Sky Rings' way. Only a ship can reach it."},
	{"id": "rocket_bike", "kind": "ride", "what": "rocket_bike", "night": 6, "scene": "town", "at": Vector2(-20, -108),
		"hint": "On the way up to the castle school, by the long rail."},
	{"id": "saucer", "kind": "ride", "what": "saucer", "night": 7, "scene": "town", "at": Vector2(112, -186),
		"hint": "In the far field, a long way out."},
]

# What each ride costs at Zippy's Tune-Up (the shop keeps prices at 20 or under)
# The Hover Bike has no schematic: Zippy makes it from your Bike once you're Lv 3 (scripts/ride_upgrades.gd)
const RIDE_PRICES := {"overboard": 14, "bike": 16, "hover_bike": 17, "rocket_board": 18, "rocket_bike": 20, "saucer": 20}

var _night := 0                   # the night they were last put out for
var _scene: Node
var _reward_wait := 2.0            # (checked twice a second; not straight away, while a save's still loading)


func _ready() -> void:
	_register_shop()


func _process(delta: float) -> void:
	_reward_wait -= delta
	if _reward_wait <= 0.0:
		_reward_wait = 0.5
		_check_rewards()
	var s := get_tree().current_scene
	# A new night's schematics go out the moment the night ticks over too: the request board counts the nights
	# (Nights.night()) and it can roll a moment after landing, so placing them only on arrival left tonight's
	# hidden until the next door (found in the 10 Nov playthrough, tools/playthrough.gd).
	if s != _scene or Nights.night() != _night:
		_scene = s
		_night = Nights.night()
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
	# A schematic is out from its own night on (an old save on a later night gets every one up to it at once). One in a
	# portal world is always there, for whenever you get there.
	var e := entry(id)
	if e.is_empty() or e.has("reward"):
		return false                     # (a reward's never out in the world: it's given to you)
	# (or that night's story quest has started early: they follow on without waiting for a visit, scripts/meetings.gd)
	return e.has("world") or Nights.night() >= int(e.night) or Dialogue.flags.has("night_%d" % int(e.night))


func hint_ready(id: String) -> bool:
	# Whether to say where it is: one in a portal world only once that world's portal has opened (so the hint never
	# gives away a world before it turns up), the rest from their night
	var e := entry(id)
	if e.is_empty():
		return false
	if e.has("reward"):
		var r: Dictionary = e.reward
		if r.has("world"):
			return Portals.is_open(str(r.world)) or Portals.is_cleared(str(r.world))
		if r.has("flag"):
			return Dialogue.flags.has("bike_boy_start") or Dialogue.flags.has(str(r.flag))
		return true                      # (a race: the race boards show every one)
	if e.has("world"):
		return Portals.is_open(str(e.world)) or Portals.is_cleared(str(e.world))
	return out_tonight(id)


func for_thing(kind: String, what: String) -> Dictionary:
	for e in LIST:
		if e.kind == kind and e.what == what:
			return e
	return {}


func gadget_unlocked(g: String) -> bool:
	# A gadget can be bought once its schematic's found (one she has stays hers)
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
		if hint_ready(str(e.id)) and not is_found(str(e.id)):
			return e
	return {}


func blueprint_of(e: Dictionary) -> String:
	# "the Fizz Flinger's blueprint", "the Buzz Bots' blueprint"
	var n := thing_name(e)
	return "the %s%s blueprint" % [n, "'" if n.ends_with("s") else "'s"]


func thing_name(e: Dictionary) -> String:
	if str(e.kind) == "gadget":
		return Arsenal.gadget_name(str(e.what))
	return str(Rides.HERO_RIDES.get(str(e.what), {}).get("name", str(e.what).capitalize()))


func note_for(kind: String, what: String) -> String:
	# The line under a locked thing in the shop: where its schematic is, once it's out
	var e := for_thing(kind, what)
	if e.is_empty() or is_found(str(e.id)) or (kind == "gadget" and Arsenal.owns(what)) or (kind == "ride" and owns_ride(what)):
		return ""
	if hint_ready(str(e.id)):
		return "[Blueprint] " + str(e.hint) if kind == "gadget" else "[Schematic] " + str(e.hint)
	if e.has("reward") or e.has("world"):
		return "[Blueprint] Not yet. A friend has it..."
	return "[Schematic] Not out yet. Maybe on night %d..." % int(e.night)


# -----------------------------------------------------------------------------
# Rewards: blueprints you're given for a quest, a race won, or a world mended
# -----------------------------------------------------------------------------
func for_race(track_id: String) -> Dictionary:
	# The blueprint that's first prize in a race, or {}
	for e in LIST:
		if str(e.get("reward", {}).get("race", "")) == track_id:
			return e
	return {}


func earned(id: String) -> bool:
	# Whether its reward's been earned (whether or not it's been given yet)
	var r: Dictionary = entry(id).get("reward", {})
	if r.has("race"):
		return int(Races.wins.get(str(r.race), 0)) > 0
	if r.has("flag"):
		return Dialogue.flags.has(str(r.flag))
	if r.has("world"):
		# (In the world itself the friend hands it over in their thank-you: rhythm_springs.gd, tide_reef.gd. This is for
		# a save that mended it before blueprints were rewards, or a thank-you that was skipped.)
		var here := get_tree().current_scene
		return Portals.is_cleared(str(r.world)) and (here == null or scene_key(here.scene_file_path) != str(r.world))
	return false


func award(id: String, quiet := false) -> bool:
	# Gives you a reward's blueprint (once). quiet: no message (the race results say it instead)
	var e := entry(id)
	if e.is_empty() or is_found(id):
		return false
	Dialogue.set_flag("schematic_" + id)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("chime", 1.0, -6.0)
	Juice.rumble(0.35, 0.2)
	if not quiet:
		var from := str(e.get("reward", {}).get("from", ""))
		Game.message("%s %s! Take it to Dash's stall."
			% ["%s gives you a blueprint!" % from if from != "" else "A blueprint!", "It's " + blueprint_of(e)])
	found_one.emit(id)
	Game.save_game()
	return true


func _check_rewards() -> void:
	# Hands over anything earned and not given yet: straight after the quest step or the world's mending, and for an
	# old save the first time it loads (a race already won, a world already mended, Dash already thanked)
	for e in LIST:
		var id := str(e.id)
		if e.has("reward") and not is_found(id) and earned(id):
			award(id)


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
		Game.message("The %s blueprint! Take it to Dash." % thing_name(e))
	else:
		Game.message("The %s schematic! Take it to Zippy." % thing_name(e))
	found_one.emit(id)
	Game.save_game()


# -----------------------------------------------------------------------------
# Rides: buying one at Zippy's Tune-Up, and riding it
# -----------------------------------------------------------------------------
func _register_shop() -> void:
	Shop.register_kind("ride", {"can_buy": _can_buy_ride, "buy": _buy_ride, "button": "Build it!",
		"note": _ride_note})
	for r in RIDE_PRICES:
		var item_id := "ride_" + str(r)
		var ride: Dictionary = Rides.HERO_RIDES[r]
		Shop.items[item_id] = {"id": item_id, "name": str(ride.name), "stall": "Tune-Up", "kind": "ride", "ride": r,
			"price": int(RIDE_PRICES[r]), "text": str(ride.says) + (" (Lv %d)" % int(ride.level) if ride.has("level") else "")}


func _ride_note(it: Dictionary) -> String:
	# Where its schematic is, or else what level Zippy's waiting for
	var n := note_for("ride", str(it.ride))
	return n if n != "" else RideUpgrades.level_note(str(it.ride))


func _can_buy_ride(it: Dictionary) -> String:
	var r := str(it.ride)
	if owns_ride(r):
		return "You have this one"
	if not ride_unlocked(r):
		return "Find its schematic"
	var lock := RideUpgrades.lock_line(r)
	if lock != "":
		return lock
	if not Game.has_item("skateboard"):
		return "Needs a skateboard"
	return ""


func _buy_ride(it: Dictionary) -> String:
	var r := str(it.ride)
	Game.give_item("ride:" + r)
	use_ride(r)
	return "Your %s is ready! Swap rides in your menu (%s)." % [str(it.name),
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
	var key := scene_key(scene.scene_file_path)
	if key == "":
		return
	for e in LIST:
		var id := str(e.id)
		if where(e) != key or is_found(id) or not out_tonight(id) or scene.get_node_or_null("Schematic " + id):
			continue
		if e.has("world") and (Portals.practice or scene.has_meta("preview")):
			continue                    # nothing found on a practice trip is kept, and a portal's preview is just a picture
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


func where(e: Dictionary) -> String:
	# Which scene it's in: "town", "school" or a portal world's id ("" for a reward: it's never put out)
	if e.has("reward"):
		return ""
	return str(e.world) if e.has("world") else str(e.get("scene", ""))


func scene_key(path: String) -> String:
	for k in SCENES:
		if path == SCENES[k]:
			return k
	var w: Dictionary = Portals.world_for_scene(path)
	return str(w.get("id", ""))


func refresh() -> void:
	# Put out any that a new night has brought (Nights calls this when a night starts)
	if get_tree().current_scene:
		_place_in(get_tree().current_scene)
