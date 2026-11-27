extends "res://scripts/secret_garden_kit.gd"

# The rebuilt Secret Garden's house and the formal spine up the middle of the hill (26 Nov 2026; see
# scripts/secret_garden.gd). Our own take on these, not copies:
#   - the Old House (after Greystone, the Doheny family's house in Beverly Hills): a long grey stone Tudor-style manor
#     across the top of the hill, steep slate roofs, gabled bays, clustered chimneys, mullioned windows glowing amber.
#     Its door stays shut (nobody's lived there for years).
#   - the Overlook Terrace in front of it, TOP m up: a long reflection pool with lilies, a balustrade along its wall
#     with urns, and the whole garden spread out below. A grand stair up its wall from the Formal Garden, and one at
#     each end.
#   - the Formal Garden (after Greystone's): a big tiered fountain in the middle, four beds edged in clipped box with
#     roses, topiary cones at the corners, benches
#   - the Cypress Walk: twin rows of tall cypresses lining the way up from the Water Stairs (after Greystone's)
#   - the Water Stairs (after the Villa d'Este's cascades and its Hundred Fountains): water spilling down a long stone
#     staircase into a pool, with little jets along both sides, and stairs to walk up either side of it
#   - the Tulip Slope (after Keukenhof): rivers of tulips in bands across the slope, and a little windmill
# Its ground is the land's pads (secret_garden_land.gd); stairs are walked as ramps.

const OVERLOOK := LAND.TOP
const HOUSE_Z := Vector2(302.0, 319.0)          # the house's main block
const HOUSE_X := 27.0
const POOL := Rect2(-16.0, 289.0, 32.0, 6.0)    # the reflection pool on the Overlook
const FOUNTAIN := Vector3(0, 18.0, 261.0)       # the Formal Garden's fountain
const CASCADE_W := 4.4                          # the Water Stairs' channel, wall to wall
const CASCADE := Vector2(150.0, 195.0)          # from its foot to its head (z)
const SIDE_STAIR_X := 7.5
const WATER_POOL := Rect2(-5.2, 141.0, 10.4, 8.0)     # the pool at the Water Stairs' foot
# Which of the estate's materials wear which baked patch (detail_props.gd dress_place), and how big it's laid on
const SURFACES := [["Estate Stone", "stone", 1.0], ["Estate Stone Dark", "stone", 0.8],
	["Terrace Paving", "stone", 1.6], ["Slate Roof", "shingles", 0.9], ["Chimney Brick", "brick", 0.7],
	["Oak Door", "barn_boards", 0.6], ["Windmill Boards", "barn_boards", 0.8], ["Windmill Thatch", "shingles", 0.7]]
const TULIPS := [Color(0.95, 0.18, 0.25), Color(1.0, 0.82, 0.2), Color(1.0, 0.5, 0.75), Color(0.95, 0.95, 0.92),
	Color(0.62, 0.3, 0.85), Color(1.0, 0.5, 0.15)]

var _jets: Array[Node3D] = []                   # little arcs of drops, moved in step()
var _sheets: Array[MeshInstance3D] = []         # the falling water down each cascade step
var _sails: Node3D


func build(garden: Node3D) -> void:
	start(garden, "Estate", 2611)
	_overlook()
	_house()
	_formal_garden()
	_cypress_walk()
	_water_stairs()
	_tulip_slope()
	_estate_trees()
	finish(SURFACES)


func stone_wall(parent: Node3D, nm: String, a: Vector2, b: Vector2, top: float, thick: float) -> void:
	# A retaining wall from a to b (on the ground plane) up to top, down to well below the ground, with a cornice
	var low := minf(ground(a.x, a.y), ground(b.x, b.y)) - 2.0
	var mid := (a + b) / 2.0
	var length := a.distance_to(b)
	var yaw := -atan2(b.y - a.y, b.x - a.x)
	var bm := block(parent, nm, Vector3(length, top - low, thick), Vector3(mid.x, (top + low) / 2.0, mid.y), stone(), true, yaw)
	bm.name = nm
	block(parent, nm + " Cornice", Vector3(length + 0.3, 0.32, thick + 0.4), Vector3(mid.x, top - 0.12, mid.y), stone_dark(), false, yaw)


