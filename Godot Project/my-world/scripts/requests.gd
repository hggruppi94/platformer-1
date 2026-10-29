extends Node

# Autoload "Requests": the nightly request board in Galaxity's Market Square (scripts/request_board.gd), and Tally, the
# little alien with a clipboard who walks round the square (scripts/request_alien.gd). Every Shift the board puts up
# three requests from the people of Galaxity, new each Galaxity day (one roll per visit: Clock's day number at the
# Shift's dawn), each paying sparkles: one easy, one medium and one harder, never the same kind twice in a night, and
# growing gently with the nights played.
#
# The kinds use what the game already has: popping Gloops (with the Star Popper, by stomping, or any way), popping a
# dizzy Crocodillo, a long grind, a big combo, a score at the Skate Park, bringing a friend something from the market
# or from Earth, going to a place, and finding a lost watch (once there are watches to find: see has_watches()).
# Progress comes in through note() (Gloops, Crocodillos, grinds and watches call it), the skater's banked combos, the
# shop (a snack bought for a delivery is wrapped up instead of eaten: wrap()), parcels picked up on Earth, talking to
# the friend it's for, and where the player is.
#
# Talking to Tally or using the board turns finished requests in for their sparkles, with a little celebration.
# Unfinished ones just fade away at the end of the Shift, with no penalty; finished ones not yet turned in are paid
# then too. The board, and the requests part of the Tab menu's Quests sheet (scripts/quests.gd), show progress live.
# Everything is saved with the game (scripts/game.gd, "requests"); saves from before the board have none, and get
# their first three on the next Shift.

signal changed

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const TIERS := ["easy", "medium", "hard"]
const PAY := {"easy": 3, "medium": 5, "hard": 8}           # sparkles, plus a little more as the nights go by
const CLERK := "Tally"                                     # the little alien with the clipboard

# How much each kind asks for, at each difficulty, on the first night. Kinds without an amount for a tier aren't
# offered at that tier.
const KINDS := {
	"gloops": {"easy": 3, "medium": 6, "hard": 10},
	"crocodillo": {"medium": 1, "hard": 2},
	"grind": {"easy": 8, "medium": 15, "hard": 25},          # metres, in one grind
	"combo": {"easy": 800, "medium": 2000, "hard": 4000},     # points, in one combo
	"park_score": {"easy": 3000, "medium": 8000, "hard": 15000},
	"deliver": {"easy": 1, "medium": 1, "hard": 1},          # easy/medium: from the market; hard: from Earth
	"visit": {"easy": 1, "medium": 1, "hard": 1},
	"watch": {"medium": 1, "hard": 2},
}
const SKATE_KINDS := ["grind", "combo", "park_score"]
const FRIENDS := {"pip": "Pip", "bramble": "Bramble", "rex": "Rex", "dash": "Dash", "mr_palmer": "Mr. Palmer",
	"nina": "Nina"}
const MARKET_GIFTS := ["star_apple", "cloud_candy", "galaxy_pop", "moon_melon"]     # snacks in res://shop/items.json
# Things from Earth: id, what it is, and the Earth building it's waiting outside (scenes/earth/earth.tscn)
const EARTH_GIFTS := [["pie", "a slice of diner pie", "Hollow Diner"], ["storybook", "an Earth storybook", "Bookshop"],
	["apples", "a bag of Earth apples", "Corner Market"]]
# Places to go: id, name, tier, the node in town that marks it, and how close counts (metres, in 3D, so the
# floating Cloud Nest needs the climb)
const PLACES := [
	["cozy_cave", "the Cozy Cave", "easy", "Happy Places/HappyPlace Cozy Cave", 5.0],
	["tree_house", "the top of the Tree House", "easy", "Happy Places/HappyPlace Tree House", 4.5],
	["observatory", "the Observatory", "medium", "Observatory", 14.0],
	["scary_gate", "the Scary World gate", "medium", "Scary World Gate", 9.0],
	["cloud_nest", "the Cloud Nest", "hard", "Happy Places/HappyPlace Cloud Nest", 5.0],
]
const GLOOP_WAYS := ["any", "bubble", "stomp"]             # pop them any way, with the Star Popper, or by stomping

