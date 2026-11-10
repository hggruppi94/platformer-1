extends "res://scripts/portal_world.gd"

# The Far Future, Dash and Rex's home (plan item 19a world 8, the last portal world; scene built by
# tools/build_far_future.gd). Lumen City, a bright neon city from the furthest future there is, and it's FADING: all
# the time broken in the other worlds is catching up with it, last of all. Its colours are washing out, its lights are
# dimming, and the far towers flicker out of time (set_fade()). The Tomorrow Clock in the middle keeps the city's time,
# and it has lost its three Time Cores. Bring them home:
#   Core 1  Dash's lab: the Swap-o-Tron's three Chrono Fuses have blown. Fit new ones (Interact, or a bubble): one by
#           the machine, one up on the gallery and one out on the roof (hover lifts carry you up to both)
#   Core 2  the Skyway Run (scripts/races.gd "skyway_run"), a rocket-ride race round the sky road: finish it, any place
#   Core 3  the Fading Plaza: six people are fading out of time. Get close (or pop a bubble at them) and your watch's
#           tick pins each one back into it. Two are up on the balcony, by the hover steps
# Each core coming home brightens the city a little. With all three, Captain Glitch (scripts/captain_glitch.gd), the
# Agent of Chaos's lieutenant, flickering on the clock's dais, wakes when you come near. Pop him and the future stops
# fading (mend()): every light in the city comes on, there are fireworks, and he flees through a rift to the Void, where
# his master is waiting. (Slice two, the reward: Rex's shot at his own body back in the mended Swap-o-Tron, and the
# Agent of Chaos's final fight opening.)
# Rex (in the husky's body) waits by the way in, Dash in his lab. Nothing here hurts more than a bump; falling off the
# Skyway just lands you on the city floor (in the race it pops you back up onto the road).

