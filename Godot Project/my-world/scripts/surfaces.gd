class_name Surfaces
extends RefCounted

# What Nina is standing on, by the thing under her feet: "grass" (the ground), "wood" (boardwalks, the dock, the
# tree house), "stone" (paved places, the castle, buildings), "crystal", "mushroom" (big solid caps: bouncy) or
# "cloud". The player (scenes/player/player.gd) picks footstep and landing sounds by it.

const BY_NAME := [
	["Boardwalk", "wood"], ["Dock", "wood"], ["Tree House", "wood"], ["Sailboats", "wood"], ["Fence", "wood"],
	["Cloud", "cloud"],
	["Crystals", "crystal"],
	["Foliage", "mushroom"],
	["Terrain", "grass"], ["Far Ground", "grass"],
]


static func kind_of(node: Node) -> String:
	if node == null:
		return "grass"
	var path := str(node.get_path())
	for pair in BY_NAME:
		if path.contains("/" + pair[0]):
			return pair[1]
	return "stone"                                       # paving, courts, the castle, buildings, interiors
