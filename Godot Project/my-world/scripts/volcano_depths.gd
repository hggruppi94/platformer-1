extends Node3D

# The Ember Tunnel: a secret way into Rhythm Springs' old volcano, and Old Ember asleep in the magma chamber under its
# peak (Hayden, 17 Nov 2026: "I'd love to have a secret volcano tunnel with an optional boss").
#
# Once Rhythm Springs is mended (the Off-Beat's back in time), a crack in a heap of dark lava rock at the peak's foot,
# up on the North Highlands' upper tier (ENTRANCE), starts to glow. Nothing says so and it isn't on the map: it's
# there to be found. Squeeze in and you're in the Ember Hall, under the tier. The tunnel winds down from there in two
# long switchbacks under the upper tier (ROUTE), past glowing magma veins, basalt columns, a lava stream running
# along the wall and steam vents that puff on the island's beat (stand on one and it bounces you up), and comes out in
# the Magma Chamber right under the peak (CHAMBER), with a ring of lava round its edge.
#
# All of it is really inside the volcano: the cave is carved out of the ground (scripts/cave_kit.gd) with solid rock
# all round it (tools/test_volcano.gd checks every bit of air is under the island's ground). It's built when the world
# loads, like the Glimmer Caves, so nothing in rhythm_springs.tscn changed.
#
# Old Ember (scripts/old_ember.gd) sleeps curled up in the middle of the chamber. Calm it and a column of steam opens
# in the chamber's roof: ride it up and you come out on the Crater Lookout, a ledge on the crater's rim looking out over
# the whole island. A way down from there takes you back to the crack. Old Ember's back asleep on the next visit (its
# reward is only the first time; the Ember Chest pays once a visit).
#
# No class_name on purpose (see scripts/use_spot.gd): load it with preload. scripts/rhythm_springs.gd calls place().

const L := preload("res://scripts/rhythm_land.gd")
const KIT := preload("res://scripts/cave_kit.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")

const NODE := "Volcano Depths"
const TUBE := 2.4                              # the tunnel's radius
# Where things are, as [angle round the island (degrees), metres out from its middle, height]
const ENTRANCE := [257.0, 112.0]               # the crack, on the upper tier at the peak's foot (outside)
const HALL := [261.0, 105.0, 13.6]             # the Ember Hall's floor, just under the tier
# The tunnel's middle line, from the Ember Hall down to the chamber: along the outer side of the tier, round a bend,
# and back along its inner side, sloping down all the way
const ROUTE := [
	[261.0, 105.0, 15.0], [265.0, 105.5, 14.3], [268.5, 103.5, 13.5], [270.0, 99.5, 12.6], [268.0, 96.5, 11.8],
	[264.0, 95.8, 10.8], [259.5, 96.0, 9.8], [255.5, 97.2, 8.8], [252.5, 99.5, 8.0],
]
const CHAMBER := [248.0, 103.0]                 # under the peak's middle (the peak is at 248 degrees, 101 m out)
const CHAMBER_FLOOR := 6.4
const CHAMBER_R := 11.5                         # the room's size across (its floor's a little narrower)
const ARENA_R := 8.6                            # inside this the floor's safe; past it, the lava ring
const LAVA_R := 9.2                             # step past this and the lava bumps you back in
const STONES_R := 6.2                           # the three Geyser Stones stand this far out
const VENTS := [[266.0, 105.0], [264.0, 96.0], [257.5, 96.4]]   # steam vents in the tunnel's floor (angle, metres out)
const STREAM := [[262.0, 95.8], [256.5, 96.8]]  # the lava stream along the inner wall, between these
const VENT_EVERY := 4                           # beats between puffs
const VENT_R := 1.0
const VENT_BOUNCE := 11.0
const TREASURE := 25
const CRACK_FROM := 2.4                         # the three lava cracks in the arena floor run out from here...
const CRACK_TO := 7.6                           # ...to here, between the Geyser Stones
const CRACK_HIT := 0.75                         # this close to a flaring crack (and on the floor) and it bumps you
const FLARE_TIME := 0.55
const MARKS := ["entrance", "hall", "chamber", "lift", "chest"]

var world: Node3D
var boss: CharacterBody3D
var field := {}
var player: CharacterBody3D
var _mats := {}
var _vents: Array[Node3D] = []
var _last_beat := -1
var _lava_told := 0.0
var _crack: Node3D
var _lift: Node3D
var _lookout: Node3D
var _chest: Node3D
var _chest_open := false
var _going := false
var _t := 0.0
var cracks: Array[Node3D] = []
var _crack_beat := -1


static func place(w: Node3D) -> Node3D:
	if w.get_node_or_null(NODE) != null:
		return w.get_node(NODE)
	var v := Node3D.new()
	v.name = NODE
	v.set_script(load("res://scripts/volcano_depths.gd"))
	v.set("world", w)
	w.add_child(v)
	return v


static func pt(a: Array, y := 0.0) -> Vector3:
	return L.at(float(a[0]), float(a[1]), float(a[2]) if a.size() > 2 else y)


