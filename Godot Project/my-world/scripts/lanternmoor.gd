extends "res://scripts/portal_world.gd"

# Lanternmoor, Pip's home world (plan item 19a world 3; scene built by tools/build_lanternmoor.gd). A soft moor under a
# violet night sky, full of glowing moths and lantern trees, where the sun won't rise: the Dawn Snatcher (a big Time
# Goblin, scripts/dawn_snatcher.gd) caught the dawn and shut it in the clock he wears as a hat. Three beacons call the
# dawn back, and lighting all three wakes him:
#   Beacon1  the Night Path: light its five lanterns (Interact, or a Star Popper bubble) and the beacon at its end lights
#   Beacon2  on Moon Rock: too far to jump to, so climb the Tall Lantern Tree and glide over on Pip's moth wings
#            (hold Jump on the way down: scenes/player/player.gd glide_fall), then light it
#   Beacon3  in the Lantern Grove: its light ran off as three runaway lights that flit away when you come near.
#            Catch them (run into them, or pop a bubble at them) and they fly home into it
# With all three lit, the Dawn Snatcher wakes on Sunrise Hill when you come near. Pop him and the world mends
# (Portals.clear): the dawn floats out of his clock and up into the sky, and the night turns to morning.
# Pip, the moth kid, waits by the way in, and the first time you talk they lend you their moth wings. They only work here.
# Nothing here hurts more than a normal bump; falling off the tree or the rock just lands you softly on the moor.
# Slice two, the reward: as the sun comes up Pip teaches you Pip's glow (scripts/pip_glow.gd: in the dark you shine,
# anywhere), and a hollow opens in the moor near the way in, down into the Glimmer Caves (scripts/glimmer_caves.gd),
# which only the glow lights. They're there every visit once it's mended.

