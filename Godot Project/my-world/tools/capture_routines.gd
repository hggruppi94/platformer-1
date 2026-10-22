extends SceneTree

# Screenshots of people going about their day (scripts/routine.gd): Rex's morning skate with Rook tagging along,
# Bramble in the gardens, Rex campaigning, Dash on his rounds, an afternoon by the water, Pip at the lamps, Rook
# grumbling at night, and the Green Man at the portal in the Shift. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_routines.gd -- <output folder>
#
# The folder defaults to user://routine_shots. Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FAR_AWAY := Vector3(-140, 2, 100)            # the empty southwest corner, far from everyone's places

var out_dir := "user://routine_shots"
var clock: Node
var game: Node
var cam: Camera3D
var player: Node3D
var routines := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_run.call_deferred()


func _run() -> void:
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame

	await _shot("01_morning_rex_skates_rook_follows", "08:00", "rex", Vector3(7, 3.5, 8))
	await _shot("02_morning_bramble_gardening", "09:00", "bramble", Vector3(-6, 4, 9))
	await _shot("03_rex_campaigning_at_town_hall", "11:00", "rex", Vector3(-5, 3, 9))
	await _shot("04_dash_on_his_rounds", "11:20", "dash", Vector3(7, 3, 7), 4.0)
	await _shot("05_afternoon_bramble_by_the_water", "14:00", "bramble", Vector3(-7, 3, 6))
	await _shot("06_rook_napping", "14:00", "rook", Vector3(4, 2.5, 6))
	await _shot("07_dusk_pip_at_the_lamps", "20:00", "pip", Vector3(6, 3, -6))
	await _shot("08_night_rook_grumbling_at_dashs_house", "22:30", "rook", Vector3(6, 3.5, 7))
	await _shot("09_shift_green_man_at_the_portal", "00:20", "green_man", Vector3(-7, 3, -4))

	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()


func _shot(file: String, time: String, who: String, offset: Vector3, wait := 2.5) -> void:
	# Nina far off, so everyone is simply where their schedule says; then look at `who` from `offset`
	await _in_town()
	player.global_position = FAR_AWAY
	clock.set_time(2, clock.parse_time(time), true)
	await create_timer(wait).timeout
	var body := routines[who].get_parent() as Node3D
	var at := body.global_position
	# From `offset`, or the first angle round them with nothing (a tree trunk, a wall) in the way
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for n in current_scene.find_children("*", "CollisionObject3D", true, false):
		if str(n.get_path()).contains("/Characters/") or n is Area3D or n is CharacterBody3D:
			skip.append((n as CollisionObject3D).get_rid())
	var from := at + offset
	for k in 12:
		var o := offset.rotated(Vector3.UP, k * TAU / 12.0)
		var q := PhysicsRayQueryParameters3D.create(at + o, at + Vector3(0, 0.9, 0))
		q.exclude = skip
		if space.intersect_ray(q).is_empty():
			from = at + o
			break
	cam.global_position = from
	cam.look_at(at + Vector3(0, 0.9, 0))
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file, "  ", clock.call("time_string"), "  ", routines[who].activity())


func _in_town() -> void:
	# Look everyone up again, in case something reloaded the town
	if current_scene == null or current_scene.scene_file_path != TOWN:
		print("NOTE left town (%s), going back" % (current_scene.scene_file_path if current_scene else "none"))
		change_scene_to_file(TOWN)
		for i in 5:
			await process_frame
	player = current_scene.find_child("Player", true, false)
	routines.clear()
	for r in get_nodes_in_group("routines"):
		routines[r.character_id] = r
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		cam = Camera3D.new()
		cam.fov = 62
		current_scene.add_child(cam)
	cam.make_current()
