extends Node

# Autoload "FirstNight": the glue for "The First Night", the opening quest line of a new game (res://quests/first_night.json,
# run by scripts/quests.gd like every other quest). The quest file holds the steps, the quest log text, who stands where
# (overrides) and the map stars; the lines are in each character's own res://dialogue/<id>.json. This script only does
# the bits a quest file can't: it turns things the player does elsewhere in the game into the quest's flags (Gloops
# popped, Dash's gadget stall looked at, a request finished, the fountain's lost watch found, Zippy said hello to),
# plays the arrival moment the first time they land in the Void (the screen warps and a watch appears on their wrist),
# cheers when the Gloop King pops, and has the portal put them to bed at the end of the night instead of by the oak.
#
#   A whole first day on Earth, then a night nobody saw coming (Hayden, 13 Nov 2026: the glowing oak quest is gone, and
#   "getting pulled into the void should be a seemingly more random occurrence"):
#   1 morning  Earth, 9 AM: Nina knocks; meet Mr. Palmer and two more people on the green.
#   1b board   Nina shows the notice board by the gazebo: read it, follow a job (a star on the map), do one and turn
#              it in (the job board tutorial, Hayden's 11 Nov 2026 playtest; it carries over to Tally's board).
#              Earth's clock waits at 6 PM until steps 1 and 1b are done, so nobody runs out of day.
#   2 evening  Nina goes home for dinner; enjoy the evening, then bed. At midnight, wherever they are, the ground
#              shakes and a crack splits open right under them (scripts/void_arrival.gd fall(); a sleep that night stops
#              at midnight, scripts/bed.gd). Nothing says it's coming.
#   Then the first Void day:
#   3 shift    the night the sky cracked: they and six other chosen fall out of the Void's sky into the Market Square
#              all at once, the Void folk stare, the little aliens run to greet them and Tally comes counting
#              (scripts/void_arrival.gd arrive()); say hello to Tally.
#   4 day      the Void: a request from Tally's board, Rex and Coach Bruno's first two lesson steps, three Gloops
#              (stomped: the Star Popper's Dash's, later), the fountain's watch. After the ollie Rex sends them after
#              his twin, Dash: "The Bike Boy" (res://quests/bike_boy.json, scripts/meetings.gd), which can run
#              alongside and has the Gloop King in it now (in his own kingdom, through the Gloop Gate
#              in the west fields: scripts/gloop_kingdom.gd).
#   5 home     pulled home at the end of the Shift, waking in bed; Nina outside: "You fell too?!"
#
# (Nov 11 2026, Hayden's meeting order: Dash isn't waiting at the portal any more and the King step moved to The
# Bike Boy. Who comes after whom, and what sends you there, is scripts/meetings.gd: the "Meetings" node here.)
#
# A new game starts it when the hero's made (scripts/creator.gd closes). An old save never gets it forced on it: Nina
# offers it on Earth, and the quest log has a button for it. Every step can be skipped from the quest log
# (Quests.skip(), because the file says "skippable"), and none of it blocks anything else in the game.
# Everything is kept as Dialogue flags, so it saves with the game and there's nothing of its own to save.