const SNATCHER_SCENE := preload("res://scenes/enemies/time_goblin_boss.tscn")
const SNATCHER_SCRIPT := preload("res://scripts/dawn_snatcher.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const GLIMMER_CAVES := preload("res://scripts/glimmer_caves.gd")
const TEACH_AFTER := DAWN_TIME + 1.5      # seconds after the Snatcher's popped: Pip teaches the glow, the hollow opens
const LANTERNS := 5
const BEACON_NAMES := ["the Night Path's beacon", "the beacon on Moon Rock", "the Lantern Grove's beacon"]
const LIGHTS := 3
const GLIDE_FALL := 1.2                   # m/s: with the moth wings, holding Jump while falling floats you down this slowly
const WAKE_NEAR := 16.0                   # coming this close to Sunrise Hill with all three beacons lit wakes him
const FLEE_NEAR := 6.0                    # a runaway light flits off when you're this close...
const LIGHT_SPEED := 3.6                  # ...this fast (slower than you run: chase it into the grove's edge)
const CATCH_NEAR := 1.4
const GROVE_R := 9.0                      # the runaway lights stay this close to the grove's middle
const DAWN_TIME := 6.0                    # seconds the sunrise takes
const MOTHS := 140
const STARS := 260
const WARM := Color(1.0, 0.75, 0.45)
const UNLIT := Color(0.25, 0.22, 0.32)

# Night and dawn: the sky, the light and the fog lerp between these (set_dawn)
const NIGHT := {"top": Color(0.1, 0.06, 0.24), "horizon": Color(0.36, 0.22, 0.5), "ground": Color(0.36, 0.22, 0.5),
	"ambient": Color(0.45, 0.38, 0.7), "fog": Color(0.32, 0.22, 0.5), "light": Color(0.7, 0.68, 1.0), "energy": 0.45}
const MORNING := {"top": Color(0.38, 0.52, 0.9), "horizon": Color(1.0, 0.72, 0.58), "ground": Color(0.75, 0.6, 0.6),
	"ambient": Color(0.85, 0.75, 0.8), "fog": Color(0.95, 0.75, 0.7), "light": Color(1.0, 0.85, 0.65), "energy": 1.1}

var snatcher_awake := false
var dawn := 0.0                           # 0 = the stuck night, 1 = morning
var _snatcher: CharacterBody3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun_light: DirectionalLight3D
var _lights: Array = []                   # the runaway lights still loose (Node3D), each with a "home" meta
var _homing := 0                          # caught lights still flying home to the beacon
var _moth_mm: MultiMesh
var _moths: Array = []                    # [centre, radius, speed, phase, height] for each moth
var _wings: Node3D
var _t := 0.0
var caves: Node3D                         # the Glimmer Caves, once it's mended (scripts/glimmer_caves.gd)


func picture() -> void:
	# In the portal's preview: the unlit lanterns and beacons, the sleeping Snatcher's glowing clock, the stars and moths
	_own_sky()
	set_dawn(1.0 if Portals.is_cleared(world_id) else 0.0)
	for i in LANTERNS:
		var m := get_node_or_null("Lantern%d" % (i + 1)) as Node3D
		if m:
			m.add_child(lantern_model(false))
	for i in 3:
		var b := get_node_or_null("Beacon%d" % (i + 1)) as Node3D
		if b:
			b.add_child(beacon_model(false))
	var s := get_node_or_null("Snatcher") as Node3D
	if s:
		var clock := dawn_clock_model()
		s.add_child(clock)
	_add_sky_things()
	_add_moths()


func setup() -> void:
	_own_sky()
	for i in LANTERNS:
		var m := get_node_or_null("Lantern%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var model := lantern_model(is_lantern_lit(i))
		model.name = "Lantern"
		m.add_child(model)
		var spot := USE_SPOT.make(Vector3(0, 0.2, 0), _lantern_offer.bind(i), light_lantern.bind(i), 2.2, 2.8)
		spot.name = "Spot"
		m.add_child(spot)
		var body := SHOT_TARGET.new() as StaticBody3D
		body.name = "Hit"
		body.on_shot = func() -> String: return "hit" if light_lantern(i) else "bounce"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.45
		cs.shape = sp
		body.add_child(cs)
		body.position.y = 1.9
		m.add_child(body)
	for i in 3:
		var b := get_node_or_null("Beacon%d" % (i + 1)) as Node3D
		if b == null:
			continue
		var model := beacon_model(is_beacon_lit(i))
		model.name = "Beacon"
		b.add_child(model)
	var island := get_node_or_null("Beacon2") as Node3D
	if island:
		var spot := USE_SPOT.make(Vector3(0, 0.2, 0), func() -> String: return "" if is_beacon_lit(1) else "light the beacon",
			func() -> void: light_beacon(1), 2.6, 3.0)
		spot.name = "Spot"
		island.add_child(spot)
	var launch := get_node_or_null("Launch") as Node3D
	if launch:
		var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if has_wings() else "look across to Moon Rock",
			_look_across, 2.6, 2.4)
		spot.name = "Spot"
		launch.add_child(spot)
	for i in LIGHTS:
		if not is_light_caught(i) and not is_beacon_lit(2):
			_add_runaway_light(i)
	_add_pip()
	_add_sky_things()
	_add_moths()
	if not Portals.is_cleared(world_id):
		_add_snatcher()
	set_dawn(1.0 if Portals.is_cleared(world_id) else 0.0)
	if Portals.has_found(world_id, "met_pip") or Portals.is_cleared(world_id):
		give_wings()
	if Portals.is_cleared(world_id):
		open_caves()
	if not Portals.is_cleared(world_id) and beacons_lit() == 0 and not Portals.has_found(world_id, "met_pip"):
		Game.message.call_deferred("Lanternmoor: it's night, and the sun just won't come up. Someone's fluttering by the way in...")


func _own_sky() -> void:
	# Each copy of the world gets its own sky, so the sunrise here never changes the portal's preview (or the next trip)
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun_light = get_node_or_null("Sun") as DirectionalLight3D


# The lanterns and beacons -------------------------------------------------------------------------------------------
func is_lantern_lit(i: int) -> bool:
	return Portals.has_found(world_id, "lantern_%d" % (i + 1))


func lanterns_lit() -> int:
	var n := 0
	for i in LANTERNS:
		if is_lantern_lit(i):
			n += 1
	return n


func is_beacon_lit(i: int) -> bool:
	return Portals.is_cleared(world_id) or Portals.has_found(world_id, "beacon_%d" % (i + 1))


func beacons_lit() -> int:
	var n := 0
	for i in 3:
		if is_beacon_lit(i):
			n += 1
	return n


func _lantern_offer(i: int) -> String:
	return "" if is_lantern_lit(i) else "light the lantern"


func light_lantern(i: int) -> bool:
	# One lantern along the Night Path: says whether there was one to light
	if is_lantern_lit(i):
		return false
	Portals.note_found(world_id, "lantern_%d" % (i + 1))
	var m := get_node_or_null("Lantern%d" % (i + 1)) as Node3D
	if m:
		_swap(m, "Lantern", lantern_model(true))
		Fx.burst(self, m.global_position + Vector3(0, 1.9, 0), WARM, 14, 0.06, 2.5, -1.0, 0.8)
	Juice.blip("chime", 1.0 + lanterns_lit() * 0.12, -5.0)
	var n := lanterns_lit()
	if n < LANTERNS:
		Game.message("The lantern glows! (%d of %d along the Night Path)" % [n, LANTERNS])
	else:
		light_beacon(0)
	return true


func light_beacon(i: int) -> void:
	if is_beacon_lit(i):
		return
	Portals.note_found(world_id, "beacon_%d" % (i + 1))
	var b := get_node_or_null("Beacon%d" % (i + 1)) as Node3D
	if b:
		_swap(b, "Beacon", beacon_model(true))
		Fx.burst(self, b.global_position + Vector3(0, 3.4, 0), WARM, 40, 0.1, 5.0, -1.0, 1.2)
	Juice.blip("pop", 0.7, -3.0)
	Juice.shake(0.08)
	var n := beacons_lit()
	Game.message("%s blazes up! (%d of 3 beacons)" % [BEACON_NAMES[i].capitalize(), n] if n < 3
		else "All three beacons are lit! Up on Sunrise Hill, something big just yawned...")


func _swap(marker: Node3D, child: String, model: Node3D) -> void:
	var old := marker.get_node_or_null(child)
	if old:
		old.name = "Old"
		old.queue_free()
	model.name = child
	marker.add_child(model)


func _look_across() -> void:
	if has_wings():
		return
	Game.message("Moon Rock's much too far to jump to. If only you had wings... Pip's by the way in.")
	Audio.play("ui_back", -8.0)


# Pip's moth wings ---------------------------------------------------------------------------------------------------
func has_wings() -> bool:
	return _wings != null and is_instance_valid(_wings)


func give_wings() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or has_wings():
		return
	player.set("glide_fall", GLIDE_FALL)
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual == null:
		return
	_wings = wings_model()
	_wings.name = "Moth Wings"
	visual.add_child(_wings)


static func wings_model() -> Node3D:
	# Two pairs of soft, see-through moth wings in Pip's own pink with glowing yellow spots, worn on the back (the
	# model faces +Z)
	var g := Node3D.new()
	g.position = Vector3(0, 1.05, -0.18)
	var wing := _mat(Color(1.0, 0.62, 0.85, 0.65), 0.4, 0.4)
	wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing.cull_mode = BaseMaterial3D.CULL_DISABLED
	var spot := _mat(Color(1.0, 0.9, 0.4), 1.5)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if side < 0 else "WingR"
		g.add_child(pivot)
		var upper := _put(pivot, _ball(0.3), wing, Vector3(side * 0.32, 0.12, 0), Vector3(1.1, 1.0, 0.08), Vector3(0, 0, side * -0.5))
		upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lower := _put(pivot, _ball(0.2), wing, Vector3(side * 0.24, -0.2, 0), Vector3(1.0, 1.0, 0.08), Vector3(0, 0, side * 0.4))
		lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_put(pivot, _ball(0.06), spot, Vector3(side * 0.38, 0.16, 0.01), Vector3(1, 1, 0.3))
	return g


# The runaway lights -------------------------------------------------------------------------------------------------
func is_light_caught(i: int) -> bool:
	return Portals.has_found(world_id, "light_%d" % (i + 1))


func lights_caught() -> int:
	var n := 0
	for i in LIGHTS:
		if is_light_caught(i):
			n += 1
	return n


func _add_runaway_light(i: int) -> void:
	var m := get_node_or_null("Light%d" % (i + 1)) as Node3D
	if m == null:
		return
	var l := runaway_light_model()
	l.name = "Runaway Light %d" % (i + 1)
	l.set_meta("index", i)
	add_child(l)
	l.global_position = m.global_position
	var body := SHOT_TARGET.new() as StaticBody3D
	body.name = "Hit"
	body.on_shot = func() -> String: return "hit" if catch_light(i) else "bounce"
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5
	cs.shape = sp
	body.add_child(cs)
	l.add_child(body)
	_lights.append(l)


func light_node(i: int) -> Node3D:
	return get_node_or_null("Runaway Light %d" % (i + 1)) as Node3D


func catch_light(i: int) -> bool:
	# Caught! It flies home into the grove's beacon; the third one lights it
	if is_light_caught(i):
		return false
	Portals.note_found(world_id, "light_%d" % (i + 1))
	var l := light_node(i)
	_lights.erase(l)
	var n := lights_caught()
	Juice.blip("sparkle", 1.2 + n * 0.15, -4.0)
	Game.message("You caught a runaway light! (%d of %d)" % [n, LIGHTS] if n < LIGHTS else "That's all three! They're flying home...")
	var beacon := get_node_or_null("Beacon3") as Node3D
	if l == null or beacon == null:
		if n >= LIGHTS:
			light_beacon(2)
		return true
	var hit := l.get_node_or_null("Hit")
	if hit:
		hit.queue_free()
	_homing += 1
	var tw := l.create_tween()
	tw.tween_property(l, "global_position", beacon.global_position + Vector3(0, 3.4, 0), 1.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_homing -= 1
		Fx.burst(self, l.global_position, WARM, 12, 0.06, 2.0, -1.0, 0.6)
		l.queue_free()
		if lights_caught() >= LIGHTS and _homing == 0:
			light_beacon(2))
	return true


func _move_lights(player: Node3D, delta: float) -> void:
	# They bob about the grove, and flit away from you when you come near (but never out of the grove's ring, so you
	# can always chase one into its edge)
	var grove := get_node_or_null("Beacon3") as Node3D
	if grove == null:
		return
	var centre := grove.global_position
	for l in _lights.duplicate():
		var node := l as Node3D
		if not is_instance_valid(node):
			_lights.erase(l)
			continue
		var i := int(node.get_meta("index"))
		var p := node.global_position
		var flat := Vector3.ZERO
		if player:
			var to := p - player.global_position
			to.y = 0.0
			if to.length() < CATCH_NEAR:
				catch_light(i)
				continue
			if to.length() < FLEE_NEAR:
				flat = to.normalized() * LIGHT_SPEED
		if flat == Vector3.ZERO:                                  # drift lazily round in a little circle
			var a := _t * 0.6 + i * 2.1
			flat = Vector3(cos(a), 0, sin(a)) * 1.0
		p += flat * delta
		var off := Vector3(p.x - centre.x, 0, p.z - centre.z)
		if off.length() > GROVE_R:
			off = off.normalized() * GROVE_R
		p = Vector3(centre.x + off.x, 1.2 + sin(_t * 2.0 + i) * 0.3, centre.z + off.z)
		node.global_position = p


static func runaway_light_model() -> Node3D:
	# A little round light with a soft halo and a glow round it, and two tiny wings, so it looks alive
	var g := Node3D.new()
	_put(g, _ball(0.22), _mat(Color(1.0, 0.85, 0.5), 2.0), Vector3.ZERO)
	var halo := _mat(Color(1.0, 0.8, 0.45, 0.3), 1.5)
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_put(g, _ball(0.4), halo, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wing := _mat(Color(1.0, 0.95, 0.8, 0.6), 1.0)
	wing.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in [-1.0, 1.0]:
		_put(g, _ball(0.12), wing, Vector3(s * 0.24, 0.1, 0), Vector3(1.4, 0.8, 0.2), Vector3(0, 0, s * 0.5))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.55)
	light.light_energy = 1.2
	light.omni_range = 3.5
	g.add_child(light)
	return g


# Pip ----------------------------------------------------------------------------------------------------------------
func _add_pip() -> void:
	var m := get_node_or_null("Pip") as Node3D
	if m == null:
		return
	var packed := load("res://models/characters/moth_kid.glb") as PackedScene
	if packed:
		var p := packed.instantiate() as Node3D
		p.name = "Model"
		m.add_child(p)
		var anim := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim:
			var pick := "fly" if anim.has_animation("fly") else "idle"
			if anim.has_animation(pick):
				anim.get_animation(pick).loop_mode = Animation.LOOP_LINEAR
				anim.play(pick)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Pip", _talk_pip, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func pip_lines() -> Array:
	# Pip's bubbly and a bit nervous in the endless dark (for once!), then says what's next
	if Portals.is_cleared(world_id):
		var found: int = caves.moths_found() if caves else 0
		if found >= GLIMMER_CAVES.MOTHS.size():
			return ["All five moonmoths came home! Listen to them, they're humming. That's moth for thank you.",
				"The Glimmer Caves are yours to explore whenever you like. Your glow knows the way now."]
		if found > 0:
			return ["%d moonmoth%s home, %d still lost in the Glimmer Caves." % [found, "" if found == 1 else "s",
				GLIMMER_CAVES.MOTHS.size() - found],
				"They only show up in your glow. Look high, look low, and look across the pool!"]
		return ["Look at that morning! I'm a moth, I'm supposed to like the night, but nights are cosier when you know the morning's coming.",
			"Don't forget the Glimmer Caves, down the hollow by the way in. Your glow lights them up.",
			"There's a moth lift at the bottom: hold {jump} in it and it floats you back up."]
	if not Portals.has_found(world_id, "met_pip"):
		Portals.note_found(world_id, "met_pip")
		give_wings()
		return ["{player}! You found Lanternmoor! This is my home. Isn't it glowy?",
			"But it's been night for ages and ages. The sun just... won't... come... up.",
			"A big grumpy Time Goblin snatched the dawn and shut it in his clock. He's asleep on Sunrise Hill, hugging it.",
			"If we light the three beacons, the dawn might be strong enough to get out!",
			"Oh! Here, have some wings. Moth wings! Hold {jump} on the way down and you'll float. Like me!",
			"One beacon's at the end of the Night Path, one's on Moon Rock, and one's in the Lantern Grove."]
	var left: Array = []
	for i in 3:
		if not is_beacon_lit(i):
			left.append(["light the five lanterns along the Night Path", "glide to Moon Rock from the top of the Tall Lantern Tree",
				"catch the runaway lights in the Lantern Grove"][i])
	if left.size() > 0:
		return ["%d beacon%s lit! It's getting brighter, I can feel it." % [3 - left.size(), "" if 3 - left.size() == 1 else "s"]
			if left.size() < 3 else "Remember: hold {jump} while you're falling, and your wings float you.",
			"Still to do: %s." % ", and ".join(left)]
	return ["All three beacons! The Dawn Snatcher's waking up on Sunrise Hill...",
		"Pop him with bubbles or stomps! When his clock goes BONG, jump the rings.",
		"I'll hold my lantern up so you can see. Go, go, go!"]


func _talk_pip() -> void:
	var spot := get_node_or_null("Pip/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Pip", pip_lines().map(func(l: String) -> String: return Settings.fill(l)), "lanternmoor_pip")


# The Dawn Snatcher --------------------------------------------------------------------------------------------------
func _add_snatcher() -> void:
	var m := get_node_or_null("Snatcher") as Node3D
	if m == null:
		return
	var g := SNATCHER_SCENE.instantiate() as CharacterBody3D
	g.set_script(SNATCHER_SCRIPT)
	g.name = "The Dawn Snatcher"                              # not "Time Goblin …", so finding goblins by name skips him
	g.set("world", self)
	g.set("size", 2.4)
	g.set("color", Color(1.0, 0.75, 0.4))
	g.set("stomps_to_defeat", 13)
	g.set("damage", 2)
	g.set("xp_reward", 50)
	g.set("wander_radius", 5.0)
	g.set("sight_range", 16.0)
	g.set("leash_range", 26.0)
	g.set("wander_speed", 1.2)
	g.set("chase_speed", 3.3)
	g.set("blink_cooldown", 7.0)
	g.set("blink_chance", 0.85)
	g.set("dizzy_time", 2.4)
	g.set("respawns", false)
	g.process_mode = Node.PROCESS_MODE_DISABLED              # fast asleep until the beacons wake him
	add_child(g)
	g.global_position = m.global_position
	_snatcher = g
	var zzz := Label3D.new()
	zzz.name = "Snoring"
	zzz.text = "Z z z"
	zzz.font_size = 72
	zzz.pixel_size = 0.01
	zzz.outline_size = 12
	zzz.modulate = Color(0.85, 0.8, 1.0)
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.position = Vector3(1.2, 6.2, 0)
	m.add_child(zzz)
	var spot := USE_SPOT.make(Vector3(0, -0.6, 4.0), func() -> String: return "" if snatcher_awake else "look at the sleeping goblin",
		_look_at_snatcher, 2.6, 3.0)
	spot.name = "Spot"
	m.add_child(spot)


func _look_at_snatcher() -> void:
	if snatcher_awake:
		return
	var left := 3 - beacons_lit()
	Game.message("A huge Time Goblin, snoring, with a golden glow shut up in his clock hat: the dawn! Light the %d beacon%s first." % [left, "" if left == 1 else "s"]
		if left > 0 else "He's stirring...")
	Audio.play("ui_back", -8.0)


func wake_snatcher() -> void:
	if snatcher_awake or _snatcher == null or not is_instance_valid(_snatcher):
		return
	snatcher_awake = true
	for n in ["Snatcher/Snoring", "Snatcher/Spot"]:
		var x := get_node_or_null(n)
		if x:
			x.queue_free()
	_snatcher.process_mode = Node.PROCESS_MODE_INHERIT
	Fx.burst(self, _snatcher.global_position + Vector3(0, 3.0, 0), WARM, 30, 0.1, 5.0, -2.0, 1.0)
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("pop", 0.5, -2.0)
	Game.message("The Dawn Snatcher wakes up, grumpy! Bubbles or stomps pop him. When his clock goes BONG, jump the rings!")


func mend() -> void:
	# The dawn floats out of his clock and up into the sky, and the night turns to morning
	snatcher_awake = false
	var from := _snatcher.global_position + Vector3(0, 5.0, 0) if _snatcher and is_instance_valid(_snatcher) \
		else (get_node("Snatcher") as Node3D).global_position + Vector3(0, 5.0, 0)
	if _snatcher and is_instance_valid(_snatcher):
		for g in _snatcher.helpers():                         # his goblins go pop with him
			if is_instance_valid(g) and not g.defeated:
				g.shot(99, g.global_position, Vector3.UP)
	Portals.clear(world_id)
	for i in 3:                                              # (all the beacons blaze, however they got lit)
		var b := get_node_or_null("Beacon%d" % (i + 1)) as Node3D
		if b:
			_swap(b, "Beacon", beacon_model(true))
	var sun := sun_model()
	sun.name = "Rising Sun"
	add_child(sun)
	sun.global_position = from
	var to := (get_node_or_null("SunRise") as Node3D)
	var tw := create_tween()
	tw.tween_property(sun, "global_position", to.global_position if to else from + Vector3(0, 30, -60), DAWN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(sun, "scale", Vector3.ONE * 6.0, DAWN_TIME)
	tw.parallel().tween_method(set_dawn, dawn, 1.0, DAWN_TIME)
	Fx.burst(self, from, WARM, 60, 0.12, 6.0, -1.0, 1.6)
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	Juice.blip("chime", 0.8, -3.0)
	get_tree().create_timer(TEACH_AFTER).timeout.connect(_teach_glow)


# The reward: Pip's glow, and the Glimmer Caves ------------------------------------------------------------------------
func open_caves() -> void:
	# The hollow opens and the caves are made under the moor (a second or so: only ever once a visit)
	if caves or has_meta("preview"):
		return
	caves = GLIMMER_CAVES.new()
	caves.name = "Glimmer Caves"
	add_child(caves)
	caves.build(self)


func teach_lines() -> Array:
	return ["{player}, wait! Before you go, I want to give you something. My glow!",
		"Moths are made of a little bit of moonlight. Now you are too.",
		"Whenever it's dark, you'll glow. Caves, tunnels, the night time. No buttons, it just happens!",
		"And look, the morning opened up the old hollow by the way in. It goes down into the Glimmer Caves.",
		"It's SO dark down there, nobody's been in for ages. Five of my moonmoths got lost in there, too.",
		"Your glow will light the way. Crystals wake up when it touches them, and there's a bridge only glow can see!"]


func _teach_glow(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:             # wait for a talk to finish first
		get_tree().create_timer(1.0).timeout.connect(_teach_glow.bind(tries + 1))
		return
	open_caves()
	Juice.rumble(0.4, 0.5)
	Juice.shake(0.2)
	var spot := get_node_or_null("Pip/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Pip", teach_lines().map(func(l: String) -> String: return Settings.fill(l)), "lanternmoor_glow")
	else:
		Game.message("New: Pip's glow! In the dark you shine. The Glimmer Caves have opened by the way in.")


func is_morning() -> bool:
	return dawn >= 0.99


func set_dawn(k: float) -> void:
	# The sky, the light and the fog, from the stuck night (0) to morning (1)
	dawn = clampf(k, 0.0, 1.0)
	if _sky:
		_sky.sky_top_color = (NIGHT.top as Color).lerp(MORNING.top, dawn)
		_sky.sky_horizon_color = (NIGHT.horizon as Color).lerp(MORNING.horizon, dawn)
		_sky.ground_horizon_color = (NIGHT.ground as Color).lerp(MORNING.ground, dawn)
	if _env:
		_env.ambient_light_color = (NIGHT.ambient as Color).lerp(MORNING.ambient, dawn)
		_env.fog_light_color = (NIGHT.fog as Color).lerp(MORNING.fog, dawn)
	if _sun_light:
		_sun_light.light_color = (NIGHT.light as Color).lerp(MORNING.light, dawn)
		_sun_light.light_energy = lerpf(NIGHT.energy, MORNING.energy, dawn)
		_sun_light.rotation_degrees = Vector3(lerpf(-42.0, -18.0, dawn), lerpf(-30.0, 30.0, dawn), 0)
	var stars := get_node_or_null("Stars") as GeometryInstance3D
	if stars:
		stars.transparency = dawn
		stars.visible = dawn < 0.98
	var moon := get_node_or_null("Moon/Moon") as GeometryInstance3D
	if moon:
		moon.transparency = dawn * 0.85
	if is_morning() and get_node_or_null("Rising Sun") == null and get_node_or_null("Morning Sun") == null:
		var s := sun_model()
		s.name = "Morning Sun"
		add_child(s)
		var to := get_node_or_null("SunRise") as Node3D
		s.global_position = to.global_position if to else Vector3(60, 34, -110)
		s.scale = Vector3.ONE * 6.0


# Stars, the moon and the moths --------------------------------------------------------------------------------------
func _add_sky_things() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.albedo_color = Color(1.0, 0.95, 1.0)
	sm.disable_fog = true
	q.material = sm
	mm.mesh = q
	mm.instance_count = STARS
	for i in STARS:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.15, 1.0)
		var d := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		var s := rng.randf_range(0.6, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), d * 170.0))
	var mi := MultiMeshInstance3D.new()
	mi.name = "Stars"
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-180, -10, -180), Vector3(360, 190, 360))
	add_child(mi)
	var m := get_node_or_null("Moon") as Node3D
	if m:
		var mat := _mat(Color(0.95, 0.92, 1.0), 1.6)
		mat.disable_fog = true
		var moon := _put(m, _ball(7.0, 24), mat, Vector3.ZERO)
		moon.name = "Moon"
		moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_moths() -> void:
	# Little glowing moths fluttering in loops round the lantern trees and the beacons
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var centres: Array = []
	for n in ["Lantern Trees", "Lantern Grove"]:
		var holder := get_node_or_null(n)
		if holder:
			for c in holder.get_children():
				if c.name.begins_with("Lantern Tree"):
					centres.append((c as Node3D).global_position + Vector3(0, 2.6, 0))
	for n in ["Beacon1", "Beacon3", "Pip"]:
		var b := get_node_or_null(n) as Node3D
		if b:
			centres.append(b.global_position + Vector3(0, 2.0, 0))
	if centres.is_empty():
		centres.append(Vector3(0, 2, 0))
	_moths = []
	for i in MOTHS:
		_moths.append([centres[i % centres.size()], rng.randf_range(0.8, 2.6), rng.randf_range(0.8, 2.0) * (1 if i % 2 else -1),
			rng.randf() * TAU, rng.randf_range(-0.8, 1.2)])
	_moth_mm = MultiMesh.new()
	_moth_mm.transform_format = MultiMesh.TRANSFORM_3D
	_moth_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.12)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = fm
	_moth_mm.mesh = q
	_moth_mm.instance_count = MOTHS
	var colours := [Color(1.0, 0.85, 0.55), Color(0.75, 0.85, 1.0), Color(1.0, 0.65, 0.9)]
	for i in MOTHS:
		_moth_mm.set_instance_color(i, colours[i % colours.size()])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Moths"
	mi.multimesh = _moth_mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 20, 120))
	add_child(mi)
	_place_moths()


