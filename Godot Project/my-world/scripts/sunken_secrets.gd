extends Node

# Secrets at the bottom of deep water, for anyone who can swim down to them (scripts/swim.gd, Otto's gift once the
# Tide Reef is mended). Hayden: "bury some secrets underwater in most places ... something that has meaning or impact
# on the lore of the game". There are three kinds, and every place with deep water hides one of each:
#   - "piece": the eight Pieces of That Night. Bits of Rex's swap pods and Dash's time core from the night in the far
#     future when both experiments went off at once. Time dropped them, like a pocket with a hole in it, and they sank.
#     Holding one plays an echo of that night. Dash collects them (dialogue/dash.json, "Watches/Sunken.hand_in"); with
#     all eight he works out that the two experiments together cracked the Shift, and that he might know how to fix it.
#   - "watch": the eight Watches of the First Chosen. Long before Nina, other kids were chosen, mended something and
#     went home safe, and each one left their watch in deep water so the Void would remember them.
#   - "bottle": the eight Seer's Bottles. Notes from the future seer, kept vague on purpose (talking about the future
#     makes time ripples), hinting at what's coming.
# Where the water's deep already (the flooded Tide Reef, Willow Pond's middle) they lie on the bottom. Everywhere else
# this puts in a deep pool at play time (`build_pool()`: the ground under it is cut away by scripts/ground_hole.gd and a
# round stone basin is sunk into the hole, with a water.gd node and a surface), so no builder or scene changed. Found
# ones are Dialogue flags (`sunk_<id>`, `sunk_given_<id>`), so nothing new in the save. A secret only shows while
# there's water over it (the Tide Reef's floods once it's mended).
#
# It lives under the Watches autoload ("Watches/Sunken"), like the Lab and the Episodes, so dialogue can reach it.

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const WORLDS := "res://scenes/portal_worlds/"

# The deep pools put in at play time: which scene, the middle (x, z; the ground's height is found), the pool's name
# and its colours. Each spot was checked flat and clear (tools/test_sunken_secrets.gd).
const POOLS := {
	"town": {"scene": TOWN, "at": Vector2(50, -66), "name": "The Wishing Well",
		"stone": Color(0.62, 0.55, 0.78), "trim": Color(1.0, 0.82, 0.4), "glow": Color(0.55, 1.0, 0.85)},
	"shard_isle": {"scene": WORLDS + "shard_isle.tscn", "at": Vector2(8, 0), "name": "The Crystal Basin",
		"stone": Color(0.8, 0.86, 0.95), "trim": Color(0.55, 1.0, 0.9), "glow": Color(0.6, 1.0, 0.95)},
	"rootmind": {"scene": WORLDS + "rootmind.tscn", "at": Vector2(-16, 18), "name": "The Dew Cup",
		"stone": Color(0.42, 0.7, 0.3), "trim": Color(1.0, 0.6, 0.85), "glow": Color(0.7, 1.0, 0.6)},
	"frozen_moment": {"scene": WORLDS + "frozen_moment.tscn", "at": Vector2(18, 24), "name": "The Thaw Pool",
		"stone": Color(0.75, 0.88, 1.0), "trim": Color(1.0, 1.0, 1.0), "glow": Color(0.6, 0.85, 1.0)},
	"lanternmoor": {"scene": WORLDS + "lanternmoor.tscn", "at": Vector2(20, 26), "name": "The Moon Well",
		"stone": Color(0.36, 0.3, 0.5), "trim": Color(1.0, 0.85, 0.5), "glow": Color(1.0, 0.85, 0.55)},
	"rhythm_springs": {"scene": WORLDS + "rhythm_springs.tscn", "at": Vector2(-20, 32), "name": "The Deep Spring",
		"stone": Color(0.9, 0.72, 0.5), "trim": Color(0.55, 0.85, 1.0), "glow": Color(0.5, 0.9, 1.0)},
}
const POOL_R := 3.4                 # inside the wall
const POOL_WALL := 0.5
const POOL_DEEP := 3.6              # the water's depth (out of her depth: she swims)
const LEDGE := 1.0                  # an inside ledge this far under the surface, to stand on and jump out from
const SURFACE_DROP := 0.15         # the water's surface, this far under the ground
const LEDGE_AT := 2.02              # which way round the ledge is
const RIM_SEGS := 48                # the paving round the pool
const RIM_ROWS := 6                 # (0.6 m apart: it reaches out at most 3.6 m past the hole)

