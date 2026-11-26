extends Node3D

# The Secret Garden's building kit (26 Nov 2026): what every part of the rebuilt garden shares. Each part
# (secret_garden_estate.gd, secret_garden_waters.gd, secret_garden_groves.gd, secret_garden_rooms.gd) extends this
# script, is made by scripts/secret_garden.gd and borrows its little helpers (sg._mat, sg._mesh, sg._box...).
#   - stone: the estate's grey limestone, in two shades, and its paving
#   - balustrades (a plinth, vase balusters, a handrail and posts, level or sloping), urns spilling flowers
#   - stairs, drawn as steps and walked on as one smooth ramp over their nosings (like the MIT Stairs3D addon's "simple
#     collision"), since the player can't step up a ledge on foot
#   - arched bridges, cypresses, and baked models (detail_props.gd baked_mesh: the detail pipeline's, or nothing when
#     it's off, so the plain shapes are used)
# Balusters and urns pile up in two lists and are drawn as MultiMeshes at the end (finish()).

const LAND := preload("res://scripts/secret_garden_land.gd")
const WATER := preload("res://scripts/water.gd")
const DETAIL := "res://scripts/detail_props.gd"
const BALUSTER_GAP := 0.34
const RAIL_H := 1.0
const STEP_RISE := 0.17

var sg: Node3D                                  # the garden (scripts/secret_garden.gd)
var bridges := []                               # [{"name", "from", "to", "rise"}] for tests
var stairs := []                                # [{"name", "foot", "top"}] for tests
var _baluster_xf: Array[Transform3D] = []
var _urn_xf: Array[Transform3D] = []
var _hedge_xf: Array[Transform3D] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0


func start(garden: Node3D, nm: String, seed_no: int) -> void:
	sg = garden
	_rng.seed = seed_no
	name = nm
	garden.add_child(self)


static func ground(x: float, z: float) -> float:
	return LAND.height(x, z)


static func on_ground(x: float, z: float) -> Vector3:
	return Vector3(x, LAND.height(x, z), z)


func baked(kind_path: String) -> Mesh:
	# A baked model's mesh (res://models/props/...glb), or null when the detail pipeline's off or it isn't there
	var d: Script = load(DETAIL)
	return d.call("baked_mesh", kind_path)


# -----------------------------------------------------------------------------
# Materials and small helpers
# -----------------------------------------------------------------------------
func stone() -> StandardMaterial3D:
	return sg._mat("Estate Stone", Color(0.6, 0.58, 0.6), 0.85)


func stone_dark() -> StandardMaterial3D:
	return sg._mat("Estate Stone Dark", Color(0.47, 0.46, 0.5), 0.85)


func paving() -> StandardMaterial3D:
	return sg._mat("Terrace Paving", Color(0.62, 0.6, 0.58), 0.9)


func water_mat() -> StandardMaterial3D:
	return sg._mat("Garden Water", Color(0.32, 0.55, 0.62, 0.82), 0.04, 0.12)


func spray_mat() -> StandardMaterial3D:
	return sg._mat("Spray", Color(0.8, 0.93, 1.0, 0.75), 0.05, 0.4)


func group(n: String, parent: Node3D = self) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


func glow(m: StandardMaterial3D) -> StandardMaterial3D:
	# Flowers glow a little asleep and brightly once the garden wakes (secret_garden.gd _set_awake)
	if not m in sg._glows:
		sg._glows.append(m)
	return m


static func along(a: Vector3, b: Vector3) -> Basis:
	# A basis whose x runs from a to b (it may slope), y up from it and z level across it
	var x := (b - a).normalized()
	var z := Vector3(-x.z, 0, x.x).normalized()
	if z.length() < 0.5:
		z = Vector3(0, 0, 1)
	var y := z.cross(x).normalized()
	return Basis(x, y, z.normalized())


