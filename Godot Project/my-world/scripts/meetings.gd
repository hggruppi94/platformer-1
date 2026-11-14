extends Node

# Who you meet, and in what order (Hayden's day 1 playtest, 11 Nov 2026, and the order he chose: "I don't want to lock
# meeting people behind days spent in-game. Their days go about normally until you are directed to them by other
# characters or game progression, but it should not be a mystery of who to talk to next"). The node is "Meetings"
# under the FirstNight autoload, so dialogue reaches it as "FirstNight/Meetings.<method>" and no new autoload was
# needed.
#
# The story quests follow on from each other as soon as the one before is done (never "come back tomorrow night"),
# and each one starts with someone sending you to the next friend:
#
#   first_night   Earth, Nina, Mr. Palmer, the notice board; then the Void: Tally, then Rex and the skate lesson
#   bike_boy      Rex sends you after his twin: Dash's tyre tracks, his lab, his runaway Buzz Bot, his stall, the
#                 Gloop King (res://quests/bike_boy.json)
#   night_2       Dash sends you to Pip
#   night_3       Pip sends you to Bramble
#   meet_friends  Bramble sends you to Melody, Melody to Heather (res://quests/meet_friends.json)
#   night_4       ...and they send you back to Dash, at the Observatory
#   night_5       Dash sends you to the Astronaut
#   night_6       the Astronaut sends you to Rex, for his campaign
#   night_7       Rex sends you to Mr. Palmer
#
# The night quests keep their ids (night_<n>) so saves and the tests keep working, but they no longer wait for a new
# visit to the Void. The Bike Boy's things (the glowing tyre tracks, the three bits Dash dropped and the Buzz Bot) are
# put into the town at play time, only while that step wants them, like the lab's ripples (scripts/lab.gd).

const TOWN := "res://scenes/town/town.tscn"
const KINETIC := preload("res://scripts/kinetic.gd")
const QUEST := "bike_boy"
const CHAIN := [
	{"quest": "bike_boy", "flag": "bike_boy_start", "after": "first_night"},
	{"quest": "night_2", "flag": "night_2", "after": "bike_boy"},
	{"quest": "night_3", "flag": "night_3", "after": "night_2"},
	{"quest": "meet_friends", "flag": "meet_friends_start", "after": "night_3"},
	{"quest": "night_4", "flag": "night_4", "after": "meet_friends"},
	{"quest": "night_5", "flag": "night_5", "after": "night_4"},
	{"quest": "night_6", "flag": "night_6", "after": "night_5"},
	{"quest": "night_7", "flag": "night_7", "after": "night_6"},
]
# The way Dash went: from the Skate Park, past the gate to the houses, past his house, to the lab (x, z)
const TRACK := [Vector2(44.0, 50.0), Vector2(50.0, 26.0), Vector2(52.5, 3.5), Vector2(70.0, -2.0),
	Vector2(84.0, -6.0), Vector2(94.0, -14.0)]
const PARTS := [
	{"id": "1", "at": Vector2(44.0, 50.0), "kind": "coil"},
	{"id": "2", "at": Vector2(52.5, 3.5), "kind": "bulb"},
	{"id": "3", "at": Vector2(84.0, -6.0), "kind": "cog"},
]
const PICK_RADIUS := 1.8
const BOT_AT := Vector2(92.5, -16.0)           # out in the yard in front of the lab's open front
const BOT_RADIUS := 1.8                        # the little circle it zooms round
const BOT_SPEED := 0.75                        # radians a second: slow enough for small hands to catch
const BOT_CATCH := 1.5
const STEP_GAP := 1.6                          # metres between tyre marks
const GADGET_STALLS := ["Gadget", "Workbench"]

var _scene: Node
var _tracks: Node3D
var _parts := {}                               # id -> its node, while it's out
var _bot: Node3D
var _t := 0.0
var _since := 0.0                              # seconds since this scene came in (the ground needs a physics frame)


func _ready() -> void:
	Quests.changed.connect(func(_id: String) -> void: advance())
	Shop.opened.connect(_on_shop)
	Arsenal.changed.connect(_check_popper.call_deferred)   # (buying the Star Popper ticks it off; the gadget's in a frame later)
	Dialogue.flag_set.connect(func(_f: String) -> void: _check_popper())


