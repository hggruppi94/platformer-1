extends SceneTree

# Checks the portal worlds' baked props (19 Nov 2026, Hayden: "Then keep baking details"): scripts/detail_props.gd
# (and dress_tide_reef, dress_dark_hollow and the other worlds' dress_*) swaps the plain builder pieces for the models from tools/build_prop_glenmoor.py (and the worlds after it), keeping
# every solid box and name, and dressing a place twice changes nothing.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_detail_portal_props.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.portal_props_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.portal_props_test_backup.cfg"
const GLENMOOR := "res://scenes/portal_worlds/glenmoor.tscn"
const TIDE_REEF := "res://scenes/portal_worlds/tide_reef.tscn"
const DARK_HOLLOW := "res://scenes/portal_worlds/dark_hollow.tscn"
const LANTERNMOOR := "res://scenes/portal_worlds/lanternmoor.tscn"
const FROZEN_MOMENT := "res://scenes/portal_worlds/frozen_moment.tscn"
const FAR_FUTURE := "res://scenes/portal_worlds/far_future.tscn"
const ROOTMIND := "res://scenes/portal_worlds/rootmind.tscn"
const SHARD_ISLE := "res://scenes/portal_worlds/shard_isle.tscn"
const GLOOP_KINGDOM := "res://scenes/bosses/gloop_kingdom.tscn"
const STAR_ARENA := "res://scenes/bosses/arena.tscn"
const CLOCK_TOWER := "res://scenes/bosses/clock_tower.tscn"
const BOULDER_CANYON := "res://scenes/bosses/boulder_canyon.tscn"
const SKYREACH := "res://scenes/bosses/skyreach_trail.tscn"
const DUSK := "res://scenes/scary_world/scary_world.tscn"
const SECRET_GARDEN := "res://scenes/secret_garden/secret_garden.tscn"
const DETAIL_PROPS := preload("res://scripts/detail_props.gd")

