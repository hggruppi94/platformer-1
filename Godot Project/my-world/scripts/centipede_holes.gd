extends Node3D

# The centipede's holes round the Void: her gulp as a way to get about, the second half of her reward once Dark Hollow
# is mended (Hayden, 10 Nov 2026, "Both": wall crawl, scripts/wall_crawl.gd, and her gulp working as fast travel
# between places you've found).
#
# Six little burrows dug in the Void (HOLES), each a ring of turned-up earth round a dark hole with roots and a few
# glowing fungi, like her corner in the school. Walk up to one and you've found it (Portals.note_found("dark_hollow",
# "hole_<id>")); her head pops up to look at you. Knock (Interact) and she asks where to: any other hole you've found,
# her home (the hollow log behind the old Scary World gate), or Dark Hollow itself. Then the same cartoon gulp as in
# her corner in the school (the screen
# closes like a mouth, "GULP!", a glowy slide), and "PTOO!" out you pop. Her hollow log at home can send you to any
# hole you've found too (scripts/scary_world.gd). Choices are recorded in Dialogue.choice_log as RECORD.
#
# Since 11 Nov 2026 her story goes in order (Hayden: the old gate, then her corner and the gulp, then Dark Hollow, then
# her home), so the holes only open once she's met you at home and shared her gifts (gifts_given()), and the statics
# below say where she is in it for everything else (the gate, her corner, Dark Hollow, wall crawl).
#
# Put into the Void at play time by Portals._hub_changes() (scripts/portals.gd), so town.tscn isn't rebuilt. The spots
# were checked flat, dry and clear: off the races, the townsfolk's paths, trees and portals (tools/test_wall_crawl.gd).

const USE_SPOT := preload("res://scripts/use_spot.gd")
const WORLD := "dark_hollow"
const RECORD := "centipede_travel"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"
const HOME_AT := Vector3(3.5, 1.0, -9.0)           # in the Scary World, on the path just in front of her by her hollow log
const HOME_YAW := PI                               # facing her (and the log)
# "at" is the hole, "y" the ground there, "face" a point she looks towards when she pops out (the place it's near)
const HOLES := [
	{"id": "market", "name": "the Market", "at": Vector2(-62.5, 54.5), "y": -0.02, "face": Vector2(-72, 49)},
	{"id": "skate_park", "name": "the Skate Park", "at": Vector2(56.4, 64.4), "y": 0.37, "face": Vector2(50, 58)},
	{"id": "gardens", "name": "the Secret Gardens", "at": Vector2(-80.0, -18.0), "y": 12.14, "face": Vector2(-80, -27)},
	{"id": "observatory", "name": "Observatory Hill", "at": Vector2(103.2, -78.6), "y": 15.8, "face": Vector2(96.4, -80.4)},
	{"id": "homes", "name": "the homes' park", "at": Vector2(87.8, 10.5), "y": -0.04, "face": Vector2(80, 6)},
	{"id": "castle", "name": "the castle gate", "at": Vector2(31.1, -88.8), "y": 15.9, "face": Vector2(37.2, -92.3)},
]
const FIND_NEAR := 4.5
const PEEK_NEAR := 7.0
const OUT := 2.0                                   # you pop out this far from the hole, towards its place
const HEAD_UP := 0.55
const HEAD_DOWN := -1.4
const CIRCLE_TIME := 0.9
const IRIS_TIME := 0.6
const SLIDE_TIME := 1.6

var spots := {}                                    # id -> its use spot
var heads := {}                                    # id -> her head peeping out of it
var travels := 0                                   # (tests read this)
var gulping := false
var _log_before := 0
var _from := ""
var _overlay: CanvasLayer


# Where she is in her story -------------------------------------------------------------------------------------------
static func gate_said_yes() -> bool:
	# Step one: a yes at the old Scary World gate (or, from before the story went in order, having been through it or
	# said yes in her corner)
	var f: Dictionary = Dialogue.flags
	return f.has("scary_world_said_yes") or f.has("scary_world_visited") or f.has("dark_hollow_said_yes")


static func at_home() -> bool:
	# Step four: Dark Hollow's mended, so she lives at her hollow log behind the old gate, and nowhere else
	return Portals.is_cleared(WORLD)


