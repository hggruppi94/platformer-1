class_name Townsfolk
extends Node3D

# Someone who lives in the Earth town (tools/build_earth.gd), made with the hero system the player uses: the Earth
# kid body (tools/build_hero_bodies.py) dressed and shaped by Hero.apply() from a hero-style look (colours from
# Hero.SWATCHES, a hairstyle, height, head size, build and face), plus a few things of their own made from shapes
# (EXTRAS: an apron, a guitar, Nina's red bow...). Grown-ups are the same body, taller, with a smaller head.
# Mr. Palmer is the exception: he has his own human model (model_path), which is used as it is.
# A look that names another hero body ("body": "cat") is made from that body instead: that's how the episode quests'
# visitors in Galaxity (scripts/episodes.gd: Melanie, Leo, the Wizard Lizard...) are made, as creatures, the way kids
# are there. EXTRAS are placed for the Earth kid body, so they're only for Earth kids.
#
# The model is made as they enter the scene, before their Routine (scripts/routine.gd) and Talk spot
# (scripts/talker.gd) wake up, so the routine finds its AnimationPlayer. With no routine they just stand and idle.

const BODY := "res://models/characters/earth_kid.glb"
# Where each thing sits on the Earth kid body as drawn (model space, metres), and the bone that carries it
const EXTRAS := {
	"bow": "head", "turtleneck": "chest", "apron": "spine", "glasses": "head", "cap": "head", "chef_hat": "head",
	"guitar": "chest", "pearls": "chest", "fire_helmet": "head", "book": "hand.L", "skateboard": "hand.R",
	"bow_tie": "chest", "scarf": "chest", "shawl": "chest", "headband": "head", "moustache": "head", "flower": "head",
	"clipboard": "hand.L", "cardigan": "spine", "striped_beanie": "head", "freckles": "head",
	"bruno_beanie": "head", "open_hoodie": "chest",
}

@export var look := {}                     # a hero (Hero.blank()'s shape); empty for a model used as it is
@export var outfit := {}                   # clothes by slot (scripts/clothes.gd), e.g. {"head": "sk8_beanie"}
@export var extras: Array = []             # [{"kind": "apron", "color": Color}], from EXTRAS
@export var model_path := BODY
@export var placeholder := false           # a stand-in look until there's a drawing (Prue)

var model: Node3D
var _anim: AnimationPlayer


