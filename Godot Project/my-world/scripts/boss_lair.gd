extends Node3D

# What every boss's lair shares (Hayden, 15 Nov 2026: "I want the time goblins, and the crocodillo boss to get their
# own arenas as well", like the Gloop King's kingdom, scripts/gloop_kingdom.gd). Each lair is a level of its own made
# by tools/build_boss_lairs.gd: only its script, an Entrance and the player. Everything else is built by the lair's
# own script (it extends this one) when it loads, so it can be changed without rebuilding anything:
#   - scripts/clock_tower.gd: the Clockwork Tower, Grandfather Tock's (its Tower Door is in the Goblin Clockyard)
#   - scripts/boulder_canyon.gd: Boulder Canyon, the Boulderdillo's (its Canyon Mouth is in Boulder Hollow)
#
# Here: the way in (the player starts just inside, facing up the level along +Z), the boss asleep in its arena until
# you come close, the treasure that opens once it's popped (sparkles the first time each Void visit), and the ways
# home (one just inside, one by the treasure after the win), which land you back in front of the lair's gate in town
# (Bosses.lair_out()). The boss is back on your next visit. A lair overrides the "To fill in" functions below.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const TOWN := "res://scenes/town/town.tscn"

var boss: CharacterBody3D
var awake := false
var popped := false                            # the boss has been popped this visit
var treasure_open := false
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _t := 0.0
var _chest: Node3D
var _home_way: Node3D


# -----------------------------------------------------------------------------
# To fill in
# -----------------------------------------------------------------------------
func lair_id() -> String:                      # its key in Bosses.LAIRS
	return ""


func arena() -> Vector3:                       # the middle of the boss's arena
	return Vector3(0, 0, 60)


func wake_range() -> float:                    # come this close to the arena's middle and the boss wakes
	return 16.0


func treasure() -> int:                        # sparkles in the treasure
	return 12


func _build() -> void:                         # the whole level
	pass


func _make_boss() -> CharacterBody3D:          # the boss, set up and placed (not yet added)
	return null


func _on_wake() -> void:
	pass


func _on_popped() -> void:
	pass


func _lair_step(_delta: float) -> void:        # every physics frame
	pass


func _open_look() -> void:                     # the treasure opening (its "Lid" swings by default)
	var lid := _chest.get_node_or_null("Lid") as Node3D
	if lid:
		lid.create_tween().tween_property(lid, "rotation:x", -1.1, 0.5).set_trans(Tween.TRANS_BACK)


func _way_look(b: Node3D) -> void:             # what a way home looks like
	var ball := SphereMesh.new()
	ball.radius = 1.3
	ball.height = 2.6
	_mesh(b, ball, Vector3(0, 1.4, 0), _mat("Home Bubble", Color(0.7, 0.95, 1.0, 0.5), 0.05, 0.8), false).name = "Bubble"


# -----------------------------------------------------------------------------
# Setting up
# -----------------------------------------------------------------------------
func _enter_tree() -> void:
	# The way in (and the player) stand just inside, facing up the level (a marker looks along its -Z, so the Entrance
	# turns round to face +Z)
	for n in [get_node_or_null("Entrance"), get_node_or_null("Player")]:
		if n is Node3D:
			(n as Node3D).position = Vector3(0, 1.0, 3.0)
			(n as Node3D).rotation.y = PI if n.name == "Entrance" else 0.0


func _ready() -> void:
	_rng.seed = hash(lair_id())
	_build()
	boss = _make_boss()
	if boss:
		boss.set("respawns", false)                          # (popped for this visit; back on the next one)
		boss.process_mode = Node.PROCESS_MODE_DISABLED       # asleep until you come into its arena
		add_child(boss)
	_way_home(Vector3(0, 0, -1.5), "Way Out")
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if is_instance_valid(boss):
		var to := _player.global_position - (global_position + arena())
		if not awake and Vector2(to.x, to.z).length() < wake_range():
			wake()
		if awake and bool(boss.get("defeated")) and not popped:
			_popped()
	_lair_step(delta)


func wake() -> void:
	if awake or not is_instance_valid(boss):
		return
	awake = true
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.set("player", _player)
	Juice.shake(0.3)
	_on_wake()


func _popped() -> void:
	popped = true
	_open_look()
	Fx.burst(self, _chest.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.85, 0.3), 24, 0.12, 4.0, 3.0)
	if _home_way == null:
		_home_way = _way_home(_chest.position + Vector3(-3.5, 0, 0), "Treasure Way Out")
	_on_popped()


func _treasure(at: Vector3) -> void:
	# A spot by the treasure: it only offers anything once the boss is popped
	var spot := USE_SPOT.make(at + Vector3(0, 0, -1.6), _treasure_offer, _open_treasure, 2.2, 2.6)
	spot.name = "Treasure Spot"
	add_child(spot)


func _treasure_offer() -> String:
	return "open the treasure" if popped and not treasure_open else ""


func _open_treasure() -> void:
	if treasure_open:
		return
	treasure_open = true
	var flag := "%s_treasure_%d" % [lair_id(), Requests.visit_day()]
	if Dialogue.flags.has(flag):
		Game.message("Empty today. Come back next time!")
		return
	Dialogue.set_flag(flag)
	Game.add_sparkles(treasure())
	Game.message("Treasure! ✦ %d sparkles." % treasure())
	Juice.blip("chime", 1.0, -4.0)


