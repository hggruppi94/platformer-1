extends Node3D

# The seasons in Stars Hollow (Earth's calendar: scripts/clock.gd). scripts/earth_town.gd puts one of these in the
# Earth scene when it loads. The town is built for autumn (tools/build_earth.gd), so autumn is the town as built, and
# for the other seasons this changes what's already there rather than building anything new:
# - the trees' leaves (the "Tree Leaves" MultiMesh, coloured per instance): fresh green with pink and white blossom
#   in spring, deep green in summer, orange and red in autumn, and in winter most are gone and the rest are snow
#   sitting on the branches,
# - the fallen leaves on the ground: little flowers dotted in the grass in spring, gone in summer, snow drifts in winter,
# - the ground and the countryside (scripts/earth_land.gd recolor()), the town green and the far hills,
# - in winter, snow on every roof, and Willow Pond iced over (to look at: it's still water underneath),
# - the Halloween dressing (jack-o'-lanterns, hay bales, scarecrows, cornstalks, sheet ghosts) only in autumn,
# - in summer, sunflowers where the pumpkins and scarecrows stood (the patch is the Sunflower Field), bright sunny
#   string lights and bunting, Willow Pond a clear sparkly blue with no mist over it (its beach and the quest
#   "Summer Splash" are scripts/summer_splash.gd), and the sun's high and bright (scripts/earth_world.gd),
# - and something in the air round the player outdoors: snow in winter, petals in spring, leaves in autumn, dandelion
#   fluff on summer days and fireflies on summer nights.
# It checks every in-game hour, so the town changes at midnight on the first day of a season.

const SNOW := Color(0.88, 0.91, 0.97)
const LEAVES := {
	"spring": [Color(0.55, 0.8, 0.35), Color(0.45, 0.72, 0.3), Color(1.0, 0.72, 0.82), Color(0.98, 0.95, 0.96),
		Color(0.62, 0.84, 0.4), Color(1.0, 0.62, 0.76)],
	"summer": [Color(0.25, 0.55, 0.2), Color(0.32, 0.62, 0.25), Color(0.2, 0.45, 0.18), Color(0.38, 0.6, 0.22)],
}
const FLOWERS := [Color(1.0, 0.95, 0.4), Color(0.98, 0.98, 1.0), Color(1.0, 0.6, 0.78), Color(0.7, 0.6, 1.0)]
const GREEN := {"spring": Color(0.45, 0.66, 0.3), "summer": Color(0.33, 0.55, 0.22), "winter": Color(0.84, 0.87, 0.93)}
const HILLS := {
	"spring": [Color(0.5, 0.7, 0.35), Color(0.62, 0.74, 0.4), Color(0.85, 0.7, 0.8), Color(0.42, 0.6, 0.3)],
	"summer": [Color(0.28, 0.5, 0.22), Color(0.35, 0.56, 0.24), Color(0.75, 0.66, 0.32), Color(0.24, 0.42, 0.2)],
	"winter": [Color(0.88, 0.91, 0.97), Color(0.8, 0.84, 0.92), Color(0.92, 0.94, 0.98), Color(0.7, 0.72, 0.8)],
}
const ROOF_SNOW := 0.8                   # how far a roof's colour goes to white in winter
const AIR_SIZE := Vector3(36, 1, 36)     # the box round the player that snow, petals or leaves fall from

