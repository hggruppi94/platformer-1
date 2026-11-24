extends "res://scripts/boss_lair.gd"

# The seven virtue trials on the Skyreach Trail (24 Nov 2026, Hayden: "the way points can literally be invisible
# portals that transport you to instances that have the same heavenly theme with different challenges", "I want them
# to be based on the heavenly virtues", "Make them not optional if you want to make it to the very end"). Each trail
# Waystone (scripts/skyreach_trail.gd) is a way in: hug it and you're here, in one shared scene
# (scenes/bosses/virtue_trial.tscn, from tools/build_boss_lairs.gd) that builds whichever trial you came for. Reach
# the altar at the end and its gate of light on the trail opens; you're put back beside the Waystone you came from.
#
#   Humility    The Lowly Way: a grand gold stair goes nowhere; the way on is the low path under the arches.
#   Patience    The Waiting Stones: stand still and the next stepping stone fades in out of the clouds.
#   Kindness    The Lost Lamb: find a lost lamb and lead it home across the bridges to its mother.
#   Temperance  The Golden Scales: take exactly five golden pears to the scales. Take a sixth and they all go back.
#   Charity     The Cherubs' Gift: give ALL your sparkles into the bowl to begin (Hayden: "you receive them back
#               after you complete the challenge 2x"), then carry feathers to six sad cherubs.
#   Diligence   The Long Climb: thirty steps round a pillar of light, with lamps to start again from.
#   Purity      The Mirror Pool: cross a mirror walkway without touching the drifting dark mists.
#
# Nothing here ever hurts: falling floats you back, mists and wind only send you back a bit. Leaving by the Way Out
# goes back to the Waystone with nothing lost (Charity gives back what you put in). The trial you're in is the Bosses
# autoload's meta "virtue_trial" ({id, stone, pos, yaw, held}); finished ones are Dialogue flags "virtue_<id>".

const SCENE := "res://scenes/bosses/virtue_trial.tscn"
const SKYREACH := "res://scenes/bosses/skyreach_trail.tscn"
const VIRTUES := [
	{"id": "humility", "name": "Humility", "colour": Color(0.75, 0.7, 1.0), "title": "The Lowly Way",
		"line": "The way on is the lowly one."},
	{"id": "patience", "name": "Patience", "colour": Color(0.55, 0.8, 1.0), "title": "The Waiting Stones",
		"line": "Be still, and the way will come."},
	{"id": "kindness", "name": "Kindness", "colour": Color(1.0, 0.6, 0.75), "title": "The Lost Lamb",
		"line": "A little lamb is lost. Bring it home."},
	{"id": "temperance", "name": "Temperance", "colour": Color(1.0, 0.82, 0.4), "title": "The Golden Scales",
		"line": "Bring the scales five pears. Not one more."},
	{"id": "charity", "name": "Charity", "colour": Color(1.0, 0.45, 0.45), "title": "The Cherubs' Gift",
		"line": "Give all you have. It comes back twice over."},
	{"id": "diligence", "name": "Diligence", "colour": Color(0.55, 0.9, 0.55), "title": "The Long Climb",
		"line": "Step by step, all the way up."},
	{"id": "purity", "name": "Purity", "colour": Color(0.92, 0.95, 1.0), "title": "The Mirror Pool",
		"line": "Keep clear of the dark mists."},
]
const REWARD := 8                        # sparkles the first time each trial's done (and a Remnant)
const ALL_REWARD := 30                   # all seven: these, 3 Remnants and the Laurel of Virtues
const FALL_Y := -6.0
const MARBLE := Color(0.93, 0.91, 0.87)
const GOLD := Color(1.0, 0.76, 0.32)

var id := "humility"
var virtue: Dictionary = VIRTUES[0]
var done := false
var check := Vector3(0, 1.0, 3.0)        # where a fall floats you back to
var altar_at := Vector3(0, 0, 50)
var _said := {}
# Patience
var waits: Array[Node3D] = []
var revealed := 0
var still_t := 0.0
# Kindness
var lamb: Node3D
var mother: Node3D
var lamb_following := false
var lamb_at_home := false
var _trail: Array[Vector3] = []
# Temperance
var pears: Array[Node3D] = []
var carried := 0
# Charity
var given := false
var barrier: StaticBody3D
var feathers: Array[Node3D] = []
var cherubs: Array[Node3D] = []
var feathers_held := 0
var happy := 0
var gift_bridge: Node3D
# Diligence
var steps: Array[Node3D] = []
var lamps := [0]                         # step numbers you start again from (0 is the floor)
var lamp_at := 0
# Purity
var mists: Array[Node3D] = []
var lilies := [6.0, 22.0, 36.0]
var lily_at := 0
var pear_wait: Node3D = null        # Temperance: the pear you're by when they all go back


# -----------------------------------------------------------------------------
# Going in and out (static, so the trail and the save can use them)
# -----------------------------------------------------------------------------
static func virtue_of(vid: String) -> Dictionary:
	for v in VIRTUES:
		if str(v.id) == vid:
			return v
	return VIRTUES[0]


