extends Node

# Autoload "Quests": the quest lines, written as plain data in res://quests/<id>.json (see res://quests/README.md).
#
# A quest starts when its "start" flags are set, then goes step by step. A step is done when its flags are set:
# flags come from conversations (scripts/dialogue.gd: an answer's or a whole conversation's "set") and from quest
# spots in town (scripts/quest_spot.gd, e.g. hanging a poster). A step can make you wait ("wait": {"days": 1}: come
# back tomorrow), and can move someone for an event while it's on ("override": Rex's rally at the fountain, in the
# evening; scripts/routine.gd asks override_for()). Finishing a quest can give an item and a new title.
#
# Progress is saved with the game (scripts/game.gd). A small note shows when a step updates, and the quest log
# (the "quest_log" key, Q) lists what to do next.

signal changed(quest_id: String)

const DIR := "res://quests"
const NOTE_TIME := 4.5

var state := {}                      # quest id -> {"step": index, "since_day": day the step began, "done": bool}
var _data := {}                      # quest id -> its file
var _order: Array[String] = []
var _check_wait := 0.0

var _note_layer: CanvasLayer
var _note: PanelContainer
var _note_label: Label
var _note_time := 0.0
var _log_layer: CanvasLayer
var _log_panel: PanelContainer
var _log_text: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS                # the log works while the game is paused under it
	if _order.is_empty():
		_load_all()
	_build_ui()
	# Steps move on when a conversation ends (not halfway through one), or when a quest spot sets a flag
	Dialogue.finished.connect(func(_id: String) -> void: check())
	Dialogue.flag_set.connect(func(_f: String) -> void:
		if not Dialogue.is_active():
			check())
	Settings.changed.connect(_apply_look)
	_apply_look()


func _load_all() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var res := load(DIR.path_join(f)) as JSON
		if res and res.data is Dictionary:
			var id := f.get_basename()
			_data[id] = res.data
			_order.append(id)
		else:
			push_warning("Quests: %s isn't valid JSON" % f)
	_order.sort()


func quest(id: String) -> Dictionary:
	if _order.is_empty():
		_load_all()                                    # asked before _ready (Game loading the save)
	return _data.get(id, {})


# -----------------------------------------------------------------------------
# Where a quest is up to
# -----------------------------------------------------------------------------
func is_started(id: String) -> bool:
	return state.has(id)


func is_done(id: String) -> bool:
	return state.get(id, {}).get("done", false)


func current_step(id: String) -> Dictionary:
	if not is_started(id) or is_done(id):
		return {}
	var steps: Array = quest(id).get("steps", [])
	var i: int = state[id].step
	return steps[i] if i < steps.size() else {}


func is_waiting(id: String) -> bool:
	# On a step that says to come back later, and it isn't later yet
	var step := current_step(id)
	var days := int(step.get("wait", {}).get("days", 0))
	return not step.is_empty() and Clock.day < int(state[id].since_day) + days


func on_step(id: String, step_id: String) -> bool:
	return current_step(id).get("id", "") == step_id


func is_ready(id: String, step_id: String) -> bool:
	return on_step(id, step_id) and not is_waiting(id)


func condition_ok(when: Dictionary) -> bool:
	# Quest conditions for dialogue (and anything else): "quest_step", "quest_ready", "quest_waiting" ("id:step"),
	# "quest_done", "quest_not_started" ("id")
	for key in ["quest_step", "quest_ready", "quest_waiting"]:
		if when.has(key):
			var parts := str(when[key]).split(":")
			var q := parts[0]
			var st := parts[1] if parts.size() > 1 else ""
			match key:
				"quest_step":
					if not on_step(q, st):
						return false
				"quest_ready":
					if not is_ready(q, st):
						return false
				"quest_waiting":
					if not (on_step(q, st) and is_waiting(q)):
						return false
	if when.has("quest_done") and not is_done(str(when["quest_done"])):
		return false
	if when.has("quest_not_started") and is_started(str(when["quest_not_started"])):
		return false
	return true


