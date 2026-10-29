extends CharacterBody3D

# A Gloop: a grumpy jelly blob. It wanders near its home spot, chases Nina when she comes close, and hurts her on
# touch. Jump on its head to pop it for XP (big ones take two stomps); rolling into it, or ramming it on the skateboard
# at speed, works too, and so do the Star Popper's bubbles (scripts/star_popper.gd): it gets caught in a bubble, floats
# up and pops.
# It comes back after a while, but only once Nina has walked away. Scene: scenes/enemies/gloop.tscn
# Expects children: CollisionShape3D (sphere), Hitbox (Area3D with a sphere), Visual (Node3D with Body/eyes/brows).

@export_group("Stats")
@export var size := 1.0                       # 1 = normal, 1.5 = big; scales the body, hitbox and stomp height
@export var color := Color(0.5, 0.28, 0.92)
@export var stomps_to_defeat := 1
@export var damage := 2
@export var xp_reward := 4

@export_group("Behaviour")
@export var wander_radius := 6.0              # how far from home it ambles
@export var sight_range := 11.0               # notices Nina within this distance
@export var leash_range := 22.0               # gives up the chase if Nina gets this far from its home
@export var wander_speed := 1.4
@export var chase_speed := 3.4                # Nina walks at 5, so she can always outrun one
@export var turn_speed := 8.0
@export var respawn_time := 40.0              # seconds after being popped
@export var ram_speed := 7.0                  # skateboard speed that knocks one out

const STOMP_BOUNCE := 8.0                     # Nina's upward speed after a stomp (more if jump is held)
const LOW_GROUND := -0.25                     # below this height is the lake basin: Gloops don't like water

var home := Vector3.ZERO
var target := Vector3.ZERO
var hits := 0
var defeated := false
var player: Player

var _t := 0.0
var _retarget := 0.0
var _squash := 0.0                            # >0 while recoiling from a stomp
var _body_mat: StandardMaterial3D
var _respawn_timer: Timer
var _was_chasing := false
var _giggle_cooldown := 0.0

@onready var visual: Node3D = $Visual
@onready var hitbox: Area3D = $Hitbox
@onready var shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	target = home
	_t = randf() * 10.0
	# Scale the physics shapes (duplicated so every Gloop can have its own size) and the visuals
	var body_shape := (shape.shape as SphereShape3D).duplicate() as SphereShape3D
	body_shape.radius *= size
	shape.shape = body_shape
	shape.position *= size
	var hit_cs := hitbox.get_child(0) as CollisionShape3D
	var hit_shape := (hit_cs.shape as SphereShape3D).duplicate() as SphereShape3D
	hit_shape.radius *= size
	hit_cs.shape = hit_shape
	hit_cs.position *= size
	visual.scale = Vector3.ONE * size
	var body := visual.get_node("Body") as MeshInstance3D
	_body_mat = (body.material_override as StandardMaterial3D).duplicate()
	_body_mat.albedo_color = Color(color, _body_mat.albedo_color.a)
	_body_mat.emission = color
	body.material_override = _body_mat
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_try_respawn)
	add_child(_respawn_timer)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta

	# Decide where to go: chase Nina if she's close (and not still blinking from a hit), otherwise amble about home
	var speed := wander_speed
	var chasing := false
	if player and not player.is_recovering():
		var to_p := player.global_position - global_position
		if Vector2(to_p.x, to_p.z).length() < sight_range and absf(to_p.y) < 4.0 \
				and _flat(player.global_position - home) < leash_range:
			chasing = true
			target = player.global_position
			speed = chase_speed
	if not chasing:
		_retarget -= delta
		if _retarget <= 0.0 or _flat(target - global_position) < 0.4:
			var a := randf() * TAU
			target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
			_retarget = randf_range(2.0, 4.5)
	if global_position.y < LOW_GROUND:
		target = home                                         # wandered into the lake basin: head home
	# Giggle when it spots her
	_giggle_cooldown -= delta
	if chasing and not _was_chasing and _giggle_cooldown <= 0.0:
		Audio.play_at("gloop_giggle", global_position, -2.0, 0.12)
		_giggle_cooldown = 5.0
	_was_chasing = chasing

	# Move (horizontal accel toward the target, gravity), pausing briefly after a stomp
	var to_t := target - global_position
	to_t.y = 0
	var want := Vector3.ZERO
	if _squash <= 0.0 and to_t.length() > 0.3:
		want = to_t.normalized() * speed
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(want, 12.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

	if h.length() > 0.2:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(h.x, h.z), 1.0 - exp(-turn_speed * delta))
	_animate(delta, h.length(), chasing)

	if player and hitbox.overlaps_body(player):
		_touch_player()


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		# Nina passes through Gloops physically; touching is handled by the Hitbox instead
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8                      # player origin is mid-capsule
	if player.velocity.y < 0.5 and feet > global_position.y + 0.5 * size:
		_stomped()
	elif player.is_rolling() or (Game.riding and _flat(player.velocity) >= ram_speed):
		_defeat()
	elif not player.is_invulnerable():
		player.hurt(damage, global_position)


