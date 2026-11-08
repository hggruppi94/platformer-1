class_name HairKit
extends RefCounted

# The new hairstyles for the creator's human kids (Hayden, 7 Nov 2026: "the top best 10 hair styles in video games for
# each gender"). Each is inspired by a kind of hair that game heroes are known for, not copied from any one of them.
# Unlike the older styles (scripts/hairstyles.gd, made of balls), these are sculpted from a shell over the scalp and
# tapered locks, so they read as hair: roots a shade darker than the tips, a soft sheen, real fringes.
#
# They're made round the human kids' head (tools/build_hero_bodies.py human_kid: the middle of the head at y 1.10,
# 0.25 wide, 0.27 tall and 0.23 deep each way from there, the face towards +z), then moved into Nina's space, which is
# where every hairstyle starts from (scripts/clothes.gd fits them to whoever wears it). So on a human kid they come out
# exactly as made, and on anyone else they stretch to their head the way the older styles do.
#
# Parts that stick up off the top (spikes, buns, a quiff) are marked "up", so a hat that covers the head tucks them
# away; an invisible ball marked "crown" says how big the hair is, so a hat sits on top of it.

const C := Vector3(0, 1.10, 0)          # the middle of the head
const R := Vector3(0.25, 0.27, 0.23)    # its size each way
# The human kids' head as clothes.gd measures it (skin above the neck: Clothes.fit_of(...).head_box), for moving the
# hair into Nina's space. Re-measure if tools/build_hero_bodies.py changes their heads (tools/test_hair.gd checks).
const HEAD_BOX := AABB(Vector3(-0.273376, 0.986, -0.23), Vector3(0.546752, 0.384, 0.46))

const GIRL := ["High ponytail", "Twin tails", "Space buns", "Long and straight", "Long braid", "Bob with bangs",
	"Pixie cut", "Big curls", "Afro puffs", "Side ponytail"]
const BOY := ["Hero spikes", "Swoop fringe", "Middle part", "Messy mop", "Quiff", "Faux-hawk", "Top knot", "Curly top",
	"Afro", "Buzz cut"]
# What each is inspired by, for the creator's little line under the name (kinds of hair, not anyone's own)
const ABOUT := {
	"High ponytail": "A tomb-raiding adventurer's swinging ponytail",
	"Twin tails": "Super long twin tails, like a pop star singer",
	"Space buns": "Two buns on top, like a street fighting champ",
	"Long and straight": "Long hair with straight bangs, like a fairy-tale princess",
	"Long braid": "One long braid down the back, like a hunter from the wilds",
	"Bob with bangs": "A neat bob with bangs, like a friendly island villager",
	"Pixie cut": "Short and choppy, like a space ranger",
	"Big curls": "Big bouncy curls, like a brave archer",
	"Afro puffs": "Two big puffs, round and fluffy",
	"Side ponytail": "A ponytail off to one side, like a water-type trainer",
	"Hero spikes": "Huge spiky hair, like a sword-swinging anime hero",
	"Swoop fringe": "A long fringe swept over one eye, like a moody fantasy hero",
	"Middle part": "Parted in the middle, like a green-tunic adventurer",
	"Messy mop": "A messy mop, like a treasure hunter's",
	"Quiff": "A big quiff at the front, like a speedy rock star",
	"Faux-hawk": "A spiky ridge down the middle, like a battle-royale champ",
	"Top knot": "Pulled back in a top knot, like a samurai",
	"Curly top": "Curls on top and short sides, like a web-slinging kid",
	"Afro": "A big round afro, like a funky racer",
	"Buzz cut": "Short and simple, like a space marine",
}


static func names() -> Array:
	return GIRL + BOY