# The places with deep water of their own: the scene, and each kind's spot on the bottom (x, z)
const NATURAL := {
	"earth": {"scene": EARTH, "spots": {"piece": Vector2(-86.5, 1.5), "watch": Vector2(-83, -1.5), "bottle": Vector2(-87.5, -2)}},
	"tide_reef": {"scene": WORLDS + "tide_reef.tscn",
		"spots": {"piece": Vector2(-30, 24), "watch": Vector2(34, 6), "bottle": Vector2(14, 34)}},
}

const KINDS := {
	"piece": {"set": "Pieces of That Night", "colour": Color(0.4, 0.85, 1.0)},
	"watch": {"set": "Watches of the First Chosen", "colour": Color(1.0, 0.82, 0.4)},
	"bottle": {"set": "Seer's Bottles", "colour": Color(0.8, 0.6, 1.0)},
}

# Every secret: its id, kind, where (a POOLS or NATURAL key), its name, what it looks like, and what it says. A piece's
# "echo" is what you hear from that night as you hold it. My first drafts, for Hayden to change.
const SECRETS := [
	# Pieces of That Night -------------------------------------------------------------------------------------------
	{"id": "piece_nameplate", "kind": "piece", "place": "town", "name": "Pod Two's Nameplate",
		"about": "A pod door. It says: DO NOT ENTER.",
		"echo": "Rex: \"One minute as a dog. What could go wrong?\""},
	{"id": "piece_ball", "kind": "piece", "place": "earth", "name": "Rook's Ball",
		"about": "A chewed red ball.",
		"echo": "Rex: \"Fetch, Rook! In the pod! Good boy!\""},
	{"id": "piece_lever", "kind": "piece", "place": "tide_reef", "name": "The Swap Lever's Knob",
		"about": "A red knob off a big lever.",
		"echo": "Rex: \"If this works, I WIN! Three, two...\""},
	{"id": "piece_countdown", "kind": "piece", "place": "shard_isle", "name": "Dash's Countdown Clock",
		"about": "A clock, stopped at one second to go.",
		"echo": "Dash: \"Starting my test! Three, two, one...\""},
	{"id": "piece_notes", "kind": "piece", "place": "rootmind", "name": "A Page of Dash's Notes",
		"about": "It says: NEVER RUN TWO EXPERIMENTS AT ONCE.",
		"echo": "Dash: \"Rex? Are you running something too? DON'T...\""},
	{"id": "piece_lens", "kind": "piece", "place": "frozen_moment", "name": "A Cracked Time Lens",
		"about": "A cracked time machine lens.",
		"echo": "(Two machines hum at once. Then... WHITE.)"},
	{"id": "piece_tag", "kind": "piece", "place": "lanternmoor", "name": "Rook's Old Collar Tag",
		"about": "A little tag that says ROOK.",
		"echo": "Rex: \"Why is my nose so GOOD? DASH!\""},
	{"id": "piece_fork", "kind": "piece", "place": "rhythm_springs", "name": "The Time Core's Tuning Fork",
		"about": "It hums two notes that don't match.",
		"echo": "(Something very deep goes CRACK.)"},
	# Watches of the First Chosen ------------------------------------------------------------------------------------
	{"id": "old_first", "kind": "watch", "place": "town", "name": "The First Watch",
		"about": "A tiny stone sundial. On the back:",
		"note": "\"We mended it, then went home. You will too. Ama.\""},
	{"id": "old_walter", "kind": "watch", "place": "earth", "name": "A Pocket Watch from 1893",
		"about": "A silver pocket watch. Inside:",
		"note": "\"Walter, 1893. Home safe. Thank you, old oak.\""},
	# (its id is still "old_grandad" so saves that found it keep it: it was Otto's Grandad's watch until Nov 12, 2026,
	# when Hayden scrapped that lore. Teddy is the chosen kid the Agent of Chaos was: scripts/chaos_ending.gd)
	{"id": "old_grandad", "kind": "watch", "place": "tide_reef", "name": "A Boy's Wristwatch from 1956",
		"about": "A boy's wristwatch, stopped at midnight. On the back:",
		"note": "\"Teddy, 1956. One more trip, then home!\""},
	{"id": "old_lio", "kind": "watch", "place": "shard_isle", "name": "The Singing Shard Pendant",
		"about": "A humming crystal. A tag says:",
		"note": "\"I kept the shards singing. Someone will come. Lio.\""},
	{"id": "old_seed", "kind": "watch", "place": "rootmind", "name": "The Seed Watch",
		"about": "A watch with a seed inside. On the back:",
		"note": "\"I grew into the oldest tree in the wood. Hello!\""},
	{"id": "old_stopwatch", "kind": "watch", "place": "frozen_moment", "name": "A Frost-Rimmed Stopwatch",
		"about": "Stopped on purpose. On it:",
		"note": "\"Don't rush your goodbyes.\""},
	{"id": "old_lantern", "kind": "watch", "place": "lanternmoor", "name": "The Lantern Watch",
		"about": "It glows like a lantern. Round the rim:",
		"note": "\"Light a lantern for me. Sol.\""},
	{"id": "old_metronome", "kind": "watch", "place": "rhythm_springs", "name": "The Metronome Pendant",
		"about": "It ticks, steady. On its weight:",
		"note": "\"Keep the beat. Tempo.\""},
	# Seer's Bottles -------------------------------------------------------------------------------------------------
	{"id": "seer_chosen", "kind": "bottle", "place": "town", "name": "A Bottle from the Seer",
		"note": "Yes, you. You were chosen for a reason."},
	{"id": "seer_oak", "kind": "bottle", "place": "earth", "name": "A Bottle from the Seer",
		"note": "The old oak has opened before."},
	{"id": "seer_bike", "kind": "bottle", "place": "tide_reef", "name": "A Bottle from the Seer",
		"note": "Nobody mends anything alone."},
	{"id": "seer_bodies", "kind": "bottle", "place": "shard_isle", "name": "A Bottle from the Seer",
		"note": "Not every body is where it belongs. Yet."},
	{"id": "seer_giant", "kind": "bottle", "place": "rootmind", "name": "A Bottle from the Seer",
		"note": "Strange things weren't always strange."},
	{"id": "seer_goodbye", "kind": "bottle", "place": "frozen_moment", "name": "A Bottle from the Seer",
		"note": "Every goodbye is a see-you-later."},
	{"id": "seer_portals", "kind": "bottle", "place": "lanternmoor", "name": "A Bottle from the Seer",
		"note": "One portal isn't on any map."},
	{"id": "seer_watch", "kind": "bottle", "place": "rhythm_springs", "name": "A Bottle from the Seer",
		"note": "Your watch always tells the truth."},
]

