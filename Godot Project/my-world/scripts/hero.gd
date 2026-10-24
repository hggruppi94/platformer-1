class_name Hero
extends RefCounted

# The player's own character, made in the character creator (scripts/creator.gd) and kept in Game.hero:
#
#   name and pronouns   what everyone calls them ({player}, {they}... in dialogue: scripts/dialogue.gd)
#   body                the body they start from (BODIES: Sofi's hippo, cow, moth, alien, dog-kid or kid bodies)
#   looks               colours (fur, hair, eyes, an accent, blush, brows, their own top, bottoms and shoes), hairstyle
#                       (scripts/hairstyles.gd), extras on or off, height, head size and build
# Their outfit is Game.outfits["hero"] (scripts/clothes.gd), like everyone else's.

const BODIES := {
	"hippo": {"name": "Hippo", "char": "nina", "model": "res://models/characters/nina.glb",
		"hair": ["Hair"], "extras": ["Bow"], "extras_name": "Hair bow"},
	"kid": {"name": "Kid", "char": "dash", "model": "res://models/characters/bike_boy.glb",
		"hair": ["Hair"], "extras": ["Cap", "Cap White", "Glasses", "Lens Shine"], "extras_name": "Cap and shades"},
	"dog": {"name": "Dog-kid", "char": "rook", "model": "res://models/characters/rook.glb",
		"hair": ["Hair"], "extras": ["Collar", "Stud", "Tag"], "extras_name": "Collar"},
	"moth": {"name": "Moth", "char": "pip", "model": "res://models/characters/moth_kid.glb",
		"hair": ["Mane Orange", "Mane Teal", "Mane Purple", "Mane Pink"], "extras": ["Wing Pink", "Wing Yellow", "Wing Orange"],
		"extras_name": "Wings"},
	"cow": {"name": "Cow", "char": "bramble", "model": "res://models/characters/cattle_girl.glb",
		"hair": ["Hair", "Hair Shade", "Hair Tip Teal", "Hair Tip Lavender"], "extras": ["Alien Charm", "Star", "Glow Teal", "Glow Violet"],
		"extras_name": "Charm and glow"},
	"alien": {"name": "Alien", "char": "green_man", "model": "res://models/characters/green_man.glb",
		"hair": [], "extras": [], "extras_name": ""},
}
const BODY_ORDER := ["hippo", "kid", "dog", "moth", "cow", "alien"]
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

const SIZES := {"height": [0.85, 1.15], "head": [0.85, 1.2], "build": [0.85, 1.2]}


static func blank() -> Dictionary:
	# A fresh hero to start from: a hippo body with short brown hair and none of Nina's own extras, named nothing yet
	return {"name": "", "pronouns": "they", "body": "hippo", "colors": {"hair": 4}, "hairstyle": 1, "extras": false,
		"height": 1.0, "head": 1.0, "build": 1.0}


static func body_of(hero: Dictionary) -> Dictionary:
	return BODIES.get(str(hero.get("body", "hippo")), BODIES.hippo)


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
	h.body = BODY_ORDER[randi() % BODY_ORDER.size()]
	for part in COLOR_PARTS:
		if randf() < 0.75:
			h.colors[part] = 1 + randi() % SWATCHES.size()
	h.hairstyle = randi() % Hairstyles.NAMES.size()
	h.extras = randf() < 0.4
	for s in SIZES:
		h[s] = snappedf(randf_range(SIZES[s][0], SIZES[s][1]), 0.05)
	return h


static func apply(model: Node3D, hero: Dictionary, outfit: Dictionary) -> void:
	# Dress and shape a model as this hero: their outfit, colours, hairstyle, extras and size
	var body := body_of(hero)
	var who: String = body.char
	Clothes.dress(model, who, outfit, {})
	var colors: Dictionary = hero.get("colors", {})
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
	# Their hair: their body's own, or a new style in their hair colour (and the body's own hair hidden)
	var style := int(hero.get("hairstyle", 0))
	if style > 0 and not body.hair.is_empty():
		Clothes._hide(model, body.hair)
	var piece := Hairstyles.build(style, _hair_color(model, body, colors))
	if piece:
		Clothes._attach(model, Clothes._skeleton(model), piece, "hair", Clothes.fit_of(model))
	if not bool(hero.get("extras", false)) and not body.extras.is_empty():
		Clothes._hide(model, body.extras)
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