func override_for(character_id: String) -> Dictionary:
	# A quest step that moves someone for an event right now (e.g. Rex's rally at the fountain in the evening)
	for id in _order:
		var step := current_step(id)
		if step.is_empty() or is_waiting(id):
			continue
		var o: Dictionary = step.get("override", {}).get(character_id, {})
		if o.is_empty():
			continue
		var times = o.get("time", [])
		var list: Array = times if times is Array else [times]
		var now := Clock.period()
		if list.is_empty() or now in list or (now == "shift" and "night" in list):
			return o
	return {}


func display_name(character_id: String, default: String) -> String:
	# The name Nina gave them, or a new title from a finished quest ("Future Mayor Rex")
	if Dialogue.names.has(character_id):
		return str(Dialogue.names[character_id])
	for id in _order:
		if is_done(id):
			var t: Dictionary = quest(id).get("titles", {})
			if t.has(character_id):
				return str(t[character_id])
	return default


func checklist(id: String) -> Array:
	# [[label, done], ...] for the current step's checklist
	var out := []
	for item in current_step(id).get("checklist", []):
		out.append([str(item[1]), Dialogue.flags.has(str(item[0]))])
	return out


# -----------------------------------------------------------------------------
# Moving quests along
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _note_time > 0.0:
		_note_time -= delta
		_note.modulate.a = clampf(_note_time, 0.0, 1.0)
	if get_tree().paused or Dialogue.is_active():
		return
	_check_wait -= delta
	if _check_wait <= 0.0:                                 # waits end with the clock: check now and then
		_check_wait = 1.0
		check()


func check() -> void:
	for id in _order:
		var q := quest(id)
		if not is_started(id):
			if _flags_ok(q.get("start", {})) and not q.get("start", {}).is_empty():
				state[id] = {"step": 0, "since_day": Clock.day, "done": false}
				_announce("New quest: %s" % q.get("name", id), current_step(id).get("text", ""))
				changed.emit(id)
			continue
		var guard := 0
		while not is_done(id) and guard < 20:
			guard += 1
			var step := current_step(id)
			if is_waiting(id) or not _flags_ok(step.get("done", {})):
				break
			_advance(id)


func _advance(id: String) -> void:
	var q := quest(id)
	var steps: Array = q.get("steps", [])
	state[id].step = int(state[id].step) + 1
	state[id].since_day = Clock.day
	if int(state[id].step) >= steps.size():
		state[id].done = true
		var reward: Dictionary = q.get("reward", {})
		if reward.has("item"):
			Game.give_item(str(reward.item))
			Game.equipment_changed.emit()                   # e.g. she puts on the sash
		if reward.has("sparkles"):
			Game.add_sparkles(int(reward.sparkles))
		_announce("Quest complete: %s" % q.get("name", id), str(reward.get("message", "")))
		Audio.play("level_up", -4.0)
	else:
		var step := current_step(id)
		var text: String = step.get("text", "")
		if is_waiting(id):
			text += "\n" + str(step.get("wait", {}).get("text", "(Come back tomorrow.)"))
		_announce("Quest updated: %s" % q.get("name", id), text)
		Audio.play("pickup", -6.0)
	changed.emit(id)
	Game.save_game()


func _flags_ok(cond: Dictionary) -> bool:
	if cond.has("flag") and not Dialogue.flags.has(str(cond.flag)):
		return false
	for f in cond.get("flags", []):
		if not Dialogue.flags.has(str(f)):
			return false
	return true


# -----------------------------------------------------------------------------
# Saving (scripts/game.gd keeps this in save.json)
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return state.duplicate(true)


func load_data(data: Dictionary) -> void:
	state.clear()
	for id in data:
		var s: Dictionary = data[id]
		state[str(id)] = {"step": int(s.get("step", 0)), "since_day": int(s.get("since_day", 1)), "done": bool(s.get("done", false))}


func reset() -> void:
	state.clear()


