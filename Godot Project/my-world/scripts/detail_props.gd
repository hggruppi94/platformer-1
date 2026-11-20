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
const STANDING_STONE := "res://models/props/glenmoor/standing_stone.glb"
const CAIRN := "res://models/props/glenmoor/cairn.glb"
const SUMMIT_CAIRN := "res://models/props/glenmoor/summit_cairn.glb"
const CROFT := "res://models/props/glenmoor/croft.glb"
const GLEN_BARN := "res://models/props/glenmoor/barn.glb"
const CORAL_DOME := "res://models/props/tide_reef/coral_dome.glb"
const CORAL_TRIM := "res://models/props/tide_reef/coral_trim.glb"
const REEF_LAMP := "res://models/props/tide_reef/lamp_post.glb"
const REEF_BOAT := "res://models/props/tide_reef/boat.glb"
const DH_TREE := "res://models/props/dark_hollow/crooked_tree.glb"
const DH_LOG := "res://models/props/dark_hollow/hollow_log.glb"
const DH_LAMP := "res://models/props/dark_hollow/moon_lamp.glb"
const DH_MUSHROOMS := "res://models/props/dark_hollow/glow_mushrooms.glb"
const DH_LAMP_GLOBE := 2.6                         # the baked lamp's globe height (a moon lamp's globe)
const DH_STONE_TINT := Color(0.5, 0.48, 0.65)     # "Old Stone" over Glenmoor's "Stone" (tools/build_dark_hollow.gd)
const LM_TREE := "res://models/props/lanternmoor/lantern_tree.glb"
const LM_POST := "res://models/props/lanternmoor/lantern_post.glb"
const LM_BEACON := "res://models/props/lanternmoor/beacon.glb"
const LM_TREE_TRUNK := 3.2                        # the baked lantern tree's trunk height at scale 1
const LM_STONE_TINT := Color(0.42, 0.38, 0.55)    # Lanternmoor's standing stones, over the Glenmoor stone
const FM_PINE := "res://models/props/frozen_moment/snow_pine.glb"
const FM_CRAG := "res://models/props/frozen_moment/ice_crag.glb"
const FM_THRONE := "res://models/props/frozen_moment/frost_throne.glb"
const FM_CRAG_H := 5.0                             # the baked crag's height at scale 1 (its base radius is 1)
const CORAL_DOME_GAIN := 1.12                     # lifts the dome's pale bake back up to its coral colour
# The model standing stone's size (tools/build_prop_glenmoor.py): each one's stretched to its own builder box
const STANDING_STONE_SIZE := Vector3(1.2, 4.0, 0.8)
const STONE_DARK_TINT := Color(0.8, 0.8, 0.84)    # "Stone Dark" over "Stone" (tools/build_glenmoor.gd)
const CRYSTAL := "res://models/props/crystal.glb"
const BASKETBALL_HOOP := "res://models/props/basketball_hoop.glb"
const TENNIS_NET := "res://models/props/tennis_net.glb"
const SOCCER_GOAL := "res://models/props/soccer_goal.glb"
const ROCK_WALL := "res://models/props/rock_wall.glb"
const OLD_SLIDE := "res://models/props/old_slide.glb"
const BOARDWALK := "res://models/props/boardwalk.glb"
const BOARDWALK_PILE := "res://models/props/boardwalk_pile.glb"
const LANTERN_POST := "res://models/props/lantern_post.glb"
const MOTHERSHIP_PAD := "res://models/props/mothership_pad.glb"
const NOTICEBOARD := "res://models/props/noticeboard.glb"
const SPRING_CAVE := "res://models/props/spring_cave.glb"
const SPRING_RIM := "res://models/props/spring_rim.glb"
const BOARDWALK_LEN := 4.0             # the model's length of deck, and its width 3 (tools/build_prop_void_5.py)
const BOARDWALK_W := 3.0
const BOARDWALKS := ["Boardwalk South", "Boardwalk North", "Boardwalk East", "Dock"]
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
# The Hot Springs' caves (tools/build_town.gd): they sit on a circle round the plateau (PLATEAU, PLATEAU_CLIFF + 1.5).
# The westmost one (x -80) was where the cliff starts to turn into the ramp, so it hung 4 m up a gentle slope with its
# floor and the back of its rock sticking out: it moves along the cliff to x SPRING_WEST_X, a little smaller.
const SPRING_CENTRE := Vector2(-78.0, -42.0)
const SPRING_CIRCLE := 34.5
const SPRING_WEST := -80.0
const SPRING_WEST_X := -77.0
const SPRING_WEST_SCALE := 0.75
const SPRING_POOL := 4.0                # the pool's middle, out in front of the mouth
const SPRING_CLEAR := 4.2               # no crystal cluster this close to a mouth or a pool
const SPRING_SINK := 0.12               # the cave sits this far into the ground, so its floor's edges don't show
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
		"hoops": 0, "tennis_net": 0, "goals": 0, "rock_wall": 0, "old_slide": 0, "boardwalks": 0, "piles": 0,
		"lantern_posts": 0, "pad": 0, "noticeboard": 0, "spring_caves": 0, "spring_rims": 0}
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
	# (19 Nov 2026) the Hot Springs' caves sit square in the cliff before anything round them is dressed, and any
	# crystal cluster standing in a cave's mouth or its pool goes
	_place_springs(scene)
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
	# (19 Nov 2026, batch twelve: tools/build_prop_void_5.py): the boardwalks round the lake and the dock, Pip's
	# lantern posts, the Mothership Pad, the noticeboard by the fountain and the Hot Springs' caves
	var deck := _scene(BOARDWALK)
	var pile := _scene(BOARDWALK_PILE)
	if deck and pile:
		var bw := _boardwalks(scene, deck, _mesh_of(pile))
		out.boardwalks = bw.x
		out.piles = bw.y
	var lpost := _scene(LANTERN_POST)
	if lpost:
		out.lantern_posts = _lantern_posts(scene.get_node_or_null("Pip's Lanterns"), lpost)
	var pad := _scene(MOTHERSHIP_PAD)
	if pad:
		out.pad = _by_shape(scene.get_node_or_null("Mothership Pad"), pad, "Detailed Pad",
			func(mi: MeshInstance3D) -> bool: return _mat_name(mi) == "Pad Metal" and mi.mesh is CylinderMesh)
	var board := _scene(NOTICEBOARD)
	if board:
		out.noticeboard = _by_shape(scene.get_node_or_null("Noticeboard"), board, "Detailed Noticeboard",
			func(mi: MeshInstance3D) -> bool: return _mat_name(mi) in ["Stall Wood", "Cork"])
	var cave := _scene(SPRING_CAVE)
	var rim := _scene(SPRING_RIM)
	if cave and rim:
		var hs := _springs(scene.get_node_or_null("Hot Springs"), cave, rim)
		out.spring_caves = hs.x
		out.spring_rims = hs.y
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


