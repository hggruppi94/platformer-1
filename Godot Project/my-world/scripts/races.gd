extends Node

# Autoload "Races": racing round Galaxity on whatever you ride (your board, or a friend's ride from the Skaters'
# Corner: scripts/rides.gd). Each track (TRACKS) is placed in its scene at runtime by scripts/race_track.gd: a start
# arch, Zippy the pink little alien who starts the races, a race board, boost pads that are there all the time, and,
# while racing, glowing rings at the checkpoints, Star Boxes and goo puddles.
#
# Talk to Zippy and say you're ready: you're put on the line with three friends on their own rides
# (scripts/race_rival.gd), a 3-2-1 countdown, then laps round the checkpoints in order (the next ring glows gold).
# Boost pads shoot you forward. Star Boxes give a power-up to use when you like (the Aim button, which is free while
# riding): the Zoom Star (a burst of speed), the Bubble Shield (no falls and no goo for a while) or the Super Spring
# (a huge hop). Goo puddles are slow going. Everyone who finishes wins sparkles (more for a better place), and beating
# your best time pays a bonus. Stepping off your ride, wandering far off the track or leaving the place ends the race
# with no harm done.
#
# Kept apart from the Star Popper and other gadgets on purpose: power-ups are things on the track, used up in a race.
#
# Zippy's Tune-Up, a workbench beside the race board, sells ride upgrades through the shared shop (scripts/shop.gd,
# the "Tune-Up" stall, kind "ride_upgrade" in res://shop/items.json): Speedy Wheels, Power Push, Grippy Grip and
# Turbo Tank, three levels each, and the Starter Star. They work on every ride, on or off the track: tuned() turns a
# ride's numbers (scripts/rides.gd) into the upgraded ones, and the skating uses those (scenes/player/skate.gd).
# Best times, wins and upgrades are saved with the game (scripts/game.gd, "races").

signal finished(track_id: String, place: int)
signal upgraded

enum State { IDLE, COUNTDOWN, RACING, RESULTS }

const TOWN := "res://scenes/town/town.tscn"
const COUNTDOWN := 3.0
const RESULTS_TIME := 7.0
const PASS_RADIUS := 6.0             # metres from a checkpoint's middle that counts as through its ring
const PAD_RADIUS := 1.9
const BOX_RADIUS := 1.7
const GOO_RADIUS := 2.0
const WANDER := 45.0                 # metres off the track and the race is off
const BEST_BONUS := 5                # sparkles for beating your best time

