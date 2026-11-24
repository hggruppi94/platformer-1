# The X-shaped crack across a Sinker Stone in the Poison Mire, made to look like a little copy of the cracks you jump into to
# go between worlds (scripts/crack.gd): a jagged split right across the stone and on down over its rounded edge to the
# goo, its two broken lips standing a touch proud with chips of rock along them, its walls going from the stone's own
# colour to black, a thin glow of the poison deep down in the middle, and hairline cracks running off it. Hayden, 24 Nov
# 2026: "Those cracked stepping stones dont look cracked lol can you make them look more like the holes in the ground
# that you teleport to worlds?" (The old cracks were three glowing sticks laid on top.) Then: "make the split x-shaped
# and have it crumble apart instead of sink", so it's two splits crossing, and the stone breaks along them
# (scripts/swamp.gd _crumble()).
#
# It's drawn over whatever the stone looks like (the plain stone, or the baked one once scripts/detail_props.gd has
# dressed it): the stone's meshes are laid onto a little height map first, and everything follows that. It's all a
# child of the stone's body, so it sinks with it. No class_name on purpose (see scripts/use_spot.gd): preload it.

const NAME := "Stone Crack"
const CELL := 0.04                   # the height map's squares
const SPAN := 1.2                    # the height map reaches this far round the stone's middle
const STEP := 0.035                  # along the split
const WIDTH := 0.17                  # half the split's width at its widest
const LIP := 0.035                   # how far the broken lips stand up off the stone
const DEEP := Color(0.01, 0.008, 0.012)

static var _grids := {}              # mesh ids -> height map, so every baked stone (one shared mesh) maps it once


static func build(body: Node3D, rock: Color, glow: Color, seed: int, above_y: float) -> Node3D:
	# An X of two cracks across `body`'s stone, in `rock`'s colour with `glow` deep down, running over its edge until
	# the stone drops under `above_y` (the goo's top, in the body's space). Any crack it had before is replaced. Meta
	# "dirs" on it: the four ways the X's arms point (angles round Y in the body's space), which the stone crumbles along.
	var old := body.get_node_or_null(NAME)
	if old:
		body.remove_child(old)
		old.free()
	var grid := _grid_of(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var g := Node3D.new()
	g.name = NAME
	g.rotation.y = rng.randf() * TAU
	body.add_child(g)
	var cross := rng.randf_range(1.25, 1.9)              # (the second arm crosses the first a bit off square)
	var dirs: Array = []
	var length := 0.0
	for arm in 2:
		var turn_y := 0.0 if arm == 0 else cross
		var a := Node3D.new()
		a.name = "Arm %d" % (arm + 1)
		a.rotation.y = turn_y
		g.add_child(a)
		var turn := Basis(Vector3.UP, g.rotation.y + turn_y)
		var h := func(x: float, z: float) -> float:
			var p := turn * Vector3(x, 0, z)              # (the arm's own frame to the body's)
			return _height(grid, p.x, p.z)
		# where the other arm runs, in this arm's frame: the lips flatten out where they meet, so the X is open
		var d := cross if arm == 0 else -cross
		var other := Vector2(cos(d), -sin(d))
		var line := _outline(h, rng, above_y, 1.0 if arm == 0 else 0.85)
		dirs.append(g.rotation.y + turn_y)
		dirs.append(g.rotation.y + turn_y + PI)
		if (line.x as PackedFloat32Array).size() < 4:
			continue
		line["other"] = other
		_split(a, line, h, rock, glow)
		_chips(a, line, h, rock, rng)
		_fissures(a, line, h, rock, rng)
		if arm == 0:
			length = float(line.x[line.x.size() - 1]) - float(line.x[0])
	g.set_meta("length", length)
	g.set_meta("dirs", dirs)
	return g


static func meet_fade(line: Dictionary, x: float, z: float) -> float:
	# 0 right where the other arm of the X runs, 1 clear of it
	if not line.has("other"):
		return 1.0
	var o: Vector2 = line.other
	return clampf((absf(x * o.y - z * o.x) - 0.17) / 0.12, 0.0, 1.0)


# ---------------------------------------------------------------- the stone's shape
static func _grid_of(body: Node3D) -> Dictionary:
	# Every visible, upward-facing triangle of the stone's meshes laid onto a grid of heights (the highest one in each)
	var meshes: Array = []
	var key := ""
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible or m.layers == 0 or _under_crack(m, body):
			continue
		var t := Transform3D.IDENTITY
		var n: Node = m
		while n != body and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		meshes.append([m.mesh, t])
		key += "%d/%s;" % [m.mesh.get_instance_id(), str(t)]
	if _grids.has(key):
		return _grids[key]
	var nx := int(ceil(SPAN * 2.0 / CELL)) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nx)
	hs.fill(-INF)
	for pair in meshes:
		var mesh: Mesh = pair[0]
		var t: Transform3D = pair[1]
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count := idx.size() if idx.size() > 0 else verts.size()
			for i in range(0, count - 2, 3):
				var a := t * verts[idx[i] if idx.size() > 0 else i]
				var b := t * verts[idx[i + 1] if idx.size() > 0 else i + 1]
				var c := t * verts[idx[i + 2] if idx.size() > 0 else i + 2]
				var nrm := (b - a).cross(c - a)
				if absf(nrm.normalized().y) < 0.08:          # (upright faces: nothing to stand a crack on)
					continue
				_raster(hs, nx, a, b, c)
	if hs.count(-INF) == hs.size():
		_fallback(hs, nx)                             # (headless runs keep no mesh data: use the stone's usual shape)
	var grid := {"nx": nx, "h": hs}
	_grids[key] = grid
	return grid


