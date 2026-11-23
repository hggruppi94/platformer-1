extends SceneTree

# Checks the climb up the inside of Grandfather Tock's Clockwork Tower (scripts/clock_tower.gd): a Cog Spool rolling
# down the walkway knocks you off it and all the way down (the "Bonk!" line), an alcove keeps you out of its way, a
# Swinging Hand knocks you off, the goblin snipers on the brass column wind up and throw glowing bolts at you, and the
# Gear Lift by the way in takes you up to the Halfway Ledge once you've reached it, and to the top once you've been there.
# Past the Halfway Ledge the walkway is shut, and the way on is the Clockwork Passage inside the tower's wall: its
# pistons and Tick-Tock Shutters push you back, the Cog Key in the Key Room opens the Cog Door at its far end, and then
# the Gear Lift can take you straight past it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_tower_climb.gd
#
# Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.climb_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.climb_backup.cfg"
const TOWER := "res://scenes/bosses/clock_tower.tscn"
const PISTONS_U := [0.12, 0.2, 0.28]

var failures := 0
var lair: Node3D
var p: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(200.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	var settings := root.get_node("Settings")
	settings.tips = false
	game._resume = {}
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)

	change_scene_to_file(TOWER)
	await _frames(8)
	await _physics(4)
	lair = current_scene as Node3D
	p = lair.find_child("Player", true, false) as CharacterBody3D
	check(lair.find_child("Tower Climb Body", true, false) != null, "the tower has a walkway spiralling up inside it")
	check(lair.find_children("Sniper Goblin *", "", true, false).size() == 4, "four goblin snipers stand on the brass column")
	check(lair.find_children("Swinging Hand", "", true, false).size() == 4, "four Swinging Hands swing over the walkway")
	await _spool_knock()
	await _alcove_safe()
	await _hand_knock()
	await _sniper()
	await _lift()
	await _passage()
	_finish()


func _fresh() -> void:
	p.set("_invulnerable_timer", 0.0)
	p.set("_stun_timer", 0.0)
	p.velocity = Vector3.ZERO
	for sp in (lair.get("spools") as Array).duplicate():
		lair.call("_spool_off", sp)
	(lair.get("spools") as Array).clear()
	lair.set("_spool_cd", 999.0)
	lair.set("_knocked", false)
	lair.set("_bonk_said", false)


func _stand(at: Vector3) -> void:
	p.global_position = at + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
		if p.is_on_floor():
			break


func _spool_knock() -> void:
	_fresh()
	await _stand(lair.call("path_point", 0.72))
	var start_y := p.global_position.y
	lair.call("_spawn_spool")
	var sp: Dictionary = (lair.get("spools") as Array)[0]
	sp.s = 0.735
	lair.call("_place_spool", sp)
	var knocked := false
	for i in 40:
		await physics_frame
		if bool(lair.get("_knocked")):
			knocked = true
			break
	check(knocked, "a Cog Spool rolling down the walkway knocks you off it")
	check(float(p.get("_stun_timer")) > 0.0 and p.call("is_invulnerable"), "...it's a knock, not a hurt (no hearts lost)")
	for i in 400:
		await physics_frame
		if p.is_on_floor() and i > 10:
			break
	check(p.global_position.y < start_y - 8.0, "...and down you go (%.1f m to %.1f m)" % [start_y, p.global_position.y])
	await _physics(2)
	check(bool(lair.get("_bonk_said")), "...and a long fall says \"Bonk!\"")


func _alcove_safe() -> void:
	_fresh()
	var al: Dictionary = (lair.get("_alcoves") as Array)[1]
	var s := float(al.s)
	await _stand(lair.call("path_point", s, 27.0))
	var y0 := p.global_position.y
	lair.call("_spawn_spool")
	var sp: Dictionary = (lair.get("spools") as Array)[0]
	sp.s = s + 0.02
	lair.call("_place_spool", sp)
	for i in 120:
		await physics_frame
	check(not bool(lair.get("_knocked")) and absf(p.global_position.y - y0) < 0.5, "in an alcove a spool rolls right past you")
	check(float(lair.get("best")) >= s - 0.02, "...and the tower notes how far up you've got (%.2f)" % float(lair.get("best")))


func _hand_knock() -> void:
	_fresh()
	var sw: Dictionary = (lair.get("_swings") as Array)[1]
	var blade := sw.blade as Node3D
	p.global_position = blade.global_position
	var knocked := false
	for i in 10:
		await physics_frame
		p.global_position = blade.global_position
		if bool(lair.get("_knocked")):
			knocked = true
			break
	check(knocked, "a Swinging Hand knocks you off the walkway")
	for i in 400:
		await physics_frame
		if p.is_on_floor() and i > 10:
			break


func _sniper() -> void:
	_fresh()
	for sn in lair.get("_snipers") as Array:
		sn.cd = 0.3
	await _stand(lair.call("path_point", 0.3))
	var bolt: Node = null
	var wound := false
	for i in 600:
		await physics_frame
		p.global_position = (lair.call("path_point", 0.3) as Vector3) + Vector3(0, 0.95, 0)
		p.velocity = Vector3.ZERO
		for sn in lair.get("_snipers") as Array:
			if float(sn.wind) > 0.0:
				wound = true
		bolt = lair.find_child("Sniper Bolt", true, false)
		if bolt != null:
			break
	check(wound, "a goblin sniper winds up before it throws")
	check(bolt != null, "...then throws a glowing bolt at you")
	await _physics(5)


