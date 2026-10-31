extends SceneTree

# Checks the people of the Earth town (tools/build_earth.gd, scripts/townsfolk.gd): everyone's there and made from
# the hero system, their routines (res://routines/<id>.json, "world": "earth") run on Earth's clock along Earth's
# paths (res://routines/earth_places.json) and reach every place, nobody walks through a wall or into the pond, the
# right people are about at each time of day, they walk when the player's watching, their talk changes with the time
# and what they're doing, human Nina lives at the Blastoffs' (and goes to bed in her own room), and Prue and Bruno are
# marked as placeholders.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_townsfolk.gd
#
# Your own save is put aside first (user://save.townsfolk_backup.json) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.townsfolk_backup.json"
const EARTH := "res://scenes/earth/earth.tscn"
const FAR_AWAY := Vector3(80, 1, 95)                # the empty southeast corner, out of everyone's sight
# Everyone with a routine, and Madame Celeste, who stays in her studio
const PEOPLE := ["palmer_earth", "ivy", "theo", "gus", "dottie", "barnaby", "marigold", "poppy", "otis", "wren", "hank", "kip",
	"lionel", "juniper", "ozzie", "nina_earth", "prue", "bruno"]

var failures := 0
var clock: Node
var game: Node
var dialogue: Node
var player: CharacterBody3D
var paths: TownPaths
var routines := {}
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	clock = root.get_node("Clock")
	game = root.get_node("Game")
	dialogue = root.get_node("Dialogue")
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	dialogue.reset()
	root.get_node("Quests").reset()
	dialogue.line_shown.connect(func(who: String, text: String) -> void: said.append([who, text]))
	paths = TownPaths.get_shared(TownPaths.EARTH_FILE)
	_check_files()
	game._resume = {}
	game.pending_message = ""
	game.next_spawn = "Entrance"
	clock.set_earth_time(12 * 60.0, true)
	change_scene_to_file(EARTH)
	await _frames(8)
	player = current_scene.find_child("Player", true, false) as CharacterBody3D
	player.global_position = FAR_AWAY
	for r in current_scene.get_tree().get_nodes_in_group("routines"):
		routines[str(r.character_id)] = r
	check(routines.size() == PEOPLE.size() and PEOPLE.all(func(id: String) -> bool: return routines.has(id)),
		"everyone in town has a routine (%d): %s" % [routines.size(), routines.keys()])
	check(routines.values().all(func(r: Node) -> bool: return r.earth), "...on Earth's clock and paths")

	_check_people()
	await _check_paths()
	await _check_day()
	await _check_walking()
	await _check_talk()
	_check_blastoffs()

	_put_save_back()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(0 if failures == 0 else 1)


# -----------------------------------------------------------------------------
# Files: every routine's places are on Earth's paths and joined to the green; every dialogue file reads
# -----------------------------------------------------------------------------
func _check_files() -> void:
	var places_ok := true
	var joined_ok := true
	for id in PEOPLE:
		var data = (load("res://routines/%s.json" % id) as JSON).data
		check(data is Dictionary and str(data.get("world", "")) == "earth" and not data.blocks.is_empty(),
			"routines/%s.json is an Earth routine" % id)
		for b in data.blocks:
			if not paths.has(str(b.place)):
				places_ok = false
				print("      %s: no place called %s" % [id, b.place])
			elif paths.route("gazebo", str(b.place)).is_empty():
				joined_ok = false
				print("      %s: no way from the green to %s" % [id, b.place])
		var talk = (load("res://dialogue/%s.json" % id) as JSON)
		check(talk != null and talk.data is Dictionary and not talk.data.get("conversations", []).is_empty(),
			"dialogue/%s.json reads" % id)
	check(places_ok, "every place in everyone's day is on Earth's paths")
	check(joined_ok, "...and every one can be walked to from the green")


