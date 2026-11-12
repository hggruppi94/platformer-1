extends Node3D

# The Star Arena (Hayden, 12 Nov 2026: "I want to add an arena with uinque bosses, and challenges like slay 100 gloops
# etc."). A level of its own (scenes/bosses/arena.tscn, made by tools/build_arena.gd: only this script, an Entrance and
# the player). Everything else is built here when it loads, like the Gloop Kingdom (scripts/gloop_kingdom.gd). The way
# in is the Arena Gate at the foot of the castle school's hill (scripts/arena.gd, the "Arena" autoload, which also
# keeps the list of rounds and your records).
#
# An open-air stadium under an evening sky: a round sandy floor (FLOOR_R) inside a low wall, stands all round full of
# little aliens who cheer every pop, four tall spotlight towers, six glowing hatches round the floor where the enemies
# come out, and a tunnel in from the south. Just inside the tunnel stand Blip, the arena's little alien announcer
# (a Void resident, like the crowd), and the Round Board: talk to either to pick a round (Arena.CHALLENGES).
#   - "count":  pop `goal` of them, `at_once` out at a time (every Glorp bit counts).
#   - "timed":  the same against the clock (`time` seconds); time up and the round's over.
#   - "waves":  a wave of `goal[i]` at once; pop them all for the next.
#   - "boss":   one of the arena's own bosses comes out of the big middle hatch.
#   - "rush":   the Champion's Cup: the bosses one after another.
# "dark" rounds bring the night down: the floodlights dim and the four spotlights sweep round the floor (lit_at(),
# beam_push(): the Gloam, scripts/the_gloam.gd, can only be popped in a beam).
# While a round's on, a bar of light closes the tunnel (so nothing wanders off) and the HUD at the top counts. Talk to
# Blip to stop it. Fainting starts the arena again (Game.faint reloads the scene), so nothing's ever lost.
# The way out is the end of the tunnel, back to the Void in front of the gate (Arena.gate_out()).

const TOWN := "res://scenes/town/town.tscn"
const USE_SPOT := preload("res://scripts/use_spot.gd")
const GLORP := preload("res://scripts/glorp.gd")
const FIZZLER := preload("res://scripts/fizzler.gd")
const SHADOW_GHOST := preload("res://scripts/shadow_ghost.gd")
const MOTHER := preload("res://scripts/glorp_mother.gd")
const BIG_BUZZ := preload("res://scripts/big_buzz.gd")
const GLOAM := preload("res://scripts/the_gloam.gd")
const GLOOP_SCENE := "res://scenes/enemies/gloop.tscn"
const GOBLIN_SCENE := "res://scenes/enemies/time_goblin.tscn"

const FLOOR_R := 24.0                         # the sandy floor's radius
const WALL_R := 25.5                          # the low wall round it
const GAP := 3.0                              # half the tunnel's width
const TUNNEL_END := 40.0                      # the tunnel runs from the wall out to here (south, +z)
const HATCH_R := 17.0
const HATCHES := 6
const HOST_AT := Vector3(-3.6, 0, 21.0)       # Blip, just inside the tunnel
const BOARD_AT := Vector3(3.6, 0, 21.0)       # the Round Board
const BOSS_AT := Vector3(0, 0, -6.0)
const BEAM_R := 3.4                           # a spotlight's circle on the floor
const BEAM_PATH := 11.0                       # how far out from the middle the beams sweep
const HOST := "Blip"
const RECORD := "arena_pick"                  # the menu's answers (taken off Dialogue.choice_log again after)

var round_id := ""                            # the round that's on ("" for none)
var count := 0                                # popped this round
var elapsed := 0.0
var time_left := 0.0
var wave := 0
var dark := false
var boss: Node3D
var _boss_queue: Array = []
var _live: Array[Node] = []
var _seen := {}
var _starting := 0.0                          # >0: the countdown before the first ones come out
var _next_wave := 0.0
var _spawned := 0
var _won_banner := 0.0
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _crowd: Array[Node3D] = []
var _cheer := 0.0
var _t := 0.0
var _player: Node3D
var _hud: CanvasLayer
var _hud_title: Label
var _hud_count: Label
var _gate_bar: StaticBody3D
var _gate_glow: MeshInstance3D
var _sun: DirectionalLight3D
var _env: Environment
var _beams: Array[Dictionary] = []            # {light: SpotLight3D, disc: MeshInstance3D, phase, speed, out}
var _flood: Array[OmniLight3D] = []
var _host_spot: Area3D
var _board_spot: Area3D
var _log_before := 0
var _menu := ""                                # which menu is open: "top", "challenge", "boss", "stop"
var _hatch_nodes: Array[Node3D] = []


func _enter_tree() -> void:
	# The way in (and the player) stand at the tunnel's outer end, facing in towards the floor (north, -Z)
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = Vector3(0, 1.0, TUNNEL_END - 4.0)
			(n as Node3D).rotation.y = 0.0


func _ready() -> void:
	_rng.seed = 2611
	_environment()
	_ground()
	_wall_and_stands()
	_tunnel()
	_hatches()
	_spotlights()
	_crowd_in()
	_host()
	_board()
	_hud_make()
	_way_out()
	_player = get_tree().get_first_node_in_group("player") as Node3D
	Dialogue.finished.connect(_on_talked)
	set_dark(false)
	if not Dialogue.flags.has("arena_met_blip"):
		Game.message("The Star Arena! Talk to Blip, the little announcer by the tunnel, to pick a round.")