func _stomped() -> void:
	hits += 1
	player.bounce(STOMP_BOUNCE)
	Audio.play_at("stomp", global_position, 0.0, 0.1 if size == 1.0 else 0.0)
	if hits >= stomps_to_defeat:
		_defeat()
	else:
		_squash = 0.6                                                # recoil and flash, then keep coming
		Game.message("Big Gloop! Stomp it again!")


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	# A Star Popper bubble (scripts/star_bubble.gd). Big Gloops take two, or one big bubble.
	if defeated:
		return "miss"
	_find_player()
	hits += power
	if hits >= stomps_to_defeat:
		_defeat(true)
	else:
		_squash = 0.6                                                # wobble and flash, then keep coming
		velocity += Vector3(dir.x, 0, dir.z).normalized() * 3.0
		Game.message("Big Gloop! Pop it again!")
	return "hit"


func _defeat(bubbled := false) -> void:
	if hits == 0:
		Audio.play_at("stomp", global_position)              # rolled into or rammed, not stomped
	defeated = true
	velocity = Vector3.ZERO
	Game.add_xp(xp_reward)
	_popup("+%d XP" % xp_reward)
	shape.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	if bubbled:
		StarBubble.carry_off(self, visual, color, size)       # caught in a bubble, floats up and pops
	else:
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.7, 0.08, 1.7) * size, 0.12)
		tw.tween_callback(func(): visual.visible = false)
	_respawn_timer.start(respawn_time)


func _try_respawn() -> void:
	# Don't pop back in right next to her
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < 15.0:
		_respawn_timer.start(3.0)
		return
	global_position = home
	velocity = Vector3.ZERO
	hits = 0
	_squash = 0.0
	defeated = false
	shape.set_deferred("disabled", false)
	hitbox.set_deferred("monitoring", true)
	visual.visible = true
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE * size, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(delta: float, moving_speed: float, chasing: bool) -> void:
	# Jelly hop: bob up and down and squish on landing; faster and bouncier when chasing
	var body := visual.get_node("Body") as Node3D
	if _squash > 0.0:
		_squash -= delta
		var k := _squash / 0.6
		body.scale = Vector3(1.0 + 0.5 * k, 1.0 - 0.45 * k, 1.0 + 0.5 * k)
		_body_mat.emission_energy_multiplier = 0.1 + (0.4 if Settings.reduce_flashing else 2.0) * k
		return
	_body_mat.emission_energy_multiplier = 0.1
	var freq := 9.0 if chasing else 6.0
	var hop := absf(sin(_t * freq)) if moving_speed > 0.2 else 0.15 * absf(sin(_t * 2.0))
	if Settings.reduce_motion:
		hop *= 0.35
	body.position.y = 0.4 + hop * (0.25 if chasing else 0.15)
	var squish := 1.0 - hop
	body.scale = Vector3(1.0 + 0.12 * squish, 1.0 - 0.12 * squish, 1.0 + 0.12 * squish)


func _popup(text: String) -> void:
	# Floating "+XP" text that rises and fades; lives in the scene, not on the Gloop, so it outlasts the pop
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
	label.global_position = global_position + Vector3(0, 1.4 * size, 0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.2, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)
