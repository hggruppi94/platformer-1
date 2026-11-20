extends RefCounted

# The Void's Museum and the plateau's first waterfall, joined up (Hayden, 20 Nov 2026: "I feel like the museum building
# should be larger and in a better spot unless it merges with the outside waterfall and has some sort of water feature
# on the inside but right now doesnt make much sense"). The builder (tools/build_town.gd) stood a small dome with its
# back to the path and its door right in the falls' spray. Now, as the town loads (WorldDetail calls place() before the
# falls are built, so scripts/big_falls.gd sees it where it ends up):
#   - it's GROW times bigger and turned YAW, so its door looks out over the lake shore, not into the spray
#   - a stream runs out of the falls' pool and in under an arched water gate in its side ("Falls Stream"), and the
#     falls' rock arch leaves that side open (the gate is in group "fall_opening": big_falls.gd _doors), so the water
#     and the secret cove behind it run straight into the Museum
#   - inside, the stream comes in through the wall and runs to a pool with a waterfall of its own (the Falls Room,
#     tools/build_interiors.gd _museum)
# Everything that looks for it ("Museum", its Door, "FromMuseum") finds it by name, so they all follow it.

const GROW := 1.2                     # how much bigger than the builder made it
const YAW := 0.75                     # which way its door faces (it faced straight into the falls' pool)
const GATE_DIR := Vector2(-0.22, 0.975)     # from its middle to the water gate, on the side facing the falls
const STREAM := [Vector2(-39.4, -38.0), Vector2(-40.3, -39.6), Vector2(-41.2, -40.9)]    # from the pool to the gate
const STREAM_W := 1.3

