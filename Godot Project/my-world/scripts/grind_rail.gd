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
	if get_parent() and String(get_parent().name).begins_with("Town Rail"):
		_clear_check.call_deferred()


# The town's own rails (tools/build_town.gd _town_rails) are laid out by the builder from hand-kept keep-clear lists,
# so one could end up running inside something: through the Library, a house, or the Star Arena's gate walls that are
# put in at play time. Pressing the grind button by one grabbed a rail nobody could see (Hayden, 14 Nov 2026: "making
# weird interaction when you press E, like grinding a rail that isn't there"). So once the world's in place, a town
# rail that runs inside anything solid takes itself out.
const PlantClearance := preload("res://scripts/plant_clearance.gd")
const CLEAR_STEP := 0.6               # metres between the spots checked along it
const CLEAR_BOX := Vector3(0.3, 0.5, 0.3)   # what has to be free just over the rail at each spot

var buried := false                   # tests: it found itself inside something and took itself out


func _clear_check() -> void:
	for wait in [0.2, 2.5]:               # (a moment for the world, then again for things put in at play time)
		if not is_inside_tree():
			return
		await get_tree().create_timer(wait).timeout
		if not is_inside_tree():
			return
		if inside_something():
			buried = true
			var holder := get_parent()
			remove_from_group("grind")
			_exit_tree()
			holder.queue_free()
			return


func inside_something() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = CLEAR_BOX
	q.shape = box
	q.collide_with_areas = false
	var n := maxi(int(length() / CLEAR_STEP), 1)
	for k in n + 1:
		q.transform = Transform3D(Basis.IDENTITY, point_at(length() * k / n) + Vector3(0, CLEAR_BOX.y / 2.0 + 0.05, 0))
		for hit in space.intersect_shape(q, 8):
			if PlantClearance._blocks(hit.get("collider"), get_parent()):
				return true
	return false


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