var season := ""                         # the one the town's showing now
var _mats := {}                          # resource_name -> [materials]
var _albedo := {}                        # material -> its colour as built
var _leaves: MultiMeshInstance3D
var _leaf_xf: Array[Transform3D] = []
var _leaf_cols: Array[Color] = []
var _fallen: MultiMeshInstance3D
var _fallen_xf: Array[Transform3D] = []
var _fallen_cols: Array[Color] = []
var _dressing: Node3D
var _pumpkins: Array[Node3D] = []        # pumpkins, jack-o'-lanterns and scarecrows outside the Autumn Dressing
var _patch_sign: Label3D
var _snowmen: Node3D                     # winter's: where the pumpkins and scarecrows were (summer's sunflowers too)
var _mist: Array[Node3D] = []            # the thin mist over Willow Pond (a Halloween-y touch: gone in summer)
var _bulbs: MultiMeshInstance3D          # the string lights and bunting: Halloween colours, Christmassy in winter, sunny in summer
var _bulb_cols: Array[Color] = []
var _bunting: MultiMeshInstance3D
var _bunting_cols: Array[Color] = []
var _land: Node
var _air: CPUParticles3D
var _air_kind := ""
var _check := 0.0
var shown_leaves: Array[Color] = []      # what the trees' leaves and the fallen leaves are showing (for the tests)
var shown_leaf_sizes: Array[float] = []
var shown_fallen: Array[Color] = []
var shown_fallen_sizes: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var scene := get_parent()
	_land = scene.find_child("Ground", true, false)
	if _land and not _land.has_method("recolor"):
		_land = null
	if _land == null:
		for n in scene.find_children("*", "StaticBody3D", true, false):
			if n.has_method("recolor"):
				_land = n
				break
	_leaves = scene.find_child("Tree Leaves", true, false) as MultiMeshInstance3D
	_fallen = scene.find_child("Fallen Leaves", true, false) as MultiMeshInstance3D
	_dressing = scene.find_child("Autumn Dressing", true, false) as Node3D
	for pair in [[_leaves, _leaf_xf, _leaf_cols], [_fallen, _fallen_xf, _fallen_cols]]:
		var mmi := pair[0] as MultiMeshInstance3D
		if mmi and mmi.multimesh:
			# (its own copy: the scene's MultiMesh is shared with every other load of the town)
			# The instances as built come from the builder's saved copy (scripts/multi_fill.gd), not from the MultiMesh,
			# which keeps them in the renderer (and a headless run, like the tests, has none)
			var old := mmi.multimesh
			var mm := MultiMesh.new()
			mm.transform_format = old.transform_format
			mm.use_colors = old.use_colors
			mm.mesh = old.mesh
			mmi.multimesh = mm
			var xf: PackedFloat32Array = mmi.get("transforms") if "transforms" in mmi else PackedFloat32Array()
			var cols: PackedColorArray = mmi.get("colors") if "colors" in mmi else PackedColorArray()
			for i in xf.size() / 12:
				var k := i * 12
				(pair[1] as Array).append(Transform3D(Vector3(xf[k], xf[k + 1], xf[k + 2]), Vector3(xf[k + 3], xf[k + 4], xf[k + 5]),
					Vector3(xf[k + 6], xf[k + 7], xf[k + 8]), Vector3(xf[k + 9], xf[k + 10], xf[k + 11])))
				(pair[2] as Array).append(cols[i] if i < cols.size() else Color.WHITE)
			mmi.multimesh.instance_count = (pair[1] as Array).size()
	_collect_materials(scene)
	_collect_autumn_bits(scene)
	_make_air()
	apply(Clock.season())


func _collect_materials(scene: Node) -> void:
	# Every material the town's made of that the seasons change, by name, as its own copy for this load
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override is StandardMaterial3D:
			m.material_override = _own(m.material_override as StandardMaterial3D)
		if m.mesh:
			for k in m.mesh.get_surface_count():
				var sm := m.get_surface_override_material(k)
				if sm == null:
					sm = m.mesh.surface_get_material(k)
				if sm is StandardMaterial3D and _wanted(sm.resource_name):
					m.set_surface_override_material(k, _own(sm as StandardMaterial3D))


func _wanted(n: String) -> bool:
	return n.begins_with("Roof ") or n.begins_with("Porch Roof ") or n in ["Gazebo Roof", "Barn Roof", "Play Roof",
		"Steeple Roof", "Town Green", "Pond Water", "Lily Pad", "Lily Flower"] or n.begins_with("Far Hill ") \
		or n.begins_with("Leaves ")


func _own(m: StandardMaterial3D) -> StandardMaterial3D:
	if not _wanted(m.resource_name):
		return m
	for have in _mats.get(m.resource_name, []):
		if _albedo.has(have) and have.get_meta("from", null) == m:
			return have
	var copy := m.duplicate() as StandardMaterial3D
	copy.set_meta("from", m)
	_albedo[copy] = {"albedo": m.albedo_color, "rough": m.roughness, "transparency": m.transparency}
	if not _mats.has(m.resource_name):
		_mats[m.resource_name] = []
	_mats[m.resource_name].append(copy)
	return copy


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 1.0
		var s := Clock.season()
		if s != season:
			apply(s)
	_follow_air()


