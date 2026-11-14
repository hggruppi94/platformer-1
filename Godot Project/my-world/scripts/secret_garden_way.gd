extends Node

# The hidden way into the real Secret Garden (scripts/secret_garden.gd), put into the Void when the town loads, like
# the Undergardens (node "SecretGarden" under the Farm autoload: dialogue can say Farm/SecretGarden.<method>). Nothing
# in town.tscn changed.
#
# Everybody knows the Secret Gardens up on the hill, so this one has to be found (Hayden's day 1 playtest: "it's not
# very secret right now"):
#   1. Up on the hill a little **wren** hops along ahead of you, looking back as if it wants you to follow (TRAIL). Each
#      time you catch up it flits on to the next spot, and from the north rim it flies down the cliff.
#   2. At the foot of the cliff it pecks at the ground by an old wall thick with ivy: dig there (Interact) and you find
#      an old iron key (flag sg_key).
#   3. With the key the ivy parts, a door's behind it, and it opens (flag sg_found). From then on the door shows, it's on
#      the map, and it takes you in any time.
# Without the key the wall's just a wall ("thick with ivy... something rustles behind it"). The way home, through the
# garden's old door, puts you back on the ground in front of the wall.

const TOWN := "res://scenes/town/town.tscn"
const USE_SPOT := preload("res://scripts/use_spot.gd")
const DOOR := Farm.SECRET_DOOR                  # the wall's middle (its face looks north, along -Z)
const FACING := Vector2(0, -1)
const WALL_W := 9.0
const WALL_H := 4.6
const KEY_AT := Vector2(-71.2, -77.0)           # where the wren pecks, by the wall's east end
# The wren's trail: from the plateau's middle, north to the rim, then down to the key (the last two are on the ground)
const TRAIL := [Vector2(-72.0, -44.0), Vector2(-70.0, -54.0), Vector2(-73.0, -62.0), Vector2(-74.0, -68.5),
	Vector2(-71.2, -77.6)]
const CATCH_UP := 5.5                           # how near you get before it flits on
const SEEN_FROM := 14.0                         # how near before you notice it the first time

var _scene: Node
var _holder: Node3D
var _wren: Node3D
var _wren_at := 0                               # which TRAIL point it's on
var _flying := false
var _ivy_door: Array[Node3D] = []               # the ivy over the doorway, which parts
var _door_leaf: Node3D
var _key_mound: Node3D
var _wall_spot: Area3D
var _key_spot: Area3D
var _t := 0.0
var _base_y := 0.0                              # the ground in front of the wall
var coming_out := false                         # on the way home from the garden (set by leave_garden())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_holder = null
		if s and s.scene_file_path == TOWN and not s.has_meta("preview"):
			_place_in.call_deferred(s)
	if not is_instance_valid(_holder):
		return
	_t += delta
	if is_instance_valid(_wren) and not _flying:
		# A little bob and a peck now and then
		var body := _wren.get_node("Body") as Node3D
		var peck := maxf(0.0, sin(_t * 5.0)) if _wren_at == TRAIL.size() - 1 and not has_key() else 0.0
		body.rotation.x = peck * 0.7
		body.position.y = absf(sin(_t * 3.0)) * 0.05
	_follow()


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
func has_key() -> bool:
	return Dialogue.flags.has("sg_key")


func found() -> bool:
	return Dialogue.flags.has("sg_found")


func wren_at() -> int:
	return _wren_at


# -----------------------------------------------------------------------------
# The wren
# -----------------------------------------------------------------------------
func _follow() -> void:
	if found() or not is_instance_valid(_wren) or _flying:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var p := Vector2(player.global_position.x, player.global_position.z)
	var w := Vector2(_wren.global_position.x, _wren.global_position.z)
	var d := p.distance_to(w)
	if not Dialogue.flags.has("sg_wren_seen") and d < SEEN_FROM:
		Dialogue.set_flag("sg_wren_seen")
		Game.message("A little wren! Follow it!")
	_wren.look_at(Vector3(player.global_position.x, _wren.global_position.y, player.global_position.z), Vector3.UP, true)
	if d < CATCH_UP and _wren_at < TRAIL.size() - 1:
		hop_on()


