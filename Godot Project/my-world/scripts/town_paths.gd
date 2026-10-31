class_name TownPaths
extends RefCounted

# The town's path graph: named points (doorsteps, paths, boardwalks, the gardens up the ramp) and the links between
# them, from res://routines/places.json. People with a daily routine (scripts/routine.gd) walk from point to point
# along links, so they go round buildings and the lake instead of through them. tools/check_paths.gd checks it.
# Earth has its own graph, res://routines/earth_places.json, written by tools/build_earth.gd. A point there can have
# a third number, the height of the floor it's on (inside a shop, up the library's steps), so finding the ground under
# it doesn't land on the roof.

const FILE := "res://routines/places.json"
const EARTH_FILE := "res://routines/earth_places.json"

static var _shared := {}             # file -> TownPaths

var file := FILE
var points := {}                     # name -> Vector2 (x, z)
var floors := {}                     # name -> the floor's height, for points indoors or up steps
var links: Array = []                # [name, name]
var _astar := AStar2D.new()
var _ids := {}                       # name -> astar id
var _names := {}                     # astar id -> name


static func get_shared(from := FILE) -> TownPaths:
	if not _shared.has(from):
		var paths := TownPaths.new()
		paths.file = from
		paths._load()
		_shared[from] = paths
	return _shared[from]


func _load() -> void:
	var res := load(file) as JSON
	if res == null or not res.data is Dictionary:
		push_warning("TownPaths: couldn't read " + file)
		return
	var pts: Dictionary = res.data.get("points", {})
	var id := 0
	for name in pts:
		var p: Array = pts[name]
		points[name] = Vector2(float(p[0]), float(p[1]))
		if p.size() > 2:
			floors[name] = float(p[2])
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
	if floors.has(name):
		return ground_at(Vector3(p.x, floors[name], p.y), space, skip, 1.2)
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
