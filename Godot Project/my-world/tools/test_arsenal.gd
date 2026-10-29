extends SceneTree

# Checks the hero's gadgets (scripts/arsenal.gd) in the town: the Gadget wheel is on R and D-pad up and can be
# remapped; she starts with just the Star Popper; Dash's gadget stall stands in the Market Square and sells the Fizz
# Flinger and the Disco Ball for sparkles (through the Shop, as kinds "gadget" and "ammo") and refills them. The Fizz
# Flinger lobs a fizz bomb that pops every Gloop in its splash and uses ammo; empty, it won't fire. The Disco Ball
# floats up and sets nearby Gloops dancing on the spot (not chasing), then lets them go. Gadgets grow versions with
# pops (more ammo, bigger splashes, the Disco Fever pops its dancers, the Mega Popper blows two bubbles). The wheel
# opens on a hold, slows the game, picks by direction and closes on release; a tap swaps back. Ammo bubbles top a
# gadget up. It all saves and loads, and her hand holds the gadget that's out.
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
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
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

	# --- Saving ---
	var saved: Dictionary = arsenal.save_data().duplicate(true)
	arsenal.reset()
	arsenal.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(arsenal.owns("fizz") and arsenal.owns("disco") and arsenal.current == "fizz" and arsenal.level("disco") == 5
		and arsenal.ammo_of("fizz") == int(saved.ammo.fizz), "gadgets, ammo and versions save and load")
	arsenal.load_data({})
	check(arsenal.owned == ["popper"], "an old save starts with just the Star Popper")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


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
