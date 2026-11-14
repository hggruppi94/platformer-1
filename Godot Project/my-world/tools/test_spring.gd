extends SceneTree

# Checks spring in Stars Hollow (Glenmoor's reward on Earth):
# - nobody on Earth talks about pumpkins, leaves, snow, cocoa or summer things in spring (every conversation that can
#   play in spring is checked), and their spring lines play,
# - the town in spring: no pumpkins or scarecrows, little bunches of tulips where they stood (none floating), the
#   patch's sign says Tulip Field, pastel string lights, no mist over the pond; and in autumn it's all back as it was,
# - the notice board's spring jobs: planting tulip bulbs round a house (they stay up), rhubarb for Poppy, and nothing
#   that says pumpkins, leaves or snow,
# - the sun: higher and brighter than in autumn, with longer days,
# - the quest "Duckling Day" with Nina, all the way through: five lost ducklings on dry, open ground, each one following
#   you in a line once found, leading them home to Mother Duck (then the family swims round Willow Pond), splashing in
#   three puddles on the green (landing in one splashes), and honey buns with Poppy.
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
	await _check_sun()
	await _check_ducklings()
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
	var mist: Array = seasons.get("_mist")
	check(mist.size() > 0 and mist.all(func(m: Node3D) -> bool: return not m.visible), "no Halloween mist over Willow Pond")
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
	check(str(jobs.text_of(plant_job)).contains("Plant bulbs"), "raking's planting tulip bulbs in spring")
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


# --- The sun ------------------------------------------------------------------------------------------------------
func _check_sun() -> void:
	_to_season("spring")
	change_scene_to_file(EARTH)
	await _frames(12)
	var sun := current_scene.find_children("*", "DirectionalLight3D", true, false)[0] as DirectionalLight3D
	await _frames(3)
	var spring_high := -sun.rotation_degrees.x
	var spring_energy := sun.light_energy
	clock.earth_minutes = 19 * 60.0
	await _frames(3)
	var spring_evening := sun.light_energy
	_to_season("autumn")
	await _frames(3)
	var autumn_high := -sun.rotation_degrees.x
	var autumn_energy := sun.light_energy
	clock.earth_minutes = 19 * 60.0
	await _frames(3)
	var autumn_evening := sun.light_energy
	check(spring_high > autumn_high + 5.0 and spring_energy > autumn_energy,
		"the spring sun's higher and brighter than autumn's (%.0f vs %.0f degrees)" % [spring_high, autumn_high])
	check(spring_evening > autumn_evening + 0.1, "and spring evenings stay light longer (at 7 PM %.2f vs %.2f)" % [spring_evening, autumn_evening])


