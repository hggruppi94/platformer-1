extends Node

# Autoload "RideUpgrades": the hero's rides get better as they level up (Hayden, 7 Nov 2026: "new vehicle mechanics
# as you level up to hover and rocket boards/bikes, with the rocket ones capable of flight").
#
# Boards and bikes each go up in three steps (Rides.LINES): the plain one, a hover one (floats over water, goo can't
# slow it) and a rocket one (it flies: skate.gd, _fly). Each step has a level in Rides.HERO_RIDES ("level"): Zippy
# won't build it at the Tune-Up until the hero's that level (Game.level), on top of finding its schematic where it has
# one (scripts/schematics.gd). The Hover Bike has no schematic: it's the Bike made to float, so it needs the Bike.
# A ride an old save already has stays its own, whatever its level.
#
# Levels used to come only from popping enemies. So riding is worth experience too: a race (more for a better
# place), a skate run's medals, and every new gap. When a level-up opens a ride, Zippy says so.

const RACE_XP := [25, 15, 10, 6]             # 1st, 2nd, 3rd, and anything after
const MEDAL_XP := [8, 12, 20]                # bronze, silver, gold (each the first time it's won)
const GAP_XP := 5                            # a gap landed for the first time

var _medals_before := {}                     # skate run id -> medals before this run, to pay only new ones


func _ready() -> void:
	Game.leveled_up.connect(_on_level_up)
	Races.finished.connect(_on_race)
	Gaps.found.connect(func(_id: String) -> void: Game.add_xp(GAP_XP))
	SkateRuns.finished.connect(_on_run)


func level_for(r: String) -> int:
	return int(Rides.HERO_RIDES.get(r, {}).get("level", 0))


func level_ok(r: String) -> bool:
	return Game.level >= level_for(r) or Schematics.owns_ride(r)


func needs_ok(r: String) -> bool:
	var need := str(Rides.HERO_RIDES.get(r, {}).get("needs", ""))
	return need == "" or Schematics.owns_ride(need)


func ready_to_build(r: String) -> bool:
	# Zippy can build it now: schematic found (if it has one), the level reached, the ride it needs owned
	return not Schematics.owns_ride(r) and Schematics.ride_unlocked(r) and level_ok(r) and needs_ok(r)


func xp_to_level(n: int) -> int:
	# How much more experience until the hero's Lv n (0 when they're there)
	if Game.level >= n:
		return 0
	var need := Game.xp_to_next() - Game.xp
	for l in range(Game.level + 1, n):
		need += 10 * l
	return need


func lock_line(r: String) -> String:
	# Why Zippy can't build it yet, for the Tune-Up, or "" if nothing about levels stops it
	if Schematics.owns_ride(r):
		return ""
	var need := str(Rides.HERO_RIDES.get(r, {}).get("needs", ""))
	if need != "" and not Schematics.owns_ride(need):
		return "Needs the %s first" % str(Rides.HERO_RIDES[need].name)
	if not level_ok(r):
		return "Reach Lv %d" % level_for(r)
	return ""


func level_note(r: String) -> String:
	# The line under a level-locked ride in the shop
	if Schematics.owns_ride(r) or level_ok(r):
		return ""
	return "[Lv %d] You're Lv %d: %d XP to go." % [
		level_for(r), Game.level, xp_to_level(level_for(r))]


func tier(r: String) -> String:
	var ride: Dictionary = Rides.HERO_RIDES.get(r, {})
	if ride.get("flight", false):
		return "Rocket: flies"
	if ride.get("hover", false):
		return "Hover: floats over water"
	return ""


func _on_level_up(lv: int) -> void:
	# A ride that just opened (and can be built now), once each
	for r in Rides.HERO_ORDER:
		if level_for(str(r)) == lv and ready_to_build(str(r)):
			Game.message("Lv %d! Zippy can build the %s!" % [lv,
				str(Rides.HERO_RIDES[r].name)])


func _on_race(_id: String, place: int) -> void:
	Game.add_xp(int(RACE_XP[clampi(place - 1, 0, RACE_XP.size() - 1)]))


func _on_run(run_id: String, _score: int) -> void:
	# SkateRuns has already counted this run's medals by now, so compare with what it had when the run began
	var now := int(SkateRuns.medals.get(run_id, 0))
	var had := int(_medals_before.get(run_id, 0))
	var xp := 0
	for k in range(had, now):
		xp += int(MEDAL_XP[clampi(k, 0, MEDAL_XP.size() - 1)])
	_medals_before[run_id] = now
	if xp > 0:
		Game.add_xp(xp)


func _process(_delta: float) -> void:
	# Remember each run's medals before a run starts (cheap: a handful of keys)
	if not SkateRuns.running():
		for k in SkateRuns.RUNS:
			_medals_before[k] = int(SkateRuns.medals.get(k, 0))
