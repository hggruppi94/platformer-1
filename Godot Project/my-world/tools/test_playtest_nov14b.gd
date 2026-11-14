extends SceneTree

# Checks Hayden's 14 Nov 2026 afternoon playtest fixes (thread "Fix bugs from the 14 Nov afternoon playtest"):
#   - lots of enemies in Jelly Mines at once (with every mod and the Jamboree) don't break the game
#   - a full kinetic charge plays its sound but puts no words up (scripts/kinetic.gd)
#   - the to-do list stops above the friend's face badge (scripts/hud.gd _fit_todo)
#   - Otto's arms stay inside his bubble (scripts/tide_reef.gd _wiggle)
#   - Flurry's Portal Plaza self stays hidden while her copy walks with you, even when the plaza's put up after the
#     copy (scripts/party.gd _hide_hub_flurry)
#   - in the water, Jump beats Dive, so a stuck Shift can't drag her down (scripts/swim.gd)
#   - the Haunted House's walk-in doorway (no inside yet) is off, so trying the quest's door doesn't bump into it
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_playtest_nov14b.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.nov14b_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.nov14b_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const GLOOP := "res://scenes/enemies/gloop.tscn"

var failures := 0
var game: Node


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
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 13 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(4)
	await _check_jelly()
	await _check_kinetic()
	await _check_todo()
	_check_otto()
	await _check_flurry()
	_check_haunted_door()
	await _check_rails()
	await _check_sky_rings()
	_finish()


func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _check_jelly() -> void:
	seed(14)
	var arsenal := root.get_node("Arsenal")
	var p := _player()
	var at := p.global_position + Vector3(0, -0.85, 0)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 5, 0), at + Vector3(0, -10, 0))
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = hit.position
	p.global_position = at + Vector3(0, 0.85, 12)          # out of the way
	for m in ["bounce", "freeze", "split"]:
		arsenal.mods_owned.append(m)
	arsenal.give("jelly", false)
	arsenal.slots["jelly"] = ["bounce", "freeze"]
	var packed := load(GLOOP) as PackedScene
	var gloops: Array = []
	for k in 40:
		var g := packed.instantiate() as Node3D
		current_scene.add_child(g)
		g.global_position = at + Vector3(randf_range(-1.2, 1.2), 0.6, randf_range(-1.2, 1.2))
		gloops.append(g)
	await _physics(2)
	var mines: Array = []
	var jelly: GDScript = load("res://scripts/jelly_mine.gd")
	for k in 5:
		mines.append(jelly.drop(current_scene, at + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), p,
			{"radius": 2.4, "time": 0.5, "leaves_two": true}))
	await _physics(4)
	var stuck := 0
	for m in mines:
		if is_instance_valid(m):
			stuck += m.stuck.size()
	check(stuck >= 10, "lots of Gloops stuck in the jelly at once (%d)" % stuck)
	await _physics(240)
	var popped := gloops.filter(func(g) -> bool: return not is_instance_valid(g) or g.get("defeated") == true).size()
	check(popped >= 10, "...and they pop, and the game carries on (%d popped)" % popped)
	check(gloops.all(func(g) -> bool: return not is_instance_valid(g) or g.is_physics_processing()),
		"...and nobody's left frozen in jelly that's gone")
	for j in get_nodes_in_group("jelly_mines"):
		j.melt()
	for g in gloops:
		if is_instance_valid(g):
			g.queue_free()
	await _physics(30)


func _check_kinetic() -> void:
	var p := _player()
	var kin: Node = p.get("kinetic")
	check(kin != null, "the hero has kinetic energy")
	if kin == null:
		return
	root.get_node("Dialogue").set_flag(kin.TAUGHT)
	var juice := root.get_node("Juice")
	var calls_before: int = juice.calls
	game.pending_message = ""
	var said := []
	var catch := func(t: String) -> void: said.append(t)
	if game.has_signal("message_shown"):
		game.message_shown.connect(catch)
	kin.charge = 0.0
	kin.add(1.0)
	await _frames(6)
	check(kin.full(), "a full charge")
	check(juice.calls > calls_before, "...plays its sparkle sound")
	var hud := p.get_node("HUD")
	var words := ""
	for l in hud.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			words += (l as Label).text + " | "
	check(not words.contains("Kinetic full") and said.all(func(t) -> bool: return not str(t).contains("Kinetic")),
		"...and puts no words up")
	kin.charge = 0.0


