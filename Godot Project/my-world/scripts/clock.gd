extends Node

# Autoload "Clock": the time of day in Galactopia. Lives across every scene and keeps running indoors.
#
# A whole day takes DAY_LENGTH_MINUTES real minutes. Every night from 12:00 to 1:00 AM is the Shift: the portal opens,
# and time in Galactopia slows down (the clock runs SHIFT_SLOWDOWN times slower), just like in the show.
# The day and time are saved with the rest of the game (scripts/game.gd). Sleeping in a bed jumps to WAKE_HOUR.
#
# Other scripts read it (Clock.hour(), Clock.daylight(), Clock.in_shift()) or listen to its signals.

signal time_changed                  # every new in-game minute
signal hour_changed(hour: int)
signal day_changed(day: int)
signal shift_started
signal shift_ended

const DAY_LENGTH_MINUTES := 20.0     # real minutes for one whole in-game day
const SHIFT_START_HOUR := 0          # the Shift: midnight...
const SHIFT_END_HOUR := 1            # ...to 1 AM
const SHIFT_SLOWDOWN := 4.0          # the clock runs this many times slower during the Shift
const START_HOUR := 8.0              # a new game starts at 8:00 AM on day 1
const WAKE_HOUR := 7                 # sleeping wakes her at 7:00 AM
const MINUTES_PER_DAY := 24 * 60

var day := 1
var minutes := START_HOUR * 60.0     # minutes since midnight, 0..1440
var running := true                  # false to stop the clock (e.g. during the sleep fade)

var _in_shift := false
var _last_minute := -1
var _last_hour := -1


func _ready() -> void:
	_in_shift = in_shift()
	_last_minute = int(minutes)
	_last_hour = hour()


func _process(delta: float) -> void:
	if not running:
		return
	var game_minutes_per_second := MINUTES_PER_DAY / (DAY_LENGTH_MINUTES * 60.0)
	if _in_shift:
		game_minutes_per_second /= SHIFT_SLOWDOWN
	_advance(delta * game_minutes_per_second)


func _advance(game_minutes: float) -> void:
	minutes += game_minutes
	while minutes >= MINUTES_PER_DAY:
		minutes -= MINUTES_PER_DAY
		day += 1
		day_changed.emit(day)
	_check_changes()


func _check_changes(announce := true) -> void:
	var m := int(minutes)
	if m != _last_minute:
		_last_minute = m
		time_changed.emit()
	var h := hour()
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	var shift := in_shift()
	if shift != _in_shift:
		_in_shift = shift
		if announce:
			Game.message("It's midnight: the Shift has begun! Time slows down... and the portal is open." if shift
				else "The Shift is over. The portal has closed.")
		(shift_started if shift else shift_ended).emit()


# -----------------------------------------------------------------------------
# Reading the time
# -----------------------------------------------------------------------------
func hour() -> int:
	return int(minutes / 60.0) % 24


func minute() -> int:
	return int(minutes) % 60


func hours() -> float:
	# The time as a fraction of hours, e.g. 18.5 for 6:30 PM
	return minutes / 60.0


func in_shift() -> bool:
	return hour() >= SHIFT_START_HOUR and hour() < SHIFT_END_HOUR


func daylight() -> float:
	# 0 at night, 1 in the day, easing through dawn (5-8 AM) and dusk (5:30-8:30 PM)
	var h := hours()
	return smoothstep(5.0, 8.0, h) * (1.0 - smoothstep(17.5, 20.5, h))


func is_night() -> bool:
	return daylight() < 0.35


func time_string() -> String:
	# 12-hour time, e.g. "7:05 PM"
	var h := hour()
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute(), "AM" if h < 12 else "PM"]


# -----------------------------------------------------------------------------
# Changing the time
# -----------------------------------------------------------------------------
func set_time(new_day: int, new_minutes: float, quiet := false) -> void:
	# Jump straight to a time. Signals for anything that changed fire (no Shift messages if quiet, e.g. on loading).
	var old_day := day
	day = maxi(new_day, 1)
	minutes = fposmod(new_minutes, MINUTES_PER_DAY)
	if day != old_day:
		day_changed.emit(day)
	_check_changes(not quiet)
	time_changed.emit()


func sleep_until_morning() -> void:
	# Next WAKE_HOUR: later today if it's still before it (sleeping at 3 AM), otherwise tomorrow
	var wake := WAKE_HOUR * 60.0
	set_time(day if minutes < wake else day + 1, wake, true)


func reset() -> void:
	set_time(1, START_HOUR * 60.0, true)
