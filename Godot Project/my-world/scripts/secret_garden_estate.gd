extends Node3D

# The Secret Garden's old estate (26 Nov 2026, Hayden: "Can you make the secret garden look like the doheny estate
# garden in beverley hills with architecture, fountain, bridges, trees"). Inspired by the gardens round Greystone, the
# Doheny family's old stone house in Beverly Hills, not a copy of it: our own grey stone house and gardens.
#   - the Old House: a grey stone Tudor-style manor along the north wall, steep slate roofs, three front gables, tall
#     chimney stacks and mullioned windows glowing amber. Nobody's lived there for years (you can't go in).
#   - the Upper Terrace in front of it, 2.4 m up, paved, with a stone balustrade, urns, clipped topiary and benches,
#     reached by a grand stair in the middle and two side stairs
#   - the Fountain Court: the old fountain gets a wide stone pool round it with arching jets, inside a parterre of
#     clipped box hedges
#   - the Brook: it springs from a lion-head spout in the terrace wall and winds down to the Lily Pond, with two little
#     stone footbridges over it, and a big balustraded stone bridge out to the pond's island
#   - an allee of tall cypresses up the middle, and great old oaks round the lawns
# The old garden (Rose Walk, maze, pond, giant flowers, Great Tree, the five sleeping seeds) is all still there, where
# it was. Stairs and bridges are drawn as steps and arches but walked on as smooth ramps under them (like the MIT
# Stairs3D addon's "simple collision"), since the player can't step up a ledge on foot.
#
# Made by scripts/secret_garden.gd (_estate(), as a child "Estate"); it borrows that script's little helpers. Every new
# stone, slate, paving, bark and door material wears a baked surface patch from the detail pipeline (dress_place, below);
# the leaves, hedges and cypresses become the baked leaf balls and hedges (detail_props.gd dress_secret_garden).

const WATER := preload("res://scripts/water.gd")

const TERRACE_Y := 2.4
const TERRACE_Z := Vector2(124.0, 149.5)       # the Upper Terrace: from its front wall back to the garden's north wall
const TERRACE_X := 36.0
const HOUSE_Z := Vector2(137.0, 148.0)         # the Old House's main block
const HOUSE_X := 22.0
const STAIR_RUN := 5.6                          # how far a stair reaches out from the terrace wall
const STAIRS := [[0.0, 9.0], [-20.0, 4.0], [20.0, 4.0]]   # [middle x, width]
const POOL_R := 6.4                             # the Fountain Court's wide pool round the old basin
const POOL_Y := 0.34
const PARTERRE_R := Vector2(7.6, 11.0)          # its hedged beds, between these radii
const BROOK := [Vector2(30, 122.6), Vector2(33, 112), Vector2(38, 100), Vector2(41, 88), Vector2(40, 76), Vector2(40, 67.5)]
const BROOK_W := 2.8
const BROOK_Y := 0.2
const OAKS := [Vector2(-56, 18), Vector2(56, 20), Vector2(-24, 22), Vector2(22, 26), Vector2(-24, 84), Vector2(-56, 92),
	Vector2(58, 98), Vector2(56, 134), Vector2(-56, 138), Vector2(18, 74)]
const BALUSTER_GAP := 0.34
const RAIL_H := 1.0

# Which of the estate's materials wear which baked patch (detail_props.gd dress_place), and how big it's laid on
const ESTATE_SURFACES := [["Estate Stone", "stone", 1.0], ["Estate Stone Dark", "stone", 0.8],
	["Terrace Paving", "stone", 1.6], ["Slate Roof", "shingles", 0.9], ["Chimney Brick", "brick", 0.7],
	["Oak Bark", "bark", 0.8], ["Oak Door", "barn_boards", 0.6], ["Brook Stone", "rock", 0.7],
	["Brook Bed", "rock", 1.0]]

var sg: Node3D                                  # the garden (scripts/secret_garden.gd)
var bridges := []                               # [{"name", "from", "to", "rise"}] for tests
var stairs := []                                # [{"x", "width", "foot", "top"}] for tests
var _baluster_xf: Array[Transform3D] = []
var _urn_xf: Array[Transform3D] = []
var _jets: Array[Node3D] = []
var _falls: Array[MeshInstance3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func build(garden: Node3D) -> void:
	sg = garden
	_rng.seed = 2611
	name = "Estate"
	garden.add_child(self)
	_terrace()
	_house()
	for s in STAIRS:
		_stair(s[0], s[1])
	_fountain_court()
	_brook()
	_pond_bridge()
	_trees()
	_paths()
	_multis()
	_dress()


# -----------------------------------------------------------------------------
# Materials and small helpers
# -----------------------------------------------------------------------------
func _stone() -> StandardMaterial3D:
	return sg._mat("Estate Stone", Color(0.56, 0.55, 0.6), 0.85)


func _stone_dark() -> StandardMaterial3D:
	return sg._mat("Estate Stone Dark", Color(0.44, 0.43, 0.5), 0.85)


func _group(n: String, parent: Node3D = self) -> Node3D:
	var g := Node3D.new()
	g.name = n
	parent.add_child(g)
	return g


func _along(a: Vector3, b: Vector3) -> Basis:
	# A basis whose x runs from a to b (it may slope), y up from it and z level across it
	var x := (b - a).normalized()
	var z := Vector3(-x.z, 0, x.x).normalized()
	if z.length() < 0.5:
		z = Vector3(0, 0, 1)
	var y := z.cross(x).normalized()
	return Basis(x, y, z.normalized())


func _slab(parent: Node3D, nm: String, a: Vector3, b: Vector3, size_yz: Vector2, m: Material, solid: bool, lift := 0.0) -> MeshInstance3D:
	# A box from a to b (its top lift above the line a-b, size_yz its height and width), drawn and maybe solid
	var basis := _along(a, b)
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


func _lathe(profile: Array, segments := 10) -> ArrayMesh:
	# Spins a profile of [radius, height] points round the up axis (balusters, urns, finials)
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


# -----------------------------------------------------------------------------
# Balustrades: a plinth, vase balusters, a handrail and square posts, level or sloping
# -----------------------------------------------------------------------------
func balustrade(parent: Node3D, a: Vector3, b: Vector3, solid := true, urns := false, posts_on := true) -> void:
	# a, b: where its foot runs (it may slope, up a stair or over a bridge)
	var stone := _stone()
	var dark := _stone_dark()
	var length := a.distance_to(b)
	_slab(parent, "Balustrade Plinth", a, b, Vector2(0.22, 0.46), dark, false, 0.22)
	_slab(parent, "Handrail", a + Vector3(0, RAIL_H, 0), b + Vector3(0, RAIL_H, 0), Vector2(0.14, 0.5), stone, false, 0.0)
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
		sg._mesh(parent, pm, at + Vector3(0, (RAIL_H + 0.22) / 2.0 - 0.1, 0), stone).name = "Balustrade Post"
		var cap := BoxMesh.new()
		cap.size = Vector3(0.62, 0.12, 0.62)
		sg._mesh(parent, cap, at + Vector3(0, RAIL_H + 0.18, 0), dark).name = "Post Cap"
		if urns and (i == 0 or i == posts):
			_urn_xf.append(Transform3D(Basis(), at + Vector3(0, RAIL_H + 0.24, 0)))
	if solid:
		_slab(parent, "Balustrade", a + Vector3(0, RAIL_H + 0.25, 0), b + Vector3(0, RAIL_H + 0.25, 0),
			Vector2(RAIL_H + 0.45, 0.5), stone, true, 0.0).visible = false


func _urn(parent: Node3D, at: Vector3, big := false) -> void:
	# A stone urn on a post or a plinth, spilling flowers that glow with the garden
	_urn_xf.append(Transform3D(Basis.from_scale(Vector3.ONE * (1.4 if big else 1.0)), at))
	var k := 1.4 if big else 1.0
	var cols := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4)]
	for i in 5:
		var a := TAU * i / 5.0
		var m: StandardMaterial3D = sg._mat("Urn Flower %d" % (i % 3), cols[i % 3], 0.6, 0.2)
		if not m in sg._glows:
			sg._glows.append(m)
		sg._ball(parent, 0.13 * k, at + Vector3(cos(a) * 0.26 * k, 0.86 * k, sin(a) * 0.26 * k), m)
	sg._ball(parent, 0.3 * k, at + Vector3(0, 0.82 * k, 0), sg._leaf(), 0.7)


