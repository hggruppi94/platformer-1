extends Node3D

# Dream skies for the portal worlds (Hayden, 22 Nov 2026: Shard Isle's dream sky was "Much better", then "Yes" to
# giving the other worlds skies of their own). Shard Isle keeps its own (shard_sky.gd). Every other world calls
# WORLD_SKY.place(self, "<world>") at the end of its setup() and picture(), so no scene was rebuilt.
#
# - **The sky** (world_dream_sky.gdshader): the world's own sky colours are copied in every frame from its
#   ProceduralSkyMaterial, so a world that changes its sky as you play (Lanternmoor's dawn, Glenmoor's day and night,
#   the Tide Reef's tide, the Far Future fading, Rhythm Springs cooling, Dark Hollow mending) still does. Over that go
#   the world's own dream parts (THEMES): a nebula and stars that come out as it gets dark, aurora ribbons, sometimes
#   a planet or a moon. The light the world gets from its sky is the same gradient it had, so nothing's lit differently.
# - **Far scenery** (THEMES "far"), well out past anywhere you can walk, never solid, never in the fog:
#     Rootmind        dandelion seeds drifting round and giant flowers far off
#     Frozen Moment   giant ice shards hanging still in the sky (they turn once it's mended and time moves again)
#     Lanternmoor     sky lanterns rising for ever, and big glowing moths
#     Glenmoor        slow clouds coloured by the time of day, and floating stones, half sun-gold, half moon-blue
#     Tide Reef       big bubbles rising up the sky and glowing jellyfish, as if the sea were overhead
#     Rhythm Springs  giant music notes bobbing round the island under a ringed sunset planet
#     Dark Hollow     ghostly wisps weaving round the hollow
#     Far Future      holo rings turning and sky ships gliding round the city
# - **A soft dream haze** round the screen's edges (dream_haze.gdshader, gentler than Shard Isle's), not in previews.
# Reduce motion slows everything right down; Reduce flashing makes the colours softer.

const SKY_SHADER := preload("res://scripts/world_dream_sky.gdshader")
const HAZE_SHADER := preload("res://scripts/dream_haze.gdshader")