static func mark(id: String) -> Vector3:
	# Where each thing is (on the floor it stands on, near enough: the cave's own floor is a little bumpy)
	var c := pt(CHAMBER, CHAMBER_FLOOR)
	match id:
		"entrance":
			var e := pt(ENTRANCE)
			return Vector3(e.x, L.height(e.x, e.z), e.z)
		"hall":
			return pt(HALL)
		"chamber":
			return c
		"lift":
			return c + _out_dir() * (ARENA_R - 1.6)
		"chest":
			return c - _out_dir().rotated(Vector3.UP, 0.9) * (ARENA_R - 1.8)
	return Vector3.ZERO


static func _out_dir() -> Vector3:
	# From the chamber's middle towards the sea (away from the tunnel's mouth)
	var c := pt(CHAMBER)
	return Vector3(c.x, 0, c.z).normalized()


static func open() -> bool:
	return Portals.is_cleared("rhythm_springs")


# The cave's shape ------------------------------------------------------------------------------------------------
static func shapes() -> Array:
	var route: Array = []
	for p in ROUTE:
		route.append(pt(p))
	var c := pt(CHAMBER)
	var hall := pt(HALL)
	return [
		{"kind": "room", "at": hall + Vector3(0, 1.6, 0), "rx": 4.6, "ry": 3.2, "rz": 4.6, "floor": hall.y},
		{"kind": "tunnel", "points": route, "r": TUBE, "floor": 0.55},
		{"kind": "room", "at": Vector3(c.x, CHAMBER_FLOOR + 3.2, c.z), "rx": CHAMBER_R, "ry": 9.0, "rz": CHAMBER_R,
			"floor": CHAMBER_FLOOR},
	]


static func cave_opts() -> Dictionary:
	return {"cell": 0.9, "blend": 1.4, "noise": 0.3, "seed": 248, "name": "Volcano Cave",
		"rock": Color(0.24, 0.2, 0.24), "floor_colour": Color(0.3, 0.24, 0.24)}


# -----------------------------------------------------------------------------------------------------------------
func _ready() -> void:
	if world == null:
		world = get_parent() as Node3D
	var built: Dictionary = KIT.build(self, shapes(), cave_opts())
	field = built.field
	KIT.shade_from_sun(world)
	_dress_tunnel()
	_dress_chamber()
	_make_crack()
	_make_lookout()
	var c := mark("chamber")
	boss = (load("res://scripts/old_ember.gd") as GDScript).new() as CharacterBody3D
	boss.name = "Old Ember"
	add_child(boss)
	boss.global_position = c
	boss.set("home", c)
	boss.set("depths", self)
	boss.call("make_stones", self, c, STONES_R)
	_chest = _make_chest(mark("chest"))
	_lift = _make_lift(mark("lift"))
	_lift.visible = false
	# (25 Nov 2026) The tunnel's and chamber's stone wears the baked rock (the cave itself is done by the kit); the
	# lava, cracks, vents and glows stay as they are
	load("res://scripts/detail_props.gd").dress_place(self, [["Lava Rock", "rock"], ["Basalt", "rock"],
		["Vent Rim", "rock"], ["Lookout Rock", "rock"], ["Chest Basalt", "rock"]])


func _physics_process(delta: float) -> void:
	_t += delta
	_lava_told = maxf(_lava_told - delta, 0.0)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		return
	var glowing := open()
	if _crack:
		_crack.get_node("Glow").visible = glowing
	_vents_step()
	_cracks_step()
	_lava_step()
	var calm := boss != null and bool(boss.get("defeated"))
	if _lift.visible != calm:
		_lift.visible = calm
		if calm:
			Fx.burst(self, _lift.global_position + Vector3(0, 2.0, 0), Color(1, 1, 1), 24, 0.12, 4.0, 3.0)


# Going between places: a quick fade, then you're there --------------------------------------------------------------
func go_to(at: Vector3, face: Vector3, words := "") -> void:
	if _going or player == null:
		return
	_going = true
	Game.hold_controls(&"volcano", true)
	var layer := CanvasLayer.new()
	layer.layer = 90
	var veil := ColorRect.new()
	veil.color = Color(0.12, 0.04, 0.02, 0.0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(veil)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		player.global_position = at + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		face.y = 0
		if face.length() > 0.01:
			var model := player.get_node_or_null("Visual") as Node3D
			if model:
				model.rotation.y = atan2(face.x, face.z)
			var arm := player.get_node_or_null("SpringArm3D") as Node3D
			if arm:
				arm.rotation.y = atan2(-face.x, -face.z)
		if words != "":
			Game.message(words))
	tw.tween_interval(0.15)
	tw.tween_property(veil, "color:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		layer.queue_free()
		Game.hold_controls(&"volcano", false)
		_going = false)


func outside() -> Vector3:
	# Just in front of the crack, on the tier
	var e := mark("entrance")
	var f := _crack_facing()
	var at := e + f * 3.2
	return Vector3(at.x, L.height(at.x, at.z), at.z)


