extends Node

# Autoload "Clock": the time of day on Earth and in Galaxity. Lives across every scene and keeps running indoors.
#
# The player lives on Earth (scenes/earth/earth.tscn), and Earth's clock (earth_minutes) is the one that always runs:
# an Earth hour every EARTH_HOUR_SECONDS real seconds. Every night from midnight to 1 AM, Earth time, is the Shift:
# the portal by the old oak opens to Galaxity, just like in the show.
#
# Galaxity's clock (day, minutes) only moves during the Shift. That one Earth hour lasts a whole Galaxity day: Galaxity
# runs a day in DAY_LENGTH_MINUTES real minutes, and Earth's clock crawls along with it (SHIFT_RATIO Galaxity minutes
# to each Earth minute), wherever the player is. Each Shift starts at dawn in Galaxity (DAWN_HOUR) and ends at dawn the
# next day, so Galaxity is always waiting at dawn between visits, and its day number goes up by one each visit.
# When the Shift ends, the portal pulls the player home to Earth from wherever they are in Galaxity.
#
# The days and times are saved with the rest of the game (scripts/game.gd). Sleeping in a bed (scripts/bed.gd) moves
# the clock on (Clock.sleep()). Other scripts read it (Clock.hour(), Clock.daylight(), Clock.in_shift()) or listen to
# its signals.

signal time_changed                  # every new in-game minute
signal hour_changed(hour: int)
signal day_changed(day: int)
signal shift_started
signal shift_ended
signal jumped                        # the time jumped instead of ticking on (sleeping, loading a save)

const DAY_LENGTH_MINUTES := 20.0     # real minutes for one whole Galaxity day (one Shift)
const SHIFT_START_HOUR := 0          # the Shift, on Earth's clock: midnight...
const SHIFT_END_HOUR := 1            # ...to 1 AM
const DAWN_HOUR := 7                 # Galaxity's day in the Shift runs from 7 AM to 7 AM
const START_HOUR := 7.0              # a new game's Galaxity is waiting at dawn on day 1
const WAKE_HOUR := 7                 # sleeping until morning wakes her at 7:00 AM
const MINUTES_PER_DAY := 24 * 60
const SHIFT_RATIO := float(MINUTES_PER_DAY) / ((SHIFT_END_HOUR - SHIFT_START_HOUR) * 60.0)   # Galaxity min per Earth min
const EARTH_HOUR_SECONDS := 60.0     # outside the Shift, an Earth hour takes a real minute
const EARTH_START := 20 * 60.0       # a new game starts at 8:00 PM on Earth, a few hours before the first Shift
const WARN_HOUR := 6                 # Galaxity's 6 AM in the Shift: "the portal will pull you home soon"
const EARTH := "res://scenes/earth/earth.tscn"
const EARTH_ARRIVAL := "Entrance"    # where the portal puts the player on Earth: by the old oak
const WEEKDAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const FIRST_WEEKDAY := 4             # Earth's day 1 is a Friday, so the first Autumn Festival is the next evening
# Earth's calendar: four seasons of four weeks each (a real year would be hundreds of hours of play, so Sofi would
# never see the snow). Every season starts on a Monday, so a date is always the same day of the week ("Saturday 27
# Autumn" every year). A new game starts on Friday 19 Autumn, a week before Hallow's Eve.
const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_DAYS := 28
const YEAR_DAYS := SEASON_DAYS * 4
const CALENDAR_START := 2 * SEASON_DAYS + 18   # calendar days before Earth's day 1 (so day 1 is 19 Autumn, Year 1)
const TODAY := -(1 << 40)            # "on_day" left out: today (any real number is a day, even before day 1)

var day := 1                         # Galaxity's day
var minutes := START_HOUR * 60.0     # Galaxity's time: minutes since midnight, 0..1440
var running := true                  # false to stop the clock (e.g. during the sleep fade)
var on_earth := false                # set by the Earth scene while she's there
var earth_minutes := EARTH_START     # Earth's time of day (saved)
var pulls_home := true               # when the Shift ends in Galaxity, the portal pulls her home (tests can turn it off)
var pull_spawn := ""                 # where on Earth that puts them, if not by the oak (the First Night: in bed, HomeSpawn)
var calendar_offset := CALENDAR_START  # saved: older saves from before the calendar get one that puts them in autumn

var _in_shift := false
var _last_minute := -1
var _last_hour := -1
var _pulling := false


func _ready() -> void:
	_in_shift = in_shift()
	_last_minute = int(minutes)
	_last_hour = hour()


