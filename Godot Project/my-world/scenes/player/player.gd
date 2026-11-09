extends CharacterBody3D
class_name Player

@export_group("Movement")
@export var speed: float = 5.0
@export var acceleration: float = 40.0   # how quickly you reach top speed on the ground
@export var friction: float = 50.0       # how quickly you stop on the ground
@export var air_control: float = 0.4     # fraction of ground accel/friction available mid-air
@export var turn_speed: float = 12.0     # how quickly the model turns to face movement

@export_group("Jump")
@export var jump_velocity: float = 6.0
@export var jump_cut: float = 0.5                # releasing jump early scales upward speed by this
@export var fall_gravity_multiplier: float = 1.6 # heavier on the way down = less floaty
@export var coyote_time: float = 0.12            # seconds you can still jump after leaving a ledge
@export var jump_buffer_time: float = 0.12       # seconds a jump press is remembered before landing
@export var double_jump_velocity: float = 5.5    # the second jump, in mid-air; free, once per time in the air
@export var flip_time: float = 0.42              # the front flip that goes with it


@export_group("Roll")
@export var roll_speed: float = 12.0        # speed at the start of the roll; it eases down to a run by the end
@export var roll_end_speed: float = 4.5
@export var roll_time: float = 0.45         # seconds the roll lasts (about 3.7 m)
@export var roll_iframes: float = 0.38      # nothing can hurt her for this much of it, from the start
@export var roll_cost: float = 25.0         # SP (stamina) per roll
@export var roll_buffer: float = 0.15       # a roll pressed just before landing still happens

@export_group("Sprint")
# Keep holding the roll button and she comes out of the roll into a sprint (Hayden's playtest, 7 Nov 2026). Free: no
# stamina, so little ones can run about town as much as they like. Let go (or stop steering) and she's back to a run.
@export var sprint_scale: float = 1.65      # times her running speed
@export var sprint_hold: float = 0.3        # seconds the roll button is held before she sprints (a tap is just a roll)

@export_group("Getting hurt")
@export var invulnerable_time: float = 1.2  # seconds of blinking after a hit, when nothing can hurt her
@export var knockback: float = 7.0          # how hard a hit pushes her away
@export var knockback_up: float = 4.0
@export var stun_time: float = 0.3          # seconds the knockback can't be steered out of

# Reference to the camera boom so movement follows where you're looking
@onready var spring_arm: SpringArm3D = $SpringArm3D
# The character model; rotated to face movement (the body itself stays unrotated so the camera doesn't spin)
@onready var visual: Node3D = $Visual
@onready var tumble: Node3D = $Visual/Tumble     # pivot at her middle: rolls and flips spin this
@onready var model: Node3D = $Visual/Tumble/Nina    # swapped for the player's own hero, or a friend skating (set_rider)
@onready var board: Node3D = $Visual/Skateboard     # what she rides on (scenes/player/ride_kit.gd fills it)
var _sash: Node3D                                 # shown once she has the campaign sash
var _hat: Node3D                                  # the market hat she's wearing (scripts/cosmetics.gd)
var _stickers: Node3D                             # market stickers on the sash
# Animations exported from Blender with the character (idle, run, jump, fall, skate)
@onready var anim: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)

const MODEL_Y := -0.8                       # feet at the bottom of the collision capsule
const BURROW := preload("res://scripts/burrow.gd")   # no class_name: --script tools compile those before the autoloads
const FROST_BREATH := preload("res://scripts/frost_breath.gd")
const GROOVE := preload("res://scripts/groove.gd")

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _invulnerable_timer := 0.0
var _stun_timer := 0.0
var _roll_timer := 0.0
var _roll_dir := Vector3.ZERO
var _roll_buffer_timer := 0.0
var _dash_held := 0.0                       # how long the roll button's been held (sprinting after sprint_hold)
var sprinting := false
var _sprint_puff := 0.0
var _air_jump_used := false
var _spin_timer := 0.0                      # somersault (roll) or front flip (double jump) in progress
var _spin_time := 1.0
var _spin_squash := 0.0                     # how much she tucks into a ball mid-spin
var _spin_grounded := false                 # roll: keep the ball on the floor while it turns
var _was_on_floor := true
var _fall_speed := 0.0
var _step_timer := 0.0
# Who's holding the controls right now (talking, a countdown, the creator, a zipline...): no moving, jumping or
# rolling while anyone is. Each system takes and lets go of its own hold with lock_input("who") and
# unlock_input("who"), so one finishing never hands the controls back while another still needs them (a talk that
# starts the Swap-o-Tron used to let her walk off mid-flash, because the talk's end unlocked everyone).
signal input_lock_changed(locked: bool)
var _input_locks := {}
# Old-style switch, kept for tools and tests: true holds the controls as "legacy", false lets go for everyone.
var input_locked: bool:
	get:
		return not _input_locks.is_empty()
	set(on):
		if on:
			lock_input(&"legacy")
		elif not _input_locks.is_empty():
			_input_locks.clear()
			input_lock_changed.emit(false)
