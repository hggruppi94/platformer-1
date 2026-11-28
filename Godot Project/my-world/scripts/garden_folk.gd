extends Node3D

# The Tuftlings (working name, 28 Nov 2026): the little furry folk who live in the Secret Garden. Hayden shared a
# picture of a small tan furry archer ("Can you put these in the secret garden? A bunch of them that are small like the
# aliens and have them have different personalities, colors, outfits, and quests with male and females", "I want them
# to be the inhabitants of the secret garden", "and add fangs", "and claws"). Inspired by the picture, our own look.
#
# A "Tuftlings" child of the garden (scripts/secret_garden.gd _folk()), made once the garden's bodies are in, so it can
# look for free ground. It puts in:
#   - Tuftling Hollow: eight grassy burrows with round doors in a ring round the Great Tree, each facing it
#     (models/props/garden_folk/burrow.glb, baked by tools/build_prop_folk.py), solid;
#   - the eight named Tuftlings (FOLK), one by each burrow, wandering about their door (scripts/garden_folk_walker.gd),
#     each with their own talk (dialogue/folk_<id>.json) and quest (quests/folk_<id>.json);
#   - more Tuftlings about the garden (CROWD): the same eight models with other fur and clothes colours, wandering by
#     the paths, all sharing dialogue/folk_crowd.json;
#   - the quests' spots (_quest_spots()), each found a free bit of ground near its place (free_spot()).
# Models: tools/build_garden_folk.py, with baked detail from tools/build_friend_detail.py folk_<id>.
# Every Tuftling far from the player rests and isn't drawn (_pace()), like the little aliens.

const LAND := preload("res://scripts/secret_garden_land.gd")
const GROVES := preload("res://scripts/secret_garden_groves.gd")
const WATERS := preload("res://scripts/secret_garden_waters.gd")
const ROOMS := preload("res://scripts/secret_garden_rooms.gd")
const WALKER := preload("res://scripts/garden_folk_walker.gd")
const SPOT := preload("res://scripts/quest_spot.gd")
const MODEL := "res://models/characters/garden_folk_%s.glb"
const PROP := "res://models/props/garden_folk/%s.glb"
const SCALE := 1.15                         # the models are about 0.62 m; shown a touch bigger, like the little aliens
const VILLAGE := GROVES.GREAT_TREE          # Tuftling Hollow is the Great Tree's glade
const HOME_R := Vector2(11.0, 19.0)         # how far from the tree's middle the burrows may sit
const HOME_GAP := 5.2                       # burrows at least this far apart
const WALK_CLEAR := 3.6                     # and this far from the Treetop Walk's line (its posts)
const AWAKE_RANGE := 70.0                   # further than this from the player, a Tuftling rests and isn't drawn

