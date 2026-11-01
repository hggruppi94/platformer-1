extends SceneTree

# Checks Stars Hollow's big days (scripts/festival.gd BIG_DAYS, scripts/big_day.gd): Winter Lights on 21 Winter (the
# Winter Tree on the green, lit at 6 PM), Kite Day on 14 Spring (kites over Lookout Hill, a stand that lends you one)
# and Firefly Night on 28 Summer (fireworks over Willow Pond, a finale at 10 PM). Each is a Sunday, on the Calendar,
# up only in its hours, somewhere with room and off the paths, pays its prize once for being there, brings the kids
# (their routines' blocks named after the day) and saves.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_big_days.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.big_days_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const KIDS := ["nina_earth", "bruno", "prue", "juniper", "theo", "ozzie"]

var failures := 0
var F: Node
var game: Node
var clock: Node
var dialogue: Node
var town: Node3D
var player: CharacterBody3D


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
	F = root.get_node("Festival")
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	dialogue.reset()
	root.get_node("Quests").reset()
	F.reset()
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.reset()
	clock.pulls_home = false
	clock.on_earth = true

	# --- The calendar ---
	var lights: int = clock.day_of("winter", 21)
	var kites: int = clock.day_of("spring", 14)
	var fireworks: int = clock.day_of("summer", 28)
	check(F.big_day(lights) == "lights" and F.big_day(kites) == "kites" and F.big_day(fireworks) == "fireworks"
		and F.big_day(lights - 1) == "" and F.big_day(2) == "", "Winter Lights, Kite Day and Firefly Night fall on their dates")
	check(clock.weekday(lights) == "Sunday" and clock.weekday(kites) == "Sunday" and clock.weekday(fireworks) == "Sunday"
		and not F.is_festival_day(lights) and not F.is_festival_day(kites) and not F.is_festival_day(fireworks),
		"all three are Sundays, never on top of a fair")
	check(F.events_on(lights).has("Winter Lights, 5 PM-10 PM") and F.events_on(kites).has("Kite Day, 10 AM-5 PM")
		and F.events_on(fireworks).has("Firefly Night, 8:30 PM-11 PM"), "the Calendar page lists them %s" % [F.events_on(fireworks)])

	# --- Winter Lights ---
	clock.day = lights
	clock.set_earth_time(16 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	await _physics(4)
	town = current_scene as Node3D
	player = town.find_child("Player", true, false) as CharacterBody3D
	_put(Vector2(10, 25))
	await _wait(0.7)
	check(town.get_node_or_null("Big Day") == null, "4 PM: nothing up yet")
	clock.set_earth_time(17 * 60.0 + 20.0, true)
	await _wait(0.7)
	var show := town.get_node_or_null("Big Day")
	check(show != null and show.kind == "lights" and show.find_child("Winter Tree", false, false) != null, "5:20 PM: the Winter Tree's up")
	if show == null:
		_end()
		return
	check(not show.lit, "...but not lit before 6")
	check(_off_paths(F.TREE_AT, 3.0), "the tree stands clear of everyone's paths")
	check(_room(F.TREE_AT, 2.4, show), "...and of anything solid")
	await _physics(10)
	var at_tree := []
	for id in KIDS:
		var r: Node = dialogue.routine_of(id)
		if r and r.activity() == "winter_lights":
			at_tree.append(id)
	check(at_tree.size() == KIDS.size(), "the kids come to see the tree %s" % [at_tree])
	dialogue.talks["bruno"] = 3
	check(" ".join(dialogue._pick("bruno").get("lines", [])).contains("lighth"), "Bruno counts the lights")
	var before: int = game.sparkles
	_put(F.TREE_AT + Vector2(6, 6))
	clock.set_earth_time(18 * 60.0 + 5.0, true)
	await _wait(0.4)
	check(show.lit and game.sparkles == before + int(F.BIG_DAYS.lights.prize), "6 PM: it's lit, and being there pays %d" % (game.sparkles - before))
	await _wait(0.3)
	check(game.sparkles == before + int(F.BIG_DAYS.lights.prize), "...once")
	check(root.get_node("Quests").log_text().contains("Winter Lights"), "the Quests sheet says it's Winter Lights")
	clock.set_earth_time(22 * 60.0 + 5.0, true)
	await _wait(0.7)
	check(town.get_node_or_null("Big Day") == null, "after 10 PM it's all gone")

	# --- Kite Day ---
	clock.day = kites
	clock.set_earth_time(11 * 60.0, true)
	clock.jumped.emit()
	_put(F.KITE_STAND_AT + Vector2(0, 3))
	await _wait(0.7)
	show = town.get_node_or_null("Big Day")
	check(show != null and show.kind == "kites" and show.get_node_or_null("Kite Stand") != null, "Kite Day: the kite stand's up")
	check(_off_paths(F.KITE_STAND_AT, 2.5) and _room(F.KITE_STAND_AT, 1.6, show), "...beside the path, with room round it")
	await _physics(10)
	await _wait(0.3)
	var flying := []
	for id in KIDS:
		var r: Node = dialogue.routine_of(id)
		if r and r.activity() == "kites" and r.current_block().get("place", "") == "hill_top":
			flying.append(id)
	check(flying.size() == KIDS.size(), "the kids are on Lookout Hill with their kites %s" % [flying])
	check(show._sky_kites.size() == 7, "kites already flying over the hill")
	check(show.player_kite == null, "no kite of your own yet")
	(show.get_node("Kite Stand") as Node).call("use")
	await _frames(2)
	check(dialogue.is_active() and F.kite_day == clock.earth_day(), "Interact at the stand: you borrow a kite")
	dialogue.end()
	await _wait(0.2)
	check(show.player_kite != null and show.player_kite.global_position.y > player.global_position.y + 3.0,
		"...and it flies over you")
	before = game.sparkles
	var top: Vector3 = show._hilltop()
	_put(Vector2(top.x + 2, top.z + 2))
	await _wait(0.4)
	check(game.sparkles == before + int(F.BIG_DAYS.kites.prize), "flying it from the hilltop pays %d" % (game.sparkles - before))
	clock.set_earth_time(17 * 60.0 + 5.0, true)
	await _wait(0.7)
	check(town.get_node_or_null("Big Day") == null, "after 5 PM the kites come down")

	# --- Firefly Night ---
	clock.day = fireworks
	clock.set_earth_time(21 * 60.0, true)
	clock.jumped.emit()
	_put(Vector2(-58.5, 10.5))
	await _wait(0.7)
	show = town.get_node_or_null("Big Day")
	check(show != null and show.kind == "fireworks" and show.get_node_or_null("Firework Raft") != null, "Firefly Night: a raft in the pond")
	var fired: int = show.rockets_fired if show else 0
	await _wait(3.0)
	var slow: int = show.rockets_fired - fired
	check(slow >= 1 and slow <= 5, "rockets go up every second or so (%d in 3 s)" % slow)
	check(game.sparkles == before + int(F.BIG_DAYS.kites.prize), "no prize before the finale")
	clock.set_earth_time(22 * 60.0 + 1.0, true)
	fired = show.rockets_fired
	await _wait(2.0)
	check(show.rockets_fired - fired >= 6, "the finale: lots more (%d in 2 s)" % (show.rockets_fired - fired))
	check(show.find_children("Burst*", "MultiMeshInstance3D", false, false).size() > 0, "...bursting in colours")
	check(game.sparkles == before + int(F.BIG_DAYS.kites.prize) + int(F.BIG_DAYS.fireworks.prize), "watching from the pond pays")

	# --- Saving ---
	var saved: Dictionary = F.save_data()
	F.reset()
	F.load_data(saved)
	check(int(F.big_prize_days.get("fireworks", 0)) == fireworks and F.kite_day == kites, "the big days' prizes save and load")
	clock.set_earth_time(23 * 60.0 + 5.0, true)
	await _wait(0.7)
	check(town.get_node_or_null("Big Day") == null, "after 11 PM the show's over")
	_end()


func _put(p: Vector2) -> void:
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(p.x, EarthLand.height(p.x, p.y) + 1.0, p.y)


func _off_paths(p: Vector2, clear: float) -> bool:
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://routines/earth_places.json"))
	for link in data.links:
		var a: Vector2 = paths.points[str(link[0])]
		var b: Vector2 = paths.points[str(link[1])]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < clear:
			print("      too near the path %s - %s" % [link[0], link[1]])
			return false
	return true


func _room(p: Vector2, radius: float, own: Node) -> bool:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = 2.5
	q.shape = sh
	q.transform = Transform3D(Basis(), Vector3(p.x, EarthLand.height(p.x, p.y) + 1.5, p.y))
	q.exclude = [player.get_rid()]
	for hit in space.intersect_shape(q, 8):
		if not own.is_ancestor_of(hit.collider):
			print("      in the way: %s" % hit.collider.name)
			return false
	return true


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(1 if failures > 0 else 0)
