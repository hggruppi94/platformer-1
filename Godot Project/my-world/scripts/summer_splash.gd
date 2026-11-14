extends Node

# Summer fun in Stars Hollow, and the quest "Summer Splash" (quests/summer_splash.json): a node "SummerSplash" under the
# EarthTown autoload (scripts/earth_town.gd), so dialogue can reach it as "EarthTown/SummerSplash.<method>" with no new
# autoload. Summer waits in Rhythm Springs, Melody's portal world, until it's mended (scripts/portals.gd "season"), and
# then Stars Hollow gets its first proper summer. Nina wants a beach day: find Prue's old swim ring by the Blastoffs'
# door and a bucket and spade at Nuts & Bolts Hardware, build a sandcastle with her on the little beach at Willow Pond,
# do a cannonball off the end of the dock, then cool off with pink lemonade at the Hollow Diner.
#
# All summer there's a little sandy beach on Willow Pond's east shore, just north of the dock, with two striped
# umbrellas and towels, and the end of the dock is a jumping spot for anyone (cannonball() any time). The sandcastle
# you built with Nina stays on the beach all summer. The notice board's summer sandcastle job (scripts/earth_jobs.gd)
# uses the beach too (CASTLE_SPOTS). Everything's put in the Earth scene at play time, and only in summer.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const QUEST := "summer_splash"
const BEACH := Vector2(-60.0, -5.5)            # the beach's middle (Willow Pond: EarthLand.POND, the dock runs along z = 0)
const BEACH_SIZE := Vector2(11.0, 8.0)         # x by z: from the water's edge up onto the grass
const CASTLE_AT := Vector2(-60.0, -4.5)        # the sandcastle you build with Nina
# Where the notice board's sandcastles go: round the beach, clear of the umbrellas and Nina's castle
# (all on dry sand: the shore's steep, so the dry part's a strip on the east side; and clear of the willow at (-62.5, -9))
const CASTLE_SPOTS := [Vector2(-61.5, -2.8), Vector2(-58.0, -3.0), Vector2(-57.5, -6.5), Vector2(-60.0, -7.5),
	Vector2(-62.8, -5.8), Vector2(-56.0, -4.5)]
const UMBRELLAS := [Vector3(-58.0, 0, -9.5), Vector3(-55.5, 0, -2.2)]   # x, (ground), z
const DOCK_END := Vector3(-73.2, 0.25, 0.0)    # where you jump from: the dock's top, near its far end (tools/build_earth.gd _dock)
const SPLASH_AT := Vector2(-78.5, 0.0)         # where you land: out in the deep middle of the pond
const JUMP_TIME := 1.1
const JUMP_HIGH := 2.6

var _jumping := false
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Dialogue.flag_set.connect(func(f: String) -> void:
		_refresh.call_deferred()
		if f == "splash_castle":
			_place_castle.call_deferred())


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_refresh()


func _earth() -> Node3D:
	var scene := get_tree().current_scene
	return scene as Node3D if scene and scene.scene_file_path == EarthTown.EARTH else null


func _on_scene_changed() -> void:
	var scene := _earth()
	if scene == null or Clock.season() != "summer" or scene.get_node_or_null("Summer Splash") != null:
		return
	var g := Node3D.new()
	g.name = "Summer Splash"
	scene.add_child(g)
	_beach(g)
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var space := scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(scene)
	_spot(g, "Swim Ring", paths.position_of("blastoff_door", space, skip) + Vector3(1.2, 0, 0.8), _ring_offer, _take_ring, true)
	_spot(g, "Bucket", paths.position_of("hardware", space, skip) + Vector3(1.4, 0, 1.0), _bucket_offer, _take_bucket, true)
	_spot(g, "Sandcastle Spot", ground(CASTLE_AT), _build_offer, _build, false)
	_spot(g, "Diving Spot", DOCK_END, _jump_offer, cannonball, false)
	_place_castle()


static func ground(at: Vector2) -> Vector3:
	return Vector3(at.x, EarthLand.height(at.x, at.y), at.y)


