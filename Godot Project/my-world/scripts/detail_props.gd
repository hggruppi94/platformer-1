extends RefCounted

# Detailed props on Stars Hollow's town green (15 Nov 2026, the detailed props pipeline; Hayden: "after seeing the
# detail on that lamp, now I feel like you've been holding back on game assets"). The builder's street lamps (a pole
# and a glowing box), park benches (four boxes) and the gazebo (cylinders and boxes) are swapped at load time for
# models made the big-game way: a very detailed version in Blender baked onto a light one (tools/bake_kit.py,
# tools/build_prop_lamp.py, build_prop_bench.py, build_prop_gazebo.py). Godot makes lighter copies of each for
# further away when it imports them (Generate LODs), and every lamp and bench shares one mesh and one material.
#
# Only how they look changes. The old pieces stay in the tree (taken out of drawing: render layers 0, meta
# "detail_prop_old"), so their collision, names, lights, the gazebo's bulbs, label and pumpkins, rays and tests all
# work as before. WorldDetail calls dress_earth() before it batches the scene (scripts/static_batch.gd), which skips
# anything with a meta.

const WATCH := preload("res://scripts/batch_watch.gd")
const LAMP := "res://models/props/street_lamp.glb"
const BENCH := "res://models/props/park_bench.glb"
const GAZEBO := "res://models/props/gazebo.glb"
const STALL := "res://models/props/market_stall_%s.glb"
const STALLS := ["Fruit", "Sweets", "Crystals", "Flowers", "Records", "Toys"]
const PUMPKIN := "res://models/props/pumpkin.glb"
const JACK := "res://models/props/jack_o_lantern.glb"
const SCARECROW := "res://models/props/scarecrow.glb"
const MAILBOX := "res://models/props/mailbox.glb"
const SIGN := "res://models/props/sign_post.glb"
const PICKET := "res://models/props/picket.glb"
const FENCE_POST := "res://models/props/fence_post.glb"
const PORCH := "res://models/props/porch.glb"
const PORCH_ROOF := "res://models/props/porch_roof.glb"
const FOUNTAIN := "res://models/props/void_fountain.glb"
const VOID_LAMP := "res://models/props/void_lamp.glb"
const HAY := "res://models/props/hay_bale.glb"
const CORN := "res://models/props/corn_sheaf.glb"
const FIRE_TRUCK := "res://models/props/fire_truck.glb"
const BOAT := "res://models/props/rowing_boat.glb"
const SLIDE := "res://models/props/slide_tower.glb"
const SWINGS := "res://models/props/swing_set.glb"
const SANDBOX := "res://models/props/sandbox.glb"
const PLANTER := "res://models/props/mum_planter.glb"
const PICKET_GAP := 0.35               # the model's picket spacing, and the builder's (_picket_fence)
const FOUNTAINS := ["Market Square", "TownSquare"]
const LAMP_BULB := 3.5                 # how high the model's bulb is (tools/build_prop_fountain.py void_lamp)
# The Void's lamp posts: the post's material, its height and where its parent's name starts (tools/build_town.gd)
const VOID_LAMPS := [["Lamp Post", 3.4, "Market Square"], ["Castle Lamp Post", 3.2, "Castle Grounds"],
	["Boardwalk Post", 2.2, "Boardwalk"], ["Boardwalk Post", 2.2, "Dock"]]
const OLD_META := "detail_prop_old"
const GAZEBO_MATS := ["Gazebo White", "Gazebo Roof"]
const POLE_H := 3.6                    # the builder's lamp pole (_lamp_post): a 3.6 m cylinder, centre 1.8 m up
const BENCH_SEAT := Vector3(1.8, 0.1, 0.5)