# -----------------------------------------------------------------------------
# The Overlook Terrace
# -----------------------------------------------------------------------------
func _overlook() -> void:
	var t := group("Overlook Terrace")
	var y := OVERLOOK
	# Its front wall over the Formal Garden, buttressed, and the lower walls down both sides
	var cuts: Array = []
	for s in LAND.STAIR_RAMPS:
		cuts.append(Vector2(s[0] - 0.3, s[1] + 0.3))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var x0 := -64.0
	for c: Vector2 in cuts:
		stone_wall(t, "Overlook Wall", Vector2(x0, 284.7), Vector2(c.x, 284.7), y, 1.4)
		balustrade(t, Vector3(x0 + 0.3, y, 285.3), Vector3(c.x, y, 285.3), true, true)
		x0 = c.y
	stone_wall(t, "Overlook Wall", Vector2(x0, 284.7), Vector2(64.0, 284.7), y, 1.4)
	balustrade(t, Vector3(x0, y, 285.3), Vector3(63.7, y, 285.3), true, true)
	var bx := -60.0
	while bx <= 60.0:
		var skip := false
		for c: Vector2 in cuts:
			if bx > c.x - 1.0 and bx < c.y + 1.0:
				skip = true
		if not skip:
			block(t, "Buttress", Vector3(1.1, y - 16.0, 0.8), Vector3(bx, (y + 16.0) / 2.0 - 0.4, 283.8), stone_dark(), false)
		bx += 8.0
	for side: float in [-1.0, 1.0]:
		stone_wall(t, "Overlook Side Wall", Vector2(side * 64.5, 284.5), Vector2(side * 64.5, LAND.Z_MAX - 0.6), y, 1.2)
		balustrade(t, Vector3(side * 63.9, y, 285.6), Vector3(side * 63.9, y, LAND.Z_MAX - 1.0), true, false)
	# The three stairs up its wall
	for s in LAND.STAIR_RAMPS:
		var cx: float = (s[0] + s[1]) / 2.0
		var w: float = s[1] - s[0] - 0.6
		stair(t, "Grand Stair" if absf(cx) < 1.0 else "Overlook Side Stair", Vector3(cx, s[4], s[2]), Vector3(cx, s[5], s[3]), w)
	# Paving round the reflection pool, and the pool itself: a long rectangle of still water with a stone kerb,
	# water lilies, and a jet at each end
	var pave := paving()
	block(t, "Terrace Paving", Vector3(POOL.size.x + 8.0, 0.06, POOL.size.y + 6.0), Vector3(0, y + 0.03, POOL.get_center().y), pave, false)
	var kerb := stone_dark()
	var p0 := POOL.position
	var p1 := POOL.end
	for e in [[Vector2(p0.x, p0.y), Vector2(p1.x, p0.y)], [Vector2(p1.x, p0.y), Vector2(p1.x, p1.y)],
			[Vector2(p1.x, p1.y), Vector2(p0.x, p1.y)], [Vector2(p0.x, p1.y), Vector2(p0.x, p0.y)]]:
		slab(t, "Pool Kerb", Vector3(e[0].x, y + 0.42, e[0].y), Vector3(e[1].x, y + 0.42, e[1].y), Vector2(0.5, 0.55), kerb, true, 0.0)
	var water := BoxMesh.new()
	water.size = Vector3(POOL.size.x - 0.5, 0.05, POOL.size.y - 0.5)
	sg._mesh(t, water, Vector3(0, y + 0.22, POOL.get_center().y), water_mat(), false).name = "Reflection Pool"
	var pad_m: StandardMaterial3D = sg._mat("Lily Pad", Color(0.28, 0.55, 0.26), 0.7)
	for i in 26:
		var at := Vector3(_rng.randf_range(p0.x + 1.0, p1.x - 1.0), y + 0.26, _rng.randf_range(p0.y + 0.8, p1.y - 0.8))
		disc(t, "Lily Pad", at, _rng.randf_range(0.28, 0.5), pad_m, 10)
		if i % 3 == 0:
			sg._ball(t, 0.13, at + Vector3(0, 0.08, 0), glow(sg._mat("Water Lily", Color(1.0, 0.78, 0.88), 0.5, 0.25)), 0.6)
	for side: float in [-1.0, 1.0]:
		_jet(t, Vector3(side * (POOL.size.x / 2.0 - 1.0), y + 0.25, POOL.get_center().y), Vector3(-side, 0, 0), 2.2, 2.6)
	# Topiary, urns and benches along it
	for px: float in [-24.0, -8.0, 8.0, 24.0]:
		block(t, "Planter", Vector3(1.4, 0.8, 1.4), Vector3(px, y + 0.4, 297.0), stone(), true)
		sg._ball(t, 0.95, Vector3(px, y + 1.75, 297.0), sg._hedge(), 1.0)
	for bxx: float in [-34.0, -22.0, 22.0, 34.0]:
		_bench(t, Vector3(bxx, y, 287.6), 0.0)


func _bench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var m: Mesh = baked("res://models/props/secret_garden/garden_bench.glb")
	if m:
		var mi := sg._mesh(parent, m, at + Vector3(0, 0.3, 0), null) as MeshInstance3D
		mi.name = "Bench"
		mi.rotation.y = yaw
	else:
		block(parent, "Bench", Vector3(2.0, 0.45, 0.6), at + Vector3(0, 0.23, 0), sg._mat("Bench Wood", Color(0.55, 0.38, 0.32)), false, yaw)
	# (the same solid shape either way)
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 0.6, 0.6)
	sg._solid(parent, "Bench Body", bs, at + Vector3(0, 0.3, 0), Vector3(0, yaw, 0))


func _jet(parent: Node3D, at: Vector3, dir: Vector3, reach: float, high: float, drops := 8) -> void:
	# A little arc of water from at, out along dir (moved in step())
	var jet := group("Jet", parent)
	jet.position = at
	jet.set_meta("dir", dir)
	jet.set_meta("reach", reach)
	jet.set_meta("high", high)
	for k in drops:
		sg._ball(jet, 0.08, Vector3.ZERO, spray_mat())
	_jets.append(jet)


