extends Node

# Autoload "Game": the player's progress (level, XP, HP, MP, items), scene changes, and saving.
# Lives across every scene.
#
# Saving: progress is written to user://save.json (on Windows: %APPDATA%\Godot\app_userdata\MyWorld\save.json)
# automatically — on arriving in a scene, on level up, on getting an item, on sleeping, every 30 seconds,
# and on quitting. The day and time of day (scripts/clock.gd), who she's talked to (scripts/dialogue.gd) and how far
# she's got in each quest (scripts/quests.gd) are saved with it.
# It's loaded when the game starts, putting Nina back where she was. New Game is in the pause menu.
# A new game (or the very first start, with no save) begins on Earth, where the player lives: in their house by the
# town green, just out of bed (the HomeSpawn marker in scenes/earth/earth.tscn, the main scene).
# Saves remember which town layout they were made in (LAYOUT): a save made outdoors in an older town starts her at
# the Market Square's entrance instead, since buildings may have moved onto the spot where she stood.

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
var max_sp := 100.0              # stamina: spent by rolling, refills quickly on its own
var sp := 100.0

signal sp_changed
const SP_REGEN := 45.0           # SP per second...
const SP_DELAY := 0.6            # ...once this long has passed since she last spent any
var _since_sp := 10.0

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
var hero := Hero.blank()         # the player's own character, made in the character creator (scripts/hero.gd)
var needs_creator := false       # a new game (or an old save from before heroes): open the creator on arriving
var popper_colour := "classic"   # the Star Popper's colours (StarPopper.COLOURS); others are earned (Watches)
var home := {}                   # how the player's house is decorated: part -> colour number, spot -> item (scripts/home_decor.gd)
var outfits := {"hero": {}}      # what everyone's wearing: who -> {slot -> shop item id} (scripts/clothes.gd)
var looks := {}                  # how everyone looks: who -> {part -> colour number}; 0 or missing is their own
var outfit: Dictionary:          # the player's outfit; a missing slot is their own look
	get:
		if not outfits.has("hero"):
			outfits["hero"] = {}
		return outfits["hero"]
	set(v):
		outfits["hero"] = v
var hat: String:                 # the hat she's wearing: the outfit's head slot ("" for none)
	get:
		return str(outfit.get("head", ""))
	set(id):
		if id == "":
			outfit.erase("head")
		else:
			outfit["head"] = id

# Sparkles: little bits of broken time left lying about (from the show). They're the money: found around town
# (scripts/sparkle.gd, they drift back the next day), earned from quests and happy places, spent at the market stalls.
signal sparkles_changed
var sparkles := 0
var sparkles_taken := {}         # sparkle name -> the day she picked it up
const HAPPY_PLACE_SPARKLES := 3  # for finding a happy place the first time

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2          # 2: the player lives on Earth, and Galaxity is visited in the Shift (scripts/clock.gd)
const LAYOUT := 2                # the town's layout: 2 = market under the plateau, homes east of the lake
const TOWN_SCENE := "res://scenes/town/town.tscn"
const NEW_GAME_SPAWN := "HomeSpawn"      # in the player's house on Earth (the main scene)
const NEW_GAME_MESSAGE := "Welcome home! At midnight the portal by the old oak opens to Galaxity."
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
		message("You got a Skateboard! Press %s to ride, %s again to step off." % [Settings.prompt("toggle_skateboard"),
			Settings.prompt("toggle_skateboard")])
	Audio.play("pickup")
	save_game()


func add_sparkles(amount: int, why := "") -> void:
	sparkles += amount
	sparkles_changed.emit()
	if why != "":
		message("%s +%d sparkle%s" % [why, amount, "" if amount == 1 else "s"])


func spend_sparkles(amount: int) -> bool:
	if sparkles < amount:
		return false
	sparkles -= amount
	sparkles_changed.emit()
	return true


func sparkle_taken(id: String) -> bool:
	# Picked up today? (Tomorrow it's back.)
	return int(sparkles_taken.get(id, -1)) == Clock.day


func take_sparkle(id: String) -> void:
	sparkles_taken[id] = Clock.day
	add_sparkles(1)


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
	max_sp += 10.0
	sp = max_sp
	sp_changed.emit()
	mp_level += 1
	Audio.play("level_up")
	message("Level up! You're now Lv %d (MP Lv %d)." % [level, mp_level])


