class_name Clothes
extends RefCounted

# Clothes and looks for Nina and her friends. Each of them has an outfit (Game.outfits[who], slot -> shop item id)
# and looks (Game.looks[who], part -> colour number). Clothes are bought at the Clothing Boutique
# (res://shop/items.json, kind "clothes"); outfits and looks are changed at the wardrobe (scripts/shop.gd), and Nina
# can lend anything she owns to a friend.
#
#   Slots, head to toe: head, face, neck, top, bottoms, feet, hands, back. One thing in each; an empty slot is their
#   own look. Top, bottoms and feet restyle their own clothes (new colours and patterns); the rest are pieces built
#   from simple shapes and fixed to their bones, so they move with them. Back pieces take the place of a backpack.
#   Hats are the market's (scripts/cosmetics.gd).
#   Looks: fur (or skin), hair, eyes, an accent (Nina's bow, Dash's cap, Rook's collar...) and blush, each picked from
#   a few colours. Colour 0 is how Sofi drew them.
#
# Pieces are made for Nina (her model's space: feet at 0, facing +Z, eyes at y 1.13) and fitted to whoever wears them:
# everyone shares one skeleton, so each piece is moved and stretched from Nina's head, neck, chest, hips, hands or
# feet to theirs (fit()), then fixed to that bone. Rex walks on four legs, so he only wears hats.

const SLOTS := ["head", "face", "neck", "top", "bottoms", "feet", "hands", "back"]
const SLOT_NAMES := {"head": "Head", "face": "Face", "neck": "Neck", "top": "Top", "bottoms": "Bottoms",
	"feet": "Feet", "hands": "Hands", "back": "Back"}
const WHO := ["hero", "nina", "dash", "rook", "pip", "bramble", "green_man", "mr_palmer", "rex"]
const ONLY_HATS := ["rex"]

# Each character's own clothes, by slot: [main part, trim parts...] (their model's material names). A slot left out
# has nothing to restyle (the Green Man wears no clothes of his own; Pip's suit is one piece).
const OWN_CLOTHES := {
	"nina": {"top": ["Shirt"], "bottoms": ["Overalls", "Overalls Trim"], "feet": ["Shoes", "Sole"]},
	"dash": {"top": ["Hoodie", "Hoodie Shade"], "bottoms": ["Shorts", "Shorts Trim"], "feet": ["Shoes", "Sole"]},
	"rook": {"top": ["Shirt", "Shirt Shade"], "bottoms": ["Denim", "Denim Light"], "feet": ["Shoes", "Sole"]},
	"pip": {"top": ["Suit Navy", "Suit Blue"], "bottoms": ["Suit Yellow", "Suit Red"]},
	"bramble": {"top": ["Top"], "bottoms": ["Shorts", "Shorts Trim"], "feet": ["Shoe", "Sole"]},
	"mr_palmer": {"top": ["Suit", "Suit Shade"], "feet": ["Shoes", "Sole"]},
}
const BACKPACKS := ["Backpack", "Backpack Mesh", "Backpack Dark", "Zipper"]

# Restyles: [main colour, second colour (pattern, trim, soles), pattern]
const RESTYLE := {
	"stripy_shirt": [Color(0.98, 0.98, 1.0), Color(0.45, 0.6, 1.0), "stripes"],
	"galaxy_tee": [Color(0.25, 0.15, 0.45), Color(1.0, 0.9, 0.5), "stars"],
	"sunny_shirt": [Color(1.0, 0.85, 0.3), Color(1.0, 0.85, 0.3), ""],
	"denim_overalls": [Color(0.35, 0.5, 0.85), Color(0.3, 0.42, 0.75), ""],
	"mint_overalls": [Color(0.55, 0.95, 0.8), Color(1.0, 1.0, 1.0), "dots"],
	"tutu": [Color(0.85, 0.7, 1.0), Color(0.85, 0.7, 1.0), ""],
	"rainbow_sneakers": [Color(1.0, 0.45, 0.5), Color(0.45, 0.8, 1.0), "stripes"],
	"sparkle_slippers": [Color(0.95, 0.6, 0.95), Color(1.0, 1.0, 0.7), "stars"],
	"moon_boots": [Color(0.85, 0.88, 0.95), Color(0.85, 0.88, 0.95), ""],
}