# Each track: its checkpoints (x, z; the first is the start and finish line), laps, prizes by place, and where its
# boost pads, Star Boxes (three across the track) and goo puddles are, as a checkpoint number plus how far on to the
# next one (2.5 is halfway from checkpoint 2 to 3) and metres to the right of the racing line.
const TRACKS := {
	"lake_loop": {
		"name": "Lake Loop",
		"blurb": "three laps round the lake",
		"scene": TOWN,
		"laps": 3,
		"points": [Vector2(-4, 24), Vector2(16, 25), Vector2(34, 24), Vector2(43, 17), Vector2(42.3, 6),
			Vector2(42.3, -5), Vector2(36, -18), Vector2(16, -22), Vector2(0, -21), Vector2(-12, -21),
			Vector2(-28, -18), Vector2(-42, -8), Vector2(-46, 4), Vector2(-38, 16), Vector2(-22, 23)],
		"boosts": [[0.5, 0.0], [4.4, 0.0], [7.5, 0.0], [11.5, 0.0]],
		"boxes": [[2.5], [9.4], [13.0]],
		"goo": [[5.5, -2.0], [8.6, 2.0], [12.3, -1.6]],
		"prizes": [15, 10, 6, 3],
		"rivals": ["dash", "rex", "bramble"],
		"starter": {"name": "Zippy", "model": "res://models/characters/little_alien_pink.glb"},
		"tune_up": true,
	},
	"meadow_wiggle": {
		"name": "Meadow Wiggle",
		"blurb": "two laps of wiggly bends through the south meadow",
		"scene": TOWN,
		"laps": 2,
		"after": "lake_loop",
		"points": [Vector2(-18, 50), Vector2(4, 46), Vector2(21, 50), Vector2(25, 62), Vector2(14, 72),
			Vector2(0, 65), Vector2(-14, 72), Vector2(-6, 85), Vector2(12, 92), Vector2(0, 99), Vector2(-24, 96),
			Vector2(-38, 82), Vector2(-30, 68), Vector2(-38, 56)],
		"boosts": [[0.5, 0.0], [5.5, 0.0], [9.5, 0.0]],
		"boxes": [[2.5], [7.5], [11.5]],
		"goo": [[3.6, 1.8], [6.4, -1.8], [10.5, 1.6]],
		"prizes": [18, 12, 7, 4],
		"rivals": ["rook", "pip", "green_man"],
		"starter": {"name": "Dart", "model": "res://models/characters/little_alien_orange.glb"},
	},
	"sky_rings": {
		"name": "Sky Rings",
		"blurb": "one big lap of the sky in the mothership",
		"scene": TOWN,
		"laps": 1,
		"after": "lake_loop",
		"sky": true,
		"ring": 24.0,
		# x, height, z: over the lake, the Homes, the Observatory, round the castle, the Spooky Woods and the Market
		"points": [Vector3(0, 48, 0), Vector3(60, 44, 24), Vector3(104, 58, -18), Vector3(112, 66, -88),
			Vector3(64, 74, -150), Vector3(-24, 80, -168), Vector3(-84, 62, -112), Vector3(-104, 58, -40),
			Vector3(-82, 38, 30), Vector3(-40, 42, 52)],
		"boosts": [[1.5], [4.5], [7.5]],
		"prizes": [25, 16, 10, 5],
		"rivals": [{"id": "blip", "name": "Blip", "colour": "green"}, {"id": "nova", "name": "Nova", "colour": "purple"},
			{"id": "zoomi", "name": "Zoomi", "colour": "yellow"}],
		"pace": [23.0, 22.0, 21.0],               # metres a second (the mothership flies at 24, more in a boost)
	},
	"observatory_hill": {
		"name": "Observatory Hill",
		"blurb": "two laps up and down the slopes of the Observatory's hill",
		"scene": TOWN,
		"laps": 2,
		"after": "meadow_wiggle",
		"points": [Vector2(104, -51), Vector2(88, -54), Vector2(80, -70), Vector2(82, -90), Vector2(92, -108),
			Vector2(112, -112), Vector2(128, -100), Vector2(132, -80), Vector2(134, -62), Vector2(124, -51)],
		"boosts": [[0.5, 0.0], [5.5, 0.0], [8.5, 0.0]],
		"boxes": [[2.5], [4.5], [7.3]],
		"goo": [[3.5, -1.6], [6.5, 1.6]],
		"prizes": [20, 14, 8, 4],
		"rivals": ["dash", "rex", "mr_palmer"],
		"starter": {"name": "Comet", "model": "res://models/characters/little_alien_blue.glb"},
	},
}
# Who rides in a friend's place when you're riding as them
const SPARE_RIVALS := ["nina", "green_man", "pip"]
# How fast each rival rides on the flat (metres per second), front of the grid to back. The player's board pushes at 9.
const RIVAL_PACE := [9.2, 8.8, 8.4]
# Settings > Assist > Skating landings also sets how hard the races are: Relaxed, Normal, Pro
const PACE_BY_ASSIST := [0.9, 1.0, 1.1]

const POWERS := {
	"zoom": {"name": "Zoom Star", "say": "Zoom!"},
	"shield": {"name": "Bubble Shield", "say": "Bubble Shield!"},
	"spring": {"name": "Super Spring", "say": "Boing!"},
}
# What each level of an upgrade adds, as a share of the ride's own number (Speedy Wheels 2 = 10% faster)
const UPGRADES := {
	"wheels": {"push_speed": 0.05, "max_speed": 0.05},
	"push": {"push_accel": 0.15, "push_kick": 0.15},
	"grip": {"carve": 0.12},
	"turbo": {},                     # boosts last TURBO longer a level (boost_time())
	"starter": {},                   # every race starts with a Zoom Star in hand
}
const TURBO := 0.25

const SHIELD_TIME := 8.0
const ZOOM_SPEED := 8.0
const ZOOM_TIME := 2.2
const SPRING_POWER := 11.0
const PAD_SPEED := 6.5
const PAD_TIME := 1.3
const SKY_BOOST := 2.0

var best := {}                       # track id -> best time in seconds
var wins := {}                       # track id -> how many times you came 1st
var raced := 0                       # races finished, all told
var upgrades := {}                   # upgrade -> level bought (see UPGRADES)
var finished_once := {}              # track id -> true once you've finished it (opens the next track)

var state := State.IDLE
var track_id := ""
var track: RaceTrack                 # the one we're racing on
var rivals: Array[RaceRival] = []
var lap := 1
var last_cp := 0                     # the last checkpoint passed (0: the line)
var next_cp := 1
var time := 0.0
var power := ""                      # the power-up being held ("" for none)
var place := 1
var progress := 0.0                  # how far round the player is, all laps together
var hud: RaceHud
var _count := 0.0
var _results := 0.0
var _shield := 0.0
var _bubble: Node3D
var _wrong := 0.0
var _last_d := 0.0
var _pad_wait := {}                  # pad -> seconds until it boosts again (so one pad is one boost)
var _goo_wait := 0.0
var _rival_pad := {}                 # rival -> the last pad they were boosted by
var _along := 0.0                    # the player's last side of the next checkpoint (- before it, + past it)
var _rng := RandomNumberGenerator.new()
var _sky_side := {}                  # sky track -> which side of its start ring the mothership was last frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = RaceHud.new()
	hud.name = "RaceHUD"
	add_child(hud)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	Dialogue.finished.connect(_on_talked)
	_rng.randomize()
	_register_shop.call_deferred()            # Shop comes after this in the autoloads


