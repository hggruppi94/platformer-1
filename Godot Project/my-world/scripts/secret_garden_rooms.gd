extends "res://scripts/secret_garden_kit.gd"

# The rebuilt Secret Garden's garden rooms on the upper slopes (26 Nov 2026; see scripts/secret_garden.gd). Our own
# take on these, not copies:
#   - the Hedge Maze (after the great English hedge mazes): a maze of tall yew, a different way through it each time it's
#     built from its seed, the maze seed asleep in a little court at its heart by a sundial, and a stone lookout beside it
#     to see the way in from above
#   - the Potager (after Villandry's kitchen garden): square beds edged in low box, each in a pattern, filled with
#     cabbages, lettuces and herbs in rows of colour, standard roses at the corners, a vine arbour along the top
#   - the Rill Court (after the Generalife's water court in the Alhambra): a long narrow rill with jets arching over it
#     from both sides, orange trees in rows, an arcade of arches at its end
#   - the Sunken Quarry Garden (after the Butchart Gardens' sunken garden, made in an old limestone quarry): cliffs all
#     round, a ramp carved round them down to beds of flowers on its floor, a pool with a fountain and a waterfall
#     pouring down the cliff
# Their ground is the land's pads and the quarry (secret_garden_land.gd).

const MAZE_CELL := 3.0
const MAZE_N := 12
const MAZE_ORIGIN := Vector2(-114.0, 242.0)     # its south-west corner (x, z)
const MAZE_Y := 16.0
const MAZE_HEDGE := 2.6
const LOOKOUT := Vector3(-67.0, 22.0, 246.0)    # the lookout's platform (middle, top)
const LOOKOUT_FOOT := Vector2(-67.0, 259.0)
const POTAGER := Rect2(58.0, 202.0, 66.0, 30.0)
const POTAGER_Y := 15.0
const RILL_Z := 264.0
const RILL_X := Vector2(68.0, 108.0)
const RILL_Y := 18.0
const SURFACES := [["Estate Stone", "stone", 1.0], ["Estate Stone Dark", "stone", 0.8], ["Arcade Tiles", "shingles", 0.6],
	["Rill Stone", "stone", 0.7], ["Quarry Ramp", "stone", 1.2], ["Arbour Wood", "barn_boards", 0.6]]

var maze_walls := []                            # [[a, b]] of hedges (x, z), for tests
var maze_entry := Vector2.ZERO                  # where the way in is
var maze_heart := Vector2.ZERO
var maze_east := []                             # [i][j]: a hedge between cell (i, j) and (i + 1, j)
var maze_north := []                            # [i][j]: a hedge between cell (i, j) and (i, j + 1)
var maze_entry_row := 0
var ramp_pts: Array[Vector3] = []               # the quarry ramp's line (for tests)
var _keep: Array[Vector3] = []
var _jets: Array[Node3D] = []
var _fall: MeshInstance3D


func build(garden: Node3D) -> void:
	start(garden, "Rooms", 7349)
	_maze()
	_lookout()
	_potager()
	_rill_court()
	_quarry()
	finish(SURFACES)


