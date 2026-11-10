extends CharacterBody3D

# A shadow ghost: Dark Hollow's own little enemy (plan item 21). An inky blob of shadow with a wispy tail and two big
# glowing eyes, floating a little off the ground. In Dark Hollow the shadows are eating moments of time, and the
# ghosts are lost bits of time that have gone dark: popping one turns it back into a little wisp of light.
# Our own design (the mood of a shadowy heartless-ish creature only, never a copy of anyone's enemy).
#
# It skitters (quick little dashes, then a pause), flickers (fades almost out for a blink now and then) and sometimes
# dodges a bubble by flickering sideways. It drifts after you when you're near and bumps you if it touches you (a
# bump, like a Gloop: never more). A stomp, a roll, a ram on your ride or a Star Popper bubble pops it.
# Kid-safe: big friendly eyes, no teeth, and it pops into light with a little chime.
#
# Built in code (no scene). Made by scripts/dark_hollow.gd (the glade's eight, which don't come back once popped) and
# scripts/the_hush.gd (the ones it calls up).

signal popped(ghost: Node3D)

const STOMP_BOUNCE := 8.0
const BODY := Color(0.07, 0.05, 0.13)
const SHEEN := Color(0.32, 0.2, 0.55)
const EYES := Color(0.75, 1.0, 1.0)
const WISP := Color(0.75, 0.95, 1.0)

@export var damage := 1
@export var xp_reward := 4
@export var wander_radius := 4.0
@export var sight_range := 9.0
@export var leash_range := 16.0
@export var dash_speed := 6.0                 # a skitter: quick...
@export var dash_time := 0.35                 # ...and short
@export var drift_speed := 1.6                # between skitters
@export var dodge_chance := 0.3               # a bubble: sometimes it flickers aside
@export var hover := 0.9                      # how high it floats over the ground
@export var size := 1.0

var home := Vector3.ZERO
var defeated := false
var visual: Node3D                            # (StarBubble squashes "visual" when a bubble hits)
var player: CharacterBody3D
var _target := Vector3.ZERO
var _dash := 0.0
var _rest := 0.0
var _dir := Vector3.ZERO
var _t := 0.0
var _flicker := 0.0
var _next_flicker := 2.0
var _dodge_wait := 0.0
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _hitbox: Area3D
var _ground_y := 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("shadow_ghosts")
	home = global_position
	_ground_y = global_position.y
	_target = home
	_t = randf() * 10.0
	_next_flicker = randf_range(1.5, 4.0)
	_rest = randf_range(0.3, 1.2)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.45 * size
	cs.shape = sp
	cs.position.y = hover * size
	add_child(cs)
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
	visual.name = "Visual"
	add_child(visual)
	_body_mat = (visual.get_node("Body") as MeshInstance3D).material_override as StandardMaterial3D
	_eye_mat = (visual.get_node("EyeL") as MeshInstance3D).material_override as StandardMaterial3D