static func build(name: String, color: Color, tie_color := Color(1.0, 0.5, 0.75)) -> Node3D:
	# The hairstyle, in Nina's space (as Hairstyles.build gives them), or null for an unknown name
	if not name in GIRL and not name in BOY:
		return null
	var g := Node3D.new()
	g.name = "Hairstyle"
	var hair := _hair_mat(color)
	var tie := _plain_mat(tie_color)
	match name:
		# ----- Girls -----
		"High ponytail":
			_cap(g, hair, 1.25, 1.0, 0.026)
			_swept_fringe(g, hair, 1, 4, 0.2)
			_sweep_back(g, hair, Vector3(0, 1.33, -0.19), 10)
			_tie(g, tie, Vector3(0, 1.33, -0.19), 0.038)
			_tail(g, hair, Vector3(0, 1.33, -0.21), [Vector3(0, 1.38, -0.32), Vector3(0, 1.2, -0.4), Vector3(0, 0.98, -0.36),
				Vector3(0, 0.78, -0.3)], 7, 0.055, 0.05)
			_crown(g, Vector3(0, 1.16, -0.03), 0.3)
		"Twin tails":
			_cap(g, hair, 1.24, 1.0, 0.024, true)
			_bangs(g, hair, 8, 1.12, 0.032)
			for s in [-1.0, 1.0]:
				var at := Vector3(s * 0.21, 1.31, -0.1)
				_tie(g, tie, at, 0.034)
				_tail(g, hair, at + Vector3(s * 0.02, 0, -0.01), [at + Vector3(s * 0.13, 0.03, -0.05),
					at + Vector3(s * 0.2, -0.15, -0.06), at + Vector3(s * 0.2, -0.4, -0.04), at + Vector3(s * 0.17, -0.68, -0.02)],
					5, 0.045, 0.045)
			_crown(g, Vector3(0, 1.16, -0.02), 0.3)
		"Space buns":
			_cap(g, hair, 1.24, 1.0, 0.024, true)
			_bangs(g, hair, 8, 1.13, 0.03)
			for s in [-1.0, 1.0]:
				_bun(g, hair, Vector3(s * 0.15, 1.39, -0.05), 0.085)
				_tie(g, tie, Vector3(s * 0.135, 1.33, -0.04), 0.03, true)
			_crown(g, Vector3(0, 1.16, -0.03), 0.3)
		"Long and straight":
			_cap(g, hair, 1.25, 1.0, 0.03, true)
			_bangs(g, hair, 9, 1.11, 0.034)
			_curtain(g, hair, 19, 0.7, 0.05, 0.0)
			for s in [-1.0, 1.0]:
				_side_lock(g, hair, s, 0.8)
			_crown(g, Vector3(0, 1.16, -0.03), 0.31)
		"Long braid":
			_cap(g, hair, 1.25, 1.03, 0.024)
			_swept_fringe(g, hair, -1, 3, 0.16)
			_braid(g, hair, tie, [Vector3(0, 1.14, -0.25), Vector3(0, 1.0, -0.29), Vector3(0, 0.84, -0.3), Vector3(0, 0.66, -0.28)])
			_crown(g, Vector3(0, 1.16, -0.03), 0.3)
		"Bob with bangs":
			_cap(g, hair, 1.24, 0.98, 0.04, true)
			_bangs(g, hair, 9, 1.12, 0.036)
			_curtain(g, hair, 18, 0.97, 0.056, 0.05, 72.0)
			_crown(g, Vector3(0, 1.15, -0.02), 0.32)
		"Pixie cut":
			_cap(g, hair, 1.26, 1.03, 0.03)
			_swept_fringe(g, hair, 1, 5, 0.1, 1.15)
			_tufts(g, hair, 9, 0.05, 11)
			_crown(g, Vector3(0, 1.18, -0.02), 0.29)
		"Big curls":
			_cap(g, hair, 1.25, 1.0, 0.04, true)
			_curl_fringe(g, hair)
			_curls_round(g, hair, 13, 0.84)
			_crown(g, Vector3(0, 1.15, -0.03), 0.34)
		"Afro puffs":
			_cap(g, hair, 1.24, 1.0, 0.024, true)
			for s in [-1.0, 1.0]:
				_puff(g, hair, Vector3(s * 0.29, 1.3, -0.06), 0.13, int(4 + s))
				_tie(g, tie, Vector3(s * 0.2, 1.28, -0.05), 0.032)
			_crown(g, Vector3(0, 1.16, -0.03), 0.3)
		"Side ponytail":
			_cap(g, hair, 1.25, 1.0, 0.026)
			_swept_fringe(g, hair, -1, 4, 0.18)
			var at := Vector3(0.22, 1.27, -0.12)
			_sweep_back(g, hair, at, 8)
			_tie(g, tie, at, 0.034)
			_tail(g, hair, at + Vector3(0.02, 0, 0), [at + Vector3(0.1, -0.02, -0.02), at + Vector3(0.13, -0.18, 0.03),
				at + Vector3(0.11, -0.38, 0.08), at + Vector3(0.06, -0.52, 0.12)], 6, 0.05, 0.05)
			_crown(g, Vector3(0, 1.16, -0.03), 0.3)
		# ----- Boys -----
		"Hero spikes":
			_cap(g, hair, 1.24, 1.02, 0.036)
			_spikes(g, hair, [[0, 60, 0.2], [35, 55, 0.2], [-35, 55, 0.2], [70, 45, 0.17], [-70, 45, 0.17], [110, 40, 0.18],
				[-110, 40, 0.18], [150, 35, 0.2], [-150, 35, 0.2], [180, 50, 0.21], [140, 65, 0.18], [-140, 65, 0.18],
				[90, 70, 0.16], [-90, 70, 0.16], [0, 85, 0.2]], 0.06)
			for k in 3:
				var x := (k - 1) * 0.08
				_lock(g, hair, [_on(x, 1.31, 0.03), _on(x * 1.2, 1.25, 0.05), Vector3(x * 1.4 + 0.02, 1.13, 0.27)], 0.05, 0.5,
					0.003, false, 1.0)
			_crown(g, Vector3(0, 1.22, -0.03), 0.34)
		"Swoop fringe":
			_cap(g, hair, 1.25, 1.02, 0.024)
			_tufts(g, hair, 6, 0.06, 5, true)
			for k in 5:
				var t := k / 4.0
				var x0 := lerpf(-0.17, 0.07, t)
				_lock(g, hair, [_on(x0 - 0.02, 1.36, 0.035), _on(x0 + 0.05, 1.31, 0.05), _on(x0 + 0.13, 1.2, 0.045),
					Vector3(x0 + 0.2, 1.08 - t * 0.02, 0.225)], 0.058 - t * 0.006, 0.42, 0.004, false, 1.0)
			_crown(g, Vector3(0, 1.17, -0.02), 0.3)
		"Middle part":
			_cap(g, hair, 1.25, 1.0, 0.028, true)
			for s in [-1.0, 1.0]:
				for k in 4:
					var x0: float = s * (0.015 + k * 0.03)
					_lock(g, hair, [_on(x0, 1.37 - k * 0.005, 0.03), _on(x0 + s * 0.08, 1.3, 0.05),
						_on(x0 + s * 0.15, 1.18, 0.04), _on(x0 + s * 0.2, 1.06, 0.03)], 0.05, 0.42, 0.006, false, 1.0)
			_curtain(g, hair, 15, 1.0, 0.045, 0.02, 80.0)
			_crown(g, Vector3(0, 1.16, -0.02), 0.31)
		"Messy mop":
			_cap(g, hair, 1.24, 1.0, 0.038)
			_tufts(g, hair, 18, 0.075, 3)
			for k in 5:
				var x := (k - 2) * 0.06
				_lock(g, hair, [_on(x, 1.33, 0.04), _on(x + 0.02, 1.25, 0.05), Vector3(x + 0.035 * sin(k * 2.0), 1.17, 0.255)],
					0.05, 0.5, 0.004, false, 1.0)
			_crown(g, Vector3(0, 1.18, -0.02), 0.33)
		"Quiff":
			_cap(g, hair, 1.25, 1.03, 0.024)
			for k in 6:
				var x := (k - 2.5) * 0.045
				var up := _up(_lock(g, hair, [_on(x, 1.25, 0.02), Vector3(x, 1.36, 0.23), Vector3(x * 0.9, 1.43, 0.15),
					Vector3(x * 0.8, 1.43, 0.02), Vector3(x * 0.7, 1.37, -0.1)], 0.06, 0.55, 0.01, false, 1.0))
				up.name = "Quiff %d" % k
			_crown(g, Vector3(0, 1.2, 0.0), 0.31)
		"Faux-hawk":
			_cap(g, hair, 1.25, 1.03, 0.014)
			for k in 7:
				var pitch := lerpf(55.0, 145.0, k / 6.0)       # from the forehead over the top to the back
				var root := _sph(0.0, pitch if pitch <= 90.0 else 180.0 - pitch, 0.02, pitch > 90.0)
				var n := (root - C).normalized()
				var tip := root + (n * 0.6 + Vector3(0, 0.6, 0.25)).normalized() * (0.15 - absf(k - 2.0) * 0.012)
				_up(_lock(g, hair, [root, root.lerp(tip, 0.5) + Vector3(0, 0.01, 0), tip], 0.06, 0.45, 0.002, false, 1.0,
					Vector3.RIGHT))
			_crown(g, Vector3(0, 1.2, -0.02), 0.3)
		"Top knot":
			_cap(g, hair, 1.25, 1.03, 0.022)
			for k in 7:
				var x := (k - 3) * 0.05
				_lock(g, hair, [_on(x, 1.25, 0.02), _on(x * 0.7, 1.35, 0.03), Vector3(x * 0.3, 1.39, -0.08)], 0.045, 0.4, 0.02,
					false, 1.0)
			_bun(g, hair, Vector3(0, 1.42, -0.12), 0.075)
			_tie(g, tie, Vector3(0, 1.37, -0.11), 0.03, true)
			_crown(g, Vector3(0, 1.17, -0.03), 0.3)
		"Curly top":
			_cap(g, hair, 1.25, 1.03, 0.012)
			_curly_top(g, hair, 15)
			_crown(g, Vector3(0, 1.22, -0.02), 0.31)
		"Afro":
			_cap(g, hair, 1.25, 1.0, 0.024)
			_afro(g, hair)
			_crown(g, Vector3(0, 1.24, -0.1), 0.4)
		"Buzz cut":
			_cap(g, _hair_mat(color.darkened(0.08)), 1.26, 1.03, 0.008)
	_to_nina(g)
	return g