const ID := "first_night"
const START_FLAG := "first_night_start"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const START_HOUR := 9.0                       # a new game starts in the morning: 9 AM on Earth
const DUSK_HOUR := 18.0                       # the day waits here (Earth time) until the town and the clues are done
const DAY_STEPS := ["morning", "board"]
const NO_SHIFT_SLEEP := ["morning", "board", "evening"]
const BOARD_FLAG := "fn_v3"                    # this save's First Night has the notice board step (migrate())
const PlaceIntro := preload("res://scripts/place_intro.gd")
const Opening := preload("res://scripts/opening.gd")
const VoidArrival := preload("res://scripts/void_arrival.gd")
const INTRO_SEEN := "void_intro_seen"
const FRESH_FLAG := "fresh_start"           # a game started since the Humming Oak (held_back())
const ORDER_FLAG := "fn_v4"                    # this save's First Night has Hayden's meeting order (migrate())
const VERSION_FLAG := "fn_v2"                 # this save's First Night has the Humming Oak's steps (see migrate())
const FALL_FLAG := "fn_v5"                     # this save's First Night has the fall, not the oak's quest (migrate())
# The Humming Oak's step numbers (morning, board, oak, clues, dusk, wait, awaken, shift, day, home) -> today's
# (morning, board, evening, shift, day, home)
const OAK_STEPS := {0: 0, 1: 1, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 3, 8: 4, 9: 5}
# An old save's step (before the Humming Oak, Nov 2026) -> the same step in the Humming Oak's list (before the board
# step went in after "morning": _migrate_v2() adds one for that)
const OLD_STEPS := {0: 0, 1: 4, 2: 6, 3: 7, 4: 8, 5: 9}
const GLOOPS := 3                             # Gloops to pop on the Void day
const FOLK := 2                               # townsfolk to say hello to on the evening
const FOUNTAIN_WATCH := "water_clock"         # the lost watch on the Market Square fountain (scripts/watches.gd)
const WATCH := "shift_watch"                  # the watch that appears on their wrist (res://shop/items.json)
const CROWN := "gloop_crown"                  # Dash's reward for popping the King (res://shop/items.json)
const KING_SPARKLES := 15
const HOME_WARN := 6.0                        # seconds into the home step in the Void: the sky gets light...
const HOME_PULL := 14.0                       # ...and the portal pulls them home to bed
# Earth's townsfolk who count as "people round the green" (not Nina or Mr. Palmer, who have their own lines)
const EARTH_FOLK := ["gus", "dottie", "barnaby", "marigold", "poppy", "otis", "wren", "hank", "kip", "lionel",
	"juniper", "ozzie", "ivy", "theo", "celeste", "prue", "bruno"]

var _home_t := 0.0                            # the home step in the Void: how long since it began (the pull comes soon)
var _woke_home := false                       # the portal put them to bed tonight: say so once Earth's up
var intro: CanvasLayer                        # the first look round the Void (scripts/place_intro.gd)
var meetings: Node                            # who you meet next (scripts/meetings.gd)
var opening: Node                             # the opening cutscenes and the movement tutorial (scripts/opening.gd)
var arrival: CanvasLayer                      # the fall, and the night the sky cracked (scripts/void_arrival.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Creator.closed.connect(_on_creator_closed)
	Dialogue.finished.connect(_on_talked)
	Requests.noted.connect(_on_noted)
	Requests.changed.connect(_check_requests)
	Watches.found_watch.connect(_on_watch)
	Quests.changed.connect(_on_quest_changed)
	Dialogue.flag_set.connect(_on_flag)
	get_tree().scene_changed.connect(_on_scene_changed)
	Quests.follow_changed.connect(_check_board)
	EarthJobs.changed.connect(_check_board)
	intro = PlaceIntro.new()
	intro.name = "Void Intro"
	add_child(intro)
	opening = Opening.new()
	opening.name = "Opening"
	add_child(opening)
	arrival = VoidArrival.new()
	arrival.name = "Arrival"
	add_child(arrival)
	_ensure_meetings()


# -----------------------------------------------------------------------------
# Where it's up to
# -----------------------------------------------------------------------------
func step() -> String:
	return str(Quests.current_step(ID).get("id", ""))


func running() -> bool:
	return Quests.is_started(ID) and not Quests.is_done(ID)


func flag(f: String) -> void:
	if not Dialogue.flags.has(f):
		Dialogue.set_flag(f)


func start() -> void:
	# Start it (a new game, Nina's offer or the quest log's button). The Quests autoload picks the flag up.
	flag(START_FLAG)
	flag(VERSION_FLAG)
	flag(BOARD_FLAG)
	flag(ORDER_FLAG)
	flag(FALL_FLAG)
	Quests.check()


func held_back(night: int) -> bool:
	# A new game (started with the Humming Oak) brings the collectibles in gradually instead of all at once: lost
	# watches, the S-K-A-T-E letters and booster coins wait for the night they're for. (The Earth notice board is out
	# from the first morning now: Nina shows it to them on the board step.)
	# Old saves, and tests that don't start a new game this way, have everything out as before.
	# A night's quest started early (the story quests follow on as soon as the one before is done, scripts/meetings.gd)
	# brings that night's things out with it.
	return Dialogue.flags.has(FRESH_FLAG) and Nights.night() < night and not Dialogue.flags.has("night_%d" % night)


