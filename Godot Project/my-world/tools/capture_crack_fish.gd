extends SceneTree

# Screenshots for the 14 Nov 2026 notes: standing on a crack with its "Press E to jump in" prompt (no more falling in),
# a rare fish swimming down in the Wishing Well, the eight rare fish side by side, and the Aquarium with every tank
# full. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_crack_fish.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.crackfish_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.crackfish_capture_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var out_dir := "user://crack_fish_shots"
var cam: Camera3D
var _had_save := false
var portals: Node
var game: Node
var fish: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Settings").tips = false
	portals = root.get_node("Portals")
	fish = root.get_node("Watches/Fish")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs", "far_future"]:
		portals.quakes.append(w)
		portals.cleared_worlds.append(w)
	change_scene_to_file(TOWN)
	await _frames(30)
	await create_timer(2.0).timeout
	await _crack()
	await _well()
	await _lineup()
	await _aquarium()
	_finish()


func _player() -> CharacterBody3D:
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	return p


func _crack() -> void:
	var g := current_scene.get_node("Portals/Portal shard_isle") as Node3D
	var p := _player()
	p.global_position = g.global_position + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await create_timer(1.5).timeout
	_cam_in(current_scene)
	_look(g.global_position + g.global_basis.z * 5.5 + Vector3(0, 2.6, 0), g.global_position + Vector3(0, 1.0, 0))
	await _frames(4)
	await _shot("01_standing_on_a_crack_press_e_to_jump_in")
	_look(g.global_position + g.global_basis.x * 6.0 + Vector3(0, 4.0, 0), g.global_position)
	await _shot("02_standing_on_it_from_the_side")


func _well() -> void:
	var p := _player()
	var at: Vector2 = fish.spot_of(fish.fish("wishfin"))
	p.global_position = Vector3(at.x + 9.0, 4.0, at.y + 9.0)
	await create_timer(2.0).timeout
	var g := current_scene.find_child("Rare Fish wishfin", true, false) as Node3D
	if g == null:
		print("no wishfin")
		return
	var mid: Vector3 = g.get_meta("middle")
	_look(mid + Vector3(2.6, 0.9, 2.2), mid + Vector3(0, -0.3, 0))
	await create_timer(0.5).timeout
	await _shot("03_wishfin_down_in_the_wishing_well")
	await create_timer(1.3).timeout
	_look(g.global_position + Vector3(1.6, 0.2, 0.4), g.global_position)
	await _shot("04_wishfin_up_close")


func _lineup() -> void:
	# All eight side by side on a plain floor, high over the Void
	var holder := Node3D.new()
	current_scene.add_child(holder)
	holder.global_position = Vector3(0, 60, -200)
	var floor := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(12, 0.1, 4)
	floor.mesh = b
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.35, 0.5)
	floor.material_override = fm
	floor.position.y = -0.6
	holder.add_child(floor)
	var light := OmniLight3D.new()
	light.omni_range = 14
	light.light_energy = 2.0
	light.position = Vector3(0, 3, 3)
	holder.add_child(light)
	for i in fish.FISH.size():
		var m: Node3D = fish.model(fish.FISH[i], 1.3)
		holder.add_child(m)
		m.position = Vector3(-5.25 + i * 1.5, 0, 0)
		m.rotation.y = -PI / 2 + 0.35
		var tag := Label3D.new()
		tag.text = str(fish.FISH[i].name)
		tag.font_size = 32
		tag.pixel_size = 0.006
		tag.outline_size = 8
		tag.position = m.position + Vector3(0, -0.45, 0.6)
		holder.add_child(tag)
	_look(holder.global_position + Vector3(0, 1.4, 6.2), holder.global_position + Vector3(0, -0.1, 0))
	await _frames(6)
	await _shot("05_the_eight_rare_fish")
	holder.queue_free()


func _aquarium() -> void:
	for f in fish.FISH:
		root.get_node("Dialogue").set_flag("fish_" + str(f.id))
	change_scene_to_file(fish.AQUARIUM)
	await _frames(30)
	await create_timer(2.0).timeout
	var p := _player()
	_cam_in(current_scene)
	var s := current_scene as Node3D
	p.global_position = s.global_position + Vector3(0, 0.9, 8.0)
	_look(s.global_position + Vector3(0, 4.5, 10.5), s.global_position + Vector3(0, 1.8, -4))
	await create_timer(0.5).timeout
	await _shot("06_the_aquarium_every_tank_full")
	var tank := s.find_child("Tank 3", true, false) as Node3D
	if tank:
		var inward := (s.global_position - tank.global_position) * Vector3(1, 0, 1)
		_look(tank.global_position + inward.normalized() * 3.4 + Vector3(0, 2.0, 0), tank.global_position + Vector3(0, 1.8, 0))
		await _shot("07_a_rare_fish_in_its_tank")


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
