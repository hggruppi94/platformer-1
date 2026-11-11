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
signal leveled_up(level: int)    # after each level gained (scripts/ride_upgrades.gd opens rides with it)

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
var hero_ride := "board"         # what the hero rides (Rides.HERO_RIDES); others are unlocked by schematics (Schematics)
var home := {}                   # how the player's house is decorated: part -> colour number, spot -> item (scripts/home_decor.gd)
var outfits := {"hero": {}}      # what everyone's wearing: who -> {slot -> shop item id} (scripts/clothes.gd)
var looks := {}                  # how everyone looks: who -> {part -> colour number}; 0 or missing is their own
var saved_outfits := []          # the quick outfit wheel's outfits (scripts/quick_outfits.gd): up to 6, null for an empty slot
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

const SAVE_PATH := "user://save.json"   # slot 1's save (and the only one tools and tests ever touch)
# Save slots: three games side by side (Hayden, 7 Nov 2026). Slot 1 is save.json, as it always was, so saves from
# before slots are slot 1; the others are save_slot2.json and save_slot3.json. The slot last played is kept in
# slots.cfg so Continue picks it up. Tools and tests (run with --script) always use slot 1 and never change slots.cfg.
const SLOTS := 3
const SLOTS_CFG := "user://slots.cfg"
var slot := 1
var hold_saves := false          # tools set this when they're done, so nothing saves over the save they put back
const SAVE_VERSION := 2          # 2: the player lives on Earth, and the Void is visited in the Shift (scripts/clock.gd)
const LAYOUT := 2                # the town's layout: 2 = market under the plateau, homes east of the lake
const EARTH_LAYOUT := 2          # Earth's layout: 2 = the grown-up town (Main Street, Maple Lane, the park), Oct 30 2026
const TOWN_SCENE := "res://scenes/town/town.tscn"
const TITLE_SCENE := "res://scenes/title/title.tscn"   # the game opens on the title screen (scripts/title_screen.gd)...
const START_SCENE := "res://scenes/earth/earth.tscn"   # ...and a game starts (or carries on) from Earth
const NEW_GAME_SPAWN := "HomeSpawn"      # in the player's house on Earth (the main scene)
const NEW_GAME_MESSAGE := "Welcome home to Stars Hollow!"                    # no spoilers: the oak keeps its secret till midnight
const AUTOSAVE_INTERVAL := 30.0
var _autosave_timer := AUTOSAVE_INTERVAL
var _resume := {}                # where to put Nina on startup: {scene, position, yaw}; used once
var _last_place := {}            # her last known {scene, position, yaw}, for saves made mid scene change
var play_time := 0.0             # seconds played, all told (shown on the title screen's Continue)


func _ready() -> void:
	slot = _last_slot()
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
	leveled_up.emit(level)


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

	if on_title():
		return                                       # the title screen isn't playing: no time, no autosave
	if not get_tree().paused:
		play_time += delta
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
	Loading.show_for(scene_path)               # between Earth and the Void: a tip and a little alien (loading_screen.gd)
	get_tree().call_deferred("change_scene_to_file", scene_path)


func go_to_point(scene_path: String, pos: Vector3, yaw: float, place_name := "") -> void:
	# Like go(), but to a spot rather than a marker (coming home from a portal world: scripts/portals.gd). The player
	# picks it up on arriving, the way a save puts her back where she was (take_resume_point()).
	if not ResourceLoader.exists(scene_path):
		message("The %s isn't open yet." % place_name if place_name != "" else "This way doesn't open yet.")
		return
	next_spawn = ""
	_resume = {"scene": scene_path, "position": [pos.x, pos.y, pos.z], "yaw": yaw}
	Audio.play("door", -4.0)
	Loading.show_for(scene_path)
	get_tree().call_deferred("change_scene_to_file", scene_path)


func _unhandled_input(event: InputEvent) -> void:
	# Developer shortcut, only when run from the editor (not in exported builds): X for 10 XP
	if OS.is_debug_build() and event.is_action_pressed("debug_xp"):
		add_xp(10)
	if event.is_action_pressed("toggle_skateboard") and not Dialogue.is_active() and not _player_carried() \
			and _board_button_free(event):
		toggle_skateboard()


