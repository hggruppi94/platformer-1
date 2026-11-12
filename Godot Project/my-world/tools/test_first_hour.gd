extends SceneTree

# The fixes from Hayden's playtest of the first hour (Nov 7, 2026), apart from the Humming Oak questline itself
# (tools/test_first_night.gd walks that):
#   - Theo and Mr. Page sit on a real bench on the green, each on their own seat (they used to stand inside each other
#     in the hay bale on the green's corner)
#   - people stop and turn to listen when you talk to them (Earth's townsfolk never did); someone busy skating or
#     riding carries on
#   - the camera still turns with the mouse after going through the portal to the Void (the minimap used to eat every
#     mouse move there)
#   - the old oak: just a tree on a new game's first day (its door shut), awake for everyone else
#   - a new game brings the collectibles in gradually; an old save has everything out as before
#   - an old save part way through The First Night moves to the same step in the new, longer one
#
#   godot --path "Godot Project/my-world" --script res://tools/test_first_hour.gd    (needs a window for the mouse)
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.first_hour_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var clock: Node
var dialogue: Node
var quests: Node
var fn: Node
var oak: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	dialogue = root.get_node("Dialogue")
	quests = root.get_node("Quests")
	fn = root.get_node("FirstNight")
	oak = root.get_node("HummingOak")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var creator := root.get_node("Creator")

	# --- A new game ---
	game.new_game()
	await _wait_for_scene(EARTH)
	await _frames(10)
	if not creator.is_open():
		creator.open(true)
	await _frames(3)
	game.hero["name"] = "Sunny"
	creator.close()
	await _frames(6)
	check(clock.earth_minutes >= 9 * 60.0 - 1.0 and clock.earth_minutes < 10 * 60.0, "a new game starts in the morning (%s)" % clock.earth_time_string())
	await _physics(40)

	# --- The bench ---
	var bench := current_scene.get_node_or_null("Green Bench") as Node3D
	check(bench != null, "there's a real bench on the green")
	var theo := _body("theo")
	var page := _body("lionel")
	if bench and theo and page:
		check(_flat(theo.global_position - page.global_position) > 0.6, "Theo and Mr. Page each have their own seat (%.2f m apart)" % _flat(theo.global_position - page.global_position))
		check(_flat(theo.global_position - bench.global_position) < 0.8 and _flat(page.global_position - bench.global_position) < 0.8,
			"...on the bench")
		check(theo.get("sitting") == true and page.get("sitting") == true, "...sitting down")
		var hips := _hip_y(theo)
		check(hips > bench.global_position.y + 0.45 and hips < bench.global_position.y + 0.7, "Theo's sat on the seat, not in it (hips %.2f m up)" % (hips - bench.global_position.y))
		for h in current_scene.find_children("*", "MeshInstance3D", true, false):
			if (h as MeshInstance3D).material_override and (h as MeshInstance3D).material_override.resource_name == "Hay":
				check(_flat((h as Node3D).global_position - bench.global_position) > 3.0, "...and nowhere near a hay bale")
				break

	# --- People stop to listen ---
	var walker: Node3D = null
	var walker_talk: Area3D = null
	for r in get_nodes_in_group("routines"):
		if r.get("_travelling") == true and r.get_parent().get_node_or_null("Talk") and r.get_parent().get_script() \
				and str(r.get_parent().get_script().resource_path).ends_with("townsfolk.gd"):
			walker = r.get_parent()
			walker_talk = walker.get_node("Talk")
			break
	if walker == null:
		clock.earth_minutes = 7 * 60.0 + 55.0              # (just before school: kids on their way)
		await _physics(120)
		for r in get_nodes_in_group("routines"):
			if r.get("_travelling") == true and r.get_parent().get_node_or_null("Talk"):
				walker = r.get_parent()
				walker_talk = walker.get_node("Talk")
				break
	check(walker != null, "someone's walking somewhere (%s)" % (walker.name if walker else "nobody"))
	if walker:
		var p := current_scene.find_child("Player", true, false) as CharacterBody3D
		p.global_position = walker.global_position + Vector3(1.5, 0.8, 0)
		await _physics(4)
		dialogue.talk_to(walker_talk)
		await _physics(4)
		var at := walker.global_position
		await _physics(60)
		check(_flat(walker.global_position - at) < 0.05, "talking to %s: they stop where they are" % walker.name)
		var to := p.global_position - walker.global_position
		check(absf(wrapf(walker.rotation.y + (walker.get_parent() as Node3D).global_rotation.y - atan2(to.x, to.z), -PI, PI)) < 0.5,
			"...and turn to face you")
		while dialogue.is_active():
			dialogue._finish_typing()
			dialogue._next()
			await _frames(1)
		await _physics(60)
		check(_flat(walker.global_position - at) > 0.2, "...then carry on")
	var routine: Node = theo.get_node("Routine") if theo else null
	if routine:
		routine._override = {"place": "green_e", "do": "wander", "label": "skating"}
		check(routine.busy(), "someone skating is too busy to stop")
		routine._override = {"place": "green_e", "do": "wander", "label": "skating", "busy": false}
		check(not routine.busy(), "...unless their block says \"busy\": false")
		routine._override = {"place": "green_e", "do": "idle", "label": "reading"}
		check(not routine.busy(), "...and reading isn't busy")

	# --- The oak's asleep on the first day ---
	var door := current_scene.find_child("PortalToGalaxity", true, false)
	check(not oak.awake() and str(door.get("closed_message")).contains("old oak"), "the oak's door is shut on the first day")
	check(current_scene.find_child("Portal Ring", true, false) == null and current_scene.find_child("Old Oak", true, false) != null,
		"no ring in the park, just the old oak")
	check(current_scene.get("crack") == null, "...and no crack in front of it before it wakes (no spoilers)")

	# --- Fewer things to collect at first ---
	check(fn.held_back(2), "a new game holds things back on the first night")
	check(current_scene.get_node_or_null("Notice Board") != null, "the notice board's up on the first day (Nina shows it)")
	var boosters := current_scene.get_node_or_null("Boosters")
	check(boosters != null and boosters.find_children("Coins*", "", false, false).is_empty(), "no booster coins yet (strips and ramps stay)")
	game.go(TOWN, "FromPortaltoEarth")
	await _wait_for_scene(TOWN)
	await _frames(10)
	var watches := current_scene.get_node_or_null("Lost Watches")
	check(watches != null and watches.get_child_count() == 1 and watches.get_child(0).name == "Watch water_clock",
		"only the fountain's lost watch is out on the first night (%d)" % (watches.get_child_count() if watches else -1))
	var letters := current_scene.find_children("Pickup *", "Area3D", true, false)
	check(not letters.is_empty() and letters.all(func(a: Node) -> bool: return not a.visible), "the S-K-A-T-E letters aren't out yet")

	# --- The camera turns after the portal ---
	await create_timer(4.0).timeout                          # (the arrival moment)
	var arm := current_scene.find_child("SpringArm3D", true, false) as Node3D
	var before := arm.rotation.y
	for i in 10:
		var e := InputEventMouseMotion.new()
		e.relative = Vector2(20, 0)
		e.position = root.get_visible_rect().size / 2.0
		Input.parse_input_event(e)
		await process_frame
	# (Headless there's no window to capture the mouse in, so the camera never sees it move: only check with a window)
	if DisplayServer.get_name() != "headless":
		check(absf(wrapf(arm.rotation.y - before, -PI, PI)) > 0.3, "in the Void the mouse still turns the camera (%.2f)" % (arm.rotation.y - before))
	else:
		print("SKIP  in the Void the mouse still turns the camera (needs a window: run without --headless)")
	var mini := root.get_node("TownMap").find_child("Minimap", true, false) as Control
	check(mini != null and mini.mouse_filter == Control.MOUSE_FILTER_IGNORE and \
		mini.find_children("*", "Control", true, false).all(func(c: Control) -> bool: return c.mouse_filter == Control.MOUSE_FILTER_IGNORE),
		"...because the minimap never takes the mouse")

	# --- Later nights, and old saves ---
	var requests := root.get_node("Requests")
	requests.nights = 2
	check(not fn.held_back(2) and fn.held_back(3), "night 2 brings more out")
	var w := root.get_node("Watches")
	check(w.out_tonight("water_clock") and w.out_tonight("many_hands") and not w.out_tonight("egg_timer"), "...the first 8 watches")
	requests.nights = 4
	check(w.out_tonight("glowworm"), "...and every watch from night 4")
	dialogue.flags.erase("fresh_start")
	requests.nights = 0
	check(not fn.held_back(2) and w.out_tonight("glowworm"), "an old save has everything out, as before")

	# --- An old save part way through The First Night ---
	quests.state["first_night"] = {"step": 2, "since_day": 1, "done": false}       # the old "shift" step
	dialogue.flags.erase("fn_v2")
	dialogue.flags.erase("oak_woken")
	fn.migrate()
	check(int(quests.state["first_night"].step) == 7 and fn.step() == "shift", "an old save on the old Shift step is on the Shift step now")
	check(dialogue.flags.has("oak_woken") and oak.awake(), "...with the oak already awake")
	quests.state["first_night"] = {"step": 1, "since_day": 1, "done": false}       # the old "wait" step
	dialogue.flags.erase("fn_v2")
	dialogue.flags.erase("oak_woken")
	fn.migrate()
	check(fn.step() == "wait" and dialogue.flags.has("fn_acorns_placed"), "...and one waiting for midnight is still waiting for midnight")
	fn.migrate()
	check(fn.step() == "wait", "...moved once only")

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")


func _body(id: String) -> Node3D:
	for t in current_scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t.get_parent() as Node3D
	return null


func _hip_y(body: Node3D) -> float:
	var skel := body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := skel.find_bone("hips")
	return (skel.global_transform * skel.get_bone_global_pose(hips).origin).y


func _wait_for_scene(path: String, frames := 200) -> void:
	for i in frames:
		await process_frame
		if current_scene and current_scene.scene_file_path == path:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
