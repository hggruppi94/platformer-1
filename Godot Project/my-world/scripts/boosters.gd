extends Node

# Autoload "Boosters": speed boosts all round Galaxity and Stars Hollow, not just on the race tracks (plan item 14).
# Three kinds, all working on foot and on every ride (on a ride through the same Skate.boost() the races' boost pads
# use, on foot through Player.boost()):
#
# - Boost strips: long glowing teal strips on the ground with gold chevrons sliding the way they push, along the
#   streets, the lakeside and into the skate parks. Ride or run over one for a burst of speed.
# - Booster ramps: little kickers (solid, so riders roll up them and fly) that boost you as you hit them and pop you
#   up off the lip, on foot too.
# - Booster coins: glowing gold coins in lines along good skating routes (between the rails of a grind line, down
#   Lookout Hill). Each adds a short burst, so a line of them keeps you going, and they come back after a while.
#
# Gentle on purpose: going fast never makes you crash (a bail only ever comes from a wonky landing or trick), and a
# boost wears off by easing back down.
#
# They aren't in the built scenes: like the lost watches (scripts/watches.gd), this puts them into whichever scene is
# showing, from BOOSTERS, so the builders and their big .tscn files don't change. Each one finds the ground under the
# spot it's given, so it never floats. The map and the minimap show them as small arrows (scripts/map_screen.gd,
# marks()). tools/test_boosters.gd checks every one is on the ground, has room round it, and that a boost raises
# your speed and wears off.

signal boosted(kind: String)

const SCENES := {"town": "res://scenes/town/town.tscn", "earth": "res://scenes/earth/earth.tscn"}

const STRIP_SIZE := Vector3(2.4, 0.06, 6.0)
const STRIP_SPEED := 6.0             # metres a second over pushing (or running) speed, like the race pads (6.5)
const STRIP_TIME := 1.2
const RAMP_SIZE := Vector3(3.0, 0.9, 3.4)   # width, lip height, length: a gentle kicker, about 15 degrees
const RAMP_SPEED := 5.0
const RAMP_TIME := 1.4
const RAMP_POP := 4.5                # an extra hop off the lip, metres a second up
const FOOT_POP := 8.0                # on foot: a big bouncy leap off the lip
const COIN_SPEED := 3.0
const COIN_TIME := 0.7
const COIN_BACK := 20.0              # seconds until a coin comes back
const COIN_RADIUS := 1.2
const RAMP_WAIT := 1.2               # seconds before the same strip or ramp boosts you again

