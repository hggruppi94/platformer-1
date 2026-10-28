class_name SkateKit
extends RefCounted

# Skate park pieces for the builders: quarter pipes, kickers, funboxes, rails, ledges and a stair set with a handrail.
# Each piece is solid (it gets collision) and its rails and edges are grindable (scripts/grind_rail.gd lines along
# their tops, for scenes/player/skate.gd). Used by tools/build_skate_test.gd (the Practice Park) and
# tools/build_town.gd (the town's Skate Park).
#
# Pieces go under a parent node at a position and turn (yaw). Their colours come from mat_fn(name, colour, roughness,
# metallic), so a builder can pass its own (the town's runs everything through its alien palette).

const COLORS := {
	"Ramp": Color(0.45, 0.85, 0.85), "Coping": Color(0.95, 0.4, 0.75), "Kicker": Color(0.98, 0.75, 0.4),
	"Funbox": Color(0.8, 0.55, 0.95), "Ledge": Color(0.62, 0.6, 0.72), "Ledge Edge": Color(0.95, 0.9, 0.6),
	"Rail": Color(0.7, 1.0, 0.45), "Concrete": Color(0.68, 0.64, 0.8),
}

var mat_fn: Callable
var _mats := {}


func _init(material_fn := Callable()) -> void:
	mat_fn = material_fn


func mat(name: String, rough := 0.7, metal := 0.0) -> Material:
	var color: Color = COLORS[name]
	if mat_fn.is_valid():
		return mat_fn.call(name, color, rough, metal)
	if not _mats.has(name):
		var m := StandardMaterial3D.new()
		m.resource_name = name
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[name] = m
	return _mats[name]


