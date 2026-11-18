extends SceneTree

# Checks the detailed props treatment across the whole game (16 Nov 2026, Hayden: "Can you give the whole game this
# treatment?"):
# - scripts/static_batch.gd merges still pieces in every place, not only Stars Hollow, and the places draw fewer meshes,
# - scripts/batch_watch.gd puts a group back the moment one of its pieces moves, hides, changes look or is freed,
# - scripts/mesh_lods.gd gives big meshes made in code their distance LODs (same shape up close),
# - scripts/detail_props.gd dresses the Void's Market Square with the six detailed stalls, keeping their shop spots,
#   names and collision,
# - with WorldDetail's switches off, a place is exactly as before.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_detail_all.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.detail_all_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.detail_all_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
# A place of each kind: the school, a portal world, a boss level, a race circuit, a room
const OTHERS := ["res://scenes/school/school.tscn", "res://scenes/portal_worlds/far_future.tscn",
	"res://scenes/portal_worlds/tide_reef.tscn", "res://scenes/bosses/gloop_kingdom.tscn",
	"res://scenes/races/lake_loop.tscn", "res://scenes/interiors/my_house.tscn",
	"res://scenes/secret_garden/secret_garden.tscn"]

var failures := 0
var detail: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 11 * 60.0, true)
	detail = root.get_node("WorldDetail")

	# --- The Void with everything off: as it was
	_switch(false)
	await _load(TOWN)
	var s := current_scene
	await _settle(s)                    # the same wait as below, so runtime additions (wilds, lairs) are in both
	var drawn_before := _drawn(s)
	var hidden := 0
	for n in s.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).layers == 0:
			hidden += 1
	check(hidden == 0, "the Void with the switches off: nothing taken out of drawing (%d)" % hidden)
	check(s.get_node_or_null("Batch Watch") == null and s.get_node_or_null("Mesh LODs") == null
		and s.find_child("Detailed Stall", true, false) == null, "...and nothing added")
	var bodies_before := s.find_children("*", "CollisionShape3D", true, false).size()
	var shapes_before := _shapes(s)
	var areas_before := s.find_children("*", "Area3D", true, false).size()

	# --- Everything on (the game's default)
	_switch(true)
	await _load(TOWN)
	s = current_scene
	await _settle(s)
	var batch: Dictionary = detail.last_batch
	print("batch ", batch, "  props ", detail.last_props)
	var drawn_after := _drawn(s)
	check(drawn_after < drawn_before * 0.8, "the Void draws far fewer meshes (%d, was %d)" % [drawn_after, drawn_before])
	check(batch.get("pieces", 0) > 2000, "the Void's still pieces are merged (%d into %d)" % [batch.get("pieces", 0),
		batch.get("meshes", 0)])
	var shapes_after := _shapes(s)
	for k in shapes_before:
		if not shapes_after.has(k):
			print("  shape gone: ", k)
	for k in shapes_after:
		if not shapes_before.has(k):
			print("  shape new: ", k)
	check(s.find_children("*", "CollisionShape3D", true, false).size() == bodies_before,
		"every collision shape is still there (%d, was %d)" % [s.find_children("*", "CollisionShape3D", true, false).size(),
		bodies_before])
	check(s.find_children("*", "Area3D", true, false).size() == areas_before, "every area is still there (%d)" % areas_before)
	# The Gloop Gate's view (under a map landmark) is merged too
	var gate := s.get_node_or_null("Gloop Gate")
	var gate_merged := 0
	if gate:
		for n in gate.find_children("Batched*", "MeshInstance3D", true, false):
			gate_merged += 1
	check(gate_merged > 10, "the Gloop Kingdom's view is merged (%d meshes)" % gate_merged)

	# Distance LODs
	var lw := s.get_node_or_null("Mesh LODs")
	check(lw != null and lw.done > 50, "big meshes get distance LODs (%d)" % (lw.done if lw else 0))
	var with_lods := 0
	var lod_shape_ok := true
	for n in s.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh and mi.mesh.has_meta("lods"):
			with_lods += 1
	check(with_lods > 50, "...and are drawn with them (%d meshes)" % with_lods)
	# Same shape up close: a LOD mesh keeps every triangle of the original at full detail
	if lw:
		var probe: bool = await _lod_probe()
		lod_shape_ok = probe
	check(lod_shape_ok, "a mesh with LODs is the same shape up close")

	# Ferns and grass cast no shadows; the giant leaves still do
	var plants_ok := true
	var leaves_shadow := false
	for f in s.find_children("*", "MultiMeshInstance3D", true, false):
		var g := f as GeometryInstance3D
		if String(g.name) in ["Ferns", "Grass"] and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			plants_ok = false
		if String(g.name) == "Leaves" and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			leaves_shadow = true
	check(plants_ok and leaves_shadow, "ferns and grass cast no shadows, the giant leaves still do")

	# The market stalls
	var props: Dictionary = detail.last_props
	check(props.get("stalls", 0) == 6, "the six market stalls are detailed (%d)" % props.get("stalls", 0))
	check(props.get("signs", 0) >= 30, "the Void's sign posts are detailed (%d)" % props.get("signs", 0))
	check(props.get("fountains", 0) == 2, "both fountains are detailed (%d)" % props.get("fountains", 0))
	check(props.get("lamps", 0) >= 30, "and the lamp posts (%d)" % props.get("lamps", 0))
	var market := s.get_node("Market Square")
	var ball_ok := false
	for c in market.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh and (c as MeshInstance3D).layers != 0 \
				and (c as MeshInstance3D).material_override.resource_name == "Fountain Water":
			ball_ok = true
	check(market.get_node_or_null("Detailed Fountain") != null and ball_ok, "the Market fountain keeps its glowing water ball")
	var lamps_ok := true
	for d in s.find_children("Detailed Lamp *", "Node3D", true, false):
		if d.scale.x < 0.6 or d.scale.x > 1.0:
			lamps_ok = false
	# A bulb is either drawn itself or merged into a "Batched" mesh with the same "Lamp" material, which is what the
	# Void's night lights up, so both count; only one the lamp swap hid would be wrong.
	var bulbs_lit := 0
	for n in s.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh is SphereMesh and m.material_override and m.material_override.resource_name == "Lamp" \
				and (m.layers != 0 or m.has_meta("static_batch")) and not m.has_meta("detail_prop_old"):
			bulbs_lit += 1
	check(lamps_ok and bulbs_lit >= 30, "every lamp post fits its bulb, and the bulbs are still drawn (%d)" % bulbs_lit)
	var signs_ok := true
	for d in s.find_children("Detailed Sign", "", true, false):
		var boards := (d as Node).get_children().filter(func(c: Node) -> bool: return String(c.name).begins_with("Board"))
		var old := (d.get_parent() as Node).find_children("*", "Label3D", false, false)
		if boards.size() != 1 or old.size() != 1:
			signs_ok = false
	check(signs_ok, "each sign keeps one board (its width) and its words")
	var stalls_ok := true
	for kind in ["Fruit", "Sweets", "Crystals", "Flowers", "Records", "Toys"]:
		var st := market.get_node_or_null(kind + " Stall")
		if st == null or st.get_node_or_null("Detailed Stall") == null or st.get_node_or_null("Shop") == null:
			stalls_ok = false
			continue
		var label := false
		for c in st.get_children():
			if c is Label3D and (c as Label3D).text == kind:
				label = true
			if c is MeshInstance3D and String(c.name).begins_with("@") and (c as MeshInstance3D).layers != 0:
				stalls_ok = false
		stalls_ok = stalls_ok and label
	check(stalls_ok, "each stall keeps its shop spot and name, and its old pieces aren't drawn")

	# The Void's batch (18 Nov 2026, tools/build_prop_void.py): crystals, sailboats, dome doors, the car, baskets
	check(props.get("crystals", 0) >= 120, "the crystal shards are detailed (%d)" % props.get("crystals", 0))
	var crystals := s.get_node("Crystals")
	var tints := 0
	var shards := 0
	var shard_ok := true
	for c in crystals.get_children():
		if c is MultiMeshInstance3D:
			tints += 1
			var xfs: Array = c.get_meta("transforms", [])
			shards += xfs.size()
			var m := (c as MultiMeshInstance3D).material_override as StandardMaterial3D
			if m == null or not m.emission_enabled or m.albedo_color.is_equal_approx(Color.WHITE):
				shard_ok = false
	var old_drawn := false
	var solid := 0
	for n in crystals.find_children("*", "", true, false):
		if n is MeshInstance3D and (n as MeshInstance3D).layers != 0:
			old_drawn = true
		if n is CollisionShape3D:
			solid += 1
	check(tints == 4 and shards == props.get("crystals", 0) and shard_ok and not old_drawn and solid >= 40,
		"four tinted, glowing MultiMeshes hold every shard, no old shard drawn, the big ones still solid (%d, %d)" % [tints, solid])
	check(props.get("sailboats", 0) == 5, "the five sailboats are detailed (%d)" % props.get("sailboats", 0))
	var sails := {}
	for d in s.get_node("Sailboats").find_children("*", "MeshInstance3D", true, false):
		if d.has_meta("sail_colour"):
			sails[(d.get_meta("sail_colour") as Color).to_html()] = true
	check(sails.size() == 3, "their sails keep their three colours (%d)" % sails.size())
	check(props.get("doors", 0) >= 10, "every dome building's door is detailed (%d)" % props.get("doors", 0))
	var doors_ok := true
	for d in s.find_children("Detailed Door *", "Node3D", true, false):
		var g := d.get_parent()
		if g.get_node_or_null("Door") == null:
			doors_ok = false
	check(doors_ok, "and each dome keeps its way in")
	var car := s.get_node("Antique Car")
	var glass := false
	for c in car.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).layers != 0:
			glass = glass or (c as MeshInstance3D).material_override.resource_name == "Car Glass"
	check(props.get("car", 0) == 1 and car.get_node_or_null("Detailed Car") != null and glass,
		"the antique car is detailed and keeps its windscreen")
	check(props.get("baskets", 0) == 3, "the three picnic baskets are detailed (%d)" % props.get("baskets", 0))

	# More of the Void (18 Nov 2026, tools/build_prop_void_more.py): the clockyard, Boulder Hollow, the ammo crates
	# and Dash's stall
	check(props.get("clocks", 0) == 7 and props.get("cogs", 0) == 9,
		"the clockyard's 7 clocks and 9 cogs are detailed (%d, %d)" % [props.get("clocks", 0), props.get("cogs", 0)])
	var yard := s.get_node("Goblin Clockyard")
	var clocks_ok := true
	for k in 7:
		var gclock := yard.get_node("Clock %d" % k)
		var case := gclock.get_node_or_null("Detailed Clock Case") as Node3D
		var hood := gclock.get_node_or_null("Detailed Clock Hood") as Node3D
		var hand_drawn := false
		var clock_old := false
		var h := 0.0
		for c in gclock.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			var size := (mi.mesh as BoxMesh).size if mi.mesh is BoxMesh else Vector3.ZERO
			if size.is_equal_approx(Vector3(0.04, 0.22, 0.02)):
				hand_drawn = mi.layers != 0
			elif mi.layers != 0:
				clock_old = true
			if is_equal_approx(size.x, 0.8):
				h = size.y
		var body := gclock.find_children("*", "CollisionShape3D", true, false)
		clocks_ok = clocks_ok and case != null and hood != null and hand_drawn and not clock_old and body.size() == 1 \
			and is_equal_approx(hood.position.y, h - 0.8) and is_equal_approx(case.scale.y, (h - 0.8) / 1.9)
	check(clocks_ok, "each clock's trunk is stretched to fit under its hood, the old pieces aren't drawn, its own hand"
		+ " still turns over the new face, and it's still solid")
	check(props.get("boulders", 0) == 12, "Boulder Hollow's 12 boulders are detailed (%d)" % props.get("boulders", 0))
	var rocks_ok := true
	for b in s.get_node("Boulder Hollow").get_children():
		if not String(b.name).begins_with("Boulder "):
			continue
		var m := b.get_node_or_null("Detailed Boulder") as Node3D
		var shape := (b.get_node("CollisionShape3D") if b.has_node("CollisionShape3D") else
			b.find_children("*", "CollisionShape3D", false, false)[0]) as CollisionShape3D
		var r := (shape.shape as SphereShape3D).radius / 0.85
		rocks_ok = rocks_ok and m != null and is_equal_approx(m.scale.x, r)
	check(rocks_ok, "each boulder is its own size and still solid")
	var crates := 0
	var crates_old := 0
	for c in s.get_tree().get_nodes_in_group("ammo_crates"):
		if c.find_child("Detailed Crate", true, false) != null:
			crates += 1
		for mi in c.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh is BoxMesh:
				crates_old += 1
	check(crates >= 10 and crates_old == 0, "every ammo crate is the detailed one under its bubble wrap (%d)" % crates)
	var gadget := s.get_node("Gadget Stall")
	var stall_old := false
	for c in gadget.get_children() + gadget.get_node("Workbench").get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).layers != 0:
			stall_old = true
	check(props.get("gadget_stall", 0) == 1 and gadget.has_node("Detailed Stall")
		and gadget.has_node("Workbench/Detailed Workbench") and not stall_old
		and gadget.has_node("Gadget Shop Spot") and gadget.has_node("Sign"),
		"Dash's stall and workbench are detailed, and keep their sign, his gadgets and the way to shop")

	# Race and skate landmarks (18 Nov 2026, tools/build_prop_void_gate.py): Tally's board, the race race_gate, the Run Clock
	var rboard := s.get_node("Request Board")
	check(rboard.has_node("Detailed Board") and _old_drawn(rboard) == 0 and rboard.has_node("Request Talk")
		and (rboard.get("text") as Label3D).text != "", "Tally's request board is detailed, and keeps its words, star and talk spot")
	var race_gate := s.get_node("Race Gate void")
	var sarch := race_gate.get_node("Start Arch")
	var towers := 0
	var half := 0.0
	var line_tiles := 0
	for c in sarch.get_children():
		if String(c.name).begins_with("Detailed Tower"):
			towers += 1
			half = absf((c as Node3D).position.x)
		var mi := c as MeshInstance3D
		if mi and mi.layers != 0 and mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.03):
			line_tiles += 1
	var banner := sarch.get_node_or_null("Detailed Banner") as Node3D
	var arch_old := 0
	for c in sarch.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.layers != 0 and not (mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.03)):
			arch_old += 1
	check(towers == 2 and banner != null and is_equal_approx(banner.scale.x, half / 6.2) and arch_old == 0
		and line_tiles == 24 and sarch.find_children("*", "CollisionShape3D", true, false).size() == 2
		and sarch.find_children("*", "Label3D", false, false).size() == 2,
		"the race gate's arch has detailed towers where the old ones stood and its banner stretched between them, and keeps the line on the ground, its name and its solid towers")
	check(race_gate.has_node("Race Board/Detailed Board") and _old_drawn(race_gate.get_node("Race Board")) == 0
		and race_gate.has_node("Tune-Up/Detailed Tune-Up") and _old_drawn(race_gate.get_node("Tune-Up")) == 0
		and race_gate.get_node("Tune-Up").has_node("Tune-Up Spot"), "the race board and Zippy's Tune-Up are detailed, and keep their words and the way to shop")
	var run_clock := s.find_child("Run Clock", true, false)
	check(run_clock != null and run_clock.has_node("Detailed Clock") and _old_drawn(run_clock) == 0
		and run_clock.has_node("Hand") and (run_clock.get_node("Hand").get_child(0) as MeshInstance3D).layers != 0
		and run_clock.has_node("Run Talk"), "the Skate Park's Run Clock is detailed, and its own hand still turns over the new face")

	# The watcher: move one merged piece and its group goes back to being drawn piece by piece
	var watch := s.get_node_or_null("Batch Watch")
	check(watch != null and not watch.groups.is_empty(), "the Void has a Batch Watch (%d groups)" % (watch.groups.size() if watch else 0))
	if watch:
		var gr: Dictionary = {}
		for g in watch.groups:
			if g.live and g.pieces.size() >= 3:
				gr = g
				break
		var piece: MeshInstance3D = gr.pieces[1]
		var made: Array = gr.made.duplicate()
		piece.position += Vector3(0, 0.5, 0)
		await _frames(30)
		var back := true
		for p in gr.pieces:
			if is_instance_valid(p) and (p as MeshInstance3D).layers == 0:
				back = false
		var gone := true
		for m in made:
			if is_instance_valid(m) and not (m as Node).is_queued_for_deletion():
				gone = false
		check(not gr.live and back and gone, "a piece that moves puts its group back (drawn again, merged mesh gone)")
		# and one that's hidden
		var gr2: Dictionary = {}
		for g in watch.groups:
			if g.live and g.pieces.size() >= 3:
				gr2 = g
				break
		(gr2.pieces[0] as MeshInstance3D).visible = false
		await _frames(30)
		check(not gr2.live, "...and so does one that's hidden")
		var before: int = watch.undone
		await _frames(120)
		check(watch.undone == before, "nothing else in the Void moved by itself in 2 s (%d groups put back in all)" % watch.undone)

	# --- Every other kind of place: merged, fewer meshes, nothing errors
	for path in OTHERS:
		_switch(false)
		await _load(path)
		var a := _drawn(current_scene)
		_switch(true)
		await _load(path)
		await _settle(current_scene)
		var b := _drawn(current_scene)
		var w := current_scene.get_node_or_null("Batch Watch")
		check(b < a, "%s draws fewer meshes (%d, was %d; %d groups put back)" % [path.get_file(), b, a, w.undone if w else 0])

	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _old_drawn(holder: Node) -> int:
	# How many plain-shape pieces directly under it are still drawn
	var n := 0
	for c in holder.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).layers != 0:
			n += 1
	return n