const REACH := 1.7                   # how near her middle has to come, swimming down
const PIECE_REWARD := {"remnants": 6, "sparkles": 20}
const WATCH_REWARD := 5              # Remnants, for all eight watches
const BOTTLE_REWARD := 5             # ...and for all eight bottles

signal found_secret(id: String)

var _scene: Node
var _holder: Node3D
var _reader: Node3D
var _check := 0.0


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_holder = null
		if s:
			_place_in.call_deferred(s)
	_check -= delta
	if _check <= 0.0 and is_instance_valid(_holder):
		_check = 0.5
		_show_waiting()


# -----------------------------------------------------------------------------
# What's been found
# -----------------------------------------------------------------------------
func secret(id: String) -> Dictionary:
	for s in SECRETS:
		if s.id == id:
			return s
	return {}


func is_found(id: String) -> bool:
	return Dialogue.flags.has("sunk_" + id)


func is_given(id: String) -> bool:
	return Dialogue.flags.has("sunk_given_" + id)


func of_kind(kind: String) -> Array:
	return SECRETS.filter(func(s: Dictionary) -> bool: return s.kind == kind)


func found_of(kind: String) -> int:
	return of_kind(kind).filter(func(s: Dictionary) -> bool: return is_found(s.id)).size()


func to_give() -> Array:
	return of_kind("piece").filter(func(s: Dictionary) -> bool: return is_found(s.id) and not is_given(s.id))


func given_count() -> int:
	return of_kind("piece").filter(func(s: Dictionary) -> bool: return is_given(s.id)).size()


func place_of(key: String) -> Dictionary:
	return POOLS.get(key, NATURAL.get(key, {}))


func spot_of(s: Dictionary) -> Vector2:
	# Where it lies (x, z): in a pool, the three kinds sit round the middle; in natural water, at their own spots
	if NATURAL.has(s.place):
		return NATURAL[s.place].spots[s.kind]
	var p: Dictionary = POOLS[s.place]
	var a: float = {"piece": 0.4, "watch": 2.5, "bottle": 4.6}[s.kind]
	return (p.at as Vector2) + Vector2(cos(a), sin(a)) * POOL_R * 0.5