# The named eight: name, which way round the tree their burrow is (radians from +x), boy or girl, what they're like
const FOLK := {
	"fennick": {"name": "Fennick", "angle": 0.3, "girl": false, "about": "brave lookout, best shot in the garden"},
	"thistle": {"name": "Thistle", "angle": 1.0, "girl": true, "about": "cheerful, mad about flowers"},
	"moss": {"name": "Moss", "angle": 1.8, "girl": false, "about": "sleepy, always nodding off"},
	"bluebell": {"name": "Bluebell", "angle": 2.5, "girl": true, "about": "shy and gentle, writes little notes"},
	"bracken": {"name": "Bracken", "angle": 3.3, "girl": false, "about": "grumpy, kind underneath"},
	"clem": {"name": "Clem", "angle": 4.1, "girl": true, "about": "curious explorer, always digging"},
	"tumble": {"name": "Tumble", "angle": 4.9, "girl": false, "about": "the littlest, giggly, loves hide-and-seek"},
	"rosehip": {"name": "Rosehip", "angle": 5.6, "girl": true, "about": "the wise old keeper of the garden"},
}
# The rest of the folk about the garden: [name, model, where (x, z), fur, clothes]
const CROWD := [
	["Pebble", "moss", Vector2(-40.0, 50.0), Color(0.55, 0.55, 0.6), Color(0.35, 0.5, 0.75)],
	["Sorrel", "clem", Vector2(30.0, 25.0), Color(0.75, 0.45, 0.3), Color(0.85, 0.3, 0.45)],
	["Wisp", "bluebell", Vector2(-10.0, 118.0), Color(0.95, 0.9, 0.8), Color(0.95, 0.75, 0.2)],
	["Nettle", "bracken", Vector2(48.0, 80.0), Color(0.45, 0.32, 0.2), Color(0.3, 0.55, 0.3)],
	["Hazel", "thistle", Vector2(0.0, 225.0), Color(0.7, 0.55, 0.35), Color(0.6, 0.4, 0.8)],
	["Burdock", "fennick", Vector2(-30.0, 262.0), Color(0.5, 0.38, 0.25), Color(0.75, 0.45, 0.1)],
	["Sage", "rosehip", Vector2(35.0, 262.0), Color(0.7, 0.72, 0.65), Color(0.4, 0.65, 0.55)],
	["Fern", "tumble", Vector2(-44.0, 92.0), Color(0.9, 0.7, 0.45), Color(0.3, 0.6, 0.85)],
	["Briar", "clem", Vector2(95.0, 150.0), Color(0.35, 0.22, 0.15), Color(0.9, 0.55, 0.65)],
	["Dapple", "thistle", Vector2(-22.0, 22.0), Color(0.85, 0.75, 0.6), Color(0.55, 0.8, 0.4)],
	["Pip-Pip", "tumble", Vector2(80.0, 118.0), Color(0.6, 0.6, 0.65), Color(0.95, 0.5, 0.2)],
	["Thorn", "fennick", Vector2(-95.0, 120.0), Color(0.3, 0.25, 0.22), Color(0.7, 0.2, 0.2)],
]
const FUR_MATS := ["Fur", "Muzzle", "Fur Dark", "Ear Inner"]
const CLOTH_MATS := ["Leaf", "Leaf Dark", "Wrap", "Wrap Light", "Shoe"]

var sg: Node3D                               # the garden
var homes := {}                              # id -> {"at": Vector3, "face": float, "door": Vector3}
var folk := {}                               # id -> the named Tuftling (a garden_folk_walker.gd)
var crowd: Array[Node3D] = []
var spots: Array[Area3D] = []                # every quest spot
var ready_done := false                      # true once everything's in (tests wait for it)
var _pace_t := 0.0
var _player: Node3D


func build(garden: Node3D) -> void:
	sg = garden
	# The garden's own bodies (_solidify()) only go in once the physics world has stepped, and free_spot() asks it
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var mark := Node3D.new()
	mark.name = "Tuftling Hollow"
	mark.set_script(load("res://scripts/landmark.gd"))
	mark.set("label", "Tuftling Hollow")
	add_child(mark)
	mark.global_position = Vector3(VILLAGE.x, LAND.height(VILLAGE.x, VILLAGE.y), VILLAGE.y + GROVES.TRUNK_R + 6.0)
	_homes()
	for id in FOLK:
		_named(id)
	for c in CROWD:
		_crowd_one(c)
	_quest_spots()
	ready_done = true


# -----------------------------------------------------------------------------
# Where things can go
# -----------------------------------------------------------------------------
func _walk_dist(p: Vector2) -> float:
	var best := INF
	var pts: Array = GROVES.WALK + [VILLAGE + Vector2(-GROVES.DECK_R, 0)]
	for i in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p))
	return best