var list: Array = []          # tonight's requests (see _make())
var rolled_visit := 0         # the visit (Galaxity day at the Shift's dawn) they were rolled for; 0 = never
var nights := 0               # how many nights the board has put requests up
var turned_in := 0            # how many requests the player has finished and been paid for, all told

var _check := 0.0
var _hooked_tricks: Object
var _told := 0                # the visit whose new requests have been announced


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Clock.shift_ended.connect(_on_shift_ended)
	Dialogue.finished.connect(_on_talked)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	changed.connect(_refresh_log)


func _refresh_log() -> void:
	# The Quests sheet shows progress live while it's open
	if Quests.is_log_open() and Quests.log_view_node():
		Quests.log_view_node().text = Quests.log_text()


# -----------------------------------------------------------------------------
# Rolling tonight's three
# -----------------------------------------------------------------------------
func visit_day() -> int:
	# The Galaxity day this Shift began on: after Galaxity's midnight the day number has moved on, but it's the same visit
	return Clock.day if Clock.minutes >= Clock.DAWN_HOUR * 60.0 else Clock.day - 1


func is_live() -> bool:
	return Clock.in_shift() and rolled_visit == visit_day() and not list.is_empty()


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if Clock.in_shift() and rolled_visit != visit_day():
		roll()
	_announce()
	if is_live():
		_check_places()


func roll(seed_value := -1) -> void:
	# Three new requests: one easy, one medium, one harder, all different kinds. Seeded by the visit so a reload
	# halfway through doesn't change them (and a test can ask for a particular night).
	_pay_finished("Sparkles from last night's requests!")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value >= 0 else hash("requests:%d:%d" % [visit_day(), nights])
	nights += 1
	rolled_visit = visit_day()
	list.clear()
	var used: Array[String] = []
	for tier in TIERS:
		var kinds := kinds_for(tier).filter(func(k: String) -> bool: return not k in used)
		if kinds.is_empty():
			continue
		var kind: String = kinds[rng.randi() % kinds.size()]
		used.append(kind)
		list.append(_make(kind, tier, rng))
	_announce()
	changed.emit()


func _announce() -> void:
	# Once a visit, in Galaxity (on Earth the Shift has its own news to tell): there are new requests
	if Clock.on_earth or _told == rolled_visit or not is_live():
		return
	_told = rolled_visit
	Game.message("New requests are up on the board in the Market Square!")


func kinds_for(tier: String) -> Array[String]:
	# The kinds that make sense right now: skating ones once there's a board to ride, watches once they exist
	var out: Array[String] = []
	for k in KINDS:
		if not KINDS[k].has(tier):
			continue
		if k in SKATE_KINDS and not Game.has_item("skateboard"):
			continue
		if k == "watch" and not has_watches():
			continue
		out.append(k)
	return out


func scale() -> float:
	# A little more is asked each night, up to half as much again by night 11, never more
	return 1.0 + 0.05 * clampi(nights - 1, 0, 10)