func _place_moths() -> void:
	for i in _moths.size():
		var m: Array = _moths[i]
		var a: float = m[3] + _t * float(m[2])
		var c: Vector3 = m[0]
		var r: float = m[1]
		var flap := 0.6 + absf(sin(_t * 14.0 + i)) * 0.6               # wings beating: the quad squashes and stretches
		var p := c + Vector3(cos(a) * r, float(m[4]) + sin(_t * 1.7 + i) * 0.35, sin(a) * r)
		_moth_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(flap, 1.0, 1.0)), p))


func _process(delta: float) -> void:
	_t += delta
	if _moth_mm:
		_place_moths()
	var sun := get_node_or_null("Rising Sun") as Node3D
	if sun:
		sun.rotate_y(delta * 0.3)
	if has_meta("preview"):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_move_lights(player, delta)
	_flap_wings(player, delta)
	_face_player(player, delta)
	if Portals.is_cleared(world_id):
		return
	var hill := get_node_or_null("Snatcher") as Node3D
	if not snatcher_awake and player and hill and beacons_lit() == 3 \
			and player.global_position.distance_to(hill.global_position) < WAKE_NEAR:
		wake_snatcher()


func _flap_wings(player: Node3D, delta: float) -> void:
	# The moth wings fold in when you walk, spread wide and beat slowly while you glide
	if not has_wings() or player == null:
		return
	var open := bool(player.get("gliding"))
	for k in ["WingL", "WingR"]:
		var w := _wings.get_node_or_null(k) as Node3D
		if w == null:
			continue
		var side := -1.0 if k == "WingL" else 1.0
		var want := (0.15 + sin(_t * 6.0) * 0.25) if open else 1.1
		w.rotation.y = lerp_angle(w.rotation.y, side * want, minf(1.0, delta * 8.0))