func _exit_tree() -> void:
	if Dialogue.finished.is_connected(_on_talked):
		Dialogue.finished.disconnect(_on_talked)


# -----------------------------------------------------------------------------
# Little helpers
# -----------------------------------------------------------------------------
func _mat(name: String, c: Color, rough := 0.6, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[name] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _solid_box(parent: Node3D, name: String, size: Vector3, at: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = at
	body.rotation.y = yaw
	parent.add_child(body)
	return body


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, m: Material, solid := true, yaw := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(parent, bm, at, m)
	mi.name = name
	mi.rotation.y = yaw
	if solid:
		_solid_box(parent, name + " Body", size, at, yaw)
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = maxf(h, 0.04)
	cm.radial_segments = 32
	var mi := _mesh(parent, cm, at, m)
	mi.name = name
	if solid:
		var body := StaticBody3D.new()
		body.name = name + " Body"
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r_top, r_bottom)
		sh.height = maxf(h, 0.04)
		cs.shape = sh
		body.add_child(cs)
		body.position = at
		parent.add_child(body)
	return mi


func _label(parent: Node3D, text: String, at: Vector3, size := 48, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.modulate = Color(1.0, 0.88, 0.45)
	l.outline_size = 12
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.position = at
	l.rotation.y = yaw
	l.double_sided = false                                  # (seen from behind it would read backwards)
	parent.add_child(l)
	return l


func ground_y() -> float:
	return 0.0


# -----------------------------------------------------------------------------
# Building it
# -----------------------------------------------------------------------------
func _environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.16, 0.12, 0.38)                    # an evening sky: deep violet over a peachy teal glow
	sm.sky_horizon_color = Color(0.95, 0.6, 0.6)
	sm.ground_horizon_color = Color(0.5, 0.4, 0.55)
	sm.ground_bottom_color = Color(0.15, 0.12, 0.2)
	sky.sky_material = sm
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.5, 0.42, 0.6)
	_env.fog_density = 0.004
	_env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.name = "Arena Sky"
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1.0, 0.85, 0.7)
	_sun.light_energy = 1.0
	_sun.shadow_enabled = true
	_sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(25), 0)
	add_child(_sun)


func _ground() -> void:
	# One big flat floor under everything (its top at 0), the sandy round floor drawn on top, and a painted star in the
	# middle (the big middle hatch, where the bosses come up)
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	_box(g, "Concourse", Vector3(200, 1.0, 200), Vector3(0, -0.5, 0), _mat("Concourse", Color(0.42, 0.36, 0.5), 0.9))
	_cyl(g, "Arena Floor", FLOOR_R + 1.6, FLOOR_R + 1.6, 0.04, Vector3(0, 0.02, 0), _mat("Sand", Color(0.93, 0.8, 0.62), 1.0), false)
	_cyl(g, "Floor Ring", FLOOR_R * 0.62, FLOOR_R * 0.62, 0.04, Vector3(0, 0.035, 0), _mat("Ring Paint", Color(0.85, 0.65, 0.95), 0.9), false)
	_cyl(g, "Floor Ring Inner", FLOOR_R * 0.6, FLOOR_R * 0.6, 0.04, Vector3(0, 0.04, 0), _mat("Sand", Color(0.93, 0.8, 0.62), 1.0), false)
	var star := MeshInstance3D.new()
	star.name = "Middle Star"
	star.mesh = StarBubble.star_mesh()
	star.material_override = _mat("Star Paint", Color(1.0, 0.82, 0.35), 0.5, 0.3)
	star.scale = Vector3(3.0, 0.05, 3.0)
	star.rotation.x = -PI / 2.0
	star.position = Vector3(0, 0.05, 0)
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(star)