# -----------------------------------------------------------------------------
# The Upper Terrace
# -----------------------------------------------------------------------------
func _terrace() -> void:
	var t := _group("Upper Terrace")
	var depth := TERRACE_Z.y - TERRACE_Z.x
	var mid_z := (TERRACE_Z.x + TERRACE_Z.y) / 2.0
	sg._box(t, "Terrace", Vector3(TERRACE_X * 2.0, TERRACE_Y, depth), Vector3(0, TERRACE_Y / 2.0, mid_z), _stone())
	var paving: StandardMaterial3D = sg._mat("Terrace Paving", Color(0.47, 0.45, 0.47), 0.9)
	sg._box(t, "Terrace Paving", Vector3(TERRACE_X * 2.0 - 0.2, 0.04, depth - 0.2), Vector3(0, TERRACE_Y + 0.02, mid_z), paving, false)
	# The front wall: a cornice along its top, a plinth at its foot and pilasters every few metres
	var dark := _stone_dark()
	sg._box(t, "Terrace Cornice", Vector3(TERRACE_X * 2.0 + 0.4, 0.3, 0.6), Vector3(0, TERRACE_Y - 0.15, TERRACE_Z.x + 0.1), dark, false)
	sg._box(t, "Terrace Plinth", Vector3(TERRACE_X * 2.0 + 0.3, 0.5, 0.5), Vector3(0, 0.25, TERRACE_Z.x + 0.05), dark, false)
	for side: float in [-1.0, 1.0]:
		sg._box(t, "Terrace Cornice", Vector3(0.6, 0.3, depth), Vector3(side * (TERRACE_X + 0.1), TERRACE_Y - 0.15, mid_z), dark, false)
	var x := -TERRACE_X + 1.0
	while x < TERRACE_X - 0.5:
		var in_stair := false
		for s in STAIRS:
			if absf(x - s[0]) < s[1] / 2.0 + 1.0:
				in_stair = true
		if not in_stair:
			sg._box(t, "Pilaster", Vector3(0.7, TERRACE_Y - 0.3, 0.25), Vector3(x, (TERRACE_Y - 0.3) / 2.0, TERRACE_Z.x - 0.1), _stone(), false)
		x += 4.5
	# The balustrade along the front, with gaps for the three stairs, and down both ends
	var cuts := []
	for s in STAIRS:
		cuts.append(Vector2(s[0] - s[1] / 2.0 - 0.25, s[0] + s[1] / 2.0 + 0.25))
	cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var from := -TERRACE_X + 0.25
	var top_z := TERRACE_Z.x + 0.25
	for c: Vector2 in cuts:
		balustrade(t, Vector3(from, TERRACE_Y, top_z), Vector3(c.x, TERRACE_Y, top_z), true, true)
		from = c.y
	balustrade(t, Vector3(from, TERRACE_Y, top_z), Vector3(TERRACE_X - 0.25, TERRACE_Y, top_z), true, true)
	for side: float in [-1.0, 1.0]:
		balustrade(t, Vector3(side * (TERRACE_X - 0.25), TERRACE_Y, top_z), Vector3(side * (TERRACE_X - 0.25), TERRACE_Y, TERRACE_Z.y - 0.6))
	# Planters with clipped topiary balls, and benches looking out over the garden
	for px: float in [-30.0, -11.0, 11.0, 30.0]:
		sg._box(t, "Planter", Vector3(1.3, 0.7, 1.3), Vector3(px, TERRACE_Y + 0.35, 128.5), _stone(), true)
		sg._ball(t, 0.85, Vector3(px, TERRACE_Y + 1.45, 128.5), sg._hedge(), 1.0)
	for bx: float in [-25.0, -15.0, 15.0, 25.0]:
		sg._box(t, "Bench", Vector3(2.0, 0.45, 0.6), Vector3(bx, TERRACE_Y + 0.23, 126.2), sg._mat("Bench Wood", Color(0.55, 0.38, 0.32)), true, 0.0)
	# The lion-head spouts in the wall either side of the grand stair: the east one is where the Brook springs from
	for wx: float in [-10.0, 30.0]:
		_wall_fountain(t, wx)


