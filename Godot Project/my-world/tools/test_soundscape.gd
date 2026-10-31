extends SceneTree

# Checks the soundscape (scripts/soundscape.gd, plan prompt F3): every area and time picks its own music and that
# track is in the project; a race, the Gloop King and the festival take over; a music zone wins indoors (the barn's
# dance class gets its own track); only one song is ever playing once a crossfade's done, and no ambience loop plays
# twice; ambience fits the place (birds by day, wind at night, water by the creek and lake, the market's murmur);
# the music ducks under dialogue and comes back to the player's own level; people talk in blips pitched their own
# way (Rook barks, the Green Man hums) on a Voices bus with its own slider; and every music and ambience file is small
# and listed in audio/CREDITS.md.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_soundscape.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.soundscape_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"
const SONGS := ["earth_day", "earth_night", "town_day", "town_night", "skate_park", "race", "gloop_king", "scary_world",
	"festival", "barn_dance"]
const AMBIENCE := ["birds", "wind", "water", "mothership_hum", "alien_chirps", "market"]

var failures := 0
var S: Node
var audio: Node
var clock: Node
var game: Node
var player: Node3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	S = root.get_node("Soundscape")
	audio = root.get_node("Audio")
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	game._resume = {}
	game.riding = false
	game.pending_message = ""
	clock.pulls_home = false

	# --- The files ---
	var credits := FileAccess.get_file_as_string("res://audio/CREDITS.md")
	for t in SONGS:
		var path: String = audio.music_path(t)
		check(path == "res://audio/music/%s.ogg" % t, "music: %s is in the project" % t)
		check(credits.contains("%s.ogg" % t), "...and in audio/CREDITS.md")
		if path != "":
			check(_size(path) < 400_000, "...and small (%d KB)" % (_size(path) / 1024))
	for a in AMBIENCE:
		var path := "res://audio/ambience/%s.ogg" % a
		check(ResourceLoader.exists(path) and credits.contains("`%s`" % a), "ambience: %s is in the project and the credits" % a)
	check(audio.music_path("no_such_song") == "", "a track that isn't there is just not found")

	# --- Earth ---
	clock.day = 1                                             # a Friday: no festival
	clock.set_earth_time(12 * 60.0, true)
	await _go(EARTH)
	player.global_position = Vector3(0, 1, 16)
	await _settle()
	check(S.pick_track() == "earth_day", "Stars Hollow at noon: earth_day (%s)" % S.pick_track())
	check(audio.current_track() == "earth_day", "...and it's what's playing")
	check("birds" in S.pick_ambience() and not "wind" in S.pick_ambience(), "...with birds (%s)" % [S.pick_ambience()])
	clock.set_earth_time(22 * 60.0, true)
	await _settle()
	check(audio.current_track() == "earth_night", "at 10 PM: earth_night (%s)" % audio.current_track())
	check("wind" in S.pick_ambience() and not "birds" in S.pick_ambience(), "...and the wind, no birds")
	player.global_position = Vector3(30, 1, -100)              # the Hollow Skate Yard
	await _settle()
	check(audio.current_track() == "skate_park", "the Hollow Skate Yard: skate_park (%s)" % audio.current_track())
	var creek: Vector2 = EarthLand.CREEK[2]
	player.global_position = Vector3(creek.x + 6.0, 1, creek.y)
	await _settle()
	check("water" in S.pick_ambience(), "by Whisper Creek you hear water (%s)" % [S.pick_ambience()])
	# The festival (a Saturday evening, on the green)
	clock.day = 2
	clock.set_earth_time(18 * 60.0, true)
	player.global_position = Vector3(0, 1, 16)
	await _settle()
	check(root.get_node("Festival").is_on() and audio.current_track() == "festival",
		"the Autumn Festival on the green: festival (%s)" % audio.current_track())
	clock.day = 1
	clock.set_earth_time(12 * 60.0, true)
	await _settle()
	# Indoors: the barn's dance class
	var studio := current_scene.find_child("StudioMusic", true, false)
	check(studio != null and str(studio.get("track")) == "barn_dance", "the barn studio's music zone plays barn_dance")
	audio.push_zone("barn_dance")
	await _settle()
	check(audio.current_track() == "barn_dance", "...inside, the dance class (%s)" % audio.current_track())
	check(S.pick_ambience().is_empty(), "...and no birds indoors")
	audio.pop_zone("barn_dance")
	await _settle()
	check(audio.current_track() == "earth_day", "...and back to earth_day outside (%s)" % audio.current_track())

	# --- Only one song at a time, and nothing twice ---
	for t in ["earth_night", "festival", "earth_day", "race", "earth_day"]:
		audio.music(t)
		await _wait(0.3)
	await _wait(audio.FADE + 0.6)
	var loud := 0
	for p in [audio._music_a, audio._music_b]:
		if p.stream and p.volume_db > -30.0:      # (with no sound card, "playing" can't be trusted: go by the fades)
			loud += 1
	check(loud == 1, "after quick changes, only one song is playing (%d)" % loud)
	var names := []
	var dup := false
	for c in S.get_children():
		if c is AudioStreamPlayer and c.stream and c != S._voice:
			var n := str(c.name)
			dup = dup or n in names
			names.append(n)
	check(not dup, "no ambience loop plays twice (%s)" % [names])

	# --- Ducking under dialogue ---
	var dialogue := root.get_node("Dialogue")
	var bus := AudioServer.get_bus_index("Music")
	var base := AudioServer.get_bus_volume_db(bus)
	var talker := Node3D.new()
	var gd := GDScript.new()
	gd.source_code = "extends Node3D\nfunc begin_talk() -> void:\n\tpass\nfunc end_talk() -> void:\n\tpass\n"
	gd.reload()
	talker.set_script(gd)
	current_scene.add_child(talker)
	dialogue.say(talker, "Nina", ["Hello! This is a test line, long enough for a few blips.", "And another."], "nina")
	await _frames(3)
	var blips: int = S.blips_left()
	await _wait(0.7)
	check(dialogue.is_active() and AudioServer.get_bus_volume_db(bus) < base - 6.0,
		"the music ducks while someone's talking (%.1f dB under)" % (base - AudioServer.get_bus_volume_db(bus)))
	check(blips > 0, "...and they talk in little blips (%d for that line)" % blips)
	dialogue.end()
	await _wait(0.8)
	check(absf(AudioServer.get_bus_volume_db(bus) - base) < 0.5, "...and comes back to your own Music volume after (%.1f / %.1f, ducked %.1f, talking %s)" % [
		AudioServer.get_bus_volume_db(bus), base, audio.ducked_by(), dialogue.is_active()])
	root.get_node("Settings").music_volume = 0.5
	root.get_node("Settings").apply()
	check(absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.5, "the Music slider still works")
	root.get_node("Settings").music_volume = 0.8
	root.get_node("Settings").apply()

	# --- Voices ---
	check(AudioServer.get_bus_index("Voices") != -1, "there's a Voices bus")
	check(S.voice_of("rook", "Rook")[1] == "bark", "Rook barks")
	check(S.voice_of("green_man", "The Green Man")[1] == "hum", "the Green Man hums")
	check(S.voice_of("dash", "Dash")[0] > S.voice_of("mr_palmer", "Mr. Palmer")[0], "Dash talks higher than Mr. Palmer")
	check(S.voice_of("someone_new", "Zed")[0] == S.voice_of("someone_new", "Zed")[0], "anyone else gets a voice of their own, the same every time")
	var settings := root.get_node("Settings")
	check("voice_volume" in settings._props(), "Voices volume is a saved setting")
	var tabs := TabContainer.new()
	root.add_child(tabs)
	root.get_node("PauseMenu")._tab_audio(tabs)
	var labels := tabs.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("Voices volume" in labels and "Music volume" in labels and "Sound effects volume" in labels,
		"Settings > Audio has Music, Effects and Voices sliders")
	tabs.queue_free()

	# --- Galaxity ---
	clock.set_earth_time(0.5 * 60.0, true)                   # in the Shift
	clock.set_time(clock.day, 10 * 60.0, true)
	await _go(TOWN)
	player.global_position = Vector3(-30, 3, 70)
	await _settle()
	check(audio.current_track() == "town_day", "Galaxity by day: town_day (%s)" % audio.current_track())
	check("alien_chirps" in S.pick_ambience(), "...with the little aliens chirping (%s)" % [S.pick_ambience()])
	player.global_position = Vector3(-72, 2, 42)
	await _settle()
	check("market" in S.pick_ambience(), "the Market Square murmurs")
	player.global_position = Vector3(50, 2, 58)
	await _settle()
	check(audio.current_track() == "skate_park", "the Skate Park: skate_park (%s)" % audio.current_track())
	var races := root.get_node("Races")
	var started: bool = races.start("lake_loop")
	await _settle()
	check(started and audio.current_track() == "race", "a race: race (%s)" % audio.current_track())
	races._end(false)
	await _frames(3)
	var king := current_scene.find_child("The Gloop King", true, false) as Node3D
	check(king != null, "the Gloop King is in town")
	if king:
		player.global_position = king.global_position + Vector3(6, 1, 0)
		king.set("_was_chasing", true)
		await _settle()
		check(audio.current_track() == "gloop_king", "the Gloop King after you: gloop_king (%s)" % audio.current_track())
		king.set("_was_chasing", false)
	clock.set_time(clock.day, 23 * 60.0, true)
	player.global_position = Vector3(-30, 3, 70)
	await _settle()
	check(audio.current_track() == "town_night", "Galaxity at night: town_night (%s)" % audio.current_track())

	# --- The Scary World ---
	await _go(SCARY)
	await _settle()
	check(audio.current_track() == "scary_world", "the Scary World: scary_world (%s)" % audio.current_track())

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 10:
		await process_frame
	player = current_scene.find_child("Player", true, false) as Node3D


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle() -> void:
	# The Soundscape looks twice a second
	await _wait(S.CHECK_EVERY + 0.15)


func _wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else 0


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
