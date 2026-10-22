extends SceneTree

# Checks sparkles (the money) and the market stalls: picking sparkles up (and them coming back the next day),
# earning them from happy places and quests, the HUD counter, shopping (snacks, hats, sash stickers) and wearing
# what she buys. Run it twice: the second run starts up like the real game and checks it all came back.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_shop.gd
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_shop.gd -- --check-load
#
# Your own save is put aside first (user://save.test_backup.json) and put back by the --check-load run.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var quests: Node
var shop: Node
var player: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(220.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	shop = root.get_node("Shop")
	if "--check-load" in OS.get_cmdline_user_args():
		_check_load.call_deferred()
	else:
		_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	dialogue.reset()
	quests.reset()
	game.items.clear()
	game.hat = ""
	game.sparkles = 0
	game.sparkles_taken.clear()

	# The catalogue
	var stalls := ["Fruit", "Sweets", "Crystals", "Flowers", "Records", "Toys"]
	check(stalls.all(func(s: String) -> bool: return shop.for_stall(s).size() >= 2), "every stall sells something (%d items)" % shop.items.size())
	var hats: Array = shop.items.values().filter(func(i: Dictionary) -> bool: return i.kind == "hat")
	var stickers: Array = shop.items.values().filter(func(i: Dictionary) -> bool: return i.kind == "sticker")
	check(hats.size() >= 2 and hats.all(func(i: Dictionary) -> bool: return Cosmetics.hat(i.id) != null), "%d hats, each with a look" % hats.size())
	check(stickers.all(func(i: Dictionary) -> bool: return Cosmetics.sticker(i.id) != null and Cosmetics.STICKER_ANGLES.has(i.id)),
		"%d stickers, each with a look and a spot on the sash" % stickers.size())
	check(shop.items.values().all(func(i: Dictionary) -> bool: return int(i.price) > 0 and int(i.price) <= 20), "prices are small (1-20 sparkles)")

	change_scene_to_file(TOWN)
	await _frames(6)
	player = current_scene.find_child("Player", true, false)
	var sparkles := current_scene.find_children("Sparkle *", "Area3D", true, false)
	var spots := current_scene.find_children("Shop", "Area3D", true, false)
	check(sparkles.size() >= 30, "sparkles scattered round town (%d)" % sparkles.size())
	check(spots.size() == 6, "a shop spot at each market stall")
	var hud := player.get_node("HUD")
	check(hud.sparkle_label.text.begins_with("✦ 0"), "HUD counter: \"%s\"" % hud.sparkle_label.text)

	# Picking one up, and it coming back tomorrow
	var sp := current_scene.find_child("Sparkle 12", true, false) as Area3D       # one out in the open
	player.global_position = sp.global_position + Vector3(0, 0.6, 0)
	await _physics(6)
	await _frames(2)
	check(game.sparkles == 1 and not sp.visible, "walked into a sparkle: +1, it's gone")
	check(hud.sparkle_label.text.begins_with("✦ 1 sparkle"), "HUD counter: \"%s\"" % hud.sparkle_label.text)
	player.global_position = Vector3(-72, 2, 60)
	await _physics(3)
	clock.set_time(clock.day + 1, 8 * 60.0, true)
	await _frames(2)
	check(sp.visible and not game.sparkle_taken(sp.name), "...back the next day")

	# Happy places and quests pay sparkles
	var happy := current_scene.find_children("*", "Area3D", true, false).filter(
		func(a: Node) -> bool: return a.get_script() == load("res://scripts/happy_place.gd"))
	var before: int = game.sparkles
	happy[0].call("_on_body_entered", player)
	check(game.sparkles == before + game.HAPPY_PLACE_SPARKLES, "first visit to a happy place: +%d" % game.HAPPY_PLACE_SPARKLES)
	happy[0].set("_cooldown", 0.0)
	happy[0].call("_on_body_entered", player)
	check(game.sparkles == before + game.HAPPY_PLACE_SPARKLES, "...only the first time")
	before = game.sparkles
	quests.load_data({"rex_campaign": {"step": 5, "since_day": 1}})
	dialogue.set_flag("campaign_done")
	check(quests.is_done("rex_campaign") and game.sparkles == before + 15, "finishing Rex's campaign: +15 (%d)" % (game.sparkles - before))
	game.items.erase("campaign_sash")
	game.equipment_changed.emit()
	var found: int = game.items.filter(func(i: String) -> bool: return i.begins_with("happy_place:")).size()
	check(game._sparkles_already_earned() == 15 + game.HAPPY_PLACE_SPARKLES * found, "an old save gets paid for quests and happy places already done")

	# Shopping at the Fruit stall: walk up, Interact
	var fruit: Area3D = spots.filter(func(s: Node) -> bool: return s.get("stall") == "Fruit")[0]
	player.global_position = fruit.global_position + (fruit.global_basis.z * 0.8) + Vector3(0, 0.8, 0)
	await _physics(6)
	await _frames(2)
	check(dialogue._nearest == fruit and fruit._prompt.text == "Press F to shop", "at the Fruit stall: \"%s\"" % fruit._prompt.text)
	_press("interact")
	await _frames(3)
	check(shop.is_open() and paused and shop._title.text == "Fruit Stall", "Interact opens the Fruit Stall (game paused)")
	game.sparkles = 0
	shop._fill()
	await _frames(2)
	var apple_button := _button("star_apple")
	check(apple_button.disabled and apple_button.text == "Not enough sparkles yet", "no sparkles: \"%s\"" % apple_button.text)
	game.sparkles = 40
	game.hp = 3
	shop._fill()
	await _frames(2)
	_button("star_apple").pressed.emit()
	await _frames(2)
	check(game.hp == 8 and game.sparkles == 38, "ate a Star Apple: HP 3 -> %d, 40 -> %d sparkles" % [game.hp, game.sparkles])
	check(shop._note.text.begins_with("Yum!"), "\"%s\"" % shop._note.text)
	_press("ui_cancel")
	await _frames(3)
	check(not shop.is_open() and not paused, "Back closes the shop")

	# A hat: bought, worn, taken off, put back on
	shop.open("Toys")
	await _frames(2)
	_button("propeller_cap").pressed.emit()
	await _frames(2)
	check(game.has_item("shop:propeller_cap") and game.hat == "propeller_cap", "bought the Propeller Cap and put it on")
	check(player.find_child("Hat", true, false) != null and player.find_child("Propeller", true, false) != null, "Nina wears it (propeller and all)")
	check(_button("propeller_cap").text == "Take off", "the button now says Take off")
	_button("propeller_cap").pressed.emit()
	await _frames(2)
	check(game.hat == "" and player.find_child("Hat", true, false) == null, "took it off")
	_button("propeller_cap").pressed.emit()
	await _frames(2)
	check(game.hat == "propeller_cap" and game.sparkles == 26, "wore it again (no paying twice: %d left)" % game.sparkles)
	shop.close()

	# Stickers need the sash
	shop.open("Toys")
	await _frames(2)
	check(_button("paw_sticker").disabled and _button("paw_sticker").text == "Needs Rex's VOTE REX sash", "sticker without the sash: \"%s\"" % _button("paw_sticker").text)
	shop.close()
	game.give_item("campaign_sash")
	game.equipment_changed.emit()
	shop.open("Toys")
	await _frames(2)
	_button("paw_sticker").pressed.emit()
	await _frames(2)
	var on_sash := player.find_child("Stickers", true, false)
	check(game.has_item("shop:paw_sticker") and on_sash and on_sash.get_child_count() == 1, "a paw print on the sash")
	check(_button("paw_sticker").disabled and _button("paw_sticker").text == "Got it!", "...and it can't be bought twice")
	shop.close()

	# Can't open a shop while talking or paused
	get_root_paused_check()
	game.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(data is Dictionary and int(data.get("sparkles", -1)) == game.sparkles and data.get("hat", "") == "propeller_cap",
		"save.json has sparkles (%s) and the hat" % data.get("sparkles", "?"))
	print("RESULT %s (%d failed). Now run with -- --check-load" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func get_root_paused_check() -> void:
	paused = true
	shop.open("Fruit")
	check(not shop.is_open(), "no shopping while the game's paused")
	paused = false


func _check_load() -> void:
	check(game.sparkles == 23 and game.hat == "propeller_cap", "loaded: %d sparkles, wearing the %s" % [game.sparkles, game.hat])
	check(game.has_item("shop:paw_sticker") and game.has_item("shop:propeller_cap"), "loaded: the cap and the sticker")
	game._resume = {}
	change_scene_to_file(TOWN)
	await _frames(6)
	var p := current_scene.find_child("Player", true, false)
	check(p.find_child("Propeller", true, false) != null and p.find_child("Stickers", true, false).get_child_count() == 1,
		"loaded: Nina's wearing the cap, and the sticker's on her sash")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _button(id: String) -> Button:
	return shop._rows.find_child("Button " + id, true, false) as Button


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


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
