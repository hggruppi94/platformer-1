class_name TownPaths
extends RefCounted

# The town's path graph: named points (doorsteps, paths, boardwalks, the gardens up the ramp) and the links between
# them, from res://routines/places.json. People with a daily routine (scripts/routine.gd) walk from point to point
# along links, so they go round buildings and the lake instead of through them. tools/check_paths.gd checks it.

const FILE := "res://routines/places.json"

static var _shared: TownPaths

var points := {}                     # name -> Vector2 (x, z)
var links: Array = []                # [name, name]
var _astar := AStar2D.new()
var _ids := {}                       # name -> astar id
var _names := {}                     # astar id -> name


static func get_shared() -> TownPaths:
	if _shared == null:
		_shared = TownPaths.new()
		_shared._load()
	return _shared


func _load() -> void:
	var res := load(FILE) as JSON
	if res == null or not res.data is Dictionary:
		push_warning("TownPaths: couldn't read " + FILE)
		return
	var pts: Dictionary = res.data.get("points", {})
	var id := 0
	for name in pts:
		var p: Array = pts[name]
		points[name] = Vector2(float(p[0]), float(p[1]))
		_astar.add_point(id, points[name])
		_ids[name] = id
		_names[id] = name
		id += 1
	for l in res.data.get("links", []):
		if _ids.has(l[0]) and _ids.has(l[1]):
			_astar.connect_points(_ids[l[0]], _ids[l[1]])
			links.append(l)
		else:
			push_warning("TownPaths: link %s names a point that isn't in the list" % [l])


func has(name: String) -> bool:
	return points.has(name)


func route(from: String, to: String) -> Array[String]:
	# The names of the points to walk through, from `from` to `to` (both included), or [] if there's no way
	var out: Array[String] = []
	if not _ids.has(from) or not _ids.has(to):
		return out
	for id in _astar.get_id_path(_ids[from], _ids[to]):
		out.append(_names[id])
	return out


func nearest(pos: Vector3) -> String:
	if _ids.is_empty():
		return ""
	return _names[_astar.get_closest_point(Vector2(pos.x, pos.z))]


func position_of(name: String, space: PhysicsDirectSpaceState3D, skip: Array[RID]) -> Vector3:
	var p: Vector2 = points.get(name, Vector2.ZERO)
	return ground_at(Vector3(p.x, 0, p.y), space, skip, 80.0)


static func ground_at(pos: Vector3, space: PhysicsDirectSpaceState3D, skip: Array[RID], above := 1.5) -> Vector3:
	# The ground (or boardwalk, dock...) under pos, looking down from `above` metres over it. A long look (80) finds
	# the ground from anywhere; a short one, from where someone already stands, can't land on a roof or a canopy.
	var q := PhysicsRayQueryParameters3D.create(Vector3(pos.x, pos.y + above, pos.z), Vector3(pos.x, pos.y - 30.0, pos.z))
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return hit.position if hit else pos


static func skip_rids(scene: Node) -> Array[RID]:
	# What a person walking about should never land on: other people, Nina, enemies, trees and leaves, triggers
	var out: Array[RID] = []
	for n in scene.find_children("*", "CollisionObject3D", true, false):
		var path := str(n.get_path())
		if n is Area3D or path.contains("/Characters/") or path.contains("/Player") or path.contains("/Trees") \
				or path.contains("/Foliage") or path.contains("/Enemies") or n is CharacterBody3D:
			out.append((n as CollisionObject3D).get_rid())
	return out
