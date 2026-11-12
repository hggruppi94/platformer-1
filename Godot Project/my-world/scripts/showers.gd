extends Node

# Heather's April Showers, the player's own: one of Glenmoor's two rewards (scripts/glenmoor.gd; the other is the
# Spring Step, scripts/spring_step.gd). Hayden, 10 Nov 2026: "Lets do April showers and the spring step". Like Bramble's
# burrow and Melody's groove it's locked until her world's mended: before Portals.is_cleared("glenmoor"), pressing it
# does nothing and the Controls list doesn't show it (Settings.action_shown()). Heather teaches both as the days go
# back to normal (glenmoor.gd thank_lines()).
#
# Since the party system (plan item 26, scripts/party.gd) it's Heather's move: with her walking with you, press Friend
# (Z, RB). (It used to be H, or holding Interact.) A little grey rain cloud
# gathers over the hero and rains for RAIN seconds (it follows them about). Then the sun peeks out, the cloud drifts
# off, and a RAINBOW arches out ahead, the way the camera's looking: a solid bridge LENGTH metres long and RISE high to
# walk up and over, for BRIDGE_LASTS seconds (it fades and wobbles before it goes). Only MAX_BRIDGES at once.
#
# What the rain does: near your garden in the Void (Farm) it waters every bed (never makes them grow faster: growing's
# Bramble's), and in Rhythm Springs it cools the heat right down.
# Made by the player (scenes/player/player.gd _ready).

const WORLD := "glenmoor"                 # the world whose mending unlocks it
const RAIN := 2.5                         # seconds of rain before the rainbow
const LENGTH := 14.0                      # the rainbow's length along the ground...
const RISE := 3.0                         # ...and how high it arches (gentle enough to walk up: under 40 degrees)
const WIDTH := 2.2
const BANDS := [Color(1.0, 0.35, 0.4), Color(1.0, 0.62, 0.3), Color(1.0, 0.9, 0.35), Color(0.45, 0.85, 0.45),
	Color(0.4, 0.65, 1.0), Color(0.7, 0.5, 1.0)]
const BRIDGE_LASTS := 20.0
const MAX_BRIDGES := 2
const COOLDOWN := 1.0
const GARDEN_NEAR := 12.0
const STEPS := 16                         # pieces of solid along the arch

var player: CharacterBody3D
var cooldown := 0.0
var raining := 0.0                        # seconds of rain left (0: no cloud)
var cloud: Node3D
var bridges: Array[Node3D] = []           # the rainbows out there now, oldest first
var showers := 0                          # (for the tests)


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func can_shower() -> bool:
	if not unlocked() or player == null or cooldown > 0.0 or raining > 0.0:
		return false
	if Game.riding or player.carried or player.input_locked:
		return false
	if player.burrow and player.burrow.active:
		return false
	if player.swim and player.swim.active:
		return false
	return true


func try_shower() -> bool:
	# Called by the player when April Showers is pressed on foot
	if not can_shower():
		return false
	shower()
	return true


