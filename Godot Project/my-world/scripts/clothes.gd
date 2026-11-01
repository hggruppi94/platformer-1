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
# Pieces are made for Nina (her model's space: feet at 0, facing +Z, eyes at y 1.18) and fitted to whoever wears them.
# Everyone's body is measured from the points of their own mesh and the bones that carry them (fit_of()): the top of
# the head in the middle (not ears, horns or antennae), how wide the head is at the eyes, the neck, chest and middle
# without arms or hair, their back, and each hand and foot. Each piece is moved and stretched from that place on Nina
# to the same place on them (_fitted()), a few parts are made to measure (_tailor(): glasses' arms, goggle straps,
# headphones), and then it's fixed to the bone there so it moves with them. Whatever a piece goes over comes off
# (UNDER), and a hat sits on a hairstyle, tucking its buns away if it covers them. Rex walks on four legs, so he only
# wears hats. tools/test_clothing_fit.gd checks every piece on everyone; tools/capture_clothing_fit.gd takes pictures.

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
	# The hero creator's own bodies (scripts/hero.gd)
	"earth_kid": {"top": ["Top", "Top Shade"], "bottoms": ["Jeans", "Jeans Shade"], "feet": ["Shoes", "Sole"]},
	"bunny": {"top": ["Top", "Top Shade"], "bottoms": ["Dungarees", "Dungarees Shade"], "feet": ["Shoes", "Sole"]},
	"cat": {"top": ["Hoodie", "Hoodie Shade"], "bottoms": ["Shorts", "Shorts Shade"], "feet": ["Shoes", "Sole"]},
	"dino": {"top": ["Top", "Top Shade"], "bottoms": ["Shorts", "Shorts Shade"], "feet": ["Shoes", "Sole"]},
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
	"earth_kid": {"fur": ["Skin", "Nose", "Ear Inner"], "hair": ["Hair"], "eyes": ["Iris", "Iris Light"],
		"accent": ["Backpack", "Backpack Dark"], "blush": ["Blush"]},
	"bunny": {"fur": ["Fur", "Ear", "Fur Light"], "eyes": ["Iris", "Iris Light"], "accent": ["Flower", "Flower Middle"],
		"blush": ["Blush"]},
	"cat": {"fur": ["Fur", "Ear", "Stripe", "Fur Light"], "eyes": ["Iris", "Iris Light"], "accent": ["Collar"],
		"blush": ["Blush"]},
	"dino": {"fur": ["Skin"], "eyes": ["Iris", "Iris Light"], "accent": ["Spike", "Horn"], "blush": ["Blush"]},
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


static func dress(model: Node3D, who: String, outfit: Dictionary, looks := {}, hidden := [], hair: Node3D = null) -> Array:
	# Put an outfit and looks on someone's model, taking off whatever was on before. hidden: parts of them to hide
	# (the hero's own hair under a new hairstyle, say); hair: a hairstyle to wear (scripts/hairstyles.gd). Gives back
	# everything that ended up hidden, as anything worn over a part hides it too (a hat hides Dash's cap).
	var mesh := _body(model)
	var skel := _skeleton(model)
	if mesh == null or skel == null:
		if hair:
			hair.free()
		return []
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
	var gone := hidden.duplicate()
	for slot in UNDER:
		if wearing(outfit, slot) != "" and can_wear(who, slot):
			for n in UNDER[slot]:
				if n not in gone:
					gone.append(n)
	var fit := fit_of(model, gone)
	if hair:
		fit = _under_hat(fit, hair, wearing(outfit, "head") in Cosmetics.COVERS)
		_attach(model, skel, hair, "hair", fit)
	for slot in SLOTS:
		var id := str(outfit.get(slot, ""))
		if id == "" or not can_wear(who, slot):
			continue
		var clothes: Dictionary = OWN_CLOTHES.get(who, {})
		if RESTYLE.has(id) and clothes.has(slot):
			_restyle(model, clothes[slot], RESTYLE[id])
		var piece := hat_or_piece(slot, id)
		if piece:
			_attach(model, skel, piece, slot, fit)
	_hide(model, gone)
	return gone


static func _under_hat(fit: Dictionary, hair: Node3D, covered: bool) -> Dictionary:
	# A hairstyle changes where a hat goes: on top of it, and as wide as it. Under a hat that covers the head,
	# anything sticking up (buns, a mohawk, curls) is tucked away. hair is still in Nina's space here.
	var t := _fitted("hair", fit)
	var crown := AABB(Vector3.ZERO, -Vector3.ONE)
	var balls := []
	for mi in hair.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		match str(m.get_meta("hair", "")):
			"up":
				if covered:
					m.free()
			"crown":
				var x: Transform3D = t * hair.transform * m.transform
				var b: AABB = x * m.get_aabb()
				crown = b if crown.size.x < 0 else crown.merge(b)
				balls.append([x.origin, x.basis.get_scale() * (m.mesh as SphereMesh).radius])
	if crown.size.x < 0:
		return fit
	var f := fit.duplicate()
	f.crown_balls = balls
	f.top = Vector3(f.top.x, maxf(f.top.y, crown.end.y), f.top.z)
	var hb: AABB = f.hat_box
	f.hat_box = AABB(Vector3(minf(hb.position.x, crown.position.x), hb.position.y, minf(hb.position.z, crown.position.z)),
		Vector3.ZERO).expand(Vector3(maxf(hb.end.x, crown.end.x), hb.end.y, maxf(hb.end.z, crown.end.z)))
	return f


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
const NOT_HEAD := ["Antenna", "Antenna Tip", "Horn", "Horn Tip", "Cap", "Cap White", "Ear", "Ear Lining", "Spike",
	"Whisker"]
