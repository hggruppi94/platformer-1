extends Node

# Autoload "Settings": every player option, saved to user://settings.cfg and applied immediately.
# The pause menu (scripts/pause_menu.gd) edits these; gameplay code reads them, e.g. Settings.no_damage.
# Anything that needs to react to a change listens to `changed`.

signal changed
signal device_changed                 # the player switched between the keyboard and a controller (prompts follow it)

const PATH := "user://settings.cfg"

# Keyboard actions the player can rebind, in menu order, with their menu names
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["jump", "Jump"], ["dash", "Roll"], ["aim", "Aim"], ["shoot", "Shoot"],
	["toggle_skateboard", "Skateboard"],
	["skate_grind", "Grind"], ["skate_flip", "Flip trick"], ["skate_grab", "Grab trick"], ["interact", "Interact"],
	["quest_log", "Quest log"], ["map", "Map"], ["player_menu", "Player menu"], ["pause", "Pause"],
]

# Controller buttons the player can change, in menu order. The sticks stay where they are. Some buttons do two jobs
# (X rolls on foot and flips on the board), so a button only clashes with actions used at the same time (PAD_GROUPS).
const PAD_REBINDABLE := [
	["jump", "Jump"], ["dash", "Roll"], ["aim", "Aim"], ["shoot", "Shoot"], ["toggle_skateboard", "Skateboard"],
	["skate_grind", "Grind"], ["skate_flip", "Flip trick"], ["skate_grab", "Grab trick"], ["interact", "Interact"], ["quest_log", "Quest log"],
	["map", "Map"], ["player_menu", "Player menu"], ["pause", "Pause"],
]
const PAD_GROUPS := [
	["jump", "dash", "aim", "shoot", "toggle_skateboard", "interact", "quest_log", "map", "player_menu", "pause"],   # on foot
	["jump", "toggle_skateboard", "skate_grind", "skate_flip", "skate_grab", "quest_log", "map", "player_menu", "pause"],   # riding
]
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad up",
	JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	PAD_LT: "LT", PAD_RT: "RT",
}
# The triggers are axes, not buttons, so they get numbers of their own past the buttons' (aiming and shooting sit on
# them: scripts/star_popper.gd)
const PAD_LT := 200
const PAD_RT := 201
const PAD_TRIGGERS := {PAD_LT: JOY_AXIS_TRIGGER_LEFT, PAD_RT: JOY_AXIS_TRIGGER_RIGHT}
# Mouse buttons can be keys too (Aim and Shoot start on them). They're kept as minus the button's number, so they
# can't be mistaken for a key.
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click", MOUSE_BUTTON_XBUTTON1: "Mouse back", MOUSE_BUTTON_XBUTTON2: "Mouse forward"}
# How forgiving the skating is (scenes/player/skate.gd, Skate.ASSIST)
const ASSIST_NAMES := ["Relaxed", "Normal", "Pro"]

# --- Audio (0..1)
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9
# --- Controls
var mouse_sensitivity := 1.0          # multiplier
var stick_sensitivity := 1.0
var invert_y := false
var invert_x := false
var control_style := "classic"        # "classic": Tony Hawk's buttons; "simple": one trick button, grinds by themselves
var tips := true                      # first-time how-to pop-ups (scripts/tips.gd)
# --- Display
var fullscreen := false
var fov := 75.0
var minimap := false                  # a small map in the bottom-right corner (scripts/map_screen.gd)
# --- Accessibility
var text_scale := 1.0                 # HUD and menu text size
var high_contrast := false            # solid dark panels, bright text, heavy outlines
var reduce_flashing := false          # no blinking/flashing on hits, calmer glows
var reduce_motion := false            # no camera kick when rolling, calmer bobbing effects
var captions := false                 # show text for important sounds
# --- Assist
var game_speed := 1.0                 # 1.0 = normal; lower gives more time to react
var no_damage := false
var infinite_mp := false
var infinite_sp := false
var skate_assist := 1                 # 0 Relaxed, 1 Normal, 2 Pro (the strict first rules)

var _defaults := {}
var bindings := {}                    # action -> physical keycode
var pad_bindings := {}                # action -> controller button (JOY_BUTTON_*)
var last_device := "keyboard"         # "keyboard" (and mouse) or "pad": whichever the player used last


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in _props():
		_defaults[p] = get(p)
	for pair in REBINDABLE:
		bindings[pair[0]] = _current_key(pair[0])
	pad_bindings = default_pad_bindings()
	if Input.get_connected_joypads().size() > 0:
		last_device = "pad"
	load_settings()
	apply()


func _props() -> Array[String]:
	return ["master_volume", "music_volume", "sfx_volume", "mouse_sensitivity", "stick_sensitivity", "invert_y",
		"invert_x", "fullscreen", "fov", "minimap", "text_scale", "high_contrast", "reduce_flashing", "reduce_motion",
		"captions", "game_speed", "no_damage", "infinite_mp", "infinite_sp", "control_style", "tips", "skate_assist"]


