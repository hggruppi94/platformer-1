extends Node

# Autoload "Game": the player's progress (level, XP, HP, MP, items), scene changes, and saving.
# Lives across every scene.
#
# Saving: progress is written to user://save.json (on Windows: %APPDATA%\Godot\app_userdata\MyWorld\save.json)
# automatically — on arriving in a scene, on level up, on getting an item, every 30 seconds, and on quitting.
# It's loaded when the game starts, putting Nina back where she was. New Game is in the pause menu.

signal stats_changed
signal message_posted(text: String)
signal saved

var next_spawn := ""             # spawn marker name to appear at after a scene change

var level := 1
var xp := 0
var max_hp := 10
var hp := 10
var max_mp := 5
var mp := 5
var mp_level := 1                # gates MP-locked places like the Slivers

const REGEN_DELAY := 6.0         # seconds without being hurt before HP starts coming back
const REGEN_INTERVAL := 3.0      # then +1 HP this often
const MP_REGEN_INTERVAL := 2.5   # +1 MP this often, always
var _since_hurt := 0.0
var _regen_timer := 0.0
var _mp_timer := MP_REGEN_INTERVAL
var pending_message := ""        # shown by the HUD after a scene reload (e.g. after fainting)

signal equipment_changed
var items: Array[String] = []    # things the player owns, e.g. "skateboard"
var riding := false              # skateboard equipped

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 30.0
var _autosave_timer := AUTOSAVE_INTERVAL
var _resume := {}                # where to put Nina on startup: {scene, position, yaw}; used once
var _last_place := {}            # her last known {scene, position, yaw}, for saves made mid scene change


func _ready() -> void:
	load_game()
	if not _resume.is_empty():
		_go_to_saved_scene.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func has_item(item: String) -> bool:
	return item in items


func give_item(item: String) -> void:
	if has_item(item):
		return
	items.append(item)
	if item == "skateboard":
		message("You got a Skateboard! Press %s to ride, %s again to step off." % [Settings.key_name("toggle_skateboard"),
			Settings.key_name("toggle_skateboard")])
	Audio.play("pickup")
	save_game()


func toggle_skateboard() -> void:
	if not has_item("skateboard"):
		message("You don't have a skateboard yet. There's one at the Skate Park!")
		return
	riding = not riding
	equipment_changed.emit()


func xp_to_next() -> int:
	return 10 * level


func add_xp(amount: int) -> void:
	xp += amount
	var leveled := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		_level_up()
		leveled = true
	stats_changed.emit()
	if leveled:
		save_game()


func _level_up() -> void:
	level += 1
	max_hp += 5
	hp = max_hp
	max_mp += 3
	mp = max_mp
	mp_level += 1
	Audio.play("level_up")
	message("Level up! You're now Lv %d (MP Lv %d)." % [level, mp_level])


func spend_mp(amount: int) -> bool:
	if Settings.infinite_mp:
		return true
	if mp < amount:
		return false
	mp -= amount
	_mp_timer = MP_REGEN_INTERVAL
	stats_changed.emit()
	return true


func damage(amount: int) -> void:
	if Settings.no_damage:
		return
	hp = maxi(hp - amount, 0)
	_since_hurt = 0.0
	stats_changed.emit()
	if hp == 0:
		faint()


func faint() -> void:
	# Out of HP: back to the start of this area with full HP. Level, XP and items are kept.
	hp = max_hp
	mp = max_mp
	next_spawn = ""
	pending_message = "Nina fainted! She's back on her feet."
	Audio.play("faint")
	stats_changed.emit()
	get_tree().call_deferred("reload_current_scene")


func _process(delta: float) -> void:
	_since_hurt += delta
	if hp < max_hp and _since_hurt >= REGEN_DELAY:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			_regen_timer = REGEN_INTERVAL
			hp += 1
			stats_changed.emit()
	else:
		_regen_timer = REGEN_INTERVAL
	if mp < max_mp:
		_mp_timer -= delta
		if _mp_timer <= 0.0:
			_mp_timer = MP_REGEN_INTERVAL
			mp += 1
			stats_changed.emit()

	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		save_game()


