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
# his master is waiting.
# Then Rex's shot at his own body back (slice two, try_swap()): once it's mended, Rex fetches Rook to Dash's lab, and
# pulling the Swap-o-Tron's lever swaps them back... for a few seconds. Then they snap back again: the swap is knotted
# into the crack in the Shift, and the other end of the knot is in the Agent of Chaos's cracked clock. That's what
# opens his final fight in the Void (flag SWAP_FLAG, chaos_fight.gd unlocked(); quest "Stop His Clock").
# Then the story's ending (slice three; the quest "Loose Ends", quests/loose_ends.json, scripts/after_the_ending.gd),
# rewritten Nov 12, 2026 for Hayden's lore bible v2: Dash doesn't sacrifice himself, fixing the Shift sends everyone
# home, Rex will be mayor of Lumen City, and Lumen City is Stars Hollow's far future, on Earth. With the Agent of
# Chaos's clock stopped, the lever swaps Rex and Rook back for good (swap_for_good(); flag REX_HOME), and Rex says sorry
# to Rook (he swapped them on purpose, testing the Swap-o-Tron). Then Dash reads the machine: the Shift is mending
# itself, and when the Tomorrow Clock strikes the last crack closes and everyone goes back to their own world and time
# (home_lines(); flag TWIST_FLAG). He waits on the clock's dais, and walking up to him plays the homecoming
# (scripts/dash_goodbye.gd): everyone says see you later, he gives you his cap, the clock strikes and the friends go
# home. Dash, Rex and Rook stay: Lumen City IS home. After that his letter waits on his workbench (letter_lines()),
# Dash takes the lost watches and the Pieces of That Night here (the three of them aren't in the Void any more), and a
# "Rex for Mayor" banner goes up by the clock. The Old Oak stands in the city all along (_add_old_oak()): the same
# tree as Stars Hollow's, a long time later, and touching it hums.
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
const ROOK_MODEL := "res://models/characters/rook.glb"
const START_FLAG := "swap_try_start"     # the quest "Stop His Clock" (quests/stop_his_clock.json) starts with this
const SWAP_FLAG := "swap_tried"           # Rex's shot at his body's been had: the Agent of Chaos's fight opens
const SWAP_FLASH := 2.4                   # seconds into the try: the flash, and they're swapped back
const SWAP_SNAP := 5.6                    # ...the knot pulls tight and they snap back again
const SWAP_DONE := 8.0                    # ...Dash reads the machine
const REX_IN_LAB := Vector3(0.8, 0, 4.2)  # where Rex and Rook wait in the lab once it's mended (from the lab's middle)
const ROOK_IN_LAB := Vector3(2.4, 0, 4.8)
# The lever stands beside Rook's pod, not in front of the pods, so it never hides who's inside
const LEVER_AT := Vector3(2.9, 0, 1.2)
const LAB_MIDDLE := Vector3(-30, 0, -4)   # (tools/build_far_future.gd LAB)
const AFTER := preload("res://scripts/after_the_ending.gd")
const GOODBYE := preload("res://scripts/dash_goodbye.gd")
const CLOCK_AT := Vector3(0, 0, -4)       # the Tomorrow Clock (tools/build_far_future.gd CLOCK)
const DASH_AT_CLOCK := Vector3(0, 0, 5.0) # where Dash waits on the clock's dais, from the clock (facing the way in)
const REX_AT_CLOCK := Vector3(-3.2, 0, 7.5)
const ROOK_AT_CLOCK := Vector3(-4.8, 0, 8.4)
const GOODBYE_NEAR := 8.0                 # walking this close to Dash at the clock plays the goodbye
const LETTER_AT := Vector3(4.2, 0, 1.0)   # Dash's letter, where he stood in his lab (from the lab's middle)
const FOR_GOOD_HOLD := 5.6                # seconds into the swap for good: it holds, in a ring of gold
# The Old Oak, still standing in Lumen City: Stars Hollow's oak, a long time later (clear of the lanes, the towers and
# the way in; checked in tools/test_far_future.gd)
const OAK_AT := Vector3(14, 0, 30)
const BANNER_AT := Vector3(9.0, 0, 13.0)  # "Rex for Mayor", once everyone's home, from the clock

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
var swapping := false                     # the Swap-o-Tron's mid-try
var _swapped := false                     # Rex and Rook are in each other's... in their OWN bodies, for a moment
var for_good := false                     # the lever's been pulled for the last time (swap_for_good())
var goodbye: CanvasLayer                  # Dash's goodbye at the Tomorrow Clock (scripts/dash_goodbye.gd)
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
	_add_lever()
	_add_friend("Rex", "res://models/characters/wolf.glb", "talk to Rex", _talk_rex)
	_add_friend("Dash", "res://models/characters/bike_boy.glb", "talk to Dash", _talk_dash)
	for i in FOLK.size():
		_add_folk(i)
	for i in 3:
		_show_core(i)
	_add_traffic()
	_add_old_oak()
	if not Portals.is_cleared(world_id):
		_add_captain()
	else:
		_to_the_lab()
		Dialogue.set_flag(START_FLAG)
		_the_ending()
	set_fade(0.0 if Portals.is_cleared(world_id) else _goal_fade())
	Races.finished.connect(_on_race_finished)
	if not Portals.is_cleared(world_id) and cores() == 0 and not Portals.has_found(world_id, "met_rex"):
		Game.message.call_deferred("Lumen City, in the far future... and it's fading!")


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
		Game.message("ZAP! Fuse in! (%d of %d)" % [n, FUSES])
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
	Game.message("The Swap-o-Tron hums! A Time Core pops out!")


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
	Game.message("Skyway Run done%s! A Time Core flies home!" %
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
	Game.message("Whoops! Back up you go!")
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
		Game.message("Tick! %s is back! \"%s\" (%d of %d)" % [FOLK[i].name, folk_lines(i)[0], n, FOLK.size()])
	else:
		Game.message("All six are back! A Time Core rises up!")
		bring_core(2)
	return true


func folk_lines(i: int) -> Array:
	# The Lumen City folk (first drafts for Hayden): fading, then glad, then cheerful about the mended future
	if Portals.is_cleared(world_id):
		return [["The lights are back on!"],
			["My pixels tingle! Thank you!"],
			["212 years, and never this bright!"],
			["Rex and Dash are lucky to have you."],
			["Beep! Bloop! That's future for hooray."],
			["I'll tell my grandkids about you!"]][i]
	return [["I was see-through! Thank you!"],
		["Phew! I was turning to static!"],
		["Much better! Now, my nap."],
		["I'm solid again!"],
		["Beep! I mean, thank you!"],
		["Was I fading? Oops!"]][i]


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
		Game.message.call_deferred("All three Time Cores are home! Something stirs...")


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
		if AFTER.everyone_home():
			if not Dialogue.flags.has(AFTER.LETTER_FLAG):
				return ["Dash left you a letter on his workbench!"]
			return [["Mayor of Lumen City, one day! Rook ate his badge."],
				["Wave at the old oak for me back home!"]][randi() % 2]
		if Dialogue.flags.has(AFTER.TWIST_FLAG):
			return ["Everybody's going home, {player}. You too.",
				"And us? We're already home!",
				"Come to the Tomorrow Clock!"]
		if AFTER.rex_home():
			return home_lines()
		if Dialogue.flags.has("beat_agent_of_chaos"):
			if not for_good and get_node_or_null("Rook") != null:
				return ["You stopped his clock! I felt it!",
					"One more go? Pull the big lever!"]
			return ["You stopped his clock! I felt it!",
				"Dash keeps staring at the sky."]
		if Dialogue.flags.has(SWAP_FLAG):
			return ["For five seconds I had HANDS!",
				"Then the Agent of Chaos yanked us back.",
				"Let's stop his clock! The far field, in the Void."]
		return ["Lumen City, all lit up! Home!",
			"Shall we try the Swap-o-Tron?",
			"Pull the big lever when you're ready!"]
	if not Portals.has_found(world_id, "met_rex"):
		Portals.note_found(world_id, "met_rex")
		return ["Welcome to the Far Future! Lumen City, our home.",
			"But look, it's FADING!",
			"The big clock lost three Time Cores.",
			"Find them! I'll guard the door. With my nose."]
	var left: Array = []
	for i in 3:
		if not is_core_home(i):
			left.append(["Dash's lab", "the Skyway Run",
				"the Fading Plaza"][i])
	if left.size() > 0:
		return ["%d Time Core%s home!" % [3 - left.size(), "" if 3 - left.size() == 1 else "s"]
			if left.size() < 3 else "The city's fading! Hurry!",
			"Still to do: %s." % ", and ".join(left)]
	return ["All three cores! But someone's on the clock...",
		"Pop him when his clock glows!"]


func _talk_rex() -> void:
	var spot := get_node_or_null("Rex/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Rex", talk_steps(rex_lines()), "far_future_rex")


func dash_lines() -> Array:
	# Dash in his own lab, where his time experiment went off the same night as Rex's swap (first drafts)
	if Portals.is_cleared(world_id):
		if AFTER.everyone_home():
			if not Dialogue.flags.has(AFTER.LETTER_FLAG):
				return ["I left you a letter on my workbench!"]
			return [["Every world's ticking the right way!"],
				["You're right under my feet. Just earlier!"]][randi() % 2]
		if Dialogue.flags.has(AFTER.TWIST_FLAG):
			return ["Everyone's coming! Let's say see you later PROPERLY.",
				"Stand with me. When it strikes, everyone goes home."]
		if AFTER.rex_home():
			return home_lines()
		if Dialogue.flags.has("beat_agent_of_chaos"):
			return ["His clock's stopped! The knot's come loose!",
				"Pull the lever, {player}. For good!"]
		if Dialogue.flags.has(SWAP_FLAG):
			return swap_lines()
		return ["The whole city's humming! You did that!",
			"Pull the Swap-o-Tron's lever when you're ready!"]
	if not Portals.has_found(world_id, "met_dash"):
		Portals.note_found(world_id, "met_dash")
		return ["{player}! In MY lab! Sorry about the sparks.",
			"The first Swap-o-Tron. It blew three Chrono Fuses!",
			"New ones are up in the gallery. Ride the lifts!"]
	if fuses_fixed() < FUSES:
		return ["%d of %d fuses in!" % [fuses_fixed(), FUSES]]
	return ["It's on! The first core's home!"]


func _talk_dash() -> void:
	var spot := get_node_or_null("Dash/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Dash", talk_steps(dash_lines() + hand_ins()), "far_future_dash")


func hand_ins() -> Array:
	# Once everyone's home, Dash isn't in the Void any more, so the lost watches (scripts/watches.gd) and the Pieces of
	# That Night (scripts/sunken_secrets.gd) come to him here
	if not AFTER.everyone_home():
		return []
	var out: Array = []
	var w := get_node_or_null("/root/Watches")
	if w and w.has_method("watches_hand_in"):
		var said: Array = w.call("watches_hand_in")
		if not said.is_empty():
			out.append("{player}: I found more lost watches, Dash!")
			out.append_array(said)
	var sunk := get_node_or_null("/root/Watches/Sunken")
	if sunk and sunk.has_method("hand_in"):
		var more: Array = sunk.call("hand_in")
		if not more.is_empty():
			out.append("{player}: And another piece of that night.")
			out.append_array(more)
	return out


func thank_lines() -> Array:
	return ["You did it! Look at the TOWERS!",
		"Captain Glitch got away. Back to his master...",
		"And the Swap-o-Tron's mended! Maybe... my own body...",
		"Come to Dash's lab! Let's TRY it!"]


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
	# Off he goes to fetch Rook (the lab's well out of sight from the way in)
	_to_the_lab()
	Dialogue.set_flag(START_FLAG)


# Rex's shot at his own body back (slice two) ---------------------------------------------------------------------------
func _to_the_lab() -> void:
	# Rex waits in Dash's lab now, with Rook, who followed the fireworks through the portal
	var rex := get_node_or_null("Rex") as Node3D
	if rex:
		rex.global_position = LAB_MIDDLE + REX_IN_LAB
	if get_node_or_null("Rook") == null:
		var m := Node3D.new()
		m.name = "Rook"
		add_child(m)
		m.global_position = LAB_MIDDLE + ROOK_IN_LAB
		_add_friend("Rook", ROOK_MODEL, "talk to Rook", _talk_rook)


func rook_lines() -> Array:
	# Rook is the dog, in Rex's human body. He only ever says woof
	if AFTER.everyone_home():
		return ["Woof! WOOF!"]
	if AFTER.rex_home():
		return ["WOOF! Woof woof woof!"]
	if Dialogue.flags.has(SWAP_FLAG):
		return ["Woof!"]
	return ["Woof! Woof woof!"]


func _talk_rook() -> void:
	var spot := get_node_or_null("Rook/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Rook", rook_lines(), "far_future_rook")


func swap_lines() -> Array:
	# Dash reads the machine after the try (first drafts)
	return ["It WORKED! For five seconds! Then... something pulled them back.",
		"A giant's clock. The Agent of Chaos!",
		"Let's stop his clock! In the far field, in the Void."]


func _add_lever() -> void:
	# The big lever on the Swap-o-Tron: only once the city's mended, and only once
	var m := get_node_or_null("SwapOTron") as Node3D
	if m == null:
		return
	var lever := Node3D.new()
	lever.name = "Lever"
	var post := MeshInstance3D.new()
	post.mesh = _box(Vector3(0.5, 1.0, 0.5))
	post.material_override = _mat(Color(0.3, 0.3, 0.42), 0.0, 0.4)
	post.position = Vector3(0, 0.5, 0)
	lever.add_child(post)
	var arm := MeshInstance3D.new()
	arm.name = "Arm"
	arm.mesh = _box(Vector3(0.1, 0.9, 0.1))
	arm.material_override = _mat(Color(0.8, 0.8, 0.9), 0.0, 0.3)
	arm.position = Vector3(0, 1.3, 0)
	arm.rotation.x = -0.5
	lever.add_child(arm)
	var knob := MeshInstance3D.new()
	knob.mesh = _ball(0.16)
	knob.material_override = _mat(Color(1.0, 0.25, 0.4), 1.2)
	knob.position = Vector3(0, 0.5, 0)
	arm.add_child(knob)
	lever.position = LEVER_AT
	m.add_child(lever)
	var spot := USE_SPOT.make(LEVER_AT, func() -> String:
		return "pull the Swap-o-Tron's lever" if can_try_swap() or can_swap_for_good() else "",
		func() -> void:
			if can_swap_for_good():
				swap_for_good()
			else:
				try_swap(), 2.0, 2.2)
	spot.name = "Spot"
	m.add_child(spot)


func can_try_swap() -> bool:
	return Portals.is_cleared(world_id) and not Dialogue.flags.has(SWAP_FLAG) and not swapping \
		and get_node_or_null("Rook") != null


func pod_at(k: int) -> Vector3:
	var m := get_node("SwapOTron") as Node3D
	return m.global_transform * Vector3(-1.5 + k * 3.0, 0.3, 0)


func try_swap() -> bool:
	# Rex steps into one pod and Rook into the other, the coil charges, ZAP... and for a moment Rex is himself again
	if not can_try_swap():
		return false
	swapping = true
	var player := get_tree().get_first_node_in_group("player")
	Game.hold_controls(&"swap_try", true, player)
	var rex := get_node("Rex") as Node3D
	var rook := get_node("Rook") as Node3D
	rex.global_position = pod_at(0)
	rook.global_position = pod_at(1)
	var arm := get_node_or_null("SwapOTron/Lever/Arm") as Node3D
	if arm:
		create_tween().tween_property(arm, "rotation:x", 0.5, 0.25)
	var coil := get_node_or_null("SwapOTron/Swap-o-Tron/Coil") as MeshInstance3D
	if coil:
		var mat := coil.material_override as StandardMaterial3D
		create_tween().tween_property(mat, "emission_energy_multiplier", 7.0, SWAP_FLASH)
	Juice.rumble(0.3, SWAP_FLASH)
	Juice.blip("whoosh", 0.6, -4.0)
	_shout(rex, "Here goes... everything!")
	get_tree().create_timer(SWAP_FLASH).timeout.connect(_swap_flash)
	get_tree().create_timer(SWAP_SNAP).timeout.connect(_swap_snap)
	get_tree().create_timer(SWAP_DONE).timeout.connect(_swap_done)
	return true


func _swap_models() -> void:
	# Each one's own mind back in their own body: the two models change places
	var rex := get_node("Rex") as Node3D
	var rook := get_node("Rook") as Node3D
	var a := rex.get_node("Model") as Node3D
	var b := rook.get_node("Model") as Node3D
	rex.remove_child(a)
	rook.remove_child(b)
	b.name = "Model"
	a.name = "Model"
	rex.add_child(b)
	rook.add_child(a)
	_swapped = not _swapped
	# In his own body Rex stands up like a boy; back in it, Rook goes on all fours again
	AFTER.upright(rex.get_node("Model"), _swapped)
	AFTER.upright(rook.get_node("Model"), false)


func _swap_flash() -> void:
	if not is_inside_tree():
		return
	for k in 2:
		Fx.burst(self, pod_at(k) + Vector3(0, 1.4, 0), Color(1.0, 0.95, 1.0), 40, 0.1, 5.0, 0.0, 1.0)
	Juice.shake(0.35)
	Juice.blip("sparkle", 1.0, -2.0)
	_swap_models()
	_shout(get_node("Rex"), "HANDS! I've got HANDS, {player}!")
	_shout(get_node("Rook"), "WOOF?!", 2.0)


func _swap_snap() -> void:
	# The knot pulls tight: the Agent of Chaos's cracked clock flickers over the machine, running backwards
	if not is_inside_tree():
		return
	var clock := knot_clock_model()
	clock.name = "Knot Clock"
	add_child(clock)
	clock.global_position = (get_node("SwapOTron") as Node3D).global_position + Vector3(0, 4.6, 0)
	for k in 2:
		Fx.burst(self, pod_at(k) + Vector3(0, 1.4, 0), Color(0.6, 0.2, 0.9), 30, 0.14, 4.0, 0.0, 1.0)
	Juice.blip("rewind", 0.8, -2.0)
	Juice.shake(0.25)
	if _swapped:
		_swap_models()
	_shout(get_node("Rex"), "No, no, no... it's pulling us BACK!")
	_shout(get_node("Rook"), "Woof.", 2.0)


func _swap_done() -> void:
	if not is_inside_tree():
		return
	var clock := get_node_or_null("Knot Clock")
	if clock:
		clock.queue_free()
	var coil := get_node_or_null("SwapOTron/Swap-o-Tron/Coil") as MeshInstance3D
	if coil:
		(coil.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2
	var arm := get_node_or_null("SwapOTron/Lever/Arm") as Node3D
	if arm:
		arm.rotation.x = -0.5
	# Out of the pods again
	(get_node("Rex") as Node3D).global_position = LAB_MIDDLE + REX_IN_LAB
	(get_node("Rook") as Node3D).global_position = LAB_MIDDLE + ROOK_IN_LAB
	Dialogue.set_flag(SWAP_FLAG)
	swapping = false
	Game.hold_controls(&"swap_try", false, get_tree().get_first_node_in_group("player"))
	var spot := get_node_or_null("Dash/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Dash", swap_lines().map(func(l: String) -> String: return Settings.fill(l)), "far_future_swap")


func _shout(who: Node3D, text: String, height := 2.7) -> void:
	# Rook shouts lower than Rex, so two shouts side by side never sit on top of each other
	if who == null:
		return
	var old := who.get_node_or_null("Shout")
	if old:
		old.free()
	var l := Label3D.new()
	l.name = "Shout"
	l.text = Settings.fill(text)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Color(1.0, 0.95, 1.0)
	l.position.y = height
	who.add_child(l)
	# A tween on the label itself goes when the label does, so a shout cut short by the next one leaves nothing behind
	l.create_tween().tween_callback(l.queue_free).set_delay(2.8)


# The ending (slice three) ----------------------------------------------------------------------------------------------
func _the_ending() -> void:
	# Where everyone is, as the ending stands: Rex and Rook in their own bodies once they've swapped for good, all three
	# at the clock once Dash has told them, and still there once everyone's home (his letter on the bench, Rex's banner up)
	AFTER.start_if_due()
	if AFTER.rex_home():
		_swap_models()
		_swapped = false
		_name_heights()
	if AFTER.everyone_home():
		_to_the_clock(false)
		_add_letter()
		_add_banner()
	elif Dialogue.flags.has(AFTER.TWIST_FLAG):
		_to_the_clock(false)
	goodbye = GOODBYE.new()
	goodbye.name = "Goodbye"
	goodbye.set("world", self)
	add_child(goodbye)


func _name_heights() -> void:
	# Rex's name sits over a boy's head now, and Rook's over a husky's
	var rl := get_node_or_null("Rex/Name") as Node3D
	var kl := get_node_or_null("Rook/Name") as Node3D
	if rl:
		rl.position.y = 2.0 if AFTER.rex_home() else 1.6
	if kl:
		kl.position.y = 1.6


func can_swap_for_good() -> bool:
	return Portals.is_cleared(world_id) and Dialogue.flags.has("beat_agent_of_chaos") and not AFTER.rex_home() \
		and not swapping and not for_good and get_node_or_null("Rook") != null


func swap_for_good() -> bool:
	# The lever, the last time: the same pods, the same ZAP, and this time nothing pulls them back
	if not can_swap_for_good():
		return false
	swapping = true
	for_good = true
	var player := get_tree().get_first_node_in_group("player")
	Game.hold_controls(&"swap_try", true, player)
	(get_node("Rex") as Node3D).global_position = pod_at(0)
	(get_node("Rook") as Node3D).global_position = pod_at(1)
	var arm := get_node_or_null("SwapOTron/Lever/Arm") as Node3D
	if arm:
		create_tween().tween_property(arm, "rotation:x", 0.5, 0.25)
	var coil := get_node_or_null("SwapOTron/Swap-o-Tron/Coil") as MeshInstance3D
	if coil:
		var mat := coil.material_override as StandardMaterial3D
		create_tween().tween_property(mat, "emission_energy_multiplier", 7.0, SWAP_FLASH)
	Juice.rumble(0.3, SWAP_FLASH)
	Juice.blip("whoosh", 0.6, -4.0)
	_shout(get_node("Rex"), "One more time... for keeps!")
	get_tree().create_timer(SWAP_FLASH).timeout.connect(_swap_flash)
	get_tree().create_timer(FOR_GOOD_HOLD).timeout.connect(_for_good_hold)
	get_tree().create_timer(SWAP_DONE).timeout.connect(_for_good_done)
	return true


func _for_good_hold() -> void:
	# Where the knot pulled them back last time: a ring of gold instead, and it holds
	if not is_inside_tree():
		return
	var at := (get_node("SwapOTron") as Node3D).global_position + Vector3(0, 1.4, 0)
	for k in 2:
		Fx.burst(self, pod_at(k) + Vector3(0, 1.4, 0), Color(1.0, 0.85, 0.4), 36, 0.12, 4.0, 0.0, 1.2)
	Fx.burst(self, at + Vector3(0, 2.0, 0), Color(1.0, 0.9, 0.55), 50, 0.1, 7.0, 0.5, 1.4)
	Juice.blip("chime", 1.0, -2.0)
	_shout(get_node("Rex"), "It's HOLDING! {player}, it's HOLDING!")
	_shout(get_node("Rook"), "AWOOOO!", 2.0)


func _for_good_done() -> void:
	if not is_inside_tree():
		return
	var coil := get_node_or_null("SwapOTron/Swap-o-Tron/Coil") as MeshInstance3D
	if coil:
		(coil.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2
	var arm := get_node_or_null("SwapOTron/Lever/Arm") as Node3D
	if arm:
		arm.rotation.x = -0.5
	(get_node("Rex") as Node3D).global_position = LAB_MIDDLE + REX_IN_LAB
	(get_node("Rook") as Node3D).global_position = LAB_MIDDLE + ROOK_IN_LAB
	if not _swapped:
		_swap_models()                           # (in case the flash was missed: they're in their own bodies now)
	_swapped = false
	_name_heights()
	Dialogue.set_flag(AFTER.REX_HOME)
	swapping = false
	Game.hold_controls(&"swap_try", false, get_tree().get_first_node_in_group("player"))
	var spot := get_node_or_null("Dash/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Dash", talk_steps(home_lines()), "far_future_twist")
		Dialogue.finished.connect(_after_twist, CONNECT_ONE_SHOT)
	else:
		_after_twist("far_future_twist")


func home_lines() -> Array:
	# Dash reads the machine one last time, and tells everyone what happens next (first drafts, Nov 12, 2026). Nothing
	# before this says it: the Pieces of That Night only have him "think he knows how it could be fixed"
	return ["Rex. Look at you. Your own face!",
		"Rex: HANDS! For KEEPS!",
		"Rex: Rook? I'm sorry I swapped us on purpose, boy.",
		"Rook: Woof!",
		"The cracks are closing, in every world!",
		"When the last one shuts, everyone goes home. You to Stars Hollow.",
		"Rex: And us?",
		"We're already home, Rex.",
		"Meet us at the Tomorrow Clock, {player}!"]


static func talk_steps(lines: Array) -> Array:
	# Lines for Dialogue.say(): "Rex: ..." and the like become that friend's line (the talk box's name changes), and
	# Dialogue fills in {player} and the rest itself (so "{player}: ..." stays the hero's own line)
	var out: Array = []
	for l in lines:
		var line := str(l)
		var said := false
		for who in ["Rex", "Dash", "Rook", "Bramble", "Pip", "Melody", "Flurry", "Otto", "Heather", "Tally"]:
			if line.begins_with(who + ": "):
				out.append({"speaker": who, "text": line.substr(who.length() + 2)})
				said = true
				break
		if not said:
			out.append(line)
	return out


func _after_twist(_id := "") -> void:
	if not is_inside_tree():
		return
	Dialogue.set_flag(AFTER.TWIST_FLAG)
	_to_the_clock(true)


func _to_the_clock(sparkle: bool) -> void:
	# Dash waits on the clock's dais, facing the way in; Rex and Rook stand with him
	for pair in [["Dash", DASH_AT_CLOCK], ["Rex", REX_AT_CLOCK], ["Rook", ROOK_AT_CLOCK]]:
		var n := get_node_or_null(str(pair[0])) as Node3D
		if n == null:
			continue
		if sparkle:
			Fx.burst(self, n.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.5), 14, 0.1, 2.5, -1.0, 0.8)
		var at: Vector3 = CLOCK_AT + pair[1]
		n.global_position = ground_below(at + Vector3(0, 1.0, 0))
		n.rotation.y = 0.0
		var model := n.get_node_or_null("Model") as Node3D
		if model:
			model.rotation.y = 0.0


func dash_at_clock() -> bool:
	var dash := get_node_or_null("Dash") as Node3D
	return dash != null and dash.global_position.distance_to(CLOCK_AT + DASH_AT_CLOCK) < 1.5


func _check_goodbye(player: Node3D) -> void:
	# Walking up to Dash at the clock plays the goodbye
	if player == null or goodbye == null or goodbye.call("playing") or AFTER.everyone_home() or Dialogue.is_active():
		return
	if not Dialogue.flags.has(AFTER.TWIST_FLAG) or not dash_at_clock():
		return
	var dash := get_node("Dash") as Node3D
	var to := player.global_position - dash.global_position
	if Vector2(to.x, to.z).length() < GOODBYE_NEAR and absf(to.y) < 3.0:
		goodbye.call("play")


func said_goodbye() -> void:
	# The homecoming's over (scripts/dash_goodbye.gd): the friends have gone home, Dash, Rex and Rook are home already,
	# his letter's on his bench, and Rex has put his banner up
	Dialogue.set_flag(AFTER.DASH_GOODBYE)
	_to_the_clock(false)
	_add_letter()
	_add_banner()
	Game.save_game()


# His letter ----------------------------------------------------------------------------------------------------------
func _add_letter() -> void:
	if get_node_or_null("Letter") != null:
		return
	var m := Node3D.new()
	m.name = "Letter"
	add_child(m)
	m.global_position = ground_below(LAB_MIDDLE + LETTER_AT + Vector3(0, 1.0, 0))
	var stand := MeshInstance3D.new()
	stand.mesh = _box(Vector3(0.5, 0.9, 0.5))
	stand.material_override = _mat(Color(0.3, 0.3, 0.42), 0.0, 0.4)
	stand.position = Vector3(0, 0.45, 0)
	m.add_child(stand)
	var env := Node3D.new()
	env.name = "Envelope"
	env.position = Vector3(0, 1.25, 0)
	m.add_child(env)
	var paper := MeshInstance3D.new()
	paper.mesh = _box(Vector3(0.5, 0.34, 0.03))
	paper.material_override = _mat(Color(1.0, 0.96, 0.85), 0.25)
	env.add_child(paper)
	var seal := MeshInstance3D.new()
	seal.mesh = _ball(0.06)
	seal.material_override = _mat(Color(0.55, 1.0, 0.4), 1.2)
	seal.position = Vector3(0, 0, 0.03)
	seal.scale = Vector3(1, 1, 0.4)
	env.add_child(seal)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.92, 0.7)
	glow.light_energy = 1.2
	glow.omni_range = 3.0
	env.add_child(glow)
	var l := Label3D.new()
	l.name = "Name"
	l.text = "For {player}"
	l.text = Settings.fill(l.text)
	l.font_size = 26
	l.pixel_size = 0.01
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 1.75
	m.add_child(l)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "read Dash's letter", read_letter, 2.2, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func _spin_letter(delta: float) -> void:
	var env := get_node_or_null("Letter/Envelope") as Node3D
	if env:
		env.rotation.y += delta * 0.8
		env.position.y = 1.25 + sin(_t * 1.6) * 0.06


func letter_lines() -> Array:
	# What Dash wrote for you (first drafts, Nov 12, 2026). The hope: he's not far away, just later
	return ["\"Dear {player}. Everybody's home. You did that.\"",
		"\"Lumen City is where Stars Hollow is. Same oak!\"",
		"\"I'm not far away. I'm just LATER.\"",
		"\"Look after Rex for me. And keep the cap!\"",
		"\"See you later. Love, Dash.\"",
		"\"P.S. Rook says woof.\""]


func read_letter() -> void:
	var spot := get_node_or_null("Letter/Spot") as Node3D
	if spot == null:
		return
	Dialogue.say(spot, "Dash's letter", letter_lines(), "dash_letter")
	Dialogue.set_flag(AFTER.LETTER_FLAG)


# Rex's banner, and the Old Oak --------------------------------------------------------------------------------------
func _add_banner() -> void:
	# Once everyone's home: "REX FOR MAYOR (one day)" in hologram letters by the clock (Hayden: Rex is mayor of Lumen
	# City in the far future)
	if get_node_or_null("Mayor Banner") != null:
		return
	var m := Node3D.new()
	m.name = "Mayor Banner"
	add_child(m)
	m.global_position = ground_below(CLOCK_AT + BANNER_AT + Vector3(0, 1.0, 0))
	m.rotation.y = atan2(-BANNER_AT.x, -BANNER_AT.z) + PI       # facing out, away from the clock
	for x in [-1.5, 1.5]:
		_put(m, _cyl(0.07, 0.09, 3.0, 8), _mat(Color(0.3, 0.3, 0.45), 0.0, 0.4), Vector3(x, 1.5, 0))
	_put(m, _box(Vector3(3.2, 1.2, 0.05)), _mat(Color(1.0, 0.45, 0.85), 1.2, 0.3, 0.55), Vector3(0, 2.4, 0))
	var l := Label3D.new()
	l.name = "Words"
	l.text = "REX FOR MAYOR\n(one day)"
	l.font_size = 64
	l.pixel_size = 0.008
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.6)
	l.position = Vector3(0, 2.4, 0.06)
	l.double_sided = false                                     # (each side shows its own words, never the other's backwards)
	m.add_child(l)
	var back := l.duplicate() as Label3D
	back.position.z = -0.06
	back.rotation.y = PI
	m.add_child(back)


