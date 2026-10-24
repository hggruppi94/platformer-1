extends SceneTree

# Checks the player's own hero (scripts/hero.gd, scripts/creator.gd) and house (scripts/home_decor.gd): a new game
# needs the creator and starts at home, the creator changes the body, hairstyle, colours, size and name and won't
# close without a name, "Surprise me" keeps the name, the hero saves and loads, an old save from before heroes asks
# for one and keeps its outfit, dialogue says the player's name and pronouns, the house's Decorate spot changes the
# colours and furniture (and they save), and Nina is a friend in town with things to say.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_creator.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const HOUSE := "res://scenes/interiors/my_house.tscn"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
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

	# --- A new game: no hero yet, wakes up at home ---
	game.hero = Hero.blank()
	game.needs_creator = true
	game.home = {}
	game._resume = {}
	game.next_spawn = "BedSpawn"
	change_scene_to_file(HOUSE)
	await _frames(6)
	check(ProjectSettings.get_setting("application/run/main_scene") == HOUSE, "the game starts in My House")
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
	_end()


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
