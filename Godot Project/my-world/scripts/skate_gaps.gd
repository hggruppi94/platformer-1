extends Node

# Autoload "Gaps": gap bonuses for the skating, like Tony Hawk's. Fly from one spot to another on your ride and the
# gap's name and points go into your combo ("GAP! Hollow Yard Gap"), the same as a trick: it multiplies with
# everything else, repeats in one combo are worth half, and a bail loses it. The first time you land each gap you've
# "found" it: a sparkle or two and a cheer, and the Skate page in the Tab menu ticks it off (found gaps are Dialogue
# flags, "gap_<id>", so they're saved with the game).
#
# Two kinds:
# - Named gaps (GAPS) at real spots: off the Hollow Skate Yard's gap kicker onto its landing deck, off the Big Air
#   Kicker at the foot of Lookout Hill, off the hardware store's loading dock, down the school's stair set, over a
#   funbox... Each says where you take off ("from") and where you must come down ("to"), as circles in the frame of a
#   skate piece in the scene (so they move with it if a builder moves it), and how far you must fly ("min_dist") or
#   drop ("drop"). "both": it counts either way across.
# - Gaps anywhere (ANYWHERE): a long hang time, a long jump, a big drop, and hopping from one rail to another.
#
# It watches the rider's skating (scenes/player/skate.gd) from outside, by its state: leaving the ground or a rail is
# a take-off, coming down onto the ground or a rail without a bail is a landing. Vert airs (straight up off a steep
# ramp and back down) don't count for the anywhere gaps, or every quarter pipe would be a Hang Time.

signal found(id: String)                          # a gap landed for the first time
signal landed_gap(id: String, points: int)        # any gap landed (scripts/skate_runs.gd counts them in a run)

const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const FIRST_SPARKLES := 2                         # for finding a gap for the first time
const Y_REACH := 4.0                              # metres above or below a zone's piece that still counts as at it

# Each named gap: its scene, the skate piece its zones are measured from ("piece": a node name, or "Name/Child"), the
# take-off and landing circles in that piece's frame (x, z, radius; skate pieces rise toward their +Z), and what else
# it needs.
const GAPS := {
	"hollow_yard_gap": {"name": "Hollow Yard Gap", "points": 500, "scene": EARTH, "piece": "Hollow Skate Yard/Gap Kicker",
		"from": Vector3(0, 3.6, 2.6), "to_piece": "Hollow Skate Yard/Gap Landing", "to": Vector3(0, 3.0, 4.2), "min_dist": 5.0,
		"where": "the Hollow Skate Yard's gap kicker, onto the landing deck"},
	"yard_funbox_hop": {"name": "Yard Funbox Hop", "points": 250, "scene": EARTH, "piece": "Hollow Skate Yard/Funbox",
		"from": Vector3(0, -2.6, 2.6), "to": Vector3(0, 2.6, 2.6), "min_dist": 4.0, "both": true,
		"where": "right over the funbox in the Hollow Skate Yard"},
	"yard_stair_set": {"name": "Yard Stair Set", "points": 300, "scene": EARTH, "piece": "Hollow Skate Yard/Yard Stairs",
		"from": Vector3(0, -2.5, 3.6), "to": Vector3(0, 5.0, 3.6), "drop": 1.0,
		"where": "off the top of the Hollow Skate Yard's stairs, all the way down"},
	"school_stair_set": {"name": "School Stair Set", "points": 300, "scene": EARTH, "piece": "School Steps",
		"from": Vector3(0, -2.5, 3.6), "to": Vector3(0, 5.0, 3.6), "drop": 1.0,
		"where": "down the steps outside Old Oak Elementary"},
	"lookout_launch": {"name": "Lookout Launch", "points": 750, "scene": EARTH, "piece": "Big Air Kicker",
		"from": Vector3(0, 3.8, 2.8), "min_dist": 9.0,
		"where": "off the Big Air Kicker at the foot of Lookout Hill (come down the hill fast!)"},
	"pond_path_hop": {"name": "Pond Path Hop", "points": 200, "scene": EARTH, "piece": "Pond Path Kicker",
		"from": Vector3(0, 2.0, 1.9), "min_dist": 4.5,
		"where": "off the old kicker by the pond path"},
	"dock_drop": {"name": "Dock Drop", "points": 250, "scene": EARTH, "piece": "Loading Dock",
		"from": Vector3(0, 0, 4.2), "drop": 0.9, "min_dist": 2.5,
		"where": "off the hardware store's loading dock"},
	"park_funbox_hop": {"name": "Funbox Hop", "points": 250, "scene": TOWN, "piece": "Skate Park/Funbox",
		"from": Vector3(0, -2.6, 2.6), "to": Vector3(0, 2.6, 2.6), "min_dist": 4.0, "both": true,
		"where": "right over the funbox in Galaxity's Skate Park"},
}
const ANYWHERE := {
	"hang_time": {"name": "Hang Time", "points": 250, "where": "two seconds in the air (not straight up a quarter pipe)"},
	"long_gap": {"name": "Long Gap", "points": 300, "where": "fly 12 metres in one jump"},
	"big_drop": {"name": "Big Drop", "points": 300, "where": "land a drop of 3.5 metres or more"},
	"rail_transfer": {"name": "Rail Transfer", "points": 250, "where": "hop from one rail straight onto another"},
}
const HANG_TIME := 2.0
const LONG_GAP := 12.0
const BIG_DROP := 3.5
const TELEPORT := 3.0                             # metres in one physics frame: moved by the game, not by riding