static func _fallback(hs: PackedFloat32Array, nx: int) -> void:
	# A stepping stone's shape (build_prop_swamp.py STONE_PROF): flat on top, rounding off to the goo
	var prof := [Vector2(0.0, 0.36), Vector2(0.4, 0.355), Vector2(0.65, 0.33), Vector2(0.8, 0.25), Vector2(0.9, 0.0),
		Vector2(0.95, -0.35)]
	for j in nx:
		for i in nx:
			var r := Vector2(-SPAN + i * CELL, -SPAN + j * CELL).length()
			for k in prof.size() - 1:
				var a: Vector2 = prof[k]
				var b: Vector2 = prof[k + 1]
				if r >= a.x and r <= b.x:
					hs[j * nx + i] = lerpf(a.y, b.y, (r - a.x) / (b.x - a.x))
					break


static func _under_crack(n: Node, body: Node) -> bool:
	while n and n != body:
		if n.name == NAME:
			return true
		n = n.get_parent()
	return false


static func _raster(hs: PackedFloat32Array, nx: int, a: Vector3, b: Vector3, c: Vector3) -> void:
	var lo_x := int(floor((minf(a.x, minf(b.x, c.x)) + SPAN) / CELL))
	var hi_x := int(ceil((maxf(a.x, maxf(b.x, c.x)) + SPAN) / CELL))
	var lo_z := int(floor((minf(a.z, minf(b.z, c.z)) + SPAN) / CELL))
	var hi_z := int(ceil((maxf(a.z, maxf(b.z, c.z)) + SPAN) / CELL))
	var d := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if absf(d) < 1e-9:
		return
	for j in range(maxi(lo_z, 0), mini(hi_z, nx - 1) + 1):
		for i in range(maxi(lo_x, 0), mini(hi_x, nx - 1) + 1):
			var px := -SPAN + i * CELL
			var pz := -SPAN + j * CELL
			var u := ((px - a.x) * (c.z - a.z) - (c.x - a.x) * (pz - a.z)) / d
			var v := ((b.x - a.x) * (pz - a.z) - (px - a.x) * (b.z - a.z)) / d
			if u < -0.02 or v < -0.02 or u + v > 1.02:
				continue
			var y := a.y + u * (b.y - a.y) + v * (c.y - a.y)
			if y > hs[j * nx + i]:
				hs[j * nx + i] = y


