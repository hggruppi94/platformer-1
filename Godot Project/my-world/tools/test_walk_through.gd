extends SceneTree

# Checks the things Nina can walk through and the ground under her (scripts/soft_zone.gd, scripts/water.gd,
# scenes/town/foliage.gd, scripts/surfaces.gd, footsteps and landings in scenes/player/player.gd).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_walk_through.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const SOUNDS := ["rustle", "swish", "bloop", "boing", "fwump", "splash", "bubbles", "pop", "steam", "waterfall",
	"step_grass", "step_wood", "step_stone", "step_water", "step_cloud", "step_crystal", "zipline"]

var failures := 0
var town: Node3D
var player                     # the Player (untyped so its own functions can be called)
var space: PhysicsDirectSpaceState3D


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
	game.riding = false                                # on foot, whatever the save says (these checks are about walking)
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	for i in 5:
		await process_frame
	await _physics(3)
	town = current_scene as Node3D
	player = town.find_child("Player", true, false)
	space = town.get_world_3d().direct_space_state

	var missing := SOUNDS.filter(func(s: String) -> bool: return not ResourceLoader.exists("res://audio/sfx/%s.wav" % s))
	check(missing.is_empty(), "all the new sounds exist: missing %s" % [missing])

	# --- The ground under her and her footsteps ---
	await _stand(Vector3(5, 0, 62))
	check(player.ground_kind() == "grass", "on the grass: steps sound like %s" % player.ground_kind())
	await _stand(_top_of(town.find_child("Boardwalk South", true, false), Vector2(-7, 5)))
	check(player.ground_kind() == "wood", "on the boardwalk: %s" % player.ground_kind())
	await _stand(_top_of(town.find_child("TownSquare", true, false), Vector2(-12, -15)))
	check(player.ground_kind() == "stone", "on the Town Square: %s" % player.ground_kind())
	var normal := await _walk_speed(Vector3(5, 0, 62))
	check(normal > 4.0, "her normal walking speed: %.1f m/s" % normal)

	# A big mushroom cap: bouncy
	var cap := _big_mushroom_cap()
	check(cap != Vector3.INF, "found a big mushroom cap")
	player.global_position = cap + Vector3(0, 4.0, 0)
	player.velocity = Vector3.ZERO
	var bounced := false
	for i in 120:
		await physics_frame
		if player.velocity.y > 6.0:
			bounced = true
			break
	check(bounced, "landing on a big mushroom cap bounces her back up (boing)")

	# --- Clouds: soft and floaty ---
	var cloud := _zone("cloud", "Cloud Nest")
	player.global_position = cloud.global_position + Vector3(0, 0.5, 0)
	player.velocity = Vector3.ZERO
	await _physics(60)
	check(player.in_zone("cloud") and player.ground_kind() == "cloud", "standing in a Cloud Nest cloud: in it, steps go \"%s\"" % player.ground_kind())
	var cloud_speed := await _walk_speed(cloud.global_position + Vector3(0, 0.5, 0), 12)
	check(cloud_speed < normal * 0.85, "slower in a cloud: %.1f m/s (normal %.1f)" % [cloud_speed, normal])
	player.global_position = cloud.global_position + Vector3(0, 6.0, 0)
	player.velocity = Vector3.ZERO
	var fastest := 0.0
	var inside := 0
	for i in 90:
		await physics_frame
		inside = inside + 1 if player.in_zone("cloud") else 0
		if inside > 2:                                    # once she's properly in it
			fastest = maxf(fastest, -player.velocity.y)
	check(fastest > 0.0 and fastest <= 5.5, "falling into a cloud is floaty (fastest fall inside %.1f m/s)" % fastest)

	# --- The bubble bath: wade in ---
	var bath := _zone("bath", "Magic Bubble Bath")
	var tub := town.find_child("Magic Bubble Bath", true, false) as Node3D
	player.global_position = tub.global_position + Vector3(1.0, 2.5, 0.5)
	player.velocity = Vector3.ZERO
	await _physics(60)
	var feet: float = player.global_position.y - 0.8 - tub.global_position.y
	check(player.in_zone("bath") and feet > 0.4 and feet < 0.8, "she wades into the bubble bath waist-deep, feet on the tub floor (%.2f m up), not on the water (1.22)" % feet)
	var bath_speed := await _walk_speed(tub.global_position + Vector3(-1.0, 1.0, 0), 10, false)
	check(bath_speed < normal * 0.65, "slow wading in the bath: %.1f m/s" % bath_speed)
	check(bath != null, "the bath has its zone")

	# --- Hot springs: warm ---
	var spring := _zone("spring", "Hot Springs")
	root.get_node("Game").hp = root.get_node("Game").max_hp - 3
	player.global_position = spring.global_position + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	await create_timer(4.6).timeout
	var hp: int = root.get_node("Game").hp
	check(player.in_zone("spring") and hp >= root.get_node("Game").max_hp - 1, "a hot spring warms her HP back up (%d/%d)" % [hp, root.get_node("Game").max_hp])

	# --- The lake: wading in the shallows ---
	var shallow := _shallow_spot()
	await _stand(shallow)
	check(player.in_zone("water") and player.ground_kind() == "water", "wading into the lake's shallows: steps go \"%s\"" % player.ground_kind())
	var lake_speed := await _walk_speed(shallow, 8, false)
	check(lake_speed < normal * 0.8, "slower wading: %.1f m/s" % lake_speed)
	await _stand(Vector3(5, 0, 62))
	check(not player.in_zone("water") and not player.in_zone("cloud") and not player.in_zone("bath"), "back on dry land: no zones left on her")

	# --- Plants: she pushes through them, and they lean away ---
	var foliage := town.find_child("Foliage", true, false)
	var leaf := _plant_of(foliage, 0)
	var grass := _plant_of(foliage, 3)
	await _stand(leaf)
	await _nudge()
	check(0 in foliage.call("touching_kinds"), "pushing into giant leaves: she's in them (they rustle)")
	await _stand(grass)
	await _nudge()
	check(3 in foliage.call("touching_kinds"), "running through tall grass: she's in it (it swishes)")
	var np = RenderingServer.global_shader_parameter_get("nina_pos")
	if np == null:
		print("SKIP  the plants leaning away from her: needs a window (shows in the screenshots)")
	else:
		check((np as Vector3).distance_to(player.global_position) < 0.5, "the plants know where she is, to lean away from her")

	# --- Waterfalls: mist and a looping rush ---
	var rushes := town.find_child("Waterfalls", true, false).find_children("Rush*", "AudioStreamPlayer3D", false, false)
	var looping := rushes.filter(func(r: AudioStreamPlayer3D) -> bool:
		return r.playing and (r.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	check(rushes.size() >= 2 and looping.size() == rushes.size(), "the waterfalls rush on a loop (%d of %d)" % [looping.size(), rushes.size()])
	_finish()


# -----------------------------------------------------------------------------
func _zone(kind: String, under: String) -> Area3D:
	for z in town.find_child(under, true, false).find_children("*", "Area3D", true, false):
		if z.get("kind") == kind:
			return z
	return null


func _top_of(node: Node, xz: Vector2) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 30, xz.y), Vector3(xz.x, -10, xz.y))
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(xz.x, 0, xz.y)