static func dress_glenmoor(scene: Node) -> Dictionary:
	# Heather's glen (19 Nov 2026, the portal worlds' props, tools/build_prop_glenmoor.py): the Standing Stones, the
	# cairns up Ben Bonnie with their tartan flags, her croft and her barn with its hay bales. Only how they look
	# changes: every solid box, the markers the race and the Stormram use, and the names stay as built.
	var out := {"stones": 0, "cairns": 0, "croft": 0, "barn": 0, "hay": 0}
	var ss := _scene(STANDING_STONE)
	var ring := scene.find_child("Standing Stones", true, false) as Node3D
	if ss and ring and not ring.has_node("Detailed Stone 1"):
		for c in ring.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not (mi.mesh is BoxMesh):
				continue
			var mn := _mat_name(mi)
			if mn == "Moss":
				_hide(mi)                                  # (the model has its own collar of moss)
				continue
			if not String(mi.name).begins_with("Stone"):
				continue
			var size := (mi.mesh as BoxMesh).size
			_hide(mi)
			var m := ss.instantiate() as Node3D
			out.stones += 1
			m.name = "Detailed Stone %d" % out.stones
			# Its own lean and turn, stretched to its own height
			m.transform = mi.transform * Transform3D(Basis.from_scale(size / STANDING_STONE_SIZE), Vector3.ZERO)
			if mn == "Stone Dark":
				_tint(m, STONE_DARK_TINT)
			ring.add_child(m)
	# The cairns: a node holding a few stone balls, a pole and the "Flag" (the builder names only some of them)
	var small := _scene(CAIRN)
	var big := _scene(SUMMIT_CAIRN)
	for flag in scene.find_children("Flag", "MeshInstance3D", true, false):
		var g := flag.get_parent() as Node3D
		if g == null or g.get_script() != null or g.has_node("Detailed Cairn") or _mat_name(flag) != "Tartan":
			continue
		var balls := 0
		for c in g.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is SphereMesh:
				balls += 1
		var model := big if balls > 4 else small
		if model == null:
			continue
		out.cairns += _dress_in(g, model, "Detailed Cairn", [])
	var croft := _scene(CROFT)
	var house := scene.find_child("Heather's Croft", true, false) as Node3D
	if croft and house:
		out.croft = _dress_in(house, croft, "Detailed Croft", [])
	var barn_m := _scene(GLEN_BARN)
	var barn := scene.find_child("Barn", true, false) as Node3D
	if barn_m and barn and scene.scene_file_path.ends_with("glenmoor.tscn"):
		var bales := []
		for c in barn.get_children():
			if c is MeshInstance3D and String(c.name).begins_with("Hay Bale"):
				bales.append(c)
		out.barn = _dress_in(barn, barn_m, "Detailed Barn", bales.map(func(b): return String(b.name)))
		# Its round bales are a little fatter and shorter than Stars Hollow's (tools/build_prop_farm.py hay_bale: 1.2
		# across and 1.2 long, its axis the cylinder's)
		var hay := _scene(HAY)
		for b: MeshInstance3D in bales:
			if hay == null or b.has_node("Detailed Hay"):
				continue
			var cm := b.mesh as CylinderMesh
			_hide(b)
			var h := hay.instantiate() as Node3D
			h.name = "Detailed Hay"
			h.scale = Vector3(cm.top_radius / 0.6, cm.height / 1.2, cm.top_radius / 0.6)
			h.rotation.y = fposmod(b.position.z * 2.3, TAU)
			b.add_child(h)
			out.hay += 1
	return out


static func _has_mat(g: Node, mat_name: String) -> bool:
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) == mat_name:
			return true
	return false