func _make(kind: String, tier: String, rng: RandomNumberGenerator) -> Dictionary:
	var n: float = KINDS[kind][tier]
	var r := {"kind": kind, "tier": tier, "progress": 0.0, "done": false, "paid": false,
		"sparkles": int(PAY[tier]) + mini(nights / 4, 3)}
	match kind:
		"gloops":
			r.how = GLOOP_WAYS[rng.randi() % GLOOP_WAYS.size()]
			r.goal = _nice(n * scale(), 1)
			if r.how != "any":
				r.goal = maxi(int(r.goal * 0.7), 2)               # a particular way is a bit harder: fewer of them
		"crocodillo", "watch":
			r.goal = int(n)                                       # one or two, however many nights
		"grind":
			r.goal = _nice(n * scale(), 1)
		"combo", "park_score":
			r.goal = _nice(n * scale(), 100)
		"deliver":
			r.goal = 1
			var friends := FRIENDS.keys()
			r.who = friends[rng.randi() % friends.size()]
			r.carrying = false
			if tier == "hard":
				var g: Array = EARTH_GIFTS[rng.randi() % EARTH_GIFTS.size()]
				r.item = g[0]
				r.item_name = g[1]
				r.from = g[2]
			else:
				var id: String = MARKET_GIFTS[rng.randi() % MARKET_GIFTS.size()]
				r.item = id
				r.item_name = str(Shop.items.get(id, {}).get("name", id))
				r.from = "market"
				r.sparkles += int(Shop.items.get(id, {}).get("price", 0))   # always more than it costs to buy
		"visit":
			r.goal = 1
			var places := PLACES.filter(func(p: Array) -> bool: return p[2] == tier)
			var p: Array = places[rng.randi() % places.size()]
			r.place = p[0]
	return r


static func _nice(v: float, step: int) -> int:
	return maxi(int(roundf(v / step)) * step, step)


# -----------------------------------------------------------------------------
# What a request says
# -----------------------------------------------------------------------------
func text_of(r: Dictionary) -> String:
	var g := int(r.get("goal", 1))
	match str(r.kind):
		"gloops":
			match str(r.get("how", "any")):
				"bubble":
					return "Pop %d Gloops with the Star Popper" % g
				"stomp":
					return "Stomp %d Gloops" % g
			return "Pop %d Gloops (bubbles or stomps)" % g
		"crocodillo":
			return "Pop a dizzy Crocodillo" if g == 1 else "Pop %d dizzy Crocodillos" % g
		"grind":
			return "Grind %d m in one go" % g
		"combo":
			return "Land a %s point combo" % _commas(g)
		"park_score":
			return "Score %s at the Skate Park" % _commas(g)
		"deliver":
			var who := friend_name(str(r.who))
			if str(r.from) == "market":
				return "Bring %s a %s from the market" % [who, r.item_name]
			return "Bring %s %s from Earth (%s)" % [who, r.item_name, r.from]
		"visit":
			return "Go to %s" % place_name(str(r.place))
		"watch":
			return "Find a lost watch" if g == 1 else "Find %d lost watches" % g
	return str(r.kind)


func progress_text(r: Dictionary) -> String:
	if r.get("paid", false):
		return "turned in!"
	if r.get("done", false):
		return "done! Turn it in"
	var p := int(r.get("progress", 0.0))
	match str(r.kind):
		"deliver":
			return "got it, now find %s" % friend_name(str(r.who)) if r.get("carrying", false) else ""
		"visit":
			return ""
		"grind":
			return "best %d m" % p if p > 0 else ""
		"combo":
			return "best %s" % _commas(p) if p > 0 else ""
		"park_score":
			return "%s / %s" % [_commas(p), _commas(int(r.goal))]
	return "%d / %d" % [p, int(r.get("goal", 1))]


func friend_name(id: String) -> String:
	return Quests.display_name(id, str(FRIENDS.get(id, id.capitalize())))


func place_name(id: String) -> String:
	for p in PLACES:
		if p[0] == id:
			return p[1]
	return id


