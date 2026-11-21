extends SceneTree

# Checks the three new characters from Hayden's drawings (21 Nov 2026):
# - Granny Purl teaches Knitting Class in the castle school (scripts/knitting_class.gd): the 2nd floor's Classroom C
#   is named for it, has its sign, desks and yarn, and she's at the front, on the floor, knitting, someone you can talk
#   to, with clear ways in from both doors up to her,
# - Sir Squiggle the top-hat worm lives in the Rootmind (scripts/rootmind.gd _add_worm()): on the moss, clear of
#   everything along his long tail, off the path in, talking, idle while time runs backwards and dancing once mended,
# - the cyber gorillas in the Far Future (scripts/cyber_gorilla.gd, scripts/gorilla_bolt.gd): three while it's fading,
#   on clear ground away from the way in and everyone you need to reach; one that sees you shows its arrows, then
#   fires a slow bolt along them that bumps you if you stay and misses if you step aside; too close and he beats his
#   chest (a ring to jump); bubbles and stomps knock him down (three hits), he comes back later; never during a talk;
#   and when the city's mended they're all gone.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_new_characters.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.new_characters_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.new_characters_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"

var failures := 0
var game: Node
var portals: Node
var dialogue: Node


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
	portals = root.get_node("Portals")
	dialogue = root.get_node("Dialogue")
	root.get_node("Settings").tips = false
	root.get_node("Settings").race_intros = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	root.get_node("Clock").set_time(3, 9 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	for w in ["shard_isle", "rootmind", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor",
			"far_future"]:
		portals.quakes.append(w)
	for w in ["shard_isle", "frozen_moment", "lanternmoor", "rhythm_springs", "tide_reef", "glenmoor"]:
		portals.cleared_worlds.append(w)
	var home_calls = portals.get("home_calls")
	if home_calls:
		home_calls.set("enabled", false)
	await _check_school()
	await _check_rootmind()
	await _check_far_future()
	_finish()


func _player() -> CharacterBody3D:
	return _first_in_group("player") as CharacterBody3D


func _first_in_group(g: String) -> Node:
	return get_first_node_in_group(g)


func _space() -> PhysicsDirectSpaceState3D:
	return (current_scene as Node3D).get_world_3d().direct_space_state


func _on_floor(at: Vector3, exclude: Array = []) -> bool:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.5, 0), at + Vector3(0, -1.0, 0))
	q.exclude = exclude
	var hit := _space().intersect_ray(q)
	return not hit.is_empty() and absf(float(hit.position.y) - at.y) < 0.2


func _solid_at(at: Vector3, r: float, exclude: Array = []) -> Array:
	var shape := SphereShape3D.new()
	shape.radius = r
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis(), at)
	sq.exclude = exclude
	var out: Array = []
	for h in _space().intersect_shape(sq, 8):
		out.append((h.collider as Node).name)
	return out


func _clear_line(a: Vector3, b: Vector3, exclude: Array = []) -> bool:
	# A walk from a to b at knee and chest height with nothing solid in the way
	for y in [0.4, 1.2]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3(0, y, 0), b + Vector3(0, y, 0))
		q.exclude = exclude
		if not _space().intersect_ray(q).is_empty():
			return false
	return true


func _anim_of(n: Node) -> String:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return ap.current_animation if ap else ""