func slab(parent: Node3D, nm: String, a: Vector3, b: Vector3, size_yz: Vector2, m: Material, solid: bool, lift := 0.0) -> MeshInstance3D:
	# A box from a to b (its top lift above the line a-b, size_yz its height and width), drawn and maybe solid
	var basis := along(a, b)
	var length := a.distance_to(b)
	var centre := (a + b) / 2.0 + basis.y * (lift - size_yz.x / 2.0)
	var bm := BoxMesh.new()
	bm.size = Vector3(length, size_yz.x, size_yz.y)
	var mi := sg._mesh(parent, bm, centre, m) as MeshInstance3D
	mi.name = nm
	mi.basis = basis
	if solid:
		var bs := BoxShape3D.new()
		bs.size = bm.size
		var body: StaticBody3D = sg._solid(parent, nm + " Body", bs, centre)
		body.basis = basis
	return mi


func block(parent: Node3D, nm: String, size: Vector3, at: Vector3, m: Material, solid := true, yaw := 0.0) -> MeshInstance3D:
	return sg._box(parent, nm, size, at, m, solid, yaw)


static func lathe(profile: Array, segments := 10) -> ArrayMesh:
	# Spins a profile of [radius, height] points round the up axis (balusters, urns, finials, basins)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		for s in segments:
			var a0 := TAU * s / segments
			var a1 := TAU * (s + 1) / segments
			var v := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_uv(Vector2(float(s) / segments, p0.y if k < 2 else p1.y))
				st.add_vertex(v[k])
	st.generate_normals()
	return st.commit()


func ring_wall(parent: Node3D, nm: String, centre: Vector3, r: float, h: float, thick: float, m: Material, sides := 24, solid := true) -> void:
	# A round wall (a pool's rim, a basin), in straight lengths
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := centre + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := centre + Vector3(cos(a1), 0, sin(a1)) * r
		slab(parent, nm, p0 + Vector3(0, h, 0), p1 + Vector3(0, h, 0), Vector2(h + 0.4, thick), m, solid, 0.0)


func disc(parent: Node3D, nm: String, at: Vector3, r: float, m: Material, sides := 32) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.04
	cm.radial_segments = sides
	var mi := sg._mesh(parent, cm, at, m, false) as MeshInstance3D
	mi.name = nm
	return mi


func wade(nm: String, ellipses: Array[Vector4], y: float) -> Node3D:
	var w := WATER.new()
	w.name = nm
	w.ellipses = ellipses
	w.water_y = y
	sg.add_child(w)
	return w


# -----------------------------------------------------------------------------
# Balustrades and urns
# -----------------------------------------------------------------------------
func balustrade(parent: Node3D, a: Vector3, b: Vector3, solid := true, urns := false, posts_on := true) -> void:
	# a, b: where its foot runs (it may slope, up a stair or over a bridge)
	var length := a.distance_to(b)
	if length < 0.3:
		return
	slab(parent, "Balustrade Plinth", a, b, Vector2(0.22, 0.46), stone_dark(), false, 0.22)
	slab(parent, "Handrail", a + Vector3(0, RAIL_H, 0), b + Vector3(0, RAIL_H, 0), Vector2(0.14, 0.5), stone(), false, 0.0)
	var n := maxi(1, floori(length / BALUSTER_GAP))
	for i in n:
		var t := (i + 0.5) / n
		var at := a.lerp(b, t) + Vector3(0, 0.22, 0)
		_baluster_xf.append(Transform3D(Basis.from_scale(Vector3(1, (RAIL_H - 0.36) / 0.65, 1)), at))
	var posts := maxi(1, ceili(length / 3.6))
	for i in (posts + 1 if posts_on else 0):
		var at := a.lerp(b, float(i) / posts)
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, RAIL_H + 0.22, 0.5)
		sg._mesh(parent, pm, at + Vector3(0, (RAIL_H + 0.22) / 2.0 - 0.1, 0), stone()).name = "Balustrade Post"
		var cap := BoxMesh.new()
		cap.size = Vector3(0.62, 0.12, 0.62)
		sg._mesh(parent, cap, at + Vector3(0, RAIL_H + 0.18, 0), stone_dark()).name = "Post Cap"
		if urns and (i == 0 or i == posts):
			urn(parent, at + Vector3(0, RAIL_H + 0.24, 0))
	if solid:
		slab(parent, "Balustrade", a + Vector3(0, RAIL_H + 0.25, 0), b + Vector3(0, RAIL_H + 0.25, 0),
			Vector2(RAIL_H + 0.45, 0.5), stone(), true, 0.0).visible = false


