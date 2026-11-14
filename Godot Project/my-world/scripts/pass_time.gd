extends RefCounted

# "Pass the time" (Hayden, 13 Nov 2026: "There's a lot locked behind time. We need to make the game playable all the
# way through without forcing the player to wait"). No class_name: preload it.
#
# The pause menu's "Pass the time" page (scripts/pause_menu.gd) lists where the clock can jump to from here: the next
# morning, noon, evening or night, the crack opening at midnight and the next Saturday fair on Earth; in the Void, any part of its day that's
# left in the Shift, or dawn, when the portal takes you home. Pick one and the screen fades, the clock races round,
# and the world carries on from then: people are where their routines say (they listen for Clock.jumped), crops have
# grown, waits are over. It's the bed's sleep (scripts/bed.gd) without walking home to bed, and without the rest.
#
# On Earth, "Go to the Void at midnight" (pause_menu.gd way_home()) passes the time to the Shift and goes straight
# through the crack, so getting back to the Void after being pulled home is one button.
#
# It keeps the story's rules: before the first fall nothing mentions the crack, the Shift or the Void
# (HummingOak.awake()); on The First Night's first day Earth's clock still stops at 6 PM until the town and the board
# are done, and on its evening every wait stops at midnight, when the ground cracks open (scripts/void_arrival.gd).
# Not in a portal world or on a race circuit (their clocks stand still), not mid-race, not in a cutscene or a talk.

const FADE := 0.6                     # seconds to fade out, and back in
const SPIN := 1.3                     # seconds of the clock racing round on the dark screen
const MIN_WAIT := 5.0                 # game minutes: anything shorter isn't worth a button

# Where the clock can jump to: [hour, name]. On Earth the day; in the Void what's left of the Shift's day, which runs
# from 7 AM to 7 AM (so its "early morning" is 5 AM, just before the Shift ends).
const EARTH_STOPS := [[7, "morning"], [12, "noon"], [18, "evening"], [21, "night"]]
const VOID_STOPS := [[12, "noon"], [17, "evening"], [21, "night"], [0, "midnight"], [5, "early morning"]]


static func why_not() -> String:
	# "" when the time can be passed here and now, otherwise why not (for tests and the debugger)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null or Game.on_title():
		return "no game"
	var player := tree.get_first_node_in_group("player")
	if player == null:
		return "no player"
	if Portals.practice or Portals.here != "":
		return "in a portal world"
	if Races.circuit != "" or Races.racing():
		return "racing"
	if not Clock.running:
		return "the clock's stopped"
	if not Clock.on_earth and not Clock.in_shift():
		return "the Void outside the Shift"
	if Dialogue.is_active():
		return "talking"
	if FirstNight.is_arriving():
		return "arriving"
	for group in ["cutscene_playing", "goodbye_playing"]:
		if not tree.get_nodes_in_group(group).is_empty():
			return "a cutscene"
	if player.has_method("input_locks") and not (player.input_locks() as Array).is_empty():
		return "busy (%s)" % ", ".join((player.input_locks() as Array).map(func(w): return str(w)))
	return ""


static func can_pass() -> bool:
	return why_not() == "" and not choices().is_empty()


static func choices() -> Array:
	# [{"text", "minutes"}] for the page's buttons, soonest first. "minutes" is how far the clock really moves.
	var out := []
	var seen := {}
	if Clock.on_earth and Clock.in_shift():
		return out                                   # (the crack's open: the way to go is through it, not waiting)
	if Clock.on_earth:
		var hold := FirstNight.earth_hold_minutes()   # (-1: none) the First Night's first day stops at 6 PM
		var stops := EARTH_STOPS.duplicate()
		if FirstNight.shift_sleep_ok():
			stops.append([Clock.SHIFT_START_HOUR, "midnight"])
		for s in stops:
			var want := Clock.minutes_until_hour(int(s[0]))
			var length := want
			# The first night every wait stops at midnight (the fall). Otherwise only the midnight stop stops there:
			# choosing morning at 10 PM is a clear choice to skip tonight's Shift, like the bed's "Until morning".
			if FirstNight.sleep_stops_at_midnight() and not Clock.in_shift():
				length = minf(length, Clock.minutes_until_hour(Clock.SHIFT_START_HOUR))
			if hold >= 0.0:
				length = minf(length, maxf(hold - Clock.earth_minutes, 0.0))
			_add(out, seen, length, _earth_text(str(s[1]), length, length < want))
		# And the next Saturday fair on the green, so nobody waits for the weekend (scripts/festival.gd)
		var k := Festival.days_until()
		if not FirstNight.running() and k >= 0 and not Festival.is_on() and (k > 0 or Clock.earth_minutes < Festival.start_time()):
			var day := Clock.earth_day() + k
			var length := k * float(Clock.MINUTES_PER_DAY) + float(Festival.fair(day).start) * 60.0 - Clock.earth_minutes
			_add(out, seen, length, "Until the %s (%s, %s)" % [Festival.fair_name(day), Clock.weekday(day),
				Clock.format_time(float(Festival.fair(day).start) * 60.0)])
	elif Clock.in_shift():
		var left := Clock.shift_minutes_left()
		for s in VOID_STOPS:
			var want := Clock.minutes_until_hour(int(s[0]))
			if want < left - MIN_WAIT:
				_add(out, seen, want, "Until %s (%s)" % [s[1], Clock.format_time(Clock.minutes + want)])
		# The end of the Shift: the portal takes them home (the First Night: a hint only, as the 6 AM message is)
		_add(out, seen, left, "Until the sky gets light" if FirstNight.running() else "Until dawn: home to Earth")
	out.sort_custom(func(a, b): return float(a.minutes) < float(b.minutes))
	return out


