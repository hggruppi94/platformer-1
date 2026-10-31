extends Node

# Autoload "Nights": a reason to come back every night (plan prompt F4). Each Galaxity visit after The First Night
# shows off something new: a friend waiting by the portal, a place, a gadget, a race or a skate goal. Nothing is ever
# locked behind a grind: a night's things are spotlighted ("Night 2! Pip's waiting for you by the portal..." when you
# land, a short skippable quest with stars on the map, a line on the Goals page), and each night puts out one or two
# schematics (scripts/schematics.gd): the real unlocks, for Dash's gadgets and the new rides at Zippy's Tune-Up.
#
# The whole 7-night plan is in /mnt/project-files/roadmap/galaxity-plan.md (F4). Nights 1 and 2 are built; the rest
# wait for Hayden to look at the plan. A night is its own quest file (quests/night_<n>.json), started by the flag
# "night_<n>", which is set the first time you land in Galaxity on that night.
#
# The Goals page (the Tab menu, between Quests and Map: scripts/player_menu.gd) reads goals(): tonight's spotlight
# and requests, the next thing to aim for in watches, races, gadgets and skate goals, and a teaser for tomorrow.
# Everything here is read from the systems that already exist (Quests, Requests, Watches, Races, Arsenal, Shop, the
# Skate Park's goals, Coach Rook's lesson), so it needs nothing new in the save: progress is Dialogue flags.

const TOWN := "res://scenes/town/town.tscn"
# Night 1 is The First Night (quests/first_night.json, scripts/first_night.gd).
const NIGHTS := [
	{"n": 1, "quest": "first_night", "title": "The First Night",
		"new": "the Market, the Star Popper, the Skate Park, Tally's board, the Lake Loop and the Gloop King"},
	{"n": 2, "quest": "night_2", "title": "Pip's Lamps",
		"new": "Pip's waiting by the portal, the Fizz Flinger's schematic, and S-K-A-T-E letters in the Skate Park",
		"arrive": "Night 2! New tonight: Pip's waiting for you by the portal, and there's a schematic glowing on the promenade.",
		"tease": "Pip has something to show you by the boardwalk..."},
]

var _told_visit := -1                       # the visit this session already said "New tonight" for


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	Shop.opened.connect(_on_shop)


# -----------------------------------------------------------------------------
# Which night it is
# -----------------------------------------------------------------------------
func night() -> int:
	# Night 1 is the first Galaxity visit, night 2 the second... (the request board counts the visits it's put up)
	return maxi(Requests.nights, 1)


func info(n: int) -> Dictionary:
	for d in NIGHTS:
		if int(d.n) == n:
			return d
	return {}


func current() -> Dictionary:
	# The night whose spotlight is on: the newest one started and not done yet, else {}
	for i in range(NIGHTS.size() - 1, -1, -1):
		var q := str(NIGHTS[i].quest)
		if Quests.is_started(q) and not Quests.is_done(q):
			return NIGHTS[i]
	return {}


func next_night() -> Dictionary:
	# The first night whose quest hasn't started (what "Tomorrow night" teases)
	for d in NIGHTS:
		if not Quests.is_started(str(d.quest)) and not Quests.is_done(str(d.quest)):
			return d
	return {}


func _on_scene_changed() -> void:
	var s := get_tree().current_scene
	if s == null or s.scene_file_path != TOWN or not Clock.in_shift():
		return
	# Landing in Galaxity after The First Night starts night 2's spotlight (the First Night ends at home on Earth, so
	# that's always a new visit). An old save that never had the First Night is offered that first (by Nina, or the
	# Quests sheet's button), never forced, so the nights follow on from it there too.
	var visit := Requests.visit_day()
	if not Dialogue.flags.has("night_2") and Quests.is_done(FirstNight.ID):
		Dialogue.set_flag("night_2")
	var c := current()
	if not c.is_empty() and c.has("arrive") and _told_visit != visit:
		_told_visit = visit
		get_tree().create_timer(3.0).timeout.connect(func() -> void: Game.message(str(c.arrive)))


# -----------------------------------------------------------------------------
# Night 2's little helpers (the rest of it is quests/night_2.json and Pip's lines in dialogue/pip.json)
# -----------------------------------------------------------------------------
func _step(quest_id: String) -> String:
	return str(Quests.current_step(quest_id).get("id", "")) if Quests.is_started(quest_id) else ""


func _on_shop(stall: String) -> void:
	if stall == "Gadget" and _step("night_2") == "explore" and Schematics.is_found("fizz"):
		Dialogue.set_flag("n2_fizz")


func _check_letters() -> void:
	if _step("night_2") != "explore" or Dialogue.flags.has("n2_letter"):
		return
	for l in load("res://scripts/skate_goals.gd").LETTERS:
		if Dialogue.flags.has("skate_letter_" + l):
			Dialogue.set_flag("n2_letter")
			return


func _process(_delta: float) -> void:
	# A letter picked up doesn't move a quest on by itself, so look now and then while night 2's list is up
	if Engine.get_process_frames() % 30 == 0:
		_check_letters()