static func is_done(vid: String) -> bool:
	return Dialogue.flags.has("virtue_" + vid)


static func all_done() -> bool:
	for v in VIRTUES:
		if not is_done(str(v.id)):
			return false
	return true


static func enter(vid: String, stone: int, back: Vector3, yaw: float) -> void:
	Bosses.set_meta("virtue_trial", {"id": vid, "stone": stone, "pos": back, "yaw": yaw, "held": 0})
	Game.go(SCENE, "Entrance", "the Trial of %s" % str(virtue_of(vid).name))


static func state() -> Dictionary:
	return Bosses.get_meta("virtue_trial", {}) if Bosses.has_meta("virtue_trial") else {}


static func held() -> int:
	# Sparkles given into Charity's bowl and not yet given back (the save counts them as yours, so none are ever lost)
	return int(state().get("held", 0))


static func save_place() -> Dictionary:
	# Saving in a trial saves you back beside its Waystone on the trail
	var s := state()
	var tree := Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree else null
	if s.is_empty() or scene == null or scene.scene_file_path != SCENE:
		return {}
	var p: Vector3 = s.pos
	return {"scene": SKYREACH, "position": [p.x, p.y, p.z], "yaw": float(s.yaw)}


func lair_id() -> String:
	return "virtue"


func arena() -> Vector3:
	return altar_at


# -----------------------------------------------------------------------------
# Building it
# -----------------------------------------------------------------------------
func _build() -> void:
	var s := state()
	id = str(s.get("id", "humility"))
	virtue = virtue_of(id)
	_environment(Color(0.36, 0.6, 0.95), Color(1.0, 0.93, 0.78), Color(0.97, 0.96, 1.0), Color(1.0, 0.97, 0.92), 0.004,
		Color(1.0, 0.95, 0.82))
	# (the same soft heaven as the trail: a blue light from round about, not the sky's white, so nothing washes out)
	var env := (get_node("Lair Sky") as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.76, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_exposure = 0.85
	env.fog_light_color = Color(0.86, 0.88, 0.95)
	env.fog_density = 0.0025
	_clouds()
	_beams()
	_bounds(40.0, -8.0, 80.0)
	# Everyone starts on the same marble landing, with the trial's name and one short line
	_isle("Landing", Vector3(0, 0, 3.5), Vector3(14, 0, 13))
	_sign(self, "Trial of %s\n%s" % [str(virtue.name), str(virtue.line)], Vector3(-4.2, 0, 6.5), PI + 0.35,
		Color(0.92, 0.88, 0.78))
	match id:
		"humility": _build_humility()
		"patience": _build_patience()
		"kindness": _build_kindness()
		"temperance": _build_temperance()
		"charity": _build_charity()
		"diligence": _build_diligence()
		"purity": _build_purity()
	_altar()


func _isle(name: String, centre: Vector3, size: Vector3, m: Material = null) -> MeshInstance3D:
	# A slab of marble whose top is at centre.y (everything you walk on is flush: you can't step up a ledge on foot),
	# with a gold edge round it
	var h := 1.2
	var mi := _box(self, name, Vector3(size.x, h, size.z), centre + Vector3(0, -h / 2.0, 0),
		m if m else _mat("Trial Marble", MARBLE, 0.35))
	var gold := _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8)
	_box(self, name + " Rim", Vector3(size.x + 0.1, 0.16, size.z + 0.1), centre + Vector3(0, -0.12, 0), gold, false)
	var under := CylinderMesh.new()
	under.top_radius = minf(size.x, size.z) * 0.45
	under.bottom_radius = 0.2
	under.height = 3.0
	_mesh(self, under, centre + Vector3(0, -2.7, 0), _mat("Trial Underside", Color(0.85, 0.83, 0.8), 0.6), false)
	return mi


func _clouds() -> void:
	# A sea of clouds below everything (falling into it floats you back) and a few drifting at the sides
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mm.mesh = sm
	mm.instance_count = 160
	var r := RandomNumberGenerator.new()
	r.seed = 777
	for i in mm.instance_count:
		var s := r.randf_range(4.0, 9.0)
		var at := Vector3(r.randf_range(-70, 70), r.randf_range(-16, -9), r.randf_range(-30, 110))
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s * 1.6, s * 0.6, s)), at))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Cloud Sea"
	mi.multimesh = mm
	mi.material_override = _mat("Trial Cloud", Color(1.0, 0.99, 0.97), 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _beams() -> void:
	var m := _mat("Trial Beam", Color(1.0, 0.95, 0.8, 0.1), 0.2, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 5:
		var c := CylinderMesh.new()
		c.top_radius = 2.0
		c.bottom_radius = 4.5
		c.height = 70.0
		var mi := _mesh(self, c, Vector3(-30 + k * 15, 25, 20 + (k % 2) * 30), m, false)
		mi.rotation.z = 0.12 * (k - 2)
		mi.name = "Heaven Light"


func _altar() -> void:
	# The end: a gold dish on a marble pedestal with the virtue's emblem turning over it. Walk up to it.
	var g := Node3D.new()
	g.name = "Altar"
	g.position = altar_at
	add_child(g)
	_cyl(g, "Pedestal", 0.6, 0.8, 1.1, Vector3(0, 0.55, 0), _mat("Trial Marble", MARBLE, 0.35))
	_cyl(g, "Dish", 0.9, 0.5, 0.2, Vector3(0, 1.2, 0), _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8), false)
	var col: Color = virtue.colour
	var em := Node3D.new()
	em.name = "Emblem"
	em.position = Vector3(0, 2.1, 0)
	g.add_child(em)
	var star := _mat("Emblem %s" % id, col, 0.2, 2.6)
	_ball(em, "Heart", 0.28, Vector3.ZERO, star, false)
	for k in 6:
		var ray := _box(em, "Ray", Vector3(0.08, 0.6, 0.08), Vector3.ZERO, star, false)
		ray.rotation.z = k * PI / 3.0
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.position.y = 2.1
	g.add_child(l)


func _way_home(at: Vector3, name: String) -> Node3D:
	# The Way Out goes back to the Waystone (not to town), with nothing lost
	var b := Node3D.new()
	b.name = name
	b.position = at
	add_child(b)
	_way_look(b)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if done else "go back to the Waystone",
		go_home, 2.4, 3.2)
	spot.name = "Home Spot"
	b.add_child(spot)
	return b