static func dress_tide_reef(scene: Node) -> Dictionary:
	# Otto's reef (20 Nov 2026, tools/build_prop_tide_reef.py): every coral house's dome, door, portholes and doorstep,
	# the bubble lamps' driftwood posts and the stranded boat. A house keeps its little coral bumps and chimney, a
	# lamp its glowing bubble and light; every collision stays. The detailed dome is baked pale and wears its house's
	# coral colour, which still fades while the tide's out and blooms when it's in (scene.follow_coral).
	var out := {"houses": 0, "lamps": 0, "boat": 0}
	var dome_m := _scene(CORAL_DOME)
	var trim_m := _scene(CORAL_TRIM)
	var tinted := {}
	if dome_m and trim_m:
		for g in scene.get_children():
			if not (g is Node3D) or not String(g.name).begins_with("Coral House") or g.has_node("Detailed Dome"):
				continue
			var dome: MeshInstance3D
			for c in g.get_children():
				if c is MeshInstance3D and c.mesh is SphereMesh and absf((c.mesh as SphereMesh).radius - 2.6) < 0.01:
					dome = c
			if dome == null:
				continue
			var body := dome.material_override
			for c in g.get_children():
				if c is MeshInstance3D and (c == dome or not _mat_name(c).begins_with("Coral")):
					_hide(c)
			var s := dome.scale.x
			var d := dome_m.instantiate() as Node3D
			d.name = "Detailed Dome"
			d.scale = Vector3.ONE * s
			g.add_child(d)
			if not tinted.has(body):
				var mat: StandardMaterial3D
				for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
					mat = (mi.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.resource_name = "Detailed " + String(body.resource_name)
				tinted[body] = mat
				if scene.has_method("follow_coral"):
					scene.call("follow_coral", body, mat, CORAL_DOME_GAIN)
				else:
					mat.albedo_color = (body as StandardMaterial3D).albedo_color * CORAL_DOME_GAIN
			for mi: MeshInstance3D in d.find_children("*", "MeshInstance3D", true, false):
				mi.set_surface_override_material(0, tinted[body])
			var t := trim_m.instantiate() as Node3D
			t.name = "Detailed Trim"
			t.scale = Vector3.ONE * s
			g.add_child(t)
			out.houses += 1
	var lamp_m := _scene(REEF_LAMP)
	var lamps := scene.get_node_or_null("Bubble Lamps")
	if lamp_m and lamps and not lamps.has_node("Detailed Lamp Post 1"):
		for c in lamps.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not (mi.mesh is CylinderMesh) or absf((mi.mesh as CylinderMesh).height - 2.6) > 0.01:
				continue
			_hide(mi)
			var m := lamp_m.instantiate() as Node3D
			out.lamps += 1
			m.name = "Detailed Lamp Post %d" % out.lamps
			m.position = mi.position - Vector3(0, 1.3, 0)
			m.rotation.y = out.lamps * 2.1                   # (each one twisted its own way)
			lamps.add_child(m)
	var boat_m := _scene(REEF_BOAT)
	var boat := scene.get_node_or_null("Stranded Boat") as Node3D
	if boat_m and boat:
		out.boat = _dress_in(boat, boat_m, "Detailed Boat", [])
	return out


static func dress_dark_hollow(scene: Node) -> Dictionary:
	# The centipede's hollow (20 Nov 2026, the portal worlds' props, tools/build_prop_dark_hollow.py): its crooked
	# trees, the Hollow Log, the glowing mushroom clusters, the Hollow Run's lamp posts and the old leaning stones.
	# (The moon lamps round Hush Hill dress themselves: dark_hollow.gd moon_lamp_model.) Only how they look changes:
	# every solid trunk, the log's box, the lights and the lamps' flames stay as built.
	var out := {"trees": 0, "log": 0, "mushrooms": 0, "lamps": 0, "stones": 0}
	var tree := _scene(DH_TREE)
	if tree:
		for g in scene.find_children("*", "Node3D", true, false):
			if _is_crooked_tree(g as Node3D):
				for mi: MeshInstance3D in g.find_children("*", "MeshInstance3D", true, false):
					_hide(mi)
				var m := tree.instantiate() as Node3D
				m.name = "Detailed Tree"
				g.add_child(m)
				out.trees += 1
	var log_m := _scene(DH_LOG)
	var lg := scene.find_child("Hollow Log", true, false) as Node3D
	if log_m and lg:
		out.log = _dress_in(lg, log_m, "Detailed Log", [])
	# The mushrooms are loose stalks and caps, a cluster at a time, each cluster's caps in the next colour round
	var mush := _scene(DH_MUSHROOMS)
	var field := scene.find_child("Glow Mushrooms", true, false) as Node3D
	if mush and field and not field.has_node("Detailed Mushrooms 1"):
		var clusters := []
		var cur := []
		var cur_mat := ""
		for c in field.get_children():
			var mi := c as MeshInstance3D
			if mi == null:
				continue
			var mn := _mat_name(mi)
			if mn == "Mushroom Stalk":
				_hide(mi)
				continue
			if not mn.begins_with("Mushroom "):
				continue
			if mn != cur_mat and not cur.is_empty():
				clusters.append(cur)
				cur = []
			cur_mat = mn
			cur.append(mi)
		if not cur.is_empty():
			clusters.append(cur)
		for caps: Array in clusters:
			var mid := Vector3.ZERO
			for cap: MeshInstance3D in caps:
				mid += cap.position
				_hide(cap)
			mid /= caps.size()
			var col := ((caps[0] as MeshInstance3D).get_active_material(0) as StandardMaterial3D).albedo_color
			var m := mush.instantiate() as Node3D
			out.mushrooms += 1
			m.name = "Detailed Mushrooms %d" % out.mushrooms
			m.position = Vector3(mid.x, 0, mid.z)
			m.rotation.y = fposmod(mid.x * 1.7 + mid.z * 0.9, TAU)
			_glow_caps(m, col)
			field.add_child(m)
	# The Hollow Run's lamps: a leaning post and a glowing flame ball; the baked post goes under each flame
	var lamp := _scene(DH_LAMP)
	var run := scene.find_child("Run Lamps", true, false) as Node3D
	if lamp and run and not run.has_node("Detailed Lamp 1"):
		var flames := []
		for c in run.get_children():
			if c is MeshInstance3D:
				if _mat_name(c) == "Lamp Post":
					_hide(c)
				elif _mat_name(c) == "Lamp Flame":
					flames.append(c)
		for f: MeshInstance3D in flames:
			var m := lamp.instantiate() as Node3D
			out.lamps += 1
			m.name = "Detailed Lamp %d" % out.lamps
			var k := f.position.y / DH_LAMP_GLOBE
			m.position = Vector3(f.position.x, 0, f.position.z)
			m.scale = Vector3.ONE * k
			m.rotation.y = fposmod(f.position.x * 2.3, TAU)
			run.add_child(m)
	# The old leaning stones (taller than they're wide: Hush Hill's crown, the glade's, the spire's ring) become
	# Glenmoor's lichened standing stone stretched to each box, in the hollow's colour; the Big Hole's squat rim stays
	var ss := _scene(STANDING_STONE)
	if ss:
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if not (mi.mesh is BoxMesh) or _mat_name(mi) != "Old Stone" or mi.has_meta(OLD_META):
				continue
			var size := (mi.mesh as BoxMesh).size
			if size.y <= maxf(size.x, size.z):
				continue
			_hide(mi)
			var m := ss.instantiate() as Node3D
			out.stones += 1
			m.name = "Detailed Stone %d" % out.stones
			m.transform = mi.transform * Transform3D(Basis.from_scale(size / STANDING_STONE_SIZE), Vector3.ZERO)
			_tint(m, DH_STONE_TINT)
			mi.get_parent().add_child(m)
	return out


static func dress_lanternmoor(scene: Node) -> Dictionary:
	# Pip's moor (20 Nov 2026, the portal worlds' props, tools/build_prop_lanternmoor.py): its lantern trees (out on
	# the moor and round the Lantern Grove) and the standing stones round the Night Path's beacon. (The path's lantern
	# posts and the beacons dress themselves: lanternmoor.gd lantern_model and beacon_model.) Every trunk's collision
	# and the lights over the trees stay as built; each tree's two lantern pods keep their colours.
	var out := {"trees": 0, "stones": 0}
	var tree := _scene(LM_TREE)
	if tree:
		# Only the first tree in each group keeps its builder's name ("Lantern Tree"); the others are "@Node3D@n", so
		# they're found by what they're made of (a bark trunk and "Lantern Leaves" puffs). The Tall Lantern Tree has
		# no such leaves, so its steps stay as they are.
		for g in scene.find_children("*", "Node3D", true, false):
			var size := _lantern_tree_size(g as Node3D)
			if size <= 0.0:
				continue
			var pods := []
			for c in g.get_children():
				if c is MeshInstance3D:
					if _mat_name(c).begins_with("Pod "):
						pods.append(((c as MeshInstance3D).get_active_material(0) as StandardMaterial3D).albedo_color)
					_hide(c)
			var m := tree.instantiate() as Node3D
			m.name = "Detailed Tree"
			m.scale = Vector3.ONE * size
			var at := (g as Node3D).global_position
			m.rotation.y = fposmod(at.x * 1.3 + at.z * 2.1, TAU)
			if pods.size() >= 2:
				_glow_part(m, "PodA", pods[0], 2.4)
				_glow_part(m, "PodB", pods[1], 2.4)
			g.add_child(m)
			out.trees += 1
	var ss := _scene(STANDING_STONE)
	if ss:
		for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if not (mi.mesh is BoxMesh) or _mat_name(mi) != "Standing Stone" or mi.has_meta(OLD_META):
				continue
			var size := (mi.mesh as BoxMesh).size
			_hide(mi)
			var m := ss.instantiate() as Node3D
			out.stones += 1
			m.name = "Detailed Stone %d" % out.stones
			m.transform = mi.transform * Transform3D(Basis.from_scale(size / STANDING_STONE_SIZE), Vector3.ZERO)
			_tint(m, LM_STONE_TINT)
			mi.get_parent().add_child(m)
	return out


static func dress_frozen_moment(scene: Node) -> Dictionary:
	# Flurry's stopped moment (20 Nov 2026, the portal worlds' props, tools/build_prop_frozen_moment.py): the snowy
	# pines, the ice crags round the edge and the Frost Throne. Only how they look changes: every trunk's and crag's
	# collision, the edge's fence and the throne's slippery ice stay as built.
	var out := {"pines": 0, "crags": 0, "throne": 0}
	var pine := _scene(FM_PINE)
	var pines := scene.find_child("Pines", true, false) as Node3D
	if pine and pines and not pines.has_node("Detailed Pine 1"):
		# Each pine is a trunk and three needle and snow cones, all loose under "Pines". Its trunk sits half its
		# height up (0.8 m at size 1), which gives its size; the cones above it go with it.
		var trunks := []
		for c in pines.get_children():
			if c is MeshInstance3D:
				if _mat_name(c) == "Pine Bark":
					trunks.append(c)
				_hide(c)
		for t: MeshInstance3D in trunks:
			var sz := t.position.y / 0.8
			var m := pine.instantiate() as Node3D
			out.pines += 1
			m.name = "Detailed Pine %d" % out.pines
			m.position = Vector3(t.position.x, 0, t.position.z)
			m.scale = Vector3.ONE * sz
			m.rotation.y = fposmod(t.position.x * 1.9 + t.position.z * 0.7, TAU)
			pines.add_child(m)
	var crag := _scene(FM_CRAG)
	var edge := scene.find_child("Ice Crags", true, false) as Node3D
	if crag and edge and not edge.has_node("Detailed Crag 1"):
		var cones := []
		for c in edge.get_children():
			if not (c is MeshInstance3D):
				continue
			var mn := _mat_name(c)
			if mn == "Crag Snow":
				_hide(c)
			elif mn == "Crag Ice" and (c as MeshInstance3D).mesh is CylinderMesh:
				cones.append(c)
				_hide(c)
		for c: MeshInstance3D in cones:
			var cm := c.mesh as CylinderMesh
			var m := crag.instantiate() as Node3D
			out.crags += 1
			m.name = "Detailed Crag %d" % out.crags
			m.position = c.position - Vector3(0, cm.height / 2.0, 0)
			m.rotation.y = c.rotation.y
			m.scale = Vector3(cm.bottom_radius, cm.height / FM_CRAG_H, cm.bottom_radius)
			edge.add_child(m)
	var throne := _scene(FM_THRONE)
	var th := scene.find_child("Frost Throne", true, false) as Node3D
	if throne and th:
		out.throne = _dress_in(th, throne, "Detailed Throne", [])
	return out


static func _lantern_tree_size(g: Node3D) -> float:
	# A lantern tree (tools/build_lanternmoor.gd _tree) is a node of plain meshes with a bark trunk 3.2 m tall at size
	# 1; its size from that trunk, or 0 if it isn't one (or it's already dressed)
	if g == null or g is MeshInstance3D or g.has_node("Detailed Tree") or g.get_script() != null:
		return 0.0
	var leafy := false
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) == "Lantern Leaves":
			leafy = true
	if not leafy:
		return 0.0
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) == "Bark" and (c as MeshInstance3D).mesh is CylinderMesh:
			var h := ((c as MeshInstance3D).mesh as CylinderMesh).height
			if h < 6.0:
				return h / LM_TREE_TRUNK
	return 0.0


