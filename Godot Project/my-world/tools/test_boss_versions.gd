extends SceneTree

# Checks the bosses of the older enemies (scripts/bosses.gd): the Boulderdillo, the Crocodillos' boss
# (scripts/crocodillo_boss.gd) in Boulder Hollow, and the Gloop King's new cross mode (scripts/gloop_king.gd).
# The Boulderdillo is big and rocky with a meter; bubbles and stomps bounce off it unless it's dizzy; it rolls three
# times in a row with a ring-slam between each, then sits dizzy; it calls Pebbledillos at a third and two-thirds (gone
# for good once popped); it gets faster and rolls once more past half; it's remembered once popped. Ordinary
# Crocodillos are unchanged. Past half his goo, the Gloop King flops faster and sends a second wave of goo.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_boss_versions.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0


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
	var game := root.get_node("Game")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	p.global_position = Vector3(-72, 2, 80)

	# --- Boulder Hollow ---
	var hollow := town.get_node_or_null("Boulder Hollow") as Node3D
	check(hollow != null and hollow.is_in_group("map_landmarks"), "Boulder Hollow is in town and on the map")
	check(hollow != null and hollow.find_children("Boulder *", "StaticBody3D", false, false).size() == 12,
		"...ringed with big boulders (two ways in)")
	var boss := town.find_child("The Boulderdillo", true, false) as CharacterBody3D
	check(boss != null and boss.is_in_group("bosses") and boss.is_in_group("enemies"), "the Boulderdillo lives there")
	await _physics(10)
	check(_height(boss) > 4.0, "it's huge (%.1f m tall)" % _height(boss))
	check(boss.get_node_or_null("BossMeter") != null, "it has a meter with its name")
	check(boss.find_children("Boulder*", "MeshInstance3D", true, false).size() >= 9
		and boss.get_node("Visual/Ball").find_children("BallBoulder*", "", false, false).size() >= 12,
		"boulders have grown into its shell, curled up or not")
	var plain := town.find_child("Crocodillo 0", true, false)
	check(plain != null and plain.size == 1.0 and (plain.get_node("Visual") as Node3D).scale.is_equal_approx(Vector3.ONE),
		"ordinary Crocodillos are their old size")

	# --- Thick hide ---
	boss.set_physics_process(false)
	boss.state = 0
	check(boss.shot(1, boss.global_position, Vector3.FORWARD) == "bounce" and boss.hits == 0,
		"bubbles boing off it while it isn't dizzy")
	boss.player = p
	boss._stomped()
	check(boss.hits == 0, "...and stomps just bounce you")

	# --- Pinball rolls ---
	var rings := town.find_children("ShockRing", "", true, false).size()
	boss.state = 3                                         # rolling
	boss._rolls_left = 2
	boss._roll_ended()
	check(boss.state == 3 and boss._rolls_left == 1, "when a roll ends it rolls again...")
	check(town.find_children("ShockRing", "", true, false).size() > rings, "...after slamming a ring out")
	boss._roll_ended()
	boss._roll_ended()
	check(boss.state == 4, "after the third roll it uncurls, dizzy")
	check(boss.get_node("Visual/Stars").visible, "...stars round its head")

	# --- Popping it while it's dizzy ---
	check(boss.shot(1, boss.global_position, Vector3.FORWARD) == "hit" and boss.hits == 1, "a dizzy one can be popped")
	boss.shot(3, boss.global_position, Vector3.FORWARD)
	await _frames(2)
	var pebbles := town.find_children("Pebbledillo *", "", true, false)
	check(pebbles.size() == 2, "at a third it calls two Pebbledillos")
	check(pebbles.size() > 0 and pebbles[0].size < 1.0 and not pebbles[0].respawns, "...little ones that don't come back")
	var speed: float = boss.roll_speed
	boss.state = 4
	boss.shot(2, boss.global_position, Vector3.FORWARD)
	check(boss._cross and boss.roll_speed > speed and boss.rolls_in_a_row == 4,
		"past half it's cross: faster, and four rolls in a row")
	boss.state = 4
	boss.shot(1, boss.global_position, Vector3.FORWARD)
	await _frames(2)
	check(town.find_children("Pebbledillo *", "", true, false).size() == 4, "...and two more Pebbledillos at two-thirds")
	for c in town.find_children("Pebbledillo *", "", true, false):
		c.shot(3, (c as Node3D).global_position, Vector3.FORWARD)
	boss.state = 4
	boss.shot(3, boss.global_position, Vector3.FORWARD)
	check(boss.defeated, "enough bubbles pop it")
	check(root.get_node("Dialogue").flags.has("popped_boulderdillo"), "popping it is remembered")
	await create_timer(3.2).timeout
	check(town.find_children("Pebbledillo *", "", true, false).is_empty(), "popped Pebbledillos are gone for good")
	check(not boss._cross and boss.rolls_in_a_row == 3, "it calms down again for next time")

	# --- The Gloop King gets cross ---
	var king := town.find_child("The Gloop King", true, false)
	king.set_physics_process(false)
	var flop: float = king.flop_every
	king.hits = 3
	king._physics_process(0.016)
	check(king._cross and king.flop_every < flop, "past half his goo the Gloop King is cross and flops more often")
	var before := town.find_children("ShockRing", "", true, false).size()
	king._land()
	await create_timer(0.6).timeout
	check(town.find_children("ShockRing", "", true, false).size() > before, "...with a second wave of goo")
	_end()


func _height(n: Node) -> float:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.get_parent().name == "BossMeter" or mi.get_parent().get_parent() \
				and mi.get_parent().get_parent().name == "BossMeter":
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.size.y


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
