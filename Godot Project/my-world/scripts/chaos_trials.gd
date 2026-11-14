extends Node

# The friends' sections of the Agent of Chaos's final fight (Hayden, Nov 10, 2026: "let's expand his current mechanics
# to include sections that require you to use all of the skills that you have learned"). A "Trials" node under the
# fight (scripts/chaos_fight.gd), which hands a turn over to it now and then.
#
# The story: all the broken time from the portal worlds is knotted into his cracked clock, so he pulls each world's
# trouble back out and throws it at you, one at a time, in the order you mended them. Each one shuts his clock tight,
# and only the move that world's friend taught you gets it open again. Do it and he's dazed with his clock glowing;
# take too long and he carries on and tries it again later (after three goes he gives that one up, so nobody's ever
# stuck). A section only comes up if you've learned its move (old saves that opened the fight with the three bosses
# might not have them all).
#
#   Phase 1 (45 to 31 chaos)
#     burrow   Bramble     The Static Storm: crackling static all round his feet buzzes you away on foot. Burrow under
#                          it to the Root Knot by his feet: roots burst up and trip him.
#     frost    Flurry      The River of Melted Time: a ring of glowing time sludge round him sweeps you back out.
#                          Freeze it (Frost breath) and cross on the ice to the knot by his feet.
#     glow     Pip         Lights Out: he swallows the daylight. Pip's glow wakes three lantern stones, and the third is
#                          on a floating rock: ride the moth swirl up and glide over on Pip's moth wings.
#   Phase 2 (30 to 16)
#     groove   Melody      The Off-Beat Stomp: he stamps a wonky beat (rings to jump). Groove on the beat three times
#                          close enough for him to hear it and he can't help dancing.
#     swim     Otto        The Time Flood: the field floods over your head. Dive to the bottom and pull the plug.
#     spring   Heather     Glitch Fires: put out three fires with April Showers, then a big clock gear rises in front of
#                          his chest: Spring Step (or a rainbow) up onto it, face to face with his clock.
#     gadgets  Dash        Glitch Crystals: three crystals shield his clock and bubbles bounce off them. Any of Dash's
#                          other gadgets shatters them (he throws you some ammo).
#   Phase 3 (15 to 0)
#     crawl    the centipede  The Clock Tower: a tower of glitch cubes shoots up in front of his clock. Climb it (wall
#                          crawl) and leap onto his clock from the top.
#     watch    Rex and Dash   The Big Rewind: his clock spins too fast to touch, winding a huge rewind. Hold up your
#                          watch (it ticks Earth's way, and Dash tuned it) and the rewind can't take you: it knots him up.
#
# Kid-safe: the static and the sludge only push you back, nothing hurts but the old shock rings, and every friend
# cheers you on.

signal section_started(id: String)
signal section_ended(id: String, ok: bool)

const SECTIONS := [
	{"id": "burrow", "phase": 1, "world": "rootmind", "friend": "Bramble"},
	{"id": "frost", "phase": 1, "world": "frozen_moment", "friend": "Flurry"},
	{"id": "glow", "phase": 1, "world": "lanternmoor", "friend": "Pip"},
	{"id": "spring", "phase": 2, "world": "glenmoor", "friend": "Heather"},
	{"id": "swim", "phase": 2, "world": "tide_reef", "friend": "Otto"},
	{"id": "groove", "phase": 2, "world": "rhythm_springs", "friend": "Melody"},
	{"id": "gadgets", "phase": 2, "world": "", "friend": "Dash"},
	{"id": "crawl", "phase": 3, "world": "dark_hollow", "friend": "The centipede"},
	{"id": "watch", "phase": 3, "world": "", "friend": "Rex"},
]
const TIME := {"burrow": 35.0, "frost": 45.0, "glow": 70.0, "groove": 35.0, "swim": 45.0, "spring": 50.0,
	"gadgets": 40.0, "crawl": 45.0, "watch": 7.0}
const TRIES := 3                              # goes at a section before he gives it up
const PURPLE := Color(0.75, 0.3, 1.0)
const GOLD := Color(1.0, 0.8, 0.3)

# Burrow
const STATIC_R := 11.0                        # the static storm round his feet
const KNOT_OUT := 4.6                         # the Root Knot (and the frost knot), out in front of his feet
const KNOT_NEAR := 2.2
# Frost
const RIVER_R := 11.0                         # the middle of the ring of sludge...
const RIVER_BLOB := 4.0                       # ...made of round pools this big (so 7 to 15 m out)
const RIVER_BLOBS := 16
# Glow
const LANTERN_OUT := 8.0
const SWIRL_OUT := 10.0                       # the moth swirl, out towards where you came from
const ROCK_ACROSS := 18.0                     # ...and the floating rock, this far to one side of it
const ROCK_UP := 5.0
const SWIRL_TOP := 13.0
const SWIRL_R := 1.7
const LIFT := 6.5
# Groove
const GROOVES := 3
const STOMP_EVERY := 3.0
# Swim
const FLOOD_R := 24.0
const FLOOD_DEEP := 3.6
# Spring
const FIRE_OUT := 9.0
const GEAR_OUT := 4.6
const GEAR_UP := 5.0                          # higher than a jump and a double jump, not a Spring Step and one
const GEAR_R := 1.9
# Gadgets
const CRYSTAL_OUT := 7.0
# Crawl
# (At 4.4 m out the tower's near face was only 2.8 m from him, and his chest clock (1.5 m in front of him, 1.7 m
# round, 5.5 to 8.9 m up) poked through it: climbing that face you got stuck under his clock halfway up. Found in the
# 10 Nov playthrough. Now the near face is 4.0 m out, clear of the clock and you.)
const TOWER_OUT := 5.6
const TOWER_UP := 10.0                        # far higher than any jump
const TOWER_W := 3.2

