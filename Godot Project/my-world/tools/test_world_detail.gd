extends SceneTree

# Checks the 14 Nov 2026 look pass (scripts/world_detail.gd and what it calls):
# - the Void's cone mountains are hidden and real mountains stand in their place, with a far range behind,
# - the ground everywhere gets the detail shader (and water doesn't),
# - every big waterfall (two on the plateau, two by the castle, Mossy Falls, Rhythm Springs' mesa) has a cove behind
#   it with a solid floor and a chest that pays once,
# - the Dusk's Embrace gate stands behind the Haunted House, facing it, inside a walled hollow, and its Talk spot and
#   way back out came with it,
# - Flurry has a bushy fox tail, and the Rainbow Ray's beam wobbles.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_world_detail.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.world_detail_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.world_detail_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const RHYTHM := "res://scenes/portal_worlds/rhythm_springs.tscn"

var failures := 0
var FALLS: GDScript      # loaded once the autoloads are up (big_falls.gd uses them), never preloaded
var DUSK: GDScript


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
	FALLS = load("res://scripts/big_falls.gd")
	DUSK = load("res://scripts/dusk_gate.gd")
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Clock").set("pulls_home", false)

	# The Void
	change_scene_to_file(TOWN)
	await _frames(12)
	var town := current_scene
	_mountains(town)
	_ground(town, "the Void")
	_falls(town, ["plateau_1", "plateau_2", "castle_east", "castle_west"], "the Void")
	await _gate(town)
	_flurry()
	_rainbow()

	# Stars Hollow and Rhythm Springs
	change_scene_to_file(EARTH)
	await _frames(12)
	_ground(current_scene, "Stars Hollow")
	_falls(current_scene, ["mossy_falls"], "Stars Hollow")
	change_scene_to_file(RHYTHM)
	await _frames(14)
	_ground(current_scene, "Rhythm Springs")
	_falls(current_scene, ["mesa_falls"], "Rhythm Springs")
	_finish()


func _mountains(town: Node) -> void:
	var holder := town.find_child("Mountains", true, false) as Node3D
	check(holder != null and holder.has_meta("alien_mountains"), "the Void's mountains were dressed")
	if holder == null:
		return
	var cones := 0
	var shown := 0
	var peaks := 0
	for c in holder.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
			cones += 1
			if (c as MeshInstance3D).visible:
				shown += 1
		elif String(c.name).begins_with("Peak "):
			peaks += 1
	check(cones > 0 and shown == 0, "every old cone is hidden (%d cones, %d still showing)" % [cones, shown])
	check(peaks >= cones + 16, "a mountain for each cone and a range of 16 behind (%d peaks)" % peaks)
	var rock := holder.find_child("Rock", true, false) as MeshInstance3D
	check(rock != null and rock.mesh is ArrayMesh and (rock.mesh as ArrayMesh).get_surface_count() == 1,
		"a mountain is a real mesh, not a cone")


func _ground(scene: Node, where: String) -> void:
	var detailed := 0
	var water_detailed := 0
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.has_meta("ground_detail"):
			continue
		detailed += 1
		var low := String(mi.name).to_lower()
		if low.contains("water") or low.contains("lake") or low.contains("pond"):
			water_detailed += 1
	check(detailed > 0, "%s: the ground has detail (%d meshes)" % [where, detailed])
	check(water_detailed == 0, "%s: no water got the ground's detail" % where)


func _falls(scene: Node, ids: Array, where: String) -> void:
	for id in ids:
		var f := scene.get_node_or_null("Big Falls %s" % id) as Node3D
		check(f != null, "%s: the %s waterfall is big now" % [where, id])
		if f == null:
			continue
		var info: Dictionary = f.get_meta("info")
		check(info.lip_y - info.floor_y >= 2.5, "%s: %s's cove is tall enough to walk in (%.1f m)" % [where, id,
			info.lip_y - info.floor_y])
		check(info.front - info.inner >= 2.0, "%s: %s's cove goes back behind the curtain (%.1f m)" % [where, id,
			info.front - info.inner])
		var floor_body := f.find_child("Cove Floor", true, false)
		check(floor_body != null and floor_body.get_node_or_null("Cove Floor Body") is StaticBody3D,
			"%s: %s's cove floor is solid" % [where, id])
		check(f.find_child("Through The Curtain", true, false) is Area3D, "%s: %s's curtain splashes you" % [where, id])
		var chest := f.find_child("Cove Chest", true, false) as Node3D
		check(chest != null, "%s: %s's cove has a chest" % [where, id])
		if chest == null:
			continue
		var before: int = root.get_node("Game").sparkles
		check(FALLS.open_chest(chest), "%s: %s's chest opens" % [where, id])
		check(root.get_node("Game").sparkles > before, "%s: %s's chest pays sparkles" % [where, id])
		check(not FALLS.open_chest(chest), "%s: %s's chest only pays once" % [where, id])


func _gate(town: Node) -> void:
	var gate := town.get_node_or_null("Scary World Gate") as Node3D
	var house := town.get_node_or_null("Haunted House") as Node3D
	check(gate != null and house != null, "the gate and the Haunted House are there")
	if gate == null or house == null:
		return
	var back := -house.global_transform.basis.z
	back.y = 0
	var off := gate.global_position - house.global_position
	off.y = 0
	check(absf(off.length() - DUSK.BEHIND_HOUSE) < 0.5 and off.normalized().dot(back.normalized()) > 0.98,
		"the gate is %.0f m straight out of the house's back" % off.length())
	var facing := gate.global_transform.basis.z
	facing.y = 0
	check(facing.normalized().dot(-off.normalized()) > 0.95, "the gate faces the house")
	check(town.find_child("Dusk Hollow", true, false) != null, "a walled hollow is round it")
	var talk := gate.find_child("Talk", true, false) as Node3D
	var out := gate.find_child("FromScaryWorld", true, false) as Node3D
	check(talk != null and talk.global_position.distance_to(gate.global_position) < 4.0, "its Talk spot came with it")
	check(out != null and out.global_position.distance_to(gate.global_position) < 6.0, "its way back out came with it")
	if out:
		# Coming back out lands on the house's side of the wall, on the ground
		var to_house := house.global_position - out.global_position
		to_house.y = 0
		check(to_house.length() < off.length(), "coming back out puts you on the house's side")


func _flurry() -> void:
	var fm := load("res://scripts/frozen_moment.gd") as GDScript
	var model: Node3D = fm.flurry_model()
	root.add_child(model)
	check(model.find_child("Fox Tail", true, false) != null, "Flurry has a bushy fox tail")
	model.queue_free()


func _rainbow() -> void:
	var ray := (load("res://scripts/rainbow_ray.gd") as GDScript).new() as Node3D
	current_scene.add_child(ray)
	ray.call("shine", Vector3(0, 30, 0), Vector3.FORWARD, {"radius": 10.0, "time": 1.4})
	var wobbly := false
	for n in ray.find_children("*", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as ShaderMaterial
		if m and m.shader and m.shader.code.contains("instance uniform float span"):
			wobbly = true
	check(wobbly, "the Rainbow Ray's beam wobbles")
	ray.queue_free()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