var carried := false                        # riding something that moves her itself (scripts/zipline.gd): no physics
var skate: Skate                            # takes over her physics while she's on the board (scenes/player/skate.gd)
var popper: StarPopper                      # her bubble blaster: aiming and shooting (scripts/star_popper.gd)
var burrow: Node                            # Bramble's burrow, once the Rootmind is mended (scripts/burrow.gd)
var frost_breath: Node                      # Flurry's frost breath, once the Frozen Moment's mended (scripts/frost_breath.gd)
var groove: Node                            # Melody's groove, once Rhythm Springs is mended (scripts/groove.gd)
var rider := "nina"                         # who this is (scripts/rides.gd): the player's own "hero", or a friend skating
var _on_board := false
# Boosters (scripts/boosters.gd) work on foot too: a rush carries her past her running speed for a moment, the way a
# boost pad carries a rider past her pushing speed (scenes/player/skate.gd), then she eases back down to a run.
var _rush_time := 0.0
var _rush_speed := 0.0
var _rush_fade := 0.0

# Walk-through places she's inside (clouds, the bubble bath, hot springs, the lake: scripts/soft_zone.gd,
# scripts/water.gd). Each can slow her down (speed_scale), make her float (gravity_scale, fall_cap) and sets the
# sound of her steps (kind). What's under her feet otherwise picks the sound too (scripts/surfaces.gd).
var _zones: Array[Node] = []
var _floor_node: Node = null
const STEP_SOUNDS := {"grass": "step_grass", "wood": "step_wood", "stone": "step_stone", "water": "step_water",
	"cloud": "step_cloud", "crystal": "step_crystal", "mushroom": "step_cloud"}
const LAND_SOUNDS := {"water": "splash", "cloud": "fwump", "crystal": "step_crystal", "mushroom": "boing"}
# Gliding: while glide_fall is over 0 (only in Lanternmoor, where Pip lends moth wings; the player is part of each
# scene, so it's gone again everywhere else), holding Jump while falling slows the fall to this many metres a second.
var glide_fall := 0.0
var gliding := false
const ICE_GRIP := 0.12                      # on ice (anything in the "ice" group) she speeds up and stops this much slower
const MUSHROOM_BOUNCE := 9.5                # landing on a big mushroom cap bounces her up this fast