static func _height(grid: Dictionary, x: float, z: float) -> float:
	# The stone's top at (x, z) in the body's space (-INF off it): the highest of the four squares round the spot, so
	# nothing drawn on it sinks into a facet
	var nx: int = grid.nx
	var hs: PackedFloat32Array = grid.h
	var fx := (x + SPAN) / CELL
	var fz := (z + SPAN) / CELL
	var i := int(floor(fx))
	var j := int(floor(fz))
	if i < 0 or j < 0 or i >= nx - 1 or j >= nx - 1:
		return -INF
	var a := hs[j * nx + i]
	var b := hs[j * nx + i + 1]
	var c := hs[(j + 1) * nx + i]
	var e := hs[(j + 1) * nx + i + 1]
	if a == -INF or b == -INF or c == -INF or e == -INF:
		return maxf(maxf(a, b), maxf(c, e))
	var u := fx - i
	var v := fz - j
	return maxf(lerpf(lerpf(a, b, u), lerpf(c, e, u), v), maxf(maxf(a, b), maxf(c, e)) - 0.01)


# ---------------------------------------------------------------- the split
static func _outline(h: Callable, rng: RandomNumberGenerator, above_y: float, wide := 1.0) -> Dictionary:
	# Like crack.gd's, smaller: a wandering middle line with ragged edges and the odd bite, widest in the middle and
	# coming to hairline points, running out each way until the stone goes under the goo
	var ends := [0.0, 0.0]
	for k in 2:
		var sgn := -1.0 if k == 0 else 1.0
		var x := 0.0
		while x < SPAN - 0.05 and float(h.call(sgn * (x + STEP), 0.0)) > above_y + 0.03:
			x += STEP
		ends[k] = sgn * x
	var x0: float = ends[0]
	var x1: float = ends[1]
	var half := (x1 - x0) * 0.5
	var mid_x := (x0 + x1) * 0.5
	var ph := rng.randf_range(0.0, TAU)
	var ph2 := rng.randf_range(0.0, TAU)
	var xs := PackedFloat32Array()
	var top := PackedFloat32Array()
	var bot := PackedFloat32Array()
	var mid := PackedFloat32Array()
	var jt := 0.0
	var jb := 0.0
	var n := int(ceil((x1 - x0) / STEP)) + 1
	if n < 4 or half < 0.2:
		return {"x": xs}
	for i in n:
		var x := x0 + i * ((x1 - x0) / (n - 1))
		var t := absf(x - mid_x) / half
		var c := 0.045 * sin(x * 6.0 + ph) + 0.025 * sin(x * 15.0 + ph2) + 0.03 * t * sin(x * 9.0 + ph2)
		var w := wide * WIDTH * pow(maxf(1.0 - t * t, 0.0), 0.6) * (0.85 + 0.15 * sin(x * 11.0 + ph)) + 0.006
		jt = jt * 0.5 + rng.randf_range(-0.012, 0.012)
		jb = jb * 0.5 + rng.randf_range(-0.012, 0.012)
		var bt := rng.randf_range(0.012, 0.03) if rng.randf() < 0.14 else 0.0
		var bb := rng.randf_range(0.012, 0.03) if rng.randf() < 0.14 else 0.0
		var k := minf(w / WIDTH * 1.5, 1.0)
		xs.append(x)
		top.append(c + w + (jt + bt) * k)
		bot.append(c - w - (jb + bb) * k)
		mid.append(c)
	return {"x": xs, "top": top, "bot": bot, "mid": mid, "half": half, "mid_x": mid_x}


