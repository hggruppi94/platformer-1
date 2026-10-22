extends Node

# Autoload "Settings": every player option, saved to user://settings.cfg and applied immediately.
# The pause menu (scripts/pause_menu.gd) edits these; gameplay code reads them, e.g. Settings.no_damage.
# Anything that needs to react to a change listens to `changed`.

signal changed

const PATH := "user://settings.cfg"

# Keyboard actions the player can rebind, in menu order, with their menu names
const REBINDABLE := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["jump", "Jump"], ["dash", "Roll"], ["toggle_skateboard", "Skateboard"],
	["interact", "Interact"], ["quest_log", "Quest log"], ["map", "Map"], ["pause", "Pause"],
]

# --- Audio (0..1)
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.9
# --- Controls
var mouse_sensitivity := 1.0          # multiplier
var stick_sensitivity := 1.0
var invert_y := false
var invert_x := false
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

var _defaults := {}
var bindings := {}                    # action -> physical keycode (keyboard only; controller layout is fixed)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for p in _props():
		_defaults[p] = get(p)
	for pair in REBINDABLE:
		bindings[pair[0]] = _current_key(pair[0])
	load_settings()
	apply()


func _props() -> Array[String]:
	return ["master_volume", "music_volume", "sfx_volume", "mouse_sensitivity", "stick_sensitivity", "invert_y",
		"invert_x", "fullscreen", "fov", "minimap", "text_scale", "high_contrast", "reduce_flashing", "reduce_motion",
		"captions", "game_speed", "no_damage", "infinite_mp", "infinite_sp"]


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
	changed.emit()


func reset_to_defaults() -> void:
	for p in _defaults:
		set(p, _defaults[p])
	bindings = default_bindings()
	apply()
	save_settings()


# ----------------------------------------------------------------------------- key bindings
func default_bindings() -> Dictionary:
	return {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "toggle_skateboard": KEY_E, "interact": KEY_F, "quest_log": KEY_Q, "map": KEY_M,
		"pause": KEY_ESCAPE}


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
	return default_bindings().get(action, 0)


func _bind(action: String, physical_keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
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