func hop_on() -> void:
	# Flit on to the next spot on the trail, in a little arc (and a long glide down the cliff for the last one)
	if _wren_at >= TRAIL.size() - 1 or not is_instance_valid(_wren):
		return
	_wren_at += 1
	_flying = true
	var from := _wren.global_position
	var to := _ground(TRAIL[_wren_at]) + Vector3(0, 0.05, 0)
	var high := maxf(from.y, to.y) + 2.0
	Juice.blip("chime")
	_wren.look_at(Vector3(to.x, from.y, to.z), Vector3.UP, true)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(_wren):
			var at := from.lerp(to, k)
			at.y = lerpf(from.y, to.y, k) + sin(k * PI) * (high - maxf(from.y, to.y) + 1.0)
			_wren.global_position = at
			(_wren.get_node("Body/Wings") as Node3D).scale.x = 1.0 + absf(sin(k * 40.0)) * 0.8,
		0.0, 1.0, 1.8 if _wren_at == TRAIL.size() - 1 else 0.7)
	tw.tween_callback(func() -> void:
		_flying = false
		if is_instance_valid(_wren):
			(_wren.get_node("Body/Wings") as Node3D).scale.x = 1.0
		if _wren_at == TRAIL.size() - 1:
			_show_key()
			Game.message("The wren pecks by an old wall..."))


static func wren_model() -> Node3D:
	# A little round brown wren with its tail cocked up and a cream chest: our own little bird, made from shapes
	var w := Node3D.new()
	w.name = "Wren"
	var body := Node3D.new()
	body.name = "Body"
	w.add_child(body)
	var brown := _mat(Color(0.55, 0.36, 0.22))
	var cream := _mat(Color(0.95, 0.86, 0.68))
	var dark := _mat(Color(0.08, 0.06, 0.05))
	var beak := _mat(Color(0.95, 0.7, 0.3))
	_ball(body, 0.13, Vector3(0, 0.16, 0), brown, Vector3(1.0, 0.9, 1.15))
	_ball(body, 0.09, Vector3(0, 0.14, 0.06), cream, Vector3(1.0, 0.9, 1.0))
	_ball(body, 0.08, Vector3(0, 0.28, 0.08), brown)
	for sx in [-1.0, 1.0]:
		_ball(body, 0.018, Vector3(sx * 0.05, 0.3, 0.14), dark)
	var b := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.0
	bm.bottom_radius = 0.022
	bm.height = 0.07
	b.mesh = bm
	b.material_override = beak
	b.rotation.x = PI / 2.0
	b.position = Vector3(0, 0.28, 0.18)
	body.add_child(b)
	var tail := _ball(body, 0.06, Vector3(0, 0.27, -0.14), brown, Vector3(0.6, 1.6, 0.4))
	tail.rotation.x = -0.6
	var wings := Node3D.new()
	wings.name = "Wings"
	body.add_child(wings)
	for sx in [-1.0, 1.0]:
		_ball(wings, 0.07, Vector3(sx * 0.11, 0.18, -0.02), brown, Vector3(0.4, 0.8, 1.2))
	for sx in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.008
		lm.bottom_radius = 0.008
		lm.height = 0.07
		leg.mesh = lm
		leg.material_override = beak
		leg.position = Vector3(sx * 0.04, 0.035, 0)
		body.add_child(leg)
	w.scale = Vector3.ONE * 1.6                 # (a bit bigger than a real wren, so small eyes can spot it)
	return w


# -----------------------------------------------------------------------------
# Putting it in
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.get_node_or_null("Ivy Wall") != null:
		return
	_holder = Node3D.new()
	_holder.name = "Ivy Wall"
	s.add_child(_holder)
	_wall()
	_key_spot = null
	_key_mound = null
	if not found():
		_wren = wren_model()
		_holder.add_child(_wren)
		_wren_at = TRAIL.size() - 1 if has_key() else 0
		_wren.global_position = _ground(TRAIL[_wren_at]) + Vector3(0, 0.05, 0)
		if has_key():
			_wren.global_position = _wall_top_spot()
		elif _wren_at == TRAIL.size() - 1:
			_show_key()
	else:
		_open_door(false)
		var mark := Node3D.new()
		mark.name = "Secret Garden Mark"
		mark.set_script(load("res://scripts/landmark.gd"))
		mark.set("label", "Secret Garden")
		_holder.add_child(mark)
		mark.global_position = Vector3(DOOR.x, _base_y, DOOR.y)
	if coming_out:
		coming_out = false
		_land_outside.call_deferred()


