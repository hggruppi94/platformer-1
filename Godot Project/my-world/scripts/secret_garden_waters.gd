extends "res://scripts/secret_garden_kit.gd"

# The rebuilt Secret Garden's waters, at the bottom of the hill by the door (26 Nov 2026; see scripts/secret_garden.gd).
# Our own take on these, not copies:
#   - Temple Lake (after Stourhead's lake): a big still lake, a little round temple of columns on its far shore (after
#     the lakeside temples of English landscape gardens) with the first seed on its steps, and a roofed bridge of
#     columns over its east arm (after the Palladian bridges at Wilton, Stowe and Prior Park)
#   - the Lily Pond (after Monet's garden at Giverny): water lilies all over it, weeping willows round it, and an arched
#     green footbridge hung with wisteria out to its island, where the pond seed sleeps
#   - the Japanese Garden (after the Portland Japanese Garden and Kyoto's stroll gardens): a koi pond with fish, a rock
#     waterfall, a stream running down to the Lily Pond under a red moon bridge, stone lanterns, maples, pines and
#     blossom, a raked gravel garden with its rocks, and a little tea house
#   - the Rose Walk (after the Huntington's and Sissinghurst's): rose arches all the way up the east side
# The ground (the lakes' beds, the island, the stream's channel) is secret_garden_land.gd's.

const WATER_SHADER := preload("res://scripts/garden_water.gdshader")
const TEMPLE := Vector3(-22.0, 0.0, 84.0)       # the Lake Temple's middle (its y is the ground's)
const TEMPLE_R := 4.4                           # its ring of columns
const PODIUM_R := 5.6                           # the top of its stepped podium
const PODIUM_H := 1.1
const PALLADIAN := Vector2(38.0, 63.0)          # the roofed bridge's ends (z), at x 50
const GREEN_BRIDGE := [Vector2(-62.0, 52.0), Vector2(-74.2, 52.0)]
const ISLAND := Vector2(-78.0, 52.0)
const MOON_BRIDGE := Vector2(-93.45, 102.36)    # where the Japanese Garden's path crosses the stream
const KOI_POND := Vector2(-102.0, 119.0)
const TEA_HOUSE := Vector3(-92.0, 2.0, 130.0)
const DRY_GARDEN := Rect2(-84.0, 112.0, 14.0, 18.0)
const FALLS := Vector2(-104.0, 127.6)           # the koi pond's waterfall, on its north shore
const ROSE_WALK := [Vector2(74, 30), Vector2(90, 60), Vector2(92, 100)]
const SURFACES := [["Estate Stone", "stone", 1.0], ["Estate Stone Dark", "stone", 0.8], ["Temple Dome", "stone", 0.7],
	["Lantern Stone", "rock", 0.6], ["Falls Rock", "rock", 1.2], ["Tea House Boards", "barn_boards", 0.6],
	["Tea House Roof", "shingles", 0.6], ["Moon Bridge Red", "maple", 0.8], ["Monet Green", "maple", 0.8],
	["Garden Rock", "rock", 1.0]]

var _keep: Array[Vector3] = []                  # (x, z, radius): no wild flowers here
var _koi: Array[Node3D] = []
var _falls: Array[MeshInstance3D] = []
var _water_mats: Array[ShaderMaterial] = []


func build(garden: Node3D) -> void:
	start(garden, "Waters", 4127)
	_temple_lake()
	_temple()
	_palladian_bridge()
	_lily_pond()
	_japanese_garden()
	_rose_walk()
	_water_trees()
	finish(SURFACES)


# -----------------------------------------------------------------------------
# Water: a sheet laid over wherever the ground's under the surface (so it follows any lake's shape), drawn with the
# garden water shader, and a wade zone round each lake
# -----------------------------------------------------------------------------
func water_material(nm: String, flow := Vector2.ZERO, clear := 0.9) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = nm
	m.shader = WATER_SHADER
	m.set_shader_parameter("flow_dir", flow)
	m.set_shader_parameter("clear_depth", clear)
	_water_mats.append(m)
	return m


