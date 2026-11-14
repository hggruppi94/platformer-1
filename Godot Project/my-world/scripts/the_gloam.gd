extends CharacterBody3D

# The Gloam: the shadow ghosts' boss, a towering ghost of dusk with a long trailing tail and a ring of little dim stars
# round its head (every enemy gets a bigger boss version: Hayden, Nov 1, 2026). It only lives in the Star Arena
# (scripts/arena_level.gd), one of its three bosses you meet nowhere else, with the arena's lights down.
#
# Like Dark Hollow's Hush it's made of the dark itself, so in the dark nothing touches it: bubbles and stomps go
# right through. But the Star Arena has four great SPOTLIGHTS whose beams sweep round the floor (world.lit_at()): when
# the Gloam drifts into a beam it's caught, goes pale and solid, and then a bubble or a stomp counts. It doesn't like
# the light, so it steers round the beams when it can: lead it into one. After each hit it darts off into the dark.
# Every few seconds it lets out a gloom wave (scripts/shock_ring.gd: jump it), and at HELP_AT hits it calls up little
# shadow ghosts. Past half it's cross: quicker, and waves more often. HITS hits and it bursts into a shower of
# evening stars. Kid-safe: big friendly eyes, a bump never more.
#
# Built in code: GLOAM.new(), with `world`, `centre` and `reach` set.

const SHADOW_GHOST := preload("res://scripts/shadow_ghost.gd")

const HITS := 13
const HELP_AT := [4, 9]
const SIZE := 3.2
const SINK := 0.9                            # it floats this low (its tail trails into the floor), so it's in jumping reach
const DRIFT := 2.0                            # m/s after you (you run at 5)
const RETREAT := 6.0
const RETREAT_TIME := 1.5
const WAVE_EVERY := 6.5
const WAVE_REACH := 9.0
const PALE := Color(0.95, 0.75, 0.55)         # caught in the light: a warm pale gold, like a sunset
const DUSK := Color(0.12, 0.07, 0.25)
const STARS := Color(1.0, 0.9, 0.6)

signal popped(who: Node3D)

var world: Node                               # the arena: lit_at(pos)
var centre := Vector3.ZERO
var reach := 20.0
var hits := 0
var defeated := false
var lit := false
var cross := false
var visual: Node3D
var player: CharacterBody3D
var _t := 0.0
var _wave := WAVE_EVERY * 0.6
var _retreat := 0.0
var _away := Vector3.ZERO
var _helped := 0
var _ground_y := 0.0
var _told_dark := 0.0
var _told_lit := false
var _body_mat: StandardMaterial3D
var _hitbox: Area3D
var _halo: Node3D


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	Arsenal.supply_boss(self)                       # ammo crates round the fight (scripts/arsenal.gd)
	_ground_y = global_position.y
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0                         # it floats through everything (it keeps over the floor itself)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5 * SIZE
	cs.shape = sp
	cs.position.y = 0.95 * SIZE
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hsp := SphereShape3D.new()
	hsp.radius = 0.6 * SIZE
	hcs.shape = hsp
	hcs.position.y = 0.95 * SIZE
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = SHADOW_GHOST.model(SIZE)
	add_child(visual)
	# Its own dusk colour, and a material of its own so it can go pale
	var body := visual.get_node("Body") as MeshInstance3D
	var shadow := body.material_override
	_body_mat = (shadow as StandardMaterial3D).duplicate() as StandardMaterial3D
	_body_mat.albedo_color = Color(DUSK, 0.85)
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override == shadow:
			(mi as MeshInstance3D).material_override = _body_mat
	_add_halo()
	BossBar.make(self, "The Gloam", PALE, 1.5 * SIZE + 0.9, 2.2).name = "Meter"


func _add_halo() -> void:
	# A ring of little dim evening stars round its head
	_halo = Node3D.new()
	_halo.name = "Halo"
	_halo.position.y = 1.15 * SIZE + 0.3
	visual.add_child(_halo)
	var m := StandardMaterial3D.new()
	m.albedo_color = STARS
	m.emission_enabled = true
	m.emission = STARS
	m.emission_energy_multiplier = 1.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 7:
		var s := MeshInstance3D.new()
		s.mesh = StarBubble.star_mesh()
		s.material_override = m
		s.scale = Vector3.ONE * 0.35
		var a := k * TAU / 7.0
		s.position = Vector3(cos(a), 0, sin(a)) * 0.9 * SIZE * 0.5
		_halo.add_child(s)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _middle() -> Vector3:
	return global_position + Vector3(0, 0.95 * SIZE, 0)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	_told_dark = maxf(_told_dark - delta, 0.0)
	lit = world != null and bool(world.call("lit_at", _middle()))
	var h := Vector3.ZERO
	if _retreat > 0.0:
		_retreat -= delta
		h = _away * RETREAT
	elif player:
		var to := player.global_position - global_position
		to.y = 0
		if to.length() > 1.2:
			h = to.normalized() * DRIFT * (1.3 if cross else 1.0) * Arsenal.slow(self)
		# It steers round the beams when it sees one coming (a little: lead it into one)
		if world and world.has_method("beam_push"):
			h += (world.call("beam_push", global_position) as Vector3) * 1.4
	var off := global_position - centre
	off.y = 0
	if off.length() > reach:
		h += -off.normalized() * 4.0
	velocity.x = move_toward(velocity.x, h.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, h.z, 14.0 * delta)
	var bob := sin(_t * 1.8) * 0.3 * (0.3 if Settings.reduce_motion else 1.0)
	velocity.y = (_ground_y - SINK + bob - global_position.y) * 3.0
	move_and_slide()
	_wave -= delta
	if _wave <= 0.0:
		_wave = (WAVE_EVERY * 0.65 if cross else WAVE_EVERY) * randf_range(0.9, 1.1)
		gloom_wave()
	_look(delta)
	(get_node("Meter") as BossBar).fill = 1.0 - float(hits) / HITS
	if player and _hitbox.overlaps_body(player):
		_touch_player()