func balustrade_run(parent: Node3D, pts: Array, solid := true, urns := false) -> void:
	for i in pts.size() - 1:
		balustrade(parent, pts[i], pts[i + 1], solid, urns and (i == 0 or i == pts.size() - 2))


func urn(parent: Node3D, at: Vector3, k := 1.0) -> void:
	# A stone urn spilling flowers that glow with the garden
	_urn_xf.append(Transform3D(Basis.from_scale(Vector3.ONE * k), at))
	var cols := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4)]
	for i in 5:
		var a := TAU * i / 5.0
		var m := glow(sg._mat("Urn Flower %d" % (i % 3), cols[i % 3], 0.6, 0.2))
		sg._ball(parent, 0.13 * k, at + Vector3(cos(a) * 0.26 * k, 0.86 * k, sin(a) * 0.26 * k), m)
	sg._ball(parent, 0.3 * k, at + Vector3(0, 0.82 * k, 0), sg._leaf(), 0.7)


# -----------------------------------------------------------------------------
# Hedges: clipped box or yew, in straight lengths (one MultiMesh: the maze's baked hedge, stretched to each length)
# -----------------------------------------------------------------------------
const HEDGE_BAKED := Vector3(5.1, 2.8, 0.9)      # the baked hedge's size (tools/build_prop_secret_garden.py hedge)


func hedge(parent: Node3D, a: Vector3, b: Vector3, height: float, thick: float, solid := true) -> void:
	# A hedge from a to b (both on the ground), height tall and thick through
	var length := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) + thick * 0.5
	if length < 0.4:
		return
	var y := minf(a.y, b.y)
	var mid := Vector3((a.x + b.x) / 2.0, y + height / 2.0, (a.z + b.z) / 2.0)
	var yaw := -atan2(b.z - a.z, b.x - a.x)
	var basis := Basis(Vector3.UP, yaw)
	_hedge_xf.append(Transform3D(basis * Basis.from_scale(Vector3(length, height, thick)), mid))
	if solid:
		var bs := BoxShape3D.new()
		bs.size = Vector3(length, height, thick)
		var body: StaticBody3D = sg._solid(parent, "Hedge Body", bs, mid)
		body.basis = basis


func _finish_hedges() -> void:
	if _hedge_xf.is_empty():
		return
	var mesh := baked("res://models/props/secret_garden/hedge.glb")
	var unit := Vector3.ONE
	if mesh:
		unit = Vector3.ONE / HEDGE_BAKED
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mesh = bm
	var xfs: Array = []
	for xf in _hedge_xf:
		xfs.append(Transform3D(xf.basis * Basis.from_scale(unit), xf.origin))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Hedges"
	mmi.multimesh = mm
	mmi.set_meta("transforms", xfs)
	mmi.visibility_range_end = 220.0
	if mesh is BoxMesh:
		mmi.material_override = sg._hedge()
	add_child(mmi)
	_hedge_xf.clear()