# Looks: what each can change ([material names] per part; the first is the main one, any others follow it a shade
# lighter or darker), and the colours to pick from (after colour 0, their own)
const LOOK_PARTS := ["fur", "hair", "eyes", "accent", "blush"]
const LOOK_NAMES := {"fur": "Fur", "hair": "Hair", "eyes": "Eyes", "accent": "Accent", "blush": "Blush"}
const OWN_LOOKS := {
	"nina": {"fur": ["Skin", "Ear Inner"], "hair": ["Hair"], "eyes": ["Iris", "Iris Light"], "accent": ["Bow"], "blush": ["Blush"]},
	"dash": {"fur": ["Skin"], "hair": ["Hair"], "accent": ["Cap"], "blush": ["Blush"]},
	"rook": {"fur": ["Skin"], "hair": ["Hair"], "eyes": ["Iris", "Iris Light"], "accent": ["Collar"], "blush": ["Blush"]},
	"pip": {"fur": ["Skin", "Skin Shade"], "hair": ["Mane Orange"], "eyes": ["Iris", "Iris Light"], "accent": ["Antenna Tip"], "blush": ["Blush"]},
	"bramble": {"fur": ["Fur", "Fur Light"], "hair": ["Hair", "Hair Shade"], "eyes": ["Iris", "Iris Light"], "accent": ["Belt"]},
	"green_man": {"fur": ["Green", "Green Dark"], "eyes": ["Eye"]},
	"mr_palmer": {"fur": ["Skin"], "hair": ["Grey Hair"], "eyes": ["Iris", "Iris Light"], "accent": ["Tie"], "blush": ["Blush"]},
	"rex": {"fur": ["Fur", "Fur Dark"], "eyes": ["Iris", "Iris Light"], "accent": ["Vest"]},
}
const ACCENT_NAMES := {"nina": "Bow", "dash": "Cap", "rook": "Collar", "pip": "Antenna Tips", "bramble": "Belt",
	"mr_palmer": "Tie", "rex": "Vest"}
const PALETTE := {
	"fur": [Color(0.58, 0.5, 0.47), Color(0.95, 0.8, 0.7), Color(0.75, 0.55, 0.4), Color(0.45, 0.32, 0.25),
		Color(0.7, 0.6, 0.9), Color(0.55, 0.85, 0.8), Color(1.0, 0.7, 0.8)],
	"hair": [Color(0.87, 0.2, 0.1), Color(1.0, 0.85, 0.35), Color(0.35, 0.22, 0.15), Color(0.15, 0.12, 0.15),
		Color(0.7, 0.45, 1.0), Color(0.3, 0.85, 0.85), Color(1.0, 0.5, 0.75)],
	"eyes": [Color(0.44, 0.25, 0.13), Color(0.3, 0.55, 1.0), Color(0.35, 0.8, 0.45), Color(0.65, 0.4, 0.95),
		Color(1.0, 0.75, 0.25)],
	"accent": [Color(0.81, 0.11, 0.13), Color(0.3, 0.55, 1.0), Color(1.0, 0.85, 0.3), Color(0.5, 0.9, 0.5),
		Color(0.75, 0.45, 1.0), Color(1.0, 0.55, 0.75)],
	"blush": [Color(0.92, 0.58, 0.65), Color(1.0, 0.45, 0.55), Color(1.0, 0.7, 0.5), Color(0.8, 0.6, 1.0)],
}