func _register_shop() -> void:
	Shop.register_kind("ride_upgrade", {"can_buy": _can_upgrade, "buy": _buy_upgrade, "button": "Tune up",
		"show": _show_upgrade})


func _show_upgrade(item: Dictionary) -> bool:
	# Only the next level of each upgrade is on the bench (the top level stays once it's bought, as "Got it!")
	var lv := level(str(item.upgrade))
	return int(item.level) == lv + 1 or (int(item.level) == lv and lv == _top_level(str(item.upgrade)))


func _top_level(upgrade: String) -> int:
	var top := 0
	for it in Shop.items.values():
		if it.get("upgrade", "") == upgrade:
			top = maxi(top, int(it.level))
	return top


func _can_upgrade(item: Dictionary) -> String:
	var lv := level(str(item.upgrade))
	if lv >= int(item.level):
		return "You have this one"
	if lv < int(item.level) - 1:
		return "Needs level %d first" % (int(item.level) - 1)
	return ""


func _buy_upgrade(item: Dictionary) -> String:
	upgrades[str(item.upgrade)] = int(item.level)
	upgraded.emit()
	return "Zippy tightens a bolt or two. %s: %s!" % [item.name, str(item.text).split(" (")[0].to_lower()]


func level(upgrade: String) -> int:
	return int(upgrades.get(upgrade, 0))


func tuned(ride: Dictionary) -> Dictionary:
	# A ride's numbers with the upgrades bought so far
	if upgrades.is_empty():
		return ride
	var out := ride.duplicate()
	for u in UPGRADES:
		var lv := level(u)
		for key in UPGRADES[u]:
			if out.has(key) and lv > 0:
				out[key] = float(out[key]) * (1.0 + float(UPGRADES[u][key]) * lv)
	return out


func boost_time(seconds: float) -> float:
	return seconds * (1.0 + TURBO * level("turbo"))


func racing() -> bool:
	return state != State.IDLE


func save_data() -> Dictionary:
	return {"best": best.duplicate(), "wins": wins.duplicate(), "raced": raced, "upgrades": upgrades.duplicate(),
		"finished": finished_once.keys()}


func load_data(data: Dictionary) -> void:
	reset()
	var b = data.get("best", {})
	var w = data.get("wins", {})
	if b is Dictionary:
		for k in b:
			best[str(k)] = float(b[k])
	if w is Dictionary:
		for k in w:
			wins[str(k)] = int(w[k])
	raced = int(data.get("raced", 0))
	var done = data.get("finished", [])
	if done is Array:
		for k in done:
			finished_once[str(k)] = true
	for k in best:
		finished_once[k] = true                       # (a best time means it was finished)
	var u = data.get("upgrades", {})
	if u is Dictionary:
		for k in u:
			upgrades[str(k)] = int(u[k])
	upgraded.emit()
	_refresh_boards()


func reset() -> void:
	if racing():
		_end(false)
	best.clear()
	wins.clear()
	raced = 0
	finished_once.clear()
	upgrades.clear()
	upgraded.emit()


# -----------------------------------------------------------------------------
# Placing the tracks
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	if racing():
		_end(false)                                   # the scene the race was in is gone: no harm done
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id in TRACKS:
		if TRACKS[id].scene == scene.scene_file_path and scene.get_node_or_null("Race " + id) == null:
			var t := RaceTrack.new()
			t.name = "Race " + id
			t.setup(TRACKS[id])
			t.set_meta("track_id", id)
			scene.add_child(t)
	_refresh_boards.call_deferred()


func track_node(id: String) -> RaceTrack:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Race " + id) as RaceTrack if scene else null


func _refresh_boards() -> void:
	for id in TRACKS:
		var t := track_node(id)
		if t and t.sky and t.ready_to_race and not (racing() and track_id == id):
			t.show_race(false)                        # its start ring shows once it's open
		if t == null or t.board_text == null:
			continue
		t.board_text.text = board_text(id)


func board_text(id: String) -> String:
	var tr: Dictionary = TRACKS[id]
	var prizes: Array = tr.prizes
	var blurb := str(tr.blurb)
	var out := "%s\n%s\n\n1st ✦ %d   2nd ✦ %d\n3rd ✦ %d   4th ✦ %d\n\n" % [str(tr.name).to_upper(), blurb[0].to_upper() + blurb.substr(1),
		prizes[0], prizes[1], prizes[2], prizes[3]]
	out += "Best time: %s" % (RaceHud.clock(float(best[id])) if best.has(id) else "not yet!")
	out += "\nBeat it for ✦ %d more" % BEST_BONUS if best.has(id) else ""
	out += "\nWins: %d" % int(wins.get(id, 0))
	return out


