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
	["Snowfield", "grass"],                              # the Frozen Moment's snow: soft and quiet underfoot
	["Frozen Lake", "crystal"], ["Ice Slide", "crystal"],   # ...and its ice clinks
]


static func kind_of(node: Node) -> String:
	if node == null:
		return "grass"
	var path := str(node.get_path())
	for pair in BY_NAME:
		if path.contains("/" + pair[0]):
			return pair[1]
	return "stone"                                       # paving, courts, the castle, buildings, interiors


# What she bumped into from the side or overhead (scripts/bumps.gd picks the boink by it): "wood" (trees, fences,
# stalls, crates), "stone" (walls, buildings, the castle: the default), "grass" (a bank of ground), "crystal" (ice,
# crystals, glass), "metal" (rails, lamp posts, the mothership), "soft" (mushrooms, clouds, hay, jelly, goo, other
# people and creatures) or "water". A node (or one of its parents) can say for itself with set_meta("surface", ...).
const WALL_BY_NAME := [
	["Hay", "soft"], ["Bale", "soft"], ["Mushroom", "soft"], ["Foliage", "soft"], ["Cloud", "soft"], ["Bubble", "soft"],
	["Jelly", "soft"], ["Gloop", "soft"], ["Goo", "soft"], ["Slime", "soft"], ["Cushion", "soft"], ["Pillow", "soft"],
	["Crystal", "crystal"], ["Ice", "crystal"], ["Frozen", "crystal"], ["Glass", "crystal"], ["Snowman", "crystal"],
	["Rail", "metal"], ["Lamp", "metal"], ["Pole", "metal"], ["Mothership", "metal"], ["Saucer", "metal"], ["Robot", "metal"],
	["Tree", "wood"], ["Trunk", "wood"], ["Fence", "wood"], ["Stall", "wood"], ["Signpost", "wood"], ["Bench", "wood"],
	["Barn", "wood"], ["Crate", "wood"], ["Boardwalk", "wood"], ["Dock", "wood"], ["Sailboats", "wood"], ["Log", "wood"],
	["Terrain", "grass"], ["Ground", "grass"], ["Hedge", "grass"], ["Snowfield", "grass"],
]


static func wall_kind(node: Node) -> String:
	if node == null:
		return "stone"
	var n := node
	for i in 4:
		if n == null:
			break
		if n.has_meta("surface"):
			return str(n.get_meta("surface"))
		n = n.get_parent()
	if node is CharacterBody3D or node is RigidBody3D:
		return "soft"                                    # bumping into someone: a friendly boink, not a clunk
	if node.is_in_group("water"):
		return "water"
	var path := str(node.get_path())
	for pair in WALL_BY_NAME:
		if path.contains(pair[0]):
			return pair[1]
	return "stone"