func _crack_facing() -> Vector3:
	# The crack's mouth looks out over open, flat tier: of sixteen ways round, the one nearest "away from the peak"
	# whose ground stays level for 8 m (the tier's edge is a cliff close by on the sea side)
	var pk: Array = L.PEAKS[0]
	var top := L.at(float(pk[0]), float(pk[1]))
	var e := pt(ENTRANCE)
	var away := Vector3(e.x - top.x, 0, e.z - top.z).normalized()
	var h0 := L.height(e.x, e.z)
	var best := away
	var best_dot := -INF
	for k in 16:
		var a := TAU * k / 16.0
		var d := Vector3(sin(a), 0, cos(a))
		var level := true
		for r in [2.0, 4.0, 6.0, 8.0]:
			var q: Vector3 = e + d * r
			if absf(L.height(q.x, q.z) - h0) > 1.0:
				level = false
		if level and d.dot(away) > best_dot:
			best_dot = d.dot(away)
			best = d
	return best


func squeeze_in() -> void:
	var hall := mark("hall")
	var into := pt(ROUTE[1]) - hall
	go_to(_floor_at(hall), into, "You squeeze through the crack... It's warm in here!")


func squeeze_out() -> void:
	go_to(outside(), _crack_facing())


func ride_steam() -> void:
	var top: Vector3 = _lookout.get_meta("stand")
	go_to(top, _lookout.get_meta("view"), "Whoosh! The steam carries you up to the crater's rim.")


func way_down() -> void:
	go_to(outside(), _crack_facing(), "You slide all the way back down to the crack.")


func _floor_at(p: Vector3) -> Vector3:
	return KIT.floor_below(field, p + Vector3(0, 1.2, 0))


