extends SceneTree

# Checks the rides' baked look (25 Nov 2026, tools/build_prop_surfaces.py maple|grip_tape|brushed_metal|tread|leaf_skin
# and scripts/detail_props.gd dress_ride, called by RideKit.build): every ride's deck, grip, metal, tyres, leaf and
# boots wear their patch with its maps, the glows, flames and see-through bits stay plain, two skateboards share their
# patched materials, building again gives the same look, and with detail off nothing changes.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_ride_detail.gd
#
# Only builds rides in an empty scene: no save or setting is touched.

const DP := preload("res://scripts/detail_props.gd")

# What each kit should have patched, at least
const WANT := {
	"board": {"maple": 3, "grip_tape": 1, "brushed_metal": 2},
	"sk8": {"maple": 3, "grip_tape": 1, "brushed_metal": 2},
	"rocket_board": {"maple": 3, "grip_tape": 1, "brushed_metal": 6},
	"skates": {"goblin_skin": 2},
	"paw_skates": {"goblin_skin": 4},
	"scooter": {"grip_tape": 3, "brushed_metal": 2},
	"leaf": {"leaf_skin": 3},
	"segway": {"brushed_metal": 4, "tread": 2},
	"overboard": {"brushed_metal": 1},
	"saucer": {"brushed_metal": 1},
	"hover": {},
}

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _mat(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi.material_override:
		return mi.material_override as StandardMaterial3D
	return mi.get_surface_override_material(0) as StandardMaterial3D


func _kind(mi: MeshInstance3D) -> String:
	var m := _mat(mi)
	return str(m.get_meta(DP.SURFACE_META, "")) if m else ""


func _build(kit: String) -> Node3D:
	var ride := Node3D.new()
	root.add_child(ride)
	var model := Node3D.new()
	root.add_child(model)
	RideKit.build(kit, ride, model)
	return ride


func _meshes(ride: Node) -> Array:
	return ride.find_children("*", "MeshInstance3D", true, false)


func _counts(ride: Node) -> Dictionary:
	var out := {}
	for mi in _meshes(ride):
		var k := _kind(mi)
		if k != "":
			out[k] = int(out.get(k, 0)) + 1
	return out


func _glows_plain(ride: Node) -> bool:
	for mi in _meshes(ride):
		var m := _mat(mi)
		if m and (m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED) and _kind(mi) != "":
			return false
	return true


func _has_maps(ride: Node) -> bool:
	for mi in _meshes(ride):
		if _kind(mi) == "":
			continue
		var m := _mat(mi)
		if m.albedo_texture == null or m.normal_texture == null or not m.uv1_triplanar:
			return false
	return true


func _run() -> void:
	var wd: Node = root.get_node_or_null("WorldDetail")
	check(wd != null and DP.on(), "the detail pipeline is on")
	for kit in WANT:
		var ride := _build(kit)
		var got := _counts(ride)
		var ok := true
		for k in WANT[kit]:
			if int(got.get(k, 0)) < int(WANT[kit][k]):
				ok = false
		check(ok, "%s: its parts wear their patches %s (want %s)" % [kit, got, WANT[kit]])
		check(_has_maps(ride), "%s: every patched part has its baked maps" % kit)
		check(_glows_plain(ride), "%s: glows, flames and see-through bits stay plain" % kit)
		check(DP.dress_ride(ride) == 0, "%s: dressing it again changes nothing" % kit)
	# The leaf's midrib is moved to the middle of the leaf
	var leaf := _build("leaf")
	var lm: StandardMaterial3D = null
	for mi in _meshes(leaf):
		if DP.ride_part(mi) == "leaf":
			lm = _mat(mi)
	check(lm != null and is_equal_approx(lm.uv1_offset.x, 0.5), "the leaf's veins run down its middle")
	# Two boards share their patched materials (the skateboard scene's materials are shared), so they draw together
	var a := _build("board")
	var b := _build("board")
	var deck_a := a.find_child("Deck", true, false) as MeshInstance3D
	var deck_b := b.find_child("Deck", true, false) as MeshInstance3D
	check(deck_a and deck_b and _mat(deck_a) == _mat(deck_b) and _kind(deck_a) == "maple",
		"two skateboards share their maple deck")
	# Bruno's black deck keeps its own colour under the grain
	var sk := _build("sk8")
	var sd := _mat(sk.find_child("Deck", true, false) as MeshInstance3D)
	check(sd != null and _kind(sk.find_child("Deck", true, false)) == "maple" and sd.albedo_color.r < 0.2,
		"the SK8 Deck is still black under its grain")
	# Rebuilding a ride (as stepping on again does) gives the same patched look
	RideKit.build("segway", a, Node3D.new())
	check(int(_counts(a).get("tread", 0)) >= 2, "a ride built again over another still gets its patches")
	# Detail off: a ride is left as built
	if wd:
		wd.set("detail_props", false)
		var plain := true
		for kit in WANT:
			if not _counts(_build(kit)).is_empty():
				plain = false
		check(plain, "with detail off every ride keeps its plain look")
		wd.set("detail_props", true)
	print("\nRESULT %s (%d failed)" % ["FAILED" if failures else "PASSED", failures])
	quit(1 if failures else 0)
