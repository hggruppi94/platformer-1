extends CanvasLayer

# Autoload "Tips": short how-to pop-ups the first time the player does something (walking about, jumping, the map,
# talking to someone, shopping, getting on a ride). Each shows once, saved as a Dialogue flag "tip_<id>" (so a new
# game shows them again). One at a time, near the top of the screen: it goes once the player does what it says (or
# after a while). Settings.tips turns them off, and the pause menu's "How-to tips again" shows the basics again.
#
# The text says the player's own keys, or controller buttons when they're using one ({jump}: Settings.fill).

const SHOW_FOR := 10.0               # seconds a tip stays up if the player doesn't do what it says
const TIPS := {
	"move": {"text": "Walk with {moves}. Move the mouse (or the right stick) to look round.",
		"done": ["move_forward", "move_back", "move_left", "move_right"]},
	"jump": {"text": "Press {jump} to jump, and again in the air for a double jump. {dash} does a roll.", "done": ["jump"]},
	"map": {"text": "{player_menu} opens your menu: your quests, the town map, your bag and more. {map} goes straight to the map.",
		"done": ["player_menu", "map", "quest_log"]},
	"pause": {"text": "{pause} pauses the game. Settings are in there, and you can turn these tips off.", "done": ["pause"]},
	"talk": {"text": "Someone to talk to! Press {interact} to say hello.", "done": ["interact"]},
	"shop": {"text": "Pick with the arrows (or the mouse) and buy things with your sparkles ✦. Earn more from quests!",
		"done": []},
	"shoot": {"text": "Gloops about! Press {shoot} to blow a bubble at them, and hold {aim} to aim. Hold {shoot} for a big bubble (1 MP).",
		"done": ["shoot", "aim"]},
	"ride": {"text": "You're riding! Hold {move_forward} to push, hold {jump} and let go to ollie. {toggle_skateboard} hops off.",
		"done": ["toggle_skateboard"]},
	"skate_shoot": {"text": "Gloops ahead! Press {shoot} on your ride to bubble them. Every pop is a Pop! trick in your combo.",
		"done": ["shoot"]},
}
const BASICS := ["move", "jump", "map", "pause"]

var _queue: Array[String] = []
var _id := ""                        # the tip showing now
var _timer := 0.0
var _gap := 0.0                      # a short breath between one tip and the next
var _panel: PanelContainer
var _text: Label


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS          # the shop pauses the game, and its tip still shows
	_build()
	Settings.changed.connect(_on_settings)
	_on_settings()


func _on_settings() -> void:
	_text.add_theme_font_size_override("font_size", roundi(21 * Settings.text_scale))
	_text.custom_minimum_size.x = roundi(560 * minf(Settings.text_scale, 1.5))
	if not Settings.tips:
		clear()


func show_tip(id: String) -> void:
	if not Settings.tips or not TIPS.has(id) or seen(id) or id == _id or id in _queue:
		return
	_queue.append(id)


func basics() -> void:
	# The first ones, once the hero's made (scripts/creator.gd)
	for id in BASICS:
		show_tip(id)


func seen(id: String) -> bool:
	return Dialogue.flags.has("tip_" + id)


func current() -> String:
	return _id


func replay() -> void:
	# The pause menu's "How-to tips again": forget which have been seen, and start with the basics
	for f in Dialogue.flags.keys():
		if String(f).begins_with("tip_"):
			Dialogue.flags.erase(f)
	clear()
	if not Settings.tips:
		Settings.set_value("tips", true)
	basics()


func clear() -> void:
	_queue.clear()
	_id = ""
	_panel.visible = false


func _process(delta: float) -> void:
	if _id == "":
		_gap -= delta
		if _gap > 0.0 or _queue.is_empty():
			return
		_id = _queue.pop_front()
		_timer = SHOW_FOR
		Dialogue.set_flag("tip_" + _id)
		_panel.visible = true
		Audio.play("ui_move", -6.0, 0.0)
	# Refilled every frame, so it follows the keyboard or controller the moment the player switches
	_text.text = Settings.fill(TIPS[_id].text)
	_timer -= delta
	for action in TIPS[_id].done:
		if Input.is_action_pressed(action) and _timer > 1.5:
			_timer = 1.5                             # they've got it: leave it up a moment longer, then go
	if _timer <= 0.0:
		_id = ""
		_panel.visible = false
		_gap = 0.6


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Tip"
	_panel.visible = false
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_top = 70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.18, 0.9)
	style.border_color = Color(1.0, 0.85, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	var icon := Label.new()
	icon.text = "💡"
	icon.add_theme_font_size_override("font_size", 26)
	row.add_child(icon)
	_text = Label.new()
	_text.custom_minimum_size.x = 560
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 21)
	_text.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	row.add_child(_text)