static func dress_earth(scene: Node) -> Dictionary:
	var out := {"lamps": 0, "benches": 0, "gazebo": 0, "pumpkins": 0, "jacks": 0, "scarecrows": 0, "mailboxes": 0,
		"fences": 0, "porches": 0, "hay": 0, "corn": 0, "truck": 0, "boat": 0,
		"playground": 0, "planters": 0}
	var lamp := _scene(LAMP)
	var bench := _scene(BENCH)
	var gazebo := _scene(GAZEBO)
	var lamps := scene.get_node_or_null("Street Lamps")
	if lamp and lamps:
		out.lamps = _lamps(lamps, lamp)
	if bench:
		out.benches = _benches(scene, bench)
	var gz := scene.get_node_or_null("Gazebo") as Node3D
	if gazebo and gz:
		out.gazebo = _gazebo(gz, gazebo)
	# (16 Nov 2026, "give everything the baked in details": tools/build_prop_autumn.py)
	var pumpkin := _scene(PUMPKIN)
	var jack := _scene(JACK)
	if pumpkin and jack:
		var n := _pumpkins(scene, pumpkin, jack)
		out.pumpkins = n.x
		out.jacks = n.y
	var scarecrow := _scene(SCARECROW)
	if scarecrow:
		out.scarecrows = _scarecrows(scene, scarecrow)
	var mailbox := _scene(MAILBOX)
	if mailbox:
		out.mailboxes = _mailboxes(scene, mailbox)
	# (16 Nov 2026, batch three: tools/build_prop_house.py)
	var picket := _scene(PICKET)
	var post := _scene(FENCE_POST)
	if picket and post:
		out.fences = _fences(scene, _mesh_of(picket), _mesh_of(post))
	var porch := _scene(PORCH)
	var roof := _scene(PORCH_ROOF)
	if porch and roof:
		out.porches = _porches(scene, porch, roof)
	# (16 Nov 2026, batch four: tools/build_prop_farm.py)
	var hay := _scene(HAY)
	if hay:
		out.hay = _hay(scene, hay)
	var corn := _scene(CORN)
	if corn:
		out.corn = _corn(scene, corn)
	var truck := _scene(FIRE_TRUCK)
	if truck:
		out.truck = _swap_node(scene, "Fire Truck", truck, "Detailed Fire Truck")
	var boat := _scene(BOAT)
	if boat:
		# The detailed boat floats a little higher than the old red hull did, so its paint shows above the pond.
		out.boat = _swap_node(scene, "Rowing Boat", boat, "Detailed Boat", 0.15)
	# (16 Nov 2026, batch five: tools/build_prop_play.py)
	out.playground = _playground(scene)
	var planter := _scene(PLANTER)
	if planter:
		out.planters = _planters(scene, planter)
	return out


static func dress_void(scene: Node) -> Dictionary:
	# The Void's Market Square (16 Nov 2026, the whole game gets the treatment): its six stalls, each with its own
	# goods (tools/build_prop_stall.py). The stall's collision, shop spot and name over it are the builder's.
	var out := {"stalls": 0, "signs": 0, "fountains": 0, "lamps": 0}
	var sign := _scene(SIGN)
	if sign:
		out.signs = _signs(scene, sign)
	# (16 Nov 2026, batch three: tools/build_prop_fountain.py)
	var fountain := _scene(FOUNTAIN)
	if fountain:
		out.fountains = _fountains(scene, fountain)
	var lamp := _scene(VOID_LAMP)
	if lamp:
		out.lamps = _void_lamps(scene, lamp)
	var market := scene.get_node_or_null("Market Square")
	if market == null:
		return out
	for kind in STALLS:
		var stall := market.get_node_or_null(kind + " Stall") as Node3D
		var model := _scene(STALL % kind.to_lower())
		if stall == null or model == null or stall.get_script() != null:
			continue
		for c in stall.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("@"):
				_hide(c)
		var m := model.instantiate() as Node3D
		m.name = "Detailed Stall"
		stall.add_child(m)
		out.stalls += 1
	return out


static func _scene(path: String) -> PackedScene:
	# A model that hasn't been imported yet (a fresh checkout before the editor's opened) just leaves the old props.
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene


static func _hide(mi: MeshInstance3D) -> void:
	WATCH.set_layers(mi, 0)
	mi.set_meta(OLD_META, true)


static func _lamps(group: Node, lamp: PackedScene) -> int:
	var poles := []
	var glass := []
	for c in group.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is CylinderMesh and absf((mi.mesh as CylinderMesh).height - POLE_H) < 0.01:
			poles.append(mi)
		elif mi.mesh is BoxMesh:
			glass.append(mi)
	var n := 0
	for pole: MeshInstance3D in poles:
		var base := pole.position - Vector3(0, POLE_H / 2, 0)
		for g: MeshInstance3D in glass:
			if g.position.distance_to(base + Vector3(0, 3.7, 0)) < 0.05:
				_hide(g)
		_hide(pole)
		var m := lamp.instantiate() as Node3D
		m.name = "Detailed Lamp %d" % n
		m.position = base
		m.rotation.y = fposmod(base.x * 0.37 + base.z * 0.61, PI / 2)     # a little turn each, so they don't all match
		group.add_child(m)
		n += 1
	return n