# --- Humility ----------------------------------------------------------------
func _build_humility() -> void:
	# A plain low path under eight low arches, and beside it a grand gold stair up to a balcony that goes nowhere
	_isle("Low Path", Vector3(0, 0, 28), Vector3(4, 0, 36))
	altar_at = Vector3(0, 0, 50)
	_isle("Altar Isle", Vector3(0, 0, 50), Vector3(10, 0, 10))
	var marble := _mat("Trial Marble", MARBLE, 0.35)
	for k in 8:
		var z := 13.0 + k * 4.5
		for side in [-1.0, 1.0]:
			_box(self, "Arch Post", Vector3(0.5, 2.0, 0.5), Vector3(side * 1.75, 1.0, z), marble)
		_box(self, "Arch", Vector3(4.0, 0.5, 0.6), Vector3(0, 2.25, z), _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8))
	var gold := _mat("Proud Gold", Color(1.0, 0.82, 0.35), 0.25, 0.6, 0.9)
	for k in 6:
		_isle("Proud Step %d" % (k + 1), Vector3(-6.5, 0.8 * (k + 1), 9.0 + k * 1.6), Vector3(3.0, 0, 1.6), gold)
	_isle("Proud Balcony", Vector3(-6.5, 4.8, 15.5), Vector3(4.0, 0, 4.0), gold)
	_sign(self, "So high! But the way on is the lowly one.", Vector3(-6.5, 4.8, 17.0), PI, Color(0.92, 0.88, 0.78))


func _step_humility(_delta: float) -> void:
	# Pride's wind: leap up proud under the arches and it blows you back to their start
	var p := _player.global_position
	if p.z > 12.0 and p.z < 47.0 and absf(p.x) < 2.2 and p.y > 1.7:
		_send_back(Vector3(0, 1.0, 10.0), "A proud leap! The wind blows you back. Stay low.")


# --- Patience ----------------------------------------------------------------
func _build_patience() -> void:
	# Seven stepping stones hidden in the clouds. Stand still near where the next should be and it fades in.
	for k in 7:
		var at := Vector3(0, 0, 14.0 + k * 4.0)
		var before := get_child_count()
		var mi := _isle("Waiting Stone %d" % (k + 1), at, Vector3(2.4, 0, 2.4))
		var body := get_node("Waiting Stone %d Body" % (k + 1)) as StaticBody3D
		# Its gold rim and the cloud under it hide with it, so nothing shows the way until you've waited
		var parts: Array[Node3D] = []
		for i in range(before, get_child_count()):
			var n := get_child(i) as Node3D
			if n and n != body:
				n.visible = false
				parts.append(n)
		var g := Node3D.new()
		g.name = "Wait %d" % (k + 1)
		g.position = at
		add_child(g)
		var glow := _mesh(g, _disc(1.1), Vector3(0, 0.05, 0), _mat("Wait Glow", Color(0.55, 0.8, 1.0, 0.5), 0.2, 2.0), false)
		glow.name = "Glow"
		g.set_meta("stone", mi)
		g.set_meta("parts", parts)
		g.set_meta("body", body)
		(body.get_child(0) as CollisionShape3D).disabled = true
		glow.scale = Vector3(0.1, 1, 0.1)
		waits.append(g)
	# The altar's isle starts right where the last stone ends, so the last step on is a walk, not a leap
	altar_at = Vector3(0, 0, 44)
	_isle("Altar Isle", Vector3(0, 0, 44.4), Vector3(10, 0, 10))


