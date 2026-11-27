extends "res://scripts/secret_garden_kit.gd"

# The rebuilt Secret Garden's trees and glass (26 Nov 2026; see scripts/secret_garden.gd). Our own take on these, not
# copies:
#   - the Arboretum on the west slopes (after Westonbirt's glades and the Arnold Arboretum's collections): groves of one
#     kind each, a Maple Glade, a Redwood Grove, a Birch Walk, a Cedar Lawn and copper beeches
#   - the Great Tree: an enormous old oak, the tree seed asleep up in its crown
#   - the Treetop Walk (after Kew's Treetop Walkway and Kirstenbosch's "Boomslang"): a walkway on posts that leaves the
#     path and climbs gently through the grove to a deck round the Great Tree's trunk, up in its crown
#   - the Glasshouse (after Kew's Palm House): a long white iron glasshouse with curved glass roofs, a tall nave and two
#     wings, palms and ferns inside and a pool of giant water lilies
#   - the Supertree Grove (after Gardens by the Bay's Supertrees): tall made trees of steel, planted all over, with wide
#     glowing canopies; a ramp winds up round the tallest to a deck in its canopy, where the flower seed sleeps
# Their ground is the land's pads (secret_garden_land.gd).

const GREAT_TREE := Vector2(-80.0, 165.0)
const CROWN_DECK := 11.0                        # the deck round its trunk, over the ground there
const DECK_R := 5.2
const TRUNK_R := 2.1
const WALK := [Vector2(-32.0, 167.0), Vector2(-46.0, 156.0), Vector2(-62.0, 149.0), Vector2(-78.0, 148.5),
	Vector2(-90.0, 155.0)]                     # the Treetop Walk, from its foot (then on to the deck's edge)
const WALK_W := 2.2
const GLASS := Vector3(92.0, 9.0, 170.0)        # the Glasshouse's middle (y: its pad)
const NAVE := Vector2(16.0, 20.0)               # its tall middle: length (x) and depth (z)
const NAVE_WALL := 5.0
const WING := Vector2(20.0, 12.0)
const WING_WALL := 3.6
const SUPER_PAD := 3.0
const TALLEST := Vector3(93.0, 24.0, 126.0)     # the tallest supertree: x, height, z
const SPIRAL_R := 4.4                           # the ramp's inside edge, clear of the canopy deck
const SUPERTREES := [Vector3(72.0, 17.0, 108.0), Vector3(78.0, 19.5, 133.0), Vector3(111.0, 18.5, 106.0),
	Vector3(115.0, 20.5, 132.0), Vector3(64.0, 15.0, 122.0), Vector3(124.0, 15.5, 119.0), Vector3(100.0, 16.0, 137.5)]
const SURFACES := [["Estate Stone", "stone", 1.0], ["Estate Stone Dark", "stone", 0.8], ["Walk Boards", "barn_boards", 0.6],
	["Supertree Steel", "metal_panel", 0.8], ["Glasshouse Floor", "stone", 1.2], ["Great Bark", "bark", 1.6]]

var walk_pts: Array[Vector3] = []               # the Treetop Walk's line (for tests)
var spiral_pts: Array[Vector3] = []             # the supertree ramp's line (for tests)
var _rib_xf: Array[Transform3D] = []
var _keep: Array[Vector3] = []
var _canopies: Array[Node3D] = []


func build(garden: Node3D) -> void:
	start(garden, "Groves", 5113)
	_great_tree()
	_treetop_walk()
	_arboretum()
	_glasshouse()
	_supertree_grove()
	finish(SURFACES)


# -----------------------------------------------------------------------------
# The Great Tree and the Treetop Walk
# -----------------------------------------------------------------------------
func crown_y() -> float:
	return ground(GREAT_TREE.x, GREAT_TREE.y) + CROWN_DECK


