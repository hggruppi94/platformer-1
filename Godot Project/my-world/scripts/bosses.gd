extends Node

# Autoload "Bosses": the Agent of Chaos's side of Galaxity (Hayden, Nov 1, 2026: "Agent of Chaos is the game's final
# boss... a new enemy called time goblins. Each enemy will have a larger boss version").
#
# Placed into the town at runtime (like the request board, scripts/requests.gd), so none of it needs the town rebuilt:
#   - The Goblin Clockyard, out in the northeast fields by the Agent's patrol: a ring of tumbledown grandfather clocks
#     where the Time Goblins (scripts/time_goblin.gd) live, plus a few goblins roaming towards the Observatory.
#     Their boss, Grandfather Tock (scripts/time_goblin_boss.gd), keeps the middle of it.
#   - Boulder Hollow, in the far northwest: a ring of big boulders where the Boulderdillo (scripts/crocodillo_boss.gd),
#     the Crocodillos' boss, rolls about. (The Gloops' boss is the Gloop King, built into the town.)
#
# Every enemy's boss is remembered here once beaten (Dialogue flags, so it's saved with everything else).

const TOWN := "res://scenes/town/town.tscn"
const GOBLIN := "res://scenes/enemies/time_goblin.tscn"
const TOCK := "res://scenes/enemies/time_goblin_boss.tscn"
const CROC := "res://scenes/enemies/crocodillo.tscn"
const HOLLOW := Vector2(-118, -180)             # x, z: Boulder Hollow, flat open ground in the northwest
const HOLLOW_RADIUS := 17.0

const CLOCKYARD := Vector2(128, -150)          # x, z: open, flat ground east of the Agent's field (the world's east
                                              # wall is at x 146, so it keeps well in from that)