func _enter_tree() -> void:
	if model:
		return
	var own_body := str(look.get("body", "earth_kid"))
	if model_path == BODY and own_body != "earth_kid" and Hero.BODIES.has(own_body):
		model_path = Hero.model_path(look)
	model = (load(model_path) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	if not look.is_empty():
		var hero := look.duplicate(true)
		hero["body"] = own_body if Hero.BODIES.has(own_body) else "earth_kid"
		Hero.apply(model, hero, outfit)
	var skel := Clothes._skeleton(model)
	if skel:
		for e in extras:
			_extra(skel, e)
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _ready() -> void:
	if _anim and not has_node("Routine") and _anim.has_animation("idle"):
		_anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
		_anim.seek(randf() * _anim.current_animation_length)


func height() -> float:
	# How tall they stand, roughly: the Earth kid body is 1.39 m as drawn
	if model_path == BODY or str(look.get("body", "")) in Hero.BODIES:
		return 1.39 * float(look.get("height", 1.0))
	return 1.8


# -----------------------------------------------------------------------------
# Their own things, made from shapes
# -----------------------------------------------------------------------------
func _extra(skel: Skeleton3D, e: Dictionary) -> void:
	var kind := str(e.get("kind", ""))
	var bone := skel.find_bone(str(EXTRAS.get(kind, "chest")))
	if bone < 0:
		return
	var c: Color = e.get("color", Color(0.8, 0.2, 0.2))
	var g := Node3D.new()
	g.name = kind
	match kind:
		"bow":                                         # Nina's big bow, on top of her head, a bit to one side
			for s in [-1.0, 1.0]:
				_mesh(g, _cone(0.0, 0.13, 0.2), c, Vector3(0.15 + s * 0.1, 1.43 - s * 0.03, 0.02), Vector3(0, 0, s * PI / 2 - 0.3),
					Vector3(1, 1, 0.45))
			_mesh(g, _ball(0.055), c.darkened(0.2), Vector3(0.15, 1.43, 0.02))
		"turtleneck":                                  # a rolled collar up the neck
			_mesh(g, _torus(0.1, 0.16), c, Vector3(0, 0.87, 0.0), Vector3.ZERO, Vector3(1, 1.8, 0.95))
		"apron":
			_mesh(g, _box(Vector3(0.34, 0.36, 0.02)), c, Vector3(0, 0.58, 0.155), Vector3(-0.12, 0, 0))
			_mesh(g, _box(Vector3(0.22, 0.14, 0.02)), c, Vector3(0, 0.79, 0.165))
			_mesh(g, _box(Vector3(0.14, 0.07, 0.025)), c.lightened(0.3), Vector3(0, 0.55, 0.175), Vector3(-0.12, 0, 0))
		"cardigan":                                    # an open knitted cardigan: two front panels and buttons
			for s in [-1.0, 1.0]:
				_mesh(g, _box(Vector3(0.11, 0.34, 0.03)), c, Vector3(s * 0.1, 0.66, 0.15), Vector3(-0.08, 0, s * 0.08))
				for k in 3:
					_mesh(g, _ball(0.012), c.lightened(0.4), Vector3(s * 0.05, 0.76 - k * 0.09, 0.168))
		"glasses":
			for s in [-1.0, 1.0]:
				_mesh(g, _torus(0.045, 0.058), c, Vector3(s * 0.09, 1.1, 0.235), Vector3(PI / 2, 0, 0))
			_mesh(g, _box(Vector3(0.06, 0.012, 0.012)), c, Vector3(0, 1.11, 0.24))
		"cap":                                         # a baseball cap, turned round backwards
			_mesh(g, _ball(0.27), c, Vector3(0, 1.3, -0.01), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
			_mesh(g, _box(Vector3(0.3, 0.02, 0.18)), c.darkened(0.25), Vector3(0, 1.26, -0.3), Vector3(-0.15, 0, 0))
		"chef_hat":
			_mesh(g, _cyl(0.2, 0.2, 0.14), Color(0.97, 0.97, 0.95), Vector3(0, 1.38, -0.02))
			_mesh(g, _ball(0.25), Color(0.98, 0.98, 0.96), Vector3(0, 1.56, -0.02), Vector3.ZERO, Vector3(1, 0.7, 1))
		"fire_helmet":                                 # a red fire helmet with a gold badge and a long back brim
			_mesh(g, _ball(0.28), c, Vector3(0, 1.3, -0.02), Vector3.ZERO, Vector3(1.0, 0.75, 1.05))
			_mesh(g, _cyl(0.34, 0.34, 0.02), c.darkened(0.2), Vector3(0, 1.2, -0.06), Vector3(-0.12, 0, 0), Vector3(1, 1, 1.15))
			_mesh(g, _box(Vector3(0.1, 0.1, 0.02)), Color(1.0, 0.8, 0.3), Vector3(0, 1.4, 0.26), Vector3(-0.4, 0, 0))
		"headband":
			_mesh(g, _torus(0.25, 0.28), c, Vector3(0, 1.27, -0.02), Vector3(-0.3, 0, 0), Vector3(1, 0.6, 1.05))
		"flower":                                      # a flower tucked over one ear
			for k in 5:
				var a := k * TAU / 5
				_mesh(g, _ball(0.035), c, Vector3(0.24 + cos(a) * 0.04, 1.22 + sin(a) * 0.04, 0.03))
			_mesh(g, _ball(0.025), Color(1.0, 0.85, 0.3), Vector3(0.245, 1.22, 0.05))
		"striped_beanie":                              # a red-and-white striped beanie with a bobble (the other Nina's)
			for k in 4:
				var band := c if k % 2 == 0 else Color(0.97, 0.95, 0.93)
				_mesh(g, _cyl(0.27 - k * 0.035, 0.3 - k * 0.035, 0.075), band, Vector3(0, 1.27 + k * 0.07, -0.02))
			_mesh(g, _ball(0.17), c, Vector3(0, 1.5, -0.02), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
			_mesh(g, _ball(0.075), Color(0.97, 0.95, 0.93), Vector3(0, 1.6, -0.02))
		"bruno_beanie":                                # Bruno's black knit SK8 beanie, from Sofi's drawing: pulled down
			# to his brows, slouching back, with a folded cuff and the SK8 patch over his left eye
			_mesh(g, _ball(0.3), c, Vector3(0, 1.33, -0.05), Vector3(-0.3, 0, 0), Vector3(1.08, 0.95, 1.12))
			_mesh(g, _cyl(0.315, 0.325, 0.095), c.lightened(0.06), Vector3(0, 1.27, -0.01), Vector3(-0.22, 0, 0))
			var patch := _mesh(g, _box(Vector3(0.1, 0.05, 0.012)), Color(0.12, 0.12, 0.13), Vector3(0.1, 1.29, 0.3),
				Vector3(-0.22, 0.32, -0.1))
			var sk8 := Label3D.new()
			sk8.text = "SK8"
			sk8.font_size = 32
			sk8.pixel_size = 0.0011
			sk8.outline_size = 0
			sk8.modulate = Color(0.92, 0.92, 0.92)
			sk8.position = Vector3(0, 0, 0.0075)
			patch.add_child(sk8)
		"open_hoodie":                                 # an open zip hoodie in his top's colour (set by the look): the
			# olive tee showing down the middle, two zips, the hood bunched behind his neck and white drawstrings
			_mesh(g, _box(Vector3(0.12, 0.34, 0.02)), e.get("tee", Color(0.45, 0.5, 0.15)), Vector3(0, 0.66, 0.172),
				Vector3(-0.06, 0, 0))
			for sd in [-1.0, 1.0]:
				_mesh(g, _box(Vector3(0.012, 0.36, 0.024)), Color(0.75, 0.75, 0.8), Vector3(sd * 0.066, 0.66, 0.18),
					Vector3(-0.06, 0, 0))
				_mesh(g, _cyl(0.007, 0.007, 0.15), Color(0.95, 0.95, 0.95), Vector3(sd * 0.045, 0.76, 0.19))
			_mesh(g, _torus(0.12, 0.2), c, Vector3(0, 0.86, -0.04), Vector3(0.25, 0, 0), Vector3(1.0, 1.6, 1.0))
			_mesh(g, _ball(0.13), c, Vector3(0, 0.83, -0.16), Vector3.ZERO, Vector3(1.2, 0.8, 0.6))
		"freckles":                                    # a sprinkle across the nose and cheeks
			for s in [-1.0, 1.0]:
				for k in 4:
					_mesh(g, _ball(0.009), c, Vector3(s * (0.045 + 0.022 * k), 1.04 + 0.012 * (k % 2), 0.215 - 0.012 * k))
		"moustache":
			for s in [-1.0, 1.0]:
				_mesh(g, _ball(0.04), c, Vector3(s * 0.035, 1.0, 0.215), Vector3(0, 0, s * 0.3), Vector3(1.5, 0.6, 0.7))
		"pearls":
			for k in 11:
				var a := PI * 0.15 + k * PI * 0.7 / 10
				_mesh(g, _ball(0.018), Color(0.97, 0.95, 0.92), Vector3(cos(a) * 0.12, 0.8 - sin(a) * 0.05, sin(a) * 0.13))
		"bow_tie":
			for s in [-1.0, 1.0]:
				_mesh(g, _cone(0.0, 0.04, 0.06), c, Vector3(s * 0.03, 0.84, 0.15), Vector3(0, 0, s * PI / 2))
		"scarf", "shawl":
			_mesh(g, _torus(0.1, 0.17), c, Vector3(0, 0.84, 0.0), Vector3.ZERO, Vector3(1.05, 0.9, 1.05))
			if kind == "scarf":
				_mesh(g, _box(Vector3(0.07, 0.22, 0.03)), c, Vector3(0.07, 0.71, 0.16), Vector3(0, 0, 0.12))
			else:
				_mesh(g, _cone(0.1, 0.25, 0.3), c, Vector3(0, 0.7, -0.08), Vector3.ZERO, Vector3(1.1, 1, 0.8))
		"guitar":                                      # slung across the front, neck up to the left
			var wood := Color(0.75, 0.45, 0.2)
			var body := Node3D.new()
			body.position = Vector3(0.0, 0.58, 0.2)
			body.rotation = Vector3(0, 0, 0.9)
			g.add_child(body)
			_mesh(body, _cyl(0.13, 0.13, 0.06), wood, Vector3(0, -0.05, 0), Vector3(PI / 2, 0, 0))
			_mesh(body, _cyl(0.1, 0.1, 0.06), wood, Vector3(0, 0.12, 0), Vector3(PI / 2, 0, 0))
			_mesh(body, _cyl(0.035, 0.035, 0.065), Color(0.15, 0.1, 0.08), Vector3(0, 0.04, 0.005), Vector3(PI / 2, 0, 0))
			_mesh(body, _box(Vector3(0.04, 0.38, 0.03)), Color(0.35, 0.22, 0.12), Vector3(0, 0.38, 0))
			_mesh(body, _box(Vector3(0.06, 0.08, 0.03)), Color(0.3, 0.18, 0.1), Vector3(0, 0.6, 0))
			_mesh(g, _box(Vector3(0.03, 0.55, 0.02)), c, Vector3(0.0, 0.7, 0.05), Vector3(0, 0, -0.75))   # the strap
		"book":
			_mesh(g, _box(Vector3(0.14, 0.19, 0.04)), c, Vector3(0.38, 0.5, 0.1), Vector3(0, 0.2, 0))
			_mesh(g, _box(Vector3(0.13, 0.18, 0.035)), Color(0.96, 0.94, 0.86), Vector3(0.385, 0.5, 0.1), Vector3(0, 0.2, 0))
		"clipboard":
			_mesh(g, _box(Vector3(0.16, 0.22, 0.015)), Color(0.6, 0.42, 0.25), Vector3(0.36, 0.52, 0.12), Vector3(0, 0.3, 0))
			_mesh(g, _box(Vector3(0.13, 0.16, 0.017)), Color(0.98, 0.98, 0.95), Vector3(0.362, 0.5, 0.122), Vector3(0, 0.3, 0))
		"skateboard":                                  # tucked under the arm
			var deck := Node3D.new()
			deck.position = Vector3(-0.36, 0.55, 0.0)
			deck.rotation = Vector3(PI / 2, 0, 0.15)
			g.add_child(deck)
			_mesh(deck, _box(Vector3(0.05, 0.72, 0.19)), c, Vector3.ZERO)
			for s in [-0.24, 0.24]:
				for w in [-0.07, 0.07]:
					_mesh(deck, _cyl(0.03, 0.03, 0.03), Color(0.95, 0.95, 0.9), Vector3(-0.05, s, w), Vector3(0, 0, PI / 2))
	# Carried by its bone: placed where it sits on the body as drawn, then the bone moves it (and the body shape
	# scales the head's things with the head)
	var holder := BoneAttachment3D.new()
	holder.name = "Own " + kind
	holder.bone_name = skel.get_bone_name(bone)
	skel.add_child(holder)
	var rest := skel.get_bone_global_rest(bone)
	var place := Node3D.new()
	place.transform = rest.affine_inverse()
	holder.add_child(place)
	place.add_child(g)


func _mesh(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 14
	return c


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := _cyl(top, bottom, h)
	c.radial_segments = 10
	return c


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	return t


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
