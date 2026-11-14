extends SceneTree

# Checks the things happening all round the race circuits (scripts/race_life.gd; Hayden's 14 Nov 2026 note: "I want
# the maps to feel like they are alive and things are happening all around"):
#
#   - Every circuit has at least four set pieces of at least three kinds, a blimp, and a crowd in its stand.
#   - Nothing in them is solid, so none of it can get in a racer's way.
#   - At rest nothing stands on the road, and once they've all gone off nothing's left lying on it either.
#   - Riding round goes off each set piece once a lap, ahead of you (never behind), and again the next lap.
#   - The crowd only cheers while you're near the stand.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_race_life.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.race_life_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.race_life_backup.cfg"

var failures := 0
var game: Node
var settings: Node
var races: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	races = root.get_node("Races")
	settings.tips = false
	settings.race_intros = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	races.reset()
	races.raced = 3
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	root.get_node("Clock").set("pulls_home", false)

	for id in races.TRACKS:
		var tr: Dictionary = races.TRACKS[id]
		if not tr.has("circuit"):
			continue
		change_scene_to_file(str(tr.scene))
		await _frames(4)
		await _until(func() -> bool:
			var tt: Node3D = races.track_node(id)
			return tt != null and tt.ready_to_race, 300)
		var c: Node3D = current_scene
		var life: Node3D = c.get_node_or_null("Life")
		check(life != null, "%s: things are going on round it" % tr.name)
		if life == null:
			continue
		var kinds := {}
		for s in life.sets:
			kinds[str(s.get_meta("kind"))] = true
		check(life.sets.size() >= 4 and kinds.size() >= 3, "%s: %d set pieces of %d kinds" % [tr.name, life.sets.size(), kinds.size()])
		check(life.get_node_or_null("Blimp") != null, "%s: a blimp circles overhead" % tr.name)
		check(life._fans.size() >= 10, "%s: a crowd in the stand (%d)" % [tr.name, life._fans.size()])
		var solid := life.find_children("*", "CollisionObject3D", true, false).size() + life.find_children("*", "CollisionShape3D", true, false).size()
		check(solid == 0, "%s: none of it is solid" % tr.name)
		var on_road := _on_road(c, life)
		check(on_road.is_empty(), "%s: nothing stands on the road at rest %s" % [tr.name, on_road])

		# Ride round two laps (the player's physics off, so the test puts them where it likes)
		var p := c.find_child("Player", true, false) as Node3D
		p.process_mode = Node.PROCESS_MODE_DISABLED
		var stand := c.get_node("Stand") as Node3D
		var cheer_near := 0
		var cheer_far := 0
		var early := []
		var seen := {}
		var total: float = c.total
		var d := 0.0
		var lap_counts: Array[int] = []
		while d < total * 2.0:
			var at: Vector3 = c.line[c.index_at(fmod(d, total))]
			p.global_position = at + Vector3.UP * 0.5
			await process_frame
			for s in life.sets:
				var key := "%s_%d" % [s.name, int(s.get_meta("fired"))]
				if int(s.get_meta("fired")) > 0 and not seen.has(key):
					seen[key] = true
					var ahead := fposmod(float(s.get_meta("d")) - fmod(d, total), total)
					if ahead < life.TRIGGER_NEAR - 2.0 or ahead > life.TRIGGER_FAR + 2.0:
						early.append("%s at %.0f m" % [s.name, ahead])
			if p.global_position.distance_to(stand.global_position) < 25.0:
				cheer_near += 1 if life.cheering else 0
			elif p.global_position.distance_to(stand.global_position) > 80.0:
				cheer_far += 1 if life.cheering else 0
			if lap_counts.is_empty() and d >= total:
				for s in life.sets:
					lap_counts.append(int(s.get_meta("fired")))
			d += 2.5
		var once := true
		for k in lap_counts.size():
			once = once and lap_counts[k] == 1
		check(once, "%s: each set piece goes off once in the first lap %s" % [tr.name, lap_counts])
		var twice := true
		for s in life.sets:
			twice = twice and int(s.get_meta("fired")) == 2
		check(twice, "%s: ...and again the next lap" % tr.name)
		check(early.is_empty(), "%s: each one goes off just ahead of you %s" % [tr.name, early])
		check(cheer_near > 0, "%s: the crowd cheers as you go by" % tr.name)
		check(cheer_far == 0, "%s: ...and not when you're far off" % tr.name)
		# Wait for everything to finish, then nothing's left on the road
		for i in 600:
			await physics_frame
		on_road = _on_road(c, life)
		check(on_road.is_empty(), "%s: nothing's left on the road afterwards %s" % [tr.name, on_road])
		p.process_mode = Node.PROCESS_MODE_INHERIT
	print("RESULT %s (%d failures)" % ["PASSED" if failures == 0 else "FAILED", failures])
	_finish()


func _on_road(c: Node3D, life: Node3D) -> Array:
	# Shown meshes low enough to be in a racer's way and over the road (the blimp's far up)
	var bad := []
	var hw: float = c.half_width()
	for m in life.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.transparency > 0.95:
			continue
		var g := mi.global_position
		var xz := Vector2(g.x, g.z)
		var road_y: float = c.line[c.nearest_index(xz)].y if c.has_method("nearest_index") else _road_y(c, xz)
		if g.y > road_y + 4.5 or g.y < road_y - 1.5:
			continue
		if c.off_road(xz) < hw + 0.5:
			bad.append("%s/%s" % [mi.get_parent().name, mi.name])
	return bad


func _road_y(c: Node3D, xz: Vector2) -> float:
	var best := INF
	var y := 0.0
	for pt in c.line:
		var dd := xz.distance_squared_to(Vector2(pt.x, pt.z))
		if dd < best:
			best = dd
			y = pt.y
	return y


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if failures > 0 else 0)
