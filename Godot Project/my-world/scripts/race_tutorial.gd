extends CanvasLayer

# How races work, shown as you go (Hayden's 13 Nov 2026 playtest: "there needs to be a tutorial for starting
# races"). A node "Tutorial" under the Races autoload, with the same calm card as the movement tutorial
# (scripts/move_tutorial.gd): one thing at a time, ticked off with a chime when you've done it. Nothing is held.
#
# Out in the world, the first time you come near a race gate with something to ride, the card says who to talk to
# ("gate"). Then in your first race:
#
#   go     when it says GO, ride forward              (done once you're moving after GO)
#   ring   through the gold ring                      (the first ring passed)
#   box    ride into a Star Box for a power-up         (holding one; the Starter Star counts)
#   use    press Aim to use it                         (it's been used)
#   watch  bumpers, sweepers, zappers and ramps        (read for a few seconds)
#   map    the map on the right, three laps            (read for a few seconds)
#
# Saved as Dialogue flags ("race_tut_<step>", "race_tut_done", "race_gate_seen"), so a race left half way carries on
# from the step it was on next time. Finishing a race ends it. A save that's raced before never sees it, and with
# Settings > tips off only the gate card shows. No class_name on purpose (preload it).

const STEPS := [
	{"id": "go", "text": "Get ready! When it says GO, ride forward with {moves}."},
	{"id": "ring", "text": "Ride through the glowing gold ring. Every ring, in order: the next one lights up gold."},
	{"id": "box", "text": "See the spinning Star Boxes across the road? Ride into one to get a power-up!"},
	{"id": "use", "text": "You've got a %s! Press {aim} to use it."},
	{"id": "watch", "text": "Watch out! Bumpers bounce you back, sweepers and zappers knock you over, ramps throw you up high."},
	{"id": "map", "text": "The map on the right shows the track and everyone on it. Three laps to the finish. Go, go, go!"},
]
const READ_FOR := 6.0                # seconds the last two cards stay before ticking themselves off
const GATE_NEAR := 26.0              # metres from a race gate's arch that shows the gate card
const DONE_FLAG := "race_tut_done"
const GATE_FLAG := "race_gate_seen"

var _i := -1
var _tick := 0.0
var _read := 0.0
var _gate_on := false
var _panel: PanelContainer
var _text: Label
var _dots: HBoxContainer
var _check: Label


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	visible = false


func running() -> bool:
	return _i >= 0


func step_id() -> String:
	return str(STEPS[_i].id) if running() else ""


func showing() -> String:
	# What the card's showing: a step's id, "gate", or "" (for the tests)
	if not visible or not _panel.visible:
		return ""
	return "gate" if _gate_on else step_id()


func wanted() -> bool:
	# Whether a race starting now should teach: not if they've raced before (an old save), finished it, or turned tips off
	return Settings.tips and Races.raced == 0 and not Dialogue.flags.has(DONE_FLAG)


func begin() -> void:
	# A race is starting (Races.start): carry on from the first step not done yet
	_gate_on = false
	if not wanted():
		stop()
		return
	_i = 0
	while _i < STEPS.size() - 1 and Dialogue.flags.has("race_tut_" + str(STEPS[_i].id)):
		_i += 1
	_begin_step()
	visible = true


func finish() -> void:
	# A race is over (whatever place): that's the lesson done, however far it got
	if not Dialogue.flags.has(DONE_FLAG):
		for s in STEPS:
			Dialogue.set_flag("race_tut_" + str(s.id))
		Dialogue.set_flag(DONE_FLAG)
	stop()


func stop() -> void:
	_i = -1
	_gate_on = false
	visible = false


func _begin_step() -> void:
	_tick = 0.0
	_read = 0.0
	_check.visible = false
	_fill()
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.3)


func _fill() -> void:
	if _gate_on:
		_text.text = _gate_text()
		_dots.visible = false
		return
	_dots.visible = true
	var t := str(STEPS[_i].text)
	if step_id() == "use":
		t = t % (str(Races.POWERS[Races.power].name) if Races.power != "" else "power-up")
	_text.text = Settings.fill(t)
	for c in _dots.get_children():
		var k: int = c.get_index()
		(c as Label).text = "●" if k < _i else ("◉" if k == _i else "○")
		(c as Label).add_theme_color_override("font_color", UiStyle.TEAL if k < _i else (UiStyle.GOLD if k == _i else Color(0.7, 0.65, 0.85)))


