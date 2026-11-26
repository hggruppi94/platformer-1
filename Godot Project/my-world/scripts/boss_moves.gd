extends Node3D

# Extra moves that make a boss harder to fight from a distance (Hayden, 21 Nov 2026: "every boss needs to have some
# sort of range attack", "or teleport, or something to add challenge"). A boss puts one of these on itself with
# BossMoves.add(); it waits until the boss says it's free (its "can" Callable) and then, every so often, does one of
# its moves, always warned first by the boss's own body (scripts/boss_tell.gd "throw" or "blink"):
#
#   "shot"  it throws one slow glowing thing straight at you: step aside.
#   "fan"   three of them in a spread: step out between them.
#   "lob"   it lobs something up in an arc to where you are: run out from under it before it lands.
#   "blink" it flickers, vanishes in a puff and pops up somewhere else in its arena.
#
# What it throws looks like the boss (a goo blob, a spinning gear, a boulder, a feather, a sour note...:
# scripts/boss_bits.gd). Kid-safe: slow enough to see coming, a bump at most (1), never while you're talking.
# Nothing is drawn on the ground: the throw itself is what you watch (Hayden: no arrows or circles).
#
# No class_name (tools run with --script compile class_name scripts before the autoloads exist): preload it.
#
#   const MOVES := preload("res://scripts/boss_moves.gd")
#   MOVES.add(self, {"moves": ["lob", "shot"], "every": 7.0, "look": "blob", "colour": ring_colour,
#       "can": func() -> bool: return not defeated, "from": 1.5})

const TELL := preload("res://scripts/boss_tell.gd")
const BITS := preload("res://scripts/boss_bits.gd")
const SHOT_SPEED := 8.5           # m/s: a slow, easy-to-read throw (you run at 5, sideways is all it takes)
const SHOT_RANGE := 34.0
const LOB_TIME := 1.35            # seconds a lob is in the air
const LOB_HIT := 1.5              # how close to where it lands still bumps you
const HIT_R := 0.75               # how close a shot has to pass to your middle
const FAN_SPREAD := 0.38          # radians between the three shots of a fan
const BLINK_GONE := 0.45          # seconds it's gone for when it blinks
const BLINK_CLEAR := 6.0          # it never pops up closer than this to you

static var enabled := true        # tests that time a fight to the second can switch these off

var boss: Node3D
var moves: Array = ["shot"]
var every := 7.0
var look := "blob"
var colour := Color(1, 1, 1)
var size := 0.6                   # how big what it throws is
var can: Callable                 # -> bool: the fight's on and the boss is free to do a move
var from := 1.5                   # how high above the boss's feet it throws from
var from_node: Node3D             # (or from this node, for a boss whose body moves on its own: the centipede)
var centre := Vector3.ZERO        # "blink": where its arena is (left out: where it is when its fight starts)
var centre_set := false
var radius := 12.0
var keep_height := false          # "blink": floats at the same height instead of landing on the ground
var damage := 1
var count := 0                    # how many moves it's done (tests)
var last := ""                    # the last one
var _t := 4.0
var _next := 0
var _told := false
var _gone := 0.0
var _blink_to := Vector3.ZERO


static func add(on: Node3D, opts: Dictionary) -> Node3D:
	var m: Node3D = (load("res://scripts/boss_moves.gd") as GDScript).new()
	m.name = "Boss Moves"
	m.boss = on
	m.moves = opts.get("moves", ["shot"])
	m.every = float(opts.get("every", 7.0))
	m.look = str(opts.get("look", "blob"))
	m.colour = opts.get("colour", Color(1, 1, 1))
	m.size = float(opts.get("size", 0.6))
	m.can = opts.get("can", Callable())
	m.from = float(opts.get("from", 1.5))
	m.from_node = opts.get("from_node", null)
	m.centre = opts.get("centre", Vector3.ZERO)
	m.centre_set = opts.has("centre")
	m.radius = float(opts.get("radius", 12.0))
	m.keep_height = bool(opts.get("keep_height", false))
	m.damage = int(opts.get("damage", 1))
	m._t = float(opts.get("first", m.every * 0.7))
	on.add_child(m)
	return m


static func of(on: Node) -> Node3D:
	return on.get_node_or_null("Boss Moves") as Node3D if on else null


