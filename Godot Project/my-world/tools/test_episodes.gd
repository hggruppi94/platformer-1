extends SceneTree

# Plays the five quests from the show's first episodes from start to finish (scripts/episodes.gd, quests/
# slide_mystery.json, emergency_prep.json, dog_rights.json, turtle_independence.json, aftershock.json):
# - We Need a Slide!: Melanie offers it after The First Night; Mr. Palmer says no; Bramble, Pip and Dash are asked;
#   the two clues at the old slide; Mr. Goldwhistle turns up only on his step; the Haunted House door lets the spirit
#   out; Melanie's plan; Mr. Palmer's yes unlocks the Cloud Water Slide
# - Emergency Prep: Leo turns up after that; the four kit things; he moves to his bunker; stocking it sets off the
#   false alarm; calming him finishes it
# - Doggie Bill of Rights: Rex offers it; the chosen rule; five signatures (Rook's a paw); Mr. Palmer; the sign
# - Turtle Independence: starts the visit after, with the shell on; the Wizard Lizard; three shells; the turtles
#   choose; letting the shell go puts back what was on their back, and the shell's theirs to keep
# - Aftershock: one Earth evening, a tremor and the glowing pond; the other Nina climbs out; her three tricks; the real
#   Nina; she goes back through the pond
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_episodes.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.episodes_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var settings: Node
var episodes: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	settings = root.get_node("Settings")
	episodes = root.get_node("Watches").get_node_or_null("Episodes")
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	settings.tips = false
	dialogue.reset()
	quests.reset()
	game.needs_creator = false
	game._resume = {}
	game.riding = false
	game.items.clear()
	game.outfits = {"hero": {}}
	clock.pulls_home = false
	check(episodes != null, "the episode quests live under Watches, as \"Episodes\"")
	for q in ["slide_mystery", "emergency_prep", "dog_rights", "turtle_independence", "aftershock"]:
		check(not quests.quest(q).is_empty(), "the quest %s is loaded" % q)

	# Earth's townsfolk are still Earth kids (Townsfolk can make other bodies now)
	await _go(EARTH)
	var ivy := _talker("ivy")
	check(ivy != null and str(ivy.get_parent().get("model_path")).ends_with("earth_kid.glb"), "Earth's townsfolk are still Earth kids")

	# ------------------------------------------------------------------ We Need a Slide!
	await _to_town(10 * 60.0)
	check(_talker("melanie") == null, "no Melanie before The First Night")
	dialogue.set_flag("first_night_start")
	quests.check()
	for i in 30:
		if quests.is_done("first_night"):
			break
		quests.skip("first_night")
	await _settle()
	var melanie := _talker("melanie")
	check(melanie != null, "Melanie's by the Town Hall after The First Night")
	if melanie:
		var p := melanie.get_parent() as Node3D
		check(Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(-72, 27.5)) < 10.0, "...near Mr. Palmer's window")
		check(absf(p.global_position.y - _ground_y(p.global_position)) < 0.6, "...standing on the ground")
		check(str(p.get("model_path")).ends_with("cat.glb"), "...and she's a creature, like kids are in Galaxity (the cat body)")
	await _talk_to(melanie, [0])
	check(_step("slide_mystery") == "ask", "Melanie asks for help: the slide quest starts")
	await _talk_to(_talker("mr_palmer"))
	check(_step("slide_mystery") == "why", "Mr. Palmer says no (patience)")
	for who in ["bramble", "pip", "dash"]:
		await _talk_to(_talker(who))
		check(dialogue.flags.has("slide_ask_" + who), "%s is asked about the old slide" % who.capitalize())
	check(_step("slide_mystery") == "look", "on to the clues")
	var sign := current_scene.find_child("Episode Spot slide_clue_sign", true, false)
	var goo := current_scene.find_child("Episode Spot slide_clue_goo", true, false)
	check(sign != null and sign.call("is_open") and goo != null and goo.call("is_open"), "the two clues are open by the old slide")
	if sign and goo:
		check(Vector2(sign.global_position.x, sign.global_position.z).distance_to(Vector2(-96, -120)) < 6.0, "...the notice is by the old slide")
		sign.call("use")
		goo.call("use")
	await _settle()
	check(_step("slide_mystery") == "rich", "both clues found")
	var gold := _talker("goldwhistle")
	check(gold != null, "Mr. Goldwhistle turns up on his step")
	await _talk_to(gold)
	check(_step("slide_mystery") == "door", "he says to try the Haunted House door")
	var door := current_scene.find_child("Episode Spot slide_spirit", true, false)
	check(door != null and door.call("is_open"), "the door can be tried")
	if door:
		door.call("use")
	await _settle()
	check(current_scene.find_child("Escaped Spirit", true, false) != null, "something giggly escapes")
	check(_talker("goldwhistle") == null, "...and Mr. Goldwhistle's gone")
	await _talk_to(_talker("melanie"))
	check(_step("slide_mystery") == "palmer", "Melanie's new plan: the floating cloud slide")
	await _talk_to(_talker("mr_palmer"))
	check(quests.is_done("slide_mystery"), "Mr. Palmer says yes")
	check(game.has_item("cloud_slide"), "...which unlocks the Cloud Water Slide")
	await _to_town(10 * 60.0)
	check(current_scene.find_child("Cloud Water Slide", true, false) != null, "the Cloud Water Slide is there on the next visit")

	# ------------------------------------------------------------------ Emergency Prep
	await _settle()
	var leo := _talker("leo")
	check(leo != null, "Leo turns up once the slide's done")
	await _talk_to(leo, [0])
	check(_step("emergency_prep") == "kit", "Leo asks for an emergency kit")
	for f in ["prep_water", "prep_torch", "prep_blanket", "prep_snacks"]:
		var s := current_scene.find_child("Episode Spot " + f, true, false)
		check(s != null and s.call("is_open") and s.get_node_or_null("Before") != null and (s.get_node("Before") as Node3D).visible,
			"%s is out to pick up" % f)
		if s:
			s.call("use")
	await _settle()
	check(messages.any(func(m: String) -> bool: return m.contains("whole kit")), "the last one says the kit's done")
	check(_step("emergency_prep") == "bunker", "on to the bunker")
	check(current_scene.find_child("Leo's Bunker", true, false) != null, "Leo's bunker is in the meadow")
	leo = _talker("leo")
	var lp := (leo.get_parent() as Node3D).global_position if leo else Vector3.ZERO
	check(Vector2(lp.x, lp.z).distance_to(Vector2(11, 35)) < 8.0, "Leo waits at his bunker")
	var stock := current_scene.find_child("Episode Spot prep_stored", true, false)
	if stock:
		stock.call("use")
	await _settle()
	check(_step("emergency_prep") == "alarm" and messages.any(func(m: String) -> bool: return m.contains("AWOOO")),
		"stocking it, a wail: the false alarm")
	await _talk_to(_talker("leo"), [1])
	check(quests.is_done("emergency_prep"), "calming Leo down finishes Emergency Prep")
	check(quests.display_name("leo", "Leo") == "Ready Leo", "he's Ready Leo now")

	# ------------------------------------------------------------------ Doggie Bill of Rights
	var rex := _talker("rex")
	await _talk_to(rex, [0])
	check(_step("dog_rights") == "write", "Rex starts the Doggie Bill of Rights")
	await _talk_to(rex, [1])
	check(dialogue.flags.has("dogs_right_bath") and _step("dog_rights") == "sign", "the rule picked (the bubble bath), on to signatures")
	for who in ["dash", "bramble", "pip", "nina", "rook"]:
		var t := _talker(who)
		check(t != null, "%s is in town to sign" % who.capitalize())
		await _talk_to(t)
		check(dialogue.flags.has("dogs_sign_" + who), "%s signs" % who.capitalize())
	check(_step("dog_rights") == "hall", "five names: on to Mr. Palmer")
	await _talk_to(_talker("mr_palmer"))
	check(quests.is_done("dog_rights"), "Mr. Palmer agrees")
	await _settle()
	check(current_scene.find_child("Dogs Welcome", true, false) != null, "the DOGS WELCOME sign and doggy fountain go up")
	check(quests.display_name("rook", "Rook") == "Rook, Good Citizen", "Rook's a Good Citizen")

	# ------------------------------------------------------------------ Turtle Independence
	game.outfit["back"] = "super_cape"
	await _to_town(9 * 60.0)
	check(not quests.is_started("turtle_independence"), "Turtle Independence waits for the next visit")
	await _to_town(9 * 60.0)
	check(_step("turtle_independence") == "wake", "the visit after, it starts")
	check(str(game.outfit.get("back", "")) == "turtle_shell", "with a turtle shell on their back")
	await _settle()
	var lizard := _talker("wizard_lizard")
	check(lizard != null, "the Wizard Lizard is in the Secret Gardens")
	await _talk_to(lizard)
	check(_step("turtle_independence") == "shells", "he explains, and asks for three shells")
	for f in ["turtle_cup", "turtle_bucket", "turtle_pot"]:
		var s := current_scene.find_child("Episode Spot " + f, true, false)
		check(s != null and s.call("is_open"), "%s is out" % f)
		if s:
			s.call("use")
	await _settle()
	check(_step("turtle_independence") == "give", "three shells found")
	var turtle := current_scene.find_child("Lake Turtle 1", true, false)
	check(turtle != null and not turtle.get_node("Chosen Shell").visible, "the little turtles are shell-less")
	var give := current_scene.find_child("Episode Spot turtle_given", true, false)
	if give:
		give.call("use")
	await _settle()
	check(turtle != null and turtle.get_node("Chosen Shell").visible, "they choose their shells")
	await _talk_to(_talker("wizard_lizard"), [1])
	check(quests.is_done("turtle_independence"), "back to the Wizard Lizard: done")
	check(str(game.outfit.get("back", "")) == "super_cape", "letting the shell go puts their cape back on")
	check(game.has_item("shop:turtle_shell"), "...and the Turtle Shell's theirs to wear")

	# ------------------------------------------------------------------ Aftershock
	clock.set_earth_time(18 * 60.0, true)
	await _go(EARTH)
	await _frames(20)
	check(not quests.is_started("aftershock"), "no aftershock before the evening")
	clock.set_earth_time(20 * 60.0, true)
	await _settle()
	check(_step("aftershock") == "pond", "one Earth evening: an aftershock")
	var glow := current_scene.find_child("Pond Glow", true, false) as Node3D
	check(glow != null and glow.visible, "Willow Pond glows")
	var pond := current_scene.find_child("Episode Spot aftershock_pond", true, false)
	if pond:
		pond.call("use")
	await _settle()
	var other := _talker("other_nina")
	check(other != null, "someone climbs out of the pond")
	if other:
		check(str(other.get_parent().get("model_path")).ends_with("earth_kid.glb"), "...an Earth kid")
		check(other.get_parent().find_child("Own striped_beanie", true, false) != null, "...in a striped beanie")
	await _talk_to(other)
	check(_step("aftershock") == "tricks", "it's another Nina, and tricks start")
	for f in ["aftershock_lights", "aftershock_pies", "aftershock_sign"]:
		var s := current_scene.find_child("Episode Spot " + f, true, false)
		check(s != null and s.call("is_open"), "%s can be put right" % f)
		if s:
			s.call("use")
	await _settle()
	check(_step("aftershock") == "nina", "on to the real Nina")
	await _talk_to(_talker("nina_earth"))
	check(_step("aftershock") == "face", "Nina's told")
	await _talk_to(_talker("other_nina"), [0])
	check(quests.is_done("aftershock"), "the other Nina goes back through the pond")
	await _settle()
	check(_talker("other_nina") == null, "...and she's gone")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_put_save_back()
	quit(failures)


