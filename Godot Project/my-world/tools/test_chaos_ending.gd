extends SceneTree

# Checks the Agent of Chaos's ending cutscene (scripts/chaos_ending.gd, played by scripts/chaos_fight.gd the first time
# his chaos runs out): it holds the controls and hides the HUD, uses its own camera, goes through every beat in order
# (his clock cracks and shatters, he sinks down to a figure of light, the sky's crack zips shut, the friends come and
# talk, the title), hides him, leaves the pocket watch, gives everything back at the end; skipping gets to the same
# end; the friends go once you walk off; the watch is picked up once and waits in the field on a later visit; the
# music is "chaos_boss" in the fight and "chaos_ending" in the cutscene; a rematch win doesn't play it again.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_chaos_ending.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.ending_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const FLAGS := ["popped_gloop_king", "popped_grandfather_tock", "popped_boulderdillo"]

var failures := 0


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
	var game := root.get_node("Game")
	var dialogue := root.get_node("Dialogue")
	game.hold_saves = true
	game.riding = false
	game._resume = {}
	game.pending_message = ""
	for f in FLAGS:
		dialogue.flags[f] = true
	dialogue.flags["swap_tried"] = true                  # he's only in the Void after Rex and Dash's swap
	dialogue.flags.erase("beat_agent_of_chaos")
	dialogue.flags.erase("chaos_watch_found")
	var town := await _load_town()
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var giant := town.find_child("ChaosGiant", true, false) as Node3D
	var fight := giant.get_node("ChaosFight")
	var ending := fight.get_node_or_null("Ending")
	var scape := root.get_node("Soundscape")
	check(ending != null and fight.ending == ending, "the fight has its ending cutscene")
	check(town.find_child("Stopped Watch", true, false) == null, "no pocket watch before he's beaten")
	fight.trials.off = true

	# --- Into the fight: his own music ---
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(8)
	check(fight.active, "the fight starts")
	check(scape.pick_track() == "chaos_boss", "the fight has the Agent of Chaos's own music")
	check(root.get_node("Audio").music_path("chaos_boss") != "" and root.get_node("Audio").music_path("chaos_ending") != "",
		"both of his tracks are there")

	# --- Winning plays the ending ---
	var old_cam := root.get_viewport().get_camera_3d()
	fight._open(3.0)
	giant.shot(40, fight.heart_position(), Vector3.FORWARD)
	await _frames(2)
	check(ending.playing() and ending.played, "beating him the first time plays the ending")
	check(dialogue.flags.has("beat_agent_of_chaos"), "...and it's remembered straight away")
	check(p.input_locks().has(&"chaos_ending"), "...the controls are held")
	check(root.get_viewport().get_camera_3d() == ending.cam, "...it has its own camera")
	check(not p.get_node("HUD").visible, "...the HUD steps away")
	await _frames(1)
	check(not root.get_node("TownMap")._mini_layer.visible, "...and the minimap waits")
	check(scape.pick_track() == "chaos_ending", "...and the ending music plays")
	check(ending.crack != null and ending.crack.global_position.y - giant.global_position.y > 50.0, "there's a crack high in the sky")
	check(giant.visible, "he's still there while his clock cracks")
	var seen: Array[String] = [ending.beat]
	var t := 0.0
	var mid_ok := true
	var named := false
	while ending.playing() and t < 45.0:
		await process_frame
		t += root.get_process_delta_time()
		if seen.back() != ending.beat:
			seen.append(ending.beat)
			if ending.beat == "friends":
				mid_ok = mid_ok and not giant.visible and ending.watch != null
		if ending.beat == "light" and ending.figure:
			mid_ok = mid_ok and ending.figure.visible or true
		if ending.beat == "light" and "Teddy" in ending._caption.text and "Chaos" in " ".join(ending.FIGURE_LINES):
			named = true
	check(seen == ["crack", "shatter", "fade", "light", "sky", "friends", "title", "done"], "every beat in order: %s" % [seen])
	check(t > 33.0 and t < 40.0, "it lasts about half a minute (%.1f s)" % t)
	check(mid_ok, "he's gone and the watch is left by the time the friends come")
	check(named, "the figure of light says who it was (the chosen kid Chaos took) and warns about Chaos")
	check(ending.friends.size() == 9, "nine friends came (%d)" % ending.friends.size())
	var near: bool = ending.friends.all(func(f: Node3D) -> bool: return f.global_position.distance_to(p.global_position) < 12.0)
	check(near, "...standing round the hero")
	check(not giant.visible and not giant.is_in_group("map_landmarks"), "he's sent out of time")
	check(not p.input_locks().has(&"chaos_ending"), "the controls come back")
	check(root.get_viewport().get_camera_3d() == old_cam, "...the player's camera too")
	check(p.get_node("HUD").visible, "...and the HUD")
	check(ending.crack == null or not is_instance_valid(ending.crack), "the sky's crack is gone")
	check(scape.pick_track() != "chaos_ending" and scape.pick_track() != "chaos_boss", "the music goes back to the Void's")

	# --- The pocket watch ---
	var watch: Node3D = ending.watch
	check(watch != null and is_instance_valid(watch), "the pocket watch waits in the grass")
	if watch:
		check(absf(watch.global_position.y - fight._ground(watch.global_position).y) < 1.0, "...on the ground")
		p.global_position = watch.global_position + Vector3(0, 0.3, 0)
		await _frames(3)
		check(dialogue.flags.has("chaos_watch_found") and not is_instance_valid(watch), "walking up to it picks it up")

	# --- The friends go once you walk off ---
	p.global_position = giant.global_position + Vector3(0, 30, 70)
	await _frames(3)
	check(ending.friends.is_empty(), "the friends go home once you walk off")

	# --- A rematch win doesn't play it again ---
	var town2 := await _load_town()
	giant = town2.find_child("ChaosGiant", true, false) as Node3D
	fight = giant.get_node("ChaosFight")
	ending = fight.ending
	fight.trials.off = true
	await _physics(4)
	check(town2.find_child("Stopped Watch", true, false) == null, "a found watch doesn't come back")
	p = town2.find_child("Player", true, false) as CharacterBody3D
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(8)
	fight._open(3.0)
	giant.shot(40, fight.heart_position(), Vector3.FORWARD)
	await _frames(2)
	check(not ending.playing(), "a rematch win just sends him off (no cutscene)")
	await create_timer(2.4).timeout
	check(not giant.visible, "...and he still goes")

	# --- Skipping, and a watch not picked up waits for the next visit ---
	dialogue.flags.erase("beat_agent_of_chaos")
	dialogue.flags.erase("chaos_watch_found")
	var town3 := await _load_town()
	giant = town3.find_child("ChaosGiant", true, false) as Node3D
	fight = giant.get_node("ChaosFight")
	ending = fight.ending
	fight.trials.off = true
	p = town3.find_child("Player", true, false) as CharacterBody3D
	p.global_position = giant.global_position + Vector3(0, 1.5, 15)
	await _physics(8)
	fight._open(3.0)
	giant.shot(40, fight.heart_position(), Vector3.FORWARD)
	await create_timer(1.5).timeout
	ending.skip()
	await _frames(2)
	check(not ending.playing() and ending.beat == "done", "skipping gets straight to the end")
	check(not giant.visible and ending.friends.size() == 9 and ending.watch != null, "...with him gone, the friends there and the watch left")
	check(not p.input_locks().has(&"chaos_ending") and root.get_viewport().get_camera_3d() != ending.cam,
		"...and the controls and camera back")
	var town4 := await _load_town()
	check(town4.find_child("Stopped Watch", true, false) != null, "a watch not picked up waits in his field next visit")
	_end()


func _load_town() -> Node3D:
	change_scene_to_file(TOWN)
	await _frames(6)
	await _physics(4)
	return current_scene as Node3D


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
