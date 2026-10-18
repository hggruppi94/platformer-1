extends Node

# Autoload "Dialogue": talking to people. Walk up to someone with a talk spot (scripts/talker.gd): their name shows
# over their head, the nearest one says "Press F to talk", and Interact starts a conversation in a box at the bottom
# of the screen. Text types itself out; Interact (or Jump) shows it all, then goes on. Some lines ask Nina a question
# with 2-3 answers to pick from (up/down, then Interact).
#
# What they say is in res://dialogue/<id>.json, one file per character. See res://dialogue/README.md for how to
# write it. Which conversation plays depends on the time of day (Clock.period()), how many times she's talked to
# them, and flags set by earlier answers. Talk counts and flags are saved with the game (scripts/game.gd).

signal started(id: String)
signal finished(id: String)
signal line_shown(speaker: String, text: String)

const DIR := "res://dialogue"
const CHARS_PER_SECOND := 45.0
const PLAYER_NAME := "Nina"

var talks := {}                      # character id -> how many conversations she's had with them
var flags := {}                      # flag name -> true, set by answers ("set": "flag" in a choice)

var _near: Array[Node3D] = []        # talk spots she's standing in (scripts/talker.gd)
var _nearest: Node3D
var _talker: Node3D                  # who she's talking to, while a conversation is on
var _id := ""
var _name := ""
var _queue: Array = []               # steps still to show: lines (Dictionary {speaker, text}) and choices
var _typing := false
var _shown := 0.0
var _choosing := false
var _data_cache := {}

var _layer: CanvasLayer
var _panel: PanelContainer
var _name_label: Label
var _text: Label
var _hint: Label
var _choices: VBoxContainer


func _ready() -> void:
	_build_ui()
	Settings.changed.connect(_apply_look)
	_apply_look()


func is_active() -> bool:
	return _talker != null


# -----------------------------------------------------------------------------
# Talk spots (called by scripts/talker.gd)
# -----------------------------------------------------------------------------
func enter_range(t: Node3D) -> void:
	if t not in _near:
		_near.append(t)


func exit_range(t: Node3D) -> void:
	_near.erase(t)


func _process(delta: float) -> void:
	# The nearest talk spot gets the "Press F to talk" prompt
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Node3D = null
	if player and not is_active():
		var best_d := INF
		for t in _near:
			if is_instance_valid(t):
				var d := t.global_position.distance_to(player.global_position)
				if d < best_d:
					best_d = d
					best = t
	if best != _nearest:
		if _nearest and is_instance_valid(_nearest):
			_nearest.call("set_prompt", false)
		_nearest = best
		if _nearest:
			_nearest.call("set_prompt", true)
	# Typewriter
	if _typing:
		_shown += delta * (1000.0 if Settings.reduce_motion else CHARS_PER_SECOND)
		_text.visible_characters = int(_shown)
		if _shown >= _text.get_total_character_count():
			_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if is_active():
		if _choosing:
			# The answer buttons take Enter/Space/pad A themselves; Interact picks the highlighted one too
			var focused := get_viewport().gui_get_focus_owner() as Button
			if event.is_action_pressed("interact") and focused and focused in current_choices():
				get_viewport().set_input_as_handled()
				focused.pressed.emit()
			return
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			if _typing:
				_finish_typing()
			else:
				_next()
	elif _nearest and is_instance_valid(_nearest) and not get_tree().paused and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		talk_to(_nearest)


# -----------------------------------------------------------------------------
# Conversations
# -----------------------------------------------------------------------------
func talk_to(talker: Node3D) -> void:
	var id: String = talker.get("character_id")
	var data := load_character(id)
	if data.is_empty():
		return
	var convo := pick_conversation(id)
	if convo.is_empty():
		return
	_talker = talker
	_id = id
	_name = data.get("name", talker.get("display_name"))
	_queue = _steps(convo)
	talks[id] = int(talks.get(id, 0)) + 1
	if _nearest:
		_nearest.call("set_prompt", false)
	_set_player_locked(true)
	talker.call("begin_talk")
	_panel.visible = true
	started.emit(id)
	_next()


func load_character(id: String) -> Dictionary:
	if _data_cache.has(id):
		return _data_cache[id]
	var path := "%s/%s.json" % [DIR, id]
	var data := {}
	if ResourceLoader.exists(path):
		var res := load(path) as JSON
		if res and res.data is Dictionary:
			data = res.data
		else:
			push_warning("Dialogue: %s isn't valid JSON" % path)
	else:
		push_warning("Dialogue: no lines for '%s' (%s)" % [id, path])
	_data_cache[id] = data
	return data


func pick_conversation(id: String) -> Array:
	# The first conversation in the file whose "when" matches now. "lines" plays as is; "rotate" plays a different
	# set each visit, in turn.
	var data := load_character(id)
	var count := int(talks.get(id, 0))
	for c in data.get("conversations", []):
		if not c is Dictionary or not _matches(c.get("when", {}), count):
			continue
		if c.has("rotate"):
			var sets: Array = c["rotate"]
			return sets[count % sets.size()] if sets.size() > 0 else []
		return c.get("lines", [])
	return []


func _matches(when: Dictionary, count: int) -> bool:
	if when.has("time"):
		var want = when["time"]
		var times: Array = want if want is Array else [want]
		var now := Clock.period()
		if not (now in times or (now == "shift" and "night" in times)):
			return false
	if when.has("talks") and count != int(when["talks"]):
		return false
	if when.has("min_talks") and count < int(when["min_talks"]):
		return false
	if when.has("max_talks") and count > int(when["max_talks"]):
		return false
	if when.has("every") and count % maxi(int(when["every"]), 1) != 0:
		return false
	if when.has("flag") and not flags.has(str(when["flag"])):
		return false
	if when.has("not_flag") and flags.has(str(when["not_flag"])):
		return false
	return true


