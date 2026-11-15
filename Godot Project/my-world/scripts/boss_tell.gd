extends Node3D

# A boss's warning before it attacks, so every fight can be learnt: the boss glows, a gold "!" pops up over it, a
# rising wind-up sound plays, and a shape on the ground says what's coming and what to do about it. The same shape
# always means the same thing, in every fight:
#
#   "jump"  a ring on the ground as far as the attack will reach, filling in towards its edge: a ring is coming, jump it.
#   "dash"  a stripe of arrows from the boss the way it's about to charge: step out of the way.
#   "drop"  a shadow that grows where something's about to land: move off it.
#   "pull"  a ring of arrows pointing in: it's about to suck you in, jump to break free.
#
# The tell only ever starts EARLIER than the attack; it never changes when the attack comes, so a fight's timing and
# its tests are just as before. Settings > Assist > Early boss warnings starts them sooner (lead()).
#
# No class_name (tools run with --script compile class_name scripts before the autoloads exist): preload it.
#
#   const TELL := preload("res://scripts/boss_tell.gd")
#   TELL.warn(self, "jump", reach, colour, secs, {"visual": visual})

const NORMAL := 0.9           # seconds of warning before an attack
const EARLY := 1.6            # with Early boss warnings on
const GOLD := Color(1.0, 0.85, 0.25)
const SEGS := 48              # the ground marks are draped over the ground, felt at this many angles...
const RINGS := 6              # ...and this many rings out, so bumps and slopes never swallow them
const LIFT := 0.07            # how far over the ground they float
const HINTS := {
	"jump": "Ring on the ground? Jump!",
	"dash": "Arrows on the ground? Step aside!",
	"drop": "A shadow? Move off it!",
	"pull": "Arrows pointing in? Jump free!",
}

var kind := "jump"
var reach := 6.0
var colour := Color(1, 1, 1)
var secs := NORMAL
var follow: Node3D            # the ground mark keeps under this (x and z) while the warning lasts
var ground_y := NAN           # where the ground is; NAN: follow's own height
var dir := Vector3.FORWARD    # "dash": which way
var visual: Node3D            # what glows
var head := 3.0               # how high the "!" floats over follow
var _t := 0.0
var _mark: Node3D
var _mat: StandardMaterial3D
var _fill: MeshInstance3D
var _bang: Label3D
var _glow: StandardMaterial3D
var _glowed: Array = []       # [mesh, the overlay it had before]
var _spin := 0.0
var _heights := PackedFloat32Array()   # the ground's height under the mark (RINGS + 1 rings of SEGS), over our own
var _sampled_at := Vector3(INF, INF, INF)
var _edge: MeshInstance3D


static func lead() -> float:
	return EARLY if bool(Settings.get("boss_warn_early")) else NORMAL


static func warn(boss: Node3D, what: String, reach_m: float, col: Color, length := -1.0, opts := {}) -> Node3D:
	if boss == null or not boss.is_inside_tree():
		return null
	var t: Node3D = (load("res://scripts/boss_tell.gd") as GDScript).new()
	t.name = "BossTell"
	t.kind = what
	t.reach = reach_m
	t.colour = col
	t.secs = length if length > 0.0 else lead()
	t.follow = opts.get("follow", boss)
	t.ground_y = float(opts.get("ground_y", NAN))
	t.dir = opts.get("dir", -boss.global_basis.z)
	t.visual = opts.get("visual", boss.get_node_or_null("Visual"))
	t.head = float(opts.get("head", -1.0))
	if t.head < 0.0:
		t.head = t._top_of(t.visual if t.visual else boss, t.follow if t.follow else boss) + 0.8
	var parent := boss.get_parent() if boss.get_parent() else boss
	parent.add_child(t)
	t.global_position = opts.get("at", t._ground_spot())
	if opts.has("at"):
		t.follow = null
	boss.set_meta("boss_tell", t)
	return t


static func showing(boss: Node) -> bool:
	if boss == null or not boss.has_meta("boss_tell"):
		return false
	var t: Variant = boss.get_meta("boss_tell")
	if not is_instance_valid(t):                  # (check before "is": a freed one can't be asked what it is)
		return false
	return t is Node and (t as Node).is_inside_tree()


func _top_of(n: Node3D, base: Node3D) -> float:
	# How high the boss's top is over its feet, from its meshes: where the "!" floats
	var top := -INF
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if not g.is_visible_in_tree() or g.mesh == null:
			continue
		var box := g.global_transform * g.get_aabb()
		top = maxf(top, box.end.y)
	return clampf(top - base.global_position.y, 1.5, 30.0) if top > -INF else 3.0


func _ground_spot() -> Vector3:
	var at := follow.global_position if follow else global_position
	return Vector3(at.x, (at.y if is_nan(ground_y) else ground_y) + 0.06, at.z)


