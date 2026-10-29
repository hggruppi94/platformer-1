extends SceneTree

# Checks life on Earth and the trips to Galaxity: a new game starting at home on Earth, the people and Mr. Palmer's
# lights quest, the portal by the old oak asleep until midnight, through it to Galaxity in the Shift (its day at full
# speed, Earth's clock crawling), home early and back (the portals, the pause menu), the warning at Galaxity's 6 AM,
# being pulled home at the end of the Shift, and a save made in Galaxity in the Shift loading there. Run it twice.
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
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))

	# A new game starts at home on Earth, just out of bed, on an evening before the first Shift
	game.new_game()
	await _wait_for_scene(EARTH)
	var player := current_scene.find_child("Player", true, false) as Node3D
	var home := current_scene.find_child("My Home", true, false) as Node3D
	check(current_scene.scene_file_path == EARTH and player != null and home != null, "a new game starts on Earth")
	var spawn := home.find_child("HomeSpawn", true, false) as Node3D
	check(player.global_position.distance_to(spawn.global_position) < 1.5, "...at home, just out of bed")
	check(home.find_child("SleepSpot", true, false) != null and home.find_child("CreatorSpot", true, false) != null,
		"the house has a bed and a spot for the character creator")
	check(clock.on_earth and clock.earth_time_string() == "8:00 PM" and not clock.in_shift() and clock.day == 1,
		"Earth 8:00 PM, before the Shift; Galaxity waits on day 1")
	await _frames(4)
	var hud := player.get_node("HUD")
	check(str(hud.message_label.text).contains("At midnight the portal"), "\"%s\"" % hud.message_label.text)
	hud._refresh_clock()
	check(hud.clock_label.text.begins_with("Earth") and hud.clock_label.text.contains("opens at midnight"),
		"the HUD: \"%s\"" % hud.clock_label.text.replace("\n", " / "))

	# Outside the Shift the portal by the old oak is asleep
	var portal := current_scene.find_child("PortalToGalaxity", true, false) as Node3D
	await _walk_into(portal)
	check(current_scene.scene_file_path == EARTH and messages.any(func(m: String) -> bool: return m.contains("asleep")),
		"8 PM: the portal's asleep")
	check(not (current_scene.find_child("Portal Swirl", true, false) as Node3D).visible, "...no swirl in it")

	# The people, and Mr. Palmer's lights
	var palmer := _talker("palmer_earth")
	check(palmer != null and _talker("ivy") != null and _talker("theo") != null, "Mr. Palmer (in person), Miss Ivy and Theo are here")
	var hello := await _talk(palmer)
	check(_said(hello, "just plain old Mr. Palmer") and _said(hello, "neighbour"), "Mr. Palmer, a neighbour, keeps his Galaxity side a secret")
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

	# Midnight: the Shift begins, and the portal opens
	clock.set_earth_time(23 * 60.0 + 59.7, true)
	await create_timer(3.0).timeout
	check(clock.in_shift() and messages.any(func(m: String) -> bool: return m.contains("the Shift has begun")),
		"midnight on Earth: the Shift has begun")
	check((current_scene.find_child("Portal Swirl", true, false) as Node3D).visible, "...and the portal swirls open")
	await _walk_into(current_scene.find_child("PortalToGalaxity", true, false))
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN and not clock.on_earth, "through the portal to Galaxity")
	player = current_scene.find_child("Player", true, false) as Node3D
	var by_portal := current_scene.find_child("FromPortaltoEarth", true, false) as Node3D
	check(player.global_position.distance_to(by_portal.global_position) < 1.5, "...arriving by Galaxity's portal")
	check(clock.day == 1 and clock.hour() == 7, "Galaxity's day 1 has just begun: %s" % clock.time_string())
	hud = player.get_node("HUD")
	hud._refresh_clock()
	check(hud.clock_label.text.begins_with("Day 1") and hud.clock_label.text.contains("The Shift (Earth 12:0"),
		"the HUD: \"%s\"" % hud.clock_label.text.replace("\n", " / "))

	# Galaxity's day goes by at full speed while Earth's clock crawls
	var g0: float = clock.minutes
	var e0: float = clock.earth_minutes
	await create_timer(3.0).timeout
	var g_rate: float = (clock.minutes - g0) / 3.0
	var e_rate: float = (clock.earth_minutes - e0) / 3.0
	check(absf(g_rate - 1440.0 / (clock.DAY_LENGTH_MINUTES * 60.0)) < 0.05, "Galaxity's day runs at full speed (%.2f min/s)" % g_rate)
	check(absf(e_rate * clock.SHIFT_RATIO - g_rate) < 0.05, "Earth's clock crawls along, %dx slower (%.3f min/s)" % [int(clock.SHIFT_RATIO), e_rate])

	# Home early and back again: Galaxity's portal, the pause menu both ways
	await _walk_into(current_scene.find_child("Portal to Earth", false, false).find_child("Door", true, false))
	await _wait_for_scene(EARTH)
	check(current_scene.scene_file_path == EARTH and clock.in_shift(), "Galaxity's portal takes her home early, still in the Shift")
	player = current_scene.find_child("Player", true, false) as Node3D
	check(player.global_position.distance_to(current_scene.find_child("Entrance", false, false).global_position) < 1.5,
		"...by the old oak")
	var pause := root.get_node("PauseMenu")
	var way: Array = pause.way_home()
	check(way.size() == 1 and way[0][0] == "Go through the portal to Galaxity", "on Earth in the Shift, the pause menu has \"%s\"" % [way[0][0] if way.size() else "nothing"])
	if way.size():
		way[0][1].call()
	await _wait_for_scene(TOWN)
	check(current_scene.scene_file_path == TOWN, "...back to Galaxity")
	way = pause.way_home()
	check(way.size() == 1 and way[0][0] == "Go home to Earth", "in Galaxity, the pause menu has \"%s\"" % [way[0][0] if way.size() else "nothing"])

	# Near the end: Galaxity's dawn is coming. Then the Shift ends and the portal pulls her home.
	clock.set_time(2, 5 * 60.0 + 59.9, true)
	await create_timer(1.0).timeout
	check(messages.any(func(m: String) -> bool: return m.contains("the portal will pull you home")), "6 AM in Galaxity: the portal will pull her home soon")
	clock.set_time(2, 6 * 60.0 + 59.5, true)
	await _wait_for_scene(EARTH, 600)
	check(current_scene.scene_file_path == EARTH and not clock.in_shift(), "Galaxity's dawn, Earth's 1 AM: the Shift's over and she's home")
	check(clock.day == 2 and clock.time_string() == "7:00 AM" and clock.earth_time_string() == "1:00 AM",
		"Galaxity waits at day 2's dawn (%s), Earth %s" % [clock.time_string(), clock.earth_time_string()])
	player = current_scene.find_child("Player", true, false) as Node3D
	check(player.global_position.distance_to(current_scene.find_child("Entrance", false, false).global_position) < 1.5,
		"...by the old oak")
	await _frames(4)
	var told: String = player.get_node("HUD").message_label.text
	check(told.contains("home to Earth"), "\"%s\"" % told)
	check(pause.way_home().is_empty(), "on Earth after the Shift there's no portal shortcut")

	# A save made in Galaxity in the Shift (the second run checks she stays there)
	clock.set_earth_time(23 * 60.0 + 59.0, true)
	clock.set_earth_time(30.0, true)
	game.go(TOWN, "FromPortaltoEarth")
	await _wait_for_scene(TOWN)
	game.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data.get("scene", "") == TOWN and is_equal_approx(float(data.get("earth_minutes", 0)), clock.earth_minutes),
		"saved in Galaxity, in the Shift (Earth %s, Galaxity %s)" % [clock.earth_time_string(), clock.time_string()])
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _check_load() -> void:
	# (Your own save goes back at the very end: this run changes scenes, and arriving anywhere autosaves. If anything
	# goes wrong, the time-out puts it back too.)
	check(quests.is_done("earth_lights"), "loaded: the lights quest is done")
	check(game._resume.get("scene", "") == TOWN and clock.in_shift() and absf(clock.earth_minutes - 30.0) < 1.0,
		"the save says she's in Galaxity, in the Shift (Earth %s)" % clock.earth_time_string())
	# Start up as the game does: the main scene (Earth), then on to where she saved
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await _frames(4)
	game._go_to_saved_scene()
	await _wait_for_scene(TOWN, 240)
	await create_timer(2.0).timeout
	check(current_scene != null and current_scene.scene_file_path == TOWN and clock.in_shift() and not clock.on_earth,
		"she's back in Galaxity, and the Shift goes on (%s)" % (current_scene.scene_file_path if current_scene else "none"))
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