func _steps(lines: Array) -> Array:
	# Lines as written in the file -> steps: {speaker, text} or {choice: [...]}
	var out: Array = []
	for l in lines:
		if l is String:
			if l.begins_with(PLAYER_NAME + ": "):
				out.append({"speaker": PLAYER_NAME, "text": l.substr(PLAYER_NAME.length() + 2)})
			else:
				out.append({"speaker": "", "text": l})
		elif l is Dictionary and l.has("choice"):
			out.append(l)
		elif l is Dictionary and l.has("text"):
			out.append({"speaker": str(l.get("speaker", "")), "text": str(l["text"])})
	return out


func _next() -> void:
	if _queue.is_empty():
		end()
		return
	var step: Dictionary = _queue.pop_front()
	if step.has("choice"):
		_show_choice(step["choice"])
		return
	var text := _fill(step["text"])
	var narration: bool = step["speaker"] == "" and text.begins_with("(") and text.ends_with(")")
	var speaker: String = "" if narration else (step["speaker"] if step["speaker"] != "" else _name)
	_name_label.text = speaker
	_name_label.visible = not narration
	var is_nina := speaker == PLAYER_NAME
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.7) if is_nina else Color(0.75, 0.9, 1.0))
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_hint.visible = false
	line_shown.emit(speaker, text)


func _fill(text: String) -> String:
	return text.format({"time": Clock.time_string(), "day": Clock.day, "talks": int(talks.get(_id, 0)),
		"name": _name, "nina": PLAYER_NAME})


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_hint.visible = true


func _show_choice(options: Array) -> void:
	_choosing = true
	_hint.visible = false
	for c in _choices.get_children():
		c.queue_free()
	var first: Button = null
	for o in options:
		var b := Button.new()
		b.text = _fill(str(o.get("text", "...")))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_choice(b)
		b.pressed.connect(choose.bind(o))
		_choices.add_child(b)
		if first == null:
			first = b
	_choices.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first:
		first.grab_focus.call_deferred()


func choose(option: Dictionary) -> void:
	# Pick an answer: Nina says it, any flag it sets is set, then its own lines play before the rest
	if not _choosing:
		return
	_choosing = false
	_choices.visible = false
	for c in _choices.get_children():
		c.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if option.has("set"):
		flags[str(option["set"])] = true
	if option.get("heal", false):
		Game.hp = Game.max_hp
		Game.mp = Game.max_mp
		Game.sp = Game.max_sp
		Game.stats_changed.emit()
		Game.sp_changed.emit()
	var steps := _steps([PLAYER_NAME + ": " + str(option.get("text", ""))]) if option.get("say", true) else []
	steps.append_array(_steps(option.get("lines", [])))
	_queue = steps + _queue
	_next()


func current_choices() -> Array[Button]:
	var out: Array[Button] = []
	for c in _choices.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out


func end() -> void:
	_panel.visible = false
	_choices.visible = false
	_typing = false
	_choosing = false
	_queue.clear()
	var id := _id
	if _talker and is_instance_valid(_talker):
		_talker.call("end_talk")
	_talker = null
	_id = ""
	# A moment later, so the Jump press that closed the box doesn't make her jump too
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if not is_active():
			_set_player_locked(false))
	Game.save_game()
	finished.emit(id)


func _set_player_locked(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player:
		player.set("input_locked", on)


# -----------------------------------------------------------------------------
# Saving (scripts/game.gd keeps these in save.json)
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"talks": talks.duplicate(), "flags": flags.keys()}


func load_data(data: Dictionary) -> void:
	talks.clear()
	flags.clear()
	var t = data.get("talks", {})
	if t is Dictionary:
		for k in t:
			talks[str(k)] = int(t[k])
	for f in data.get("flags", []):
		flags[str(f)] = true


func reset() -> void:
	talks.clear()
	flags.clear()


# -----------------------------------------------------------------------------
# The box at the bottom of the screen
# -----------------------------------------------------------------------------
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	_layer.add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	_name_label = Label.new()
	v.add_child(_name_label)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.visible = false
	v.add_child(_choices)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _apply_look() -> void:
	var hc := Settings.high_contrast
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.95) if hc else Color(0.1, 0.08, 0.15, 0.88)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(_fs(18))
	if hc:
		style.border_color = Color(1, 1, 1)
		style.set_border_width_all(2)
	_panel.add_theme_stylebox_override("panel", style)
	var w := _fs(860)
	_panel.custom_minimum_size = Vector2(w, _fs(150))
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0
	_panel.offset_bottom = -24
	_name_label.add_theme_font_size_override("font_size", _fs(22))
	_text.add_theme_font_size_override("font_size", _fs(24))
	_text.add_theme_color_override("font_color", Color(1, 1, 0.85) if hc else Color(1, 1, 1))
	_hint.add_theme_font_size_override("font_size", _fs(15))
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_hint.text = "%s  >" % Settings.key_name("interact")
	for b in _choices.get_children():
		_style_choice(b)


func _style_choice(b: Button) -> void:
	b.add_theme_font_size_override("font_size", _fs(22))
	var focus := StyleBoxFlat.new()                      # a clear outline on the highlighted answer, for controllers
	focus.draw_center = false
	focus.border_color = Color(1, 1, 0.6) if Settings.high_contrast else Color(0.9, 0.75, 1.0)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(8)
	b.add_theme_stylebox_override("focus", focus)
