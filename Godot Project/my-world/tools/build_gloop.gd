extends SceneTree

# Builds the Gloops, after Hayden's Gloop King picture (Oct 29, 2026): glossy green-gold goo with a rainbow sheen, big
# dark glassy eyes set in goo rims, layers of goo draped over each other with drippy tongues, and stubby feet.
#
#   res://scenes/enemies/gloop.tscn       an ordinary Gloop (logic in scripts/gloop.gd)
#   res://scenes/enemies/gloop_king.tscn  the Gloop King: the same goo with a little gold crown and a red gem
#                                         (logic in scripts/gloop_king.gd)
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_gloop.gd
#
# Feet at the origin, facing +Z like the glTF characters. Size and goldness are set per Gloop where it's placed.
# The goo itself is scenes/enemies/gloop_goo.gdshader; the drip loop lives there (the tongues) and in gloop.gd (the
# drops that fall off them).

const OUT_DIR := "res://scenes/enemies"
const SHADER := "res://scenes/enemies/gloop_goo.gdshader"
const BODY_MESH := "res://scenes/enemies/gloop_body.tres"   # shared by both scenes, so it's only stored once

# The body is a dome on a fat bottom, sitting on its feet. Heights and radii are in metres for a size-1 Gloop.
const RADIUS := 0.45
const CENTER_Y := 0.36            # the widest ring, low down like the picture
const TOP_HALF := 0.78            # dome height above it
const BOTTOM_HALF := 0.3          # belly below it, down to the feet
const COLUMNS := 120
const RINGS_EDGE := 10            # rows across each layer's rolled edge
const RINGS_BETWEEN := 13         # rows between one layer's edge and the next
const RINGS_TOP := 24             # rows over the dome

# Draped goo layers: each hangs from height h and ends in tongues reaching up to `depth` lower. The middle one hangs
# just under the eyes like in the picture, which gives the face its droopy, grumpy look without drawing a mouth.
#   h, depth, tongues, phase, thickness, band above h
const LAYERS := [
	[1.0, 0.1, 4, 0.9, 0.03, 0.14],
	[0.64, 0.2, 5, 0.2, 0.042, 0.24],
	[0.33, 0.16, 6, 2.1, 0.04, 0.2],
]

const EYE_Y := 0.79
const EYE_LON := 0.4              # radians either side of the front
const EYE_R := 0.078
const ROLL := 0.06                # how round a goo layer's edge is as it rolls under

var goo: ShaderMaterial          # the body: drip mask on
var goo_still: ShaderMaterial    # feet and eye rims: same look, no oozing
var drips: Array[Vector3] = []   # where the drops fall from (tongue tips), in body space
var body_mesh: ArrayMesh


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	goo = ShaderMaterial.new()
	goo.resource_name = "Gloop Goo"
	goo.shader = load(SHADER)
	goo_still = goo.duplicate()
	goo_still.resource_name = "Gloop Goo (still)"
	goo_still.set_shader_parameter("use_drip_mask", false)
	body_mesh = _body_mesh()
	body_mesh.resource_name = "Gloop Body"
	print("body save=", ResourceSaver.save(body_mesh, BODY_MESH), " ", BODY_MESH)
	body_mesh = ResourceLoader.load(BODY_MESH, "", ResourceLoader.CACHE_MODE_REPLACE)   # so the scenes link to the file
	_save(_gloop("Gloop", "res://scripts/gloop.gd", false), OUT_DIR + "/gloop.tscn")
	_save(_gloop("Gloop King", "res://scripts/gloop_king.gd", true), OUT_DIR + "/gloop_king.tscn")
	quit()


func _save(root: Node, path: String) -> void:
	_own(root, root)
	var scene := PackedScene.new()
	print("pack=", scene.pack(root), " save=", ResourceSaver.save(scene, path), " ", path)
	root.free()