# -----------------------------------------------------------------------------
# Building blocks (all in the human head's space)
# -----------------------------------------------------------------------------
static func _sph(yaw_deg: float, pitch_deg: float, out: float, back := false) -> Vector3:
	# A point on the head: yaw 0 straight ahead (+z), 90 their left (+x); pitch 90 the very top. out: how far off the
	# skin. back: measure from the back of the head (yaw 180) instead.
	var yaw := deg_to_rad(yaw_deg + (180.0 if back else 0.0))
	var pitch := deg_to_rad(pitch_deg)
	var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	return _surface(d, out)


static func _surface(d: Vector3, out: float) -> Vector3:
	d = d.normalized()
	var s := 1.0 / (d / R).length()
	return C + d * (s + out)


static func _on(x: float, y: float, out: float) -> Vector3:
	# The point on the front-and-top of the head at this x and height (out: how far off the skin)
	var u := clampf(x / R.x, -0.98, 0.98)
	var v := clampf((y - C.y) / R.y, -0.98, 0.98)
	var w := sqrt(maxf(1.0 - u * u - v * v, 0.0))
	return _surface(Vector3(u * R.x, v * R.y, w * R.z), out)


static func _cap(g: Node3D, m: Material, hairline: float, nape: float, thick: float, part := false) -> MeshInstance3D:
	# A shell of hair over the scalp, thick off the skin: down to the hairline over the face (a little lower at the
	# temples), to the nape at the back, behind the ears at the sides. part: a little parting line down the middle.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u := 64
	var v := 40
	var rows := []
	for j in v + 1:
		var pitch := lerpf(-PI / 2.0, PI / 2.0, j / float(v))
		var row := []
		for i in u + 1:
			var yaw := TAU * i / float(u)
			var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			var skin := _surface(d, 0.0)
			# Where the hair stops at this spot: the hairline at the front, the nape at the back, behind the ears
			var front := smoothstep(-0.1, 0.5, d.z)
			var temple := smoothstep(0.55, 0.9, absf(d.x))
			var stop := lerpf(nape, hairline - 0.1 * temple, front)
			var ear := smoothstep(0.75, 0.95, absf(d.x)) * smoothstep(-0.25, 0.1, d.z)    # tucked round the ears
			stop = maxf(stop, lerpf(stop, 1.17, ear))
			var keep := smoothstep(stop - 0.012, stop + 0.022, skin.y)
			var t := thick * (0.55 + 0.45 * smoothstep(0.85, 1.25, skin.y))              # fuller on top
			if part:
				t *= 1.0 - 0.5 * (1.0 - smoothstep(0.0, 0.05, absf(skin.x))) * smoothstep(0.05, 0.5, d.z + d.y)
			var out := lerpf(-0.03, t, keep)
			var p := _surface(d, out)
			row.append([p, keep])
		rows.append(row)
	for j in v:
		for i in u:
			var quad := [rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]]
			if quad.all(func(q: Array) -> bool: return q[1] < 0.01):
				continue                                   # all tucked inside the head: nothing to see
			for k in [0, 2, 1, 0, 3, 2]:
				var q: Array = quad[k]
				st.set_color(Color(1, 1, 1).darkened(0.12 - 0.12 * smoothstep(1.0, 1.35, (q[0] as Vector3).y)))
				st.add_vertex(q[0])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Cap"
	mi.mesh = st.commit()
	mi.material_override = m
	g.add_child(mi)
	return mi


