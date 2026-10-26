extends SceneTree

# Checks Nina's clothes (scripts/clothes.gd): every slot from head to toe has things to buy at the Clothing Boutique
# (res://shop/items.json), each with a look; buying puts it on; she can wear one thing in every slot at once, the
# pieces sit on her bones and move with her, her backpack comes off for wings; the wardrobe's arrows swap and take
# things off; outfits save and load (and an old save's hat carries over); Nina's house has a wardrobe; a friend
# skating in her place doesn't wear her clothes; her looks change colour; and friends can be dressed too, with the
# clothes fitted to them.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_clothes.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const BOUTIQUE := "res://scenes/interiors/clothing_boutique.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"

var failures := 0
var game: Node
var shop: Node


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
	shop = root.get_node("Shop")
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = ""
	# The player is their own hero, made from your save: start from a hippo body (Nina's), as the checks below look
	# at her own shirt and hair
	game.hero = Hero.blank()
	game.needs_creator = false

	# --- What there is ---
	var clothes: Array = shop.items.values().filter(func(i: Dictionary) -> bool: return i.kind == "clothes")
	for slot in Clothes.SLOTS:
		var n: int = shop.items.values().filter(func(i: Dictionary) -> bool:
			return (i.kind == "hat" and slot == "head") or (i.kind == "clothes" and i.slot == slot)).size()
		check(n >= 3, "%s: %d things to wear" % [Clothes.SLOT_NAMES[slot], n])
	var looks: bool = clothes.all(func(i: Dictionary) -> bool:
		var piece := Clothes.hat_or_piece(i.slot, i.id)
		var ok := piece != null or Clothes.RESTYLE.has(i.id)
		if piece:
			piece.free()
		return ok)
	check(looks and clothes.all(func(i: Dictionary) -> bool: return i.stall == "Boutique"),
		"all %d clothes have a look and are sold at the Boutique" % clothes.size())

	# --- The Boutique: buy one thing for every slot ---
	change_scene_to_file(BOUTIQUE)
	await _frames(6)
	var p := current_scene.find_child("Player", true, false) as Node3D
	check(current_scene.find_child("BoutiqueCounter", true, false) != null and current_scene.find_child("WardrobeSpot", true, false) != null,
		"the Clothing Boutique has a counter and a mirror")
	for f in game.items.duplicate():
		if String(f).begins_with("shop:"):
			game.items.erase(f)
	game.outfit = {}
	game.sparkles = 500
	var pick := {"head": "sk8_beanie", "face": "heart_shades", "neck": "cozy_scarf", "top": "galaxy_tee",
		"bottoms": "tutu", "feet": "moon_boots", "hands": "cozy_mittens", "back": "butterfly_wings"}
	shop.open("Boutique")
	for slot in pick:
		shop.buy(pick[slot])
	shop.close()
	await _frames(2)
	check(game.outfit == pick, "buying puts each thing on: wearing one in all 8 slots")
	var model := p.get("model") as Node3D
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var holders := skel.find_children("Clothes *", "BoneAttachment3D", false, false)
	var on_bones := {}
	for h in holders:
		on_bones[(h as BoneAttachment3D).bone_name] = true
	check(on_bones.has("head") and on_bones.has("chest") and on_bones.has("hips") and on_bones.has("hand.L")
		and on_bones.has("hand.R") and on_bones.has("foot.L") and on_bones.has("foot.R"),
		"pieces sit on her head, chest, hips, both hands and both feet (%d)" % holders.size())
	var body := Clothes._body(model)
	var hidden: bool = Clothes._surfaces(body, ["Backpack"]).all(func(i: int) -> bool:
		var m := body.get_surface_override_material(i) as StandardMaterial3D
		return m != null and m.albedo_color.a == 0.0)
	check(hidden, "her backpack comes off for the wings")
	var shirts := Clothes._surfaces(body, ["Shirt"])
	var sm := body.get_surface_override_material(shirts[0]) as StandardMaterial3D if not shirts.is_empty() else null
	check(sm != null and sm.albedo_texture != null, "the Galaxy Tee restyles her own shirt, with stars")

	# Pieces move with her: a mitten follows her hand when she runs
	var mitten: Node3D = null
	for h in holders:
		if (h as BoneAttachment3D).bone_name == "hand.L":
			mitten = h
	var anim := p.get("anim") as AnimationPlayer
	var still := mitten.global_position - p.global_position
	anim.play("run")
	anim.seek(0.25, true)
	await _frames(3)
	var running := mitten.global_position - p.global_position
	check(still.distance_to(running) > 0.03, "a mitten moves with her hand as she runs (%.2f m)" % still.distance_to(running))
	anim.play("idle")

	# --- The wardrobe's arrows ---
	shop.buy("hero_gloves")
	shop.open("Wardrobe")
	await _frames(2)
	check(shop._title.text == "Your Wardrobe", "the mirror opens your wardrobe")
	game.outfit["hands"] = "cozy_mittens"
	shop.cycle("hands", 1)
	check(game.outfit.get("hands") == "hero_gloves", "the arrow swaps the mittens for the hero gloves")
	shop.cycle("hands", 1)
	check(not game.outfit.has("hands"), "...and round again to her own bare hands")
	shop.cycle("hands", -1)
	check(game.outfit.get("hands") == "hero_gloves", "...and back")
	shop.close()

	# --- Saving and loading ---
	game.save_game()
	var saved: Dictionary = game.outfit.duplicate()
	game.outfit = {}
	game.load_game()
	check(game.outfit == saved, "the outfit saves and loads")
	var old := {"hat": "propeller_cap"}
	game.outfit = {}
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.erase("outfit")
	data.erase("outfits")
	data.merge(old, true)
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.outfit.get("head") == "propeller_cap" and game.hat == "propeller_cap", "an old save's hat carries over")
	game.outfit = pick.duplicate()
	game.equipment_changed.emit()

	# --- A friend skating in her place doesn't wear her clothes, and she has them back after ---
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	p.set_rider("dash")
	await _frames(2)
	var dash_model := p.get("model") as Node3D
	check(dash_model.find_children("Clothes *", "BoneAttachment3D", true, false).is_empty(), "Dash doesn't borrow Nina's outfit when he skates")
	p.set_rider("hero")
	await _frames(2)
	model = p.get("model") as Node3D
	check(model.find_children("Clothes *", "BoneAttachment3D", true, false).size() == holders.size(), "...and the hero has theirs back")

	# --- Their looks: a hair colour from the creator recolours their own hair ---
	game.hero["colors"] = {"hair": 3}
	game.hero["hairstyle"] = 0                       # their body's own hair
	game.equipment_changed.emit()
	await _frames(2)
	model = p.get("model") as Node3D
	var body2 := Clothes._body(model)
	var hairs := Clothes._surfaces(body2, ["Hair"])
	var hair := body2.get_surface_override_material(hairs[0]) as StandardMaterial3D if not hairs.is_empty() else null
	check(hair != null and hair.albedo_color.is_equal_approx(Hero.SWATCHES[2]), "the creator's hair colour recolours their hair")
	game.hero["colors"] = {}

	# --- Dressing a friend: Dash gets the star glasses, fitted to his face ---
	shop.open("Wardrobe")
	shop.cycle_who(2)                                 # past Nina, to Dash
	check(shop.who == "dash" and shop._title.text == "Dash's Wardrobe", "the Who arrows pick Dash")
	game.outfits["dash"] = {"face": "star_glasses", "hands": "hero_gloves", "top": "stripy_shirt"}
	shop.close()
	p.set_rider("dash")
	await _frames(3)
	var dm := p.get("model") as Node3D
	var fit := Clothes.fit_of(dm)
	var glasses: Node3D = null
	for h in dm.find_children("Clothes *", "BoneAttachment3D", true, false):
		if (h as BoneAttachment3D).bone_name == "head":
			glasses = h.get_child(0)
	var lens := glasses.get_child(0) as Node3D if glasses else null
	var in_model := dm.global_transform.affine_inverse() * lens.global_position if lens else Vector3.ZERO
	check(lens != null and absf(in_model.y - fit.eyes.y) < 0.12 and absf(in_model.z - fit.eyes.z) < 0.12,
		"Dash wears the star glasses over his own eyes (%.2f up, %.2f forward)" % [in_model.y, in_model.z])
	var dbody := Clothes._body(dm)
	var hoodies := Clothes._surfaces(dbody, ["Hoodie"])
	check(not hoodies.is_empty() and dbody.get_surface_override_material(hoodies[0]) != null, "...and the stripy shirt restyles his hoodie")
	check(not Clothes.can_wear("rex", "face") and Clothes.can_wear("rex", "head"), "Rex only wears hats")
	p.set_rider("hero")
	await _frames(2)

	# --- Friends wear their outfits in town too ---
	change_scene_to_file("res://scenes/town/town.tscn")
	await _frames(6)
	var dash_npc := current_scene.find_child("Dash", true, false) as Node3D
	var npc_model := dash_npc.get_node("Model") as Node3D
	check(npc_model.find_children("Clothes *", "BoneAttachment3D", true, false).size() >= 3, "Dash wears his outfit round town")

	# --- Nina's house has a wardrobe ---
	change_scene_to_file(HOUSE)
	await _frames(6)
	check(current_scene.find_child("WardrobeSpot", true, false) != null, "Nina's house has a wardrobe")
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