func _disc(r: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.04
	return c


func _step_patience(delta: float) -> void:
	if revealed >= waits.size():
		return
	var cb := _player as CharacterBody3D
	var next := waits[revealed]
	var d := next.global_position - cb.global_position
	var flat := Vector2(cb.velocity.x, cb.velocity.z).length()
	if Vector2(d.x, d.z).length() < 4.8 and cb.is_on_floor() and flat < 0.3:
		still_t += delta
	else:
		if still_t > 0.4 and flat >= 0.3:
			_say_once("patience", "Be still... wait for the way.")
		still_t = 0.0
	var glow := next.get_node("Glow") as Node3D
	var k := clampf(still_t / 2.0, 0.1, 1.0)
	glow.scale = Vector3(k, 1, k)
	if still_t >= 2.0:
		reveal_next()


func reveal_next() -> void:
	if revealed >= waits.size():
		return
	var g := waits[revealed]
	for n in g.get_meta("parts"):
		(n as Node3D).visible = true
	((g.get_meta("body") as StaticBody3D).get_child(0) as CollisionShape3D).disabled = false
	(g.get_node("Glow") as Node3D).visible = false
	Juice.blip("chime", 1.0 + revealed * 0.08, -6.0)
	Fx.burst(self, g.global_position + Vector3(0, 0.3, 0), virtue.colour, 12, 0.07, 2.0, 0.5, 0.6)
	revealed += 1
	still_t = 0.0
	check = g.global_position + Vector3(0, 1.0, 0) if revealed > 1 else check


# --- Kindness ----------------------------------------------------------------
func _build_kindness() -> void:
	# A crossroads isle, a far isle where the lamb is lost, and its mother waiting on the altar isle
	_isle("North Bridge", Vector3(0, 0, 15), Vector3(2.0, 0, 10))
	_isle("Crossroads", Vector3(0, 0, 24), Vector3(7, 0, 8))
	_isle("West Bridge", Vector3(-8.5, 0, 24), Vector3(10, 0, 1.8))
	_isle("Lamb Isle", Vector3(-17, 0, 24), Vector3(8, 0, 8))
	_isle("East Bridge", Vector3(8.5, 0, 24), Vector3(10, 0, 1.8))
	_isle("Fold Isle", Vector3(17, 0, 24), Vector3(9, 0, 9))
	altar_at = Vector3(19.5, 0, 26.5)
	lamb = _sheep(0.6, "Lamb")
	lamb.position = Vector3(-18, 0, 25)
	mother = _sheep(1.0, "Mother Sheep")
	mother.position = Vector3(16, 0, 22)
	mother.rotation.y = PI * 0.75


func _sheep(s: float, name: String) -> Node3D:
	# A fluffy white sheep of puffs with a dark face and two little white wings (they're in heaven)
	var g := Node3D.new()
	g.name = name
	add_child(g)
	var wool := _mat("Wool", Color(0.98, 0.97, 0.95), 1.0)
	var face := _mat("Sheep Face", Color(0.25, 0.22, 0.25), 0.8)
	for k in 6:
		var a := k * TAU / 6.0
		_ball(g, "Fluff", 0.3 * s, Vector3(cos(a) * 0.25 * s, 0.6 * s + sin(a * 2.0) * 0.06, sin(a) * 0.35 * s), wool, false)
	_ball(g, "Body", 0.4 * s, Vector3(0, 0.6 * s, 0), wool, false)
	_ball(g, "Head", 0.2 * s, Vector3(0, 0.75 * s, 0.48 * s), face, false)
	for side in [-1.0, 1.0]:
		_ball(g, "Eye", 0.04 * s, Vector3(side * 0.08 * s, 0.8 * s, 0.65 * s), _mat("Sheep Eye", Color(1, 1, 1), 0.3), false)
		var w := _ball(g, "Wing", 0.18 * s, Vector3(side * 0.42 * s, 0.85 * s, -0.05 * s), _mat("Sheep Wing", Color(1, 1, 1), 0.4, 0.5), false)
		w.scale = Vector3(0.3, 1.0, 1.4)
		w.rotation.z = side * 0.5
		for fx in [-0.18, 0.18]:
			_cyl(g, "Leg", 0.05 * s, 0.05 * s, 0.4 * s, Vector3(side * 0.18 * s, 0.2 * s, fx * s * 1.4), face, false)
	return g


func _step_kindness(delta: float) -> void:
	var p := _player.global_position
	var lp := lamb.global_position
	if not lamb_following and Vector2(p.x - lp.x, p.z - lp.z).length() < 3.0:
		lamb_following = true
		Game.message("Baa! The lamb follows you. Take it to its mother.")
		Juice.blip("chime", 1.6, -6.0)
	if lamb_following:
		# It trots along your footsteps a little way behind (its wings flutter it back if it ever falls behind)
		if _trail.is_empty() or _trail[-1].distance_to(Vector3(p.x, 0, p.z)) > 0.4:
			_trail.append(Vector3(p.x, 0, p.z))
			if _trail.size() > 80:
				_trail.remove_at(0)
		var target := _trail[maxi(0, _trail.size() - 5)]
		var to := target - Vector3(lp.x, 0, lp.z)
		if to.length() > 12.0:
			lamb.position = target
		elif to.length() > 0.3:
			var step := to.normalized() * minf(to.length(), 6.5 * delta)
			lamb.position += Vector3(step.x, 0, step.z)
			lamb.rotation.y = atan2(to.x, to.z)
		lamb.position.y = absf(sin(_t * 10.0)) * 0.08
	# Once you're beside its mother the lamb runs the last bit to her by itself
	var near_mum := Vector2(p.x - mother.position.x, p.z - mother.position.z).length() < 4.0
	if lamb_following and (near_mum or lamb.global_position.distance_to(mother.global_position) < 3.2):
		# Home: it stays snuggled by its mother (so it's still home when you walk on to the altar)
		lamb_following = false
		lamb_at_home = true
		lamb.position = mother.position + Vector3(-0.9, 0, 0.6)
		lamb.rotation.y = mother.rotation.y
		Juice.blip("sparkle", 1.4, -4.0)
		Fx.burst(self, mother.global_position + Vector3(0, 1.2, 0), virtue.colour, 16, 0.06, 2.0, 0.5, 0.8)
		_say_once("kind", "The lamb is home! Now to the altar.")


func lamb_home() -> bool:
	return lamb_at_home


# --- Temperance --------------------------------------------------------------
func _build_temperance() -> void:
	# An orchard isle with thirty golden pears. The scales want exactly five.
	_isle("Orchard", Vector3(0, 0, 20), Vector3(30, 0, 20))
	altar_at = Vector3(0, 0, 37)
	_isle("Scales Isle", Vector3(0, 0, 36), Vector3(10, 0, 12))
	var pear := _mat("Golden Pear", Color(1.0, 0.82, 0.3), 0.3, 0.8, 0.6)
	var leaf := _mat("Pear Leaf", Color(0.4, 0.8, 0.4), 0.6)
	for row in 5:
		for col in [-13.0, -8.0, -3.0, 3.0, 8.0, 13.0]:
			var g := Node3D.new()
			g.name = "Pear"
			g.position = Vector3(col, 0, 13.0 + row * 4.0)
			add_child(g)
			_cyl(g, "Stand", 0.12, 0.2, 0.7, Vector3(0, 0.35, 0), _mat("Trial Marble", MARBLE, 0.35), false)
			var fruit := Node3D.new()
			fruit.name = "Fruit"
			fruit.position.y = 1.0
			g.add_child(fruit)
			_ball(fruit, "Bottom", 0.2, Vector3.ZERO, pear, false)
			_ball(fruit, "Top", 0.13, Vector3(0, 0.18, 0), pear, false)
			_box(fruit, "Leaf", Vector3(0.12, 0.02, 0.06), Vector3(0.06, 0.32, 0), leaf, false)
			pears.append(g)
	# The scales: two gold pans on a beam, waiting
	var s := Node3D.new()
	s.name = "Scales"
	s.position = altar_at + Vector3(2.6, 0, 0)
	add_child(s)
	var gold := _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8)
	_cyl(s, "Post", 0.08, 0.12, 1.8, Vector3(0, 0.9, 0), gold, false)
	_box(s, "Beam", Vector3(1.6, 0.06, 0.06), Vector3(0, 1.8, 0), gold, false)
	for side in [-1.0, 1.0]:
		_cyl(s, "Pan", 0.35, 0.25, 0.08, Vector3(side * 0.8, 1.4, 0), gold, false)