func _ready() -> void:
	add_to_group("player")              # enemies find her through this group
	var scene_root: Node = owner if owner else get_tree().current_scene   # current_scene isn't set yet during a scene change
	# Coming through a door: appear at the matching spawn marker in this scene
	if Game.next_spawn != "":
		var marker := scene_root.find_child(Game.next_spawn, true, false) as Node3D
		if marker:
			# Stand on the marker facing the way it points (its -Z: into the room, or away from the building). Only
			# the model and the camera turn: the body stays unturned, like everywhere else (movement and the camera
			# rely on it). Copying the marker's whole transform used to turn the body and leave her facing backwards.
			global_position = marker.global_position
			rotation = Vector3.ZERO
			var yaw := marker.global_rotation.y
			visual.rotation.y = yaw + PI                    # models face +Z
			spring_arm.rotation.y = yaw                     # camera behind her, looking the same way
		Game.next_spawn = ""
	# Starting the game from a save: appear where she was
	var resume := Game.take_resume_point(scene_root.scene_file_path if scene_root else "")
	if not resume.is_empty():
		global_position = resume["position"]
		visual.rotation.y = resume["yaw"]
		spring_arm.rotation.y = resume["yaw"] + PI         # camera behind her
	if not Game.is_resuming():
		Game.save_game.call_deferred()                     # autosave on arriving anywhere
	_loop_animations()
	if anim:
		anim.play("idle")
	skate = Skate.new()
	skate.name = "Skate"
	add_child(skate)
	skate.setup(self)
	popper = StarPopper.new()
	add_child(popper)
	popper.setup(self)
	popper.popped.connect(skate.on_pop)        # pops on the board are tricks in the combo
	burrow = BURROW.new()
	burrow.name = "Burrow"
	add_child(burrow)
	burrow.setup(self)
	frost_breath = FROST_BREATH.new()
	frost_breath.name = "FrostBreath"
	add_child(frost_breath)
	frost_breath.setup(self)
	groove = GROOVE.new()
	groove.name = "Groove"
	add_child(groove)
	groove.setup(self)
	set_rider("hero", false)                    # the player's own character (scripts/hero.gd) takes the stand-in's place
	Game.equipment_changed.connect(_on_equipment_changed)
	_on_equipment_changed()
	# A new game (or a save from before heroes) starts in the character creator. Not in tests and screenshot tools,
	# which run their own main loop.
	if Game.needs_creator and get_tree().get_script() == null:
		Creator.open.call_deferred(true)


func lock_input(who: StringName) -> void:
	# Hold the controls for "who" until it lets go. Taking a hold it already has does nothing (countdowns call this
	# every frame).
	if _input_locks.has(who):
		return
	var was := input_locked
	_input_locks[who] = true
	if not was:
		input_lock_changed.emit(true)


func unlock_input(who: StringName) -> void:
	# Let go of "who"'s hold. She can move again once nobody's holding the controls.
	if not _input_locks.erase(who):
		return
	if _input_locks.is_empty():
		input_lock_changed.emit(false)


func input_locks() -> Array:
	# Who's holding the controls, for tests, the debugger and anyone asking "why can't she move?"
	return _input_locks.keys()


func _loop_animations() -> void:
	if anim:
		for loop_name in ["idle", "run", "walk", "fall", "skate", "ride", "fly"]:
			if anim.has_animation(loop_name):
				anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR


func set_rider(id: String, hop_on := true) -> void:
	# Swap who's playing: the player's own hero, or a friend skating at a skate park's Skaters' Corner
	# (scripts/rider_select.gd). Their model takes the place of the last one,
	# their ride goes under them, and the skating takes on their ride's feel and tricks. While a friend is skating,
	# their own self in town steps out of sight, so there aren't two of them.
	_show_npc(rider, true)
	rider = id
	var r := Rides.ride(id)
	var old := model
	model = (load(r.model) as PackedScene).instantiate() as Node3D
	model.name = "Hero" if id == "hero" else "Rider"
	tumble.add_child(model)
	old.free()                                  # her hat, sash and stickers go with her model
	_sash = null
	_hat = null
	_stickers = null
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_loop_animations()
	if id == "hero":
		_add_sash()
	skate.set_ride(r, RideKit.build(r.kit, board, model))
	if popper:
		popper.attach(model)
	_show_npc(id, false)
	if hop_on and not Game.riding and Game.has_item("skateboard"):
		Game.riding = true
		Game.equipment_changed.emit()
	else:
		_on_equipment_changed()


