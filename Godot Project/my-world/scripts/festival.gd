extends Node

# Autoload "Festival": a fair on Earth's town green every Saturday evening (Earth's calendar: Clock.weekday()), a
# different one each season (FAIRS): the Autumn Festival, the Frost Fair, the Spring Fair and the Summer Fair. And
# Hallow's Eve on the last day of autumn: trick-or-treating door to door on Maple Lane (scripts/hallows_eve.gd).
# Below, "the festival" means whichever fair's on. While it's on, scripts/festival_green.gd puts it up round the gazebo: stalls with treats and
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
const SEASON := "autumn"
const TODAY := -(1 << 40)                       # (the same as Clock.TODAY: a day left out means today)
const START := 17 * 60.0                       # the Autumn Festival's times (each season's fair has its own: FAIRS)
const END := 22 * 60.0
const LANTERNS := 21 * 60.0
# Every Saturday there's a fair on the green, a different one each season (Earth's calendar: scripts/clock.gd). Same
# stalls, same people and the same things to do, dressed for the season: the baking contest's bake, the barrel game
# (bobbing for apples, ice fishing through a hole in the ice, hooking a duck), the ride, the banner and the treats
# (shop/items.json "season").
const FAIRS := {
	"autumn": {"name": "Autumn Festival", "start": 17, "end": 22, "lanterns": 21, "bake": "pumpkin pie",
		"game": "Bob for apples", "verb": "bob for apples", "catch": "apple", "ride": "hayride", "cart": "Gus's Cider Cart"},
	"winter": {"name": "Frost Fair", "start": 16, "end": 21, "lanterns": 20, "bake": "gingerbread house",
		"game": "Ice fishing", "verb": "go ice fishing", "catch": "fish", "ride": "sleigh ride", "cart": "Gus's Cocoa Cart"},
	"spring": {"name": "Spring Fair", "start": 17, "end": 22, "lanterns": 21, "bake": "strawberry tart",
		"game": "Hook a duck", "verb": "hook a duck", "catch": "duck", "ride": "hayride", "cart": "Gus's Lemonade Cart"},
	"summer": {"name": "Summer Fair", "start": 18, "end": 23, "lanterns": 22, "bake": "blueberry pie",
		"game": "Bob for apples", "verb": "bob for apples", "catch": "apple", "ride": "hayride", "cart": "Gus's Lemonade Cart"},
}
# Hallow's Eve: the last day of autumn, trick-or-treating door to door on Maple Lane (scripts/hallows_eve.gd)
const HALLOWS := {"season": "autumn", "date": 28, "start": 17 * 60.0, "end": 21 * 60.0}
const TREAT_PRIZE := 1                          # sparkles a door
const TREAT_BONUS := 6                          # ...and for every door on the lane
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
var treats_day := 0             # the Hallow's Eve the doors below were knocked on
var treat_doors: Array = []     # the doors that gave a treat that night
var hallows_bonus_day := 0

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
	var f := fair()
	return "A %s, boxed up with a bow! Take it to the judge at the %s (Saturday, %s)." % [f.bake, f.name, hours_text()]


# -----------------------------------------------------------------------------
# When
# -----------------------------------------------------------------------------
func is_festival_day(on_day := TODAY) -> bool:
	# Every Saturday: that season's fair (Earth's calendar: scripts/clock.gd)
	return Clock.weekday(on_day) == DAY and (on_day != TODAY or not Clock.in_shift())


func fair(on_day := TODAY) -> Dictionary:
	# The season's fair: its name, times (hours), bake, barrel game and ride
	return FAIRS.get(Clock.season(on_day), FAIRS.autumn)


func fair_name(on_day := TODAY) -> String:
	return str(fair(on_day).name)


func start_time() -> float:
	return float(fair().start) * 60.0


func end_time() -> float:
	return float(fair().end) * 60.0


func lantern_time() -> float:
	return float(fair().lanterns) * 60.0


func hours_text(on_day := TODAY) -> String:
	# "5 to 10 PM"
	var f := fair(on_day)
	return "%d to %d PM" % [int(f.start) - 12, int(f.end) - 12]


func is_on() -> bool:
	return is_festival_day() and Clock.earth_minutes >= start_time() and Clock.earth_minutes < end_time()


func lanterns_up() -> bool:
	return is_on() and Clock.earth_minutes >= lantern_time()


func is_hallows_eve(on_day := TODAY) -> bool:
	return Clock.season(on_day) == HALLOWS.season and Clock.season_day(on_day) == HALLOWS.date \
		and (on_day != TODAY or not Clock.in_shift())


func hallows_on() -> bool:
	return is_hallows_eve() and Clock.earth_minutes >= HALLOWS.start and Clock.earth_minutes < HALLOWS.end