static func _lock(g: Node3D, m: Material, ctrl: Array, r0: float, flat := 0.5, tip := 0.004, up := false,
		taper := 1.0, face: Variant = null) -> MeshInstance3D:
	# A tapered lock of hair through the control points (a smooth curve), wide at the root and pointed at the tip, flat
	# against the head (or facing face, a direction, if given). Roots are a shade darker than the tips.
	var pts := _smooth(ctrl, 6)
	var n := pts.size()
	var sides := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in n:
		var p: Vector3 = pts[i]
		var fwd: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var out: Vector3 = (face as Vector3) if face != null else (p - C).normalized()
		var side := fwd.cross(out).normalized()
		if side.length() < 0.5:
			side = fwd.cross(Vector3.UP).normalized()
		out = side.cross(fwd).normalized()
		var t := i / float(n - 1)
		var r := tip + (r0 - tip) * pow(1.0 - t, taper)
		if i == 0:
			r *= 0.8
		var ring := []
		for k in sides:
			var a := TAU * k / sides
			ring.append(p + side * cos(a) * r + out * sin(a) * r * flat)
		rings.append([ring, t])
	for i in n - 1:
		for k in sides:
			var k2 := (k + 1) % sides
			var a: Array = rings[i]
			var b: Array = rings[i + 1]
			var quad := [[a[0][k], a[1]], [a[0][k2], a[1]], [b[0][k2], b[1]], [b[0][k], b[1]]]
			for q in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				st.set_color(Color(1, 1, 1).darkened(0.18 * (1.0 - float(q[1]))))
				st.add_vertex(q[0])
	# A round root end
	var first: Array = rings[0][0]
	var mid := Vector3.ZERO
	for p in first:
		mid += p
	mid /= first.size()
	mid -= (pts[1] - pts[0]).normalized() * r0 * 0.4
	for k in sides:
		st.set_color(Color(1, 1, 1).darkened(0.18))
		st.add_vertex(mid)
		st.add_vertex(first[(k + 1) % sides])
		st.add_vertex(first[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Lock"
	mi.mesh = st.commit()
	mi.material_override = m
	g.add_child(mi)
	if up:
		_up(mi)
	return mi


static func _smooth(ctrl: Array, per: int) -> Array:
	# Catmull-Rom through the control points
	var pts: Array = ctrl.duplicate()
	var ext: Array = [pts[0] * 2.0 - pts[1]] + pts + [pts[-1] * 2.0 - pts[-2]]
	var out := []
	for i in range(1, ext.size() - 2):
		var p0: Vector3 = ext[i - 1]
		var p1: Vector3 = ext[i]
		var p2: Vector3 = ext[i + 1]
		var p3: Vector3 = ext[i + 2]
		for k in per:
			var t := k / float(per)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(pts[-1])
	return out


static func _ball(g: Node3D, m: Material, pos: Vector3, r: Vector3, up := false) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	var mi := MeshInstance3D.new()
	mi.name = "Ball"
	mi.mesh = s
	mi.material_override = m
	mi.position = pos
	mi.scale = r
	g.add_child(mi)
	if up:
		_up(mi)
	return mi


static func _up(mi: MeshInstance3D) -> MeshInstance3D:
	mi.set_meta("hair", "up")
	return mi


static func _crown(g: Node3D, at: Vector3, r: float) -> void:
	# How big the hair is, for a hat to sit on (scripts/clothes.gd _under_hat): an invisible ball
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.name = "Crown"
	mi.mesh = s
	mi.position = at
	mi.scale = Vector3(1.0, 0.75, 0.95)
	mi.visible = false
	mi.set_meta("hair", "crown")
	g.add_child(mi)


static func _tie(g: Node3D, m: Material, at: Vector3, r: float, up := false) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r * 0.55
	t.outer_radius = r
	var mi := MeshInstance3D.new()
	mi.name = "Tie"
	mi.mesh = t
	mi.material_override = m
	mi.position = at
	mi.look_at_from_position(at, at + (at - C).normalized(), Vector3.UP if absf((at - C).normalized().y) < 0.9 else Vector3.FORWARD)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	g.add_child(mi)
	if up:
		_up(mi)


static func _bangs(g: Node3D, m: Material, count: int, low: float, r: float) -> void:
	# Straight bangs: locks from the top of the head down over the forehead, cut straight across at low
	for k in count:
		var t := k / float(count - 1)
		var x := lerpf(-0.17, 0.17, t)
		var drop := low + 0.015 * pow(absf(t - 0.5) * 2.0, 2.0) * 3.0
		_lock(g, m, [_on(x * 0.6, 1.36, 0.03), _on(x * 0.95, 1.27, 0.05), Vector3(x, drop + 0.02, _on(x, drop + 0.02, 0.03).z)],
			r * 1.6, 0.3, r * 0.7, false, 0.5)


static func _swept_fringe(g: Node3D, m: Material, dir: float, count: int, reach: float, low := 1.2) -> void:
	# A fringe swept to one side (dir +1 their left, -1 their right), from a parting over the other eye
	for k in count:
		var t := k / float(maxi(count - 1, 1))
		var x0 := -dir * lerpf(0.12, 0.0, t)
		_lock(g, m, [_on(x0, 1.36, 0.03), _on(x0 + dir * reach * 0.4, 1.3, 0.05),
			_on(x0 + dir * reach, low + 0.03 * t, 0.04)], 0.055, 0.42, 0.005, false, 1.0)


static func _sweep_back(g: Node3D, m: Material, to: Vector3, count: int) -> void:
	# Locks combed from all round the hairline to a tie (under a ponytail), so the head isn't one smooth cap
	for k in count:
		var yaw := lerpf(-150.0, 150.0, k / float(count - 1))
		var root := _sph(yaw, 18.0 if absf(yaw) > 60.0 else 48.0, 0.028)
		var mid := C + ((root + to) / 2.0 - C).normalized() * ((root - C).length() + 0.02)
		_lock(g, m, [root, mid, to + (root - to).normalized() * 0.03], 0.05, 0.35, 0.02, false, 0.8)


static func _tail(g: Node3D, m: Material, root: Vector3, path: Array, count: int, r: float, spread: float) -> void:
	# A tail of hair (a ponytail or twin tail): several locks bunched at the tie and fanning a little as they fall
	for k in count:
		var a := TAU * k / count
		var off := Vector3(cos(a), 0, sin(a)) * spread
		var pts := [root]
		for i in path.size():
			var f := 0.35 + 0.65 * (i + 1) / float(path.size())
			pts.append((path[i] as Vector3) + off * f + Vector3(0, 0, 0))
		_lock(g, m, pts, r, 0.75, 0.004, false, 0.8, Vector3(cos(a), 0, sin(a)))


static func _curtain(g: Node3D, m: Material, count: int, bottom: float, r: float, curl: float, from_yaw := 62.0) -> void:
	# Hair falling all round the back and sides, from the crown to bottom (curl: the ends turn in under)
	for k in count:
		var t := k / float(count - 1)
		var yaw := lerpf(from_yaw, 360.0 - from_yaw, t)
		var top := _sph(yaw, 50, 0.03)
		var mid := _sph(yaw, 5, 0.05)
		var d := Vector3(mid.x - C.x, 0, mid.z - C.z).normalized()
		var low := Vector3(mid.x, bottom + 0.06, mid.z) + d * 0.04
		var end := Vector3(mid.x, bottom, mid.z) + d * (0.04 - curl) + Vector3(0, curl * 0.6, 0)
		_lock(g, m, [top, mid, low.lerp(mid, 0.4) + d * 0.02, low, end], r * 1.5, 0.3, r * 0.5, false, 0.4)


static func _side_lock(g: Node3D, m: Material, s: float, bottom: float) -> void:
	# A lock in front of each shoulder, framing the face
	_lock(g, m, [_sph(s * 70, 45, 0.03), _sph(s * 78, 5, 0.05), Vector3(s * 0.27, 1.0, 0.07), Vector3(s * 0.25, bottom, 0.1)],
		0.05, 0.45, 0.01, false, 0.5)


static func _tufts(g: Node3D, m: Material, count: int, size: float, seed: int, sides_only := false) -> void:
	# Short tufts all over (or round the sides and back), pointing out and down
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in count:
		var yaw := rng.randf_range(60.0, 300.0) if sides_only else rng.randf_range(-170.0, 170.0)
		var pitch := rng.randf_range(10.0, 45.0) if sides_only else rng.randf_range(15.0, 80.0)
		if absf(yaw) < 50.0 and pitch < 50.0:
			pitch = 55.0                                   # keep the face clear
		var root := _sph(yaw, pitch, 0.02)
		var n := (root - C).normalized()
		var tip := root + (n * 0.55 + Vector3(0, -0.6, 0) + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))).normalized() * size * rng.randf_range(0.8, 1.2)
		_lock(g, m, [root, root.lerp(tip, 0.5) + n * size * 0.25, tip], size * 0.65, 0.5, 0.003, false, 1.0)