static func _benches(scene: Node, bench: PackedScene) -> int:
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is BoxMesh) or not (mi.mesh as BoxMesh).size.is_equal_approx(BENCH_SEAT):
			continue
		if not is_equal_approx(mi.position.y, 0.45) or mi.has_meta(OLD_META):
			continue
		var b := mi.get_parent() as Node3D
		if b == null or b.get_script() != null:
			continue
		for c in b.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("@"):
				_hide(c)
		var m := bench.instantiate() as Node3D
		m.name = "Detailed Bench"
		b.add_child(m)
		n += 1
	return n


static func _gazebo(g: Node3D, gazebo: PackedScene) -> int:
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not String(mi.name).begins_with("@"):
			continue
		var m := mi.material_override
		if m and m.resource_name in GAZEBO_MATS:
			_hide(mi)
	var model := gazebo.instantiate() as Node3D
	model.name = "Detailed Gazebo"
	g.add_child(model)
	return 1


static func _mat_name(mi: MeshInstance3D) -> String:
	return String(mi.material_override.resource_name) if mi.material_override else ""


static func _pumpkins(scene: Node, pumpkin: PackedScene, jack: PackedScene) -> Vector2i:
	# Every builder pumpkin (tools/build_earth.gd _pumpkin: a ball of radius r squashed to 1.15 x 0.8 x 1.15, its
	# middle 0.7 r over the spot, and a stem 1.4 r up) and jack-o'-lantern (a pumpkin with a glowing face in a little
	# node in front of it). The detailed one goes UNDER the old ball, so when the seasons hide the ball (only autumn
	# has pumpkins: scripts/seasons.gd) it goes too, and it undoes the ball's squash so it's round at the right size.
	var n := Vector2i.ZERO
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is SphereMesh) or _mat_name(mi) != "Pumpkin" or mi.has_meta(OLD_META):
			continue
		var parent := mi.get_parent() as Node3D
		if parent == null or not mi.scale.is_equal_approx(Vector3(1.15, 0.8, 1.15)):
			continue
		var r := (mi.mesh as SphereMesh).radius
		var at := mi.position - Vector3(0, 0.7 * r, 0)
		var face: Node3D = null
		for c in parent.get_children():
			var c3 := c as Node3D
			if c3 is MeshInstance3D:
				if _mat_name(c3) == "Pumpkin Stem" and c3.position.distance_to(at + Vector3(0, 1.4 * r, 0)) < 0.01:
					_hide(c3)
			elif c3 and c3.position.distance_to(at + Vector3(0, 0.75 * r, 1.08 * r)) < 0.01 and c3.get_child_count() > 0 \
					and c3.get_child(0) is MeshInstance3D and _mat_name(c3.get_child(0)) == "Jack Glow":
				face = c3
		if face:
			for g in face.get_children():
				if g is MeshInstance3D:
					_hide(g)
		_hide(mi)
		var m := (jack if face else pumpkin).instantiate() as Node3D
		m.name = "Detailed Jack" if face else "Detailed Pumpkin"
		# a jack faces where the builder's face did (+Z); a plain pumpkin gets a turn of its own
		var yaw := 0.0 if face else fposmod(at.x * 2.3 + at.z * 1.7, TAU)
		m.transform = Transform3D(mi.basis.inverse() * Basis(Vector3.UP, yaw).scaled(Vector3.ONE * r),
			mi.basis.inverse() * Vector3(0, -0.7 * r, 0))
		mi.add_child(m)
		if face:
			n.y += 1
		else:
			n.x += 1
	return n


static func _scarecrows(scene: Node, scarecrow: PackedScene) -> int:
	# The builder's scarecrows (_scarecrow): a node of pieces, found by its sack head (the second one in a place got a
	# made-up name). The seasons hide that node, so the detailed one goes in it.
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if _mat_name(mi) != "Sack Head" or mi.has_meta(OLD_META):
			continue
		var s := mi.get_parent() as Node3D
		if s == null or s.get_script() != null or s.has_node("Detailed Scarecrow"):
			continue
		for c in s.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("@"):
				_hide(c)
		var m := scarecrow.instantiate() as Node3D
		m.name = "Detailed Scarecrow"
		s.add_child(m)
		n += 1
	return n