static func _glow_part(model: Node, prefix: String, c: Color, energy := 1.3) -> void:
	# A part baked pale with a glow map takes colour c and glows in it
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).begins_with(prefix):
			continue
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat:
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = c
				copy.emission_enabled = true
				copy.emission = c
				copy.emission_energy_multiplier = energy
				mi.set_surface_override_material(i, copy)


static func lanternmoor_part(path: String) -> Node3D:
	# A baked Night Path lantern post or beacon for lanternmoor.gd, or null if detailed props are off
	if not on():
		return null
	var m := _scene(path)
	return m.instantiate() as Node3D if m else null


static func _is_crooked_tree(g: Node3D) -> bool:
	# A crooked tree (tools/build_dark_hollow.gd _dead_tree) holds its bark trunk and some branch nodes with bark in
	# them; a branch holds only bark.
	if g == null or g.has_node("Detailed Tree") or g.get_script() != null:
		return false
	var bark := false
	var branches := false
	for c in g.get_children():
		if c is MeshInstance3D and _mat_name(c) == "Crooked Bark":
			bark = true
		elif c is Node3D and not (c is MeshInstance3D) and c.get_child_count() > 0 \
				and c.get_child(0) is MeshInstance3D and _mat_name(c.get_child(0)) == "Crooked Bark":
			branches = true
	return bark and branches