const COLOUR_NAMES := {
	"fur": ["their own", "peach", "caramel", "cocoa", "lilac", "mint", "bubblegum"],
	"hair": ["their own", "sunny blonde", "chestnut", "midnight", "purple", "teal", "pink"],
	"eyes": ["their own", "sky blue", "leaf green", "violet", "gold"],
	"accent": ["their own", "blue", "yellow", "green", "purple", "pink"],
	"blush": ["their own", "rosy", "peachy", "lavender"],
}

# Where each kind of piece is made to sit on Nina: [the bone it rides on, the point on her it's placed round]
const ANCHORS := {"head": ["head", "top"], "hair": ["head", "top"], "face": ["head", "eyes"], "neck": ["chest", "neck"], "back": ["chest", "chest"],
	"bottoms": ["hips", "hips"]}

static var _patterns := {}
static var _fits := {}


static func dress(model: Node3D, who: String, outfit: Dictionary, looks := {}) -> void:
	# Put an outfit and looks on someone's model, taking off whatever was on before
	var mesh := _body(model)
	var skel := _skeleton(model)
	if mesh == null or skel == null:
		return
	for old in skel.find_children("Clothes *", "BoneAttachment3D", false, false):
		old.free()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		for i in (m as MeshInstance3D).mesh.get_surface_count():
			(m as MeshInstance3D).set_surface_override_material(i, null)
	var own: Dictionary = OWN_LOOKS.get(who, {})
	for part in looks:
		var pick := int(looks[part])
		if pick > 0 and own.has(part) and PALETTE.has(part):
			_recolour(model, own[part], PALETTE[part][pick % PALETTE[part].size()])
	var fit := fit_of(model)
	for slot in SLOTS:
		var id := str(outfit.get(slot, ""))
		if id == "" or (who in ONLY_HATS and slot != "head"):
			continue
		var clothes: Dictionary = OWN_CLOTHES.get(who, {})
		if RESTYLE.has(id) and clothes.has(slot):
			_restyle(model, clothes[slot], RESTYLE[id])
		if slot == "back":
			_hide(model, BACKPACKS)
		var piece := hat_or_piece(slot, id)
		if piece:
			_attach(model, skel, piece, slot, fit)


static func wearing(outfit: Dictionary, slot: String) -> String:
	return str(outfit.get(slot, ""))


static func can_wear(who: String, slot: String) -> bool:
	return not (who in ONLY_HATS and slot != "head")


static func looks_for(who: String) -> Array:
	# The parts of their look that can be changed, in order
	var own: Dictionary = OWN_LOOKS.get(who, {})
	return LOOK_PARTS.filter(func(p: String) -> bool: return own.has(p))


static func look_name(who: String, part: String) -> String:
	return str(ACCENT_NAMES.get(who, "Accent")) if part == "accent" else str(LOOK_NAMES[part])


# -----------------------------------------------------------------------------
# Their model's parts
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


static func _each_surface(model: Node3D, names: Array, fn: Callable) -> void:
	# fn(mesh, surface index, which name it matched (its place in names)) for every part with one of these names
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(i)
			if m and m.resource_name in names:
				fn.call(mesh, i, names.find(m.resource_name))


static func _recolour(model: Node3D, names: Array, color: Color) -> void:
	# The main part takes the colour; the others (a shade, a light) keep how much lighter or darker they were
	var main_base := Color.WHITE
	_each_surface(model, [names[0]], func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		main_base = (mesh.mesh.surface_get_material(i) as StandardMaterial3D).albedo_color)
	_each_surface(model, names, func(mesh: MeshInstance3D, i: int, k: int) -> void:
		var base := mesh.mesh.surface_get_material(i) as StandardMaterial3D
		if base == null:
			return
		var m := base.duplicate() as StandardMaterial3D
		var c := color
		if k > 0 and main_base.v > 0.01:
			c = Color.from_hsv(color.h, color.s, clampf(color.v * base.albedo_color.v / main_base.v, 0.0, 1.0))
		m.albedo_color = c
		mesh.set_surface_override_material(i, m))


