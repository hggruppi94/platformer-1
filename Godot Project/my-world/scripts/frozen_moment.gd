extends "res://scripts/portal_world.gd"

# The Frozen Moment, Flurry's home world (plan items 19a world 2 and 23; scene built by tools/build_frozen_moment.gd).
# Time has stopped here mid-moment: snowflakes hang in the air without falling, the great clock in the sky is stuck on
# one tick (its second hand twitches and can't get past it), and three moments are frozen solid in shells of ice:
#   Moment1  a fish leaping out of a hole in the frozen lake (slide out across the ice to it)
#   Moment2  a snowball fight on top of Snowball Hill, the snowballs hanging mid-throw (jump up the snowy steps)
#   Moment3  a snowbird mid-flight at the far end of the icicle cave
# Chip a moment's ice three times (Interact, or a Star Popper bubble) and it thaws: the fish splashes back in, the
# snowballs fly, the bird flies out of the cave. With all three thawed the Frost Gloop (scripts/frost_gloop.gd), frozen
# on its throne at the far end, cracks out of its ice when you come near. Pop it and the world mends
# (Portals.clear): the snow starts falling and the clock ticks on.
# Flurry, the arctic fox kid (a chosen one, working name), waits by the way in. She's the only thing here that still
# moves, and she's shy: talking to her says what to do next. The ice slide from the top of the hill brings you down.
# Ice (the lake, the throne: group "ice") is slippery underfoot (scenes/player/player.gd ICE_GRIP); the snow drifts
# slow you down (scripts/soft_zone.gd, kind "snow"). Nothing here hurts more than a normal bump.

const FROST_GLOOP_SCRIPT := preload("res://scripts/frost_gloop.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const MOMENTS := ["Moment1", "Moment2", "Moment3"]
const MOMENT_NAMES := ["the leaping fish", "the snowball fight", "the snowbird"]
const THAW_HITS := 3                       # chips to thaw a moment's ice
const WAKE_NEAR := 16.0                    # coming this close to the throne with all three thawed wakes the Gloop
const SLIDE_TIME := 3.0
const FLAKES := 360
const FLAKE_R := 38.0
const FLAKE_TOP := 14.0
const ICE := Color(0.7, 0.88, 1.0)

var gloop_awake := false
var _chips := [0, 0, 0]
var _gloop: CharacterBody3D
var _sliding := false
var _flakes: Array = []                    # the snowflakes' places (also in the MultiMesh, when there's a renderer)
var _flake_mm: MultiMesh
var _t := 0.0
var _tick := 0.0
var _second := 0.0                         # the clock's second hand (radians)
var _flying := false                       # the snowbird's flying off (wings flapping)


func picture() -> void:
	# In the portal's preview: the frozen moments, the Gloop frozen in its block, the hanging snow and the stuck clock
	for i in MOMENTS.size():
		var m := get_node_or_null(MOMENTS[i]) as Node3D
		if m:
			m.add_child(moment_model(i))
	var g := get_node_or_null("FrostGloop") as Node3D
	if g:
		var blob := MeshInstance3D.new()
		blob.mesh = _ball(1.2)
		blob.material_override = _mat(Color(0.5, 0.75, 0.95), 0.3, 0.2)
		blob.scale = Vector3(1.3, 1.0, 1.3)
		blob.position.y = 0.4
		g.add_child(blob)
		g.add_child(ice_block_model())
	_add_clock()
	_add_flakes()


func setup() -> void:
	for i in MOMENTS.size():
		var m := get_node_or_null(MOMENTS[i]) as Node3D
		if m == null:
			continue
		var model := moment_model(i)
		model.name = "Moment"
		m.add_child(model)
		var spot := USE_SPOT.make(Vector3(0, 0.2, 0), _moment_offer.bind(i), _chip.bind(i), 3.2, 3.5)
		spot.name = "Spot"
		m.add_child(spot)
		var body := SHOT_TARGET.new() as StaticBody3D
		body.name = "Hit"
		body.on_shot = func() -> String: return "hit" if _chip(i) else "bounce"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.6
		cs.shape = sp
		body.add_child(cs)
		(model.get_node("Shell") as Node3D).add_child(body)
	var slide := get_node_or_null("Slide") as Node3D
	if slide:
		var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if _sliding else "ride the ice slide down",
			slide_down, 1.8, 1.8)
		spot.name = "Spot"
		slide.add_child(spot)
	_add_flurry()
	_add_clock()
	_add_flakes()
	if not Portals.is_cleared(world_id):
		_add_frost_gloop()
	_refresh()
	if not Portals.is_cleared(world_id) and moments_thawed() == 0:
		Game.message.call_deferred("The Frozen Moment: everything's stopped, even the snowflakes. Someone's waving by the way in...")


