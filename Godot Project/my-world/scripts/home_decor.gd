extends Node3D

# The player's own house (tools/build_interiors.gd, _my_house), decorated their way (Game.home): wall, floor, rug
# and blanket colours, and what stands in each of the room's spots (a plant, a bookshelf, a fish tank...). Every
# choice is already built and hidden; this shows the chosen ones. The Decorate spot (the "Decorate" stall in
# scripts/shop.gd) changes Game.home and calls Game.equipment_changed, which redecorates.

const COLORS := {
	"walls": [Color(1.0, 0.85, 0.9), Color(0.8, 0.9, 1.0), Color(0.85, 1.0, 0.85), Color(1.0, 0.95, 0.75),
		Color(0.85, 0.8, 1.0), Color(1.0, 0.8, 0.65), Color(0.75, 0.95, 0.95), Color(0.95, 0.95, 0.95)],
	"floor": [Color(0.62, 0.44, 0.3), Color(0.8, 0.65, 0.45), Color(0.4, 0.28, 0.2), Color(0.85, 0.8, 0.9),
		Color(0.55, 0.75, 0.9), Color(0.6, 0.8, 0.6)],
	"rug": [Color(0.75, 0.55, 0.95), Color(1.0, 0.6, 0.75), Color(0.5, 0.8, 1.0), Color(1.0, 0.85, 0.4),
		Color(0.55, 0.9, 0.6), Color(1.0, 0.65, 0.4)],
	"blanket": [Color(0.9, 0.12, 0.22), Color(0.35, 0.55, 1.0), Color(1.0, 0.8, 0.3), Color(0.45, 0.85, 0.5),
		Color(0.75, 0.5, 1.0), Color(1.0, 0.55, 0.8)],
}
const COLOR_NAMES := {
	"walls": ["pink", "sky blue", "mint", "lemon", "lavender", "peach", "aqua", "white"],
	"floor": ["oak", "honey wood", "dark wood", "lilac tiles", "blue tiles", "green tiles"],
	"rug": ["purple", "pink", "blue", "yellow", "green", "orange"],
	"blanket": ["red", "blue", "yellow", "green", "purple", "pink"],
}
const LABELS := {"walls": "Walls", "floor": "Floor", "rug": "Rug", "blanket": "Blanket"}
# What can stand in a spot, and the spots round the room
const ITEMS := ["none", "plant", "bookshelf", "toy_chest", "lamp", "fish_tank", "beanbag", "drum_kit", "easel",
	"telescope", "arcade", "trophy_shelf"]
const ITEM_NAMES := {"none": "nothing", "plant": "a big plant", "bookshelf": "a bookshelf", "toy_chest": "a toy chest",
	"lamp": "a lava lamp", "fish_tank": "a fish tank", "beanbag": "a beanbag", "drum_kit": "a drum kit",
	"easel": "an easel", "telescope": "a telescope", "arcade": "an arcade game", "trophy_shelf": "a trophy shelf"}
const SPOTS := ["spot1", "spot2", "spot3", "spot4", "spot5", "spot6"]
const SPOT_NAMES := {"spot1": "By the bed", "spot2": "Back wall", "spot3": "Right wall", "spot4": "Left wall",
	"spot5": "By the door, left", "spot6": "By the door, right"}
const STARTING := {"spot1": "lamp", "spot2": "bookshelf", "spot4": "toy_chest", "spot6": "plant"}

var _mats := {}


func _ready() -> void:
	# Each recolourable part gets its own copy of its material, so changing it changes only this house
	for part in ["walls", "floor", "rug", "blanket"]:
		for mi in find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).material_override
			if m and m.resource_name.begins_with("Decor " + part):
				if not _mats.has(part):
					_mats[part] = m.duplicate()
				(mi as MeshInstance3D).material_override = _mats[part]
	Game.equipment_changed.connect(decorate)
	decorate()


static func choice(part: String) -> int:
	return int(Game.home.get(part, 0))


static func item_in(spot: String) -> String:
	return str(Game.home.get(spot, STARTING.get(spot, "none")))


func decorate() -> void:
	for part in _mats:
		var cols: Array = COLORS[part]
		(_mats[part] as StandardMaterial3D).albedo_color = cols[choice(part) % cols.size()]
	for spot in SPOTS:
		var holder := get_node_or_null("Decor/" + spot) as Node3D
		if holder == null:
			continue
		var want := item_in(spot)
		for c in holder.get_children():
			var on: bool = c.name == "Item " + want
			(c as Node3D).visible = on
			c.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED   # hidden ones aren't solid
