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
const STARTER := "Zippy"

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

var best := {}                       # track id -> best time in seconds
var wins := {}                       # track id -> how many times you came 1st
var raced := 0                       # races finished, all told
var upgrades := {}                   # upgrade -> level bought (see UPGRADES)

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
	return {"best": best.duplicate(), "wins": wins.duplicate(), "raced": raced, "upgrades": upgrades.duplicate()}


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
# Zippy
# -----------------------------------------------------------------------------
func talk(talker: Node3D) -> void:
	if racing():
		return
	Dialogue.say(talker, STARTER, lines(), "zippy")


func lines(id := "lake_loop") -> Array:
	var tr: Dictionary = TRACKS[id]
	if not Game.has_item("skateboard"):
		return ["Vroom vroom, {player}! I'm Zippy, and I start the races round the lake.",
			"But {they}'ll need something to ride first! There's a skateboard waiting at the Skate Park."]
	var out: Array = []
	if raced == 0:
		out.append("Vroom vroom, {player}! I'm Zippy, and I start the races round the lake!")
		out.append("Ride through every ring, in order: the next one glows gold. Boost pads zoom you along, and the Star Boxes give you a power-up. Press %s to use it!" % Settings.prompt("aim"))
		out.append("Goo puddles are slow going, so steer round them. Everyone who finishes wins sparkles!")
	else:
		out.append("Back for more, {player}? The %s is %s." % [tr.name, tr.blurb])
		if best.has(id):
			out.append("Your best time is %s. Beat it for ✦ %d more!" % [RaceHud.clock(float(best[id])), BEST_BONUS])
	out.append({"choice": [{"text": "Let's race!", "set": "race_go"}, {"text": "Not right now."}]})
	return out


func _on_talked(id: String) -> void:
	if id != "zippy" or not Dialogue.flags.has("race_go"):
		return
	Dialogue.flags.erase("race_go")
	start.call_deferred("lake_loop")


# -----------------------------------------------------------------------------
# A race
# -----------------------------------------------------------------------------
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func start(id: String) -> bool:
	var t := track_node(id)
	var p := _player()
	if racing() or t == null or not t.ready_to_race or p == null or not Game.has_item("skateboard"):
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
	if _count <= 0.0:
		state = State.RACING
		p.input_locked = false
		for r in rivals:
			r.go()
		hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.5)
		Audio.play("level_up")


func _race(delta: float) -> void:
	var p := _player()
	if p == null:
		_end(false)
		return
	if not Game.riding:
		Game.message("You stepped off your ride, so the race is off. Talk to Zippy to race again!")
		_end(false)
		return
	time += delta
	var t := track
	var L := t.length
	var cps := t.cp_dist
	var pos := p.global_position
	# Through the next ring? Either close to its middle, or across its line (fast riders can be between frames)
	var cp_d := cps[next_cp]
	var cp_pos := t.point_at(cp_d)
	var cp_dir := t.dir_at(cp_d)
	var rel := pos - cp_pos
	var along := rel.dot(cp_dir)
	var side := absf(rel.dot(t.side_at(cp_d)))
	var through := Vector2(rel.x, rel.z).length() < PASS_RADIUS or (_along < 0.0 and along >= 0.0 and side < PASS_RADIUS + 2.0 and absf(rel.y) < 6.0)
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
	var speed := Vector2(p.velocity.x, p.velocity.z).length()
	var fwd := Vector2(p.velocity.x, p.velocity.z).dot(Vector2(t.dir_at(here).x, t.dir_at(here).z))
	_wrong = _wrong + delta if speed > 3.0 and fwd < -2.0 else 0.0
	if _wrong > 1.2:
		_wrong = -2.0
		hud.shout("Wrong way!", Color(1.0, 0.55, 0.6), 0.6)
	if t.off_line(pos, here) > WANDER:
		Game.message("You rode off the track, so the race is off. Talk to Zippy to race again!")
		_end(false)
		return
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
	raced += 1
	Game.add_sparkles(prize + bonus, "%s in the %s!" % [RaceHud.ordinal(place), TRACKS[track_id].name])
	# The table: friends not home yet get the time they're on course for
	var rows: Array = [["You", time]]
	for r in rivals:
		var t_est := r.finish_time if r.finished else time + maxf(laps_l - r.d, 0.0) / maxf(r.speed, 4.0)
		rows.append([str(Rides.ride(r.id).rider), t_est])
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
		if t == null:
			continue
		for pad in t.pads:
			if _pad_wait.has(pad) or not _over(p.global_position, (pad as Node3D).global_position, PAD_RADIUS, 1.5):
				continue
			_pad_wait[pad] = 1.0
			skate.call("boost", PAD_SPEED, boost_time(PAD_TIME))
			Audio.play("swish", 0.0, 0.1)
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
	# Friends get boosted by the pads they ride over too
	for pad in track.pads:
		if _rival_pad.get(r) == pad:
			continue
		var gap := Vector2(r.global_position.x - (pad as Node3D).global_position.x, r.global_position.z - (pad as Node3D).global_position.z).length()
		if gap < 2.5:
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