var fight: Node                               # the ChaosFight this belongs to
var off := false                              # tests of the old fight turn every section off
var only: Array = []                          # tests: just these sections (empty = all that are learned)
var done := {}                                # id -> true once beaten this fight
var tries := {}                               # id -> goes so far
var current := ""
var left := 0.0                               # seconds left of this go
var root: Node3D                              # this go's things in the world

# What the current go has going on (tests read these)
var knot: Node3D
var lanterns: Array[Node3D] = []
var swirl_at := Vector3.ZERO
var rock: Node3D
var fires: Array[Node3D] = []
var gear: Node3D
var crystals: Array[Node3D] = []
var tower: StaticBody3D
var flood: Node3D
var river: Array[Node3D] = []
var heard := 0                                # on-beat grooves he heard
var watched := false
var pushed_back := 0                          # times the static or the sludge sent you back

var _base := Vector3.ZERO                     # the ground under him when the go started
var _out := Vector3.FORWARD                   # flat, from him towards the player then
var _side := Vector3.RIGHT
var _tick := 0.0
var _safe := Vector3.ZERO                     # the player's last spot outside the sludge
var _wet_for := 0
var _told := {}
var _wings: Node3D
var _glide_was := 0.0
var _model_was := Transform3D.IDENTITY


# --- Which sections there are --------------------------------------------------------------------------------------

func info(id: String) -> Dictionary:
	for s in SECTIONS:
		if s.id == id:
			return s
	return {}


func learned(id: String) -> bool:
	# Has the player got the move this section needs?
	var s := info(id)
	if s.is_empty():
		return false
	var portals := get_node_or_null("/root/Portals")
	match id:
		"gadgets":
			return Arsenal.owned.any(func(g: String) -> bool: return g != "popper")
		"watch":
			return TimeWatch.has_watch()
		"glow":
			return portals != null and portals.is_cleared("lanternmoor")
	return portals != null and portals.is_cleared(str(s.world))


func available(id: String) -> bool:
	if off or (not only.is_empty() and not (id in only)):
		return false
	return learned(id) and not done.has(id) and int(tries.get(id, 0)) < TRIES


func pending(phase: int) -> String:
	# The next section for this phase, or ""
	for s in SECTIONS:
		if int(s.phase) == phase and available(str(s.id)):
			return str(s.id)
	return ""


func busy() -> bool:
	return current != ""


func spinning() -> bool:
	return current == "watch"


func reset() -> void:
	# The fight's been called off: next time, everything again
	cleanup()
	done.clear()
	tries.clear()


# --- A go at a section ---------------------------------------------------------------------------------------------

func start(id: String) -> void:
	cleanup()
	current = id
	Party.bring_for(id)                               # that friend comes along for it (scripts/party.gd)
	left = float(TIME.get(id, 40.0))
	tries[id] = int(tries.get(id, 0)) + 1
	var giant := fight.get("giant") as Node3D
	var player := fight.get("player") as Node3D
	_base = fight.call("_ground", giant.global_position)
	_out = player.global_position - giant.global_position
	_out.y = 0.0
	_out = _out.normalized() if _out.length() > 0.5 else Vector3(sin(giant.rotation.y), 0, cos(giant.rotation.y))
	_side = _out.cross(Vector3.UP).normalized()
	root = Node3D.new()
	root.name = "Chaos Trial %s" % id
	giant.get_parent().add_child(root)
	_tick = 0.0
	heard = 0
	watched = false
	pushed_back = 0
	var model := giant.get_node_or_null("Model") as Node3D
	if model:
		_model_was = model.transform
	giant.call("_play", "chaos", 1.0)
	Juice.shake(0.4)
	call("_start_" + id)
	section_started.emit(id)


func update(delta: float) -> void:
	# Called by the fight every physics frame while a section's on
	if current == "":
		return
	left -= delta
	_tick -= delta
	var ok: bool = call("_update_" + current, delta)
	if ok:
		_end(true)
	elif left <= 0.0:
		_end(false)