func _ready() -> void:
	add_to_group("boss_tells")
	_build_mark()
	_build_bang()
	_start_glow()
	Juice.blip("windup", 1.0 if secs <= NORMAL + 0.05 else 0.8, -4.0)
	if HINTS.has(kind) and not Dialogue.flags.has("tell_seen_" + kind):
		Dialogue.flags["tell_seen_" + kind] = true                 # the first time each shape's seen, say what to do
		Game.message(HINTS[kind])


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / secs, 0.0, 1.0)
	if follow and is_instance_valid(follow):
		global_position = _ground_spot()
	var pulse := 0.5 + 0.5 * sin(_t * TAU * (2.0 + 4.0 * k))
	if Settings.reduce_flashing:
		pulse = 0.6
	if _mat:
		_mat.albedo_color.a = lerpf(0.35, 0.95, pulse)
	if global_position.distance_to(_sampled_at) > 0.3:
		_sample()                                  # the ground under it changed: feel it again
	match kind:
		"jump":
			_drape_disc(_fill, maxf(0.05, reach * k))
		"drop":
			_drape_disc(_fill, maxf(0.05, reach * lerpf(0.3, 1.0, k)))
		"dash":
			if _mark:
				_mark.global_basis = Basis.looking_at(Vector3(dir.x, 0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.FORWARD)
				for i in _mark.get_child_count():
					var c := _mark.get_child(i) as Node3D
					c.position.z = -fposmod(float(i) * 1.6 + _t * 5.0, reach)
					c.position.y = _ground_under(c.global_position) - global_position.y
		"pull":
			if _mark:
				_spin -= delta * 1.5
				for c in _mark.get_children():
					var n := c as Node3D
					var a := float(n.get_meta("a")) + _spin
					var r := lerpf(reach, reach * 0.35, fmod(_t * 0.9 + float(n.get_index() % 2) * 0.5, 1.0))
					n.position = Vector3(sin(a), 0, cos(a)) * r
					n.rotation.y = a + PI
					n.position.y = _ground_under(n.global_position) - global_position.y
	if _bang:
		_bang.position.y = head + sin(_t * 9.0) * 0.12
		_bang.pixel_size = 0.012 * (1.0 + 0.25 * pulse)
		if follow and is_instance_valid(follow):
			_bang.global_position.y = follow.global_position.y + head + sin(_t * 9.0) * 0.12
	if _glow:
		_glow.emission_energy_multiplier = lerpf(0.4, 2.2, pulse) if not Settings.reduce_flashing else 1.0
	if _t >= secs:
		_end()


func _end() -> void:
	set_process(false)
	for g in _glowed:
		if is_instance_valid(g[0]):
			(g[0] as GeometryInstance3D).material_overlay = g[1]
	_glowed.clear()
	queue_free()


func _exit_tree() -> void:
	for g in _glowed:
		if is_instance_valid(g[0]):
			(g[0] as GeometryInstance3D).material_overlay = g[1]
	_glowed.clear()


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c, 0.8)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.render_priority = 2
	return m