func _step_temperance(_delta: float) -> void:
	var p := _player.global_position
	# After the pears all go back, the one you're standing by can't be picked again until you step away from it
	if pear_wait and Vector2(p.x - pear_wait.position.x, p.z - pear_wait.position.z).length() > 1.3:
		pear_wait = null
	for g in pears:
		if g != pear_wait and g.visible and Vector2(p.x - g.position.x, p.z - g.position.z).length() < 0.85 \
				and p.y < 2.6:
			take_pear(g)


func take_pear(g: Node3D) -> void:
	g.visible = false
	carried += 1
	if carried > 5:
		# Too many: every pear goes back where it was
		for q in pears:
			q.visible = true
		carried = 0
		pear_wait = g
		Juice.blip("thud", 1.0, -4.0)
		Game.message("Too many! Just enough is best. The pears go back.")
		return
	Juice.blip("chime", 1.0 + carried * 0.1, -6.0)
	Game.message("Pears: %d of 5." % carried)


# --- Charity -----------------------------------------------------------------
func _build_charity() -> void:
	# The giving bowl at the landing's end, a light barrier until you've given, six sad cherubs on the hub and a
	# feather on each of six side isles
	var bowl := Node3D.new()
	bowl.name = "Giving Bowl"
	bowl.position = Vector3(0, 0, 8)
	add_child(bowl)
	_cyl(bowl, "Stand", 0.3, 0.45, 0.9, Vector3(0, 0.45, 0), _mat("Trial Marble", MARBLE, 0.35))
	_cyl(bowl, "Bowl", 0.7, 0.35, 0.3, Vector3(0, 1.05, 0), _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8), false)
	var spot := USE_SPOT.make(Vector3(0, 0, -1.2), func() -> String: return "" if given else "give all your sparkles",
		give_all, 2.2, 2.6)
	spot.name = "Bowl Spot"
	bowl.add_child(spot)
	var bm := _mat("Charity Light", Color(1.0, 0.5, 0.5, 0.35), 0.2, 1.6)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var veil := _box(self, "Giving Veil", Vector3(6, 4, 0.1), Vector3(0, 2, 10.2), bm, false)
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bs := BoxShape3D.new()
	bs.size = Vector3(14, 10, 0.5)
	barrier = _solid(self, "Giving Barrier", bs, Vector3(0, 5, 10.2))
	barrier.set_meta("veil", veil)
	_isle("Giving Bridge", Vector3(0, 0, 12), Vector3(3, 0, 4))
	_isle("Cherub Hub", Vector3(0, 0, 20), Vector3(12, 0, 12))
	for k in 6:
		var side := -1.0 if k < 3 else 1.0
		var z := 15.0 + (k % 3) * 5.0
		_isle("Feather Bridge %d" % (k + 1), Vector3(side * 8.5, 0, z), Vector3(5.5, 0, 1.6))
		_isle("Feather Isle %d" % (k + 1), Vector3(side * 13.0, 0, z), Vector3(3.6, 0, 3.6))
		var f := Node3D.new()
		f.name = "Feather %d" % (k + 1)
		f.position = Vector3(side * 13.0, 1.0, z)
		add_child(f)
		var fm := _box(f, "Quill", Vector3(0.06, 0.7, 0.22), Vector3.ZERO, _mat("Feather", Color(1, 1, 1), 0.4, 0.8), false)
		fm.rotation.z = 0.3
		feathers.append(f)
		var c := _cherub()
		var a := k * TAU / 6.0
		c.position = Vector3(cos(a) * 3.2, 0, 20 + sin(a) * 3.2)
		c.rotation.y = -a
		cherubs.append(c)
	gift_bridge = Node3D.new()
	gift_bridge.name = "Gift Bridge"
	add_child(gift_bridge)
	altar_at = Vector3(0, 0, 37)
	_isle("Altar Isle", Vector3(0, 0, 37), Vector3(9, 0, 9))
	var gb := _box(gift_bridge, "Gift Path", Vector3(2.4, 0.4, 8.0), Vector3(0, -0.2, 28.5), _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8))
	gb.visible = false
	var gbody := get_node("Gift Bridge/Gift Path Body") as StaticBody3D
	(gbody.get_child(0) as CollisionShape3D).disabled = true