func _end(ok: bool) -> void:
	var id := current
	if ok:
		done[id] = true
		_say(id, "win")
	elif int(tries.get(id, 0)) >= TRIES:
		_say(id, "give_up")
	else:
		_say(id, "again")
	if id == "glow":
		_take_wings()
		_free_dark()
	if id == "swim" or id == "frost":
		_drain()
	if not ok:
		cleanup()                                     # (done ones keep their gear or tower till his clock shuts)
	current = ""
	Party.bring_for("")
	section_ended.emit(id, ok)
	fight.call("trial_over", id, ok)


func cleanup() -> void:
	# Everything this go put out (the gear and the tower stay until his clock closes again: they're how you reach it)
	if current == "glow" or _wings != null:
		_take_wings()
	if current == "glow":
		_free_dark()
	current = ""
	Party.bring_for("")
	knot = null
	lanterns.clear()
	rock = null
	fires.clear()
	gear = null
	crystals.clear()
	tower = null
	flood = null
	river.clear()
	if root != null and is_instance_valid(root):
		root.queue_free()
	root = null
	var giant := fight.get("giant") as Node3D if fight else null
	var model := giant.get_node_or_null("Model") as Node3D if giant else null
	if model and _model_was != Transform3D.IDENTITY:
		model.transform = _model_was


func shot(_power: int, _point: Vector3) -> String:
	# His clock's shut tight while a section's on (the crystals take their own bubbles)
	if current == "gadgets" and not _told.has("bounce_clock"):
		_told["bounce_clock"] = true
		Game.message("Bubbles bounce off! Shatter his Glitch Crystals with one of Dash's gadgets first.")
	return "bounce"


# --- Bramble: the Static Storm -------------------------------------------------------------------------------------

func _start_burrow() -> void:
	_disc(_base, STATIC_R, Color(1.0, 0.3, 0.8, 0.22), "Static")
	knot = _knot(_base + _out * KNOT_OUT, Color(0.55, 0.95, 0.4), "Root Knot")
	_say("burrow", "start")


func _update_burrow(_delta: float) -> bool:
	var p := _player()
	var flat := _flat(p.global_position - _base)
	var under := p.burrow != null and bool(p.burrow.get("active"))
	if _tick <= 0.0:
		_tick = 0.25
		Fx.burst(root, _base + _out.rotated(Vector3.UP, randf() * TAU) * randf_range(2.0, STATIC_R) + Vector3.UP * 0.3,
			[PURPLE, GOLD, Color(1.0, 0.4, 0.8)][randi() % 3], 6, 0.06, 2.5, 0.0, 0.35)
	if flat < STATIC_R and not under and p.is_on_floor() and not p.is_invulnerable():
		_push_out(p, _base, "static", "The static buzzes you back! Go under it: %s to burrow." % Settings.key_name("burrow"))
	return under and _flat(p.global_position - knot.global_position) < KNOT_NEAR


# --- Flurry: the River of Melted Time ------------------------------------------------------------------------------

func _start_frost() -> void:
	var water_script: GDScript = load("res://scripts/water.gd")
	for i in RIVER_BLOBS:
		var a := TAU * i / RIVER_BLOBS
		var c := _base + Vector3(cos(a), 0, sin(a)) * RIVER_R
		var g: Vector3 = fight.call("_ground", c)
		var w: Node3D = water_script.new()
		w.name = "Melted Time %d" % i
		w.set("ellipses", [Vector4(c.x, c.z, RIVER_BLOB, RIVER_BLOB)] as Array[Vector4])
		w.set("water_y", g.y + 0.25)
		w.set("speed_scale", 0.4)
		root.add_child(w)
		w.add_child(_sludge_look(g + Vector3(0, 0.25, 0), RIVER_BLOB * 1.06))
		river.append(w)
	knot = _knot(_base + _out * KNOT_OUT, Color(0.6, 0.9, 1.0), "Frost Knot")
	var p := _player()
	if _in_river(p.global_position) or _flat(p.global_position - _base) < RIVER_R - RIVER_BLOB:
		p.global_position = _ground_at(_base + _out * (RIVER_R + RIVER_BLOB + 2.0)) + Vector3.UP * 0.4
		p.velocity = Vector3.ZERO
	_safe = p.global_position
	_say("frost", "start")


func _wet() -> bool:
	# Feet in the sludge for a couple of frames running (not just the frame she lands on a floe)
	_wet_for += 1
	return _wet_for >= 3


func _on_ice(p: Player) -> bool:
	# Straight down from her (the player's own floor check can lag a frame behind on landing)
	var q := PhysicsRayQueryParameters3D.create(p.global_position, p.global_position + Vector3(0, -1.4, 0))
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and (hit.collider as Node).is_in_group("ice")


func _in_river(at: Vector3) -> bool:
	for w in river:
		if is_instance_valid(w) and w.call("covers", at.x, at.z):
			return true
	return false