func _show_npc(id: String, on: bool) -> void:
	# The town's own copy of a character (and Dash's bike), shown or put away
	var scene := get_tree().current_scene
	if id == "hero" or scene == null:
		return
	for r in scene.find_children("Routine", "", true, false):
		if r.get("character_id") != id:
			continue
		for n in [r.get_parent(), r.get("_bike")]:
			if n is Node3D:
				(n as Node3D).visible = on
				(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _on_equipment_changed() -> void:
	if not Game.riding and rider != "hero":
		set_rider("hero", false)                # stepping off makes you yourself again
		return
	board.visible = Game.riding
	if Game.riding and not _on_board:
		skate.start()
	elif not Game.riding and _on_board:
		skate.stop()
	_on_board = Game.riding
	if _sash:
		_sash.visible = Game.has_item("campaign_sash")     # Rex's thank-you for running his campaign
		if _stickers:
			_stickers.free()
		_stickers = Node3D.new()
		_stickers.name = "Stickers"
		_sash.add_child(_stickers)
		for id in Cosmetics.STICKER_ANGLES:
			if Game.has_item("shop:" + id):
				var st: Node3D = Cosmetics.sticker(id)
				st.transform = Cosmetics.sticker_place(id)
				_stickers.add_child(st)
	# Head to toe, and their looks: the hero as made in the creator (scripts/hero.gd), or a friend as dressed at the
	# wardrobe (scripts/clothes.gd)
	if rider == "hero":
		Hero.apply(model, Game.hero, Game.outfits.get("hero", {}))
	else:
		Clothes.dress(model, rider, Game.outfits.get(rider, {}), Game.looks.get(rider, {}))
	_hat = model.find_child("Hat", true, false) as Node3D
	model.position.y = MODEL_Y + (float(skate.ride.deck) if Game.riding else 0.0)
	model.rotation.y = float(skate.ride.stance) if Game.riding else 0.0


func _add_sash() -> void:
	# A "VOTE REX" sash from her shoulder across to her hip, round her middle (on the model, so it turns and rolls
	# with her)
	_sash = Node3D.new()
	_sash.name = "Sash"
	_sash.position = Vector3(0, 0.6, 0)
	model.add_child(_sash)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.27
	torus.outer_radius = 0.33
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.25, 0.3)
	m.roughness = 0.7
	ring.material_override = m
	ring.rotation = Vector3(0, 0, deg_to_rad(44))
	ring.scale = Vector3(1.0, 1.0, 0.85)
	_sash.add_child(ring)
	var star := MeshInstance3D.new()                       # a gold rosette on the front
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.03
	star.mesh = disc
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.25)
	gold.metallic = 0.6
	gold.roughness = 0.3
	star.material_override = gold
	star.position = Vector3(-0.07, 0.04, 0.27)
	star.rotation = Vector3(PI / 2, 0, 0)
	_sash.add_child(star)


func is_invulnerable() -> bool:
	# Nothing can hurt her: blinking after a hit, the invulnerable frames of a roll, or underground
	if burrow and burrow.active:
		return true
	return _invulnerable_timer > 0.0 or (_roll_timer > 0.0 and roll_time - _roll_timer < roll_iframes)


func is_recovering() -> bool:
	# Just the blinking after a hit (enemies leave her alone for it; a roll's iframes don't scare them off)
	return _invulnerable_timer > 0.0


func is_rolling() -> bool:
	return _roll_timer > 0.0


func is_sprinting() -> bool:
	return sprinting


func hurt(amount: int, from: Vector3) -> void:
	# Called by enemies on touch. Knocks her away from the hit, then she blinks and can't be hurt for a moment.
	if is_invulnerable():
		return
	_invulnerable_timer = invulnerable_time
	_stun_timer = stun_time
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = -visual.global_transform.basis.z
	velocity = away.normalized() * knockback + Vector3.UP * knockback_up
	_roll_timer = 0.0
	Audio.play("hurt")
	Juice.shake(0.35)
	Juice.rumble(0.4, 0.2, 0.3)
	Game.damage(amount)


func bounce(strength: float) -> void:
	# Pop upward after stomping an enemy; hold jump for a higher bounce
	velocity.y = strength * (1.3 if Input.is_action_pressed("jump") else 1.0)
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_air_jump_used = false              # a stomp gives the double jump back


func boost(extra: float, seconds: float) -> void:
	# A booster: on a ride the ride takes it (the same as a race's boost pads), on foot she rushes along
	if Game.riding:
		skate.boost(extra, seconds)
		return
	_rush_speed = maxf(extra, _rush_speed if _rush_time > 0.0 else 0.0)
	_rush_time = maxf(_rush_time, seconds)


func boosting() -> bool:
	return skate.boosting() if Game.riding else _rush_time > 0.0


func facing_dir() -> Vector3:
	# Which way her model faces, flat (models face +Z)
	return Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))


