extends SceneTree

# Checks the buildings' insides (16 Nov 2026):
# - Stars Hollow (scripts/insides.gd): every building in Insides.ROOMS is hollow: its solid box is gone, there's a
#   doorway you can walk through into the room, solid walls everywhere else, a floor, the room's furniture (baked
#   props as MultiMeshes, which you bump into), lights and the "interior" music, Inside and Doorway markers, no
#   occluder inside it, and its insides stop drawing far away. With WorldDetail.insides off the box is still there.
#   A real walk: the player walks in through the doorway.
# - The Void (tools/build_interiors.gd): every dome door in the town leads to a room that exists, each room has its
#   Entrance and a way back out to the right marker in town, and the Town Hall has Mr. Palmer's desk and the map.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_insides.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.insides_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.insides_test_backup.cfg"
const EARTH := "res://scenes/earth/earth.tscn"
const TOWN := "res://scenes/town/town.tscn"
const INSIDES := preload("res://scripts/insides.gd")
# Void rooms that are built so far (the rest of the town's doors still say "isn't open yet" until they are)
const VOID_ROOMS := ["town_hall", "cafe", "aquarium", "restaurant_and_cafe", "ninas_house", "clothing_boutique",
	"my_house", "observatory", "museum", "library", "potion_shop", "book_store", "pet_shop", "gaming_station",
	"dashs_house", "melanies_house", "empty_home_2", "haunted_house", "toy_store"]

# Shops whose fittings are all shelves and goods made in code (nothing there to bake)
const NO_BAKED := ["Corner Market", "Hardware Store"]