func _wall_and_stands() -> void:
	# The low wall round the floor (gap for the tunnel at the south), an invisible taller wall just behind it so
	# nobody climbs into the stands, and the stands themselves: four tiers stepping up and out, made into one mesh.
	var w := Node3D.new()
	w.name = "Wall"
	add_child(w)
	var stone := _mat("Arena Stone", Color(0.78, 0.66, 0.92), 0.7)
	var trim := _mat("Arena Trim", Color(1.0, 0.8, 0.3), 0.3, 0.1, 0.7)
	var n := 64
	var seg_len := TAU * WALL_R / n + 0.15
	for k in n:
		var a := TAU * k / n
		var at := Vector3(cos(a), 0, sin(a)) * WALL_R
		if at.z > 0.0 and absf(at.x) < GAP + 0.6:
			continue                                          # the tunnel's way in
		var yaw := -a + PI / 2.0
		_box(w, "Wall %d" % k, Vector3(seg_len, 1.3, 0.6), at + Vector3(0, 0.65, 0), stone, true, yaw)
		_box(w, "Trim %d" % k, Vector3(seg_len, 0.12, 0.7), at + Vector3(0, 1.34, 0), trim, false, yaw)
		_solid_box(w, "WorldBounds Ring %d" % k, Vector3(seg_len, 8.0, 0.4), at * ((WALL_R + 0.7) / WALL_R) + Vector3(0, 4.0, 0), yaw)
	# The stands (one mesh: tiers of boxes), behind the wall, all round but over the tunnel
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in 4:
		var r := WALL_R + 2.2 + tier * 2.0
		var h := 1.4 + tier * 1.3
		var tn := 72
		for k in tn:
			var a := TAU * (k + 0.5) / tn
			var at := Vector3(cos(a), 0, sin(a)) * r
			if at.z > 0.0 and absf(at.x) < GAP + 1.0 and tier < 3:
				continue                                      # over the tunnel only the top tier runs across
			var y0 := 0.0 if not (at.z > 0.0 and absf(at.x) < GAP + 1.0) else 4.0
			var box := BoxMesh.new()
			box.size = Vector3(TAU * r / tn + 0.1, h - y0, 2.05)
			var xf := Transform3D(Basis(Vector3.UP, -a + PI / 2.0), at + Vector3(0, (h + y0) * 0.5, 0))
			st.append_from(box, 0, xf)
	st.generate_normals()
	var stands := MeshInstance3D.new()
	stands.name = "Stands"
	stands.mesh = st.commit()
	stands.material_override = _mat("Stands", Color(0.55, 0.45, 0.72), 0.8)
	add_child(stands)
	# Bunting and banners round the top
	var colours := [Color(1.0, 0.55, 0.75), Color(0.45, 0.95, 1.0), Color(1.0, 0.85, 0.35), Color(0.6, 1.0, 0.5)]
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		var at := Vector3(cos(a), 0, sin(a)) * (WALL_R + 9.6)
		if at.z > 0.0 and absf(at.x) < GAP + 2.0:
			continue
		var pole := _cyl(w, "Banner Pole", 0.1, 0.1, 4.0, at + Vector3(0, 7.2, 0), trim, false)
		pole.name = "Banner Pole"
		var flag := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 2.4)
		flag.mesh = q
		var fm := _mat("Banner %d" % (k % 4), colours[k % 4], 0.8, 0.2)
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = fm
		flag.position = at + Vector3(0, 7.6, 0) + Vector3(-sin(a), 0, cos(a)) * 0.9
		flag.rotation.y = -a
		w.add_child(flag)
	# A big sign over the tunnel, inside
	_label(w, "★ THE STAR ARENA ★", Vector3(0, 8.6, WALL_R + 5.5), 96, PI)
	_label(w, "★ THE STAR ARENA ★", Vector3(0, 8.6, WALL_R + 6.5), 96, 0.0)


func _tunnel() -> void:
	# The way in from the south: two walls and a roof, and the bar of light that shuts it during a round
	var t := Node3D.new()
	t.name = "Tunnel"
	add_child(t)
	var stone := _mat("Arena Stone", Color(0.78, 0.66, 0.92), 0.7)
	var length := TUNNEL_END - WALL_R
	var mid_z := WALL_R + length * 0.5
	for side in [-1.0, 1.0]:
		_box(t, "Tunnel Wall", Vector3(0.8, 4.2, length + 1.0), Vector3(side * (GAP + 0.4), 2.1, mid_z), stone)
	_box(t, "Tunnel Roof", Vector3(GAP * 2.0 + 1.6, 0.5, length - 6.0), Vector3(0, 4.35, mid_z + 1.0), stone, false)
	# Outer bounds: you can't wander off round the outside of the stadium
	for side in [-1.0, 1.0]:
		_solid_box(t, "WorldBounds Side", Vector3(1, 10, 200), Vector3(side * 60.0, 5, 0))
		_solid_box(t, "WorldBounds End", Vector3(200, 10, 1), Vector3(0, 5, side * 60.0))
	_solid_box(t, "WorldBounds Back", Vector3(GAP * 2.0, 10, 1), Vector3(0, 5, TUNNEL_END + 0.6))
	# The bar of light (only there during a round)
	_gate_bar = _solid_box(t, "Gate Bar", Vector3(GAP * 2.0, 6.0, 0.6), Vector3(0, 3.0, WALL_R + 0.3))
	_gate_glow = _box(t, "Gate Glow", Vector3(GAP * 2.0, 3.0, 0.15), Vector3(0, 1.5, WALL_R + 0.3),
		_mat("Gate Light", Color(0.45, 0.95, 1.0, 0.45), 0.2, 1.5), false)
	_gate_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_gate(false)


func _set_gate(shut: bool) -> void:
	_gate_glow.visible = shut
	(_gate_bar.get_child(0) as CollisionShape3D).set_deferred("disabled", not shut)


func _hatches() -> void:
	# Six glowing round hatches round the floor where the enemies pop up, and the big star in the middle for bosses
	var h := Node3D.new()
	h.name = "Hatches"
	add_child(h)
	for k in HATCHES:
		var a := TAU * (k + 0.5) / HATCHES - PI / 2.0
		var at := Vector3(cos(a), 0, sin(a)) * HATCH_R
		var hatch := Node3D.new()
		hatch.name = "Hatch %d" % (k + 1)
		hatch.position = at
		h.add_child(hatch)
		_cyl(hatch, "Hatch Rim", 1.3, 1.3, 0.04, Vector3(0, 0.05, 0), _mat("Hatch Rim", Color(1.0, 0.8, 0.3), 0.3, 0.4, 0.7), false)
		_cyl(hatch, "Hatch Glow", 1.05, 1.05, 0.04, Vector3(0, 0.06, 0), _mat("Hatch Glow", Color(0.5, 0.95, 1.0), 0.3, 1.2), false)
		_hatch_nodes.append(hatch)


func hatch_spot(k: int) -> Vector3:
	return _hatch_nodes[k % _hatch_nodes.size()].global_position


