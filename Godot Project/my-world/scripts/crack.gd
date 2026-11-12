extends RefCounted

# A crack in the ground, the way between worlds (Hayden, 12 Nov 2026, lore bible v2 part 3 item 1): "the cracks ARE
# the portals". The broken Shift splits the ground open, and the crack itself is the door: a jagged glowing hole you
# jump into. Nothing rises out of it. Used for every portal world's crack in the Void (scripts/portals.gd), the way
# home inside each world (scripts/portal_world.gd), the crack by the old oak on Earth (scripts/earth_world.gd) and the
# crack in the Void that goes back to Earth (scripts/portal.gd).
#
# make() builds the look (the hole's shaft, a glowing swirl at its bottom, jagged glowing lips and fissures running
# out over the ground) and the "Fall" area just inside the hole. sink() cuts the real ground away under it
# (scripts/ground_hole.gd), so the player truly drops in, and lays broken earth over the cut's ragged edge. The swirl
# at the bottom ("Swirl") is where a world's live preview shows (Portals._open_preview()): look down into a crack and
# you see the world it leads to. set_open() shuts or opens it: shut, a lid of cracked earth covers it (Earth's crack
# outside the Shift), and the fall area sleeps.
# No class_name on purpose (see scripts/use_spot.gd): load it with preload.

const HOLE := preload("res://scripts/ground_hole.gd")

const R := 1.4                       # the hole's radius
const DEPTH := 5.0                   # down to the swirl
const LIPS := 11                     # glowing jagged shards round the edge
const FISSURES := 7                  # glowing cracks running out over the ground
const RIM_SEGS := 36
const RIM_OUT := 1.4                 # the broken earth reaches at least this far past the hole