func shower() -> void:
	cooldown = COOLDOWN
	showers += 1
	raining = RAIN
	if is_instance_valid(cloud):
		cloud.queue_free()
	cloud = cloud_model()
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = player.global_position + Vector3(0, 3.6, 0)
	cloud.scale = Vector3.ONE * 0.2
	cloud.create_tween().tween_property(cloud, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.blip("whoosh", 0.7, -8.0)
	_water_garden()
	_cool_down()


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if raining > 0.0:
		raining -= delta
		if is_instance_valid(cloud) and player:
			cloud.global_position = cloud.global_position.lerp(player.global_position + Vector3(0, 3.6, 0), minf(1.0, delta * 6.0))
		if raining <= 0.0:
			raining = 0.0
			_sun_comes_out()
	var now := Time.get_ticks_msec() / 1000.0
	for b in bridges.duplicate():
		if not is_instance_valid(b):
			bridges.erase(b)
			continue
		var left: float = float(b.get_meta("until")) - now
		if left <= 0.0:
			_fade(b)
		elif left < 3.0:
			# About to go: it shimmers, so nobody's caught out on top of it
			(b.get_node("Look") as Node3D).visible = fmod(left, 0.3) > 0.1


func nothing_near() -> bool:
	return not Dialogue.is_active() and Dialogue._near.is_empty()


func _sun_comes_out() -> void:
	# The rain stops, the cloud brightens and drifts away, and the rainbow arches out ahead
	if is_instance_valid(cloud):
		var c := cloud
		cloud = null
		var tw := c.create_tween()
		tw.tween_property(c, "position", c.position + Vector3(0, 4.0, 0), 1.2)
		tw.parallel().tween_property(c, "scale", Vector3.ONE * 0.3, 1.2)
		tw.tween_callback(c.queue_free)
		var rain := c.get_node_or_null("Rain") as CPUParticles3D
		if rain:
			rain.emitting = false
	if player and player.is_inside_tree():
		rainbow(player.global_position, ahead())


func ahead() -> Vector3:
	# Where the rainbow goes: the way the camera looks, along the ground
	var cam := player.get_viewport().get_camera_3d() if player else null
	var d := -cam.global_basis.z if cam else Vector3.FORWARD
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func rainbow(from: Vector3, dir: Vector3) -> Node3D:
	# A solid rainbow from the hero's feet, arching LENGTH metres ahead and down onto the ground there (or level, if
	# there's no ground: over water or a drop)
	var start := _ground(from, 2.5, from - Vector3(0, 0.8, 0))
	var end_at := start + dir * LENGTH
	var end := _ground(end_at + Vector3(0, 4.0, 0), 9.0, end_at)
	end.y = clampf(end.y, start.y - 2.5, start.y + 2.5)
	var b := rainbow_model(start, end)
	get_tree().current_scene.add_child(b)
	b.set_meta("until", Time.get_ticks_msec() / 1000.0 + BRIDGE_LASTS)
	bridges.append(b)
	while bridges.size() > MAX_BRIDGES:
		_fade(bridges[0])
	var look := b.get_node("Look") as Node3D
	look.scale = Vector3(1, 0.05, 1)
	look.create_tween().tween_property(look, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(get_tree().current_scene, (start + end) / 2.0 + Vector3(0, RISE, 0), BANDS[2], 20, 0.08, 3.0, -1.0, 1.0)
	Juice.blip("chime", 1.2, -5.0)
	Juice.blip("sparkle", 1.0, -8.0)
	return b


func _ground(from: Vector3, down: float, fallback: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -down, 0))
	if player:
		q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q) if player else {}
	return hit.position if not hit.is_empty() else fallback


func _fade(b: Node3D) -> void:
	bridges.erase(b)
	if not is_instance_valid(b):
		return
	for c in b.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var tw := b.create_tween()
	tw.tween_property(b.get_node("Look"), "scale", Vector3(1, 0.02, 1), 0.4)
	tw.tween_callback(b.queue_free)


func _water_garden() -> int:
	# Rain near your garden in the Void waters every bed (just a drink: making things grow is Bramble's gift)
	var farm := get_node_or_null("/root/Farm")
	if farm == null or not farm.call("unlocked") or player == null:
		return 0
	var g := get_tree().current_scene.get_node_or_null("Garden") as Node3D
	if g == null or g.global_position.distance_to(player.global_position) > GARDEN_NEAR:
		return 0
	farm.call("update")
	var n := 0
	var now: float = farm.now()
	for b in farm.get("beds"):
		if str(b.crop) == "":
			continue
		b.water_until = maxf(float(b.water_until), now + farm.WATER_LASTS)
		n += 1
	if n > 0:
		farm.emit_signal("changed")
		Game.message("A good soak for your garden! Every bed's watered.")
	return n


func _cool_down() -> void:
	# In Rhythm Springs, rain cools the heat right down (scripts/rhythm_springs.gd heat)
	var world := get_tree().current_scene
	if world and "heat" in world and str(world.get("world_id")) == "rhythm_springs":
		world.set("heat", 0.0)


