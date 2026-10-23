extends SceneTree

# Builds res://scenes/skate/test_park.tscn: a small practice park for trying out the skating (scenes/player/skate.gd)
# before it goes into town. A halfpipe, a big quarter pipe, a kicker, a funbox with ledges, flat rails, a ledge, and a
# platform with stairs and a handrail going down, on a big flat lavender slab under the green Galaxity sky.
# Logic: scripts/skate_test_park.gd. Rails and ledges are scripts/grind_rail.gd lines along their tops.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_skate_test.gd
#
# Play it from the editor (open the scene, F6) or straight from the command line:
#   godot --path "Godot Project/my-world" res://scenes/skate/test_park.tscn

const OUT := "res://scenes/skate/test_park.tscn"
const HALF := 45.0                                # the slab is 90 m across; a low wall round the edge

var world: Node3D
var mats := {}


func _initialize() -> void:
	world = Node3D.new()
	world.name = "SkateTestPark"
	world.set_script(load("res://scripts/skate_test_park.gd"))
	_environment()
	_ground()
	# The halfpipe: two quarter pipes facing each other across a 6 m flat bottom, east of the start
	quarter_pipe("Halfpipe East", Vector3(27, 0, -6), PI / 2, 12.0, 3.4, 78.0)
	quarter_pipe("Halfpipe West", Vector3(21, 0, -6), -PI / 2, 12.0, 3.4, 78.0)
	# One big quarter pipe across the north end
	quarter_pipe("North Quarter", Vector3(-4, 0, -30), PI, 26.0, 4.0, 78.0)
	# A low quarter pipe to learn on, in the west
	quarter_pipe("Little Quarter", Vector3(-33, 0, 8), -PI / 2, 10.0, 2.2, 65.0)
	kicker("Kicker", Vector3(-14, 0, 4), PI, 3.0, 1.1, 4.0)
	funbox("Funbox", Vector3(0, 0, -8))
	flat_rail("Flat Rail", Vector3(-9, 0, 16), Vector3(1, 0, 0), 10.0, 0.5)
	flat_rail("Long Rail", Vector3(10, 0, 2), Vector3(0, 0, 1), 14.0, 0.6)
	ledge("Ledge", Vector3(-20, 0, -12), Vector3(0, 0, 1), 10.0, 0.5)
	stairs_and_handrail("Stair Set", Vector3(-24, 0, 24))
	_signs()
	var start := Marker3D.new()
	start.name = "Start"
	start.position = Vector3(0, 1.0, 30)
	world.add_child(start)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = start.position
	world.add_child(player)
	_own(world)
	var scene := PackedScene.new()
	print("SAVED ", OUT, " pack=", scene.pack(world), " save=", ResourceSaver.save(scene, OUT))
	quit()


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = world
		if c.scene_file_path == "":
			_own(c)