# -----------------------------------------------------------------------------
# Stairs: steps you see, a smooth ramp you walk on, stone cheeks with balustrades
# -----------------------------------------------------------------------------
func stair(parent: Node3D, nm: String, foot: Vector3, top: Vector3, width: float, cheeks := true, urns := true) -> void:
	# A straight stair from foot (the ground at its bottom) to top (the landing at its top), any way round
	var s := group(nm, parent)
	var rise := top.y - foot.y
	var flat := Vector3(top.x - foot.x, 0, top.z - foot.z)
	var run := flat.length()
	var dir := flat / maxf(run, 0.001)
	var across := Vector3(-dir.z, 0, dir.x)
	var steps := maxi(2, roundi(rise / STEP_RISE))
	var tread := run / steps
	var yaw := atan2(dir.x, dir.z)
	var st := stone()
	for i in steps:
		var hgt := rise * (i + 1) / steps
		var at := foot + dir * tread * (i + 0.5)
		# each step a block from its tread down to the foot's level (and a little under), so the side's solid
		var sm := BoxMesh.new()
		sm.size = Vector3(width, hgt + 0.3, tread + 0.02)
		var mi := sg._mesh(s, sm, Vector3(at.x, foot.y + (hgt - 0.3) / 2.0, at.z), st) as MeshInstance3D
		mi.name = "Step"
		mi.rotation.y = yaw
		var nmesh := BoxMesh.new()
		nmesh.size = Vector3(width, 0.06, 0.12)
		var nose := sg._mesh(s, nmesh, foot + dir * (tread * i + 0.02) + Vector3(0, hgt - 0.03, 0), stone_dark()) as MeshInstance3D
		nose.name = "Nosing"
		nose.rotation.y = yaw
	# The ramp runs over the nosings, from the first step's front to the top
	var a := foot - dir * tread + Vector3(0, 0.0, 0)
	var b := top - dir * tread
	slab(s, "Stair Ramp", a, b, Vector2(0.3, width), st, true, 0.0).visible = false
	slab(s, "Stair Landing", b, top + dir * 0.4, Vector2(0.3, width), st, true, 0.0).visible = false
	if cheeks:
		for side: float in [-1.0, 1.0]:
			var off := across * side * (width / 2.0 + 0.3)
			var c0 := foot + off + Vector3(0, 0.4, 0)
			var c1 := top + off + Vector3(0, 0.05, 0)
			slab(s, "Stair Cheek", c0, c1, Vector2(maxf(rise, 1.0) + 1.0, 0.6), st, true, 0.0)
			balustrade(s, c0, c1, true)
			block(s, "Newel", Vector3(0.75, 1.5, 0.75), foot + off - dir * 0.1 + Vector3(0, 0.75, 0), stone_dark(), true)
			if urns:
				urn(s, foot + off - dir * 0.1 + Vector3(0, 1.5, 0), 1.2 if width > 6.0 else 1.0)
	stairs.append({"name": nm, "foot": foot - dir * (tread + 0.8), "top": top + dir * 1.2})


