extends RefCounted

# Pieces for building caves, shared by Lanternmoor's Glimmer Caves (tools/build_lanternmoor.gd) and the Void's
# Secret Gardens caves. Caves are meant to be explored with Pip's glow (scripts/pip_glow.gd): put a dark_zone() over
# them and they go dark unless you're glowing.
#
# build() makes one seamless rock cave (a mesh you see from the inside, and its collision) from a list of shapes,
# carved out of solid rock:
#   {"kind": "room",   "at": Vector3, "r": 7.0, "squash": 0.6, "floor": y}   an egg-shaped hollow (r across, r * squash
#        up and down, or give "rx"/"ry"/"rz"); "floor" cuts its bottom flat at that height (default: 60% of the way down)
#   {"kind": "tunnel", "points": [Vector3, ...], "r": 2.5, "floor": 0.55}    a winding tube through the points; its
#        floor is cut flat "floor" * r under the middle of the tube, so it slopes along with the tunnel
#   {"kind": "shaft",  "at": Vector3, "r": 3.0, "top": y}                   a round upright shaft from "at" (its floor)
#        up to "top": run it past opts.top to open the cave to the world above
#   any shape with "solid": true is put back as rock instead (a pillar, a ledge, a lump in a room's middle)
# The shapes are added up as a signed distance field (negative is air) with a soft blend where they meet, so a tunnel
# runs into a room with no seam, and a little noise makes the walls rocky. The surface is made by surface nets on a
# grid of opts.cell metres. It's GDScript, so a big cave takes a few seconds: build it in a builder and save it, or
# cache it.
#
# No class_name on purpose (see scripts/use_spot.gd): load it with preload.

const BIG := 6.0                       # "solid rock" in the field, far from any hollow
const ROCK := Color(0.42, 0.36, 0.55)
const ROCK_DARK := Color(0.26, 0.22, 0.36)
const MOSS := Color(0.32, 0.46, 0.48)
const GLOW_MOSS := Color(0.45, 1.0, 0.85)
const CRYSTAL := Color(0.6, 0.75, 1.0)
const MUSHROOM := Color(0.75, 0.5, 1.0)
const DUST := Color(1.0, 0.85, 0.55)    # the moth dust Pip's glow shows up (glow bridges)
const GLOW_CRYSTAL := preload("res://scripts/glow_crystal.gd")
const LAYER := 1 << 10                 # render layer 11: cave rock, which the sun and moon never light (shade_from_sun)


# The cave itself -------------------------------------------------------------------------------------------------
# opts: "cell" (grid size, 1.0), "blend" (how softly shapes join, 1.2), "noise" (how rocky, 0.35), "seed",
# "top" (no cave above this height: shapes crossing it open there), "name", "rock" / "floor_colour" (Colors).
# Returns {"body": StaticBody3D (already added to parent), "field": the grid, for floor_below() / ceiling_above()}.
static func build(parent: Node3D, shapes: Array, opts := {}) -> Dictionary:
	var s: float = opts.get("cell", 1.0)
	var blend: float = opts.get("blend", 1.2)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for sh in shapes:
		if sh.get("solid", false):
			continue
		var b := _bounds(sh)
		lo = lo.min(b.position)
		hi = hi.max(b.end)
	lo -= Vector3.ONE * 2.0
	hi += Vector3.ONE * 2.0
	if opts.has("top"):
		hi.y = minf(hi.y, float(opts.top))
	var nx := int(ceil((hi.x - lo.x) / s)) + 1
	var ny := int(ceil((hi.y - lo.y) / s)) + 1
	var nz := int(ceil((hi.z - lo.z) / s)) + 1
	var f := {"lo": lo, "s": s, "nx": nx, "ny": ny, "nz": nz, "d": PackedFloat32Array()}
	var d: PackedFloat32Array = f.d
	d.resize(nx * ny * nz)
	d.fill(BIG)
	for sh in shapes:
		if not sh.get("solid", false):
			_stamp(f, sh, blend)
	for sh in shapes:                                           # rock put back goes in after every hollow
		if sh.get("solid", false):
			_stamp(f, sh, blend)
	var amp: float = opts.get("noise", 0.35)
	if amp > 0.0:
		var noise := FastNoiseLite.new()
		noise.seed = opts.get("seed", 7)
		noise.frequency = 0.16
		noise.fractal_octaves = 2
		for k in nz:
			for j in ny:
				for i in nx:
					var idx := (k * ny + j) * nx + i
					if absf(d[idx]) < 2.5:
						d[idx] += noise.get_noise_3d(lo.x + i * s, lo.y + j * s, lo.z + k * s) * amp
	f.d = d
	var body := StaticBody3D.new()
	body.name = opts.get("name", "Cave Rock")
	parent.add_child(body)
	var mesh := _surface(f, opts)
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = mesh
	mi.material_override = rock_material(opts.get("rock", ROCK))
	mi.layers = LAYER
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(mesh.get_meta("faces"))
	mesh.remove_meta("faces")
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("surface", "stone")
	return {"body": body, "field": f}


