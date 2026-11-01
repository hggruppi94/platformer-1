extends CharacterBody3D

# A Time Goblin, one of the Agent of Chaos's cheeky helpers (Hayden, Nov 1, 2026). A round teal goblin with a gold
# pocket watch in its belly whose hands run backwards. Its trick: it remembers where it was, and when a bubble is about
# to catch it (or it's been stomped on but not popped) it BLINKS BACK IN TIME to where it stood a couple of seconds ago,
# leaving a trail of see-through ghosts. A blink leaves it dizzy for a moment, so the way to catch one is to make it
# blink, then pop it while its watch is still spinning. It can only blink every few seconds.
# It's quick (but slower than the player), and if it bumps you it snatches a sparkle and runs off giggling; pop it and
# you get the sparkle back. Kid-safe: it bumps, it never hurts more than a Gloop, and it's carried off in a bubble.
# Scene: scenes/enemies/time_goblin.tscn (built by tools/build_time_goblin.gd); placed at runtime by scripts/bosses.gd.
# The boss version is scripts/time_goblin_boss.gd (Grandfather Tock).

@export_group("Stats")
@export var size := 1.0
@export var color := Color(0.2, 0.85, 0.75)    # the colour of its pop sparkles
@export var stomps_to_defeat := 1
@export var damage := 1
@export var xp_reward := 6

@export_group("Behaviour")
@export var wander_radius := 7.0
@export var sight_range := 13.0
@export var leash_range := 26.0
@export var wander_speed := 1.8
@export var chase_speed := 4.0                 # quicker than a Gloop, still slower than the player (5)
@export var flee_speed := 4.6
@export var turn_speed := 10.0
@export var respawn_time := 45.0
@export var respawns := true
@export var respawn_clear := 15.0
@export var ram_speed := 7.0
@export var blink_back := 2.0                  # seconds back in time a blink takes it
@export var blink_cooldown := 5.0              # seconds before it can blink again
@export var blink_chance := 0.75               # how often it notices a bubble in time
@export var dizzy_time := 1.4                  # after a blink: stands still, watch spinning, easy to pop

const STOMP_BOUNCE := 8.0
const LOW_GROUND := -0.25
const DODGE_RANGE := 4.5                       # a bubble this close and heading its way makes it blink
const HISTORY_STEP := 0.1                      # seconds between remembered spots
const HISTORY_KEEP := 4.0                      # seconds of them kept

enum State { WANDER, CHASE, FLEE, DIZZY }

var home := Vector3.ZERO
var target := Vector3.ZERO
var hits := 0
var defeated := false
var player: Player
var state := State.WANDER
var carried := 0                               # sparkles it has snatched, given back when it pops

var _t := 0.0
var _retarget := 0.0
var _state_t := 0.0
var _blink_cd := 0.0
var _hist: Array[Vector3] = []
var _hist_t := 0.0
var _squash := 0.0
var _respawn_timer: Timer
var _seen_bubbles := {}                        # bubbles it already decided about (so one bubble = one roll)
var _was_chasing := false
var _giggle_cd := 0.0
var _loot: Node3D

@onready var visual: Node3D = $Visual
@onready var hitbox: Area3D = $Hitbox
@onready var shape: CollisionShape3D = $CollisionShape3D
@onready var _hour: Node3D = $Visual/Watch/Hour
@onready var _minute: Node3D = $Visual/Watch/Minute
@onready var _legs: Array[Node3D] = [$Visual/LegL, $Visual/LegR]
@onready var _arms: Array[Node3D] = [$Visual/ArmL, $Visual/ArmR]
@onready var _head: Node3D = $Visual/Head


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("time_goblins")
	home = global_position
	target = home
	_t = randf() * 10.0
	var cap := (shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
	cap.radius *= size
	cap.height *= size
	shape.shape = cap
	shape.position *= size
	var hcs := hitbox.get_child(0) as CollisionShape3D
	var hs := (hcs.shape as SphereShape3D).duplicate() as SphereShape3D
	hs.radius *= size
	hcs.shape = hs
	hcs.position *= size
	visual.scale = Vector3.ONE * size
	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_try_respawn)
	add_child(_respawn_timer)
	_make_loot()


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	_state_t -= delta
	_blink_cd -= delta
	_giggle_cd -= delta
	_remember(delta)
	_watch_for_bubbles()

	var speed := wander_speed
	match state:
		State.DIZZY:
			speed = 0.0
			if _state_t <= 0.0:
				state = State.WANDER
		State.FLEE:
			speed = flee_speed
			if player:
				var away := global_position - player.global_position
				away.y = 0
				target = global_position + away.normalized() * 6.0
			if _state_t <= 0.0:
				state = State.WANDER
		_:
			var chasing := _can_see_player()
			state = State.CHASE if chasing else State.WANDER
			if chasing:
				target = player.global_position
				speed = chase_speed
				if not _was_chasing and _giggle_cd <= 0.0:
					_giggle()
			else:
				_retarget -= delta
				if _retarget <= 0.0 or _flat(target - global_position) < 0.4:
					var a := randf() * TAU
					target = home + Vector3(cos(a), 0, sin(a)) * randf() * wander_radius
					_retarget = randf_range(1.5, 3.5)
	_was_chasing = state == State.CHASE
	if global_position.y < LOW_GROUND:
		target = home
	_steer(delta, speed)
	_animate(delta)
	if player and hitbox.overlaps_body(player):
		_touch_player()


