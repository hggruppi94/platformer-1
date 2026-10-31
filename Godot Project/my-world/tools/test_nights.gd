extends SceneTree

# Checks the nights after The First Night and the Goals page (scripts/nights.gd, quests/night_2.json, plan prompt F4):
# the Goals page always has something for tonight, something to aim for in watches, races, gadgets and skating, and a
# teaser for tomorrow night; night 2 starts the first time you land in Galaxity after The First Night (never during
# it), with "New tonight" and Pip waiting by the portal; Pip's lines start the boardwalk lamps; Dash's stall and a
# S-K-A-T-E letter tick the list; it pays out; an old save that never had The First Night gets night 2 from its second
# visit, but not on its first; and the Tab menu has a Goals sheet.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_nights.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.nights_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var N: Node
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var requests: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	N = root.get_node("Nights")
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	requests = root.get_node("Requests")
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	dialogue.reset()
	quests.reset()
	requests.nights = 1
	game._resume = {}
	game.riding = false
	game.pending_message = ""
	clock.pulls_home = false
	if not game.has_item("skateboard"):
		game.give_item("skateboard")

	# --- The Goals page, from the start ---
	var g: Array = N.goals()
	check(g.map(func(p: Array) -> String: return p[0]) == ["Tonight", "Next to aim for", "Tomorrow night"],
		"the Goals page has Tonight, Next to aim for and Tomorrow night")
	var aim: Array = g[1][1]
	for want in ["Lost watches", "Races", "Gadgets", "Skat"]:
		check(aim.any(func(l: String) -> bool: return l.contains(want)), "...something to aim for in %s" % want)
	check(not g[2][1].is_empty() and str(g[2][1][0]) != "", "...and a teaser for tomorrow night (%s)" % g[2][1][0])

	# --- During The First Night: no night 2 yet ---
	dialogue.set_flag("first_night_start")
	quests.check()
	check(quests.is_started("first_night"), "The First Night is on")
	check(N.current().get("n", 0) == 1 and str(N.goals()[0][1][0]).contains("The First Night"),
		"...and it's what the Goals page says is on tonight")
	check(str(N.goals()[2][1][0]).contains("Pip"), "...with Pip teased for tomorrow night")
	clock.set_earth_time(0.2 * 60.0, true)                   # in the Shift
	await _go(TOWN)
	check(not dialogue.flags.has("night_2"), "no night 2 while The First Night's still going")
	var guard := 20
	while not quests.is_done("first_night") and guard > 0:
		quests.skip("first_night")
		guard -= 1
	await _frames(3)
	check(quests.is_done("first_night"), "The First Night skipped all the way through")

	# --- Night 2: the next visit ---
	requests.nights = 2
	messages.clear()
	await _go(EARTH)
	await _go(TOWN)
	check(dialogue.flags.has("night_2") and quests.is_started("night_2") and _step() == "pip",
		"landing in Galaxity after The First Night starts night 2, on Pip's step")
	await create_timer(3.4).timeout
	check(messages.any(func(m: String) -> bool: return m.contains("Night 2")), "...with \"New tonight\" when you land")
	check(str(N.goals()[0][1][0]).contains("Night 2"), "...and the Goals page says it's night 2")
	var pip := _talker("pip")
	check(pip != null and _going(pip, "portal"), "Pip's waiting by the portal")
	if pip:
		await _talk_to(pip, [0])
	check(dialogue.flags.has("n2_pip") and dialogue.flags.has("pip_lamps_start") and quests.is_started("pip_lamps"),
		"Pip asks for help with the boardwalk lamps, and saying yes starts them")
	check(_step() == "explore", "...then the list of new things to try")
	var shop := root.get_node("Shop")
	shop.open("Gadget")
	await _frames(2)
	shop.close()
	await _frames(2)
	check(not dialogue.flags.has("n2_fizz"), "looking at Dash's stall before finding the schematic doesn't tick it")
	var sch := current_scene.get_node_or_null("Schematic fizz") as Node3D
	check(sch != null, "the Fizz Flinger's schematic is out on the promenade")
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	if sch and player:
		player.global_position = sch.global_position + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		await _frames(6)
	check(dialogue.flags.has("schematic_fizz"), "...and walking into it finds it")
	shop.open("Gadget")
	await _frames(2)
	shop.close()
	await _frames(2)
	check(dialogue.flags.has("n2_fizz"), "then looking at Dash's gadget stall ticks the Fizz Flinger")
	var before: int = game.sparkles
	dialogue.set_flag("skate_letter_K")
	await _frames(40)
	quests.check()
	await _frames(2)
	check(dialogue.flags.has("n2_letter"), "a S-K-A-T-E letter ticks the letters")
	check(quests.is_done("night_2") and game.sparkles == before + 8, "night 2 is done, with 8 sparkles (%d)" % (game.sparkles - before))
	check(N.current().is_empty(), "...and nothing's spotlighted after it")

	# --- The Tab menu's Goals sheet ---
	var menu := root.get_node("PlayerMenu")
	menu.open("goals")
	await _frames(3)
	var texts: Array = menu.root.find_children("*", "RichTextLabel", true, false).map(func(r: RichTextLabel) -> String: return r.text)
	check(menu.is_open() and menu.sheet == "goals", "the Tab menu opens on a Goals sheet")
	check(texts.any(func(t: String) -> bool: return t.contains("Lost watches")), "...showing what to aim for (%d lines)" % texts.size())
	menu.close()
	await _frames(2)

	# --- An old save that never had The First Night ---
	dialogue.reset()
	quests.reset()
	requests.nights = 4
	await _go(EARTH)
	await _go(TOWN)
	check(not dialogue.flags.has("night_2") and not quests.is_started("night_2"),
		"an old save that never had The First Night isn't pushed into night 2 (The First Night's offered first)")
	check(quests.can_skip("night_2") == false and bool(quests.quest("night_2").get("skippable", false)),
		"night 2 can be skipped from the quest log, like The First Night")

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _step() -> String:
	return str(quests.current_step("night_2").get("id", ""))


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 30:
		await process_frame
		if current_scene and current_scene.scene_file_path == scene:
			break
	await _frames(6)


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _going(t: Node, place: String) -> bool:
	var r := t.get_parent().find_child("Routine", true, false)
	if r == null:
		for n in get_nodes_in_group("routines"):
			if n.get("character_id") == t.get("character_id"):
				r = n
	return r != null and str(r.current_block().get("place", "")) == place


func _talk_to(t: Node3D, picks: Array = []) -> void:
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var body := t.get_parent() as Node3D
	player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick if pick >= 0 else buttons.size() - 1].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
