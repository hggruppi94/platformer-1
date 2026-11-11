extends RefCounted

# The hero's Void look (Hayden, 11 Nov 2026: "maybe there is another way we can change the characters when they enter
# the void? Adding watches to their wrists etc", then "Yes to the void changes"). In the show, kids are people on Earth
# and creatures in the Void; the hero stays a human kid (the creator's one body), but crossing over changes them a
# little:
#
#   a watch on their left wrist   the Shift Watch (or the Time Keeper once they have it), whether or not they chose to
#                                 wear it, so long as they've got one (it appears on their first crossing:
#                                 scripts/first_night.gd)
#   a soft glow in their eyes     in their Void colour
#   one alien feature             antennae, little horns, pointy ears or a tail, picked on the creator's Void tab
#
# On Earth they look just as they were made. Kept in Game.hero as "void_feature" and "void_glow" (an index into
# GLOWS). A hero has no feature until their first time in the Void: then they get one at random and hear about it
# (so the creator never gives the Void away before they've been). The creator's Void tab only shows after that.
#
# No class_name on purpose (like scripts/use_spot.gd): --script tools compile class_name scripts before the autoloads
# exist, and this looks at Creator. Preload it.

const FEATURES := ["antennae", "horns", "ears", "tail"]
const FEATURE_NAMES := {"antennae": "Antennae", "horns": "Little horns", "ears": "Pointy ears", "tail": "A tail"}
const FEATURE_ABOUT := {
	"antennae": "Two wiggly stalks with glowing tips, for picking up Void signals.",
	"horns": "A pair of curly little horns that glow at the tips.",
	"ears": "Long pointy ears that hear the Void humming.",
	"tail": "A swishy tail with a glowing tuft on the end.",
}
const GLOWS := [Color(0.3, 0.95, 0.85), Color(0.65, 1.0, 0.35), Color(1.0, 0.4, 0.85), Color(0.75, 0.6, 1.0),
	Color(1.0, 0.82, 0.3), Color(0.4, 0.75, 1.0)]
const GLOW_NAMES := ["Teal", "Lime", "Magenta", "Lilac", "Gold", "Sky"]
const EYE_PARTS := ["Iris", "Iris Light"]
const HOLDER := "Void Look"            # every piece's BoneAttachment3D starts with this, so they're easy to take off
const WATCHES := ["shift_watch", "time_keeper_watch"]
const WRIST_R := 0.036                 # how thick the human kids' arm is round the wrist (the watch's band goes round it)
const WRIST_UP := 0.03                 # and how far up the arm from the hand bone the band sits


static func has_look(hero: Dictionary) -> bool:
	# They've been to the Void and got their feature (the creator's Void tab shows from then on)
	return str(hero.get("void_feature", "")) in FEATURES


static func feature(hero: Dictionary) -> String:
	var f := str(hero.get("void_feature", ""))
	return f if f in FEATURES else FEATURES[0]


static func glow(hero: Dictionary) -> Color:
	return GLOWS[posmod(int(hero.get("void_glow", 0)), GLOWS.size())]


static func pick_random(hero: Dictionary) -> void:
	hero["void_feature"] = FEATURES[randi() % FEATURES.size()]
	hero["void_glow"] = randi() % GLOWS.size()


static func in_void(node: Node) -> bool:
	# Is this node's world the Void (the town, the school, its rooms, a portal world, a Void race circuit...)? Only
	# Stars Hollow, the Earth race circuit and the title screen aren't.
	var scene := _scene_of(node)
	if scene == null:
		return false
	var path := scene.scene_file_path
	if path == "res://scenes/earth/earth.tscn" or path.begins_with("res://scenes/title/"):
		return false
	var circuit := str(scene.get("circuit_id")) if "circuit_id" in scene else ""
	if circuit != "":
		var races := _autoload("Races")
		if races:
			var track: Dictionary = races.TRACKS.get(circuit, {})
			if str(track.get("circuit", {}).get("theme", "void")) == "earth":
				return false
	return true


static func shown_on(player: Node) -> bool:
	# Whether the player's hero wears it right now: in the Void, or while the creator's Void tab is showing it off
	var creator := _autoload("Creator")
	if creator and creator.has_method("previewing_void") and creator.previewing_void():
		return true
	return in_void(player)


static func _scene_of(node: Node) -> Node:
	# The scene it's in. While a new scene is still being put in, current_scene can be the old one (or nothing), so
	# go by the node's own ancestors: the one just under the root.
	if node == null or not node.is_inside_tree():
		return null
	var n := node
	var root := node.get_tree().root
	while n.get_parent() and n.get_parent() != root:
		n = n.get_parent()
	return n


static func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(name) if tree else null


# -----------------------------------------------------------------------------
# Putting it on (after Hero.apply, which takes everything off first: Clothes.dress)
# -----------------------------------------------------------------------------
static func apply(model: Node3D, hero: Dictionary, outfit: Dictionary, on: bool) -> void:
	var skel := Clothes._skeleton(model)
	if skel == null:
		return
	for old in skel.find_children(HOLDER + "*", "BoneAttachment3D", false, false):
		old.free()
	if not on:
		return                                   # (Clothes.dress already put their eyes back as they were)
	var c := glow(hero)
	_glow_eyes(model, c)
	_watch(model, skel, outfit)
	match feature(hero):
		"antennae":
			_antennae(model, skel, c)
		"horns":
			_horns(model, skel, c)
		"ears":
			_ears(model, skel, c)
		"tail":
			_tail(model, skel, c)


