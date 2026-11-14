extends RefCounted

# Big waterfalls with a secret cove behind each (Hayden, 14 Nov 2026: "Id also like to put little secret coves behind
# all the waterfalls, and make them much larger and more impressive"). WorldDetail calls dress_void / dress_earth /
# dress_rhythm as those places load; the builders' old thin sheets and foam are hidden (their rushing sound stays) and
# each fall is rebuilt where it was, about twice as wide:
#   - the upper cascade pours down the cliff face itself (it follows the cliff's real shape, found with rays)
#   - part way down a rocky arch juts out of the cliff, and the water spills over its lip as a big curtain in front of
#     a cove: two sheets, the front one quicker and thinner, with foam where it lands, rising spray, mist, a rainbow
#     in the spray and tumbled boulders round the splash
#   - behind the curtain, the cove: a dry rock floor (a ramp up to it where it stands over water), glowing crystals,
#     glowcaps and a little treasure chest (COVE_SPARKLES and a Remnant, once each: flag "cove_<place>_<id>")
#   - walking through the curtain splashes and soaks you (swim.gd soak())
# The falls and coves are built from the place's own height and rock: rays find the cliff, so it fits whichever world.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const COVE_SPARKLES := 6
const COVE_REMNANTS := 1
const COVE_DEPTH := 4.5          # metres of dry floor behind the curtain
const ARCH_HIGH := 5.0           # the arch's lip, at most this high over the splash

const FALLS_SHADER := """shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
uniform vec4 colour : source_color = vec4(0.72, 0.92, 1.0, 0.8);
uniform float speed = 1.4;
uniform float streaks = 9.0;
uniform float glow = 0.25;
float h(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5); }
float n(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	// a gentle ripple across the sheet as it falls
	VERTEX.z += sin(UV.y * 18.0 - TIME * 5.0 + UV.x * 7.0) * 0.06;
}
void fragment() {
	float fall = UV.y * 6.0 - TIME * speed;
	float s1 = n(vec2(UV.x * streaks * 6.0, fall * 2.0));
	float s2 = n(vec2(UV.x * streaks * 13.0 + 5.0, fall * 3.1));
	float white = smoothstep(0.55, 0.95, s1 * 0.6 + s2 * 0.5);
	float foam = smoothstep(0.82, 1.0, UV.y) + smoothstep(0.1, 0.0, UV.y) * 0.6;   // churned at the bottom, lip at the top
	float edge = smoothstep(0.0, 0.07 + 0.05 * n(vec2(UV.y * 9.0 - TIME, 1.0)), min(UV.x, 1.0 - UV.x));   // ragged sides
	vec3 c = mix(colour.rgb, vec3(1.0), clamp(white * 0.75 + foam, 0.0, 1.0));
	ALBEDO = c;
	EMISSION = c * glow;
	ROUGHNESS = 0.15;
	ALPHA = clamp(colour.a * edge * (0.75 + 0.25 * white) + foam * 0.3, 0.0, 1.0);
}
"""