# -----------------------------------------------------------------------------
# The chain
# -----------------------------------------------------------------------------
func advance() -> void:
	# Start whichever story quest's turn it is: the one after the last one done (or skipped all the way through)
	for c in CHAIN:
		if Dialogue.flags.has(str(c.flag)) or Quests.is_started(str(c.quest)):
			continue
		if Quests.is_done(str(c.after)):
			Dialogue.set_flag(str(c.flag))
			Schematics.refresh()
			Quests.check.call_deferred()
		return


func story_now() -> String:
	# The newest story quest that's going (for the Goals page), else ""
	for i in range(CHAIN.size() - 1, -1, -1):
		var q := str(CHAIN[i].quest)
		if Quests.is_started(q) and not Quests.is_done(q):
			return q
	if Quests.is_started("first_night") and not Quests.is_done("first_night"):
		return "first_night"
	return ""


func story_next() -> String:
	for c in CHAIN:
		if not Quests.is_started(str(c.quest)):
			return str(c.quest)
	return ""


func migrate() -> void:
	# A save from before this order (game.gd, through FirstNight.migrate()): if they met Dash the old way (by the
	# portal on the First Night), The Bike Boy is done for them, or waits on its Gloop King step if they hadn't popped
	# him yet. Saves that never met Dash get it the new way.
	if Quests.state.has(QUEST) or not Dialogue.flags.has("fn_met_dash"):
		return
	for f in ["bike_boy_start", "bb_part_1", "bb_part_2", "bb_part_3", "bb_met_dash", "bb_bot_caught", "bb_thanked",
			"bb_stall", "schematic_popper", "bb_popper"]:
		Dialogue.flags[f] = true
	var steps: Array = Quests.quest(QUEST).get("steps", [])
	var king_done := Dialogue.flags.has("popped_gloop_king") and Dialogue.flags.has("fn_told_dash")
	if king_done or Quests.is_done("first_night"):
		Quests.state[QUEST] = {"step": steps.size(), "since_day": Clock.day, "done": true}
	else:
		Quests.state[QUEST] = {"step": steps.size() - 1, "since_day": Clock.day, "done": false}


func stall_open() -> bool:
	# Dash's gadget stall and workbench open once The Bike Boy gets to them. A save from before the new first day
	# (no "fresh_start") had them from the start, and keeps them.
	if not Dialogue.flags.has(FirstNight.FRESH_FLAG):
		return true
	if Quests.is_done(QUEST):
		return true
	return Quests.on_step(QUEST, "stall") or Quests.on_step(QUEST, "king")


func closed_lines(stall: String) -> Array:
	# What the stall says while it's shut (scripts/shop_stall.gd)
	var sign := "(GONE TINKERING. BACK SOON! -D)"
	var out: Array = [sign]
	if Quests.is_started(QUEST):
		out.append("(PS: catch my Buzz Bot, PLEASE!)")
	else:
		out.append("(A little bike is drawn on it.)")
	return out


# -----------------------------------------------------------------------------
# The Bike Boy's little helpers
# -----------------------------------------------------------------------------
func _on_shop(stall: String) -> void:
	if stall == "Gadget" and Quests.on_step(QUEST, "stall"):
		_flag("bb_stall")
	_check_popper()


func _check_popper() -> void:
	# Bought the Star Popper (or had it already). A game with no Star Popper blueprint never needs to find one.
	if not Quests.on_step(QUEST, "stall"):
		return
	if Schematics.entry("popper").is_empty():
		_flag("schematic_popper")
	if Arsenal.owns("popper"):
		_flag("bb_popper")


func _flag(f: String) -> void:
	if not Dialogue.flags.has(f):
		Dialogue.set_flag(f)


func meet_dash() -> Array:
	# Dash's "do" when you find him in the lab: the bot gets loose as he talks
	_flag("bb_met_dash")
	return []


func thanks_from_dash() -> Array:
	# Dash's "do" once the bot's caught: his stall's open, and he gives you the Star Popper's blueprint as a thank-you
	# (Schematics.LIST "popper" is a reward for "bb_thanked"; his lines say so, so no message on top)
	_flag("bb_thanked")
	Schematics.award("popper", true)
	return []


func king_from_dash() -> Array:
	# Dash's "do" once the King's popped: the crown (FirstNight.crown_from_dash() always gave it), then he shows you
	# his kinetic energy (scripts/kinetic.gd), then sends you on to Pip
	var lines: Array = FirstNight.crown_from_dash()
	lines.append_array(KINETIC.teach_lines())
	lines.append("Oh! Pip's waiting by the portal. Go on!")
	return lines


func kinetic_from_dash() -> Array:
	# For a save that told Dash about the King before he had his kinetic trick to show
	return KINETIC.teach_lines()