func free_spot(anchor: Vector2, r0: float, r1: float, clear := 0.45, seed_ := 0) -> Vector3:
	# The nearest bit of open, flat-enough ground to anchor between r0 and r1 away, with nothing solid on it (rays from
	# just over the ground, so a glasshouse's roof or a tree's crown overhead doesn't count). Vector3.INF if none.
	var space := get_world_3d().direct_space_state
	var steps := 10
	for i in steps + 1:
		var r := lerpf(r0, r1, float(i) / steps)
		var n := maxi(8, int(TAU * r / 1.2))
		for k in n:
			var a := TAU * (k + seed_ * 0.37) / n
			var p := anchor + Vector2(cos(a), sin(a)) * r
			var g := _ground_at(space, p, clear)
			if g != Vector3.INF:
				return g
	return Vector3.INF


func _ground_at(space: PhysicsDirectSpaceState3D, p: Vector2, clear: float) -> Vector3:
	if LAND.in_lake(p.x, p.y, 0.6) != "" or LAND.slope(p.x, p.y) > 0.5 or LAND.stream_dist(p.x, p.y) < 1.0:
		return Vector3.INF
	if absf(p.x) > LAND.X_HALF - 2.0 or p.y < 2.0 or p.y > LAND.Z_MAX - 2.0:
		return Vector3.INF
	var h := LAND.height(p.x, p.y)
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 1.6, p.y), Vector3(p.x, h - 3.0, p.y))
	var hit := space.intersect_ray(q)
	if hit.is_empty() or absf(hit.position.y - h) > 0.6 or (hit.normal as Vector3).y < 0.8:
		return Vector3.INF
	var at: Vector3 = hit.position
	var sq := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = clear
	sq.shape = ball
	sq.transform = Transform3D(Basis(), at + Vector3.UP * (clear + 0.12))
	if not space.intersect_shape(sq, 1).is_empty():
		return Vector3.INF
	return at


func can_stand(at: Vector3) -> bool:
	# For the walkers: somewhere they may wander to (not in the water, a stream, up a bank or off the garden)
	return LAND.in_lake(at.x, at.z, 0.6) == "" and LAND.slope(at.x, at.z) < 0.5 and LAND.stream_dist(at.x, at.z) > 1.0 \
			and absf(at.x) < LAND.X_HALF - 2.0 and at.z > 2.0 and at.z < LAND.Z_MAX - 2.0 \
			and LAND.quarry_dist(at.x, at.z) > LAND.QUARRY.z + LAND.QUARRY_WALL + 1.0 or _in_quarry_floor(at)


func _in_quarry_floor(at: Vector3) -> bool:
	return LAND.quarry_dist(at.x, at.z) < LAND.QUARRY.z - 1.5


# -----------------------------------------------------------------------------
# Tuftling Hollow: the burrows
# -----------------------------------------------------------------------------
func _homes() -> void:
	var space := get_world_3d().direct_space_state
	var scene := load(PROP % "burrow") as PackedScene
	var taken: Array[Vector2] = []
	for id in FOLK:
		var a0: float = FOLK[id].angle
		var found := Vector3.INF
		for tries in 60:
			var a := a0 + (0.09 * ((tries + 1) / 2) * (1 if tries % 2 == 0 else -1))
			for r in [13.0, 15.0, 11.5, 17.0, 19.0]:
				var p: Vector2 = VILLAGE + Vector2(cos(a), sin(a)) * r
				if _walk_dist(p) < WALK_CLEAR or LAND.path_dist(p.x, p.y) < 2.4:
					continue
				var near := false
				for t in taken:
					if t.distance_to(p) < HOME_GAP:
						near = true
				if near:
					continue
				var g := _ground_at(space, p, 1.25)
				if g != Vector3.INF:
					found = g
					break
			if found != Vector3.INF:
				break
		if found == Vector3.INF:
			push_warning("Tuftlings: no room for %s's burrow" % id)
			continue
		taken.append(Vector2(found.x, found.z))
		var to := Vector2(VILLAGE.x - found.x, VILLAGE.y - found.z)
		var face := atan2(to.x, to.y)             # its door (+Z) looks at the Great Tree
		var b := StaticBody3D.new()
		b.name = "Burrow %s" % FOLK[id].name
		add_child(b)
		b.global_position = found + Vector3.DOWN * 0.08   # sunk a little, so no lip shows on a gentle slope
		b.rotation.y = face
		var m := scene.instantiate() as Node3D
		m.name = "Model"
		b.add_child(m)
		# A ball sunk into the ground is the mound's shape near enough, and needs no mesh data (headless runs have none)
		var cs := CollisionShape3D.new()
		var ball := SphereShape3D.new()
		ball.radius = 1.25
		cs.shape = ball
		cs.position = Vector3(0, -0.2, -0.25)
		b.add_child(cs)
		var door := b.global_transform * Vector3(0, 0, 1.1)
		homes[id] = {"at": found, "face": face, "door": door, "node": b}


