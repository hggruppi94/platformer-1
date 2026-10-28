class_name EdgeRails
extends RefCounted

# Any edge can be ground, like in Tony Hawk's: the top edges of every solid box in a scene (benches, walls, steps,
# ledges, planters, tables, stall counters, roofs, the plaza's kerb) and the rims of round tops (fountains, flower
# beds, pots) are made into grind lines (scripts/grind_rail.gd) when someone first rides there (scenes/player/skate.gd).
# They're invisible: the edge itself is what she grinds.
#
# Left out: things that move or are people (only StaticBody3D shapes count), tilted boxes (their top isn't flat),
# boxes taller than WALL_MAX (the invisible walls round the world) and edges shorter than MIN_EDGE.

const MIN_EDGE := 0.8                 # metres: shorter edges aren't worth grinding
const WALL_MAX := 12.0                # boxes taller than this are the world's invisible walls
const MAX_SIZE := 60.0                # ...or wider than this (the ground under everything)
const LIFT := 0.03                    # the line sits just above the edge, where the trucks touch


static func add_to(scene: Node) -> int:
	# Adds the scene's edges once (under an "EdgeRails" node) and returns how many lines it made
	if scene == null or scene.get_node_or_null("EdgeRails"):
		return 0
	var holder := Node3D.new()
	holder.name = "EdgeRails"
	scene.add_child(holder)
	var made := 0
	for node in scene.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.disabled or not cs.get_parent() is StaticBody3D or not cs.is_visible_in_tree():
			continue
		var t := cs.global_transform
		if t.basis.y.normalized().dot(Vector3.UP) < 0.97:
			continue                                          # tilted: no flat top to have edges
		if cs.shape is BoxShape3D:
			made += _box(holder, t, (cs.shape as BoxShape3D).size)
		elif cs.shape is CylinderShape3D:
			var c := cs.shape as CylinderShape3D
			made += _rim(holder, t, c.radius, c.height)
	return made


static func _box(holder: Node3D, t: Transform3D, size: Vector3) -> int:
	var s := t.basis.get_scale()
	var full := size * s
	if full.y > WALL_MAX or full.x > MAX_SIZE or full.z > MAX_SIZE:
		return 0
	var h := size / 2.0
	var corners := [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var made := 0
	for k in 4:
		var a: Vector3 = t * corners[k]
		var b: Vector3 = t * corners[(k + 1) % 4]
		if a.distance_to(b) >= MIN_EDGE:
			_line(holder, [a, b])
			made += 1
	return made


static func _rim(holder: Node3D, t: Transform3D, radius: float, height: float) -> int:
	# The round edge of a cylinder's top, as a ring of short straight runs (closed by repeating the first point)
	var r := radius * t.basis.get_scale().x
	if r < 0.4 or r > MAX_SIZE / 2.0 or height * t.basis.get_scale().y > WALL_MAX:
		return 0
	var steps := clampi(int(r * 6.0), 12, 64)
	var pts := []
	for k in steps + 1:
		var a := TAU * k / steps
		pts.append(t * Vector3(cos(a) * radius, height / 2.0, sin(a) * radius))
	_line(holder, pts)
	return 1


static func _line(holder: Node3D, pts: Array) -> void:
	var r := GrindRail.new()
	r.kind = "ledge"
	var c := Curve3D.new()
	for p in pts:
		c.add_point(p + Vector3.UP * LIFT)
	r.curve = c
	holder.add_child(r)
