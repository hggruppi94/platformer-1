extends CharacterBody3D

# The Crocodillo: a hunched crocodile-armadillo (scene built by tools/build_crocodillo.gd).
#
# It lurks near its home spot. When it spots Nina it snaps its jaws, curls up into an armoured ball and rolls at her.
# While it's a ball it can't be hurt: jumping on it just bounces her off the shell, and touching it hurts. After a
# roll it uncurls and sits there dizzy, stars round its head, and that's the time to stomp on its head (two stomps).
# Rolling into it or ramming it on the skateboard works too, but only while it isn't curled up.
# The Star Popper's bubbles (scripts/star_popper.gd) boing off its rolling shell, but out of its ball one makes it dizzy,
# and two bubbles (or one big one) pop it away. It comes back after a while, once Nina has walked away. Expects: CollisionShape3D, Hitbox (Area3D),
# Visual/Body (with LegL, LegR, ArmL, ArmR, Head/Jaw, Tail), Visual/Ball, Visual/Stars.

enum State { WANDER, STALK, CURL, ROLL, DIZZY }

@export_group("Stats")
@export var stomps_to_defeat := 2
@export var damage := 3
@export var xp_reward := 15

@export_group("Behaviour")
@export var wander_radius := 7.0
@export var sight_range := 13.0
@export var leash_range := 26.0
@export var wander_speed := 1.1
@export var stalk_speed := 2.2                 # slow on its feet: Nina (5) can always walk away
@export var roll_speed := 9.0
@export var roll_time := 2.0
@export var dizzy_time := 2.8
@export var roll_cooldown := 2.5
@export var respawn_time := 45.0
@export var ram_speed := 7.0

const STOMP_BOUNCE := 8.0
const SHELL_BOUNCE := 9.5
const LOW_GROUND := -0.25                      # the lake bed: it stays on dry land

var home := Vector3.ZERO
var target := Vector3.ZERO
var hits := 0
var defeated := false
var state := State.WANDER
var player: Player

var _t := 0.0
var _state_t := 0.0                            # time left in CURL, ROLL, DIZZY
var _cooldown := 0.0
var _retarget := 0.0
var _roll_dir := Vector3.FORWARD
var _flinch := 0.0
var _respawn_timer: Timer
var _told_shell := false                       # the "bubbles bounce off its shell" hint, once

@onready var visual: Node3D = $Visual
@onready var body: Node3D = $Visual/Body
@onready var ball: Node3D = $Visual/Ball
@onready var stars: Node3D = $Visual/Stars
@onready var hitbox: Area3D = $Hitbox
@onready var shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	target = home
	_t = randf() * 10.0
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_try_respawn)
	add_child(_respawn_timer)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	_cooldown -= delta
	_flinch = maxf(_flinch - delta, 0.0)
	var want := Vector3.ZERO
	match state:
		State.WANDER, State.STALK:
			want = _walk(delta)
		State.CURL:
			_state_t -= delta
			if _state_t <= 0.0:
				_set_state(State.ROLL)
		State.ROLL:
			_state_t -= delta
			want = _roll_dir * roll_speed * Arsenal.slow(self)     # (frosty from the Freeze mod: slower)
			if _state_t <= 0.0 or (is_on_wall() and _state_t < roll_time - 0.3):
				_set_state(State.DIZZY)
		State.DIZZY:
			_state_t -= delta
			if _state_t <= 0.0:
				_cooldown = roll_cooldown
				_set_state(State.WANDER)
	if global_position.y < LOW_GROUND and state != State.ROLL:
		target = home
	var accel := 30.0 if state == State.ROLL else 10.0
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(want, accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if h.length() > 0.2 and state != State.ROLL:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(h.x, h.z), 1.0 - exp(-6.0 * delta))
	_animate(delta, h.length())
	if player and hitbox.overlaps_body(player):
		_touch_player()


func _walk(delta: float) -> Vector3:
	# Amble about home, or creep toward Nina when she's close; roll at her once it's near enough and ready
	var to_p := player.global_position - global_position if player else Vector3(999, 0, 0)
	var sees := player != null and not player.is_recovering() and _flat(to_p) < sight_range and absf(to_p.y) < 4.0 \
		and _flat(player.global_position - home) < leash_range
	if sees:
		if state != State.STALK:
			Audio.play_at("fwump", global_position, -3.0, 0.1)
			_flinch = 0.4                                     # a jaw snap when it spots her
		state = State.STALK
		target = player.global_position
		if _cooldown <= 0.0 and _flat(to_p) < sight_range * 0.8:
			_roll_dir = Vector3(to_p.x, 0, to_p.z).normalized()
			_set_state(State.CURL)
			return Vector3.ZERO
	else:
		state = State.WANDER
		_retarget -= delta
		if _retarget <= 0.0 or _flat(target - global_position) < 0.5:
			var a := randf() * TAU
			target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
			_retarget = randf_range(2.5, 5.0)
	var to_t := target - global_position
	to_t.y = 0
	if to_t.length() < 0.4:
		return Vector3.ZERO
	return to_t.normalized() * (stalk_speed if state == State.STALK else wander_speed) * Arsenal.slow(self)


