extends SceneTree

# Pictures of Nov 7's new looks and friends: human Nina on Earth in her new look (from Hayden's picture: red bob with a
# fringe and her red bow, freckles, a gap-tooth smile, little gold hoops, a white tee under a pink pinafore and her
# yellow backpack), then in Galaxity Melody (tools/build_melody.py) and the plant girl (tools/build_plant_girl.py),
# who burrows into the ground and sprouts up somewhere else (scripts/burrower.gd).
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_new_friends.gd -- <output folder> [earth|galaxity]
#
# Your own save and settings are put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.friends_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.friends_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://friends_shots"
var only := ""
var cam: Camera3D
var clock: Node
var game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	root.get_node("Settings").last_device = "keyboard"
	game._resume = {}
	game.pending_message = ""
	if only != "galaxity":
		await _earth()
	if only != "earth":
		await _galaxity()
	_finish()


func _earth() -> void:
	# Human Nina at noon on the green: front, side, back (her backpack), close on her face, and with Bruno and Prue
	game.next_spawn = "Entrance"
	clock.earth_minutes = 12 * 60.0
	change_scene_to_file(EARTH)
	await _frames(8)
	await create_timer(1.0).timeout
	_hide_player()
	_new_cam()
	var kids: Array[Node3D] = []
	for n in ["Nina", "Bruno", "Prue"]:
		var k := current_scene.find_child(n, true, false) as Node3D
		var r: Node = k.get_node_or_null("Routine")
		if r:
			r.process_mode = Node.PROCESS_MODE_DISABLED
		k.visible = true
		kids.append(k)
	var at := Vector3(0, 0.03, -6.5)
	kids[0].global_position = at
	kids[0].global_rotation = Vector3(0, PI, 0)
	kids[1].global_position = at + Vector3(40, 0, 0)
	kids[2].global_position = at + Vector3(42, 0, 0)
	await _shot_at("01_earth_nina_front", at + Vector3(0, 1.0, -2.6), at + Vector3(0, 0.75, 0), 45.0)
	await _shot_at("02_earth_nina_face", at + Vector3(0.1, 1.15, -1.2), at + Vector3(0, 1.1, 0), 40.0)
	kids[0].global_rotation = Vector3(0, PI * 0.5, 0)
	await _shot_at("03_earth_nina_side", at + Vector3(0, 1.0, -2.6), at + Vector3(0, 0.75, 0), 45.0)
	kids[0].global_rotation = Vector3(0, 0, 0)
	await _shot_at("04_earth_nina_back", at + Vector3(0, 1.0, -2.6), at + Vector3(0, 0.75, 0), 45.0)
	for i in kids.size():
		kids[i].global_position = Vector3(1.2 - i * 1.2, 0.03, -6.5)
		kids[i].global_rotation = Vector3(0, PI, 0)
	await _shot_at("05_earth_the_blastoffs", Vector3(0, 1.3, -10.6), Vector3(0, 0.95, -6.5), 50.0)


func _galaxity() -> void:
	# Melody and the plant girl in Galaxity, in the morning
	game.next_spawn = ""
	change_scene_to_file(TOWN)
	await _frames(8)
	clock.set_time(1, 9 * 60.0, true)
	await create_timer(1.0).timeout
	_hide_player()
	_new_cam()
	root.get_node("Tips").clear()
	game.message("")
	var melody := _npc("melody")
	var plant := _npc("plant_girl")
	for n in [melody, plant]:
		var r: Node = n.get_node_or_null("Routine")
		if r:
			r.process_mode = Node.PROCESS_MODE_DISABLED
		n.visible = true
	var spot := Vector3(66.0, 0.0, 4.0)
	spot.y = _ground(spot)
	melody.global_position = spot
	plant.global_position = spot + Vector3(1.4, 0, 0)
	plant.global_position.y = _ground(plant.global_position)
	for n in [melody, plant]:
		n.global_rotation = Vector3.ZERO
	await _shot_at("06_galaxity_melody_and_plant_girl", spot + Vector3(0.7, 1.3, 4.0), spot + Vector3(0.7, 0.9, 0), 45.0)
	await _shot_at("07_galaxity_melody_close", spot + Vector3(-0.1, 1.15, 1.8), spot + Vector3(0, 1.0, 0), 40.0)
	await _shot_at("08_galaxity_plant_girl_close", spot + Vector3(1.4, 1.35, 2.3), spot + Vector3(1.4, 1.15, 0), 45.0)
	var anim := melody.find_child("AnimationPlayer", true, false) as AnimationPlayer
	anim.play("dance")
	await _frames(12)
	await _shot_at("09_melody_dances", spot + Vector3(-0.1, 1.15, 2.6), spot + Vector3(0, 0.8, 0), 45.0)
	anim.play("idle")

	# The plant girl burrows: move her body a few metres the way her routine would and watch her go under and come up
	var burrower := plant.get_node_or_null("Burrower")
	if burrower:
		var from := plant.global_position
		var to := from + Vector3(5.0, 0, 0)
		cam.global_position = from + Vector3(2.5, 1.7, 6.0)
		cam.look_at(from + Vector3(2.5, 0.7, 0))
		cam.fov = 50.0
		await _frames(10)
		var mover := func() -> void:
			var d := to - plant.global_position
			d.y = 0.0
			var step := 2.0 * get_root().get_physics_process_delta_time()
			if d.length() > 0.01:
				plant.global_position += d.normalized() * minf(d.length(), step)
		physics_frame.connect(mover)
		await create_timer(0.3).timeout
		await _snap("10_plant_girl_burrows")
		await create_timer(0.8).timeout
		await _snap("11_plant_girl_underground")
		while plant.global_position.distance_to(Vector3(to.x, plant.global_position.y, to.z)) > 0.02:
			await physics_frame
		await create_timer(0.5).timeout
		await _snap("12_plant_girl_sprouts")
		physics_frame.disconnect(mover)
		await create_timer(1.0).timeout
		await _snap("13_plant_girl_up_again")
		(plant.find_child("AnimationPlayer", true, false) as AnimationPlayer).play("snap")
		await create_timer(0.55).timeout
		await _shot_at("14_plant_girl_snappy", to + Vector3(0.6, 1.4, 2.0), to + Vector3(0.3, 1.0, 0), 45.0)


func _npc(id: String) -> Node3D:
	for r in current_scene.find_children("Routine", "", true, false):
		if r.get("character_id") == id:
			return r.get_parent() as Node3D
	return null


func _ground(at: Vector3) -> float:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 20, 0), at + Vector3(0, -20, 0))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else at.y


func _hide_player() -> void:
	var player := current_scene.find_child("Player", true, false) as Node3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	player.global_position += Vector3(0, 0, 40)


func _new_cam() -> void:
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()


func _shot_at(file: String, from: Vector3, look: Vector3, fov: float) -> void:
	cam.make_current()
	cam.global_position = from
	cam.look_at(look)
	cam.fov = fov
	await create_timer(0.4).timeout
	await _frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _snap(file: String) -> void:
	# A shot straight away, from wherever the camera already is (for things that are moving)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
