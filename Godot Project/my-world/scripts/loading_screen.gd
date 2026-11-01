extends CanvasLayer

# Autoload "Loading": the loading screen between Earth and Galaxity (plan prompt F5). Game.go() and the title
# screen's Continue call show_for(scene) just before they change scene; it only shows when the trip is from one world
# to another (Earth, Galaxity, the Scary World, the title screen), never for a door into a shop or back out of one. A deep purple screen, a tip,
# and a little alien bobbing and waving (drawn in code), up for at least MIN_TIME so it can be read, and gone again
# once the new place is ready. Tests: tools/test_title.gd.

const MIN_TIME := 1.4
const WORLDS := ["res://scenes/earth/earth.tscn", "res://scenes/town/town.tscn",
	"res://scenes/scary_world/scary_world.tscn", "res://scenes/title/title.tscn"]
const TIPS := [
	"An hour on Earth is a whole day in Galaxity. Make the most of every Shift!",
	"Hold Aim to look over your shoulder, and Shoot to blow star bubbles.",
	"Tally's board has three new requests every night you visit.",
	"The Goals page in your menu always shows something to aim for.",
	"Lost watches tick in their own ways. Dash would love to see them.",
	"On your board, hold Jump to crouch, and let go to ollie.",
	"Sleep in your bed \"Until the Shift\" to get to midnight quicker.",
	"Pop a Gloop while you're grinding: it counts as a trick!",
	"Zippy's races open one after another. Any place counts!",
	"Feeling stuck? Open the map: the stars show where to go.",
	"The little aliens love it when you wave back.",
	"Every Saturday evening there's a fair on the green: a different one each season.",
	"On the last day of autumn it's Hallow's Eve. Knock on every door on Maple Lane!",
	"Every season on Earth lasts four weeks. The Calendar page in your menu shows what's coming.",
	"No school at weekends: Nina, Bruno and their friends are out round town all day.",
]

var tip := ""
var showing := false
var _panel: Control
var _tip_label: Label
var _where_label: Label
var _alien: Control
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
	if scene_path == from or not scene_path in WORLDS or not (from in WORLDS or from == ""):
		return                                   # a door into a shop or a room, or back out of one: no loading screen
	tip = TIPS[_rng.randi() % TIPS.size()]
	_tip_label.text = tip
	_where_label.text = {"res://scenes/earth/earth.tscn": "Off to Earth...", "res://scenes/town/town.tscn": "Off to Galaxity...",
		"res://scenes/scary_world/scary_world.tscn": "Off to the Scary World..."}.get(scene_path, "Loading...")
	_panel.visible = true
	_panel.modulate.a = 1.0
	showing = true
	_shown_at = Time.get_ticks_msec()


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
