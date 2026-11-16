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
			"Bamboo Grove", "Pier", "Flower Glade", "Legend Hut", "Tide Pools", "Islet"]:
		check(world.find_child(n, true, false) != null, "the island has its " + n)
	var falls := world.find_children("Waterfall", "", true, false)
	var ridge := false
	for f in falls:
		ridge = ridge or str(f.get_meta("fall_id", "")) == "ridge_falls"
	check(ridge, "the ridge's waterfall is marked for its secret cove")
	for n in ["Shade Pavilion", "Shade Hut 1", "Shade Hut 2", "Shade Hut 3", "Shade Cave", "Shade Legend Hut"]:
		check(world.find_child(n, true, false) != null, n + " cools you down")
	check(B.HUTS.size() == 3, "three stilt treehouses")
	_check_detail()

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
	# Into the flower glade, between two of its giant flowers
	var ga := 0.2 + TAU / 18.0
	var gd := Vector3(cos(ga), 0, sin(ga))
	await _route("in between the giant flowers to the middle of the glade", B.GLADE + gd * 11.0,
		[B.GLADE + gd * 4.0, B.GLADE], 0.0)
	# Into the legend hut by its open side, up to the drum
	var hd := Vector3(-B.LEGEND_HUT.x, 0, -B.LEGEND_HUT.z).normalized()
	await _route("in through the legend hut's open side to its drum", B.LEGEND_HUT + hd * 9.0,
		[B.LEGEND_HUT + hd * 4.5, B.LEGEND_HUT + hd * 1.3], 0.0)
	# Out along the sandbar to the islet, and you can't step off it into the deep sea
	var from: Vector3 = B.bar_from()
	var islet: Vector3 = B.islet_at()
	var bar := (islet - from).normalized()
	await _route("out along the sandbar to the islet", from - bar * 6.0, [from, islet - bar * 3.0, islet + Vector3(0, 0, 2.5)], 0.0)
	var mid := from.lerp(islet, 0.55)
	await _route_blocked("off the side of the sandbar into the deep sea", mid, mid + bar.cross(Vector3.UP) * 6.0)
	await _route_blocked("off the islet's far side into the deep sea", islet, islet + bar * 12.0)
	var fence_at := bar * (B.shore_r(atan2(bar.z, bar.x)) - 3.0)
	await _route_blocked("through the fence beside the sandbar out onto the sea", fence_at + bar.cross(Vector3.UP) * 3.0 - bar * 3.0,
		fence_at + bar.cross(Vector3.UP) * 3.0 + bar * 8.0)
	_finish()


func _check_detail() -> void:
	# The baked island props (scripts/detail_props.gd dress_rhythm, tools/build_prop_island.py): every palm, torch,
	# grove lantern and the gate has its detailed one, nothing old is drawn, and the collisions and flames stay
	var props: Dictionary = root.get_node("WorldDetail").last_props
	var palms := world.find_children("Parasol Palm *", "Node3D", true, false)
	var torches := 0
	for f in world.find_children("Flame", "MeshInstance3D", true, false):
		if f.get_parent().get_parent().name == "Torch Paths":
			torches += 1
	check(palms.size() > 40 and props.get("palms", 0) == palms.size(),
		"every palm is detailed (%d of %d)" % [props.get("palms", 0), palms.size()])
	check(torches > 5 and props.get("torches", 0) == torches, "every tiki torch is detailed (%d of %d)" % [props.get("torches", 0), torches])
	check(props.get("lanterns", 0) >= 2, "the bamboo grove's lanterns are detailed (%d)" % props.get("lanterns", 0))
	check(props.get("gate", 0) == 1, "the Springs Gate is detailed")
	var old_drawn := 0
	var flames_hidden := 0
	for g in palms + [world.find_child("Springs Gate", true, false)]:
		for m in (g as Node).get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).layers != 0:
				old_drawn += 1
	for f in world.find_children("Flame", "MeshInstance3D", true, false):
		if f.get_parent().get_parent().name == "Torch Paths" and (f as MeshInstance3D).layers == 0:
			flames_hidden += 1
	check(old_drawn == 0, "none of the old palm or gate pieces are drawn (%d)" % old_drawn)
	check(flames_hidden == 0, "the torches' flames still burn")
	var bodies := 0
	for g in palms:
		bodies += (g as Node).find_children("*", "StaticBody3D", true, false).size()
	check(bodies >= palms.size(), "the palms are still solid (%d bodies)" % bodies)
	# Each detailed palm is as tall as its old one and leans the same way
	var worst := 0.0
	for g in palms:
		var d := (g as Node).get_node_or_null("Detailed Palm") as Node3D
		var top := Vector3.ZERO
		for m in (g as Node).get_children():
			if m is MeshInstance3D and (m as MeshInstance3D).material_override and \
					(m as MeshInstance3D).material_override.resource_name == "Coconut":
				top = m.position + Vector3(0, 0.3, 0)
		if d == null:
			worst = INF
			continue
		var model_top: Vector3 = d.transform * Vector3(0.9, 5.0, 0)
		var off := absf(model_top.y - top.y)
		var lean := Vector2(top.x, top.z)
		if lean.length() > 0.2:
			off += 1.0 - Vector2(model_top.x, model_top.z).normalized().dot(lean.normalized())
		worst = maxf(worst, off)
	check(worst < 0.15, "each detailed palm stands as tall as its old one and leans its way (worst %.2f off)" % worst)


func _route_blocked(what: String, start: Vector3, goal: Vector3) -> void:
	# Walk hard at somewhere you shouldn't get to for 6 s: you mustn't get within 2 m of it, nor fall
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	for i in 60 * 6:
		await physics_frame
		world.set("heat", 0.0)
		var want := goal - p.global_position
		want.y = 0
		_steer(want.normalized())
	_release()
	await _physics(10)
	var d := Vector2(goal.x - p.global_position.x, goal.z - p.global_position.z).length()
	check(d > 2.0 and _feet() > -0.3, "you can't walk %s (%.1f m short, feet at %.2f)" % [what, d, _feet()])


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