# Shader settings (any uniform of world_dream_sky.gdshader), the haze, and the far scenery: [kind, how many, nearest,
# furthest, lowest, highest, colours]
const THEMES := {
	"rootmind": {
		"sky": {"deepen": 0.15, "nebula": 0.45, "nebula_day": 0.35, "nebula_hue": 0.18, "nebula_spread": 0.5,
			"nebula_tint": Vector3(1.0, 1.15, 0.7), "stars": 0.6, "star_day": 0.05, "aurora": 0.45, "aurora_hue": 0.15,
			"aurora_spread": 0.12, "moon": 1.0, "moon_size": 0.05, "moon_colour": Color(0.92, 1.0, 0.82),
			"moon_dir": Vector3(0.5, 0.5, -0.7)},
		"haze": 0.16,
		"far": [["seed", 16, 120.0, 230.0, 18.0, 90.0, [Color(1, 1, 0.92), Color(0.95, 1.0, 0.85)]],
			["bloom", 6, 250.0, 330.0, -20.0, 20.0, [Color(1.0, 0.6, 0.85), Color(1.0, 0.86, 0.45),
				Color(0.75, 0.6, 1.0)]]],
	},
	"frozen_moment": {
		"sky": {"deepen": 0.3, "nebula": 0.25, "nebula_day": 0.3, "nebula_hue": 0.5, "nebula_spread": 0.35,
			"nebula_tint": Vector3(0.75, 0.95, 1.2), "stars": 0.9, "star_day": 0.2, "aurora": 1.0, "aurora_hue": 0.38,
			"aurora_spread": 0.1, "moon": 1.0, "moon_size": 0.075, "moon_colour": Color(0.9, 0.96, 1.0),
			"moon_dir": Vector3(-0.6, 0.45, 0.65)},
		"haze": 0.12,
		"far": [["ice", 11, 200.0, 320.0, 30.0, 110.0, [Color(0.7, 0.92, 1.0), Color(0.85, 0.9, 1.0),
			Color(0.7, 1.0, 0.95)]]],
	},
	"lanternmoor": {
		"sky": {"deepen": 0.0, "nebula": 0.6, "nebula_day": 0.25, "nebula_hue": 0.7, "nebula_spread": 0.45,
			"nebula_tint": Vector3(1.05, 0.8, 1.2), "stars": 1.0, "aurora": 0.3, "aurora_hue": 0.05,
			"aurora_spread": 0.15},
		"haze": 0.18,
		"far": [["lantern", 42, 90.0, 260.0, -10.0, 160.0, [Color(1.0, 0.62, 0.3), Color(1.0, 0.78, 0.4),
				Color(1.0, 0.5, 0.6)]],
			["moth", 5, 140.0, 220.0, 40.0, 90.0, [Color(0.95, 0.6, 1.0), Color(0.6, 0.9, 1.0)]]],
	},
	"glenmoor": {
		"sky": {"deepen": 0.15, "nebula": 0.35, "nebula_day": 0.1, "nebula_hue": 0.6, "nebula_spread": 0.5,
			"stars": 1.0, "star_day": 0.0, "aurora": 0.35, "aurora_hue": 0.55, "aurora_spread": 0.2},
		"haze": 0.1,
		"far": [["cloud", 11, 190.0, 300.0, 45.0, 100.0, [Color(1, 1, 1)]],
			["stone", 8, 250.0, 320.0, 25.0, 70.0, [Color(1.0, 0.8, 0.35), Color(0.45, 0.65, 1.0)]]],
	},
	"tide_reef": {
		"sky": {"deepen": 0.2, "nebula": 0.4, "nebula_day": 0.35, "nebula_hue": 0.45, "nebula_spread": 0.35,
			"nebula_tint": Vector3(0.7, 1.1, 1.15), "stars": 0.5, "star_day": 0.08, "aurora": 0.6, "aurora_hue": 0.42,
			"aurora_spread": 0.12, "planet": 1.0, "ring": 0.0, "planet_size": 0.11,
			"planet_a": Color(0.98, 0.94, 0.96), "planet_b": Color(1.0, 0.78, 0.86),
			"planet_dir": Vector3(0.55, 0.35, -0.75)},
		"haze": 0.18,
		"far": [["bubble", 30, 110.0, 250.0, -20.0, 170.0, [Color(0.7, 0.95, 1.0), Color(0.85, 0.85, 1.0)]],
			["jelly", 6, 95.0, 150.0, 20.0, 60.0, [Color(1.0, 0.6, 0.85), Color(0.55, 0.95, 1.0),
				Color(0.75, 0.65, 1.0)]]],
	},
	"rhythm_springs": {
		"sky": {"deepen": 0.15, "nebula": 0.35, "nebula_day": 0.3, "nebula_hue": 0.0, "nebula_spread": 0.9,
			"stars": 0.6, "star_day": 0.05, "aurora": 0.5, "aurora_hue": 0.0, "aurora_spread": 0.4, "planet": 1.0,
			"ring": 1.0, "planet_size": 0.13, "planet_a": Color(1.0, 0.6, 0.45), "planet_b": Color(1.0, 0.85, 0.5),
			"planet_dir": Vector3(-0.7, 0.3, 0.65)},
		"haze": 0.16,
		"far": [["note", 14, 240.0, 340.0, 30.0, 120.0, [Color(1.0, 0.45, 0.7), Color(0.5, 0.9, 1.0),
			Color(1.0, 0.85, 0.35), Color(0.7, 0.55, 1.0), Color(0.5, 1.0, 0.7)]]],
	},
	"dark_hollow": {
		"sky": {"deepen": 0.0, "nebula": 0.5, "nebula_hue": 0.72, "nebula_spread": 0.3,
			"nebula_tint": Vector3(0.75, 0.75, 1.15), "stars": 1.0, "aurora": 0.25, "aurora_hue": 0.62,
			"aurora_spread": 0.1},
		"haze": 0.2,
		"far": [["wisp", 18, 110.0, 210.0, 10.0, 70.0, [Color(0.6, 0.8, 1.0), Color(0.8, 0.65, 1.0)]]],
	},
	"far_future": {
		"sky": {"deepen": 0.1, "nebula": 0.6, "nebula_day": 0.6, "nebula_hue": 0.85, "nebula_spread": 0.4,
			"nebula_tint": Vector3(1.1, 0.85, 1.15), "stars": 0.9, "star_day": 0.3, "aurora": 0.4, "aurora_hue": 0.5,
			"aurora_spread": 0.3, "planet": 1.0, "ring": 1.0, "planet_size": 0.19,
			"planet_a": Color(0.55, 0.7, 1.0), "planet_b": Color(0.95, 0.55, 0.9), "planet_dir": Vector3(0.6, 0.4, 0.7),
			"moon": 1.0, "moon_size": 0.03, "moon_dir": Vector3(-0.5, 0.6, -0.6)},
		"haze": 0.14,
		"far": [["holo", 6, 220.0, 320.0, 40.0, 110.0, [Color(0.3, 1.0, 1.0), Color(1.0, 0.4, 0.85)]],
			["ship", 10, 150.0, 280.0, 50.0, 120.0, [Color(0.3, 1.0, 1.0), Color(1.0, 0.45, 0.85),
				Color(1.0, 0.85, 0.4)]]],
	},
}