func spend_sp(amount: float) -> bool:
	if Settings.infinite_sp:
		return true
	if sp < amount:
		return false
	sp -= amount
	_since_sp = 0.0
	sp_changed.emit()
	return true


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
	sp = max_sp
	next_spawn = ""
	pending_message = "%s fainted! %s back on %s feet." % [Dialogue.player_name(),
		(Hero.pronoun(hero, "they") + ("'re" if Hero.pronoun(hero, "are") == "are" else "'s")).capitalize(), Hero.pronoun(hero, "their")]
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
	if sp < max_sp:
		_since_sp += delta
		if _since_sp >= SP_DELAY:
			sp = minf(sp + SP_REGEN * delta, max_sp)
			sp_changed.emit()
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
	if event.is_action_pressed("toggle_skateboard") and not Dialogue.is_active() and not _player_carried() \
			and _board_button_free(event):
		toggle_skateboard()


func _board_button_free(event: InputEvent) -> bool:
	# On a controller, Y is both the board and Grind (scenes/player/skate.gd). While she's riding it only steps her off
	# when she's rolling on the ground with no rail in reach; the keyboard has its own Grind key, so E always works on
	# the ground.
	var player := get_tree().get_first_node_in_group("player")
	if not riding or player == null or player.get("skate") == null:
		return true
	if not player.skate.can_step_off():
		return false
	return not (event is InputEventJoypadButton and player.skate.rail_in_reach())


