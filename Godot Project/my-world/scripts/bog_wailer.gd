extends CharacterBody3D

# A Bog Wailer (a working name, until Hayden names them), Hayden, 24 Nov 2026: "siren-type enemies with giant malformed
# heads that will slowly wander the swamp and their loud call summons hordes of smaller enemies". Our own design: a
# tall, thin, stooping thing of bog wood and moss under a huge lumpy head that's far too big for it, lopsided, with one
# big glowing eye and one little one, moss hanging off it, and a wide soft mouth. Creepy, never gory.
#
# It plods slowly round its bit of the swamp (scripts/swamp.gd puts them in), wading through the water as if it isn't
# there. When it hears you near (HEAR, no need to see you: it's the swamp's ears) it stops, its head swells and its
# mouth opens (the wind-up, so you can see it coming), then it WAILS: a long eerie call, rings of sound rolling out,
# and Mucklings (little bog Gloops: scenes/enemies/gloop.tscn, recoloured) pop up out of the mud round it and come for
# you. It calls again while you stay near, but never has more than MAX_MUCKLINGS out at once.
# Its call doesn't hurt; bumping into it does (1). Pop it like any enemy: three bubbles (a big bubble is three), a stomp
# on its big head, a roll or a ram on your ride. Popped, it's silenced, and every Muckling it called melts back into the
# mud. It comes back a while later, once you're away from its patch.

signal popped(who: Node3D)
signal called(count: int)

const MUCKLING := preload("res://scenes/enemies/gloop.tscn")
const HEAD_Y := 2.15                     # the middle of its head, from its feet
const STOMP_ABOVE := 2.0                 # a landing with her feet above this (from its feet) is a stomp on the head
const STOMP_BOUNCE := 10.0
const MAX_MUCKLINGS := 10                # a horde, but never more than this out at once
const NEAR_YOU := 4.5                    # the ones that come up round you, this far off (and up to 2 m more)
const WIND_UP := 1.3                     # seconds its head swells before the wail
const WAIL_TIME := 1.1

@export var hits := 3
@export var damage := 1
@export var xp_reward := 10
@export var hear := 15.0
@export var wander_radius := 8.0
@export var walk_speed := 0.8            # slow: she walks at 5
@export var call_every := 10.0
@export var call_count := 5              # Mucklings per call (fewer if it's near MAX_MUCKLINGS)
@export var respawn_time := 60.0
@export var respawn_clear := 20.0
@export var skin := Color(0.2, 0.24, 0.2)        # its bog-wood body
@export var head_colour := Color(0.42, 0.44, 0.36)
@export var eye_colour := Color(1.0, 0.9, 0.45)
@export var muck := {"green": Color(0.2, 0.32, 0.16), "deep": Color(0.05, 0.1, 0.06), "pop": Color(0.5, 0.8, 0.4)}
@export var bed_y := -0.8                # the swamp's bed, where Mucklings come up
@export var murk_top := -0.12            # the swamp's top: Mucklings wade with their bodies up out of it

var home := Vector3.ZERO
var defeated := false
var hp := 3
var visual: Node3D
var head: Node3D
var mouth: MeshInstance3D
var player: CharacterBody3D
var winding := 0.0                       # >0 while its head swells (the wind-up)
var wailing := 0.0                       # >0 while it calls
var calls := 0                           # (tests read these)
var mucklings: Array[Node] = []
var _call_cd := 2.0
var _target := Vector3.ZERO
var _rest := 1.0
var _hurt_cd := 0.0
var _stagger := 0.0
var _t := 0.0
var _hitbox: Area3D
var _shape: CollisionShape3D
var _respawn_left := -1.0
var _arms: Array[Node3D] = []
static var _made := 0                    # Mucklings made, for their names


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bog_wailers")
	home = global_position
	_target = home
	hp = hits
	_t = randf() * 10.0
	_call_cd = randf_range(1.0, 2.5)
	collision_layer = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.0
	_shape.shape = cap
	_shape.position.y = 1.0
	add_child(_shape)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.8
	hcap.height = 2.9
	hcs.shape = hcap
	hcs.position.y = 1.45
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	_build()


