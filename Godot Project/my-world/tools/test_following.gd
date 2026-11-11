extends SceneTree

# Checks following quests and side jobs (Hayden's 11 Nov 2026 playtest: "all quests and side jobs should be selectable
# allowing you to change back and forth and even showing multiple location markers simultaneously"): Quests.followed,
# the Follow buttons on the Quests sheet's cards (quests and board jobs), map stars only for what's followed (several
# at once), the HUD's to-do list for each, following from the board itself, saving it, an old save; and the first look
# round the Void (scripts/place_intro.gd, FirstNight.void_intro()).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_following.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.following_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var map: Node
var requests: Node
var jobs: Node


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
	quests = root.get_node("Quests")
	map = root.get_node("TownMap")
	requests = root.get_node("Requests")
	jobs = root.get_node("EarthJobs")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game.hold_saves = true
	game._resume = {}
	game.riding = false
	dialogue.reset()
	quests.reset()
	change_scene_to_file(TOWN)
	await _frames(8)
	var town := current_scene
	clock.set_time(1, 13 * 60.0, true)

	# --- Quests: the first one's followed by itself, a second one doesn't steal it ---
	dialogue.flags["rex_campaign_start"] = true
	quests.check()
	check(quests.followed == ["rex_campaign"], "the first quest is followed by itself (%s)" % str(quests.followed))
	var rex_stars: int = map.quest_markers().size()
	check(rex_stars > 0, "...and has stars on the map (%d)" % rex_stars)
	dialogue.flags["bramble_flowers_start"] = true
	quests.check()
	check(quests.followed == ["rex_campaign"], "a second quest doesn't steal the follow")
	check(map.quest_markers().size() == rex_stars, "...so the map still only shows the first one's stars")
	quests.follow("bramble_flowers", true)
	var both: int = map.quest_markers().size()
	check(both > rex_stars, "following both: both quests' stars at once (%d)" % both)
	var labels: Array = map.quest_markers().map(func(q: Dictionary) -> String: return str(q.label))
	check(labels.has(str(quests.quest("rex_campaign").name)) and labels.has(str(quests.quest("bramble_flowers").name)),
		"...each star says whose it is")
	check(quests.objectives_all().size() == 2, "the to-do list has both (%d)" % quests.objectives_all().size())
	quests.follow("rex_campaign", false)
	check(quests.tracked_quest() == "bramble_flowers" and map.quest_markers().size() == both - rex_stars,
		"unfollow one: only the other's stars and list")
	quests.follow("rex_campaign", false)
	quests.follow("bramble_flowers", false)
	check(map.quest_markers().is_empty(), "follow nothing: no stars")
	quests.follow_only("rex_campaign")
	check(quests.followed == ["rex_campaign"], "follow_only switches to just that one")

	# --- Tonight's requests: cards, Follow, stars ---
	clock.set_time(2, 9 * 60.0, true)
	requests.roll(11)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var visit: Dictionary = requests._make("visit", "medium", rng)
	visit.place = "observatory"
	requests.list = requests.list.filter(func(r: Dictionary) -> bool: return r.kind != "visit")
	requests.list[0] = visit
	var key: String = requests.key_of(visit)
	check(key == "req:visit" and requests.is_live(), "a request has a key to follow it by (%s)" % key)
	var cards: VBoxContainer = quests.cards_view()
	root.add_child(cards)
	var card := cards.get_node_or_null("Card req_visit")
	check(card != null, "tonight's requests are cards on the Quests sheet")
	var b := card.find_child("Follow", true, false) as Button if card else null
	check(b != null and not b.button_pressed, "...with a Follow button")
	if b:
		b.button_pressed = true
	await _frames(3)
	check(quests.is_followed(key), "pressing Follow follows it")
	var fresh := cards.get_node_or_null("Card req_visit")
	check(fresh != null and (fresh.find_child("Follow", true, false) as Button).button_pressed
		and (fresh.find_child("Follow", true, false) as Button).text.contains("Following"), "...and the card says so")
	var obs := town.get_node("Observatory") as Node3D
	check(map.quest_markers().any(func(q: Dictionary) -> bool: return (q.pos as Vector3).distance_to(obs.global_position) < 1.0),
		"a star on the Observatory for it, as well as the quest's")
	check(map.quest_markers().size() > rex_stars, "...both followed at once")
	check(quests.objectives_all().any(func(o: Dictionary) -> bool: return o.name == "Tally's request"), "the to-do list has it too")
	var rex_card := cards.get_node_or_null("Card rex_campaign")
	check(rex_card != null and rex_card.find_child("Follow", true, false) != null, "quest cards have a Follow button too")
	cards.queue_free()
	visit.done = true
	var board := town.get_node_or_null("Request Board") as Node3D
	check(board != null and map.quest_markers().any(func(q: Dictionary) -> bool: return (q.pos as Vector3).distance_to(board.global_position) < 1.0),
		"done: the star moves to the board, to turn it in")
	visit.paid = true
	check(not quests.live_followed().has(key), "paid: it's not followed any more")

	# --- Following from Tally's board ---
	visit.done = false
	visit.paid = false
	quests.follow(key, false)
	var spot := board.get_node("Request Talk")
	await _talk_to(spot, [-2])                     # "Follow them all!"
	check(requests.list.all(func(r: Dictionary) -> bool: return quests.is_followed(requests.key_of(r))), "the board's \"Follow them all!\" follows every request")
	await _talk_to(spot, [0])                       # picking a followed one stops following it
	check(not quests.is_followed(requests.key_of(requests.list[0])), "...and picking a followed one stops following it")

	# --- Saving ---
	var saved: Array = quests.follow_save()
	quests.followed.clear()
	quests.follow_load(saved)
	check(quests.followed == saved, "followed things save and load")
	quests.followed.clear()
	quests.follow_load(null)
	check(quests.followed.size() == 1 and quests.followed[0] in ["rex_campaign", "bramble_flowers"], "an old save follows the quest it was on (%s)" % str(quests.followed))

	# --- Earth's jobs: props get stars ---
	change_scene_to_file(EARTH)
	await _frames(10)
	clock.on_earth = true
	jobs.roll(5)
	var rake: Dictionary = jobs._make("rake", "easy", rng)
	jobs.list[0] = rake
	jobs._place_props()
	await _frames(3)
	quests.follow_only(jobs.key_of(rake))
	var piles: Array = map.quest_markers()
	check(piles.size() == int(rake.goal), "following a raking job: a star on every leaf pile (%d of %d)" % [piles.size(), int(rake.goal)])

	# --- The first look round the Void ---
	change_scene_to_file(TOWN)
	await _frames(8)
	var fn := root.get_node("FirstNight")
	dialogue.flags.erase("void_intro_seen")
	var cam_before := root.get_viewport().get_camera_3d()
	var finished := [false]
	fn.void_intro(func() -> void: finished[0] = true, true)
	await _frames(3)
	check(fn.intro.playing() and root.get_viewport().get_camera_3d() != cam_before, "the Void's first look plays with its own camera")
	check(fn.intro.shots.size() >= 3, "...over the town, the Market Square and down to Tally's board (%d shots)" % fn.intro.shots.size())
	var player := current_scene.find_child("Player", true, false)
	check(player.input_locked, "...holding the controls")
	check(dialogue.flags.has("void_intro_seen"), "...and only once")
	await create_timer(4.0).timeout
	check(fn.intro.playing(), "still going after 4 s")
	fn.intro.stop()
	await _frames(2)
	check(not fn.intro.playing() and finished[0] and not player.input_locked and root.get_viewport().get_camera_3d() == cam_before,
		"skipped: back to the player's camera and controls, and whatever came after runs")
	var again := [false]
	fn.void_intro(func() -> void: again[0] = true, true)
	await _frames(2)
	check(not fn.intro.playing() and again[0], "it doesn't play a second time")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _talk_to(t: Node3D, picks: Array = []) -> void:
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[pick if pick >= 0 else buttons.size() + pick].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