func _look(delta: float) -> void:
	var goal := Color(PALE, 0.95) if lit else Color(DUSK, 0.85)
	_body_mat.albedo_color = _body_mat.albedo_color.lerp(goal, 1.0 - exp(-8.0 * delta))
	_body_mat.emission_enabled = true
	_body_mat.emission = PALE
	_body_mat.emission_energy_multiplier = lerpf(_body_mat.emission_energy_multiplier, 0.6 if lit else 0.0, 1.0 - exp(-8.0 * delta))
	if player:
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-3.0 * delta))
	var tail := visual.get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.z = sin(_t * 3.0) * 0.25
	_halo.rotation.y += delta * 0.8
	if lit and not _told_lit and hits == 0:
		_told_lit = true
		Game.message("The spotlight's caught the Gloam! In the light it can be popped: quick!")


func gloom_wave() -> void:
	ShockRing.spawn(get_parent(), Vector3(global_position.x, _ground_y, global_position.z), WAVE_REACH, DUSK.lightened(0.3), 2, 1.0)
	Juice.blip("whoosh", 0.5, -6.0)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if lit and player.velocity.y < 0.5 and feet > global_position.y + 0.95 * SIZE:
		player.call("bounce", 9.0)
		hurt(1, player.global_position - global_position)
		return
	if lit and player.call("is_rolling"):
		hurt(1, player.global_position - global_position)
		return
	if _retreat <= 0.0 and not player.call("is_invulnerable"):
		player.call("hurt", 2, global_position)


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	if not lit:
		if _told_dark <= 0.0:
			Game.message("The bubble went straight through! In the dark the Gloam is only shadow. Lead it into a spotlight.")
			_told_dark = 8.0
		return "miss"
	hurt(mini(power, 1), dir)
	return "hit"


func hurt(n: int, dir: Vector3) -> void:
	if defeated or n <= 0 or _retreat > 0.0:
		return
	hits += n
	Juice.hitstop(0.05)
	Juice.shake(0.25)
	Fx.burst(get_parent(), _middle(), STARS, 12, 0.08, 3.0, 0.0, 0.6)
	Juice.blip("chime", 0.8, -4.0)
	if hits >= HITS:
		_burst()
		return
	var left := HITS - hits
	Game.message("The Gloam shivers in the light! %d more to pop it." % left if left > 1 else "One more and the Gloam pops!")
	# Dart off into the dark, away from you
	var away := -dir
	away.y = 0
	_away = (away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)).rotated(Vector3.UP, randf_range(-0.6, 0.6))
	_retreat = RETREAT_TIME
	if not cross and hits * 2 >= HITS:
		cross = true
		Game.message("The Gloam is cross! It's quicker now, and its gloom waves come more often.")
	while _helped < HELP_AT.size() and hits >= int(HELP_AT[_helped]):
		_helped += 1
		_call_ghosts(3)


func _call_ghosts(n: int) -> void:
	for k in n:
		var g := SHADOW_GHOST.new() as CharacterBody3D
		g.name = "Gloam Ghost"
		g.set("sight_range", 30.0)
		g.set("leash_range", 60.0)
		var a := k * TAU / n + randf()
		var where := Vector3(global_position.x, _ground_y, global_position.z) + Vector3(cos(a), 0, sin(a)) * 3.5
		var parent := get_parent() as Node3D
		g.position = parent.to_local(where) if parent else where
		get_parent().add_child(g)
		Fx.burst(get_parent(), where + Vector3(0, 1, 0), SHADOW_GHOST.SHEEN, 8, 0.06, 1.5, 0.0, 0.4)
	Game.message("The Gloam calls up little shadow ghosts!")


func _burst() -> void:
	defeated = true
	velocity = Vector3.ZERO
	(get_node("Meter") as Node3D).visible = false
	_hitbox.set_deferred("monitoring", false)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var at := _middle()
	Fx.burst(get_parent(), at, STARS, 30, 0.1, 4.0, -1.0, 1.2)
	Fx.burst(get_parent(), at, PALE, 20, 0.12, 3.0, 0.0, 1.0)
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	Juice.blip("sparkle", 0.9, -2.0)
	Game.add_xp(50)
	Game.message("You popped the Gloam! It bursts into a sky full of evening stars.")
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.6, 0.05, 1.6), 0.3)
	tw.tween_callback(func() -> void: visual.visible = false)
	popped.emit(self)
	if world and world.has_method("boss_popped"):
		world.call("boss_popped", self)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
