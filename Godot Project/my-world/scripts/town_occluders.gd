extends Node3D

# Occlusion culling for Stars Hollow (15 Nov 2026, the detailed props pipeline). A big game doesn't draw what's
# hidden behind a building; Godot can do the same (Project Settings > Rendering > Occlusion Culling, on since this
# change) if it's told which shapes block the view. This puts an invisible box inside every building on the town map
# (ui/earth_map.json "buildings", the builder's footprints), a little smaller than its walls, so things behind a shop
# or a house aren't sent to the graphics card at all.
#
# A box only blocks while the camera's outside it (with some room): step into a shop, or let the camera swing close,
# and that one switches off, so nothing inside a building is ever hidden.

const MAP := "res://ui/earth_map.json"
const SHRINK := 0.8          # of the footprint, so the box is well inside the walls
const HEIGHT := 3.6          # metres above the ground (the builders' walls are 4 to 6 m)
const SINK := 0.6            # and down into the ground, for slopes
const SKIP := ["Dance Studio"]   # buildings you can see into through big open doors
const ROOM := 2.5            # metres round a box where the camera switches it off

var boxes: Array[OccluderInstance3D] = []


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var space := get_world_3d().direct_space_state
	for b in data.get("buildings", []):
		if b.size() < 7 or b[6] != "building" or String(b[0]) in SKIP:
			continue
		var at := Vector3(float(b[1]), 0.0, float(b[2]))
		var yaw := float(b[5])
		# The ground's height: the lowest of four rays just outside the corners (the middle would hit the roof)
		var y := INF
		for c in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var off := Vector3(c.x * (float(b[3]) / 2.0 + 1.0), 0, c.y * (float(b[4]) / 2.0 + 1.0)).rotated(Vector3.UP, yaw)
			var q := PhysicsRayQueryParameters3D.create(at + off + Vector3(0, 60, 0), at + off - Vector3(0, 30, 0))
			var hit := space.intersect_ray(q)
			if hit:
				y = minf(y, hit.position.y)
		if y == INF:
			y = 0.0
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = Vector3(float(b[3]) * SHRINK, HEIGHT + SINK, float(b[4]) * SHRINK)
		occ.occluder = box
		occ.name = String(b[0])
		occ.position = Vector3(at.x, y + (HEIGHT - SINK) / 2.0, at.z)
		occ.rotation.y = yaw
		add_child(occ)
		boxes.append(occ)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	for occ in boxes:
		var local := occ.global_transform.affine_inverse() * p
		var half := (occ.occluder as BoxOccluder3D).size / 2.0 + Vector3(ROOM, ROOM, ROOM)
		occ.visible = not (absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z)
