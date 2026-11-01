class_name Hero
extends RefCounted

# The player's own character, made in the character creator (scripts/creator.gd) and kept in Game.hero:
#
#   name and pronouns   what everyone calls them ({player}, {they}... in dialogue: scripts/dialogue.gd)
#   body                the body they start from (BODIES: Sofi's hippo, cow, moth, alien and kid bodies, an Earth kid,
#                       a bunny, a cat and a dino, and the secret dog-kid once it's found)
#   looks               colours (fur, hair, eyes, an accent, blush, brows, their own top, bottoms and shoes), hairstyle
#                       (scripts/hairstyles.gd), extras on or off, height, head size and build
# Their outfit is Game.outfits["hero"] (scripts/clothes.gd), like everyone else's.

# Each body's face parts, for face sculpting (scripts/face_sculpt.gd): where each eye (the left one: the right is its
# mirror), the nose, the mouth and each ear sit on the model (in Godot's model space), how far round that spot its
# pieces reach ("r"), and which parts they're made of. A body without a feature (the alien has no ears) leaves it out,
# and its slider goes away. "head" is the middle of the head, which noses and ears grow out from. Ears can be a list:
# antennae or horns grow with them ("ears_name" says so on the slider).
const BODIES := {
	"hippo": {"name": "Hippo", "char": "nina", "model": "res://models/characters/nina.glb",
		"hair": ["Hair"], "extras": ["Bow"], "extras_name": "Hair bow",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.105, 1.18, 0.215), "r": 0.1},
			"nose": {"at": Vector3(0, 1.035, 0.22), "r": 0.13, "root": Vector3(0, 1.02, 0.13),
				"parts": ["Skin", "Nostril", "Mouth", "Tongue", "Teeth"]},
			"mouth": {"at": Vector3(0, 0.95, 0.255), "r": 0.1},
			"ears": {"at": Vector3(0.215, 1.335, -0.03), "r": 0.09, "parts": ["Skin", "Ear Inner"]}}},
	"kid": {"name": "Kid", "char": "dash", "model": "res://models/characters/bike_boy.glb",
		"hair": ["Hair"], "extras": ["Cap", "Cap White", "Glasses", "Lens Shine"], "extras_name": "Cap and shades",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.1, 1.16, 0.22), "r": 0.075},
			"nose": {"at": Vector3(0, 1.025, 0.235), "r": 0.05},
			"mouth": {"at": Vector3(0.005, 0.97, 0.205), "r": 0.07},
			"ears": {"at": Vector3(0.255, 1.085, -0.015), "r": 0.08}}},
	"moth": {"name": "Moth", "char": "pip", "model": "res://models/characters/moth_kid.glb",
		"hair": ["Mane Orange", "Mane Teal", "Mane Purple", "Mane Pink"], "extras": ["Wing Pink", "Wing Yellow", "Wing Orange"],
		"extras_name": "Wings",
		"face": {"head": Vector3(0, 1.07, 0),
			"eyes": {"at": Vector3(0.105, 1.09, 0.205), "r": 0.1},
			"nose": {"at": Vector3(0, 1.02, 0.245), "r": 0.04},
			"mouth": {"at": Vector3(0, 0.96, 0.225), "r": 0.07},
			"ears": [{"at": Vector3(0.275, 1.055, -0.015), "r": 0.08, "parts": ["Skin", "Skin Shade"]},
				{"at": Vector3(0.15, 1.47, 0.05), "r": 0.16, "root": Vector3(0.075, 1.32, 0.045),
					"parts": ["Antenna", "Antenna Tip"]}], "ears_name": "Ears and antennae"}},
	"cow": {"name": "Cow", "char": "bramble", "model": "res://models/characters/cattle_girl.glb",
		"hair": ["Hair", "Hair Shade", "Hair Tip Teal", "Hair Tip Lavender"], "extras": ["Alien Charm", "Star", "Glow Teal", "Glow Violet"],
		"extras_name": "Charm and glow",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.105, 1.11, 0.195), "r": 0.1},
			"nose": {"at": Vector3(0, 1.01, 0.2), "r": 0.07, "root": Vector3(0, 1.01, 0.15),
				"parts": ["Muzzle", "Nose", "Mouth"]},
			"mouth": {"at": Vector3(0, 0.99, 0.22), "r": 0.04},
			"ears": [{"at": Vector3(0.262, 0.99, 0.03), "r": 0.08, "parts": ["Fur", "Fur Light"]},
				{"at": Vector3(0.265, 1.445, -0.005), "r": 0.15, "root": Vector3(0.16, 1.27, 0.0),
					"parts": ["Horn", "Horn Tip"]}], "ears_name": "Ears and horns"}},
	"alien": {"name": "Alien", "char": "green_man", "model": "res://models/characters/green_man.glb",
		"hair": [], "extras": [], "extras_name": "",
		"face": {"head": Vector3(0, 1.12, 0),
			"eyes": {"at": Vector3(0.09, 1.115, 0.15), "r": 0.1},
			"mouth": {"at": Vector3(0, 0.943, 0.085), "r": 0.03, "parts": ["Mouth"]}}},
	# Bodies made for the creator (tools/build_hero_bodies.py)
	"earth_kid": {"name": "Earth kid", "char": "earth_kid", "model": "res://models/characters/earth_kid.glb",
		"hair": ["Hair"], "extras": ["Backpack", "Backpack Dark"], "extras_name": "Backpack",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.09, 1.1, 0.2), "r": 0.1},
			"nose": {"at": Vector3(0, 1.035, 0.23), "r": 0.05},
			"mouth": {"at": Vector3(0, 0.955, 0.195), "r": 0.07},
			"ears": {"at": Vector3(0.245, 1.09, -0.01), "r": 0.08, "parts": ["Skin", "Ear Inner"]}}},
	"bunny": {"name": "Bunny", "char": "bunny", "model": "res://models/characters/bunny.glb",
		"hair": [], "extras": ["Flower", "Flower Middle"], "extras_name": "Flower",
		"face": {"head": Vector3(0, 1.09, 0),
			"eyes": {"at": Vector3(0.09, 1.12, 0.21), "r": 0.1},
			"nose": {"at": Vector3(0, 1.02, 0.23), "r": 0.14, "root": Vector3(0, 1.02, 0.17),
				"parts": ["Nose", "Fur Light", "Whisker"]},
			"mouth": {"at": Vector3(0, 0.95, 0.2), "r": 0.06},
			"ears": {"at": Vector3(0.115, 1.47, -0.01), "r": 0.1, "root": Vector3(0.1, 1.31, 0.0),
				"parts": ["Ear", "Ear Lining"]}}},
	"cat": {"name": "Cat", "char": "cat", "model": "res://models/characters/cat.glb",
		"hair": [], "extras": ["Collar", "Bell"], "extras_name": "Bell collar",
		"face": {"head": Vector3(0, 1.09, 0),
			"eyes": {"at": Vector3(0.09, 1.11, 0.205), "r": 0.1},
			"nose": {"at": Vector3(0, 1.02, 0.22), "r": 0.14, "root": Vector3(0, 1.02, 0.16),
				"parts": ["Nose", "Fur Light", "Whisker"]},
			"mouth": {"at": Vector3(0, 0.955, 0.195), "r": 0.06},
			"ears": {"at": Vector3(0.15, 1.33, 0.0), "r": 0.08, "root": Vector3(0.12, 1.27, 0.0),
				"parts": ["Ear", "Ear Lining"]}}},
	"dino": {"name": "Dino", "char": "dino", "model": "res://models/characters/dino.glb",
		"hair": [], "extras": ["Scarf"], "extras_name": "Scarf",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.095, 1.15, 0.205), "r": 0.1},
			"nose": {"at": Vector3(0, 1.01, 0.2), "r": 0.15, "root": Vector3(0, 1.02, 0.12),
				"parts": ["Skin", "Nostril", "Mouth", "Tongue", "Teeth"]},
			"mouth": {"at": Vector3(0, 0.96, 0.285), "r": 0.08},
			"ears": [{"at": Vector3(0.24, 1.1, -0.035), "r": 0.06},
				{"at": Vector3(0.09, 1.365, -0.04), "r": 0.08, "root": Vector3(0.08, 1.33, -0.03), "parts": ["Horn"]}],
			"ears_name": "Ears and horns"}},
	# Secret bodies: they don't walk on two legs, so they aren't in the creator's list until they're unlocked
	# (SECRETS)
	"dog": {"name": "Dog-kid", "char": "rook", "model": "res://models/characters/rook.glb",
		"hair": ["Hair"], "extras": ["Collar", "Stud", "Tag"], "extras_name": "Collar",
		"face": {"head": Vector3(0, 1.1, 0),
			"eyes": {"at": Vector3(0.085, 1.1, 0.21), "r": 0.075},
			"nose": {"at": Vector3(0, 1.03, 0.235), "r": 0.05},
			"mouth": {"at": Vector3(0, 0.96, 0.205), "r": 0.07},
			"ears": {"at": Vector3(0.255, 1.085, -0.015), "r": 0.08}}},
}
# The bodies everyone can pick, in the creator's order
const BODY_ORDER := ["hippo", "kid", "earth_kid", "bunny", "cat", "moth", "cow", "dino", "alien"]
# Secret bodies, and how each one's found. They're kept by the save once found (Game.items "secret:<body>").
const SECRETS := {
	"dog": {"flag": "skate_lesson_done", "hint": "Finish Coach Bruno's skate lesson"},
}
const SECRET_ORDER := ["dog"]
const PRONOUNS := {
	"they": {"they": "they", "them": "them", "their": "their", "theirs": "theirs", "themself": "themself", "are": "are"},
	"she": {"they": "she", "them": "her", "their": "her", "theirs": "hers", "themself": "herself", "are": "is"},
	"he": {"they": "he", "them": "him", "their": "his", "theirs": "his", "themself": "himself", "are": "is"},
}