# -----------------------------------------------------------------------------
# The folk
# -----------------------------------------------------------------------------
func _walker(model_id: String, nm: String, char_id: String, at: Vector3, radius: float, size: float) -> Node3D:
	var w := CharacterBody3D.new()
	w.set_script(WALKER)
	w.name = nm
	w.set("garden", self)
	w.set("wander_radius", radius)
	var m := (load(MODEL % model_id) as PackedScene).instantiate() as Node3D
	m.name = "Model"
	m.scale = Vector3.ONE * SCALE
	w.add_child(m)
	var cs := CollisionShape3D.new()
	cs.name = "Body Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.16 * size
	cap.height = 0.7 * size
	cs.shape = cap
	cs.position.y = 0.35 * size + 0.02
	w.add_child(cs)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", char_id)
	talk.set("display_name", nm)
	talk.set("talk_radius", 2.0)
	talk.set("name_height", 0.95 * size)
	w.add_child(talk)
	w.position = to_local(at + Vector3.UP * 0.05)   # before it's added: the wandering's home is where it starts
	add_child(w)
	return w


func _named(id: String) -> void:
	if not homes.has(id):
		return
	var h: Dictionary = homes[id]
	var start := free_spot(Vector2(h.door.x, h.door.z), 0.6, 4.0, 0.3)
	if start == Vector3.INF:
		start = h.door
	var size := 0.8 if id == "tumble" else (1.05 if id == "rosehip" else 1.0)
	var w := _walker(id, str(FOLK[id].name), "folk_" + id, start, 4.5, size)
	w.set("home_node", h.node)
	w.rotation.y = h.face + PI                     # looking out from the door
	folk[id] = w


func _crowd_one(c: Array) -> void:
	var start := free_spot(c[2], 0.0, 8.0, 0.3, crowd.size())
	if start == Vector3.INF:
		push_warning("Tuftlings: no room for %s" % c[0])
		return
	var w := _walker(str(c[1]), str(c[0]), "folk_crowd", start, 7.0, 0.8 if c[1] == "tumble" else 1.0)
	recolour(w, c[3], c[4])
	w.rotation.y = randf() * TAU
	crowd.append(w)


static func recolour(who: Node3D, fur: Color, cloth: Color) -> void:
	# Another Tuftling from the same model: its fur and clothes in other colours. The baked detail is a grey tint
	# multiplied with each part's own colour, so it keeps its fur strands and leaf veins.
	for mi in who.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var nm := mat.resource_name
			var to := Color(-1, 0, 0)
			if nm == "Fur":
				to = fur
			elif nm == "Muzzle":
				to = fur.lerp(Color(1, 0.97, 0.9), 0.55)
			elif nm == "Fur Dark":
				to = fur.darkened(0.35)
			elif nm == "Ear Inner":
				to = fur.lerp(Color(1.0, 0.6, 0.65), 0.5)
			elif nm in ["Leaf", "Wrap"]:
				to = cloth
			elif nm in ["Leaf Dark", "Wrap Light"]:
				to = cloth.darkened(0.3) if nm == "Leaf Dark" else cloth.lightened(0.4)
			if to.r < 0.0:
				continue
			var m2 := mat.duplicate() as StandardMaterial3D
			m2.albedo_color = to
			(mi as MeshInstance3D).set_surface_override_material(i, m2)