# -----------------------------------------------------------------------------
# The note and the quest log
# -----------------------------------------------------------------------------
func _announce(title: String, text: String) -> void:
	_note_label.text = title + ("\n" + text if text != "" else "")
	_note_time = NOTE_TIME
	_note.modulate.a = 1.0


func note_text() -> String:
	return _note_label.text if _note_time > 0.0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		get_viewport().set_input_as_handled()
		toggle_log()
	elif is_log_open() and event.is_action_pressed("ui_cancel"):     # (Pause closes it too: scripts/pause_menu.gd)
		get_viewport().set_input_as_handled()
		toggle_log()


func is_log_open() -> bool:
	return _log_layer.visible


func toggle_log() -> void:
	if not is_log_open() and (get_tree().paused or Dialogue.is_active()):
		return                                             # not over the pause menu, a bed, or a conversation
	_log_layer.visible = not _log_layer.visible
	get_tree().paused = _log_layer.visible
	if _log_layer.visible:
		_note_time = 0.0                                   # the log says it all; don't cover it
		_note.modulate.a = 0.0
		_log_text.text = log_text()
		Audio.play("ui_accept", -4.0, 0.0)


func log_text() -> String:
	var lines := ["[b]Quests[/b]", ""]
	var any := false
	for id in _order:
		if not is_started(id):
			continue
		any = true
		var q := quest(id)
		if is_done(id):
			lines.append("[color=#b8f5b8]%s - done![/color]" % q.get("name", id))
			continue
		var step := current_step(id)
		lines.append("[b]%s[/b]" % q.get("name", id))
		lines.append("  " + str(step.get("text", "")))
		for item in checklist(id):
			lines.append("    %s %s" % ["[color=#b8f5b8](done)[/color]" if item[1] else "( )", item[0]])
		if is_waiting(id):
			lines.append("  [color=#f5e6a3]%s[/color]" % step.get("wait", {}).get("text", "(Come back tomorrow.)"))
		lines.append("")
	if not any:
		lines.append("No quests yet. Talk to people around town!")
	lines.append("")
	lines.append("[color=#c8c8d8](%s to close)[/color]" % Settings.prompt("quest_log"))
	return "\n".join(lines)


func _build_ui() -> void:
	_note_layer = CanvasLayer.new()
	_note_layer.layer = 15
	add_child(_note_layer)
	_note = PanelContainer.new()
	_note.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_note.offset_right = -16
	_note.offset_top = 60
	_note.modulate.a = 0.0
	_note_label = Label.new()
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_child(_note_label)
	_note_layer.add_child(_note)
	_log_layer = CanvasLayer.new()
	_log_layer.layer = 35
	_log_layer.visible = false
	add_child(_log_layer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_layer.add_child(center)
	_log_panel = PanelContainer.new()
	center.add_child(_log_panel)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.fit_content = true
	_log_text.scroll_active = false
	_log_panel.add_child(_log_text)


func _apply_look() -> void:
	var hc := Settings.high_contrast
	for p in [_note, _log_panel]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.1, 0.08, 0.15, 0.9)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(roundi(16 * Settings.text_scale))
		if hc:
			style.border_color = Color(1, 1, 1)
			style.set_border_width_all(2)
		(p as PanelContainer).add_theme_stylebox_override("panel", style)
	_note.custom_minimum_size.x = roundi(320 * Settings.text_scale)
	_note_label.custom_minimum_size.x = roundi(300 * Settings.text_scale)
	_note_label.add_theme_font_size_override("font_size", roundi(18 * Settings.text_scale))
	_note_label.add_theme_color_override("font_color", Color(1, 1, 0.8) if hc else Color(1, 0.95, 0.75))
	_log_text.custom_minimum_size = Vector2(roundi(560 * Settings.text_scale), 0)
	_log_text.add_theme_font_size_override("normal_font_size", roundi(20 * Settings.text_scale))
	_log_text.add_theme_font_size_override("bold_font_size", roundi(24 * Settings.text_scale))
