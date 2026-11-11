extends Node

# Autoload "FirstNight": the glue for "The First Night", the opening quest line of a new game (res://quests/first_night.json,
# run by scripts/quests.gd like every other quest). The quest file holds the steps, the quest log text, who stands where
# (overrides) and the map stars; the lines are in each character's own res://dialogue/<id>.json. This script only does
# the bits a quest file can't: it turns things the player does elsewhere in the game into the quest's flags (Gloops
# popped, Dash's gadget stall looked at, a request finished, the fountain's lost watch found, Zippy said hello to),
# plays the arrival moment the first time they land in the Void (the screen warps and a watch appears on their wrist),
# cheers when the Gloop King pops, and has the portal put them to bed at the end of the night instead of by the oak.
#
#   The Humming Oak, a whole first day on Earth (the oak itself, its acorns and its reveal: scripts/humming_oak.gd):
#   1 morning  Earth, 9 AM: Nina knocks; meet Mr. Palmer and two more people on the green.
#   1b board   Nina shows the notice board by the gazebo: read it, follow a job (a star on the map), do one and turn
#              it in (the job board tutorial, Hayden's 11 Nov 2026 playtest; it carries over to Tally's board).
#   2 oak      Nina says the old oak hums at midnight: listen to it, and something's ticking inside.
#   3 clues    Mr. Page's book (The Legend of the Old Oak), Mr. Palmer's lilac envelope from the Void, and three
#              glowing acorns round town (each one sets off a tremor). Earth's clock waits at 6 PM until steps 1 to 3
#              are done, so nobody runs out of day.
#   4 dusk     lay the acorns in the oak's roots: its runes wake. The clock waits at 11 PM until they're in.
#   5 wait     until midnight (the bed's "Until the Shift" is offered from here on, not before).
#   6 awaken   at midnight, walk up to the oak: it opens its door for the first time (the reveal).
#   Then the first Void day:
#   7 shift    through the oak's door: the arrival moment, a short flight over the Void that ends on Tally's request
#              board (the first time only: scripts/place_intro.gd, void_intro()), then Dash at the portal.
#   8 day      the Void: Gloops, Dash's stall, Coach Bruno's first two lesson steps, a request, the fountain's watch.
#   9 king     the Gloop King in the west fields, then tell Dash (he gives the Gloop Crown, and something far off makes him go quiet).
#   10 home    pulled home at the end of the Shift, waking in bed; Nina outside: "Same time tomorrow?"
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
const HOLD_HOUR := 23.0                       # ...and here until the acorns are in the oak's roots
const DAY_STEPS := ["morning", "board", "oak", "clues"]
const NO_SHIFT_SLEEP := ["morning", "board", "oak", "clues", "dusk"]
const BOARD_FLAG := "fn_v3"                    # this save's First Night has the notice board step (migrate())
const PlaceIntro := preload("res://scripts/place_intro.gd")
const INTRO_SEEN := "void_intro_seen"
const FRESH_FLAG := "fresh_start"           # a game started since the Humming Oak (held_back())
const VERSION_FLAG := "fn_v2"                 # this save's First Night has the Humming Oak's steps (see migrate())
# An old save's step (before the Humming Oak, Nov 2026) -> the same step in the Humming Oak's list (before the board
# step went in after "morning": _migrate_v2() adds one for that)
const OLD_STEPS := {0: 0, 1: 4, 2: 6, 3: 7, 4: 8, 5: 9}
const GLOOPS := 3                             # Gloops to pop on the Void day
const FOLK := 2                               # townsfolk to say hello to on the evening
const FOUNTAIN_WATCH := "water_clock"         # the lost watch on the Market Square fountain (scripts/watches.gd)
const WATCH := "shift_watch"                  # the watch that appears on their wrist (res://shop/items.json)
const CROWN := "gloop_crown"                  # Dash's reward for popping the King (res://shop/items.json)
const KING_SPARKLES := 15
# Earth's townsfolk who count as "people round the green" (not Nina or Mr. Palmer, who have their own lines)
const EARTH_FOLK := ["gus", "dottie", "barnaby", "marigold", "poppy", "otis", "wren", "hank", "kip", "lionel",
	"juniper", "ozzie", "ivy", "theo", "celeste", "prue", "bruno"]
const WARP_TIME := 2.6                        # seconds of the arrival moment

var _warp_layer: CanvasLayer
var _warp_rect: ColorRect
var _warp_text: Label
var _arriving := false
var _woke_home := false                       # the portal put them to bed tonight: say so once Earth's up
var intro: CanvasLayer                        # the first look round the Void (scripts/place_intro.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Creator.closed.connect(_on_creator_closed)
	Dialogue.finished.connect(_on_talked)
	Requests.noted.connect(_on_noted)
	Requests.changed.connect(_check_requests)
	Watches.found_watch.connect(_on_watch)
	Shop.opened.connect(_on_shop)
	Quests.changed.connect(_on_quest_changed)
	Dialogue.flag_set.connect(_on_flag)
	get_tree().scene_changed.connect(_on_scene_changed)
	Quests.follow_changed.connect(_check_board)
	EarthJobs.changed.connect(_check_board)
	_build_warp()
	intro = PlaceIntro.new()
	intro.name = "Void Intro"
	add_child(intro)


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
	Quests.check()