func _great_tree() -> void:
	var at := on_ground(GREAT_TREE.x, GREAT_TREE.y)
	var g := group("Great Tree")
	var bark: StandardMaterial3D = sg._mat("Great Bark", Color(0.38, 0.31, 0.27), 0.95)
	# The trunk, its root flare and great limbs reaching out over the deck
	sg._cyl(g, "Great Trunk", TRUNK_R * 0.8, TRUNK_R, CROWN_DECK + 5.0, at + Vector3(0, (CROWN_DECK + 5.0) / 2.0 - 0.3, 0), bark, true)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var root := sg._cyl(g, "Great Root", 0.2, 0.9, 4.2, at + Vector3(cos(a) * 3.2, 0.15, sin(a) * 3.2), bark, false) as MeshInstance3D
		var out := Vector3(cos(a), -0.22, sin(a)).normalized()
		var rx := out.cross(Vector3.UP).normalized()
		root.basis = Basis(rx, out, rx.cross(out))
	var top := at + Vector3(0, CROWN_DECK + 4.5, 0)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var reach := _rng.randf_range(8.0, 11.0)
		var tip := top + Vector3(cos(a) * reach, _rng.randf_range(2.0, 5.0), sin(a) * reach)
		limb(top, tip, 0.85, "oak")
		leaves(tip + Vector3(0, 1.4, 0), _rng.randf_range(4.2, 5.4), "oak" if i % 2 else "oak_light", 0.62)
		var mid := (top + tip) / 2.0 + Vector3(0, 2.6, 0)
		leaves(mid, 3.8, "oak_light" if i % 2 else "oak", 0.6)
	leaves(top + Vector3(0, 7.0, 0), 8.0, "oak", 0.6)
	leaves(top + Vector3(3.0, 9.5, -2.0), 5.0, "oak_light", 0.7)
	trees.append({"kind": "great", "at": at, "height": CROWN_DECK + 16.0})
	# The deck round the trunk, a railing all round but where the walk comes in, and lanterns
	var y := crown_y()
	var deck := group("Crown Deck", g)
	var boards: StandardMaterial3D = sg._mat("Walk Boards", Color(0.55, 0.42, 0.3), 0.8)
	var rail: StandardMaterial3D = sg._mat("Walk Rail", Color(0.3, 0.25, 0.22), 0.7)
	var cm := CylinderMesh.new()
	cm.top_radius = DECK_R
	cm.bottom_radius = DECK_R
	cm.height = 0.3
	cm.radial_segments = 28
	sg._mesh(deck, cm, Vector3(at.x, y - 0.15, at.z), boards).name = "Crown Deck Boards"
	var cs := CylinderShape3D.new()
	cs.radius = DECK_R
	cs.height = 0.3
	sg._solid(deck, "Crown Deck Body", cs, Vector3(at.x, y - 0.15, at.z))
	var way_in := walk_end_dir()
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		var mid_dir := Vector2(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0))
		if mid_dir.dot(way_in) > 0.88:
			continue
		var p0 := Vector3(at.x + cos(a0) * (DECK_R - 0.15), y, at.z + sin(a0) * (DECK_R - 0.15))
		var p1 := Vector3(at.x + cos(a1) * (DECK_R - 0.15), y, at.z + sin(a1) * (DECK_R - 0.15))
		slab(deck, "Deck Rail", p0 + Vector3(0, 1.05, 0), p1 + Vector3(0, 1.05, 0), Vector2(0.1, 0.12), rail, false, 0.0)
		slab(deck, "Deck Rail Low", p0 + Vector3(0, 0.55, 0), p1 + Vector3(0, 0.55, 0), Vector2(0.06, 0.08), rail, false, 0.0)
		var pm := BoxMesh.new()
		pm.size = Vector3(0.12, 1.1, 0.12)
		sg._mesh(deck, pm, p0 + Vector3(0, 0.55, 0), rail).name = "Deck Post"
		slab(deck, "Deck Railing", p0 + Vector3(0, 1.2, 0), p1 + Vector3(0, 1.2, 0), Vector2(1.4, 0.2), rail, true, 0.0).visible = false
	# Struts under the deck down to the trunk
	for i in 6:
		var a := TAU * i / 6.0
		slab(deck, "Deck Strut", Vector3(at.x + cos(a) * TRUNK_R * 0.8, y - 3.5, at.z + sin(a) * TRUNK_R * 0.8),
			Vector3(at.x + cos(a) * (DECK_R - 0.4), y - 0.3, at.z + sin(a) * (DECK_R - 0.4)), Vector2(0.2, 0.2), rail, false, 0.0)
	var lamp: StandardMaterial3D = glow(sg._mat("Walk Lamp", Color(1.0, 0.85, 0.55), 0.5, 1.0))
	for i in 3:
		var a := TAU * i / 3.0 + 1.0
		sg._ball(deck, 0.18, Vector3(at.x + cos(a) * 3.2, y + 2.4, at.z + sin(a) * 3.2), lamp)
	# The tree seed, on the deck the far side from where the walk comes in
	var far := way_in.rotated(PI / 2.0) * (DECK_R - 1.0)
	sg.put_seed("tree", Vector3(at.x + far.x, y, at.z + far.y))
	_keep.append(Vector3(at.x, at.z, 9.0))


func walk_end_dir() -> Vector2:
	# Which way the walk comes onto the deck from the middle of the tree
	return (WALK[WALK.size() - 1] - GREAT_TREE).normalized()


