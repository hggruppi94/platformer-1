extends "res://scripts/boss_lair.gd"

# Boulder Canyon, the Boulderdillo's own lair (Hayden, 15 Nov 2026: "I want the time goblins, and the crocodillo boss
# to get their own arenas as well"). The way in is the Canyon Mouth, a heap of boulders with a cave in it, in the
# middle of Boulder Hollow (scripts/bosses.gd). Inside, from the mouth (south) to the Boulderdillo (north, +z):
#   - The Rockslide Run: a red rock canyon where boulders keep rolling down three lanes at you. Step between the lanes
#     or jump them (a bump, never more). Two Crocodillos patrol it.
#   - The Rock Arch: boulders piled up either side, a slab across the top.
#   - The Pinball Pit: its arena, ringed with big boulders and four rock pillars in the middle to pinball off. It sits
#     on its Rock Throne until you come in, then the usual fight is on (scripts/crocodillo_boss.gd).
#     Its own trick: once it's up, rocks fall from the canyon rim. Look up: the rock wobbles loose right over where it'll land, dribbling gravel; get out from under it. A fallen rock
#     stays a while, and it bounces the Boulderdillo's rolls too.
#   - Pop it and the rocks stop, and the Big Geode by its throne cracks open.
# All the names and the look are first drafts for Hayden.

const CROC := "res://scenes/enemies/crocodillo.tscn"
const DETAIL := "res://scripts/detail_props.gd"

const ARENA := Vector3(0, 0, 74)
const ARENA_R := 20.0
const THRONE := Vector3(0, 0, 90)
const LANES := [-4.5, 0.0, 4.5]                # the Rockslide Run's three lanes (x)
const RUN := Vector2(42, 4)                    # boulders roll from z 42 down to z 4
const ROLL_SPEED := 7.0
const ROLL_EVERY := 2.6
const ROLL_R := 0.85
const FALL_EVERY := 4.5                        # rocks fall this often (3.2 s when it's cross)
const FALL_WARN := 1.3                         # the rock wobbles on the rim this long first
const FALL_FROM := 22.0                        # ...this high over where it'll land
const FALL_R := 1.6
const FALLEN_STAYS := 7.0
const FALLEN_MAX := 6

var rolling: Array[Node3D] = []                # boulders on their way down the run
var falls: Array = []                          # {node, t, up, gravel} rocks wobbling loose up on the rim
var fallen: Array = []                         # {node, t} rocks lying in the pit
var rocks_on := false
var _roll_t := 1.0
var _fall_t := 2.0


func lair_id() -> String:
	return "boulder_canyon"


func arena() -> Vector3:
	return ARENA


func wake_range() -> float:
	return 16.0


func treasure() -> int:
	return 12


func _build() -> void:
	_environment(Color(0.32, 0.5, 0.82), Color(1.0, 0.7, 0.45), Color(0.3, 0.16, 0.1), Color(0.85, 0.6, 0.45), 0.0035,
		Color(1.0, 0.85, 0.65))
	_floor(Vector2(64, 120), Vector3(0, 0, 46), Color(0.78, 0.5, 0.32), Color(0.88, 0.62, 0.4), "Canyon Sand")
	_bounds(29.0, -8.0, 100.0)
	_run()
	_arch()
	_pit()


func _rock(k: int) -> StandardMaterial3D:
	var cols := [Color(0.7, 0.33, 0.22), Color(0.85, 0.55, 0.3), Color(0.78, 0.45, 0.42), Color(0.6, 0.3, 0.25)]
	return _mat("Canyon Rock %d" % k, cols[k % cols.size()], 0.85)


func _boulder_mat() -> StandardMaterial3D:
	return _mat("Boulder", Color(0.55, 0.47, 0.5), 0.8)


