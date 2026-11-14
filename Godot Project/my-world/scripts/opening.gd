extends Node

# The first minutes of a new game, shown with little cutscenes instead of pop-up messages (Hayden's 12 Nov 2026
# playtest: "There need to be more cutscenes in the beginning to guide the player, and way less popups. maybe a
# movement tutorial"). A node "Opening" under the FirstNight autoload (scripts/first_night.gd); dialogue and tools
# reach it as FirstNight.opening.
#
#   wake    the hero's made: a look over Stars Hollow on a sunny morning, the old oak, home, then a knock at the door
#           (replaces "Welcome to Stars Hollow!", "Knock knock!..." and the four how-to tips)
#   tutorial  the movement tutorial in the house (scripts/move_tutorial.gd), ending at the front door
#   nina    out of the door: the camera finds Nina on the green, waving
#   Then a short "where to go" shot each time The First Night moves on to a new step, so the player is shown where to
#   go instead of reading it (GUIDES): Mr. Palmer and the green, the notice board, home in the evening, and in the
#   Void the Skate Park where Rex is.
#
# Everything is skippable (Jump, Interact or Accept: scripts/place_intro.gd) and plays once (flags "opening_wake",
# "guide_<id>"). Nothing here gives away what's coming (Hayden's no-spoilers rule): the shots only show where things
# are, and the words only say what the quest already says. Headless runs (the tests) skip the cutscenes themselves
# (their "after" still happens) unless `force` is set.

const PlaceIntro := preload("res://scripts/place_intro.gd")
const MoveTutorial := preload("res://scripts/move_tutorial.gd")
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const WAKE_FLAG := "opening_wake"
const BASICS := ["move", "jump", "map", "pause", "talk"]     # tips the opening shows another way (scripts/tips.gd)
# A guide for a First Night step: where it plays ("earth" / "void"), and what it waits for besides its step
const GUIDES := {
	"nina": {"world": "earth", "step": "morning", "unless": "fn_nina"},
	"green": {"world": "earth", "step": "morning", "flag": "fn_nina"},
	"board": {"world": "earth", "step": "board"},
	"evening": {"world": "earth", "step": "evening"},
	"skate_park": {"world": "void", "step": "day", "flag": "fn_met_tally"},
}
# Places on Stars Hollow's ground, [x, z] (routines/earth_places.json, quests/first_night.json)
const GAZEBO := Vector2(0.0, 8.0)
const OAK := Vector2(-5.5, 14.5)
const BOARD := Vector2(-3.7, 6.6)
const MY_HOME := Vector2(0.0, 31.6)
const SKATE_PARK := Vector2(50.0, 58.0)

var cut: CanvasLayer                  # the cutscene player (scripts/place_intro.gd)
var tutorial: CanvasLayer             # scripts/move_tutorial.gd
var force := false                    # tests: play the cutscenes even in a headless run
var _waking := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	cut = PlaceIntro.new()
	cut.name = "Opening Cutscene"
	add_child(cut)
	tutorial = MoveTutorial.new()
	tutorial.name = "Move Tutorial"
	add_child(tutorial)
	tutorial.finished.connect(_on_tutorial_done)


func headless() -> bool:
	return DisplayServer.get_name() == "headless" and not force


func playing() -> bool:
	return cut.playing() or _waking


# -----------------------------------------------------------------------------
# Waking up
# -----------------------------------------------------------------------------
func wake() -> void:
	# A new game's hero is made (FirstNight._on_creator_closed, at 9 AM): the morning, then the knock
	Dialogue.set_flag(WAKE_FLAG)
	for t in BASICS:
		Dialogue.set_flag("tip_" + t)              # (said by the cutscenes and the tutorial instead)
	var player := _player()
	var home := _home()
	if headless() or player == null or home == null:
		_knock()
		_start_tutorial()
		return
	_waking = true
	cut.done.connect(func() -> void:
		_waking = false
		_start_tutorial(), CONNECT_ONE_SHOT)
	cut.play(wake_shots(player, home))


func wake_shots(player: Node3D, home: Node3D) -> Array:
	var g := _at(GAZEBO)
	var oak := _at(OAK)
	var front := home.global_basis.z.normalized()               # the house's front, where the door is
	var door := home.global_position + front * 4.5
	var mid := player.global_position.lerp(door, 0.35) + Vector3.UP * 0.9
	# Inside, from the back corner past the bed: the hero in the middle, the doorway behind them
	var corner := home.global_transform * Vector3(2.9, 2.6, -3.4)
	var corner_in := home.global_transform * Vector3(2.2, 2.2, -2.4)
	return [
		{"start": g + Vector3(34, 34, -46), "start_look": g, "from": g + Vector3(-6, 24, -34), "look": g, "time": 5.0,
			"title": "Stars Hollow", "caption": "A sleepy little town..."},
		{"from": oak + ((g - oak) * Vector3(1, 0, 1)).normalized() * 10.0 + Vector3.UP * 3.0, "look": oak + Vector3.UP * 4.0, "time": 3.6,
			"title": "", "caption": "...mostly."},
		{"from": door + front * 6.0 + home.global_basis.x * 3.0 + Vector3.UP * 1.9, "look": door + Vector3.UP * 2.0, "time": 3.6,
			"title": "", "caption": "Home sweet home."},
		{"start": corner, "start_look": mid, "from": corner_in, "look": mid, "time": 3.4, "sound": "door",
			"title": "", "caption": "Knock knock!"},
	]


func _knock() -> void:
	Audio.play("door", -2.0, 0.0)
	get_tree().create_timer(0.45, false).timeout.connect(func() -> void: Audio.play("door", -2.0, 0.0))