# -----------------------------------------------------------------------------
# The Old House
# -----------------------------------------------------------------------------
func _house() -> void:
	var h := group("Old House")
	var y0 := OVERLOOK
	var st := stone()
	var dark := stone_dark()
	var slate: StandardMaterial3D = sg._mat("Slate Roof", Color(0.3, 0.31, 0.38), 0.75)
	var wall_h := 10.0
	var depth := HOUSE_Z.y - HOUSE_Z.x
	var mid_z := (HOUSE_Z.x + HOUSE_Z.y) / 2.0
	block(h, "House Wall", Vector3(HOUSE_X * 2.0, wall_h, depth), Vector3(0, y0 + wall_h / 2.0, mid_z), st)
	block(h, "House Plinth", Vector3(HOUSE_X * 2.0 + 0.4, 0.7, depth + 0.4), Vector3(0, y0 + 0.35, mid_z), dark, false)
	block(h, "String Course", Vector3(HOUSE_X * 2.0 + 0.3, 0.25, depth + 0.3), Vector3(0, y0 + 4.7, mid_z), dark, false)
	block(h, "Parapet Course", Vector3(HOUSE_X * 2.0 + 0.4, 0.3, depth + 0.4), Vector3(0, y0 + wall_h - 0.1, mid_z), dark, false)
	_gable_roof(h, Vector3(0, y0 + wall_h, mid_z), HOUSE_X * 2.0 + 0.6, depth + 0.8, 7.5, true, slate)
	for side: float in [-1.0, 1.0]:
		_gable_wall(h, Vector3(side * (HOUSE_X + 0.45), y0 + wall_h - 0.1, mid_z), depth + 0.5, 7.8, PI / 2.0)
	# Five gabled bays stand forward of it: a tall one in the middle with the door, two either side
	for b in [[-20.0, 8.0, 3.0, wall_h], [-9.5, 7.0, 2.4, wall_h - 1.0], [0.0, 10.0, 4.0, wall_h + 2.0],
			[9.5, 7.0, 2.4, wall_h - 1.0], [20.0, 8.0, 3.0, wall_h]]:
		var bx: float = b[0]
		var bw: float = b[1]
		var bd: float = b[2]
		var bh: float = b[3]
		var front := HOUSE_Z.x - bd
		block(h, "Bay Wall", Vector3(bw, bh, bd + 0.2), Vector3(bx, y0 + bh / 2.0, front + (bd + 0.2) / 2.0), st)
		block(h, "Bay Plinth", Vector3(bw + 0.4, 0.7, bd + 0.4), Vector3(bx, y0 + 0.35, front + bd / 2.0), dark, false)
		block(h, "String Course", Vector3(bw + 0.3, 0.25, bd + 0.3), Vector3(bx, y0 + 4.7, front + bd / 2.0), dark, false)
		var gh := 5.0 if bw < 9.0 else 6.8
		_gable_roof(h, Vector3(bx, y0 + bh, front + 3.6), bw + 0.6, 7.6, gh, false, slate)
		_gable_wall(h, Vector3(bx, y0 + bh - 0.1, front - 0.35), bw + 0.4, gh + 0.35, 0.0)
		_quoins(h, Vector3(bx - bw / 2.0, y0, front), bh)
		_quoins(h, Vector3(bx + bw / 2.0, y0, front), bh)
		if bw < 9.0:
			_window(h, Vector3(bx, y0 + 2.4, front), bw * 0.55, 2.6, 4 if bw > 7.5 else 3)
			_window(h, Vector3(bx, y0 + 7.0, front), bw * 0.55, 2.4, 4 if bw > 7.5 else 3)
			_window(h, Vector3(bx, y0 + bh + 1.8, front - 0.55), 1.6, 1.8, 2)
		else:
			_door(h, Vector3(bx, y0, front))
			_window(h, Vector3(bx, y0 + 7.4, front), 5.6, 3.2, 5)
			_window(h, Vector3(bx, y0 + bh + 2.4, front - 0.55), 2.0, 2.4, 2)
	for wx: float in [-25.0, -14.75, 14.75, 25.0]:
		_window(h, Vector3(wx, y0 + 2.4, HOUSE_Z.x), 2.2, 2.6, 2)
		_window(h, Vector3(wx, y0 + 7.0, HOUSE_Z.x), 2.2, 2.4, 2)
	for side: float in [-1.0, 1.0]:
		for wz: float in [306.0, 311.0, 316.0]:
			_window(h, Vector3(side * HOUSE_X, y0 + 2.4, wz), 2.2, 2.6, 2, side * PI / 2.0)
			_window(h, Vector3(side * HOUSE_X, y0 + 7.0, wz), 2.2, 2.4, 2, side * PI / 2.0)
		_quoins(h, Vector3(side * HOUSE_X, y0, HOUSE_Z.x), wall_h)
	for cx: float in [-22.0, -13.0, 13.0, 22.0]:
		_chimney(h, Vector3(cx, y0 + wall_h + 3.0, mid_z + 1.8))
	# A round stair tower at the west end with a conical slate cap, like the big houses have
	var tower := Vector3(-HOUSE_X - 1.5, y0, HOUSE_Z.x + 1.5)
	sg._cyl(h, "Stair Tower", 3.0, 3.0, wall_h + 4.0, tower + Vector3(0, (wall_h + 4.0) / 2.0, 0), st, true)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 3.6
	cone.height = 6.0
	cone.radial_segments = 16
	sg._mesh(h, cone, tower + Vector3(0, wall_h + 7.0, 0), slate).name = "Tower Roof"
	for k in 3:
		_window(h, tower + Vector3(0, 3.0 + k * 4.2, -3.0), 1.0, 2.0, 1)