func _wall_fountain(parent: Node3D, x: float) -> void:
	var f := _group("Wall Fountain", parent)
	f.position = Vector3(x, 0, TERRACE_Z.x)
	var dark := _stone_dark()
	sg._box(f, "Spout Panel", Vector3(1.6, 1.6, 0.2), Vector3(0, 1.5, -0.1), dark, false)
	var head := sg._ball(f, 0.38, Vector3(0, 1.55, -0.32), _stone(), 0.9) as MeshInstance3D
	head.name = "Lion Head"
	for side: float in [-1.0, 1.0]:
		sg._ball(f, 0.14, Vector3(side * 0.28, 1.85, -0.3), _stone(), 1.0).name = "Lion Ear"
	sg._cyl(f, "Spout", 0.05, 0.05, 0.3, Vector3(0, 1.4, -0.6), dark, false).rotation.x = PI / 2.0
	var bowl := CylinderMesh.new()
	bowl.top_radius = 1.2
	bowl.bottom_radius = 1.0
	bowl.height = 0.55
	bowl.radial_segments = 20
	sg._mesh(f, bowl, Vector3(0, 0.27, -1.0), _stone()).name = "Spout Basin"
	sg._cyl(f, "Spout Water", 1.05, 1.05, 0.05, Vector3(0, 0.5, -1.0), sg._mat("Fountain Water", Color(0.45, 0.75, 0.95, 0.8), 0.05, 0.3), false)
	var fall := BoxMesh.new()
	fall.size = Vector3(0.12, 0.95, 0.06)
	var fm := sg._mesh(f, fall, Vector3(0, 0.95, -0.78), sg._mat("Spray", Color(0.7, 0.9, 1.0, 0.7), 0.05, 0.4), false) as MeshInstance3D
	fm.name = "Spout Fall"
	_falls.append(fm)


# -----------------------------------------------------------------------------
# The Old House
# -----------------------------------------------------------------------------
func _house() -> void:
	var h := _group("Old House")
	var y0 := TERRACE_Y
	var stone := _stone()
	var dark := _stone_dark()
	var slate: StandardMaterial3D = sg._mat("Slate Roof", Color(0.32, 0.33, 0.42), 0.75)
	var wall_h := 9.0
	var depth := HOUSE_Z.y - HOUSE_Z.x
	var mid_z := (HOUSE_Z.x + HOUSE_Z.y) / 2.0
	sg._box(h, "House Wall", Vector3(HOUSE_X * 2.0, wall_h, depth), Vector3(0, y0 + wall_h / 2.0, mid_z), stone)
	sg._box(h, "House Plinth", Vector3(HOUSE_X * 2.0 + 0.4, 0.6, depth + 0.4), Vector3(0, y0 + 0.3, mid_z), dark, false)
	sg._box(h, "String Course", Vector3(HOUSE_X * 2.0 + 0.3, 0.25, depth + 0.3), Vector3(0, y0 + 4.3, mid_z), dark, false)
	# The main roof, steep slate, its ridge along the house, with stone gable walls at both ends
	_gable_roof(h, Vector3(0, y0 + wall_h, mid_z), HOUSE_X * 2.0 + 0.6, depth + 0.8, 6.5, true, slate)
	for side: float in [-1.0, 1.0]:
		_gable_wall(h, Vector3(side * (HOUSE_X + 0.45), y0 + wall_h - 0.1, mid_z), depth + 0.5, 6.8, PI / 2.0)
	# Three gabled bays stand forward of it: a big one in the middle with the door, a smaller one either side
	for b in [[-14.0, 8.0, 3.2, wall_h], [0.0, 10.0, 3.8, wall_h + 1.5], [14.0, 8.0, 3.2, wall_h]]:
		var bx: float = b[0]
		var bw: float = b[1]
		var bd: float = b[2]
		var bh: float = b[3]
		var front := HOUSE_Z.x - bd
		sg._box(h, "Bay Wall", Vector3(bw, bh, bd + 0.2), Vector3(bx, y0 + bh / 2.0, front + (bd + 0.2) / 2.0), stone)
		sg._box(h, "Bay Plinth", Vector3(bw + 0.4, 0.6, bd + 0.4), Vector3(bx, y0 + 0.3, front + bd / 2.0), dark, false)
		sg._box(h, "String Course", Vector3(bw + 0.3, 0.25, bd + 0.3), Vector3(bx, y0 + 4.3, front + bd / 2.0), dark, false)
		var gh := 5.2 if bw < 9.0 else 6.4
		_gable_roof(h, Vector3(bx, y0 + bh, front + 3.5), bw + 0.6, 7.4, gh, false, slate)
		_gable_wall(h, Vector3(bx, y0 + bh - 0.1, front - 0.35), bw + 0.4, gh + 0.35, 0.0)
		_quoins(h, Vector3(bx - bw / 2.0, y0, front), bh)
		_quoins(h, Vector3(bx + bw / 2.0, y0, front), bh)
		if bw < 9.0:
			_window(h, Vector3(bx, y0 + 2.2, front), 4.4, 2.4, 4)
			_window(h, Vector3(bx, y0 + 6.4, front), 4.4, 2.4, 4)
			_window(h, Vector3(bx, y0 + bh + 1.9, front - 0.55), 1.6, 1.8, 2)
		else:
			_door(h, Vector3(bx, y0, front))
			_window(h, Vector3(bx, y0 + 6.8, front), 5.2, 3.0, 5)
			_window(h, Vector3(bx, y0 + bh + 2.3, front - 0.55), 2.0, 2.2, 2)
	for wx: float in [-20.0, -7.5, 7.5, 20.0]:
		var ww := 2.2 if absf(wx) > 15.0 else 3.0
		_window(h, Vector3(wx, y0 + 2.2, HOUSE_Z.x), ww, 2.4, 2 if ww < 2.5 else 3)
		_window(h, Vector3(wx, y0 + 6.4, HOUSE_Z.x), ww, 2.4, 2 if ww < 2.5 else 3)
	for side: float in [-1.0, 1.0]:
		for wz: float in [140.0, 145.0]:
			_window(h, Vector3(side * HOUSE_X, y0 + 2.2, wz), 2.2, 2.4, 2, side * PI / 2.0)
			_window(h, Vector3(side * HOUSE_X, y0 + 6.4, wz), 2.2, 2.4, 2, side * PI / 2.0)
		_quoins(h, Vector3(side * HOUSE_X, y0, HOUSE_Z.x), wall_h)
	# Tall chimney stacks of clustered shafts, Tudor style
	for cx: float in [-18.0, -7.0, 7.0, 18.0]:
		_chimney(h, Vector3(cx, y0 + wall_h + 2.5, mid_z + 1.2))