# -----------------------------------------------------------------------------
func _check_school() -> void:
	change_scene_to_file(SCHOOL)
	await _frames(16)
	var kc := root.get_node_or_null("Watches/KnittingClass")
	check(kc != null, "the Knitting Class is under Watches")
	if kc == null:
		return
	var room := current_scene.get_node_or_null("Floor 2/Knitting Class") as Node3D
	check(room != null, "the castle school's 2nd floor has the Knitting Class")
	var g: Node3D = kc.granny()
	check(g != null, "Granny Purl is in it")
	if room == null or g == null:
		return
	var floor_2 := current_scene.get_node("Floor 2") as Node3D
	var local := floor_2.to_local(g.global_position)
	check(local.x > kc.ROOM_MIN.x and local.x < kc.ROOM_MAX.x and local.z > kc.ROOM_MIN.y and local.z < kc.ROOM_MAX.y,
		"...inside its walls")
	var body := g.get_node_or_null("Body") as CollisionObject3D
	var mine: Array = [body.get_rid()] if body else []
	check(_on_floor(g.global_position, mine), "...standing on the floor")
	var hits := _solid_at(g.global_position + Vector3(0, 0.9, 0), 0.4, mine)
	check(hits.is_empty(), "...with nothing solid where she stands %s" % [hits])
	check(g.get_node_or_null("Model") != null and _anim_of(g) == "idle", "...knitting (her idle) (%s)" % _anim_of(g))
	var talk := g.get_node_or_null("Talk")
	check(talk != null and str(talk.get("character_id")) == "yarn_granny", "...and you can talk to her")
	var lines: Array = dialogue.pick_conversation("yarn_granny")
	check(lines.size() >= 2 and lines.size() <= 3 and str(lines[0]).contains("Knitting"), "her hello is short and says what she teaches")
	var named := false
	var old_name := false
	for l in current_scene.find_children("*", "Label3D", true, false):
		if (l as Label3D).text == "Knitting Class":
			named = true
		if (l as Label3D).text == "Classroom C" and floor_2.to_local((l as Label3D).global_position).distance_to(
				Vector3(18.5, 3.6, -3.5)) < 0.5:
			old_name = true
	check(not old_name, "the room's old name is gone")
	check(named, "the room's name says Knitting Class")
	check(room.get_node_or_null("Class Sign") != null, "...a sign by its door")
	var desks := 0
	for c in room.get_children():
		if str(c.name).begins_with("Desk"):
			desks += 1
	check(desks == kc.DESKS.size(), "...and %d desks" % desks)
	# Clear ways in from both doors up to her (desks in two columns leave an aisle)
	var front := floor_2.to_global(Vector3(kc.GRANNY_AT.x, 0, kc.GRANNY_AT.y + 1.0))
	check(_clear_line(floor_2.to_global(Vector3(18.5, 0, 3.6)), front), "a clear aisle from the south door up to her")
	check(_clear_line(floor_2.to_global(Vector3(11.4, 0, -3.5)), floor_2.to_global(Vector3(18.5, 0, -3.5))),
		"...and in from the west door")
	# Going back to the school doesn't put her in twice
	change_scene_to_file(SCHOOL)
	await _frames(16)
	check(current_scene.find_children("Granny Purl", "", true, false).size() == 1, "she's only there once after coming back")


# -----------------------------------------------------------------------------
func _check_rootmind() -> void:
	change_scene_to_file(TOWN)
	await _frames(10)
	portals.enter("rootmind")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(portals.here == "rootmind", "into the Rootmind")
	var w := s.get_node_or_null("Sir Squiggle") as Node3D
	check(w != null, "Sir Squiggle the worm lives in the Rootmind")
	if w == null:
		return
	check(_on_floor(w.global_position), "...on the moss")
	# His body and his long tail (about 1.5 m behind him) are clear of everything
	var back := -w.global_basis.z
	for k in 4:
		var at := w.global_position + back * (k * 0.45) + Vector3(0, 0.35, 0)
		var hits := _solid_at(at, 0.3)
		check(hits.is_empty(), "...nothing solid along him %.1f m back %s" % [k * 0.45, hits])
	# Off the path from the way in to the Heart Glade, and not on top of Bramble or the way home
	check(absf(w.global_position.x) > 3.0, "...beside the path in, not on it (%.1f m off)" % absf(w.global_position.x))
	for n in ["Bramble", "WayHome", "Entrance", "TimeStone"]:
		var m := s.get_node_or_null(n) as Node3D
		if m:
			check(Vector2(w.global_position.x - m.global_position.x, w.global_position.z - m.global_position.z).length() > 3.0,
				"...a good way from %s" % n)
	check(_anim_of(w) == "idle", "...fretting about (idle) while time runs backwards (%s)" % _anim_of(w))
	var talk := w.get_node_or_null("Talk")
	check(talk != null and str(talk.get("character_id")) == "top_hat_worm", "...and you can talk to him")
	var lines: Array = dialogue.pick_conversation("top_hat_worm")
	check(lines.size() == 3 and str(lines[0]).contains("Sir Squiggle"), "his hello is three short lines")
	s.call("worm_dance")
	await _frames(2)
	check(_anim_of(w) == "dance", "once it's mended, he dances (%s)" % _anim_of(w))
	portals.cleared_worlds.append("rootmind")
	dialogue.talks["top_hat_worm"] = 2
	var after: Array = dialogue.pick_conversation("top_hat_worm")
	check(not after.is_empty() and not " ".join(after).contains("backwards"), "...and after, his lines are happy ones")
	portals.go_home()
	await _frames(14)


