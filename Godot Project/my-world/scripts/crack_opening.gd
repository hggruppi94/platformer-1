extends Node

# A cutscene for every crack that opens (Hayden, 14 Nov 2026: "We need to make it more obvious when a crack opens up,
# with a cutscene for each one"). A node "Crack Opening" under the Portals autoload (scripts/portals.gd); reach it as
# Portals.opening_cut.
#
#   quake(id)  A time quake opens a portal world's crack in the Void. The ground shakes under the player, then the
#              camera flies over to where it's happening and watches the ground split open, a pillar of the world's
#              light shoots up into the sky, something of that world spills out of it (snowflakes for the Frozen
#              Moment, bubbles for the Tide Reef, a beat for Rhythm Springs...), the camera looks down it at the world
#              swirling at the bottom, and pulls back to show where it is, with the world's name.
#   earth()    The first time the crack by the old oak opens in Stars Hollow (the second Shift on: the first night you
#              fall wherever you are, scripts/void_arrival.gd). The oak hums and the green splits open in front of it.
#
# Every shot is skippable (Jump, Interact or Accept: scripts/place_intro.gd), and skipping still leaves the crack open.
# Nothing here looks ahead (Hayden's no-spoilers rule): the words only say what's happening right now and what you can
# see down the crack; no bosses, no reasons why. Headless runs (the tests) don't play them (the old quick quake happens
# instead) unless `force` is set.

const PlaceIntro := preload("res://scripts/place_intro.gd")
const EARTH_FLAG := "cut_crack_earth"

# What spills out of each world's crack, and what you see down it. "bits": colour of the little things that come out,
# "rise": how they move (up and floating, down and falling...), "sound": as it splits open, "look": the caption
# looking down it.
const WORLDS := {
	"shard_isle": {"bits": Color(0.8, 1.0, 0.95), "rise": 3.0, "float": -1.5, "sound": "level_up",
		"look": "Way down at the bottom, crystals are glinting... and humming, a little out of tune."},
	"rootmind": {"bits": Color(0.35, 0.75, 0.25), "rise": 2.5, "float": -2.0, "sound": "rustle",
		"look": "Roots are wriggling down there... and something blinks back up at you!"},
	"frozen_moment": {"bits": Color(0.95, 0.98, 1.0), "rise": 1.6, "float": 0.0, "sound": "frost",
		"look": "An icy wind blows up out of it. Snowflakes hang in the air, not moving at all."},
	"lanternmoor": {"bits": Color(1.0, 0.82, 0.4), "rise": 1.4, "float": 0.6, "sound": "faint",
		"look": "It's dark as night down there, and little lights are bobbing about. Moths?"},
	"glenmoor": {"bits": Color(1.0, 0.7, 0.85), "rise": 3.2, "float": -1.2, "sound": "rustle",
		"look": "Petals, raindrops, sunshine and snow all whirl up out of it at once!"},
	"tide_reef": {"bits": Color(0.75, 0.95, 1.0), "rise": 2.0, "float": 1.4, "sound": "bubbles",
		"look": "It smells like the seaside down there... but where's all the water gone?"},
	"rhythm_springs": {"bits": Color(1.0, 0.55, 0.9), "rise": 3.5, "float": -2.5, "sound": "boing", "beat": true,
		"look": "A beat thumps up out of it, boom, boom... then it stumbles, and stops."},
	"far_future": {"bits": Color(0.5, 1.0, 1.0), "rise": 5.0, "float": -4.0, "sound": "beam",
		"look": "Far, far below, neon lights flicker, like a whole city... fading in and out."},
}

# Where it is, said in the cutscene where the quake's own words say too much (they're kept as they are elsewhere)
const PLACES := {"far_future": "the hedge behind Rex and Dash's lab"}

var cut: CanvasLayer                  # the cutscene player (scripts/place_intro.gd)
var force := false                    # tests and capture tools: play them even in a headless run
var showing := ""                     # the world whose crack is in the cutscene ("earth" for the oak's), "" otherwise
var _opened := false
var _then := Callable()
var _occluders: Array = []            # trees in the way of a camera: [where (x, z), how wide, how tall]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cut = PlaceIntro.new()
	cut.name = "Crack Cutscene"
	add_child(cut)
	cut.done.connect(_on_done)


