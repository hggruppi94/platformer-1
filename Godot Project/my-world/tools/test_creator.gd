extends SceneTree

# Checks the player's own hero (scripts/hero.gd, scripts/creator.gd) and house (scripts/home_decor.gd): a new game
# needs the creator and starts at home, the creator changes the body, hairstyle, colours, size and name and won't
# close without a name, "Surprise me" keeps the name, the hero saves and loads, an old save from before heroes asks
# for one and keeps its outfit, turning the hero (mouse or stick) keeps the mouse and leaves the camera alone, the
# wardrobe opens the creator, the Face tab sculpts eyes, noses, ears and mouths and picks ready-made faces, the
# dog-kid is a secret found by finishing Rook's skate lesson, New Game while it's open starts cleanly (and asks again after a quit), dialogue says the player's name and pronouns, the house's Decorate spot changes the
# colours and furniture (and they save), and Nina is a friend in town with things to say.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_creator.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const HOUSE := "res://scenes/interiors/my_house.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var windowed := DisplayServer.get_name() != "headless"   # headless Godot can't grab the mouse, so mouse modes are only checked with a window
var game: Node
var creator: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	creator = root.get_node("Creator")
	dialogue = root.get_node("Dialogue")

	# --- A new game: no hero yet, wakes up at home on Earth ---
	game.hero = Hero.blank()
	game.needs_creator = true
	game.home = {}
	game._resume = {}
	game.next_spawn = "HomeSpawn"
	change_scene_to_file(EARTH)
	await _frames(6)
	check(ProjectSettings.get_setting("application/run/main_scene") == EARTH, "the game starts at home on Earth")
	var p := current_scene.find_child("Player", true, false) as Node3D
	check(p.get("rider") == "hero" and (p.get("model") as Node3D).name == "Hero", "the player is their own hero")

	# --- The creator ---
	creator.open(true)
	await _frames(2)
	check(creator.is_open() and p.get("input_locked"), "the creator opens, and the hero waits while it's open")
	game.hero["body"] = "hippo"
	creator.step_body(1)
	await _frames(2)
	var model := p.get("model") as Node3D
	check(game.hero.body == "kid" and model.scene_file_path == Hero.BODIES.kid.model, "the body arrows change the body")
	creator.set_value("hairstyle", 3)
	await _frames(2)
	model = p.get("model") as Node3D
	var hair := false
	for h in model.find_children("Clothes *", "BoneAttachment3D", true, false):
		if h.get_child_count() > 0 and h.get_child(0).name == "Hairstyle":
			hair = true
	check(hair, "picking a hairstyle puts it on their head")
	creator.set_color("fur", 15)
	await _frames(2)
	var skin := Clothes._surfaces(Clothes._body(model), ["Skin"])
	var fur := Clothes._body(model).get_surface_override_material(skin[0]) as StandardMaterial3D
	check(fur != null and fur.albedo_color.is_equal_approx(Hero.SWATCHES[14]), "a colour swatch recolours their fur")
	creator.set_value("height", 1.15)
	await _frames(2)
	check(is_equal_approx(model.scale.y, 1.15), "the height slider makes them taller")

	# --- Face sculpting ---
	creator._tab = "Face"
	creator._fill()
	await _frames(1)
	for key in ["eyes", "eye_gap", "nose", "ears", "mouth"]:
		check(creator._content.find_child("Slider " + key, true, false) != null, "the Face tab has a %s slider" % key)
	var body_mesh := Clothes._body(model)
	var wide := _head_width(body_mesh.mesh)
	creator.set_value("ears", 2.8)
	await _frames(2)
	model = p.get("model") as Node3D
	body_mesh = Clothes._body(model)
	check(body_mesh.mesh != body_mesh.get_meta("unsculpted") and _head_width(body_mesh.mesh) > wide + 0.1,
		"the ears slider makes their ears much bigger")
	check(body_mesh.skin != null and body_mesh.mesh.get_surface_count() == (body_mesh.get_meta("unsculpted") as Mesh).get_surface_count(),
		"...on a copy of their body that's still skinned, part for part")
	var nose_parts := Clothes._surfaces(body_mesh, ["Nose"])
	var nose_before := _part_box(body_mesh.get_meta("unsculpted"), nose_parts[0])
	creator.set_value("nose", 3.0)
	await _frames(2)
	body_mesh = Clothes._body(p.get("model"))
	check(_part_box(body_mesh.mesh, nose_parts[0]).size.x > nose_before.size.x * 2.5, "the nose slider goes up to a huge nose")
	creator.step_face(1)
	check(FaceSculpt.preset_index(game.hero) == 0, "the Face arrows go from a face of their own to the first ready-made one")
	creator.step_face(1)
	check(FaceSculpt.preset_index(game.hero) == 1 and is_equal_approx(float(game.hero.eyes), FaceSculpt.PRESETS[1].eyes),
		"the Face arrows pick a ready-made face (%s)" % FaceSculpt.PRESETS[1].name)
	creator.step_face(-1)
	await _frames(2)
	body_mesh = Clothes._body(p.get("model"))
	check(FaceSculpt.preset_index(game.hero) == 0 and body_mesh.mesh == body_mesh.get_meta("unsculpted"),
		"...and \"As drawn\" puts their own face back")
	var alien := Hero.BODIES.alien.face as Dictionary
	check(not FaceSculpt.has_feature(alien, "ears") and FaceSculpt.has_feature(alien, "eyes"), "a body with no ears has no ears slider")

	# --- Secret bodies: the dog-kid gets about on all fours, so it's found, not picked ---
	dialogue.flags.erase("skate_lesson_done")
	game.items.erase("secret:dog")
	var seen := []
	for i in Hero.BODY_ORDER.size() + 2:
		creator.step_body(1)
		seen.append(game.hero.body)
	check("dog" not in seen and "dog" not in Hero.BODY_ORDER, "the dog-kid isn't in the list of bodies until it's found")
	creator._tab = "Body"
	creator._fill()
	var hint := false
	for l in creator._content.find_children("*", "Label", true, false):
		if "Coach Rook" in (l as Label).text:
			hint = true
	check(hint, "...and the Body tab gives a hint for finding it")
	dialogue.set_flag("skate_lesson_done")
	await _frames(3)
	check(game.has_item("secret:dog") and "dog" in Hero.choices(game.hero), "finishing Rook's skate lesson finds the dog-kid")
	seen = []
	for i in Hero.choices(game.hero).size():
		creator.step_body(1)
		seen.append(game.hero.body)
	check("dog" in seen, "...which the body arrows then reach")
	dialogue.flags.erase("skate_lesson_done")
	check(Hero.found("dog"), "...and it stays found")
	game.hero["body"] = "kid"
	creator.step_body(0)
	await _frames(2)
	game.hero["name"] = ""
	creator.close()
	check(creator.is_open() and creator._tab == "Name", "it won't close without a name, and goes to the Name tab")
	game.hero["name"] = "Luna"
	creator.set_value("pronouns", "she")
	creator.surprise()
	check(game.hero.name == "Luna" and game.hero.pronouns == "she", "Surprise me keeps their name and pronouns")
	creator.close()
	await _frames(2)
	check(not creator.is_open() and not game.needs_creator and not p.get("input_locked"), "Done closes it and they can move")

	# --- Their name in dialogue ---
	check(dialogue._fill("Hi, {player}! {They} said {their} name.") == "Hi, Luna! She said her name.",
		"dialogue says their name and pronouns")

	# --- Saving and loading ---
	var made: Dictionary = game.hero.duplicate(true)
	game.save_game()
	game.hero = Hero.blank()
	game.load_game()
	check(game.hero.name == "Luna" and game.hero.body == made.body and not game.needs_creator, "the hero saves and loads")
	# An old save, from before heroes: Nina's outfit becomes theirs, and they get to make a hero
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("hero")
	data["outfits"] = {"nina": {"face": "star_glasses"}}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.needs_creator and game.outfits.get("hero", {}).get("face") == "star_glasses", "an old save asks for a hero and keeps its outfit")
	game.hero = made
	game.needs_creator = false

	# --- Decorating the house ---
	change_scene_to_file(HOUSE)
	await _frames(6)
	var shop := root.get_node("Shop")
	shop.open("Decorate")
	game.home = {}
	shop.decorate("spot2", 1)
	shop.decorate("walls", 2)
	shop.close()
	await _frames(2)
	var spot := current_scene.get_node("Decor/spot2") as Node3D
	var shown := []
	for c in spot.get_children():
		if (c as Node3D).visible:
			shown.append(String(c.name))
	check(shown == ["Item toy_chest"], "the Decorate arrows change what's in a spot (%s)" % [shown])
	check(int(game.home.walls) == 2, "...and the wall colour")
	var walls := (current_scene as Node).get("_mats").get("walls") as StandardMaterial3D
	check(walls != null and walls.albedo_color.is_equal_approx(current_scene.COLORS.walls[2]), "...which the walls show")
	game.save_game()
	game.home = {}
	game.load_game()
	check(game.home.get("spot2") == "toy_chest" and int(game.home.walls) == 2, "the decorating saves")

	# --- Nina is a friend in town ---
	game.next_spawn = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	var nina := current_scene.find_child("Nina", true, false) as Node3D
	check(nina != null and nina.get_node("Talk").get("character_id") == "nina", "Nina lives in town now, and can be talked to")
	var first: Array = dialogue.pick_conversation("nina")
	check(first.size() > 0, "...with things to say")
	check(current_scene.find_child("My House", true, false) != null, "the town has My House, apart from Nina's")

	# --- Turning the hero keeps the mouse (it used to vanish: a click in the world grabbed it for the camera) ---
	var pause := root.get_node("PauseMenu")
	p = current_scene.find_child("Player", true, false) as Node3D
	var visual := p.get_node("Visual") as Node3D
	var arm := p.find_child("SpringArm3D", true, false) as Node3D
	creator.open()
	await _frames(2)
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "the creator shows the mouse")
	var probe := ClickProbe.new()
	current_scene.add_child(probe)
	var yaw := visual.rotation.y
	var arm_yaw := arm.rotation.y
	var at := Vector2(root.get_visible_rect().size.x * 0.75, root.get_visible_rect().size.y * 0.5)
	_mouse_button(at, true)
	for i in 5:
		var move := InputEventMouseMotion.new()
		move.position = at + Vector2(20 * (i + 1), 0)
		move.relative = Vector2(20, 0)
		root.push_input(move)
	_mouse_button(at + Vector2(100, 0), false)
	await _frames(2)
	check(not is_equal_approx(visual.rotation.y, yaw), "dragging the mouse turns the hero round")
	check(probe.clicks == 0, "...and the drag's clicks don't reach the game camera, which would grab the mouse")
	check(not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "...and the mouse stays visible after turning them")
	probe.queue_free()
	check(is_equal_approx(arm.rotation.y, arm_yaw), "...and the game camera behind doesn't turn")
	# The controller's right stick turns them too, and not the camera
	yaw = visual.rotation.y
	Input.action_press("look_right")
	await _frames(5)
	Input.action_release("look_right")
	check(visual.rotation.y > yaw + 0.01 and is_equal_approx(arm.rotation.y, arm_yaw), "the right stick turns the hero, not the camera")
	# Pausing and resuming gives the mouse back to the creator
	pause.open()
	pause.close()
	check(creator.is_open() and (not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE), "resuming from the pause menu keeps the creator's mouse")
	var player_cam := arm.get_node("Camera3D") as Camera3D
	creator.close()
	await _frames(2)
	check(not creator.is_open() and player_cam.current and (not windowed or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),
		"Done goes back to the game camera and grabs the mouse again")

	# --- The wardrobe opens the creator ---
	var shop2 := root.get_node("Shop")
	shop2.open("Wardrobe")
	await _frames(2)
	var remake := shop2._rows.find_child("Button remake", true, false) as Button
	check(remake != null, "the wardrobe has a button to change your hero")
	if remake:
		remake.pressed.emit()
		await _frames(2)
		check(creator.is_open() and not shop2.is_open() and not paused, "...which closes the wardrobe and opens the creator")
		creator.close()
		await _frames(2)
		check(not creator.is_open() and player_cam.current and not p.get("input_locked"), "...and Done goes back to the game")

	# --- New Game from the pause menu while making a hero ---
	creator.open()
	await _frames(2)
	pause.open()
	pause.close()
	game.new_game()
	await _frames(8)
	check(not creator.is_open(), "a new game puts away the creator that was open in the old scene")
	check(game.needs_creator and str(game.hero.get("name", "")) == "", "...and starts with no hero yet")
	var p2 := current_scene.find_child("Player", true, false) as Node3D
	check(p2 != null and p2 != p and current_scene.scene_file_path == EARTH, "...at home on Earth, with a new player")
	creator.open(true)
	await _frames(2)
	check(creator.is_open() and p2.get("input_locked") and creator._cam != null and creator._cam.current,
		"...where the creator opens again for the new hero")
	check((not windowed or Input.mouse_mode == Input.MOUSE_MODE_VISIBLE) and creator._tab == "Body", "...with the mouse, on the Body tab")
	# Quitting before the hero's made (the new game has already saved) asks for one again next time
	game.save_game()
	game.load_game()
	check(game.needs_creator, "a new game saved before the hero's made still opens the creator next time")
	game._resume = {}
	game.hero["name"] = "Luna"
	creator.close()
	await _frames(2)
	check(not creator.is_open() and not p2.get("input_locked") and (not windowed or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED),
		"Done after a new game lets the hero move")
	game.load_game()
	check(not game.needs_creator and game.hero.name == "Luna", "...and once it's made, loading doesn't ask again")
	game._resume = {}
	_end()


func _head_width(mesh: Mesh) -> float:
	# How wide their head is, ears and all (everything above the neck)
	var w := 0.0
	for i in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if v.y > 1.0:
				w = maxf(w, absf(v.x))
	return w * 2.0


func _part_box(mesh: Mesh, surface: int) -> AABB:
	var v: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
	var box := AABB(v[0], Vector3.ZERO)
	for x in v:
		box = box.expand(x)
	return box


class ClickProbe extends Node:
	# Counts mouse clicks that get past the creator to the game (where the camera would grab the mouse)
	var clicks := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			clicks += 1


func _mouse_button(at: Vector2, down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = at
	root.push_input(click)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