func _process(delta: float) -> void:
	if not running:
		return
	if in_shift():
		# (no further than the end of the Shift, so it always ends right on Galaxity's dawn)
		var game_minutes := delta * MINUTES_PER_DAY / (DAY_LENGTH_MINUTES * 60.0)
		if game_minutes >= shift_minutes_left() - 0.0001:
			_finish_shift()
			_check_changes()
			return
		earth_minutes += game_minutes / SHIFT_RATIO
		_advance(game_minutes)
	else:
		earth_minutes = fposmod(earth_minutes + delta * 60.0 / EARTH_HOUR_SECONDS, MINUTES_PER_DAY)
		if in_shift() and not _in_shift:
			_to_dawn()                               # midnight on Earth: Galaxity's day begins
		_check_changes()


func _advance(game_minutes: float) -> void:
	minutes += game_minutes
	while minutes >= MINUTES_PER_DAY:
		minutes -= MINUTES_PER_DAY
		day += 1
		day_changed.emit(day)
	_check_changes()


func _check_changes(announce := true) -> void:
	var m := int(local_minutes())
	if m != _last_minute:
		_last_minute = m
		time_changed.emit()
	var h := hour()
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
		if announce and h == WARN_HOUR and in_shift() and not on_earth:
			Game.message("The sky's getting light. At 7 AM the Shift ends, and the portal will pull you home to Earth.")
	var shift := in_shift()
	if shift != _in_shift:
		_in_shift = shift
		if announce:
			if shift:
				Game.message("It's midnight: the Shift has begun! The portal by the old oak is open to Galaxity.")
			elif on_earth:
				Game.message("1 AM: the Shift is over, and the portal has closed until tomorrow night.")
		(shift_started if shift else shift_ended).emit()
		if not shift:
			_pull_home()


func _to_dawn() -> void:
	# A Shift starts at Galaxity's dawn. It's already waiting there after the last one, but an old save (or a sleep
	# through a whole Shift on Earth) can leave it somewhere else: move it on to the next dawn.
	var wait := fposmod(DAWN_HOUR * 60.0 - minutes, MINUTES_PER_DAY)
	if wait > 0.01 and wait < MINUTES_PER_DAY - 0.01:
		var total := minutes + wait
		day += int(total / MINUTES_PER_DAY)
		minutes = fposmod(total, MINUTES_PER_DAY)
		day_changed.emit(day)


func _pull_home() -> void:
	if on_earth or not pulls_home or _pulling:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == EARTH or get_tree().get_first_node_in_group("player") == null:
		return
	_pulling = true
	Game.pending_message = "The Shift is over! The portal swirls up and pulls %s home to Earth." % Dialogue.player_name()
	if pull_spawn != "":
		# The first night ends in bed (scripts/first_night.gd says what happened once Earth's up)
		Game.pending_message = ""
		FirstNight.pulled_home()
	Game.go(EARTH, pull_spawn if pull_spawn != "" else EARTH_ARRIVAL, "Earth")
	_done_pulling.call_deferred()


func _done_pulling() -> void:
	await get_tree().process_frame
	_pulling = false


# -----------------------------------------------------------------------------
# Reading the time
# -----------------------------------------------------------------------------
func hour() -> int:
	# The hour where she is: Earth's on Earth, Galaxity's in Galaxity
	return int(local_minutes() / 60.0) % 24


func minute() -> int:
	return int(local_minutes()) % 60


func hours() -> float:
	# Galaxity's time as a fraction of hours, e.g. 18.5 for 6:30 PM (its sky and lamps follow it)
	return minutes / 60.0


func local_minutes() -> float:
	return earth_minutes if on_earth else minutes


func earth_time_string() -> String:
	return format_time(earth_minutes)


func earth_day() -> int:
	# Earth's day number. Galaxity's day goes up once a Shift (at its own midnight, partway through), so from Earth's
	# midnight until then Earth is already a day ahead of it. A new game starts on Earth's day 1, a Friday evening.
	return day + 1 if in_shift() and minutes >= DAWN_HOUR * 60.0 else day


func weekday(on_day := TODAY) -> String:
	# "Friday" for Earth's day 1, then round the week (the Autumn Festival is on Saturdays: scripts/festival.gd)
	return WEEKDAYS[calendar_index(on_day) % 7]


# --- Earth's calendar ----------------------------------------------------------
func calendar_index(on_day := TODAY) -> int:
	# Days since Monday 1 Spring, Year 1 (the weekday and the date both come from it)
	var d := earth_day() if on_day == TODAY else on_day
	return maxi(d - 1 + calendar_offset, 0)


func season(on_day := TODAY) -> String:
	# "spring", "summer", "autumn" or "winter" on Earth (Galaxity has no seasons: it's outside time)
	return SEASONS[(calendar_index(on_day) / SEASON_DAYS) % 4]


func season_name(on_day := TODAY) -> String:
	return season(on_day).capitalize()


