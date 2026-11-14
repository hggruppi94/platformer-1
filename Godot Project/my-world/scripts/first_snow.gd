extends Node

# Winter fun in Stars Hollow, and the quest "The First Snow" (quests/first_snow.json): a node "FirstSnow" under the
# EarthTown autoload (scripts/earth_town.gd), so dialogue can reach it as "EarthTown/FirstSnow.<method>" with no new
# autoload. Once winter's come (it waits in the Frozen Moment: plan item 20), Nina wants to build a snowman: find a
# carrot for its nose at the Corner Market and Prue's old scarf at the Blastoffs' door, build it with her on the green,
# sled down Lookout Hill, then warm up with cocoa at the Hollow Diner. The snowman stays on the green all winter, and
# the sled on the hilltop stays for anyone who wants another go. Everything's put in the Earth scene at play time, and
# only in winter.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const QUEST := "first_snow"
const SNOWMAN_AT := Vector2(1.5, -11.0)      # the snowman, on the green's north side between two trees, by Nina
const SLED_DIR := 5.5                          # which way the sled run goes from the hill's middle (north-east: clear)
const SLED_FROM := 10.0                        # from this far out on the flat top...
const SLED_TO := 44.0                          # ...to this far, past the foot of the slope
const SLED_TIME := 4.0

var _sledding := false
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Dialogue.flag_set.connect(func(f: String) -> void:
		_refresh.call_deferred()
		if f == "snow_built":
			_place_snowman.call_deferred())


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
	if scene == null or Clock.season() != "winter" or scene.get_node_or_null("First Snow") != null:
		return
	var g := Node3D.new()
	g.name = "First Snow"
	scene.add_child(g)
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var space := scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(scene)
	_spot(g, "Snow Carrot", paths.position_of("market", space, skip) + Vector3(1.6, 0, 1.0), _carrot_offer, _take_carrot, true)
	_spot(g, "Snow Scarf", paths.position_of("blastoff_door", space, skip) + Vector3(1.2, 0, 0.8), _scarf_offer, _take_scarf, true)
	_spot(g, "Snowman Spot", Vector3(SNOWMAN_AT.x, EarthLand.height(SNOWMAN_AT.x, SNOWMAN_AT.y), SNOWMAN_AT.y), _build_offer, _build, false)
	var sled := _spot(g, "Sled", sled_start(), _sled_offer, sled_down, false)
	sled.add_child(sled_model())
	_place_snowman()


func _spot(g: Node3D, name: String, at: Vector3, offer: Callable, act: Callable, glow: bool) -> Node3D:
	var n := Node3D.new()
	n.name = name
	g.add_child(n)
	n.global_position = at
	var spot := USE_SPOT.make(Vector3.ZERO, offer, act, 2.0, 2.0)
	spot.name = "Spot"
	n.add_child(spot)
	if glow:
		# Something to pick up: a little bundle with a glow round it while the quest wants it
		var thing := MeshInstance3D.new()
		thing.name = "Thing"
		var b := BoxMesh.new()
		b.size = Vector3(0.35, 0.25, 0.35)
		thing.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.5, 0.1) if name == "Snow Carrot" else Color(0.85, 0.15, 0.2)
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 0.6
		thing.material_override = m
		thing.position.y = 0.4
		n.add_child(thing)
		thing.visible = _wants(name)
	return n


func _wants(name: String) -> bool:
	if not Quests.on_step(QUEST, "gather"):
		return false
	return not Dialogue.flags.has("snow_carrot" if name == "Snow Carrot" else "snow_scarf")


func _refresh() -> void:
	var scene := _earth()
	if scene == null:
		return
	for n in ["Snow Carrot", "Snow Scarf"]:
		var t := scene.get_node_or_null("First Snow/%s/Thing" % n) as Node3D
		if t:
			t.visible = _wants(n)


# --- The quest's steps -----------------------------------------------------------------------------------------------
func _carrot_offer() -> String:
	return "take a carrot for the snowman's nose" if _wants("Snow Carrot") else ""


func _take_carrot() -> void:
	if not _wants("Snow Carrot"):
		return
	Dialogue.set_flag("snow_carrot")
	Game.message("Kip: \"Take the wonkiest one!\"")
	Audio.play("pickup", -4.0)
	_refresh()


func _scarf_offer() -> String:
	return "take Prue's old scarf" if _wants("Snow Scarf") else ""