func _physics_process(delta: float) -> void:
	if _hat and _hat.has_node("Propeller"):
		(_hat.get_node("Propeller") as Node3D).rotate_y(delta * 14.0)    # the propeller cap spins
	if burrow.active and (carried or Game.riding):
		burrow.stop(0.0)                        # onto a ride or a zipline: up she comes
	if carried:
		return
	var on_floor := is_on_floor()

	# Blink while invulnerable after a hit (or stay solid with Reduce flashing on)
	if _invulnerable_timer > 0.0:
		_invulnerable_timer -= delta
		model.visible = Settings.reduce_flashing or _invulnerable_timer <= 0.0 or fmod(_invulnerable_timer, 0.16) > 0.08
	_stun_timer -= delta
	if _rush_time > 0.0 and _rush_time - delta <= 0.0:
		_rush_fade = 0.8
	_rush_time -= delta
	_rush_fade -= delta
	if Game.riding:
		skate.physics(delta)
		return
	if burrow.active:
		burrow.physics(delta)
		return
	if Input.is_action_just_pressed("burrow") and burrow.try_start():
		return
	if Input.is_action_just_pressed("frost_breath"):
		frost_breath.try_breathe()
	if Input.is_action_just_pressed("groove"):
		groove.try_groove()
	if on_floor:
		_air_jump_used = false

	# Gravity
	if not on_floor:
		var gravity := get_gravity() * _zone_min("gravity_scale", 1.0)
		if velocity.y < 0:
			gravity *= fall_gravity_multiplier
		velocity += gravity * delta
		velocity.y = maxf(velocity.y, -_zone_min("fall_cap", 1000.0))       # floaty in clouds and the bath
		# Moth wings (Pip lends them in Lanternmoor, scripts/lanternmoor.gd): holding Jump on the way down glides
		gliding = glide_fall > 0.0 and velocity.y < 0.0 and Input.is_action_pressed("jump") and not input_locked
		if gliding:
			velocity.y = maxf(velocity.y, -glide_fall)
	else:
		gliding = false

	# Coyote time and jump buffering
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	var jump_pressed := Input.is_action_just_pressed("jump") and not input_locked
	_jump_buffer_timer = jump_buffer_time if jump_pressed else _jump_buffer_timer - delta

	# Jump. Jumping out of a roll is allowed and ends it.
	if _jump_buffer_timer > 0 and _coyote_timer > 0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0
		_coyote_timer = 0
		_end_roll()
		Audio.play("jump", -3.0)
		Juice.squash(model, -0.18, 0.2)                 # a stretch up off the ground
	# Double jump: a second, free jump in mid-air with a front flip; back again on landing or stomping
	elif jump_pressed and not on_floor and not _air_jump_used and _stun_timer <= 0.0:
		velocity.y = double_jump_velocity
		_air_jump_used = true
		_jump_buffer_timer = 0
		_end_roll()
		_spin(flip_time, 0.25, false)
		Audio.play("double_jump", -3.0, 0.05)
		Juice.burst(get_parent(), global_position + Vector3(0, 0.3, 0), Color(0.85, 0.8, 1.0, 0.8), 8, 0.07, 2.0, 0.4)

	# Let go of jump early for a shorter hop
	if Input.is_action_just_released("jump") and velocity.y > 0:
		velocity.y *= jump_cut

	# Read input
	var input_dir := Vector2.ZERO if input_locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Build direction relative to the CAMERA's yaw instead of the player body
	var cam_basis := spring_arm.global_transform.basis
	var forward := -cam_basis.z
	var right := cam_basis.x
	# Flatten to the horizontal plane so looking up/down doesn't slow you
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var direction := (right * input_dir.x - forward * input_dir.y).normalized()

	# Roll (the "dash" action): on the ground only; pressed in the air, it waits a moment for her to land
	_roll_buffer_timer = roll_buffer if Input.is_action_just_pressed("dash") and not input_locked else _roll_buffer_timer - delta
	if _roll_buffer_timer > 0.0 and on_floor:
		_try_roll(direction)
	# Sprint: still holding it once the roll's done, and steering somewhere
	_dash_held = _dash_held + delta if Input.is_action_pressed("dash") and not input_locked else 0.0
	sprinting = _dash_held >= sprint_hold and direction != Vector3.ZERO and _roll_timer <= 0.0 \
		and _stun_timer <= 0.0 and not popper.aiming

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	if _roll_timer > 0.0:
		_roll_timer -= delta
		var f := 1.0 - maxf(_roll_timer, 0.0) / roll_time
		horizontal = _roll_dir * lerpf(roll_speed, roll_end_speed, f * f)   # fast start, eases into a run
	elif _stun_timer > 0.0:
		pass                                # knocked back: ride out the hit
	else:
		# Accelerate toward the target speed instead of snapping to it
		var rate := acceleration if direction else friction
		if not on_floor:
			rate *= air_control
		var target := direction * speed * _zone_min("speed_scale", 1.0) * popper.move_scale()
		if sprinting:
			target *= sprint_scale
			if on_floor:
				rate = acceleration * 1.5
				_sprint_puff -= delta
				if _sprint_puff <= 0.0:                 # little dust puffs from her heels
					_sprint_puff = 0.18
					Juice.burst(get_parent(), global_position + Vector3(0, -0.7, 0), Color(0.95, 0.9, 0.8, 0.55), 3, 0.06, 0.8, 0.35)
		if _rush_time > 0.0:
			# Rushing from a booster: she shoots along the way she steers (or faces, with nothing held)
			target = (direction if direction else facing_dir()) * (speed + _rush_speed)
			rate = acceleration * (3.0 if on_floor else 1.0)
		elif _rush_fade > 0.0 and horizontal.length() > speed:
			rate = acceleration * 0.2                   # easing back down to a run, not a sudden stop
		if on_floor and on_ice():
			rate *= ICE_GRIP                            # slippy: a kid-safe slide, never a fall
		horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_fall_speed = -velocity.y
	move_and_slide()
	_floor_node = null
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y > 0.6:
				_floor_node = c.get_collider() as Node
				break
		if _floor_node == null:
			_floor_node = _floor_below()           # running on the flat, floor snap keeps her down with no collision to read
	RenderingServer.global_shader_parameter_set("nina_pos", global_position)   # plants lean away from her
	_sounds(delta, horizontal.length())

	# Turn the model to face where you steer (models face +Z after glTF export from Blender)
	var face := _roll_dir if _roll_timer > 0.0 else direction
	if popper.aiming and _roll_timer <= 0.0:
		# Aiming the Star Popper: she faces where the camera looks and walks (or sidesteps) that way round
		visual.rotation.y = lerp_angle(visual.rotation.y, popper.aim_yaw(), 1.0 - exp(-turn_speed * 2.0 * delta))
	elif face:
		var target_yaw := atan2(face.x, face.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	_update_spin(delta)

	_update_animation(horizontal.length())


func _try_roll(direction: Vector3) -> void:
	# A quick forward somersault that costs stamina (SP). For most of it nothing can hurt her (iframes), so she can
	# roll straight through an attack; rolling into a Gloop pops it.
	if _roll_timer > 0.0 or _stun_timer > 0.0:
		return
	_roll_buffer_timer = 0.0
	if not Game.spend_sp(roll_cost):
		Game.message("Too tired to roll! Stamina refills in a moment.")
		Audio.play("ui_back", -6.0, 0.0)
		return
	_roll_dir = direction if direction else visual.global_transform.basis.z
	_roll_dir.y = 0.0
	_roll_dir = _roll_dir.normalized()
	_roll_timer = roll_time
	_spin(roll_time, 0.5, true)
	Audio.play("roll", -2.0, 0.08)
	Juice.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color(0.9, 0.85, 0.75, 0.7), 8, 0.08, 1.5, 0.5)
	Juice.rumble(0.2, 0.08)
	if not Settings.reduce_motion:
		spring_arm.fov_kick = 5.0