func event_on() -> String:
	# What's on in town right now, for the routines' blocks (scripts/routine.gd): "festival" (any fair), "hallows", or ""
	if is_on():
		return "festival"
	if hallows_on():
		return "hallows"
	return ""


func days_until() -> int:
	# 0 on a festival Saturday, 1 on the Friday before... (-1 if there's none until next autumn: a season's 28 days)
	for k in Clock.YEAR_DAYS:
		if is_festival_day(Clock.earth_day() + k):
			return k
	return -1


func events_on(on_day: int) -> Array[String]:
	# What's on in Stars Hollow that day, for the Calendar page (scripts/player_menu.gd)
	var out: Array[String] = []
	if is_hallows_eve(on_day):
		out.append("Hallow's Eve, trick-or-treat 5-9 PM")
	if Clock.season_day(on_day) == 1:
		out.append("First day of %s" % Clock.season_name(on_day))
	if is_festival_day(on_day):
		out.append("%s, %s" % [fair_name(on_day), hours_text(on_day).replace(" to ", "-")])
	return out


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var scene := get_tree().current_scene
	var on := is_on()
	if scene and scene.scene_file_path == EARTH and scene.is_inside_tree():
		# (the fair's node keeps the name "Autumn Festival" whatever the season, so older tests and tools find it)
		var green := scene.get_node_or_null("Autumn Festival")
		if on and green != null and green.get_meta("season", "") != Clock.season():
			# (the season changed while a fair was up, as when time jumps from one Saturday to another: it's
			# dressed for its season when it's made, so make it again; taken out first so the new one gets the name)
			scene.remove_child(green)
			green.queue_free()
			green = null
		if on and green == null:
			green = (load("res://scripts/festival_green.gd") as GDScript).new() as Node3D
			green.name = "Autumn Festival"
			green.set_meta("season", Clock.season())
			scene.add_child(green)
		elif not on and green != null:
			green.queue_free()
		var lane := scene.get_node_or_null("Hallows Eve")
		var spooky := hallows_on()
		if spooky and lane == null:
			lane = (load("res://scripts/hallows_eve.gd") as GDScript).new() as Node3D
			lane.name = "Hallows Eve"
			scene.add_child(lane)
		elif not spooky and lane != null:
			lane.queue_free()
		if Clock.on_earth:
			_announce(on)
			_announce_hallows(spooky)
	if on != _was_on:
		_was_on = on
		changed.emit()


func _announce(on: bool) -> void:
	# The morning of a festival, and when it starts
	var today := Clock.earth_day()
	var f := fair()
	if on and _told_day != -today:
		_told_day = -today
		Game.message("The %s is on the green till %d PM! Treats, the baking contest, %s and the %s." % [f.name,
			int(f.end) - 12, str(f.game).to_lower(), f.ride])
	elif is_festival_day() and not on and Clock.earth_minutes < start_time() and Clock.hour() >= 6 and _told_day != today and _told_day != -today:
		_told_day = today
		Game.message("It's Saturday: the %s is on the green this evening, %s!" % [f.name, hours_text()])


var _told_hallows := 0


func _announce_hallows(on: bool) -> void:
	var today := Clock.earth_day()
	if on and _told_hallows != -today:
		_told_hallows = -today
		Game.message("Happy Hallow's Eve! The lanterns are lit on Maple Lane: knock on the doors for trick-or-treat till 9 PM.")
	elif is_hallows_eve() and not on and Clock.earth_minutes < HALLOWS.start and Clock.hour() >= 6 and _told_hallows != today \
			and _told_hallows != -today:
		_told_hallows = today
		Game.message("It's Hallow's Eve! Trick-or-treat on Maple Lane from 5 PM.")


