extends CharacterBody3D

# Captain Glitch: the Far Future's boss (plan item 19a world 8, scripts/far_future.gd), the Agent of Chaos's lieutenant.
# A tall knight made of purple glitch cubes with a cape of static and a cracked little clock on his chest, like his
# master's. He's been hiding in Lumen City, feeding on its fading, flickering on the Tomorrow Clock's dais like a statue.
# When all three Time Cores are home and you come near, he wakes up (wake()).
#
# How he fights (kid-safe: bumps, and a pop at the end):
#   HOVER  he floats over the dais, drifting after you, and every VOLLEY_EVERY seconds marks the ground with chaos
#          bursts (scripts/chaos_burst.gd, his master's: a glowing mark that pops in glitch cubes; move off it)
#   SLAM   after VOLLEYS volleys he drops down with a thud and a ring rolls out (ShockRing: jump it)
#   OPEN   then he's dazed on the ground for OPEN_TIME and the clock on his chest glows: bubbles and stomps count now,
#          at most HITS_PER_OPEN times, then he glitches back up into the air
#   While he's not open, bubbles bounce off his armour and touching him bumps you.
# At HELP_AT hits he tears open a glitch rift and two Time Goblins tumble out. HITS hits and he comes apart into glitch
# cubes, shouts that his master's waiting in the Void, and blinks away through a rift: the world mends
# (far_future.gd mend()).

enum State { STATUE, HOVER, SLAM, OPEN }

const GOBLIN := preload("res://scenes/enemies/time_goblin.tscn")

const HITS := 9
const HITS_PER_OPEN := 3
const HELP_AT := [3, 6]
const VOLLEYS := 3
const VOLLEY_EVERY := 2.4
const OPEN_TIME := 4.5
const HOVER_Y := 3.6                          # metres over the dais while he's flying
const DRIFT := 2.6                            # m/s after you (you run at 5)
const ARENA_IN := 5.5                         # he stays out of the clock's spire...
const ARENA_OUT := 12.0                       # ...and over the dais
const RING_REACH := 11.0
const PURPLE := Color(0.62, 0.3, 1.0)
const MAGENTA := Color(1.0, 0.3, 0.8)
const GOLD := Color(1.0, 0.82, 0.35)

var world: Node3D                             # scripts/far_future.gd
var state := State.STATUE
var hits := 0
var defeated := false
var title := "Captain Glitch"
var visual: Node3D
var player: CharacterBody3D
var minions: Array = []
var _bar: BossBar
var _t := 0.0
var _timer := 0.0
var _volleys := 0
var _open_hits := 0
var _ground_y := 0.0
var _hitbox: Area3D
var _clock_mat: StandardMaterial3D
var _cubes: Node3D


func _ready() -> void:
	add_to_group("enemies")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 3.6
	cs.shape = cap
	cs.position.y = 1.8
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 1.15
	hcap.height = 4.0
	hcs.shape = hcap
	hcs.position.y = 1.8
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = model()
	visual.name = "Visual"
	add_child(visual)
	_clock_mat = (visual.get_node("Chest Clock") as MeshInstance3D).material_override as StandardMaterial3D
	_cubes = visual.get_node("Glitch Cubes") as Node3D
	_bar = BossBar.make(self, title, MAGENTA, 4.6, 2.2)
	_bar.visible = false
	_ground_y = global_position.y


func wake() -> void:
	# Called by the world (it switches his process back on first)
	_ground_y = global_position.y
	_bar.visible = true
	_set_state(State.HOVER)
	_find_player()
	Fx.burst(get_parent(), global_position + Vector3(0, 2.0, 0), PURPLE, 36, 0.12, 5.0, -1.0, 1.0)
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("buzz", 0.6, -2.0)
	_say("I am CAPTAIN GLITCH! And my master's clock runs BACKWARDS!")
	Game.message("Captain Glitch wakes up! Dodge the glowing marks. When he crashes down, jump the ring, then pop the clock on his chest while it glows!")


func _set_state(s: State) -> void:
	state = s
	match s:
		State.HOVER:
			_volleys = 0
			_timer = VOLLEY_EVERY * 0.6
		State.SLAM:
			_timer = 0.5
		State.OPEN:
			_timer = OPEN_TIME
			_open_hits = 0