func _gable_roof(parent: Node3D, base: Vector3, length: float, span: float, rise: float, along_x: bool, m: Material) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(span, rise, length) if along_x else Vector3(length, rise, span)
	var mi := sg._mesh(parent, pm, base + Vector3(0, rise / 2.0, 0), m) as MeshInstance3D
	mi.name = "Roof"
	if along_x:
		mi.rotation.y = PI / 2.0
	var ridge := BoxMesh.new()
	ridge.size = Vector3(length, 0.22, 0.3) if along_x else Vector3(0.3, 0.22, span)
	sg._mesh(parent, ridge, base + Vector3(0, rise + 0.02, 0), stone_dark()).name = "Ridge"


func _gable_wall(parent: Node3D, base: Vector3, width: float, rise: float, yaw: float) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(width, rise, 0.35)
	var mi := sg._mesh(parent, pm, base + Vector3(0, rise / 2.0, 0), stone()) as MeshInstance3D
	mi.name = "Gable"
	mi.rotation.y = yaw
	var fin := sg._mesh(parent, lathe([Vector2(0.18, 0), Vector2(0.18, 0.3), Vector2(0.1, 0.4), Vector2(0.14, 0.7), Vector2(0.0, 1.2)], 8),
		base + Vector3(0, rise - 0.05, 0), stone_dark()) as MeshInstance3D
	fin.name = "Finial"


func _quoins(parent: Node3D, corner: Vector3, height: float) -> void:
	var y := 0.7
	var k := 0
	while y < height - 0.3:
		var long := 0.62 if k % 2 == 0 else 0.4
		var qm := BoxMesh.new()
		qm.size = Vector3(long, 0.5, long)
		sg._mesh(parent, qm, corner + Vector3(0, y + 0.25, 0), stone_dark()).name = "Quoin"
		y += 0.6
		k += 1


func _window(parent: Node3D, at: Vector3, w: float, h: float, lights: int, yaw := PI) -> void:
	# A mullioned window, leaded panes glowing amber, a stone surround, mullions and a transom, and a sill
	var win := group("Window", parent)
	win.position = at
	win.rotation.y = yaw
	var glass: StandardMaterial3D = sg._mat("Leaded Window", Color(1.0, 0.8, 0.5), 0.3, 0.55)
	var gm := BoxMesh.new()
	gm.size = Vector3(w, h, 0.06)
	sg._mesh(win, gm, Vector3(0, 0, 0.05), glass, false).name = "Panes"
	var dark := stone_dark()
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
	var d := group("Front Door", parent)
	d.position = at
	d.rotation.y = PI
	var dark := stone_dark()
	var oak: StandardMaterial3D = sg._mat("Oak Door", Color(0.42, 0.3, 0.27), 0.85)
	var dm := BoxMesh.new()
	dm.size = Vector3(2.6, 3.6, 0.12)
	sg._mesh(d, dm, Vector3(0, 1.8, 0.04), oak).name = "Door Leaf"
	var arch := PrismMesh.new()
	arch.size = Vector3(2.6, 0.7, 0.12)
	sg._mesh(d, arch, Vector3(0, 3.95, 0.04), oak).name = "Door Arch"
	for side: float in [-1.0, 1.0]:
		var jm := BoxMesh.new()
		jm.size = Vector3(0.45, 4.5, 0.5)
		sg._mesh(d, jm, Vector3(side * 1.55, 2.25, 0.2), dark).name = "Door Jamb"
		sg._ball(d, 0.07, Vector3(side * 0.35, 1.7, 0.14), sg._mat("Old Brass", Color(0.85, 0.68, 0.35), 0.3))
	var head := PrismMesh.new()
	head.size = Vector3(3.6, 0.9, 0.5)
	sg._mesh(d, head, Vector3(0, 4.95, 0.2), dark).name = "Door Head"
	var shield := sg._mesh(d, lathe([Vector2(0.0, 0.0), Vector2(0.4, 0.25), Vector2(0.5, 0.9), Vector2(0.0, 0.9)], 4),
		Vector3(0, 5.8, 0.12), stone()) as MeshInstance3D
	shield.name = "Shield"
	shield.scale = Vector3(1, 1, 0.3)
	for i in 2:
		var sm := BoxMesh.new()
		sm.size = Vector3(3.8 - i * 0.6, 0.12, 1.2 - i * 0.4)
		sg._mesh(d, sm, Vector3(0, 0.06 + i * 0.12, 0.6 - i * 0.2), dark).name = "Door Step"


func _chimney(parent: Node3D, base: Vector3) -> void:
	var brick: StandardMaterial3D = sg._mat("Chimney Brick", Color(0.62, 0.5, 0.56), 0.9)
	block(parent, "Chimney Stack", Vector3(2.4, 5.0, 1.4), base + Vector3(0, 2.5, 0), stone(), false)
	block(parent, "Chimney Band", Vector3(2.7, 0.3, 1.7), base + Vector3(0, 5.1, 0), stone_dark(), false)
	for i in 3:
		var at := base + Vector3(-0.75 + i * 0.75, 5.25, 0)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 2.8
		cm.radial_segments = 8
		sg._mesh(parent, cm, at + Vector3(0, 1.4, 0), brick).name = "Chimney Shaft"
		var cap := CylinderMesh.new()
		cap.top_radius = 0.42
		cap.bottom_radius = 0.36
		cap.height = 0.3
		cap.radial_segments = 8
		sg._mesh(parent, cap, at + Vector3(0, 2.9, 0), stone_dark()).name = "Chimney Pot"


