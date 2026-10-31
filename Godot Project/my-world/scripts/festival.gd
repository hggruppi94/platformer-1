extends Node

# Autoload "Festival": the Autumn Festival on Earth's town green, every Saturday evening from 5 to 10 PM (Earth's
# clock: Clock.weekday()). While it's on, scripts/festival_green.gd puts it up round the gazebo: stalls with treats and
# cider, the pie contest table, a barrel to bob for apples, the lantern stall, hay bales, strings of paper lanterns, a
# banner, and the hayride (a little tractor driven by a friendly scarecrow, pulling a hay wagon round the green).
# At 9 PM everyone lets a lantern go and they float up over the town. The people of the town come too: a routine can
# have a "festival" list of blocks that takes over while it's on (scripts/routine.gd), so Poppy runs the treats stall,
# Gus the cider cart, Dottie judges the pies, Hank minds the apple barrel, Miss Marigold hands out lanterns and
# Barnaby plays on the gazebo.
#
# Things to do, each paying sparkles once a festival (and fine to do again just for fun):
# - The pie contest: buy a contest pie at the bakery (shop/items.json, kind "contest_pie", sold here through
#   Shop.register_kind) and take it to Dottie, the judge (her "do": "Festival.judge_pie" in dialogue/dottie.json).
# - Bobbing for apples: three goes at biting at the right moment (scripts/apple_bobbing.gd).
# - The hayride: hop on at its stop by the Maple Inn for a lap of the green.
# - A lantern from Miss Marigold's stall, to let go with everyone else's at nine.
# Saved as "festival" (scripts/game.gd).

signal changed

const EARTH := "res://scenes/earth/earth.tscn"
const DAY := "Saturday"
const START := 17 * 60.0
const END := 22 * 60.0
const LANTERNS := 21 * 60.0
const PIE_PRIZES := [12, 8, 5]                  # sparkles for 1st, 2nd and 3rd
const APPLE_PRIZE := 1                          # sparkles an apple, plus a bonus for all three
const APPLE_BONUS := 3
const LANTERN_PRIZE := 2

var pie_day := 0                # the Earth day of the last festival the player's pie was judged at
var ribbons := [0, 0, 0]        # blue, red and yellow ribbons won
var apples_day := 0             # the last festival the apple prize was paid at
var apples_best := 0
var lantern_day := 0            # the festival the player got a lantern at
var lanterns_let_go := 0
var hayrides := 0

var _check := 0.0
var _told_day := 0
var _was_on := false
var _bobbing: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Shop.register_kind("contest_pie", {"can_buy": _pie_can_buy, "buy": _pie_buy})


func _pie_can_buy(_it: Dictionary) -> String:
	return "You've got one to enter" if Game.has_item("contest_pie") else ""


func _pie_buy(_it: Dictionary) -> String:
	Game.items.append("contest_pie")
	return "A golden pumpkin pie, boxed up with a bow! Take it to the judge at the Autumn Festival (Saturday, 5 to 10 PM)."


# -----------------------------------------------------------------------------
# When
# -----------------------------------------------------------------------------
func is_festival_day() -> bool:
	return Clock.weekday() == DAY and not Clock.in_shift()


func is_on() -> bool:
	return is_festival_day() and Clock.earth_minutes >= START and Clock.earth_minutes < END


func lanterns_up() -> bool:
	return is_on() and Clock.earth_minutes >= LANTERNS


func days_until() -> int:
	# 0 on a Saturday, 1 on a Friday...
	for k in 7:
		if Clock.weekday(Clock.earth_day() + k) == DAY:
			return k
	return 0


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var scene := get_tree().current_scene
	var on := is_on()
	if scene and scene.scene_file_path == EARTH and scene.is_inside_tree():
		var green := scene.get_node_or_null("Autumn Festival")
		if on and green == null:
			green = (load("res://scripts/festival_green.gd") as GDScript).new() as Node3D
			green.name = "Autumn Festival"
			scene.add_child(green)
		elif not on and green != null:
			green.queue_free()
		if Clock.on_earth:
			_announce(on)
	if on != _was_on:
		_was_on = on
		changed.emit()


func _announce(on: bool) -> void:
	# The morning of a festival, and when it starts
	var today := Clock.earth_day()
	if on and _told_day != -today:
		_told_day = -today
		Game.message("The Autumn Festival is on the green till 10 PM! Treats, the pie contest, apple bobbing and the hayride.")
	elif is_festival_day() and not on and Clock.earth_minutes < START and Clock.hour() >= 6 and _told_day != today and _told_day != -today:
		_told_day = today
		Game.message("It's Saturday: the Autumn Festival is on the green this evening, 5 to 10 PM!")


func log_lines() -> Array[String]:
	var out: Array[String] = []
	if is_on():
		out.append("[b]The Autumn Festival[/b] is on the green till 10 PM")
		out.append("  %s Enter a pie in the contest (contest pies at the bakery)" % _tick(pie_day == Clock.earth_day()))
		out.append("  %s Bob for apples at the barrel" % _tick(apples_day == Clock.earth_day()))
		out.append("  %s Get a lantern for nine o'clock" % _tick(lantern_day == Clock.earth_day()))
		out.append("  ( ) Ride the hayride round the green (it stops by the Maple Inn)")
		out.append("")
	elif is_festival_day() and Clock.earth_minutes < START:
		out.append("[b]Tonight:[/b] the Autumn Festival on the green, 5 to 10 PM")
		out.append("")
	return out


static func _tick(done: bool) -> String:
	return "[color=#b8f5b8](done)[/color]" if done else "( )"