func _lift() -> void:
	_fresh()
	lair.set("best", 0.0)
	check(String(lair.call("_lift_offer")) == "", "the Gear Lift does nothing till you've climbed to the Halfway Ledge")
	lair.set("best", float(lair.call("ledge_s")))
	check(String(lair.call("_lift_offer")).contains("Halfway"), "...then it offers the Halfway Ledge")
	lair.call("_ride_lift")
	await _physics(20)
	var ledge: Vector3 = lair.call("path_point", float(lair.call("ledge_s")), 27.0)
	check(p.global_position.distance_to(ledge) < 2.5, "...and takes you there (%.1f m off)" % p.global_position.distance_to(ledge))
	lair.set("best", 1.05)
	check(String(lair.call("_lift_offer")).contains("top"), "once you've been to the top it goes all the way up")
	lair.call("_ride_lift")
	await _physics(20)
	check(p.global_position.y > float((lair.call("arena") as Vector3).y) - 1.0, "...and takes you there (%.1f m up)" % p.global_position.y)


func _floor_under(at: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.5, 0), at + Vector3(0, -3.0, 0))
	q.exclude = [p.get_rid()]
	return not lair.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _passage() -> void:
	_fresh()
	await _physics(2)
	var ledge := float(lair.call("ledge_s"))
	var out := float(lair.call("exit_s"))
	check(lair.find_child("Clockwork Passage Body", true, false) != null, "there's a Clockwork Passage inside the tower's wall")
	check(_floor_under(lair.call("path_point", ledge - 0.01)), "the walkway still runs up to the Halfway Ledge")
	var gap := true
	for k in 5:
		if _floor_under(lair.call("path_point", lerpf(ledge + 0.06, out - 0.06, k / 4.0))):
			gap = false
	check(gap, "...but past it the open walkway is shut (no planks till the passage comes out)")
	check(lair.find_child("Shut Gate Body", true, false) != null, "...with a grille where it stops")
	check(_floor_under(lair.call("passage_point", 0.5)) and _floor_under(lair.call("passage_point", 0.05))
		and _floor_under(lair.call("passage_point", 0.95)), "the passage has a floor all the way along")
	check(bool(lair.call("in_passage", lair.call("passage_point", 0.5))), "...and the tower knows when you're in it")
	# A piston shoves you back
	lair.set("pushes", 0)
	var pis: Dictionary = (lair.get("_pistons") as Array)[0]
	var at: Vector3 = lair.call("passage_point", float(PISTONS_U[0]))
	var pushed := false
	for i in 400:
		await physics_frame
		if int(lair.get("pushes")) > 0:
			pushed = true
			break
		if not p.call("is_invulnerable"):
			p.global_position = at + Vector3(0, 0.95, 0)
			p.velocity = Vector3.ZERO
	check(pushed, "a piston punching out of the wall pushes you back along the passage")
	check(float(p.get("_stun_timer")) > 0.0 and p.call("is_invulnerable"), "...it's a push, not a hurt")
	check(float(pis.e) >= 0.0, "...and the piston pulls back again after")
	# A shutter drops and shuts the way for a moment
	_fresh()
	var sh: Dictionary = (lair.get("_shutters") as Array)[0]
	var was_shut := false
	var was_open := false
	for i in 400:
		await physics_frame
		if bool(sh.shut):
			was_shut = not (sh.shape as CollisionShape3D).disabled or was_shut
		elif was_shut:
			was_open = true
			break
	check(was_shut, "a Tick-Tock Shutter drops and shuts the passage")
	check(was_open, "...then lifts again so you can run under")
	# The key and the door
	lair.set("has_key", false)
	lair.call("_try_door")
	await _physics(2)
	check(not bool(lair.get("door_open")), "the Cog Door at the end is locked without the key")
	var door := lair.find_child("Cog Door Body", true, false)
	check(door != null, "...and it's solid")
	var key := lair.find_child("Cog Key", true, false) as Node3D
	check(key != null and key.visible, "the Cog Key waits in the Key Room")
	p.global_position = key.global_position
	await _physics(4)
	check(bool(lair.get("has_key")), "walking up to it picks it up")
	lair.call("_try_door")
	await _physics(4)
	check(bool(lair.get("door_open")), "...and it opens the Cog Door")
	check(_floor_under(lair.call("path_point", out + 0.01)), "past the door the walkway carries on up")
	# The lift's middle stop
	lair.set("best", out)
	check(String(lair.call("_lift_offer")).contains("Passage"), "once you're through, the Gear Lift goes past the Passage")
	lair.call("_ride_lift")
	await _physics(20)
	var stop: Vector3 = lair.call("path_point", out, 27.0)
	check(p.global_position.distance_to(stop) < 2.5, "...and takes you there (%.1f m off)" % p.global_position.distance_to(stop))


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