static func rock_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Cave Rock"
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	m.roughness = 0.95
	m.metallic_specular = 0.1
	m.disable_ambient_light = true                              # no sky light under the ground: only lamps and the glow
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.18
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 4
	tex.noise = n
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.62, 0.66))           # only light and shade: the colour's in the vertex colours
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	tex.color_ramp = ramp
	m.albedo_texture = tex
	return m


# Keep the sun and moon (every DirectionalLight3D in the scene) off cave rock (layer LAYER), so a cave under the ground
# is dark whatever the time of day. Call it once the scene's in (the world's setup).
static func shade_from_sun(scene: Node) -> void:
	for n in scene.find_children("*", "DirectionalLight3D", true, false):
		(n as DirectionalLight3D).light_cull_mask &= ~LAYER


# Put a decoration on the cave rock's layer, and keep the sky's light off it, so it's as dark as the rock round it
static func in_the_dark(n: Node) -> void:
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).layers = LAYER
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).layers = LAYER


# How far it is from p to the cave's air (negative: p is in the air). Reads the grid, nearest point.
static func field_at(f: Dictionary, p: Vector3) -> float:
	var q: Vector3 = (p - f.lo) / f.s
	var i := clampi(roundi(q.x), 0, f.nx - 1)
	var j := clampi(roundi(q.y), 0, f.ny - 1)
	var k := clampi(roundi(q.z), 0, f.nz - 1)
	return f.d[(k * f.ny + j) * f.nx + i]


# The cave's floor straight under p (or p itself if p is in rock), for standing things on it
static func floor_below(f: Dictionary, p: Vector3) -> Vector3:
	var q := p
	while q.y > f.lo.y and field_at(f, q) < 0.0:
		q.y -= f.s * 0.25
	return q


# ...and its ceiling straight over p
static func ceiling_above(f: Dictionary, p: Vector3) -> Vector3:
	var q := p
	var top: float = f.lo.y + (f.ny - 1) * f.s
	while q.y < top and field_at(f, q) < 0.0:
		q.y += f.s * 0.25
	return q


static func _bounds(sh: Dictionary) -> AABB:
	match sh.kind:
		"room":
			var e := _radii(sh)
			return AABB(sh.at - e, e * 2.0)
		"tunnel":
			var b := AABB(sh.points[0], Vector3.ZERO)
			for p in sh.points:
				b = b.expand(p)
			return b.grow(sh.r)
		"shaft":
			var top: float = sh.top
			return AABB(sh.at - Vector3(sh.r, 0, sh.r), Vector3(sh.r * 2.0, top - sh.at.y, sh.r * 2.0))
	return AABB()


static func _radii(sh: Dictionary) -> Vector3:
	var r: float = sh.get("r", 6.0)
	return Vector3(sh.get("rx", r), sh.get("ry", r * float(sh.get("squash", 0.6))), sh.get("rz", r))


static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a, -b, k)


static func _stamp(f: Dictionary, sh: Dictionary, blend: float) -> void:
	if sh.kind == "tunnel":
		var pts: Array = sh.points
		for i in pts.size() - 1:
			_stamp_box(f, AABB(pts[i], Vector3.ZERO).expand(pts[i + 1]).grow(sh.r + blend), sh, blend, i)
	else:
		_stamp_box(f, _bounds(sh).grow(blend), sh, blend, 0)