func _can_see_player() -> bool:
	if player == null or player.is_recovering():
		return false
	var to_p := player.global_position - global_position
	return _flat(to_p) < sight_range and absf(to_p.y) < 4.0 and _flat(player.global_position - home) < leash_range


func _steer(delta: float, speed: float) -> void:
	var to_t := target - global_position
	to_t.y = 0
	var want := Vector3.ZERO
	if _squash <= 0.0 and speed > 0.0 and to_t.length() > 0.3:
		want = to_t.normalized() * speed * Arsenal.slow(self)
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(want, 16.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	if h.length() > 0.2:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(h.x, h.z), 1.0 - exp(-turn_speed * delta))
	elif state == State.DIZZY or (player and state != State.FLEE):
		pass


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Player
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


# --- Time ----------------------------------------------------------------------------------------------------------

func _remember(delta: float) -> void:
	_hist_t -= delta
	if _hist_t > 0.0:
		return
	_hist_t = HISTORY_STEP
	_hist.append(global_position)
	var keep := int(HISTORY_KEEP / HISTORY_STEP)
	if _hist.size() > keep:
		_hist = _hist.slice(_hist.size() - keep)


func can_blink() -> bool:
	return not defeated and _blink_cd <= 0.0 and state != State.DIZZY and _hist.size() > 3


func blink() -> bool:
	# Back in time: it jumps to where it stood `blink_back` seconds ago, leaving ghosts along the way it came
	if not can_blink():
		return false
	var steps := mini(int(blink_back / HISTORY_STEP), _hist.size() - 1)
	var to: Vector3 = _hist[_hist.size() - 1 - steps]
	var parent := get_parent()
	var n := 4
	for i in n:
		var at: Vector3 = _hist[_hist.size() - 1 - int(steps * float(i) / n)]
		_ghost(at, 0.15 + 0.1 * i)
	Fx.burst(parent, global_position + Vector3(0, 0.5 * size, 0), Color(0.6, 1.0, 0.95), 10, 0.06, 2.5, 0.0, 0.5)
	global_position = to
	velocity = Vector3.ZERO
	_hist = _hist.slice(0, _hist.size() - steps)
	Fx.burst(parent, to + Vector3(0, 0.5 * size, 0), Color(1.0, 0.85, 0.35), 12, 0.07, 2.5, 0.0, 0.5)
	Juice.blip("rewind", 1.0 / sqrt(size), -6.0)
	_blink_cd = blink_cooldown
	state = State.DIZZY
	_state_t = dizzy_time
	_blinked()
	return true


func _watch_for_bubbles() -> void:
	if not can_blink():
		return
	var me := global_position + Vector3(0, 0.5 * size, 0)
	for b in get_tree().get_nodes_in_group("star_bubbles"):
		var bub := b as Node3D
		if bub == null or _seen_bubbles.has(bub.get_instance_id()):
			continue
		var to := me - bub.global_position
		if to.length() > DODGE_RANGE + size:
			continue
		var v: Vector3 = bub.get("velocity") if bub.get("velocity") != null else Vector3.ZERO
		if v.length() < 0.5 or v.normalized().dot(to.normalized()) < 0.6:
			continue
		_seen_bubbles[bub.get_instance_id()] = true
		if _seen_bubbles.size() > 32:
			_seen_bubbles.clear()
		if randf() < blink_chance:
			blink()
			return


func _ghost(at: Vector3, fade: float) -> void:
	# A see-through copy of the goblin, left behind as it rewinds
	var g := visual.duplicate(0) as Node3D
	g.name = "TimeGhost"
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.55, 1.0, 0.95, 0.35)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(g)
	g.global_position = at
	g.global_rotation = visual.global_rotation
	g.scale = visual.scale
	var tw := g.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, fade + 0.3)
	tw.tween_callback(g.queue_free)


# --- Touching, stomps and bubbles ----------------------------------------------------------------------------------

func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if player.velocity.y < 0.5 and feet > global_position.y + 0.55 * size:
		_stomped()
	elif player.is_rolling() or (Game.riding and _flat(player.velocity) >= ram_speed):
		hits = stomps_to_defeat
		_defeat()
	elif not player.is_invulnerable():
		player.hurt(damage, global_position)
		_snatch()


func _snatch() -> void:
	# It nicks a sparkle and runs off giggling (pop it to get it back)
	if Game.sparkles > 0 and Game.spend_sparkles(1):
		carried += 1
		Game.message("A Time Goblin snatched a sparkle! Pop it to get it back.")
	state = State.FLEE
	_state_t = 3.0
	_giggle()