static func _spikes(g: Node3D, m: Material, spots: Array, r: float) -> void:
	# Big pointed spikes: [yaw, pitch, length] each, pointing out from the head and swept up and back
	for s in spots:
		var root := _sph(float(s[0]), float(s[1]), 0.02)
		var n := (root - C).normalized()
		var tip := root + (n + Vector3(0, 0.55, -0.35)).normalized() * float(s[2])
		var bend := root.lerp(tip, 0.55) + Vector3(0, 0.02, -0.02)
		_lock(g, m, [root, bend, tip], r, 0.55, 0.002, float(s[1]) > 50.0, 1.0)


static func _bun(g: Node3D, m: Material, at: Vector3, r: float) -> void:
	# A bun: a ball wrapped round with a few locks
	_ball(g, m, at, Vector3(r, r * 0.9, r), true)
	for k in 3:
		var pts := []
		for i in 9:
			var a := TAU * (i / 8.0) * 0.85 + k * 2.1
			var y := lerpf(-0.6, 0.6, i / 8.0) * r * 0.7
			var rr := r * (1.02 - 0.25 * absf(y) / r)
			pts.append(at + Vector3(cos(a) * rr, y, sin(a) * rr))
		_lock(g, m, pts, r * 0.32, 0.55, r * 0.15, true, 0.6)


