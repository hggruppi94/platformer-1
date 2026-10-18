extends SceneTree

# Checks the town's path graph (res://routines/places.json): what's underfoot at every point, that every link can be
# walked without going through a building or prop, and that every place can be reached from every other.
# Run it after moving points or adding links:
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/check_paths.gd

const TOWN := "res://scenes/town/town.tscn"
const SAVE := "user://save.json"
const BACKUP := "user://save.check_backup.json"

var problems := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Loading the town makes the game autosave: put your save aside and back afterwards. If a backup is already
	# there, an earlier run stopped before putting it back: that backup is your real save, so keep it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	root.get_node("Game")._resume = {}
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame
	await physics_frame
	await physics_frame
	var paths := TownPaths.get_shared()
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var skip := _skip_rids()
	print("Points (what's underfoot):")
	for name in paths.points:
		var p: Vector3 = paths.position_of(name, space, skip)
		var hit := _ray(space, Vector3(p.x, 80, p.z), Vector3(p.x, -20, p.z), skip)
		var what := _name(hit.get("collider")) if hit else "NOTHING"
		var bad := hit.is_empty() or not (what.contains("Ground") or what.contains("Boardwalk") or what.contains("Dock")
			or what.contains("Skate") or what.contains("TownSquare"))
		print("  %s %-16s y=%6.2f  on %s" % ["!!" if bad else "  ", name, p.y, what])
		if bad:
			problems += 1
	print("Links (anything in the way at knee and head height):")
	for l in paths.links:
		var a: Vector3 = paths.position_of(l[0], space, skip)
		var b: Vector3 = paths.position_of(l[1], space, skip)
		var blocked := []
		for h in [0.7, 1.5]:
			# Walk the link in short steps, following the ground, and look ahead for anything solid
			var steps := maxi(int(a.distance_to(b) / 2.0), 1)
			var prev := a
			for k in range(1, steps + 1):
				var q := a.lerp(b, float(k) / steps)
				var g := _ray(space, Vector3(q.x, q.y + 3, q.z), Vector3(q.x, q.y - 6, q.z), skip)
				if g:
					q.y = g.position.y
				var hit := _ray(space, prev + Vector3.UP * h, q + Vector3.UP * h, skip)
				if hit and not _name(hit.collider).contains("Ground"):
					var n := _name(hit.collider)
					if n not in blocked:
						blocked.append(n)
				prev = q
		var tag := "!!" if not blocked.is_empty() else "  "
		print("  %s %s - %s (%.0f m)%s" % [tag, l[0], l[1], a.distance_to(b), "  BLOCKED BY " + ", ".join(blocked) if blocked else ""])
		if not blocked.is_empty():
			problems += 1
	# Everything reachable from Nina's House
	var lonely := []
	for name in paths.points:
		if paths.route(name, "ninas_house").is_empty() and name != "ninas_house":
			lonely.append(name)
	print("Can't get there from Nina's House: %s" % [lonely])
	problems += lonely.size()
	print("RESULT %s (%d problems)" % ["OK" if problems == 0 else "PROBLEMS", problems])
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(problems)


func _skip_rids() -> Array[RID]:
	return TownPaths.skip_rids(current_scene)


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = skip
	return space.intersect_ray(q)


func _name(n: Object) -> String:
	if n == null:
		return "?"
	var node := n as Node
	return str(node.get_path()).replace(str(current_scene.get_path()) + "/", "")
