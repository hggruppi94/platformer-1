extends CharacterBody3D

# A cyber gorilla (a working name: "Glitchback" for the kind, until Hayden names them), from Hayden's drawing (21 Nov
# 2026): "gorilla is going to be an enemy that shoots his blaster at you in the far future". Half fur, half black
# machine, a glowing light-blue blaster for his right forearm, a bolted panel in his head and his back, and a screen in
# his belly with a gold skull on it (models/characters/cyber_gorilla.glb, built by tools/build_cyber_gorilla.py). The
# game never says whose skull it is: no spoilers.
#
# In Lumen City while it's fading (scripts/far_future.gd puts them in; they're gone once it's mended). He plods about
# his patch of the city floor. When he sees you (SIGHT, and nothing in the way) he stops, turns and lifts his blaster:
# arrows on the ground show the way the shot will go (scripts/boss_tell.gd "dash": "Arrows on the ground? Step aside!")
# and the blaster glows brighter, then a fat, slow bolt (scripts/gorilla_bolt.gd) flies along the arrows. Step aside and
# it misses. Too close and he beats his chest instead: a ring across the ground (ShockRing, with a "jump" tell) to jump.
# Kid-safe: every hit is a bump, never more. Three bubbles (a big bubble is three), a stomp on his head, a roll or a
# ram on your ride each knock a bit off him (HITS); then he fizzles out in sparks, and comes back a while later.

signal popped(who: Node3D)

const TELL := preload("res://scripts/boss_tell.gd")
const BOLT := preload("res://scripts/gorilla_bolt.gd")
const MODEL := "res://models/characters/cyber_gorilla.glb"
const CYBER := Color(0.4, 0.85, 1.0)
const RED := Color(1.0, 0.2, 0.15)
const STOMP_BOUNCE := 9.0
const HEAD_Y := 1.75                       # his head, from his feet: a landing above this is a stomp

@export var hits := 3
@export var damage := 1
@export var xp_reward := 12
@export var sight := 16.0
@export var wander_radius := 6.0
@export var leash := 20.0
@export var walk_speed := 1.5
@export var keep_away := 8.0               # he likes to shoot from about this far
@export var shoot_every := 3.2             # seconds between shots (after the bolt flies)
@export var beat_range := 3.0              # closer than this and he beats his chest instead
@export var beat_every := 4.0
@export var respawns := true
@export var respawn_time := 45.0
@export var respawn_clear := 18.0

