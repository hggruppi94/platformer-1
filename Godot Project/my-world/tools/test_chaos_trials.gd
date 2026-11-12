extends SceneTree

# Checks the friends' sections of the Agent of Chaos's final fight (scripts/chaos_trials.gd, run by
# scripts/chaos_fight.gd): none come up before their move's learned; his chaos can't drop into the next phase while a
# section's left; each section needs its move (Bramble's burrow, Flurry's frost breath, Pip's glow and moth wings,
# Melody's groove, Otto's swimming, Heather's April Showers and Spring Step, Dash's gadgets, the centipede's wall
# crawl, the watch) and leaves him dazed with his clock glowing; running out of time tries it again later, and after
# three goes he gives it up.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_chaos_trials.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.trials_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const WORLDS := ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs",
	"dark_hollow", "far_future"]
const DAZED := 5
const TRIAL := 7

var failures := 0
var said: Array[String] = []
var town: Node3D
var p: CharacterBody3D
var giant: Node3D
var fight: Node
var trials: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	var portals := root.get_node("Portals")
	var arsenal := root.get_node("Arsenal")
	game.hold_saves = true
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	game.message_posted.connect(func(t: String) -> void: said.append(t))
	dialogue.flags.erase("beat_agent_of_chaos")
	portals.cleared_worlds.clear()
	arsenal.owned.assign(["popper"])
	arsenal.current = "popper"
	game.items.assign(game.items.filter(func(i: String) -> bool: return not i.contains("watch") and not i.contains("keeper")))
	dialogue.flags["swap_tried"] = true
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	town = current_scene as Node3D
	p = town.find_child("Player", true, false) as CharacterBody3D
	giant = town.find_child("ChaosGiant", true, false) as Node3D
	fight = giant.get_node("ChaosFight")
	trials = fight.get_node_or_null("Trials")
	check(trials != null and trials.fight == fight, "the fight has its friends' sections")

	# --- Nothing learned: no sections ---
	await _go_near()
	check(fight.active, "Rex's swap opens the fight")
	for ph in [1, 2, 3]:
		check(trials.pending(ph) == "", "with no moves learned there are no sections in phase %d" % ph)
	check(fight.chaos_floor() == 0, "...and nothing holds his chaos up")

	# --- Learn everything ---
	portals.cleared_worlds.assign(WORLDS)
	arsenal.give("fizz", false)
	game.give_item("shop:shift_watch")
	check(trials.pending(1) == "burrow" and trials.pending(2) == "spring" and trials.pending(3) == "crawl",
		"each phase's sections come in the order the worlds were mended")
	check(fight.chaos_floor() == 21, "his chaos can't drop into phase 2 while phase 1 has sections left")
	fight._open(3.0)
	giant.shot(15, fight.heart_position(), Vector3.FORWARD)
	check(fight.chaos == 21 and fight.phase == 1, "...even with a big hit (%d)" % fight.chaos)

	# --- A turn ends with a section ---
	fight.step = 1
	fight._volleys = 1
	fight._t = 0.0
	await _physics(3)
	check(fight.step == TRIAL and trials.current == "burrow", "at the end of a turn he starts Bramble's section")
	check(trials.shot(1, fight.heart_position()) == "bounce" and giant.shot(1, fight.heart_position(), Vector3.FORWARD) == "bounce",
		"...and his clock's shut tight meanwhile")
	check(said.any(func(t: String) -> bool: return t.contains("Bramble") and t.contains("Burrow")), "...Bramble says what to do")

	# --- Bramble: the Static Storm ---
	await _stand(trials._base + trials._out * 6.0)
	await _physics(4)
	check(trials.pushed_back > 0, "on foot, the static buzzes you back")
	await _stand(trials.knot.global_position + trials._out * 1.5)
	await _land()
	var dug: bool = p.burrow.try_start()
	check(dug and p.burrow.active, "you can burrow there")
	p.global_position = Vector3(trials.knot.global_position.x, p.global_position.y, trials.knot.global_position.z)
	await _until(func() -> bool: return trials.current == "", 60)
	var chaos_was := 21
	check(trials.done.has("burrow") and fight.step == DAZED and fight.vulnerable(),
		"burrowing to the Root Knot trips him: he's dazed and his clock glows")
	check(fight.chaos == chaos_was, "...and his chaos stays up while phase 1 has more sections (%d)" % fight.chaos)
	p.burrow.stop()
	await _land()

	# --- Flurry: the River of Melted Time ---
	fight._trial("frost")
	await _physics(2)
	check(trials.river.size() == 16 and trials._in_river(trials._base + trials._out * 11.0), "a ring of melted time pours round him")
	check(trials._flat(p.global_position - trials._base) > 15.0, "...you start outside it")
	var safe: Vector3 = p.global_position
	await _stand(trials._base + trials._out * 11.0)
	await _physics(3)
	check(trials.pushed_back > 0 and p.global_position.distance_to(safe) < 3.0, "walking into it sweeps you back out")
	# Breathe frost at it from the edge
	await _stand(trials._base + trials._out * 16.0)
	await _land()
	_face(trials._base)
	p.frost_breath.cooldown = 0.0
	p.frost_breath.breathe()
	var floes: Array = p.frost_breath.floes
	check(floes.size() >= 2 and floes.any(func(f: Node3D) -> bool: return trials._in_river(f.global_position)),
		"frost breath freezes it into floes (%d)" % floes.size())
	var floe := floes.filter(func(f: Node3D) -> bool: return trials._in_river(f.global_position))[0] as Node3D
	var pushed: int = trials.pushed_back
	p.global_position = floe.global_position + Vector3(0, 0.8, 0)
	p.velocity = Vector3.ZERO
	await _physics(25)
	check(trials.pushed_back == pushed and p.global_position.distance_to(floe.global_position) < 2.0,
		"standing on the ice, it doesn't sweep you away")
	await _stand(trials.knot.global_position)
	await _until(func() -> bool: return trials.current == "", 60)
	check(trials.done.has("frost") and fight.step == DAZED, "crossing to the Frost Knot freezes him: dazed")
	await _physics(3)
	check(trials.river.is_empty(), "...and the river goes")

	# --- Pip: Lights Out ---
	fight._trial("glow")
	await _physics(3)
	check(trials.lanterns.size() == 3 and trials.rock != null, "he swallows the light: three lantern stones, one on a floating rock")
	check(float(p.get("glide_fall")) > 0.0 and p.find_child("Moth Wings", true, false) != null, "...and Pip lends you moth wings")
	await _stand(trials.lanterns[0].global_position + trials._out * 2.0)
	await _physics(10)
	check(p.pip_glow.in_dark and p.pip_glow.shining(), "it's dark round him, and Pip's glow comes on")
	check(trials.lanterns[0].awake, "the glow wakes a lantern stone")
	await _stand(trials.lanterns[1].global_position + trials._out * 2.0)
	await _physics(10)
	check(trials.lanterns[1].awake, "...and the other one on the ground")
	var rock_top: float = trials.rock.global_position.y
	check(rock_top - trials._ground_at(trials.rock.global_position - Vector3(0, 8, 0)).y > 4.0, "the third is on a rock high off the ground")
	await _stand(trials.swirl_at)
	await _land()
	var y0: float = p.global_position.y
	Input.action_press("jump")
	await _physics(45)
	Input.action_release("jump")
	check(p.global_position.y > y0 + 4.0, "holding Jump in the moth swirl carries you up (%.1f m)" % (p.global_position.y - y0))
	p.global_position += trials._side * 4.0                   # out of the swirl
	p.velocity = Vector3.ZERO
	Input.action_press("jump")                              # (the free double jump goes first)
	await _until(func() -> bool: return p.velocity.y < 0.0, 120)
	await _physics(20)
	check(p.gliding and p.velocity.y > -1.5, "holding Jump on the way down, you glide")
	Input.action_release("jump")
	p.global_position = trials.rock.global_position + Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return trials.current == "", 90)
	check(trials.done.has("glow") and fight.step == DAZED, "waking the rock's lantern brings the light back: he's dazed")
	await _physics(3)
	check(float(p.get("glide_fall")) == 0.0 and p.find_child("Moth Wings", true, false) == null, "...and the wings go back to Pip")
	check(not p.pip_glow.in_dark, "...and the dark's gone")

	# --- On to phase 2 ---
	check(fight.chaos_floor() == 0 or trials.pending(1) == "", "with phase 1's sections done, his chaos can drop again")
	fight._open(3.0)
	giant.shot(fight.chaos - 20, fight.heart_position(), Vector3.FORWARD)
	check(fight.phase == 2 and fight.chaos == 20, "phase 2 comes")
	check(fight.chaos_floor() == 11, "...and holds at 11 while its sections are left")

	# --- Melody: the Off-Beat Stomp ---
	await _stand(giant.global_position + trials._out * 9.0)
	fight._trial("groove")
	await _physics(2)
	p.groove._set_dancing(30.0)
	await _physics(3)
	check(not p.groove.is_dancing(giant), "grooving doesn't freeze the Agent of Chaos (and his fight)")
	p.groove.grooved.emit(false, 0)
	check(trials.heard == 0, "off the beat, he doesn't hear it")
	p.global_position = giant.global_position + trials._out * 30.0
	p.groove.grooved.emit(true, 1)
	check(trials.heard == 0, "...or from too far")
	await _stand(giant.global_position + trials._out * 8.0)
	for i in 3:
		p.groove.grooved.emit(true, i + 1)
	await _until(func() -> bool: return trials.current == "", 30)
	check(trials.done.has("groove") and fight.step == DAZED, "three on-beat grooves close by: he dances, dazed")

	# --- Otto: the Time Flood ---
	fight._trial("swim")
	await create_timer(3.4).timeout
	var flood: Node3D = trials.flood
	check(flood != null and float(flood.water_y) > trials._base.y + 3.0, "he floods the field over your head")
	await _stand(trials.knot.global_position + trials._out * 3.0)
	await _physics(30)
	check(p.swim.active, "you're swimming")
	p.global_position = trials.knot.global_position + Vector3(0, 0.2, 0)
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return trials.current == "", 60)
	check(trials.done.has("swim") and fight.step == DAZED, "diving to the plug drains the flood: dazed")
	await create_timer(1.8).timeout
	check(float(flood.water_y) < trials._base.y, "...and the water's gone")
	await _land()

	# --- Heather: Glitch Fires and the clock gear ---
	fight._trial("spring")
	await _physics(2)
	check(trials.fires.size() == 3, "three glitch fires spring up")
	for f in trials.fires:
		await _stand(f.global_position + trials._out * 1.5)
		await _land()
		p.showers.cooldown = 0.0
		p.showers.raining = 0.0
		p.showers.shower()
		await _physics(4)
	check(trials.fires.all(func(f: Node3D) -> bool: return f.get_meta("out", false)), "April Showers puts them out")
	check(trials.gear != null, "...and a clock gear rises")
	await create_timer(1.6).timeout
	var gear_up: float = trials.gear.global_position.y - trials._ground_at(trials.gear.global_position - Vector3(0, 8, 0)).y
	var one_jump: float = 6.0 * 6.0 / (2.0 * 9.8) + 5.5 * 5.5 / (2.0 * 9.8)
	var springy: float = (6.0 * 1.65) * (6.0 * 1.65) / (2.0 * 9.8) + 5.5 * 5.5 / (2.0 * 9.8)
	check(gear_up > one_jump + 0.5 and gear_up < springy - 0.5,
		"it's higher than a jump and a double jump (%.1f m), not a Spring Step and one (%.1f m): %.1f m" % [one_jump, springy, gear_up])
	p.global_position = trials.gear.global_position + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _until(func() -> bool: return trials.current == "", 60)
	check(trials.done.has("spring") and fight.step == DAZED, "on the gear, face to face with his clock: dazed")
	await _land()

	# --- Dash: the Glitch Crystals ---
	fight._trial("gadgets")
	await _physics(2)
	check(trials.crystals.size() == 3 and trials.crystals.all(func(c: Node) -> bool: return c.is_in_group("enemies")),
		"three Glitch Crystals shield him")
	check(arsenal.ammo_of("fizz") > 0, "...and Dash throws you some ammo")
	arsenal.current = "popper"
	check(trials.crystals[0].shot(1, Vector3.ZERO, Vector3.FORWARD) == "bounce", "Star Popper bubbles bounce off them")
	arsenal.current = "fizz"
	for c in trials.crystals:
		check(arsenal.hit(c, 1, Vector3.FORWARD, "fizz") == "hit", "a Fizz Flinger splash shatters one")
	await _until(func() -> bool: return trials.current == "", 30)
	check(trials.done.has("gadgets") and fight.step == DAZED, "with the crystals gone: dazed")
	arsenal.current = "popper"

	# --- On to phase 3 ---
	fight._open(3.0)
	giant.shot(fight.chaos - 10, fight.heart_position(), Vector3.FORWARD)
	check(fight.phase == 3 and fight.chaos == 10 and fight.chaos_floor() == 1, "phase 3 comes, and holds at 1 while its sections are left")

	# --- The centipede: the Clock Tower ---
	fight._trial("crawl")
	await create_timer(1.5).timeout
	var tower: StaticBody3D = trials.tower
	var wc: GDScript = load("res://scripts/wall_crawl.gd")
	check(tower != null and wc.climbable(tower), "a tower of glitch cubes shoots up, and you can climb it")
	check(tower.global_position.y + 10.0 - trials._ground_at(tower.global_position).y > 9.0, "...far higher than any jump")
	# Really climb it
	var face: Vector3 = tower.global_position - trials._out * 1.95
	await _stand(Vector3(face.x, 0, face.z))
	await _land()
	p.wall_crawl.start(-trials._out)
	_face(tower.global_position)
	Input.action_press("move_forward")
	await _until(func() -> bool: return trials.current == "", 300)
	Input.action_release("move_forward")
	check(trials.done.has("crawl") and fight.step == DAZED, "climbing to the top, you leap onto his clock: dazed")
	if p.wall_crawl.active:
		p.wall_crawl.stop()
	await _stand(giant.global_position + trials._out * 12.0)
	await _land()

	# --- The watch: the Big Rewind (a miss first) ---
	fight._trail.clear()
	var back_to: Vector3 = p.global_position + trials._out * 3.0
	fight._trail.append(back_to)
	var rewinds: int = fight.rewinds_done
	fight._trial("watch")
	await _physics(2)
	check(fight._glow.visible and trials.spinning(), "his clock spins, too fast to touch")
	check(giant.shot(1, fight.heart_position(), Vector3.FORWARD) == "bounce", "...bubbles just bounce")
	trials.left = 0.05
	await _physics(4)
	check(fight.rewinds_done == rewinds + 1 and not trials.done.has("watch"), "without your watch up, the rewind goes through")
	check(trials.pending(3) == "watch", "...and he'll try it again")
	fight._trial("watch")
	await _physics(2)
	p.get_node("HUD").check_watch()
	await _until(func() -> bool: return trials.current == "", 30)
	check(trials.done.has("watch") and fight.step == DAZED, "holding up your watch, the rewind can't take you: dazed")
	check(fight.chaos_floor() == 0, "with every section done, his chaos can run out")

	# --- Giving up after three goes ---
	trials.done.erase("crawl")
	trials.tries.erase("crawl")
	for i in 3:
		fight._trial("crawl")
		await _physics(2)
		trials.left = 0.0
		await _physics(3)
	check(not trials.available("crawl") and said.any(func(t: String) -> bool: return t.contains("Never mind that one")),
		"after three goes, he gives a section up")

	# --- Called off: everything again next time ---
	p.global_position = giant.global_position + Vector3(0, 30, 90)
	await _physics(4)
	check(not fight.active and trials.done.is_empty() and trials.root == null, "walking away resets the sections")
	_end()


# --- Helpers -------------------------------------------------------------------------------------------------------

func _go_near() -> void:
	p.global_position = giant.global_position + Vector3(0, 40, 60)
	await _physics(4)
	await _stand(giant.global_position + Vector3(0, 0, 15))
	await _physics(6)


func _stand(at: Vector3) -> void:
	var g: Vector3 = fight._ground(at)
	p.global_position = g + Vector3(0, 0.6, 0)
	p.velocity = Vector3.ZERO
	await _physics(2)


func _face(at: Vector3) -> void:
	var d := at - p.global_position
	var yaw := atan2(d.x, d.z)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		visual.global_rotation.y = yaw
	var cam := p.find_child("SpringArm3D", true, false) as Node3D
	if cam:
		cam.global_rotation.y = yaw + PI


func _land() -> void:
	for i in 90:
		await physics_frame
		if p.is_on_floor():
			return


func _until(cond: Callable, frames: int) -> void:
	for i in frames:
		if cond.call():
			return
		await physics_frame


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
	Input.action_release("jump")
	Input.action_release("move_forward")
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
	quit(1 if failures > 0 else 0)