# -----------------------------------------------------------------------------
# Bridges: arched, in short solid lengths, with balustrades or a low parapet
# -----------------------------------------------------------------------------
func bridge(parent: Node3D, nm: String, a: Vector3, b: Vector3, rise: float, width: float, rails: bool, m: Material = null, under := 0.0, rail_m: Material = null) -> Node3D:
	# An arched bridge from a to b (each on the ground at its end). under: how far down its sides reach. rail_m: a
	# wooden railing in that colour (posts and two rails) instead of a stone balustrade or parapet.
	var g := group(nm, parent)
	var n := 12
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3(0, rise * sin(PI * t), 0))
	var st := m if m else stone()
	var basis := along(a, b)
	for i in n:
		slab(g, "Bridge Deck", pts[i], pts[i + 1], Vector2(0.35, width), st, true, 0.0)
		var mid := (pts[i] + pts[i + 1]) / 2.0
		var lowest := minf(a.y, b.y) - under
		if mid.y - lowest > 0.15:
			var sp := BoxMesh.new()
			sp.size = Vector3(pts[i].distance_to(pts[i + 1]) + 0.05, mid.y - lowest, width - 0.1)
			var smi := sg._mesh(g, sp, Vector3(mid.x, (mid.y + lowest) / 2.0 - 0.17, mid.z), st) as MeshInstance3D
			smi.name = "Bridge Spandrel"
			smi.basis = basis
		for side: float in [-1.0, 1.0]:
			var off := basis.z * side * (width / 2.0 - 0.25)
			if rail_m:
				slab(g, "Top Rail", pts[i] + off + Vector3(0, 1.0, 0), pts[i + 1] + off + Vector3(0, 1.0, 0),
					Vector2(0.12, 0.16), rail_m, false, 0.0)
				slab(g, "Mid Rail", pts[i] + off + Vector3(0, 0.5, 0), pts[i + 1] + off + Vector3(0, 0.5, 0),
					Vector2(0.08, 0.1), rail_m, false, 0.0)
				var pm := BoxMesh.new()
				pm.size = Vector3(0.16, 1.15, 0.16)
				sg._mesh(g, pm, pts[i] + off + Vector3(0, 0.5, 0), rail_m).name = "Rail Post"
				if i == n - 1:
					sg._mesh(g, pm, pts[n] + off + Vector3(0, 0.5, 0), rail_m).name = "Rail Post"
				slab(g, "Railing", pts[i] + off + Vector3(0, 1.1, 0), pts[i + 1] + off + Vector3(0, 1.1, 0),
					Vector2(1.2, 0.2), rail_m, true, 0.0).visible = false
			elif rails:
				balustrade(g, pts[i] + off, pts[i + 1] + off, true, false, false)
			else:
				slab(g, "Parapet", pts[i] + off + Vector3(0, 0.6, 0), pts[i + 1] + off + Vector3(0, 0.6, 0),
					Vector2(0.6, 0.4), stone_dark(), true, 0.0)
	bridges.append({"name": nm, "from": a, "to": b, "rise": rise})
	return g


# -----------------------------------------------------------------------------
# Trees: every kind is built of three shapes (a trunk, limbs and balls of leaves), each drawn as one MultiMesh per
# colour (the baked nature shapes when the detail pipeline's on: tools/build_prop_nature.py), and each trunk is solid.
# -----------------------------------------------------------------------------
const NATURE := "res://models/props/nature/%s.glb"
# Bark and leaf colours (sRGB), by name
const BARKS := {"oak": Color(0.4, 0.33, 0.3), "pale": Color(0.86, 0.84, 0.8), "red": Color(0.55, 0.3, 0.24),
	"dark": Color(0.28, 0.23, 0.22), "grey": Color(0.52, 0.5, 0.5), "palm": Color(0.56, 0.46, 0.36)}
const LEAVES := {"oak": Color(0.24, 0.46, 0.24), "oak_light": Color(0.36, 0.56, 0.28), "cedar": Color(0.16, 0.34, 0.3),
	"maple_red": Color(0.86, 0.22, 0.16), "maple_orange": Color(0.95, 0.52, 0.16), "maple_gold": Color(0.98, 0.78, 0.25),
	"birch": Color(0.55, 0.74, 0.32), "copper": Color(0.45, 0.2, 0.28), "redwood": Color(0.18, 0.36, 0.22),
	"cypress": Color(0.15, 0.33, 0.23), "willow": Color(0.52, 0.7, 0.32), "blossom": Color(1.0, 0.74, 0.86),
	"pine": Color(0.17, 0.36, 0.26), "palm": Color(0.3, 0.6, 0.28), "lime": Color(0.62, 0.78, 0.3)}
var _tree_parts := {}                          # "trunk|oak" -> [transforms] (and "limb|...", "leaf|...")
var trees := []                                # [{"kind", "at", "height"}] for tests and the scatter


func _part(kind: String, colour: String, xf: Transform3D) -> void:
	var key := kind + "|" + colour
	if not _tree_parts.has(key):
		_tree_parts[key] = []
	_tree_parts[key].append(xf)