func headless() -> bool:
	return DisplayServer.get_name() == "headless" and not force


func playing() -> bool:
	return cut.playing()


func can_play() -> bool:
	# Nothing else is on: no talking, menus, other cutscenes or a race
	var tree := get_tree()
	if tree.paused or cut.playing() or Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open():
		return false
	if not tree.get_nodes_in_group("cutscene_playing").is_empty() or FirstNight.is_arriving() or Races.racing():
		return false
	return tree.get_first_node_in_group("player") != null


# -----------------------------------------------------------------------------
# A portal world's crack in the Void
# -----------------------------------------------------------------------------
func quake(id: String, open_it: Callable, then: Callable) -> bool:
	# Plays the quake's cutscene: open_it() splits the crack open on cue, then() when it's over (skipped or not).
	# False if it can't play (headless): the caller does its own quick quake.
	if headless():
		return false
	var shots := quake_shots(id, open_it)
	if shots.is_empty():
		return false
	showing = id
	_opened = false
	_then = then
	cut.play(shots)
	return true


func quake_shots(id: String, open_it: Callable = Callable()) -> Array:
	var w := Portals.world(id)
	var player := _player()
	if w.is_empty() or player == null:
		return []
	var at := Remnants.ground_at(w.at)
	_gather()
	var yaw := float(w.yaw)
	var side := Vector3(sin(yaw), 0, cos(yaw))          # the crack's z side: it runs left to right across the shot
	var across := Vector3(cos(yaw), 0, -sin(yaw))
	var turn := _best_turn(at, side * 10.0 + across * 2.5 + Vector3.UP * 6.5)
	side = side.rotated(Vector3.UP, turn)
	across = across.rotated(Vector3.UP, turn)
	var theme: Dictionary = WORLDS.get(id, {})
	var p := player.global_position
	var colour: Color = w.colour
	var shots: Array = []
	# 1. Where you are: everything shakes
	var back := (p - at) * Vector3(1, 0, 1)
	back = back.normalized() if back.length() > 0.5 else side
	shots.append({"from": p + back * 4.5 + Vector3.UP * 3.0, "look": p + Vector3.UP * 1.0, "time": 2.4,
		"title": "A Time Quake!", "caption": "The ground's shaking! Something's cracking open...", "shake": 0.7,
		"sound": "stomp"})
	# 2. Over there: high up, swinging in as the ground splits
	var high := _clear(at, at + side * 22.0 + across * 6.0 + Vector3.UP * 15.0)
	var mid := _clear(at, at + side * 10.0 + across * 2.5 + Vector3.UP * 6.5)
	shots.append({"start": high, "start_look": at, "from": mid, "look": at + Vector3.UP * 0.5, "time": 3.6,
		"title": "", "caption": "Over by %s, the ground splits wide open!" % str(PLACES.get(id, Portals.near_words(id))), "shake": 0.4,
		"call": _split.bind(id, open_it)})
	# 3. Looking down it: the world it leads to, swirling at the bottom
	shots.append({"from": _clear(at, at + side * 2.2 + Vector3.UP * 4.4), "look": at + Vector3.DOWN * 3.0, "time": 3.8,
		"title": "", "caption": str(theme.get("look", "Something glows, far down at the bottom...")),
		"call": _look_down.bind(id)})
	# 4. Pulling back, to see where it is
	shots.append({"from": _clear(at, at + side * 12.0 - across * 7.0 + Vector3.UP * 7.0), "look": at, "time": 3.4,
		"title": str(w.name), "caption": "A new crack! Jump in when you're ready."})
	return shots


func _split(id: String, open_it: Callable) -> void:
	# The crack splits open, right on cue, with its light shooting up and its world spilling out
	_opened = true
	if open_it.is_valid():
		open_it.call()
	var g := Portals.crack(id)
	if g == null:
		return
	var w := Portals.world(id)
	var theme: Dictionary = WORLDS.get(id, {})
	var at := g.global_position
	Audio.play(str(theme.get("sound", "beam")), -3.0, 0.05)
	_pillar(g.get_parent(), at, w.colour)
	var tw := g.create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(_spill.bind(g, at, theme, w.colour))
	if theme.get("beat", false):
		for i in 3:                                  # boom... boom... boom (and then it stumbles)
			tw.tween_interval(0.42 if i < 2 else 0.7)
			tw.tween_callback(func() -> void:
				Juice.shake(0.15)
				Audio.play("stomp", -10.0, 0.0)
				Fx.burst(g, at + Vector3.UP * 0.6, w.colour, 14, 0.12, 4.0, -3.0, 0.7))