func _way_home(at: Vector3, name: String) -> Node3D:
	var b := Node3D.new()
	b.name = name
	b.position = at
	add_child(b)
	_way_look(b)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "go home to the Void", go_home, 2.4, 3.2)
	spot.name = "Home Spot"
	b.add_child(spot)
	return b


func go_home() -> void:
	var out: Dictionary = Bosses.lair_out(lair_id())
	Game.pending_message = ""
	Bosses.coming_out_of = lair_id()
	Game.go_to_point(TOWN, out.position, float(out.yaw), "the Void")


func bump(from: Vector3, amount := 1) -> void:
	# Kid-safe hazards: a knock and a blink, like touching a Gloop (never while she's already blinking)
	if _player and _player.has_method("hurt"):
		_player.call("hurt", amount, from)


func player_low() -> bool:
	# On (or just over) the floor: high in a jump, ground hazards miss her
	return _player != null and _player.global_position.y < 1.9


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
		m.emission = Color(c.r, c.g, c.b)
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


func _solid(parent: Node3D, name: String, shape: Shape3D, at: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = at
	body.rotation = rot
	parent.add_child(body)
	return body


func _box(parent: Node3D, name: String, size: Vector3, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := _mesh(parent, bm, at, m)
	mi.name = name
	if solid:
		var bs := BoxShape3D.new()
		bs.size = size
		_solid(parent, name + " Body", bs, at)
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bottom: float, h: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = 24
	var mi := _mesh(parent, cm, at, m)
	mi.name = name
	if solid:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(r_top, r_bottom)
		cs.height = h
		_solid(parent, name + " Body", cs, at)
	return mi


func _ball(parent: Node3D, name: String, r: float, at: Vector3, m: Material, solid := true) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	var mi := _mesh(parent, sm, at, m)
	mi.name = name
	if solid:
		var ss := SphereShape3D.new()
		ss.radius = r
		_solid(parent, name + " Body", ss, at)
	return mi


func _sign(parent: Node3D, text: String, at: Vector3, yaw := PI, board_col := Color(0.3, 0.22, 0.35)) -> void:
	_box(parent, "Sign Post", Vector3(0.2, 2.2, 0.2), at + Vector3(0, 1.1, 0), _mat("Sign Wood", Color(0.45, 0.3, 0.2)), false)
	var board := Node3D.new()
	board.name = "Sign"
	board.position = at + Vector3(0, 2.1, 0)
	board.rotation.y = yaw
	parent.add_child(board)
	var back := BoxMesh.new()
	back.size = Vector3(3.4, 1.0, 0.12)
	_mesh(board, back, Vector3.ZERO, _mat("Sign Board %s" % board_col.to_html(), board_col))
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.88, 0.45)
	label.outline_size = 8
	label.outline_modulate = Color(0.12, 0.08, 0.15)
	label.position = Vector3(0, 0, 0.08)                     # (the writing's on the board's +Z face: tools/audit_signs.gd)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = 520
	board.add_child(label)


func _environment(top: Color, horizon: Color, ground: Color, fog: Color, fog_density := 0.004, sun_col := Color(1, 0.92, 0.75)) -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = top
	sm.sky_horizon_color = horizon
	sm.ground_horizon_color = horizon.darkened(0.3)
	sm.ground_bottom_color = ground
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.fog_sky_affect = 0.2
	var we := WorldEnvironment.new()
	we.name = "Lair Sky"
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_col
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(-25), 0)
	add_child(sun)


func _floor(size: Vector2, centre: Vector3, a: Color, b: Color, name := "Floor") -> void:
	# One flat floor for the whole lair (the player can't step up a ledge on foot, so everything walkable is flush)
	var g := Node3D.new()
	g.name = "Ground"
	add_child(g)
	var plane := PlaneMesh.new()
	plane.size = size
	var m := StandardMaterial3D.new()
	m.resource_name = name
	var noise := NoiseTexture2D.new()
	noise.width = 256
	noise.height = 256
	noise.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	noise.noise = n
	var grad := Gradient.new()
	grad.set_color(0, a)
	grad.set_color(1, b)
	noise.color_ramp = grad
	m.albedo_texture = noise
	m.uv1_scale = Vector3(size.x / 8.0, size.y / 8.0, 1)
	m.roughness = 0.9
	_mesh(g, plane, centre, m, false).name = name
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, 2.0, size.y)
	_solid(g, "Ground Body", bs, centre + Vector3(0, -1.0, 0))


func _bounds(x: float, z0: float, z1: float) -> void:
	# Invisible walls round the whole lair, so nobody wanders off the edge of the world
	var edge := Node3D.new()
	edge.name = "WorldBounds Lair"
	add_child(edge)
	var mid := (z0 + z1) / 2.0
	for w in [[Vector3(0, 6, z0), Vector3(x * 2.0, 12, 1)], [Vector3(0, 6, z1), Vector3(x * 2.0, 12, 1)],
			[Vector3(-x, 6, mid), Vector3(1, 12, z1 - z0)], [Vector3(x, 6, mid), Vector3(1, 12, z1 - z0)]]:
		var bs := BoxShape3D.new()
		bs.size = w[1]
		_solid(edge, "Edge", bs, w[0])