func is_open() -> bool:
	return state == State.OPEN and not defeated


func _physics_process(delta: float) -> void:
	if defeated or state == State.STATUE:
		return
	_find_player()
	_t += delta
	_timer -= delta
	_tidy_minions()
	var centre: Vector3 = world.call("arena_centre") if world else _ground_home()
	match state:
		State.HOVER:
			var goal := player.global_position if player else centre
			var to := goal - global_position
			to.y = 0.0
			var want := to.normalized() * DRIFT * Arsenal.slow(self) if to.length() > 2.5 else Vector3.ZERO
			velocity.x = move_toward(velocity.x, want.x, 8.0 * delta)
			velocity.z = move_toward(velocity.z, want.z, 8.0 * delta)
			velocity.y = (_ground_y + HOVER_Y + sin(_t * 1.6) * 0.3 - global_position.y) * 3.0
			if _timer <= 0.0:
				_volley()
				_volleys += 1
				_timer = VOLLEY_EVERY * (0.8 if hits >= HITS / 2 else 1.0)
				if _volleys >= VOLLEYS:
					_set_state(State.SLAM)
		State.SLAM:
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y = -14.0
			if global_position.y <= _ground_y + 0.05 or _timer <= 0.0:
				global_position.y = _ground_y
				velocity = Vector3.ZERO
				_landed()
		State.OPEN:
			velocity = Vector3.ZERO
			if _timer <= 0.0 or _open_hits >= HITS_PER_OPEN:
				_rise()
	_keep_in_arena(centre)
	move_and_slide()
	_animate(delta)
	if player and _hitbox.overlaps_body(player):
		_touch_player()
	_bar.fill = 1.0 - float(hits) / HITS


func _ground_home() -> Vector3:
	return Vector3(global_position.x, _ground_y, global_position.z)


func _keep_in_arena(centre: Vector3) -> void:
	var off := global_position - centre
	off.y = 0.0
	var d := off.length()
	if d < 0.01:
		return
	if d < ARENA_IN:
		global_position += off.normalized() * (ARENA_IN - d)
	elif d > ARENA_OUT:
		global_position -= off.normalized() * (d - ARENA_OUT)


func _volley() -> void:
	# Chaos bursts: one right where you're standing, more round about (bigger volleys once he's cross)
	if player == null:
		return
	var n := 2 if hits < HITS / 2 else 3
	_burst_at(player.global_position, 1.3)
	for k in n:
		var a := randf() * TAU
		_burst_at(player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 5.5), 1.5)
	Juice.blip("buzz", 1.2, -8.0)
	_cubes.rotation.y += 1.0


func _burst_at(at: Vector3, warn: float) -> void:
	var b := ChaosBurst.new()
	b.warn = warn
	b.damage = 1
	get_parent().add_child(b)
	var ground: Vector3 = world.call("ground_below", at) if world else Vector3(at.x, _ground_y, at.z)
	b.global_position = ground


func _landed() -> void:
	# CRASH: a ring rolls out (jump it), and he's dazed with his chest clock glowing
	ShockRing.spawn(get_parent(), global_position, RING_REACH, MAGENTA, 1, 1.0)
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.5, 0.3)
	Juice.blip("thud", 0.7, -3.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 0.3, 0), PURPLE, 24, 0.12, 4.0, -2.0, 0.7)
	_set_state(State.OPEN)
	_say(["Bzzt! Error! ERROR!", "My armour! It's lagging!", "Stop that, it TICKLES!"][randi() % 3])


func _rise() -> void:
	Fx.burst(get_parent(), global_position + Vector3(0, 1.5, 0), PURPLE, 16, 0.1, 3.0, 0.0, 0.6)
	Juice.blip("whoosh", 0.9, -6.0)
	_set_state(State.HOVER)