# -----------------------------------------------------------------------------
# The Hedge Maze
# -----------------------------------------------------------------------------
func _maze() -> void:
	var g := group("Hedge Maze")
	var n := MAZE_N
	# Walls between cells: east walls [i][j] (between i and i+1) and north walls [i][j] (between j and j+1)
	var east := []
	var north := []
	for i in n:
		east.append([])
		north.append([])
		for j in n:
			east[i].append(true)
			north[i].append(true)
	var heart := [n / 2 - 1, n / 2]                 # the 2 x 2 court at the middle
	var visited := {}
	for i in heart:
		for j in heart:
			visited[Vector2i(i, j)] = true
	east[heart[0]][heart[0]] = false
	east[heart[0]][heart[1]] = false
	north[heart[0]][heart[0]] = false
	north[heart[1]][heart[0]] = false
	# Carve the rest from the cell north of the court (a recursive backtracker, from the court's own seed)
	var start_cell := Vector2i(heart[0], heart[1] + 1)
	north[heart[0]][heart[1]] = false
	var stack: Array[Vector2i] = [start_cell]
	visited[start_cell] = true
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x >= 0 and nb.x < n and nb.y >= 0 and nb.y < n and not visited.has(nb):
				options.append(nb)
		if options.is_empty():
			stack.pop_back()
			continue
		var nb := options[_rng.randi() % options.size()]
		if nb.x > c.x:
			east[c.x][c.y] = false
		elif nb.x < c.x:
			east[nb.x][nb.y] = false
		elif nb.y > c.y:
			north[c.x][c.y] = false
		else:
			north[nb.x][nb.y] = false
		visited[nb] = true
		stack.append(nb)
	# The way in: on the east side, the row nearest the path from the Formal Garden (z 262)
	var entry_row := clampi(roundi((262.0 - MAZE_ORIGIN.y) / MAZE_CELL - 0.5), 0, n - 1)
	maze_east = east
	maze_north = north
	maze_entry_row = entry_row
	maze_entry = Vector2(MAZE_ORIGIN.x + n * MAZE_CELL, MAZE_ORIGIN.y + (entry_row + 0.5) * MAZE_CELL)
	maze_heart = MAZE_ORIGIN + Vector2(n / 2, n / 2) * MAZE_CELL
	# The hedges: runs of wall joined up into long lengths
	var y := MAZE_Y
	var segs := []
	for j in n:                                     # walls along x: the south edge, then each north wall
		var runs := []
		for i in n:
			runs.append(j == 0)
		_runs(segs, runs, func(i0: int, i1: int) -> Array:
			return [MAZE_ORIGIN + Vector2(i0 * MAZE_CELL, 0), MAZE_ORIGIN + Vector2((i1 + 1) * MAZE_CELL, 0)])
		var walls := []
		for i in n:
			walls.append(north[i][j])
		var zz := MAZE_ORIGIN.y + (j + 1) * MAZE_CELL
		_runs(segs, walls, func(i0: int, i1: int) -> Array:
			return [Vector2(MAZE_ORIGIN.x + i0 * MAZE_CELL, zz), Vector2(MAZE_ORIGIN.x + (i1 + 1) * MAZE_CELL, zz)])
	for i in n:                                     # walls along z: the west edge, then each east wall
		var west := []
		for j in n:
			west.append(i == 0)
		_runs(segs, west, func(j0: int, j1: int) -> Array:
			return [MAZE_ORIGIN + Vector2(0, j0 * MAZE_CELL), MAZE_ORIGIN + Vector2(0, (j1 + 1) * MAZE_CELL)])
		var walls := []
		for j in n:
			walls.append(east[i][j] and not (i == n - 1 and j == entry_row))
		var xx := MAZE_ORIGIN.x + (i + 1) * MAZE_CELL
		_runs(segs, walls, func(j0: int, j1: int) -> Array:
			return [Vector2(xx, MAZE_ORIGIN.y + j0 * MAZE_CELL), Vector2(xx, MAZE_ORIGIN.y + (j1 + 1) * MAZE_CELL)])
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		hedge(g, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), MAZE_HEDGE, 0.9, true)
		maze_walls.append([a, b])
	# Gravel underfoot all through it
	block(g, "Maze Gravel", Vector3(n * MAZE_CELL, 0.04, n * MAZE_CELL),
		Vector3(MAZE_ORIGIN.x + n * MAZE_CELL / 2.0, y + 0.02, MAZE_ORIGIN.y + n * MAZE_CELL / 2.0),
		sg._mat("Maze Gravel", Color(0.78, 0.72, 0.62), 0.95), false)
	# The heart: a sundial on a round step, four urns, the maze seed
	var h := Vector3(maze_heart.x, y, maze_heart.y)
	var dial := baked("res://models/props/secret_garden/sundial.glb")
	if dial:
		sg._mesh(g, dial, h, null).name = "Maze Sundial"
	else:
		sg._cyl(g, "Sundial Pillar", 0.25, 0.32, 1.0, h + Vector3(0, 0.5, 0), stone(), false)
		sg._cyl(g, "Sundial Face", 0.5, 0.5, 0.08, h + Vector3(0, 1.04, 0), stone_dark(), false)
	var cs := CylinderShape3D.new()
	cs.radius = 0.5
	cs.height = 1.2
	sg._solid(g, "Sundial Body", cs, h + Vector3(0, 0.6, 0))
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		urn(g, h + Vector3(cos(a) * 3.6, 0, sin(a) * 3.6), 0.8)
	sg.put_seed("maze", h + Vector3(1.6, 0, -1.6))
	# Gate piers at the way in
	for side: float in [-1.0, 1.0]:
		var p := Vector3(maze_entry.x + 0.2, y, maze_entry.y + side * (MAZE_CELL / 2.0 + 0.3))
		block(g, "Maze Gate Pier", Vector3(0.9, 3.0, 0.9), p + Vector3(0, 1.5, 0), stone(), true)
		urn(g, p + Vector3(0, 3.0, 0), 0.9)
	_keep.append(Vector3(maze_heart.x, maze_heart.y, n * MAZE_CELL * 0.75))