# -----------------------------------------------------------------------------
# The people themselves
# -----------------------------------------------------------------------------
func _check_people() -> void:
	var folk: Array = current_scene.find_children("*", "Townsfolk", true, false)
	check(folk.size() == PEOPLE.size() + 1, "%d townsfolk (everyone and Madame Celeste)" % folk.size())
	var made := true
	var animated := true
	for f in folk:
		var model: Node3D = f.model
		if model == null or Clothes._skeleton(model) == null:
			made = false
		var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model else null
		if ap == null or not ap.has_animation("walk") or not ap.has_animation("idle"):
			animated = false
			print("      %s can't walk" % f.name)
	check(made, "each one has a body")
	check(animated, "...that can stand and walk")
	var hero_made := folk.filter(func(f: Node) -> bool: return f.model_path == Townsfolk.BODY)
	check(hero_made.size() == folk.size() - 1, "all but Mr. Palmer are the Earth kid body, made like a hero (%d)" % hero_made.size())
	var palmer := _body("palmer_earth") as Townsfolk
	check(palmer.model_path.ends_with("mr_palmer.glb"), "Mr. Palmer is his own human self on Earth")
	var styled := true
	for f in hero_made:
		var hair_or_bald := int(f.look.get("hairstyle", 0)) > 0
		var shaped := (f.model as Node3D).scale.y > 0.5
		var skel := Clothes._skeleton(f.model)
		if not hair_or_bald or not shaped or skel.get_node_or_null("BodyShape") == null:
			styled = false
			print("      %s isn't styled" % f.name)
	check(styled, "...each with their own hairstyle, height and body shape")
	var grownups := hero_made.filter(func(f: Node) -> bool: return float(f.look.height) > 1.2)
	var kids := hero_made.filter(func(f: Node) -> bool: return float(f.look.height) < 1.1)
	check(grownups.size() >= 12 and kids.size() >= 6, "%d grown-ups (taller) and %d kids" % [grownups.size(), kids.size()])
	var looks := {}
	for f in hero_made:
		looks[JSON.stringify(f.look) + str(f.extras)] = true
	check(looks.size() == hero_made.size(), "no two look the same")
	var things := 0
	for f in hero_made:
		things += Clothes._skeleton(f.model).find_children("Own *", "BoneAttachment3D", false, false).size()
	check(things >= 25, "their own things are on them (%d: aprons, glasses, a guitar, Nina's bow...)" % things)


func _check_blastoffs() -> void:
	var nina := _body("nina_earth") as Townsfolk
	check(nina.name == "Nina" and int(nina.look.hairstyle) == Hairstyles.NAMES.find("Bob") and int(nina.look.colors.hair) == 9,
		"human Nina has a red bob")
	var kinds := nina.extras.map(func(e: Dictionary) -> String: return str(e.kind))
	check("bow" in kinds and "turtleneck" in kinds and int(nina.look.colors.top) == 6, "...her red bow and a black turtleneck")
	var skel := Clothes._skeleton(nina.model)
	check(skel.get_node_or_null("Own bow") != null and skel.get_node_or_null("Own turtleneck") != null, "...and she's wearing them")
	check((_body("prue") as Townsfolk).placeholder and (_body("bruno") as Townsfolk).placeholder and not nina.placeholder,
		"Prue and Bruno are marked as placeholders (Nina isn't)")
	check((_body("bruno") as Townsfolk).outfit.get("head", "") == "sk8_beanie", "Bruno wears his SK8 beanie")
	var blocks: Array = routines.nina_earth.blocks
	check(blocks.any(func(b: Dictionary) -> bool: return b.place == "nina_room" and b.do == "away"),
		"Nina goes to bed in her own room at the Blastoffs'")