func _switch(on: bool) -> void:
	detail.detail_props = on
	detail.batching = on
	detail.lods = on
	detail.occluders = on
	detail.plant_shadows = not on


func _load(path: String) -> void:
	change_scene_to_file(path)
	await _frames(16)


func _settle(s: Node) -> void:
	# The later merging passes (1 and 3 s after loading) and the LODs worked out in the background
	await create_timer(3.5).timeout
	var lw := s.get_node_or_null("Mesh LODs")
	var t := Time.get_ticks_msec()
	while lw and lw.busy() and Time.get_ticks_msec() - t < 90000:
		await process_frame


func _lod_probe() -> bool:
	# A sphere made in code given LODs the game's way: its full-detail surface is the original, triangle for triangle
	var sm := SphereMesh.new()
	sm.radial_segments = 96
	sm.rings = 48
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sm.get_mesh_arrays())
	var holder := Node3D.new()
	current_scene.add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	holder.add_child(mi)
	var lw := current_scene.get_node("Mesh LODs")
	lw.scan(holder)
	var t := Time.get_ticks_msec()
	while lw.busy() and Time.get_ticks_msec() - t < 30000:
		await process_frame
	var out := mi.mesh as ArrayMesh
	var ok := out != am and out.has_meta("lods") and out.get_surface_count() == 1 \
		and out.surface_get_array_index_len(0) == am.surface_get_array_index_len(0) \
		and out.get_aabb().is_equal_approx(am.get_aabb())
	holder.queue_free()
	return ok


func _shapes(s: Node) -> Dictionary:
	# Each collision shape by where it is (names made at load time can differ between loads)
	var out := {}
	for c in s.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		var k := "%s %s" % [cs.get_parent().name if not String(cs.get_parent().name).begins_with("@") else "@",
			cs.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
		out[k] = out.get(k, 0) + 1
	return out


func _drawn(s: Node) -> int:
	var n := 0
	for c in s.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.is_visible_in_tree() and g.layers != 0:
			n += 1
	return n


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0 if failures == 0 else 1)
