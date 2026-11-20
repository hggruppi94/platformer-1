extends RefCounted

# The Hot Springs' caves go somewhere now (Hayden, 20 Nov 2026: "The hot springs doorways dont actually go
# anywhere"). Behind each cave mouth (the baked spring_cave.glb, placed and turned by scripts/detail_props.gd
# _place_springs and _springs) a tunnel runs into the plateau's cliff and opens into a small warm grotto with a
# steaming pool, warm crystals and the cave's glow. Called by detail_props.gd _springs once the mouths are in, so it's
# only there with the detail pipeline on (with it off the old builder disc stays, as it was).
#   - The cliff's ground is cut away inside the mouth (scripts/ground_hole.gd: the terrain's collision, and its mesh
#     outside headless runs), between just over the floor and the tunnel's roof, so the mouth is open.
#   - The tunnel and grotto are one piece of cave_kit rock with its own floor and walls (scripts/cave_kit.gd), clipped
#     at the mouth's front so it's open there.
#   - The glow sphere and its light the builder put just inside each mouth move to the grotto's back; a second light
#     warms the grotto. The pool in the grotto copies the outside pool's water and its warm zone.
# Every size is in the cave's own frame (+z out of the cliff, y up from the mouth's spot), times the cave's size.
# Hot Springs gets metas "grotto_shapes" and "grotto_areas" (what it added: test_detail_all counts them).
# No class_name on purpose (see scripts/use_spot.gd): load it with preload.

const KIT := preload("res://scripts/cave_kit.gd")
const HOLE := preload("res://scripts/ground_hole.gd")

const TUNNEL_R := 2.2                 # inside the mouth's rock ring (2.3 round (0, 1, 0))
const TUNNEL_Y := 1.33                # its middle: the floor (0.55 of the way down) comes out at FLOOR
const FLOOR := 0.38                   # the floor, over the mouth's spot (the field's noise brings it down level with the ground)
const TUNNEL := [Vector2(2.2, -0.22), Vector2(-1.0, 0.0), Vector2(-4.6, 0.0)]  # its points (z, and how much lower:
                                      # the front dips so its floor's edge meets the ground outside without a lip)
const ROOM := Vector3(0.0, 2.1, -8.6) # the grotto's middle
const ROOM_R := Vector3(4.6, 3.0, 4.2)
const OPEN_AT := 1.35                 # no rock in front of this (the ring's front is at 1.45)
const CUTS := [Vector3(-0.4, 1.95, 0), Vector3(1.0, 0.9, 0)]  # the ground's cut away round these spots (z, how far round)
const CUT_LO := 0.22                  # from this high over the mouth's spot
const CUT_HI := 3.75                  # up to this
const POOL := Vector3(0.0, 0.0, -9.6) # the pool, on the grotto's floor
const POOL_R := 1.6
const GLOW_AT := Vector3(0.0, 0.7, -12.0)
const LIGHT_AT := Vector3(0.0, 3.0, -7.5)
const ROCK := Color(0.37, 0.34, 0.43)         # the baked mouth's rock (tools/build_prop_void_5.py CAVE_ROCK)
const FLOOR_COLOUR := Color(0.44, 0.38, 0.36)
const WARM := Color(1.0, 0.6, 0.3)


