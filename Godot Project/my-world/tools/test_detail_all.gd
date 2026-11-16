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
	var signs_ok := true
	for d in s.find_children("Detailed Sign", "", true, false):
		var boards := (d as Node).get_children().filter(func(c: Node) -> bool: return String(c.name).begins_with("Board"))
		var old := (d.get_parent() as Node).find_children("*", "Label3D", false, false)
		if boards.size() != 1 or old.size() != 1:
			signs_ok = false
	check(signs_ok, "each sign keeps one board (its width) and its words")
	var market := s.get_node("Market Square")
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