static func _commas(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func board_text() -> String:
	var lines: PackedStringArray = ["TONIGHT'S REQUESTS", ""]
	if not is_live():
		lines.append("The board's asleep.")
		lines.append("New requests every Shift!")
		return "\n".join(lines)
	for r in list:
		var mark := "★" if r.paid else ("✔" if r.done else "•")
		var extra := progress_text(r)
		lines.append("%s %s   ✦ %d" % [mark, text_of(r), int(r.sparkles)])
		lines.append("(%s)" % extra if extra != "" and not r.paid else "")
	return "\n".join(lines)


func log_lines() -> Array[String]:
	# For the Tab menu's Quests sheet (scripts/quests.gd log_text())
	var out: Array[String] = []
	if not is_live():
		return out
	out.append("[b]Tonight's requests[/b] (the board in the Market Square)")
	for r in list:
		var extra := progress_text(r)
		var line := "  %s %s  [color=#f5e6a3]✦ %d[/color]" % ["[color=#b8f5b8](done)[/color]" if r.done else "( )",
			text_of(r), int(r.sparkles)]
		if extra != "":
			line += "  [color=#c8c8d8](%s)[/color]" % extra
		out.append(line)
	out.append("")
	return out


# -----------------------------------------------------------------------------
# Progress
# -----------------------------------------------------------------------------
func note(kind: String, amount := 1.0, how := "") -> void:
	# Something happened that a request might want: "gloop" (how: "bubble", "stomp" or "ram"), "crocodillo",
	# "grind" (amount: metres in that one grind), "watch" (a lost watch found)
	if not is_live():
		return
	var any := false
	for r in list:
		if r.done:
			continue
		match [str(r.kind), kind]:
			["gloops", "gloop"]:
				var want := str(r.get("how", "any"))
				if want == "any" or want == how:
					r.progress += amount
					any = true
			["crocodillo", "crocodillo"], ["watch", "watch"]:
				r.progress += amount
				any = true
			["grind", "grind"]:
				if amount > float(r.progress):
					r.progress = floorf(amount)
					any = true
		if any:
			_check_done(r)
	if any:
		changed.emit()


func _on_banked(points: int, _names: String) -> void:
	if not is_live():
		return
	var any := false
	for r in list:
		if r.done:
			continue
		if r.kind == "combo" and points > int(r.progress):
			r.progress = points
			any = true
		elif r.kind == "park_score" and _in_park():
			r.progress += points
			any = true
		_check_done(r)
	if any:
		changed.emit()


func _in_park() -> bool:
	var scene := get_tree().current_scene
	var park := scene.get_node_or_null("Skate Park") if scene else null
	return park != null and park.has_method("in_park") and bool(park.call("in_park"))


func _check_done(r: Dictionary) -> void:
	if r.done or float(r.progress) < float(r.get("goal", 1)):
		return
	r.done = true
	Audio.play("pickup", -2.0, 0.0)
	Game.message("Request done: %s! Turn it in at the board for ✦ %d." % [text_of(r), int(r.sparkles)])


func _check_places() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != TOWN:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for r in list:
		if r.done or r.kind != "visit":
			continue
		for p in PLACES:
			var spot := scene.get_node_or_null(str(p[3])) as Node3D
			if p[0] == r.place and spot and player.global_position.distance_to(spot.global_position) < float(p[4]):
				r.progress = 1.0
				_check_done(r)
				changed.emit()


# --- Deliveries ---------------------------------------------------------------
func wrap(item_id: String) -> String:
	# The shop asks before a snack is eaten: if a delivery wants it, it's wrapped up for that friend instead. Returns
	# the friend's name ("" if nobody wants it).
	if not is_live():
		return ""
	for r in list:
		if r.kind == "deliver" and not r.done and not r.carrying and r.from == "market" and r.item == item_id:
			r.carrying = true
			changed.emit()
			return friend_name(str(r.who))
	return ""


func pick_up(item_id: String) -> void:
	# A parcel on Earth (scripts/request_parcel.gd)
	for r in list:
		if r.kind == "deliver" and not r.done and r.item == item_id and not r.carrying:
			r.carrying = true
			Audio.play("pickup", -3.0)
			Game.message("You picked up %s for %s." % [r.item_name, friend_name(str(r.who))])
			changed.emit()
			return


func wants_parcel(item_id: String) -> bool:
	if not is_live():
		return false
	for r in list:
		if r.kind == "deliver" and not r.done and not r.carrying and r.item == item_id:
			return true
	return false


func _on_talked(id: String) -> void:
	# After a chat with the friend a delivery is for, they get it
	if not is_live():
		return
	for r in list:
		if r.kind == "deliver" and not r.done and r.carrying and r.who == id:
			r.carrying = false
			r.progress = 1.0
			Game.message("%s gave %s %s. %s is so happy!" % [Dialogue.player_name(), friend_name(id), _the(str(r.item_name)),
				friend_name(id)])
			_check_done(r)
			changed.emit()
			return


static func _the(item_name: String) -> String:
	# "a slice of diner pie" -> "the slice of diner pie"; "Star Apple" -> "the Star Apple"
	for a in ["a ", "an "]:
		if item_name.begins_with(a):
			return "the " + item_name.substr(a.length())
	return "the " + item_name


func has_watches() -> bool:
	# Lost watches come with their own hunt (an autoload named "Watches"). Until it's in, the board doesn't ask for them.
	var w := get_node_or_null("/root/Watches")
	return w != null and (not w.has_method("remaining") or int(w.call("remaining")) > 0)


# -----------------------------------------------------------------------------
# Turning in
# -----------------------------------------------------------------------------
func ready_to_turn_in() -> Array:
	return list.filter(func(r: Dictionary) -> bool: return r.done and not r.paid)


func turn_in(at: Node3D = null) -> int:
	# Pays out every finished request; returns the sparkles paid
	var total := 0
	var count := 0
	for r in ready_to_turn_in():
		r.paid = true
		total += int(r.sparkles)
		count += 1
	if total == 0:
		return 0
	turned_in += count
	Game.add_sparkles(total, "Request%s turned in!" % ("" if count == 1 else "s"))
	Audio.play("level_up", -3.0, 0.0)
	if at and at.is_inside_tree():
		_celebrate(at)
	changed.emit()
	Game.save_game()
	return total


func _celebrate(at: Node3D) -> void:
	# Confetti in the board's colours and a little "+N" that floats up
	var scene := get_tree().current_scene
	var top := at.global_position + Vector3.UP * 2.4
	for c in [Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 1.0), Color(0.4, 0.95, 0.85), Color(1.0, 0.55, 0.8)]:
		Fx.burst(scene, top, c, 14, 0.07, 4.0, -4.0, 1.2)