func _cherub() -> Node3D:
	# A little round cherub with wings, drooping (sad) until it's given a feather
	var g := Node3D.new()
	g.name = "Cherub"
	add_child(g)
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 0.8
	body.rotation.x = 0.5
	g.add_child(body)
	var skin := _mat("Cherub Skin", Color(1.0, 0.85, 0.75), 0.6)
	_ball(body, "Tummy", 0.3, Vector3.ZERO, _mat("Cherub Robe", Color(1, 0.97, 0.92), 0.7), false)
	_ball(body, "Head", 0.22, Vector3(0, 0.42, 0), skin, false)
	_ball(body, "Curls", 0.2, Vector3(0, 0.55, -0.03), _mat("Cherub Hair", Color(1.0, 0.82, 0.45), 0.7), false)
	for side in [-1.0, 1.0]:
		var w := _ball(body, "Wing", 0.25, Vector3(side * 0.33, 0.15, -0.15), _mat("Feather", Color(1, 1, 1), 0.4, 0.8), false)
		w.scale = Vector3(0.3, 0.9, 1.2)
		w.rotation.z = side * 0.6
	var halo := TorusMesh.new()
	halo.inner_radius = 0.14
	halo.outer_radius = 0.17
	var h := _mesh(body, halo, Vector3(0, 0.75, 0), _mat("Halo", GOLD, 0.3, 2.0), false)
	h.name = "Halo"
	h.visible = false
	g.set_meta("happy", false)
	return g


func give_all() -> void:
	if given:
		return
	given = true
	var n := Game.sparkles
	Game.spend_sparkles(n)
	var s := state()
	s.held = int(s.get("held", 0)) + n
	Bosses.set_meta("virtue_trial", s)
	var veil := barrier.get_meta("veil") as Node3D
	barrier.queue_free()
	barrier = null
	veil.create_tween().tween_property(veil, "scale", Vector3(1, 0.01, 1), 0.8)
	Juice.blip("chime", 0.8, -3.0)
	Fx.burst(self, Vector3(0, 1.4, 8), GOLD, 24, 0.07, 3.0, 1.0, 1.0)
	Game.message("You gave all %d sparkles. The way opens." % n if n > 0 else "You gave all you had. The way opens.")


func _step_charity(_delta: float) -> void:
	if not given:
		return
	var p := _player.global_position
	for f in feathers:
		if f.visible and p.distance_to(f.global_position) < 1.3:
			f.visible = false
			feathers_held += 1
			Juice.blip("chime", 1.4, -6.0)
			Game.message("A feather! Give it to a sad cherub.")
	for c in cherubs:
		if feathers_held > 0 and not bool(c.get_meta("happy")) and Vector2(p.x - c.position.x, p.z - c.position.z).length() < 1.4:
			cheer(c)
	for c in cherubs:
		if bool(c.get_meta("happy")):
			(c.get_node("Body") as Node3D).position.y = 1.1 + sin(_t * 3.0 + c.position.x) * 0.15


