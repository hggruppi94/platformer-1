extends CharacterBody3D

# A Fizzler: a little crackling ball of static with one big eye, like a TV that's lost its channel and grown legs (no
# legs, it floats). Hayden, 12 Nov 2026: "I want to make more enemies"; the story's "static wisps", the little bits of
# static that come out of the cracks. (The game never says whose they are: no spoilers.)
#
# It zips about in short straight dashes with a pause between (bzzt... bzzt...), and when it gets close it crackles up
# brighter and lets off a little ring of static across the ground (scripts/shock_ring.gd: jump it). Now and then a
# bubble makes it blink sideways out of the way with a fizz. A stomp, a roll, a ram on your ride or a Star Popper bubble
# pops it into sparks. Kid-safe: a bump, never more, and it pops with a cheerful "bzip!".
#
# Built in code (no scene): FIZZLER.new(). Placed in the Void's Static Field by scripts/wilds.gd (they come back after
# a while, like Gloops) and sent in by the Star Arena (scripts/arena_level.gd, `respawns` false). Their boss, Big Buzz
# (scripts/big_buzz.gd), only lives in the Star Arena.

signal popped(who: Node3D)

const STOMP_BOUNCE := 8.0
const CORE := Color(0.18, 0.08, 0.3)
const STATIC := Color(0.45, 0.95, 1.0)
const GLITCH := Color(1.0, 0.35, 0.85)

@export var size := 1.0
@export var damage := 1
@export var xp_reward := 4
@export var wander_radius := 7.0
@export var sight_range := 12.0
@export var leash_range := 24.0
@export var zip_speed := 7.5                  # a zip: quick...
@export var zip_time := 0.28                  # ...and short
@export var rest_time := 0.8                  # crackling between zips
@export var zap_range := 3.2                  # this close and it crackles up for a zap
@export var zap_every := 3.5
@export var blink_chance := 0.25              # a bubble: sometimes it blinks aside
@export var hover := 1.0
@export var respawns := true
@export var respawn_time := 40.0
@export var respawn_clear := 15.0

var home := Vector3.ZERO
var defeated := false
var visual: Node3D                            # (StarBubble squashes "visual" when a bubble hits)
var player: CharacterBody3D
var charging := 0.0                           # >0 while it crackles up for a zap
var _target := Vector3.ZERO
var _zip := 0.0
var _rest := 0.0
var _dir := Vector3.ZERO
var _t := 0.0
var _zap_cd := 2.0
var _blink_wait := 0.0
var _ground_y := 0.0
var _shell_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _bolts: Array[Node3D] = []
var _hitbox: Area3D
var _shapes: Array[CollisionShape3D] = []
var _respawn_left := -1.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("fizzlers")
	home = global_position
	_ground_y = global_position.y
	_target = home
	_t = randf() * 10.0
	_rest = randf_range(0.2, rest_time)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.4 * size
	cs.shape = sp
	cs.position.y = hover * size
	add_child(cs)
	_shapes.append(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hsp := SphereShape3D.new()
	hsp.radius = 0.6 * size
	hcs.shape = hsp
	hcs.position.y = hover * size
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = model(size)
	add_child(visual)
	_shell_mat = visual.get_meta("shell")
	_eye_mat = visual.get_meta("eye")
	for b in visual.get_node("Bolts").get_children():
		_bolts.append(b)


static func model(s: float) -> Node3D:
	# A dark core inside a crackling see-through shell of static, one big eye, and little zig-zag sparks flicking
	# round it. Its middle is `hover` up (the shell is drawn round 1.0 * s).
	var g := Node3D.new()
	g.name = "Visual"
	var core := MeshInstance3D.new()
	core.name = "Core"
	var cm := SphereMesh.new()
	cm.radius = 0.32 * s
	cm.height = 0.64 * s
	core.mesh = cm
	var core_m := StandardMaterial3D.new()
	core_m.albedo_color = CORE
	core_m.emission_enabled = true
	core_m.emission = Color(0.35, 0.1, 0.5)
	core_m.emission_energy_multiplier = 0.6
	core_m.roughness = 0.4
	core.material_override = core_m
	core.position.y = 1.0 * s
	g.add_child(core)
	var shell := MeshInstance3D.new()
	shell.name = "Shell"
	var sm := SphereMesh.new()
	sm.radius = 0.46 * s
	sm.height = 0.92 * s
	sm.radial_segments = 10                   # chunky facets read as fuzz
	sm.rings = 6
	shell.mesh = sm
	var shell_m := StandardMaterial3D.new()
	shell_m.albedo_color = Color(STATIC, 0.35)
	shell_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell_m.emission_enabled = true
	shell_m.emission = STATIC
	shell_m.emission_energy_multiplier = 1.4
	shell_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = shell_m
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.position.y = 1.0 * s
	g.add_child(shell)
	g.set_meta("shell", shell_m)
	# One big friendly eye
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = Color(1, 1, 1)
	eye_m.emission_enabled = true
	eye_m.emission = Color(0.9, 1.0, 1.0)
	eye_m.emission_energy_multiplier = 0.8
	var eye := MeshInstance3D.new()
	eye.name = "Eye"
	var em := SphereMesh.new()
	em.radius = 0.17 * s
	em.height = 0.3 * s
	eye.mesh = em
	eye.material_override = eye_m
	eye.position = Vector3(0, 1.05 * s, 0.3 * s)
	g.add_child(eye)
	g.set_meta("eye", eye_m)
	var pupil := MeshInstance3D.new()
	pupil.name = "Pupil"
	var pm := SphereMesh.new()
	pm.radius = 0.075 * s
	pm.height = 0.12 * s
	pupil.mesh = pm
	var pupil_m := StandardMaterial3D.new()
	pupil_m.albedo_color = Color(0.1, 0.05, 0.2)
	pupil.material_override = pupil_m
	pupil.position = Vector3(0, 1.06 * s, 0.44 * s)
	g.add_child(pupil)
	# Sparks: little zig-zags (two thin bars each) that flick round the shell
	var bolts := Node3D.new()
	bolts.name = "Bolts"
	bolts.position.y = 1.0 * s
	g.add_child(bolts)
	var bolt_m := StandardMaterial3D.new()
	bolt_m.albedo_color = Color(1, 1, 1)
	bolt_m.emission_enabled = true
	bolt_m.emission = STATIC
	bolt_m.emission_energy_multiplier = 3.0
	bolt_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 5:
		var b := Node3D.new()
		b.name = "Bolt%d" % i
		for k in 2:
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 0.2, 0.03) * s
			bar.mesh = bm
			bar.material_override = bolt_m if i % 2 == 0 else _glitch_mat()
			bar.position = Vector3(0.05 * s * (1 if k == 0 else -1), 0.08 * s * (k * 2 - 1), 0)
			bar.rotation.z = 0.6 * (1 if k == 0 else -1)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.add_child(bar)
		var a := i * TAU / 5.0
		b.position = Vector3(cos(a), sin(a * 2.0) * 0.4, sin(a)) * 0.52 * s
		bolts.add_child(b)
	return g


