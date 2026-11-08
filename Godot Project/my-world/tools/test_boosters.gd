extends SceneTree

# Checks the boosters round the Void and Stars Hollow (scripts/boosters.gd): strips, ramps and coin lines in both
# towns; every one is put in at play time on dry ground with nothing floating, room to come at it and nothing in the
# way where it sends you; each strip and ramp boosts you on foot and on the board, past your usual speed, and the
# boost wears off; a ramp pops you up; a coin goes when you take it and comes back; and the map has an arrow for each.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boosters.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.boosters_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.boosters_test_backup.cfg"

var failures := 0
var game: Node
var boosters: Node


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
	game = root.get_node("Game")
	boosters = root.get_node("Boosters")
	var settings := root.get_node("Settings")
	settings.tips = false
	settings.skate_assist = 1
	game._resume = {}
	game.pending_message = ""
	game.riding = false
	root.get_node("Races").reset()
	root.get_node("Dialogue").reset()
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(1, 12 * 60.0, true)

	var all: Array = boosters.BOOSTERS
	var kinds := {}
	for b in all:
		kinds["%s %s" % [b.scene, b.kind]] = int(kinds.get("%s %s" % [b.scene, b.kind], 0)) + 1
	for sc in ["town", "earth"]:
		for k in ["strip", "ramp", "coins"]:
			check(int(kinds.get("%s %s" % [sc, k], 0)) >= 2, "%s has at least 2 of kind %s (%d)" % [sc, k, int(kinds.get("%s %s" % [sc, k], 0))])

	for sc in ["town", "earth"]:
		change_scene_to_file(boosters.SCENES[sc])
		await _frames(8)
		await _physics(4)
		await _check_scene(sc)

	await _check_boosts()
	_finish()


func _check_scene(sc: String) -> void:
	var s := current_scene as Node3D
	var holder := s.get_node_or_null("Boosters")
	var here: Array = boosters.in_scene(sc)
	var want := 0
	for b in here:
		want += int(b.get("count", 1)) if b.kind == "coins" else 1
	check(holder != null and holder.get_child_count() == want, "%s: all %d boosters are put in (%d)" % [sc, want, holder.get_child_count() if holder else 0])
	if holder == null:
		return
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var space := s.get_world_3d().direct_space_state
	var floating: Array[String] = []
	var wet: Array[String] = []
	var tilted: Array[String] = []
	var blocked: Array[String] = []
	var crowded: Array[String] = []
	for n in holder.get_children():
		var b := n as Node3D
		var kind := str(b.get_meta("kind"))
		var label := "%s (%s, %.0f, %.0f)" % [b.name, b.get_meta("where"), b.global_position.x, b.global_position.z]
		if not bool(b.get_meta("grounded", false)):
			floating.append(label)
			continue
		var feet := b.global_position - (Vector3.UP * 1.0 if kind == "coins" else Vector3.ZERO)
		# Nothing floats: straight down from it there's ground within a hand's width
		var q := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.3, feet + Vector3.DOWN * 0.4)
		q.exclude = [p.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			floating.append(label)
		if feet.y < -0.55 or _in_water(space, feet + Vector3.UP * 0.3):
			wet.append(label)
		if kind != "coins" and b.global_basis.y.y < 0.9:
			tilted.append(label)
		# Room to come at it and nothing in the way where it sends you: rays at knee and chest height from 4 m before
		# it to 6 m past it (10 m past a ramp, where you come down), each end on the ground under it
		var dir: Vector3 = b.get_meta("dir")
		var side := Vector3(-dir.z, 0, dir.x)
		for lane in ([-0.9, 0.0, 0.9] if kind != "coins" else [0.0]):
			var a := _ground(space, feet - dir * 4.0 + side * lane, p)
			var e := _ground(space, feet + dir * (10.0 if kind == "ramp" else 6.0) + side * lane, p)
			for h in [0.6, 1.3]:
				var r := PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, e + Vector3.UP * (h + maxf(e.y - a.y, 0.0)))
				r.exclude = [p.get_rid()]
				var rh := space.intersect_ray(r)
				if not rh.is_empty() and rh.collider is StaticBody3D and not (rh.collider as Node).is_in_group("booster") and blocked.size() < 12:
					blocked.append("%s by %s/%s" % [label, (rh.collider as Node).get_parent().name, (rh.collider as Node).name])
					break
		for o in holder.get_children():
			if o != b and o.get_meta("index") != b.get_meta("index") and (o as Node3D).global_position.distance_to(b.global_position) < 5.0:
				crowded.append(label)
				break
	check(floating.is_empty(), "%s: every booster sits on the ground (%s)" % [sc, ", ".join(floating)])
	check(wet.is_empty(), "%s: ...on dry ground (%s)" % [sc, ", ".join(wet)])
	check(tilted.is_empty(), "%s: strips and ramps lie on fairly flat ground (%s)" % [sc, ", ".join(tilted)])
	check(blocked.is_empty(), "%s: room to come at each one and nothing in the way where it sends you (%s)" % [sc, ", ".join(blocked)])
	check(crowded.is_empty(), "%s: they're spread out (%s)" % [sc, ", ".join(crowded)])
	# Race pads and boosters don't sit on top of each other
	var near_pad: Array[String] = []
	for t in s.get_children():
		if t.get("pads") is Array:                         # a race track (scripts/race_track.gd)
			for pad in t.get("pads"):
				for n in holder.get_children():
					if (n as Node3D).global_position.distance_to((pad as Node3D).global_position) < 6.0:
						near_pad.append(str(n.name))
	check(near_pad.is_empty(), "%s: no booster on top of a race's boost pad (%s)" % [sc, ", ".join(near_pad)])
	# Ramps are solid: none on a race's line, where they'd be in the racers' way
	var on_line: Array[String] = []
	for t in s.get_children():
		if t.get("line") is PackedVector3Array and not bool(t.get("sky")):
			for n in holder.get_children():
				if str(n.get_meta("kind")) != "ramp":
					continue
				for pt in t.get("line"):
					if Vector2(pt.x, pt.z).distance_to(Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z)) < 5.0:
						on_line.append(str(n.name))
						break
	check(on_line.is_empty(), "%s: no ramp on a race's line (%s)" % [sc, ", ".join(on_line)])
	# The map has an arrow for each strip and ramp and each coin line
	check(boosters.marks().size() == here.size(), "%s: the map shows an arrow for each booster (%d)" % [sc, boosters.marks().size()])