# -----------------------------------------------------------------------------
# The Rockslide Run
# -----------------------------------------------------------------------------
func _run() -> void:
	var r := Node3D.new()
	r.name = "Rockslide Run"
	add_child(r)
	# The canyon walls: stripy layered rock, each stretch a bit different
	for side in [-1.0, 1.0]:
		for k in 12:
			var z := 2.0 + k * 4.0
			var h := _rng.randf_range(13.0, 20.0)
			var x: float = side * (10.0 + _rng.randf_range(0.0, 1.2))
			var bs := BoxShape3D.new()
			bs.size = Vector3(3.0, h, 4.2)
			_solid(r, "Canyon Wall", bs, Vector3(x, h / 2.0, z))
			var y := 0.0
			var band := 0
			while y < h:
				var bh := minf(_rng.randf_range(1.5, 3.5), h - y)
				var w := 3.0 + _rng.randf_range(-0.3, 0.6)
				_box(r, "Rock Band", Vector3(w, bh, 4.3), Vector3(x + side * _rng.randf_range(-0.2, 0.3), y + bh / 2.0, z),
					_rock(band + k), false)
				y += bh
				band += 1
	# The lanes, worn into the sand, and a heap of rocks at the top where they come from
	for x in LANES:
		_box(r, "Lane", Vector3(1.6, 0.02, RUN.x - RUN.y), Vector3(x, 0.01, (RUN.x + RUN.y) / 2.0), _mat("Lane", Color(0.62, 0.38, 0.25)), false)
	for k in 7:
		_ball(r, "Rock Heap", _rng.randf_range(1.0, 1.8), Vector3(_rng.randf_range(-7.5, 7.5), 0.6, RUN.x + 2.5 + _rng.randf_range(0, 1.5)),
			_boulder_mat(), false)
	_sign(r, "BOULDER CANYON\nwatch out for rocks!", Vector3(-6.5, 0, 7.0), PI, Color(0.45, 0.22, 0.15))
	var spots := [Vector3(-2, 0.4, 20), Vector3(2, 0.4, 32)]
	for k in spots.size():
		var c := (load(CROC) as PackedScene).instantiate() as Node3D
		c.name = "Canyon Crocodillo %d" % (k + 1)
		c.position = spots[k]
		add_child(c)


func _roll_one() -> void:
	var b := Node3D.new()
	b.name = "Rolling Boulder"
	add_child(b)
	b.position = Vector3(LANES[_rng.randi() % LANES.size()], ROLL_R, RUN.x)
	(load(DETAIL) as GDScript).canyon_rock(_ball(b, "Ball", ROLL_R, Vector3.ZERO, _boulder_mat(), false))
	_ball(b, "Moss", ROLL_R * 0.55, Vector3(0, ROLL_R * 0.55, 0), _mat("Moss", Color(0.35, 0.6, 0.35)), false)
	rolling.append(b)
	Juice.dust(self, b.global_position - Vector3(0, ROLL_R, 0), 0.6)
	Audio.play_at("roll", b.global_position, 2.0, -0.2)


# -----------------------------------------------------------------------------
# The Rock Arch and the Pinball Pit
# -----------------------------------------------------------------------------
func _arch() -> void:
	var a := Node3D.new()
	a.name = "Rock Arch"
	add_child(a)
	for side in [-1.0, 1.0]:
		for k in 4:
			_ball(a, "Arch Boulder", 1.6 - k * 0.15, Vector3(side * (6.5 + _rng.randf_range(-0.3, 0.3)), 1.4 + k * 2.4, 50.0), _rock(k + 1))
	_box(a, "Arch Slab", Vector3(16.0, 1.4, 3.0), Vector3(0, 10.0, 50.0), _rock(0), false)


func _pit() -> void:
	var p := Node3D.new()
	p.name = "Pinball Pit"
	p.position = ARENA
	add_child(p)
	_cyl(p, "Pit Floor", ARENA_R, ARENA_R, 0.03, Vector3(0, 0.015, 0), _mat("Pit Sand", Color(0.72, 0.4, 0.28), 0.9), false)
	# The ring of big boulders (a way in at the south)
	for k in 18:
		var ang := TAU * k / 18.0
		if absf(wrapf(ang - PI, -PI, PI)) < 0.3:
			continue
		var r := _rng.randf_range(1.8, 2.6)
		_ball(p, "Pit Boulder", r, Vector3(sin(ang), 0, cos(ang)) * (ARENA_R + 1.5) + Vector3(0, r * 0.7, 0), _boulder_mat())
	# Four rock pillars to pinball off
	for k in 4:
		var ang := TAU * (k + 0.5) / 4.0
		_cyl(p, "Pillar", 1.3, 1.7, 4.0, Vector3(sin(ang), 0, cos(ang)) * 10.0 + Vector3(0, 2.0, 0), _rock(k))
	# The canyon rim all round, high up (where the rocks fall from)
	for k in 26:
		var ang := TAU * k / 26.0
		var h := _rng.randf_range(16.0, 24.0)
		_box(p, "Rim Rock", Vector3(9.0, h, 6.0), Vector3(sin(ang), 0, cos(ang)) * 28.0 + Vector3(0, h / 2.0, 0), _rock(k), false).rotation.y = ang
	# The Rock Throne
	_cyl(self, "Rock Throne", 2.6, 3.0, 1.2, THRONE + Vector3(0, 0.6, 0), _rock(2))
	_box(self, "Throne Back", Vector3(5.0, 4.0, 1.2), THRONE + Vector3(0, 2.0, 3.0), _rock(3))
	_geode(THRONE + Vector3(-6.0, 0, -2.0))


