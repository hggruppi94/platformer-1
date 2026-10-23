class_name Clothes
extends RefCounted

# Nina's clothes, head to toe: eight slots, one thing worn in each (Game.outfit, slot -> shop item id). Bought at the
# Clothing Boutique (res://shop/items.json, kind "clothes"), changed at her wardrobe (scripts/shop.gd).
#
#   head, face, neck, hands and back: pieces built from simple shapes that sit on her body and move with it (fixed to
#   her bones). Hats are the market's (scripts/cosmetics.gd).
#   top, bottoms and feet: her own shirt, overalls and shoes in new colours and patterns, sometimes with something
#   extra (a tutu, moon boots).
# An empty slot is her own look. Wings, the cape and the jetpack take the place of her backpack.
#
# Pieces are placed in her model's own space (feet at 0, facing +Z), standing as she does in Blender, and then fixed
# to the nearest bone, so they follow her arms and legs when she runs.

const SLOTS := ["head", "face", "neck", "top", "bottoms", "feet", "hands", "back"]
const SLOT_NAMES := {"head": "Head", "face": "Face", "neck": "Neck", "top": "Top", "bottoms": "Bottoms",
	"feet": "Feet", "hands": "Hands", "back": "Back"}

# Restyled parts of her model: which of its materials each slot recolours, and with what
# [surface materials, main colour, second colour (patterns), pattern]
const RESTYLE := {
	"stripy_shirt": [["Shirt"], Color(0.98, 0.98, 1.0), Color(0.45, 0.6, 1.0), "stripes"],
	"galaxy_tee": [["Shirt"], Color(0.25, 0.15, 0.45), Color(1.0, 0.9, 0.5), "stars"],
	"sunny_shirt": [["Shirt"], Color(1.0, 0.85, 0.3), Color(1.0, 0.85, 0.3), ""],
	"denim_overalls": [["Overalls", "Overalls Trim"], Color(0.35, 0.5, 0.85), Color(0.3, 0.42, 0.75), ""],
	"mint_overalls": [["Overalls", "Overalls Trim"], Color(0.55, 0.95, 0.8), Color(1.0, 1.0, 1.0), "dots"],
	"tutu": [["Overalls", "Overalls Trim"], Color(0.85, 0.7, 1.0), Color(0.85, 0.7, 1.0), ""],
	"rainbow_sneakers": [["Shoes"], Color(1.0, 0.45, 0.5), Color(0.45, 0.8, 1.0), "stripes"],
	"sparkle_slippers": [["Shoes", "Sole"], Color(0.95, 0.6, 0.95), Color(1.0, 1.0, 0.7), "stars"],
	"moon_boots": [["Shoes", "Sole"], Color(0.85, 0.88, 0.95), Color(0.85, 0.88, 0.95), ""],
}
const BACKPACK := ["Backpack", "Backpack Mesh", "Zipper"]

static var _patterns := {}


static func dress(model: Node3D, outfit: Dictionary) -> void:
	# Put the outfit on her model, taking off whatever was on before
	var mesh := _body(model)
	var skel := _skeleton(model)
	if mesh == null or skel == null:
		return
	for old in skel.find_children("Clothes *", "BoneAttachment3D", false, false):
		old.free()
	for i in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(i, null)
	for slot in SLOTS:
		var id := str(outfit.get(slot, ""))
		if id == "":
			continue
		if RESTYLE.has(id):
			_restyle(mesh, RESTYLE[id])
		if slot == "back":
			_hide(mesh, BACKPACK)
		var piece := hat_or_piece(slot, id)
		if piece:
			_attach(model, skel, piece, slot)


static func wearing(outfit: Dictionary, slot: String) -> String:
	return str(outfit.get(slot, ""))


# -----------------------------------------------------------------------------
# Her model's parts
# -----------------------------------------------------------------------------
static func _body(model: Node3D) -> MeshInstance3D:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin != null:
			return mi
	return null


static func _skeleton(model: Node3D) -> Skeleton3D:
	var all := model.find_children("*", "Skeleton3D", true, false)
	return all[0] as Skeleton3D if all.size() > 0 else null


static func _surfaces(mesh: MeshInstance3D, names: Array) -> Array[int]:
	var out: Array[int] = []
	for i in mesh.mesh.get_surface_count():
		var m := mesh.mesh.surface_get_material(i)
		if m and m.resource_name in names:
			out.append(i)
	return out