# -----------------------------------------------------------------------------
# Putting them in
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.has_meta("preview"):
		return
	var here := ""
	for key in POOLS:
		if POOLS[key].scene == s.scene_file_path:
			here = key
	for key in NATURAL:
		if NATURAL[key].scene == s.scene_file_path:
			here = key
	if here == "":
		return
	_holder = Node3D.new()
	_holder.name = "Sunken Secrets"
	_holder.set_meta("place", here)
	s.add_child(_holder)
	_reader = Node3D.new()                       # who's "talking" when one's read out (Dialogue.say needs someone)
	_reader.name = "Reader"
	_reader.set_script(PICKUP)
	_holder.add_child(_reader)
	if POOLS.has(here):
		var pool := build_pool(POOLS[here], (s as Node3D).get_world_3d(), s)
		_holder.add_child(pool)
	_show_waiting()


func _show_waiting() -> void:
	# Put in any secret here that isn't found yet and has water over it (the Tide Reef's sea only comes in once it's
	# mended, so its secrets turn up then)
	var here := str(_holder.get_meta("place"))
	for s in SECRETS:
		if s.place != here or is_found(s.id) or _holder.has_node("Secret " + str(s.id)):
			continue
		var at := spot_of(s)
		var bed := _ground(Vector3(at.x, 60.0, at.y))
		var w: Node = SWIM.water_at(get_tree(), Vector3(at.x, bed, at.y))
		if w == null or float(w.get("water_y")) - bed < 2.0:
			continue
		var pick := Node3D.new()
		pick.name = "Secret " + str(s.id)
		pick.set_script(PICKUP)
		pick.set("id", s.id)
		pick.set("owner_node", self)
		pick.add_child(model(s.kind))
		_holder.add_child(pick)
		pick.global_position = Vector3(at.x, bed + 0.3, at.y)


func _ground(from: Vector3) -> float:
	if not is_instance_valid(_holder):
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -120.0, 0))
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player:
		q.exclude = [player.get_rid()]
	var hit := _holder.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


const SWIM := preload("res://scripts/swim.gd")
const WATER := preload("res://scripts/water.gd")
const PICKUP := preload("res://scripts/sunken_pickup.gd")
const HOLE := preload("res://scripts/ground_hole.gd")