func water_sheet(parent: Node3D, nm: String, area: Rect2, y: float, m: Material, cell := 1.0) -> MeshInstance3D:
	# Squares over area wherever the ground at any corner is under the surface
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var nx := ceili(area.size.x / cell)
	var nz := ceili(area.size.y / cell)
	var count := 0
	for j in nz:
		for i in nx:
			var x0 := area.position.x + i * cell
			var z0 := area.position.y + j * cell
			var wet := false
			for c in [Vector2(x0, z0), Vector2(x0 + cell, z0), Vector2(x0, z0 + cell), Vector2(x0 + cell, z0 + cell)]:
				if ground(c.x, c.y) < y - 0.01:
					wet = true
					break
			if not wet:
				continue
			var v := [Vector3(x0, y, z0), Vector3(x0 + cell, y, z0), Vector3(x0 + cell, y, z0 + cell), Vector3(x0, y, z0 + cell)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_uv(Vector2(v[k].x, v[k].z) * 0.1)
				st.add_vertex(v[k])
			count += 1
	if count == 0:
		return null
	var mi := sg._mesh(parent, st.commit(), Vector3.ZERO, m, false) as MeshInstance3D
	mi.name = nm
	return mi


func lake_wade(lake_name: String) -> void:
	for lake in LAND.LAKES:
		if lake[0] == lake_name:
			var c: Vector2 = lake[1]
			var r: Vector2 = lake[2]
			wade(lake_name + " Water Zone", [Vector4(c.x, c.y, r.x * 0.97, r.y * 0.97)] as Array[Vector4], float(lake[4]))


func _lily_pads(parent: Node3D, nm: String, centre: Vector2, radii: Vector2, y: float, count: int, avoid: Array) -> void:
	# Round pads with a notch (drawn as a flat disc), and a few pink and white flowers among them
	var pad := CylinderMesh.new()
	pad.top_radius = 0.55
	pad.bottom_radius = 0.55
	pad.height = 0.03
	pad.radial_segments = 10
	var flower := SphereMesh.new()
	flower.radius = 0.16
	flower.height = 0.2
	flower.radial_segments = 8
	flower.rings = 4
	var pads: Array = []
	var flowers: Array = []
	var tries := 0
	while pads.size() < count and tries < count * 12:
		tries += 1
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * 0.92
		var p := centre + Vector2(cos(a) * radii.x, sin(a) * radii.y) * d
		if ground(p.x, p.y) > y - 0.25:
			continue
		var blocked := false
		for av: Vector3 in avoid:
			if p.distance_to(Vector2(av.x, av.y)) < av.z:
				blocked = true
				break
		if blocked:
			continue
		var k := _rng.randf_range(0.6, 1.5)
		pads.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(k, 1, k)), Vector3(p.x, y + 0.02, p.y)))
		if _rng.randf() < 0.22:
			flowers.append(Transform3D(Basis.IDENTITY, Vector3(p.x + 0.15, y + 0.1, p.y)))
	sg._multi(parent, nm + " Pads", pad, pads, sg._mat("Lily Pad", Color(0.24, 0.5, 0.24), 0.6))
	sg._multi(parent, nm + " Lilies", flower, flowers, glow(sg._mat("Water Lily", Color(1.0, 0.72, 0.86), 0.5, 0.3)))


# -----------------------------------------------------------------------------
# Temple Lake
# -----------------------------------------------------------------------------
func _temple_lake() -> void:
	var g := group("Temple Lake")
	var m := water_material("Temple Lake Water", Vector2.ZERO, 1.1)
	water_sheet(g, "Temple Lake Water", Rect2(-36.0, 28.0, 112.0, 56.0), LAND.WATER_Y, m)
	lake_wade("Temple Lake")
	lake_wade("Temple Lake Arm")
	_lily_pads(g, "Temple Lake", Vector2(4.0, 56.0), Vector2(36.0, 24.0), LAND.WATER_Y, 70,
		[Vector3(4.0, 56.0, 20.0), Vector3(50.0, 50.0, 5.0)])
	# A rowboat tied up by the south shore
	var boat := group("Rowboat", g)
	boat.position = Vector3(14.0, LAND.WATER_Y + 0.05, 34.5)
	boat.rotation.y = 0.3
	var wood: StandardMaterial3D = sg._mat("Boat Wood", Color(0.55, 0.36, 0.24), 0.7)
	var paint: StandardMaterial3D = sg._mat("Boat Paint", Color(0.85, 0.88, 0.92), 0.6)
	var hull := SphereMesh.new()
	hull.radius = 1.0
	hull.height = 1.0
	hull.is_hemisphere = true
	hull.radial_segments = 16
	hull.rings = 6
	var h := sg._mesh(boat, hull, Vector3(0, 0.3, 0), paint) as MeshInstance3D
	h.rotation.x = PI
	h.scale = Vector3(0.7, 0.5, 1.75)
	h.name = "Hull"
	var inside := disc(boat, "Boat Inside", Vector3(0, 0.26, 0), 0.95, wood)
	inside.scale = Vector3(0.68, 1, 1.7)
	block(boat, "Seat", Vector3(1.2, 0.06, 0.3), Vector3(0, 0.22, 0.3), wood, false)
	block(boat, "Seat", Vector3(1.1, 0.06, 0.3), Vector3(0, 0.22, -0.7), wood, false)
	block(boat, "Oar", Vector3(0.08, 0.05, 2.4), Vector3(0.45, 0.32, -0.2), wood, false, 0.2)
	_keep.append(Vector3(14.0, 34.5, 3.0))


