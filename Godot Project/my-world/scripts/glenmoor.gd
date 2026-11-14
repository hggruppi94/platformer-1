extends "res://scripts/portal_world.gd"

# Since 12 Nov 2026 Glenmoor is the fifth portal world: Hayden swapped spring and summer, so Glenmoor comes
# before the Tide Reef and Rhythm Springs after it (scripts/portals.gd quake_due).
#
# Glenmoor, Heather's home world (plan item 19a world 6; scene built by tools/build_glenmoor.gd). Misty highland hills,
# purple heather, dry stone walls and fluffy highland critters: home of Heather the cattle girl and her best friend
# Isla. (Heather's from the farm in Glenmoor's lowlands and Isla from up the glen: one Southern, one Scottish, the
# story's two Highland cattle girl best friends.)
#
# The time problem (Hayden, 10 Nov 2026: "a sort of continuous looping between day and night with factions that
# prefer both warring over the unpredictable cycle", "a sort of yin and yang theme"): the Stormram's whirlwind
# (scripts/stormram.gd) has set day and night LOOPING. The sun races up and down, sometimes fast, sometimes slow,
# sometimes backwards (the flux), and a card at the top says whether it's day, dusk, night or dawn. The glen's split
# in two over it: the Sunfolk (Heather's side, by the croft) want it always day, and the Moonfolk (Isla's side, up
# the glen) want it always night. Each side cheers when its time comes round and grumbles when it goes.
# Three Balance Charms (a yin and yang charm in three parts) set it right. Each one makes the loop a little steadier:
#   charm 1  the Sun Charm, for Heather and the Sunfolk: herd the five Fluffkins (fluffy highland calves) into the
#            stone Fold. They trot away from you, so walk round behind one; they only go in through the gate.
#   charm 2  the Twilight Charm, for both sides: the shared garden. Sunflowers open by day and moonflowers by night;
#            catch each one open and sing it still (Interact).
#   charm 3  the Moon Charm, for Isla and the Moonfolk: race Isla up Ben Bonnie, past the six cairns in order.
# With all three, the Stormram wakes on the Standing Stones when you come near. Popping it mends the world
# (Portals.clear, which also opens spring on Earth): day and night go back to a normal, steady day, the two sides
# make peace, and Heather teaches her spring moves (scripts/showers.gd, scripts/spring_step.gd).

const STORMRAM := preload("res://scripts/stormram.gd")
const CROC := "res://scenes/enemies/crocodillo.tscn"
const CYCLE := [10.0, 14.0, 20.0, 28.0]      # seconds for a day and a night, by how many charms you have (each slows it)
const NORMAL_DAY := 240.0                    # once it's mended: a steady day and night in four minutes
const FLUX_EVERY := [2.0, 5.0]               # the flux picks a new speed this often (seconds, at random)...
const FLUX_SPEEDS := [0.35, 2.2]             # ...from this range (times the cycle's own speed)
const BACKWARDS := [0.25, 0.15, 0.05, 0.0]   # the chance each new speed runs time backwards, by charms
const OPEN_FROM := 0.68                      # a sunflower's open in this much daylight (a moonflower in this much dark)
const FLUFFS := 5
const FLEE_NEAR := 5.0                       # a Fluffkin trots away from you inside this...
const FLEE_SPEED := 3.6                      # ...this fast (you run at 5, so you can always get round behind)
const GRAZE_SPEED := 0.6
const ROAM_R := 44.0                         # they stay inside this (the fence is at 48.6)
const BEDS := 5
const BLOOM_FROM := 0.5                      # full bloom is this part of the cycle...
const BLOOM_TO := 0.85                       # ...to this (2.8 seconds: plenty of time to sing to it)
const CAIRN_REACH := 3.2
const ISLA_SPEED := 4.0                      # Isla runs up a bit slower than you (and stops for breath at the top)
const COUNTDOWN := 3.0
const WAKE_NEAR := 18.0
const TEACH_AFTER := 3.0
const BELL_GOLD := Color(1.0, 0.82, 0.35)
const BLOSSOM := Color(1.0, 0.75, 0.85)
const SUN_GOLD := Color(1.0, 0.78, 0.3)
const MOON_BLUE := Color(0.55, 0.62, 1.0)
const CHARMS := ["the Sun Charm", "the Twilight Charm", "the Moon Charm"]
# The two sides of the glen: where each camp stands, and who's in it (made like the townsfolk; working names)
const SUN_CAMP := Vector3(12.0, 0.0, 9.0)
const MOON_CAMP := Vector3(-12.0, 0.0, 2.0)
const PEACE_AT := Vector3(-4.0, 0.0, 5.5)              # between the camps, just off the path
const SUNFOLK := [
	{"name": "Goldie", "body": "cow", "colors": {"fur": 3, "hair": 11, "eyes": 4, "accent": 11, "top": 11, "bottoms": 10, "shoes": 4}},
	{"name": "Barley", "body": "bunny", "colors": {"fur": 2, "hair": 10, "eyes": 12, "accent": 10, "top": 10, "bottoms": 11, "shoes": 3}},
	{"name": "Sunny Jim", "body": "cat", "colors": {"fur": 10, "hair": 11, "eyes": 11, "accent": 9, "top": 9, "bottoms": 11, "shoes": 4}},
]
const MOONFOLK := [
	{"name": "Morag", "body": "cat", "colors": {"fur": 8, "hair": 6, "eyes": 14, "accent": 15, "top": 15, "bottoms": 16, "shoes": 6}},
	{"name": "Wee Dougal", "body": "bunny", "colors": {"fur": 7, "hair": 8, "eyes": 15, "accent": 16, "top": 16, "bottoms": 15, "shoes": 6}},
	{"name": "Nessa", "body": "cow", "colors": {"fur": 6, "hair": 7, "eyes": 13, "accent": 14, "top": 14, "bottoms": 16, "shoes": 8}},
]

# Day and night: the grass, the rowans' spring blossom, the hills, the sky and the light
const DAY := {"grass": Color(0.5, 0.78, 0.38), "leaves": Color(1.0, 0.78, 0.86), "hill": Color(0.45, 0.68, 0.38),
	"top": Color(0.42, 0.62, 0.92), "horizon": Color(0.92, 0.9, 0.86), "light": Color(1.0, 0.95, 0.85), "energy": 1.1,
	"fog": Color(0.74, 0.8, 0.86), "ambient": 0.4}
const DUSK := {"top": Color(0.4, 0.38, 0.62), "horizon": Color(1.0, 0.6, 0.45), "light": Color(1.0, 0.62, 0.42),
	"fog": Color(0.72, 0.55, 0.55)}
const NIGHT := {"grass": Color(0.18, 0.3, 0.32), "leaves": Color(0.5, 0.45, 0.62), "hill": Color(0.16, 0.26, 0.3),
	"top": Color(0.03, 0.04, 0.14), "horizon": Color(0.14, 0.16, 0.3), "light": Color(0.55, 0.65, 1.0), "energy": 0.28,
	"fog": Color(0.12, 0.14, 0.24), "ambient": 0.25}

