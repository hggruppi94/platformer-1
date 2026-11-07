extends Node

# Autoload "Quests": the quest lines, written as plain data in res://quests/<id>.json (see res://quests/README.md).
#
# A quest starts when its "start" flags are set, then goes step by step. A step is done when its flags are set:
# flags come from conversations (scripts/dialogue.gd: an answer's or a whole conversation's "set") and from quest
# spots in town (scripts/quest_spot.gd, e.g. hanging a poster). A step can make you wait ("wait": {"days": 1}: come
# back tomorrow), and can move someone for an event while it's on ("override": Rex's rally at the fountain, in the
# evening; scripts/routine.gd asks override_for()). Finishing a quest can give an item and a new title.
#
# Progress is saved with the game (scripts/game.gd). A banner slides in when a quest starts, updates or finishes, and
# the quest log (the player menu's Quests sheet, scripts/player_menu.gd: Tab, or the "quest_log" key, Q) shows each
# quest as a card (cards_view()): its name, who gave it ("giver" in the file, or the first person a step sends you
# to), a picture, the step with its ticks, and the reward. Both wear the shared menu look (scripts/ui_style.gd).

signal changed(quest_id: String)
signal skipped(quest_id: String, step_id: String)    # a step skipped from the quest log (scripts/playtest.gd notes it)

const DIR := "res://quests"
const NOTE_TIME := 4.5

var state := {}                      # quest id -> {"step": index, "since_day": day the step began, "done": bool}
var _data := {}                      # quest id -> its file
var _order: Array[String] = []
var _check_wait := 0.0

var _note_layer: CanvasLayer
var _note: PanelContainer
var _note_label: Label
var _note_title: Label
var _note_body: Label
var _note_tween: Tween
var _names := {}                      # character id -> their name, from res://dialogue/<id>.json (for the cards)
var _note_time := 0.0
var _log_text: RichTextLabel         # shown on the player menu's Quests sheet


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
		_celebrate()
	else:
		var step := current_step(id)
		var text: String = step.get("text", "")
		if is_waiting(id):
			text += "\n" + str(step.get("wait", {}).get("text", "(Come back tomorrow.)"))
		_announce("Quest updated: %s" % q.get("name", id), text)
		Audio.play("pickup", -6.0)
	changed.emit(id)
	Game.save_game()


func can_skip(id: String) -> bool:
	# A quest whose file says "skippable" (the First Night) can skip its current step from the quest log
	return bool(quest(id).get("skippable", false)) and not current_step(id).is_empty()


func skip(id: String) -> void:
	# Skip the step it's on: its flags are set as if it had been done (any wait is over too), and it moves on
	if not can_skip(id):
		return
	var step := current_step(id)
	skipped.emit(id, str(step.get("id", "")))
	var cond: Dictionary = step.get("done", {})
	var wait := int(step.get("wait", {}).get("days", 0))
	if wait > 0:
		state[id].since_day = Clock.day - wait
	if cond.has("flag"):
		Dialogue.flags[str(cond.flag)] = true
	for f in cond.get("flags", []):
		Dialogue.flags[str(f)] = true
	check()


