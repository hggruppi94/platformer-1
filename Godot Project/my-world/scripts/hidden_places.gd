extends Node

# Autoload "Hidden": hidden places to find off the beaten path (Hayden, 15 Nov 2026: "Lets get started on the making
# the game feel bigger like elden ring plan", slice one of the plan "Making the game feel bigger").
#
# Six in Stars Hollow and six in the Void, out in the far corners and edges where nothing else goes. Each one has
# something you can see from a long way off (a beam of starlight, a kite high in the sky, smoke from a chimney, a
# balloon stuck in a tree) so a child spots it, wonders what it is, and walks over. Walking into the middle of it finds
# it (no button: like the Peepers): a "Hidden place found!" card, sparkles (and a Remnant in the Void), and for a
# couple of them a hat. Finding all six in a world gives that world's explorer hat.
#
# Nothing points at them before they're found: no map marker, no quest, no hint. Once found, a place shows on the big
# map and the minimap ("Hidden places" in its legend), and the Bag lists them (found ones by name, the rest as ???).
# Found is a Dialogue flag, "hidden_<id>", so it's saved with everything else.
#
# Put into the town and Stars Hollow at play time (like scripts/wilds.gd), so no built scene changed. Nothing here is
# solid: it's all for looking at, so it can't trap anyone or block a path. tools/test_hidden_places.gd checks every
# spot is on open ground inside the world, clear of buildings, trees and everything else.

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const FIND_RADIUS := 4.0               # walk this close to a place's middle and it's found
const SPARKLES := 6                    # for each place
const VOID_REMNANTS := 1               # ...and in the Void, a Remnant too
const SET_SPARKLES := 20               # finding all six in a world

# id, world, name, where (x, z), and what it gives besides sparkles ("hat": a shop item id). Every name, look and
# reward is a first draft for Hayden.
const PLACES := [
	{"id": "star_well", "world": "void", "name": "The Star Well", "at": Vector2(-124, -238)},
	{"id": "upside_tree", "world": "void", "name": "The Upside-Down Tree", "at": Vector2(126, -236)},
	{"id": "sky_swing", "world": "void", "name": "The Sky Swing", "at": Vector2(10, -240)},
	{"id": "bubble_spring", "world": "void", "name": "Bubble Spring", "at": Vector2(-132, -75)},
	{"id": "humming_shell", "world": "void", "name": "The Humming Shell", "at": Vector2(-130, 90), "hat": "shell_crown"},
	{"id": "kite_hill", "world": "void", "name": "Kite Hill", "at": Vector2(130, 92)},
	{"id": "fairy_ring", "world": "earth", "name": "The Fairy Ring", "at": Vector2(-135, -135), "hat": "acorn_cap"},
	{"id": "sleeping_giant", "world": "earth", "name": "The Sleeping Giant", "at": Vector2(-68, -131)},
	{"id": "old_lookout", "world": "earth", "name": "The Old Lookout", "at": Vector2(-135, -65)},
	{"id": "smoky_cottage", "world": "earth", "name": "The Smoky Chimney", "at": Vector2(54, -31)},
	{"id": "stuck_balloon", "world": "earth", "name": "The Stuck Balloon", "at": Vector2(53, 74)},
	{"id": "bottle_tree", "world": "earth", "name": "The Bottle Tree", "at": Vector2(-90, 88)},
]
# Where you walk in to find it, from its middle, for the ones you'd otherwise have to stand inside (the giant's head,
# the cottage, the well)
const FIND_AT := {"star_well": Vector3(0, 0, 2.8), "upside_tree": Vector3(0, 0, 6.5), "humming_shell": Vector3(0, 0, 4.5),
	"sleeping_giant": Vector3(0, 0, 10.5), "smoky_cottage": Vector3(0, 0, 3.6), "bottle_tree": Vector3(0, 0, 2.6),
	"fairy_ring": Vector3(0, 0, 2.0)}
# All six in a world
const SET_HATS := {"void": "starfinder_hat", "earth": "wanderer_hat"}

var enabled := true                    # tests can switch it off
var _last: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s != _last:
		_last = s
		if s and enabled:
			_place_all.call_deferred(s)


static func world_of(scene: Node) -> String:
	if scene == null:
		return ""
	match scene.scene_file_path:
		TOWN:
			return "void"
		EARTH:
			return "earth"
	return ""