func trunk(at: Vector3, r: float, h: float, bark: String, solid := true, lean := Vector3.ZERO) -> Vector3:
	# A trunk from at (sunk a little into the ground) up h; returns its top
	var up := (Vector3.UP + lean).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var basis := Basis(side, up, side.cross(up)) * Basis.from_scale(Vector3(r, h + 0.4, r))
	var base := at - Vector3(0, 0.4, 0)
	_part("trunk", bark, Transform3D(basis, base + up * (h + 0.4) / 2.0))
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = r * 0.85
		cs.height = h
		var body: StaticBody3D = sg._solid(self, "Tree Trunk Body", cs, at + up * h / 2.0)
		body.basis = Basis(side, up, side.cross(up))
	return at + up * h


func limb(a: Vector3, b: Vector3, r: float, bark: String) -> void:
	var up := (b - a).normalized()
	var side := up.cross(Vector3.UP).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var basis := Basis(side, up, side.cross(up).normalized()) * Basis.from_scale(Vector3(r, a.distance_to(b), r))
	_part("limb", bark, Transform3D(basis, (a + b) / 2.0))


func leaves(at: Vector3, r: float, colour: String, squash := 1.0, yaw := 0.0) -> void:
	_part("leaf", colour, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(r, r * squash, r)), at))