# -----------------------------------------------------------------------------
# Every link of Earth's paths is clear to walk: no wall, fence or prop across it, never through water
# -----------------------------------------------------------------------------
func _check_paths() -> void:
	await _frames(2)
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(current_scene)
	var blocked := []
	var wet := []
	var floating := []
	for l in paths.links:
		var a := paths.position_of(str(l[0]), space, skip)
		var b := paths.position_of(str(l[1]), space, skip)
		for h in [0.55, 1.4]:
			var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, b + Vector3.UP * h)
			q.exclude = skip
			var hit: Dictionary = space.intersect_ray(q)
			if hit and not _is_ground(hit.collider) and not _step_up(hit, a, b):
				blocked.append("%s-%s (%s)" % [l[0], l[1], str((hit.collider as Node).get_path()).get_slice("/", 3)])
				break
		for k in 9:
			var p := a.lerp(b, (k + 1) / 10.0)
			var g := TownPaths.ground_at(p, space, skip, 2.0)
			if EarthLand.is_water(g.x, g.z) and g.y < EarthLand.WATER_Y + 0.1:
				wet.append("%s-%s" % [l[0], l[1]])
				break
	for name in paths.points:
		var p := paths.position_of(name, space, skip)
		var floor_y: float = paths.floors.get(name, EarthLand.height(paths.points[name].x, paths.points[name].y))
		if absf(p.y - floor_y) > 1.0:
			floating.append("%s (%.1f, not %.1f)" % [name, p.y, floor_y])
	check(paths.points.size() >= 70 and paths.links.size() >= 80,
		"Earth's paths: %d places, %d links" % [paths.points.size(), paths.links.size()])
	check(blocked.is_empty(), "nothing stands across any path: %s" % [blocked])
	check(wet.is_empty(), "...and none goes through the pond or the creek: %s" % [wet])
	check(floating.is_empty(), "every place is on its floor (not a roof): %s" % [floating])


func _is_ground(n: Object) -> bool:
	var path := str((n as Node).get_path())
	return path.contains("/Land") or path.contains("Steps") or path.contains("Gate Ramp") or path.contains("Porch")


func _step_up(hit: Dictionary, a: Vector3, b: Vector3) -> bool:
	# A low step on the way (a porch, the dock, the yard's concrete): the ray meets its edge at knee height
	return (hit.position as Vector3).y < maxf(a.y, b.y) + 0.6


# -----------------------------------------------------------------------------
# Through the day, with nobody watching: everyone's simply where their schedule says (or at home)
# -----------------------------------------------------------------------------
func _check_day() -> void:
	player.global_position = FAR_AWAY
	var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(current_scene)
	for t in ["07:15", "10:30", "12:30", "15:30", "19:45", "23:50", "03:00"]:
		clock.set_earth_time(clock.parse_time(t), true)
		await _settle()
		var wrong := []
		var out := 0
		for id in PEOPLE:
			var r: Node = routines[id]
			var b: Dictionary = r.current_block()
			var body := r.get_parent() as Node3D
			var want := paths.position_of(str(b.place), space, skip)
			var far := Vector2(body.global_position.x - want.x, body.global_position.z - want.z).length()
			if b.do == "away":
				if body.visible:
					wrong.append("%s should be in (%s)" % [id, b.place])
			else:
				out += 1
				if not body.visible or far > float(b.get("radius", 0.0)) + 1.5:
					wrong.append("%s is %.1f m from %s" % [id, far, b.place])
		check(wrong.is_empty(), "%s: everyone's where they should be (%d out and about) %s" % [t, out, wrong])
	clock.set_earth_time(clock.parse_time("03:00"), true)
	await _settle()
	check(PEOPLE.all(func(id: String) -> bool: return not (routines[id].get_parent() as Node3D).visible),
		"3 AM: the whole town's asleep")
	clock.set_earth_time(clock.parse_time("23:50"), true)
	await _settle()
	check(routines.palmer_earth.activity() == "oak_watch" and (routines.palmer_earth.get_parent() as Node3D).visible,
		"just before midnight Mr. Palmer's out by the old oak")


# -----------------------------------------------------------------------------
# Walking: when the player's near, people walk to their next place along the paths, never through a building
# -----------------------------------------------------------------------------
func _check_walking() -> void:
	for trip in [["ivy", "14:59", "bookshop"], ["nina_earth", "14:59", "skate_yard"], ["palmer_earth", "16:29", "gazebo"],
			["kip", "15:59", "library_door"]]:
		var id: String = trip[0]
		clock.set_earth_time(clock.parse_time(trip[1]) - 0.4, true)
		await _settle()
		var r: Node = routines[id]
		var body := r.get_parent() as Node3D
		if not body.visible:                                     # (at school until three: watch her come out of it)
			r.snap()
		player.global_position = body.global_position + Vector3(3, 1, 3)
		Engine.time_scale = 6.0
		var started := false
		var through := []
		for i in 20000:
			await physics_frame
			player.global_position = body.global_position + Vector3(3, 1, 3)
			if r.is_travelling():
				started = true
				var roof := _roof_over(body.global_position)
				if roof != "" and roof not in through:
					through.append(roof)
			elif started:
				break
		Engine.time_scale = 1.0
		print("      %s: started %s, travelling %s, at %s, time %s, block %s" % [id, started, r.is_travelling(), body.global_position,
			clock.earth_time_string(), r.current_block().place])
		var space: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
		var dest := paths.position_of(trip[2], space, TownPaths.skip_rids(current_scene))
		var d := Vector2(body.global_position.x - dest.x, body.global_position.z - dest.z).length()
		check(started and not r.is_travelling() and d < 6.0, "%s walks to %s while the player watches (%.1f m from it)" % [id, trip[2], d])
		var walk_ins := ["Earth Town Hall", "Bakery", "Toy Shop", "Library", "Blastoff House", "String Lights", "Lamps", "Trees"]
		check(through.all(func(n: String) -> bool: return n in walk_ins),
			"...without walking through a building (only in and out of doors): %s" % [through])