const SKIN := ["Skin", "Fur", "Green"]
const HAIR := ["Hair", "Hair Shade", "Hair Tip Teal", "Hair Tip Lavender", "Grey Hair", "Mane Orange", "Mane Teal",
	"Mane Purple", "Mane Pink"]
const TORSO_BONES := ["hips", "spine", "chest", "neck"]
const LEG_BONES := ["thigh.L", "thigh.R"]
# What comes off when something is worn over it: a hat goes on instead of Dash's cap or Nina's bow, new glasses
# instead of their own, wings or a cape instead of a backpack
const UNDER := {"head": ["Cap", "Cap White", "Bow"], "face": ["Glasses", "Lens Shine"], "back": BACKPACKS}
const SKIRT_Y := 0.44                    # where the tutu sits round Nina's middle


static var _clouds := {}


static func _cloud(model: Node3D) -> Dictionary:
	# Every point of their body as they stand in Blender (in their model's space), with the bone that carries it most
	# and the part it belongs to (as numbers into "bones" and "parts"); kept per model. Pieces are fitted to these
	# points, so they hug the real shape.
	var key := model.scene_file_path
	if key != "" and _clouds.has(key):
		return _clouds[key]
	var pos := PackedVector3Array()
	var bone_of := PackedInt32Array()
	var part_of := PackedInt32Array()
	var bones := [""]
	var parts := []
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mi as MeshInstance3D
		var to_model := _in_model(model, mesh)
		# The skin's bones as numbers into bones
		var bind := PackedInt32Array()
		if mesh.skin:
			for j in mesh.skin.get_bind_count():
				var bn := String(mesh.skin.get_bind_name(j))
				if bn not in bones:
					bones.append(bn)
				bind.append(bones.find(bn))
		for s in mesh.mesh.get_surface_count():
			var m := mesh.mesh.surface_get_material(s)
			var name := m.resource_name if m else ""
			if name not in parts:
				parts.append(name)
			var part := parts.find(name)
			var arrays := mesh.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bi = arrays[Mesh.ARRAY_BONES]
			var bw = arrays[Mesh.ARRAY_WEIGHTS]
			var per: int = 0
			if bi is PackedInt32Array and v.size() > 0 and not bind.is_empty():
				per = (bi as PackedInt32Array).size() / v.size()
			for k in v.size():
				pos.append(to_model * v[k])
				part_of.append(part)
				var best := 0
				var most := -1.0
				for j in per:
					if bw[k * per + j] > most:
						most = bw[k * per + j]
						best = bind[bi[k * per + j]] if bi[k * per + j] < bind.size() else 0
				bone_of.append(best)
	var c := {"pos": pos, "bone_of": bone_of, "part_of": part_of, "bones": bones, "parts": parts}
	if key != "":
		_clouds[key] = c
	return c


static func _in_model(model: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = n
	while at != model and at is Node3D:
		t = (at as Node3D).transform * t
		at = at.get_parent()
	return t


static func _flags(names: Array, fn: Callable) -> PackedByteArray:
	# fn(name) for each bone or part name, as 1s and 0s to look up by number
	var out := PackedByteArray()
	for n in names:
		out.append(1 if fn.call(n) else 0)
	return out


class Box:
	# A box grown point by point (quicker than AABB.expand), empty until the first point
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)

	func add(p: Vector3) -> void:
		lo = lo.min(p)
		hi = hi.max(p)

	func empty() -> bool:
		return lo.x > hi.x

	func aabb(fallback: AABB) -> AABB:
		return fallback if empty() else AABB(lo, hi - lo)


