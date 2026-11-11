class_name RaceRival
extends Node3D

# A friend racing against you (scripts/races.gd): Dash on his BMX, Rex on his paw skates, Heather on her scooter and
# so on, each on their own ride from scripts/rides.gd. They follow the track's racing line (scripts/race_track.gd),
# each in a lane of their own that drifts a little, at a speed that suits their ride. They're good sports: when
# they're far ahead they ease off, and when they're far behind they pedal harder, so a race is close and
# anyone can win it with a clean run. Boost pads work for them too. They don't bump into anything: they ride
# through each other and the player, so nobody gets knocked off.
#
# Since 11 Nov 2026 they race for real: they pick up power-ups from the Star Boxes and throw them (at each other and at
# you: scripts/race_attacks.gd), put up Bubble Shields, steer round bumpers, goo and zappers they see coming (lane_goal),
# fly off jump ramps, and get knocked about too: a Bubble Seeker, a Zap Ring, a sweeper or a zapper spins them round
# and slows them right down for a moment (hit()), goo slows them (slow_down()), a bumper bounces them aside.
#
# In the sky race they're little aliens in their mini saucers (scripts/mini_saucer.gd, made bigger so they can be
# seen beside the mothership), flown along the line in the air by this script instead of their own wandering.

const CATCH_UP := 0.2                # at most this much faster when far behind the player
const EASE_OFF := 0.3                # at most this much slower when far ahead
const GAP := 70.0                    # metres ahead or behind for the most of either
const START_TIME := 1.6              # seconds to get up to speed from the line

var id := ""
var track: RaceTrack
var d := 0.0                         # how far round they've gone, all laps together
var lane := 0.0                      # metres to the right of the racing line
var skill := 1.0                     # their speed against their ride's own pushing speed
var speed := 0.0
var finished := false
var finish_time := 0.0
var _ride: Dictionary
var _boost := 0.0
var _t := 0.0
var _running := 0.0
var _model: Node3D
var _anim: AnimationPlayer
var item := ""                       # a power-up they're holding (scripts/race_attacks.gd uses it)
var item_wait := 0.0                 # ...and how long before they think about using it
var item_held := 0.0                 # ...and how long they've had it
var lane_goal := 0.0                 # the lane they're steering for
var _stun := 0.0                     # spinning round after a knock
var _slow := 0.0                     # slow going in goo
var _shield := 0.0
var _bubble: Node3D
var _hop := 0.0                      # off a jump ramp: how far through the hop (0: on the ground)
var _say: Label3D
var _say_time := 0.0
var saucer := {}                     # a sky racer: {"name", "colour"} (a little alien in a mini saucer)
var _name := ""                      # an Earth kid's name (from the townsfolk they're copied from)


func setup(who: String, t: RaceTrack, start_d: float, start_lane: float, how_good: float) -> void:
	id = who
	track = t
	d = start_d
	lane = start_lane
	lane_goal = start_lane
	skill = how_good
	_t = randf() * TAU