func _take_scarf() -> void:
	if not _wants("Snow Scarf"):
		return
	Dialogue.set_flag("snow_scarf")
	Game.message("Prue's note: \"FOR THE SNOWMAN. HE GETS COLD.\"")
	Audio.play("pickup", -4.0)
	_refresh()


func _build_offer() -> String:
	return "build the snowman with Nina" if Quests.on_step(QUEST, "build") else ""


func _build() -> void:
	if not Quests.on_step(QUEST, "build"):
		return
	Dialogue.set_flag("snow_built")
	Game.message("A snowman! With a wonky carrot nose!")
	Juice.blip("sparkle", 1.2, -4.0)


func _place_snowman() -> void:
	# The snowman you built with Nina stands on the green all winter
	var g := _earth().get_node_or_null("First Snow") as Node3D if _earth() else null
	if g == null or not Dialogue.flags.has("snow_built") or g.get_node_or_null("Our Snowman") != null:
		return
	var sm: Node3D = load("res://scripts/seasons.gd").snowman_model(1.0)
	sm.name = "Our Snowman"
	g.add_child(sm)
	sm.global_position = (g.get_node("Snowman Spot") as Node3D).global_position
	sm.rotation.y = PI
	Fx.burst(g, sm.global_position + Vector3.UP, Color(1, 1, 1), 20, 0.1, 3.0, -2.5, 1.0)


# --- Sledding down Lookout Hill --------------------------------------------------------------------------------------
func sled_line() -> Array[Vector3]:
	# The run, a point a metre, on the snow from the flat top to past the foot of the hill
	var out: Array[Vector3] = []
	var dir := Vector2(cos(SLED_DIR), sin(SLED_DIR))
	var d := SLED_FROM
	while d <= SLED_TO:
		var p := EarthLand.HILL + dir * d
		out.append(Vector3(p.x, EarthLand.height(p.x, p.y) + 0.15, p.y))
		d += 1.0
	return out


func sled_start() -> Vector3:
	return sled_line()[0] - Vector3(0, 0.15, 0)


func _sled_offer() -> String:
	return "sled down Lookout Hill!" if not _sledding else ""


func sled_down() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or _sledding:
		return
	var curve := Curve3D.new()
	for p in sled_line():
		curve.add_point(p)
	_sledding = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	var sled := sled_model()
	sled.name = "Riding Sled"
	player.add_child(sled)
	sled.position.y = -0.95                   # (the player's middle is 0.8 up: the sled's on the snow)
	Juice.blip("whoosh", 1.2, -4.0)
	var length := curve.get_baked_length()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var d := length * t
		var at := curve.sample_baked(d)
		var ahead := curve.sample_baked(minf(d + 0.5, length))
		player.global_position = at + Vector3(0, 0.8, 0)
		var visual := player.get_node_or_null("Visual") as Node3D
		if visual and ahead.distance_to(at) > 0.01:
			visual.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
			sled.rotation.y = visual.rotation.y,
		0.0, 1.0, SLED_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		sled.queue_free()
		_sledding = false
		Fx.burst(get_tree().current_scene, player.global_position, Color(1, 1, 1), 16, 0.08, 3.0, -3.0, 0.8)
		Juice.blip("thud", 1.0, -8.0)
		if Quests.on_step(QUEST, "sled"):
			Dialogue.set_flag("snow_sledded")
			Game.message("WHEEEE! Nina: \"Cocoa! Hollow Diner!\""))


func is_sledding() -> bool:
	return _sledding


static func sled_model() -> Node3D:
	# A red wooden sled with curled runners
	var g := Node3D.new()
	g.name = "Sled"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.8, 0.18, 0.15)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.75, 0.8)
	metal.metallic = 0.6
	var deck := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.6, 0.08, 1.2)
	deck.mesh = b
	deck.material_override = wood
	deck.position.y = 0.22
	g.add_child(deck)
	for sx in [-0.26, 0.26]:
		var run := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.05, 0.05, 1.3)
		run.mesh = rb
		run.material_override = metal
		run.position = Vector3(sx, 0.05, 0)
		g.add_child(run)
		var curl := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.1
		t.outer_radius = 0.14
		curl.mesh = t
		curl.material_override = metal
		curl.position = Vector3(sx, 0.17, 0.62)
		curl.rotation.z = PI / 2
		g.add_child(curl)
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.05, 0.16, 0.05)
		leg.mesh = lb
		leg.material_override = wood
		leg.position = Vector3(sx, 0.12, 0)
		g.add_child(leg)
	return g
