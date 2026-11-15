extends SceneTree

# Checks the neighbours' errands in Stars Hollow (overnight polish, 15 Nov 2026; scripts/home_calls.gd ERRANDS):
#   - nothing's offered (and no "!" shows) before the old oak's woken;
#   - after that a bobbing "!" over Barnaby, Miss Marigold, Juniper and Mr. Gumdrop, and Kip only in autumn;
#   - each giver offers theirs, the "!" goes once it's started, and its three things wait in town, every one on open
#     ground (not inside a building or a wall) and clear of the other quests' spots;
#   - finding them, back to the giver, the reward, and none of it touches the crack;
#   - every line follows the less-reading rules (3 lines a talk, no stage directions).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_errands.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.errands_test_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var dialogue: Node
var quests: Node
var calls: Node
var clock: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	calls = root.get_node("Portals").home_calls
	clock = root.get_node("Clock")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Settings").tips = false
	game.new_game()
	await _wait_for_scene(EARTH)
	game.needs_creator = false
	await create_timer(1.5).timeout
	check(clock.season() == "autumn", "a new game starts in autumn")

	# --- Before the oak's woken: nothing ---
	for id in calls.ERRANDS:
		check(not calls.errand_open(id), "%s isn't offered before the oak's woken" % id)
	check(get_root_marks().is_empty(), "...and no \"!\" shows")

	dialogue.set_flag("oak_woken")
	await create_timer(1.2).timeout
	var marked := get_root_marks()
	for id in calls.ERRANDS:
		var who := str(calls.ERRANDS[id].giver)
		check(calls.errand_open(id), "%s is on offer now" % id)
		var here := current_scene.find_children("*", "Area3D", true, false).any(func(t: Node) -> bool:
			return "character_id" in t and str(t.get("character_id")) == who)
		if here:
			check(marked.has(who), "a \"!\" bobs over %s" % who)

	# Kip's leaf piles are only for autumn
	clock.open_season("winter")
	clock.dial_to("winter")
	check(not calls.errand_open("errand_leaves"), "Kip's leaf piles aren't offered in winter")
	check(calls.errand_open("errand_song"), "...but Barnaby's song is, any season")
	for k in 3:
		if clock.season() != "autumn":
			clock.calendar_offset += clock.SEASON_DAYS
	check(clock.season() == "autumn", "(back to autumn)")

	# --- The spots: open ground, clear of everything else ---
	var holder := current_scene.get_node_or_null("Home Calls")
	check(holder != null, "the errands' things are in Stars Hollow")
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	for k in calls.SPOTS:
		if not str(k[0]).begins_with("errand_"):
			continue
		var spot := holder.get_node("Home Spot " + str(k[2])) as Node3D
		var at := spot.global_position
		check(absf(at.y - EarthLand.height(at.x, at.z)) < 1.5, "%s is on the ground (%.1f)" % [k[2], at.y])
		var ball := SphereShape3D.new()
		ball.radius = 0.45
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = ball
		q.transform = Transform3D(Basis(), at + Vector3(0, 1.0, 0))
		q.collide_with_areas = false
		var hits := space.intersect_shape(q, 4)
		check(hits.is_empty(), "%s is out in the open, nothing solid on it (%s)" % [k[2],
			str(hits.map(func(h: Dictionary) -> String: return str(h.collider.name)))])
		var near := ""
		for j in calls.SPOTS:
			if j != k and (j[3] as Vector2).distance_to(k[3]) < 3.0:
				near = str(j[2])
		check(near == "", "%s isn't on top of another spot (%s)" % [k[2], near])

	# --- One whole errand: Barnaby's song ---
	var crack_before: bool = calls.sealed()
	dialogue.talks["barnaby"] = 0
	var lines: Array = dialogue.pick_conversation("barnaby")
	check(not str(lines).contains("song"), "the first time, Barnaby just says hello")
	dialogue.talks["barnaby"] = 1
	lines = dialogue.pick_conversation("barnaby")
	check(str(lines).contains("song"), "...then he asks about his song (%s)" % str(lines).left(80))
	dialogue.set_flag("errand_song_start")
	await _quests()
	check(quests.on_step("errand_song", "find"), "...yes starts it: find the pages")
	await create_timer(1.0).timeout
	check(not get_root_marks().has("barnaby"), "...and his \"!\" goes")
	for f in ["song_1", "song_2", "song_3"]:
		var spot := holder.get_node("Home Spot " + f)
		check(spot.is_open() and (spot.get_node("Before") as Node3D).visible, "%s waits to be picked up" % f)
		spot.use()
	await _quests()
	check(quests.on_step("errand_song", "back"), "three found: back to Barnaby")
	lines = dialogue.pick_conversation("barnaby")
	check(str(lines).contains("All three"), "he's pleased")
	var before: int = game.sparkles
	dialogue.set_flag("errand_song_back")
	await _quests()
	check(quests.is_done("errand_song"), "the errand's done")
	check(game.sparkles == before + 6, "...for 6 sparkles (%d)" % (game.sparkles - before))
	check(calls.sealed() == crack_before and calls.chapter == "", "...and it never touched the crack")
	check(not calls.errand_open("errand_song"), "...and it isn't offered again")

	# --- The leaf piles: jumping in leaves them spread about ---
	dialogue.set_flag("errand_leaves_start")
	await _quests()
	var pile := holder.get_node("Home Spot leaves_1")
	check(pile.get_node_or_null("Done") != null, "a leaf pile has a spread-out look for after")
	pile.use()
	await _frames(3)
	check((pile.get_node("Done") as Node3D).visible and not (pile.get_node("Before") as Node3D).visible,
		"jumping in leaves the leaves spread about")

	# --- The words ---
	var bad := []
	for who in ["barnaby", "marigold", "juniper", "otis", "kip"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/%s.json" % who))
		for c in d.conversations:
			var w: Dictionary = c.get("when", {})
			var errand := str(w.get("quest_step", w.get("quest_not_started", "")))
			if not errand.begins_with("errand_"):
				continue
			var ls: Array = c.get("lines", [])
			if ls.size() > 3:
				bad.append("%s: %d lines" % [who, ls.size()])
			for l in ls:
				if l is String and (l as String).begins_with("("):
					bad.append("%s: %s" % [who, l])
	check(bad.is_empty(), "the errands' talks are short, with no stage directions %s" % str(bad))
	for id in calls.ERRANDS:
		var q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://quests/%s.json" % id))
		for st in q.steps:
			check(str(st.text).split(" ").size() <= 5, "%s's goal is a few words: %s" % [id, st.text])
	_finish()


func get_root_marks() -> Dictionary:
	var out := {}
	for t in get_nodes_in_group("errand_givers"):
		if t.get_node_or_null("Errand Mark") != null:
			out[str(t.get("character_id"))] = true
	return out


func _quests() -> void:
	quests.check()
	await _frames(3)


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
