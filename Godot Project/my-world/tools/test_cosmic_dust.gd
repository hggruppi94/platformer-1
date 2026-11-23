extends SceneTree

# Checks the cosmic dust (scripts/cosmic_dust.gd, put in by WorldDetail): the Void and the portal worlds each get one
# "Cosmic Dust" in their own colours, Shard Isle (it has its own dream motes) and Stars Hollow get none, it's never
# solid or merged, putting it in again adds nothing, Reduce motion stops it drifting, and with the switch off there's
# none.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_cosmic_dust.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.cosmic_dust_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.cosmic_dust_test_backup.cfg"
const COSMIC := preload("res://scripts/cosmic_dust.gd")
const WITH := ["res://scenes/town/town.tscn", "res://scenes/portal_worlds/dark_hollow.tscn",
	"res://scenes/portal_worlds/lanternmoor.tscn"]
const WITHOUT := ["res://scenes/earth/earth.tscn", "res://scenes/portal_worlds/shard_isle.tscn"]

var failures := 0
var game: Node
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


func _go(path: String) -> Node3D:
	change_scene_to_file(path)
	for i in 14:
		await process_frame
	return current_scene as Node3D


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	detail = root.get_node("WorldDetail")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false

	var colours := []
	for path: String in WITH:
		var w := await _go(path)
		var name := path.get_file().get_basename()
		var dust := w.get_node_or_null(COSMIC.NAME) as MultiMeshInstance3D
		check(dust != null and dust.multimesh.instance_count == COSMIC.COUNT, "%s: has its cosmic dust" % name)
		if dust == null:
			continue
		check(dust.has_meta("cosmic_dust") and not dust.has_meta("static_batch"), "%s: marked and never merged" % name)
		check(dust.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s: nothing solid" % name)
		var m := dust.material_override as ShaderMaterial
		colours.append(m.get_shader_parameter("colour_a"))
		check(m.get_shader_parameter("motion") == 1.0, "%s: drifting" % name)
		check(COSMIC.place(w) == dust and w.find_children(COSMIC.NAME, "", false, false).size() == 1,
			"%s: putting it in again adds nothing" % name)
		COSMIC.set_motion(dust, false)
		check(m.get_shader_parameter("motion") == 0.0, "%s: still with Reduce motion" % name)
		COSMIC.set_motion(dust, true)
	check(colours.size() == 3 and colours[0] != colours[1] and colours[1] != colours[2],
		"each place has its own colours")
	for path: String in WITHOUT:
		var w := await _go(path)
		check(w.get_node_or_null(COSMIC.NAME) == null, "%s: no cosmic dust" % path.get_file().get_basename())

	detail.cosmic = false
	var off := await _go("res://scenes/portal_worlds/dark_hollow.tscn")
	check(off.get_node_or_null(COSMIC.NAME) == null, "switched off: no cosmic dust")
	detail.cosmic = true
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
