extends Node

# Autoload "DivineMind": the voice of the Divine Mind (Hayden, 12 Nov 2026, lore bible v2 part 2 and part 3 items 2
# and 3). The ultimate good, a giant god-like brain that chooses the chosen ones every time the Shift breaks. It is
# never shown: it speaks to the hero inside their mind, wherever they are, when they need it. The Humming Oak on Earth
# hums because the Divine Mind is there, and touching the oak asks it for a hint (scripts/humming_oak.gd calls hint()).
#
# say() shows its words softly at the top of the screen, a line at a time, without stopping play (a talk would hold the
# controls, and a voice in your head doesn't). It speaks when a crack opens (scripts/portals.gd quake()), when a world's
# time is put right (Portals.clear()) and at the oak. Its hints only ever point at what has already happened or what
# the player is already doing, never at what's coming (Hayden's no-spoilers rule, 10 Nov 2026), and it is only ever
# called "a voice in your mind" in the game: who it is stays a mystery the story can tell.

signal spoke(text: String)

const SPEAKER := "A voice in your mind"

# Everything it says. They're spoken aloud too (Hayden, 14 Nov 2026: "can we give the brain dialogue in your mind a
# voice?"): each line has its own .ogg in VOICE_DIR, made by tools/make_mind_voice.py from the list that
# tools/dump_mind_lines.gd writes (all_lines() below). A line with no file yet is just shown, as before. If you change
# or add a line, run both tools again.
const ARRIVAL := "Don't be afraid. You're exactly where you're meant to be."
const CRACK_OPENED := ["Feel that? A new crack opened.", "A world needs you!"]
const MENDED := "Well done. %s is mended."
const OAK_FIRST := "Don't be afraid. I chose you, {player}. Whenever you're lost, come and touch the old oak, and I'll help you find the way."
const HINT_CRACK := "A crack lies open in the Void, by %s. Time is broken on the other side."
const HINT_FRIEND := "Jump in. Someone there is waiting for a friend."
const HINT_FIX := "Jump in. Put it right."
const HINT_GOAL := "Remember what you set out to do..."
const HINT_REST := "Rest, and be with the people you love. The ground here is open, whenever you're ready."
const HINT_LOOK := "Look around you. Help where you can. When you're needed, I will tell you."
const VOICE_DIR := "res://audio/mind/"
const VOICE_TAIL := 0.6                # seconds a spoken line stays up after the voice stops
const MIN_TIME := 3.2                  # seconds a line stays up, at least...
const PER_CHAR := 0.055                # ...plus this much for each letter
const FADE := 0.4

var said: Array[String] = []           # everything it has said this run (tests read it)
var _queue: Array[String] = []
var _t := 0.0
var _showing := false
var _layer: CanvasLayer
var _box: PanelContainer
var _who: Label
var _text: Label
var _voice: AudioStreamPlayer
var spoken := 0                        # lines it has said aloud this run (tests read it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voices" if AudioServer.get_bus_index("Voices") >= 0 else "Master"
	add_child(_voice)
	# Its lines in a talk (the old oak) are spoken as they come up, and the voice stops when the talk moves on
	Dialogue.line_shown.connect(_on_dialogue_line)
	Dialogue.finished.connect(func(_id: String) -> void: stop_voice())


func say(lines: Array) -> void:
	# Lines in the hero's head. A new message waits for the one before it.
	for l in lines:
		var s := str(l).strip_edges()
		if s == "":
			continue
		_queue.append(s)
		said.append(s)
		spoke.emit(s)
	if not _showing:
		_next()


func speaking() -> bool:
	return _showing


func clear() -> void:
	_queue.clear()
	_showing = false
	_box.visible = false
	stop_voice()


func _process(delta: float) -> void:
	if not _showing:
		return
	if get_tree().paused:
		return
	_t -= delta
	var a := 1.0
	if _t < FADE:
		a = clampf(_t / FADE, 0.0, 1.0)
	_box.modulate.a = minf(a, _box.modulate.a + delta / FADE)
	if _t <= 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		_box.visible = false
		return
	var s: String = _queue.pop_front()
	_text.text = s
	_t = MIN_TIME + s.length() * PER_CHAR
	_box.modulate.a = 0.0
	_place()
	_box.visible = true
	_showing = true
	Juice.blip("chime", 0.55, -14.0)
	var secs := speak(s)
	if secs > 0.0:
		_t = maxf(_t, secs + VOICE_TAIL)       # the words stay up till it's finished saying them


# -----------------------------------------------------------------------------
# Its voice
# -----------------------------------------------------------------------------
static func voice_key(text: String) -> String:
	# The line's file name: the same in tools/make_mind_voice.py
	return text.strip_edges().md5_text().substr(0, 16)