func _face_player(player: Node3D, delta: float) -> void:
	# Pip turns to look at you when you come near, bobbing in the air as they flutter
	var m := get_node_or_null("Pip/Model") as Node3D
	if m == null:
		return
	m.position.y = 0.25 + sin(_t * 2.2) * 0.12
	if player == null:
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
		m.emission = Color(colour.r, colour.g, colour.b)
		m.emission_energy_multiplier = emit
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


static func _cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func lantern_model(lit: bool) -> Node3D:
	# A path lantern: a crooked dark post with a hooked arm and a round paper lantern hanging from it
	var g := Node3D.new()
	var post := _mat(Color(0.18, 0.14, 0.22), 0.0, 0.9)
	_put(g, _cyl(0.06, 0.09, 2.2), post, Vector3(0, 1.1, 0))
	_put(g, _cyl(0.04, 0.04, 0.5), post, Vector3(0, 2.15, 0.2), Vector3.ONE, Vector3(PI / 2, 0, 0))
	var paper := _mat(WARM if lit else UNLIT, 1.4 if lit else 0.0, 0.6)
	var shade := _put(g, _ball(0.26), paper, Vector3(0, 1.9, 0.42), Vector3(1.0, 1.25, 1.0))
	shade.name = "Shade"
	var cap := _mat(Color(0.3, 0.22, 0.35), 0.0, 0.7)
	_put(g, _cyl(0.08, 0.14, 0.08), cap, Vector3(0, 2.25, 0.42))
	_put(g, _cyl(0.12, 0.06, 0.06), cap, Vector3(0, 1.56, 0.42))
	if lit:
		var light := OmniLight3D.new()
		light.name = "Glow"
		light.light_color = WARM
		light.light_energy = 1.4
		light.omni_range = 5.5
		light.position = Vector3(0, 1.9, 0.42)
		g.add_child(light)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.12
	c.height = 2.2
	cs.shape = c
	cs.position.y = 1.1
	body.add_child(cs)
	g.add_child(body)
	return g