func _end_roll() -> void:
	if _roll_timer > 0.0:
		_roll_timer = 0.0
		_spin_timer = 0.0                    # the spin eases back upright from wherever it was


func _spin(time: float, squash: float, grounded: bool) -> void:
	_spin_time = time
	_spin_timer = time
	_spin_squash = squash
	_spin_grounded = grounded


func _update_spin(delta: float) -> void:
	# One full turn forward around her middle, tucked into a ball halfway through. The visual is rotated to face her
	# heading, so turning about its X axis is always a forward somersault.
	if _spin_timer > 0.0:
		_spin_timer -= delta
		var f := clampf(1.0 - _spin_timer / _spin_time, 0.0, 1.0)
		var turn := f * f * (3.0 - 2.0 * f)                         # ease in and out
		tumble.rotation.x = TAU * turn if _spin_timer > 0.0 else 0.0
		var s := 1.0 - _spin_squash * sin(PI * f)
		tumble.scale = Vector3(1.0, s, 1.0)
		# On the ground, lower the pivot as she tucks so the ball rolls along the floor instead of floating
		tumble.position.y = -0.8 * (1.0 - s) if _spin_grounded else 0.0
	else:
		var k := 1.0 - exp(-18.0 * delta)
		tumble.rotation.x = lerp_angle(tumble.rotation.x, 0.0, k)
		tumble.scale = tumble.scale.lerp(Vector3.ONE, k)
		tumble.position.y = lerpf(tumble.position.y, 0.0, k)


