extends SceneTree

# A playthrough of the whole story, start to finish, on ONE save that carries on from chapter to chapter (Hayden's
# "full playtest from the start of the game to the ending", 10 Nov 2026). Each feature's own test sets up the state it
# needs; this one never does: every chapter starts from the save the chapter before left, and only does what a player
# could (talk, walk into things, use spots, pop things, sleep, go through portals). So it finds the seams between
# features: a quest that never starts because the one before ended differently, a quake that never comes, a move a
# later world needs that was never taught, a save that doesn't carry something over.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/playthrough.gd -- <chapter> [shots folder]
#
# Chapters, in order (each needs the one before it to have passed): first_night, nights, harvest, shard_isle,
# rootmind, frozen_moment, lanternmoor, rhythm_springs, tide_reef, glenmoor, dark_hollow, far_future, chaos.
# "all" runs every chapter one after another in one go.
#
# Each chapter's end is kept as user://playthrough_<chapter>.json, and the next chapter starts from it (copied in as
# the save). Your own save and settings are put aside first (under their own names) and put back at the end, so this
# is safe on Hayden's PC too. With a shots folder (and a window, not --headless) it saves pictures along the way.

const SAVE := "user://save.json"
const BACKUP := "user://save.playthrough_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.playthrough_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const CHAPTERS := ["first_night", "nights", "harvest", "shard_isle", "rootmind", "frozen_moment", "lanternmoor",
	"rhythm_springs", "tide_reef", "glenmoor", "dark_hollow", "far_future", "chaos"]

var failures := 0
var notes: Array = []                   # problems found, in plain words, printed at the end
var shots_dir := ""
var shot_n := 0
var said: Array = []
var messages: Array = []

var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var portals: Node
var rem: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1
		notes.append(what)


func note(what: String) -> void:
	# Not a failure: something a player would notice (a missing hint, an odd wait)
	print("NOTE  " + what)
	notes.append("(note) " + what)


