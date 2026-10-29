class_name SkateTricks
extends RefCounted

# Tricks, combos and score for the skating (scenes/player/skate.gd), like Tony Hawk's: every trick goes into the
# combo, the combo pays its points times how many tricks are in it, and it's paid out when she lands and rolls
# away without linking anything else (a manual or a grind keeps it going). A bail loses the whole combo. Doing the
# same trick again in one combo is worth less each time, so mixing it up pays. Tricks fill the special meter; when
# it's full, Flip and Grab together does the rider's special trick.
#
# Which tricks a ride has, and what they're called, comes from its "tricks" in scripts/rides.gd.

signal changed                                  # the combo, score or special meter changed (the HUD listens)
signal banked(points: int, names: String)       # a combo was paid out
signal lost                                     # a combo was lost in a bail
signal live_done(name: String, seconds: float)  # a grind or manual just ended (without a bail)
signal added(name: String)                      # a trick went into the combo
signal popped(kind: String, on_grind: bool)     # a Star Popper bubble popped an enemy mid-ride (scripts/skate_goals.gd)

const GRACE := 0.4                    # after landing, this long to link a manual before the combo is paid out
const SPIN_POINTS := [0, 100, 250, 400, 600, 800, 1000, 1200]    # by half turns: 180, 360, 540...
const SPECIAL_FILL := 1500.0          # points of tricks that fill the special meter from empty
# Popping an enemy with the Star Popper while riding is a trick of its own: [name, points], by what was popped.
# Its points fill the special meter like any trick's (a Gloop's Pop! is about a sixth of it), and a second Pop! in
# one combo is worth half, like any repeat.
const POPS := {"gloop": ["Pop!", 250], "croc": ["Croc Pop!", 400], "king": ["King Pop!", 1500]}

var ride: Dictionary
var combo: Array[Dictionary] = []     # {"name", "points"} in the order she did them
var score := 0                        # everything paid out since she arrived
var best_combo := 0
var special := 0.0                    # 0..1; full means a special trick is ready
var flip := {}                        # the flip trick happening now: {"name", "style", "time", "duration", "points"}
var grab := {}                        # the grab being held now: {"name", "style", "time"}
var live := {}                        # a trick whose points grow while it lasts (a grind or a manual): {"name", "time", "base", "rate"}
var _grace := -1.0


func is_active() -> bool:
	return not combo.is_empty() or not live.is_empty() or not grab.is_empty() or not flip.is_empty()


func flipping() -> bool:
	return not flip.is_empty()


func multiplier() -> int:
	return maxi(combo.size() + (0 if live.is_empty() else 1), 1)


func points() -> int:
	# The combo so far, before the multiplier
	var total := 0
	for t in combo:
		total += int(t.points)
	if not live.is_empty():
		total += _live_points()
	return total


func names() -> String:
	var out: PackedStringArray = []
	for t in combo:
		out.append(t.name)
	if not live.is_empty():
		out.append(live.name)
	if not grab.is_empty():
		out.append(grab.name)
	return " + ".join(out)


static func direction_name(input: Vector2) -> String:
	# The stick (or WASD) as one of five: "", "up", "down", "left", "right"
	if input.length() < 0.5:
		return ""
	if absf(input.x) > absf(input.y):
		return "right" if input.x > 0.0 else "left"
	return "down" if input.y > 0.0 else "up"


# -----------------------------------------------------------------------------
# In the air
# -----------------------------------------------------------------------------
func start_flip(dir: String) -> bool:
	if flipping():
		return false
	var t: Array = ride.tricks.flips.get(dir, ride.tricks.flips[""])
	flip = {"name": t[0], "points": t[1], "style": t[2], "time": 0.0, "duration": t[3] if t.size() > 3 else 0.45}
	_grace = -1.0
	changed.emit()
	return true


func start_special() -> bool:
	if special < 1.0 or flipping():
		return false
	var t: Array = ride.tricks.special
	flip = {"name": t[0], "points": t[1], "style": t[2], "time": 0.0, "duration": t[3], "special": true}
	special = 0.0
	changed.emit()
	return true


func start_grab(dir: String) -> void:
	if not grab.is_empty():
		return
	var t: Array = ride.tricks.grabs.get(dir, ride.tricks.grabs[""])
	grab = {"name": t[0], "style": t[1], "time": 0.0}
	_grace = -1.0
	changed.emit()


func release_grab() -> void:
	if grab.is_empty():
		return
	# A grab is worth more the longer she holds it
	add(grab.name, 150 + int(grab.time * 250.0))
	grab = {}


