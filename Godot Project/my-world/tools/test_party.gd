extends SceneTree

# Checks the party system (plan item 26, scripts/party.gd): the five friends' moves have no buttons of their own any
# more, one Friend button does whoever's with you; nobody's with you in a new game (and RB just rolls); friends join
# when they say yes (and old saves have everyone they'd learned from joined); Switch friend goes round them and
# nobody; in the Void town the friend's own town self follows you (scripts/routine.gd TAG_ALONG) and a quest still
# gets them; elsewhere in the Void a copy follows you (scripts/party_follower.gd), but not in their own home world;
# on Earth only Nina and Bruno help; Flurry hops in by water; the final fight's sections bring their friend; Flurry
# and the three dialogue files ask to join; and it all saves and loads.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_party.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.party_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.party_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const SHARD := "res://scenes/portal_worlds/shard_isle.tscn"
const ROOTMIND := "res://scenes/portal_worlds/rootmind.tscn"

var failures := 0
var game: Node
var portals: Node
var settings: Node
var party: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	settings = root.get_node("Settings")
	party = root.get_node("Party")
	dialogue = root.get_node("Dialogue")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	_check_buttons()
	_check_dialogue_files()
	_check_joining()
	await _check_town()
	await _check_water()
	await _check_portal_world()
	await _check_home_world()
	await _check_earth()
	_check_sections()
	_check_saving()
	_finish()


# --- buttons ---------------------------------------------------------------------------------------------------------
func _check_buttons() -> void:
	for a in settings.FRIEND_MOVES:
		check(not settings.default_bindings().has(a) and not settings.default_pad_bindings().has(a),
			"%s has no button of its own" % a)
		check(settings.prompt(a) == settings.prompt("friend"), "...a line saying {%s} says the Friend button" % a)
	check(settings.default_bindings().get("friend") == KEY_Z and settings.default_pad_bindings().get("friend") == JOY_BUTTON_RIGHT_SHOULDER,
		"Friend is Z and RB")
	check(settings.default_bindings().get("friend_wheel") == KEY_X and settings.default_pad_bindings().get("friend_wheel") == JOY_BUTTON_DPAD_LEFT,
		"Switch friend is X and D-pad left")
	var on_foot: Array = settings.PAD_GROUPS[0]
	check(on_foot.size() == 15, "the on-foot controller actions are down from 18 to %d" % on_foot.size())
	var clash := ""
	var pads: Dictionary = settings.default_pad_bindings()
	for a in on_foot:
		for b in on_foot:
			if a < b and pads.get(a, -1) >= 0 and pads.get(a, -1) == pads.get(b, -2) and not settings._shares_on_purpose(a, b):
				clash = "%s and %s" % [a, b]
	check(clash == "", "no two on-foot actions share a button (%s)" % clash)
	check(not settings.action_shown("friend") and not settings.action_shown("friend_wheel"),
		"in a new game neither is on the Controls list (nobody's joined)")
	var t: String = settings.fill("Press {burrow} to dig, {groove} to dance")
	check(not t.contains("{"), "Settings.fill fills the moves in: %s" % t)


func _check_dialogue_files() -> void:
	for pair in [["bramble", "bramble", "rootmind"], ["melody", "melody", "rhythm_springs"], ["clover", "heather", "glenmoor"]]:
		var d := JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/%s.json" % pair[0])) as Dictionary
		var asks := false
		var again := false
		for c in d.conversations:
			var w: Dictionary = c.get("when", {})
			var text := JSON.stringify(c)
			if w.get("mended", "") == pair[2] and w.get("not_flag", "") == "party_asked_" + pair[1] \
					and text.contains("party_yes_" + pair[1]) and text.contains("party_join"):
				asks = true
			if w.get("flag", "") == "party_asked_" + pair[1] and w.get("not_flag", "") == "party_yes_" + pair[1]:
				again = true
		check(asks, "%s asks to join once %s's mended (yes sets party_yes_%s, recorded)" % [pair[0], pair[2], pair[1]])
		check(again, "...and asks again now and then after a not yet")
	portals.cleared_worlds.append("frozen_moment")
	var lines: Array = portals.flurry_hub_lines()
	check(JSON.stringify(lines).contains("party_yes_flurry"), "Flurry asks to come along on the Portal Plaza")
	portals.note_found("frozen_moment", "flurry_in_hub")
	portals.cleared_worlds.erase("frozen_moment")


