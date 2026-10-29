class_name FaceSculpt
extends RefCounted

# Face sculpting for the character creator (scripts/creator.gd): bigger or smaller eyes, eyes further apart or closer
# together, and bigger or smaller noses, ears and mouths, from tiny to cartoonishly huge.
#
# Every character is one skinned mesh with every part of their face riding on the head bone, so there are no bones to
# scale an eye or an ear by. Instead each body says where its face parts are (Hero.BODIES "face"), and the hero gets
# their own copy of the mesh with those parts' points moved: each part is a separate piece of the mesh in Blender
# (an eyeball, an ear), so it's found as a connected piece near where the body says, and scaled about its own root
# (an ear grows out from where it joins the head, an eye from its middle). The head bone carries the moved points
# just the same, so running, skating and every animation keep the new face.

# The hero's sculpt values (in Game.hero; 1 is as drawn), and how far each one goes
const KEYS := ["eyes", "eye_gap", "nose", "ears", "mouth"]
const RANGES := {"eyes": [0.45, 2.3], "eye_gap": [0.65, 1.6], "nose": [0.3, 3.0], "ears": [0.3, 3.0],
	"mouth": [0.45, 2.2]}
const NAMES := {"eyes": "Eyes", "eye_gap": "Eye spacing", "nose": "Nose", "ears": "Ears", "mouth": "Mouth"}
# Which feature each value moves (a body with no ears has no ear slider)
const FEATURE := {"eyes": "eyes", "eye_gap": "eyes", "nose": "nose", "ears": "ears", "mouth": "mouth"}

# Ready-made faces to start from. "As drawn" puts everything back; the rest push a look a long way, and the sliders
# fine-tune from there.
const PRESETS := [
	{"name": "As drawn", "eyes": 1.0, "eye_gap": 1.0, "nose": 1.0, "ears": 1.0, "mouth": 1.0},
	{"name": "Big-eyed cutie", "eyes": 1.85, "eye_gap": 1.05, "nose": 0.6, "ears": 1.15, "mouth": 0.75},
	{"name": "Goofball", "eyes": 1.45, "eye_gap": 1.4, "nose": 2.1, "ears": 1.7, "mouth": 1.7},
	{"name": "Snooty", "eyes": 0.75, "eye_gap": 0.85, "nose": 2.6, "ears": 0.8, "mouth": 0.6},
	{"name": "Bat ears", "eyes": 1.25, "eye_gap": 1.0, "nose": 0.8, "ears": 2.8, "mouth": 0.9},
	{"name": "Beady", "eyes": 0.5, "eye_gap": 0.75, "nose": 1.4, "ears": 1.1, "mouth": 1.0},
	{"name": "Tiny face", "eyes": 0.7, "eye_gap": 0.8, "nose": 0.45, "ears": 0.6, "mouth": 0.55},
	{"name": "Wise old soul", "eyes": 0.8, "eye_gap": 1.1, "nose": 1.8, "ears": 2.0, "mouth": 0.7},
	{"name": "Wide and happy", "eyes": 1.2, "eye_gap": 1.55, "nose": 1.0, "ears": 1.3, "mouth": 2.1},
]

# The parts an eye can be made of (a body's spec can add more), and the brows that move with it
const EYE_PARTS := ["Eye White", "Iris", "Iris Light", "Pupil", "Eye Shine", "Eye", "Glasses", "Lens Shine", "Brow"]
const BROW := "Brow"

static var _meshes := {}      # original mesh -> its surfaces' arrays and pieces


static func value(hero: Dictionary, key: String) -> float:
	return clampf(float(hero.get(key, 1.0)), RANGES[key][0], RANGES[key][1])


static func has_feature(face: Dictionary, key: String) -> bool:
	return face.has(FEATURE[key])


static func slider_name(face: Dictionary, key: String) -> String:
	return str(face.get(key + "_name", NAMES[key]))


static func preset_index(hero: Dictionary) -> int:
	# Which preset the hero's face is now, or -1 once the sliders have moved it off one
	for i in PRESETS.size():
		var same := true
		for k in KEYS:
			if not is_equal_approx(value(hero, k), float(PRESETS[i][k])):
				same = false
				break
		if same:
			return i
	return -1


static func apply_preset(hero: Dictionary, i: int) -> void:
	for k in KEYS:
		hero[k] = PRESETS[i][k]


static func random_into(hero: Dictionary) -> void:
	# "Surprise me!": usually a preset, sometimes anything at all
	if randf() < 0.6:
		apply_preset(hero, randi() % PRESETS.size())
		return
	for k in KEYS:
		hero[k] = snappedf(randf_range(lerpf(1.0, RANGES[k][0], 0.7), lerpf(1.0, RANGES[k][1], 0.7)), 0.05)


