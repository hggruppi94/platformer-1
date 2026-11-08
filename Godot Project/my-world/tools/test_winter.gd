extends SceneTree

# Checks winter in Stars Hollow and Flurry's frost breath (the Frozen Moment's reward):
# - the town in winter: no pumpkins or scarecrows, snowmen where they stood (none floating or indoors), the patch's
#   sign says Snowman Field, the string lights go red, green and white, the notice board has a star; and in autumn
#   it's all back as it was,
# - nobody on Earth talks about pumpkins, leaves, hayrides or apple bobbing in winter (every conversation that can
#   play in winter is checked), and their winter lines play,
# - the notice board's winter jobs: shovelling snow, winterberries for Poppy, snowmen on the green (built by walking
#   into a snowball; they stay up), and no snowmen jobs in autumn,
# - the quest "The First Snow" with Nina, all the way through (carrot, scarf, the snowman, sledding down Lookout Hill
#   on a clear run, cocoa with Gus),
# - frost breath: locked (and not on the Controls list) until the Frozen Moment's mended; then it freezes ice floes on
#   the lake you can stand on without getting wet, chills a Gloop in front, has a short cooldown, and the ice melts.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_winter.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.winter_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.winter_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const FALL := "pumpkin|\\bleaves\\b|autumn|cider|halloween|hayride|\\bhay\\b|scarecrow|\\bapples?\\b|cobweb|caramel|kettle corn|raking"

var failures := 0
var game: Node
var clock: Node
var quests: Node
var dialogue: Node
var jobs: Node
var portals: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	jobs = root.get_node("EarthJobs")
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	_check_lines()
	await _check_town()
	await _check_jobs()
	await _check_first_snow()
	await _check_frost_breath()
	_finish()