func _temple() -> void:
	# A round temple of twelve columns on a stepped podium, a dome on top, an urn on a plinth inside
	var g := group("Lake Temple")
	var at := Vector3(TEMPLE.x, ground(TEMPLE.x, TEMPLE.z) - 0.1, TEMPLE.z)
	g.position = at
	var st := stone()
	# The podium: four round steps (drawn), walked up as a gentle cone all the way round
	for i in 4:
		var r := PODIUM_R + (3 - i) * 0.55
		var hgt := PODIUM_H * (i + 1) / 4.0
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = hgt + 0.4
		cm.radial_segments = 32
		sg._mesh(g, cm, Vector3(0, (hgt - 0.4) / 2.0, 0), st if i % 2 == 0 else stone_dark()).name = "Temple Step"
	var cone := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(Vector3(cos(a) * (PODIUM_R + 2.0), -0.3, sin(a) * (PODIUM_R + 2.0)))
		pts.append(Vector3(cos(a) * (PODIUM_R - 0.1), PODIUM_H, sin(a) * (PODIUM_R - 0.1)))
	cone.points = pts
	sg._solid(g, "Temple Podium Body", cone, Vector3.ZERO)
	# Twelve columns with bases and capitals
	var col_h := 5.2
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(cos(a) * TEMPLE_R, PODIUM_H, sin(a) * TEMPLE_R)
		sg._cyl(g, "Temple Column", 0.27, 0.32, col_h, p + Vector3(0, col_h / 2.0 + 0.2, 0), st, true)
		block(g, "Column Base", Vector3(0.8, 0.22, 0.8), p + Vector3(0, 0.11, 0), stone_dark(), false, a)
		block(g, "Column Capital", Vector3(0.82, 0.26, 0.82), p + Vector3(0, col_h + 0.33, 0), stone_dark(), false, a)
	# The entablature and the dome
	var top := PODIUM_H + col_h + 0.46
	for r_h in [[TEMPLE_R + 0.6, 0.55, stone()], [TEMPLE_R + 0.8, 0.18, stone_dark()]]:
		var cm := CylinderMesh.new()
		cm.top_radius = r_h[0]
		cm.bottom_radius = r_h[0]
		cm.height = r_h[1]
		cm.radial_segments = 32
		sg._mesh(g, cm, Vector3(0, top + float(r_h[1]) / 2.0 + (0.55 if r_h[1] < 0.3 else 0.0), 0), r_h[2]).name = "Entablature"
	var dome := SphereMesh.new()
	dome.radius = TEMPLE_R + 0.5
	dome.height = (TEMPLE_R + 0.5) * 1.3
	dome.is_hemisphere = true
	dome.radial_segments = 28
	dome.rings = 10
	sg._mesh(g, dome, Vector3(0, top + 0.73, 0), sg._mat("Temple Dome", Color(0.62, 0.68, 0.64), 0.6)).name = "Temple Dome"
	var lantern := lathe([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.4, 0.3), Vector2(0.18, 0.5), Vector2(0.26, 0.75),
		Vector2(0.0, 1.0)], 12)
	sg._mesh(g, lantern, Vector3(0, top + 0.73 + (TEMPLE_R + 0.5) * 0.65 - 0.05, 0), stone_dark()).name = "Dome Finial"
	# Inside: a plinth with an urn of glowing flowers
	block(g, "Temple Plinth", Vector3(1.0, 1.1, 1.0), Vector3(0, PODIUM_H + 0.55, 0), stone(), true)
	urn(g, Vector3(0, PODIUM_H + 1.1, 0), 1.3)
	# The walk seed sleeps on its steps, on the side looking out over the lake
	var toward := (Vector2(4.0, 56.0) - Vector2(TEMPLE.x, TEMPLE.z)).normalized()
	var seed_at := Vector2(TEMPLE.x, TEMPLE.z) + toward * (PODIUM_R + 0.6)
	sg.put_seed("walk", Vector3(seed_at.x, at.y + PODIUM_H * 0.72, seed_at.y))
	_keep.append(Vector3(TEMPLE.x, TEMPLE.z, PODIUM_R + 3.0))


func _palladian_bridge() -> void:
	# A long low arched bridge over the lake's east arm with a colonnade along it under a roof, a pavilion at each end
	# and one in the middle
	var g := group("Palladian Bridge")
	var a := on_ground(50.0, PALLADIAN.x)
	var b := on_ground(50.0, PALLADIAN.y)
	var rise := 1.3
	bridge(g, "Palladian Bridge Deck", a, b, rise, 5.2, true, null, 1.4)
	var st := stone()
	var roof_y := maxf(a.y, b.y) + rise + 4.2
	var n := 12
	var length := b.z - a.z
	for side: float in [-1.0, 1.0]:
		for i in range(1, n):
			var t := float(i) / n
			var z := a.z + length * t
			var deck := a.y + (b.y - a.y) * t + rise * sin(PI * t)
			var x := 50.0 + side * 2.15
			var h := roof_y - deck - 0.3
			if i % 3 == 0:
				# a square pier at each pavilion
				block(g, "Bridge Pier", Vector3(0.7, h, 0.7), Vector3(x, deck + h / 2.0, z), st, true)
			else:
				sg._cyl(g, "Bridge Column", 0.18, 0.2, h - 0.3, Vector3(x, deck + (h - 0.3) / 2.0 + 0.1, z), st, false)
				block(g, "Bridge Capital", Vector3(0.5, 0.2, 0.5), Vector3(x, deck + h - 0.1, z), stone_dark(), false)
	# The roof: a long entablature on each side and a slate roof over it, pediments over the pavilions
	var slate: StandardMaterial3D = sg._mat("Slate Roof", Color(0.36, 0.38, 0.44), 0.8)
	var z0 := a.z + length / n
	var z1 := b.z - length / n
	block(g, "Bridge Entablature", Vector3(5.1, 0.55, z1 - z0 + 1.0), Vector3(50.0, roof_y, (z0 + z1) / 2.0), st, false)
	for side: float in [-1.0, 1.0]:
		var roof := BoxMesh.new()
		roof.size = Vector3(3.2, 0.18, z1 - z0 + 1.6)
		var r := sg._mesh(g, roof, Vector3(50.0 + side * 1.35, roof_y + 0.85, (z0 + z1) / 2.0), slate) as MeshInstance3D
		r.rotation.z = -side * 0.5
		r.name = "Bridge Roof"
	for i in [3, 6, 9]:
		var z: float = a.z + length * i / n
		var ped := PrismMesh.new()
		ped.size = Vector3(5.6, 1.5, 2.6)
		sg._mesh(g, ped, Vector3(50.0, roof_y + 1.0, z), st).name = "Pavilion Pediment"
		urn(g, Vector3(50.0, roof_y + 1.75, z), 0.8)
	_keep.append(Vector3(50.0, PALLADIAN.x, 4.0))
	_keep.append(Vector3(50.0, PALLADIAN.y, 4.0))