# Every booster: its scene, kind, where ("at": a spot just above the ground, its height near the real ground so the
# ground under it is found and not a roof) and which way it pushes ("to": a point on the ground it points at).
# Coin lines go from "at" to "to" with "count" coins.
const BOOSTERS := [
	# --- Galaxity: round the lake (between the Lake Loop's own pads, scripts/races.gd) ---
	{"scene": "town", "kind": "strip", "at": Vector3(24, 0, 24.6), "to": Vector2(34, 24), "where": "the lake's south shore"},
	{"scene": "town", "kind": "strip", "at": Vector3(-19, 0, -19.6), "to": Vector2(-28, -18), "where": "the lake's north shore"},
	{"scene": "town", "kind": "strip", "at": Vector3(-30, 0, 19.6), "to": Vector2(-22, 23), "where": "the lake's west shore"},
	# --- Galaxity: the streets ---
	{"scene": "town", "kind": "strip", "at": Vector3(72, 0, 3), "to": Vector2(90, 3), "where": "the Homes street"},
	{"scene": "town", "kind": "strip", "at": Vector3(-42, 0, 42), "to": Vector2(-32, 41), "where": "the road out of the Market"},
	{"scene": "town", "kind": "strip", "at": Vector3(43, 0, 44), "to": Vector2(43, 51), "where": "the way into the Skate Park"},
	# --- Galaxity: coins along the rail line through the south meadow to the Skate Park and on east ---
	{"scene": "town", "kind": "coins", "at": Vector3(9, 0, 49.5), "to": Vector2(14, 51.5), "count": 3, "where": "between the meadow rails"},
	{"scene": "town", "kind": "coins", "at": Vector3(23.5, 0, 53.8), "to": Vector2(31, 51.5), "count": 4, "where": "between the meadow rails"},
	{"scene": "town", "kind": "coins", "at": Vector3(73, 0, 48.5), "to": Vector2(77.5, 52.5), "count": 3, "where": "past the Skate Park"},
	{"scene": "town", "kind": "coins", "at": Vector3(86.5, 0, 53.5), "to": Vector2(94, 50.2), "count": 4, "where": "on to the courts"},
	# --- Galaxity: coins down the rail line from the Library to the Spooky Woods ---
	{"scene": "town", "kind": "coins", "at": Vector3(-20.5, 0, -52.5), "to": Vector2(-28.5, -52.8), "count": 4, "where": "the Library rail line"},
	{"scene": "town", "kind": "coins", "at": Vector3(-44.5, 0, -73), "to": Vector2(-51, -71.8), "count": 3, "where": "the rail line to the woods"},
	{"scene": "town", "kind": "coins", "at": Vector3(-69, 0, -93.2), "to": Vector2(-77.5, -93.8), "count": 4, "where": "the rail line to the woods"},
	# --- Galaxity: big air ---
	{"scene": "town", "kind": "ramp", "at": Vector3(14, 0, 64), "to": Vector2(24, 64), "where": "the south meadow"},
	{"scene": "town", "kind": "ramp", "at": Vector3(66, 0, 74), "to": Vector2(74, 80), "where": "by the sports fields"},
	{"scene": "town", "kind": "ramp", "at": Vector3(60, 0, 90), "to": Vector2(68, 90), "where": "by the soccer field"},

	# --- Stars Hollow: down Lookout Hill to the Big Air Kicker ---
	{"scene": "earth", "kind": "coins", "at": Vector3(-99, 4, -100), "to": Vector2(-80, -100.6), "count": 6, "where": "down Lookout Hill"},
	{"scene": "earth", "kind": "strip", "at": Vector3(-75, 0, -100.8), "to": Vector2(-67, -101), "where": "into the Big Air Kicker"},
	# --- Stars Hollow: the streets ---
	{"scene": "earth", "kind": "strip", "at": Vector3(-2, 0, -100), "to": Vector2(6, -100), "where": "into the Hollow Skate Yard"},
	{"scene": "earth", "kind": "strip", "at": Vector3(-22, 0, 58), "to": Vector2(-32, 58), "where": "Maple Lane"},
	{"scene": "earth", "kind": "coins", "at": Vector3(-46, 0, 58), "to": Vector2(-64, 58), "count": 5, "where": "Maple Lane"},
	{"scene": "earth", "kind": "strip", "at": Vector3(-24, 0, -20), "to": Vector2(-24, -30), "where": "behind Main Street"},
	# --- Stars Hollow: round Willow Pond and big air ---
	{"scene": "earth", "kind": "coins", "at": Vector3(-66, 0, 21), "to": Vector2(-86, 21), "count": 5, "where": "round Willow Pond"},
	{"scene": "earth", "kind": "ramp", "at": Vector3(-40, 0, 26), "to": Vector2(-50, 26), "where": "by the playground"},
	{"scene": "earth", "kind": "ramp", "at": Vector3(56, 0, 30), "to": Vector2(56, 20), "where": "the lane past the barn"},
]

const TEAL := Color(0.3, 0.95, 0.95)
const GOLD := Color(1.0, 0.85, 0.35)

var _scene: Node
var _holder: Node3D
var _items: Array[Node3D] = []        # the boosters in the scene showing
var _wait := {}                       # booster -> seconds until it boosts again
var _t := 0.0
var used := 0                         # boosts given, all told (tools/test_boosters.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	_t += delta
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_items.clear()
		_wait.clear()
		if s:
			_place_in.call_deferred(s)
	for b in _wait.keys():
		_wait[b] = float(_wait[b]) - delta
		if float(_wait[b]) <= 0.0:
			_wait.erase(b)
	_animate(delta)
	_check_player()


func scene_key(s: Node) -> String:
	if s == null:
		return ""
	for k in SCENES:
		if SCENES[k] == s.scene_file_path:
			return k
	return ""


func in_scene(key: String) -> Array:
	return BOOSTERS.filter(func(b: Dictionary) -> bool: return b.scene == key)


func items() -> Array[Node3D]:
	return _items