const CAPTAIN := preload("res://scripts/captain_glitch.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const RACE := "skyway_run"
const FUSES := 3
const FOLK := [
	{"name": "Juno", "body": "cat", "colors": {"fur": 5, "hair": 13, "eyes": 14, "accent": 13, "top": 13, "bottoms": 14, "shoes": 15}},
	{"name": "Pixel", "body": "bunny", "colors": {"fur": 7, "hair": 9, "eyes": 13, "accent": 9, "top": 9, "bottoms": 13, "shoes": 14}},
	{"name": "Grandpa Gizmo", "body": "dino", "colors": {"fur": 11, "hair": 7, "eyes": 12, "accent": 12, "top": 12, "bottoms": 15, "shoes": 15}},
	{"name": "Vega", "body": "hippo", "colors": {"fur": 13, "hair": 14, "eyes": 9, "accent": 14, "top": 14, "bottoms": 9, "shoes": 13}},
	{"name": "Bleep", "body": "cat", "colors": {"fur": 9, "hair": 12, "eyes": 13, "accent": 12, "top": 15, "bottoms": 12, "shoes": 9}},
	{"name": "Orla", "body": "cow", "colors": {"fur": 7, "hair": 13, "eyes": 14, "accent": 13, "top": 13, "bottoms": 15, "shoes": 14}},
]
const PIN_NEAR := 2.4                     # this close (and not far above or below) and your watch pins someone in time
const WAKE_NEAR := 16.0                   # coming this close to the captain with all three cores wakes him
const MEND_TIME := 4.0                    # seconds the city takes to brighten
const THANKS_AFTER := MEND_TIME + 1.0
const LIFT_TIME := 1.1                    # seconds a hover lift takes to carry you up
const FADED := 0.85                       # how faded the city is with no cores home (1 = all grey)
const CORE_COLOURS := [Color(0.55, 1.0, 0.4), Color(1.0, 0.82, 0.35), Color(0.4, 1.0, 1.0)]
const TRAFFIC := 16

var fade := 1.0                           # 0 = mended, bright; FADED = no cores
var captain_awake := false
var _captain: CharacterBody3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _neon: Array = []                     # [material, its full glow] for every "Neon ..." material in this copy
var _towers: Array = []                   # the skyline's towers (they flicker out while it's fading)
var _traffic: Array = []                  # [pod, centre, radius, speed, phase, height]
var _fireworks := 0.0
var _lifting := false
var _t := 0.0


func picture() -> void:
	# In the portal's preview: the city as it is (faded or bright), with its traffic going round
	_own_look()
	for i in 3:
		_show_core(i)
	_add_traffic()
	set_fade(0.0 if Portals.is_cleared(world_id) else _goal_fade())


func setup() -> void:
	_own_look()
	for i in FUSES:
		_add_fuse(i)
	for i in 2:
		_add_lift(i)
	_add_swap_o_tron()
	_add_friend("Rex", "res://models/characters/wolf.glb", "talk to Rex", _talk_rex)
	_add_friend("Dash", "res://models/characters/bike_boy.glb", "talk to Dash", _talk_dash)
	for i in FOLK.size():
		_add_folk(i)
	for i in 3:
		_show_core(i)
	_add_traffic()
	if not Portals.is_cleared(world_id):
		_add_captain()
	set_fade(0.0 if Portals.is_cleared(world_id) else _goal_fade())
	Races.finished.connect(_on_race_finished)
	if not Portals.is_cleared(world_id) and cores() == 0 and not Portals.has_found(world_id, "met_rex"):
		Game.message.call_deferred("The Far Future: Lumen City, a neon city from the furthest future... and it's fading away. A husky's waving by the way in.")


func _own_look() -> void:
	# Each copy of the world gets its own sky and its own neon, so mending it here never changes the portal's preview
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	var copies := {}
	for m in find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or not mat.resource_name.begins_with("Neon"):
			continue
		if not copies.has(mat):
			var c := mat.duplicate() as StandardMaterial3D
			copies[mat] = c
			_neon.append([c, mat.emission_energy_multiplier])
		mi.material_override = copies[mat]
	var sky := get_node_or_null("Skyline") as Node3D
	if sky:
		for t in sky.get_children():
			if str(t.name).begins_with("Tower"):
				_towers.append(t)


# The fading ---------------------------------------------------------------------------------------------------------
func _goal_fade() -> float:
	return FADED * (1.0 - cores() / 3.0 * 0.75)


func is_mended() -> bool:
	return Portals.is_cleared(world_id) and fade <= 0.01


func set_fade(k: float) -> void:
	# The colour drains out of the whole city (the environment's saturation), and its neon dims
	fade = clampf(k, 0.0, 1.0)
	if _env:
		_env.adjustment_enabled = true
		_env.adjustment_saturation = lerpf(1.15, 0.12, fade)
		_env.adjustment_brightness = lerpf(1.0, 0.85, fade)
		_env.fog_density = lerpf(0.004, 0.012, fade)
	if _sky:
		_sky.sky_top_color = Color(0.08, 0.2, 0.42).lerp(Color(0.3, 0.3, 0.36), fade)
		_sky.sky_horizon_color = Color(0.95, 0.5, 0.75).lerp(Color(0.62, 0.6, 0.66), fade)
	for n in _neon:
		(n[0] as StandardMaterial3D).emission_energy_multiplier = float(n[1]) * lerpf(1.0, 0.2, fade)
	if fade <= 0.0:
		for t in _towers:
			(t as Node3D).visible = true


func _flicker(delta: float) -> void:
	# While it's fading, the skyline's towers wink out of time for a moment, more often the more faded it is
	for t in _towers:
		var n := t as Node3D
		if not n.visible:
			if n.has_meta("back") and _t >= float(n.get_meta("back")):
				n.visible = true
		elif fade > 0.05 and randf() < fade * delta * 0.25:
			n.visible = false
			n.set_meta("back", _t + randf_range(0.1, 0.5))


# The Chrono Fuses (core 1) -------------------------------------------------------------------------------------------
func is_fuse_fixed(i: int) -> bool:
	return Portals.has_found(world_id, "fuse_%d" % (i + 1)) or Portals.is_cleared(world_id)


func fuses_fixed() -> int:
	var n := 0
	for i in FUSES:
		if is_fuse_fixed(i):
			n += 1
	return n


func _add_fuse(i: int) -> void:
	var m := get_node_or_null("Fuse%d" % (i + 1)) as Node3D
	if m == null:
		return
	var model := fuse_model(is_fuse_fixed(i))
	model.name = "Fuse"
	m.add_child(model)
	var spot := USE_SPOT.make(Vector3(0, 0.2, 0), func() -> String: return "" if is_fuse_fixed(i) else "fit a new Chrono Fuse",
		fix_fuse.bind(i), 2.0, 2.4)
	spot.name = "Spot"
	m.add_child(spot)
	var body := SHOT_TARGET.new() as StaticBody3D
	body.name = "Hit"
	body.on_shot = func() -> String: return "hit" if fix_fuse(i) else "bounce"
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.4
	cs.shape = sp
	body.add_child(cs)
	body.position.y = 0.9
	m.add_child(body)


func fix_fuse(i: int) -> bool:
	if is_fuse_fixed(i):
		return false
	Portals.note_found(world_id, "fuse_%d" % (i + 1))
	var m := get_node_or_null("Fuse%d" % (i + 1)) as Node3D
	if m:
		var old := m.get_node_or_null("Fuse")
		if old:
			old.free()
		var model := fuse_model(true)
		model.name = "Fuse"
		m.add_child(model)
		Fx.burst(self, m.global_position + Vector3(0, 0.9, 0), CORE_COLOURS[0], 18, 0.06, 3.0, -1.0, 0.7)
	Juice.blip("chime", 1.0 + i * 0.15, -5.0)
	var n := fuses_fixed()
	if n < FUSES:
		Game.message("ZAP! A new Chrono Fuse clicks in. (%d of %d)" % [n, FUSES])
	else:
		_swap_o_tron_on()
		bring_core(0)
	return true


func _add_lift(i: int) -> void:
	# A hover lift: a glowing pad with a beam over it. Interact on it and it floats you up to the gallery or the roof
	var m := get_node_or_null("Lift%d" % (i + 1)) as Node3D
	if m == null:
		return
	var model := lift_model()
	model.name = "Pad"
	m.add_child(model)
	var spot := USE_SPOT.make(Vector3(0, 0.2, 0), func() -> String: return "" if _lifting else "ride the hover lift up",
		lift.bind(i), 1.8, 2.2)
	spot.name = "Spot"
	m.add_child(spot)


func lift(i: int) -> void:
	var to := get_node_or_null("Lift%dTop" % (i + 1)) as Node3D
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if to == null or player == null or _lifting:
		return
	_lifting = true
	Game.hold_controls(&"far_lift", true, player)
	player.velocity = Vector3.ZERO
	var from := player.global_position
	var goal := to.global_position + Vector3(0, 0.95, 0)
	Juice.blip("whoosh", 1.2, -5.0)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := from.lerp(goal, k)
		p.y = lerpf(from.y, goal.y, sin(k * PI / 2.0)) + sin(k * PI) * 1.2
		if is_instance_valid(player):
			player.global_position = p
			player.velocity = Vector3.ZERO, 0.0, 1.0, LIFT_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		_lifting = false
		if is_instance_valid(player):
			Game.hold_controls(&"far_lift", false, player)
		Fx.burst(self, goal, Color(0.5, 0.9, 1.0), 10, 0.05, 2.0, 0.0, 0.5))