# -----------------------------------------------------------------------------
# The Formal Garden
# -----------------------------------------------------------------------------
func _formal_garden() -> void:
	var f := group("Formal Garden")
	var y := FOUNTAIN.y
	_tiered_fountain(f, FOUNTAIN)
	# Four big beds either side of the fountain's square, each edged in clipped box, with roses inside and a topiary cone
	# at each corner (the square round the fountain stays open, so you can walk round it to every path and stair)
	var hedge: StandardMaterial3D = sg._hedge()
	var roses := [glow(sg._mat("Rose White", Color(1.0, 0.97, 0.93), 0.6, 0.15)), glow(sg._mat("Rose Blush", Color(1.0, 0.82, 0.86), 0.6, 0.15))]
	var beds := [Rect2(-54, 248, 40, 10), Rect2(14, 248, 40, 10), Rect2(-54, 264, 40, 7), Rect2(14, 264, 40, 7)]
	for bed: Rect2 in beds:
		# Cut round the fountain, the side stairs' paths and the middle path
		var x0 := bed.position.x
		var x1 := bed.end.x
		var z0 := bed.position.y
		var z1 := bed.end.y
		var gaps := [-46.0, 46.0]
		for gx: float in gaps:
			if gx > x0 and gx < x1:
				_hedge_line(f, Vector2(x0, z0), Vector2(gx - 2.0, z0), hedge)
				_hedge_line(f, Vector2(gx + 2.0, z0), Vector2(x1, z0), hedge)
				_hedge_line(f, Vector2(x0, z1), Vector2(gx - 2.0, z1), hedge)
				_hedge_line(f, Vector2(gx + 2.0, z1), Vector2(x1, z1), hedge)
		_hedge_line(f, Vector2(x0, z0), Vector2(x0, z1), hedge)
		_hedge_line(f, Vector2(x1, z0), Vector2(x1, z1), hedge)
		for c in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
			_topiary_cone(f, Vector3(c.x, y, c.y))
		var xx := x0 + 1.2
		while xx < x1 - 1.0:
			if absf(xx - 46.0) > 2.6 and absf(xx + 46.0) > 2.6 and Vector2(xx, (z0 + z1) / 2.0).distance_to(Vector2(0, 261)) > 12.0:
				var zz := z0 + 1.4
				while zz < z1 - 1.0:
					var at := Vector3(xx + _rng.randf_range(-0.3, 0.3), y, zz + _rng.randf_range(-0.3, 0.3))
					sg._ball(f, 0.45, at + Vector3(0, 0.35, 0), sg._leaf(), 0.8)
					for k in 3:
						sg._ball(f, 0.14, at + Vector3(_rng.randf_range(-0.35, 0.35), 0.72, _rng.randf_range(-0.35, 0.35)), roses[(k + int(xx)) % 2])
					zz += 2.2
			xx += 2.4
	# Benches facing the fountain
	for b in [[Vector3(-11.5, y, 255.0), PI / 2.0], [Vector3(11.5, y, 255.0), -PI / 2.0], [Vector3(-11.5, y, 267.0), PI / 2.0], [Vector3(11.5, y, 267.0), -PI / 2.0]]:
		_bench(f, b[0], b[1])
	# The Cypress Walk's top: two stone piers with urns where it enters the garden
	for side: float in [-1.0, 1.0]:
		block(f, "Gate Pier", Vector3(1.0, 2.4, 1.0), Vector3(side * 4.2, y + 1.2, 240.5), stone(), true)
		urn(f, Vector3(side * 4.2, y + 2.4, 240.5), 1.2)


func _hedge_line(parent: Node3D, a: Vector2, b: Vector2, _m: Material) -> void:
	# A length of low clipped box
	hedge(parent, on_ground(a.x, a.y), on_ground(b.x, b.y), 0.75, 0.6)


func _topiary_cone(parent: Node3D, at: Vector3) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.75
	cm.height = 2.4
	cm.radial_segments = 12
	var mi := sg._mesh(parent, cm, at + Vector3(0, 1.4, 0), sg._hedge()) as MeshInstance3D
	mi.name = "Topiary Cone"
	sg._cyl(parent, "Topiary Pot", 0.5, 0.42, 0.4, at + Vector3(0, 0.2, 0), stone_dark(), true)