func _physics_process(delta: float) -> void:
	if not enabled or boss == null or not is_instance_valid(boss):
		return
	if _gone > 0.0:
		_gone -= delta
		if _gone <= 0.0:
			_appear()
		return
	if can.is_valid() and not bool(can.call()):
		_told = false
		return
	if not centre_set:
		centre_set = true                          # (bosses are often moved into place after they're made)
		centre = boss.global_position
	if Dialogue.is_active():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.global_position.distance_to(_from_point()) > SHOT_RANGE + 6.0:
		return
	_t -= delta
	var kind := str(moves[_next % moves.size()])
	if not _told and _t <= TELL.lead():
		if TELL.showing(boss):                     # it's winding up for something of its own: wait for that
			_t = TELL.lead() + 0.1
			return
		_told = true
		_tell(kind)
	if _t <= 0.0:
		_t = every * randf_range(0.85, 1.2)
		_told = false
		_next += 1
		count += 1
		last = kind
		match kind:
			"shot":
				_shoot(player, 0.0)
			"fan":
				for i in [-1, 0, 1]:
					_shoot(player, FAN_SPREAD * i)
			"lob":
				_lob(player)
			"blink":
				_vanish(player)


func _tell(kind: String) -> void:
	# The boss's own body winds up. It doesn't take the boss's tell slot, so the boss can still wind up for its own
	# attack while this one's going (the two add together on its body, once: scripts/boss_tell.gd keeps one record of them on it).
	var had: Variant = boss.get_meta("boss_tell") if boss.has_meta("boss_tell") else null
	var opts := {}
	var vis := boss.get_node_or_null("Visual")
	if vis == null and "visual" in boss:
		vis = boss.get("visual")
	if vis:
		opts["visual"] = vis
	TELL.warn(boss, "blink" if kind == "blink" else "throw", 2.0, colour, TELL.lead(), opts)
	if had != null and is_instance_valid(had):
		boss.set_meta("boss_tell", had)
	else:
		boss.remove_meta("boss_tell")


func _from_point() -> Vector3:
	if from_node and is_instance_valid(from_node):
		return from_node.global_position + Vector3(0, from, 0)
	return boss.global_position + Vector3(0, from, 0)


# -----------------------------------------------------------------------------
# Throws
# -----------------------------------------------------------------------------
func _shoot(player: Node3D, turn: float) -> void:
	var at := _from_point()
	var aim := player.global_position + Vector3(0, 0.8, 0) - at
	if aim.length() < 0.5:
		return
	var dir := aim.normalized().rotated(Vector3.UP, turn)
	var s := Thrown.new()
	s.name = "Boss Shot"
	s.mover = self
	s.velocity = dir * SHOT_SPEED
	s.life = SHOT_RANGE / SHOT_SPEED
	_dress(s)
	boss.get_parent().add_child(s)
	s.global_position = at
	Juice.blip("whoosh", 1.4, -6.0)


func _lob(player: Node3D) -> void:
	var at := _from_point()
	var s := Thrown.new()
	s.name = "Boss Lob"
	s.mover = self
	s.lob = true
	s.start = at
	s.target = player.global_position + Vector3(0, 0.1, 0)
	s.life = LOB_TIME
	s.peak = 3.0 + _flat(s.target - at) * 0.18
	_dress(s)
	boss.get_parent().add_child(s)
	s.global_position = at
	Juice.blip("whoosh", 0.9, -5.0)