var day_k := 0.0                             # 0..1 round a day: 0 noon, 0.25 dusk, 0.5 midnight, 0.75 dawn
var _flux := 1.0                             # how fast (and which way) the flux is running it just now
var _flux_left := 0.0
var _was_day := true
var racing := false
var race_go := false                         # past the countdown
var race_next := 0                           # the next cairn to reach
var stormram: CharacterBody3D
var _t := 0.0
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _mats := {}                              # material name -> this copy's own material (so the preview never changes)
var _snow: Array = []
var _night_sky: Node3D
var _star_mat: StandardMaterial3D
var _sunfolk: Array = []
var _moonfolk: Array = []
var _sun_tilt := Vector3.ZERO
var _fluffs: Array = []                      # [node, target] for each Fluffkin
var _plants: Array = []
var _held_pose: Array = []                   # (the phase each plant was held at)
var _isla: Node3D
var _isla_d := 0.0
var _isla_done := false
var _countdown := 0.0
var _race_line: Path3D
var _heather_anim: AnimationPlayer
var _hud: CanvasLayer
var _sky_label: Label
var _race_label: Label


func picture() -> void:
	# In the portal's preview: day and night looping over the glen, the Fluffkins out in the meadow and the garden
	_own_looks()
	_add_fluffkins()
	_add_garden()
	set_process(true)


func setup() -> void:
	_own_looks()
	_soft_ground()
	_add_fluffkins()
	_add_garden()
	_add_heather()
	_add_isla()
	_add_camps()
	_race_line = get_node_or_null("RaceLine") as Path3D
	_make_hud()
	if is_mended():
		set_daylight(0.85)                                   # a fresh spring morning
	else:
		_add_stormram()
	_was_day = is_day()
	_show_sky()
	if not is_mended() and bells() == 0 and not Portals.has_found(world_id, "met_heather"):
		Game.message.call_deferred("Glenmoor: day, night, day, night!")


func _soft_ground() -> void:
	# The glen's grass and Ben Bonnie's slopes are soil: Bramble's burrow digs into them (scripts/burrow.gd soil())
	for holder in ["Glen", "Ben Bonnie"]:
		var h := get_node_or_null(holder)
		if h:
			for b in h.find_children("*", "StaticBody3D", true, false):
				b.add_to_group("soil")


func is_mended() -> bool:
	return Portals.is_cleared(world_id)


# Day and night, looping --------------------------------------------------------------------------------------------
func _own_looks() -> void:
	# Each copy of the world gets its own sky and its own materials, so the preview never changes with this one
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_sun_tilt = _sun.rotation
	_mats = {}
	_snow = []
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m == null:
			continue
		if m.resource_name in ["Glen Grass", "Leaves", "Hill Grass"]:
			if not _mats.has(m.resource_name):
				_mats[m.resource_name] = m.duplicate()
			(mi as MeshInstance3D).material_override = _mats[m.resource_name]
		if str(mi.name).begins_with("Snow Cap"):
			_snow.append(mi)
			(mi as Node3D).visible = false                   # (it's spring in the glen, so no snow)
	_add_night_sky()
	set_daylight(day_k)


func _add_night_sky() -> void:
	# A moon and a sky full of stars that fade in at night (made here: the builder's sky is a daytime one)
	_night_sky = Node3D.new()
	_night_sky.name = "Night Sky"
	add_child(_night_sky)
	_star_mat = _mat(Color(1.0, 1.0, 0.95), 3.0, 1.0)
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if "disable_fog" in _star_mat:
		_star_mat.set("disable_fog", true)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _ball(1.0, 4)
	mm.instance_count = 160
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.2, 1.0)
		var dir := Vector3(cos(a) * sqrt(1.0 - up * up), up, sin(a) * sqrt(1.0 - up * up))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.5, 1.3)), dir * 260.0))
	var stars := MultiMeshInstance3D.new()
	stars.name = "Stars"
	stars.multimesh = mm
	stars.material_override = _star_mat
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_night_sky.add_child(stars)
	var moon := _put(_night_sky, _ball(9.0, 16), _star_mat, Vector3(-120, 150, -170))
	moon.name = "Moon"
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func daylight() -> float:
	# 1 at noon, 0 at midnight
	return 0.5 + 0.5 * cos(day_k * TAU)


func is_day() -> bool:
	return daylight() >= 0.5


func cycle_len() -> float:
	return NORMAL_DAY if is_mended() else CYCLE[bells()]


func time_words() -> String:
	var l := daylight()
	if l >= 0.65:
		return "☀ Day"
	if l <= 0.35:
		return "🌙 Night"
	return "🌅 Dusk" if day_k < 0.5 else "🌄 Dawn"


func set_daylight(k: float) -> void:
	day_k = fposmod(k, 1.0)
	var l := daylight()
	var dusk := clampf(1.0 - absf(l - 0.5) / 0.3, 0.0, 1.0)           # the sky blushes on the way through
	for key in [["Glen Grass", "grass"], ["Leaves", "leaves"], ["Hill Grass", "hill"]]:
		var m := _mats.get(key[0]) as StandardMaterial3D
		if m:
			m.albedo_color = (NIGHT[key[1]] as Color).lerp(DAY[key[1]], l)
	var top := (NIGHT.top as Color).lerp(DAY.top, l).lerp(DUSK.top, dusk * 0.6)
	var horizon := (NIGHT.horizon as Color).lerp(DAY.horizon, l).lerp(DUSK.horizon, dusk * 0.7)
	if _sky:
		_sky.sky_top_color = top
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
	if _env:
		_env.fog_light_color = (NIGHT.fog as Color).lerp(DAY.fog, l).lerp(DUSK.fog, dusk * 0.5)
		_env.ambient_light_energy = lerpf(NIGHT.ambient, DAY.ambient, l)
	if _sun:
		_sun.light_color = (NIGHT.light as Color).lerp(DAY.light, l).lerp(DUSK.light, dusk * 0.6)
		_sun.light_energy = lerpf(NIGHT.energy, DAY.energy, l)
		_sun.rotation = _sun_tilt + Vector3(lerpf(0.75, 0.0, l), day_k * 0.6, 0)      # low by night (the moon's light)
	if _star_mat:
		_star_mat.albedo_color.a = clampf((0.45 - l) / 0.3, 0.0, 1.0)
	if _night_sky:
		_night_sky.visible = l < 0.45


func _loop(delta: float) -> void:
	# The flux: day and night keep looping, at a speed that keeps changing (and now and then running backwards).
	# Each Balance Charm makes it steadier; mended, it's a normal day at a steady pace.
	if is_mended():
		_flux = 1.0
	else:
		_flux_left -= delta
		if _flux_left <= 0.0:
			_flux_left = randf_range(FLUX_EVERY[0], FLUX_EVERY[1])
			var steady := bells() / 3.0
			_flux = lerpf(randf_range(FLUX_SPEEDS[0], FLUX_SPEEDS[1]), 1.0, steady * 0.6)
			if randf() < BACKWARDS[bells()]:
				_flux = -_flux
	set_daylight(day_k + _flux * delta / cycle_len())
	var now := is_day()
	if now != _was_day:
		_was_day = now
		_show_sky()
		if not has_meta("preview"):
			_cheer(now)
			if not is_mended():
				Juice.blip("whoosh", 1.3 if now else 0.8, -16.0)