func held_back(night: int) -> bool:
	# A new game (started with the Humming Oak) brings the collectibles in gradually instead of all at once: lost
	# watches, the S-K-A-T-E letters and booster coins wait for the night they're for. (The Earth notice board is out
	# from the first morning now: Nina shows it to them on the board step.)
	# Old saves, and tests that don't start a new game this way, have everything out as before.
	return Dialogue.flags.has(FRESH_FLAG) and Nights.night() < night


func shift_sleep_ok() -> bool:
	# The bed's "Until the Shift" (scripts/bed.gd) only once the oak's ready for midnight
	return not running() or not step() in NO_SHIFT_SLEEP


func migrate() -> void:
	# A save from before the Humming Oak (scripts/game.gd calls this as it loads): its First Night step number is moved
	# to the same step now, and if it was past the evening, the new Earth-day steps count as done (the oak's awake for
	# it once it's through the door). Saves that never started it, or finished it, have nothing to move.
	_migrate_v2()
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
	_knock.call_deferred()


func _knock() -> void:
	Audio.play("door", -2.0, 0.0)
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void: Audio.play("door", -2.0, 0.0))
	Game.message("Knock knock! Someone's at your door. Go outside and see who it is!")
	Tips.show_tip("talk")


func _process(_delta: float) -> void:
	if Clock.pull_spawn == "HomeSpawn" and step() != "home":
		Clock.pull_spawn = ""                         # (only tonight: after that, the portal leaves them by the oak)
	if not running():
		return
	match step():
		"morning", "board", "oak", "clues":
			# Earth's clock waits at 6 PM (just the clock: everyone carries on) until the day's clues are found
			_hold(DUSK_HOUR)
		"dusk":
			_hold(HOLD_HOUR)
		"wait":
			if Clock.in_shift():
				flag("fn_midnight")
		"day":
			_check_requests()
		"home":
			Clock.pull_spawn = "HomeSpawn"            # the end of the Shift puts them to bed tonight (scripts/clock.gd)


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
		{"speaker": "Nina", "text": "This is the notice board! Everyone in Stars Hollow pins up little jobs they need a hand with."},
		{"speaker": "Nina", "text": "Do one, then come back and press %s here to turn it in. They pay sparkles!" % Settings.prompt("interact")},
		{"speaker": "Nina", "text": "Pick one to FOLLOW and a star shows you where to go, on your map and your minimap. You can follow more than one!"},
		{"speaker": "Nina", "text": "You can change your mind any time in your Quests, too (%s). Each job and quest has a Follow button." % Settings.prompt("player_menu")},
	]


# -----------------------------------------------------------------------------
# 3. Crossing over: the arrival moment
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or not running():
		return
	if scene.scene_file_path == TOWN and not Dialogue.flags.has("fn_arrived"):
		_arrive.call_deferred()
	elif scene.scene_file_path == EARTH and _woke_home:
		_woke_home = false
		Game.message("%s wakes up in bed, back on Earth. Was it all a dream? The watch on %s wrist is still ticking... Go and find Nina!" %
			[Dialogue.player_name(), Hero.pronoun(Game.hero, "their")])


