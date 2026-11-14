extends Townsfolk

# The Seer: a kindly old stargazer who lives in the Observatory on its hill in the Void and sits on the Council, the
# few who watch the stars and try to see what's coming (Hayden, Nov 12 2026: "the seer still isnt in the game and
# needs to be added. Im thinking an old ... woman, but something not racist", then "seer is just that. part of the
# council"). She's made like the grown-up townsfolk (the Earth kid body, taller, a smaller head: scripts/townsfolk.gd)
# and then given her own things, built here from shapes:
#   - a shawl of night sky, stitched with stars that drift and twinkle (scripts/star_shawl.gdshader), gold-edged,
#     with little gold tassels
#   - a long skirt, round gold spectacles, and her white hair up in a bun
#   - a clouded-glass lantern in one hand, mist swirling inside it (scripts/seer_lantern.gdshader): what might be
#     coming shows in the swirls, she says
#   - a crooked walking stick with a crescent moon on top, in the other
#   - Hoot, a sleepy little owl who rides on her shoulder and dozes, breathing slowly, and now and then opens one eye
# On purpose there's nothing of the old fortune-teller costume (no headscarf, coins, crystal-ball tent or caravan):
# she's a stargazing grandma. The lore bible (story/lore-bible.md) says the same.

const SHAWL_SHADER := preload("res://scripts/star_shawl.gdshader")
const LANTERN_SHADER := preload("res://scripts/seer_lantern.gdshader")
# Her look, in the creator's terms (colours are numbers into Hero.SWATCHES, from 1): warm brown skin, white hair in a
# bun (the Top knot), grey eyes, a lavender top and a deep blue skirt. Her build was 1.12 and is a slimmer 0.94 since
# 14 Nov 2026 (Hayden: "make the seer a little skinnier"); her shawl and skirt sit on her bones, so they slim with her
const LOOK := {"colors": {"fur": 22, "hair": 7, "brows": 7, "eyes": 8, "top": 16, "bottoms": 15, "shoes": 4},
	"hairstyle": 28, "extras": false, "height": 1.22, "head": 0.88, "build": 0.94, "eyes": 0.95}
const SKIRT := Color(0.2, 0.2, 0.5)
const GOLD := Color(0.95, 0.75, 0.32)
const OWL := Color(0.62, 0.48, 0.36)
const OWL_FACE := Color(0.93, 0.86, 0.74)

var owl: Node3D                                    # Hoot, on her shoulder
var lantern: Node3D
var _owl_body: Node3D
var _owl_eye: Node3D
var _t := 0.0
var _peek := 4.0                                   # seconds till Hoot next opens an eye
var _dressed := false


func _init() -> void:
	if look.is_empty():
		look = LOOK.duplicate(true)
	if extras.is_empty():
		extras = [{"kind": "glasses", "color": GOLD}]


func _enter_tree() -> void:
	super()
	if _dressed or model == null:
		return
	_dressed = true
	var skel := Clothes._skeleton(model)
	if skel == null:
		return
	_on(skel, "chest", _shawl())
	_on(skel, "hips", _skirt())
	lantern = _lantern()
	_on(skel, "hand.R", lantern)
	_on(skel, "hand.L", _stick())
	owl = _owl()
	_on(skel, "chest", owl)
	_on(skel, "head", _smile_lines())


func _process(delta: float) -> void:
	_t += delta
	if _owl_body:
		# Hoot breathes slowly in his sleep; every so often one eye opens to look at whoever's there, then shuts
		var breathe := 1.0 + sin(_t * 1.6) * 0.04
		_owl_body.scale = Vector3(breathe, 1.0 + (breathe - 1.0) * 0.5, breathe)
		_peek -= delta
		if _owl_eye:
			_owl_eye.visible = _peek < 0.0
		if _peek < -1.4:
			_peek = randf_range(5.0, 11.0)


# -----------------------------------------------------------------------------
# Her things
# -----------------------------------------------------------------------------
func _on(skel: Skeleton3D, bone_name: String, thing: Node3D) -> void:
	# Carried by a bone, placed where it sits on the body as drawn (as Townsfolk._extra does)
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		return
	var holder := BoneAttachment3D.new()
	holder.name = "Seer " + thing.name
	holder.bone_name = bone_name
	skel.add_child(holder)
	var place := Node3D.new()
	place.transform = skel.get_bone_global_rest(bone).affine_inverse()
	holder.add_child(place)
	place.add_child(thing)