# The Balance Charms (their ids are still bell_1..3) --------------------------------------------------------------
func has_bell(i: int) -> bool:
	return is_mended() or Portals.has_found(world_id, "bell_%d" % (i + 1))


func bells() -> int:
	var n := 0
	for i in 3:
		if has_bell(i):
			n += 1
	return n


func ring_bell(i: int, at: Vector3) -> void:
	if has_bell(i):
		return
	Portals.note_found(world_id, "bell_%d" % (i + 1))
	Fx.burst(self, at + Vector3(0, 1.5, 0), [SUN_GOLD, BELL_GOLD, MOON_BLUE][i], 36, 0.1, 4.5, -1.0, 1.2)
	Juice.blip("chime", 0.9 + bells() * 0.15, -2.0)
	Juice.rumble(0.3, 0.2)
	var n := bells()
	Game.message(("Got %s! (%d of 3)" % [CHARMS[i], n]) if n < 3
		else "All three charms! Something woolly BLEATS...")
	_show_sky()


# The Fluffkins ------------------------------------------------------------------------------------------------------
func is_penned(i: int) -> bool:
	return has_bell(0) or Portals.has_found(world_id, "fluff_%d" % (i + 1))


func penned() -> int:
	var n := 0
	for i in FLUFFS:
		if is_penned(i):
			n += 1
	return n


func _add_fluffkins() -> void:
	_fluffs = []
	var holder := Node3D.new()
	holder.name = "Fluffkins"
	add_child(holder)
	var fold := _fold()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for i in FLUFFS:
		var m := get_node_or_null("Fluff%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var f := fluffkin_model(i)
		f.name = "Fluffkin %d" % (i + 1)
		holder.add_child(f)
		var at := m.global_position
		if is_penned(i) and fold:
			var a := i * TAU / FLUFFS + 0.6
			at = fold.global_position + Vector3(cos(a), 0, sin(a)) * 2.4
		f.global_position = Vector3(at.x, 0.0, at.z)
		f.rotation.y = rng.randf() * TAU
		_fluffs.append([f, f.global_position])


func fluffkin(i: int) -> Node3D:
	return _fluffs[i][0] if i < _fluffs.size() else null


func _fold() -> Node3D:
	return get_node_or_null("Fold") as Node3D


func in_fold(p: Vector3) -> bool:
	var fold := _fold()
	if fold == null:
		return false
	return Vector2(p.x - fold.global_position.x, p.z - fold.global_position.z).length() < float(fold.get_meta("radius")) - 0.7


func fluff_step(player: Node3D, delta: float) -> void:
	# Each Fluffkin trots away from you when you're close, and grazes about when you're not. They can only get into
	# the Fold through its gate; once in, they're penned and stay.
	var fold := _fold()
	var hill := get_node_or_null("Hill") as Node3D
	for i in _fluffs.size():
		var f := _fluffs[i][0] as Node3D
		var p := f.global_position
		var move := Vector3.ZERO
		if is_penned(i):
			var c := fold.global_position if fold else p
			var to: Vector3 = _fluffs[i][1]
			if Vector2(to.x - p.x, to.z - p.z).length() < 0.3 or Vector2(to.x - c.x, to.z - c.z).length() > 3.0:
				var a := randf() * TAU
				_fluffs[i][1] = c + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 3.0)
			move = (_fluffs[i][1] - p) * Vector3(1, 0, 1)
			move = move.normalized() * GRAZE_SPEED * 0.7 if move.length() > 0.1 else Vector3.ZERO
		else:
			var away := p - player.global_position if player else Vector3(99, 0, 0)
			away.y = 0.0
			if player and away.length() < FLEE_NEAR:
				move = away.normalized() * FLEE_SPEED
				f.set_meta("bounce", true)
			else:
				f.set_meta("bounce", false)
				var to: Vector3 = _fluffs[i][1]
				if Vector2(to.x - p.x, to.z - p.z).length() < 0.4 or randf() < delta * 0.1:
					var a := randf() * TAU
					_fluffs[i][1] = p + Vector3(cos(a), 0, sin(a)) * 3.0
				move = (_fluffs[i][1] - p) * Vector3(1, 0, 1)
				move = move.normalized() * GRAZE_SPEED if move.length() > 0.1 else Vector3.ZERO
		move = _fluff_slide(f, p, move, delta, player)
		var q := p + move * delta
		q = _keep_fluff_out(q, i)
		if hill:
			var hr := Vector2(q.x - hill.global_position.x, q.z - hill.global_position.z)
			var room := float(hill.get_meta("radius")) + 1.0
			if hr.length() < room:
				var out := hr.normalized() * room
				q = Vector3(hill.global_position.x + out.x, q.y, hill.global_position.z + out.y)
		var flat := Vector2(q.x, q.z)
		if flat.length() > ROAM_R:
			flat = flat.normalized() * ROAM_R
			q = Vector3(flat.x, q.y, flat.y)
		q.y = 0.0
		if (q - p).length() > 0.001:
			f.rotation.y = lerp_angle(f.rotation.y, atan2(q.x - p.x, q.z - p.z), minf(1.0, delta * 8.0))
		f.global_position = q
		var body := f.get_node_or_null("Body") as Node3D
		if body:
			var hop := absf(sin(_t * 9.0 + i)) * 0.18 if f.get_meta("bounce", false) else absf(sin(_t * 2.0 + i)) * 0.03
			body.position.y = 0.5 + hop
		if not is_penned(i) and in_fold(q):
			pen_fluff(i)


func _fluff_slide(f: Node3D, p: Vector3, move: Vector3, delta: float, player: Node3D) -> Vector3:
	# Fluffkins go round walls, fences and houses instead of through them, and one that's pinned in a corner while
	# you chase it slips out sideways (Hayden, 14 Nov playtest: one got stuck behind a wall)
	if move.length() < 0.01 or not is_inside_tree():
		return move
	var space := get_world_3d().direct_space_state
	var dir := move.normalized()
	for k in 2:
		var from := p + Vector3(0, 0.45, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * (move.length() * delta + 0.75))
		if player is CollisionObject3D:
			q.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var fold_wall := get_node_or_null("The Fold")
		if fold_wall and fold_wall.is_ancestor_of(hit.collider):
			break                                       # (the Fold's own wall: _keep_fluff_out sees to that)
		var n: Vector3 = hit.normal
		n.y = 0.0
		if n.length() < 0.2:
			break                                       # (the ground rising: walk on up)
		n = n.normalized()
		var along := move - n * move.dot(n)
		if along.length() < move.length() * 0.3:
			# Head on: slip off to the side away from you (or either side, grazing)
			var side := Vector3(-n.z, 0, n.x)
			if player and side.dot(p - player.global_position) < 0.0:
				side = -side
			along = side * move.length()
		move = along
		dir = move.normalized()
	# Pinned (in a corner) while running away: a little slip sideways for a moment
	var stuck := float(f.get_meta("stuck", 0.0))
	var last: Vector3 = f.get_meta("last_at", p)
	if f.get_meta("bounce", false) and (p - last).length() < move.length() * delta * 0.25:
		stuck += delta
	else:
		stuck = maxf(stuck - delta, 0.0)
	f.set_meta("last_at", p)
	if stuck > 0.6:
		var slip := Vector3(-move.z, 0, move.x).normalized()
		if f.get_index() % 2 == 1:
			slip = -slip
		move = slip * FLEE_SPEED
		stuck = 0.0 if stuck > 1.6 else stuck
	f.set_meta("stuck", stuck)
	return move