# More colours for the creator than the wardrobe's few (scripts/clothes.gd PALETTE): colour 0 is the body's own
const SWATCHES := [
	Color(0.98, 0.85, 0.75), Color(0.93, 0.72, 0.58), Color(0.78, 0.55, 0.4), Color(0.55, 0.38, 0.27),
	Color(0.35, 0.24, 0.18), Color(0.15, 0.12, 0.14), Color(0.95, 0.95, 0.97), Color(0.6, 0.6, 0.68),
	Color(0.95, 0.3, 0.3), Color(1.0, 0.55, 0.25), Color(1.0, 0.85, 0.3), Color(0.55, 0.85, 0.35),
	Color(0.3, 0.75, 0.6), Color(0.35, 0.8, 0.95), Color(0.35, 0.5, 1.0), Color(0.6, 0.45, 1.0),
	Color(0.85, 0.5, 0.95), Color(1.0, 0.55, 0.75), Color(0.6, 0.55, 0.5), Color(0.75, 0.95, 0.85),
]
const COLOR_PARTS := ["fur", "hair", "eyes", "accent", "blush", "brows", "top", "bottoms", "shoes"]
const COLOR_NAMES := {"fur": "Fur / skin", "hair": "Hair", "eyes": "Eyes", "accent": "Accent", "blush": "Blush",
	"brows": "Brows", "top": "Top", "bottoms": "Bottoms", "shoes": "Shoes"}