func _pay_finished(why: String) -> void:
	# Finished but not turned in when the Shift ends: no one loses what they earned
	var total := 0
	for r in ready_to_turn_in():
		r.paid = true
		total += int(r.sparkles)
		turned_in += 1
	if total > 0:
		Game.add_sparkles(total, why)


func _on_shift_ended() -> void:
	# Unfinished requests just fade away; finished ones are paid
	_pay_finished("Tally sent your request sparkles home with you!")
	list.clear()
	changed.emit()


# --- Tally and the board: what they say ---------------------------------------
func talk(talker: Node3D) -> void:
	Dialogue.say(talker, CLERK, lines(talker), "tally")


func lines(talker: Node3D = null) -> Array:
	if not is_live():
		return ["(Tally taps the empty clipboard.) Nothing tonight yet, {player}! New requests go up every Shift."]
	var out: Array = []
	var paid := turn_in(talker)
	if paid > 0:
		out.append("Ooh, {player}, you did it! Tick, tick, tick! Here's ✦ %d, all yours." % paid)
		if ready_to_turn_in().is_empty() and list.all(func(r: Dictionary) -> bool: return r.paid):
			out.append("That's every request tonight! Everyone in Galaxity is talking about {them}.")
			return out
	else:
		out.append("Hello, {player}! Tally's the name, requests are my game. Here's who needs a hand tonight:")
	for r in list:
		if not r.paid:
			var extra := progress_text(r)
			out.append("%s, for ✦ %d.%s" % [text_of(r), int(r.sparkles), (" (%s)" % extra.capitalize()) if extra != "" else ""])
	out.append("No rush, and no worries if {they} can't do them all. Whatever's left just fades at the end of the Shift.")
	return out