# -----------------------------------------------------------------------------
# Little helpers
# -----------------------------------------------------------------------------
func mat(name: String, color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	mats[name] = m
	return m


func group(name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation.y = yaw
	world.add_child(g)
	return g


func box_at(size: Vector3, m: Material, pos: Vector3, parent: Node, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		parent.add_child(body)
	return mi


func tube(a: Vector3, b: Vector3, r: float, m: Material, parent: Node) -> void:
	# A round bar from a to b (rails and posts)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, up, side.cross(up)), (a + b) / 2)
	parent.add_child(mi)


func grind_line(name: String, points: Array, kind: String, parent: Node) -> GrindRail:
	var r := GrindRail.new()
	r.name = name
	r.kind = kind
	var c := Curve3D.new()
	for pt in points:
		c.add_point(pt)
	r.curve = c
	parent.add_child(r)
	return r


func prism(profile: PackedVector2Array, width: float, m: Material, parent: Node, smooth_top := 0) -> void:
	# Extrudes a side profile (points as (z, y), going round the outline) across x from -width/2 to width/2, with
	# both side caps, as one solid. The first smooth_top edges of the outline get smooth normals (a curved ramp face).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := profile.size()
	var centre := Vector2.ZERO
	for q in profile:
		centre += q
	centre /= n
	var hw := width / 2
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		var edge := p1 - p0
		var out := Vector2(edge.y, -edge.x).normalized()      # perpendicular to the edge
		if out.dot((p0 + p1) / 2 - centre) < 0.0:
			out = -out
		var n0 := Vector3(0, out.y, out.x)
		var n1 := n0
		if i < smooth_top:
			n0 = _smooth_normal(profile, i, centre)
			n1 = _smooth_normal(profile, i + 1, centre)
		var a := Vector3(-hw, p0.y, p0.x)
		var b := Vector3(hw, p0.y, p0.x)
		var c := Vector3(hw, p1.y, p1.x)
		var d := Vector3(-hw, p1.y, p1.x)
		_tri(st, a, b, c, n0, n0, n1, Vector3(0, out.y, out.x))
		_tri(st, a, c, d, n0, n1, n1, Vector3(0, out.y, out.x))
	var tris := Geometry2D.triangulate_polygon(profile)
	for side in [-1.0, 1.0]:
		var sn := Vector3(side, 0, 0)
		for k in range(0, tris.size(), 3):
			var q := [profile[tris[k]], profile[tris[k + 1]], profile[tris[k + 2]]]
			var v := []
			for pt in q:
				v.append(Vector3(side * hw, pt.y, pt.x))
			_tri(st, v[0], v[1], v[2], sn, sn, sn, sn)
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	parent.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


func _smooth_normal(profile: PackedVector2Array, i: int, centre: Vector2) -> Vector3:
	var n := profile.size()
	var prev := profile[(i - 1 + n) % n]
	var next := profile[(i + 1) % n]
	var t := (next - prev).normalized()
	var out := Vector2(t.y, -t.x)
	if out.dot(profile[i] - centre) < 0.0:
		out = -out
	return Vector3(0, out.y, out.x).normalized()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, face: Vector3) -> void:
	# Godot draws the side where the corners go clockwise, so swap two if they'd face inward
	if (b - a).cross(c - a).dot(face) > 0.0:
		var tmp := b
		b = c
		c = tmp
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


# -----------------------------------------------------------------------------
# The park
# -----------------------------------------------------------------------------
func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.6, 0.3)               # the same green midday sky as the town
	sky_mat.sky_horizon_color = Color(0.86, 0.93, 0.6)
	sky_mat.ground_horizon_color = Color(0.86, 0.93, 0.6)
	sky_mat.ground_bottom_color = Color(0.1, 0.04, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.75, 0.68, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, -35, 0)
	world.add_child(sun)


func _ground() -> void:
	var g := group("Ground", Vector3.ZERO)
	box_at(Vector3(HALF * 2, 1.0, HALF * 2), mat("Slab", Color(0.78, 0.74, 0.88), 0.85), Vector3(0, -0.5, 0), g)
	# Painted lines on the slab, just for looks
	var paint := mat("Paint", Color(0.98, 0.55, 0.85), 0.6)
	for k in 5:
		box_at(Vector3(0.25, 0.01, HALF * 2 - 4), paint, Vector3(-36 + k * 18, 0.005, 0), g, false)
	# A low wall round the edge so she can't roll off the world
	var wall := mat("Wall", Color(0.55, 0.45, 0.75), 0.8)
	for side in [-1, 1]:
		box_at(Vector3(HALF * 2, 1.2, 0.6), wall, Vector3(0, 0.6, side * HALF), g)
		box_at(Vector3(0.6, 1.2, HALF * 2), wall, Vector3(side * HALF, 0.6, 0), g)


func quarter_pipe(name: String, pos: Vector3, yaw: float, width: float, radius: float, top_deg: float) -> void:
	# A curved ramp rising toward its local +Z, with a flat deck at the top and a metal coping along the lip (which
	# is grindable). Turned by yaw: 0 rises toward +Z (south), PI toward north, PI/2 toward east.
	var g := group(name, pos, yaw)
	var profile := PackedVector2Array()
	var steps := 14
	for k in steps + 1:
		var a := deg_to_rad(top_deg) * k / steps
		profile.append(Vector2(radius * sin(a), radius * (1.0 - cos(a))))
	var top := profile[steps]
	var deck := 2.0
	profile.append(Vector2(top.x + deck, top.y))
	profile.append(Vector2(top.x + deck, 0.0))
	prism(profile, width, mat("Ramp", Color(0.45, 0.85, 0.85), 0.55), g, steps)
	tube(Vector3(-width / 2, top.y, top.x), Vector3(width / 2, top.y, top.x), 0.06, mat("Coping", Color(0.95, 0.4, 0.75), 0.25, 0.8), g)
	grind_line("Coping", [Vector3(-width / 2 + 0.3, top.y + 0.04, top.x), Vector3(width / 2 - 0.3, top.y + 0.04, top.x)], "rail", g)


func kicker(name: String, pos: Vector3, yaw: float, length: float, height: float, width: float) -> void:
	# A straight launch ramp, rising toward local +Z
	var g := group(name, pos, yaw)
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(length, height), Vector2(length, 0)])
	prism(profile, width, mat("Kicker", Color(0.98, 0.75, 0.4), 0.6), g)


