extends SceneTree

# Checks the Frozen Moment, Flurry's portal world (scripts/frozen_moment.gd, scenes/portal_worlds/frozen_moment.tscn):
# its quake waits for the Rootmind to be mended, then its portal rises at the foot of the mountains on flat, clear
# ground; inside, Flurry's there and says what to do; the snow hangs still and the sky clock's stuck; the lake's ice is
# slippery and the snow drifts slow you down; the ice slide brings you down off Snowball Hill; each frozen moment
# takes three chips (Interact or a bubble) to thaw; the Frost Gloop stays frozen until all three are thawed, then
# wakes when you come near; popping it mends the world (its reward, falling snow, a ticking clock) without counting as
# popping the Gloop King; and what you've done stays done after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_frozen_moment.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.frozen_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.frozen_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/frozen_moment.tscn"

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
	quests.state[rem.QUEST] = {"step": 0, "done": false, "since_day": 1}
	for w in ["shard_isle", "rootmind"]:
		portals.quakes.append(w)
	portals.cleared_worlds.append("shard_isle")

	check(ResourceLoader.exists(WORLD) and portals.is_built("frozen_moment"), "the Frozen Moment's scene is built")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	await _check_quake()
	await _check_inside()
	await _check_ground()
	await _check_moments()
	await _check_gloop()
	await _check_home()
	_check_saving()
	_finish()


func _check_quake() -> void:
	check(not portals.quake_due("frozen_moment"), "no Frozen Moment quake before the Rootmind is mended")
	portals.cleared_worlds.append("rootmind")
	check(portals.next_due() == "frozen_moment", "then its quake is due")
	portals.quake("frozen_moment", true)
	await _frames(4)
	var p := current_scene.get_node_or_null("Portals/Portal frozen_moment") as Node3D
	check(p != null and portals.is_open("frozen_moment"), "its portal rises in the Void")
	if p == null:
		return
	var w: Dictionary = portals.world("frozen_moment")
	var ground: Vector3 = rem.ground_at(w.at + Vector2(3.0, 0.0))      # (beside the crack: its middle is a hole)
	check(absf(p.global_position.y - ground.y) < 0.05, "...standing on the ground")
	check(w.at.y < -200.0, "...far north, at the foot of the mountains (z %d)" % w.at.y)
	var worst := 0.0
	for k in 12:
		var a := k * TAU / 12.0
		worst = maxf(worst, absf(rem.ground_at(w.at + Vector2(cos(a), sin(a)) * 5.5).y - ground.y))
	check(worst < 0.4, "...on flat ground (worst step %.2f)" % worst)
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
	check(portals._portal_offer("frozen_moment") == "look down the crack to The Frozen Moment", "it offers a trip to the Frozen Moment (%s)" % portals._portal_offer("frozen_moment"))


