extends Node

# Autoload "Playtest": an optional notebook for watching someone play (plan prompt F6). Off unless Settings > Assist >
# "Playtest notes" is on. Then it writes one line per thing that happens to a file in the save folder:
#
#   user://playtest/notes_<date>_<time>.jsonl   (on Windows: %APPDATA%\Godot\app_userdata\MyWorld\playtest\)
#
# What it notes: each First Night step (and each night's step after it) starting and how long the one before took;
# being stuck (nothing new for STUCK seconds: no quest step, flag, sparkle, request or trick; noted once, with where they
# were); bails; menus opened (the Tab menu's sheets, the pause menu, shops); steps skipped; races started and finished;
# requests finished; and the scene (Earth, Galaxity...) every time it changes. Nothing ever leaves the PC: there's no
# network code here, only a file. tools/playtest_report.gd turns the newest file into a short summary.

const DIR := "user://playtest/"
const STUCK := 180.0                          # seconds with nothing new before it's a "stuck" moment
const WATCH_QUESTS := ["first_night", "night_2", "night_3", "night_4", "night_5", "night_6", "night_7"]

var file_path := ""
var _file: FileAccess
var _started := 0.0                           # real seconds when the notebook opened
var _quiet := 0.0                             # seconds since anything new happened
var _stuck_noted := false
var _step_at := {}                            # quest id -> [step id, time it started]
var _menu_open := false
var _pause_open := false
var _shop_open := false
var _racing := false
var _skate: Node
var _last_sparkles := 0
var _done_requests := {}
var events: Array = []                        # what's been written this session (tools/test_playtest.gd)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.changed.connect(_on_settings)
	Quests.changed.connect(_on_quest)
	Quests.skipped.connect(func(id: String, step: String) -> void: note("skip", {"quest": id, "step": step}))
	Dialogue.flag_set.connect(func(_f: String) -> void: _progress())
	PlayerMenu.sheet_changed.connect(func(s: String) -> void: note("menu", {"sheet": s}))
	Races.finished.connect(func(id: String, place: int) -> void:
		note("race_finished", {"track": id, "place": place})
		_progress())
	Requests.changed.connect(_on_requests)
	get_tree().scene_changed.connect(func() -> void:
		var s := get_tree().current_scene
		note("scene", {"scene": s.scene_file_path.get_file().get_basename() if s else ""}))
	_on_settings()


func on() -> bool:
	return bool(Settings.get("playtest"))


func _on_settings() -> void:
	if on() and _file == null:
		_open()
	elif not on() and _file != null:
		note("notes_off")
		_file.close()
		_file = null


func _open() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var t := Time.get_datetime_dict_from_system()
	file_path = DIR + "notes_%04d-%02d-%02d_%02d-%02d-%02d.jsonl" % [t.year, t.month, t.day, t.hour, t.minute, t.second]
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	_started = Time.get_ticks_msec() / 1000.0
	_quiet = 0.0
	_stuck_noted = false
	_last_sparkles = Game.sparkles
	note("notes_on", {"hero": str(Game.hero.get("name", "")), "night": Nights.night()})
	for q in WATCH_QUESTS:
		if Quests.is_started(q) and not Quests.is_done(q):
			_step_at[q] = [str(Quests.current_step(q).get("id", "")), _now()]


func _now() -> float:
	return snappedf(Time.get_ticks_msec() / 1000.0 - _started, 0.1)


func note(what: String, data := {}) -> void:
	# One line in the notebook: {"t": seconds since it opened, "what": ..., plus whatever else}
	if _file == null:
		return
	var line := {"t": _now(), "what": what}
	line.merge(data)
	events.append(line)
	_file.store_line(JSON.stringify(line))
	_file.flush()


func _progress() -> void:
	_quiet = 0.0
	_stuck_noted = false


func _on_quest(id: String) -> void:
	_progress()
	if not id in WATCH_QUESTS:
		return
	var step := str(Quests.current_step(id).get("id", "")) if not Quests.is_done(id) else "done"
	var was: Array = _step_at.get(id, ["", _now()])
	if was[0] == step:
		return
	if was[0] != "":
		note("step_done", {"quest": id, "step": was[0], "seconds": snappedf(_now() - float(was[1]), 0.1)})
	if step != "done":
		note("step", {"quest": id, "step": step})
	_step_at[id] = [step, _now()]


func _on_requests() -> void:
	for r in Requests.list:
		var key := str(r.get("kind", "")) + ":" + str(r.get("tier", ""))
		if r.done and not _done_requests.has(key):
			_done_requests[key] = true
			note("request_done", {"kind": str(r.get("kind", "")), "tier": str(r.get("tier", ""))})
			_progress()


func _process(delta: float) -> void:
	if _file == null:
		return
	if get_tree().paused or Dialogue.is_active():
		_progress()                           # reading or in a menu isn't being stuck
	else:
		_quiet += delta
	if Game.sparkles != _last_sparkles:
		_last_sparkles = Game.sparkles
		_progress()
	if _quiet >= STUCK and not _stuck_noted:
		_stuck_noted = true
		var p := get_tree().get_first_node_in_group("player") as Node3D
		var where := p.global_position.snapped(Vector3.ONE) if p else Vector3.ZERO
		var steps := {}
		for q in WATCH_QUESTS:
			if Quests.is_started(q) and not Quests.is_done(q):
				steps[q] = str(Quests.current_step(q).get("id", ""))
		note("stuck", {"seconds": int(_quiet), "scene": _scene_name(), "at": [where.x, where.y, where.z], "steps": steps})
	# Menus and races, as they open and start
	if PlayerMenu.is_open() != _menu_open:
		_menu_open = PlayerMenu.is_open()
		if _menu_open:
			note("menu_open", {"sheet": str(PlayerMenu.sheet)})
	if PauseMenu.is_open() != _pause_open:
		_pause_open = PauseMenu.is_open()
		if _pause_open:
			note("pause_menu")
	if Shop.is_open() != _shop_open:
		_shop_open = Shop.is_open()
		if _shop_open:
			note("shop", {"stall": str(Shop._stall)})
	if Races.racing() != _racing:
		_racing = Races.racing()
		if _racing:
			note("race_started")
	# Bails: the skater's own signal, hooked whenever a new player appears
	var player := get_tree().get_first_node_in_group("player")
	var skate: Node = player.get_node_or_null("Skate") if player else null
	if skate != _skate:
		_skate = skate
		if _skate and _skate.has_signal("bailed") and not _skate.bailed.is_connected(_on_bail):
			_skate.bailed.connect(_on_bail)


func _on_bail() -> void:
	note("bail", {"scene": _scene_name()})


func _scene_name() -> String:
	var s := get_tree().current_scene
	return s.scene_file_path.get_file().get_basename() if s else ""