const CLOCKYARD_RADIUS := 9.0
# Where the goblins start: the clockyard gang, and pairs out roaming
const GOBLIN_SPOTS := [
	Vector2(124, -146), Vector2(133, -153), Vector2(129, -143), Vector2(124, -154),
	Vector2(120, -125), Vector2(126, -121),
	Vector2(92, -206), Vector2(98, -214),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != TOWN or scene.get_node_or_null("Goblin Clockyard") != null:
		return
	_place_clockyard(scene)
	_place_hollow(scene)


func ground(scene: Node3D, x: float, z: float) -> Vector3:
	# The ground height at (x, z): a ray straight down, ignoring anything that moves (players, enemies, the little
	# saucers and the mothership)
	var space := scene.get_world_3d().direct_space_state
	var from := Vector3(x, 60.0, z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 120.0)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	while hit and (not (hit.collider is StaticBody3D) or hit.collider is AnimatableBody3D):   # (saucers fly over)
		q.exclude = q.exclude + [(hit.collider as CollisionObject3D).get_rid()]
		hit = space.intersect_ray(q)
	return hit.position if hit else Vector3(x, 0.0, z)


# -----------------------------------------------------------------------------
# The Goblin Clockyard
# -----------------------------------------------------------------------------
func _place_clockyard(scene: Node) -> void:
	var yard := Node3D.new()
	yard.name = "Goblin Clockyard"
	yard.set_script(load("res://scripts/landmark.gd"))
	yard.set("label", "Goblin Clockyard")
	scene.add_child(yard)
	yard.global_position = ground(scene, CLOCKYARD.x, CLOCKYARD.y)
	_clock_ring(yard)
	var enemies := scene.find_child("Enemies", true, false)
	var parent: Node = enemies if enemies else scene
	var goblin := load(GOBLIN) as PackedScene
	var i := 0
	for p in GOBLIN_SPOTS:
		var g := goblin.instantiate() as Node3D
		g.name = "Time Goblin %d" % i
		g.position = _local(parent, ground(scene, p.x, p.y) + Vector3(0, 0.2, 0))    # before _ready reads its home
		parent.add_child(g)
		i += 1
	var tock := (load(TOCK) as PackedScene).instantiate() as Node3D
	tock.name = "Grandfather Tock"                        # not "Time Goblin …", so finding goblins by name skips him
	tock.set("size", 2.4)
	tock.set("color", Color(0.5, 1.0, 0.9))
	tock.set("stomps_to_defeat", 8)
	tock.set("damage", 2)
	tock.set("xp_reward", 50)
	tock.set("wander_radius", 5.0)
	tock.set("sight_range", 16.0)
	tock.set("leash_range", 26.0)
	tock.set("wander_speed", 1.2)
	tock.set("chase_speed", 3.3)
	tock.set("blink_cooldown", 7.0)
	tock.set("blink_chance", 0.85)
	tock.set("dizzy_time", 2.4)
	tock.set("respawn_time", 150.0)
	tock.position = _local(parent, ground(scene, CLOCKYARD.x, CLOCKYARD.y) + Vector3(0, 0.3, 0))
	parent.add_child(tock)


# -----------------------------------------------------------------------------
# Boulder Hollow
# -----------------------------------------------------------------------------
func _place_hollow(scene: Node) -> void:
	var hollow := Node3D.new()
	hollow.name = "Boulder Hollow"
	hollow.set_script(load("res://scripts/landmark.gd"))
	hollow.set("label", "Boulder Hollow")
	scene.add_child(hollow)
	hollow.global_position = ground(scene, HOLLOW.x, HOLLOW.y)
	var rock := _mat(Color(0.5, 0.44, 0.55))
	var moss := _mat(Color(0.3, 0.6, 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for k in 14:
		if k == 3 or k == 10:                          # two ways in
			continue
		var a := TAU * k / 14.0
		var r := rng.randf_range(1.4, 2.4)
		var b := StaticBody3D.new()
		b.name = "Boulder %d" % k
		b.position = Vector3(cos(a), 0, sin(a)) * HOLLOW_RADIUS + Vector3(0, r * 0.6, 0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 1.6
		sm.radial_segments = 9
		sm.rings = 5
		mi.mesh = sm
		mi.material_override = rock
		mi.rotation = Vector3(rng.randf(), rng.randf() * TAU, rng.randf() * 0.3)
		b.add_child(mi)
		var cap := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = r * 0.7
		cm.height = r * 0.5
		cap.mesh = cm
		cap.material_override = moss
		cap.position = Vector3(0, r * 0.6, 0)
		b.add_child(cap)
		var cs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = r * 0.85
		cs.shape = ss
		b.add_child(cs)
		hollow.add_child(b)
	var enemies := scene.find_child("Enemies", true, false)
	var parent: Node = enemies if enemies else scene
	var boss := (load(CROC) as PackedScene).instantiate() as CharacterBody3D
	boss.set_script(load("res://scripts/crocodillo_boss.gd"))
	boss.name = "The Boulderdillo"                       # not "Crocodillo …", so finding Crocodillos by name skips it
	boss.set("size", 2.6)
	boss.set("stomps_to_defeat", 10)
	boss.set("damage", 3)
	boss.set("xp_reward", 60)
	boss.set("wander_radius", 6.0)
	boss.set("sight_range", 20.0)
	boss.set("leash_range", 30.0)
	boss.set("stalk_speed", 2.6)
	boss.set("roll_speed", 11.0)
	boss.set("roll_time", 1.3)
	boss.set("dizzy_time", 3.6)
	boss.set("roll_cooldown", 2.0)
	boss.set("respawn_time", 180.0)
	boss.position = _local(parent, hollow.global_position + Vector3(0, 0.4, 0))
	parent.add_child(boss)


func _local(parent: Node, at: Vector3) -> Vector3:
	return (parent as Node3D).global_transform.affine_inverse() * at if parent is Node3D else at


func _clock_ring(yard: Node3D) -> void:
	# Tumbledown grandfather clocks leaning every which way, cogs in the grass, all stopped at different times
	var wood := _mat(Color(0.42, 0.2, 0.17))
	var face := _mat(Color(0.98, 0.95, 0.85), 0.6)
	var brass := _mat(Color(0.85, 0.62, 0.25), 0.0, 0.85)
	var ink := _mat(Color(0.08, 0.05, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	for k in 7:
		var a := TAU * k / 7.0 + 0.3
		var c := Node3D.new()
		c.name = "Clock %d" % k
		yard.add_child(c)
		var h := rng.randf_range(2.2, 3.2)
		c.position = Vector3(cos(a), 0, sin(a)) * CLOCKYARD_RADIUS
		c.rotation = Vector3(rng.randf_range(-0.25, 0.25), -a + PI / 2, rng.randf_range(-0.3, 0.3))
		_box(c, Vector3(0.8, h, 0.55), Vector3(0, h / 2, 0), wood)
		_box(c, Vector3(0.95, 0.25, 0.65), Vector3(0, h + 0.1, 0), wood)
		var f := _cyl(c, 0.3, 0.05, Vector3(0, h - 0.4, 0.29), face)
		f.rotation.x = PI / 2
		var hand := _box(c, Vector3(0.04, 0.22, 0.02), Vector3(0, h - 0.4, 0.33), ink)
		hand.rotation.z = rng.randf_range(0, TAU)
		_box(c, Vector3(0.05, 0.6, 0.02), Vector3(0, h * 0.35, 0.29), brass)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.8, h, 0.55)
		cs.shape = bs
		cs.position = Vector3(0, h / 2, 0)
		body.add_child(cs)
		c.add_child(body)
	for k in 9:
		var cog := _cyl(yard, rng.randf_range(0.25, 0.6), 0.12,
			Vector3(rng.randf_range(-6, 6), 0.06, rng.randf_range(-6, 6)), brass)
		cog.rotation.x = rng.randf_range(-0.2, 0.2)


func _mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.4 if metal > 0.0 else 0.7
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	mi.mesh = c
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi
