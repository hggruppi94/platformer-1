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
const COVERED_BRIDGE := "res://models/props/covered_bridge.glb"
const FOOTBRIDGE := "res://models/props/footbridge.glb"
const DOCK := "res://models/props/dock.glb"
const TELESCOPE := "res://models/props/telescope.glb"
const PALM := "res://models/props/palm.glb"
const TIKI_TORCH := "res://models/props/tiki_torch.glb"
const GROVE_LANTERN := "res://models/props/grove_lantern.glb"
const SPRINGS_GATE := "res://models/props/springs_gate.glb"
const CRYSTAL := "res://models/props/crystal.glb"
const BASKETBALL_HOOP := "res://models/props/basketball_hoop.glb"
const TENNIS_NET := "res://models/props/tennis_net.glb"
const SOCCER_GOAL := "res://models/props/soccer_goal.glb"
const ROCK_WALL := "res://models/props/rock_wall.glb"
const OLD_SLIDE := "res://models/props/old_slide.glb"
const SAILBOAT := "res://models/props/sailboat.glb"
const DOME_DOOR := "res://models/props/dome_door.glb"
const ANTIQUE_CAR := "res://models/props/antique_car.glb"
const PICNIC_BASKET := "res://models/props/picnic_basket.glb"
const CLOCK_CASE := "res://models/props/clock_case.glb"
const CLOCK_HOOD := "res://models/props/clock_hood.glb"
const COG := "res://models/props/cog.glb"
const BOULDER := "res://models/props/boulder.glb"
const GADGET_STALL := "res://models/props/gadget_stall.glb"
const WORKBENCH := "res://models/props/workbench.glb"
const REQUEST_BOARD := "res://models/props/request_board.glb"
const RACE_BOARD := "res://models/props/race_board.glb"
const TUNE_UP := "res://models/props/tune_up.glb"
const RUN_CLOCK := "res://models/props/run_clock.glb"
const ARCH_TOWER := "res://models/props/arch_tower.glb"
const ARCH_BANNER := "res://models/props/arch_banner.glb"
const TREE_HOUSE := "res://models/props/tree_house.glb"
const LAB_SHED := "res://models/props/lab_shed.glb"
const LAB_KIT := "res://models/props/lab_kit.glb"
const POOL_WALL := "res://models/props/pool_wall.glb"
const POOL_LIP := "res://models/props/pool_lip.glb"
const VEIN_ROCK := "res://models/props/vein_rock.glb"
const VEIN_CRYSTALS := "res://models/props/vein_crystals.glb"
const VEIN_STUBS := "res://models/props/vein_stubs.glb"
const TREE_HOUSE_MATS := ["Big Bark", "Tree House Wood", "Tree House Wall", "Tree House Roof"]
const LAB_KEEP := "lab_keep"           # pieces of the lab that stay as they are (scripts/lab.gd: Hound Hero's picture)
const ARCH_BANNER_HALF := 6.2          # half the model banner's width (tools/build_prop_void_gate.py arch_banner HW)
const CLOCK_CASE_H := 1.9              # the model clock trunk's height (tools/build_prop_void_more.py CASE_H)
const CLOCK_HOOD_H := 0.8              # how much of each clock is its hood (scripts/bosses.gd _clock_ring)
const CRYSTAL_R := 0.18                # the model shard's shoulder radius; it's 1 tall (tools/build_prop_void.py CR)
const DOME_DOOR_SIZE := Vector3(1.8, 2.6, 0.6)
const PALM_H := 5.0                    # the model palm's height (tools/build_prop_island.py PALM_H)
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
		"playground": 0, "planters": 0, "covered_bridge": 0, "footbridge": 0, "dock": 0, "telescope": 0}
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
	# (16 Nov 2026, batch six: tools/build_prop_creek.py)
	var cb := _scene(COVERED_BRIDGE)
	if cb:
		out.covered_bridge = _covered_bridge(scene, cb)
	var fb := _scene(FOOTBRIDGE)
	if fb:
		out.footbridge = _by_material(scene, "Footbridge", ["Bridge Wood"], fb, "Detailed Footbridge")
	var dk := _scene(DOCK)
	if dk:
		out.dock = _by_material(scene, "Dock", ["Bridge Wood", "Post Wood"], dk, "Detailed Dock", true)
	var scope := _scene(TELESCOPE)
	if scope:
		out.telescope = _telescope(scene, scope)
	return out


static func dress_void(scene: Node) -> Dictionary:
	# The Void's Market Square (16 Nov 2026, the whole game gets the treatment): its six stalls, each with its own
	# goods (tools/build_prop_stall.py). The stall's collision, shop spot and name over it are the builder's.
	var out := {"stalls": 0, "signs": 0, "fountains": 0, "lamps": 0, "crystals": 0, "sailboats": 0, "doors": 0,
		"car": 0, "baskets": 0, "clocks": 0, "cogs": 0, "boulders": 0, "gadget_stall": 0, "tree_house": 0,
		"hoops": 0, "tennis_net": 0, "goals": 0, "rock_wall": 0, "old_slide": 0}
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
	# (18 Nov 2026, the Void's batch: tools/build_prop_void.py)
	var crystal := _scene(CRYSTAL)
	if crystal:
		out.crystals = _crystals(scene, crystal)
	var sailboat := _scene(SAILBOAT)
	if sailboat:
		out.sailboats = _sailboats(scene, sailboat)
	var door := _scene(DOME_DOOR)
	if door:
		out.doors = _dome_doors(scene, door)
	var car := _scene(ANTIQUE_CAR)
	if car:
		out.car = _antique_car(scene, car)
	var basket := _scene(PICNIC_BASKET)
	if basket:
		out.baskets = _baskets(scene, basket)
	# (18 Nov 2026, more of the Void: tools/build_prop_void_more.py). The clockyard, the hollow and Dash's stall are
	# put in by Bosses and Arsenal as the town loads, and they dress themselves too (each calls the same function),
	# so whichever comes first, they're swapped once.
	var yard := dress_clockyard(scene.get_node_or_null("Goblin Clockyard"))
	out.clocks = yard.x
	out.cogs = yard.y
	out.boulders = dress_hollow(scene.get_node_or_null("Boulder Hollow"))
	out.gadget_stall = dress_gadget_stall(scene.get_node_or_null("Gadget Stall"))
	# (18 Nov 2026, batch ten: tools/build_prop_void_4.py). The lab, the Wishing Well and the Remnant veins are put in
	# at play time and dress themselves (dress_lab, dress_pool, dress_vein).
	out.tree_house = dress_tree_house(scene.get_node_or_null("Tree House"))
	# (18 Nov 2026, batch eleven: tools/build_prop_void_sports.py): the park and sports corner
	var hoop := _scene(BASKETBALL_HOOP)
	if hoop:
		out.hoops = _hoops(scene.get_node_or_null("Basketball Court"), hoop)
	var tnet := _scene(TENNIS_NET)
	if tnet:
		out.tennis_net = _tennis_net(scene.get_node_or_null("Tennis Court"), tnet)
	var goal := _scene(SOCCER_GOAL)
	if goal:
		out.goals = _goals(scene.get_node_or_null("Soccer Field"), goal)
	var wall := _scene(ROCK_WALL)
	if wall:
		out.rock_wall = _whole(scene.get_node_or_null("Rock Wall"), wall, "Detailed Rock Wall")
	var slide := _scene(OLD_SLIDE)
	if slide:
		out.old_slide = _whole(scene.get_node_or_null("Old Slide"), slide, "Detailed Old Slide")
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


static func dress_rhythm(scene: Node) -> Dictionary:
	# Melody's island in Rhythm Springs (16 Nov 2026, batch seven, made to look like Hayden's concept pictures:
	# tools/build_prop_island.py): its palms, tiki torches, the bamboo grove's lanterns and the Springs Gate. The old
	# pieces stop being drawn; their collisions, the torches' flames and lights, and the shade markers stay.
	var out := {"palms": 0, "torches": 0, "lanterns": 0, "gate": 0}
	var palm := _scene(PALM)
	if palm:
		for g in scene.find_children("Parasol Palm *", "Node3D", true, false):
			out.palms += _palm(g, palm)
	# The builder names only the first torch and lantern (the rest are "@Node3D@..."), so they're found by what's
	# in them: a torch has its "Flame", a lantern its "Lantern Glow" box.
	var torch := _scene(TIKI_TORCH)
	var lantern := _scene(GROVE_LANTERN)
	for g in scene.find_children("*", "Node3D", true, false):
		var flame := g.get_node_or_null("Flame") as MeshInstance3D
		if torch and flame and _mat_name(flame) == "Torch Flame" and g.get_parent().name == "Torch Paths":
			out.torches += _dress_in(g, torch, "Detailed Torch", ["Flame"])
		elif lantern and g.get_parent().name == "Bamboo Grove" and _has_mat(g, "Lantern Glow"):
			out.lanterns += _dress_in(g, lantern, "Detailed Lantern", [])
	var gate := _scene(SPRINGS_GATE)
	# (Since the island grew, the gate's own pieces sit in "Gate Core", scaled up; the baked gate goes in there too, so
	# it's scaled the same. Its walls and towers stay as built.)
	var sg := scene.find_child("Springs Gate", true, false) as Node3D
	if sg and sg.has_node("Gate Core"):
		sg = sg.get_node("Gate Core") as Node3D
	if gate and sg:
		out.gate = _dress_in(sg, gate, "Detailed Gate", [])
	return out