static func fit_of(model: Node3D, hidden := []) -> Dictionary:
	# Where everything goes on them, measured from their body (anything hidden left out). Kept per model and per
	# set of hidden parts.
	var key := _key_for(model.scene_file_path, hidden)
	if _fits.has(key) and model.scene_file_path != "":
		return _fits[key]
	var skel := _skeleton(model)
	var c := _cloud(model)
	var bones := {}
	for b in ["head", "chest", "hips", "hand.L", "hand.R", "foot.L", "foot.R"]:
		var i := skel.find_bone(b)
		if i >= 0:
			bones[b] = (_skel_in_model(model, skel) * skel.get_bone_global_rest(i)).origin
	var head: Vector3 = bones.get("head", Vector3(0, 0.9, 0))
	var chest: Vector3 = bones.get("chest", head - Vector3(0, 0.14, 0))
	var fit := {}
	fit.chest = chest
	fit.hips = bones.get("hips", chest - Vector3(0, 0.26, 0))
	fit.torso = maxf(chest.y - fit.hips.y, 0.1)
	fit.neck = (head + chest) / 2.0 + Vector3(0, -0.01, 0)
	if model.scene_file_path == NINA:
		fit.skirt_y = SKIRT_Y
	else:
		var nina := _nina_fit()
		fit.skirt_y = fit.hips.y + (nina.skirt_y - nina.hips.y) * fit.torso / nina.torso

	var pos: PackedVector3Array = c.pos
	var bone_of: PackedInt32Array = c.bone_of
	var part_of: PackedInt32Array = c.part_of
	var shown := _flags(c.parts, func(n: String) -> bool: return n not in hidden)
	var headwear := _flags(c.parts, func(n: String) -> bool: return n not in hidden and n not in NOT_HEAD)
	var loose := _flags(c.parts, func(n: String) -> bool: return n in HAIR or n in BACKPACKS)    # hair and bags: not their body
	var skin := _flags(c.parts, func(n: String) -> bool: return n in SKIN)
	var eye := _flags(c.parts, func(n: String) -> bool: return n in ["Eye White", "Eye"])
	var specs := _flags(c.parts, func(n: String) -> bool: return n == "Glasses")
	var on_head := _flags(c.bones, func(n: String) -> bool: return n == "head")
	var torso := _flags(c.bones, func(n: String) -> bool: return n in TORSO_BONES)
	var leg := _flags(c.bones, func(n: String) -> bool: return n in LEG_BONES)
	var limb := _flags(c.bones, func(n: String) -> bool: return _is_limb(n))
	var ends := ["hand.L", "hand.R", "foot.L", "foot.R"]
	var end_of := PackedInt32Array()
	for n in c.bones:
		end_of.append(ends.find(n))

	# First: the eyes, the whole head, their head itself (skin or fur above the neck, for hairstyles), hands and feet
	var eyes := Box.new()
	var glasses := Box.new()
	var whole := Box.new()
	var skull := Box.new()
	var limbs := [Box.new(), Box.new(), Box.new(), Box.new()]
	var neck_y := head.y + 0.08
	for i in pos.size():
		var p := pos[i]
		var pt := part_of[i]
		var bn := bone_of[i]
		if eye[pt]:
			eyes.add(p)
		if specs[pt]:
			glasses.add(p)
		if on_head[bn] and headwear[pt]:
			whole.add(p)
		if skin[pt] and p.y > neck_y:
			skull.add(p)
		if end_of[bn] >= 0 and shown[pt]:
			(limbs[end_of[bn]] as Box).add(p)
	var whole_head := whole.aabb(AABB(head + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 0.6, 0.6)))
	# New glasses go where their own were (just in front), as far apart as their eyes (Dash's shades are wider than
	# eyes, so when they're all he has, his eyes are taken as most of their width)
	var eye_point := head + Vector3(0, 0.23, 0.29)
	fit.eyes_w = 0.3
	var both := Box.new()
	for b in [eyes, glasses]:
		if not (b as Box).empty():
			both.add((b as Box).lo)
			both.add((b as Box).hi)
	if not both.empty():
		var mid := eyes if not eyes.empty() else glasses
		eye_point = Vector3(head.x, (mid.lo.y + mid.hi.y) / 2.0, both.hi.z + 0.02)
		fit.eyes_w = maxf((eyes.hi.x - eyes.lo.x) if not eyes.empty() else (glasses.hi.x - glasses.lo.x) * 0.65, 0.1)
	fit.eyes = eye_point
	fit.eyes_top = eye_point.y + 0.06
	if not both.empty():
		fit.eyes_top = (eyes if not eyes.empty() else glasses).hi.y
	fit.head_box = skull.aabb(AABB(head + Vector3(-0.3, 0.1, -0.3), Vector3(0.6, 0.5, 0.6)))

	# Then: the top in the middle of the head (so ears, horns and antennae don't count), how wide and deep the head is
	# at the eyes (hair at the sides included), how wide it is all the way up (a slice every centimetre), and round
	# the body (arms and hair left out) at the neck, the chest and the middle where a skirt sits
	var band := whole_head.size.x * 0.18
	var crown := Box.new()
	var crown_body := Box.new()
	var face := Box.new()
	var skin_face := Box.new()
	var neck := Box.new()
	var chest_box := Box.new()
	var skirt := Box.new()
	var lo := whole_head.position.y
	var n := int(ceilf(whole_head.size.y / 0.01)) + 1
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(n)
	right.resize(n)
	left.fill(INF)
	right.fill(-INF)
	var neck_at: float = fit.neck.y
	var skirt_at: float = fit.skirt_y
	for i in pos.size():
		var p := pos[i]
		var pt := part_of[i]
		var bn := bone_of[i]
		if on_head[bn] and headwear[pt]:
			if absf(p.x - head.x) < band:
				crown.add(p)
				if not loose[pt]:
					crown_body.add(p)
			if absf(p.y - eye_point.y) < 0.04:
				face.add(p)
				if skin[pt]:
					skin_face.add(p)
			var k := clampi(int((p.y - lo) / 0.01), 0, n - 1)
			left[k] = minf(left[k], p.x)
			right[k] = maxf(right[k], p.x)
		if shown[pt] and not loose[pt]:
			if torso[bn]:
				if absf(p.y - neck_at) < 0.03:
					neck.add(p)
				if absf(p.y - chest.y) < 0.06:
					chest_box.add(p)
			if (torso[bn] or leg[bn]) and absf(p.y - skirt_at) < 0.04:
				skirt.add(p)
	fit.top = Vector3(head.x, whole_head.end.y, head.z)
	if not crown.empty():
		# On big spiky hair (Pip's mane) a hat sits down into it a bit rather than balancing on the tips
		var y := crown.hi.y
		if not crown_body.empty():
			y = minf(y, crown_body.hi.y + 0.5 * (crown_body.hi.y - eye_point.y))
		fit.top = Vector3(head.x, y, (crown.lo.z + crown.hi.z) / 2.0)
	fit.face = face.aabb(whole_head)
	fit.skin_face = skin_face.aabb(fit.face)    # without hair: straps and glasses' arms go under it
	fit.hat_box = fit.face                      # what a hat has to fit over (a hairstyle makes it bigger: _under_hat)
	fit.profile = [lo, left, right]
	fit.neck_box = neck.aabb(AABB(fit.neck - Vector3(0.12, 0.03, 0.12), Vector3(0.24, 0.06, 0.24)))
	fit.chest_box = chest_box.aabb(AABB(chest - Vector3(0.2, 0.06, 0.15), Vector3(0.4, 0.12, 0.3)))
	fit.skirt_box = skirt.aabb(AABB(Vector3(fit.hips.x - 0.2, skirt_at - 0.04, fit.hips.z - 0.15), Vector3(0.4, 0.08, 0.3)))

	# Last: their back. In slices a centimetre high from the neck down past the hips, how far back their body reaches,
	# and their hair (a cape hangs outside long hair rather than through it). Only something as wide as a good part of
	# their back counts, coming in from behind: a tail with no bone of its own (the cat's curls up behind her) isn't
	# their back, and things worn on the back used to float out on it.
	var cape_lo: float = fit.hips.y - fit.torso * 1.6
	var slices := maxi(int(ceilf((neck_at + 0.04 - cape_lo) / 0.01)), 1)
	var cw: float = fit.chest_box.size.x * 0.6     # (as wide as a cape: hair at its edges counts too)
	var body_bins := []
	var hair_bins := []
	for k in slices:
		body_bins.append({})
		hair_bins.append({})
	for i in pos.size():
		var p := pos[i]
		if shown[part_of[i]] and not limb[bone_of[i]] and absf(p.x - chest.x) < cw and p.y >= cape_lo:
			var k := int((p.y - cape_lo) / 0.01)
			if k < slices:
				var bins: Dictionary = hair_bins[k] if loose[part_of[i]] else body_bins[k]
				var zb := int(floorf(p.z / 0.01))
				var span: Vector2 = bins.get(zb, Vector2(INF, -INF))
				bins[zb] = Vector2(minf(span.x, p.x), maxf(span.y, p.x))
	var wide: float = fit.chest_box.size.x * 0.35
	var reach := _reach(body_bins, wide)
	var hair_reach := _reach(hair_bins, wide)
	fit.cape_back = [cape_lo, reach, hair_reach]
	# The back pieces (wings, jetpack) go against the furthest back of it between their hips and their neck
	var back_z := INF
	for k in slices:
		var y: float = cape_lo + k * 0.01
		if y > fit.hips.y and y < neck_at:
			back_z = minf(back_z, reach[k])
	fit.back = Vector3(chest.x, chest.y, back_z if is_finite(back_z) else fit.chest_box.position.z)

	# Hands and feet: the middle of each, how big it is, and which way it points from the wrist or ankle
	for e in ends.size():
		var joint: Vector3 = bones.get(ends[e], fit.hips)
		var box: AABB = (limbs[e] as Box).aabb(AABB(joint - Vector3(0.05, 0.05, 0.05), Vector3(0.1, 0.1, 0.1)))
		fit[ends[e]] = {"box": box, "joint": joint, "dir": (box.get_center() - joint).normalized()}
	# Ears that stand up past the top of their head (Rex's): hats stay low enough for the tips to poke out
	# (the top of the head itself is measured in a strip down the middle, between the ears; the ears' tips are the
	# highest point of the head)
	var ears := Box.new()
	var ear := _flags(c.parts, func(n: String) -> bool: return n in ["Ear Inner", "Ear Lining"])
	var skull_top := -INF
	var head_top := -INF
	for i in pos.size():
		if on_head[bone_of[i]] and headwear[part_of[i]]:
			head_top = maxf(head_top, pos[i].y)
			if absf(pos[i].x - head.x) < 0.03:
				skull_top = maxf(skull_top, pos[i].y)
			if ear[part_of[i]]:
				ears.add(pos[i])
	fit.skull_top = skull_top
	fit.ears_top = head_top if not ears.empty() and ears.hi.y > skull_top + 0.03 else -INF
	if model.scene_file_path != "":
		_fits[key] = fit
	return fit