func _gable_roof(parent: Node3D, base: Vector3, length: float, span: float, rise: float, along_x: bool, m: Material) -> void:
	# A steep pitched roof: a prism, ridge along x (or along z, for a bay's gable), sitting on base
	var pm := PrismMesh.new()
	pm.size = Vector3(span, rise, length) if along_x else Vector3(length, rise, span)
	var mi := sg._mesh(parent, pm, base + Vector3(0, rise / 2.0, 0), m) as MeshInstance3D
	mi.name = "Roof"
	if along_x:
		mi.rotation.y = PI / 2.0
	# a ridge of dark stone along the top
	var ridge := BoxMesh.new()
	ridge.size = Vector3(length, 0.22, 0.3) if along_x else Vector3(0.3, 0.22, span)
	sg._mesh(parent, ridge, base + Vector3(0, rise + 0.02, 0), _stone_dark()).name = "Ridge"


func _gable_wall(parent: Node3D, base: Vector3, width: float, rise: float, yaw: float) -> void:
	# The stone gable end over a roof's slates (a thin prism a touch bigger than the roof), with a finial on top
	var pm := PrismMesh.new()
	pm.size = Vector3(width, rise, 0.35)
	var mi := sg._mesh(parent, pm, base + Vector3(0, rise / 2.0, 0), _stone()) as MeshInstance3D
	mi.name = "Gable"
	mi.rotation.y = yaw
	var fin := sg._mesh(parent, _lathe([Vector2(0.18, 0), Vector2(0.18, 0.3), Vector2(0.1, 0.4), Vector2(0.14, 0.7), Vector2(0.0, 1.2)], 8),
		base + Vector3(0, rise - 0.05, 0), _stone_dark()) as MeshInstance3D
	fin.name = "Finial"


func _quoins(parent: Node3D, corner: Vector3, height: float) -> void:
	# Big dressed corner stones, long and short in turn, up a corner
	var y := 0.6
	var k := 0
	while y < height - 0.3:
		var long := 0.7 if k % 2 == 0 else 0.42
		var qm := BoxMesh.new()
		qm.size = Vector3(long, 0.5, long)
		sg._mesh(parent, qm, corner + Vector3(0, y + 0.25, 0), _stone_dark()).name = "Quoin"
		y += 0.6
		k += 1


func _window(parent: Node3D, at: Vector3, w: float, h: float, lights: int, yaw := PI) -> void:
	# A mullioned window, leaded panes glowing amber, a stone surround, mullions and a transom, and a sill
	var win := _group("Window", parent)
	win.position = at
	win.rotation.y = yaw
	var glass: StandardMaterial3D = sg._mat("Leaded Window", Color(1.0, 0.8, 0.5), 0.3, 0.55)
	var gm := BoxMesh.new()
	gm.size = Vector3(w, h, 0.06)
	sg._mesh(win, gm, Vector3(0, 0, 0.05), glass, false).name = "Panes"
	var dark := _stone_dark()
	for side: float in [-1.0, 1.0]:
		var jm := BoxMesh.new()
		jm.size = Vector3(0.22, h + 0.44, 0.3)
		sg._mesh(win, jm, Vector3(side * (w / 2.0 + 0.11), 0, 0.12), dark).name = "Jamb"
	var lm := BoxMesh.new()
	lm.size = Vector3(w + 0.7, 0.26, 0.4)
	sg._mesh(win, lm, Vector3(0, h / 2.0 + 0.13, 0.16), dark).name = "Hood"
	sg._mesh(win, lm, Vector3(0, -h / 2.0 - 0.13, 0.2), dark).name = "Sill"
	for i in range(1, lights):
		var mm := BoxMesh.new()
		mm.size = Vector3(0.12, h, 0.16)
		sg._mesh(win, mm, Vector3(-w / 2.0 + w * i / lights, 0, 0.1), dark).name = "Mullion"
	var tm := BoxMesh.new()
	tm.size = Vector3(w, 0.1, 0.14)
	sg._mesh(win, tm, Vector3(0, h * 0.18, 0.1), dark).name = "Transom"


func _door(parent: Node3D, at: Vector3) -> void:
	# The front door: oak in a deep Tudor arch, a stone shield over it. It's locked (the house is only to look at).
	var d := _group("Front Door", parent)
	d.position = at
	d.rotation.y = PI
	var dark := _stone_dark()
	var oak: StandardMaterial3D = sg._mat("Oak Door", Color(0.42, 0.3, 0.27), 0.85)
	var dm := BoxMesh.new()
	dm.size = Vector3(2.4, 3.4, 0.12)
	sg._mesh(d, dm, Vector3(0, 1.7, 0.04), oak).name = "Door Leaf"
	var arch := PrismMesh.new()
	arch.size = Vector3(2.4, 0.7, 0.12)
	sg._mesh(d, arch, Vector3(0, 3.75, 0.04), oak).name = "Door Arch"
	for side: float in [-1.0, 1.0]:
		var jm := BoxMesh.new()
		jm.size = Vector3(0.45, 4.3, 0.5)
		sg._mesh(d, jm, Vector3(side * 1.45, 2.15, 0.2), dark).name = "Door Jamb"
		sg._ball(d, 0.07, Vector3(side * 0.35, 1.6, 0.14), sg._mat("Old Brass", Color(0.85, 0.68, 0.35), 0.3))
	var head := PrismMesh.new()
	head.size = Vector3(3.4, 0.9, 0.5)
	sg._mesh(d, head, Vector3(0, 4.75, 0.2), dark).name = "Door Head"
	var shield := sg._mesh(d, _lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.25), Vector2(0.5, 0.9), Vector2(0.0, 0.9)], 4),
		Vector3(0, 5.6, 0.12), _stone()) as MeshInstance3D
	shield.name = "Shield"
	shield.scale = Vector3(1, 1, 0.3)
	# Two steps up from the terrace to the door, for looks (you stand at it, not on them)
	for i in 2:
		var sm := BoxMesh.new()
		sm.size = Vector3(3.6 - i * 0.6, 0.12, 1.2 - i * 0.4)
		sg._mesh(d, sm, Vector3(0, 0.06 + i * 0.12, 0.6 - i * 0.2), dark).name = "Door Step"