func funbox(name: String, pos: Vector3) -> void:
	# A flat-topped box with a ramp up each end (along Z) and a ledge along each long side to grind
	var g := group(name, pos)
	var h := 0.9
	var top := 4.0
	var ramp := 2.6
	var profile := PackedVector2Array([Vector2(-top / 2 - ramp, 0), Vector2(-top / 2, h), Vector2(top / 2, h),
		Vector2(top / 2 + ramp, 0)])
	var w := 5.0
	prism(profile, w, mat("Funbox", Color(0.8, 0.55, 0.95), 0.6), g)
	var edge := mat("Ledge Edge", Color(0.95, 0.9, 0.6), 0.4, 0.5)
	for side in [-1, 1]:
		var x: float = side * (w / 2 - 0.05)
		tube(Vector3(x, h, -top / 2), Vector3(x, h, top / 2), 0.05, edge, g)
		grind_line("Edge " + ("East" if side > 0 else "West"), [Vector3(x, h + 0.03, -top / 2), Vector3(x, h + 0.03, top / 2)], "ledge", g)
	# A rail down the middle of the top
	var rail := mat("Rail", Color(0.7, 1.0, 0.45), 0.25, 0.8)
	tube(Vector3(0, h + 0.45, -top / 2 - 1.0), Vector3(0, h + 0.45, top / 2 + 1.0), 0.05, rail, g)
	for z in [-top / 2, top / 2]:
		tube(Vector3(0, h, z), Vector3(0, h + 0.45, z), 0.04, rail, g)
	grind_line("Top Rail", [Vector3(0, h + 0.5, -top / 2 - 1.0), Vector3(0, h + 0.5, top / 2 + 1.0)], "rail", g)


func flat_rail(name: String, pos: Vector3, along: Vector3, length: float, height: float) -> void:
	var g := group(name, pos)
	var rail := mat("Rail", Color(0.7, 1.0, 0.45), 0.25, 0.8)
	var a := -along * length / 2 + Vector3.UP * height
	var b := along * length / 2 + Vector3.UP * height
	tube(a, b, 0.05, rail, g)
	var posts := int(length / 2.5) + 1
	for k in posts:
		var at := a.lerp(b, float(k) / (posts - 1))
		tube(Vector3(at.x, 0, at.z), at, 0.04, rail, g)
	grind_line("Rail", [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05], "rail", g)


func ledge(name: String, pos: Vector3, along: Vector3, length: float, height: float) -> void:
	# A long low concrete block, grindable along both top edges
	var g := group(name, pos)
	var w := 1.0
	var size := Vector3(w, height, length) if along.z != 0.0 else Vector3(length, height, w)
	box_at(size, mat("Ledge", Color(0.62, 0.6, 0.72), 0.8), Vector3(0, height / 2, 0), g)
	var side_dir := Vector3(1, 0, 0) if along.z != 0.0 else Vector3(0, 0, 1)
	var edge := mat("Ledge Edge", Color(0.95, 0.9, 0.6), 0.4, 0.5)
	for side in [-1, 1]:
		var off: Vector3 = side_dir * side * (w / 2 - 0.05) + Vector3.UP * height
		tube(off - along * length / 2, off + along * length / 2, 0.04, edge, g)
		grind_line("Edge " + ("A" if side < 0 else "B"), [off - along * length / 2 + Vector3.UP * 0.03, off + along * length / 2 + Vector3.UP * 0.03], "ledge", g)


func stairs_and_handrail(name: String, pos: Vector3) -> void:
	# A platform you ride up to by a bank, four steps down the far side, and a handrail down the steps
	var g := group(name, pos)
	var h := 1.6
	var concrete := mat("Concrete", Color(0.68, 0.64, 0.8), 0.85)
	box_at(Vector3(8, h, 6), concrete, Vector3(0, h / 2, -3), g)              # the platform, z from -6 to 0
	# The bank up to it from the north
	prism(PackedVector2Array([Vector2(-6 - 4.0, 0), Vector2(-6, h), Vector2(-6, 0)]), 8.0, concrete, g)
	# Steps down to the south, from z = 0 to 2.4
	var steps := 4
	for k in steps:
		var top := h * (steps - k - 0.5) / steps
		box_at(Vector3(8, top, 0.6), concrete, Vector3(0, top / 2, 0.3 + k * 0.6), g)
	var rail := mat("Rail", Color(0.7, 1.0, 0.45), 0.25, 0.8)
	for x in [-3.2, 3.2]:
		var a := Vector3(x, h + 0.75, -1.0)
		var b := Vector3(x, h + 0.75, 0.0)
		var c := Vector3(x, 0.75, 2.4 + 1.0)
		tube(a, b, 0.05, rail, g)
		tube(b, c, 0.05, rail, g)
		for z in [-1.0, 2.4 + 1.0]:
			tube(Vector3(x, h if z < 0.0 else 0.0, z), Vector3(x, (h + 0.75) if z < 0.0 else 0.75, z), 0.04, rail, g)
		grind_line("Handrail " + ("East" if x > 0.0 else "West"), [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, c + Vector3.UP * 0.05], "rail", g)


func _signs() -> void:
	var s := Label3D.new()
	s.name = "Welcome"
	s.text = "Practice Park\nHold Jump to crouch, let go to ollie\nGrind near rails and ledges\nLeft and right to spin in the air"
	s.font_size = 64
	s.pixel_size = 0.006
	s.outline_size = 14
	s.modulate = Color(1.0, 0.95, 0.75)
	s.position = Vector3(8, 2.6, 25)                    # beside the start, turned toward it
	s.rotation.y = atan2(-8.0, 5.0)
	world.add_child(s)