func shift_sleep_ok() -> bool:
	# Whether the bed and the pause menu may hint at the Void yet: only once they've been through once (no spoilers)
	return not running() or not step() in NO_SHIFT_SLEEP


func earth_hold_minutes() -> float:
	# Where Earth's clock is waiting on the first day (6 PM, until the town and the board are done: _hold()), or -1.
	if running() and step() in ["morning", "board"]:
		return DUSK_HOUR * 60.0
	return -1.0


func sleep_stops_at_midnight() -> bool:
	# The first night, any sleep ends at midnight, even "until morning": that's when the ground cracks open
	# (scripts/bed.gd)
	return running() and step() == "evening"


func _ensure_meetings() -> void:
	# (made the first time it's needed: a save can load, and call migrate(), before this autoload's _ready)
	if meetings == null:
		meetings = (load("res://scripts/meetings.gd") as GDScript).new() as Node
		meetings.name = "Meetings"
		add_child(meetings)


func migrate() -> void:
	# A save from before the Humming Oak (scripts/game.gd calls this as it loads): its First Night step number is moved
	# to the same step now, and if it was past the evening, the new Earth-day steps count as done (the oak's awake for
	# it once it's through the door). Saves that never started it, or finished it, have nothing to move.
	_migrate_v2()
	_migrate_v3()
	_migrate_v4()
	_migrate_v5()
	_ensure_meetings()
	meetings.migrate()


func _migrate_v3() -> void:
	if not Quests.state.has(ID) or Dialogue.flags.has(BOARD_FLAG):
		return
	# (Nov 11 2026: the notice board step went in after "morning": a save past the morning moves one step on, and
	# the board's tutorial counts as done)
	Dialogue.flags[BOARD_FLAG] = true
	var st: Dictionary = Quests.state[ID]
	if not bool(st.get("done", false)) and int(st.get("step", 0)) >= 1:
		st["step"] = int(st.get("step", 0)) + 1
		for f in ["fn_board_look", "fn_board_follow", "fn_board_job"]:
			Dialogue.flags[f] = true


func _migrate_v4() -> void:
	# (Nov 11 2026: the Gloop King step moved to The Bike Boy, scripts/meetings.gd.) A save on the King step goes to
	# "home" and does the King there; one on "home" stays on it.
	if not Quests.state.has(ID) or Dialogue.flags.has(ORDER_FLAG):
		return
	Dialogue.flags[ORDER_FLAG] = true
	var st: Dictionary = Quests.state[ID]
	if bool(st.get("done", false)):
		return
	var at := int(st.get("step", 0))
	if at >= 9:
		st["step"] = 9
	if at >= 8:
		Dialogue.flags["fn_met_tally"] = true


func _migrate_v5() -> void:
	# (13 Nov 2026: the oak's quest, its acorns and its reveal are gone; a crack opens under the hero at midnight
	# instead.) A save on one of the oak's steps goes to "evening" and falls at the next midnight; one past it moves to
	# the same step in the shorter list.
	if not Quests.state.has(ID) or Dialogue.flags.has(FALL_FLAG):
		return
	Dialogue.flags[FALL_FLAG] = true
	var st: Dictionary = Quests.state[ID]
	if bool(st.get("done", false)):
		return
	var at := int(st.get("step", 0))
	st["step"] = int(OAK_STEPS.get(at, at - 4))
	if at >= 7:
		Dialogue.flags["fn_fell"] = true
		Dialogue.flags["oak_woken"] = true
	if at >= 8:
		Dialogue.flags["fn_arrived"] = true           # (they'd already landed: no cutscene for them)