func _initialize() -> void:
	create_timer(3000.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var chapter := str(args[0]) if args.size() > 0 else "all"
	shots_dir = str(args[1]) if args.size() > 1 else ""
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	portals = root.get_node("Portals")
	rem = root.get_node("Remnants")
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	var todo: Array = CHAPTERS.duplicate() if chapter == "all" else [chapter]
	for c in todo:
		var i := CHAPTERS.find(c)
		if i < 0:
			check(false, "there's a chapter called %s" % c)
			break
		if i > 0 and not await _load_from(CHAPTERS[i - 1]):
			break
		print("\n=== Chapter: %s ===" % c)
		var before := failures
		await call("_ch_" + c)
		await _frames(4)
		game.save_game()
		DirAccess.copy_absolute(SAVE, "user://playthrough_%s.json" % c)
		print("=== %s: %s ===" % [c, "OK" if failures == before else "%d FAILED" % (failures - before)])
	_finish()


func _load_from(prev: String) -> bool:
	# Start from where the chapter before left the save, the way a player would: the title screen's Continue
	var from := "user://playthrough_%s.json" % prev
	if not FileAccess.file_exists(from):
		check(false, "chapter %s has been played first (run it before this one)" % prev)
		return false
	DirAccess.copy_absolute(from, SAVE)
	game._reset_state()
	game.load_game()
	game.continue_game()
	for i in 60:
		await process_frame
		if current_scene and current_scene.scene_file_path != "" and current_scene.find_child("Player", true, false):
			break
	await _frames(10)
	return true


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	print("\n--- What came up ---")
	for n in notes:
		print("  * " + str(n))
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


# =============================================================================
# Chapter 1: a new game, through The First Night, to waking up at home
# =============================================================================
func _ch_first_night() -> void:
	var creator := root.get_node("Creator")
	var lesson := root.get_node("SkateLesson")
	var shop := root.get_node("Shop")
	var requests := root.get_node("Requests")
	var watches := root.get_node("Watches")
	var oak := root.get_node("HummingOak")
	var fn := root.get_node("FirstNight")
	# The title screen first, as the game opens
	change_scene_to_file(game.TITLE_SCENE)
	await _frames(20)
	await shot("title")
	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	check(creator.is_open() or game.needs_creator, "a new game opens the character creator")
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	await shot("creator")
	game.hero["name"] = "Sunny"
	creator.close()
	await _frames(6)
	check(quests.is_started("first_night") and _step("first_night") == "morning", "The First Night starts once the hero's made")
	await _physics(30)
	await shot("first_morning")
	await _talk("nina_earth")
	await _talk("palmer_earth")
	await _talk("theo")
	await _talk("lionel")
	await _frames(4)
	check(_step("first_night") == "board", "two hellos on the green: on to the notice board (%s)" % _step("first_night"))
	var nb := current_scene.get_node_or_null("Notice Board") as Node3D
	var jobs := root.get_node("EarthJobs")
	if nb:
		await _talk("nina_earth")
		await _talk_to(nb.get_node("Request Talk"), [0])          # read it with Nina, and follow the first job
		jobs.list[0].progress = jobs.list[0].goal                 # (the job itself: the board's own test does each kind)
		jobs.list[0].done = true
		jobs.changed.emit()
		await _talk_to(nb.get_node("Request Talk"), [-1])         # turn it in
		await _frames(4)
	check(_step("first_night") == "oak", "a job followed, done and turned in: on to the oak (%s)" % _step("first_night"))
	await _physics(30)
	var spot := current_scene.find_child("Oak Spot", true, false)
	await _talk_to(spot)
	await _frames(4)
	check(_step("first_night") == "clues", "listened at the oak: on to the clues (%s)" % _step("first_night"))
	await _physics(30)
	await _talk("lionel")
	var town := root.get_node("EarthTown")
	town.letter_lines()
	for i in 3:
		var acorn := current_scene.get_node_or_null("Glowing Acorn %d" % (i + 1)) as Node3D
		if acorn:
			_player().global_position = acorn.global_position + Vector3(0, 0.3, 0)
			await _physics(8)
	await _frames(4)
	check(_step("first_night") == "dusk", "the book, the letter and three acorns: on to dusk (%s)" % _step("first_night"))
	await _talk_to(spot)
	await _frames(4)
	check(_step("first_night") == "wait", "the acorns in the oak's roots: wait for midnight (%s)" % _step("first_night"))
	# To bed, like a player: walk home and sleep "Until the Shift"
	await _sleep_until_shift()
	check(clock.in_shift() and _step("first_night") == "awaken", "slept until the Shift (%s, %s)" % [clock.earth_time_string(), _step("first_night")])
	var door := current_scene.find_child("PortalToGalaxity", true, false) as Node3D
	_player().global_position = door.global_position + door.global_basis.z * 8.0
	await _frames(6)
	check(oak.revealing, "walking up to the oak at midnight wakes it")
	await create_timer(2.0).timeout
	await shot("oak_reveal")
	await create_timer(oak.REVEAL_TIME).timeout
	await _frames(4)
	check(_step("first_night") == "shift" and oak.awake(), "the door in the oak opens")
	await _through_oak()
	await create_timer(fn.WARP_TIME + 1.6).timeout
	check(game.has_item("shop:shift_watch"), "a watch on the hero's wrist")
	await shot("first_landing")
	await _physics(30)
	var tally := current_scene.get_node_or_null("Tally/Request Talk") as Node3D
	check(tally != null, "Tally's in the Market Square")
	if tally:
		await _talk_to(tally, [-1])
	await _frames(4)
	check(_step("first_night") == "day", "Tally's hello: on to the Void day (%s)" % _step("first_night"))
	await _physics(30)
	for i in 3:
		requests.note("gloop", 1.0, "stomp")
	await _talk("rex")
	await _frames(6)
	if lesson.active:
		lesson.complete("push")
		await create_timer(2.0).timeout
		lesson.complete("ollie")
		await _frames(4)
		lesson.stop()
	game.riding = false
	await _talk("rex")
	check(quests.is_started("bike_boy"), "after the ollie, Rex sends you after Dash: The Bike Boy")
	if requests.list.size() > 0:
		requests.list[0].done = true
		requests.changed.emit()
	await _frames(2)
	watches.pick_up("water_clock")
	await _frames(2)
	var zippy := _starter("lake_loop")
	if zippy:
		await _talk_to(zippy, [-1])
	await _frames(4)
	check(_step("first_night") == "home", "the Void day's list done: on to going home (%s)" % _step("first_night"))

	# --- The Bike Boy: meeting Dash ---
	await _physics(30)
	await _frames(30)
	for i in 3:
		var part := current_scene.get_node_or_null("Dash's Gadget Bit %d" % (i + 1)) as Node3D
		check(part != null, "Dash's dropped bit %d is out" % (i + 1))
		if part:
			_player().global_position = part.global_position + Vector3(0, 0.3, 0)
			_player().velocity = Vector3.ZERO
			await _physics(4)
			await _frames(3)
	await _frames(30)
	check(_step("bike_boy") == "lab", "his three bits picked up: on to his lab (%s)" % _step("bike_boy"))
	await _physics(30)
	await _talk("dash")
	await _frames(20)
	var bot := current_scene.get_node_or_null("Runaway Buzz Bot") as Node3D
	check(bot != null or dialogue.flags.has("bb_bot_caught"), "Dash's Buzz Bot gets loose")   # (or it's bumped into you already)
	for k in 20:
		if not is_instance_valid(bot):
			break
		_player().global_position = bot.global_position + Vector3(0, 0.3, 0)
		await _physics(2)
	await _frames(30)
	await _talk("dash")
	await _frames(30)
	check(_step("bike_boy") == "stall", "the bot caught: Dash's stall opens (%s)" % _step("bike_boy"))
	shop.open("Gadget")
	await _frames(2)
	shop.close()
	await _get_blueprint("popper")                  # (in the Market Square, a few metres from his stall)
	await _frames(30)
	check(_step("bike_boy") == "king", "the Star Popper: on to the Gloop King (%s)" % _step("bike_boy"))
	# He's in his own kingdom now, through the Gloop Gate in the west fields (scripts/gloop_kingdom.gd)
	var gate := current_scene.get_node_or_null("Gloop Gate") as Node3D
	check(gate != null, "the Gloop Gate's in the west fields")
	root.get_node("Bosses").enter_kingdom()
	await _frames(10)
	await _physics(4)
	check(current_scene.scene_file_path == root.get_node("Bosses").KINGDOM, "through it to the Gloop Kingdom")
	var king := current_scene.find_child("The Gloop King", true, false)
	_player().global_position = Vector3(0, 1, 80)
	await _physics(20)
	check(bool(current_scene.get("awake")), "into his court: he's up off his throne")
	await shot("gloop_king")
	await _pop(king)
	check(dialogue.flags.has("popped_gloop_king"), "the Gloop King popped")
	current_scene.call("go_home")
	await _frames(10)
	await _physics(20)
	check(current_scene.scene_file_path == TOWN, "the goo bubble takes you back to the Void")
	await _physics(10)
	await _talk("dash")                               # (the fountain's lost watch first: Dash always takes those first)
	await _frames(10)
	if not quests.is_done("bike_boy"):
		await _talk("dash")
	await _frames(30)
	check(quests.is_done("bike_boy") and game.has_item("shop:gloop_crown"), "Dash's crown: The Bike Boy is done")
	await _end_shift()
	check(current_scene.scene_file_path == EARTH, "pulled home to Earth at 1 AM")
	await _physics(30)
	await _talk("nina_earth")
	await _frames(4)
	check(quests.is_done("first_night"), "The First Night is done")
	await shot("home_again")


# =============================================================================
# Chapter 2: nights 2 to 7 (and Melody and Heather), each straight after the last (scripts/meetings.gd)
# =============================================================================
const FRIENDS := {2: "pip", 3: "bramble", 4: "dash", 5: "astronaut", 6: "rex", 7: "mr_palmer"}


func _ch_nights() -> void:
	var S := root.get_node("Schematics")
	await _next_visit()
	for n in range(2, 8):
		if n == 2 and not root.get_node("Arsenal").owns("popper"):
			await _get_blueprint("popper")     # (if The Bike Boy didn't already: the Market Square, from night 1)
		var q := "night_%d" % n
		if n == 4:
			await _meet_friends()
		check(quests.is_started(q), "night %d's story quest is on" % n)
		if not quests.is_started(q):
			continue
		var friend := _talker(FRIENDS[n])
		check(friend != null, "night %d: %s is in the Void to meet" % [n, FRIENDS[n]])
		if friend:
			await _talk_to(friend)
		check(_step(q) == "explore", "night %d: met %s, on to the night's list (%s)" % [n, FRIENDS[n], _step(q)])
		var items: Array = quests.current_step(q).get("checklist", []).map(func(c: Array) -> String: return str(c[0]))
		for flag in items:
			await _night_do(n, str(flag), S)
			check(dialogue.flags.has(flag), "night %d: %s" % [n, flag])
		await _frames(4)
		quests.check()
		check(quests.is_done(q), "night %d is done" % n)
		if n == 2:
			await shot("night_2")
	var rides: Array = S.LIST.filter(func(e: Dictionary) -> bool: return str(e.kind) == "ride")
	check(rides.all(func(e: Dictionary) -> bool: return S.is_found(str(e.id))), "every ride's schematic found by night 7")
	await _end_shift()


func _meet_friends() -> void:
	check(quests.is_started("meet_friends"), "after Bramble, Melody and Heather")
	await _talk("melody")
	await _frames(30)
	await _talk("clover")
	await _frames(30)
	await _talk("melody")
	await _frames(30)
	check(quests.is_done("meet_friends"), "Melody's song for Heather: done")


func _night_do(n: int, flag: String, S: Node) -> void:
	# Really do each thing on a night's list, the way a player would (from tools/test_later_nights.gd)
	var player := _player()
	if flag.begins_with("schematic_"):
		var id := flag.trim_prefix("schematic_")
		var e: Dictionary = S.entry(id)
		if e.has("sky"):
			S.pick_up(id)                          # (flying the mothership through it: tools/test_schematics.gd)
			return
		if str(e.scene) == "school" and current_scene.scene_file_path != SCHOOL:
			await _go(SCHOOL, "FromTown")
		var pick := current_scene.get_node_or_null("Schematic " + id) as Node3D
		check(pick != null, "the %s's schematic is out" % id)
		if pick == null:
			print("    (night %d, out tonight %s, in this scene: %s)" % [root.get_node("Nights").night(), S.out_tonight(id),
				", ".join(current_scene.get_children().filter(func(c: Node) -> bool: return str(c.name).begins_with("Schematic")).map(func(c: Node) -> String: return str(c.name)))])
		if pick:
			_player().global_position = pick.global_position + Vector3(0, 0.5, 0)
			_player().velocity = Vector3.ZERO
			await _frames(6)
		if current_scene.scene_file_path != TOWN:
			await _go(TOWN, "FromSchool")
		return
	match flag:
		"n2_fizz":
			root.get_node("Shop").open("Gadget")
			await _frames(2)
			root.get_node("Shop").close()
			await _frames(2)
		"n2_letter":
			# The nearest S-K-A-T-E letter
			var best: Node3D = null
			for l in current_scene.find_children("Pickup *", "Area3D", true, false):
				if not (l as Node3D).is_visible_in_tree():
					continue
				if best == null or _flat(l.global_position - player.global_position) < _flat(best.global_position - player.global_position):
					best = l
			if best:
				player.global_position = best.global_position
				await _physics(10)
			if not dialogue.flags.has(flag):
				dialogue.set_flag("skate_letter_K")
				note("couldn't find an S-K-A-T-E letter to walk into on night 2, so one was given")
			await _frames(40)
		"n3_race":
			root.get_node("Races").finished.emit("lake_loop", 2)
		"n4_observatory":
			await _stand_by("Observatory", Vector3(0, 0, 12))
		"n4_ride":
			game.sparkles += 30
			root.get_node("Shop").buy("ride_bike")
			await _frames(40)
		"n5_fly":
			var ship := get_first_node_in_group("mothership")
			if ship and player:
				ship.call("board", player)
				for i in 400:
					await process_frame
					if ship.call("is_piloted") and dialogue.flags.has("n5_fly"):
						break
				ship.call("beam_down")
				await create_timer(4.0).timeout
		"n6_school":
			await _go(SCHOOL, "FromTown")
			await _frames(40)
			await _go(TOWN, "FromSchool")
		"n7_gate":
			await _stand_by("Scary World Gate", Vector3(0, 0, 6))
			# The first step of the centipede's story: say yes at the old gate (it won't open; a whisper sends you on)
			var gate := _find_talker("scary_gate")
			if gate:
				var heard := await _talk_to(gate, [1])
				check(_said(heard, "won't open") and dialogue.flags.has("scary_world_said_yes"), "night 7: yes at the old gate, but it won't open; a whisper sends you to the school")
		"n7_giant":
			# Nobody's in the far field yet (the Agent of Chaos only turns up after Rex and Dash's swap): just go and look
			var giant := current_scene.find_child("ChaosGiant", true, false) as Node3D
			check(giant == null or not giant.visible, "night 7: the Agent of Chaos isn't in the far field yet")
			if player:
				player.global_position = Vector3(112, 12, -200)
				player.velocity = Vector3.ZERO
				await _frames(40)
				await shot("night_7_giant")
		_:
			await _frames(4)


func _stand_by(node_name: String, off: Vector3) -> void:
	var n := current_scene.find_child(node_name, true, false) as Node3D
	if n and _player():
		_player().global_position = n.global_position + off + Vector3(0, 1, 0)
		_player().velocity = Vector3.ZERO
		await _frames(40)


# =============================================================================
# Chapter 3: Bramble's Harvest (the Remnants and the garden), and Shard Isle's quake
# =============================================================================
func _ch_harvest() -> void:
	var farm := root.get_node("Farm")
	await _next_visit()
	# Shard Isle's quake comes once The First Night's done
	await create_timer(portals.QUAKE_DELAY + 4.0).timeout
	check(portals.is_open("shard_isle"), "a time quake: Shard Isle's portal rises in the Void")
	# Bramble asks from the fourth chat on
	var tries := 0
	while not quests.is_started(rem.QUEST) and tries < 8:
		tries += 1
		await _talk("bramble")
	check(quests.is_started(rem.QUEST), "Bramble offers her Harvest (after %d chats)" % tries)
	if tries > 4:
		note("Bramble took %d chats to offer her Harvest" % tries)
	var holder := current_scene.get_node_or_null("Remnants")
	for p in rem.PARTS:
		var part := holder.get_node_or_null("Part " + str(p.id)) as Node3D
		if part:
			_player().global_position = part.global_position + Vector3(0, 0.5, 1.2)
			await _physics(4)
			part.get_node("Spot").use()
	await _frames(4)
	check(rem.parts_found() == 3, "the three tool parts found")
	await _talk("bramble", [1])
	check(rem.has_tool(), "Bramble builds the tool (%s)" % rem.tool_name())
	var vein := holder.get_node("Vein lake_shore") as Node3D
	_player().global_position = vein.global_position + Vector3(0, 0.5, 2.0)
	await _physics(4)
	vein.get_node("Spot").use()
	await create_timer(5.0).timeout
	check(rem.count > 0, "a first vein gives Remnants (%d)" % rem.count)
	await _physics(60)
	var b := _talker("bramble")
	var garden := current_scene.get_node_or_null("Garden") as Node3D
	check(b != null and garden != null and _flat(b.get_parent().global_position - garden.global_position) < 14.0,
		"Bramble waits at your garden")
	await _talk("bramble")
	check(farm.beds[0].tilled, "Bramble's tour digs the first beds")
	_player().global_position = garden.to_global(farm.bed_local(0)) + Vector3(0, 0.5, 1.0)
	await _physics(4)
	farm._use(0)
	await _frames(2)
	if dialogue.is_active():
		dialogue._next()
		var answers: Array = dialogue.current_choices()
		if not answers.is_empty():
			(answers[0] as Button).pressed.emit()
		await _frames(2)
		if dialogue.is_active():
			dialogue.end()
	farm._use(0)                                          # water it
	await _frames(2)
	quests.check()
	check(quests.on_step(rem.QUEST, "grow"), "planted and watered (%s)" % _step(rem.QUEST))
	await shot("garden")
	clock.set_time(clock.day, clock.minutes + 250.0, true)  # the Shift's clock runs on: 4 Void hours later
	farm.update()
	check(farm.ripe(0), "the Blinkberry ripens in the Shift")
	farm._use(0)
	await _frames(4)
	quests.check()
	check(quests.is_done(rem.QUEST) and game.has_item("watering_can"), "Bramble's Harvest is done: the watering can")
	await _end_shift()


# =============================================================================
# The portal worlds
# =============================================================================
func _in_void() -> void:
	# In the Void in the Shift (a new night if need be)
	if not (clock.in_shift() and current_scene.scene_file_path == TOWN):
		await _next_visit()


func _quake_and_enter(id: String, extra := 0) -> bool:
	# Wait for the world's time quake (it comes a few seconds after landing in the Void once the story's there), walk up
	# to its portal and step through
	await _in_void()
	if not portals.is_open(id):
		for i in 3:
			await create_timer(portals.QUAKE_DELAY + 5.0).timeout
			if portals.is_open(id):
				break
			# Not this visit? Try the next night
			await _next_visit()
	check(portals.is_open(id), "%s's time quake comes, and its portal rises (due %s)" % [id, portals.quake_due(id)])
	if not portals.is_open(id):
		return false
	var p := current_scene.get_node_or_null("Portals/Portal " + id) as Node3D
	check(p != null, "%s's portal stands in the Void" % id)
	if p:
		_player().global_position = p.global_position + p.global_basis.z * 3.2 + Vector3(0, 0.5, 0)
		_player().velocity = Vector3.ZERO
		await _physics(30)
		await shot(id + "_portal")
	portals._use_portal(id)
	await _frames(2)
	await _answer([1 if extra > 0 else 0])
	await _wait_for_scene(str(portals.world(id).scene))
	check(current_scene.scene_file_path == str(portals.world(id).scene) and portals.here == id, "stepped through to %s" % id)
	await _physics(20)
	await shot(id + "_inside")
	for e in root.get_node("Schematics").LIST:
		if str(e.get("world", "")) == id:
			await _get_blueprint(str(e.id))
	return portals.here == id


func _get_blueprint(id: String) -> void:
	# Walk into a gadget's blueprint where it lies, then have Dash build it (buying it right away, as a player would on
	# their next visit to his stall: Hayden, 11 Nov, every gadget needs its blueprint and buying)
	var S := root.get_node("Schematics")
	await _physics(4)
	var bp := current_scene.get_node_or_null("Schematic " + id) as Node3D
	check(bp != null or S.is_found(id), "the %s's blueprint is out (%s)" % [id, current_scene.scene_file_path.get_file()])
	if bp:
		var back := _player().global_position
		_player().global_position = bp.global_position + Vector3(0, 0.5, 0)
		_player().velocity = Vector3.ZERO
		await _physics(8)
		_player().global_position = back
		_player().velocity = Vector3.ZERO
		await _physics(4)
	check(S.is_found(id), "...and walking into it finds it")
	var shop := root.get_node("Shop")
	var e: Dictionary = S.entry(id)
	for item in shop.items:
		var it: Dictionary = shop.items[item]
		if str(it.kind) == "gadget" and str(it.gadget) == str(e.what) and not root.get_node("Arsenal").owns(str(e.what)):
			game.sparkles = maxi(game.sparkles, int(it.price))
			check(shop.buy(item), "...and Dash builds the %s" % it.name)


func _answer(picks: Array = []) -> void:
	# Click through whatever's being said, picking answers
	var guard := 400
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			var pick: int = picks.pop_front() if picks.size() > 0 else 0
			buttons[clampi(pick if pick >= 0 else buttons.size() - 1, 0, buttons.size() - 1)].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await create_timer(0.25).timeout


func _chat(spot_path: String, picks: Array = []) -> Array:
	# Talk to someone in a portal world (their talk spot), all the way through
	var spot := current_scene.get_node_or_null(spot_path) as Node3D
	check(spot != null, "%s is there to talk to" % spot_path)
	if spot == null:
		return []
	_player().global_position = spot.global_position + spot.global_basis.z * 1.5 + Vector3(0, 0.5, 0)
	await _physics(4)
	said.clear()
	spot.use()
	await _frames(2)
	await _answer(picks)
	return said.duplicate()


func _wait_talk(most := 10.0) -> Array:
	# Wait for someone to start talking by themselves (a thank-you, a lesson), then hear them out
	var t := 0.0
	said.clear()
	while not dialogue.is_active() and t < most:
		await create_timer(0.25).timeout
		t += 0.25
	await _answer()
	return said.duplicate()


func _home_from(id: String) -> void:
	# The way home, back to the Void by the portal
	var way := current_scene.get_node_or_null("WayHome/Way Home/Spot")
	check(way != null, "%s has a way home" % id)
	if way:
		way.use()
	else:
		portals.go_home()
	await _wait_for_scene(TOWN)
	await _physics(10)
	check(current_scene.scene_file_path == TOWN and portals.here == "", "home to the Void from %s" % id)


func _time_check(id: String) -> void:
	# Was there time left? (A kid needs to manage it in the time a trip gives.)
	print("    (%s: %.0f s of portal time left)" % [id, portals.time_left])


func _ch_shard_isle() -> void:
	if not await _quake_and_enter("shard_isle"):
		return
	var s := current_scene
	for i in 3:
		var e := s.get_node("Echo%d" % (i + 1)) as Node3D
		_player().global_position = e.global_position + Vector3(0, 1, 0)
		await _physics(4)
		s.get_node("Echo%d/Spot" % (i + 1)).use()
	await _use("HeartStone/Heart/Spot")
	check(portals.is_cleared("shard_isle"), "the Echo Crystals in the Heart Stone mend Shard Isle")
	await shot("shard_isle_mended")
	await _home_from("shard_isle")
	await _physics(20)
	check(current_scene.get_node_or_null("Portals/Portal Plaza") != null, "the Portal Plaza has grown in the Void")
	await shot("portal_plaza")


func _ch_rootmind() -> void:
	if not await _quake_and_enter("rootmind"):
		return
	var s := current_scene
	await _chat("Bramble/Spot")
	for i in 3:
		_player().global_position = (s.get_node("Bloom%d" % (i + 1)) as Node3D).global_position + Vector3(0, 1, 0)
		await _physics(4)
		s.get_node("Bloom%d/Spot" % (i + 1)).use()
		await _frames(2)
	check(s.blooms_awake() == 3, "the three Sun Blooms wake")
	_player().global_position = Vector3(0, 0.6, 8.0)
	await _physics(4)
	check(s.calming, "walking up to the Thornknot starts the calming")
	for n in 3:
		s._t = floor(s._t / s.HIVE_BEAT) * s.HIVE_BEAT + s.HIVE_BEAT + 0.3      # (waiting for the hive's blink)
		await _frames(2)
		var k: int = s.glowing_knot()
		if k >= 0:
			s.get_node("Thornknot/Tangle/Knot%d/Spot" % k).use()
		await _frames(2)
	check(portals.is_cleared("rootmind"), "humming with the hive calms the Thornknot: the Rootmind's mended")
	await shot("rootmind_mended")
	var lines := await _wait_talk(12.0)
	check(_said(lines, "under the ground") or root.get_node("Settings").action_shown("burrow"), "Bramble teaches the burrow")
	await _home_from("rootmind")

func _boss(node: Node3D, holder: String, name: String) -> void:
	# Walk up to a sleeping boss until it wakes, then pop it
	_player().global_position = node.global_position + Vector3(0, 0.5, 10)
	await _frames(4)
	var b: Node = current_scene.get(holder)
	check(b != null and is_instance_valid(b) and b.process_mode != Node.PROCESS_MODE_DISABLED, "%s wakes when you come near" % name)
	await _physics(30)
	await shot(name.to_snake_case())
	_player().global_position = node.global_position + Vector3(0, 0.6, 20)
	await _pop(b)


func _ch_frozen_moment() -> void:
	if not await _quake_and_enter("frozen_moment"):
		return
	var s := current_scene
	await _chat("Flurry/Spot")
	for i in 3:
		_player().global_position = (s.get_node("Moment%d" % (i + 1)) as Node3D).global_position + Vector3(0, 0.6, 2.0)
		await _physics(4)
		for k in 3:
			s.get_node("Moment%d/Spot" % (i + 1)).use()
			await _frames(1)
	check(s.moments_thawed() == 3, "three frozen moments thawed")
	await _boss(s.get_node("FrostGloop"), "_gloop", "the Frost Gloop")
	check(portals.is_cleared("frozen_moment"), "popping the Frost Gloop mends the Frozen Moment")
	check(clock.seasons_open.has("winter"), "...and winter can come to Stars Hollow")
	await shot("frozen_moment_mended")
	_time_check("frozen_moment")
	await _home_from("frozen_moment")
	await _physics(20)
	var flurry := current_scene.get_node_or_null("Portals/Flurry/Spot")
	check(flurry != null, "Flurry's come through to the Portal Plaza")
	if flurry:
		await _chat("Portals/Flurry/Spot")
	check(root.get_node("Settings").action_shown("frost_breath"), "Flurry's frost breath is learned")
	await shot("flurry_on_the_plaza")


func _ch_lanternmoor() -> void:
	if not await _quake_and_enter("lanternmoor"):
		return
	var s := current_scene
	var lines := await _chat("Pip/Spot")
	check(s.has_wings(), "Pip lends moth wings")
	for i in 5:
		s.get_node("Lantern%d/Spot" % (i + 1)).use()
	check(s.is_beacon_lit(0), "the Night Path's five lanterns light its beacon")
	# Moon Rock: a running jump off the Tall Lantern Tree, gliding on Pip's wings
	var player := _player()
	var launch := (s.get_node("Launch") as Node3D).global_position
	var rock := (s.get_node("Beacon2") as Node3D).global_position
	var dir := Vector3(rock.x - launch.x, 0, rock.z - launch.z).normalized()
	player.global_position = launch + dir * 1.8 + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	player.spring_arm.global_rotation = Vector3(0, atan2(-dir.x, -dir.z), 0)
	await _physics(10)
	Input.action_press("move_forward")
	Input.action_press("jump")
	player.velocity = dir * 5.0 + Vector3(0, 6.0, 0)
	await _physics(6)
	var n := 0
	while n < 600 and not (player.is_on_floor() and n > 20):
		await physics_frame
		n += 1
	Input.action_release("move_forward")
	Input.action_release("jump")
	await _physics(6)
	check(player.global_position.y > 6.0, "gliding from the Tall Lantern Tree to Moon Rock (landed at %s)" % player.global_position)
	s.get_node("Beacon2/Spot").use()
	check(s.is_beacon_lit(1), "Moon Rock's beacon lit")
	for i in 3:
		var l: Node3D = s.light_node(i)
		if l:
			l.get_node("Hit").shot(1, Vector3.ZERO, Vector3.FORWARD)
			await _frames(2)
	for i in 40:
		await create_timer(0.25).timeout
		if s.beacons_lit() == 3:
			break
	check(s.beacons_lit() == 3, "the runaway lights caught: three beacons")
	await _boss(s.get_node("Snatcher"), "_snatcher", "the Dawn Snatcher")
	check(portals.is_cleared("lanternmoor"), "popping the Dawn Snatcher mends Lanternmoor")
	await create_timer(1.0).timeout
	await shot("lanternmoor_sunrise")
	lines = await _wait_talk(12.0)
	check(not lines.is_empty(), "Pip teaches their glow")
	_time_check("lanternmoor")
	await _home_from("lanternmoor")

func _ch_rhythm_springs() -> void:
	if not await _quake_and_enter("rhythm_springs"):
		return
	var s := current_scene
	await _chat("Melody/Spot")
	var player := _player()
	# The Sizzle Steps' shell (walking the stones is checked in test_rhythm_springs) and the mesa's
	for k in 2:
		var shell := (s.get_node("Shell%d" % (k + 1)) as Node3D).global_position
		player.global_position = shell + Vector3(0, 0.9, 1.8)
		await _physics(4)
		player.global_position = shell + Vector3(0, 0.9, 0.3)
		await _physics(6)
	check(s.shells() == 2, "the Sizzle Steps' and Waterfall Mesa's shells (%d)" % s.shells())
	var slide := s.get_node_or_null("SlideTop/Spot")
	if slide:
		slide.use()
		var t := 0
		while s.riding_slide and t < 900:
			await physics_frame
			t += 1
		await _physics(30)
	# Dancing with Melody: press Jump on her beat, like a player keeping time
	player.global_position = (s.get_node("DanceFloor") as Node3D).global_position + Vector3(0, 0.9, 0)
	await _physics(10)
	s.get_node("DanceFloor/Spot").use()
	check(s.dancing, "dancing with Melody")
	var t2 := 0.0
	var last_beat := -1
	while s.dancing and t2 < 40.0:
		await process_frame
		t2 += root.get_process_delta_time()
		var ph: float = s._dance_phase
		if (ph > 0.95 or ph < 0.05) and int(s._dance_beats) != last_beat:
			last_beat = int(s._dance_beats)
			s.dance_press()
	check(s.shells() == 3, "eight presses on Melody's beat: the Dance Floor's shell (after %.0f s)" % t2)
	# The Off-Beat
	var ob := s.off_beat as Node3D
	player.global_position = (s.get_node("OffBeat") as Node3D).global_position + Vector3(0, 0.2, 12)
	await _frames(4)
	check(ob.awake, "with all three shells, the Off-Beat wakes")
	await _physics(30)
	await shot("the_off_beat")
	player.global_position = Vector3(0, 0.9, 20)
	var guard := 0
	while not ob.defeated and guard < 40:
		guard += 1
		ob._shot_cd = 0.0
		ob.shot_weight()
		await _frames(1)
	await _frames(4)
	check(portals.is_cleared("rhythm_springs") and clock.season_open("summer"), "the Off-Beat's back in time: Rhythm Springs mended, summer open")
	var lines := await _wait_talk(12.0)
	check(not lines.is_empty(), "Melody teaches her groove")
	await create_timer(4.0).timeout
	await shot("rhythm_springs_evening")
	_time_check("rhythm_springs")
	await _home_from("rhythm_springs")


func _bring_otto(s: Node, to: Vector3) -> void:
	_player().global_position = to
	_player().velocity = Vector3.ZERO
	var t := 0
	while not s.otto_near(to, 4.0) and t < 900:
		await process_frame
		t += 1


func _ch_tide_reef() -> void:
	if not await _quake_and_enter("tide_reef"):
		return
	var s := current_scene
	var home: Vector3 = s.otto_at()
	await _chat("Otto the Octopus/Spot")
	check(s.met_otto(), "met Otto")
	var vault := (s.get_node("Vault") as Node3D).global_position
	await _bring_otto(s, vault + Vector3(0, 0.9, 0))
	s.get_node("Vault/Spot").use()
	await create_timer(2.8).timeout
	_player().global_position = (s.get_node("Pearl1") as Node3D).global_position + Vector3(0, 0.9, 0.3)
	await _frames(6)
	check(s.has_pearl(0), "Otto opens the Clam Vault: the first pearl")
	var right: int = s.right_hole
	await _bring_otto(s, (s.get_node("Hole%d" % (right + 1)) as Node3D).global_position + Vector3(-0.8, 0.9, 0))
	s.get_node("Hole%d/Spot" % (right + 1)).use()
	await _frames(4)
	check(s.has_pearl(1), "Otto reaches into the glinting hole: the second pearl")
	var pad := (s.get_node("BubblePad") as Node3D).global_position
	await _bring_otto(s, pad + Vector3(0, 0.9, 0))
	s.get_node("BubblePad/Spot").use()
	await create_timer(2.4).timeout
	# Up his bubble steps (each one hopped in test_tide_reef), to the top
	_player().global_position = (s.get_node("Pearl3") as Node3D).global_position + Vector3(0, 0.9, 0.3)
	await _frames(6)
	check(s.pearls() == 3, "the spire's pearl: all three")
	var ride := s.get_node_or_null("RideTop/Spot")
	if ride:
		ride.use()
		var t := 0
		while s.riding and t < 1500:
			await physics_frame
			t += 1
		await _physics(50)
	var g := s.riptide as CharacterBody3D
	var basin := (s.get_node("RiptideGloop") as Node3D).global_position
	_player().global_position = basin + Vector3(0, 0.9, 13)
	await _frames(4)
	check(s.riptide_awake, "with three pearls the Riptide Gloop wakes")
	await _physics(30)
	await shot("riptide_gloop")
	_player().global_position = basin + Vector3(26, 0.9, 26)
	var t3 := 0
	while not s.is_mended() and t3 < 6000:
		await process_frame
		t3 += 1
		if g.held and not g.defeated:
			g.shot(1, g.global_position, Vector3.FORWARD)
	check(portals.is_cleared("tide_reef"), "popped while Otto holds it: the Tide Reef's mended (%.0f s)" % (t3 / 60.0))
	for i in 4:
		if portals.has_found("tide_reef", "swim_taught") and not dialogue.is_active():
			break
		await _wait_talk(15.0)
	check(portals.has_found("tide_reef", "swim_taught"), "Otto teaches you to swim")
	await create_timer(s.FLOOD_TIME + 1.5).timeout
	check(s.flood == 1.0, "the sea floods back in")
	for i in s.LAMPS.size():
		_player().global_position = s.LAMPS[i] + Vector3(1.0, -0.6, 0)
		_player().velocity = Vector3.ZERO
		await _physics(8)
	check(s.lamps_lit() == 5, "swim to the five sea lanterns (%d)" % s.lamps_lit())
	await shot("under_the_sea")
	var chest := s.get_node_or_null("Reef Chest/Spot")
	if chest:
		_player().global_position = (chest as Node3D).global_position + Vector3(0, 0.5, 1.5)
		await _physics(6)
		chest.use()
	check(s.chest_open(), "the Reef Chest opened")
	_time_check("tide_reef")
	if portals.time_left < 30.0:
		note("the Tide Reef took nearly all of a trip's time in one go (%.0f s left)" % portals.time_left)
	await _home_from("tide_reef")
	await _physics(20)
	check(current_scene.find_child("Otto", true, false) != null, "Otto's on the Portal Plaza")


func _ch_glenmoor() -> void:
	if not await _quake_and_enter("glenmoor"):
		return
	var s := current_scene
	await _chat("Heather/Spot")
	await _chat("Isla Runner/Spot")
	# The Fluffkins (herding each one through the gate is checked in test_glenmoor)
	for i in 5:
		s.pen_fluff(i)
	check(s.has_bell(0), "five Fluffkins in the Fold: the Sun Charm")
	# The garden: sing to each flower while it's open, waiting for day or night to come round as a player would
	var t := 0.0
	while not s.has_bell(1) and t < 120.0:
		for b in 5:
			if s.in_bloom(b) and not s.is_held(b):
				var bed := s.get_node("Bed%d" % (b + 1)) as Node3D
				_player().global_position = bed.global_position + Vector3(0, 0.9, 1.5)
				await _physics(2)
				s.get_node("Bed%d/Spot" % (b + 1)).use()
		await create_timer(0.5).timeout
		t += 0.5
	check(s.has_bell(1), "every flower sung to while it's open: the Twilight Charm (took %.0f s of waiting for day and night)" % t)
	if t > 60.0:
		note("Glenmoor's garden took %.0f s of waiting for day and night to come round" % t)
	# The hill race: run cairn to cairn at running speed
	await _chat("Isla Runner/Spot")
	if not s.racing:
		s.get_node("Isla Runner/Spot").use()
	var w := 0
	while s.racing and not s.race_go and w < 600:
		await process_frame
		w += 1
	var prev := (s.get_node("RaceStart") as Node3D).global_position
	for i in 6:
		var at := (s.get_node("Cairn%d" % (i + 1)) as Node3D).global_position
		await create_timer(Vector2(at.x - prev.x, at.z - prev.z).length() / 5.0).timeout
		_player().global_position = at + Vector3(0.6, 1.0, 0)
		await _physics(3)
		prev = at
	check(s.has_bell(2), "the hill race up Ben Bonnie won: the Moon Charm")
	var storm := s.get_node("The Stormram") as CharacterBody3D
	_player().global_position = (s.get_node("Stormram") as Node3D).global_position + Vector3(0, 0.6, 14)
	await _frames(4)
	check(not storm.get("asleep"), "with three charms the Stormram wakes")
	await _physics(30)
	await shot("the_stormram")
	_player().global_position = Vector3(0, 0.9, 30)
	var g := 0
	while not storm.get("defeated") and g < 40:
		g += 1
		storm.call("_set_state", 4)                            # (dizzy, after a charge)
		storm.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("glenmoor") and clock.season_open("spring"), "the Stormram popped: Glenmoor mended, spring open")
	for i in 3:
		if root.get_node("Settings").action_shown("showers") and not dialogue.is_active():
			break
		await _wait_talk(10.0)
	check(root.get_node("Settings").action_shown("showers"), "Heather teaches April Showers and the Spring Step")
	await create_timer(3.0).timeout
	await shot("glenmoor_peace")
	await _home_from("glenmoor")