func _tiered_fountain(parent: Node3D, at: Vector3) -> void:
	# The big fountain: a wide round pool, a column holding two tiers of basins that spill over, a jet on top and a
	# ring of jets round the pool's rim arching in
	var g := group("Great Fountain", parent)
	g.position = at
	var st := stone()
	var dark := stone_dark()
	var pool_r := 7.0
	ring_wall(g, "Fountain Rim", Vector3.ZERO, pool_r, 0.55, 0.6, st, 28)
	ring_wall(g, "Fountain Coping", Vector3(0, 0.08, 0), pool_r, 0.55, 0.8, dark, 28, false)
	disc(g, "Fountain Water", Vector3(0, 0.3, 0), pool_r - 0.3, water_mat())
	wade("Fountain Water Zone", [Vector4(at.x, at.z, pool_r - 0.4, pool_r - 0.4)] as Array[Vector4], at.y + 0.3)
	var baked_f: Mesh = baked("res://models/props/estate/tiered_fountain.glb")
	if baked_f:
		var mi := sg._mesh(g, baked_f, Vector3.ZERO, null) as MeshInstance3D
		mi.name = "Fountain Tiers"
	else:
		sg._mesh(g, lathe([Vector2(1.6, 0.0), Vector2(1.6, 0.5), Vector2(1.0, 0.7), Vector2(0.7, 1.2), Vector2(0.6, 2.6),
			Vector2(3.2, 2.9), Vector2(3.4, 3.3), Vector2(3.0, 3.35), Vector2(0.5, 3.4), Vector2(0.45, 4.8), Vector2(1.9, 5.0),
			Vector2(2.0, 5.3), Vector2(1.7, 5.35), Vector2(0.35, 5.4), Vector2(0.3, 6.2), Vector2(0.55, 6.5), Vector2(0.0, 6.9)], 24),
			Vector3.ZERO, st).name = "Fountain Tiers"
	var col := CylinderShape3D.new()
	col.radius = 1.6
	col.height = 6.0
	sg._solid(g, "Fountain Column", col, Vector3(0, 3.0, 0))
	# Water spilling over each tier's lip in a sheet (a thin see-through ring), and the jets
	for tier in [[3.3, 3.35], [5.3, 2.0]]:
		var ring := CylinderMesh.new()
		ring.top_radius = tier[1] + 0.05
		ring.bottom_radius = tier[1] + 0.25
		ring.height = tier[0] - (0.4 if tier[0] > 4.0 else 0.35)
		ring.cap_top = false
		ring.cap_bottom = false
		ring.radial_segments = 28
		var sheet := sg._mesh(g, ring, Vector3(0, tier[0] - ring.height / 2.0, 0), spray_mat(), false) as MeshInstance3D
		sheet.name = "Water Sheet"
		_sheets.append(sheet)
		disc(g, "Tier Water", Vector3(0, tier[0] - 0.05, 0), tier[1] - 0.15, water_mat())
	_jet(g, Vector3(0, 6.9, 0), Vector3.ZERO, 0.0, 2.4, 10)
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		_jet(g, Vector3(cos(a), 0, sin(a)) * (pool_r - 0.3) + Vector3(0, 0.6, 0), -Vector3(cos(a), 0, sin(a)), 3.2, 2.8)


# -----------------------------------------------------------------------------
# The Cypress Walk and its terrace
# -----------------------------------------------------------------------------
func _cypress_walk() -> void:
	var c := group("Cypress Walk")
	var z := 207.0
	while z < 239.5:
		for side: float in [-1.0, 1.0]:
			tree("cypress", on_ground(side * 5.6, z), _rng.randf_range(1.1, 1.25))
			# a little bed of lavender between each pair
			if z < 236.0:
				var at := on_ground(side * 5.6, z + 2.2)
				for k in 4:
					sg._ball(c, 0.32, at + Vector3(_rng.randf_range(-0.4, 0.4), 0.25, _rng.randf_range(-0.6, 0.6)),
						glow(sg._mat("Lavender", Color(0.62, 0.5, 0.92), 0.7, 0.15)), 0.8)
		z += 4.4
	# The Cypress Terrace over the Water Stairs: a balustrade along its front, with gaps for the side stairs, and
	# a fountain head in the middle where the cascade begins
	var y := 14.0
	var front := 195.3
	var x0 := -18.0
	for gx: float in [-SIDE_STAIR_X, SIDE_STAIR_X]:
		balustrade(c, Vector3(x0, y, front), Vector3(gx - 2.3, y, front), true, true)
		x0 = gx + 2.3
	balustrade(c, Vector3(x0, y, front), Vector3(18.0, y, front), true, true)