func cheer(c: Node3D) -> void:
	feathers_held -= 1
	happy += 1
	c.set_meta("happy", true)
	var body := c.get_node("Body") as Node3D
	body.rotation.x = 0.0
	(body.get_node("Halo") as Node3D).visible = true
	Juice.blip("sparkle", 1.2, -4.0)
	Fx.burst(self, c.global_position + Vector3(0, 1.2, 0), GOLD, 14, 0.06, 2.0, 0.5, 0.7)
	if happy >= cherubs.size():
		var gb := gift_bridge.get_node("Gift Path") as MeshInstance3D
		gb.visible = true
		((gift_bridge.get_node("Gift Path Body") as StaticBody3D).get_child(0) as CollisionShape3D).disabled = false
		Game.message("Every cherub is happy! A golden bridge appears.")
	else:
		Game.message("The cherub smiles! %d of %d." % [happy, cherubs.size()])


# --- Diligence ---------------------------------------------------------------
const PILLAR := Vector3(0, 0, 24)
const STEP_N := 30
const STEP_R := 7.0
const STEP_A := 0.42
const STEP_RISE := 0.7


static func step_at(k: int) -> Vector3:
	var a := k * STEP_A
	return PILLAR + Vector3(sin(a) * STEP_R, 0.5 + k * STEP_RISE, -cos(a) * STEP_R)


func _build_diligence() -> void:
	# A wide marble floor round a pillar of light, and thirty steps winding up it; lamps on steps 10 and 20
	_isle("Climb Floor", Vector3(0, 0, 21), Vector3(24, 0, 24))
	var pm := _mat("Light Pillar", Color(0.75, 1.0, 0.75, 0.55), 0.2, 1.8)
	_cyl(self, "Pillar of Light", 2.0, 2.0, 26.0, PILLAR + Vector3(0, 13, 0), pm)
	for k in STEP_N:
		var at := step_at(k)
		var mi := _isle("Step %d" % (k + 1), at, Vector3(2.6, 0, 2.6))
		steps.append(mi)
		if k == 10 or k == 20:
			_cyl(self, "Step Lamp", 0.08, 0.1, 1.4, at + Vector3(0, 0.7, 0), _mat("Trial Gold", GOLD, 0.3, 0.4, 0.8), false)
			_ball(self, "Step Lamp Light", 0.18, at + Vector3(0, 1.5, 0), _mat("Lamp Lit", Color(0.7, 1.0, 0.7), 0.3, 2.5), false)
	# The top is a landing out past the last step (not over the pillar, where it would roof the steps below it)
	var top := step_at(STEP_N - 1)
	var out := Vector3(top.x - PILLAR.x, 0, top.z - PILLAR.z).normalized()
	altar_at = top + out * 3.0 - Vector3(0, 0.0, 0)
	_isle("Top", altar_at, Vector3(5, 0, 5))


func _step_diligence(_delta: float) -> void:
	var p := _player.global_position
	for k in [10, 20]:
		if k > lamp_at and p.distance_to(step_at(k) + Vector3(0, 0.8, 0)) < 2.2:
			lamp_at = k
			check = step_at(k) + Vector3(0, 1.0, 0)
			Juice.blip("chime", 1.3, -5.0)
			Game.message("A lamp! You'll start again here.")
	# Slipped off and down to the floor from above a lamp: float back up to it
	if lamp_at > 0 and p.y < step_at(lamp_at).y - 4.0:
		_send_back(check, "Keep going! Back to the lamp.")


# --- Purity ------------------------------------------------------------------
func _build_purity() -> void:
	# A mirror walkway with drifting dark mists; gold lilies along it are where you start again
	var mirror := _mat("Mirror", Color(0.85, 0.9, 1.0), 0.02, 0.0, 1.0)
	_isle("Mirror Walk", Vector3(0, 0, 30), Vector3(8, 0, 40), mirror)
	altar_at = Vector3(0, 0, 54)
	_isle("Altar Isle", Vector3(0, 0, 54), Vector3(10, 0, 9))
	for z in lilies:
		_mesh(self, _disc(0.9), Vector3(-3.0, 0.03, z + 1.0), _mat("Gold Lily", GOLD, 0.3, 1.0, 0.6), false).name = "Lily"
	var dark := _mat("Dark Mist", Color(0.25, 0.15, 0.35, 0.75), 0.9, 0.3)
	var zs := [14.0, 18.5, 27.0, 31.5, 40.0, 44.0, 48.0]
	for i in zs.size():
		var g := Node3D.new()
		g.name = "Mist %d" % (i + 1)
		g.position = Vector3(0, 1.0, zs[i])
		add_child(g)
		for b in 4:
			_ball(g, "Puff", 0.6 + b * 0.12, Vector3(sin(b * 2.0) * 0.5, sin(b * 1.3) * 0.3, cos(b * 2.0) * 0.4), dark, false)
		g.set_meta("speed", 1.1 + (i % 3) * 0.45)
		g.set_meta("phase", i * 1.7)
		mists.append(g)