# -----------------------------------------------------------------------------
# What's out in the town
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_tracks = null
		_bot = null
		_parts.clear()
		_since = 0.0
		advance()                              # (a save loaded, or a trip home: whose turn is it?)
	_since += delta
	if s == null or s.scene_file_path != TOWN:
		return
	if _since > 0.4 and Engine.get_process_frames() % 20 == 0:
		_check_popper()
		_tidy(s)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var at := Vector2(p.global_position.x, p.global_position.z)
	for id in _parts.keys():
		var n: Node3D = _parts[id]
		if not is_instance_valid(n):
			_parts.erase(id)
			continue
		n.rotation.y += delta * 1.6
		n.get_child(0).position.y = 0.55 + sin(_t * 2.5) * 0.12
		if at.distance_to(Vector2(n.global_position.x, n.global_position.z)) < PICK_RADIUS \
				and absf(p.global_position.y - n.global_position.y) < 2.5:
			_pick(str(id), n)
	if is_instance_valid(_bot):
		var a := _t * BOT_SPEED
		var c := Vector2(BOT_AT.x + cos(a) * BOT_RADIUS, BOT_AT.y + sin(a) * BOT_RADIUS)
		_bot.global_position = Vector3(c.x, _bot.global_position.y, c.y)
		_bot.get_child(0).position.y = 1.0 + sin(_t * 4.0) * 0.25
		_bot.rotation.y = -a
		if at.distance_to(c) < BOT_CATCH and absf(p.global_position.y - _bot.global_position.y) < 2.5:
			_catch_bot()


func _tidy(s: Node) -> void:
	# Put out what the quest's step wants, and take away what it doesn't
	var tracks_on := Quests.on_step(QUEST, "tracks") or Quests.on_step(QUEST, "lab")
	if tracks_on and _tracks == null:
		_tracks = _make_tracks(s)
	elif not tracks_on and is_instance_valid(_tracks):
		_tracks.queue_free()
		_tracks = null
	for part in PARTS:
		var id := str(part.id)
		var want := Quests.on_step(QUEST, "tracks") and not Dialogue.flags.has("bb_part_" + id)
		if want and not _parts.has(id):
			_parts[id] = _make_part(s, part)
		elif not want and _parts.has(id):
			if is_instance_valid(_parts[id]):
				_parts[id].queue_free()
			_parts.erase(id)
	var bot_on := Quests.on_step(QUEST, "bot")
	if bot_on and _bot == null:
		_bot = _make_bot(s)
	elif not bot_on and is_instance_valid(_bot):
		_bot.queue_free()
		_bot = null


func _pick(id: String, n: Node3D) -> void:
	_parts.erase(id)
	Juice.chime_pickup()
	Fx.burst(n.get_parent(), n.global_position + Vector3.UP * 0.6, Color(1.0, 0.85, 0.35), 10, 0.07, 3.0, -4.0, 0.8)
	n.queue_free()
	_flag("bb_part_" + id)
	var got := PARTS.filter(func(pt: Dictionary) -> bool: return Dialogue.flags.has("bb_part_" + str(pt.id))).size()
	var what: String = {"coil": "a springy coil", "bulb": "a fizzing bulb", "cog": "a tiny cog"}.get(
		str(PARTS[int(id) - 1].kind), "a gadget bit")
	if got < PARTS.size():
		Game.message("Got %s! (%d of %d)" % [what, got, PARTS.size()])
	else:
		Game.message("Got %s! That's all three!" % what)


func _catch_bot() -> void:
	var at := _bot.global_position + Vector3.UP
	Fx.burst(_bot.get_parent(), at, Color(1.0, 0.85, 0.35), 16, 0.08, 4.0, -4.0, 1.0)
	Juice.blip("pop", 1.2, -4.0)
	Juice.rumble(0.3, 0.15)
	_bot.queue_free()
	_bot = null
	_flag("bb_bot_caught")
	Game.message("Got the Buzz Bot! Back to Dash!")


func _ground(s: Node, x: float, z: float) -> float:
	var space := (s as Node3D).get_world_3d().direct_space_state if s is Node3D else null
	if space == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 60.0, z), Vector3(x, -40.0, z))
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else 0.0