func _add_swap_o_tron() -> void:
	var m := get_node_or_null("SwapOTron") as Node3D
	if m == null:
		return
	var model := swap_o_tron_model()
	model.name = "Swap-o-Tron"
	m.add_child(model)
	_swap_o_tron_glow(fuses_fixed() >= FUSES)


func _swap_o_tron_on() -> void:
	_swap_o_tron_glow(true)
	var m := get_node_or_null("SwapOTron") as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 3.0, 0), Color(1.0, 0.5, 0.9), 30, 0.08, 4.0, -1.0, 1.0)
	Juice.shake(0.2)
	Game.message("The Swap-o-Tron hums back to life! Out of its coil pops a glowing Time Core. One home!")


func _swap_o_tron_glow(on: bool) -> void:
	var g := get_node_or_null("SwapOTron/Swap-o-Tron") as Node3D
	if g == null:
		return
	g.set_meta("on", on)
	for n in ["Coil", "Pod Ring 0", "Pod Ring 1"]:
		var mi := g.get_node_or_null(n) as MeshInstance3D
		if mi:
			var mat := mi.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.2 if on else 0.15
			mat.albedo_color = Color(1.0, 0.45, 0.85) if on else Color(0.35, 0.3, 0.4)
	var l := g.get_node_or_null("Glow") as OmniLight3D
	if l:
		l.visible = on


func swap_o_tron_on() -> bool:
	var g := get_node_or_null("SwapOTron/Swap-o-Tron") as Node3D
	return g != null and bool(g.get_meta("on", false))


# The Skyway Run (core 2) -----------------------------------------------------------------------------------------------
func _on_race_finished(track_id: String, place: int) -> void:
	if track_id != RACE or not is_inside_tree():
		return
	if is_core_home(1):
		return
	Game.message("You finished the Skyway Run%s! A Time Core streaks down from the sky road to the Tomorrow Clock." %
		(" in first place" if place == 1 else ""))
	bring_core(1)


func _catch_off_skyway(player: CharacterBody3D) -> void:
	# Fallen off the sky road mid-race? A gust of rocket wind pops you back up onto it, just where you were
	if not Races.racing() or Races.track_id != RACE or player.global_position.y > 6.0:
		return
	var t := Races.track_node(RACE)
	if t == null:
		return
	var d := t.nearest(player.global_position, -1.0, 80.0)
	player.global_position = t.point_at(d) + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	Game.message("Whoops! A puff of rocket wind pops you back up onto the Skyway.")
	Audio.play("boing", -6.0)


# The fading people (core 3) --------------------------------------------------------------------------------------------
func is_pinned(i: int) -> bool:
	return Portals.has_found(world_id, "folk_%d" % (i + 1)) or Portals.is_cleared(world_id)