func _spill(g: Node3D, at: Vector3, theme: Dictionary, colour: Color) -> void:
	if not is_instance_valid(g):
		return
	var bits: Color = theme.get("bits", colour)
	var rise := float(theme.get("rise", 3.0))
	var fl := float(theme.get("float", -2.0))
	Fx.burst(g, at + Vector3.UP * 0.4, bits, 40, 0.1, rise, fl, 2.6, 35.0)
	Fx.burst(g, at + Vector3.UP * 0.4, colour, 24, 0.08, rise * 0.7, fl, 2.0, 50.0)


func _look_down(id: String) -> void:
	var g := Portals.crack(id)
	if g:
		Portals.show_preview(id)                     # the live window into the world, down at the bottom
		Fx.burst(g, g.global_position + Vector3.UP * 0.3, WORLDS.get(id, {}).get("bits", Portals.world(id).colour),
			18, 0.08, 2.0, -0.5, 2.2, 30.0)


static func _pillar(parent: Node, at: Vector3, colour: Color) -> void:
	# A tall beam of the world's light, shooting up out of the crack and fading away: you can see it from anywhere
	if parent == null or not parent.is_inside_tree():
		return
	var beam := MeshInstance3D.new()
	beam.name = "Crack Pillar"
	var m := CylinderMesh.new()
	m.top_radius = 1.4
	m.bottom_radius = 0.8
	m.height = 60.0
	m.radial_segments = 16
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	beam.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bright := colour.lerp(Color.WHITE, 0.35)
	mat.albedo_color = Color(bright.r, bright.g, bright.b, 0.0)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(beam)
	beam.global_position = at + Vector3.UP * 30.0
	beam.scale = Vector3(0.2, 0.05, 0.2)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.omni_range = 18.0
	light.light_energy = 0.0
	beam.add_child(light)
	light.position = Vector3(0, -28.0, 0)
	var tw := beam.create_tween()
	tw.set_parallel(true)
	tw.tween_property(beam, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.8, 0.5)
	tw.tween_property(light, "light_energy", 6.0, 0.5)
	tw.chain().tween_interval(2.8)
	tw.chain().set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, 2.2)
	tw.tween_property(beam, "scale", Vector3(0.3, 1.0, 0.3), 2.2)
	tw.tween_property(light, "light_energy", 0.0, 2.2)
	tw.chain().tween_callback(beam.queue_free)


# -----------------------------------------------------------------------------
# The crack by the old oak, on Earth
# -----------------------------------------------------------------------------
func earth_due() -> bool:
	# The first Shift the oak's crack opens with you there, once you've been to the Void (the first night you fell
	# wherever you stood instead)
	return not Dialogue.flags.has(EARTH_FLAG) and Dialogue.flags.has("fn_arrived") and not headless()


func earth(world: Node3D, crack: Node3D, open_it: Callable) -> bool:
	# open_it(): splits the crack open from shut, on cue. Sets the flag, so it only ever plays once.
	if not earth_due() or crack == null or not can_play():
		return false
	var shots := earth_shots(crack, open_it)
	if shots.is_empty():
		return false
	Dialogue.set_flag(EARTH_FLAG)
	showing = "earth"
	_opened = false
	_then = func(opened: bool) -> void:
		if not opened and open_it.is_valid():
			open_it.call()
	cut.play(shots)
	return true


