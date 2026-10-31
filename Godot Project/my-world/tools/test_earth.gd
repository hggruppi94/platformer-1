extends SceneTree

# Checks life on Earth and the trips to Galaxity: a new game starting at home on Earth, the people and Mr. Palmer's
# lights quest, the portal by the old oak asleep until midnight, through it to Galaxity in the Shift (its day at full
# speed, Earth's clock crawling), home early and back (the portals, the pause menu), the warning at Galaxity's 6 AM,
# being pulled home at the end of the Shift, and a save made in Galaxity in the Shift loading there. Run it twice.
# Also the grown-up town (since Oct 30, 2026): every place there, a way in to every walk-in building, nothing floating,
# the ground's pond and hill, wading, the skate spots, the Earth map, and an old save made on Earth waking up at home.
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

	await _town_layout()

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

	# An old save made out on Earth, from before the town grew, wakes up at home (where she stood might be a shop now)
	game.save_game()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	old.erase("earth_layout")
	old["scene"] = EARTH
	old["position"] = [10.0, 1.0, -46.0]                      # (in the middle of what's now the antique shop)
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	game.load_game()
	check(game._resume.get("scene", "") == EARTH and not game._resume.has("position") and game.next_spawn == "HomeSpawn",
		"an old save from out on Earth wakes up at home (%s, spawn %s)" % [game._resume, game.next_spawn])
	check(str(game.pending_message).contains("grown"), "...and says the town's grown: \"%s\"" % game.pending_message)
	game._resume = {}
	game.next_spawn = ""
	game.pending_message = ""

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


# -----------------------------------------------------------------------------
# The grown-up town
# -----------------------------------------------------------------------------
const PLACES := ["Bakery", "Toy Shop", "Library", "Earth Town Hall", "Fire Station", "Antiques", "Hardware Store", "School",
	"Blastoff House", "Palmer House", "Maple House 1", "Maple House 2", "Maple House 3", "Maple House 4", "Maple House 5",
	"Maple House 6", "Hollow Skate Yard", "Covered Bridge", "Hollow Diner", "Bookshop", "Corner Market", "Maple Inn",
	"Dance Studio", "My Home", "Water", "Park"]
const INSIDES := ["Bakery", "Toy Shop", "Library", "Earth Town Hall", "Blastoff House"]