func _board_button_free(event: InputEvent) -> bool:
	# Y on a controller and E on the keyboard are both the board and Grind (scenes/player/skate.gd). While she's riding
	# the button only steps her off when she's rolling on the ground with no rail in reach. (If the player gives Grind
	# a key of its own, the board key always works on the ground.)
	var player := get_tree().get_first_node_in_group("player")
	if not riding or player == null or player.get("skate") == null:
		return true
	if not player.skate.can_step_off():
		return false
	return not (event.is_action("skate_grind") and player.skate.rail_in_reach())


func _player_carried() -> bool:
	# On the zipline or in the mothership: no hopping on the skateboard
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.get("carried") == true


func hold_controls(who: StringName, on: bool, player: Node = null) -> void:
	# Take or let go of who's hold on the player's controls (scenes/player/player.gd lock_input). Every system that
	# stops her moving (talks, countdowns, cutscenes, rides) goes through here with its own name, so they never undo
	# each other's holds.
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player) or not player.has_method("lock_input"):
		return
	if on:
		player.lock_input(who)
	else:
		player.unlock_input(who)


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_game() -> void:
	_autosave_timer = AUTOSAVE_INTERVAL
	if hold_saves:
		return
	var data := {
		"version": SAVE_VERSION,
		"layout": LAYOUT,
		"earth_layout": EARTH_LAYOUT,
		"saved_at": Time.get_datetime_string_from_system(),
		"level": level, "xp": xp,
		"hp": hp, "max_hp": max_hp, "mp": mp, "max_mp": max_mp, "mp_level": mp_level, "max_sp": max_sp,
		"items": items, "riding": riding, "hat": hat, "outfit": outfit, "outfits": outfits, "looks": looks, "saved_outfits": saved_outfits, "hero": hero, "needs_creator": needs_creator, "home": home,
		"popper_colour": popper_colour, "play_time": play_time, "hero_ride": hero_ride,
		"sparkles": sparkles, "sparkles_taken": sparkles_taken,
		"day": Clock.day, "minutes": Clock.minutes, "earth_minutes": Clock.earth_minutes,
		"calendar_offset": Clock.calendar_offset, "seasons_open": Clock.seasons_open.duplicate(),
		"dialogue": Dialogue.save_data(),
		"quests": Quests.save_data(),
		"followed": Quests.follow_save(),                # what the player follows (the Quests sheet's Follow buttons)
		"requests": Requests.save_data(),
		"earth_jobs": EarthJobs.save_data(),
		"festival": Festival.save_data(),
		"arsenal": Arsenal.save_data(),
		"races": Races.save_data(),
		"skate_runs": SkateRuns.save_data(),
		"remnants": Remnants.save_data(),
		"farm": Farm.save_data(),
		"portals": Portals.save_data(),
	}
	# Where Nina is, so she reappears there next time
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if not _resume.is_empty():
		data.merge(_resume)      # still on the way back to where she saved: keep that place
	elif not Races.save_place().is_empty():
		data.merge(Races.save_place())     # on a race circuit: saved back at its race gate (scripts/races.gd)
	elif player and scene and scene.scene_file_path != "" and player.is_inside_tree():
		# Up in the mothership she saves as if back on its pad (scripts/mothership.gd), not in mid-air
		var p: Vector3 = player.get_meta("save_spot", player.global_position)
		_last_place = {"scene": scene.scene_file_path, "position": [p.x, p.y, p.z],
			"yaw": (player.get_node("Visual") as Node3D).rotation.y}
		data.merge(_last_place)
	elif not _last_place.is_empty():
		data.merge(_last_place)  # mid scene change: keep the last known place rather than losing it
	# Write to a temp file first, then swap it in, so a crash mid-write can't corrupt the save
	var tmp := save_path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Couldn't write save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	DirAccess.rename_absolute(tmp, save_path())
	saved.emit()


