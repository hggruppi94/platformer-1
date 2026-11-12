extends RefCounted

# A crack in the ground, the way between worlds (Hayden, 12 Nov 2026, lore bible v2 part 3 item 1): "the cracks ARE
# the portals". The broken Shift splits the ground open, and the crack itself is the door: you jump into it. Nothing
# rises out of it. Used for every portal world's crack in the Void (scripts/portals.gd), the way home inside each
# world (scripts/portal_world.gd), the crack by the old oak on Earth (scripts/earth_world.gd) and the crack in the Void
# that goes back to Earth (scripts/portal.gd).
#
# The look (Hayden, 12 Nov 2026, with a photo of a real earth fissure: "make them look more like this"): a long, jagged
# split in the ground, widest in the middle and narrowing to hairline points at both ends, with dark soil walls dropping
# away into blackness, broken dry dirt heaped along its lips, clods hanging off the edges and thin side cracks running
# off into the dirt. Only far down at the bottom does the colour of the world it leads to shimmer. It runs along the
# crack's own x axis (the "Jump in" spots sit to one side of it, on z).
#
# make() builds what doesn't depend on the ground (the bottom, the shimmer at the bottom, the lights, the lid and the
# "Fall" area just inside the split). sink() cuts the real ground away under the deep middle (scripts/ground_hole.gd),
# so the player truly drops in, and then builds the rest following the ground: the broken earth round the split
# ("Broken Earth", which also covers the cut's ragged edge), the split's walls ("Shaft"), the clods ("Lips") and the side
# cracks ("Fissures"). The swirl at the bottom ("Swirl") is where a world's live preview shows
# (Portals._open_preview()): look down into a crack and you see the world it leads to. set_open() shuts or opens it:
# shut, the split closes to a dirt seam (the lid: Earth's crack outside the Shift), and the fall area sleeps.
# No class_name on purpose (see scripts/use_spot.gd): load it with preload.

const HOLE := preload("res://scripts/ground_hole.gd")

const R := 1.4                       # the deep middle: the ground is cut away this far round the crack's centre
const DEPTH := 5.0                   # down to the swirl
const LENGTH := 2.65                 # half the split's length, in R's (so it runs ~3.7 m each way)
const WIDTH := 0.68                  # half the split's width at its widest, in metres (the player is 0.7 m across)
const STEP := 0.14                   # along the split
const RIM_OUT := 1.4                 # the broken earth reaches at least this far past the cut
const GLOW := 1.5

const SOIL := Color(0.31, 0.22, 0.15)      # the walls' top, damp dark soil
const DEEP := Color(0.035, 0.027, 0.025)   # where the light runs out
const DIRT := Color(0.47, 0.36, 0.25)      # dry broken dirt round it
const DIRT_EDGE := Color(0.33, 0.24, 0.16)