func _gate_text() -> String:
	var hub := _near_hub()
	var who := str(Races.HUBS[hub].starter.name) if hub != "" else "the starter"
	return "Races! Talk to %s under the race arch (%s) to pick a race. Each one has a whole track of its own." % [who,
		Settings.prompt("interact")]


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _busy() -> bool:
	return Dialogue.is_active() or not get_tree().get_nodes_in_group("cutscene_playing").is_empty() \
		or Creator.is_open() or PlayerMenu.is_open() or Races.state == Races.State.INTRO \
		or Races.state == Races.State.RESULTS or Races.choosing()


func _process(delta: float) -> void:
	if running():
		_lesson(delta)
	else:
		_gate()


# -----------------------------------------------------------------------------
# The gate card: who to talk to, the first time you're near a race gate
# -----------------------------------------------------------------------------
func _near_hub() -> String:
	var p := _player()
	if p == null:
		return ""
	for hub in Races.HUBS:
		var g: Node3D = Races.hub_node(hub)
		if g and g.is_inside_tree():
			var at: Vector2 = Races.HUBS[hub].at
			if Vector2(p.global_position.x, p.global_position.z).distance_to(at) < GATE_NEAR:
				return hub
	return ""


func _gate() -> void:
	var want := not Dialogue.flags.has(GATE_FLAG) and Races.raced == 0 and Game.has_item("skateboard") \
		and Races.circuit == "" and not Races.racing() and _near_hub() != ""
	if want and not _gate_on:
		_gate_on = true
		visible = true
		_check.visible = false
		_begin_step()
	elif not want and _gate_on:
		_gate_on = false
		visible = false
	if _gate_on:
		_panel.visible = not _busy()
		_fill()


func gate_talked() -> void:
	# Talking to the starter is what the gate card asked for (Races.talk)
	Dialogue.set_flag(GATE_FLAG)


# -----------------------------------------------------------------------------
# The lesson, in your first race
# -----------------------------------------------------------------------------
func _lesson(delta: float) -> void:
	if not Races.racing() and Races.state != Races.State.RESULTS:
		stop()                                    # (the race was called off: it carries on next time)
		return
	var busy := _busy()
	_panel.visible = not busy
	if busy:
		return
	_fill()
	if _tick > 0.0:
		_tick -= delta
		if _tick <= 0.0:
			_i += 1
			if _i >= STEPS.size():
				stop()                            # (all done; "race_tut_done" waits for the finish)
				return
			_begin_step()
		return
	if _done_now(delta):
		Dialogue.set_flag("race_tut_" + step_id())
		_check.visible = true
		Audio.play("pickup", -8.0, 0.1)
		_tick = 0.7


func _done_now(delta: float) -> bool:
	match step_id():
		"go":
			var p := _player() as CharacterBody3D
			return Races.state == Races.State.RACING and p != null and Vector2(p.velocity.x, p.velocity.z).length() > 3.0
		"ring":
			return Races.state == Races.State.RACING and (Races.last_cp > 0 or Races.lap > 1)
		"box":
			return Races.power != ""
		"use":
			# (Used: nothing in hand any more. Or never got one this race: move on rather than wait.)
			return Races.power == ""
		"watch", "map":
			_read += delta
			return _read >= READ_FOR
	return false


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Race Tutorial"
	# On the left, under the level and sparkles box (scripts/hud.gd) and over the power-up box (scripts/race_hud.gd):
	# clear of the lap line and the big 3-2-1 shouts in the middle, and of the road ahead
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 16
	_panel.offset_top = 180
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.18, 0.82)
	style.border_color = UiStyle.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_text = Label.new()
	_text.add_theme_font_override("font", Dialogue.font)
	_text.add_theme_font_size_override("font_size", Settings.hud(22))
	_text.add_theme_color_override("font_color", UiStyle.TEXT)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = Settings.hud(340)
	row.add_child(_text)
	_check = Label.new()
	_check.text = "✔"
	_check.add_theme_font_size_override("font_size", Settings.hud(26))
	_check.add_theme_color_override("font_color", UiStyle.TEAL)
	row.add_child(_check)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 8)
	v.add_child(_dots)
	for i in STEPS.size():
		var d := Label.new()
		d.add_theme_font_size_override("font_size", Settings.hud(16))
		_dots.add_child(d)