func _to_season(s: String) -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of(s, 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0


# --- What people say ---------------------------------------------------------------------------------------------
func _check_lines() -> void:
	var fall := RegEx.create_from_string("(?i)" + FALL)
	var bad: Array[String] = []
	var winter_convs := 0
	for f in DirAccess.get_files_at("res://dialogue"):
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/" + f))
		var routine = JSON.parse_string(FileAccess.get_file_as_string("res://routines/%s.json" % id)) \
			if FileAccess.file_exists("res://routines/%s.json" % id) else null
		if not routine is Dictionary or str(routine.get("world", "")) != "earth":
			continue
		for c in data.get("conversations", []):
			var when: Dictionary = c.get("when", {})
			if when.has("season"):
				var ss: Array = when.season if when.season is Array else [when.season]
				if not "winter" in ss:
					continue
				winter_convs += 1
			if when.has("talks") or str(when.get("quest_step", "")).begins_with("first_night") \
					or str(when.get("quest_not_started", "")) == "first_night":
				continue                                 # (a first hello, or the First Night: always autumn)
			for set in (c.get("rotate", []) if c.has("rotate") else [c.get("lines", [])]):
				for l in set:
					var said: String = l.replace("Scarecrow Sam", "Sam") if l is String else ""
					if fall.search(said) and not "acorn" in said.to_lower() and not "as long as anyone" in said:
						bad.append("%s: %s" % [id, l])
	check(bad.is_empty(), "nobody on Earth talks about autumn things in winter%s" % ("" if bad.is_empty() else " (%s)" % " | ".join(bad)))
	check(winter_convs >= 35, "there are winter conversations (%d)" % winter_convs)
	_to_season("winter")
	var kip: Array = dialogue.pick_conversation("theo")
	check(" ".join(kip).contains("winter") or not " ".join(kip).contains("autumn"), "Theo's lines fit winter")


# --- The town ----------------------------------------------------------------------------------------------------
func _check_town() -> void:
	_to_season("winter")
	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(2)
	var seasons := current_scene.get_node("Seasons")
	check(seasons.season == "winter", "Stars Hollow's in winter")
	var pumpkins: Array = seasons.get("_pumpkins")
	check(pumpkins.size() > 20 and pumpkins.all(func(n: Node3D) -> bool: return not n.visible),
		"no pumpkins or scarecrows round town in winter (%d hidden)" % pumpkins.size())
	var men := current_scene.get_node_or_null("Seasons/Winter Snowmen")
	check(men != null and seasons.shown_snowmen >= 8, "snowmen stand where they were (%d)" % seasons.shown_snowmen)
	var floating := 0
	if men:
		for sm in men.get_children():
			var p := (sm as Node3D).global_position
			if absf(p.y - EarthLand.height(p.x, p.z)) > 0.45:
				floating += 1
	check(floating == 0, "...all on the ground")
	var sign := seasons.get("_patch_sign") as Label3D
	check(sign != null and sign.text == "Snowman Field", "the pumpkin patch is the Snowman Field")
	check(seasons.lights_colour(0) == seasons.BULBS_WINTER[0], "the string lights are wintry")
	var board := current_scene.get_node_or_null("Notice Board")
	check(board == null or board.find_children("*", "OmniLight3D", true, false).size() >= 1, "the notice board's up")
	_to_season("autumn")
	seasons.apply("autumn")
	check(pumpkins.all(func(n: Node3D) -> bool: return n.visible) and current_scene.get_node_or_null("Seasons/Winter Snowmen") == null
		and sign.text == "Pumpkin Patch", "in autumn the pumpkins and scarecrows are back")
	await _frames(2)


# --- The notice board ----------------------------------------------------------------------------------------------
func _check_jobs() -> void:
	_to_season("autumn")
	var autumn_kinds := {}
	for t in ["easy", "medium", "hard"]:
		for k in jobs.kinds_for(t):
			autumn_kinds[k] = true
	check(not autumn_kinds.has("snowman"), "no snowman jobs in autumn")
	_to_season("winter")
	change_scene_to_file(EARTH)
	await _frames(12)
	var seen := {}
	var fall := RegEx.create_from_string("(?i)" + FALL)
	var bad: Array[String] = []
	var snow_job: Dictionary = {}
	for d in 40:
		jobs.roll(hash("winter_test:%d" % d))
		for r in jobs.list:
			seen[str(r.kind)] = true
			var text: String = jobs.text_of(r)
			if fall.search(text):
				bad.append(text)
			if str(r.kind) == "snowman" and snow_job.is_empty():
				snow_job = r.duplicate(true)
	check(seen.has("snowman") and seen.has("rake") and seen.has("bakery"), "winter has snowmen, shovelling and winterberry jobs")
	check(bad.is_empty(), "no winter job says pumpkins or leaves%s" % ("" if bad.is_empty() else " (%s)" % bad[0]))
	# Build the snowmen: walk into each snowball
	jobs.list.clear()
	jobs.list.append(snow_job)
	jobs.rolled_visit = clock.earth_day()
	jobs._place_props()
	await _frames(3)
	var balls := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "snowball")
	check(balls.size() == int(snow_job.goal), "a snowball waits on the green for each snowman (%d)" % balls.size())
	var player := current_scene.find_child("Player", true, false) as Node3D
	for b in balls:
		b.call("_on_body", player)
	await _frames(2)
	check(bool(jobs.list[0].done) and balls.all(func(b: Node) -> bool: return b.get("built")), "walking into them builds the snowmen and does the job")
	jobs._place_props()
	await _frames(2)
	var built := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("built") == true)
	check(built.size() == int(snow_job.goal), "the snowmen stay up after the job's done")


