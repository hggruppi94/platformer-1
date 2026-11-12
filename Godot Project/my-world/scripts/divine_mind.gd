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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


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
	_box.visible = true
	_showing = true
	Juice.blip("chime", 0.55, -14.0)


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
			lines.append("A crack lies open in the Void, by %s. Time is broken on the other side." % Portals.near_words(str(id)))
			lines.append("Jump in. %s" % ("Someone there is waiting for a friend." if str(w.get("owner", "")) != "" else "Put it right."))
			return lines
	var goals := Quests.objectives()
	if not goals.is_empty():
		for item in goals.items:
			if not bool(item[1]):
				lines.append("Remember what you set out to do...")
				lines.append(str(item[0]))
				return lines
	if Clock.on_earth and not Clock.in_shift():
		return ["Rest, and be with the people you love. When the moon is at its highest, the ground here opens."]
	return ["Look around you. Help where you can. When you're needed, I will tell you."]


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