static func cloud_model() -> Node3D:
	# A puffy little grey rain cloud with rain falling out of it
	var g := Node3D.new()
	g.name = "Rain Cloud"
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.74, 0.82)
	m.roughness = 1.0
	for k in 6:
		var a := k * TAU / 6.0
		var p := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.7 + 0.15 * (k % 2)
		s.height = s.radius * 1.6
		s.radial_segments = 10
		s.rings = 5
		p.mesh = s
		p.material_override = m
		p.position = Vector3(cos(a) * 0.8, 0.1 * (k % 3), sin(a) * 0.55)
		g.add_child(p)
	var top := MeshInstance3D.new()
	var ts := SphereMesh.new()
	ts.radius = 0.9
	ts.height = 1.5
	top.mesh = ts
	top.material_override = m
	top.position.y = 0.35
	g.add_child(top)
	var rain := CPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 90
	rain.lifetime = 0.6
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(1.2, 0.1, 0.8)
	rain.direction = Vector3.DOWN
	rain.spread = 4.0
	rain.gravity = Vector3(0, -20, 0)
	rain.initial_velocity_min = 5.0
	rain.initial_velocity_max = 6.0
	var drop := BoxMesh.new()
	drop.size = Vector3(0.03, 0.3, 0.03)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.65, 0.8, 1.0, 0.8)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	rain.mesh = drop
	rain.position.y = -0.3
	g.add_child(rain)
	return g


static func arch(start: Vector3, end: Vector3, t: float) -> Vector3:
	# A point along the rainbow: from start to end with a gentle hump RISE high in the middle
	return start.lerp(end, t) + Vector3(0, RISE * sin(PI * t), 0)


static func rainbow_model(start: Vector3, end: Vector3) -> StaticBody3D:
	# The rainbow bridge: six coloured bands side by side across its width, arching from start to end, with a solid
	# plank under each stretch to walk on
	var b := StaticBody3D.new()
	b.name = "Rainbow"
	b.add_to_group("rainbow")
	var flat := end - start
	flat.y = 0.0
	var side := flat.normalized().cross(Vector3.UP).normalized()
	for k in STEPS:
		var p0 := arch(start, end, float(k) / STEPS)
		var p1 := arch(start, end, float(k + 1) / STEPS)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(WIDTH, 0.25, p0.distance_to(p1) + 0.1)
		cs.shape = box
		var fwd := (p1 - p0).normalized()
		var up := fwd.cross(side).normalized()
		if up.y < 0.0:
			up = -up
		var basis := Basis(up.cross(fwd).normalized(), up, fwd)
		cs.transform = Transform3D(basis, (p0 + p1) / 2.0 - up * 0.12)
		b.add_child(cs)
	var look := Node3D.new()
	look.name = "Look"
	b.add_child(look)
	look.position = start
	var mesh := MeshInstance3D.new()
	mesh.name = "Bands"
	mesh.mesh = _bands_mesh(start, end, side)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.4
	mesh.material_override = m
	mesh.position = -start
	look.add_child(mesh)
	return b


static func _bands_mesh(start: Vector3, end: Vector3, side: Vector3) -> ArrayMesh:
	# The coloured strips, in world space (the caller moves it), each a ribbon along the arch
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := BANDS.size()
	var segs := 32
	for band in n:
		var a := -WIDTH / 2.0 + WIDTH * band / n
		var c: Color = BANDS[band]
		for k in segs:
			var p0 := arch(start, end, float(k) / segs)
			var p1 := arch(start, end, float(k + 1) / segs)
			var v := [p0 + side * a, p0 + side * (a + WIDTH / n), p1 + side * a, p1 + side * (a + WIDTH / n)]
			for i in [0, 2, 1, 1, 2, 3]:
				st.set_color(c)
				st.set_normal(Vector3.UP)
				st.add_vertex(v[i])
	return st.commit()