static func dig(scene: Node, g: Node3D) -> int:
	if scene == null or g == null or g.has_meta("grottos"):
		return 0
	g.set_meta("grottos", true)
	g.set_meta("hole_keep", true)                 # the cuts mustn't hide the mouths, pools and glows right beside them
	var shapes_before := g.find_children("*", "CollisionShape3D", true, false).size()
	var areas_before := g.find_children("*", "Area3D", true, false).size()
	var caves := []
	var glows := []
	var lights := []
	var pools := []
	var zones := []
	for c in g.get_children():
		var mi := c as MeshInstance3D
		if mi and mi.mesh is CylinderMesh and mi.has_meta("spring_yaw"):
			caves.append(mi)
		elif mi and mi.mesh is SphereMesh and mi.material_override and mi.material_override.resource_name == "Cave Glow":
			glows.append(mi)
		elif c is OmniLight3D:
			lights.append(c)
		elif mi and mi.material_override and mi.material_override.resource_name == "Spring Water":
			pools.append(mi)
		elif c is Area3D:
			zones.append(c)
	var n := 0
	for rock: MeshInstance3D in caves:
		var s := float(rock.get_meta("spring_scale", 1.0))
		var yaw := float(rock.get_meta("spring_yaw", 0.0))
		var spot := rock.position - Vector3(0, 1.0, 0)
		var frame := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), spot)
		var out := Vector3(sin(yaw), 0, cos(yaw))
		var holder := Node3D.new()
		holder.name = "Spring Grotto %d" % n
		g.add_child(holder)
		holder.set_meta("frame", frame)
		# Open the cliff inside the mouth, and a little in front of it too (a smaller cave stands further out from
		# the cliff, so the cliff's lip can reach into its mouth)
		for cut: Vector3 in CUTS:
			var c2 := frame * Vector3(0, 0, cut.x)
			HOLE.cut(scene, Vector2(c2.x, c2.z), cut.y * s, spot.y + CUT_LO, spot.y + CUT_HI * s)
		# The tunnel and the grotto
		var pts := []
		for t: Vector2 in TUNNEL:
			pts.append(frame * Vector3(0, TUNNEL_Y + t.y, t.x))
		var floor_y := spot.y + FLOOR * s
		var room := frame * ROOM
		var shapes := [
			{"kind": "tunnel", "points": pts, "r": TUNNEL_R * s, "floor": (TUNNEL_Y - FLOOR) / TUNNEL_R},
			{"kind": "room", "at": room, "rx": ROOM_R.x * s, "ry": ROOM_R.y * s, "rz": ROOM_R.z * s, "floor": floor_y},
		]
		var open_at := frame * Vector3(0, 0, OPEN_AT)
		var built := KIT.build(holder, shapes, {"cell": 0.5, "noise": 0.22, "seed": 40 + n, "name": "Grotto Rock",
			"rock": ROCK, "floor_colour": FLOOR_COLOUR, "clip": [Plane(out, out.dot(open_at))]})
		holder.set_meta("field", built.field)
		# The glow and its light go to the back of the grotto, and a lamp of a light warms the middle
		var glow := _nearest(glows, spot, 4.0) as Node3D
		if glow:
			glows.erase(glow)
			glow.position = frame * GLOW_AT
		var lamp := _nearest(lights, spot + out * 1.5, 4.0) as OmniLight3D
		if lamp:
			lights.erase(lamp)
			lamp.position = frame * (GLOW_AT + Vector3(0, 0.8, 1.2))
			lamp.omni_range = maxf(lamp.omni_range, 7.0)
		var warm := OmniLight3D.new()
		warm.name = "Grotto Light"
		warm.light_color = WARM
		warm.light_energy = 2.2
		warm.omni_range = 9.0 * s
		warm.shadow_enabled = false
		holder.add_child(warm)
		warm.position = frame * LIGHT_AT
		# A steaming pool in the grotto, like the one outside
		var outside := _nearest(pools, spot + out * 4.0, 6.0) as MeshInstance3D
		var at := frame * POOL
		at.y = floor_y
		if outside:
			var water := MeshInstance3D.new()
			water.name = "Grotto Pool"
			var cyl := CylinderMesh.new()
			cyl.top_radius = POOL_R * s
			cyl.bottom_radius = POOL_R * s
			cyl.height = 0.12
			water.mesh = cyl
			water.material_override = outside.material_override
			holder.add_child(water)
			water.position = at + Vector3(0, 0.07, 0)
			var zone := _nearest(zones, outside.position, 4.0) as Area3D
			if zone:
				var copy := zone.duplicate() as Area3D
				copy.name = "Grotto Warm Zone"
				holder.add_child(copy)
				copy.position = at + (zone.position - outside.position) + Vector3(0, 0.05, 0)
				copy.scale = Vector3.ONE * s
		var steam := CPUParticles3D.new()
		steam.name = "Grotto Steam"
		steam.amount = 18
		steam.lifetime = 2.6
		steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		steam.emission_sphere_radius = POOL_R * s * 0.7
		steam.direction = Vector3.UP
		steam.spread = 20.0
		steam.gravity = Vector3(0, 0.25, 0)
		steam.initial_velocity_min = 0.2
		steam.initial_velocity_max = 0.5
		steam.scale_amount_min = 0.5
		steam.scale_amount_max = 1.1
		var puff := SphereMesh.new()
		puff.radius = 0.25
		puff.height = 0.5
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_color = Color(1, 1, 1, 0.18)
		puff.material = pm
		steam.mesh = puff
		holder.add_child(steam)
		steam.position = at + Vector3(0, 0.2, 0)
		# Warm crystals round the walls
		var k := 0
		for side: float in [-1.0, 1.0]:
			var cr := KIT.crystals(holder, frame * Vector3(side * 3.4, 0.0, -8.0 - side * 1.2), WARM, 5, 60 + n * 3 + k, s)
			cr.position.y = floor_y
			cr.name = "Grotto Crystals %d" % k
			k += 1
		var back := KIT.crystals(holder, frame * Vector3(1.6, 0.0, -11.6), WARM, 6, 70 + n, 1.2 * s)
		back.position.y = floor_y
		back.name = "Grotto Crystals %d" % k
		n += 1
	g.set_meta("grotto_shapes", g.find_children("*", "CollisionShape3D", true, false).size() - shapes_before)
	g.set_meta("grotto_areas", g.find_children("*", "Area3D", true, false).size() - areas_before)
	return n


# Where the grotto's middle is, on its floor (for tests and pictures)
static func middle(holder: Node3D) -> Vector3:
	var frame: Transform3D = holder.get_meta("frame")
	var p := frame * ROOM
	p.y = (frame * Vector3(0, FLOOR, 0)).y
	return p


static func _nearest(list: Array, at: Vector3, within: float) -> Node:
	var best: Node3D = null
	var d := within
	for c: Node3D in list:
		var e := Vector2(c.position.x - at.x, c.position.z - at.z).length()
		if e < d:
			d = e
			best = c
	return best
