extends CanvasLayer

# Autoload "Loading": the loading screen between Earth and the Void (plan prompt F5). Game.go() and the title
# screen's Continue call show_for(scene) just before they change scene; it only shows when the trip is from one world
# to another (Earth, the Void, the Scary World, the title screen), never for a door into a shop or back out of one. A deep purple screen, a tip,
# and a little alien bobbing and waving (drawn in code), up for at least MIN_TIME so it can be read, and gone again
# once the new place is ready. Tests: tools/test_title.gd.

const MIN_TIME := 1.4
const WORLDS := ["res://scenes/earth/earth.tscn", "res://scenes/town/town.tscn",
	"res://scenes/scary_world/scary_world.tscn", "res://scenes/title/title.tscn"]
# Short, true tips (Hayden's 14 Nov 2026 rule: a few words, the button's name filled in by Settings.fill). Each can
# wait for a flag, so a tip never talks about something the player hasn't met yet. The overnight polish (15 Nov 2026)
# took out the ones the game had moved past: "An Earth hour is a whole Void day" (the Void's day loops now), "new
# requests every night", and the unclear "Any race place counts".
const TIPS := [
	["Stuck? Touch the old oak!", "oak_woken"],
	["{player_menu} opens your map and quests.", ""],
	["Stars on the map show the way.", ""],
	["Hold {aim}, then {shoot}!", "bb_thanked"],
	["{gadget_wheel} picks a gadget.", "bb_thanked"],
	["Found a watch? Show Dash!", "bb_thanked"],
	["On a board: hold {jump}, let go!", ""],
	["Pop Gloops for sparkles!", ""],
	["Tally's board has jobs!", "fn_met_tally"],
	["{friend} does your friend's move!", "party"],
	["Wave at the little aliens!", "fn_met_tally"],
	["Saturday evening: a fair!", ""],
	["Hallow's Eve: knock knock!", ""],
	["A big party every season!", ""],
	["Check the Calendar!", ""],
	["Weekends: friends play outside!", ""],
	["Bump into things. Boink!", ""],
]

# Before the old oak has opened for them (a new game's first day), only tips that don't give the Void away
# (Hayden's day 1 playtest, 11 Nov 2026: no spoilers before things happen)
const FIRST_DAY_TIPS := [
	"{player_menu} opens your map and quests.",
	"Stars on the map show the way.",
	"Saturday evening: a fair!",
	"Hallow's Eve: knock knock!",
	"Check the Calendar!",
	"Weekends: friends play outside!",
]
const STARS := 60                            # little twinkling stars behind the alien

var tip := ""
var showing := false
var _panel: Control
var _tip_label: Label
var _where_label: Label
var _alien: Control
var _sky: Control
var _stars: Array = []                       # [position 0..1, size, twinkle speed, phase]
var _shown_at := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build()
	get_tree().scene_changed.connect(_on_scene_changed)


func show_for(scene_path: String) -> void:
	var here := get_tree().current_scene
	var from := here.scene_file_path if here else ""
	var worlds := WORLDS.duplicate()
	for w in Portals.WORLDS:                     # the portal worlds count as worlds too (scripts/portals.gd)
		if str(w.scene) != "":
			worlds.append(str(w.scene))
	worlds.append(Bosses.KINGDOM)                # ...and the Gloop King's kingdom (scripts/gloop_kingdom.gd)
	worlds.append(Arena.LEVEL)                   # ...and the Star Arena (scripts/arena_level.gd)
	worlds.append(Farm.SECRET_GARDEN)            # ...and the real Secret Garden (scripts/secret_garden.gd)
	for id in Races.TRACKS:                      # ...and the race circuits (scripts/races.gd)
		if Races.TRACKS[id].has("circuit"):
			worlds.append(str(Races.TRACKS[id].scene))
	if scene_path == from or not scene_path in worlds or not (from in worlds or from == ""):
		return                                   # a door into a shop or a room, or back out of one: no loading screen
	var tips := tips_now()
	tip = Settings.fill(tips[_rng.randi() % tips.size()])
	_tip_label.text = tip
	_where_label.text = {"res://scenes/earth/earth.tscn": "Off to Earth...", "res://scenes/town/town.tscn": "Off to the Void...",
		"res://scenes/scary_world/scary_world.tscn": "Off to Dusk's Embrace..."}.get(scene_path,
		("Through the portal to %s..." % Portals.world_for_scene(scene_path).name) if Portals.is_world_scene(scene_path) \
		else ("Off to the race..." if Races.is_circuit(scene_path) else ("Into the Gloop Kingdom..." if scene_path == Bosses.KINGDOM \
		else ("Into the Star Arena..." if scene_path == Arena.LEVEL \
		else ("Into the Secret Garden..." if scene_path == Farm.SECRET_GARDEN else "Loading...")))))
	_panel.visible = true
	_panel.modulate.a = 1.0
	showing = true
	_shown_at = Time.get_ticks_msec()