# The way in: a heap of lava rock with a crack in it --------------------------------------------------------------
func _make_crack() -> void:
	var e := mark("entrance")
	var f := _crack_facing()
	var g := Node3D.new()
	g.name = "Ember Crack"
	add_child(g)
	g.global_position = e
	g.rotation.y = atan2(f.x, f.z)
	var rock := _mat("Lava Rock", Color(0.2, 0.17, 0.2), 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 257
	# Boulders heaped round the back and sides (solid), the crack between the two biggest
	var body := StaticBody3D.new()
	body.name = "Ember Crack Rocks"
	g.add_child(body)
	for b in [[Vector3(-1.5, 1.4, -0.6), 1.7], [Vector3(1.5, 1.3, -0.5), 1.6], [Vector3(0, 2.4, -1.3), 1.5],
			[Vector3(-2.7, 0.7, 0.2), 0.95], [Vector3(2.6, 0.6, 0.3), 0.9], [Vector3(0.2, 0.5, -2.4), 1.2]]:
		var at: Vector3 = b[0]
		var r: float = b[1]
		var m := _ball_mesh(r)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.material_override = rock
		mi.position = at
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		mi.scale = Vector3(1.0, 0.8 + rng.randf() * 0.3, 1.0)
		g.add_child(mi)
		var cs := CollisionShape3D.new()
		var ss := SphereShape3D.new()
		ss.radius = r * 0.9
		cs.shape = ss
		cs.position = at
		body.add_child(cs)
	# The crack: a dark slit, and once the volcano's open, a warm glow in it with steam curling out
	var slit := BoxMesh.new()
	slit.size = Vector3(0.7, 2.2, 0.3)
	var s := MeshInstance3D.new()
	s.mesh = slit
	s.material_override = _mat("Crack Dark", Color(0.05, 0.03, 0.04), 1.0)
	s.position = Vector3(0, 1.1, 0.35)
	g.add_child(s)
	var glow := Node3D.new()
	glow.name = "Glow"
	g.add_child(glow)
	var gm := BoxMesh.new()
	gm.size = Vector3(0.36, 1.8, 0.1)
	var gi := MeshInstance3D.new()
	gi.mesh = gm
	gi.material_override = _mat("Crack Glow", Color(1.0, 0.45, 0.12), 0.5, 3.0)
	gi.position = Vector3(0, 1.05, 0.48)
	glow.add_child(gi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 1.4
	l.omni_range = 4.0
	l.position = Vector3(0, 1.2, 1.0)
	glow.add_child(l)
	for k in 3:
		var puff := MeshInstance3D.new()
		puff.mesh = _ball_mesh(0.35 + k * 0.12)
		puff.material_override = _mat("Crack Steam", Color(1, 1, 1, 0.22), 1.0)
		puff.position = Vector3(0.1 * k, 2.4 + k * 0.6, 0.4)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.add_child(puff)
	glow.visible = open()
	# A little sign, only readable up close
	var sign := Label3D.new()
	sign.name = "Crack Sign"
	sign.text = "Warm in here..."
	sign.font_size = 40
	sign.pixel_size = 0.008
	sign.modulate = Color(1.0, 0.75, 0.45)
	sign.outline_size = 10
	sign.outline_modulate = Color(0.1, 0.05, 0.05)
	sign.position = Vector3(1.2, 0.5, 1.15)
	sign.rotation.x = -0.4
	sign.visibility_range_end = 10.0
	g.add_child(sign)
	var spot := USE_SPOT.make(Vector3(0, 0, 1.8), func() -> String: return "squeeze into the crack" if open() else "",
		squeeze_in, 2.0, 2.6)
	spot.name = "Crack Spot"
	g.add_child(spot)
	_crack = g


# The tunnel ---------------------------------------------------------------------------------------------------------
func _dress_tunnel() -> void:
	var hall := mark("hall")
	var t := Node3D.new()
	t.name = "Ember Tunnel"
	add_child(t)
	# The way back out, at the back of the Ember Hall: a sliver of daylight
	var back := hall - (pt(ROUTE[1]) - hall).normalized() * 3.0
	back = _floor_at(back)
	var out := Node3D.new()
	out.name = "Way Out"
	t.add_child(out)
	out.global_position = back
	var day := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.5, 2.0, 0.2)
	day.mesh = dm
	day.material_override = _mat("Daylight", Color(1.0, 0.95, 0.8), 0.5, 2.0)
	day.position.y = 1.2
	out.add_child(day)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "squeeze back out", squeeze_out, 2.2, 2.8)
	spot.name = "Out Spot"
	out.add_child(spot)
	# Warm lights all the way down, magma veins glowing in the walls, basalt columns and obsidian shards
	var route: Array = [hall]
	for p in ROUTE:
		route.append(pt(p))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var veins := _mat("Magma Vein", Color(1.0, 0.42, 0.1), 0.6, 2.6)
	var basalt := _mat("Basalt", Color(0.18, 0.16, 0.19), 0.85)
	for i in route.size():
		var p: Vector3 = route[i]
		if i % 2 == 0:
			_lamp(t, p + Vector3(0, 1.2, 0), Color(1.0, 0.5, 0.22), 1.6, 9.0)
		if i == 0 or i == route.size() - 1:
			continue
		var along: Vector3 = (route[mini(i + 1, route.size() - 1)] - route[i - 1])
		along.y = 0
		along = along.normalized()
		var side := along.cross(Vector3.UP)
		var s := 1.0 if i % 2 == 0 else -1.0
		# A cluster of basalt columns against the wall
		var foot := _floor_at(p + side * s * 1.4)
		for k in 4:
			var col := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.radial_segments = 6
			cm.top_radius = 0.22
			cm.bottom_radius = 0.24
			cm.height = 0.6 + rng.randf() * 1.0
			col.mesh = cm
			col.material_override = basalt
			col.position = foot + side * s * (0.25 * k) + along * (rng.randf() - 0.5) * 0.8 + Vector3(0, cm.height * 0.5, 0)
			t.add_child(col)
		# A glowing vein running up the other wall
		var vein := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.12, 2.2, 0.12)
		vein.mesh = vm
		vein.material_override = veins
		var vfoot := _floor_at(p - side * s * (TUBE * 0.78))
		vein.position = vfoot + Vector3(0, 1.3, 0)
		vein.rotation = Vector3(0, atan2(along.x, along.z), 0.4 * s)
		t.add_child(vein)
		KIT.crystals(t, _floor_at(p - side * s * 1.5), Color(0.25, 0.12, 0.3), 4, i, 0.7)
	# The steam vents
	for v in VENTS:
		_vents.append(_vent(t, _floor_at(Vector3(pt(v).x, _nearest_on_route(pt(v, 12.0)).y, pt(v).z))))
	# The lava stream along the inner wall, and a little lava fall feeding it
	var a := _floor_at(pt(STREAM[0], 12.0))
	var b := _floor_at(pt(STREAM[1], 12.0))
	var dir := (b - a)
	dir.y = 0
	var side_in := Vector3(-(a + b).x, 0, -(a + b).z).normalized()
	var stream := Node3D.new()
	stream.name = "Lava Stream"
	t.add_child(stream)
	stream.set_meta("a", a + side_in * 1.25)
	stream.set_meta("b", b + side_in * 1.25)
	var n := int(dir.length() / 1.0)
	for k in n + 1:
		var q := a.lerp(b, float(k) / n) + side_in * 1.25
		q = _floor_at(q)
		var lm := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.75, 0.08, 1.1)
		lm.mesh = pm
		lm.material_override = _mat("Lava", Color(1.0, 0.45, 0.08), 0.4, 3.0)
		lm.position = q + Vector3(0, 0.05, 0)
		lm.rotation.y = atan2(dir.x, dir.z)
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stream.add_child(lm)
	var fall_at := _floor_at(a + side_in * 1.25)
	var fm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var roof := KIT.ceiling_above(field, fall_at + Vector3(0, 0.5, 0))
	bm.size = Vector3(0.5, maxf(roof.y - fall_at.y, 1.0), 0.18)
	fm.mesh = bm
	fm.material_override = _mat("Lava Fall", Color(1.0, 0.55, 0.15), 0.4, 3.4)
	fm.position = fall_at + Vector3(0, bm.size.y * 0.5, 0)
	fm.rotation.y = atan2(side_in.x, side_in.z)
	stream.add_child(fm)
	_lamp(stream, fall_at + Vector3(0, 1.0, 0), Color(1.0, 0.45, 0.15), 1.8, 7.0)
	KIT.in_the_dark(t)
	for l in t.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).light_cull_mask = 0xFFFFF


