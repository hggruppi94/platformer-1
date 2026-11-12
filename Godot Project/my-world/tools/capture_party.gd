extends SceneTree

# Screenshots of the party system (scripts/party.gd, plan item 26): Bramble walking with you through the Void town,
# the card that says who's with you after Switch friend, Nina and Bruno following you round Shard Isle, and Flurry
# hopping in to freeze the lake; then the friend wheel, the friend badge on the HUD and the bubble that says Flurry
# could help by water. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_party.gd -- <output folder>
#
# Your own save and settings are put aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.party_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.party_capture_backup.cfg"

var out_dir := "user://party_shots"
var cam: Camera3D
var _had_save := false
var party: Node
var portals: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	party = root.get_node("Party")
	portals = root.get_node("Portals")
	portals.cleared_worlds.append_array(["rootmind", "frozen_moment", "rhythm_springs"])
	root.get_node("Dialogue").flags["make_taught"] = true
	for id in ["bramble", "melody", "flurry", "nina_bruno"]:
		party.join(id, true)
	party.with_you = "bramble"
	game.go("res://scenes/town/town.tscn", "", "")
	await _frames(24)
	await _town()
	await _card()
	await _lake()
	await _shard()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _walk(frames: int, dir := "move_forward") -> void:
	Input.action_press(dir)
	for i in frames:
		await physics_frame
	Input.action_release(dir)
	for i in 50:
		await physics_frame


func _side_cam(p: Node3D, other: Node3D, dist := 7.0) -> void:
	if cam == null or not is_instance_valid(cam):
		cam = Camera3D.new()
		cam.fov = 50
		current_scene.add_child(cam)
	var mid := (p.global_position + other.global_position) * 0.5
	var along := other.global_position - p.global_position
	along.y = 0.0
	var side := Vector3(-along.z, 0, along.x).normalized() if along.length() > 0.1 else Vector3.RIGHT
	cam.global_position = mid + side * dist + Vector3(0, 2.4, 0)
	cam.look_at(mid + Vector3(0, 0.9, 0), Vector3.UP)
	cam.make_current()
	await _frames(3)


func _town() -> void:
	var p := _player()
	p.global_position = Vector3(-70, 2, 48)
	await _walk(120)
	var bramble: Node3D = null
	for r in get_nodes_in_group("routines"):
		if r.character_id == "bramble":
			bramble = r.get_parent()
	if bramble:
		await _side_cam(p, bramble)
		await _shot("01_bramble_walks_with_you")
	if cam:
		cam.clear_current()


func _card() -> void:
	party.with_you = "flurry"
	party.switch()                                  # -> Heather isn't joined: next is Melody
	await _frames(3)                                # (the card only stays up 3.5 s, and a window with no GPU is slow)
	await _shot("02_switch_friend_card")
	party.open_wheel()
	party.wheel.point(party.wheel.slot_angle(party.wheel.slots.find("flurry")))
	await _frames(3)
	await _shot("06_friend_wheel")
	party.close_wheel(false)
	await _walk(90)
	for r in get_nodes_in_group("routines"):
		if r.character_id == "melody":
			await _side_cam(_player(), r.get_parent())
			await _shot("03_melody_tags_along")
	if cam:
		cam.clear_current()


func _lake() -> void:
	var p := _player()
	party.with_you = "bramble"
	var fb: Node = p.frost_breath
	var at := Vector3.INF
	for x in range(-60, 61, 3):
		for z in range(-40, 61, 3):
			if at == Vector3.INF and fb.water_under(float(x), float(z) - 6.0) != null and fb.water_under(float(x), float(z)) == null:
				at = Vector3(x, 3, z)
	if at == Vector3.INF:
		return
	p.global_position = at
	p.get_node("Visual").global_rotation.y = PI          # facing the water (-Z)
	await _frames(30)
	await _shot("07_badge_and_flurry_bubble")
	party.use(p)
	await _frames(40)
	var fol: Array = party.followers()
	if not fol.is_empty():
		await _side_cam(p, fol[0], 8.0)
	await _shot("04_flurry_hops_in_by_the_lake")
	if cam:
		cam.clear_current()


func _shard() -> void:
	party.with_you = "nina_bruno"
	root.get_node("Game").go("res://scenes/portal_worlds/shard_isle.tscn", "Entrance", "Shard Isle")
	await _frames(30)
	print("ON SHARD ISLE")
	await _walk(100)
	var fol: Array = party.followers()
	if fol.size() >= 2:
		await _side_cam(_player(), fol[1], 8.0)
	await _shot("05_nina_and_bruno_on_shard_isle")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	root.get_node("Game").hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	quit()