func _spotlights() -> void:
	# Four tall towers at the corners, each with a big lamp whose beam sweeps round the floor. By day they're just
	# floodlights; in a dark round their beams light circles that move round the floor (lit_at()).
	var s := Node3D.new()
	s.name = "Spotlights"
	add_child(s)
	var metal := _mat("Tower Metal", Color(0.35, 0.3, 0.45), 0.4, 0.0, 0.6)
	var lamp_m := _mat("Lamp Glass", Color(1.0, 0.95, 0.75), 0.2, 2.0)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var base := Vector3(cos(a), 0, sin(a)) * (WALL_R + 12.0)
		var tower := Node3D.new()
		tower.name = "Spotlight Tower %d" % (k + 1)
		tower.position = base
		s.add_child(tower)
		_cyl(tower, "Tower", 0.45, 0.7, 16.0, Vector3(0, 8.0, 0), metal, true)
		_cyl(tower, "Lamp", 1.2, 0.9, 1.0, Vector3(0, 16.4, 0), lamp_m, false)
		var light := SpotLight3D.new()
		light.name = "Beam"
		light.light_color = Color(1.0, 0.95, 0.8)
		light.light_energy = 6.0
		light.spot_range = 60.0
		light.spot_angle = 9.0
		light.shadow_enabled = false
		light.position = Vector3(0, 16.4, 0)
		tower.add_child(light)
		var disc := MeshInstance3D.new()
		disc.name = "Beam Circle %d" % (k + 1)
		var cm := CylinderMesh.new()
		cm.top_radius = BEAM_R
		cm.bottom_radius = BEAM_R
		cm.height = 0.04
		cm.radial_segments = 32
		disc.mesh = cm
		disc.material_override = _mat("Beam Circle", Color(1.0, 0.95, 0.75, 0.35), 0.3, 1.2)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)
		var flood := OmniLight3D.new()
		flood.name = "Floodlight"
		flood.light_color = Color(1.0, 0.92, 0.8)
		flood.light_energy = 2.0
		flood.omni_range = 30.0
		flood.position = Vector3(0, 15.0, 0)
		tower.add_child(flood)
		_flood.append(flood)
		_beams.append({"light": light, "disc": disc, "phase": a, "speed": [0.28, -0.22, 0.34, -0.3][k],
			"out": BEAM_PATH * [1.0, 0.55, 0.8, 0.35][k]})


func beam_at(i: int) -> Vector3:
	var b: Dictionary = _beams[i]
	var a: float = float(b.phase) + _t * float(b.speed)
	var o: float = float(b.out)
	return Vector3(cos(a) * o + sin(a * 1.7) * 2.0, 0.0, sin(a) * o)


func lit_at(at: Vector3) -> bool:
	# Is this spot in a spotlight's circle (only in a dark round), or in Pip's glow?
	if dark:
		for i in _beams.size():
			if Vector2(at.x - beam_at(i).x, at.z - beam_at(i).z).length() < BEAM_R:
				return true
	var glow = _player.get_node_or_null("PipGlow") if _player else null
	return glow != null and glow.has_method("lights") and glow.lights(at)


func beam_push(at: Vector3) -> Vector3:
	# Which way to steer to keep out of the nearest beam (the Gloam doesn't like the light)
	if not dark:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for i in _beams.size():
		var d := at - beam_at(i)
		d.y = 0
		var l := d.length()
		if l < BEAM_R + 2.5 and l > 0.01:
			push += d / l * (1.0 - l / (BEAM_R + 2.5))
	return push


func set_dark(on: bool) -> void:
	dark = on
	_sun.light_energy = 0.12 if on else 1.0
	_env.ambient_light_energy = 0.12 if on else 0.6
	_env.background_energy_multiplier = 0.25 if on else 1.0
	for f in _flood:
		f.visible = not on
	for b in _beams:
		(b.light as SpotLight3D).visible = on
		(b.disc as MeshInstance3D).visible = on


func _crowd_in() -> void:
	# Little aliens all round the stands (a Void resident crowd), bobbing and waving; they cheer every pop
	var c := Node3D.new()
	c.name = "Crowd"
	add_child(c)
	var colours := ["blue", "green", "orange", "pink", "purple", "red", "yellow"]
	var n := 36
	for k in n:
		var tier := k % 4
		var a := TAU * (k + 0.5) / n + tier * 0.05
		var r := WALL_R + 2.2 + tier * 2.0
		var at := Vector3(cos(a), 0, sin(a)) * r
		if at.z > 0.0 and absf(at.x) < GAP + 1.5:
			continue
		var path := "res://models/characters/little_alien_%s.glb" % colours[k % colours.size()]
		if not ResourceLoader.exists(path):
			continue
		var alien := (load(path) as PackedScene).instantiate() as Node3D
		alien.name = "Fan %d" % (k + 1)
		alien.scale = Vector3.ONE * 1.2
		alien.position = at + Vector3(0, 1.4 + tier * 1.3, 0)
		alien.rotation.y = atan2(-at.x, -at.z)                # facing the floor
		c.add_child(alien)
		_crowd.append(alien)
		var anim := alien.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			for nm in ["idle", "wave"]:
				if anim.has_animation(nm):
					anim.get_animation(nm).loop_mode = Animation.LOOP_LINEAR
			if anim.has_animation("idle"):
				anim.play("idle")
				anim.seek(_rng.randf() * 2.0)
			alien.set_meta("anim", anim)
		alien.set_meta("y", alien.position.y)


