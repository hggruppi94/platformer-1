extends SceneTree

# Checks Mr. Palmer's Galaxity form (models/characters/mr_palmer_alien.glb, scripts/palmer_trunk.gd): he's the alien
# with the trunk, his tea table stands in front of his spot by the Town Hall window, and when he sips he curls his trunk
# round the teacup, lifts it off the table and puts it back. At bedtime he goes in and the table stays by the window.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_palmer.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FAR_AWAY := Vector3(-140, 2, 100)            # the empty southwest corner, far from everyone's places

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var clock := root.get_node("Clock")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as Node3D
	p.global_position = FAR_AWAY
	clock.set_time(1, 10 * 60.0, true)
	await _physics(8)

	var palmer := town.find_child("MrPalmer", true, false) as Node3D
	var trunk := palmer.get_node_or_null("Trunk")
	var skel := palmer.find_child("Skeleton3D", true, false) as Skeleton3D
	var anim := palmer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(skel != null and skel.find_bone("trunk.0") >= 0 and skel.find_bone("trunk.7") >= 0, "Mr. Palmer has his trunk bones")
	check(anim != null and anim.has_animation("idle") and anim.has_animation("walk") and anim.has_animation("grab"),
		"...and idle, walk and grab")
	var table := town.find_child("PalmerTeaTable", true, false) as Node3D
	check(table != null, "his tea table is in town")
	if trunk == null or table == null:
		_end()
		return
	var cup := table.get_node("Teacup") as Node3D
	var gap := Vector2(table.global_position.x - palmer.global_position.x, table.global_position.z - palmer.global_position.z).length()
	check(gap > 0.5 and gap < 1.0, "the table stands just in front of him at 10 AM (%.2f m)" % gap)
	# He turns to his "face" point gradually, and he may have been facing anywhere at the save's time, so give him a
	# second to finish turning before checking which way he faces.
	await _physics(60)
	var ahead := palmer.global_transform.basis.z
	var to_table := table.global_position - palmer.global_position
	check(Vector2(ahead.x, ahead.z).dot(Vector2(to_table.x, to_table.z).normalized()) > 0.9, "...right where he's facing")
	var home := cup.global_position

	# A sip: the cup leaves the table on the end of his trunk, goes up, and comes back down to the table
	trunk.call("sip")
	var lifted := 0.0
	var near_tip := true
	var held := false
	var until := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < until:
		await process_frame
		if held and not trunk.call("is_holding_cup"):
			break
		if trunk.call("is_holding_cup"):
			held = true
			lifted = maxf(lifted, cup.global_position.y - home.y)
			near_tip = near_tip and cup.global_position.distance_to(trunk.call("tip_position")) < 0.15
	check(held and lifted > 0.3, "he lifts the teacup with his trunk (%.2f m up)" % lifted)
	check(near_tip, "...holding it on the end of his trunk the whole time")
	await create_timer(0.5).timeout
	check(cup.global_position.distance_to(home) < 0.01 and not trunk.call("is_holding_cup"), "...and puts it back on the table")
	check(anim.current_animation == "idle", "then he goes back to standing (%s)" % anim.current_animation)

	# Bedtime: he goes in, the table stays by the window
	clock.set_time(1, 21 * 60.0, true)
	await _physics(8)
	check(not palmer.visible and table.visible and table.global_position.distance_to(home) < 1.0,
		"at 9 PM he's gone in and the tea table stays by the window")
	_end()


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