func _animate(delta: float) -> void:
	# His clock glows while he's open; his glitch cubes spin round him; he jitters now and then, like bad signal
	var open := state == State.OPEN
	_clock_mat.emission_energy_multiplier = lerpf(_clock_mat.emission_energy_multiplier, 3.0 if open else 0.3, 1.0 - exp(-8.0 * delta))
	_clock_mat.albedo_color = GOLD if open else Color(0.4, 0.35, 0.5)
	_cubes.rotation.y += delta * (0.6 if Settings.reduce_motion else 1.8)
	visual.position.x = (randf_range(-0.08, 0.08) if randf() < 0.08 and not Settings.reduce_motion else 0.0)
	visual.rotation.z = sin(_t * 1.2) * 0.04 if not open else sin(_t * 10.0) * 0.08
	if player:
		var to := player.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _say(text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.01
	label.outline_size = 12
	label.modulate = Color(1.0, 0.8, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	label.position = Vector3(0, 5.4, 0)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y + 0.8, 2.4)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 2.4).set_delay(1.2)
	tw.tween_callback(label.queue_free)


# Getting hit ------------------------------------------------------------------------------------------------------------
func shot(power: int, _point: Vector3, dir: Vector3) -> String:
	if defeated or state == State.STATUE:
		return "miss"
	if not is_open():
		return "bounce"                          # his armour: boing
	hurt(mini(power, 2), dir)
	return "hit"


func hurt(amount: int, _dir: Vector3) -> void:
	if defeated or not is_open():
		return
	var before := hits
	hits = mini(hits + maxi(amount, 1), HITS)
	_open_hits += 1
	Juice.hitstop(0.05)
	Juice.shake(0.15)
	Juice.blip("pop", 0.7, -4.0)
	Fx.burst(get_parent(), global_position + Vector3(0, 2.2, 0), GOLD, 16, 0.08, 3.0, -0.5, 0.8)
	if hits >= HITS:
		defeat()
		return
	for at in HELP_AT:
		if before < int(at) and hits >= int(at):
			_summon()


func _touch_player() -> void:
	# Dazed on the ground, a stomp on his helmet counts (and bounces you off); in the air, touching him bumps you
	var feet := player.global_position.y - 0.8
	if is_open():
		if player.velocity.y < 0.5 and feet > global_position.y + 3.0:
			player.call("bounce", 9.0)
			hurt(1, Vector3.DOWN)
		return
	if not player.call("is_invulnerable"):
		player.call("hurt", 1, global_position)


func _summon() -> void:
	# A glitch rift tears open and two Time Goblins tumble out
	_say("Minions! To me!")
	Game.message("Captain Glitch tears open a glitch rift! Time Goblins tumble out. Pop them too!")
	for k in 2:
		var a := randf() * TAU
		var spot := global_position + Vector3(cos(a), 0, sin(a)) * 4.0
		var ground: Vector3 = world.call("ground_below", spot) if world else spot
		var g := GOBLIN.instantiate() as Node3D
		g.name = "Glitch Minion %d" % randi_range(100, 999)
		g.set("respawns", false)
		g.position = ground + Vector3(0, 0.4, 0)
		get_parent().add_child(g)
		minions.append(g)
		Fx.burst(get_parent(), ground + Vector3(0, 0.6, 0), PURPLE, 16, 0.12, 2.5, 1.0, 0.7)
		Fx.burst(get_parent(), ground + Vector3(0, 0.6, 0), GOLD, 8, 0.08, 2.0, 1.0, 0.6)


func _tidy_minions() -> void:
	minions = minions.filter(func(n) -> bool: return is_instance_valid(n) and n.get("defeated") != true)


func defeat() -> void:
	# He comes apart into glitch cubes, shouts for his master, and blinks away through a rift
	defeated = true
	velocity = Vector3.ZERO
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	_bar.visible = false
	for m in minions:
		if is_instance_valid(m) and m.get("defeated") != true and m.has_method("shot"):
			m.shot(99, m.global_position, Vector3.UP)
	Game.add_xp(80)
	_say("This isn't over! Tick... tock... TICK!")
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 0.7, 1.3), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(visual, "scale", Vector3(0.05, 2.0, 0.05), 0.35)
	tw.tween_callback(func() -> void: visual.visible = false)
	Fx.burst(get_parent(), global_position + Vector3(0, 2.0, 0), PURPLE, 50, 0.14, 6.0, -0.5, 1.4)
	Fx.burst(get_parent(), global_position + Vector3(0, 2.0, 0), GOLD, 30, 0.1, 5.0, -0.5, 1.2)
	Juice.shake(0.4)
	Juice.rumble(0.6, 0.4, 0.5)
	Juice.blip("chime", 0.8, -2.0)
	Game.message("You popped Captain Glitch! He blinks away through a rift... to the Void.")
	if world:
		world.call("mend")


