extends RefCounted

# The Void's mountains (Hayden, 14 Nov 2026: "The mountains are just upside-down cones right now, and should visually
# look more like actual mountains, maybe even an alien landscape", with a picture of jagged icy peaks under a ringed
# planet and a purple sky). WorldDetail calls dress() as the town or the school (its 3rd-floor window shows the same
# peaks) loads: every cone under a "Mountains" node (tools/build_town.gd _mountains(), build_school.gd's view) is hidden
# and a real mountain stands in its place, same foot, height and turn:
#   - a jagged faceted peak with a few lower summits round it and ridges running down (FastNoiseLite, ridged), its
#     footprint ragged, never round
#   - dark indigo rock on the steep faces with paler bands, icy lavender-white snow and ice on the gentler slopes up high
#   - now and then a cluster of glowing crystals jutting out of its side
# Behind them a second, taller and paler range (FAR_RANGE) makes it a landscape instead of a row.
# Same seed every time, so they always look the same. Nothing is solid (they're far past the edge of the world).

const RINGS := 16
const SEGMENTS := 30
const FAR_RANGE := 16                          # how many peaks in the range behind
const ROCK := Color(0.2, 0.16, 0.34)
const ROCK_BAND := Color(0.32, 0.26, 0.48)
const ICE := Color(0.62, 0.7, 0.98)
const SNOW := Color(0.9, 0.9, 1.0)
const CRYSTALS := [Color(0.4, 1.0, 0.95), Color(1.0, 0.45, 0.9), Color(0.7, 0.55, 1.0)]


static func dress(scene: Node) -> int:
	# Swaps the cones for mountains. Returns how many it made (tests read it).
	var made := 0
	for holder in scene.find_children("Mountains", "Node3D", true, false):
		if holder.has_meta("alien_mountains"):
			continue
		holder.set_meta("alien_mountains", true)
		var mats := materials()
		var k := 0
		for child in holder.get_children():
			var cone := child as MeshInstance3D
			if cone == null or not (cone.mesh is CylinderMesh) or (cone.mesh as CylinderMesh).top_radius > 0.01:
				continue
			var h := (cone.mesh as CylinderMesh).height
			var foot := cone.position - cone.basis.y.normalized() * h / 2.0
			cone.visible = false
			holder.add_child(mountain(h, 100 + k, mats, foot, cone.rotation.y))
			k += 1
			made += 1
		# The range behind: taller and further, so the near peaks stand in front of something
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in FAR_RANGE:
			var a := lerpf(-PI * 0.97, -PI * 0.03, i / float(FAR_RANGE - 1)) + rng.randf_range(-0.04, 0.04)
			var dist := rng.randf_range(360, 420)
			var h := rng.randf_range(110, 170)
			var foot := Vector3(cos(a) * dist, -8, sin(a) * dist - 60)
			holder.add_child(mountain(h, 300 + i, mats, foot, rng.randf() * TAU, true))
			made += 1
	return made


static func materials() -> Dictionary:
	var rock := StandardMaterial3D.new()
	rock.resource_name = "Alien Mountain"
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.55
	rock.metallic_specular = 0.6
	rock.rim_enabled = true                      # a soft cold rim of light along the ridges, like the picture
	rock.rim = 0.35
	rock.rim_tint = 0.3
	var far := rock.duplicate() as StandardMaterial3D
	far.resource_name = "Alien Mountain Far"
	far.roughness = 0.8
	var crystal := StandardMaterial3D.new()
	crystal.resource_name = "Mountain Crystal"
	crystal.vertex_color_use_as_albedo = true
	crystal.emission_enabled = true
	crystal.emission = Color(0.5, 0.9, 1.0)
	crystal.emission_energy_multiplier = 1.4
	crystal.roughness = 0.2
	return {"rock": rock, "far": far, "crystal": crystal}