static func _split(g: Node3D, line: Dictionary, h: Callable, rock: Color, glow: Color) -> void:
	# Across each step: the outer foot of a lip, its broken top, down its wall into the dark, the bottom of the split
	# (a thin glow where it's widest), and back up the other side. All of it just over the stone, so it never sinks in.
	var xs: PackedFloat32Array = line.x
	var top: PackedFloat32Array = line.top
	var bot: PackedFloat32Array = line.bot
	var mid: PackedFloat32Array = line.mid
	var half: float = line.half
	var mid_x: float = line.mid_x
	var lip_c := rock.lightened(0.04)
	var wall_c := rock.darkened(0.7)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow_st := SurfaceTool.new()
	glow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows: Array = []
	for i in xs.size():
		var x := xs[i]
		var w := (top[i] - bot[i]) * 0.5
		var t := absf(x - mid_x) / half
		var lip := LIP * clampf(w / WIDTH * 1.6, 0.25, 1.0) * meet_fade(line, x, mid[i]) + 0.002
		var out := 0.035 * clampf(w / WIDTH * 2.0, 0.3, 1.0)
		# z across, height over the stone, colour
		var pts := [
			[top[i] + out, 0.004, rock],
			[top[i] + out * 0.3, lip, lip_c],
			[top[i] - w * 0.12, lip * 0.5, wall_c],
			[top[i] - w * 0.3, lip * 0.2, wall_c.lerp(DEEP, 0.85)],
			[mid[i] + w * 0.5, 0.006, DEEP],
			[mid[i] - w * 0.5, 0.006, DEEP],
			[bot[i] + w * 0.3, lip * 0.2, wall_c.lerp(DEEP, 0.85)],
			[bot[i] + w * 0.12, lip * 0.5, wall_c],
			[bot[i] - out * 0.3, lip, lip_c],
			[bot[i] - out, 0.004, rock],
		]
		var row: Array = []
		for p in pts:
			var z: float = p[0]
			var y := float(h.call(x, z))
			if y == -INF:
				y = float(h.call(x, mid[i]))
			row.append([Vector3(x, y + float(p[1]), z), p[2]])
		rows.append(row)
		# the glow, deep in the middle where the split is widest
		if t < 0.75 and i + 1 < xs.size():
			var gw := w * 0.09 * (1.0 - t / 0.75)
			var x2 := xs[i + 1]
			var a := Vector3(x, float(h.call(x, mid[i])) + 0.009, mid[i] + gw)
			var b := Vector3(x2, float(h.call(x2, mid[i + 1])) + 0.009, mid[i + 1] + gw)
			var c := Vector3(x2, float(h.call(x2, mid[i + 1])) + 0.009, mid[i + 1] - gw)
			var d := Vector3(x, float(h.call(x, mid[i])) + 0.009, mid[i] - gw)
			for q in [a, c, b, a, d, c]:
				glow_st.set_normal(Vector3.UP)
				glow_st.add_vertex(q)
	for i in rows.size() - 1:
		for k in (rows[i] as Array).size() - 1:
			var a: Array = rows[i][k]
			var b: Array = rows[i + 1][k]
			var c: Array = rows[i + 1][k + 1]
			var d: Array = rows[i][k + 1]
			for tri in [[a, b, c], [a, c, d]]:
				var v: Array = tri
				var p0: Vector3 = v[0][0]
				if ((v[2][0] as Vector3) - p0).cross((v[1][0] as Vector3) - p0).y < 0.0:
					v = [v[0], v[2], v[1]]
				for q in v:
					st.set_color(q[1])
					st.add_vertex(q[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Split"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.resource_name = "Sinker Split"
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)
	var gm := StandardMaterial3D.new()
	gm.resource_name = "Sinker Crack"            # (the name the tests and the old look knew it by)
	gm.albedo_color = glow
	gm.emission_enabled = true
	gm.emission = glow
	gm.emission_energy_multiplier = 0.9
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gi := MeshInstance3D.new()
	gi.name = "Glow"
	gi.mesh = glow_st.commit()
	gi.material_override = gm
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(gi)


static func _chips(g: Node3D, line: Dictionary, h: Callable, rock: Color, rng: RandomNumberGenerator) -> void:
	# Broken chips of rock along both lips, some tipped out over the dark (crack.gd's clods, in stone)
	var xs: PackedFloat32Array = line.x
	var top: PackedFloat32Array = line.top
	var bot: PackedFloat32Array = line.bot
	var mats := [_mat(rock.lightened(0.08)), _mat(rock.darkened(0.15)), _mat(rock.darkened(0.35))]
	var i := 2
	while i < xs.size() - 2:
		var w := (top[i] - bot[i]) * 0.5
		for side in 2:
			if rng.randf() < 0.45:
				continue
			var sgn := 1.0 if side == 0 else -1.0
			var edge := top[i] if side == 0 else bot[i]
			var s := rng.randf_range(0.025, 0.055) * clampf(w / WIDTH * 1.8, 0.5, 1.0)
			var z := edge + sgn * (s * 0.5 - rng.randf_range(-0.005, 0.02))
			if meet_fade(line, xs[i], z) < 0.9:
				continue
			var chip := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = rng.randi_range(4, 6)
			sm.rings = 2
			chip.mesh = sm
			chip.scale = Vector3(s * rng.randf_range(1.0, 1.7), s * rng.randf_range(0.4, 0.7), s)
			chip.material_override = mats[rng.randi() % mats.size()]
			chip.position = Vector3(xs[i], float(h.call(xs[i], z)) + LIP * 0.6, z)
			chip.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-PI, PI), rng.randf_range(-0.4, 0.4))
			chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(chip)
		i += rng.randi_range(2, 4)