static func _restyle(model: Node3D, names: Array, look: Array) -> void:
	# Their own garment in new colours: the first part takes the main colour (and pattern), any others (trim, soles)
	# the second colour
	_each_surface(model, names, func(mesh: MeshInstance3D, i: int, k: int) -> void:
		var base := mesh.mesh.surface_get_material(i) as StandardMaterial3D
		var m := (base.duplicate() if base else StandardMaterial3D.new()) as StandardMaterial3D
		if k == 0:
			m.albedo_color = Color.WHITE if look[2] != "" else look[0]
			if look[2] != "":
				m.albedo_texture = _pattern(look[2], look[0], look[1])
				m.uv1_triplanar = true                     # their model's own UVs don't matter: the pattern wraps round
				m.uv1_scale = Vector3(4, 4, 4)
		else:
			m.albedo_color = look[1]
			m.albedo_texture = null
		mesh.set_surface_override_material(i, m))


static func _hide(model: Node3D, names: Array) -> void:
	var gone := StandardMaterial3D.new()
	gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gone.albedo_color = Color(1, 1, 1, 0)
	_each_surface(model, names, func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		mesh.set_surface_override_material(i, gone))


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


# -----------------------------------------------------------------------------
# Fitting: where the places pieces sit round are on someone, measured from their model (and kept per model)
# -----------------------------------------------------------------------------
const NINA := "res://models/characters/nina.glb"
const NOT_HEAD := ["Antenna", "Antenna Tip", "Horn", "Horn Tip", "Cap", "Cap White"]


static func fit_of(model: Node3D) -> Dictionary:
	var key := model.scene_file_path
	if _fits.has(key) and key != "":
		return _fits[key]
	var skel := _skeleton(model)
	var bones := {}
	for b in ["head", "chest", "hips", "upper_arm.L", "hand.L", "hand.R", "foot.L", "foot.R"]:
		var i := skel.find_bone(b)
		if i >= 0:
			bones[b] = (_skel_in_model(model, skel) * skel.get_bone_global_rest(i)).origin
	# The eyes (their middle, at the front) and the top of the head, from the model's parts
	var eyes := AABB()
	var got_eyes := false
	var top := -INF
	var skull := -INF                       # the top of their head itself (their skin or fur), without the hair
	var head_box := AABB()
	var got_head := false
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		for s in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(s)
			var name := m.resource_name if m else ""
			var v: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if v.is_empty():
				continue
			var bb := AABB(v[0], Vector3.ZERO)
			for p in v:
				bb = bb.expand(p)
			if name in ["Eye White", "Eye", "Glasses"]:
				eyes = bb if not got_eyes else eyes.merge(bb)
				got_eyes = true
			if name not in NOT_HEAD:
				top = maxf(top, bb.end.y)
			if name in ["Skin", "Fur", "Green"]:
				skull = maxf(skull, bb.end.y)
				# Their head itself: the skin or fur above the neck
				var neck_y: float = bones.get("head", Vector3(0, 0.9, 0)).y + 0.08
				for p in v:
					if p.y > neck_y:
						head_box = AABB(p, Vector3.ZERO) if not got_head else head_box.expand(p)
						got_head = true
	var head: Vector3 = bones.get("head", Vector3(0, 0.9, 0))
	var fit := {}
	var eye_point := Vector3(head.x, eyes.get_center().y, eyes.end.z + 0.02) if got_eyes else head + Vector3(0, 0.23, 0.29)
	fit.top = Vector3(head.x, top, head.z)
	fit.eyes = eye_point
	fit.head_size = maxf(top - eye_point.y, 0.1)
	fit.skull = maxf((skull if skull > -INF else top) - eye_point.y, 0.1)
	fit.head_box = head_box if got_head else AABB(head + Vector3(-0.3, 0.1, -0.3), Vector3(0.6, 0.5, 0.6))
	var chest: Vector3 = bones.get("chest", head - Vector3(0, 0.14, 0))
	fit.neck = (head + chest) / 2.0 + Vector3(0, -0.01, 0)
	fit.chest = chest
	fit.hips = bones.get("hips", chest - Vector3(0, 0.26, 0))
	fit.width = absf(bones["upper_arm.L"].x) if bones.has("upper_arm.L") else 0.24
	fit.torso = maxf(chest.y - fit.hips.y, 0.1)
	for b in ["hand.L", "hand.R", "foot.L", "foot.R"]:
		fit[b] = bones.get(b, fit.hips)
	if key != "":
		_fits[key] = fit
	return fit


