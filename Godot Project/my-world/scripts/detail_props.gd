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
const OLD_META := "detail_prop_old"
const GAZEBO_MATS := ["Gazebo White", "Gazebo Roof"]
const POLE_H := 3.6                    # the builder's lamp pole (_lamp_post): a 3.6 m cylinder, centre 1.8 m up
const BENCH_SEAT := Vector3(1.8, 0.1, 0.5)


static func dress_earth(scene: Node) -> Dictionary:
	var out := {"lamps": 0, "benches": 0, "gazebo": 0, "pumpkins": 0, "jacks": 0, "scarecrows": 0, "mailboxes": 0}
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
	return out


static func dress_void(scene: Node) -> Dictionary:
	# The Void's Market Square (16 Nov 2026, the whole game gets the treatment): its six stalls, each with its own
	# goods (tools/build_prop_stall.py). The stall's collision, shop spot and name over it are the builder's.
	var out := {"stalls": 0, "signs": 0}
	var sign := _scene(SIGN)
	if sign:
		out.signs = _signs(scene, sign)
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
	mi.layers = 0
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