var failures := 0


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
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.on_earth = true
	clock.set_earth_time(12 * 60.0, true)
	var detail := root.get_node("WorldDetail")

	# --- Off: the old solid boxes
	detail.insides = false
	change_scene_to_file(EARTH)
	await _frames(16)
	var s := current_scene as Node3D
	for name in INSIDES.ROOMS:
		var g := s.get_node(name) as Node3D
		check(not g.has_meta(INSIDES.HOLLOW_META) and g.get_node_or_null("Room") == null, "%s: with insides off it's as built" % name)
		var mid := g.global_transform * Vector3(0, 1.0, 0)
		check(_solid_at(s, mid), "%s: and solid in the middle" % name)

	# --- On (the game's default)
	detail.insides = true
	change_scene_to_file(EARTH)
	await _frames(16)
	await create_timer(1.5).timeout
	s = current_scene as Node3D
	var occ := s.get_node_or_null("Town Occluders")
	for name in INSIDES.ROOMS:
		var spec: Dictionary = INSIDES.ROOMS[name]
		var size: Vector3 = spec.size
		var g := s.get_node(name) as Node3D
		var xf := g.global_transform
		check(g.has_meta(INSIDES.HOLLOW_META) and g.get_node_or_null("Room") != null, "%s is a room" % name)
		check(not _solid_at(s, xf * Vector3(0, 1.0, 0)), "%s: nothing solid in the middle of the room" % name)
		var hd := size.z / 2.0
		check(not _ray(s, xf * Vector3(0, 1.0, hd + 2.0), xf * Vector3(0, 1.0, hd - 2.0)), "%s: the doorway's open" % name)
		check(_ray(s, xf * Vector3(size.x * 0.35, 1.0, hd + 2.0), xf * Vector3(size.x * 0.35, 1.0, hd - 2.0)),
			"%s: the front wall's solid beside the doorway" % name)
		check(_ray(s, xf * Vector3(0, 1.5, -hd - 2.0), xf * Vector3(0, 1.5, -hd + 1.0)), "%s: the back wall's solid" % name)
		check(_ray(s, xf * Vector3(-size.x / 2 - 2.0, 1.5, 0), xf * Vector3(-size.x / 2 + 0.6, 1.5, 0)), "%s: the side walls are solid" % name)
		var floor_hit := _hit(s, xf * Vector3(0.1, size.y - 0.5, hd - 1.2), xf * Vector3(0.1, -1.0, hd - 1.2))
		check(floor_hit.has("position") and absf(floor_hit.position.y - xf.origin.y) < 0.3, "%s: a floor to stand on by the door" % name)
		check(_ray(s, xf * Vector3(0, size.y - 0.6, 0), xf * Vector3(0, size.y + 0.6, 0)), "%s: a ceiling" % name)
		var mms := g.find_children("*", "MultiMeshInstance3D", true, false)
		check(mms.size() >= 1 or name in NO_BAKED, "%s: baked furniture in it (%d sets)" % [name, mms.size()])
		var far_ok := true
		for n in g.get_node("Room").find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			if gi.layers != 0 and gi.visibility_range_end <= 0.0:
				far_ok = false
		check(far_ok, "%s: everything in the room stops drawing far away" % name)
		var lights := g.get_node("Room").find_children("*", "OmniLight3D", true, false)
		check(not lights.is_empty() and (lights[0] as OmniLight3D).distance_fade_enabled, "%s: lights inside (faded far away)" % name)
		check(g.get_node_or_null("Room/Music") != null and g.get_node("Room/Music").get("track") == "interior", "%s: its own music" % name)
		check(g.get_node_or_null("Inside") != null and g.get_node_or_null("Doorway") != null, "%s: Inside and Doorway markers" % name)
		if occ:
			var label_name: String = spec.get("label", name)
			check(occ.get_node_or_null(label_name) == null, "%s: no occluder inside it" % name)
		var merged := 0
		for n in g.get_node("Room").find_children("*", "MeshInstance3D", true, false):
			if n.has_meta("static_batch") and (n as MeshInstance3D).layers != 0:
				merged += 1
		check(merged > 0, "%s: its pieces are merged (%d meshes)" % [name, merged])
		if spec.has("shop"):
			var shop_ok := false
			for c in g.get_children():
				if c is Area3D and String(c.name).begins_with("Shop"):
					var lp: Vector3 = c.position
					shop_ok = absf(lp.x) < size.x / 2 - 0.3 and absf(lp.z) < hd - 0.3 and absf(lp.y - 1.0) < 0.5
			check(shop_ok, "%s: its shop counter's inside the room" % name)
	# The diner's furniture is solid: a booth's seat holds you up
	var diner := s.get_node("Hollow Diner") as Node3D
	var booths := diner.find_child("Booths", true, false) as MultiMeshInstance3D
	check(booths != null and booths.multimesh.instance_count == 8, "the diner has 8 booths")
	if booths:
		var b0: Transform3D = diner.global_transform * booths.transform * (booths.get_meta("transforms") as Array)[0]
		var seat := _hit(s, b0 * Vector3(0, 2.0, 0.05), b0 * Vector3(0, -0.5, 0.05))
		check(seat.has("position") and absf(seat.position.y - (b0.origin.y + 0.46)) < 0.1, "you can sit up on a booth's seat (%s, booth at %s)" % [str(seat.get("position")), str(b0.origin)])

	# A real walk in through the diner's door
	var player := s.find_child("Player", true, false) as CharacterBody3D
	var door := diner.get_node("Doorway") as Node3D
	var inside := diner.get_node("Inside") as Node3D
	player.global_position = door.global_position
	await _frames(4)
	var target := inside.global_position
	var walked := false
	for i in 240:
		var to := target - player.global_position
		to.y = 0
		if to.length() < 0.6:
			walked = true
			break
		Input.action_press("move_forward")
		_face(player, to)
		await physics_frame
	Input.action_release("move_forward")
	check(walked, "the player walks in through the diner's door (%.1f m short)" % (target - player.global_position).length())

	# --- The Void: every dome door goes somewhere that's built, or is listed as still to come
	change_scene_to_file(TOWN)
	await _frames(16)
	var town := current_scene
	for n in town.find_children("Door", "Area3D", true, false):
		var dest := String(n.get("destination"))
		if not dest.begins_with("res://scenes/interiors/"):
			continue
		var file := dest.get_file().get_basename()
		if file in VOID_ROOMS:
			check(ResourceLoader.exists(dest), "the %s door leads to a room" % file)
			var room := (load(dest) as PackedScene).instantiate()
			check(room.get_node_or_null("Entrance") != null, "%s: an Entrance to arrive at" % file)
			var exit := room.get_node_or_null("ExitToTown")
			check(exit != null and town.find_child(String(exit.get("spawn")), true, false) != null,
				"%s: its way out lands at its building in town" % file)
			room.free()
	# Every dome door leads to a room now: nothing says "isn't open yet"
	var unbuilt := []
	for n in town.find_children("Door", "Area3D", true, false):
		var dest2 := String(n.get("destination"))
		if dest2.begins_with("res://scenes/interiors/") and not ResourceLoader.exists(dest2):
			unbuilt.append(dest2.get_file())
	check(unbuilt.is_empty(), "every dome door in the Void has a room (missing: %s)" % str(unbuilt))
	# The Haunted House's door stays shut until its spirit's let out (the slide quest's knock)
	await _frames(8)
	var haunt: Area3D = null
	for n in town.find_children("Door", "Area3D", true, false):
		if String(n.get("destination")).ends_with("haunted_house.tscn"):
			haunt = n
	check(haunt != null and not haunt.monitoring, "the Haunted House's door is shut before its spirit's out")
	for id in ["museum", "library", "toy_store", "haunted_house"]:
		var r := (load("res://scenes/interiors/%s.tscn" % id) as PackedScene).instantiate()
		var meshes := r.find_children("*", "MeshInstance3D", true, false).size() + r.find_children("*", "MultiMeshInstance3D", true, false).size()
		check(meshes > 20 and r.find_children("*", "OmniLight3D", true, false).size() > 0, "%s is furnished and lit (%d meshes)" % [id, meshes])
		r.free()
	var hall := (load("res://scenes/interiors/town_hall.tscn") as PackedScene).instantiate()
	check(hall.find_child("Mayor Desk", true, false) != null, "Mr. Palmer's desk is in the Town Hall")
	check(hall.find_child("Town Map", true, false) != null, "and the town map on the wall")
	check(hall.find_child("Pendulum", true, false) != null, "and the great clock's pendulum")
	hall.free()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _face(player: Node3D, dir: Vector3) -> void:
	# Points the camera rig the way to go, so "forward" walks there
	var rig := player.get_node_or_null("SpringArm3D") as Node3D
	if rig == null:
		rig = player.find_child("SpringArm*", true, false) as Node3D
	if rig:
		rig.global_rotation.y = atan2(-dir.x, -dir.z)


func _hit(s: Node3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	return s.get_world_3d().direct_space_state.intersect_ray(q)


func _ray(s: Node3D, a: Vector3, b: Vector3) -> bool:
	return not _hit(s, a, b).is_empty()


func _solid_at(s: Node3D, p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	for h in s.get_world_3d().direct_space_state.intersect_point(q):
		if h.collider is StaticBody3D:
			return true
	return false


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
	quit()
