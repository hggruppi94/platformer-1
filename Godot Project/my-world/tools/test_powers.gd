extends SceneTree

# Checks the two powers from the lore bible (12 Nov 2026): Dash's kinetic energy (scripts/kinetic.gd) and Nina and
# Bruno's shared making power (scripts/make.gd, quest "Making Things", res://quests/make_together.json).
#
# Kinetic: locked until Dash teaches it (no charge, an ordinary roll); his King conversation and the catch-up one for
# old saves teach it and set the flag; running fills the charge (walking doesn't), the meter shows (a gold KE bar under
# SP in the stats corner, not in the middle of the screen); a big landing adds a bit; a full charge does nothing to a
# roll on foot (Hayden, 13 Nov 2026: no roll attack) but Flip on a ride, rolling along the ground, lets it out as a
# boost: faster, empty again; not without a full charge, and not off the ride.
# Make: locked (not on the Controls list, does nothing) until Bruno teaches it in the quest; on the ground it makes a
# bridge out in front at your feet's height that you can walk along; in the air a step under you to land on, only one
# a jump; two at once at most; they pop by themselves; three things tick the quest on, showing Nina finishes it; and a
# press of RB once it's taught makes something without rolling too.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_powers.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.powers_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.powers_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"

var failures := 0
var game: Node
var settings: Node
var clock: Node
var dialogue: Node
var quests: Node
var party: Node


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
	settings = root.get_node("Settings")
	party = root.get_node("Party")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	clock.set("pulls_home", false)
	clock.set_time(3, 10 * 60.0, true)
	quests.state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)

	await _check_kinetic_locked()
	await _check_kinetic_taught()
	await _check_charge()
	await _check_make_locked()
	await _check_make_quest()
	await _check_bridge()
	await _check_step()
	await _check_rb()
	await _check_show_nina()
	await _check_ride_boost()                  # last: riding turns the camera, which the walking checks lean on
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.find_child("Player", true, false) as CharacterBody3D


func _spot() -> Vector3:
	return root.get_node("Remnants").ground_at(Vector2(-24.0, 46.0)) + Vector3(0, 1.0, 0)


func _land(p: CharacterBody3D) -> void:
	for i in 300:
		await physics_frame
		if p.is_on_floor() and i > 2:
			return


func _reset(p: CharacterBody3D, at := Vector3.INF) -> void:
	p.global_position = _spot() if at == Vector3.INF else at
	p.velocity = Vector3.ZERO
	await _land(p)
	await _physics(3)


# Kinetic ----------------------------------------------------------------------------------------------------------
func _check_kinetic_locked() -> void:
	var p := _player()
	var k := p.get_node_or_null("Kinetic")
	check(k != null and p.get_node_or_null("Make") != null, "the player has Kinetic and Make nodes")
	await _reset(p)
	k.add(0.5)
	check(k.charge == 0.0, "before Dash teaches it, nothing charges")
	check(not k.can_boost() and not k.meter_shown(), "...there's no boost, and no meter")


func _check_kinetic_taught() -> void:
	var meetings := root.get_node("FirstNight/Meetings")
	var lines: Array = meetings.king_from_dash()
	check(dialogue.flags.has("kinetic_taught"), "Dash's King conversation teaches his kinetic trick")
	check(lines.any(func(l: Variant) -> bool: return str(l).contains("{skate_flip}")), "...saying how (Flip, {skate_flip}, on a ride)")
	check(str(lines[lines.size() - 1]).contains("Pip"), "...and still sends you on to Pip last")
	dialogue.flags.erase("kinetic_taught")
	var again: Array = meetings.kinetic_from_dash()
	check(dialogue.flags.has("kinetic_taught") and again.size() > 3, "an old save past the King gets it from Dash's catch-up talk")
	var dash := JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/dash.json")) as Dictionary
	var found := false
	for c in dash.conversations:
		if str(c.get("do", "")) == "FirstNight/Meetings.kinetic_from_dash":
			found = c.get("when", {}).get("not_flag", "") == "kinetic_taught"
	check(found, "(Dash's catch-up talk is in his file, only until it's taught)")