static func _has_mat(g: Node, mat_name: String) -> bool:
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) == mat_name:
			return true
	return false


static func _dress_in(g: Node3D, model: PackedScene, new_name: String, keep: Array) -> int:
	# Every plain piece straight under the node stops being drawn (except the ones named in keep) and the detailed
	# one goes in the node, at its origin.
	if g.get_script() != null or g.has_node(new_name):
		return 0
	for c in g.get_children():
		if c is MeshInstance3D and not (String(c.name) in keep):
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = new_name
	g.add_child(m)
	return 1


static func _palm(g: Node3D, model: PackedScene) -> int:
	# A parasol palm (tools/build_rhythm_springs.gd _palm): its coconut hangs 0.3 m under the top of its leaning
	# trunk, so it says how tall the palm is and which way it leans. The model curves over towards +X, so it's turned
	# to lean the same way and scaled to the same height.
	if g.get_script() != null or g.has_node("Detailed Palm"):
		return 0
	var top := Vector3(0, 5.0, 0)
	for c in g.get_children():
		if c is MeshInstance3D:
			if _mat_name(c) == "Coconut":
				top = c.position + Vector3(0, 0.3, 0)
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = "Detailed Palm"
	var s := top.y / PALM_H
	m.scale = Vector3(s, s, s)
	var lean := Vector2(top.x, top.z)
	m.rotation.y = atan2(-lean.y, lean.x) if lean.length() > 0.05 else fposmod(g.position.x * 1.7 + g.position.z, TAU)
	g.add_child(m)
	return 1


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


static func _covered_bridge(scene: Node, model: PackedScene) -> int:
	# The old covered bridge on Maple Lane (tools/build_earth.gd _covered_bridge): its deck, walls, windows, roof and
	# end trims stop being drawn and the detailed bridge, built to the same sizes, goes in its node. The stone feet
	# down in the creek (their heights follow the creek bed) stay, and so do the signs and lamps over each end.
	var g := scene.find_child("Covered Bridge", true, false) as Node3D
	if g == null or g.get_script() != null or g.has_node("Detailed Covered Bridge"):
		return 0
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) != "Library Stone":
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = "Detailed Covered Bridge"
	g.add_child(m)
	return 1


static func _by_material(scene: Node, node_name: String, mats: Array, model: PackedScene, new_name: String,
		flat := false) -> int:
	# A one-off whose plain pieces sit straight under a node of its own with other things beside them (the
	# footbridge's grind rails, the dock's rowing boat): only the pieces in these materials stop being drawn. The
	# detailed one goes where the first of them (the deck) was, turned the same way, on the ground's level.
	var g := scene.find_child(node_name, true, false) as Node3D
	if g == null or g.get_script() != null or g.has_node(new_name):
		return 0
	var deck: MeshInstance3D = null
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) in mats:
			if deck == null:
				deck = c
			_hide(c)
	if deck == null:
		return 0
	var m := model.instantiate() as Node3D
	m.name = new_name
	m.position = Vector3(deck.position.x, 0, deck.position.z)
	m.rotation.y = 0.0 if flat else deck.rotation.y
	g.add_child(m)
	return 1


static func _telescope(scene: Node, model: PackedScene) -> int:
	# The coin telescope on Lookout Hill (tools/build_earth.gd _lookout_hill): a post and a tilted tube in its own
	# little node. The detailed one looks the same way (towards the node's +Z, over the town).
	var top := scene.find_child("Lookout", true, false) as Node3D
	if top == null:
		return 0
	for m in top.find_children("*", "MeshInstance3D", true, false):
		if _mat_name(m) != "Scope Metal" or m.has_meta(OLD_META):
			continue
		var holder := m.get_parent() as Node3D
		if holder.has_node("Detailed Telescope"):
			return 0
		for o in holder.get_children():
			if o is MeshInstance3D:
				_hide(o)
		var d := model.instantiate() as Node3D
		d.name = "Detailed Telescope"
		holder.add_child(d)
		return 1
	return 0