func _glow(col: Color, energy := 1.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func _make_tracks(s: Node) -> Node3D:
	# Two lines of glowing tyre marks along the way Dash rode (one wheel, then the other), dropped onto the ground
	var root := Node3D.new()
	root.name = "Dash's Tyre Tracks"
	s.add_child(root)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.03, 0.85)
	var mat := _glow(Color(1.0, 0.88, 0.45), 2.2)          # gold, so they show up on the teal grass
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in TRACK.size() - 1:
		var a: Vector2 = TRACK[i]
		var b: Vector2 = TRACK[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * 0.22
		var marks := int(a.distance_to(b) / STEP_GAP)
		for k in marks:
			var c := a.lerp(b, float(k) / maxf(marks, 1))
			c += Vector2(sin(c.x * 0.37) * 0.25, cos(c.y * 0.29) * 0.25)      # a little wobble: he rides like that
			var mark := MeshInstance3D.new()
			mark.mesh = mesh
			mark.material_override = mat
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var w := c + (side if k % 2 == 0 else -side)
			root.add_child(mark)
			mark.global_position = Vector3(w.x, _ground(s, w.x, w.y) + 0.03, w.y)
			mark.rotation.y = atan2(dir.x, dir.y)
	return root


func _make_part(s: Node, part: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Dash's Gadget Bit %s" % str(part.id)
	var model := Node3D.new()
	root.add_child(model)
	var gold := _glow(Color(1.0, 0.8, 0.3), 1.2)
	match str(part.kind):
		"coil":
			for i in 5:
				var ring := MeshInstance3D.new()
				var t := TorusMesh.new()
				t.inner_radius = 0.16
				t.outer_radius = 0.22
				ring.mesh = t
				ring.material_override = gold
				ring.position.y = -0.2 + i * 0.1
				model.add_child(ring)
		"bulb":
			var glass := MeshInstance3D.new()
			var ball := SphereMesh.new()
			ball.radius = 0.22
			ball.height = 0.44
			glass.mesh = ball
			glass.material_override = _glow(Color(0.5, 1.0, 0.85), 2.2)
			model.add_child(glass)
			var cap := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.1
			cy.bottom_radius = 0.1
			cy.height = 0.16
			cap.mesh = cy
			cap.material_override = gold
			cap.position.y = -0.26
			model.add_child(cap)
		_:
			var cog := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.24
			cy.bottom_radius = 0.24
			cy.height = 0.08
			cy.radial_segments = 10
			cog.mesh = cy
			cog.material_override = gold
			cog.rotation.x = PI / 2.0
			model.add_child(cog)
			for i in 8:
				var tooth := MeshInstance3D.new()
				var bx := BoxMesh.new()
				bx.size = Vector3(0.08, 0.08, 0.1)
				tooth.mesh = bx
				tooth.material_override = gold
				tooth.position = Vector3(cos(i * TAU / 8.0) * 0.28, sin(i * TAU / 8.0) * 0.28, 0)
				cog.add_child(tooth)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.45)
	light.light_energy = 1.2
	light.omni_range = 4.0
	model.add_child(light)
	s.add_child(root)
	var at: Vector2 = part.at
	root.global_position = Vector3(at.x, _ground(s, at.x, at.y), at.y)
	return root


func _make_bot(s: Node) -> Node3D:
	# Dash's runaway Buzz Bot: a little gold ball with a teal eye and two buzzing rotors
	var root := Node3D.new()
	root.name = "Runaway Buzz Bot"
	var model := Node3D.new()
	root.add_child(model)
	var body := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.3
	ball.height = 0.6
	body.mesh = ball
	body.material_override = _glow(Color(1.0, 0.78, 0.25), 0.8)
	model.add_child(body)
	var eye := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = 0.11
	e.height = 0.22
	eye.mesh = e
	eye.material_override = _glow(Color(0.35, 1.0, 0.9), 2.4)
	eye.position = Vector3(0, 0.05, -0.26)
	model.add_child(eye)
	for side in [-1.0, 1.0]:
		var rotor := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.22
		cy.bottom_radius = 0.22
		cy.height = 0.02
		rotor.mesh = cy
		var rm := _glow(Color(0.8, 0.95, 1.0), 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.albedo_color.a = 0.5
		rotor.material_override = rm
		rotor.position = Vector3(side * 0.3, 0.3, 0)
		model.add_child(rotor)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.4)
	light.light_energy = 1.0
	light.omni_range = 3.5
	model.add_child(light)
	s.add_child(root)
	root.global_position = Vector3(BOT_AT.x + BOT_RADIUS, _ground(s, BOT_AT.x + BOT_RADIUS, BOT_AT.y), BOT_AT.y)
	return root
