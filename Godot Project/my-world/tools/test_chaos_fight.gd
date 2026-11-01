extends SceneTree

# Checks the final boss fight with the Agent of Chaos (scripts/chaos_fight.gd, scripts/chaos_burst.gd, hooked into
# scripts/chaos_giant.gd by scripts/bosses.gd): it stays locked (with a hint) until the three bosses are popped; then
# coming close starts it; his chest clock only counts while it glows (a real Star Popper bubble on it counts); chaos
# bursts are marked first and bump you if you stay on the mark; walking far away calls it off; phase 2 calls minions
# and his clock opens once they're popped; phase 3 winds a rewind that three hits break, and if it isn't broken the
# player is pulled back in time and he gets some chaos back; at zero chaos he's sent out of time, it's remembered and
# rewarded.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_chaos_fight.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FLAGS := ["popped_gloop_king", "popped_grandfather_tock", "popped_boulderdillo"]

var failures := 0
var said: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.message_posted.connect(func(t: String) -> void: said.append(t))
	for f in FLAGS + ["beat_agent_of_chaos"]:
		dialogue.flags.erase(f)
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var giant := town.find_child("ChaosGiant", true, false) as Node3D
	var fight := giant.get_node_or_null("ChaosFight")
	check(fight != null and giant.get("fight") == fight, "the Agent of Chaos has his final fight hooked up")
	check(giant.has_method("shot"), "...and can be shot at")
	await _physics(4)

	# --- Locked until the three bosses are popped ---
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(10)
	check(not fight.active, "he won't fight before his three champions are popped")
	check(said.any(func(t: String) -> bool: return t.contains("Beat his champions first")), "...and says who's left")

	# --- Unlocked: coming close starts it ---
	for f in FLAGS:
		dialogue.flags[f] = true
	p.global_position = giant.global_position + Vector3(0, 40, 60)       # step away and back in
	await _physics(4)
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(6)
	check(fight.active and fight.phase == 1, "with all three popped, coming close starts the fight")
	check(giant.is_in_group("enemies") and giant.is_in_group("bosses"), "...he's a target now")
	check(giant.get_node_or_null("BossMeter") != null, "...with a big meter")

	# --- The clock only counts while it glows ---
	var heart: Vector3 = fight.heart_position()
	check(heart.y - giant.global_position.y > 5.0, "his clock is high on his chest")
	check(giant.shot(1, heart, Vector3.FORWARD) == "bounce" and fight.chaos == 30, "bubbles bounce off while it's shut")
	fight._open(3.0)
	check(giant.shot(1, giant.global_position + Vector3(0, 1, 0), Vector3.FORWARD) == "bounce",
		"...and off his legs even when it's open")
	check(giant.shot(1, heart, Vector3.FORWARD) == "hit" and fight.chaos == 29, "a bubble on his glowing clock counts")
	# A real bubble from the Star Popper, flying up at it
	var from := p.global_position + Vector3(0, 0.6, 0)
	var star: GDScript = load("res://scripts/star_bubble.gd")
	star.fire(town, from, heart - from, p)
	for i in 120:
		await physics_frame
		if fight.chaos < 29:
			break
	check(fight.chaos == 28, "a real bubble fired at the glowing clock hits it")

	# --- Chaos bursts ---
	fight.step = 1
	fight._t = 0.0
	await _physics(2)
	var bursts := town.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
		return n.get_script() == load("res://scripts/chaos_burst.gd"))
	check(bursts.size() >= 4, "a volley of chaos bursts lands round the player (%d)" % bursts.size())
	fight.set_physics_process(false)
	fight.step = 0
	for b in bursts:
		b.queue_free()
	p._invulnerable_timer = 0.0
	await _land(p)
	var burst = load("res://scripts/chaos_burst.gd").new()
	town.add_child(burst)
	burst.global_position = p.global_position - Vector3(0, 0.8, 0)
	var bumped := false
	for i in 120:
		await physics_frame
		if p.is_recovering():
			bumped = true
			break
	check(bumped, "staying on a burst's mark gets you bumped")
	p._invulnerable_timer = 0.0
	var far = load("res://scripts/chaos_burst.gd").new()
	town.add_child(far)
	far.global_position = p.global_position + Vector3(5, -0.8, 0)
	await create_timer(1.6).timeout
	check(not p.is_recovering(), "...but one off to the side doesn't")

	# --- Walking away calls it off ---
	fight.step = 1
	p.global_position = giant.global_position + Vector3(0, 30, 90)
	await _physics(4)
	check(not fight.active and fight.chaos == 30, "walking far away calls it off, and he gets his chaos back")
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(6)
	check(fight.active, "...and coming back starts it again")
	fight.set_physics_process(false)

	# --- Phase 2: minions ---
	fight._open(3.0)
	giant.shot(10, heart, Vector3.FORWARD)
	check(fight.phase == 2, "at two-thirds he moves on to phase 2")
	fight._summon()
	await _frames(2)
	var minions: Array = fight.minions.duplicate()
	check(minions.size() == 3, "he calls three minions out of glitch rifts")
	check(minions.any(func(m: Node) -> bool: return m.is_in_group("time_goblins"))
		and minions.any(func(m: Node) -> bool: return m.has_method("_drip")), "...Time Goblins and a Gloop")
	for m in minions:
		m.shot(5, (m as Node3D).global_position, Vector3.FORWARD)
	fight.drive(0.016)
	check(fight.step == 2 and fight.vulnerable(), "popping them all opens his clock")

	# --- Phase 3: the rewind ---
	giant.shot(10, heart, Vector3.FORWARD)
	check(fight.phase == 3 and fight.chaos == 10, "at a third he moves on to phase 3")
	fight._wind()
	for i in 3:
		giant.shot(1, heart, Vector3.FORWARD)
	check(fight.step == 5 and fight.rewind_breaks == 1 and fight.chaos == 10,
		"three hits on his spinning clock break the rewind and leave him dazed")
	fight._trail.clear()
	var was_at := giant.global_position + Vector3(6, 1.5, 14)
	fight._trail.append(was_at)
	p.global_position = giant.global_position + Vector3(-8, 1.5, 18)
	fight.chaos = 5
	fight._wind()
	fight._t = 0.0
	fight.drive(0.016)
	check(fight.rewinds_done == 1 and p.global_position.distance_to(was_at) < 1.0,
		"if it isn't broken, time rewinds and the player is pulled back")
	check(fight.chaos == 8, "...and he gets some chaos back")

	# --- Winning ---
	var sparkles: int = game.sparkles
	fight._open(3.0)
	giant.shot(20, heart, Vector3.FORWARD)
	check(fight.step == 6 and not fight.active, "at zero chaos his clock shatters")
	check(dialogue.flags.has("beat_agent_of_chaos"), "beating him is remembered")
	check(game.sparkles == sparkles + 20, "...and rewarded")
	await create_timer(2.4).timeout
	check(not giant.visible and not giant.is_in_group("map_landmarks"), "he's sent back out of time")
	_end()


func _land(p: CharacterBody3D) -> void:
	for i in 90:
		await physics_frame
		if p.is_on_floor():
			return


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