# The frozen moments -------------------------------------------------------------------------------------------------
func moment_id(i: int) -> String:
	return "moment_%d" % (i + 1)


func is_thawed(i: int) -> bool:
	return Portals.has_found(world_id, moment_id(i))


func moments_thawed() -> int:
	var n := 0
	for i in MOMENTS.size():
		if is_thawed(i):
			n += 1
	return n


func _moment_offer(i: int) -> String:
	if is_thawed(i):
		return ""
	return "thaw the frozen moment" if _chips[i] == 0 else "chip the ice again"


func _chip(i: int) -> bool:
	# One chip at a moment's ice; the third thaws it. Says whether there was ice there to chip.
	if is_thawed(i):
		return false
	_chips[i] += 1
	var shell := get_node_or_null("%s/Moment/Shell" % MOMENTS[i]) as Node3D
	if shell:
		Fx.burst(self, shell.global_position, ICE, 10, 0.06, 2.5, -3.0, 0.6)
	if _chips[i] < THAW_HITS:
		Juice.blip("tick", 1.4 + _chips[i] * 0.2, -4.0)
		if shell:
			var k: float = 1.0 - 0.14 * _chips[i]
			var tw := shell.create_tween()
			tw.tween_property(shell, "scale", Vector3.ONE * (k - 0.06), 0.06)
			tw.tween_property(shell, "scale", Vector3.ONE * k, 0.12)
		Game.message("Crack! The ice round %s splinters. (%d more)" % [MOMENT_NAMES[i], THAW_HITS - _chips[i]])
		return true
	Portals.note_found(world_id, moment_id(i))
	_thaw(i)
	var n := moments_thawed()
	Game.message("%s thaws and moves again! (%d of 3)" % [MOMENT_NAMES[i].capitalize(), n] if n < 3
		else "All three moments are moving again! Something on the icy throne just cracked...")
	return true