static func _reach(slices: Array, wide: float) -> PackedFloat32Array:
	# For each slice's depth bins (z in centimetres -> the x span there), coming in from behind: the first depth where
	# everything so far is at least this wide side to side
	var out := PackedFloat32Array()
	out.resize(slices.size())
	out.fill(INF)
	for k in slices.size():
		var bins: Dictionary = slices[k]
		var keys := bins.keys()
		keys.sort()
		var lo := INF
		var hi := -INF
		for zb in keys:
			var span: Vector2 = bins[zb]
			lo = minf(lo, span.x)
			hi = maxf(hi, span.y)
			if hi - lo >= wide:
				out[k] = zb * 0.01
				break
	return out


static func _is_limb(bone: String) -> bool:
	for k in ["arm", "hand", "thigh", "shin", "foot", "front", "paw", "tail", "wing", "antenna"]:
		if k in bone:
			return true
	return false


static func _nina_fit() -> Dictionary:
	# The pieces were made on Nina, so her measurements are where they start from (without her backpack, which the
	# back pieces take the place of)
	if not _fits.has(_key_for(NINA, BACKPACKS)):
		var nina := (load(NINA) as PackedScene).instantiate() as Node3D
		nina.scene_file_path = NINA
		fit_of(nina, BACKPACKS)
		nina.free()
	return _fits[_key_for(NINA, BACKPACKS)]