# -----------------------------------------------------------------------------
# Hooking up to each scene: the skater's combos, the board and Tally in town, parcels on Earth
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_hook_skater.call_deferred()
	if scene.scene_file_path == TOWN and scene.get_node_or_null("Request Board") == null:
		_place_board(scene)
	elif scene.scene_file_path == EARTH:
		_place_parcels.call_deferred(scene)


func _hook_skater() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var skate = player.get("skate") if player else null
	if skate == null or skate.get("tricks") == null:
		return
	var tricks: Object = skate.tricks
	if tricks == _hooked_tricks:
		return
	_hooked_tricks = tricks
	tricks.connect("banked", _on_banked)


func _place_board(scene: Node) -> void:
	# The board stands at the edge of the Market Square between the Records stall and the Town Hall path, mirroring
	# Rex's noticeboard on the other side (tools/build_town.gd, NOTICEBOARD_ANGLE), facing the fountain. Tally walks
	# a ring round the fountain between the benches and the stalls. They're added here rather than built into the
	# town scene, so the board can change without rebuilding the town.
	var square := scene.get_node_or_null("Market Square") as Node3D
	if square == null:
		return
	var a := deg_to_rad(250.0)
	var board := (load("res://scripts/request_board.gd") as GDScript).new() as Node3D
	board.name = "Request Board"
	scene.add_child(board)
	board.global_position = square.global_position + Vector3(cos(a) * 13.0, 0.15, sin(a) * 13.0)
	board.rotation.y = atan2(-cos(a), -sin(a))
	var alien := (load("res://scripts/request_alien.gd") as GDScript).new() as Node3D
	alien.name = "Tally"
	alien.set("centre", square.global_position + Vector3(0, 0.15, 0))
	scene.add_child(alien)


func _place_parcels(scene: Node) -> void:
	# Earth gifts wait outside their building, in front of the door that faces the town green
	if not is_live():
		return
	for g in EARTH_GIFTS:
		if not wants_parcel(str(g[0])) or scene.get_node_or_null("Parcel " + str(g[0])) != null:
			continue
		var building := scene.get_node_or_null(str(g[2])) as Node3D
		if building == null:
			continue
		var front := building.global_transform.basis.z.normalized()
		var at := building.global_position + front * 6.5
		var parcel := (load("res://scripts/request_parcel.gd") as GDScript).new() as Node3D
		parcel.name = "Parcel " + str(g[0])
		parcel.set("item_id", str(g[0]))
		scene.add_child(parcel)
		parcel.global_position = at
		parcel.call("settle")


# -----------------------------------------------------------------------------
# Saving (scripts/game.gd keeps this in save.json)
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"list": list.duplicate(true), "rolled_visit": rolled_visit, "nights": nights, "turned_in": turned_in}


func load_data(data: Dictionary) -> void:
	reset()
	rolled_visit = int(data.get("rolled_visit", 0))
	nights = int(data.get("nights", 0))
	turned_in = int(data.get("turned_in", 0))
	var saved = data.get("list", [])
	if saved is Array:
		for r in saved:
			if r is Dictionary and KINDS.has(str(r.get("kind", ""))):
				var copy: Dictionary = r.duplicate(true)
				copy.progress = float(copy.get("progress", 0.0))
				copy.goal = int(copy.get("goal", 1))
				copy.sparkles = int(copy.get("sparkles", 0))
				copy.done = bool(copy.get("done", false))
				copy.paid = bool(copy.get("paid", false))
				if copy.has("carrying"):
					copy.carrying = bool(copy.carrying)
				list.append(copy)
	changed.emit()


func reset() -> void:
	list.clear()
	rolled_visit = 0
	nights = 0
	turned_in = 0
