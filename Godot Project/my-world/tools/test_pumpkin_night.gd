extends SceneTree

# Checks autumn's quest "Pumpkin Night" with Nina (scripts/pumpkin_night.gd): Nina offers it in autumn after The First
# Night; the pumpkin, candle, carving spot and porch are on dry, open ground with nothing solid in the way; the steps go
# in order with the right things glowing; the lit jack-o'-lantern stays on the porch after the town loads again; Gus
# makes the cider; and nothing of it is there in winter.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_pumpkin_night.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.pumpkin_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.pumpkin_test_backup.cfg"
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
	await _check_pumpkin_night()
	_finish()


func _to_season(s: String) -> void:
	clock.on_earth = true
	clock.set_time(clock.day_of(s, 3, 1), 13 * 60.0, true)
	clock.earth_minutes = 13 * 60.0


# --- Pumpkin Night ------------------------------------------------------------------------------------------------
func _clear(at: Vector3) -> bool:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	q.shape = sphere
	q.transform = Transform3D(Basis(), at + Vector3(0, 0.75, 0))
	for h in space.intersect_shape(q, 4):
		if h.collider is StaticBody3D and not h.collider is EarthLand:
			return false
	return not EarthLand.is_water(at.x, at.z)


func _check_pumpkin_night() -> void:
	_to_season("autumn")
	change_scene_to_file(EARTH)
	await _frames(14)
	await _physics(2)
	var g := current_scene.get_node_or_null("Pumpkin Night")
	check(g != null, "autumn puts Pumpkin Night's spots in Stars Hollow")
	if g == null:
		return
	for n in ["Pick Pumpkin", "Candle", "Carving Spot", "Porch"]:
		var at := (g.get_node(n) as Node3D).global_position
		check(_clear(at), "%s is on open ground (%.1f, %.1f)" % [n, at.x, at.z])
		check(absf(at.y - EarthLand.height(at.x, at.z)) < 0.4, "...and on the ground, not floating")
	dialogue.talks["nina_earth"] = 5
	var nina: Array = dialogue.pick_conversation("nina_earth")
	check(" ".join(nina).contains("pumpkin time"), "Nina wants to make a jack-o'-lantern")
	dialogue.set_flag("pumpkin_night_start")
	quests.check()
	await _frames(2)
	var pn := root.get_node("EarthTown/PumpkinNight")
	pn._refresh()
	check(quests.on_step("pumpkin_night", "gather"), "Pumpkin Night starts")
	check(g.get_node("Pick Pumpkin/Thing").visible and g.get_node("Candle/Thing").visible, "the pumpkin and candle show")
	check(not g.get_node("Carving Spot/Uncarved").visible, "...but nothing to carve yet")
	pn._take("pn_pumpkin", "")
	pn._take("pn_candle", "")
	quests.check()
	pn._refresh()
	check(quests.on_step("pumpkin_night", "carve"), "with both, it's time to carve")
	check(not g.get_node("Pick Pumpkin/Thing").visible, "...and the pumpkin's been picked")
	check(g.get_node("Carving Spot/Uncarved").visible, "...the pumpkin waits on the green")
	var star: Array = JSON.parse_string(FileAccess.get_file_as_string("res://quests/pumpkin_night.json")).steps[1].where[0].at
	var carve_at := (g.get_node("Carving Spot") as Node3D).global_position
	check(Vector2(carve_at.x, carve_at.z).distance_to(Vector2(star[0], star[1])) < 2.0, "...and the map's star is on it")
	pn._carve()
	quests.check()
	pn._refresh()
	check(quests.on_step("pumpkin_night", "porch"), "carved! now the porch")
	check(g.get_node("Porch/Unlit").visible, "...where the carved pumpkin waits")
	pn._light()
	quests.check()
	await _frames(3)
	check(g.get_node_or_null("Our Lantern") != null, "the jack-o'-lantern glows by the Blastoffs' door")
	check(quests.on_step("pumpkin_night", "cider"), "then it's cider time")
	dialogue.talks["gus"] = 3
	var gus: Array = dialogue.pick_conversation("gus")
	check(" ".join(gus).contains("cider"), "Gus makes the cider")
	dialogue.set_flag("pn_cider")
	quests.check()
	check(quests.is_done("pumpkin_night"), "Pumpkin Night is done")
	# The lantern's still there when the town loads again
	change_scene_to_file(EARTH)
	await _frames(14)
	await _physics(2)
	check(current_scene.get_node_or_null("Pumpkin Night/Our Lantern") != null, "the lantern's still lit next time")
	# None of it in winter
	_to_season("winter")
	change_scene_to_file(EARTH)
	await _frames(14)
	check(current_scene.get_node_or_null("Pumpkin Night") == null, "no Pumpkin Night in winter")


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