# The crack itself. `on_fall` is called when the player drops into it (and not while it's shut).
static func make(colour: Color, on_fall: Callable = Callable(), r := R) -> Node3D:
	var g := Node3D.new()
	g.set_meta("r", r)
	g.set_meta("colour", colour)
	g.set_meta("open", 1.0)
	var dark := _mat(Color(0.05, 0.03, 0.09), 0.9)
	var edge := _mat(colour, 0.3, 2.4)
	var rock := _mat(Color(0.12, 0.09, 0.16), 0.95, 0.0)
	rock.emission_enabled = true
	rock.emission = colour.darkened(0.6)
	rock.emission_energy_multiplier = 0.35
	# The shaft: a ring of rough rock walls going down, glowing faintly from below
	var shaft := Node3D.new()
	shaft.name = "Shaft"
	g.add_child(shaft)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	shaft.add_child(walls)
	var n := 18
	var mid := r + 0.25
	var seg := TAU * mid / n * 1.12
	for i in n:
		var a := i * TAU / n
		var jag := 0.12 * sin(i * 2.7)
		# (their tops stay just under the ground, so there's no lip to trip on at the edge)
		var t := Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * (mid + jag), -DEPTH * 0.5 - 0.06, sin(a) * (mid + jag)))
		_box(shaft, walls, Vector3(seg, DEPTH, 0.5), t, rock)
	_box(shaft, walls, Vector3(r * 2.0 + 1.0, 0.4, r * 2.0 + 1.0), Transform3D(Basis(), Vector3(0, -DEPTH - 0.2, 0)), dark)
	# The swirl at the bottom, colour of the world it leads to (the preview window shows here)
	var swirl := MeshInstance3D.new()
	swirl.name = "Swirl"
	var disc := CylinderMesh.new()
	disc.top_radius = r + 0.1
	disc.bottom_radius = r + 0.1
	disc.height = 0.04
	disc.radial_segments = 32
	swirl.mesh = disc
	var sm := _mat(colour.darkened(0.2), 0.2, 1.8)
	swirl.material_override = sm
	swirl.position.y = -DEPTH + 0.05
	g.add_child(swirl)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var cd := CylinderMesh.new()
	cd.top_radius = r * 0.45
	cd.bottom_radius = r * 0.45
	cd.height = 0.02
	core.mesh = cd
	core.material_override = _mat(colour.lightened(0.5), 0.2, 3.0)
	swirl.add_child(core)
	core.position = Vector3(0, 0.04, 0)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = colour
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.position.y = -1.2
	g.add_child(light)
	var up := OmniLight3D.new()
	up.name = "Deep Glow"
	up.light_color = colour
	up.light_energy = 1.6
	up.omni_range = 5.0
	up.position.y = -DEPTH + 1.0
	g.add_child(up)
	# Jagged glowing lips round the edge
	var lips := Node3D.new()
	lips.name = "Lips"
	g.add_child(lips)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in LIPS:
		var a := i * TAU / LIPS + rng.randf_range(-0.15, 0.15)
		var lip := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.5, 0.95), 0.07, 0.09)
		lip.mesh = b
		lip.material_override = edge
		lip.position = Vector3(cos(a) * (r + 0.02), 0.04, sin(a) * (r + 0.02))
		lip.rotation.y = -a + PI * 0.5 + rng.randf_range(-0.35, 0.35)
		lips.add_child(lip)
	# The lid: cracked earth that covers it while it's shut (set_open())
	var lid := StaticBody3D.new()
	lid.name = "Lid"
	g.add_child(lid)
	var lid_mesh := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = r + 0.15
	lc.bottom_radius = r + 0.15
	lc.height = 0.16
	lc.radial_segments = 24
	lid_mesh.mesh = lc
	lid_mesh.material_override = _mat(Color(0.2, 0.15, 0.13), 0.95)
	lid_mesh.position.y = -0.06
	lid.add_child(lid_mesh)
	for k in 3:                                    # a dark seam across the lid, glowing faintly
		var s := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(r * 1.9, 0.02, 0.08)
		s.mesh = sb
		s.material_override = _mat(colour.darkened(0.3), 0.4, 0.8)
		s.position = Vector3(0, 0.03, (k - 1) * 0.35)
		s.rotation.y = 0.4 * (k - 1) + 0.2
		lid.add_child(s)
	var lcs := CollisionShape3D.new()
	var lshape := CylinderShape3D.new()
	lshape.radius = r + 0.15
	lshape.height = 0.16
	lcs.shape = lshape
	lcs.position.y = -0.06
	lid.add_child(lcs)
	lid.visible = false
	lcs.disabled = true
	# Dropping in: just inside the hole, up to a little over the ground (so even where the ground couldn't be cut
	# away, stepping onto the crack's middle takes you through)
	var fall := Area3D.new()
	fall.name = "Fall"
	fall.monitorable = false
	var fcs := CollisionShape3D.new()
	var fshape := CylinderShape3D.new()
	fshape.radius = maxf(r - 0.35, 0.6)
	fshape.height = DEPTH
	fcs.shape = fshape
	fcs.position.y = -DEPTH * 0.5 + 0.45
	fall.add_child(fcs)
	g.add_child(fall)
	if on_fall.is_valid():
		fall.body_entered.connect(func(b: Node3D) -> void:
			if b.is_in_group("player") and float(g.get_meta("open", 1.0)) > 0.5 and not g.has_meta("falling"):
				fall_in(g, b, on_fall))
	return g


# Cut the ground away under a crack that's in the scene already (at its spot, on the ground), and cover the cut's
# ragged edge with broken earth and glowing fissures that follow the ground. Returns how far the cut reached.
static func sink(g: Node3D, scene: Node) -> float:
	if not (scene is Node3D) or not g.is_inside_tree():
		return 0.0
	var r := float(g.get_meta("r", R))
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var at := Vector2(g.global_position.x, g.global_position.z)
	var gy := g.global_position.y
	# The ground's heights round it, read before the cut (relative to the crack's own height)
	var rows := 5
	var heights: Array = []
	for i in RIM_SEGS:
		var a := i * TAU / RIM_SEGS
		var row: Array = []
		for k in rows + 1:
			var d := r + 0.05 + k * (RIM_OUT + 1.4) / rows
			row.append(_height(space, at + Vector2(cos(a), sin(a)) * d, gy) - gy)
		heights.append(row)
	var fissure_h: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(at.x) * 31.0 + absf(at.y) * 17.0)
	for i in FISSURES:
		var a := i * TAU / FISSURES + rng.randf_range(-0.3, 0.3)
		var len := rng.randf_range(1.4, 3.0)
		var tip := at + Vector2(cos(a), sin(a)) * (r + len)
		fissure_h.append([a, len, _height(space, tip, gy) - gy])
	var reach := HOLE.cut(scene, at, r + 0.1, gy - DEPTH - 1.0, gy + 0.6)
	var r_out := clampf(reach + 0.35, r + 0.6, r + RIM_OUT + 1.4)
	g.set_meta("rim", r_out)
	_rim(g, heights, r + 0.05, r_out, (RIM_OUT + 1.4) / rows)
	_fissures(g, fissure_h, r, g.get_meta("colour", Color(0.7, 0.5, 1.0)))
	return reach


# Shut (0) or open (1) it; anything between is part-way (the lid shrinks away as it opens)
static func set_open(g: Node3D, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	g.set_meta("open", k)
	var lid := g.get_node_or_null("Lid") as StaticBody3D
	if lid:
		lid.visible = k < 0.99
		lid.scale = Vector3(1.0 - k * 0.98, 1.0, 1.0 - k * 0.98)
		(lid.get_child(lid.get_child_count() - 1) as CollisionShape3D).disabled = k > 0.5
	for n in ["Swirl", "Glow", "Deep Glow"]:
		var c := g.get_node_or_null(n) as Node3D
		if c:
			c.visible = k > 0.02
	var glow := g.get_node_or_null("Glow") as OmniLight3D
	if glow:
		glow.light_energy = 2.2 * k
	for c in (g.get_node("Lips") as Node3D).get_children():
		var m := (c as MeshInstance3D).material_override as StandardMaterial3D
		m.emission_energy_multiplier = lerpf(0.5, 2.4, k)
	var fall := g.get_node_or_null("Fall") as Area3D
	if fall:
		fall.monitoring = k > 0.5


static func is_open(g: Node3D) -> bool:
	return float(g.get_meta("open", 1.0)) > 0.5


# Dropping in: a whoosh, a little sparkle, a moment of falling, then off to wherever it goes
static func fall_in(g: Node3D, player: Node3D, then: Callable) -> void:
	g.set_meta("falling", true)
	var colour: Color = g.get_meta("colour", Color(0.7, 0.5, 1.0))
	Juice.blip("whoosh", 0.8, -4.0)
	Juice.rumble(0.4, 0.3, 0.3)
	Fx.burst(g, g.global_position + Vector3(0, 0.3, 0), colour, 24, 0.08, 4.0, -2.0, 0.9)
	if player is CharacterBody3D:
		# Pulled gently into the middle, so nobody hangs on the edge
		var to := Vector3(g.global_position.x, player.global_position.y, g.global_position.z)
		(player as CharacterBody3D).velocity = (to - player.global_position) * 3.0 + Vector3(0, -2.0, 0)
	var t := g.get_tree().create_timer(0.45)
	t.timeout.connect(func() -> void:
		if is_instance_valid(g):
			g.remove_meta("falling")
		if then.is_valid():
			then.call())


# Put the player right over a crack's middle, so they drop in (the "Jump in!" answer at its spot)
static func drop_player(g: Node3D) -> void:
	var player := g.get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null:
		return
	player.global_position = g.global_position + Vector3(0, 0.6, 0)
	player.velocity = Vector3(0, 1.5, 0)


# -----------------------------------------------------------------------------
static func _height(space: PhysicsDirectSpaceState3D, at: Vector2, near: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, near + 6.0, at.y), Vector3(at.x, near - 6.0, at.y))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.collider is Node and _is_body(hit.collider)):
		return near
	return (hit.position as Vector3).y