func _treetop_walk() -> void:
	var g := group("Treetop Walk")
	var boards: StandardMaterial3D = sg._mat("Walk Boards", Color(0.55, 0.42, 0.3), 0.8)
	var steel: StandardMaterial3D = sg._mat("Walk Steel", Color(0.32, 0.34, 0.33), 0.5)
	var rail: StandardMaterial3D = sg._mat("Walk Rail", Color(0.3, 0.25, 0.22), 0.7)
	# (each corner cut off, so no turn's sharper than about half of what it was)
	var raw: Array[Vector2] = []
	raw.assign(WALK)
	raw.append(GREAT_TREE + walk_end_dir() * (DECK_R - 0.3))
	var flat: Array[Vector2] = [raw[0]]
	for i in range(1, raw.size() - 1):
		flat.append(raw[i].move_toward(raw[i - 1], 3.0))
		flat.append(raw[i].move_toward(raw[i + 1], 3.0))
	flat.append(raw[raw.size() - 1])
	var total := 0.0
	for i in flat.size() - 1:
		total += flat[i].distance_to(flat[i + 1])
	var y0 := ground(flat[0].x, flat[0].y)
	var y1 := crown_y()
	var run := 0.0
	walk_pts.clear()
	for i in flat.size():
		if i > 0:
			run += flat[i - 1].distance_to(flat[i])
		walk_pts.append(Vector3(flat[i].x, lerpf(y0, y1, run / total), flat[i].y))
	for i in walk_pts.size() - 1:
		var a := walk_pts[i]
		var b := walk_pts[i + 1]
		slab(g, "Walk Deck", a, b, Vector2(0.25, WALK_W), boards, true, 0.0)
		var basis := along(a, b)
		for side: float in [-1.0, 1.0]:
			var off := basis.z * side * (WALK_W / 2.0 - 0.08)
			slab(g, "Walk Handrail", a + off + Vector3(0, 1.05, 0), b + off + Vector3(0, 1.05, 0), Vector2(0.08, 0.1), rail, false, 0.0)
			slab(g, "Walk Cable", a + off + Vector3(0, 0.55, 0), b + off + Vector3(0, 0.55, 0), Vector2(0.03, 0.03), steel, false, 0.0)
			slab(g, "Walk Railing", a + off + Vector3(0, 1.15, 0), b + off + Vector3(0, 1.15, 0), Vector2(1.4, 0.16), rail, true, 0.0).visible = false
		# Posts every few metres: a pair of steel legs down to the ground, braced
		var n := maxi(1, floori(a.distance_to(b) / 5.0))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			var gy := ground(p.x, p.z)
			if p.y - gy < 0.8:
				continue
			for side: float in [-1.0, 1.0]:
				var foot := Vector3(p.x, gy - 0.3, p.z) + basis.z * side * (WALK_W / 2.0 + 0.4)
				var head := p + basis.z * side * (WALK_W / 2.0 - 0.1) - Vector3(0, 0.25, 0)
				slab(g, "Walk Leg", foot, head, Vector2(0.18, 0.18), steel, false, 0.0)
			slab(g, "Walk Brace", p + basis.z * (WALK_W / 2.0) - Vector3(0, 0.4, 0), p - basis.z * (WALK_W / 2.0) - Vector3(0, 0.4, 0),
				Vector2(0.12, 0.12), steel, false, 0.0)
		_keep_line(a, b, 5.0)


func _keep_line(a: Vector3, b: Vector3, r: float) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / (r * 0.8)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		_keep.append(Vector3(p.x, p.z, r))


func near_kept(p: Vector2, extra := 0.0) -> bool:
	for k in _keep:
		if p.distance_to(Vector2(k.x, k.y)) < k.z + extra:
			return true
	return false


# -----------------------------------------------------------------------------
# The Arboretum: groves of one kind each over the west slopes
# -----------------------------------------------------------------------------
func _arboretum() -> void:
	var groves := [
		["Maple Glade", Rect2(-128.0, 147.0, 28.0, 20.0), ["maple_red", "maple_orange", "maple_gold"], 9, 6.5],
		["Redwood Grove", Rect2(-128.0, 176.0, 24.0, 14.0), ["redwood"], 6, 8.0],
		["Birch Walk", Rect2(-62.0, 174.0, 36.0, 7.0), ["birch"], 10, 4.0],
		["Birch Walk South", Rect2(-62.0, 160.0, 26.0, 8.0), ["birch"], 6, 4.0],
		["Cedar Lawn", Rect2(-98.0, 178.0, 30.0, 10.0), ["cedar"], 4, 11.0],
		["Copper Beeches", Rect2(-128.0, 128.0, 18.0, 10.0), ["copper", "blossom_white", "oak"], 4, 8.0],
		["Pinetum", Rect2(-60.0, 108.0, 22.0, 26.0), ["pine", "cedar", "pine"], 7, 6.0],
		["East Glade", Rect2(28.0, 140.0, 26.0, 24.0), ["maple_gold", "blossom", "birch", "blossom_white", "oak", "maple_red"], 9, 6.5],
		["East Woods", Rect2(100.0, 62.0, 34.0, 32.0), ["oak", "blossom_white", "cedar", "copper", "blossom", "maple_orange"], 10, 7.0],
	]
	for gr in groves:
		var rect: Rect2 = gr[1]
		var kinds: Array = gr[2]
		var want: int = gr[3]
		var gap: float = gr[4]
		var placed: Array[Vector2] = []
		var tries := 0
		while placed.size() < want and tries < want * 40:
			tries += 1
			var p := rect.position + Vector2(_rng.randf() * rect.size.x, _rng.randf() * rect.size.y)
			if LAND.path_dist(p.x, p.y) < 2.6 or LAND.in_lake(p.x, p.y, 3.0) != "" or near_kept(p, 1.0):
				continue
			var pad := LAND.on_pad(p.x, p.y, -3.0)
			if pad != "" and pad != "Tea Garden":
				continue
			if LAND.slope(p.x, p.y) > 0.45 or absf(p.x) > LAND.X_HALF - 4.0:
				continue
			var ok := true
			for q in placed:
				if q.distance_to(p) < gap:
					ok = false
					break
			for t in trees:
				if Vector2(t.at.x, t.at.z).distance_to(p) < gap * 0.7:
					ok = false
					break
			if not ok:
				continue
			placed.append(p)
			tree(kinds[placed.size() % kinds.size()], on_ground(p.x, p.y), _rng.randf_range(0.85, 1.15))