func _runs(out: Array, flags: Array, make: Callable) -> void:
	# Joins neighbouring trues in flags into one run each, made into a segment by make(first, last)
	var i := 0
	while i < flags.size():
		if flags[i]:
			var j := i
			while j + 1 < flags.size() and flags[j + 1]:
				j += 1
			out.append(make.call(i, j))
			i = j + 1
		else:
			i += 1


func _lookout() -> void:
	# A stone lookout beside the maze: a stair up to a balustraded platform on four piers, 6 m up
	var g := group("Maze Lookout")
	var top := LOOKOUT
	var foot := Vector3(LOOKOUT_FOOT.x, ground(LOOKOUT_FOOT.x, LOOKOUT_FOOT.y), LOOKOUT_FOOT.y)
	var half := 2.6
	var edge := Vector3(top.x, top.y, top.z + half)
	stair(g, "Lookout Stair", foot, edge, 2.4, true, false)
	block(g, "Lookout Floor", Vector3(half * 2.0, 0.4, half * 2.0), top - Vector3(0, 0.2, 0), paving(), true)
	block(g, "Lookout Cornice", Vector3(half * 2.0 + 0.4, 0.22, half * 2.0 + 0.4), top - Vector3(0, 0.45, 0), stone_dark(), false)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p := Vector3(top.x + c.x * (half - 0.4), 0, top.z + c.y * (half - 0.4))
		var gy := ground(p.x, p.z) - 0.4
		block(g, "Lookout Pier", Vector3(0.8, top.y - gy, 0.8), Vector3(p.x, (top.y + gy) / 2.0 - 0.3, p.z), stone(), true)
	var corners := [Vector3(top.x - half, top.y, top.z - half), Vector3(top.x + half, top.y, top.z - half),
		Vector3(top.x + half, top.y, top.z + half), Vector3(top.x - half, top.y, top.z + half)]
	balustrade(g, corners[0], corners[1], true, true)
	balustrade(g, corners[1], corners[2], true, false)
	balustrade(g, corners[3], corners[0], true, false)
	# the stair's side of the platform has its balustrade only beside the stair
	balustrade(g, corners[2], Vector3(top.x + 1.6, top.y, top.z + half), true, false)
	balustrade(g, Vector3(top.x - 1.6, top.y, top.z + half), corners[3], true, false)
	_keep.append(Vector3(top.x, (top.z + LOOKOUT_FOOT.y) / 2.0, 9.0))