func _vent(parent: Node3D, at: Vector3) -> Node3D:
	var v := Node3D.new()
	v.name = "Steam Vent"
	parent.add_child(v)
	v.global_position = at
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.45
	tm.outer_radius = 0.75
	ring.mesh = tm
	ring.material_override = _mat("Vent Rim", Color(0.22, 0.18, 0.2), 0.9)
	ring.position.y = 0.05
	v.add_child(ring)
	var hole := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.45
	hm.bottom_radius = 0.45
	hm.height = 0.04
	hole.mesh = hm
	hole.name = "Hole"
	hole.material_override = _mat("Vent Glow", Color(1.0, 0.5, 0.2), 0.6, 1.0).duplicate()
	hole.position.y = 0.04
	v.add_child(hole)
	var puff := MeshInstance3D.new()
	puff.name = "Puff"
	var pc := CylinderMesh.new()
	pc.top_radius = 0.9
	pc.bottom_radius = 0.35
	pc.height = 3.0
	puff.mesh = pc
	puff.material_override = _mat("Vent Steam", Color(1, 1, 1, 0.35), 1.0)
	puff.position.y = 1.5
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.visible = false
	v.add_child(puff)
	v.set_meta("puffs", 0)
	return v


func _vents_step() -> void:
	# On the island's beat: every VENT_EVERY beats each vent glows a beat, then puffs. Standing on one bounces you up.
	var beat := int(world.get("beat_n")) if world and world.get("beat_n") != null else int(_t / 0.7)
	if beat == _last_beat:
		return
	_last_beat = beat
	for i in _vents.size():
		var v := _vents[i]
		var k := (beat + i) % VENT_EVERY
		var hole := v.get_node("Hole") as MeshInstance3D
		(hole.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if k == VENT_EVERY - 1 else 1.0
		if k == 0:
			puff(v)


func puff(v: Node3D) -> void:
	v.set_meta("puffs", int(v.get_meta("puffs", 0)) + 1)
	var p := v.get_node("Puff") as MeshInstance3D
	p.visible = true
	p.scale = Vector3(0.4, 0.2, 0.4)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector3.ONE, 0.18)
	tw.tween_interval(0.25)
	tw.tween_callback(func() -> void: p.visible = false)
	if player and Vector2(player.global_position.x - v.global_position.x, player.global_position.z - v.global_position.z).length() < VENT_R \
			and player.global_position.y < v.global_position.y + 2.2:
		player.call("bounce", VENT_BOUNCE)
		Juice.blip("whoosh", 1.3, -6.0)


# The chamber ----------------------------------------------------------------------------------------------------------
func _dress_chamber() -> void:
	var c := mark("chamber")
	var ch := Node3D.new()
	ch.name = "Magma Chamber"
	add_child(ch)
	# The lava ring round the edge: a glowing band just inside the walls, with lights in it
	var lava := _mat("Lava", Color(1.0, 0.45, 0.08), 0.4, 3.0)
	for k in 28:
		var a := TAU * k / 28.0
		var mouth := pt(ROUTE[ROUTE.size() - 1]) - c
		if absf(wrapf(a - atan2(mouth.x, mouth.z), -PI, PI)) < 0.32:
			continue                                  # (the way in crosses it on a rock causeway)
		var dir := Vector3(sin(a), 0, cos(a))
		var at := _floor_at(c + dir * (LAVA_R + 0.7))
		var lm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.4, 0.08, 1.6)
		lm.mesh = bm
		lm.material_override = lava
		lm.position = at + Vector3(0, 0.05, 0)
		lm.rotation.y = a + PI / 2.0
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ch.add_child(lm)
		if k % 4 == 0:
			_lamp(ch, at + Vector3(0, 1.4, 0), Color(1.0, 0.45, 0.15), 1.5, 8.0)
	# A big warm light under the roof, and the vent in the roof the steam goes up when Old Ember's calm
	_lamp(ch, c + Vector3(0, 7.5, 0), Color(1.0, 0.55, 0.3), 1.2, 18.0)
	var roof := KIT.ceiling_above(field, c + Vector3(0, 2.0, 0))
	var vent := MeshInstance3D.new()
	var vm := CylinderMesh.new()
	vm.top_radius = 1.4
	vm.bottom_radius = 1.0
	vm.height = 0.3
	vent.mesh = vm
	vent.name = "Roof Vent"
	vent.material_override = _mat("Roof Vent", Color(1.0, 0.7, 0.4), 0.5, 1.6)
	vent.position = roof + Vector3(0, -0.1, 0)
	ch.add_child(vent)
	# Obsidian round the walls and basalt columns standing about
	var rng := RandomNumberGenerator.new()
	rng.seed = 248
	var basalt := _mat("Basalt", Color(0.18, 0.16, 0.19), 0.85)
	for k in 9:
		var a := TAU * (k + 0.5) / 9.0
		var at := _floor_at(c + Vector3(sin(a), 0, cos(a)) * (ARENA_R - 0.4))
		KIT.crystals(ch, at, Color(0.28, 0.12, 0.32), 3, 40 + k, 0.9)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var at := _floor_at(c + Vector3(sin(a), 0, cos(a)) * (CHAMBER_R - 1.0))
		var col := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.radial_segments = 6
		cm.top_radius = 0.5
		cm.bottom_radius = 0.6
		cm.height = 3.0 + rng.randf() * 2.0
		col.mesh = cm
		col.material_override = basalt
		col.position = at + Vector3(0, cm.height * 0.5 - 0.5, 0)
		ch.add_child(col)
	_make_cracks(ch, c)
	KIT.in_the_dark(ch)