# -----------------------------------------------------------------------------
# The sky race: the mothership (scripts/mothership.gd) through rings in the air
# -----------------------------------------------------------------------------
func _ship() -> Node3D:
	return get_tree().get_first_node_in_group("mothership") as Node3D


func _watch_sky() -> void:
	# Flying the mothership through an open sky track's start ring starts its race, straight away
	var ship := _ship()
	if ship == null or not ship.is_piloted():
		_sky_side.clear()
		return
	for id in TRACKS:
		var t := track_node(id)
		if t == null or not t.sky or not t.ready_to_race or not unlocked(id):
			continue
		var c := t.point_at(0.0)
		var rel := ship.global_position - c
		var along := rel.dot(t.dir_at(0.0))
		var before := float(_sky_side.get(id, along))
		_sky_side[id] = along
		if before < 0.0 and along >= 0.0 and rel.length() < t.ring_radius + 6.0:
			start_sky(id)
			return


func start_sky(id: String) -> bool:
	var t := track_node(id)
	var ship := _ship()
	if racing() or t == null or not t.sky or ship == null or not ship.is_piloted() or not unlocked(id):
		return false
	track_id = id
	track = t
	var pace: Array = TRACKS[id].pace
	var who: Array = TRACKS[id].rivals
	for k in who.size():
		var rival := RaceRival.new()
		rival.name = "Racer " + str(who[k].name)
		rival.saucer = who[k]
		rival.setup(str(who[k].id), t, -12.0 - 10.0 * k, [-12.0, 12.0, 0.0][k % 3], float(pace[k]))
		get_tree().current_scene.add_child(rival)
		rival.go()
		rivals.append(rival)
	lap = 1
	last_cp = 0
	next_cp = 1
	time = 0.0
	power = ""
	place = 1
	progress = 0.0
	_wrong = 0.0
	_along = -1.0
	_rival_pad.clear()
	t.show_race(true)
	t.light_rings(1)
	state = State.RACING
	hud.clear()
	hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.6)
	Audio.play("level_up")
	_status()
	return true


func _sky_boosts(ship: Node3D) -> void:
	for ring in track.pads:
		if _pad_wait.has(ring) or ship.global_position.distance_to((ring as Node3D).global_position) > 16.0:
			continue
		_pad_wait[ring] = 2.0
		ship.boost(boost_time(SKY_BOOST))
		Audio.play("swish", 0.0, 0.1)
		hud.shout("Boost!", Color(0.5, 1.0, 1.0), 0.4)


# -----------------------------------------------------------------------------
# For the map (scripts/map_screen.gd)
# -----------------------------------------------------------------------------
func map_tracks() -> Array:
	var out: Array = []
	for id in TRACKS:
		var t := track_node(id)
		if t == null or not t.ready_to_race:
			continue
		out.append({"name": TRACKS[id].name, "line": t.line, "start": t.point_at(0.0), "open": unlocked(id),
			"racing": racing() and track_id == id})
	return out


func map_next() -> Vector3:
	return track.point_at(track.cp_dist[next_cp]) if racing() and is_instance_valid(track) else Vector3.ZERO


func map_rivals() -> Array:
	return rivals.filter(func(r: RaceRival) -> bool: return is_instance_valid(r)).map(func(r: RaceRival) -> Vector3: return r.global_position)


# -----------------------------------------------------------------------------
# The starters (Zippy at the Lake Loop, and one at each other track)
# -----------------------------------------------------------------------------
func unlocked(id: String) -> bool:
	# A track opens once you've finished the one before it (any place counts)
	var needs := str(TRACKS[id].get("after", ""))
	return needs == "" or finished_once.has(needs)


func talk(talker: Node3D) -> void:
	if racing():
		return
	var id := str(talker.get_parent().get_meta("track_id", "lake_loop"))     # the talk spot is on the starter
	Dialogue.say(talker, str(TRACKS[id].starter.name), lines(id), "race_starter")


