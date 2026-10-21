extends SceneTree

# Checks the tree house steps, the zipline and the castle walls (tools/build_town.gd, scripts/zipline.gd).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_quick_fixes.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const MAX_RISE := 0.9          # a comfortable hop (her jump reaches about 1.8 m)
const MAX_GAP := 2.0           # edge to edge
const HEADROOM := 2.0          # clear space needed above a step (she's about 1.6 m tall)

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame
	await _physics(3)
	var town := current_scene as Node3D
	var space := town.get_world_3d().direct_space_state
	var player := town.find_child("Player", true, false) as CharacterBody3D
	var tree_house := town.find_child("Tree House", true, false) as Node3D

	# --- 1. The tree house steps: clear overhead, small hops, the last one meets the deck ---
	var steps: Array[StaticBody3D] = []
	var deck: StaticBody3D = null
	for b in tree_house.get_children():
		if b is StaticBody3D:
			var shape := (b.get_child(0) as CollisionShape3D).shape
			if shape is BoxShape3D and is_equal_approx((shape as BoxShape3D).size.y, 0.25):
				steps.append(b)
			elif shape is CylinderShape3D and is_equal_approx((shape as CylinderShape3D).radius, 4.5):
				deck = b
	steps.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.y < b.global_position.y)
	check(steps.size() >= 6 and deck != null, "found %d steps and the deck" % steps.size())
	var deck_top := deck.global_position.y + 0.2
	var no_room := []
	var big_hops := []
	for k in steps.size():
		var top := steps[k].global_position + Vector3.UP * 0.13
		var q := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.05, top + Vector3.UP * HEADROOM)
		q.exclude = [steps[k].get_rid()]
		var hit := space.intersect_ray(q)
		if hit:
			no_room.append("step %d (hits %s %.1f m up)" % [k + 1, hit.collider.get_parent().name, hit.position.y - top.y])
		if k > 0:
			var prev := steps[k - 1].global_position
			var rise := steps[k].global_position.y - prev.y
			var flat := Vector2(steps[k].global_position.x - prev.x, steps[k].global_position.z - prev.z).length() - 1.4
			if rise > MAX_RISE or flat > MAX_GAP:
				big_hops.append("step %d: %.2f m up, %.2f m across" % [k + 1, rise, flat])
	check(no_room.is_empty(), "room to stand on every step (the old ones were under the deck): %s" % [no_room])
	check(big_hops.is_empty(), "every step is a small hop up from the last: %s" % [big_hops])
	var last := steps[-1].global_position + Vector3.UP * 0.13
	check(absf(last.y - deck_top) < 0.15, "the top step is level with the deck (%.2f m off)" % (last.y - deck_top))

	# Standing on the top step and walking toward the trunk takes her onto the deck and to the happy place
	player.global_position = last + Vector3.UP * 1.0
	player.velocity = Vector3.ZERO
	await _physics(20)
	check(player.is_on_floor() and absf(player.global_position.y - (last.y + 0.8)) < 0.4,
		"Nina can stand on the top step (y %.2f)" % player.global_position.y)
	# The happy place is on the deck too, round the trunk: from the deck beside it, walk in
	var happy := town.find_child("HappyPlace Tree House", true, false) as Node3D
	player.global_position = tree_house.global_position + Vector3(3.6, 0, -0.6) + Vector3.UP * (deck_top - tree_house.global_position.y + 1.0)
	await _physics(10)
	await _walk(player, _flat(happy.global_position - player.global_position), 25)
	check(player.global_position.y > deck_top + 0.5 and player.is_on_floor(), "...and walk onto the deck (y %.2f)" % player.global_position.y)
	check(game.has_item("happy_place:tree_house"), "...and reach the tree house happy place (Nina at %s, happy place at %s)" % [
		player.global_position - tree_house.global_position, happy.global_position - tree_house.global_position])

	# --- 2. The zipline: Interact at the handle, ride down, let go at the landing ---
	var zip := tree_house.find_child("Zipline", false, false) as Area3D
	var zip_end := tree_house.find_child("ZipEnd", false, false) as Node3D
	player.global_position = zip.global_position + Vector3(0.6, 0.2, 0.6)
	await _physics(10)
	check(zip.get_node("Prompt").visible, "by the handle: \"%s\"" % zip.get_node("Prompt").text)
	_press("interact")
	await _physics(4)
	check(zip.is_riding() and player.get("carried"), "Interact grabs the handle and she rides")
	var lowest_gap := INF
	var lowest_what := ""
	for i in 600:
		await physics_frame
		if not zip.is_riding():
			break
		var g := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3.DOWN * 40)
		g.exclude = [player.get_rid()]
		var hit := space.intersect_ray(g)
		if hit and player.global_position.y - 0.8 - hit.position.y < lowest_gap:
			lowest_gap = player.global_position.y - 0.8 - hit.position.y
			lowest_what = str((hit.collider as Node).get_path()).replace(str(current_scene.get_path()) + "/", "")
			lowest_what += " at %s, Nina at %s (local to the tree %s), shape %s" % [hit.position, player.global_position,
				player.global_position - tree_house.global_position, (hit.collider as Node).get_child(0).shape]
	check(not zip.is_riding(), "...all the way to the bottom")
	check(lowest_gap > -0.2, "...without going through anything (lowest %.1f m above %s)" % [lowest_gap, lowest_what])
	await _physics(90)
	var landed := Vector2(player.global_position.x - zip_end.global_position.x, player.global_position.z - zip_end.global_position.z).length()
	check(player.is_on_floor() and landed < 4.0, "she lands on the ground by the landing post (%.1f m from it)" % landed)
	check(not player.get("carried") and not player.get("input_locked"), "...and can move again")
	check(current_scene.scene_file_path == TOWN, "...still in town")

	# --- 3. The castle: every part joined to the main building ---
	var groups := _castle_groups(town.get_node("Castle School"))
	check(groups == 1, "the castle is one connected building (%d separate pieces)" % groups)
	_finish()


func _castle_groups(castle: Node) -> int:
	# Group the castle's meshes into pieces that touch (bounding boxes overlapping, 0.15 m slack); signs don't count
	var boxes: Array[AABB] = []
	for m in castle.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is QuadMesh or str(m.get_path()).contains("Sign"):
			continue
		boxes.append(((m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()).grow(0.15))
	var parent := range(boxes.size())
	var find := func(i: int) -> int:
		while parent[i] != i:
			i = parent[i]
		return i
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].intersects(boxes[j]):
				var a: int = find.call(i)
				var b: int = find.call(j)
				if a != b:
					parent[a] = b
	var roots := {}
	for i in boxes.size():
		roots[find.call(i)] = true
	return roots.size()


func _walk(player: CharacterBody3D, dir: Vector3, frames: int) -> void:
	# Push forward with the camera turned to face `dir`
	var arm := player.get_node("SpringArm3D") as Node3D
	arm.rotation.y = atan2(-dir.x, -dir.z)
	Input.action_press("move_forward")
	await _physics(frames)
	Input.action_release("move_forward")
	await _physics(10)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z).normalized()


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