# -----------------------------------------------------------------------------
# The Potager
# -----------------------------------------------------------------------------
func _potager() -> void:
	var g := group("Potager")
	var y := POTAGER_Y
	var cols := 3
	var rows := 2
	var gap := 3.2
	var bw := (POTAGER.size.x - gap * (cols + 1)) / cols
	var bd := (POTAGER.size.y - gap * (rows + 1)) / rows
	var crops := [["Cabbage", Color(0.42, 0.6, 0.55), 0.42], ["Red Cabbage", Color(0.5, 0.28, 0.5), 0.42],
		["Lettuce", Color(0.55, 0.78, 0.32), 0.3], ["Red Lettuce", Color(0.62, 0.26, 0.24), 0.3],
		["Carrot Tops", Color(0.32, 0.6, 0.22), 0.22], ["Marigolds", Color(1.0, 0.62, 0.12), 0.2],
		["Lavender", Color(0.6, 0.5, 0.88), 0.25]]
	var crop_xf := []
	for c in crops:
		crop_xf.append([])
	var box_h := 0.55
	for bi in cols:
		for bj in rows:
			var x0 := POTAGER.position.x + gap + bi * (bw + gap)
			var z0 := POTAGER.position.y + gap + bj * (bd + gap)
			var c := Vector2(x0 + bw / 2.0, z0 + bd / 2.0)
			# the bed's edge: low clipped box all round
			var pts := [Vector2(x0, z0), Vector2(x0 + bw, z0), Vector2(x0 + bw, z0 + bd), Vector2(x0, z0 + bd)]
			for k in 4:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[(k + 1) % 4]
				hedge(g, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), box_h, 0.45, true)
			# a pattern inside: a cross, or a diamond, by the bed
			if (bi + bj) % 2 == 0:
				hedge(g, Vector3(c.x - bw / 2.0, y, c.y), Vector3(c.x + bw / 2.0, y, c.y), box_h, 0.4, false)
				hedge(g, Vector3(c.x, y, c.y - bd / 2.0), Vector3(c.x, y, c.y + bd / 2.0), box_h, 0.4, false)
			else:
				var dm := [Vector2(c.x - bw / 2.0, c.y), Vector2(c.x, c.y - bd / 2.0), Vector2(c.x + bw / 2.0, c.y), Vector2(c.x, c.y + bd / 2.0)]
				for k in 4:
					var a: Vector2 = dm[k]
					var b: Vector2 = dm[(k + 1) % 4]
					hedge(g, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), box_h, 0.4, false)
			# crops in rows of colour
			var rows_in := int(bd / 0.9)
			for r in rows_in:
				var kind := (r + bi * 2 + bj) % crops.size()
				var zr := z0 + 0.6 + r * (bd - 1.2) / maxf(rows_in - 1, 1)
				var per := int(bw / 0.75)
				for k in per:
					var xr := x0 + 0.5 + k * (bw - 1.0) / maxf(per - 1, 1)
					var s: float = crops[kind][2]
					crop_xf[kind].append(Transform3D(Basis.from_scale(Vector3(s, s * 0.75, s)), Vector3(xr, y + s * 0.5, zr)))
			# standard roses at the corners
			for p in pts:
				var at := Vector3(p.x, y, p.y)
				sg._cyl(g, "Standard Rose Stem", 0.04, 0.05, 1.3, at + Vector3(0, 0.65, 0), sg._mat("Rose Stem", Color(0.3, 0.25, 0.2), 0.9), false)
				sg._ball(g, 0.45, at + Vector3(0, 1.55, 0), sg._mat("Rose Leaf", Color(0.2, 0.42, 0.22), 0.8))
				for r in 4:
					var a := TAU * r / 4.0
					sg._ball(g, 0.13, at + Vector3(cos(a) * 0.36, 1.6 + 0.1 * (r % 2), sin(a) * 0.36),
						glow(sg._mat("Rose 1", Color(1.0, 0.65, 0.78), 0.5, 0.3)))
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	for i in crops.size():
		var m: StandardMaterial3D = sg._mat("Crop " + crops[i][0], crops[i][1], 0.8)
		if crops[i][0] in ["Marigolds", "Lavender"]:
			glow(m)
		sg._multi(g, "Crops " + crops[i][0], ball, crop_xf[i], m)
	# The vine arbour along the top: posts, beams and leaves with grapes
	var wood: StandardMaterial3D = sg._mat("Arbour Wood", Color(0.5, 0.4, 0.3), 0.8)
	var z := POTAGER.end.y + 1.2
	var x0 := POTAGER.position.x + 4.0
	var x1 := POTAGER.end.x - 4.0
	var n := int((x1 - x0) / 3.0)
	for i in n + 1:
		var x := x0 + (x1 - x0) * i / n
		for side: float in [-1.0, 1.0]:
			block(g, "Arbour Post", Vector3(0.22, 2.6, 0.22), Vector3(x, y + 1.3, z + side * 1.4), wood, true)
		block(g, "Arbour Beam", Vector3(0.18, 0.18, 3.6), Vector3(x, y + 2.7, z), wood, false)
		sg._ball(g, 1.0, Vector3(x, y + 2.95, z), sg._leaf(), 0.45).scale = Vector3(1.6, 1, 2.0)
		sg._ball(g, 0.16, Vector3(x + 0.6, y + 2.45, z + 0.5), sg._mat("Grapes", Color(0.42, 0.24, 0.55), 0.5), 1.5)
	for side: float in [-1.0, 1.0]:
		block(g, "Arbour Rail", Vector3(x1 - x0 + 0.4, 0.16, 0.16), Vector3((x0 + x1) / 2.0, y + 2.6, z + side * 1.4), wood, false)
	_keep.append(Vector3(POTAGER.get_center().x, POTAGER.get_center().y, 40.0))