func _migrate_v2() -> void:
	# Before the Humming Oak: straight to today's steps (the board's in them too, so nothing more to move after)
	if not Quests.state.has(ID) or Dialogue.flags.has(VERSION_FLAG):
		return
	Dialogue.flags[VERSION_FLAG] = true
	Dialogue.flags[BOARD_FLAG] = true
	var st: Dictionary = Quests.state[ID]
	if bool(st.get("done", false)):
		return
	var old := int(st.get("step", 0))
	var now := int(OLD_STEPS.get(old, old))
	st["step"] = now + (1 if now >= 1 else 0)
	if old >= 1:
		for f in ["fn_oak_listen", "fn_book", "fn_acorns", "fn_acorns_placed", "fn_board_look", "fn_board_follow", "fn_board_job"]:
			Dialogue.flags[f] = true
	if old >= 2:
		Dialogue.flags["oak_woken"] = true


# -----------------------------------------------------------------------------
# 1. The evening
# -----------------------------------------------------------------------------
func _on_creator_closed() -> void:
	# A new game's hero is made: the day starts at 9 AM (the clock kept going while they were in the creator), and
	# Nina knocks at the door. Changing the hero later doesn't start anything.
	if not bool(Creator.get("_first_time")) or Quests.is_started(ID) or not Clock.on_earth:
		return
	Clock.set_earth_time(START_HOUR * 60.0, true)
	flag(FRESH_FLAG)
	# Earth was put together before the hero was made: take away what a new game's first day holds back
	Boosters.drop_coins()
	start()                                      # (the notice board stays: Nina shows it to them this morning)
	# A look over the town, the knock at the door and the movement tutorial, instead of pop-ups (scripts/opening.gd)
	opening.wake.call_deferred()


func _process(_delta: float) -> void:
	if Clock.pull_spawn == "HomeSpawn" and step() != "home":
		Clock.pull_spawn = ""                         # (only tonight: after that, the portal leaves them by the oak)
	if not running():
		return
	match step():
		"morning", "board":
			# Earth's clock waits at 6 PM (just the clock: everyone carries on) until the town and the board are done
			_hold(DUSK_HOUR)
		"evening":
			if arrival.due():
				arrival.fall()                        # midnight: the ground cracks open under them
		"day":
			_check_requests()
		"home":
			Clock.pull_spawn = "HomeSpawn"            # the end of the Shift puts them to bed tonight (scripts/clock.gd)
			_pull_soon(_delta)


func _pull_soon(delta: float) -> void:
	# The first day's jobs are done: the sky gets light and the portal pulls them home a moment later, so nobody waits
	# for the Void's whole day to run out (Hayden, 14 Nov 2026: no waiting on the clock)
	if Clock.on_earth or not Clock.in_shift() or Dialogue.is_active() or arrival.playing() \
			or not get_tree().get_nodes_in_group("cutscene_playing").is_empty():
		return
	var was := _home_t
	_home_t += delta
	if was < HOME_WARN and _home_t >= HOME_WARN:
		Game.message("The sky's getting light... and your new watch has started to tingle. Something's about to happen.")
	if was < HOME_PULL and _home_t >= HOME_PULL:
		Clock.end_shift()                         # (the portal pulls them home to bed: scripts/clock.gd)


func _hold(hour: float) -> void:
	if Clock.on_earth and not Clock.in_shift() and Clock.earth_minutes >= hour * 60.0:
		Clock.earth_minutes = hour * 60.0


func _on_talked(id: String) -> void:
	if not running():
		return
	if step() == "morning" and id in EARTH_FOLK:
		flag("fn_hi_" + id)
		var met := EARTH_FOLK.filter(func(f: String) -> bool: return Dialogue.flags.has("fn_hi_" + f)).size()
		if met >= FOLK:
			flag("fn_folk")
	elif step() == "board" and id == "notice_board":
		flag("fn_board_look")
		_check_board()
	elif step() == "shift" and id == "tally":
		flag("fn_met_tally")                      # Tally's first hello (scripts/requests.gd)
	elif step() == "day" and id == "race_starter":
		flag("fn_zippy")                          # Zippy at the Lake Loop (scripts/races.gd)


func _check_board() -> void:
	# The notice board tutorial's ticks: a job followed (the board's choice or the Quests sheet's Follow button), and a
	# job finished and turned in
	if not running() or step() != "board":
		return
	if Dialogue.flags.has("fn_board_look"):
		for key in Quests.followed:
			if key.begins_with(EarthJobs.key_prefix() + ":"):
				flag("fn_board_follow")
	if EarthJobs.turned_in > 0 or EarthJobs.list.any(func(r: Dictionary) -> bool: return r.paid):
		flag("fn_board_job")