static func _braid(g: Node3D, m: Material, tie: Material, path: Array) -> void:
	# A braid: overlapping plaits alternating side to side along the path, a tie and a little tuft at the end
	var pts := _smooth(path, 4)
	var count := 13
	for k in count:
		var t := k / float(count - 1)
		var p: Vector3 = pts[int(t * (pts.size() - 1))]
		var w := lerpf(0.055, 0.035, t)
		var side := 1.0 if k % 2 == 0 else -1.0
		var b := _ball(g, m, p + Vector3(side * w * 0.35, 0, 0), Vector3(w, w * 1.25, w * 0.85))
		b.rotation.z = side * 0.5
	var end: Vector3 = pts[-1]
	_tie(g, tie, end + Vector3(0, -0.02, 0), 0.03)
	_lock(g, m, [end + Vector3(0, -0.03, 0), end + Vector3(0.01, -0.08, 0.01), end + Vector3(-0.005, -0.13, 0.02)], 0.04, 0.8,
		0.004, false, 1.0, Vector3.FORWARD)


static func _puff(g: Node3D, m: Material, at: Vector3, r: float, seed: int) -> void:
	# A round fluffy puff: a ball with bumps all over
	_ball(g, m, at, Vector3(r, r * 0.95, r))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for k in 22:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		_ball(g, m, at + d * r * 0.82, Vector3.ONE * r * rng.randf_range(0.3, 0.42))


