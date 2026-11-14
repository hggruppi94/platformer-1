extends Node3D

# The centipede's own boss fight, at home by her hollow log behind the old gate (Hayden, 11 Nov 2026: "I want her to
# have a boss fight herself in her own world and she fully befriends you after"). The story: everyone has always run
# away from her, so before she can be friends for keeps she needs to know you'll stay when she's at her very scariest.
# It's a game (she says so, and asks first: yes or no, recorded, like the gate). Nothing here is more than a bump.
#
# How it plays (scripts/centipede_walker.gd is her body, bigger than usual):
#   - SCUTTLE: she races round you in a big ring, then stops and rears up, eyes glowing (a line on the ground shows
#     where she's going)...
#   - CHARGE: ...and charges straight across the clearing. Get out of the way!
#   - DIZZY: after a charge she's dizzy for a moment, curled up with stars round her head. Bop her on the head (jump on
#     her) or pop her with a bubble. Any other time, bubbles boing off her shiny back.
#   - From HIDE_AT hits she also dives into the ground and comes up where you were standing. The spot is marked
#     the moment she dives (a ring on the ground that fills in, cracks, dust and rumbling) and stays put, so step out
#     of it before it's full (Hayden, 14 Nov 2026: "right now it is instant, it should give the player a chance to
#     dodge"). Only someone still on it when she pops up gets bumped.
# HITS hits and she flops over giggling: you stayed. scripts/scary_world.gd takes it from there.

signal won

const WALKER := preload("res://scripts/centipede_walker.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")

const HITS := 10
const HIDE_AT := 5                        # from this many hits she burrows under you too
const SIZE := 1.6
const ARENA := 13.0                       # she stays within this of the middle
const RING := 7.0                         # how far out she scuttles round you
const SCUTTLE_SPEED := 7.0
const SCUTTLE_TIME := 3.2
const WINDUP := 1.0
const CHARGE_SPEED := 13.0
const CHARGE_LEN := 16.0
const DIZZY_TIME := 3.2
const TOUCH := 0.85                       # how close (times SIZE) a segment has to be to bump you
const LAYER := 1 << 19                    # her shot targets: bubbles hit them, you walk through them
const GLOW := Color(0.85, 0.45, 1.0)
const POP_WARN := 1.8                     # seconds from her dive to popping up: time to see the mark and step off it
const POP_R := 1.9                        # the marked spot's radius: still inside it when she pops up is a bump

var middle := Vector3.ZERO
var body: Node3D                          # the walker
var hits := 0
var defeated := false
var state := "scuttle"
var visual: Node3D                        # (bubbles squish this)
var _t := 0.0
var _left := SCUTTLE_TIME
var _ring_a := 0.0
var _charge_dir := Vector3.FORWARD
var _charge_gone := 0.0
var _line: MeshInstance3D
var _stars: Node3D
var _bar: BossBar
var _targets: Array[StaticBody3D] = []
var _bumped := 0.0
var _told_bounce := 0.0
var _hid_once := false
var _warn: Node3D                         # the mark on the ground where she'll come up
var _warn_fill: MeshInstance3D
var _dust_t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	Arsenal.supply_boss(self)                       # ammo crates round the fight (scripts/arsenal.gd)
	middle = global_position
	body = WALKER.new() as Node3D
	body.name = "Body"
	body.set("size", SIZE)
	body.set("head_height", 1.0)
	add_child(body)
	visual = body
	var p := _player()
	var start := middle + Vector3(0, 0, -RING)
	body.call("place", start, PI / 2.0)
	_ring_a = atan2(start.x - middle.x, start.z - middle.z)
	for k in 5:                                          # bubble targets along her (head and every few segments)
		var t := SHOT_TARGET.new() as StaticBody3D
		t.name = "Target%d" % k
		t.collision_layer = LAYER
		t.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.55 * SIZE
		cs.shape = sp
		t.add_child(cs)
		t.on_shot = _bubbled
		t.top_level = true
		add_child(t)
		_targets.append(t)
	_line = MeshInstance3D.new()
	var q := BoxMesh.new()
	q.size = Vector3(0.6, 0.03, CHARGE_LEN)
	_line.mesh = q
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(GLOW, 0.45)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line.material_override = lm
	_line.top_level = true
	_line.visible = false
	add_child(_line)
	_stars = _dizzy_stars()
	_bar = BossBar.make(self, _name(), GLOW, 3.4)
	_bar.top_level = false
	if p:
		_ring_a = atan2(start.x - p.global_position.x, start.z - p.global_position.z)


