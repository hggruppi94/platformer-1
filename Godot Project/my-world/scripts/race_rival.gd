class_name RaceRival
extends Node3D

# A friend racing against you (scripts/races.gd): Dash on his BMX, Rex on his paw skates, Bramble on her scooter and
# so on, each on their own ride from scripts/rides.gd. They follow the track's racing line (scripts/race_track.gd),
# each in a lane of their own that drifts a little, at a speed that suits their ride. They're good sports: when
# they're far ahead they ease off, and when they're far behind they pedal harder, so a race is close and
# anyone can win it with a clean run. Boost pads work for them too. They don't bump into anything: they ride
# through each other and the player, so nobody gets knocked off.
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
var saucer := {}                     # a sky racer: {"name", "colour"} (a little alien in a mini saucer)
var _name := ""                      # an Earth kid's name (from the townsfolk they're copied from)


func setup(who: String, t: RaceTrack, start_d: float, start_lane: float, how_good: float) -> void:
	id = who
	track = t
	d = start_d
	lane = start_lane
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
		_name = str(_townsfolk_of(id).name)
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
	# things they carry round town left at home (their board is under their feet now, and a book won't help)
	var them := _townsfolk_of(id) as Townsfolk
	if them == null:
		return null
	var kid := Townsfolk.new()
	kid.look = them.look
	kid.outfit = them.outfit
	kid.model_path = them.model_path
	kid.extras = them.extras.filter(func(e: Dictionary) -> bool: return not str(e.get("kind", "")) in ["skateboard", "book", "clipboard", "guitar"])
	return kid


func go() -> void:
	_running = 0.001


func boost(seconds: float) -> void:
	_boost = maxf(_boost, seconds)


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
	speed = move_toward(speed, base, (14.0 if _boost > 0.0 else (5.0 if saucer.is_empty() else 10.0)) * delta)
	d += speed * delta
	var wide := 2.4 if saucer.is_empty() else 14.0
	lane = clampf(lane + sin(_t * 0.37) * 0.25 * delta * (1.0 if saucer.is_empty() else 4.0), -wide, wide)    # drifting about their lane a little
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
			visual.position.y = absf(sin(_t * 7.0)) * 0.03 * clampf(speed / 8.0, 0.0, 1.0)
