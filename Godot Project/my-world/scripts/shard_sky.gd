extends Node3D

# Shard Isle's dream sky. Hayden, 22 Nov 2026: "Can we add more cool background scenery like a sky box? Maybe some
# tripping visual effects". The island floats in the middle of nowhere, so it gets a sky that goes all the way round
# and a dreamy look, all put in at play time (shard_isle.gd calls SKY.place(self) in setup() and picture(), so the
# scene wasn't rebuilt):
# - **The sky** (dream_sky.gdshader, in place of the builder's plain gradient): a slowly swirling rainbow nebula,
#   twinkling stars, aurora ribbons, a ringed planet and a little moon.
# - **The Dream Islands**: nine big far-off islands round the edge of the sky, each with crystal spires and a
#   **lightfall** pouring off it into the clouds below, bobbing slowly. Four giant crystal monoliths turning far out.
# - **Sky jellies**: seven big glowing jellyfish drifting in slow loops beyond the warp islands, pulsing.
# - **Dream motes**: little glowing specks floating round the player.
# - **The dream haze** (dream_haze.gdshader, a layer under the HUD): the edges of the screen shimmer through the
#   rainbow, and stepping through a Warp Ring (shard_warps.gd calls trip()) swirls the picture and splits its
#   colours for a moment. Reduce motion stops it moving the picture; Reduce flashing makes the colours softer.
# None of it is solid, and nothing floats any differently than it did (Hayden: "Keep the forever floating").

const SKY_SHADER := preload("res://scripts/dream_sky.gdshader")
const HAZE_SHADER := preload("res://scripts/dream_haze.gdshader")
const ROCK := "res://models/props/shard_isle/island_rock.glb"   # the baked rock under Shard Isle's own islands

const PALETTE := [Color(0.55, 1.0, 0.8), Color(0.65, 0.8, 1.0), Color(1.0, 0.68, 0.92), Color(1.0, 0.86, 0.5),
	Color(0.78, 0.66, 1.0)]
const FAR_ISLANDS := 9
const FAR_MIN := 250.0                 # how far out the Dream Islands are (the warp islands reach about 57 m)
const FAR_MAX := 360.0
const MONOLITHS := 4
const JELLIES := 7
const JELLY_MIN := 72.0                # the jellies' loops, beyond every island you can stand on
const JELLY_MAX := 115.0
const MOTES := 70
const MOTE_BOX := 14.0                 # the motes float in a box this wide round the camera
const HAZE := 0.35                     # how strong the everyday haze is
const TRIP_TIME := 1.6                 # how long a warp's swirl lasts

var world: Node3D
var sky_mat: ShaderMaterial
var haze_mat: ShaderMaterial
var islands: Array[Node3D] = []        # (for tests)
var monoliths: Array[Node3D] = []
var jellies: Array[Node3D] = []
var motes: MultiMeshInstance3D
var trips := 0                         # (for tests) how many times trip() has run
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bob := {}                         # node -> [base position, phase, speed]
var _jelly := {}                       # jelly -> [centre, radius, height, phase, speed]
var _mote_at: Array[Vector3] = []
var _trip_tween: Tween


static func place(w: Node3D, preview := false) -> Node3D:
	var s = (load("res://scripts/shard_sky.gd") as GDScript).new()
	s.name = "Dream Sky"
	s.world = w
	w.add_child(s)
	s._build(preview)
	return s


func _build(preview: bool) -> void:
	_rng.seed = 2211
	_sky()
	_far_islands()
	_monoliths()
	_jellies()
	if not preview:
		_motes()
		_haze()


func motion() -> float:
	return 0.25 if Settings.reduce_motion else 1.0


func colour() -> float:
	return 0.5 if Settings.reduce_flashing else 1.0


# The sky ---------------------------------------------------------------------------------------------------------
func _sky() -> void:
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	# (A copy: the portal's preview loads this scene too, and each keeps its own)
	var env := we.environment.duplicate() as Environment
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("motion", motion())
	sky_mat.set_shader_parameter("colour", colour())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	# The far Dream Islands sit in a soft haze, not lost in it
	env.fog_density = 0.0018
	we.environment = env