static func _glow_eyes(model: Node3D, c: Color) -> void:
	# The coloured part of each eye takes on a soft glow, a bit of their own colour and a bit of the Void's
	Clothes._each_surface(model, EYE_PARTS, func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		var now := mesh.get_surface_override_material(i)
		if now == null:
			now = mesh.mesh.surface_get_material(i)
		var m := (now as StandardMaterial3D).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = m.albedo_color.lerp(c, 0.7)
		m.emission_energy_multiplier = 1.4
		mesh.set_surface_override_material(i, m))


static func _watch(model: Node3D, skel: Skeleton3D, outfit: Dictionary) -> void:
	# Their watch on their left wrist (the Time Keeper once they have it, else the Shift Watch), unless they're already
	# wearing one there. Before they have one, nothing. It's made here round the human kids' wrist rather than from the
	# clothes piece (scripts/clothes.gd), which is made for Nina's paw.
	var game := _autoload("Game")
	if game == null or str(outfit.get("hands", "")) in WATCHES:
		return
	var keeper: bool = game.has_item("shop:time_keeper_watch")
	if not keeper and not game.has_item("shop:shift_watch"):
		return
	var g := Node3D.new()
	g.name = "Watch"
	# Just up the arm from the hand bone, its band round the arm, its face looking out and a bit forward
	var elbow := Vector3(0.31, 0.67, 0.03)
	var hand := Vector3(0.38, 0.56, 0.05)
	var arm := (hand - elbow).normalized()
	var out := Vector3(1, 0, 0.7)
	out = (out - arm * out.dot(arm)).normalized()
	var frame := Node3D.new()
	frame.name = "Frame"
	frame.transform = Transform3D(Basis(arm.cross(out).normalized(), arm, out), hand - arm * WRIST_UP)
	g.add_child(frame)
	var band := TorusMesh.new()
	band.inner_radius = WRIST_R
	band.outer_radius = WRIST_R + 0.016
	band.rings = 20
	band.ring_segments = 8
	var bi := MeshInstance3D.new()
	bi.name = "Band"
	bi.mesh = band
	bi.material_override = Clothes._mat(Color(1.0, 0.82, 0.3) if keeper else Color(0.3, 0.8, 0.75), 0.4, 0.6 if keeper else 0.0)
	frame.add_child(bi)
	var at := Vector3(0, 0, WRIST_R + 0.012)
	if keeper:
		Clothes._time_keeper(frame, at, 0.03)
	else:
		var face := Vector3(PI / 2, 0, 0)
		Clothes._mesh(frame, Clothes._cyl(0.03, 0.03, 0.014), Clothes._mat(Color(0.85, 0.85, 0.95), 0.3, 0.8), at, face)
		Clothes._mesh(frame, Clothes._cyl(0.025, 0.025, 0.016), Clothes._mat(Color(0.25, 0.15, 0.45), 0.3, 0.0, 0.6),
			at + Vector3(0, 0, 0.002), face)
		Clothes._mesh(frame, Clothes._sphere(0.006), Clothes._mat(Color(0.65, 1.0, 0.4), 0.3, 0.0, 2.0), at + Vector3(0, -0.017, 0.01))
		Clothes._mesh(frame, Clothes._box(Vector3(0.004, 0.02, 0.003)), Clothes._mat(Color(1, 0.95, 0.7), 0.4, 0.0, 1.0),
			at + Vector3(0.005, -0.007, 0.01), Vector3(0, 0, -0.6))
	_hold(model, skel, g, "hand.L", "watch")


static func _hold(model: Node3D, skel: Skeleton3D, part: Node3D, bone_name: String, what: String) -> void:
	# Like Clothes._fix, but in a holder of our own (so Clothes doesn't count it as clothes)
	var bone := skel.find_bone(bone_name)
	if bone < 0:
		part.free()
		return
	var holder := BoneAttachment3D.new()
	holder.name = "%s %s" % [HOLDER, what]
	holder.bone_name = bone_name
	skel.add_child(holder)
	var rest := Clothes._skel_in_model(model, skel) * skel.get_bone_global_rest(bone)
	part.transform = rest.affine_inverse() * part.transform
	holder.add_child(part)


static func skin_color(model: Node3D) -> Color:
	# (In a box: a lambda gets its own copy of a plain local, so setting one inside it wouldn't come back out)
	var found := [Color(0.93, 0.72, 0.58)]
	Clothes._each_surface(model, ["Skin"], func(mesh: MeshInstance3D, i: int, _k: int) -> void:
		var m := mesh.get_surface_override_material(i)
		if m == null:
			m = mesh.mesh.surface_get_material(i)
		if m is StandardMaterial3D:
			found[0] = (m as StandardMaterial3D).albedo_color)
	return found[0]


