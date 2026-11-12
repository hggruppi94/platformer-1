extends SceneTree

# Checks the Seer and the Wizard Lizard as principal (scripts/council.gd, scripts/seer.gd, dialogue/seer.json,
# dialogue/wizard_lizard.json):
# - the Observatory's door in the Void now goes somewhere: its interior, with a way back out to the Observatory,
# - the Seer is there, on the floor, dressed (shawl, lantern, Hoot, walking stick), and someone you can talk to,
# - her first talk introduces her and the Council; after that she reads her lantern: the step you're on for the quest
#   you follow (and nothing else), or a quiet evening with nothing followed; her bottles once, after one's found,
# - the Council's table and its six chairs are there,
# - the castle school has the principal's office on the 3rd floor with the Wizard Lizard in it, its name over it, a
#   sign by its door and one in the foyer; while Turtle Independence is on he's out in the Secret Gardens instead
#   (and not in his office), and after it he's back,
# - the Wizard Lizard's lines: the principal's hello the first time at school, a "hello again" if you met him with
#   the turtles first.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_council.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.council_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.council_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const OBSERVATORY := "res://scenes/interiors/observatory.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const TURTLES := "turtle_independence"

var failures := 0
var game: Node
var quests: Node
var dialogue: Node
var council: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	quests = root.get_node("Quests")
	dialogue = root.get_node("Dialogue")
	council = root.get_node_or_null("Watches/Council")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Clock").set("pulls_home", false)
	check(council != null, "the Council node is under Watches (dialogue says Watches/Council.fortune)")
	if council == null:
		_finish()
		return
	await _check_door()
	await _check_observatory()
	_check_seer_lines()
	await _check_school()
	_check_lizard_lines()
	_finish()


# -----------------------------------------------------------------------------
func _check_door() -> void:
	change_scene_to_file(TOWN)
	await _frames(12)
	var obs := current_scene.get_node_or_null("Observatory") as Node3D
	check(obs != null, "the Void has its Observatory")
	if obs == null:
		return
	var door := obs.get_node_or_null("Door") as Area3D
	check(door != null and str(door.get("destination")) == OBSERVATORY, "its door goes to the Observatory inside")
	check(ResourceLoader.exists(OBSERVATORY), "...which is built (scenes/interiors/observatory.tscn)")
	check(obs.get_node_or_null("FromObservatory") != null, "...and there's somewhere to come back out to in front of it")