const RAINBOW_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform float strength = 0.2;
void fragment() {
	// UV.y across the band: red on the outside to violet on the inside, soft at both edges
	float t = UV.y;
	vec3 c = clamp(abs(fract(vec3(t) + vec3(0.0, 0.66, 0.33)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	float soft = smoothstep(0.0, 0.25, t) * smoothstep(1.0, 0.75, t);
	float sway = 0.7 + 0.3 * sin(TIME * 0.6 + UV.x * 3.0);
	ALBEDO = c * soft * strength * sway;
}
"""

static var _falls_shader: Shader
static var _rainbow_shader: Shader


# Each place's falls ---------------------------------------------------------------------------------------------------
static func dress_void(scene: Node) -> int:
	var made := 0
	var found := []                                    # [mesh, id, width]
	var wf := scene.get_node_or_null("Waterfalls")
	if wf:
		var k := 0
		for c in wf.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is QuadMesh:
				k += 1
				found.append([c, "plateau_%d" % k, 10.0 if k == 1 else 8.5])
		_hide_old(wf)
	var cg := scene.get_node_or_null("Castle Grounds")
	if cg:
		var names := ["castle_east", "castle_west"]
		var k := 0
		for c in cg.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.mesh is QuadMesh and mi.material_override is ShaderMaterial and k < 2:
				found.append([mi, names[k], 16.0])
				k += 1
				mi.visible = false
			elif mi and mi.mesh is CylinderMesh and mi.material_override and mi.material_override.resource_name == "Foam":
				mi.visible = false
	for f in found:
		if _build(scene, f[0], f[1], f[2], "alien"):
			made += 1
	return made


static func dress_earth(scene: Node) -> int:
	var made := 0
	for fall in scene.find_children("Waterfall", "MeshInstance3D", true, false):
		var parent := fall.get_parent()
		for c in parent.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.material_override and mi.material_override.resource_name == "Foam" \
					and mi.global_position.distance_to(fall.global_position) < 12.0:
				mi.visible = false
		if _build(scene, fall, "mossy_falls", 8.0, "earth"):
			made += 1
	return made


static func dress_rhythm(scene: Node) -> int:
	var made := 0
	for fall in scene.find_children("Waterfall", "MeshInstance3D", true, false):
		var parent := fall.get_parent()
		for c in parent.get_children():
			var mi := c as MeshInstance3D
			if mi and mi.material_override and mi.material_override.resource_name == "Foam" \
					and mi.global_position.distance_to(fall.global_position) < 10.0:
				mi.visible = false
		if _build(scene, fall, "mesa_falls", 6.5, "sand"):
			made += 1
	return made


static func _hide_old(holder: Node) -> void:
	# The old sheets, foam and mist go; the rushing sound stays
	for c in holder.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visible = false
		if c is CPUParticles3D:
			(c as CPUParticles3D).emitting = false


# Building one -------------------------------------------------------------------------------------------------------
static func _build(scene: Node, old: MeshInstance3D, id: String, width: float, look: String) -> bool:
	# Works out where the old sheet ran (its top, its bottom, which way is out from the cliff) and builds the new
	# falls and cove there, on the scene's root so nothing the old one sat in moves it
	var size := Vector2.ZERO
	if old.mesh is QuadMesh:
		size = (old.mesh as QuadMesh).size
	elif old.mesh is BoxMesh:
		size = Vector2((old.mesh as BoxMesh).size.x, (old.mesh as BoxMesh).size.y)
	else:
		return false
	var gt := old.global_transform
	var up := gt.basis.y.normalized()
	var top := gt.origin + up * gt.basis.y.length() * size.y / 2.0
	var bottom := gt.origin - up * gt.basis.y.length() * size.y / 2.0
	old.visible = false
	var out := Vector3(bottom.x - top.x, 0, bottom.z - top.z)
	if out.length() < 0.5:
		out = Vector3(gt.basis.z.x, 0, gt.basis.z.z)
	out = out.normalized()
	var world := (scene as Node3D).get_world_3d()
	var root := Node3D.new()
	root.name = "Big Falls " + id
	root.set_meta("cove_id", id)
	scene.add_child(root)
	# The cliff's real face: how far out from the top it is at each height, and the ground and water at the foot
	var edge := Vector3(top.x, 0, top.z)
	var top_y := top.y
	var foot_y := bottom.y
	# Slide it along the cliff, if it must, so the cove isn't built into a building at its foot (the castle's east
	# falls came down right onto one of its towers)
	var moved := _clear_spot(world, edge, out, top_y, foot_y, width, root)
	if moved.distance_to(edge) > 0.1:
		edge = moved
		top_y = minf(top_y, _land_ground(world, edge - out * 1.0, top_y + 4.0))
	var drop := top_y - foot_y
	var lip_y := foot_y + minf(ARCH_HIGH, maxf(drop * 0.45, 3.2))
	var face_at_lip := _face(world, edge, out, lip_y, root)
	var face_at_foot := _face(world, edge, out, foot_y + 0.6, root)
	var front := maxf(face_at_lip + COVE_DEPTH, face_at_foot + 2.6)     # the curtain's distance out from the top
	var side := Vector3.UP.cross(out).normalized()
	var ground_front := _ground(world, edge + out * (front + 2.0), top_y + 5.0, root)
	var splash_y := maxf(foot_y, ground_front)
	var floor_y := maxf(foot_y, _land_ground(world, edge + out * (face_at_lip + COVE_DEPTH * 0.5), lip_y)) + 0.12
	var mats := _materials(look)
	# Where the back wall really is at the cove's floor: a sloping cliff stands further out down there than at the lip,
	# so the chest, crystals and glowcaps go in front of that, never inside the rock (and at least 1.6 m behind the curtain)
	var inner := minf(maxf(face_at_lip, _face(world, edge, out, floor_y + 0.5, root) + 0.3), front - 3.0)
	var info := {"edge": edge, "out": out, "side": side, "top_y": top_y, "lip_y": lip_y, "floor_y": floor_y,
		"splash_y": splash_y, "front": front, "back": face_at_lip, "inner": inner, "width": width, "id": id}
	root.set_meta("info", info)
	_upper_cascade(world, root, info, mats)
	_arch(root, info, mats)
	_curtains(root, info, mats)
	_splash(root, info, mats, look)
	_cove(scene, root, info, mats, look)
	return true


static func _face(world: World3D, edge: Vector3, out: Vector3, y: float, skip: Node) -> float:
	# How far out from the cliff top the cliff's face is at height y: a ray from well out in front, back towards it
	var from := edge + out * 16.0 + Vector3(0, y, 0)
	var to := edge - out * 6.0 + Vector3(0, y, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	for i in 8:
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return 0.0
		if _is_land(hit.collider):
			return maxf((Vector3(hit.position.x, 0, hit.position.z) - edge).dot(out), 0.0)
		var ex := q.exclude
		ex.append((hit.collider as CollisionObject3D).get_rid())
		q.exclude = ex
	return 0.0


static func _is_land(c: Object) -> bool:
	# The ground or a cliff, not a tree, a sign or a person in front of it
	var n := c as Node
	for i in 3:
		if n == null:
			break
		var low := String(n.name).to_lower()
		for w in ["ground", "terrain", "mesa", "hill", "cliff", "land", "rock"]:
			if low.contains(w):
				return true
		n = n.get_parent()
	return false


static func _clear_spot(world: World3D, edge: Vector3, out: Vector3, top_y: float, foot_y: float, width: float,
		skip: Node) -> Vector3:
	# The first spot along the cliff (no move, then a little either way, further each time) where nothing but ground
	# stands where the cove and the splash go (a grid of rays down over it), and, if it moved, where the cliff top is
	# still about as high to pour off
	var side := Vector3.UP.cross(out).normalized()
	for s in [0.0, 3.0, -3.0, 6.0, -6.0, 9.0, -9.0, 12.0, -12.0, 15.0, -15.0, 18.0, -18.0, 21.0, -21.0]:
		var at: Vector3 = edge + side * s
		if s != 0.0 and absf(_land_ground(world, at - out * 1.0, top_y + 4.0) - top_y) > 2.5:
			continue
		var clear := true
		for a in 5:
			for d in 4:
				var p: Vector3 = at + side * lerpf(-width / 2.0, width / 2.0, a / 4.0) + out * lerpf(1.5, COVE_DEPTH + 6.0, d / 3.0)
				var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, foot_y + 5.5, p.z), Vector3(p.x, foot_y - 1.0, p.z))
				var hit := world.direct_space_state.intersect_ray(q)
				if not hit.is_empty() and not _is_land(hit.collider) and hit.position.y > foot_y + 0.4:
					clear = false
					break
			if not clear:
				break
		if clear:
			return at
	return edge


static func _land_ground(world: World3D, at: Vector3, from_y: float) -> float:
	# Like _ground(), but only the ground itself counts (not a roof, a tree or a stall standing on it)
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y + 2.0, at.z), Vector3(at.x, from_y - 60.0, at.z))
	for i in 8:
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return from_y - 10.0
		if _is_land(hit.collider):
			return hit.position.y
		var ex := q.exclude
		ex.append(hit.rid)
		q.exclude = ex
	return from_y - 10.0


static func _ground(world: World3D, at: Vector3, from_y: float, skip: Node) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, from_y + 2.0, at.z), Vector3(at.x, from_y - 60.0, at.z))
	var hit := world.direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else from_y - 10.0


static func _materials(look: String) -> Dictionary:
	if _falls_shader == null:
		_falls_shader = Shader.new()
		_falls_shader.code = FALLS_SHADER
		_rainbow_shader = Shader.new()
		_rainbow_shader.code = RAINBOW_SHADER
	var water_col := {"alien": Color(0.55, 1.0, 0.85, 0.82), "earth": Color(0.72, 0.9, 1.0, 0.8),
		"sand": Color(0.6, 0.92, 1.0, 0.8)}[look] as Color
	var rock_cols := {"alien": [Color(0.24, 0.18, 0.38), Color(0.12, 0.42, 0.44)],
		"earth": [Color(0.42, 0.42, 0.4), Color(0.3, 0.42, 0.2)],
		"sand": [Color(0.86, 0.6, 0.4), Color(0.95, 0.78, 0.55)]}[look] as Array
	var sheet := ShaderMaterial.new()
	sheet.resource_name = "Big Falls Water"
	sheet.shader = _falls_shader
	sheet.set_shader_parameter("colour", water_col)
	sheet.set_shader_parameter("glow", 0.35 if look == "alien" else 0.12)
	var front := sheet.duplicate() as ShaderMaterial
	front.set_shader_parameter("colour", Color(water_col.lerp(Color.WHITE, 0.35), 0.5))
	front.set_shader_parameter("speed", 2.1)
	front.set_shader_parameter("streaks", 14.0)
	var rock := StandardMaterial3D.new()
	rock.resource_name = "Falls Rock"
	rock.vertex_color_use_as_albedo = true
	rock.roughness = 0.85
	var foam := StandardMaterial3D.new()
	foam.resource_name = "Falls Foam"
	foam.albedo_color = Color(0.95, 0.98, 1.0, 0.85)
	foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam.roughness = 0.4
	foam.emission_enabled = true
	foam.emission = Color(0.9, 0.97, 1.0)
	foam.emission_energy_multiplier = 0.25
	var rainbow := ShaderMaterial.new()
	rainbow.shader = _rainbow_shader
	return {"sheet": sheet, "front": front, "rock": rock, "rock_cols": rock_cols, "foam": foam, "rainbow": rainbow,
		"water": water_col}


static func _at(info: Dictionary, out_m: float, across: float, y: float) -> Vector3:
	return info.edge + info.out * out_m + info.side * across + Vector3(0, y, 0)


static func _upper_cascade(world: World3D, root: Node3D, info: Dictionary, mats: Dictionary) -> void:
	# A strip of falling water hugging the cliff from the top down to the arch's roof, following the cliff's shape
	var steps := 10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = info.width * 0.8
	var rows := []
	var roof_y: float = info.lip_y + 1.2
	for i in steps + 1:
		var t := i / float(steps)
		var y := lerpf(info.top_y + 0.15, roof_y, t)
		var d := _face(world, info.edge, info.out, y - 0.05, root) + 0.3
		if i == 0:
			d = 0.0
		d = minf(d, info.back + 0.5)
		rows.append([_at(info, d, -w / 2.0, y), _at(info, d, w / 2.0, y), t])
	# along the top of the arch's roof to its front edge
	rows.append([_at(info, info.front - 0.2, -w / 2.0, roof_y + 0.05), _at(info, info.front - 0.2, w / 2.0, roof_y + 0.05), 1.0])
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var ta := i / float(rows.size() - 1)
		var tb := (i + 1) / float(rows.size() - 1)
		for v in [[a[0], Vector2(0, ta)], [a[1], Vector2(1, ta)], [b[0], Vector2(0, tb)],
				[a[1], Vector2(1, ta)], [b[1], Vector2(1, tb)], [b[0], Vector2(0, tb)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0] - root.global_position)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Upper Cascade"
	mi.mesh = st.commit()
	mi.material_override = mats.sheet
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _arch(root: Node3D, info: Dictionary, mats: Dictionary) -> void:
	# The rock arch jutting out of the cliff: two lumpy side walls from the floor up, and a roof slab over them that
	# the water runs across and spills off. All solid.
	var w: float = info.width
	var depth: float = info.front - info.back + 1.2
	var mid_out: float = (info.front + info.back) / 2.0 - 0.3
	var base: float = minf(info.floor_y, info.splash_y) - 1.2
	var roof_y: float = info.lip_y + 1.2
	var yaw := atan2(info.out.x, info.out.z)
	for s in [-1.0, 1.0]:
		var wall_h: float = roof_y - base + 0.4
		var size := Vector3(2.2, wall_h, depth + 1.0)
		_rock(root, "Arch Wall", _at(info, mid_out + 0.4, s * (w / 2.0 + 1.0), base + wall_h / 2.0), size, yaw, mats,
			hash(info.id) + int(s * 3), true)
		# a few boulders heaped against its outer side, so it grows out of the cliff
		for k in 3:
			var bs := randf_range(1.4, 2.6)
			_rock(root, "Arch Boulder", _at(info, mid_out + randf_range(-2.0, 2.0), s * (w / 2.0 + 2.6 + k * 0.6),
				base + bs * 0.5 + k * 1.2), Vector3(bs * 1.3, bs, bs * 1.2), randf() * TAU, mats, k + hash(info.id), false)
	var roof := Vector3(w + 4.4, 1.6, depth + 1.0)
	_rock(root, "Arch Roof", _at(info, mid_out + 0.4, 0.0, roof_y - 0.8), roof, yaw, mats, hash(info.id) + 7, true)


static func _curtains(root: Node3D, info: Dictionary, mats: Dictionary) -> void:
	# The big curtain from the arch's lip down to the splash, and a thinner, quicker one just in front
	var drop: float = info.lip_y + 1.2 - info.splash_y
	var yaw := atan2(info.out.x, info.out.z)
	for k in 2:
		var q := QuadMesh.new()
		q.size = Vector2(info.width * (1.0 if k == 0 else 0.86), drop + 0.4)
		q.subdivide_depth = 24
		q.subdivide_width = 12
		var mi := MeshInstance3D.new()
		mi.name = "Curtain" if k == 0 else "Curtain Front"
		mi.mesh = q
		mi.material_override = mats.sheet if k == 0 else mats.front
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		# QuadMesh faces +Z with UV.y running top to bottom, which is what the shader wants
		mi.global_transform = Transform3D(Basis(Vector3.UP, yaw), _at(info, info.front + k * 0.35, 0.0,
			info.splash_y + drop / 2.0 - 0.1))
	# Foam pouring over the lip
	var lip := MeshInstance3D.new()
	lip.name = "Lip Foam"
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = info.width + 0.6
	lip.mesh = cm
	lip.material_override = mats.foam
	root.add_child(lip)
	# (a capsule stands along its y: lay it along the lip, across the falls)
	lip.global_transform = Transform3D(Basis(info.out, info.side, Vector3.UP), _at(info, info.front - 0.1, 0.0, info.lip_y + 2.0))
	# Walking through the curtain: a splash, and you're soaked
	var a := Area3D.new()
	a.name = "Through The Curtain"
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(info.width, drop, 0.8)
	cs.shape = bx
	a.add_child(cs)
	root.add_child(a)
	a.global_transform = Transform3D(Basis(Vector3.UP, yaw), _at(info, info.front, 0.0, info.splash_y + drop / 2.0))
	a.body_entered.connect(func(b: Node3D) -> void: _through(a, b))


static func _through(a: Area3D, b: Node3D) -> void:
	if not b.is_in_group("player"):
		return
	Audio.play_at("splash", b.global_position, -4.0)
	Fx.burst(a.get_parent(), b.global_position + Vector3(0, 1.0, 0), Color(0.85, 0.95, 1.0), 14, 0.08, 2.5, -6.0, 0.7)
	var swim := b.get_node_or_null("Swim")
	if swim and swim.has_method("soak"):
		swim.soak()


static func _splash(root: Node3D, info: Dictionary, mats: Dictionary, look: String) -> void:
	var foot := _at(info, info.front + 0.6, 0.0, info.splash_y + 0.05)
	var yaw := atan2(info.out.x, info.out.z)
	# Churned white water where it lands: overlapping flat foam pads
	for k in 7:
		var f := MeshInstance3D.new()
		f.name = "Splash Foam"
		var c := CylinderMesh.new()
		var r: float = info.width * randf_range(0.14, 0.22)
		c.top_radius = r
		c.bottom_radius = r * 1.1
		c.height = 0.18
		c.radial_segments = 16
		f.mesh = c
		f.material_override = mats.foam
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(f)
		f.global_position = foot + info.side * (k - 3) * info.width * 0.13 + info.out * randf_range(-0.4, 1.4)
	# Spray leaping up, and mist rolling off
	for kind in ["Spray", "Mist"]:
		var p := CPUParticles3D.new()
		p.name = kind
		var spray: bool = kind == "Spray"
		p.amount = 70 if spray else 46
		p.lifetime = 1.3 if spray else 3.4
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(info.width * 0.45, 0.3, 0.8)
		p.direction = Vector3(0, 1, 0.5)
		p.spread = 30.0 if spray else 50.0
		p.initial_velocity_min = 2.5 if spray else 0.5
		p.initial_velocity_max = 5.0 if spray else 1.4
		p.gravity = Vector3(0, -7.0, 0) if spray else Vector3(0, 0.25, 0)
		var ball := SphereMesh.new()
		ball.radius = 0.12 if spray else 0.6
		ball.height = ball.radius * 2.0
		ball.radial_segments = 6
		ball.rings = 3
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.97, 1.0, 0.7 if spray else 0.22)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ball.material = m
		p.mesh = ball
		var fade := Curve.new()
		fade.add_point(Vector2(0, 0.4))
		fade.add_point(Vector2(0.3, 1))
		fade.add_point(Vector2(1, 0))
		p.scale_amount_curve = fade
		root.add_child(p)
		p.global_transform = Transform3D(Basis(Vector3.UP, yaw), foot + Vector3(0, 0.2, 0))
	# A rainbow arching through the spray
	var bow := MeshInstance3D.new()
	bow.name = "Rainbow"
	bow.mesh = _arc_mesh(info.width * 0.55, info.width * 0.12, 24)
	bow.material_override = mats.rainbow
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bow)
	bow.global_transform = Transform3D(Basis(Vector3.UP, yaw), foot + info.out * 2.2 + Vector3(0, -0.4, 0))
	# Tumbled boulders round the pool, a mossy one or two
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(info.id)
	for k in 8:
		var s := rng.randf_range(0.8, 2.0)
		var across: float = (rng.randf_range(0.55, 0.85) * info.width) * (1.0 if k % 2 == 0 else -1.0)
		_rock(root, "Splash Boulder", _at(info, info.front + rng.randf_range(0.0, 4.0), across, info.splash_y + s * 0.2),
			Vector3(s * 1.3, s, s * 1.1), rng.randf() * TAU, mats, 50 + k, false)
	# Its rush, loud close by
	var rush := AudioStreamPlayer3D.new()
	rush.name = "Big Rush"
	rush.set_script(load("res://scripts/ambient_loop.gd"))
	rush.set("sound", "waterfall")
	rush.unit_size = 9.0
	rush.max_distance = 60.0
	rush.volume_db = -3.0
	root.add_child(rush)
	rush.global_position = foot + Vector3(0, 1.0, 0)


static func _arc_mesh(radius: float, band: float, segs: int) -> ArrayMesh:
	# A flat half-ring standing up, UV.y across the band (0 outside, 1 inside)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := PI * i / segs
		var a1 := PI * (i + 1) / segs
		var o0 := Vector3(cos(a0), sin(a0), 0) * radius
		var o1 := Vector3(cos(a1), sin(a1), 0) * radius
		var i0 := Vector3(cos(a0), sin(a0), 0) * (radius - band)
		var i1 := Vector3(cos(a1), sin(a1), 0) * (radius - band)
		for v in [[o0, Vector2(i / float(segs), 0)], [o1, Vector2((i + 1) / float(segs), 0)], [i0, Vector2(i / float(segs), 1)],
				[o1, Vector2((i + 1) / float(segs), 0)], [i1, Vector2((i + 1) / float(segs), 1)], [i0, Vector2(i / float(segs), 1)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


static func _cove(scene: Node, root: Node3D, info: Dictionary, mats: Dictionary, look: String) -> void:
	# The secret cove behind the curtain
	var yaw := atan2(info.out.x, info.out.z)
	var w: float = info.width
	var depth: float = info.front - info.back + 0.4
	var mid_out: float = (info.front + info.back) / 2.0
	# Its floor: a flat rock shelf (solid), and a ramp down at the front where it stands above the water or ground
	var floor_size := Vector3(w + 0.4, 1.0, depth + 1.4)
	var fl := _slab(root, "Cove Floor", _at(info, mid_out - 0.4, 0.0, info.floor_y - 0.5), floor_size, yaw, mats, true)
	fl.set_meta("surface", "stone")
	var front_ground := _ground((scene as Node3D).get_world_3d(), _at(info, info.front + 3.6, 0.0, 0.0), info.floor_y + 2.0, root)
	var rise: float = info.floor_y - front_ground
	if rise > 0.25:
		var run := maxf(rise * 2.4, 3.2)
		var ramp := _slab(root, "Cove Ramp", Vector3.ZERO, Vector3(w * 0.5, 0.5, sqrt(run * run + rise * rise) + 0.6), 0.0, mats, true)
		var start := _at(info, info.front + 0.6, 0.0, info.floor_y)
		var end := _at(info, info.front + 0.6 + run, 0.0, front_ground)
		var dir := (end - start).normalized()
		var right := Vector3.UP.cross(dir).normalized()
		var up := dir.cross(right).normalized()
		ramp.global_transform = Transform3D(Basis(right, up, -dir).orthonormalized(), (start + end) / 2.0 - up * 0.25)
	# Glowing crystals in the back corners, glowcaps, and a soft light
	var glow_cols := {"alien": [Color(0.4, 1.0, 0.95), Color(1.0, 0.5, 0.9)], "earth": [Color(0.6, 0.85, 1.0), Color(0.75, 1.0, 0.7)],
		"sand": [Color(1.0, 0.75, 0.4), Color(0.5, 0.95, 1.0)]}[look] as Array
	for s in [-1.0, 1.0]:
		for k in 3:
			var c := MeshInstance3D.new()
			c.name = "Cove Crystal"
			var cm := CylinderMesh.new()
			var len := randf_range(0.7, 1.6)
			cm.top_radius = 0.0
			cm.bottom_radius = len * 0.18
			cm.height = len
			cm.radial_segments = 5
			c.mesh = cm
			var col: Color = glow_cols[k % 2]
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = 1.6
			m.roughness = 0.15
			c.material_override = m
			root.add_child(c)
			var at := _at(info, info.inner + 0.5 + k * 0.4, s * (w / 2.0 - 0.9 - k * 0.3), info.floor_y + len * 0.4)
			c.global_transform = Transform3D(Basis(Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)).normalized()
				if k == 1 else Vector3.FORWARD, randf_range(0.1, 0.4)), at)
	var light := OmniLight3D.new()
	light.name = "Cove Glow"
	light.light_color = glow_cols[0]
	light.light_energy = 1.4
	light.omni_range = maxf(w * 0.6, 6.0)
	root.add_child(light)
	light.global_position = _at(info, info.inner + 1.2, 0.0, info.floor_y + 2.2)
	for k in 5:
		var cap := MeshInstance3D.new()
		cap.name = "Cove Glowcap"
		var sm := SphereMesh.new()
		var r := randf_range(0.12, 0.22)
		sm.radius = r
		sm.height = r
		sm.is_hemisphere = true
		cap.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = glow_cols[1]
		m.emission_enabled = true
		m.emission = glow_cols[1]
		m.emission_energy_multiplier = 1.2
		cap.material_override = m
		root.add_child(cap)
		cap.global_position = _at(info, info.inner + randf_range(0.4, 1.8), randf_range(-w * 0.4, w * 0.4), info.floor_y + 0.02)
	_chest(root, info)


static func _chest(root: Node3D, info: Dictionary) -> void:
	# A little treasure chest at the back of the cove: sparkles and a Remnant, the first time only
	var flag := "cove_%s_%s" % [_place(root), info.id]
	var chest := Node3D.new()
	chest.name = "Cove Chest"
	chest.set_meta("flag", flag)
	root.add_child(chest)
	chest.global_transform = Transform3D(Basis(Vector3.UP, atan2(info.out.x, info.out.z)),
		_at(info, info.inner + 0.9, 0.0, info.floor_y))
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.32, 0.6)
	wood.roughness = 0.8
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var body := MeshInstance3D.new()
	body.name = "Body"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.5, 0.6)
	body.mesh = bm
	body.material_override = wood
	body.position.y = 0.25
	chest.add_child(body)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.94, 0.08, 0.64)
	band.mesh = bb
	band.material_override = gold
	band.position.y = 0.4
	chest.add_child(band)
	var hinge := Node3D.new()
	hinge.name = "Lid"
	hinge.position = Vector3(0, 0.5, -0.3)
	chest.add_child(hinge)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.3
	lm.bottom_radius = 0.3
	lm.height = 0.9
	lm.radial_segments = 12
	lid.mesh = lm
	lid.material_override = wood
	lid.rotation.z = PI / 2.0
	lid.position = Vector3(0, 0.0, 0.3)
	lid.scale = Vector3(0.6, 1.0, 1.0)
	hinge.add_child(lid)
	var lock := MeshInstance3D.new()
	var lk := BoxMesh.new()
	lk.size = Vector3(0.14, 0.16, 0.06)
	lock.mesh = lk
	lock.material_override = gold
	lock.position = Vector3(0, 0.42, 0.31)
	chest.add_child(lock)
	if Dialogue.flags.get(flag, false):
		hinge.rotation.x = -1.9
	var spot := USE_SPOT.make(Vector3(0, 0.4, 0.6), func() -> String:
			return "" if Dialogue.flags.get(flag, false) else "open the chest",
		func() -> void: open_chest(chest), 1.6, 1.4)
	spot.name = "Spot"
	chest.add_child(spot)


static func open_chest(chest: Node3D) -> bool:
	# Opens a cove's chest: the reward the first time. Returns whether it gave anything (tests call it).
	var flag: String = chest.get_meta("flag")
	if Dialogue.flags.get(flag, false):
		return false
	Dialogue.flags[flag] = true
	var lid := chest.get_node("Lid") as Node3D
	if chest.is_inside_tree():
		var tw := chest.create_tween()
		tw.tween_property(lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.play_at("pickup", chest.global_position)
		Fx.burst(chest, Vector3(0, 0.7, 0), Color(1.0, 0.85, 0.4), 18, 0.08, 2.5, -2.0, 1.0)
	else:
		lid.rotation.x = -1.9
	Game.add_sparkles(COVE_SPARKLES, "a secret cove")
	Remnants.add(COVE_REMNANTS, "a secret cove")
	Game.message("A secret cove! +%d sparkles, +%d Remnant" % [COVE_SPARKLES, COVE_REMNANTS])
	return true


static func _place(root: Node) -> String:
	var s := root.get_tree().current_scene if root.is_inside_tree() else null
	if s == null:
		return "void"
	var p := s.scene_file_path
	if p.contains("earth"):
		return "earth"
	if p.contains("rhythm"):
		return "rhythm"
	return "void"


# Rock -----------------------------------------------------------------------------------------------------------------
static func _rock(root: Node3D, name: String, at: Vector3, size: Vector3, yaw: float, mats: Dictionary, seed_no: int,
		solid: bool) -> MeshInstance3D:
	# A lumpy faceted rock about `size`, its colour mottled between the place's two rock colours. Solid if asked.
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _lumpy(size, seed_no, mats.rock_cols)
	mi.material_override = mats.rock
	root.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	if solid:
		var body := StaticBody3D.new()
		body.name = name + " Body"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = size * 0.92
		cs.shape = bx
		body.add_child(cs)
		mi.add_child(body)
		body.set_meta("surface", "stone")
	return mi


static func _slab(root: Node3D, name: String, at: Vector3, size: Vector3, yaw: float, mats: Dictionary, solid: bool) -> MeshInstance3D:
	# A flat-topped rock shelf (only its sides are lumpy, so it's good to walk on)
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = (mats.rock_cols[0] as Color).lerp(mats.rock_cols[1], 0.25)
	m.roughness = 0.9
	mi.material_override = m
	root.add_child(mi)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	if solid:
		var body := StaticBody3D.new()
		body.name = name + " Body"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = size
		cs.shape = bx
		body.add_child(cs)
		mi.add_child(body)
	return mi


static func _lumpy(size: Vector3, seed_no: int, cols: Array) -> ArrayMesh:
	# A box pushed in and out by noise, flat shaded, so it reads as a chunk of rock
	var noise := FastNoiseLite.new()
	noise.seed = seed_no
	noise.frequency = 0.9
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	bm.subdivide_width = 3
	bm.subdivide_height = 3
	bm.subdivide_depth = 3
	var arrays := bm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var key := (v * 10.0).round() / 10.0                     # the same corner moves the same way on every face
		var push := 1.0 + noise.get_noise_3dv(key * 2.0) * 0.28
		moved[i] = Vector3(v.x * size.x, v.y * size.y, v.z * size.z) * push
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size(), 3):
		var a := moved[idx[t]]
		var b := moved[idx[t + 1]]
		var c := moved[idx[t + 2]]
		var mid := (a + b + c) / 3.0
		var n := (b - a).cross(c - a).normalized()
		if n.dot(mid) < 0.0:
			n = -n                                               # (pointing out of the rock)
		var mix_k := clampf(0.5 + noise.get_noise_3dv(mid * 3.0 + Vector3(9, 0, 0)) * 0.9 + (0.25 if n.y > 0.6 else 0.0), 0.0, 1.0)
		var col: Color = (cols[0] as Color).lerp(cols[1], mix_k * 0.7)
		for v in [a, b, c]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()