static func _glow_caps(model: Node, c: Color) -> void:
	# The cluster's caps are baked pale with a glow map; they take the old caps' colour and glow in it. Stalks stay.
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).begins_with("Caps"):
			continue
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_active_material(i) as StandardMaterial3D
			if mat:
				var copy := mat.duplicate() as StandardMaterial3D
				copy.albedo_color = c
				copy.emission_enabled = true
				copy.emission = c
				copy.emission_energy_multiplier = 1.3
				mi.set_surface_override_material(i, copy)


static func moon_lamp_post() -> Node3D:
	# The baked iron post for a moon lamp round Hush Hill (dark_hollow.gd moon_lamp_model), or null if it's off
	if not on():
		return null
	var lamp := _scene(DH_LAMP)
	return lamp.instantiate() as Node3D if lamp else null


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


# ----------------------------------------------------------------------------- batch twelve (19 Nov 2026)
static func _multi(parent: Node3D, mesh: Mesh, xfs: Array, name: String) -> void:
	# Many copies of one baked mesh in one draw. A MultiMesh keeps nothing in a headless run, so the places are in
	# its meta "transforms" too (for tests).
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm
	mmi.set_meta("transforms", xfs)
	mmi.visibility_range_end = 160.0
	parent.add_child(mmi)


static func _boardwalks(scene: Node, deck: PackedScene, pile: Mesh) -> Vector2i:
	# Each boardwalk (tools/build_town.gd boardwalk()): one plank box 0.3 deep from a to b, and a pile each side every
	# 4 m or so (cylinders 2 m tall, 0.7 down). The deck becomes whole 4 m lengths of the detailed one, stretched a
	# little to fit (and squeezed for the narrower dock); the piles are one MultiMesh. The deck's collision, its lamp
	# posts (already detailed: _void_lamps) and their glowing bulbs stay.
	var out := Vector2i.ZERO
	if pile == null:
		return out
	for gname: String in BOARDWALKS:
		var g := scene.get_node_or_null(gname) as Node3D
		if g == null or g.get_script() != null or g.has_node("Detailed Boardwalk"):
			continue
		var piles := []
		var holder: Node3D = null
		for c in g.get_children():
			var mi := c as MeshInstance3D
			if mi == null or mi.has_meta(OLD_META):
				continue
			# (the long east one is wide enough, turned, to have been given the ground's look: WorldDetail)
			if mi.mesh is BoxMesh and _mat_name(mi) in ["Boardwalk", "Ground Detail"] \
					and is_equal_approx((mi.mesh as BoxMesh).size.y, 0.3):
				var size := (mi.mesh as BoxMesh).size
				holder = Node3D.new()
				holder.name = "Detailed Boardwalk"
				holder.position = mi.position - Vector3(0, size.y / 2.0, 0)
				holder.rotation = mi.rotation
				var n := maxi(1, roundi(size.z / BOARDWALK_LEN))
				var stretch := size.z / (n * BOARDWALK_LEN)
				for k in n:
					var m := deck.instantiate() as Node3D
					m.name = "Length %d" % k
					m.position = Vector3(0, 0, -size.z / 2.0 + (k + 0.5) * size.z / n)
					m.scale = Vector3(size.x / BOARDWALK_W, 1, stretch)
					holder.add_child(m)
				_hide(mi)
				out.x += 1
			elif mi.mesh is CylinderMesh and _mat_name(mi) == "Boardwalk Post" \
					and is_equal_approx((mi.mesh as CylinderMesh).height, 2.0):
				var base := mi.position + Vector3(0, 0.7, 0)
				piles.append(Transform3D(Basis(Vector3.UP, fposmod(base.x * 1.3 + base.z * 0.7, TAU)), base))
				_hide(mi)
		if holder:
			g.add_child(holder)
		if piles.size() > 0:
			_multi(g, pile, piles, "Detailed Piles")
			out.y += piles.size()
	return out


static func _lantern_posts(g: Node3D, model: PackedScene) -> int:
	# Pip's lanterns (tools/build_town.gd, "Pip's Lanterns"): a post (a cylinder 2.4 tall, 1.4 up from the deck) and
	# a little arm on top, the lantern hanging a quarter of a metre off it. The detailed post's arm reaches along its
	# +X to a hook over the lantern, so each turns towards its own. The lanterns (lit or not, the quest's) stay.
	if g == null or g.get_script() != null or g.has_node("Detailed Lantern Post 0"):
		return 0
	var hangs := []
	for node in g.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh is SphereMesh and String(mi.get_parent().name).begins_with("Unlit Lantern"):
			hangs.append(mi.position)
	var n := 0
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.has_meta(OLD_META) or _mat_name(mi) != "Boardwalk Post":
			continue
		if mi.mesh is BoxMesh:
			_hide(mi)
			continue
		if not (mi.mesh is CylinderMesh and is_equal_approx((mi.mesh as CylinderMesh).height, 2.4)):
			continue
		var base := mi.position - Vector3(0, 1.4, 0)
		var to := Vector3.ZERO
		for h: Vector3 in hangs:
			var d := Vector3(h.x - base.x, 0, h.z - base.z)
			if d.length() < 0.6 and (to == Vector3.ZERO or d.length() < to.length()):
				to = d
		var m := model.instantiate() as Node3D
		m.name = "Detailed Lantern Post %d" % n
		m.position = base
		m.rotation.y = atan2(-to.z, to.x) if to != Vector3.ZERO else 0.0
		g.add_child(m)
		_hide(mi)
		n += 1
	return n