func _gloop(n: String, script: String, king: bool) -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = n
	root.set_script(load(script))

	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var body_shape := SphereShape3D.new()
	body_shape.radius = 0.42
	cs.shape = body_shape
	cs.position = Vector3(0, 0.42, 0)
	root.add_child(cs)

	var hitbox := Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hit_shape := SphereShape3D.new()
	hit_shape.radius = 0.62
	hcs.shape = hit_shape
	hcs.position = Vector3(0, 0.47, 0)
	hitbox.add_child(hcs)
	root.add_child(hitbox)

	# A wet shine on the ground under it. Kept off the Visual so it stays put when a bubble carries the Gloop away.
	var puddle := MeshInstance3D.new()
	puddle.name = "Puddle"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.55
	pm.bottom_radius = 0.55
	pm.height = 0.012
	pm.radial_segments = 28
	pm.rings = 1
	puddle.mesh = pm
	var wet := StandardMaterial3D.new()
	wet.resource_name = "Gloop Puddle"
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color = Color(0.12, 0.22, 0.05, 0.4)
	wet.metallic = 0.4
	wet.roughness = 0.03
	puddle.material_override = wet
	puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle.position = Vector3(0, 0.012, 0.02)
	puddle.scale = Vector3(1.0, 1.0, 0.85)
	root.add_child(puddle)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh
	body.material_override = goo
	visual.add_child(body)

	# Stubby feet, two in front and two behind, poking out under the belly (on the Visual, not the Body, so they
	# stay on the ground while the body bobs, and can waddle)
	var feet := Node3D.new()
	feet.name = "Feet"
	visual.add_child(feet)
	var k := 0
	for p in [Vector3(-0.19, 0.05, 0.16), Vector3(0.19, 0.05, 0.16), Vector3(-0.23, 0.05, -0.12), Vector3(0.23, 0.05, -0.12)]:
		var foot := _sphere(0.11, goo_still, 20, 10)
		foot.name = "Foot%d" % k
		foot.position = p
		foot.scale = Vector3(1.0, 0.6, 1.15)
		feet.add_child(foot)
		k += 1

	# Big dark glassy eyes, each sunk into a goo rim, with a little window-shine so they read at a distance
	var eye_mat := StandardMaterial3D.new()
	eye_mat.resource_name = "Gloop Eye"
	eye_mat.albedo_color = Color(0.03, 0.02, 0.05)
	eye_mat.metallic = 0.55
	eye_mat.roughness = 0.03
	eye_mat.clearcoat_enabled = true
	eye_mat.rim_enabled = true
	eye_mat.rim = 0.5
	eye_mat.rim_tint = 0.2
	var shine := StandardMaterial3D.new()
	shine.resource_name = "Gloop Eye Shine"
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.albedo_color = Color(1.0, 0.97, 0.92)
	for s in [-1, 1]:
		var lon: float = EYE_LON * s
		var lat := asin((EYE_Y - CENTER_Y) / TOP_HALF)
		var at := _surface(lat, lon)
		var normal := Vector3(at.x, (at.y - CENTER_Y) * 0.5, at.z).normalized()
		var rim := MeshInstance3D.new()
		rim.name = "EyeRim%s" % ("L" if s < 0 else "R")
		var tm := TorusMesh.new()
		tm.inner_radius = EYE_R * 0.85
		tm.outer_radius = EYE_R * 1.3
		tm.rings = 24
		tm.ring_segments = 12
		rim.mesh = tm
		rim.material_override = goo_still
		# The torus's hole looks out along the normal, and it's squashed flat so it reads as a soft socket, not a ring
		rim.basis = _facing(normal) * Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(1.0, 0.45, 1.0))
		rim.position = at + normal * 0.004
		body.add_child(rim)
		var eye := _sphere(EYE_R, eye_mat, 24, 12)
		eye.name = "Eye%s" % ("L" if s < 0 else "R")
		eye.basis = _facing(normal) * Basis.from_scale(Vector3(1.0, 0.85, 1.0))
		eye.position = at - normal * 0.01
		body.add_child(eye)
		var dot := _sphere(EYE_R * 0.2, shine, 10, 6)
		dot.name = "Shine"
		dot.position = Vector3(-0.3, 0.34, 0.86) * EYE_R      # up and to the left on the front, the same in both eyes
		eye.add_child(dot)

	# Where the drops fall from: every tongue's tip
	var marks := Node3D.new()
	marks.name = "Drips"
	body.add_child(marks)
	drips.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in drips.size():
		var m := Marker3D.new()
		m.name = "Drip%d" % i
		m.position = drips[i]
		marks.add_child(m)

	if king:
		body.add_child(_crown())
	return root


# --- The body ------------------------------------------------------------------------------------------------------