static func _key_for(path: String, hidden: Array) -> String:
	var names := hidden.duplicate()
	names.sort()
	return path + " | " + ",".join(names)


static func _skel_in_model(model: Node3D, skel: Skeleton3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = skel
	while n != model and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _fitted(slot: String, fit: Dictionary, part := "") -> Transform3D:
	# Moves and stretches a piece made for Nina onto someone else: from a place on her to the same place on them,
	# stretched by how much wider, taller and deeper that part of them is
	var nina := _nina_fit()
	var from: Vector3
	var to: Vector3
	var s := Vector3.ONE
	match slot:
		"head":
			# Hats on top of their head (or hair) in the middle, as wide as their head is at the eyes
			# (and no lower over their eyes than on Nina's)
			var k: float = fit.hat_box.size.x / nina.hat_box.size.x
			var ky := minf(k, (fit.top.y - fit.eyes_top) / (nina.top.y - nina.eyes_top))
			s = Vector3(k, ky, clampf(fit.hat_box.size.z / nina.hat_box.size.z, k * 0.85, k * 1.2))
			from = nina.top
			to = fit.top
		"face":
			# Glasses on their eyes, as far apart as their eyes are
			var k: float = fit.eyes_w / nina.eyes_w
			s = Vector3(k, k, k)
			from = nina.eyes
			to = fit.eyes
		"hair":
			# Hairstyles wrap their head itself: Nina's head stretched to theirs, middle to middle
			s = fit.head_box.size / nina.head_box.size
			from = nina.head_box.get_center()
			to = fit.head_box.get_center()
		"neck", "bottoms":
			# Round their neck, or round their middle: as wide and deep as they are there
			var a: AABB = nina.neck_box if slot == "neck" else nina.skirt_box
			var b: AABB = fit.neck_box if slot == "neck" else fit.skirt_box
			s = Vector3(b.size.x / a.size.x, 1.0, b.size.z / a.size.z)
			s.y = fit.torso / nina.torso if slot == "bottoms" else (s.x + s.z) / 2.0
			var ya: float = nina.neck.y if slot == "neck" else nina.skirt_y
			var yb: float = fit.neck.y if slot == "neck" else fit.skirt_y
			from = Vector3(a.get_center().x, ya, a.get_center().z)
			to = Vector3(b.get_center().x, yb, b.get_center().z)
		"back":
			# Against their back, as wide as their chest and as tall as their body
			var w: float = fit.chest_box.size.x / nina.chest_box.size.x
			s = Vector3(w, fit.torso / nina.torso, w)
			from = nina.back
			to = fit.back
		"hands":
			# Round each hand, as big as it is and pointing the way it points
			var a: Dictionary = nina[part]
			var b: Dictionary = fit[part]
			var k: float = (b.box as AABB).size.length() / (a.box as AABB).size.length()
			var turn := Basis(Quaternion(a.dir, b.dir)) if (a.dir as Vector3).dot(b.dir) < 0.999 else Basis.IDENTITY
			var m := turn * Basis.from_scale(Vector3(k, k, k))
			return Transform3D(m, (b.box as AABB).get_center() - m * (a.box as AABB).get_center())
		"feet":
			# Round each foot, from the ground up
			var a: AABB = nina[part].box
			var b: AABB = fit[part].box
			s = Vector3(b.size.x / a.size.x, 1.0, b.size.z / a.size.z)
			s.y = (s.x + s.z) / 2.0
			from = Vector3(a.get_center().x, a.position.y, a.get_center().z)
			to = Vector3(b.get_center().x, b.position.y, b.get_center().z)
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
	if slot == "head":
		_under_ears(piece, fit)
	_tailor(piece, fit)
	_fix(model, skel, piece, str(ANCHORS.get(slot, ["chest"])[0]), slot)


static func _under_ears(hat: Node3D, fit: Dictionary) -> void:
	# On a head whose ears stand up past its top (Rex), a hat as tall as usual swallowed the ears whole. Squash it
	# down towards the top of the head so the top part of each ear pokes out above it.
	var above: float = fit.ears_top - fit.skull_top
	if above < 0.03:
		return
	var limit: float = fit.skull_top + above * 0.6
	var hi := -INF
	for mi in hat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var box := _in_model(hat, m) * m.get_aabb()
		hi = maxf(hi, (hat.transform * box).end.y)
	if hi <= limit:
		return
	var f: float = (limit - fit.skull_top) / (hi - fit.skull_top)
	var squash := Transform3D(Basis.from_scale(Vector3(1.0, f, 1.0)), Vector3(0, fit.skull_top * (1.0 - f), 0))
	hat.transform = squash * hat.transform


static func _tailor(piece: Node3D, fit: Dictionary) -> void:
	# A few parts are made to measure instead of just stretched: glasses' arms reach back to the sides of their head,
	# goggles' band and headphones go round their head as it really is
	var to_piece := piece.transform.affine_inverse()
	var face: AABB = fit.skin_face
	var k := piece.transform.basis.get_scale().x
	var cups := {}
	var band: Material = null
	for mi in piece.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		match str(m.get_meta("fit", "")):
			"cup":
				# On the side of their head at the same height, just outside it (hair included)
				var p := piece.transform * m.position
				var side := signf(p.x - fit.eyes.x)
				var at := Vector3(_head_edge(fit, p.y, side) + side * 0.035 * k, p.y, face.get_center().z)
				m.transform = to_piece * Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)).scaled(Vector3(k, k, k)), at)
				cups[side] = at
			"band":
				band = m.material_override
				m.free()
	if band and cups.size() == 2:
		# The headphones' band, made again from cup to cup over the top of their head: one smooth, rounded arch,
		# made wider all over (not bent out bit by bit, which made it a box) until it clears their head, or their hair,
		# everywhere up its sides. Near the top it rides over the head in the middle, so ears that stand up there
		# (Rex's) don't push it out into a box.
		var mid: Vector3 = (cups[-1.0] + cups[1.0]) / 2.0
		var half: float = (cups[1.0].x - cups[-1.0].x) / 2.0
		var up: float = fit.top.y + 0.018 - mid.y
		if fit.get("ears_top", -INF) > fit.top.y - 0.02:
			up = fit.get("skull_top", fit.top.y) + 0.018 - mid.y
		var n := 16
		var dirs := []
		var widen := 1.0
		for i in n + 1:
			var a := PI * i / n
			var d := Vector2(-signf(cos(a)) * pow(absf(cos(a)), 0.7), pow(sin(a), 0.7))   # a little squarer than a circle
			dirs.append(d)
			var at_y := mid.y + d.y * up
			var grow := smoothstep(0.0, 0.5, d.y)             # (its ends stay on the cups)
			if absf(d.x) > 0.35 and at_y < mid.y + up * 0.75 and grow > 0.15:
				var side := signf(d.x)
				var need := absf(_head_edge(fit, at_y, side) + side * 0.018 - mid.x)
				widen = maxf(widen, 1.0 + (need / (absf(d.x) * half) - 1.0) / grow)
		var points := []
		for d in dirs:
			var w := 1.0 + (widen - 1.0) * smoothstep(0.0, 0.5, (d as Vector2).y)
			points.append(mid + Vector3((d as Vector2).x * half * w, (d as Vector2).y * up, 0))
		for i in n:
			var p0: Vector3 = points[i]
			var p1: Vector3 = points[i + 1]
			var b := BoxMesh.new()
			b.size = Vector3(p0.distance_to(p1) + 0.012, 0.035, 0.06)
			var seg := MeshInstance3D.new()
			seg.mesh = b
			seg.material_override = band
			piece.add_child(seg)
			seg.transform = to_piece * Transform3D(Basis.from_euler(Vector3(0, 0, atan2(p1.y - p0.y, p1.x - p0.x))), (p0 + p1) / 2.0)
	for mi in piece.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		match str(m.get_meta("fit", "")):
			"temple":
				# Along the side of their head at the eyes, from the glasses back towards their ears
				var side := signf((piece.transform * m.position).x - fit.eyes.x)
				var x: float = (face.end.x if side > 0 else face.position.x) + side * 0.012
				var z0: float = fit.eyes.z - 0.01
				var z1: float = lerpf(face.get_center().z, z0, 0.35)
				var at := Transform3D(Basis.from_scale(Vector3(1, 1, (z0 - z1) / 0.22)), Vector3(x, fit.eyes.y + 0.015, (z0 + z1) / 2.0))
				m.transform = to_piece * at
			"collar":
				# Round their neck like a scarf, wherever their back is
				m.transform = to_piece * _fitted("neck", fit) * m.transform
			"cape":
				var cape := _cape(fit)
				m.transform = to_piece * Transform3D((cape.basis as Basis) * Basis.from_scale(Vector3(cape.width / 0.5, cape.length / 0.62, 1.0)), cape.at)
			"cape_badge":
				# On the cape, a little above its middle, on the outside
				var cape := _cape(fit)
				var k2: float = cape.width / 0.5
				var at: Vector3 = cape.at + cape.basis.y * cape.length * 0.05 - cape.basis.z * 0.02
				m.transform = to_piece * Transform3D((cape.basis as Basis) * Basis.from_euler(Vector3(PI / 2, 0, 0)) * Basis.from_scale(Vector3(k2, 1.0, k2)), at)
			"wrap":
				# A band round their head at the eyes, just outside it
				var r := Vector3(face.size.x / 2.0 + 0.02, 0.0, face.size.z / 2.0 + 0.02) / 0.28
				var at := Transform3D(Basis.from_scale(Vector3(r.x, 0.3, r.z)), Vector3(face.get_center().x, fit.eyes.y + 0.01, face.get_center().z))
				m.transform = to_piece * at