func _ch_dark_hollow() -> void:
	# The secret way in: the centipede's corner Behind the Walls in the castle school
	await _in_void()
	await _go(SCHOOL, "FromTown")
	var corner := current_scene.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner") as Node3D
	check(corner != null, "the centipede's corner is in the castle school")
	if corner == null:
		return
	if not dialogue.flags.has("scary_world_said_yes"):
		dialogue.set_flag("scary_world_said_yes")           # (if night 7 didn't run in this playthrough)
	_player().global_position = corner.to_global(Vector3(-21.0, 1.0, -22.45))
	await _physics(10)
	check(corner.shown and corner.arriving, "come near and she comes walking along the ceiling")
	await create_timer(corner.WALK_FROM / corner.WALK_SPEED + 1.0).timeout
	check(corner.shown and not corner.arriving, "...and drops into her nest")
	await shot("centipede_corner")
	_player().global_position = corner.to_global(corner.SPOT_AT) + Vector3(1.0, 1.0, 0)
	await _physics(6)
	corner.get_node("Spot").use()
	await _frames(2)
	await _answer([0])
	for i in 40:
		await create_timer(0.25).timeout
		if portals.here == "dark_hollow" and current_scene.find_child("Player", true, false):
			break
	check(portals.here == "dark_hollow", "she gulps you down to Dark Hollow")
	await create_timer(1.5).timeout
	await shot("dark_hollow_inside")
	var s := current_scene
	for i in 8:
		var g: Node = s.ghost_node(i)
		if g and not g.defeated:
			g.pop(true)
	await create_timer(1.5).timeout
	var piece := s.get_node_or_null("Piece1") as Node3D
	if piece:
		_player().global_position = piece.global_position + Vector3(0, -0.4, 0)
		await _frames(6)
	check(s.pieces_found() == 1, "eight shadow ghosts popped: the first Moon Piece")
	_player().global_position = Vector3(0.0, 1.5, 0.0)                 # into the Big Hole
	_player().velocity = Vector3.ZERO
	var n := 0
	while n < 300 and s.spits == 0:
		await physics_frame
		n += 1
	n = 0
	while n < 300 and not (_player().is_on_floor() and n > 20):
		await physics_frame
		n += 1
	await _frames(4)
	check(s.pieces_found() == 2, "the Big Hole spits you up the Crooked Spire: the second piece")
	var races := root.get_node("Races")
	var t: Node3D = races.track_node("hollow_run")
	check(t != null, "the Hollow Run is here")
	if t:
		var p := _player()
		p.global_position = t.point_at(-3.0) + Vector3.UP * 0.9
		await _physics(4)
		races.start("hollow_run")
		await _physics(int(races.COUNTDOWN * 60) + 10)
		for lap in int(races.TRACKS.hollow_run.laps):
			for i in range(1, t.cp_dist.size() + 1):
				var d: float = t.cp_dist[i % t.cp_dist.size()]
				p.global_position = t.point_at(d - 2.0) + Vector3.UP * 0.85
				p.velocity = t.dir_at(d) * 7.0
				await _physics(4)
				p.global_position = t.point_at(d) + Vector3.UP * 0.85
				await _physics(3)
				if races.state != races.State.RACING:
					break
		await _physics(int(races.RESULTS_TIME * 60) + 20)
		if game.riding:
			game.toggle_skateboard()
	check(s.pieces_found() == 3, "the Hollow Run finished: the third piece")
	var h: CharacterBody3D = s.hush()
	var hill := (s.get_node("Hush") as Node3D).global_position
	_player().global_position = hill + Vector3(0, 1.0, 12)
	await _frames(4)
	check(s.hush_awake, "with three pieces the Hush wakes")
	await _physics(20)
	await shot("the_hush")
	_player().global_position = Vector3(0, 1.0, 20)
	var lamp: Vector3 = s.lamp_pos(0)
	var toward := (hill - lamp)
	toward.y = 0
	for k in 14:
		if not is_instance_valid(h) or h.defeated:
			break
		h.global_position = Vector3(lamp.x, h.global_position.y, lamp.z) + toward.normalized() * 4.0
		s.light_lamp(0)
		await _physics(2)
		h.shot(1, h.global_position, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("dark_hollow"), "popped in a moon lamp's light: Dark Hollow's mended")
	var lines := await _wait_talk(12.0)
	check(_said(lines, "old gate"), "the centipede cheers and asks you to come to her home, behind the old gate")
	await create_timer(2.0).timeout
	await shot("dark_hollow_mended")
	# The way home takes you to her home this first time: her scary game, then friends for keeps and her gifts
	current_scene.get_node("WayHome/Way Home/Spot").use()
	await _wait_for_scene(SCARY)
	await _physics(10)
	check(current_scene.scene_file_path == SCARY, "the way home takes you to her home, behind the old gate")
	var her := _find_talker("centipede")
	if her:
		await _talk_to(her, [0])
	await _frames(4)
	var boss := current_scene.get_node_or_null("Centipede Boss")
	check(boss != null, "she asks to play her scary game, and it's on")
	if boss:
		await create_timer(3.0).timeout
		await shot("centipede_boss")
		while not boss.defeated:
			boss.state = "dizzy"
			boss.hurt(1)
		var thanks := await _wait_talk(12.0)
		check(_said(thanks, "climb") and _said(thanks, "knock"), "you stayed: friends for keeps, and she teaches the wall crawl and her holes")
	await create_timer(1.0).timeout
	await _go(TOWN, "FromScaryWorld")
	check(current_scene.scene_file_path == TOWN, "home to the Void")