static func beacon_model(lit: bool) -> Node3D:
	# A beacon: a tall stone pillar with a big iron cage on top holding a lantern-flower that blazes when it's lit
	var g := Node3D.new()
	var stone := _mat(Color(0.42, 0.38, 0.52), 0.0, 0.9)
	_put(g, _cyl(0.45, 0.65, 2.6, 10), stone, Vector3(0, 1.3, 0))
	_put(g, _cyl(0.7, 0.55, 0.3, 10), stone, Vector3(0, 2.7, 0))
	var iron := _mat(Color(0.15, 0.12, 0.18), 0.0, 0.5)
	for k in 6:
		var a := k * TAU / 6.0
		_put(g, _cyl(0.04, 0.04, 1.2, 4), iron, Vector3(cos(a) * 0.55, 3.4, sin(a) * 0.55))
	_put(g, _cyl(0.0, 0.65, 0.4, 10), iron, Vector3(0, 4.15, 0))
	var flame := _mat(WARM if lit else UNLIT, 2.2 if lit else 0.0, 0.5)
	var heart := _put(g, _ball(0.4), flame, Vector3(0, 3.35, 0), Vector3(1.0, 1.3, 1.0))
	heart.name = "Flame"
	if lit:
		var light := OmniLight3D.new()
		light.name = "Glow"
		light.light_color = WARM
		light.light_energy = 3.0
		light.omni_range = 12.0
		light.position = Vector3(0, 3.4, 0)
		g.add_child(light)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = 0.65
	c.height = 4.4
	cs.shape = c
	cs.position.y = 2.2
	body.add_child(cs)
	g.add_child(body)
	return g