func _thaw(i: int) -> void:
	# The ice shatters and the moment carries on from where it stopped
	var m := get_node_or_null("%s/Moment" % MOMENTS[i]) as Node3D
	if m == null:
		return
	var shell := m.get_node("Shell") as Node3D
	Fx.burst(self, shell.global_position, ICE, 30, 0.08, 4.0, -4.0, 0.9)
	Juice.blip("pop", 0.8, -3.0)
	Juice.shake(0.08)
	shell.visible = false
	var hit := shell.get_node_or_null("Hit") as CollisionObject3D
	if hit:
		hit.queue_free()
	var thing := m.get_node("Thing") as Node3D
	var tw := create_tween()
	match i:
		0:                                                   # the fish arcs up and splashes back into its hole
			var from := thing.position
			tw.tween_property(thing, "position", from + Vector3(0.4, 0.6, 0), 0.35).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(thing, "rotation:z", -1.2, 0.6)
			tw.tween_property(thing, "position", Vector3(from.x + 0.8, -0.4, from.z), 0.4).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				Fx.burst(self, m.global_position + Vector3(0.8, 0.1, 0), Color(0.6, 0.85, 1.0), 18, 0.07, 3.0, -6.0, 0.8)
				Juice.blip("whoosh", 1.6, -8.0)
				thing.visible = false)
		1:                                                   # the snowballs fly and splat on the snowmen
			for b in thing.get_node("Balls").get_children():
				var ball := b as Node3D
				var to: Vector3 = ball.get_meta("to")
				tw.parallel().tween_property(ball, "position", to, 0.45).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void:
				for b in thing.get_node("Balls").get_children():
					Fx.burst(self, (b as Node3D).global_position, Color(1, 1, 1), 10, 0.07, 2.5, -5.0, 0.6)
					(b as Node3D).visible = false
				Juice.blip("thud", 1.3, -6.0))
		2:                                                   # the snowbird flaps and flies out of the cave
			_flying = true
			var out := thing.position + Vector3(-16.0, 1.0, 0)
			tw.tween_property(thing, "position", out, 2.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(thing, "position", out + Vector3(-6.0, 10.0, 0), 1.6)
			tw.tween_callback(func() -> void:
				_flying = false
				thing.visible = false)
	Juice.blip("chime", 0.9 + i * 0.2, -5.0)


func _refresh() -> void:
	# What's thawed stays thawed: on coming back, the shells are gone and the moments have carried on
	for i in MOMENTS.size():
		var m := get_node_or_null("%s/Moment" % MOMENTS[i]) as Node3D
		if m == null:
			continue
		var done := is_thawed(i) or Portals.is_cleared(world_id)
		var shell := m.get_node("Shell") as Node3D
		shell.visible = not done
		if done:
			var hit := shell.get_node_or_null("Hit")
			if hit:
				hit.queue_free()
			match i:
				0, 2:
					(m.get_node("Thing") as Node3D).visible = false
				1:
					(m.get_node("Thing/Balls") as Node3D).visible = false


# The Frost Gloop ----------------------------------------------------------------------------------------------------
func _add_frost_gloop() -> void:
	var m := get_node_or_null("FrostGloop") as Node3D
	if m == null:
		return
	var g := (load("res://scenes/enemies/gloop_king.tscn") as PackedScene).instantiate() as CharacterBody3D
	g.set_script(FROST_GLOOP_SCRIPT)
	g.name = "The Frost Gloop"                               # not "Gloop …", so finding Gloops by name skips it
	g.set("world", self)
	g.set("size", 2.2)
	g.set("color", Color(0.7, 0.9, 1.0))
	g.set("goldness", 0.55)
	g.set("stomps_to_defeat", 6)
	g.set("damage", 2)
	g.set("xp_reward", 40)
	g.set("wander_radius", 6.0)
	g.set("sight_range", 18.0)
	g.set("leash_range", 30.0)
	g.set("wander_speed", 1.0)
	g.set("chase_speed", 2.6)
	g.set("respawns", false)
	g.process_mode = Node.PROCESS_MODE_DISABLED             # frozen solid until it wakes
	add_child(g)
	g.global_position = m.global_position
	_gloop = g
	var block := ice_block_model()
	block.name = "Ice Block"
	m.add_child(block)
	var body := SHOT_TARGET.new() as StaticBody3D
	body.name = "Hit"
	body.on_shot = func() -> String:
		_look_at_block()
		return "bounce"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(5.2, 4.6, 5.2)
	cs.shape = bs
	cs.position.y = 1.1
	body.add_child(cs)
	block.add_child(body)
	var spot := USE_SPOT.make(Vector3(0, -0.6, 3.2), func() -> String: return "" if gloop_awake else "look at the frozen Gloop",
		_look_at_block, 2.6, 3.0)
	spot.name = "Spot"
	m.add_child(spot)


func _look_at_block() -> void:
	if gloop_awake:
		return
	var left := 3 - moments_thawed()
	Game.message("A huge Gloop, frozen solid on its throne, hugging the stopped moment. Thaw the %d frozen moment%s first." % [left, "" if left == 1 else "s"]
		if left > 0 else "The ice round it is cracking...")
	Audio.play("ui_back", -8.0)


func wake_gloop() -> void:
	if gloop_awake or _gloop == null or not is_instance_valid(_gloop):
		return
	gloop_awake = true
	var block := get_node_or_null("FrostGloop/Ice Block") as Node3D
	if block:
		Fx.burst(self, block.global_position + Vector3(0, 1.5, 0), ICE, 50, 0.12, 6.0, -5.0, 1.2)
		block.queue_free()
	var spot := get_node_or_null("FrostGloop/Spot")
	if spot:
		spot.queue_free()
	_gloop.process_mode = Node.PROCESS_MODE_INHERIT
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("pop", 0.5, -2.0)
	Game.message("The Frost Gloop cracks out of its ice! Bubbles or stomps pop it. When it flops, jump the ring of frost!")


func mend() -> void:
	# The stopped moment slips free: snow falls, the clock ticks on
	gloop_awake = false
	if _gloop and is_instance_valid(_gloop):
		for g in _gloop.get("_court"):                   # its Snow Gloops melt away with it
			if is_instance_valid(g) and not g.defeated:
				g.shot(99, g.global_position, Vector3.UP)
	Portals.clear(world_id)
	Fx.burst(self, Vector3(0, 3.0, -20), Color(1, 1, 1), 50, 0.1, 6.0, -1.0, 1.6)
	Fx.burst(self, Vector3(0, 3.0, -20), ICE, 30, 0.08, 5.0, -1.0, 1.4)
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	_refresh()


# The ice slide ------------------------------------------------------------------------------------------------------
func slide_down() -> void:
	var m := get_node_or_null("Slide") as Node3D
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if m == null or player == null or _sliding:
		return
	var curve := Curve3D.new()
	for p in m.get_meta("path"):
		curve.add_point(p)
	_sliding = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	Juice.blip("whoosh", 1.4, -4.0)
	var length := curve.get_baked_length()
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var d := length * t
		var at := curve.sample_baked(d)
		var ahead := curve.sample_baked(minf(d + 0.5, length))
		player.global_position = at
		var visual := player.get_node_or_null("Visual") as Node3D
		if visual and ahead.distance_to(at) > 0.01:
			visual.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z),
		0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		player.set_physics_process(true)
		player.velocity = Vector3.ZERO
		_sliding = false
		Fx.burst(self, player.global_position, Color(1, 1, 1), 12, 0.06, 2.5, -3.0, 0.6)
		Juice.blip("thud", 1.0, -8.0))