func finish_flip() -> void:
	# Landed while the board was still going round, near enough the end to count (the forgiving assists)
	if flipping():
		add(flip.name, int(flip.points))
		flip = {}


func update_air(delta: float) -> void:
	if not grab.is_empty():
		grab.time += delta
	if flipping():
		flip.time += delta
		if flip.time >= flip.duration:
			add(flip.name, int(flip.points))
			flip = {}


func land(half_turns: int) -> void:
	# Landed clean: the grab (if she's still holding it) and the spin count too, then a moment to link a manual
	release_grab()
	if half_turns > 0:
		add(str(half_turns * 180), SPIN_POINTS[mini(half_turns, SPIN_POINTS.size() - 1)])
	if not combo.is_empty():
		_grace = GRACE


# -----------------------------------------------------------------------------
# Grinds and manuals: tricks that keep going
# -----------------------------------------------------------------------------
func start_live(name: String, base: int, rate: float) -> void:
	end_live()
	release_grab()
	live = {"name": name, "time": 0.0, "base": base, "rate": rate}
	_grace = -1.0
	changed.emit()


func update_live(delta: float) -> void:
	if not live.is_empty():
		live.time += delta
		changed.emit()


func end_live() -> void:
	if live.is_empty():
		return
	var pts := _live_points()
	var name: String = live.name
	var seconds: float = live.time
	live = {}
	add(name, pts)
	live_done.emit(name, seconds)


func _live_points() -> int:
	return int(live.base) + int(float(live.time) * float(live.rate))


# -----------------------------------------------------------------------------
# Popping things with the Star Popper (scripts/star_popper.gd)
# -----------------------------------------------------------------------------
func pop(kind: String, on_ground: bool, on_grind := false) -> void:
	# An enemy popped by a bubble while riding goes into the combo. On the ground (not in a manual), a lone pop
	# starts a combo of its own, with the usual moment to link a manual before it's paid out.
	var t: Array = POPS.get(kind, POPS.gloop)
	add(t[0], t[1])
	combo[-1]["pop"] = kind
	if on_ground and live.is_empty() and _grace < 0.0:
		_grace = GRACE
	popped.emit(kind, on_grind)


func pops(kind := "gloop") -> int:
	# How many of these she's popped in this combo
	var n := 0
	for t in combo:
		if t.get("pop", "") == kind:
			n += 1
	return n


# -----------------------------------------------------------------------------
# The combo
# -----------------------------------------------------------------------------
func add(name: String, pts: int) -> void:
	# The same trick again in this combo is worth half as much each time
	var repeats := 0
	for t in combo:
		if t.name == name:
			repeats += 1
	pts = maxi(int(pts / pow(2.0, repeats)), 10)
	combo.append({"name": name, "points": pts})
	special = minf(special + pts / SPECIAL_FILL, 1.0)
	added.emit(name)
	changed.emit()


func update_ground(delta: float) -> void:
	# Rolling along after a landing: pay the combo out once the moment to link something has passed
	if _grace >= 0.0 and live.is_empty():
		_grace -= delta
		if _grace < 0.0:
			bank()


func keep_going() -> void:
	_grace = -1.0


func bank() -> void:
	end_live()
	release_grab()
	_grace = -1.0
	if combo.is_empty():
		return
	var total := points() * multiplier()
	var what := names()
	score += total
	best_combo = maxi(best_combo, total)
	combo.clear()
	flip = {}
	banked.emit(total, what)
	changed.emit()


func wipeout(keep: float, keep_special: bool) -> void:
	# A bail. With keep > 0 (the forgiving assists) that much of the combo so far is still paid out; otherwise, or
	# with nothing done yet, it's lost. The trick she was in the middle of doesn't count either way.
	live = {}
	flip = {}
	grab = {}
	if keep <= 0.0 or combo.is_empty():
		var meter := special
		lose()
		if keep_special:
			special = meter
			changed.emit()
		return
	_grace = -1.0
	var total := int(points() * multiplier() * keep)
	var what := names()
	score += total
	best_combo = maxi(best_combo, total)
	combo.clear()
	if not keep_special:
		special = 0.0
	banked.emit(total, what)
	changed.emit()


func lose() -> void:
	var had := is_active()
	combo.clear()
	flip = {}
	grab = {}
	live = {}
	_grace = -1.0
	special = 0.0
	if had:
		lost.emit()
	changed.emit()