static func _mailboxes(scene: Node, mailbox: PackedScene) -> int:
	# The builder's mailboxes (_mailbox): a post, a box and a flag; the family's name over it stays.
	var n := 0
	for node in scene.find_children("Mailbox*", "Node3D", true, false):
		var b := node as Node3D
		if b.get_script() != null or not b.has_node("Box") or b.has_node("Detailed Mailbox"):
			continue
		for c in b.get_children():
			if c is MeshInstance3D:
				_hide(c)
		var m := mailbox.instantiate() as Node3D
		m.name = "Detailed Mailbox"
		b.add_child(m)
		n += 1
	return n


static func _signs(scene: Node, sign: PackedScene) -> int:
	# The Void's sign posts (tools/build_town.gd sign_post): a 2 m pole, a board as wide as its words and the words.
	# The model has a board of five widths: keep the nearest and stretch it the rest of the way.
	var n := 0
	for node in scene.find_children("Sign*", "Node3D", true, false):
		var s := node as Node3D
		if s.get_script() != null or s.has_node("Detailed Sign"):
			continue
		var pole: MeshInstance3D = null
		var board: MeshInstance3D = null
		for c in s.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			if mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).height, 2.0):
				pole = mi
			elif mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.9):
				board = mi
		if pole == null or board == null:
			continue
		var width := (board.mesh as BoxMesh).size.x
		_hide(pole)
		_hide(board)
		var m := sign.instantiate() as Node3D
		m.name = "Detailed Sign"
		var best: Node3D = null
		var best_off := INF
		for c in m.get_children():
			if not String(c.name).begins_with("Board"):
				continue
			var w := float(String(c.name).trim_prefix("Board")) / 10.0
			var off := absf(log(width / w))
			if off < best_off:
				best_off = off
				best = c
		for c in m.get_children():
			if String(c.name).begins_with("Board") and c != best:
				m.remove_child(c)
				c.free()
		if best:
			var w := float(String(best.name).trim_prefix("Board")) / 10.0
			best.scale.x *= width / w
		s.add_child(m)
		n += 1
	return n


static func _mesh_of(model: PackedScene) -> Mesh:
	var m := model.instantiate()
	var found := m.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() > 0 else null
	m.free()
	return mesh


static func _on_line(p: Vector3, a: Vector3, b: Vector3) -> bool:
	# Whether p (on the ground plane) lies on the fence line from a to b
	var d := Vector2(b.x - a.x, b.z - a.z)
	var q := Vector2(p.x - a.x, p.z - a.z)
	var t := q.dot(d) / maxf(d.length_squared(), 0.0001)
	return t > -0.01 and t < 1.01 and (q - d * t).length() < 0.02