static func gifts_given() -> bool:
	# She's met you at home and taught you wall crawl and her holes (saves from before taught it in Dark Hollow)
	return at_home() and (Dialogue.flags.has("centipede_gifts") or Portals.has_found(WORLD, "thanked"))


# Where to ------------------------------------------------------------------------------------------------------------
static func ids() -> Array:
	var out: Array = ["home"]
	for h in HOLES:
		out.append(h.id)
	return out


static func hole(id: String) -> Dictionary:
	for h in HOLES:
		if h.id == id:
			return h
	return {}


static func found(id: String) -> bool:
	return Portals.has_found(WORLD, "hole_" + id)


static func found_count() -> int:
	var n := 0
	for h in HOLES:
		if found(h.id):
			n += 1
	return n


static func travel_choices(from: String) -> Array:
	# A choice for each place she can take you from here: the holes you've found, and her home (from a hole)
	var out: Array = []
	for h in HOLES:
		if h.id != from and found(h.id):
			out.append({"text": "Pop me out by %s." % h.name, "answer": h.id, "record": RECORD,
				"lines": ["%s? Right you are. Hold on to your hat!" % str(h.name).capitalize()]})
	if from != "home":
		out.append({"text": "Your home, by the old gate.", "answer": "home", "record": RECORD,
			"lines": ["Home! I'll put the kettle on. (I don't have a kettle.) Here we go..."]})
	return out


static func landing(id: String) -> Array:
	# [position, yaw] where you pop out by a hole: a step from it towards its place, facing the place
	var h := hole(id)
	var at: Vector2 = h.at
	var face: Vector2 = h.face
	var d := (face - at).normalized()
	var p := at + d * OUT
	return [Vector3(p.x, float(h.y) + 1.0, p.y), atan2(d.x, d.y)]


static func arrive(id: String, overlay: CanvasLayer) -> void:
	# The end of the slide: out you pop at the hole (or her home, or Dark Hollow)
	var tree := Engine.get_main_loop() as SceneTree
	Game.hold_controls(&"gulp", false)
	var scene := tree.current_scene
	var player := tree.get_first_node_in_group("player") as CharacterBody3D
	if player and player.get("wall_crawl") and player.wall_crawl.active:
		player.wall_crawl.stop()
	if id == "dark_hollow":
		_free_later(tree, overlay)
		Portals.enter_dark_hollow()
		return
	if id == "home":
		_free_later(tree, overlay)
		Game.pending_message = "PTOO! Out you pop by her hollow log, behind the old gate."
		Game.go_to_point(SCARY, HOME_AT, HOME_YAW, "the Scary World")
		return
	var h := hole(id)
	if h.is_empty():
		_free_later(tree, overlay)
		return
	var land := landing(id)
	if scene and scene.scene_file_path == TOWN and player:
		# Already in the Void: straight there, and the mouth opens again on the new place
		var g: Vector3 = Remnants.ground_at(h.at)
		var p: Vector3 = land[0]
		p.y = g.y + 1.0
		player.global_position = p
		player.velocity = Vector3.ZERO
		player.visual.rotation.y = float(land[1])
		var arm := player.get("spring_arm") as Node3D
		if arm:
			arm.rotation.y = float(land[1]) + PI           # camera behind her, as on arriving through a door
		if overlay and overlay.has_method("open_up"):
			overlay.call("open_up", 0.5)
		else:
			_free_later(tree, overlay)
		Juice.blip("pop", 1.3, -4.0)
		Game.message("PTOO! Out you pop by %s." % h.name)
		return
	_free_later(tree, overlay)
	Game.pending_message = "PTOO! Out you pop by %s." % h.name
	Game.go_to_point(TOWN, land[0], float(land[1]), "the Void")


static func _free_later(tree: SceneTree, o: CanvasLayer) -> void:
	if o == null:
		return
	tree.create_timer(0.8, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(o):
			o.queue_free())