static func places_in(world: String) -> Array:
	return PLACES.filter(func(p: Dictionary) -> bool: return p.world == world)


static func flag(id: String) -> String:
	return "hidden_" + id


func is_found(id: String) -> bool:
	return bool(Dialogue.flags.get(flag(id), false))


func found_in(world: String) -> Array:
	# [{id, name, pos: Vector3}] of the ones found in this world (for the map)
	var out := []
	for p in places_in(world):
		if is_found(p.id):
			out.append({"id": p.id, "name": p.name, "pos": Vector3(p.at.x, 0, p.at.y)})
	return out


func found_count(world := "") -> int:
	var n := 0
	for p in PLACES:
		if (world == "" or p.world == world) and is_found(p.id):
			n += 1
	return n


func _place_all(scene: Node) -> void:
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	var world := world_of(scene)
	if world == "" or scene.get_node_or_null("Hidden Places") != null:
		return
	var holder := Node3D.new()
	holder.name = "Hidden Places"
	scene.add_child(holder)
	for p in places_in(world):
		var ground := Bosses.ground(scene as Node3D, p.at.x, p.at.y)
		var root := Node3D.new()
		root.name = str(p.name)
		root.set_meta("place_id", p.id)
		root.add_to_group("hidden_places")
		holder.add_child(root)
		root.global_position = ground
		var look := Node3D.new()
		look.name = "Look"
		root.add_child(look)
		var builder := Callable(self, "_look_" + str(p.id))
		builder.call(look)
		_finder(root, str(p.id))


func _finder(root: Node3D, id: String) -> void:
	var a := Area3D.new()
	a.name = "Find"
	a.monitorable = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = FIND_RADIUS
	cyl.height = 4.0
	shape.shape = cyl
	shape.position.y = 1.5
	a.add_child(shape)
	a.position = FIND_AT.get(id, Vector3.ZERO)
	root.add_child(a)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			find(id))


func find(id: String) -> bool:
	# Finds a place: its reward the first time. Returns whether it was new (tests call it).
	if is_found(id):
		return false
	var p: Dictionary = {}
	for q in PLACES:
		if q.id == id:
			p = q
	if p.is_empty():
		return false
	Dialogue.flags[flag(id)] = true
	var gifts := ["+%d sparkles" % SPARKLES]
	Game.add_sparkles(SPARKLES, "a hidden place")
	if p.world == "void":
		Remnants.add(VOID_REMNANTS, "a hidden place")
		gifts.append("+%d Remnant" % VOID_REMNANTS)
	if p.has("hat") and _give(str(p.hat)):
		gifts.append("the " + _hat_name(str(p.hat)))
	if found_count(p.world) == places_in(p.world).size():
		Game.add_sparkles(SET_SPARKLES, "every hidden place")
		if _give(str(SET_HATS[p.world])):
			gifts.append("the " + _hat_name(str(SET_HATS[p.world])))
	var line := "Hidden place found! %s\n%s" % [p.name, ", ".join(gifts)]
	if found_count(p.world) == places_in(p.world).size():
		line += "\nYou found them all here!"
	else:
		line += "\n%d of %d here" % [found_count(p.world), places_in(p.world).size()]
	Game.message(line)
	var scene := get_tree().current_scene
	var root := _root_of(id)
	if root:
		Audio.play_at("pickup", root.global_position)
		Fx.burst(root, Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.4), 24, 0.1, 3.0, -2.0, 1.2)
	if scene and Juice.has_method("rumble"):
		Juice.rumble(0.3, 0.2)
	Game.save_game()
	return true


func _root_of(id: String) -> Node3D:
	for n in get_tree().get_nodes_in_group("hidden_places"):
		if str(n.get_meta("place_id", "")) == id:
			return n as Node3D
	return null


func _give(hat: String) -> bool:
	if Game.has_item("shop:" + hat):
		return false
	Game.items.append("shop:" + hat)                   # worn from the wardrobe, like the race prizes
	return true


func _hat_name(hat: String) -> String:
	return str(Shop.items.get(hat, {}).get("name", hat.capitalize()))