# -----------------------------------------------------------------------------
# Changing the town
# -----------------------------------------------------------------------------
func apply(new_season: String) -> void:
	season = new_season
	if _land:
		_land.call("recolor", season)
	_paint_trees()
	_paint_fallen()
	_paint_materials()
	_dress(season == "autumn")
	_dress_rest()
	_paint_lights()
	_set_air()


func hide_leaf(i: int) -> void:
	# A tree that's left out because it would grow through something (scripts/plant_clearance.gd): its leaves stay
	# gone whatever the season
	if i >= 0 and i < _leaf_xf.size():
		_leaf_xf[i] = Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
		if _leaves and _leaves.multimesh and i < _leaves.multimesh.instance_count:
			_leaves.multimesh.set_instance_transform(i, _leaf_xf[i])


func _paint_trees() -> void:
	if _leaves == null or _leaf_xf.is_empty():
		return
	var mm := _leaves.multimesh
	shown_leaves.clear()
	shown_leaf_sizes.clear()
	for i in _leaf_xf.size():
		var xf := _leaf_xf[i]
		var c := _leaf_cols[i]
		match season:
			"spring", "summer":
				var pal: Array = LEAVES[season]
				c = pal[(i * 7 + i / 4) % pal.size()]
			"winter":
				# Most of the leaves gone; one ball in four left as snow lying on the bare branches
				if i % 4 == 0:
					xf = Transform3D(xf.basis.scaled(Vector3(0.7, 0.45, 0.7)), xf.origin + Vector3(0, -0.2, 0))
					c = SNOW
				else:
					xf = Transform3D(Basis().scaled(Vector3.ONE * 0.001), xf.origin)
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, c)
		shown_leaves.append(c)
		shown_leaf_sizes.append(xf.basis.get_scale().x)


func _paint_fallen() -> void:
	if _fallen == null or _fallen_xf.is_empty():
		return
	var mm := _fallen.multimesh
	shown_fallen.clear()
	shown_fallen_sizes.clear()
	for i in _fallen_xf.size():
		var xf := _fallen_xf[i]
		var c := _fallen_cols[i]
		match season:
			"spring":                                # a flower in every third spot, small and bright
				if i % 3 == 0:
					xf = Transform3D(xf.basis.scaled(Vector3.ONE * 0.8), xf.origin + Vector3(0, 0.02, 0))
					c = FLOWERS[i % FLOWERS.size()]
				else:
					xf = Transform3D(Basis().scaled(Vector3.ONE * 0.001), xf.origin)
			"summer":                                # a few flowers left in the long grass
				if i % 9 == 0:
					c = FLOWERS[(i / 9) % FLOWERS.size()]
				else:
					xf = Transform3D(Basis().scaled(Vector3.ONE * 0.001), xf.origin)
			"winter":                                # drifts: big soft patches of snow on the snow
				xf = Transform3D(xf.basis.scaled(Vector3(9.0, 9.0, 1.0)), xf.origin + Vector3(0, 0.01, 0))
				c = SNOW
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, c)
		shown_fallen.append(c)
		shown_fallen_sizes.append(xf.basis.get_scale().x)