# -----------------------------------------------------------------------------
# The Water Stairs
# -----------------------------------------------------------------------------
func _water_stairs() -> void:
	var w := group("Water Stairs")
	var st := stone()
	var dark := stone_dark()
	var z0 := CASCADE.x
	var z1 := CASCADE.y
	var steps := 16
	var run := (z1 - z0) / steps
	var half := CASCADE_W / 2.0
	# The channel: a kerb either side up the slope, and the stepped basins inside it, each a pool of water spilling
	# over its lip into the next
	for side: float in [-1.0, 1.0]:
		var a := Vector3(side * (half + 0.3), ground(side * (half + 0.3), z0), z0)
		var b := Vector3(side * (half + 0.3), ground(side * (half + 0.3), z1), z1)
		slab(w, "Cascade Kerb", a + Vector3(0, 0.6, 0), b + Vector3(0, 0.6, 0), Vector2(1.6, 0.6), st, true, 0.0)
		slab(w, "Kerb Coping", a + Vector3(0, 0.68, 0), b + Vector3(0, 0.68, 0), Vector2(0.14, 0.8), dark, false, 0.0)
	for i in steps:
		var za := z0 + run * i
		var zb := za + run
		var top := ground(0, zb)
		var basin := BoxMesh.new()
		basin.size = Vector3(CASCADE_W, 1.2, run)
		sg._mesh(w, basin, Vector3(0, top - 0.6 - 0.15, (za + zb) / 2.0), st).name = "Cascade Step"
		var water := BoxMesh.new()
		water.size = Vector3(CASCADE_W - 0.1, 0.04, run - 0.1)
		sg._mesh(w, water, Vector3(0, top - 0.08, (za + zb) / 2.0), water_mat(), false).name = "Cascade Water"
		# the fall over this step's front lip, down to the one below
		var drop := top - ground(0, za)
		var sheet := BoxMesh.new()
		sheet.size = Vector3(CASCADE_W - 0.2, drop + 0.1, 0.06)
		var sh := sg._mesh(w, sheet, Vector3(0, top - 0.1 - drop / 2.0, za + 0.05), spray_mat(), false) as MeshInstance3D
		sh.name = "Cascade Fall"
		_sheets.append(sh)
		var lip := BoxMesh.new()
		lip.size = Vector3(CASCADE_W, 0.12, 0.3)
		sg._mesh(w, lip, Vector3(0, top - 0.06, za + 0.15), dark).name = "Cascade Lip"
	# Its head: a stone niche in the Cypress Terrace's wall, a mask pouring water, urns either side
	var head := group("Cascade Head", w)
	head.position = Vector3(0, ground(0, z1), z1)
	block(head, "Niche", Vector3(7.0, 3.4, 1.0), Vector3(0, 1.0, 0.6), st, true)
	var arch := TorusMesh.new()
	arch.inner_radius = 1.5
	arch.outer_radius = 1.9
	var am := sg._mesh(head, arch, Vector3(0, 1.6, 0.05), dark) as MeshInstance3D
	am.rotation.x = PI / 2.0
	am.name = "Niche Arch"
	sg._ball(head, 0.6, Vector3(0, 1.6, -0.1), st, 0.9).name = "Mask"
	var pour := BoxMesh.new()
	pour.size = Vector3(0.5, 1.6, 0.08)
	var pm := sg._mesh(head, pour, Vector3(0, 0.75, -0.5), spray_mat(), false) as MeshInstance3D
	pm.name = "Mask Pour"
	_sheets.append(pm)
	# The Hundred Fountains: little jets all the way up both sides, arching into the channel
	var k := 0
	var z := z0 + 1.2
	while z < z1 - 1.0:
		for side: float in [-1.0, 1.0]:
			_jet(w, Vector3(side * (half + 0.3), ground(side * (half + 0.3), z) + 0.8, z), Vector3(-side, 0, 0), 1.6, 0.9, 6)
		z += 2.4
		k += 1
	# The stairs either side, walked as ramps, with balustrades on their outer sides
	for side: float in [-1.0, 1.0]:
		var x := side * SIDE_STAIR_X
		stair(w, "Water Stair", Vector3(x, ground(x, z0), z0), Vector3(x, ground(x, z1), z1), 3.6, false, false)
		var ox := x + side * 2.2
		balustrade_run(w, [Vector3(ox, ground(ox, z0), z0), Vector3(ox, ground(ox, (z0 + z1) / 2.0), (z0 + z1) / 2.0),
			Vector3(ox, ground(ox, z1), z1)], true, true)
	# The pool at the foot, the falls landing in it
	var py := ground(0, WATER_POOL.get_center().y)
	var r0 := WATER_POOL.position
	var r1 := WATER_POOL.end
	for e in [[Vector2(r0.x, r0.y), Vector2(r1.x, r0.y)], [Vector2(r1.x, r0.y), Vector2(r1.x, r1.y)],
			[Vector2(r0.x, r1.y), Vector2(r0.x, r0.y)]]:
		slab(w, "Pool Kerb", Vector3(e[0].x, py + 0.45, e[0].y), Vector3(e[1].x, py + 0.45, e[1].y), Vector2(0.9, 0.6), dark, true, 0.0)
	for e in [[Vector2(r1.x, r1.y), Vector2(half + 0.6, r1.y)], [Vector2(-half - 0.6, r1.y), Vector2(r0.x, r1.y)]]:
		slab(w, "Pool Kerb", Vector3(e[0].x, py + 0.45, e[0].y), Vector3(e[1].x, py + 0.45, e[1].y), Vector2(0.9, 0.6), dark, true, 0.0)
	var water := BoxMesh.new()
	water.size = Vector3(WATER_POOL.size.x - 0.6, 0.05, WATER_POOL.size.y - 0.6)
	sg._mesh(w, water, Vector3(0, py + 0.25, WATER_POOL.get_center().y), water_mat(), false).name = "Foot Pool"
	block(w, "Foot Pool Floor", Vector3(WATER_POOL.size.x, 0.4, WATER_POOL.size.y), Vector3(0, py - 0.15, WATER_POOL.get_center().y), dark, false)
	for side: float in [-1.0, 1.0]:
		_jet(w, Vector3(side * 3.0, py + 0.3, 144.0), Vector3.ZERO, 0.0, 3.0, 9)


# -----------------------------------------------------------------------------
# The Tulip Slope
# -----------------------------------------------------------------------------
func _tulip_slope() -> void:
	var t := group("Tulip Slope")
	# Rivers of colour: bands that wind across the slope, each its own colour, either side of the path up
	var stems: Array = []
	var cups := []
	for c in TULIPS:
		cups.append([])
	var x := -25.0
	while x <= 25.0:
		var z := 97.0
		while z <= 139.0:
			if absf(x) > 3.2 and absf(x) < 24.5:
				var jx := x + _rng.randf_range(-0.25, 0.25)
				var jz := z + _rng.randf_range(-0.25, 0.25)
				var band := int(floor((jz + 6.0 * sin(jx * 0.12) + absf(jx) * 0.35) / 5.0))
				var at := on_ground(jx, jz)
				var h := _rng.randf_range(0.4, 0.55)
				stems.append(Transform3D(Basis.from_scale(Vector3(1, h, 1)), at + Vector3(0, h / 2.0, 0)))
				cups[posmod(band, TULIPS.size())].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), at + Vector3(0, h, 0)))
			z += 0.75
		x += 0.75
	var cup := lathe([Vector2(0.0, -0.02), Vector2(0.07, 0.0), Vector2(0.11, 0.08), Vector2(0.1, 0.16), Vector2(0.08, 0.2), Vector2(0.0, 0.17)], 6)
	for i in TULIPS.size():
		var m := glow(sg._mat("Tulip %d" % i, TULIPS[i], 0.55, 0.12))
		sg._multi(t, "Tulips %d" % i, cup, cups[i], m)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.018
	stalk.bottom_radius = 0.022
	stalk.height = 1.0
	stalk.radial_segments = 4
	sg._multi(t, "Tulip Stems", stalk, stems, sg._leaf())
	_windmill(t, on_ground(-19.0, 131.0))


