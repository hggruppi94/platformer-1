extends SceneTree

# Checks Nina's clothes (scripts/clothes.gd): every slot from head to toe has things to buy at the Clothing Boutique
# (res://shop/items.json), each with a look; buying puts it on; she can wear one thing in every slot at once, the
# pieces sit on her bones and move with her, her backpack comes off for wings; the wardrobe's arrows swap and take
# things off; outfits save and load (and an old save's hat carries over); Nina's house has a wardrobe; and a friend
# skating in her place doesn't wear her clothes.
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
	var shirt: int = Clothes._surfaces(body, ["Shirt"])[0]
	var sm := body.get_surface_override_material(shirt) as StandardMaterial3D
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
	check(shop._title.text == "Nina's Wardrobe", "the mirror opens her wardrobe")
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
	check(dash_model.find_children("Clothes *", "BoneAttachment3D", true, false).is_empty(), "Dash skates in his own clothes")
	p.set_rider("nina")
	await _frames(2)
	model = p.get("model") as Node3D
	check(model.find_children("Clothes *", "BoneAttachment3D", true, false).size() == holders.size(), "...and Nina has hers back")

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