func _roof_over(pos: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.UP * 30)
	q.exclude = TownPaths.skip_rids(current_scene)
	var hit: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(q)
	return str((hit.collider as Node).get_path()).get_slice("/", 3) if hit else ""


# -----------------------------------------------------------------------------
# Talk: hello the first time, then lines for the time of day and what they're doing
# -----------------------------------------------------------------------------
func _check_talk() -> void:
	var cases := [
		["gus", "07:00", ["own the diner"], ["Coffee?"]],
		["dottie", "11:30", ["Maple Inn"], ["little chat"]],
		["barnaby", "21:30", ["troubadour"], ["flickers green"]],
		["kip", "13:30", ["six"], ["Pumpkins!"]],
		["nina_earth", "17:45", ["Nina Blastoff"], ["hums louder near midnight"]],
		["palmer_earth", "23:50", ["plain old Mr. Palmer"], ["admiring the old oak"]],
		["juniper", "17:30", ["star reporter"], ["Just pie"]],
		["poppy", "15:30", ["cauldron cakes"], ["fresh air"]],
	]
	for c in cases:
		var id: String = c[0]
		clock.set_earth_time(clock.parse_time(c[1]), true)
		await _settle()
		var first := await _talk(id)
		var then := await _talk(id)
		check(_said(first, c[2]) and _said(then, c[3]), "%s at %s: \"%s\", then \"%s\"" % [id, c[1],
			first[0][1] if first.size() > 0 else "", then[0][1] if then.size() > 0 else ""])
	for id in PEOPLE:
		var hello := (await _talk(id)) if (routines[id].get_parent() as Node3D).visible else [[id, "(away)"]]
		if hello.is_empty():
			check(false, "%s has something to say" % id)
			return
	check(true, "everyone out and about has something to say")
	var bad := []
	for id in PEOPLE:
		var text := FileAccess.get_file_as_string("res://dialogue/%s.json" % id)
		for word in [" he ", " she ", " his ", " her ", " him "]:
			for line in text.split("\n"):
				if line.contains("{player}:") and line.contains(word):
					bad.append(id)
	check(bad.is_empty(), "nobody's lines assume the player's gender: %s" % [bad])


func _talk(id: String) -> Array:
	var r: Node = routines[id]
	var body := r.get_parent() as Node3D
	var t := body.get_node("Talk") as Area3D
	player.global_position = body.global_position + body.global_basis.z * 1.6 + Vector3(0, 0.8, 0)
	player.velocity = Vector3.ZERO
	for i in 4:
		await physics_frame
	said.clear()
	dialogue.talk_to(t)
	await _frames(2)
	var guard := 300
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			buttons[0].grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")
			await _frames(1)
			_press("interact")
		await _frames(2)
	await create_timer(0.25).timeout
	player.global_position = FAR_AWAY
	return said.duplicate()


func _said(lines: Array, words: Array) -> bool:
	return words.all(func(w: String) -> bool: return lines.any(func(l: Array) -> bool: return str(l[1]).contains(w)))


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


# -----------------------------------------------------------------------------
func _body(id: String) -> Node3D:
	return routines[id].get_parent() as Node3D if routines.has(id) else null


func _settle() -> void:
	for i in 4:
		await physics_frame
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