func _stomped() -> void:
	hits += 1
	player.bounce(STOMP_BOUNCE)
	Audio.play_at("stomp", global_position, 0.0, 0.2)
	Juice.hitstop(0.04)
	Juice.shake(0.1)
	if hits >= stomps_to_defeat:
		_defeat()
	else:
		_squash = 0.4
		_hurt_message(true)
		blink()


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	_find_player()
	hits += power
	if hits >= stomps_to_defeat:
		_defeat(true)
	else:
		_squash = 0.4
		velocity += Vector3(dir.x, 0, dir.z).normalized() * 3.0
		_hurt_message(false)
	return "hit"


func _defeat(bubbled := false) -> void:
	defeated = true
	velocity = Vector3.ZERO
	Requests.note("time_goblin", 1.0, "bubble" if bubbled else "stomp")
	Game.add_xp(xp_reward)
	_popup("+%d XP" % xp_reward)
	if carried > 0:
		Game.add_sparkles(carried, "Got your sparkles back!")
		carried = 0
	_loot.visible = false
	shape.set_deferred("disabled", true)
	hitbox.set_deferred("monitoring", false)
	if bubbled:
		StarBubble.carry_off(self, visual, color, size)
	else:
		Audio.play_at("pop", global_position, 0.0, 0.1)
		var tw := create_tween()
		tw.tween_property(visual, "scale", Vector3(1.6, 0.1, 1.6) * size, 0.12)
		tw.tween_callback(func(): visual.visible = false)
		Fx.burst(get_parent(), global_position + Vector3(0, 0.4, 0), color, 16, 0.08, 3.0, -1.0, 0.6)
	_defeated()
	if respawns:
		_respawn_timer.start(respawn_time)
	else:
		get_tree().create_timer(2.5).timeout.connect(queue_free)


func _try_respawn() -> void:
	if player and is_instance_valid(player) and player.global_position.distance_to(home) < respawn_clear:
		_respawn_timer.start(3.0)
		return
	global_position = home
	velocity = Vector3.ZERO
	hits = 0
	_squash = 0.0
	_hist.clear()
	state = State.WANDER
	defeated = false
	shape.set_deferred("disabled", false)
	hitbox.set_deferred("monitoring", true)
	visual.visible = true
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE * 0.05
	create_tween().tween_property(visual, "scale", Vector3.ONE * size, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- Looks ---------------------------------------------------------------------------------------------------------

func _animate(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	var spin := 1.0
	if state == State.DIZZY:
		spin = 9.0
	elif state == State.CHASE or state == State.FLEE:
		spin = 3.0
	if not Settings.reduce_motion or state != State.DIZZY:
		_minute.rotation.z += delta * 2.4 * spin        # anticlockwise from the front: time running backwards
		_hour.rotation.z += delta * 0.2 * spin
	var freq := 12.0 if moving > 2.5 else 7.0
	var swing := sin(_t * freq) * clampf(moving / 3.0, 0.0, 1.0)
	_legs[0].rotation.x = swing * 0.7
	_legs[1].rotation.x = -swing * 0.7
	_arms[0].rotation.x = -swing * 0.8
	_arms[1].rotation.x = swing * 0.8
	var bob := absf(sin(_t * freq)) * 0.05 * clampf(moving / 2.0, 0.0, 1.0)
	visual.position.y = bob * size
	if state == State.DIZZY:
		_head.rotation.z = sin(_t * 10.0) * 0.25
		visual.rotation.y += delta * 3.0
	elif state == State.FLEE:
		_head.rotation.z = sin(_t * 18.0) * 0.12           # giggling as it runs
		_arms[0].rotation.x = -2.6
		_arms[1].rotation.x = -2.6
	else:
		_head.rotation.z = lerpf(_head.rotation.z, 0.0, 1.0 - exp(-8.0 * delta))
	if _squash > 0.0:
		_squash -= delta
		var k := _squash / 0.4
		visual.scale = Vector3(1.0 + 0.3 * k, 1.0 - 0.3 * k, 1.0 + 0.3 * k) * size
	else:
		visual.scale = Vector3.ONE * size
	_loot.visible = carried > 0
	if carried > 0:
		_loot.rotation.y += delta * 3.0


func _make_loot() -> void:
	# The sparkle it's carrying, held up over its head
	_loot = Node3D.new()
	_loot.name = "Loot"
	add_child(_loot)
	_loot.position = Vector3(0, 1.35 * size, 0)
	var star := MeshInstance3D.new()
	star.mesh = StarBubble.star_mesh()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.3)
	m.emission_energy_multiplier = 2.0
	star.material_override = m
	star.scale = Vector3.ONE * 0.6
	_loot.add_child(star)
	_loot.visible = false


func _giggle() -> void:
	Audio.play_at("gloop_giggle", global_position, -4.0, 0.5 / sqrt(size))
	_giggle_cd = 5.0


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
	label.global_position = global_position + Vector3(0, 1.5 * size, 0)
	var tw := label.create_tween().set_parallel()
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.2, 1.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)


# --- Hooks for Grandfather Tock (scripts/time_goblin_boss.gd) -------------------------------------------------------

func _hurt_message(stomped: bool) -> void:
	Game.message("The Time Goblin blinked back in time! Pop it while it's dizzy." if stomped
		else "Got it! Once more!")


func _blinked() -> void:
	pass


func _defeated() -> void:
	pass