# Lava cracks: three zigzag cracks across the arena floor between the Geyser Stones. While Old Ember's awake they take
# turns on the island's beat: a crack glows bright for a beat (the warning), then flares up in a sheet of fire for a
# moment. Jump it or step off it. Asleep or calm, they only simmer.
func _make_cracks(parent: Node3D, c: Vector3) -> void:
	for k in 3:
		var a := TAU * k / 3.0
		var dir := Vector3(sin(a), 0, cos(a))
		var side := dir.cross(Vector3.UP)
		var g := Node3D.new()
		g.name = "Lava Crack %d" % (k + 1)
		parent.add_child(g)
		var a0 := _floor_at(c + dir * CRACK_FROM)
		var a1 := _floor_at(c + dir * CRACK_TO)
		g.set_meta("a", a0)
		g.set_meta("b", a1)
		g.set_meta("flaring", false)
		var m := _mat("Lava Crack", Color(1.0, 0.4, 0.08), 0.4, 1.2).duplicate() as StandardMaterial3D
		g.set_meta("mat", m)
		var n := 6
		for i in n:
			var p0 := a0.lerp(a1, float(i) / n) + side * (0.25 if i % 2 == 0 else -0.25)
			var p1 := a0.lerp(a1, float(i + 1) / n) + side * (-0.25 if i % 2 == 0 else 0.25)
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.35, 0.06, p0.distance_to(p1) + 0.15)
			seg.mesh = bm
			seg.material_override = m
			seg.position = (p0 + p1) * 0.5 + Vector3(0, 0.04, 0)
			seg.look_at_from_position(seg.position, p1 + Vector3(0, 0.04, 0), Vector3.UP)
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(seg)
		var flare := MeshInstance3D.new()
		flare.name = "Flare"
		var fm := BoxMesh.new()
		fm.size = Vector3(1.0, 2.2, a0.distance_to(a1))
		flare.mesh = fm
		flare.material_override = _mat("Crack Flare", Color(1.0, 0.55, 0.15, 0.75), 0.5, 3.0)
		flare.position = (a0 + a1) * 0.5 + Vector3(0, 1.1, 0)
		flare.look_at_from_position(flare.position, a1 + Vector3(0, 1.1, 0), Vector3.UP)
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flare.visible = false
		g.add_child(flare)
		cracks.append(g)


func fighting() -> bool:
	return boss != null and not bool(boss.get("defeated")) and int(boss.get("state")) != 0


func _cracks_step() -> void:
	var beat := int(world.get("beat_n")) if world and world.get("beat_n") != null else int(_t / 0.7)
	if beat == _crack_beat:
		return
	_crack_beat = beat
	var on := fighting()
	var which := (beat / 2) % cracks.size()
	for i in cracks.size():
		var m := cracks[i].get_meta("mat") as StandardMaterial3D
		m.emission_energy_multiplier = 1.2
		if on and i == which:
			if beat % 2 == 0:
				m.emission_energy_multiplier = 4.0           # the warning beat
			else:
				flare_crack(i)


func flare_crack(i: int) -> void:
	var g := cracks[i]
	g.set_meta("flaring", true)
	var f := g.get_node("Flare") as MeshInstance3D
	f.visible = true
	f.scale = Vector3(1, 0.1, 1)
	var tw := f.create_tween()
	tw.tween_property(f, "scale", Vector3.ONE, 0.1)
	tw.tween_interval(FLARE_TIME - 0.2)
	tw.tween_property(f, "scale", Vector3(1, 0.1, 1), 0.1)
	tw.tween_callback(func() -> void:
		f.visible = false
		g.set_meta("flaring", false))
	Juice.blip("whoosh", 0.8, -8.0)


