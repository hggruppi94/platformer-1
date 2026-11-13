extends SceneTree

# Checks the cracks between worlds and the Divine Mind's voice (Hayden, 12 Nov 2026, lore bible v2 part 3 items 1 to 4:
# "the cracks ARE the portals", the oak hums for the Divine Mind and can be touched for a hint, no portal time limit):
#   - on Earth there's no crack by the old oak before the first Shift it opens in (no spoilers), then at midnight one
#     splits the ground open in front of the oak, a real hole, and jumping in takes you to the Void;
#   - in the Void the ring is gone from the way back to Earth: it's a crack too, and jumping in takes you home;
#   - at 1 AM the Earth crack closes over again;
#   - touching the oak: its hum, the voice in your mind (the first time it says it chose you), and a hint that only
#     points at what's already happened (an open crack) or what you're already doing (your quest), never ahead;
#   - the voice speaks without stopping play, a line at a time.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_cracks.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.cracks_test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var portals: Node
var mind: Node
var oak: Node
var crack_mod
var loading: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	portals = root.get_node("Portals")
	mind = root.get_node("DivineMind")
	oak = root.get_node("HummingOak")
	loading = root.get_node("Loading")
	crack_mod = load("res://scripts/crack.gd")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Settings").tips = false
	game.new_game()
	await _wait_for_scene(EARTH)
	check(current_scene.scene_file_path == EARTH and clock.on_earth and not clock.in_shift(), "a new game, on Earth before the Shift")

	# --- No crack before it first opens ---
	await _frames(4)
	check(current_scene.get("crack") == null and not dialogue.flags.has("earth_crack_seen"), "no crack by the old oak yet (no spoilers)")
	var door := current_scene.find_child("PortalToGalaxity", true, false) as Node3D
	var oak_node := current_scene.get_node("Portal Home/Old Oak") as Node3D
	check(door.global_position.distance_to(oak_node.global_position) < 4.0, "...the old way through is still tucked in the oak")

	# --- Touching the oak ---
	if oak.awake():
		var lines: Array = oak.lines()
		var voice := lines.filter(func(l) -> bool: return l is Dictionary and l.get("speaker", "") == mind.SPEAKER)
		check(str(lines[0]).contains("humming"), "touching the old oak: it hums right through you")
		check(voice.size() >= 2 and str(voice[0].text).contains("I chose you"), "...and a voice in your mind says it chose you")
		lines = oak.lines()
		voice = lines.filter(func(l) -> bool: return l is Dictionary and l.get("speaker", "") == mind.SPEAKER)
		check(not voice.any(func(l) -> bool: return str(l.text).contains("I chose you")) and voice.size() >= 1,
			"the next time it just gives a hint (%s)" % (str(voice[0].text) if voice else ""))
	else:
		check(false, "the oak should be awake on a test's new game")
	# A hint never looks ahead: an open crack, else what you're doing, else rest
	portals.quakes = ["shard_isle"]
	var hint: Array = mind.hint()
	check(str(hint[0]).contains("crack lies open") and str(hint[0]).contains("Observatory Hill"), "with a crack open, the hint points to it")
	portals.cleared_worlds = ["shard_isle"]
	hint = mind.hint()
	check(not str(hint).contains("crack lies open"), "...not once that world's mended")
	portals.quakes = []
	portals.cleared_worlds = []
	check(not str(mind.hint()).to_lower().contains("agent") and not str(mind.hint()).to_lower().contains("chaos"), "...and never names what's to come")

	# --- The voice: a line at a time, without stopping play ---
	mind.clear()
	mind.say(["One.", "Two."])
	check(mind.speaking() and mind._text.text == "One." and not dialogue.is_active(), "the voice shows its first line, and play goes on")
	await create_timer(mind.MIN_TIME + 0.6).timeout
	check(mind._text.text == "Two.", "...then the next")
	mind.clear()

	# --- Midnight: the crack opens ---
	clock.set_earth_time(23 * 60.0 + 59.7, true)
	await create_timer(3.5).timeout
	var crack := current_scene.get("crack") as Node3D
	check(clock.in_shift() and crack != null, "midnight: a crack splits the ground open in front of the old oak")
	if crack == null:
		_finish()
		return
	check(crack.get_meta("open", 0.0) > 0.9 and not (crack.get_node("Lid") as Node3D).visible, "...wide open")
	check(dialogue.flags.has("earth_crack_seen"), "...and it's been seen now")
	var to_oak := Vector2(crack.global_position.x - oak_node.global_position.x, crack.global_position.z - oak_node.global_position.z).length()
	check(to_oak > 3.0 and to_oak < 6.5, "...just in front of the oak (%.1f m)" % to_oak)
	var spot := current_scene.find_child("Oak Spot", true, false) as Node3D
	var spot_gap := Vector2(spot.global_position.x - crack.global_position.x, spot.global_position.z - crack.global_position.z).length()
	check(spot_gap > 1.4 + 0.5, "...leaving room to stand and touch the oak (%.1f m)" % spot_gap)
	var entrance := current_scene.get_node("Entrance") as Node3D
	var land := Vector2(entrance.global_position.x - crack.global_position.x, entrance.global_position.z - crack.global_position.z).length()
	check(land > float(crack.get_meta("r", 1.4)) + 0.9, "arrivals from the Void land beside it, not in it (%.1f m)" % land)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var c := crack.global_position
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c + Vector3(0, -20, 0)))
	check(not hit.is_empty() and (hit.position as Vector3).y < c.y - 3.0, "it's a real hole in the ground (down to %.1f, hit %s, crack y %.2f)" % [((hit.position as Vector3).y if hit else 0.0), (str((hit.collider as Node).get_path()) if hit else ""), c.y])
	check(door.global_position.distance_to(c) < 1.5, "the way through is down it")
	# Jump in: a tumble down into it first, the screen filling with its colour
	await _drop_into(crack)
	var faller := current_scene.find_child("Player", true, false) as CharacterBody3D
	for i in 60:
		if faller.get("carried") == true and faller.global_position.y < c.y:
			break
		await physics_frame
	check(faller.get("carried") == true and faller.global_position.y < c.y + 0.6 and (faller.get_node("Visual/Tumble") as Node3D).scale.x < 0.99,
		"falling in: they tumble down into the crack, getting smaller (y %.2f, size %.2f)" % [faller.global_position.y - c.y, (faller.get_node("Visual/Tumble") as Node3D).scale.x])
	await _wait_for_scene(TOWN, 900)
	check(current_scene.scene_file_path == TOWN and not clock.on_earth, "jumping into the crack takes you to the Void")

	# --- The Void's way home is a crack too ---
	await _frames(6)
	var home := current_scene.get_node("Portal to Earth") as Node3D
	var back := home.get_node_or_null("Crack") as Node3D
	check(back != null, "the Void's way back to Earth is a crack")
	check(not (home.get_node("Ring") as Node3D).is_visible_in_tree() and not (home.get_node("Swirl") as Node3D).is_visible_in_tree(), "...the old ring is gone (ring %s, swirl %s)" % [(home.get_node("Ring") as Node3D).visible, (home.get_node("Swirl") as Node3D).visible])
	if back == null:
		_finish()
		return
	check(back.get_meta("open", 0.0) > 0.9, "...open, in the Shift")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var by := current_scene.find_child("FromPortaltoEarth", true, false) as Node3D
	# Coming out: once the loading screen's gone they're thrown up out of the crack, and land just beside it
	var vis := player.get_node("Visual") as Node3D
	var popped := false
	for i in 600:
		if player.get("carried") == true and vis.visible:
			popped = true
			break
		await process_frame
	check(popped, "...they pop up out of the crack")
	await create_timer(crack_mod.POP_TIME + 0.5).timeout
	# 2.5 m, not 1.5: on a busy machine more physics steps run and she can settle a little further from the marker (1.5 m,
	# seen once with four tests running at once). What matters is that she's beside the crack, not in it.
	check(player.get("carried") != true and vis.visible and player.get("input_locked") != true and player.global_position.distance_to(by.global_position) < 2.5 and player.global_position.distance_to(back.global_position) > 3.0,
		"...and land beside it, free to go (%.1f m from the marker, %.1f m from the crack)" % [player.global_position.distance_to(by.global_position), player.global_position.distance_to(back.global_position)])
	c = back.global_position
	hit = space_of().intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c + Vector3(0, -20, 0)))
	check(not hit.is_empty() and (hit.position as Vector3).y < c.y - 3.0, "...a real hole too")
	await _drop_into(back)
	await _wait_for_scene(EARTH, 900)
	check(current_scene.scene_file_path == EARTH and clock.in_shift(), "jumping in takes you home to Earth, still in the Shift")

	# --- 1 AM: it closes over ---
	await _frames(6)
	crack = current_scene.get("crack") as Node3D
	check(crack != null, "the crack's there from the start now it's been seen")
	clock.set_earth_time(1 * 60.0 + 1.0, true)
	await create_timer(3.5).timeout
	if current_scene.scene_file_path == EARTH and crack and is_instance_valid(crack):
		check(crack.get_meta("open", 1.0) < 0.1 and _hidden(crack), "at 1 AM it closes up and isn't there at all (nothing showing)")
		check(not (crack.get_node("Fall") as Area3D).monitoring, "...and you can't fall in")
		c = crack.global_position
		hit = space_of().intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c + Vector3(0, -20, 0)))
		check(not hit.is_empty() and absf((hit.position as Vector3).y - c.y) < 0.6, "...and the ground's whole again (hit %.2f, crack y %.2f)" % [((hit.position as Vector3).y if hit else 0.0), c.y])
		# Opening again: hidden till the first moment it opens, then unzipping from the middle (the town's own clock
		# would shut it again straight away at 1 AM, so it's held still meanwhile)
		current_scene.set_process(false)
		crack_mod.set_open(crack, 0.2)
		check((crack.get_node("Broken Earth") as Node3D).visible and (crack.get_node("Broken Earth") as Node3D).scale.x < 0.9, "opening, it unzips from the middle (%.2f long)" % (crack.get_node("Broken Earth") as Node3D).scale.x)
		crack_mod.set_open(crack, 1.0)
		await _frames(2)
		hit = space_of().intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 20, 0), c + Vector3(0, -20, 0)))
		check(not hit.is_empty() and (hit.position as Vector3).y < c.y - 3.0 and (crack.get_node("Broken Earth") as Node3D).scale.x > 0.99, "...and open, it's a hole again (hit %s at %.2f)" % [(str((hit.collider as Node).get_path()) if hit else ""), ((hit.position as Vector3).y - c.y if hit else 0.0)])
		crack_mod.set_open(crack, 0.0)
		current_scene.set_process(true)
	_finish()


func _hidden(g: Node3D) -> bool:
	for n in ["Broken Earth", "Lips", "Fissures", "Shaft/Split", "Lid", "Swirl"]:
		var c := g.get_node_or_null(n) as Node3D
		if c and c.is_visible_in_tree():
			return false
	return true


func space_of() -> PhysicsDirectSpaceState3D:
	return (current_scene as Node3D).get_world_3d().direct_space_state


func _drop_into(g: Node3D) -> void:
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	p.global_position = g.global_position + Vector3(4.0, 1.0, 0)
	for i in 4:
		await physics_frame
	p.global_position = g.global_position + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame


func _wait_for_scene(path: String, frames := 150) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