# The crack itself. `on_fall` is called when the player drops into it (and not while it's shut).
static func make(colour: Color, on_fall: Callable = Callable(), r := R) -> Node3D:
	var g := Node3D.new()
	g.set_meta("r", r)
	g.set_meta("colour", colour)
	g.set_meta("open", 1.0)
	var line := _outline(r, int(colour.r8 * 7 + colour.g8 * 13 + colour.b8 * 29))
	g.set_meta("outline", line)
	var dark := _mat(DEEP, 1.0)
	# The bottom, and (built in sink()) the split's walls
	var shaft := Node3D.new()
	shaft.name = "Shaft"
	g.add_child(shaft)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	shaft.add_child(walls)
	_box(shaft, walls, Vector3(r * 2.0 + 1.0, 0.4, r * 2.0 + 1.0), Transform3D(Basis(), Vector3(0, -DEPTH - 0.2, 0)), dark)
	# The swirl at the bottom, colour of the world it leads to (the preview window shows here). The split's walls hide
	# all but the strip of it you see between them.
	var swirl := MeshInstance3D.new()
	swirl.name = "Swirl"
	var disc := CylinderMesh.new()
	disc.top_radius = r + 0.1
	disc.bottom_radius = r + 0.1
	disc.height = 0.04
	disc.radial_segments = 32
	swirl.mesh = disc
	swirl.material_override = _mat(colour.darkened(0.35), 0.2, 1.2)
	swirl.position.y = -DEPTH + 0.08
	g.add_child(swirl)
	var core := MeshInstance3D.new()
	core.name = "Core"
	var cd := CylinderMesh.new()
	cd.top_radius = r * 0.45
	cd.bottom_radius = r * 0.45
	cd.height = 0.02
	core.mesh = cd
	core.material_override = _mat(colour.lightened(0.3), 0.2, 2.0)
	swirl.add_child(core)
	core.position = Vector3(0, 0.04, 0)
	# A faint glow from far down only: the top of the split stays dark earth
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = colour
	light.light_energy = GLOW
	light.omni_range = 4.2
	light.position.y = -DEPTH + 2.2
	g.add_child(light)
	var up := OmniLight3D.new()
	up.name = "Deep Glow"
	up.light_color = colour
	up.light_energy = 1.4
	up.omni_range = 3.5
	up.position.y = -DEPTH + 0.8
	g.add_child(up)
	var lips := Node3D.new()                       # the clods along the edges (sink())
	lips.name = "Lips"
	g.add_child(lips)
	# The lid: the split closed up to a seam of dirt while it's shut (set_open()). Flat until sink() lays it on the ground.
	var lid := StaticBody3D.new()
	lid.name = "Lid"
	g.add_child(lid)
	var lcs := CollisionShape3D.new()
	lid.add_child(lcs)
	_fill_lid(g, {})
	lid.visible = false
	lcs.disabled = true
	# Dropping in: just inside the split's deep middle, up to a little over the ground (so even where the ground couldn't
	# be cut away, stepping onto the crack's middle takes you through)
	var fall := Area3D.new()
	fall.name = "Fall"
	fall.monitorable = false
	var fcs := CollisionShape3D.new()
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(maxf(r - 0.3, 0.6) * 2.0, DEPTH, maxf(WIDTH - 0.2, 0.35) * 2.0)
	fcs.shape = fshape
	fcs.position.y = -DEPTH * 0.5 + 0.45
	fall.add_child(fcs)
	g.add_child(fall)
	if on_fall.is_valid():
		fall.body_entered.connect(func(b: Node3D) -> void:
			if b.is_in_group("player") and float(g.get_meta("open", 1.0)) > 0.5 and not g.has_meta("falling"):
				fall_in(g, b, on_fall))
	return g


# Cut the ground away under a crack that's in the scene already (at its spot, on the ground), and build the split
# following the ground: its walls, the broken earth round it (over the cut's ragged edge too), the clods on its lips and
# the side cracks. Returns how far the cut reached.
static func sink(g: Node3D, scene: Node) -> float:
	if not (scene is Node3D) or not g.is_inside_tree():
		return 0.0
	var r := float(g.get_meta("r", R))
	var line: Dictionary = g.get_meta("outline")
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var gt := g.global_transform
	var gy := g.global_position.y
	# The ground's heights all round it, read before the cut (relative to the crack's own height), on a 0.5 m grid in
	# the crack's own frame
	var half_x := float(line.half) + 1.4
	var half_z := r + RIM_OUT + 1.6
	var grid := {"x0": -half_x, "z0": -half_z, "step": 0.5, "nx": int(ceil(half_x * 4.0)) + 1, "nz": int(ceil(half_z * 4.0)) + 1}
	var hs := PackedFloat32Array()
	hs.resize(grid.nx * grid.nz)
	for j in grid.nz:
		for i in grid.nx:
			var p := gt * Vector3(grid.x0 + i * 0.5, 0, grid.z0 + j * 0.5)
			var h := _height(space, Vector2(p.x, p.z), gy) - gy
			# (something standing there, a crystal or a root, isn't the ground: the dirt mustn't climb up it)
			hs[j * grid.nx + i] = h if h < 0.7 else 0.0
	grid.h = hs
	var at := Vector2(g.global_position.x, g.global_position.z)
	var reach := HOLE.cut(scene, at, r + 0.1, gy - DEPTH - 1.0, gy + 0.6)
	var r_out := clampf(reach + 0.35, r + 0.6, r + RIM_OUT + 1.4)
	g.set_meta("rim", r_out)
	var ctx := {"grid": grid, "line": line, "r": r, "r_out": r_out + 0.7, "cover": r_out}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(at.x) * 31.0 + absf(at.y) * 17.0) + 5
	_deck(g, ctx, rng)
	_walls(g, ctx, rng)
	_clods(g, ctx, rng)
	_fissures(g, ctx, rng)
	_fill_lid(g, ctx)
	set_open(g, float(g.get_meta("open", 1.0)))
	return reach


