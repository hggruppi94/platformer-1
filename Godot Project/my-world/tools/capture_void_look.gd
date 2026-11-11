extends SceneTree

# Screenshots of the hero's Void look (scripts/void_look.gd): the four alien features on girls and boys, front and
# back, the eye glow up close, the glow colours, the same hero on Earth and in the Void, and the creator's Void tab.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_void_look.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const VOID_LOOK := preload("res://scripts/void_look.gd")
const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const ROOM := "res://scenes/interiors/clothing_boutique.tscn"

var out_dir := "user://void_look_shots"
var cam: Camera3D
var row: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(240.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _hero(girl: bool, feature: String, glow: int, style := -1, skin := 0, hair := 4) -> Dictionary:
	var h := Hero.blank(girl)
	h.name = "Sam"
	h.void_feature = feature
	h.void_glow = glow
	if style >= 0:
		h.hairstyle = style
	h.colors = {"hair": hair}
	if skin > 0:
		h.colors["fur"] = skin
	return h


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.hold_saves = true
	game._resume = {}
	game.items.append("shop:shift_watch")
	change_scene_to_file(ROOM)
	for i in 6:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	p.global_position = Vector3(0, 0.85, 12.0)
	p.get_node("HUD").visible = false
	cam = Camera3D.new()
	cam.fov = 40
	current_scene.add_child(cam)
	var g := Hairstyles.GIRL_STYLES
	var b := Hairstyles.BOY_STYLES
	# Each feature on a girl and a boy, as on Earth (top) and in the Void
	var heroes := []
	var feats := VOID_LOOK.FEATURES
	for k in 4:
		heroes.append(_hero(k % 2 == 0, feats[k], k, (g if k % 2 == 0 else b)[k * 2], [1, 3, 22, 4][k], [4, 6, 11, 5][k]))
	await _lineup(heroes, "01_on_earth_as_made", false, 0.0)
	await _lineup(heroes, "02_in_the_void_front", true, 0.0)
	await _lineup(heroes, "03_in_the_void_back", true, PI)
	await _lineup(heroes, "04_in_the_void_side", true, PI / 2)
	# Every feature on the same girl, then the same boy
	heroes = []
	for f in feats:
		heroes.append(_hero(true, f, 0, g[1]))
	await _lineup(heroes, "05_girl_every_feature", true, 0.4)
	heroes = []
	for f in feats:
		heroes.append(_hero(false, f, 3, b[0]))
	await _lineup(heroes, "06_boy_every_feature", true, -0.4)
	# The six glow colours
	heroes = []
	for k in VOID_LOOK.GLOWS.size():
		heroes.append(_hero(k % 2 == 1, feats[k % 4], k, (b if k % 2 == 1 else g)[k + 2]))
	await _lineup(heroes, "07_every_glow_colour", true, 0.3)
	# Big hair: features still show
	heroes = []
	for s in [g[7], g[8], b[8], b[2]]:
		heroes.append(_hero(s in g, "horns", 0, s))
	await _lineup(heroes, "08_horns_with_big_hair", true, 0.3)
	# Up close: the eyes and the watch
	await _close_up(_hero(true, "antennae", 0, g[0]), "09_eyes_close_up", Vector3(0, 1.15, 1.0), Vector3(0, 1.12, 0))
	await _close_up(_hero(false, "ears", 2, b[1]), "10_watch_close_up", Vector3(0.9, 0.8, 0.6), Vector3(0.3, 0.6, 0))
	# The real game: the hero in the Void town and on Earth
	await _in_world("res://scenes/town/town.tscn", Vector3(-70, 0, 60), "11_in_the_void_town", _hero(true, "antennae", 0, g[0]))
	root.get_node("Clock").earth_minutes = 600.0             # (a sunny morning, at home where a new game starts)
	game.next_spawn = "HomeSpawn"
	await _in_world("res://scenes/earth/earth.tscn", Vector3.ZERO, "12_on_earth_same_hero", _hero(true, "antennae", 0, g[0]))
	# The creator's Void tab
	await _creator("13_creator_void_tab")
	_finish()


func _lineup(heroes: Array, file: String, on: bool, turn: float) -> void:
	if row:
		row.free()
	row = Node3D.new()
	current_scene.add_child(row)
	for k in heroes.size():
		var h: Dictionary = heroes[k]
		var m := (load(Hero.model_path(h)) as PackedScene).instantiate() as Node3D
		row.add_child(m)
		m.position = Vector3((k - (heroes.size() - 1) / 2.0) * (1.1 if heroes.size() <= 4 else 0.85), 0, 0)
		m.rotation.y = turn
		Hero.apply(m, h, {})
		VOID_LOOK.apply(m, h, {}, on)
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.play("idle")
	cam.make_current()
	cam.global_position = Vector3(0, 1.2, 5.6 if heroes.size() <= 4 else 6.4)
	cam.look_at(Vector3(0, 0.85, 0))
	await _shot(file)


func _close_up(h: Dictionary, file: String, from: Vector3, at: Vector3) -> void:
	await _lineup([h], file + "_full", true, 0.0)
	cam.global_position = from
	cam.look_at(at)
	await _shot(file)


func _in_world(scene: String, at: Vector3, file: String, h: Dictionary) -> void:
	if row:
		row.free()
		row = null
	var game := root.get_node("Game")
	game.hero = h
	game._resume = {}
	change_scene_to_file(scene)
	for i in 10:
		await process_frame
	var p := current_scene.find_child("Player", true, false) as Node3D
	if at != Vector3.ZERO:
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 80, at + Vector3.DOWN * 80)
		await physics_frame
		var hit := p.get_world_3d().direct_space_state.intersect_ray(ray)
		p.global_position = (hit.position if hit else at) + Vector3.UP * 0.1
	p.get_node("HUD").visible = false
	for i in 30:
		await process_frame
	var c := Camera3D.new()
	c.fov = 35
	current_scene.add_child(c)
	c.make_current()
	var vis := p.get_node("Visual") as Node3D
	vis.rotation.y = 0.5
	var front := Vector3(sin(0.5), 0, cos(0.5))
	c.global_position = p.global_position + front * 3.0 + Vector3(0.6, 1.2, 0)
	c.look_at(p.global_position + Vector3(0, 0.9, 0))
	await _shot(file)


func _creator(file: String) -> void:
	var creator := root.get_node("Creator")
	creator.open()
	for i in 4:
		await process_frame
	creator._tab = "Void"
	creator._fill()
	for i in 10:
		await process_frame
	await _shot(file)
	creator._tab = "Name"
	creator.close()


func _shot(file: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
