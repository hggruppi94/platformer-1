extends SceneTree

# Checks the town's Skate Park (tools/build_town.gd, _skate_park) and its goals (scripts/skate_goals.gd): the ramps,
# funbox, rail and ledge are there and grindable, the benches round town are grindable, a quarter pipe there sends
# her into a vert air, the S-K-A-T-E letters only count on the board and pay out when all five are got, and each other
# goal pays its sparkles once. Skating as a friend puts their town self out of sight. There are lots of rails round
# town, every box edge and round rim can be ground, and she can push up a hill.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_skate_park.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var dialogue: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(150.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	game._resume = {}
	game.pending_message = ""
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_"):
			dialogue.flags.erase(f)
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	game.riding = false
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var s: Node = p.get_node("Skate")
	var park := town.get_node_or_null("Skate Park") as Node3D
	check(park != null and park.has_method("complete"), "the town has a Skate Park with goals")
	if park == null:
		_end()
		return
	for piece in ["Quarter Pipe East", "Quarter Pipe West", "Funbox", "Flat Rail", "Ledge"]:
		var n := park.get_node_or_null(piece)
		check(n != null and n.find_children("*", "GrindRail", true, false).size() > 0, "...with a grindable " + piece)
	var benches := 0
	for r in tree_rails(town):
		if String(r.name).begins_with("Bench Grind"):
			benches += 1
	check(benches >= 6, "benches round town are grindable (%d)" % benches)

	# --- Riding the quarter pipe in town ---
	game.riding = true
	game.equipment_changed.emit()
	await _physics(2)
	var c := park.global_position
	# Nothing passing by may knock her off her board here (whatever's about at the save's time: on a busy run a
	# passer-by's hit made her bail before she reached the ramp)
	p.set("_invulnerable_timer", 30.0)
	# Put her right on the floor (not dropped onto it: on a busy run a drop sometimes landed as a bail)
	var drop := PhysicsRayQueryParameters3D.create(c + Vector3(1.0, 3.0, 1.5), c + Vector3(1.0, -2.0, 1.5))
	drop.exclude = [p.get_rid()]
	var floor_hit: Dictionary = (town as Node3D).get_world_3d().direct_space_state.intersect_ray(drop)
	var on_floor: Vector3 = floor_hit.position if floor_hit else c + Vector3(1.0, 0.0, 1.5)
	p.global_position = on_floor + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	s.state = s.State.ROLL
	await _physics(20)
	check(s.state == s.State.ROLL and s._grounded, "she rolls on the park floor (%s, %s, at %s from the park, riding %s)" % [
		s.State.keys()[s.state], "on the ground" if s._grounded else "in the air", p.global_position - c, game.riding])
	p.velocity = Vector3(11, 0, 0)
	s._yaw = PI / 2
	var vert := false
	var peak := 0.0
	for i in 150:
		await physics_frame
		vert = vert or s._vert
		peak = maxf(peak, p.global_position.y - c.y)
	check(vert and peak > 4.0, "the east quarter pipe sends her into a vert air (%.1f m up)" % peak)
	await _physics(60)
	p.set("_invulnerable_timer", 0.0)

	# --- The letters: only on the board, all five pay out ---
	var start_sparkles: int = game.sparkles
	game.riding = false
	game.equipment_changed.emit()
	var s_letter := park.get_node("Pickup S") as Area3D
	p.global_position = s_letter.global_position
	await _physics(6)
	check(s_letter.visible and not dialogue.flags.has("skate_letter_S"), "walking into a letter doesn't count")
	game.riding = true
	game.equipment_changed.emit()
	for l in ["S", "K", "A", "T", "E"]:
		var a := park.get_node("Pickup " + l) as Area3D
		p.global_position = a.global_position + Vector3(0, 3, 0)
		await _physics(3)
		s.state = s.State.AIR
		p.global_position = a.global_position
		p.velocity = Vector3.ZERO
		await _physics(3)
	check(park.is_done("letters"), "riding through all five letters finishes S-K-A-T-E")
	check(game.sparkles == start_sparkles + 5, "...and pays 5 sparkles (%d)" % (game.sparkles - start_sparkles))
	var board := park.find_child("Goals", true, false) as Label3D
	check(board.text.contains("★ Collect S-K-A-T-E"), "...and the board ticks it off")

	# --- The other goals, from tricks done in the park ---
	p.global_position = c + Vector3(1.0, 1.3, 1.5)
	await _physics(10)
	var t: SkateTricks = s.tricks
	start_sparkles = game.sparkles
	t.banked.emit(3000, "Kickflip + 50-50 + 540")
	check(park.is_done("combo") and park.is_done("spin"), "a 3,000 combo with a 540 in it does two goals")
	t.live_done.emit("50-50", 3.4)
	t.live_done.emit("Manual", 1.0)
	check(park.is_done("grind") and not park.is_done("manual"), "a long grind counts, a short manual doesn't")
	t.live_done.emit("Manual", 3.2)
	check(park.is_done("manual"), "...a long one does")
	t.banked.emit(1000, "Galaxy Twirl")
	check(park.is_done("special"), "doing her special counts")
	t.banked.emit(11000, "Kickflip")
	check(park.is_done("score"), "scoring 15,000 here counts")
	check(game.sparkles == start_sparkles + 5 + 3 + 3 + 3 + 5 + 8, "...and they pay their sparkles (%d)" % (game.sparkles - start_sparkles))
	var before: int = game.sparkles
	t.banked.emit(5000, "Kickflip + 540")
	check(game.sparkles == before, "a goal only pays once")

	# --- Skating as Dash puts the town's own Dash (and his bike) out of sight until he's done ---
	check(park.find_child("RiderSelect", true, false) != null, "the Skate Park has a Skaters' Corner")
	var dash_npc := town.find_child("Dash", true, false) as Node3D
	var bike := town.find_child("Bike", true, false) as Node3D
	p.set_rider("dash")
	await _physics(3)
	check(not dash_npc.visible and not bike.visible and dash_npc.process_mode == Node.PROCESS_MODE_DISABLED,
		"while you skate as Dash, the town's Dash and his bike step out of sight")
	p.set_rider("nina")
	await _physics(3)
	check(dash_npc.visible and bike.visible, "...and come back when it's Nina again")

	# --- Far from the park, nothing counts ---
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_goal_"):
			dialogue.flags.erase(f)
	p.global_position = c + Vector3(60, 5, 0)
	await _physics(3)
	t.banked.emit(3000, "540")
	check(not park.is_done("combo"), "tricks done away from the park don't count for its goals")
	for f in dialogue.flags.keys():
		if String(f).begins_with("skate_"):
			dialogue.flags.erase(f)

	# --- Rails all round town, and every edge grindable ---
	var town_rails := town.get_node_or_null("Town Rails")
	var rail_count := town_rails.find_children("*", "GrindRail", true, false).size() if town_rails else 0
	check(rail_count >= 60, "lots of rails round town (%d)" % rail_count)
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var edges := town.get_node_or_null("EdgeRails")
	var edge_count := edges.get_child_count() if edges else 0
	check(edge_count > 200, "the edges of the town's boxes and round tops are grindable (%d)" % edge_count)
	var ok_grind := 0
	for k in [5, 50, 150]:
		if edges == null or k >= edge_count:
			continue
		var r := edges.get_child(k) as GrindRail
		var on: Vector3 = r.point_at(r.length() * 0.5)
		p.global_position = on + Vector3(0, 0.8 + 0.6, 0)
		p.velocity = Vector3(0, -1, 0)
		s._pop()
		s._grind_buffer = 0.2
		if s._try_grind():
			ok_grind += 1
		s._leave_rail(Vector3.ZERO)
		s.state = s.State.AIR
		await _physics(2)
	check(ok_grind == 3, "she locks onto edges anywhere (%d of 3)" % ok_grind)
	check(GrindRail.near(c).size() > 0, "rails are filed by where they are, so she only looks at the ones nearby")

	# --- Pushing up a hill ---
	var hill := _find_hill(town)
	check(hill.size() > 0, "found a hill to push up")
	if hill.size() > 0:
		var foot: Vector3 = hill[0]
		var up_dir: Vector3 = hill[1]
		p.global_position = foot + Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		s.state = s.State.ROLL
		s._yaw = atan2(up_dir.x, up_dir.z)
		(p.get_node("SpringArm3D") as Node3D).rotation.y = atan2(-up_dir.x, -up_dir.z)
		await _physics(10)
		var start := p.global_position
		Input.action_press("move_forward")
		await _physics(180)
		Input.action_release("move_forward")
		var climbed := p.global_position.y - start.y
		var went := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).dot(Vector2(up_dir.x, up_dir.z))
		check(climbed > 1.0 and went > 4.0, "she can push up a hill (%.1f m up, %.1f m along, %.0f degrees)" % [climbed, went, hill[2]])
	_end()


func _find_hill(town: Node) -> Array:
	# A stretch of open ground sloping 10 to 22 degrees: [the bottom, uphill direction, the slope in degrees]
	var space := (town as Node3D).get_world_3d().direct_space_state
	for x in range(-120, 130, 6):
		for z in range(-120, 100, 6):
			var hit := _ground_hit(space, Vector3(x, 80, z))
			if hit.is_empty():
				continue
			var n: Vector3 = hit.normal
			var deg := rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))
			if deg < 10.0 or deg > 22.0:
				continue
			var up_dir := -Vector3(n.x, 0, n.z).normalized()
			# The same slope for a good way up, with nothing in the way
			var ok := true
			for k in range(1, 6):
				var h2 := _ground_hit(space, hit.position + up_dir * k * 1.5 + Vector3(0, 40, 0))
				if h2.is_empty() or (h2.normal as Vector3).y < 0.85 or (h2.normal as Vector3).y > 0.99:
					ok = false
					break
			if ok:
				return [hit.position, up_dir, deg]
	return []


func _ground_hit(space: PhysicsDirectSpaceState3D, from: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 160)
	return space.intersect_ray(q)


func tree_rails(n: Node) -> Array:
	return n.find_children("*", "GrindRail", true, false)


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
