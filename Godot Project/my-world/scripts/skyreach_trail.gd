extends "res://scripts/boss_lair.gd"

# The Skyreach Trail: the longest trail in the game, and the one big optional boss at the end of it (the "feels
# bigger" plan's slice 4; Hayden: "Go ahead", 15 Nov 2026). Its way in is a narrow cleft in the rocks at the very foot
# of the mountains, far north of the castle (Bosses.LAIRS "skyreach"), with a small sign you can only read up close and
# nothing on the map, so you find it by exploring. Nothing in the game mentions the Seraph until you're on the summit.
# Since 24 Nov 2026 it's heaven (Hayden): white marble and gold over a sea of clouds, and the boss is a biblical angel,
# the Seraph (scripts/starhorn.gd: its file, node and flag still say Starhorn, for saves and tests).
#
# Inside, a path winds one and a half times round a mountain on its way up (about 400 m and 36 m high): a flat meadow at
# the foot, then the trail with a cliff on the inside and a long drop on the outside (an unseen rail keeps you on it),
# four Waystones that light as you pass and are where you start again if you fall or faint, and at the top a round
# summit with the Seraph asleep in the middle (scripts/starhorn.gd), its three Star Shards and the treasure.
#
# The shape (all in this script, nothing in the .tscn): the trail's middle at angle a round the mountain's middle MID is
#   MID + (sin a * r, h, -cos a * r), a from 0 to TURNS, r from R0 to R1, h from 0 to TOP
# (h levels off for the last FLAT_END) so it starts on the meadow straight ahead of the way in, heading right. Every loop's inside cliff climbs to the next
# loop's outside edge, so the whole mountain is one surface. Cliffs and slopes are too steep to walk up and their body
# is named "Edge ..." so wall crawl leaves them alone (scripts/wall_crawl.gd): the trail is the only way up.

const STARHORN := preload("res://scripts/starhorn.gd")

const MID := Vector3(0, 0, 90)            # the mountain's middle, on the ground
const TURNS := 3.0 * PI                   # one and a half times round
const R0 := 60.0                          # how far out the trail starts...
const R1 := 31.0                          # ...and ends
const TOP := 36.0                         # the summit's height
const HALF := 3.0                         # half the trail's width
const FLAT_END := 0.3                     # the last bit of the trail (in radians round) is flat
const SAMPLES := 360
const SUMMIT_R := 27.0
const RAIL_H := 6.0                       # the unseen rail along the outside edge (higher than a double jump)
const STONES := [0.02, 0.8, 1.6, 2.4]     # the Waystones, as fractions of PI round the trail (the fifth is on top)
const FALL := 8.0                         # this far under the last Waystone and you float back to it
const STONE_REACH := 3.5

var stones: Array[Node3D] = []            # the Waystones in order, the summit's last
var stone_at := 0                         # the last one lit
var _fell_t := 0.0


func lair_id() -> String:
	return "skyreach"


func arena() -> Vector3:
	return MID + Vector3(0, TOP, 0)


func wake_range() -> float:
	return STARHORN.WAKE + 1.0               # (the Starhorn wakes itself at WAKE; the lair only lets it run first)


func treasure() -> int:
	return 25


# -----------------------------------------------------------------------------
# The trail's shape (static so tests can use it)
# -----------------------------------------------------------------------------
static func trail_r(a: float) -> float:
	return lerpf(R0, R1, a / TURNS)


static func trail_h(a: float) -> float:
	# (the last few metres are flat, so the path meets the summit's landing with no step: you can't step up on foot)
	return lerpf(0.0, TOP, minf(a / (TURNS - FLAT_END), 1.0))


static func trail_point(a: float) -> Vector3:
	var r := trail_r(a)
	return MID + Vector3(sin(a) * r, trail_h(a), -cos(a) * r)


static func out_dir(a: float) -> Vector3:
	return Vector3(sin(a), 0, -cos(a))


static func trail_length() -> float:
	var n := 0.0
	var last := trail_point(0.0)
	for i in range(1, SAMPLES + 1):
		var p := trail_point(TURNS * i / SAMPLES)
		n += p.distance_to(last)
		last = p
	return n