func _height(space: PhysicsDirectSpaceState3D, at: Vector2) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 80, at.y), Vector3(at.x, -60, at.y))
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D if is_inside_tree() else null
	if player:
		q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func build_pool(p: Dictionary, world: World3D, scene: Node = null) -> Node3D:
	# A round stone basin sunk into the ground, deep enough to swim down in. The ground under it is cut away
	# (scripts/ground_hole.gd), so the water's surface lies just under the ground and you can walk straight in. A stone
	# wall lines the hole, a ring of paving covers the cut edge, a ledge inside lets you climb back out, and there's the
	# water (scripts/water.gd, so she splashes in and swims), its surface, and a glow at the bottom.
	var root := Node3D.new()
	root.name = str(p.name)
	var at: Vector2 = p.at
	var space := world.direct_space_state
	var g := _height(space, at)
	root.position = Vector3(at.x, g, at.y)
	root.set_meta("ground", g)
	var bed := -(POOL_DEEP + SURFACE_DROP)          # the bottom, under the ground
	root.set_meta("bed", g + bed)
	# The paving's heights, read before the ground's cut
	var rim_in := POOL_R + POOL_WALL * 0.5
	var heights: Array = []
	for i in RIM_SEGS:
		var a := i * TAU / RIM_SEGS
		var row: Array = []
		for k in RIM_ROWS + 1:
			var d := rim_in + k * 0.6
			row.append(_height(space, at + Vector2(cos(a), sin(a)) * d) - g)
		heights.append(row)
	var reach := rim_in
	if scene:
		reach = HOLE.cut(scene, at, rim_in, g + bed - 1.0, g + 0.5)
	var rim_out := minf(maxf(reach + 0.4, POOL_R + POOL_WALL + 0.6), rim_in + RIM_ROWS * 0.6)
	root.set_meta("rim", rim_out)
	var stone := _mat(p.stone)
	var trim := _mat(p.trim, 0.4)
	var body := StaticBody3D.new()
	body.name = "Walls"
	root.add_child(body)
	var n := 24
	var mid := POOL_R + POOL_WALL * 0.5
	var seg := TAU * mid / n * 1.08
	var wall_h := -bed + 0.5
	for i in n:
		var a := i * TAU / n
		var t := Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * mid, -wall_h * 0.5, sin(a) * mid))
		_box(root, body, Vector3(seg, wall_h, POOL_WALL), t, stone)
		var lip := Transform3D(t.basis, Vector3(cos(a) * mid, 0.04, sin(a) * mid))
		_box(root, null, Vector3(seg, 0.08, POOL_WALL + 0.12), lip, trim)
	_box(root, body, Vector3(POOL_R * 2.0 + 0.4, 0.5, POOL_R * 2.0 + 0.4), Transform3D(Basis(), Vector3(0, bed - 0.25, 0)), stone)
	# The paving round it, following the ground, out over wherever the ground's edge was cut ragged
	_rim(root, body, heights, rim_in, rim_out, (p.stone as Color).darkened(0.12))
	# A ledge just inside, under the water: swim onto it, stand, and jump out
	var la := LEDGE_AT
	var lr := POOL_R - 0.6
	var lh := POOL_DEEP - LEDGE
	_box(root, body, Vector3(1.2, lh, 1.6), Transform3D(Basis(Vector3.UP, -la + PI * 0.5),
		Vector3(cos(la) * lr, bed + lh * 0.5, sin(la) * lr)), stone)
	# The water
	var water := Node3D.new()
	water.name = "Water"
	water.set_script(WATER)
	var outline: Array[Vector4] = [Vector4(at.x, at.y, POOL_R + 0.05, POOL_R + 0.05)]   # (right up to the wall)
	water.set("ellipses", outline)
	water.set("water_y", g - SURFACE_DROP)
	root.add_child(water)
	var surf := MeshInstance3D.new()
	surf.name = "Surface"
	var disc := CylinderMesh.new()
	disc.top_radius = POOL_R
	disc.bottom_radius = POOL_R
	disc.height = 0.04
	surf.mesh = disc
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.25, 0.65, 0.8, 0.32)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.emission_enabled = true
	wm.emission = (p.glow as Color) * 0.35
	wm.roughness = 0.1
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	surf.material_override = wm
	surf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surf.position.y = -SURFACE_DROP
	root.add_child(surf)
	var bottom := MeshInstance3D.new()             # a glowing floor, so the secrets show from the top
	bottom.name = "Floor"
	var fd := CylinderMesh.new()
	fd.top_radius = POOL_R
	fd.bottom_radius = POOL_R
	fd.height = 0.1
	bottom.mesh = fd
	var fm := _mat((p.stone as Color).darkened(0.35))
	fm.emission_enabled = true
	fm.emission = (p.glow as Color) * 0.25
	bottom.material_override = fm
	bottom.position.y = bed + 0.05
	root.add_child(bottom)
	var light := OmniLight3D.new()
	light.light_color = p.glow
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position.y = bed + 1.0
	root.add_child(light)
	var sign := Label3D.new()                       # its name on the top step
	sign.name = "Name"
	sign.text = str(p.name)
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 12
	sign.modulate = p.trim
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var a0 := 1.6
	sign.position = Vector3(cos(a0) * (rim_out + 0.5), 1.5, sin(a0) * (rim_out + 0.5))
	root.add_child(sign)
	return root