func _geode(at: Vector3) -> void:
	_chest = Node3D.new()
	_chest.name = "Big Geode"
	_chest.position = at
	add_child(_chest)
	var shell := _mat("Geode Shell", Color(0.5, 0.45, 0.48), 0.9)
	var bottom := SphereMesh.new()
	bottom.radius = 0.9
	bottom.height = 0.9
	bottom.is_hemisphere = true
	var bm := _mesh(_chest, bottom, Vector3(0, 0.9, 0), shell)
	bm.rotation.x = PI
	var bs := SphereShape3D.new()
	bs.radius = 0.9
	_solid(_chest, "Geode Body", bs, Vector3(0, 0.9, 0))
	var crystals := _mat("Geode Crystals", Color(0.75, 0.45, 1.0), 0.2, 1.3)
	for k in 7:
		var ang := TAU * k / 7.0
		var c := _cyl(_chest, "Crystal", 0.0, 0.16, 0.55, Vector3(cos(ang) * 0.4, 0.95, sin(ang) * 0.4), crystals, false)
		c.rotation = Vector3(sin(ang) * 0.4, 0, -cos(ang) * 0.4)
	var lid := Node3D.new()                                   # the top half, hinged at the back
	lid.name = "Lid"
	lid.position = Vector3(0, 0.9, 0.85)
	_chest.add_child(lid)
	var top := SphereMesh.new()
	top.radius = 0.9
	top.height = 0.9
	top.is_hemisphere = true
	_mesh(lid, top, Vector3(0, 0, -0.85), shell)
	_treasure(at)


func _open_look() -> void:
	var lid := _chest.get_node("Lid") as Node3D
	lid.create_tween().tween_property(lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK)
	Juice.blip("chime", 0.9, -3.0)


func _way_look(b: Node3D) -> void:
	# A little cave mouth of boulders with a warm glow inside
	for side in [-1.0, 1.0]:
		_ball(b, "Way Rock", 0.9, Vector3(side * 1.3, 0.8, 0), _boulder_mat(), false)
	_ball(b, "Way Rock", 1.0, Vector3(0, 2.4, 0), _boulder_mat(), false)
	var glow := _cyl(b, "Glow", 1.0, 1.0, 0.08, Vector3(0, 1.3, 0), _mat("Way Glow", Color(1.0, 0.8, 0.4, 0.6), 0.1, 1.2), false)
	glow.rotation.x = PI / 2.0
	glow.scale = Vector3(0.9, 1.0, 1.3)


# -----------------------------------------------------------------------------
# The Boulderdillo
# -----------------------------------------------------------------------------
func _make_boss() -> CharacterBody3D:
	var b := (load(CROC) as PackedScene).instantiate() as CharacterBody3D
	b.set_script(load("res://scripts/crocodillo_boss.gd"))
	b.name = "The Boulderdillo"
	b.set("size", 2.6)
	b.set("stomps_to_defeat", 16)
	b.set("damage", 3)
	b.set("xp_reward", 60)
	b.set("wander_radius", 8.0)
	b.set("sight_range", 24.0)
	b.set("leash_range", ARENA_R + 6.0)
	b.set("stalk_speed", 2.6)
	b.set("roll_speed", 11.0)
	b.set("roll_time", 1.3)
	b.set("dizzy_time", 3.6)
	b.set("roll_cooldown", 1.6)
	b.position = THRONE + Vector3(0, 1.7, 0)
	return b


func _on_wake() -> void:
	boss.set("home", ARENA + Vector3(0, 0.4, 4.0))
	boss.velocity = Vector3(0, 6.0, -5.0)
	rocks_on = true
	_fall_t = 3.0
	Game.message("The Boulderdillo rolls off its throne! Watch for falling rocks!")
	Audio.play_at("stomp", boss.global_position, 4.0, -0.4)


func _on_popped() -> void:
	rocks_on = false
	for f in falls:
		(f.node as Node).queue_free()
	falls.clear()


func fall_every() -> float:
	return FALL_EVERY * (0.7 if is_instance_valid(boss) and bool(boss.get("_cross")) else 1.0)