# -----------------------------------------------------------------------------
# The Glasshouse
# -----------------------------------------------------------------------------
func glass_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = sg._mat("Glasshouse Glass", Color(0.82, 0.96, 0.94, 0.2), 0.05)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.9
	return m


func iron_mat() -> StandardMaterial3D:
	return sg._mat("Glasshouse Iron", Color(0.93, 0.95, 0.93), 0.4)


static func vault_mesh(length: float, r: float, segs := 16) -> ArrayMesh:
	# Half a cylinder along x, open at the ends: a curved glass roof
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in segs:
		var a0 := PI * s / segs
		var a1 := PI * (s + 1) / segs
		var v := [Vector3(-length / 2.0, sin(a0) * r, cos(a0) * r), Vector3(length / 2.0, sin(a0) * r, cos(a0) * r),
			Vector3(length / 2.0, sin(a1) * r, cos(a1) * r), Vector3(-length / 2.0, sin(a1) * r, cos(a1) * r)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(0, v[k].y, v[k].z).normalized())
			st.set_uv(Vector2(v[k].x, v[k].y) * 0.2)
			st.add_vertex(v[k])
	return st.commit()


static func half_dome_mesh(r: float, segs := 12) -> ArrayMesh:
	# A quarter of a sphere on the +x side: the rounded end of a vault
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		for j in segs / 2:
			var p0 := -PI / 2.0 + PI * i / segs
			var p1 := -PI / 2.0 + PI * (i + 1) / segs
			var e0 := (PI / 2.0) * j / (segs / 2)
			var e1 := (PI / 2.0) * (j + 1) / (segs / 2)
			var f := func(p: float, e: float) -> Vector3: return Vector3(cos(e) * cos(p), sin(e), cos(e) * sin(p)) * r
			var v := [f.call(p0, e0), f.call(p1, e0), f.call(p1, e1), f.call(p0, e1)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_normal((v[k] as Vector3).normalized())
				st.add_vertex(v[k])
	return st.commit()


func _rib_arc(centre: Vector3, r: float, across_x: bool, segs := 10) -> void:
	# An iron rib following a vault's curve (in the y-z plane, or the y-x plane)
	for s in segs:
		var a0 := PI * s / segs
		var a1 := PI * (s + 1) / segs
		var p0 := Vector3(0, sin(a0) * r, cos(a0) * r)
		var p1 := Vector3(0, sin(a1) * r, cos(a1) * r)
		if not across_x:
			p0 = Vector3(p0.z, p0.y, 0)
			p1 = Vector3(p1.z, p1.y, 0)
		_rib(centre + p0, centre + p1)


func _rib(a: Vector3, b: Vector3, thick := 0.12) -> void:
	var basis := along(a, b)
	_rib_xf.append(Transform3D(basis * Basis.from_scale(Vector3(a.distance_to(b) + 0.04, thick, thick)), (a + b) / 2.0))


func _glasshouse() -> void:
	var g := group("Glasshouse")
	var y := GLASS.y
	var c := Vector3(GLASS.x, y, GLASS.z)
	var glass := glass_mat()
	var iron := iron_mat()
	var floor_m: StandardMaterial3D = sg._mat("Glasshouse Floor", Color(0.72, 0.66, 0.6), 0.9)
	# Floors
	block(g, "Glasshouse Floor", Vector3(NAVE.x, 0.06, NAVE.y), c + Vector3(0, 0.03, 0), floor_m, false)
	for side: float in [-1.0, 1.0]:
		block(g, "Glasshouse Floor", Vector3(WING.x, 0.06, WING.y), c + Vector3(side * (NAVE.x + WING.x) / 2.0, 0.03, 0), floor_m, false)
	# The nave: glass walls with a door each side (south and north), the tall vault
	var door := 3.4
	for side: float in [-1.0, 1.0]:
		var z := c.z + side * NAVE.y / 2.0
		var piece := (NAVE.x - door) / 2.0
		for s2: float in [-1.0, 1.0]:
			_glass_wall(g, Vector3(c.x + s2 * (door / 2.0 + piece / 2.0), y, z), Vector3(piece, NAVE_WALL, 0.1), glass, iron)
		block(g, "Door Lintel", Vector3(door, 0.3, 0.25), Vector3(c.x, y + 3.2, z), iron, false)
		_glass_wall(g, Vector3(c.x, y + 3.35 + (NAVE_WALL - 3.35) / 2.0, z), Vector3(door, NAVE_WALL - 3.35, 0.1), glass, iron, false)
		# the nave's ends, where the wings don't cover them
		var ex := c.x + side * NAVE.x / 2.0
		var bit := (NAVE.y - WING.y) / 2.0
		for s2: float in [-1.0, 1.0]:
			_glass_wall(g, Vector3(ex, y, c.z + s2 * (WING.y / 2.0 + bit / 2.0)), Vector3(0.1, NAVE_WALL, bit), glass, iron)
		_glass_wall(g, Vector3(ex, y + WING_WALL, c.z), Vector3(0.1, NAVE_WALL - WING_WALL, WING.y), glass, iron, false)
	var nr := NAVE.y / 2.0
	var nv := sg._mesh(g, vault_mesh(NAVE.x, nr), Vector3(c.x, y + NAVE_WALL, c.z), glass, false) as MeshInstance3D
	nv.name = "Nave Vault"
	# the vault's open ends, glazed: half discs
	for side: float in [-1.0, 1.0]:
		var hd := CylinderMesh.new()
		hd.top_radius = nr
		hd.bottom_radius = nr
		hd.height = 0.05
		hd.radial_segments = 24
		var end := sg._mesh(g, hd, Vector3(c.x + side * NAVE.x / 2.0, y + NAVE_WALL, c.z), glass, false) as MeshInstance3D
		end.rotation.z = PI / 2.0
		end.scale = Vector3(1, 1, 1)
		end.name = "Nave End Glass"
	for i in 9:
		_rib_arc(Vector3(c.x - NAVE.x / 2.0 + NAVE.x * i / 8.0, y + NAVE_WALL, c.z), nr + 0.05, true, 14)
	_rib(Vector3(c.x - NAVE.x / 2.0, y + NAVE_WALL + nr, c.z), Vector3(c.x + NAVE.x / 2.0, y + NAVE_WALL + nr, c.z), 0.2)
	# A lantern on the nave's top
	block(g, "Nave Lantern", Vector3(6.0, 1.6, 3.0), Vector3(c.x, y + NAVE_WALL + nr + 0.6, c.z), glass, false)
	block(g, "Nave Lantern Roof", Vector3(6.4, 0.2, 3.4), Vector3(c.x, y + NAVE_WALL + nr + 1.5, c.z), iron, false)
	# The wings: low walls, a vault, and a rounded glass end
	var wr := WING.y / 2.0
	for side: float in [-1.0, 1.0]:
		var wx := c.x + side * (NAVE.x + WING.x) / 2.0
		for s2: float in [-1.0, 1.0]:
			_glass_wall(g, Vector3(wx, y, c.z + s2 * WING.y / 2.0), Vector3(WING.x, WING_WALL, 0.1), glass, iron)
		var wv := sg._mesh(g, vault_mesh(WING.x, wr), Vector3(wx, y + WING_WALL, c.z), glass, false) as MeshInstance3D
		wv.name = "Wing Vault"
		for i in 6:
			_rib_arc(Vector3(wx - WING.x / 2.0 + WING.x * i / 5.0, y + WING_WALL, c.z), wr + 0.05, true, 10)
		# the end: a curved glass wall and a half dome over it
		var ex := c.x + side * (NAVE.x / 2.0 + WING.x)
		for k in 8:
			var a0 := -PI / 2.0 + PI * k / 8.0
			var a1 := -PI / 2.0 + PI * (k + 1) / 8.0
			var p0 := Vector3(ex + side * cos(a0) * wr, y, c.z + sin(a0) * wr)
			var p1 := Vector3(ex + side * cos(a1) * wr, y, c.z + sin(a1) * wr)
			_glass_wall(g, (p0 + p1) / 2.0, Vector3(p0.distance_to(p1), WING_WALL, 0.1), glass, iron, true, -atan2(p1.z - p0.z, p1.x - p0.x))
		var dm := sg._mesh(g, half_dome_mesh(wr), Vector3(ex, y + WING_WALL, c.z), glass, false) as MeshInstance3D
		dm.scale = Vector3(side, 1, 1)
		dm.name = "Wing Dome"
		for k in 5:
			var p := -PI / 2.0 + PI * k / 4.0
			for e in 5:
				var e0 := (PI / 2.0) * e / 5.0
				var e1 := (PI / 2.0) * (e + 1) / 5.0
				var q0 := Vector3(side * cos(e0) * cos(p), sin(e0), cos(e0) * sin(p)) * (wr + 0.05)
				var q1 := Vector3(side * cos(e1) * cos(p), sin(e1), cos(e1) * sin(p)) * (wr + 0.05)
				_rib(Vector3(ex, y + WING_WALL, c.z) + q0, Vector3(ex, y + WING_WALL, c.z) + q1)
	# A stone plinth all round (low, so it's no step at the doors: the doors cut through it)
	# Inside: palms, tree ferns, a pool of giant water lilies, benches
	for p in [Vector2(-4.5, -5.0), Vector2(4.5, -5.0), Vector2(-5.0, 5.5), Vector2(5.0, 5.5), Vector2(0.0, 7.0)]:
		tree("palm", Vector3(c.x + p.x, y, c.z + p.y), _rng.randf_range(1.05, 1.3))
	for side: float in [-1.0, 1.0]:
		for i in 4:
			var px := c.x + side * (NAVE.x / 2.0 + 3.0 + i * 5.0)
			var pz := c.z + (3.0 if i % 2 else -3.0)
			if i % 2 == 0:
				tree("palm", Vector3(px, y, pz), _rng.randf_range(0.7, 0.85))
			else:
				_tree_fern(g, Vector3(px, y, pz))
	var pool_r := 3.2
	ring_wall(g, "Lily Pool Rim", Vector3(c.x, y, c.z), pool_r, 0.5, 0.4, sg._mat("Estate Stone", Color(0.6, 0.58, 0.6), 0.85), 20, true)
	disc(g, "Lily Pool Water", Vector3(c.x, y + 0.4, c.z), pool_r - 0.15, water_mat())
	var giant_pad: StandardMaterial3D = sg._mat("Giant Lily Pad", Color(0.3, 0.52, 0.22), 0.6)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 0.95
		cm.height = 0.12
		cm.radial_segments = 20
		sg._mesh(g, cm, Vector3(c.x + cos(a) * 1.6, y + 0.45, c.z + sin(a) * 1.6), giant_pad, false).name = "Giant Lily Pad"
	sg._ball(g, 0.3, Vector3(c.x, y + 0.6, c.z), glow(sg._mat("Giant Lily", Color(1.0, 0.85, 0.92), 0.4, 0.4)), 0.6)
	_keep.append(Vector3(c.x, c.z, NAVE.x / 2.0 + WING.x + wr + 3.0))
	_keep.append(Vector3(c.x, c.z - NAVE.y / 2.0 - 2.0, 4.0))


func _glass_wall(parent: Node3D, at: Vector3, size: Vector3, glass: Material, iron: Material, solid := true, yaw := 0.0) -> void:
	# A wall of glass panes in iron frames (at: the middle of its foot)
	var mi := block(parent, "Glass Wall", size, at + Vector3(0, size.y / 2.0, 0), glass, solid, yaw)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var basis := Basis(Vector3.UP, yaw)
	var long := maxf(size.x, size.z)
	var dir := basis.x if size.x >= size.z else basis.z
	var n := maxi(1, roundi(long / 1.6))
	for i in n + 1:
		var p := at + dir * (-long / 2.0 + long * i / n)
		_rib(p, p + Vector3(0, size.y, 0), 0.1)
	_rib(at - dir * long / 2.0 + Vector3(0, size.y, 0), at + dir * long / 2.0 + Vector3(0, size.y, 0), 0.16)
	_rib(at - dir * long / 2.0 + Vector3(0, 0.1, 0), at + dir * long / 2.0 + Vector3(0, 0.1, 0), 0.22)
	if size.y > 2.5:
		_rib(at - dir * long / 2.0 + Vector3(0, 2.2, 0), at + dir * long / 2.0 + Vector3(0, 2.2, 0), 0.08)


func _tree_fern(parent: Node3D, at: Vector3) -> void:
	sg._cyl(parent, "Tree Fern Trunk", 0.16, 0.22, 2.6, at + Vector3(0, 1.3, 0), sg._mat("Fern Trunk", Color(0.3, 0.22, 0.18), 0.9), true)
	var frond: StandardMaterial3D = sg._mat("Fern Frond", Color(0.3, 0.6, 0.26), 0.8)
	for i in 8:
		var a := TAU * i / 8.0
		var f: MeshInstance3D = sg._ball(parent, 0.9, at + Vector3(cos(a) * 1.0, 2.5, sin(a) * 1.0), frond, 0.12)
		f.scale = Vector3(1.0, 1.0, 0.35)
		f.rotation = Vector3(0, -a, -0.35)
	trees.append({"kind": "fern", "at": at, "height": 2.8})


# -----------------------------------------------------------------------------
# The Supertree Grove
# -----------------------------------------------------------------------------
func _supertree_grove() -> void:
	var g := group("Supertree Grove")
	for s in SUPERTREES:
		_supertree(g, Vector3(s.x, SUPER_PAD, s.z), s.y, false)
	_supertree(g, Vector3(TALLEST.x, SUPER_PAD, TALLEST.z), TALLEST.y, true)
	_spiral(g)
	# Flower beds round their feet
	var bed: StandardMaterial3D = glow(sg._mat("Supertree Bed", Color(0.95, 0.45, 0.8), 0.6, 0.3))
	var bed2: StandardMaterial3D = glow(sg._mat("Supertree Bed Gold", Color(1.0, 0.8, 0.3), 0.6, 0.3))
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var a_xf: Array = []
	var b_xf: Array = []
	for s in SUPERTREES:
		for k in 14:
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(3.0, 5.0)
			var p := Vector3(s.x + cos(a) * r, SUPER_PAD + 0.2, s.z + sin(a) * r)
			(a_xf if k % 2 else b_xf).append(Transform3D(Basis.from_scale(Vector3(0.45, 0.3, 0.45)), p))
	sg._multi(g, "Supertree Flowers", ball, a_xf, bed)
	sg._multi(g, "Supertree Flowers Gold", ball, b_xf, bed2)


func _supertree(parent: Node3D, at: Vector3, height: float, tallest: bool) -> void:
	var g := group("Supertree", parent)
	g.position = at
	var steel: StandardMaterial3D = sg._mat("Supertree Steel", Color(0.42, 0.34, 0.4), 0.5)
	var plants: StandardMaterial3D = sg._mat("Supertree Plants", Color(0.2, 0.38, 0.22), 0.9)
	var bloom: StandardMaterial3D = glow(sg._mat("Supertree Glow", Color(0.85, 0.4, 1.0), 0.5, 0.8))
	var trunk_top := height - 6.0
	var r0 := 2.0 if tallest else 1.6
	var r1 := 1.0 if tallest else 0.8
	sg._cyl(g, "Supertree Trunk", r1, r0, trunk_top, Vector3(0, trunk_top / 2.0, 0), steel, true)
	# Planted panels up the trunk, and ribs of steel spiralling round them
	var panel := CylinderMesh.new()
	panel.top_radius = r1 + 0.12
	panel.bottom_radius = r0 + 0.12
	panel.height = trunk_top - 2.0
	panel.radial_segments = 12
	sg._mesh(g, panel, Vector3(0, trunk_top / 2.0 + 1.0, 0), plants).name = "Supertree Planting"
	for i in 10:
		var a := TAU * i / 10.0
		var b := a + 0.9
		_rib(at + Vector3(cos(a) * (r0 + 0.2), 0.0, sin(a) * (r0 + 0.2)),
			at + Vector3(cos(b) * (r1 + 0.2), trunk_top, sin(b) * (r1 + 0.2)), 0.14)
	# Bright flowers dotted up the planting
	for i in 18:
		var t := _rng.randf_range(0.1, 0.95)
		var a := _rng.randf() * TAU
		var r := lerpf(r0, r1, t) + 0.25
		sg._ball(g, 0.16, Vector3(cos(a) * r, trunk_top * t, sin(a) * r), bloom, 0.8)
	# The canopy: a wide funnel of steel ribs with a glowing rim
	var funnel := CylinderMesh.new()
	funnel.top_radius = 7.0 if tallest else 5.5
	funnel.bottom_radius = r1
	funnel.height = 6.0
	funnel.radial_segments = 24
	funnel.cap_top = false
	funnel.cap_bottom = false
	var fm: StandardMaterial3D = sg._mat("Supertree Canopy", Color(0.5, 0.36, 0.55, 0.55), 0.5)
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canopy := sg._mesh(g, funnel, Vector3(0, trunk_top + 3.0, 0), fm) as MeshInstance3D
	canopy.name = "Supertree Canopy"
	var top_r := funnel.top_radius
	for i in 16:
		var a := TAU * i / 16.0
		_rib(at + Vector3(cos(a) * r1, trunk_top, sin(a) * r1), at + Vector3(cos(a) * top_r, height, sin(a) * top_r), 0.16)
	var tm := TorusMesh.new()
	tm.inner_radius = top_r - 0.14
	tm.outer_radius = top_r + 0.14
	tm.rings = 32
	sg._mesh(g, tm, Vector3(0, height, 0), bloom, false).name = "Supertree Rim"
	var tm2 := TorusMesh.new()
	tm2.inner_radius = top_r * 0.55 - 0.1
	tm2.outer_radius = top_r * 0.55 + 0.1
	tm2.rings = 24
	sg._mesh(g, tm2, Vector3(0, trunk_top + 3.0, 0), bloom, false).name = "Supertree Ring"
	_canopies.append(g)
	_keep.append(Vector3(at.x, at.z, 6.0 if tallest else 3.5))
	if tallest:
		# The deck in its canopy, a railing round it, and the flower seed in the middle
		var y := at.y + height - 0.6
		var deck := CylinderMesh.new()
		deck.top_radius = 4.2
		deck.bottom_radius = 4.2
		deck.height = 0.3
		deck.radial_segments = 24
		var boards: StandardMaterial3D = sg._mat("Walk Boards", Color(0.55, 0.42, 0.3), 0.8)
		sg._mesh(g, deck, Vector3(0, height - 0.6 - 0.15, 0), boards).name = "Canopy Deck"
		var cs := CylinderShape3D.new()
		cs.radius = 4.2
		cs.height = 0.3
		sg._solid(g, "Canopy Deck Body", cs, Vector3(0, height - 0.6 - 0.15, 0))
		var rail: StandardMaterial3D = sg._mat("Walk Rail", Color(0.3, 0.25, 0.22), 0.7)
		for i in 20:
			var a0 := TAU * i / 20.0
			var a1 := TAU * (i + 1) / 20.0
			if Vector2(cos((a0 + a1) / 2.0), sin((a0 + a1) / 2.0)).dot(Vector2(cos(spiral_end_angle()), sin(spiral_end_angle()))) > 0.85:
				continue
			var p0 := Vector3(at.x + cos(a0) * 4.05, y, at.z + sin(a0) * 4.05)
			var p1 := Vector3(at.x + cos(a1) * 4.05, y, at.z + sin(a1) * 4.05)
			slab(g, "Canopy Rail", p0 + Vector3(0, 1.05, 0), p1 + Vector3(0, 1.05, 0), Vector2(0.1, 0.12), steel, false, 0.0)
			slab(g, "Canopy Railing", p0 + Vector3(0, 1.2, 0), p1 + Vector3(0, 1.2, 0), Vector2(1.4, 0.2), rail, true, 0.0).visible = false
		sg.put_seed("flower", Vector3(at.x, y, at.z))


func spiral_end_angle() -> float:
	return _spiral_turns() * TAU


func _spiral_turns() -> float:
	# Enough turns that the ramp's no steeper than about 1 in 4.5
	var rise := TALLEST.y - 0.6
	return ceilf(rise / (TAU * (SPIRAL_R + 0.95)) * 4.5 * 2.0) / 2.0 + 0.25


func _spiral(parent: Node3D) -> void:
	# A ramp winding up round the tallest supertree's trunk, from the ground to the deck in its canopy
	var g := group("Supertree Ramp", parent)
	var c := Vector3(TALLEST.x, SUPER_PAD, TALLEST.z)
	var turns := _spiral_turns()
	var rise := TALLEST.y - 0.6
	var n := int(turns * 24.0)
	var boards: StandardMaterial3D = sg._mat("Walk Boards", Color(0.55, 0.42, 0.3), 0.8)
	var steel: StandardMaterial3D = sg._mat("Supertree Steel", Color(0.42, 0.34, 0.4), 0.5)
	var rail: StandardMaterial3D = sg._mat("Walk Rail", Color(0.3, 0.25, 0.22), 0.7)
	var w := 1.9
	spiral_pts.clear()
	for i in n + 1:
		var t := float(i) / n
		var a := turns * TAU * t
		spiral_pts.append(c + Vector3(cos(a) * (SPIRAL_R + w / 2.0), rise * t + 0.03, sin(a) * (SPIRAL_R + w / 2.0)))
	# ...and in off its top onto the deck
	var a_end := turns * TAU
	spiral_pts.append(c + Vector3(cos(a_end) * 3.6, rise + 0.03, sin(a_end) * 3.6))
	var a0 := spiral_pts[0]
	for i in n + 1:
		var p0 := spiral_pts[i]
		var p1 := spiral_pts[i + 1]
		if i == n:
			# (the last bit runs straight in onto the deck from the ramp's inside edge, so its side's no ledge on the
			# ramp's last turn; no rail across it)
			slab(g, "Ramp Deck", p0.move_toward(Vector3(c.x, p0.y, c.z), w / 2.0), p1, Vector2(0.25, w), boards, true, 0.0)
			continue
		slab(g, "Ramp Deck", p0, p1, Vector2(0.25, w), boards, true, 0.0)
		var outer := Vector3(p0.x - c.x, 0, p0.z - c.z).normalized()
		var off0 := outer * (w / 2.0 - 0.08)
		var outer1 := Vector3(p1.x - c.x, 0, p1.z - c.z).normalized() * (w / 2.0 - 0.08)
		slab(g, "Ramp Rail", p0 + off0 + Vector3(0, 1.05, 0), p1 + outer1 + Vector3(0, 1.05, 0), Vector2(0.08, 0.1), steel, false, 0.0)
		slab(g, "Ramp Railing", p0 + off0 + Vector3(0, 1.15, 0), p1 + outer1 + Vector3(0, 1.15, 0), Vector2(1.4, 0.16), rail, true, 0.0).visible = false
		if i % 3 == 0:
			slab(g, "Ramp Arm", c + Vector3(0, p0.y - c.y - 0.5, 0) + outer * 1.2, p0 + off0 - Vector3(0, 0.3, 0), Vector2(0.12, 0.12), steel, false, 0.0)
	_keep.append(Vector3(a0.x, a0.z, 3.0))


func blocks(at: Vector3) -> bool:
	if near_kept(Vector2(at.x, at.z)):
		return true
	for t in trees:
		if Vector2(at.x, at.z).distance_to(Vector2(t.at.x, t.at.z)) < 2.2:
			return true
	return false


func wake(_k: float) -> void:
	pass


func finish(surfaces: Array) -> void:
	# The glasshouse's and supertrees' iron ribs, all one MultiMesh, then the kit's
	if not _rib_xf.is_empty():
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bm
		mm.instance_count = _rib_xf.size()
		for i in _rib_xf.size():
			mm.set_instance_transform(i, _rib_xf[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Iron Ribs"
		mmi.multimesh = mm
		mmi.material_override = iron_mat()
		mmi.visibility_range_end = 260.0
		add_child(mmi)
	super.finish(surfaces)


func step(_delta: float) -> void:
	for i in _canopies.size():
		var rim := _canopies[i].get_node_or_null("Supertree Rim") as Node3D
		if rim:
			rim.rotation.y = _t * (0.1 + 0.02 * i)