# -----------------------------------------------------------------------------
# Shapes (nothing solid, no shadows from the glowing bits)
# -----------------------------------------------------------------------------
static func _mat(c: Color, glow := 0.0, see := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	if see or c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _put(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE,
		name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if name != "":
		mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	if mat is StandardMaterial3D and ((mat as StandardMaterial3D).emission_enabled or (mat as StandardMaterial3D).transparency):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, segs := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	return m


static func _ball(r: float, segs := 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t


static func _stick(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material, tip := -1.0) -> MeshInstance3D:
	# A rod from one point to another (a root, a string)
	var d := to - from
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var mi := _put(parent, _cyl(radius if tip < 0.0 else tip, radius, d.length(), 6), mat, Vector3.ZERO)
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (from + to) / 2.0)
	return mi


static func _beam(parent: Node3D, colour: Color, height: float, radius: float) -> MeshInstance3D:
	# A soft column of light going up into the sky: the thing you see from far away
	var m := _mat(Color(colour.r, colour.g, colour.b, 0.28), 2.5, true)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var b := _put(parent, _cyl(radius * 0.6, radius, height, 16), m, Vector3(0, height / 2.0, 0), Vector3.ZERO, Vector3.ONE, "Beam")
	return b


static func _motes(parent: Node3D, colour: Color, amount: int, box: Vector3, up: float, life: float, size := 0.08,
		y := 0.0, name := "Motes") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = up * 0.7
	p.initial_velocity_max = up
	p.gravity = Vector3.ZERO
	var sm := _ball(size, 6)
	var m := _mat(colour, 3.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	p.position.y = y
	parent.add_child(p)
	return p


static func _light(parent: Node3D, colour: Color, y: float, energy := 1.5, reach := 9.0) -> void:
	var l := OmniLight3D.new()
	l.name = "Glow"
	l.light_color = colour
	l.light_energy = energy
	l.omni_range = reach
	l.position.y = y
	parent.add_child(l)


static func _spin(node: Node3D, axis: Vector3, speed: float) -> void:
	# A gentle endless turn (a tween, so nothing needs a script of its own)
	var tw := node.create_tween().set_loops()
	var start := node.rotation
	tw.tween_method(func(t: float) -> void: node.rotation = start + axis * t, 0.0, TAU, TAU / speed)


static func _sway(node: Node3D, prop: String, amount: float, period: float) -> void:
	var base: float = node.get_indexed(prop)
	var tw := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, prop, base + amount, period / 2.0)
	tw.tween_property(node, prop, base - amount, period)
	tw.tween_property(node, prop, base, period / 2.0)


# -----------------------------------------------------------------------------
# The Void's six
# -----------------------------------------------------------------------------
func _look_star_well(g: Node3D) -> void:
	# An old round stone well with a beam of starlight shooting up out of it
	var stone := _mat(Color(0.55, 0.5, 0.7))
	for k in 14:
		var a := k * TAU / 14.0
		_put(g, _box(Vector3(0.7, 0.9, 0.45)), stone, Vector3(sin(a) * 1.3, 0.45, cos(a) * 1.3), Vector3(0, a, 0))
	_put(g, _cyl(1.05, 1.05, 0.05, 24), _mat(Color(0.5, 0.75, 1.0), 2.5), Vector3(0, 0.75, 0), Vector3.ZERO, Vector3.ONE, "Starwater")
	var wood := _mat(Color(0.45, 0.3, 0.45))
	for s in [-1.0, 1.0]:
		_put(g, _box(Vector3(0.15, 2.4, 0.15)), wood, Vector3(s * 1.3, 1.6, 0))
	_put(g, _cyl(0.1, 0.1, 2.9, 8), wood, Vector3(0, 2.75, 0), Vector3(0, 0, PI / 2.0))
	var roof := _put(g, _cyl(0.0, 1.9, 1.0, 4), _mat(Color(0.35, 0.25, 0.55)), Vector3(0, 3.4, 0), Vector3(0, PI / 4.0, 0))
	roof.name = "Roof"
	_beam(g, Color(0.6, 0.85, 1.0), 70.0, 0.9).position.y += 0.8
	_motes(g, Color(0.85, 0.95, 1.0), 40, Vector3(0.6, 0.1, 0.6), 6.0, 6.0, 0.1, 0.8, "Starlight")
	_light(g, Color(0.6, 0.85, 1.0), 1.5, 2.0, 10.0)


func _look_upside_tree(g: Node3D) -> void:
	# A tree growing the wrong way up: its leafy crown squashed on the ground, its trunk going up, and its glowing roots
	# spread out against the sky
	var leaf := _mat(Color(0.35, 0.85, 0.6))
	for k in 7:
		var a := k * TAU / 7.0
		_put(g, _ball(2.2), leaf, Vector3(sin(a) * 2.4, 1.0, cos(a) * 2.4), Vector3.ZERO, Vector3(1, 0.55, 1))
	_put(g, _ball(2.6), leaf, Vector3(0, 1.6, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	var bark := _mat(Color(0.5, 0.35, 0.55))
	_put(g, _cyl(0.6, 1.0, 17.0, 10), bark, Vector3(0, 10.5, 0), Vector3.ZERO, Vector3.ONE, "Trunk")
	var roots := Node3D.new()
	roots.name = "Roots"
	roots.position.y = 19.0
	g.add_child(roots)
	var glow := _mat(Color(1.0, 0.55, 0.9), 2.2)
	for k in 9:
		var a := k * TAU / 9.0 + 0.2
		var len := 6.0 + float(k % 3) * 1.8
		var dir := Vector3(sin(a) * 0.84, 0.54 - 0.1 * (k % 2), cos(a) * 0.84)
		_stick(roots, Vector3.ZERO, dir * len, 0.4, glow, 0.05)
	_spin(roots, Vector3.UP, 0.15)
	_motes(roots, Color(1.0, 0.7, 0.95), 26, Vector3(4, 1, 4), 1.2, 5.0, 0.09, 1.0, "Root Glow")
	_light(g, Color(1.0, 0.55, 0.9), 19.0, 2.5, 18.0)


func _look_sky_swing(g: Node3D) -> void:
	# A little cloud floating high up, with a swing hanging all the way down from it
	var cloud := Node3D.new()
	cloud.name = "Cloud"
	cloud.position.y = 27.0
	cloud.scale = Vector3.ONE * 1.6
	g.add_child(cloud)
	var puff := _mat(Color(1.0, 0.95, 1.0), 0.35)
	for k in 6:
		var a := k * TAU / 6.0
		_put(cloud, _ball(1.6 + float(k % 2) * 0.6), puff, Vector3(sin(a) * 2.2, float(k % 3) * 0.4, cos(a) * 1.4))
	_put(cloud, _ball(2.4), puff, Vector3(0, 0.6, 0))
	var swing := Node3D.new()
	swing.name = "Swing"
	swing.position.y = 26.0
	g.add_child(swing)
	var rope := _mat(Color(0.95, 0.85, 0.6))
	for s in [-0.55, 0.55]:
		_put(swing, _cyl(0.04, 0.04, 25.3, 6), rope, Vector3(s, -12.65, 0))
	_put(swing, _box(Vector3(1.4, 0.12, 0.5)), _mat(Color(1.0, 0.5, 0.75)), Vector3(0, -25.3, 0), Vector3.ZERO, Vector3.ONE, "Seat")
	_sway(swing, "rotation:x", 0.06, 4.0)
	_sway(cloud, "position:y", 0.5, 6.0)
	_motes(g, Color(1.0, 0.85, 1.0), 14, Vector3(2.5, 0.5, 1.5), 0.3, 6.0, 0.1, 26.0, "Cloud Sparkles")


func _look_bubble_spring(g: Node3D) -> void:
	# A little spring that never stops blowing giant shiny bubbles up into the sky
	_put(g, _cyl(2.2, 2.4, 0.3, 24), _mat(Color(0.5, 0.45, 0.65)), Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, "Rim")
	_put(g, _cyl(1.9, 1.9, 0.05, 24), _mat(Color(0.45, 0.95, 1.0), 1.2), Vector3(0, 0.32, 0), Vector3.ZERO, Vector3.ONE, "Spring")
	var p := CPUParticles3D.new()
	p.name = "Bubbles"
	p.amount = 26
	p.lifetime = 16.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	var sm := _ball(1.0, 16)
	var m := _mat(Color(0.75, 0.95, 1.0, 0.28), 0.8, true)
	m.metallic_specular = 1.0
	m.roughness = 0.05
	m.rim_enabled = true
	m.rim = 1.0
	sm.material = m
	p.mesh = sm
	p.position.y = 0.6
	g.add_child(p)
	_light(g, Color(0.5, 0.95, 1.0), 1.2, 1.2, 8.0)


func _look_humming_shell(g: Node3D) -> void:
	# A giant pink spiral seashell lying in the grass, glowing softly, with little music notes floating up out of it
	var shell := Node3D.new()
	shell.name = "Shell"
	shell.rotation = Vector3(0, 0.6, -0.35)
	g.add_child(shell)
	var pink := _mat(Color(1.0, 0.65, 0.8), 0.25)
	for k in 7:
		var r := 2.6 * pow(0.78, k)
		_put(shell, _torus(r * 0.35, r), pink, Vector3(0, 1.2 + k * 0.45, -k * 0.2), Vector3(0.2, 0, 0))
	_put(shell, _ball(1.6), _mat(Color(1.0, 0.85, 0.9), 0.4), Vector3(0, 1.0, 0.9), Vector3.ZERO, Vector3(1.2, 0.8, 0.9), "Mouth")
	_motes(g, Color(1.0, 0.7, 0.95), 40, Vector3(1.0, 0.3, 1.0), 2.4, 11.0, 0.22, 2.0, "Notes")
	_light(g, Color(1.0, 0.6, 0.85), 2.0, 1.6, 10.0)
	_sway(shell, "rotation:x", 0.03, 3.0)


func _look_kite_hill(g: Node3D) -> void:
	# A picnic blanket and a basket, a stake in the ground, and a big kite flying very high on its long string
	_put(g, _box(Vector3(3.0, 0.03, 2.4)), _mat(Color(1.0, 0.45, 0.6)), Vector3(0.5, 0.02, 0.8), Vector3.ZERO, Vector3.ONE, "Blanket")
	_put(g, _box(Vector3(0.7, 0.45, 0.5)), _mat(Color(0.75, 0.55, 0.35)), Vector3(1.2, 0.25, 1.1), Vector3.ZERO, Vector3.ONE, "Basket")
	_put(g, _cyl(0.06, 0.06, 0.8, 6), _mat(Color(0.5, 0.35, 0.3)), Vector3(-1.2, 0.4, -0.5), Vector3.ZERO, Vector3.ONE, "Stake")
	var kite := Node3D.new()
	kite.name = "Kite"
	kite.position = Vector3(-10, 30, -14)
	kite.scale = Vector3.ONE * 1.7
	g.add_child(kite)
	var to_town := Vector3(0, 0, -75) - g.global_position          # its face turned towards the town, to be seen
	kite.rotation.y = atan2(to_town.x, to_town.z)
	var cols := [Color(1.0, 0.85, 0.25), Color(0.4, 0.9, 1.0), Color(1.0, 0.4, 0.7), Color(0.6, 1.0, 0.45)]
	_put(kite, _box(Vector3(2.6, 2.6, 0.06)), _mat(cols[2], 0.6), Vector3.ZERO, Vector3(0, 0, PI / 4.0), Vector3(1, 1.35, 1), "Sail")
	_put(kite, _box(Vector3(1.3, 1.3, 0.08)), _mat(cols[0], 0.8), Vector3(0, 0, 0.02), Vector3(0, 0, PI / 4.0), Vector3(1, 1.35, 1))
	for k in 6:
		_put(kite, _box(Vector3(0.5, 0.25, 0.05)), _mat(cols[(k + 1) % 4], 0.6), Vector3(0.15 * (1 - 2 * (k % 2)), -2.8 - k * 0.8, 0),
			Vector3(0, 0, 0.4 * (1 - 2 * (k % 2))))
	# The string, from the stake to the kite
	var str_line := _stick(g, Vector3(-1.2, 0.8, -0.5), kite.position + Vector3(0, -2.4 * 1.7, 0), 0.03, _mat(Color(1, 1, 1), 1.0))
	str_line.name = "String"
	_sway(kite, "rotation:z", 0.25, 3.0)
	_sway(kite, "position:y", 0.8, 5.0)


# -----------------------------------------------------------------------------
# Stars Hollow's six
# -----------------------------------------------------------------------------
func _look_fairy_ring(g: Node3D) -> void:
	# A ring of toadstools in the woods with a column of fireflies swirling up out of the middle
	var red := _mat(Color(0.9, 0.2, 0.2))
	var dots := _mat(Color(1, 1, 0.95))
	var stem := _mat(Color(0.95, 0.9, 0.8))
	for k in 11:
		var a := k * TAU / 11.0
		var s := 0.7 + float(k % 3) * 0.25
		var at := Vector3(sin(a) * 3.0, 0, cos(a) * 3.0)
		_put(g, _cyl(0.1 * s, 0.14 * s, 0.6 * s, 8), stem, at + Vector3(0, 0.3 * s, 0))
		_put(g, _ball(0.35 * s, 10), red, at + Vector3(0, 0.62 * s, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
		_put(g, _ball(0.06 * s, 6), dots, at + Vector3(0.12 * s, 0.78 * s, 0.1 * s))
	# A tall toadstool in the middle, for the ring to be round
	_put(g, _cyl(0.35, 0.5, 3.2, 10), stem, Vector3(0, 1.6, 0))
	_put(g, _ball(1.8, 16), red, Vector3(0, 3.3, 0), Vector3.ZERO, Vector3(1, 0.5, 1), "Big Cap")
	for k in 8:
		var a := k * TAU / 8.0
		_put(g, _ball(0.18, 6), dots, Vector3(sin(a) * 1.1, 3.95, cos(a) * 1.1))
	var flies := _motes(g, Color(1.0, 0.95, 0.45), 140, Vector3(2.0, 0.3, 2.0), 2.8, 11.0, 0.11, 1.0, "Fireflies")
	_beam(g, Color(1.0, 0.9, 0.5), 32.0, 1.6)
	flies.tangential_accel_min = 1.5
	flies.tangential_accel_max = 2.5
	_light(g, Color(1.0, 0.9, 0.5), 2.5, 1.4, 9.0)


func _look_sleeping_giant(g: Node3D) -> void:
	# A huge mossy stone head half sunk in the ground, eyes shut, a little tree growing on top, and big sleepy puffs of
	# breath floating up out of its nose, high over the trees
	_giant_head(g)
	g.get_child(-1).scale = Vector3.ONE * 1.5
	var puffs := CPUParticles3D.new()
	puffs.name = "Snores"
	puffs.amount = 10
	puffs.lifetime = 10.0
	puffs.direction = Vector3(0, 1, 0.25)
	puffs.spread = 8.0
	puffs.initial_velocity_min = 2.4
	puffs.initial_velocity_max = 3.0
	puffs.gravity = Vector3.ZERO
	puffs.scale_amount_min = 1.0
	puffs.scale_amount_max = 2.2
	var sm := _ball(0.7, 8)
	sm.material = _mat(Color(0.95, 0.97, 1.0, 0.7), 0.3, true)
	puffs.mesh = sm
	puffs.position = Vector3(0, 3.6, 6.4)
	g.add_child(puffs)


func _giant_head(parent: Node3D) -> void:
	var g := Node3D.new()
	g.name = "Giant"
	parent.add_child(g)
	var stone := _mat(Color(0.42, 0.44, 0.4))
	var moss := _mat(Color(0.3, 0.5, 0.22))
	_put(g, _ball(4.0, 20), stone, Vector3(0, 1.8, 0), Vector3.ZERO, Vector3(1.1, 1.05, 0.95), "Head")
	_put(g, _ball(3.4, 16), moss, Vector3(0, 4.4, -0.8), Vector3.ZERO, Vector3(1.25, 0.5, 1.1), "Moss")
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		_put(g, _ball(0.9, 8), moss, Vector3(sin(a) * 3.6, 0.6 + float(k % 2) * 1.6, cos(a) * 3.0))
	_put(g, _ball(0.9, 12), stone, Vector3(0, 2.0, 3.9), Vector3.ZERO, Vector3(0.8, 1.2, 0.8), "Nose")
	var lid := _mat(Color(0.22, 0.23, 0.21))
	for s in [-1.0, 1.0]:
		_put(g, _box(Vector3(1.3, 0.12, 0.2)), lid, Vector3(s * 1.4, 3.0, 3.6), Vector3(0, 0, s * -0.12))
		_put(g, _ball(1.1, 10), stone, Vector3(s * 4.2, 2.0, 0.3), Vector3.ZERO, Vector3(0.35, 0.9, 0.6))   # ears
	_put(g, _box(Vector3(1.6, 0.15, 0.2)), lid, Vector3(0, 0.9, 3.75), Vector3.ZERO, Vector3.ONE, "Mouth")
	_put(g, _cyl(0.12, 0.2, 2.6, 6), _mat(Color(0.45, 0.32, 0.22)), Vector3(0.6, 5.6, -0.6))
	_put(g, _ball(1.3, 12), _mat(Color(0.95, 0.6, 0.25)), Vector3(0.6, 7.2, -0.6), Vector3.ZERO, Vector3(1, 0.85, 1), "Little Tree")


func _look_old_lookout(g: Node3D) -> void:
	var tall := Node3D.new()
	tall.name = "Tower"
	tall.scale = Vector3(1.15, 1.45, 1.15)
	g.add_child(tall)
	_lookout(tall)


func _lookout(g: Node3D) -> void:
	# A tall old wooden lookout tower in the woods, a flag flapping on top and a lantern in its hut
	var wood := _mat(Color(0.5, 0.35, 0.25))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_put(g, _box(Vector3(0.25, 14.0, 0.25)), wood, Vector3(sx * 1.2, 7.0, sz * 1.2), Vector3(sz * 0.04, 0, sx * -0.04))
	for k in 4:
		_put(g, _box(Vector3(2.6, 0.12, 0.12)), wood, Vector3(0, 2.5 + k * 3.0, 1.2), Vector3(0, 0, 0.6 * (1 - 2 * (k % 2))))
	_put(g, _box(Vector3(3.2, 0.2, 3.2)), wood, Vector3(0, 14.0, 0), Vector3.ZERO, Vector3.ONE, "Floor")
	_put(g, _cyl(0.0, 2.6, 1.6, 4), _mat(Color(0.6, 0.25, 0.25)), Vector3(0, 16.6, 0), Vector3(0, PI / 4.0, 0), Vector3.ONE, "Roof")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_put(g, _box(Vector3(0.15, 1.8, 0.15)), wood, Vector3(sx * 1.4, 14.9, sz * 1.4))
	_put(g, _ball(0.25, 8), _mat(Color(1.0, 0.8, 0.4), 3.0), Vector3(0, 15.0, 0), Vector3.ZERO, Vector3.ONE, "Lantern")
	_light(g, Color(1.0, 0.8, 0.45), 15.0, 2.0, 10.0)
	_put(g, _cyl(0.04, 0.04, 3.0, 6), wood, Vector3(0, 18.6, 0))
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0, 19.6, 0)
	g.add_child(flag)
	_put(flag, _box(Vector3(2.4, 1.3, 0.03)), _mat(Color(1.0, 0.35, 0.3), 0.5), Vector3(1.2, 0, 0))
	_sway(flag, "rotation:y", 0.35, 2.0)


func _look_smoky_cottage(g: Node3D) -> void:
	# A tiny cottage on its own in the woods with its door boarded up, but smoke always curling up out of the chimney
	_put(g, _box(Vector3(3.6, 2.4, 3.0)), _mat(Color(0.85, 0.8, 0.7)), Vector3(0, 1.2, 0), Vector3.ZERO, Vector3.ONE, "Walls")
	var roof := PrismMesh.new()
	roof.size = Vector3(4.2, 1.6, 3.4)
	_put(g, roof, _mat(Color(0.45, 0.3, 0.3)), Vector3(0, 3.2, 0), Vector3.ZERO, Vector3.ONE, "Roof")
	_put(g, _box(Vector3(0.6, 1.8, 0.6)), _mat(Color(0.6, 0.35, 0.3)), Vector3(1.1, 3.6, -0.6), Vector3.ZERO, Vector3.ONE, "Chimney")
	var wood := _mat(Color(0.5, 0.35, 0.25))
	_put(g, _box(Vector3(0.9, 1.6, 0.06)), _mat(Color(0.35, 0.25, 0.2)), Vector3(0, 0.8, 1.52), Vector3.ZERO, Vector3.ONE, "Door")
	for k in 2:
		_put(g, _box(Vector3(1.2, 0.18, 0.06)), wood, Vector3(0, 0.6 + k * 0.7, 1.57), Vector3(0, 0, 0.3 * (1 - 2 * k)))
	for s in [-1.0, 1.0]:
		_put(g, _box(Vector3(0.6, 0.6, 0.06)), _mat(Color(1.0, 0.85, 0.5), 1.5), Vector3(s * 1.2, 1.4, 1.52))
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 34
	smoke.lifetime = 14.0
	smoke.direction = Vector3(0.15, 1, 0)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 1.6
	smoke.initial_velocity_max = 2.2
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.6))
	smoke.scale_amount_curve = curve
	var sm := _ball(0.6, 8)
	sm.material = _mat(Color(0.92, 0.92, 0.95, 0.55), 0.0, true)
	smoke.mesh = sm
	smoke.position = Vector3(1.1, 4.6, -0.6)
	g.add_child(smoke)


func _look_stuck_balloon(g: Node3D) -> void:
	# A striped hot-air balloon caught in the top of a tall tree, its basket dangling
	var bark := _mat(Color(0.42, 0.3, 0.22))
	_put(g, _cyl(0.4, 0.7, 14.0, 8), bark, Vector3(-1.5, 7.0, 0), Vector3.ZERO, Vector3.ONE, "Tree")
	_put(g, _ball(3.2, 12), _mat(Color(0.9, 0.5, 0.2)), Vector3(-1.5, 14.5, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	var balloon := Node3D.new()
	balloon.name = "Balloon"
	balloon.position = Vector3(0.5, 20.0, 0.5)
	balloon.scale = Vector3.ONE * 1.4
	balloon.rotation.z = -0.35
	g.add_child(balloon)
	var cols := [Color(1.0, 0.35, 0.4), Color(1.0, 0.85, 0.3)]
	for k in 8:
		var seg := _put(balloon, _ball(3.2, 16), _mat(cols[k % 2], 0.15), Vector3.ZERO, Vector3(0, k * TAU / 8.0, 0), Vector3(0.42, 1.15, 1.0))
		seg.position = Vector3(sin(k * TAU / 8.0), 0, cos(k * TAU / 8.0)) * 0.9
	var basket := Node3D.new()
	basket.name = "Basket"
	basket.position = Vector3(1.6, 10.0, 0.9)
	g.add_child(basket)
	_put(basket, _box(Vector3(1.2, 1.0, 1.2)), _mat(Color(0.7, 0.5, 0.3)), Vector3.ZERO)
	var rope := _mat(Color(0.85, 0.8, 0.65))
	for sx in [-0.5, 0.5]:
		_put(basket, _cyl(0.03, 0.03, 6.5, 4), rope, Vector3(sx, 3.5, 0))
	_sway(basket, "rotation:z", 0.1, 3.5)


func _look_bottle_tree(g: Node3D) -> void:
	# A bare old tree hung all over with coloured glass bottles that catch the light and clink in the wind
	var bark := _mat(Color(0.4, 0.3, 0.25))
	_put(g, _cyl(0.45, 0.8, 9.0, 8), bark, Vector3(0, 4.5, 0), Vector3.ZERO, Vector3.ONE, "Trunk")
	var cols := [Color(0.3, 0.6, 1.0), Color(0.4, 0.95, 0.6), Color(1.0, 0.45, 0.7), Color(1.0, 0.8, 0.3), Color(0.7, 0.5, 1.0)]
	for k in 7:
		var a := k * TAU / 7.0
		var branch := Node3D.new()
		branch.position = Vector3(0, 6.5 + float(k % 3) * 1.0, 0)
		branch.rotation = Vector3(0, a, 0)
		g.add_child(branch)
		_put(branch, _cyl(0.06, 0.16, 3.4, 6), bark, Vector3(0, 0.9, -1.3), Vector3(-0.95, 0, 0))
		for j in 2:
			var bottle := Node3D.new()
			bottle.scale = Vector3.ONE * 1.7
			bottle.position = Vector3(0, 0.6 + j * 0.9, -1.0 - j * 1.2)
			branch.add_child(bottle)
			var c: Color = cols[(k + j) % cols.size()]
			_put(bottle, _cyl(0.03, 0.03, 0.4, 4), _mat(Color(0.9, 0.9, 0.85)), Vector3(0, -0.2, 0))
			_put(bottle, _cyl(0.06, 0.15, 0.5, 8), _mat(Color(c.r, c.g, c.b, 0.75), 1.4, true), Vector3(0, -0.65, 0))
			_sway(bottle, "rotation:x", 0.15, 2.0 + j * 0.7 + k * 0.1)
	_light(g, Color(0.6, 0.8, 1.0), 6.0, 1.4, 12.0)
	_motes(g, Color(0.7, 0.9, 1.0), 50, Vector3(3.0, 1.0, 3.0), 2.6, 10.0, 0.1, 6.0, "Glints")