func _arrive() -> void:
	# The first landing in the Void: the screen swirls, a watch appears on their wrist, and dawn comes up
	if _arriving:
		return
	_arriving = true
	flag("fn_arrived")
	_give_watch()
	Game.hold_controls(&"first_night_arrival", true)
	var mat := _warp_rect.material as ShaderMaterial
	var calm := Settings.reduce_motion
	_warp_layer.visible = true
	_warp_text.text = "The Void. Dawn.\nA watch has appeared on %s wrist. It ticks... differently here." % \
		Hero.pronoun(Game.hero, "their")
	_warp_text.modulate.a = 0.0
	mat.set_shader_parameter("amount", 0.0 if calm else 1.0)
	mat.set_shader_parameter("tint", 0.85)
	Audio.play("beam", -4.0, 0.0)
	var tw := _warp_layer.create_tween()
	tw.tween_property(_warp_text, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("amount", 0.0 if calm else v),
		1.0, 0.0, WARP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter("tint", v), 0.85, 0.0, WARP_TIME)
	tw.tween_interval(0.6)
	tw.tween_property(_warp_text, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_warp_layer.visible = false
		_arriving = false
		Game.hold_controls(&"first_night_arrival", false)        # (a talk going on keeps its own hold)
		Audio.play("pickup", -6.0, 0.0)
		void_intro(func() -> void:
			if step() == "shift":
				Game.message("Someone's waving at you from beside the portal...")))


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
			"title": "The Void", "caption": "{player}'s first morning on the other side of the oak."},
		{"from": square.global_position + Vector3(18, 26, 26), "look": square.global_position, "time": 4.0,
			"title": "", "caption": "The Market Square, right in the middle of town."},
	]
	if board:
		var b := board.global_position
		var out := ((square.global_position - b) * Vector3(1, 0, 1)).normalized()
		shots.append({"from": b + out * 6.5 + Vector3.UP * 2.8, "look": b + Vector3.UP * 1.6, "time": 4.0,
			"title": "Tally's Request Board",
			"caption": "Folks in the Void pin up requests here every night. Follow one and a star shows the way!"})
		shots.append({"from": b + out * 5.5 + Vector3.UP * 2.4, "look": b + Vector3.UP * 1.5, "time": 2.2,
			"title": "Tally's Request Board", "caption": "Just like the notice board back home."})
	if after.is_valid():
		intro.done.connect(after, CONNECT_ONE_SHOT)
	intro.play(shots)


func is_arriving() -> bool:
	return _arriving


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
		out.append("(Rex slides a skateboard over with one paw.) Here, borrow my spare. It's yours now. Mayors share.")
	if Dialogue.flags.has("skate_lesson_ollie"):
		out.append("You already know the basics! Bruno's at the Lesson Pad if you want the fancy stuff.")
		return out
	out.append("COACH BRUNO! We have a student!")
	out.append({"speaker": "Bruno", "text": "(Nina's little brother skids up on a black SK8 deck.) A new one? Thweet. Lesson Pad. Let'th go."})
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
			flag("fn_gloop_%d" % (i + 1))
			if i + 1 < GLOOPS:
				Game.message("Pop! That's %d of %d Gloops." % [i + 1, GLOOPS])
			break
	if Dialogue.flags.has("fn_gloop_%d" % GLOOPS):
		flag("fn_gloops")


func _on_shop(stall: String) -> void:
	if stall == "Gadget" and running() and step() == "day":
		flag("fn_stall")


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
	if f == "popped_gloop_king" and running() and step() == "king":
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
	Game.message("HOORAY! You popped the Gloop King! Dash is cheering at the edge of the fields. Go and tell him!")


func crown_from_dash() -> Array:
	# Dash's "do" once the King's popped: the Gloop Crown (put straight on) and some sparkles
	flag("fn_told_dash")
	if not Game.has_item("shop:" + CROWN):
		Game.items.append("shop:" + CROWN)
		Game.outfit["head"] = CROWN
		Game.add_sparkles(KING_SPARKLES, "Dash's prize:")
		Game.equipment_changed.emit()
	return ["(The Gloop Crown is yours! You're wearing it. Find it in your wardrobe any time.)"]


# -----------------------------------------------------------------------------
# 6. Home
# -----------------------------------------------------------------------------
func pulled_home() -> void:
	# scripts/clock.gd, as the end of the Shift puts them to bed on the first night
	_woke_home = true


# -----------------------------------------------------------------------------
# The arrival moment's screen
# -----------------------------------------------------------------------------
func _build_warp() -> void:
	_warp_layer = CanvasLayer.new()
	_warp_layer.layer = 48
	_warp_layer.visible = false
	add_child(_warp_layer)
	_warp_rect = ColorRect.new()
	_warp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	# A swirl that winds the screen round its middle and unwinds, washed in the portal's lavender, fading to nothing
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
uniform float tint = 0.8;
void fragment() {
	vec2 c = SCREEN_UV - vec2(0.5);
	float r = length(c);
	float a = amount * 7.0 * (1.0 - smoothstep(0.0, 0.75, r));
	float s = sin(a);
	float co = cos(a);
	vec2 uv = vec2(c.x * co - c.y * s, c.x * s + c.y * co) * (1.0 - 0.35 * amount) + vec2(0.5);
	vec3 col = textureLod(screen, uv, amount * 2.0).rgb;
	vec3 lav = mix(vec3(0.72, 0.6, 1.0), vec3(0.4, 0.95, 0.85), smoothstep(0.1, 0.6, r));
	COLOR = vec4(mix(col, lav, tint), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_warp_rect.material = m
	_warp_layer.add_child(_warp_rect)
	_warp_text = Label.new()
	_warp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warp_text.add_theme_font_size_override("font_size", roundi(30 * Settings.text_scale))
	_warp_text.add_theme_color_override("font_color", Color(1, 0.97, 1))
	_warp_text.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.25))
	_warp_text.add_theme_constant_override("outline_size", 8)
	_warp_layer.add_child(_warp_text)
