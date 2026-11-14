extends Node

# Rare fish for the Aquarium (Hayden, 14 Nov 2026: "an aquarium quest where you collect all the exotic fish species of
# different worlds; You need the swim ability"). Quest: quests/aquarium.json ("Rare Fish"), given by Otto on the
# Portal Plaza (scripts/portals.gd _talk_otto), or started by catching the first one.
#
# Every place with deep water (the same eight as the sunken secrets, scripts/sunken_secrets.gd: the Void's Wishing
# Well, Willow Pond on Earth, the flooded Tide Reef and the deep pools in Shard Isle, Rootmind, the Frozen Moment,
# Lanternmoor and Rhythm Springs) has one rare fish swimming slow circles down deep. Only a swimmer who can dive gets
# down to it (Otto's gift, scripts/swim.gd): paddling on top isn't close enough. It darts off when you come near, so it
# takes a little chase, and then it's caught: it goes off in a bubble to the Void's Aquarium (Hayden's interact rule
# is about cracks: touching a fish is the catch, like the sunken secrets).
#
# In the Aquarium (scenes/interiors/aquarium.tscn) each caught fish swims in its own wall tank, with its name. With all
# eight in, the quest's done. Found ones are Dialogue flags ("fish_<id>"), so nothing new in the save.
# Names and looks are my first drafts, for Hayden to change.
#
# It lives under the Watches autoload ("Watches/Fish"), like the sunken secrets.

const SWIM := preload("res://scripts/swim.gd")
const SUNKEN := preload("res://scripts/sunken_secrets.gd")
const AQUARIUM := "res://scenes/interiors/aquarium.tscn"
const START := "aquarium_start"
const FULL := "aquarium_full"

# Each fish: where (a sunken-secrets place), its middle (x, z), its name and look ("kind" picks its extra bit)
const FISH := [
	{"id": "wishfin", "place": "town", "name": "Wishfin", "body": Color(1.0, 0.8, 0.3), "fin": Color(0.7, 0.45, 1.0), "kind": "glow"},
	{"id": "pond_prince", "place": "earth", "at": Vector2(-85, 0), "name": "Pond Prince", "body": Color(1.0, 0.98, 0.95), "fin": Color(1.0, 0.35, 0.2), "kind": "whiskers"},
	{"id": "crystal_guppy", "place": "shard_isle", "name": "Crystal Guppy", "body": Color(0.55, 1.0, 0.95, 0.6), "fin": Color(0.85, 1.0, 1.0), "kind": "spikes"},
	{"id": "leafy_minnow", "place": "rootmind", "name": "Leafy Minnow", "body": Color(0.45, 0.85, 0.3), "fin": Color(1.0, 0.6, 0.85), "kind": "leaf"},
	{"id": "frostfin", "place": "frozen_moment", "name": "Frostfin", "body": Color(0.85, 0.95, 1.0), "fin": Color(0.5, 0.75, 1.0), "kind": "frost"},
	{"id": "glowbelly", "place": "lanternmoor", "name": "Glowbelly", "body": Color(0.25, 0.2, 0.4), "fin": Color(1.0, 0.85, 0.45), "kind": "lure"},
	{"id": "bopfish", "place": "rhythm_springs", "name": "Bopfish", "body": Color(1.0, 0.55, 0.15), "fin": Color(0.3, 0.8, 1.0), "kind": "stripes"},
	{"id": "rainbow_puffer", "place": "tide_reef", "at": Vector2(30, 10), "name": "Rainbow Puffer", "body": Color(1.0, 0.45, 0.6), "fin": Color(0.4, 1.0, 0.7), "kind": "puff"},
]

const LOOP_R := 1.4                  # the circle it swims
const SPEED := 0.55                  # radians a second, lazy
const DART := 2.2                    # ...and when you're near
const NOTICE := 3.2                  # it notices you this near
const REACH := 1.25                  # and it's caught this near (her middle)
const DEEP := 2.0                    # only in water at least this deep

signal caught_fish(id: String)

var _scene: Node
var _here := ""
var _check := 0.0
var _fish: Node3D                    # the one swimming here (if any)
var _t := 0.0
var _dart := 0.0


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_fish = null
		_here = ""
		if s:
			_place_in.call_deferred(s)
	if not is_instance_valid(_scene):
		return
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		if _here != "" and not is_instance_valid(_fish):
			_put_in()
	if is_instance_valid(_fish):
		_swim(delta)