# -----------------------------------------------------------------------------
# The Goals page
# -----------------------------------------------------------------------------
func goals() -> Array:
	# [[heading, [line, ...]], ...] for the Goals sheet (and tools/test_nights.gd). Lines may use BBCode colours.
	var out := []
	var tonight: Array[String] = []
	var c := current()
	if not c.is_empty():
		var q := Quests.quest(str(c.quest))
		var st := _step(str(c.quest))
		tonight.append("[b]Night %d: %s[/b]" % [int(c.n), str(c.title)])
		for s in q.get("steps", []):
			if str(s.id) == st:
				tonight.append(Dialogue._fill(str(s.text)))
	else:
		tonight.append("[b]Night %d[/b]" % night())
	if Requests.is_live():
		for r in Requests.list:
			tonight.append("%s %s  [color=#f5e6a3]✦ %d[/color]" % ["✓" if r.done else "○", Requests.text_of(r), int(r.sparkles)])
	elif not Clock.in_shift():
		tonight.append("Tally's board puts up three new requests every time you visit Galaxity.")
	out.append(["Tonight", tonight])

	var aim: Array[String] = []
	var w := _watch_goal()
	if w != "":
		aim.append(w)
	var r := _race_goal()
	if r != "":
		aim.append(r)
	var g := _gadget_goal()
	if g != "":
		aim.append(g)
	var rd := _ride_goal()
	if rd != "":
		aim.append(rd)
	var s := _skate_goal()
	if s != "":
		aim.append(s)
	if aim.is_empty():
		aim.append("You've done everything there is so far. Wow! Hayden's making more.")
	out.append(["Next to aim for", aim])

	var tease := str(next_night().get("tease", ""))         # each night's own teaser, shown the night before
	out.append(["Tomorrow night", [tease if tease != "" else "Every night in Galaxity there's something new to find."]])
	return out


func _watch_goal() -> String:
	var nr: Dictionary = Watches.next_reward()
	if nr.is_empty():
		return ""
	var left := int(nr.at) - Watches.given_count()
	var pocket := Watches.to_give().size()
	var t := "Lost watches: give Dash %d more for %s (%d of %d given)" % [left, str(nr.text), Watches.given_count(),
		Watches.WATCHES.size()]
	if pocket > 0:
		t += ". You've got %d in your pocket for him!" % pocket
	return t


func _race_goal() -> String:
	for id in Races.TRACKS:
		if Races.unlocked(id) and not Races.finished_once.has(id):
			var t: Dictionary = Races.TRACKS[id]
			var who := str(t.get("starter", {}).get("name", "the starter"))
			return "Races: try the %s (talk to %s)" % [str(t.name), who] if not t.get("sky", false) \
				else "Races: fly the mothership through the Sky Rings' start ring"
	for id in Races.TRACKS:
		if not Races.unlocked(id):
			var t: Dictionary = Races.TRACKS[id]
			var after: Dictionary = Races.TRACKS.get(str(t.get("after", "")), {})
			return "Races: finish the %s to open the %s" % [str(after.get("name", "last race")), str(t.name)]
	return "Races: every track's open. Can you win them all?"


func _gadget_goal() -> String:
	# A gadget she can buy now (its schematic's found), else the next schematic to look for, else growing the one out
	var cheapest := {}
	for id in Shop.items:
		var it: Dictionary = Shop.items[id]
		var g := str(it.get("gadget", ""))
		if str(it.get("kind", "")) == "gadget" and not Arsenal.owns(g) and Schematics.gadget_unlocked(g):
			if cheapest.is_empty() or int(it.price) < int(cheapest.price):
				cheapest = it
	if not cheapest.is_empty():
		var have := Game.sparkles
		return "Gadgets: the %s at Dash's stall, ✦ %d%s" % [str(cheapest.name), int(cheapest.price),
			" (you can afford it!)" if have >= int(cheapest.price) else " (you have %d)" % have]
	var sch := Schematics.next_hint()
	if not sch.is_empty():
		return "Schematic: find the %s's. %s" % [Schematics.thing_name(sch), str(sch.hint)]
	var id := str(Arsenal.current)
	if Arsenal.level(id) < Arsenal.MAX_LEVEL:
		var need: int = Arsenal.LEVEL_XP[Arsenal.level(id)] - int(Arsenal.xp.get(id, 0))
		return "Gadgets: %d more pops with the %s and it grows to V%d" % [maxi(need, 1), Arsenal.gadget_name(id),
			Arsenal.level(id) + 1]
	return ""


func _ride_goal() -> String:
	# A ride with its schematic found but not built yet, at Zippy's Tune-Up
	for r in Rides.HERO_ORDER:
		var item: Dictionary = Shop.items.get("ride_" + str(r), {})
		if not item.is_empty() and Schematics.ride_unlocked(str(r)) and not Schematics.owns_ride(str(r)):
			return "Rides: Zippy can build you the %s at the Tune-Up, ✦ %d" % [str(item.name), int(item.price)]
	return ""


func _skate_goal() -> String:
	if not Game.has_item("skateboard"):
		return "Skating: pick up the skateboard in the middle of the Skate Park"
	if not SkateLesson.is_done():
		var done := 0
		for st in SkateLesson.STEPS:
			done += 1 if Dialogue.flags.has("skate_lesson_" + st.id) else 0
		return "Skating: finish Coach Rook's lesson (%d of %d steps)" % [done, SkateLesson.STEPS.size()]
	var G := load("res://scripts/skate_goals.gd")
	for goal in G.GOALS:
		if not Dialogue.flags.has("skate_goal_" + goal.id):
			return "Skate Park goal: %s  [color=#f5e6a3]✦ %d[/color]" % [str(goal.text), int(goal.sparkles)]
	return ""