static func summit() -> Vector3:
	return MID + Vector3(0, TOP, 0)


func _enter_tree() -> void:
	super._enter_tree()
	# Back after a faint (the scene starts again): start at the last Waystone you lit, not right at the bottom
	var k := int(Bosses.get_meta("lair_resume", 0)) if Bosses.has_meta("lair_resume") else 0
	if k > 0:
		stone_at = k
		var p := get_node_or_null("Player") as Node3D
		if p:
			p.position = _stone_spot(k) + Vector3(0, 1.0, 0)
			p.rotation.y = 0.0


# -----------------------------------------------------------------------------
# Building it
# -----------------------------------------------------------------------------
func _build() -> void:
	# Heaven (24 Nov 2026, Hayden: "skyreach trail needs to be a more heavenly/cloudy place"): a clear blue sky
	# going gold at the horizon, a soft white haze, a warm sun, white marble and gold, and clouds everywhere: the
	# meadow at the foot is a floor of cloud and a sea of clouds lies all round (_heaven()).
	_environment(Color(0.36, 0.6, 0.95), Color(1.0, 0.93, 0.78), Color(0.97, 0.96, 1.0), Color(1.0, 0.97, 0.92), 0.004,
		Color(1.0, 0.95, 0.82))
	# (the sky's white below would light everything from all sides and wash it out, so the light from round about is
	# a soft blue and a touch dimmer, and the picture a little darker)
	var env := (get_node("Lair Sky") as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.76, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_exposure = 0.85
	env.fog_light_color = Color(0.86, 0.88, 0.95)
	env.fog_density = 0.0025
	_floor(Vector2(170, 200), Vector3(0, 0, 80), Color(0.84, 0.86, 0.92), Color(0.9, 0.89, 0.86), "Cloud Floor")
	_bounds(84.0, -6.0, 178.0)
	_trail()
	_mountain()
	_summit()
	_waystones()
	_scenery()
	_heaven()
	_sign(self, "The Skyreach Trail", Vector3(4.5, 0, 9), PI + 0.4, Color(0.92, 0.88, 0.78))
	_star_chest(summit() + Vector3(0, 0, -11))


func _make_boss() -> CharacterBody3D:
	var b: CharacterBody3D = STARHORN.new()
	b.name = "The Starhorn"
	b.position = summit()
	b.set("home", summit())
	return b


func _ready() -> void:
	super._ready()
	if is_instance_valid(boss):
		boss.call("make_shards", self, summit())


func _on_wake() -> void:
	pass


func _on_popped() -> void:
	pass


func _tri(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	# One triangle, wound so it faces along hint (Godot's front faces are clockwise: its normal is (c-a) x (b-a))
	var n := (c - a).cross(b - a)
	if n.dot(hint) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	n = n.normalized()
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)
		faces.append(v)


func _quad(st: SurfaceTool, faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	_tri(st, faces, a, b, c, hint)
	_tri(st, faces, a, c, d, hint)


func _body(name: String, faces: PackedVector3Array) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := _solid(self, name, shape, Vector3.ZERO)
	return body


func _surface(name: String, st: SurfaceTool, col: Color, rough := 0.9) -> MeshInstance3D:
	var m := _mat(name, col, rough)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)
	return mi


func _trail() -> void:
	# The path itself: a ribbon HALF either side of the middle line, its own body so it's the only thing you walk up
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in SAMPLES:
		var a0 := TURNS * i / SAMPLES
		var a1 := TURNS * (i + 1) / SAMPLES
		var p0 := trail_point(a0)
		var p1 := trail_point(a1)
		_quad(st, faces, p0 - out_dir(a0) * HALF, p0 + out_dir(a0) * HALF, p1 + out_dir(a1) * HALF,
			p1 - out_dir(a1) * HALF, Vector3.UP)
	# The last bit, a little landing turning in onto the summit
	var end := trail_point(TURNS)
	var land := [end + Vector3(-HALF, 0, HALF), end + Vector3(HALF, 0, HALF),
		Vector3(HALF, TOP, MID.z + SUMMIT_R - 1.0), Vector3(-HALF, TOP, MID.z + SUMMIT_R - 1.0)]
	_quad(st, faces, land[0], land[1], land[2], land[3], Vector3.UP)
	_surface("Trail Path", st, Color(0.9, 0.74, 0.45))
	_body("Trail Body", faces)
	# The unseen rail all along the outside, and across the trail's end (the path turns in onto the summit there)
	var rail := PackedVector3Array()
	var rst := SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SAMPLES:
		var a0 := TURNS * i / SAMPLES
		var a1 := TURNS * (i + 1) / SAMPLES
		var o0 := trail_point(a0) + out_dir(a0) * HALF
		var o1 := trail_point(a1) + out_dir(a1) * HALF
		_quad(rst, rail, o0 + Vector3(0, -1.0, 0), o1 + Vector3(0, -1.0, 0), o1 + Vector3(0, RAIL_H, 0),
			o0 + Vector3(0, RAIL_H, 0), -out_dir(a0))
	var e0 := end + Vector3(-HALF - 0.2, -1.0, -HALF - 3.0)
	var e1 := end + Vector3(-HALF - 0.2, -1.0, HALF + 0.5)
	_quad(rst, rail, e0, e1, e1 + Vector3(0, RAIL_H + 1.0, 0), e0 + Vector3(0, RAIL_H + 1.0, 0), Vector3.RIGHT)
	_body("Edge Trail Rail", rail)
	# Kerb stones along the outside edge, so you can see where the edge is
	var kerb := _mat("Kerb Stone", Color(0.86, 0.84, 0.8))
	var km := BoxMesh.new()
	km.size = Vector3(0.7, 0.45, 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = km
	var n := 0
	var spots: Array[Transform3D] = []
	var d := 0.0
	var last := trail_point(0.0)
	for i in range(1, SAMPLES + 1):
		var a := TURNS * i / SAMPLES
		var p := trail_point(a)
		d += p.distance_to(last)
		last = p
		if d >= 2.2:
			d = 0.0
			var t := Transform3D(Basis(Vector3.UP, -a), p + out_dir(a) * (HALF - 0.35) + Vector3(0, 0.2, 0))
			spots.append(t)
	mm.instance_count = spots.size()
	for t in spots:
		mm.set_instance_transform(n, t)
		n += 1
	var kerbs := MultiMeshInstance3D.new()
	kerbs.name = "Kerb Stones"
	kerbs.multimesh = mm
	kerbs.material_override = kerb
	add_child(kerbs)


func _cliff_top(a: float) -> Vector3:
	# Where this loop's inside cliff reaches: the next loop's outside edge, or the summit's edge once there's no loop
	# (never gentler than about 51 degrees: where that leaves room before the summit, a flat cap at the top fills it)
	var up := a + TAU
	if up <= TURNS:
		return trail_point(up) + out_dir(a) * HALF
	var rise := TOP - trail_h(a)
	var r := maxf(SUMMIT_R, trail_r(a) - HALF - rise / 1.25)
	return MID + out_dir(a) * r + Vector3(0, TOP, 0)


func _mountain() -> void:
	# The cliffs on the inside of the trail all the way up, and the slope from the outside edge down to the meadow
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in SAMPLES:
		var a0 := TURNS * i / SAMPLES
		var a1 := TURNS * (i + 1) / SAMPLES
		var in0 := trail_point(a0) - out_dir(a0) * HALF
		var in1 := trail_point(a1) - out_dir(a1) * HALF
		var t0 := _cliff_top(a0)
		var t1 := _cliff_top(a1)
		if t0.y < in0.y + 0.05 or t1.y < in1.y + 0.05:
			continue
		_quad(st, faces, in0, in1, t1, t0, out_dir(a0) + Vector3.UP * 0.3)
		if a0 + TAU > TURNS:
			var s0 := MID + out_dir(a0) * SUMMIT_R + Vector3(0, TOP, 0)
			var s1 := MID + out_dir(a1) * SUMMIT_R + Vector3(0, TOP, 0)
			if t0.distance_to(s0) > 0.05 or t1.distance_to(s1) > 0.05:
				_quad(st, faces, t0, t1, s1, s0, Vector3.UP)
	for i in SAMPLES:
		var a0 := TURNS * i / SAMPLES
		var a1 := TURNS * (i + 1) / SAMPLES
		if a0 >= TAU:
			break
		var o0 := trail_point(a0) + out_dir(a0) * HALF
		var o1 := trail_point(a1) + out_dir(a1) * HALF
		var g0 := Vector3(o0.x, 0, o0.z) + out_dir(a0) * (o0.y * 0.55 + 0.6)
		var g1 := Vector3(o1.x, 0, o1.z) + out_dir(a1) * (o1.y * 0.55 + 0.6)
		_quad(st, faces, o0, o1, g1 + Vector3(0, -0.3, 0), g0 + Vector3(0, -0.3, 0), out_dir(a0) + Vector3.UP * 0.3)
	_surface("Mountain Rock", st, Color(0.78, 0.76, 0.78))
	_body("Edge Mountain", faces)


func _summit() -> void:
	var top := summit()
	var grass := _mat("Summit Marble", Color(0.86, 0.84, 0.8))
	_cyl(self, "Summit", SUMMIT_R, SUMMIT_R + 2.0, 6.0, top + Vector3(0, -3.0, 0), grass)
	# A low ring of stones round the edge with an unseen wall over it, open where the trail comes in (+Z)
	var wall := Node3D.new()
	wall.name = "Summit Ring"
	add_child(wall)
	var marble := _mat("Heaven Marble", Color(0.88, 0.86, 0.82), 0.35)
	var gold := _mat("Heaven Gold", Color(1.0, 0.76, 0.32), 0.3, 0.2, 0.8)
	var gap := atan2(HALF + 0.8, SUMMIT_R)
	var k := 40
	for i in k:
		var a := TAU * (i + 0.5) / k
		var off := wrapf(a, -PI, PI)               # (its angle from the trail's way in at +Z)
		if absf(off) < gap:
			continue
		var at := top + Vector3(sin(a), 0, cos(a)) * (SUMMIT_R - 0.6)
		var bs := BoxShape3D.new()
		bs.size = Vector3(TAU * SUMMIT_R / k + 0.3, 8.0, 0.6)          # (down past the steep bit just under the top)
		var body := _solid(wall, "Edge Summit", bs, at + Vector3(0, -0.5, 0), Vector3(0, a, 0))
		body.name = "Edge Summit %d" % i
		if i % 2 == 0:
			# A ring of short white columns with gold caps round the edge, like an open temple in the clouds
			var h := 2.2 + (i % 3) * 0.5
			_cyl(wall, "Ring Column", 0.38, 0.45, h, at + Vector3(0, h * 0.5, 0), marble, false)
			_cyl(wall, "Ring Column Cap", 0.62, 0.5, 0.3, at + Vector3(0, h + 0.15, 0), gold, false)
			_cyl(wall, "Ring Column Foot", 0.6, 0.65, 0.3, at + Vector3(0, 0.15, 0), marble, false)
	# The Seraph's bed: a soft ring of gold moss and glowing flowers in the middle
	_cyl(self, "Star Bed", 6.5, 7.0, 0.1, top + Vector3(0, 0.03, 0), _mat("Star Moss", Color(1.0, 0.86, 0.5), 0.4, 0.5), false)
	var bloom := _mat("Star Bloom", Color(1.0, 0.92, 0.65), 0.5, 1.6)
	for i in 14:
		var a := TAU * i / 14.0
		_ball(self, "Star Bloom", 0.25, top + Vector3(sin(a) * 6.8, 0.25, cos(a) * 6.8), bloom, false)
	var light := OmniLight3D.new()
	light.name = "Summit Glow"
	light.light_color = Color(1.0, 0.9, 0.65)
	light.light_energy = 1.5
	light.omni_range = 26.0
	light.position = top + Vector3(0, 8, 0)
	add_child(light)


func _star_chest(at: Vector3) -> void:
	# A stone chest with a crystal lid, opening on a pile of starlight
	_chest = Node3D.new()
	_chest.name = "Star Chest"
	_chest.position = at
	add_child(_chest)
	_box(_chest, "Chest", Vector3(1.8, 1.0, 1.2), Vector3(0, 0.5, 0), _mat("Chest Stone", Color(0.86, 0.84, 0.8)))
	_box(_chest, "Band", Vector3(1.9, 0.14, 1.3), Vector3(0, 0.75, 0), _mat("Chest Gold", Color(0.95, 0.78, 0.35), 0.3, 0.3, 0.8), false)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 1.0, 0.6)                    # (hinged at the back)
	_chest.add_child(lid)
	_box(lid, "Crystal Lid", Vector3(1.8, 0.3, 1.2), Vector3(0, 0.15, -0.6), _mat("Chest Crystal", Color(0.6, 0.85, 1.0, 0.85), 0.2, 1.2), false)
	_ball(_chest, "Starlight", 0.5, Vector3(0, 0.95, 0), _mat("Chest Starlight", Color(1.0, 0.95, 0.7), 0.3, 2.0), false)
	_treasure(at)


func _open_look() -> void:
	var lid := _chest.get_node("Lid") as Node3D
	lid.create_tween().tween_property(lid, "rotation:x", 1.2, 0.5).set_trans(Tween.TRANS_BACK)
	Juice.blip("chime", 1.4, -3.0)


func _stone_spot(k: int) -> Vector3:
	if k >= STONES.size():
		return summit() + Vector3(0, 0, SUMMIT_R - 4.0)
	return trail_point(float(STONES[k]) * PI)


func _waystones() -> void:
	# Little standing stones with a lantern on top that lights as you go by: where you start again if you fall or faint
	for k in STONES.size() + 1:
		var spot := _stone_spot(k)
		var a := float(STONES[k]) * PI if k < STONES.size() else PI
		var at := spot - out_dir(a) * (HALF - 0.7) if k < STONES.size() else spot + Vector3(2.5, 0, 0)
		var g := Node3D.new()
		g.name = "Waystone %d" % (k + 1)
		g.position = at
		add_child(g)
		_cyl(g, "Stone", 0.3, 0.42, 1.6, Vector3(0, 0.8, 0), _mat("Waystone", Color(0.86, 0.84, 0.8)))
		var lamp := _ball(g, "Lamp", 0.28, Vector3(0, 1.85, 0), _mat("Waystone Dark", Color(0.3, 0.3, 0.4)), false)
		lamp.set_meta("lit_mat", _mat("Waystone Lit", Color(1.0, 0.85, 0.5), 0.4, 2.5))
		var l := OmniLight3D.new()
		l.name = "Glow"
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 1.2
		l.omni_range = 7.0
		l.position.y = 1.9
		l.visible = false
		g.add_child(l)
		g.set_meta("spot", spot)
		stones.append(g)
	for k in stone_at + 1:
		_light(k, false)


func _light(k: int, say := true) -> void:
	var g := stones[k]
	if bool(g.get_meta("lit", false)):
		return
	g.set_meta("lit", true)
	var lamp := g.get_node("Lamp") as MeshInstance3D
	lamp.material_override = lamp.get_meta("lit_mat")
	(g.get_node("Glow") as OmniLight3D).visible = true
	if say:
		stone_at = maxi(stone_at, k)
		Bosses.set_meta("lair_resume", stone_at)
		Juice.blip("chime", 1.2, -6.0)
		Fx.burst(self, g.global_position + Vector3(0, 1.9, 0), Color(1.0, 0.85, 0.5), 10, 0.06, 2.0, 1.0, 0.5)
		if k > 0:
			Game.message("Waystone lit. You'll start here if you fall.")


func _scenery() -> void:
	# White marble columns standing in the clouds round the foot (some broken, some leaning), gold crystals on the
	# cliffs, white and gold banners along the trail, and clouds drifting round the top
	var marble := _mat("Heaven Marble", Color(0.88, 0.86, 0.82), 0.35)
	var gold := _mat("Heaven Gold", Color(1.0, 0.76, 0.32), 0.3, 0.2, 0.8)
	var trunk := _mat("Gold Pole", Color(1.0, 0.76, 0.32), 0.3, 0.1, 0.8)
	for i in 22:
		var a := TAU * i / 22.0 + _rng.randf_range(-0.05, 0.05)
		var r := _rng.randf_range(72.0, 80.0)
		var at := MID + Vector3(sin(a) * r, 0, -cos(a) * r)
		if at.z < 20.0 and absf(at.x) < 14.0:
			continue                                      # (keep the clouds by the way in open)
		var g := Node3D.new()
		g.name = "Heaven Column"
		g.position = at
		add_child(g)
		var broken := i % 4 == 1
		var h := _rng.randf_range(2.5, 4.5) if broken else _rng.randf_range(7.0, 11.0)
		_cyl(g, "Column", 0.7, 0.8, h, Vector3(0, h * 0.5, 0), marble, false)
		_cyl(g, "Column Foot", 1.1, 1.2, 0.6, Vector3(0, 0.3, 0), marble, false)
		if not broken:
			_cyl(g, "Column Cap", 1.15, 0.85, 0.5, Vector3(0, h + 0.25, 0), gold, false)
		if i % 5 == 3:
			g.rotation.z = _rng.randf_range(-0.12, 0.12)
	var crystal := _mat("Cliff Crystal", Color(1.0, 0.88, 0.55), 0.3, 1.4)
	for i in 30:
		var a := _rng.randf_range(0.3, TURNS - 0.3)
		var bottom := trail_point(a) - out_dir(a) * HALF
		var t := _cliff_top(a)
		var at := bottom.lerp(t, _rng.randf_range(0.25, 0.8))
		var pm := PrismMesh.new()
		pm.size = Vector3(0.5, _rng.randf_range(0.8, 1.6), 0.5)
		var mi := _mesh(self, pm, at, crystal, false)
		mi.name = "Cliff Crystal"
		mi.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0, TAU), _rng.randf_range(-0.4, 0.4))
	var cols := [Color(1.0, 1.0, 1.0), Color(1.0, 0.85, 0.45), Color(0.75, 0.88, 1.0), Color(1.0, 0.92, 0.85), Color(1.0, 0.95, 0.7)]
	for f in 9:
		var a := TURNS * (f + 0.5) / 9.0
		var g := Node3D.new()
		g.name = "Flags %d" % (f + 1)
		add_child(g)
		var p0 := trail_point(a) - out_dir(a) * (HALF - 0.2) + Vector3(0, 3.4, 0)
		var p1 := trail_point(a) + out_dir(a) * (HALF - 0.2) + Vector3(0, 3.4, 0)
		for side in [p0, p1]:
			_cyl(g, "Flag Pole", 0.05, 0.06, 3.6, side - Vector3(0, 1.7, 0), trunk, false)
		for j in 7:
			var q: Vector3 = p0.lerp(p1, (j + 0.5) / 7.0) + Vector3(0, -0.25 - sin(PI * (j + 0.5) / 7.0) * 0.3, 0)
			var flag := BoxMesh.new()
			flag.size = Vector3(0.45, 0.5, 0.03)
			var mi := _mesh(g, flag, q, _mat("Flag %d" % (j % cols.size()), cols[j % cols.size()], 0.8), false)
			mi.rotation.y = -a + PI / 2
	var cloud := _mat("Cloud", Color(1.0, 1.0, 1.0, 0.92), 1.0)
	for i in 18:
		var c := Node3D.new()
		c.name = "Cloud %d" % i
		var a := TAU * i / 18.0
		c.position = MID + Vector3(sin(a) * 52.0, _rng.randf_range(14.0, 50.0), -cos(a) * 52.0)
		c.set_meta("a", a)
		c.set_meta("r", _rng.randf_range(44.0, 66.0))
		add_child(c)
		for j in 6:
			var mi := _ball(c, "Puff", _rng.randf_range(2.4, 4.2), Vector3(j * 2.8 - 7.0, _rng.randf_range(-0.6, 0.8),
				_rng.randf_range(-1.5, 1.5)), cloud, false)
			mi.scale = Vector3(1.0, 0.7, 1.0)
		c.add_to_group("skyreach_clouds")