func _base(lat: float, lon: float) -> Vector3:
	# The plain blob before the goo layers: a dome on a fat belly
	var top := lat > 0.0
	var y := CENTER_Y + sin(lat) * (TOP_HALF if top else BOTTOM_HALF)
	var c := maxf(cos(lat), 0.0)
	var r := RADIUS * pow(c, 0.8 if top else 0.5) * (1.0 - 0.1 * maxf(sin(lat), 0.0))
	return Vector3(r * sin(lon), y, r * cos(lon))


func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


func _tongue(layer: Array, lon: float) -> Vector2:
	# How far this layer's edge hangs down at this longitude (0..1), and that tongue's own number for its timing
	var n: int = layer[2]
	var a: float = n * lon + layer[3] + 0.5 * sin(2.0 * lon + layer[3])
	var idx := floorf(a / TAU)
	var amp := 0.3 + 0.7 * _hash(idx + layer[3] * 7.0)                 # some tongues long, some short
	return Vector2(pow(maxf(sin(a), 0.0), 1.6) * amp, _hash(idx * 3.1 + layer[3]))      # wide, rounded tongues


func _surface(lat: float, lon: float) -> Vector3:
	return _shape(lat, lon)[0]


func _shape(lat: float, lon: float) -> Array:
	# The blob with its goo layers added: [point, drip mask, timing]
	var p := _base(lat, lon)
	var y := p.y
	var out := 0.0
	var mask := 0.0
	var timing := 0.0
	for layer in LAYERS:
		var h: float = layer[0]
		var tg := _tongue(layer, lon)
		var edge: float = h - layer[1] * tg.x
		if y > h + layer[5] or y < edge:
			continue
		var t: float = layer[4] * (1.0 + 0.6 * tg.x)
		var from_top := smoothstep(h + layer[5], h, y)                       # thickens toward its edge
		var u := clampf((y - edge) / ROLL, 0.0, 1.0)
		var rounded := sqrt(1.0 - (1.0 - u) * (1.0 - u))                     # and rolls under at the edge, round
		var lip := 1.0 + 0.35 * exp(-pow((y - edge - ROLL) / 0.03, 2.0))     # a fat rim, like poured goo
		out += t * from_top * rounded * lip
		if y < h:
			var m: float = tg.x * smoothstep(h, edge, y)
			if m > mask:
				mask = m
				timing = tg.y
	var flat := Vector2(p.x, p.z)
	if flat.length() > 0.0001:
		flat = flat.normalized() * (flat.length() + out)
	return [Vector3(flat.x, y, flat.y), mask, timing]


func _lat_of(y: float) -> float:
	var top := y > CENTER_Y
	return asin(clampf((y - CENTER_Y) / (TOP_HALF if top else BOTTOM_HALF), -1.0, 1.0))


func _column(lon: float) -> PackedFloat32Array:
	# The heights of one column's rows, bottom to top. Each layer's rolled edge gets its own block of rows that
	# follows the edge as it dips into each tongue, so the edges come out smooth instead of stair-stepped. The rest
	# is spread evenly by latitude, which keeps the dome's top round.
	var bottom := CENTER_Y - BOTTOM_HALF
	var top := CENTER_Y + TOP_HALF
	var marks: Array[float] = [bottom]
	var counts: Array[int] = []
	for k in range(LAYERS.size() - 1, -1, -1):              # lowest layer first
		var layer: Array = LAYERS[k]
		var edge: float = layer[0] - layer[1] * _tongue(layer, lon).x
		marks.append(edge)
		counts.append(RINGS_BETWEEN)
		marks.append(edge + ROLL * 1.3)
		counts.append(RINGS_EDGE)
	marks.append(top)
	counts.append(RINGS_TOP)
	var ys := PackedFloat32Array()
	for seg in counts.size():
		var a := _lat_of(marks[seg])
		var b := _lat_of(marks[seg + 1])
		var n := counts[seg]
		for r in n:
			var f := float(r) / n
			if counts[seg] == RINGS_EDGE:
				ys.append(lerpf(marks[seg], marks[seg + 1], f))       # even in height across the rolled edge
			else:
				var lat := lerpf(a, b, f)
				ys.append(CENTER_Y + sin(lat) * (TOP_HALF if lat > 0.0 else BOTTOM_HALF))
	ys.append(top)
	return ys


