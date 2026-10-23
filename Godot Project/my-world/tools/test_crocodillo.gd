extends SceneTree

# Checks the Crocodillo (scripts/crocodillo.gd) in the town: it curls up and rolls at Nina when she comes close,
# jumping on it while it's a ball just bounces her off unhurt, touching the rolling ball hurts, and two stomps while
# it's dizzy beat it for XP. Also checks the mothership is up there flying.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_crocodillo.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node


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
	game = root.get_node("Game")
	var CROC: GDScript = load("res://scripts/crocodillo.gd")      # loaded now, once the autoloads it uses exist
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	var town := current_scene
	var crocs := town.find_children("Crocodillo *", "", true, false)
	check(crocs.size() >= 3, "there are Crocodillos in town (%d)" % crocs.size())
	var croc := crocs[0] as CharacterBody3D
	var p := town.find_child("Player", true, false) as CharacterBody3D

	# --- She walks up: it spots her, curls up and rolls at her ---
	var c := croc.global_position
	p.global_position = c + Vector3(7, 1.0, 0)
	var curled := false
	var rolled := false
	for i in 120:
		await physics_frame
		curled = curled or croc.state == CROC.State.CURL
		rolled = rolled or croc.state == CROC.State.ROLL
		if rolled:
			break
	check(curled, "it curls up when she comes close")
	check(rolled, "...and rolls at her")
	check((croc.get_node("Visual/Ball") as Node3D).visible, "...as an armoured ball")

	# --- Jumping on the ball: a bounce, no hurt. Touching it from the side: hurt ---
	croc.set_physics_process(false)
	p.set_physics_process(false)
	var hp: int = game.hp
	p.global_position = croc.global_position + Vector3(0, 2.6, 0)
	p.velocity = Vector3(0, -3, 0)
	croc._touch_player()
	check(p.velocity.y > 5.0 and game.hp == hp, "jumping on the rolling ball bounces her off, unhurt")
	check(not croc.defeated and croc.hits == 0, "...and doesn't hurt it")
	p.global_position = croc.global_position + Vector3(0.8, 0.9, 0)
	p.velocity = Vector3.ZERO
	p.set("_invulnerable_timer", 0.0)
	croc._touch_player()
	check(game.hp < hp, "bumping into the rolling ball hurts her (%d -> %d)" % [hp, game.hp])

	# --- Dizzy after the roll: two stomps beat it ---
	croc._set_state(CROC.State.DIZZY)
	check((croc.get_node("Visual/Stars") as Node3D).visible and (croc.get_node("Visual/Body") as Node3D).visible,
		"after a roll it uncurls, dizzy, with stars round its head")
	var xp: int = game.xp
	var level: int = game.level
	for k in 2:
		p.global_position = croc.global_position + Vector3(0, 2.8, 0)
		p.velocity = Vector3(0, -3, 0)
		croc._touch_player()
	check(croc.defeated, "two stomps while it's dizzy beat it")
	check(game.xp > xp or game.level > level, "...for XP")

	# --- The mothership ---
	var ship := town.get_node_or_null("Mothership") as Node3D
	check(ship != null, "the mothership is in the town")
	if ship:
		var from := ship.global_position
		await create_timer(1.0).timeout
		check(ship.global_position.distance_to(from) > 3.0 and ship.global_position.y > 60.0,
			"...flying high over it (moved %.1f m in a second, %.0f m up)" % [ship.global_position.distance_to(from), ship.global_position.y])
		check(ship.has_method("fly") and ship.get_node_or_null("Hull/Cockpit") != null, "...with fly() and a cockpit seat ready for a pilot")

	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