func _flat(mesh: Mesh, m: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi


func _build_mark() -> void:
	_mark = Node3D.new()
	_mark.name = "Mark"
	add_child(_mark)
	_mat = _flat_mat(colour.lerp(GOLD, 0.35))
	match kind:
		"jump":
			# The edge: exactly as far as the ring will roll. Inside: a pale disc growing out to it. Both follow the
			# ground's bumps (_sample, _drape_ring, _drape_disc).
			_edge = _flat(ArrayMesh.new(), _mat)
			_edge.name = "Edge"
			_edge.set_meta("reach", reach)
			_mark.add_child(_edge)
			var fm := _flat_mat(colour)
			fm.albedo_color.a = 0.28
			_fill = _flat(ArrayMesh.new(), fm)
			_fill.name = "Fill"
			_mark.add_child(_fill)
		"drop":
			var sm := _flat_mat(Color(0.08, 0.04, 0.12))
			sm.albedo_color.a = 0.55
			_fill = _flat(ArrayMesh.new(), sm)
			_fill.name = "Shadow"
			_mark.add_child(_fill)
			_edge = _flat(ArrayMesh.new(), _mat)
			_edge.name = "Edge"
			_edge.set_meta("reach", reach)
			_mark.add_child(_edge)
		"dash":
			# Chevrons sliding along the way it'll charge, as far as it'll go
			var n := maxi(3, int(reach / 1.6))
			for i in n:
				var chev := PrismMesh.new()
				chev.size = Vector3(1.6, 0.9, 0.04)
				var c := _flat(chev, _mat)
				c.name = "Arrow %d" % i
				c.rotation = Vector3(-PI / 2.0, 0, 0)
				_mark.add_child(c)
		"pull":
			for i in 10:
				var chev := PrismMesh.new()
				chev.size = Vector3(1.2, 0.8, 0.04)
				var c := _flat(chev, _mat)
				c.name = "Arrow %d" % i
				var a := TAU * float(i) / 10.0
				c.set_meta("a", a)
				c.rotation = Vector3(-PI / 2.0, a + PI, 0)
				_mark.add_child(c)


func _build_bang() -> void:
	_bang = Label3D.new()
	_bang.name = "Bang"
	_bang.text = "!"
	_bang.font_size = 160
	_bang.outline_size = 36
	_bang.modulate = GOLD
	_bang.outline_modulate = Color(0.35, 0.1, 0.25)
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bang.no_depth_test = true
	_bang.pixel_size = 0.012
	_bang.position.y = head
	add_child(_bang)


func _start_glow() -> void:
	if visual == null or not is_instance_valid(visual):
		return
	_glow = StandardMaterial3D.new()
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = Color(colour.lerp(GOLD, 0.3), 0.35)
	_glow.emission_enabled = true
	_glow.emission = colour.lerp(GOLD, 0.3)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var g := mi as GeometryInstance3D
		if g.visible and g.material_overlay == null:
			_glowed.append([g, g.material_overlay])
			g.material_overlay = _glow


# -----------------------------------------------------------------------------
# Draping the marks over the ground
# -----------------------------------------------------------------------------
func _ground_under(at: Vector3) -> float:
	# The ground's height at (x, z): a ray down that only stops on still things (not people, enemies or bosses)
	if not is_inside_tree():
		return at.y
	var space := get_world_3d().direct_space_state
	var from := Vector3(at.x, global_position.y + 4.0, at.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0)
	q.collide_with_areas = false
	for i in 4:
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return global_position.y
		if hit.collider is StaticBody3D and not (hit.collider is AnimatableBody3D):
			return float(hit.position.y) + LIFT
		q.exclude = q.exclude + [(hit.collider as CollisionObject3D).get_rid()]
	return global_position.y


func _sample() -> void:
	# Feels the ground under the round marks (only the round ones need it: arrows feel their own spot)
	_sampled_at = global_position
	if kind != "jump" and kind != "drop":
		return
	_heights.resize((RINGS + 1) * SEGS)
	for ri in RINGS + 1:
		var r := reach * float(ri) / RINGS
		for si in SEGS:
			var a := TAU * float(si) / SEGS
			var p := global_position + Vector3(sin(a), 0, cos(a)) * r
			_heights[ri * SEGS + si] = _ground_under(p) - global_position.y
	_drape_ring(_edge, reach * (0.93 if kind == "jump" else 0.9), reach)


func _h(r: float, si: int) -> float:
	# The ground's height (over ours) r metres out at angle step si, between the rings felt
	if _heights.is_empty():
		return LIFT
	var f := clampf(r / maxf(reach, 0.01) * RINGS, 0.0, float(RINGS))
	var lo := int(floor(f))
	var hi := mini(lo + 1, RINGS)
	si = posmod(si, SEGS)
	return lerpf(_heights[lo * SEGS + si], _heights[hi * SEGS + si], f - lo)


func _drape_ring(mi: MeshInstance3D, inner: float, outer: float) -> void:
	if mi == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for si in SEGS:
		var a0 := TAU * float(si) / SEGS
		var a1 := TAU * float(si + 1) / SEGS
		var i0 := Vector3(sin(a0) * inner, _h(inner, si), cos(a0) * inner)
		var o0 := Vector3(sin(a0) * outer, _h(outer, si) + 0.02, cos(a0) * outer)
		var i1 := Vector3(sin(a1) * inner, _h(inner, si + 1), cos(a1) * inner)
		var o1 := Vector3(sin(a1) * outer, _h(outer, si + 1) + 0.02, cos(a1) * outer)
		for v in [i0, o0, o1, i0, o1, i1]:
			st.add_vertex(v)
	mi.mesh = st.commit()


func _drape_disc(mi: MeshInstance3D, r: float) -> void:
	# A disc of radius r lying on the ground, in a few rings so it bends over bumps
	if mi == null:
		return
	var steps := 4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in steps:
		var r0 := r * float(k) / steps
		var r1 := r * float(k + 1) / steps
		for si in SEGS:
			var a0 := TAU * float(si) / SEGS
			var a1 := TAU * float(si + 1) / SEGS
			var p00 := Vector3(sin(a0) * r0, _h(r0, si) - 0.01, cos(a0) * r0)
			var p01 := Vector3(sin(a1) * r0, _h(r0, si + 1) - 0.01, cos(a1) * r0)
			var p10 := Vector3(sin(a0) * r1, _h(r1, si) - 0.01, cos(a0) * r1)
			var p11 := Vector3(sin(a1) * r1, _h(r1, si + 1) - 0.01, cos(a1) * r1)
			for v in [p00, p10, p11, p00, p11, p01]:
				st.add_vertex(v)
	mi.mesh = st.commit()