func _keep_fluff_out(q: Vector3, i: int) -> Vector3:
	# The Fold's wall: a Fluffkin outside it can only come in through the gate (and a penned one stays in)
	var fold := _fold()
	if fold == null:
		return q
	var c := fold.global_position
	var r := float(fold.get_meta("radius"))
	var d := Vector2(q.x - c.x, q.z - c.z)
	var a := atan2(d.y, d.x)
	var at_gate := absf(wrapf(a - float(fold.get_meta("gate")), -PI, PI)) < 0.38
	if is_penned(i):
		if d.length() > r - 1.2:
			var back := d.normalized() * (r - 1.2)
			return Vector3(c.x + back.x, q.y, c.z + back.y)
		return q
	if not at_gate and d.length() < r + 0.9 and d.length() > r - 1.0:
		# Pushed up against the Fold's wall: it edges round the wall towards the gate rather than sticking there
		var gate := float(fold.get_meta("gate"))
		var a2 := a + clampf(wrapf(gate - a, -PI, PI), -0.006, 0.006)
		var out := Vector2(cos(a2), sin(a2)) * (r + 0.9)
		return Vector3(c.x + out.x, q.y, c.z + out.y)
	return q


func pen_fluff(i: int) -> void:
	if is_penned(i):
		return
	Portals.note_found(world_id, "fluff_%d" % (i + 1))
	var f := fluffkin(i)
	if f:
		Fx.burst(self, f.global_position + Vector3(0, 1.0, 0), Color(1, 1, 1), 14, 0.08, 2.5, -1.0, 0.8)
		var fold := _fold()
		if fold:
			_fluffs[i][1] = fold.global_position
	Audio.play("boing", -6.0)
	var n := penned()
	if n < FLUFFS:
		Game.message("A Fluffkin's in! (%d of %d)" % [n, FLUFFS])
	else:
		var fold := _fold()
		ring_bell(0, fold.global_position if fold else Vector3.ZERO)


# Heather's garden ---------------------------------------------------------------------------------------------------
func is_held(i: int) -> bool:
	return has_bell(1) or Portals.has_found(world_id, "bed_%d" % (i + 1))


func held() -> int:
	var n := 0
	for i in BEDS:
		if is_held(i):
			n += 1
	return n


func is_moonflower(i: int) -> bool:
	# The shared garden: Heather's sunflowers (1, 3, 5) and the Moonfolk's moonflowers (2, 4) side by side
	return i % 2 == 1


func grow_phase(i: int) -> float:
	# How open a flower is: a shut bud (0) opening up to full bloom (BLOOM_FROM to BLOOM_TO). Sunflowers open in the
	# daylight and moonflowers in the dark, so the flux opens and shuts them. Held: always open.
	if is_held(i):
		return 0.65
	var light := 1.0 - daylight() if is_moonflower(i) else daylight()
	if light < OPEN_FROM:
		return light / OPEN_FROM * BLOOM_FROM * 0.98
	return lerpf(BLOOM_FROM, BLOOM_TO - 0.01, (light - OPEN_FROM) / (1.0 - OPEN_FROM))


func in_bloom(i: int) -> bool:
	var p := grow_phase(i)
	return p >= BLOOM_FROM and p < BLOOM_TO


func _add_garden() -> void:
	_plants = []
	for i in BEDS:
		var m := get_node_or_null("Bed%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var p := plant_model(i)
		p.name = "Plant"
		m.add_child(p)
		_plants.append(p)
		if has_meta("preview"):
			continue
		var spot := USE_SPOT.make(Vector3.ZERO, _bed_offer.bind(i), tend.bind(i), 1.6, 1.8)
		spot.name = "Spot"
		m.add_child(spot)
	_show_plants()


func _bed_offer(i: int) -> String:
	if is_held(i):
		return ""
	return "sing to the plant"


func tend(i: int) -> bool:
	# Sing to a plant: in full bloom, it stays that way for good. Any other time it's too early or too late.
	if is_held(i):
		return false
	var p := grow_phase(i)
	var m := get_node_or_null("Bed%d" % (i + 1)) as Node3D
	if not in_bloom(i):
		Juice.blip("tick", 0.7, -8.0)
		Game.message("Shut! Moonflowers open at night." if is_moonflower(i)
			else "Shut! Sunflowers open in the day.")
		return false
	Portals.note_found(world_id, "bed_%d" % (i + 1))
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.2, 0), BLOSSOM, 22, 0.08, 3.0, -1.0, 0.9)
	Juice.blip("chime", 1.0 + held() * 0.12, -4.0)
	_show_plants()
	var n := held()
	if n < BEDS:
		Game.message("The %s stays open! (%d of %d)" % ["moonflower" if is_moonflower(i) else "sunflower", n, BEDS])
	else:
		ring_bell(1, m.global_position if m else Vector3.ZERO)
	return true


func _show_plants() -> void:
	for i in _plants.size():
		var p := _plants[i] as Node3D
		if is_instance_valid(p):
			set_plant(p, grow_phase(i))


# Isla, and the hill race --------------------------------------------------------------------------------------------
func _add_isla() -> void:
	var m := get_node_or_null("Isla") as Node3D
	if m == null:
		return
	_isla = Node3D.new()
	_isla.name = "Isla Runner"
	add_child(_isla)
	_isla.global_transform = m.global_transform
	var model := isla_model()
	_isla.add_child(model)
	var spot := USE_SPOT.make(Vector3.ZERO, _isla_offer, _use_isla, 2.4, 2.4)
	spot.name = "Spot"
	_isla.add_child(spot)


func _isla_offer() -> String:
	if racing:
		return ""
	if Portals.has_found(world_id, "met_isla") and not has_bell(2):
		return "race Isla up Ben Bonnie"
	return "talk to Isla"


func _use_isla() -> void:
	if racing:
		return
	if Portals.has_found(world_id, "met_isla") and not has_bell(2):
		start_race()
		return
	var spot := _isla.get_node_or_null("Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Isla", isla_lines().map(func(l: String) -> String: return Settings.fill(l)), "glenmoor_isla")


func isla_lines() -> Array:
	# Isla's from up the glen: bouncy, cheeky, a wee bit competitive, and a night owl who leads the Moonfolk
	# (a first draft for Hayden)
	if not Portals.has_found(world_id, "met_isla"):
		Portals.note_found(world_id, "met_isla")
		return ["Och, hiya! I'm Isla, Heather's best friend!",
			"Well. We were. The glen's split in two.",
			"Want the Moon Charm? Race me up past the cairns!",
			"Ben Bonnie's the top. Ready?"]
	if is_mended():
		return [["Proper days AND nights! Cartwheels!"],
			["Me and Heather had a sunset picnic!"],
			["We teach them stars. They teach us jam."],
			["Rematch up the hill some time?"]].pick_random()
	if has_bell(2):
		return ["You're FAST!",
			"The Moon Charm's yours!"]
	return ["Another go? Past the cairns to the top!", "On your marks..."]


