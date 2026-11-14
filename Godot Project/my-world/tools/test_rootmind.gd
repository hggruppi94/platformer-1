extends SceneTree

# Checks the Rootmind, Bramble's portal world (scripts/rootmind.gd, scenes/portal_worlds/rootmind.tscn): its quake
# waits for Shard Isle to be mended and Bramble's Harvest to have begun, then its portal rises on the Secret Gardens
# hill on flat, clear ground; inside, Bramble's there to talk to, the leaf climb is all easy jumps up to the High
# Bloom, the leaf slide brings you down, the tall grass bends away from you, every plant's eyes watch you and blink
# together, the seedling shrinks; the Thornknot can't be calmed before the three Sun Blooms are awake, then only when
# the hive blinks (by Interact or a bubble), and lashes thorn rings in between; calming its three knots mends the
# world (its reward, the seedling grows, the giant flowers open) and watching flowers spring up in the Void round the
# portal and your garden (not in front of the gate); and what you've done stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_rootmind.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.rootmind_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rootmind_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/rootmind.tscn"

var failures := 0
var game: Node
var portals: Node
var rem: Node
var quests: Node
var clock: Node


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
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	portals.home_calls.enabled = false      # (this world on its own: no pull home to Stars Hollow, test_home_calls.gd)
	rem = root.get_node("Remnants")
	quests = root.get_node("Quests")
	clock = root.get_node("Clock")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	portals.quakes.append("shard_isle")

	check(ResourceLoader.exists(WORLD) and portals.is_built("rootmind"), "the Rootmind's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_thornknot()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("rootmind"), "no Rootmind quake before Shard Isle is mended")
	portals.cleared_worlds.append("shard_isle")
	check(not portals.quake_due("rootmind"), "...nor before Bramble's Harvest has begun")
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	check(portals.next_due() == "rootmind", "then the Rootmind's quake is due")
	portals.quake("rootmind", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal rootmind") as Node3D
	check(p != null and portals.is_open("rootmind"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("rootmind")
	var ground: Vector3 = rem.ground_at(w.at + Vector2(3.0, 0.0))      # (beside the crack: its middle is a hole)
	check(absf(p.global_position.y - ground.y) < 0.05 and ground.y > 10.0, "...up on the Secret Gardens hill (y %.1f)" % ground.y)
	var worst := 0.0
	for k in 12:
		var a := k * TAU / 12.0
		worst = maxf(worst, absf(rem.ground_at(w.at + Vector2(cos(a), sin(a)) * 5.5).y - ground.y))
	check(worst < 0.4, "...on flat ground (worst step %.2f)" % worst)
	var garden: Vector2 = root.get_node("Farm").GARDEN
	check(garden.distance_to(w.at) > 9.0 and garden.distance_to(w.at) < 18.0, "...near your garden but not on it (%.1f m)" % garden.distance_to(w.at))
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	q.shape = sphere
	q.transform = Transform3D(Basis(), p.global_position + Vector3(0, 3.5, 0))
	var others := space.intersect_shape(q, 16).filter(func(h: Dictionary) -> bool:
		var c: Node = h.collider
		return not p.is_ancestor_of(c) and not c.is_in_group("player"))
	check(others.is_empty(), "nothing else stands in the portal's way (%d)" % others.size())
	check(portals._portal_offer("rootmind") == "look down the crack to The Rootmind", "it offers a trip to the Rootmind")


func _check_inside() -> void:
	portals.enter("rootmind")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "rootmind", "stepping through takes you to the Rootmind")
	for n in ["WayHome/Way Home/Spot", "Vein1/Remnant Vein/Spot", "Bloom1/Spot",
			"Bloom2/Spot", "Bloom3/Spot", "Slide/Spot", "Bramble/Spot", "Bramble/Model", "Seedling/Sprout",
			"Thornknot/Tangle/Knot0/Spot", "Thornknot/Tangle/Knot2/Hit"]:
		check(s.get_node_or_null(n) != null, "the Rootmind has %s" % n)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	var lines: Array = s.bramble_lines()
	check(lines.size() == 3 and "Sun Blooms" in str(lines[2]), "Bramble says what to do (%s)" % str(lines[0]).left(40))
	# Everything stands on something
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["Bloom1", "Bloom2", "Bloom3", "Vein1", "Bramble"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.0, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	check(_climb_ok(s), "the leaf climb is all easy jumps, with room to stand on every leaf")
	# The leaf slide
	player.global_position = (s.get_node("Slide") as Node3D).global_position + Vector3(0, 0.3, 0)
	s.get_node("Slide/Spot").use()
	await create_timer(0.4).timeout
	check(not player.is_physics_processing(), "riding the leaf slide")
	await create_timer(s.SLIDE_TIME).timeout
	await _physics(4)
	check(player.is_physics_processing() and player.global_position.y < 1.5 and Vector2(player.global_position.x, player.global_position.z).length() < 14.0,
		"...brings you down near the Heart Glade (%s)" % player.global_position)
	# The tall grass bends away
	var meadow := s.get_node("Tall Meadow") as Node3D
	var blade := meadow.get_child(0) as Node3D
	player.global_position = blade.global_position + Vector3(0.6, 0.5, 0)
	await _frames(3)
	check(Vector2(blade.rotation.x, blade.rotation.z).length() > 0.2, "the tall grass bends away as you brush through")
	# Eyes watch you and blink together
	var plant := s.get_node("Eyeplants").get_child(0) as Node3D
	player.global_position = plant.global_position + Vector3(4, 0.5, 0)
	await _frames(40)
	var head := plant.get_node("Head") as Node3D
	check(absf(wrapf(head.rotation.y - PI / 2.0, -PI, PI)) < 0.3, "the plants turn their eyes to watch you")
	var blinked := false
	for i in 300:
		await process_frame
		if (head.get_node("EyeL") as Node3D).scale.y < 0.5:
			blinked = true
			break
	check(blinked, "...and blink with the hive")
	check((s.get_node("Seedling/Sprout") as Node3D).scale.x < 1.0, "the seedling is shrinking back into a seed")
	check(not (s.get_node("Giant Buds").get_child(0).get_node("Open") as Node3D).visible, "the giant flowers are shut")


func _climb_ok(s: Node) -> bool:
	# Each leaf up the stem is a short, low jump from the one before, and none is right over another to bump your head
	var leaves: Array = []
	for c in s.get_node("Leaf Climb").get_children():
		if str(c.name).begins_with("Leaf"):
			leaves.append(c)
	if leaves.size() < 8:
		return false
	leaves.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.position.y < b.position.y)
	if (leaves[0] as Node3D).position.y > 1.3:
		print("  first leaf too high")
		return false
	for i in leaves.size():
		var a := leaves[i] as Node3D
		if i > 0:
			var b := leaves[i - 1] as Node3D
			var gap := Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() - 3.2
			if a.position.y - b.position.y > 1.4 or gap > 1.5:
				print("  leaf %d: rise %.2f, gap %.2f" % [i, a.position.y - b.position.y, gap])
				return false
		for j in range(i + 1, leaves.size()):
			var o := leaves[j] as Node3D
			var flat := Vector2(a.position.x - o.position.x, a.position.z - o.position.z).length()
			if flat < 3.0 and o.position.y - a.position.y < 2.3:
				print("  leaf %d is under leaf %d" % [i, j])
				return false
	var bloom := (s.get_node("Bloom1") as Node3D).position
	return bloom.y > 8.0


func _check_thornknot() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(s.get_node("Thornknot/Tangle/Knot0/Spot").what() == "look at the thorny tangle", "the Thornknot just sits there before the blooms wake")
	s.get_node("Thornknot/Tangle/Knot0/Spot").use()
	check(s.knots_calm() == 0, "...and can't be calmed yet")
	check(s.get_node("Bloom1/Spot").what() == "wake the High Bloom", "the blooms can be woken")
	for i in 3:
		s.get_node("Bloom%d/Spot" % (i + 1)).use()
	check(s.blooms_awake() == 3 and portals.has_found("rootmind", "bloom_2"), "all three Sun Blooms awake, and remembered")
	check(s.get_node("Bloom1/Spot").what() == "", "...a woken bloom has nothing more to do")
	check("Thornknot" in str(s.bramble_lines()[0]), "Bramble says what to do about the Thornknot")
	player.global_position = Vector3(0, 0.6, 8.0)
	await _physics(3)
	await _frames(2)
	check(s.calming, "walking up to it starts the calming")
	# Out of step it won't listen; it lashes thorns instead
	s._t = floor(s._t / s.HIVE_BEAT) * s.HIVE_BEAT + s.HIVE_BEAT + 2.0
	await _frames(1)
	check(s.glowing_knot() == -1, "between the hive's blinks no knot glows")
	check(s.knot_hit(0) == "bounce" and s.knots_calm() == 0, "...and humming along then does nothing")
	s._t += s.LASH_AT - 2.0 + 0.05
	await _frames(2)
	check(s.get_node_or_null("ShockRing") != null, "out of step, it lashes a ring of thorns to jump")
	# In step, each knot calms in turn: by Interact, and by a bubble from the Star Popper
	for n in 3:
		s._t = floor(s._t / s.HIVE_BEAT) * s.HIVE_BEAT + s.HIVE_BEAT + 0.3
		await _frames(2)
		var k: int = s.glowing_knot()
		check(k >= 0, "when the hive blinks a knot glows (%d)" % k)
		if k < 0:
			return
		if n == 1:
			var hit := s.get_node("Thornknot/Tangle/Knot%d/Hit" % k)
			check(hit.shot(1, Vector3.ZERO, Vector3.FORWARD) == "hit", "a bubble on the glowing knot calms it")
		else:
			check(s.get_node("Thornknot/Tangle/Knot%d/Spot" % k).what() == "hum along with the hive", "its spot offers humming along")
			var r0: int = rem.count
			s.get_node("Thornknot/Tangle/Knot%d/Spot" % k).use()
			if n == 2:
				check(rem.count == r0 + int(portals.world("rootmind").reward_remnants), "the last knot mends the Rootmind, with its reward")
		check(s.knot_calm(k), "knot %d is calm" % k)
	check(portals.is_cleared("rootmind") and not s.calming, "the Thornknot has rejoined the hive")
	await _frames(60)
	check((s.get_node("Seedling/Sprout/Sapling") as Node3D).visible and (s.get_node("Seedling/Sprout") as Node3D).scale.x > 1.2, "the seedling grows into a sapling")
	check((s.get_node("Giant Buds").get_child(0).get_node("Open") as Node3D).visible, "the giant flowers open")
	check((s.get_node("Thornknot/Tangle/Flowers") as Node3D).visible, "the Thornknot is covered in flowers")
	check("Thank you" in str(s.bramble_lines()), "Bramble thanks you")


func _check_home() -> void:
	portals.go_home()          # (the way home: there's no time limit to run out any more)
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "the way home takes you home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal rootmind") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by the Rootmind's portal (%s, %s)" % [player.global_position, p.global_position if p else Vector3.ZERO])
	var flowers := current_scene.get_node_or_null("Portals/Watching Flowers")
	check(flowers != null and flowers.get_child_count() >= 14, "watching flowers have sprung up (%d)" % (flowers.get_child_count() if flowers else 0))
	if flowers == null:
		return
	var farm := root.get_node("Farm")
	var gate: Vector2 = farm.GARDEN + Vector2(0, farm.plot_half().x)
	var by_garden := 0
	var clear_gate := true
	for f in flowers.get_children():
		var at := Vector2((f as Node3D).global_position.x, (f as Node3D).global_position.z)
		if at.distance_to(farm.GARDEN) < 9.0:
			by_garden += 1
		if at.distance_to(gate) < 1.4:
			clear_gate = false
	check(by_garden >= 5 and clear_gate, "...along your garden (%d), keeping its gate clear" % by_garden)
	var head := flowers.get_child(0).get_node("Head") as Node3D
	player.global_position = head.global_position + Vector3(0, 0, 5)
	await _frames(60)
	check(absf(wrapf(head.rotation.y, -PI, PI)) < 0.4, "...and they turn to watch you")
	portals.enter("rootmind")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.blooms_awake() == 3 and s.knots_calm() == 3, "going back, it's all still done")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("rootmind") and portals.found == found and portals.is_open("rootmind"), "the Rootmind's progress loads back")


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
