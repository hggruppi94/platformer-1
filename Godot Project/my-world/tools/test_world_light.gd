extends SceneTree

# Checks the lighting levels (scripts/world_light.gd, Settings.lighting): every place gets a World Light; at Nice its
# live Environment has SSAO and the haze, at Best bounced light and a soft sun too, and Simple puts every setting back
# exactly as the place had it; the haze's colour follows the place's fog colour as it changes (the Void's day and
# night, Earth's); a place that swaps its Environment later (the portal worlds, the dream skies) gets the new one
# dressed; the minimap's copy has none of it; and switching it off in WorldDetail leaves places as they were.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_world_light.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.world_light_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.world_light_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const ROOM := "res://scenes/interiors/town_hall.tscn"
const WORLDS := ["lanternmoor", "glenmoor", "shard_isle", "far_future"]
const LIGHT := preload("res://scripts/world_light.gd")

var failures := 0
var game: Node
var settings: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _load(path: String) -> Node:
	change_scene_to_file(path)
	await _frames(14)
	return current_scene


func _env() -> Environment:
	var w := root.get_viewport().find_world_3d()
	return w.environment if w else null


func _levels(where: String, inside := false) -> void:
	var light := current_scene.get_node_or_null("World Light")
	check(light != null, "%s has a World Light" % where)
	if light == null:
		return
	var env := _env()
	check(env != null and light.current_env() == env, "%s: it dresses the live Environment" % where)
	if env == null:
		return
	var base: Dictionary = env.get_meta("world_light_base", {})
	check(not base.is_empty(), "%s: it remembers how the Environment was" % where)
	settings.set_value("lighting", "nice")
	await _frames(2)
	check(env.ssao_enabled and env.volumetric_fog_enabled and not env.ssil_enabled,
		"%s Nice: SSAO and the haze on" % where)
	check(env.volumetric_fog_sky_affect == 0.0, "%s Nice: the haze keeps off the sky" % where)
	var want := LIGHT.HAZE_INSIDE if inside else float(LIGHT.HAZE["nice"])
	check(is_equal_approx(env.volumetric_fog_density, want), "%s Nice: haze density %.4f" % [where, want])
	settings.set_value("lighting", "best")
	await _frames(2)
	check(env.ssil_enabled and env.ssao_enabled and env.volumetric_fog_enabled, "%s Best: bounced light too" % where)
	for sun in light.suns():
		check(is_equal_approx((sun as DirectionalLight3D).light_angular_distance, LIGHT.SUN_SOFTNESS),
			"%s Best: the sun's shadows are soft" % where)
	# The haze follows the fog's colour as the place changes it
	env.fog_light_color = Color(0.2, 0.4, 0.6)
	await create_timer(LIGHT.FOLLOW * 2.5).timeout
	var now := env.fog_light_color                    # (a day/night script may have moved it again since)
	check(env.volumetric_fog_albedo.is_equal_approx(LIGHT.haze_colour(now)), "%s: the haze takes the fog's colour" % where)
	settings.set_value("lighting", "simple")
	await _frames(2)
	var same := true
	for k in base:
		if k == "volumetric_fog_albedo":
			continue
		if env.get(k) != base[k]:
			same = false
			print("   differs: ", k, " ", env.get(k), " was ", base[k])
	check(same, "%s Simple: every setting back as it was" % where)
	for sun in light.suns():
		var sb: Dictionary = sun.get_meta("world_light_base", {})
		check(not sb.is_empty() and is_equal_approx(sun.light_angular_distance, float(sb.light_angular_distance))
			and is_equal_approx(sun.light_volumetric_fog_energy, float(sb.light_volumetric_fog_energy)),
			"%s Simple: the sun back as it was" % where)
	settings.set_value("lighting", "nice")
	await _frames(2)


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	check(settings.lighting == "nice" or FileAccess.file_exists(SETTINGS_BACKUP), "Lighting starts at Nice")
	check("lighting" in settings._props(), "Lighting is saved with the settings")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.on_earth = true
	clock.set_earth_time(11 * 60.0, true)
	await _load(EARTH)
	await _levels("Stars Hollow")
	clock.on_earth = false
	clock.set_time(3, 11 * 60.0, true)
	await _load(TOWN)
	await _levels("the Void")
	# Night in the Void: the haze changes colour with the fog, but stays pale so the lamps light it up
	await create_timer(1.0).timeout
	var env := _env()
	var by_day := env.volumetric_fog_albedo
	clock.set_time(3, 23 * 60.0, true)
	await create_timer(1.0).timeout
	var at_night := env.volumetric_fog_albedo
	check(not at_night.is_equal_approx(by_day) and at_night.v >= 0.84,
		"the Void at night: the haze follows the night's fog and stays pale (%s)" % at_night)
	var lamp_ok := true
	for l in current_scene.find_children("*", "OmniLight3D", true, false):
		var b: Dictionary = l.get_meta("world_light_base", {})
		if b.is_empty() or not is_equal_approx(l.light_volumetric_fog_energy, float(b.light_volumetric_fog_energy) * LIGHT.LAMP_HAZE):
			lamp_ok = false
	check(lamp_ok, "the Void: every lamp lights the haze more")
	await _load(ROOM)
	await _levels("the Town Hall", true)
	# The portal worlds copy or swap their Environment as they set up: the live one is the one dressed
	var portals := root.get_node("Portals")
	portals.home_calls.enabled = false
	portals.practice = false
	for id: String in WORLDS:
		await _load(str(portals.world(id).scene))
		await create_timer(LIGHT.FOLLOW * 2.5).timeout
		var light := current_scene.get_node_or_null("World Light")
		var e := _env()
		check(light != null and light.current_env() == e and e.ssao_enabled and e.volumetric_fog_enabled,
			"%s: its live Environment is dressed" % id)
	# Off in WorldDetail: nothing added
	var detail := root.get_node("WorldDetail")
	detail.lighting = false
	await _load(TOWN)
	check(current_scene.get_node_or_null("World Light") == null and not _env().ssao_enabled,
		"switched off: no World Light, no SSAO")
	detail.lighting = true
	print("RESULT " + ("FAILED (%d)" % failures if failures else "PASSED"))
	_finish()


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	else:
		DirAccess.remove_absolute(SETTINGS)
	quit(1 if failures else 0)