func _start_tutorial() -> void:
	var player := _player()
	if player == null:
		return
	tutorial.start(player, _home())
	if not tutorial.running():
		_on_tutorial_done()


func _on_tutorial_done() -> void:
	guide_soon("nina")


# -----------------------------------------------------------------------------
# Where-to-go shots, as the First Night moves on
# -----------------------------------------------------------------------------
var _due: Array[String] = []


func guide_soon(id: String) -> void:
	if GUIDES.has(id) and not Dialogue.flags.has("guide_" + id) and not id in _due:
		_due.append(id)


func due() -> Array[String]:
	return _due


func check() -> void:
	# The First Night's step changed (or a flag it waits on): queue that step's guide
	for id in GUIDES:
		var g: Dictionary = GUIDES[id]
		if FirstNight.step() != str(g.step):
			continue
		if g.has("flag") and not Dialogue.flags.has(str(g.flag)):
			continue
		if g.has("unless") and Dialogue.flags.has(str(g.unless)):
			continue
		if id == "nina" and not Dialogue.flags.has(MoveTutorial.DONE_FLAG):
			continue                                # (it comes when they step out of the door)
		guide_soon(id)


func _process(_delta: float) -> void:
	if _due.is_empty() or cut.playing() or _waking:
		return
	if not FirstNight.running() or Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or get_tree().paused:
		return
	if not get_tree().get_nodes_in_group("cutscene_playing").is_empty() or FirstNight.is_arriving():
		return
	var id: String = _due[0]
	var g: Dictionary = GUIDES[id]
	if FirstNight.step() != str(g.step) or (g.has("unless") and Dialogue.flags.has(str(g.unless))):
		_due.pop_front()                            # (moved on before it could play)
		return
	if not _in_world(str(g.world)):
		return                                      # waits till they're there
	_due.pop_front()
	play_guide(id)


func play_guide(id: String) -> void:
	Dialogue.set_flag("guide_" + id)
	if headless():
		return
	var shots := guide_shots(id)
	if not shots.is_empty():
		cut.play(shots)


func guide_shots(id: String) -> Array:
	var player := _player()
	if player == null:
		return []
	var p := player.global_position
	match id:
		"nina":
			var nina := _who("nina_earth", p + Vector3(0, 0, 8))
			return [_look_at(p, nina, "", "Nina! Say hi with {interact}.", 4.5)]
		"green":
			var palmer := _who("palmer_earth", _at(GAZEBO))
			return [_look_at(p, palmer, "", "Say hi to Mr. Palmer...", 3.6),
				{"from": _at(GAZEBO) + Vector3(14, 12, 18), "look": _at(GAZEBO), "time": 3.6, "title": "",
					"caption": "...and two more friends!"}]
		"board":
			return [_close_up(_at(BOARD), "The Notice Board", "Jobs for sparkles!", 4.5, 6.0, 1.6)]
		"evening":
			return [_close_up(_at(MY_HOME), "Home", "Bedtime soon!", 4.5, 12.0, 2.0)]
		"skate_park":
			return [_close_up(_at(SKATE_PARK), "The Skate Park", "Rex is waiting!", 4.5, 16.0, 6.0)]
	return []


func _look_at(from_pos: Vector3, at: Vector3, title: String, caption: String, time: float) -> Dictionary:
	# Someone, seen from a few metres in front of them, on the player's side (so nothing's in between)
	var to := (from_pos - at) * Vector3(1, 0, 1)
	var dir := to.normalized() if to.length() > 0.1 else Vector3.BACK
	var side := dir.cross(Vector3.UP) * 1.2
	return {"from": at + dir * minf(4.5, maxf(to.length() - 0.5, 2.5)) + side + Vector3.UP * 2.2,
		"look": at + Vector3.UP * 1.1, "time": time, "title": title, "caption": caption}


func _close_up(at: Vector3, title: String, caption: String, time: float, dist := 7.0, up := 2.5) -> Dictionary:
	# A slow swing in on a place, from the side the player's on
	var player := _player()
	var side := ((player.global_position - at) * Vector3(1, 0, 1)) if player else Vector3.BACK
	side = side.normalized() if side.length() > 0.5 else Vector3.BACK
	return {"from": at + side * dist + Vector3.UP * (up + 2.0), "look": at + Vector3.UP * up, "time": time,
		"title": title, "caption": caption}


# -----------------------------------------------------------------------------
# Where things are
# -----------------------------------------------------------------------------
func _in_world(w: String) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return scene.scene_file_path == (EARTH if w == "earth" else TOWN)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _home() -> Node3D:
	var scene := get_tree().current_scene
	var spawn := scene.find_child("HomeSpawn", true, false) if scene else null
	return spawn.get_parent() as Node3D if spawn else null


func _who(id: String, fallback: Vector3) -> Vector3:
	var scene := get_tree().current_scene
	if scene:
		for t in scene.find_children("Talk", "Area3D", true, false):
			if t.get("character_id") == id:
				return (t.get_parent() as Node3D).global_position
	return fallback


func _at(xz: Vector2) -> Vector3:
	# A spot on the ground: rays down find its height (the lowest thing there, so not a roof or the board's top; the
	# player's height if nothing's there)
	var player := _player()
	var y := player.global_position.y if player else 0.0
	var w := player.get_world_3d() if player else null
	if w:
		var skip: Array[RID] = []
		if player is CollisionObject3D:
			skip.append(player.get_rid())
		for i in 8:
			var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 200.0, xz.y), Vector3(xz.x, -50.0, xz.y))
			q.exclude = skip
			var hit := w.direct_space_state.intersect_ray(q)
			if hit.is_empty():
				break
			y = hit.position.y
			skip.append(hit.rid)
	return Vector3(xz.x, y, xz.y)