static func _curl(g: Node3D, m: Material, root: Vector3, down: float, r: float, turns: float, outward: Vector3) -> void:
	# A springy ringlet: a helix hanging from root
	var pts := []
	var steps := int(turns * 8)
	for i in steps + 1:
		var t := i / float(steps)
		var a := TAU * turns * t
		var side := outward.cross(Vector3.UP).normalized()
		pts.append(root + outward * (r + cos(a) * r) * 0.9 + side * sin(a) * r + Vector3(0, -down * t, 0))
	_lock(g, m, pts, 0.04, 0.8, 0.016, false, 0.5)


static func _curls_round(g: Node3D, m: Material, count: int, bottom: float) -> void:
	for k in count:
		var t := k / float(count - 1)
		var yaw := lerpf(55.0, 305.0, t)
		var root := _sph(yaw, 18.0 + 10.0 * sin(k * 1.7), 0.035)
		var out := Vector3(root.x - C.x, 0, root.z - C.z).normalized()
		_curl(g, m, root, root.y - bottom - 0.04 * sin(k * 2.3), 0.042, 2.2, out)
	# and bumps of curls over the top
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for k in 16:
		var p := _sph(rng.randf_range(-160, 160), rng.randf_range(40, 85), 0.04)
		if p.z > 0.12 and p.y < 1.3:
			continue
		_ball(g, m, p, Vector3.ONE * rng.randf_range(0.045, 0.06))