# Looks --------------------------------------------------------------------------------------------------------------------
static func _m(colour: Color, emit := 0.0, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit
	return m


static func _mesh(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func model() -> Node3D:
	# About 4.5 m tall: boxy armour of dark purple cubes, a helmet with a glowing magenta visor slit and two antenna
	# horns, big square shoulder pads, a cape of flickering static, and his little cracked clock in his chest
	var g := Node3D.new()
	var armour := _m(Color(0.24, 0.14, 0.4), 0.0, 0.35)
	var plate := _m(Color(0.42, 0.26, 0.7), 0.3, 0.35)
	var visor := _m(MAGENTA, 3.0, 0.2)
	var bx := func(size: Vector3) -> BoxMesh:
		var b := BoxMesh.new()
		b.size = size
		return b
	_mesh(g, bx.call(Vector3(1.6, 1.8, 1.0)), armour, Vector3(0, 2.4, 0)).name = "Chest"
	_mesh(g, bx.call(Vector3(1.2, 0.9, 0.85)), plate, Vector3(0, 1.2, 0))
	for sx in [-1.0, 1.0]:
		_mesh(g, bx.call(Vector3(0.55, 1.1, 0.55)), armour, Vector3(sx * 0.4, 0.55, 0))           # legs
		_mesh(g, bx.call(Vector3(0.75, 0.6, 0.9)), plate, Vector3(sx * 1.15, 3.25, 0))           # shoulder pads
		_mesh(g, bx.call(Vector3(0.45, 1.5, 0.45)), armour, Vector3(sx * 1.15, 2.25, 0), Vector3.ONE, Vector3(0, 0, sx * 0.12))
		_mesh(g, bx.call(Vector3(0.55, 0.5, 0.55)), plate, Vector3(sx * 1.25, 1.4, 0))           # fists
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = 0.12
		horn.height = 0.7
		_mesh(g, horn, visor, Vector3(sx * 0.42, 4.55, 0), Vector3.ONE, Vector3(0, 0, -sx * 0.35))
	_mesh(g, bx.call(Vector3(1.0, 0.95, 0.95)), armour, Vector3(0, 3.8, 0)).name = "Helmet"
	_mesh(g, bx.call(Vector3(0.8, 0.14, 0.1)), visor, Vector3(0, 3.85, 0.48)).name = "Visor"
	# The cape: a sheet of static behind him
	var cape := _m(Color(0.55, 0.4, 0.85), 0.6, 0.6)
	cape.albedo_color.a = 0.7
	cape.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cape.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(g, bx.call(Vector3(1.9, 2.8, 0.06)), cape, Vector3(0, 2.0, -0.62), Vector3.ONE, Vector3(-0.12, 0, 0)).name = "Cape"
	# The chest clock: dull until he's open, then it glows gold (the weak spot)
	var clock := CylinderMesh.new()
	clock.top_radius = 0.42
	clock.bottom_radius = 0.42
	clock.height = 0.12
	clock.radial_segments = 20
	var cm := _m(Color(0.4, 0.35, 0.5), 0.3, 0.3)
	cm.emission = GOLD
	_mesh(g, clock, cm, Vector3(0, 2.55, 0.52), Vector3.ONE, Vector3(PI / 2.0, 0, 0)).name = "Chest Clock"
	_mesh(g, bx.call(Vector3(0.05, 0.6, 0.04)), _m(Color(0.1, 0.05, 0.15)), Vector3(0.05, 2.6, 0.6), Vector3.ONE, Vector3(0, 0, 0.6))
	# Glitch cubes orbiting him
	var ring := Node3D.new()
	ring.name = "Glitch Cubes"
	g.add_child(ring)
	var cols := [PURPLE, GOLD, Color(0.3, 0.9, 1.0)]
	for k in 10:
		var a := k * TAU / 10.0
		var s := 0.18 + 0.08 * (k % 3)
		_mesh(ring, bx.call(Vector3.ONE * s), _m(cols[k % 3], 1.6), Vector3(cos(a) * 1.9, 1.2 + (k % 4) * 0.8, sin(a) * 1.9),
			Vector3.ONE, Vector3(k, k * 0.7, 0))
	return g