# ---------------------------------------------------------------- the Void's batch (18 Nov 2026)
static func _crystals(scene: Node, model: PackedScene) -> int:
	# The glowing crystal clusters across the Void (tools/build_town.gd _crystals): each shard is two see-through
	# cylinders (a body r across at its shoulder, 0.65 of its height, and a point), so none of them could be merged
	# and every one was its own draw. Each shard becomes the detailed one, scaled to its size, and every shard of one
	# colour is one MultiMesh (four draws for the lot). The detailed shard is baked nearly white and tinted here with
	# the old colour, glow and all. The big shards' collisions stay. Places also in meta "transforms" (for tests).
	var g := scene.get_node_or_null("Crystals") as Node3D
	if g == null or g.get_script() != null or g.has_node("Detailed Crystals 0"):
		return 0
	var mesh := _mesh_of(model)
	if mesh == null:
		return 0
	var by_tint := {}          # material name -> [old material, transforms]
	var n := 0
	for cluster in g.get_children():
		if not (cluster is Node3D):
			continue
		for shard in cluster.get_children():
			if not (shard is Node3D) or shard is MeshInstance3D:
				continue
			var body: MeshInstance3D = null
			var tip: MeshInstance3D = null
			for c in shard.get_children():
				var mi := c as MeshInstance3D
				if mi == null or not (mi.mesh is CylinderMesh) or mi.has_meta(OLD_META):
					continue
				if is_zero_approx((mi.mesh as CylinderMesh).top_radius):
					tip = mi
				else:
					body = mi
			if body == null or tip == null:
				continue
			var cm := body.mesh as CylinderMesh
			var r := cm.top_radius
			var h := cm.height / 0.65
			var key := _mat_name(body)
			if not by_tint.has(key):
				by_tint[key] = [body.material_override, []]
			var s := r / CRYSTAL_R
			var local: Transform3D = (cluster as Node3D).transform * (shard as Node3D).transform
			by_tint[key][1].append(local * Transform3D(Basis.from_scale(Vector3(s, h, s)), Vector3.ZERO))
			_hide(body)
			_hide(tip)
			n += 1
	var k := 0
	for key: String in by_tint:
		var old := by_tint[key][0] as StandardMaterial3D
		var xfs: Array = by_tint[key][1]
		var mat := (mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		mat.resource_name = "Detailed " + key
		if old:
			var tint := Color(old.albedo_color, 1.0)
			mat.albedo_color = tint
			mat.emission_enabled = true
			mat.emission = tint
			mat.emission_energy_multiplier = old.emission_energy_multiplier
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Detailed Crystals %d" % k
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.set_meta("transforms", xfs)
		mmi.set_meta("tint", key)
		g.add_child(mmi)
		k += 1
	return n


static func _sailboats(scene: Node, model: PackedScene) -> int:
	# The lake's sailboats (tools/build_town.gd _boats): a box hull and a wedge sail in one of three colours. The
	# detailed one goes in each boat's node; its sail (material "sailboat_sail", baked white) takes the old sail's
	# colour.
	var g := scene.get_node_or_null("Sailboats") as Node3D
	if g == null or g.get_script() != null:
		return 0
	var n := 0
	for boat in g.get_children():
		if not (boat is Node3D) or boat is MeshInstance3D or boat.has_node("Detailed Sailboat"):
			continue
		var sail_col := Color.WHITE
		var found := false
		for c in boat.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			if _mat_name(mi).begins_with("Sail"):
				sail_col = (mi.material_override as StandardMaterial3D).albedo_color
			found = true
			_hide(mi)
		if not found:
			continue
		var m := model.instantiate() as Node3D
		m.name = "Detailed Sailboat"
		boat.add_child(m)
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			var sm := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if sm and sm.resource_name == "sailboat_sail":
				var t := sm.duplicate() as StandardMaterial3D
				t.albedo_color = sail_col
				mi.set_surface_override_material(0, t)
				mi.set_meta("sail_colour", sail_col)
		n += 1
	return n


static func _dome_doors(scene: Node, model: PackedScene) -> int:
	# The door of every dome building (tools/build_town.gd dome_building): a dark box 1.8 x 2.6 x 0.6 set into the
	# dome. The detailed door has its front where the box's was and its foot 0.2 m under the ground, like the box's.
	# The Door area (the way in) is a node of its own and stays.
	var n := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not (mi.mesh is BoxMesh) or _mat_name(mi) != "Door" or mi.has_meta(OLD_META):
			continue
		if not (mi.mesh as BoxMesh).size.is_equal_approx(DOME_DOOR_SIZE):
			continue
		var parent := mi.get_parent() as Node3D
		if parent == null or parent.get_script() != null:
			continue
		_hide(mi)
		var m := model.instantiate() as Node3D
		m.name = "Detailed Door %d" % n
		m.transform = Transform3D(mi.basis, mi.position - mi.basis.y * (DOME_DOOR_SIZE.y / 2.0 - 0.2))
		parent.add_child(m)
		n += 1
	return n


static func _antique_car(scene: Node, model: PackedScene) -> int:
	# The old car in the South Meadow picnic park: every piece but the see-through windscreen (kept, the model only
	# has its frame) stops being drawn and the detailed car goes in its node. Its collision stays.
	var g := scene.get_node_or_null("Antique Car") as Node3D
	if g == null or g.get_script() != null or g.has_node("Detailed Car"):
		return 0
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) != "Car Glass":
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = "Detailed Car"
	g.add_child(m)
	return 1