func _paint_materials() -> void:
	for n in _mats:
		for m in _mats[n]:
			var mat := m as StandardMaterial3D
			var built: Dictionary = _albedo[mat]
			var c: Color = built.albedo
			mat.roughness = built.rough
			mat.transparency = built.transparency
			var name := str(n)
			if name.begins_with("Roof ") or name.begins_with("Porch Roof ") or name.ends_with("Roof"):
				if season == "winter":
					c = c.lerp(SNOW, ROOF_SNOW)
			elif name == "Town Green":
				c = GREEN.get(season, c)
			elif name.begins_with("Far Hill "):
				if HILLS.has(season):
					c = HILLS[season][int(name.get_slice(" ", 2)) % 4]
			elif name.begins_with("Leaves "):
				if season == "winter":
					c = SNOW
				elif LEAVES.has(season):
					c = LEAVES[season][absi(hash(name)) % LEAVES[season].size()]
			elif name == "Pond Water" and season == "winter":
				c = Color(0.82, 0.9, 0.97, 0.97)     # iced over
				mat.roughness = 0.15
			elif name == "Pond Water" and season == "summer":
				c = SUMMER_POND                      # clear and blue, glinting in the sun
				mat.roughness = 0.02
			elif name == "Pond Water" and season == "spring":
				c = SPRING_POND                      # fresh and clear after the showers, for the ducks
				mat.roughness = 0.04
			elif (name == "Lily Pad" or name == "Lily Flower") and season == "winter":
				c = Color(0.85, 0.92, 0.98)          # (under the ice)
			mat.albedo_color = c if name == "Pond Water" and season == "winter" else Color(c, built.albedo.a)


func _dress(on: bool) -> void:
	# The Halloween dressing, and its hay bales' collisions, only in autumn
	if _dressing == null:
		return
	_dressing.visible = on
	for cs in _dressing.find_children("*", "CollisionShape3D", true, false):
		(cs as CollisionShape3D).disabled = not on
	for m in _mist:
		if is_instance_valid(m):
			m.visible = season != "summer" and season != "spring"      # (a Halloween-y mist: not in the sunny seasons)


# -----------------------------------------------------------------------------
# The rest of autumn: pumpkins and scarecrows round town, and the lights
# -----------------------------------------------------------------------------
const PUMPKINY := ["Pumpkin", "Pumpkin Stem", "Jack Glow"]
const BULBS_WINTER := [Color(1.0, 0.25, 0.25), Color(0.3, 0.95, 0.4), Color(1.0, 0.95, 0.85), Color(0.45, 0.65, 1.0)]
const BUNTING_WINTER := [Color(0.85, 0.15, 0.2), Color(0.15, 0.55, 0.3), Color(0.97, 0.97, 1.0), Color(0.75, 0.8, 0.9)]
# Summer's: sunshine yellow, sea turquoise, watermelon pink and lime
const BULBS_SUMMER := [Color(1.0, 0.85, 0.2), Color(0.2, 0.85, 0.85), Color(1.0, 0.45, 0.55), Color(0.6, 0.95, 0.3)]
const BUNTING_SUMMER := [Color(1.0, 0.8, 0.15), Color(0.1, 0.65, 0.75), Color(0.95, 0.35, 0.45), Color(0.97, 0.97, 1.0)]
# Spring's: soft pastels, blossom pink, primrose, lilac and mint
const BULBS_SPRING := [Color(1.0, 0.7, 0.82), Color(1.0, 0.95, 0.55), Color(0.8, 0.7, 1.0), Color(0.65, 1.0, 0.8)]
const BUNTING_SPRING := [Color(1.0, 0.72, 0.84), Color(1.0, 0.93, 0.5), Color(0.75, 0.65, 0.95), Color(0.97, 0.97, 1.0)]
const TULIPS := [Color(0.95, 0.2, 0.3), Color(1.0, 0.85, 0.2), Color(1.0, 0.55, 0.75), Color(0.75, 0.45, 0.95), Color(1.0, 0.6, 0.2)]
const SUMMER_POND := Color(0.1, 0.38, 0.56)
const SPRING_POND := Color(0.14, 0.42, 0.5)