# -----------------------------------------------------------------------------
# The pie contest (Dottie judges: dialogue/dottie.json has "do": "Festival.judge_pie")
# -----------------------------------------------------------------------------
func judge_pie() -> Array:
	var today := Clock.earth_day()
	if not is_on():
		return []
	if pie_day == today:
		return ["Your pie's already got its ribbon, sweetheart! Go and enjoy the festival."]
	if not Game.has_item("contest_pie"):
		return ["Have you got a pie for the contest? Poppy sells contest pies at the bakery on Main Street. Hurry, the judging's tonight!"]
	Game.items.erase("contest_pie")
	pie_day = today
	# The very first pie wins; after that the judges are a little harder to please (the same answer all evening)
	var place := 0 if ribbons == [0, 0, 0] else int(hash("pie:%d" % today) % 3)
	ribbons[place] += 1
	Game.add_sparkles(PIE_PRIZES[place], "The pie contest!")
	Audio.play("level_up", -3.0, 0.0)
	changed.emit()
	Game.save_game()
	var verdict := [
		["(Dottie takes a bite. Her eyes go wide. She takes another bite.)", "Oh. Oh my. That's the best pie I've had since 1987!",
			"FIRST PRIZE! A big blue ribbon for {player}! Oh, wait till Gus hears. He'll be so cross. Ha!"],
		["(Dottie takes a bite and nods slowly.)", "Lovely crust. Lovely! A smidge more cinnamon next time, sweetheart.",
			"SECOND PRIZE! A red ribbon for {player}! Poppy's lemon meringue just pipped you."],
		["(Dottie takes a bite. Then a sip of cider. Then another bite.)", "Hm! Interesting! Very... autumnal!",
			"THIRD PRIZE! A yellow ribbon, and everybody gets a ribbon for trying. That's the rule. I made it."],
	]
	var out: Array = verdict[place].duplicate()
	out.append("(✦ %d sparkles for the pie contest!)" % PIE_PRIZES[place])
	return out


# -----------------------------------------------------------------------------
# The festival's own spots (scripts/request_spot.gd with jobs = Festival): Interact comes here, by the spot's name
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	match str(spot.name):
		"Apple Barrel":
			start_bobbing()
		"Lantern Stall":
			Dialogue.say(spot, "Miss Marigold", lantern_lines(), "festival_lanterns")
		"Hayride":
			var wagon := spot.get_parent()
			if wagon and wagon.has_method("hop_on"):
				wagon.call("hop_on")


func lantern_lines() -> Array:
	var today := Clock.earth_day()
	if lanterns_up():
		return ["Oh, the lanterns have all gone up! Aren't they beautiful? Like little stars going home."]
	if lantern_day == today:
		return ["You've got your lantern! Keep it safe. At nine o'clock, everyone lets theirs go together."]
	lantern_day = today
	changed.emit()
	return ["A lantern for you, {player}! Paper and string and a little candle, made by the library's craft club.",
		"At nine o'clock we all let them go together. My grandmother said they carry wishes up to the stars.",
		"(You got a paper lantern. Be on the green at 9 PM!)"]


func let_lanterns_go() -> void:
	# scripts/festival_green.gd at nine: if the player has a lantern and is there, theirs goes up too
	if lantern_day != Clock.earth_day() or not Clock.on_earth:
		return
	lantern_day = -lantern_day                  # (let go: no second one tonight)
	lanterns_let_go += 1
	Game.add_sparkles(LANTERN_PRIZE, "You let your lantern go!")
	Game.message("Your lantern floats up with all the others, higher and higher, over the old oak.")
	changed.emit()


# --- Bobbing for apples ----------------------------------------------------------
func start_bobbing() -> void:
	if is_instance_valid(_bobbing):
		return
	if Game.riding:
		Game.message("Hop off your board to bob for apples!")
		return
	_bobbing = (load("res://scripts/apple_bobbing.gd") as GDScript).new()
	_bobbing.name = "Apple Bobbing"
	get_tree().root.add_child(_bobbing)


func bobbing() -> Node:
	return _bobbing if is_instance_valid(_bobbing) else null


func apples_done(apples: int) -> String:
	# scripts/apple_bobbing.gd when the three goes are over; what it says at the end
	apples_best = maxi(apples_best, apples)
	var today := Clock.earth_day()
	var word := "No apples, just a very wet face!" if apples == 0 else ("%d apple%s!" % [apples, "" if apples == 1 else "s"])
	if apples_day == today or apples == 0:
		changed.emit()
		return word
	apples_day = today
	var prize := apples * APPLE_PRIZE + (APPLE_BONUS if apples == 3 else 0)
	Game.add_sparkles(prize, "Apple bobbing!")
	changed.emit()
	return "%s ✦ %d sparkles!" % [word, prize]


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"pie_day": pie_day, "ribbons": ribbons.duplicate(), "apples_day": apples_day, "apples_best": apples_best,
		"lantern_day": lantern_day, "lanterns_let_go": lanterns_let_go, "hayrides": hayrides}


func load_data(data: Dictionary) -> void:
	reset()
	pie_day = int(data.get("pie_day", 0))
	var r = data.get("ribbons", [])
	if r is Array and r.size() == 3:
		ribbons = [int(r[0]), int(r[1]), int(r[2])]
	apples_day = int(data.get("apples_day", 0))
	apples_best = int(data.get("apples_best", 0))
	lantern_day = int(data.get("lantern_day", 0))
	lanterns_let_go = int(data.get("lanterns_let_go", 0))
	hayrides = int(data.get("hayrides", 0))
	changed.emit()


func reset() -> void:
	pie_day = 0
	ribbons = [0, 0, 0]
	apples_day = 0
	apples_best = 0
	lantern_day = 0
	lanterns_let_go = 0
	hayrides = 0