func drop_rock(at: Vector3) -> void:
	# No shadow on the floor: the rock itself shows up on the canyon's rim right over where it'll land, wobbling loose
	# and dribbling gravel down, then drops (_land)
	var s := Node3D.new()
	s.name = "Rock Coming"
	add_child(s)
	s.position = Vector3(at.x, 0.05, at.z)
	var up := Node3D.new()
	up.name = "Up High"
	s.add_child(up)
	up.position.y = FALL_FROM
	(load(DETAIL) as GDScript).canyon_rock(_ball(up, "Rock", 0.95, Vector3.ZERO, _boulder_mat(), false))
	falls.append({"node": s, "t": 0.0, "up": up, "gravel": 0.0})


func _gravel(f: Dictionary) -> void:
	# A pebble falling from the loose rock: you can see where it's coming down
	var s := f.node as Node3D
	var peb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.2
	peb.mesh = sm
	peb.material_override = _boulder_mat()
	s.add_child(peb)
	peb.position = Vector3(_rng.randf_range(-0.5, 0.5), FALL_FROM - 0.8, _rng.randf_range(-0.5, 0.5))
	var tw := peb.create_tween()
	tw.tween_property(peb, "position:y", 0.1, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(peb.queue_free)


func _land(f: Dictionary) -> void:
	var s := f.node as Node3D
	var at := s.global_position
	s.queue_free()
	var rock := Node3D.new()
	rock.name = "Fallen Rock"
	add_child(rock)
	rock.global_position = Vector3(at.x, FALL_FROM, at.z)
	(load(DETAIL) as GDScript).canyon_rock(_ball(rock, "Rock", 0.95, Vector3.ZERO, _boulder_mat(), false))
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position:y", 0.9, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Juice.dust(self, Vector3(at.x, 0.0, at.z), 1.0)
		Juice.blip("thud", 0.7, -3.0)
		var p := _player as CharacterBody3D
		var near := p != null and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < FALL_R + 0.3
		if near and p.global_position.y < 3.0:
			bump(Vector3(at.x, p.global_position.y, at.z))
		# It's only solid once it's down, and never round her (so it can't land on her and trap her)
		if not near:
			var ss := SphereShape3D.new()
			ss.radius = 0.95
			_solid(rock, "Rock Body", ss, Vector3.ZERO))
	fallen.append({"node": rock, "t": 0.0})
	while fallen.size() > FALLEN_MAX:
		(fallen.pop_front().node as Node).queue_free()


func _lair_step(delta: float) -> void:
	var p := _player as CharacterBody3D
	# The Rockslide Run: a boulder every few seconds while you're in it
	if p and p.global_position.z > RUN.y - 2.0 and p.global_position.z < RUN.x + 2.0:
		_roll_t -= delta
		if _roll_t <= 0.0:
			_roll_t = ROLL_EVERY
			_roll_one()
	for b in rolling.duplicate():
		b.position.z -= ROLL_SPEED * delta
		b.rotate_x(-ROLL_SPEED / ROLL_R * delta)
		if b.position.z < RUN.y:
			Juice.dust(self, b.global_position - Vector3(0, ROLL_R, 0), 0.5)
			rolling.erase(b)
			b.queue_free()
			continue
		if p and not p.call("is_invulnerable"):
			var d := Vector2(p.global_position.x - b.position.x, p.global_position.z - b.position.z).length()
			if d < ROLL_R + 0.5 and p.global_position.y < ROLL_R * 2.0 + 0.5:
				bump(b.global_position)
	# Falling rocks in the pit, once it's up
	if rocks_on:
		_fall_t -= delta
		if _fall_t <= 0.0 and p:
			_fall_t = fall_every()
			var here := p.global_position - ARENA
			here.y = 0.0
			if here.length() > ARENA_R - 2.0:
				here = here.normalized() * (ARENA_R - 2.0)
			drop_rock(ARENA + here)
			for i in 2:
				var ang := _rng.randf() * TAU
				drop_rock(ARENA + Vector3(sin(ang), 0, cos(ang)) * _rng.randf_range(3.0, ARENA_R - 3.0))
	for f in falls.duplicate():
		f.t += delta
		var k := clampf(f.t / FALL_WARN, 0.0, 1.0)
		(f.up as Node3D).position = Vector3(sin(f.t * 40.0), FALL_FROM, cos(f.t * 37.0)) * Vector3(0.12 * k, 1, 0.12 * k)
		f.gravel -= delta
		if f.gravel <= 0.0:
			f.gravel = lerpf(0.4, 0.12, k)
			_gravel(f)
		if f.t >= FALL_WARN:
			falls.erase(f)
			_land(f)
	for r in fallen.duplicate():
		r.t += delta
		if r.t > FALLEN_STAYS:
			fallen.erase(r)
			var n := r.node as Node3D
			if is_instance_valid(n):
				Juice.dust(self, n.global_position - Vector3(0, 0.9, 0), 0.5)
				n.queue_free()