# Which of each body's parts a colour goes on, beyond Clothes.OWN_LOOKS and Clothes.OWN_CLOTHES
const BROWS := ["Brow"]

const SIZES := {"height": [0.8, 1.2], "head": [0.8, 1.4], "build": [0.8, 1.3]}


static func blank() -> Dictionary:
	# A fresh hero to start from: a hippo body with short brown hair and none of Nina's own extras, named nothing yet
	return {"name": "", "pronouns": "they", "body": "hippo", "colors": {"hair": 4}, "hairstyle": 1, "extras": false,
		"height": 1.0, "head": 1.0, "build": 1.0, "eyes": 1.0, "eye_gap": 1.0, "nose": 1.0, "ears": 1.0, "mouth": 1.0}


static func body_of(hero: Dictionary) -> Dictionary:
	return BODIES.get(str(hero.get("body", "hippo")), BODIES.hippo)


static func choices(hero := {}) -> Array:
	# The bodies the creator offers: everyone's, then the secrets found so far, and whatever body they have now
	var out := BODY_ORDER.duplicate()
	for id in SECRET_ORDER:
		if found(id):
			out.append(id)
	var now := str(hero.get("body", ""))
	if BODIES.has(now) and now not in out:
		out.append(now)
	return out


static func is_secret(id: String) -> bool:
	return SECRETS.has(id)


static func found(id: String) -> bool:
	# A secret body is found for good once its condition's been met (Creator.check_secrets keeps it in the save)
	var game := _autoload("Game")
	if game and game.has_item("secret:" + id):
		return true
	return meets(id)


static func meets(id: String) -> bool:
	var how: Dictionary = SECRETS.get(id, {})
	var dialogue := _autoload("Dialogue")
	var game := _autoload("Game")
	if how.has("flag") and dialogue and dialogue.flags.has(how.flag):
		return true
	if how.has("item") and game and game.has_item(how.item):
		return true
	return false