func _to_town(galaxity_minutes: float) -> void:
	# Each visit to Galaxity is in the Shift; Earth goes to the town scene to "arrive"
	clock.set_earth_time(0.25 * 60.0, true)
	await _go(EARTH)
	await _go(TOWN)
	clock.set_time(clock.day, galaxity_minutes, true)
	await _settle()


func _ground_y(p: Vector3) -> float:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -30, 0))
	var got := space.intersect_ray(q)
	return got.position.y if not got.is_empty() else -100.0


func _step(quest_id: String) -> String:
	return str(quests.current_step(quest_id).get("id", ""))


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 40:
		await process_frame
		if current_scene and current_scene.scene_file_path == scene:
			break
	await _frames(6)


func _talker(id: String) -> Area3D:
	if current_scene == null:
		return null
	for t in current_scene.find_children("*", "Area3D", true, false):
		if t.get("character_id") == id and not t.is_queued_for_deletion() and not t.get_parent().is_queued_for_deletion():
			return t
	return null


func _talk_to(t: Node3D, picks: Array = []) -> void:
	if t == null:
		check(false, "(someone to talk to wasn't there)")
		return
	var player := _player()
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
			buttons[pick].pressed.emit()
		else:
			dialogue._finish_typing()
			dialogue._next()
		await _frames(1)
	await _frames(2)
	quests.check()
	await _frames(2)


func _settle() -> void:
	# Long enough for scripts/episodes.gd's next look round (it checks every 0.3 s, not every frame)
	await create_timer(0.45).timeout
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
