extends SceneTree

# Checks the trip through the portal to Earth: only during the Shift, Earth's own clock (Galaxity's crawls while
# she's there), the people and Mr. Palmer's lights quest, the warning, being pulled home when the Shift ends, going
# home early (the portal, the pause menu), and a save made on Earth after the Shift sending her home. Run it twice.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_earth.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_earth.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var said: Array = []
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(230.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		if "--check-load" in OS.get_cmdline_user_args():
			_put_save_back()
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	dialogue.reset()
	quests.reset()
	game.sparkles = 0
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	change_scene_to_file(TOWN)
	await _frames(6)

	# Outside the Shift the portal's asleep
	clock.set_time(1, 22 * 60.0, true)
	await _frames(4)
	await _walk_into(current_scene.find_child("Portal to Earth", false, false).find_child("Door", true, false))
	check(current_scene.scene_file_path == TOWN and messages.any(func(m: String) -> bool: return m.contains("asleep")), "10 PM: the portal's asleep")

	# In the Shift: through to Earth
	clock.set_time(2, 10.0, true)
	await create_timer(3.0).timeout                           # the swirl opens
	await _walk_into(current_scene.find_child("Portal to Earth", false, false).find_child("Door", true, false))
	await _wait_for_scene(EARTH)
	check(current_scene.scene_file_path == EARTH, "12:10 AM, the Shift: through the portal to Earth")
	var player := current_scene.find_child("Player", true, false) as Node3D
	check(player.global_position.distance_to(current_scene.find_child("Entrance", false, false).global_position) < 1.5, "she arrives by the old oak")
	check(clock.on_earth and dialogue.flags.has("visited_earth"), "on Earth (remembered)")
	await _frames(3)
	check(messages.any(func(m: String) -> bool: return m.contains("the portal will pull you home")), "told she'll be pulled home when the Shift ends")
	var hud := player.get_node("HUD")
	await create_timer(3.5).timeout
	check(hud.clock_label.text.begins_with("Earth"), "the HUD shows Earth's time: \"%s\"" % hud.clock_label.text.replace("\n", " / "))

	# Time: Earth's evening goes by while Galaxity's Shift crawls
	var g0: float = clock.minutes
	var e0: float = clock.earth_minutes
	await create_timer(3.0).timeout
	var g_rate: float = (clock.minutes - g0) / 3.0
	var e_rate: float = (clock.earth_minutes - e0) / 3.0
	var shift_rate: float = clock.MINUTES_PER_DAY / (clock.DAY_LENGTH_MINUTES * 60.0) / clock.SHIFT_SLOWDOWN
	check(absf(g_rate - shift_rate / clock.EARTH_SLOWDOWN) < 0.01, "Galaxity's clock crawls on Earth (%.3f min/s, %dx slower than the Shift)" % [g_rate, int(clock.EARTH_SLOWDOWN)])
	check(e_rate > g_rate * 4.0, "Earth's own evening goes much faster (%.2f min/s)" % e_rate)
	var real_minutes: float = 60.0 / (shift_rate / clock.EARTH_SLOWDOWN) / 60.0
	check(real_minutes > 10.0, "a whole Shift on Earth lasts %.0f real minutes" % real_minutes)

	# The people, and Mr. Palmer's lights
	var palmer := _talker("palmer_earth")
	check(palmer != null and _talker("ivy") != null and _talker("theo") != null, "Mr. Palmer (in person), Miss Ivy and Theo are here")
	var hello := await _talk(palmer)
	check(_said(hello, "just plain old Mr. Palmer"), "Mr. Palmer keeps his Galaxity side a secret")
	var ask := await _talk(_talker("palmer_earth"), [0])
	check(_said(ask, "string lights") and quests.on_step("earth_lights", "find"), "the hook quest: find the gazebo's lights")
	var boxes := current_scene.find_children("Light Box *", "Area3D", true, false)
	check(boxes.size() == 3, "three boxes of lights round the green")
	dialogue.talks["theo"] = 1                              # they've met
	var tip := await _talk(_talker("theo"))
	check(_said(tip, "by the bookshop window"), "Theo has a hint")
	for b in boxes:
		var ok := await _use_spot(b)
		check(ok and dialogue.flags.has(b.get("flag")), "picked up %s" % b.name)
	check(quests.on_step("earth_lights", "bring"), "all three: take them to Mr. Palmer")
	var lit_before: bool = (current_scene.find_child("Gazebo Lights", true, false) as Node3D).visible
	await _talk(_talker("palmer_earth"))
	await _frames(2)
	check(not lit_before and (current_scene.find_child("Gazebo Lights", true, false) as Node3D).visible, "the gazebo lights up")
	check(quests.is_done("earth_lights") and game.sparkles == 8, "quest done, +8 sparkles")

	# Nearly time; then the Shift ends and the portal pulls her home
	clock.minutes = 50.5
	await _frames(3)
	check(messages.any(func(m: String) -> bool: return m.contains("nearly over")), "12:50: the portal flickers, nearly time to go")
	clock.minutes = 59.98
	await _wait_for_scene(TOWN, 600)
	check(current_scene.scene_file_path == TOWN and not clock.in_shift(), "1 AM: the Shift's over and she's home")
	player = current_scene.find_child("Player", true, false) as Node3D
	var by_portal := current_scene.find_child("FromPortaltoEarth", true, false) as Node3D
	check(player.global_position.distance_to(by_portal.global_position) < 1.5 and not clock.on_earth, "...right by the portal")
	await _frames(4)
	var told: String = player.get_node("HUD").message_label.text
	check(told.contains("pulls Nina home"), "\"%s\"" % told)

	# Going home early: the pause menu, and the portal by the oak
	clock.set_time(3, 5.0, true)
	game.go(EARTH, "Entrance")
	await _wait_for_scene(EARTH)
	var pause := root.get_node("PauseMenu")
	pause.open()
	await _frames(2)
	var buttons := pause.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Go back through the portal")
	check(buttons.size() == 1, "on Earth the pause menu has \"Go back through the portal\"")
	if buttons.size():
		buttons[0].pressed.emit()
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN and not paused, "...home early")
	game.go(EARTH, "Entrance")
	await _wait_for_scene(EARTH)
	await _walk_into(current_scene.find_child("PortalHome", true, false))
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN, "walking into the portal by the oak goes home too")

	# A save made on Earth, opened after the Shift's ended (phase 2 checks she's sent home)
	game.go(EARTH, "Entrance")
	await _wait_for_scene(EARTH)
	game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data.get("scene", "") == EARTH and data.has("earth_minutes"), "saved on Earth (with Earth's time)")
	data["minutes"] = 3 * 60.0                                     # pretend she closed the game and the Shift's long over
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	# (Your own save goes back at the very end: this run changes scenes, and arriving anywhere autosaves. If anything
	# goes wrong, the time-out puts it back too.)
	check(quests.is_done("earth_lights"), "loaded: the lights quest is done")
	check(game._resume.get("scene", "") == EARTH, "the save says she's on Earth")
	# Start up as the game does: the main scene, then on to where she saved (Earth), which sends her home
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _frames(4)
	game._go_to_saved_scene()
	for i in 240:
		await process_frame
		if current_scene and current_scene.scene_file_path == TOWN:
			break
	await _frames(6)
	check(current_scene != null and current_scene.scene_file_path == TOWN and not clock.on_earth,
		"a save on Earth after the Shift: she's sent home (%s)" % (current_scene.scene_file_path if current_scene else "none"))
	await _frames(4)
	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


# -----------------------------------------------------------------------------
func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _walk_into(area: Node3D) -> void:
	# Step away first (a door only notices her coming in), then into it
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	player.global_position = area.global_position + Vector3(0, 0.5, 8.0)
	for i in 4:
		await physics_frame
	player.global_position = area.global_position + Vector3(0, -0.5, 0)
	player.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame
	await _frames(3)


func _use_spot(spot: Area3D) -> bool:
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	for k in 8:
		player.global_position = spot.global_position + Vector3(1.0, 0.8, 0).rotated(Vector3.UP, k * TAU / 8.0)
		player.velocity = Vector3.ZERO
		for i in 6:
			await physics_frame
		await _frames(2)
		if dialogue._nearest == spot:
			_press("interact")
			await _frames(3)
			return true
	return false


func _talk(t: Area3D, picks: Array = []) -> Array:
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var body := t.get_parent() as Node3D
	player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame
	said.clear()
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick].grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")
			await _frames(1)
			_press("interact")
		await _frames(2)
	await create_timer(0.25).timeout
	return said.duplicate()


func _wait_for_scene(path: String, frames := 150) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