func _collect_autumn_bits(scene: Node) -> void:
	# The town as built has pumpkins on doorsteps, the gazebo's steps, mantels and in the pumpkin patch, and
	# scarecrows in the patch. They only belong in autumn: in winter snowmen stand where they were.
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override and m.material_override.resource_name in PUMPKINY \
				and not (_dressing and _dressing.is_ancestor_of(m)):
			_pumpkins.append(m)
	# Scarecrows: found by their sack heads, since a second one in the same place got a made-up node name
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override and m.material_override.resource_name == "Sack Head" \
				and not (_dressing and _dressing.is_ancestor_of(m)) and not _pumpkins.has(m.get_parent()):
			_pumpkins.append(m.get_parent() as Node3D)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.material_override and m.material_override.resource_name == "Pond Mist":
			_mist.append(m)
	var patch := scene.find_child("Pumpkin Patch", true, false)
	if patch:
		for l in patch.find_children("*", "Label3D", true, false):
			if (l as Label3D).text == "Pumpkin Patch":
				_patch_sign = l
	_bulbs = scene.find_child("Bulbs", true, false) as MultiMeshInstance3D
	_bunting = scene.find_child("Bunting", true, false) as MultiMeshInstance3D
	for pair in [[_bulbs, _bulb_cols], [_bunting, _bunting_cols]]:
		var mmi := pair[0] as MultiMeshInstance3D
		if mmi == null or mmi.multimesh == null:
			continue
		var old := mmi.multimesh
		var mm := MultiMesh.new()                                  # (its own copy, as for the leaves)
		mm.transform_format = old.transform_format
		mm.use_colors = old.use_colors
		mm.mesh = old.mesh
		var xf: PackedFloat32Array = mmi.get("transforms") if "transforms" in mmi else PackedFloat32Array()
		var cols: PackedColorArray = mmi.get("colors") if "colors" in mmi else PackedColorArray()
		mm.instance_count = xf.size() / 12
		for i in mm.instance_count:
			var k := i * 12
			mm.set_instance_transform(i, Transform3D(Vector3(xf[k], xf[k + 1], xf[k + 2]), Vector3(xf[k + 3], xf[k + 4],
				xf[k + 5]), Vector3(xf[k + 6], xf[k + 7], xf[k + 8]), Vector3(xf[k + 9], xf[k + 10], xf[k + 11])))
			(pair[1] as Array).append(cols[i] if i < cols.size() else Color.WHITE)
		mmi.multimesh = mm


func _dress_rest() -> void:
	var autumn := season == "autumn"
	for n in _pumpkins:
		if is_instance_valid(n):
			n.visible = autumn
	if _patch_sign:
		_patch_sign.text = {"winter": "Snowman Field", "summer": "Sunflower Field", "spring": "Tulip Field"}.get(season, "Pumpkin Patch")
	if _snowmen:
		_snowmen.name = "Melting Snowmen"
		_snowmen.queue_free()
		_snowmen = null
	shown_snowmen = 0
	shown_sunflowers = 0
	shown_tulips = 0
	if season == "autumn":
		return
	# A snowman (in winter), a big sunflower (in summer) or a little bunch of tulips (in spring) for each doorstep
	# pumpkin (one for a cluster of them), and for each scarecrow
	_snowmen = Node3D.new()
	_snowmen.name = {"winter": "Winter Snowmen", "summer": "Summer Sunflowers"}.get(season, "Spring Tulips")
	add_child(_snowmen)
	var spots: Array[Vector3] = []
	for n in _pumpkins:
		if not is_instance_valid(n) or (n is MeshInstance3D and (n as MeshInstance3D).material_override.resource_name != "Pumpkin"):
			continue
		var at := n.global_position
		if n is MeshInstance3D:
			at.y -= (n as MeshInstance3D).get_aabb().size.y * n.global_basis.get_scale().y * 0.35
		var ground := EarthLand.height(at.x, at.z)
		if absf(at.y - ground) > 0.4:
			continue                          # (on a mantel, a hay bale, indoors up a step: nothing there)
		at.y = ground
		# (one snowman for a cluster of pumpkins; sunflowers are thinner, so they stand in little groups)
		var apart := (2.5 if season == "winter" else 1.1) if n is MeshInstance3D else 0.5
		if spots.any(func(p: Vector3) -> bool: return Vector2(p.x - at.x, p.z - at.z).length() < apart):
			continue
		spots.append(at)
	for at in spots:
		var big := spots.find(at) % 3 == 0
		var thing: Node3D
		match season:
			"winter":
				thing = snowman_model(0.75 if big else 0.55)
			"summer":
				thing = sunflower_model(1.3 if big else 1.0)
			_:
				thing = tulip_bunch_model(spots.find(at), 1.2 if big else 1.0)
		_snowmen.add_child(thing)
		thing.global_position = at
		thing.rotation.y = fposmod(at.x * 1.7 + at.z, TAU)
	if season == "winter":
		shown_snowmen = spots.size()
	elif season == "summer":
		shown_sunflowers = spots.size()
	else:
		shown_tulips = spots.size()