func _update_frost(_delta: float) -> bool:
	var p := _player()
	var here := p.global_position
	var on_ice := _on_ice(p)
	if not _in_river(here) or on_ice or not p.is_on_floor():
		_wet_for = 0
	if not _in_river(here):
		if p.is_on_floor() and _flat(here - _base) > RIVER_R:
			_safe = here
	elif p.is_on_floor() and not on_ice and _wet():
		pushed_back += 1
		p.global_position = _safe + Vector3.UP * 0.3
		p.velocity = Vector3.ZERO
		Fx.burst(root, here + Vector3.UP * 0.4, PURPLE, 14, 0.08, 3.0, -2.0, 0.6)
		Audio.play_at("splash", here, -2.0)
		_tell("frost_back", "The melted time sweeps you back! Freeze it with %s and cross on the ice." %
			Settings.key_name("frost_breath"))
	return _flat(here - knot.global_position) < KNOT_NEAR and absf(here.y - knot.global_position.y) < 2.5


# --- Pip: Lights Out ---------------------------------------------------------------------------------------------

func _start_glow() -> void:
	var kit: GDScript = load("res://scripts/cave_kit.gd")
	kit.call("dark_zone", root, _base + Vector3(0, 10, 0), Vector3(90, 50, 90), "Chaos Dark")
	_eclipse(1.0)
	for k in [-1.0, 1.0]:
		lanterns.append(_lantern(_ground_at(_base + _out * 3.0 + _side * k * LANTERN_OUT)))
	swirl_at = _ground_at(_base + _out * SWIRL_OUT)
	var side := _side
	var across := swirl_at + side * ROCK_ACROSS
	if absf(across.x) > 136.0 or absf(across.z) > 236.0:
		side = -side
		across = swirl_at + side * ROCK_ACROSS
	_swirl_look(swirl_at)
	var ground: Vector3 = _ground_at(across)
	rock = _floating_rock(ground + Vector3(0, ROCK_UP, 0))
	lanterns.append(_lantern(rock.global_position + Vector3(0, 0.25, 0)))
	_give_wings()
	_say("glow", "start")


func _update_glow(_delta: float) -> bool:
	var p := _player()
	# The moth swirl: hold Jump in it and the moths carry you up
	if _flat(p.global_position - swirl_at) < SWIRL_R and p.global_position.y < swirl_at.y + SWIRL_TOP \
			and Input.is_action_pressed("jump"):
		p.velocity.y = LIFT
		_tell("glow_lift", "Up you go! Now hold %s on the way down to glide to the floating rock." % Settings.key_name("jump"))
	if _tick <= 0.0:
		_tick = 0.3
		Fx.burst(root, swirl_at + Vector3(randf_range(-1, 1), randf_range(0.5, SWIRL_TOP), randf_range(-1, 1)),
			Color(1.0, 0.86, 0.62), 3, 0.05, 1.0, -0.5, 1.2)
	return lanterns.all(func(l: Node3D) -> bool: return is_instance_valid(l) and bool(l.get("awake")))


func _give_wings() -> void:
	var p := _player()
	_glide_was = float(p.get("glide_fall"))
	p.set("glide_fall", 1.2)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual and visual.get_node_or_null("Moth Wings") == null:
		_wings = load("res://scripts/lanternmoor.gd").call("wings_model")
		_wings.name = "Moth Wings"
		visual.add_child(_wings)


func _take_wings() -> void:
	var p := _player()
	if p:
		p.set("glide_fall", _glide_was)
	if _wings != null and is_instance_valid(_wings):
		_wings.queue_free()
	_wings = null


func _free_dark() -> void:
	_eclipse(0.0)
	if root:
		for z in root.get_children():
			if z.is_in_group("cave_dark"):
				z.queue_free()


func _eclipse(to: float) -> void:
	# The Void's sky and sun go to night and back (scripts/day_night.gd)
	var scene := get_tree().current_scene
	var dn := scene.find_child("DayNight", false, false) if scene else null
	if dn and "eclipse" in dn:
		dn.create_tween().tween_property(dn, "eclipse", to, 1.2)


# --- Melody: the Off-Beat Stomp --------------------------------------------------------------------------------------

func _start_groove() -> void:
	var p := _player()
	if p.groove and not p.groove.is_connected("grooved", _on_grooved):
		p.groove.connect("grooved", _on_grooved)
	_tick = 1.5
	_say("groove", "start")


func _on_grooved(on_beat: bool, streak: int) -> void:
	if current != "groove":
		return
	var p := _player()
	var reach: float = float(p.groove.call("ring_for", streak)) + 2.5
	var flat := _flat(p.global_position - (fight.get("giant") as Node3D).global_position)
	if not on_beat:
		_tell("groove_off", "Off the beat! Melody's beat is steady: watch the beat card.")
	elif flat > reach:
		_tell("groove_far", "He can't hear you from there! Get closer and groove again.")
	else:
		heard += 1
		var giant := fight.get("giant") as Node3D
		Fx.burst(root, giant.global_position + Vector3(0, 6.0, 0), Color(1.0, 0.55, 0.85), 10, 0.1, 3.0, 0.0, 0.8)
		if heard < GROOVES:
			Game.message("His foot taps along... (%d of %d)" % [heard, GROOVES])