static func _add(out: Array, seen: Dictionary, length: float, text: String) -> void:
	if length < MIN_WAIT:
		return
	var key := roundi(length)
	if seen.has(key):
		return                                       # (two stops that end up at the same time: the first one wins)
	seen[key] = true
	out.append({"text": text, "minutes": length})


static func _earth_text(stop: String, length: float, cut_short := false) -> String:
	var at := Clock.format_time(Clock.earth_minutes + length)
	if roundi(fposmod(Clock.earth_minutes + length, Clock.MINUTES_PER_DAY)) == Clock.SHIFT_START_HOUR * 60:
		# Midnight: once they've seen the crack open it's the Shift. Before the first fall nothing says why it stops
		# there (like the bed): it's just late.
		if HummingOak.awake() and FirstNight.shift_sleep_ok():
			return "Until the crack opens (%s)" % at
		return "Until late at night (%s)" % at
	if cut_short:
		return "Until %s (%s)" % ["the evening" if roundi(length + Clock.earth_minutes) % Clock.MINUTES_PER_DAY == 18 * 60
			else "later", at]
	return "Until %s (%s)" % [stop, at]


static func to_the_shift_ok() -> bool:
	# The quick way back to the Void from Earth: once they've been through, any time outside the Shift
	return Clock.on_earth and not Clock.in_shift() and HummingOak.awake() and FirstNight.shift_sleep_ok() \
		and why_not() == ""


static func go_to_the_void() -> void:
	# Pass the time to midnight, then straight through the crack (pause_menu.gd way_home())
	run(Clock.minutes_until_hour(Clock.SHIFT_START_HOUR), func() -> void:
		if Clock.in_shift():
			Game.go(Game.TOWN_SCENE, "FromPortaltoEarth", "Void"))


static func run(length: float, then := Callable()) -> void:
	# Fade out, move the clock on by length game minutes, fade back in (then calls then, if it's given)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or length <= 0.0:
		return
	var from := Clock.local_minutes()
	var on_earth := Clock.on_earth
	var ends_shift := not Clock.on_earth and Clock.in_shift() and length >= Clock.shift_minutes_left() - 0.01
	tree.paused = true
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.name = "PassTime"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.02, 0.1)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.modulate.a = 0.0
	layer.add_child(dark)
	var text := Label.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", roundi(40 * Settings.text_scale))
	text.add_theme_color_override("font_color", Color(1, 0.95, 1))
	dark.add_child(text)
	tree.root.add_child(layer)
	Audio.play("ui_back", -6.0)

	# The clock races round on the dark screen (just the words: the real clock jumps once, at the end)
	var show := func(k: float) -> void:
		text.text = "Time passes...\n\n%s" % Clock.format_time(from + length * k)
	show.call(0.0)
	var tw := layer.create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, FADE)
	tw.tween_method(show, 0.0, 1.0, SPIN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		tree.paused = false
		if ends_shift:
			# The end of the Shift: the portal takes them home (scripts/clock.gd), and the scene goes with it
			layer.queue_free()
			Clock.sleep(length)
			return
		Clock.sleep(length)
		Game.save_game()
		tree.paused = true)
	tw.tween_interval(0.25)
	tw.tween_property(dark, "modulate:a", 0.0, FADE)
	tw.tween_callback(func() -> void:
		tree.paused = false
		layer.queue_free()
		if then.is_valid():
			then.call()
		elif _after_text(on_earth) != "":
			Game.message(_after_text(on_earth)))


static func _after_text(was_on_earth: bool) -> String:
	if Clock.on_earth and Clock.in_shift():
		# (before the first fall the fall itself says it all: scripts/void_arrival.gd)
		return "" if not HummingOak.awake() else \
			"It's midnight: the Shift has begun, and the crack by the old oak is open."
	if was_on_earth:
		return "Time flies! It's %s on Earth." % Clock.earth_time_string()
	return "Time flies! It's %s in the Void." % Clock.time_string()