# The look: everything from Godot's own shapes ---------------------------------------------------------------------
func _mat(c: Color, rough := 0.9, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _ball(r: float, m: Material, at: Vector3, parent: Node3D, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	mi.scale = sc
	parent.add_child(mi)
	return mi


func _limb(r: float, length: float, m: Material, parent: Node3D) -> MeshInstance3D:
	# A limb hanging down from its parent's origin
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(length, r * 2.0 + 0.01)
	c.radial_segments = 10
	c.rings = 4
	mi.mesh = c
	mi.material_override = m
	mi.position = Vector3(0, -length / 2.0, 0)
	parent.add_child(mi)
	return mi


func _build() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name) + int(home.x * 13.0 + home.z * 7.0)
	var body := _mat(skin)
	var moss := _mat(skin.lerp(Color(0.25, 0.42, 0.2), 0.6))
	var lump := _mat(head_colour)
	# Thin legs, knees a little bent, and a long stooping body
	for s: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(s * 0.2, 0.95, 0)
		hip.rotation.x = 0.08
		visual.add_child(hip)
		_limb(0.1, 0.95, body, hip)
		_ball(0.15, body, Vector3(s * 0.2, 0.06, 0.08), visual, Vector3(1.0, 0.5, 1.6))
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.95, 0)
	torso.rotation.x = 0.35                               # stooped forward under the weight of its head
	visual.add_child(torso)
	var chest := _limb(0.24, 1.05, body, torso)
	chest.position = Vector3(0, 0.5, 0)
	_ball(0.3, moss, Vector3(0, 0.95, 0.02), torso, Vector3(1.2, 0.55, 1.0))   # mossy shoulders
	# Long arms that hang almost to the ground and sway as it walks
	for s: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(s * 0.36, 0.92, 0.05)
		sh.rotation.z = s * 0.12
		torso.add_child(sh)
		_limb(0.07, 1.35, body, sh)
		for f in 3:                                       # three long twig fingers
			var fi := _limb(0.025, 0.28, body, sh)
			fi.position = Vector3((f - 1) * 0.04, -1.45, 0.02)
			fi.rotation.x = (f - 1) * 0.25
		_arms.append(sh)
	# The head: far too big, lumpy and lopsided, on a thin neck
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, HEAD_Y, 0.42)
	visual.add_child(head)
	_ball(0.78, lump, Vector3.ZERO, head, Vector3(1.08, 0.95, 1.0))
	for k in 6:                                           # the lumps
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-0.6, 0.6)).normalized()
		_ball(rng.randf_range(0.28, 0.46), lump, dir * 0.62, head, Vector3.ONE * rng.randf_range(0.9, 1.15))
	_ball(0.5, lump, Vector3(0.38, 0.35, -0.1), head, Vector3(1.0, 0.8, 1.0))    # the big bulge on one side
	# Moss draped over the top, hanging in strands
	var drape := _mat(Color(0.24, 0.4, 0.2), 0.95)
	_ball(0.6, drape, Vector3(-0.15, 0.5, -0.05), head, Vector3(1.1, 0.4, 1.0))
	for k in 9:
		var a := rng.randf_range(-2.4, 2.4)
		var hang := Node3D.new()
		hang.position = Vector3(sin(a) * 0.72, 0.15 + rng.randf() * 0.3, cos(a) * 0.4 - 0.1)
		head.add_child(hang)
		_limb(0.03, rng.randf_range(0.4, 0.9), drape, hang)
	# One big eye and one little one, glowing, set lopsided
	var eye := _mat(eye_colour, 0.3, 3.0)
	var dark := _mat(Color(0.03, 0.03, 0.04), 0.6)
	_ball(0.24, dark, Vector3(-0.3, 0.12, 0.62), head)
	_ball(0.17, eye, Vector3(-0.3, 0.12, 0.74), head)
	_ball(0.12, dark, Vector3(0.3, 0.26, 0.66), head)
	_ball(0.08, eye, Vector3(0.3, 0.26, 0.74), head)
	var shine := OmniLight3D.new()
	shine.light_color = eye_colour
	shine.light_energy = 0.7
	shine.omni_range = 4.0
	shine.position = Vector3(-0.2, 0.1, 1.1)
	head.add_child(shine)
	# A wide soft mouth that opens to wail (a dark hollow, no teeth)
	mouth = _ball(0.3, dark, Vector3(0.0, -0.34, 0.66), head, Vector3(1.4, 0.18, 0.6))
	mouth.name = "Mouth"