static func _cape(fit: Dictionary) -> Dictionary:
	# A cape made to measure (in their model's space): from their shoulders, just touching their back (or the back of
	# their hair), hanging down past their hips and leaning out just enough to clear the roundest part of them, so it
	# never cuts through a round tummy-and-bottom body or long hair. Stretched only, it used to stand off a round
	# back at the top or go through hair.
	var nina := _nina_fit()
	var kt: float = fit.torso / nina.torso
	var width: float = 0.5 * fit.chest_box.size.x / nina.chest_box.size.x
	var y_top: float = fit.neck.y - 0.05 * kt
	var length: float = 0.62 * kt
	var y_bot: float = y_top - length * cos(0.18)
	var lo: float = fit.cape_back[0]
	var reach: PackedFloat32Array = fit.cape_back[1]
	var hair: PackedFloat32Array = fit.cape_back[2]
	# Hair only counts if it's long, hanging well down over where the cape goes (Bramble's). A bob that ends at the
	# shoulders (Nina's) just lies over the top of the cape.
	var k_long := int((y_top - 0.3 * kt - lo) / 0.01)
	var long_hair := k_long >= 0 and k_long < hair.size() and is_finite(hair[k_long])
	var back_at := func(y: float) -> float:
		var k := int((y - lo) / 0.01)
		var z := INF
		for j in range(k - 1, k + 2):
			if j >= 0 and j < reach.size():
				z = minf(z, reach[j])
				if long_hair:
					z = minf(z, hair[j])
		return z
	var z_top := INF                       # (the furthest back near the top, so the top edge rests on their shoulders)
	var yy := y_top
	while yy > y_top - 0.08 * kt:
		z_top = minf(z_top, back_at.call(yy))
		yy -= 0.01
	if not is_finite(z_top):
		z_top = fit.back.z
	z_top -= 0.015
	var z_bot := z_top - length * sin(0.18)
	var y := y_top - 0.01
	while y > y_bot:
		var t := (y_top - y) / (y_top - y_bot)
		var z: float = back_at.call(y)
		if t > 0.12 and is_finite(z):
			z_bot = minf(z_bot, z_top + (z - 0.02 - z_top) / t)
		y -= 0.01
	var dir := Vector3(0, y_top - y_bot, z_top - z_bot)
	var lean := atan2(dir.z, dir.y)
	return {"at": Vector3(fit.chest.x, (y_top + y_bot) / 2.0, (z_top + z_bot) / 2.0), "basis": Basis.from_euler(Vector3(lean, 0, 0)),
		"width": width, "length": dir.length()}


