extends SceneTree

# Screenshots of gadget slices 2 and 3 (scripts/arsenal.gd) in the Market Square at midday: Dash's workbench and its
# shop window, a Gloop turned into a plushie, the Buzz Bots bubbling a Gloop, the Rainbow Ray filling one with
# colour, a Gloop stuck in a Jelly Mine, a Freeze puff and a frosty Gloop, Split bubbles, Icy Shards, the gadget
# wheel with all seven gadgets and their mods, the Bag's Gadgets page, and ammo crates out by the Gloop King. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_arsenal_mods.gd -- <output folder>
#
# Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.arsenal_mods_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://arsenal_mods_shots"
var cam: Camera3D
var player: CharacterBody3D
var arm: SpringArm3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(200.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	var arsenal := root.get_node("Arsenal")
	var shop := root.get_node("Shop")
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	settings.tips = false
	settings.last_device = "keyboard"
	arsenal.reset()
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	arm = player.get_node("SpringArm3D") as SpringArm3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	var popper = player.get("popper")
	var enemies := town.find_children("Gloop *", "", true, false) + town.find_children("Crocodillo *", "", true, false)
	for e in enemies:
		(e as Node3D).set_physics_process(false)
		(e as Node3D).global_position += Vector3(0, -300, 0)
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	for id in ["fizz", "disco", "plush", "buzz", "rainbow", "jelly"]:
		arsenal.give(id, false)
	for m in ["freeze", "split", "bounce", "magnet"]:
		arsenal.give_mod(m)
	arsenal.slots = {}

	# --- 10, 11: Dash's workbench and its shop window ---
	var stall := town.get_node("Gadget Stall") as Node3D
	var bench := stall.find_child("Workbench", true, false) as Node3D
	var front := stall.global_transform.basis.z
	player.global_position = _ground(bench.global_position + front * 2.0) + Vector3(0, 0.85, 0)
	(player.get_node("Visual") as Node3D).rotation.y = atan2(-front.x, -front.z)
	cam.global_position = bench.global_position + front * 5.5 + Vector3(0, 2.2, 0) - stall.global_transform.basis.x * 1.5
	cam.look_at(bench.global_position + Vector3(-0.8, 1.3, 0))
	cam.make_current()
	await _physics(10)
	await _still("10_dashs_workbench")
	game.sparkles = 60
	arsenal.mods_owned.clear()
	shop.open("Workbench")
	await _frames(4)
	await _shot("11_workbench_shop")
	shop.close()
	for m in ["freeze", "split", "bounce", "magnet"]:
		arsenal.give_mod(m)
	arsenal.slots = {}

	var fountain := town.find_child("Market Square", true, false) as Node3D
	var ground := _ground(fountain.global_position + Vector3(0, 0, 14))
	var g := [] as Array
	for k in 6:
		g.append(town.find_child("Gloop %d" % k, true, false))
	var place := func(k: int, off: Vector3) -> void:
		var gl := g[k] as CharacterBody3D
		gl.global_position = _ground(ground + off)
		(gl.get_node("Visual") as Node3D).rotation.y = PI
		gl.stomps_to_defeat = 1
	var away := func() -> void:
		for gl in g:
			(gl as Node3D).global_position = Vector3(0, -300, 0)
			(gl as Node3D).set_physics_process(false)
	player.global_position = ground + Vector3(0, 0.85, 0)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0

	# --- 12: a plushie ---
	place.call(0, Vector3(0.5, 0, 6))
	arsenal.select("plush")
	await _physics(3)
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(25)
	cam.global_position = ground + Vector3(-3.0, 1.8, 3.0)
	cam.look_at(ground + Vector3(0.4, 0.6, 6))
	cam.make_current()
	await _still("12_plushinator_plushie")
	arsenal.unplush(g[0])
	away.call()

	# --- 13: Buzz Bots ---
	arsenal.select("buzz")
	place.call(1, Vector3(1.0, 0, 6))
	g[1].set_physics_process(false)
	g[1].stomps_to_defeat = 99
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(80)
	cam.global_position = ground + Vector3(-4.0, 2.6, -2.5)
	cam.look_at(ground + Vector3(0.3, 1.4, 2.5))
	await _still("13_buzz_bots")
	for b in get_nodes_in_group("buzz_bots"):
		b.finish()
	away.call()

	# --- 14: Rainbow Ray ---
	arsenal.select("rainbow")
	place.call(2, Vector3(0.0, 0, 7))
	g[2].set_physics_process(false)
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	for i in 40:
		popper.shine(1.0 / 60.0)
		await physics_frame
	cam.global_position = ground + Vector3(-4.5, 2.0, 2.0)
	cam.look_at(ground + Vector3(0, 1.0, 4.5))
	popper.shine(1.0 / 60.0)
	await _still("14_rainbow_ray")
	for i in 50:
		popper.shine(1.0 / 60.0)
		await physics_frame
	away.call()
	await _physics(60)

	# --- 15: a Gloop stuck in a Jelly Mine ---
	arsenal.select("jelly")
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	var mine = popper.shoot(false)
	g[3].global_position = mine.global_position
	g[3].set_physics_process(true)
	await _physics(30)
	cam.global_position = mine.global_position + Vector3(-2.6, 1.5, 2.2)
	cam.look_at(mine.global_position + Vector3(0, 0.5, 0))
	await _still("15_jelly_mine_stuck")
	await _physics(100)
	away.call()

	# --- 16: Freeze: a frosty puff and a frosty Gloop ---
	arsenal.select("fizz")
	arsenal.fit("fizz", 0, "freeze")
	arsenal.fit("fizz", 1, "bounce")
	place.call(4, Vector3(1.2, 0, 8))
	g[4].stomps_to_defeat = 99
	g[4].set_physics_process(false)
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	for i in 120:
		await physics_frame
		if town.find_child("FrostPuff", true, false) != null:
			break
	await _physics(4)
	cam.global_position = ground + Vector3(-4.5, 2.4, 4.5)
	cam.look_at(ground + Vector3(0.8, 0.8, 8))
	await _still("16_freeze_puff")
	await _physics(30)
	await _still("17_frosty_gloop")
	away.call()

	# --- 18: Split bubbles from the Star Popper, and Icy Shards ---
	arsenal.select("popper")
	arsenal.fit("popper", 0, "split")
	arsenal.fit("popper", 1, "freeze")
	place.call(5, Vector3(0, 0, 12))
	g[5].stomps_to_defeat = 99
	g[5].set_physics_process(false)
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(5)
	popper._cooldown = 0.0
	(player.get_node("Visual") as Node3D).rotation.y = 0.0
	popper.shoot(false)
	await _physics(6)
	cam.global_position = ground + Vector3(-3.0, 1.6, 0.5)
	cam.look_at(ground + Vector3(0, 1.2, 5))
	await _still("18_split_bubbles")
	place.call(0, Vector3(2.0, 0, 11))
	place.call(1, Vector3(-2.0, 0, 12.5))
	for k in [0, 1]:
		g[k].set_physics_process(false)
	arsenal.impact(g[5].global_position, "popper")
	await _physics(6)
	cam.global_position = ground + Vector3(-5.0, 3.0, 8.0)
	cam.look_at(ground + Vector3(0, 0.6, 12))
	await _still("19_icy_shards")
	await _physics(60)
	away.call()

	# --- 20: the wheel with all seven gadgets and their mods ---
	arsenal.fit("disco", 0, "bounce")
	arsenal.fit("plush", 0, "magnet")
	arsenal.fit("jelly", 0, "bounce")
	arsenal.fit("jelly", 1, "freeze")
	arm.get_node("Camera3D").make_current()
	var wheel = popper.find_child("GadgetWheel", true, false)
	wheel.open_wheel()
	wheel.point(wheel.slot_angle(0))
	await _frames(4)
	await _shot("20_gadget_wheel_with_mods")
	wheel.close(false)

	# --- 21: the Bag's Gadgets page ---
	var menu := root.get_node("PlayerMenu")
	menu.open("bag")
	await _frames(4)
	var head := menu.find_child("Gadgets", true, false) as Control
	var scs := menu.find_children("*", "ScrollContainer", true, false)
	var sc := scs[0] as ScrollContainer if not scs.is_empty() else null
	if head and sc:
		sc.scroll_vertical = int(head.position.y) - 10
	await _frames(4)
	await _shot("21_bag_gadgets_page")
	menu.close()
	await _frames(2)

	# --- 22, 23: ammo crates out by the Gloop King, and one popping ---
	var crate := town.find_child("Ammo Crate 3", true, false) as Node3D
	var king := town.find_child("The Gloop King", true, false) as Node3D
	player.global_position = _ground(crate.global_position + Vector3(4, 0, 4)) + Vector3(0, 0.85, 0)
	cam.global_position = crate.global_position + Vector3(5.0, 2.5, 6.0)
	cam.look_at((crate.global_position + (king.global_position if king else crate.global_position)) / 2.0 + Vector3(0, 1.0, 0))
	cam.make_current()
	await _physics(10)
	await _still("22_ammo_crates_by_the_gloop_king")
	crate.shot(1, crate.global_position, Vector3.UP)
	await _physics(4)
	cam.global_position = crate.global_position + Vector3(2.5, 1.4, 2.5)
	cam.look_at(crate.global_position + Vector3(0, 0.6, 0))
	await _still("23_ammo_crate_pops")
	_finish()


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -40, 0))
	q.exclude = [player.get_rid()] if player else []
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else at


func _look_at(target: Vector3) -> void:
	var c := arm.get_node("Camera3D") as Camera3D
	var d := (target - c.global_position).normalized()
	arm.rotation = Vector3(asin(d.y), atan2(-d.x, -d.z), 0)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _still(file: String) -> void:
	# Freeze everything for the picture, then carry on
	paused = true
	await _frames(3)
	await _shot(file)
	paused = false


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	Input.action_release("aim")
	Input.action_release("shoot")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save and FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