func season_day(on_day := TODAY) -> int:
	# 1..28: the date within the season
	return calendar_index(on_day) % SEASON_DAYS + 1


func year(on_day := TODAY) -> int:
	return calendar_index(on_day) / YEAR_DAYS + 1


func date_string(on_day := TODAY) -> String:
	# "Friday 19 Autumn"
	return "%s %d %s" % [weekday(on_day), season_day(on_day), season_name(on_day)]


func day_of(season_id: String, date: int, after_day := TODAY) -> int:
	# The Earth day number of the next season_id date (today counts), e.g. day_of("winter", 1) for the first snow
	var from := earth_day() if after_day == TODAY else after_day
	var want := SEASONS.find(season_id) * SEASON_DAYS + clampi(date, 1, SEASON_DAYS) - 1
	return from + posmod(want - calendar_index(from) % YEAR_DAYS, YEAR_DAYS)


func is_weekend(on_day := TODAY) -> bool:
	return calendar_index(on_day) % 7 >= 5


func school_holiday(on_day := TODAY) -> String:
	# The name of the school holiday on that day, or "" (weekends aren't holidays: is_school_day() asks both)
	var s := season(on_day)
	var date := season_day(on_day)
	if s == "summer":
		return "the summer holidays"
	if s == "winter" and date >= 22:
		return "the winter holidays"
	if s == "spring" and date >= 8 and date <= 14:
		return "spring break"
	return ""


func is_school_day(on_day := TODAY) -> bool:
	# Old Oak Elementary is open Monday to Friday, outside the holidays (kids' routines: scripts/routine.gd)
	return not is_weekend(on_day) and school_holiday(on_day) == ""


func fit_calendar_to_old_save() -> void:
	# A save from before the calendar: keep its day of the week and put it in the week of 19 Autumn, so the town
	# (dressed for autumn) and the Autumn Festival stay as they were
	var d := earth_day() - 1
	calendar_offset = 2 * SEASON_DAYS + 14 + (d + CALENDAR_START) % 7 - d   # (Monday 15 Autumn starts that week)


func in_shift() -> bool:
	return earth_minutes >= SHIFT_START_HOUR * 60.0 and earth_minutes < SHIFT_END_HOUR * 60.0


func shift_minutes_left() -> float:
	# Galaxity minutes until the Shift ends (0 outside it)
	return maxf(SHIFT_END_HOUR * 60.0 - earth_minutes, 0.0) * SHIFT_RATIO if in_shift() else 0.0


func daylight() -> float:
	# Galaxity's light: 0 at night, 1 in the day, easing through dawn (5-8 AM) and dusk (5:30-8:30 PM)
	var h := hours()
	return smoothstep(5.0, 8.0, h) * (1.0 - smoothstep(17.5, 20.5, h))


func period() -> String:
	# The part of the day where she is, by name: "morning" (5-11), "day" (11-5 PM), "evening" (5-9 PM), "night"
	# (9 PM-5 AM), or "shift" (which is also night): on Earth, the Shift itself; in Galaxity, its midnight hour, when the
	# portal glows its brightest. Dialogue lines can depend on it (scripts/dialogue.gd).
	var h := hour()
	if h == 0 and (in_shift() or not on_earth):
		return "shift"
	if h >= 5 and h < 11:
		return "morning"
	if h >= 11 and h < 17:
		return "day"
	if h >= 17 and h < 21:
		return "evening"
	return "night"


static func parse_time(text: String) -> float:
	# "07:30" (or "7:30") -> minutes since midnight
	var parts := text.split(":")
	return int(parts[0]) * 60.0 + (int(parts[1]) if parts.size() > 1 else 0)


func is_night() -> bool:
	return daylight() < 0.35


func time_string() -> String:
	# Galaxity's 12-hour time, e.g. "7:05 PM"
	return format_time(minutes)


static func format_time(at_minutes: float) -> String:
	var m := int(fposmod(at_minutes, MINUTES_PER_DAY))
	var h := m / 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m % 60, "AM" if h < 12 else "PM"]


func minutes_until_hour(h: int) -> float:
	# How long until the clock where she is next reads h:00 (a whole day if it's exactly h:00 now)
	var wait := fposmod(h * 60.0 - local_minutes(), MINUTES_PER_DAY)
	return wait if wait > 0.0 else float(MINUTES_PER_DAY)


func sleep_length(want_minutes: float) -> float:
	# How long a sleep of want_minutes really lasts. On Earth, one that would run past midnight stops there, so she
	# never sleeps through the Shift without knowing (already in it, she can sleep on). In Galaxity, sleep can't last
	# past the end of the Shift: she wakes up back home on Earth.
	if not on_earth:
		return minf(want_minutes, shift_minutes_left()) if in_shift() else want_minutes
	if in_shift():
		return want_minutes
	return minf(want_minutes, minutes_until_hour(SHIFT_START_HOUR))