func _ch_far_future() -> void:
	if not await _quake_and_enter("far_future"):
		return
	var s := current_scene
	await _chat("Rex/Spot")
	await _chat("Dash/Spot")
	var player := _player()
	for i in 2:
		var pad := (s.get_node("Lift%d" % (i + 1)) as Node3D).global_position
		player.global_position = pad + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		await _physics(4)
		s.get_node("Lift%d/Spot" % (i + 1)).use()
		await create_timer(s.LIFT_TIME + 0.3).timeout
		await _physics(20)
		var f := s.get_node("Fuse%d" % (i + 2)) as Node3D
		player.global_position = f.global_position + Vector3(0, 0.9, 1.2)
		await _physics(4)
		s.get_node("Fuse%d/Spot" % (i + 2)).use()
	var f1 := s.get_node("Fuse1") as Node3D
	player.global_position = f1.global_position + Vector3(0, 0.9, 1.2)
	await _physics(4)
	s.get_node("Fuse1/Spot").use()
	check(s.is_core_home(0), "three Chrono Fuses: the Swap-o-Tron hums, the first Time Core")
	for i in 6:
		var folk := s.get_node("Folk%d" % (i + 1)) as Node3D
		player.global_position = folk.global_position + Vector3(1.4, 0.9, 0)
		await _physics(4)
		if not s.is_pinned(i):
			(s.get_node("Folk%d/Hit" % (i + 1)) as Node).shot(1, Vector3.ZERO, Vector3.FORWARD)
	check(s.pinned() == 6 and s.is_core_home(2), "six fading folk pinned back into time: the third core")
	if dialogue.is_active():
		await _answer()
	var races := root.get_node("Races")
	var t: Node3D = races.track_node("skyway_run")
	if t:
		var p := _player()
		p.global_position = t.point_at(-3.0) + Vector3.UP * 0.9
		await _physics(4)
		races.start("skyway_run")
		await _physics(int(races.COUNTDOWN * 60) + 10)
		await shot("skyway_run")
		for lap in int(races.TRACKS.skyway_run.laps):
			for i in range(1, t.cp_dist.size() + 1):
				var d: float = t.cp_dist[i % t.cp_dist.size()]
				p.global_position = t.point_at(d - 2.0) + Vector3.UP * 0.85
				p.velocity = t.dir_at(d) * 7.0
				await _physics(4)
				p.global_position = t.point_at(d) + Vector3.UP * 0.85
				await _physics(3)
				if races.state != races.State.RACING:
					break
		await _physics(int(races.RESULTS_TIME * 60) + 20)
		if game.riding:
			game.toggle_skateboard()
	check(s.cores() == 3, "the Skyway Run: all three Time Cores home")
	var c := s.get_node("Captain Glitch") as CharacterBody3D
	var m := (s.get_node("Captain") as Node3D).global_position
	player.global_position = m + Vector3(0, 1.0, 10)
	await _frames(4)
	check(s.captain_awake, "Captain Glitch wakes")
	await _physics(30)
	await shot("captain_glitch")
	player.global_position = Vector3(0, 1.0, 40)
	var g := 0
	while not c.get("defeated") and g < 40:
		g += 1
		c.call("_set_state", 3)                      # (open, after crashing down)
		c.shot(1, Vector3.ZERO, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("far_future"), "Captain Glitch popped: the Far Future's mended")
	await create_timer(s.THANKS_AFTER + 0.4).timeout
	await _answer()
	await shot("lumen_city_mended")
	check(quests.is_started("stop_his_clock"), "the quest Stop His Clock starts")
	# Rex's shot at his own body
	await _physics(30)
	var lever := s.get_node_or_null("SwapOTron/Spot")
	check(lever != null and s.can_try_swap(), "the Swap-o-Tron's lever is there to pull")
	if lever:
		player.global_position = (s.get_node("SwapOTron") as Node3D).global_position + Vector3(0, 1.0, 3.5)
		await _physics(4)
		lever.use()
		await create_timer(s.SWAP_FLASH + 0.4).timeout
		await shot("rex_has_hands")
		await create_timer(s.SWAP_DONE - s.SWAP_FLASH + 0.3).timeout
		await _answer()
	check(dialogue.flags.has(s.SWAP_FLAG) and load("res://scripts/chaos_fight.gd").unlocked(), "the swap snaps back: the Agent of Chaos's fight is open")
	await _home_from("far_future")


