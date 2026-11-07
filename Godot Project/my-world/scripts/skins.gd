class_name Skins
extends RefCounted

# Skins: colour sets for the hero's body (fur or skin, hair, eyes, accent, blush and brows), earned round the game
# and picked in the wardrobe (scripts/shop.gd) or with a saved outfit on the quick outfit wheel
# (scripts/quick_outfits.gd). A skin sits on top of the colours picked in the creator (Game.hero.colors) without
# changing them, so taking it off gives the hero back exactly as they were made: Hero.apply() reads colors_of().
# Each one works on every body; "keep" lists what a body holds on to (an Earth kid keeps their own skin tone, since
# kids are people on Earth). Owned skins are items "skin:<id>" in Game.items, so a save needs nothing new for them.
#
# Colours are numbers into Hero.SWATCHES, counted from 1 (0 is the body's own).

const SKINS := {
	"starlight": {"name": "Starlight", "colors": {"fur": 16, "hair": 7, "eyes": 11, "accent": 11, "blush": 18, "brows": 7},
		"from": "requests", "need": 3, "how": "Finish 3 of Tally's requests"},
	"comet": {"name": "Comet Tail", "colors": {"fur": 14, "hair": 10, "eyes": 7, "accent": 10, "blush": 18, "brows": 10},
		"from": "requests", "need": 10, "how": "Finish 10 of Tally's requests"},
	"clockwork": {"name": "Clockwork Brass", "colors": {"fur": 11, "hair": 4, "eyes": 13, "accent": 9, "blush": 10, "brows": 4},
		"from": "watches", "need": 5, "how": "Give Dash 5 lost watches"},
	"midnight": {"name": "Midnight Hour", "colors": {"fur": 6, "hair": 16, "eyes": 11, "accent": 17, "blush": 16, "brows": 16},
		"from": "watches", "need": 15, "how": "Give Dash 15 lost watches"},
	"checkered": {"name": "Checkered Flag", "colors": {"fur": 7, "hair": 6, "eyes": 9, "accent": 9, "blush": 9, "brows": 6},
		"from": "races", "need": 1, "how": "Finish a race"},
	"champion": {"name": "Champion Gold", "colors": {"fur": 11, "hair": 10, "eyes": 15, "accent": 9, "blush": 10, "brows": 10},
		"from": "wins", "need": 3, "how": "Win 3 races"},
}
const ORDER := ["starlight", "comet", "clockwork", "midnight", "checkered", "champion"]
# What a body keeps of its own whatever skin it wears
const KEEP := {"earth_kid": ["fur"], "human_girl": ["fur"], "human_boy": ["fur"]}


static func colors_of(hero: Dictionary) -> Dictionary:
	# The colours the hero shows: the creator's, with their skin's on top
	var out: Dictionary = (hero.get("colors", {}) as Dictionary).duplicate()
	var id := str(hero.get("skin", ""))
	if not SKINS.has(id):
		return out
	var keep: Array = KEEP.get(str(hero.get("body", "hippo")), [])
	var skin: Dictionary = SKINS[id].colors
	for part in skin:
		if not part in keep:
			out[part] = skin[part]
	return out


static func skin_name(id: String) -> String:
	return str(SKINS[id].name) if SKINS.has(id) else "Their own colours"


static func owns(id: String) -> bool:
	var game := _autoload("Game")
	return id == "" or (game != null and game.has_item("skin:" + id))


static func owned() -> Array[String]:
	var out: Array[String] = []
	for id in ORDER:
		if owns(id):
			out.append(id)
	return out


static func progress(id: String) -> int:
	# How far along the way to earning it the player is
	var how: String = SKINS[id].from
	match how:
		"requests":
			var r := _autoload("Requests")
			return int(r.get("turned_in")) if r else 0
		"watches":
			var w := _autoload("Watches")
			return int(w.given_count()) if w else 0
		"races":
			var races := _autoload("Races")
			return int(races.get("raced")) if races else 0
		"wins":
			var races := _autoload("Races")
			var n := 0
			if races:
				for t in races.get("wins"):
					n += int(races.get("wins")[t])
			return n
	return 0


static func earned(id: String) -> bool:
	return progress(id) >= int(SKINS[id].need)


static func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(name) if tree else null