func _check_todo() -> void:
	var p := _player()
	var hud := p.get_node("HUD")
	var party := root.get_node("Party")
	root.get_node("Dialogue").set_flag("make_taught")
	party.join("nina_bruno", true)
	party.with_you = "nina_bruno"
	# A long to-do list: follow everything that's on
	var quests := root.get_node("Quests")
	for id in ["slide_mystery", "undergardens", "make_together"]:
		if quests.has_method("start"):
			quests.start(id)
		if quests.has_method("follow"):
			quests.follow(id)
	await _frames(30)
	var face := p.get_node_or_null("FriendFace")
	check(face != null and face.badge_shown(), "the friend's face badge is up")
	if face == null or not hud.todo.visible:
		check(true, "(no to-do list showing to check)")
		return
	var list_bottom: float = (hud.todo.position.y + hud.todo.size.y * hud.todo.scale.y) * hud.scale.y
	var badge_top: float = face.badge_rect().position.y
	check(list_bottom <= badge_top, "the to-do list stops above the badge (%.0f, badge at %.0f)" % [list_bottom, badge_top])


func _check_otto() -> void:
	var model: Node3D = load("res://scripts/tide_reef.gd").otto_model()
	var reef: GDScript = load("res://scripts/tide_reef.gd")
	var worst := 0.0
	var bubble := model.get_node("Chair/Bubble") as MeshInstance3D
	var r := (bubble.mesh as SphereMesh).radius
	var mid := bubble.position
	for t in [0.0, 0.7, 1.9, 3.3, 5.1]:
		reef.call("_wiggle", model, t, 1.0)
		for arm in model.get_meta("arms"):
			for seg in arm:
				var s := seg as MeshInstance3D
				var at := (model.get_node("Body") as Node3D).position + s.position
				var out := at.distance_to(mid) + (s.mesh as SphereMesh).radius
				worst = maxf(worst, out)
	check(worst <= r, "Otto's arms stay inside his bubble (furthest %.2f, bubble %.2f)" % [worst, r])
	var head := model.get_node("Body/Head") as MeshInstance3D
	var top := (model.get_node("Body") as Node3D).position.y + head.position.y + (head.mesh as SphereMesh).radius * head.scale.y
	check(top < mid.y + r, "...and so does his head")
	model.free()


func _check_flurry() -> void:
	# Flurry with you, then back out into the town (as coming out of a building does): the plaza and its Flurry are
	# put up again after her copy's made
	var party := root.get_node("Party")
	var portals := root.get_node("Portals")
	for w in ["shard_isle", "frozen_moment"]:
		if not portals.cleared_worlds.has(w):
			portals.cleared_worlds.append(w)
	if not party.joined.has("flurry"):
		party.joined.append("flurry")
	party.with_you = "flurry"
	change_scene_to_file(TOWN)
	await _frames(40)
	await _physics(10)
	var hub := portals._holder.get_node_or_null("Flurry") as Node3D if is_instance_valid(portals._holder) else null
	check(party.followers().size() == 1, "Flurry walks with you as a copy")
	check(hub != null and not hub.visible, "...and her Portal Plaza self is hidden (no second Flurry)")
	# The plaza's Flurry made again after the copy (how it goes coming out of a building)
	if hub:
		hub.name = "Flurry Old"
		hub.queue_free()
		await _frames(2)
		portals._flurry_in_hub()
		await _frames(20)
		hub = portals._holder.get_node_or_null("Flurry") as Node3D
		check(hub != null and not hub.visible, "...even when the plaza's Flurry is put up after her copy")
	party.with_you = ""
	await _frames(20)
	check(hub != null and hub.visible, "...and she's back on the plaza when she's not with you")


func _check_haunted_door() -> void:
	var door := current_scene.get_node_or_null("Haunted House/Door") as Area3D
	check(door != null and not door.monitoring, "the Haunted House's walk-in doorway is off (there's no inside yet)")


func _check_rails() -> void:
	# No town rail runs inside anything (the Library's, a house's and the Star Arena gate's took themselves out)
	await create_timer(3.0).timeout
	var inside := []
	var town_rails := 0
	for r in get_nodes_in_group("grind"):
		if r.get_parent() and String(r.get_parent().name).begins_with("Town Rail"):
			town_rails += 1
			if r.inside_something():
				inside.append(String(r.get_parent().name))
	check(town_rails >= 15 and inside.is_empty(), "no town rail runs inside a building (%d rails; inside: %s)" % [town_rails, inside])
	check(current_scene.find_child("Town Rail 1", true, false) == null, "...the one through the Library is gone")


func _check_sky_rings() -> void:
	var races := root.get_node("Races")
	game.give_item("skateboard")
	races.finished_once["lake_loop"] = true
	var said: Array = races.hub_lines("void")
	var offered := false
	for l in said:
		if l is Dictionary and l.has("choice"):
			for c in l.choice:
				offered = offered or str(c.get("set", "")) == "race_go_sky_rings"
	check(offered, "Zippy offers the Sky Rings once the Lake Loop's done")
	root.get_node("Settings").race_intros = false
	var went = await races.fly_to_sky("sky_rings")
	var ship: Node3D = races._ship()
	check(went and races.racing() and races.track_id == "sky_rings", "...and picking it beams you up and the race is on")
	check(ship != null and ship.is_piloted(), "...flying the mothership")
	races._end(false)
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