# Flurry -------------------------------------------------------------------------------------------------------------
func _add_flurry() -> void:
	var m := get_node_or_null("Flurry") as Node3D
	if m == null:
		return
	m.add_child(flurry_model())
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Flurry", _talk_flurry, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func flurry_model() -> Node3D:
	# An arctic fox kid in a frosty blue-white coat with a puffy scarf, made like the townsfolk (scripts/townsfolk.gd)
	# from the cat body, with a big bushy tail and her pocket watch, frozen on one tick, on a chain
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = "Model"
	p.set("look", {"body": "cat", "colors": {"fur": 7, "eyes": 14, "accent": 14, "top": 14, "bottoms": 7, "shoes": 15},
		"extras": true, "height": 0.9})
	p.set("extras", [{"kind": "scarf", "color": Color(0.45, 0.7, 1.0)}])
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.45, -0.2)
	tail.rotation.x = -0.9
	p.add_child(tail)
	var fur := _mat(Color(0.95, 0.96, 1.0), 0.0, 0.9)
	var tip := _mat(Color(0.75, 0.87, 1.0), 0.0, 0.9)
	var bush := MeshInstance3D.new()
	bush.mesh = _ball(0.12)
	bush.material_override = fur
	bush.scale = Vector3(1.0, 3.2, 1.0)
	bush.position.y = 0.34
	tail.add_child(bush)
	var end := MeshInstance3D.new()
	end.mesh = _ball(0.1)
	end.material_override = tip
	end.scale = Vector3(1.0, 1.4, 1.0)
	end.position.y = 0.7
	tail.add_child(end)
	var watch := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.06
	c.bottom_radius = 0.06
	c.height = 0.02
	watch.mesh = c
	watch.material_override = _mat(Color(0.8, 0.9, 1.0), 0.4, 0.2)
	watch.position = Vector3(0.12, 0.5, 0.14)
	watch.rotation.x = PI / 2
	p.add_child(watch)
	return p


func flurry_lines() -> Array:
	# Flurry's shy at first: short lines, and more of them as she warms to you. Then what to do next.
	if Portals.is_cleared(world_id):
		return ["It's snowing. Real snow, falling down! I forgot what it sounds like.",
			"And listen... my watch is ticking again. Tick. Tick. Tick.",
			"Thank you, {player}. I don't know what I'd... um. Thank you."]
	var n := moments_thawed()
	if not Portals.has_found(world_id, "met_flurry"):
		Portals.note_found(world_id, "met_flurry")
		return ["Oh! You can move too? I... hi. I'm Flurry.",
			"Everything stopped. The snow, the birds, all of it. Right in the middle of a moment.",
			"My watch stopped on one tick. See? It keeps trying to get past it.",
			"Three moments are stuck in the ice. A fish on the lake, a snowball fight up the hill, a bird in the icicle cave.",
			"If you chip the ice off them, maybe... maybe they'll carry on?"]
	if n < 3:
		var left: Array = []
		for i in MOMENTS.size():
			if not is_thawed(i):
				left.append(["the fish out on the lake", "the snowball fight on the hilltop", "the bird in the icicle cave"][i])
		return ["%d moving again. You're really good at this." % n if n > 0 else "Chip the ice three times and it breaks. Or pop it with bubbles.",
			"Still frozen: %s." % " and ".join(left), "The lake's slippery. Slide, don't run!"]
	return ["The big Gloop on the throne... it's been hugging the moment the whole time, so time can't move.",
		"It's waking up. Pop it! And when it flops, jump the frost ring.",
		"I'll... I'll be brave and watch from here."]


