extends SceneTree

# Checks the town's layout (tools/build_town.gd, layout 2): starting a new game in Nina's House, old saves moving to
# the market entrance, buildings not overlapping and their doors on open ground, the districts where they belong, the
# Observatory up its hill, signposts pointing the right way, the portal lighting the neighbourhood in the Shift, Pip
# at the market lamps, and the Scary World gate asking before letting her in.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_layout.gd
#
# Your own save is put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.test_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const HOUSE := "res://scenes/interiors/ninas_house.tscn"
const BT := preload("res://tools/build_town.gd")

var failures := 0
var game: Node
var clock: Node
var messages: Array[String] = []


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
	# Put your save aside. If a backup is already there, an earlier run stopped before putting it back: that backup
	# is your real save, so keep it rather than copying this run's test save over it.
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	game = root.get_node("Game")
	clock = root.get_node("Clock")
	game.message_posted.connect(func(t: String) -> void: messages.append(t))

	# --- 1. A new game starts in Nina's House, just out of bed ---
	check(ProjectSettings.get_setting("application/run/main_scene") == HOUSE, "the game starts in Nina's House")
	DirAccess.remove_absolute(SAVE)
	game._resume = {}
	game.call("load_game")
	check(game.next_spawn == "BedSpawn", "with no save, she wakes up by her bed (spawn %s)" % game.next_spawn)
	change_scene_to_file(HOUSE)
	await _frames(5)
	var p := current_scene.find_child("Player", true, false) as Node3D
	var bed := current_scene.find_child("Bed", true, false) as Node3D
	check(p.global_position.distance_to(bed.global_position) < 3.5, "...right next to it (%.1f m)" % p.global_position.distance_to(bed.global_position))

	# --- 2. Old saves made outdoors move to the market entrance; new ones come back exactly ---
	_write_save({"scene": TOWN, "position": [73.65, 0.77, -29.6], "yaw": 0.0, "level": 3})       # no "layout": old
	game.call("load_game")
	var note: String = game.pending_message
	change_scene_to_file(TOWN)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as Node3D
	var entrance := current_scene.find_child("MarketEntrance", true, false) as Node3D
	check(p.global_position.distance_to(entrance.global_position) < 1.5, "an old-town save starts her at the market entrance (%.1f m)" % p.global_position.distance_to(entrance.global_position))
	check(note.contains("makeover"), "...with a note that the town has changed: \"%s\"" % note)
	_write_save({"scene": TOWN, "position": [10.0, 1.0, 50.0], "yaw": 0.5, "level": 3, "layout": 2})
	game.call("load_game")
	change_scene_to_file(TOWN)
	await _frames(6)
	p = current_scene.find_child("Player", true, false) as Node3D
	check(Vector2(p.global_position.x - 10, p.global_position.z - 50).length() < 1.0, "a new-layout save puts her back exactly where she was")

	# --- 3. Buildings: none overlapping, doors and the spots outside them on open ground ---
	var town := current_scene as Node3D
	var space := town.get_world_3d().direct_space_state
	var domes := []
	for g in town.get_children():
		if g is Node3D and g.find_child("Door", false, false) and (g as Node3D).get_child_count() > 0:
			var shape: Shape3D = null
			for b in g.get_children():
				if b is StaticBody3D and (b.get_child(0) as CollisionShape3D).shape is SphereShape3D:
					shape = (b.get_child(0) as CollisionShape3D).shape
					break
			if shape:
				domes.append([g.name, (g as Node3D).global_position, (shape as SphereShape3D).radius])
	var overlaps := []
	for i in domes.size():
		for j in range(i + 1, domes.size()):
			var d := Vector2(domes[i][1].x - domes[j][1].x, domes[i][1].z - domes[j][1].z).length()
			if d < domes[i][2] + domes[j][2] + 1.0:
				overlaps.append("%s / %s" % [domes[i][0], domes[j][0]])
	check(domes.size() >= 15 and overlaps.is_empty(), "%d buildings, none overlapping: %s" % [domes.size(), overlaps])
	var blocked := []
	for dm in domes:
		var g := town.get_node(NodePath(str(dm[0]))) as Node3D
		for m in g.get_children():
			if m is Marker3D and str(m.name).begins_with("From"):
				var q := PhysicsShapeQueryParameters3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 0.35
				cap.height = 1.5
				q.shape = cap
				q.transform = Transform3D(Basis(), (m as Marker3D).global_position + Vector3(0, 0.3, 0))
				q.exclude = TownPaths.skip_rids(town)
				var hits := space.intersect_shape(q, 4).filter(func(h: Dictionary) -> bool:
					var path := str((h.collider as Node).get_path())
					return not ["Terrain", "Market Square", "Boardwalk", "Dock", "TownSquare", "Skate"].any(func(w: String) -> bool: return path.contains(w)))
				if not hits.is_empty():
					blocked.append("%s (%s)" % [dm[0], (hits[0].collider as Node).get_parent().name])
	check(blocked.is_empty(), "the spot outside every building is clear to stand on: %s" % [blocked])

	# --- 4. The districts ---
	var market: Vector3 = BT.MARKET
	var housing: Vector3 = BT.HOUSING
	var shops_ok := ["Potion Shop", "Cafe", "Restaurant & Cafe", "Pet Shop", "Clothing Boutique", "Book Store", "Town Hall"].all(
		func(n: String) -> bool:
			var g := town.find_child(n, false, false) as Node3D
			return g != null and Vector2(g.global_position.x - market.x, g.global_position.z - market.y).length() < 32.0)
	check(shops_ok, "the Town Hall and the shops ring the Market Square")
	var homes_ok := ["Nina's House", "Dash's House", "Melanie's House", "Empty Home", "Empty Home 2"].all(
		func(n: String) -> bool:
			var g := town.find_child(n, false, false) as Node3D
			return g != null and Vector2(g.global_position.x - housing.x, g.global_position.z - housing.y).length() < housing.z - 4.0)
	check(homes_ok, "the homes are inside the housing district's hedge, east of the lake")
	var obs := town.find_child("Observatory", false, false) as Node3D
	check(obs.global_position.y > 12.0, "the Observatory is up on its hill (%.1f m)" % obs.global_position.y)
	var steepest := 0.0
	var line: Array = BT.MAIN_PATHS[4]
	for k in line.size() - 1:
		for t in 20:
			var a: Vector2 = (line[k] as Vector2).lerp(line[k + 1], t / 20.0)
			var b: Vector2 = (line[k] as Vector2).lerp(line[k + 1], (t + 1) / 20.0)
			var ya := _ground_y(space, town, a)
			var yb := _ground_y(space, town, b)
			steepest = maxf(steepest, rad_to_deg(atan2(absf(yb - ya), a.distance_to(b))))
	check(steepest < 40.0, "the path up the Observatory's hill is walkable (steepest %.0f degrees)" % steepest)

	# --- 5. Signposts point the right way ---
	var targets := {"Market": Vector2(market.x, market.y), "Homes": Vector2(housing.x, housing.y),
		"Castle & School": Vector2(BT.CASTLE_HILL.x, BT.CASTLE_HILL.y), "Observatory": Vector2(BT.OBS_HILL.x, BT.OBS_HILL.y),
		"Portal": Vector2(BT.PORTAL.x, BT.PORTAL.y), "Haunted House": Vector2(BT.HAUNTED_HOUSE.x, BT.HAUNTED_HOUSE.y)}
	var wrong := []
	var boards := 0
	for g in town.get_children():
		if not str(g.name).begins_with("Signpost"):
			continue
		for board in g.get_children():
			var l := board.find_child("*", false, false) as Label3D
			if board is Node3D and board.get_child_count() > 1:
				for c in board.get_children():
					if c is Label3D:
						l = c
				if l == null or not targets.has(l.text):
					continue
				boards += 1
				var pointing := Vector2((board as Node3D).global_transform.basis.x.x, (board as Node3D).global_transform.basis.x.z)
				var want: Vector2 = targets[l.text] - Vector2((g as Node3D).global_position.x, (g as Node3D).global_position.z)
				if rad_to_deg(absf(pointing.angle_to(want))) > 10.0:
					wrong.append("%s at %s" % [l.text, g.name])
	check(boards >= 12 and wrong.is_empty(), "%d signpost boards point toward where they say: %s" % [boards, wrong])

	# --- 6. The portal lights up the neighbourhood in the Shift ---
	var hood := town.find_child("Portal to Earth", false, false).get_node("NeighbourhoodGlow") as OmniLight3D
	clock.set_time(3, 12 * 60.0, true)
	await create_timer(3.0).timeout                    # (the portal takes a moment to close)
	var day_on := hood.visible
	clock.set_time(3, 20.0, true)
	await create_timer(3.0).timeout
	var homes := Vector3(housing.x, 0, housing.y)
	check(not day_on and hood.visible and hood.light_energy > 1.0 and hood.global_position.distance_to(Vector3(BT.PORTAL.x, hood.global_position.y, BT.PORTAL.y)) < 1.0
		and Vector2(hood.global_position.x - homes.x, hood.global_position.z - homes.z).length() < hood.omni_range,
		"in the Shift the portal's glow reaches the homes (and it's dark by day)")

	# --- 7. Pip at the market lamps in the evening, the boardwalk later ---
	var pip: Node = null
	for r in get_nodes_in_group("routines"):
		if r.character_id == "pip":
			pip = r
	p.global_position = Vector3(-140, 2, 100)
	clock.set_time(3, 19 * 60.0, true)
	await _physics(6)
	var pip_at := (pip.get_parent() as Node3D).global_position
	check(pip.activity() == "lamp_watching" and Vector2(pip_at.x - market.x, pip_at.z - market.y).length() < 25.0,
		"at 7 PM Pip is at the market lamps (%.0f m from the fountain)" % Vector2(pip_at.x - market.x, pip_at.z - market.y).length())
	clock.set_time(3, 23 * 60.0, true)
	await _physics(6)
	pip_at = (pip.get_parent() as Node3D).global_position
	check(Vector2(pip_at.x + 7, pip_at.z - 5).length() < 25.0, "at 11 PM he's on the boardwalk")

	# --- 8. Spooky woods: the old slide, and the Scary World gate asks first (it never just lets her in) ---
	check(town.find_child("Old Slide", false, false) != null, "the boarded-up old slide stands by the Haunted House")
	var gate := town.find_child("Scary World Gate", false, false).find_child("Talk", true, false) as Area3D
	p.global_position = gate.global_position + Vector3(0, 0.6, 0)
	await _physics(10)
	await process_frame
	check(current_scene.scene_file_path == TOWN and root.get_node("Dialogue")._nearest == gate,
		"at the Scary World gate: still in town, with a question to answer (%s)" % gate.get("character_id"))
	_finish()


func _ground_y(space: PhysicsDirectSpaceState3D, town: Node, at: Vector2) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80, at.y), Vector3(at.x, -20, at.y))
	q.exclude = TownPaths.skip_rids(town)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0


func _write_save(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game._resume = {}
	game.next_spawn = ""


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)
