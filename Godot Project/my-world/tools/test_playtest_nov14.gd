extends SceneTree

# Checks Hayden's 14 Nov 2026 playtest fixes (thread "Fix swimming, board and world bugs"):
#   - the gadget readout only pops up for a moment when you switch gadget (scripts/gadget_wheel.gd)
#   - a Shift that the computer forgot to let go of is let go of by the next key (scripts/settings.gd)
#   - a portal's window into the Tide Reef no longer floods the Void (scripts/portals.gd _only_a_picture)
#   - Otto's bubble sits round your head (on the head bone), and out of the water you drip and look wet, then dry
#     (scripts/swim.gd)
#   - the giant mushrooms in the Undergardens are solid, stem and cap (scripts/garden_caves.gd)
#   - every Fluffkin in Glenmoor can be herded into the Fold (scripts/glenmoor.gd: they go round walls and slip out
#     of corners)
# (Riding fakie looking forward is in tools/test_skate_help.gd.)
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_playtest_nov14.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.nov14_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.nov14_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const REEF := "res://scenes/portal_worlds/tide_reef.tscn"
const GLEN := "res://scenes/portal_worlds/glenmoor.tscn"

var failures := 0
var game: Node
var portals: Node


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
	portals = root.get_node("Portals")
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
	await _check_readout()
	await _check_shift()
	await _check_preview()
	await _check_mushrooms()
	await _check_swim()
	await _check_fluffkins()
	_finish()


func _check_readout() -> void:
	var arsenal := root.get_node("Arsenal")
	var player := current_scene.get_tree().get_first_node_in_group("player")
	var wheel := player.find_child("GadgetWheel", true, false)
	check(wheel != null, "the gadget wheel's on her HUD")
	if wheel == null:
		return
	arsenal.give("popper", false)
	arsenal.give("fizz", false)
	await _frames(3)
	check(wheel.readout_left > 0.0, "getting or switching a gadget pops the readout up")
	wheel.readout_left = 0.05
	await _frames(20)
	check(wheel.readout_left == 0.0 and wheel.modulate.a < 0.01, "...and then it goes away, so it never covers what you're reading")
	arsenal.select("popper")
	await _frames(3)
	check(wheel.readout_left > 1.0 and wheel.modulate.a > 0.9, "switching again shows it again")
	wheel.readout_left = 0.0


func _key(code: Key, pressed: bool, shift := false) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	k.shift_pressed = shift
	Input.parse_input_event(k)


func _check_shift() -> void:
	_key(KEY_SHIFT, true, true)
	await _frames(2)
	check(Input.is_action_pressed("dash"), "holding Shift holds Roll")
	_key(KEY_W, true, true)
	await _frames(3)
	check(Input.is_action_pressed("dash"), "...and a key pressed while it's down doesn't let go of it")
	_key(KEY_W, false, true)
	_key(KEY_W, true, false)                  # the computer says Shift's up, but its "let go" never came
	await _frames(3)
	check(not Input.is_action_pressed("dash") and not Input.is_physical_key_pressed(KEY_SHIFT),
		"a Shift that got stuck down is let go of by the next key (no stuck sprint or dive)")
	_key(KEY_W, false, false)
	await _frames(2)


func _check_preview() -> void:
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef"]:
		if not w in portals.cleared_worlds:
			portals.cleared_worlds.append(w)
		if not w in portals.quakes:
			portals.quakes.append(w)
	change_scene_to_file(TOWN)
	await _frames(14)
	await _physics(4)
	# Home from the reef: out in front of its crack, where its window is open
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var w: Dictionary = portals.world("tide_reef")
	player.global_position = Vector3(w.at.x, 1.5, w.at.y) + Vector3(sin(w.yaw), 0, cos(w.yaw)) * 3.2
	player.velocity = Vector3.ZERO
	await _physics(60)
	var g: Node = portals.crack("tide_reef")
	var view := g.get_node_or_null("Preview") if g else null
	check(view != null, "the Tide Reef's crack shows its window")
	if view == null:
		return
	var wet := current_scene.get_tree().get_nodes_in_group("water").filter(func(n: Node) -> bool: return view.is_ancestor_of(n))
	check(wet.is_empty(), "...and none of the reef's water in it counts as water in the Void")
	check(not player.call("is_swimming") and not player.get("swim").view_under,
		"home by the crack, the Void isn't flooded: you stand on the ground (%.1f m)" % player.global_position.y)