# =============================================================================
# The last chapter: the Agent of Chaos, his friends' sections, and the ending
# =============================================================================
var _fight: Node
var _trials: Node
var _giant: Node3D


func _ch_chaos() -> void:
	await _in_void()
	var ars := root.get_node("Arsenal")
	check(ars.ORDER.all(func(g: String) -> bool: return ars.owns(g)), "every gadget's been found and bought by now (%s)" % str(ars.owned))
	_giant = current_scene.find_child("ChaosGiant", true, false) as Node3D
	check(_giant != null, "the Agent of Chaos is in his field")
	if _giant == null:
		return
	_fight = _giant.get_node("ChaosFight")
	_trials = _fight.get_node_or_null("Trials")
	var p := _player()
	p.global_position = _giant.global_position + Vector3(0, 40, 60)
	await _physics(4)
	await _stand_at(_giant.global_position + Vector3(0, 0, 15))
	await _physics(6)
	check(_fight.active, "walking up to him starts the final fight")
	await shot("final_fight")
	var expected: Array = []
	for ph in [1, 2, 3]:
		for sec in _trials.SECTIONS:
			if int(sec.phase) == ph and _trials.learned(str(sec.id)):
				expected.append(str(sec.id))
	print("    (sections this save should get: %s)" % ", ".join(expected))
	var seen: Array = []
	var t := 0.0
	var last_shot := 0.0
	var ending: Node = _fight.get("ending")
	while t < 900.0 and not dialogue.flags.has("beat_agent_of_chaos") and not (ending and ending.playing()):
		await physics_frame
		t += 1.0 / 60.0
		if not _fight.active:
			check(false, "the fight stays on (it stopped at %.0f s, chaos %d)" % [t, _fight.chaos])
			break
		var cur := str(_trials.current)
		if cur != "" and not cur in seen:
			seen.append(cur)
			print("    (%.0f s: %s's section, chaos %d, phase %d)" % [t, cur, _fight.chaos, _fight.phase])
			await _do_section(cur)
			continue
		# Pop his minions, if any
		for m in _fight.minions:
			if is_instance_valid(m) and not bool(m.get("defeated")) and m.has_method("shot") and fmod(t, 0.5) < 0.02:
				m.shot(1, (m as Node3D).global_position, Vector3.FORWARD)
		if _fight.vulnerable() and t - last_shot > 0.25:
			last_shot = t
			_giant.shot(1, _fight.heart_position(), Vector3.FORWARD)
		# Stand back out of his bursts' way
		if _flat(p.global_position - _giant.global_position) < 10.0 and cur == "":
			await _stand_at(_giant.global_position + Vector3(0, 0, 15))
	print("    (the fight took %.0f s of game time)" % t)
	check(expected.all(func(x: String) -> bool: return x in seen), "every friend's section came up (%s)" % ", ".join(seen))
	check(dialogue.flags.has("beat_agent_of_chaos") or (ending and ending.playing()), "the Agent of Chaos is beaten")
	# The ending
	ending = _fight.get("ending")
	check(ending != null and ending.playing(), "the ending cutscene plays")
	if ending:
		var beats: Array = []
		var e := 0.0
		while ending.playing() and e < 60.0:
			await create_timer(0.5).timeout
			e += 0.5
			if not str(ending.beat) in beats:
				beats.append(str(ending.beat))
				if str(ending.beat) in ["shatter", "light", "friends", "title"]:
					await shot("ending_" + str(ending.beat))
			if dialogue.is_active():
				dialogue._finish_typing()
		print("    (the ending's parts: %s)" % ", ".join(beats))
		check(not ending.playing() and e < 50.0, "the ending finishes (%.0f s) and you can play on" % e)
		check(not p.input_locked, "...with the controls back")
	await _physics(30)
	check(dialogue.flags.has("beat_agent_of_chaos"), "the Agent of Chaos is beaten (flag)")
	check(quests.is_done("stop_his_clock"), "the quest Stop His Clock is done")
	var w := current_scene.find_child("Pocket Watch", true, false) as Node3D
	if w == null and ending:
		w = ending.get("watch")
	check(w != null, "he left a little pocket watch in the grass")
	if w:
		p.global_position = w.global_position + Vector3(0, 0.6, 0)
		await _physics(10)
		await _answer()
	await shot("after_the_ending")
	# Save, and load it back, as the next time the game's started
	game.save_game()
	var flags_before: Dictionary = dialogue.flags.duplicate()
	game._reset_state()
	game.load_game()
	check(dialogue.flags.has("beat_agent_of_chaos") and portals.cleared_worlds.size() >= 9, "it all saves and loads (%d worlds mended)" % portals.cleared_worlds.size())
	var lost := flags_before.keys().filter(func(k) -> bool: return not dialogue.flags.has(k))
	check(lost.is_empty(), "no flags lost on loading (%s)" % ", ".join(lost.slice(0, 6)))


