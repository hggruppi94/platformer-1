extends SceneTree

# Checks Remnants and the garden (scripts/remnants.gd, scripts/farm.gd): the veins, tool parts and garden are put into
# the town on the ground; the quest "Bramble's Harvest" plays through (parts, the tool, a first vein, Bramble's garden
# tour, planting, watering, the first harvest, the watering can); veins give Remnants once a Void day and regrow;
# Bramble burrows over to help; plants only grow while watered, wait (and never die) when dry, ripen and harvest;
# seeds, Remnant seeds, selling and snacks work in the shop; the request board can ask for a harvest; the HUD and Bag
# show it; and it all saves, loads, and an old save without any of it starts empty.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_farming.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.farming_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.farming_test_backup.cfg"

var failures := 0
var game: Node
var farm: Node
var rem: Node
var dialogue: Node
var quests: Node
var clock: Node
var shop: Node


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
	farm = root.get_node("Farm")
	rem = root.get_node("Remnants")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	shop = root.get_node("Shop")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)

	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(10)
	await _physics(4)
	await _check_placed()
	await _check_quest_and_veins()
	await _check_growing()
	_check_shop()
	_check_requests()
	_check_ui()
	_check_saving()
	_finish()


func _check_placed() -> void:
	var s := current_scene as Node3D
	var holder := s.get_node_or_null("Remnants") as Node3D
	check(holder != null, "the Remnants things are put into the town")
	var garden := s.get_node_or_null("Garden") as Node3D
	check(garden != null, "the garden is put into the town")
	if holder == null or garden == null:
		return
	var space := s.get_world_3d().direct_space_state
	for v in rem.VEINS:
		var g := holder.get_node_or_null("Vein " + str(v.id)) as Node3D
		check(g != null, "vein %s is there" % v.id)
		if g == null:
			continue
		check(absf(g.global_position.x - v.at.x) < 0.01 and absf(g.global_position.z - v.at.y) < 0.01, "vein %s is where it should be" % v.id)
		check(g.global_position.y > -0.3, "vein %s is on dry ground (y %.2f)" % [v.id, g.global_position.y])
		check(g.get_node_or_null("Spot") != null and g.get_node("Spot").has_method("use"), "vein %s can be used" % v.id)
	for p in rem.PARTS:
		check(holder.get_node_or_null("Part " + str(p.id)) != null, "tool part %s is there" % p.id)
	# The garden: on flat dry ground, clear of the house and the hedge
	check(garden.global_position.y > -0.5 and garden.global_position.y < 0.5, "the garden is on the ground (y %.2f)" % garden.global_position.y)
	var house := Vector2(66, 16)
	check(Vector2(garden.global_position.x, garden.global_position.z).distance_to(house) > 4.5 + 3.0, "the garden is clear of My House")
	var hedge := Vector2(80, 0)
	for corner in [Vector2(-3.4, -2.3), Vector2(3.4, -2.3), Vector2(-3.4, 2.3), Vector2(3.4, 2.3)]:
		var c: Vector2 = Vector2(garden.global_position.x, garden.global_position.z) + corner
		check(c.distance_to(hedge) < 34.0 - 1.6, "the garden's corner %s is inside the Homes hedge" % corner)
	var blocked := 0
	for i in farm.BEDS:
		var at: Vector3 = garden.to_global(farm.bed_local(i))
		var shape := SphereShape3D.new()
		shape.radius = 0.6
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), at + Vector3(0, 0.9, 0))
		blocked += space.intersect_shape(q, 4).size()
		check(garden.get_node_or_null("Bed %d/Spot" % i) != null and garden.get_node("Bed %d/Spot" % i).has_method("use"), "bed %d can be used" % i)
	check(blocked == 0, "nothing solid stands in the beds (%d)" % blocked)