func _check_observatory() -> void:
	change_scene_to_file(OBSERVATORY)
	await _frames(12)
	await _physics(4)
	var s := current_scene
	var exit := s.get_node_or_null("ExitToTown") as Area3D
	check(exit != null and str(exit.get("destination")) == TOWN and str(exit.get("spawn")) == "FromObservatory",
		"the way out goes back to the Void, in front of the Observatory")
	check(s.get_node_or_null("Entrance") != null, "there's an Entrance to come in at")
	var seer := s.get_node_or_null("The Seer") as Node3D
	check(seer != null, "the Seer is at home")
	if seer == null:
		return
	var talk := seer.get_node_or_null("Talk")
	check(talk != null and str(talk.get("character_id")) == "seer" and str(talk.get("display_name")) == "The Seer",
		"...and you can talk to her (dialogue/seer.json)")
	check(seer.get("model") != null, "...made from the townsfolk body")
	for part in ["Seer Shawl", "Seer Lantern", "Seer Owl", "Seer Walking Stick", "Seer Skirt"]:
		check(seer.find_child(part, true, false) != null, "...with her " + part.trim_prefix("Seer ").to_lower())
	var shawl := seer.find_child("Star Shawl", true, false) as MeshInstance3D
	check(shawl != null and shawl.material_override is ShaderMaterial, "...her shawl is the moving star cloth")
	var glass := seer.find_child("Lantern Glass", true, false) as MeshInstance3D
	check(glass != null and glass.material_override is ShaderMaterial, "...her lantern has mist swirling inside")
	# Standing on the floor, not in it or over it
	var space := (s as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(seer.global_position + Vector3(0, 3, 0), seer.global_position + Vector3(0, -3, 0))
	var hit := space.intersect_ray(q)
	check(not hit.is_empty() and absf(float(hit.position.y) - seer.global_position.y) < 0.15,
		"she stands on the floor (%.2f)" % (seer.global_position.y - float(hit.get("position", Vector3.ZERO).y)))
	# Nothing solid where she stands, and she's within reach of the door
	var shape := SphereShape3D.new()
	shape.radius = 0.3
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = shape
	sq.transform = Transform3D(Basis(), seer.global_position + Vector3(0, 0.8, 0))
	check(space.intersect_shape(sq).is_empty(), "nothing solid where she stands")
	var hoot := seer.get("owl") as Node3D
	check(hoot != null, "Hoot rides on her shoulder")
	var table := s.get_node_or_null("Council Table")
	check(table != null, "the Council's round table is there")
	if table:
		var chairs := 0
		for c in table.get_children():
			if str(c.name).begins_with("Council Chair"):
				chairs += 1
		check(chairs == 6, "...with six chairs round it (%d)" % chairs)
		check(table.find_child("Council Orb", true, false) != null, "...and its glowing orb")
	check(s.get_node_or_null("Telescope") != null, "the big telescope's there")


func _check_seer_lines() -> void:
	dialogue.talks.erase("seer")
	var first := _joined(dialogue.pick_conversation("seer"))
	check("I'm the Seer" in first and "Council" in first and "Hoot" in first,
		"the first time, she says who she is, Hoot, and the Council")
	dialogue.talks["seer"] = 1
	var convo: Array = dialogue.pick_conversation("seer")
	check("lantern" in _joined(convo), "after that, she offers to read her lantern")
	# A fortune: the step of the quest you follow, said her way
	quests.state[TURTLES] = {"step": 1, "since_day": 1, "done": false}
	quests.chose_none = false
	quests.follow_only(TURTLES)
	dialogue.flags.erase("seer_bottles_talked")
	for f in dialogue.flags.keys():
		if str(f).begins_with("sunk_seer"):
			dialogue.flags.erase(f)
	var reading := _joined(council.fortune())
	var o: Dictionary = quests.objectives()
	var goal := ""
	for item in o.get("items", []):
		if not item[1]:
			goal = str(item[0])
			break
	check(str(o.get("name", "")) != "" and str(o.name) in reading, "her lantern names the quest you follow (%s)" % o.get("name"))
	check(goal != "" and goal.trim_suffix(".") in reading, "...and the step you're on")
	check(not "bottle" in reading, "...no bottles before you've found one")
	# Nothing followed: a quiet evening
	quests.followed.clear()
	quests.chose_none = true
	reading = _joined(council.fortune())
	check("tea" in reading and not "thread" in reading, "with nothing followed, her lantern shows a quiet evening")
	# A bottle found: she says so, once
	dialogue.flags["sunk_seer_oak"] = true
	reading = _joined(council.fortune())
	check("bottles" in reading, "after you find one of her bottles, she talks about them")
	check(dialogue.flags.has("seer_bottles_talked") and not "bottles" in _joined(council.fortune()), "...only once")
	quests.chose_none = false
	quests.state.erase(TURTLES)
	dialogue.flags.erase("sunk_seer_oak")


func _check_school() -> void:
	quests.state.erase(TURTLES)
	change_scene_to_file(SCHOOL)
	await _frames(14)
	var office := current_scene.get_node_or_null("Floor 3/Principal's Office") as Node3D
	check(office != null, "the castle school has the principal's office on the 3rd floor")
	if office == null:
		return
	var liz: Node3D = council.principal()
	check(liz != null, "the Wizard Lizard is in it")
	if liz:
		var talk := liz.get_node_or_null("Talk")
		check(talk != null and str(talk.get("character_id")) == "wizard_lizard", "...and you can talk to him")
		var at := liz.global_position
		var floor_3 := current_scene.get_node("Floor 3") as Node3D
		var local := floor_3.to_local(at)
		check(local.x > council.OFFICE_MIN.x and local.x < council.OFFICE_MAX.x and local.z > council.OFFICE_MIN.y
			and local.z < council.OFFICE_MAX.y, "...inside its walls")
		var space := (current_scene as Node3D).get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at + Vector3(0, -2, 0))
		var hit := space.intersect_ray(q)
		check(not hit.is_empty() and absf(float(hit.position.y) - at.y) < 0.15, "...standing on the floor")
		var shape := SphereShape3D.new()
		shape.radius = 0.3
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = shape
		sq.transform = Transform3D(Basis(), at + Vector3(0, 0.8, 0))
		check(space.intersect_shape(sq).is_empty(), "...with nothing solid where he stands")
	var named := false
	for l in current_scene.find_children("*", "Label3D", true, false):
		if (l as Label3D).text == "Principal's Office":
			named = true
	check(named, "the room's name says Principal's Office")
	check(office.get_node_or_null("Sign PRINCIPAL") != null, "...a sign by its door")
	check(current_scene.get_node_or_null("Floor 1/Principal Sign") != null,
		"...and a sign in the foyer pointing the way")
	# On the turtles' days he's in the Secret Gardens instead
	quests.state[TURTLES] = {"step": 0, "since_day": 1, "done": false}
	check(council.lizard_away(), "while Turtle Independence is on, he's away")
	change_scene_to_file(SCHOOL)
	await _frames(14)
	check(current_scene.get_node_or_null("Floor 3/Principal's Office") != null and council.principal() == null,
		"...his office is there but he's not in it")
	var eps := root.get_node("Watches/Episodes")
	check(bool(eps.guests().wizard_lizard.here), "...he's in the Secret Gardens with the turtles")
	quests.state[TURTLES] = {"step": 3, "since_day": 1, "done": true}
	check(not bool(eps.guests().wizard_lizard.here) and not council.lizard_away(),
		"once it's done he's out of the Gardens and back at school")
	change_scene_to_file(SCHOOL)
	await _frames(14)
	check(council.principal() != null, "...in his office")


