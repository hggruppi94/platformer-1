extends SceneTree

# Checks the 12 Nov 2026 lore changes from the lore bible v2 (story/lore-bible.md, Part 3: items 5, 10, 12 and 16):
# - the world order: spring before summer. Glenmoor quakes once Lanternmoor's mended, the Tide Reef after Glenmoor,
#   Rhythm Springs after the Tide Reef, and the Far Future only once all three are mended (an old save that mended
#   Rhythm Springs before Glenmoor doesn't skip Heather's world); Portals.WORLDS and the final fight's friend
#   sections are in the new order,
# - Nina is chosen with a watch of her own and her home on Maple Lane; Bruno isn't chosen, just caught up in it,
# - coming home from the Void: a soft haze and a deja vu line (not on the First Night's own way home, not from Earth),
# - visitors come and go: the friends from other worlds and Mr. Palmer drop through a crack when they go home at
#   night (if you can see them), Nina, Bruno, Dash, Rex and Rook don't; Tally says who lives in the Void for keeps.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_lore_order.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.lore_order_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.lore_order_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var clock: Node
var quests: Node
var dialogue: Node
var portals: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	_check_order()
	_check_lines()
	await _check_deja_vu()
	await _check_visitors()
	_finish()


# --- The world order ----------------------------------------------------------------------------------------------
func _ids() -> Array:
	return portals.WORLDS.map(func(w: Dictionary) -> String: return str(w.id))


func _cleared(ids: Array) -> void:
	portals.quakes = ids.duplicate()
	portals.cleared_worlds = ids.duplicate()


func _check_order() -> void:
	var ids := _ids()
	check(ids.find("lanternmoor") < ids.find("glenmoor") and ids.find("glenmoor") < ids.find("tide_reef")
		and ids.find("tide_reef") < ids.find("rhythm_springs") and ids.find("rhythm_springs") < ids.find("far_future"),
		"WORLDS: Lanternmoor, Glenmoor, the Tide Reef, Rhythm Springs, then the Far Future (%s)" % ", ".join(ids))
	check(portals.world("glenmoor").get("season") == "spring" and portals.world("rhythm_springs").get("season") == "summer",
		"Glenmoor still opens spring and Rhythm Springs summer")
	var before := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]
	_cleared(before)
	check(portals.quake_due("glenmoor"), "Glenmoor's quake comes once Lanternmoor's mended")
	check(not portals.quake_due("rhythm_springs") and not portals.quake_due("tide_reef"),
		"...and not Rhythm Springs' or the Tide Reef's yet")
	check(portals.next_due() == "glenmoor", "the next world due is Glenmoor")
	_cleared(before + ["glenmoor"])
	check(portals.quake_due("tide_reef") and not portals.quake_due("rhythm_springs"),
		"once Glenmoor's mended, the Tide Reef quakes (not Rhythm Springs)")
	_cleared(before + ["glenmoor", "tide_reef"])
	check(portals.quake_due("rhythm_springs") and not portals.quake_due("far_future"),
		"once the Tide Reef's mended, Rhythm Springs quakes (not the Far Future)")
	_cleared(before + ["glenmoor", "tide_reef", "rhythm_springs"])
	check(portals.quake_due("far_future"), "with all three mended, the Far Future quakes")
	# A save from before the swap: Melody's world and Otto's mended, Heather's never visited
	_cleared(before + ["rhythm_springs", "tide_reef"])
	check(portals.quake_due("glenmoor") and not portals.quake_due("far_future"),
		"an old save with Rhythm Springs mended first still gets Glenmoor, and no Far Future till it's mended")
	_cleared([])
	var sections: Array = (load("res://scripts/chaos_trials.gd") as GDScript).get_script_constant_map().SECTIONS
	var order := sections.map(func(s: Dictionary) -> String: return str(s.world)).filter(func(w: String) -> bool:
		return w in ["glenmoor", "tide_reef", "rhythm_springs"])
	check(order == ["glenmoor", "tide_reef", "rhythm_springs"],
		"the final fight throws the worlds back in the order you mend them: Heather's, Otto's, then Melody's")


# --- Nina and Bruno -----------------------------------------------------------------------------------------------
func _all_lines(file: String) -> String:
	return FileAccess.get_file_as_string("res://dialogue/%s.json" % file)


func _check_lines() -> void:
	var nina := _all_lines("nina")
	check(nina.contains("I got one too. That means I'm chosen"), "Nina in the Void: she's chosen, with a watch of her own")
	check(nina.contains("Maple Lane"), "...and her home's on Maple Lane, on Earth")
	check(not nina.contains("You're new, aren't you?"), "...and she knows the hero from Stars Hollow")
	var earth := _all_lines("nina_earth")
	check(earth.contains("We're chosen, {player}. Both of us."), "Nina back home: both of you are chosen")
	check(earth.contains("with my sister Prue and my little brother Bruno"), "...and her family's on Earth")
	var bruno := _all_lines("bruno")
	check(bruno.contains("not one of the chothen") and bruno.contains("caught up in it"),
		"Bruno on Earth: not chosen, just caught up")
	var data = JSON.parse_string(bruno)
	var found := false
	for c in data.conversations:
		if c.get("set", "") == "bruno_caught_up":
			found = c.when.get("quest_done", "") == "first_night"
	check(found, "...and he only says so after the First Night")
	check(_all_lines("bruno_alien").contains("I grabbed Nina'th hand when the oak opened"),
		"Bruno in the Void: he grabbed Nina's hand and got pulled through")
	check(not _all_lines("bruno_alien").contains("You came through the portal too?"), "...the old hello's gone")


# --- Deja vu ------------------------------------------------------------------------------------------------------
func _go(path: String) -> void:
	change_scene_to_file(path)
	await _frames(10)


func _haze() -> Node:
	return root.get_node("EarthTown/DejaVu").get_node_or_null("DejaVu Haze")


func _check_deja_vu() -> void:
	var deja := root.get_node("EarthTown/DejaVu")
	await _go(EARTH)
	await _go(EARTH)
	check(_haze() == null, "Earth to Earth: no deja vu")
	await _go(TOWN)
	var n: int = deja.homecomings
	messages.clear()
	await _go(EARTH)
	check(deja.homecomings == n + 1 and _haze() != null, "the Void to Earth: the soft haze comes over the screen")
	await create_timer(1.3).timeout
	check(deja.last_line() != "" and deja.last_line() in messages, "...and a deja vu line: \"%s\"" % deja.last_line())
	await create_timer(3.5).timeout
	check(_haze() == null, "...and it clears after a few seconds")
	# The First Night's own way home has its own wake-up message
	var steps: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://quests/first_night.json")) as Dictionary).steps
	var home := steps.map(func(st: Dictionary) -> String: return str(st.id)).find("home")
	quests.state[root.get_node("FirstNight").ID] = {"step": home, "done": false, "since_day": 1}
	await _go(TOWN)
	n = deja.homecomings
	await _go(EARTH)
	check(deja.homecomings == n, "not on the First Night's way home (it has its own \"Was it all a dream?\")")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}


# --- Visitors come and go -----------------------------------------------------------------------------------------
func _routine_of(id: String) -> Node:
	for r in current_scene.find_children("*", "", true, false):
		if r.get_script() and str(r.get_script().resource_path).ends_with("scripts/routine.gd") \
				and str(r.get("character_id")) == id:
			return r
	return null


func _check_visitors() -> void:
	var visitors: Array = (load("res://scripts/routine.gd") as GDScript).get_script_constant_map().VISITORS
	for id in ["bramble", "pip", "melody", "clover", "mr_palmer"]:
		check(id in visitors, "%s comes and goes through the cracks" % id)
	for id in ["dash", "rex", "rook", "nina", "bruno_alien"]:
		check(not id in visitors, "%s doesn't go home through a crack" % id)
	# Bramble goes home at 20:30: watch her go
	clock.on_earth = false
	clock.set_time(clock.day, 20 * 60.0 + 28.0, true)
	await _go(TOWN)
	await _physics(4)
	var bramble := _routine_of("bramble")
	check(bramble != null, "found Bramble's routine")
	if bramble == null:
		return
	var player := get_first_node_in_group("player") as Node3D
	var body := bramble.get_parent() as Node3D
	var greenhouse: Vector3 = bramble._paths.position_of("greenhouse", bramble._space, bramble._skip)
	body.global_position = greenhouse + Vector3(1.5, 0, 0)
	player.global_position = greenhouse + Vector3(6, 1, 0)
	await _physics(3)
	check(bramble.is_present(), "Bramble's in town before 20:30")
	clock.minutes = 20 * 60.0 + 31.0            # ticks on (a jump would just put her away, unseen)
	var crack: Node = null
	for i in 600:
		await physics_frame
		crack = get_first_node_in_group("visitor_crack")
		if crack or not bramble.is_present():
			break
	await _physics(2)
	crack = get_first_node_in_group("visitor_crack") if crack == null else crack
	check(not bramble.is_present(), "at 20:30 Bramble goes home")
	check(crack != null, "...through a little crack in the ground, as you watch")
	if crack:
		check((crack as Node3D).global_position.distance_to(body.global_position) < 1.0, "...right at her feet")
		await create_timer(2.2).timeout
		check(not is_instance_valid(crack), "...and it zips shut again")
	# Tally says who lives here for keeps
	var requests := root.get_node("Requests")
	dialogue.flags["tally_hi"] = true
	dialogue.flags.erase("tally_comers")
	var said: String = "\n".join(requests.lines())
	check(said.contains("Only a few of us live in the Void for keeps") and said.contains("Astronaut"),
		"Tally: only Tally, the little ones and the Astronaut live in the Void for keeps")
	check(said.contains("Dash, Rex and Rook"), "...and Dash, Rex and Rook can't leave")
	check(not "\n".join(requests.lines()).contains("for keeps"), "...said once")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