# -----------------------------------------------------------------------------
# The Lily Pond and its green bridge
# -----------------------------------------------------------------------------
func _lily_pond() -> void:
	var g := group("Lily Pond")
	water_sheet(g, "Lily Pond Water", Rect2(-120.0, 34.0, 60.0, 40.0), LAND.WATER_Y, water_material("Lily Pond Water", Vector2.ZERO, 0.7))
	lake_wade("Lily Pond")
	_lily_pads(g, "Lily Pond", Vector2(-90.0, 54.0), Vector2(27.0, 18.0), LAND.WATER_Y, 260,
		[Vector3(ISLAND.x, ISLAND.y, 6.5), Vector3(-68.0, 52.0, 3.5)])
	# The green bridge (Monet's), arched, with wisteria trained over arches above it
	var a := on_ground(GREEN_BRIDGE[0].x, GREEN_BRIDGE[0].y)
	var b := on_ground(GREEN_BRIDGE[1].x, GREEN_BRIDGE[1].y)
	var green: StandardMaterial3D = sg._mat("Monet Green", Color(0.3, 0.58, 0.36), 0.6)
	var wood: StandardMaterial3D = sg._mat("Bridge Planks", Color(0.48, 0.38, 0.28), 0.8)
	var rise := 1.1
	bridge(g, "Green Bridge", a, b, rise, 2.4, false, wood, 0.0, green)
	var wisteria: StandardMaterial3D = glow(sg._mat("Wisteria", Color(0.7, 0.55, 0.95), 0.6, 0.25))
	var span := a.distance_to(b)
	for i in 4:
		var t := (i + 0.5) / 4.0
		var p := a.lerp(b, t) + Vector3(0, rise * sin(PI * t), 0)
		for side: float in [-1.0, 1.0]:
			sg._cyl(g, "Trellis Post", 0.06, 0.06, 2.5, p + Vector3(0, 1.25, side * 1.25), green, false)
		block(g, "Trellis Bar", Vector3(0.12, 0.12, 2.7), p + Vector3(0, 2.55, 0), green, false)
		for k in 14:
			var z := _rng.randf_range(-1.3, 1.3)
			var r := _rng.randf_range(0.08, 0.13)
			var drop: MeshInstance3D = sg._ball(g, r, p + Vector3(_rng.randf_range(-0.5, 0.5), 2.45 - r * 2.2 - _rng.randf() * 0.2, z), wisteria, 3.2)
			drop.name = "Wisteria"
		sg._ball(g, 0.3, p + Vector3(0, 2.6, 0), sg._leaf(), 0.5).scale = Vector3(2.2, 1, 5.0)
	block(g, "Trellis Rail", Vector3(span, 0.1, 0.1), (a + b) / 2.0 + Vector3(0, rise + 2.6, 1.25), green, false)
	block(g, "Trellis Rail", Vector3(span, 0.1, 0.1), (a + b) / 2.0 + Vector3(0, rise + 2.6, -1.25), green, false)
	# The island: a willow, a stone bench, a stone lantern, and the pond seed by the water's edge
	var isle := on_ground(ISLAND.x, ISLAND.y)
	tree("willow", isle + Vector3(-1.6, 0, 1.0), 0.75)
	_stone_lantern(g, isle + Vector3(1.4, 0, -2.2))
	sg.put_seed("pond", isle + Vector3(1.6, 0.0, 1.6))
	_keep.append(Vector3(ISLAND.x, ISLAND.y, 5.5))


# -----------------------------------------------------------------------------
# The Japanese Garden
# -----------------------------------------------------------------------------
func _japanese_garden() -> void:
	var g := group("Japanese Garden")
	var koi_y: float = 1.85
	water_sheet(g, "Koi Pond Water", Rect2(-116.0, 110.0, 28.0, 18.0), koi_y, water_material("Koi Pond Water", Vector2.ZERO, 0.6))
	lake_wade("Koi Pond")
	_lily_pads(g, "Koi Pond", KOI_POND, Vector2(11.0, 7.0), koi_y, 18, [Vector3(FALLS.x, FALLS.y, 4.0)])
	ring_stones(g, KOI_POND, Vector2(11.4, 7.4), 26)
	_koi_fish(g, koi_y)
	_waterfall(g, koi_y)
	_stream(g)
	# The red moon bridge over the stream
	var dir := Vector2(-16.0, 4.0).normalized()
	var a2 := MOON_BRIDGE - dir * 3.8
	var b2 := MOON_BRIDGE + dir * 3.8
	var red: StandardMaterial3D = sg._mat("Moon Bridge Red", Color(0.78, 0.2, 0.16), 0.6)
	bridge(g, "Moon Bridge", on_ground(a2.x, a2.y), on_ground(b2.x, b2.y), 1.3, 2.0, false, red, 0.0,
		sg._mat("Moon Bridge Rail", Color(0.2, 0.15, 0.13), 0.7))
	_keep.append(Vector3(MOON_BRIDGE.x, MOON_BRIDGE.y, 5.0))
	# Stone lanterns along the path
	for p in [Vector2(-80.0, 98.0), Vector2(-99.0, 106.5), Vector2(-113.0, 113.0), Vector2(-120.5, 124.0),
			Vector2(-104.0, 138.5), Vector2(-88.0, 124.0), Vector2(-66.0, 76.0)]:
		_stone_lantern(g, on_ground(p.x, p.y))
	_dry_garden(g)
	_tea_house(g)


func ring_stones(parent: Node3D, c: Vector2, r: Vector2, count: int) -> void:
	# Rounded stones round a pond's edge
	var m: StandardMaterial3D = sg._mat("Garden Rock", Color(0.5, 0.49, 0.47), 0.9)
	for i in count:
		var a := TAU * i / count + _rng.randf() * 0.1
		var p := c + Vector2(cos(a) * r.x, sin(a) * r.y)
		var k := _rng.randf_range(0.35, 0.7)
		sg._ball(parent, k, on_ground(p.x, p.y) + Vector3(0, k * 0.2, 0), m, 0.6).name = "Pond Stone"


