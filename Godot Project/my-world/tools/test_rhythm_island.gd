extends SceneTree

# Checks Rhythm Springs' island (tools/build_rhythm_springs.gd): you arrive on the beach on solid ground, and really
# walk (on the stick, through the camera's frame) up the torch path through the Springs Gate into the valley, out
# along the pier, into the thatched pavilion, up the ramp to the first stilt treehouse, round its deck and over both
# rope bridges to the third, and in through the crystal cave's doorway to its pool. The island has its sea, its
# fence, the ridge's waterfall, the lagoons and the shade spots for the new buildings.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_rhythm_island.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.rhythm_island_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.rhythm_island_test_backup.cfg"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"
const B := preload("res://tools/build_rhythm_springs.gd")

var failures := 0
var game: Node
var world: Node3D
var p: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	change_scene_to_file(WORLD)
	await _frames(10)
	await _physics(10)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	check(world != null and p != null, "Rhythm Springs loads with the player in it")
	if p == null:
		_finish()
		return

	# The island's parts
	for n in ["Island Ground", "Sea", "WorldBounds Fence", "Springs Gate", "Pavilion", "Stilt Huts", "Crystal Cave",
			"Bamboo Grove", "Pier"]:
		check(world.find_child(n, true, false) != null, "the island has its " + n)
	var falls := world.find_children("Waterfall", "", true, false)
	var ridge := false
	for f in falls:
		ridge = ridge or str(f.get_meta("fall_id", "")) == "ridge_falls"
	check(ridge, "the ridge's waterfall is marked for its secret cove")
	for n in ["Shade Pavilion", "Shade Hut 1", "Shade Hut 2", "Shade Hut 3", "Shade Cave"]:
		check(world.find_child(n, true, false) != null, n + " cools you down")
	check(B.HUTS.size() == 3, "three stilt treehouses")

	# Where you arrive is on the ground
	await _settle()
	check(absf(_feet()) < 0.6 and p.is_on_floor(), "you arrive standing on the beach (feet at %.2f)" % _feet())

	# Up the torch path, through the gate, into the valley
	await _route("up the torch path and through the Springs Gate into the valley", B.ARRIVE,
		[B.GATE + Vector3(0, 0, 4), B.GATE, Vector3(0, 0, 38)], 0.0)
	# Out along the pier
	var pier_start := B.shore_r(PI / 2.0) - 9.0
	await _route("on along the beach and out to the end of the pier", B.ARRIVE,
		[Vector3(B.PIER_X, 0, pier_start - 8.0), Vector3(B.PIER_X, 0, pier_start + 2.0), Vector3(B.PIER_X, 0, B.PIER_END - 4.0)], 0.0)
	# Into the pavilion, between two posts
	var a := TAU / 16.0
	var dir := Vector3(cos(a), 0, sin(a))
	await _route("in between the pavilion's posts to its table", B.PAVILION + dir * 9.0,
		[B.PAVILION + dir * 6.5, B.PAVILION + dir * 1.8], 0.0)
	check(_feet() < 0.2, "...its floor is nearly flush with the ground (feet at %.2f)" % _feet())
	# Up the ramp, round the decks and over the rope bridges
	var in_dir := Vector3(-B.HUTS[0].x, 0, -B.HUTS[0].z).normalized()
	var steps: Array = [B.HUTS[0] + in_dir * 11.5, B.HUTS[0] + in_dir * 2.2 + Vector3(0, B.HUT_DECK, 0)]
	for i in B.HUTS.size() - 1:
		var from: Vector3 = B.HUTS[i]
		var to: Vector3 = B.HUTS[i + 1]
		var last: Vector3 = steps[steps.size() - 1]
		steps.append_array(_round_deck(from, last - from, to - from))
		steps.append(to - (to - from).normalized() * 2.2 + Vector3(0, B.HUT_DECK, 0))
	steps.append(B.HUTS[2] + (B.HUTS[1] - B.HUTS[2]).normalized() * 1.9 + Vector3(0, B.HUT_DECK, 0))
	await _route("up the ramp to the first treehouse, round its deck and over both rope bridges to the third",
		B.HUTS[0] + in_dir * 13.0, steps, B.HUT_DECK)
	check(absf(_feet() - B.HUT_DECK) < 0.3, "...standing up on the third treehouse's deck (feet at %.2f)" % _feet())
	# In through the crystal cave's doorway
	var face := Vector3(-B.CAVE.x, 0, -B.CAVE.z).normalized()
	await _route("in through the crystal cave's doorway to its pool", B.CAVE + face * 13.0,
		[B.CAVE + face * 9.0, B.CAVE + face * 3.6], 0.0)
	_finish()


func _round_deck(at: Vector3, from_v: Vector3, to_v: Vector3) -> Array:
	# Waypoints round a treehouse's deck, 2.2 m out from its middle (the hut's walls go out 1.4 m, the deck 2.6 m),
	# the short way round from where you came onto it to where the next bridge leaves
	var out := []
	var a0 := atan2(from_v.z, from_v.x)
	var a1 := atan2(to_v.z, to_v.x)
	var d := wrapf(a1 - a0, -PI, PI)
	var n := int(ceil(absf(d) / deg_to_rad(20.0)))
	for k in range(1, n + 1):
		var aa := a0 + d * k / n
		out.append(at + Vector3(cos(aa), 0, sin(aa)) * 2.2 + Vector3(0, B.HUT_DECK, 0))
	return out


func _route(what: String, start: Vector3, steps: Array, end_y: float) -> void:
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	var heat_of: Variant = world.get("heat")
	var wpi := 0
	var got := false
	for i in 60 * 40:
		await physics_frame
		if heat_of != null:
			world.set("heat", 0.0)
		var want: Vector3 = steps[wpi] - p.global_position
		want.y = 0
		if want.length() < 0.7:
			if wpi == steps.size() - 1:
				got = true
				break
			wpi += 1
		_steer(want.normalized())
	_release()
	await _physics(10)
	check(got and absf(_feet() - end_y) < 0.6,
		"you can walk %s (step %d of %d, feet at %.2f)" % [what, wpi + 1, steps.size(), _feet()])


func _feet() -> float:
	# The player's origin is the middle of their capsule: their feet are half its height lower
	var shape := (p.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	return p.global_position.y - shape.height / 2.0


func _settle() -> void:
	await _physics(40)


func _steer(want: Vector3) -> void:
	# Like a player on the stick: through the camera's frame
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