static func _stamp_box(f: Dictionary, box: AABB, sh: Dictionary, blend: float, seg: int) -> void:
	var lo: Vector3 = f.lo
	var s: float = f.s
	var nx: int = f.nx
	var ny: int = f.ny
	var nz: int = f.nz
	var d: PackedFloat32Array = f.d
	var i0 := maxi(0, floori((box.position.x - lo.x) / s))
	var i1 := mini(nx - 1, ceili((box.end.x - lo.x) / s))
	var j0 := maxi(0, floori((box.position.y - lo.y) / s))
	var j1 := mini(ny - 1, ceili((box.end.y - lo.y) / s))
	var k0 := maxi(0, floori((box.position.z - lo.z) / s))
	var k1 := mini(nz - 1, ceili((box.end.z - lo.z) / s))
	var solid: bool = sh.get("solid", false)
	var kind: String = sh.kind
	var a := Vector3.ZERO
	var ab := Vector3.ZERO
	var r: float = sh.get("r", 3.0)
	var e := Vector3.ONE
	var floor_y := -INF
	if kind == "tunnel":
		a = sh.points[seg]
		ab = sh.points[seg + 1] - a
	elif kind == "room":
		e = _radii(sh)
		floor_y = sh.get("floor", sh.at.y - e.y * 0.6)
	elif kind == "shaft":
		floor_y = sh.at.y
	var tfloor: float = sh.get("floor", 0.55) * r
	var len2 := maxf(ab.length_squared(), 0.0001)
	for k in range(k0, k1 + 1):
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var p := lo + Vector3(i, j, k) * s
				var dist := 0.0
				if kind == "tunnel":
					var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
					var c := a + ab * t
					dist = maxf((p - c).length() - r, (c.y - tfloor) - p.y)
				elif kind == "room":
					var q: Vector3 = (p - sh.at) / e
					dist = maxf((q.length() - 1.0) * minf(e.x, minf(e.y, e.z)), floor_y - p.y)
				else:
					var top: float = sh.top
					dist = maxf(Vector2(p.x - sh.at.x, p.z - sh.at.z).length() - r, maxf(floor_y - p.y, p.y - top))
				var idx := (k * ny + j) * nx + i
				d[idx] = _smax(d[idx], -dist, blend * 0.5) if solid else _smin(d[idx], dist, blend)
	f.d = d


# Surface nets: one point inside each grid cell the surface passes through, joined into quads across every grid edge
# it crosses. Points face into the air (that's the side you see from inside the cave).
static func _surface(f: Dictionary, opts: Dictionary) -> ArrayMesh:
	var lo: Vector3 = f.lo
	var s: float = f.s
	var nx: int = f.nx
	var ny: int = f.ny
	var nz: int = f.nz
	var d: PackedFloat32Array = f.d
	var cx := nx - 1
	var cy := ny - 1
	var cz := nz - 1
	var cell_vert := PackedInt32Array()
	cell_vert.resize(cx * cy * cz)
	cell_vert.fill(-1)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var rock: Color = opts.get("rock", ROCK)
	var moss: Color = opts.get("floor_colour", MOSS)
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var corner := []
	for n in 8:
		corner.append(Vector3(n & 1, (n >> 1) & 1, (n >> 2) & 1))
	var c := PackedFloat32Array()
	c.resize(8)
	for k in cz:
		for j in cy:
			for i in cx:
				var neg := 0
				for n in 8:
					var v := d[((k + (n >> 2 & 1)) * ny + j + (n >> 1 & 1)) * nx + i + (n & 1)]
					c[n] = v
					if v < 0.0:
						neg += 1
				if neg == 0 or neg == 8:
					continue
				var sum := Vector3.ZERO
				var cnt := 0
				for e in edges:
					var va := c[e[0]]
					var vb := c[e[1]]
					if (va < 0.0) != (vb < 0.0):
						var t := va / (va - vb)
						sum += (corner[e[0]] as Vector3).lerp(corner[e[1]], t)
						cnt += 1
				var g := Vector3((c[1] - c[0]) + (c[3] - c[2]) + (c[5] - c[4]) + (c[7] - c[6]),
					(c[2] - c[0]) + (c[3] - c[1]) + (c[6] - c[4]) + (c[7] - c[5]),
					(c[4] - c[0]) + (c[5] - c[1]) + (c[6] - c[2]) + (c[7] - c[3]))
				var nrm := -g.normalized() if g.length_squared() > 0.000001 else Vector3.UP
				cell_vert[(k * cy + j) * cx + i] = verts.size()
				verts.append(lo + (Vector3(i, j, k) + sum / cnt) * s)
				normals.append(nrm)
				var shade := 0.85 + 0.3 * fposmod(sin(i * 12.9898 + j * 78.233 + k * 37.719) * 43758.5453, 1.0)
				if nrm.y > 0.55:
					colours.append(moss.lerp(rock, 0.25) * shade)
				elif nrm.y < -0.55:
					colours.append(ROCK_DARK.lerp(rock, 0.4) * shade)
				else:
					colours.append(rock * shade)
	var index := PackedInt32Array()
	var faces := PackedVector3Array()
	# Edges along x, y and z, each with the four cells round it
	var sizes := [nx, ny, nz]
	for axis in 3:
		for k in range(0, nz):
			for j in range(0, ny):
				for i in range(0, nx):
					var a := Vector3i(i, j, k)
					var b := a
					b[axis] += 1
					if b.x >= nx or b.y >= ny or b.z >= nz:
						continue
					var u := (axis + 1) % 3
					var w := (axis + 2) % 3
					if a[u] < 1 or a[w] < 1 or a[u] > sizes[u] - 2 or a[w] > sizes[w] - 2:
						continue
					var da := d[(a.z * ny + a.y) * nx + a.x]
					var db := d[(b.z * ny + b.y) * nx + b.x]
					if (da < 0.0) == (db < 0.0):
						continue
					var q := []
					for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0)]:
						var cc := a
						cc[u] += o.x
						cc[w] += o.y
						q.append(cell_vert[(cc.z * cy + cc.y) * cx + cc.x])
					if q.has(-1):
						continue
					var want := (normals[q[0]] + normals[q[1]] + normals[q[2]] + normals[q[3]])
					_tri(index, faces, verts, q[0], q[1], q[2], want)
					_tri(index, faces, verts, q[0], q[2], q[3], want)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("faces", faces)
	return mesh