func cheer(big := false) -> void:
	_cheer = maxf(_cheer, 2.5 if big else 1.0)
	for a in _crowd:
		var anim = a.get_meta("anim", null)
		if anim and (anim as AnimationPlayer).has_animation("wave"):
			(anim as AnimationPlayer).play("wave", 0.2)


func _host() -> void:
	# Blip, the arena's little announcer: a yellow little alien on a gold podium, with a megaphone
	var h := Node3D.new()
	h.name = "Blip"
	h.position = HOST_AT
	h.rotation.y = 0.0
	add_child(h)
	_cyl(h, "Podium", 0.8, 0.9, 0.6, Vector3(0, 0.3, 0), _mat("Arena Trim", Color(1.0, 0.8, 0.3), 0.3, 0.1, 0.7))
	var path := "res://models/characters/little_alien_yellow.glb"
	if ResourceLoader.exists(path):
		var alien := (load(path) as PackedScene).instantiate() as Node3D
		alien.name = "Model"
		alien.scale = Vector3.ONE * 1.8
		alien.position = Vector3(0, 0.6, 0)
		alien.rotation.y = 0.0                                # facing the tunnel (+Z), where you come in
		h.add_child(alien)
		var anim := alien.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation("wave"):
			anim.get_animation("wave").loop_mode = Animation.LOOP_LINEAR
			anim.play("wave")
	var horn := _cyl(h, "Megaphone", 0.22, 0.08, 0.5, Vector3(0.45, 1.6, 0.25), _mat("Megaphone", Color(1.0, 0.45, 0.6), 0.4), false)
	horn.rotation.x = PI / 2.0
	_label(h, "BLIP\n(announcer)", Vector3(0, 2.9, 0), 36, 0.0).billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_host_spot = USE_SPOT.make(Vector3(0, 0, 0.6), func() -> String: return "talk to Blip", talk, 2.6, 2.4)
	_host_spot.name = "Blip Spot"
	h.add_child(_host_spot)


func _board() -> void:
	# The Round Board: every round, with a star for each one won, and best times
	var b := Node3D.new()
	b.name = "Round Board"
	b.position = BOARD_AT
	add_child(b)
	for side in [-1.0, 1.0]:
		_box(b, "Board Leg", Vector3(0.2, 3.0, 0.2), Vector3(side * 1.6, 1.5, 0), _mat("Tower Metal", Color(0.35, 0.3, 0.45), 0.4, 0.0, 0.6), false)
	_box(b, "Board", Vector3(3.6, 2.6, 0.2), Vector3(0, 2.4, 0), _mat("Board Face", Color(0.16, 0.1, 0.28), 0.6), true)
	var l := _label(b, "", Vector3(0, 2.4, 0.12), 16, 0.0)
	l.name = "Board Text"
	l.modulate = Color(1, 1, 1)
	l.width = 340
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The same on the back, for reading it from the floor
	var back := l.duplicate() as Label3D
	back.name = "Board Text Back"
	back.position = Vector3(0, 2.4, -0.12)
	back.rotation.y = PI
	b.add_child(back)
	_board_spot = USE_SPOT.make(Vector3(0, 0, 0.8), func() -> String: return "read the Round Board", talk, 2.4, 2.4)
	_board_spot.name = "Board Spot"
	b.add_child(_board_spot)
	_refresh_board()


func board_text() -> String:
	var lines: Array[String] = ["ROUNDS    (★ won)"]
	for c in Arena.CHALLENGES:
		var id := str(c.id)
		var mark := "★" if Arena.wins(id) > 0 else ("·" if Arena.is_open(id) else "🔒")
		var best := Arena.best(id)
		lines.append("%s %s%s" % [mark, str(c.name) if Arena.is_open(id) else "???",
			("   best %s" % Arena.clock_text(best)) if best > 0.0 else ""])
	return "\n".join(lines)


func _refresh_board() -> void:
	for n in ["Board Text", "Board Text Back"]:
		var l := find_child(n, true, false) as Label3D
		if l:
			l.text = board_text()


func _way_out() -> void:
	var spot := USE_SPOT.make(Vector3(0, 0, TUNNEL_END - 1.2), func() -> String: return "go back out to the Void", go_home, 2.6, 3.0)
	spot.name = "Way Out"
	add_child(spot)
	_label(self, "WAY OUT", Vector3(0, 3.6, TUNNEL_END - 0.2), 40, PI)


func go_home() -> void:
	if round_id != "":
		stop_round(true)
	var out: Dictionary = Arena.gate_out()
	Game.pending_message = "Back out by the Star Arena's gate."
	Arena.coming_out = true
	Game.go_to_point(TOWN, out.position, float(out.yaw), "the Void")


func _hud_make() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "ArenaHud"
	_hud.layer = 5
	add_child(_hud)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -280
	box.offset_right = 280
	box.offset_top = 70
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_hud_title = Label.new()
	_hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_title.add_theme_font_size_override("font_size", 26)
	_hud_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_hud_title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.2))
	_hud_title.add_theme_constant_override("outline_size", 10)
	box.add_child(_hud_title)
	_hud_count = Label.new()
	_hud_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_count.add_theme_font_size_override("font_size", 34)
	_hud_count.add_theme_color_override("font_color", Color(1, 1, 1))
	_hud_count.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.2))
	_hud_count.add_theme_constant_override("outline_size", 12)
	box.add_child(_hud_count)
	_hud.visible = false