func tree(kind: String, at: Vector3, k := 1.0) -> void:
	# One tree of a kind, k its size. Each is our own simple take on the tree, not a botanical model.
	var yaw := _rng.randf() * TAU
	var h := 0.0
	match kind:
		"oak":
			h = 7.0 * k
			var top := trunk(at, 1.0 * k, h, "oak")
			for i in 5:
				var a := yaw + TAU * i / 5.0
				var out := Vector3(cos(a), 0, sin(a))
				var tip := at + out * 5.0 * k + Vector3(0, h + 2.4 * k, 0)
				limb(top - Vector3(0, 1.2 * k, 0), tip, 0.42 * k, "oak")
				leaves(tip + Vector3(0, 0.9 * k, 0), _rng.randf_range(3.2, 4.0) * k, "oak" if i % 2 else "oak_light", 0.72)
			leaves(top + Vector3(0, 3.6 * k, 0), 5.0 * k, "oak", 0.75)
			h += 7.0 * k
		"cedar":
			# Cedar of Lebanon: a stout trunk and flat layers of dark leaves, like shelves
			h = 12.0 * k
			trunk(at, 0.9 * k, h, "dark")
			for i in 5:
				var y := (3.5 + i * 2.2) * k
				var w := (8.0 - i * 1.2) * k
				var a := yaw + i * 1.3
				var off := Vector3(cos(a), 0, sin(a)) * 1.4 * k
				leaves(at + off + Vector3(0, y, 0), w, "cedar", 0.22, a)
				limb(at + Vector3(0, y - 0.6, 0), at + off * 2.0 + Vector3(0, y, 0), 0.25 * k, "dark")
			h += 2.0 * k
		"maple_red", "maple_orange", "maple_gold":
			h = 4.5 * k
			var top := trunk(at, 0.55 * k, h, "grey")
			for i in 4:
				var a := yaw + TAU * i / 4.0
				var tip := at + Vector3(cos(a), 0, sin(a)) * 2.6 * k + Vector3(0, h + 1.6 * k, 0)
				limb(top - Vector3(0, 0.6 * k, 0), tip, 0.22 * k, "grey")
				leaves(tip + Vector3(0, 0.6 * k, 0), 2.4 * k, kind, 0.75)
			leaves(top + Vector3(0, 2.6 * k, 0), 3.2 * k, kind, 0.8)
			h += 5.0 * k
		"redwood":
			# Very tall, a red furrowed trunk, a narrow spire of leaves from halfway up
			h = 30.0 * k
			trunk(at, 1.5 * k, h, "red")
			for i in 8:
				var y := (12.0 + i * 2.8) * k
				leaves(at + Vector3(0, y, 0), (4.6 - i * 0.48) * k, "redwood", 0.55, yaw + i)
			h += 2.0 * k
		"birch":
			h = 9.0 * k
			trunk(at, 0.3 * k, h, "pale")
			for i in 3:
				var a := yaw + TAU * i / 3.0
				leaves(at + Vector3(cos(a) * 1.0 * k, h - (1.0 + i) * k, sin(a) * 1.0 * k), 1.9 * k, "birch", 1.2)
			leaves(at + Vector3(0, h + 0.4 * k, 0), 1.6 * k, "birch", 1.4)
			h += 2.0 * k
		"copper":
			h = 6.0 * k
			var top := trunk(at, 0.8 * k, h, "grey")
			leaves(top + Vector3(0, 3.2 * k, 0), 5.2 * k, "copper", 0.8)
			for i in 3:
				var a := yaw + TAU * i / 3.0
				leaves(top + Vector3(cos(a) * 3.2 * k, 1.6 * k, sin(a) * 3.2 * k), 3.4 * k, "copper", 0.7)
			h += 7.0 * k
		"willow":
			# A weeping willow by the water: a broad dome of leaves hanging right down
			h = 5.5 * k
			var top := trunk(at, 0.75 * k, h, "grey")
			leaves(top + Vector3(0, 1.2 * k, 0), 5.0 * k, "willow", 0.55)
			for i in 9:
				var a := yaw + TAU * i / 9.0
				leaves(at + Vector3(cos(a) * 4.4 * k, h - 1.2 * k, sin(a) * 4.4 * k), 1.6 * k, "willow", 2.2)
			h += 4.0 * k
		"blossom":
			h = 3.6 * k
			var top := trunk(at, 0.4 * k, h, "dark", true, Vector3(0.15, 0, 0.1))
			for i in 4:
				var a := yaw + TAU * i / 4.0
				leaves(top + Vector3(cos(a) * 1.9 * k, 0.6 * k, sin(a) * 1.9 * k), 1.8 * k, "blossom", 0.7)
			leaves(top + Vector3(0, 1.4 * k, 0), 2.2 * k, "blossom", 0.7)
			h += 3.0 * k
		"pine":
			# A Japanese garden pine: a leaning trunk and flat cloud pads of needles
			h = 5.0 * k
			var lean := Vector3(cos(yaw), 0, sin(yaw)) * 0.35
			var top := trunk(at, 0.45 * k, h, "dark", true, lean)
			for i in 4:
				var a := yaw + 1.7 * i
				var tip := top + Vector3(cos(a) * 2.4 * k, (-1.4 + i * 0.7) * k, sin(a) * 2.4 * k)
				limb(top - Vector3(0, 0.8 * k, 0), tip, 0.16 * k, "dark")
				leaves(tip, 1.7 * k, "pine", 0.38, a)
			leaves(top + Vector3(0, 0.6 * k, 0), 1.9 * k, "pine", 0.4)
			h += 1.5 * k
		"cypress":
			h = 1.2 * k
			trunk(at, 0.22 * k, 1.4 * k, "oak")
			leaves(at + Vector3(0, 0.6 * k + 4.0 * k, 0), 1.0 * k, "cypress", 4.2)
			h = 8.8 * k
		"palm":
			h = 8.0 * k
			var lean := Vector3(cos(yaw), 0, sin(yaw)) * 0.18
			var top := trunk(at, 0.32 * k, h, "palm", true, lean)
			for i in 7:
				var a := yaw + TAU * i / 7.0
				leaves(top + Vector3(cos(a) * 1.8 * k, -0.4 * k, sin(a) * 1.8 * k), 1.9 * k, "palm", 0.3, a)
			leaves(top + Vector3(0, 0.2 * k, 0), 1.0 * k, "palm", 0.8)
	trees.append({"kind": kind, "at": at, "height": h})


func cypress(parent: Node3D, at: Vector3, k: float) -> void:
	tree("cypress", at, k)