static func voice_path(text: String) -> String:
	return VOICE_DIR + voice_key(text) + ".ogg"


static func has_voice(text: String) -> bool:
	return ResourceLoader.exists(voice_path(text))


func speak(text: String) -> float:
	# Says a line aloud (cutting off whatever it was saying). Returns how long it takes, or 0 with no file for it
	stop_voice()
	if not has_voice(text):
		return 0.0
	var stream := load(voice_path(text)) as AudioStream
	if stream == null:
		return 0.0
	_voice.stream = stream
	_voice.play()
	spoken += 1
	return stream.get_length()


func stop_voice() -> void:
	if _voice and _voice.playing:
		_voice.stop()


func is_talking() -> bool:
	return _voice != null and _voice.playing


func _on_dialogue_line(speaker: String, _text_shown: String) -> void:
	# In a talk the line's own words come from the file as written, with {player} still in (the voice can't know the
	# name the player chose, so the recording leaves it out)
	if speaker == SPEAKER:
		speak(str(Dialogue.get("raw_line")))
	else:
		stop_voice()


func all_lines() -> Array:
	# Every line it can ever say, for tools/dump_mind_lines.gd: the fixed ones, the ones naming each world, and every
	# quest goal its hints can remind you of
	var out: Array = [ARRIVAL, OAK_FIRST, HINT_FRIEND, HINT_FIX, HINT_GOAL, HINT_REST, HINT_LOOK]
	out.append_array(CRACK_OPENED)
	for w in Portals.WORLDS:
		out.append(MENDED % w.name)
		out.append(HINT_CRACK % Portals.near_words(str(w.id)))
	for id in Quests._order:
		for step in Quests.quest(id).get("steps", []):
			if not step is Dictionary:
				continue
			for item in step.get("checklist", []):
				out.append(str(item[1]))
			out.append(Quests.short_goal(step))
			if step.has("wait"):
				out.append(str(step.get("wait", {}).get("text", "Come back tomorrow.")).trim_prefix("(").trim_suffix(")"))
	out.append("Come back tomorrow.")
	return out


# -----------------------------------------------------------------------------
# A hint about what to do next (touching the Humming Oak)
# -----------------------------------------------------------------------------
func hint() -> Array:
	# Only ever about cracks that are already open or things the player is already doing
	var lines: Array = []
	for w0 in Portals.open_worlds():
		var id := str((w0 as Dictionary).id)
		if not Portals.is_cleared(str(id)) and Portals.has_portal(str(id)):
			var w := Portals.world(str(id))
			lines.append(HINT_CRACK % Portals.near_words(str(id)))
			lines.append(HINT_FRIEND if str(w.get("owner", "")) != "" else HINT_FIX)
			return lines
	var goals := Quests.objectives()
	if not goals.is_empty():
		for item in goals.items:
			if not bool(item[1]):
				lines.append(HINT_GOAL)
				lines.append(str(item[0]))
				return lines
	if Clock.on_earth and not Clock.in_shift():
		return [HINT_REST]
	return [HINT_LOOK]


func _place() -> void:
	# Just under the HUD's clock (it used to sit at a fixed height, and a bigger HUD's clock poked out from under it),
	# as wide as the text size wants but never wider than the screen, and taller if the words wrap onto more lines
	var ts := Settings.text_scale
	_who.add_theme_font_size_override("font_size", roundi(15 * ts))
	_text.add_theme_font_size_override("font_size", roundi(21 * ts))
	var half := UiStyle.fit_width(_box, 660.0 * ts) / 2.0
	_box.offset_left = -half
	_box.offset_right = half
	var top := 64.0
	var hud := get_tree().get_first_node_in_group("hud") as CanvasLayer
	var clock := hud.get("clock_panel") as Control if hud else null
	if clock and clock.is_visible_in_tree():
		var r := clock.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, clock.size)
		top = maxf(top, r.end.y + 8.0)
	_box.offset_top = top
	_box.offset_bottom = top + 86.0


# -----------------------------------------------------------------------------
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 46
	add_child(_layer)
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_box.offset_left = -330
	_box.offset_right = 330
	_box.offset_top = 64
	_box.offset_bottom = 150
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.08, 0.3, 0.72)
	sb.border_color = Color(0.85, 0.7, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0.7, 0.5, 1.0, 0.35)
	sb.shadow_size = 14
	_box.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_box)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)
	_who = Label.new()
	_who.text = "~ %s ~" % SPEAKER
	_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_who.add_theme_font_size_override("font_size", 15)
	_who.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0, 0.85))
	v.add_child(_who)
	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 21)
	_text.add_theme_color_override("font_color", Color(1.0, 0.97, 1.0))
	_text.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.45))
	_text.add_theme_constant_override("outline_size", 6)
	v.add_child(_text)
	_box.visible = false
