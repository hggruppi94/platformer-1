extends SceneTree

# Checks the game-feel helper (scripts/juice.gd): every call is safe with Screen shake at 0 and rumble off, and with
# both on, with and without a camera or a scene; the shake settles and gives the camera back exactly as it was; the
# hit-pause is short and puts the game speed back (the Assist speed and the gadget wheel's slow-down too); Reduce
# motion stops the shake and the pause; the sparkle chime climbs on quick pickups and starts low again after a
# breather; every little sound can be made; squash springs back to the node's own size; the settings save and show
# on the Assist tab; and every action in the game that should have feedback calls it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_juice.gd
#
# Your own save is put aside (under its own name) and put back at the end. Your settings are put back too.

const SAVE := "user://save.json"
const BACKUP := "user://save.juice_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var juice := root.get_node("Juice")
	var settings := root.get_node("Settings")
	var keep := {"screen_shake": settings.screen_shake, "rumble": settings.rumble, "reduce_motion": settings.reduce_motion,
		"game_speed": settings.game_speed}
	settings.reduce_motion = false
	settings.game_speed = 1.0
	Engine.time_scale = 1.0

	# --- Safe with nothing about: no scene, no camera ---
	for on in [false, true]:
		settings.screen_shake = 1.0 if on else 0.0
		settings.rumble = on
		_every_call(juice, null)
		await _frames(3)
		check(true, "every call is safe with no scene or camera (shake and rumble %s)" % ("on" if on else "off"))
	await create_timer(0.2, true, false, true).timeout
	check(is_equal_approx(Engine.time_scale, 1.0), "...and the game speed is back to normal")

	# --- In town, with a camera ---
	root.get_node("Game")._resume = {}
	root.get_node("Clock").pulls_home = false
	change_scene_to_file(TOWN)
	for i in 10:
		await process_frame
	var cam := root.get_viewport().get_camera_3d()
	check(cam != null, "the town has a camera")
	var player := current_scene.find_child("Player", true, false) as Node3D
	var h0: float = cam.h_offset
	var v0: float = cam.v_offset

	settings.screen_shake = 0.0
	settings.rumble = false
	_every_call(juice, player)
	await _frames(4)
	check(juice.trauma == 0.0 and is_equal_approx(cam.h_offset, h0) and is_equal_approx(cam.v_offset, v0),
		"Screen shake at 0: every call is safe, and the camera never moves")
	await create_timer(0.2, true, false, true).timeout

	settings.screen_shake = 1.0
	settings.rumble = true
	juice.shake(0.5)
	await _frames(3)
	check(juice.trauma > 0.0 and (not is_equal_approx(cam.h_offset, h0) or not is_equal_approx(cam.v_offset, v0)),
		"Screen shake on: the camera wobbles")
	var moved := absf(cam.h_offset - h0) + absf(cam.v_offset - v0)
	check(moved < juice.MAX_OFFSET * 2.0, "...gently (%.2f m at most)" % moved)
	await create_timer(1.2, true, false, true).timeout
	await _frames(3)
	check(juice.trauma == 0.0 and is_equal_approx(cam.h_offset, h0) and is_equal_approx(cam.v_offset, v0),
		"...settles in about a second, and gives the camera back exactly as it was")
	settings.screen_shake = 0.5
	juice.shake(1.0)
	check(juice.trauma <= 0.51, "the slider scales it (50%%: %.2f)" % juice.trauma)
	juice.trauma = 0.0
	settings.screen_shake = 1.0
	settings.reduce_motion = true
	juice.shake(1.0)
	juice.hitstop(0.08)
	check(juice.trauma == 0.0 and not juice.stopped() and is_equal_approx(Engine.time_scale, 1.0),
		"Reduce motion: no shake and no hit-pause")
	settings.reduce_motion = false
	await _frames(2)
	cam.h_offset = h0
	cam.v_offset = v0

	# --- The hit-pause ---
	juice.hitstop(0.06)
	check(juice.stopped() and Engine.time_scale < 0.1, "a hit-pause freezes the game for a moment")
	await create_timer(0.15, true, false, true).timeout
	await _frames(2)
	check(not juice.stopped() and is_equal_approx(Engine.time_scale, 1.0), "...and lets go again straight after")
	juice.hitstop(5.0)
	await create_timer(0.16, true, false, true).timeout
	await _frames(2)
	check(not juice.stopped(), "...never longer than a tenth of a second, whatever it's asked")
	Engine.time_scale = 0.2                             # the gadget wheel's slow-down (or a slow Assist speed)
	juice.hitstop(0.05)
	juice.hitstop(0.05)                                 # two at once
	await create_timer(0.12, true, false, true).timeout
	await _frames(2)
	check(is_equal_approx(Engine.time_scale, 0.2), "...and puts back whatever speed was there before (%.2f)" % Engine.time_scale)
	Engine.time_scale = 1.0
	paused = true
	juice.hitstop(0.05)
	check(not juice.stopped(), "...but not while the game's paused")
	paused = false

	# --- The sparkle chime ---
	var steps := []
	for i in 5:
		juice.chime_pickup()
		steps.append(juice.chime_step())
	check(steps == [0, 1, 2, 3, 4], "quick sparkle pickups climb the scale (%s)" % str(steps))
	for i in 10:
		juice.chime_pickup()
	check(juice.chime_step() == juice.CHIME_STEPS.size() - 1, "...up to an octave, and no further")
	await create_timer(juice.CHIME_WINDOW + 0.1, true, false, true).timeout
	juice.chime_pickup()
	check(juice.chime_step() == 0, "...and start low again after a breather")
	var all_made := true
	for kind in ["chime", "pop", "tick", "whoosh", "thud", "sparkle", "buzz"]:
		var s: AudioStreamWAV = juice._make(kind)
		all_made = all_made and s != null and s.data.size() > 100
	check(all_made, "every little sound can be made in code (no .wav files needed)")
	check(juice._make("nonsense") == null, "...and an unknown one is just quiet")

	# --- Squash and stretch ---
	var visual := player.get_node("Visual") as Node3D
	var base := visual.scale
	juice.squash(visual, 0.3, 0.2)
	# Watch every frame rather than once, since a slow headless frame can jump right past the squash.
	var squashed := false
	var until := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < until and not squashed:
		await process_frame
		squashed = not visual.scale.is_equal_approx(base)
	check(squashed, "squash: the hero squashes (time scale %.2f)" % Engine.time_scale)
	juice.squash(visual, 0.3, 0.2)                     # again before it's done
	await create_timer(0.4, true, false, true).timeout
	check(visual.scale.is_equal_approx(base), "...and springs back to their own size, even squashed twice")
	juice.squash(null)
	check(true, "squash with nothing to squash is safe")

	# --- Settings ---
	check("screen_shake" in settings._props() and "rumble" in settings._props(), "Screen shake and Controller rumble are saved settings")
	var menu := root.get_node("PauseMenu")
	var g := GridContainer.new()
	root.add_child(g)
	var tabs := TabContainer.new()
	root.add_child(tabs)
	menu._tab_assist(tabs)
	var labels := tabs.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("Screen shake" in labels and "Controller rumble" in labels, "...and both are on the Assist tab")
	tabs.queue_free()
	g.queue_free()

	# --- Everything that should give feedback calls it ---
	var wants := {
		"scenes/player/player.gd": "jump, double jump, landing, roll, getting hurt",
		"scripts/sparkle.gd": "sparkle pickup",
		"scripts/star_popper.gd": "every gadget's shot",
		"scripts/star_bubble.gd": "bubble pops",
		"scripts/gloop.gd": "stomps",
		"scripts/gloop_king.gd": "the Gloop King's hits, belly-flop and pop",
		"scenes/player/skate.gd": "ollie, landing, grinds, bails",
		"scenes/player/skate_tricks.gd": "combo payout",
		"scripts/races.gd": "countdown, boosts, power-ups",
		"scripts/quests.gd": "quest complete",
		"scripts/requests.gd": "request complete",
		"scripts/watches.gd": "watch pickup",
		"scripts/shop.gd": "buying",
		"scripts/door.gd": "doors and portals",
		"scripts/fizz_bomb.gd": "the Fizz Flinger's splash",
		"scripts/disco_ball.gd": "the Disco Ball",
	}
	for path in wants:
		var src := FileAccess.get_file_as_string("res://" + path)
		check(src.contains("Juice.") or src.contains("\"Juice\""), "%s has feedback (%s)" % [path.get_file(), wants[path]])

	for k in keep:
		settings.set(k, keep[k])
	settings.apply()
	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _every_call(juice: Node, at: Node3D) -> void:
	var parent: Node = at.get_parent() if at else null
	var pos := at.global_position if at else Vector3.ZERO
	juice.shake(0.5)
	juice.hitstop(0.03)
	juice.burst(parent, pos, Color.WHITE)
	juice.squash(at.get_node("Visual") if at else null, 0.2)
	juice.rumble(0.5, 0.1, 0.5)
	juice.hit(parent, pos, Color.WHITE, true)
	juice.hit(parent, pos, Color.WHITE, false)
	for kind in ["chime", "pop", "tick", "whoosh", "thud", "sparkle", "buzz", "nonsense"]:
		juice.blip(kind)
	juice.chime_pickup()


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


func _frames(n: int) -> void:
	for i in n:
		await process_frame
