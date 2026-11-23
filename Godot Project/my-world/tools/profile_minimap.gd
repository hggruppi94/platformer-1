extends SceneTree

# How much the minimap costs a frame in every kind of place (a check tool, 23 Nov 2026). For each place it loads it,
# follows lots of quests at once (the worst case: every star searched for), and times the minimap's own work straight:
# TownMap._process, the corner map's drawing and the quest stars. Run it with a window (portal worlds and race circuits
# only get their map picture with one):
#   godot --path "Godot Project/my-world" --script res://tools/profile_minimap.gd [-- <only this scene's name>]
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.minimap_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.minimap_backup.cfg"
const CALLS := 60
const BUDGET_US := 300.0
const TOWN_REFRESH := 0.25    # TownMap.MINI_REFRESH      # more than this a frame and the minimap is worth fixing

const PLACES := [
	["town", "res://scenes/town/town.tscn", Vector3(-72, 0, 63)],
	["town homes", "res://scenes/town/town.tscn", Vector3(80, 0, 20)],
	["earth", "res://scenes/earth/earth.tscn", Vector3(0, 0, 10)],
	["earth main st", "res://scenes/earth/earth.tscn", Vector3(-10, 0, -60)],
	["school", "res://scenes/school/school.tscn", null],
	["shard_isle", "res://scenes/portal_worlds/shard_isle.tscn", null],
	["rootmind", "res://scenes/portal_worlds/rootmind.tscn", null],
	["frozen_moment", "res://scenes/portal_worlds/frozen_moment.tscn", null],
	["lanternmoor", "res://scenes/portal_worlds/lanternmoor.tscn", null],
	["rhythm_springs", "res://scenes/portal_worlds/rhythm_springs.tscn", null],
	["tide_reef", "res://scenes/portal_worlds/tide_reef.tscn", null],
	["glenmoor", "res://scenes/portal_worlds/glenmoor.tscn", null],
	["dark_hollow", "res://scenes/portal_worlds/dark_hollow.tscn", null],
	["far_future", "res://scenes/portal_worlds/far_future.tscn", null],
	["lake_loop", "res://scenes/races/lake_loop.tscn", null],
	["pumpkin_run", "res://scenes/races/pumpkin_run.tscn", null],
	["secret_garden", "res://scenes/secret_garden/secret_garden.tscn", null],
	["gloop_kingdom", "res://scenes/bosses/gloop_kingdom.tscn", null],
	["arena", "res://scenes/bosses/arena.tscn", null],
	["skyreach_trail", "res://scenes/bosses/skyreach_trail.tscn", null],
	["scary_world", "res://scenes/scary_world/scary_world.tscn", null],
]

var _draw_us := 0.0
var _draws := 0
var _draw_list := []
var _rows := []


func _initialize() -> void:
	create_timer(2400.0, true, false, true).timeout.connect(func() -> void:
		print("TIMED OUT")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.minimap = true
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	var quests := root.get_node("Quests")
	# The worst case: a dozen quests on and followed, each on its first step
	var ids := ["slide_mystery", "emergency_prep", "dog_rights", "rex_lab", "brambles_harvest", "undergardens",
		"aquarium", "bike_boy", "meet_friends", "pumpkin_night", "summer_splash", "duckling_day"]
	for id in ids:
		if quests._data.has(id):
			quests.state[id] = {"step": 0, "since_day": 1, "since_at": 0.0, "done": false}
			quests.follow(id, true)
	print("following: ", quests.live_followed())
	var tm := root.get_node("TownMap")
	tm._mini_overlay.draw.disconnect(tm._draw_mini)
	tm._mini_overlay.draw.connect(func() -> void:
		# Each part 20 times over in one go, like the other timings: a single pass is too short to time on a busy machine
		var t0 := Time.get_ticks_usec()
		for k in 20:
			_split_draw(tm)
		var took := (Time.get_ticks_usec() - t0) / 20.0
		_draw_us += took
		_draw_list.append(took)
		_draws += 1)
	var only := OS.get_cmdline_user_args()
	for place in PLACES:
		if not only.is_empty() and not place[0] in only:
			continue
		if not ResourceLoader.exists(place[1]):
			print("missing ", place[1])
			continue
		clock.on_earth = place[1].contains("/earth/")
		clock.set_time(3, 11 * 60.0, true)
		change_scene_to_file(place[1])
		for i in 10:
			await process_frame
		await create_timer(3.0).timeout
		var player := current_scene.find_child("Player", true, false) as Node3D if current_scene else null
		if player and place[2] != null:
			var spot: Vector3 = place[2]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 60, spot + Vector3.DOWN * 20))
			player.global_position = (hit.position + Vector3.UP * 0.2) if hit else spot
		game.hold_controls(&"profile", true)
		# Wait for the map picture (portal worlds, circuits), then time
		var t := Time.get_ticks_msec()
		while tm.snap_scene() and not tm.has_snap() and Time.get_ticks_msec() - t < 8000:
			await process_frame
		await _frames(10)
		await _row(place[0], tm)
	print("--- minimap per frame, microseconds (process + corner map drawing) ---")
	var worst := 0.0
	for r in _rows:
		# The stars and people lists are worked out again every MINI_REFRESH, so a frame's share of that is added on
		var total: float = r[1] + r[2] + (r[3] + r[4]) / (60.0 * TOWN_REFRESH)
		r.append(total)
		worst = maxf(worst, total)
		print("  %-16s process %7.1f  draw %7.1f  stars %7.1f  people %6.1f  shown %s  stars on map %d  areas %d%s" % [
			r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], "   (%.0f a frame)%s" % [r[8], "  <-- over budget" if r[8] > BUDGET_US else ""]])
	print("WORST %.1f us a frame (budget %.0f)" % [worst, BUDGET_US])
	_finish()


func _row(name: String, tm: Node) -> void:
	var t0 := Time.get_ticks_usec()
	for i in CALLS:
		tm._process(1.0 / 60.0)
	var proc := (Time.get_ticks_usec() - t0) / float(CALLS)
	_draw_us = 0.0
	_draws = 0
	_draw_list.clear()
	await _frames(CALLS)
	_draw_list.sort()
	var draw: float = _draw_list[_draw_list.size() / 2] if not _draw_list.is_empty() else 0.0   # the median, so one stall doesn't count
	print("  %s [%s] slowest draw %.0f" % [name, current_scene.scene_file_path if current_scene else "?", _draw_list.back() if not _draw_list.is_empty() else 0.0])
	t0 = Time.get_ticks_usec()
	var n := 0
	for i in 20:
		n = tm.quest_markers().size()
	var stars := (Time.get_ticks_usec() - t0) / 20.0
	t0 = Time.get_ticks_usec()
	for i in 20:
		tm.people()
	var people := (Time.get_ticks_usec() - t0) / 20.0
	var areas := current_scene.find_children("*", "Area3D", true, false).size() if current_scene else 0
	_rows.append([name, proc, draw, stars, people, tm._mini_layer.visible, n, areas])
	print("%s: process %.1f us, draw %.1f us (%d draws), stars %.1f us (%d), mini shown %s" % [
		name, proc, draw, _draws, stars, n, tm._mini_layer.visible])


func _split_draw(tm: Node) -> void:
	# TownMap's own corner map drawing (its quest stars and people are worked out again every MINI_REFRESH, which the
	# summary adds on as a share of each frame)
	tm._draw_mini()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	var game := root.get_node_or_null("Game")
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit()