# How much bigger each kind is drawn than it's built (they're far off, so they need to be big to read)
const BIG := {"seed": 2.4, "lantern": 2.0, "moth": 2.0, "stone": 1.5, "bubble": 2.2, "jelly": 2.0, "note": 2.0,
	"wisp": 2.5, "ship": 2.2, "holo": 1.4, "ice": 1.2}

var world: Node3D
var theme := ""
var sky_mat: ShaderMaterial
var haze_mat: ShaderMaterial
var src: ProceduralSkyMaterial                 # the world's own sky, which it keeps changing
var far: Array[Node3D] = []                    # (for tests) every far thing
var _move := {}                                # far thing -> [kind, centre angle, radius, height, phase, speed, ...]
var _clouds: Array[StandardMaterial3D] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _last := []


static func place(w: Node3D, which: String, preview := false) -> Node3D:
	if not THEMES.has(which):
		return null
	var old := w.get_node_or_null("Dream Sky")
	if old:
		return old
	var s = (load("res://scripts/world_sky.gd") as GDScript).new()
	s.name = "Dream Sky"
	s.world = w
	s.theme = which
	w.add_child(s)
	s._build(preview)
	return s


func motion() -> float:
	return 0.25 if Settings.reduce_motion else 1.0


func colour() -> float:
	return 0.5 if Settings.reduce_flashing else 1.0


func mended() -> bool:
	var id = world.get("world_id")
	return id != null and str(id) != "" and Portals.is_cleared(str(id))


func _build(preview: bool) -> void:
	_rng.seed = hash(theme)
	_sky()
	for f: Array in THEMES[theme].far:
		_far(f)
	if not preview:
		_haze()
	_follow(true)
	_place_far(0.0)


# The sky -----------------------------------------------------------------------------------------------------------
func _sky() -> void:
	var we := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null:
		return
	# The world's own sky stays as the colours to follow (some worlds keep changing it in _sky)
	var own = world.get("_sky")
	src = own as ProceduralSkyMaterial if own is ProceduralSkyMaterial else null
	var env := we.environment
	if src == null and env.sky:
		src = env.sky.sky_material as ProceduralSkyMaterial
	# A world that made its own copy of its environment keeps changing that one, so use it as it is; otherwise copy it
	# (the portal's preview loads the same scene, and each keeps its own)
	if world.get("_env") != env:
		env = env.duplicate() as Environment
		we.environment = env
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	for k: String in THEMES[theme].sky:
		var v = THEMES[theme].sky[k]
		if v is Color:
			v = Vector3(v.r, v.g, v.b)
		sky_mat.set_shader_parameter(k, v)
	_settings()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky


