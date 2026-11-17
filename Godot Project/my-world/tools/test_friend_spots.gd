extends SceneTree

# Checks the friend spots and the Seam (scripts/friend_spots.gd): none before a world's mended or on a practice trip;
# one in each of five mended worlds, on the ground, with its chest out of reach; the Friend button by it calls in the
# friend it needs (whoever's along) and their real move opens it; then you really walk to the chest (up the Lonely
# Shard's bridge too) and it pays once; it stays open next visit; all five give the Friendship Circlet; and the Seam
# takes you from Glenmoor's hot spring to Lanternmoor and back, paying once.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_friend_spots.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.friend_spots_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.friend_spots_test_backup.cfg"
const WORLDS := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor"]

var failures := 0
var game: Node
var portals: Node
var party: Node
var dialogue: Node
var FS: GDScript
var p: CharacterBody3D
var world: Node3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _load(id: String) -> void:
	change_scene_to_file(str(portals.world(id).scene))
	await _frames(10)
	await _physics(20)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	FS = load("res://scripts/friend_spots.gd")
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	party = root.get_node("Party")
	dialogue = root.get_node("Dialogue")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals.home_calls.enabled = false
	root.get_node("Hidden").guardians = false

	# --- Not mended: nothing there ---
	portals.cleared_worlds.clear()
	await _load("shard_isle")
	check(get_nodes_in_group("friend_spots").is_empty(), "before Shard Isle's mended there's no friend spot")

	# --- Mended, everyone joined ---
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs"]:
		portals.cleared_worlds.append(w)
	dialogue.flags["make_taught"] = true
	for f in party.ORDER:
		party.join(f, true)
	check(FS.SPOTS.size() == 5, "five friend spots")
	var friends := {}
	for s in FS.SPOTS:
		friends[s.friend] = true
		check(party.friend(str(s.friend)).get("world", "") != s.world, "%s's friend isn't the one from its own world" % s.id)
	check(friends.size() == 5, "each needs a different friend")

	for id in WORLDS:
		if OS.has_environment("FS_ONLY") and OS.get_environment("FS_ONLY") != id:
			continue
		await _one_world(id)

	check(game.has_item("shop:" + FS.SET_HAT), "all five give the Friendship Circlet")
	check(FS.found_count() == 5, "all five found")

	# --- Next visit it's still open ---
	await _load("shard_isle")
	var again := get_nodes_in_group("friend_spots")
	check(again.size() == 1 and again[0].opened and again[0].find_children("Plank *", "", false, false).size() == 9,
		"next visit the Lonely Shard's bridge is still there")
	check(again.size() == 1 and str(again[0].chest.get_node("Spot").offer.call()) == "", "...and its chest is empty")

	# --- The Seam ---
	await _seam()

	# --- Practice trips have none ---
	portals.practice = true
	await _load("rootmind")
	check(get_nodes_in_group("friend_spots").is_empty(), "a practice trip has no friend spot")
	portals.practice = false
	_finish()


func _one_world(id: String) -> void:
	await _load(id)
	var spots := get_nodes_in_group("friend_spots")
	check(spots.size() == 1, "%s: one friend spot (%d)" % [id, spots.size()])
	if spots.is_empty() or p == null:
		return
	var spot = spots[0]
	var need := str(spot.info.friend)
	print("      %s at %s" % [spot.name, spot.global_position.snapped(Vector3.ONE * 0.1)])
	# On the ground
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(spot.global_position + Vector3(0, 0.8, 0), spot.global_position + Vector3(0, -1, 0))
	q.exclude = [p.get_rid()]
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf(hit.position.y - spot.global_position.y) < 0.6, "...its stone sits on the ground")
	check(not spot.opened and str(spot.chest.get_node("Spot").offer.call()) == "", "...shut, nothing to open yet")
	# Walking straight at the chest gets nowhere before it's open
	var chest_at: Vector3 = spot.chest.global_position
	# (where you'd come from: in front of it, or for the Lonely Shard, from the island behind its stone)
	var front: Vector3 = spot.global_transform * (Vector3(0, 0, -2.5) if id == "shard_isle" else Vector3(0, 0, 3.0))
	p.global_position = front + Vector3(0, 1.0, 0)
	await _physics(30)
	await _walk(chest_at, 6.0)
	check(_flat(p.global_position, chest_at) > 1.3 or absf(_feet() - chest_at.y) > 0.8,
		"...you can't get to the chest before it's open (%.1f m off, feet %.1f vs %.1f)" % [_flat(p.global_position, chest_at), _feet(), chest_at.y])
	# The name shows close up
	p.global_position = front + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	await _frames(3)
	check((spot.get_node("Friend Name") as Label3D).visible, "...close up the friend's name shows over the stone")
	# The Friend button calls the friend it needs
	party.with_you = "nina_bruno" if need != "nina_bruno" else "bramble"
	await _stand_for(spot)
	check(str(party.call("_who_for", p)) == need, "...the Friend button calls in %s (%s)" % [need, party.call("_who_for", p)])
	check(party.helper() == need, "...and the HUD's bubble shows them")
	var tries: int = FS.GROOVES if need == "melody" else 1
	for i in tries:
		party.use(p)
		await _physics(30)
	if need == "heather":
		await _physics(150)                    # (the rain, then the sun)
	if need == "bramble":
		await _physics(20)
	check(party.with_you == need, "...%s hopped in" % need)
	check(spot.opened and dialogue.flags.get(FS.flag_open(spot.info.id), false), "...their move opened it")
	if need == "bramble" and p.burrow.active:
		p.burrow.stop()
	await _physics(80)
	chest_at = spot.chest.global_position          # (the buried lantern's has come up)
	# Now walk to the chest and open it
	p.global_position = front + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(30)
	if id == "shard_isle":
		# Up the bridge: from the stone to the perch's rim, then to the chest
		await _walk(spot.global_transform * Vector3(0, 0, 0.5), 4.0)
		await _walk(spot.global_transform * Vector3(0, FS.PERCH_UP, FS.PERCH_OUT - 2.0), 12.0)
	await _walk(chest_at + (spot.chest.global_basis * Vector3(0, 0, 1.0)), 10.0)
	check(_flat(p.global_position, chest_at) < 1.8 and absf(_feet() - chest_at.y) < 0.8,
		"...then you can walk to the chest (%.1f m off, feet %.1f vs %.1f)" % [_flat(p.global_position, chest_at), _feet(), chest_at.y])
	var offer := str(spot.chest.get_node("Spot").offer.call())
	check(offer == "open the chest", "...it offers to open (%s)" % offer)
	var s0: int = game.sparkles
	spot.chest.get_node("Spot").act.call()
	var extra: int = FS.SET_SPARKLES if FS.found_count() == 5 else 0
	check(game.sparkles == s0 + FS.SPARKLES + extra, "...+%d sparkles (%d)" % [FS.SPARKLES + extra, game.sparkles - s0])
	check(not spot.open_chest() and game.sparkles == s0 + FS.SPARKLES + extra, "...only once")


