extends SceneTree

# Checks the bumps and boinks (scripts/bumps.gd): running into a wall bounces her back with a puff of smoke, a sound
# that fits what it is (scripts/surfaces.gd wall_kind) and a squash; soft things bounce further; a walk-in is a little
# one and leaning on a wall nothing; a ceiling bonk; on a board, a head-on bump rolls her away backwards, and a kerb
# she rolls up is no bump at all; the settings (Bumps and boinks, Rumble strength) are saved, on the Assist tab, and
# Bumps and boinks off stops it all. Built on a test floor high over the Practice Park, so nothing else gets in the way.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_bumps.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.bumps_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.bumps_backup.cfg"
const PARK := "res://scenes/skate/test_park.tscn"
const Bumps := preload("res://scripts/bumps.gd")
const UP := 200.0                         # the test floor's top

var failures := 0
var game: Node
var settings: Node
var p: CharacterBody3D
var s: Node
var walls := {}


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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	settings.bumps = true
	settings.rumble = true
	settings.rumble_strength = 1.0
	settings.screen_shake = 1.0
	settings.reduce_motion = false
	settings.tips = false
	game._resume = {}
	change_scene_to_file(PARK)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	s = p.get_node("Skate")
	_build()
	await _physics(2)

	_kinds()
	_sounds_and_settings()
	await _on_foot()
	await _on_board()
	await _echo()
	_finish()


# -----------------------------------------------------------------------------
# The test floor: a big slab with a wooden crate, a mushroom, a stone wall, a roof and a kerb on it
# -----------------------------------------------------------------------------
func _build() -> void:
	_box("Test Floor", Vector3(0, UP - 0.5, 0), Vector3(80, 1, 80))
	walls.crate = _box("Test Crate", Vector3(-20, UP + 1.5, -3), Vector3(4, 3, 1))
	walls.mushroom = _box("Test Mushroom", Vector3(0, UP + 1.5, -3), Vector3(4, 3, 1))
	walls.stone = _box("Test Block", Vector3(20, UP + 1.5, -3), Vector3(4, 3, 1))
	walls.roof = _box("Test Shelter", Vector3(-20, UP + 2.6, 20), Vector3(4, 0.4, 4))
	walls.kerb = _box("Test Kerb", Vector3(20, UP + 0.1, 20), Vector3(6, 0.2, 1))
	walls.wall = _box("Test Wall", Vector3(0, UP + 1.5, 30), Vector3(40, 3, 1))
	walls.tunnel = _box("Test Tunnel Roof", Vector3(-30, UP + 4.0, -25), Vector3(6, 0.5, 10))


