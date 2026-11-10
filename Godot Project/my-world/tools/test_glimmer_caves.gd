extends SceneTree

# Checks Lanternmoor's reward (slice two): Pip's glow (scripts/pip_glow.gd) and the Glimmer Caves
# (scripts/glimmer_caves.gd, built with scripts/cave_kit.gd). Before Lanternmoor's mended there's no glow and no way
# down; mending it, Pip teaches the glow and the hollow opens; the caves are all joined up, nothing in them is inside
# rock, and the way down really is open; in the caves it's dark and you glow; crystals wake; the glow bridge is only
# there in the glow and carries you over the Chasm; moth lifts float you up; bouncy mushrooms bounce; the moonmoths
# only show in the glow and pay out when all five are found; the Moon Cache opens once; Gloomies hide from the glow;
# back in the Void you glow at night but not by day; and it all stays after leaving and loading.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_glimmer_caves.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.glimmer_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.glimmer_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const WORLD := "res://scenes/portal_worlds/lanternmoor.tscn"
const KIT := preload("res://scripts/cave_kit.gd")

var failures := 0
var game: Node
var portals: Node
var rem: Node
var clock: Node
var dialogue: Node


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
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "rootmind", "frozen_moment"]:
		portals.cleared_worlds.append(w)
	change_scene_to_file(TOWN)
	await _frames(10)
	await _check_locked()
	await _check_mending()
	_check_layout()
	await _check_way_down()
	await _check_bridge()
	await _check_lifts_and_bounce()
	await _check_moths_and_cache()
	await _check_back_in_the_void()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _check_locked() -> void:
	var glow: Node = _player().get("pip_glow")
	check(glow != null and not glow.unlocked(), "the hero has Pip's glow, locked until Lanternmoor's mended")
	portals.enter("lanternmoor")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(s.scene_file_path == WORLD, "into Lanternmoor")
	check(s.caves == null and s.get_node_or_null("Glimmer Caves") == null, "before it's mended there are no caves")
	check(not _player().pip_glow.shining(), "...and no glow, even in its endless night")
	check(_ground_at(s, Vector2(8, 37)) > -0.5, "...and the moor's solid where the hollow will be")


func _check_mending() -> void:
	var s := current_scene
	var t0 := Time.get_ticks_msec()
	s.mend()
	check(portals.is_cleared("lanternmoor"), "mending Lanternmoor")
	await create_timer(s.TEACH_AFTER + 0.5).timeout
	check(s.caves != null, "after the sunrise, the hollow opens and the Glimmer Caves are there")
	print("      (the caves took %d ms all told)" % (Time.get_ticks_msec() - t0))
	check(dialogue.is_active() and "glow" in " ".join(s.teach_lines()), "...and Pip teaches you the glow")
	dialogue.end()
	await _frames(4)
	var glow: Node = _player().pip_glow
	check(glow.unlocked(), "the glow's yours now")
	check(s.get("fall_below") < -40.0, "the world's fall catch is under the caves (%.0f)" % s.get("fall_below"))
	check("Glimmer" in " ".join(s.pip_lines()), "Pip's lines point you to the caves")


