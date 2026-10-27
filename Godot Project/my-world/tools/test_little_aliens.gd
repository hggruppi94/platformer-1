extends SceneTree

# Checks the little aliens (scripts/little_aliens.gd, little_alien.gd, mini_saucer.gd): the town gets its crowd of
# walkers, saucers and jetpack floaters in all seven colours; walkers stand on real surfaces (ground, roofs and walls,
# never the lake bed or the town's invisible edge walls) and keep to them as they wander; saucers stay over the town
# and out of the ground; nothing of theirs can block the player; and walkers left far behind turn up near the player.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_little_aliens.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var crowd := town.find_child("LittleAliens", true, false) as Node3D
	check(crowd != null, "the town has its little aliens")
	if crowd == null:
		_end()
		return
	var walkers: Array[Node3D] = []
	var flyers: Array[Node3D] = []
	for c in crowd.get_children():
		if c.name.begins_with("LittleAlien"):
			walkers.append(c)
		else:
			flyers.append(c)
	check(walkers.size() == crowd.walkers, "%d little aliens walk about" % walkers.size())
	check(flyers.size() == crowd.saucers + crowd.jetpacks, "%d fly (%d saucers, %d on jetpacks)" % [flyers.size(),
		crowd.saucers, crowd.jetpacks])
	var colours := {}
	for w in walkers:
		colours[w.scene_file_path.get_file()] = true
	check(colours.size() == 7, "all seven colours are out (%s)" % ", ".join(colours.keys()))
	var anim := walkers[0].find_child("AnimationPlayer", true, false) as AnimationPlayer
	var moves := ["idle", "walk", "run", "sit", "float", "wave"]
	check(anim != null and moves.all(func(a: String) -> bool: return anim.has_animation(a)),
		"they can idle, walk, run, sit, float and wave")

	# --- Nothing of theirs is solid ---
	var solid := crowd.find_children("*", "CollisionObject3D", true, false)
	check(solid.is_empty(), "nothing of theirs can block the player")

	# --- Everyone's standing on something real ---
	_report(walkers, "at the start")

	# --- They keep to their surfaces as they wander ---
	var before := walkers.map(func(w: Node3D) -> Vector3: return w.global_position)
	p.global_position = Vector3(40, 3, 40)                    # out of the way of most of them
	for w in walkers:
		w.visible = true
	await create_timer(8.0).timeout
	var moved := 0
	for i in walkers.size():
		if walkers[i].global_position.distance_to(before[i]) > 0.5:
			moved += 1
	check(moved >= walkers.size() / 3, "they wander about (%d of %d moved in 8 s)" % [moved, walkers.size()])
	_report(walkers, "after wandering")

	# --- Saucers stay over the town and out of the ground ---
	var ok_air := true
	var space := town.get_world_3d().direct_space_state
	var flew := 0
	var starts := flyers.map(func(f: Node3D) -> Vector3: return f.global_position)
	await create_timer(4.0).timeout
	for i in flyers.size():
		var f := flyers[i]
		if f.global_position.distance_to(starts[i]) > 1.0:
			flew += 1
		var at := f.global_position
		var inside: bool = Rect2(crowd.area).has_point(Vector2(at.x, at.z))
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.UP * 200)
		var buried := not space.intersect_ray(q).is_empty() and at.y < 0.0
		if not inside or buried or at.y < -1.0:
			ok_air = false
			print("    %s at %s" % [f.name, at])
	check(flew >= flyers.size() / 2, "the saucers and floaters fly about (%d of %d)" % [flew, flyers.size()])
	check(ok_air, "...over the town, never under the ground")

	# --- Walkers left far behind turn up near the player ---
	p.global_position = Vector3(-120, 5, -230)                # a far corner
	await create_timer(12.0).timeout
	var near := walkers.filter(func(w: Node3D) -> bool: return w.global_position.distance_to(p.global_position) < 70.0)
	check(near.size() >= 6, "walk to a far corner and some come along to it (%d nearby)" % near.size())
	_end()


func _report(walkers: Array[Node3D], when: String) -> void:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var floating := 0
	var walls := 0
	var roofs := 0
	var lake := 0
	for w in walkers:
		var up: Vector3 = w.up
		var q := PhysicsRayQueryParameters3D.create(w.global_position + up * 0.3, w.global_position - up * 0.3)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or not LittleAliens.walkable(hit):
			floating += 1
			print("    %s isn't on anything at %s (up %s)" % [w.name, w.global_position, up])
			continue
		if up.y < 0.5:
			walls += 1
		elif not str(hit.collider.get_path()).contains("Terrain"):
			roofs += 1
		if w.global_position.y < -0.45 and str(hit.collider.get_path()).contains("Terrain"):
			lake += 1
	check(floating == 0, "%s every walker stands on something (%d walls, %d roofs and tops, %d floating)" % [
		when, walls, roofs, floating])
	check(lake == 0, "%s none of them are on the lake bed" % when)


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
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