static func apply(model: Node3D, face: Dictionary, hero: Dictionary) -> void:
	# Give this model the hero's face. The model keeps its original mesh (for the next change, and for anything that
	# measures the body, like the clothes: scripts/clothes.gd), and wears a sculpted copy.
	var mi := Clothes._body(model)
	if mi == null or not mi.mesh is ArrayMesh:
		return
	var original := mi.get_meta("unsculpted", mi.mesh) as ArrayMesh
	mi.set_meta("unsculpted", original)
	var data := _data(original)
	var moved := _sculpt(data, face, hero)
	if moved.is_empty():
		_swap(mi, original)
		return
	var m := ArrayMesh.new()
	for i in original.get_surface_count():
		var arrays: Array = data.arrays[i]
		if moved.has(i):
			arrays = arrays.duplicate()
			arrays[Mesh.ARRAY_VERTEX] = moved[i]
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			original.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		m.surface_set_material(i, original.surface_get_material(i))
		m.surface_set_name(i, original.surface_get_name(i))
	_swap(mi, m)


static func _swap(mi: MeshInstance3D, m: Mesh) -> void:
	if mi.mesh == m:
		return
	# The same surfaces in the same order, so the colours and hidden parts set on them stay
	var keep := []
	for i in mi.get_surface_override_material_count():
		keep.append(mi.get_surface_override_material(i))
	mi.mesh = m
	for i in mini(keep.size(), mi.get_surface_override_material_count()):
		mi.set_surface_override_material(i, keep[i])


# -----------------------------------------------------------------------------
# Sculpting
# -----------------------------------------------------------------------------
static func _sculpt(data: Dictionary, face: Dictionary, hero: Dictionary) -> Dictionary:
	# Moves the points of every face part the hero's values change. Returns surface -> its new points (only the
	# surfaces that changed). A point can belong to more than one feature (a hippo's mouth is on her snout), so the
	# features go in order: the mouth first, then the nose carries it.
	var out := {}
	var ctx := {"data": data, "out": out}
	var head: Vector3 = face.get("head", Vector3(0, 1.1, 0))
	if face.has("mouth"):
		var s := value(hero, "mouth")
		if not is_equal_approx(s, 1.0):
			var spec: Dictionary = face.mouth
			var p: Vector3 = spec.at
			_move(ctx, _pick(data, spec, spec.get("parts", ["Mouth", "Tongue", "Teeth"]), 0.0),
				func(v: Vector3) -> Vector3: return p + (v - p) * Vector3(s, s, lerpf(1.0, s, 0.4)))
	if face.has("nose"):
		var s := value(hero, "nose")
		if not is_equal_approx(s, 1.0):
			var spec: Dictionary = face.nose
			# A nose grows out of the face: from its root, a little behind its middle
			var p: Vector3 = spec.get("root", spec.at + (head - spec.at).normalized() * float(spec.r) * 0.5)
			_move(ctx, _pick(data, spec, spec.get("parts", ["Nose", "Nostril"]), 0.0),
				func(v: Vector3) -> Vector3: return p + (v - p) * s)
	if face.has("eyes"):
		var s := value(hero, "eyes")
		var gap := value(hero, "eye_gap")
		if not (is_equal_approx(s, 1.0) and is_equal_approx(gap, 1.0)):
			var spec: Dictionary = face.eyes
			var parts: Array = EYE_PARTS + spec.get("parts", [])
			for side in [1.0, -1.0]:
				var c: Vector3 = spec.at * Vector3(side, 1, 1)
				var c2 := Vector3(c.x * gap, c.y, c.z)
				var one := spec.duplicate()
				one.at = c
				# The eye itself (and its lashes) grows about its middle; it flattens a little as it grows, so a big
				# eye stays on the face instead of bulging off it
				_move(ctx, _pick(data, one, parts, 0.0),
					func(v: Vector3) -> Vector3: return c2 + (v - c) * Vector3(s, s, lerpf(1.0, s, 0.45)))
				# Brows just above go along with it, lifted clear of a bigger eye
				_move(ctx, _pick(data, one, [BROW], float(spec.r), 2.4),
					func(v: Vector3) -> Vector3: return v + (c2 - c) + Vector3(0, (v.y - c.y) * (s - 1.0) * 0.55, 0))
	if face.has("ears"):
		var s := value(hero, "ears")
		if not is_equal_approx(s, 1.0):
			for spec in (face.ears if face.ears is Array else [face.ears]):
				for side in [1.0, -1.0]:
					var one: Dictionary = spec.duplicate()
					one.at = spec.at * Vector3(side, 1, 1)
					# An ear grows out from where it meets the head
					var root: Vector3 = spec.get("root", spec.at + (head - spec.at).normalized() * float(spec.r) * 0.55)
					root.x *= side
					_move(ctx, _pick(data, one, spec.get("parts", ["Skin"]), 0.0),
						func(v: Vector3) -> Vector3: return root + (v - root) * s)
	return out


