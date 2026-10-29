extends SceneTree

# Screenshots of how the clothes fit everyone (scripts/clothes.gd): each hero body, secret ones too (with a hairstyle, so
# hats over hair show) and each friend who can be dressed, wearing five outfits that between them have every hat and
# every piece of clothing, from the front and the side. Each character also gets a contact sheet: the five outfits
# across, front on the top row and side below. Taken in an empty grey studio so nothing else gets in the way.
# Opens a window (not --headless):
#
#   godot --path "Godot Project/my-world" --script res://tools/capture_clothing_fit.gd -- <output folder> [who ...]
#
# Your own save is put aside and put back afterwards.

const SAVE := "user://save.json"
const BACKUP := "user://save.capture_backup.json"
const SHOT := Vector2i(480, 600)
const THUMB := Vector2i(320, 400)

# Five outfits that between them wear every hat and every piece (the restyles only recolour their own clothes, so
# one of each is enough)
const OUTFITS := [
	{"head": "propeller_cap", "face": "star_glasses", "neck": "cozy_scarf", "hands": "cozy_mittens", "back": "butterfly_wings", "top": "stripy_shirt"},
	{"head": "flower_crown", "face": "heart_shades", "neck": "bow_tie", "hands": "hero_gloves", "back": "super_cape", "bottoms": "tutu", "feet": "moon_boots"},
	{"head": "crystal_tiara", "face": "space_goggles", "neck": "crystal_necklace", "hands": "garden_gloves", "back": "jetpack", "top": "galaxy_tee", "feet": "rainbow_sneakers"},
	{"head": "headphones", "face": "star_glasses", "neck": "bow_tie", "bottoms": "tutu", "feet": "moon_boots", "top": "sunny_shirt"},
	{"head": "sk8_beanie", "face": "heart_shades", "neck": "cozy_scarf", "hands": "hero_gloves", "back": "super_cape", "bottoms": "mint_overalls", "feet": "sparkle_slippers"},
]
# The hero bodies wear a different hairstyle with each outfit: big ones, to show hair tucked under hats
const HERO_HAIR := [5, 8, 4, 7, 10]
const FRIEND_MODELS := {
	"nina": "res://models/characters/nina.glb", "dash": "res://models/characters/bike_boy.glb",
	"rook": "res://models/characters/rook.glb", "pip": "res://models/characters/moth_kid.glb",
	"bramble": "res://models/characters/cattle_girl.glb", "green_man": "res://models/characters/green_man.glb",
	"mr_palmer": "res://models/characters/mr_palmer_alien.glb", "rex": "res://models/characters/wolf.glb",
}

var out_dir := "user://clothing_fit_shots"
var only := []                # just these bodies and friends (after the folder), or everyone
var cam: Camera3D
var stage: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	only = args.slice(1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(SHOT)
	create_timer(600.0, true, false, true).timeout.connect(_finish)
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Game")._resume = {}
	var studio := Node3D.new()
	root.add_child(studio)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.64, 0.68)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.environment.ambient_light_energy = 0.6
	studio.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	sun.light_energy = 1.1
	studio.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, 2.6, 0)
	fill.light_energy = 0.45
	studio.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	studio.add_child(cam)
	cam.make_current()
	stage = Node3D.new()
	studio.add_child(stage)

	for body in Hero.BODY_ORDER + Hero.SECRET_ORDER:
		if not only.is_empty() and body not in only:
			continue
		await _character("hero_" + body, func(k: int) -> Node3D:
			var hero := Hero.blank()
			hero.body = body
			hero.hairstyle = HERO_HAIR[k]
			hero.colors = {"hair": 15}
			var m := (load(Hero.model_path(hero)) as PackedScene).instantiate() as Node3D
			stage.add_child(m)
			Hero.apply(m, hero, OUTFITS[k])
			return m)
	for who in FRIEND_MODELS:
		if not only.is_empty() and who not in only:
			continue
		await _character(who, func(k: int) -> Node3D:
			var m := (load(FRIEND_MODELS[who]) as PackedScene).instantiate() as Node3D
			m.scene_file_path = FRIEND_MODELS[who]
			stage.add_child(m)
			Clothes.dress(m, who, OUTFITS[k], {})
			return m)
	_finish()


func _character(name: String, make: Callable) -> void:
	# Five outfits, front and side, and a contact sheet of all ten
	var sheet := Image.create(THUMB.x * OUTFITS.size(), THUMB.y * 2, false, Image.FORMAT_RGBA8)
	for k in OUTFITS.size():
		var m: Node3D = make.call(k)
		for i in 3:
			await process_frame
		for v in 2:
			m.rotation.y = 0.0 if v == 0 else PI / 2          # the side view: facing to the right of the picture
			await process_frame
			var box := _bounds(m)
			var h := maxf(box.size.y, box.size.x * SHOT.y / SHOT.x) * 1.08
			cam.size = h
			var mid := box.get_center()
			cam.global_position = mid + Vector3(0, 0, 6)
			cam.look_at(mid)
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var file := "%s_%d_%s.png" % [name, k + 1, "front" if v == 0 else "side"]
			img.save_png(out_dir.path_join(file))
			img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, THUMB), Vector2i(k * THUMB.x, v * THUMB.y))
		m.free()
	sheet.save_png(out_dir.path_join("sheet_%s.png" % name))
	print("SHOT ", name)


func _bounds(model: Node3D) -> AABB:
	# Everything they're wearing included, in the world (they stand at the middle of the stage)
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit()