func _shawl() -> Node3D:
	# Over her shoulders and down past her elbows, front and back: an open cone of night sky with a gold edge (a
	# narrower cone and skirt since 14 Nov 2026, with her slimmer build, so she doesn't read as a big bell)
	var g := Node3D.new()
	g.name = "Shawl"
	var sky := ShaderMaterial.new()
	sky.shader = SHAWL_SHADER
	var cone := CylinderMesh.new()
	cone.top_radius = 0.16
	cone.bottom_radius = 0.3
	cone.height = 0.38
	cone.radial_segments = 28
	cone.rings = 2
	cone.cap_top = false
	cone.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.name = "Star Shawl"
	mi.mesh = cone
	mi.material_override = sky
	mi.position = Vector3(0, 0.71, -0.01)
	mi.scale = Vector3(1.0, 1.0, 0.9)
	g.add_child(mi)
	_mesh(g, _torus(0.15, 0.2), Color(0.3, 0.15, 0.46), Vector3(0, 0.89, -0.01), Vector3.ZERO, Vector3(1.0, 0.8, 0.92))
	_mesh(g, _torus(0.285, 0.31), GOLD, Vector3(0, 0.52, -0.01), Vector3.ZERO, Vector3(1.0, 1.0, 0.9))
	for k in 20:
		var a := TAU * k / 20.0
		_mesh(g, _ball(0.02), GOLD, Vector3(cos(a) * 0.3, 0.495, sin(a) * 0.3 * 0.9 - 0.01))
	# A gold star brooch pinning it at the front
	_mesh(g, _ball(0.028), GOLD.lightened(0.2), Vector3(0, 0.84, 0.17))
	return g


func _smile_lines() -> Node3D:
	# Little smile lines at the corners of her eyes, so she reads as a grandma and not a kid with white hair
	var g := Node3D.new()
	g.name = "Smile Lines"
	var line := Color(0.5, 0.32, 0.22)
	for s in [-1.0, 1.0]:
		for k in 2:
			_mesh(g, _box(Vector3(0.045, 0.006, 0.006)), line, Vector3(s * 0.175, 1.115 - k * 0.025, 0.17 - k * 0.005),
				Vector3(0, -s * 0.75, s * (0.35 - k * 0.6)))
	return g


func _skirt() -> Node3D:
	# A long skirt down to her ankles, with a darker hem
	var g := Node3D.new()
	g.name = "Skirt"
	_mesh(g, _cyl(0.15, 0.23, 0.46), SKIRT, Vector3(0, 0.3, 0.0))
	_mesh(g, _cyl(0.232, 0.24, 0.04), SKIRT.darkened(0.35), Vector3(0, 0.085, 0.0))
	return g


func _lantern() -> Node3D:
	# Hanging from her right hand by a ring: a brass cap, a clouded glass ball with mist swirling inside, a brass base,
	# and a soft light
	var g := Node3D.new()
	g.name = "Lantern"
	var brass := Color(0.78, 0.58, 0.26)
	var at := Vector3(-0.39, 0.37, 0.09)
	_mesh(g, _torus(0.022, 0.032), brass, at + Vector3(0, 0.17, 0), Vector3(0, 0, PI / 2))
	_mesh(g, _cyl(0.004, 0.004, 0.06), brass, at + Vector3(0, 0.13, 0))
	_mesh(g, _cyl(0.03, 0.06, 0.04), brass, at + Vector3(0, 0.09, 0))
	var glass := MeshInstance3D.new()
	glass.name = "Lantern Glass"
	glass.mesh = _ball(0.065)
	var mist := ShaderMaterial.new()
	mist.shader = LANTERN_SHADER
	glass.material_override = mist
	glass.position = at
	g.add_child(glass)
	for k in 4:                                    # the brass cage round the glass
		var a := TAU * k / 4.0 + PI / 4
		_mesh(g, _cyl(0.004, 0.004, 0.13), brass, at + Vector3(cos(a) * 0.066, 0, sin(a) * 0.066))
	_mesh(g, _cyl(0.055, 0.04, 0.03), brass, at + Vector3(0, -0.075, 0))
	var light := OmniLight3D.new()
	light.name = "Lantern Light"
	light.light_color = Color(0.75, 0.65, 1.0)
	light.light_energy = 0.7
	light.omni_range = 2.6
	light.position = at
	g.add_child(light)
	return g


