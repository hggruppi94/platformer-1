extends SceneTree

# Checks the Hum Heads (scripts/stone_heads.gd), the five giant stone heads in Rhythm Springs: there are five, each
# standing on the floor inside the valley's walls, clear of the pools, the hot springs, the palms and everything else
# solid, facing in; they're solid; walking up to one makes it hum; before the beat's back all five humming gives
# nothing, and once it's back all five sing together for 5 sparkles, only once; standing beside one is shade; and a
# practice trip gives nothing.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_hum_heads.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.hum_heads_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.hum_heads_test_backup.cfg"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"
const BUILDER := preload("res://tools/build_rhythm_springs.gd")

var failures := 0
var game: Node
var portals: Node


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
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals = root.get_node("Portals")
	portals.home_calls.enabled = false
	portals.cleared_worlds.erase("rhythm_springs")
	var flags: Dictionary = root.get_node("Dialogue").flags
	flags.erase("hum_heads_song")
	change_scene_to_file(WORLD)
	await _frames(10)
	await _physics(4)
	var world := current_scene as Node3D
	var hh := world.get_node_or_null("Hum Heads")
	check(hh != null and hh.heads.size() == 5, "five Hum Heads stand in Rhythm Springs")
	if hh == null:
		_finish()
		return
	var space := world.get_world_3d().direct_space_state
	for i in hh.heads.size():
		var holder := hh.heads[i][0] as Node3D
		var at := holder.global_position
		var name := "Head %d" % (i + 1)
		check(Vector2(at.x, at.z).length() < BUILDER.FLOOR_R - 4.0, name + ": inside the valley's walls")
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(2.0, 3, 0).rotated(Vector3.UP, holder.rotation.y), at + Vector3(2.0, -3, 0).rotated(Vector3.UP, holder.rotation.y))
		var hit := space.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y - at.y) < 0.15, name + ": the floor's flat right beside it")
		var clear := true
		for e in BUILDER.POOLS:
			clear = clear and Vector2(at.x - e.x, at.z - e.y).length() > maxf(e.z, e.w) + 2.5
		for s in BUILDER.HOT_SPRINGS:
			clear = clear and Vector2(at.x - s.x, at.z - s.z).length() > 3.3 + 2.5
		for pa in BUILDER.PALMS:
			clear = clear and Vector2(at.x - pa.x, at.z - pa.z).length() > 3.0
		check(clear, name + ": clear of the pools, hot springs and palms")
		var own := holder.get_node("Stone") as StaticBody3D
		var shape := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.4, 4.0, 2.8)
		shape.shape = box
		shape.transform = Transform3D(Basis(Vector3.UP, holder.rotation.y), at + Vector3(0, 2.4, 0))
		shape.exclude = [own.get_rid()]
		var others := []
		for r in space.intersect_shape(shape, 8):
			var c := r.collider as Node
			if c is Area3D:
				continue
			others.append(str(c.name))
		check(others.is_empty(), name + ": nothing else solid where it stands %s" % [others])
		var to_mid := (Vector3.ZERO - at).normalized()
		check(holder.global_transform.basis.z.dot(to_mid) > 0.95, name + ": faces in, at the valley")
		check(world.in_shade(at + Vector3(0, 0.5, 0) + to_mid * 1.6), name + ": beside it is shade")
		var ray := PhysicsRayQueryParameters3D.create(at + to_mid * 4.0 + Vector3(0, 2.0, 0), at + Vector3(0, 2.0, 0))
		var h2 := space.intersect_ray(ray)
		check(not h2.is_empty() and h2.collider == own, name + ": it's solid")
	var p := current_scene.find_child("Player", true, false) as CharacterBody3D
	# Before the beat's back: they hum, but out of tune, and all five give nothing
	var before: int = game.sparkles
	for i in 5:
		await _visit(p, hh, i)
	check(not hh.heard.has(false), "walking up to each one makes it hum")
	check(game.sparkles == before and not flags.get("hum_heads_song", false), "before the beat's back: no song, no sparkles")
	# Once mended, all five together sing their song: 5 sparkles, once
	portals.cleared_worlds.append("rhythm_springs")
	hh.heard = [false, false, false, false, false]
	hh._cooldown = [0.0, 0.0, 0.0, 0.0, 0.0]
	for i in 5:
		await _visit(p, hh, i)
	check(flags.get("hum_heads_song", false) and game.sparkles == before + 5, "once the beat's back, all five sing: +5 sparkles (%d)" % (game.sparkles - before))
	check(not hh.sing_together() and game.sparkles == before + 5, "...and only once")
	# A practice trip keeps nothing
	flags.erase("hum_heads_song")
	portals.practice = true
	var b2: int = game.sparkles
	hh.sing_together()
	check(game.sparkles == b2, "a practice trip's song gives no sparkles")
	portals.practice = false
	_finish()


func _visit(p: CharacterBody3D, hh: Node, i: int) -> void:
	var holder := hh.heads[i][0] as Node3D
	p.global_position = holder.global_position + holder.global_transform.basis.z * 3.0 + Vector3(0, 0.9, 0)
	p.velocity = Vector3.ZERO
	await _frames(4)


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