# --- joining ---------------------------------------------------------------------------------------------------------
func _check_joining() -> void:
	game._reset_state()
	check(party.joined.is_empty() and party.with_you == "", "a new game: nobody's with you")
	check(not party.can_use(null), "...and Friend does nothing")
	portals.cleared_worlds.append("rootmind")
	check(party.learned("bramble") and not party.has_joined("bramble"), "mending the Rootmind teaches Burrow, but Bramble hasn't joined")
	dialogue.set_flag("party_yes_bramble")
	check(party.has_joined("bramble") and party.with_you == "bramble", "saying yes: Bramble joins and walks with you")
	check(settings.action_shown("friend") and not settings.action_shown("friend_wheel"),
		"Friend's on the Controls list now, Switch friend not yet (one friend)")
	dialogue.set_flag("make_taught")
	check(party.has_joined("nina_bruno") and party.with_you == "nina_bruno", "Nina and Bruno join as they teach Make")
	check(settings.action_shown("friend_wheel"), "two friends: Switch friend's on the Controls list")
	check(party.switch() == "bramble", "Switch friend: Bramble")
	check(party.switch() == "", "...then nobody")
	check(party.switch() == "nina_bruno", "...then round again")
	check(party.card_shown() or party._card_left > 0.0, "switching shows who's with you")
	# Old saves: everyone you'd learned a move from has joined
	game._reset_state()
	portals.cleared_worlds.append_array(["rootmind", "glenmoor"])
	dialogue.flags["make_taught"] = true
	party.load_data(null)
	check(party.joined == ["nina_bruno", "bramble", "heather"], "an old save: everyone you'd learned from has joined (%s)" % [party.joined])
	check(party.with_you == "heather", "...and the last of them is with you")
	check(dialogue.flags.has("party_yes_bramble") and dialogue.flags.has("party_asked_heather"), "...so nobody asks again")
	check(not party.has_joined("flurry"), "...but not anyone whose world isn't mended")


# --- in the Void town --------------------------------------------------------------------------------------------------
func _check_town() -> void:
	game._reset_state()
	portals.cleared_worlds.append("rootmind")
	party.join("bramble", true)
	change_scene_to_file(TOWN)
	await _frames(12)
	await _physics(8)
	var p := _player()
	var r := _routine("bramble")
	check(r != null, "Bramble's in town")
	if r == null:
		return
	check(party.tags_along("bramble") and r.current_block().get("who", "") == "@player", "her routine says: walk with the player")
	check(party.followers().is_empty(), "...so there's no copy (her own self does it, and can still be talked to)")
	var body := r.get_parent() as Node3D
	await _physics(30)
	var d := _flat(body.global_position, p.global_position)
	check(d < 6.0, "she's by you (%.1f m)" % d)
	# Walk off: she keeps up
	var spot := p.global_position + Vector3(14, 0, 0)
	p.global_position = spot + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(240)
	d = _flat(body.global_position, p.global_position)
	check(d < 6.0, "you go somewhere else and she follows (%.1f m)" % d)
	# Far away: she catches up out of sight
	p.global_position = Vector3(-40, 8, 40)
	p.velocity = Vector3.ZERO
	await _physics(90)
	d = _flat(body.global_position, p.global_position)
	check(d < 8.0, "a long way off, she catches up (%.1f m)" % d)
	# Pressing Friend: Bramble burrows
	await _land(p)
	var burrow: Node = p.burrow
	if not burrow.soil(p._floor_node):
		p.global_position = body.global_position + Vector3(0, 1.0, 0)
		await _land(p)
	Input.action_press("friend")
	await _physics(2)
	Input.action_release("friend")
	await _physics(2)
	check(burrow.active, "Friend: Bramble's Burrow")
	await _press("friend")
	await _physics(40)
	# Nobody with you: back to her own day
	party.switch()
	await _physics(4)
	check(party.with_you == "" and r.current_block().get("who", "") != "@player", "nobody along: she goes back to her own day")
	check(not party.can_use(p), "...and Friend does nothing (RB just rolls)")
	party.with_you = "bramble"


