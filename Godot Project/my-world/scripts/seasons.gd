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
# - and something in the air round the player outdoors: snow in winter, petals in spring, leaves in autumn, and on
#   summer nights, fireflies.
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
	_set_air()


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
	# What's falling or floating round the player now: "snow", "petals", "leaves", "fireflies" or ""
	match season:
		"winter":
			return "snow"
		"spring":
			return "petals"
		"autumn":
			return "leaves"
		"summer":
			return "fireflies" if Clock.earth_minutes >= 20 * 60.0 or Clock.earth_minutes < 5 * 60.0 else ""
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
