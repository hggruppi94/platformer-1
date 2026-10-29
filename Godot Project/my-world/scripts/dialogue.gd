extends Node

# Autoload "Dialogue": talking to people. Walk up to someone with a talk spot (scripts/talker.gd): their name shows
# over their head, the nearest one says "Press F to talk", and Interact starts a conversation in a box at the bottom
# of the screen. Text types itself out; Interact (or Jump) shows it all, then goes on. Some lines ask Nina a question
# with 2-3 answers to pick from (up/down, then Interact).
#
# What they say is in res://dialogue/<id>.json, one file per character. See res://dialogue/README.md for how to
# write it. Which conversation plays depends on the time of day (Clock.period()), how many times she's talked to
# them, flags set by earlier answers, and where they are and what they're up to in their daily routine
# (scripts/routine.gd), and where Nina is up to in a quest (scripts/quests.gd). Talk counts and flags are saved with the
# game (scripts/game.gd).

signal started(id: String)
signal finished(id: String)
signal line_shown(speaker: String, text: String)
signal flag_set(flag: String)

const DIR := "res://dialogue"
const CHARS_PER_SECOND := 45.0
const PLAYER_TAG := "{player}"       # lines starting "{player}: " are the player's own (their name comes from the creator)

var talks := {}                      # character id -> how many conversations she's had with them
var flags := {}                      # flag name -> true, set by answers and conversations ("set": "flag")
var names := {}                      # character id -> the name Nina gave them ("name" in an answer)
var choice_log: Array = []           # answers marked "record": [{what, answer, day, time}], oldest first (saved)

var _near: Array[Node3D] = []        # talk spots she's standing in (scripts/talker.gd)
var _nearest: Node3D
var _talker: Node3D                  # who she's talking to, while a conversation is on
var _id := ""
var _name := ""
var _queue: Array = []               # steps still to show: lines (Dictionary {speaker, text}) and choices
var _set_at_end := ""                # the conversation's own "set" flag, set once it's over
var _go_at_end: Array = []           # [scene, spawn]: an answer's "go", taken once the conversation's over
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
	if talker.has_method("use"):
		talker.call("use")                           # not someone to talk to: a quest spot (scripts/quest_spot.gd)
		return
	var id: String = talker.get("character_id")
	var data := load_character(id)
	if data.is_empty():
		return
	var picked := _pick(id)
	var convo: Array = picked.get("lines", [])
	if convo.is_empty():
		return
	_talker = talker
	_id = id
	_name = Quests.display_name(id, data.get("name", talker.get("display_name")))
	_queue = _steps(convo)
	_queue.append_array(_steps(_do(str(picked.get("do", "")))))
	_set_at_end = str(picked.get("set", ""))
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
	return _pick(id).get("lines", [])


func _pick(id: String) -> Dictionary:
	# The first conversation in the file whose "when" matches now: {lines, set}. "lines" plays as is; "rotate" plays
	# a different set each visit, in turn.
	var data := load_character(id)
	var count := int(talks.get(id, 0))
	for c in data.get("conversations", []):
		if not c is Dictionary or not _matches(c.get("when", {}), count, id):
			continue
		var lines: Array = c.get("lines", [])
		if c.has("rotate"):
			var sets: Array = c["rotate"]
			lines = sets[count % sets.size()] if sets.size() > 0 else []
		return {"lines": lines, "set": c.get("set", ""), "do": c.get("do", "")}
	return {}


func _do(what: String) -> Array:
	# A conversation's "do": "Autoload.method" runs as the talk starts (handing Dash the lost watches:
	# scripts/watches.gd), and any lines it gives back are said after the conversation's own
	if what == "" or what.get_slice_count(".") != 2:
		return []
	var target := get_node_or_null("/root/" + what.get_slice(".", 0))
	var method := what.get_slice(".", 1)
	if target == null or not target.has_method(method):
		push_warning("Dialogue: can't do '%s'" % what)
		return []
	var lines = target.call(method)
	return lines if lines is Array else []


func routine_of(id: String) -> Node:
	for r in get_tree().get_nodes_in_group("routines"):
		if r.get("character_id") == id:
			return r
	return null