var shown_snowmen := 0                   # how many winter snowmen there are (for the tests)
var shown_sunflowers := 0                # and summer sunflowers
var shown_tulips := 0                    # and spring tulip bunches


func _paint_lights() -> void:
	for pair in [[_bulbs, _bulb_cols, BULBS_WINTER, BULBS_SUMMER, BULBS_SPRING], [_bunting, _bunting_cols, BUNTING_WINTER, BUNTING_SUMMER, BUNTING_SPRING]]:
		var mmi := pair[0] as MultiMeshInstance3D
		if mmi == null:
			continue
		var cols: Array = pair[1]
		for i in cols.size():
			var c: Color = cols[i]
			if season == "winter":
				c = pair[2][i % 4]
			elif season == "summer":
				c = pair[3][i % 4]
			elif season == "spring":
				c = pair[4][i % 4]
			mmi.multimesh.set_instance_color(i, c)


func lights_colour(i: int) -> Color:
	# (for the tests: the colour string light i is showing)
	if season == "winter":
		return BULBS_WINTER[i % 4]
	if season == "summer":
		return BULBS_SUMMER[i % 4]
	if season == "spring":
		return BULBS_SPRING[i % 4]
	return _bulb_cols[i] if i < _bulb_cols.size() else Color.WHITE


static func tulip_model(size := 1.0, k := 0) -> Node3D:
	# One tulip: a green stem with a long leaf, and a cup-shaped flower head in one of the spring colours
	var g := Node3D.new()
	g.name = "Tulip"
	var green := _m(Color(0.3, 0.6, 0.25), 0.8)
	var tall := 0.5 * size
	var stem := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.018 * size
	c.bottom_radius = 0.025 * size
	c.height = tall
	c.radial_segments = 6
	stem.mesh = c
	stem.material_override = green
	stem.position.y = tall / 2.0
	g.add_child(stem)
	var leaf := MeshInstance3D.new()
	leaf.mesh = _sphere(0.08 * size)
	leaf.material_override = green
	leaf.position = Vector3(0.04 * size, tall * 0.3, 0)
	leaf.scale = Vector3(0.6, 2.4, 0.3)
	leaf.rotation.z = -0.3
	g.add_child(leaf)
	var cup := _m(TULIPS[posmod(k, TULIPS.size())], 0.6)
	for p in 3:
		var a := TAU * p / 3.0
		var petal := MeshInstance3D.new()
		petal.mesh = _sphere(0.055 * size)
		petal.material_override = cup
		petal.position = Vector3(cos(a) * 0.03 * size, tall + 0.05 * size, sin(a) * 0.03 * size)
		petal.scale = Vector3(0.9, 1.6, 0.9)
		g.add_child(petal)
	return g


static func tulip_bunch_model(k: int, size := 1.0) -> Node3D:
	# A little clump of tulips, mixed colours, where a pumpkin stood in autumn
	var g := Node3D.new()
	g.name = "Tulips"
	for i in 5:
		var a := i * 2.4 + k
		var t := tulip_model(size * (0.85 + 0.1 * (i % 3)), k + i)
		t.position = Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else 0.16 * size)
		g.add_child(t)
	return g