func _sounds(delta: float, horizontal_speed: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		var ground := ground_kind()
		if ground == "mushroom" and _fall_speed > 2.0:
			velocity.y = MUSHROOM_BOUNCE              # boing: big mushroom caps are bouncy
			_air_jump_used = false
			Audio.play("boing", -2.0, 0.1)
		elif _fall_speed > 3.0:
			if ground == "cloud":
				velocity.y = minf(_fall_speed * 0.35, 4.0)   # a soft little bounce on a cloud
			Audio.play(LAND_SOUNDS.get(ground, "land"), linear_to_db(clampf(_fall_speed / 10.0, 0.3, 1.0)))
			# A squash and a puff of dust, more for a bigger fall; a little shake only for a really big one
			var hard := clampf((_fall_speed - 3.0) / 12.0, 0.0, 1.0)
			Juice.squash(model, 0.12 + 0.2 * hard, 0.22)
			Juice.burst(get_parent(), global_position + Vector3(0, 0.05, 0), Color(0.9, 0.85, 0.75, 0.7), 6 + int(8 * hard), 0.07, 1.2 + 2.0 * hard, 0.5)
			if hard > 0.4:
				Juice.shake(0.25 * hard)
				Juice.rumble(0.3 * hard, 0.12)
	_was_on_floor = on_floor
	# Footsteps while running on foot
	if on_floor and horizontal_speed > 0.8 and _roll_timer <= 0.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.33 * clampf(speed / horizontal_speed, 0.8, 1.6)
			Audio.play(STEP_SOUNDS.get(ground_kind(), "step"), -9.0, 0.15)
	else:
		_step_timer = 0.0


func enter_zone(zone: Node) -> void:
	if zone not in _zones:
		_zones.append(zone)


func exit_zone(zone: Node) -> void:
	_zones.erase(zone)


func in_zone(kind: String) -> bool:
	for z in _zones:
		if is_instance_valid(z) and z.get("kind") == kind:
			return true
	return false


func _floor_below() -> Node:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3(0, -1.3, 0))
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.collider as Node if not hit.is_empty() else null


func on_ice() -> bool:
	# Standing on ice (the Frozen Moment's lake and slides, scripts/frozen_moment.gd)
	return _floor_node != null and is_instance_valid(_floor_node) and _floor_node.is_in_group("ice")


func ground_kind() -> String:
	# Water and clouds she's in come first; otherwise whatever is under her feet
	for k in ["water", "bath", "spring", "cloud"]:
		if in_zone(k):
			return "cloud" if k == "cloud" else "water"
	return Surfaces.kind_of(_floor_node)


func _zone_min(prop: String, default: float) -> float:
	var v := default
	for z in _zones:
		if is_instance_valid(z):
			v = minf(v, float(z.get(prop)))
	return v


func _update_animation(horizontal_speed: float) -> void:
	if anim == null:
		return
	var target := "idle"
	if _spin_timer > 0.0:
		target = "fall"                     # arms and legs tucked in for the roll or flip
	elif not is_on_floor():
		target = "jump" if velocity.y > 0.0 else "fall"
	elif horizontal_speed > 0.3:
		target = "run"
	# assigned_animation sticks after a one-shot (jump) finishes, so it holds its last pose instead of restarting
	if anim.assigned_animation != target:
		anim.play(target, 0.15)
	# Match the stride to how fast she's actually moving
	anim.speed_scale = clampf(horizontal_speed / speed, 0.6, 1.8 if sprinting else 1.4) if target == "run" else 1.0
	if target == "run" and popper.aiming:
		anim.speed_scale = clampf(horizontal_speed / (speed * popper.AIM_MOVE), 0.6, 1.0)