func _name() -> String:
	var n := str(Dialogue.names.get("centipede", ""))
	return n if n != "" else "The Centipede"


func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func head_at() -> Vector3:
	return body.get("head_at")


func _process(delta: float) -> void:
	if defeated:
		return
	_t += delta
	_bumped -= delta
	_told_bounce -= delta
	var p := _player()
	match state:
		"scuttle":
			_scuttle(delta, p)
		"windup":
			_left -= delta
			if _left <= 0.0:
				state = "charge"
				_charge_gone = 0.0
				_line.visible = false
				Juice.blip("whoosh", 0.6, -2.0)
				Audio.play_at("centipede_skitter", head_at(), 0.0)
		"charge":
			_charge(delta)
		"dizzy":
			_left -= delta
			_stars.global_position = head_at() + Vector3(0, 2.2 * SIZE, 0)
			_stars.rotation.y += delta * (1.5 if Settings.reduce_motion else 4.0)
			if _left <= 0.0:
				_stars.visible = false
				_next()
		"under":
			_left -= delta
			_rumble(delta)
			if _left <= 0.0:
				_pop_up()
	_place_targets()
	_bar.global_position = head_at() + Vector3(0, 3.0 * SIZE, 0)
	_bar.fill = 1.0 - float(hits) / HITS
	if p:
		_touch(p)


func _scuttle(delta: float, p: Node3D) -> void:
	# Round and round you, fast, in a ring
	var c := p.global_position if p else middle
	var off := Vector2(c.x - middle.x, c.z - middle.z)
	if off.length() > ARENA - RING:
		off = off.normalized() * (ARENA - RING)
		c = Vector3(middle.x + off.x, c.y, middle.z + off.y)
	_ring_a += (SCUTTLE_SPEED * (1.2 if hits >= HIDE_AT else 1.0) / RING) * delta
	var goal := Vector3(c.x + sin(_ring_a) * RING, middle.y, c.z + cos(_ring_a) * RING)
	var h := head_at()
	var to := goal - h
	to.y = 0.0
	var next := h + to.normalized() * minf(to.length(), SCUTTLE_SPEED * 1.4 * delta) if to.length() > 0.01 else h
	next.y = middle.y
	body.call("step", next)
	_left -= delta
	if _left <= 0.0:
		_wind_up(p)


func _wind_up(p: Node3D) -> void:
	# She stops, rears up and glares (eyes glowing), and a line on the ground shows where she'll charge
	state = "windup"
	_left = WINDUP * (0.8 if hits >= HIDE_AT else 1.0)
	var h := head_at()
	var at := p.global_position if p else middle
	_charge_dir = Vector3(at.x - h.x, 0, at.z - h.z)
	_charge_dir = _charge_dir.normalized() if _charge_dir.length() > 0.1 else Vector3.FORWARD
	_line.global_position = h + _charge_dir * (CHARGE_LEN / 2.0) + Vector3(0, 0.05, 0)
	_line.global_rotation = Vector3(0, atan2(_charge_dir.x, _charge_dir.z), 0)
	_line.visible = true
	var tw := create_tween()
	tw.tween_property(body, "head_height", 1.9, 0.35).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(maxf(_left - 0.6, 0.1))
	tw.tween_property(body, "head_height", 1.0, 0.2)
	Juice.blip("thud", 0.6, -6.0)


func _charge(delta: float) -> void:
	var h := head_at()
	var step := CHARGE_SPEED * delta
	var next := h + _charge_dir * step
	var off := Vector2(next.x - middle.x, next.z - middle.z)
	_charge_gone += step
	if _charge_gone >= CHARGE_LEN or off.length() > ARENA + 2.0:
		state = "dizzy"
		_left = DIZZY_TIME
		_stars.visible = true
		Juice.shake(0.2)
		Juice.blip("boing", 0.8, -4.0)
		Fx.burst(get_parent(), h + Vector3(0, 0.5, 0), Color(0.6, 0.5, 0.6), 14, 0.08, 3.0, -1.0, 0.6)
		return
	next.y = middle.y
	body.call("step", next)


func _next() -> void:
	# After a dizzy spell: from HIDE_AT hits, every other time, she dives under and pops up beneath you
	if hits >= HIDE_AT and (not _hid_once or randf() < 0.5):
		_hid_once = true
		_dive()
		return
	state = "scuttle"
	_left = SCUTTLE_TIME * randf_range(0.8, 1.2)