static func _baskets(scene: Node, model: PackedScene) -> int:
	# The picnic baskets on the South Meadow's blankets: a box 0.6 x 0.4 x 0.4, swapped for a wicker one standing
	# where it stood, turned the same way.
	var g := scene.get_node_or_null("South Meadow") as Node3D
	if g == null or g.get_script() != null:
		return 0
	var n := 0
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh) or _mat_name(mi) != "Picnic Basket" or mi.has_meta(OLD_META):
			continue
		_hide(mi)
		var m := model.instantiate() as Node3D
		m.name = "Detailed Basket %d" % n
		m.transform = Transform3D(mi.basis, mi.position - mi.basis.y * 0.2)
		g.add_child(m)
		n += 1
	return n


static func _hoops(court: Node3D, model: PackedScene) -> int:
	# The basketball court's two hoops (tools/build_town.gd court()): each a post (a cylinder 3.4 tall), a backboard
	# and a ring, at x = s * (half the court - 1). The detailed hoop faces -X from its post, so the one at -x turns
	# round. The court, its lines and its sign stay.
	if court == null or court.get_script() != null or court.has_node("Detailed Hoop 0"):
		return 0
	var n := 0
	for c in court.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.has_meta(OLD_META):
			continue
		if mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).height, 3.4):
			var m := model.instantiate() as Node3D
			m.name = "Detailed Hoop %d" % n
			m.position = Vector3(mi.position.x, 0, mi.position.z)
			m.rotation.y = 0.0 if mi.position.x > 0.0 else PI
			court.add_child(m)
			n += 1
			_hide(mi)
		elif mi.mesh is TorusMesh or _mat_name(mi) == "Backboard":
			_hide(mi)
	return n


static func _tennis_net(court: Node3D, model: PackedScene) -> int:
	# The tennis court's net (a see-through box 0.08 thick, as long as the court is wide) and its two posts
	# (cylinders 1.2 tall): the detailed net, 11 m long, stretched to fit.
	if court == null or court.get_script() != null or court.has_node("Detailed Net"):
		return 0
	var length := 0.0
	for c in court.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		if mi.mesh is BoxMesh and _mat_name(mi) == "Net":
			length = (mi.mesh as BoxMesh).size.z
			_hide(mi)
		elif mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).height, 1.2):
			_hide(mi)
	if length <= 0.0:
		return 0
	var m := model.instantiate() as Node3D
	m.name = "Detailed Net"
	m.scale = Vector3(1, 1, length / 11.0)
	court.add_child(m)
	return 1


static func _goals(field: Node3D, model: PackedScene) -> int:
	# The soccer court's two goals (tools/build_town.gd _soccer_field): posts (cylinders 2.2 tall), a crossbar (6 m)
	# and a see-through net box behind, on the goal line at x = +-15.6. The detailed goal's net reaches out to +X,
	# so the one at -x turns round. The turf, the ball and the sign stay.
	if field == null or field.get_script() != null or field.has_node("Detailed Goal 0"):
		return 0
	var lines := {}
	for c in field.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.has_meta(OLD_META):
			continue
		var goal_part := _mat_name(mi) == "Goal Net" or (_mat_name(mi) == "Goal Post" and mi.mesh is CylinderMesh)
		if goal_part:
			if _mat_name(mi) == "Goal Post":
				lines[signf(mi.position.x)] = mi.position.x
			_hide(mi)
	var n := 0
	for s: float in lines:
		var m := model.instantiate() as Node3D
		m.name = "Detailed Goal %d" % n
		m.position = Vector3(lines[s], 0, 0)
		m.rotation.y = 0.0 if s > 0.0 else PI
		field.add_child(m)
		n += 1
	return n


static func _whole(g: Node3D, model: PackedScene, name: String) -> int:
	# A landmark built from shapes straight in its group (the Rock Wall, the old slide): every one of its own pieces
	# stops being drawn and the detailed one goes in their place. Its sign (a node of its own) and every collision
	# stay.
	if g == null or g.get_script() != null or g.has_node(name):
		return 0
	for c in g.get_children():
		if c is MeshInstance3D:
			_hide(c)
	var m := model.instantiate() as Node3D
	m.name = name
	g.add_child(m)
	return 1


