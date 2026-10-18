extends SceneTree

# One-off project setup: adds the input actions and autoloads that the pause menu, dash, beds and audio need, with
# controller support, and saves project.godot. Safe to re-run (it overwrites these entries with the same values).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/setup_input.gd


func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1                        # any keyboard
	e.physical_keycode = code as Key
	return e


func pad_button(i: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1                        # any controller
	e.button_index = i as JoyButton
	return e


func pad_axis(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis as JoyAxis
	e.axis_value = value
	return e


func set_action(name: String, events: Array, deadzone := 0.2) -> void:
	ProjectSettings.set_setting("input/" + name, {"deadzone": deadzone, "events": events})


func _initialize() -> void:
	# Movement: keyboard + left stick
	set_action("move_forward", [key(KEY_W), pad_axis(JOY_AXIS_LEFT_Y, -1.0)])
	set_action("move_back", [key(KEY_S), pad_axis(JOY_AXIS_LEFT_Y, 1.0)])
	set_action("move_left", [key(KEY_A), pad_axis(JOY_AXIS_LEFT_X, -1.0)])
	set_action("move_right", [key(KEY_D), pad_axis(JOY_AXIS_LEFT_X, 1.0)])
	# Buttons (Xbox layout names; PlayStation: A=Cross, B=Circle, X=Square, Y=Triangle)
	set_action("jump", [key(KEY_SPACE), pad_button(JOY_BUTTON_A)])
	set_action("dash", [key(KEY_SHIFT), pad_button(JOY_BUTTON_X), pad_button(JOY_BUTTON_RIGHT_SHOULDER)])
	set_action("toggle_skateboard", [key(KEY_E), pad_button(JOY_BUTTON_Y)])
	set_action("interact", [key(KEY_F), pad_button(JOY_BUTTON_B)])          # talk to people, sleep in a bed
	set_action("pause", [key(KEY_ESCAPE), key(KEY_P), pad_button(JOY_BUTTON_START)])
	set_action("debug_xp", [key(KEY_X)])
	# Camera: right stick
	set_action("look_left", [pad_axis(JOY_AXIS_RIGHT_X, -1.0)], 0.15)
	set_action("look_right", [pad_axis(JOY_AXIS_RIGHT_X, 1.0)], 0.15)
	set_action("look_up", [pad_axis(JOY_AXIS_RIGHT_Y, -1.0)], 0.15)
	set_action("look_down", [pad_axis(JOY_AXIS_RIGHT_Y, 1.0)], 0.15)

	# Autoloads, in start-up order: Clock before Game (loading a save sets the time), Audio before Settings (Settings
	# sets the volumes), PauseMenu last
	for pair in [["Clock", "res://scripts/clock.gd"], ["Game", "res://scripts/game.gd"], ["Audio", "res://scripts/audio.gd"],
			["Settings", "res://scripts/settings.gd"], ["Dialogue", "res://scripts/dialogue.gd"],
			["PauseMenu", "res://scripts/pause_menu.gd"]]:
		ProjectSettings.set_setting("autoload/" + pair[0], "*" + pair[1])
	print("save=", ProjectSettings.save())
	quit()