static func _restyle(mesh: MeshInstance3D, look: Array) -> void:
	# Her own garment in new colours: the first part takes the main colour (and pattern), any others (trim, soles)
	# the second colour
	var parts := _surfaces(mesh, look[0])
	for k in parts.size():
		var base := mesh.mesh.surface_get_material(parts[k]) as StandardMaterial3D
		var m := (base.duplicate() if base else StandardMaterial3D.new()) as StandardMaterial3D
		if k == 0:
			m.albedo_color = Color.WHITE if look[3] != "" else look[1]
			if look[3] != "":
				m.albedo_texture = _pattern(look[3], look[1], look[2])
				m.uv1_triplanar = true                     # her model's own UVs don't matter: the pattern wraps round
				m.uv1_scale = Vector3(4, 4, 4)
		else:
			m.albedo_color = look[2]
			m.albedo_texture = null
		mesh.set_surface_override_material(parts[k], m)


static func _hide(mesh: MeshInstance3D, names: Array) -> void:
	var gone := StandardMaterial3D.new()
	gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gone.albedo_color = Color(1, 1, 1, 0)
	for i in _surfaces(mesh, names):
		mesh.set_surface_override_material(i, gone)


static func _pattern(kind: String, a: Color, b: Color) -> ImageTexture:
	# A small repeating pattern, made once and kept
	var key := "%s %s %s" % [kind, a.to_html(), b.to_html()]
	if _patterns.has(key):
		return _patterns[key]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var on := false
			match kind:
				"stripes":
					on = (y / 4) % 2 == 0
				"dots":
					on = Vector2(x % 16 - 8, y % 16 - 8).length() < 3.5
				"stars":
					var cx := absi(x % 16 - 8)
					var cy := absi(y % 16 - 8)
					on = (cx <= 1 and cy <= 4) or (cy <= 1 and cx <= 4) or (cx + cy <= 3)
			img.set_pixel(x, y, b if on else a)
	var tex := ImageTexture.create_from_image(img)
	_patterns[key] = tex
	return tex


static func _attach(model: Node3D, skel: Skeleton3D, piece: Node3D, slot: String) -> void:
	# Fix a piece (placed in her model's space) to the bone that carries that part of her
	var bone_names := {"head": "head", "face": "head", "neck": "chest", "back": "chest", "bottoms": "hips"}
	if slot in ["hands", "feet"]:
		# One for each side: the piece has a "L" and an "R" child, each placed for that side
		for side in ["L", "R"]:
			var part := piece.get_node_or_null(side) as Node3D
			if part:
				piece.remove_child(part)
				_fix(model, skel, part, ("hand." if slot == "hands" else "foot.") + side, slot)
		piece.free()
		return
	_fix(model, skel, piece, bone_names.get(slot, "chest"), slot)


static func _fix(model: Node3D, skel: Skeleton3D, part: Node3D, bone_name: String, slot: String) -> void:
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		part.free()
		return
	var holder := BoneAttachment3D.new()
	holder.name = "Clothes %s %s" % [slot, bone_name]
	holder.bone_name = bone_name
	skel.add_child(holder)
	# Where the bone sits in her model's space when she stands as in Blender; the piece goes relative to that
	var skel_in_model := Transform3D.IDENTITY
	var n: Node = skel
	while n != model and n is Node3D:
		skel_in_model = (n as Node3D).transform * skel_in_model
		n = n.get_parent()
	var rest := skel_in_model * skel.get_bone_global_rest(bone)
	part.transform = rest.affine_inverse() * part.transform
	holder.add_child(part)