# -----------------------------------------------------------------------------
# What's been caught
# -----------------------------------------------------------------------------
func fish(id: String) -> Dictionary:
	for f in FISH:
		if f.id == id:
			return f
	return {}


func is_caught(id: String) -> bool:
	return Dialogue.flags.has("fish_" + id)


func caught_count() -> int:
	return FISH.filter(func(f: Dictionary) -> bool: return is_caught(f.id)).size()


func fish_at(place: String) -> Dictionary:
	for f in FISH:
		if f.place == place:
			return f
	return {}


func spot_of(f: Dictionary) -> Vector2:
	if f.has("at"):
		return f.at
	return SUNKEN.POOLS[f.place].at


func scene_of(place: String) -> String:
	if SUNKEN.POOLS.has(place):
		return str(SUNKEN.POOLS[place].scene)
	return str(SUNKEN.NATURAL[place].scene)


# -----------------------------------------------------------------------------
# Putting one in
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.has_meta("preview"):
		return
	if s.scene_file_path == AQUARIUM:
		_fill_tanks(s)
		return
	for f in FISH:
		if scene_of(str(f.place)) == s.scene_file_path and not is_caught(f.id):
			_here = str(f.place)
	_check = 1.0                                  # (a moment, so the sunken pools are in first)


func _put_in() -> void:
	# Once there's deep water there (the Tide Reef's sea only comes in once it's mended)
	var f := fish_at(_here)
	if f.is_empty() or is_caught(f.id) or not is_instance_valid(_scene):
		_here = ""
		return
	# Its own spot, or (in natural water) the sunken secrets' spots there, whichever's deep enough first
	var tries: Array = [spot_of(f)]
	if SUNKEN.NATURAL.has(_here):
		tries.append_array((SUNKEN.NATURAL[_here].spots as Dictionary).values())
	var at := Vector2.ZERO
	var bed := 0.0
	var depth := -1.0
	for c in tries:
		var b := _ground(Vector3(c.x, 60.0, c.y))
		var w: Node = SWIM.water_at(get_tree(), Vector3(c.x, b, c.y))
		if w != null and float(w.get("water_y")) - b >= DEEP:
			at = c
			bed = b
			depth = float(w.get("water_y")) - b
			break
	if depth < 0.0:
		return
	var g := Node3D.new()
	g.name = "Rare Fish " + str(f.id)
	g.set_meta("id", f.id)
	g.set_meta("middle", Vector3(at.x, bed + clampf(depth * 0.4, 1.0, 1.6), at.y))
	var m := model(f)
	m.name = "Model"
	g.add_child(m)
	_scene.add_child(g)
	g.global_position = g.get_meta("middle")
	_fish = g
	_t = randf() * TAU