func _add_old_oak() -> void:
	# The Old Oak: Stars Hollow's oak, still standing a long, long time later, kept in a little ring of grass with a
	# plaque. A trunk you can't walk through, a broad crown of leaves and soft glowing runes up its bark, like the ones
	# on the old oak back home. Touching it hums (touch_oak())
	if get_node_or_null("Old Oak") != null:
		return
	var m := Node3D.new()
	m.name = "Old Oak"
	add_child(m)
	m.global_position = ground_below(OAK_AT + Vector3(0, 1.0, 0))
	var bark := _mat(Color(0.36, 0.26, 0.2), 0.0, 0.9)
	var grass := _mat(Color(0.3, 0.55, 0.3), 0.0, 0.9)
	var leaf := _mat(Color(0.36, 0.56, 0.26), 0.0, 0.8)
	var leaf2 := _mat(Color(0.46, 0.66, 0.3), 0.0, 0.8)
	var rune := _mat(Color(0.55, 1.0, 0.85), 1.6, 0.4)
	_put(m, _cyl(4.2, 4.4, 0.12, 32), grass, Vector3(0, 0.06, 0))
	_put(m, _cyl(4.4, 4.5, 0.2, 32), _mat(Color(0.5, 0.52, 0.62), 0.0, 0.6), Vector3(0, 0.02, 0))
	_put(m, _cyl(0.95, 1.4, 5.0, 14), bark, Vector3(0, 2.5, 0))
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		_put(m, _cyl(0.2, 0.42, 3.4, 8), bark, Vector3(cos(a) * 1.2, 5.4, sin(a) * 1.2), Vector3.ONE, Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7))
		_put(m, _cyl(0.2, 0.45, 1.6, 8), bark, Vector3(cos(a) * 1.5, 0.25, sin(a) * 1.5), Vector3.ONE, Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
	# A broad, lumpy crown: lots of overlapping clumps in two greens, wider than it is tall, like an old oak's
	var rng := RandomNumberGenerator.new()
	rng.seed = 1893
	_put(m, _ball(3.4, 14), leaf, Vector3(0, 7.8, 0), Vector3(1.25, 0.75, 1.25))
	for k in 14:
		var a := TAU * k / 14.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(2.6, 4.2)
		var at := Vector3(cos(a) * r, rng.randf_range(6.4, 9.0), sin(a) * r)
		_put(m, _ball(rng.randf_range(1.4, 2.1), 10), leaf if k % 3 else leaf2, at, Vector3(1.0, 0.75, 1.0))
	for k in 7:
		var a := TAU * k / 7.0
		_put(m, _box(Vector3(0.12, 0.34, 0.04)), rune, Vector3(cos(a) * 1.18, 1.0 + k * 0.45, sin(a) * 1.18), Vector3.ONE, Vector3(0, -a + PI / 2.0, 0))
	var body := StaticBody3D.new()
	body.name = "Trunk"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 6.0
	shape.shape = cyl
	shape.position.y = 3.0
	body.add_child(shape)
	m.add_child(body)
	var plaque := Label3D.new()
	plaque.name = "Plaque"
	plaque.text = "THE OLD OAK\nIt was here before the city.\nIt still hums."
	plaque.font_size = 28
	plaque.pixel_size = 0.008
	plaque.outline_size = 8
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.position = Vector3(0, 2.6, 2.2)
	m.add_child(plaque)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.55, 1.0, 0.85)
	glow.light_energy = 0.8
	glow.omni_range = 6.0
	glow.position = Vector3(0, 2.0, 1.8)
	m.add_child(glow)
	var spot := USE_SPOT.make(Vector3(0, 0, 1.7), func() -> String: return "touch the old oak", touch_oak, 2.6, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func oak_lines() -> Array:
	# A hint, never a spoiler: before the ending it only sounds familiar; after, everyone knows why
	if AFTER.everyone_home():
		return ["(The old oak hums under your hand, slow and warm.)",
			"(It's the same tree as back home!)"]
	return ["(The old oak hums under your hand, slow and warm.)",
		"(It hums just like the oak in Stars Hollow!)"]


func touch_oak() -> void:
	var spot := get_node_or_null("Old Oak/Spot") as Node3D
	if spot == null:
		return
	Portals.note_found(world_id, "oak_touched")
	Dialogue.say(spot, "The Old Oak", oak_lines(), "far_future_oak")


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
	Game.message("A glitchy statue. Bring %d Time Core%s home first." % [left, "" if left == 1 else "s"]
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
	var hand := get_node_or_null("Knot Clock/Hand") as Node3D
	if hand:
		hand.rotation.z += delta * 9.0                   # (backwards, like his)
	if Portals.is_cleared(world_id):
		_check_goodbye(player)
		_spin_letter(delta)
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
	for n in ["Rex", "Dash", "Rook"]:
		var m := get_node_or_null(n) as Node3D
		if m == null:
			continue
		m.visible = not racing
		var model := m.get_node_or_null("Model") as Node3D
		if model == null or player == null:
			continue
		var to := player.global_position - m.global_position
		if Vector2(to.x, to.z).length() > 9.0 or swapping or (goodbye and goodbye.call("playing")):
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


static func knot_clock_model() -> Node3D:
	# A flickering picture of the Agent of Chaos's cracked clock, its hand spinning backwards (the other end of the knot)
	var g := Node3D.new()
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.08
	face.mesh = disc
	face.material_override = _mat(Color(0.55, 0.2, 0.85), 1.6, 0.4, 0.75)
	face.rotation.x = PI / 2.0
	g.add_child(face)
	var rim := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.05
	t.outer_radius = 1.25
	rim.mesh = t
	rim.material_override = _mat(Color(0.95, 0.75, 0.3), 1.0, 0.3)
	rim.rotation.x = PI / 2.0
	g.add_child(rim)
	var hand := Node3D.new()
	hand.name = "Hand"
	g.add_child(hand)
	var stick := MeshInstance3D.new()
	stick.mesh = _box(Vector3(0.1, 0.85, 0.06))
	stick.material_override = _mat(Color(1.0, 0.9, 0.6), 2.0)
	stick.position = Vector3(0, 0.38, 0.08)
	hand.add_child(stick)
	var crack := MeshInstance3D.new()
	crack.mesh = _box(Vector3(0.06, 1.9, 0.1))
	crack.material_override = _mat(Color(0.05, 0.0, 0.1))
	crack.position.z = 0.07
	crack.rotation.z = 0.5
	g.add_child(crack)
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