var _was := -1                                    # the rider's skate state last frame
var _take := {}                                   # the take-off: {"pos", "rail", "grind"}
var _air := 0.0
var _vert := false
var last_jump := []                               # (for the tests) the last landing: [from, to, seconds in the air]
var _zones := {}
var _last_pos := Vector3.ZERO                                  # gap id -> [from centre, from radius, to centre, to radius, has to]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


static func all_ids() -> Array:
	return GAPS.keys() + ANYWHERE.keys()


static func info(id: String) -> Dictionary:
	return GAPS.get(id, ANYWHERE.get(id, {}))


func is_found(id: String) -> bool:
	return Dialogue.flags.has("gap_" + id)


func found_count() -> int:
	return all_ids().filter(func(id: String) -> bool: return is_found(id)).size()


func _on_scene_changed() -> void:
	# Work out where each named gap's circles are in this scene, from its skate pieces
	_zones.clear()
	_was = -1
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id in GAPS:
		var g: Dictionary = GAPS[id]
		if g.scene != scene.scene_file_path:
			continue
		var piece := _piece(scene, str(g.piece))
		var to_piece := _piece(scene, str(g.get("to_piece", g.piece)))
		if piece == null or to_piece == null:
			push_warning("Gaps: can't find %s for %s" % [g.piece, id])
			continue
		var f: Vector3 = g.from
		var to: Vector3 = g.get("to", Vector3.ZERO)
		_zones[id] = [piece.to_global(Vector3(f.x, 0, f.y)), f.z, to_piece.to_global(Vector3(to.x, 0, to.y)), to.z, g.has("to")]


func _piece(scene: Node, path: String) -> Node3D:
	var first := scene.find_child(path.get_slice("/", 0), true, false)
	if first == null:
		return null
	var rest := path.substr(path.find("/") + 1) if path.contains("/") else ""
	return (first.get_node_or_null(rest) if rest != "" else first) as Node3D


func zone(id: String) -> Array:
	# (For the tests and the capture tool) the named gap's circles here: [from centre, radius, to centre, radius, has to]
	return _zones.get(id, [])


func _physics_process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	var skate = p.get("skate") if p else null
	if skate == null or not Game.riding or not skate.get("hud"):
		_was = -1
		return
	var st: int = skate.state
	var AIR: int = skate.State.AIR
	var pos := (p as Node3D).global_position
	if pos.distance_to(_last_pos) > TELEPORT:
		_take = {}                                    # whisked somewhere (a race start, a door, a respawn): not a jump
		_was = -1
	_last_pos = pos
	if st == AIR and _was != AIR and _was != -1:
		_take = {"pos": (p as Node3D).global_position, "grind": _was == skate.State.GRIND, "rail": skate.get("_last_rail")}
		_air = 0.0
		_vert = false
	if st == AIR:
		_air += delta
		_vert = _vert or bool(skate.get("_vert"))
	elif _was == AIR and not _take.is_empty() and (st == skate.State.ROLL or st == skate.State.GRIND):
		var grind: bool = st == skate.State.GRIND
		check_landing(_take.pos, (p as Node3D).global_position, _air, _vert, bool(_take.grind), grind,
			_take.rail, skate.get("_rail"), skate)
		_take = {}
	elif st == skate.State.BAIL:
		_take = {}
	_was = st


func check_landing(from: Vector3, to: Vector3, air: float, vert: bool, from_grind: bool, on_grind: bool, from_rail,
		to_rail, skate) -> Array:
	# Which gaps a jump from here to there was, put into the combo. Returns their ids.
	var got: Array = []
	last_jump = [from, to, air]
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	var drop := from.y - to.y
	for id in _zones:
		var g: Dictionary = GAPS[id]
		var z: Array = _zones[id]
		var ok := _gap_fits(g, z, from, to, dist, drop)
		if not ok and g.get("both", false):
			ok = _gap_fits(g, [z[2], z[3], z[0], z[1], true], from, to, dist, drop)
		if ok:
			got.append(id)
	if not vert:
		if air >= HANG_TIME:
			got.append("hang_time")
		if dist >= LONG_GAP:
			got.append("long_gap")
	if drop >= BIG_DROP:
		got.append("big_drop")
	if from_grind and on_grind and from_rail != null and to_rail != null and from_rail != to_rail:
		got.append("rail_transfer")
	for id in got:
		_award(id, skate)
	return got


func _gap_fits(g: Dictionary, z: Array, from: Vector3, to: Vector3, dist: float, drop: float) -> bool:
	if not _in(from, z[0], z[1]):
		return false
	if z[4] and not _in(to, z[2], z[3]):
		return false
	if dist < float(g.get("min_dist", 0.0)) or drop < float(g.get("drop", -INF)):
		return false
	return true


func _in(at: Vector3, centre: Vector3, r: float) -> bool:
	return Vector2(at.x - centre.x, at.z - centre.z).length() <= r and absf(at.y - centre.y) < Y_REACH


func _award(id: String, skate) -> void:
	var g := info(id)
	var tricks: SkateTricks = skate.tricks if skate else null
	if tricks:
		tricks.gap(str(g.name), int(g.points))
	if skate and skate.get("hud"):
		skate.hud.shout("GAP! %s" % g.name, Color(0.55, 1.0, 0.85))
	Audio.play("bloop", -6.0, 0.1)
	Juice.blip("sparkle", 1.3, -10.0)
	landed_gap.emit(id, int(g.points))
	if not is_found(id):
		Dialogue.set_flag("gap_" + id)
		Game.add_sparkles(FIRST_SPARKLES, "New gap found: %s! (%d of %d)" % [g.name, found_count(), all_ids().size()])
		found.emit(id)