func _big_mushroom_cap() -> Vector3:
	for b in town.find_child("Foliage", true, false).get_children():
		if b is StaticBody3D:
			var cs := b.get_child(0) as CollisionShape3D
			return cs.global_position + Vector3(0, (cs.shape as CylinderShape3D).height / 2.0, 0)
	return Vector3.INF


func _plant_of(foliage: Node, kind: int) -> Vector3:
	var pos: PackedVector3Array = foliage.get("positions")
	var kinds: PackedInt32Array = foliage.get("kinds")
	var sizes: PackedFloat32Array = foliage.get("sizes")
	for i in pos.size():
		if kinds[i] == kind and sizes[i] > 1.0 and Vector2(pos[i].x, pos[i].z).length() > 60:
			return pos[i]
	return Vector3.ZERO


func _shallow_spot() -> Vector3:
	# A point just inside the lake's south shore where the water is shallow enough to wade
	for z in range(17, 4, -1):
		var p := _top_of(town, Vector2(-30, z))
		if p.y < -0.9 and p.y > -1.6:
			return p
	return _top_of(town, Vector2(-30, 12))


func _stand(at: Vector3) -> void:
	var g := _top_of(town, Vector2(at.x, at.z)) if at.y == 0 else at
	player.global_position = g + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	await _physics(15)


func _nudge() -> void:
	# A couple of steps on the spot so she's moving through the plants
	player.velocity = Vector3(2.0, 0, 0)
	await _physics(2)
	player.velocity = Vector3(2.0, 0, 0)
	await _physics(2)


func _walk_speed(at: Vector3, frames := 30, reset := true) -> float:
	# Push forward (west) for a moment from `at` and measure how fast she goes
	if reset:
		await _stand(at)
	var arm := player.get_node("SpringArm3D") as Node3D
	arm.rotation.y = atan2(1.0, 0.0)                      # camera looking west
	Input.action_press("move_forward")
	await _physics(frames)
	var from: Vector3 = player.global_position
	await _physics(20)
	var moved := Vector2(player.global_position.x - from.x, player.global_position.z - from.z).length()
	Input.action_release("move_forward")
	await _physics(10)
	return moved / (20.0 / Engine.physics_ticks_per_second)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