func _finish_trees() -> void:
	if _tree_parts.is_empty():
		return
	var d: Script = load(DETAIL)
	var meshes := {"trunk": baked(NATURE % "bark_trunk"), "limb": baked(NATURE % "bark_limb"), "leaf": baked(NATURE % "leaf_ball")}
	var plain := {}
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.56
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 10
	plain["trunk"] = cyl
	var lcyl := CylinderMesh.new()
	lcyl.top_radius = 0.4
	lcyl.bottom_radius = 1.0
	lcyl.height = 1.0
	lcyl.radial_segments = 8
	plain["limb"] = lcyl
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	plain["leaf"] = ball
	var g := group("Trees")
	for key: String in _tree_parts:
		var bits := key.split("|")
		var part := bits[0]
		var colour: Color = (LEAVES if part == "leaf" else BARKS)[bits[1]]
		var mesh: Mesh = meshes[part] if meshes[part] else plain[part]
		var m: StandardMaterial3D = null
		if meshes[part]:
			m = d.call("_nature_mat", mesh, colour, {"trunk": "bark_trunk", "limb": "bark_limb", "leaf": "leaf_ball"}[part])
		if m == null:
			m = sg._mat(("Leaves " if part == "leaf" else "Bark ") + bits[1], colour, 0.9)
		var xfs: Array = _tree_parts[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Tree %s %s" % [part.capitalize(), bits[1]]
		mmi.multimesh = mm
		mmi.material_override = m
		mmi.set_meta("transforms", xfs)
		mmi.visibility_range_end = 260.0
		g.add_child(mmi)
	_tree_parts.clear()


# -----------------------------------------------------------------------------
# The end: balusters and urns into MultiMeshes, baked patches on the stone
# -----------------------------------------------------------------------------
func finish(surfaces: Array) -> void:
	_finish_trees()
	_finish_hedges()
	var baluster := lathe([Vector2(0.1, 0.0), Vector2(0.1, 0.05), Vector2(0.065, 0.08), Vector2(0.05, 0.13),
		Vector2(0.105, 0.27), Vector2(0.115, 0.33), Vector2(0.085, 0.42), Vector2(0.042, 0.52), Vector2(0.052, 0.56),
		Vector2(0.085, 0.6), Vector2(0.085, 0.65)])
	var urn_mesh := lathe([Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.07), Vector2(0.1, 0.11), Vector2(0.08, 0.22),
		Vector2(0.15, 0.28), Vector2(0.3, 0.44), Vector2(0.36, 0.6), Vector2(0.34, 0.7), Vector2(0.41, 0.74),
		Vector2(0.41, 0.8), Vector2(0.3, 0.82), Vector2(0.0, 0.8)], 14)
	var b_baked := baked("res://models/props/estate/baluster.glb")
	var u_baked := baked("res://models/props/estate/urn.glb")
	for pair in [["Balusters", b_baked if b_baked else baluster, _baluster_xf, b_baked != null],
			["Urns", u_baked if u_baked else urn_mesh, _urn_xf, u_baked != null]]:
		var xfs: Array = pair[2]
		if xfs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[1]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pair[0]
		mmi.multimesh = mm
		mmi.set_meta("transforms", xfs)
		mmi.visibility_range_end = 140.0
		if not pair[3]:
			mmi.material_override = stone()
		add_child(mmi)
	var d: Script = load(DETAIL)
	d.call("dress_place", self, surfaces)
	if not b_baked:
		for n in ["Balusters", "Urns"]:
			var mmi := get_node_or_null(n) as MultiMeshInstance3D
			if mmi:
				var m: StandardMaterial3D = d.call("world_patched", mmi.material_override as StandardMaterial3D, "stone", 0.5)
				if m:
					mmi.material_override = m


func _process(delta: float) -> void:
	_t += delta
	step(delta)


func step(_delta: float) -> void:
	pass