func _ground(at: Vector2) -> Vector3:
	return Bosses.ground(_scene as Node3D, at.x, at.y)


func _wall_top_spot() -> Vector3:
	return Vector3(DOOR.x + 2.4, _base_y - 0.5 + WALL_H + 0.5 + 0.02, DOOR.y)


func _wall() -> void:
	var base := _ground(DOOR + FACING * 1.0)
	_base_y = base.y
	var w := Node3D.new()
	w.name = "Old Wall"
	_holder.add_child(w)
	w.global_position = Vector3(DOOR.x, base.y - 0.5, DOOR.y)
	w.rotation.y = atan2(FACING.x, FACING.y)    # its +Z looks north, away from the cliff
	var brick := _mat(Color(0.62, 0.36, 0.3), 0.95)
	var ivy := _mat(Color(0.2, 0.42, 0.18), 0.8)
	var ivy2 := _mat(Color(0.28, 0.52, 0.2), 0.8)
	# The wall: two solid pieces either side of the doorway and a lintel over it, so the doorway's really there
	var half := WALL_W / 2.0
	for side in [-1.0, 1.0]:
		var piece_w := half - 1.2
		_solid_box(w, Vector3(piece_w, WALL_H + 0.5, 0.9), Vector3(side * (1.2 + piece_w / 2.0), (WALL_H + 0.5) / 2.0, 0), brick)
	_solid_box(w, Vector3(2.4, WALL_H + 0.5 - 3.5, 0.9), Vector3(0, 3.5 + (WALL_H + 0.5 - 3.5) / 2.0, 0), brick)
	# The door, set back in the doorway (and a solid block behind it till it's open, so the cliff's never seen)
	var dark := _mat(Color(0.04, 0.05, 0.04))
	_box(w, Vector3(2.4, 3.0, 0.1), Vector3(0, 2.0, -0.35), dark)
	var hinge := Node3D.new()
	hinge.name = "Door Hinge"
	hinge.position = Vector3(-1.15, 0.5, -0.2)
	w.add_child(hinge)
	_door_leaf = hinge
	var wood := _mat(Color(0.42, 0.3, 0.38), 0.9)
	_box(hinge, Vector3(2.3, 3.0, 0.12), Vector3(1.15, 1.5, 0), wood)
	for k in 3:
		_box(hinge, Vector3(2.32, 0.12, 0.16), Vector3(1.15, 0.4 + k * 1.1, 0.02), _mat(Color(0.2, 0.18, 0.2), 0.6))
	_ball(hinge, 0.09, Vector3(1.95, 1.5, 0.1), _mat(Color(0.85, 0.65, 0.3), 0.4))
	var block := StaticBody3D.new()
	block.name = "Door Block"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 3.0, 0.6)
	cs.shape = bs
	cs.position = Vector3(0, 2.0, 0)
	block.add_child(cs)
	w.add_child(block)
	# Ivy all over it: big clumps on the wall, and a thick curtain over the doorway that parts once you've the key
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for k in 70:
		var at := Vector3(rng.randf_range(-half, half), rng.randf_range(0.7, WALL_H + 0.6), 0.48)
		if absf(at.x) < 1.35 and at.y < 3.7:
			continue
		_ball(w, rng.randf_range(0.35, 0.6), at, ivy if k % 2 else ivy2, Vector3(1.0, 1.0, 0.45))
	_ivy_door.clear()
	for k in 26:
		var at := Vector3(rng.randf_range(-1.25, 1.25), rng.randf_range(0.7, 3.8), 0.5 + rng.randf_range(0.0, 0.12))
		_ivy_door.append(_ball(w, rng.randf_range(0.35, 0.5), at, ivy if k % 2 else ivy2, Vector3(1.0, 1.0, 0.45)))
	# Trailing strands down the wall
	for k in 14:
		var strand := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 0.03
		cm.height = rng.randf_range(1.0, 2.6)
		strand.mesh = cm
		strand.material_override = ivy
		strand.position = Vector3(rng.randf_range(-half, half), WALL_H + 0.3 - cm.height / 2.0, 0.55)
		w.add_child(strand)
	# The way in
	_wall_spot = USE_SPOT.make(Vector3(0, 0.5, 1.6), _wall_offer, _wall_act, 2.4, 2.6)
	_wall_spot.name = "Wall Spot"
	w.add_child(_wall_spot)