func message(text: String) -> void:
	message_posted.emit(text)


func go(scene_path: String, spawn: String, place_name := "") -> void:
	if not ResourceLoader.exists(scene_path):
		message(("The %s isn't open yet." % place_name) if place_name != "" else "This door doesn't open yet.")
		return
	next_spawn = spawn
	Audio.play("door", -4.0)
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _unhandled_input(event: InputEvent) -> void:
	# Developer shortcut, only when run from the editor (not in exported builds): X for 10 XP
	if OS.is_debug_build() and event.is_action_pressed("debug_xp"):
		add_xp(10)
	if event.is_action_pressed("toggle_skateboard"):
		toggle_skateboard()


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_game() -> void:
	_autosave_timer = AUTOSAVE_INTERVAL
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"level": level, "xp": xp,
		"hp": hp, "max_hp": max_hp, "mp": mp, "max_mp": max_mp, "mp_level": mp_level,
		"items": items, "riding": riding,
	}
	# Where Nina is, so she reappears there next time
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if not _resume.is_empty():
		data.merge(_resume)      # still on the way back to where she saved: keep that place
	elif player and scene and scene.scene_file_path != "" and player.is_inside_tree():
		var p := player.global_position
		_last_place = {"scene": scene.scene_file_path, "position": [p.x, p.y, p.z],
			"yaw": (player.get_node("Visual") as Node3D).rotation.y}
		data.merge(_last_place)
	elif not _last_place.is_empty():
		data.merge(_last_place)  # mid scene change: keep the last known place rather than losing it
	# Write to a temp file first, then swap it in, so a crash mid-write can't corrupt the save
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	DirAccess.rename_absolute(tmp, SAVE_PATH)
	saved.emit()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		# Unreadable: keep it aside for inspection and start fresh
		DirAccess.rename_absolute(SAVE_PATH, "user://save.bad.json")
		push_warning("Save file was unreadable; moved to save.bad.json and started a new game.")
		pending_message = "Your save couldn't be read, so this is a new game."
		return
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	max_hp = int(data.get("max_hp", max_hp))
	hp = clampi(int(data.get("hp", max_hp)), 1, max_hp)
	max_mp = int(data.get("max_mp", max_mp))
	mp = clampi(int(data.get("mp", max_mp)), 0, max_mp)
	mp_level = int(data.get("mp_level", mp_level))
	items.clear()
	for it in data.get("items", []):
		items.append(str(it))
	riding = bool(data.get("riding", false)) and has_item("skateboard")
	var pos = data.get("position")
	if data.has("scene") and ResourceLoader.exists(str(data["scene"])) and pos is Array and pos.size() == 3:
		_resume = {"scene": str(data["scene"]), "position": [float(pos[0]), float(pos[1]), float(pos[2])],
			"yaw": float(data.get("yaw", 0.0))}
	pending_message = "Welcome back! Lv %d" % level


func _go_to_saved_scene() -> void:
	# Runs once the main scene is up. If she saved somewhere else (an interior, say), go there.
	if _resume.is_empty():
		return                   # she already appeared in the main scene where she saved
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path != _resume["scene"]:
		get_tree().change_scene_to_file(_resume["scene"])


func is_resuming() -> bool:
	return not _resume.is_empty()


func take_resume_point(scene_path: String) -> Dictionary:
	# Called by the player when she appears. Returns {position, yaw} once, if the save put her in this scene.
	if _resume.is_empty() or _resume["scene"] != scene_path:
		return {}
	var p: Array = _resume["position"]
	var r := {"position": Vector3(p[0], p[1], p[2]), "yaw": _resume["yaw"]}
	_resume = {}
	return r


func new_game() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	level = 1
	xp = 0
	max_hp = 10
	hp = 10
	max_mp = 5
	mp = 5
	mp_level = 1
	items.clear()
	riding = false
	next_spawn = ""
	_resume = {}
	_last_place = {}
	pending_message = "New game!"
	equipment_changed.emit()
	stats_changed.emit()
	get_tree().call_deferred("change_scene_to_file", ProjectSettings.get_setting("application/run/main_scene"))