func marks() -> Array:
	# For the map and the minimap: one small arrow for each strip and ramp, and one at the start of each coin line,
	# pointing the way it pushes
	var out := []
	var key := scene_key(get_tree().current_scene)
	for b in in_scene(key):
		var at := Vector3(b.at)
		var to := Vector2(b.to)
		var dir := Vector2(to.x - at.x, to.y - at.z).normalized()
		out.append({"pos": at, "yaw": atan2(dir.x, dir.y), "kind": b.kind})
	return out


# -----------------------------------------------------------------------------
# Putting them in
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D:
		return
	var key := scene_key(s)
	if key == "" or s.get_node_or_null("Boosters"):
		return
	_holder = Node3D.new()
	_holder.name = "Boosters"
	s.add_child(_holder)
	var i := 0
	for b in in_scene(key):
		var at := Vector3(b.at)
		var to := Vector2(b.to)
		match str(b.kind):
			"strip":
				_add(_strip(), b, i, at, to)
			"ramp":
				_add(_ramp(), b, i, at, to)
			"coins":
				var n := int(b.get("count", 3))
				for k in n:
					var f := float(k) / maxf(n - 1, 1)
					var spot := Vector3(lerpf(at.x, to.x, f), at.y, lerpf(at.z, to.y, f))
					var c := _coin()
					_add(c, b, i, spot, to + Vector2(to.x - at.x, to.y - at.z), k)
		i += 1


func _add(node: Node3D, b: Dictionary, index: int, at: Vector3, to: Vector2, k := 0) -> void:
	node.set_meta("kind", str(b.kind))
	node.set_meta("index", index)
	node.set_meta("where", str(b.get("where", "")))
	node.name = "%s %d%s" % [str(b.kind).capitalize(), index, "" if b.kind != "coins" else ".%d" % k]
	_holder.add_child(node)
	var hit := ground_at(at)
	var ground: Vector3 = hit.get("pos", at)
	var n: Vector3 = hit.get("normal", Vector3.UP)
	var fwd := Vector3(to.x - at.x, 0.0, to.y - at.z).normalized()
	if fwd == Vector3.ZERO:
		fwd = Vector3.FORWARD
	node.set_meta("grounded", not hit.is_empty())
	node.set_meta("dir", fwd)
	if b.kind == "coins":
		node.global_position = ground + Vector3.UP * 1.0
		node.rotation.y = atan2(fwd.x, fwd.z)
		return
	# Lie along the ground: up is the ground's normal, +Z the way it pushes (along the slope)
	var z := (fwd - n * fwd.dot(n)).normalized()
	var x := n.cross(z).normalized()
	node.global_transform = Transform3D(Basis(x, n, z), ground + n * 0.02)


func ground_at(at: Vector3) -> Dictionary:
	# The top of whatever solid thing is under this spot, looking down from a little above the height it was given
	# (so a roof or a tree overhead isn't taken for the ground). Moving things are looked through. Empty if nothing.
	var world := (_holder.get_world_3d() if _holder and _holder.is_inside_tree() else null)
	if world == null:
		return {}
	var space := world.direct_space_state
	var from := at + Vector3.UP * 4.0
	var skip: Array[RID] = []
	for k in 6:
		var q := PhysicsRayQueryParameters3D.create(from, at + Vector3.DOWN * 10.0)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if hit.collider is StaticBody3D and not (hit.collider as Node).is_in_group("booster"):
			return {"pos": hit.position, "normal": hit.normal}
		skip.append(hit.rid)
	return {}


# -----------------------------------------------------------------------------
# Riding and running over them
# -----------------------------------------------------------------------------
func _player() -> Node3D:
	var s := get_tree().current_scene
	return s.get_node_or_null("Player") as Node3D if s else null