func _check_layout() -> void:
	var c: Node = current_scene.caves
	var f: Dictionary = c.field
	# Every cavern joins up with the Moth Hall through the air (a flood fill of the cave's field)
	var seen := _flood(f, c.ROOMS["moth_hall"])
	var joined := true
	for room in c.ROOMS:
		if not seen.has(_cell(f, c.ROOMS[room])):
			joined = false
			print("      not joined: ", room)
	check(joined, "all seven caverns join up (%d)" % c.ROOMS.size())
	var ok := true
	for m in c.MOTHS:
		var bounce := false                                 # (or high over a bouncy mushroom)
		for b in c.BOUNCERS:
			if Vector2(m.x - b.at.x, m.z - b.at.z).length() < 2.0 and m.y - b.at.y < 8.0:
				bounce = true
		if KIT.field_at(f, m) >= 0.0 or (m.y - KIT.floor_below(f, m).y > 1.6 and not bounce):
			ok = false
			print("      moth in rock or out of reach: ", m, " field ", KIT.field_at(f, m), " floor ", KIT.floor_below(f, m))
	check(ok, "every moonmoth floats in the open, within reach of a floor or ledge")
	ok = true
	for lift in c.find_children("Moth Lift*", "Node3D", false, false):
		var at: Vector3 = (lift as Node3D).global_position
		if KIT.field_at(f, at + Vector3(0, 0.5, 0)) >= 0.0 or absf(KIT.floor_below(f, at + Vector3(0, 1, 0)).y - at.y) > 0.3:
			ok = false
			print("      lift ", at, " floor ", KIT.floor_below(f, at + Vector3(0, 1, 0)))
	check(ok, "the moth lifts stand on the floor")
	var under := KIT.floor_below(f, (c.BRIDGE[0] + c.BRIDGE[1]) / 2.0)
	check(under.y < -28.0, "the Chasm's pit really drops away under the bridge (floor at %.1f)" % under.y)
	check(absf(KIT.floor_below(f, c.BRIDGE[0] + Vector3(-1.0, 1.0, 0)).y - c.BRIDGE[0].y) < 0.6
		and absf(KIT.floor_below(f, c.BRIDGE[1] + Vector3(1.0, 1.0, 0)).y - c.BRIDGE[1].y) < 0.6,
		"...and the bridge meets the floor at both ends")
	check(KIT.field_at(f, c.CACHE + Vector3(0, 0.6, 0)) < 0.0, "the Moon Cache is in the open")
	var gdark := current_scene.get_tree().get_nodes_in_group("cave_dark")
	check(gdark.size() > 0, "the caves are a dark place")


func _check_way_down() -> void:
	var s := current_scene
	var p := _player()
	check(_ground_at(s, Vector2(8, 37)) < -5.0, "the hollow's open: nothing to stand on until the Moth Hall below")
	p.global_position = Vector3(8, 2.0, 37)
	p.velocity = Vector3.ZERO
	await _physics(150)
	check(p.global_position.y < -7.0 and p.global_position.y > -9.5, "dropping in lands you in the Moth Hall (y %.1f)" % p.global_position.y)
	await _frames(30)
	var glow: Node = p.pip_glow
	check(glow.in_dark and glow.shining(), "down there it's dark, and you glow")
	check(glow._light.visible and glow._light.light_energy > 1.0, "...a real light round you")
	var shade := p.get_node_or_null("Cave Dark") as CanvasLayer
	check(shade != null and shade.visible, "...with the dark closing in round the edges")
	var lit := false
	for n in s.get_tree().get_nodes_in_group("glow_wake"):
		if n.get("awake"):
			lit = true
	check(lit and glow.woken > 0, "the crystals near you wake up in the glow")
	var sun := s.get_node("Sun") as DirectionalLight3D
	check(sun.light_cull_mask & KIT.LAYER == 0, "the sun never lights the cave rock")