func _stand_at(at: Vector3) -> void:
	var g: Vector3 = _fight._ground(at)
	_player().global_position = g + Vector3(0, 0.6, 0)
	_player().velocity = Vector3.ZERO
	await _physics(2)


func _land() -> void:
	for i in 90:
		await physics_frame
		if _player().is_on_floor():
			return


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await physics_frame


func _face_to(at: Vector3) -> void:
	var p := _player()
	var d := at - p.global_position
	var yaw := atan2(d.x, d.z)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		visual.global_rotation.y = yaw
	var cam := p.find_child("SpringArm3D", true, false) as Node3D
	if cam:
		cam.global_rotation.y = yaw + PI


func _do_section(id: String) -> void:
	# Each friend's move, the way the trials test does it for real (tools/test_chaos_trials.gd)
	var p := _player()
	var tr := _trials
	match id:
		"burrow":
			await _stand_at(tr.knot.global_position + tr._out * 1.5)
			await _land()
			p.burrow.try_start()
			p.global_position = Vector3(tr.knot.global_position.x, p.global_position.y, tr.knot.global_position.z)
			await _until(func() -> bool: return tr.current == "", 120)
			if p.burrow.active:
				p.burrow.stop()
			await _land()
		"frost":
			await _stand_at(tr._base + tr._out * 16.0)
			await _land()
			_face_to(tr._base)
			p.frost_breath.cooldown = 0.0
			p.frost_breath.breathe()
			var floes: Array = p.frost_breath.floes.filter(func(f: Node3D) -> bool: return tr._in_river(f.global_position))
			check(not floes.is_empty(), "frost breath freezes the River of Melted Time")
			if not floes.is_empty():
				p.global_position = (floes[0] as Node3D).global_position + Vector3(0, 0.8, 0)
				await _physics(25)
			await _stand_at(tr.knot.global_position)
			await _until(func() -> bool: return tr.current == "", 120)
		"glow":
			for i in 2:
				await _stand_at(tr.lanterns[i].global_position + tr._out * 2.0)
				await _physics(10)
			await _stand_at(tr.swirl_at)
			await _land()
			Input.action_press("jump")
			await _physics(45)
			Input.action_release("jump")
			p.global_position = tr.rock.global_position + Vector3(0, 1.2, 0)
			p.velocity = Vector3.ZERO
			await _until(func() -> bool: return tr.current == "", 120)
		"groove":
			await _stand_at(_giant.global_position + tr._out * 8.0)
			for i in 3:
				p.groove.grooved.emit(true, i + 1)
			await _until(func() -> bool: return tr.current == "", 60)
		"swim":
			await create_timer(3.4).timeout
			await _stand_at(tr.knot.global_position + tr._out * 3.0)
			await _physics(30)
			p.global_position = tr.knot.global_position + Vector3(0, 0.2, 0)
			p.velocity = Vector3.ZERO
			await _until(func() -> bool: return tr.current == "", 120)
			await create_timer(1.8).timeout
			await _land()
		"spring":
			await _physics(2)
			for f in tr.fires:
				await _stand_at(f.global_position + tr._out * 1.5)
				await _land()
				p.showers.cooldown = 0.0
				p.showers.raining = 0.0
				p.showers.shower()
				await _physics(4)
			await create_timer(1.6).timeout
			if tr.gear:
				p.global_position = tr.gear.global_position + Vector3(0, 1.0, 0)
				p.velocity = Vector3.ZERO
			await _until(func() -> bool: return tr.current == "", 120)
			await _land()
		"gadgets":
			var arsenal := root.get_node("Arsenal")
			var g: String = arsenal.owned.filter(func(x: String) -> bool: return x != "popper")[0]
			arsenal.current = g
			for c in tr.crystals:
				arsenal.hit(c, 1, Vector3.FORWARD, g)
			await _until(func() -> bool: return tr.current == "", 60)
			arsenal.current = "popper"
		"crawl":
			await create_timer(1.5).timeout
			var tower: StaticBody3D = tr.tower
			var face: Vector3 = tower.global_position - tr._out * 1.95
			await _stand_at(Vector3(face.x, 0, face.z))
			await _land()
			p.wall_crawl.start(-tr._out)
			_face_to(tower.global_position)
			Input.action_press("move_forward")
			await _until(func() -> bool: return tr.current == "", 400)
			Input.action_release("move_forward")
			if p.wall_crawl.active:
				p.wall_crawl.stop()
			await _stand_at(_giant.global_position + tr._out * 12.0)
			await _land()
		"watch":
			await _physics(2)
			p.get_node("HUD").check_watch()
			await _until(func() -> bool: return tr.current == "", 60)
			await create_timer(1.0).timeout
	check(tr.done.has(id), "%s's section done" % id)


