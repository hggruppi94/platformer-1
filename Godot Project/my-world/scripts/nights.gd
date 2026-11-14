extends Node

# Autoload "Nights": a reason to come back every night (plan prompt F4). Each the Void visit after The First Night
# shows off something new: a friend waiting by the portal, a place, a gadget, a race or a skate goal. Nothing is ever
# locked behind a grind: a night's things are spotlighted ("Night 2! Pip's waiting for you by the portal..." when you
# land, a short skippable quest with stars on the map, a line on the Goals page), and each night puts out one or two
# schematics (scripts/schematics.gd): the real unlocks, for Dash's gadgets and the new rides at Zippy's Tune-Up.
#
# The whole 7-night plan is in /mnt/project-files/roadmap/galaxity-plan.md (F4), and all seven are built. A night is
# its own quest file (quests/night_<n>.json), started by the flag "night_<n>". Since Hayden's meeting order (11 Nov
# 2026: "I don't want to lock meeting people behind days spent in-game") they no longer wait for the next visit:
# each starts as soon as the story quest before it is done, with the friend you just helped sending you on
# (scripts/meetings.gd has the order). The ids still say "night", but nothing the player sees does.
#
# The Goals page (the Tab menu, between Quests and Map: scripts/player_menu.gd) reads goals(): tonight's spotlight
# and requests, the next thing to aim for in watches, races, gadgets and skate goals, and a teaser for tomorrow.
# Everything here is read from the systems that already exist (Quests, Requests, Watches, Races, Arsenal, Shop, the
# Skate Park's goals, Coach Bruno's lesson), so it needs nothing new in the save: progress is Dialogue flags.

const TOWN := "res://scenes/town/town.tscn"
# Night 1 is The First Night (quests/first_night.json, scripts/first_night.gd).
const NIGHTS := [
	{"n": 1, "quest": "first_night", "title": "The First Night",
		"new": "the Market and the Gloop King"},
	{"n": 2, "quest": "night_2", "title": "Pip's Lamps",
		"new": "Pip and the S-K-A-T-E letters",
		"tease": "Pip has something to show you..."},
	{"n": 3, "quest": "night_3", "title": "The Meadow in Bloom",
		"new": "Bramble and the south meadow",
		"tease": "Something's glowing in the south meadow..."},
	{"n": 4, "quest": "night_4", "title": "Stars Over Observatory Hill",
		"new": "Dash and the Observatory",
		"tease": "Dash wants to show you the stars!"},
	{"n": 5, "quest": "night_5", "title": "Up in the Mothership",
		"new": "the Astronaut and the mothership",
		"tease": "Something's floating up in the sky..."},
	{"n": 6, "quest": "night_6", "title": "Rex for Mayor",
		"new": "Rex and the castle school",
		"tease": "Rex is practising a speech..."},
	{"n": 7, "quest": "night_7", "title": "The Far Corners",
		"new": "Mr. Palmer and the far field",
		"tease": "Mr. Palmer wants a quiet word..."},
]
# Night 7: the far field behind the castle hill, and how close counts as having a look round it. (The flag's still
# "n7_giant" so old saves keep their tick, but nobody's out there yet: the Agent of Chaos only turns up after Rex and
# Dash try to swap back, scripts/chaos_giant.gd present(). Hayden's day 1 playtest, 11 Nov 2026.)
const FAR_FIELD := Vector2(116, -206)
const FAR_FIELD_NEAR := 30.0



func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	Races.finished.connect(_on_race_finished)


# -----------------------------------------------------------------------------
# Which night it is
# -----------------------------------------------------------------------------
func night() -> int:
	# Night 1 is the first Void visit, night 2 the second... (the request board counts the visits it's put up)
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
	# Landing in the Void after The First Night starts night 2's spotlight (the First Night ends at home on Earth, so
	# that's always a new visit). An old save that never had the First Night is offered that first (by Nina, or the
	# Quests sheet's button), never forced, so the nights follow on from it there too.
	# (the story quests start themselves now, as soon as the one before is done: scripts/meetings.gd)
	FirstNight.meetings.advance()