static func model(s := 1.0) -> Node3D:
	# The look, shared with the Hush (scripts/the_hush.gd, much bigger): a soft teardrop of shadow, a wispy tail that
	# fades out, little stubby arms and two big round glowing eyes. Each one gets its own materials (it flickers).
	var g := Node3D.new()
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(BODY, 0.92)
	body_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_m.roughness = 0.4
	body_m.rim_enabled = true
	body_m.rim = 0.8
	body_m.rim_tint = 0.9
	body_m.emission_enabled = true
	body_m.emission = SHEEN
	body_m.emission_energy_multiplier = 0.25
	var eye_m := StandardMaterial3D.new()
	eye_m.albedo_color = EYES
	eye_m.emission_enabled = true
	eye_m.emission = EYES
	eye_m.emission_energy_multiplier = 2.2
	var pupil_m := StandardMaterial3D.new()
	pupil_m.albedo_color = Color(0.1, 0.12, 0.25)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var sm := SphereMesh.new()
	sm.radius = 0.45 * s
	sm.height = 1.0 * s
	body.mesh = sm
	body.material_override = body_m
	body.position.y = 0.95 * s
	g.add_child(body)
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4 * s
	cm.bottom_radius = 0.02 * s
	cm.height = 0.75 * s
	cm.radial_segments = 10
	tail.mesh = cm
	tail.material_override = body_m
	tail.position.y = 0.42 * s
	g.add_child(tail)
	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := SphereMesh.new()
		am.radius = 0.12 * s
		am.height = 0.2 * s
		arm.mesh = am
		arm.material_override = body_m
		arm.position = Vector3(side * 0.44 * s, 0.82 * s, 0.08 * s)
		g.add_child(arm)
		var eye := MeshInstance3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		var em := SphereMesh.new()
		em.radius = 0.13 * s
		em.height = 0.22 * s
		eye.mesh = em
		eye.material_override = eye_m
		eye.position = Vector3(side * 0.16 * s, 1.08 * s, 0.38 * s)
		g.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.055 * s
		pm.height = 0.08 * s
		pupil.mesh = pm
		pupil.material_override = pupil_m
		pupil.position = Vector3(side * 0.15 * s, 1.07 * s, 0.49 * s)
		g.add_child(pupil)
	return g


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	_dodge_wait = maxf(_dodge_wait - delta, 0.0)
	var chasing := false
	if player and not player.call("is_recovering"):
		var to_p := player.global_position - global_position
		if Vector2(to_p.x, to_p.z).length() < sight_range and absf(to_p.y) < 4.0 \
				and _flat(player.global_position - home) < leash_range:
			chasing = true
			_target = player.global_position
	# Skitter: a quick dash towards where it's going, a pause, another dash
	if _dash > 0.0:
		_dash -= delta
	else:
		_rest -= delta
		if _rest <= 0.0:
			if not chasing and (_flat(_target - global_position) < 0.6 or randf() < 0.5):
				var a := randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
			var to := _target - global_position
			to.y = 0
			var side := Vector3(-to.z, 0, to.x).normalized() * randf_range(-0.5, 0.5)    # zig-zaggy
			_dir = (to.normalized() + side).normalized() if to.length() > 0.2 else Vector3.ZERO
			_dash = dash_time
			_rest = randf_range(0.25, 0.7) if chasing else randf_range(0.6, 1.6)
	var speed := dash_speed if _dash > 0.0 else drift_speed * (0.5 if not chasing else 1.0)
	var want := _dir * speed * Arsenal.slow(self)
	velocity.x = move_toward(velocity.x, want.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 30.0 * delta)
	# Float at its height over the ground it started on, bobbing a little
	var bob := sin(_t * 2.4) * 0.12 * (0.3 if Settings.reduce_motion else 1.0)
	velocity.y = (_ground_y + bob - global_position.y) * 4.0
	move_and_slide()
	if Vector2(velocity.x, velocity.z).length() > 0.3:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(velocity.x, velocity.z), 1.0 - exp(-10.0 * delta))
	if player and chasing:                                      # eyes on you
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	_animate(delta)
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _animate(delta: float) -> void:
	# The tail sways and the body wobbles; now and then it flickers almost out, like a candle in a draught
	var tail := visual.get_node("Tail") as Node3D
	tail.rotation.z = sin(_t * 5.0) * 0.25
	tail.rotation.x = -clampf(Vector2(velocity.x, velocity.z).length() * 0.08, 0.0, 0.5)
	var body := visual.get_node("Body") as Node3D
	var w := 1.0 + sin(_t * 3.1) * 0.05
	body.scale = Vector3(w, 2.0 - w, w)
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_flicker = 0.35
		_next_flicker = randf_range(2.0, 5.0)
	var alpha := 0.92
	if _flicker > 0.0:
		_flicker -= delta
		alpha = 0.92 - 0.75 * sin(_flicker / 0.35 * PI) * (0.4 if Settings.reduce_flashing else 1.0)
	_body_mat.albedo_color.a = alpha
	_eye_mat.emission_energy_multiplier = 2.2 * clampf(alpha + 0.2, 0.3, 1.0)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)                   # you pass through; touching is the hitbox's job
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
	# A bubble. Now and then it flickers aside at the last moment and the bubble pops on nothing.
	if defeated:
		return "miss"
	if _dodge_wait <= 0.0 and randf() < dodge_chance:
		_dodge_wait = 2.5
		dodge(dir)
		return "miss"
	pop(true)
	return "hit"


func dodge(dir: Vector3) -> void:
	# Flicker sideways out of the way
	var side := Vector3(-dir.z, 0, dir.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	global_position += side * 1.6
	_flicker = 0.35
	Fx.burst(get_parent(), global_position + Vector3(0, hover * size, 0), SHEEN, 6, 0.05, 1.2, 0.0, 0.3)
	Juice.blip("whoosh", 1.6, -12.0)


func pop(bubbled := false) -> void:
	# Pop! The shadow bursts and a little wisp of light (the lost moment) floats up out of it
	if defeated:
		return
	defeated = true
	velocity = Vector3.ZERO
	Game.add_xp(xp_reward)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	var at := global_position + Vector3(0, hover * size, 0)
	if bubbled:
		StarBubble.carry_off(self, visual, WISP, 1.0 * size)
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.6, 0.1, 1.6) * size, 0.12)
		tw.tween_callback(func(): visual.visible = false)
	Fx.burst(get_parent(), at, WISP, 14, 0.06, 2.5, -0.5, 0.8)
	Juice.blip("chime", 1.5, -8.0)
	_wisp(at)
	popped.emit(self)
	get_tree().create_timer(2.5).timeout.connect(queue_free)


func _wisp(at: Vector3) -> void:
	# The lost moment, free: a little ball of light that floats up and fades
	var w := MeshInstance3D.new()
	w.name = "Wisp"
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	w.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = WISP
	m.emission_enabled = true
	m.emission = WISP
	m.emission_energy_multiplier = 3.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w.material_override = m
	get_parent().add_child(w)
	w.global_position = at
	var tw := w.create_tween()
	tw.tween_property(w, "global_position", at + Vector3(randf_range(-0.6, 0.6), 4.0, randf_range(-0.6, 0.6)), 1.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 1.8).set_delay(0.6)
	tw.tween_callback(w.queue_free)