func _spot(g: Node3D, name: String, at: Vector3, offer: Callable, act: Callable, glow: bool) -> Node3D:
	var n := Node3D.new()
	n.name = name
	g.add_child(n)
	n.global_position = at
	var spot := USE_SPOT.make(Vector3.ZERO, offer, act, 2.0, 2.0)
	spot.name = "Spot"
	n.add_child(spot)
	if glow:
		# Something to pick up, glowing while the quest wants it: the swim ring, or a bucket with a spade in it
		var thing := ring_model() if name == "Swim Ring" else bucket_model()
		thing.name = "Thing"
		thing.position.y = 0.05
		n.add_child(thing)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.5)
		light.light_energy = 0.7
		light.omni_range = 2.0
		light.position.y = 0.6
		thing.add_child(light)
		thing.visible = _wants(name)
	return n


func _wants(name: String) -> bool:
	if not Quests.on_step(QUEST, "gather"):
		return false
	return not Dialogue.flags.has("splash_ring" if name == "Swim Ring" else "splash_bucket")


func _refresh() -> void:
	var scene := _earth()
	if scene == null:
		return
	for n in ["Swim Ring", "Bucket"]:
		var t := scene.get_node_or_null("Summer Splash/%s/Thing" % n) as Node3D
		if t:
			t.visible = _wants(n)


# --- The beach --------------------------------------------------------------------------------------------------------
func _beach(g: Node3D) -> void:
	# A patch of golden sand that follows the ground down to the water's edge, two striped umbrellas with towels under
	# them, and a beach ball
	var beach := Node3D.new()
	beach.name = "Beach"
	g.add_child(beach)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var corner := BEACH - BEACH_SIZE / 2.0
	for i in n:
		for j in n:
			var quad := [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]
			for q in quad:
				var u: Vector2 = q / float(n)
				# (an oval, not a square: the corners tuck under the grass)
				var e := ((u - Vector2(0.5, 0.5)) * 2.0).length()
				var p := corner + u * BEACH_SIZE
				var sink := 0.06 - smoothstep(0.75, 1.05, e) * 0.12
				st.add_vertex(Vector3(p.x, EarthLand.height(p.x, p.y) + sink, p.y))
	st.generate_normals()
	var sand := MeshInstance3D.new()
	sand.name = "Sand"
	sand.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.resource_name = "Beach Sand"
	m.albedo_color = Color(0.8, 0.62, 0.36)
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	sand.material_override = m
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beach.add_child(sand)
	var stripes := [[Color(0.95, 0.3, 0.35), Color(1, 1, 1)], [Color(0.15, 0.6, 0.85), Color(1.0, 0.85, 0.2)]]
	for k in UMBRELLAS.size():
		var u: Vector3 = UMBRELLAS[k]
		var umb := umbrella_model(stripes[k][0], stripes[k][1])
		beach.add_child(umb)
		umb.global_position = ground(Vector2(u.x, u.z))
		var towel := _box(beach, Vector3(0.9, 0.03, 1.8), stripes[k][0].lightened(0.25))
		towel.global_position = ground(Vector2(u.x + 0.7, u.z + 0.3)) + Vector3(0, 0.07, 0)
		towel.rotation.y = 0.4 + k
	var ball := MeshInstance3D.new()
	ball.name = "Beach Ball"
	var sp := SphereMesh.new()
	sp.radius = 0.25
	sp.height = 0.5
	ball.mesh = sp
	ball.material_override = _mat(Color(1.0, 0.45, 0.2))
	beach.add_child(ball)
	ball.global_position = ground(Vector2(-59.0, -6.0)) + Vector3(0, 0.27, 0)
	for k in 3:                                                      # (white and blue panels round it)
		var band := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.235
		t.outer_radius = 0.255
		band.mesh = t
		band.material_override = _mat([Color(1, 1, 1), Color(0.2, 0.5, 0.95), Color(1.0, 0.85, 0.2)][k])
		band.rotation = Vector3(PI / 2, k * PI / 3, 0)
		ball.add_child(band)