func _check_quest_and_veins() -> void:
	var holder := current_scene.get_node("Remnants") as Node3D
	# Before the tool: a vein only says it's too deep
	check(not rem.has_tool(), "no harvesting tool to start with")
	check(rem._vein_offer("lake_shore") == "look at the glowing crystals", "a vein offers a look before the tool")
	check(not rem.harvest("lake_shore") and rem.count == 0, "no Remnants without the tool")
	check(not rem.shown(), "the HUD doesn't show Remnants before the quest")
	check(farm._offer(0) == "", "the garden beds offer nothing before Bramble's tour")
	# Bramble's offer starts it
	dialogue.set_flag("harvest_start")
	quests.check()
	check(quests.is_started("brambles_harvest") and quests.on_step("brambles_harvest", "parts"), "Bramble's Harvest starts on the parts step")
	check(rem.shown(), "the HUD shows Remnants once the quest starts")
	await _frames(2)
	for p in rem.PARTS:
		var node := holder.get_node("Part " + str(p.id)) as Node3D
		check((node.get_node("Look") as Node3D).visible, "part %s shows while it's wanted" % p.id)
		node.get_node("Spot").use()
	await _frames(2)
	check(rem.parts_found() == 3, "all three parts picked up")
	quests.check()
	check(quests.on_step("brambles_harvest", "build"), "then: take the parts to Bramble")
	check(not (holder.get_node("Part handle/Look") as Node3D).visible, "picked-up parts are gone")
	# Bramble's conversation on that step builds the tool (its file is checked for the right conversation too)
	var convo := _bramble_convo("brambles_harvest:build")
	check(not convo.is_empty() and str(convo.get("set", "")) == "harvest_tool_built", "Bramble's build conversation sets the tool flag")
	dialogue.set_flag("harvest_look_star")
	dialogue.set_flag("harvest_tool_built")
	quests.check()
	check(rem.has_tool() and rem.tool_name() == "Star Scoop", "the tool is made, with the look the player picked")
	check(quests.on_step("brambles_harvest", "vein"), "then: harvest a vein")
	# A vein with Bramble's help: she burrows over, sprouts up, and the Remnants pop out
	check(rem._vein_offer("lake_shore") == "harvest Remnants", "a vein offers a harvest with the tool")
	holder.get_node("Vein lake_shore/Spot").use()
	await _frames(5)
	check(holder.get_node_or_null("Bramble Helps") != null, "Bramble burrows over to help")
	await create_timer(4.5).timeout
	check(rem.count == rem.PER_VEIN, "the vein gave %d Remnants (%d)" % [rem.PER_VEIN, rem.count])
	check(holder.get_node_or_null("Bramble Helps") == null, "Bramble burrows off again")
	check(not (holder.get_node("Vein lake_shore/Crystals") as Node3D).visible and (holder.get_node("Vein lake_shore/Stubs") as Node3D).visible, "a harvested vein shows only stubs")
	check(not rem.harvest("lake_shore") and rem.count == rem.PER_VEIN, "once a Void day: no more from it today")
	check(rem.harvest("castle_rock") and rem.count == rem.PER_VEIN * 2, "another vein still gives")
	clock.set_time(4, 9 * 60.0, true)
	check(rem.is_ready("lake_shore"), "veins regrow the next Void day")
	rem._refresh_veins()
	check((holder.get_node("Vein lake_shore/Crystals") as Node3D).visible, "...and look full again")
	quests.check()
	check(quests.on_step("brambles_harvest", "garden"), "then: meet Bramble at the garden")
	var ov: Dictionary = quests.override_for("bramble")
	check(str(ov.get("place", "")) == "my_garden", "Bramble waits at the garden on that step")
	# Her tour: two beds dug and a bag of seeds
	var tour := _bramble_convo("brambles_harvest:garden")
	check(str(tour.get("do", "")) == "Farm.tour" and str(tour.get("set", "")) == "garden_tour", "Bramble's garden conversation runs the tour")
	var said: Array = farm.tour()
	dialogue.set_flag("garden_tour")
	check(said.size() > 2, "Bramble explains the garden")
	check(farm.beds[0].tilled and farm.beds[1].tilled and not farm.beds[2].tilled, "Bramble digs the first two beds")
	check(int(farm.seeds.get("blinkberry", 0)) == 3 and int(farm.seeds.get("peekaroot", 0)) == 1, "...and gives three Blinkberry seeds and a Peekaroot seed")
	check(farm.tour().is_empty(), "the tour only happens once")
	quests.check()
	check(quests.on_step("brambles_harvest", "plant"), "then: plant and water")


func _bramble_convo(step: String) -> Dictionary:
	var data: Dictionary = dialogue.load_character("bramble")
	for c in data.get("conversations", []):
		if str(c.get("when", {}).get("quest_step", "")) == step:
			return c
	return {}