func lines(id := "lake_loop") -> Array:
	var tr: Dictionary = TRACKS[id]
	var me := str(tr.starter.name)
	if not Game.has_item("skateboard"):
		return ["Vroom vroom, {player}! I'm %s, and I start the races here." % me,
			"But {they}'ll need something to ride first! There's a skateboard waiting at the Skate Park."]
	var out: Array = []
	if raced == 0:
		out.append("Vroom vroom, {player}! I'm %s, and I start the %s: %s!" % [me, tr.name, tr.blurb])
		out.append("Ride through every ring, in order: the next one glows gold. Boost pads zoom you along, and the Star Boxes give you a power-up. Press %s to use it!" % Settings.prompt("aim"))
		out.append("Goo puddles are slow going, so steer round them. Everyone who finishes wins sparkles!")
	else:
		out.append("Back for more, {player}? The %s is %s." % [tr.name, tr.blurb])
		if best.has(id):
			out.append("Your best time here is %s. Beat it for ✦ %d more!" % [RaceHud.clock(float(best[id])), BEST_BONUS])
	if not unlocked(id):
		out.append("This one opens once you've finished the %s. Zippy starts that one, by the lake!" % TRACKS[str(tr.after)].name)
	var choice: Array = []
	if unlocked(id):
		choice.append({"text": "Let's race!", "set": "race_go_" + id})
	# The other tracks you can race: the starter whistles up a mini saucer to whizz you over to the line
	for other in TRACKS:
		if other != id and unlocked(other) and TRACKS[other].scene == tr.scene and not TRACKS[other].get("sky", false):
			choice.append({"text": "Take me to the %s!" % TRACKS[other].name, "set": "race_go_" + other})
	choice.append({"text": "Not right now."})
	var news := TRACKS.keys().filter(func(k: String) -> bool: return unlocked(k) and k != id and not str(TRACKS[k].get("after", "")) == "" and not best.has(k) and not TRACKS[k].get("sky", false))
	if not news.is_empty() and raced > 0:
		out.append("Ooh, and the %s is open now! I can whizz you over." % TRACKS[news[0]].name)
	if unlocked("sky_rings") and not best.has("sky_rings"):
		out.append("And the Sky Rings are open! Fly the mothership through the big gold ring over the lake to start.")
	out.append({"choice": choice})
	return out


func _on_talked(id: String) -> void:
	if id != "race_starter":
		return
	for f in Dialogue.flags.keys():
		if str(f).begins_with("race_go_"):
			Dialogue.flags.erase(f)
			start.call_deferred(str(f).trim_prefix("race_go_"))
			return


# -----------------------------------------------------------------------------
# A race
# -----------------------------------------------------------------------------
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func start(id: String) -> bool:
	var t := track_node(id)
	var p := _player()
	if racing() or t == null or not t.ready_to_race or p == null or not Game.has_item("skateboard") or not unlocked(id):
		return false
	track_id = id
	track = t
	if not Game.riding:
		Game.riding = true
		Game.equipment_changed.emit()
	# The grid, just behind the line: the player at the front on the left, the others beside and behind
	var grid := [[-4.0, -2.2], [-4.0, 2.2], [-9.0, -2.2], [-9.0, 2.2]]
	var start_at := t.point_at(grid[0][0]) + t.side_at(grid[0][0]) * float(grid[0][1])
	var ground := t.ground_at(Vector2(start_at.x, start_at.z))
	var f := t.dir_at(0.0)
	p.global_position = ground + Vector3.UP * 0.85
	p.velocity = Vector3.ZERO
	var yaw := atan2(f.x, f.z)
	p.visual.rotation.y = yaw
	var skate = p.get("skate")
	skate.set("_yaw", yaw)
	skate.set("_shown_yaw", yaw)
	p.spring_arm.rotation.y = atan2(-f.x, -f.z)
	p.input_locked = true
	# The friends lining up
	var who: Array = []
	for r in TRACKS[id].rivals:
		who.append(r if r != p.get("rider") else "")
	for k in who.size():
		if who[k] == "":
			for spare in SPARE_RIVALS:
				if not spare in who and spare != p.get("rider"):
					who[k] = spare
					break
	var pace := float(PACE_BY_ASSIST[clampi(Settings.skate_assist, 0, PACE_BY_ASSIST.size() - 1)])
	for k in who.size():
		var rival := RaceRival.new()
		rival.name = "Racer " + str(who[k])
		var push := float(Rides.ride(who[k]).push_speed)
		rival.setup(who[k], t, float(grid[k + 1][0]), float(grid[k + 1][1]), RIVAL_PACE[k] * pace / push)
		get_tree().current_scene.add_child(rival)
		rivals.append(rival)
		_show_npc(who[k], false)
	lap = 1
	last_cp = 0
	next_cp = 1
	time = 0.0
	power = "zoom" if level("starter") > 0 else ""
	place = 1
	progress = 0.0
	_shield = 0.0
	_wrong = 0.0
	_last_d = 0.0
	_along = -1.0
	_rival_pad.clear()
	t.show_race(true)
	state = State.COUNTDOWN
	_count = COUNTDOWN
	hud.clear()
	hud.show_power(POWERS[power].name if power != "" else "")
	hud.shout("3", Color(1.0, 0.85, 0.3), 0.5)
	Audio.play("ui_move")
	_status()
	return true