func start_race() -> void:
	if racing or _race_line == null:
		return
	racing = true
	race_go = false
	race_next = 0
	_isla_d = 0.0
	_isla_done = false
	_countdown = COUNTDOWN
	var start := get_node_or_null("RaceStart") as Node3D
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and start:
		player.global_position = start.global_position + Vector3(-1.2, 0.9, 0.8)
		player.velocity = Vector3.ZERO
		Game.hold_controls(&"hill_race", true, player)
	if _isla:
		_isla.global_position = _race_line.to_global(_race_line.curve.sample_baked(0.0))
	_show_race()
	Juice.blip("tick", 1.0, -4.0)


func _race_step(player: Node3D, delta: float) -> void:
	if not racing:
		return
	if not race_go:
		var was := int(ceil(_countdown))
		_countdown -= delta
		if int(ceil(_countdown)) != was and _countdown > 0.0:
			Juice.blip("tick", 1.0, -4.0)
		if _countdown <= 0.0:
			race_go = true
			if player:
				Game.hold_controls(&"hill_race", false, player)
			Juice.blip("chime", 1.2, -3.0)
		_show_race()
		return
	# Isla runs her line
	var length := _race_line.curve.get_baked_length()
	if not _isla_done:
		_isla_d = minf(_isla_d + ISLA_SPEED * delta, length)
		var at := _race_line.to_global(_race_line.curve.sample_baked(_isla_d))
		var ahead := _race_line.to_global(_race_line.curve.sample_baked(minf(_isla_d + 0.5, length)))
		_isla.global_position = at
		if ahead.distance_to(at) > 0.01:
			_isla.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
		if _isla_d >= length - 0.05:
			_isla_done = true
			end_race(false)
			return
	# You: the next cairn, in order
	if player:
		var c := get_node_or_null("Cairn%d" % (race_next + 1)) as Node3D
		if c and Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length() < CAIRN_REACH \
				and absf(player.global_position.y - c.global_position.y) < 3.0:
			reach_cairn()
		elif player.global_position.distance_to((get_node("Hill") as Node3D).global_position) > 60.0:
			end_race(false, "Off the course! Try again.")
	_show_race()


func cairns() -> int:
	var n := 0
	while get_node_or_null("Cairn%d" % (n + 1)) != null:
		n += 1
	return n


func reach_cairn() -> void:
	if not racing or not race_go:
		return
	race_next += 1
	Juice.blip("chime", 1.0 + race_next * 0.1, -6.0)
	if race_next >= cairns():
		end_race(true)


func end_race(won: bool, why := "") -> void:
	racing = false
	race_go = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		Game.hold_controls(&"hill_race", false, player)
	if won:
		var top := get_node_or_null("Cairn%d" % cairns()) as Node3D
		if not has_bell(2):
			Game.message("You beat Isla! \"Och, like the wind!\"")
			ring_bell(2, top.global_position if top else Vector3.ZERO)
		else:
			Game.message("You beat Isla to the top again!")
	else:
		Game.message(why if why != "" else "Isla wins! \"Ha! Again?\"")
	_show_race()
	# Isla jogs back down to the start after a moment
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_isla) and not racing:
			var m := get_node_or_null("Isla") as Node3D
			if m:
				_isla.global_transform = m.global_transform)


func isla_progress() -> float:
	return _isla_d


func _show_race() -> void:
	if _race_label == null:
		return
	var box := _race_label.get_parent() as Control
	box.visible = racing
	if not racing:
		return
	if not race_go:
		_race_label.text = "Race up Ben Bonnie!  %d..." % int(ceil(_countdown))
		return
	var total := cairns()
	var mine := race_next / float(total)
	var hers := _isla_d / maxf(_race_line.curve.get_baked_length(), 1.0)
	_race_label.text = "Cairns %d / %d   ·   Isla's %s" % [race_next, total, "behind you!" if mine >= hers else "ahead!"]


# The Sunfolk and the Moonfolk ---------------------------------------------------------------------------------------
func _add_camps() -> void:
	# Two little camps across the glen from each other, each with its banner and three folk. Mended, they make peace:
	# the two banners come down and one that's half sun, half moon goes up between them (_make_peace()).
	_sunfolk = _camp("Sunfolk", SUN_CAMP, SUNFOLK, false)
	_moonfolk = _camp("Moonfolk", MOON_CAMP, MOONFOLK, true)
	if is_mended():
		_make_peace()


func _camp(camp: String, at: Vector3, folk: Array, moon: bool) -> Array:
	var g := Node3D.new()
	g.name = camp
	add_child(g)
	g.position = _ground(at)
	var face := (_ground((SUN_CAMP + MOON_CAMP) / 2.0) - g.position)
	var banner := banner_model(moon)
	banner.name = "Banner"
	g.add_child(banner)
	banner.rotation.y = 0.0                                  # (its flag faces the way in, so you see it coming)
	var out: Array = []
	for i in folk.size():
		var who: Dictionary = folk[i]
		var a := (i - 1) * 0.9 + atan2(face.x, face.z)
		var spot := g.position + Vector3(sin(a), 0, cos(a)) * 3.2
		var p := Node3D.new()
		p.name = str(who.name)
		add_child(p)
		p.position = _ground(spot)
		p.rotation.y = atan2(face.x, face.z)
		p.add_child(folk_model(who))
		var talk := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to %s" % who.name, _talk_folk.bind(p, moon, i), 2.0, 2.2)
		talk.name = "Spot"
		p.add_child(talk)
		out.append(p)
	return out


func _ground(at: Vector3) -> Vector3:
	# The ground under a spot (the glen rolls a little)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 30.0, at.z), Vector3(at.x, -10.0, at.z))
		var hit := space.intersect_ray(q)
		if hit:
			return hit.position
	return Vector3(at.x, 0.0, at.z)


func folk_lines(moon: bool, i: int) -> Array:
	# The two sides' talk: cross with each other before it's mended, friends after (first drafts for Hayden)
	if is_mended():
		return ([["The Sunfolk fell asleep at our feast!"],
			["I swapped star names for honey!"],
			["Night's no fun without a day!"]] if moon else
			[["I saw shooting stars past my bedtime!"],
			["Day's lovely. Night is too, now!"],
			["Our banner's half sun, half moon!"]])[i % 3]
	if moon:
		return [["Night's the best! Stars! Owls!",
			"And then the sun barges in. RUDE."],
			["Shh. I'm watchin' for shootin' stars."],
			["The Sunfolk shout HOORAY every sunrise!"]][i % 3]
	return [["Day's the best! Sunshine! Fluffkins!",
		"And then the night sneaks back. Again!"],
		["I'm Barley. You can't make hay in the dark!"],
		["The Moonfolk cheer. We cheer LOUDER."]][i % 3]


func _talk_folk(p: Node3D, moon: bool, i: int) -> void:
	var spot := p.get_node_or_null("Spot") as Node3D
	if spot:
		Dialogue.say(spot, str(p.name), folk_lines(moon, i), "glenmoor_folk")