static func _tri(index: PackedInt32Array, faces: PackedVector3Array, verts: PackedVector3Array, a: int, b: int, c: int,
		want: Vector3) -> void:
	# Wind it so its front faces `want` (into the air), the only side Godot draws
	var pa := verts[a]
	var pb := verts[b]
	var pc := verts[c]
	if (pc - pa).cross(pb - pa).dot(want) < 0.0:
		var t := b
		b = c
		c = t
		pb = verts[b]
		pc = verts[c]
	index.append_array([a, b, c])
	faces.append_array([pa, pb, pc])


# Darkness -----------------------------------------------------------------------------------------------------------
# A box of dark: while the player's inside it the light goes and only Pip's glow lights the way (scripts/pip_glow.gd).
static func dark_zone(parent: Node3D, centre: Vector3, size: Vector3, zone_name := "Dark") -> Node3D:
	var z := Node3D.new()
	z.name = zone_name
	z.set_meta("size", size)
	z.add_to_group("cave_dark", true)
	parent.add_child(z)
	z.position = centre
	return z


static func in_zone(zone: Node3D, p: Vector3) -> bool:
	var size: Vector3 = zone.get_meta("size", Vector3.ZERO)
	var q := zone.global_transform.affine_inverse() * p
	return absf(q.x) <= size.x * 0.5 and absf(q.y) <= size.y * 0.5 and absf(q.z) <= size.z * 0.5