func _dive() -> void:
	state = "under"
	_left = POP_WARN
	_dust_t = 0.0
	var h := head_at()
	Fx.burst(get_parent(), h + Vector3(0, 0.4, 0), Color(0.45, 0.35, 0.4), 16, 0.08, 3.0, -1.0, 0.6)
	Juice.blip("whoosh", 0.7, -4.0)
	body.visible = false
	# Where you are now is where she comes up. The mark doesn't follow you: that's the dodge.
	var p := _player()
	var at := p.global_position if p else middle
	at.y = middle.y
	set_meta("pop_at", at)
	_show_warn(at)
	Game.message("She's coming up! Move!")


func _show_warn(at: Vector3) -> void:
	if _warn == null:
		_warn = Node3D.new()
		_warn.name = "Burrow Warning"
		get_parent().add_child(_warn)
		var rim := MeshInstance3D.new()
		rim.name = "Rim"
		var tm := TorusMesh.new()
		tm.inner_radius = POP_R - 0.18
		tm.outer_radius = POP_R
		tm.rings = 48
		tm.ring_segments = 6
		rim.mesh = tm
		rim.scale = Vector3(1, 0.4, 1)
		rim.material_override = _warn_mat(Color(GLOW.r, GLOW.g, GLOW.b, 0.95))
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_warn.add_child(rim)
		_warn_fill = MeshInstance3D.new()
		_warn_fill.name = "Fill"
		var disc := CylinderMesh.new()
		disc.top_radius = POP_R - 0.15
		disc.bottom_radius = POP_R - 0.15
		disc.height = 0.04
		disc.radial_segments = 40
		_warn_fill.mesh = disc
		_warn_fill.material_override = _warn_mat(Color(0.35, 0.15, 0.45, 0.55))
		_warn_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_warn.add_child(_warn_fill)
		# A few dark cracks across the spot, so it reads as ground about to break
		var crack_mat := _warn_mat(Color(0.12, 0.05, 0.15, 0.9))
		for k in 5:
			var c := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.12, 0.03, POP_R * randf_range(0.9, 1.6))
			c.mesh = b
			c.material_override = crack_mat
			c.rotation.y = k * TAU / 5.0 + randf_range(-0.3, 0.3)
			c.position = Vector3(0, 0.03, 0)
			c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_warn.add_child(c)
	_warn.global_position = at + Vector3(0, 0.06, 0)
	_warn.visible = true
	_warn_fill.scale = Vector3(0.05, 1, 0.05)


func _warn_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m


func warn_left() -> float:
	# For tests: seconds until she pops up (0 when she isn't under)
	return maxf(_left, 0.0) if state == "under" else 0.0


func _rumble(delta: float) -> void:
	# The mark fills in as she gets closer, the ground shakes a little and dust puffs up from the spot
	if _warn == null:
		return
	var k := clampf(1.0 - _left / POP_WARN, 0.0, 1.0)
	_warn_fill.scale = Vector3(lerpf(0.05, 1.0, k), 1, lerpf(0.05, 1.0, k))
	_dust_t -= delta
	if _dust_t <= 0.0:
		_dust_t = lerpf(0.45, 0.15, k)
		var at: Vector3 = get_meta("pop_at", middle)
		var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).limit_length(POP_R * 0.8)
		Fx.burst(get_parent(), at + off + Vector3(0, 0.2, 0), Color(0.45, 0.35, 0.4), 6, 0.06, 1.5, -1.0, 0.4)
		Juice.shake(0.04 + 0.08 * k)


func _pop_up() -> void:
	var at: Vector3 = get_meta("pop_at", middle)
	if _warn:
		_warn.visible = false
	body.visible = true
	var away := Vector3(at.x - middle.x, 0, at.z - middle.z)
	var yaw := atan2(away.x, away.z) if away.length() > 0.1 else 0.0
	body.call("place", at, yaw)
	Juice.shake(0.25)
	Juice.blip("pop", 0.6, -2.0)
	Fx.burst(get_parent(), at + Vector3(0, 0.4, 0), Color(0.45, 0.35, 0.4), 20, 0.1, 4.0, -1.0, 0.7)
	# Still standing on the mark: a bump. Stepped off it (or high in a jump): nothing.
	var p := _player()
	if p and not p.call("is_invulnerable"):
		var d := Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length()
		var feet := p.global_position.y - 0.8
		if d < POP_R and feet - at.y < 1.2:
			_bumped = 1.0
			p.call("hurt", 1, at)
	state = "dizzy"
	_left = DIZZY_TIME * 0.8
	_stars.visible = true