func _check_growing() -> void:
	await _frames(1)
	# Digging a bed of your own
	check(farm._offer(2) == "dig this bed", "an undug bed offers digging with the tool")
	farm._use(2)
	check(farm.beds[2].tilled, "digging it makes it ready")
	check(farm._offer(0) == "plant a seed", "a dug bed offers planting")
	# Planting with two kinds of seed asks which; with the choice made it's planted
	farm._use(0)
	check(dialogue.is_active(), "two kinds of seed: a little question asks which")
	dialogue._next()                                 # past "(Which seed shall it be?)" to the answers
	var answers: Array = dialogue.current_choices()
	check(answers.size() == 3, "...with an answer for each seed and \"Not now\" (%d)" % answers.size())
	if not answers.is_empty():
		(answers[0] as Button).pressed.emit()        # Blinkberry
	if dialogue.is_active():
		dialogue.end()
	check(str(farm.beds[0].crop) == "blinkberry" and int(farm.seeds.blinkberry) == 2, "a Blinkberry seed is planted")
	check(farm.thirsty(0) and farm._offer(0) == "water it", "a new seed wants water")
	var t0: float = farm.now()
	_later(120.0)
	farm.update()
	check(float(farm.beds[0].grown) == 0.0, "it doesn't grow without water")
	check(farm.water(0) == 1, "watering by hand waters one bed")
	check(not farm.thirsty(0), "...and it's happy")
	quests.check()
	check(quests.on_step("brambles_harvest", "grow"), "planting and watering moves the quest on")
	_later(120.0)
	farm.update()
	check(absf(float(farm.beds[0].grown) - 120.0) < 1.0, "it grows while it has water (%.0f min)" % float(farm.beds[0].grown))
	check(farm.stage(0) >= 2 and not farm.ripe(0), "a sprout, not ripe yet (stage %d)" % farm.stage(0))
	# A Peekaroot that runs dry waits, and never dies
	farm.plant(1, "peekaroot")
	farm.water(1)
	_later(600.0)
	farm.update()
	check(farm.ripe(0), "the Blinkberry ripens")
	check(absf(float(farm.beds[1].grown) - farm.WATER_LASTS) < 1.0, "the Peekaroot only grew while watered (%.0f)" % float(farm.beds[1].grown))
	check(farm.thirsty(1) and not farm.ripe(1), "...then waits, thirsty")
	clock.set_time(clock.day + 3, clock.minutes, true)
	farm.update()
	check(str(farm.beds[1].crop) == "peekaroot" and farm.thirsty(1), "days later it's still there, waiting (plants never die)")
	await _frames(2)
	var garden := current_scene.get_node("Garden") as Node3D
	farm._refresh()
	check(garden.get_node_or_null("Bed 1/Look") != null and garden.get_node("Bed 1/Look").find_child("Drop", true, false) != null, "a thirsty plant shows a water drop")
	check(garden.get_node("Bed 0/Look").find_child("Eyes", true, false) != null, "the ripe Blinkberry has eyes")
	check(farm._offer(0) == "pick the Blinkberry", "a ripe one offers picking")
	# Picking
	check(farm.harvest(0) == 3 and int(farm.crops.blinkberry) == 3, "picking gives 3 Blinkberries")
	check(str(farm.beds[0].crop) == "" and farm.beds[0].tilled, "the bed's ready for the next seed")
	quests.check()
	check(quests.is_done("brambles_harvest"), "the first harvest finishes Bramble's Harvest")
	check(game.has_item("watering_can"), "...and the reward is the watering can")
	# The can waters everything at once
	farm.plant(0, "blinkberry")
	check(farm._offer(0) == "water the garden", "with the can it offers watering the whole garden")
	check(farm.water(0) == 2, "the can waters every thirsty bed (%d)" % 2)
	_later(300.0)
	farm.update()
	check(farm.ripe(1), "the watered Peekaroot catches up and ripens")
	check(farm.harvest(1) == 2 and int(farm.crops.peekaroot) == 2, "picking gives 2 Peekaroots")
	# A Remnant sprout grows a crystal
	farm.give_seeds("remnant_sprout", 1)
	farm.plant(2, "remnant_sprout")
	var before: int = rem.count
	for k in 4:
		farm.water(2)
		_later(360.0)
		farm.update()
	check(farm.ripe(2), "the Remnant sprout ripens after a whole Void day of watering")
	farm.harvest(2)
	check(rem.count == before + 2, "...and gives 2 Remnants (%d -> %d)" % [before, rem.count])
	check(farm.harvested >= 5, "harvests are counted (%d)" % farm.harvested)
	# Clock going backwards (a test, an old save) doesn't break anything
	farm.plant(2, "blinkberry") if int(farm.seeds.get("blinkberry", 0)) > 0 else null
	clock.set_time(1, 8 * 60.0, true)
	farm.update()
	check(float(farm.beds[2].grown) >= 0.0, "the clock going back doesn't grow or shrink plants")
	clock.set_time(4, 9 * 60.0, true)
	farm.update()