func _heaven() -> void:
	# A sea of clouds all round the mountain (big flat white puffs, one MultiMesh, nothing solid): a ring hugging its
	# foot and a wide sea out past the walls to the horizon, so the meadow seems to float. Then soft beams of light
	# falling from the sky onto the summit and down the trail.
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 16
	puff.rings = 8
	var cloud := _mat("Cloud Sea", Color(0.97, 0.97, 1.0), 1.0)
	var spots: Array[Transform3D] = []
	for i in 70:                                          # round the mountain's foot
		var a := TAU * i / 70.0 + _rng.randf_range(-0.04, 0.04)
		var r := _rng.randf_range(R0 + 7.0, R0 + 15.0)
		var at := MID + Vector3(sin(a) * r, _rng.randf_range(-0.6, 0.4), -cos(a) * r)
		if at.z < 24.0 and absf(at.x) < 16.0:
			continue                                      # (the way in stays clear)
		var s := _rng.randf_range(3.5, 6.0)
		spots.append(Transform3D(Basis.from_scale(Vector3(s * 1.4, s * 0.45, s)).rotated(Vector3.UP, _rng.randf() * TAU), at))
	for i in 220:                                         # the sea out past the walls
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(100.0, 330.0)
		var at := MID + Vector3(sin(a) * r, _rng.randf_range(-6.0, 2.0) - r * 0.02, -cos(a) * r)
		var s := _rng.randf_range(8.0, 18.0) * (0.7 + r / 330.0)
		spots.append(Transform3D(Basis.from_scale(Vector3(s * 1.5, s * 0.4, s)).rotated(Vector3.UP, _rng.randf() * TAU), at))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = puff
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, spots[i])
	var sea := MultiMeshInstance3D.new()
	sea.name = "Cloud Sea"
	sea.multimesh = mm
	sea.material_override = cloud
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	sea.set_meta("count", spots.size())
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0, 0.9, 0.6, 0.045)
	var rays := Node3D.new()
	rays.name = "Heaven Light"
	add_child(rays)
	var spots_down := [summit(), trail_point(TURNS * 0.35), trail_point(TURNS * 0.7), MID + Vector3(0, 0, -40)]
	for k in spots_down.size():
		var at: Vector3 = spots_down[k]
		var wide := 14.0 if k == 0 else 7.0
		var cm := CylinderMesh.new()
		cm.top_radius = wide * 1.6
		cm.bottom_radius = wide
		cm.height = 90.0
		cm.cap_top = false
		cm.cap_bottom = false
		var mi := _mesh(rays, cm, at + Vector3(0, 45.0, 0), beam, false)
		mi.name = "Light Beam"
		mi.rotation.z = 0.12 if k % 2 == 0 else -0.1