func board_tutorial_lines() -> Array:
	# Nina, the first time they read the board on the board step (EarthJobs.lines() puts these first)
	if not running() or step() != "board" or Dialogue.flags.has("fn_board_look"):
		return []
	return [
		{"speaker": "Nina", "text": "The notice board! Jobs for sparkles!"},
		{"speaker": "Nina", "text": "Do one, then come back here. Press %s!" % Settings.prompt("interact")},
		{"speaker": "Nina", "text": "FOLLOW one and a star shows the way!"},
	]


# -----------------------------------------------------------------------------
# 3. Crossing over: the arrival moment
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not running():
		return
	# (only after the fall: a save loaded in the Void some other way never plays it)
	if scene.scene_file_path == TOWN and Dialogue.flags.has("fn_fell") and not Dialogue.flags.has("fn_arrived"):
		_arrive.call_deferred()
	elif scene.scene_file_path == EARTH and _woke_home:
		_woke_home = false
		Game.message("Was it a dream? The watch still ticks...")


func _arrive() -> void:
	# The first landing in the Void: a watch appears on their wrist, and the night the sky cracked plays
	# (scripts/void_arrival.gd: the cutscene, the little aliens and Tally waiting)
	_give_watch()
	arrival.arrive()


func void_intro(after: Callable = Callable(), force := false) -> void:
	# The first look round the Void: up over the portal, across the lake to the Market Square, and down to Tally's
	# request board, where the notice board's tutorial carries on. Once only (flag void_intro_seen). Headless runs
	# (the tests) skip it unless they ask for it.
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var square := scene.get_node_or_null("Market Square") as Node3D if scene else null
	var board := scene.get_node_or_null("Request Board") as Node3D if scene else null
	var skip := Dialogue.flags.has(INTRO_SEEN) or (DisplayServer.get_name() == "headless" and not force)
	if skip or player == null or square == null:
		if after.is_valid():
			after.call()
		return
	flag(INTRO_SEEN)
	var p := player.global_position
	var to_sq := (square.global_position - p) * Vector3(1, 0, 1)
	var shots: Array = [
		{"from": p + Vector3.UP * 22.0 - to_sq.normalized() * 18.0, "look": p + to_sq * 0.25, "time": 3.2,
			"title": "The Void", "caption": "First morning in the Void!"},
		{"from": square.global_position + Vector3(18, 26, 26), "look": square.global_position, "time": 4.0,
			"title": "", "caption": "The Market Square."},
	]
	if board:
		var b := board.global_position
		var out := ((square.global_position - b) * Vector3(1, 0, 1)).normalized()
		shots.append({"from": b + out * 6.5 + Vector3.UP * 2.8, "look": b + Vector3.UP * 1.6, "time": 4.0,
			"title": "Tally's Request Board",
			"caption": "Requests! Follow one for a star."})
		shots.append({"from": b + out * 5.5 + Vector3.UP * 2.4, "look": b + Vector3.UP * 1.5, "time": 2.2,
			"title": "Tally's Request Board", "caption": "Just like back home!"})
	if after.is_valid():
		intro.done.connect(after, CONNECT_ONE_SHOT)
	intro.play(shots)


func is_arriving() -> bool:
	return arrival.playing()


func _give_watch() -> void:
	if Game.has_item("shop:" + WATCH):
		return
	Game.items.append("shop:" + WATCH)
	if str(Game.outfit.get("hands", "")) == "":
		Game.outfit["hands"] = WATCH                # it's simply there, on their wrist
	Game.equipment_changed.emit()


# -----------------------------------------------------------------------------
# 4. The Void day
# -----------------------------------------------------------------------------
func popper_from_dash() -> Array:
	# Dash's "do" (res://dialogue/dash.json): he shows off the Star Popper, and the shooting tip comes up
	flag("fn_popper")
	Tips.show_tip("shoot")
	return []


