extends SceneTree

# Screenshots of face sculpting (scripts/face_sculpt.gd): for every body, a row of heads close up with the sculpt
# sliders pushed to their ends (eyes, eye spacing, nose, ears, mouth), and a row of the ready-made face sculpts.
# Lineups in the Clothing Boutique. Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_faces.gd -- <output folder> [body ...]
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const ROOM := "res://scenes/interiors/clothing_boutique.tscn"

var out_dir := "user://face_shots"
var only := []
var cam: Camera3D
var row: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	only = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(300.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Game")._resume = {}
	change_scene_to_file(ROOM)
	for i in 6:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(0, 0.85, 8.0)
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 40
	current_scene.add_child(cam)
	var n := 0
	for b in Hero.BODY_ORDER + Hero.SECRET_ORDER:
		if not only.is_empty() and b not in only:
			continue
		n += 1
		# The sliders at their ends
		var heroes := []
		for s in [{}, {"eyes": 2.3}, {"eyes": 0.45, "eye_gap": 1.6}, {"nose": 3.0}, {"ears": 3.0}, {"mouth": 2.2}]:
			var h := Hero.blank()
			h.body = b
			h.hairstyle = 0
			h.merge(s, true)
			heroes.append(h)
		await _lineup(heroes, "%02d_%s_sliders" % [n, b])
		# The ready-made sculpts
		heroes = []
		for i in FaceSculpt.PRESETS.size():
			var h := Hero.blank()
			h.body = b
			h.hairstyle = 0
			FaceSculpt.apply_preset(h, i)
			heroes.append(h)
		await _lineup(heroes, "%02d_%s_presets" % [n, b])
	_finish()


func _lineup(heroes: Array, file: String) -> void:
	if row:
		row.free()
	row = Node3D.new()
	current_scene.add_child(row)
	var gap := 0.72
	for k in heroes.size():
		var h: Dictionary = heroes[k]
		var m := (load(Hero.model_path(h)) as PackedScene).instantiate() as Node3D
		row.add_child(m)
		m.position = Vector3((k - (heroes.size() - 1) / 2.0) * gap, 0, 0)
		Hero.apply(m, h, {})
	var width := heroes.size() * gap
	cam.make_current()
	cam.global_position = Vector3(0, 1.2, width * 0.82 + 0.4)
	cam.look_at(Vector3(0, 1.05, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
