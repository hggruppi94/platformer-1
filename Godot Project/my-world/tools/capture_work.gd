extends SceneTree

# Pictures of people really doing their jobs (scripts/work_job.gd, routines/jobs.json): Miss Marigold up the library
# ladder, Poppy kneading and at the oven, Gus with his deliveries, Kip washing the fire truck, Bramble at her beds and
# her stall, Pip lighting the Market's lamps, and the rest. Two shots a job, each taken once they're at it. Opens a
# window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_work.gd -- <output folder> [only]
#
# Pass a job's id (or part of a shot's name) as "only" to take just those. Your own save is put aside and put back.

const WORK_JOB := preload("res://scripts/work_job.gd")
const SAVE := "user://save.json"
const BACKUP := "user://save.capture_work_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

# Who does each job, and the hour they're at it (Earth's clock, or the Void's)
const EARTH_JOBS := {
	"librarian": ["marigold", 10.25], "baker": ["poppy", 10.25], "toymaker": ["otis", 10.25],
	"hall_keeper": ["palmer_earth", 10.25], "diner_cook": ["gus", 10.25], "waitress": ["ivy", 10.25],
	"hardware": ["hank", 10.25], "truck_wash": ["kip", 10.25], "innkeeper": ["dottie", 10.25],
	"bookseller": ["lionel", 10.25], "antiques": ["wren", 10.25], "grocer": ["kip", 7.0],
}
const VOID_JOBS := {
	"garden_beds": ["bramble", 8.0], "flower_stall": ["bramble", 13.0], "lamplighter": ["pip", 19.3],
}

var out_dir := "user://work_shots"
var only := ""
var cam: Camera3D
var clock: Node
var game: Node
var n := 0
var minimap_was := true
var tips_was := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	create_timer(900.0, true, false, true).timeout.connect(_finish)
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	minimap_was = root.get_node("Settings").minimap
	tips_was = root.get_node("Settings").tips
	root.get_node("Settings").minimap = false          # (only while this runs: put back at the end, never saved)
	root.get_node("Settings").tips = false
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Dialogue").reset()
	root.get_node("Quests").reset()
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.day = 1                                       # a Friday: a working day, no fair
	clock.calendar_offset = clock.CALENDAR_START
	clock.set_earth_time(10 * 60.0 + 15.0, true)
	await _open(EARTH, Vector3(80, 1, 95))
	for job in EARTH_JOBS:
		await _job_shots(job, EARTH_JOBS[job][0], EARTH_JOBS[job][1], false)
	clock.set_time(1, 8 * 60.0, true)
	await _open(TOWN, Vector3(150, 30, 150))
	for job in VOID_JOBS:
		await _job_shots(job, VOID_JOBS[job][0], VOID_JOBS[job][1], true)
	_finish()


func _open(scene: String, player_at: Vector3) -> void:
	change_scene_to_file(scene)
	for i in 8:
		await process_frame
	await create_timer(1.0).timeout
	var player := current_scene.find_child("Player", true, false) as Node3D
	(player.get_node("HUD") as CanvasLayer).visible = false
	player.global_position = player_at
	cam = Camera3D.new()
	cam.far = 1500.0
	current_scene.add_child(cam)
	cam.make_current()


func _job_shots(job_id: String, who: String, hour: float, void_side: bool) -> void:
	if only != "" and not job_id.contains(only):
		return
	if void_side:
		clock.set_time(1, hour * 60.0, true)
	else:
		clock.set_earth_time(hour * 60.0, true)
	clock.running = false
	for i in 6:
		await physics_frame
	var r: Node = null
	for rr in current_scene.get_tree().get_nodes_in_group("routines"):
		if str(rr.character_id) == who:
			r = rr
	var job = r.get("_job") if r else null
	if job == null or str(job.id) != job_id:
		print("NOT AT WORK ", job_id, " (", who, ")")
		clock.running = true
		return
	# The first step they do something at, the one halfway round, and the ladder (the librarian's whole point)
	var posed := []
	for k in job.steps.size():
		if (job.steps[k] as Dictionary).has("pose"):
			posed.append(k)
	var picks := [posed[0], posed[posed.size() / 2]]
	for k in job.steps.size():
		if (job.steps[k] as Dictionary).has("climb"):
			picks = [k] + picks
	picks = picks.reduce(func(acc: Array, v) -> Array: return acc if v in acc else acc + [v], [])
	# Let them go round in order (so they're carrying what they would be), quickly, until they're at each pick
	for k in picks:
		Engine.time_scale = 5.0
		var climbs := (job.steps[k] as Dictionary).has("climb")
		for i in 60 * 60:
			await physics_frame
			if job.step == k and job.state == WORK_JOB.DO and job.t > 0.6 and (not climbs or job.up > 0.9):
				break
		Engine.time_scale = 1.0
		await create_timer(0.3).timeout
		var file := "%02d_%s_%d_%s" % [n, job_id, k + 1, str(job.steps[k].get("pose", ""))]
		await _shoot(file + "_a", r.get_parent() as Node3D, job, -1.0)
		await _shoot(file + "_b", r.get_parent() as Node3D, job, 1.0)
		n += 1
	clock.running = true


func _shoot(file: String, body: Node3D, job, front: float) -> void:
	# From behind one shoulder (front -1), so we see them and what they're working at, or from the front at the other
	# side (front 1), to see their face; pulled in if a wall or a shelf is in the way
	var face := body.global_transform.basis.z           # (models face +Z)
	face.y = 0
	face = face.normalized() if face.length() > 0.1 else Vector3.FORWARD
	var head := body.global_position + Vector3.UP * (1.0 + float(job.up))
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	# Try a few angles round them (behind or in front, either side) and take the one with the most room
	var want := head
	var room := -1.0
	for deg in [35.0, -35.0, 60.0, -60.0, 15.0, -15.0]:
		var dir := face.rotated(Vector3.UP, deg_to_rad(deg)) * front
		var to := head + dir * 2.4 + Vector3.UP * 0.4
		var q := PhysicsRayQueryParameters3D.create(head, to)
		q.exclude = TownPaths.skip_rids(current_scene)
		var hit: Dictionary = space.intersect_ray(q)
		var d := head.distance_to(Vector3(hit.position)) * 0.85 if hit else head.distance_to(to)
		if d > room + 0.3:
			room = d
			want = head + (to - head).normalized() * d
	cam.global_position = want
	cam.look_at(head - Vector3.UP * 0.35 + face * (0.5 if front < 0 else 0.0))
	cam.fov = 62.0
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	Engine.time_scale = 1.0
	root.get_node("Settings").minimap = minimap_was
	root.get_node("Settings").tips = tips_was
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	print("DONE ", ProjectSettings.globalize_path(out_dir))
	quit()