func load_game() -> void:
	if not FileAccess.file_exists(save_path()):
		next_spawn = NEW_GAME_SPAWN                     # the very first start: wake up at home
		pending_message = NEW_GAME_MESSAGE
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if typeof(data) != TYPE_DICTIONARY:
		# Unreadable: keep it aside for inspection and start fresh
		DirAccess.rename_absolute(save_path(), save_path().get_basename() + ".bad.json")
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
	# The clocks. Away from Earth it's always the Shift, so setting the Void's time puts Earth's at the matching moment
	# of it. That's all a save from before the player lived on Earth (version 1) needs: one made in the Void carries on
	# right there, in the Shift, until the Void's next dawn. Saves made on Earth, and newer ones, keep Earth's own time.
	var saved_scene := str(data.get("scene", ""))
	if data.has("day") and data.has("minutes"):     # older saves have no clock: keep the new-game time
		Clock.set_time(int(data["day"]), float(data["minutes"]), true)
	if int(data.get("version", 1)) >= 2 or saved_scene == Clock.EARTH:
		Clock.earth_minutes = float(data.get("earth_minutes", Clock.EARTH_START))
	if saved_scene != Clock.EARTH and not Clock.in_shift():
		Clock.set_time(Clock.day, Clock.minutes, true)
	# Earth's calendar (scripts/clock.gd): a save from before it keeps its weekday and lands in late autumn
	if data.has("calendar_offset"):
		Clock.calendar_offset = int(data["calendar_offset"])
	else:
		Clock.fit_calendar_to_old_save()
	# Its seasons (plan item 20): a save from before seasons were unlocked one by one keeps all four
	var open = data.get("seasons_open", null)
	Clock.seasons_open = Clock.SEASONS.duplicate()
	if open is Array and not (open as Array).is_empty():
		Clock.seasons_open = Clock.SEASONS.filter(func(x) -> bool: return x in open)
	var dialogue = data.get("dialogue", {})
	Dialogue.load_data(dialogue if dialogue is Dictionary else {})
	var quests = data.get("quests", {})
	Quests.load_data(quests if quests is Dictionary else {})
	FirstNight.migrate()                          # an old save's First Night steps, moved to the Humming Oak's
	Quests.follow_load(data.get("followed", null))  # (a save from before following follows its to-do list's quest)
	var requests = data.get("requests", {})                  # saves from before the request board have none
	Requests.load_data(requests if requests is Dictionary else {})
	var jobs = data.get("earth_jobs", {})                    # saves from before Earth's notice board have none
	EarthJobs.load_data(jobs if jobs is Dictionary else {})
	var festival = data.get("festival", {})
	Festival.load_data(festival if festival is Dictionary else {})
	var arsenal = data.get("arsenal", {})                    # saves from before gadgets have none: just the popper
	Arsenal.load_data(arsenal if arsenal is Dictionary else {})
	if not data.has("arsenal"):
		Arsenal.old_save()
	var races = data.get("races", {})                        # saves from before the races have none
	Races.load_data(races if races is Dictionary else {})
	var runs = data.get("skate_runs", {})                    # saves from before the skate runs have none
	SkateRuns.load_data(runs if runs is Dictionary else {})
	var rem = data.get("remnants", {})                       # saves from before Remnants have none
	Remnants.load_data(rem if rem is Dictionary else {})
	var farm = data.get("farm", {})                          # ...and no garden yet
	Farm.load_data(farm if farm is Dictionary else {})
	var portals = data.get("portals", {})                    # saves from before the time quakes have had none
	Portals.load_data(portals if portals is Dictionary else {})
	Portals.open_seasons()                                     # (a mended world's season is always open)
	Clock.skip_locked_seasons()
	# Saves from before the outfit wheel have no saved outfits
	saved_outfits = SavedOutfits.clean(data.get("saved_outfits", []))
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
		hero = Hero.migrate(hero)          # a hero from before the human kids becomes one (a girl or a boy)
	elif outfits.has("nina") and outfits["hero"].is_empty():
		outfits["hero"] = outfits["nina"]
		outfits.erase("nina")
	home = data.get("home", {}) if data.get("home", {}) is Dictionary else {}
	popper_colour = str(data.get("popper_colour", "classic"))
	hero_ride = str(data.get("hero_ride", "board"))         # saves from before the new rides ride a board
	if not Rides.HERO_RIDES.has(hero_ride) or not (hero_ride == "board" or has_item("ride:" + hero_ride)):
		hero_ride = "board"
	play_time = float(data.get("play_time", 0.0))
	looks = {}
	var all_looks = data.get("looks", {})
	if all_looks is Dictionary:
		for who in all_looks:
			if all_looks[who] is Dictionary:
				looks[str(who)] = {}
				for part in all_looks[who]:
					looks[str(who)][str(part)] = int(all_looks[who][part])
	# Until Nov 7, 2026 the cow girl was called Bramble (that's the plant girl's name now), so her clothes and colours
	# from an older save were filed under "bramble": they're hers, so they move to "clover"
	for d in [outfits, looks]:
		if d.has("bramble") and not d.has("clover"):
			d["clover"] = d["bramble"]
		d.erase("bramble")
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
	if _resume.get("scene", "") == Clock.EARTH and int(data.get("earth_layout", 1)) < EARTH_LAYOUT:
		# Saved outdoors on Earth before the town grew: where she stood might be inside a new shop now, so wake up at home
		_resume = {"scene": Clock.EARTH}
		next_spawn = NEW_GAME_SPAWN
		pending_message = "Welcome back! The town's grown while you were away: Main Street, Maple Lane and a park. Have a look at the map!"


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
	if scene and scene.scene_file_path == TITLE_SCENE:
		return                   # the title screen's Continue takes her there (continue_game())
	if scene and scene.scene_file_path != _resume["scene"]:
		get_tree().change_scene_to_file(_resume["scene"])