# -----------------------------------------------------------------------------
# Talking to Blip: the menus
# -----------------------------------------------------------------------------
func talk() -> void:
	if Dialogue.is_active():
		return
	_log_before = Dialogue.choice_log.size()
	if round_id != "":
		_menu = "stop"
		Dialogue.say(_host_spot, HOST, ["(Blip covers the megaphone.) Psst! The round's still on! Want to stop it?",
			{"choice": [
				{"text": "Stop the round.", "answer": "stop", "record": RECORD, "lines": ["Okay! Round's off. No harm done: try again any time!"]},
				{"text": "No, I'll keep going!", "answer": "go", "record": RECORD, "lines": ["That's the spirit! GO GO GO!"]}]}], "arena")
		return
	_menu = "top"
	var lines: Array = []
	if not Dialogue.flags.has("arena_met_blip"):
		Dialogue.set_flag("arena_met_blip")
		lines.append_array(["(A little yellow alien on a podium swings a megaphone round at you.) WELCOME, WELCOME, WELCOME to the STAR ARENA!",
			"I'm Blip! I call the rounds. You pick one, the hatches open, and you pop everything that comes out. The crowd LOVES a pop.",
			"Win a round and there's a prize. Win the round with the little ones, and their great big boss comes out to play. Bosses you won't meet anywhere else!",
			"If you get bumped too much and faint, it's no bother: the round just starts over."])
	else:
		lines.append(["{player}! The crowd's been chanting your name! Well... beeping it. What'll it be?",
			"Back for more? The hatches are ready!", "The Star Arena's champion-in-training! What's it to be?"][_rng.randi() % 3])
	lines.append({"choice": [
		{"text": "A challenge round!", "answer": "challenge", "record": RECORD, "say": true},
		{"text": "A boss round!", "answer": "boss", "record": RECORD},
		{"text": "How am I doing?", "answer": "medals", "record": RECORD},
		{"text": "Not right now.", "answer": "no", "record": RECORD, "lines": ["Come back soon! The crowd'll wait. They've got snacks."]}]})
	Dialogue.say(_host_spot, HOST, lines, "arena")


func challenge_lines() -> Array:
	var options: Array = []
	for c in Arena.CHALLENGES:
		if str(c.kind) in ["boss", "rush"]:
			continue
		options.append({"text": "%s%s" % [c.name, "  ★" if Arena.wins(str(c.id)) > 0 else ""], "answer": str(c.id), "record": RECORD,
			"lines": [str(c.about)]})
	options.append({"text": "Never mind.", "answer": "no", "record": RECORD})
	return ["Challenge rounds! Pick one:", {"choice": options}]


func boss_lines() -> Array:
	var options: Array = []
	for c in Arena.CHALLENGES:
		if not str(c.kind) in ["boss", "rush"]:
			continue
		var id := str(c.id)
		if Arena.is_open(id):
			options.append({"text": "%s%s" % [c.name, "  ★" if Arena.wins(id) > 0 else ""], "answer": id, "record": RECORD,
				"lines": [str(c.about)]})
		else:
			options.append({"text": "??? (locked)", "answer": "locked_" + id, "record": RECORD,
				"lines": ["Ooh, that one's not ready for you yet. %s" % Arena.needs_text(id)]})
	options.append({"text": "Never mind.", "answer": "no", "record": RECORD})
	return ["Boss rounds! These ones only live here:", {"choice": options}]


func medal_lines() -> Array:
	var won := Arena.medals()
	var out: Array = ["You've won %d of the %d rounds! (The Round Board has the lot, with your best times.)" % [won, Arena.CHALLENGES.size()]]
	if won == 0:
		out.append("Start with Pop 100 Gloops. Everyone starts with Pop 100 Gloops!")
	elif won == Arena.CHALLENGES.size():
		out.append("Every single one! You're the Star Arena's CHAMPION! (The crowd goes wild. Beep beep beep!)")
	return out


func _on_talked(id: String) -> void:
	if id != "arena":
		return
	var answer := ""
	var k := Dialogue.choice_log.size() - 1
	while k >= _log_before:
		var e: Dictionary = Dialogue.choice_log[k]
		if str(e.get("what", "")) == RECORD:
			if answer == "":
				answer = str(e.get("answer", ""))
			Dialogue.choice_log.remove_at(k)                 # (menu picks aren't worth remembering for good)
		k -= 1
	_after_pick.call_deferred(_menu, answer)


func _after_pick(menu: String, answer: String) -> void:
	match [menu, answer]:
		["stop", "stop"]:
			stop_round(true)
			return
		["top", "challenge"]:
			_open_menu("challenge", challenge_lines())
			return
		["top", "boss"]:
			_open_menu("boss", boss_lines())
			return
		["top", "medals"]:
			_open_menu("medals", medal_lines())
			return
	if menu in ["challenge", "boss"] and not Arena.round_of(answer).is_empty() and Arena.is_open(answer):
		start_round(answer)


func _open_menu(menu: String, lines: Array) -> void:
	_menu = menu
	_log_before = Dialogue.choice_log.size()
	Dialogue.say(_host_spot, HOST, lines, "arena")


