class_name GrindRail
extends Path3D

# Something to grind: a handrail, the edge of a ledge, the back of a bench. The curve runs along the very top, where
# the board's trucks sit, so the skater (scenes/player/skate.gd) just follows it. Builders lay the points out
# (straight runs, so the baked curve stays a clean polyline) and make the rail's look themselves; this only knows
# the line.

@export var kind := "rail"            # "rail" (metal: sparks and a ringing grind) or "ledge" (stone and wood)


func _ready() -> void:
	add_to_group("grind")


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