func set_value(prop: String, value) -> void:
	set(prop, value)
	apply()
	save_settings()


func apply() -> void:
	Audio.set_volume("Master", master_volume)
	Audio.set_volume("Music", music_volume)
	Audio.set_volume("SFX", sfx_volume)
	Engine.time_scale = game_speed
	if not OS.has_feature("headless"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and \
				not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	for action in bindings:
		_bind(action, bindings[action])
	for action in pad_bindings:
		_bind_pad(action, pad_bindings[action])
	changed.emit()


func reset_to_defaults() -> void:
	for p in _defaults:
		set(p, _defaults[p])
	bindings = default_bindings()
	pad_bindings = default_pad_bindings()
	apply()
	save_settings()


func use_layout(style: String) -> void:
	# The Controls tab's layouts: Classic (Tony Hawk's buttons) or Simple (one trick button: tap to flip, hold to
	# grab; grinds happen by themselves). Either one puts every key and button back where it started.
	control_style = style
	bindings = default_bindings()
	pad_bindings = default_pad_bindings()
	apply()
	save_settings()


func _input(event: InputEvent) -> void:
	note_device(event)


func note_device(event: InputEvent) -> void:
	# Which one the player is using, so prompts can show the right button. The player menu (scripts/player_menu.gd)
	# tells this too, as it keeps the buttons it uses from going any further.
	var now := last_device
	if event is InputEventJoypadButton and event.pressed:
		now = "pad"
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		now = "pad"
	elif (event is InputEventKey and event.pressed) or event is InputEventMouseButton:
		now = "keyboard"
	if now != last_device:
		last_device = now
		device_changed.emit()


# ----------------------------------------------------------------------------- prompts
func prompt(action: String) -> String:
	# What to press for an action, on whatever the player is using right now: "Space", "A", "Left stick up"...
	if last_device != "pad":
		if action == "quest_log" and bindings.get("quest_log", 0) == 0:
			action = "player_menu"                 # no key of its own: Tab opens the player menu on the Quests sheet
		return key_name(action)
	if action == "quest_log" and pad_bindings.get("quest_log", -1) < 0:
		action = "player_menu"                     # no button of its own: Back opens the player menu on the Quests sheet
	match action:
		"move_forward", "move_back", "move_left", "move_right":
			return "Left stick " + {"move_forward": "up", "move_back": "down", "move_left": "left", "move_right": "right"}[action]
		"look_left", "look_right", "look_up", "look_down":
			return "Right stick"
	return pad_name(action)


func moves() -> String:
	# The four move keys together ("WASD"), or the stick
	if last_device == "pad":
		return "the left stick"
	return "%s%s%s%s" % [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]


func fill(text: String) -> String:
	# Fills {jump}, {skate_flip}... with what to press, and {moves} with the move keys (scripts/tips.gd, the lesson)
	var words := {"moves": moves()}
	for pair in REBINDABLE:
		words[pair[0]] = prompt(pair[0])
	return text.format(words)


func pad_name(action: String) -> String:
	var b: int = pad_bindings.get(action, -1)
	return PAD_NAMES.get(b, "-") if b >= 0 else "-"


# ----------------------------------------------------------------------------- controller buttons
func default_pad_bindings() -> Dictionary:
	return {"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_X, "aim": PAD_LT, "shoot": PAD_RT, "toggle_skateboard": JOY_BUTTON_Y, "skate_grind": JOY_BUTTON_Y,
		"skate_flip": JOY_BUTTON_X, "skate_grab": JOY_BUTTON_B, "interact": JOY_BUTTON_B, "quest_log": -1,
		"map": JOY_BUTTON_LEFT_SHOULDER, "player_menu": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START}
	# The quest log has no button of its own (-1): Back opens the player menu (scripts/player_menu.gd) on its Quests
	# sheet. The player can still give it one in Settings > Controls.


func rebind_pad(action: String, button: int) -> String:
	# Like rebind(), for a controller button. Only actions used at the same time clash (PAD_GROUPS); the one that had
	# the button gets this action's old one.
	var old: int = pad_bindings.get(action, -1)
	var clash := ""
	for group in PAD_GROUPS:
		if not action in group:
			continue
		for other in group:
			if other != action and pad_bindings.get(other, -1) == button and not _shares_on_purpose(action, other):
				clash = other
				pad_bindings[other] = old
	pad_bindings[action] = button
	apply()
	save_settings()
	return clash


func _shares_on_purpose(a: String, b: String) -> bool:
	# The skateboard button is Grind too while riding (scripts/game.gd, _board_button_free), so those two may share
	return [a, b].has("toggle_skateboard") and [a, b].has("skate_grind")


func _bind_pad(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton or e is InputEventJoypadMotion:
			InputMap.action_erase_event(action, e)
	if button < 0:
		return                                      # no button (the quest log, by default)
	if PAD_TRIGGERS.has(button):
		var t := InputEventJoypadMotion.new()
		t.device = -1
		t.axis = PAD_TRIGGERS[button]
		t.axis_value = 1.0
		InputMap.action_add_event(action, t)
		return
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = button as JoyButton
	InputMap.action_add_event(action, b)
	if action == "dash" and button != JOY_BUTTON_RIGHT_SHOULDER:   # RB rolls too, whatever Roll is on
		var rb := InputEventJoypadButton.new()
		rb.device = -1
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event(action, rb)


# ----------------------------------------------------------------------------- key bindings
func default_bindings() -> Dictionary:
	return {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "aim": -MOUSE_BUTTON_RIGHT, "shoot": -MOUSE_BUTTON_LEFT, "toggle_skateboard": KEY_E, "skate_grind": KEY_L, "skate_flip": KEY_J, "skate_grab": KEY_K,
		"interact": KEY_F, "quest_log": KEY_Q, "map": KEY_M, "player_menu": KEY_TAB, "pause": KEY_ESCAPE}


func rebind(action: String, physical_keycode: int) -> String:
	# Returns the name of another action that already used this key (it gets swapped onto the old key), or "".
	var old: int = bindings.get(action, 0)
	var clash := ""
	for other in bindings:
		if other != action and bindings[other] == physical_keycode:
			clash = other
			bindings[other] = old
	bindings[action] = physical_keycode
	apply()
	save_settings()
	return clash


func key_name(action: String) -> String:
	var code: int = bindings.get(action, 0)
	if code == 0:
		return "-"
	if code < 0:
		return MOUSE_NAMES.get(-code, "Mouse %d" % -code)
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(code)          # no keyboard layout to ask (automated tests)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code as Key))   # e.g. Z on AZERTY


func action_label(action: String) -> String:
	for pair in REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return action


func _current_key(action: String) -> int:
	if not InputMap.has_action(action):
		return default_bindings().get(action, 0)
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.physical_keycode if e.physical_keycode != 0 else e.keycode
		if e is InputEventMouseButton:
			return -e.button_index
	return default_bindings().get(action, 0)


func _bind(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in InputMap.action_get_events(action):
		if e is InputEventKey or e is InputEventMouseButton:
			InputMap.action_erase_event(action, e)
	if physical_keycode == 0:
		return                                      # no key
	if physical_keycode < 0:
		var mb := InputEventMouseButton.new()       # a mouse button (Aim and Shoot, to start with)
		mb.device = -1
		mb.button_index = -physical_keycode as MouseButton
		InputMap.action_add_event(action, mb)
		return
	var k := InputEventKey.new()
	k.device = -1
	k.physical_keycode = physical_keycode as Key
	InputMap.action_add_event(action, k)
	if action == "pause":                       # P also pauses, whatever Pause is bound to
		var p := InputEventKey.new()
		p.device = -1
		p.physical_keycode = KEY_P
		if physical_keycode != KEY_P:
			InputMap.action_add_event(action, p)


# ----------------------------------------------------------------------------- persistence
func save_settings() -> void:
	var cf := ConfigFile.new()
	for p in _props():
		cf.set_value("settings", p, get(p))
	for a in bindings:
		cf.set_value("keys", a, bindings[a])
	for a in pad_bindings:
		cf.set_value("pad", a, pad_bindings[a])
	cf.save(PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for p in _props():
		if cf.has_section_key("settings", p):
			var v = cf.get_value("settings", p)
			if typeof(v) == typeof(get(p)) or (typeof(get(p)) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				set(p, v)
	for a in bindings.keys():
		if cf.has_section_key("keys", a):
			bindings[a] = int(cf.get_value("keys", a))
	for a in pad_bindings.keys():
		if cf.has_section_key("pad", a):
			pad_bindings[a] = int(cf.get_value("pad", a))
	# Actions added since these settings were saved (the player menu, on Tab and Back) get their own key and button,
	# even from something the player had moved onto it: that one goes back to where it started, or to nothing if
	# that's taken too (Hayden's quest log was on Tab, and the player menu opens on the Quests sheet anyway).
	if cf.has_section("keys"):
		for a in bindings.keys():
			if not cf.has_section_key("keys", a):
				_claim(bindings, a, default_bindings(), 0)
	if cf.has_section("pad"):
		for a in pad_bindings.keys():
			if not cf.has_section_key("pad", a):
				_claim(pad_bindings, a, default_pad_bindings(), -1)


func _claim(table: Dictionary, action: String, defaults: Dictionary, none: int) -> void:
	var mine: int = defaults.get(action, none)
	for other in table:
		# Only one the player moved there: some start out sharing on purpose (X rolls and flips)
		if other != action and table[other] == mine and table[other] != defaults.get(other, none):
			var own: int = defaults.get(other, none)
			table[other] = own if not table.values().has(own) else none