func _check_lizard_lines() -> void:
	dialogue.flags.erase("met_lizard")
	dialogue.flags.erase("turtle_met_lizard")
	quests.state.erase(TURTLES)
	var hello := _joined(dialogue.pick_conversation("wizard_lizard"))
	check("principal" in hello and "Seer" in hello and "every version of you" in hello,
		"the first time at school he's the principal, gives his rules and points to the Seer")
	dialogue.flags["met_lizard"] = true
	quests.state[TURTLES] = {"step": 0, "since_day": 1, "done": false}
	var wake := _joined(dialogue.pick_conversation("wizard_lizard"))
	check("Hello again" in wake and "turtles" in wake.to_lower(), "met at school first, the turtle day says hello again")
	dialogue.flags.erase("met_lizard")
	var fresh := _joined(dialogue.pick_conversation("wizard_lizard"))
	check("I am the Wizard Lizard" in fresh and "principal of the castle school" in fresh,
		"met with the turtles first, he says he's the principal there")
	dialogue.flags["turtle_met_lizard"] = true
	quests.state[TURTLES] = {"step": 3, "since_day": 1, "done": true}
	var after := _joined(dialogue.pick_conversation("wizard_lizard"))
	check("turtles' helper" in after, "...and at school after, he remembers the turtles")
	dialogue.flags["met_lizard"] = true
	check(_joined(dialogue.pick_conversation("wizard_lizard")) != "", "after that he always has something to say")
	quests.state.erase(TURTLES)


# -----------------------------------------------------------------------------
func _joined(lines: Array) -> String:
	var out := []
	for l in lines:
		out.append(JSON.stringify(l))
	return " ".join(out)


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