func _chimney(parent: Node3D, base: Vector3) -> void:
	var brick: StandardMaterial3D = sg._mat("Chimney Brick", Color(0.62, 0.5, 0.56), 0.9)
	sg._box(parent, "Chimney Stack", Vector3(2.2, 5.0, 1.3), base + Vector3(0, 2.5, 0), _stone(), false)
	sg._box(parent, "Chimney Band", Vector3(2.5, 0.3, 1.6), base + Vector3(0, 5.1, 0), _stone_dark(), false)
	for i in 3:
		var at := base + Vector3(-0.7 + i * 0.7, 5.25, 0)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 2.6
		cm.radial_segments = 8
		sg._mesh(parent, cm, at + Vector3(0, 1.3, 0), brick).name = "Chimney Shaft"
		var cap := CylinderMesh.new()
		cap.top_radius = 0.42
		cap.bottom_radius = 0.36
		cap.height = 0.3
		cap.radial_segments = 8
		sg._mesh(parent, cap, at + Vector3(0, 2.7, 0), _stone_dark()).name = "Chimney Pot"


# -----------------------------------------------------------------------------
# Stairs: steps you see, a smooth ramp you walk on (on the steps' nosings), stone cheeks with balustrades
# -----------------------------------------------------------------------------
func _stair(cx: float, width: float) -> void:
	var s := _group("Grand Stair" if width > 6.0 else "Side Stair")
	var steps := 8
	var rise := TERRACE_Y / steps
	var top := TERRACE_Z.x
	var foot := top - STAIR_RUN
	var tread := STAIR_RUN / steps
	var stone := _stone()
	for i in steps:
		var hgt := rise * (i + 1)
		var sm := BoxMesh.new()
		sm.size = Vector3(width, hgt, tread + 0.02)
		sg._mesh(s, sm, Vector3(cx, hgt / 2.0, foot + tread * (i + 0.5)), stone).name = "Step"
		var nm := BoxMesh.new()
		nm.size = Vector3(width, 0.06, 0.12)
		sg._mesh(s, nm, Vector3(cx, hgt - 0.03, foot + tread * i + 0.02), _stone_dark()).name = "Nosing"
	# The ramp runs over the nosings: height rise at the first step's front, full height at the last one's
	var a := Vector3(cx, 0.0, foot - tread)
	var b := Vector3(cx, TERRACE_Y, top - tread)
	_slab(s, "Stair Ramp", a, b, Vector2(0.3, width), stone, true, 0.0).visible = false
	_slab(s, "Stair Landing", b, Vector3(cx, TERRACE_Y, top + 0.3), Vector2(0.3, width), stone, true, 0.0).visible = false
	# Cheeks either side: a sloping stone wall up to the terrace with a balustrade on it, a newel and urn at the foot
	for side: float in [-1.0, 1.0]:
		var x := cx + side * (width / 2.0 + 0.3)
		var c0 := Vector3(x, 0.4, foot)
		var c1 := Vector3(x, TERRACE_Y + 0.05, top)
		_slab(s, "Stair Cheek", c0, c1, Vector2(3.4, 0.6), stone, true, 0.0)
		balustrade(s, c0, c1, true)
		sg._box(s, "Newel", Vector3(0.75, 1.5, 0.75), Vector3(x, 0.75, foot - 0.1), _stone_dark(), true)
		_urn(s, Vector3(x, 1.5, foot - 0.1), width > 6.0)
	stairs.append({"x": cx, "width": width, "foot": Vector3(cx, 0, foot - tread - 0.6), "top": Vector3(cx, TERRACE_Y, top + 1.5)})
	# Tall cypresses either side of the grand stair's foot
	if width > 6.0:
		for side: float in [-1.0, 1.0]:
			_cypress(s, Vector3(cx + side * (width / 2.0 + 2.2), 0, foot - 1.0), 1.1)


# -----------------------------------------------------------------------------
# The Fountain Court: a wide pool round the old fountain, arching jets, a parterre of box hedges
# -----------------------------------------------------------------------------
func _fountain_court() -> void:
	var f := _group("Fountain Court")
	f.position = sg.FOUNTAIN
	var stone := _stone()
	var sides := 16
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(cos(a0), 0, sin(a0)) * POOL_R
		var p1 := Vector3(cos(a1), 0, sin(a1)) * POOL_R
		_slab(f, "Pool Rim", p0 + Vector3(0, 0.55, 0), p1 + Vector3(0, 0.55, 0), Vector2(0.55, 0.6), stone, true, 0.0)
		_slab(f, "Pool Coping", p0 + Vector3(0, 0.62, 0), p1 + Vector3(0, 0.62, 0), Vector2(0.1, 0.8), _stone_dark(), false, 0.0)
	var water := CylinderMesh.new()
	water.top_radius = POOL_R - 0.25
	water.bottom_radius = POOL_R - 0.25
	water.height = 0.05
	water.radial_segments = 32
	sg._mesh(f, water, Vector3(0, POOL_Y, 0), sg._mat("Fountain Water", Color(0.45, 0.75, 0.95, 0.8), 0.05, 0.3), false).name = "Pool Water"
	var w := WATER.new()
	w.name = "Fountain Pool Water"
	w.ellipses = [Vector4(sg.FOUNTAIN.x, sg.FOUNTAIN.z, POOL_R - 0.3, POOL_R - 0.3)]
	w.water_y = POOL_Y
	sg.add_child(w)
	# Eight jets arch from the rim in towards the old basin (each a string of glassy drops, moved in _process)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var jet := _group("Jet", f)
		jet.position = Vector3(cos(a), 0, sin(a)) * (POOL_R - 0.2) + Vector3(0, 0.62, 0)
		jet.rotation.y = -a
		for k in 7:
			sg._ball(jet, 0.09, Vector3.ZERO, sg._mat("Spray", Color(0.7, 0.9, 1.0, 0.7), 0.05, 0.4))
		_jets.append(jet)
	# The parterre: four beds, each a quarter ring edged in clipped box, filled with flowers and a topiary ball
	var p := _group("Parterre", f)
	var r0 := PARTERRE_R.x
	var r1 := PARTERRE_R.y
	var hedge: StandardMaterial3D = sg._hedge()
	var cols := [Color(1.0, 0.6, 0.8), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.4), Color(1.0, 1.0, 0.95)]
	for q in 4:
		var a0 := deg_to_rad(20.0 + q * 90.0)
		var a1 := deg_to_rad(70.0 + q * 90.0)
		for r: float in [r0, r1]:
			var n := ceili(r * (a1 - a0) / 1.2)
			for i in n:
				var b0 := lerpf(a0, a1, float(i) / n)
				var b1 := lerpf(a0, a1, float(i + 1) / n)
				_hedge_run(p, Vector3(cos(b0), 0, sin(b0)) * r, Vector3(cos(b1), 0, sin(b1)) * r, hedge)
		for a: float in [a0, a1]:
			_hedge_run(p, Vector3(cos(a), 0, sin(a)) * r0, Vector3(cos(a), 0, sin(a)) * r1, hedge)
		var mid := (a0 + a1) / 2.0
		sg._ball(p, 0.9, Vector3(cos(mid), 0, sin(mid)) * ((r0 + r1) / 2.0) + Vector3(0, 0.95, 0), hedge, 1.0)
		for k in 22:
			var a := lerpf(a0 + 0.06, a1 - 0.06, _rng.randf())
			var rr := lerpf(r0 + 0.5, r1 - 0.5, _rng.randf())
			var m: StandardMaterial3D = sg._mat("Parterre Flower %d" % (k % 4), cols[(k + q) % 4], 0.6, 0.2)
			if not m in sg._glows:
				sg._glows.append(m)
			sg._ball(p, 0.2, Vector3(cos(a), 0, sin(a)) * rr + Vector3(0, 0.3, 0), m)