# -----------------------------------------------------------------------------
# Night 2's little helpers (the rest of it is quests/night_2.json and Pip's lines in dialogue/pip.json)
# -----------------------------------------------------------------------------
func _step(quest_id: String) -> String:
	return str(Quests.current_step(quest_id).get("id", "")) if Quests.is_started(quest_id) else ""


func _check_letters() -> void:
	if _step("night_2") != "explore" or Dialogue.flags.has("n2_letter"):
		return
	for l in load("res://scripts/skate_goals.gd").LETTERS:
		if Dialogue.flags.has("skate_letter_" + l):
			Dialogue.set_flag("n2_letter")
			return


func _process(_delta: float) -> void:
	# A letter picked up, a ride built or a place reached doesn't move a quest on by itself, so look now and then
	# while a night's list is up
	if Engine.get_process_frames() % 30 == 0:
		_check_letters()
		_check_later_nights()


# -----------------------------------------------------------------------------
# Nights 3 to 7: the things on their lists that aren't a flag already (schematics are "schematic_<id>")
# -----------------------------------------------------------------------------
func _check_later_nights() -> void:
	var s := get_tree().current_scene
	if s == null:
		return
	if _step("night_4") == "explore":
		if not Dialogue.flags.has("n4_observatory") and _near(s, "Observatory", 16.0):
			Dialogue.set_flag("n4_observatory")
		if not Dialogue.flags.has("n4_ride") and Schematics.rides_owned().size() > 1:
			Dialogue.set_flag("n4_ride")
	if _step("night_5") == "explore" and not Dialogue.flags.has("n5_fly"):
		for ship in get_tree().get_nodes_in_group("mothership"):
			if ship.has_method("is_piloted") and ship.is_piloted():
				Dialogue.set_flag("n5_fly")
	if _step("night_6") == "explore" and not Dialogue.flags.has("n6_school") \
			and s.scene_file_path == str(Schematics.SCENES.school):
		Dialogue.set_flag("n6_school")
	if _step("night_7") == "explore":
		if not Dialogue.flags.has("n7_giant") and s.scene_file_path == TOWN and _near_point(FAR_FIELD, FAR_FIELD_NEAR):
			Dialogue.set_flag("n7_giant")
			Game.message("The grass is pressed flat. Something BIG was here...")
		if not Dialogue.flags.has("n7_gate") and _near(s, "Scary World Gate", 10.0):
			Dialogue.set_flag("n7_gate")


func _on_race_finished(_track: String, _place: int) -> void:
	if _step("night_3") == "explore":
		Dialogue.set_flag("n3_race")


func _near(s: Node, node_name: String, metres: float) -> bool:
	var n := s.find_child(node_name, true, false) as Node3D
	return n != null and _near_node(n, metres)


func _near_point(at: Vector2, metres: float) -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and Vector2(p.global_position.x, p.global_position.z).distance_to(at) < metres


func _near_node(n: Node3D, metres: float) -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return false
	var a := Vector2(p.global_position.x, p.global_position.z)
	return a.distance_to(Vector2(n.global_position.x, n.global_position.z)) < metres


# -----------------------------------------------------------------------------
# The Goals page
# -----------------------------------------------------------------------------
func goals() -> Array:
	# [[heading, [line, ...]], ...] for the Goals sheet (and tools/test_nights.gd). Lines may use BBCode colours.
	var out := []
	var tonight: Array[String] = []
	var story: String = FirstNight.meetings.story_now()
	if story != "":
		var q := Quests.quest(story)
		var st := _step(story)
		tonight.append("[b]%s[/b]" % str(q.get("name", story)))
		for s in q.get("steps", []):
			if str(s.id) == st:
				tonight.append(Dialogue._fill(str(s.text)))
	if Requests.is_live():
		for r in Requests.list:
			tonight.append("%s %s  [color=#f5e6a3]✦ %d[/color]" % ["✓" if r.done else "○", Requests.text_of(r), int(r.sparkles)])
	elif not Clock.in_shift():
		tonight.append("New requests on Tally's board every visit!")
	if tonight.is_empty():
		tonight.append("Your friends always have something to do!")
	out.append(["Right now", tonight])

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
		aim.append("You did EVERYTHING! More soon!")
	out.append(["Next to aim for", aim])

	var tease := str(next_night().get("tease", ""))         # the next story quest's teaser
	out.append(["Coming up", [tease if tease != "" else "Something new every visit!"]])
	return out