static func _head_edge(fit: Dictionary, y: float, side: float) -> float:
	# The x of the edge of their head (hair and a hairstyle included) on one side (+1 or -1), at height y
	var lo: float = fit.profile[0]
	var edges: PackedFloat32Array = fit.profile[2] if side > 0 else fit.profile[1]
	var x: float = fit.eyes.x
	var k := int((y - lo) / 0.01)
	for j in range(k - 2, k + 3):                  # a slice either side, as a slice can be empty
		if j >= 0 and j < edges.size() and is_finite(edges[j]):
			x = maxf(x, edges[j]) if side > 0 else minf(x, edges[j])
	for ball in fit.get("crown_balls", []):
		var dy: float = (y - ball[0].y) / ball[1].y
		if absf(dy) < 1.0:
			var w: float = ball[1].x * sqrt(1.0 - dy * dy)
			x = maxf(x, ball[0].x + w) if side > 0 else minf(x, ball[0].x - w)
	return x


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
			for s in [-1, 1]:                                  # arms back to their ears (made to measure: _tailor)
				_mesh(g, _box(Vector3(0.015, 0.015, 0.22)), gold, Vector3(s * 0.2, 1.15, 0.19)).set_meta("fit", "temple")
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
				_mesh(g, _box(Vector3(0.02, 0.015, 0.22)), frame, Vector3(s * 0.2, 1.15, 0.19)).set_meta("fit", "temple")
		"space_goggles":
			var band := _mat(Color(0.35, 0.25, 0.55), 0.6)
			var rim := _mat(Color(0.75, 0.78, 0.85), 0.3, 0.8)
			var glass := _mat(Color(0.4, 1.0, 0.75, 0.6), 0.2, 0.0, 0.6)
			_mesh(g, _torus(0.25, 0.28), band, Vector3(0, 1.14, 0.02), Vector3.ZERO, Vector3(1.0, 0.3, 1.05)).set_meta("fit", "wrap")
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
		"time_keeper_pendant":                             # Dash's thank-you for all 20 lost watches (scripts/watches.gd)
			var gold := _mat(Color(1.0, 0.82, 0.3), 0.3, 0.8)
			_mesh(g, _torus(0.17, 0.182), gold, Vector3(0, 0.84, 0.03), Vector3(0.35, 0, 0))
			_time_keeper(g, Vector3(0, 0.75, 0.26), 0.055)
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
		"time_keeper_watch":                               # only on the left wrist
			var hnd := Node3D.new()
			hnd.name = "L"
			g.add_child(hnd)
			var wrist := Vector3(0.43 - 0.035, 0.49 + 0.075, 0.055)
			_mesh(hnd, _torus(0.04, 0.058), _mat(Color(0.55, 0.35, 0.75), 0.5), wrist, Vector3(0, 0, 0.5))
			_time_keeper(hnd, wrist + Vector3(0, 0, 0.05), 0.032)
		"shift_watch":                                     # the watch that appears on arrival (scripts/first_night.gd)
			var hnd := Node3D.new()
			hnd.name = "L"
			g.add_child(hnd)
			var wrist := Vector3(0.43 - 0.035, 0.49 + 0.075, 0.055)
			_mesh(hnd, _torus(0.04, 0.056), _mat(Color(0.3, 0.8, 0.75), 0.6), wrist, Vector3(0, 0, 0.5))
			var face := Vector3(PI / 2, 0, 0)
			var at := wrist + Vector3(0, 0, 0.05)
			_mesh(hnd, _cyl(0.028, 0.028, 0.012), _mat(Color(0.85, 0.85, 0.95), 0.3, 0.8), at, face)
			_mesh(hnd, _cyl(0.023, 0.023, 0.013), _mat(Color(0.25, 0.15, 0.45), 0.3, 0.0, 0.6), at + Vector3(0, 0, 0.002), face)
			_mesh(hnd, _sphere(0.005), _mat(Color(0.65, 1.0, 0.4), 0.3, 0.0, 2.0), at + Vector3(0, 0.014, 0.008))
			_mesh(hnd, _box(Vector3(0.003, 0.016, 0.002)), _mat(Color(1, 0.95, 0.7), 0.4, 0.0, 1.0),
				at + Vector3(0.004, 0.006, 0.008), Vector3(0, 0, -0.6))
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
			# Hanging from her shoulders, just touching her back at the top; its gold collar goes round her neck
			_mesh(g, _box(Vector3(0.5, 0.62, 0.025)), cloth, Vector3(0, 0.52, -0.29), Vector3(0.18, 0, 0)).set_meta("fit", "cape")
			_mesh(g, _torus(0.16, 0.19), _mat(Color(1.0, 0.85, 0.25), 0.4, 0.6), Vector3(0, 0.85, 0.0), Vector3.ZERO, Vector3(1, 0.5, 1)).set_meta("fit", "collar")
			_mesh(g, _cyl(0.07, 0.07, 0.02, 5), _mat(Color(1.0, 0.85, 0.25), 0.4, 0.6, 0.6), Vector3(0, 0.55, -0.31),
				Vector3(PI / 2 + 0.18, 0, 0)).set_meta("fit", "cape_badge")
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


static func _time_keeper(parent: Node3D, at: Vector3, r: float) -> void:
	# The Time Keeper's face: a gold case, a lilac dial with a teal star at twelve and two hands, facing out
	var face := Vector3(PI / 2, 0, 0)
	_mesh(parent, _cyl(r, r, r * 0.4), _mat(Color(1.0, 0.82, 0.3), 0.3, 0.8), at, face)
	_mesh(parent, _cyl(r * 0.82, r * 0.82, r * 0.45), _mat(Color(0.8, 0.7, 1.0), 0.3, 0.0, 0.3), at + Vector3(0, 0, 0.002), face)
	_mesh(parent, _sphere(r * 0.14), _mat(Color(0.3, 0.95, 0.85), 0.3, 0.0, 1.0), at + Vector3(0, r * 0.6, r * 0.25))
	for k in 2:                                          # each hand reaches out from the middle
		var a := 0.7 + k * 2.4
		var l := r * (0.65 - k * 0.2)
		_mesh(parent, _box(Vector3(r * 0.08, l, r * 0.06)), _mat(Color(0.2, 0.12, 0.3), 0.4),
			at + Vector3(-sin(a) * l / 2.0, cos(a) * l / 2.0, r * 0.26), Vector3(0, 0, a))


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