# --- Duckling Day -------------------------------------------------------------------------------------------------
func _check_ducklings() -> void:
	_to_season("spring")
	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(2)
	var dd := root.get_node("EarthTown/DucklingDay")
	var g := current_scene.get_node_or_null("Duckling Day")
	check(g != null and g.get_node_or_null("Mother Duck") != null and g.get_node_or_null("Puddle 3") != null,
		"spring puts Mother Duck, her ducklings and puddles in Stars Hollow")
	if g == null:
		return
	var space: PhysicsDirectSpaceState3D = (current_scene as Node3D).get_world_3d().direct_space_state
	var bad: Array[String] = []
	var spots: Array = []
	for i in dd.DUCKLINGS:
		spots.append(["duckling %d" % (i + 1), dd.lost_spot(i), 0.4])
	for i in dd.PUDDLES.size():
		var p: Vector3 = dd.PUDDLES[i]
		spots.append(["puddle %d" % (i + 1), dd.ground(Vector2(p.x, p.z)), dd.PUDDLE_R])
	spots.append(["Mother Duck", dd.ground(dd.MOTHER_AT), 0.6])
	for sp in spots:
		var at: Vector3 = sp[1]
		var r: float = sp[2]
		if EarthLand.is_water(at.x, at.z):
			bad.append("%s is in the water" % sp[0])
		# Nothing solid there (a wall, a bench, a building) from ankle height up to a kid's head
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = 1.4
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, 0.95, 0))
		var hits: Array = space.intersect_shape(q, 4).filter(func(h: Dictionary) -> bool:
			return not (h.collider is Area3D) and not h.collider.is_in_group("player"))
		if not hits.is_empty():
			bad.append("%s is in %s" % [sp[0], (hits[0].collider as Node).name])
		# ...and nothing over it (indoors or under a roof)
		var up := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, 30, 0))
		var roof: Dictionary = space.intersect_ray(up)
		if roof and not (roof.collider is Area3D):
			bad.append("%s is under %s" % [sp[0], (roof.collider as Node).name])
	check(bad.is_empty(), "the ducklings, the puddles and Mother Duck are all outdoors on dry, open ground%s" % ("" if bad.is_empty() else " (%s)" % ", ".join(bad)))
	var mother_pond := Vector2(dd.MOTHER_AT.x - EarthLand.POND.x, dd.MOTHER_AT.y - EarthLand.POND.y)
	check(EarthLand.pond_e(dd.MOTHER_AT.x, dd.MOTHER_AT.y) < 1.3, "Mother Duck waits right by Willow Pond (%.1f m from its middle)" % mother_pond.length())
	var swim_dry := 0
	for k in 24:
		var a := TAU * k / 24.0
		if not EarthLand.is_water(dd.SWIM.x + cos(a) * dd.SWIM.z, dd.SWIM.y + sin(a) * dd.SWIM.w):
			swim_dry += 1
	check(swim_dry == 0, "the family's swim goes all the way round in the water")
	check(not g.get_node("Duckling 1").visible, "the ducklings hide till the quest starts")
	# Nina starts it
	var line: Array = dialogue.pick_conversation("nina_earth")
	check(" ".join(line).contains("ducklings"), "Nina tells you about the lost ducklings in spring")
	dialogue.set_flag("duckling_day_start")
	quests.check()
	await _frames(3)
	check(quests.on_step("duckling_day", "find"), "Duckling Day starts")
	check(g.get_node("Duckling 1").visible and g.get_node("Duckling 5").visible, "the lost ducklings are out")
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	# Walk up to each one: it falls in behind you
	for i in dd.DUCKLINGS:
		player.global_position = dd.lost_spot(i) + Vector3(0.6, 0.85, 0.3)
		player.velocity = Vector3.ZERO
		await _physics(4)
		await _frames(20)
		check(dd.found(i), "walking up to duckling %d picks it up%s" % [i + 1, "" if dd.found(i) else " (stood at %s, it's at %s)" % [player.global_position, dd.lost_spot(i)]])
	quests.check()
	await _frames(2)
	check(quests.on_step("duckling_day", "home"), "with all five, it's time to take them home")
	# Walk a little way: they follow in a line behind you
	var start := Vector3(-30.0, 0, 14.0)
	player.global_position = dd.ground(Vector2(start.x, start.z)) + Vector3(0, 0.85, 0)
	await _physics(3)
	for k in 30:
		player.global_position += Vector3(-0.2, 0, 0)
		await _frames(1)
	var feet := player.global_position - Vector3(0, 0.85, 0)
	var ok_line := true
	var last := 0.0
	for i in dd.DUCKLINGS:
		var d := g.get_node("Duckling %d" % (i + 1)) as Node3D
		var dist := Vector2(d.global_position.x - feet.x, d.global_position.z - feet.z).length()
		if dist < last or dist > 5.0 or d.global_position.x < feet.x:
			ok_line = false
		last = dist
	check(ok_line, "the ducklings follow in a line behind you")
	player.global_position = dd.ground(dd.MOTHER_AT + Vector2(2.0, 0.5)) + Vector3(0, 0.85, 0)
	await _physics(3)
	await _frames(20)
	check(dd.home(), "leading them to Mother Duck brings them home")
	quests.check()
	await _frames(30)
	check(quests.on_step("duckling_day", "puddles"), "then it's puddle time")
	var m := (g.get_node("Mother Duck") as Node3D).global_position
	var d1 := (g.get_node("Duckling 1") as Node3D).global_position
	check(EarthLand.is_water(m.x, m.z) and EarthLand.is_water(d1.x, d1.z) and absf(d1.y - EarthLand.WATER_Y) < 0.3,
		"the family's swimming on Willow Pond")
	# Jump into each puddle: a splash
	for i in dd.PUDDLES.size():
		var p: Vector3 = dd.PUDDLES[i]
		player.global_position = dd.ground(Vector2(p.x, p.z)) + Vector3(0, 2.5, 0)
		player.velocity = Vector3.ZERO
		await _physics(3)                        # (is_on_floor() still says where she was till she's moved)
		for k in 90:
			await physics_frame
			if player.is_on_floor():
				break
		await _frames(3)
		check(dialogue.flags.has("puddle_%d" % (i + 1)), "landing in puddle %d splashes it%s" % [i + 1, "" if dialogue.flags.has("puddle_%d" % (i + 1)) else " (landed at %s, floor %s, splashes %d)" % [player.global_position, player.is_on_floor(), dd.splashes]])
	quests.check()
	await _frames(2)
	check(quests.on_step("duckling_day", "buns"), "then honey buns")
	var poppy_line: Array = dialogue.pick_conversation("poppy")
	check(" ".join(poppy_line).contains("honey buns"), "Poppy has the honey buns ready")
	dialogue.set_flag("spring_buns")
	quests.check()
	check(quests.is_done("duckling_day"), "Duckling Day is done")
	var after: Array = dialogue.pick_conversation("nina_earth")
	check(after.size() > 0, "Nina has lines after")
	var before: int = dd.splashes
	dd.splash(0)
	check(dd.splashes == before + 1, "the puddles still splash after the quest")
	# In autumn none of it's there
	_to_season("autumn")
	change_scene_to_file(EARTH)
	await _frames(12)
	check(current_scene.get_node_or_null("Duckling Day") == null, "no puddles or duck family out of spring")


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