static func sunflower_model(size := 1.0) -> Node3D:
	# A tall sunflower: a green stem with two leaves, a big yellow flower head with a brown middle, turned to the sun
	var g := Node3D.new()
	g.name = "Sunflower"
	var green := _m(Color(0.3, 0.55, 0.2), 0.8)
	var tall := 1.6 * size
	var stem := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.035 * size
	c.bottom_radius = 0.05 * size
	c.height = tall
	c.radial_segments = 6
	stem.mesh = c
	stem.material_override = green
	stem.position.y = tall / 2.0
	g.add_child(stem)
	for k in 2:
		var leaf := MeshInstance3D.new()
		leaf.mesh = _sphere(0.16 * size)
		leaf.material_override = green
		var sx := -1.0 if k == 0 else 1.0
		leaf.position = Vector3(sx * 0.14 * size, tall * (0.35 + k * 0.2), 0)
		leaf.scale = Vector3(1.4, 0.25, 0.8)
		leaf.rotation.z = sx * -0.4
		g.add_child(leaf)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, tall, 0.06 * size)
	head.rotation.x = 0.35                 # nodding a little, face to the sky
	g.add_child(head)
	var petal := _m(Color(1.0, 0.8, 0.1), 0.7)
	for k in 12:
		var a := TAU * k / 12.0
		var p := MeshInstance3D.new()
		p.mesh = _sphere(0.09 * size)
		p.material_override = petal
		p.position = Vector3(cos(a) * 0.2 * size, sin(a) * 0.2 * size, 0)
		p.rotation.z = a
		p.scale = Vector3(1.7, 1.0, 0.3)          # (long along the way it points: out from the middle)
		head.add_child(p)
	var middle := MeshInstance3D.new()
	var mc := CylinderMesh.new()
	mc.top_radius = 0.15 * size
	mc.bottom_radius = 0.15 * size
	mc.height = 0.06 * size
	mc.radial_segments = 14
	middle.mesh = mc
	middle.material_override = _m(Color(0.4, 0.24, 0.1), 0.9)
	middle.rotation.x = PI / 2
	middle.position.z = 0.02 * size
	head.add_child(middle)
	return g


static func snowman_model(size := 0.7) -> Node3D:
	# A friendly snowman: three snowballs, coal eyes and buttons, a carrot nose, stick arms, a red scarf and a hat
	var g := Node3D.new()
	g.name = "Snowman"
	var snow := _m(Color(0.96, 0.97, 1.0), 0.9)
	var coal := _m(Color(0.08, 0.08, 0.1), 0.6)
	var y := 0.0
	for k in 3:
		var r: float = size * [0.5, 0.36, 0.26][k]
		var b := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = r
		sp.height = r * 2.0
		b.mesh = sp
		b.material_override = snow
		b.position.y = y + r * 0.85
		g.add_child(b)
		y = b.position.y + r * 0.8
	var head_y := y - size * 0.26 * 0.8
	var hr := size * 0.26
	for sx in [-1.0, 1.0]:
		_bit(g, _sphere(hr * 0.12), coal, Vector3(sx * hr * 0.35, head_y + hr * 0.2, hr * 0.9))
	var nose := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = hr * 0.14
	c.height = hr * 0.8
	nose.mesh = c
	nose.material_override = _m(Color(1.0, 0.5, 0.1), 0.6)
	nose.rotation.x = PI / 2
	nose.position = Vector3(0, head_y, hr * 1.2)
	g.add_child(nose)
	var mid_y := size * (0.5 * 1.65 + 0.36 * 0.85)
	for k in 3:
		_bit(g, _sphere(size * 0.035), coal, Vector3(0, mid_y + (k - 1) * size * 0.11, size * 0.35))
	var scarf := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = hr * 0.8
	t.outer_radius = hr * 1.12
	scarf.mesh = t
	scarf.material_override = _m(Color(0.85, 0.15, 0.2), 0.8)
	scarf.position.y = head_y - hr * 0.85
	g.add_child(scarf)
	var hat := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = hr * 0.6
	hc.bottom_radius = hr * 0.6
	hc.height = hr * 0.8
	hat.mesh = hc
	hat.material_override = coal
	hat.position.y = head_y + hr * 1.1
	g.add_child(hat)
	var brim := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = hr * 0.95
	bc.bottom_radius = hr * 0.95
	bc.height = hr * 0.08
	brim.mesh = bc
	brim.material_override = coal
	brim.position.y = head_y + hr * 0.72
	g.add_child(brim)
	var stick := _m(Color(0.4, 0.26, 0.15), 0.9)
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = size * 0.015
		ac.bottom_radius = size * 0.025
		ac.height = size * 0.6
		arm.mesh = ac
		arm.material_override = stick
		arm.position = Vector3(sx * size * 0.55, mid_y + size * 0.08, 0)
		arm.rotation.z = sx * -1.0
		g.add_child(arm)
	return g