func _celebrate() -> void:
	# A shower of sparkles round the player and a happy little sound (scripts/juice.gd)
	Juice.blip("sparkle", 1.0, -6.0)
	Juice.rumble(0.3, 0.2)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p:
		Juice.burst(p.get_parent(), p.global_position + Vector3(0, 2.0, 0), Color(1.0, 0.88, 0.4), 20, 0.07, 3.5, 1.0)
		Juice.burst(p.get_parent(), p.global_position + Vector3(0, 2.0, 0), Color(0.75, 0.6, 1.0), 14, 0.06, 3.0, 1.0)


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
	# The banner: a quest card that slides in from the right with a little bounce (or just appears, with Reduce motion)
	_note_label.text = title + ("\n" + text if text != "" else "")    # (the whole note, for note_text())
	var parts := title.split(": ", true, 1)
	_note_title.text = (parts[0] + "!") if parts.size() > 1 else title
	_note_body.text = (parts[1] if parts.size() > 1 else "") + ("\n" + text if text != "" else "")
	_note_time = NOTE_TIME
	_note.modulate.a = 1.0
	if _note_tween:
		_note_tween.kill()
	_note.pivot_offset = Vector2(_note.size.x, 0)
	if Settings.reduce_motion:
		_note.position.x = _note_x()
		return
	_note.position.x = _note_x() + _note.size.x + 40.0
	_note.scale = Vector2(0.9, 0.9)
	_note_tween = create_tween().set_parallel()
	_note_tween.tween_property(_note, "position:x", _note_x(), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_note_tween.tween_property(_note, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _note_x() -> float:
	var vp := _note.get_viewport_rect().size if _note.is_inside_tree() else Vector2(1280, 720)
	return vp.x - _note.size.x - 16.0


func note_text() -> String:
	return _note_label.text if _note_time > 0.0 else ""


# The log is the player menu's Quests sheet (scripts/player_menu.gd), which Q (the "quest_log" key) and Tab open,
# pausing the game under it.
func is_log_open() -> bool:
	return PlayerMenu.showing("quests")


func toggle_log() -> void:
	PlayerMenu.toggle_sheet("quests")


func log_view() -> RichTextLabel:
	# The sheet shows this, filled in fresh each time it opens
	_note_time = 0.0                                       # the log says it all; don't cover it
	_note.modulate.a = 0.0
	_log_text.text = log_text()
	return _log_text


func cards_view() -> VBoxContainer:
	# The Quests sheet's cards, built fresh: the quests on the go first, then the finished ones (smaller)
	var box := VBoxContainer.new()
	box.name = "Quest Cards"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", roundi(12 * Settings.text_scale))
	var any := false
	for done in [false, true]:
		for id in _order:
			if is_started(id) and is_done(id) == done:
				box.add_child(card(id))
				any = true
	if not any:
		var l := Label.new()
		l.text = "No quests yet. Talk to people around town!"
		box.add_child(l)
	return box


func card(id: String) -> PanelContainer:
	# One quest as a card: a picture of who gave it, the name, who from, the step and its ticks, and the reward
	var sc := Settings.text_scale
	var q := quest(id)
	var done := is_done(id)
	var c := PanelContainer.new()
	c.name = "Card " + id
	c.theme_type_variation = "Card"
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if done:
		c.add_theme_stylebox_override("panel", UiStyle.card(Color(0.16, 0.22, 0.24), Settings.high_contrast, sc))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(16 * sc))
	c.add_child(row)
	var who := giver(id)
	var pic := QuestPicture.new()
	pic.name = "Picture"
	pic.letter = giver_name(who).substr(0, 1).to_upper() if who != "" else "?"
	pic.colour = _colour_of(who if who != "" else id)
	pic.done = done
	pic.custom_minimum_size = Vector2.ONE * roundi((56 if done else 84) * sc)
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", roundi(2 * sc))
	row.add_child(v)
	var title := _card_label(v, str(q.get("name", id)) + ("  ✔ Done!" if done else ""), 26 if not done else 22, Color(0.7, 1.0, 0.75) if done else UiStyle.GOLD)
	title.name = "Title"
	title.add_theme_constant_override("outline_size", roundi(7 * sc))
	if who != "":
		_card_label(v, "From " + giver_name(who), 17, Color(0.8, 0.75, 0.95)).name = "From"
	if done:
		return c
	var step := current_step(id)
	var text := _card_label(v, str(step.get("text", "")), 20, UiStyle.TEXT)
	text.name = "Step"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for item in checklist(id):
		var tick := _card_label(v, ("  ✔  " if item[1] else "  ○  ") + str(item[0]), 19, Color(0.6, 1.0, 0.7) if item[1] else UiStyle.TEXT)
		tick.name = "Tick"
		tick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_waiting(id):
		_card_label(v, str(step.get("wait", {}).get("text", "(Come back tomorrow.)")), 18, Color(0.96, 0.9, 0.64)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var reward := reward_text(id)
	if reward != "":
		_card_label(v, "Reward: " + reward, 18, Color(1.0, 0.88, 0.45)).name = "Reward"
	return c


func reward_text(id: String) -> String:
	var r: Dictionary = quest(id).get("reward", {})
	var bits: Array[String] = []
	if r.has("sparkles"):
		bits.append("✦ %d sparkles" % int(r.sparkles))
	if r.has("item"):
		bits.append("a surprise")
	if not quest(id).get("titles", {}).is_empty():
		bits.append("a new title")
	return ", ".join(bits)


func giver(id: String) -> String:
	# Who gave the quest: "giver" in its file, or else the first person one of its steps sends you to
	var q := quest(id)
	if q.has("giver"):
		return str(q.giver)
	for step in q.get("steps", []):
		for w in step.get("where", []):
			if w is String and FileAccess.file_exists("%s/%s.json" % [Dialogue.DIR, w]):
				return w
			if w is Dictionary and w.has("who"):
				return str(w.who)
	return ""


func giver_name(who: String) -> String:
	if not _names.has(who):
		var n := who.capitalize()
		var f := FileAccess.open("%s/%s.json" % [Dialogue.DIR, who], FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if data is Dictionary and data.has("name"):
				n = str(data.name)
		_names[who] = n
	return display_name(who, str(_names[who]))


func _colour_of(key: String) -> Color:
	# Each person's picture gets its own colour from the alien palette, the same every time
	var cols := [UiStyle.TEAL_DEEP, UiStyle.MAGENTA, Color(0.55, 0.45, 0.95), Color(0.95, 0.6, 0.25), Color(0.5, 0.85, 0.3),
		Color(0.3, 0.6, 0.95)]
	return cols[absi(hash(key)) % cols.size()]


func _card_label(parent: Node, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", roundi(size * Settings.text_scale))
	l.add_theme_color_override("font_color", col)
	l.custom_minimum_size.x = roundi(200 * Settings.text_scale)
	parent.add_child(l)
	return l


func extras_text() -> String:
	# What the cards don't cover, for under them on the sheet: tonight's requests, Earth's jobs, the festival
	var lines: Array[String] = []
	lines.append_array(Requests.log_lines())
	lines.append_array(EarthJobs.log_lines())
	lines.append_array(Festival.log_lines())
	return "\n".join(lines).strip_edges()


func log_view_node() -> RichTextLabel:
	return _log_text


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
	lines.append_array(Requests.log_lines())              # tonight's request board (scripts/requests.gd)
	lines.append_array(EarthJobs.log_lines())             # today's jobs on Earth's notice board (scripts/earth_jobs.gd)
	lines.append_array(Festival.log_lines())              # the Autumn Festival, when it's on (scripts/festival.gd)
	lines.append("")
	lines.append("[color=#c8c8d8](%s to close)[/color]" % Settings.prompt("quest_log"))
	return "\n".join(lines)


func _build_ui() -> void:
	_note_layer = CanvasLayer.new()
	_note_layer.layer = 15
	add_child(_note_layer)
	_note = PanelContainer.new()
	_note.name = "Quest Banner"
	_note.position = Vector2(900, 60)
	_note.modulate.a = 0.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_note.add_child(v)
	_note_title = Label.new()
	_note_title.uppercase = true
	v.add_child(_note_title)
	_note_body = Label.new()
	_note_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note_body)
	_note_label = Label.new()                          # the note as one text (note_text()), not shown
	_note_label.visible = false
	v.add_child(_note_label)
	_note_layer.add_child(_note)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.fit_content = true
	_log_text.scroll_active = false
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _exit_tree() -> void:
	if _log_text.get_parent() == null:
		_log_text.free()                               # put away (not on the player menu) when the game quits


func _apply_look() -> void:
	var hc := Settings.high_contrast
	var sc := Settings.text_scale
	_note.theme = UiStyle.theme()
	_note.add_theme_stylebox_override("panel", UiStyle.card(Color(0, 0, 0, 0.95) if hc else Color(0.2, 0.12, 0.34, 0.95), hc, sc))
	_note.custom_minimum_size.x = roundi(340 * sc)
	_note.size.x = _note.custom_minimum_size.x
	_note_title.add_theme_font_size_override("font_size", roundi(22 * sc))
	_note_title.add_theme_color_override("font_color", Color(1, 1, 0.6) if hc else UiStyle.GOLD)
	_note_title.add_theme_constant_override("outline_size", roundi(7 * sc))
	_note_body.custom_minimum_size.x = roundi(300 * sc)
	_note_body.add_theme_font_size_override("font_size", roundi(19 * sc))
	_note_body.add_theme_color_override("font_color", Color(1, 1, 0.8) if hc else UiStyle.TEXT)
	_log_text.custom_minimum_size = Vector2(roundi(560 * Settings.text_scale), 0)
	_log_text.add_theme_font_override("normal_font", UiStyle.font())
	_log_text.add_theme_font_override("bold_font", UiStyle.font())
	_log_text.add_theme_font_size_override("normal_font_size", roundi(20 * Settings.text_scale))
	_log_text.add_theme_font_size_override("bold_font_size", roundi(24 * Settings.text_scale))
