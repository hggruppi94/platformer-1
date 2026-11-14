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
	["gadget_wheel", "Gadget wheel"], ["outfit_wheel", "Outfit wheel"], ["friend", "Friend move"], ["friend_wheel", "Friend wheel"],
	["toggle_skateboard", "Skateboard"], ["skate_grind", "Grind"], ["skate_flip", "Flip trick"], ["skate_grab", "Grab trick"], ["interact", "Interact"],
	["player_menu", "Player menu"], ["quest_log", "Menu: Quests"], ["map", "Menu: Map"], ["check_watch", "Check your watch"],
	["pause", "Pause"],
]

# Controller buttons the player can change, in menu order. The sticks stay where they are. Some buttons do two jobs
# (X rolls on foot and flips on the board), so a button only clashes with actions used at the same time (PAD_GROUPS).
# The quests and the map are tabs of the one menu on Back (scripts/player_menu.gd), so on a controller they have no
# buttons of their own any more (the design doc's "three menus into one"); the keyboard keeps Q and M as shortcuts
# straight to those tabs, since they cost nothing there.
const PAD_REBINDABLE := [
	["jump", "Jump"], ["dash", "Roll"], ["aim", "Aim"], ["shoot", "Shoot"], ["gadget_wheel", "Gadget wheel"],
	["outfit_wheel", "Outfit wheel"], ["friend", "Friend move"], ["friend_wheel", "Friend wheel"], ["toggle_skateboard", "Skateboard"], ["skate_grind", "Grind"], ["skate_flip", "Flip trick"], ["skate_grab", "Grab trick"], ["interact", "Interact"],
	["player_menu", "Player menu"], ["check_watch", "Check your watch"], ["pause", "Pause"],
]
const PAD_GROUPS := [
	["jump", "dash", "aim", "shoot", "gadget_wheel", "outfit_wheel", "friend", "friend_wheel", "toggle_skateboard", "interact", "player_menu", "check_watch", "pause"],   # on foot
	["jump", "aim", "shoot", "gadget_wheel", "outfit_wheel", "toggle_skateboard", "skate_grind", "skate_flip", "skate_grab", "player_menu", "check_watch", "pause"],   # riding (Aim uses a race's power-up: scripts/races.gd)
]
# The friends' moves (plan item 26, scripts/party.gd): none has a button of its own any more. The friend walking with
# you does theirs when you press Friend, so a prompt for any of them says the Friend button (prompt(), key_name()).
# The names still say whether the move's been learned (action_shown()).
const FRIEND_MOVES := ["burrow", "frost_breath", "groove", "showers", "make"]
# Moves a chosen one teaches: learned once their world is mended (action_shown())
const SECRET_ACTIONS := {"burrow": "rootmind", "frost_breath": "frozen_moment", "groove": "rhythm_springs", "showers": "glenmoor"}
# ...and moves a friend teaches in a quest: hidden until that flag's set (Nina and Bruno's Make, scripts/make.gd)
const SECRET_FLAGS := {"make": "make_taught"}
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
var voice_volume := 0.8               # the little blips people talk in (scripts/soundscape.gd)
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
var minimap := true                   # the round map in the bottom-right corner (scripts/map_screen.gd); on by default since Nov 2026
var map_hide := []                   # what's switched off on the maps (the big map's "Show on the map" list): kinds
                                      # ("people", "races"...) and followed quests' stars ("quest:<id or job key>")
var clock_style := "both"             # the HUD's clock once the hero has a watch: "both" (watch and words), "watch", "words"
# --- Accessibility
var text_scale := 1.0                 # HUD and menu text size
var hud_size := 0.8                   # the on-screen stuff while playing (stats, clock, to-do list, quest banner, minimap,
                                      # tips): 0.8 "Small" by default since Hayden's 7 Nov 2026 playtest, 1.0 the old size