# -----------------------------------------------------------------------------
# A round
# -----------------------------------------------------------------------------
func start_round(id: String) -> void:
	var c := Arena.round_of(id)
	if c.is_empty() or round_id != "":
		return
	_clear()
	round_id = id
	count = 0
	elapsed = 0.0
	wave = 0
	_spawned = 0
	_next_wave = 0.0
	_boss_queue = (c.get("bosses", []) as Array).duplicate() if str(c.kind) == "rush" else ([c.boss] if c.has("boss") else [])
	time_left = float(c.get("time", 0))
	_starting = 3.0
	_won_banner = 0.0
	_set_gate(true)
	set_dark(bool(c.get("dark", false)))
	_hud.visible = true
	Game.message("%s! Get ready..." % c.name)
	Juice.blip("whoosh", 1.0, -6.0)
	cheer(true)
	# Into the middle of the floor, so nothing pops up right on top of you
	if _player and _player.global_position.distance_to(Vector3(0, 0, 14)) > 10.0 and _player.global_position.z > 14.0:
		_player.global_position = Vector3(0, 1.0, 14.0)


func stop_round(quiet := false) -> void:
	if round_id == "":
		return
	if not quiet:
		Game.message("Round over.")
	round_id = ""
	_clear()
	_set_gate(false)
	set_dark(false)
	_hud.visible = false


func _clear() -> void:
	# Everything the round sent out goes (with a puff), and nothing's counted for it
	var gone := _live.duplicate()
	_live.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(e):
			gone.append(e)
	for e in gone:
		if is_instance_valid(e) and not (e as Node).is_queued_for_deletion():
			if e is Node3D:
				Fx.burst(self, (e as Node3D).global_position + Vector3(0, 0.8, 0), Color(0.9, 0.85, 1.0), 6, 0.06, 1.5, 0.0, 0.4)
			(e as Node).queue_free()
	_seen.clear()
	boss = null


func _won() -> void:
	var c := Arena.round_of(round_id)
	var prize := Arena.won(round_id, elapsed)
	var line := "ROUND WON! %s in %s." % [c.name, Arena.clock_text(elapsed)]
	if not prize.is_empty() and Arena.prize_text(prize) != "":
		line += " Prize: %s%s" % [Arena.prize_text(prize), " (first win!)" if prize.get("first", false) else ""]
	Game.message(line)
	if prize.has("item") and prize.get("first", false):
		Game.message("The Champion's Cup is yours! Wear it from the wardrobe. CHAMPION!")
	Juice.blip("sparkle", 1.0, -2.0)
	cheer(true)
	for i in 5:
		Fx.burst(self, Vector3(_rng.randf_range(-12, 12), 6.0 + _rng.randf() * 4.0, _rng.randf_range(-12, 12)),
			[Color(1.0, 0.85, 0.35), Color(0.45, 0.95, 1.0), Color(1.0, 0.5, 0.8)][i % 3], 20, 0.1, 5.0, -2.0, 1.2)
	var was := round_id
	round_id = ""
	_clear()
	_set_gate(false)
	set_dark(false)
	_won_banner = 4.0
	_hud_title.text = "ROUND WON!"
	_hud_count.text = "%s  ·  %s" % [Arena.round_of(was).name, Arena.clock_text(elapsed)]
	_refresh_board()


func _lost(why: String) -> void:
	Game.message(why)
	stop_round(true)


func boss_popped(_who: Node) -> void:
	# A boss popped (told by the boss itself). In the Champion's Cup the next one comes out after a breather.
	if round_id == "":
		return
	count += 1
	cheer(true)
	if _boss_queue.is_empty():
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if round_id != "":
				_won())
	else:
		_next_wave = 2.0
		Game.message("Next up... get ready!")


func _spawn_boss(kind: String) -> void:
	var b: Node3D
	match kind:
		"mama_glorp":
			b = MOTHER.make()
		"big_buzz":
			b = BIG_BUZZ.new() as Node3D
			b.name = "Big Buzz"
			b.set("centre", Vector3.ZERO)
			b.set("reach", FLOOR_R - 4.0)
		"gloam":
			b = GLOAM.new() as Node3D
			b.name = "The Gloam"
			b.set("centre", Vector3.ZERO)
			b.set("reach", FLOOR_R - 4.0)
	if b == null:
		return
	if str(Arena.round_of(round_id).get("kind", "")) == "rush":
		set_dark(kind == "gloam")                             # (the Gloam needs the lights down)
	b.set("world", self)
	b.position = BOSS_AT + Vector3(0, 0.4 if kind == "mama_glorp" else 0.0, 0)
	add_child(b)
	boss = b
	_seen[b.get_instance_id()] = true
	Fx.burst(self, BOSS_AT + Vector3(0, 1.5, 0), Color(1.0, 0.85, 0.35), 24, 0.12, 4.0, 0.0, 0.9)
	Juice.shake(0.4)
	Game.message("Here comes %s!" % str(b.name))
	cheer(true)