static func _pick(data: Dictionary, spec: Dictionary, parts: Array, inner: float, outer := 1.0) -> Array:
	# The pieces of this feature: made of one of these parts, with their middle near the spec's spot (within its
	# radius, or between inner and radius x outer for a ring round it, like brows), and small (not the whole head)
	var at: Vector3 = spec.at
	var r := float(spec.r)
	var out := []
	for piece in data.pieces:
		var d: float = (piece.center as Vector3).distance_to(at)
		var near := d > inner and d <= r * outer if inner > 0.0 else d <= r
		if not near or float(piece.size) > r * 4.5:
			continue
		for name in piece.parts:
			if name in parts:
				out.append(piece)
				break
	return out


static func _move(ctx: Dictionary, pieces: Array, fn: Callable) -> void:
	var out: Dictionary = ctx.out
	var data: Dictionary = ctx.data
	for piece in pieces:
		for s in piece.points:
			if not out.has(s):
				out[s] = (data.arrays[s][Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
			var v: PackedVector3Array = out[s]
			for k in piece.points[s]:
				v[k] = fn.call(v[k])
			out[s] = v


# -----------------------------------------------------------------------------
# A mesh's pieces, worked out once per model
# -----------------------------------------------------------------------------
static func _data(mesh: ArrayMesh) -> Dictionary:
	# Every surface's arrays, and the mesh split into its connected pieces (points that share a triangle, or sit in
	# exactly the same spot across a seam, belong together), each with its middle, size and which parts it's made of
	var key := mesh.get_instance_id()
	if _meshes.has(key):
		return _meshes[key]
	var arrays := []
	var first := PackedInt32Array()          # the first point of each surface in one long numbering
	var pos := PackedVector3Array()
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		arrays.append(a)
		first.append(pos.size())
		pos.append_array(a[Mesh.ARRAY_VERTEX])
	var parent := PackedInt32Array()
	parent.resize(pos.size())
	for k in pos.size():
		parent[k] = k
	var spot := {}
	for k in pos.size():
		var at := pos[k].snapped(Vector3.ONE * 0.0001)
		if spot.has(at):
			_join(parent, k, spot[at])
		else:
			spot[at] = k
	for i in arrays.size():
		var idx = arrays[i][Mesh.ARRAY_INDEX]
		if not idx is PackedInt32Array:
			continue
		var b := first[i]
		for t in range(0, (idx as PackedInt32Array).size(), 3):
			_join(parent, b + idx[t], b + idx[t + 1])
			_join(parent, b + idx[t], b + idx[t + 2])
	var by_root := {}
	for i in arrays.size():
		var name := ""
		if mesh.surface_get_material(i):
			name = mesh.surface_get_material(i).resource_name
		var n := (arrays[i][Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		for k in n:
			var r := _root(parent, first[i] + k)
			if not by_root.has(r):
				by_root[r] = {"lo": pos[first[i] + k], "hi": pos[first[i] + k], "parts": [], "points": {}}
			var piece: Dictionary = by_root[r]
			piece.lo = (piece.lo as Vector3).min(pos[first[i] + k])
			piece.hi = (piece.hi as Vector3).max(pos[first[i] + k])
			if name not in piece.parts:
				piece.parts.append(name)
			if not piece.points.has(i):
				piece.points[i] = []
			(piece.points[i] as Array).append(k)
	var pieces := []
	for piece in by_root.values():
		piece.center = ((piece.lo as Vector3) + (piece.hi as Vector3)) / 2.0
		piece.size = ((piece.hi as Vector3) - (piece.lo as Vector3)).length()
		pieces.append(piece)
	var data := {"arrays": arrays, "pieces": pieces}
	_meshes[key] = data
	return data


static func _root(parent: PackedInt32Array, k: int) -> int:
	while parent[k] != k:
		parent[k] = parent[parent[k]]
		k = parent[k]
	return k


static func _join(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _root(parent, a)
	var rb := _root(parent, b)
	if ra != rb:
		parent[ra] = rb