func _talk_flurry() -> void:
	var spot := get_node_or_null("Flurry/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Flurry", flurry_lines(), "frozen_flurry")


# The stuck clock and the hanging snow -------------------------------------------------------------------------------
func _add_clock() -> void:
	var m := get_node_or_null("Clock") as Node3D
	if m == null:
		return
	var g := clock_model()
	g.name = "Sky Clock"
	m.add_child(g)


func clock_ticking() -> bool:
	return not has_meta("preview") and Portals.is_cleared(world_id)


func _add_flakes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	_flakes = []
	for i in FLAKES:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * FLAKE_R
		_flakes.append(Vector3(cos(a) * r, rng.randf_range(0.4, FLAKE_TOP), sin(a) * r))
	_flake_mm = MultiMesh.new()
	_flake_mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1, 1, 1, 0.9)
	q.material = fm
	_flake_mm.mesh = q
	_flake_mm.instance_count = FLAKES
	var mi := MultiMeshInstance3D.new()
	mi.name = "Snowflakes"
	mi.multimesh = _flake_mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-FLAKE_R, 0, -FLAKE_R), Vector3(FLAKE_R * 2, FLAKE_TOP + 1, FLAKE_R * 2))
	add_child(mi)
	_place_flakes()


func _place_flakes() -> void:
	for i in _flakes.size():
		_flake_mm.set_instance_transform(i, Transform3D(Basis(), _flakes[i]))


func snow_falling() -> bool:
	return not has_meta("preview") and Portals.is_cleared(world_id)


func _process(delta: float) -> void:
	_t += delta
	# The clock: stuck, its second hand twitching at one tick and slipping back; mended, it ticks round
	var hand := get_node_or_null("Clock/Sky Clock/Second") as Node3D
	if hand:
		if clock_ticking():
			_tick -= delta
			if _tick <= 0.0:
				_tick = 1.0
				_second -= TAU / 60.0
			hand.rotation.z = lerp_angle(hand.rotation.z, _second, minf(1.0, delta * 20.0))
		else:
			hand.rotation.z = -0.9 + (0.05 if fmod(_t, 1.0) < 0.15 else 0.0)
	# The snow: hanging still (just a glint), or falling once the moment's free
	if snow_falling() and not _flakes.is_empty():
		for i in _flakes.size():
			var f: Vector3 = _flakes[i]
			f.y -= delta * (0.8 + fmod(i * 0.37, 0.6))
			f.x += sin(_t * 0.7 + i) * delta * 0.3
			if f.y < 0.1:
				f.y = FLAKE_TOP
			_flakes[i] = f
		_place_flakes()
	# The snowbird's wings while it flies off
	if _flying:
		for k in ["WingL", "WingR"]:
			var w := get_node_or_null("Moment3/Moment/Thing/" + k) as Node3D
			if w:
				w.rotation.z = sin(_t * 18.0) * 0.8 * (1.0 if k == "WingL" else -1.0)
	if has_meta("preview"):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_face_player(player, delta)
	if Portals.is_cleared(world_id):
		return
	var throne := get_node_or_null("FrostGloop") as Node3D
	if not gloop_awake and player and throne and moments_thawed() == 3 \
			and player.global_position.distance_to(throne.global_position) < WAKE_NEAR:
		wake_gloop()


func _face_player(player: Node3D, delta: float) -> void:
	# Flurry turns to look at you when you come near (shy, but curious)
	var m := get_node_or_null("Flurry/Model") as Node3D
	if m == null or player == null:
		return
	var to := player.global_position - m.global_position
	if Vector2(to.x, to.z).length() > 9.0:
		return
	var want := atan2(to.x, to.z) - (m.get_parent() as Node3D).global_rotation.y
	m.rotation.y = lerp_angle(m.rotation.y, want, minf(1.0, delta * 4.0))


