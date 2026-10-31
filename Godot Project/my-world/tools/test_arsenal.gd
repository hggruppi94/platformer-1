extends SceneTree

# Checks the hero's gadgets (scripts/arsenal.gd) in the town: the Gadget wheel is on R and D-pad up and can be
# remapped; she starts with just the Star Popper; Dash's gadget stall stands in the Market Square and sells the Fizz
# Flinger and the Disco Ball for sparkles (through the Shop, as kinds "gadget" and "ammo") and refills them. The Fizz
# Flinger lobs a fizz bomb that pops every Gloop in its splash and uses ammo; empty, it won't fire. The Disco Ball
# floats up and sets nearby Gloops dancing on the spot (not chasing), then lets them go. Gadgets grow versions with
# pops (more ammo, bigger splashes, the Disco Fever pops its dancers, the Mega Popper blows two bubbles). The wheel
# opens on a hold, slows the game, picks by direction and closes on release; a tap swaps back. Ammo bubbles top a
# gadget up. It all saves and loads, and her hand holds the gadget that's out.
# Slice 2: Dash's workbench sells the four mods and three levels of upgrades; every mod works on every gadget (Freeze
# leaves a frosty puff that slows, Split makes two, Bounce bounces, the Sparkle Magnet pulls sparkles and ammo in);
# combos have names and Icy Shards throws shards; the Bag's Gadgets page swaps mods. Slice 3: the Plushinator, Buzz
# Bots, Rainbow Ray and Jelly Mines each work and have their Mega, the ammo crates stand on the ground round town and
# fill gadgets up, and the new sounds are made.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_arsenal.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.arsenal_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.arsenal_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var arsenal: Node
var shop: Node
var _had_save := false


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	arsenal = root.get_node("Arsenal")
	shop = root.get_node("Shop")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	arsenal.reset()

	# --- The controls ---
	var listed := func(list: Array) -> bool: return list.any(func(p: Array) -> bool: return p[0] == "gadget_wheel")
	check(listed.call(settings.REBINDABLE) and listed.call(settings.PAD_REBINDABLE), "Gadget wheel is in both control lists")
	check(settings.key_name("gadget_wheel") == "R" and settings.pad_name("gadget_wheel") == "D-pad up",
		"...on R and D-pad up (%s, %s)" % [settings.key_name("gadget_wheel"), settings.pad_name("gadget_wheel")])
	settings.rebind("gadget_wheel", KEY_G)
	check(settings.key_name("gadget_wheel") == "G", "...and can be moved")
	settings.use_layout("classic")

	# --- Starting out ---
	check(arsenal.owned == ["popper"] and arsenal.current == "popper", "she starts with just the Star Popper")
	check(arsenal.ammo_of("popper") < 0 and arsenal.has_ammo("popper"), "...which never runs out")
	var stall_items: Array = shop.for_stall("Gadget")
	check(stall_items.size() >= 4, "Dash's stall sells gadgets and refills (%d things)" % stall_items.size())

	change_scene_to_file(TOWN)
	await _frames(8)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var popper = p.get("popper")
	var stall := town.get_node_or_null("Gadget Stall") as Node3D
	check(stall != null, "the gadget stall is in the town")
	var square := town.find_child("Market Square", true, false) as Node3D
	if stall and square:
		var d := Vector2(stall.global_position.x - square.global_position.x, stall.global_position.z - square.global_position.z).length()
		check(d > 10.0 and d < 19.0, "...at the edge of the Market Square (%.1f m from the fountain)" % d)
		var spot := stall.find_child("Gadget Shop Spot", true, false)
		check(spot != null and spot.get("stall") == "Gadget", "...with a spot to shop at")
		var board := town.get_node_or_null("Request Board") as Node3D
		if board:
			check(board.global_position.distance_to(stall.global_position) > 5.0, "...not on top of the request board")
	check(popper.find_child("GadgetWheel", true, false) != null, "the wheel is on her HUD")

	# --- Buying ---
	# (Each gadget needs its schematic found first: tools/test_schematics.gd checks that. Here they're all found.)
	for e in root.get_node("Schematics").LIST:
		root.get_node("Dialogue").set_flag("schematic_" + str(e.id))
	game.sparkles = 5
	check(shop.can_buy("fizz_flinger") == "Not enough sparkles yet", "the Fizz Flinger costs sparkles")
	check(shop.can_buy("fizz_refill") != "", "...and there's nothing to refill yet (%s)" % shop.can_buy("fizz_refill"))
	game.sparkles = 40
	shop.open("Gadget")
	await _frames(2)
	var bought: bool = shop.buy("fizz_flinger")
	check(bought and arsenal.owns("fizz") and game.sparkles == 30, "buying the Fizz Flinger (40 -> %d sparkles)" % game.sparkles)
	check(arsenal.current == "fizz" and arsenal.ammo_of("fizz") == 8, "...it's out, full (%d)" % arsenal.ammo_of("fizz"))
	check(not game.has_item("shop:fizz_flinger"), "...kept by the Arsenal, not in her bag of things")
	check(shop.can_buy("fizz_flinger") == "You have this one" and shop.can_buy("fizz_refill") == "It's full",
		"...can't buy it twice, or fill a full one")
	shop.close()
	await _frames(2)
	check(str(popper._prop.get_meta("gadget", "")) == "fizz", "the Fizz Flinger is what's in her hand")

	# --- The Fizz Flinger ---
	var gloops: Array[Node] = town.find_children("Gloop *", "", true, false)
	check(gloops.size() >= 4, "there are Gloops (%d)" % gloops.size())
	var flat := _flat_spot(town, p)
	for g in gloops + town.find_children("Crocodillo *", "", true, false):
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)
	var g0 := gloops[0] as CharacterBody3D
	var g1 := gloops[1] as CharacterBody3D
	_stage(p, g0, flat, Vector3(0, 0, 8))
	_place(p, g1, g0.global_position + Vector3(1.2, 0, 0.6))
	g0.set("stomps_to_defeat", 1)
	g1.set("stomps_to_defeat", 1)
	await _physics(3)
	var bomb = popper.shoot(false)
	check(bomb != null and bomb.is_in_group("fizz_bombs"), "Shoot lobs a fizz bomb")
	check(arsenal.ammo_of("fizz") == 7, "...using one fizz (%d left)" % arsenal.ammo_of("fizz"))
	await _physics(80)
	check(g0.defeated and g1.defeated, "the splash pops both Gloops it lands by")
	check(int(arsenal.xp.get("fizz", 0)) == 2, "...a point for the Fizz Flinger each (%d)" % int(arsenal.xp.get("fizz", 0)))
	# Out of fizz
	arsenal.ammo["fizz"] = 0
	popper._cooldown = 0.0
	check(popper.shoot(false) == null and get_nodes_in_group("fizz_bombs").is_empty(), "empty, it won't throw")
	shop.open("Gadget")
	check(shop.can_buy("fizz_refill") == "" and shop.buy("fizz_refill") and arsenal.ammo_of("fizz") == arsenal.max_ammo("fizz"),
		"a refill at Dash's stall fills it up (%d)" % arsenal.ammo_of("fizz"))

	# --- The Disco Ball ---
	check(shop.buy("disco_ball") and arsenal.owns("disco") and arsenal.current == "disco", "buying the Disco Ball")
	shop.close()
	await _frames(2)
	var g2 := gloops[2] as CharacterBody3D
	var g3 := gloops[3] as CharacterBody3D
	_stage(p, g2, flat, Vector3(0, 0, 9))
	_place(p, g3, g2.global_position + Vector3(-2.0, 0, 1.0))
	for g in [g2, g3]:
		(g as Node3D).set_physics_process(true)
		g.set("stomps_to_defeat", 2)
	await _physics(3)
	popper._cooldown = 0.0
	var ball = popper.shoot(false)
	check(ball != null and ball.is_in_group("disco_balls"), "Shoot throws a disco ball")
	await _physics(60)
	check(ball and is_instance_valid(ball) and ball.dancers.has(g2) and ball.dancers.has(g3), "...the Gloops near it dance")
	var still := g2.global_position
	var rest: Vector3 = ball.dancers[g2].rot if ball and ball.dancers.has(g2) else Vector3.ZERO
	await _physics(30)
	check(not g2.is_physics_processing() and g2.global_position.distance_to(still) < 0.05,
		"...on the spot, not chasing her")
	check(g2.find_child("DanceNote", false, false) != null, "...with music notes over their heads")
	check(not g2.defeated, "...and nobody's popped")
	ball.time = 0.0
	await _physics(3)
	var turned := (g2.get_node("Visual") as Node3D).rotation
	check(not is_instance_valid(ball) and g2.is_physics_processing() and absf(turned.x - rest.x) + absf(turned.z - rest.z) < 0.01,
		"when the music stops they go back to normal")
	check(int(arsenal.xp.get("disco", 0)) == 2, "...a point for the Disco Ball for each dancer")

	# --- Versions ---
	arsenal.xp["fizz"] = 4
	arsenal.add_xp("fizz")
	check(arsenal.level("fizz") == 2 and arsenal.max_ammo("fizz") == 10 and arsenal.ammo_of("fizz") == 10,
		"five pops grow the Fizz Flinger to V2: more ammo, and it comes full")
	check(float(arsenal.stat("fizz", "radius")) > 2.6, "...with a bigger splash")
	arsenal.xp["disco"] = arsenal.LEVEL_XP[4]
	check(arsenal.level("disco") == 5 and arsenal.gadget_name("disco") == "Disco Fever", "V5 is the Disco Fever")
	_stage(p, g3, flat, Vector3(0, 0, 9))
	g3.set_physics_process(true)
	await _physics(3)
	popper._cooldown = 0.0
	ball = popper.shoot(false)
	await _physics(60)
	check(ball and is_instance_valid(ball) and ball.dancers.has(g3), "...its dancers dance")
	ball.time = 0.0
	await _physics(3)
	check(g3.defeated, "...and pop when the music stops")
	arsenal.select("popper")
	arsenal.xp["popper"] = arsenal.LEVEL_XP[4]
	await _frames(2)
	popper._cooldown = 0.0
	var before := get_nodes_in_group("star_bubbles").size()
	popper.shoot(false)
	check(get_nodes_in_group("star_bubbles").size() == before + 2, "the Mega Popper blows two bubbles at once")
	check(str(popper._prop.get_meta("gadget", "")) == "popper", "...and it's the popper in her hand again")
	arsenal.xp["popper"] = 0

	# --- The wheel ---
	var wheel = popper.find_child("GadgetWheel", true, false)
	arsenal.select("fizz")
	arsenal.select("popper")
	Input.action_press("gadget_wheel")
	await _frames(2)
	await create_timer(0.35, true, false, true).timeout
	await _frames(2)
	check(wheel.open and is_equal_approx(Engine.time_scale, wheel.SLOW), "holding Gadget wheel opens the wheel and slows the game")
	wheel.point(wheel.slot_angle(arsenal.ORDER.find("disco")))
	check(wheel.hover == "disco", "pointing picks a slot")
	Input.action_release("gadget_wheel")
	await _frames(3)
	check(not wheel.open and is_equal_approx(Engine.time_scale, 1.0) and arsenal.current == "disco",
		"letting go picks the Disco Ball and the game runs on")
	Input.action_press("gadget_wheel")
	await _frames(2)
	Input.action_release("gadget_wheel")
	await _frames(3)
	check(arsenal.current == "popper", "a tap swaps back to the last one")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_2
	ev.pressed = true
	wheel._unhandled_input(ev)
	check(arsenal.current == "fizz", "2 picks the Fizz Flinger")

	# --- Ammo bubbles ---
	arsenal.ammo["fizz"] = 1
	var drop = arsenal.drop(p.global_position + Vector3(1.5, 0.5, 0), "fizz")
	await _physics(40)
	check(not is_instance_valid(drop) and arsenal.ammo_of("fizz") > 1, "an ammo bubble drifts to her and tops up the fizz (%d)" % arsenal.ammo_of("fizz"))

	await _slice_2_and_3(town, p, popper, gloops, flat)

	# --- Saving ---
	arsenal.fit("fizz", 0, "bounce")
	var saved_max: int = arsenal.max_ammo("fizz")
	var saved: Dictionary = arsenal.save_data().duplicate(true)
	arsenal.reset()
	arsenal.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(arsenal.owns("fizz") and arsenal.owns("disco") and int(arsenal.xp.get("disco", 0)) == int(saved.xp.disco)
		and arsenal.ammo_of("fizz") == int(saved.ammo.fizz), "gadgets, ammo and versions save and load")
	check(arsenal.owns("jelly") and arsenal.owns_mod("freeze") and arsenal.has_mod("fizz", "bounce")
		and arsenal.upgrade_level("fizz", "ammo") == 1 and arsenal.max_ammo("fizz") == int(saved_max),
		"...and so do the mods, the slots and the upgrades")
	arsenal.load_data({})
	check(arsenal.owned == ["popper"] and arsenal.mods_owned.is_empty() and arsenal.mods("popper").is_empty(),
		"an old save starts with just the Star Popper, and no mods")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _slice_2_and_3(town: Node, p: CharacterBody3D, popper: Node, gloops: Array[Node], flat: Vector3) -> void:
	var stall := town.get_node_or_null("Gadget Stall") as Node3D
	# --- Dash's workbench ---
	var spot := stall.find_child("Workbench Shop Spot", true, false) if stall else null
	check(spot != null and spot.get("stall") == "Workbench", "Dash's workbench is beside his stall")
	var bench: Array = shop.for_stall("Workbench")
	var mods_sold: int = bench.filter(func(it: Dictionary) -> bool: return it.kind == "mod").size()
	check(mods_sold == 4, "...it sells the four mods (%d)" % mods_sold)
	var ups: Array = bench.filter(func(it: Dictionary) -> bool: return it.kind == "gadget_upgrade")
	check(ups.size() == 8 and ups.all(func(it: Dictionary) -> bool: return int(it.level) == 1),
		"...and the first level of each upgrade for the gadgets she has (%d)" % ups.size())
	var dear: Array = shop.items.values().filter(func(it: Dictionary) -> bool:
		return it.stall in ["Gadget", "Workbench"] and int(it.price) > 20)
	check(dear.is_empty(), "nothing there costs over 20 sparkles")
	game.sparkles = 200
	check(shop.buy("mod_freeze") and arsenal.owns_mod("freeze"), "buying the Freeze mod")
	check(shop.can_buy("mod_freeze") == "You have this one", "...once")
	for m in ["mod_split", "mod_bounce", "mod_magnet"]:
		shop.buy(m)
	check(arsenal.mods_owned.size() == 4, "...and the other three")
	var before: int = arsenal.max_ammo("fizz")
	check(shop.buy("upgrade_fizz_ammo_1") and arsenal.max_ammo("fizz") > before and arsenal.ammo_of("fizz") == arsenal.max_ammo("fizz"),
		"a Bigger Tank gives the Fizz Flinger more ammo (%d -> %d), full" % [before, arsenal.max_ammo("fizz")])
	check(shop.for_stall("Workbench").any(func(it: Dictionary) -> bool: return it.id == "upgrade_fizz_ammo_2")
		and not shop.for_stall("Workbench").any(func(it: Dictionary) -> bool: return it.id == "upgrade_fizz_ammo_1"),
		"...then the workbench offers level 2")
	var cd: float = arsenal.stat("disco", "cooldown")
	var rad: float = arsenal.stat("disco", "radius")
	arsenal.upgrade("disco", "reload")
	arsenal.upgrade("disco", "splash")
	check(float(arsenal.stat("disco", "cooldown")) < cd and float(arsenal.stat("disco", "radius")) > rad,
		"Quick Hands and Big Splash make the Disco Ball quicker and bigger")
	check(shop.can_buy("upgrade_popper_reload_2") == "Needs level 1 first" and not shop.items.has("upgrade_popper_ammo_1"),
		"upgrades go in order, and the Star Popper has no tank to upgrade")
	shop.close()

	# --- The four new gadgets (bought, then each tried with every mod) ---
	for g in ["plushinator", "buzz_bots", "rainbow_ray", "jelly_mines"]:
		shop.open("Gadget")
		shop.buy(g)
		shop.close()
	check(["plush", "buzz", "rainbow", "jelly"].all(func(id: String) -> bool: return arsenal.owns(id)),
		"Dash's stall sells the Plushinator, Buzz Bots, Rainbow Ray and Jelly Mines")
	check(shop.for_stall("Gadget").filter(func(it: Dictionary) -> bool: return it.kind == "ammo").size() == 6,
		"...and refills for each gadget she has")
	await _frames(2)
	for id in ["plush", "buzz", "rainbow", "jelly"]:
		arsenal.select(id)
		await _frames(2)
		check(str(popper._prop.get_meta("gadget", "")) == id, "the %s is in her hand when it's out" % arsenal.GADGETS[id].name)
	arsenal.xp["disco"] = 0

	var g0 := gloops[4] as CharacterBody3D
	var g1 := gloops[5] as CharacterBody3D
	var g2 := gloops[6] as CharacterBody3D
	# The Plushinator
	arsenal.select("plush")
	_fresh(g0)
	_stage(p, g0, flat, Vector3(0, 0, 7))
	await _physics(3)
	popper._cooldown = 0.0
	var bolt = popper.shoot(false)
	await _physics(30)
	check(arsenal.is_plush(g0) and not g0.is_physics_processing() and g0.find_child("Plushie", false, false) != null,
		"a Plushinator bolt turns a Gloop into a plushie, sitting still")
	var sparks: int = game.sparkles
	arsenal.select("popper")
	popper._cooldown = 0.0
	popper.shoot(false)
	await _physics(30)
	check(g0.defeated and game.sparkles > sparks, "...one bubble pops it, for a sparkle (%d -> %d)" % [sparks, game.sparkles])
	_fresh(g1)
	_stage(p, g1, flat, Vector3(0, 0, 7))
	arsenal.plush(g1, 0.1)
	await create_timer(0.3).timeout
	await _physics(2)
	check(not arsenal.is_plush(g1) and g1.is_physics_processing() and (g1.get_node("Visual") as Node3D).visible,
		"...and if nobody pops it, it turns back")
	# Plush Party (V5)
	arsenal.select("plush")
	arsenal.xp["plush"] = arsenal.LEVEL_XP[4]
	_fresh(g0)
	_fresh(g1)
	_stage(p, g0, flat, Vector3(0, 0, 7))
	_place(p, g1, g0.global_position + Vector3(1.5, 0, 0))
	await _physics(3)
	popper._cooldown = 0.0
	popper.shoot(false)
	await _physics(30)
	check(arsenal.gadget_name("plush") == "Plush Party" and arsenal.is_plush(g0) and arsenal.is_plush(g1),
		"the Plush Party (V5) turns everyone round it into plushies")
	arsenal.unplush(g0)
	arsenal.unplush(g1)
	arsenal.xp["plush"] = 0

	# Buzz Bots
	arsenal.select("buzz")
	_fresh(g0)
	_stage(p, g0, flat, Vector3(0, 0, 5))
	g0.set("stomps_to_defeat", 1)
	await _physics(2)
	popper._cooldown = 0.0
	var bots = popper.shoot(false)
	check(bots != null and bots.bots.size() == 3, "Buzz Bots: three helper bots come out")
	await _physics(150)
	check(is_instance_valid(bots) and bots.shots > 0 and g0.defeated and int(arsenal.xp.get("buzz", 0)) >= 1,
		"...they buzz round her and bubble a Gloop in reach (a point for the Buzz Bots)")
	if is_instance_valid(bots):
		bots.finish()
	arsenal.xp["buzz"] = arsenal.LEVEL_XP[4]
	popper._cooldown = 0.0
	bots = popper.shoot(false)
	check(bots != null and bots.bots.size() == 5 and arsenal.gadget_name("buzz") == "Buzz Swarm", "the Buzz Swarm (V5) is five bots")
	bots.finish()
	arsenal.xp["buzz"] = 0

	# Rainbow Ray
	arsenal.select("rainbow")
	_fresh(g0)
	_stage(p, g0, flat, Vector3(0, 0, 6))
	await _physics(2)
	var ammo_was: int = arsenal.ammo_of("rainbow")
	for k in 20:
		popper.shine(1.0 / 60.0)
		await physics_frame
	var ray = popper.ray
	check(ray != null and ray.fills.has(g0) and float(ray.fills[g0]) > 0.1 and g0.find_child("RainbowFill", false, false) != null,
		"the Rainbow Ray fills a Gloop with colour")
	check(arsenal.ammo_of("rainbow") < ammo_was, "...using ammo while it shines")
	for k in 100:
		popper.shine(1.0 / 60.0)
		await physics_frame
	check(g0.defeated, "...till it pops")
	# Double Rainbow (V5) goes through a row
	arsenal.xp["rainbow"] = arsenal.LEVEL_XP[4]
	_fresh(g0)
	_fresh(g1)
	_stage(p, g0, flat, Vector3(0, 0, 4))
	_place(p, g1, flat + Vector3(0, 0, 7))
	for g in [g0, g1]:
		(g as Node3D).set_physics_process(false)
	await _physics(2)
	for k in 80:
		popper.shine(1.0 / 60.0)
		await physics_frame
	check(g0.defeated and g1.defeated, "the Double Rainbow (V5) pops two in a row")
	for g in [g0, g1]:
		(g as Node3D).set_physics_process(true)
	arsenal.xp["rainbow"] = 0

	# Jelly Mines
	arsenal.select("jelly")
	_fresh(g0)
	_stage(p, g0, flat, Vector3(0, 0, 6))
	await _physics(2)
	popper._cooldown = 0.0
	var mine = popper.shoot(false)
	check(mine != null and mine.is_in_group("jelly_mines") and mine.global_position.distance_to(p.global_position) < 2.5,
		"Jelly Mines: one drops on the ground in front of her")
	_place(p, g0, mine.global_position)
	await _physics(10)
	check(mine.stuck.has(g0) and not g0.is_physics_processing(), "...a Gloop that walks in is stuck")
	await _physics(110)
	check(g0.defeated and not is_instance_valid(mine), "...then pops, and the jelly splats")
	arsenal.xp["jelly"] = arsenal.LEVEL_XP[4]
	_fresh(g0)
	popper._cooldown = 0.0
	mine = popper.shoot(false)
	_place(p, g0, mine.global_position)
	await _physics(90)
	check(get_nodes_in_group("jelly_mines").size() == 2, "the Jelly Jamboree (V5) leaves two little jellies")
	for j in get_nodes_in_group("jelly_mines"):
		j.melt()
	arsenal.xp["jelly"] = 0
	await _physics(30)

	# --- Every mod on every gadget (one Gloop at a time) ---
	for g in [g0, g1]:
		_fresh(g)
		(g as Node3D).global_position += Vector3(0, -300, 0)
		(g as Node3D).set_physics_process(false)
	var ids: Array = arsenal.ORDER
	for id in ids:
		arsenal.ammo[id] = arsenal.max_ammo(id)
	# Split: two of everything
	for id in ids:
		arsenal.select(id)
		arsenal.slots[id] = ["split", ""]
		var n := await _count_shot(p, popper, id, g2, flat)
		var want := 2 if id != "buzz" else 5
		check(n == want, "Split on the %s: %d (%d)" % [arsenal.GADGETS[id].name, want, n])
		arsenal.slots[id] = ["", ""]
		_clean()
		await _physics(5)
	# Freeze: a frosty puff that slows
	for id in ids:
		arsenal.select(id)
		arsenal.slots[id] = ["freeze", ""]
		g2.remove_meta("chill_until") if g2.has_meta("chill_until") else null
		_fresh(g2)
		_stage(p, g2, flat, Vector3(0, 0, 5))
		g2.set("stomps_to_defeat", 99)
		await _physics(2)
		popper._cooldown = 0.0
		var puffs := [0]                                   # (lambdas copy plain locals, so a list to count in)
		var hooked := func(n: Node) -> void:
			if "FrostPuff" in str(n.name):
				puffs[0] += 1
		node_added.connect(hooked)
		if id == "rainbow":
			for k in 30:
				popper.shine(1.0 / 60.0)
				await physics_frame
			arsenal.impact(g2.global_position, "rainbow")      # (its puff comes when someone pops)
		elif id == "buzz":
			popper.shoot(false)
			await _physics(150)
		elif id == "jelly":
			var m = popper.shoot(false)
			_place(p, g2, m.global_position)
			await _physics(15)
			m.splat()
		else:
			popper.shoot(false)
			await _physics(70)
		await _physics(2)
		node_added.disconnect(hooked)
		check(puffs[0] > 0 and arsenal.slow(g2) < 1.0, "Freeze on the %s: a frosty puff slows the Gloop" % arsenal.GADGETS[id].name)
		arsenal.slots[id] = ["", ""]
		g2.set("stomps_to_defeat", 1)
		_clean()
		await _physics(5)
	# Frosty enemies really are slower
	_fresh(g2)
	_stage(p, g2, flat, Vector3(0, 0, 6))
	g2.set("home", g2.global_position)                    # (so it isn't leashed back to its own home)
	g2.remove_meta("chill_until")
	g2.set_physics_process(true)
	await _physics(40)
	var quick := Vector2(g2.velocity.x, g2.velocity.z).length()
	arsenal.chill(g2)
	await _physics(40)
	var slow := Vector2(g2.velocity.x, g2.velocity.z).length()
	check(quick > 1.0 and slow < quick * 0.6, "a frosty Gloop chases slower (%.1f -> %.1f m/s)" % [quick, slow])
	check(g2.find_child("Frost", false, false) != null, "...and looks frosty")
	g2.remove_meta("chill_until")
	# Bounce: off the ground or a wall
	for id in ids:
		arsenal.select(id)
		arsenal.slots[id] = ["bounce", ""]
		var ok := await _bounces(p, popper, id, g2, flat)
		check(ok, "Bounce on the %s" % arsenal.GADGETS[id].name)
		arsenal.slots[id] = ["", ""]
		_clean()
		await _physics(5)
	# Sparkle Magnet: sparkles and ammo bubbles fly to her
	var sparkle: Node3D = town.find_children("*", "Area3D", true, false).filter(func(n: Node) -> bool:
		return n.is_in_group("sparkles") and n.visible).front() as Node3D
	for id in ids:
		arsenal.select(id)
		arsenal.slots[id] = ["magnet", ""]
		check(arsenal.ammo_pull() > 5.0, "Sparkle Magnet on the %s pulls ammo bubbles from further off" % arsenal.GADGETS[id].name)
		arsenal.slots[id] = ["", ""]
	arsenal.select("popper")
	arsenal.slots["popper"] = ["magnet", ""]
	if sparkle:
		var spot_s := sparkle.global_position
		p.global_position = spot_s + Vector3(6.0, 0.85, 0)
		p.velocity = Vector3.ZERO
		var had: int = game.sparkles
		await _physics(40)
		check(game.sparkle_taken(sparkle.name) and game.sparkles == had + 1, "...and a sparkle 6 m away flies to her")
	arsenal.ammo["fizz"] = 1
	var far_drop = arsenal.drop(p.global_position + Vector3(7.0, 0.5, 0), "fizz")
	await _physics(80)
	check(not is_instance_valid(far_drop), "...and so does an ammo bubble 7 m away")
	arsenal.slots["popper"] = ["", ""]

	# --- Combos ---
	arsenal.fit("popper", 0, "freeze")
	arsenal.fit("popper", 1, "split")
	check(arsenal.combo_name("popper") == "Icy Shards", "Freeze and Split together are Icy Shards")
	arsenal.fit("popper", 1, "freeze")
	check(arsenal.slots_of("popper") == ["", "freeze"], "the same mod can't go in both slots")
	arsenal.fit("popper", 0, "split")
	_fresh(g0)
	_fresh(g1)
	_stage(p, g0, flat, Vector3(0, 0, 5))
	_place(p, g1, g0.global_position + Vector3(2.5, 0, 0))
	for g in [g0, g1]:
		g.set("stomps_to_defeat", 1)
		(g as Node3D).set_physics_process(false)
	var shards := [0]
	var count_shards := func(n: Node) -> void:
		if "IcyShard" in str(n.name):
			shards[0] += 1
	node_added.connect(count_shards)
	arsenal.impact(g0.global_position, "popper")
	await _physics(30)
	node_added.disconnect(count_shards)
	check(shards[0] >= 2 and g0.defeated and g1.defeated, "...whose frosty puffs throw icy shards that pop (%d shards)" % shards[0])
	for g in [g0, g1]:
		(g as Node3D).set_physics_process(true)
	check(arsenal.COMBOS.size() == 6, "every pair of mods has a combo name")
	arsenal.slots["popper"] = ["", ""]

	# --- The Bag's Gadgets page ---
	var menu := root.get_node("PlayerMenu")
	menu.open("bag")
	await _frames(3)
	var slot_b := menu.find_child("Slot fizz 0", true, false) as Button
	check(slot_b != null and menu.find_child("Gadgets", true, false) != null, "the Bag has a Gadgets page with mod slots")
	if slot_b:
		slot_b.pressed.emit()
		check(arsenal.slots_of("fizz")[0] == "freeze" and "Freeze" in slot_b.text, "...pressing a slot swaps in the next mod (%s)" % slot_b.text)
	menu.close()
	await _frames(2)
	var wheel = popper.find_child("GadgetWheel", true, false)
	wheel.open_wheel()
	wheel.hover = "fizz"
	wheel.queue_redraw()
	await _frames(2)
	wheel.close(false)
	check(wheel.slot_angle(6) != wheel.slot_angle(0) and arsenal.ORDER.size() == 7, "the wheel has room for all seven gadgets")

	# --- Ammo crates ---
	var crates := get_nodes_in_group("ammo_crates")
	check(crates.size() == arsenal.CRATES.size(), "%d ammo crates round Galaxity" % crates.size())
	var space := p.get_world_3d().direct_space_state
	var bad := []
	for c in crates:
		var at := (c as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -0.6, 0))
		q.exclude = [(c as CollisionObject3D).get_rid()]
		var under := space.intersect_ray(q)
		var box := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.7, 0.6, 0.7)
		box.shape = bs
		box.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.45, 0))
		box.exclude = [(c as CollisionObject3D).get_rid()]
		var inside: Array = space.intersect_shape(box, 4).filter(func(h: Dictionary) -> bool: return h.collider is StaticBody3D)
		if under.is_empty() or not inside.is_empty() or at.y < -0.3:
			bad.append("%s %s" % [c.name, at])
	check(bad.is_empty(), "...each on open ground, out of the water %s" % str(bad))
	var near_king: int = crates.filter(func(c: Node) -> bool:
		return (c as Node3D).global_position.distance_to(Vector3(-128, 0, 8)) < 20.0).size()
	check(near_king >= 3, "...%d of them near the Gloop King" % near_king)
	arsenal.ammo["fizz"] = 0
	arsenal.ammo["jelly"] = 0
	var crate := crates[0] as Node3D
	arsenal.select("popper")
	p.global_position = crate.global_position + Vector3(0, 0.85, 6)
	p.velocity = Vector3.ZERO
	await _physics(3)
	var from := crate.global_position + Vector3(0, 0.5, 4)
	load("res://scripts/star_bubble.gd").fire(current_scene, from, Vector3(0, 0, -1), p, false, 1.0)
	await _physics(40)
	check(crate.opened and arsenal.ammo_of("fizz") > 0 and arsenal.ammo_of("jelly") > 0, "a bubble pops a crate and fills her gadgets")
	crate.refill()
	p.global_position = crate.global_position + Vector3(0, 0.9, 0.6)
	await _physics(10)
	check(crate.opened, "...walking into one pops it too")
	crate.refill()
	check(not crate.opened, "...and they're back the next day")

	# --- Sounds ---
	var quiet := []
	for n in ["plush_poof", "buzz", "rainbow_hum", "rainbow_pop", "jelly", "frost", "crate"]:
		var st := root.get_node("Audio")._stream(n) as AudioStreamWAV
		if st == null or st.data.size() < 2000:
			quiet.append(n)
	check(quiet.is_empty(), "every new gadget sound is made %s" % str(quiet))
	p.global_position = flat + Vector3(0, 0.85, 0)