func _check_bridge() -> void:
	var s := current_scene
	var c: Node = s.caves
	var p := _player()
	var glow: Node = p.pip_glow
	var planks: Array = s.get_tree().get_nodes_in_group("glow_solid")
	check(planks.size() >= 8, "the Chasm has a glow bridge (%d planks)" % planks.size())
	var a: Vector3 = c.BRIDGE[0]
	var b: Vector3 = c.BRIDGE[1]
	p.global_position = a + Vector3(-2.0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	await _frames(30)
	var near: Node3D = planks[0]
	var far: Node3D = planks[0]
	for pl in planks:
		if (pl as Node3D).global_position.distance_to(p.global_position) < near.global_position.distance_to(p.global_position):
			near = pl
		if (pl as Node3D).global_position.distance_to(p.global_position) > far.global_position.distance_to(p.global_position):
			far = pl
	check(glow.is_shown(near) and near.visible, "the planks near you shine in the glow")
	check(far.global_position.distance_to(p.global_position) > glow.RADIUS and not glow.is_shown(far),
		"...and the far end isn't there yet")
	# Walk across, a step at a time
	var fell := false
	for i in 26:
		var t := float(i) / 25.0
		p.global_position = a.lerp(b, t) + Vector3(0, 0.95, 0)
		p.velocity = Vector3.ZERO
		await _physics(4)
		await _frames(2)
		if p.global_position.y < a.y - 1.0:
			fell = true
			break
	check(not fell, "the bridge holds you all the way across the Chasm (y %.1f)" % p.global_position.y)
	# Without the glow it's not there at all
	portals.cleared_worlds.erase("lanternmoor")
	await _frames(40)
	var shape := near.get_node("CollisionShape3D") as CollisionShape3D if near.has_node("CollisionShape3D") else null
	if shape == null:
		for ch in near.get_children():
			if ch is CollisionShape3D:
				shape = ch
	check(not glow.shining() and not near.visible and shape.disabled, "without the glow the bridge isn't there, or solid")
	portals.cleared_worlds.append("lanternmoor")
	await _frames(40)
	var back: Node3D = planks[0]
	for pl in planks:
		if (pl as Node3D).global_position.distance_to(p.global_position) < back.global_position.distance_to(p.global_position):
			back = pl
	check(back.visible and glow.is_shown(back), "...and it comes back with the glow")


func _check_lifts_and_bounce() -> void:
	var s := current_scene
	var c: Node = s.caves
	var p := _player()
	# The Echo Pool's moth lift floats you back up to the Chasm
	var low: Dictionary = c.LIFTS[1]
	p.global_position = low.at + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	Input.action_press("jump")
	await create_timer(3.5).timeout
	check(c.lifting or p.global_position.y > low.top - 2.0, "holding Jump in the Echo Pool's moth lift floats you up")
	check(p.global_position.y > low.top - 2.0, "...right up to the Chasm (y %.1f)" % p.global_position.y)
	Input.action_release("jump")
	# The Moth Hall's lifts you out of the hollow
	var hall: Dictionary = c.LIFTS[0]
	p.global_position = hall.at + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _physics(20)
	Input.action_press("jump")
	await create_timer(3.5).timeout
	check(p.global_position.y > 0.5, "...and the Moth Hall's floats you out of the hollow (y %.1f)" % p.global_position.y)
	Input.action_release("jump")
	await _physics(30)
	# Just falling down the hollow without Jump doesn't lift you
	p.global_position = Vector3(8, 2.0, 37)
	p.velocity = Vector3.ZERO
	await _physics(150)
	check(p.global_position.y < -7.0, "without Jump you drop down the hollow as normal")
	# A bouncy mushroom
	var mush: Dictionary = c.BOUNCERS[2]
	var before: int = c.bounces
	p.global_position = mush.at + Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	var top := -100.0
	for i in 200:
		await physics_frame
		top = maxf(top, p.global_position.y)
	check(c.bounces > before and top > mush.at.y + 5.0, "bouncy mushrooms spring you up high (%.1f m)" % (top - mush.at.y))


func _check_moths_and_cache() -> void:
	var s := current_scene
	var c: Node = s.caves
	var p := _player()
	var glow: Node = p.pip_glow
	var m: Node3D = c.moths[0]
	p.global_position = c.ROOMS["gallery"] + Vector3(0, 0.5, 0)
	await _physics(10)
	await _frames(30)
	check(m != null and not glow.is_shown(m), "a moonmoth out of the glow's reach can't be seen")
	var r_before: int = rem.count
	var s_before: int = game.sparkles
	for i in c.MOTHS.size():
		p.global_position = c.MOTHS[i] + Vector3(0, -0.2, 0)
		p.velocity = Vector3.ZERO
		await _frames(3)
		check(portals.has_found("lanternmoor", "moth_%d" % (i + 1)), "walking up to moonmoth %d finds it" % (i + 1))
	check(c.moths_found() == 5 and rem.count == r_before + c.MOTH_REMNANTS and game.sparkles == s_before + c.MOTH_SPARKLES,
		"all five found: Pip sends %d Remnants and %d sparkles" % [rem.count - r_before, game.sparkles - s_before])
	check("five" in " ".join(s.pip_lines()), "Pip thanks you for them")
	r_before = rem.count
	check(c.open_cache() and rem.count == r_before + c.CACHE_REMNANTS, "the Moon Cache gives %d Remnants" % c.CACHE_REMNANTS)
	check(not c.open_cache() and rem.count == r_before + c.CACHE_REMNANTS, "...only once")
	# The Gloomies hide from the glow
	var home: Vector3 = c.gloomies[1].get_meta("home")
	p.global_position = home + Vector3(2.5, 0.5, 0)
	await _physics(4)
	await create_timer(1.0).timeout
	check(c.gloomie_hiding(1), "a Gloomie scurries off from your glow")
	p.global_position = c.ROOMS["gallery"] + Vector3(0, 0.5, 0)
	await create_timer(3.5).timeout
	check(not c.gloomie_hiding(1), "...and creeps back once you've gone")


func _check_back_in_the_void() -> void:
	current_scene.get_node("WayHome/Way Home/Spot").use()
	await _frames(14)
	await _physics(4)
	check(current_scene.scene_file_path == TOWN, "home to the Void")
	var glow: Node = _player().pip_glow
	clock.set_time(clock.day, 12 * 60.0, true)
	await _frames(4)
	check(glow.unlocked() and not glow.shining(), "in the Void by day you don't glow")
	clock.set_time(clock.day, 23 * 60.0 + 30.0, true)
	await _frames(40)
	check(glow.shining() and not glow.in_dark and glow._light.light_energy < 1.0 and glow._light.light_energy > 0.2,
		"...at night you glow softly (%.2f)" % glow._light.light_energy)
	clock.set_time(clock.day, 12 * 60.0, true)
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared("lanternmoor") and portals.found == found, "the moonmoths and the Moon Cache stay found after loading")
	portals.enter("lanternmoor")
	await _frames(14)
	var s := current_scene
	check(s.caves != null and s.caves.moths.all(func(x: Variant) -> bool: return x == null), "going back, the caves are there and the moths are home")
	check(_ground_at(s, Vector2(8, 37)) < -5.0, "...and the hollow's still open")
	s.get_node("WayHome/Way Home/Spot").use()
	await _frames(12)