func mist_x(i: int, t: float) -> float:
	var g := mists[i]
	return sin(t * float(g.get_meta("speed")) + float(g.get_meta("phase"))) * 3.2


func _step_purity(_delta: float) -> void:
	var p := _player.global_position
	for k in lilies.size():
		if k > lily_at and p.z > lilies[k] and absf(p.x) < 4.0:
			lily_at = k
			check = Vector3(0, 1.0, lilies[k] + 1.0)
			_say_once("lily_%d" % k, "A golden lily. Safe here.")
	for i in mists.size():
		var g := mists[i]
		g.position.x = mist_x(i, _t)
		if Vector2(p.x - g.position.x, p.z - g.position.z).length() < 1.5 and p.y < 2.8:
			_send_back(check if lily_at > 0 else Vector3(0, 1.0, 8.0), "The dark mist touches you. Back to the lily.")
			return


# -----------------------------------------------------------------------------
# Every frame
# -----------------------------------------------------------------------------
func _lair_step(delta: float) -> void:
	var em := get_node_or_null("Altar/Emblem") as Node3D
	if em:
		em.rotation.y += delta * 1.2
	if done:
		return
	var p := _player.global_position
	if p.y < FALL_Y:
		_send_back(check, "You float back up.")
		return
	match id:
		"humility": _step_humility(delta)
		"patience": _step_patience(delta)
		"kindness": _step_kindness(delta)
		"temperance": _step_temperance(delta)
		"charity": _step_charity(delta)
		"diligence": _step_diligence(delta)
		"purity": _step_purity(delta)
	if Vector2(p.x - altar_at.x, p.z - altar_at.z).length() < 2.0 and absf(p.y - altar_at.y - 0.8) < 1.5:
		if altar_ready():
			complete()
		else:
			_say_once("altar", _altar_hint())


func altar_ready() -> bool:
	match id:
		"kindness": return lamb_home()
		"temperance": return carried == 5
		"charity": return given and happy >= cherubs.size()
	return true


func _altar_hint() -> String:
	match id:
		"kindness": return "Bring the lamb home to its mother first."
		"temperance": return "The scales want five pears. You have %d." % carried
	return ""


func _say_once(key: String, text: String) -> void:
	if text == "" or _said.has(key):
		return
	_said[key] = true
	Game.message(text)


func _send_back(to: Vector3, text: String) -> void:
	var cb := _player as CharacterBody3D
	cb.global_position = to
	cb.velocity = Vector3.ZERO
	Fx.burst(self, to, Color(1.0, 0.85, 0.5), 12, 0.06, 2.0, 1.0, 0.5)
	Juice.blip("whoosh", 1.0, -6.0)
	if text != "":
		Game.message(text)


# -----------------------------------------------------------------------------
# The end: the altar
# -----------------------------------------------------------------------------
func complete() -> void:
	if done:
		return
	done = true
	var first := not is_done(id)
	Dialogue.set_flag("virtue_" + id)
	Juice.blip("chime", 1.0, -2.0)
	Juice.shake(0.2)
	Fx.burst(self, altar_at + Vector3(0, 2.1, 0), virtue.colour, 40, 0.1, 5.0, 2.0, 1.5)
	var s := state()
	var gave := int(s.get("held", 0))
	s.held = 0
	Bosses.set_meta("virtue_trial", s)
	if id == "charity" and gave > 0:
		Game.add_sparkles(gave * 2)
		Game.message("Your gift comes back twice over! ✦ %d sparkles." % (gave * 2))
	if first:
		Game.add_sparkles(REWARD)
		Remnants.add(1)
		Game.message("Trial of %s done! ✦ %d sparkles and a Remnant." % [str(virtue.name), REWARD])
	if all_done() and not Dialogue.flags.has("virtue_all"):
		Dialogue.set_flag("virtue_all")
		Game.add_sparkles(ALL_REWARD)
		Remnants.add(3)
		if not Game.has_item("shop:virtue_laurel"):
			Game.items.append("shop:virtue_laurel")
		Game.message("All seven virtues! The Laurel of Virtues is yours.")
	get_tree().create_timer(2.5).timeout.connect(_back_to_trail.bind(true))


func go_home() -> void:
	_back_to_trail(false)


func _back_to_trail(finished: bool) -> void:
	if not is_inside_tree():
		return
	var s := state()
	var gave := int(s.get("held", 0))
	if gave > 0:
		Game.add_sparkles(gave)                  # (left before the end: what you gave comes back, no more, no less)
	Bosses.remove_meta("virtue_trial")
	var stone := int(s.get("stone", 0))
	Bosses.set_meta("virtue_back", stone)
	if finished:
		Bosses.set_meta("virtue_opened", id)
	var at: Vector3 = s.get("pos", Vector3(0, 1, 3))
	Game.pending_message = "" if finished else "Come back when you're ready."
	Game.go_to_point(SKYREACH, at, float(s.get("yaw", 0.0)), "the Skyreach Trail")
