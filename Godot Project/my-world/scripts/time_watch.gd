class_name TimeWatch
extends RefCounted

# The hero's own watch as the game's clock: which watch they have, what time it shows, and what it says when they
# check it (the check_watch key, T or D-pad down: scripts/hud.gd). scripts/watch_face.gd draws it.
#
# There's nothing new in the save: the watches are items the hero already gets (the Shift Watch on their first
# crossing, scripts/first_night.gd; the Time Keeper for all twenty lost watches, scripts/watches.gd), and the face
# follows whichever they're wearing. Before the first crossing there's no watch, so the HUD's clock is just words.

const SHIFT := "shift_watch"
const KEEPER := "time_keeper_watch"
const PENDANT := "time_keeper_pendant"


static func has_watch() -> bool:
	return Game.has_item("shop:" + SHIFT) or Game.has_item("shop:" + KEEPER) or Game.has_item("shop:" + PENDANT)


static func style() -> String:
	# "shift" (ticks Earth's way) or "keeper" (keeps your own time): the one they're wearing, else the best they own
	var hands := str(Game.outfit.get("hands", ""))
	var neck := str(Game.outfit.get("neck", ""))
	if hands == SHIFT:
		return "shift"
	if hands == KEEPER or neck == PENDANT:
		return "keeper"
	return "keeper" if Game.has_item("shop:" + KEEPER) or Game.has_item("shop:" + PENDANT) else "shift"


static func watch_name() -> String:
	return "Time Keeper" if style() == "keeper" else "Shift Watch"


static func shown_minutes() -> float:
	# What its big hands say: the Shift Watch always Earth's time, the Time Keeper the time where they are
	return Clock.earth_minutes if style() == "shift" else Clock.local_minutes()


static func other_minutes() -> float:
	# The Time Keeper's little dial: the other world's time
	return Clock.minutes if Clock.on_earth else Clock.earth_minutes


static func ripple_bearing() -> Variant:
	# Vector2(angle on the dial, metres) to the nearest time ripple the lab quest needs, seen from where the camera
	# looks (straight ahead is twelve o'clock), or null when there's none to find here (scripts/lab.gd)
	var lab := Watches.get_node_or_null("Lab")
	if lab == null:
		return null
	var at = lab.call("nearest_ripple")
	if at == null:
		return null
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group("player") as Node3D
	if player == null:
		return null
	var cam := player.get_viewport().get_camera_3d()
	var to: Vector3 = (at as Vector3) - player.global_position
	var flat := Vector2(to.x, to.z)
	var dist := flat.length()
	if cam:
		var local := cam.global_basis.inverse() * to
		return Vector2(atan2(local.x, -local.z), dist)
	return Vector2(atan2(to.x, -to.z), dist)


static func lines() -> Array[String]:
	# What checking the watch shows, a line each
	var out: Array[String] = []
	var keeper := style() == "keeper"
	out.append("%s: %s" % [watch_name(), "keeps your own time" if keeper else "ticks Earth's way"])
	out.append("Earth: %s, %s (Year %d)" % [Clock.date_string(), Clock.earth_time_string(), Clock.year()])
	if Clock.in_shift():
		var left := Clock.shift_minutes_left()
		out.append("Galaxity: day %d, %s" % [Clock.day, Clock.time_string()])
		out.append("The Shift: %s of Galaxity's day left before the portal pulls you home" % _span(left))
	elif Clock.on_earth:
		out.append("The portal by the old oak opens at midnight: %s to go" % _span(Clock.minutes_until_hour(Clock.SHIFT_START_HOUR)))
		if Festival.is_festival_day() and not Festival.is_on() and Clock.earth_minutes < Festival.start_time():
			out.append("The %s starts at %d PM today, on the green" % [Festival.fair_name(), int(Festival.fair().start) - 12])
		elif Festival.is_on():
			out.append("The %s is on, on the green!" % Festival.fair_name())
		if Festival.hallows_on():
			out.append("Hallow's Eve! Trick-or-treat on Maple Lane till 9 PM")
		var big := Festival.big_day()
		if big != "":
			out.append("Today it's %s: %s" % [Festival.BIG_DAYS[big].name, Festival.BIG_DAYS[big].where])
	else:
		out.append("Galaxity: day %d, %s (the portal's closed)" % [Clock.day, Clock.time_string()])
	var bearing = ripple_bearing()
	if bearing != null:
		out.append("It's humming: a time ripple, about %d m that way (follow the pink pointer)" % roundi(float(bearing.y)))
	elif Clock.in_shift() and not Clock.on_earth:
		out.append("Night %d in Galaxity" % Nights.night())
	return out


static func _span(game_minutes: float) -> String:
	var m := maxi(roundi(game_minutes), 0)
	var h := m / 60
	var mm := m % 60
	if h == 0:
		return "%d minute%s" % [mm, "" if mm == 1 else "s"]
	if mm == 0:
		return "%d hour%s" % [h, "" if h == 1 else "s"]
	return "%d hour%s %d minute%s" % [h, "" if h == 1 else "s", mm, "" if mm == 1 else "s"]