func _check_inside() -> void:
	portals.enter("frozen_moment")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD and portals.here == "frozen_moment", "stepping through takes you to the Frozen Moment")
	for n in ["WayHome/Way Home/Spot", "Vein1/Remnant Vein/Spot", "Moment1/Spot",
			"Moment2/Moment/Shell/Hit", "Moment3/Spot", "Slide/Spot", "Flurry/Spot", "Flurry/Model", "FrostGloop/Ice Block",
			"The Frost Gloop", "Clock/Sky Clock/Second", "Snowflakes"]:
		check(s.get_node_or_null(n) != null, "the Frozen Moment has %s" % n)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you arrive at the way in")
	var first: Array = s.flurry_lines()
	check("Flurry" in str(first[0]) and "Three moments" in " ".join(first), "Flurry says hello and what's frozen")
	var next: Array = s.flurry_lines()
	check("Still frozen" in " ".join(next), "...and after that, what's left")
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["Moment1", "Moment2", "Moment3", "FrostGloop", "Vein1", "Flurry", "Slide"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	# Time's stopped: the snow hangs still and the clock's second hand never gets past its tick
	var flakes: Array = s._flakes.duplicate()
	var hand := s.get_node("Clock/Sky Clock/Second") as Node3D
	var turned := 0.0
	for i in 60:
		await process_frame
		turned = maxf(turned, absf(hand.rotation.z + 0.9))
	check(s._flakes == flakes and not s.snow_falling(), "the snowflakes hang still in the air")
	check(turned < 0.1 and not s.clock_ticking(), "the sky clock's stuck on one tick")


func _check_ground() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	# The lake's ice is slippery: let go and you slide on; on snow you stop
	var glide_ice := await _glide(player, Vector3(0, 0.5, 6))
	check(player.on_ice(), "the frozen lake is ice")
	var glide_snow := await _glide(player, Vector3(-30, 0.5, 26))
	check(not player.on_ice(), "...the snowfield isn't")
	check(glide_ice > 2.0 and glide_snow < 0.5, "on the ice you keep sliding after letting go (%.1f m/s, snow %.1f)" % [glide_ice, glide_snow])
	# Snow drifts slow you down
	var drift := (s.get_node("Snow Drifts/Drift1") as Node3D).global_position
	var in_drift := await _run_speed(player, drift + Vector3(0, 0.6, 0))
	var outside := await _run_speed(player, Vector3(2, 0.5, 20))
	check(in_drift < outside * 0.75, "the snow drifts slow you down (%.1f vs %.1f m/s)" % [in_drift, outside])
	# The ice slide down Snowball Hill
	player.global_position = (s.get_node("Slide") as Node3D).global_position + Vector3(0, 0.3, 0)
	s.get_node("Slide/Spot").use()
	await create_timer(0.4).timeout
	check(not player.is_physics_processing(), "riding the ice slide")
	await create_timer(s.SLIDE_TIME).timeout
	await _physics(4)
	check(player.is_physics_processing() and player.global_position.y < 1.5 and player.global_position.distance_to(Vector3(-12, 0, -2.4)) < 3.0,
		"...brings you down off the hill by the lake (%s)" % player.global_position)
	await _physics(30)


func _glide(player: CharacterBody3D, at: Vector3) -> float:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.spring_arm.global_rotation = Vector3.ZERO
	await _physics(6)
	Input.action_press("move_forward")
	await _physics(70)
	Input.action_release("move_forward")
	await _physics(12)
	return Vector2(player.velocity.x, player.velocity.z).length()


func _run_speed(player: CharacterBody3D, at: Vector3) -> float:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.spring_arm.global_rotation = Vector3(0, PI / 2, 0)
	await _physics(6)
	Input.action_press("move_forward")
	await _physics(40)
	var v := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release("move_forward")
	await _physics(20)
	return v


func _check_moments() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	check(s.get_node("FrostGloop/Spot").what() == "look at the frozen Gloop", "the Frost Gloop sits frozen on its throne")
	check(s._gloop.process_mode == Node.PROCESS_MODE_DISABLED, "...not moving at all")
	player.global_position = (s.get_node("FrostGloop") as Node3D).global_position + Vector3(0, 0, 6)
	await _frames(10)
	check(not s.gloop_awake, "...and walking right up to it doesn't wake it yet")
	check(s.get_node("Moment1/Spot").what() == "thaw the frozen moment", "a frozen moment offers to be thawed")
	s.get_node("Moment1/Spot").use()
	s.get_node("Moment1/Spot").use()
	check(not s.is_thawed(0) and s.get_node("Moment1/Spot").what() == "chip the ice again", "two chips crack the ice...")
	s.get_node("Moment1/Spot").use()
	check(s.is_thawed(0) and s.moments_thawed() == 1, "...and the third thaws the leaping fish")
	var hit := s.get_node("Moment2/Moment/Shell/Hit") as Node
	var said := []
	for i in 3:
		said.append(hit.shot(1, Vector3.ZERO, Vector3.FORWARD))
	check(said == ["hit", "hit", "hit"] and s.is_thawed(1), "three bubbles thaw the snowball fight")
	player.global_position = Vector3(0, 0.6, 20)                     # well away from the throne
	await _physics(4)
	for i in 3:
		s.get_node("Moment3/Spot").use()
	check(s.moments_thawed() == 3 and s.get_node("Moment3/Spot").what() == "", "the snowbird thaws too, and there's nothing left to chip")
	await create_timer(4.5).timeout
	check(not (s.get_node("Moment1/Moment/Thing") as Node3D).visible and not (s.get_node("Moment3/Moment/Thing") as Node3D).visible,
		"the fish splashed back in and the bird flew off")
	check(not (s.get_node("Moment2/Moment/Shell") as Node3D).visible, "the ice shells are gone")
	# Hayden's playtest, 14 Nov 2026: the fish has a real hole in the ice, and once thawed the moments carry on
	check(s.get_node_or_null("Moment1/Moment/Water") != null, "the fish's hole is open water in the ice")
	check(int(s.leaps) >= 1, "the fish keeps leaping out of its hole and back in (%d leaps)" % s.leaps)
	check(int(s.throws) >= 3, "the snowmen keep throwing snowballs at each other (%d throws)" % s.throws)


func _check_gloop() -> void:
	var s := current_scene
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	await _physics(10)
	check(not s.gloop_awake, "the Frost Gloop waits until you come near")
	player.global_position = (s.get_node("FrostGloop") as Node3D).global_position + Vector3(0, 0, 10)
	await _frames(4)
	var g := s._gloop as CharacterBody3D
	check(s.gloop_awake and g.process_mode == Node.PROCESS_MODE_INHERIT, "with all three thawed, it cracks out of its ice")
	check(g.get("title") == "Frost Gloop" and g.ring_colour.b > 0.9, "...the Frost Gloop, with its own name and a ring of frost")
	await _physics(30)
	var before: int = rem.count
	player.global_position = Vector3(0, 0.6, 20)                     # out of its reach while it's popped
	for i in int(g.stomps_to_defeat):
		g.shot(1, g.global_position, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared("frozen_moment"), "popping it mends the Frozen Moment")
	check(rem.count == before + int(portals.world("frozen_moment").reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(not root.get_node("Dialogue").flags.has("popped_gloop_king"), "...and it doesn't count as popping the Gloop King")
	var flakes: Array = s._flakes.duplicate()
	var hand := s.get_node("Clock/Sky Clock/Second") as Node3D
	var from := hand.rotation.z
	await create_timer(2.5).timeout
	check(s.snow_falling() and s._flakes != flakes, "the snow starts falling")
	check(s.clock_ticking() and absf(hand.rotation.z - from) > 0.1, "the sky clock ticks on")
	check("snowing" in " ".join(s.flurry_lines()), "Flurry's thrilled")


func _check_home() -> void:
	portals.go_home()          # (the way home: there's no time limit to run out any more)
	await create_timer(1.0).timeout
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "the way home takes you home to the Void")
	var p := current_scene.get_node_or_null("Portals/Portal frozen_moment") as Node3D
	var player := current_scene.get_tree().get_first_node_in_group("player") as Node3D
	check(p != null and player.global_position.distance_to(p.global_position) < 6.0, "...right by the Frozen Moment's portal")
	portals.enter("frozen_moment")
	await _frames(14)
	var s := current_scene
	check(s.scene_file_path == WORLD and s.moments_thawed() == 3 and s.get_node_or_null("The Frost Gloop") == null
		and not (s.get_node("Moment1/Moment/Shell") as Node3D).visible and s.snow_falling(), "going back, it's all still done and the snow's still falling")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("frozen_moment") and portals.found == found and portals.is_open("frozen_moment"), "the Frozen Moment's progress loads back")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
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