# Decorations ------------------------------------------------------------------------------------------------------
static func _mat(colour: Color, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, alpha)
	m.roughness = 0.6
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _cone(top: float, bottom: float, h: float, seg := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


# Stalactites hanging from the ceiling over a circle (and a few stalagmites under them), found with the cave's field
static func stalactites(parent: Node3D, f: Dictionary, centre: Vector3, r: float, n: int, seed := 1) -> Node3D:
	var g := Node3D.new()
	g.name = "Stalactites"
	parent.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := _mat(ROCK.lightened(0.15))
	m.disable_ambient_light = true
	for i in n:
		var a := rng.randf() * TAU
		var p := centre + Vector3(cos(a), 0, sin(a)) * sqrt(rng.randf()) * r
		if field_at(f, p) >= 0.0:
			continue
		var top := ceiling_above(f, p)
		var bottom := floor_below(f, p)
		var room := top.y - bottom.y
		if room < 3.0:
			continue
		var h := minf(rng.randf_range(0.8, 2.6), room * 0.35)
		var mi := MeshInstance3D.new()
		mi.mesh = _cone(0.02, rng.randf_range(0.18, 0.4), h)
		mi.material_override = m
		g.add_child(mi)
		mi.position = top + Vector3(0, 0.25, 0)
		mi.position.y -= h * 0.5
		mi.rotation.x = PI
		if rng.randf() < 0.4:
			var up := MeshInstance3D.new()
			up.mesh = _cone(0.03, rng.randf_range(0.25, 0.5), h * 0.6)
			up.material_override = m
			g.add_child(up)
			up.position = bottom + Vector3(rng.randf_range(-0.6, 0.6), h * 0.3 - 0.1, rng.randf_range(-0.6, 0.6))
	in_the_dark(g)
	return g


# A cluster of crystals that sleep dim in the dark and wake up shining when Pip's glow first reaches them
# (scripts/glow_crystal.gd, group "glow_wake")
static func crystals(parent: Node3D, pos: Vector3, colour := CRYSTAL, n := 5, seed := 1, size := 1.0) -> Node3D:
	var g := Node3D.new()
	g.name = "Crystals"
	g.set_script(GLOW_CRYSTAL)
	g.set("colour", colour)
	parent.add_child(g)
	g.position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var m := _mat(colour, 0.25, 0.85)
	m.resource_name = "Crystal"
	for i in n:
		var mi := MeshInstance3D.new()
		var h := rng.randf_range(0.6, 1.6) * size
		mi.mesh = _cone(0.0, rng.randf_range(0.12, 0.26) * size, h, 5)
		mi.material_override = m
		g.add_child(mi)
		var a := rng.randf() * TAU
		mi.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.45) * size + Vector3(0, h * 0.45, 0)
		mi.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45))
	return g


# Little glowing mushrooms on the floor round a spot (they always glow a little: cave lamps you can find)
static func mushrooms(parent: Node3D, f: Dictionary, pos: Vector3, n := 6, seed := 1, colour := MUSHROOM) -> Node3D:
	var g := Node3D.new()
	g.name = "Mushrooms"
	parent.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cap := _mat(colour, 1.4)
	var stem := _mat(Color(0.85, 0.82, 0.95))
	for i in n:
		var a := rng.randf() * TAU
		var p := floor_below(f, pos + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.2, 1.6))
		var s := rng.randf_range(0.5, 1.2)
		var st := MeshInstance3D.new()
		st.mesh = _cone(0.04 * s, 0.06 * s, 0.3 * s)
		st.material_override = stem
		g.add_child(st)
		st.position = p + Vector3(0, 0.15 * s, 0)
		var c := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.16 * s
		sp.height = 0.16 * s
		sp.is_hemisphere = true
		sp.radial_segments = 10
		sp.rings = 3
		c.mesh = sp
		c.material_override = cap
		g.add_child(c)
		c.position = p + Vector3(0, 0.3 * s, 0)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 0.6
	light.omni_range = 3.5
	g.add_child(light)
	light.position = floor_below(f, pos) + Vector3(0, 0.6, 0)
	return g


# A patch of glowing moss on the floor
static func glow_moss(parent: Node3D, f: Dictionary, pos: Vector3, r := 1.5, colour := GLOW_MOSS) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Glow Moss"
	var c := _cone(r, r, 0.04, 14)
	mi.mesh = c
	mi.material_override = _mat(colour, 0.9)
	parent.add_child(mi)
	mi.position = floor_below(f, pos) + Vector3(0, 0.04, 0)
	return mi


# A bridge of moth dust from a to b that only Pip's glow shows: each plank is in group "glow_solid", so it's there
# (seen and stood on) only while the glow reaches it, and the bridge seems to grow ahead of you as you walk.
static func glow_bridge(parent: Node3D, a: Vector3, b: Vector3, width := 1.6, plank := 1.2) -> Node3D:
	var g := Node3D.new()
	g.name = "Glow Bridge"
	parent.add_child(g)
	var n := maxi(1, ceili(a.distance_to(b) / plank))
	var m := _mat(DUST, 1.6, 0.8)
	m.resource_name = "Moth Dust"
	var dir := (b - a).normalized()
	for i in n:
		var body := StaticBody3D.new()
		body.name = "Plank%d" % (i + 1)
		body.add_to_group("glow_solid", true)
		g.add_child(body)
		body.position = a.lerp(b, (i + 0.5) / n)
		body.rotation.y = atan2(dir.x, dir.z)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, 0.18, a.distance_to(b) / n * 0.92)
		mi.mesh = bm
		mi.material_override = m
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, 0.3, a.distance_to(b) / n)
		cs.shape = box
		body.add_child(cs)
		body.set_meta("surface", "wood")
	return g