# -----------------------------------------------------------------------------
# The Rill Court
# -----------------------------------------------------------------------------
func _rill_court() -> void:
	var g := group("Rill Court")
	var y := RILL_Y
	var rs: StandardMaterial3D = sg._mat("Rill Stone", Color(0.74, 0.66, 0.58), 0.8)
	var length := RILL_X.y - RILL_X.x
	var mid := (RILL_X.x + RILL_X.y) / 2.0
	# The rill: a narrow channel of water between stone kerbs, a little pool at each end
	block(g, "Rill Kerb", Vector3(length, 0.12, 0.3), Vector3(mid, y + 0.06, RILL_Z - 0.55), rs, false)
	block(g, "Rill Kerb", Vector3(length, 0.12, 0.3), Vector3(mid, y + 0.06, RILL_Z + 0.55), rs, false)
	block(g, "Rill Water", Vector3(length, 0.04, 0.8), Vector3(mid, y + 0.05, RILL_Z), water_mat(), false)
	for x in [RILL_X.x, RILL_X.y]:
		ring_wall(g, "Rill Pool Rim", Vector3(x, y, RILL_Z), 1.6, 0.35, 0.3, rs, 16, false)
		disc(g, "Rill Pool Water", Vector3(x, y + 0.3, RILL_Z), 1.45, water_mat())
		_jet_up(g, Vector3(x, y + 0.3, RILL_Z), 1.6)
	# Jets arching over it from both sides
	var spray: StandardMaterial3D = spray_mat()
	var n := 14
	for i in n:
		var x := RILL_X.x + 3.0 + (length - 6.0) * i / (n - 1)
		for side: float in [-1.0, 1.0]:
			var jet := Node3D.new()
			jet.name = "Rill Jet"
			jet.position = Vector3(x, y + 0.1, RILL_Z + side * 0.75)
			jet.set_meta("dir", Vector3(0, 0, -side))
			g.add_child(jet)
			for k in 7:
				var d: MeshInstance3D = sg._ball(jet, 0.05, Vector3.ZERO, spray)
				d.name = "Drop"
			_jets.append(jet)
	# Beds of flowers along both sides and orange trees in two rows
	for side: float in [-1.0, 1.0]:
		var zb := RILL_Z + side * 4.5
		block(g, "Rill Bed Edge", Vector3(length, 0.18, 3.2), Vector3(mid, y + 0.09, zb), rs, false)
		var fl: StandardMaterial3D = glow(sg._mat("Rill Flowers %d" % int(side), Color(1.0, 0.4, 0.5) if side > 0 else Color(0.95, 0.85, 0.3), 0.6, 0.3))
		var xfs := []
		for k in 60:
			xfs.append(Transform3D(Basis.from_scale(Vector3.ONE * 0.22), Vector3(RILL_X.x + length * (k + 0.5) / 60.0, y + 0.3, zb + _rng.randf_range(-1.2, 1.2))))
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		ball.radial_segments = 8
		ball.rings = 4
		sg._multi(g, "Rill Flowers", ball, xfs, fl)
		for k in 7:
			_orange_tree(g, Vector3(RILL_X.x + 2.0 + (length - 4.0) * k / 6.0, y, RILL_Z + side * 9.0))
	# An arcade of arches at the east end, roofed in tiles
	var ax := RILL_X.y + 5.0
	var tiles: StandardMaterial3D = sg._mat("Arcade Tiles", Color(0.7, 0.38, 0.26), 0.8)
	var arches := 5
	var span := 3.2
	for i in arches + 1:
		var z := RILL_Z - span * arches / 2.0 + span * i
		sg._cyl(g, "Arcade Column", 0.2, 0.22, 3.2, Vector3(ax, y + 1.6, z), stone(), true)
		block(g, "Arcade Capital", Vector3(0.55, 0.25, 0.55), Vector3(ax, y + 3.3, z), stone_dark(), false)
		if i < arches:
			var tm := TorusMesh.new()
			tm.inner_radius = span / 2.0 - 0.18
			tm.outer_radius = span / 2.0 + 0.12
			tm.rings = 20
			var arch := sg._mesh(g, tm, Vector3(ax, y + 3.4, z + span / 2.0), stone()) as MeshInstance3D
			arch.rotation.z = PI / 2.0
			arch.scale = Vector3(1, 0.6, 1)
			arch.name = "Arcade Arch"
	block(g, "Arcade Wall", Vector3(0.6, 1.4, span * arches + 0.8), Vector3(ax, y + 4.5, RILL_Z), stone(), false)
	block(g, "Arcade Back", Vector3(0.4, 5.2, span * arches + 0.8), Vector3(ax + 3.0, y + 2.6, RILL_Z), stone(), true)
	var roof := BoxMesh.new()
	roof.size = Vector3(4.2, 0.2, span * arches + 1.4)
	var r := sg._mesh(g, roof, Vector3(ax + 1.5, y + 5.6, RILL_Z), tiles) as MeshInstance3D
	r.rotation.z = 0.22
	r.name = "Arcade Roof"
	block(g, "Arcade Floor", Vector3(3.4, 0.05, span * arches + 0.6), Vector3(ax + 1.5, y + 0.03, RILL_Z), paving(), false)
	_keep.append(Vector3(mid, RILL_Z, 26.0))
	_keep.append(Vector3(ax + 1.5, RILL_Z, 10.0))