func _matches(when: Dictionary, count: int, id := "") -> bool:
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
	if not Quests.condition_ok(when):              # "quest_step", "quest_ready", "quest_done", ...
		return false
	if not Watches.condition_ok(when):             # "watches_to_give", "watches_found", "watches_given"
		return false
	# Their routine: where they are ("place"), what they're up to ("activity", the block's label), on the move
	if when.has("place") or when.has("activity") or when.has("travelling"):
		var r := routine_of(id)
		if r == null:
			return false
		for key in ["place", "activity"]:
			if when.has(key):
				var want = when[key]
				var options: Array = want if want is Array else [want]
				if not str(r.call(key)) in options:
					return false
		if when.has("travelling") and bool(when["travelling"]) != r.call("is_travelling"):
			return false
	return true


func _steps(lines: Array) -> Array:
	# Lines as written in the file -> steps: {speaker, text} or {choice: [...]}
	var out: Array = []
	for l in lines:
		if l is String:
			if l.begins_with(PLAYER_TAG + ": "):
				out.append({"speaker": PLAYER_TAG, "text": l.substr(PLAYER_TAG.length() + 2)})
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
	var is_player := speaker == PLAYER_TAG
	if is_player:
		speaker = player_name()
	_name_label.text = speaker
	_name_label.visible = not narration
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.7) if is_player else Color(0.75, 0.9, 1.0))
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_typing = true
	_hint.visible = false
	line_shown.emit(speaker, text)


func player_name() -> String:
	return Hero.display_name(Game.hero)


func _fill(text: String) -> String:
	# Fills in {player} (the name they chose), their pronouns ({they}, {them}, {their}, and capitalised), and more
	var words := {"time": Clock.time_string(), "day": Clock.day, "talks": int(talks.get(_id, 0)),
		"name": _name, "player": player_name(), "nina": player_name(), "quest_log": Settings.prompt("quest_log")}
	words.merge(Watches.fill())                      # {watches_new}, {watches_given}, {watches_left}
	for w in ["they", "them", "their", "theirs", "themself", "are"]:
		var p := Hero.pronoun(Game.hero, w)
		words[w] = p
		words[w.capitalize()] = p.capitalize()
	return text.format(words)


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
		set_flag(str(option["set"]))
	if option.has("record"):
		# Remember this answer for good, with when: e.g. whether she chose to go into the Scary World (a moment
		# that's worth being able to talk about afterwards)
		choice_log.append({"what": str(option["record"]), "answer": str(option.get("answer", option.get("text", ""))),
			"day": Clock.day, "time": Clock.time_string()})
	if option.has("name"):
		names[_id] = str(option["name"])
	if option.has("go"):
		_go_at_end = option["go"]
	if option.get("heal", false):
		Game.hp = Game.max_hp
		Game.mp = Game.max_mp
		Game.sp = Game.max_sp
		Game.stats_changed.emit()
		Game.sp_changed.emit()
	var steps := _steps([PLAYER_TAG + ": " + str(option.get("text", ""))]) if option.get("say", true) else []
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
	if _set_at_end != "":
		set_flag(_set_at_end)
		_set_at_end = ""
	if not _go_at_end.is_empty():
		var go := _go_at_end
		_go_at_end = []
		Game.go.call_deferred(str(go[0]), str(go[1]) if go.size() > 1 else "Entrance")
	# A moment later, so the Jump press that closed the box doesn't make her jump too
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if not is_active():
			_set_player_locked(false))
	Game.save_game()
	finished.emit(id)


func set_flag(flag: String) -> void:
	flags[flag] = true
	flag_set.emit(flag)


func _set_player_locked(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player:
		player.set("input_locked", on)


# -----------------------------------------------------------------------------
# Saving (scripts/game.gd keeps these in save.json)
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"talks": talks.duplicate(), "flags": flags.keys(), "names": names.duplicate(), "choices": choice_log.duplicate(true)}


func load_data(data: Dictionary) -> void:
	talks.clear()
	flags.clear()
	var t = data.get("talks", {})
	if t is Dictionary:
		for k in t:
			talks[str(k)] = int(t[k])
	for f in data.get("flags", []):
		flags[str(f)] = true
	names.clear()
	var n = data.get("names", {})
	if n is Dictionary:
		for k in n:
			names[str(k)] = str(n[k])
	choice_log = (data.get("choices", []) as Array).duplicate(true) if data.get("choices", []) is Array else []


func reset() -> void:
	talks.clear()
	flags.clear()
	names.clear()
	choice_log.clear()


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
	_hint.text = "%s  >" % Settings.prompt("interact")
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