func pinned() -> int:
	var n := 0
	for i in FOLK.size():
		if is_pinned(i):
			n += 1
	return n


func _add_folk(i: int) -> void:
	var m := get_node_or_null("Folk%d" % (i + 1)) as Node3D
	if m == null:
		return
	var who: Dictionary = FOLK[i]
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = "Model"
	p.set("look", {"body": who.body, "colors": who.colors, "extras": true, "height": 0.9})
	m.add_child(p)
	var ghost := Label3D.new()
	ghost.name = "Fading"
	ghost.text = "~ fading ~"
	ghost.font_size = 40
	ghost.pixel_size = 0.01
	ghost.outline_size = 10
	ghost.modulate = Color(0.75, 0.9, 1.0, 0.8)
	ghost.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost.position.y = 2.3
	ghost.visible = not is_pinned(i)
	m.add_child(ghost)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to %s" % who.name if is_pinned(i) else "show them your watch",
		_use_folk.bind(i), 2.2, 2.4)
	spot.name = "Spot"
	m.add_child(spot)
	var body := SHOT_TARGET.new() as StaticBody3D
	body.name = "Hit"
	body.on_shot = func() -> String: return "hit" if pin(i) else "bounce"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.5
	cs.shape = cap
	cs.position.y = 0.8
	body.add_child(cs)
	m.add_child(body)


func _use_folk(i: int) -> void:
	if not is_pinned(i):
		pin(i)
		return
	var spot := get_node_or_null("Folk%d/Spot" % (i + 1)) as Node3D
	if spot:
		Dialogue.say(spot, str(FOLK[i].name), folk_lines(i), "far_future_folk")


func pin(i: int) -> bool:
	# Your watch ticks, and they snap back into time: solid, bright, and very glad of it
	if is_pinned(i):
		return false
	Portals.note_found(world_id, "folk_%d" % (i + 1))
	var m := get_node_or_null("Folk%d" % (i + 1)) as Node3D
	if m:
		(m.get_node("Model") as Node3D).visible = true
		var ghost := m.get_node_or_null("Fading") as Node3D
		if ghost:
			ghost.visible = false
		Fx.burst(self, m.global_position + Vector3(0, 1.2, 0), CORE_COLOURS[2], 20, 0.06, 3.0, -0.5, 0.8)
		Juice.squash(m.get_node("Model") as Node3D, 0.18, 0.2)
	Juice.blip("tick", 1.0, -4.0)
	var n := pinned()
	if n < FOLK.size():
		Game.message("Tick! Your watch pins %s back into time. \"%s\" (%d of %d)" % [FOLK[i].name, folk_lines(i)[0], n, FOLK.size()])
	else:
		Game.message("Tick! That's all six back in time! The plaza's holo-globe flares up, and a Time Core rises out of it.")
		bring_core(2)
	return true


func folk_lines(i: int) -> Array:
	# The Lumen City folk (first drafts for Hayden): fading, then glad, then cheerful about the mended future
	if Portals.is_cleared(world_id):
		return [["The lights are all back on! I'm going to stay up and look at them till the morning. The real morning!"],
			["My pixels feel all tingly. In a good way. Thank you, time-friend!"],
			["In all my two hundred and twelve years, I've never seen the city so bright. And I've seen a LOT of bright."],
			["Rex and Dash were the cleverest kids on the block, you know. Glad they've got a friend like you."],
			["Beep! Bloop! That's future for hooray."],
			["I'm going to tell my grandkids about you. And their grandkids. Time's long round here."]][i]
	return [["I was going see-through! Like a ghost! Thank you!", "It's all the broken time, you know. It reaches us last."],
		["Phew! I was turning into static. Fzzzt.", "My nan says the past is all tangled up. Somebody should untangle it!"],
		["Ah, much better. At my age you don't want to fade before your nap.", "Rex and Dash's lab is out west. Those two!"],
		["Ooh, I'm solid again! I can hold my hoverball!", "Have you raced the Skyway? Countdown's waiting under the road."],
		["Beep! I mean, thank you! I always say beep when I'm surprised.", "Something glitchy's been hanging round the Tomorrow Clock."],
		["Oh! Was I fading? How embarrassing.", "If the clock gets its cores back, maybe the whole city will stop fading."]][i]


# The Time Cores ---------------------------------------------------------------------------------------------------------
func is_core_home(i: int) -> bool:
	return Portals.has_found(world_id, "core_%d" % (i + 1)) or Portals.is_cleared(world_id)


func cores() -> int:
	var n := 0
	for i in 3:
		if is_core_home(i):
			n += 1
	return n


