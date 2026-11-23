extends SceneTree

# Checks the moving pixel flames (scripts/fire_fx.gd, put in by WorldDetail): Rhythm Springs' torches and flaring
# stones, Dark Hollow's green lamps, Lanternmoor's beacons (none while unlit, one once lit), the castle school's and
# the Haunted House's candles. Each old flame shape is see-through and never merged, each pixel flame stands on its old
# flame's foot at a size that fits it, a hidden flame hides its pixel flame too, a green flame burns green, dressing a
# place again adds nothing, and with the switch off there are none.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_fire_fx.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.fire_fx_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.fire_fx_test_backup.cfg"
const FIRE := preload("res://scripts/fire_fx.gd")
const PLACES := {
	"res://scenes/portal_worlds/rhythm_springs.tscn": 10,
	"res://scenes/portal_worlds/dark_hollow.tscn": 10,
	"res://scenes/school/school.tscn": 0,
	"res://scenes/interiors/haunted_house.tscn": 3,
}

var failures := 0
var game: Node
var portals: Node
var detail: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go(path: String) -> Node3D:
	change_scene_to_file(path)
	await _frames(14)
	return current_scene as Node3D


func _check_flames(w: Node3D, label: String, at_least: int) -> Array:
	var flames := FIRE.flames_in(w)
	print("  %s: %d pixel flames (dressed on load %d)" % [label, flames.size(), detail.last_fire])
	check(flames.size() >= at_least, "%s: at least %d flames (%d)" % [label, at_least, flames.size()])
	var bad_old := 0
	var merged := 0
	var off_foot := 0
	var sizes := 0
	for q: MeshInstance3D in flames:
		var p := q.get_parent()
		if p is MeshInstance3D:
			var old := p as MeshInstance3D
			if old.transparency < 1.0 or not old.has_meta(FIRE.META):
				bad_old += 1
			if old.has_meta("static_batch"):
				merged += 1
			var box := old.get_aabb()
			var foot := old.global_transform * Vector3(box.get_center().x, box.position.y, box.get_center().z)
			if q.global_position.distance_to(foot) > 0.05:
				off_foot += 1
			var tall := box.size.y * old.global_transform.basis.get_scale().y
			var h := q.global_transform.basis.get_scale().y
			if h < tall * 2.0 or h > tall * 8.0 + 0.3:
				sizes += 1
	check(bad_old == 0, "%s: every old flame is see-through and marked (%d not)" % [label, bad_old])
	check(merged == 0, "%s: no old flame was merged away (%d)" % [label, merged])
	check(off_foot == 0, "%s: each pixel flame stands on its old flame's foot (%d off)" % [label, off_foot])
	check(sizes == 0, "%s: each pixel flame fits its old flame's size (%d don't)" % [label, sizes])
	check(FIRE.dress(w) == 0, "%s: dressing it again adds nothing" % label)
	return flames


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	detail = root.get_node("WorldDetail")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals.home_calls.enabled = false
	portals.practice = false

	for path: String in PLACES:
		var w := await _go(path)
		var flames := _check_flames(w, path.get_file().get_basename(), int(PLACES[path]))
		if path.contains("dark_hollow"):
			var green := 0
			for q: MeshInstance3D in flames:
				var h: float = (q.material_override as ShaderMaterial).get_shader_parameter("hue_shift")
				if h > 0.2 and h < 0.5:
					green += 1
			check(green > 0 and green == flames.size(), "dark_hollow: its lamp flames burn green (%d of %d)" % [green, flames.size()])
		if path.contains("rhythm_springs"):
			# The Sizzle Steps' stones: each has a bonfire "Flame" that's hidden till it flares.
			var stones := 0
			var hidden_ok := 0
			for f: Node in w.find_children("Flame", "Node3D", true, false):
				if f.get_class() != "Node3D":
					continue
				stones += 1
				var q := f.get_node_or_null(FIRE.NAME) as MeshInstance3D
				if q and f.get_node_or_null(FIRE.NAME + " 2") and q.is_visible_in_tree() == (f as Node3D).is_visible_in_tree():
					hidden_ok += 1
			check(stones > 0 and hidden_ok == stones,
				"rhythm_springs: every stone's bonfire has three flames that hide and show with it (%d of %d)" % [hidden_ok, stones])

	# Lanternmoor: an unlit beacon has no fire; lit, its new flame gets one as it arrives.
	var lm := await _go("res://scenes/portal_worlds/lanternmoor.tscn")
	var b2 := lm.get_node_or_null("Beacon2/Beacon")
	check(b2 != null and FIRE.flames_in(b2).is_empty(), "lanternmoor: an unlit beacon has no flame")
	lm.light_beacon(1)
	await _frames(4)
	b2 = lm.get_node_or_null("Beacon2/Beacon")
	check(b2 != null and FIRE.flames_in(b2).size() == 1, "lanternmoor: lit, the beacon burns")

	# With the switch off there are none.
	detail.fire = false
	var off := await _go("res://scenes/portal_worlds/dark_hollow.tscn")
	check(FIRE.flames_in(off).is_empty(), "switched off: no pixel flames")
	detail.fire = true
	print("RESULT " + ("FAILED (%d)" % failures if failures else "PASSED"))
	_finish()


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if failures else 0)
