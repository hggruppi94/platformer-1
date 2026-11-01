extends SceneTree

# Checks the seasons in Stars Hollow (scripts/seasons.gd, put in the Earth scene by scripts/earth_town.gd): the town
# shows the season Earth's calendar says (scripts/clock.gd) and changes when it does. Autumn is the town as built.
# Winter: most leaves gone and the rest snow, snow drifts where the fallen leaves were, white ground and roofs, the
# pond iced over, snow in the air, and the Halloween dressing (with its hay bales' collisions) put away. Spring:
# green leaves with blossom, flowers in the grass, petals in the air. Summer: deep green, a few flowers, fireflies at
# night only. Then back to autumn, exactly as built.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_seasons.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.seasons_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var clock: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	clock = root.get_node("Clock")
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	clock.reset()
	clock.set_earth_time(13 * 60.0, true)
	change_scene_to_file(EARTH)
	for i in 12:
		await process_frame
	var s := current_scene.get_node_or_null("Seasons")
	check(s != null and s.season == "autumn", "the town loads in autumn on a new game")
	if s == null:
		_end()
		return
	var built_leaves: Array = s.shown_leaves.duplicate()
	var built_fallen: Array = s.shown_fallen.duplicate()
	check(built_leaves.size() > 500 and built_fallen.size() > 3000, "it has the trees' leaves and the fallen leaves (%d, %d)" % [built_leaves.size(), built_fallen.size()])
	var land: Node = s._land
	var green := _mat(s, "Town Green")
	var roof := _mat(s, "Roof Bakery")
	var pond := _mat(s, "Pond Water")
	var dressing: Node3D = s._dressing
	check(land != null and green != null and roof != null and pond != null and dressing != null and dressing.visible,
		"...the ground, the green, the roofs, the pond and the Halloween dressing (up in autumn)")
	var roof_autumn: Color = roof.albedo_color
	check(s.air_kind() == "leaves", "leaves drift about in autumn")

	# --- Winter comes on day 11 (the clock checks once a second) ---
	clock.day = 11
	await create_timer(1.3).timeout
	check(clock.date_string() == "Monday 1 Winter" and s.season == "winter", "Monday 1 Winter: the town turns to winter")
	var gone := 0
	var snowy := 0
	for i in s.shown_leaves.size():
		if s.shown_leaf_sizes[i] < 0.01:
			gone += 1
		elif (s.shown_leaves[i] as Color).is_equal_approx(s.SNOW):
			snowy += 1
	check(gone > s.shown_leaves.size() * 0.7 and snowy + gone == s.shown_leaves.size(), "most leaves are gone, the rest are snow (%d gone, %d snow)" % [gone, snowy])
	check(s.shown_fallen.all(func(c: Color) -> bool: return c.is_equal_approx(s.SNOW)), "the fallen leaves are snow drifts")
	check(EarthLand.color_at(0, 30, 0.0, 0.0).get_luminance() > 0.8 and roof.albedo_color.get_luminance() > roof_autumn.get_luminance() + 0.2
		and green.albedo_color.get_luminance() > 0.8, "white ground, green and roofs")
	check(pond.albedo_color.a > 0.95 and pond.albedo_color.b > 0.9, "the pond is iced over")
	var shapes := dressing.find_children("*", "CollisionShape3D", true, false)
	check(not dressing.visible and shapes.all(func(c: CollisionShape3D) -> bool: return c.disabled),
		"the Halloween dressing is put away, hay bales and all (%d collisions off)" % shapes.size())
	check(s.air_kind() == "snow" and s._air.emitting, "it snows")

	# --- Spring and summer ---
	clock.day = clock.day_of("spring", 3)
	await create_timer(1.3).timeout
	var blossom: int = s.shown_leaves.filter(func(c: Color) -> bool: return c.r > 0.9).size()
	var flowers: int = s.shown_fallen_sizes.filter(func(x: float) -> bool: return x > 0.1).size()
	check(s.season == "spring" and blossom > 100 and s.shown_leaf_sizes.all(func(x: float) -> bool: return x > 0.5),
		"spring: every tree in leaf, with blossom (%d)" % blossom)
	check(flowers > 1000 and flowers < s.shown_fallen.size() / 2, "...flowers in the grass instead of fallen leaves (%d)" % flowers)
	check(s.air_kind() == "petals" and not dressing.visible, "...petals in the air, no Halloween")
	clock.day = clock.day_of("summer", 3)
	clock.set_earth_time(13 * 60.0, true)
	await create_timer(1.3).timeout
	check(s.season == "summer" and s.shown_leaves.all(func(c: Color) -> bool: return c.g > c.r), "summer: green leaves")
	check(s.air_kind() == "" and not s._air.emitting, "...nothing in the air by day")
	clock.set_earth_time(22 * 60.0, true)
	await create_timer(0.2).timeout
	check(s.air_kind() == "fireflies" and s._air.emitting, "...and fireflies at night")

	# --- Back to autumn: the town as built ---
	clock.day = clock.day_of("autumn", 3)
	clock.set_earth_time(13 * 60.0, true)
	await create_timer(1.3).timeout
	check(s.season == "autumn" and s.shown_leaves == built_leaves and s.shown_fallen == built_fallen
		and roof.albedo_color.is_equal_approx(roof_autumn) and dressing.visible
		and dressing.find_children("*", "CollisionShape3D", true, false).all(func(c: CollisionShape3D) -> bool: return not c.disabled),
		"autumn again: everything just as the builder made it")
	_end()


func _mat(s: Node, name: String) -> StandardMaterial3D:
	var list: Array = s._mats.get(name, [])
	return list[0] if not list.is_empty() else null


func _end() -> void:
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