func _lava_step() -> void:
	# The lava ring: step into it and it bumps you back in (a bump, never more), like touching a Gloop
	var c := mark("chamber")
	var off := player.global_position - c
	var flat := Vector2(off.x, off.z).length()
	if flat > LAVA_R and flat < CHAMBER_R + 0.5 and absf(off.y) < 4.0 and not _on_causeway(off):
		_lava_bump(player.global_position, c + Vector3(off.x, 0, off.z).normalized() * (ARENA_R - 1.5))
	# ...a flaring crack in the arena floor (jump over it and it can't touch you)
	for g in cracks:
		if bool(g.get_meta("flaring")):
			var a: Vector3 = g.get_meta("a")
			var b: Vector3 = g.get_meta("b")
			var q := Geometry3D.get_closest_point_to_segment(player.global_position, a, b)
			var d := player.global_position - q
			if Vector2(d.x, d.z).length() < CRACK_HIT and d.y < 1.6:
				var away := Vector3(d.x, 0, d.z)
				if away.length() < 0.05:
					away = (b - a).cross(Vector3.UP)
				_lava_bump(player.global_position, _floor_at(q + away.normalized() * 1.8))
	# ...and the stream in the tunnel
	var s := get_node_or_null("Ember Tunnel/Lava Stream") as Node3D
	if s:
		var a: Vector3 = s.get_meta("a")
		var b: Vector3 = s.get_meta("b")
		var q := Geometry3D.get_closest_point_to_segment(player.global_position, a, b)
		var d := player.global_position - q
		if Vector2(d.x, d.z).length() < 0.45 and absf(d.y) < 1.4:
			_lava_bump(player.global_position, _floor_at(_nearest_on_route(player.global_position)))


func _nearest_on_route(p: Vector3) -> Vector3:
	# The middle of the tunnel nearest to here (away from the stream along its wall)
	var best := pt(ROUTE[0])
	var bd := INF
	for i in ROUTE.size() - 1:
		var q := Geometry3D.get_closest_point_to_segment(p, pt(ROUTE[i]), pt(ROUTE[i + 1]))
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = q
	return best


func _on_causeway(off: Vector3) -> bool:
	var mouth := pt(ROUTE[ROUTE.size() - 1]) - mark("chamber")
	return absf(wrapf(atan2(off.x, off.z) - atan2(mouth.x, mouth.z), -PI, PI)) < 0.32


func _lava_bump(from: Vector3, to: Vector3) -> void:
	# Always out of the lava (a hurt only when you can be hurt, so you never stand in it while you blink)
	if not player.call("is_invulnerable"):
		player.call("hurt", 1, from)
	player.global_position = to + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	Fx.burst(self, from, Color(1.0, 0.5, 0.15), 12, 0.08, 3.0, 2.0, 0.5)
	if _lava_told <= 0.0:
		Game.message("Hot hot hot! Keep off the lava.")
		_lava_told = 10.0


# Once Old Ember's calm: the Ember Chest, the steam up to the rim, and the Crater Lookout ------------------------------
func _make_chest(at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Ember Chest"
	add_child(g)
	g.global_position = _floor_at(at)
	var c := mark("chamber")
	var f := Vector3(c.x - at.x, 0, c.z - at.z).normalized()
	g.rotation.y = atan2(f.x, f.z)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.8, 0.9)
	box.mesh = bm
	box.material_override = _mat("Chest Basalt", Color(0.22, 0.18, 0.22), 0.8)
	box.position.y = 0.4
	g.add_child(box)
	var lid := Node3D.new()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.8, -0.45)
	g.add_child(lid)
	var lm := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(1.35, 0.3, 0.95)
	lm.mesh = lb
	lm.material_override = _mat("Chest Lid", Color(0.3, 0.2, 0.2), 0.7)
	lm.position = Vector3(0, 0.15, 0.45)
	lid.add_child(lm)
	for x in [-0.5, 0.5]:
		var band := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.12, 0.85, 0.95)
		band.mesh = bb
		band.material_override = _mat("Chest Glow", Color(1.0, 0.55, 0.2), 0.4, 2.0)
		band.position = Vector3(x, 0.42, 0)
		g.add_child(band)
	var spot := USE_SPOT.make(Vector3(0, 0, 1.3), _chest_offer, open_chest, 2.0, 2.4)
	spot.name = "Chest Spot"
	g.add_child(spot)
	KIT.in_the_dark(g)
	return g


func _chest_offer() -> String:
	return "open the Ember Chest" if boss and bool(boss.get("defeated")) and not _chest_open else ""


func open_chest() -> void:
	if _chest_open or not bool(boss.get("defeated")):
		return
	_chest_open = true
	var lid := _chest.get_node("Lid") as Node3D
	lid.create_tween().tween_property(lid, "rotation:x", -1.1, 0.5).set_trans(Tween.TRANS_BACK)
	var flag := "volcano_treasure_%d" % Requests.visit_day()
	if Dialogue.flags.has(flag):
		Game.message("Empty today. Come back next time!")
		return
	Dialogue.set_flag(flag)
	Game.add_sparkles(TREASURE)
	Game.message("The Ember Chest! ✦ %d sparkles." % TREASURE)
	Fx.burst(self, _chest.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.3), 24, 0.12, 4.0, 3.0)
	Juice.blip("chime", 1.0, -4.0)