func lesson_from_rex() -> Array:
	# Rex's "do" (res://dialogue/rex.json): a spare board if they haven't got one, then Coach Bruno's lesson once the
	# conversation's over (scripts/skate_lesson.gd; the first two steps, push and ollie, are on the checklist)
	var out: Array = []
	if not Game.has_item("skateboard"):
		Game.give_item("skateboard")
		out.append("Here, have my spare board!")
	if Dialogue.flags.has("skate_lesson_ollie"):
		out.append("You know the basics! Bruno's got more.")
		return out
	out.append("COACH BRUNO! We have a student!")
	out.append({"speaker": "Bruno", "text": "A new one? Thweet! Let'th go!"})
	out.append({"speaker": "Rook", "text": "Woof!"})
	Dialogue.finished.connect(_start_lesson, CONNECT_ONE_SHOT)
	return out


func _start_lesson(_id: String) -> void:
	if not SkateLesson.active:
		SkateLesson.start.call_deferred()


func _on_noted(kind: String, _amount: float, _how: String) -> void:
	if kind != "gloop" or not running() or step() != "day":
		return
	for i in GLOOPS:
		if not Dialogue.flags.has("fn_gloop_%d" % (i + 1)):
			flag("fn_gloop_%d" % (i + 1))           # (the to-do list counts them: no pop-up for each)
			break
	if Dialogue.flags.has("fn_gloop_%d" % GLOOPS):
		flag("fn_gloops")


func _check_requests() -> void:
	if not running() or step() != "day" or Dialogue.flags.has("fn_request"):
		return
	for r in Requests.list:
		if r.get("done", false) or r.get("paid", false):
			flag("fn_request")
			return


func _on_watch(id: String) -> void:
	if id == FOUNTAIN_WATCH and running():
		flag("fn_fountain_watch")


func _on_quest_changed(id: String) -> void:
	if id != ID or not running():
		return
	opening.check()                               # a "where to go" shot for the new step (scripts/opening.gd)
	match step():
		"day":
			# Already found the fountain's watch on an old save? Then it's ticked off.
			if Watches.is_found(FOUNTAIN_WATCH):
				flag("fn_fountain_watch")
			_check_requests()
		"home":
			Clock.pull_spawn = "HomeSpawn"


# -----------------------------------------------------------------------------
# 5. The Gloop King
# -----------------------------------------------------------------------------
func _on_flag(f: String) -> void:
	if f in ["fn_nina", "fn_met_tally"] and running():
		opening.check()
	if f == "popped_gloop_king" and Quests.on_step(meetings.QUEST, "king"):
		_cheer()
	elif f == START_FLAG:
		flag(VERSION_FLAG)                        # (started now, so it's on today's steps: nothing for migrate() to move)
		flag(BOARD_FLAG)
		if Dialogue.is_active():
			flag("fn_nina")                       # said yes to Nina's offer (an old save): that's her talked to


func _cheer() -> void:
	# The payoff: a cheer, a shower of sparkly confetti, and Dash waving from the edge of the fields
	Audio.play("level_up", 0.0, 0.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var at := player.global_position + Vector3(0, 2.0, 0)
		for c in [Color(1.0, 0.85, 0.3), Color(0.7, 0.55, 1.0), Color(0.4, 0.95, 0.8), Color(1.0, 0.5, 0.75)]:
			Fx.burst(player.get_parent(), at, c, 14, 0.09, 4.0, -4.0, 1.6)
	Game.message("HOORAY! The Gloop King's popped! Tell Dash!")


func crown_from_dash() -> Array:
	# Dash's "do" once the King's popped: the Gloop Crown (put straight on) and some sparkles
	flag("fn_told_dash")
	if not Game.has_item("shop:" + CROWN):
		Game.items.append("shop:" + CROWN)
		Game.outfit["head"] = CROWN
		Game.add_sparkles(KING_SPARKLES, "Dash's prize:")
		Game.equipment_changed.emit()
	return ["(You got the Gloop Crown!)"]


# -----------------------------------------------------------------------------
# 6. Home
# -----------------------------------------------------------------------------
func pulled_home() -> void:
	# scripts/clock.gd, as the end of the Shift puts them to bed on the first night
	_woke_home = true
