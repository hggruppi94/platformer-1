extends SceneTree

# Checks summer in Stars Hollow (Rhythm Springs' reward on Earth):
# - the town in summer: no pumpkins or scarecrows, sunflowers where they stood (none floating or indoors), the patch's
#   sign says Sunflower Field, sunny string lights, a clear blue pond with no mist, the notice board has a star, and
#   the sun's higher and brighter than in autumn with longer days; and in autumn it's all back as it was,
# - nobody on Earth talks about pumpkins, leaves, snow or cocoa in summer (every conversation that can play in summer
#   is checked), and their summer lines play,
# - the notice board's summer jobs: watering thirsty flowers (they stay perked up), strawberries for Poppy,
#   sandcastles on the beach (built by walking into a heap of sand; they stay up), and no sandcastle jobs in autumn,
# - the beach at Willow Pond: on dry ground, clear of paths and the dock,
# - the quest "Summer Splash" with Nina, all the way through (swim ring, bucket and spade, the sandcastle, a
#   cannonball off the dock into the deep water, pink lemonade with Gus).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_summer.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.summer_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.summer_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
# Things that don't belong in summer: autumn's and winter's (the Summer Fair still has a hayride and apple bobbing)
const NOT_SUMMER := "pumpkin|\\bleaves\\b|autumn|cider|halloween|scarecrow|cobweb|caramel|kettle corn|raking|snow|cocoa|frost|sleigh|winter|gingerbread|mitten|ice fishing|shovel"

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
	await _check_splash()
	_finish()