func bring_core(i: int) -> void:
	if Portals.has_found(world_id, "core_%d" % (i + 1)):
		return
	Portals.note_found(world_id, "core_%d" % (i + 1))
	_show_core(i)
	var s := get_node_or_null("Socket%d" % (i + 1)) as Node3D
	if s:
		Fx.burst(self, s.global_position + Vector3(0, 1.6, 0), CORE_COLOURS[i], 26, 0.08, 4.0, -1.0, 1.0)
	var tw := create_tween()
	tw.tween_method(set_fade, fade, _goal_fade(), 2.0)
	Juice.blip("chime", 0.8, -3.0)
	if cores() == 3:
		Game.message.call_deferred("All three Time Cores are home! The Tomorrow Clock chimes... and something glitchy stirs on its dais.")


func _show_core(i: int) -> void:
	var s := get_node_or_null("Socket%d" % (i + 1)) as Node3D
	if s == null:
		return
	var old := s.get_node_or_null("Core")
	if old:
		old.free()
	var home := is_core_home(i)
	var c := core_model(CORE_COLOURS[i], home)
	c.name = "Core"
	s.add_child(c)


# Rex and Dash ------------------------------------------------------------------------------------------------------------
func _add_friend(n: String, model: String, verb: String, talk: Callable) -> void:
	var m := get_node_or_null(n) as Node3D
	if m == null:
		return
	var packed := load(model) as PackedScene
	if packed:
		var p := packed.instantiate() as Node3D
		p.name = "Model"
		m.add_child(p)
		var anim := p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.has_animation("idle"):
			anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("idle")
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return verb, talk, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)
	var l := Label3D.new()
	l.name = "Name"
	l.text = n
	l.font_size = 30
	l.pixel_size = 0.01
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 2.2 if n == "Dash" else 1.6
	m.add_child(l)


func rex_lines() -> Array:
	# Rex is home, in the husky's body, and the place he's going to be mayor of one day is fading (first drafts)
	if Portals.is_cleared(world_id):
		return ["Look at it, {player}. Lumen City, all lit up. Home.",
			"One day I'm going to be mayor here. A mayor with four paws, maybe. We'll see.",
			"Dash says the Swap-o-Tron's working better than ever now. I'm trying not to get my hopes up. My tail isn't listening."]
	if not Portals.has_found(world_id, "met_rex"):
		Portals.note_found(world_id, "met_rex")
		return ["{player}! You came! Welcome to the Far Future. Lumen City! This is where me and Dash are from.",
			"Well. It's where we're from WHEN. The furthest future there is.",
			"But look at it. The colours are going. The towers keep blinking out. It's FADING.",
			"All the time that broke in the other worlds is catching up with it. The future gets it last, and worst.",
			"The Tomorrow Clock in the middle keeps the city's time, and it's lost its three Time Cores.",
			"Dash is in his lab, out west: the Swap-o-Tron's blown its fuses. There's a race round the Skyway up there. And the Fading Plaza, east... people are fading right out of time.",
			"Bring the cores home and the clock should hold. Go on! I'll guard the way in. With my nose."]
	var left: Array = []
	for i in 3:
		if not is_core_home(i):
			left.append(["fix the Swap-o-Tron's fuses in Dash's lab", "race the Skyway Run (Countdown's under the sky road, east)",
				"pin the fading people in the Fading Plaza back into time"][i])
	if left.size() > 0:
		return ["%d Time Core%s home! The colours are coming back, a bit. I can smell them. Don't ask." % [3 - left.size(), "" if 3 - left.size() == 1 else "s"]
			if left.size() < 3 else "The city's fading, {player}. We have to hurry.",
			"Still to do: %s." % ", and ".join(left)]
	return ["All three cores! The clock's holding... but there's someone on its dais. Someone glitchy.",
		"I know that look. Purple. Cubes. Grumpy. That's one of the Agent of Chaos's lot!",
		"Pop him when his chest clock glows. Jump the rings. And keep off the glowing marks!"]


func _talk_rex() -> void:
	var spot := get_node_or_null("Rex/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Rex", rex_lines().map(func(l: String) -> String: return Settings.fill(l)), "far_future_rex")


func dash_lines() -> Array:
	# Dash in his own lab, where his time experiment went off the same night as Rex's swap (first drafts)
	if Portals.is_cleared(world_id):
		return ["Everything's humming again. The lab, the clock, the whole city. You did that, {player}.",
			"And the Swap-o-Tron... it's working. Properly working. For the first time since that night.",
			"I've been doing sums. If we got Rex in one pod and Rook in the other... No. Not yet. I need to check them again. And again."]
	if not Portals.has_found(world_id, "met_dash"):
		Portals.note_found(world_id, "met_dash")
		return ["Oh! {player}! In MY lab! Sorry about the mess. And the fading. And the sparks.",
			"This is the real one. The first Swap-o-Tron. Rex built it right here, the same night I ran my time experiment.",
			"Both at once. That's what cracked everything.",
			"Now all its Chrono Fuses have blown. I've got new ones, but I'm too busy holding the clock's numbers steady.",
			"One goes by the machine, one up on the gallery and one out on the roof. The hover lifts will take you up. Interact, or pop a bubble at them!"]
	if fuses_fixed() < FUSES:
		return ["%d of %d Chrono Fuses in. The Swap-o-Tron's twitching!" % [fuses_fixed(), FUSES],
			"Remember: one by the machine, one on the gallery and one on the roof. The hover lifts go up."]
	return ["The Swap-o-Tron's on! And the first core's home. I could hug you. I won't. Science doesn't hug.",
		"Rex says there's a race round the Skyway, and the Fading Plaza needs help. Go, go!"]


