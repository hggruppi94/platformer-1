extends SceneTree

# Checks spring in Stars Hollow (Glenmoor's reward on Earth):
# - nobody on Earth talks about pumpkins, leaves, snow, cocoa or summer things in spring (every conversation that can
#   play in spring is checked), and their spring lines play,
# - the town in spring: no pumpkins or scarecrows, little bunches of tulips where they stood (none floating), the
#   patch's sign says Tulip Field, pastel string lights; and in autumn it's all back as it was,
# - the notice board's spring jobs: planting tulip bulbs round a house (they stay up), rhubarb for Poppy, and nothing
#   that says pumpkins, leaves or snow.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_spring.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.spring_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.spring_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
# Things that don't belong in spring: autumn's, winter's and summer's (the Spring Fair still has a hayride)
const NOT_SPRING := "pumpkin|\\bleaves\\b|autumn|cider|halloween|scarecrow|cobweb|caramel|kettle corn|raking|snow|cocoa|frost|sleigh|winter|gingerbread|mitten|ice fishing|shovel|summer|sunflower|sandcastle|apple|strawberr(y|ies) shortcake"

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
	_finish()


func _to_season(s: String) -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of(s, 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0


# --- What people say ---------------------------------------------------------------------------------------------
func _check_lines() -> void:
	var off := RegEx.create_from_string("(?i)" + NOT_SPRING)
	var bad: Array[String] = []
	var spring_convs := 0
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
				if not "spring" in ss:
					continue
				spring_convs += 1
			if when.has("talks") or str(when.get("quest_step", "")).begins_with("first_night") \
					or str(when.get("quest_not_started", "")) == "first_night" or str(when.get("quest_step", "")).begins_with("first_snow") \
					or when.get("quest_done", "") == "first_snow" or when.has("activity") and str(when.activity) == "winter_lights" \
					or str(when.get("quest_step", "")).begins_with("summer_splash") or when.get("quest_done", "") == "summer_splash":
				continue                                 # (a first hello, the First Night, the First Snow, Summer Splash: never spring)
			for set in (c.get("rotate", []) if c.has("rotate") else [c.get("lines", [])]):
				for l in set:
					var said: String = l.replace("Scarecrow Sam", "Sam").replace("Snow Cone", "Cone") if l is String else ""
					if off.search(said) and not "acorn" in said.to_lower() and not "as long as anyone" in said:
						bad.append("%s: %s" % [id, l])
	check(bad.is_empty(), "nobody on Earth talks about autumn, winter or summer things in spring%s" % ("" if bad.is_empty() else " (%s)" % " | ".join(bad)))
	check(spring_convs >= 33, "there are spring conversations (%d)" % spring_convs)
	_to_season("spring")
	var poppy: Array = dialogue.pick_conversation("poppy")
	check(not " ".join(poppy).to_lower().contains("pumpkin"), "Poppy's lines fit spring")


# --- The town ----------------------------------------------------------------------------------------------------
func _check_town() -> void:
	_to_season("spring")
	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(2)
	var seasons := current_scene.get_node("Seasons")
	check(seasons.season == "spring", "Stars Hollow's in spring")
	var pumpkins: Array = seasons.get("_pumpkins")
	check(pumpkins.size() > 20 and pumpkins.all(func(n: Node3D) -> bool: return not n.visible),
		"no pumpkins or scarecrows round town in spring (%d hidden)" % pumpkins.size())
	var tulips := current_scene.get_node_or_null("Seasons/Spring Tulips")
	check(tulips != null and seasons.shown_tulips >= 8, "bunches of tulips where they were (%d)" % seasons.shown_tulips)
	check(current_scene.get_node_or_null("Seasons/Winter Snowmen") == null and current_scene.get_node_or_null("Seasons/Summer Sunflowers") == null,
		"...and no snowmen or sunflowers")
	var floating := 0
	if tulips:
		for t in tulips.get_children():
			var p := (t as Node3D).global_position
			if absf(p.y - EarthLand.height(p.x, p.z)) > 0.45:
				floating += 1
	check(floating == 0, "...all on the ground")
	var sign := seasons.get("_patch_sign") as Label3D
	check(sign != null and sign.text == "Tulip Field", "the pumpkin patch is the Tulip Field")
	check(seasons.lights_colour(0) == seasons.BULBS_SPRING[0], "the string lights are spring pastels")
	check(seasons.air_kind() == "petals", "petals in the air")
	_to_season("autumn")
	seasons.apply("autumn")
	check(pumpkins.all(func(n: Node3D) -> bool: return n.visible) and current_scene.get_node_or_null("Seasons/Spring Tulips") == null
		and sign.text == "Pumpkin Patch", "in autumn the pumpkins and scarecrows are back")
	await _frames(2)


# --- The notice board ----------------------------------------------------------------------------------------------
func _check_jobs() -> void:
	_to_season("spring")
	var kinds := {}
	for t in ["easy", "medium", "hard"]:
		for k in jobs.kinds_for(t):
			kinds[k] = true
	check(not kinds.has("snowman") and not kinds.has("sandcastle"), "no snowman or sandcastle jobs in spring")
	change_scene_to_file(EARTH)
	await _frames(12)
	var seen := {}
	var off := RegEx.create_from_string("(?i)" + NOT_SPRING)
	var bad: Array[String] = []
	var plant_job: Dictionary = {}
	var rhubarb_job: Dictionary = {}
	for d in 40:
		jobs.roll(hash("spring_test:%d" % d))
		for r in jobs.list:
			seen[str(r.kind)] = true
			var text: String = jobs.text_of(r) + " " + jobs.progress_text(r)
			if off.search(text):
				bad.append(text)
			if str(r.kind) == "rake" and plant_job.is_empty():
				plant_job = r.duplicate(true)
			if str(r.kind) == "bakery" and rhubarb_job.is_empty():
				rhubarb_job = r.duplicate(true)
	check(seen.has("rake") and seen.has("bakery"), "spring has planting and rhubarb jobs")
	check(bad.is_empty(), "no spring job says pumpkins, leaves, snow or summer things%s" % ("" if bad.is_empty() else " (%s)" % bad[0]))
	check(str(jobs.text_of(plant_job)).contains("Plant tulip bulbs"), "raking's planting tulip bulbs in spring")
	check(str(jobs.text_of(rhubarb_job)).contains("rhubarb"), "Poppy wants rhubarb in spring")
	var player := current_scene.find_child("Player", true, false) as Node3D
	jobs.list.clear()
	jobs.list.append(plant_job)
	jobs.rolled_visit = clock.earth_day()
	jobs._place_props()
	await _frames(3)
	var holes := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "bulb")
	check(holes.size() == int(plant_job.goal), "a little hole with a bulb by the house for each one (%d)" % holes.size())
	for b in holes:
		b.call("_on_body", player)
	await _frames(2)
	check(bool(jobs.list[0].done), "planting them all does the job")
	jobs._place_props()
	await _frames(2)
	holes = current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "bulb")
	check(holes.size() == int(plant_job.goal) and holes.all(func(b: Node) -> bool: return b.get("built")), "the tulips stay up")
	jobs.list.clear()
	jobs.list.append(rhubarb_job)
	jobs._place_props()
	await _frames(3)
	var rhubarb := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "rhubarb")
	check(rhubarb.size() == int(rhubarb_job.goal), "rhubarb waits in the Tulip Field (%d)" % rhubarb.size())


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