var talk_speed := 40.0                # letters a second when people talk (scripts/dialogue.gd); 0 = the whole line at once
var talk_caps := true                 # people's lines in comic capitals (false: ordinary sentence case, easier to read)
var objectives := true                # the "To do" list under the stats (scripts/objectives.gd)
var high_contrast := false            # solid dark panels, bright text, heavy outlines
var reduce_flashing := false          # no blinking/flashing on hits, calmer glows
var reduce_motion := false            # no camera kick when rolling, calmer bobbing effects
var screen_shake := 1.0               # 0..1: how much the camera shakes on bumps and big pops (scripts/juice.gd)
var rumble := true                    # controller rumble on hits, landings and pops (scripts/juice.gd)
var rumble_strength := 1.0            # 0..1: how strong that rumble is
var bumps := true                     # bumps and boinks when you knock into things (scripts/bumps.gd)
var playtest := false                 # write playtest notes to the save folder (scripts/playtest.gd); off by default
var captions := false                 # show text for important sounds
# --- Assist
var game_speed := 1.0                 # 1.0 = normal; lower gives more time to react
var no_damage := false
var infinite_mp := false
var infinite_sp := false
var skate_assist := 1                 # 0 Relaxed, 1 Normal, 2 Pro (the strict first rules)
var practice_trips := false           # Pause > "Visit a portal world": practice trips for playtesting (Portals.practice_trip())
var race_intros := true               # the flyover of the track and the rivals before a race (scripts/race_intro.gd)

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
	return ["master_volume", "music_volume", "sfx_volume", "voice_volume", "mouse_sensitivity", "stick_sensitivity",
		"invert_y", "invert_x", "fullscreen", "fov", "minimap", "map_hide", "clock_style", "text_scale", "hud_size", "talk_speed", "talk_caps", "objectives", "high_contrast", "reduce_flashing",
		"reduce_motion", "captions", "game_speed", "no_damage", "infinite_mp", "infinite_sp", "control_style", "tips",
		"skate_assist", "screen_shake", "rumble", "rumble_strength", "bumps", "playtest", "race_intros", "practice_trips"]


func hud(px: float) -> int:
	# A size on the playing screen (the HUD): text size times the HUD size
	return roundi(px * text_scale * hud_size)


func set_value(prop: String, value) -> void:
	set(prop, value)
	apply()
	save_settings()


func apply() -> void:
	Audio.set_volume("Master", master_volume)
	Audio.set_volume("Music", music_volume)
	Audio.set_volume("SFX", sfx_volume)
	Audio.set_volume("Voices", voice_volume)
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
	_unstick_modifiers(event)


func _unstick_modifiers(event: InputEvent) -> void:
	# Shift (Roll / sprint / dive) or Ctrl sometimes stayed held down after it was let go (Hayden, 14 Nov playtest:
	# "the shift is getting stuck putting them in descend mode or sprint mode until it's pressed again"): the
	# computer can lose a key's "let go". Every other key and mouse button press says which of those keys are really
	# down, so when one says Shift (or Ctrl, Alt) isn't but the game still thinks it is, let go of it for real.
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	var we := event as InputEventWithModifiers
	if event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return                                      # (the key itself: its own up and down are the truth)
	for pair in [[KEY_SHIFT, we.shift_pressed], [KEY_CTRL, we.ctrl_pressed], [KEY_ALT, we.alt_pressed]]:
		if not pair[1] and Input.is_physical_key_pressed(pair[0]):
			var up := InputEventKey.new()
			up.physical_keycode = pair[0]
			up.keycode = pair[0]
			up.pressed = false
			Input.parse_input_event.call_deferred(up)


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
	if action in FRIEND_MOVES:
		action = "friend"                          # the friend with you does it (scripts/party.gd)
	if last_device != "pad":
		if action in ["quest_log", "map"] and bindings.get(action, 0) == 0:
			action = "player_menu"                 # no key of its own: Tab opens the player menu, quests and map in it
		return key_name(action)
	if action in ["quest_log", "map"] and pad_bindings.get(action, -1) < 0:
		action = "player_menu"                     # no button of its own: Back opens the player menu, quests and map in it
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
	var words := {"moves": moves(), "showers_how": showers_how()}
	for pair in REBINDABLE:
		words[pair[0]] = prompt(pair[0])
	for a in FRIEND_MOVES:
		words[a] = prompt(a)
	return text.format(words)


func showers_how() -> String:
	# How to call April Showers (scripts/showers.gd), said as the start of a sentence. It's Heather's move now, so it's
	# the Friend button with her walking with you (scripts/party.gd)
	return "Press %s with Heather along" % prompt("friend")


func pad_name(action: String) -> String:
	if action in FRIEND_MOVES:
		action = "friend"
	var b: int = pad_bindings.get(action, -1)
	return PAD_NAMES.get(b, "-") if b >= 0 else "-"