var failures := 0
var detail: Node


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
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	root.get_node("Clock").set("pulls_home", false)
	detail = root.get_node("WorldDetail")
	if "secret" in OS.get_cmdline_user_args():
		# (only the Secret Garden: -- secret)
		await _secret_garden()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "arena" in OS.get_cmdline_user_args():
		# (only the Star Arena: -- arena)
		await _star_arena()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "race" in OS.get_cmdline_user_args():
		# (only the race circuits: -- race)
		await _race_circuits()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "dusk" in OS.get_cmdline_user_args():
		# (only Dusk's Embrace: -- dusk)
		await _dusks_embrace()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "skyreach" in OS.get_cmdline_user_args():
		# (only the Skyreach Trail: -- skyreach)
		await _skyreach()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "canyon" in OS.get_cmdline_user_args():
		# (only Boulder Canyon: -- canyon)
		await _boulder_canyon()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "tower" in OS.get_cmdline_user_args():
		# (only the Clockwork Tower: -- tower)
		await _clock_tower()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return
	if "gloop" in OS.get_cmdline_user_args():
		# (only the Gloop Kingdom: -- gloop)
		await _gloop_kingdom()
		print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
		_finish()
		return

	# As built: the solid boxes to compare with
	detail.detail_props = false
	await _load(GLENMOOR)
	var shapes_before := _shapes(current_scene)
	var ring := current_scene.find_child("Standing Stones", true, false) as Node3D
	var heights := {}
	for c in ring.get_children():
		if c is MeshInstance3D and String(c.name).begins_with("Stone") and (c as MeshInstance3D).mesh is BoxMesh:
			heights[String(c.name)] = ((c as MeshInstance3D).mesh as BoxMesh).size.y

	detail.detail_props = true
	await _load(GLENMOOR)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Glenmoor props: ", got)
	check(got.get("stones", 0) == heights.size() and heights.size() >= 9, "every Standing Stone swapped (%d)" % heights.size())
	check(got.get("cairns", 0) == 6, "six cairns up Ben Bonnie swapped")
	check(got.get("croft", 0) == 1 and got.get("barn", 0) == 1, "Heather's croft and barn swapped")
	check(got.get("hay", 0) == 5, "the barn's five hay bales swapped")

	ring = s.find_child("Standing Stones", true, false) as Node3D
	var stones_ok := true
	var old_drawn := 0
	for c in ring.get_children():
		# (the worn grass disc in the middle stays as it is)
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh and (c as MeshInstance3D).layers != 0:
			old_drawn += 1
		if String(c.name).begins_with("Detailed Stone"):
			var aabb := _aabb(c as Node3D)
			if aabb.size.y < 1.0:
				stones_ok = false
	check(old_drawn == 0, "no plain standing stone or moss box drawn")
	# Each detailed stone stands as tall as the box it replaced
	for n: String in heights:
		var box := ring.get_node(n) as MeshInstance3D
		var top := box.transform * Vector3(0, heights[n] * 0.5, 0)
		var best := INF
		for c in ring.get_children():
			if String(c.name).begins_with("Detailed Stone"):
				var d := (c as Node3D).position.distance_to(box.position)
				best = minf(best, d)
		if best > 0.01:
			stones_ok = false
		if top.y < 1.0:
			stones_ok = false
	check(stones_ok, "each detailed stone sits where its box was, at its height")

	var summit := 0
	for g in s.find_children("Detailed Cairn", "Node3D", true, false):
		var p := g.get_parent()
		var balls := 0
		for c in p.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
				balls += 1
			if c is MeshInstance3D and c.name != "Detailed Cairn" and (c as MeshInstance3D).layers != 0:
				old_drawn += 1
		if balls > 4:
			summit += 1
	check(summit == 1, "the summit cairn is the big one")
	var croft := s.find_child("Heather's Croft", true, false)
	var barn := s.find_child("Barn", true, false)
	var plain := 0
	for g in [croft, barn]:
		for c in g.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).layers != 0:
				plain += 1
	check(plain == 0, "nothing plain left drawn on the croft and barn")
	check(_aabb(croft.get_node("Detailed Croft")).size.x > 7.0, "the croft model is house sized")
	check(_aabb(barn.get_node("Detailed Barn")).size.y > 7.0, "the barn model is barn sized")
	var hay_ok := true
	for c in barn.get_children():
		if String(c.name).begins_with("Hay Bale") and not c.has_node("Detailed Hay"):
			hay_ok = false
	check(hay_ok, "every hay bale keeps its name and holds its detailed bale")

	check(_shapes(s) == shapes_before, "every collision shape is where it was")
	var again := DETAIL_PROPS.dress_glenmoor(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing it again changes nothing")

	await _tide_reef()
	await _dark_hollow()
	await _lanternmoor()
	await _frozen_moment()
	await _far_future()
	await _rootmind()
	await _shard_isle()
	await _gloop_kingdom()
	await _secret_garden()
	await _star_arena()
	await _clock_tower()
	await _boulder_canyon()
	await _skyreach()
	await _dusks_embrace()
	await _race_circuits()
	print("RESULT " + ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	_finish()


func _tide_reef() -> void:
	await _load(TIDE_REEF)
	var s := current_scene
	# The corals' detailed copies still fade and bloom with the tide (they used to stay as they were dressed)
	var coral: MeshInstance3D
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).material_override as StandardMaterial3D
		if m and m.resource_name.begins_with("Coral ") and m.has_meta("detail_surface") and c.is_visible_in_tree():
			coral = c
			break
	check(coral != null, "the reef's corals wear their detailed copies")
	var got: Dictionary = detail.last_props
	print("Tide Reef props: ", got)
	check(got.get("houses", 0) == 10, "all ten coral houses swapped")
	check(got.get("lamps", 0) >= 10, "the bubble lamps' posts swapped (%d)" % got.get("lamps", 0))
	check(got.get("boat", 0) == 1, "the stranded boat swapped")
	var plain := 0
	var kept_bits := true
	for i in 10:
		var h := s.get_node("Coral House %d" % (i + 1))
		var bits := 0
		for c in h.get_children():
			if not (c is MeshInstance3D):
				continue
			# (the coral bits may be merged into one batch, but they're never put away as old props)
			if String((c as MeshInstance3D).material_override.resource_name).begins_with("Coral"):
				if not c.has_meta("detail_prop_old"):
					bits += 1
			elif not c.has_meta("detail_prop_old"):
				plain += 1
		if bits < 10:
			kept_bits = false
	check(plain == 0, "nothing plain left drawn on a coral house")
	check(kept_bits, "every house keeps its coral bumps and chimney")
	for b in s.get_node("Bubble Lamps").get_children():
		if b is MeshInstance3D and (b as MeshInstance3D).mesh is CylinderMesh and (b as MeshInstance3D).layers != 0:
			plain += 1
	check(plain == 0, "no plain lamp post drawn")
	var lit := 0
	for b in s.get_node("Bubble Lamps").get_children():
		if b is MeshInstance3D and (b as MeshInstance3D).mesh is SphereMesh and (b as MeshInstance3D).layers != 0:
			lit += 1
	check(lit >= 10, "every bubble still glows on its post")
	# A detailed dome is tinted its own house's coral, and blooms with the tide
	var dome := (s.get_node("Coral House 1/Detailed Dome") as Node3D).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var dm := dome.get_surface_override_material(0) as StandardMaterial3D
	s.set_tide(0.0)
	var d_dry := dm.albedo_color
	s.set_tide(1.0)
	var d_wet := dm.albedo_color
	check(not d_dry.is_equal_approx(d_wet) and d_wet.r > d_wet.b, "a detailed dome blooms in its coral pink (%s -> %s)" % [d_dry, d_wet])
	s.set_tide(0.0)
	var again := DETAIL_PROPS.dress_tide_reef(s)
	check(again.houses == 0 and again.lamps == 0 and again.boat == 0, "dressing the reef again changes nothing")
	if coral:
		s.set_tide(0.0)
		var dry := (coral.material_override as StandardMaterial3D).albedo_color
		s.set_tide(1.0)
		var wet := (coral.material_override as StandardMaterial3D).albedo_color
		check(not dry.is_equal_approx(wet), "a detailed coral blooms when the tide comes in (%s -> %s)" % [dry, wet])
		s.set_tide(0.0)


func _dark_hollow() -> void:
	detail.detail_props = false
	await _load(DARK_HOLLOW)
	var shapes_before := _shapes(current_scene, true)
	detail.detail_props = true
	await _load(DARK_HOLLOW)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Dark Hollow props: ", got)
	check(got.get("trees", 0) >= 60, "every crooked tree swapped (%d)" % got.get("trees", 0))
	check(got.get("log", 0) == 1, "the Hollow Log swapped")
	check(got.get("mushrooms", 0) >= 25, "the glowing mushroom clusters swapped (%d)" % got.get("mushrooms", 0))
	check(got.get("lamps", 0) >= 8, "the Hollow Run's lamp posts swapped (%d)" % got.get("lamps", 0))
	check(got.get("stones", 0) >= 20, "the old leaning stones swapped (%d)" % got.get("stones", 0))
	# Nothing plain left drawn: no bark, stalk or cap, lamp post or tall old stone that isn't put away
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or not mi.is_visible_in_tree() or mi.get_parent().name.begins_with("Detailed"):
			continue
		var m := mi.get_active_material(0)
		var mn := String(m.resource_name) if m else ""
		if mn in ["Crooked Bark", "Mushroom Stalk", "Lamp Post", "Log Bark", "Log Inside"]:
			plain += 1
		elif mn == "Old Stone" and mi.mesh is BoxMesh:
			var b := (mi.mesh as BoxMesh).size
			if b.y > maxf(b.x, b.z):
				plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# The flames on the run's posts still glow, at the top of their baked posts
	var flames := 0
	for c in s.get_node("Run Lamps").get_children():
		if c is MeshInstance3D and String((c as MeshInstance3D).get_active_material(0).resource_name) == "Lamp Flame" \
				and not c.has_meta("detail_prop_old") and not String(c.name).begins_with("Batched"):
			flames += 1
	check(flames == got.get("lamps", -1), "every lamp keeps its flame (%d)" % flames)
	# A mushroom cluster glows in its old colour
	var cl := s.get_node("Glow Mushrooms/Detailed Mushrooms 1") as Node3D
	var caps: MeshInstance3D
	for c in cl.find_children("Caps*", "MeshInstance3D", true, false):
		caps = c
	var cm := caps.get_surface_override_material(0) as StandardMaterial3D if caps else null
	check(cm != null and cm.emission_enabled and cm.emission.g > 0.4, "a mushroom cluster glows in its colour")
	# The moon lamps round Hush Hill wear the baked post, lit and unlit, and keep their globes
	var lamps := s.find_children("Detailed Post", "Node3D", true, false)
	check(lamps.size() >= 4, "the moon lamps wear the baked post (%d)" % lamps.size())
	# (only the still ones: the ghosts bob and the centipede's talk spot follows her)
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_dark_hollow(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the hollow again changes nothing")


func _lanternmoor() -> void:
	detail.detail_props = false
	await _load(LANTERNMOOR)
	var shapes_before := _shapes(current_scene, true)
	var plain_posts := current_scene.find_children("Detailed Post", "Node3D", true, false).size()
	detail.detail_props = true
	await _load(LANTERNMOOR)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Lanternmoor props: ", got)
	check(plain_posts == 0, "no baked posts with detailed props off")
	check(got.get("trees", 0) >= 28, "every lantern tree swapped (%d)" % got.get("trees", 0))
	check(got.get("stones", 0) == 6, "the beacon's ring of standing stones swapped (%d)" % got.get("stones", 0))
	# Nothing plain left drawn: no small tree's bark, leaves or pods, no standing stone
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or not mi.is_visible_in_tree() or String(mi.name).begins_with("Batched"):
			continue
		var grove := String(mi.get_parent().get_parent().name) if mi.get_parent().get_parent() else ""
		if not grove in ["Lantern Grove", "Lantern Trees"] and _mat_of(mi) != "Standing Stone":
			continue
		if _mat_of(mi) in ["Bark", "Lantern Leaves", "Pod Glow", "Pod Pink", "Pod Blue", "Standing Stone"]:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# Each tree is sized to its old trunk and its pods glow in the old colours
	var t := s.find_children("Detailed Tree", "Node3D", true, false)
	var sized := true
	for d: Node3D in t:
		var trunk: MeshInstance3D = null
		for c in d.get_parent().get_children():
			if trunk == null and c is MeshInstance3D and _mat_of(c) == "Bark":
				trunk = c  # the first bark piece is the trunk; the branches come after it
		if trunk == null or absf(d.scale.y - (trunk.mesh as CylinderMesh).height / 3.2) > 0.01:
			sized = false
	check(sized and t.size() == got.get("trees", -1), "every tree is sized to its own trunk")
	var pod: MeshInstance3D
	for c in t[0].find_children("PodA*", "MeshInstance3D", true, false):
		pod = c
	var pm := pod.get_surface_override_material(0) as StandardMaterial3D if pod else null
	check(pm != null and pm.emission_enabled and pm.emission.r > 0.4, "a tree's lantern pod glows in its colour")
	# The Night Path's lanterns and the beacons wear their baked posts and keep their shades and flames
	var posts := s.find_children("Detailed Post", "Node3D", true, false)
	check(posts.size() >= 5, "the Night Path's lanterns wear the baked post (%d)" % posts.size())
	var shades := true
	for p: Node in posts:
		var shade := p.get_parent().get_node_or_null("Shade") as MeshInstance3D
		if shade == null or not shade.visible:
			shades = false
	check(shades, "every lantern keeps its paper shade")
	var beacons := s.find_children("Detailed Beacon", "Node3D", true, false)
	check(beacons.size() >= 3, "the three beacons are baked (%d)" % beacons.size())
	var flames := true
	for b: Node in beacons:
		var f := b.get_parent().get_node_or_null("Flame") as MeshInstance3D
		if f == null or not f.visible:
			flames = false
	check(flames, "every beacon keeps its flame")
	var shapes_after := _shapes(s, true)
	# (the runaway lights' "Hit" targets flit about the grove, so only the still shapes count)
	for d: Dictionary in [shapes_before, shapes_after]:
		for k in d.keys():
			if String(k).begins_with("Hit "):
				d.erase(k)
	if shapes_after != shapes_before:
		for k in shapes_before:
			if shapes_after.get(k, 0) != shapes_before[k]:
				print("  before only: ", k)
		for k in shapes_after:
			if shapes_before.get(k, 0) != shapes_after[k]:
				print("  after only: ", k)
	check(shapes_after == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_lanternmoor(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the moor again changes nothing")


func _frozen_moment() -> void:
	detail.detail_props = false
	await _load(FROZEN_MOMENT)
	var shapes_before := _shapes(current_scene, true)
	var plain_pines := current_scene.find_children("Detailed Pine*", "Node3D", true, false).size()
	detail.detail_props = true
	await _load(FROZEN_MOMENT)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Frozen Moment props: ", got)
	check(plain_pines == 0, "no baked pines with detailed props off")
	check(got.get("pines", 0) == 26, "every snowy pine swapped (%d)" % got.get("pines", 0))
	check(got.get("crags", 0) == 30, "every ice crag swapped (%d)" % got.get("crags", 0))
	check(got.get("throne", 0) == 1, "the Frost Throne swapped")
	# Nothing plain left drawn under the pines, the crags or the throne
	var plain := 0
	for g in ["Pines", "Ice Crags", "Frost Throne"]:
		var n := s.find_child(g, true, false)
		for c in n.get_children():
			if c is MeshInstance3D and not c.has_meta("detail_prop_old") and (c as MeshInstance3D).is_visible_in_tree() \
					and not String(c.name).begins_with("Batched"):
				plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# Each pine stands on the ground at its own size (from its trunk), each crag as tall and wide as its old cone
	var sized := true
	for d: Node3D in s.find_child("Pines", true, false).find_children("Detailed Pine*", "Node3D", false, false):
		if absf(d.position.y) > 0.01 or d.scale.x < 0.75 or d.scale.x > 1.35:
			sized = false
	check(sized, "every pine stands on the ground at its own size")
	var crags_ok := true
	var cones := []
	for c in s.find_child("Ice Crags", true, false).get_children():
		if c is MeshInstance3D and c.has_meta("detail_prop_old") and (c as MeshInstance3D).mesh is CylinderMesh \
				and _mat_of(c) == "Crag Ice":
			cones.append(c)
	var crags := s.find_child("Ice Crags", true, false).find_children("Detailed Crag*", "Node3D", false, false)
	for i in crags.size():
		var c: MeshInstance3D = cones[i]
		var b := _aabb(crags[i])
		var h := (c.mesh as CylinderMesh).height
		if absf(b.size.y * crags[i].scale.y - h) > h * 0.06 or absf(crags[i].position.y) > 0.1:
			crags_ok = false
	check(crags.size() == cones.size() and crags_ok, "every crag stands where its cone did, just as tall")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_frozen_moment(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the Frozen Moment again changes nothing")


func _far_future() -> void:
	detail.detail_props = false
	await _load(FAR_FUTURE)
	var shapes_before := _shapes(current_scene, true)
	var plain_clock := current_scene.find_children("Detailed Clock", "Node3D", true, false).size()
	detail.detail_props = true
	await _load(FAR_FUTURE)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Far Future props: ", got)
	check(plain_clock == 0, "no baked clock with detailed props off")
	check(got.get("clock", 0) == 1, "the Tomorrow Clock's dais and spire swapped")
	check(got.get("posts", 0) == 6, "every streetlight post swapped (%d)" % got.get("posts", 0))
	check(got.get("fountain", 0) == 1, "the plaza's fountain swapped")
	check(got.get("benches", 0) == 4, "every plaza bench swapped (%d)" % got.get("benches", 0))
	# Nothing plain left drawn, and the city's neon (which fades with it) is all still there
	var plain := 0
	var neon := 0
	var neon_hidden := 0
	for g in ["Tomorrow Clock", "Streetlights", "Fading Plaza"]:
		for c in s.find_child(g, true, false).get_children():
			if not (c is MeshInstance3D):
				continue
			var mn := _mat_of(c)
			if mn in ["Dais", "Spire", "Post", "Fountain", "Bench"] and (c as MeshInstance3D).is_visible_in_tree() \
					and (c as MeshInstance3D).layers != 0:
				plain += 1
			if mn.begins_with("Neon"):
				neon += 1
				if c.has_meta("detail_prop_old") or not (c as MeshInstance3D).is_visible_in_tree():
					neon_hidden += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	check(neon > 0 and neon_hidden == 0, "the clock's and lights' neon is all still drawn (%d)" % neon)
	# Each post stands on the ground right under its bulb
	var posts_ok := true
	var lights := s.find_child("Streetlights", true, false)
	for d: Node3D in lights.find_children("Detailed Post*", "Node3D", false, false):
		var near := false
		for c in lights.get_children():
			if c is MeshInstance3D and _mat_of(c) == "Post" and Vector2(c.position.x - d.position.x, c.position.z - d.position.z).length() < 0.01:
				near = true
		if not near or absf(d.position.y) > 0.01:
			posts_ok = false
	check(posts_ok, "every post stands where its old post did")
	# The towers' glass wears the glass patch
	var glass := 0
	var patched := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var m := (c as MeshInstance3D).get_active_material(0)
		if m and String(m.resource_name).begins_with("Tower Glass"):
			glass += 1
			if m.get_meta("detail_surface", "") == "glass_facade":
				patched += 1
	check(glass > 0 and patched == glass, "every tower's glass has the glass patch (%d of %d)" % [patched, glass])
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_far_future(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the Far Future again changes nothing")


func _rootmind() -> void:
	detail.detail_props = false
	await _load(ROOTMIND)
	var shapes_before := _shapes(current_scene, true)
	var plain_stem := current_scene.find_children("Detailed Stem*", "Node3D", true, false).size()
	detail.detail_props = true
	await _load(ROOTMIND)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Rootmind props: ", got)
	check(plain_stem == 0, "no baked stem with detailed props off")
	check(got.get("stems", 0) == 37, "every giant stem swapped: 26 round the edge, the Leaf Climb's, 10 flowers' (%d)" % got.get("stems", 0))
	check(got.get("leaves", 0) == 26, "every edge leaf swapped (%d)" % got.get("leaves", 0))
	check(got.get("step_leaves", 0) == 9, "every step leaf on the Leaf Climb swapped (%d)" % got.get("step_leaves", 0))
	check(got.get("buds", 0) == 10 and got.get("blooms", 0) == 10, "every giant flower's bud and bloom swapped")
	check(got.get("arches", 0) == 6, "every root arch in the tunnel swapped (%d)" % got.get("arches", 0))
	# Nothing plain left drawn (a stalk to a step leaf is a thin stem and stays)
	var plain := 0
	for g in ["Giant Stems", "Leaf Climb", "Giant Buds", "Root Tunnel"]:
		for c in s.find_child(g, true, false).find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.has_meta("detail_prop_old") or _in_model(mi):
				continue
			var mn := _mat_of(mi)
			var thick := mi.mesh is CylinderMesh and (mi.mesh as CylinderMesh).bottom_radius > 0.3
			if (mn in ["Giant Leaf", "Step Leaf"] or (mi.mesh is SphereMesh and mi.get_parent().name == "Giant Stems") or mn.begins_with("Petal") or mi.mesh is TorusMesh or (mn == "Giant Stem" and thick)) \
					and mi.mesh is PrimitiveMesh:
				plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# Each stem stands on its old cylinder's foot, as tall as it was
	var stems_ok := true
	for d: Node3D in s.find_children("Detailed Stem*", "Node3D", true, false):
		var box := _aabb(d)
		if absf(d.position.y) > 0.05 or box.size.y < 19.0 or box.size.y > 22.5:
			stems_ok = false
	check(stems_ok, "every stem stands on the ground at its old height")
	# The buds and blooms go with the flower's own Bud and Open, so mending still opens them
	var f := s.find_child("Giant Buds", true, false).get_child(0) as Node3D
	var bud_m := f.get_node("Bud/Detailed Bud") as Node3D
	var bloom_m := f.get_node("Open/Detailed Bloom") as Node3D
	check(bud_m.is_visible_in_tree() and not bloom_m.is_visible_in_tree(), "a shut flower shows its baked bud")
	(f.get_node("Bud") as Node3D).visible = false
	(f.get_node("Open") as Node3D).visible = true
	check(not bud_m.is_visible_in_tree() and bloom_m.is_visible_in_tree(), "an open flower shows its baked bloom")
	(f.get_node("Bud") as Node3D).visible = true
	(f.get_node("Open") as Node3D).visible = false
	var heart_ok := false
	for c in f.get_node("Open").get_children():
		if c is MeshInstance3D and _mat_of(c) == "Flower Heart" and not c.has_meta("detail_prop_old"):
			heart_ok = true
	check(heart_ok, "the flower's glowing heart is kept")
	var tinted := false
	for mi: MeshInstance3D in bud_m.find_children("*", "MeshInstance3D", true, false):
		var m := mi.get_active_material(0) as StandardMaterial3D
		if m and m.albedo_color != Color.WHITE:
			tinted = true
	check(tinted, "a bud wears its own petal colour")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_rootmind(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the Rootmind again changes nothing")


func _shard_isle() -> void:
	detail.detail_props = false
	await _load(SHARD_ISLE)
	var shapes_before := _shapes(current_scene, true)
	var plain_rock := current_scene.find_children("Detailed Island Rock", "Node3D", true, false).size()
	var plain_plinth := current_scene.find_children("Detailed Plinth", "Node3D", true, false).size()
	detail.detail_props = true
	await _load(SHARD_ISLE)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Shard Isle props: ", got)
	check(plain_rock == 0 and plain_plinth == 0, "no baked rock or plinth with detailed props off")
	check(got.get("islands", 0) == 10, "the main island's, the three islets' and the six warp islands' rock swapped (%d)"
		% got.get("islands", 0))
	check(got.get("far", 0) == 16, "every far-off rock in the sky swapped (%d)" % got.get("far", 0))
	check(got.get("stones", 0) == 9, "every stepping stone swapped (%d)" % got.get("stones", 0))
	check(got.get("mounds", 0) >= 6, "a mound under every crystal cluster (%d)" % got.get("mounds", 0))
	check(got.get("crystals", 0) >= 80, "every crystal swapped (%d)" % got.get("crystals", 0))
	# The crystals are two MultiMeshes (glowing green and pale), one place for each crystal
	var places := 0
	var glows := true
	for mmi: MultiMeshInstance3D in s.get_node("Detailed Crystals").get_children():
		places += (mmi.get_meta("transforms") as Array).size()
		var m := mmi.material_override as StandardMaterial3D
		if m == null or not m.emission_enabled:
			glows = false
	check(places == got.get("crystals", 0) and s.get_node("Detailed Crystals").get_child_count() == 2,
		"the crystals are two MultiMeshes with a place each (%d)" % places)
	check(glows, "the baked crystals glow")
	# Nothing plain left drawn: rock, stones and crystals (the Jitter's moving shards stay)
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree() or not (mi.mesh is PrimitiveMesh):
			continue
		var mn := _mat_of(mi)
		if (mn in ["Shard Rock", "Stepping Crystal"] or mn in ["Shard Glow", "Pale Crystal"]) \
				and not s.get_node("Jitter").is_ancestor_of(mi):
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	var jitter := 0
	for c in s.get_node("Jitter").get_children():
		if c is MeshInstance3D and not c.has_meta("detail_prop_old"):
			jitter += 1
	check(jitter == 10, "the out-of-tune shards still move about as they were (%d)" % jitter)
	# Each island's rock hangs under its moss, as wide as the island
	var rocks_ok := true
	var warp_r := {}
	for id: String in s.get_node("Warps").ISLANDS:
		warp_r[s.get_node("Warps").ISLANDS[id].get("at")] = float(s.get_node("Warps").ISLANDS[id].get("r", 14.0))
	for d: Node3D in s.find_children("Detailed Island Rock", "Node3D", true, false):
		var box := _aabb(d)
		var r := 14.0 if d.get_parent().name == "Main Island" else 5.0
		if str(d.get_parent().name).begins_with("Islet Warp"):
			r = float(warp_r.get((d.get_parent() as Node3D).position, 5.0))   # (the Warp Rings' islands, scripts/shard_warps.gd)
		if absf(d.position.y + 0.6) > 0.01 or box.end.y > 0.05 or absf(box.size.x * d.scale.x - 2.0 * r) > 0.25 * r:
			rocks_ok = false
	check(rocks_ok, "every island's rock hangs under its moss, as wide as the island")
	# The hanging crystals moved down onto the rounder rock: each one's foot is in the rock, not under or over it
	var hang_ok := true
	var island := s.get_node("Main Island") as Node3D
	for c in island.get_children():
		if c is MeshInstance3D and c.has_meta("detail_drop"):
			var h := ((c as MeshInstance3D).mesh as CylinderMesh).height
			var foot: float = c.position.y + h * 0.5 + float(c.get_meta("detail_drop"))
			var d := Vector2(c.position.x, c.position.z).length() / 14.0
			var under := -0.6 + DETAIL_PROPS._rock_under(d) * 7.0
			if foot < under or foot > under + 0.2:
				hang_ok = false
	check(hang_ok, "the crystals under the main island hang from its new rock")
	# The Heart Stone and the Echo Crystals' stands are baked where they're made
	check(s.find_children("Detailed Plinth", "Node3D", true, false).size() == 1, "the Heart Stone's plinth is baked")
	check(s.find_children("Detailed Stand", "Node3D", true, false).size() == 3, "the three Echo Crystals' stands are baked")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_shard_isle(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing Shard Isle again changes nothing")


func _gloop_kingdom() -> void:
	detail.detail_props = false
	await _load(GLOOP_KINGDOM)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Kingdom") == null, "nothing baked in the kingdom with detailed props off")
	detail.detail_props = true
	await _load(GLOOP_KINGDOM)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Gloop Kingdom props: ", got)
	check(got.get("towers", 0) == 2 and got.get("arches", 0) == 1, "the Palace Gate's two towers and its arch swapped")
	check(got.get("walls", 0) == 25, "every piece of the court's wall swapped (%d)" % got.get("walls", 0))
	check(got.get("stands", 0) == 10, "all ten courtiers' stands swapped (%d)" % got.get("stands", 0))
	check(got.get("dais", 0) == 1 and got.get("throne", 0) == 1, "the throne and its dais swapped")
	check(got.get("posts", 0) == 12, "every lantern post on the Bog Road swapped (%d)" % got.get("posts", 0))
	check(got.get("spires", 0) == 40, "every rock spire round the edge swapped (%d)" % got.get("spires", 0))
	check(got.get("chest", 0) == 2, "the Royal Treasure's chest and lid swapped")
	# Nothing plain left drawn of what was swapped (the goo, crowns, bulbs and banners stay)
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree():
			continue
		var mn := _mat_of(mi)
		var par := String(mi.get_parent().name)
		if mn == "Palace Stone" and par in ["Palace Gate", "Royal Court"]:
			plain += 1
		elif mn == "Goo Rock" or (par == "Bog Road" and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.y == 3.0):
			plain += 1
		elif par == "Throne" and mi.mesh is BoxMesh and mn == "Royal Gold" and String(mi.name).begins_with("Throne"):
			plain += 1
		elif par in ["Royal Treasure", "Lid"]:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# The MultiMeshes have a place each, each where its old piece was
	var dk := s.get_node("Detailed Kingdom")
	var places := 0
	for mmi: MultiMeshInstance3D in dk.get_children():
		places += (mmi.get_meta("transforms") as Array).size()
	check(places == 25 + 10 + 12 + 40, "the walls, stands, posts and spires are MultiMeshes with a place each (%d)" % places)
	var near := true
	for mmi: MultiMeshInstance3D in dk.get_children():
		for t: Transform3D in mmi.get_meta("transforms"):
			var found := false
			for c in s.find_children("*", "MeshInstance3D", true, false):
				if c.has_meta("detail_prop_old") and (c as MeshInstance3D).global_position.distance_to(t.origin) < 0.01:
					found = true
					break
			if not found:
				near = false
	check(near, "each copy stands where its old piece stood")
	# The lid's model is in the Lid, so it still swings open
	var lid := s.find_child("Lid", true, false) as Node3D
	check(lid != null and lid.get_node_or_null("Detailed Chest Lid") != null, "the baked lid is in the lid that opens")
	check(s.find_child("Detailed Gate Arch", true, false) != null, "the gate's arch is baked")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_gloop_kingdom(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the kingdom again changes nothing")


func _secret_garden() -> void:
	detail.detail_props = false
	await _load(SECRET_GARDEN)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Garden") == null, "nothing baked in the garden with detailed props off")
	detail.detail_props = true
	await _load(SECRET_GARDEN)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Secret Garden props: ", got)
	check(got.get("walls", 0) == 5, "all five of the garden's walls are baked lengths of ivy-covered brick (%d)" % got.get("walls", 0))
	check(got.get("arches", 0) == 9, "the Rose Walk's arches swapped (%d)" % got.get("arches", 0))
	check(got.get("fountain", 0) == 1 and got.get("sundial", 0) == 1 and got.get("summerhouse", 0) == 1,
		"the fountain, sundial and summerhouse swapped")
	check(got.get("hedges", 0) >= 40, "the maze's hedges swapped (%d)" % got.get("hedges", 0))
	check(got.get("flowers", 0) == 9, "all nine Giant Flowers swapped (%d)" % got.get("flowers", 0))
	check(got.get("tree", 0) == 1, "the Great Tree swapped")
	check(got.get("benches", 0) >= 3, "the benches swapped (%d)" % got.get("benches", 0))
	check(got.get("leaf_balls", 0) > 50, "the leafy balls are baked leaf balls (%d)" % got.get("leaf_balls", 0))
	# Nothing plain left drawn of what was swapped
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree():
			continue
		var mn := _mat_of(mi)
		var nm := DETAIL_PROPS._base_name(mi)
		var par := String(mi.get_parent().name)
		var was_swapped := false
		if mi.mesh is SphereMesh and mn in ["Hedge", "Old Leaves", "Great Leaves", "Garden Leaf", "Ivy", "Ivy Light"]:
			was_swapped = true                   # (leafy balls, ivy)
		elif nm in ["South Wall", "North Wall", "Side Wall", "Coping", "Outer Tree", "Arch Post", "Hedge", "Bench",
				"Alcove Bench", "Sundial", "Sundial Face", "Summerhouse Post", "Stem", "Flower Face", "Flower Middle",
				"Fountain Basin", "Fountain Column", "Fountain Bowl"]:
			was_swapped = true
		elif par == "Great Tree" and mn == "Old Bark":
			was_swapped = true
		if was_swapped:
			plain += 1
			if plain < 12:
				print("  still plain: ", mi.get_path(), " ", mn)
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# Each MultiMesh copy stands on a piece it replaced
	var dg := s.get_node("Detailed Garden")
	var places := 0
	for mmi: MultiMeshInstance3D in dg.get_children():
		places += (mmi.get_meta("transforms") as Array).size()
	check(places > 100, "the walls, arches, hedges, benches and leaves are MultiMeshes with a place each (%d)" % places)
	# The flowers keep glowing brighter when the garden wakes: their baked heads' materials are in its list
	var glows: Array = s.get("_glows")
	var heads := 0
	for f in s.find_children("Giant Flower *", "Node3D", true, false):
		var h := f.get_node_or_null("Detailed Head") as Node3D
		if h == null:
			continue
		for m in h.find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).get_active_material(0)
			if mat != null and mat in glows:
				heads += 1
				break
	check(heads == 9, "each flower's baked head glows with the garden (%d)" % heads)
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_secret_garden(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the garden again changes nothing")


func _star_arena() -> void:
	detail.detail_props = false
	await _load(STAR_ARENA)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Arena") == null, "nothing baked in the arena with detailed props off")
	detail.detail_props = true
	await _load(STAR_ARENA)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Star Arena props: ", got)
	check(got.get("walls", 0) == 61, "every length of the low wall swapped (%d)" % got.get("walls", 0))
	check(got.get("steps", 0) == 278, "a baked step on every block of the stands (%d)" % got.get("steps", 0))
	check(got.get("fans", 0) == (s.get_node("Crowd").get_child_count()), "the whole crowd up on the seats (%d)" % got.get("fans", 0))
	check(got.get("towers", 0) == 4, "all four spotlight towers swapped")
	check(got.get("hatches", 0) == 6, "all six hatches swapped")
	check(got.get("tunnel", 0) == 1 and got.get("podium", 0) == 1 and got.get("board", 0) == 1,
		"the tunnel, Blip's podium and the Round Board swapped")
	# Nothing plain left drawn of what was swapped (the hatches' glow, beams, banners and words stay)
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree():
			continue
		var n := String(mi.name)
		if n == "Stands" or n.begins_with("Wall ") or n.begins_with("Trim ") or n in ["Tower", "Lamp", "Hatch Rim",
				"Tunnel Wall", "Tunnel Roof", "Podium", "Board Leg", "Board"]:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	var steps := s.get_node("Detailed Arena/Detailed Stand Steps") as MultiMeshInstance3D
	var tops := {}
	for t: Transform3D in steps.get_meta("transforms"):
		tops[snappedf(t.origin.y, 0.01)] = true
	check(tops.size() == 4, "the steps sit at the stands' four tier heights (%s)" % str(tops.keys()))
	var near := true
	for t: Transform3D in (s.get_node("Detailed Arena/Detailed Wall") as MultiMeshInstance3D).get_meta("transforms"):
		var found := false
		for c in s.get_node("Wall").get_children():
			if c.has_meta("detail_prop_old") and (c as Node3D).global_position.distance_to(t.origin) < 0.01:
				found = true
				break
		near = near and found
	check(near, "each wall length stands where its old box stood")
	check(s.get_node("Round Board").find_child("Board Text", true, false) != null, "the board's words are still there")
	var glow := s.find_child("Hatch Glow", true, false) as MeshInstance3D
	check(glow != null and glow.is_visible_in_tree() and not glow.has_meta("detail_prop_old"), "the hatches still glow")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_star_arena(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the arena again changes nothing")


func _clock_tower() -> void:
	detail.detail_props = false
	await _load(CLOCK_TOWER)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Tower") == null, "nothing baked in the tower with detailed props off")
	detail.detail_props = true
	await _load(CLOCK_TOWER)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Clockwork Tower props: ", got)
	var gears := 0
	for g in s.find_children("*", "Node3D", true, false):
		if g.has_node("Disc") and g.has_node("Hub"):
			gears += 1
	check(gears > 20 and got.get("gears", 0) == gears, "every gear swapped (%d of %d)" % [got.get("gears", 0), gears])
	check(got.get("walls", 0) == 20, "both gear walls in baked lengths (%d)" % got.get("walls", 0))
	check(got.get("frames", 0) == 3 and got.get("pendulums", 0) == 3, "all three pendulums and their frames swapped")
	check(got.get("gate", 0) == 1 and got.get("clock", 0) == 1 and got.get("dais", 0) == 1 and got.get("cuckoo", 0) == 1,
		"the Cog Gate, the Big Clock, Tock's dais and the Cuckoo Chest swapped")
	check(got.get("bays", 0) == 10, "the round wall in ten bays (%d)" % got.get("bays", 0))
	check(got.get("posts", 0) == 35, "every rail post swapped (%d)" % got.get("posts", 0))
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree() or "/Visual/" in str(mi.get_path()):
			continue                                     # (the goblins and Tock have arms and cogs of their own)
		if String(mi.name) in ["Disc", "Tooth", "Hub", "Gear Wall", "Pendulum Post", "Pendulum Beam", "Arm", "Bob",
				"Gate Tower", "Gate Beam", "Tower Wall", "Rail Post", "Big Face", "Big Rim", "Big Mark", "Dais", "Dais Top",
				"House", "Roof", "Little Face"]:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# What the game moves stays the game's: the hands, the bobs' glow, the chest's door and bird
	var hands := 0
	for h in s.get_node("Clock Floor/Big Clock").get_children():
		var hand := h.get_node_or_null("Hand") as MeshInstance3D
		if hand and hand.is_visible_in_tree() and not hand.has_meta("detail_prop_old"):
			hands += 1
	check(hands == 2, "the Big Clock's two hands are still drawn (%d)" % hands)
	var glow := s.find_child("Bob Glow", true, false) as MeshInstance3D
	check(glow != null and glow.is_visible_in_tree(), "the bobs still glow")
	check(s.get_node("Cuckoo Chest/Lid/Door").is_visible_in_tree(), "the Cuckoo Chest's door is still there")
	var pend := s.find_child("Detailed Pendulum", true, false) as Node3D
	check(pend != null and pend.get_parent().has_node("Bob Glow"), "each baked pendulum swings with its pivot")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_clock_tower(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the tower again changes nothing")


func _boulder_canyon() -> void:
	detail.detail_props = false
	await _load(BOULDER_CANYON)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Canyon") == null, "nothing baked in the canyon with detailed props off")
	detail.detail_props = true
	await _load(BOULDER_CANYON)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Boulder Canyon props: ", got)
	check(got.get("walls", 0) == 24, "all 24 stretches of the run's walls baked (%d)" % got.get("walls", 0))
	check(got.get("rim", 0) == 26, "all 26 rim rocks round the pit baked (%d)" % got.get("rim", 0))
	check(got.get("rocks", 0) >= 7 + 8 + 15, "every boulder baked (%d)" % got.get("rocks", 0))
	check(got.get("pillars", 0) == 4, "the four pillars baked")
	check(got.get("slab", 0) == 1 and got.get("throne", 0) == 1 and got.get("geode", 0) == 1,
		"the arch's slab, the Rock Throne and the Big Geode baked")
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree() or "/Visual/" in str(mi.get_path()):
			continue
		if DETAIL_PROPS._base_name(mi) in ["Rock Band", "Rim Rock", "Rock Heap", "Arch Boulder", "Pit Boulder", "Way Rock", "Pillar",
				"Arch Slab", "Rock Throne", "Throne Back"]:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	# The walls stand where the solid walls are, as tall
	var mmi := s.get_node("Detailed Canyon/Detailed Canyon Walls") as MultiMeshInstance3D
	var xfs: Array = mmi.get_meta("transforms")
	var tall_ok := true
	for t in xfs.slice(0, 24):
		var tr := t as Transform3D
		var h := tr.basis.get_scale().y * DETAIL_PROPS.BC_WALL_H
		if h < 12.9 or h > 20.1 or absf(absf(tr.origin.x) - 10.6) > 0.7:
			tall_ok = false
	check(tall_ok, "each wall stretch stands where its solid wall is, as tall")
	check(s.get_node_or_null("Big Geode/Lid/Detailed Lid") != null, "the geode's baked lid is inside its Lid, so it still opens")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	# Rocks made in play get the baked boulder too
	var c: Node = s
	c.call("drop_rock", Vector3(0, 0, 74))
	var coming := s.find_child("Rock Coming", true, false) as Node3D
	check(coming != null and coming.find_child("Detailed Rock", true, false) != null, "a falling rock is a baked boulder")
	c.call("_roll_one")
	var rb := s.find_child("Rolling Boulder", true, false) as Node3D
	check(rb != null and rb.get_node_or_null("Detailed Ball") != null, "a rolling boulder is a baked boulder")
	var again := DETAIL_PROPS.dress_boulder_canyon(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the canyon again changes nothing")


func _skyreach() -> void:
	detail.detail_props = false
	await _load(SKYREACH)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Skyreach") == null, "nothing baked on the trail with detailed props off")
	detail.detail_props = true
	await _load(SKYREACH)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Skyreach props: ", got)
	check(got.get("kerbs", 0) > 100, "the kerb stones are baked blocks (%d)" % got.get("kerbs", 0))
	check(got.get("ring_rocks", 0) >= 15, "the summit's ring of rocks baked (%d)" % got.get("ring_rocks", 0))
	check(got.get("waystones", 0) == 5, "all five Waystones baked (%d)" % got.get("waystones", 0))
	check(got.get("pines", 0) >= 25, "the pines round the foot baked (%d)" % got.get("pines", 0))
	check(got.get("crystals", 0) == 30, "all 30 cliff crystals baked (%d)" % got.get("crystals", 0))
	check(got.get("flags", 0) == 63, "all 63 prayer flags baked (%d)" % got.get("flags", 0))
	check(got.get("chest", 0) == 1 and got.get("blooms", 0) == 14, "the Star Chest and the 14 Star Blooms baked")
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree() or "/Visual/" in str(mi.get_path()):
			continue
		var m := DETAIL_PROPS._mat_name(mi)
		# (the prayer flags' poles are the pines' bark too, and stay)
		if m in ["Ring Stone", "Pine", "Cliff Crystal", "Star Bloom", "Waystone", "Chest Stone"] or m.begins_with("Flag ") \
				or m == "Pine Trunk" and mi.get_parent() == s:
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	var kerbs := s.get_node("Kerb Stones") as MultiMeshInstance3D
	check(kerbs.multimesh.mesh is ArrayMesh, "the kerbs' MultiMesh draws the baked block")
	# A Waystone's lamp still lights (the trail swaps its material), inside its cage
	var w := s.get_node("Waystone 2") as Node3D
	check(w.get_node_or_null("Detailed Waystone") != null and w.get_node("Lamp").is_visible_in_tree(),
		"a Waystone keeps its lamp beside its baked pillar")
	s.call("_light", 1, false)
	check((w.get_node("Lamp") as MeshInstance3D).material_override.resource_name == "Waystone Lit", "the lamp still lights")
	check(s.get_node_or_null("Star Chest/Lid/Crystal Lid") != null and s.get_node("Star Chest/Lid/Crystal Lid").is_visible_in_tree(),
		"the chest keeps its crystal lid")
	# Each pine stands where its old trunk was
	var pm := s.get_node("Detailed Skyreach/Detailed Pines") as MultiMeshInstance3D
	var ground_ok := true
	for t in pm.get_meta("transforms"):
		var tr := t as Transform3D
		var h := tr.basis.get_scale().y * DETAIL_PROPS.SKY_PINE_H
		if h < 6.0 or h > 10.5:
			ground_ok = false
	check(ground_ok, "each pine as tall as its old one")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var patched := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var am := mi.get_active_material(0)
		if am and am.has_meta(DETAIL_PROPS.SURFACE_META) and String(am.resource_name) == "Trail Path":
			patched += 1
	check(patched == 1, "the path has the stone patch (%d)" % patched)
	var rock := s.get_node("Mountain Rock") as MeshInstance3D
	check(rock.get_active_material(0) is ShaderMaterial, "the mountain's rock has the ground look")
	var again := DETAIL_PROPS.dress_skyreach(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing the trail again changes nothing")


func _dusks_embrace() -> void:
	detail.detail_props = false
	await _load(DUSK)
	var shapes_before := _shapes(current_scene, true)
	check(current_scene.get_node_or_null("Detailed Dusk") == null, "nothing baked in Dusk's Embrace with detailed props off")
	detail.detail_props = true
	await _load(DUSK)
	var s := current_scene
	var got: Dictionary = detail.last_props
	print("Dusk's Embrace props: ", got)
	# (the Poison Mire's way in, scripts/swamp.gd _open_gap, takes the few trees in its way out first)
	var left := s.get_node("Twisted Trees").get_child_count()
	check(got.get("trees", 0) == left and left >= 70, "every twisted tree baked (%d of %d)" % [got.get("trees", 0), left])
	check(got.get("mushrooms", 0) >= 15, "the glowing mushrooms baked (%d)" % got.get("mushrooms", 0))
	check(got.get("log", 0) == 1 and got.get("gate", 0) == 1, "the hollow log and the gate home baked")
	check(got.get("stones", 0) >= 15, "the stepping stones baked (%d)" % got.get("stones", 0))
	var plain := 0
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		# (the Poison Mire's log bridges, scripts/swamp.gd, are its own and stay)
		if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree() or "/Swamp/" in str(mi.get_path()):
			continue
		var m := DETAIL_PROPS._mat_name(mi)
		if m in ["Old Bark", "Stalk", "Path Stone", "Log Wood", "Log Inside", "Log Moss", "Old Wall Stone", "Gate Iron"] \
				or m.begins_with("Glow Cap"):
			plain += 1
	check(plain == 0, "nothing plain left drawn (%d)" % plain)
	var drawn := 0
	for n in ["Wisp 1", "Eyes 1"]:
		var w := s.get_node_or_null("Glow/" + n) as Node3D
		if w and w.is_visible_in_tree() and (w.get_child(0) as MeshInstance3D).layers != 0:
			drawn += 1
	check(drawn == 2, "the wisps and the eyes in the dark are still drawn")
	var home := false
	for c in s.get_node("Gate Home").get_children():
		if c is MeshInstance3D and DETAIL_PROPS._mat_name(c) == "Home Glow" and (c as MeshInstance3D).layers != 0:
			home = true
	check(home and s.get_node_or_null("Gate Home/ExitToTown") != null, "the way home still glows and still goes home")
	var tall := true
	for t in s.get_node("Twisted Trees").get_children():
		var m := t.get_node_or_null("Detailed Tree") as Node3D
		if m and (m.scale.y * DETAIL_PROPS.DH_TREE_H < 4.5 or m.scale.y * DETAIL_PROPS.DH_TREE_H > 11.5):
			tall = false
	check(tall, "each tree as tall as its old trunk")
	check(_shapes(s, true) == shapes_before, "every solid shape is where it was")
	var again := DETAIL_PROPS.dress_dusks_embrace(s)
	var none := true
	for k in again:
		if again[k] != 0:
			none = false
	check(none, "dressing it again changes nothing")


func _race_circuits() -> void:
	# Every circuit's grandstand and scenery (detail_props.gd dress_race_circuit)
	var plain_mats := ["Bark", "Stalk", "Crystal", "Mushroom Stalk", "Mushroom Cap", "Glow Stalk", "Night Bark",
		"Lamp Pole", "Hay", "Barn", "Barn Roof", "Barn Door", "Silo", "Silo Cap", "Mill", "Sail", "Pillar",
		"Observatory", "Dome", "Telescope", "Stand", "Stand Roof"]
	var want := {"lake_loop": ["orb_trees", "crystals"], "meadow_wiggle": ["orb_trees", "crystals", "mushrooms"],
		"observatory_hill": ["orb_trees", "crystals", "observatory"], "hollow_run": ["crooked", "glow_mushrooms",
		"lamps", "pillar"], "pumpkin_run": ["trees", "hay", "pumpkins", "barn", "silo", "windmill"]}
	for id in want:
		var path := "res://scenes/races/%s.tscn" % id
		detail.detail_props = false
		await _load(path)
		var shapes_before := _shapes(current_scene)
		check(current_scene.get_node_or_null("Detailed Race") == null, "%s: nothing baked with detailed props off" % id)
		detail.detail_props = true
		await _load(path)
		var s := current_scene
		var got: Dictionary = detail.last_props
		print(id, " props: ", got)
		check(got.get("stand", 0) == 1, "%s: the grandstand baked" % id)
		for k: String in want[id]:
			check(got.get(k, 0) > 0, "%s: %s baked (%d)" % [id, k, got.get(k, 0)])
		var plain := 0
		for c in s.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			if mi.has_meta("detail_prop_old") or _in_model(mi) or not mi.is_visible_in_tree():
				continue
			if "/Life/" in str(mi.get_path()):
				continue
			var m := DETAIL_PROPS._mat_name(mi)
			if m in plain_mats or m.begins_with("Leaves ") or m.begins_with("Orb #") or m.begins_with("Orb ") \
					or m.begins_with("Glow Cap"):
				plain += 1
		check(plain == 0, "%s: nothing plain left drawn (%d)" % [id, plain])
		var fans := 0
		for c in s.get_node("Stand").get_children():
			if not (c is MeshInstance3D) and not String(c.name).begins_with("Detailed"):
				fans += 1
		check(fans >= 12, "%s: the cheering crowd is still in the stand (%d)" % [id, fans])
		if id == "pumpkin_run":
			var sails := s.get_meta("sails") as Node3D
			var before := sails.rotation.z
			for i in 10:
				await process_frame
			check(sails.has_node("Detailed Sails") and not is_equal_approx(sails.rotation.z, before),
				"the windmill's baked sails turn")
		if id == "hollow_run":
			var face := s.get_meta("moon_clock") as Node3D
			check(face.is_visible_in_tree() and face.has_node("Minute Hand") and face.has_node("Hour Hand"),
				"the Moon Clock's face and hands are the game's")
			var glow := 0
			for p in s.get_node("Lamp Posts").get_children():
				for c in p.get_children():
					if c is MeshInstance3D and DETAIL_PROPS._mat_name(c) == "Lamp Glow" and (c as MeshInstance3D).layers != 0:
						glow += 1
			check(glow == got.get("lamps", -1), "every lamp's bulb still glows (%d)" % glow)
		check(_shapes(s) == shapes_before, "%s: every collision shape is where it was" % id)
		var again := DETAIL_PROPS.dress_race_circuit(s)
		var none := true
		for k in again:
			if again[k] != 0:
				none = false
		check(none, "%s: dressing it again changes nothing" % id)


func _in_model(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if String(p.name).begins_with("Detailed"):
			return true
		p = p.get_parent()
	return false


func _mat_of(mi: MeshInstance3D) -> String:
	var m := mi.get_active_material(0)
	return String(m.resource_name) if m else ""


func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var t := n.global_transform.affine_inverse() * mi.global_transform
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if n is MeshInstance3D:
		box = (n as MeshInstance3D).get_aabb() if first else box
	return box


func _shapes(s: Node, still_only := false) -> Dictionary:
	var out := {}
	for c in s.find_children("*", "CollisionShape3D", true, false):
		var cs := c as CollisionShape3D
		if still_only and not (cs.get_parent() is StaticBody3D):
			continue
		var k := "%s %s" % [cs.get_parent().name if not String(cs.get_parent().name).begins_with("@") else "@",
			cs.global_position.snapped(Vector3(0.1, 0.1, 0.1))]
		out[k] = out.get(k, 0) + 1
	return out


func _load(path: String) -> void:
	change_scene_to_file(path)
	for i in 16:
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