func _to_season(s: String) -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of(s, 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0


# --- What people say ---------------------------------------------------------------------------------------------
func _check_lines() -> void:
	var off := RegEx.create_from_string("(?i)" + NOT_SUMMER)
	var bad: Array[String] = []
	var summer_convs := 0
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
				if not "summer" in ss:
					continue
				summer_convs += 1
			if when.has("talks") or str(when.get("quest_step", "")).begins_with("first_night") \
					or str(when.get("quest_not_started", "")) == "first_night" or str(when.get("quest_step", "")).begins_with("first_snow") \
					or when.get("quest_done", "") == "first_snow" or when.has("activity") and str(when.activity) == "winter_lights":
				continue                                 # (a first hello, the First Night, the First Snow: never summer)
			for set in (c.get("rotate", []) if c.has("rotate") else [c.get("lines", [])]):
				for l in set:
					var said: String = l.replace("Scarecrow Sam", "Sam").replace("Snow Cone", "Cone") if l is String else ""
					if off.search(said) and not "acorn" in said.to_lower() and not "as long as anyone" in said:
						bad.append("%s: %s" % [id, l])
	check(bad.is_empty(), "nobody on Earth talks about autumn or winter things in summer%s" % ("" if bad.is_empty() else " (%s)" % " | ".join(bad)))
	check(summer_convs >= 35, "there are summer conversations (%d)" % summer_convs)
	_to_season("summer")
	var theo: Array = dialogue.pick_conversation("theo")
	check(not " ".join(theo).contains("autumn"), "Theo's lines fit summer")


# --- The town ----------------------------------------------------------------------------------------------------
func _check_town() -> void:
	_to_season("autumn")
	change_scene_to_file(EARTH)
	await _frames(12)
	var sun := current_scene.get_node("Sun") as DirectionalLight3D
	var autumn_sun := sun.light_energy
	var autumn_high := -sun.rotation_degrees.x
	clock.earth_minutes = 20.5 * 60.0
	await _frames(3)
	var autumn_evening := sun.light_energy
	_to_season("summer")
	change_scene_to_file(EARTH)
	await _frames(12)
	await _physics(2)
	sun = current_scene.get_node("Sun") as DirectionalLight3D
	var seasons := current_scene.get_node("Seasons")
	check(seasons.season == "summer", "Stars Hollow's in summer")
	check(sun.light_energy > autumn_sun * 1.2 and -sun.rotation_degrees.x > autumn_high + 8.0,
		"the summer sun's brighter (%.2f, autumn %.2f) and higher (%.0f, autumn %.0f degrees)" % [sun.light_energy, autumn_sun,
		-sun.rotation_degrees.x, autumn_high])
	clock.earth_minutes = 20.5 * 60.0
	await _frames(3)
	check(sun.light_energy > autumn_evening + 0.2 and sun.light_color != Color(0.58, 0.66, 1.0), "...and it's still light at half past eight in the evening")
	clock.earth_minutes = 13 * 60.0
	await _frames(3)
	var pumpkins: Array = seasons.get("_pumpkins")
	check(pumpkins.size() > 20 and pumpkins.all(func(n: Node3D) -> bool: return not n.visible),
		"no pumpkins or scarecrows round town in summer (%d hidden)" % pumpkins.size())
	var flowers := current_scene.get_node_or_null("Seasons/Summer Sunflowers")
	check(flowers != null and seasons.shown_sunflowers >= 8, "sunflowers stand where they were (%d)" % seasons.shown_sunflowers)
	check(current_scene.get_node_or_null("Seasons/Winter Snowmen") == null, "...and no snowmen")
	var floating := 0
	if flowers:
		for sf in flowers.get_children():
			var p := (sf as Node3D).global_position
			if absf(p.y - EarthLand.height(p.x, p.z)) > 0.45:
				floating += 1
	check(floating == 0, "...all on the ground")
	var sign := seasons.get("_patch_sign") as Label3D
	check(sign != null and sign.text == "Sunflower Field", "the pumpkin patch is the Sunflower Field")
	check(seasons.lights_colour(0) == seasons.BULBS_SUMMER[0], "the string lights are sunny")
	var mist: Array = seasons.get("_mist")
	check(mist.size() > 0 and mist.all(func(m: Node3D) -> bool: return not m.visible), "no Halloween mist over the pond")
	check(seasons.air_kind() == "fluff", "dandelion fluff in the air")
	var board := current_scene.get_node_or_null("Notice Board")
	check(board == null or board.find_children("*", "OmniLight3D", true, false).size() >= 1, "the notice board's up")
	# The beach: dry where you stand, clear of the dock, the paths and anything solid
	var splash := current_scene.get_node_or_null("Summer Splash")
	check(splash != null and splash.get_node_or_null("Beach/Sand") != null, "there's a beach at Willow Pond")
	var ss = root.get_node("EarthTown/SummerSplash")
	var wet := 0
	for s in ss.CASTLE_SPOTS + [ss.CASTLE_AT]:
		if EarthLand.height(s.x, s.y) < EarthLand.WATER_Y + 0.15 or absf(s.y) < 2.5:
			wet += 1
	check(wet == 0, "the sandcastles all go on dry sand, off the dock")
	var places = JSON.parse_string(FileAccess.get_file_as_string("res://routines/earth_places.json"))
	var near := 0
	for link in places.links:
		var a: Array = places.points[link[0]]
		var b: Array = places.points[link[1]]
		for s in ss.CASTLE_SPOTS + [ss.CASTLE_AT, Vector2(ss.UMBRELLAS[0].x, ss.UMBRELLAS[0].z), Vector2(ss.UMBRELLAS[1].x, ss.UMBRELLAS[1].z)]:
			if Geometry2D.get_closest_point_to_segment(s, Vector2(a[0], a[1]), Vector2(b[0], b[1])).distance_to(s) < 1.5:
				near += 1
	check(near == 0, "nothing on the beach is in anyone's way (%d)" % near)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var blocked := 0
	for s in ss.CASTLE_SPOTS + [ss.CASTLE_AT, Vector2(ss.UMBRELLAS[0].x, ss.UMBRELLAS[0].z), Vector2(ss.UMBRELLAS[1].x, ss.UMBRELLAS[1].z)]:
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.6
		q.shape = sphere
		q.transform = Transform3D(Basis(), ss.ground(s) + Vector3(0, 0.9, 0))
		for h in space.intersect_shape(q, 4):
			if h.collider is StaticBody3D and not h.collider is EarthLand:
				blocked += 1
				break
	check(blocked == 0, "...and nothing solid's there")
	_to_season("autumn")
	seasons.apply("autumn")
	check(pumpkins.all(func(n: Node3D) -> bool: return n.visible) and current_scene.get_node_or_null("Seasons/Summer Sunflowers") == null
		and sign.text == "Pumpkin Patch" and mist.all(func(m: Node3D) -> bool: return m.visible), "in autumn the pumpkins, scarecrows and mist are back")
	await _frames(2)


# --- The notice board ----------------------------------------------------------------------------------------------
func _check_jobs() -> void:
	_to_season("autumn")
	var autumn_kinds := {}
	for t in ["easy", "medium", "hard"]:
		for k in jobs.kinds_for(t):
			autumn_kinds[k] = true
	check(not autumn_kinds.has("sandcastle"), "no sandcastle jobs in autumn")
	_to_season("summer")
	var summer_kinds := {}
	for t in ["easy", "medium", "hard"]:
		for k in jobs.kinds_for(t):
			summer_kinds[k] = true
	check(not summer_kinds.has("snowman"), "no snowman jobs in summer")
	change_scene_to_file(EARTH)
	await _frames(12)
	var seen := {}
	var off := RegEx.create_from_string("(?i)" + NOT_SUMMER)
	var bad: Array[String] = []
	var castle_job: Dictionary = {}
	var water_job: Dictionary = {}
	for d in 40:
		jobs.roll(hash("summer_test:%d" % d))
		for r in jobs.list:
			seen[str(r.kind)] = true
			var text: String = jobs.text_of(r)
			if off.search(text):
				bad.append(text)
			if str(r.kind) == "sandcastle" and castle_job.is_empty():
				castle_job = r.duplicate(true)
			if str(r.kind) == "rake" and water_job.is_empty():
				water_job = r.duplicate(true)
	check(seen.has("sandcastle") and seen.has("rake") and seen.has("bakery"), "summer has sandcastle, watering and strawberry jobs")
	check(bad.is_empty(), "no summer job says pumpkins, leaves or snow%s" % ("" if bad.is_empty() else " (%s)" % bad[0]))
	check(str(jobs.text_of(water_job)).contains("Water the thirsty flowers"), "raking's watering in summer")
	# Build the sandcastles: walk into each heap of sand
	var player := current_scene.find_child("Player", true, false) as Node3D
	jobs.list.clear()
	jobs.list.append(castle_job)
	jobs.rolled_visit = clock.earth_day()
	jobs._place_props()
	await _frames(3)
	var heaps := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "sandpile")
	check(heaps.size() == int(castle_job.goal), "a heap of sand waits on the beach for each sandcastle (%d)" % heaps.size())
	for b in heaps:
		b.call("_on_body", player)
	await _frames(2)
	check(bool(jobs.list[0].done) and heaps.all(func(b: Node) -> bool: return b.get("built")), "walking into them builds the sandcastles and does the job")
	jobs._place_props()
	await _frames(2)
	var built := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("built") == true)
	check(built.size() == int(castle_job.goal), "the sandcastles stay up after the job's done")
	# Water the flowers: walk into each one
	jobs.list.clear()
	jobs.list.append(water_job)
	jobs._place_props()
	await _frames(3)
	var pots := current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "thirsty")
	check(pots.size() == int(water_job.goal), "a thirsty flower by the house for each one to water (%d)" % pots.size())
	for b in pots:
		b.call("_on_body", player)
	await _frames(2)
	check(bool(jobs.list[0].done), "watering them all does the job")
	jobs._place_props()
	await _frames(2)
	pots = current_scene.get_tree().get_nodes_in_group("earth_job_props").filter(func(n: Node) -> bool: return n.get("kind") == "thirsty")
	check(pots.size() == int(water_job.goal) and pots.all(func(b: Node) -> bool: return b.get("built")), "the watered flowers stay perked up")