# -----------------------------------------------------------------------------
func _check_far_future() -> void:
	portals.enter("far_future")
	await _frames(14)
	await _physics(4)
	var s := current_scene
	check(portals.here == "far_future", "into the Far Future")
	var gs: Array = s.call("gorillas")
	check(gs.size() == 3, "three cyber gorillas while it's fading (%d)" % gs.size())
	if gs.size() < 3:
		return
	var entrance := (s.get_node("Entrance") as Node3D).global_position
	var avoid := ["Rex", "Dash", "WayHome", "TimeStone", "Vein1", "Captain", "Folk1", "Folk2", "Folk3", "Folk4",
		"Folk5", "Folk6", "Fuse1", "Lift1", "Lift2"]
	for g in gs:
		var gor := g as CharacterBody3D
		check(_on_floor(gor.global_position, [gor.get_rid()]), "%s stands on the city floor" % gor.name)
		var hits := _solid_at(gor.global_position + Vector3(0, 1.1, 0), 0.9, [gor.get_rid()])
		check(hits.is_empty(), "...with room round him %s" % [hits])
		check(gor.global_position.distance_to(entrance) > float(gor.get("sight")) + 4.0,
			"...out of sight of the way in (%.0f m)" % gor.global_position.distance_to(entrance))
		var nearest := INF
		for n in avoid:
			var m := s.get_node_or_null(n) as Node3D
			if m:
				nearest = minf(nearest, Vector2(gor.global_position.x - m.global_position.x, gor.global_position.z - m.global_position.z).length())
		check(nearest > 8.0, "...well away from everyone you need to reach (%.1f m)" % nearest)
		check(_anim_of(gor) in ["idle", "walk"], "...plodding about (%s)" % _anim_of(gor))
	var gor := gs[0] as CharacterBody3D
	# The others stand still out of the way while we try the first
	for k in range(1, gs.size()):
		(gs[k] as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var p := _player()
	# 1. He sees you, shows his arrows, and fires along them: stay put and it bumps you
	var here := gor.global_position
	p.global_position = here + Vector3(0, 0.85, 9.0)
	p.velocity = Vector3.ZERO
	gor.set("_shoot_cd", 0.0)
	var aimed := false
	var told := false
	for i in 60:
		await physics_frame
		p.global_position = here + Vector3(0, p.global_position.y - here.y, 9.0)
		if float(gor.get("aiming")) > 0.0:
			aimed = true
			told = told or gor.has_meta("boss_tell") and is_instance_valid(gor.get_meta("boss_tell"))
			break
	check(aimed, "he sees you and lifts his blaster")
	check(told, "...with arrows on the ground the way it'll go")
	var hp_before := int(game.hp)
	var hurt := false
	var bolt_seen := false
	for i in 240:
		await physics_frame
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		if not _all_in_group("gorilla_bolts").is_empty():
			bolt_seen = true
		if int(game.hp) < hp_before:
			hurt = true
			break
	check(bolt_seen, "...then a bolt flies out of it")
	check(hurt, "...and standing still in its way, it bumps you")
	check(hp_before - int(game.hp) == 1, "...just a bump (1)")
	# 2. Step aside and it misses
	game.hp = game.max_hp
	await _physics(90)                                   # let her stop blinking
	p.global_position = here + Vector3(0, 0.85, 9.0)
	gor.set("_shoot_cd", 0.0)
	for i in 60:
		await physics_frame
		if float(gor.get("aiming")) > 0.0:
			break
	p.global_position = here + Vector3(3.5, 0.85, 9.0)   # off the arrows
	hp_before = int(game.hp)
	var shots_before := int(gor.get("shots"))
	for i in 150:
		await physics_frame
		p.velocity.x = 0.0
		p.velocity.z = 0.0
		gor.set("_shoot_cd", 99.0)                       # no second shot at the new spot
	check(int(gor.get("shots")) > shots_before, "he fires again")
	check(int(game.hp) == hp_before, "...but you stepped aside, so it misses")
	# 3. Never during a talk
	gor.set("_shoot_cd", 0.0)
	p.global_position = here + Vector3(0, 0.85, 9.0)
	dialogue.say(s.get_node("Rex/Spot"), "Rex", ["One.", "Two.", "Three."])
	var quiet := true
	for i in 40:
		await physics_frame
		if float(gor.get("aiming")) > 0.0:
			quiet = false
	check(quiet, "he never shoots while you're talking to someone")
	dialogue.end()
	await _physics(4)
	# 4. Too close: he beats his chest, a ring to jump
	gor.set("aiming", 0.0)
	gor.set("_shoot_cd", 99.0)
	gor.set("_beat_cd", 0.0)
	p.global_position = here + Vector3(0, 0.85, 2.0)
	var beat := false
	for i in 60:
		await physics_frame
		p.global_position = gor.global_position + Vector3(0, 0.85, 2.0)
		if float(gor.get("beating")) > 0.0:
			beat = true
			break
	check(beat, "too close, he winds up a chest beat")
	var ring := false
	for i in 120:
		await physics_frame
		if not s.find_children("ShockRing", "", true, false).is_empty():
			ring = true
			break
	check(ring, "...and a ring rolls out across the ground")
	p.global_position = here + Vector3(0, 0.85, 30.0)
	# 5. Three bubbles pop him; a big bubble counts for three
	gor.set("_beat_cd", 99.0)
	for k in 3:
		check(str(gor.call("shot", 1, gor.global_position, Vector3.FORWARD)) == "hit", "bubble %d hits him" % (k + 1))
		await _physics(25)
	check(gor.get("defeated") == true, "...three bubbles and he fizzles out")
	check(str(gor.call("shot", 1, gor.global_position, Vector3.FORWARD)) == "miss", "...after that bubbles go through")
	gor.set("_respawn_left", 0.01)
	await _physics(6)
	check(gor.get("defeated") == false and int(gor.get("hp")) == 3, "he comes back a while later, all mended")
	gor.call("shot", 3, gor.global_position, Vector3.FORWARD)
	check(gor.get("defeated") == true, "a big bubble pops him in one")
	# 6. A stomp on his head knocks one off and bounces you up
	var g2 := gs[1] as CharacterBody3D
	g2.process_mode = Node.PROCESS_MODE_INHERIT
	var hp2 := int(g2.get("hp"))
	p.global_position = g2.global_position + Vector3(0, 2.9, 0)
	p.velocity = Vector3(0, -3.0, 0)
	var stomped := false
	for i in 40:
		await physics_frame
		if int(g2.get("hp")) < hp2:
			stomped = true
			break
	check(stomped, "landing on his head knocks a bit off him")
	# 7. Mended: they're all gone
	s.call("mend")
	await _frames(4)
	var left := 0
	for g in s.call("gorillas"):
		if is_instance_valid(g) and not (g as Node).is_queued_for_deletion():
			left += 1
	check(left == 0, "once the city's mended the gorillas are gone (%d left)" % left)


func _all_in_group(g: String) -> Array:
	return get_nodes_in_group(g)


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
