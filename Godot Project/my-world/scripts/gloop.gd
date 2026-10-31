extends CharacterBody3D

# A Gloop: a grumpy blob of glossy green-gold goo that's always dripping (the look comes from Hayden's Gloop King
# picture; scripts/gloop_king.gd is the King himself). It wanders near its home spot, chases Nina when she comes close, and hurts her on
# touch. Jump on its head to pop it for XP (big ones take two stomps); rolling into it, or ramming it on the skateboard
# at speed, works too, and so do the Star Popper's bubbles (scripts/star_popper.gd): it gets caught in a bubble, floats
# up and pops.
# It comes back after a while, but only once Nina has walked away. Scene: scenes/enemies/gloop.tscn
# Expects children: CollisionShape3D (sphere), Hitbox (Area3D with a sphere), Puddle, and Visual (Node3D with Body and
# Feet; Body holds the eyes and Drips, markers where the drops fall from). Built by tools/build_gloop.gd.

@export_group("Stats")
@export var size := 1.0                       # 1 = normal, 1.5 = big; scales the body, hitbox and stomp height
@export var color := Color(0.55, 0.75, 0.18)  # the colour of its pop sparkles
@export var goldness := 0.45                  # how much gold is swirled through the green goo
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
@export var respawns := true                  # false for the Gloops the King calls in: once popped, they're gone
@export var respawn_clear := 15.0             # it only comes back when she's at least this far from its home

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
var _goo: Array[ShaderMaterial] = []         # this Gloop's own copies of its goo, so a hit only flashes this one
var _body_y := 0.0
var _feet: Array[Node3D] = []
var _feet_rest: Array[Vector3] = []
var _drops: Array[Dictionary] = []           # one falling drop per tongue tip: {from, mesh, t, wait}
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
	_own_goo(visual)
	var body := visual.get_node("Body") as Node3D
	_body_y = body.position.y
	for f in visual.get_node("Feet").get_children():
		_feet.append(f)
		_feet_rest.append(f.position)
	_make_drops(body)
	($Puddle as Node3D).scale = Vector3(size, 1.0, size * 0.85)
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
		want = to_t.normalized() * speed * Arsenal.slow(self)        # (frosty from the Freeze mod: slower)
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
		_hurt_message(true)


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
		_hurt_message(false)
	return "hit"


func _defeat(bubbled := false) -> void:
	if hits == 0:
		Audio.play_at("stomp", global_position)              # rolled into or rammed, not stomped
	defeated = true
	velocity = Vector3.ZERO
	Requests.note("gloop", 1.0, "bubble" if bubbled else ("stomp" if hits > 0 else "ram"))     # the request board
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
	for d in _drops:
		(d.mesh as Node3D).visible = false
	create_tween().tween_property($Puddle, "scale", Vector3(0.01, 1.0, 0.01), 1.2).set_delay(0.3)
	_defeated()
	if respawns:
		_respawn_timer.start(respawn_time)
	else:
		get_tree().create_timer(2.5).timeout.connect(queue_free)


func _try_respawn() -> void:
	# Don't pop back in right next to her
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < respawn_clear:
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
	($Puddle as Node3D).scale = Vector3(size, 1.0, size * 0.85)
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE * size, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(delta: float, moving_speed: float, chasing: bool) -> void:
	# Goo bounce: bob and squish on every step; faster and bouncier when chasing
	var body := visual.get_node("Body") as Node3D
	if _squash > 0.0:
		_squash -= delta
		var k := _squash / 0.6
		body.scale = Vector3(1.0 + 0.5 * k, 1.0 - 0.45 * k, 1.0 + 0.5 * k)
		_set_goo("flash", (0.15 if Settings.reduce_flashing else 0.8) * k)
		return
	_set_goo("flash", 0.0)
	_set_goo("ooze", 0.35 if Settings.reduce_motion else 1.0)
	_drip(delta)
	var freq := 9.0 if chasing else 6.0
	var hop := absf(sin(_t * freq)) if moving_speed > 0.2 else 0.15 * absf(sin(_t * 2.0))
	if Settings.reduce_motion:
		hop *= 0.35
	body.position.y = _body_y + hop * (0.1 if chasing else 0.05)   # a waddling bounce: it stays on its feet
	var squish := 1.0 - hop
	body.scale = Vector3(1.0 + 0.12 * squish, 1.0 - 0.12 * squish, 1.0 + 0.12 * squish)
	# Waddle: the feet stay on the ground and shuffle while it moves, front and back pairs in turn
	var step := sin(_t * freq) if moving_speed > 0.2 else 0.0
	for i in _feet.size():
		var side := 1.0 if (i == 0 or i == 3) else -1.0
		_feet[i].position = _feet_rest[i] + Vector3(0, maxf(step * side, 0.0) * 0.06, step * side * 0.06)


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


