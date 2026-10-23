extends SceneTree

# Draws the town map (res://ui/town_map.png) from the real town: a picture from straight above at midday, no fog,
# without people or sky. The map screen (scripts/map_screen.gd) puts the labels, Nina and markers on top, using
# res://ui/town_map.json to know which part of the town the picture covers. Re-run it after changing the town
# (tools/build_town.gd). Opens a window (pictures need rendering, so not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/make_map.gd
#   godot --headless --path "Godot Project/my-world" --import          (then import the new picture)
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const CENTER := Vector2(0, -75)                   # x, z of the middle of the map (the castle hill reaches z -248)
const SIZE_M := 370.0                             # metres across (it's square)
const PIXELS := 1024
const HIDE := ["Player", "Characters", "Sky Objects", "Enemies", "Sailboats", "WorldBounds", "Mountains", "Foliage"]


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(PIXELS, PIXELS))
	create_timer(120.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 6:
		await process_frame
	root.get_node("Clock").set_time(1, 12 * 60.0, true)
	var town := current_scene as Node3D
	(town.get_node("Player/HUD") as CanvasLayer).visible = false
	for n in HIDE:
		var node := town.get_node_or_null(n) as Node3D
		if node:
			node.visible = false
	# The map is wider than the town's ground: the far grass fills its edges, dropped below the lake bed so it can't
	# show through the water
	(town.get_node("Far Ground") as Node3D).position.y = -3.0
	var env := (town.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	var cam := Camera3D.new()
	town.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE_M
	cam.far = 600.0
	cam.global_position = Vector3(CENTER.x, 250, CENTER.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)                 # straight down, north (-z) at the top
	cam.make_current()
	await create_timer(2.0).timeout
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var side := mini(img.get_width(), img.get_height())
	var covers := SIZE_M * float(side) / img.get_height()      # the camera's size is its height in metres
	if img.get_width() != img.get_height():
		img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	img.resize(PIXELS, PIXELS, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("res://ui/town_map.png"))
	var f := FileAccess.open("res://ui/town_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"center": [CENTER.x, CENTER.y], "size_m": covers}, "  "))
	f.close()
	print("MAP ", ProjectSettings.globalize_path("res://ui/town_map.png"), " ", side, "px")
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