func _box(name: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	b.add_child(shape)
	current_scene.add_child(b)
	b.global_position = at
	return b


func _kinds() -> void:
	check(Surfaces.wall_kind(walls.crate) == "wood", "a crate is wood")
	check(Surfaces.wall_kind(walls.mushroom) == "soft", "a mushroom is soft")
	check(Surfaces.wall_kind(walls.stone) == "stone", "anything else is stone")
	check(Surfaces.wall_kind(null) == "stone", "...and nothing is stone too")
	var odd := Node3D.new()
	odd.name = "Odd Thing"
	odd.set_meta("surface", "crystal")
	current_scene.add_child(odd)
	check(Surfaces.wall_kind(odd) == "crystal", "a thing can say what it is (meta \"surface\")")
	check(Surfaces.wall_kind(p) == "soft", "bumping into someone is a soft boink")


func _sounds_and_settings() -> void:
	var juice := root.get_node("Juice")
	var made := true
	for kind in ["boink", "bonk", "clunk", "clink", "squish"]:
		var w: AudioStreamWAV = juice._make(kind)
		made = made and w != null and w.data.size() > 100
	check(made, "every bump sound can be made in code")
	for kind in Bumps.SOUNDS:
		check(juice._make(Bumps.SOUNDS[kind][0]) != null, "%s has a sound" % kind)
	settings.rumble_strength = 0.5
	check(is_equal_approx(juice.rumble_scale(), 0.5), "Rumble strength scales the rumble")
	settings.rumble = false
	check(juice.rumble_scale() == 0.0, "...and Controller rumble off is none at all")
	settings.rumble = true
	settings.rumble_strength = 1.0
	check("bumps" in settings._props() and "rumble_strength" in settings._props(), "Bumps and boinks and Rumble strength are saved settings")
	var tabs := TabContainer.new()
	root.add_child(tabs)
	root.get_node("PauseMenu")._tab_assist(tabs)
	var labels := tabs.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check("Bumps and boinks" in labels and "Rumble strength" in labels and "Screen shake" in labels,
		"...and on the Assist tab, with Screen shake")
	tabs.queue_free()


# -----------------------------------------------------------------------------
# On foot
# -----------------------------------------------------------------------------
func _on_foot() -> void:
	if game.riding:
		game.toggle_skateboard()
	await _physics(3)
	check(not game.riding, "on foot")

	var hit := await _run_into(walls.crate, 9.0)
	check(not hit.is_empty() and hit.kind == "wood" and not hit.head, "running into a crate is a woody bump (%s)" % str(hit))
	check(p.velocity.z > 1.0, "...that bounces her back off it (%.1f m/s back)" % p.velocity.z)
	check(current_scene.find_child("Bump Smoke", true, false) != null, "...with a puff of smoke")
	var wood_back: float = p.velocity.z
	await _physics(30)
	check(p.global_position.z > walls.crate.global_position.z + 0.95, "...and she ends up a bit back from it (%.2f m off)" %
		(p.global_position.z - walls.crate.global_position.z - 0.5))

	hit = await _run_into(walls.mushroom, 9.0)
	check(not hit.is_empty() and hit.kind == "soft", "a mushroom is a soft boink")
	check(p.velocity.z > wood_back, "...and bounces her further (%.1f m/s, wood %.1f)" % [p.velocity.z, wood_back])

	hit = await _run_into(walls.stone, 5.0)
	check(not hit.is_empty() and hit.kind == "stone" and float(hit.strength) < 0.3, "walking into a wall is a little stony bump (%.2f)" % float(hit.get("strength", -1)))
	hit = await _run_into(walls.stone, 2.0)
	check(hit.is_empty(), "creeping into one is no bump at all")
	hit = await _run_into(walls.stone, 12.0)
	check(not hit.is_empty() and float(hit.strength) > 0.9, "a sprint into it is a big one (%.2f)" % float(hit.get("strength", -1)))
	# Leaning on it: no bump after the first
	_place(walls.stone.global_position + Vector3(0, -1.5 + 1.0, 0.86))
	var leaned := 0
	for i in 40:
		p.velocity = Vector3(0, p.velocity.y, -5.0)
		if p.has_meta("last_bump"):
			p.remove_meta("last_bump")
		await physics_frame
		if p.has_meta("last_bump"):
			leaned += 1
	check(leaned <= 3, "pushing on a wall for a while doesn't keep rattling (%d bumps in 40 frames)" % leaned)

	settings.bumps = false
	hit = await _run_into(walls.crate, 9.0)
	check(hit.is_empty(), "Bumps and boinks off: nothing")
	settings.bumps = true

	# A ceiling bonk
	_place(walls.roof.global_position + Vector3(0, -2.6 + 1.0, 0))
	await _physics(3)
	p.remove_meta("bump_wait")
	if p.has_meta("last_bump"):
		p.remove_meta("last_bump")
	p.velocity = Vector3(0, 9.0, 0)
	for i in 20:
		await physics_frame
		if p.has_meta("last_bump"):
			break
	var head: Dictionary = p.get_meta("last_bump", {})
	check(not head.is_empty() and head.head, "jumping into a roof is a bonk on the head")
	check(p.velocity.y < 0.0, "...and down she comes")


func _run_into(wall: Node3D, speed: float) -> Dictionary:
	# Stand her just in front of a wall (its front at z + 0.5) and send her into it at `speed`
	await _physics(20)
	_place(wall.global_position + Vector3(0, -1.5 + 1.0, 0.5 + 0.35 + 0.12))
	await _physics(2)
	p.remove_meta("bump_wait")
	if p.has_meta("last_bump"):
		p.remove_meta("last_bump")
	p.velocity = Vector3(0, 0, -speed)
	for i in 6:
		await physics_frame
		if p.has_meta("last_bump"):
			return p.get_meta("last_bump")
	return {}


func _place(at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	if game.riding:
		s._yaw = PI
		s.fakie = false
		if s.state == s.State.BAIL:
			s._end_bail()
		s.state = s.State.ROLL


# -----------------------------------------------------------------------------
# On a board
# -----------------------------------------------------------------------------
func _on_board() -> void:
	if not game.riding:
		game.toggle_skateboard()
	await _physics(3)
	check(game.riding, "on the board")
	_place(Vector3(0, UP + 0.85, 26.0))
	await _physics(10)
	p.remove_meta("bump_wait")
	if p.has_meta("last_bump"):
		p.remove_meta("last_bump")
	check(s.state == s.State.ROLL, "hopping on just after a bonk doesn't knock her off")
	var was_fakie: bool = s.fakie
	# Roll head on into the long wall at z 29.5
	var hit := {}
	for i in 60:
		if not p.has_meta("last_bump"):
			p.velocity = Vector3(0, p.velocity.y, 10.0)
		await physics_frame
		if p.has_meta("last_bump"):
			hit = p.get_meta("last_bump")
			break
	check(not hit.is_empty() and hit.kind == "stone", "rolling into a wall on the board is a bump (%s)" % str(hit))
	check(p.velocity.z < -1.0, "...that bounces her back (%.1f m/s)" % p.velocity.z)
	check(s.fakie != was_fakie, "...rolling away backwards, the board still pointing the same way")
	await _physics(20)
	check(s.state == s.State.ROLL, "...and she's still riding, no bail")

	# A kerb she rolls up
	s.fakie = false
	_place(walls.kerb.global_position + Vector3(0, 0.75, -3.0))
	s._yaw = 0.0
	await _physics(5)
	p.remove_meta("bump_wait")
	if p.has_meta("last_bump"):
		p.remove_meta("last_bump")
	var bumped := false
	for i in 50:
		p.velocity = Vector3(0, p.velocity.y, 6.0)
		await physics_frame
		bumped = bumped or p.has_meta("last_bump")
		if p.global_position.z > walls.kerb.global_position.z + 1.0:
			break
	check(p.global_position.z > walls.kerb.global_position.z + 0.5, "she rolls up and over a kerb")
	check(not bumped, "...and that's no bump")


# -----------------------------------------------------------------------------
# Cave sounds and echo (scripts/cave_echo.gd)
# -----------------------------------------------------------------------------
func _echo() -> void:
	var echo: Node = p.get_node("CaveEcho")
	check(echo != null, "the hero has a cave echo")
	var bed: AudioStreamWAV = echo.make_bed()
	check(bed.data.size() > 1000 and bed.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the cave's drips and hum are made in code, and loop")
	_place(Vector3(10, UP + 0.85, 10))
	await _seconds(0.8)
	check(not echo.inside and echo.amount == 0.0 and not echo.has_effects(), "out in the open: no echo")
	# Under a tunnel's roof
	_place(walls.tunnel.global_position + Vector3(0, -4.0 + 0.85, 0))
	await _seconds(0.9)
	check(echo.inside and echo.why == "tunnel", "under a tunnel roof she's in a tunnel (%s)" % echo.why)
	check(echo.amount > 0.9 and echo.has_effects(), "...the sounds echo (%.2f)" % echo.amount)
	check(echo.get_node("Cave Bed").playing, "...and the cave drips and hums")
	# A dark cave zone, like the Undergardens'
	_place(Vector3(10, UP + 0.85, 10))
	var kit: GDScript = load("res://scripts/cave_kit.gd")
	var zone: Node3D = kit.dark_zone(current_scene, Vector3(10, UP + 2.0, 10), Vector3(8, 6, 8), "Test Dark")
	await _seconds(0.4)
	check(echo.inside and echo.why == "cave", "in a dark cave too (%s)" % echo.why)
	zone.queue_free()
	await _seconds(0.9)
	check(not echo.inside and echo.amount == 0.0 and not echo.has_effects(), "out again, it all eases away and the bus is clean")
	check(not echo.get_node("Cave Bed").playing, "...and the drips stop")


func _seconds(t: float) -> void:
	var until := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < until:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.remove_absolute(SETTINGS)
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame
