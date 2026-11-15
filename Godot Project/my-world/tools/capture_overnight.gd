extends SceneTree

# Screenshots of the overnight polish (15 Nov 2026): the loading screen's tips and stars, the "!" over a neighbour
# with an errand, the errands' things round Stars Hollow (a song page, a book, a newt, a toy, a leaf pile before and
# after a jump). Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_overnight.gd -- <output folder> [loading]
#
# "loading" takes only the loading screen (for a before shot on an older build). Your own save and settings are put
# aside (under their own names) and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.overnight_capture_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.overnight_capture_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"

var out_dir := "user://overnight_shots"
var only_loading := false
var cam: Camera3D
var _had_save := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	only_loading = "loading" in args
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
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
	game.hero["name"] = "Sofi"
	root.get_node("Settings").tips = false
	var dialogue := root.get_node("Dialogue")
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	dialogue.set_flag("oak_woken")
	dialogue.set_flag("earth_crack_seen")
	dialogue.set_flag("cut_crack_earth")
	dialogue.set_flag("bb_thanked")
	dialogue.set_flag("fn_met_tally")
	root.get_node("Clock").set_earth_time(10 * 60.0, true)
	game.go(EARTH, "Entrance", "")
	await _frames(90)
	await create_timer(2.0).timeout

	# The loading screen, as it shows between worlds
	var loading := root.get_node("Loading")
	loading.show_for("res://scenes/town/town.tscn")
	await create_timer(0.8).timeout
	await _shot("01_loading_screen")
	loading.set("showing", false)
	(loading.get("_panel") as Control).visible = false
	if only_loading:
		_finish()
		return

	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	p.get_node("HUD").visible = false
	_cam_in(s)
	# The "!" over someone with an errand
	await create_timer(1.5).timeout
	var marked := get_nodes_in_group("errand_givers")
	var n := 2
	for t in marked:
		var who := str(t.get("character_id"))
		if not who in ["barnaby", "marigold", "otis"]:
			continue
		var mark := (t as Node).get_node_or_null("Errand Mark") as Node3D
		var at := (t as Node3D).global_position
		p.global_position = at + Vector3(0, 0.5, 4.0)
		await create_timer(0.8).timeout
		at = (t as Node3D).global_position
		var top := mark.global_position if mark else at + Vector3(0, 2.2, 0)
		_clear_view(at + Vector3(0, 1.2, 0), top)
		await _shot("%02d_errand_mark_%s" % [n, who])
		n += 1
	# The errands' things round town
	for id in ["errand_song", "errand_books", "errand_newts", "errand_toys", "errand_leaves"]:
		dialogue.set_flag(id + "_start")
	quests.check()
	await create_timer(1.0).timeout
	var holder := s.get_node("Home Calls")
	for k in [["song_1", "song_page"], ["book_1", "overdue_book"], ["newt_1", "newt"], ["toy_1", "runaway_toy"],
			["leaves_1", "leaf_pile"]]:
		var spot := holder.get_node_or_null("Home Spot " + str(k[0])) as Node3D
		if spot == null:
			continue
		p.global_position = spot.global_position + Vector3(0, 0.6, 3.0)
		await create_timer(0.6).timeout
		_look(spot.global_position + Vector3(1.8, 1.3, 2.4), spot.global_position + Vector3(0, 0.3, 0))
		await _shot("%02d_%s" % [n, k[1]])
		n += 1
		if str(k[0]) == "leaves_1":
			spot.call("use")
			await create_timer(1.0).timeout
			await _shot("%02d_leaf_pile_after_a_jump" % n)
			n += 1
	_finish()


func _cam_in(s: Node) -> void:
	cam = Camera3D.new()
	cam.fov = 55
	s.add_child(cam)
	cam.make_current()


func _clear_view(body: Vector3, top: Vector3) -> void:
	# Try round the person for a spot 5 m off where nothing's between the camera and them
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var best := body + Vector3(0, 1.5, 5)
	for i in 16:
		var a := TAU * i / 16.0
		var from := body + Vector3(sin(a) * 5.0, 1.4, cos(a) * 5.0)
		var q := PhysicsRayQueryParameters3D.create(from, body)
		q.collide_with_areas = false
		var q2 := PhysicsRayQueryParameters3D.create(from, top)
		q2.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if (hit.is_empty() or not hit.collider is StaticBody3D and not hit.collider is CSGShape3D) and space.intersect_ray(q2).is_empty():
			best = from
			break
	_look(best, (body + top) * 0.5)


func _look(from: Vector3, to: Vector3) -> void:
	cam.global_position = from
	cam.look_at(to, Vector3.UP)


func _frames(count: int) -> void:
	for i in count:
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