func _physics_process(delta: float) -> void:
	_tick_pads(delta)
	if state == State.IDLE:
		_watch_sky()
	match state:
		State.COUNTDOWN:
			_countdown(delta)
		State.RACING:
			_race(delta)
		State.RESULTS:
			_results -= delta
			for r in rivals:
				r.race(delta, progress)
			if _results <= 0.0:
				_end(true)


func _countdown(delta: float) -> void:
	var p := _player()
	if p == null:
		_end(false)
		return
	p.velocity = Vector3.ZERO
	p.input_locked = true
	var before := ceili(_count)
	_count -= delta
	var now := ceili(_count)
	if now != before and now > 0:
		hud.shout(str(now), Color(1.0, 0.85, 0.3), 0.5)
		Audio.play("ui_move")
		Juice.blip("tick", 1.0, -6.0)
		Juice.rumble(0.15, 0.06)
	if _count <= 0.0:
		state = State.RACING
		p.input_locked = false
		for r in rivals:
			r.go()
		hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.5)
		Audio.play("level_up")
		Juice.blip("tick", 1.5, -4.0)
		Juice.shake(0.15)
		Juice.rumble(0.4, 0.15)


func _race(delta: float) -> void:
	var p := _player()
	if p == null:
		_end(false)
		return
	var t := track
	var ship := _ship()
	if t.sky:
		if ship == null or not ship.is_piloted():
			Game.message("You left the mothership, so the sky race is off. Fly through the gold ring to race again!")
			_end(false)
			return
	elif not Game.riding:
		Game.message("You stepped off your ride, so the race is off. Talk to the starter to race again!")
		_end(false)
		return
	time += delta
	var L := t.length
	var cps := t.cp_dist
	var pos := ship.global_position if t.sky else p.global_position
	var vel: Vector3 = ship.velocity if t.sky else p.velocity
	# Through the next ring? Either close to its middle, or across its line (fast riders can be between frames)
	var cp_d := cps[next_cp]
	var cp_pos := t.point_at(cp_d)
	var cp_dir := t.dir_at(cp_d)
	var rel := pos - cp_pos
	var along := rel.dot(cp_dir)
	var side := absf(rel.dot(t.side_at(cp_d)))
	var reach := t.ring_radius + 4.0 if t.sky else PASS_RADIUS
	var close := rel.length() if t.sky else Vector2(rel.x, rel.z).length()
	var through := close < reach or (_along < 0.0 and along >= 0.0 and side < reach + 2.0 and absf(rel.y) < (t.ring_radius if t.sky else 6.0))
	_along = along
	if through:
		_pass_checkpoint()
		if state != State.RACING:
			return
	# How far round: between the last checkpoint passed and the next
	var lo := cps[last_cp]
	var hi := cps[next_cp] if next_cp != 0 else L
	var here := t.nearest(pos, (lo + hi) / 2.0, (hi - lo) / 2.0 + 20.0)
	here = lo + clampf(wrapf(here - lo, -L / 2.0, L / 2.0), 0.0, hi - lo)     # the loop wraps round at the line
	progress = (lap - 1) * L + here
	# Going the wrong way for a while?
	var speed := Vector2(vel.x, vel.z).length()
	var fwd := Vector2(vel.x, vel.z).dot(Vector2(t.dir_at(here).x, t.dir_at(here).z))
	_wrong = _wrong + delta if speed > 3.0 and fwd < -2.0 else 0.0
	if _wrong > 1.2:
		_wrong = -2.0
		hud.shout("Wrong way!", Color(1.0, 0.55, 0.6), 0.6)
	if t.off_line(pos, here) > WANDER * (3.0 if t.sky else 1.0):
		Game.message("You went off the track, so the race is off. %s" % ("Fly through the gold ring to race again!" if t.sky else "Talk to the starter to race again!"))
		_end(false)
		return
	if t.sky:
		_sky_boosts(ship)
	else:
		_pick_up(p, t)
		_use_power(p)
		_tick_shield(p, delta)
	for r in rivals:
		r.race(delta, progress)
		_rival_pads(r)
		if not r.finished and r.d >= t.laps_length(int(TRACKS[track_id].laps)):
			r.finished = true
			r.finish_time = time
	place = 1
	for r in rivals:
		if r.d > progress:
			place += 1
	_status()


func _pass_checkpoint() -> void:
	var t := track
	var cps := t.cp_dist
	last_cp = next_cp
	next_cp = (next_cp + 1) % cps.size()
	_along = -1.0
	Audio.play("bloop", -4.0, 0.1)
	if last_cp == 0:
		if lap >= int(TRACKS[track_id].laps):
			_finish()
			return
		lap += 1
		hud.shout("Final lap!" if lap == int(TRACKS[track_id].laps) else "Lap %d!" % lap, Color(0.75, 0.9, 1.0), 0.6)
		Audio.play("level_up", -4.0)
	t.light_rings(next_cp)


func _status() -> void:
	hud.show_status(lap, int(TRACKS[track_id].laps), place, rivals.size() + 1, time)