func _check_charge() -> void:
	var p := _player()
	var k := p.get_node("Kinetic")
	await _reset(p)
	k.charge = 0.0
	# Walking pace doesn't store anything: hold the player to a walk for a moment
	for i in 30:
		p.velocity = Vector3(2.0, p.velocity.y, 0)
		await physics_frame
	check(k.charge == 0.0, "walking doesn't store any go")
	await _reset(p)
	Input.action_press("move_right")
	await create_timer(1.5).timeout
	Input.action_release("move_right")
	check(k.charge > 0.05 and k.charge < 1.0, "running stores some (%.2f after 1.5 s)" % k.charge)
	await _frames(2)
	check(k.meter_shown(), "the kinetic meter shows while it fills")
	var before: float = k.charge
	await _reset(p)
	p.global_position = _spot() + Vector3(0, 7.0, 0)
	p.velocity = Vector3.ZERO
	await _land(p)
	await _physics(2)
	check(k.charge >= before + k.LANDING_ADDS - 0.01, "a big landing adds a bit (%.2f -> %.2f)" % [before, k.charge])


func _check_ride_boost() -> void:
	var p := _player()
	var k := p.get_node("Kinetic")
	var hud := p.get_node("HUD")
	await _reset(p)
	k.charge = 1.0
	await _frames(2)
	check(k.meter_shown(), "a full charge shows on the meter")
	check(hud.panel.is_ancestor_of(hud.ke_bar), "...which is a bar in the stats corner (out of the way of the riding meters)")
	check(not p.get_node("Kinetic").has_node("Kinetic HUD"), "...and not the old card in the middle of the screen")
	game.sp = game.max_sp
	p._try_roll(Vector3(1, 0, 0))
	check(k.bursts == 0 and k.full(), "a roll on foot doesn't use it up (no more roll attack)")
	await create_timer(0.6).timeout
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	check(k.bursts == 0 and k.full(), "...and Flip on foot doesn't either")
	game.riding = true
	game.equipment_changed.emit()
	await _frames(3)
	await _reset(p)
	var skate: Node = p.get("skate")
	check(int(skate.state) == int(skate.State.ROLL) and k.can_boost(), "on a ride, rolling along with a full charge, it's ready")
	var before := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	check(k.bursts == 1 and k.charge == 0.0, "Flip on a ride lets it all out (empty again)")
	check(skate.boosting(), "...as a boost")
	await _physics(10)
	var after := Vector2(p.velocity.x, p.velocity.z).length()
	check(after > before + 5.0, "...and the ride shoots off (%.1f -> %.1f m/s)" % [before, after])
	check(not skate.tricks.flipping(), "...without starting a flip trick")
	await create_timer(2.5).timeout
	Input.action_press("skate_flip")
	await _physics(2)
	Input.action_release("skate_flip")
	check(k.bursts == 1, "an empty charge gives no boost")
	game.riding = false
	game.equipment_changed.emit()
	await _frames(3)
	k.charge = 0.0


# Make -------------------------------------------------------------------------------------------------------------
func _check_make_locked() -> void:
	var p := _player()
	var m := p.get_node("Make")
	check(not settings.default_bindings().has("make") and settings.prompt("make") == settings.prompt("friend"),
		"Make has no button of its own: it's Nina and Bruno's move, on the Friend button (Z, RB: scripts/party.gd)")
	var rb := false
	for e in InputMap.action_get_events("dash"):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_SHOULDER:
			rb = true
	check(rb, "RB still rolls too (until a friend's with you)")
	check(not settings.action_shown("make"), "Make isn't learned before Nina and Bruno teach it")
	check(not m.try_make() and m.things.is_empty(), "pressing it does nothing yet")


func _check_make_quest() -> void:
	quests.state["bike_boy"] = {"step": 6, "done": true, "since_day": 1}
	var nina := JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/nina.json")) as Dictionary
	var offer := false
	for c in nina.conversations:
		if c.get("set", "") == "make_start":
			offer = c.get("when", {}).get("quest_done", "") == "bike_boy"
	check(offer, "Nina offers the quest once The Bike Boy's done")
	dialogue.set_flag("make_start")
	await _frames(2)
	check(quests.is_started("make_together") and str(quests.current_step("make_together").get("id", "")) == "bruno",
		"the quest starts: find Bruno")
	var bruno := JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/bruno_alien.json")) as Dictionary
	var teach: Array = []
	for c in bruno.conversations:
		if c.get("set", "") == "make_taught":
			teach = c.lines
	check(teach.any(func(l: Variant) -> bool: return str(l).contains("{make}")), "Bruno teaches it, saying the button")
	dialogue.set_flag("make_taught")
	await _frames(2)
	check(settings.action_shown("make"), "...and then it's learned")
	check(party.has_joined("nina_bruno") and party.with_you == "nina_bruno", "...and Nina and Bruno join you")
	check(str(quests.current_step("make_together").get("id", "")) == "try", "the quest moves on: make three things")