# -----------------------------------------------------------------------------
# The pieces, in her model's space: feet at y 0, facing +Z, her face's front at about z 0.27, eyes at y 1.13
# -----------------------------------------------------------------------------
static func hat_or_piece(slot: String, id: String) -> Node3D:
	if slot == "head":
		return Cosmetics.hat(id)
	var g := Node3D.new()
	g.name = id
	match id:
		# --- Face
		"star_glasses":
			var gold := _mat(Color(1.0, 0.82, 0.25), 0.4, 0.6)
			var lens := _mat(Color(0.7, 0.9, 1.0, 0.5), 0.3)
			for s in [-1, 1]:
				_mesh(g, _cyl(0.075, 0.075, 0.02, 5), gold, Vector3(s * 0.1, 1.135, 0.29), Vector3(PI / 2, 0, 0))
				_mesh(g, _cyl(0.06, 0.06, 0.025, 5), lens, Vector3(s * 0.1, 1.135, 0.295), Vector3(PI / 2, 0, 0))
			_mesh(g, _box(Vector3(0.06, 0.015, 0.015)), gold, Vector3(0, 1.15, 0.3))
		"heart_shades":
			var frame := _mat(Color(1.0, 0.4, 0.7), 0.4)
			var dark := _mat(Color(0.2, 0.05, 0.2), 0.2, 0.3)
			for s in [-1, 1]:
				for k in [-1, 1]:                              # a heart: two round lobes and a point
					_mesh(g, _sphere(0.042), dark, Vector3(s * 0.1 + k * 0.03, 1.15, 0.285), Vector3.ZERO, Vector3(1, 1, 0.35))
				var tip := PrismMesh.new()
				tip.size = Vector3(0.12, 0.08, 0.03)
				_mesh(g, tip, dark, Vector3(s * 0.1, 1.105, 0.285), Vector3(0, 0, PI))
			_mesh(g, _box(Vector3(0.06, 0.015, 0.015)), frame, Vector3(0, 1.15, 0.29))
			for s in [-1, 1]:
				_mesh(g, _box(Vector3(0.02, 0.015, 0.22)), frame, Vector3(s * 0.2, 1.15, 0.19))
		"space_goggles":
			var band := _mat(Color(0.35, 0.25, 0.55), 0.6)
			var rim := _mat(Color(0.75, 0.78, 0.85), 0.3, 0.8)
			var glass := _mat(Color(0.4, 1.0, 0.75, 0.6), 0.2, 0.0, 0.6)
			_mesh(g, _torus(0.25, 0.28), band, Vector3(0, 1.14, 0.02), Vector3.ZERO, Vector3(1.0, 0.3, 1.05))
			for s in [-1, 1]:
				_mesh(g, _cyl(0.075, 0.08, 0.06), rim, Vector3(s * 0.1, 1.14, 0.29), Vector3(PI / 2, 0, 0))
				_mesh(g, _cyl(0.06, 0.06, 0.065), glass, Vector3(s * 0.1, 1.14, 0.295), Vector3(PI / 2, 0, 0))
		# --- Neck
		"cozy_scarf":
			var wool := _mat(Color(0.95, 0.35, 0.45), 0.9)
			_mesh(g, _torus(0.13, 0.2), wool, Vector3(0, 0.86, 0.0), Vector3.ZERO, Vector3(1, 0.9, 1))
			_mesh(g, _box(Vector3(0.1, 0.28, 0.05)), wool, Vector3(0.08, 0.72, 0.2), Vector3(0.15, 0, 0.1))
			_mesh(g, _box(Vector3(0.1, 0.02, 0.052)), _mat(Color(1.0, 0.9, 0.5), 0.9), Vector3(0.09, 0.62, 0.215), Vector3(0.15, 0, 0.1))
		"bow_tie":
			var silk := _mat(Color(0.3, 0.45, 1.0), 0.4)
			for s in [-1, 1]:
				var p := PrismMesh.new()
				p.size = Vector3(0.1, 0.1, 0.03)
				_mesh(g, p, silk, Vector3(s * 0.05, 0.86, 0.21), Vector3(0, 0, s * PI / 2))
			_mesh(g, _sphere(0.025), silk, Vector3(0, 0.86, 0.22))
		"crystal_necklace":
			_mesh(g, _torus(0.17, 0.185), _mat(Color(0.9, 0.9, 1.0), 0.3, 0.8), Vector3(0, 0.84, 0.03), Vector3(0.35, 0, 0))
			var gem := PrismMesh.new()
			gem.size = Vector3(0.06, 0.09, 0.04)
			_mesh(g, gem, _mat(Color(0.6, 0.9, 1.0), 0.2, 0.0, 1.2), Vector3(0, 0.75, 0.21), Vector3(0, 0, PI))
		# --- Bottoms
		"tutu":
			var frill := _mat(Color(1.0, 0.7, 0.9, 0.85), 0.6)
			for k in 2:
				_mesh(g, _cyl(0.2, 0.34 - k * 0.04, 0.07, 20), frill, Vector3(0, 0.46 - k * 0.05, 0.0))
		# --- Feet (an "L" and an "R")
		"moon_boots":
			var puff := _mat(Color(0.85, 0.88, 0.95), 0.5, 0.3)
			for side in ["L", "R"]:
				var b := Node3D.new()
				b.name = side
				g.add_child(b)
				var x := 0.12 if side == "L" else -0.12
				_mesh(b, _cyl(0.1, 0.11, 0.17), puff, Vector3(x, 0.1, 0.02))
				_mesh(b, _torus(0.08, 0.11), _mat(Color(0.6, 0.85, 1.0), 0.4, 0.0, 0.6), Vector3(x, 0.19, 0.02))
		# --- Hands (an "L" and an "R")
		"cozy_mittens", "hero_gloves", "garden_gloves":
			var col := {"cozy_mittens": Color(0.5, 0.75, 1.0), "hero_gloves": Color(0.95, 0.3, 0.35),
				"garden_gloves": Color(0.5, 0.85, 0.4)}[id] as Color
			for side in ["L", "R"]:
				var hnd := Node3D.new()
				hnd.name = side
				g.add_child(hnd)
				var s := 1.0 if side == "L" else -1.0
				var at := Vector3(s * 0.43, 0.49, 0.065)          # her hand, a little below the wrist
				_mesh(hnd, _sphere(0.065), _mat(col, 0.7), at, Vector3.ZERO, Vector3(1, 1.2, 1))
				if id == "hero_gloves":                          # big cuffs
					_mesh(hnd, _cyl(0.07, 0.06, 0.07), _mat(Color(1.0, 0.85, 0.25), 0.4, 0.5), at + Vector3(-s * 0.03, 0.06, -0.01), Vector3(0, 0, s * 0.5))
				elif id == "cozy_mittens":                       # a fluffy cuff
					_mesh(hnd, _torus(0.045, 0.07), _mat(Color(1, 1, 1), 0.9), at + Vector3(-s * 0.025, 0.06, -0.01), Vector3(0, 0, s * 0.5))
		# --- Back (her backpack comes off)
		"butterfly_wings":
			var wing := _mat(Color(0.75, 0.55, 1.0, 0.8), 0.3, 0.0, 0.4)
			var spot := _mat(Color(1.0, 0.9, 0.45), 0.4, 0.0, 0.8)
			for s in [-1, 1]:
				_mesh(g, _sphere(0.22), wing, Vector3(s * 0.22, 0.85, -0.3), Vector3(0, s * 0.5, s * 0.4), Vector3(1.0, 1.2, 0.08))
				_mesh(g, _sphere(0.14), wing, Vector3(s * 0.17, 0.58, -0.28), Vector3(0, s * 0.5, -s * 0.5), Vector3(1.0, 1.0, 0.08))
				_mesh(g, _sphere(0.05), spot, Vector3(s * 0.26, 0.9, -0.33), Vector3.ZERO, Vector3(1, 1, 0.3))
		"super_cape":
			var cloth := _mat(Color(0.95, 0.25, 0.45), 0.6)
			_mesh(g, _box(Vector3(0.5, 0.62, 0.025)), cloth, Vector3(0, 0.52, -0.33), Vector3(0.18, 0, 0))
			_mesh(g, _torus(0.16, 0.19), _mat(Color(1.0, 0.85, 0.25), 0.4, 0.6), Vector3(0, 0.85, 0.0), Vector3.ZERO, Vector3(1, 0.5, 1))
			_mesh(g, _cyl(0.07, 0.07, 0.02, 5), _mat(Color(1.0, 0.85, 0.25), 0.4, 0.6, 0.6), Vector3(0, 0.55, -0.35), Vector3(PI / 2 + 0.18, 0, 0))
		"jetpack":
			var tank := _mat(Color(0.75, 0.78, 0.88), 0.3, 0.8)
			var flame := _mat(Color(1.0, 0.6, 0.3), 0.5, 0.0, 3.0)
			for s in [-1, 1]:
				_mesh(g, _cyl(0.08, 0.08, 0.36), tank, Vector3(s * 0.1, 0.62, -0.32))
				_mesh(g, _sphere(0.08), _mat(Color(0.95, 0.35, 0.45), 0.4), Vector3(s * 0.1, 0.8, -0.32))
				var cone := _cyl(0.06, 0.0, 0.14, 8)
				_mesh(g, cone, flame, Vector3(s * 0.1, 0.38, -0.32))
			_mesh(g, _box(Vector3(0.12, 0.2, 0.06)), tank, Vector3(0, 0.65, -0.27))
		_:
			g.free()
			return null
	return g


static func _mat(color: Color, rough := 0.5, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 16
	s.rings = 8
	return s


static func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 32
	t.ring_segments = 8
	return t


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