func _orange_tree(parent: Node3D, at: Vector3) -> void:
	var top := trunk(at, 0.16, 1.8, "grey")
	leaves(top + Vector3(0, 0.9, 0), 1.3, "oak", 0.9)
	var fruit: StandardMaterial3D = glow(sg._mat("Oranges", Color(1.0, 0.55, 0.1), 0.5, 0.25))
	for k in 7:
		var a := TAU * k / 7.0
		sg._ball(parent, 0.11, top + Vector3(cos(a) * 1.05, 0.7 + 0.4 * sin(a * 3.0), sin(a) * 1.05), fruit)
	sg._cyl(parent, "Orange Tree Pot", 0.45, 0.35, 0.6, at + Vector3(0, 0.3, 0), sg._mat("Terracotta", Color(0.72, 0.4, 0.26), 0.8), false)


func _jet_up(parent: Node3D, at: Vector3, high: float) -> void:
	var jet := Node3D.new()
	jet.name = "Pool Jet"
	jet.position = at
	jet.set_meta("dir", Vector3.ZERO)
	jet.set_meta("high", high)
	parent.add_child(jet)
	for k in 8:
		sg._ball(jet, 0.07, Vector3.ZERO, spray_mat()).name = "Drop"
	_jets.append(jet)


# -----------------------------------------------------------------------------
# The Sunken Quarry Garden
# -----------------------------------------------------------------------------
static func _cliff_r(t: float) -> float:
	# How far out from the quarry's middle its cliff is t of the way up (the inverse of the land's smoothstep)
	var lo := 0.0
	var hi := 1.0
	for i in 24:
		var m := (lo + hi) / 2.0
		if m * m * (3.0 - 2.0 * m) < t:
			lo = m
		else:
			hi = m
	return LAND.QUARRY.z + LAND.QUARRY_WALL * (lo + hi) / 2.0