func _update_groove(_delta: float) -> bool:
	if _tick <= 0.0:
		_tick = STOMP_EVERY
		var giant := fight.get("giant") as Node3D
		ShockRing.spawn(giant.get_parent(), giant.global_position, 22.0, Color(1.0, 0.55, 0.85), 1, 2.6)
		Audio.play_at("stomp", giant.global_position, 4.0, -0.5)
		Juice.shake(0.25)
	if heard >= GROOVES:
		_dance()
		return true
	return false


func _dance() -> void:
	# He can't help it: a big wobbly dance on the spot
	var model := (fight.get("giant") as Node3D).get_node_or_null("Model") as Node3D
	if model == null:
		return
	var was := model.rotation
	var tw := model.create_tween()
	for i in 4:
		tw.tween_property(model, "rotation:z", was.z + (0.12 if i % 2 == 0 else -0.12), 0.25)
	tw.tween_property(model, "rotation:z", was.z, 0.25)


# --- Otto: the Time Flood ------------------------------------------------------------------------------------------

func _start_swim() -> void:
	var w: Node3D = (load("res://scripts/water.gd") as GDScript).new()
	w.name = "Time Flood"
	w.set("ellipses", [Vector4(_base.x, _base.z, FLOOD_R, FLOOD_R)] as Array[Vector4])
	w.set("water_y", _base.y - 0.5)
	w.set("speed_scale", 0.7)
	root.add_child(w)
	var look := _sludge_look(_base + Vector3(0, -0.5, 0), FLOOD_R * 1.07, Color(0.25, 0.55, 0.85, 0.5))
	look.name = "Surface"
	w.add_child(look)
	flood = w
	var tw := w.create_tween().set_parallel()
	tw.tween_property(w, "water_y", _base.y + FLOOD_DEEP, 3.0)
	tw.tween_property(look, "global_position:y", _base.y + FLOOD_DEEP, 3.0)
	knot = _knot(_base + _out * KNOT_OUT, Color(0.4, 0.9, 1.0), "Plug")
	_say("swim", "start")


func _update_swim(_delta: float) -> bool:
	var p := _player()
	var under := p.swim != null and bool(p.swim.get("under"))
	if under and not _told.has("swim_under"):
		_told["swim_under"] = true
	return under and p.global_position.distance_to(knot.global_position) < KNOT_NEAR + 0.6


func _drain() -> void:
	if flood != null and is_instance_valid(flood):
		var look := flood.get_node_or_null("Surface") as Node3D
		var tw := flood.create_tween().set_parallel()
		tw.tween_property(flood, "water_y", _base.y - 2.0, 1.5)
		if look:
			tw.tween_property(look, "global_position:y", _base.y - 2.0, 1.5)
		Audio.play_at("splash", _base, 2.0)
	for w in river:
		if is_instance_valid(w):
			w.queue_free()
	river.clear()


# --- Heather: Glitch Fires and the clock gear ----------------------------------------------------------------------

func _start_spring() -> void:
	for a in [-0.75, 0.0, 0.75]:
		fires.append(_fire(_ground_at(_base + _out.rotated(Vector3.UP, a) * FIRE_OUT)))
	_say("spring", "start")


func _update_spring(_delta: float) -> bool:
	var p := _player()
	var raining := p.showers != null and float(p.showers.get("raining")) > 0.0
	for f in fires:
		if is_instance_valid(f) and not f.get_meta("out", false) and raining \
				and _flat(p.global_position - f.global_position) < 3.2:
			_put_out(f)
	if gear == null:
		if fires.all(func(f: Node3D) -> bool: return f.get_meta("out", false)):
			_raise_gear()
		return false
	var top := gear.global_position.y + 0.15
	return p.is_on_floor() and p.global_position.y > top - 0.2 and _flat(p.global_position - gear.global_position) < GEAR_R


func _put_out(f: Node3D) -> void:
	f.set_meta("out", true)
	Fx.burst(root, f.global_position + Vector3.UP * 0.8, Color(0.85, 0.9, 1.0, 0.8), 18, 0.12, 2.0, 1.0, 1.0)
	Audio.play_at("splash", f.global_position, -2.0)
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3(0.05, 0.05, 0.05), 0.5)
	tw.tween_callback(func() -> void: f.visible = false)
	var still := fires.filter(func(x: Node3D) -> bool: return not x.get_meta("out", false)).size()
	Game.message("Fizzle! %s" % ("That's all three!" if still == 0 else "%d to go." % still))