func _rim(root: Node3D, body: StaticBody3D, heights: Array, r_in: float, r_out: float, c: Color) -> void:
	# A ring of paving from the wall's top out to r_out, a few centimetres over the ground it covers, with a little
	# skirt down at its outside edge so it never floats. Its collision is the same triangles.
	var rows := maxi(int(ceil((r_out - r_in) / 0.6)), 1)
	var pts: Array = []
	for i in RIM_SEGS:
		var a := i * TAU / RIM_SEGS
		var row: Array = []
		for k in rows + 1:
			var d := lerpf(r_in, r_out, float(k) / rows)
			var f := clampf((d - r_in) / 0.6, 0.0, RIM_ROWS - 0.001)
			var y := lerpf(float(heights[i][int(f)]), float(heights[i][int(f) + 1]), f - int(f)) + 0.04
			row.append(Vector3(cos(a) * d, y, sin(a) * d))
		pts.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var quad := func(a: Vector3, b: Vector3, cc: Vector3, d: Vector3, n: Vector3, solid: bool) -> void:
		for tri in [[a, b, cc], [a, cc, d]]:
			var v: Array = tri
			if (v[2] - v[0]).cross(v[1] - v[0]).dot(n) < 0.0:
				v = [v[0], v[2], v[1]]
			for q in v:
				st.set_normal(n)
				st.add_vertex(q)
				if solid:
					faces.append(q)
	for i in RIM_SEGS:
		var j := (i + 1) % RIM_SEGS
		for k in rows:
			quad.call(pts[i][k], pts[j][k], pts[j][k + 1], pts[i][k + 1], Vector3.UP, true)
		var o0: Vector3 = pts[i][rows]
		var o1: Vector3 = pts[j][rows]
		var out := Vector3(o0.x, 0, o0.z).normalized()
		quad.call(o0, o1, o1 + Vector3(0, -0.35, 0), o0 + Vector3(0, -0.35, 0), out, false)   # (only to look at)
	var mi := MeshInstance3D.new()
	mi.name = "Paving"
	mi.mesh = st.commit()
	mi.material_override = _mat(c)
	root.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)


func _box(parent: Node3D, body: StaticBody3D, size: Vector3, t: Transform3D, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.transform = t
	parent.add_child(mi)
	if body:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.transform = t
		body.add_child(cs)


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


# -----------------------------------------------------------------------------
# How each kind looks, from shapes: a glowing machine part, a gold watch gone a bit green, a bottle with a note
# -----------------------------------------------------------------------------
func model(kind: String) -> Node3D:
	var m := Node3D.new()
	m.name = "Model"
	var col: Color = KINDS[kind].colour
	match kind:
		"piece":
			var gear := _mesh(_cyl(0.28, 0.08), _mat(Color(0.75, 0.75, 0.85), 0.0))
			gear.rotation.x = PI * 0.5
			m.add_child(gear)
			for i in 8:
				var a := i * TAU / 8.0
				var tooth := _mesh(_cube(Vector3(0.1, 0.1, 0.08)), _mat(Color(0.75, 0.75, 0.85)))
				tooth.position = Vector3(cos(a) * 0.32, sin(a) * 0.32, 0)
				tooth.rotation.z = a
				m.add_child(tooth)
			var core := _mesh(_ball(0.12), _mat(col, 2.0))
			core.position.z = 0.05
			m.add_child(core)
		"watch":
			var case_ := _mesh(_cyl(0.24, 0.07), _mat(Color(0.75, 0.68, 0.38), 0.2))
			case_.rotation.x = PI * 0.5
			m.add_child(case_)
			var face := _mesh(_cyl(0.2, 0.02), _mat(Color(0.75, 0.95, 0.85), 0.3))
			face.rotation.x = PI * 0.5
			face.position.z = 0.04
			m.add_child(face)
			for h in [Vector2(0.0, 0.14), Vector2(0.1, 0.0)]:
				var hand := _mesh(_cube(Vector3(0.025 if h.x == 0.0 else h.x, 0.025 if h.y == 0.0 else h.y, 0.01)),
					_mat(Color(0.2, 0.2, 0.3)))
				hand.position = Vector3(h.x * 0.5, h.y * 0.5, 0.055)
				m.add_child(hand)
			var bow := _mesh(_cyl(0.05, 0.05), _mat(Color(0.75, 0.68, 0.38)))
			bow.position.y = 0.28
			m.add_child(bow)
		"bottle":
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.7, 0.95, 0.9, 0.45)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			var b := _mesh(_cyl(0.13, 0.36), glass)
			m.add_child(b)
			var neck := _mesh(_cyl(0.05, 0.14), glass)
			neck.position.y = 0.25
			m.add_child(neck)
			var wax := _mesh(_cyl(0.065, 0.06), _mat(Color(0.75, 0.55, 1.0), 0.6))
			wax.position.y = 0.34
			m.add_child(wax)
			var note := _mesh(_cyl(0.06, 0.26), _mat(Color(1.0, 0.95, 0.8), 0.3))
			m.add_child(note)
			m.rotation.z = 1.2                        # lying on its side on the bottom
	var halo := _mesh(_ball(0.55), null)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(col.r, col.g, col.b, 0.16)
	hm.emission_enabled = true
	hm.emission = col
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = hm
	halo.name = "Halo"
	var holder := Node3D.new()
	holder.add_child(m)
	holder.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.0
	light.omni_range = 3.5
	holder.add_child(light)
	holder.scale = Vector3.ONE * 1.6
	return holder


