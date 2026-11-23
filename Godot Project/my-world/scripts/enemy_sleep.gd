extends RefCounted

# Enemies a long way from the player rest (no class_name: preload it). In the Void's Market the town's 26 enemies cost
# about 1.8 ms of every frame (measured on Hayden's PC, 23 Nov 2026), most of it ones nobody could see: their thinking
# and drips every physics frame, and their 45 or so little meshes each drawn from across the town. Now an enemy further
# than FAR from her (more for a big one) stops where it is until she comes back, and its meshes aren't drawn past the
# same distance, so anything she can see is awake and anything asleep can't be seen. Respawn timers are Timers, so
# they carry on either way.

const FAR := 90.0                      # metres, for a size-1 enemy


static func reach(e: Node3D) -> float:
	var s = e.get("size")
	return FAR * maxf(1.0, float(s) if s != null else 1.0)


static func asleep(e: Node3D, player: Node3D) -> bool:
	# True while she's far enough away that it can rest this frame. With no player (some tests) it stays awake.
	if player == null or not is_instance_valid(player):
		return false
	return e.global_position.distance_squared_to(player.global_position) > reach(e) * reach(e)


static func hide_when_far(id: int) -> void:
	# Its meshes stop being drawn past the distance it falls asleep at (the ones made later, like a Gloop's drips, are
	# under its Visual and only made while it's awake and near)
	var e := instance_from_id(id) as Node3D                # (by id: it may be gone by the time this runs)
	if e == null or not e.is_inside_tree():
		return                                            # (gone again before it got here)
	var end := reach(e)
	for g in e.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.visibility_range_end > 0.0:
			continue                                      # (one that already has its own range keeps it)
		gi.visibility_range_end = end                    # (no fade: fading draws it see-through, which costs more)
