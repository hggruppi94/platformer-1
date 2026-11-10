extends CharacterBody3D

# The Hush: Dark Hollow's boss (plan item 21), a big shadow ghost that has been swallowing the hollow's moments of
# time. Like the little shadow ghosts (scripts/shadow_ghost.gd, it's made from the same look, much bigger) but it is
# made of the dark itself, so in the dark nothing can touch it: bubbles and stomps go right through.
#
# The trick is light. Four moon lamps stand round Hush Hill (scripts/dark_hollow.gd): while the Hush is within
# LIT_NEAR of a lit lamp it's caught in the light, goes pale and solid, and a bubble or a stomp hurts it. It hates the
# light, so when it gets right up to a lamp it hushes it out (snuff); light it again with Interact or a bubble (or wait:
# they come back on their own). Pip's glow, if you have it, lights it up too when it's close to you. After every hit it
# darts away into the dark, so lure it back to a lamp.
# Every so often it breathes out a "Shhhh" ring across the ground (ShockRing: jump it), and at HELP_AT hits it calls up
# little shadow ghosts. HITS hits and it bursts into the lost moments it swallowed, and the hollow mends
# (dark_hollow.gd mend()). Never more than a bump, like everything here.
#
# Made by scripts/dark_hollow.gd at the "Hush" marker, asleep (process off) until woken.

const SHADOW_GHOST := preload("res://scripts/shadow_ghost.gd")

const HITS := 8
const HELP_AT := [3, 6]                       # hits at which it calls up little ghosts
const LIT_NEAR := 6.0                         # metres from a lit lamp that count as in its light
const SNUFF_NEAR := 2.2                       # this close to a lit lamp and it hushes it out
const DRIFT := 1.9                            # m/s after you (you run at 5)
const RETREAT := 5.5                          # m/s darting off after a hit...
const RETREAT_TIME := 1.6                     # ...for this long
const RING_EVERY := 7.0
const RING_REACH := 9.0
const ARENA := 15.0                           # it never strays further than this from the hill
const HOVER := 1.2
const SIZE := 3.0
const PALE := Color(0.62, 0.55, 0.9)

var world: Node3D                             # scripts/dark_hollow.gd
var hits := 0
var defeated := false
var lit := false
var visual: Node3D
var player: CharacterBody3D
var home := Vector3.ZERO
var _bar: BossBar
var _t := 0.0
var _ring := RING_EVERY * 0.6
var _retreat := 0.0
var _away := Vector3.ZERO
var _lamp_hunt := 6.0
var _hunting := -1
var _told_dark := 0.0
var _told_lit := false
var _body_mat: StandardMaterial3D
var _hitbox: Area3D


func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
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
	hsp.radius = 0.62 * SIZE
	hcs.shape = hsp
	hcs.position.y = 0.95 * SIZE
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = SHADOW_GHOST.model(SIZE)
	visual.name = "Visual"
	add_child(visual)
	_body_mat = (visual.get_node("Body") as MeshInstance3D).material_override as StandardMaterial3D
	_crown()
	_bar = BossBar.make(self, "The Hush", PALE, 0.95 * SIZE * 2.0 + 0.6, 2.2)


func _crown() -> void:
	# A slow halo of dark wisps round its head: the moments it swallowed, still turning inside it
	var c := Node3D.new()
	c.name = "Crown"
	c.position.y = 0.95 * SIZE * 1.9
	visual.add_child(c)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.95, 1.0, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.6, 0.8, 1.0)
	m.emission_energy_multiplier = 1.2
	for k in 8:
		var w := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		w.mesh = sm
		w.material_override = m
		var a := k * TAU / 8.0
		w.position = Vector3(cos(a), sin(a * 2.0) * 0.15, sin(a)) * 1.1
		c.add_child(w)


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	_t += delta
	lit = world != null and world.call("lights_hush", global_position + Vector3(0, 0.95 * SIZE, 0))
	_look(delta)
	# Where to go: darting away after a hit; now and then off to hush a lamp; otherwise drifting after you
	var want := Vector3.ZERO
	if _retreat > 0.0:
		_retreat -= delta
		want = _away * RETREAT
	else:
		_lamp_hunt -= delta
		if _lamp_hunt <= 0.0 and _hunting < 0 and world:
			_hunting = int(world.call("nearest_lit_lamp", global_position))
			_lamp_hunt = randf_range(9.0, 13.0)
		var goal := player.global_position if player else home
		if _hunting >= 0 and world:
			if not bool(world.call("is_lamp_lit", _hunting)):
				_hunting = -1
			else:
				goal = (world.call("lamp_pos", _hunting) as Vector3)
		var to := goal - global_position
		to.y = 0.0
		if to.length() > 0.8:
			want = to.normalized() * DRIFT * (1.25 if hits >= HITS / 2 else 1.0) * Arsenal.slow(self)
	# Stay over the arena
	var from_home := global_position - home
	from_home.y = 0.0
	if from_home.length() > ARENA:
		want += -from_home.normalized() * 3.0
	velocity.x = move_toward(velocity.x, want.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, want.z, 12.0 * delta)
	velocity.y = (home.y + HOVER * 0.3 + sin(_t * 1.3) * 0.25 - global_position.y) * 3.0
	move_and_slide()
	if world:
		var near := int(world.call("nearest_lit_lamp", global_position, SNUFF_NEAR))
		if near >= 0:
			world.call("snuff_lamp", near)
			_hunting = -1
	_ring -= delta
	if _ring <= 0.0:
		_ring = RING_EVERY * (0.75 if hits >= HITS / 2 else 1.0)
		shush()
	if player and _hitbox.overlaps_body(player):
		_touch_player()
	_bar.fill = 1.0 - float(hits) / HITS