func _hedge_run(parent: Node3D, a: Vector3, b: Vector3, m: Material) -> void:
	# A short straight length of low clipped box hedge (named "Hedge" so the detail pipeline gives it the maze's baked
	# hedge, squashed down to its size)
	var length := a.distance_to(b) + 0.4
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.6, 0.45)
	var mi := sg._mesh(parent, bm, (a + b) / 2.0 + Vector3(0, 0.3, 0), m) as MeshInstance3D
	mi.name = "Hedge"
	mi.basis = _along(a, b)
	var bs := BoxShape3D.new()
	bs.size = bm.size
	var body: StaticBody3D = sg._solid(parent, "Hedge Body", bs, mi.position)
	body.basis = mi.basis


# -----------------------------------------------------------------------------
# The Brook and its bridges
# -----------------------------------------------------------------------------
func brook_distance(x: float, z: float) -> float:
	# How far a point is from the Brook's middle line
	var best := INF
	var p := Vector2(x, z)
	for i in BROOK.size() - 1:
		var a: Vector2 = BROOK[i]
		var b: Vector2 = BROOK[i + 1]
		var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a.lerp(b, t)))
	return best


func _brook() -> void:
	var br := _group("Brook")
	var water_m: StandardMaterial3D = sg._mat("Brook Water", Color(0.4, 0.68, 0.85, 0.78), 0.05, 0.25)
	var bed: StandardMaterial3D = sg._mat("Brook Bed", Color(0.36, 0.38, 0.42), 0.95)
	var rock: StandardMaterial3D = sg._mat("Brook Stone", Color(0.62, 0.6, 0.66), 0.9)
	var circles: Array[Vector4] = []
	for i in BROOK.size() - 1:
		var a := Vector3(BROOK[i].x, 0, BROOK[i].y)
		var b := Vector3(BROOK[i + 1].x, 0, BROOK[i + 1].y)
		var bm := BoxMesh.new()
		bm.size = Vector3(a.distance_to(b), 0.04, BROOK_W)
		var wm := sg._mesh(br, bm, (a + b) / 2.0 + Vector3(0, BROOK_Y, 0), water_m, false) as MeshInstance3D
		wm.name = "Brook Surface"
		wm.basis = _along(a, b)
		var bb := BoxMesh.new()
		bb.size = Vector3(a.distance_to(b), 0.03, BROOK_W + 0.6)
		var bmi := sg._mesh(br, bb, (a + b) / 2.0 + Vector3(0, 0.02, 0), bed, false) as MeshInstance3D
		bmi.name = "Brook Bed"
		bmi.basis = _along(a, b)
		var n := ceili(a.distance_to(b) / 1.3)
		var across := _along(a, b).z
		for k in n:
			var at := a.lerp(b, (k + 0.5) / n)
			if Vector2(at.x, at.z).distance_to(Vector2(sg.POND.x, sg.POND.z)) > sg.POND_R.y + 1.0:
				circles.append(Vector4(at.x, at.z, BROOK_W / 2.0, BROOK_W / 2.0))
			for side: float in [-1.0, 1.0]:
				var edge := at + across * side * (BROOK_W / 2.0 + 0.25) + Vector3(_rng.randf_range(-0.3, 0.3), 0.12, 0)
				sg._ball(br, _rng.randf_range(0.28, 0.5), edge, rock, 0.55)
		# round the bends, a disc of water so the lengths join
		if i > 0:
			var disc := CylinderMesh.new()
			disc.top_radius = BROOK_W / 2.0
			disc.bottom_radius = BROOK_W / 2.0
			disc.height = 0.04
			sg._mesh(br, disc, a + Vector3(0, BROOK_Y, 0), water_m, false).name = "Brook Bend"
	var w := WATER.new()
	w.name = "Brook Water"
	w.ellipses = circles
	w.water_y = BROOK_Y
	sg.add_child(w)
	# Two little stone footbridges: one on the path across from the cypresses, one up by the giant flowers
	_bridge(br, "Brook Bridge", _cross(3, 0.6), 0.9, 2.2, false)
	_bridge(br, "Upper Brook Bridge", _cross(1, 0.55), 0.8, 2.0, false)


func _cross(seg: int, t: float) -> Array:
	# The two ends of a bridge across the Brook's length seg, t of the way along it
	var a := Vector3(BROOK[seg].x, 0, BROOK[seg].y)
	var b := Vector3(BROOK[seg + 1].x, 0, BROOK[seg + 1].y)
	var at := a.lerp(b, t)
	var across := _along(a, b).z
	return [at - across * 3.2, at + across * 3.2]