static func mountain(h: float, seed_no: int, mats: Dictionary, foot: Vector3, turn: float, far := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Peak %d" % seed_no
	root.position = foot
	root.rotation.y = turn
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = peak_mesh(h, seed_no, far)
	mi.material_override = mats["far"] if far else mats["rock"]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if not far:
		_crystals(root, h, seed_no, mats["crystal"])
	return root


static func height_at(t: float, a: float, h: float, noise: FastNoiseLite, subs: Array) -> float:
	# How high the mountain is t of the way out from its middle (0..1) at angle a
	var x := cos(a) * t
	var z := sin(a) * t
	var main := h * pow(1.0 - t, 1.35)
	for s in subs:
		var d := Vector2(x - s.x, z - s.y).length()
		main = maxf(main, s.z * h * pow(maxf(1.0 - d / s.w, 0.0), 1.2) * (1.0 - t * 0.6))
	# Ridges: ridged noise carves gullies and sharp crests, most on the middle slopes
	var n := 1.0 - absf(noise.get_noise_2d(x * 3.2, z * 3.2))
	var crest := (n * n - 0.45) * h * 0.22 * sin(t * PI)
	var fine := noise.get_noise_2d(x * 11.0 + 40.0, z * 11.0) * h * 0.04 * (1.0 - t)
	return maxf(main + crest + fine, 0.0) if t < 0.999 else 0.0


static func peak_mesh(h: float, seed_no: int, far := false) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_no
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_no
	var subs := []                                 # lower summits round the main one: x, z, height (of h), reach
	for i in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.28, 0.55)
		subs.append(Vector4(cos(a) * r, sin(a) * r, rng.randf_range(0.45, 0.78), rng.randf_range(0.3, 0.5)))
	var radius := h * (0.95 if far else 0.85)
	var rings := RINGS if not far else 10
	var segs := SEGMENTS if not far else 20
	# Points: a ragged footprint (each spoke a little longer or shorter), the summit off-centre a touch
	var pts := []
	for i in rings + 1:
		var t := i / float(rings)
		var row := []
		for j in segs:
			var a := j * TAU / segs
			var spoke := 1.0 + noise.get_noise_2d(cos(a) * 2.0 + 9.0, sin(a) * 2.0) * 0.35
			var y := height_at(t, a, h, noise, subs)
			row.append(Vector3(cos(a) * t * radius * spoke, y, sin(a) * t * radius * spoke))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var snow_line := h * rng.randf_range(0.38, 0.5)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j2]
			var c: Vector3 = pts[i + 1][j]
			var d: Vector3 = pts[i + 1][j2]
			_tri(st, a, c, b, h, snow_line, far)
			_tri(st, b, c, d, h, snow_line, far)
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, h: float, snow_line: float, far: bool) -> void:
	# One flat facet, coloured by how steep and how high it is
	var n := (b - a).cross(c - a)
	if n.length() < 0.0001:
		return
	n = n.normalized()
	if n.y < 0.0:
		n = -n
	var mid := (a + b + c) / 3.0
	var flat := n.y
	var high := mid.y / h
	var band := 0.5 + 0.5 * sin(mid.y * 0.45 + mid.x * 0.05)
	var col := ROCK.lerp(ROCK_BAND, band * 0.6)
	if flat > 0.62 and mid.y > snow_line * 0.7:
		col = ICE.lerp(SNOW, clampf((mid.y - snow_line * 0.7) / (h * 0.3), 0.0, 1.0))
	elif flat > 0.5 and mid.y > snow_line:
		col = col.lerp(ICE, 0.65)
	elif high > 0.85:
		col = col.lerp(SNOW, 0.5)
	if far:
		col = col.lerp(Color(0.62, 0.55, 0.85), 0.45)     # further away: paler and bluer, into the haze
	st.set_color(col)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


static func _crystals(root: Node3D, h: float, seed_no: int, mat: Material) -> void:
	# A cluster of glowing crystals jutting out of one side on some mountains
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_no * 13
	if rng.randf() < 0.55:
		var a := rng.randf() * TAU
		var t := rng.randf_range(0.45, 0.65)
		var base := Vector3(cos(a) * t * h * 0.85, h * pow(1.0 - t, 1.35) * 0.85, sin(a) * t * h * 0.85)
		var col: Color = CRYSTALS[rng.randi() % CRYSTALS.size()]
		for i in rng.randi_range(3, 5):
			var len := h * rng.randf_range(0.12, 0.24)
			var m := CylinderMesh.new()
			m.top_radius = 0.0
			m.bottom_radius = len * 0.16
			m.height = len
			m.radial_segments = 5
			m.rings = 1
			var mi := MeshInstance3D.new()
			mi.name = "Crystal"
			mi.mesh = m
			var cm := mat.duplicate() as StandardMaterial3D
			cm.albedo_color = col
			cm.vertex_color_use_as_albedo = false
			cm.emission = col
			mi.material_override = cm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var out := Vector3(cos(a), 0.9, sin(a)).normalized()
			var tilt := out + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.2, 0.3), rng.randf_range(-0.4, 0.4))
			var up := tilt.normalized()
			var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
			mi.transform = Transform3D(Basis(side, up, side.cross(up)), base + up * len * 0.4)
			root.add_child(mi)