# --- Goo and drips -------------------------------------------------------------------------------------------------

func _own_goo(n: Node, copies := {}) -> void:
	# Give this Gloop its own copy of each goo material (one for the oozing body, one for the still feet and rims),
	# so flashing one after a hit doesn't flash them all
	for c in n.get_children():
		if c is MeshInstance3D and c.material_override is ShaderMaterial:
			var m := c.material_override as ShaderMaterial
			if not copies.has(m):
				var mine := m.duplicate() as ShaderMaterial
				mine.set_shader_parameter("goldness", goldness)
				copies[m] = mine
				_goo.append(mine)
			c.material_override = copies[m]
		_own_goo(c, copies)


func _set_goo(param: String, value: float) -> void:
	for m in _goo:
		m.set_shader_parameter(param, value)


func _make_drops(body: Node3D) -> void:
	# One drop for each tongue tip marker. Drops live on the Visual, not the Body, so they fall straight down to
	# the puddle however the body is bobbing.
	var marks := body.get_node_or_null("Drips")
	if marks == null:
		return
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.035
	drop_mesh.height = 0.07
	drop_mesh.radial_segments = 10
	drop_mesh.rings = 5
	for m in marks.get_children():
		var d := MeshInstance3D.new()
		d.name = "Drop"
		d.mesh = drop_mesh
		d.material_override = _goo[0] if not _goo.is_empty() else null
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.visible = false
		visual.add_child(d)
		_drops.append({"from": m, "mesh": d, "t": 0.0, "wait": randf_range(0.0, 1.5)})


func _drip(delta: float) -> void:
	# Each drop swells at the tip of its tongue, stretches, lets go, falls into the puddle and splats flat, then
	# after a little wait the next one starts. Skipped when nobody's close enough to see it.
	if player and global_position.distance_squared_to(player.global_position) > 45.0 * 45.0:
		return
	var body := visual.get_node("Body") as Node3D
	for d in _drops:
		var mesh := d.mesh as MeshInstance3D
		if d.wait > 0.0:
			d.wait -= delta
			mesh.visible = false
			continue
		d.t += delta
		var tip: Vector3 = body.transform * (d.from as Node3D).position
		mesh.visible = true
		if d.t < 1.4:                                            # swelling and stretching at the tip
			var k: float = d.t / 1.4
			mesh.position = tip + Vector3(0, -0.04 * k, 0)
			mesh.scale = Vector3(0.4 + 0.6 * k, 0.4 + 1.4 * k * k, 0.4 + 0.6 * k)
		elif mesh.position.y > 0.03:                             # falling
			var fall: float = d.t - 1.4
			mesh.position.y = tip.y - 0.04 - 0.5 * 9.8 * fall * fall
			mesh.scale = Vector3(0.9, 1.5, 0.9)
		else:                                                    # splat, then gone
			mesh.position.y = 0.02
			mesh.scale = mesh.scale.lerp(Vector3(2.2, 0.15, 2.2), 1.0 - exp(-18.0 * delta))
			if mesh.scale.y < 0.2:
				d.t = 0.0
				d.wait = randf_range(0.5, 2.5)


# --- Hooks for the King (scripts/gloop_king.gd) --------------------------------------------------------------------

func _hurt_message(stomped: bool) -> void:
	# Hit but not popped yet
	Game.message("Big Gloop! Stomp it again!" if stomped else "Big Gloop! Pop it again!")


func _defeated() -> void:
	pass
