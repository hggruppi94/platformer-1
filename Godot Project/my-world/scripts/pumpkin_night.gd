extends Node

# Autumn's quest in Stars Hollow, "Pumpkin Night" (quests/pumpkin_night.json; overnight polish, 15 Nov 2026, a first
# draft for Hayden): winter, spring and summer each had a quest with Nina and autumn, the season every game starts in,
# had none. Pick a pumpkin at the patch and get a candle from Hank, carve it with Nina on the green, light it on the
# Blastoffs' porch (it glows there for the rest of autumn), then warm cider with Gus. A "PumpkinNight" node under the
# EarthTown autoload (scripts/earth_town.gd), so dialogue can reach it as "EarthTown/PumpkinNight". Everything's put in
# the Earth scene at play time, and only in autumn, the same way scripts/first_snow.gd does winter's.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const QUEST := "pumpkin_night"
const CARVE_AT := Vector2(1.5, -11.0)        # on the green's north side by Nina (the snowman's spot, empty in autumn)
const PORCH_OFF := Vector3(1.2, 0, 0.8)      # beside the Blastoffs' door (where Prue's scarf waits in winter)
const ORANGE := Color(0.95, 0.5, 0.12)
const GLOW := Color(1.0, 0.75, 0.2)

var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Dialogue.flag_set.connect(func(f: String) -> void:
		_refresh.call_deferred()
		if f == "pn_lit":
			_place_lantern.call_deferred())


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
	if scene == null or Clock.season() != "autumn" or scene.get_node_or_null("Pumpkin Night") != null:
		return
	var g := Node3D.new()
	g.name = "Pumpkin Night"
	scene.add_child(g)
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var space := scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(scene)
	var pumpkin := _spot(g, "Pick Pumpkin", paths.position_of("pumpkin_patch", space, skip) + Vector3(1.4, 0, 1.0),
		func() -> String: return "pick a pumpkin" if _wants("pn_pumpkin") else "",
		func() -> void: _take("pn_pumpkin", "The roundest one! Perfect."))
	pumpkin.add_child(_thing("Thing", pumpkin_model(false)))
	var candle := _spot(g, "Candle", paths.position_of("hardware", space, skip) + Vector3(-1.6, 0, 1.0),
		func() -> String: return "take a candle" if _wants("pn_candle") else "",
		func() -> void: _take("pn_candle", "Hank: \"Mind the flame, kiddo.\""))
	candle.add_child(_thing("Thing", candle_model()))
	var carve := _spot(g, "Carving Spot", Vector3(CARVE_AT.x, EarthLand.height(CARVE_AT.x, CARVE_AT.y), CARVE_AT.y),
		func() -> String: return "carve the pumpkin with Nina" if Quests.on_step(QUEST, "carve") else "",
		_carve)
	carve.add_child(_thing("Uncarved", pumpkin_model(false)))
	var porch := _spot(g, "Porch", paths.position_of("blastoff_door", space, skip) + PORCH_OFF,
		func() -> String: return "light the jack-o'-lantern" if Quests.on_step(QUEST, "porch") else "",
		_light)
	var unlit := _thing("Unlit", pumpkin_model(true, false))
	porch.add_child(unlit)
	unlit.global_rotation.y = atan2(-porch.global_position.x, -porch.global_position.z)
	_place_lantern()
	_refresh()


func _spot(g: Node3D, name: String, at: Vector3, offer: Callable, act: Callable) -> Node3D:
	var n := Node3D.new()
	n.name = name
	g.add_child(n)
	n.global_position = at
	var spot := USE_SPOT.make(Vector3.ZERO, offer, act, 2.0, 2.0)
	spot.name = "Spot"
	n.add_child(spot)
	return n


func _thing(name: String, model: Node3D) -> Node3D:
	model.name = name
	return model


func _wants(flag: String) -> bool:
	return Quests.on_step(QUEST, "gather") and not Dialogue.flags.has(flag)


func _refresh() -> void:
	var g := _earth().get_node_or_null("Pumpkin Night") as Node3D if _earth() else null
	if g == null:
		return
	var shown := {
		"Pick Pumpkin/Thing": _wants("pn_pumpkin"),
		"Candle/Thing": _wants("pn_candle"),
		"Carving Spot/Uncarved": Quests.on_step(QUEST, "carve"),
		"Porch/Unlit": Quests.on_step(QUEST, "porch"),
	}
	for path: String in shown:
		var n := g.get_node_or_null(path) as Node3D
		if n:
			n.visible = bool(shown[path])