static func dawn_clock_model() -> Node3D:
	# For the portal's preview: the Snatcher's clock with the dawn glowing inside (the real goblin isn't in a picture)
	var g := Node3D.new()
	var wood := _mat(Color(0.35, 0.22, 0.2), 0.0, 0.8)
	_put(g, BoxMesh.new(), wood, Vector3(0, 1.6, 0), Vector3(1.4, 3.2, 1.0))
	var glow := _mat(Color(1.0, 0.72, 0.35), 3.0)
	_put(g, _cyl(0.5, 0.5, 0.05, 24), glow, Vector3(0, 2.6, 0.52), Vector3.ONE, Vector3(PI / 2, 0, 0))
	_put(g, BoxMesh.new(), glow, Vector3(0, 1.2, 0.51), Vector3(0.8, 1.2, 0.02))
	return g


static func sun_model() -> Node3D:
	# The dawn, let out: a warm glowing ball with soft rays round it (and a light, so the moor turns gold under it)
	var g := Node3D.new()
	var core := _mat(Color(1.0, 0.8, 0.45), 4.0)
	core.disable_fog = true
	_put(g, _ball(1.0, 20), core, Vector3.ZERO).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ray := _mat(Color(1.0, 0.7, 0.4, 0.5), 2.0)
	ray.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.disable_fog = true
	for k in 10:
		var a := k * TAU / 10.0
		_put(g, _cyl(0.0, 0.22, 0.9, 4), ray, Vector3(cos(a), sin(a), 0) * 1.45, Vector3.ONE, Vector3(0, 0, a - PI / 2)) \
			.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.55)
	light.light_energy = 2.0
	light.omni_range = 18.0
	g.add_child(light)
	return g