func _finish() -> void:
	# Over the line: places as they stand (friends already home are ahead), sparkles for everyone, a bonus for a best
	var laps_l := track.laps_length(int(TRACKS[track_id].laps))
	place = 1
	for r in rivals:
		if r.finished:
			place += 1
	var prizes: Array = TRACKS[track_id].prizes
	var prize := int(prizes[clampi(place - 1, 0, prizes.size() - 1)])
	var old_best := float(best.get(track_id, 0.0))
	var new_best := old_best <= 0.0 or time < old_best
	var bonus := BEST_BONUS if new_best and old_best > 0.0 else 0
	if new_best:
		best[track_id] = time
	if place == 1:
		wins[track_id] = int(wins.get(track_id, 0)) + 1
	var opens := TRACKS.keys().filter(func(k: String) -> bool: return str(TRACKS[k].get("after", "")) == track_id and not finished_once.has(track_id))
	finished_once[track_id] = true
	raced += 1
	Game.add_sparkles(prize + bonus, "%s in the %s!" % [RaceHud.ordinal(place), TRACKS[track_id].name])
	# The table: friends not home yet get the time they're on course for
	var rows: Array = [["You", time]]
	for r in rivals:
		var t_est := r.finish_time if r.finished else time + maxf(laps_l - r.d, 0.0) / maxf(r.speed, 4.0)
		rows.append([str(r.saucer.name) if not r.saucer.is_empty() else str(Rides.ride(r.id).rider), t_est])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	# Your row stays where you really finished, whatever the guesses say
	rows.erase(rows.filter(func(row: Array) -> bool: return row[0] == "You")[0])
	rows.insert(place - 1, ["You", time])
	var text := "%s\n\n" % ("You won!" if place == 1 else "You came %s!" % RaceHud.ordinal(place))
	for k in rows.size():
		text += "%s   %s   %s\n" % [RaceHud.ordinal(k + 1), rows[k][0], RaceHud.clock(float(rows[k][1]))]
	text += "\nPrize: ✦ %d" % prize
	if bonus > 0:
		text += "\nNew best time! ✦ %d more" % bonus
	elif new_best:
		text += "\nYour first best time: %s" % RaceHud.clock(time)
	for k in opens:
		text += "\nThe %s is open now!" % TRACKS[k].name
	hud.shout("FINISH!", Color(1.0, 0.85, 0.3), 0.8)
	hud.show_results(text)
	Audio.play("level_up")
	state = State.RESULTS
	_results = RESULTS_TIME
	for r in rivals:
		r.finished = true                             # a slow lap of honour while the results are up
	_clear_power()
	track.show_race(false)
	_refresh_boards()
	finished.emit(track_id, place)


func _end(_done: bool) -> void:
	# Back to riding about: the friends ride off home (back in their usual places), the rings go
	for r in rivals:
		if is_instance_valid(r):
			_show_npc(r.id, true)
			r.queue_free()
	rivals.clear()
	_clear_power()
	if is_instance_valid(track):
		track.show_race(false)
	var p := _player()
	if p and state == State.COUNTDOWN:
		p.input_locked = false
	state = State.IDLE
	hud.clear()
	_refresh_boards()


# -----------------------------------------------------------------------------
# Boost pads, Star Boxes, goo and power-ups
# -----------------------------------------------------------------------------
func _tick_pads(delta: float) -> void:
	# Boost pads work any time someone rides over them, race or no race
	for pad in _pad_wait.keys():
		_pad_wait[pad] = float(_pad_wait[pad]) - delta
		if float(_pad_wait[pad]) <= 0.0:
			_pad_wait.erase(pad)
	_goo_wait -= delta
	var p := _player()
	if p == null or not Game.riding:
		return
	var skate = p.get("skate")
	for id in TRACKS:
		var t := track_node(id)
		if t == null or t.sky:
			continue
		for pad in t.pads:
			if _pad_wait.has(pad) or not _over(p.global_position, (pad as Node3D).global_position, PAD_RADIUS, 1.5):
				continue
			_pad_wait[pad] = 1.0
			skate.call("boost", PAD_SPEED, boost_time(PAD_TIME))
			Audio.play("swish", 0.0, 0.1)
			Juice.blip("whoosh", 1.2, -8.0)
			Juice.shake(0.12)
			Juice.rumble(0.3, 0.2)
			Juice.burst(p.get_parent(), p.global_position + Vector3(0, 0.3, 0), Color(0.5, 1.0, 1.0, 0.8), 12, 0.06, 3.0, 0.5)
			skate.hud.shout("Boost!", Color(0.5, 1.0, 1.0))


