extends SceneTree

# Screenshots of what the character creator can make (scripts/hero.gd): every hairstyle on a hippo, every body type,
# body shapes, a row of random heroes ("Surprise me"), and every body as drawn (the secret dog-kid last). Lineups of
# models in the Clothing Boutique.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_hero.gd -- <output folder>
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const ROOM := "res://scenes/interiors/clothing_boutique.tscn"

var out_dir := "user://hero_shots"
var cam: Camera3D
var row: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	create_timer(150.0, true, false, true).timeout.connect(_finish)
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
	seed(4)

	# Every hairstyle, on a hippo with blonde hair
	var heroes := []
	for k in Hairstyles.NAMES.size():
		var h := Hero.blank()
		h.hairstyle = k
		h.colors = {"hair": 11}
		heroes.append(h)
	await _lineup(heroes.slice(0, 6), "01_hairstyles_a")
	await _lineup(heroes.slice(6), "02_hairstyles_b")
	# Every body, with a ponytail
	heroes = []
	for b in Hero.BODY_ORDER:
		var h := Hero.blank()
		h.body = b
		h.hairstyle = 3
		heroes.append(h)
	await _lineup(heroes, "03_bodies_with_a_ponytail")
	# Body shapes: small, as drawn, tall; big head; wide
	heroes = []
	for s in [{"height": 0.85}, {}, {"height": 1.15}, {"head": 1.2}, {"build": 1.2}, {"build": 0.85, "head": 0.85}]:
		var h := Hero.blank()
		h.merge(s, true)
		heroes.append(h)
	await _lineup(heroes, "04_body_shapes")
	# Surprise me!
	heroes = []
	for k in 6:
		heroes.append(Hero.random())
	await _lineup(heroes, "05_surprise_me")
	# Every body as drawn, their own hair, with the secret one at the end
	heroes = []
	for b in Hero.BODY_ORDER + Hero.SECRET_ORDER:
		var h := Hero.blank()
		h.body = b
		h.hairstyle = 0
		heroes.append(h)
	await _lineup(heroes, "06_every_body")
	_finish()


func _lineup(heroes: Array, file: String) -> void:
	if row:
		row.free()
	row = Node3D.new()
	current_scene.add_child(row)
	for k in heroes.size():
		var h: Dictionary = heroes[k]
		var m := (load(Hero.model_path(h)) as PackedScene).instantiate() as Node3D
		row.add_child(m)
		m.position = Vector3((k - (heroes.size() - 1) / 2.0) * (1.15 if heroes.size() <= 6 else 0.8), 0, 0)
		Hero.apply(m, h, {})
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation("idle"):
			ap.play("idle")
	cam.make_current()
	cam.global_position = Vector3(0, 1.3, 7.2 if heroes.size() <= 6 else 7.6)
	cam.look_at(Vector3(0, 0.85, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(file + ".png"))
	print("SHOT ", file)


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