# Far scenery -----------------------------------------------------------------------------------------------------
func _glow(c: Color, energy := 1.6, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _solid(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _mesh(parent: Node3D, mesh: Mesh, m: Material, at := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _cone(top_r: float, bottom_r: float, h: float, seg := 9) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _crystal(r: float, h: float) -> CylinderMesh:
	return _cone(0.0, r, h, 5)


func _rock(g: Node3D, r: float, h: float, at: Vector3, rock: Material) -> void:
	if ResourceLoader.exists(ROCK):
		var m := (load(ROCK) as PackedScene).instantiate() as Node3D
		m.scale = Vector3(r / 0.95, h / 1.3, r / 0.95)
		m.position = at
		m.rotation.y = _rng.randf() * TAU
		g.add_child(m)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		_mesh(g, _cone(r, r * 0.12, h, 10), rock, at + Vector3(0, -h * 0.5, 0))


func _lightfall(c: Color) -> StandardMaterial3D:
	# A column of light, bright where it leaves the island and fading away as it falls
	var grad := Gradient.new()
	grad.set_color(0, Color(c, 0.55))
	grad.set_color(1, Color(c, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var m := _glow(c, 1.5, 1.0)
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_texture = tex
	return m


func _far_islands() -> void:
	var holder := Node3D.new()
	holder.name = "Dream Islands"
	add_child(holder)
	var rock := _solid(Color(0.58, 0.5, 0.74))
	var moss := _solid(Color(0.62, 0.86, 0.78))
	for k in FAR_ISLANDS:
		var a := k * TAU / FAR_ISLANDS + _rng.randf_range(-0.2, 0.2)
		var d := _rng.randf_range(FAR_MIN, FAR_MAX)
		var r := _rng.randf_range(16.0, 34.0)
		var g := Node3D.new()
		g.name = "Dream Island %d" % (k + 1)
		g.position = Vector3(cos(a) * d, _rng.randf_range(-40.0, 60.0), sin(a) * d)
		g.rotation.y = _rng.randf() * TAU
		holder.add_child(g)
		# The same baked rock as Shard Isle's own islands (its top is at 0, 0.95 across and 1.3 deep), a mossy top,
		# and a second lump to break up the shape
		_rock(g, r, r * 1.5, Vector3.ZERO, rock)
		_mesh(g, _cone(r * 1.0, r * 0.97, r * 0.1, 14), moss, Vector3(0, r * 0.02, 0))
		var lump := r * _rng.randf_range(0.35, 0.55)
		_rock(g, lump, lump * 1.4, Vector3(r * 0.75, -lump * 0.25, r * 0.3), rock)
		var c: Color = PALETTE[k % PALETTE.size()]
		var glow := _glow(c, 2.2)
		for j in _rng.randi_range(3, 6):
			var p := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6)) * r
			var h := _rng.randf_range(0.4, 1.1) * r
			_mesh(g, _crystal(h * 0.18, h), glow, p + Vector3(0, r * 0.1 + h * 0.5, 0),
				Vector3(_rng.randf_range(-0.25, 0.25), 0, _rng.randf_range(-0.25, 0.25)))
		# The lightfall: a soft curtain of light pouring off its edge, fading as it falls
		var fall := _mesh(g, _cone(r * 0.12, r * 0.3, r * 3.0, 16), _lightfall(c), Vector3(r * 0.55, -r * 1.7, 0))
		fall.name = "Lightfall"
		islands.append(g)
		_bob[g] = [g.position, _rng.randf() * TAU, _rng.randf_range(0.12, 0.25)]


func _monoliths() -> void:
	var holder := Node3D.new()
	holder.name = "Dream Monoliths"
	add_child(holder)
	for k in MONOLITHS:
		var a := (k + 0.5) * TAU / MONOLITHS + 0.4
		var d := _rng.randf_range(300.0, 380.0)
		var g := Node3D.new()
		g.name = "Monolith %d" % (k + 1)
		g.position = Vector3(cos(a) * d, _rng.randf_range(10.0, 50.0), sin(a) * d)
		holder.add_child(g)
		var h := _rng.randf_range(60.0, 90.0)
		var c: Color = PALETTE[(k + 2) % PALETTE.size()]
		var m := _glow(c, 1.4, 0.8)
		_mesh(g, _cone(0.0, h * 0.14, h * 0.5, 6), m, Vector3(0, h * 0.25, 0))
		_mesh(g, _cone(h * 0.14, 0.0, h * 0.5, 6), m, Vector3(0, -h * 0.25, 0))
		g.rotation.z = _rng.randf_range(-0.3, 0.3)
		monoliths.append(g)
		_bob[g] = [g.position, _rng.randf() * TAU, 0.08]


func _jellies() -> void:
	var holder := Node3D.new()
	holder.name = "Sky Jellies"
	add_child(holder)
	for k in JELLIES:
		var c: Color = PALETTE[k % PALETTE.size()]
		var g := Node3D.new()
		g.name = "Sky Jelly %d" % (k + 1)
		holder.add_child(g)
		var size := _rng.randf_range(2.5, 4.5)
		var bell := SphereMesh.new()
		bell.radius = size
		bell.height = size * 1.3
		bell.is_hemisphere = true
		bell.radial_segments = 20
		bell.rings = 8
		_mesh(g, bell, _glow(c, 1.8, 0.45)).name = "Bell"
		var core := SphereMesh.new()
		core.radius = size * 0.35
		core.height = size * 0.5
		_mesh(g, core, _glow(Color(1, 1, 1), 2.4, 0.7), Vector3(0, size * 0.25, 0))
		# Trailing ribbons, waving as it drifts
		for j in 6:
			var ra := j * TAU / 6.0
			var q := QuadMesh.new()
			q.size = Vector2(size * 0.22, size * 2.6)
			var rib := _mesh(g, q, _glow(c, 1.2, 0.35), Vector3(cos(ra), 0, sin(ra)) * size * 0.55 + Vector3(0, -size * 1.3, 0),
				Vector3(0, -ra, 0))
			rib.name = "Ribbon %d" % (j + 1)
		var centre := Vector3(_rng.randf_range(-20.0, 20.0), 0, _rng.randf_range(-20.0, 20.0))
		_jelly[g] = [centre, _rng.randf_range(JELLY_MIN, JELLY_MAX), _rng.randf_range(-12.0, 38.0),
			k * TAU / JELLIES, _rng.randf_range(0.01, 0.02) * (1.0 if k % 2 == 0 else -1.0)]
		jellies.append(g)
	_move_jellies(0.0)


func jelly_at(g: Node3D, t: float) -> Vector3:
	var j: Array = _jelly[g]
	var a: float = j[3] + t * float(j[4])
	return Vector3(j[0]) + Vector3(cos(a), 0, sin(a)) * float(j[1]) + Vector3(0, float(j[2]) + sin(t * 0.3 + a) * 3.0, 0)


func _move_jellies(t: float) -> void:
	for g: Node3D in jellies:
		g.position = jelly_at(g, t)
		var pulse := 1.0 + sin(t * 1.6 + float(_jelly[g][3]) * 3.0) * 0.08 * motion()
		g.scale = Vector3(pulse, 2.0 - pulse, pulse)
		for r in g.get_children():
			if r.name.begins_with("Ribbon"):
				(r as Node3D).rotation.x = sin(t * 1.3 + r.get_index()) * 0.25 * motion()


# Close up ----------------------------------------------------------------------------------------------------------
func _motes() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	dot.radial_segments = 6
	dot.rings = 3
	mm.mesh = dot
	mm.instance_count = MOTES
	motes = MultiMeshInstance3D.new()
	motes.name = "Dream Motes"
	motes.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.8
	motes.material_override = m
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.top_level = true
	add_child(motes)
	for i in MOTES:
		_mote_at.append(Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * MOTE_BOX)
		mm.set_instance_color(i, PALETTE[i % PALETTE.size()] * 1.4)


func _haze() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.name = "Dream Haze"
	layer.layer = 1                                  # over the world, under the HUD and menus (like the flow)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze_mat = ShaderMaterial.new()
	haze_mat.shader = HAZE_SHADER
	haze_mat.set_shader_parameter("strength", HAZE)
	rect.material = haze_mat
	layer.add_child(rect)
	add_child(layer)
	_settings()


func _settings() -> void:
	if sky_mat:
		sky_mat.set_shader_parameter("motion", motion())
		sky_mat.set_shader_parameter("colour", colour())
	if haze_mat:
		haze_mat.set_shader_parameter("melt", 0.0 if Settings.reduce_motion else 1.0)
		haze_mat.set_shader_parameter("colour", colour())


func trip() -> void:
	# A Warp Ring swirls the world round you for a moment, then it settles
	trips += 1
	if haze_mat == null:
		return
	if _trip_tween:
		_trip_tween.kill()
	var peak := 0.45 if Settings.reduce_flashing else 1.0
	haze_mat.set_shader_parameter("trip", peak)
	_trip_tween = create_tween()
	_trip_tween.tween_method(func(v: float): haze_mat.set_shader_parameter("trip", v), peak, 0.0, TRIP_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_t += delta
	var mo := motion()
	for g: Node3D in _bob:
		var b: Array = _bob[g]
		g.position = Vector3(b[0]) + Vector3(0, sin(_t * float(b[2]) + float(b[1])) * 3.0 * mo, 0)
		if g in monoliths:
			g.rotate_y(delta * 0.05 * mo)
	_move_jellies(_t)
	if motes:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var c := cam.global_position
			var corner := c - Vector3.ONE * MOTE_BOX * 0.5
			var mm := motes.multimesh
			for i in MOTES:
				var p := _mote_at[i] + Vector3(sin(_t * 0.3 + i), 0.35, cos(_t * 0.25 + i * 1.7)) * delta * 0.4 * mo
				_mote_at[i] = p
				# Wrap round the box, so there are always motes about wherever the camera goes
				var w := Vector3(fposmod(p.x - corner.x, MOTE_BOX), fposmod(p.y - corner.y, MOTE_BOX),
					fposmod(p.z - corner.z, MOTE_BOX)) + corner
				var tw := 0.6 + 0.4 * sin(_t * 2.0 + i * 0.7)
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * tw), w))
	if Engine.get_process_frames() % 30 == 0:
		_settings()