const RAMP_RISE := 0.9


func _ground(space: PhysicsDirectSpaceState3D, at: Vector3, p: CollisionObject3D) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 6.0)
	q.exclude = [p.get_rid()]
	var skip: Array[RID] = [p.get_rid()]
	for k in 5:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return at
		if hit.collider is StaticBody3D and not (hit.collider as Node).is_in_group("booster"):
			return hit.position
		skip.append(hit.rid)
	return at


func _in_water(space: PhysicsDirectSpaceState3D, at: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = at
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in space.intersect_point(q, 16):
		var n := hit.collider as Node
		if n and n.get_script() and String(n.get_script().resource_path).ends_with("water.gd"):
			return true
	return false


func _check_boosts() -> void:
	change_scene_to_file(boosters.SCENES.town)
	await _frames(8)
	await _physics(4)
	var s := current_scene as Node3D
	var p := s.find_child("Player", true, false) as CharacterBody3D
	var holder := s.get_node("Boosters")
	var strip: Node3D
	var ramp: Node3D
	var coin: Node3D
	for n in holder.get_children():
		match str(n.get_meta("kind")):
			"strip":
				strip = n if strip == null else strip
			"ramp":
				ramp = n if ramp == null else ramp
			"coins":
				coin = n if coin == null else coin
	var walk: float = p.speed

	# --- On foot ---
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	var dir: Vector3 = strip.get_meta("dir")
	p.global_position = strip.global_position - dir * 2.0 + Vector3.UP * 0.9
	p.velocity = dir * walk
	p.visual.rotation.y = atan2(dir.x, dir.z)
	var before: int = boosters.used
	await _physics(30)
	check(boosters.used > before, "running over a boost strip boosts you on foot")
	var spd := Vector2(p.velocity.x, p.velocity.z).length()
	check(spd > walk + 3.0, "...well past running speed (%.1f m/s, running is %.1f)" % [spd, walk])
	await _physics(180)
	spd = Vector2(p.velocity.x, p.velocity.z).length()
	check(spd < walk + 0.5, "...and it wears off (%.1f m/s)" % spd)

	# A ramp on foot: boosted and popped up off it
	dir = ramp.get_meta("dir")
	p.global_position = ramp.global_position - dir * 3.0 + Vector3.UP * 0.9
	p.velocity = dir * walk
	p.visual.rotation.y = atan2(dir.x, dir.z)
	before = boosters.used
	var top := p.global_position.y
	for i in 90:
		p.velocity.x = dir.x * maxf(walk, Vector2(p.velocity.x, p.velocity.z).length())
		p.velocity.z = dir.z * maxf(walk, Vector2(p.velocity.x, p.velocity.z).length())
		await physics_frame
		top = maxf(top, p.global_position.y)
	check(boosters.used > before, "running up a booster ramp boosts you")
	check(top > ramp.global_position.y + 2.5, "...and pops you high up off it (%.1f m up)" % (top - ramp.global_position.y))

	# A coin: gone when taken, back later. (Facing across its line, so the little rush doesn't carry her into the next.)
	var cdir: Vector3 = coin.get_meta("dir")
	p.visual.rotation.y = atan2(-cdir.z, cdir.x)
	p.velocity = Vector3.ZERO
	p.global_position = coin.global_position + Vector3.DOWN * 0.2
	before = boosters.used
	await _physics(3)
	check(boosters.used == before + 1, "taking a booster coin gives a boost")
	check(not (coin.get_node("Spin") as Node3D).visible, "...and the coin goes")
	await _physics(10)
	check(boosters.used == before + 1, "...only the once")
	coin.set_meta("gone", 0.05)
	p.global_position += Vector3(0, 0, 30)
	await _physics(10)
	check((coin.get_node("Spin") as Node3D).visible, "...and it comes back after a while")

	# --- On the board ---
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var sk: Node = p.get_node("Skate")
	dir = strip.get_meta("dir")
	await _physics(100)                                  # (the strip's wait from before runs out)
	p.global_position = strip.global_position - dir * 2.5 + Vector3.UP * 0.85
	p.velocity = dir * 6.0
	await _physics(25)
	check(sk.boosting(), "riding over a boost strip boosts the board")
	spd = Vector2(p.velocity.x, p.velocity.z).length()
	check(spd > 10.0, "...past pushing speed (%.1f m/s)" % spd)
	await _physics(300)
	check(not sk.boosting(), "...and it wears off")
	check(not sk.is_bailing(), "going fast never makes you crash")
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
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