var home := Vector3.ZERO
var defeated := false
var hp := 3
var visual: Node3D                         # "Visual": the model (StarBubble and the Plushinator look for it)
var player: CharacterBody3D
var aiming := 0.0                          # >0 while he lifts the blaster (the arrows are showing)
var beating := 0.0                         # >0 while he winds up a chest beat
var shots := 0                             # bolts fired (for tests)
var _aim_dir := Vector3.FORWARD
var _aim_at := Vector3.ZERO                               # where she stood (her middle) when he took aim
var _shoot_cd := 2.0
var _beat_cd := 2.0
var _target := Vector3.ZERO
var _rest := 0.0
var _hurt_cd := 0.0
var _stagger := 0.0
var _anim: AnimationPlayer
var _playing := ""
var _glow: StandardMaterial3D              # his blaster's glow (the model's "Cyber Glow"), brighter while aiming
var _glow_base := 6.0
var _hand := -1
var _skel: Skeleton3D
var _shapes: Array[CollisionShape3D] = []
var _hitbox: Area3D
var _respawn_left := -1.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("cyber_gorillas")
	home = global_position
	_target = home
	hp = hits
	_rest = randf_range(0.5, 2.0)
	_shoot_cd = randf_range(1.5, 3.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 2.0
	cs.shape = cap
	cs.position.y = 1.0
	add_child(cs)
	_shapes.append(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.75
	hcap.height = 2.3
	hcs.shape = hcap
	hcs.position.y = 1.05
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var packed := load(MODEL) as PackedScene
	if packed:
		var m := packed.instantiate() as Node3D
		m.name = "Model"
		visual.add_child(m)
		_anim = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_skel = m.find_child("*", true, false) as Skeleton3D
		for k in m.find_children("*", "Skeleton3D", true, false):
			_skel = k as Skeleton3D
		if _skel:
			_hand = _skel.find_bone("hand.R")
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh := (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var mt := mesh.surface_get_material(i) as StandardMaterial3D
				if mt and mt.resource_name == "Cyber Glow":
					_glow = mt.duplicate() as StandardMaterial3D
					_glow_base = _glow.emission_energy_multiplier
					(mi as MeshInstance3D).set_surface_override_material(i, _glow)
	if _anim:
		for a in ["idle", "walk"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("idle")


func _play(a: String, speed := 1.0) -> void:
	if _anim == null or a == _playing or not _anim.has_animation(a):
		return
	_playing = a
	_anim.play(a, 0.2, speed)


func _physics_process(delta: float) -> void:
	if defeated:
		if _respawn_left >= 0.0:
			_respawn_left -= delta
			if _respawn_left < 0.0:
				_try_respawn()
		return
	_find_player()
	_shoot_cd = maxf(_shoot_cd - delta, 0.0)
	_beat_cd = maxf(_beat_cd - delta, 0.0)
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	var slow := Arsenal.slow(self)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var want := Vector3.ZERO
	var sees := _sees_player()
	if _stagger > 0.0:
		_stagger -= delta
	elif aiming > 0.0:
		aiming -= delta * slow
		_face(_aim_dir, delta, 10.0)
		if aiming <= 0.0:
			_fire()
	elif beating > 0.0:
		beating -= delta * slow
		if beating <= 0.0:
			_beat()
	elif sees and _calm():
		var to := player.global_position - global_position
		to.y = 0.0
		var d := to.length()
		_face(to, delta, 6.0)
		if d < beat_range and _beat_cd <= 0.0:
			_start_beat()
		elif _shoot_cd <= 0.0 and d > beat_range:
			_start_aim(to, player.global_position)
		elif d > keep_away + 2.0 and _flat(global_position - home) < leash:
			want = to.normalized() * walk_speed
		elif d < keep_away - 3.0:
			want = -to.normalized() * walk_speed * 0.7
	else:
		# Plodding about his patch
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.6:
			_rest -= delta
			if _rest <= 0.0:
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, wander_radius)
				_rest = randf_range(1.5, 3.5)
		else:
			want = to.normalized() * walk_speed * 0.8
			_face(to, delta, 4.0)
	want *= slow
	velocity.x = move_toward(velocity.x, want.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 12.0 * delta)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	if aiming > 0.0 or (_playing == "blast" and _anim and _anim.is_playing()):
		pass
	elif beating > 0.0 or (_playing == "chest_beat" and _anim and _anim.is_playing()):
		pass
	else:
		_play("walk" if moving else "idle")
	if _glow:
		var k := 1.0 if aiming <= 0.0 else 1.0 + 2.5 * (1.0 - aiming / maxf(TELL.lead(), 0.01))
		_glow.emission_energy_multiplier = _glow_base * k
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _calm() -> bool:
	# Never mid-talk, mid-cutscene, or while the player's being carried somewhere
	if Dialogue.is_active() or player.get("carried") == true:
		return false
	return get_tree().get_nodes_in_group("cutscene_playing").is_empty()


func _sees_player() -> bool:
	if player == null or player.call("is_recovering"):
		return false
	var to := player.global_position - global_position
	if Vector2(to.x, to.z).length() > sight or absf(to.y) > 3.0:
		return false
	if _flat(player.global_position - home) > leash + sight:
		return false
	# Nothing solid in the way (he won't shoot through a wall)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.4, 0), player.global_position + Vector3(0, 0.6, 0))
	q.exclude = [get_rid(), player.get_rid()]
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


func _start_aim(to: Vector3, at := Vector3.ZERO) -> void:
	_aim_dir = to.normalized()
	_aim_at = at if at != Vector3.ZERO else global_position + to + Vector3(0, 0.8, 0)
	aiming = TELL.lead()
	velocity.x = 0.0
	velocity.z = 0.0
	_play("blast")
	if _anim:
		_anim.seek(0.0, true)
	TELL.warn(self, "dash", minf(to.length() + 4.0, 18.0), CYBER, aiming,
		{"dir": _aim_dir, "visual": visual, "head": HEAD_Y + 0.9, "ground_y": global_position.y})
	Juice.blip("whoosh", 1.4, -10.0)


func muzzle() -> Vector3:
	# Where the bolt comes out: just past his blaster hand, at chest height, along the way he's aiming
	var at := global_position + Vector3(0, 1.25, 0)
	if _skel and _hand >= 0:
		var h := _skel.global_transform * _skel.get_bone_global_pose(_hand)
		at = Vector3(h.origin.x, maxf(h.origin.y, global_position.y + 1.0), h.origin.z)
	return at + _aim_dir * 0.5


func _fire() -> void:
	if not is_inside_tree():
		return
	var b: Area3D = BOLT.new()
	b.name = "Gorilla Bolt"
	# His blaster's up at his shoulder, well over a kid's head, so the bolt tips down to where she stood when he took
	# aim. It still flies straight along the arrows he showed, so stepping off them always dodges it.
	var from := muzzle()
	var aim := (_aim_at - from)
	var flat := Vector2(aim.x, aim.z).length()
	var dir := _aim_dir
	if flat > 1.0:
		dir = (_aim_dir * flat + Vector3(0, aim.y, 0)).normalized()
	b.set("dir", dir)
	b.set("damage", damage)
	b.set("shooter", self)
	get_parent().add_child(b)
	b.global_position = from
	shots += 1
	_shoot_cd = shoot_every
	Fx.burst(get_parent(), b.global_position, CYBER, 8, 0.05, 2.5, 0.0, 0.3)
	Juice.blip("pop", 0.6, -6.0)


func _start_beat() -> void:
	beating = TELL.lead()
	_beat_cd = beat_every
	velocity.x = 0.0
	velocity.z = 0.0
	_play("chest_beat")
	if _anim:
		_anim.seek(0.0, true)
	TELL.warn(self, "jump", beat_range * 1.6, RED, beating, {"visual": visual, "head": HEAD_Y + 0.9})


func _beat() -> void:
	if not is_inside_tree():
		return
	ShockRing.spawn(get_parent(), global_position, beat_range * 1.6, RED, damage, 0.6, "energy")
	Juice.shake(0.12)
	Juice.blip("thud", 0.7, -4.0)
	_shoot_cd = maxf(_shoot_cd, 1.2)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)              # touching is the hitbox's job
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if player.velocity.y < 0.5 and feet > global_position.y + HEAD_Y - 0.4:
		player.call("bounce", STOMP_BOUNCE)
		Juice.hitstop(0.04)
		take_hit(1, (player.global_position - global_position) * Vector3(1, 0, 1))
	elif player.call("is_rolling") or (Game.riding and _flat(player.velocity) >= 7.0):
		take_hit(1, player.velocity)
		player.call("bounce", 5.0)
	elif not player.call("is_invulnerable"):
		player.call("hurt", damage, global_position)


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	# A Star Popper bubble (or any gadget, through Arsenal.hit): a big bubble counts for three
	if defeated:
		return "miss"
	take_hit(maxi(power, 1), dir, true)
	return "hit"


func take_hit(n: int, dir := Vector3.ZERO, bubbled := false) -> void:
	if defeated or _hurt_cd > 0.0:
		return
	_hurt_cd = 0.35
	hp -= n
	aiming = 0.0                                          # a hit spoils his aim (and the bolt never comes)
	beating = 0.0
	var t: Variant = get_meta("boss_tell") if has_meta("boss_tell") else null
	if t != null and is_instance_valid(t):
		(t as Node).queue_free()
	if hp <= 0:
		pop(bubbled)
		return
	_stagger = 0.5
	var push := dir * Vector3(1, 0, 1)
	if push.length() > 0.01:
		velocity += push.normalized() * 3.0
	Fx.burst(get_parent(), global_position + Vector3(0, 1.4, 0), CYBER, 8, 0.05, 2.5, 0.0, 0.3)
	Juice.blip("bonk", 0.8, -6.0)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.06)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func pop(bubbled := false) -> void:
	# He fizzles out of time in a shower of light-blue sparks
	if defeated:
		return
	defeated = true
	aiming = 0.0
	beating = 0.0
	velocity = Vector3.ZERO
	Game.add_xp(xp_reward)
	for cs in _shapes:
		cs.set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	var at := global_position + Vector3(0, 1.2, 0)
	if bubbled:
		StarBubble.carry_off(self, visual, CYBER, 2.0)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.4, 0.1, 1.4), 0.15)
		tw.tween_callback(func(): visual.visible = false)
	Fx.burst(get_parent(), at, CYBER, 16, 0.06, 3.5, 0.0, 0.6)
	Fx.burst(get_parent(), at, RED, 6, 0.05, 2.0, 0.0, 0.4)
	Juice.blip("chime", 1.2, -6.0)
	popped.emit(self)
	if respawns:
		_respawn_left = respawn_time
	else:
		get_tree().create_timer(2.5).timeout.connect(queue_free)


func fizzle_away() -> void:
	# Gone for good (the city's mended): a puff of sparks, no reward
	respawns = false
	if not defeated and is_inside_tree():
		Fx.burst(get_parent(), global_position + Vector3(0, 1.2, 0), CYBER, 16, 0.06, 3.5, 0.0, 0.6)
	queue_free()


func _try_respawn() -> void:
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < respawn_clear:
		_respawn_left = 3.0
		return
	global_position = home
	velocity = Vector3.ZERO
	defeated = false
	hp = hits
	_hurt_cd = 0.0
	for cs in _shapes:
		cs.set_deferred("disabled", false)
	_hitbox.set_deferred("monitoring", true)
	visual.visible = true
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