func _check_water() -> void:
	# Flurry hops in by water, whoever was with you
	var p := _player()
	var w := Vector3.INF
	for x in range(-60, 61, 3):
		for z in range(-40, 61, 3):
			if w == Vector3.INF and p.frost_breath.water_under(float(x), float(z)) != null \
					and p.frost_breath.water_under(float(x) + 6.0, float(z)) != null \
					and p.frost_breath.water_under(float(x), float(z) + 6.0) != null:
				w = Vector3(x, 2.0, z)
	check(w != Vector3.INF, "found the lake")
	if w == Vector3.INF:
		return
	portals.cleared_worlds.append("frozen_moment")
	party.join("flurry", true)
	party.with_you = "bramble"
	p.global_position = w
	p.velocity = Vector3.ZERO
	await _physics(4)
	check(party._who_for(p) == "flurry", "by water, Flurry's the one who'd answer Friend")
	party.use(p)
	check(party.with_you == "flurry", "...and pressing it swaps her in")
	await _physics(30)
	check(party.followers().size() == 1, "she has no town self, so a copy walks with you")
	var hub := portals._holder.get_node_or_null("Flurry") as Node3D if is_instance_valid(portals._holder) else null
	check(hub == null or not hub.visible, "...and she's not on the Portal Plaza at the same time")
	party.with_you = "bramble"
	await _physics(30)
	check(hub == null or hub.visible, "back to Bramble: Flurry's back on the plaza")


func _check_portal_world() -> void:
	game.go(SHARD, "Entrance", "Shard Isle")
	await _frames(16)
	await _physics(10)
	var p := _player()
	check(current_scene.scene_file_path == SHARD, "into Shard Isle")
	check(party.followers().size() == 1, "in a portal world a copy of Bramble walks with you")
	if party.followers().is_empty():
		return
	var f := party.followers()[0] as Node3D
	check(f.global_position.distance_to(p.global_position) < 8.0, "...close by")
	var start := p.global_position
	Input.action_press("move_forward")
	await _physics(90)
	Input.action_release("move_forward")
	await _physics(90)
	var d := _flat(f.global_position, p.global_position)
	check(p.global_position.distance_to(start) > 3.0 and d < 6.0, "you run, she follows (%.1f m behind)" % d)
	party.with_you = "nina_bruno"
	party.join("nina_bruno", true)
	party.with_you = "nina_bruno"
	await _physics(30)
	check(party.followers().size() == 2, "Nina and Bruno: two copies, side by side")
	party.with_you = "bramble"
	await _physics(30)


func _check_home_world() -> void:
	game.go(ROOTMIND, "Entrance", "the Rootmind")
	await _frames(16)
	await _physics(10)
	check(current_scene.scene_file_path == ROOTMIND, "into the Rootmind")
	check(party.followers().is_empty(), "Bramble's home: no copy (she's already there)")
	check(party._who_for(_player()) == "bramble", "...but Friend still burrows")


func _check_earth() -> void:
	game.go(EARTH, "HomeSpawn", "Stars Hollow")
	await _frames(16)
	await _physics(10)
	check(current_scene.scene_file_path == EARTH, "home to Stars Hollow")
	check(party.followers().is_empty(), "nobody from the Void follows you on Earth")
	party.with_you = "bramble"
	check(party._who_for(_player()) == "nina_bruno", "on Earth Friend is Nina and Bruno's Make (they live here)")
	var keep: Array = party.joined.duplicate()
	party.joined.erase("nina_bruno")
	check(party._who_for(_player()) == "", "...and nothing without them")
	party.joined = keep


func _check_sections() -> void:
	game._reset_state()
	party.bring_for("frost")
	check(party.current() == "flurry", "the final fight's frost section brings Flurry along, joined or not")
	party.bring_for("glow")
	check(party.current() == "", "Pip's section needs no friend button")
	party.bring_for("")
	var src := FileAccess.get_file_as_string("res://scripts/chaos_trials.gd")
	check(src.contains("Party.bring_for(id)") and src.contains("Party.bring_for(\"\")"), "chaos_trials.gd brings them and lets them go")


func _check_saving() -> void:
	game._reset_state()
	portals.cleared_worlds.append("glenmoor")
	party.join("heather", true)
	party.join("bramble", true)
	party.with_you = "heather"
	var data: Dictionary = party.save_data()
	party.reset()
	party.load_data(data)
	check(party.joined == ["heather", "bramble"] and party.with_you == "heather", "save and load keep who's joined and who's with you")
	party.load_data({"joined": ["nobody_real", "melody"], "with": "nobody_real"})
	check(party.joined == ["melody"] and party.with_you == "", "a save with someone unknown: they're left out")


# --- helpers ---------------------------------------------------------------------------------------------------------
func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _routine(id: String) -> Node:
	for r in get_nodes_in_group("routines"):
		if str(r.get("character_id")) == id:
			return r
	return null


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _land(p: CharacterBody3D) -> void:
	for i in 120:
		await physics_frame
		if p.is_on_floor():
			break


func _press(action: String) -> void:
	Input.action_press(action)
	await _physics(2)
	Input.action_release(action)
	await _physics(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("friend")
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
