extends Node3D

# Builds the alien undergrowth when the scene loads (MultiMesh data can't be baked from a headless build):
# giant teal and purple leaves, glowing blue mushrooms and magenta/violet ferns, as in Sofi's picture.
# Where each plant goes, its kind, size, turn and colour are written by tools/build_town.gd (_foliage).
# Big mushroom caps are solid (and bouncy: scenes/player/player.gd), so you can hop across them.
#
# Walking through them: leaves, ferns and tall grass lean away from Nina and spring back (the shader reads her
# position from the "nina_pos" shader global), rustle or swish as she pushes through, and the odd leaf flutters off.
# Only what she's right next to parts, and not far (Hayden's day 1 playtest, 11 Nov 2026: the gap she left in the
# grass was far too big): grass within about 0.75 m bends, leaves and ferns within about 1 m.
#
# A plant that would grow through something solid (a building, a fence, a bench, a rail...) is left out when the
# world loads (scripts/plant_clearance.gd), so nothing pokes through walls.
# Small mushrooms light up with a "bloop" when she brushes them.

enum { LEAVES, FERN, MUSHROOM, GRASS }

@export var positions: PackedVector3Array
@export var kinds: PackedInt32Array
@export var sizes: PackedFloat32Array
@export var yaws: PackedFloat32Array
@export var colors: PackedColorArray
@export var stem_color := Color(0.85, 0.6, 0.85)
@export var leaf_glow := 0.22               # how much leaves and ferns light up in their own colour
@export var fern_glow := 0.35
@export var cap_glow := 0.8                 # mushroom caps
@export var max_lights := 14                # the biggest mushrooms also light the ground around them
@export var solid_cap_size := 2.2           # mushrooms at least this tall get a solid cap
@export var grass_glow := 0.12

const PlantClearance := preload("res://scripts/plant_clearance.gd")
const CELL := 6.0                           # metres: the grid used to find plants near her quickly
const SOUND_GAP := 0.28                     # seconds between rustles
var _grid := {}                             # Vector2i cell -> plant indices
var _reach := PackedFloat32Array()          # how close counts as touching each plant
var _cap_index := {}                        # small mushroom plant index -> its cap in the caps MultiMesh
var _caps_mm: MultiMesh
var _cap_cols: Array[Color] = []
var _touching := {}                         # plants she's in right now
var _flash := {}                            # cap index -> seconds of glow left
var _sound_wait := 0.0
var _player: CharacterBody3D
var left_out := 0                           # plants not grown because something solid is in their way
const RECHECK := [1.0, 4.0]                 # seconds after loading to look again (recheck())
var _parts := {}                            # plant index -> [[first instance in each MultiMesh], [one past its last]]
var _mms: Array = [null, null, null, null, null]      # leaves, ferns, stems, caps, grass
var _extras := {}                           # plant index -> its solid cap and light, if it has them