func _fresh(g: CharacterBody3D) -> void:
	# A Gloop back to new, wherever it is (stopping any pop that's still floating it off)
	for t in get_processed_tweens():
		t.kill()
	arsenal.unplush(g)
	if g.has_meta("chill_until"):
		g.remove_meta("chill_until")
	g.defeated = false
	g.hits = 0
	g.set("_squash", 0.0)
	(g.get_node("CollisionShape3D") as CollisionShape3D).disabled = false
	(g.get_node("Hitbox") as Area3D).monitoring = true
	var v := g.get_node("Visual") as Node3D
	v.visible = true
	v.position = Vector3.ZERO
	v.rotation = Vector3.ZERO
	v.scale = Vector3.ONE * float(g.get("size"))
	g.set("stomps_to_defeat", 1)
	g.set_physics_process(true)
	var old := g.get_node_or_null("CaughtBubble")
	if old:
		old.queue_free()
	(g.get_node("Puddle") as Node3D).scale = Vector3.ONE


func _clean() -> void:
	for grp in ["star_bubbles", "fizz_bombs", "disco_balls", "buzz_bots", "jelly_mines", "plush_bolts", "frost_puffs"]:
		for n in get_nodes_in_group(grp):
			n.queue_free()


func _count_shot(p: CharacterBody3D, popper: Node, id: String, g: CharacterBody3D, flat: Vector3) -> int:
	# How many of whatever it fires come out of one shot
	_fresh(g)
	_stage(p, g, flat, Vector3(0, 0, 8))
	g.set_physics_process(false)
	await _physics(2)
	popper._cooldown = 0.0
	match id:
		"rainbow":
			popper.shine(1.0 / 60.0)
			await physics_frame
			return popper.ray.ends.size()
		"buzz":
			var b = popper.shoot(false)
			var n: int = b.bots.size() if b else 0
			if b:
				b.finish()
			return n
	var grp: String = {"popper": "star_bubbles", "fizz": "fizz_bombs", "disco": "disco_balls", "plush": "plush_bolts",
		"jelly": "jelly_mines"}[id]
	var was := get_nodes_in_group(grp).size()
	popper.shoot(false)
	return get_nodes_in_group(grp).size() - was