func _player_carried() -> bool:
	# On the zipline or in the mothership: no hopping on the skateboard
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.get("carried") == true


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_game() -> void:
	_autosave_timer = AUTOSAVE_INTERVAL
	var data := {
		"version": SAVE_VERSION,
		"layout": LAYOUT,
		"saved_at": Time.get_datetime_string_from_system(),
		"level": level, "xp": xp,
		"hp": hp, "max_hp": max_hp, "mp": mp, "max_mp": max_mp, "mp_level": mp_level, "max_sp": max_sp,
		"items": items, "riding": riding, "hat": hat, "outfit": outfit, "outfits": outfits, "looks": looks, "hero": hero, "needs_creator": needs_creator, "home": home,
		"popper_colour": popper_colour,
		"sparkles": sparkles, "sparkles_taken": sparkles_taken,
		"day": Clock.day, "minutes": Clock.minutes, "earth_minutes": Clock.earth_minutes,
		"dialogue": Dialogue.save_data(),
		"quests": Quests.save_data(),
		"requests": Requests.save_data(),
	}
	# Where Nina is, so she reappears there next time
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if not _resume.is_empty():
		data.merge(_resume)      # still on the way back to where she saved: keep that place
	elif player and scene and scene.scene_file_path != "" and player.is_inside_tree():
		# Up in the mothership she saves as if back on its pad (scripts/mothership.gd), not in mid-air
		var p: Vector3 = player.get_meta("save_spot", player.global_position)
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
		next_spawn = NEW_GAME_SPAWN                     # the very first start: wake up at home
		pending_message = NEW_GAME_MESSAGE
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
	max_sp = float(data.get("max_sp", 90.0 + 10.0 * level))   # older saves: work it out from the level
	sp = max_sp
	items.clear()
	for it in data.get("items", []):
		items.append(str(it))
	riding = bool(data.get("riding", false)) and has_item("skateboard")
	# The clocks. Away from Earth it's always the Shift, so setting Galaxity's time puts Earth's at the matching moment
	# of it. That's all a save from before the player lived on Earth (version 1) needs: one made in Galaxity carries on
	# right there, in the Shift, until Galaxity's next dawn. Saves made on Earth, and newer ones, keep Earth's own time.
	var saved_scene := str(data.get("scene", ""))
	if data.has("day") and data.has("minutes"):     # older saves have no clock: keep the new-game time
		Clock.set_time(int(data["day"]), float(data["minutes"]), true)
	if int(data.get("version", 1)) >= 2 or saved_scene == Clock.EARTH:
		Clock.earth_minutes = float(data.get("earth_minutes", Clock.EARTH_START))
	if saved_scene != Clock.EARTH and not Clock.in_shift():
		Clock.set_time(Clock.day, Clock.minutes, true)
	var dialogue = data.get("dialogue", {})
	Dialogue.load_data(dialogue if dialogue is Dictionary else {})
	var quests = data.get("quests", {})
	Quests.load_data(quests if quests is Dictionary else {})
	var requests = data.get("requests", {})                  # saves from before the request board have none
	Requests.load_data(requests if requests is Dictionary else {})
	outfits = {"hero": {}}
	var all_worn = data.get("outfits", {"hero": data.get("outfit", {})})
	if all_worn is Dictionary:
		for who in all_worn:
			var worn = all_worn[who]
			if worn is Dictionary:
				outfits[str(who)] = {}
				for slot in worn:
					outfits[str(who)][str(slot)] = str(worn[slot])
	# The player's own character; a save from before heroes was Nina's, so her outfit becomes theirs and they get to
	# make their hero
	hero = Hero.blank()
	needs_creator = not data.get("hero", null) is Dictionary
	if not needs_creator:
		# A new game saves as soon as the player arrives, before the hero's made: if they quit then, they still get to
		# make one next time
		needs_creator = bool(data.get("needs_creator", false))
		hero.merge(data["hero"], true)
	elif outfits.has("nina") and outfits["hero"].is_empty():
		outfits["hero"] = outfits["nina"]
		outfits.erase("nina")
	home = data.get("home", {}) if data.get("home", {}) is Dictionary else {}
	popper_colour = str(data.get("popper_colour", "classic"))
	looks = {}
	var all_looks = data.get("looks", {})
	if all_looks is Dictionary:
		for who in all_looks:
			if all_looks[who] is Dictionary:
				looks[str(who)] = {}
				for part in all_looks[who]:
					looks[str(who)][str(part)] = int(all_looks[who][part])
	if not outfit.has("head") and str(data.get("hat", "")) != "":
		hat = str(data["hat"])                       # a save from before outfits: just a hat
	sparkles_taken.clear()
	var taken = data.get("sparkles_taken", {})
	if taken is Dictionary:
		for k in taken:
			sparkles_taken[str(k)] = int(taken[k])
	if data.has("sparkles"):
		sparkles = int(data["sparkles"])
	else:
		sparkles = _sparkles_already_earned()          # a save from before sparkles: pay for what she's already done
	var pos = data.get("position")
	if data.has("scene") and ResourceLoader.exists(str(data["scene"])) and pos is Array and pos.size() == 3:
		_resume = {"scene": str(data["scene"]), "position": [float(pos[0]), float(pos[1]), float(pos[2])],
			"yaw": float(data.get("yaw", 0.0))}
	pending_message = "Welcome back! Lv %d" % level
	if _resume.get("scene", "") == TOWN_SCENE and int(data.get("layout", 1)) < LAYOUT:
		# Saved outdoors in the old town: start at the market entrance rather than where she stood
		_resume = {"scene": TOWN_SCENE}
		next_spawn = "MarketEntrance"
		pending_message = "Welcome back! The town has had a makeover. You're at the Market Square."


func _sparkles_already_earned() -> int:
	var total := 0
	for id in Quests.state:
		if Quests.is_done(id):
			total += int(Quests.quest(id).get("reward", {}).get("sparkles", 0))
	total += HAPPY_PLACE_SPARKLES * items.filter(func(i: String) -> bool: return i.begins_with("happy_place:")).size()
	return total


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
	if not _resume.has("position"):                  # (an old-layout save: she's at a marker instead)
		_resume = {}
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
	max_sp = 100.0
	sp = 100.0
	mp_level = 1
	items.clear()
	riding = false
	outfits = {"hero": {}}
	looks = {}
	hero = Hero.blank()
	needs_creator = true
	home = {}
	popper_colour = "classic"
	sparkles = 0
	sparkles_taken.clear()
	Clock.reset()
	Dialogue.reset()
	Quests.reset()
	Requests.reset()
	next_spawn = NEW_GAME_SPAWN                      # wake up at home
	_resume = {}
	_last_place = {}
	pending_message = NEW_GAME_MESSAGE
	equipment_changed.emit()
	stats_changed.emit()
	get_tree().call_deferred("change_scene_to_file", ProjectSettings.get_setting("application/run/main_scene"))