func _check_mushrooms() -> void:
	var ug := current_scene.get_node_or_null("Undergardens")
	var m := ug.find_child("Mushroom1", true, false) if ug else null
	check(m != null, "the Mushroom Grotto's giant mushrooms are there")
	if m == null:
		return
	check(m.get_node_or_null("Stem Shape") != null and m.get_node_or_null("Cap Shape") != null,
		"...solid in the stem and the cap")
	var top := (m as Node3D).global_position + Vector3(0, 3.0, 0)
	var q := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -3.0, 0))
	var hit := (current_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	var cap := m.find_children("*", "MeshInstance3D", false, false).filter(func(c: Node) -> bool: return (c as MeshInstance3D).mesh is SphereMesh)
	var dome_top := (cap[0] as Node3D).global_position.y + ((cap[0] as MeshInstance3D).mesh as SphereMesh).height \
		if not cap.is_empty() else 0.0
	check(not hit.is_empty() and absf((hit.position as Vector3).y - dome_top) < 0.1,
		"...and you stand on top of the cap, not sunk into it (%.2f vs %.2f)" % [(hit.position as Vector3).y if not hit.is_empty() else -1.0, dome_top])


func _check_swim() -> void:
	change_scene_to_file(REEF)
	await _frames(14)
	await _physics(4)
	current_scene.set_flood(1.0)
	var player := current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var swim: Node = player.get("swim")
	player.global_position = Vector3(0, 6, 8)
	player.velocity = Vector3.ZERO
	await _physics(90)
	var helmet: Node3D = swim.get("_helmet")
	var model: Node3D = player.get("model")
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var head := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head")).origin
	var off := helmet.global_position - head
	check(swim.under and helmet.visible and absf(off.y - swim.HELMET_UP) < 0.05 and Vector2(off.x, off.z).length() < 0.06,
		"under the water, Otto's bubble sits right round your head (%s from the head bone)" % off)
	swim.stop(swim.HOP)
	await _frames(3)
	var dark := model.find_children("*", "MeshInstance3D", true, false).filter(func(c: Node) -> bool:
		return (c as MeshInstance3D).material_overlay != null and (c as MeshInstance3D).material_overlay == swim.get("_wet_mat"))
	check(swim.wet > 0.9 and not dark.is_empty(), "out of the water you're soaked: your clothes go darker (%d parts)" % dark.size())
	var drops := 0
	for i in 20:
		await process_frame
	drops = current_scene.find_children("*", "GPUParticles3D", true, false).size() + current_scene.find_children("*", "CPUParticles3D", true, false).size()
	check(drops > 0, "...and you drip")
	swim.wet = 0.01
	await _frames(30)
	dark = model.find_children("*", "MeshInstance3D", true, false).filter(func(c: Node) -> bool:
		return (c as MeshInstance3D).material_overlay != null and (c as MeshInstance3D).material_overlay == swim.get("_wet_mat"))
	check(swim.wet == 0.0 and dark.is_empty(), "...then you dry off, back as you were")


func _check_fluffkins() -> void:
	portals.cleared_worlds.erase("glenmoor")                  # (not mended yet: the Fluffkins are still out)
	change_scene_to_file(GLEN)
	await _frames(14)
	await _physics(4)
	var s := current_scene
	s.set_process(false)
	s.set_physics_process(false)
	var player := s.get_tree().get_first_node_in_group("player") as CharacterBody3D
	var fold := s.get_node("Fold") as Node3D
	var c := fold.global_position
	var r := float(fold.get_meta("radius"))
	var gate := float(fold.get_meta("gate"))
	var gdir := Vector3(cos(gate), 0, sin(gate))
	var all := true
	for i in s.FLUFFS:
		var f := s.fluffkin(i) as Node3D
		var t := 0.0
		var pp := f.global_position + Vector3(8, 0, 0)
		while t < 60.0 and not s.is_penned(i):
			# A herder walking round behind it: out to the gate, then in
			var fp := f.global_position
			var tgt := c + gdir * (r + 3.0)
			if Vector2(fp.x - c.x, fp.z - c.z).length() < r + 4.0 and (fp - c).normalized().dot(gdir) > 0.6:
				tgt = c
			var want := tgt - fp
			want.y = 0.0
			var spot := fp - want.normalized() * 3.2
			var to := spot - pp
			to.y = 0.0
			pp += to.normalized() * minf(to.length(), 5.0 / 30.0)
			player.global_position = pp + Vector3(0, 0.9, 0)
			s.fluff_step(player, 1.0 / 60.0)
			s.fluff_step(player, 1.0 / 60.0)
			await physics_frame
			t += 1.0 / 30.0
		check(s.is_penned(i), "Fluffkin %d can be herded into the Fold (%.0f s)" % [i + 1, t])
		all = all and s.is_penned(i)


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