func _watch_goal() -> String:
	var nr: Dictionary = Watches.next_reward()
	if nr.is_empty():
		return ""
	var left := int(nr.at) - Watches.given_count()
	var pocket := Watches.to_give().size()
	var t := "Lost watches: %d more for Dash (%s)" % [left, str(nr.text)]
	if pocket > 0:
		t += ". You've got %d in your pocket for him!" % pocket
	return t


func _race_goal() -> String:
	for id in Races.TRACKS:
		if Races.unlocked(id) and not Races.finished_once.has(id):
			var t: Dictionary = Races.TRACKS[id]
			var who := Races.starter_name(id)
			var earth: bool = t.scene == Races.EARTH or Races.hub_of(id) == "earth"
			return "Races: try the %s (%s%s)" % [str(t.name), who, " in Stars Hollow" if earth else ""] if not t.get("sky", false) \
				else "Races: the Sky Rings"
	for id in Races.TRACKS:
		if not Races.unlocked(id):
			var t: Dictionary = Races.TRACKS[id]
			var after: Dictionary = Races.TRACKS.get(str(t.get("after", "")), {})
			return "Races: the %s opens the %s" % [str(after.get("name", "last race")), str(t.name)]
	return "Races: win them all!"


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
		if str(sch.kind) == "gadget":
			return "Gadgets: the %s's blueprint. %s" % [Schematics.thing_name(sch), str(sch.hint)]
		return "Schematic: find the %s's. %s" % [Schematics.thing_name(sch), str(sch.hint)]
	if not Arsenal.armed():
		return "Gadgets: find a blueprint for Dash"
	var id := str(Arsenal.current)
	if Arsenal.level(id) < Arsenal.MAX_LEVEL:
		var need: int = Arsenal.LEVEL_XP[Arsenal.level(id)] - int(Arsenal.xp.get(id, 0))
		return "Gadgets: %d more pops with the %s" % [maxi(need, 1), Arsenal.gadget_name(id)]
	return ""


func _ride_goal() -> String:
	# A ride with its schematic found but not built yet, at Zippy's Tune-Up
	for r in Rides.HERO_ORDER:
		var item: Dictionary = Shop.items.get("ride_" + str(r), {})
		if not item.is_empty() and RideUpgrades.ready_to_build(str(r)):
			return "Rides: Zippy can build you the %s, ✦ %d" % [str(item.name), int(item.price)]
	# ...or the next ride a level will open (its schematic found, if it needs one)
	for r in Rides.HERO_ORDER:
		var rr := str(r)
		if not Schematics.owns_ride(rr) and Schematics.ride_unlocked(rr) and RideUpgrades.needs_ok(rr) \
				and not RideUpgrades.level_ok(rr):
			return "Rides: reach Lv %d for the %s" % [RideUpgrades.level_for(rr),
				str(Rides.HERO_RIDES[rr].name)]
	return ""


func _skate_goal() -> String:
	if not Game.has_item("skateboard"):
		return "Skating: grab the skateboard!"
	if not SkateLesson.is_done():
		var done := 0
		for st in SkateLesson.STEPS:
			done += 1 if Dialogue.flags.has("skate_lesson_" + st.id) else 0
		return "Skating: Bruno's lesson (%d of %d)" % [done, SkateLesson.STEPS.size()]
	var G := load("res://scripts/skate_goals.gd")
	for goal in G.GOALS:
		if not Dialogue.flags.has("skate_goal_" + goal.id):
			return "Skate Park goal: %s  [color=#f5e6a3]✦ %d[/color]" % [str(goal.text), int(goal.sparkles)]
	return ""