func _body_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips := {}
	var cols: Array[PackedFloat32Array] = []
	for i in COLUMNS:
		cols.append(_column(TAU * float(i) / COLUMNS))
	var rows := cols[0].size()
	for j in rows:
		for i in COLUMNS:
			var lon := TAU * float(i) / COLUMNS
			var s := _shape(_lat_of(cols[i][j]), lon)
			st.set_color(Color(s[1], s[2], 0.0))
			st.set_uv(Vector2(float(i) / COLUMNS, float(j) / (rows - 1)))
			st.add_vertex(s[0])
			# Remember the lowest point of each big tongue for the falling drops
			if s[1] > 0.25:
				var key := "%.2f" % s[2]
				if not tips.has(key) or (s[0] as Vector3).y < tips[key].y:
					tips[key] = s[0]
	for j in rows - 1:
		for i in COLUMNS:
			var a := j * COLUMNS + i
			var b := j * COLUMNS + (i + 1) % COLUMNS
			var c := (j + 1) * COLUMNS + i
			var d := (j + 1) * COLUMNS + (i + 1) % COLUMNS
			for v in [a, c, b, b, c, d]:                # clockwise seen from outside, as Godot wants
				st.add_index(v)
	st.generate_normals()
	for p in tips.values():
		drips.append(p * 1.02)
	return st.commit()


# --- The King's crown ----------------------------------------------------------------------------------------------

func _crown() -> Node3D:
	# A little gold crown with five points and a red gem, perched on the right of his head and tipped over a bit,
	# like in the picture
	var crown := Node3D.new()
	crown.name = "Crown"
	var gold := StandardMaterial3D.new()
	gold.resource_name = "Crown Gold"
	gold.albedo_color = Color(1.0, 0.74, 0.22)
	gold.metallic = 1.0
	gold.roughness = 0.28
	var gem := StandardMaterial3D.new()
	gem.resource_name = "Crown Gem"
	gem.albedo_color = Color(0.78, 0.02, 0.2)
	gem.metallic = 0.3
	gem.roughness = 0.04
	gem.emission_enabled = true
	gem.emission = Color(0.9, 0.05, 0.25)
	gem.emission_energy_multiplier = 0.35
	var band := MeshInstance3D.new()
	band.name = "Band"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.105
	bm.bottom_radius = 0.1
	bm.height = 0.06
	bm.radial_segments = 20
	bm.cap_top = false
	bm.cap_bottom = false
	band.mesh = bm
	var two_sided := gold.duplicate() as StandardMaterial3D
	two_sided.cull_mode = BaseMaterial3D.CULL_DISABLED
	band.material_override = two_sided
	band.position.y = 0.03
	crown.add_child(band)
	for i in 5:
		var a := TAU * i / 5.0
		var spike := MeshInstance3D.new()
		spike.name = "Point%d" % i
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = 0.045
		sm.height = 0.1
		sm.radial_segments = 4
		sm.rings = 1
		spike.mesh = sm
		spike.material_override = gold
		spike.position = Vector3(sin(a) * 0.092, 0.11, cos(a) * 0.092)
		spike.rotation.y = a
		spike.scale = Vector3(1.0, 1.0, 0.35)                 # flat points, like a paper crown cut from gold
		crown.add_child(spike)
	var stone := MeshInstance3D.new()
	stone.name = "Gem"
	var gm := SphereMesh.new()
	gm.radius = 0.024
	gm.height = 0.048
	gm.radial_segments = 4
	gm.rings = 2
	stone.mesh = gm
	stone.material_override = gem
	stone.position = Vector3(0, 0.035, 0.108)
	stone.scale = Vector3(1.0, 1.3, 0.6)
	crown.add_child(stone)
	var top := _surface(_lat_of(1.08), 0.9)
	crown.position = Vector3(top.x, top.y - 0.02, top.z)
	crown.rotation = Vector3(0.05, 0.3, -0.42)
	return crown


# --- Helpers -------------------------------------------------------------------------------------------------------

func _facing(normal: Vector3) -> Basis:
	# A basis whose +Z points along `normal` and whose Y stays roughly up
	var z := normal.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var y := z.cross(x)
	return Basis(x, y, z)


func _sphere(r: float, m: Material, seg := 16, rings := 8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = seg
	s.rings = rings
	mi.mesh = s
	mi.material_override = m
	return mi


func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)