func log_lines() -> Array[String]:
	var out: Array[String] = []
	var f := fair()
	if is_on():
		out.append("[b]The %s[/b] is on the green till %d PM" % [f.name, int(f.end) - 12])
		out.append("  %s Enter a %s in the baking contest (contest bakes at the bakery)" % [_tick(pie_day == Clock.earth_day()), f.bake])
		out.append("  %s %s at the barrel" % [_tick(apples_day == Clock.earth_day()), f.game])
		out.append("  %s Get a lantern for %d o'clock" % [_tick(lantern_day == Clock.earth_day()), int(f.lanterns) - 12])
		out.append("  ( ) Ride the %s round the green (it stops by the Maple Inn)" % f.ride)
		out.append("")
	elif is_festival_day() and Clock.earth_minutes < start_time():
		out.append("[b]Tonight:[/b] the %s on the green, %s" % [f.name, hours_text()])
		out.append("")
	if hallows_on():
		var left := HALLOWS_DOORS.size() - (treat_doors.size() if treats_day == Clock.earth_day() else 0)
		out.append("[b]Hallow's Eve![/b] Trick-or-treat on Maple Lane till 9 PM: %d door%s left to knock on" % [left, "" if left == 1 else "s"])
		out.append("")
	elif is_hallows_eve() and Clock.earth_minutes < HALLOWS.start:
		out.append("[b]Tonight:[/b] Hallow's Eve, trick-or-treat on Maple Lane from 5 PM")
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
	var bake := str(fair().bake)
	if pie_day == today:
		return ["Your %s's already got its ribbon, sweetheart! Go and enjoy the fair." % bake]
	if not Game.has_item("contest_pie"):
		return ["Have you got a %s for the baking contest? Poppy sells contest bakes at the bakery on Main Street. Hurry, the judging's tonight!" % bake]
	Game.items.erase("contest_pie")
	pie_day = today
	# The very first pie wins; after that the judges are a little harder to please (the same answer all evening)
	var place := 0 if ribbons == [0, 0, 0] else int(hash("pie:%d" % today) % 3)
	ribbons[place] += 1
	Game.add_sparkles(PIE_PRIZES[place], "The baking contest!")
	Audio.play("level_up", -3.0, 0.0)
	changed.emit()
	Game.save_game()
	var verdict := [
		["(Dottie takes a bite. Her eyes go wide. She takes another bite.)", "Oh. Oh my. That's the best %s I've had since 1987!" % bake,
			"FIRST PRIZE! A big blue ribbon for {player}! Oh, wait till Gus hears. He'll be so cross. Ha!"],
		["(Dottie takes a bite and nods slowly.)", "Lovely crust. Lovely! A smidge more cinnamon next time, sweetheart.",
			"SECOND PRIZE! A red ribbon for {player}! Poppy's lemon meringue just pipped you."],
		["(Dottie takes a bite. Then a sip of %s. Then another bite.)" % ("cocoa" if Clock.season() == "winter" else ("lemonade"
			if Clock.season() in ["spring", "summer"] else "cider")), "Hm! Interesting! Very... %s!" % {"autumn": "autumnal",
			"winter": "wintry", "spring": "springy", "summer": "summery"}.get(Clock.season(), "autumnal"),
			"THIRD PRIZE! A yellow ribbon, and everybody gets a ribbon for trying. That's the rule. I made it."],
	]
	var out: Array = verdict[place].duplicate()
	out.append("(✦ %d sparkles for the baking contest!)" % PIE_PRIZES[place])
	return out


# -----------------------------------------------------------------------------
# The festival's own spots (scripts/request_spot.gd with jobs = Festival): Interact comes here, by the spot's name
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	match str(spot.name):
		"Apple Barrel":
			start_bobbing()
		_ when str(spot.name).begins_with("Door "):
			knock(str(spot.name).trim_prefix("Door "))
		"Lantern Stall":
			Dialogue.say(spot, "Miss Marigold", lantern_lines(), "festival_lanterns")
		"Hayride":
			var wagon := spot.get_parent()
			if wagon and wagon.has_method("hop_on"):
				wagon.call("hop_on")


func _lantern_hour() -> String:
	return ["eight", "nine", "ten"][clampi(int(fair().lanterns) - 20, 0, 2)]


func lantern_lines() -> Array:
	var today := Clock.earth_day()
	if lanterns_up():
		return ["Oh, the lanterns have all gone up! Aren't they beautiful? Like little stars going home."]
	if lantern_day == today:
		return ["You've got your lantern! Keep it safe. At %s o'clock, everyone lets theirs go together." % _lantern_hour()]
	lantern_day = today
	changed.emit()
	return ["A lantern for you, {player}! Paper and string and a little candle, made by the library's craft club.",
		"At %s o'clock we all let them go together. My grandmother said they carry wishes up to the stars." % _lantern_hour(),
		"(You got a paper lantern. Be on the green at %d PM!)" % (int(fair().lanterns) - 12)]


func let_lanterns_go() -> void:
	# scripts/festival_green.gd at nine: if the player has a lantern and is there, theirs goes up too
	if lantern_day != Clock.earth_day() or not Clock.on_earth:
		return
	lantern_day = -lantern_day                  # (let go: no second one tonight)
	lanterns_let_go += 1
	Game.add_sparkles(LANTERN_PRIZE, "You let your lantern go!")
	Game.message("Your lantern floats up with all the others, higher and higher, over the old oak.")
	changed.emit()