func _stone_lantern(parent: Node3D, at: Vector3) -> void:
	# A tōrō: a foot, a post, a little light box glowing at night, a roof and a knob on top
	var g := group("Stone Lantern", parent)
	g.position = at
	var m: StandardMaterial3D = sg._mat("Lantern Stone", Color(0.56, 0.56, 0.52), 0.95)
	block(g, "Lantern Foot", Vector3(0.8, 0.25, 0.8), Vector3(0, 0.12, 0), m, true)
	sg._cyl(g, "Lantern Post", 0.15, 0.18, 0.9, Vector3(0, 0.7, 0), m, false)
	block(g, "Lantern Shelf", Vector3(0.7, 0.14, 0.7), Vector3(0, 1.2, 0), m, false)
	block(g, "Lantern Box", Vector3(0.46, 0.42, 0.46), Vector3(0, 1.48, 0), m, false)
	var light: StandardMaterial3D = glow(sg._mat("Lantern Light", Color(1.0, 0.8, 0.45), 0.5, 1.2))
	block(g, "Lantern Window", Vector3(0.5, 0.22, 0.3), Vector3(0, 1.48, 0), light, false)
	block(g, "Lantern Window", Vector3(0.3, 0.22, 0.5), Vector3(0, 1.48, 0), light, false)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.08
	roof.bottom_radius = 0.62
	roof.height = 0.34
	roof.radial_segments = 6
	sg._mesh(g, roof, Vector3(0, 1.86, 0), m).name = "Lantern Roof"
	sg._ball(g, 0.11, Vector3(0, 2.1, 0), m, 1.3).name = "Lantern Knob"
	_keep.append(Vector3(at.x, at.z, 1.2))


func _koi_fish(parent: Node3D, y: float) -> void:
	var colours := [Color(1.0, 0.5, 0.15), Color(0.98, 0.95, 0.9), Color(0.95, 0.3, 0.15), Color(1.0, 0.75, 0.3)]
	for i in 9:
		var f := Node3D.new()
		f.name = "Koi"
		parent.add_child(f)
		var m: StandardMaterial3D = sg._mat("Koi %d" % (i % 4), colours[i % 4], 0.4)
		var body: MeshInstance3D = sg._ball(f, 0.18, Vector3.ZERO, m, 1.0)
		body.scale = Vector3(0.7, 0.55, 2.0)
		var tail: MeshInstance3D = sg._ball(f, 0.14, Vector3(0, 0, -0.42), m, 1.0)
		tail.scale = Vector3(1.4, 0.3, 0.8)
		if i % 2 == 0:
			sg._ball(f, 0.09, Vector3(0.0, 0.06, 0.12), sg._mat("Koi Spot", Color(0.95, 0.95, 0.92), 0.4))
		f.set_meta("orbit", Vector3(_rng.randf_range(2.0, 8.5), _rng.randf_range(1.2, 4.8), _rng.randf() * TAU))
		f.set_meta("speed", _rng.randf_range(0.12, 0.3) * (1.0 if i % 3 else -1.0))
		f.set_meta("y", y - 0.22)
		_koi.append(f)


func _waterfall(parent: Node3D, pool_y: float) -> void:
	# Rocks heaped up on the pond's north shore, water spilling down them in two falls, foam where it lands
	var g := group("Koi Falls", parent)
	var rock: StandardMaterial3D = sg._mat("Falls Rock", Color(0.46, 0.45, 0.44), 0.95)
	var base := on_ground(FALLS.x, FALLS.y + 2.0)
	var heap := [[Vector3(0, 0.6, 2.2), 2.2], [Vector3(-2.4, 0.5, 2.6), 1.7], [Vector3(2.5, 0.4, 2.4), 1.6],
		[Vector3(-1.2, 2.0, 2.8), 1.5], [Vector3(1.3, 1.9, 2.9), 1.4], [Vector3(0, 3.2, 3.3), 1.3],
		[Vector3(-3.6, 0.3, 1.4), 1.0], [Vector3(3.8, 0.3, 1.3), 0.9], [Vector3(0.2, 4.1, 3.9), 0.9]]
	for h in heap:
		var r: float = h[1]
		var mi: MeshInstance3D = sg._ball(g, r, base + (h[0] as Vector3) - Vector3(0, 0, 2.0), rock, 0.8)
		mi.name = "Falls Rock"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cs := BoxShape3D.new()
	cs.size = Vector3(8.0, 4.0, 3.4)
	sg._solid(g, "Falls Rocks Body", cs, base + Vector3(0, 1.6, 1.0))
	var fall_m: StandardMaterial3D = sg._mat("Falling Water", Color(0.82, 0.93, 0.98, 0.72), 0.1, 0.25)
	for f in [[Vector3(-0.2, 0, 0.2), 1.1, 3.9], [Vector3(1.6, 0, 0.6), 0.7, 2.3]]:
		var top: float = f[2]
		var qm := BoxMesh.new()
		qm.size = Vector3(f[1], top - (pool_y - base.y), 0.08)
		var mi := sg._mesh(g, qm, base + (f[0] as Vector3) + Vector3(0, (top + pool_y - base.y) / 2.0 - 0.0, -0.6), fall_m, false) as MeshInstance3D
		mi.position.y = (base.y + top + pool_y) / 2.0
		mi.rotation.x = 0.12
		mi.name = "Falling Water"
		_falls.append(mi)
		var foam := disc(g, "Falls Foam", Vector3(base.x + (f[0] as Vector3).x, pool_y + 0.03, base.z - 1.2), float(f[1]) * 0.9,
			sg._mat("Foam", Color(0.92, 0.97, 1.0, 0.7), 0.3))
		foam.scale = Vector3(1, 1, 0.6)
	_keep.append(Vector3(FALLS.x, FALLS.y + 1.5, 5.0))