const STREAM_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 color : source_color = vec4(0.45, 0.85, 1.0, 0.8);
void fragment() {
	float s = fract(UV.y * 3.0 + sin(UV.x * 9.0) * 0.08 - TIME * 0.9);
	ALBEDO = mix(color.rgb, vec3(1.0), smoothstep(0.82, 1.0, s) * 0.55);
	EMISSION = color.rgb * 0.25;
	ROUGHNESS = 0.05;
	ALPHA = color.a;
}"""


static func place(scene: Node) -> bool:
	var m := scene.get_node_or_null("Museum") as Node3D
	if m == null or m.has_meta("falls_museum"):
		return false
	m.set_meta("falls_museum", true)
	var out := m.get_node_or_null("FromMuseum") as Node3D
	var old_out := out.global_position if out else Vector3.INF
	var at := m.global_position
	m.global_transform = Transform3D(Basis(Vector3.UP, YAW).scaled(Vector3.ONE * GROW), at)
	if out:
		# The way out stays on the ground in front of the door, the right size (a marker's scale isn't wanted)
		out.scale = Vector3.ONE / GROW
		var p := out.global_position
		out.global_position = Vector3(p.x, _ground(scene, p, m) + 1.0, p.z)
		var player := scene.find_child("Player", true, false) as Node3D
		if player and player.global_position.distance_to(old_out) < 2.5:
			# Someone just out of the Museum was put at the old way out: they move with it, turned the way
			# player.gd turns her at any marker (only her model and the camera)
			player.global_position = out.global_position + Vector3(0, 0.2, 0)
			player.rotation = Vector3.ZERO
			var yaw := out.global_rotation.y
			var visual := player.get_node_or_null("Visual") as Node3D
			if visual:
				visual.rotation.y = yaw + PI
			var arm = player.get("spring_arm")
			if arm is Node3D:
				(arm as Node3D).rotation.y = yaw
	_clear_round(scene, m)
	_stream(scene, m)
	return true


static func gate_spot(m: Node3D) -> Vector3:
	# Where the water gate is: on the dome's foot, on the side facing the falls
	var r := 7.0 * GROW
	return m.global_position + Vector3(GATE_DIR.x, 0, GATE_DIR.y).normalized() * (r - 0.35)


static func _ground(scene: Node, at: Vector3, skip: Node = null) -> float:
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 30.0, at.z), Vector3(at.x, at.y - 30.0, at.z))
	var ex: Array[RID] = []
	if skip:
		for b in skip.find_children("*", "CollisionObject3D", true, false):
			ex.append((b as CollisionObject3D).get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else at.y


static func _clear_round(scene: Node, m: Node3D) -> void:
	# Crystal clusters and grind rails the builder put just outside the old dome are inside the bigger one now. The
	# trees and plants see it for themselves (scripts/plant_clearance.gd looks again a second after the town loads).
	var r := 7.0 * GROW + 1.2
	var c := m.global_position
	var crystals := scene.get_node_or_null("Crystals")
	if crystals:
		for k in crystals.get_children():
			if k is Node3D and not (k is MultiMeshInstance3D) and _flat((k as Node3D).global_position, c) < r + 1.0:
				crystals.remove_child(k)
				k.queue_free()
	var rails := scene.get_node_or_null("Town Rails")
	if rails:
		for k in rails.get_children():
			if k is Node3D and _flat((k as Node3D).global_position, c) < r:
				k.queue_free()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _stream(scene: Node, m: Node3D) -> void:
	# The stream from the falls' pool to the gate, the gate itself, and its marker for big_falls.gd
	var root := Node3D.new()
	root.name = "Falls Stream"
	scene.add_child(root)
	var water := ShaderMaterial.new()
	water.shader = Shader.new()
	water.shader.code = STREAM_SHADER
	var stone := StandardMaterial3D.new()
	stone.resource_name = "Stream Stone"
	stone.albedo_color = Color(0.62, 0.6, 0.78)
	stone.roughness = 0.85
	var gate := gate_spot(m)
	var pts: Array[Vector3] = []
	for p: Vector2 in STREAM:
		var v := Vector3(p.x, 0, p.y)
		v.y = _ground(scene, v, m)
		pts.append(v)
	pts.append(Vector3(gate.x, _ground(scene, gate, m), gate.z))
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var flat := Vector3(b.x - a.x, 0, b.z - a.z)
		var length := flat.length() + 0.3
		var mid := (a + b) / 2.0
		var yaw := atan2(flat.x, flat.z)
		var plane := PlaneMesh.new()
		plane.size = Vector2(STREAM_W, length)
		var w := MeshInstance3D.new()
		w.name = "Stream Water %d" % k
		w.mesh = plane
		w.material_override = water
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(w)
		w.global_position = mid + Vector3(0, 0.1, 0)
		w.rotation.y = yaw
		# Pebbles along both banks (not solid: it's a little stream you step over)
		for s: float in [-1.0, 1.0]:
			for j in int(length / 0.55) + 1:
				var t := (j + 0.5) / (int(length / 0.55) + 1)
				var side := Vector3(cos(yaw), 0, -sin(yaw)) * s * (STREAM_W / 2.0 + 0.15)
				var peb := MeshInstance3D.new()
				peb.name = "Stream Pebble %d %d" % [k, j + (0 if s < 0 else 100)]
				var sm := SphereMesh.new()
				var rad := 0.17 + 0.07 * sin(j * 2.3 + s)
				sm.radius = rad
				sm.height = rad * 1.2
				sm.radial_segments = 8
				sm.rings = 4
				peb.mesh = sm
				peb.material_override = stone
				root.add_child(peb)
				peb.global_position = a.lerp(b, t) + side + Vector3(0, 0.06, 0)
	_water_gate(root, m, gate, stone)
	var mark := Marker3D.new()
	mark.name = "Water Gate Opening"
	root.add_child(mark)
	mark.global_position = Vector3(gate.x, _ground(scene, gate, m) + 1.2, gate.z)
	mark.add_to_group("fall_opening")


static func _water_gate(root: Node3D, m: Node3D, at: Vector3, stone: Material) -> void:
	# An arch of stone blocks in the dome's foot, dark inside with water glowing in it and an iron grille, and
	# "The Falls Room" over it
	var g := Node3D.new()
	g.name = "Water Gate"
	root.add_child(g)
	var out := Vector3(at.x - m.global_position.x, 0, at.z - m.global_position.z).normalized()
	g.global_position = Vector3(at.x, m.global_position.y, at.z)
	g.rotation.y = atan2(out.x, out.z)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.1, 0.18)
	dark.emission_enabled = true
	dark.emission = Color(0.2, 0.55, 0.9)
	dark.emission_energy_multiplier = 0.6
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.18, 0.25)
	iron.metallic = 0.7
	iron.roughness = 0.4
	_box(g, "Gate Dark", Vector3(1.7, 1.5, 0.3), Vector3(0, 0.75, 0.1), dark)
	for s: float in [-1.0, 1.0]:
		_box(g, "Gate Pillar", Vector3(0.5, 1.9, 0.7), Vector3(s * 1.1, 0.95, 0.25), stone)
	for k in 7:                                          # the arch's blocks, round the top
		var a := PI * k / 6.0
		var p := Vector3(cos(a) * 1.1, 1.85 + sin(a) * 0.75, 0.3)
		var b := _box(g, "Gate Arch Block", Vector3(0.48, 0.42, 0.7), p, stone)
		b.rotation.z = a - PI / 2
	for k in 5:
		var bar := _box(g, "Gate Bar", Vector3(0.06, 1.6, 0.06), Vector3(-0.6 + k * 0.3, 0.8, 0.45), iron)
		bar.name = "Gate Bar"
	var light := OmniLight3D.new()
	light.name = "Gate Glow"
	light.light_color = Color(0.45, 0.8, 1.0)
	light.light_energy = 0.8
	light.omni_range = 4.0
	g.add_child(light)
	light.position = Vector3(0, 0.8, 0.9)
	var title := Label3D.new()
	title.name = "Falls Room Sign"
	title.text = "The Falls Room"
	title.font_size = 44
	title.outline_size = 10
	title.modulate = Color(0.85, 0.95, 1.0)
	g.add_child(title)
	title.position = Vector3(0, 3.0, 0.7)


static func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	parent.add_child(mi)
	mi.position = pos
	return mi