func _pond_bridge() -> void:
	# A big stone bridge with balustrades from the pond's north-west shore out to the island, between two of the
	# summerhouse's posts (its gaps face 30 degrees round from each post)
	var d := Vector3(cos(deg_to_rad(150.0)), 0, sin(deg_to_rad(150.0)))
	var pond := Vector3(sg.POND.x, 0, sg.POND.z)
	_bridge(self, "Pond Bridge", [pond + d * 17.0, pond + d * (sg.ISLAND_R - 0.2)], 1.3, 2.4, true)


func _bridge(parent: Node3D, nm: String, ends: Array, rise: float, width: float, rails: bool) -> void:
	# An arched stone bridge from ends[0] to ends[1]: its deck in short sloping lengths (each solid, so you walk up
	# and over), stone under it down to the water, an arch ring and its shadow on both faces, and balustrades or a
	# low parapet along both sides
	var g := _group(nm, parent)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var n := 10
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t) + Vector3(0, rise * sin(PI * t), 0))
	var stone := _stone()
	var dark := _stone_dark()
	var basis := _along(a, b)
	for i in n:
		_slab(g, "Bridge Deck", pts[i], pts[i + 1], Vector2(0.35, width), stone, true, 0.0)
		var mid := (pts[i] + pts[i + 1]) / 2.0
		if mid.y > 0.15:
			var sp := BoxMesh.new()
			sp.size = Vector3(pts[i].distance_to(pts[i + 1]) + 0.05, mid.y, width - 0.1)
			var smi := sg._mesh(g, sp, Vector3(mid.x, mid.y / 2.0 - 0.17, mid.z), stone) as MeshInstance3D
			smi.name = "Bridge Spandrel"
			smi.basis = basis
		for side: float in [-1.0, 1.0]:
			var off := basis.z * side * (width / 2.0 - 0.25)
			if rails:
				balustrade(g, pts[i] + off, pts[i + 1] + off, true, false, false)
			else:
				_slab(g, "Parapet", pts[i] + off + Vector3(0, 0.6, 0), pts[i + 1] + off + Vector3(0, 0.6, 0),
					Vector2(0.6, 0.4), dark, true, 0.0)
	# The arch: a ring of dark voussoirs and the shadow under it, on both faces
	var centre := a.lerp(b, 0.5)
	var span := a.distance_to(b)
	var r := minf(rise + 0.1, span * 0.3)
	for side: float in [-1.0, 1.0]:
		var face := centre + basis.z * side * (width / 2.0 + 0.01)
		var shade := CylinderMesh.new()
		shade.top_radius = r * 0.82
		shade.bottom_radius = r * 0.82
		shade.height = 0.04
		shade.radial_segments = 24
		var sh := sg._mesh(g, shade, face, sg._mat("Arch Shadow", Color(0.08, 0.1, 0.14)), false) as MeshInstance3D
		sh.name = "Arch Shadow"
		sh.basis = Basis(basis.x, basis.z * side, basis.y * -side)
		var ring := TorusMesh.new()
		ring.inner_radius = r * 0.82
		ring.outer_radius = r
		ring.rings = 24
		var rm := sg._mesh(g, ring, face + basis.z * side * 0.02, dark) as MeshInstance3D
		rm.name = "Arch Ring"
		rm.basis = Basis(basis.x, basis.z * side, basis.y * -side)
	# Newels at its four corners
	for e: Vector3 in [a, b]:
		for side: float in [-1.0, 1.0]:
			sg._box(g, "Bridge Newel", Vector3(0.6, 1.3, 0.6), e + basis.z * side * (width / 2.0 - 0.25) + Vector3(0, 0.65, 0), dark, true)
	bridges.append({"name": nm, "from": a, "to": b, "rise": rise})


# -----------------------------------------------------------------------------
# Trees: great old oaks round the lawns, and tall cypresses up the middle
# -----------------------------------------------------------------------------
func _trees() -> void:
	var g := _group("Estate Trees")
	var bark: StandardMaterial3D = sg._mat("Oak Bark", Color(0.42, 0.34, 0.33), 0.95)
	var leaves: StandardMaterial3D = sg._mat("Oak Leaves", Color(0.26, 0.48, 0.28), 0.85)
	var leaves2: StandardMaterial3D = sg._mat("Oak Leaves Light", Color(0.36, 0.56, 0.3), 0.85)
	for o: Vector2 in OAKS:
		var at := Vector3(o.x, 0, o.y)
		var th := _rng.randf_range(6.0, 8.0)
		var tr := _rng.randf_range(0.9, 1.25)
		sg._cyl(g, "Oak Trunk", tr * 0.75, tr, th, at + Vector3(0, th / 2.0, 0), bark, true)
		# Big limbs reaching out, and a wide crown of leafy clumps over them
		var limbs := 4
		var turn := _rng.randf() * TAU
		for k in limbs:
			var a := turn + TAU * k / limbs
			var out := Vector3(cos(a), 0, sin(a))
			var l0 := at + Vector3(0, th - 0.8, 0)
			var l1 := at + out * 4.2 + Vector3(0, th + 2.2, 0)
			var lm := CylinderMesh.new()
			lm.top_radius = 0.28
			lm.bottom_radius = tr * 0.5
			lm.height = l0.distance_to(l1)
			lm.radial_segments = 10
			var limb := sg._mesh(g, lm, (l0 + l1) / 2.0, bark) as MeshInstance3D
			limb.name = "Oak Limb"
			var up := (l1 - l0).normalized()
			var side := up.cross(Vector3.UP).normalized()
			limb.basis = Basis(side, up, side.cross(up).normalized())
			sg._ball(g, _rng.randf_range(3.2, 4.2), l1 + Vector3(0, 0.8, 0), leaves if k % 2 else leaves2, 0.7)
		sg._ball(g, _rng.randf_range(4.4, 5.4), at + Vector3(0, th + 3.6, 0), leaves, 0.75)
		for k in 3:
			var a := turn + TAU * (k + 0.5) / 3.0
			sg._ball(g, _rng.randf_range(3.0, 3.8), at + Vector3(cos(a) * 2.6, th + 4.4, sin(a) * 2.6), leaves2, 0.7)
	# The cypress allee up the middle path, from the fountain to the giant flowers
	var z := 70.0
	while z < 97.0:
		for side: float in [-1.0, 1.0]:
			_cypress(g, Vector3(side * 4.4, 0, z), _rng.randf_range(0.95, 1.1))
		z += 4.3
	# ...and a pair either end of the house
	for side: float in [-1.0, 1.0]:
		_cypress(g, Vector3(side * (HOUSE_X + 4.0), TERRACE_Y, 140.0), 1.25)