# ----------------------------------------------------------------------------- controller buttons
func default_pad_bindings() -> Dictionary:
	return {"jump": JOY_BUTTON_A, "dash": JOY_BUTTON_X, "aim": PAD_LT, "shoot": PAD_RT, "gadget_wheel": JOY_BUTTON_DPAD_UP, "outfit_wheel": JOY_BUTTON_LEFT_STICK, "friend": JOY_BUTTON_RIGHT_SHOULDER, "friend_wheel": JOY_BUTTON_LEFT_SHOULDER, "toggle_skateboard": JOY_BUTTON_Y, "skate_grind": JOY_BUTTON_Y,
		"skate_flip": JOY_BUTTON_X, "skate_grab": JOY_BUTTON_B, "interact": JOY_BUTTON_B, "quest_log": -1,
		"map": -1, "player_menu": JOY_BUTTON_BACK, "check_watch": JOY_BUTTON_DPAD_DOWN, "pause": JOY_BUTTON_START}
	# The quests and the map have no button of their own (-1): Back opens the player menu (scripts/player_menu.gd), and
	# they're its first tabs. LB (the map's old button) is the friend wheel now (scripts/party.gd).


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
	return ([a, b].has("toggle_skateboard") and [a, b].has("skate_grind")) or ([a, b].has("dash") and [a, b].has("skate_flip"))


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
	# RB rolls too, whatever Roll is on. Friend's on RB as well: until a friend's with you RB just rolls, and after that
	# a press that's a friend's move isn't a roll too (scenes/player/player.gd, scripts/party.gd)
	if action == "dash" and button != JOY_BUTTON_RIGHT_SHOULDER:
		var rb := InputEventJoypadButton.new()
		rb.device = -1
		rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
		InputMap.action_add_event(action, rb)


# ----------------------------------------------------------------------------- key bindings
# The skate tricks' keys used to be J, K and L, out under the hand that holds the mouse, so combos were hard to hit
# (Hayden's day 1 playtest, 11 Nov 2026). Now they're all under the left hand, the way the controller shares its
# buttons: Shift flips (it rolls on foot), Ctrl grabs, E grinds (it's the board key too: on a ride, E only steps off on
# the ground with no rail in reach, scripts/game.gd). Settings saved with the old keys move over once (load_settings).
const OLD_SKATE_KEYS := {"skate_grind": KEY_L, "skate_flip": KEY_J, "skate_grab": KEY_K}


func default_bindings() -> Dictionary:
	return {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_SHIFT, "aim": -MOUSE_BUTTON_RIGHT, "shoot": -MOUSE_BUTTON_LEFT, "gadget_wheel": KEY_R, "outfit_wheel": KEY_C, "friend": KEY_Z, "friend_wheel": KEY_X, "toggle_skateboard": KEY_E, "skate_grind": KEY_E, "skate_flip": KEY_SHIFT, "skate_grab": KEY_CTRL,
		"interact": KEY_F, "quest_log": KEY_Q, "map": KEY_M, "player_menu": KEY_TAB, "check_watch": KEY_T, "pause": KEY_ESCAPE}


func rebind(action: String, physical_keycode: int) -> String:
	# Returns the name of another action that already used this key (it gets swapped onto the old key), or "". Like
	# the controller, a key only clashes with actions used at the same time (PAD_GROUPS: on foot, riding), so Shift can
	# roll on foot and flip on the board. Keys for actions in neither group (moving) clash with everything.
	var old: int = bindings.get(action, 0)
	var clash := ""
	for other in bindings:
		if other != action and bindings[other] == physical_keycode and _key_clash(action, other):
			clash = other
			bindings[other] = old
	bindings[action] = physical_keycode
	apply()
	save_settings()
	return clash


func _key_clash(a: String, b: String) -> bool:
	if _shares_on_purpose(a, b):
		return false
	var in_a := PAD_GROUPS.filter(func(g: Array) -> bool: return a in g)
	var in_b := PAD_GROUPS.filter(func(g: Array) -> bool: return b in g)
	if in_a.is_empty() or in_b.is_empty():
		return true
	for g in in_a:
		if b in g:
			return true
	return false