func _stream(parent: Node3D) -> void:
	# A ribbon of moving water down the stream's channel, from the koi pond to the Lily Pond
	var st_def: Array = LAND.STREAMS[0]
	var pts: Array = st_def[0]
	var half: float = st_def[1] - 0.15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var samples: Array[Vector2] = []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, ceili(a.distance_to(b)))
		for k in n:
			samples.append(a.lerp(b, float(k) / n))
	samples.append(pts[pts.size() - 1])
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in samples.size():
		var p := samples[i]
		var d := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-d.y, d.x) * half
		var y := ground(p.x, p.y) + 0.32
		var l := Vector3(p.x + side.x, y, p.y + side.y)
		var r := Vector3(p.x - side.x, y, p.y - side.y)
		if i > 0:
			for v in [prev_l, prev_r, r, prev_l, r, l]:
				st.set_uv(Vector2(v.x, v.z) * 0.1)
				st.add_vertex(v)
		prev_l = l
		prev_r = r
	var mi := sg._mesh(parent, st.commit(), Vector3.ZERO, water_material("Stream Water", Vector2(0.1, -0.5), 0.4), false) as MeshInstance3D
	mi.name = "Stream Water"
	# Stones along its banks
	var m: StandardMaterial3D = sg._mat("Garden Rock", Color(0.5, 0.49, 0.47), 0.9)
	for i in range(2, samples.size() - 2, 3):
		var p := samples[i]
		var d := (samples[i + 1] - samples[i - 1]).normalized()
		var side := Vector2(-d.y, d.x) * (half + 0.9) * (1.0 if i % 2 else -1.0)
		var k := _rng.randf_range(0.3, 0.6)
		sg._ball(parent, k, on_ground(p.x + side.x, p.y + side.y) + Vector3(0, k * 0.15, 0), m, 0.6).name = "Stream Stone"


func _dry_garden(parent: Node3D) -> void:
	# Raked white gravel in lines round three rocks, inside a low clay wall on three sides (after Ryōan-ji's)
	var g := group("Dry Garden", parent)
	var r := DRY_GARDEN
	var y := LAND.pad_height(LAND.pad_named("Tea Garden"), r.get_center().y) + 0.03
	var gravel: StandardMaterial3D = sg._mat("Raked Gravel", Color(0.8, 0.79, 0.74), 0.95)
	var ridge: StandardMaterial3D = sg._mat("Raked Gravel Ridge", Color(0.66, 0.65, 0.6), 0.95)
	block(g, "Gravel Bed", Vector3(r.size.x, 0.06, r.size.y), Vector3(r.get_center().x, y, r.get_center().y), gravel, false)
	var rocks := [Vector3(-79.0, 116.5, 1.0), Vector3(-74.0, 122.0, 1.4), Vector3(-80.0, 126.5, 0.8)]
	for z in range(1, int(r.size.y / 0.45)):
		var zz := r.position.y + z * 0.45
		var bm := BoxMesh.new()
		bm.size = Vector3(r.size.x - 0.2, 0.03, 0.08)
		sg._mesh(g, bm, Vector3(r.get_center().x, y + 0.04, zz), ridge, false).name = "Rake Line"
	var rock_m: StandardMaterial3D = sg._mat("Garden Rock", Color(0.5, 0.49, 0.47), 0.9)
	for rk in rocks:
		var k: float = rk.z
		var mi: MeshInstance3D = sg._ball(g, k, Vector3(rk.x, y + k * 0.25, rk.y), rock_m, 0.75)
		mi.name = "Dry Garden Rock"
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# rings raked round each rock
		for ring in 3:
			var tm := TorusMesh.new()
			tm.inner_radius = k + 0.3 + ring * 0.45
			tm.outer_radius = k + 0.36 + ring * 0.45
			sg._mesh(g, tm, Vector3(rk.x, y + 0.04, rk.y), ridge, false).name = "Rake Ring"
		var cs := SphereShape3D.new()
		cs.radius = k
		sg._solid(g, "Dry Garden Rock Body", cs, Vector3(rk.x, y, rk.y))
	var wall: StandardMaterial3D = sg._mat("Clay Wall", Color(0.74, 0.6, 0.46), 0.9)
	block(g, "Clay Wall", Vector3(r.size.x, 1.2, 0.4), Vector3(r.get_center().x, y + 0.6, r.end.y + 0.2), wall, true)
	block(g, "Clay Wall", Vector3(0.4, 1.2, r.size.y), Vector3(r.end.x + 0.2, y + 0.6, r.get_center().y), wall, true)
	block(g, "Clay Wall Cap", Vector3(r.size.x + 0.4, 0.14, 0.6), Vector3(r.get_center().x, y + 1.25, r.end.y + 0.2),
		sg._mat("Tea House Roof", Color(0.3, 0.3, 0.32), 0.8), false)
	block(g, "Clay Wall Cap", Vector3(0.6, 0.14, r.size.y + 0.4), Vector3(r.end.x + 0.2, y + 1.25, r.get_center().y),
		sg._mat("Tea House Roof", Color(0.3, 0.3, 0.32), 0.8), false)
	_keep.append(Vector3(r.get_center().x, r.get_center().y, 11.0))