func _bounces(p: CharacterBody3D, popper: Node, id: String, g: CharacterBody3D, flat: Vector3) -> bool:
	# Fires at the ground with nothing about (or, for the Jelly Mines, next to a Gloop) and sees it bounce
	_fresh(g)
	g.global_position += Vector3(0, -300, 0)
	g.set_physics_process(false)
	p.global_position = flat + Vector3(0, 0.85, 0)
	p.velocity = Vector3.ZERO
	await _physics(2)
	popper._cooldown = 0.0
	match id:
		"popper", "plush":
			var down := Vector3(0, -1, 1).normalized()
			var b
			if id == "popper":
				b = load("res://scripts/star_bubble.gd").fire(current_scene, p.global_position + Vector3(0, 0.5, 0.5), down, p, false, 1.0)
			else:
				b = load("res://scripts/plush_bolt.gd").fire_bolt(current_scene, p.global_position + Vector3(0, 0.5, 0.5), down, p, {})
			await _physics(12)
			return is_instance_valid(b) and b.bounces_left == 0 and b.velocity.y > 0.0
		"buzz":
			var b = load("res://scripts/star_bubble.gd").fire(current_scene, p.global_position + Vector3(0, 0.5, 0.5), Vector3(0, -1, 1).normalized(), p, false, 1.0)
			b.set_meta("gadget", "buzz")
			await _physics(12)
			return is_instance_valid(b) and b.velocity.y > 0.0
		"fizz":
			var f = popper.shoot(false)
			for k in 120:
				await physics_frame
				if not is_instance_valid(f) or f.bounces > 0:
					break
			return is_instance_valid(f) and f.bounces == 1
		"disco":
			var d = popper.shoot(false)
			for k in 120:
				await physics_frame
				if not is_instance_valid(d) or d._bounced:
					break
			var ok: bool = is_instance_valid(d) and d._bounced and d._flying
			if is_instance_valid(d):
				d.queue_free()
			return ok
		"rainbow":
			popper.ray.shine(p.global_position + Vector3(0, 0.5, 0), Vector3(0, -1, 1).normalized(), {"radius": 10.0})
			return popper.ray.ends.size() == 2
		"jelly":
			var m = popper.shoot(false)
			_fresh(g)
			_place(p, g, m.global_position + Vector3(4.0, 0, 0))
			g.set_physics_process(false)
			var at: Vector3 = m.global_position
			await create_timer(2.6).timeout
			var moved: bool = is_instance_valid(m) and m.global_position.distance_to(at) > 1.0
			if is_instance_valid(m):
				m.melt()
			return moved or not is_instance_valid(m)
	return false


func _flat_spot(town: Node, p: CharacterBody3D) -> Vector3:
	# Somewhere open on the town's ground: in the market square, away from the stalls
	var spot := town.find_child("Market Square", true, false) as Node3D
	var at := spot.global_position + Vector3(0, 0, 14) if spot else p.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -40, 0))
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _stage(p: CharacterBody3D, enemy: CharacterBody3D, at: Vector3, offset: Vector3) -> void:
	# Her on open ground facing the enemy, `offset` from her
	p.global_position = at + Vector3(0, 0.85, 0)
	p.velocity = Vector3.ZERO
	_place(p, enemy, at + offset)
	var d := Vector3(offset.x, 0, offset.z).normalized()
	(p.get_node("Visual") as Node3D).rotation.y = atan2(d.x, d.z)


func _place(p: CharacterBody3D, enemy: CharacterBody3D, spot: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 20, 0), spot + Vector3(0, -20, 0))
	q.exclude = [p.get_rid(), enemy.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	enemy.global_position = hit.position if not hit.is_empty() else spot
	enemy.velocity = Vector3.ZERO


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Engine.time_scale = 1.0
	Input.action_release("gadget_wheel")
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)              # there was no save before the test: don't leave one
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	quit(1 if failures > 0 else 0)