# ----------------------------------------------------------------------------- more of the Void (18 Nov 2026)
static func on() -> bool:
	# Whether detailed props are wanted (WorldDetail's switches). Things that build themselves at play time (the
	# clockyard, the stall, ammo crates in any place) ask this before dressing themselves.
	var tree := Engine.get_main_loop() as SceneTree
	var wd: Node = tree.root.get_node_or_null("WorldDetail") if tree else null
	return wd != null and bool(wd.get("enabled")) and bool(wd.get("detail_props"))


static func dress_clockyard(yard: Node) -> Vector2i:
	# The Goblin Clockyard (scripts/bosses.gd _clock_ring): each grandfather clock's trunk (a box 0.8 x h x 0.55)
	# becomes the detailed trunk stretched to h - 0.8, with the hood on top. Its own hand stays, turning over the
	# new face. Every cog in the grass (a cylinder 0.12 thick) becomes a detailed cog of its radius, tipped the same.
	var n := Vector2i.ZERO
	if yard == null or not on():
		return n
	var case_m := _scene(CLOCK_CASE)
	var hood_m := _scene(CLOCK_HOOD)
	var cog_m := _scene(COG)
	for c in yard.get_children():
		var clock := c as Node3D
		if clock == null or not String(clock.name).begins_with("Clock ") or case_m == null or hood_m == null:
			continue
		if clock.has_node("Detailed Clock Case"):
			n.x += 1
			continue
		var h := 0.0
		for p in clock.get_children():
			var mi := p as MeshInstance3D
			if mi and mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.x, 0.8):
				h = (mi.mesh as BoxMesh).size.y
		if h <= CLOCK_HOOD_H:
			continue
		for p in clock.get_children():
			var mi := p as MeshInstance3D
			if mi and not (mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.is_equal_approx(Vector3(0.04, 0.22, 0.02))):
				_hide(mi)
		var body := case_m.instantiate() as Node3D
		body.name = "Detailed Clock Case"
		body.scale = Vector3(1, (h - CLOCK_HOOD_H) / CLOCK_CASE_H, 1)
		clock.add_child(body)
		var hood := hood_m.instantiate() as Node3D
		hood.name = "Detailed Clock Hood"
		hood.position.y = h - CLOCK_HOOD_H
		clock.add_child(hood)
		n.x += 1
	if cog_m == null:
		return n
	for c in yard.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not (mi.mesh is CylinderMesh) or absf((mi.mesh as CylinderMesh).height - 0.12) > 0.001:
			continue
		if not mi.has_meta(OLD_META):
			_hide(mi)
			var r := (mi.mesh as CylinderMesh).top_radius
			var m := cog_m.instantiate() as Node3D
			m.name = "Detailed Cog %d" % n.y
			m.transform = Transform3D(mi.basis * Basis.from_scale(Vector3(r, 1, r)), mi.position)
			yard.add_child(m)
		n.y += 1
	return n


static func dress_hollow(hollow: Node) -> int:
	# Boulder Hollow (scripts/bosses.gd _place_hollow): each boulder (a squashed ball of radius r, tipped every which
	# way, and its moss cap) becomes a detailed boulder of that size turned the same way round, mossy on top. Its
	# collision ball stays.
	var n := 0
	var model := _scene(BOULDER)
	if hollow == null or model == null or not on():
		return n
	for c in hollow.get_children():
		var b := c as Node3D
		if b == null or not String(b.name).begins_with("Boulder "):
			continue
		if b.has_node("Detailed Boulder"):
			n += 1
			continue
		var r := 0.0
		var yaw := 0.0
		for p in b.get_children():
			var mi := p as MeshInstance3D
			if mi == null or not (mi.mesh is SphereMesh):
				continue
			var sm := mi.mesh as SphereMesh
			if is_equal_approx(sm.height, sm.radius * 1.6):
				r = sm.radius
				yaw = mi.rotation.y
			_hide(mi)
		if r <= 0.0:
			continue
		var m := model.instantiate() as Node3D
		m.name = "Detailed Boulder"
		m.rotation.y = yaw
		m.scale = Vector3.ONE * r
		b.add_child(m)
		n += 1
	return n