func _cheer(day: bool) -> void:
	# Whose time it is cheers, and the other side grumbles (a shout over their heads for a moment)
	if is_mended():
		return
	var happy: Array = _sunfolk if day else _moonfolk
	var cross: Array = _moonfolk if day else _sunfolk
	if not happy.is_empty():
		_shout(happy.pick_random(), ["HOORAY, DAY!", "Sunshine!", "Good mornin'!"].pick_random() if day
			else ["HOORAY, NIGHT!", "Stars!", "Bonnie night!"].pick_random(), SUN_GOLD if day else MOON_BLUE)
	if not cross.is_empty() and randf() < 0.6:
		_shout(cross.pick_random(), ["Boo!", "Not AGAIN!", "Och, away!", "Hmph!"].pick_random(), Color(0.9, 0.9, 0.95))


func _shout(p: Node3D, text: String, colour: Color) -> void:
	if not is_instance_valid(p):
		return
	var old := p.get_node_or_null("Shout")
	if old:
		old.free()
	var l := Label3D.new()
	l.name = "Shout"
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = colour
	l.position.y = 2.3
	p.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", 2.8, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)


func _make_peace() -> void:
	# Both banners come down and one half-and-half banner goes up between the camps; everyone turns to face it
	for camp in ["Sunfolk", "Moonfolk"]:
		var b := get_node_or_null("%s/Banner" % camp) as Node3D
		if b:
			b.visible = false
	if get_node_or_null("Peace Banner") == null:
		var p := peace_banner_model()
		p.name = "Peace Banner"
		add_child(p)
		p.position = _ground(PEACE_AT)
	# Everyone gathers round it, Sunfolk and Moonfolk side by side
	var all: Array = []
	for i in maxi(_sunfolk.size(), _moonfolk.size()):
		if i < _sunfolk.size():
			all.append(_sunfolk[i])
		if i < _moonfolk.size():
			all.append(_moonfolk[i])
	for i in all.size():
		var f := all[i] as Node3D
		if not is_instance_valid(f):
			continue
		var shout := f.get_node_or_null("Shout")
		if shout:
			shout.free()
		var a := PI * 0.15 + i * TAU / (all.size() + 1)        # (a gap in the ring on the path side)
		f.position = _ground(PEACE_AT + Vector3(sin(a), 0, cos(a)) * 3.4)
		f.rotation.y = a + PI


# Heather ------------------------------------------------------------------------------------------------------------
func _add_heather() -> void:
	var m := get_node_or_null("Heather") as Node3D
	if m == null:
		return
	var packed := load("res://models/characters/cattle_girl.glb") as PackedScene
	if packed:
		var p := packed.instantiate() as Node3D
		p.name = "Model"
		m.add_child(p)
		_heather_anim = p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _heather_anim and _heather_anim.has_animation("idle"):
			_heather_anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			_heather_anim.play("idle")
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Heather", _talk_heather, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func heather_lines() -> Array:
	# Heather's the farm girl from the lowlands of Glenmoor: warm, stubborn and Southern ("sugar", "y'all"). She loves
	# a sunny day, so the Sunfolk look to her. A first draft for Hayden.
	if is_mended() and not Portals.has_found(world_id, "thanked"):
		Portals.note_found(world_id, "thanked")
		return thank_lines()
	if is_mended():
		return [["A real day, then a real night. Nice and slow!",
			"Me and Isla are friends again!"],
			["April Showers: {showers_how}. Walk on the rainbow!"],
			["Spring Step: jump as you land. Boing!"],
			["No sunrise without a night first!"]].pick_random()
	if not Portals.has_found(world_id, "met_heather"):
		Portals.note_found(world_id, "met_heather")
		return ["Welcome to Glenmoor, sugar! Look: day, night, day again!",
			"The Stormram's spinnin' it all. Sunfolk and Moonfolk are fightin'!",
			"Three charms make the Balance Charm. Stars on your map!"]
	var left: Array = []
	for i in 3:
		if not has_bell(i):
			left.append(["herd the Fluffkins (%d of %d)" % [penned(), FLUFFS],
				"sing to the flowers (%d of %d)" % [held(), BEDS],
				"race Isla"][i])
	if left.size() > 0:
		return ["%s The days are steadyin'!" % ("Two charms!" if left.size() == 1 else "One charm!")
			if left.size() < 3 else "Still to do: %s." % "; and ".join(left)]
	return ["The charm's whole! The Stormram's wakin' up...",
		"Dodge his whirlwind! Jump his gusts!",
		"Pop him when he's dizzy!"]


func thank_lines() -> Array:
	return ["You did it! Day and night take turns again!",
		"Sunfolk and Moonfolk are friends again!",
		"And spring can come to Earth now!",
		"Two gifts for you!",
		"April Showers: {showers_how}. Walk on the rainbow!",
		"Spring Step: jump as you land. Boing!",
		"Thank you, sugar!"]


func _talk_heather() -> void:
	var spot := get_node_or_null("Heather/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Heather", heather_lines().map(func(l: String) -> String: return Settings.fill(l)), "glenmoor_heather")


# The Stormram -------------------------------------------------------------------------------------------------------
func _add_stormram() -> void:
	var m := get_node_or_null("Stormram") as Node3D
	if m == null:
		return
	var s := (load(CROC) as PackedScene).instantiate() as CharacterBody3D
	s.set_script(STORMRAM)
	s.name = "The Stormram"                              # not "Crocodillo …", so finding Crocodillos by name skips it
	s.set("asleep", true)
	s.set("world", self)
	s.set("size", 2.2)
	s.set("stomps_to_defeat", 13)
	s.set("damage", 2)
	s.set("xp_reward", 60)
	s.set("wander_radius", 5.0)
	s.set("sight_range", 18.0)
	s.set("leash_range", 30.0)
	s.set("stalk_speed", 2.4)
	s.set("roll_speed", 10.0)
	s.set("roll_time", 1.3)
	s.set("dizzy_time", 3.8)
	s.set("roll_cooldown", 2.2)
	s.position = m.position
	add_child(s)
	stormram = s


func wake_stormram() -> void:
	if stormram and is_instance_valid(stormram) and stormram.get("asleep"):
		stormram.call("wake")


func mend() -> void:
	# The Stormram's popped: day and night ease into a normal, steady day (a fresh spring morning), the two sides
	# make peace, and blossom bursts out on the rowans
	Portals.clear(world_id)
	racing = false
	_flux = 1.0
	var to := 0.85 if day_k <= 0.85 else 1.85
	var tw := create_tween()
	tw.tween_method(set_daylight, day_k, to, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_show_sky)
	for t in get_children():
		if str(t.name).begins_with("Rowan"):
			Fx.burst(self, (t as Node3D).global_position + Vector3(0, 4.5, 0), BLOSSOM, 16, 0.08, 3.0, -1.0, 1.4)
	_make_peace()
	_show_plants()
	_show_sky()
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	Juice.blip("chime", 0.8, -3.0)
	get_tree().create_timer(TEACH_AFTER).timeout.connect(_thank)