static func _by_shape(g: Node3D, model: PackedScene, name: String, old: Callable) -> int:
	# A landmark whose detailed model is built in its own group's frame (the Mothership Pad, the noticeboard): the
	# pieces old() picks stop being drawn and the model goes in. Everything else (the pad's glowing rings, the
	# notes, every collision, area, sign and quest spot) stays.
	if g == null or g.get_script() != null or g.has_node(name):
		return 0
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi and not mi.has_meta(OLD_META) and old.call(mi):
			_hide(mi)
	var m := model.instantiate() as Node3D
	m.name = name
	g.add_child(m)
	return 1


static func _place_springs(scene: Node) -> int:
	# The Hot Springs (tools/build_town.gd) are three caves in the plateau's south cliff, each a rock disc (3.2
	# across, 1 m up from its spot) with a dark disc on it, a glow inside, its light, and a steaming pool 4 m out in
	# front (a disc 2.2 across with its warm zone). The builder faced them all straight south, but the cliff curves
	# round, so the eastern ones stuck out of it on one side and sank into it on the other; and the western one hung
	# up a gentle slope. Each cave turns to face straight out from the cliff, sits down on the ground its pool is on,
	# and takes its glow, light and pool with it (the westmost moves along the cliff, see SPRING_WEST). Crystal
	# clusters standing in a mouth or a pool go. Done once; the rock disc keeps its new turn and size in metas for
	# _springs. Returns how many caves were placed.
	var g := scene.get_node_or_null("Hot Springs") as Node3D
	if g == null or g.get_script() != null or g.has_meta("springs_placed"):
		return 0
	g.set_meta("springs_placed", true)
	var sets := {}                       # the cave's old x (rounded) -> its pieces
	for c in g.get_children():
		var n3 := c as Node3D
		if n3 == null or n3.name == "Sign":
			continue
		var key := roundi(n3.position.x)
		if not sets.has(key):
			sets[key] = {"rock": null, "pieces": [], "pool": []}
		var mi := c as MeshInstance3D
		if mi and mi.mesh is CylinderMesh and _mat_name(mi) == "Cave Rock" and is_equal_approx((mi.mesh as CylinderMesh).top_radius, 3.2):
			sets[key].rock = mi
			sets[key].pieces.append(mi)
		elif (mi and _mat_name(mi) == "Spring Water") or c is Area3D:
			sets[key].pool.append(n3)
		elif mi or c is Light3D:
			sets[key].pieces.append(n3)
	var spots := []
	for key in sets:
		var st: Dictionary = sets[key]
		var rock := st.rock as MeshInstance3D
		if rock == null:
			continue
		var p := rock.position - Vector3(0, 1.0, 0)
		var ground := p.y
		for q in st.pool:
			if q is MeshInstance3D:
				ground = (q as Node3D).position.y - 0.05
		var to := p
		var size := 1.0
		if is_equal_approx(p.x, SPRING_WEST):
			to.x = SPRING_WEST_X
			size = SPRING_WEST_SCALE
		var dx := to.x - SPRING_CENTRE.x
		to.z = SPRING_CENTRE.y + sqrt(maxf(SPRING_CIRCLE * SPRING_CIRCLE - dx * dx, 0.0))
		to.y = ground - SPRING_SINK
		var yaw := atan2(dx, to.z - SPRING_CENTRE.y)
		var face := Vector3(sin(yaw), 0, cos(yaw))
		# old spot -> new spot, turned to face out from the cliff
		var t := Transform3D(Basis(Vector3.UP, yaw), to) * Transform3D(Basis.IDENTITY, -p)
		for n3: Node3D in st.pieces:
			n3.transform = t * n3.transform
		var pool := to + face * SPRING_POOL
		for q: Node3D in st.pool:
			q.position = Vector3(pool.x, q.position.y, pool.z)
		rock.set_meta("spring_yaw", yaw)
		rock.set_meta("spring_scale", size)
		spots.append(to + face * 1.2)
		spots.append(pool)
	var crystals := scene.get_node_or_null("Crystals")
	var cleared := 0                     # the crystals' collisions that went with them (tests read the meta)
	if crystals:
		for cl in crystals.get_children():
			var c3 := cl as Node3D
			if c3 == null:
				continue
			for at: Vector3 in spots:
				if Vector2(c3.position.x - at.x, c3.position.z - at.z).length() < SPRING_CLEAR:
					cleared += c3.find_children("*", "CollisionShape3D", true, false).size()
					crystals.remove_child(c3)
					c3.free()
					break
	g.set_meta("springs_cleared_shapes", cleared)
	return spots.size() / 2


static func _springs(g: Node3D, cave: PackedScene, rim: PackedScene) -> Vector2i:
	# The Hot Springs (placed by _place_springs first): each cave becomes the detailed mouth, open now so the glow
	# inside shows, turned and sized as placed, and each pool gets a ring of stones. The glow, its light, the water
	# and the warm zone stay.
	var out := Vector2i.ZERO
	if g == null or g.get_script() != null or g.has_node("Detailed Spring Cave 0"):
		return out
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.has_meta(OLD_META) or not (mi.mesh is CylinderMesh):
			continue
		var cm := mi.mesh as CylinderMesh
		if _mat_name(mi) == "Cave Rock" and is_equal_approx(cm.top_radius, 3.2):
			var m := cave.instantiate() as Node3D
			m.name = "Detailed Spring Cave %d" % out.x
			var s := float(mi.get_meta("spring_scale", 1.0))
			m.transform = Transform3D(Basis(Vector3.UP, float(mi.get_meta("spring_yaw", 0.0))).scaled_local(Vector3.ONE * s),
				mi.position - Vector3(0, 1.0, 0))
			g.add_child(m)
			_hide(mi)
			out.x += 1
		elif _mat_name(mi) == "Cave" and is_equal_approx(cm.top_radius, 2.4):
			_hide(mi)
		elif _mat_name(mi) == "Spring Water" and is_equal_approx(cm.top_radius, 2.2):
			var m := rim.instantiate() as Node3D
			m.name = "Detailed Spring Rim %d" % out.y
			m.position = mi.position - Vector3(0, 0.05, 0)
			m.rotation.y = out.y * 1.3
			g.add_child(m)
			out.y += 1
	return out


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