func _make_lift(at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = "Steam Lift"
	add_child(g)
	g.global_position = _floor_at(at)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.3
	rim.mesh = tm
	rim.material_override = _mat("Vent Rim", Color(0.22, 0.18, 0.2), 0.9)
	rim.position.y = 0.06
	g.add_child(rim)
	var column := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 0.9
	var roof := KIT.ceiling_above(field, g.global_position + Vector3(0, 1.0, 0))
	cm.height = maxf(roof.y - g.global_position.y, 3.0)
	column.mesh = cm
	column.name = "Steam"
	column.material_override = _mat("Lift Steam", Color(1, 1, 1, 0.25), 1.0)
	column.position.y = cm.height * 0.5
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(column)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "ride the steam up" if g.visible else "",
		ride_steam, 2.0, 3.0)
	spot.name = "Lift Spot"
	g.add_child(spot)
	KIT.in_the_dark(g)
	return g


func _make_lookout() -> void:
	# A ledge of lava rock on the crater's rim, on the side looking out over the island, with a low wall round it
	var pk: Array = L.PEAKS[0]
	var top := L.at(float(pk[0]), float(pk[1]))
	var view := Vector3(-top.x, 0, -top.z).normalized()
	var at := top + view * (L.CRATER_R + 2.2)
	var hi := -INF
	for k in 12:
		var a := TAU * k / 12.0
		for r in [0.0, 0.8, 1.6]:
			hi = maxf(hi, L.height(at.x + cos(a) * r, at.z + sin(a) * r))
	var g := Node3D.new()
	g.name = "Crater Lookout"
	add_child(g)
	g.global_position = Vector3(at.x, hi + 0.2, at.z)
	g.rotation.y = atan2(view.x, view.z)
	var rock := _mat("Lookout Rock", Color(0.46, 0.34, 0.31), 0.9)   # (the peak's own rock, so it reads as an outcrop)
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(3.6, 0.5, 3.6)
	deck.mesh = dm
	deck.material_override = rock
	deck.position.y = -0.25
	g.add_child(deck)
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = 2.3
	um.bottom_radius = 3.4
	um.height = 7.0
	um.radial_segments = 7
	under.mesh = um
	under.material_override = rock
	under.position.y = -3.9
	g.add_child(under)
	var body := StaticBody3D.new()
	body.name = "Lookout Deck"
	g.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.6, 0.5, 3.6)
	cs.shape = bs
	cs.position.y = -0.25
	body.add_child(cs)
	# A low wall round it you can't climb, with gaps for the view (it's all one wall to the physics)
	var edge := StaticBody3D.new()
	edge.name = "Edge Lookout"
	edge.add_to_group("no_climb")
	g.add_child(edge)
	for w in [[Vector3(0, 0.6, 1.85), Vector3(3.8, 1.2, 0.2)], [Vector3(0, 0.6, -1.85), Vector3(3.8, 1.2, 0.2)],
			[Vector3(1.85, 0.6, 0), Vector3(0.2, 1.2, 3.8)], [Vector3(-1.85, 0.6, 0), Vector3(0.2, 1.2, 3.8)]]:
		var wcs := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = w[1]
		wcs.shape = wb
		wcs.position = w[0]
		edge.add_child(wcs)
		var wm := MeshInstance3D.new()
		var wbm := BoxMesh.new()
		wbm.size = Vector3(w[1].x, 0.5, w[1].z)
		wm.mesh = wbm
		wm.material_override = rock
		wm.position = w[0] - Vector3(0, 0.35, 0)
		g.add_child(wm)
	var sign := Label3D.new()
	sign.name = "Lookout Sign"
	sign.text = "Crater Lookout"
	sign.font_size = 44
	sign.pixel_size = 0.008
	sign.modulate = Color(1.0, 0.8, 0.45)
	sign.outline_size = 10
	sign.outline_modulate = Color(0.1, 0.05, 0.05)
	sign.position = Vector3(0, 0.55, 1.98)
	g.add_child(sign)
	var spot := USE_SPOT.make(Vector3(0, 0, -1.0), func() -> String: return "slide back down", way_down, 1.6, 2.6)
	spot.name = "Down Spot"
	g.add_child(spot)
	g.set_meta("stand", g.global_position + view * 0.2)
	g.set_meta("view", view)
	_lookout = g


# Little helpers ---------------------------------------------------------------------------------------------------
func _lamp(parent: Node3D, at: Vector3, col: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	parent.add_child(l)
	l.global_position = at
	return l


func _mat(id: String, c: Color, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.resource_name = id
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[id] = m
	return m


func _ball_mesh(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s