func _raise_gear() -> void:
	gear = _gear_model()
	root.add_child(gear)
	var at := _ground_at(_base + _out * GEAR_OUT)
	gear.global_position = at
	gear.create_tween().tween_property(gear, "global_position:y", at.y + GEAR_UP, 1.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say("spring", "gear")


# --- Dash: the Glitch Crystals -------------------------------------------------------------------------------------

func _start_gadgets() -> void:
	for id in Arsenal.owned:
		Arsenal.refill(id, 99)
	for a in [-1.0, 0.0, 1.0]:
		var c := _crystal()
		root.add_child(c)
		c.global_position = _ground_at(_base + _out.rotated(Vector3.UP, a * 0.9) * CRYSTAL_OUT) + Vector3(0, 1.6, 0)
		crystals.append(c)
	_say("gadgets", "start")


func crystal_shot(c: Node3D) -> String:
	if c.get_meta("broken", false):
		return "miss"
	if Arsenal.current == "popper" and not c.get("plushed"):
		_tell("crystal_popper", "Boing! Bubbles bounce off. Hold %s and pick another gadget!" % Settings.key_name("gadget_wheel"))
		return "bounce"
	c.set_meta("broken", true)
	c.set("defeated", true)
	Fx.burst(root, c.global_position, PURPLE, 20, 0.12, 4.0, -3.0, 0.8)
	Fx.burst(root, c.global_position, Color(0.5, 1.0, 0.95), 10, 0.08, 3.0, -3.0, 0.6)
	Audio.play_at("pop", c.global_position, 0.0)
	Juice.shake(0.2)
	c.remove_from_group("enemies")
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	tw.tween_callback(func() -> void: c.visible = false; (c as CollisionObject3D).process_mode = Node.PROCESS_MODE_DISABLED)
	return "hit"


func _update_gadgets(_delta: float) -> bool:
	for c in crystals:
		if is_instance_valid(c) and c.visible:
			c.rotate_y(0.03)
	return crystals.all(func(c: Node3D) -> bool: return c.get_meta("broken", false))


# --- The centipede: the Clock Tower --------------------------------------------------------------------------------

func _start_crawl() -> void:
	tower = StaticBody3D.new()
	tower.name = "Glitch Tower"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TOWER_W, TOWER_UP, TOWER_W)
	cs.shape = box
	cs.position.y = TOWER_UP * 0.5
	tower.add_child(cs)
	tower.add_child(_tower_look())
	root.add_child(tower)
	var at := _ground_at(_base + _out * TOWER_OUT)
	tower.global_position = at - Vector3(0, TOWER_UP, 0)
	tower.look_at(at - Vector3(0, TOWER_UP, 0) + _out, Vector3.UP)
	tower.create_tween().tween_property(tower, "global_position:y", at.y, 1.2).set_ease(Tween.EASE_OUT)
	Juice.rumble(0.6, 0.4, 0.8)
	_say("crawl", "start")


func _update_crawl(_delta: float) -> bool:
	var p := _player()
	var top := tower.global_position.y + TOWER_UP
	return p.global_position.y > top - 0.3 and _flat(p.global_position - tower.global_position) < TOWER_W * 0.75


# --- Rex and Dash: the Big Rewind ----------------------------------------------------------------------------------

func _start_watch() -> void:
	fight.call("_show_glow", true)
	_tick = 1.0
	_say("watch", "start")
	Juice.blip("rewind", 0.4, -2.0)


func _update_watch(_delta: float) -> bool:
	if _tick <= 0.0:
		_tick = 1.0
		Juice.blip("tick", 0.6 + 0.1 * (TIME.watch - left), -6.0)
	var hud := _player().get_node_or_null("HUD")
	if hud and hud.get("glance") and (hud.get("glance") as Control).visible:
		watched = true
	return watched


# --- Bits ----------------------------------------------------------------------------------------------------------

func _player() -> Player:
	return fight.get("player") as Player


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _ground_at(at: Vector3) -> Vector3:
	return fight.call("_ground", at)


func _push_out(p: Player, from: Vector3, key: String, line: String) -> void:
	pushed_back += 1
	var away := p.global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else _out
	p.velocity = away * 9.0 + Vector3.UP * 4.5
	p.global_position += Vector3.UP * 0.1
	Audio.play_at("boing", p.global_position, -4.0, 0.2)
	Fx.burst(root, p.global_position + Vector3.UP * 0.5, Color(1.0, 0.4, 0.8), 10, 0.06, 3.0, 0.0, 0.4)
	_tell(key, line)


func _tell(key: String, line: String) -> void:
	# A hint, once a go
	if _told.get(key, -1) == int(tries.get(current, 0)):
		return
	_told[key] = int(tries.get(current, 0))
	Game.message(line)