func _set_state(s: State) -> void:
	state = s
	match s:
		State.CURL:
			_state_t = 0.45
			Audio.play_at("fwump", global_position, 0.0)
			var tw := create_tween()
			tw.tween_property(body, "scale", Vector3(0.6, 0.35, 0.6), 0.2)
			tw.tween_callback(func() -> void:
				body.visible = false
				ball.visible = true
				ball.scale = Vector3.ONE * 0.6)
			tw.tween_property(ball, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		State.ROLL:
			_state_t = roll_time
			Audio.play_at("roll", global_position, 0.0, 0.1)
		State.DIZZY:
			_state_t = dizzy_time
			velocity = Vector3.ZERO
			_uncurl()
			stars.visible = true
		State.WANDER:
			stars.visible = false


func _uncurl() -> void:
	ball.visible = false
	ball.rotation = Vector3.ZERO
	body.visible = true
	body.scale = Vector3(0.7, 0.5, 0.7)
	create_tween().tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		add_collision_exception_with(player)              # touching is handled by the Hitbox
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var curled := state == State.CURL or state == State.ROLL
	var feet := player.global_position.y - 0.8
	var on_top := player.velocity.y < 0.5 and feet > global_position.y + (1.1 if curled else 1.4)
	if curled:
		if on_top:
			player.bounce(SHELL_BOUNCE)                   # armoured: she just bounces off
			Audio.play_at("boing", global_position)
		elif not player.is_invulnerable():
			player.hurt(damage, global_position)
		return
	if on_top:
		_stomped()
	elif player.is_rolling() or (Game.riding and _flat(player.velocity) >= ram_speed):
		hits = stomps_to_defeat
		_defeat()
	elif not player.is_invulnerable() and state != State.DIZZY:
		player.hurt(damage, global_position)


func _stomped() -> void:
	hits += 1
	player.bounce(STOMP_BOUNCE)
	Audio.play_at("stomp", global_position, 0.0, 0.05)
	if hits >= stomps_to_defeat:
		_defeat()
	else:
		_flinch = 0.6
		_cooldown = maxf(_cooldown, 1.0)
		Game.message("The Crocodillo's shell is tough! Stomp it again while it's dizzy!")


func shelled() -> bool:
	# Rolled up in its armour: bubbles boing off and it can't hear the Disco Ball (scripts/disco_ball.gd)
	return state == State.CURL or state == State.ROLL


func shot(power: int, _point: Vector3, _dir: Vector3) -> String:
	# A Star Popper bubble (scripts/star_bubble.gd)
	if defeated:
		return "miss"
	_find_player()
	if shelled():
		if not _told_shell:
			_told_shell = true
			Game.message("Boing! Bubbles bounce off its shell. Wait till it uncurls!")
		return "bounce"
	hits += power
	if hits >= stomps_to_defeat:
		_defeat(true)
	else:
		_flinch = 0.6
		_cooldown = maxf(_cooldown, 1.0)
		if state != State.DIZZY:
			_set_state(State.DIZZY)               # one bubble makes it dizzy: pop it again, or stomp it
		Game.message("Pop! The Crocodillo's dizzy. Once more!")
	return "hit"


func _defeat(bubbled := false) -> void:
	defeated = true
	velocity = Vector3.ZERO
	Requests.note("crocodillo")                                  # the request board
	Game.add_xp(xp_reward)
	_popup("+%d XP" % xp_reward)
	shape.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	stars.visible = false
	if bubbled:
		StarBubble.carry_off(self, visual, Color(0.45, 0.85, 0.55), 1.4)   # caught in a bubble, floats up and pops
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.4, 0.1, 1.4), 0.18)
		tw.tween_callback(func() -> void: visual.visible = false)
	_respawn_timer.start(respawn_time)


func _try_respawn() -> void:
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < 18.0:
		_respawn_timer.start(3.0)
		return
	global_position = home
	velocity = Vector3.ZERO
	hits = 0
	defeated = false
	_cooldown = roll_cooldown
	_set_state(State.WANDER)
	ball.visible = false
	body.visible = true
	body.scale = Vector3.ONE
	shape.set_deferred("disabled", false)
	hitbox.set_deferred("monitoring", true)
	visual.visible = true
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(delta: float, speed: float) -> void:
	var calm := 0.4 if Settings.reduce_motion else 1.0
	if state == State.ROLL:
		ball.rotation.x += speed / 0.72 * delta              # spin as it rolls
		visual.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
		return
	if state == State.DIZZY:
		stars.rotation.y += delta * 5.0
		body.rotation.z = sin(_t * 4.0) * 0.12 * calm      # wobbling on the spot
	else:
		body.rotation.z = 0.0
	# A plodding walk: legs and arms swinging, tail swaying, a bob in its step; the jaw snaps when it's alarmed
	var stride := clampf(speed / stalk_speed, 0.0, 1.0)
	var swing := sin(_t * (5.5 if state == State.STALK else 4.0)) * 0.55 * stride * calm
	(body.get_node("LegL") as Node3D).rotation.x = swing
	(body.get_node("LegR") as Node3D).rotation.x = -swing
	(body.get_node("ArmL") as Node3D).rotation.x = -swing * 0.7
	(body.get_node("ArmR") as Node3D).rotation.x = swing * 0.7
	(body.get_node("Tail") as Node3D).rotation.y = sin(_t * 2.2) * 0.3 * calm
	body.position.y = absf(swing) * 0.06
	var jaw := body.get_node("Head/Jaw") as Node3D
	var open := 0.0
	if _flinch > 0.0:
		open = absf(sin(_flinch * 14.0)) * 0.55
	elif state == State.STALK:
		open = 0.15 + 0.12 * sin(_t * 3.0)
	jaw.rotation.x = open


func _popup(text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = Color(1.0, 0.92, 0.4)
	label.outline_modulate = Color(0.3, 0.15, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	get_parent().add_child(label)
	label.global_position = global_position + Vector3(0, 2.2, 0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.2, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