static func _nina_fit() -> Dictionary:
	# The pieces were made on Nina, so her measurements are where they start from
	if not _fits.has(NINA):
		var nina := (load(NINA) as PackedScene).instantiate() as Node3D
		nina.scene_file_path = NINA
		fit_of(nina)
		nina.free()
	return _fits[NINA]


static func _skel_in_model(model: Node3D, skel: Skeleton3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skel
	while n != model and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _fitted(slot: String, fit: Dictionary, part := "") -> Transform3D:
	# Moves and stretches a piece made for Nina onto someone else: round the matching point on each of them
	var nina := _nina_fit()
	var from: Vector3
	var to: Vector3
	var s := Vector3.ONE
	match slot:
		"head", "face":
			# Hats on top of their hair, glasses on their eyes; sized to their head
			var k: float = fit.head_box.size.x / nina.head_box.size.x
			s = Vector3(k, k, k)
			from = nina.top if slot == "head" else nina.eyes
			to = fit.top if slot == "head" else fit.eyes
		"hair":
			# Hairstyles wrap their head itself: Nina's head stretched to theirs, middle to middle
			s = fit.head_box.size / nina.head_box.size
			from = nina.head_box.get_center()
			to = fit.head_box.get_center()
		"neck", "back", "bottoms":
			var w: float = fit.width / nina.width
			s = Vector3(w, fit.torso / nina.torso, w)
			var spot: String = {"neck": "neck", "back": "chest", "bottoms": "hips"}[slot]
			from = nina[spot]
			to = fit[spot]
		"hands", "feet":
			from = nina[part]
			to = fit[part]
	return Transform3D(Basis.from_scale(s), to - from * s)


static func _attach(model: Node3D, skel: Skeleton3D, piece: Node3D, slot: String, fit: Dictionary) -> void:
	# Fix a piece (made in Nina's model space) to the bone that carries that part of whoever wears it
	if slot in ["hands", "feet"]:
		# One for each side: the piece has an "L" and an "R" child, each placed for that side
		for side in ["L", "R"]:
			var part := piece.get_node_or_null(side) as Node3D
			if part:
				piece.remove_child(part)
				var bone: String = ("hand." if slot == "hands" else "foot.") + side
				part.transform = _fitted(slot, fit, bone)
				_fix(model, skel, part, bone, slot)
		piece.free()
		return
	piece.transform = _fitted(slot, fit) * piece.transform
	_fix(model, skel, piece, str(ANCHORS.get(slot, ["chest"])[0]), slot)


static func _fix(model: Node3D, skel: Skeleton3D, part: Node3D, bone_name: String, slot: String) -> void:
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		part.free()
		return
	var holder := BoneAttachment3D.new()
	holder.name = "Clothes %s %s" % [slot, bone_name]
	holder.bone_name = bone_name
	skel.add_child(holder)
	# Where the bone sits in their model's space when they stand as in Blender; the piece goes relative to that
	var rest := _skel_in_model(model, skel) * skel.get_bone_global_rest(bone)
	part.transform = rest.affine_inverse() * part.transform
	holder.add_child(part)


# -----------------------------------------------------------------------------
# The pieces, made for Nina (her model's space): feet at y 0, facing +Z, her face's front at about z 0.27, eyes at y 1.13
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