func _say(id: String, what: String) -> void:
	var f := str(info(id).get("friend", ""))
	var lines := {
		"burrow": {
			"start": "He shakes a storm of static out of his clock! Bramble: \"Static can't get you under the ground! Burrow (%s) to the Root Knot by his feet!\"" % Settings.key_name("burrow"),
			"win": "Roots burst up and tangle round his ankles! He stumbles: pop his clock!",
		},
		"frost": {
			"start": "A river of melted time pours round him! Flurry: \"Freeze it with your frost breath (%s) and cross on the ice!\"" % Settings.key_name("frost_breath"),
			"win": "You reach the Frost Knot: the river freezes solid, and him with it! Pop his clock!",
		},
		"glow": {
			"start": "He swallows the daylight! Pip: \"Don't be scared, my glow's with you. Wake the three lantern stones! One's up on that floating rock: ride the moth swirl up (hold %s) and glide!\"" % Settings.key_name("jump"),
			"win": "All three lanterns blaze! The light comes back and dazzles him: pop his clock!",
		},
		"groove": {
			"start": "He stomps a wonky beat! Melody: \"Ugh, he's off the beat! Groove (%s) on MY beat, close to him, and he won't be able to help himself!\"" % Settings.key_name("groove"),
			"win": "He can't help it: the Agent of Chaos is DANCING! Pop his clock!",
		},
		"swim": {
			"start": "He floods the field with time! Otto: \"Dive down (hold %s) and pull the glowing plug by his feet!\"" % Settings.key_name("dash"),
			"win": "You pull the plug! The flood drains away and he's left soggy and dazed: pop his clock!",
		},
		"spring": {
			"start": "Glitch fires spring up round him! Heather: \"Well I'll be! Put 'em out with April Showers (%s), sugar!\"" % Settings.key_name("showers"),
			"gear": "A big clock gear rises in front of his chest! Heather: \"Spring Step up there: jump the second you land, three times!\"",
			"win": "You're face to face with his clock! Heather: \"Yeehaw! Give it a pop!\"",
		},
		"gadgets": {
			"start": "Glitch Crystals shield his clock! Dash: \"Bubbles won't crack those. Here, ammo! Try something with a bit more fizz (hold %s).\"" % Settings.key_name("gadget_wheel"),
			"win": "Every crystal's shattered! Dash: \"Ha! Told you it'd work!\" Pop his clock!",
		},
		"crawl": {
			"start": "A tower of glitch cubes shoots up in front of his clock! The centipede: \"Walk right into it and climb! Up up up, like me!\"",
			"win": "From the top of the tower you leap right onto his clock! He's dazed: pop it!",
		},
		"watch": {
			"start": "His clock spins backwards too fast to touch: he's winding up the BIGGEST rewind! Rex: \"Your watch ticks Earth's way! Hold it up (%s), quick!\"" % Settings.key_name("check_watch"),
			"win": "Your watch ticks on, steady as Earth! The rewind can't take you, so it knots him up instead. Pop his clock!",
		},
	}
	var line := ""
	match what:
		"again":
			line = "He shakes it off. He'll try that one again, so be ready!"
		"give_up":
			line = "%s: \"Never mind that one, you're doing great! Keep popping his clock!\"" % f
		_:
			line = str(lines.get(id, {}).get(what, ""))
	if line != "":
		Game.message(line)