func _box(parent: Node3D, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


static func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func umbrella_model(a: Color, b: Color) -> Node3D:
	# A beach umbrella: a white pole and a striped canopy in two colours
	var g := Node3D.new()
	g.name = "Beach Umbrella"
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035
	c.bottom_radius = 0.035
	c.height = 2.3
	pole.mesh = c
	pole.material_override = _mat(Color(0.95, 0.95, 0.95))
	pole.position.y = 1.15
	g.add_child(pole)
	var canopy := MeshInstance3D.new()
	canopy.mesh = _cone(1.3, 0.5)
	canopy.material_override = _mat(a)
	canopy.position.y = 2.2
	g.add_child(canopy)
	# Stripes: four flattened cones a hair bigger, crossing at the top, so they show as wedges of the other colour
	for k in 4:
		var stripe := MeshInstance3D.new()
		stripe.mesh = _cone(1.32, 0.51)
		stripe.material_override = _mat(b)
		stripe.position.y = 2.2
		stripe.rotation.y = TAU * k / 8.0
		stripe.scale = Vector3(1.0, 1.0, 0.3)
		g.add_child(stripe)
	return g


static func _cone(r: float, h: float) -> CylinderMesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = r
	cone.height = h
	cone.radial_segments = 16
	return cone


static func sandcastle_model(size := 1.0) -> Node3D:
	# A sandcastle: a square keep with four round towers, pointy tops, a little flag, and a shell on the front
	var g := Node3D.new()
	g.name = "Sandcastle"
	var sand := _mat(Color(0.9, 0.76, 0.5))
	var wet := _mat(Color(0.78, 0.64, 0.42))
	var keep := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.7, 0.45, 0.7) * size
	keep.mesh = b
	keep.material_override = wet
	keep.position.y = 0.225 * size
	g.add_child(keep)
	for k in 4:
		var x := (0.35 if k % 2 else -0.35) * size
		var z := (0.35 if k < 2 else -0.35) * size
		var tower := MeshInstance3D.new()
		var t := CylinderMesh.new()
		t.top_radius = 0.15 * size
		t.bottom_radius = 0.18 * size
		t.height = 0.6 * size
		t.radial_segments = 10
		tower.mesh = t
		tower.material_override = sand
		tower.position = Vector3(x, 0.3 * size, z)
		g.add_child(tower)
		var top := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.0
		tc.bottom_radius = 0.17 * size
		tc.height = 0.25 * size
		tc.radial_segments = 10
		top.mesh = tc
		top.material_override = sand
		top.position = Vector3(x, 0.72 * size, z)
		g.add_child(top)
	var middle := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.12 * size
	mc.bottom_radius = 0.2 * size
	mc.height = 0.45 * size
	mc.radial_segments = 10
	middle.mesh = mc
	middle.material_override = sand
	middle.position.y = 0.67 * size
	g.add_child(middle)
	var stick := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.01 * size
	sc.bottom_radius = 0.01 * size
	sc.height = 0.4 * size
	stick.mesh = sc
	stick.material_override = _mat(Color(0.5, 0.35, 0.2))
	stick.position.y = 1.08 * size
	g.add_child(stick)
	var flag := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(0.18, 0.12, 0.01) * size
	flag.mesh = fb
	flag.material_override = _mat(Color(0.95, 0.25, 0.35))
	flag.position = Vector3(0.1 * size, 1.22 * size, 0)
	g.add_child(flag)
	var shell := MeshInstance3D.new()
	var ss := SphereMesh.new()
	ss.radius = 0.06 * size
	ss.height = 0.12 * size
	shell.mesh = ss
	shell.material_override = _mat(Color(1.0, 0.8, 0.8))
	shell.position = Vector3(0, 0.25 * size, 0.36 * size)
	shell.scale = Vector3(1.0, 0.8, 0.4)
	g.add_child(shell)
	return g


static func ring_model() -> Node3D:
	# Prue's old swim ring: a fat red and white striped ring, lying on the ground
	var g := Node3D.new()
	for k in 2:
		var r := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.18
		t.outer_radius = 0.38
		t.rings = 16
		r.mesh = t
		r.material_override = _mat(Color(0.95, 0.25, 0.25) if k == 0 else Color(1, 1, 1))
		r.position.y = 0.1 + k * 0.005
		r.scale = Vector3(1.0, 1.0, 1.0) if k == 0 else Vector3(1.01, 1.02, 0.35)
		g.add_child(r)
	return g


static func bucket_model() -> Node3D:
	# A blue bucket with a yellow spade sticking out of it
	var g := Node3D.new()
	var b := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.17
	c.bottom_radius = 0.13
	c.height = 0.3
	b.mesh = c
	b.material_override = _mat(Color(0.2, 0.5, 0.95))
	b.position.y = 0.15
	g.add_child(b)
	var handle := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.15
	t.outer_radius = 0.17
	handle.mesh = t
	handle.material_override = _mat(Color(1.0, 0.85, 0.2))
	handle.position.y = 0.3
	handle.rotation.x = PI / 2
	g.add_child(handle)
	var spade := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.04, 0.45, 0.04)
	spade.mesh = sb
	spade.material_override = _mat(Color(1.0, 0.85, 0.2))
	spade.position = Vector3(0.05, 0.38, 0)
	spade.rotation.z = -0.3
	g.add_child(spade)
	return g