static func _is_body(n: Node) -> bool:
	return n is CharacterBody3D or n.is_in_group("player")


static func _rim(g: Node3D, heights: Array, r_in: float, r_out: float, step: float) -> void:
	# Broken earth from the hole's edge out over wherever the ground's edge was cut ragged, a few centimetres over the
	# ground it covers (its collision is the same triangles)
	var rows := maxi(int(ceil((r_out - r_in) / 0.5)), 1)
	var pts: Array = []
	var n_rows: int = (heights[0] as Array).size()
	for i in RIM_SEGS:
		var a := i * TAU / RIM_SEGS
		var row: Array = []
		for k in rows + 1:
			var d := lerpf(r_in, r_out, float(k) / rows)
			var f := clampf((d - r_in) / step, 0.0, n_rows - 1.001)
			var y := lerpf(float(heights[i][int(f)]), float(heights[i][int(f) + 1]), f - int(f)) + 0.05
			if k == 0:
				y = minf(y, 0.05)
			row.append(Vector3(cos(a) * d, y, sin(a) * d))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in RIM_SEGS:
		var j := (i + 1) % RIM_SEGS
		for k in rows:
			var quad := [pts[i][k], pts[j][k], pts[j][k + 1], pts[i][k + 1]]
			for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
				var v: Array = tri
				if (v[2] - v[0]).cross(v[1] - v[0]).dot(Vector3.UP) < 0.0:
					v = [v[0], v[2], v[1]]
				for q in v:
					st.set_normal(Vector3.UP)
					st.add_vertex(q)
					faces.append(q)
		var o0: Vector3 = pts[i][rows]
		var o1: Vector3 = pts[j][rows]
		var out := Vector3(o0.x, 0, o0.z).normalized()
		for tri in [[o0, o1, o1 + Vector3(0, -0.3, 0)], [o0, o1 + Vector3(0, -0.3, 0), o0 + Vector3(0, -0.3, 0)]]:
			var v: Array = tri
			if (v[2] - v[0]).cross(v[1] - v[0]).dot(out) < 0.0:
				v = [v[0], v[2], v[1]]
			for q in v:
				st.set_normal(out)
				st.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.name = "Broken Earth"
	mi.mesh = st.commit()
	mi.material_override = _mat(Color(0.24, 0.18, 0.15), 0.95)
	g.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "Broken Earth Body"
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	g.add_child(body)
	g.set_meta("rim_heights", heights)


static func _fissures(g: Node3D, list: Array, r: float, colour: Color) -> void:
	# Thin glowing cracks running out from the hole over the ground, the Shift's break showing through
	var holder := Node3D.new()
	holder.name = "Fissures"
	g.add_child(holder)
	var edge := _mat(colour, 0.3, 1.8)
	for f in list:
		var a: float = f[0]
		var len: float = f[1]
		var tip_y: float = f[2]
		var dir := Vector3(cos(a), 0, sin(a))
		var from := dir * (r + 0.1) + Vector3(0, 0.07, 0)
		var bend := Vector3(-dir.z, 0, dir.x) * (0.3 * sin(a * 3.0))
		var to := dir * (r + len) + bend + Vector3(0, tip_y + 0.06, 0)
		var midp := (from + to) * 0.5 + bend * 0.5
		for pair in [[from, midp], [midp, to]]:
			var p0: Vector3 = pair[0]
			var p1: Vector3 = pair[1]
			var d := p1 - p0
			var seg := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.09, 0.04, d.length() + 0.05)
			seg.mesh = b
			seg.material_override = edge
			holder.add_child(seg)
			seg.position = (p0 + p1) * 0.5
			seg.basis = Basis.looking_at(d.normalized(), Vector3.UP) if d.length() > 0.01 else Basis()


static func _box(parent: Node3D, body: StaticBody3D, size: Vector3, t: Transform3D, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.transform = t
	parent.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = t
		body.add_child(cs)


static func _mat(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m