func _ray_down(from: Vector3, len := 4.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -len, 0))
	q.exclude = [_player().get_rid()]
	return current_scene.get_world_3d().direct_space_state.intersect_ray(q)


func _check_bridge() -> void:
	var p := _player()
	var m := p.get_node("Make")
	await _reset(p)
	p.visual.rotation.y = PI * 0.5                 # facing +X
	var feet := p.global_position.y - 0.8
	var t: Node3D = m.make()
	await _physics(2)
	check(m.things.size() == 1 and m.things[0].kind == "bridge", "on the ground it makes a bridge")
	var hit := _ray_down(p.global_position + p.facing_dir() * 3.0 + Vector3(0, 1.5, 0))
	check(not hit.is_empty() and hit.collider == t, "...out in front of you (hit %s)" % (str(hit.collider.name) + " at " + str(hit.position) if not hit.is_empty() else "nothing"))
	if not hit.is_empty():
		check(absf(hit.position.y - feet) < 0.15, "...at your feet's height (%.2f vs %.2f)" % [hit.position.y, feet])
	check(not m.try_make(), "(a moment before the next)")
	Input.action_press("move_right")
	await create_timer(0.45).timeout
	Input.action_release("move_right")
	check(p.is_on_floor() and p.get("_floor_node") == t, "you can walk out along it")
	await create_timer(m.COOLDOWN + 0.05).timeout
	check(m.try_make() and m.things.size() == 2, "a second thing")
	await create_timer(m.COOLDOWN + 0.05).timeout
	var first: Node3D = m.things[0].node
	check(m.try_make() and m.things.size() == 2, "a third: still only two at once")
	await _frames(2)
	check(not is_instance_valid(first), "...the oldest popped")
	check(dialogue.flags.has("made_three"), "three things made")
	await _frames(2)
	check(str(quests.current_step("make_together").get("id", "")) == "show", "...the quest says show Nina")
	await create_timer(m.LASTS + 0.3).timeout
	check(m.things.is_empty(), "they pop by themselves after %.0f s" % m.LASTS)


func _check_step() -> void:
	var p := _player()
	var m := p.get_node("Make")
	await _reset(p)
	var ground := p.global_position.y
	p.velocity = Vector3(0, 7.0, 0)
	await create_timer(0.35).timeout
	check(not p.is_on_floor(), "(up in the air)")
	check(m.try_make() and m.things[m.things.size() - 1].kind == "step", "in the air it makes a step")
	await create_timer(m.COOLDOWN + 0.05).timeout
	check(not m.try_make(), "...only one a jump")
	await _land(p)
	check(p.global_position.y > ground + 0.8, "...and you land on it (%.2f m up)" % (p.global_position.y - ground))
	await _physics(3)
	m.clear()
	await _land(p)


func _check_rb() -> void:
	var p := _player()
	var m := p.get_node("Make")
	await _reset(p)
	m.clear()
	m.cooldown = 0.0
	game.sp = game.max_sp
	var n: int = m.made_count
	Input.action_press("friend")
	Input.action_press("dash")                      # RB is both
	await _physics(2)
	Input.action_release("friend")
	Input.action_release("dash")
	check(m.made_count == n + 1, "RB makes something with Nina and Bruno along")
	check(not p.is_rolling(), "...without rolling too")
	m.clear()


func _check_show_nina() -> void:
	var before: int = game.sparkles
	dialogue.set_flag("make_showed_nina")
	await _frames(2)
	check(quests.is_done("make_together"), "showing Nina finishes the quest")
	check(game.sparkles == before + 8, "...+8 sparkles")


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_right")
	Input.action_release("friend")
	Input.action_release("dash")
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