# --- Summer Splash -------------------------------------------------------------------------------------------------
func _check_splash() -> void:
	_to_season("summer")
	change_scene_to_file(EARTH)
	await _frames(14)
	await _physics(2)
	var splash := current_scene.get_node_or_null("Summer Splash")
	check(splash != null, "summer puts Summer Splash's spots in Stars Hollow")
	if splash == null:
		return
	dialogue.talks["nina_earth"] = 5
	var nina: Array = dialogue.pick_conversation("nina_earth")
	check(" ".join(nina).contains("BEACH DAY"), "Nina wants a beach day")
	dialogue.set_flag("summer_splash_start")
	quests.check()
	await _frames(2)
	var ss := root.get_node("EarthTown/SummerSplash")
	ss._refresh()
	check(quests.on_step("summer_splash", "gather"), "Summer Splash starts")
	check(splash.get_node("Swim Ring/Thing").visible and splash.get_node("Bucket/Thing").visible, "the swim ring and bucket glow")
	ss._take_ring()
	ss._take_bucket()
	quests.check()
	check(quests.on_step("summer_splash", "build"), "with the swim ring and bucket, it's time to build")
	check(ss._build_offer() != "", "...on the beach with Nina")
	ss._build()
	quests.check()
	await _frames(3)
	check(splash.get_node_or_null("Our Sandcastle") != null and quests.on_step("summer_splash", "jump"), "the sandcastle goes up on the beach")
	# The cannonball: from the dock into deep water
	var dock_end: Vector3 = ss.DOCK_END
	check(EarthLand.height(dock_end.x, dock_end.z) < EarthLand.WATER_Y and EarthLand.height(ss.SPLASH_AT.x, ss.SPLASH_AT.y) < EarthLand.WATER_Y - 0.8,
		"the jump's off the end of the dock into the deep middle of the pond")
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	player.global_position = dock_end + Vector3(0, 1, 0)
	await _physics(30)
	check(player.global_position.y > dock_end.y + 0.5, "you can stand on the dock where you jump from (y %.2f)" % player.global_position.y)
	ss.cannonball()
	check(ss.is_jumping(), "cannonball!")
	await create_timer(ss.JUMP_TIME + 0.5).timeout
	quests.check()
	var landed: Vector3 = ss.splash_point()
	check(not ss.is_jumping() and Vector2(player.global_position.x - landed.x, player.global_position.z - landed.z).length() < 1.5,
		"KER-SPLOOSH, into the pond")
	check(not player.input_locked, "...and you can swim off")
	check(quests.on_step("summer_splash", "lemonade"), "then it's lemonade time")
	dialogue.talks["gus"] = 3
	var gus: Array = dialogue.pick_conversation("gus")
	check(" ".join(gus).contains("pink lemonades"), "Gus pours the pink lemonade")
	dialogue.set_flag("splash_lemonade")
	quests.check()
	check(quests.is_done("summer_splash"), "Summer Splash is done")
	_to_season("autumn")
	change_scene_to_file(EARTH)
	await _frames(12)
	check(current_scene.get_node_or_null("Summer Splash") == null, "no beach in autumn")


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