func _look(delta: float) -> void:
	# In the dark it's inky and hard to see; in the light it goes pale violet and its face shows
	var k := 1.0 if lit else 0.0
	var a := _body_mat.albedo_color
	var goal := Color(PALE, 0.95) if lit else Color(SHADOW_GHOST.BODY, 0.82)
	_body_mat.albedo_color = a.lerp(goal, 1.0 - exp(-6.0 * delta))
	_body_mat.emission_energy_multiplier = lerpf(_body_mat.emission_energy_multiplier, 0.8 * k + 0.25, 1.0 - exp(-6.0 * delta))
	var crown := visual.get_node("Crown") as Node3D
	crown.rotation.y += delta * (0.4 if Settings.reduce_motion else 1.0)
	var tail := visual.get_node("Tail") as Node3D
	tail.rotation.z = sin(_t * 2.0) * 0.18
	if player:
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-3.0 * delta))


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _touch_player() -> void:
	var feet := player.global_position.y - 0.8
	if lit and player.velocity.y < 0.5 and feet > global_position.y + 0.95 * SIZE:
		player.call("bounce", 9.0)
		hurt(1, Vector3.UP)
	elif not player.call("is_invulnerable"):
		player.call("hurt", 1, global_position)


func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	if defeated:
		return "miss"
	if not lit:
		_told_dark -= 1.0
		if _told_dark <= 0.0:
			_told_dark = 4.0
			Game.message("The bubble went straight through! In the dark the Hush is only shadow. Lure it into a lamp's light.")
		return "miss"
	hurt(mini(power, 2), dir)
	return "hit"


func hurt(amount: int, dir: Vector3) -> void:
	if defeated or not lit:
		return
	var before := hits
	hits = mini(hits + maxi(amount, 1), HITS)
	Juice.hitstop(0.05)
	Juice.shake(0.15)
	Juice.blip("pop", 0.7, -4.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.95 * SIZE, 0), Color(0.75, 0.95, 1.0), 16, 0.08, 3.0, -0.5, 0.8)
	if not _told_lit:
		_told_lit = true
		Game.message("Got it! In the light the Hush can be popped. It's darting off into the dark: lure it back to a lamp!")
	if hits >= HITS:
		defeat()
		return
	# Dart away from you into the dark
	var away := global_position - (player.global_position if player else global_position - dir)
	away.y = 0.0
	_away = away.normalized() if away.length() > 0.1 else Vector3(dir.x, 0, dir.z).normalized()
	_retreat = RETREAT_TIME
	for at in HELP_AT:
		if before < int(at) and hits >= int(at) and world:
			world.call("call_ghosts", global_position, 3)
			Game.message("The Hush calls up little shadow ghosts! Pop them, then lure it back into the light.")


func shush() -> void:
	# "Shhhh...": a ring of hush rolls out over the ground. Jump it!
	if world == null:
		return
	var ground: Vector3 = world.call("ground_below", global_position)
	ShockRing.spawn(get_parent(), ground, RING_REACH, Color(0.55, 0.45, 0.95), 1, 1.1)
	var label := Label3D.new()
	label.text = "Shhhhh..."
	label.font_size = 64
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = Color(0.8, 0.75, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.position = Vector3(0, 0.95 * SIZE * 2.0 + 1.2, 0)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y + 1.0, 1.2)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tw.tween_callback(label.queue_free)
	Juice.blip("whoosh", 0.6, -6.0)


func defeat() -> void:
	# It bursts into all the moments it swallowed, and they float up home to the Moon Clock
	defeated = true
	velocity = Vector3.ZERO
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	_bar.visible = false
	Game.add_xp(60)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 1.4, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.05, 0.25)
	tw.tween_callback(func() -> void: visual.visible = false)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.95 * SIZE, 0), Color(0.8, 0.95, 1.0), 50, 0.1, 6.0, -0.5, 1.4)
	Juice.shake(0.3)
	Juice.rumble(0.5, 0.4, 0.4)
	Juice.blip("chime", 0.8, -2.0)
	if world:
		world.call("mend")