func _tea_house(parent: Node3D) -> void:
	# A little open tea house on a raised wooden floor, paper screens and a wide sweeping roof
	var g := group("Tea House", parent)
	var at := Vector3(TEA_HOUSE.x, ground(TEA_HOUSE.x, TEA_HOUSE.z), TEA_HOUSE.z)
	g.position = at
	var boards: StandardMaterial3D = sg._mat("Tea House Boards", Color(0.5, 0.36, 0.26), 0.8)
	var dark: StandardMaterial3D = sg._mat("Tea House Posts", Color(0.28, 0.2, 0.16), 0.8)
	var paper: StandardMaterial3D = sg._mat("Paper Screen", Color(0.96, 0.93, 0.84), 0.9, 0.15)
	var roof_m: StandardMaterial3D = sg._mat("Tea House Roof", Color(0.3, 0.3, 0.32), 0.8)
	# Its floor is low, with a step stone in front, so it's walked onto
	block(g, "Tea House Floor", Vector3(6.0, 0.3, 5.0), Vector3(0, 0.15, 0), boards, true)
	block(g, "Step Stone", Vector3(1.6, 0.15, 0.9), Vector3(0, 0.07, -3.0), sg._mat("Garden Rock", Color(0.5, 0.49, 0.47), 0.9), false)
	for c in [Vector2(-2.8, -2.3), Vector2(2.8, -2.3), Vector2(-2.8, 2.3), Vector2(2.8, 2.3)]:
		block(g, "Tea House Post", Vector3(0.24, 2.6, 0.24), Vector3(c.x, 1.6, c.y), dark, true)
	# Paper screens on the back and the sides (the front's open, facing the pond)
	block(g, "Paper Screen", Vector3(5.4, 2.1, 0.06), Vector3(0, 1.35, 2.3), paper, true)
	block(g, "Paper Screen", Vector3(0.06, 2.1, 4.4), Vector3(-2.8, 1.35, 0), paper, true)
	block(g, "Paper Screen", Vector3(0.06, 2.1, 4.4), Vector3(2.8, 1.35, 0), paper, true)
	for x in range(-2, 3):
		block(g, "Screen Bar", Vector3(0.06, 2.1, 0.1), Vector3(x * 1.1, 1.35, 2.27), dark, false)
	block(g, "Screen Rail", Vector3(5.5, 0.08, 0.1), Vector3(0, 1.6, 2.27), dark, false)
	# The roof: two wide sweeping slopes, a ridge, and the eaves lifted at the corners
	for side: float in [-1.0, 1.0]:
		var bm := BoxMesh.new()
		bm.size = Vector3(8.4, 0.16, 4.2)
		var r := sg._mesh(g, bm, Vector3(0, 3.35, side * 1.7), roof_m) as MeshInstance3D
		r.rotation.x = side * 0.42
		r.name = "Tea House Roof"
	block(g, "Roof Ridge", Vector3(8.8, 0.3, 0.4), Vector3(0, 4.15, 0), dark, false)
	for c in [Vector2(-4.2, -3.3), Vector2(4.2, -3.3), Vector2(-4.2, 3.3), Vector2(4.2, 3.3)]:
		var tip: MeshInstance3D = sg._ball(g, 0.18, Vector3(c.x, 2.75, c.y), dark, 0.6)
		tip.name = "Eave Tip"
	# A low table with tea on it
	block(g, "Tea Table", Vector3(1.4, 0.35, 0.9), Vector3(0, 0.48, 0.3), dark, false)
	sg._cyl(g, "Teapot", 0.14, 0.16, 0.2, Vector3(0, 0.75, 0.3), sg._mat("Teapot", Color(0.3, 0.45, 0.4), 0.4), false)
	_keep.append(Vector3(at.x, at.z, 5.5))


# -----------------------------------------------------------------------------
# The Rose Walk
# -----------------------------------------------------------------------------
func _rose_walk() -> void:
	var g := group("Rose Arches")
	var arch_mesh := baked("res://models/props/secret_garden/rose_arch.glb")
	var xfs: Array = []
	var rose_cols := [Color(0.95, 0.25, 0.35), Color(1.0, 0.65, 0.78), Color(0.98, 0.92, 0.8), Color(0.95, 0.55, 0.3)]
	var bush: Array = []
	var roses: Array = [[], [], [], []]
	for i in ROSE_WALK.size() - 1:
		var a: Vector2 = ROSE_WALK[i]
		var b: Vector2 = ROSE_WALK[i + 1]
		var n := floori(a.distance_to(b) / 4.5)
		var d := (b - a).normalized()
		var across := Vector3(-d.y, 0, d.x)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			var at := on_ground(p.x, p.y)
			var basis := Basis(across, Vector3.UP, across.cross(Vector3.UP))
			if arch_mesh:
				xfs.append(Transform3D(basis, at))
			else:
				for side: float in [-1.0, 1.0]:
					sg._cyl(g, "Arch Post", 0.08, 0.08, 3.0, at + across * side * 1.9 + Vector3(0, 1.5, 0),
						sg._mat("Arch Iron", Color(0.2, 0.22, 0.2), 0.6), false)
				var tm := TorusMesh.new()
				tm.inner_radius = 1.84
				tm.outer_radius = 1.96
				var mi := sg._mesh(g, tm, at + Vector3(0, 3.0, 0), sg._mat("Arch Iron", Color(0.2, 0.22, 0.2), 0.6)) as MeshInstance3D
				mi.basis = Basis(across, across.cross(Vector3.UP), -Vector3.UP).orthonormalized()
			# rose bushes in beds either side
			for side: float in [-1.0, 1.0]:
				for j in 2:
					var q := at + across * side * (2.8 + j * 0.9) + Vector3(d.x, 0, d.y) * _rng.randf_range(-1.8, 1.8)
					q.y = ground(q.x, q.z)
					bush.append(Transform3D(Basis.from_scale(Vector3(0.65, 0.55, 0.65)), q + Vector3(0, 0.45, 0)))
					for r in 3:
						var c := _rng.randi() % 4
						var off := Vector3(_rng.randf_range(-0.45, 0.45), _rng.randf_range(0.2, 0.55), _rng.randf_range(-0.45, 0.45))
						roses[c].append(Transform3D(Basis.from_scale(Vector3.ONE * 0.14), q + Vector3(0, 0.45, 0) + off))
			_keep.append(Vector3(at.x, at.z, 4.5))
	if arch_mesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = arch_mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Rose Arch Models"
		mmi.multimesh = mm
		mmi.set_meta("transforms", xfs)
		mmi.visibility_range_end = 160.0
		g.add_child(mmi)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 10
	ball.rings = 5
	sg._multi(g, "Rose Bushes", ball, bush, sg._mat("Rose Leaf", Color(0.2, 0.42, 0.22), 0.8))
	for c in 4:
		sg._multi(g, "Roses %d" % c, ball, roses[c], glow(sg._mat("Rose %d" % c, rose_cols[c], 0.5, 0.3)))
	set_meta("rose_arches", xfs.size() if arch_mesh else -1)