# Thinking ------------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if defeated:
		if _respawn_left >= 0.0:
			_respawn_left -= delta
			if _respawn_left < 0.0:
				_try_respawn()
		return
	_find_player()
	_t += delta
	_call_cd = maxf(_call_cd - delta, 0.0)
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	mucklings.assign(mucklings.filter(func(n: Node) -> bool: return is_instance_valid(n) and not bool(n.get("defeated"))))
	var slow := Arsenal.slow(self)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var want := Vector3.ZERO
	if _stagger > 0.0:
		_stagger -= delta
	elif winding > 0.0:
		winding -= delta * slow
		if winding <= 0.0:
			_wail()
	elif wailing > 0.0:
		wailing -= delta * slow
	elif _hears() and _calm():
		var to := player.global_position - global_position
		to.y = 0.0
		_face(to, delta, 3.0)
		if _call_cd <= 0.0 and mucklings.size() < MAX_MUCKLINGS:
			start_call()
		elif to.length() > 6.0:
			want = to.normalized() * walk_speed * 0.7            # it shuffles after you, very slowly
	else:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			_rest -= delta
			if _rest <= 0.0:
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, wander_radius)
				_rest = randf_range(2.0, 4.5)
		else:
			want = to.normalized() * walk_speed
			_face(to, delta, 2.0)
	want *= slow
	velocity.x = move_toward(velocity.x, want.x, 6.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 6.0 * delta)
	move_and_slide()
	_animate(delta)
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _animate(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var step := sin(_t * 3.2) * clampf(moving / walk_speed, 0.0, 1.0)
	for i in _arms.size():
		_arms[i].rotation.x = step * (0.35 if i == 0 else -0.35) + sin(_t * 1.1 + i) * 0.06
	var swell := 1.0
	var open := 0.18
	if winding > 0.0:
		var k := 1.0 - winding / WIND_UP
		swell = 1.0 + 0.22 * k
		open = 0.18 + 0.4 * k
		head.position.x = sin(_t * 60.0) * 0.02 * k            # shivering with the breath it's taking
	elif wailing > 0.0:
		swell = 1.15 + 0.05 * sin(_t * 30.0)
		open = 0.75
		head.position.x = 0.0
	else:
		head.position.x = 0.0
	var bob := sin(_t * 3.2 * 2.0) * 0.04 * clampf(moving / walk_speed, 0.0, 1.0)
	head.position.y = HEAD_Y + bob
	head.rotation.z = 0.12 + sin(_t * 0.9) * 0.08                # lolling, too heavy to hold straight
	var sc := head.scale.lerp(Vector3.ONE * swell, 1.0 - exp(-10.0 * delta))
	head.scale = sc
	mouth.scale.y = lerpf(mouth.scale.y, open, 1.0 - exp(-12.0 * delta))


func _hears() -> bool:
	if player == null or player.call("is_recovering"):
		return false
	var to := player.global_position - global_position
	return Vector2(to.x, to.z).length() < hear and absf(to.y) < 5.0


func _calm() -> bool:
	if Dialogue.is_active() or player.get("carried") == true:
		return false
	return get_tree().get_nodes_in_group("cutscene_playing").is_empty()


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


# The call ------------------------------------------------------------------------------------------------------------
func start_call() -> void:
	if defeated or winding > 0.0 or wailing > 0.0:
		return
	winding = WIND_UP
	velocity.x = 0.0
	velocity.z = 0.0
	Juice.blip("windup", 0.55, -8.0)


func _wail() -> void:
	if not is_inside_tree():
		return
	wailing = WAIL_TIME
	_call_cd = call_every
	calls += 1
	Juice.blip("wail", randf_range(0.9, 1.05), -2.0)
	Juice.shake(0.12)
	var mouth_at := mouth.global_position
	for k in 3:                                            # rings of sound rolling out (they don't hurt)
		get_tree().create_timer(0.22 * k).timeout.connect(func() -> void:
			if is_inside_tree():
				var r := ShockRing.spawn(get_parent(), Vector3(mouth_at.x, global_position.y, mouth_at.z), 9.0 + k * 3.0,
					eye_colour.lerp(Color(0.8, 0.85, 1.0), 0.5), 0, 1.2, "gust")
				r.name = "Wail Ring")
	Fx.burst(get_parent(), mouth_at, eye_colour, 10, 0.06, 2.5, 0.0, 0.5)
	if not Dialogue.flags.has("bog_wailer_heard"):
		Dialogue.set_flag("bog_wailer_heard")
		Game.message("A Bog Wailer! Its call wakes the Mucklings. Pop it and they melt away.")
	var n := mini(call_count, MAX_MUCKLINGS - mucklings.size())
	for i in n:
		_raise_muckling(i, n)
	called.emit(n)


func _raise_muckling(i: int, of: int) -> void:
	# Most come up out of the mud round it; from the third on, every other one comes up round YOU, so a call really
	# brings a horde in from all sides (Hayden, after playing: "I want them to spawn in")
	var at := Vector3.ZERO
	var round_you := i >= 2 and i % 2 == 0 and player != null and is_instance_valid(player)
	if round_you:
		var a := randf() * TAU
		at = player.global_position + Vector3(sin(a), 0, cos(a)) * randf_range(NEAR_YOU, NEAR_YOU + 2.0)
		var y := _ground_at(at)
		if y < bed_y - 0.2 or y > player.global_position.y + 1.0:
			round_you = false                          # (no ground there, or up on something: come up by the wailer)
		else:
			at.y = y
	if not round_you:
		var a := TAU * (float(i) + randf_range(-0.2, 0.2)) / float(maxi(of, 1)) + visual.rotation.y
		at = global_position + Vector3(sin(a), 0, cos(a)) * randf_range(2.5, 4.5)
		at.y = _ground_at(at)
	at.y = maxf(at.y, bed_y) + 0.3
	var g := make_muckling(get_parent(), at, muck, bed_y, murk_top)
	g.set_meta("wailer", self)
	mucklings.append(g)


static func make_muckling(parent: Node, at: Vector3, muck_cols: Dictionary, bed: float, top: float) -> CharacterBody3D:
	# One Muckling (a little bog Gloop), shared with the swamp's mimics and lurkers (scripts/swamp_dangers.gd). It's
	# happy down on the swamp's bed (a Gloop heads home below the lake basin's height, so it used to sink back to
	# where it came up and sit there hidden under the murk) and it wades with its body up out of the water.
	_made += 1
	var g := MUCKLING.instantiate() as CharacterBody3D
	g.name = "Muckling %d" % _made                       # (numbered, so no two clash and get renamed)
	g.set("respawns", false)
	g.set("size", 0.6)
	g.set("damage", 1)
	g.set("xp_reward", 2)
	g.set("chase_speed", 3.1)
	g.set("sight_range", 18.0)
	g.set("leash_range", 40.0)
	g.set("wander_radius", 3.0)
	g.set("goldness", 0.0)
	g.set("pounce", true)                              # it hops at you, up out of the water onto islands too
	g.set("pounce_range", 4.5)
	g.set("pounce_every", 2.4)
	g.set("pounce_speed", 6.0)
	g.set("low_ground", bed - 2.0)
	g.set("hound", true)
	g.set("wade_top", top)
	g.set("color", muck_cols.get("pop", Color(0.5, 0.8, 0.4)))
	g.add_to_group("mucklings")
	g.position = (parent as Node3D).to_local(at)       # (before it's added: a Gloop takes its home from there)
	parent.add_child(g)
	for m in (g.get("_goo") as Array):
		(m as ShaderMaterial).set_shader_parameter("green", muck_cols.get("green"))
		(m as ShaderMaterial).set_shader_parameter("deep", muck_cols.get("deep"))
	var pop: Color = muck_cols.get("pop", Color(0.5, 0.8, 0.4))
	Fx.burst(parent, at, pop, 14, 0.12, 3.5, -8.0, 0.7)              # a splash of mud as it bursts up
	Fx.burst(parent, at + Vector3(0, 0.4, 0), pop.lightened(0.3), 8, 0.08, 5.0, -10.0, 0.5)
	Audio.play_at("gloop_giggle", at, -4.0, 0.3)
	_rise(g)
	if g.has_method("alert"):
		g.call("alert")
	return g


static func _rise(g: Node3D) -> void:
	# It squeezes up out of the mud: its look starts flat and under, then springs up
	var v := g.get_node_or_null("Visual") as Node3D
	if v == null:
		return
	var sc := v.scale
	v.scale = Vector3(sc.x * 1.4, sc.y * 0.1, sc.z * 1.4)
	var t := g.create_tween()
	t.tween_property(v, "scale", sc, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ground_at(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 6, 0), p + Vector3(0, -6, 0))
	q.exclude = [get_rid()]
	if player:
		q.exclude.append(player.get_rid())
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else p.y


# Bumps and pops ------------------------------------------------------------------------------------------------------
func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if player.velocity.y < 0.5 and feet > global_position.y + STOMP_ABOVE:
		player.call("bounce", STOMP_BOUNCE)
		Juice.hitstop(0.04)
		take_hit(1, (player.global_position - global_position) * Vector3(1, 0, 1))
	elif player.call("is_rolling") or (Game.riding and Vector2(player.velocity.x, player.velocity.z).length() >= 7.0):
		take_hit(1, player.velocity)
		player.call("bounce", 5.0)
	elif not player.call("is_invulnerable"):
		player.call("hurt", damage, global_position)


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	take_hit(maxi(power, 1), dir, true)
	return "hit"


func take_hit(n: int, dir := Vector3.ZERO, bubbled := false) -> void:
	if defeated or _hurt_cd > 0.0:
		return
	_hurt_cd = 0.35
	hp -= n
	winding = 0.0                                          # a hit cuts its call off
	if hp <= 0:
		pop(bubbled)
		return
	_stagger = 0.6
	var push := dir * Vector3(1, 0, 1)
	if push.length() > 0.01:
		velocity += push.normalized() * 2.5
	Fx.burst(get_parent(), head.global_position, head_colour.lightened(0.3), 8, 0.06, 2.5, 0.0, 0.4)
	Juice.blip("squish", 0.7, -6.0)
	var tw := create_tween()
	tw.tween_property(head, "scale", Vector3(1.25, 0.8, 1.25), 0.07)
	tw.tween_property(head, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func pop(bubbled := false) -> void:
	# Silenced: it's gone, and every Muckling it called melts back into the mud
	if defeated:
		return
	defeated = true
	winding = 0.0
	wailing = 0.0
	velocity = Vector3.ZERO
	Game.add_xp(xp_reward)
	_shape.set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	var at := head.global_position
	if bubbled:
		StarBubble.carry_off(self, visual, eye_colour, 2.4)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.3, 0.1, 1.3), 0.2)
		tw.tween_callback(func(): visual.visible = false)
	Fx.burst(get_parent(), at, head_colour.lightened(0.4), 18, 0.08, 3.5, 0.0, 0.7)
	Fx.burst(get_parent(), at, eye_colour, 8, 0.05, 2.0, 0.0, 0.4)
	Juice.blip("pop", 0.6, -4.0)
	for m in mucklings:
		if is_instance_valid(m) and not bool(m.get("defeated")) and m.has_method("_defeat"):
			m.call("_defeat", false)
	mucklings.clear()
	if not Dialogue.flags.has("bog_wailer_popped"):
		Dialogue.set_flag("bog_wailer_popped")
		Game.message("Shh! The Bog Wailer's quiet, and its Mucklings sank back into the mud.")
	popped.emit(self)
	_respawn_left = respawn_time


func _try_respawn() -> void:
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < respawn_clear:
		_respawn_left = 3.0
		return
	defeated = false
	hp = hits
	global_position = home
	visual.visible = true
	visual.scale = Vector3.ONE
	visual.position = Vector3.ZERO
	_shape.set_deferred("disabled", false)
	_hitbox.set_deferred("monitoring", true)
	_call_cd = 3.0