# -----------------------------------------------------------------------------
# The quests' spots
# -----------------------------------------------------------------------------
func _spot(quest: String, step: String, flag: String, action: String, done: String, at: Vector3, before: Node3D,
		face := 0.0) -> Area3D:
	if at == Vector3.INF:
		push_warning("Tuftlings: no room for %s" % flag)
		return null
	var a := Area3D.new()
	a.set_script(SPOT)
	a.name = "Spot %s" % flag
	a.set("quest", quest)
	a.set("step", step)
	a.set("flag", flag)
	a.set("action", action)
	a.set("done_message", done)
	a.set("radius", 1.6)
	if before:
		before.name = "Before"
		a.add_child(before)
	add_child(a)
	a.global_position = at
	a.rotation.y = face
	spots.append(a)
	return a


func _prop(kind: String, s := 1.0) -> Node3D:
	var n := Node3D.new()
	var m := (load(PROP % kind) as PackedScene).instantiate() as Node3D
	m.scale = Vector3.ONE * s
	n.add_child(m)
	return n


func _firefly() -> Node3D:
	# A firefly: a little glow bobbing over the grass (glows stay plain, like every glow in the game)
	var n := Node3D.new()
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	ball.mesh = sm
	var m := StandardMaterial3D.new()
	m.resource_name = "Firefly Glow"
	m.albedo_color = Color(0.85, 1.0, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.8, 1.0, 0.35)
	m.emission_energy_multiplier = 4.0
	ball.material_override = m
	ball.position.y = 0.9
	ball.name = "Firefly"
	n.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(0.8, 1.0, 0.4)
	light.light_energy = 0.8
	light.omni_range = 2.2
	light.position.y = 0.9
	n.add_child(light)
	return n


func _hiding_tumble() -> Node3D:
	var n := Node3D.new()
	var m := (load(MODEL % "tumble") as PackedScene).instantiate() as Node3D
	m.scale = Vector3.ONE * SCALE
	n.add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("wave"):
		ap.get_animation("wave").loop_mode = Animation.LOOP_LINEAR
		ap.play("wave")
	return n