func _check_shop() -> void:
	game.sparkles = 10
	var seeds_before := int(farm.seeds.get("gogglegourd", 0))
	check(shop.can_buy("seed_gogglegourd") == "", "Goggle Gourd seeds can be bought")
	check(shop.buy("seed_gogglegourd"), "buying a seed")
	check(int(farm.seeds.gogglegourd) == seeds_before + 1 and game.sparkles == 4, "a seed in the bag, 6 sparkles paid")
	check(shop.for_stall("Flowers").any(func(it: Dictionary) -> bool: return it.id == "seed_blinkberry"), "the Flowers stall sells seeds")
	var r_before: int = rem.count
	check(shop.buy("seed_remnant_sprout"), "buying a Remnant sprout seed")
	check(rem.count == r_before - 1 and game.sparkles == 4, "it costs a Remnant, not sparkles")
	rem.count = 0
	check(shop.can_buy("seed_remnant_sprout") == "Not enough Remnants yet", "no Remnants, no Remnant seed")
	rem.count = r_before
	var crops_before := int(farm.crops.get("blinkberry", 0))
	check(shop.buy("sell_blinkberry"), "selling a Blinkberry")
	check(int(farm.crops.blinkberry) == crops_before - 1 and game.sparkles == 6, "one fewer Blinkberry, 2 sparkles paid to you")
	farm.crops.erase("gogglegourd")
	check(shop.can_buy("sell_gogglegourd") == "None to sell", "nothing to sell, no selling")
	game.hp = 1
	var pf := int(farm.crops.get("peekaroot", 0))
	check(shop.buy("snack_peekaroot_fries"), "making Peekaroot Fries")
	check(int(farm.crops.get("peekaroot", 0)) == pf - 2 and game.hp == 11 or game.hp == game.max_hp, "the fries use 2 Peekaroots and heal")
	check(shop.can_buy("snack_peekaroot_fries").begins_with("Needs"), "no more Peekaroots, no more fries")


func _check_requests() -> void:
	var req := root.get_node("Requests")
	check(req.has_garden(), "the request board knows there's a garden")
	check("harvest" in req.kinds_for("easy"), "it can ask for a harvest")
	var r: Dictionary = req._make("harvest", "easy", RandomNumberGenerator.new())
	check(req.text_of(r) == "Pick 2 crops in your garden", "the harvest request reads well (%s)" % req.text_of(r))
	var earth := root.get_node("EarthJobs")
	check(not earth.kinds().has("harvest"), "Earth's notice board doesn't ask for it")


func _check_ui() -> void:
	var hud := current_scene.find_child("HUD", true, false)
	var label := hud.get("remnant_label") as Label if hud else null
	check(label != null and label.visible and label.text.begins_with("◆"), "the HUD shows Remnants (%s)" % (label.text if label else "none"))
	check(farm.bag_text().contains("Seeds:") and farm.bag_text().contains("Crops:"), "the Bag lists seeds and crops")


func _check_saving() -> void:
	var beds_before: Array = farm.beds.duplicate(true)
	var seeds_before: Dictionary = farm.seeds.duplicate()
	var r_before: int = rem.count
	var taken_before: Dictionary = rem.veins_taken.duplicate()
	game.save_game()
	farm.reset()
	rem.reset()
	check(farm.seeds.is_empty() and rem.count == 0, "(cleared before loading)")
	game.load_game()
	check(rem.count == r_before and rem.veins_taken == taken_before, "Remnants and harvested veins load back")
	var same := true
	for i in farm.BEDS:
		for k in ["tilled", "crop"]:
			if farm.beds[i][k] != beds_before[i][k]:
				same = false
	check(same and farm.seeds == seeds_before, "the garden beds and seeds load back")
	# An old save from before all this
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("farm")
	data.erase("remnants")
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(rem.count == 0 and farm.seeds.is_empty() and not farm.beds[0].tilled, "an old save starts with no Remnants and no garden")


func _later(m: float) -> void:
	# Move the Void's clock on by this many minutes, past midnight into the next day if need be
	var t: float = clock.day * 1440.0 + clock.minutes + m
	clock.set_time(int(t / 1440.0), fmod(t, 1440.0), true)


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