func _stick() -> Node3D:
	# A crooked wooden walking stick in her left hand, reaching the ground, with a little gold crescent moon on top
	var g := Node3D.new()
	g.name = "Walking Stick"
	var wood := Color(0.42, 0.28, 0.17)
	var x := 0.4
	_mesh(g, _cyl(0.014, 0.017, 0.36), wood, Vector3(x, 0.2, 0.08), Vector3(0, 0, 0.05))
	_mesh(g, _cyl(0.014, 0.014, 0.3), wood, Vector3(x - 0.005, 0.52, 0.08), Vector3(0, 0, -0.06))
	_mesh(g, _ball(0.02), wood.darkened(0.2), Vector3(x + 0.005, 0.37, 0.08))       # a knot in the wood
	var moon := Node3D.new()
	moon.position = Vector3(x - 0.01, 0.72, 0.08)
	g.add_child(moon)
	for k in 9:                                    # a crescent of gold beads, fattest in the middle
		var a := lerpf(-2.2, 2.2, k / 8.0)
		_mesh(moon, _ball(0.016 - absf(a) * 0.004), GOLD, Vector3(-sin(a) * 0.045 - 0.01, cos(a) * 0.045, 0.0))
	return g


func _owl() -> Node3D:
	# Hoot: a round little owl asleep on her left shoulder, eyes shut, ear tufts and a tiny beak
	var g := Node3D.new()
	g.name = "Owl"
	g.position = Vector3(0.23, 0.88, -0.02)
	g.scale = Vector3.ONE * 1.35
	_owl_body = Node3D.new()
	_owl_body.name = "Owl Body"
	g.add_child(_owl_body)
	var b := _owl_body
	_mesh(b, _ball(0.06), OWL, Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(1.0, 1.15, 0.95))
	_mesh(b, _ball(0.045), OWL_FACE, Vector3(0, 0.05, 0.03), Vector3.ZERO, Vector3(1.0, 1.1, 0.6))      # tummy
	for s in [-1.0, 1.0]:
		_mesh(b, _ball(0.035), OWL.darkened(0.15), Vector3(s * 0.055, 0.06, -0.005), Vector3.ZERO, Vector3(0.5, 1.2, 1.0))
		_mesh(b, _cone(0.0, 0.016, 0.04), OWL.darkened(0.2), Vector3(s * 0.03, 0.175, 0.0), Vector3(0, 0, -s * 0.35))
		_mesh(b, _box(Vector3(0.022, 0.005, 0.005)), Color(0.15, 0.1, 0.08), Vector3(s * 0.022, 0.135, 0.055),
			Vector3(0, 0, s * 0.25))                                                                    # shut eyes
	_mesh(b, _ball(0.052), OWL, Vector3(0, 0.13, 0.0), Vector3.ZERO, Vector3(1.05, 0.9, 0.95))           # head
	_mesh(b, _ball(0.04), OWL_FACE, Vector3(0, 0.128, 0.022), Vector3.ZERO, Vector3(1.15, 0.85, 0.5))   # face disc
	_mesh(b, _cone(0.0, 0.009, 0.02), Color(0.95, 0.7, 0.3), Vector3(0, 0.118, 0.05), Vector3(PI / 2 + 0.3, 0, 0))
	for s in [-1.0, 1.0]:
		_mesh(b, _box(Vector3(0.012, 0.012, 0.02)), Color(0.95, 0.7, 0.3), Vector3(s * 0.02, 0.0, 0.03))  # feet
	# The one eye he opens now and then: big and amber, over the shut one on the left
	_owl_eye = Node3D.new()
	_owl_eye.name = "Owl Eye"
	_owl_eye.visible = false
	b.add_child(_owl_eye)
	_mesh(_owl_eye, _ball(0.013), Color(1.0, 0.75, 0.2), Vector3(0.022, 0.135, 0.056))
	_mesh(_owl_eye, _ball(0.006), Color(0.05, 0.05, 0.05), Vector3(0.022, 0.135, 0.067))
	return g