static func _fences(scene: Node, picket: Mesh, post: Mesh) -> int:
	# The builder's picket fences (tools/build_earth.gd _picket_fence): a picket and a pointed top every 0.35 m or
	# so and two rails, all white boxes. Each is found by its low rail (0.35 m up, 0.06 x 0.08 across, as long as the
	# fence) and drawn again as one MultiMesh of detailed pickets per place, with a post at each end. The old fence's
	# collision is one box of its own and stays. A MultiMesh keeps nothing in a headless run, so the pickets' places
	# are in its meta "transforms" too (for tests).
	if picket == null or post == null:
		return 0
	var n := 0
	var by_parent := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is BoxMesh) or _mat_name(mi) != "Gazebo White" or mi.has_meta(OLD_META):
			continue
		var size := (mi.mesh as BoxMesh).size
		if not (is_equal_approx(size.x, 0.06) and is_equal_approx(size.y, 0.08) and is_equal_approx(mi.position.y, 0.35)):
			continue
		var parent := mi.get_parent() as Node3D
		if parent == null or parent.get_script() != null:
			continue
		var along := Vector3(sin(mi.rotation.y), 0, cos(mi.rotation.y))
		var mid := Vector3(mi.position.x, 0, mi.position.z)
		var a := mid - along * size.z / 2.0
		var b := mid + along * size.z / 2.0
		# the fence's old pieces: both rails, every picket and its pointed top
		for c in parent.get_children():
			var p := c as MeshInstance3D
			if p == null or _mat_name(p) != "Gazebo White" or p.has_meta(OLD_META):
				continue
			var y := p.position.y
			var hit := false
			if p.mesh is BoxMesh:
				var s := (p.mesh as BoxMesh).size
				hit = (s.is_equal_approx(Vector3(0.1, 1.0, 0.06)) and is_equal_approx(y, 0.5)) \
					or (s.is_equal_approx(size) and (is_equal_approx(y, 0.35) or is_equal_approx(y, 0.8)))
			elif p.mesh is CylinderMesh:
				var cm := p.mesh as CylinderMesh
				hit = is_zero_approx(cm.top_radius) and is_equal_approx(cm.height, 0.14) and is_equal_approx(y, 1.07)
			if hit and _on_line(p.position, a, b):
				_hide(p)
		var count := int(size.z / PICKET_GAP)
		var gap := size.z / maxf(count, 1)
		var yaw := Basis(Vector3.UP, mi.rotation.y)
		if not by_parent.has(parent):
			by_parent[parent] = [[], []]
		for k in count:
			by_parent[parent][0].append(Transform3D(yaw.scaled(Vector3(1, 1, gap / PICKET_GAP)), a + along * gap * k))
		for end in [a, b]:
			by_parent[parent][1].append(Transform3D(yaw, end))
		n += 1
	for parent: Node3D in by_parent:
		for which in 2:
			var xfs: Array = by_parent[parent][which]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = picket if which == 0 else post
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Detailed Fence Pickets" if which == 0 else "Detailed Fence Posts"
			mmi.multimesh = mm
			mmi.set_meta("transforms", xfs)
			mmi.visibility_range_end = 160.0
			parent.add_child(mmi)
	return n


static func _porches(scene: Node, porch: PackedScene, roof: PackedScene) -> int:
	# The front porches on Maple Lane (tools/build_earth.gd _house): a slab, a flat roof in the house's roof colour
	# and two white posts. The slab's collision is a body of its own and stays. The detailed roof is tinted with the
	# house's roof colour, keeping the old material's name so the seasons still put snow on it in winter.
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is BoxMesh) or _mat_name(mi) != "Porch Wood" or mi.has_meta(OLD_META):
			continue
		if not (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(5.0, 0.3, 2.0)):
			continue
		var g := mi.get_parent() as Node3D
		if g == null or g.get_script() != null or g.has_node("Detailed Porch"):
			continue
		var front := mi.position.z - 1.0
		var roof_mat: StandardMaterial3D = null
		for c in g.get_children():
			var p := c as MeshInstance3D
			if p == null or not (p.mesh is BoxMesh):
				continue
			var s := (p.mesh as BoxMesh).size
			if _mat_name(p).begins_with("Porch Roof ") and s.is_equal_approx(Vector3(5.4, 0.15, 2.3)):
				roof_mat = p.material_override as StandardMaterial3D
				_hide(p)
			elif _mat_name(p) == "Gazebo White" and s.is_equal_approx(Vector3(0.15, 2.8, 0.15)) \
					and absf(p.position.z - (front + 2.0)) < 0.01:
				_hide(p)
		_hide(mi)
		var m := porch.instantiate() as Node3D
		m.name = "Detailed Porch"
		m.position = Vector3(mi.position.x, 0, front)
		g.add_child(m)
		var r := roof.instantiate() as Node3D
		r.name = "Detailed Porch Roof"
		r.position = m.position
		if roof_mat:
			# (the seasons may already have their own copy of it: start from the colour it was built with)
			var built: StandardMaterial3D = roof_mat.get_meta("from", roof_mat)
			for rm in r.find_children("*", "MeshInstance3D", true, false):
				var own := (rm as MeshInstance3D).get_active_material(0).duplicate() as StandardMaterial3D
				own.resource_name = built.resource_name
				own.albedo_color = built.albedo_color
				(rm as MeshInstance3D).material_override = own
		g.add_child(r)
		var seasons := scene.get_node_or_null("Seasons")
		if seasons and seasons.has_method("take_in"):
			seasons.call("take_in", r)
		n += 1
	return n