func _talk_dash() -> void:
	var spot := get_node_or_null("Dash/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Dash", dash_lines().map(func(l: String) -> String: return Settings.fill(l)), "far_future_dash")


func thank_lines() -> Array:
	return ["{player}! You did it! The whole city's lit up! Look at the TOWERS!",
		"Captain Glitch got away, though. Through a rift. I saw where it went... the Void.",
		"The Agent of Chaos is there. Waiting. This was his last trick before the big one.",
		"But he's got us to deal with now. All of us. And the future's not fading any more!",
		"And Dash says the Swap-o-Tron's mended. Properly mended. Which means maybe... me... my own body...",
		"One thing at a time. THANK you, {player}. From the furthest future there is."]


func _thank(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:
		get_tree().create_timer(1.0).timeout.connect(_thank.bind(tries + 1))
		return
	Portals.note_found(world_id, "thanked")
	var spot := get_node_or_null("Rex/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Rex", thank_lines().map(func(l: String) -> String: return Settings.fill(l)), "far_future_thanks")


# Captain Glitch -----------------------------------------------------------------------------------------------------------
func _add_captain() -> void:
	var m := get_node_or_null("Captain") as Node3D
	if m == null:
		return
	var c := CharacterBody3D.new()
	c.set_script(CAPTAIN)
	c.name = "Captain Glitch"
	c.set("world", self)
	c.process_mode = Node.PROCESS_MODE_DISABLED              # a flickering statue until all three cores are home
	add_child(c)
	c.global_position = m.global_position
	_captain = c
	var spot := USE_SPOT.make(Vector3(0, 0, 3.0), func() -> String: return "" if captain_awake else "look at the glitchy statue",
		_look_at_captain, 2.6, 3.0)
	spot.name = "Spot"
	m.add_child(spot)


func _look_at_captain() -> void:
	if captain_awake:
		return
	var left := 3 - cores()
	Game.message("A tall figure made of purple glitch cubes, flickering, with a cracked little clock on his chest. Bring the %d Time Core%s home first." % [left, "" if left == 1 else "s"]
		if left > 0 else "He's twitching...")
	Audio.play("ui_back", -8.0)


func wake_captain() -> void:
	if captain_awake or _captain == null or not is_instance_valid(_captain):
		return
	captain_awake = true
	var spot := get_node_or_null("Captain/Spot")
	if spot:
		spot.queue_free()
	_captain.process_mode = Node.PROCESS_MODE_INHERIT
	_captain.call("wake")


func ground_below(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2.0, 0), at + Vector3(0, -30.0, 0))
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	var skip: Array[RID] = []
	if player:
		skip.append(player.get_rid())
	if _captain and is_instance_valid(_captain):
		skip.append(_captain.get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, 0.0, at.z)


func arena_centre() -> Vector3:
	var c := get_node_or_null("Tomorrow Clock") as Node3D
	return c.global_position if c else Vector3(0, 0, -4)


func mend() -> void:
	# The future stops fading: the colour floods back, every light comes on, and the sky fills with fireworks
	captain_awake = false
	Portals.clear(world_id)
	for i in 3:
		_show_core(i)
	for t in _towers:
		(t as Node3D).visible = true
	var tw := create_tween()
	tw.tween_method(set_fade, fade, 0.0, MEND_TIME).set_trans(Tween.TRANS_SINE)
	_fireworks = 0.0
	Juice.shake(0.2)
	Juice.rumble(0.4, 0.4)
	Juice.blip("chime", 0.7, -2.0)
	get_tree().create_timer(THANKS_AFTER).timeout.connect(_thank)


# Hover traffic and fireworks ----------------------------------------------------------------------------------------------
func _add_traffic() -> void:
	# Little hover pods looping round the towers high above the Skyway (only to look at)
	var g := Node3D.new()
	g.name = "Hover Traffic"
	add_child(g)
	var cols := [Color(0.4, 1.0, 1.0), Color(1.0, 0.5, 0.9), Color(1.0, 0.85, 0.4), Color(0.6, 1.0, 0.45)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in TRAFFIC:
		var pod := pod_model(cols[i % cols.size()])
		g.add_child(pod)
		_traffic.append([pod, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 16)), rng.randf_range(30.0, 62.0),
			rng.randf_range(0.08, 0.16) * (1.0 if i % 2 == 0 else -1.0), rng.randf() * TAU, rng.randf_range(16.0, 32.0)])
	_place_traffic()


