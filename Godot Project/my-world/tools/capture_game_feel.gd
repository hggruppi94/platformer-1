extends SceneTree

# Short clips (every frame saved, for turning into GIFs) of the game-feel touches on skating and the Star Popper
# (scripts/juice.gd kick() and dust(), scenes/player/skate.gd, scripts/star_popper.gd, scripts/star_bubble.gd) at
# the Skate Park at midday, from a camera beside her (Juice nudges whatever camera is showing, so the kicks still
# show): an ollie, a big drop
# landing, a bail, riding off the end of a rail, a trick combo with the HUD bumping, and popping a Gloop on foot.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_game_feel.gd -- <output folder>
#
# Each clip is a folder of numbered PNGs. Your own save is put aside (under a name of its own) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.game_feel_capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://game_feel_shots"
var player: CharacterBody3D
var skate: Node
var arm: SpringArm3D
var cam: Camera3D
var _frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(960, 600))
	create_timer(400.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	game._resume = {}
	game.pending_message = ""
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	settings.tips = false
	settings.reduce_motion = false
	settings.screen_shake = 1.0
	settings.last_device = "pad"
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	skate = player.get_node("Skate")
	arm = player.get_node("SpringArm3D") as SpringArm3D
	var park := town.get_node("Skate Park") as Node3D
	var c := park.global_position + Vector3(0, 0.25, 0)
	await _physics(3)
	var gloops: Array[Node] = park.find_children("Skate Gloop *", "", false, false)
	for g in gloops:
		(g as Node3D).set_physics_process(false)
		(g as Node3D).global_position += Vector3(0, -300, 0)
	game.riding = true
	game.equipment_changed.emit()
	await _physics(5)
	(player.get_node("HUD") as CanvasLayer).visible = false
	skate.landed.connect(func(clean: bool) -> void: print("EVENT landed clean=%s frame %d, puffs %d, parent %s" % [clean, _frame,
		player.get_parent().find_children("Dust*", "Node3D", false, false).size(), player.get_parent().name]))
	skate.bailed.connect(func() -> void: print("EVENT bailed frame %d" % _frame))
	cam = Camera3D.new()
	cam.fov = 50
	town.add_child(cam)
	cam.make_current()

	# --- 1: an ollie off the flat: the dust puff from the tail ---
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	player.velocity = Vector3(5, 0, 0)
	_side_view()
	await _physics(15)
	skate._pop()
	player.velocity.y = 5.0
	await _clip("01_ollie_dust", 40)

	# --- 2: a big drop: dust ring, camera sinks and comes back, a thud ---
	_put(c + Vector3(-5, 5.5, 1.5), skate.State.AIR)
	player.velocity = Vector3(4, -6, 0)
	_side_view(1.8, 7.0, 2.5)
	await _clip("02_big_landing", 55)

	# --- 3: a bail: freeze beat, thud, dust cloud ---
	_put(c + Vector3(-6, 0.85, 1.5), skate.State.ROLL)
	player.velocity = Vector3(6, 0, 0)
	_side_view()
	await _physics(15)
	create_timer(0.05).timeout.connect(skate.bail)
	await _clip("03_bail", 50)
	await _physics(90)

	# --- 4: off the end of the flat rail: a last flick of sparks ---
	var rail := park.get_node("Flat Rail").find_children("*", "GrindRail", true, false)[0] as GrindRail
	_put(rail.point_at(rail.length() * 0.55) + Vector3(0, 1.4, 0), skate.State.AIR)
	var t := rail.tangent_at(rail.length() * 0.55)
	player.velocity = t * 6.0 + Vector3(0, -1, 0)
	skate._grind_buffer = 0.2
	skate._try_grind()
	_side_view()
	await _clip("04_off_the_rail", 50)
	skate.tricks.bank()

	# --- 5: a combo in the air: each trick ticks and the combo line bumps; then the gold when it pays out ---
	_put(c + Vector3(-5, 5.0, 1.5), skate.State.AIR)
	player.velocity = Vector3(3, 6, 0)
	_side_view(1.5, 8.0, 2.5)
	skate.tricks.start_flip("")
	await _physics(12)
	skate.tricks.add("Big Spin", 900)
	await _physics(8)
	skate.tricks.add("Melon", 700)
	await _clip("05_combo_bump", 90)

	# --- 6: on foot, popping a Gloop: the nozzle puff, the squish, the beat of freeze on the pop ---
	game.riding = false
	game.equipment_changed.emit()
	await _physics(5)
	_put_foot(c + Vector3(-5, 0.9, 1.0))
	var g := gloops[0] as CharacterBody3D
	var q := PhysicsRayQueryParameters3D.create(c + Vector3(-1.5, 6, 1.0), c + Vector3(-1.5, -6, 1.0))
	q.exclude = [player.get_rid(), g.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	g.global_position = hit.position if not hit.is_empty() else c + Vector3(-1.5, 0, 1.0)
	(g.get_node("Visual") as Node3D).rotation.y = -PI / 2
	_side_view(1.7, 5.0, 1.0)
	await _physics(10)
	var popper = player.get("popper")
	popper._cooldown = 0.0
	popper.shoot(false)
	await _clip("06_popper_shot", 30)
	popper._cooldown = 0.0
	popper.shoot(false)
	await _clip("07_popper_pop", 60)
	_finish()


func _put(at: Vector3, state: int) -> void:
	skate.tricks.lose()
	skate._manual = 0
	player.global_position = at
	player.velocity = Vector3.ZERO
	skate.state = state
	skate._yaw = PI / 2
	(player.get_node("Visual") as Node3D).rotation.y = PI / 2


func _put_foot(at: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	(player.get_node("Visual") as Node3D).rotation.y = PI / 2


func _side_view(ahead := 2.0, back := 6.0, up := 1.2) -> void:
	# Side on to her, a little ahead of where she's going, so the action happens in the middle of the picture
	var at := player.global_position + Vector3(ahead, 0, 0)
	at.y = player.global_position.y - (2.0 if up > 2.0 else 0.0)
	cam.global_position = at + Vector3(0, up, back)
	cam.look_at(at + Vector3(0, -0.2, 0))
	cam.make_current()


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _clip(name: String, frames: int) -> void:
	# Every drawn frame for a moment, so the clip shows the hit-pause as it plays
	var dir := out_dir.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	for i in frames:
		_frame = i
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("%03d.png" % i))
	_frame = -1
	print("CLIP ", name)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
