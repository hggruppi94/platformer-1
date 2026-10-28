class_name GrindRail
extends Path3D

# Something to grind: a handrail, the edge of a ledge, the back of a bench. The curve runs along the very top, where
# the board's trucks sit, so the skater (scenes/player/skate.gd) just follows it. Builders lay the points out
# (straight runs, so the baked curve stays a clean polyline) and make the rail's look themselves; this only knows
# the line. Edges of the world's own boxes and round tops become rails by themselves (scripts/edge_rails.gd).
#
# Every rail files itself in a grid of the world (CELL metres square), so the skater only looks at the rails near
# them, however many there are in town.

const CELL := 8.0

@export var kind := "rail"            # "rail" (metal: sparks and a ringing grind) or "ledge" (stone and wood)

static var _grid := {}                # Vector2i cell -> Array of rails touching it
var _cells: Array[Vector2i] = []


func _ready() -> void:
	add_to_group("grind")
	_file()


func _exit_tree() -> void:
	for c in _cells:
		var list: Array = _grid.get(c, [])
		list.erase(self)
		if list.is_empty():
			_grid.erase(c)
	_cells.clear()


func _file() -> void:
	# Into every cell its line passes through (sampled every half cell, so a long rail is in all of them)
	var n := maxi(int(length() / (CELL * 0.5)), 1)
	for k in n + 1:
		var at := point_at(length() * k / n)
		var c := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
		if c not in _cells:
			_cells.append(c)
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append(self)


static func near(pos: Vector3) -> Array:
	# The rails in the cell round this point and the eight next to it
	var out := []
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for r in _grid.get(c + Vector2i(dx, dz), []):
				if is_instance_valid(r) and r not in out:
					out.append(r)
	return out


func length() -> float:
	return curve.get_baked_length()


func closest_offset(world_pos: Vector3) -> float:
	return curve.get_closest_offset(to_local(world_pos))


func point_at(offset: float) -> Vector3:
	return to_global(curve.sample_baked(clampf(offset, 0.0, length())))


func tangent_at(offset: float) -> Vector3:
	# Which way the rail runs here (toward higher offsets), in world space. Measured over a short stretch rather than
	# at a point, so a corner between two straight runs turns smoothly instead of all at once.
	var a := point_at(offset - 0.15)
	var b := point_at(offset + 0.15)
	if a.distance_squared_to(b) < 0.0001:
		return (point_at(length()) - point_at(0.0)).normalized()
	return (b - a).normalized()