func _thank(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:
		get_tree().create_timer(1.0).timeout.connect(_thank.bind(tries + 1))
		return
	var spot := get_node_or_null("Heather/Spot") as Node3D
	if spot and not Portals.has_found(world_id, "thanked"):
		Portals.note_found(world_id, "thanked")
		Dialogue.say(spot, "Heather", thank_lines().map(func(l: String) -> String: return Settings.fill(l)), "glenmoor_thanks")


# The HUD: day or night, and the race ------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Glen HUD"
	_hud.layer = 5
	add_child(_hud)
	var box := PanelContainer.new()
	box.name = "Sky"
	box.add_theme_stylebox_override("panel", UiStyle.card(Color(0.15, 0.22, 0.18, 0.85)))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(280, 0)
	box.position = Vector2(-140, 64)
	_sky_label = Label.new()
	_sky_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sky_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_sky_label)
	_hud.add_child(box)
	var race := PanelContainer.new()
	race.name = "Race"
	race.add_theme_stylebox_override("panel", UiStyle.card(Color(0.3, 0.15, 0.2, 0.85)))
	race.set_anchors_preset(Control.PRESET_CENTER_TOP)
	race.custom_minimum_size = Vector2(360, 0)
	race.position = Vector2(-180, 110)
	_race_label = Label.new()
	_race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_race_label.add_theme_font_size_override("font_size", 22)
	race.add_child(_race_label)
	race.visible = false
	_hud.add_child(race)


func sky_words() -> String:
	if is_mended():
		return "%s  (a normal day again!)" % time_words()
	return "%s  · the flux!  (%d of 3 charms)" % [time_words(), bells()]


func _show_sky() -> void:
	if _sky_label == null:
		return
	_sky_label.text = sky_words()
	var box := _sky_label.get_parent() as Control
	box.position.x = box.get_parent_area_size().x / 2.0 - box.size.x / 2.0 if box.get_parent_area_size().x > 0 else box.position.x
	var race := _race_label.get_parent() as Control
	race.position.x = race.get_parent_area_size().x / 2.0 - race.size.x / 2.0 if race.get_parent_area_size().x > 0 else race.position.x


# Every frame ---------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_loop(delta)
	_show_plants()
	if has_meta("preview"):
		for i in _fluffs.size():                            # (the Fluffkins graze about in the preview too)
			var body := (_fluffs[i][0] as Node3D).get_node_or_null("Body") as Node3D
			if body:
				body.position.y = 0.5 + absf(sin(_t * 2.0 + i)) * 0.03
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not get_tree().paused:
		fluff_step(player, delta)
		_race_step(player, delta)
	var m := get_node_or_null("Stormram") as Node3D
	if player and not is_mended() and bells() == 3 and m and player.global_position.distance_to(m.global_position) < WAKE_NEAR:
		wake_stormram()
	_show_sky()


# Looks ---------------------------------------------------------------------------------------------------------------
static func _ball(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func _mat(colour: Color, emit := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = Color(colour.r, colour.g, colour.b)
		m.emission_energy_multiplier = emit
	return m


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, seg := 8) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func fluffkin_model(k: int) -> Node3D:
	# A Fluffkin: a fluffy little highland calf, a round ball of shaggy wool (cream, ginger or toffee) on four stubby
	# legs, with a long fringe over its eyes, two tiny curved horns and a pink nose
	var g := Node3D.new()
	var wools := [Color(0.98, 0.94, 0.86), Color(0.95, 0.6, 0.3), Color(0.8, 0.55, 0.35), Color(0.98, 0.9, 0.78), Color(0.9, 0.5, 0.25)]
	var wool := _mat(wools[k % wools.size()], 0.0, 1.0)
	var dark := _mat(Color(0.25, 0.18, 0.15))
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 0.5
	g.add_child(body)
	_put(body, _ball(0.5), wool, Vector3.ZERO, Vector3(1.0, 0.85, 1.15))
	for k2 in 6:                                         # shaggy tufts
		var a := k2 * TAU / 6.0
		_put(body, _ball(0.2, 8), wool, Vector3(cos(a) * 0.38, 0.22 + 0.05 * (k2 % 2), sin(a) * 0.42))
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.12, 0.5)
	body.add_child(head)
	_put(head, _ball(0.26), wool, Vector3.ZERO)
	_put(head, _ball(0.13), _mat(Color(1.0, 0.72, 0.72)), Vector3(0, -0.08, 0.2), Vector3(1.3, 0.8, 0.8))
	for s in [-1.0, 1.0]:
		_put(head, _ball(0.035, 6), dark, Vector3(s * 0.06, -0.06, 0.3))
		_put(head, _cyl(0.0, 0.05, 0.2, 6), _mat(Color(0.95, 0.9, 0.8)), Vector3(s * 0.2, 0.18, 0.0), Vector3.ONE, Vector3(0, 0, -s * 0.9))
		_put(head, _ball(0.07, 6), wool, Vector3(s * 0.26, 0.05, -0.02), Vector3(1.4, 0.5, 0.8))      # floppy ears
	_put(head, _ball(0.2), wool, Vector3(0, 0.12, 0.12), Vector3(1.3, 0.6, 0.9))                    # the fringe over its eyes
	for s in [-1.0, 1.0]:
		for f in [-1.0, 1.0]:
			_put(g, _cyl(0.07, 0.07, 0.4, 6), dark, Vector3(s * 0.25, 0.2, f * 0.3))
	_put(body, _ball(0.08, 6), wool, Vector3(0, 0.1, -0.58))                                      # a little tail tuft
	return g


static func plant_model(k: int) -> Node3D:
	# One of Heather's plants: a stem with two leaves and a big round bloom (colours by bed), which set_plant() grows,
	# opens and wilts
	var g := Node3D.new()
	# Sunflowers on the even beds (gold and orange), moonflowers on the odd ones (pale silver and lilac, glowing)
	var blooms := [Color(1.0, 0.82, 0.25), Color(0.85, 0.9, 1.0), Color(1.0, 0.6, 0.25), Color(0.8, 0.72, 1.0), Color(1.0, 0.9, 0.35)]
	var stem := Node3D.new()
	stem.name = "Stem"
	g.add_child(stem)
	var green := _mat(Color(0.35, 0.65, 0.3))
	green.resource_name = "Stem Green"
	_put(stem, _cyl(0.04, 0.05, 1.0, 6), green, Vector3(0, 0.5, 0)).name = "Stalk"
	for s in [-1.0, 1.0]:
		_put(stem, _ball(0.16, 8), green, Vector3(s * 0.15, 0.4, 0), Vector3(1.6, 0.25, 0.8), Vector3(0, 0, s * 0.4)).name = "Leaf"
	var flower := Node3D.new()
	flower.name = "Bloom"
	flower.position.y = 1.05
	stem.add_child(flower)
	var petal := _mat(blooms[k % blooms.size()], 0.15 if k % 2 == 0 else 0.6, 0.6)
	petal.resource_name = "Petal"
	for p in 6:
		var a := p * TAU / 6.0
		_put(flower, _ball(0.12, 8), petal, Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), Vector3(1.0, 0.45, 1.0))
	_put(flower, _ball(0.09, 8), _mat(Color(1.0, 0.9, 0.4), 0.3), Vector3(0, 0.03, 0))
	g.set_meta("petal", blooms[k % blooms.size()])
	return g