static func _fountains(scene: Node, fountain: PackedScene) -> int:
	# The Void's two fountains (tools/build_town.gd: the Market Square's and Island Park's): the stone basin and the
	# column are swapped; the water, the glowing water ball (with the lost watch on it), the collision stay.
	var n := 0
	for place in FOUNTAINS:
		var g := scene.get_node_or_null(place) as Node3D
		if g == null or g.has_node("Detailed Fountain"):
			continue
		var hid := 0
		for c in g.get_children():
			var p := c as MeshInstance3D
			if p and p.mesh is CylinderMesh and _mat_name(p) == "Fountain Stone" and absf(p.position.x) < 0.01 \
					and absf(p.position.z) < 0.01:
				_hide(p)
				hid += 1
		if hid == 0:
			continue
		var m := fountain.instantiate() as Node3D
		m.name = "Detailed Fountain"
		g.add_child(m)
		n += 1
	return n


static func _void_lamps(scene: Node, lamp: PackedScene) -> int:
	# The Void's lamp posts: a plain pole with a glowing ball on top. The pole is swapped for a detailed one, made
	# as tall as this lamp's ball, whose cage goes round the ball. The ball stays: the Void's night lights it up
	# (scripts/day_night.gd, by its material "Lamp").
	var n := 0
	var bulbs := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is SphereMesh and _mat_name(mi) == "Lamp":
			if not bulbs.has(mi.get_parent()):
				bulbs[mi.get_parent()] = []
			bulbs[mi.get_parent()].append(mi)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is CylinderMesh) or mi.has_meta(OLD_META):
			continue
		var parent := mi.get_parent() as Node3D
		var h := (mi.mesh as CylinderMesh).height
		var kind_ok := false
		for k in VOID_LAMPS:
			if _mat_name(mi) == k[0] and is_equal_approx(h, k[1]) and String(parent.name).begins_with(k[2]):
				kind_ok = true
		if not kind_ok:
			continue
		var base := mi.position - Vector3(0, h / 2.0, 0)
		var bulb: MeshInstance3D = null
		for b: MeshInstance3D in bulbs.get(parent, []):
			var off := b.position - base
			if Vector2(off.x, off.z).length() < 0.05 and off.y > h * 0.9 and off.y < h + 0.6:
				bulb = b
		if bulb == null:
			continue
		_hide(mi)
		var m := lamp.instantiate() as Node3D
		m.name = "Detailed Lamp %d" % n
		m.position = base
		m.rotation.y = fposmod(base.x * 0.37 + base.z * 0.61, PI / 2)
		m.scale = Vector3.ONE * ((bulb.position.y - base.y) / LAMP_BULB)
		parent.add_child(m)
		n += 1
	return n


static func _hay(scene: Node, hay: PackedScene) -> int:
	# The builder's round hay bales: a cylinder 1.2 m across and 1.2 m long laid on its side (by the dance studio, in
	# the pumpkin patch and at the green's corners). The detailed one goes inside the old cylinder, so its axis is the
	# cylinder's and the seasons hiding the Autumn Dressing hide it too; each is rolled round a bit so no two match.
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is CylinderMesh) or _mat_name(mi) != "Hay" or mi.has_meta(OLD_META):
			continue
		var cm := mi.mesh as CylinderMesh
		if not (is_equal_approx(cm.top_radius, 0.6) and is_equal_approx(cm.height, 1.2)):
			continue
		_hide(mi)
		var m := hay.instantiate() as Node3D
		m.name = "Detailed Hay"
		var p := mi.global_position if mi.is_inside_tree() else mi.position
		m.rotation.y = fposmod(p.x * 1.9 + p.z * 2.7, TAU)
		mi.add_child(m)
		n += 1
	return n