# ----------------------------------------------------------------------------- nature (19 Nov 2026)
# Trees and plants are MultiMeshes (thousands of copies, each with its own place and colour), so nothing is hidden or
# added here: each MultiMesh just gets the baked shape (tools/build_prop_nature.py, sized to the shape it replaces) and
# its maps. The maps are baked pale and each copy keeps its own colour on top, so seasons, glows and the builders'
# colours carry on. `NATURE_GAIN` brings each baked tint's middle back to 1 (its mean in linear light, measured).
const NATURE := "res://models/props/nature/%s.glb"
const NATURE_GAIN := {"bark_trunk": 1.83, "bark_limb": 1.7, "leaf_ball": 2.0, "void_orb": 2.0, "void_spire": 1.2,
	"void_stalk": 1.36, "mushroom_cap": 1.19, "mushroom_stem": 1.29, "giant_leaf": 1.4}     # (leaves held to 2)
const NATURE_META := "detail_nature"   # on each MultiMeshInstance3D given a baked shape: which model


static func dress_nature(scene: Node) -> Dictionary:
	# The Void's trees (scenes/town/trees.gd), its giant leaves and mushrooms (scenes/town/foliage.gd) and Stars
	# Hollow's autumn trees (tools/build_earth.gd _flush_trees). Returns how many MultiMeshes got each model.
	var out := {}
	if scene == null:
		return out
	for mmi: MultiMeshInstance3D in scene.find_children("*", "MultiMeshInstance3D", true, false):
		if mmi.has_meta(NATURE_META) or mmi.multimesh == null:
			continue
		var owner_script: Script = mmi.get_parent().get_script() if mmi.get_parent() else null
		var from := owner_script.resource_path.get_file() if owner_script else ""
		var kind := ""
		var swap_mesh := true
		match [from, String(mmi.name)]:
			["trees.gd", "Canopies"]:
				kind = "void_orb"
			["trees.gd", "Spires"]:
				kind = "void_spire"
			["trees.gd", "Trunks"]:
				kind = "void_stalk"
			["foliage.gd", "Caps"]:
				kind = "mushroom_cap"
			["foliage.gd", "Stems"]:
				kind = "mushroom_stem"
			["foliage.gd", "Leaves"]:
				kind = "giant_leaf"
				swap_mesh = false          # the leaf's own curved blade stays; the bake is laid on its UVs
			[_, "Tree Trunk"]:
				kind = "bark_trunk"
			[_, "Tree Branch"]:
				kind = "bark_limb"
			[_, "Tree Leaves"]:
				kind = "leaf_ball"
		if kind == "" or (kind.begins_with("bark") or kind == "leaf_ball") and mmi.get_parent().name != "Autumn Trees":
			continue
		var model := _scene(NATURE % kind)
		if model == null:
			continue
		var mesh := _mesh_of(model)
		var baked := mesh.surface_get_material(0) as StandardMaterial3D if mesh else null
		if baked == null:
			continue
		var gain: float = NATURE_GAIN.get(kind, 1.0)
		var old := mmi.material_override
		if old is ShaderMaterial:
			var mat := (old as ShaderMaterial).duplicate() as ShaderMaterial
			mat.set_shader_parameter("detailed", true)
			mat.set_shader_parameter("detail_tint", baked.albedo_texture)
			mat.set_shader_parameter("detail_normal", baked.normal_texture)
			mat.set_shader_parameter("detail_orm", baked.ao_texture)
			mat.set_shader_parameter("detail_gain", gain)
			mmi.material_override = mat
		elif old is StandardMaterial3D:
			# The bark: the baked material, in the old one's colour (the Void's) or each copy's (Stars Hollow's)
			var was := old as StandardMaterial3D
			var mat := baked.duplicate() as StandardMaterial3D
			mat.resource_name = "Detailed " + kind
			mat.vertex_color_use_as_albedo = was.vertex_color_use_as_albedo
			var c := was.albedo_color * gain
			mat.albedo_color = Color(c.r, c.g, c.b, 1.0)
			mat.emission_enabled = was.emission_enabled
			mat.emission = was.emission
			mat.emission_energy_multiplier = was.emission_energy_multiplier
			mmi.material_override = mat
		else:
			continue
		if swap_mesh:
			mmi.multimesh.mesh = mesh
		mmi.set_meta(NATURE_META, kind)
		out[kind] = int(out.get(kind, 0)) + 1
	return out


# ----------------------------------------------------------------------------- building outsides (19 Nov 2026)
# Walls and roofs are far too big, and come in far too many sizes, to bake whole, so they get TILING detail instead
# (tools/build_prop_surfaces.py): a patch of siding, shingles, brick, stone, barn boards or dome scales, modelled in
# full and baked onto a square that repeats. Nothing is added or hidden: each wall and roof material is swapped for a
# copy with the patch's maps, in its own colour (the patch is baked pale; `SURFACE_GAIN` lifts its middle back to 1),
# keeping its name so the seasons still snow on the roofs. Box walls and prism roofs have no UVs worth using, so the
# patch is laid on in the mesh's own space (triplanar, `SURFACE_TILE` metres a patch); the Void's round domes use their
# sphere's UVs, so the scales follow the dome round and up.
const SURFACE := "res://models/props/surfaces/%s.glb"
const SURFACE_TILE := {"clapboard": 2.0, "shingles": 2.0, "brick": 1.2, "stone": 2.4, "barn_boards": 2.0,
	"dome_scales": 1.6, "bark": 1.6, "rock": 3.0, "ice": 3.0, "snow": 3.0, "coral": 1.2, "metal_panel": 2.0,
	"drystone": 2.0}
const SURFACE_GAIN := {"clapboard": 1.38, "shingles": 1.62, "brick": 2.07, "stone": 1.58, "barn_boards": 1.56,
	"dome_scales": 1.31, "bark": 1.8, "rock": 1.51, "ice": 1.15, "snow": 1.11, "coral": 1.8, "metal_panel": 1.57,
	"drystone": 2.0}