func _quest_spots() -> void:
	# Fennick's arrows: by the Lake Temple, up the Cypress Walk, in the Supertree Grove, in the Formal Garden
	var arrows := [Vector2(WATERS.TEMPLE.x, WATERS.TEMPLE.z), Vector2(0, 222), Vector2(GROVES.TALLEST.x - 8.0, GROVES.TALLEST.z - 8.0),
		Vector2(-30, 250)]
	for i in arrows.size():
		_spot("folk_fennick", "arrows", "folk_arrow_%d" % (i + 1), "pull out the arrow", "An arrow!",
			free_spot(arrows[i], 5.0 if i == 0 else 2.0, 12.0, 0.4, i), _prop("arrow"), i * 1.3)
	# Thistle's flowers: the Tulip Slope, the Rose Walk, the Potager
	var flowers := [Vector2(12, 118), Vector2(WATERS.ROSE_WALK[1].x - 4.0, WATERS.ROSE_WALK[1].y), ROOMS.POTAGER.get_center()]
	for i in flowers.size():
		_spot("folk_thistle", "flowers", "folk_posy_%d" % (i + 1), "pick the flowers", "Pretty flowers!",
			free_spot(flowers[i], 1.5, 12.0, 0.4, i), _prop("posy"), i * 2.0)
	# Moss's tea: in front of the Tea House
	_spot("folk_moss", "tea", "folk_tea", "pour a cup of tea", "A cup of tea!",
		free_spot(Vector2(WATERS.TEA_HOUSE.x, WATERS.TEA_HOUSE.z - 6.0), 0.0, 8.0, 0.4), _prop("teacup"))
	# Bracken's lucky acorn: in the maze's heart
	var heart: Vector3 = sg.seed_at.get("maze", Vector3(ROOMS.MAZE_ORIGIN.x + 34, 0, ROOMS.MAZE_ORIGIN.y + 24))
	_spot("folk_bracken", "acorn", "folk_acorn", "pick up the acorn", "A lucky acorn!",
		free_spot(Vector2(heart.x, heart.z), 1.2, 6.0, 0.3), _prop("acorn"))
	# Clem's shiny stones: down in the Sunken Quarry
	for i in 3:
		var a := 0.8 + i * 2.1
		var p := Vector2(LAND.QUARRY.x, LAND.QUARRY.y) + Vector2(cos(a), sin(a)) * 7.0
		_spot("folk_clem", "stones", "folk_stone_%d" % (i + 1), "pick up the stone", "A shiny stone!",
			free_spot(p, 0.0, 6.0, 0.3, i), _prop("shiny_stone"), a)
	# Tumble's hiding places: by the koi pond's falls, in the Glasshouse, by the Palladian Bridge
	var hides := [Vector2(WATERS.FALLS.x + 3.0, WATERS.FALLS.y - 7.0), Vector2(GROVES.GLASS.x, GROVES.GLASS.z),
		Vector2(50.0, WATERS.PALLADIAN.x - 5.0)]
	for i in hides.size():
		_spot("folk_tumble", "hide%d" % (i + 1), "folk_hide_%d" % (i + 1), "find Tumble", "Found you!",
			free_spot(hides[i], 0.0, 10.0, 0.35, i), _hiding_tumble(), i * 2.2)
	# Rosehip's fireflies: by four of the Japanese Garden's stone lanterns
	var lanterns: Array[Node3D] = []
	# (found by their foot: Godot renames every lantern group after the first, but not the pieces inside each)
	for n in sg.find_children("Lantern Foot", "", true, false):
		lanterns.append(n.get_parent() as Node3D)
	lanterns.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.z < b.global_position.z)
	var picked := 0
	var used: Array[Vector3] = []
	var anchors: Array[Vector2] = []
	for n in lanterns:
		anchors.append(Vector2(n.global_position.x, n.global_position.z))
	anchors.append(WATERS.KOI_POND)   # if the lanterns are crowded, the koi pond's banks will do
	for c in anchors:
		for tries in 3:
			if picked >= 4:
				break
			var at := free_spot(c, 1.4 + tries * 2.0, 8.0 + tries * 3.0, 0.35, picked + tries)
			if at == Vector3.INF:
				continue
			var close := false
			for u in used:
				if u.distance_to(at) < 4.0:
					close = true
			if close:
				continue
			used.append(at)
			picked += 1
			_spot("folk_rosehip", "fireflies", "folk_firefly_%d" % picked, "catch the firefly", "Got one!", at,
				_firefly())
			break


# -----------------------------------------------------------------------------
# Every half second: Tumble hides while you're looking for him, and far folk rest
# -----------------------------------------------------------------------------
func tumble_hiding() -> bool:
	var step := str(Quests.current_step("folk_tumble").get("id", ""))
	return step.begins_with("hide")


func _process(delta: float) -> void:
	_pace_t -= delta
	if _pace_t > 0.0 or not ready_done:
		return
	_pace_t = 0.5
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var t: Node3D = folk.get("tumble")
	if t:
		var hide := tumble_hiding()
		t.visible = not hide
		t.set("hidden_away", hide)
	for w in folk.values() + crowd:
		var near := _player == null or (w as Node3D).global_position.distance_to(_player.global_position) < AWAKE_RANGE
		w.set("resting", not near)
		if w != t or not tumble_hiding():
			(w as Node3D).visible = near