func _place_traffic() -> void:
	for tr in _traffic:
		var a: float = float(tr[4]) + _t * float(tr[3])
		var c: Vector3 = tr[1]
		var r: float = tr[2]
		var p := c + Vector3(cos(a) * r, float(tr[5]) + sin(_t * 0.7 + a) * 0.8, sin(a) * r)
		var pod := tr[0] as Node3D
		pod.position = p
		pod.rotation.y = -a + (0.0 if float(tr[3]) > 0.0 else PI)


func _process(delta: float) -> void:
	_t += delta
	_place_traffic()
	var globe := get_node_or_null("Fading Plaza/Holo Globe") as Node3D
	if globe:
		globe.rotation.y += delta * 0.6
	if has_meta("preview"):
		return
	_flicker(delta)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	_fade_folk(player)
	_face_friends(player, delta)
	if Portals.is_cleared(world_id):
		_fireworks -= delta
		if _fireworks <= 0.0 and fade < 0.5:
			_fireworks = randf_range(0.6, 1.6)
			var at := Vector3(randf_range(-40, 40), randf_range(24, 40), randf_range(-50, 20))
			var cols := [Color(1.0, 0.5, 0.9), Color(0.4, 1.0, 1.0), Color(1.0, 0.85, 0.4), Color(0.6, 1.0, 0.45)]
			Fx.burst(self, at, cols[randi() % cols.size()], 30, 0.18, 9.0, 1.0, 1.4)
		return
	if player == null:
		return
	_catch_off_skyway(player)
	var m := get_node_or_null("Captain") as Node3D
	if not captain_awake and m and cores() == 3 and player.global_position.distance_to(m.global_position) < WAKE_NEAR:
		wake_captain()


func _fade_folk(player: Node3D) -> void:
	# The fading folk flicker in and out of sight, and your watch pins any you get right up to
	for i in FOLK.size():
		var m := get_node_or_null("Folk%d" % (i + 1)) as Node3D
		if m == null or is_pinned(i):
			continue
		var model := m.get_node("Model") as Node3D
		model.visible = fmod(_t * (1.3 + i * 0.17) + i * 0.37, 1.0) > 0.35
		if player:
			var to := player.global_position - m.global_position
			if Vector2(to.x, to.z).length() < PIN_NEAR and absf(to.y - 0.9) < 1.6:
				pin(i)


func _face_friends(player: Node3D, delta: float) -> void:
	# Rex and Dash turn to look at you when you come near (and stand aside while they race you on the Skyway)
	var racing := Races.racing() and Races.track_id == RACE
	for n in ["Rex", "Dash"]:
		var m := get_node_or_null(n) as Node3D
		if m == null:
			continue
		m.visible = not racing
		var model := m.get_node_or_null("Model") as Node3D
		if model == null or player == null:
			continue
		var to := player.global_position - m.global_position
		if Vector2(to.x, to.z).length() > 9.0:
			continue
		var want := atan2(to.x, to.z) - m.global_rotation.y
		model.rotation.y = lerp_angle(model.rotation.y, want, minf(1.0, delta * 4.0))


# Looks ------------------------------------------------------------------------------------------------------------------
static func _mat(colour: Color, emit := 0.0, rough := 0.5, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, alpha)
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(colour.r, colour.g, colour.b)
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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