func _check_player() -> void:
	if _items.is_empty():
		return
	var p := _player()
	if p == null or not p.has_method("boost") or bool(p.get("input_locked")) or bool(p.get("carried")):
		return
	var pos := p.global_position
	for b in _items:
		if not is_instance_valid(b) or _wait.has(b):
			continue
		var kind := str(b.get_meta("kind"))
		var local := b.global_transform.affine_inverse() * pos
		match kind:
			"strip":
				if absf(local.x) < STRIP_SIZE.x / 2.0 + 0.3 and absf(local.z) < STRIP_SIZE.z / 2.0 and local.y > -0.5 and local.y < 1.8:
					_wait[b] = RAMP_WAIT
					give(p, kind, STRIP_SPEED, STRIP_TIME, b)
			"ramp":
				if absf(local.x) < RAMP_SIZE.x / 2.0 + 0.2 and local.z > -RAMP_SIZE.z / 2.0 - 0.3 and local.z < RAMP_SIZE.z / 2.0 \
						and local.y > -0.5 and local.y < RAMP_SIZE.y + 1.6:
					var heading := Vector3(p.velocity.x, 0, p.velocity.z) if p is CharacterBody3D else Vector3.ZERO
					if heading.dot(b.get_meta("dir")) < 0.5:
						continue                      # only going up it, not sliding down its back
					_wait[b] = RAMP_WAIT
					give(p, kind, RAMP_SPEED, RAMP_TIME, b)
					_pop_off(p, b)
			"coins":
				if float(b.get_meta("gone", 0.0)) > 0.0:
					continue
				if pos.distance_to(b.global_position) < COIN_RADIUS + 0.6:
					b.set_meta("gone", COIN_BACK)
					give(p, kind, COIN_SPEED, COIN_TIME, b)


func give(p: Node3D, kind: String, extra: float, seconds: float, from: Node3D = null) -> void:
	# The boost itself, and the shared juice for it (the same family as the race pads, scripts/races.gd)
	var t := Races.boost_time(seconds)          # Zippy's Turbo Tank makes every boost last longer
	p.call("boost", extra, t)
	used += 1
	boosted.emit(kind)
	var at := p.global_position + Vector3(0, 0.3, 0)
	if kind == "coins":
		Juice.chime_pickup()
		Juice.burst(p.get_parent(), from.global_position if from else at, GOLD, 10, 0.06, 2.5, 0.45)
		Juice.rumble(0.15, 0.06)
	else:
		Audio.play("swish", 0.0, 0.1)
		Juice.blip("whoosh", 1.2 if kind == "strip" else 0.95, -8.0)
		Juice.shake(0.1)
		Juice.rumble(0.3, 0.2)
		Juice.burst(p.get_parent(), at, Color(TEAL, 0.8), 12, 0.06, 3.0, 0.5)
		var hud = p.get("skate").get("hud") if p.get("skate") else null
		if hud and hud.has_method("shout") and Game.riding:
			hud.shout("Boost!" if kind == "strip" else "Big air!", Color(0.5, 1.0, 1.0))


func _pop_off(p: Node3D, b: Node3D) -> void:
	# Off the lip: riders get a hop on top of the kicker's own launch; on foot she's bounced right up and over
	if Game.riding:
		var skate = p.get("skate")
		if skate:
			skate.call("spring", RAMP_POP)
	elif p is CharacterBody3D:
		(p as CharacterBody3D).velocity.y = maxf((p as CharacterBody3D).velocity.y, FOOT_POP)
		Audio.play("boing", -6.0)
		Juice.squash(p.get("model"), -0.18, 0.2)


# -----------------------------------------------------------------------------
# How they look (the race pads' teal and gold)
# -----------------------------------------------------------------------------
func _animate(delta: float) -> void:
	for b in _items:
		if not is_instance_valid(b):
			continue
		match str(b.get_meta("kind")):
			"strip", "ramp":
				for k in 3:
					var ch := b.get_node_or_null("Chevron%d" % k) as Node3D
					if ch:
						var len := STRIP_SIZE.z if b.get_meta("kind") == "strip" else RAMP_SIZE.z
						var f := fposmod(k / 3.0 + _t * 0.5, 1.0)
						ch.position.z = -len / 2.0 + 0.4 + f * (len - 0.8)
						if b.get_meta("kind") == "ramp":
							ch.position.y = 0.06 + (ch.position.z / RAMP_SIZE.z + 0.5) * RAMP_SIZE.y
				var glow := b.get_node_or_null("Glow") as MeshInstance3D
				if glow:
					(glow.material_override as StandardMaterial3D).emission_energy_multiplier = 1.4 + sin(_t * 6.0) * 0.5
			"coins":
				var spin := b.get_node_or_null("Spin") as Node3D
				var gone := float(b.get_meta("gone", 0.0))
				if gone > 0.0:
					gone -= delta
					b.set_meta("gone", gone)
				if spin:
					spin.visible = gone <= 0.0
					spin.rotation.y = _t * 3.0
					spin.position.y = sin(_t * 2.5 + b.position.x) * 0.12