func _disc(at: Vector3, r: float, col: Color, nm: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nm
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.05
	c.radial_segments = 48
	m.mesh = c
	m.material_override = _glow_mat(col, 1.5)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = at + Vector3(0, 0.08, 0)
	return m


func _glow_mat(col: Color, emit := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(col.r, col.g, col.b)
	m.emission_energy_multiplier = emit
	return m


func _knot(at: Vector3, col: Color, nm: String) -> Node3D:
	# A glowing knot of time: a twisted ring floating just over the ground
	var n := Node3D.new()
	n.name = nm
	root.add_child(n)
	n.global_position = _ground_at(at) + Vector3(0, 0.9, 0)
	for k in 3:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.45
		tm.outer_radius = 0.7
		t.mesh = tm
		t.material_override = _glow_mat(col, 2.5)
		t.rotation = Vector3(k * 1.05, k * 0.7, 0)
		n.add_child(t)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 2.0
	light.omni_range = 6.0
	n.add_child(light)
	n.create_tween().set_loops().tween_property(n, "rotation:y", TAU, 3.0).from(0.0)
	return n


func _sludge_look(at: Vector3, r: float, col := Color(0.7, 0.3, 1.0, 0.55)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = 0.06
	c.radial_segments = 40
	m.mesh = c
	m.material_override = _glow_mat(col, 0.8)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at                                   # (its water node sits at the origin)
	return m


func _lantern(at: Vector3) -> Node3D:
	# A lantern stone: a stone post with a lantern on top that Pip's glow wakes (group glow_wake, like the
	# Glimmer Caves' crystals)
	var n: Node3D = _LANTERN.new()
	n.name = "Lantern Stone"
	n.add_to_group("glow_wake")
	root.add_child(n)
	n.global_position = at
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.25
	pm.bottom_radius = 0.4
	pm.height = 1.4
	post.mesh = pm
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.35, 0.32, 0.42)
	post.material_override = stone
	post.position.y = 0.7
	n.add_child(post)
	var lamp := MeshInstance3D.new()
	lamp.name = "Lamp"
	var lm := SphereMesh.new()
	lm.radius = 0.4
	lm.height = 0.8
	lamp.mesh = lm
	lamp.material_override = _glow_mat(Color(0.3, 0.28, 0.25), 0.0)
	lamp.position.y = 1.7
	n.add_child(lamp)
	return n


func _swirl_look(at: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.name = "Moth Swirl"
	var c := CylinderMesh.new()
	c.top_radius = SWIRL_R
	c.bottom_radius = SWIRL_R
	c.height = SWIRL_TOP
	c.cap_top = false
	c.cap_bottom = false
	m.mesh = c
	m.material_override = _glow_mat(Color(1.0, 0.86, 0.62, 0.18), 1.2)
	(m.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = at + Vector3(0, SWIRL_TOP * 0.5, 0)


func _floating_rock(at: Vector3) -> Node3D:
	var b := StaticBody3D.new()
	b.name = "Floating Rock"
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.6
	cy.height = 1.0
	cs.shape = cy
	cs.position.y = -0.5
	b.add_child(cs)
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.6
	cm.bottom_radius = 0.6
	cm.height = 2.4
	cm.radial_segments = 9
	m.mesh = cm
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.34, 0.5)
	m.material_override = stone
	m.position.y = -1.2
	b.add_child(m)
	root.add_child(b)
	b.global_position = at
	return b


func _fire(at: Vector3) -> Node3D:
	# A glitch fire: flickering magenta and gold flames of little cubes (kid-safe: no smoke)
	var n := Node3D.new()
	n.name = "Glitch Fire"
	root.add_child(n)
	n.global_position = at
	for k in 3:
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.7 - k * 0.15
		cm.height = 1.8 - k * 0.3
		cm.radial_segments = 6
		f.mesh = cm
		f.material_override = _glow_mat([Color(1.0, 0.3, 0.75, 0.85), Color(0.75, 0.3, 1.0, 0.85), GOLD][k], 2.5)
		f.position = Vector3(randf_range(-0.2, 0.2), cm.height * 0.5, randf_range(-0.2, 0.2))
		f.rotation.y = k * 0.8
		n.add_child(f)
		var tw := f.create_tween().set_loops()
		tw.tween_property(f, "scale", Vector3(1.1, 1.25, 1.1), 0.18 + 0.05 * k)
		tw.tween_property(f, "scale", Vector3(0.9, 0.85, 0.9), 0.18 + 0.05 * k)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.8)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 1.0
	n.add_child(light)
	return n


func _gear_model() -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Clock Gear"
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = GEAR_R
	cy.height = 0.3
	cs.shape = cy
	b.add_child(cs)
	var gold := _glow_mat(Color(0.95, 0.75, 0.3), 0.4)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = GEAR_R
	dm.bottom_radius = GEAR_R
	dm.height = 0.3
	disc.mesh = dm
	disc.material_override = gold
	b.add_child(disc)
	for k in 12:
		var tooth := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.45, 0.3, 0.5)
		tooth.mesh = tb
		tooth.material_override = gold
		var a := TAU * k / 12.0
		tooth.position = Vector3(cos(a), 0, sin(a)) * (GEAR_R + 0.2)
		tooth.rotation.y = -a
		b.add_child(tooth)
	return b


func _crystal() -> StaticBody3D:
	var b: StaticBody3D = _CRYSTAL.new()
	b.name = "Glitch Crystal"
	b.set("trials", self)
	b.add_to_group("enemies")
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.9
	cs.shape = sh
	b.add_child(cs)
	var m := MeshInstance3D.new()
	m.name = "Look"
	var pm := PrismMesh.new()
	pm.size = Vector3(1.2, 2.2, 1.2)
	m.mesh = pm
	m.material_override = _glow_mat(Color(0.7, 0.35, 1.0, 0.85), 1.8)
	b.add_child(m)
	var under := MeshInstance3D.new()
	var pm2 := PrismMesh.new()
	pm2.size = Vector3(1.2, 1.4, 1.2)
	under.mesh = pm2
	under.material_override = m.material_override
	under.rotation.z = PI
	under.position.y = -1.6
	b.add_child(under)
	return b


func _tower_look() -> Node3D:
	# A stack of purple and gold glitch cubes, jiggled a little so it reads as cubes, not a wall
	var n := Node3D.new()
	n.name = "Look"
	var mats := [_glow_mat(Color(0.45, 0.2, 0.7), 0.4), _glow_mat(Color(0.6, 0.3, 0.95), 0.6), _glow_mat(GOLD, 0.8)]
	var rows := int(TOWER_UP / 1.0)
	for y in rows:
		for k in 4:
			var c := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * 1.6
			c.mesh = bm
			c.material_override = mats[(y + k) % 3 if (y * 7 + k) % 5 else 2]
			c.position = Vector3((k % 2 - 0.5) * 1.6, y + 0.5, (k / 2 - 0.5) * 1.6) * Vector3(1, 1, 1)
			c.rotation.y = 0.05 * ((y + k) % 3 - 1)
			n.add_child(c)
	return n


# The little scripts for things that need a method of their own -------------------------------------------------------

const _LANTERN := preload("res://scripts/chaos_lantern.gd")
const _CRYSTAL := preload("res://scripts/chaos_crystal.gd")