static func _autoload(name: String) -> Node:
	# (Autoloads, looked up by path: this is a plain class, which can't name them directly)
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(name) if tree else null


static func model_path(hero: Dictionary) -> String:
	return body_of(hero).model


static func display_name(hero: Dictionary) -> String:
	var n := str(hero.get("name", "")).strip_edges()
	return n if n != "" else "You"


static func pronoun(hero: Dictionary, word: String) -> String:
	return str(PRONOUNS.get(str(hero.get("pronouns", "they")), PRONOUNS.they).get(word, word))


static func random() -> Dictionary:
	# "Surprise me!": a whole new look (keeping their name and pronouns, which the creator puts back)
	var h := blank()
	var bodies := choices(h)
	h.body = bodies[randi() % bodies.size()]
	for part in COLOR_PARTS:
		if randf() < 0.75:
			h.colors[part] = 1 + randi() % SWATCHES.size()
	h.hairstyle = randi() % Hairstyles.NAMES.size()
	h.extras = randf() < 0.4
	for s in SIZES:
		h[s] = snappedf(randf_range(SIZES[s][0], SIZES[s][1]), 0.05)
	FaceSculpt.random_into(h)
	return h


static func apply(model: Node3D, hero: Dictionary, outfit: Dictionary) -> void:
	# Dress and shape a model as this hero: their outfit, colours, hairstyle, extras and size
	var body := body_of(hero)
	var who: String = body.char
	var colors: Dictionary = hero.get("colors", {})
	# Their hair: their body's own, or a new style in their hair colour (and the body's own hair hidden). The clothes
	# are fitted with these parts gone, and a hat goes over the hairstyle.
	var hidden := []
	var style := int(hero.get("hairstyle", 0))
	if style > 0 and not body.hair.is_empty():
		hidden.append_array(body.hair)
	if not bool(hero.get("extras", false)):
		hidden.append_array(body.extras)
	var hair_color := _hair_color(model, body, colors)
	var gone := Clothes.dress(model, who, outfit, {}, hidden, Hairstyles.build(style, hair_color))
	var own_looks: Dictionary = Clothes.OWN_LOOKS.get(who, {})
	var own_clothes: Dictionary = Clothes.OWN_CLOTHES.get(who, {})
	for part in colors:
		var pick := int(colors[part])
		if pick <= 0:
			continue
		var c: Color = SWATCHES[(pick - 1) % SWATCHES.size()]
		var names: Array = []
		match part:
			"brows":
				names = BROWS
			"top", "bottoms":
				if not outfit.has(part):                    # a bought top or bottoms has its own colours
					names = own_clothes.get(part, [])
			"shoes":
				if not outfit.has("feet"):
					names = own_clothes.get("feet", [])
			_:
				names = own_looks.get(part, [])
		if not names.is_empty():
			Clothes._recolour(model, names, c)
	Clothes._hide(model, gone)                      # recolouring mustn't bring back anything hidden
	# Size: height scales the whole model (their feet stay on the ground); head and build go on the skeleton
	var h := float(hero.get("height", 1.0))
	model.scale = Vector3(h, h, h)
	var skel := Clothes._skeleton(model)
	var shape := skel.get_node_or_null("BodyShape") as BodyShape
	if shape == null:
		shape = BodyShape.new()
		shape.name = "BodyShape"
		skel.add_child(shape)
	shape.head = float(hero.get("head", 1.0))
	shape.build = float(hero.get("build", 1.0))
	# Their face: eyes, nose, ears and mouth sculpted bigger or smaller (after the clothes, which fit the body as drawn)
	FaceSculpt.apply(model, body.get("face", {}), hero)


static func _hair_color(model: Node3D, body: Dictionary, colors: Dictionary) -> Color:
	var pick := int(colors.get("hair", 0))
	if pick > 0:
		return SWATCHES[(pick - 1) % SWATCHES.size()]
	# Their body's own hair colour (the alien has none: a soft green)
	var found := Color(0.45, 0.8, 0.4)
	if not body.hair.is_empty():
		Clothes._each_surface(model, [body.hair[0]], func(mesh: MeshInstance3D, i: int, _k: int) -> void:
			found = (mesh.mesh.surface_get_material(i) as StandardMaterial3D).albedo_color)
	return found