const PLANT_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform float glow = 0.1;
uniform float sway = 0.06;
uniform float push = 0.9;
uniform float reach = 1.4;
uniform float body_r = 0.38;      // her outline: how wide (metres from her middle)...
uniform float body_h = 1.5;       // ...and how tall
global uniform vec3 nina_pos;
void vertex() {
	// Gentle wind: tips move more than the base, each plant on its own beat
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float w = sin(TIME * 1.3 + o.x * 0.37 + o.z * 0.29) * sway * UV.y * UV.y;
	VERTEX.x += w;
	VERTEX.z += w * 0.6;
	// Part round her body only (Hayden, 14 Nov 2026: "should just be the outline of your character, not a big circle
	// around their body"): only the bits of a plant that would be inside her (an upright capsule about her size, from
	// her feet to over her head) are pushed out to just past its edge, roots staying put, so the plants hug her shape
	// as she walks or rides through and spring straight back behind her. `reach` and `push` are kept for old callers.
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 away = wp.xz - nina_pos.xz;
	float d = length(away);
	float up = wp.y - nina_pos.y;
	float in_height = smoothstep(-0.35, -0.05, up) * (1.0 - smoothstep(body_h, body_h + 0.25, up));
	float r = body_r * (up < 0.35 ? 0.8 : 1.0);           // a little narrower round her feet
	float inside = max(r + 0.06 - d, 0.0) * in_height * UV.y;
	vec2 out_dir = away / max(d, 0.001);
	vec3 shove = vec3(out_dir.x, -0.25, out_dir.y) * inside;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(shove, 0.0)).xyz;
}
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;                  // 0 on the midrib, 1 at the edge
	float rib = 1.0 - smoothstep(0.0, 0.07, across);
	float veins = smoothstep(0.82, 1.0, sin((UV.y * 16.0 - across * 3.0) * 3.14159)) * step(0.1, UV.y) * (1.0 - across);
	vec3 c = COLOR.rgb * (0.65 + 0.5 * (1.0 - across));
	c = mix(c, COLOR.rgb * 0.4 + vec3(0.55), rib * 0.55 + veins * 0.3);
	ALBEDO = c;
	ROUGHNESS = 0.55;
	EMISSION = COLOR.rgb * glow * (0.6 + rib);
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}"""

const CAP_SHADER := """shader_type spatial;
uniform float glow = 1.5;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	// Brighter toward the rim, with a scatter of little glowing dots
	float rim = smoothstep(0.2, 1.0, length(lp.xz));
	vec3 cell = floor(lp * 7.0);
	float rnd = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float dot_ = step(0.86, rnd) * (1.0 - smoothstep(0.18, 0.32, length(fract(lp * 7.0) - 0.5)));
	vec3 c = COLOR.rgb * (0.55 + 0.45 * rim);
	ALBEDO = mix(c, vec3(0.85, 1.0, 1.0), dot_);
	ROUGHNESS = 0.25;
	EMISSION = (COLOR.rgb * (0.5 + 0.8 * rim) + vec3(0.7, 1.0, 1.0) * dot_ * 1.5) * glow;
}"""


func _ready() -> void:
	var leaves: Array[Transform3D] = []
	var leaf_cols: Array[Color] = []
	var fronds: Array[Transform3D] = []
	var frond_cols: Array[Color] = []
	var stems: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var cap_cols: Array[Color] = []
	var blades: Array[Transform3D] = []
	var blade_cols: Array[Color] = []
	var lights := 0
	_reach.resize(positions.size())
	left_out = 0
	for i in positions.size():
		var p := positions[i]
		var s := sizes[i]
		_reach[i] = s * [0.75, 0.6, 0.5, 0.55][kinds[i]]
		if not _clear(i):
			_reach[i] = 0.0                                     # (never touched: it isn't there)
			left_out += 1
			continue
		var base := Basis(Vector3.UP, yaws[i])
		var rng := RandomNumberGenerator.new()
		rng.seed = i * 7919 + 13
		var cell := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(i)
		var had := [leaves.size(), fronds.size(), stems.size(), caps.size(), blades.size()]
		match kinds[i]:
			GRASS:
				blades.append(Transform3D(base * Basis.from_scale(Vector3(s, s, s)), p + Vector3(0, -0.05, 0)))
				blade_cols.append(colors[i])
			LEAVES:
				# A clump of 4-7 giant leaves fanning out from one spot
				var n := rng.randi_range(4, 7)
				for k in n:
					var b := base * Basis(Vector3.UP, TAU * k / n + rng.randf_range(-0.3, 0.3))
					b = b * Basis(Vector3.RIGHT, rng.randf_range(0.12, 0.5))          # lean outward
					var ls := s * rng.randf_range(0.7, 1.1)
					leaves.append(Transform3D(b * Basis.from_scale(Vector3.ONE * ls), p + Vector3(0, -0.05, 0)))
					leaf_cols.append(colors[i].lerp(colors[i].lightened(0.25), rng.randf() * 0.5))
			FERN:
				var n := rng.randi_range(8, 12)
				for k in n:
					var b := base * Basis(Vector3.UP, TAU * k / n + rng.randf_range(-0.2, 0.2))
					b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.25))
					var fs := s * rng.randf_range(0.75, 1.1)
					fronds.append(Transform3D(b * Basis.from_scale(Vector3.ONE * fs), p + Vector3(0, -0.03, 0)))
					frond_cols.append(colors[i].lerp(colors[i].darkened(0.3), rng.randf() * 0.6))
			MUSHROOM:
				var h := s
				var r := s * 0.09
				var cap_r := s * rng.randf_range(0.45, 0.6)
				var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(),
					rng.randf_range(0.0, 0.12))
				var b := base * tilt
				stems.append(Transform3D(b * Basis.from_scale(Vector3(r, h, r)), p + b * Vector3(0, h / 2 - 0.1, 0)))
				var top := p + b * Vector3(0, h - 0.1, 0)
				caps.append(Transform3D(b * Basis.from_scale(Vector3(cap_r, cap_r * 0.5, cap_r)), top))
				cap_cols.append(colors[i])
				if s < solid_cap_size:
					_cap_index[i] = caps.size() - 1
				if s >= solid_cap_size:
					var body := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					var cyl := CylinderShape3D.new()
					cyl.radius = cap_r * 0.9
					cyl.height = cap_r * 0.35
					cs.shape = cyl
					cs.position = top + Vector3(0, cap_r * 0.17, 0)
					body.add_child(cs)
					var cs2 := CollisionShape3D.new()
					var stem_shape := CylinderShape3D.new()
					stem_shape.radius = r
					stem_shape.height = h
					cs2.shape = stem_shape
					cs2.position = p + Vector3(0, h / 2, 0)
					body.add_child(cs2)
					add_child(body)
					_extras[i] = [body]
				if s >= solid_cap_size and lights < max_lights:
					var light := OmniLight3D.new()
					light.light_color = colors[i].lightened(0.3)
					light.light_energy = 1.4
					light.omni_range = cap_r * 4.0
					light.position = top - Vector3(0, 0.6, 0)
					add_child(light)
					_extras[i] = _extras.get(i, []) + [light]
					lights += 1
		_parts[i] = [had, [leaves.size(), fronds.size(), stems.size(), caps.size(), blades.size()]]

	_mms[0] = _add_multimesh(_leaf_mesh(), leaves, leaf_cols, _plant_material(leaf_glow, 0.05, 1.0, 0.55), "Leaves")
	_mms[1] = _add_multimesh(_fern_mesh(), fronds, frond_cols, _plant_material(fern_glow, 0.08, 1.0, 0.5), "Ferns")
	_mms[4] = _add_multimesh(_grass_mesh(), blades, blade_cols, _plant_material(grass_glow, 0.1, 0.75, 0.35), "Grass")
	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = stem_color
	stem_mat.roughness = 0.5
	stem_mat.emission_enabled = true
	stem_mat.emission = stem_color
	stem_mat.emission_energy_multiplier = 0.25
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.75
	stem_mesh.bottom_radius = 1.0
	stem_mesh.height = 1.0
	stem_mesh.radial_segments = 10
	stem_mesh.rings = 1
	var stem_cols: Array[Color] = []
	stem_cols.resize(stems.size())
	stem_cols.fill(Color.WHITE)
	_mms[2] = _add_multimesh(stem_mesh, stems, stem_cols, stem_mat, "Stems")
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.0
	cap_mesh.height = 1.0
	cap_mesh.is_hemisphere = true
	cap_mesh.radial_segments = 24
	cap_mesh.rings = 8
	var cap_mat := ShaderMaterial.new()
	var cap_sh := Shader.new()
	cap_sh.code = CAP_SHADER
	cap_mat.shader = cap_sh
	cap_mat.set_shader_parameter("glow", cap_glow)
	_caps_mm = _add_multimesh(cap_mesh, caps, cap_cols, cap_mat, "Caps")
	_mms[3] = _caps_mm
	_cap_cols = cap_cols
	# Lots of things are put into the world just after it loads (boosters, the bosses' yards, quest props...): look
	# again once they're in, and take away any plant they've landed on
	for wait in RECHECK:
		get_tree().create_timer(wait).timeout.connect(recheck)


func recheck() -> void:
	if not is_inside_tree():
		return
	for i in _parts:
		if _reach[i] > 0.0 and not _clear(i):
			_take_away(i)


func _take_away(i: int) -> void:
	# Plant i goes: its leaves, fronds, stem, cap or blades shrink to nothing, and its solid cap and light go
	var hidden := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -500, 0))
	var from: Array = _parts[i][0]
	var to: Array = _parts[i][1]
	for k in _mms.size():
		var mm: MultiMesh = _mms[k]
		if mm == null:
			continue
		for j in range(from[k], to[k]):
			mm.set_instance_transform(j, hidden)
	for n in _extras.get(i, []):
		if is_instance_valid(n):
			(n as Node).queue_free()
	_cap_index.erase(i)
	_touching.erase(i)
	_reach[i] = 0.0
	left_out += 1


func _physics_process(delta: float) -> void:
	# Which plants is she pushing through? Rustle, flutter and light up accordingly.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	_sound_wait -= delta
	var feet := _player.global_position - Vector3(0, 0.8, 0)
	var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 1.0
	var c := Vector2i(floori(feet.x / CELL), floori(feet.z / CELL))
	var now := {}
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for i in _grid.get(c + Vector2i(dx, dz), []):
				var p := positions[i]
				if feet.y > p.y + sizes[i] * 0.9 or feet.y < p.y - 0.6:
					continue                                  # jumping over it, or it's on another level
				if Vector2(feet.x - p.x, feet.z - p.z).length() < _reach[i]:
					now[i] = true
	for i in now:
		if not _touching.has(i) and kinds[i] == MUSHROOM and _cap_index.has(i):
			_flash[_cap_index[i]] = 0.8                        # a small mushroom lights up
			Audio.play_at("bloop", positions[i] + Vector3(0, sizes[i], 0), -6.0, 0.15)
	_touching = now
	if moving and _sound_wait <= 0.0 and not now.is_empty():
		var kind := -1
		for i in now:
			if kinds[i] == LEAVES or (kind == -1 and kinds[i] != MUSHROOM):
				kind = kinds[i]
		if kind != -1:
			_sound_wait = SOUND_GAP
			Audio.play_at("rustle" if kind == LEAVES else "swish", feet + Vector3(0, 0.5, 0), -7.0, 0.15)
			if kind != GRASS and randf() < 0.5:                 # a leaf or two flutters off
				var i: int = now.keys()[0]
				Fx.burst(self, feet + Vector3(0, 1.0, 0), colors[i], 3, 0.07, 1.2, -1.0, 1.3)


func _process(delta: float) -> void:
	for idx in _flash.keys():
		_flash[idx] -= delta
		var k := clampf(_flash[idx] / 0.8, 0.0, 1.0)
		_caps_mm.set_instance_color(idx, _cap_cols[idx].lerp(Color(1, 1, 1), k * 0.7))
		if _flash[idx] <= 0.0:
			_flash.erase(idx)


func touching_kinds() -> Array:
	# What she's in right now (for tests): e.g. [LEAVES, GRASS]
	var out := []
	for i in _touching:
		if not kinds[i] in out:
			out.append(kinds[i])
	return out


func _plant_material(glow: float, sway: float, reach: float, push: float) -> ShaderMaterial:
	# reach: how near she has to be before it bends (metres); push: how far its tips lean away
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = PLANT_SHADER
	m.shader = sh
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("reach", reach)
	m.set_shader_parameter("push", push)
	return m


func _clear(i: int) -> bool:
	# Is there room for plant i, with nothing solid where its leaves, fronds, stalk or blades would be? A box round
	# the middle of the plant (a bit inside its outline, so a leaf tip brushing a wall is fine)
	var p := positions[i]
	var s := sizes[i]
	var half := _reach[i] * 0.6
	var low := 0.25
	var high := maxf(s * 0.75, low + 0.2)
	if kinds[i] == MUSHROOM:
		half = s * 0.3
		high = s
	var xf := Transform3D(Basis(), p + Vector3(0, (low + high) / 2.0, 0))
	return PlantClearance.box_clear(self, xf, Vector3(half * 2.0, high - low, half * 2.0), self)


func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D], cols: Array[Color], material: Material,
		node_name := "") -> MultiMesh:
	if xforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	if node_name != "":
		mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = material
	add_child(mmi)
	return mm


func _leaf_mesh() -> ArrayMesh:
	# One giant leaf, 1 unit long: a short stalk rising steeply, then a broad cupped blade that arcs over and droops.
	# UV.x runs across the blade (0.5 = midrib), UV.y along it (0 = base, 1 = tip).
	const ROWS := 26
	const COLS := 7
	const WIDTH := 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine: Array[Vector3] = []
	var tangent: Array[Vector3] = []
	var p := Vector3.ZERO
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var a := deg_to_rad(82.0 - 95.0 * pow(t, 1.6))          # elevation of the midrib
		var d := Vector3(0, sin(a), cos(a))
		spine.append(p)
		tangent.append(d)
		p += d / ROWS
	var grid := []
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var blade := clampf((t - 0.16) / 0.84, 0.0, 1.0)
		var w := 0.02 + WIDTH * 0.5 * pow(sin(PI * pow(blade, 0.75)), 0.85)
		var n: Vector3 = Vector3.RIGHT.cross(tangent[r]) * -1.0  # surface normal (up side of the blade)
		var row := []
		for c in COLS:
			var u := float(c) / (COLS - 1)
			var across := (u - 0.5) * 2.0
			var cup := across * across * w * 0.3 + sin(t * 30.0 + across * 2.0) * 0.006 * absf(across)
			row.append(spine[r] + Vector3.RIGHT * across * w + n * cup)
		grid.append(row)
	for r in ROWS:
		for c in COLS - 1:
			var quad := [Vector2i(r, c), Vector2i(r, c + 1), Vector2i(r + 1, c + 1), Vector2i(r + 1, c)]
			for idx in [0, 1, 2, 0, 2, 3]:
				var q: Vector2i = quad[idx]
				st.set_uv(Vector2(float(q.y) / (COLS - 1), float(q.x) / ROWS))
				st.add_vertex(grid[q.x][q.y])
	st.generate_normals()
	return st.commit()


func _grass_mesh() -> ArrayMesh:
	# A clump of tall grass, 1 unit high: 14 thin tapering blades fanning out and curving over at the tips.
	# UV.y runs up each blade (0 = root, 1 = tip) so the wind and her push bend the tips most.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for b in 14:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.3)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.15, 0.4)
		var h := rng.randf_range(0.7, 1.0)
		var w := rng.randf_range(0.03, 0.05)
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var segs := 4
		for k in segs:
			var t0 := float(k) / segs
			var t1 := float(k + 1) / segs
			var p0 := root + Vector3(0, h * t0, 0) + lean * t0 * t0
			var p1 := root + Vector3(0, h * t1, 0) + lean * t1 * t1
			var w0 := 1.0 - t0
			var w1 := 1.0 - t1
			_tri(st, p0 - side * w0, p0 + side * w0, p1 + side * w1, Vector2(0.4, t0), Vector2(0.6, t0), Vector2(0.6, t1))
			_tri(st, p0 - side * w0, p1 + side * w1, p1 - side * w1, Vector2(0.4, t0), Vector2(0.6, t1), Vector2(0.4, t1))
	st.generate_normals()
	return st.commit()


func _fern_mesh() -> ArrayMesh:
	# One fern frond, 1 unit long: an arching stem with pairs of narrow leaflets that shrink toward the tip.
	const SEGS := 18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := Vector3.ZERO
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for i in SEGS + 1:
		var t := float(i) / SEGS
		var a := deg_to_rad(62.0 - 100.0 * pow(t, 1.4))
		var d := Vector3(0, sin(a), cos(a))
		pts.append(p)
		tans.append(d)
		p += d / SEGS
	for i in SEGS:
		var t := float(i) / SEGS
		var n: Vector3 = Vector3.RIGHT.cross(tans[i]) * -1.0
		# stem: a thin strip
		var sw := 0.012 * (1.0 - t * 0.7)
		_tri(st, pts[i] - Vector3.RIGHT * sw, pts[i] + Vector3.RIGHT * sw, pts[i + 1], Vector2(0.45, t), Vector2(0.55, t),
			Vector2(0.5, t + 1.0 / SEGS))
		if t < 0.08:
			continue
		var length := 0.2 * pow(1.0 - t, 0.55) + 0.02
		var base_w := 0.035 * (1.0 - t * 0.6)
		for side: float in [-1.0, 1.0]:
			var root := pts[i].lerp(pts[i + 1], 0.5)
			var tip := root + Vector3.RIGHT * side * length + tans[i] * length * 0.45 - n * length * 0.25
			var a := root - tans[i] * base_w
			var b := root + tans[i] * base_w
			var mid := root.lerp(tip, 0.5) + n * 0.01
			var u_tip := 0.5 + side * 0.5
			var u_mid := 0.5 + side * 0.25
			_tri(st, a, b, mid, Vector2(0.5, t), Vector2(0.5, t), Vector2(u_mid, t))
			_tri(st, a, mid, tip, Vector2(0.5, t), Vector2(u_mid, t), Vector2(u_tip, t))
			_tri(st, b, tip, mid, Vector2(0.5, t), Vector2(u_tip, t), Vector2(u_mid, t))
	st.generate_normals()
	return st.commit()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