static func _mat(color: Color, glow_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	if glow_energy > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow_energy
	return m


static func _chain(parent: Node3D, points: Array, r0: float, r1: float, mat: Material, flat := 1.0) -> void:
	# A bendy limb through these points (in the piece's space), thick at the first and thin at the last: a tapered
	# cylinder between each pair and a ball at each joint so the bends are smooth. flat < 1 squashes it sideways
	# (an ear's thin, not round).
	var n := points.size()
	for i in n - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var ra := lerpf(r0, r1, float(i) / (n - 1))
		var rb := lerpf(r0, r1, float(i + 1) / (n - 1))
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = ra
		cyl.top_radius = rb
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 10
		cyl.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = mat
		var basis := _along(b - a, flat)
		mi.transform = Transform3D(basis, (a + b) / 2.0)
		parent.add_child(mi)
		if i > 0:
			var ball := SphereMesh.new()
			ball.radius = ra
			ball.height = ra * 2.0
			ball.radial_segments = 10
			ball.rings = 6
			var bi := MeshInstance3D.new()
			bi.mesh = ball
			bi.material_override = mat
			bi.transform = Transform3D(basis, a)
			parent.add_child(bi)


static func _along(dir: Vector3, flat := 1.0) -> Basis:
	# A basis whose Y runs along dir, with its Z (squashed by flat) facing as near the front (+Z) as it can
	var up := dir.normalized()
	var ref := Vector3.BACK if absf(up.z) < 0.9 else Vector3.UP
	var fwd := (ref - up * ref.dot(up)).normalized()
	var side := up.cross(fwd).normalized()
	return Basis(side, up, fwd * flat)


static func _ball(parent: Node3D, at: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


# The pieces, in the human kids' model space (feet at y 0, facing +Z, the middle of the head at about (0, 1.1, 0),
# the ears at x 0.245, the top of the head about 1.33). Each goes on the head bone (the tail on the hips), so it turns
# and grows with them.
static func _antennae(model: Node3D, skel: Skeleton3D, c: Color) -> void:
	var g := Node3D.new()
	g.name = "Antennae"
	var stalk := _mat(skin_color(model).lerp(c, 0.25))
	var tip := _mat(c, 2.2)
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * 0.08, 1.27, 0.05), Vector3(s * 0.11, 1.4, 0.06), Vector3(s * 0.15, 1.5, 0.04),
			Vector3(s * 0.2, 1.57, 0.06)]
		_chain(g, pts, 0.02, 0.012, stalk)
		_ball(g, pts[-1], 0.045, tip).name = "Tip"
	_hold(model, skel, g, "head", "antennae")


static func _horns(model: Node3D, skel: Skeleton3D, c: Color) -> void:
	var g := Node3D.new()
	g.name = "Horns"
	var bone := _mat(Color(0.96, 0.9, 0.8).lerp(c, 0.15))
	var tip := _mat(c, 1.6)
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * 0.1, 1.27, 0.09), Vector3(s * 0.17, 1.42, 0.07), Vector3(s * 0.23, 1.53, 0.01),
			Vector3(s * 0.25, 1.6, -0.07)]
		_chain(g, pts, 0.065, 0.016, bone)
		_ball(g, pts[-1], 0.02, tip).name = "Tip"
	_hold(model, skel, g, "head", "horns")


static func _ears(model: Node3D, skel: Skeleton3D, c: Color) -> void:
	var g := Node3D.new()
	g.name = "Ears"
	var skin := _mat(skin_color(model))
	var tip := _mat(c, 1.6)
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * 0.2, 1.07, -0.02), Vector3(s * 0.31, 1.12, -0.04), Vector3(s * 0.4, 1.2, -0.07),
			Vector3(s * 0.46, 1.29, -0.1)]
		_chain(g, pts, 0.09, 0.01, skin, 0.4)
		_ball(g, pts[-1], 0.016, tip).name = "Tip"
	_hold(model, skel, g, "head", "ears")


static func _tail(model: Node3D, skel: Skeleton3D, c: Color) -> void:
	# Out from the bottom of their back, curling down and up again, with a glowing tuft. It swishes slowly.
	var g := Node3D.new()
	g.name = "Tail"
	var swish := Node3D.new()
	swish.name = "Swish"
	swish.position = Vector3(0, 0.5, -0.13)
	g.add_child(swish)
	var skin := _mat(skin_color(model))
	var pts := [Vector3(0, 0, 0), Vector3(0, -0.08, -0.12), Vector3(0, -0.1, -0.26), Vector3(0, -0.04, -0.38),
		Vector3(0, 0.08, -0.45), Vector3(0, 0.2, -0.47)]
	_chain(swish, pts, 0.04, 0.02, skin)
	_ball(swish, pts[-1], 0.055, _mat(c, 1.8)).name = "Tip"
	_hold(model, skel, g, "hips", "tail")
	if swish.is_inside_tree():
		var t := swish.create_tween().set_loops()
		t.tween_property(swish, "rotation:y", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
		t.tween_property(swish, "rotation:y", -0.35, 0.9).set_trans(Tween.TRANS_SINE)