func _windmill(parent: Node3D, at: Vector3) -> void:
	# A little Dutch windmill at the top of the slope: a tapering eight-sided body of boards, a thatched cap, and sails
	# that turn (step())
	var w := group("Windmill", parent)
	w.position = at
	w.rotation.y = 0.5
	var boards: StandardMaterial3D = sg._mat("Windmill Boards", Color(0.36, 0.28, 0.26), 0.9)
	block(w, "Mill Base", Vector3(5.0, 1.4, 5.0), Vector3(0, 0.5, 0), stone_dark(), true)
	var body := CylinderMesh.new()
	body.top_radius = 1.6
	body.bottom_radius = 2.4
	body.height = 7.0
	body.radial_segments = 8
	sg._mesh(w, body, Vector3(0, 4.7, 0), boards).name = "Mill Body"
	var bs := CylinderShape3D.new()
	bs.radius = 2.3
	bs.height = 7.0
	sg._solid(w, "Mill Body Body", bs, Vector3(0, 4.7, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.2
	cap.bottom_radius = 2.0
	cap.height = 2.2
	cap.radial_segments = 8
	sg._mesh(w, cap, Vector3(0, 9.3, 0), sg._mat("Windmill Thatch", Color(0.6, 0.5, 0.36), 0.95)).name = "Mill Cap"
	_window(w, Vector3(0, 2.0, -2.25), 0.9, 1.4, 1)
	_sails = group("Sails", w)
	_sails.position = Vector3(0, 7.8, -2.2)
	var sail_m: StandardMaterial3D = sg._mat("Sail Cloth", Color(0.94, 0.9, 0.84), 0.9)
	sail_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 4:
		var arm := group("Sail", _sails)
		arm.rotation.z = TAU * i / 4.0
		block(arm, "Sail Stock", Vector3(0.18, 6.0, 0.18), Vector3(0, 3.0, 0), boards, false)
		block(arm, "Sail Cloth", Vector3(1.4, 4.6, 0.04), Vector3(0.8, 3.6, 0.05), sail_m, false)
	sg._ball(_sails, 0.35, Vector3.ZERO, stone_dark())


# -----------------------------------------------------------------------------
# Trees: oaks round the Formal Garden, cypresses at the house, a few great trees on the slopes either side
# -----------------------------------------------------------------------------
func _estate_trees() -> void:
	for side: float in [-1.0, 1.0]:
		for z: float in [244.0, 256.0, 268.0, 280.0]:
			if side < 0.0 and z < 260.0:
				continue                        # (the maze's lookout stands there)
			tree("oak" if int(z) % 24 == 4 else "copper", on_ground(side * 63.0, z), _rng.randf_range(0.8, 0.95))
		tree("cypress", on_ground(side * (HOUSE_X + 5.0), 300.0), 1.35)
		tree("cypress", on_ground(side * (HOUSE_X + 9.0), 300.0), 1.2)
		for z: float in [156.0, 172.0, 188.0]:
			if z == 172.0:
				tree("blossom" if side < 0 else "blossom_white", on_ground(side * 30.0, z), 1.2)
			else:
				tree("oak", on_ground(side * 30.0, z), _rng.randf_range(0.85, 1.0))
		for z: float in [214.0, 228.0]:
			tree("copper" if side < 0 else "oak", on_ground(side * 26.0, z), 0.9)


func blocks(at: Vector3) -> bool:
	for t in trees:
		if Vector2(at.x, at.z).distance_to(Vector2(t.at.x, t.at.z)) < 2.5:
			return true
	return false


func wake(_k: float) -> void:
	pass


# -----------------------------------------------------------------------------
# Every frame: the jets arch, the falls shimmer, the windmill turns
# -----------------------------------------------------------------------------
func step(delta: float) -> void:
	for jet in _jets:
		var n := jet.get_child_count()
		var dir: Vector3 = jet.get_meta("dir")
		var reach: float = jet.get_meta("reach")
		var high: float = jet.get_meta("high")
		for k in n:
			var s := fposmod(_t * 0.9 + float(k) / n, 1.0)
			var drop := jet.get_child(k) as Node3D
			if reach <= 0.0:
				# straight up and falling back round itself
				drop.position = Vector3(sin(k * 2.1) * 0.25 * s, high * 4.0 * s * (1.0 - s), cos(k * 2.1) * 0.25 * s)
			else:
				drop.position = dir * reach * s + Vector3(0, high * 4.0 * s * (1.0 - s) - s * 0.4, 0)
	for f in _sheets:
		f.scale.x = 1.0 + sin(_t * 9.0 + f.position.z) * 0.04
	if _sails:
		_sails.rotation.z = -_t * 0.6