func tips_now() -> Array:
	# The tips that fit this save: none that give the Void away before the oak's opened, and none about someone or
	# something the player hasn't met yet
	if not HummingOak.awake():
		return FIRST_DAY_TIPS
	var out := []
	for t in TIPS:
		var need := str(t[1])
		if need == "" or (need == "party" and not Party.joined.is_empty()) or Dialogue.flags.has(need):
			out.append(str(t[0]))
	return out


func _on_scene_changed() -> void:
	if not showing:
		return
	var left := MIN_TIME - (Time.get_ticks_msec() - _shown_at) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left, true, false, true).timeout
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.35)
	await tw.finished
	_panel.visible = false
	showing = false


func _process(_delta: float) -> void:
	if showing:
		_alien.queue_redraw()
		_sky.queue_redraw()


func _build() -> void:
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	add_child(_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.06, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	for i in STARS:
		_stars.append([Vector2(_rng.randf(), _rng.randf()), _rng.randf_range(1.0, 2.6), _rng.randf_range(1.5, 4.0), _rng.randf() * TAU])
	_sky = Control.new()
	_sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.draw.connect(_draw_sky)
	_panel.add_child(_sky)
	_alien = Control.new()
	_alien.set_anchors_preset(Control.PRESET_CENTER)
	_alien.position = Vector2(0, -60)
	_alien.draw.connect(_draw_alien)
	_panel.add_child(_alien)
	_where_label = Label.new()
	_where_label.set_anchors_preset(Control.PRESET_CENTER)
	_where_label.position = Vector2(-300, 70)
	_where_label.size = Vector2(600, 50)
	_where_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_where_label.add_theme_font_size_override("font_size", 34)
	_where_label.add_theme_color_override("font_color", Color(0.93, 0.86, 1.0))
	_panel.add_child(_where_label)
	_tip_label = Label.new()
	_tip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tip_label.position = Vector2(-520, -150)
	_tip_label.size = Vector2(1040, 90)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_font_size_override("font_size", 24)
	_tip_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.95))
	_panel.add_child(_tip_label)


func _draw_sky() -> void:
	# Stars twinkling slowly behind everything (still with Reduce motion: they only fade, they don't move)
	var t := Time.get_ticks_msec() / 1000.0
	var size := _sky.size
	for st in _stars:
		var a := 0.35 + 0.45 * (0.5 + 0.5 * sin(t * float(st[2]) + float(st[3])))
		_sky.draw_circle(Vector2(st[0].x * size.x, st[0].y * size.y), float(st[1]), Color(0.9, 0.85, 1.0, a))


func _draw_alien() -> void:
	# A little alien in a shiny hood with huge eyes, bobbing up and down and waving one hand
	var t := Time.get_ticks_msec() / 1000.0
	var bob := sin(t * 3.0) * 8.0
	var c := _alien
	var suit := Color(0.55, 0.85, 1.0)
	var o := Vector2(0, bob)
	c.draw_circle(o + Vector2(0, 52), 30.0, suit.darkened(0.15))              # body
	c.draw_circle(o + Vector2(0, 0), 42.0, suit)                                # hood
	c.draw_circle(o + Vector2(0, 4), 33.0, Color(0.85, 0.95, 0.75))             # face
	for side in [-1.0, 1.0]:
		c.draw_circle(o + Vector2(side * 13.0, 2), 11.0, Color(0.05, 0.03, 0.1))  # big black eyes
		c.draw_circle(o + Vector2(side * 13.0 - 3.0, -2), 3.5, Color(1, 1, 1, 0.9))
	c.draw_circle(o + Vector2(0, 18), 3.0, Color(0.95, 0.6, 0.7))                 # a little nose
	var wave := sin(t * 7.0) * 0.6
	var shoulder := o + Vector2(26, 40)
	var hand := shoulder + Vector2(cos(-1.2 + wave), sin(-1.2 + wave)) * 34.0
	c.draw_line(shoulder, hand, suit.darkened(0.15), 10.0)
	c.draw_circle(hand, 7.0, Color(0.85, 0.95, 0.75))
	c.draw_line(o + Vector2(-26, 40), o + Vector2(-38, 66), suit.darkened(0.15), 10.0)
	c.draw_line(o + Vector2(0, -42), o + Vector2(10, -64), suit, 3.0)            # antenna
	c.draw_circle(o + Vector2(10, -66), 5.0, Color(1.0, 0.85, 0.4))