func _seam() -> void:
	game.pending_message = ""
	await _load("glenmoor")
	var seam := get_nodes_in_group("seam")
	check(seam.size() == 1, "Glenmoor has the Seam behind the hot spring (%d)" % seam.size())
	if seam.is_empty():
		return
	var g := seam[0] as Node3D
	var spot = get_nodes_in_group("friend_spots")[0]
	var local: Vector3 = spot.global_transform.affine_inverse() * g.global_position
	check(absf(local.x) < 3.0 and local.z < -2.5 and local.z > -7.0, "...inside the nook (%s)" % local.snapped(Vector3.ONE * 0.1))
	var s0: int = game.sparkles
	FS.go_through("glenmoor")
	await _frames(20)
	await _physics(60)
	check(current_scene.scene_file_path == str(portals.world("lanternmoor").scene), "through the Seam to Lanternmoor")
	check(portals.here == "lanternmoor", "...counted as being in Lanternmoor")
	check(game.sparkles == s0 + FS.SEAM_SPARKLES and dialogue.flags.get("seam_found", false), "...+%d sparkles the first time" % FS.SEAM_SPARKLES)
	p = get_first_node_in_group("player") as CharacterBody3D
	var back := get_nodes_in_group("seam")
	check(back.size() == 1, "...and a twin crack there leads back")
	if back.size() == 1 and p:
		check(_flat(p.global_position, (back[0] as Node3D).global_position) < 5.0, "...you came out beside it")
		var lspot = get_nodes_in_group("friend_spots")[0]
		check(lspot.global_position.distance_to((back[0] as Node3D).global_position) < 9.0, "...by the buried lantern")
	await _physics(60)
	check(p != null and p.is_on_floor(), "...standing on the ground")
	FS.go_through("lanternmoor")
	await _frames(20)
	await _physics(60)
	check(current_scene.scene_file_path == str(portals.world("glenmoor").scene), "back through to Glenmoor")
	check(game.sparkles == s0 + FS.SEAM_SPARKLES, "...nothing more the second time")


func _stand_for(spot: Node3D) -> void:
	# Stand where the move works on it, facing it
	var at: Vector3 = spot.global_transform * Vector3(0, 0, 1.4)
	match str(spot.info.id):
		"lonely_shard":
			at = spot.global_transform * Vector3(0, 0, -1.0)
		"buried_lantern":
			at = spot.global_transform * Vector3(0, 0, -2.0)    # (on its soft soil)
		"hot_spring":
			at = spot.global_transform * Vector3(0, 0, 2.5)
		"sleepy_bud":
			at = spot.global_transform * Vector3(0, 0, 0.6)
		"ice_chest":
			at = spot.global_transform * Vector3(0, 0, -0.6)
	p.global_position = at + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	var vis := p.get_node("Visual") as Node3D
	var to: Vector3 = spot.target() - at
	vis.global_rotation.y = atan2(to.x, to.z)
	await _physics(30)


func _walk(to: Vector3, seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame
		game.hp = 10
		var want := to - p.global_position
		want.y = 0
		if want.length() < 0.6:
			break
		_steer(want.normalized())
		if OS.has_environment("FS_DEBUG") and i % 20 == 0:
			print("        at ", p.global_position.snapped(Vector3.ONE * 0.1), " to ", to.snapped(Vector3.ONE * 0.1), " floor ", p.is_on_floor())
	_release()
	await _physics(10)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _feet() -> float:
	var shape := (p.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	return p.global_position.y - shape.height / 2.0


func _steer(want: Vector3) -> void:
	var b: Basis = p.get_node("SpringArm3D").global_transform.basis
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
	var ix := rgt.dot(want)
	var iy := -fwd.dot(want)
	_release()
	if ix > 0:
		Input.action_press("move_right", ix)
	else:
		Input.action_press("move_left", -ix)
	if iy > 0:
		Input.action_press("move_back", iy)
	else:
		Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	_release()
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