# =============================================================================
# Helpers: the way a player gets about

# =============================================================================
func _sleep_until_shift() -> void:
	# Home to bed, and sleep "Until the Shift" (the next midnight on Earth)
	if current_scene.scene_file_path != EARTH:
		await _go(EARTH, "HomeSpawn")
	var bed := current_scene.find_child("SleepSpot", true, false)
	check(bed != null, "the bed's there to sleep in")
	if bed == null:
		return
	_player().global_position = (current_scene.find_child("HomeSpawn", true, false) as Node3D).global_position
	await _frames(2)
	bed.sleep_for(clock.minutes_until_hour(0))
	for i in 600:
		await process_frame
		if clock.in_shift() and not bool(bed.get("_busy")) and not paused:
			break
	await _frames(10)


func _through_oak() -> void:
	# Walk into the oak's door (it's open in the Shift)
	if current_scene.scene_file_path != EARTH:
		await _go(EARTH, "Entrance")
	var door := current_scene.find_child("PortalToGalaxity", true, false) as Node3D
	var p := _player()
	if door and p:
		p.global_position = door.global_position + Vector3(0, 0.5, 0)
		p.velocity = Vector3.ZERO
	for i in 200:
		await process_frame
		if current_scene and current_scene.scene_file_path == TOWN:
			break
	await _frames(10)
	check(current_scene.scene_file_path == TOWN, "through the oak into the Void")