# --- Hallow's Eve: trick-or-treat (scripts/hallows_eve.gd puts a lantern and a knock spot at each door) ------------
const HALLOWS_DOORS := {
	"palmer_house": ["Mr. Palmer", "(Mr. Palmer opens the door in a tall pointy hat.) Trick or... oh, I'm meant to say treat. Here. Don't tell anyone I'm fun."],
	"blastoff_door": ["Mrs. Blastoff", "Oh, look at you! Nina's out with Prue and Bruno somewhere. Have a toffee apple, and one for the road!"],
	"hollis_house": ["Miss Marigold", "Happy Hallow's Eve! A little bag of star-shaped biscuits, made at the library's craft club."],
	"quill_house": ["Barnaby", "(Barnaby plays a spooky chord on his banjo.) Ooooh! Here, have a lollipop. And a second spooky chord. Ooooh!"],
	"bramblewood_house": ["Hank", "Trick or treat, eh? I've got a treat. It's a carrot. ...Kidding! Chocolate coins. Don't tell Hank Jr."],
	"okafor_house": ["Mrs. Okafor", "Juniper's already been out three times in three different costumes. Take two, sweetheart!"],
	"pemberton_house": ["Mr. Pemberton", "Theo says knights don't trick-or-treat, they 'collect tribute'. Here's your tribute: a fudge square."],
	"larkspur_house": ["Ozzie's dad", "Ozzie ate half the bowl before we opened the door. Here's what's left: one big gummy worm!"],
	"home_1": ["Old Mrs. Fennimore", "Oh, a little monster! How frightening! Here's a peppermint. I've had it since last year. It's fine."],
	"home_3": ["The Pickwicks", "(The whole family answers in matching pumpkin jumpers.) HAPPY HALLOW'S EVE! Have a cupcake!"],
}


func knock(door: String) -> void:
	# Knock on a door on Hallow's Eve: a treat and a sparkle from each one, once, and a bonus for every door on the lane
	var spot := get_tree().current_scene.find_child("Door " + door, true, false) as Node3D if get_tree().current_scene else null
	Dialogue.say(spot, str(HALLOWS_DOORS.get(door, ["Neighbour", ""])[0]), treat_lines(door), "hallows_" + door)


func treat_lines(door: String) -> Array:
	var today := Clock.earth_day()
	if not hallows_on():
		return ["(The porch light's off. Nobody's answering.)"]
	if treats_day != today:
		treats_day = today
		treat_doors.clear()
	if door in treat_doors:
		return ["Back again? (They laugh.) I've seen that costume before! Go on, try the next house."]
	treat_doors.append(door)
	Game.add_sparkles(TREAT_PRIZE, "Trick or treat!")
	var out: Array = ["{player}: Trick or treat!", str(HALLOWS_DOORS.get(door, ["", "Here you go!"])[1])]
	out.append("(✦ %d sparkle. %d of %d doors on Maple Lane.)" % [TREAT_PRIZE, treat_doors.size(), HALLOWS_DOORS.size()])
	if treat_doors.size() == HALLOWS_DOORS.size() and hallows_bonus_day != today:
		hallows_bonus_day = today
		Game.add_sparkles(TREAT_BONUS, "Every door on Maple Lane!")
		out.append("(Your bucket's full! Every door on Maple Lane: ✦ %d bonus sparkles!)" % TREAT_BONUS)
	changed.emit()
	return out


func doors_knocked() -> int:
	return treat_doors.size() if treats_day == Clock.earth_day() else 0


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
	var catch := str(fair().catch)
	var nothing: String = {"apple": "No apples, just a very wet face!", "fish": "No fish, just very cold fingers!",
		"duck": "No ducks, but they all quacked at you!"}.get(catch, "None this time!")
	var word: String = nothing if apples == 0 else ("%d %s%s!" % [apples, catch, "" if apples == 1 or catch == "fish" else "s"])
	if apples_day == today or apples == 0:
		changed.emit()
		return word
	apples_day = today
	var prize := apples * APPLE_PRIZE + (APPLE_BONUS if apples == 3 else 0)
	Game.add_sparkles(prize, str(fair().game) + "!")
	changed.emit()
	return "%s ✦ %d sparkles!" % [word, prize]


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"pie_day": pie_day, "ribbons": ribbons.duplicate(), "apples_day": apples_day, "apples_best": apples_best,
		"lantern_day": lantern_day, "lanterns_let_go": lanterns_let_go, "hayrides": hayrides,
		"treats_day": treats_day, "treat_doors": treat_doors.duplicate(), "hallows_bonus_day": hallows_bonus_day}


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
	treats_day = int(data.get("treats_day", 0))
	var doors = data.get("treat_doors", [])
	treat_doors = (doors as Array).map(func(d) -> String: return str(d)) if doors is Array else []
	hallows_bonus_day = int(data.get("hallows_bonus_day", 0))
	changed.emit()


func reset() -> void:
	pie_day = 0
	ribbons = [0, 0, 0]
	apples_day = 0
	apples_best = 0
	lantern_day = 0
	lanterns_let_go = 0
	hayrides = 0
	treats_day = 0
	treat_doors = []
	hallows_bonus_day = 0