static func _m(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _sphere(r: float) -> SphereMesh:
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.0
	sp.radial_segments = 8
	sp.rings = 4
	return sp


static func _bit(parent: Node3D, mesh: Mesh, m: Material, at: Vector3) -> void:
	var b := MeshInstance3D.new()
	b.mesh = mesh
	b.material_override = m
	b.position = at
	parent.add_child(b)


# -----------------------------------------------------------------------------
# Something in the air
# -----------------------------------------------------------------------------
func _make_air() -> void:
	_air = CPUParticles3D.new()
	_air.name = "Season Air"
	_air.amount = 260
	_air.lifetime = 7.0
	_air.preprocess = 7.0
	_air.local_coords = false
	_air.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_air.emission_box_extents = AIR_SIZE / 2.0
	_air.direction = Vector3(0.3, -1, 0.1)
	_air.spread = 25.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A soft round dot, not a square: white in the middle fading out to the edge
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.9))
	dot.gradient = g
	m.albedo_texture = dot
	quad.material = m
	_air.mesh = quad
	add_child(_air)


func air_kind() -> String:
	# What's falling or floating round the player now: "snow", "petals", "leaves", "fluff", "fireflies" or ""
	match season:
		"winter":
			return "snow"
		"spring":
			return "petals"
		"autumn":
			return "leaves"
		"summer":
			# (summer evenings are long: the fireflies wait till it's dark at nine)
			return "fireflies" if Clock.earth_minutes >= 21 * 60.0 or Clock.earth_minutes < 5 * 60.0 else "fluff"
	return ""


func _set_air() -> void:
	_air_kind = air_kind()
	if _air == null:
		return
	_air.emitting = _air_kind != ""
	var quad := _air.mesh as QuadMesh
	var m := quad.material as StandardMaterial3D
	m.emission_enabled = false
	match _air_kind:
		"snow":
			_air.amount = 420
			_air.color = Color(1, 1, 1, 0.95)
			_air.gravity = Vector3(0, -1.2, 0)
			_air.initial_velocity_min = 0.4
			_air.initial_velocity_max = 0.9
			quad.size = Vector2(0.1, 0.1)
		"petals":
			_air.amount = 90
			_air.color = Color(1.0, 0.75, 0.85, 0.95)
			_air.gravity = Vector3(0.4, -0.5, 0.1)
			_air.initial_velocity_min = 0.3
			_air.initial_velocity_max = 0.8
			quad.size = Vector2(0.12, 0.09)
		"leaves":
			_air.amount = 50
			_air.color = Color(0.95, 0.5, 0.15, 1.0)
			_air.gravity = Vector3(0.5, -0.7, 0.2)
			_air.initial_velocity_min = 0.3
			_air.initial_velocity_max = 1.0
			quad.size = Vector2(0.18, 0.13)
		"fluff":
			# Dandelion seeds drifting about in the sunshine, slowly, mostly sideways
			_air.amount = 40
			_air.color = Color(1.0, 1.0, 0.97, 0.85)
			_air.gravity = Vector3(0.35, -0.12, 0.15)
			_air.initial_velocity_min = 0.1
			_air.initial_velocity_max = 0.4
			quad.size = Vector2(0.09, 0.09)
		"fireflies":
			_air.amount = 70
			_air.color = Color(1.0, 0.95, 0.45, 1.0)
			_air.gravity = Vector3(0, 0.05, 0)
			_air.initial_velocity_min = 0.1
			_air.initial_velocity_max = 0.4
			_air.spread = 180.0
			quad.size = Vector2(0.07, 0.07)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.95, 0.4)
			m.emission_energy_multiplier = 3.0
	if _air_kind != "fireflies":
		_air.spread = 25.0


func _follow_air() -> void:
	if _air == null:
		return
	if air_kind() != _air_kind:
		_set_air()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	# Over the player's head (fireflies down at their height); nothing indoors (a music zone: the bakery, the barn...)
	var high := 1.2 if _air_kind == "fireflies" else 9.0
	_air.global_position = player.global_position + Vector3(0, high, 0)
	_air.visible = Audio.zone_track() == ""