func _cypress(parent: Node3D, at: Vector3, k: float) -> void:
	# A tall, slim Italian cypress
	var bark: StandardMaterial3D = sg._mat("Oak Bark", Color(0.42, 0.34, 0.33), 0.95)
	sg._cyl(parent, "Cypress Trunk", 0.16, 0.2, 1.2, at + Vector3(0, 0.6, 0), bark, true)
	var sm := SphereMesh.new()
	sm.radius = 0.95 * k
	sm.height = 7.8 * k
	sm.radial_segments = 12
	sm.rings = 8
	var mi := sg._mesh(parent, sm, at + Vector3(0, 0.6 + 3.9 * k, 0), sg._mat("Cypress", Color(0.18, 0.38, 0.26), 0.85), false) as MeshInstance3D
	mi.name = "Cypress"


# -----------------------------------------------------------------------------
# Paths: gravel walks joining it all up
# -----------------------------------------------------------------------------
func _paths() -> void:
	var g := _group("Estate Paths")
	var gravel: StandardMaterial3D = sg._mat("Gravel Path", Color(0.86, 0.8, 0.7), 0.95)
	var brook_a: Array = _cross(3, 0.6)
	var upper: Array = _cross(1, 0.55)
	var pond_foot: Vector3 = bridges[bridges.size() - 1].from if bridges.size() > 0 else Vector3.ZERO
	for p in bridges:
		if p.name == "Pond Bridge":
			pond_foot = p.from
	var runs := [
		[Vector3(4.0, 0, brook_a[0].z), brook_a[0]],                     # the allee across to the Brook Bridge
		[brook_a[1], Vector3(62, 0, brook_a[1].z)],                       # ...and on to the east lawn
		[Vector3(0, 0, 112.0), Vector3(0, 0, 118.0)],                     # the flowers to the grand stair
		[Vector3(-20, 0, 108.0), Vector3(-20, 0, 117.6)],                 # the west walk to the west stair
		[Vector3(20, 0, 117.6), upper[0]],                                # the east stair to the Upper Brook Bridge
		[upper[1], Vector3(56, 0, 118.0)],
		[Vector3(27.0, 0, 52.0), pond_foot],                              # the fountain's east path to the Pond Bridge
	]
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var pm := PlaneMesh.new()
		pm.size = Vector2(a.distance_to(b) + 1.0, 3.0)
		var mi := sg._mesh(g, pm, (a + b) / 2.0 + Vector3(0, 0.021, 0), gravel, false) as MeshInstance3D
		mi.name = "Path"
		var x := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
		mi.basis = Basis(x, Vector3.UP, x.cross(Vector3.UP).normalized())


# -----------------------------------------------------------------------------
# The balusters and urns, all in two MultiMeshes, and the baked patches
# -----------------------------------------------------------------------------
func _multis() -> void:
	var stone := _stone()
	var baluster := _lathe([Vector2(0.1, 0.0), Vector2(0.1, 0.05), Vector2(0.065, 0.08), Vector2(0.05, 0.13),
		Vector2(0.105, 0.27), Vector2(0.115, 0.33), Vector2(0.085, 0.42), Vector2(0.042, 0.52), Vector2(0.052, 0.56),
		Vector2(0.085, 0.6), Vector2(0.085, 0.65)])
	var urn := _lathe([Vector2(0.0, 0.0), Vector2(0.19, 0.0), Vector2(0.19, 0.07), Vector2(0.1, 0.11), Vector2(0.08, 0.22),
		Vector2(0.15, 0.28), Vector2(0.3, 0.44), Vector2(0.36, 0.6), Vector2(0.34, 0.7), Vector2(0.41, 0.74),
		Vector2(0.41, 0.8), Vector2(0.3, 0.82), Vector2(0.0, 0.8)], 14)
	for pair in [["Balusters", baluster, _baluster_xf], ["Urns", urn, _urn_xf]]:
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
		mmi.material_override = stone
		add_child(mmi)


func _dress() -> void:
	var detail := load("res://scripts/detail_props.gd")
	detail.dress_place(self, ESTATE_SURFACES)
	# (dress_place only looks at MeshInstances: the balusters and urns are MultiMeshes, so they're dressed here)
	for n in ["Balusters", "Urns"]:
		var mmi := get_node_or_null(n) as MultiMeshInstance3D
		if mmi:
			var m: StandardMaterial3D = detail.world_patched(mmi.material_override as StandardMaterial3D, "stone", 0.5)
			if m:
				mmi.material_override = m


func blocks(at: Vector3) -> bool:
	# True where the garden's scattered flowers and bushes shouldn't go (on the terrace, the stairs, the Brook, the
	# fountain court, under an oak or a cypress)
	if at.z > TERRACE_Z.x - STAIR_RUN - 2.0 and absf(at.x) < TERRACE_X + 2.0:
		return true
	if brook_distance(at.x, at.z) < BROOK_W / 2.0 + 1.6:
		return true
	for o: Vector2 in OAKS:
		if Vector2(at.x, at.z).distance_to(o) < 2.5:
			return true
	if absf(at.x) < 6.0 and at.z > 66.0 and at.z < 99.0:
		return true
	for b in bridges:
		var a: Vector3 = b.from
		var e: Vector3 = b.to
		var p := Vector2(at.x, at.z)
		var a2 := Vector2(a.x, a.z)
		var e2 := Vector2(e.x, e.z)
		var t := clampf((p - a2).dot(e2 - a2) / (e2 - a2).length_squared(), 0.0, 1.0)
		if p.distance_to(a2.lerp(e2, t)) < 2.5:
			return true
	return false


# -----------------------------------------------------------------------------
# Every frame: the jets arch and the spouts pour
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	for jet in _jets:
		var n := jet.get_child_count()
		for k in n:
			var s := fposmod(_t * 0.9 + float(k) / n, 1.0)
			# out over the water towards the basin in a little arc (local -x is in towards the middle)
			var drop := jet.get_child(k) as Node3D
			drop.position = Vector3(-s * 1.9, 3.2 * s * (1.0 - s), 0)
	for f in _falls:
		f.scale.x = 1.0 + sin(_t * 9.0) * 0.12
