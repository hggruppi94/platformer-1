extends Node

# Autoload "FirstNight": the glue for "The First Night", the opening quest line of a new game (res://quests/first_night.json,
# run by scripts/quests.gd like every other quest). The quest file holds the steps, the quest log text, who stands where
# (overrides) and the map stars; the lines are in each character's own res://dialogue/<id>.json. This script only does
# the bits a quest file can't: it turns things the player does elsewhere in the game into the quest's flags (Gloops
# popped, Dash's gadget stall looked at, a request finished, the fountain's lost watch found, Zippy said hello to),
# plays the arrival moment the first time they land in Galaxity (the screen warps and a watch appears on their wrist),
# cheers when the Gloop King pops, and has the portal put them to bed at the end of the night instead of by the oak.
#
#   1 evening  Earth, 8 PM: Nina knocks; meet Mr. Palmer and two more people on the green. Earth's clock waits at 11 PM
#              until this step's done, so a slow first look round never misses the first Shift.
#   2 wait     until midnight (Nina suggests the bed's "Until the Shift").
#   3 shift    through the portal: the arrival moment, then Dash at the portal on the far side.
#   4 day      Galaxity: Gloops, Dash's stall, Coach Rook's first two lesson steps, a request, the fountain's watch, Zippy.
#   5 king     the Gloop King in the west fields, then tell Dash (he gives the Gloop Crown and hints at the Agent of Chaos).
#   6 home     pulled home at the end of the Shift, waking in bed; Nina outside: "Same time tomorrow?"
#
# A new game starts it when the hero's made (scripts/creator.gd closes). An old save never gets it forced on it: Nina
# offers it on Earth, and the quest log has a button for it. Every step can be skipped from the quest log
# (Quests.skip(), because the file says "skippable"), and none of it blocks anything else in the game.
# Everything is kept as Dialogue flags, so it saves with the game and there's nothing of its own to save.

const ID := "first_night"
const START_FLAG := "first_night_start"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const START_HOUR := 20.0                      # a new game's evening: 8 PM on Earth
const HOLD_HOUR := 23.0                       # the evening waits here (Earth time) until the first step's done
const GLOOPS := 3                             # Gloops to pop on the Galaxity day
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
	_build_warp()


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
	Quests.check()


# -----------------------------------------------------------------------------
# 1. The evening
# -----------------------------------------------------------------------------
func _on_creator_closed() -> void:
	# A new game's hero is made: the evening starts at 8 PM (the clock kept going while they were in the creator), and
	# Nina knocks at the door. Changing the hero later doesn't start anything.
	if not bool(Creator.get("_first_time")) or Quests.is_started(ID) or not Clock.on_earth:
		return
	Clock.set_earth_time(START_HOUR * 60.0, true)
	start()
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
		"evening":
			# Earth's clock waits at 11 PM (just the clock: everyone carries on) until the evening's done
			if Clock.on_earth and not Clock.in_shift() and Clock.earth_minutes >= HOLD_HOUR * 60.0:
				Clock.earth_minutes = HOLD_HOUR * 60.0
		"wait":
			if Clock.in_shift():
				flag("fn_midnight")
		"day":
			_check_requests()
		"home":
			Clock.pull_spawn = "HomeSpawn"            # the end of the Shift puts them to bed tonight (scripts/clock.gd)


func _on_talked(id: String) -> void:
	if not running():
		return
	if step() == "evening" and id in EARTH_FOLK:
		flag("fn_hi_" + id)
		var met := EARTH_FOLK.filter(func(f: String) -> bool: return Dialogue.flags.has("fn_hi_" + f)).size()
		if met >= FOLK:
			flag("fn_folk")
	elif step() == "day" and id == "race_starter":
		flag("fn_zippy")                          # Zippy at the Lake Loop (scripts/races.gd)


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
		Game.message("%s wakes up in bed, back on Earth. Was it all a dream? The watch on %s wrist is still ticking..." %
			[Dialogue.player_name(), Hero.pronoun(Game.hero, "their")])


func _arrive() -> void:
	# The first landing in Galaxity: the screen swirls, a watch appears on their wrist, and dawn comes up
	if _arriving:
		return
	_arriving = true
	flag("fn_arrived")
	_give_watch()
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player:
		player.set("input_locked", true)
	var mat := _warp_rect.material as ShaderMaterial
	var calm := Settings.reduce_motion
	_warp_layer.visible = true
	_warp_text.text = "Galaxity. Dawn.\nA watch has appeared on %s wrist. It ticks... differently here." % \
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
		var p := get_tree().get_first_node_in_group("player")
		if p and "input_locked" in p and not Dialogue.is_active():
			p.set("input_locked", false)
		Audio.play("pickup", -6.0, 0.0)
		if step() == "shift":
			Game.message("Someone's waving at you from beside the portal..."))


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
# 4. The Galaxity day
# -----------------------------------------------------------------------------
func popper_from_dash() -> Array:
	# Dash's "do" (res://dialogue/dash.json): he shows off the Star Popper, and the shooting tip comes up
	flag("fn_popper")
	Tips.show_tip("shoot")
	return []


func lesson_from_rex() -> Array:
	# Rex's "do" (res://dialogue/rex.json): a spare board if they haven't got one, then Coach Rook's lesson once the
	# conversation's over (scripts/skate_lesson.gd; the first two steps, push and ollie, are on the checklist)
	var out: Array = []
	if not Game.has_item("skateboard"):
		Game.give_item("skateboard")
		out.append("(Rex slides a skateboard over with one paw.) Here, borrow my spare. It's yours now. Mayors share.")
	if Dialogue.flags.has("skate_lesson_ollie"):
		out.append("You already know the basics! Rook's at the Lesson Pad if you want the fancy stuff.")
		return out
	out.append("COACH ROOK! We have a student!")
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
	elif f == START_FLAG and Dialogue.is_active():
		flag("fn_nina")                           # said yes to Nina's offer (an old save): that's her talked to


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
