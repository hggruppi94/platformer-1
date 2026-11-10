extends SceneTree

# Screenshots of the friends' sections of the Agent of Chaos's final fight (scripts/chaos_trials.gd): Bramble's Static
# Storm, Flurry's River of Melted Time, Pip's Lights Out (the glow and the glide), Melody's Off-Beat Stomp, Otto's
# Time Flood, Heather's Glitch Fires and clock gear, Dash's Glitch Crystals, the centipede's Clock Tower and the watch's
# Big Rewind. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_chaos_trials.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.chaos_trials_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const WORLDS := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor",
	"dark_hollow", "far_future"]

var out_dir := "user://chaos_trials_shots"
var cam: Camera3D
var town: Node3D
var p: CharacterBody3D
var giant: Node3D
var fight: Node
var trials: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(2400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.hold_saves = true
	game._resume = {}
	game.pending_message = ""
	root.get_node("Settings").tips = false
	root.get_node("Settings").no_damage = true
	root.get_node("Dialogue").flags["swap_tried"] = true
	root.get_node("Portals").cleared_worlds.assign(WORLDS)
	root.get_node("Arsenal").give("fizz", false)
	game.give_item("shop:shift_watch")
	change_scene_to_file(TOWN)
	for i in 8:
		await process_frame
	root.get_node("Clock").set_time(1, 16 * 60.0, true)
	town = current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	giant = town.find_child("ChaosGiant", true, false) as Node3D
	fight = giant.get_node("ChaosFight")
	trials = fight.get_node("Trials")
	var front := giant.global_transform.basis.z.normalized()
	await _stand(giant.global_position + front * 16.0)
	for i in 30:
		await physics_frame
	cam = Camera3D.new()
	cam.fov = 55
	town.add_child(cam)
	cam.make_current()
	var g := giant.global_position

	# Bramble: the Static Storm
	await _section("burrow")
	await _stand(trials._base + trials._out * 7.5 + trials._side * 1.5)
	p.burrow.try_start()
	await _snap("01_bramble_static_storm", trials._base + trials._out * 15.0 - trials._side * 6.0 + Vector3(0, 13, 0),
		trials._base + trials._out * 5.5, 20)
	p.burrow.stop()

	# Flurry: the River of Melted Time
	await _section("frost")
	await _stand(trials._base + trials._out * 16.5)
	_face(trials._base)
	p.frost_breath.cooldown = 0.0
	p.frost_breath.breathe()
	for i in 20:
		await physics_frame
	var floe: Node3D = p.frost_breath.floes[1] if p.frost_breath.floes.size() > 1 else null
	if floe:
		p.global_position = floe.global_position + Vector3(0, 0.8, 0)
		p.velocity = Vector3.ZERO
	_face(trials._base)
	p.frost_breath.cooldown = 0.0
	p.frost_breath.breathe()
	await _snap("02_flurry_river_of_melted_time", trials._base + trials._out * 22.0 + trials._side * 8.0 + Vector3(0, 10, 0),
		trials._base + trials._out * 9.0, 20)

	# Pip: Lights Out
	await _section("glow")
	await _stand(trials.lanterns[0].global_position + trials._out * 2.0 + trials._side * 1.0)
	for i in 30:
		await physics_frame
	p.get_node("HUD").visible = true
	await _snap("03_pip_lights_out", p.global_position + trials._out * 6.0 + Vector3(0, 3.5, 0),
		trials.lanterns[0].global_position + Vector3(0, 1.0, 0), 20)
	p.get_node("HUD").visible = false
	var across: Vector3 = trials.rock.global_position - trials.swirl_at
	across.y = 0.0
	p.global_position = trials.swirl_at + across * 0.4 + Vector3(0, 8.0, 0)
	p.velocity = across.normalized() * 4.0
	_face(trials.rock.global_position)
	Input.action_press("jump")
	for i in 6:
		await physics_frame
	await _snap("04_pip_gliding_to_the_rock", trials.swirl_at + across * 0.5 + trials._out * 13.0 + Vector3(0, 7.0, 0),
		p.global_position + across.normalized() * 2.0, 2)
	Input.action_release("jump")

	# Melody: the Off-Beat Stomp
	await _section("groove")
	await _stand(giant.global_position + trials._out * 8.0)
	p.groove.cooldown = 0.0
	p.groove.groove()
	await _snap("05_melody_off_beat_stomp", p.global_position + trials._out * 9.0 + trials._side * 5.0 + Vector3(0, 4, 0),
		giant.global_position + Vector3(0, 4, 0), 10)

	# Otto: the Time Flood
	await _section("swim")
	for i in 220:
		await physics_frame
	await _stand(trials._base + trials._out * 26.0)                   # on the shore, looking in
	await _snap("06_otto_time_flood", trials._base + trials._out * 30.0 + trials._side * 4.0 + Vector3(0, 9, 0),
		trials._base + Vector3(0, 3, 0), 10)

	# Heather: Glitch Fires, then the clock gear
	await _section("spring")
	await _stand(trials.fires[1].global_position + trials._out * 1.8)
	p.showers.cooldown = 0.0
	p.showers.shower()
	await _snap("07_heather_glitch_fires", p.global_position + trials._out * 8.0 - trials._side * 3.0 + Vector3(0, 9, 0),
		trials.fires[1].global_position + Vector3(0, 1, 0), 12)
	for f in trials.fires:
		trials._put_out(f)
	for i in 100:
		await physics_frame
	p.global_position = trials.gear.global_position + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	trials.left = 999.0
	for i in 2:
		await physics_frame
	await _snap("08_heather_clock_gear", trials.gear.global_position + trials._out * 9.0 + trials._side * 6.0 + Vector3(0, 1, 0),
		fight.heart_position() - Vector3(0, 1.5, 0), 3)

	# Dash: Glitch Crystals
	await _section("gadgets")
	await _stand(giant.global_position + trials._out * 13.0)
	await _snap("09_dash_glitch_crystals", p.global_position + trials._out * 4.0 + Vector3(0, 11, 0),
		giant.global_position + trials._out * 6.0 + Vector3(0, 2, 0), 10)

	# The centipede: the Clock Tower
	await _section("crawl")
	for i in 90:
		await physics_frame
	var tower: Node3D = trials.tower
	await _stand(tower.global_position - trials._out * 1.95)
	p.global_position += Vector3(0, 5.0, 0)
	p.wall_crawl.start(-trials._out)
	_face(tower.global_position)
	for i in 6:
		await physics_frame
	await _snap("10_centipede_clock_tower", tower.global_position + trials._out * 12.0 + trials._side * 7.0 + Vector3(0, 6, 0),
		tower.global_position + Vector3(0, 6, 0), 3)
	if p.wall_crawl.active:
		p.wall_crawl.stop()

	# The watch: the Big Rewind
	await _section("watch")
	await _stand(giant.global_position + trials._out * 13.0)
	p.get_node("HUD").visible = true
	p.get_node("HUD").check_watch()
	trials.left = 999.0
	await _snap("11_watch_big_rewind", p.global_position + trials._out * 4.0 + Vector3(0, 6, 0),
		fight.heart_position(), 4)
	_finish()


func _section(id: String) -> void:
	trials.cleanup()
	fight.trials.only = [id]
	fight._trial(id)
	trials.left = 999.0
	for i in 4:
		await physics_frame


func _stand(at: Vector3) -> void:
	var gr: Vector3 = fight._ground(at)
	p.global_position = gr + Vector3(0, 0.6, 0)
	p.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame


func _face(at: Vector3) -> void:
	var d := at - p.global_position
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		visual.global_rotation.y = atan2(d.x, d.z)


func _snap(file: String, at: Vector3, look: Vector3, wait := 8) -> void:
	cam.global_position = at
	cam.look_at(look)
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Input.action_release("jump")
	Input.action_release("move_forward")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