static func gulp_overlay() -> CanvasLayer:
	# The same mouth-closing overlay as her corner's gulp (scripts/centipede_corner.gd's Gulp)
	var corner: GDScript = load("res://scripts/centipede_corner.gd")
	var o: CanvasLayer = corner.Gulp.new()
	o.name = "Gulp"
	o.layer = 90
	return o


# The holes in the Void ---------------------------------------------------------------------------------------------------
func _ready() -> void:
	for h in HOLES:
		var g: Vector3 = Remnants.ground_at(h.at)
		var root := Node3D.new()
		root.name = "Hole %s" % h.id
		add_child(root)
		root.global_position = g
		_build(root, h)
		var head := _head()
		root.add_child(head)
		head.position = Vector3(0, HEAD_DOWN, 0)
		head.visible = false
		heads[h.id] = head
		var id: String = h.id
		var spot := USE_SPOT.make(g, func() -> String: return _offer(id), func() -> void: knock(id), 2.2, 1.9)
		spot.name = "Knock %s" % h.id
		add_child(spot)
		spots[h.id] = spot
	Dialogue.finished.connect(_on_talked)


func _head() -> Node3D:
	var scene := load("res://scenes/creatures/centipede.tscn") as PackedScene
	var whole := scene.instantiate()                   # only its head (as in scripts/centipede_friend.gd)
	var head := whole.get_node("Head") as Node3D
	whole.remove_child(head)
	whole.free()
	head.name = "Her Head"
	head.scale = Vector3.ONE * 0.7
	return head


func _offer(id: String) -> String:
	return "" if gulping else "knock on the centipede's hole"


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for h in HOLES:
		var root := get_node("Hole %s" % h.id) as Node3D
		var d := Vector2(player.global_position.x - root.global_position.x, player.global_position.z - root.global_position.z).length()
		var near := d < PEEK_NEAR and absf(player.global_position.y - root.global_position.y) < 4.0
		if near and d < FIND_NEAR and not found(h.id):
			Portals.note_found(WORLD, "hole_" + str(h.id))
			Game.message("You found one of the centipede's holes, by %s! Knock on it and she'll take you along her tunnels." % h.name)
			Juice.blip("chime", 1.2, -6.0)
		var head: Node3D = heads[h.id]
		if gulping and _from == h.id:
			continue
		var want := HEAD_UP if near else HEAD_DOWN
		head.position.y = move_toward(head.position.y, want, 3.5 * delta)
		head.visible = head.position.y > HEAD_DOWN + 0.2
		if head.visible:
			var to := player.global_position - head.global_position
			head.rotation.y = lerp_angle(head.rotation.y, atan2(to.x, to.z), minf(1.0, 4.0 * delta))


func knock(id: String) -> void:
	if gulping:
		return
	if not found(id):
		Portals.note_found(WORLD, "hole_" + id)
	_from = id
	_log_before = Dialogue.choice_log.size()
	Juice.blip("thud", 1.5, -6.0)                       # knock knock knock
	get_tree().create_timer(0.18).timeout.connect(func() -> void: Juice.blip("thud", 1.6, -6.0))
	get_tree().create_timer(0.36).timeout.connect(func() -> void: Juice.blip("thud", 1.5, -6.0))
	Dialogue.say(spots[id], _name(), lines(id), "centipede_hole")


func _name() -> String:
	var n := str(Dialogue.names.get("centipede", ""))
	return n if n != "" else "The Centipede"


func lines(id: String) -> Array:
	var choice: Array = [{"text": "Dark Hollow, please!", "answer": "dark_hollow", "record": RECORD,
		"lines": ["Home sweet home! Gulp, slide, ptoo!"]}]
	choice.append_array(travel_choices(id))
	choice.append({"text": "Not now, thanks.", "answer": "no", "record": RECORD,
		"lines": ["Okay! Knock any time. I can hear a knock from anywhere in my tunnels."]})
	var out: Array = ["(Knock knock knock. Lots and lots of little feet come pattering up the tunnel, and her pale face pops out.)",
		"{player}! You knocked! Where shall I take you?"]
	if found_count() < HOLES.size():
		out.append("(I've got %d holes round the Void. You've found %d. The rest are near the places everyone likes best.)" % [HOLES.size(), found_count()])
	out.append({"choice": choice})
	return out