func group(parent: Node, name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation.y = yaw
	parent.add_child(g)
	return g


# -----------------------------------------------------------------------------
# The pieces
# -----------------------------------------------------------------------------
func quarter_pipe(parent: Node, name: String, pos: Vector3, yaw: float, width: float, radius: float, top_deg: float,
		deck := 2.0) -> Node3D:
	# A curved ramp rising toward its local +Z, with a flat deck at the top and a metal coping along the lip (which
	# is grindable). Turned by yaw: 0 rises toward +Z (south), PI toward north, PI/2 toward east. Steep near the top
	# (75 degrees or more) so she goes straight up off it into a vert air.
	var g := group(parent, name, pos, yaw)
	var profile := PackedVector2Array()
	var steps := 14
	for k in steps + 1:
		var a := deg_to_rad(top_deg) * k / steps
		profile.append(Vector2(radius * sin(a), radius * (1.0 - cos(a))))
	var top := profile[steps]
	profile.append(Vector2(top.x + deck, top.y))
	profile.append(Vector2(top.x + deck, 0.0))
	prism(profile, width, mat("Ramp", 0.55), g, steps)
	tube(Vector3(-width / 2, top.y, top.x), Vector3(width / 2, top.y, top.x), 0.06, mat("Coping", 0.25, 0.8), g)
	grind_line("Coping", [Vector3(-width / 2 + 0.3, top.y + 0.04, top.x), Vector3(width / 2 - 0.3, top.y + 0.04, top.x)], "rail", g)
	return g


func kicker(parent: Node, name: String, pos: Vector3, yaw: float, length: float, height: float, width: float) -> Node3D:
	# A straight launch ramp, rising toward local +Z
	var g := group(parent, name, pos, yaw)
	prism(PackedVector2Array([Vector2(0, 0), Vector2(length, height), Vector2(length, 0)]), width, mat("Kicker", 0.6), g)
	return g


func funbox(parent: Node, name: String, pos: Vector3, yaw := 0.0) -> Node3D:
	# A flat-topped box with a ramp up each end (along local Z), a grindable edge along each long side, and a rail
	# down the middle of the top
	var g := group(parent, name, pos, yaw)
	var h := 0.9
	var top := 4.0
	var ramp := 2.6
	var w := 5.0
	prism(PackedVector2Array([Vector2(-top / 2 - ramp, 0), Vector2(-top / 2, h), Vector2(top / 2, h),
		Vector2(top / 2 + ramp, 0)]), w, mat("Funbox", 0.6), g)
	var edge := mat("Ledge Edge", 0.4, 0.5)
	for side in [-1, 1]:
		var x: float = side * (w / 2 - 0.05)
		tube(Vector3(x, h, -top / 2), Vector3(x, h, top / 2), 0.05, edge, g)
		grind_line("Edge " + ("East" if side > 0 else "West"), [Vector3(x, h + 0.03, -top / 2), Vector3(x, h + 0.03, top / 2)], "ledge", g)
	var rail := mat("Rail", 0.25, 0.8)
	tube(Vector3(0, h + 0.45, -top / 2 - 1.0), Vector3(0, h + 0.45, top / 2 + 1.0), 0.05, rail, g)
	for z in [-top / 2, top / 2]:
		tube(Vector3(0, h, z), Vector3(0, h + 0.45, z), 0.04, rail, g)
	grind_line("Top Rail", [Vector3(0, h + 0.5, -top / 2 - 1.0), Vector3(0, h + 0.5, top / 2 + 1.0)], "rail", g)
	return g


func flat_rail(parent: Node, name: String, pos: Vector3, along: Vector3, length: float, height: float) -> Node3D:
	var g := group(parent, name, pos)
	var rail := mat("Rail", 0.25, 0.8)
	var a := -along * length / 2 + Vector3.UP * height
	var b := along * length / 2 + Vector3.UP * height
	tube(a, b, 0.05, rail, g)
	var posts := int(length / 2.5) + 1
	for k in posts:
		var at := a.lerp(b, float(k) / (posts - 1))
		tube(Vector3(at.x, 0, at.z), at, 0.04, rail, g)
	grind_line("Rail", [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05], "rail", g)
	return g


func ground_rail(parent: Node, name: String, ground_a: Vector3, ground_b: Vector3, height: float, ground_mid := Vector3.INF) -> Node3D:
	# A rail out in the world, from one spot on the ground to another (they needn't be level: it runs down a hill
	# with the ground), at this height above it, with a post at each end and in the middle. Positions are in the
	# parent's space.
	var g := group(parent, name, Vector3.ZERO)
	var rail := mat("Rail", 0.25, 0.8)
	var up := Vector3.UP * height
	var a := ground_a + up
	var b := ground_b + up
	tube(a, b, 0.05, rail, g)
	var mid := ground_mid if ground_mid != Vector3.INF else (ground_a + ground_b) / 2.0
	for foot in [ground_a, mid, ground_b]:
		var top: Vector3 = a.lerp(b, clampf((foot - ground_a).length() / maxf((ground_b - ground_a).length(), 0.01), 0.0, 1.0))
		tube(Vector3(top.x, foot.y - 0.2, top.z), top, 0.04, rail, g)
	grind_line("Rail", [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05], "rail", g)
	return g


func ledge(parent: Node, name: String, pos: Vector3, along: Vector3, length: float, height: float) -> Node3D:
	# A long low concrete block, grindable along both top edges
	var g := group(parent, name, pos)
	var w := 1.0
	var size := Vector3(w, height, length) if along.z != 0.0 else Vector3(length, height, w)
	box_at(size, mat("Ledge", 0.8), Vector3(0, height / 2, 0), g)
	var side_dir := Vector3(1, 0, 0) if along.z != 0.0 else Vector3(0, 0, 1)
	var edge := mat("Ledge Edge", 0.4, 0.5)
	for side in [-1, 1]:
		var off: Vector3 = side_dir * side * (w / 2 - 0.05) + Vector3.UP * height
		tube(off - along * length / 2, off + along * length / 2, 0.04, edge, g)
		grind_line("Edge " + ("A" if side < 0 else "B"), [off - along * length / 2 + Vector3.UP * 0.03, off + along * length / 2 + Vector3.UP * 0.03], "ledge", g)
	return g


func stairs_and_handrail(parent: Node, name: String, pos: Vector3) -> Node3D:
	# A platform you ride up to by a bank from the north, four steps down the south side, and a handrail down the steps
	# on each side
	var g := group(parent, name, pos)
	var h := 1.6
	var concrete := mat("Concrete", 0.85)
	box_at(Vector3(8, h, 6), concrete, Vector3(0, h / 2, -3), g)              # the platform, z from -6 to 0
	prism(PackedVector2Array([Vector2(-6 - 4.0, 0), Vector2(-6, h), Vector2(-6, 0)]), 8.0, concrete, g)
	var steps := 4
	for k in steps:
		var top := h * (steps - k - 0.5) / steps
		box_at(Vector3(8, top, 0.6), concrete, Vector3(0, top / 2, 0.3 + k * 0.6), g)
	var rail := mat("Rail", 0.25, 0.8)
	for x in [-3.2, 3.2]:
		var a := Vector3(x, h + 0.75, -1.0)
		var b := Vector3(x, h + 0.75, 0.0)
		var c := Vector3(x, 0.75, 2.4 + 1.0)
		tube(a, b, 0.05, rail, g)
		tube(b, c, 0.05, rail, g)
		for z in [-1.0, 2.4 + 1.0]:
			tube(Vector3(x, h if z < 0.0 else 0.0, z), Vector3(x, (h + 0.75) if z < 0.0 else 0.75, z), 0.04, rail, g)
		grind_line("Handrail " + ("East" if x > 0.0 else "West"), [a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, c + Vector3.UP * 0.05], "rail", g)
	return g


func skaters_corner(parent: Node, pos: Vector3) -> Node3D:
	# A glowing pad with a sign: stand on it and press Interact to swap who's skating (scripts/rider_select.gd)
	var g := group(parent, "Skaters Corner", pos)
	var pad := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.3
	c.bottom_radius = 1.4
	c.height = 0.08
	c.radial_segments = 32
	pad.mesh = c
	pad.material_override = mat("Coping", 0.4)
	pad.position = Vector3(0, 0.04, 0)
	g.add_child(pad)
	var label := Label3D.new()
	label.name = "Sign"
	label.text = "Skaters' Corner"
	label.font_size = 64
	label.pixel_size = 0.006
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.modulate = Color(1.0, 0.95, 0.75)
	label.position = Vector3(0, 2.6, 0)
	g.add_child(label)
	var area := Area3D.new()
	area.name = "RiderSelect"
	area.set_script(load("res://scripts/rider_select.gd"))
	area.position = Vector3(0, 1.0, 0)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.3
	shape.height = 2.0
	cs.shape = shape
	area.add_child(cs)
	g.add_child(area)
	return g


func lesson_pad(parent: Node, pos: Vector3) -> Node3D:
	# Another glowing pad, for Coach Rook's skate lesson (scripts/lesson_pad.gd, scripts/skate_lesson.gd). Rook stands
	# beside it while the lesson's on.
	var g := skaters_corner(parent, pos)
	g.name = "Lesson Pad"
	(g.get_node("Sign") as Label3D).text = "Skate Lessons"
	(g.get_node("RiderSelect") as Area3D).name = "Lesson"
	(g.get_node("Lesson") as Area3D).set_script(load("res://scripts/lesson_pad.gd"))
	return g


# -----------------------------------------------------------------------------
# Building blocks
# -----------------------------------------------------------------------------
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
	# A round bar from a to b (rails and posts), just for looks: grinding uses the grind lines
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
	# Which way round the outline goes says which side of every edge is outside. (Pointing away from the outline's
	# middle doesn't: on a quarter pipe's hollow curve that points into the ramp, and its faces came out inside out,
	# so the curve was invisible though she could still ride it.)
	var turn := _winding(profile)
	var hw := width / 2
	for i in n:
		var p0 := profile[i]
		var p1 := profile[(i + 1) % n]
		var edge := p1 - p0
		var out := Vector2(edge.y, -edge.x).normalized() * turn      # perpendicular to the edge, outward
		var n0 := Vector3(0, out.y, out.x)
		var n1 := n0
		if i < smooth_top:
			n0 = _smooth_normal(profile, i, turn)
			n1 = _smooth_normal(profile, i + 1, turn)
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


func _winding(profile: PackedVector2Array) -> float:
	# +1 if the outline goes round anticlockwise (in its own (z, y) plane), -1 if clockwise: the outside of each edge
	# is then on its right, or its left
	var area := 0.0
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		area += a.x * b.y - b.x * a.y
	return 1.0 if area > 0.0 else -1.0


func _smooth_normal(profile: PackedVector2Array, i: int, turn: float) -> Vector3:
	var n := profile.size()
	var prev := profile[(i - 1 + n) % n]
	var next := profile[(i + 1) % n]
	var t := (next - prev).normalized()
	var out := Vector2(t.y, -t.x) * turn
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