func spawn(kind: String) -> Node3D:
	# One of the little ones, out of a hatch (the one furthest from you, so it doesn't land on your head)
	var best_k := 0
	var best_d := -1.0
	for k in HATCHES:
		var d := hatch_spot(k).distance_to(_player.global_position) if _player else _rng.randf() * 10.0
		d += _rng.randf() * 6.0
		if d > best_d:
			best_d = d
			best_k = k
	var at := hatch_spot(best_k) + Vector3(_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))
	var e: Node3D
	match kind:
		"gloop":
			e = (load(GLOOP_SCENE) as PackedScene).instantiate() as Node3D
			e.position = at + Vector3(0, 0.3, 0)
		"glorp":
			e = GLORP.make(1.5)
			e.position = at + Vector3(0, 0.3, 0)
		"goblin":
			e = (load(GOBLIN_SCENE) as PackedScene).instantiate() as Node3D
			e.position = at + Vector3(0, 0.3, 0)
		"fizzler":
			e = FIZZLER.new() as Node3D
			e.position = at
		"ghost":
			e = SHADOW_GHOST.new() as Node3D
			e.position = at
	if e == null:
		return null
	e.name = "%s %d" % [kind.capitalize(), _spawned + 1]
	e.set("respawns", false)
	e.set("sight_range", 60.0)
	e.set("leash_range", 90.0)
	e.set("wander_radius", 3.0)
	add_child(e)
	_spawned += 1
	_seen[e.get_instance_id()] = true
	_live.append(e)
	Fx.burst(self, at + Vector3(0, 0.6, 0), Color(0.5, 0.95, 1.0), 8, 0.06, 2.0, 0.0, 0.4)
	return e


func _track() -> void:
	# New enemies (Glorp bits, a boss's helpers) join the list; popped ones count
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_ancestor_of(e) or e.is_in_group("bosses"):
			continue
		var id := e.get_instance_id()
		if not _seen.has(id):
			_seen[id] = true
			_live.append(e)
	var still: Array[Node] = []
	for e in _live:
		if not is_instance_valid(e) or bool(e.get("defeated")) or e.is_queued_for_deletion():
			count += 1
			if _rng.randf() < 0.5:
				cheer()
		else:
			still.append(e)
	_live = still


func alive() -> int:
	return _live.size()


func _physics_process(delta: float) -> void:
	_t += delta
	_move_beams()
	_animate_crowd(delta)
	if _won_banner > 0.0:
		_won_banner -= delta
		if _won_banner <= 0.0 and round_id == "":
			_hud.visible = false
	if round_id == "":
		return
	var c := Arena.round_of(round_id)
	if _starting > 0.0:
		var before := ceili(_starting)
		_starting -= delta
		_hud_title.text = str(c.name)
		_hud_count.text = str(ceili(_starting)) if _starting > 0.0 else "GO!"
		if ceili(_starting) != before:
			Juice.blip("tick", 1.0 if _starting > 0.0 else 1.6, -6.0)
		return
	elapsed += delta
	var counted_before := count
	_track()
	var kind := str(c.kind)
	match kind:
		"count", "timed":
			var goal := int(c.goal)
			if count >= goal:
				_won()
				return
			if kind == "timed":
				time_left -= delta
				if time_left <= 0.0:
					_lost("Time's up! %d of %d popped. So close! Talk to Blip to try again." % [count, goal])
					return
			while alive() < int(c.get("at_once", 6)) and count + alive() < goal:
				if spawn(str(c.enemy)) == null:
					break
			_hud_title.text = str(c.name)
			_hud_count.text = "%d / %d popped%s" % [mini(count, goal), goal,
				("   ⏱ %s" % Arena.clock_text(maxf(time_left, 0.0))) if kind == "timed" else ""]
		"waves":
			var waves: Array = c.goal
			if alive() == 0:
				if wave >= waves.size():
					_won()
					return
				_next_wave -= delta
				if _next_wave <= 0.0:
					if wave > 0:
						Game.message("Wave %d!" % (wave + 1))
					for i in int(waves[wave]):
						spawn(str(c.enemy))
					wave += 1
					_next_wave = 2.0                              # (a breather after each wave)
			_hud_title.text = "%s: wave %d of %d" % [c.name, maxi(wave, 1), waves.size()]
			_hud_count.text = "%d left in this wave" % alive()
		"boss", "rush":
			if (boss == null or not is_instance_valid(boss)) and not _boss_queue.is_empty():
				_next_wave -= delta
				if _next_wave <= 0.0:
					_spawn_boss(str(_boss_queue.pop_front()))
			var total: int = (c.get("bosses", []) as Array).size() if kind == "rush" else 1
			_hud_title.text = str(c.name) if kind == "boss" else "%s: boss %d of %d" % [c.name, mini(count + 1, total), total]
			_hud_count.text = "⏱ %s" % Arena.clock_text(elapsed)
	if count > counted_before:
		Juice.blip("pop", 1.1 + 0.05 * (count % 5), -14.0)


func _move_beams() -> void:
	for i in _beams.size():
		var b: Dictionary = _beams[i]
		var at := beam_at(i)
		(b.disc as MeshInstance3D).position = at + Vector3(0, 0.07, 0)
		var light := b.light as SpotLight3D
		if light.is_inside_tree():
			var from := light.global_position
			if from.distance_to(at) > 0.1:
				light.look_at(at, Vector3.UP)


func _animate_crowd(delta: float) -> void:
	_cheer = maxf(_cheer - delta, 0.0)
	var i := 0
	for a in _crowd:
		i += 1
		var y: float = a.get_meta("y")
		var hop := (absf(sin(_t * 9.0 + i)) * 0.35 * minf(_cheer, 1.0)) if _cheer > 0.0 else absf(sin(_t * 1.5 + i)) * 0.04
		a.position.y = y + hop * (0.3 if Settings.reduce_motion else 1.0)
		if _cheer <= 0.0:
			var anim = a.get_meta("anim", null)
			if anim and (anim as AnimationPlayer).current_animation == "wave" and (anim as AnimationPlayer).has_animation("idle"):
				(anim as AnimationPlayer).play("idle", 0.3)