# -----------------------------------------------------------------------------
# Every frame: the Waystones, falling off, the clouds
# -----------------------------------------------------------------------------
func _lair_step(delta: float) -> void:
	for c in get_tree().get_nodes_in_group("skyreach_clouds"):
		var n := c as Node3D
		var a := float(n.get_meta("a")) + delta * 0.01
		n.set_meta("a", a)
		var r := float(n.get_meta("r"))
		n.position = Vector3(MID.x + sin(a) * r, n.position.y, MID.z - cos(a) * r)
	var p := _player.global_position
	for k in stones.size():
		if k > stone_at or not bool(stones[k].get_meta("lit", false)):
			var spot: Vector3 = stones[k].get_meta("spot")
			if p.distance_to(spot + Vector3(0, 1.0, 0)) < STONE_REACH + HALF:
				_light(k)
	# Fell off (or slid down a cliff)? Float back up to the last Waystone
	var floor_y: float = (stones[stone_at].get_meta("spot") as Vector3).y
	if p.y < floor_y - FALL:
		_fell_t += delta
		if _fell_t > 0.25:
			_fell_t = 0.0
			back_to_stone()
	else:
		_fell_t = 0.0


func back_to_stone() -> void:
	var cb := _player as CharacterBody3D
	cb.global_position = _stone_spot(stone_at) + Vector3(0, 1.2, 0)
	cb.velocity = Vector3.ZERO
	Fx.burst(self, cb.global_position, Color(1.0, 0.85, 0.5), 12, 0.06, 2.0, 1.0, 0.5)
	Game.message("Whoops! Back to the Waystone.")


func go_home() -> void:
	if Bosses.has_meta("lair_resume"):
		Bosses.remove_meta("lair_resume")
	super.go_home()


func player_low() -> bool:
	return _player != null and _player.global_position.y < summit().y + 1.9