# --- The quest's steps -----------------------------------------------------------------------------------------------
func _take(flag: String, line: String) -> void:
	if not _wants(flag):
		return
	Dialogue.set_flag(flag)
	Game.message(line)
	Audio.play("pickup", -4.0)
	_refresh()


func _carve() -> void:
	if not Quests.on_step(QUEST, "carve"):
		return
	Dialogue.set_flag("pn_carved")
	Game.message("A big toothy grin! Nina did the eyes.")
	var at := (_earth().get_node("Pumpkin Night/Carving Spot") as Node3D).global_position
	Fx.burst(_earth(), at + Vector3(0, 0.5, 0), ORANGE, 16, 0.07, 2.5, -3.0, 0.7)
	Juice.blip("pop", 1.1, -4.0)


func _light() -> void:
	if not Quests.on_step(QUEST, "porch"):
		return
	Dialogue.set_flag("pn_lit")
	Game.message("It glows! Spooky!")
	Juice.blip("sparkle", 1.2, -4.0)


func _place_lantern() -> void:
	# The lantern you carved with Nina glows by the Blastoffs' door for the rest of autumn
	var g := _earth().get_node_or_null("Pumpkin Night") as Node3D if _earth() else null
	if g == null or not Dialogue.flags.has("pn_lit") or g.get_node_or_null("Our Lantern") != null:
		return
	var lantern := pumpkin_model(true, true)
	lantern.name = "Our Lantern"
	g.add_child(lantern)
	lantern.global_position = (g.get_node("Porch") as Node3D).global_position
	# Its grin faces the town green, out over Maple Lane, so people going by see it
	lantern.rotation.y = atan2(-lantern.global_position.x, -lantern.global_position.z)
	Fx.burst(g, lantern.global_position + Vector3(0, 0.4, 0), GLOW, 14, 0.06, 2.0, -1.5, 0.8)


# --- Looks -------------------------------------------------------------------------------------------------------------
static func pumpkin_model(carved: bool, lit := false) -> Node3D:
	# A plump pumpkin with ribs and a stalk; carved, it has a grin, and lit, the grin glows with a candle inside
	var root := Node3D.new()
	var skin := _mat(ORANGE, 0.15 if not lit else 0.4)
	for k in 6:
		var rib := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.24
		s.height = 0.42
		rib.mesh = s
		rib.material_override = skin
		var a := TAU * k / 6.0
		rib.position = Vector3(cos(a) * 0.1, 0.22, sin(a) * 0.1)
		root.add_child(rib)
	var stalk := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.03
	c.bottom_radius = 0.05
	c.height = 0.14
	stalk.mesh = c
	stalk.material_override = _mat(Color(0.35, 0.42, 0.15))
	stalk.position.y = 0.48
	root.add_child(stalk)
	if carved:
		var face := _mat(GLOW, 3.0) if lit else _mat(Color(0.2, 0.08, 0.02))
		for sx in [-1.0, 1.0]:
			_bit(root, Vector3(0.08, 0.07, 0.02), Vector3(sx * 0.1, 0.3, 0.33), face, PI / 4.0)
		_bit(root, Vector3(0.24, 0.05, 0.02), Vector3(0, 0.16, 0.33), face, 0.0)
		for tx in [-0.06, 0.06]:
			_bit(root, Vector3(0.04, 0.05, 0.02), Vector3(tx, 0.2, 0.335), skin, 0.0)
		if lit:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.6, 0.2)
			light.light_energy = 1.4
			light.omni_range = 4.5
			light.position.y = 0.25
			root.add_child(light)
	return root


static func candle_model() -> Node3D:
	var root := Node3D.new()
	var wax := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.06
	c.height = 0.22
	wax.mesh = c
	wax.material_override = _mat(Color(0.98, 0.93, 0.8), 0.2)
	wax.position.y = 0.4
	root.add_child(wax)
	var flame := MeshInstance3D.new()
	var f := SphereMesh.new()
	f.radius = 0.03
	f.height = 0.08
	flame.mesh = f
	flame.material_override = _mat(GLOW, 3.0)
	flame.position.y = 0.55
	root.add_child(flame)
	return root


static func _bit(parent: Node3D, size: Vector3, at: Vector3, m: Material, turn: float) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	b.mesh = bm
	b.material_override = m
	b.position = at
	b.rotation.z = turn
	parent.add_child(b)


static func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m