func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _follow(force := false) -> void:
	# Copy the world's own sky colours in (only when they've changed, so the light isn't worked out again for nothing)
	if src == null or sky_mat == null:
		return
	var now := [src.sky_top_color, src.sky_horizon_color, src.ground_bottom_color]
	if not force and now == _last:
		return
	_last = now
	sky_mat.set_shader_parameter("top_colour", _v(src.sky_top_color))
	sky_mat.set_shader_parameter("light_top", _v(src.sky_top_color))
	sky_mat.set_shader_parameter("horizon_colour", _v(src.sky_horizon_color))
	sky_mat.set_shader_parameter("below_colour", _v(src.ground_bottom_color))
	sky_mat.set_shader_parameter("light_below", _v(src.ground_bottom_color))
	# Glenmoor's clouds take the colour of the time of day
	var lum := src.sky_top_color.get_luminance()
	for m in _clouds:
		var c := Color(1, 1, 1).lerp(src.sky_horizon_color, 0.35) * lerpf(0.35, 1.05, clampf(lum * 1.6, 0.0, 1.0))
		m.albedo_color = Color(c, 0.85)


# Far scenery -------------------------------------------------------------------------------------------------------
func _mat(c: Color, energy := 1.6, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.emission_enabled = energy > 0.0
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true                           # far out in the sky, not lost in the world's mist
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func _cone(top_r: float, bottom_r: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


func _far(f: Array) -> void:
	var kind: String = f[0]
	var holder := Node3D.new()
	holder.name = "Far " + kind.capitalize()
	add_child(holder)
	var cols: Array = f[6]
	for k in int(f[1]):
		var c: Color = cols[k % cols.size()]
		var g := Node3D.new()
		g.name = "%s %d" % [kind.capitalize(), k + 1]
		holder.add_child(g)
		var size := 1.0
		match kind:
			"seed": size = _seed(g, c)
			"bloom": size = _bloom(g, c)
			"ice": size = _ice(g, c)
			"lantern": size = _lantern(g, c)
			"moth": size = _moth(g, c)
			"cloud": size = _cloud(g)
			"stone": size = _stone(g, c, k)
			"bubble": size = _bubble(g, c)
			"jelly": size = _jelly(g, c)
			"note": size = _note(g, c)
			"wisp": size = _wisp(g, c)
			"holo": size = _holo(g, c)
			"ship": size = _ship(g, c)
		var a := k * TAU / float(f[1]) + _rng.randf_range(-0.25, 0.25)
		var speed := 0.0
		match kind:
			"seed", "cloud", "moth", "wisp": speed = _rng.randf_range(0.004, 0.012)
			"jelly", "ship": speed = _rng.randf_range(0.012, 0.025)
			"note", "holo": speed = _rng.randf_range(0.003, 0.008)
		if k % 2 == 1:
			speed = -speed
		_move[g] = [kind, a, _rng.randf_range(f[2], f[3]), _rng.randf_range(f[4], f[5]), _rng.randf() * TAU, speed,
			float(f[4]), float(f[5]), size, _rng.randf_range(0.6, 1.4), float(BIG.get(kind, 1.0))]
		g.scale = Vector3.ONE * float(BIG.get(kind, 1.0))
		g.set_meta("far_kind", kind)
		far.append(g)


func _seed(g: Node3D, c: Color) -> float:
	# A dandelion seed puff: a glowing heart and fluffy spokes with a tuft on each end
	var s := _rng.randf_range(4.0, 7.5)
	var fluff := _mat(c, 1.3, 0.75)
	_mesh(g, _ball(s * 0.16), _mat(Color(1.0, 0.92, 0.6), 2.0))
	for j in 14:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1), _rng.randf_range(-1, 1)).normalized()
		var spoke := _mesh(g, _cone(s * 0.012, s * 0.012, s, 4), fluff, dir * s * 0.5)
		spoke.look_at_from_position(dir * s * 0.5, dir * s * 2.0, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		spoke.rotate_object_local(Vector3.RIGHT, PI / 2)
		_mesh(g, _ball(s * 0.1, 6), fluff, dir * s)
	# Its long stalk trailing below
	_mesh(g, _cone(s * 0.02, s * 0.02, s * 1.6, 4), _mat(Color(0.9, 1.0, 0.8), 0.8, 0.6), Vector3(0, -s * 0.8, 0))
	return s


func _bloom(g: Node3D, c: Color) -> float:
	# A giant flower far off, its stem rising out of the mist below
	var s := _rng.randf_range(22.0, 36.0)
	_mesh(g, _cone(s * 0.05, s * 0.08, s * 5.0, 6), _mat(Color(0.35, 0.6, 0.35), 0.4), Vector3(0, -s * 2.5, 0))
	var petal := _mat(c, 1.0, 0.92)
	for j in 7:
		var a := j * TAU / 7.0
		var p := _mesh(g, _ball(s * 0.32, 10), petal, Vector3(cos(a), 0.15, sin(a)) * s * 0.42)
		p.scale = Vector3(1.0, 0.22, 0.55)
		p.rotation.y = -a
	_mesh(g, _ball(s * 0.2, 10), _mat(Color(1.0, 0.9, 0.5), 2.2), Vector3(0, s * 0.08, 0))
	return s


func _ice(g: Node3D, c: Color) -> float:
	# A giant ice shard hanging in the sky, point down, with little ones round it
	var h := _rng.randf_range(30.0, 60.0)
	var m := _mat(c, 1.1, 0.7)
	_mesh(g, _cone(h * 0.16, 0.0, h * 0.75, 6), m, Vector3(0, -h * 0.25, 0))
	_mesh(g, _cone(0.0, h * 0.16, h * 0.25, 6), m, Vector3(0, h * 0.25, 0))
	for j in 3:
		var a := j * TAU / 3.0 + 0.5
		var sh := h * _rng.randf_range(0.2, 0.35)
		_mesh(g, _cone(sh * 0.16, 0.0, sh, 6), m, Vector3(cos(a), 0, sin(a)) * h * 0.35 + Vector3(0, -sh * 0.3, 0),
			Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
	g.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, _rng.randf_range(-0.15, 0.15))
	return h


func _lantern(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(1.8, 3.4)
	_mesh(g, _cone(s * 0.42, s * 0.32, s, 8), _mat(c, 2.0, 0.9))
	_mesh(g, _ball(s * 0.2, 8), _mat(Color(1.0, 0.95, 0.75), 3.0), Vector3(0, -s * 0.25, 0))
	return s


func _moth(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(8.0, 12.0)
	_mesh(g, _cone(s * 0.06, s * 0.08, s * 0.7, 6), _mat(Color(0.95, 0.85, 1.0), 1.4), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Wing L" if side < 0 else "Wing R"
		g.add_child(pivot)
		var q := QuadMesh.new()
		q.size = Vector2(s, s * 0.8)
		_mesh(pivot, q, _mat(c, 1.5, 0.6), Vector3(side * s * 0.5, 0, 0), Vector3(-PI / 2, 0, 0))
	return s


func _cloud(g: Node3D) -> float:
	var s := _rng.randf_range(14.0, 26.0)
	var m := _mat(Color(1, 1, 1), 0.0, 0.85)
	_clouds.append(m)
	for j in _rng.randi_range(5, 8):
		var p := Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.15, 0.25), _rng.randf_range(-0.5, 0.5)) * s
		var b := _mesh(g, _ball(s * _rng.randf_range(0.4, 0.7), 10), m, p)
		b.scale.y = 0.6
	return s


func _stone(g: Node3D, c: Color, k: int) -> float:
	# Floating standing stones: half glow gold like the Sunfolk's sun, half blue like the Moonfolk's moon
	var h := _rng.randf_range(12.0, 20.0)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.45, 0.43, 0.48)
	rock.roughness = 0.95
	rock.disable_fog = true
	var b := BoxMesh.new()
	b.size = Vector3(h * 0.32, h, h * 0.2)
	_mesh(g, b, rock)
	var rune := BoxMesh.new()
	rune.size = Vector3(h * 0.12, h * 0.5, h * 0.02)
	_mesh(g, rune, _mat(c, 2.4), Vector3(0, h * 0.05, h * 0.105))
	_mesh(g, rune, _mat(c, 2.4), Vector3(0, h * 0.05, -h * 0.105))
	var under := _mesh(g, _cone(h * 0.2, 0.0, h * 0.4, 6), _mat(c, 1.2, 0.35), Vector3(0, -h * 0.75, 0))
	under.name = "Glow"
	return h


func _bubble(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(2.0, 6.0)
	_mesh(g, _ball(s, 16), _mat(c, 0.6, 0.22))
	_mesh(g, _ball(s * 0.18, 6), _mat(Color(1, 1, 1), 2.0, 0.8), Vector3(-s * 0.45, s * 0.5, s * 0.45))
	return s


func _jelly(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(3.0, 5.0)
	var bell := SphereMesh.new()
	bell.radius = s
	bell.height = s * 1.3
	bell.is_hemisphere = true
	bell.radial_segments = 20
	bell.rings = 8
	_mesh(g, bell, _mat(c, 1.8, 0.45)).name = "Bell"
	_mesh(g, _ball(s * 0.35), _mat(Color(1, 1, 1), 2.4, 0.7), Vector3(0, s * 0.25, 0))
	for j in 6:
		var ra := j * TAU / 6.0
		var q := QuadMesh.new()
		q.size = Vector2(s * 0.22, s * 2.6)
		var rib := _mesh(g, q, _mat(c, 1.2, 0.35), Vector3(cos(ra), 0, sin(ra)) * s * 0.55 + Vector3(0, -s * 1.3, 0),
			Vector3(0, -ra, 0))
		rib.name = "Ribbon %d" % (j + 1)
	return s


func _note(g: Node3D, c: Color) -> float:
	# A giant glowing music note: a round head, a stem and a flag (two heads joined by a beam now and then)
	var s := _rng.randf_range(10.0, 18.0)
	var m := _mat(c, 2.0)
	var two := _rng.randf() < 0.4
	for i in (2 if two else 1):
		var x := i * s * 0.9
		var head := _mesh(g, _ball(s * 0.22, 12), m, Vector3(x, 0, 0), Vector3(0, 0, 0.45))
		head.scale = Vector3(1.3, 0.85, 0.6)
		_mesh(g, _cone(s * 0.04, s * 0.04, s, 5), m, Vector3(x + s * 0.24, s * 0.5, 0))
	var flag := BoxMesh.new()
	if two:
		flag.size = Vector3(s * 0.95, s * 0.14, s * 0.08)
		_mesh(g, flag, m, Vector3(s * 0.69, s, 0), Vector3(0, 0, -0.12))
	else:
		flag.size = Vector3(s * 0.4, s * 0.12, s * 0.08)
		_mesh(g, flag, m, Vector3(s * 0.42, s * 0.88, 0), Vector3(0, 0, -0.6))
	return s


func _wisp(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(2.0, 3.6)
	_mesh(g, _ball(s * 0.5, 10), _mat(c, 2.2, 0.75))
	_mesh(g, _ball(s * 0.22, 8), _mat(Color(1, 1, 1), 2.6, 0.85))
	var tail := _mesh(g, _cone(s * 0.45, 0.0, s * 2.4, 8), _mat(c, 1.2, 0.35), Vector3(0, 0, s * 1.2),
		Vector3(-PI / 2, 0, 0))
	tail.name = "Tail"
	return s


func _holo(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(18.0, 30.0)
	var t := TorusMesh.new()
	t.inner_radius = s * 0.92
	t.outer_radius = s
	t.rings = 48
	t.ring_segments = 6
	_mesh(g, t, _mat(c, 2.4, 0.8))
	var t2 := TorusMesh.new()
	t2.inner_radius = s * 0.62
	t2.outer_radius = s * 0.66
	t2.rings = 40
	t2.ring_segments = 6
	_mesh(g, t2, _mat(c, 1.6, 0.5), Vector3.ZERO, Vector3(0.4, 0, 0)).name = "Inner"
	g.rotation = Vector3(_rng.randf_range(0.3, 1.2), _rng.randf() * TAU, 0)
	return s


func _ship(g: Node3D, c: Color) -> float:
	var s := _rng.randf_range(6.0, 11.0)
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.82, 0.85, 0.95)
	hull.metallic = 0.6
	hull.roughness = 0.3
	hull.disable_fog = true
	var body := _mesh(g, _ball(s * 0.5, 12), hull)
	body.scale = Vector3(0.45, 0.3, 1.0)
	var strip := BoxMesh.new()
	strip.size = Vector3(s * 0.47, s * 0.03, s * 0.8)
	_mesh(g, strip, _mat(c, 3.0))
	_mesh(g, _ball(s * 0.08, 6), _mat(c, 3.5), Vector3(0, 0, s * 0.52))
	return s


func _place_far(t: float) -> void:
	var mo := motion()
	var go := not (theme == "frozen_moment" and not mended())     # time's stopped there till it's mended
	for g: Node3D in _move:
		var m: Array = _move[g]
		var kind: String = m[0]
		var a: float = float(m[1]) + (t * float(m[5]) if go else 0.0)
		var r: float = m[2]
		var y: float = m[3]
		var ph: float = m[4]
		var tt := t if go else 0.0
		match kind:
			"lantern", "bubble":
				# Rising for ever: back to the bottom once out of sight at the top
				var lo: float = m[6]
				var hi: float = m[7]
				var rate := (1.3 if kind == "lantern" else 2.2) * float(m[9])
				y = lo + fposmod(y - lo + tt * rate, hi - lo)
				a += sin(tt * 0.05 + ph) * 0.03
			_:
				y += sin(tt * 0.3 + ph) * 3.0
		var at := Vector3(cos(a) * r, y, sin(a) * r)
		if kind == "wisp":
			at += Vector3(sin(tt * 0.7 + ph), sin(tt * 1.1 + ph) * 0.6, cos(tt * 0.6 + ph)) * 8.0
		if kind in ["moth", "wisp", "ship", "jelly"]:
			# Face the way they're drifting round
			var ahead := Vector3(cos(a + signf(float(m[5])) * 0.05) * r, at.y, sin(a + signf(float(m[5])) * 0.05) * r)
			if ahead.distance_to(at) > 0.01:
				g.look_at_from_position(at, ahead, Vector3.UP)
				if kind == "wisp":
					g.rotate_object_local(Vector3.UP, PI)
				g.scale = Vector3.ONE * float(m[10])
		g.position = at
		match kind:
			"seed", "bloom", "stone":
				g.rotation.y = ph + tt * 0.02
				g.rotation.z = sin(tt * 0.2 + ph) * 0.08
			"ice":
				if go:
					g.rotation.y = ph + tt * 0.03
			"note":
				g.rotation.y = -a + PI / 2
				g.rotation.z = sin(tt * 1.2 + ph) * 0.15 * mo
			"holo":
				g.rotate_object_local(Vector3.UP, 0.003 * mo)
			"moth":
				var flap := sin(tt * 3.0 + ph) * 0.6 * mo
				(g.get_node("Wing L") as Node3D).rotation.z = flap
				(g.get_node("Wing R") as Node3D).rotation.z = -flap
			"jelly":
				var pulse := 1.0 + sin(tt * 1.6 + ph) * 0.08 * mo
				g.scale = Vector3(pulse, 2.0 - pulse, pulse) * float(m[10])
				g.rotation.x = 0.0


# Close up ----------------------------------------------------------------------------------------------------------
func _haze() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.name = "Dream Haze"
	layer.layer = 1                                  # over the world, under the HUD and menus
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze_mat = ShaderMaterial.new()
	haze_mat.shader = HAZE_SHADER
	haze_mat.set_shader_parameter("strength", float(THEMES[theme].haze))
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


func _process(delta: float) -> void:
	_t += delta * motion()
	_follow()
	_place_far(_t)
	if Engine.get_process_frames() % 30 == 0:
		_settings()