func _town_layout() -> void:
	var s := current_scene
	var missing := PLACES.filter(func(n: String) -> bool: return s.find_child(n, true, false) == null)
	check(missing.is_empty(), "every place in town is there (missing: %s)" % [missing])
	for n in ["Footbridge", "Dock", "Playground", "Pumpkin Patch", "Lookout", "Waterfall", "Big Air Kicker", "Hill Rail", "Loading Dock"]:
		check(s.find_child(n, true, false) != null, "the park and town have the %s" % n)
	var space := (s as Node3D).get_world_3d().direct_space_state
	var player := s.find_child("Player", true, false) as CharacterBody3D
	await physics_frame

	# The ground: flat round the green, the pond's bowl, the hill's top
	check(absf(_ground_y(space, Vector3(7, 0, 7)) - 0.0) < 0.2, "the green's flat ground is there")
	check(_ground_y(space, Vector3(EarthLand.POND.x, 0, EarthLand.POND.y)) < -1.4, "Willow Pond is a bowl in the ground")
	check(absf(_ground_y(space, Vector3(EarthLand.HILL.x, 0, EarthLand.HILL.y)) - EarthLand.HILL_TOP) < 0.3, "Lookout Hill rises %.1f m" % EarthLand.HILL_TOP)

	# A way in to every walk-in building: nothing between just outside the door and the middle of the room, and a floor
	for n in INSIDES:
		var b := s.find_child(n, true, false) as Node3D
		var door := b.get_node_or_null("Doorway") as Node3D
		var inside := b.get_node_or_null("Inside") as Node3D
		if door == null or inside == null:
			check(false, "%s has a doorway and an inside" % n)
			continue
		var clear := _capsule_clear(space, door.global_position + Vector3(0, 0.1, 0), inside.global_position + Vector3(0, 0.1, 0), player)
		var floor_y := _ground_y(space, inside.global_position)
		check(clear and absf(inside.global_position.y - 1.0 - floor_y) < 0.4, "walk into the %s (clear: %s, floor %.2f)" % [n, clear, floor_y])
	# The Blastoffs: a bedroom each, through their own doorways
	var house := s.find_child("Blastoff House", true, false) as Node3D
	for kid in ["Nina", "Prue", "Bruno"]:
		var room := house.get_node_or_null("%s's Room" % kid) as Node3D
		var ok := room != null
		if ok:
			# Across the living room to the bedroom's door, then in
			var at_door := house.to_global(Vector3(room.position.x, 1.1, 0.8))
			var in_room := house.to_global(room.position + Vector3(0, 1.1, 0.5))
			ok = _capsule_clear(space, house.get_node("Inside").global_position + Vector3(0, 0.1, 0), at_door, player) \
				and _capsule_clear(space, at_door, in_room, player)
		check(ok, "into %s's room" % kid)

	# Nothing floating: every building stands on the ground (the library on its stone base), every tree and lamp too
	var floating := []
	for n in PLACES:
		var node := s.find_child(n, true, false) as Node3D
		if node == null or n in ["Water", "Park", "Covered Bridge"]:                # (the bridge spans the creek)
			continue
		var y := node.global_position.y - (1.2 if n == "Library" else 0.0)
		if absf(y - EarthLand.height(node.global_position.x, node.global_position.z)) > 0.25:
			floating.append(n)
	var trees := 0
	for t in s.get_node("Autumn Trees").get_children():
		if t is StaticBody3D:
			trees += 1
			var foot := (t as Node3D).global_position - Vector3(0, 1.0, 0)
			if absf(foot.y - EarthLand.height(foot.x, foot.z)) > 0.25:
				floating.append("a tree at %s" % foot)
	for l in s.get_tree().get_nodes_in_group("earth_lamps"):
		var lp := (l as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lp, lp + Vector3(0, -12, 0)))
		if hit.is_empty():
			floating.append("a lamp at %s" % lp)
	check(floating.is_empty() and trees > 150, "nothing floating (%d trees): %s" % [trees, floating.slice(0, 5)])

	# Wading into the pond
	player.global_position = Vector3(EarthLand.POND.x, EarthLand.height(EarthLand.POND.x, EarthLand.POND.y) + 1.0, EarthLand.POND.y)
	player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	check(player.call("in_zone", "water"), "she can wade into Willow Pond")
	player.global_position = Vector3(-6, 1.0, 22)
	player.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame
	check(not player.call("in_zone", "water"), "...and out again")

	# Skating: the yard's grind lines, the hill rail all the way down, the big kickers, handrails on the library steps
	var yard := s.find_child("Hollow Skate Yard", true, false)
	var yard_lines := yard.find_children("*", "GrindRail", true, false).size()
	var hill_rail: Array = s.find_child("Hill Rail", true, false).find_children("*", "GrindRail", true, false)
	var drop := 0.0
	if hill_rail.size() > 0:
		var c: Curve3D = hill_rail[0].curve
		drop = c.get_point_position(0).y - c.get_point_position(c.point_count - 1).y
	var lib_rails := s.find_child("Library", true, false).find_children("Handrail*", "GrindRail", true, false).size()
	check(yard_lines >= 12 and drop > 5.0 and lib_rails == 2, "skate lines: %d in the yard, the hill rail drops %.1f m, %d library handrails" % [yard_lines, drop, lib_rails])
	check(yard.find_child("Big Vert East", true, false) != null and yard.find_child("Gap Kicker", true, false) != null, "the Big Vert and the gap jump")

	# The Earth map knows the town, and draws it on the map sheet and the minimap
	var tm := root.get_node("TownMap")
	check(tm.on_earth(), "the map knows it's on Earth")
	var names: Array = tm._earth.buildings.map(func(b: Array) -> String: return str(b[0]))
	var off_map := []
	for n in ["Crumb & Cauldron Bakery", "Gizmo & Gumdrop Toys", "Lantern Hill Library", "Town Hall", "Fire Station No. 1",
			"Cobweb Corner Antiques", "Nuts & Bolts Hardware", "Old Oak Elementary", "Hollow Skate Yard", "Hollow Diner",
			"Turn the Page Books", "Corner Market", "Maple Inn", "Home", "Dance Studio", "Covered Bridge"]:
		if not n in names:
			off_map.append(n)
	for b in tm._earth.buildings:
		var at: Vector2 = tm.to_map(Vector3(float(b[1]), 0, float(b[2])))
		if at.x < 0.0 or at.x > 1.0 or at.y < 0.0 or at.y > 1.0:
			off_map.append(str(b[0]) + " (outside the picture)")
	check(off_map.is_empty(), "the map shows every place (missing: %s)" % [off_map])
	var p_on_map: Vector2 = tm.to_map(player.global_position)
	check(p_on_map.x > 0.0 and p_on_map.x < 1.0 and p_on_map.y > 0.0 and p_on_map.y < 1.0, "...and where she is")

	# The people (tools/test_townsfolk.gd checks them properly): everyone's routine runs on Earth's paths, every place
	# in their day can be walked to from the portal, and they're on the map
	var earth_paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var lost := []
	var folk := 0
	for r in get_nodes_in_group("routines"):
		folk += 1
		for b in r.blocks:
			if not r.earth or earth_paths.route("old_oak", str(b.place)).is_empty():
				lost.append("%s: %s" % [r.character_id, b.place])
	check(folk >= 18 and lost.is_empty(), "%d people live here, and every place in their day can be reached (%s)" % [folk, lost])
	var on_map: Array = tm.people()
	check(on_map.size() == folk and on_map.all(func(p: Dictionary) -> bool:
		var m: Vector2 = tm.to_map(p.pos)
		return m.x > 0.0 and m.x < 1.0 and m.y > 0.0 and m.y < 1.0), "...and they're all on the map")

	# Back home to carry on
	var spawn := s.find_child("HomeSpawn", true, false) as Node3D
	player.global_position = spawn.global_position
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame


func _ground_y(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var from := at if at.y > 0.5 else Vector3(at.x, 30.0, at.z)         # (from a point indoors: straight down from there)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -10.0, at.z)))
	return float(hit.position.y) if not hit.is_empty() else -99.0


func _capsule_clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, player: CollisionObject3D) -> bool:
	# Whether someone her size can walk straight from a to b
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), a + Vector3(0, 0.15, 0))
	q.motion = b - a
	q.exclude = [player.get_rid()]
	q.collide_with_areas = false
	var r := space.cast_motion(q)
	return r.size() == 2 and r[0] >= 0.999