static func _glitch_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = GLITCH
	m.emission_enabled = true
	m.emission = GLITCH
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _physics_process(delta: float) -> void:
	if defeated:
		if _respawn_left >= 0.0:
			_respawn_left -= delta
			if _respawn_left < 0.0:
				_try_respawn()
		return
	_find_player()
	_t += delta
	_blink_wait = maxf(_blink_wait - delta, 0.0)
	_zap_cd = maxf(_zap_cd - delta, 0.0)
	var chasing := false
	if player and not player.call("is_recovering"):
		var to_p := player.global_position - global_position
		if Vector2(to_p.x, to_p.z).length() < sight_range and absf(to_p.y) < 4.0 \
				and _flat(player.global_position - home) < leash_range:
			chasing = true
			_target = player.global_position
	# Crackling up for a zap: it stops still and fizzes brighter, then lets the ring go
	if charging > 0.0:
		charging -= delta
		velocity = Vector3.ZERO
		if charging <= 0.0:
			_zap()
	elif chasing and _zap_cd <= 0.0 and _flat(player.global_position - global_position) < zap_range * size:
		charging = 0.8
		_zap_cd = zap_every
		Juice.blip("whoosh", 2.2, -14.0)
	else:
		if _zip > 0.0:
			_zip -= delta
		else:
			_rest -= delta
			if _rest <= 0.0:
				if not chasing and (_flat(_target - global_position) < 0.8 or randf() < 0.5):
					var a := randf() * TAU
					_target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
				var to := _target - global_position
				to.y = 0
				_dir = to.normalized() if to.length() > 0.3 else Vector3.ZERO
				_zip = zip_time
				_rest = rest_time * randf_range(0.7, 1.2) * (0.7 if chasing else 1.3)
		var speed := zip_speed if _zip > 0.0 else 0.3
		var want := _dir * speed * Arsenal.slow(self)
		velocity.x = move_toward(velocity.x, want.x, 60.0 * delta)
		velocity.z = move_toward(velocity.z, want.z, 60.0 * delta)
	var bob := sin(_t * 3.0) * 0.1 * (0.3 if Settings.reduce_motion else 1.0)
	velocity.y = (_ground_y + bob - global_position.y) * 4.0
	move_and_slide()
	if player and chasing:
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
	elif Vector2(velocity.x, velocity.z).length() > 0.5:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-10.0 * delta))
	_animate(delta)
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _animate(_delta: float) -> void:
	# The sparks flick round, the shell fizzes (brighter while charging), the whole thing jitters a little
	var k := 1.0 if charging <= 0.0 else 2.2
	var jitter := 0.0 if Settings.reduce_motion else 0.02 * k
	visual.position = Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), 0)
	var spin := _t * (4.0 + 6.0 * (k - 1.0))
	for i in _bolts.size():
		var a := spin + i * TAU / _bolts.size()
		_bolts[i].position = Vector3(cos(a), sin(a * 1.7 + i) * 0.4, sin(a)) * 0.52 * size
		_bolts[i].rotation.y = -a
		_bolts[i].visible = Settings.reduce_flashing or fmod(_t * 13.0 + i * 0.37, 1.0) > 0.25
	if _shell_mat:
		var flick := 0.5 + 0.5 * sin(_t * 31.0) if not Settings.reduce_flashing else 0.5
		_shell_mat.emission_energy_multiplier = (1.0 + 0.8 * flick) * k
		_shell_mat.albedo_color = Color(STATIC.lerp(GLITCH, 0.0 if charging <= 0.0 else 0.5), 0.3 + 0.1 * k)
	var shell := visual.get_node("Shell") as Node3D
	var w := 1.0 + sin(_t * 17.0) * 0.04 * k
	shell.scale = Vector3(w, 2.0 - w, w)


