class_name SavedOutfits
extends RefCounted

# Saved outfits in a save (Game.saved_outfits, for the quick outfit wheel: scripts/quick_outfits.gd), made safe to
# use. A plain class with nothing but this, so Game can tidy a save's outfits while it loads, before the
# QuickOutfits autoload is there.

const MAX := 6


static func clean(data) -> Array:
	# A save's saved outfits made safe to use: always six places, each null or a whole outfit
	var out := []
	out.resize(MAX)
	if not data is Array:
		return out
	for i in mini((data as Array).size(), MAX):
		var o = data[i]
		if not o is Dictionary:
			continue
		var worn := {}
		var raw_outfit = o.get("outfit", {})
		if raw_outfit is Dictionary:
			for slot in raw_outfit:
				if str(slot) in Clothes.SLOTS:
					worn[str(slot)] = str(raw_outfit[slot])
		var colors := {}
		var raw_colors = o.get("colors", {})
		if raw_colors is Dictionary:
			for part in raw_colors:
				colors[str(part)] = int(raw_colors[part])
		out[i] = {"name": str(o.get("name", "Outfit %d" % (i + 1))), "outfit": worn, "colors": colors,
			"skin": str(o.get("skin", ""))}
	return out