# --- The quest's steps -----------------------------------------------------------------------------------------------
func _ring_offer() -> String:
	return "take Prue's old swim ring" if _wants("Swim Ring") else ""


func _take_ring() -> void:
	if not _wants("Swim Ring"):
		return
	Dialogue.set_flag("splash_ring")
	Game.message("Prue's note: \"IT HAS A HOLE. BLOW HARDER.\"")
	Audio.play("pickup", -4.0)
	_refresh()


func _bucket_offer() -> String:
	return "take a bucket and spade" if _wants("Bucket") else ""


func _take_bucket() -> void:
	if not _wants("Bucket"):
		return
	Dialogue.set_flag("splash_bucket")
	Game.message("Hank: \"On the house!\"")
	Audio.play("pickup", -4.0)
	_refresh()


func _build_offer() -> String:
	return "build a sandcastle with Nina" if Quests.on_step(QUEST, "build") else ""


func _build() -> void:
	if not Quests.on_step(QUEST, "build"):
		return
	Dialogue.set_flag("splash_castle")
	Game.message("A sandcastle with four towers!")
	Juice.blip("sparkle", 1.2, -4.0)


func _place_castle() -> void:
	# The sandcastle you built with Nina stays on the beach all summer
	var g := _earth().get_node_or_null("Summer Splash") as Node3D if _earth() else null
	if g == null or not Dialogue.flags.has("splash_castle") or g.get_node_or_null("Our Sandcastle") != null:
		return
	var sc := sandcastle_model(1.3)
	sc.name = "Our Sandcastle"
	g.add_child(sc)
	sc.global_position = (g.get_node("Sandcastle Spot") as Node3D).global_position
	sc.rotation.y = -PI / 2                     # (facing the water)
	var ring := ring_model()
	ring.name = "Moat Ring"
	sc.add_child(ring)
	ring.scale = Vector3.ONE * 2.6
	ring.position.y = -0.2
	Fx.burst(g, sc.global_position + Vector3.UP * 0.6, Color(0.93, 0.82, 0.58), 18, 0.08, 2.5, -3.0, 0.9)


# --- Cannonball off the dock -----------------------------------------------------------------------------------------
func _jump_offer() -> String:
	return "CANNONBALL into Willow Pond!" if not _jumping else ""


func splash_point() -> Vector3:
	return Vector3(SPLASH_AT.x, EarthLand.WATER_Y, SPLASH_AT.y)


func cannonball() -> void:
	# Up off the end of the dock in an arc, curled up tight, and down into the deep middle of the pond with a huge splash
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or _jumping:
		return
	_jumping = true
	Game.hold_controls(&"cannonball", true, player)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var from := DOCK_END + Vector3(0, 0.8, 0)
	var to := splash_point() + Vector3(0, 0.3, 0)
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.y = atan2(to.x - from.x, to.z - from.z)
	Juice.blip("whoosh", 1.0, -4.0)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		player.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * JUMP_HIGH, 0)
		if visual:
			# (tucked into a ball for the way down)
			var tuck := smoothstep(0.15, 0.4, t)
			visual.scale = Vector3(1.0 + tuck * 0.15, 1.0 - tuck * 0.35, 1.0 + tuck * 0.15),
		0.0, 1.0, JUMP_TIME)
	tw.tween_callback(func() -> void:
		if visual:
			visual.scale = Vector3.ONE
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		Game.hold_controls(&"cannonball", false, player)
		_jumping = false
		var at := splash_point()
		var scene := get_tree().current_scene
		for c in [Color(0.85, 0.95, 1.0), Color(0.55, 0.8, 1.0)]:
			Fx.burst(scene, at + Vector3.UP * 0.2, c, 26, 0.12, 5.0, -6.0, 1.2)
		Fx.ripple(scene, at)
		Audio.play_at("splash", at, 2.0)
		Juice.shake(0.25)
		if Quests.on_step(QUEST, "jump"):
			Dialogue.set_flag("splash_jumped")
			Game.message("KER-SPLOOSH! Nina: \"A TEN! Lemonade time!\""))


func is_jumping() -> bool:
	return _jumping
