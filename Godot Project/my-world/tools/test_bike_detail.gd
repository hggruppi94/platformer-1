extends SceneTree

# Checks the bike's baked look (25 Nov 2026, scripts/detail_props.gd dress_bike, called by dress_ride and dress_void):
# the hero's BMX, Hover Bike and Rocket Bike and Dash's parked bike wear brushed metal on the frame, rims and black
# parts, the seat the pebbly skin and the tyres the tread, wrapped round each wheel on their own UVs (the tyres spin,
# so a pattern laid on from outside would slide over them). The bike stays skinned and animated, the tread meets
# itself where it joins round each wheel, doing it again changes nothing, and with detail off nothing changes.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_bike_detail.gd
#
# Only builds bikes in an empty scene: no save or setting is touched.

const DP := preload("res://scripts/detail_props.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _bikes(n: Node) -> Array:
	var out := []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if DP.is_bike(mi):
			out.append(mi)
	return out


func _kinds(mi: MeshInstance3D) -> Dictionary:
	var out := {}
	for s in mi.mesh.get_surface_count():
		var m := mi.get_surface_override_material(s) as StandardMaterial3D
		var old := mi.mesh.surface_get_material(s)
		if m and m.has_meta(DP.SURFACE_META):
			out[old.resource_name] = m
	return out


func _check_bike(mi: MeshInstance3D, what: String) -> void:
	var k := _kinds(mi)
	check(k.size() == DP.BIKE_PATCH.size(), "%s: %d of its %d parts are patched %s" % [what, k.size(), DP.BIKE_PATCH.size(), k.keys()])
	var maps := true
	for n in k:
		var m: StandardMaterial3D = k[n]
		maps = maps and m.albedo_texture != null and m.normal_texture != null
		maps = maps and str(m.get_meta(DP.SURFACE_META)) == str(DP.BIKE_PATCH[n][0])
	check(maps, "%s: each wears its own patch with its maps" % what)
	var tyre: StandardMaterial3D = k.get(DP.BIKE_TYRE)
	check(tyre != null and not tyre.uv1_triplanar, "%s: the tyres read their own UVs, not laid on from outside" % what)
	check(k.has("Frame") and (k["Frame"] as StandardMaterial3D).uv1_triplanar, "%s: the frame's metal is laid on in its own space" % what)
	check(mi.skin != null and not mi.skeleton.is_empty(), "%s: still skinned to its bones" % what)
	check(DP.dress_bike(mi) == 0, "%s: dressing it again changes nothing" % what)


func _run() -> void:
	var wd: Node = root.get_node_or_null("WorldDetail")
	check(wd != null and DP.on(), "the detail pipeline is on")
	var meshes := {}
	for kit in ["bmx", "hover_bike", "rocket_bike"]:
		var ride := Node3D.new()
		root.add_child(ride)
		RideKit.build(kit, ride, Node3D.new())
		var bikes := _bikes(ride)
		check(bikes.size() >= 1, "%s: has the bike in it (%d)" % [kit, bikes.size()])
		for mi in bikes:
			_check_bike(mi, kit)
			meshes[mi.mesh] = true
	check(meshes.size() == 1, "every bike shares one wrapped mesh (%d)" % meshes.size())
	# The tyres' UVs: across the tyre and round it, a whole number of tread patches round each wheel
	var mesh: Mesh = meshes.keys()[0] if meshes.size() > 0 else null
	var tyre_ok := false
	if mesh:
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			if mat == null or mat.resource_name != DP.BIKE_TYRE:
				continue
			var a := mesh.surface_get_arrays(s)
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var lo := INF
			var hi := -INF
			for p in uv:
				lo = minf(lo, p.y)
				hi = maxf(hi, p.y)
			# No triangle spans more than a quarter of a turn in V (the seam is stitched)
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var worst := 0.0
			for t in range(0, idx.size(), 3):
				var vs := [uv[idx[t]].y, uv[idx[t + 1]].y, uv[idx[t + 2]].y]
				worst = maxf(worst, vs.max() - vs.min())
			print("      tyre: %d points, V from %.2f to %.2f, widest triangle %.3f" % [v.size(), lo, hi, worst])
			tyre_ok = uv.size() == v.size() and hi - lo > 0.5 and worst < (hi - lo) * 0.25
	check(tyre_ok, "the tread wraps round the wheels with no smeared seam")
	# The bike still animates: its AnimationPlayer plays and moves the wheels' bones
	var glb := (load(DP.BIKE_GLB) as PackedScene).instantiate()
	root.add_child(glb)
	DP.dress_bike(glb)
	var ap := glb.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sk := glb.find_child("*", true, false) as Node
	for n in glb.find_children("*", "Skeleton3D", true, false):
		sk = n
	check(ap != null and ap.get_animation_list().size() > 0 and sk is Skeleton3D, "the dressed bike keeps its skeleton and animations %s" % (ap.get_animation_list() if ap else []))
	for mi in _bikes(glb):
		check(mi.get_node_or_null(mi.skeleton) == sk, "its mesh still follows the skeleton")
	# Dash's bike parked in town (scenes/town/characters.tscn), dressed by dress_void
	var chars := (load("res://scenes/town/characters.tscn") as PackedScene).instantiate()
	root.add_child(chars)
	var dash_bike := chars.get_node_or_null("Bike")
	check(dash_bike != null, "Dash's bike is in town")
	if dash_bike:
		check(DP.dress_bike(dash_bike) >= 1, "Dash's bike gets dressed")
		for mi in _bikes(dash_bike):
			_check_bike(mi, "Dash's bike")
	# Detail off: a bike is left as built
	if wd:
		wd.set("detail_props", false)
		var ride := Node3D.new()
		root.add_child(ride)
		RideKit.build("bmx", ride, Node3D.new())
		var plain := true
		for mi in _bikes(ride):
			plain = plain and not mi.has_meta("bike_dressed") and _kinds(mi).is_empty()
		check(plain, "with detail off the bike keeps its plain look")
		wd.set("detail_props", true)
	print("\nRESULT %s (%d failed)" % ["FAILED" if failures else "PASSED", failures])
	quit(1 if failures else 0)