func _dress(s: Thrown) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Look"
	mi.mesh = BITS.mesh(look)
	mi.material_override = BITS.mat(colour, 1.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * size
	mi.position.y = -0.5 * size                       # (the shapes stand on their middle: centre them)
	var spin := Node3D.new()
	spin.name = "Spin"
	spin.add_child(mi)
	s.add_child(spin)
	var halo := MeshInstance3D.new()
	halo.name = "Glow"
	halo.mesh = BITS.mesh("fleck")
	halo.material_override = BITS.mat(colour.lightened(0.4), 1.4, 0.35)
	halo.scale = Vector3.ONE * size * 1.9
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(halo)
	s.colour = colour
	s.size = size
	s.damage = damage


func hit_player(at: Vector3) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.is_invulnerable() and not Dialogue.is_active():
		p.hurt(damage, at)


# -----------------------------------------------------------------------------
# Blinking away
# -----------------------------------------------------------------------------
func _vanish(player: Node3D) -> void:
	var to := _blink_spot(player)
	if to == Vector3.INF:
		return
	_blink_to = to
	_puff(boss.global_position)
	boss.visible = false
	_gone = BLINK_GONE
	Juice.blip("rewind", 1.3, -4.0)


func _appear() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	boss.global_position = _blink_to
	if boss is CharacterBody3D:
		(boss as CharacterBody3D).velocity = Vector3.ZERO
	boss.visible = true
	_puff(_blink_to)
	Juice.blip("pop", 0.8, -4.0)


func _blink_spot(player: Node3D) -> Vector3:
	var space := boss.get_world_3d().direct_space_state
	var here := boss.global_position
	for i in 16:
		var a := randf() * TAU
		var d := radius * randf_range(0.3, 0.85)
		var spot := centre + Vector3(sin(a) * d, 0, cos(a) * d)
		if _flat(spot - player.global_position) < BLINK_CLEAR or _flat(spot - here) < 4.0:
			continue
		if keep_height:
			return Vector3(spot.x, here.y, spot.z)
		var q := PhysicsRayQueryParameters3D.create(Vector3(spot.x, here.y + 8.0, spot.z), Vector3(spot.x, here.y - 12.0, spot.z))
		if boss is CollisionObject3D:
			q.exclude = [(boss as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - here.y) > 3.0:
			continue
		return hit.position + Vector3(0, 0.05, 0)
	return Vector3.INF


func _puff(at: Vector3) -> void:
	# A burst of the boss's own shapes where it vanishes and where it pops back
	var parent := boss.get_parent()
	if parent == null:
		return
	Juice.burst(parent, at + Vector3(0, 1.2, 0), colour, 16, 0.12, 4.0, 0.4)
	for i in 10:
		var n := MeshInstance3D.new()
		n.name = "Blink Bit"
		n.mesh = BITS.mesh(look)
		n.material_override = BITS.mat(colour.lightened(0.2), 1.6)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(n)
		var a := TAU * i / 10.0
		n.global_position = at + Vector3(0, 1.0, 0)
		n.scale = Vector3.ONE * size * 0.6
		var tw := n.create_tween().set_parallel()
		tw.tween_property(n, "global_position", at + Vector3(sin(a) * 2.2, randf_range(0.6, 2.6), cos(a) * 2.2), 0.45) \
			.set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.45)
		tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.45).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(n.queue_free)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


# What a boss throws: flies straight (a shot) or in an arc (a lob), spinning, with a little trail behind it.
class Thrown extends Node3D:
	var mover: Node3D
	var velocity := Vector3.ZERO
	var lob := false
	var start := Vector3.ZERO
	var target := Vector3.ZERO
	var peak := 3.0
	var life := 3.0
	var colour := Color.WHITE
	var size := 0.6
	var damage := 1
	var _t := 0.0
	var _trail_t := 0.0
	var _done := false

	func _ready() -> void:
		add_to_group("boss_shots")

	func _physics_process(delta: float) -> void:
		if _done:
			return
		_t += delta
		var spin := get_node_or_null("Spin") as Node3D
		if spin:
			spin.rotate_x(delta * 7.0)
			spin.rotate_y(delta * 4.0)
		var was := global_position
		if lob:
			var u := clampf(_t / life, 0.0, 1.0)
			global_position = start.lerp(target, u) + Vector3(0, 4.0 * peak * u * (1.0 - u), 0)
			if u >= 1.0:
				_land()
				return
		else:
			global_position += velocity * delta
			var p := get_tree().get_first_node_in_group("player") as Node3D
			if p and (p.global_position + Vector3(0, 0.8, 0)).distance_to(global_position) < HIT_R + size * 0.4:
				_hit_player()
				return
			# It stops on a wall or the ground (layer 1, the world), so nothing comes through walls at you
			var q := PhysicsRayQueryParameters3D.create(was, global_position, 1)
			if p is CollisionObject3D:
				q.exclude = [(p as CollisionObject3D).get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() or _t >= life:
				_pop()
				return
		_trail_t -= delta
		if _trail_t <= 0.0:
			_trail_t = 0.05
			_trail(was)

	func _trail(at: Vector3) -> void:
		var n := MeshInstance3D.new()
		n.name = "Shot Trail"
		n.mesh = BITS.mesh("spark")
		n.material_override = BITS.mat(colour.lightened(0.3), 1.6, 0.7)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_parent().add_child(n)
		n.global_position = at
		n.scale = Vector3.ONE * size * 0.5
		var tw := n.create_tween()
		tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.35)
		tw.tween_callback(n.queue_free)

	func _hit_player() -> void:
		if mover and is_instance_valid(mover):
			mover.call("hit_player", global_position)
		_pop()

	func _land() -> void:
		# A lob landing: a splat where it comes down, a bump only if you're still right there on the ground
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.is_on_floor() and Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() < LOB_HIT \
				and absf(p.global_position.y - target.y) < 1.5:
			if mover and is_instance_valid(mover):
				mover.call("hit_player", global_position)
		Juice.dust(get_parent(), target, 0.8)
		Audio.play_at("stomp", target, 1.0, 0.3)
		_pop()

	func _pop() -> void:
		_done = true
		Juice.burst(get_parent(), global_position, colour, 10, 0.08, 3.0, 0.3)
		Juice.blip("pop", 1.2, -6.0)
		queue_free()