static func _curl_fringe(g: Node3D, m: Material) -> void:
	for k in 5:
		var x := (k - 2) * 0.075
		var root := _on(x, 1.31, 0.035)
		_curl(g, m, root, 0.09, 0.022, 1.5, Vector3(0, 0.3, 1).normalized())


static func _curly_top(g: Node3D, m: Material, count: int) -> void:
	# Tight curls piled on top, short sides
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in count:
		var yaw := rng.randf_range(-150, 150)
		var pitch := rng.randf_range(48, 88)
		var p := _sph(yaw, pitch, 0.045)
		if absf(yaw) < 40.0 and pitch < 60.0:
			p = _sph(yaw, 62, 0.05)
		var r := rng.randf_range(0.05, 0.065)
		var b := _ball(g, m, p, Vector3(r, r * 0.85, r), true)
		b.name = "Curl"
		for j in 2:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 1), rng.randf_range(-1, 1)).normalized()
			_ball(g, m, p + d * r * 0.7, Vector3.ONE * r * 0.55, true)


static func _afro(g: Node3D, m: Material) -> void:
	# A big round afro: a full puff over the head, with bumps, leaving the face clear
	var at := C + Vector3(0, 0.14, -0.1)
	_ball(g, m, at, Vector3(0.36, 0.31, 0.31))
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 60:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1), rng.randf_range(-1, 0.75)).normalized()
		var p := at + d * Vector3(0.34, 0.29, 0.29)
		if p.z > 0.06 and p.y < 1.33:
			continue                                     # not over the face
		_ball(g, m, p, Vector3.ONE * rng.randf_range(0.06, 0.09))


static func _to_nina(g: Node3D) -> void:
	# From the human head's space to Nina's (where hairstyles start from): her head box to theirs, middle to middle
	var nina: AABB = Clothes._nina_fit().head_box
	var s := nina.size / HEAD_BOX.size
	g.transform = Transform3D(Basis.from_scale(s), nina.get_center() - HEAD_BOX.get_center() * s)


# -----------------------------------------------------------------------------
# Materials
# -----------------------------------------------------------------------------
static func _hair_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.5
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _plain_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.6
	return m