func _on_talked(talk_id: String) -> void:
	if talk_id != "centipede_hole":
		return
	for k in range(_log_before, Dialogue.choice_log.size()):
		var e: Dictionary = Dialogue.choice_log[k]
		var a := str(e.get("answer", ""))
		if str(e.get("what", "")) == RECORD and (a == "dark_hollow" or a in ids()):
			travel.call_deferred(a)
			return


func travel(to: String) -> void:
	# Her head comes right up out of the hole and round you... GULP! Then the slide along her tunnels.
	if gulping:
		return
	gulping = true
	travels += 1
	Game.hold_controls(&"gulp", true)
	var head: Node3D = heads.get(_from) if heads.has(_from) else null
	var tw := create_tween()
	if head:
		head.visible = true
		tw.tween_property(head, "position:y", 1.6, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(head, "scale", Vector3.ONE * 1.2, 0.3)
		tw.tween_property(head, "rotation:y", head.rotation.y + TAU * (0.5 if Settings.reduce_motion else 1.0), CIRCLE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		Audio.play_at("centipede_skitter", head.global_position, -2.0)
	else:
		tw.tween_interval(0.3)
	tw.tween_callback(_close)
	tw.tween_interval(IRIS_TIME + 0.4)
	tw.tween_callback(func() -> void:
		if _overlay:
			_overlay.call("slide")
		Juice.blip("whoosh", 0.8, -4.0))
	tw.tween_interval(SLIDE_TIME)
	tw.tween_callback(func() -> void:
		if head:
			head.scale = Vector3.ONE * 0.7
			head.position.y = HEAD_DOWN
		gulping = false
		var o := _overlay
		_overlay = null
		arrive(to, o))


func _close() -> void:
	_overlay = gulp_overlay()
	get_tree().root.add_child(_overlay)
	_overlay.call("close", IRIS_TIME)
	Juice.blip("pop", 0.45, 0.0)
	Juice.blip("thud", 0.7, -4.0)
	Juice.shake(0.2)
	Juice.rumble(0.5, 0.3, 0.3)


# Her burrow: a ring of turned-up earth round a dark hole, roots poking out and glowing fungi ------------------------------
func _build(root: Node3D, h: Dictionary) -> void:
	var earth := _mat(Color(0.3, 0.2, 0.17), 0.0, 0.95)
	var dark := _mat(Color(0.02, 0.01, 0.03), 0.0, 1.0)
	var root_m := _mat(Color(0.42, 0.28, 0.2), 0.0, 0.9)
	var glow := _mat(Color(0.45, 0.95, 0.85), 1.6, 0.6)
	var glow2 := _mat(Color(0.8, 0.5, 1.0), 1.4, 0.6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 1.05
	ring.rings = 20
	ring.ring_segments = 10
	var m := _put(root, ring, earth, Vector3(0, 0.02, 0))
	m.scale = Vector3(1.0, 0.45, 1.0)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.68
	disc.bottom_radius = 0.5
	disc.height = 0.06
	_put(root, disc, dark, Vector3(0, 0.05, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(h.id))
	for k in 5:                                         # roots curling out over the rim
		var a := k * TAU / 5.0 + rng.randf() * 0.5
		var c := CylinderMesh.new()
		c.top_radius = 0.025
		c.bottom_radius = 0.06
		c.height = 0.7
		var r := _put(root, c, root_m, Vector3(cos(a) * 0.75, 0.16, sin(a) * 0.75))
		r.rotation = Vector3(0, -a, 1.25 + rng.randf() * 0.3)
	for k in 4:                                         # glowing fungi on the earth
		var a := rng.randf() * TAU
		var cap := SphereMesh.new()
		cap.radius = 0.08 + rng.randf() * 0.05
		cap.height = cap.radius
		cap.is_hemisphere = true
		_put(root, cap, glow if k % 2 == 0 else glow2, Vector3(cos(a) * 1.0, 0.12, sin(a) * 1.0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.95, 0.85)
	light.light_energy = 0.6
	light.omni_range = 2.5
	light.position = Vector3(0, 0.5, 0)
	root.add_child(light)


func _mat(c: Color, emit := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
