extends SceneTree

# Checks Bramble's burrow, the Rootmind's reward (scripts/burrow.gd): it's locked until the Rootmind is mended
# (pressing Burrow does nothing and Settings > Controls doesn't list it), then on soft ground Burrow dives under:
# out of sight, a soil mound instead, nothing can hurt you, no shooting, quicker than running; Jump or Burrow again
# sprouts you up with a hop; it won't start on paving, and running onto paving or getting on a ride pops you up; the
# Rootmind's moss counts as soil; mending the Rootmind has Bramble teach it, and her lines after say how.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_burrow.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.burrow_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.burrow_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/rootmind.tscn"
var BURROW: GDScript                      # loaded once the autoloads are up: it uses them

var failures := 0
var game: Node
var portals: Node
var settings: Node


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
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	BURROW = load("res://scripts/burrow.gd")
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	settings = root.get_node("Settings")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	var quests := root.get_node("Quests")
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	_check_controls()
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(6)
	await _check_town()
	await _check_rootmind()
	_finish()


func _check_controls() -> void:
	check(InputMap.has_action("burrow"), "there's a Burrow action")
	check(settings.default_bindings().get("burrow") == KEY_B and settings.default_pad_bindings().get("burrow") == JOY_BUTTON_RIGHT_STICK,
		"it's on B and R3 to start with")
	var keys: Dictionary = settings.default_bindings()
	var clash := ""
	for a in keys:
		if a != "burrow" and keys[a] == KEY_B:
			clash = a
	var pads: Dictionary = settings.default_pad_bindings()
	for a in settings.PAD_GROUPS[0]:
		if a != "burrow" and pads.get(a, -1) == JOY_BUTTON_RIGHT_STICK:
			clash = a
	check(clash == "", "nothing else on foot uses them (%s)" % clash)
	check(not settings.action_shown("burrow"), "Settings > Controls doesn't list Burrow before the Rootmind's mended")


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _ground(at: Vector2) -> Dictionary:
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80, at.y), Vector3(at.x, -40, at.y))
	return space.intersect_ray(q)


func _spot(want_soil: bool) -> Vector3:
	# Somewhere flat and open, on soil or not, with soil (or not) a few metres all round
	for x in range(-120, 121, 6):
		for z in range(-120, 121, 6):
			var ok := true
			var y := 0.0
			for d in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4), Vector2(0, -10)]:
				var hit := _ground(Vector2(x, z) + d)
				if hit.is_empty() or hit.normal.y < 0.95 or BURROW.soil(hit.collider) != want_soil:
					ok = false
					break
				if d == Vector2.ZERO:
					y = hit.position.y
			if ok:
				return Vector3(x, y + 0.9, z)
	return Vector3.INF


func _press(action: String) -> void:
	Input.action_press(action)
	await _physics(1)
	Input.action_release(action)
	await _physics(1)


func _place(p: CharacterBody3D, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.spring_arm.global_rotation = Vector3.ZERO           # forward is -Z
	await _physics(8)


func _check_town() -> void:
	var p := _player()
	var b: Node = p.burrow
	check(b != null and b.get_script() == BURROW, "the hero has a burrow")
	var soil := _spot(true)
	var hard := _spot(false)
	check(soil != Vector3.INF and hard != Vector3.INF, "found open grass and open paving in the Void")
	await _place(p, soil)
	check(p.is_on_floor() and BURROW.soil(p._floor_node), "standing on the Void's grass")
	await _press("burrow")
	check(not b.active and p.visual.visible, "locked: before the Rootmind's mended, Burrow does nothing")

	portals.cleared_worlds.append("rootmind")
	check(settings.action_shown("burrow"), "once it's mended, Settings > Controls lists Burrow")
	await _press("burrow")
	check(b.active, "Burrow dives under")
	check(not p.visual.visible and b._mound.visible, "...out of sight, with a soil mound where you are")
	check(p.is_invulnerable(), "...where nothing can hurt you")
	var hp: int = game.get("health") if game.get("health") != null else 0
	p.hurt(1, p.global_position + Vector3(1, 0, 0))
	check(game.get("health") == null or game.get("health") == hp, "...a Gloop's bump doesn't count")
	check(not p.popper.can_shoot(), "...and no shooting from down there")
	Input.action_press("move_forward")
	await _physics(40)
	var flat := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	check(b.active and flat > p.speed * 1.3, "tunnelling is quicker than running (%.1f m/s vs %.1f)" % [flat, p.speed])
	await _physics(10)
	await _press("jump")
	check(not b.active and p.visual.visible, "Jump sprouts you back up")
	check(p.velocity.y > p.jump_velocity * 0.9, "...with a springy hop (%.1f)" % p.velocity.y)
	await _physics(60)

	await _place(p, soil)
	await _press("burrow")
	await _physics(10)
	await _press("burrow")
	check(not b.active and p.velocity.y > 0.0, "Burrow again pops you up too")
	await _physics(60)

	await _place(p, hard)
	check(p.is_on_floor() and not BURROW.soil(p._floor_node), "standing on paving")
	await _press("burrow")
	check(not b.active, "paving's too hard to dig into")

	await _place(p, soil)
	await _press("burrow")
	check(b.active, "back under on the grass")
	p.global_position = hard - Vector3(0, 0.08, 0)    # standing right on it, so it's the paving that does it
	await _physics(6)
	check(not b.active and p.visual.visible, "tunnelling onto paving pops you up")
	await _physics(60)

	await _place(p, soil)
	await _press("burrow")
	game.riding = true
	await _physics(3)
	check(not b.active and p.visual.visible, "getting on a ride pops you up")
	game.riding = false
	await _physics(10)


func _check_rootmind() -> void:
	game.go(WORLD, "Entrance", "the Rootmind")
	await _frames(16)
	await _physics(6)
	var s := current_scene
	check(s.scene_file_path == WORLD, "into the Rootmind")
	var moss := false
	var hit := _ground(Vector2(6, 12))
	moss = not hit.is_empty() and BURROW.soil(hit.collider)
	check(moss, "the Rootmind's moss counts as soil")
	var lines := " ".join(s.bramble_lines())
	check(lines.contains("{burrow}"), "Bramble's lines after mending remind you how to burrow")
	# Teaching: mend a fresh Rootmind and Bramble comes in with it
	portals.cleared_worlds.erase("rootmind")
	check(" ".join(s.teach_lines()).contains("{burrow}") and " ".join(s.teach_lines()).contains("{jump}"),
		"Bramble's lesson names the buttons")
	var dialogue := root.get_node("Dialogue")
	if dialogue.is_active():
		dialogue.end()
	s.mend()
	check(portals.is_cleared("rootmind"), "mending the Rootmind unlocks it")
	await create_timer(s.TEACH_AFTER + 0.5).timeout
	check(dialogue.is_active(), "...and Bramble teaches you to burrow")
	var p := _player()
	await _place(p, Vector3(6, 1.0, 12))
	if dialogue.is_active():
		dialogue.end()
	await _physics(30)
	await _press("burrow")
	check(p.burrow.active, "burrowing works on the Rootmind's moss")


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
