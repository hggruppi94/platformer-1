extends SceneTree

# Checks the shy Peepers (scripts/peeper.gd): one hides in every portal world, standing on the floor near its Remnant
# vein with room round it; walking up to it gives 3 sparkles and sets its flag, only the first time; and a practice
# trip gives nothing.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_peepers.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.peepers_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.peepers_test_backup.cfg"

var failures := 0
var game: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	var portals := root.get_node("Portals")
	portals.home_calls.enabled = false
	for w in portals.WORLDS:
		if not w.has("scene"):
			continue
		change_scene_to_file(w.scene)
		await _frames(10)
		await _physics(4)
		var peepers := get_nodes_in_group("peepers")
		check(peepers.size() == 1, "%s: one Peeper hides there (%d)" % [w.id, peepers.size()])
		if peepers.is_empty():
			continue
		var pe := peepers[0] as Node3D
		var vein := current_scene.find_child("Remnant Vein", true, false) as Node3D
		check(vein != null and pe.global_position.distance_to(vein.global_position) < 4.0, "...beside the Remnant vein")
		var space := (current_scene as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(pe.global_position + Vector3(0, 1, 0), pe.global_position + Vector3(0, -0.5, 0))
		var hit := space.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y - pe.global_position.y) < 0.2, "...standing on the floor")
		var p := current_scene.find_child("Player", true, false) as CharacterBody3D
		var before: int = game.sparkles
		p.global_position = pe.global_position + Vector3(0, 0.9, 1.0)
		p.velocity = Vector3.ZERO
		await _frames(4)
		check(pe.is_found() and game.sparkles == before + 3, "...walking up to it finds it, +3 sparkles (%d)" % (game.sparkles - before))
		check(not pe.found() and game.sparkles == before + 3, "...and only once")
	# A practice trip keeps nothing
	var flag := "peeper_shard_isle"
	root.get_node("Dialogue").flags.erase(flag)
	portals.practice = true
	change_scene_to_file(portals.WORLDS[0].scene)
	await _frames(10)
	var pe2 := get_nodes_in_group("peepers")[0] as Node3D
	var b2: int = game.sparkles
	pe2.found()
	check(game.sparkles == b2, "a practice trip's Peeper gives no sparkles")
	portals.practice = false
	_finish()


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