# Looks --------------------------------------------------------------------------------------------------------------
static func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func _mat(colour: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit
	return m


static func _ice_mat() -> StandardMaterial3D:
	var m := _mat(Color(0.72, 0.9, 1.0, 0.45), 0.25, 0.05)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.8
	return m


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	return c


static func moment_model(i: int) -> Node3D:
	# One frozen moment: "Thing" (what's frozen, posed mid-moment) inside "Shell" (its ice)
	var g := Node3D.new()
	var thing := Node3D.new()
	thing.name = "Thing"
	g.add_child(thing)
	var snow := _mat(Color(0.97, 0.98, 1.0), 0.0, 0.95)
	var dark := _mat(Color(0.08, 0.08, 0.12), 0.0, 0.3)
	var shell_at := Vector3(0, 1.3, 0)
	var shell_scale := Vector3.ONE * 1.4
	match i:
		0:                                                   # the leaping fish, over its hole in the ice
			_put(g, _cone(0.9, 0.9, 0.04), _mat(Color(0.1, 0.25, 0.4), 0.0, 0.05), Vector3(0, 0.02, 0))
			var fish := _mat(Color(1.0, 0.6, 0.35), 0.15, 0.3)
			thing.position = Vector3(0, 1.3, 0)
			thing.rotation.z = 0.6
			_put(thing, _ball(0.3), fish, Vector3.ZERO, Vector3(1.8, 0.9, 0.7))
			_put(thing, _cone(0.0, 0.28, 0.4), fish, Vector3(-0.62, 0, 0), Vector3(1, 1, 0.3), Vector3(0, 0, PI / 2))
			for s in [-1.0, 1.0]:
				_put(thing, _ball(0.06), dark, Vector3(0.36, 0.07, s * 0.17))
			for k in 6:                                      # splash drops, hanging in the air
				var a := k * TAU / 6.0
				_put(g, _ball(0.07), _mat(Color(0.7, 0.9, 1.0), 0.3, 0.05), Vector3(cos(a) * 0.6, 0.3 + (k % 3) * 0.3, sin(a) * 0.6))
		1:                                                   # the snowball fight: two snowmen, three snowballs mid-throw
			for s in [-1.0, 1.0]:
				var man := Node3D.new()
				man.position = Vector3(s * 2.1, 0, 0)
				g.add_child(man)
				_put(man, _ball(0.55), snow, Vector3(0, 0.5, 0))
				_put(man, _ball(0.4), snow, Vector3(0, 1.25, 0))
				_put(man, _ball(0.28), snow, Vector3(0, 1.8, 0))
				_put(man, _cone(0.0, 0.06, 0.3), _mat(Color(1.0, 0.55, 0.2)), Vector3(-s * 0.32, 1.8, 0), Vector3.ONE, Vector3(0, 0, s * PI / 2))
				for e in [-1.0, 1.0]:
					_put(man, _ball(0.04), dark, Vector3(-s * 0.24, 1.9, e * 0.1))
				_put(man, _cone(0.03, 0.03, 0.8), _mat(Color(0.45, 0.3, 0.2)), Vector3(-s * 0.4, 1.35, 0.3), Vector3.ONE, Vector3(0.4, 0, s * 1.0))
				_put(man, _cone(0.3, 0.3, 0.08), _mat(Color(0.35, 0.5, 1.0)), Vector3(0, 1.55, 0), Vector3(1, 1, 1))
			var balls := Node3D.new()
			balls.name = "Balls"
			thing.add_child(balls)
			for k in 3:
				var x := lerpf(-1.1, 1.1, k / 2.0)
				var b := _put(balls, _ball(0.16), snow, Vector3(x, 1.6 + sin(k * 1.4) * 0.35, (k - 1) * 0.25))
				b.set_meta("to", Vector3(2.1 if k != 1 else -2.1, 1.3, 0))
			shell_at = Vector3(0, 1.6, 0)
			shell_scale = Vector3(2.0, 1.0, 1.0) * 1.2
		2:                                                   # the snowbird, wings out, mid-flight
			var feathers := _mat(Color(0.92, 0.95, 1.0), 0.05, 0.8)
			thing.position = Vector3(0, 2.0, 0)
			_put(thing, _ball(0.25), feathers, Vector3.ZERO, Vector3(1.5, 1.0, 1.0))
			_put(thing, _ball(0.16), feathers, Vector3(-0.38, 0.14, 0))
			_put(thing, _cone(0.0, 0.05, 0.16), _mat(Color(1.0, 0.75, 0.3)), Vector3(-0.58, 0.12, 0), Vector3.ONE, Vector3(0, 0, PI / 2))
			for s in [-1.0, 1.0]:
				_put(thing, _ball(0.03), dark, Vector3(-0.47, 0.2, s * 0.09))
				var wing := Node3D.new()
				wing.name = "WingL" if s < 0 else "WingR"
				wing.position = Vector3(0, 0.1, s * 0.18)
				thing.add_child(wing)
				_put(wing, _ball(0.2), _mat(Color(0.7, 0.85, 1.0), 0.05, 0.8), Vector3(0, 0, s * 0.35), Vector3(1.2, 0.2, 2.0), Vector3(0, 0, 0.3 * s))
			_put(thing, _cone(0.0, 0.12, 0.35), feathers, Vector3(0.48, 0.05, 0), Vector3(1, 1, 0.3), Vector3(0, 0, -PI / 2))
			shell_at = Vector3(0, 2.0, 0)
			shell_scale = Vector3.ONE * 1.1
	var shell := Node3D.new()
	shell.name = "Shell"
	shell.position = shell_at
	g.add_child(shell)
	var glass := _put(shell, _ball(1.0, 16), _ice_mat(), Vector3.ZERO, shell_scale)
	glass.name = "Ice"
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 5:                                              # a few frosty facets on the outside
		var a := k * TAU / 5.0
		_put(shell, _cone(0.0, 0.18, 0.5), _ice_mat(), Vector3(cos(a), 0.4 * sin(k * 2.0), sin(a)) * shell_scale * 0.9,
			Vector3.ONE, Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
	return g


static func ice_block_model() -> Node3D:
	# The block of ice the Frost Gloop is frozen in, sitting on its throne
	var g := Node3D.new()
	var glass := _put(g, BoxMesh.new(), _ice_mat(), Vector3(0, 1.1, 0), Vector3(5.2, 4.6, 5.2))
	glass.name = "Ice"
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 8:
		var a := k * TAU / 8.0 + 0.3
		_put(g, _cone(0.0, 0.5, 1.6 + (k % 3) * 0.6), _ice_mat(), Vector3(cos(a) * 2.4, 3.4 + (k % 2) * 0.4, sin(a) * 2.4),
			Vector3.ONE, Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))
	return g


static func clock_model() -> Node3D:
	# The great clock hanging in the sky, facing the bowl: frosted face, twelve ticks, three hands
	var g := Node3D.new()
	var face := _cone(6.0, 6.0, 0.4)
	face.radial_segments = 48
	_put(g, face, _mat(Color(0.88, 0.94, 1.0), 0.35, 0.3), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 5.9
	rim.outer_radius = 6.6
	rim.rings = 48
	_put(g, rim, _mat(Color(0.55, 0.7, 0.95), 0.2, 0.2), Vector3.ZERO, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var ink := _mat(Color(0.2, 0.3, 0.5), 0.0, 0.5)
	for k in 12:
		var a := k * TAU / 12.0
		var tick := BoxMesh.new()
		tick.size = Vector3(0.3, 0.9 if k % 3 == 0 else 0.5, 0.1)
		_put(g, tick, ink, Vector3(sin(a) * 5.0, cos(a) * 5.0, 0.25), Vector3.ONE, Vector3(0, 0, -a))
	for h in [["Hour", 2.8, 0.35, -2.1], ["Minute", 4.3, 0.22, 0.6], ["Second", 4.8, 0.1, -0.9]]:
		var hand := Node3D.new()
		hand.name = h[0]
		hand.position.z = 0.3 + (0.05 if h[0] == "Second" else 0.0)
		hand.rotation.z = h[3]
		g.add_child(hand)
		var bar := BoxMesh.new()
		bar.size = Vector3(h[2], h[1], 0.08)
		_put(hand, bar, _mat(Color(1.0, 0.45, 0.6), 0.6) if h[0] == "Second" else ink, Vector3(0, h[1] / 2.0 - 0.3, 0))
	_put(g, _ball(0.45), _mat(Color(0.55, 0.7, 0.95), 0.3), Vector3(0, 0, 0.35))
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.88, 1.0)
	light.light_energy = 1.5
	light.omni_range = 14.0
	light.position.z = 3.0
	g.add_child(light)
	return g