# -----------------------------------------------------------------------------
# Trees round the waters: willows by the ponds, oaks and cedars round the lake, maples, pines and blossom in the
# Japanese Garden
# -----------------------------------------------------------------------------
func _water_trees() -> void:
	# Willows round the Lily Pond's shore
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		var p := Vector2(-90.0, 54.0) + Vector2(cos(a) * 30.5, sin(a) * 21.0)
		if p.distance_to(GREEN_BRIDGE[0]) < 11.0 or LAND.path_dist(p.x, p.y) < 2.5:
			continue
		tree("willow", on_ground(p.x, p.y), _rng.randf_range(0.85, 1.1))
	# Round Temple Lake: big cedars and oaks, a copper beech, one weeping willow on the shore by the temple
	for t in [["cedar", Vector2(-50.0, 30.0), 1.1], ["oak", Vector2(-58.0, 88.0), 1.0], ["copper", Vector2(32.0, 88.0), 1.0],
			["cedar", Vector2(62.0, 80.0), 1.0], ["oak", Vector2(-30.0, 104.0), 0.9], ["willow", Vector2(-38.0, 70.0), 0.9],
			["oak", Vector2(38.0, 16.0), 0.9], ["oak", Vector2(-38.0, 14.0), 0.95], ["birch", Vector2(-56.0, 66.0), 1.0],
			["birch", Vector2(60.0, 30.0), 1.0], ["maple_gold", Vector2(22.0, 98.0), 1.0], ["cedar", Vector2(70.0, 68.0), 0.9]]:
		var p: Vector2 = t[1]
		tree(t[0], on_ground(p.x, p.y), t[2])
	# The Japanese Garden: maples in three colours, pines leaning over the water, blossom by the tea house
	for t in [["maple_red", Vector2(-108.0, 130.0)], ["maple_red", Vector2(-84.0, 108.0)], ["maple_orange", Vector2(-120.0, 116.0)],
			["maple_gold", Vector2(-96.0, 134.0)], ["maple_red", Vector2(-70.0, 96.0)], ["pine", Vector2(-114.0, 122.0)],
			["pine", Vector2(-90.0, 113.0)], ["pine", Vector2(-82.0, 86.0)], ["blossom", Vector2(-86.0, 133.0)],
			["blossom", Vector2(-98.0, 140.0)], ["blossom", Vector2(-124.0, 130.0)], ["maple_orange", Vector2(-100.0, 94.0)],
			["pine", Vector2(-76.0, 70.0)], ["maple_red", Vector2(-110.0, 108.5)]]:
		var p: Vector2 = t[1]
		if LAND.path_dist(p.x, p.y) < 1.5:
			p += Vector2(2.5, 0)
		tree(t[0], on_ground(p.x, p.y), _rng.randf_range(0.8, 1.0))


func blocks(at: Vector3) -> bool:
	for k in _keep:
		if Vector2(at.x, at.z).distance_to(Vector2(k.x, k.y)) < k.z:
			return true
	for t in trees:
		if Vector2(at.x, at.z).distance_to(Vector2(t.at.x, t.at.z)) < 2.0:
			return true
	return false


func wake(_k: float) -> void:
	pass


func step(_delta: float) -> void:
	for f in _koi:
		var o: Vector3 = f.get_meta("orbit")
		var a := o.z + _t * float(f.get_meta("speed"))
		var p := KOI_POND + Vector2(cos(a) * o.x, sin(a) * o.y)
		var nxt := KOI_POND + Vector2(cos(a + 0.05 * signf(float(f.get_meta("speed")))) * o.x, sin(a + 0.05 * signf(float(f.get_meta("speed")))) * o.y)
		f.position = Vector3(p.x, float(f.get_meta("y")) + sin(_t * 1.3 + o.z) * 0.05, p.y)
		var d := nxt - p
		f.rotation.y = atan2(d.x, d.y) + sin(_t * 6.0 + o.z) * 0.12
	for w in _falls:
		w.scale.x = 1.0 + sin(_t * 8.0 + w.position.x) * 0.05