func _ready() -> void:
	if not saucer.is_empty():
		_saucer()
		return
	_ride = Races.ride_of(id)
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var kid := _townsfolk_copy()
	_model = kid if kid else (load(_ride.model) as PackedScene).instantiate() as Node3D
	_model.name = "Rider"
	_model.position.y = float(_ride.deck)
	_model.rotation.y = float(_ride.stance)
	visual.add_child(_model)
	var ride := Node3D.new()
	ride.name = "Ride"
	visual.add_child(ride)
	if kid:
		_name = str(_townsfolk_of(id).name) if _townsfolk_of(id) else str(Races.kid_look(id).name)
		RideKit.build(str(_ride.kit), ride, kid.model)
	else:
		if id != "hero":
			Clothes.dress(_model, id, Game.outfits.get(id, {}), Game.looks.get(id, {}))
		RideKit.build(str(_ride.kit), ride, _model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var pose := str(_ride.get("anim", "skate"))
	if _anim and _anim.has_animation(pose):
		_anim.get_animation(pose).loop_mode = Animation.LOOP_LINEAR
		_anim.play(pose)
	var tag := Label3D.new()
	tag.text = display_name()
	tag.font_size = 26
	tag.pixel_size = 0.01
	tag.outline_size = 10
	tag.modulate = Color(1, 0.95, 0.75)
	tag.outline_modulate = Color(0.15, 0.08, 0.2)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 2.3
	add_child(tag)
	_say = Label3D.new()
	_say.name = "Says"
	_say.font_size = 34
	_say.pixel_size = 0.01
	_say.outline_size = 12
	_say.modulate = Color(1.0, 0.85, 0.35)
	_say.outline_modulate = Color(0.15, 0.08, 0.2)
	_say.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_say.position.y = 2.75
	_say.visible = false
	add_child(_say)
	_place()


func _saucer() -> void:
	# Its speed is said straight out (skill is metres a second), with no ride to take it from
	_ride = {"push_speed": 1.0, "rider": str(saucer.name)}
	var s := Node3D.new()
	s.name = "Visual"
	s.set_script(load("res://scripts/mini_saucer.gd"))
	s.set("pilot", (load("res://models/characters/little_alien_%s.glb" % saucer.colour) as PackedScene).instantiate())
	s.scale = Vector3.ONE * 4.0
	add_child(s)
	s.set_physics_process(false)                 # flown along the line from here, not wandering about
	var tag := Label3D.new()
	tag.text = str(saucer.name)
	tag.font_size = 64
	tag.pixel_size = 0.02
	tag.outline_size = 14
	tag.modulate = Color(1, 0.95, 0.75)
	tag.outline_modulate = Color(0.15, 0.08, 0.2)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = 5.0
	add_child(tag)
	_place()


func display_name() -> String:
	if not saucer.is_empty():
		return str(saucer.name)
	return _name if _name != "" else str(Races.ride_of(id).rider)


func _townsfolk_of(who: String) -> Node3D:
	# The Earth kid in town with this id (the townsfolk's Routine carries it: tools/build_earth.gd _person)
	var scene := get_tree().current_scene
	if scene == null or not Races.TOWNSFOLK_RIDES.has(who):
		return null
	for r in scene.find_children("Routine", "", true, false):
		if r.get("character_id") == who and r.get_parent() is Townsfolk:
			return r.get_parent() as Node3D
	return null


func _townsfolk_copy() -> Townsfolk:
	# On Earth the friends racing are people: a copy of their Earth self from town (scripts/townsfolk.gd), with the
	# things they carry round town left at home (their board is under their feet now, and a book won't help). On a
	# circuit there's no town: Races copied their looks on the way out (Races.kid_look()).
	if not Races.TOWNSFOLK_RIDES.has(id):
		return null
	var them := _townsfolk_of(id) as Townsfolk
	var kid := Townsfolk.new()
	if them == null:
		var k := Races.kid_look(id)
		kid.look = k.look
		kid.outfit = k.outfit
		if str(k.model_path) != "":
			kid.model_path = k.model_path
		kid.extras = (k.extras as Array).filter(func(e: Dictionary) -> bool: return not str(e.get("kind", "")) in ["skateboard", "book", "clipboard", "guitar"])
		return kid
	kid.look = them.look
	kid.outfit = them.outfit
	kid.model_path = them.model_path
	kid.extras = them.extras.filter(func(e: Dictionary) -> bool: return not str(e.get("kind", "")) in ["skateboard", "book", "clipboard", "guitar"])
	return kid


func go() -> void:
	_running = 0.001


func boost(seconds: float) -> void:
	_boost = maxf(_boost, seconds)
	_slow = 0.0


func stunned() -> bool:
	return _stun > 0.0


func shielded() -> bool:
	return _shield > 0.0


func hit(seconds: float) -> bool:
	# Knocked by a Bubble Seeker, a Zap Ring, a sweeper or a zapper: a spin and a moment of slow going. A shield takes
	# it instead (and pops). Says whether it got them.
	if _shield > 0.0:
		_shield = 0.0
		_pop_bubble()
		say("Phew!")
		return false
	if _stun > 0.0:
		return false
	_stun = seconds
	_boost = 0.0
	say(["Whoa!", "Hey!", "Oof!", "Nooo!", "Bonk!"][randi() % 5])
	return true


func slow_down(seconds: float) -> void:
	if _shield > 0.0 or _boost > 0.0:
		return
	if _slow <= 0.0:
		say("Gloopy!")
	_slow = maxf(_slow, seconds)


func bumped(out: Vector3) -> bool:
	# A bumper they didn't steer round: thrown aside into the next lane, a little slower
	if _stun > 0.0 or _hop > 0.0:
		return false
	var side := track.side_at(d)
	lane += signf(out.dot(side)) * 1.5 if absf(out.dot(side)) > 0.1 else 1.5
	lane_goal = lane
	speed *= 0.7
	say("Boing!")
	return true


func hop() -> void:
	if _hop <= 0.0:
		_hop = 0.001


func shield_up(seconds: float) -> void:
	_shield = seconds
	if _bubble == null and saucer.is_empty():
		_bubble = MeshInstance3D.new()
		_bubble.name = "Bubble Shield"
		var s := SphereMesh.new()
		s.radius = 1.2
		s.height = 2.4
		(_bubble as MeshInstance3D).mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.9, 1.0, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = Color(0.6, 0.9, 1.0)
		m.emission_energy_multiplier = 0.6
		m.rim_enabled = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		(_bubble as MeshInstance3D).material_override = m
		_bubble.position.y = 1.0
		add_child(_bubble)
	say("Shield up!")


func _pop_bubble() -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func say(text: String) -> void:
	if _say == null:
		return
	_say.text = text
	_say.visible = true
	_say_time = 1.2


func race(delta: float, player_progress: float) -> void:
	# One step of riding. player_progress is how far round the player is (all laps), to know whether to ease off.
	if _running <= 0.0:
		return
	_t += delta
	_running += delta
	_boost -= delta
	var base := float(_ride.push_speed) * skill
	var ahead := d - player_progress
	if finished:
		base *= 0.55                                  # a slow lap of honour past the line
	elif ahead > 0.0:
		base *= 1.0 - EASE_OFF * clampf(ahead / GAP, 0.0, 1.0)
	else:
		base *= 1.0 + CATCH_UP * clampf(-ahead / GAP, 0.0, 1.0)
	if _boost > 0.0:
		base += 6.0 if saucer.is_empty() else 12.0
	base *= clampf(_running / START_TIME, 0.15, 1.0)
	# Knocked about: spinning round slows right down, goo halves it
	_stun -= delta
	_slow -= delta
	_shield -= delta
	if _shield <= 0.0 and _bubble:
		_pop_bubble()
	if _say_time > 0.0 and _say:
		_say_time -= delta
		_say.visible = _say_time > 0.0
	if _stun > 0.0:
		base *= 0.15
	elif _slow > 0.0:
		base *= 0.5
	speed = move_toward(speed, base, (14.0 if _boost > 0.0 or _stun > 0.0 else (5.0 if saucer.is_empty() else 10.0)) * delta)
	d += speed * delta
	var wide := 2.4 if saucer.is_empty() else 14.0
	if saucer.is_empty() and track.width > 0.0:
		wide = track.width / 2.0 - 1.2
	if saucer.is_empty():
		# Steering for their lane (scripts/race_attacks.gd picks it clear of trouble), with a little wander
		lane_goal = clampf(lane_goal + sin(_t * 0.37) * 0.25 * delta, -wide, wide)
		lane = move_toward(lane, lane_goal, 3.5 * delta)
	else:
		lane = clampf(lane + sin(_t * 0.37) * 0.25 * delta * 4.0, -wide, wide)    # drifting about their lane a little
	lane = clampf(lane, -wide, wide)
	if _hop > 0.0:
		_hop += delta / 0.8
		if _hop >= 1.0:
			_hop = 0.0
	_place()


func _place() -> void:
	if track == null or track.length <= 0.0:
		return
	var f := track.dir_at(d)
	var at := track.point_at(d) + track.side_at(d) * lane
	at.y = track.point_at(d).y + (sin(_t * 0.8) * 2.0 if not saucer.is_empty() else 0.0)
	global_position = at
	var want := Basis.looking_at(-f, Vector3.UP)
	global_basis = want if speed < 0.5 else global_basis.slerp(want, 0.25).orthonormalized()
	# A little lean into the bends, and a bob on the bumps
	var ahead := track.dir_at(d + 4.0)
	var turn := f.signed_angle_to(ahead, Vector3.UP)
	var visual := get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.z = clampf(-turn * 1.2, -0.35, 0.35) * clampf(speed / 8.0, 0.0, 1.0)
		if saucer.is_empty():
			visual.position.y = absf(sin(_t * 7.0)) * 0.03 * clampf(speed / 8.0, 0.0, 1.0) + sin(_hop * PI) * 2.2
			visual.rotation.y = TAU * clampf(_stun / 1.6, 0.0, 1.0) * 2.0 if _stun > 0.0 else 0.0