# -----------------------------------------------------------------------------
# Changing the time
# -----------------------------------------------------------------------------
func set_time(new_day: int, new_minutes: float, quiet := false) -> void:
	# Jump Galaxity's clock straight to a time. Signals for anything that changed fire (no Shift messages if quiet, e.g.
	# on loading). Away from Earth it's always the Shift, so Earth's clock moves to the matching moment of it.
	var old_day := day
	day = maxi(new_day, 1)
	minutes = fposmod(new_minutes, MINUTES_PER_DAY)
	if not on_earth:
		earth_minutes = SHIFT_START_HOUR * 60.0 + fposmod(minutes - DAWN_HOUR * 60.0, MINUTES_PER_DAY) / SHIFT_RATIO
	_in_shift = in_shift()                           # (a jump inside Galaxity isn't a Shift starting)
	if day != old_day:
		day_changed.emit(day)
	_check_changes(not quiet)
	time_changed.emit()
	jumped.emit()


func set_earth_time(new_minutes: float, quiet := false) -> void:
	# Jump Earth's clock straight to a time. Galaxity's waits at dawn for the Shift; landing inside the Shift moves it
	# on to the matching moment of that day.
	var was_shift := in_shift()
	earth_minutes = fposmod(new_minutes, MINUTES_PER_DAY)
	if in_shift() and not was_shift:
		_to_dawn()
		var total := minutes + (earth_minutes - SHIFT_START_HOUR * 60.0) * SHIFT_RATIO
		day += int(total / MINUTES_PER_DAY)
		minutes = fposmod(total, MINUTES_PER_DAY)
	_check_changes(not quiet)
	time_changed.emit()
	jumped.emit()


func advance(game_minutes: float) -> void:
	# Jump Galaxity's clock forward, into the next days if need be. Quiet: whoever jumped says what happened.
	var total := minutes + game_minutes
	set_time(day + int(total / MINUTES_PER_DAY), total, true)


func sleep(length: float) -> void:
	# Sleep for length minutes where she is (scripts/bed.gd works it out with sleep_length()). A sleep in Galaxity that
	# reaches the end of the Shift ends it, and the portal brings her home.
	if on_earth:
		var before := earth_minutes
		var was_shift := in_shift()
		if was_shift:
			# In the Shift, Earth's clock crawls: the sleep runs on Galaxity's time, and may end the Shift
			var left := shift_minutes_left()
			if length >= left:
				end_shift()
				earth_minutes = fposmod(before + length / SHIFT_RATIO, MINUTES_PER_DAY)
				time_changed.emit()
				return
			_advance(length)
			earth_minutes += length / SHIFT_RATIO
			_check_changes(false)
			time_changed.emit()
			jumped.emit()
			return
		set_earth_time(before + length, true)
	elif in_shift() and length >= shift_minutes_left() - 0.01:
		end_shift()
	else:
		advance(length)


func end_shift() -> void:
	# The Shift is over: Earth's 1 AM, Galaxity's dawn, and (in Galaxity) the portal pulls her home
	if not in_shift():
		return
	_finish_shift()
	jumped.emit()
	_check_changes(false)


func _finish_shift() -> void:
	# Galaxity on to its dawn (exactly: no rounding left over to make it read 6:59), Earth to 1 AM
	var wait := fposmod(DAWN_HOUR * 60.0 - minutes, MINUTES_PER_DAY)
	if wait > MINUTES_PER_DAY - 0.01:
		wait = 0.0                                   # (already there, give or take a rounding)
	if minutes + wait >= MINUTES_PER_DAY - 0.001:
		day += 1
		day_changed.emit(day)
	minutes = DAWN_HOUR * 60.0
	earth_minutes = SHIFT_END_HOUR * 60.0


func sleep_until_morning() -> void:
	# Galaxity's next WAKE_HOUR: later today if it's still before it (sleeping at 3 AM), otherwise tomorrow
	var wait := fposmod(WAKE_HOUR * 60.0 - minutes, MINUTES_PER_DAY)
	advance(wait if wait > 0.0 else float(MINUTES_PER_DAY))


func reset() -> void:
	# A new game: Galaxity waiting at dawn on day 1, an evening at home on Earth
	var was_on_earth := on_earth
	on_earth = true                                  # (so setting Galaxity's time leaves Earth's alone)
	set_time(1, START_HOUR * 60.0, true)
	on_earth = was_on_earth
	earth_minutes = EARTH_START
	calendar_offset = CALENDAR_START
	_in_shift = in_shift()
	_check_changes(false)