# Shut (0) or open (1) it; anything between is part-way (the seam of dirt draws apart as it opens)
static func set_open(g: Node3D, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	g.set_meta("open", k)
	var lid := g.get_node_or_null("Lid") as StaticBody3D
	if lid:
		lid.visible = k < 0.99
		lid.scale = Vector3(1.0, 1.0, maxf(1.0 - k, 0.02))
		(lid.get_child(lid.get_child_count() - 1) as CollisionShape3D).disabled = k > 0.5
	for n in ["Swirl", "Glow", "Deep Glow"]:
		var c := g.get_node_or_null(n) as Node3D
		if c:
			c.visible = k > 0.02
	var glow := g.get_node_or_null("Glow") as OmniLight3D
	if glow:
		glow.light_energy = GLOW * k
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
# The split's shape: for each step along x, where its two edges are (z) and where its middle runs. Widest in the middle,
# narrowing to points; both edges ragged on their own, with bites taken out here and there.
static func _outline(r: float, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var half := r * LENGTH
	var w0 := maxf(WIDTH * r / R, 0.55)
	var n := int(ceil(half * 2.0 / STEP)) + 1
	var ph := rng.randf_range(0.0, TAU)
	var ph2 := rng.randf_range(0.0, TAU)
	var xs := PackedFloat32Array()
	var top := PackedFloat32Array()
	var bot := PackedFloat32Array()
	var mid := PackedFloat32Array()
	var jt := 0.0
	var jb := 0.0
	for i in n:
		var x := -half + i * (half * 2.0 / (n - 1))
		var t := absf(x) / half
		# the middle wanders more towards the ends (the deep middle stays over the cut)
		var c := (0.08 + 0.25 * t) * sin(x * 1.25 + ph) + 0.06 * sin(x * 3.4 + ph2)
		var w := w0 * pow(maxf(1.0 - t * t, 0.0), 0.75) * (0.88 + 0.12 * sin(x * 2.1 + ph2))
		# ragged edges: a random walk, pulled back, plus the odd bite
		jt = jt * 0.55 + rng.randf_range(-0.06, 0.06)
		jb = jb * 0.55 + rng.randf_range(-0.06, 0.06)
		var bt := rng.randf_range(0.06, 0.16) if rng.randf() < 0.12 else 0.0
		var bb := rng.randf_range(0.06, 0.16) if rng.randf() < 0.12 else 0.0
		var k := minf(w * 2.0, 1.0)                # (less raggedness where it's thin)
		var zt := c + w + (jt + bt) * k
		var zb := c - w - (jb + bb) * k
		if zt - zb < 0.02:
			zt = c + 0.01
			zb = c - 0.01
		xs.append(x)
		top.append(zt)
		bot.append(zb)
		mid.append(c)
	return {"half": half, "x": xs, "top": top, "bot": bot, "mid": mid}


static func _edge_at(line: Dictionary, x: float) -> Vector3:
	# (top edge z, bottom edge z, middle z) at x; past the ends, a closed point
	var xs: PackedFloat32Array = line.x
	var n := xs.size()
	var f := clampf((x - xs[0]) / (xs[n - 1] - xs[0]) * (n - 1), 0.0, n - 1.001)
	var i := int(f)
	var u := f - i
	var top: PackedFloat32Array = line.top
	var bot: PackedFloat32Array = line.bot
	var mid: PackedFloat32Array = line.mid
	if absf(x) > float(line.half):
		var m := lerpf(mid[i], mid[i + 1], u)
		return Vector3(m, m, m)
	return Vector3(lerpf(top[i], top[i + 1], u), lerpf(bot[i], bot[i + 1], u), lerpf(mid[i], mid[i + 1], u))


static func _ground(ctx: Dictionary, x: float, z: float) -> float:
	# The ground's height at (x, z) in the crack's frame, from the heights read before the cut (0 with none)
	if not ctx.has("grid"):
		return 0.0
	var gr: Dictionary = ctx.grid
	var fx := clampf((x - float(gr.x0)) / 0.5, 0.0, int(gr.nx) - 1.001)
	var fz := clampf((z - float(gr.z0)) / 0.5, 0.0, int(gr.nz) - 1.001)
	var i := int(fx)
	var j := int(fz)
	var h: PackedFloat32Array = gr.h
	var nx := int(gr.nx)
	var a := lerpf(h[j * nx + i], h[j * nx + i + 1], fx - i)
	var b := lerpf(h[(j + 1) * nx + i], h[(j + 1) * nx + i + 1], fx - i)
	return lerpf(a, b, fz - j)


static func _lip(d: float, x: float) -> float:
	# The broken dirt heaped up along the split's lips, falling away from the edge
	return 0.075 * exp(-d / 0.35) * (0.7 + 0.3 * sin(x * 5.3))


static func _deck_y(ctx: Dictionary, x: float, z: float) -> float:
	var e := _edge_at(ctx.line, x)
	var d := maxf(z - e.x, e.y - z)
	return _ground(ctx, x, z) + 0.04 + _lip(maxf(d, 0.0), x)


static func _deck(g: Node3D, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	# Broken dry earth round the split, out over wherever the ground's edge was cut ragged: strips across it, from each
	# edge of the split out to a ragged boundary, a few centimetres over the ground (its collision is the same triangles)
	var line: Dictionary = ctx.line
	var r_out: float = ctx.r_out
	var half: float = line.half
	var rx := maxf(half + 0.9, r_out + 0.2)
	var ez := 1.15                                # how far the dirt reaches either side of the thin ends
	var cols := int(ceil(rx * 2.0 / STEP)) + 1
	var rows := 6
	var outer := PackedFloat32Array()
	var wob := 0.0
	for c in cols:
		var x := -rx + c * (rx * 2.0 / (cols - 1))
		var t := clampf(absf(x) / rx, 0.0, 1.0)
		var o := ez * sqrt(maxf(1.0 - t * t, 0.0))
		if absf(x) < r_out:
			o = maxf(o, sqrt(r_out * r_out - x * x) + 0.1)
		wob = wob * 0.7 + rng.randf_range(-0.12, 0.12)
		outer.append(maxf(o + wob * minf(o, 1.0), 0.05))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var grid: Array = []                          # [col][side][row] -> Vector3
	for c in cols:
		var x := -rx + c * (rx * 2.0 / (cols - 1))
		var e := _edge_at(line, x)
		var sides: Array = []
		for side in 2:
			var z_in := e.x if side == 0 else e.y
			var sgn := 1.0 if side == 0 else -1.0
			var z_out := e.z + sgn * maxf(outer[c], absf(z_in - e.z) + 0.25)
			var pts: Array = []
			for k in rows + 1:
				var s := pow(float(k) / rows, 1.6)
				var z := lerpf(z_in, z_out, s)
				var y := _ground(ctx, x, z) + 0.04 + _lip(absf(z - z_in), x)
				if k == rows:
					y -= 0.05                           # (tucked into the ground at its outer edge)
				pts.append(Vector3(x, y, z))
			sides.append(pts)
		grid.append(sides)
	for c in cols - 1:
		for side in 2:
			for k in rows:
				# each corner with how solid it is: solid over the cut (so its ragged edge never shows) and near the
				# split, fading into the ground further out
				var quad := [[grid[c][side][k], k], [grid[c + 1][side][k], k], [grid[c + 1][side][k + 1], k + 1],
					[grid[c][side][k + 1], k + 1]]
				for tri in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
					var v: Array = tri
					if ((v[2][0] as Vector3) - (v[0][0] as Vector3)).cross((v[1][0] as Vector3) - (v[0][0] as Vector3)).dot(Vector3.UP) < 0.0:
						v = [v[0], v[2], v[1]]
					for q in v:
						var p: Vector3 = q[0]
						var col := _dirt_colour(p, ctx)
						var fade := 1.0 - smoothstep(0.3, 1.0, pow(float(q[1]) / rows, 1.6))
						col.a = 1.0 if Vector2(p.x, p.z).length() < float(ctx.cover) else fade
						st.set_color(col)
						st.add_vertex(p)
						faces.append(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Broken Earth"
	mi.mesh = st.commit()
	var dm := _vmat(0.97)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mi.material_override = dm
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


static func _dirt_colour(p: Vector3, ctx: Dictionary) -> Color:
	# Dry and pale away from the split, darker and damper right at its lips, blotchy all over
	var e := _edge_at(ctx.line, p.x)
	var d := maxf(maxf(p.z - e.x, e.y - p.z), 0.0)
	var n := 0.5 + 0.25 * sin(p.x * 3.7 + p.z * 1.9) + 0.25 * sin(p.x * 1.3 - p.z * 4.1)
	var c := DIRT.lerp(DIRT_EDGE, clampf(1.0 - d / 0.6, 0.0, 1.0))
	return c.darkened(0.12 * n)


static func _walls(g: Node3D, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	# The split's two soil walls, lumpy and leaning in a little as they drop away into the dark, and its floor: deep over
	# the cut middle, rising to just over the ground towards the thin ends
	var line: Dictionary = ctx.line
	var r: float = ctx.r
	var xs: PackedFloat32Array = line.x
	var levels := [0.0, 0.1, 0.3, 0.6, 1.0]        # down the wall, as parts of its depth
	var shades := [SOIL.lightened(0.15), SOIL, SOIL.darkened(0.45), DEEP.lightened(0.05), DEEP]
	var cols: Array = []                             # [col] -> [top wall points, bottom wall points]
	for i in xs.size():
		var x := xs[i]
		var e := _edge_at(line, x)
		var surf := _ground(ctx, x, e.z) + 0.015
		var floor_y := lerpf(-DEPTH, surf, smoothstep(r - 0.55, r - 0.05, absf(x)))
		var walls_pair: Array = []
		for side in 2:
			var z0 := e.x if side == 0 else e.y
			var top_y := _deck_y(ctx, x, z0)
			var pts: Array = []
			for l in levels.size():
				var f: float = levels[l]
				var y := lerpf(top_y, floor_y, f)
				var lean := 0.16 * f * (z0 - e.z)       # (in towards the middle)
				var bump := 0.0 if l == 0 else rng.randf_range(-0.07, 0.07) * minf(absf(z0 - e.z) * 3.0, 1.0)
				pts.append(Vector3(x, y, z0 - lean + bump))
			walls_pair.append(pts)
		cols.append(walls_pair)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in cols.size() - 1:
		for side in 2:
			var inward := Vector3(0, 0, -1.0 if side == 0 else 1.0)
			for l in levels.size() - 1:
				var a: Vector3 = cols[i][side][l]
				var b: Vector3 = cols[i + 1][side][l]
				var c: Vector3 = cols[i + 1][side][l + 1]
				var d: Vector3 = cols[i][side][l + 1]
				var ca: Color = shades[l]
				var cd: Color = shades[l + 1]
				for tri in [[[a, ca], [b, ca], [c, cd]], [[a, ca], [c, cd], [d, cd]]]:
					var v: Array = tri
					if ((v[2][0] as Vector3) - (v[0][0] as Vector3)).cross((v[1][0] as Vector3) - (v[0][0] as Vector3)).dot(inward) < 0.0:
						v = [v[0], v[2], v[1]]
					for q in v:
						st.set_color(q[1])
						st.add_vertex(q[0])
						faces.append(q[0])
		# the floor between the walls' feet (deep in the middle, a dark seam towards the ends)
		var last := levels.size() - 1
		var fa: Vector3 = cols[i][0][last]
		var fb: Vector3 = cols[i + 1][0][last]
		var fc: Vector3 = cols[i + 1][1][last]
		var fd: Vector3 = cols[i][1][last]
		for tri in [[fa, fb, fc], [fa, fc, fd]]:
			var v: Array = tri
			if (v[2] - v[0]).cross(v[1] - v[0]).dot(Vector3.UP) < 0.0:
				v = [v[0], v[2], v[1]]
			for q in v:
				st.set_color(DEEP)
				st.add_vertex(q)
				faces.append(q)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Split"
	mi.mesh = st.commit()
	mi.material_override = _vmat(1.0)
	var shaft := g.get_node("Shaft") as Node3D
	shaft.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	(shaft.get_node("Walls") as StaticBody3D).add_child(cs)


static func _clods(g: Node3D, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	# Lumps of broken dirt along both lips, some hanging out over the dark, and a few stuck on the walls further down
	var lips := g.get_node("Lips") as Node3D
	var line: Dictionary = ctx.line
	var half: float = line.half
	var mats := [_mat(DIRT_EDGE, 0.97), _mat(SOIL.lightened(0.1), 0.97), _mat(DIRT.darkened(0.1), 0.97)]
	var x := -half + 0.3
	while x < half - 0.3:
		var e := _edge_at(line, x)
		var w := (e.x - e.y) * 0.5
		for side in 2:
			if rng.randf() < 0.3:
				continue
			var sgn := 1.0 if side == 0 else -1.0
			var z_edge := e.x if side == 0 else e.y
			var s := rng.randf_range(0.1, 0.24) * clampf(w * 2.5, 0.45, 1.0)
			var over := rng.randf_range(-0.04, 0.16)            # (out over the edge, or back from it)
			var z := z_edge + sgn * (s * 0.5 - over)
			var size := Vector3(s * rng.randf_range(0.9, 1.6), s * rng.randf_range(0.45, 0.8), s * rng.randf_range(0.8, 1.3))
			var clod := _lump(size, rng)
			clod.material_override = mats[rng.randi() % mats.size()]
			clod.position = Vector3(x, _deck_y(ctx, x, z_edge + sgn * 0.1) + size.y * 0.15, z)
			clod.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf_range(-PI, PI), rng.randf_range(-0.45, 0.45))
			lips.add_child(clod)
		x += rng.randf_range(0.22, 0.4)
	var r: float = ctx.r
	for i in 9:                                      # stuck on the walls
		var cx := rng.randf_range(-(r - 0.6), r - 0.6)
		var e := _edge_at(line, cx)
		var side := rng.randi() % 2
		var z := (e.x if side == 0 else e.y) - (0.08 if side == 0 else -0.08)
		var s := rng.randf_range(0.12, 0.26)
		var clod := _lump(Vector3(s * 1.3, s * 0.8, s), rng)
		clod.material_override = mats[1]
		clod.position = Vector3(cx, -rng.randf_range(0.25, 1.6), z)
		clod.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-PI, PI), rng.randf_range(-0.6, 0.6))
		lips.add_child(clod)


static func _lump(size: Vector3, rng: RandomNumberGenerator) -> MeshInstance3D:
	# A lump of dirt: a few-sided ball, squashed to its size (faceted, so it catches the light like a broken clod)
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = rng.randi_range(5, 7)
	m.rings = 3
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.scale = size
	return mi


static func _fissures(g: Node3D, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	# Thin dark cracks running off the split into the dirt, and on out past its two ends
	var holder := Node3D.new()
	holder.name = "Fissures"
	g.add_child(holder)
	var line: Dictionary = ctx.line
	var half: float = line.half
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var runs: Array = []
	for end in [-1.0, 1.0]:                          # on past the ends
		var e := _edge_at(line, end * half)
		runs.append([Vector2(end * (half - 0.1), e.z), Vector2(end, 0.0), rng.randf_range(0.9, 1.5), 0.05])
	for i in 8:                                      # off the sides
		var x := rng.randf_range(-half * 0.8, half * 0.8)
		var e := _edge_at(line, x)
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := e.x if side > 0 else e.y
		var a := side * rng.randf_range(0.6, 1.35) + (0.0 if rng.randf() < 0.5 else PI * 0.0)
		var dir := Vector2(cos(a), sin(a))
		if rng.randf() < 0.5:
			dir.x = -dir.x
		runs.append([Vector2(x, z - side * 0.03), dir, rng.randf_range(0.5, 1.5), rng.randf_range(0.04, 0.07)])
	for run in runs:
		var p: Vector2 = run[0]
		var dir: Vector2 = run[1]
		var len: float = run[2]
		var w: float = run[3]
		var segs := 5
		for s in segs:
			var nd := dir.rotated(rng.randf_range(-0.5, 0.5))
			var q := p + nd * (len / segs)
			var w0 := w * (1.0 - float(s) / segs)
			var w1 := w * (1.0 - float(s + 1) / segs) + 0.008
			var side0 := Vector2(-nd.y, nd.x)
			var quad := [p + side0 * w0, q + side0 * w1, q - side0 * w1, p - side0 * w0]
			var v3: Array = []
			for c in quad:
				var c2: Vector2 = c
				v3.append(Vector3(c2.x, _deck_y(ctx, c2.x, c2.y) + 0.012, c2.y))
			for tri in [[v3[0], v3[1], v3[2]], [v3[0], v3[2], v3[3]]]:
				var v: Array = tri
				if (v[2] - v[0]).cross(v[1] - v[0]).dot(Vector3.UP) < 0.0:
					v = [v[0], v[2], v[1]]
				for q3 in v:
					st.set_normal(Vector3.UP)
					st.add_vertex(q3)
			p = q
			dir = nd
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(DEEP.lightened(0.04), 1.0)
	holder.add_child(mi)


static func _fill_lid(g: Node3D, ctx: Dictionary) -> void:
	# The split closed up: dirt filling it at the lips' height, with a dark seam down its middle
	var lid := g.get_node("Lid") as StaticBody3D
	for c in lid.get_children():
		if c is MeshInstance3D:
			c.free()
	var line: Dictionary = ctx.get("line", g.get_meta("outline"))
	var xs: PackedFloat32Array = line.x
	var top: PackedFloat32Array = line.top
	var bot: PackedFloat32Array = line.bot
	var mid: PackedFloat32Array = line.mid
	var lctx := ctx if ctx.has("line") else {"line": line}
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seam := SurfaceTool.new()
	seam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for i in xs.size() - 1:
		var pts: Array = []
		for j in [i, i + 1]:
			var y := maxf(_deck_y(lctx, xs[j], top[j]), _deck_y(lctx, xs[j], bot[j])) + 0.01
			pts.append([Vector3(xs[j], y, top[j]), Vector3(xs[j], y, bot[j]), Vector3(xs[j], y + 0.005, mid[j])])
		var a: Vector3 = pts[0][0]
		var b: Vector3 = pts[1][0]
		var c: Vector3 = pts[1][1]
		var d: Vector3 = pts[0][1]
		for tri in [[a, b, c], [a, c, d]]:
			var v: Array = tri
			if (v[2] - v[0]).cross(v[1] - v[0]).dot(Vector3.UP) < 0.0:
				v = [v[0], v[2], v[1]]
			for q in v:
				st.set_normal(Vector3.UP)
				st.add_vertex(q)
				faces.append(q)
		var m0: Vector3 = pts[0][2]
		var m1: Vector3 = pts[1][2]
		var sw := Vector3(0, 0, 0.035)
		for tri in [[m0 + sw, m1 + sw, m1 - sw], [m0 + sw, m1 - sw, m0 - sw]]:
			var v: Array = tri
			if (v[2] - v[0]).cross(v[1] - v[0]).dot(Vector3.UP) < 0.0:
				v = [v[0], v[2], v[1]]
			for q in v:
				seam.set_normal(Vector3.UP)
				seam.add_vertex(q)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat(DIRT_EDGE, 0.97)
	lid.add_child(mi)
	lid.move_child(mi, 0)
	var sm := MeshInstance3D.new()
	sm.mesh = seam.commit()
	sm.material_override = _mat(DEEP, 1.0)
	lid.add_child(sm)
	lid.move_child(sm, 1)
	var cs := lid.get_child(lid.get_child_count() - 1) as CollisionShape3D
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape


static func _height(space: PhysicsDirectSpaceState3D, at: Vector2, near: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, near + 6.0, at.y), Vector3(at.x, near - 6.0, at.y))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.collider is Node and _is_body(hit.collider)):
		return near
	return (hit.position as Vector3).y


static func _is_body(n: Node) -> bool:
	return n is CharacterBody3D or n.is_in_group("player")


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


static func _vmat(rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m


static func _mat(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m