static func _fissures(g: Node3D, line: Dictionary, h: Callable, rock: Color, rng: RandomNumberGenerator) -> void:
	# Thin dark cracks branching off the split across the stone (crack.gd's side cracks, smaller)
	var xs: PackedFloat32Array = line.x
	var top: PackedFloat32Array = line.top
	var bot: PackedFloat32Array = line.bot
	var half: float = line.half
	var mid_x: float = line.mid_x
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var i := rng.randi_range(int(xs.size() * 0.15), int(xs.size() * 0.85))
		var side := -1.0 if k % 2 == 0 else 1.0
		var p := Vector2(xs[i], (top[i] if side > 0 else bot[i]) + side * 0.02)
		var a := side * rng.randf_range(0.5, 1.3)
		var dir := Vector2(cos(a), sin(a))
		if rng.randf() < 0.5:
			dir.x = -dir.x
		var length := rng.randf_range(0.15, 0.4) * clampf(1.2 - absf(xs[i] - mid_x) / half, 0.4, 1.0)
		var w := rng.randf_range(0.008, 0.015)
		var segs := 4
		for s in segs:
			var nd := dir.rotated(rng.randf_range(-0.6, 0.6))
			var q := p + nd * (length / segs)
			var w0 := w * (1.0 - float(s) / segs) + 0.002
			var w1 := w * (1.0 - float(s + 1) / segs) + 0.002
			var sd := Vector2(-nd.y, nd.x)
			var quad := [p + sd * w0, q + sd * w1, q - sd * w1, p - sd * w0]
			var v3: Array = []
			var ok := true
			for c in quad:
				var c2: Vector2 = c
				var y := float(h.call(c2.x, c2.y))
				if y == -INF:
					ok = false
					break
				v3.append(Vector3(c2.x, y + 0.006, c2.y))
			if not ok:
				break
			for tri in [[v3[0], v3[1], v3[2]], [v3[0], v3[2], v3[3]]]:
				var v: Array = tri
				if (v[2] - v[0]).cross(v[1] - v[0]).y < 0.0:
					v = [v[0], v[2], v[1]]
				for q3 in v:
					st.set_normal(Vector3.UP)
					st.add_vertex(q3)
			p = q
			dir = nd
	var mi := MeshInstance3D.new()
	mi.name = "Fissures"
	mi.mesh = st.commit()
	mi.material_override = _mat(DEEP.lerp(rock, 0.15))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Sinker Chip"
	m.albedo_color = c
	m.roughness = 0.95
	return m