func key_name(action: String) -> String:
	if action in FRIEND_MOVES:
		action = "friend"
	var code: int = bindings.get(action, 0)
	if code == 0:
		return "-"
	if code < 0:
		return MOUSE_NAMES.get(-code, "Mouse %d" % -code)
	if DisplayServer.get_name() == "headless":
		return OS.get_keycode_string(code)          # no keyboard layout to ask (automated tests)
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code as Key))   # e.g. Z on AZERTY


func action_shown(action: String) -> bool:
	# Whether Settings > Controls lists it yet. The friends' moves have no button of their own (FRIEND_MOVES), so for
	# them it says whether the move's been learned: Burrow once the Rootmind is mended (scripts/burrow.gd), Frost
	# breath once the Frozen Moment is (frost_breath.gd), Groove once Rhythm Springs is (groove.gd), April Showers once
	# Glenmoor is (showers.gd) and Make once Nina and Bruno teach it (make.gd)
	if action == "friend" or action == "friend_wheel":
		# The Friend button once a friend's joined you, and Switch friend once there's more than one to switch between
		var party := get_node_or_null("/root/Party")
		return party != null and party.joined.size() >= (2 if action == "friend_wheel" else 1)
	if SECRET_FLAGS.has(action):
		var dialogue := get_node_or_null("/root/Dialogue")
		return dialogue != null and dialogue.flags.has(SECRET_FLAGS[action])
	if SECRET_ACTIONS.has(action):
		var portals := get_node_or_null("/root/Portals")
		return portals != null and portals.is_cleared(SECRET_ACTIONS[action])
	return true


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
	cf.set_value("settings", "minimap_v2", true)
	cf.set_value("settings", "skate_keys_v2", true)
	cf.set_value("settings", "menus_v2", true)
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
	# The minimap used to start off. Settings saved before it was on by default get it switched on once (the
	# "minimap_v2" mark says that's been done), and after that it stays however the player leaves it.
	if not cf.has_section_key("settings", "minimap_v2"):
		minimap = true
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
	if not cf.has_section_key("settings", "skate_keys_v2"):
		for a in OLD_SKATE_KEYS:
			if bindings.get(a, 0) == OLD_SKATE_KEYS[a]:
				var want: int = default_bindings()[a]
				for other in bindings:
					if other != a and bindings[other] == want and _key_clash(a, other):
						want = 0                            # the player's put something else there: leave this one
						break
				if want != 0:
					bindings[a] = want
	if not cf.has_section_key("settings", "menus_v2"):
		_one_menu()
	_free_board_shoot()


func _one_menu() -> void:
	# Settings saved before the quests and the map were only tabs of the one menu: on a controller they lose their own
	# buttons, and the friend wheel moves from D-pad left onto LB (the map's old button) if nothing else is there, so
	# D-pad left goes back to picking gadgets (scripts/gadget_wheel.gd).
	pad_bindings["quest_log"] = -1
	pad_bindings["map"] = -1
	if pad_bindings.get("friend_wheel", -1) == JOY_BUTTON_DPAD_LEFT and not pad_bindings.values().has(JOY_BUTTON_LEFT_SHOULDER):
		pad_bindings["friend_wheel"] = JOY_BUTTON_LEFT_SHOULDER


func _free_board_shoot() -> void:
	# Shoot works on the board too now (scripts/star_popper.gd), so a button the player gave it back when it was
	# only for walking may also be a skate trick's. Then Shoot goes back to RT, and whatever was on RT gets Shoot's
	# old button if it's only used on foot, or its own first button if it's used on the board too.
	var mine: int = pad_bindings.get("shoot", -1)
	if mine < 0:
		return
	for other in PAD_GROUPS[1]:
		if other != "shoot" and pad_bindings.get(other, -1) == mine and not _shares_on_purpose("shoot", other):
			for a in pad_bindings:
				if a != "shoot" and pad_bindings[a] == PAD_RT:
					pad_bindings[a] = mine if not a in PAD_GROUPS[1] else default_pad_bindings().get(a, -1)
			pad_bindings["shoot"] = PAD_RT
			return


func _claim(table: Dictionary, action: String, defaults: Dictionary, none: int) -> void:
	var mine: int = defaults.get(action, none)
	for other in table:
		# Only one the player moved there: some start out sharing on purpose (X rolls and flips)
		if other != action and table[other] == mine and table[other] != defaults.get(other, none):
			var own: int = defaults.get(other, none)
			table[other] = own if not table.values().has(own) else none