static func dress_gadget_stall(stall: Node) -> int:
	# Dash's gadget stall and his workbench (scripts/gadget_stall.gd): the counter, posts, awning, scallops and sign
	# board, and the bench, pegboard, awning, vice and tools, all made of plain shapes, become one detailed model
	# each. His gadgets on the counter, the bits on the bench, the light, both labels, the collisions and the shop
	# spots are kept.
	if stall == null or not on() or stall.has_node("Detailed Stall"):
		return 1 if stall != null and stall.has_node("Detailed Stall") else 0
	var stall_m := _scene(GADGET_STALL)
	var bench_m := _scene(WORKBENCH)
	if stall_m == null:
		return 0
	for c in stall.get_children():
		if c is MeshInstance3D:
			_hide(c)
	var m := stall_m.instantiate() as Node3D
	m.name = "Detailed Stall"
	stall.add_child(m)
	var bench := stall.get_node_or_null("Workbench")
	if bench and bench_m:
		for c in bench.get_children():
			if c is MeshInstance3D:
				_hide(c)
		var b := bench_m.instantiate() as Node3D
		b.name = "Detailed Workbench"
		bench.add_child(b)
	return 1


# ----------------------------------------------------------------------------- race and skate landmarks (18 Nov 2026)
static func _swap_meshes(holder: Node, model_path: String, new_name: String,
		keep := func(_mi: MeshInstance3D) -> bool: return false) -> int:
	# Hides every plain-shape piece directly under holder (but the ones keep says to leave) and puts the detailed
	# model in their place. Its labels, lights, moving bits (in nodes of their own), collisions and talk spots stay.
	if holder == null or not on():
		return 0
	if holder.has_node(new_name):
		return 1
	var model := _scene(model_path)
	if model == null:
		return 0
	for c in holder.get_children():
		var mi := c as MeshInstance3D
		if mi and not mi.has_meta(OLD_META) and not keep.call(mi):
			_hide(mi)
	var m := model.instantiate() as Node3D
	m.name = new_name
	holder.add_child(m)
	return 1


static func dress_request_board(board: Node) -> int:
	# Tally's request board in the Void's Market Square (scripts/request_board.gd): its posts, board, gold trims and
	# roof. Its spinning star (a node of its own), glow, words and talk spot stay. Stars Hollow's notice board (old
	# wood and pinned cards) is left as it is.
	if board == null or bool(board.get("earthy")):
		return 0
	return _swap_meshes(board, REQUEST_BOARD, "Detailed Board")


static func dress_run_clock(clock: Node) -> int:
	# A Run Clock at a skate park (scripts/skate_runs.gd _make_clock): the post, the face and its marks, the rim and
	# the sign board. Its hand (a node of its own, turning over the face), both labels and talk spot stay.
	return _swap_meshes(clock, RUN_CLOCK, "Detailed Clock")


static func dress_race_gate(track: Node) -> int:
	# A race's start (scripts/race_track.gd): the start arch's towers and banner, the race board and Zippy's Tune-Up.
	# The arch's towers stand where the old ones stood, however wide the road is, and the banner stretches between
	# them; the chequered line on the ground, the race's name on the banner, the board's words, the collisions and
	# the talk spots stay.
	var n := 0
	if track == null or not on():
		return n
	var arch := track.get_node_or_null("Start Arch") as Node3D
	var tower_m := _scene(ARCH_TOWER)
	var banner_m := _scene(ARCH_BANNER)
	if arch and tower_m and banner_m and not arch.has_node("Detailed Banner"):
		var half := 0.0
		for c in arch.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).height, 6.0):
				half = absf(mi.position.x)
		if half > 0.0:
			for c in arch.get_children():
				var mi := c as MeshInstance3D
				if mi and not (mi.mesh is BoxMesh and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.03)):
					_hide(mi)
			for side in [-1.0, 1.0]:
				var t := tower_m.instantiate() as Node3D
				t.name = "Detailed Tower %s" % ("L" if side < 0 else "R")
				t.position.x = side * half
				arch.add_child(t)
			var b := banner_m.instantiate() as Node3D
			b.name = "Detailed Banner"
			b.scale.x = half / ARCH_BANNER_HALF
			arch.add_child(b)
	if arch and arch.has_node("Detailed Banner"):
		n += 1
	n += _swap_meshes(track.get_node_or_null("Race Board"), RACE_BOARD, "Detailed Board")
	n += _swap_meshes(track.get_node_or_null("Tune-Up"), TUNE_UP, "Detailed Tune-Up")
	return n


# ----------------------------------------------------------------------------- batch ten (18 Nov 2026)
static func dress_tree_house(g: Node) -> int:
	# The Tree House (tools/build_town.gd _tree_house): the trunk, the spiral steps and their posts, the deck, the
	# railing and the little house with its roof become one detailed model. The leaves, the zipline, the sign, and
	# every collision (the trunk, each step, the deck, the house) stay.
	if g == null or not on():
		return 0
	if g.has_node("Detailed Tree House"):
		return 1
	var model := _scene(TREE_HOUSE)
	if model == null:
		return 0
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi and _mat_name(mi) in TREE_HOUSE_MATS:
			_hide(mi)
	var m := model.instantiate() as Node3D
	m.name = "Detailed Tree House"
	g.add_child(m)
	return 1