func _ground(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -120.0, 0))
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player:
		q.exclude = [player.get_rid()]
	var hit := (_scene as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else 0.0


func _swim(delta: float) -> void:
	# Slow circles, a little up and down; it darts faster when she's near. Close enough while diving: caught.
	var mid: Vector3 = _fish.get_meta("middle")
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var near := 99.0
	if player:
		near = (player.global_position + Vector3(0, 0.8, 0)).distance_to(_fish.global_position)
	_dart = move_toward(_dart, 1.0 if near < NOTICE else 0.0, delta * 2.0)
	_t += delta * lerpf(SPEED, DART, _dart)
	var prev := _fish.global_position
	var r := LOOP_R * (1.0 + 0.25 * sin(_t * 0.7))
	_fish.global_position = mid + Vector3(cos(_t) * r, sin(_t * 1.3) * 0.25, sin(_t) * r)
	var dir := _fish.global_position - prev
	if dir.length() > 0.0001:
		_fish.look_at(_fish.global_position + dir, Vector3.UP)
	var m := _fish.get_node_or_null("Model") as Node3D
	if m:
		var tail := m.get_node_or_null("Tail") as Node3D
		if tail:
			tail.rotation.y = sin(_t * lerpf(6.0, 14.0, _dart)) * 0.5
		if m.has_meta("puff"):                   # the puffer puffs up when she's close
			m.scale = Vector3.ONE * lerpf(1.0, 1.6, _dart)
	if near < REACH and _can_catch(player):
		catch(str(_fish.get_meta("id")))


func _can_catch(player: Node3D) -> bool:
	# Down there swimming, not paddling on top (the dive is Otto's gift), and not mid-chat
	if player == null or not player.has_method("is_swimming") or not player.call("is_swimming"):
		return false
	var swim = player.get("swim")
	if swim == null or not bool(swim.get("under")):
		return false
	return not Dialogue.is_active()


func catch(id: String) -> void:
	var f := fish(id)
	if f.is_empty() or is_caught(id):
		return
	Dialogue.set_flag("fish_" + id)
	if not Dialogue.flags.has(START):
		Dialogue.set_flag(START)                  # (finding one yourself starts the quest too)
	var at := _fish.global_position if is_instance_valid(_fish) else Vector3.ZERO
	if is_instance_valid(_fish):
		_fish.name = "Caught Fish"
		_bubble_away(_fish)
	_fish = null
	_here = ""
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("sparkle", 1.0, -6.0)
	Juice.rumble(0.3, 0.15)
	if is_instance_valid(_scene):
		Fx.burst(_scene, at, f.fin, 18, 0.07, 2.5, 1.0, 0.8)
	Game.message("%s caught! %d of %d" % [f.name, caught_count(), FISH.size()])
	caught_fish.emit(id)
	Game.save_game()


func _bubble_away(g: Node3D) -> void:
	# Off to the Aquarium in a bubble: up and away, then gone
	var bubble := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	bubble.mesh = s
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.75, 0.95, 1.0, 0.3)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.emission_enabled = true
	bm.emission = Color(0.5, 0.85, 1.0) * 0.4
	bm.rim_enabled = true
	bubble.material_override = bm
	g.add_child(bubble)
	var tw := g.create_tween()
	tw.tween_property(g, "global_position", g.global_position + Vector3(0, 6.0, 0), 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(g, "scale", Vector3.ONE * 0.2, 1.4).set_delay(0.6)
	tw.tween_callback(g.queue_free)


# -----------------------------------------------------------------------------
# In the Aquarium
# -----------------------------------------------------------------------------
func _fill_tanks(s: Node) -> void:
	# Each caught fish in its own wall tank ("Tank 1".."Tank 8": tools/build_interiors.gd), with its name over it
	for i in FISH.size():
		var f: Dictionary = FISH[i]
		var tank := s.find_child("Tank %d" % (i + 1), true, false) as Node3D
		if tank == null:
			continue
		var name_tag := Label3D.new()
		name_tag.name = "Rare Fish Name"
		name_tag.font_size = 48
		name_tag.pixel_size = 0.008
		name_tag.outline_size = 10
		name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		name_tag.position = Vector3(0, 3.5, 0)
		tank.add_child(name_tag)
		if not is_caught(f.id):
			name_tag.text = "?"
			name_tag.modulate = Color(0.75, 0.85, 1.0, 0.7)
			continue
		name_tag.text = str(f.name)
		name_tag.modulate = (f.fin as Color).lightened(0.3)
		var holder := Node3D.new()
		holder.name = "Rare Fish"
		holder.set_script(load("res://scripts/fish_school.gd"))
		holder.set("half_size", Vector3(0.25, 0.5, 1.0))
		holder.position = Vector3(0, 1.7, 0)
		var m := model(f, 0.75)
		m.rotation.y = PI                         # (fish_school turns them by their +z: face that way)
		var pivot := Node3D.new()
		pivot.add_child(m)
		holder.add_child(pivot)
		tank.add_child(holder)                    # (after its fish: fish_school counts them as it's added)
	if caught_count() == FISH.size() and not Dialogue.flags.has(FULL):
		var t := get_tree().create_timer(1.2)
		t.timeout.connect(func() -> void:
			if get_tree().current_scene == s and not Dialogue.flags.has(FULL):
				Dialogue.set_flag(FULL)
				Audio.play("level_up", -4.0, 0.0)
				Juice.blip("sparkle", 1.0, -4.0)
				Game.message("Every tank is full!")
				Game.save_game())


# -----------------------------------------------------------------------------
# The fish
# -----------------------------------------------------------------------------
func model(f: Dictionary, size := 1.0) -> Node3D:
	# A round little fish facing -z: body, tail, fins, eyes, and its own extra bit
	var g := Node3D.new()
	var body_c: Color = f.body
	var fin_c: Color = f.fin
	var bm := _mat(body_c, 0.35 if f.kind == "glow" else 0.12)
	if body_c.a < 1.0:
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fm := _mat(fin_c, 0.3)
	var body := _mesh(_ball(0.3 * size), bm, Vector3.ZERO, g)
	body.name = "Body"
	body.scale = Vector3(0.75, 0.9, 1.35)
	# The tail: an upright fan behind, its point at the body (it swishes from the "Tail" pivot)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0, 0.36 * size)
	g.add_child(tail)
	var tp := PrismMesh.new()
	tp.size = Vector3(0.42, 0.3, 0.04) * size
	var t := _mesh(tp, fm, Vector3(0, 0, 0.15 * size), tail)
	t.basis = Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))   # (fan upright, point forwards)
	# The fin on top, upright along the back
	var dp := PrismMesh.new()
	dp.size = Vector3(0.3, 0.18, 0.03) * size
	var top := _mesh(dp, fm, Vector3(0, 0.33, 0.04) * size, g)
	top.basis = Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
	for side in [-1.0, 1.0]:                       # little side fins and big eyes
		var fin := _mesh(_ball(0.1 * size), fm, Vector3(side * 0.23, -0.06, -0.02) * size, g)
		fin.scale = Vector3(1.0, 0.18, 0.6)
		fin.rotation.z = side * -0.5
		_mesh(_ball(0.06 * size), _mat(Color(1, 1, 1)), Vector3(side * 0.15, 0.08, -0.3) * size, g)
		_mesh(_ball(0.033 * size), _mat(Color(0.05, 0.05, 0.1)), Vector3(side * 0.18, 0.09, -0.33) * size, g)
	match str(f.kind):
		"glow":
			var l := OmniLight3D.new()
			l.light_color = body_c
			l.light_energy = 0.8
			l.omni_range = 2.5
			g.add_child(l)
		"whiskers":
			for side in [-1.0, 1.0]:
				var w := _mesh(_box(Vector3(0.02, 0.02, 0.22) * size), fm, Vector3(side * 0.08, -0.06, -0.48) * size, g)
				w.rotation.y = side * 0.5
			for k in 3:                             # koi patches
				_mesh(_ball(0.1 * size), fm, Vector3(0.12 * (k - 1), 0.17, -0.05 + 0.12 * k) * size, g)
		"spikes":
			for k in 4:
				var sp := _mesh(_cone(0.05 * size, 0.2 * size), _mat(fin_c, 0.6), Vector3(0, 0.25, -0.15 + k * 0.1) * size, g)
				sp.rotation.x = -0.4
		"leaf":
			for side in [-1.0, 1.0]:
				var leaf := _mesh(_ball(0.14 * size), _mat(Color(0.3, 0.7, 0.25)), Vector3(side * 0.2, 0.18, 0.05) * size, g)
				leaf.scale = Vector3(0.2, 0.5, 1.0)
				leaf.rotation.z = side * 0.6
		"frost":
			for k in 5:
				var a := k * TAU / 5.0
				_mesh(_ball(0.03 * size), _mat(Color(1, 1, 1), 1.0), Vector3(cos(a) * 0.2, sin(a) * 0.24, 0.05) * size, g)
		"lure":
			var stalk := _mesh(_box(Vector3(0.02, 0.22, 0.02) * size), fm, Vector3(0, 0.33, -0.25) * size, g)
			stalk.rotation.x = -0.6
			_mesh(_ball(0.07 * size), _mat(fin_c, 2.0), Vector3(0, 0.42, -0.38) * size, g)
			var l := OmniLight3D.new()
			l.light_color = fin_c
			l.light_energy = 0.9
			l.omni_range = 2.5
			l.position = Vector3(0, 0.42, -0.38) * size
			g.add_child(l)
		"stripes":
			for k in 3:
				var st := _mesh(_cyl(0.215 * size, 0.04 * size), _mat(Color(1, 1, 1)), Vector3(0, 0, -0.18 + k * 0.17) * size, g)
				st.rotation.x = PI / 2
				st.scale = Vector3(1.05 - absf(k - 1) * 0.12, 1.0, 1.25 - absf(k - 1) * 0.15)
		"puff":
			g.set_meta("puff", true)
			for k in 8:
				var a := k * TAU / 8.0
				var sp := _mesh(_cone(0.03 * size, 0.1 * size), _mat(fin_c), Vector3(cos(a) * 0.24, sin(a) * 0.28, 0) * size, g)
				sp.rotation.z = a - PI / 2
	return g


func _mesh(m: Mesh, mat: Material, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	return m


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 14
	s.rings = 8
	return s


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 16
	return c