func _zap() -> void:
	# A little ring of static across the ground (jump it)
	if not is_inside_tree():
		return
	var at := Vector3(global_position.x, _ground_y, global_position.z)
	ShockRing.spawn(get_parent(), at, zap_range * size * 1.4, STATIC, damage, 0.55)
	Fx.burst(get_parent(), global_position + Vector3(0, hover * size, 0), STATIC, 8, 0.05, 3.0, 0.0, 0.3)
	Juice.blip("buzz", 2.4, -8.0)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)                  # you pass through; touching is the hitbox's job
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if player.velocity.y < 0.5 and feet > global_position.y + hover * size * 0.6:
		player.call("bounce", STOMP_BOUNCE)
		Juice.hitstop(0.04)
		pop()
	elif player.call("is_rolling") or (Game.riding and _flat(player.velocity) >= 7.0):
		pop()
	elif not player.call("is_invulnerable"):
		player.call("hurt", damage, global_position)


func shot(_power: int, _point: Vector3, dir: Vector3) -> String:
	# A bubble. Sometimes it blinks aside at the last moment, fizz!
	if defeated:
		return "miss"
	if _blink_wait <= 0.0 and randf() < blink_chance:
		_blink_wait = 2.5
		blink(dir)
		return "miss"
	pop(true)
	return "hit"


func blink(dir: Vector3) -> void:
	var side := Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	global_position += side * 1.8
	Fx.burst(get_parent(), global_position + Vector3(0, hover * size, 0), GLITCH, 6, 0.05, 1.5, 0.0, 0.3)
	Juice.blip("whoosh", 1.8, -12.0)


func pop(bubbled := false) -> void:
	# Bzip! It bursts into sparks
	if defeated:
		return
	defeated = true
	charging = 0.0
	velocity = Vector3.ZERO
	Game.add_xp(xp_reward)
	for cs in _shapes:
		cs.set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	var at := global_position + Vector3(0, hover * size, 0)
	if bubbled:
		StarBubble.carry_off(self, visual, STATIC, 1.0 * size)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.6, 0.1, 1.6) * size, 0.12)
		tw.tween_callback(func(): visual.visible = false)
	Fx.burst(get_parent(), at, STATIC, 12, 0.05, 3.0, 0.0, 0.5)
	Fx.burst(get_parent(), at, GLITCH, 6, 0.05, 2.0, 0.0, 0.4)
	Juice.blip("chime", 2.0, -8.0)
	popped.emit(self)
	if respawns:
		_respawn_left = respawn_time
	else:
		get_tree().create_timer(2.5).timeout.connect(queue_free)


func _try_respawn() -> void:
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < respawn_clear:
		_respawn_left = 3.0
		return
	global_position = home
	velocity = Vector3.ZERO
	defeated = false
	for cs in _shapes:
		cs.set_deferred("disabled", false)
	_hitbox.set_deferred("monitoring", true)
	visual.visible = true
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