func _mesh(mesh: Mesh, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if m:
		mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	return c


func _cube(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


# -----------------------------------------------------------------------------
# Finding one (scripts/sunken_pickup.gd calls these)
# -----------------------------------------------------------------------------
func reached(pick: Node3D) -> bool:
	# She has to be swimming down there: floating on the top before Otto's taught her isn't close enough
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or not player.has_method("is_swimming") or not player.call("is_swimming"):
		return false
	if Dialogue.is_active():
		return false
	return (player.global_position + Vector3(0, 0.8, 0)).distance_to(pick.global_position) < REACH


func pick_up(id: String, at := Vector3.ZERO) -> void:
	var s := secret(id)
	if s.is_empty() or is_found(id):
		return
	Dialogue.set_flag("sunk_" + id)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("sparkle", 1.0, -6.0)
	Juice.rumble(0.3, 0.15)
	if is_instance_valid(_holder):
		Fx.burst(_holder, at, KINDS[s.kind].colour, 16, 0.07, 2.5, 1.0, 0.8)
	var lines := lines_for(s)
	if is_instance_valid(_reader):
		Dialogue.say(_reader, str(s.name), lines.map(func(l: String) -> String: return Settings.fill(l)), "sunk_" + id)
	found_secret.emit(id)
	Game.save_game()


func lines_for(s: Dictionary) -> Array:
	# What it says when you find it, and what's said when it finishes a set
	var lines: Array = []
	var n := found_of(s.kind)
	match s.kind:
		"piece":
			lines.append("(%s)" % s.about)
			lines.append("(A far-away voice:)")
			lines.append(s.echo)
			lines.append("(Show Dash! %d of 8)" % n)
		"watch":
			lines.append("(%s)" % s.about)
			lines.append(s.note)
			lines.append("(%d of 8 old watches)" % n)
			if n == 8:
				lines.append("(Eight watches from kids chosen long ago!)")
				Remnants.add(WATCH_REWARD, "watches of the first chosen")
				lines.append("(You got %s!)" % Remnants.words(WATCH_REWARD))
		"bottle":
			lines.append("(A note in a bottle, from the Seer:)")
			lines.append("\"%s\"" % s.note)
			lines.append("(%d of 8 Seer's Bottles.)" % n)
			if n == 8:
				lines.append("\"You found them all! I knew you would. The Seer.\"")
				Remnants.add(BOTTLE_REWARD, "the seer's bottles")
				lines.append("(You got %s!)" % Remnants.words(BOTTLE_REWARD))
	return lines


# -----------------------------------------------------------------------------
# Giving the pieces to Dash (dialogue/dash.json: "do": "Watches/Sunken.hand_in")
# -----------------------------------------------------------------------------
func hand_in() -> Array:
	var giving := to_give()
	if giving.is_empty():
		return []
	for s in giving:
		Dialogue.set_flag("sunk_given_" + str(s.id))
	var given := given_count()
	var lines: Array = []
	if given == 8 and not Dialogue.flags.has("sunk_pieces_done"):
		Dialogue.set_flag("sunk_pieces_done")
		lines.append_array([
			"Two experiments at once. Rex's and mine.",
			"It cracked the Shift. It was me too.",
			"Now I know how to fix it. With everyone!",
			"Thanks, {player}. These are for you."])
		Remnants.add(int(PIECE_REWARD.remnants), "pieces of that night")
		Game.add_sparkles(int(PIECE_REWARD.sparkles), "pieces of that night")
		lines.append("(You got %s and %d sparkles!)" % [Remnants.words(int(PIECE_REWARD.remnants)), int(PIECE_REWARD.sparkles)])
	else:
		lines.append("%d of 8! Look in deep water." % given)
	Audio.play("level_up", -4.0, 0.0)
	Game.save_game()
	return lines


func condition_ok(when: Dictionary) -> bool:
	# Dialogue "when" keys: "sunk_to_give" (pieces found and not given to Dash yet), "sunk_given" (at least N given)
	if when.has("sunk_to_give") and bool(when["sunk_to_give"]) != (not to_give().is_empty()):
		return false
	if when.has("sunk_given") and given_count() < int(when["sunk_given"]):
		return false
	return true


func fill() -> Dictionary:
	return {"pieces_given": str(given_count())}