static func _cyl(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func fuse_model(fixed: bool) -> Node3D:
	# A Chrono Fuse in its little stand: a glass tube with a glowing green core when it's good, black and cracked
	# with a puff of sparks when it's blown
	var g := Node3D.new()
	var metal := _mat(Color(0.55, 0.58, 0.72), 0.0, 0.3)
	_put(g, _cyl(0.3, 0.38, 0.6, 8), metal, Vector3(0, 0.3, 0))
	var tube := _mat(Color(0.55, 1.0, 0.4) if fixed else Color(0.15, 0.12, 0.18), 2.0 if fixed else 0.0, 0.2, 0.85)
	_put(g, _cyl(0.16, 0.16, 0.7, 10), tube, Vector3(0, 0.95, 0)).name = "Tube"
	_put(g, _cyl(0.2, 0.2, 0.1, 10), metal, Vector3(0, 1.32, 0))
	if fixed:
		var l := OmniLight3D.new()
		l.light_color = Color(0.55, 1.0, 0.4)
		l.light_energy = 0.8
		l.omni_range = 3.0
		l.position.y = 1.0
		g.add_child(l)
	else:
		var zap := Label3D.new()
		zap.name = "Blown"
		zap.text = "blown!"
		zap.font_size = 34
		zap.pixel_size = 0.01
		zap.outline_size = 8
		zap.modulate = Color(1.0, 0.75, 0.4)
		zap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zap.position.y = 1.75
		g.add_child(zap)
	return g


static func lift_model() -> Node3D:
	# A hover lift: a round glowing pad with a soft beam of light standing up out of it
	var g := Node3D.new()
	_put(g, _cyl(0.9, 1.0, 0.12, 20), _mat(Color(0.5, 0.9, 1.0), 1.4, 0.3), Vector3(0, 0.06, 0))
	var beam := _mat(Color(0.5, 0.9, 1.0), 0.8, 0.2, 0.18)
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_put(g, _cyl(0.75, 0.85, 3.0, 20), beam, Vector3(0, 1.6, 0)).name = "Beam"
	var l := Label3D.new()
	l.text = "Hover lift"
	l.font_size = 30
	l.pixel_size = 0.01
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 3.4
	g.add_child(l)
	return g


static func swap_o_tron_model() -> Node3D:
	# The first Swap-o-Tron, the one Rex built: two glass pods with glowing rings, a coil arch over them
	var g := Node3D.new()
	var trim := _mat(Color(0.75, 0.75, 0.9), 0.0, 0.3)
	for k in 2:
		var x := -1.5 + k * 3.0
		_put(g, _cyl(0.95, 1.05, 0.3, 16), trim, Vector3(x, 0.15, 0))
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 1.0
		cy.height = 0.3
		cs.shape = cy
		body.add_child(cs)
		body.position = Vector3(x, 0.15, 0)
		g.add_child(body)
		var glass := _mat(Color(0.8, 0.75, 1.0), 0.0, 0.1, 0.22)
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_put(g, _cyl(0.85, 0.85, 2.5, 16), glass, Vector3(x, 1.55, 0))
		_put(g, _cyl(0.95, 0.95, 0.3, 16), trim, Vector3(x, 2.95, 0))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.82
		ring.outer_radius = 0.92
		_put(g, ring, _mat(Color(1.0, 0.45, 0.85), 2.2), Vector3(x, 1.6, 0)).name = "Pod Ring %d" % k
	var arch := TorusMesh.new()
	arch.inner_radius = 2.0
	arch.outer_radius = 2.2
	_put(g, arch, _mat(Color(1.0, 0.45, 0.85), 2.2), Vector3(0, 3.0, 0), Vector3.ONE, Vector3(PI / 2.0, 0, 0)).name = "Coil"
	var l := Label3D.new()
	l.text = "SWAP-O-TRON (the first one)"
	l.font_size = 36
	l.pixel_size = 0.01
	l.outline_size = 8
	l.modulate = Color(1.0, 0.8, 1.0)
	l.position = Vector3(0, 3.6, 0.8)
	g.add_child(l)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.55, 0.9)
	glow.light_energy = 1.4
	glow.omni_range = 7.0
	glow.position.y = 2.5
	g.add_child(glow)
	return g


static func core_model(colour: Color, home: bool) -> Node3D:
	# A Time Core: a glowing crystal ball in a gold cage, spinning over its socket (an empty cage when it's not home)
	var g := Node3D.new()
	var gold := _mat(Color(1.0, 0.82, 0.4), 0.3, 0.3)
	for k in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.5
		ring.outer_radius = 0.56
		_put(g, ring, gold, Vector3(0, 1.6, 0), Vector3.ONE, Vector3(PI / 2.0, k * PI / 3.0, 0))
	if home:
		_put(g, _ball(0.4, 16), _mat(colour, 3.0, 0.2), Vector3(0, 1.6, 0)).name = "Glow Ball"
		var l := OmniLight3D.new()
		l.light_color = colour
		l.light_energy = 1.6
		l.omni_range = 5.0
		l.position.y = 1.6
		g.add_child(l)
	return g


static func pod_model(colour: Color) -> Node3D:
	# A little hover car: a rounded pod with a glass bubble top and a glowing strip underneath
	var g := Node3D.new()
	_put(g, _ball(0.9, 12), _mat(Color(0.85, 0.88, 1.0), 0.0, 0.3), Vector3.ZERO, Vector3(1.0, 0.45, 1.8))
	_put(g, _ball(0.55, 10), _mat(colour, 0.6, 0.1, 0.6), Vector3(0, 0.35, -0.1), Vector3(1.0, 0.8, 1.3))
	_put(g, _box(Vector3(1.2, 0.08, 2.6)), _mat(colour, 2.5), Vector3(0, -0.4, 0))
	return g