func earth_shots(crack: Node3D, open_it: Callable = Callable()) -> Array:
	var player := _player()
	if player == null or crack == null:
		return []
	var at := crack.global_position
	var side := crack.global_basis.z * Vector3(1, 0, 1)
	side = side.normalized() if side.length() > 0.1 else Vector3.BACK
	var across := crack.global_basis.x * Vector3(1, 0, 1)
	across = across.normalized() if across.length() > 0.1 else Vector3.RIGHT
	var oak := at - side * 2.9                          # (the crack's 2.9 m out in front of the oak)
	_gather()
	var p := player.global_position
	var back := (p - at) * Vector3(1, 0, 1)
	back = back.normalized() if back.length() > 0.5 else side
	return [
		{"from": p + back * 4.5 + Vector3.UP * 3.0, "look": p + Vector3.UP * 1.0, "time": 2.2, "title": "Midnight",
			"caption": "The whole town goes quiet... and the old oak starts to hum.", "sound": "faint", "shake": 0.25},
		{"start": _clear(at, at + side * 16.0 + across * 5.0 + Vector3.UP * 9.0), "start_look": oak + Vector3.UP * 3.0,
			"from": _clear(at, at + side * 8.0 + across * 2.0 + Vector3.UP * 4.5), "look": at + Vector3.UP * 0.5,
			"time": 3.8, "title": "", "caption": "The ground in front of it splits wide open!", "shake": 0.45,
			"call": func() -> void:
				_opened = true
				if open_it.is_valid():
					open_it.call()
				Audio.play("stomp", -4.0, 0.0)
				_pillar(crack.get_parent(), at, Color(0.7, 0.5, 1.0))},
		{"from": at + side * 3.0 + Vector3.UP * 4.4, "look": at + Vector3.DOWN * 2.0, "time": 3.6, "title": "",
			"caption": "Far down at the bottom, a light swirls... just like the night you fell."},
		{"from": _clear(at, at + side * 11.0 - across * 6.0 + Vector3.UP * 6.0), "look": oak + Vector3.UP * 2.0,
			"time": 3.2, "title": "The Crack by the Old Oak", "caption": "It's open till 1 AM. Jump in when you're ready."},
	]


# -----------------------------------------------------------------------------
func _on_done() -> void:
	var id := showing
	showing = ""
	if id != "" and id != "earth":
		Portals.hide_preview_if_far(id)
	var then := _then
	_then = Callable()
	if then.is_valid():
		then.call(_opened)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _clear(target: Vector3, from: Vector3) -> Vector3:
	# A camera spot that can see the target: if a building, a hill or a tree is in the way, go up higher till it isn't
	var spot := from
	for i in 6:
		if not _blocked(target, spot):
			return spot
		spot += Vector3.UP * 4.0
	return spot


func _best_turn(at: Vector3, offset: Vector3) -> float:
	# Which way round the crack to look from: straight on if nothing's in the way, else the nearest way round that's clear
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2, 1.9, -1.9, PI]:
		if not _blocked(at, at + offset.rotated(Vector3.UP, turn)):
			return turn
	return 0.0


func _blocked(target: Vector3, spot: Vector3) -> bool:
	var w := _player().get_world_3d() if _player() else null
	if w:
		var q := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 1.0, spot)
		q.collide_with_areas = false
		var player := _player() as CollisionObject3D
		if player:
			q.exclude = [player.get_rid()]
		if not w.direct_space_state.intersect_ray(q).is_empty():
			return true
	# Trees aren't solid, so the ray can't see them: check them by where they stand
	for i in range(1, 13):
		var p := target.lerp(spot, i / 12.0)
		for o in _occluders:
			if p.y < float(o[2]) and Vector2(p.x, p.z).distance_to(o[0]) < float(o[1]):
				return true
	return false


func _gather() -> void:
	# The trees round about (scenes/town/trees.gd): where each stands, how wide and how tall
	_occluders.clear()
	var scene := get_tree().current_scene
	var trees := scene.find_child("Trees", true, false) as Node3D if scene else null
	if trees == null or not "positions" in trees:
		return
	var sizes: PackedFloat32Array = trees.get("sizes") if "sizes" in trees else PackedFloat32Array()
	var spots: PackedVector3Array = trees.get("positions")
	for i in spots.size():
		var g := trees.global_transform * spots[i]
		var k := sizes[i] if i < sizes.size() else 1.0
		_occluders.append([Vector2(g.x, g.z), 1.3 * k + 0.5, g.y + 3.0 + 2.8 * k])
