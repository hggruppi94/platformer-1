extends RefCounted

# (No class_name: preload it, like scripts/use_spot.gd, so --script tools never trip over a stale class cache.)

# Trees and plants mustn't grow through things (Hayden's day 1 playtest, 11 Nov 2026: "tree and plant assets clip
# through other objects and it looks messy"). The builders scatter them using hand-kept keep-clear lists, which miss
# anything added to the world later. So as a world loads, each tree and plant asks the physics world whether anything
# solid (a building, fence, bench, rail, ramp, lamp, sign...) is where its trunk, leaves or blades would be, and also
# whether any built thing's look is (a roof's overhang, a sign or a lamp with nothing solid to it), and leaves itself
# out if so. The ground doesn't count, and nor does anything belonging to the plants themselves (the Void's solid
# mushroom caps, Earth's tree trunks), anything flat on the ground (paths, paint) or anything that moves about.
#
# Used by scenes/town/trees.gd and scenes/town/foliage.gd (the Void) and scripts/earth_world.gd (Earth's trees).

# Bodies under a node with one of these names are the land itself
const GROUND_NAMES := ["Terrain", "Ground", "Far Ground", "Land", "GroundCollision", "Bounds", "Water", "Lake", "Edge",
	"WorldBounds", "Sky"]
# ...and the plants' own holders, whose looks never count against each other
const PLANT_NAMES := ["Trees", "Foliage", "Autumn Trees"]
const MESH_CELL := 8.0            # metres: the grid the looks are sorted into
const MESH_FLAT := 0.3            # looks flatter than this (paths, paint, rugs) don't count
const MESH_HUGE := 40.0           # ...nor ones wider than this (whole districts, the sky, walls round the world)

static var _ground_ok := {}       # collider instance id -> true when it's ground, false otherwise
static var blocked_by := {}       # for tests and tools: what's stopped plants growing, by the path of its parent, with counts
static var _looks := {}           # the looks' grid (cell -> [[AABB, node path]]) for one world, made once a frame
static var _looks_key := []