static func _corn(scene: Node, corn: PackedScene) -> int:
	# The cornstalk bundles tied to the street lamps round the green (tools/build_earth.gd _halloween): five thin
	# cylinders 2.2 m tall round a spot. Each bundle becomes one sheaf standing on that spot, in the same place in the
	# tree (the Autumn Dressing), so it comes and goes with the season.
	var n := 0
	var groups := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is CylinderMesh) or _mat_name(mi) != "Cornstalk" or mi.has_meta(OLD_META):
			continue
		if not is_equal_approx((mi.mesh as CylinderMesh).height, 2.2):
			continue
		var parent := mi.get_parent() as Node3D
		if parent == null or parent.get_script() != null:
			continue
		if not groups.has(parent):
			groups[parent] = []
		var put := false
		for b: Array in groups[parent]:
			if Vector2(b[0].position.x - mi.position.x, b[0].position.z - mi.position.z).length() < 0.6:
				b.append(mi)
				put = true
				break
		if not put:
			groups[parent].append([mi])
	for parent: Node3D in groups:
		for b: Array in groups[parent]:
			var mid := Vector3.ZERO
			for mi: MeshInstance3D in b:
				mid += mi.position
				_hide(mi)
			mid /= b.size()
			var m := corn.instantiate() as Node3D
			m.name = "Detailed Corn %d" % n
			m.position = Vector3(mid.x, mid.y - 1.1, mid.z)
			m.rotation.y = fposmod(mid.x * 1.3 + mid.z * 0.7, TAU)
			parent.add_child(m)
			n += 1
	return n


static func _swap_node(scene: Node, node_name: String, model: PackedScene, new_name: String, lift := 0.0) -> int:
	# A one-off made of plain pieces under a node of its own (the fire engine, the rowing boat): its pieces stop
	# being drawn and the detailed one goes in that node. The collision (a body of its own) stays.
	var g := scene.find_child(node_name, true, false) as Node3D
	if g == null or g.get_script() != null or g.has_node(new_name):
		return 0
	for c in g.get_children():
		if c is MeshInstance3D:
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = new_name
	m.position.y = lift
	g.add_child(m)
	return 1


static func _playground(scene: Node) -> int:
	# The playground by Willow Pond (tools/build_earth.gd _playground): the slide tower, the swings and the sandbox.
	# Each old piece stops being drawn and the detailed one goes in its node, in the same frame (built to match), so
	# the deck you climb onto and the sandbox's boards keep their collision. The sign and the bark stay as they are.
	var p := scene.find_child("Playground", true, false) as Node3D
	if p == null or p.get_script() != null:
		return 0
	var n := 0
	var sandbox: Node3D = null
	for c in p.get_children():
		for m in c.find_children("*", "MeshInstance3D", true, false):
			if _mat_name(m) == "Sand":
				sandbox = c
	for pair in [[p.get_node_or_null("Slide"), SLIDE, "Detailed Slide"], [p.get_node_or_null("Swings"), SWINGS,
			"Detailed Swings"], [sandbox, SANDBOX, "Detailed Sandbox"]]:
		var g := pair[0] as Node3D
		var model := _scene(pair[1])
		if g == null or model == null or g.has_node(pair[2]):
			continue
		for m in g.find_children("*", "MeshInstance3D", true, false):
			_hide(m)
		var d := model.instantiate() as Node3D
		d.name = pair[2]
		g.add_child(d)
		n += 1
	return n


static func _planters(scene: Node, planter: PackedScene) -> int:
	# Main Street's stone planters, each with four balls of mums along it (tools/build_earth.gd, "Main Street
	# Things"). The detailed planter stands where the box was, with its mums planted in it in the same colours.
	var g := scene.find_child("Main Street Things", true, false) as Node3D
	if g == null:
		return 0
	var mums: Array[MeshInstance3D] = []
	for m in g.find_children("*", "MeshInstance3D", true, false):
		if _mat_name(m).begins_with("Mums ") and not m.has_meta(OLD_META):
			mums.append(m)
	var n := 0
	for m in g.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if _mat_name(mi) != "Planter Stone" or mi.has_meta(OLD_META) or not (mi.mesh is BoxMesh):
			continue
		var at := g.to_local(mi.global_transform.origin) if mi.is_inside_tree() else _local_to(g, mi)
		_hide(mi)
		for b in mums:
			if not b.has_meta(OLD_META) and Vector2(b.position.x - at.x, b.position.z - at.z).length() < 2.2:
				_hide(b)
		var d := planter.instantiate() as Node3D
		d.name = "Detailed Planter %d" % n
		d.position = Vector3(at.x, 0, at.z)
		g.add_child(d)
		n += 1
	return n


static func _local_to(g: Node3D, mi: Node3D) -> Vector3:
	# Outside the tree (a test building the scene by hand) global_transform can't be read: add up the parents.
	var t := mi.transform
	var p := mi.get_parent() as Node3D
	while p and p != g:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t.origin