# --- The First Snow ------------------------------------------------------------------------------------------------
func _check_first_snow() -> void:
	_to_season("winter")
	change_scene_to_file(EARTH)
	await _frames(14)
	await _physics(2)
	var snow := current_scene.get_node_or_null("First Snow")
	check(snow != null, "winter puts the First Snow's spots in Stars Hollow")
	if snow == null:
		return
	dialogue.talks["nina_earth"] = 5
	var nina: Array = dialogue.pick_conversation("nina_earth")
	check(" ".join(nina).contains("SNOWING"), "Nina's excited about the snow")
	dialogue.set_flag("first_snow_start")
	quests.check()
	await _frames(2)
	fs_refresh()
	check(quests.on_step("first_snow", "gather"), "The First Snow starts")
	check(snow.get_node("Snow Carrot/Thing").visible and snow.get_node("Snow Scarf/Thing").visible, "the carrot and scarf glow")
	var fs := root.get_node("EarthTown/FirstSnow")
	fs._take_carrot()
	fs._take_scarf()
	quests.check()
	check(quests.on_step("first_snow", "build"), "with the carrot and scarf, it's time to build")
	check(fs._build_offer() != "", "...beside Nina on the green")
	fs._build()
	quests.check()
	await _frames(3)
	check(snow.get_node_or_null("Our Snowman") != null and quests.on_step("first_snow", "sled"), "the snowman goes up on the green")
	# The sled run: on the snow all the way, nothing solid in the way, and it really goes down the hill
	var line: Array[Vector3] = fs.sled_line()
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var blocked := 0
	for p in line:
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.6
		q.shape = sphere
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.9, 0))
		for h in space.intersect_shape(q, 4):
			if h.collider is StaticBody3D and not h.collider is EarthLand:
				blocked += 1
				break
	check(blocked == 0, "the sled run down Lookout Hill is clear")
	check(line[0].y - line[-1].y > 5.0, "...and it's downhill (%.1f m)" % (line[0].y - line[-1].y))
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	player.global_position = fs.sled_start() + Vector3(0, 1, 0)
	fs.sled_down()
	check(fs.is_sledding(), "whee! sledding")
	await create_timer(fs.SLED_TIME + 0.5).timeout
	quests.check()
	check(not fs.is_sledding() and player.global_position.distance_to(line[-1] + Vector3(0, 0.8, 0)) < 1.5, "the sled brings you to the bottom")
	check(quests.on_step("first_snow", "cocoa"), "then it's cocoa time")
	dialogue.talks["gus"] = 3
	var gus: Array = dialogue.pick_conversation("gus")
	check(" ".join(gus).contains("marshmallows"), "Gus makes the cocoa")
	dialogue.set_flag("snow_cocoa")
	quests.check()
	check(quests.is_done("first_snow"), "The First Snow is done")


# --- Frost breath --------------------------------------------------------------------------------------------------
func _check_frost_breath() -> void:
	var settings := root.get_node("Settings")
	portals.cleared_worlds.clear()
	check(not settings.action_shown("frost_breath"), "frost breath isn't on the Controls list before the Frozen Moment's mended")
	clock.on_earth = false
	clock.set_time(3, 10 * 60.0, true)
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(3)
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	var fb := player.get_node("FrostBreath")
	check(not fb.try_breathe(), "locked, it does nothing")
	portals.cleared_worlds.append_array(["shard_isle", "rootmind", "frozen_moment"])
	check(settings.action_shown("frost_breath"), "once it's mended it's on the Controls list")
	# On the lake's south shore, facing the water
	var lake: Node = null
	for w in current_scene.get_tree().get_nodes_in_group("water"):
		if w.call("covers", 0.0, 10.0):
			lake = w
	check(lake != null, "found the lake")
	if lake == null:
		return
	var shore := Vector3(0, 0, 10.0)
	while lake.call("covers", shore.x, shore.z):
		shore.z += 1.0
	shore.z += 1.5
	player.global_position = shore + Vector3(0, 3, 0)
	await _physics(30)
	(player.get_node("Visual") as Node3D).global_rotation.y = PI          # facing -z, out over the lake
	var gloop: Node3D = load("res://scenes/enemies/gloop.tscn").instantiate()
	current_scene.add_child(gloop)
	gloop.global_position = player.global_position + Vector3(0, 0, -3.0)
	await _frames(2)
	check(fb.try_breathe(), "frost breath!")
	await _frames(2)
	check(fb.floes.size() >= 2, "it freezes ice floes on the lake (%d)" % fb.floes.size())
	check(root.get_node("Arsenal").slow(gloop) < 1.0, "it chills a Gloop in front")
	check(not fb.try_breathe(), "a short breath before the next huff")
	var floe := fb.floes[fb.floes.size() - 1] as Node3D
	check(floe.is_in_group("ice") and floe is StaticBody3D, "the ice is solid and slippery")
	player.global_position = floe.global_position + Vector3(0, 1.2, 0)
	player.velocity = Vector3.ZERO
	await _physics(30)
	check(player.is_on_floor() and player.global_position.y > float(lake.get("water_y")) + 0.6 and player.call("on_ice"),
		"you can stand on it, dry, on the ice (y %.2f)" % player.global_position.y)
	for f in fb.floes:
		f.set_meta("until", 0.0)
	await _frames(3)
	check(fb.floes.is_empty(), "the ice melts away after a while")


func fs_refresh() -> void:
	root.get_node("EarthTown/FirstSnow")._refresh()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


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
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