func _end_shift() -> void:
	# The Shift runs out (it lasts an Earth hour), and the portal pulls them home
	clock.pulls_home = true
	clock.end_shift()
	await _wait_for_scene(EARTH, 400)
	await _frames(10)


func _next_visit() -> void:
	# Another night: home, to bed till midnight, through the oak
	if clock.in_shift() and current_scene.scene_file_path == TOWN:
		await _end_shift()
	await _sleep_until_shift()
	await _through_oak()
	await create_timer(3.5).timeout


func _pop(enemy: Node, most := 300) -> void:
	# Bubbles at it until it pops (the way the per-boss tests do: their fights are checked there)
	var guard := most
	while is_instance_valid(enemy) and not bool(enemy.get("defeated")) and guard > 0:
		guard -= 1
		if enemy.has_method("shot"):
			enemy.shot(1, (enemy as Node3D).global_position, Vector3.FORWARD)
		await _physics(2)
	await _frames(4)


func shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	shot_n += 1
	img.save_png(shots_dir.path_join("%02d_%s.png" % [shot_n, name]))
	print("  (picture: %02d_%s.png)" % [shot_n, name])


func _step(q: String) -> String:
	return str(quests.current_step(q).get("id", ""))


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D if current_scene else null


func _talker(id: String) -> Area3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func _starter(track: String) -> Node3D:
	for t in current_scene.find_children("*", "Area3D", true, false):
		# (the starter's at the race gate: scripts/races.gd HUBS; any open race can be picked there)
		if t.get_parent() and (str(t.get_parent().get_meta("track_id", "")) == track \
				or str(t.get_parent().get_meta("hub_id", "")) == root.get_node("Races").hub_of(track)) and t.has_method("begin_talk"):
			return t
	return null


func _said(lines: Array, text: String) -> bool:
	return lines.any(func(l: Array) -> bool: return str(l[1]).contains(text))


func _talk(id: String, picks: Array = []) -> Array:
	var t := _talker(id)
	if t == null:
		check(false, "%s is here to talk to (%s)" % [id, current_scene.scene_file_path.get_file()])
		return []
	return await _talk_to(t, picks)


func _talk_to(t: Node3D, picks: Array = []) -> Array:
	# Stand by them and talk it all the way through, picking answers (-1: the last one)
	var player := _player()
	var body := t.get_parent() as Node3D
	if player and body:
		player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
		player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame
	said.clear()
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 400
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
	for l in said:
		if str(l[1]).contains("{") or str(l[1]).to_lower().contains("galaxity"):
			check(false, "a line reads right: \"%s\"" % l[1])
	return said.duplicate()


func _use(path_or_node) -> void:
	var n: Node = path_or_node if path_or_node is Node else current_scene.get_node_or_null(str(path_or_node))
	check(n != null, "there's a %s to use" % str(path_or_node))
	if n:
		n.use()
	await _frames(2)


func _go(scene: String, spawn := "") -> void:
	game.go(scene, spawn)
	await _wait_for_scene(scene)


func _wait_for_scene(path: String, frames := 300) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path and current_scene.find_child("Player", true, false):
			break
	await _frames(6)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _find_talker(id: String) -> Node3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null
