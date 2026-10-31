extends SceneTree

# Checks the schematics and the new rides (scripts/schematics.gd, scripts/schematic_pickup.gd, Rides.HERO_RIDES,
# scenes/player/ride_kit.gd; Hayden: "the weapons can stay locked until they are unlocked and purchased"):
# Dash's stall lists every gadget from the start, but each one says "Find its schematic" until it's found; Zippy's
# Tune-Up has the five new rides the same way; a schematic is only out from its own night; every one lands on open
# ground (or, the sky one, in open air); walking into one finds it and the gadget can be bought; an old save's gadgets
# stay its own; each new ride builds, rides, saves and swaps on the Skate page; rocket rides boost harder; the Goals
# page points to the next schematic; and night 2 sends you to the first one.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_schematics.gd
#
# Your own save is put aside (under its own name) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.schematics_backup.json"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"

var failures := 0
var S: Node
var game: Node
var shop: Node
var arsenal: Node
var dialogue: Node
var requests: Node
var messages: Array = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_put_save_back()
		quit(1))
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	S = root.get_node("Schematics")
	game = root.get_node("Game")
	shop = root.get_node("Shop")
	arsenal = root.get_node("Arsenal")
	dialogue = root.get_node("Dialogue")
	requests = root.get_node("Requests")
	root.get_node("Clock").pulls_home = false
	root.get_node("Settings").tips = false
	game.message_posted.connect(func(t: String) -> void: messages.append(t))
	dialogue.reset()
	root.get_node("Quests").reset()
	arsenal.reset()
	game.items.clear()
	game.give_item("skateboard")
	game.hero_ride = "board"
	game.riding = false
	game._resume = {}
	requests.nights = 1

	# --- Everything's on the shelf, but locked ---
	var gadgets: Array = shop.items.values().filter(func(it: Dictionary) -> bool: return str(it.kind) == "gadget")
	check(gadgets.size() == 6, "Dash's stall lists all six gadgets (%d)" % gadgets.size())
	check(gadgets.all(func(it: Dictionary) -> bool: return shop.can_buy(str(it.id)) == "Find its schematic"),
		"...and every one says \"Find its schematic\" on the first night")
	game.sparkles = 999
	check(not shop.buy("fizz_flinger") and not arsenal.owns("fizz") and game.sparkles == 999,
		"...so even with lots of sparkles you can't buy one yet")
	var rides: Array = shop.items.values().filter(func(it: Dictionary) -> bool: return str(it.kind) == "ride")
	check(rides.size() == 5 and rides.all(func(it: Dictionary) -> bool: return str(it.stall) == "Tune-Up"),
		"Zippy's Tune-Up lists the five new rides (%s)" % str(rides.map(func(it: Dictionary) -> String: return str(it.name))))
	check(rides.all(func(it: Dictionary) -> bool: return shop.can_buy(str(it.id)) == "Find its schematic"),
		"...each locked behind its schematic")
	check(rides.all(func(it: Dictionary) -> bool: return int(it.price) > 0 and int(it.price) <= 20), "...each 20 sparkles or less")
	check(str(shop.kinds.gadget.note.call(shop.items["fizz_flinger"])).contains("night 2"),
		"a locked gadget teases which night its schematic turns up (%s)" % shop.kinds.gadget.note.call(shop.items["fizz_flinger"]))
	var whats := {}
	for e in S.LIST:
		whats[str(e.kind) + ":" + str(e.what)] = int(e.night)
	for g in arsenal.ORDER:
		if g != "popper":
			check(whats.has("gadget:" + g), "the %s has a schematic (night %d)" % [g, int(whats.get("gadget:" + g, 0))])
	for r in ["overboard", "bike", "rocket_board", "rocket_bike", "saucer"]:
		check(whats.has("ride:" + r), "the %s has a schematic (night %d)" % [r, int(whats.get("ride:" + r, 0))])

	# --- Only from their own night ---
	await _go(TOWN)
	check(_pickups().is_empty(), "on the first night there are no schematics out")
	requests.nights = 2
	await _go(TOWN)
	var names: Array = _pickups().map(func(n: Node) -> String: return str(n.name))
	check(names == ["Schematic fizz"], "on night 2 the Fizz Flinger's is out, and only that one (%s)" % str(names))
	requests.nights = 7
	await _go(TOWN)
	var town_ones: Array = S.LIST.filter(func(e: Dictionary) -> bool: return str(e.scene) == "town")
	check(_pickups().size() == town_ones.size(), "by night 7 all %d of the town's are out (%d)" % [town_ones.size(), _pickups().size()])

	# --- Each lands somewhere you can get to ---
	await _frames(4)
	var space := (current_scene as Node3D).get_world_3d().direct_space_state
	for p in _pickups():
		var e: Dictionary = S.entry(str(p.id))
		var at: Vector3 = p.global_position
		if e.has("sky"):
			check(_clear(space, at + Vector3(0, 2.5, 0), 6.0), "%s: in open air the mothership can fly through" % e.id)
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -0.4, 0)))
		check(not hit.is_empty(), "%s: on the ground at (%.0f, %.1f, %.0f)" % [e.id, at.x, at.y, at.z])
		check(at.y > -1.0 and pow(at.x / 40.0, 2) + pow(at.z / 17.0, 2) > 1.0 and pow((at.x + 5) / 34.0, 2) + pow((at.z + 32) / 7.0, 2) > 1.0, "%s: not down in the lake (%.1f)" % [e.id, at.y])
		check(_clear(space, at + Vector3(0, 0.9, 0), 0.45), "%s: not inside a wall, a tree or a building" % e.id)

	# --- Finding one ---
	var fizz := current_scene.get_node_or_null("Schematic fizz") as Node3D
	var player := current_scene.find_child("Player", true, false) as CharacterBody3D
	messages.clear()
	if fizz and player:
		player.global_position = fizz.global_position + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		await _frames(6)
	check(S.is_found("fizz") and dialogue.flags.has("schematic_fizz"), "walking into the Fizz Flinger's schematic finds it")
	check(messages.any(func(m: String) -> bool: return m.contains("Fizz Flinger") and m.contains("Dash")),
		"...and says Dash can build it now")
	await _frames(2)
	check(current_scene.get_node_or_null("Schematic fizz") == null, "...and it's gone from the ground")
	check(shop.can_buy("fizz_flinger") == "", "now the Fizz Flinger can be bought")
	check(str(shop.kinds.gadget.note.call(shop.items["disco_ball"])).contains("meadow"),
		"a locked gadget whose schematic is out says where to look (%s)" % shop.kinds.gadget.note.call(shop.items["disco_ball"]))
	game.sparkles = 40
	check(shop.buy("fizz_flinger") and arsenal.owns("fizz"), "...and bought")
	await _go(TOWN)
	check(current_scene.get_node_or_null("Schematic fizz") == null, "a found schematic doesn't come back")
	player = current_scene.find_child("Player", true, false) as CharacterBody3D

	# --- An old save's gadgets stay its own ---
	arsenal.give("disco", false)
	check(shop.can_buy("disco_ball") == "You have this one" and S.gadget_unlocked("disco"),
		"a gadget an old save already has stays its own, schematic or not")

	# --- The Goals page points to the next one ---
	var aim: Array = root.get_node("Nights").goals()[1][1]
	check(aim.any(func(l: String) -> bool: return l.begins_with("Schematic:")), "the Goals page says which schematic to look for next")

	# --- Rides ---
	for r in S.RIDE_PRICES:
		var ride: Dictionary = _ride_for(str(r))
		check(str(ride.kit) != "board" or r == "rocket_board", "%s: has its own kit (%s)" % [r, ride.kit])
		check(float(ride.push_speed) >= 9.0 and float(ride.max_speed) > float(ride.push_speed), "%s: pushes at %.1f m/s, up to %.1f" % [r, ride.push_speed, ride.max_speed])
		check((ride.tricks as Dictionary).has("flips") and (ride.tricks as Dictionary).has("special"), "%s: has its own tricks (%s)" % [r, ride.tricks.special[0]])
		var holder := Node3D.new()
		root.add_child(holder)
		var parts: Dictionary = RideKit.build(str(ride.kit), holder, player.model)
		check(holder.get_child_count() > 0, "%s: its ride is built (%d parts)" % [r, holder.get_child_count()])
		check((parts.get("flames") != null) == bool(ride.get("flames", false)), "%s: %s" % [r, "rockets with flames" if ride.get("flames", false) else "no rockets"])
		holder.queue_free()
	check(str(_ride_for("bike").tricks.flips[""][0]) == "Tailwhip", "the Bike does BMX tricks, like Dash's")

	S.pick_up("overboard")
	check(shop.can_buy("ride_overboard") == "", "finding the Overboard's schematic lets Zippy build it")
	game.sparkles = 40
	check(shop.buy("ride_overboard") and game.has_item("ride:overboard") and game.hero_ride == "overboard",
		"buying it, and it's what you ride now")
	game.riding = true
	game.equipment_changed.emit()
	await _frames(3)
	var skate: Node = player.get("skate")
	check(str(skate.ride.kit) == "overboard" and player.board.get_child_count() > 0, "the hero's on the Overboard (%s)" % skate.ride.kit)
	check(await _rides_along(player), "...and it rolls along")

	# Rocket rides push harder off boosts
	for r in ["rocket_board", "rocket_bike", "saucer", "bike"]:
		S.pick_up(r)
		game.sparkles = 40
		shop.buy("ride_" + r)
		await _frames(2)
		check(game.hero_ride == r and str(skate.ride.kit) == str(_ride_for(r).kit), "the %s can be bought and ridden" % r)
		check(await _rides_along(player), "...and it rolls along")
	S.use_ride("rocket_board")
	await _frames(2)
	skate.boost(5.0, 1.0)
	check(is_equal_approx(float(skate.get("_boost_speed")), 7.0), "the Rocket Board's rockets make a boost 40%% stronger (%.1f)" % float(skate.get("_boost_speed")))
	var flames := player.board.find_child("Flames", true, false) as Node3D
	await _frames(20)
	var flame := flames.get_child(0) as Node3D if flames else null
	check(flame != null and flame.scale.z > 1.3, "...and its flames burn big while it boosts (%.2f)" % (flame.scale.z if flame else 0.0))

	# --- The Skate page swaps rides ---
	var menu := root.get_node("PlayerMenu")
	menu.open("skate")
	await _frames(3)
	var row: Node = menu.root.find_child("Rides", true, false)
	var buttons: Array = row.get_children().filter(func(c: Node) -> bool: return c is Button) if row else []
	check(buttons.size() == 6, "the Skate page has a button for each ride she has (%d)" % buttons.size())
	var bb := row.find_child("Ride board", true, false) as Button if row else null
	if bb:
		bb.pressed.emit()
	await _frames(3)
	check(game.hero_ride == "board" and str(skate.ride.kit) == "board", "...and picking the Skateboard puts her back on it")
	menu.close()
	await _frames(2)

	# --- Saving ---
	S.use_ride("saucer")
	game.save_game()
	game.hero_ride = "board"
	game.load_game()
	check(game.hero_ride == "saucer", "the ride you're on is saved")
	var f := FileAccess.open(SAVE, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data.items = (data.items as Array).filter(func(i) -> bool: return str(i) != "ride:saucer")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.hero_ride == "board", "...and a save riding something it doesn't have rides the board")
	data.erase("hero_ride")
	f = FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	game.load_game()
	check(game.hero_ride == "board" and S.is_found("fizz"), "a save from before the rides rides the board, and keeps what it found")

	# --- Night 2 sends you to the first one ---
	var q: Dictionary = root.get_node("Quests").quest("night_2")
	var items: Array = q.steps[1].checklist.map(func(c: Array) -> String: return str(c[0]))
	check(items.has("schematic_fizz"), "night 2's list has finding the Fizz Flinger's schematic")

	# --- The school's ---
	requests.nights = 7
	game.riding = false
	await _go(SCHOOL)
	var plush := current_scene.get_node_or_null("Schematic plush") as Node3D
	check(plush != null, "the Plushinator's schematic is at the castle school")
	if plush:
		var sp := (current_scene as Node3D).get_world_3d().direct_space_state
		var hit := sp.intersect_ray(PhysicsRayQueryParameters3D.create(plush.global_position + Vector3(0, 0.3, 0), plush.global_position + Vector3(0, -0.4, 0)))
		check(not hit.is_empty() and _clear(sp, plush.global_position + Vector3(0, 0.9, 0), 0.45),
			"...on the floor, in the open (%s)" % str(plush.global_position))

	_put_save_back()
	print("RESULT %s (%d failed)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(failures)


func _ride_for(r: String) -> Dictionary:
	var was: String = game.hero_ride
	game.hero_ride = r
	var out: Dictionary = Rides.ride("hero")
	game.hero_ride = was
	return out


func _rides_along(player: CharacterBody3D) -> bool:
	# Push forward for a second on open ground, and see she gets going without falling off
	player.global_position = Vector3(-4, 1.5, 24)
	player.velocity = Vector3.ZERO
	await _physics(4)
	Input.action_press("move_forward")
	var top := 0.0
	for i in 70:
		await physics_frame
		top = maxf(top, Vector2(player.velocity.x, player.velocity.z).length())
	Input.action_release("move_forward")
	var skate: Node = player.get("skate")
	print("    (top speed %.1f m/s)" % top)
	return top > 4.0 and int(skate.state) != int(skate.State.BAIL)


func _clear(space: PhysicsDirectSpaceState3D, at: Vector3, r: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = r
	q.shape = ball
	q.transform = Transform3D(Basis(), at)
	for got in space.intersect_shape(q, 8):
		var c: Object = got.collider
		if c is StaticBody3D or c is CSGShape3D:
			return false
	return true


func _pickups() -> Array:
	return current_scene.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("Schematic "))


func _go(scene: String) -> void:
	change_scene_to_file(scene)
	for i in 30:
		await process_frame
		if current_scene and current_scene.scene_file_path == scene:
			break
	await _frames(6)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _put_save_back() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.remove_absolute(SAVE)
		DirAccess.rename_absolute(BACKUP, SAVE)
		print("Put your own save back.")