func _mat(c: Color, glow := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c, 1.0)
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _chevrons(parent: Node3D, width: float) -> void:
	var m := _mat(GOLD, 2.5, true)
	for k in 3:
		var chevron := Node3D.new()
		chevron.name = "Chevron%d" % k
		chevron.position = Vector3(0, 0.07, 0)
		parent.add_child(chevron)
		for s in [-1.0, 1.0]:
			var bar := BoxMesh.new()
			bar.size = Vector3(width * 0.4, 0.03, 0.24)
			var b := _mesh(chevron, bar, Vector3(s * width * 0.16, 0, -0.2), m)
			b.rotation.y = s * 0.7


func _strip() -> Node3D:
	# A boost strip: a long dark teal strip with a glowing middle and gold chevrons sliding along it
	var strip := Node3D.new()
	var base := BoxMesh.new()
	base.size = STRIP_SIZE
	_mesh(strip, base, Vector3.ZERO, _mat(Color(0.12, 0.3, 0.4)))
	var glow := BoxMesh.new()
	glow.size = Vector3(STRIP_SIZE.x - 0.3, 0.02, STRIP_SIZE.z - 0.3)
	_mesh(strip, glow, Vector3(0, 0.04, 0), _mat(TEAL, 1.6)).name = "Glow"
	_chevrons(strip, STRIP_SIZE.x)
	_items.append(strip)
	return strip


func _ramp() -> Node3D:
	# A booster ramp: a solid wedge rising to its lip at +Z, teal on top with chevrons running up it, and a gold lip
	var ramp := Node3D.new()
	var body := StaticBody3D.new()
	body.name = "Body"
	body.add_to_group("booster")
	ramp.add_child(body)
	var wedge := PrismMesh.new()
	wedge.left_to_right = 1.0                   # the high side at +X, turned to +Z below
	wedge.size = Vector3(RAMP_SIZE.z, RAMP_SIZE.y, RAMP_SIZE.x)
	var mi := _mesh(body, wedge, Vector3(0, RAMP_SIZE.y / 2.0, 0), _mat(Color(0.14, 0.32, 0.44)))
	mi.rotation.y = -PI / 2.0
	var shape := CollisionShape3D.new()
	shape.shape = wedge.create_convex_shape()
	shape.position = mi.position
	shape.rotation = mi.rotation
	body.add_child(shape)
	# The glowing top: a thin plate along the slope
	var slope := atan2(RAMP_SIZE.y, RAMP_SIZE.z)
	var plate := BoxMesh.new()
	plate.size = Vector3(RAMP_SIZE.x - 0.4, 0.02, sqrt(RAMP_SIZE.z * RAMP_SIZE.z + RAMP_SIZE.y * RAMP_SIZE.y) - 0.3)
	var g := _mesh(ramp, plate, Vector3(0, RAMP_SIZE.y / 2.0 + 0.02, 0), _mat(TEAL, 1.6))
	g.rotation.x = -slope
	g.name = "Glow"
	var lip := BoxMesh.new()
	lip.size = Vector3(RAMP_SIZE.x, 0.08, 0.16)
	_mesh(ramp, lip, Vector3(0, RAMP_SIZE.y + 0.02, RAMP_SIZE.z / 2.0 - 0.08), _mat(GOLD, 2.0))
	_chevrons(ramp, RAMP_SIZE.x - 0.4)
	for k in 3:
		(ramp.get_node("Chevron%d" % k) as Node3D).rotation.x = -slope
	_items.append(ramp)
	return ramp


func _coin() -> Node3D:
	# A booster coin: a glowing gold coin with a teal arrow on each face, spinning and bobbing
	var coin := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	coin.add_child(spin)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.1
	_mesh(spin, disc, Vector3.ZERO, _mat(GOLD, 1.8)).rotation.x = PI / 2.0
	var rim := TorusMesh.new()
	rim.inner_radius = 0.38
	rim.outer_radius = 0.48
	_mesh(spin, rim, Vector3.ZERO, _mat(Color(1.0, 0.95, 0.7), 1.2)).rotation.x = PI / 2.0
	var arrow := PrismMesh.new()
	arrow.size = Vector3(0.36, 0.36, 0.03)
	var am := _mat(Color(0.2, 0.75, 0.8), 1.4, true)
	for side in [-1.0, 1.0]:
		var a := _mesh(spin, arrow, Vector3(0, 0, side * 0.06), am)
		a.rotation.z = -PI / 2.0
	coin.add_to_group("booster_coin")
	_items.append(coin)
	return coin