static func set_plant(p: Node3D, phase: float) -> void:
	# 0 to BLOOM_FROM: a sprout growing tall; bloom: wide open; after BLOOM_TO: wilting, drooping and browning
	var stem := p.get_node("Stem") as Node3D
	var flower := stem.get_node("Bloom") as Node3D
	var grow := clampf(phase / BLOOM_FROM, 0.12, 1.0)
	var wilt := clampf((phase - BLOOM_TO) / (1.0 - BLOOM_TO), 0.0, 1.0)
	stem.scale = Vector3(1, grow * (1.0 - wilt * 0.35), 1)
	stem.rotation.z = wilt * 0.9
	var open := 0.15 if phase < BLOOM_FROM * 0.7 else (1.0 if phase < BLOOM_TO else 1.0 - wilt * 0.5)
	if phase >= BLOOM_FROM * 0.7 and phase < BLOOM_FROM:
		open = lerpf(0.15, 1.0, (phase - BLOOM_FROM * 0.7) / (BLOOM_FROM * 0.3))
	flower.scale = Vector3.ONE * open / maxf(grow, 0.12)
	var c: Color = p.get_meta("petal")
	for mi in flower.get_children():
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m and m.resource_name == "Petal":
			m.albedo_color = c.lerp(Color(0.45, 0.32, 0.2), wilt)
			m.emission_energy_multiplier = (0.15 if c.b < 0.6 else 0.6) * (1.0 - wilt)
	var leaf := (stem.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	if leaf:
		leaf.albedo_color = Color(0.35, 0.65, 0.3).lerp(Color(0.55, 0.45, 0.25), wilt)


static func isla_model() -> Node3D:
	# Isla, Heather's best friend: made like the townsfolk (scripts/townsfolk.gd) from the cow body Heather's model
	# shares, in shaggy highland ginger with a tartan scarf (a working look: no drawing of her yet)
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = "Model"
	p.set("look", {"body": "cow", "colors": {"fur": 10, "hair": 9, "eyes": 14, "accent": 9, "top": 14, "bottoms": 5, "shoes": 4},
		"extras": true, "height": 0.95})
	p.set("extras", [{"kind": "scarf", "color": Color(0.75, 0.2, 0.25)}])
	return p


static func folk_model(who: Dictionary) -> Node3D:
	# One of the Sunfolk or Moonfolk: made like the townsfolk from a hero body, in their side's colours, with a scarf
	var p := (load("res://scripts/townsfolk.gd") as GDScript).new() as Node3D
	p.name = "Model"
	p.set("look", {"body": who.body, "colors": who.colors, "extras": true, "height": 0.9})
	var cols: Dictionary = who.colors
	var hero := load("res://scripts/hero.gd") as GDScript
	var swatches: Array = hero.get("SWATCHES") if hero else []
	var scarf: Color = swatches[(int(cols.accent) - 1) % swatches.size()] if not swatches.is_empty() else Color.WHITE
	p.set("extras", [{"kind": "scarf", "color": scarf}])
	return p


static func banner_model(moon: bool) -> Node3D:
	# A camp's banner on a tall pole: the Sunfolk's gold with a sun, the Moonfolk's deep blue with a crescent moon
	var g := Node3D.new()
	var wood := _mat(Color(0.45, 0.32, 0.22))
	_put(g, _cyl(0.07, 0.08, 4.2, 8), wood, Vector3(0, 2.1, 0))
	_put(g, _ball(0.14, 8), _mat(SUN_GOLD if not moon else Color(0.85, 0.88, 1.0), 0.5), Vector3(0, 4.25, 0))
	var cloth := _mat(Color(1.0, 0.75, 0.3) if not moon else Color(0.16, 0.18, 0.42), 0.0, 0.9)
	var flag := BoxMesh.new()
	flag.size = Vector3(1.5, 1.1, 0.05)
	_put(g, flag, cloth, Vector3(0.8, 3.4, 0)).name = "Flag"
	if moon:
		var glow := _mat(Color(0.9, 0.92, 1.0), 0.8)
		_put(g, _cyl(0.32, 0.32, 0.06, 16), glow, Vector3(0.8, 3.4, 0.05), Vector3.ONE, Vector3(PI / 2, 0, 0))
		_put(g, _cyl(0.27, 0.27, 0.06, 16), cloth, Vector3(0.92, 3.47, 0.07), Vector3.ONE, Vector3(PI / 2, 0, 0))   # bites the crescent
		for k in 3:
			_put(g, _ball(0.05, 6), glow, Vector3(0.3 + k * 0.45, 3.85 - (k % 2) * 0.75, 0.06))
	else:
		var sun := _mat(Color(1.0, 0.95, 0.5), 0.6)
		_put(g, _cyl(0.25, 0.25, 0.06, 16), sun, Vector3(0.8, 3.4, 0.05), Vector3.ONE, Vector3(PI / 2, 0, 0))
		for k in 8:
			var a := k * TAU / 8.0
			var ray := BoxMesh.new()
			ray.size = Vector3(0.06, 0.16, 0.04)
			_put(g, ray, sun, Vector3(0.8 + cos(a) * 0.38, 3.4 + sin(a) * 0.38, 0.06), Vector3.ONE, Vector3(0, 0, a - PI / 2))
	return g


static func peace_banner_model() -> Node3D:
	# Peace between the two sides: one banner, a yin and yang of sun gold and night blue, each with a dot of the other
	var g := Node3D.new()
	var wood := _mat(Color(0.45, 0.32, 0.22))
	_put(g, _cyl(0.08, 0.09, 4.6, 8), wood, Vector3(0, 2.3, 0))
	var gold := _mat(Color(1.0, 0.8, 0.35), 0.3)
	var night := _mat(Color(0.16, 0.18, 0.42), 0.2)
	night.cull_mode = BaseMaterial3D.CULL_DISABLED
	var at := Vector3(0, 3.6, 0.1)
	var disc := func(r: float, m: Material, off: Vector3) -> void:
		_put(g, _cyl(r, r, 0.05, 32), m, at + off, Vector3.ONE, Vector3(PI / 2, 0, 0))
	# Two halves (a gold disc with a night half laid over it), the two small round heads of the swirl, then the dots
	_put(g, _cyl(0.85, 0.85, 0.05, 32), gold, at, Vector3.ONE, Vector3(PI / 2, 0, 0))
	var h := MeshInstance3D.new()
	h.name = "Night Half"
	h.mesh = _half_disc(0.85)
	h.material_override = night
	h.position = at + Vector3(0, 0, 0.03)
	g.add_child(h)
	disc.call(0.425, gold, Vector3(0, 0.425, 0.03))
	disc.call(0.425, night, Vector3(0, -0.425, 0.03))
	disc.call(0.12, night, Vector3(0, 0.425, 0.04))
	disc.call(0.12, gold, Vector3(0, -0.425, 0.04))
	_put(g, _cyl(0.92, 0.92, 0.04, 32), _mat(Color(0.95, 0.95, 0.98)), at - Vector3(0, 0, 0.02), Vector3.ONE, Vector3(PI / 2, 0, 0))
	return g


static func _half_disc(r: float, seg := 24) -> ArrayMesh:
	# The right half of a flat disc facing +Z (for the peace banner's yin and yang)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in seg:
		var a0 := -PI / 2.0 + PI * k / seg
		var a1 := -PI / 2.0 + PI * (k + 1) / seg
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1), sin(a1), 0) * r)
		st.add_vertex(Vector3(cos(a0), sin(a0), 0) * r)
	return st.commit()
