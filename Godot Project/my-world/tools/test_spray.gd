extends SceneTree

# Checks the spray paint (scripts/spray_can.gd, scripts/paint.gd): the Spray paint button is on V and R3, hidden in
# Controls until the cans are bought at the Toy Shop / the Toys stall; with the cans out her camera's over her
# shoulder, the can's in her hand and no gadget fires; paint sticks to the ground and walls (not people), a stroke
# joins up, painting over a spot recolours it instead of piling up, water washes it off, it stays put when she goes
# away and comes back, and it's in the save. Holding Shoot really paints, and riding puts the cans away.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_spray.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.spray_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var settings: Node
var paint: Node
var shop: Node
var _save := ""
var _backup := ""
var _had_save := false


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
	game = root.get_node("Game")
	settings = root.get_node("Settings")
	paint = root.get_node("Paint")
	shop = root.get_node("Shop")
	_save = game.save_path()
	_backup = _save.get_basename() + ".spray_test_backup.json"
	_had_save = FileAccess.file_exists(_save)
	if _had_save and not FileAccess.file_exists(_backup):
		DirAccess.copy_absolute(_save, _backup)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	game._reset_state()
	game._resume = {}
	game.pending_message = ""

	# --- The button and buying the cans ---
	var listed := func(list: Array) -> bool: return list.any(func(p: Array) -> bool: return p[0] == "spray")
	check(listed.call(settings.REBINDABLE) and listed.call(settings.PAD_REBINDABLE), "Spray paint is in both control lists")
	check(settings.key_name("spray") == "V" and settings.pad_name("spray") == "R3",
		"...on V and R3 (%s, %s)" % [settings.key_name("spray"), settings.pad_name("spray")])
	var clash := false
	for a in settings.default_bindings():
		if a != "spray" and settings.default_bindings()[a] == KEY_V:
			clash = true
	for a in settings.default_pad_bindings():
		if a != "spray" and settings.default_pad_bindings()[a] == JOY_BUTTON_RIGHT_STICK:
			clash = true
	check(not clash, "...which nothing else uses")
	check(not settings.action_shown("spray"), "...hidden in Controls until she has the cans")
	check(shop.items.has("spray_can") and str(shop.items["spray_can"].stall) == "Toy Shop"
		and shop.items.has("spray_cans") and str(shop.items["spray_cans"].stall) == "Toys",
		"the cans are sold at the Toy Shop on Earth and the Toys stall in the Void")
	game.sparkles = 10
	check(shop.can_buy("spray_can") == "", "...and can be bought (%s)" % shop.can_buy("spray_can"))
	check(shop.buy("spray_can") and game.has_item("spray_can"), "buying them")
	check(shop.can_buy("spray_cans") == "You have some", "...once is enough (%s)" % shop.can_buy("spray_cans"))
	check(settings.action_shown("spray"), "...and now Controls lists the button")

	# --- In town ---
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(20)
	var town := current_scene
	var p := town.find_child("Player", true, false) as CharacterBody3D
	var can = p.get("spray")
	var popper = p.get("popper")
	check(can != null, "she has the spray cans on her")
	check(paint.layer != null and paint.layer.is_inside_tree() and paint.place == TOWN, "the town has a paint layer")
	paint.wash_all()
	root.get_node("Arsenal").give("popper", false)
	can.set_active(true)
	await _physics(15)
	check(can.active and popper.painting and popper.aiming, "cans out: she aims like with the popper")
	check(not popper.can_shoot(), "...and no gadget fires")
	var prop = popper.get("_prop")
	check(prop != null and str(prop.get_meta("gadget", "")) == "spray", "...the can's in her hand")

	# Paint on the ground in front of her
	var space := p.get_world_3d().direct_space_state
	var ahead := p.global_position + (p.get("visual") as Node3D).global_transform.basis.z.normalized() * 3.0
	var q := PhysicsRayQueryParameters3D.create(ahead + Vector3(0, 3, 0), ahead + Vector3(0, -6, 0))
	q.exclude = [p.get_rid()]
	var g := space.intersect_ray(q)
	check(not g.is_empty() and paint.paintable(g.collider, g.position), "the ground in front of her takes paint (%s)"
		% (str(g.collider.name) if not g.is_empty() else "nothing"))
	if g.is_empty():
		_finish()
		return
	var spot: Vector3 = g.position
	can.pick(0)
	var got: int = can.spray_at(spot, g.normal, g.collider)
	check(got == 1 and paint.count() == 1 and paint.colour_at(spot) == 0, "a puff leaves a red dab")
	var t: Transform3D = paint.dab_transform(paint.places[TOWN], 0)
	check(t.origin.distance_to(spot) < 0.1 and (t.origin - spot).dot(g.normal) > 0.005,
		"...lying flat on the ground, just above it")
	# A stroke joins up
	var end := spot + Vector3(1.0, 0, 0)
	var g2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(end + Vector3(0, 3, 0), end + Vector3(0, -6, 0)))
	if not g2.is_empty():
		end = g2.position
	can.spray_at(end, g.normal, g.collider)
	var n: int = paint.count()
	check(n >= 6, "a quick sweep is a line, not two dots (%d dabs)" % n)
	check(paint.colour_at(spot.lerp(end, 0.5)) == 0, "...painted all the way along")
	# Painting over the same spot
	can._last = {}
	can.pick(4)
	for i in 30:
		can.spray_at(spot, g.normal, g.collider)
	check(paint.colour_at(spot) == 4, "painting over a spot: the new colour's on top")
	check(paint.count() < n + 12, "...and it doesn't pile up dab on dab (%d -> %d)" % [n, paint.count()])
	# Not on people
	var someone := CharacterBody3D.new()
	town.add_child(someone)
	can._last = {}
	check(can.spray_at(spot + Vector3(0, 1, 0), Vector3.UP, someone) == 0, "no paint on people or anything that moves")
	var mover := AnimatableBody3D.new()
	check(not paint.paintable(mover), "...nor moving platforms")
	mover.free()
	someone.queue_free()
	# A wall: anything solid that stays put
	var wall := StaticBody3D.new()
	var look := MeshInstance3D.new()
	look.mesh = BoxMesh.new()
	wall.add_child(look)
	town.add_child(wall)
	wall.global_position = Vector3(0, 50, 0)
	check(paint.paintable(wall, Vector3(0, 50, 0.5)), "walls and rocks take paint")
	var bounds := StaticBody3D.new()
	town.add_child(bounds)
	bounds.global_position = Vector3(0, 80, 0)
	check(not paint.paintable(bounds, Vector3(0, 80, 0.5)), "...but not the invisible walls round a world")
	# A window on that wall: only a thin mesh stuck out in front of it, with the wall's collision behind (as the
	# builders make them). Paint goes on the glass, not hidden behind it (Hayden: "the paint is behind the window").
	var glass := MeshInstance3D.new()
	var pane := BoxMesh.new()
	pane.size = Vector3(0.6, 0.6, 0.1)
	glass.mesh = pane
	town.add_child(glass)
	glass.global_position = Vector3(0, 50, 0.55)
	paint._skins_ready = false
	var on_glass: Vector3 = paint.outside(Vector3(0, 50, 0.5), Vector3(0, 0, 1))
	check(absf(on_glass.z - 0.6) < 0.01, "paint on a window sits on the glass, not behind it (z %.3f)" % on_glass.z)
	var by_glass: Vector3 = paint.outside(Vector3(0.45, 50, 0.5), Vector3(0, 0, 1))
	check(absf(by_glass.z - 0.5) < 0.001, "...and beside the window it's still on the wall (z %.3f)" % by_glass.z)
	var sideways: Vector3 = paint.outside(Vector3(0, 50.5, 0), Vector3(0, 1, 0))
	check(sideways.is_equal_approx(Vector3(0, 50.5, 0)), "...and nothing moves on the wall's top")
	var was: int = paint.count()
	can._last = {}
	can.spray_at(Vector3(0, 50, 0.5), Vector3(0, 0, 1), wall)
	check(paint.count() > was and paint.colour_at(Vector3(0, 50, 0.6)) >= 0, "spraying a window leaves paint on it")
	check(paint.wash(Vector3(0, 50, 0.6), 0.5) > 0, "...and water washes it off the glass")
	glass.queue_free()
	var bridge := StaticBody3D.new()
	bridge.add_to_group("made_thing")
	check(not paint.paintable(bridge), "...nor a made bridge that'll pop")
	bridge.free()
	wall.queue_free()
	bounds.queue_free()

	# --- It stays put ---
	var before: int = paint.count()
	game.save_game()
	paint.reset()
	check(paint.count() == 0, "(reset clears it)")
	var data = JSON.parse_string(FileAccess.get_file_as_string(_save))
	check(data is Dictionary and data.has("paint"), "the paint is in the save")
	paint.load_data(data.get("paint", {}))
	check(paint.count() == before and paint.colour_at(spot) == 4, "...and comes back from it (%d dabs)" % paint.count())
	check(paint.layer.multimesh.visible_instance_count == before, "...drawn again")
	change_scene_to_file(EARTH)
	await _frames(8)
	check(paint.place == EARTH and paint.count() == 0, "Stars Hollow has its own paint (none yet)")
	change_scene_to_file(TOWN)
	await _frames(10)
	check(paint.place == TOWN and paint.count() == before and paint.layer.multimesh.visible_instance_count == before,
		"back in the Void, the paint's still there")
	town = current_scene
	p = town.find_child("Player", true, false) as CharacterBody3D
	can = p.get("spray")
	popper = p.get("popper")

	# --- Water washes it off ---
	can.wash_at(spot)
	check(paint.colour_at(spot) == -1, "water washes it off where it lands")
	check(paint.count() > 0 and paint.count() < before, "...only there (%d left)" % paint.count())
	for i in 12:
		can.wash_at(spot.lerp(end, i / 11.0))
	check(paint.count() == 0, "washing along the line takes it all off")
	can.pick(can.WATER)
	check(can.current_colour().b > 0.9, "the palette's last pot is water")
	can.cycle(1)
	check(can.colour == 0, "...and round again to red")

	# --- Really holding Shoot ---
	can.set_active(true)
	await _physics(10)
	p.spring_arm.rotation.x = -0.85                  # look down at the ground in front of her
	await _physics(5)
	var hit: Dictionary = can.aim_hit()
	check(not hit.is_empty(), "looking down, the crosshair's on the ground")
	var d0: int = can.dabs
	Input.action_press("shoot")
	await _physics(40)
	Input.action_release("shoot")
	await _physics(3)
	check(can.dabs > d0 and paint.count() > 0, "holding Shoot sprays paint (%d puffs)" % (can.dabs - d0))
	var c0: int = paint.count()
	Input.action_press("aim")
	await _physics(30)
	Input.action_release("aim")
	await _physics(3)
	check(paint.count() < c0, "holding Aim washes it off (%d -> %d)" % [c0, paint.count()])
	# A full place says so
	paint.places[TOWN] = PackedFloat32Array()
	var full := PackedFloat32Array()
	for i in paint.MAX_DABS:
		full.append_array([0, -50, 0, 0, 1, 0, 0, 0.1, 0, 0.012])
	paint.places[TOWN] = full
	paint._rebuild()
	can._last = {}
	check(can.spray_at(spot + Vector3(30, 0, 30), Vector3.UP, null) == 0 and paint.full(), "a place can get full")
	paint.wash_all()

	# --- Putting them away ---
	game.give_item("skateboard")
	game.riding = true
	await _physics(5)
	check(not can.active and not popper.painting, "riding puts the cans away")
	game.riding = false
	await _physics(3)
	Input.action_press("spray")
	await _physics(2)
	Input.action_release("spray")
	await _physics(2)
	check(can.active, "the Spray paint button gets them out")
	Input.action_press("spray")
	await _physics(2)
	Input.action_release("spray")
	await _physics(2)
	check(not can.active and not popper.painting, "...and puts them away again")

	# --- A new game has none ---
	game._reset_state()
	check(not game.has_item("spray_can") and paint.count() == 0, "a new game has no cans and no paint")

	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("shoot")
	Input.action_release("aim")
	Input.action_release("spray")
	if FileAccess.file_exists(_backup):
		DirAccess.rename_absolute(_backup, _save)
	elif not _had_save and FileAccess.file_exists(_save):
		DirAccess.remove_absolute(_save)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.rename_absolute(SETTINGS_BACKUP, SETTINGS)
	elif FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(SETTINGS)
	quit(1 if failures > 0 else 0)
