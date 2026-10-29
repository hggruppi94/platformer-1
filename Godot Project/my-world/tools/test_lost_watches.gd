extends SceneTree

# Checks the lost watches hunt (scripts/watches.gd, scripts/watch_pickup.gd): there are 20, each its own look, name,
# note and hint, kid-safe; each one can be reached the way its "how" says (stood under, jumped to, waded to, climbed
# to, ridden past on the zipline, grinded past, skated to, beamed down onto from the mothership, or flown through),
# in the town, the school and the Scary World; picking one up sets its flag, shows the card and takes it away for
# good; the sky ones only come to the mothership; Dash takes them and gives each reward once at 5, 10, 15 and 20; the
# Bag shows them all (silhouettes for missing ones) and the map only the found ones; and it all saves and loads, with
# old saves (no watches) still fine.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_lost_watches.gd
#
# Your own save is put aside (under its own name, so another test can't swap it) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.watches_test_backup.json"
const UNSAFE := ["blood", "kill", "dead", "die ", "dies", "gun", "hurt", "scream", "weapon", "monster"]

var failures := 0
var _had_save := false


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
	_had_save = FileAccess.file_exists(SAVE)
	if _had_save and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	var game := root.get_node("Game")
	var watches := root.get_node("Watches")
	var dialogue := root.get_node("Dialogue")
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	dialogue.reset()
	game.items.clear()
	game.popper_colour = "classic"
	# Midday in Galaxity, and no pull home to Earth partway through (a save near the end of the Shift used to end the
	# visit mid-test, so the town checks ran on Earth)
	var clock := root.get_node("Clock")
	clock.pulls_home = false
	clock.set_time(1, 12 * 60.0, true)
	var all: Array = watches.WATCHES

	# --- Twenty, each its own ---
	check(all.size() == 20, "there are 20 lost watches (%d)" % all.size())
	var ids := {}
	var names := {}
	var notes := {}
	var safe := true
	var complete := true
	for w in all:
		ids[w.id] = true
		names[w.name] = true
		notes[w.note] = true
		complete = complete and str(w.note) != "" and str(w.hint) != "" and str(w.place) != "" and \
			w.scene in watches.SCENES and w.pos is Vector3
		for word in UNSAFE:
			if (str(w.note) + " " + str(w.hint) + " " + str(w.name)).to_lower().contains(word):
				safe = false
				print("      unsafe word '%s' in %s" % [word, w.id])
	check(ids.size() == 20 and names.size() == 20 and notes.size() == 20, "every watch has its own id, name and note")
	check(complete, "...and a hint, a place and a spot in a real scene")
	check(safe, "...all kid-safe")
	var looks := {}
	var all_built := true
	for w in all:
		var m: Node3D = watches.model(w.id)
		var parts := m.find_children("*", "MeshInstance3D", true, false).size()
		all_built = all_built and parts >= 4
		var sig := "%d" % parts
		for mi in m.find_children("*", "MeshInstance3D", true, false).slice(0, 3):
			sig += (mi as MeshInstance3D).mesh.get_class()
		looks[sig + str(w.id)] = parts
		m.free()
	check(all_built, "every watch has a model of its own, built from several shapes")
	var hows := {}
	for w in all:
		hows[w.how] = int(hows.get(w.how, 0)) + 1
	check(hows.size() >= 8, "finding them uses every way of getting about (%s)" % str(hows))
	var per_scene := {}
	for w in all:
		per_scene[w.scene] = int(per_scene.get(w.scene, 0)) + 1
	check(per_scene.get("school", 0) >= 1 and per_scene.get("scary", 0) >= 1, "some are in the school and the Scary World")
	var spread := true
	for a in all:
		for b in all:
			if a.id < b.id and a.scene == b.scene and (a.pos as Vector3).distance_to(b.pos) < 8.0:
				spread = false
				print("      %s and %s are too close" % [a.id, b.id])
	check(spread, "they're spread out (8 m apart at least)")

	# --- Every one can be reached ---
	for scene_key in ["town", "school", "scary"]:
		change_scene_to_file(watches.SCENES[scene_key])
		await _frames(6)
		await _physics(4)
		var s := current_scene as Node3D
		var holder := s.get_node_or_null("Lost Watches")
		var here: Array = all.filter(func(w: Dictionary) -> bool: return w.scene == scene_key)
		check(holder != null and holder.get_child_count() == here.size(),
			"%s: all %d of its watches are out there" % [scene_key, here.size()])
		for w in here:
			_reachable(s, w)

	# --- Picking one up (in town) ---
	change_scene_to_file(watches.SCENES.town)
	await _frames(6)
	await _physics(4)
	var town := current_scene as Node3D
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var w0: Dictionary = watches.watch("egg_timer")
	var pick := town.get_node("Lost Watches/Watch egg_timer") as Node3D
	p.global_position = w0.pos + Vector3(4, 0.2, 0)
	await _frames(3)
	check(not watches.is_found("egg_timer") and is_instance_valid(pick), "a watch stays put until she gets there")
	p.global_position = w0.pos + Vector3(0.6, 0.0, 0)
	await _frames(3)
	check(watches.is_found("egg_timer"), "walking into it picks it up (flag watch_found_egg_timer)")
	check(not is_instance_valid(pick), "...and it's gone from where it was")
	check(watches._card.visible and watches._card_title.text.contains(str(w0.name)), "...and its card shows its name")
	check(watches._card_note.text.contains("Chef Pepper"), "...and the note about its owner")
	check(watches.found_count() == 1, "one found")

	# A beam one: floating down the mothership's beam onto the roof gets it
	var wb: Dictionary = watches.watch("pocket")
	p.global_position = wb.pos + Vector3(0, 6, 0)
	await _frames(2)
	check(not watches.is_found("pocket"), "a roof watch isn't picked up from high above it")
	p.global_position = _landing(town, wb.pos, p)
	await _frames(3)
	check(watches.is_found("pocket"), "landing from the beam on the Town Hall dome picks up the one there")

	# The sky ones only come to the mothership
	var ws: Dictionary = watches.watch("galaxy")
	p.global_position = ws.pos
	await _frames(3)
	check(not watches.is_found("galaxy"), "a sky watch doesn't come to her on her own (only the ship can get there)")
	var ship := town.find_child("Mothership", true, false) as Node3D
	ship.set_process(false)
	ship.set_physics_process(false)
	ship.set("pilot", p)
	ship.global_position = ws.pos + Vector3(5, 0, 0)
	await _frames(3)
	check(watches.is_found("galaxy"), "flying the mothership through it picks it up")
	ship.set("pilot", null)
	p.global_position = Vector3(-72, 1.0, 70)

	# The map shows only found ones
	var on_map: Array = watches.found_in_town()
	check(on_map.size() == 3, "the map marks the 3 found in town, and none of the others (%d)" % on_map.size())

	# Coming back: found ones don't come back
	change_scene_to_file(watches.SCENES.town)
	await _frames(6)
	town = current_scene as Node3D
	check(town.get_node_or_null("Lost Watches/Watch egg_timer") == null and
		town.get_node("Lost Watches").get_child_count() == 14, "found watches stay found next time (14 left in town)")

	# --- The Bag ---
	var menu := root.get_node("PlayerMenu")
	menu.open("bag")
	await _frames(3)
	var grid := menu.find_child("Watch Grid", true, false) as GridContainer
	check(grid != null and grid.get_child_count() == 20, "the Bag has a Watches page with all 20")
	if grid:
		var named := (grid.get_node("egg_timer") as Control).find_children("*", "Label", true, false)
		var hidden := (grid.get_node("seashell") as Control).find_children("*", "Label", true, false)
		check(not named.is_empty() and (named[0] as Label).text == "Chef's Egg Timer", "...found ones by name")
		check(not hidden.is_empty() and (hidden[0] as Label).text == "???", "...missing ones as ???")
		var icon := (grid.get_node("seashell") as Control).find_children("*", "SubViewport", true, false)
		var dark := false
		if not icon.is_empty():
			var meshes := (icon[0] as Node).find_children("*", "MeshInstance3D", true, false)
			dark = not meshes.is_empty() and ((meshes[0] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.v < 0.25
		check(dark, "...as a dark silhouette")
		(grid.get_node("seashell") as Button).grab_focus()
		await _frames(1)
		var detail := menu.find_child("Watch Detail", true, false) as Label
		check(detail != null and detail.text.begins_with("Still lost. Hint:"), "picking a missing one shows its hint")
	menu.close()
	await _frames(2)

	# --- Dash ---
	dialogue.talks["dash"] = 4
	var convo: Dictionary = dialogue._pick("dash")
	check(str(convo.get("do", "")) == "Watches.watches_hand_in", "with watches in her pocket, Dash asks for them")
	for flag in dialogue.flags.keys():                    # start his count from none
		if str(flag).begins_with("watch_"):
			dialogue.flags.erase(flag)
	for w in all.slice(0, 5):
		dialogue.set_flag("watch_found_" + str(w.id))
	var sparkles_before: int = game.sparkles
	var lines: Array = watches.watches_hand_in()
	check(watches.given_count() == 5 and watches.to_give().is_empty(), "he takes them all (5 given)")
	check(game.sparkles == sparkles_before + 15, "at 5: 15 sparkles")
	check(lines.size() >= 2, "...and says so")
	check(watches.watches_hand_in().is_empty(), "nothing more to give: nothing happens")
	for w in all.slice(5, 10):
		dialogue.set_flag("watch_found_" + str(w.id))
	watches.watches_hand_in()
	check(game.has_item("popper_colour:clockwork") and game.popper_colour == "clockwork", "at 10: the Clockwork Star Popper")
	var popper_script: Script = load("res://scripts/star_popper.gd")    # (loaded now: it needs the autoloads up)
	var prop: Node3D = popper_script.build_prop("clockwork")
	check(prop.get_meta("colour") == "clockwork" and prop.get_child_count() > popper_script.build_prop().get_child_count(),
		"...which looks different (it has a clock face)")
	for w in all.slice(10, 15):
		dialogue.set_flag("watch_found_" + str(w.id))
	sparkles_before = game.sparkles
	watches.watches_hand_in()
	check(game.has_item("shop:watch_sticker") and game.sparkles == sparkles_before + 10, "at 15: the Tick-Tock Sticker")
	check(Cosmetics.sticker("watch_sticker") != null, "...which has a look for the sash")
	for w in all.slice(15, 20):
		dialogue.set_flag("watch_found_" + str(w.id))
	lines = watches.watches_hand_in()
	check(game.has_item("shop:time_keeper_watch") and game.has_item("shop:time_keeper_pendant"), "at 20: the Time Keeper")
	check(root.get_node("Shop").owned_for("hands").has("time_keeper_watch") and
		root.get_node("Shop").owned_for("neck").has("time_keeper_pendant"), "...to wear on the wrist or round the neck")
	var piece: Node3D = Clothes.hat_or_piece("hands", "time_keeper_watch")
	check(piece != null and piece.get_node_or_null("L") != null and piece.get_node_or_null("R") == null,
		"...the watch goes on one wrist")
	var pend: Node3D = Clothes.hat_or_piece("neck", "time_keeper_pendant")
	check(pend != null, "...and the pendant round the neck")
	check(lines.any(func(l) -> bool: return str(l).contains("twenty")), "Dash thanks you for all twenty")
	var rewards := 0
	for f in dialogue.flags:
		if str(f).begins_with("watch_reward_"):
			rewards += 1
	check(rewards == 4, "every reward given once (4)")
	dialogue.talks["dash"] = 4
	check(str(dialogue._pick("dash").get("do", "")) == "", "with none to give, he talks about other things")
	check(dialogue._fill("{watches_given} of 20, {watches_left} left") == "20 of 20, 0 left", "his lines can count them")

	# --- Saving and loading ---
	game.save_game()
	dialogue.reset()
	game.popper_colour = "classic"
	game.load_game()
	check(watches.found_count() == 20 and watches.given_count() == 20, "found and given watches are saved")
	check(game.popper_colour == "clockwork", "...and the Star Popper's colour")
	# An old save with nothing about watches
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	data.erase("popper_colour")
	var keep: Array = []
	for f in data.dialogue.flags:
		if not str(f).begins_with("watch_"):
			keep.append(f)
	data.dialogue.flags = keep
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(watches.found_count() == 0 and game.popper_colour == "classic", "an old save loads with no watches found")
	_end()


func _reachable(s: Node3D, w: Dictionary) -> void:
	var space := s.get_world_3d().direct_space_state
	var pos: Vector3 = w.pos
	var below := _below(space, pos)
	var gap := pos.y - below.y
	var top := _below(space, Vector3(pos.x, 400.0, pos.z))        # whatever's highest there
	var ok := false
	var why := ""
	match str(w.how):
		"walk", "wade":
			ok = gap > 0.3 and gap < 2.3
			if w.how == "wade":
				ok = ok and below.y < -0.5                           # in water, on the bottom
			why = "%.1f m over what's under it" % gap
		"jump":
			ok = gap >= 1.5 and gap < 3.6
			why = "%.1f m up: a jump" % gap
		"climb":
			var ground := _ground(space, pos)
			ok = gap > 0.3 and gap < 2.3 and below.y - ground > 4.0
			why = "%.1f m over something %.1f m up" % [gap, below.y - ground]
		"zipline":
			var a := (s.find_child("ZipTop", true, false) as Node3D).global_position
			var b := (s.find_child("ZipEnd", true, false) as Node3D).global_position
			var hang := 1.25
			var on := Geometry3D.get_closest_point_to_segment(pos, a - Vector3(0, hang, 0), b - Vector3(0, hang, 0))
			ok = on.distance_to(pos) < 0.6 and gap > 3.0
			why = "%.2f m from the rider's path, %.1f m up" % [on.distance_to(pos), gap]
		"grind":
			var best := INF
			for r in s.get_tree().get_nodes_in_group("grind"):
				var rail := r as GrindRail
				var at := rail.point_at(rail.closest_offset(pos))
				best = minf(best, at.distance_to(pos))
			ok = best < 1.4
			why = "%.2f m over a grind rail" % best
		"skate":
			var pipe := false
			for n in s.find_children("Quarter Pipe*", "Node3D", true, false):
				var d := (n as Node3D).global_position - pos
				pipe = pipe or Vector2(d.x, d.z).length() < 12.0
			ok = pipe and gap < 5.0 and gap > 2.5
			why = "by a quarter pipe, %.1f m up" % gap
		"beam":
			var bounds := Rect2(-135, -245, 270, 340)
			ok = top.distance_to(below) < 0.01 and gap > 0.3 and gap < 2.5 and bounds.has_point(Vector2(pos.x, pos.z))
			why = "on top of a roof, %.1f m over it" % gap
		"sky":
			var bounds := Rect2(-135, -245, 270, 340)
			ok = top.y < pos.y - 16.0 and pos.y < 180.0 and bounds.has_point(Vector2(pos.x, pos.z))
			why = "%.0f m over the ground, inside where the ship can fly" % (pos.y - top.y)
	if w.how != "sky":
		var q := PhysicsShapeQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 0.25
		q.shape = ball
		q.transform = Transform3D(Basis.IDENTITY, pos)
		var stuck := space.intersect_shape(q, 8).any(func(h: Dictionary) -> bool: return h.collider is StaticBody3D)
		ok = ok and not stuck
		if stuck:
			why += ", but it's inside something"
	check(ok, "%s (%s, %s): %s" % [w.name, w.how, w.place, why])


func _below(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
	var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 500.0))
	return h.position if h else Vector3(p.x, -100.0, p.z)


func _ground(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	# The lowest thing under it (the land), going down through whatever's in the way
	var at := p
	var y := -100.0
	for k in 8:
		var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 500.0))
		if h.is_empty():
			break
		y = h.position.y
		at = h.position + Vector3.DOWN * 0.05
	return y


func _landing(s: Node3D, pos: Vector3, player: CollisionObject3D) -> Vector3:
	# Where the mothership's beam puts her down over this spot (scripts/mothership.gd: the first thing below, +0.9,
	# not counting her own capsule, which the ship leaves out too)
	var space := s.get_world_3d().direct_space_state
	var from := Vector3(pos.x, 300.0, pos.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 500.0)
	q.exclude = [player.get_rid()]
	var h := space.intersect_ray(q)
	return (h.position if h else from) + Vector3(0, 0.9, 0)


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
	elif not _had_save:
		DirAccess.remove_absolute(SAVE)              # there wasn't one before: don't leave the test's behind
	quit(1 if failures > 0 else 0)