static func box_clear(at: Node3D, xf: Transform3D, size: Vector3, own: Node = null) -> bool:
	# Is this box (in world space; size in metres along xf's own axes) free of anything solid?
	if size.x <= 0.01 or size.y <= 0.01 or size.z <= 0.01 or not at.is_inside_tree():
		return true
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	q.shape = shape
	q.transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	for hit in at.get_world_3d().direct_space_state.intersect_shape(q, 16):
		if _blocks(hit.get("collider"), own):
			var what := String((hit.collider as Node).get_parent().get_path()) if (hit.collider as Node).get_parent() else "?"
			blocked_by[what] = int(blocked_by.get(what, 0)) + 1
			return false
	# Then the looks: the box's own bounds against each built thing's bounds
	var box := q.transform * AABB(-size / 2.0, size)
	var looks := _looks_of(at)
	var c0 := Vector2i(floori(box.position.x / MESH_CELL), floori(box.position.z / MESH_CELL))
	var c1 := Vector2i(floori(box.end.x / MESH_CELL), floori(box.end.z / MESH_CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for l in looks.get(Vector2i(cx, cz), []):
				if (l[0] as AABB).intersects(box):
					blocked_by[l[1]] = int(blocked_by.get(l[1], 0)) + 1
					return false
	return true


static func _looks_of(at: Node) -> Dictionary:
	# Every built thing's look in this world, sorted into a grid: made again each frame it's asked for (a world loading,
	# or a look again after things were put in), and kept for the rest of that frame
	var world := at
	while world.get_parent() and world.get_parent() != at.get_tree().root:
		world = world.get_parent()
	var key := [world.get_instance_id(), Engine.get_process_frames()]
	if key == _looks_key:
		return _looks
	_looks_key = key
	_looks = {}
	_add_looks(world, false)
	return _looks


static func _add_looks(n: Node, skip: bool) -> void:
	if n is CharacterBody3D or n is RigidBody3D or n is Area3D or n is Skeleton3D or n is AnimationPlayer \
			or String(n.name) == "Characters":
		return                                         # people, enemies, rides, pickups, walkers: they move about
	if String(n.name) in GROUND_NAMES or String(n.name) in PLANT_NAMES:
		return
	if n is Node3D and not (n as Node3D).visible:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		var box := mi.global_transform * mi.get_aabb()
		if box.size.y >= MESH_FLAT and box.size.x <= MESH_HUGE and box.size.z <= MESH_HUGE:
			var shrunk := box.grow(-minf(0.1, box.size[box.get_shortest_axis_index()] * 0.25))
			var what := String(mi.get_parent().get_path())
			var c0 := Vector2i(floori(shrunk.position.x / MESH_CELL), floori(shrunk.position.z / MESH_CELL))
			var c1 := Vector2i(floori(shrunk.end.x / MESH_CELL), floori(shrunk.end.z / MESH_CELL))
			for cx in range(c0.x, c1.x + 1):
				for cz in range(c0.y, c1.y + 1):
					var cell := Vector2i(cx, cz)
					if not _looks.has(cell):
						_looks[cell] = []
					_looks[cell].append([shrunk, what])
	for c in n.get_children():
		_add_looks(c, skip)


static func instance_clear(at: Node3D, xf: Transform3D, unit: Vector3, own: Node = null) -> bool:
	# The same for a MultiMesh instance: xf is its (scaled) transform and unit the box that fits inside its mesh before
	# scaling, e.g. Vector3(1.1, 1.1, 1.1) for a unit-radius ball
	var size := Vector3(unit.x * xf.basis.x.length(), unit.y * xf.basis.y.length(), unit.z * xf.basis.z.length())
	return box_clear(at, xf, size, own)


static func _blocks(collider: Object, own: Node) -> bool:
	if collider == null or not (collider is StaticBody3D):
		return false                                  # people, enemies, rides and pickups move about: not in the way
	var body := collider as Node
	if own and own.is_ancestor_of(body):
		return false
	var id := body.get_instance_id()
	if not _ground_ok.has(id):
		var ground := false
		var n := body
		while n:
			if String(n.name) in GROUND_NAMES or n.is_in_group("ground"):
				ground = true
				break
			n = n.get_parent()
		_ground_ok[id] = ground
	return not _ground_ok[id]


# ----------------------------------------------------------------------------- Earth's baked trees
# tools/build_earth.gd batches the town's trees into three MultiMeshes under "Autumn Trees" (scripts/multi_fill.gd):
# trunks, balls of leaves and bare branches, with a little solid box for each trunk. A tree in the way of something
# goes as a whole: its trunk, its leaves, its branches and its box.

const TRUNK_UNIT := Vector3(1.2, 0.85, 1.2)
const LEAVES_UNIT := Vector3(1.1, 1.1, 1.1)
const BRANCH_UNIT := Vector3(1.0, 0.85, 1.0)


static func prune_earth_trees(trees: Node3D) -> int:
	if trees == null:
		return 0
	var parts := {}
	for kind in ["Trunk", "Leaves", "Branch"]:
		var mmi := trees.get_node_or_null("Tree " + kind) as MultiMeshInstance3D
		if mmi and mmi.multimesh:
			parts[kind] = mmi
	if not parts.has("Trunk") and not parts.has("Branch"):
		return 0
	# Each tree's spot: its trunk, or for a bare tree its thick bottom branch (the ones starting at the ground)
	var anchors: Array[Vector3] = []
	var members: Array = []                           # per tree: [[kind, index], ...]
	var blocked: Array[bool] = []
	if parts.has("Trunk"):
		var xfs := _instances(parts.Trunk)
		for i in xfs.size():
			var xf: Transform3D = xfs[i]
			anchors.append(xf.origin - Vector3(0, xf.basis.y.length() / 2.0, 0))
			members.append([["Trunk", i]])
			blocked.append(not instance_clear(trees, xf, TRUNK_UNIT, trees))
	var loose: Array = []
	for kind in ["Leaves", "Branch"]:
		if not parts.has(kind):
			continue
		var xfs := _instances(parts[kind])
		for i in xfs.size():
			var xf: Transform3D = xfs[i]
			if kind == "Branch" and xf.basis.x.length() > 0.2:
				# A bare tree's main stem: its own tree
				var foot := xf.origin - xf.basis.y / 2.0
				anchors.append(foot)
				members.append([[kind, i]])
				blocked.append(not instance_clear(trees, xf, BRANCH_UNIT, trees))
			else:
				loose.append([kind, i, xf])
	for l in loose:
		var xf: Transform3D = l[2]
		var best := -1
		var best_d := 4.0
		for t in anchors.size():
			var d := Vector2(xf.origin.x - anchors[t].x, xf.origin.z - anchors[t].z).length()
			if d < best_d:
				best_d = d
				best = t
		if best == -1:
			continue
		members[best].append([l[0], l[1]])
		if not blocked[best]:
			var unit := LEAVES_UNIT if l[0] == "Leaves" else BRANCH_UNIT
			blocked[best] = not instance_clear(trees, xf, unit, trees)
	var gone := 0
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	# The seasons (scripts/seasons.gd) keep their own copy of the leaves to repaint: tell them too
	var seasons: Node = null
	if trees.get_parent():
		for n in trees.get_parent().get_children():
			if n.has_method("hide_leaf"):
				seasons = n
				break
	for t in anchors.size():
		if not blocked[t]:
			continue
		gone += 1
		for m in members[t]:
			var mmi := parts[m[0]] as MultiMeshInstance3D
			mmi.multimesh.set_instance_transform(m[1], hidden)
			if m[0] == "Leaves" and seasons:
				seasons.hide_leaf(m[1])
			# ...and in the builder's saved copy too (scripts/multi_fill.gd), which scripts/seasons.gd refills from
			var saved = mmi.get("transforms")
			if saved is PackedFloat32Array and saved.size() >= (m[1] + 1) * 12:
				for j in 9:
					saved[m[1] * 12 + j] = 0.0
				saved[m[1] * 12 + 10] = -500.0
				mmi.set("transforms", saved)
		# ...and its trunk's solid box (a 0.6 x 2 x 0.6 body standing on the same spot)
		for c in trees.get_children():
			if c is StaticBody3D and Vector2(c.global_position.x - anchors[t].x, c.global_position.z - anchors[t].z).length() < 0.5:
				c.queue_free()
	return gone


static func _instances(mmi: MultiMeshInstance3D) -> Array:
	# Its instances as built: from the builder's saved copy (scripts/multi_fill.gd) when it has one, since a headless
	# run keeps no instance data in the MultiMesh itself
	var out := []
	var xf = mmi.get("transforms")
	if xf is PackedFloat32Array and xf.size() >= 12:
		for i: int in xf.size() / 12:
			var k: int = i * 12
			out.append(mmi.global_transform * Transform3D(Vector3(xf[k], xf[k + 1], xf[k + 2]),
				Vector3(xf[k + 3], xf[k + 4], xf[k + 5]), Vector3(xf[k + 6], xf[k + 7], xf[k + 8]),
				Vector3(xf[k + 9], xf[k + 10], xf[k + 11])))
		return out
	for i in mmi.multimesh.instance_count:
		out.append(mmi.global_transform * mmi.multimesh.get_instance_transform(i))
	return out