# The portal worlds' natural stuff (batch fifteen) is only patched in a portal world, so a "Stone" or a "Snow" in the
# towns is left alone. Their rocks, trunks and crags are scaled and turned every which way by the builders, so these
# lay the patch on in the world's space, which keeps every piece's patch the same size.
const PORTAL_SURFACES := {
	"bark": ["Crooked Bark", "Pine Bark", "Bark", "Mangrove Bark", "Root", "Root Wall"],
	"rock": ["Old Stone", "Spire Rock", "Shard Rock", "Reef Rock", "Reef Rock Pale", "Reef Rock Dark", "Wet Rock",
		"Wet Rock Dark", "Standing Stone", "Moon Stone", "Path Stone"],
	"ice": ["Crag Ice", "Icicle", "Slide Ice", "Cave Ice", "Throne Ice", "Lake Ice"],
	"snow": ["Snow", "Crag Snow", "Drift Snow", "Snow Cap"],
	"metal_panel": ["Lab Wall", "Skyway Deck", "Pillar", "Lab Floor"],
	"drystone": ["Stone", "Stone Dark"],
}
const WORLD_SPACE_SURFACES := ["bark", "rock", "ice", "snow", "coral", "drystone"]
const SURFACE_META := "detail_surface"   # on each swapped material: which patch


static func surface_of(mat_name: String, portal := false) -> String:
	# Which patch a builder material gets ("" for none); `portal` for a portal world's own
	if portal:
		if mat_name.begins_with("Coral "):
			return "coral"
		for kind in PORTAL_SURFACES:
			if mat_name in PORTAL_SURFACES[kind]:
				return kind
		return ""
	if mat_name in ["Wall Fire Station", "Wall School"]:
		return "brick"
	if mat_name in ["Wall Library", "Library Stone", "Dome Trim"]:
		return "stone"
	if mat_name == "Barn Red":
		return "barn_boards"
	if mat_name.begins_with("Dome ("):
		return "dome_scales"
	if mat_name.begins_with("Roof ") or mat_name in ["Steeple Roof", "Barn Roof"]:
		return "shingles"
	if mat_name.begins_with("Wall ") and mat_name != "Wall Inside" or mat_name == "Steeple":
		return "clapboard"
	return ""


static func dress_buildings(scene: Node) -> Dictionary:
	# Every builder wall and roof in the place (Stars Hollow's houses, shops, steeples and barn; the Void's domes and
	# their trims). Returns how many meshes got each patch.
	var out := {}
	if scene == null:
		return out
	var made := {}                         # [old material, key] -> the detailed copy, so copies are shared
	made["portal"] = scene.scene_file_path.begins_with("res://scenes/portal_worlds/")
	for node in scene.find_children("*", "GeometryInstance3D", true, false):
		if node is CSGShape3D:
			# A combiner has no material of its own (its children are found by themselves)
			var cm = node.get("material")
			if cm is StandardMaterial3D:
				var m := _surface_mat(cm, null, made)
				if m:
					node.set("material", m)
					_count(out, m)
			continue
		if not node is MeshInstance3D:
			continue
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var changed := false
		if mi.material_override is StandardMaterial3D:
			var m := _surface_mat(mi.material_override, mi.mesh, made)
			if m:
				mi.material_override = m
				_count(out, m)
				changed = true
		else:
			for k in mi.mesh.get_surface_count():
				var sm := mi.get_surface_override_material(k)
				if sm == null:
					sm = mi.mesh.surface_get_material(k)
				if sm is StandardMaterial3D:
					var m := _surface_mat(sm, mi.mesh, made)
					if m:
						mi.set_surface_override_material(k, m)
						_count(out, m)
						changed = true
		# A roof turned within its building (the barn's) would have its courses running the wrong way once merged into
		# the building's space, so it keeps its own (a name keeps scripts/static_batch.gd off it)
		if changed and String(mi.name).begins_with("@") and absf(mi.basis.z.normalized().z) < 0.9:
			mi.name = "Detailed Surface"
	# A place that keeps its own copies of colours to change later (the Tide Reef's corals fade and bloom with the tide)
	# is told which copy each one became, or it would go on changing a material nothing wears any more
	if scene.has_method("surface_swapped"):
		for key in made:
			if key is Array:
				var nm: StandardMaterial3D = made[key]
				scene.call("surface_swapped", key[0], nm, float(SURFACE_GAIN[nm.get_meta(SURFACE_META)]))
	var seasons := scene.get_node_or_null("Seasons")
	if seasons and seasons.has_method("take_in") and not out.is_empty():
		seasons.call("take_in", scene)
	return out


static func _count(out: Dictionary, m: Material) -> void:
	var kind: String = m.get_meta(SURFACE_META)
	out[kind] = int(out.get(kind, 0)) + 1


static func _surface_mat(old: StandardMaterial3D, mesh: Mesh, made: Dictionary) -> StandardMaterial3D:
	if old.has_meta(SURFACE_META):
		return null
	var kind := surface_of(old.resource_name, made.get("portal", false))
	if kind == "" or old.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var tile: float = SURFACE_TILE[kind]
	var uv := Vector3.ONE
	if kind == "dome_scales":
		if not mesh is SphereMesh:
			return null
		# Round the dome and from pole to pole, a whole number of patches so the seam closes
		var r := (mesh as SphereMesh).radius
		uv = Vector3(maxf(1.0, roundf(TAU * r / tile)), maxf(1.0, roundf(PI * r / tile)), 1.0)
	var key := [old, uv]
	if made.has(key):
		return made[key]
	var model := _scene(SURFACE % kind)
	var baked_mesh := _mesh_of(model) if model else null
	var baked := baked_mesh.surface_get_material(0) as StandardMaterial3D if baked_mesh else null
	if baked == null:
		return null
	var m := old.duplicate() as StandardMaterial3D
	m.albedo_texture = baked.albedo_texture
	var c := old.albedo_color * float(SURFACE_GAIN[kind])
	m.albedo_color = Color(c.r, c.g, c.b, 1.0)
	m.normal_enabled = true
	m.normal_texture = baked.normal_texture
	m.ao_enabled = true
	m.ao_texture = baked.ao_texture
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.6
	m.roughness_texture = baked.ao_texture
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = 1.0
	m.texture_repeat = true
	if kind == "dome_scales":
		m.uv1_scale = uv
	else:
		m.uv1_triplanar = true
		m.uv1_world_triplanar = kind in WORLD_SPACE_SURFACES
		m.uv1_triplanar_sharpness = 6.0
		m.uv1_scale = Vector3.ONE / tile
	m.set_meta(SURFACE_META, kind)
	made[key] = m
	return m