static func dress_lab(lab: Node) -> int:
	# Rex and Dash's lab (scripts/lab.gd _build): the shed (floor, walls, posts, roof, sign board, radar dish) and
	# its kit (the Swap-o-Tron's pod bases and caps, the cables, the console, Dash's bench, the chalkboard and the
	# picture frame). Anything that glows or is see-through (the pods' glass and coils, the buttons, the beakers),
	# the lever (a node of its own), Hound Hero's picture, the words, lights and every collision stay.
	if lab == null or not on():
		return 0
	if lab.has_node("Detailed Lab"):
		return 1
	var shed := _scene(LAB_SHED)
	var kit := _scene(LAB_KIT)
	if shed == null or kit == null:
		return 0
	var pieces: Array = []
	for c in lab.get_children():
		if c is MeshInstance3D:
			pieces.append(c)
		elif c is StaticBody3D:
			for b in c.get_children():
				if b is MeshInstance3D:
					pieces.append(b)
	for mi: MeshInstance3D in pieces:
		var mat := mi.material_override as StandardMaterial3D
		if mi.has_meta(LAB_KEEP) or (mat and (mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)):
			continue
		_hide(mi)
	var m := shed.instantiate() as Node3D
	m.name = "Detailed Lab"
	lab.add_child(m)
	var k := kit.instantiate() as Node3D
	k.name = "Detailed Lab Kit"
	lab.add_child(k)
	return 1


static func dress_pool(pool: Node, wall_h: float, stone: Color, trim: Color) -> int:
	# A deep pool (scripts/sunken_secrets.gd build_pool: the Wishing Well in the Void and one in five portal worlds):
	# the ring of wall boxes and the lip on top become the detailed wall and coping, baked pale and tinted to the
	# pool's own colours. The paving round it, the ledge, the floor, the water and every collision stay.
	if pool == null or not on():
		return 0
	if pool.has_node("Detailed Wall"):
		return 1
	var wall_m := _scene(POOL_WALL)
	var lip_m := _scene(POOL_LIP)
	if wall_m == null or lip_m == null:
		return 0
	for c in pool.get_children():
		var mi := c as MeshInstance3D
		if mi == null or not mi.mesh is BoxMesh:
			continue
		var sz := (mi.mesh as BoxMesh).size
		if is_equal_approx(sz.y, wall_h) or is_equal_approx(sz.y, 0.08):
			_hide(mi)
	var w := wall_m.instantiate() as Node3D
	w.name = "Detailed Wall"
	w.scale.y = wall_h / POOL_WALL_H
	_tint(w, stone)
	pool.add_child(w)
	var l := lip_m.instantiate() as Node3D
	l.name = "Detailed Lip"
	_tint(l, trim)
	pool.add_child(l)
	return 1


const POOL_WALL_H := 4.25              # the model wall's height (tools/build_prop_void_4.py WALL_H)


static func _tint(model: Node, c: Color) -> void:
	# The model's colours are baked pale; its own material, copied, multiplies them by c.
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat:
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = c
				mi.set_surface_override_material(i, copy)


static func dress_vein(vein: Node) -> int:
	# A Remnant vein (scripts/remnants.gd vein_model, in the Void and the portal worlds): its obsidian lumps, its nine
	# crystals and the stubs left once harvested. The crystals and stubs go in the vein's own "Crystals" and "Stubs"
	# nodes, so harvesting still shows one or the other. The glow light and the collision stay.
	if vein == null or not on():
		return 0
	if vein.has_node("Detailed Rock"):
		return 1
	var rock_m := _scene(VEIN_ROCK)
	var crystals_m := _scene(VEIN_CRYSTALS)
	var stubs_m := _scene(VEIN_STUBS)
	var crystals := vein.get_node_or_null("Crystals")
	var stubs := vein.get_node_or_null("Stubs")
	if rock_m == null or crystals_m == null or stubs_m == null or crystals == null or stubs == null:
		return 0
	for c in vein.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
			_hide(c)
	for holder in [crystals, stubs]:
		for c in holder.get_children():
			if c is MeshInstance3D:
				_hide(c)
	var r := rock_m.instantiate() as Node3D
	r.name = "Detailed Rock"
	vein.add_child(r)
	var cr := crystals_m.instantiate() as Node3D
	cr.name = "Detailed Crystals"
	crystals.add_child(cr)
	var st := stubs_m.instantiate() as Node3D
	st.name = "Detailed Stubs"
	stubs.add_child(st)
	return 1