# Helpers ----------------------------------------------------------------------------------------------------------------
func _ground_at(s: Node3D, at: Vector2) -> float:
	var space := s.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 5.0, at.y), Vector3(at.x, -60.0, at.y))
	q.collision_mask = 1
	var player := _player()
	if player:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else -100.0


func _cell(f: Dictionary, p: Vector3) -> int:
	var q: Vector3 = (p - f.lo) / f.s
	return (clampi(roundi(q.z), 0, f.nz - 1) * f.ny + clampi(roundi(q.y), 0, f.ny - 1)) * f.nx + clampi(roundi(q.x), 0, f.nx - 1)


func _flood(f: Dictionary, from: Vector3) -> Dictionary:
	var d: PackedFloat32Array = f.d
	var nx: int = f.nx
	var ny: int = f.ny
	var seen := {}
	var todo := [_cell(f, from)]
	seen[todo[0]] = true
	while not todo.is_empty():
		var i: int = todo.pop_back()
		var x := i % nx
		var y := (i / nx) % ny
		var z := i / (nx * ny)
		for o in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var a: int = x + o.x
			var b: int = y + o.y
			var c: int = z + o.z
			if a < 0 or b < 0 or c < 0 or a >= nx or b >= ny or c >= int(f.nz):
				continue
			var j := (c * ny + b) * nx + a
			if not seen.has(j) and d[j] < 0.0:
				seen[j] = true
				todo.append(j)
	return seen


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")
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