func _show_key() -> void:
	if has_key() or is_instance_valid(_key_mound):
		return
	_key_mound = Node3D.new()
	_key_mound.name = "Key Mound"
	_holder.add_child(_key_mound)
	_key_mound.global_position = _ground(KEY_AT)
	_ball(_key_mound, 0.35, Vector3(0, 0.0, 0), _mat(Color(0.36, 0.25, 0.16), 1.0), Vector3(1.0, 0.4, 1.0))
	var glint := _ball(_key_mound, 0.06, Vector3(0.08, 0.12, 0.05), _mat(Color(1.0, 0.85, 0.4), 0.3, 1.5))
	glint.name = "Glint"
	_key_spot = USE_SPOT.make(Vector3.ZERO, func() -> String: return "dig where the wren is pecking", dig_key, 1.8, 2.0)
	_key_spot.name = "Key Spot"
	_key_mound.add_child(_key_spot)


func dig_key() -> void:
	if has_key():
		return
	Dialogue.set_flag("sg_key")
	Juice.blip("sparkle")
	if is_instance_valid(_key_mound):
		Fx.burst(_holder, _key_mound.global_position + Vector3(0, 0.3, 0), Color(0.5, 0.36, 0.2))
		_key_mound.queue_free()
	Game.message("An old iron key!")
	if is_instance_valid(_wren):
		_flying = true
		var tw := create_tween()
		tw.tween_property(_wren, "global_position", _wall_top_spot(), 0.8)
		tw.tween_callback(func() -> void: _flying = false)


func _wall_offer() -> String:
	if found():
		return "go in to the Secret Garden"
	if has_key():
		return "part the ivy"
	return "look at the old wall"


func _wall_act() -> void:
	if found():
		enter_garden()
		return
	if not has_key():
		Game.message("An old wall. It smells of roses...")
		return
	Dialogue.set_flag("sg_found")
	Juice.blip("chime")
	Juice.shake(0.12)
	Game.message("A hidden door! The Secret Garden!")
	_open_door(true)
	if is_instance_valid(_wren):
		var tw := create_tween()
		tw.tween_property(_wren, "global_position", _wren.global_position + Vector3(0, 6, -3), 1.2)
		tw.tween_callback(_wren.queue_free)


func _open_door(animate: bool) -> void:
	for n in _ivy_door:
		if not is_instance_valid(n):
			continue
		var to := n.position + Vector3(signf(n.position.x + 0.01) * 1.0, 0, 0.1)
		if animate:
			create_tween().tween_property(n, "position", to, 0.8)
		else:
			n.position = to
	if is_instance_valid(_door_leaf):
		if animate:
			create_tween().tween_property(_door_leaf, "rotation:y", -1.6, 1.2).set_delay(0.6)
		else:
			_door_leaf.rotation.y = -1.6


func enter_garden() -> void:
	Game.pending_message = ""
	Game.go(Farm.SECRET_GARDEN, "Entrance", "the Secret Garden")


func way_out() -> Dictionary:
	# Where you come out: in front of the wall, facing away from it
	var at := DOOR + FACING * 3.0
	return {"position": Vector3(at.x, 2.0, at.y), "yaw": atan2(FACING.x, FACING.y)}


func leave_garden() -> void:
	var out := way_out()
	coming_out = true
	Game.go_to_point(TOWN, out.position, out.yaw, "the Void")


func _land_outside() -> void:
	# The garden can't measure the town's ground, so the resume point is only roughly right: stand on the ground
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or not is_instance_valid(_scene):
		return
	var at: Vector3 = way_out().position
	player.global_position = _ground(Vector2(at.x, at.z)) + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO


# -----------------------------------------------------------------------------
# Little helpers
# -----------------------------------------------------------------------------
static func _mat(c: Color, rough := 0.8, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _ball(parent: Node3D, r: float, at: Vector3, m: Material, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = m
	mi.position = at
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


static func _solid_box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = at
	parent.add_child(sb)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	_box(sb, size, Vector3.ZERO, m)
	return sb