func _place_targets() -> void:
	var trail: Array = body.get("trail")
	if trail.is_empty():
		return
	for k in _targets.size():
		var t := _targets[k]
		if k == 0:
			t.global_position = head_at() + Vector3(0, 1.0 * SIZE, 0)
		else:
			var pd: Array = body.call("_point_back", k * 2.5 * WALKER.SPACING * SIZE)
			t.global_position = (pd[0] as Vector3) + Vector3(0, 0.35 * SIZE, 0)
		t.process_mode = Node.PROCESS_MODE_INHERIT if body.visible else Node.PROCESS_MODE_DISABLED


func _touch(p: CharacterBody3D) -> void:
	if not body.visible or state == "under":
		return
	var feet := p.global_position.y - 0.8
	var head := head_at() + Vector3(0, 1.0 * SIZE, 0)
	# A bop on the head while she's dizzy
	if state == "dizzy" and p.velocity.y < 0.5 and Vector2(p.global_position.x - head.x, p.global_position.z - head.z).length() < 1.1 * SIZE \
			and feet > head.y - 0.4 and feet < head.y + 1.2:
		p.call("bounce", 10.0)
		hurt(1)
		return
	if state == "dizzy" or _bumped > 0.0 or p.call("is_invulnerable"):
		return
	# Otherwise bumping into her bumps you (only while she's moving)
	var trail: Array = body.get("trail")
	for k in range(0, 22, 2):
		var pd: Array = body.call("_point_back", k * WALKER.SPACING * SIZE)
		var at: Vector3 = pd[0]
		if Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < TOUCH * SIZE and absf(feet - at.y) < 1.2 * SIZE:
			_bumped = 1.0
			p.call("hurt", 1, at)
			return
	if trail.is_empty():
		return


func _bubbled() -> String:
	if defeated:
		return "miss"
	if state != "dizzy":
		if _told_bounce <= 0.0:
			_told_bounce = 5.0
			Game.message("Boing! Her back's too shiny while she's zooming about. Wait till she's dizzy!")
		return "bounce"
	hurt(1)
	return "hit"


func hurt(amount: int) -> void:
	if defeated or state != "dizzy":
		return
	hits = mini(hits + amount, HITS)
	Juice.hitstop(0.05)
	Juice.shake(0.15)
	Juice.blip("pop", 0.9, -4.0)
	Fx.burst(get_parent(), head_at() + Vector3(0, 1.2 * SIZE, 0), GLOW, 16, 0.08, 3.0, -0.5, 0.8)
	var giggles := ["Hee! That tickles!", "Oof! Okay, okay, you got me!", "You're still here?!", "Nobody's EVER stayed this long!",
		"Hee hee! Stop! No, don't stop!", "One more..."]
	Game.message(giggles[mini(hits - 1, giggles.size() - 1)])
	if hits >= HITS:
		defeat()
		return
	_stars.visible = false
	_left = 0.0
	_next()


func defeat() -> void:
	# She flops over, all her legs waving in the air, giggling: you stayed
	defeated = true
	state = "done"
	_line.visible = false
	_stars.visible = false
	_bar.visible = false
	if _warn:
		_warn.visible = false
	for t in _targets:
		t.queue_free()
	_targets.clear()
	Game.add_xp(50)
	Juice.blip("chime", 0.8, -2.0)
	Fx.burst(get_parent(), head_at() + Vector3(0, 1.0, 0), GLOW, 40, 0.1, 5.0, -0.5, 1.2)
	won.emit()


func _exit_tree() -> void:
	if is_instance_valid(_warn):
		_warn.queue_free()


func _dizzy_stars() -> Node3D:
	var s := Node3D.new()
	s.name = "Dizzy"
	s.top_level = true
	s.visible = false
	add_child(s)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.9, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.3)
	m.emission_energy_multiplier = 1.5
	for k in 4:
		var b := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.14
		sm.height = 0.28
		b.mesh = sm
		b.material_override = m
		var a := k * TAU / 4.0
		b.position = Vector3(cos(a), 0, sin(a)) * 0.8
		s.add_child(b)
	return s