func on_title() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == TITLE_SCENE


func continue_game() -> void:
	# From the title screen: back to where the save left off (or home on Earth, for a save with no place in it)
	var to := str(_resume.get("scene", START_SCENE))
	if to == START_SCENE and _resume.is_empty() and next_spawn == "":
		next_spawn = NEW_GAME_SPAWN
	Loading.show_for(to)
	get_tree().call_deferred("change_scene_to_file", to)


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


# -----------------------------------------------------------------------------
# Save slots
# -----------------------------------------------------------------------------
static func slot_path(n: int) -> String:
	return SAVE_PATH if n <= 1 else "user://save_slot%d.json" % n


func save_path() -> String:
	return slot_path(slot)


static func _tool_run() -> bool:
	# Tools and tests run the game with --script: they keep to slot 1 (whose save they put aside and back)
	return "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args()


func _last_slot() -> int:
	if _tool_run():
		return 1
	var cfg := ConfigFile.new()
	if cfg.load(SLOTS_CFG) != OK:
		return 1
	return clampi(int(cfg.get_value("slots", "last", 1)), 1, SLOTS)


func _remember_slot() -> void:
	if _tool_run():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("slots", "last", slot)
	cfg.save(SLOTS_CFG)


func slot_info(n: int) -> Dictionary:
	# What the title screen shows for a slot: {} for an empty one, else the hero's name, girl or boy, level, how long
	# they've played, Earth's day and when it was saved
	var path := slot_path(n)
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	var h: Dictionary = data.get("hero", {}) if data.get("hero", {}) is Dictionary else {}
	if bool(data.get("needs_creator", false)) and str(h.get("name", "")).strip_edges() == "":
		return {}                                    # a new game quit before the hero was made: as good as empty
	return {"name": Hero.display_name(h), "girl": Hero.is_girl(Hero.migrate(h)), "level": int(data.get("level", 1)),
		"play_time": float(data.get("play_time", 0.0)), "day": int(data.get("day", 1)),
		"saved_at": str(data.get("saved_at", ""))}


func use_slot(n: int) -> void:
	# Play the game in slot n: the one being played is saved first, then everything is reset and slot n loaded
	# (an empty slot loads as a fresh start). The title screen's Continue then takes them where it left off.
	n = clampi(n, 1, SLOTS)
	if n == slot:
		return
	slot = n
	_remember_slot()
	_reset_state()
	load_game()


func delete_slot(n: int) -> void:
	DirAccess.remove_absolute(slot_path(n))
	if n == slot:
		_reset_state()
		load_game()


func new_game_in(n: int) -> void:
	# A new game in slot n (whatever was in it is gone)
	slot = clampi(n, 1, SLOTS)
	_remember_slot()
	new_game()


func new_game() -> void:
	DirAccess.remove_absolute(save_path())
	_reset_state()
	hero = Hero.blank()
	Clock.seasons_open = ["autumn"]                  # the other seasons wait in portal worlds (plan item 20)
	needs_creator = true
	next_spawn = NEW_GAME_SPAWN                      # wake up at home
	pending_message = NEW_GAME_MESSAGE
	equipment_changed.emit()
	stats_changed.emit()
	get_tree().call_deferred("change_scene_to_file", START_SCENE)


func _reset_state() -> void:
	# Everything back to how a new game starts (no scene change, nothing saved)
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
	saved_outfits = []
	hero = Hero.blank()
	home = {}
	popper_colour = "classic"
	hero_ride = "board"
	sparkles = 0
	sparkles_taken.clear()
	play_time = 0.0
	Clock.reset()
	Dialogue.reset()
	Quests.reset()
	Requests.reset()
	EarthJobs.reset()
	Festival.reset()
	Arsenal.reset()
	Races.reset()
	SkateRuns.reset()
	Remnants.reset()
	Farm.reset()
	Portals.reset()
	next_spawn = ""
	_resume = {}
	_last_place = {}
	pending_message = ""
	needs_creator = false