func _over(a: Vector3, b: Vector3, radius: float, height: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < radius and absf(a.y - 0.8 - b.y) < height


func _pick_up(p: Player, t: RaceTrack) -> void:
	var skate = p.get("skate")
	for box in t.boxes:
		if float((box as Node3D).get_meta("gone", 0.0)) > 0.0 or not _over(p.global_position, (box as Node3D).global_position, BOX_RADIUS, 2.5):
			continue
		(box as Node3D).set_meta("gone", 5.0)
		if power != "":
			continue                                  # already holding one: the box just pops
		power = _roll_power()
		hud.show_power(POWERS[power].name)
		Audio.play("pickup")
		Juice.blip("sparkle", 1.2, -9.0)
		Juice.burst(p.get_parent(), (box as Node3D).global_position, Color(1.0, 0.85, 0.35), 14, 0.07, 3.0, 0.6)
		Juice.rumble(0.2, 0.08)
	if _goo_wait <= 0.0:
		for g in t.goo:
			if _over(p.global_position, (g as Node3D).global_position, GOO_RADIUS, 1.0) and bool(skate.call("is_on_ground")):
				_goo_wait = 1.5
				if _shield > 0.0 or bool(skate.call("boosting")):
					skate.hud.shout("Whoosh!", Color(0.7, 0.95, 1.0))
				else:
					skate.call("gooed", 1.3)
					skate.hud.shout("Gloopy!", Color(0.7, 0.95, 0.35))
					Audio.play("stomp", -4.0)
				break


func _roll_power() -> String:
	# Further back, more Zoom Stars: they help you catch up
	var behind := place > 2
	var roll := _rng.randf()
	if roll < (0.55 if behind else 0.35):
		return "zoom"
	return "shield" if roll < (0.8 if behind else 0.7) else "spring"


func _use_power(p: Player) -> void:
	if power == "" or p.get("input_locked") or not Input.is_action_just_pressed("aim"):
		return
	use_power()


func use_power() -> bool:
	# Use what's held. The Super Spring needs the ground under you, so in the air it waits.
	var p := _player()
	if power == "" or p == null:
		return false
	var skate = p.get("skate")
	match power:
		"zoom":
			skate.call("boost", ZOOM_SPEED, boost_time(ZOOM_TIME))
			Audio.play("swish")
		"shield":
			_shield = SHIELD_TIME
			skate.set("shielded", true)
			_add_bubble(p)
			Audio.play("bubbles")
		"spring":
			if not bool(skate.call("is_on_ground")):
				return false
			skate.call("spring", SPRING_POWER)
			Audio.play("boing")
	skate.hud.shout(POWERS[power].say, Color(1.0, 0.85, 0.3))
	power = ""
	hud.show_power("")
	return true


func _tick_shield(p: Player, delta: float) -> void:
	if _shield <= 0.0:
		return
	_shield -= delta
	if _bubble:
		_bubble.scale = Vector3.ONE * (1.0 + sin(time * 8.0) * 0.03)
		_bubble.visible = _shield > 1.5 or fmod(_shield, 0.3) > 0.12 or Settings.reduce_flashing
	if _shield <= 0.0:
		_clear_shield(p)


func _add_bubble(p: Player) -> void:
	if _bubble:
		return
	_bubble = MeshInstance3D.new()
	_bubble.name = "Bubble Shield"
	var s := SphereMesh.new()
	s.radius = 1.25
	s.height = 2.5
	(_bubble as MeshInstance3D).mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.9, 1.0, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1.0)
	m.emission_energy_multiplier = 0.6
	m.rim_enabled = true
	m.rim = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	(_bubble as MeshInstance3D).material_override = m
	(_bubble as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position.y = 0.2
	p.add_child(_bubble)


func _clear_shield(p: Player) -> void:
	_shield = 0.0
	if p:
		var skate = p.get("skate")
		if skate:
			skate.set("shielded", false)
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func _clear_power() -> void:
	power = ""
	_clear_shield(_player())
	hud.show_power("")


func _rival_pads(r: RaceRival) -> void:
	# Friends get boosted by the pads they ride over too (and the saucers by the boost rings in the sky)
	for pad in track.pads:
		if _rival_pad.get(r) == pad:
			continue
		var gap := r.global_position.distance_to((pad as Node3D).global_position) if track.sky else \
			Vector2(r.global_position.x - (pad as Node3D).global_position.x, r.global_position.z - (pad as Node3D).global_position.z).length()
		if gap < (16.0 if track.sky else 2.5):
			_rival_pad[r] = pad
			r.boost(PAD_TIME)


# -----------------------------------------------------------------------------
func _show_npc(id: String, on: bool) -> void:
	# A friend racing steps out of their usual place in town while they race (the same as scenes/player/player.gd)
	var scene := get_tree().current_scene
	if scene == null:
		return
	for r in scene.find_children("Routine", "", true, false):
		if r.get("character_id") != id:
			continue
		for n in [r.get_parent(), r.get("_bike")]:
			if n is Node3D:
				(n as Node3D).visible = on
				(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