func _quarry() -> void:
	var g := group("Sunken Garden")
	var c := Vector2(LAND.QUARRY.x, LAND.QUARRY.y)
	var floor_y := LAND.QUARRY_FLOOR
	# The ramp: carved into the cliff, from the south-east rim round the south side down to the floor
	var a_top := atan2(-0.8, 0.6)
	var sweep := -PI * 0.95
	var rim_y := ground(c.x + cos(a_top) * 23.0, c.y + sin(a_top) * 23.0)
	var n := 28
	ramp_pts.clear()
	for i in n + 1:
		var t := float(i) / n
		var a := a_top + sweep * t
		var y := lerpf(rim_y, floor_y, t)
		var lift := clampf((y - floor_y) / (rim_y - floor_y), 0.0, 1.0)
		var r := _cliff_r(lift) - 1.6
		if i == 0:
			r = 23.0
		ramp_pts.append(Vector3(c.x + cos(a) * r, y, c.y + sin(a) * r))
	var rm: StandardMaterial3D = sg._mat("Quarry Ramp", Color(0.72, 0.68, 0.62), 0.9)
	for i in n:
		var p0 := ramp_pts[i]
		var p1 := ramp_pts[i + 1]
		slab(g, "Quarry Ramp", p0, p1, Vector2(4.0, 2.8), rm, true, 0.0)
		# a low parapet on its open side
		var mid := (p0 + p1) / 2.0
		var inward := Vector3(c.x - mid.x, 0, c.y - mid.z).normalized() * 1.25
		slab(g, "Ramp Parapet", p0 + inward + Vector3(0, 0.55, 0), p1 + inward + Vector3(0, 0.55, 0), Vector2(0.55, 0.3),
			stone_dark(), true, 0.0)
	# Ivy and ferns spilling down the cliffs
	var ivy: StandardMaterial3D = sg._mat("Quarry Ivy", Color(0.15, 0.32, 0.17), 0.9)
	for i in 110:
		var a := TAU * i / 110.0 + _rng.randf() * 0.04
		if absf(wrapf(a - (a_top + sweep * 0.5), -PI, PI)) < 1.7:
			continue
		var t := _rng.randf_range(0.35, 0.85)
		var r := _cliff_r(t)
		var p := Vector3(c.x + cos(a) * r, floor_y + (12.0 - floor_y) * t, c.y + sin(a) * r)
		var mi: MeshInstance3D = sg._ball(g, _rng.randf_range(0.6, 1.1), p, ivy, 0.7)
		mi.scale = Vector3(1.0, 1.0, 1.0) * _rng.randf_range(0.8, 1.3)
		mi.name = "Cliff Ivy"
	# The floor: curving beds of flowers in bands of colour, a lawn path round, trees
	var cols := [Color(0.95, 0.25, 0.4), Color(1.0, 0.75, 0.2), Color(0.7, 0.45, 0.95), Color(1.0, 0.55, 0.75),
		Color(0.98, 0.95, 0.85), Color(1.0, 0.45, 0.15)]
	var xfs := []
	for k in cols.size():
		xfs.append([])
	for i in 1500:
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * (LAND.QUARRY.z - 2.5)
		var p := c + Vector2(cos(a), sin(a)) * r
		if p.distance_to(c + Vector2(0, 8.0)) < 5.6 or absf(r - 7.0) < 1.1 or p.distance_to(c) < 2.5:
			continue
		var band := int(floor((a + r * 0.25) / TAU * cols.size() * 2.0))
		var s := _rng.randf_range(0.09, 0.16)
		xfs[posmod(band, cols.size())].append(Transform3D(Basis.from_scale(Vector3(s, s * 0.8, s)), Vector3(p.x, floor_y + s * 0.6, p.y)))
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	for k in cols.size():
		sg._multi(g, "Sunken Flowers", ball, xfs[k], glow(sg._mat("Sunken Flowers %d" % k, cols[k], 0.6, 0.3)))
	for p in [Vector2(-9.0, -6.0), Vector2(9.5, -4.0), Vector2(-4.0, -11.0), Vector2(11.0, 6.0)]:
		tree("blossom" if p.x < 0 else "maple_red", Vector3(c.x + p.x, floor_y, c.y + p.y), 0.85)
	# The pool on the north side, with a fountain, and the waterfall pouring down the cliff into it
	var pool := Vector3(c.x, floor_y, c.y + 8.0)
	ring_wall(g, "Sunken Pool Rim", pool, 4.6, 0.45, 0.4, stone(), 20, true)
	disc(g, "Sunken Pool Water", pool + Vector3(0, 0.38, 0), 4.45, water_mat())
	sg._cyl(g, "Fountain Column", 0.25, 0.35, 1.4, pool + Vector3(0, 0.7, 0), stone(), true)
	sg._cyl(g, "Fountain Bowl", 0.9, 0.3, 0.3, pool + Vector3(0, 1.45, 0), stone(), false)
	_jet_up(g, pool + Vector3(0, 1.6, 0), 1.8)
	var cliff_top := ground(c.x, c.y + LAND.QUARRY.z + LAND.QUARRY_WALL + 1.0)
	var fall_h := cliff_top - floor_y
	var qm := BoxMesh.new()
	qm.size = Vector3(2.6, fall_h / cos(0.53), 0.1)
	var r_mid := _cliff_r(0.5)
	_fall = sg._mesh(g, qm, Vector3(c.x, floor_y + fall_h / 2.0, c.y + r_mid - 0.6), sg._mat("Falling Water", Color(0.82, 0.93, 0.98, 0.72), 0.1, 0.25), false) as MeshInstance3D
	_fall.rotation.x = 0.53
	_fall.name = "Quarry Falls"
	block(g, "Falls Lip", Vector3(3.4, 0.4, 1.2), Vector3(c.x, cliff_top + 0.1, c.y + LAND.QUARRY.z + LAND.QUARRY_WALL), stone_dark(), false)
	# A balustrade round the rim's lookout by the ramp's top
	var la := a_top + 0.35
	var lb := a_top + 0.9
	var p_a := Vector3(c.x + cos(la) * 22.6, 0, c.y + sin(la) * 22.6)
	var p_b := Vector3(c.x + cos(lb) * 22.6, 0, c.y + sin(lb) * 22.6)
	p_a.y = ground(p_a.x, p_a.z)
	p_b.y = ground(p_b.x, p_b.z)
	balustrade(g, p_a, p_b, true, true)
	_keep.append(Vector3(c.x, c.y, LAND.QUARRY.z + LAND.QUARRY_WALL + 1.0))


func blocks(at: Vector3) -> bool:
	for k in _keep:
		if Vector2(at.x, at.z).distance_to(Vector2(k.x, k.y)) < k.z:
			return true
	if at.x > -116.0 and at.x < -76.0 and at.z > 240.0 and at.z < 280.0:
		return true
	return false


func wake(_k: float) -> void:
	pass


func step(_delta: float) -> void:
	for jet in _jets:
		var dir: Vector3 = jet.get_meta("dir")
		var n := jet.get_child_count()
		for k in n:
			var s := fposmod(_t * 0.8 + float(k) / n, 1.0)
			var drop := jet.get_child(k) as Node3D
			if dir == Vector3.ZERO:
				var high: float = jet.get_meta("high")
				drop.position = Vector3(sin(k * 2.1) * 0.3 * s, high * 4.0 * s * (1.0 - s), cos(k * 2.1) * 0.3 * s)
			else:
				drop.position = dir * 1.5 * s + Vector3(0, 0.9 * 4.0 * s * (1.0 - s), 0)
	if _fall:
		_fall.scale.x = 1.0 + sin(_t * 8.0) * 0.04
