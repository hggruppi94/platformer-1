extends "res://scripts/portal_world.gd"

# Glenmoor, Heather's home world (plan item 19a world 6; scene built by tools/build_glenmoor.gd). Misty highland hills,
# purple heather, dry stone walls and fluffy highland critters: home of Heather the cattle girl and her best friend
# Isla. (Heather's from the farm in Glenmoor's lowlands and Isla from up the glen: one Southern, one Scottish, the
# story's two Highland cattle girl best friends.)
#
# The time problem: the Stormram's whirlwind (scripts/stormram.gd) has set the seasons SPINNING. Spring, summer,
# autumn and winter come round every few seconds (the grass, the rowan trees, the snow on the hills and the light all
# turn with them, and a card at the top says which season it is), so crops grow and wilt before anyone can pick them.
# Each Spring Bell rung slows the spin a little. Three Spring Bells settle it:
#   bell 1  the Fold: herd the five Fluffkins (fluffy highland calves) into the stone pen. They trot away from you, so
#           walk round behind one to send it where you want; they only go in through the gate.
#   bell 2  Heather's garden: her five plants grow, bloom and wilt round and round. Catch each one in full bloom and
#           sing it still (Interact): a healing-and-growing game.
#   bell 3  the hill race: race Isla up Ben Bonnie, past the six cairns in order, to the summit cairn first.
# With all three rung, the Stormram wakes on the Standing Stones when you come near. Popping it mends the world
# (Portals.clear, which also opens spring on Earth): the seasons settle on spring for good, and blossom comes out.
# Heather's reward (her grow ability) is slice two.

const STORMRAM := preload("res://scripts/stormram.gd")
const CROC := "res://scenes/enemies/crocodillo.tscn"
const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_WORDS := ["🌸 Spring", "☀ Summer", "🍂 Autumn", "❄ Winter"]
const SPIN := [4.0, 6.0, 9.0, 14.0]          # seconds a season lasts, by how many bells are rung (each one slows it)
const FLUFFS := 5
const FLEE_NEAR := 5.0                       # a Fluffkin trots away from you inside this...
const FLEE_SPEED := 3.6                      # ...this fast (you run at 5, so you can always get round behind)
const GRAZE_SPEED := 0.6
const ROAM_R := 44.0                         # they stay inside this (the fence is at 48.6)
const BEDS := 5
const GROW_CYCLE := 8.0                      # seconds for a plant to sprout, grow, bloom and wilt
const BLOOM_FROM := 0.5                      # full bloom is this part of the cycle...
const BLOOM_TO := 0.85                       # ...to this (2.8 seconds: plenty of time to sing to it)
const CAIRN_REACH := 3.2
const ISLA_SPEED := 4.0                      # Isla runs up a bit slower than you (and stops for breath at the top)
const COUNTDOWN := 3.0
const WAKE_NEAR := 18.0
const TEACH_AFTER := 3.0
const BELL_GOLD := Color(1.0, 0.82, 0.35)
const BLOSSOM := Color(1.0, 0.75, 0.85)

# Each season's look: the grass, the rowan leaves, the hills, the sky and the light
const LOOKS := [
	{"grass": Color(0.5, 0.78, 0.38), "leaves": Color(1.0, 0.78, 0.86), "hill": Color(0.45, 0.68, 0.38), "top": Color(0.5, 0.68, 0.9),
		"horizon": Color(0.9, 0.9, 0.92), "light": Color(1.0, 0.96, 0.88), "energy": 1.0, "fog": Color(0.72, 0.8, 0.86)},
	{"grass": Color(0.36, 0.66, 0.26), "leaves": Color(0.25, 0.55, 0.22), "hill": Color(0.35, 0.58, 0.28), "top": Color(0.35, 0.6, 0.95),
		"horizon": Color(0.95, 0.92, 0.82), "light": Color(1.0, 0.95, 0.8), "energy": 1.2, "fog": Color(0.78, 0.82, 0.8)},
	{"grass": Color(0.62, 0.58, 0.3), "leaves": Color(0.9, 0.42, 0.18), "hill": Color(0.58, 0.45, 0.3), "top": Color(0.55, 0.62, 0.78),
		"horizon": Color(0.95, 0.8, 0.65), "light": Color(1.0, 0.8, 0.6), "energy": 0.9, "fog": Color(0.8, 0.72, 0.64)},
	{"grass": Color(0.82, 0.85, 0.9), "leaves": Color(0.45, 0.38, 0.35), "hill": Color(0.78, 0.82, 0.88), "top": Color(0.62, 0.7, 0.82),
		"horizon": Color(0.9, 0.92, 0.96), "light": Color(0.9, 0.94, 1.0), "energy": 0.8, "fog": Color(0.8, 0.84, 0.9)},
]

var season_k := 0.0                          # 0..4 round the year (0 spring, 1 summer, 2 autumn, 3 winter)
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
var _season_label: Label
var _race_label: Label


func picture() -> void:
	# In the portal's preview: the seasons spinning over the glen, the Fluffkins out in the meadow and the garden
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
	_race_line = get_node_or_null("RaceLine") as Path3D
	_make_hud()
	if is_mended():
		season_k = 0.0
	else:
		_add_stormram()
	_show_season()
	if not is_mended() and bells() == 0 and not Portals.has_found(world_id, "met_heather"):
		Game.message.call_deferred("Glenmoor: whoa, the seasons are spinning! Blossom, sun, leaves, snow... Heather's waiting by the way in.")


func _soft_ground() -> void:
	# The glen's grass and Ben Bonnie's slopes are soil: Bramble's burrow digs into them and Heather's grow sprouts
	# from them (scripts/burrow.gd soil())
	for holder in ["Glen", "Ben Bonnie"]:
		var h := get_node_or_null(holder)
		if h:
			for b in h.find_children("*", "StaticBody3D", true, false):
				b.add_to_group("soil")


func is_mended() -> bool:
	return Portals.is_cleared(world_id)


# The spinning seasons ----------------------------------------------------------------------------------------------
func _own_looks() -> void:
	# Each copy of the world gets its own sky and its own seasonal materials
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = get_node_or_null("Sun") as DirectionalLight3D
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
	set_season(season_k)


func spin_len() -> float:
	return SPIN[bells()]


func season() -> String:
	return SEASONS[int(floor(season_k)) % 4]


func set_season(k: float) -> void:
	# Blends from one season's look to the next over the last fifth of each (so the turn is quick but not a snap)
	season_k = fposmod(k, 4.0)
	var i := int(floor(season_k)) % 4
	var f := clampf((season_k - floor(season_k) - 0.8) / 0.2, 0.0, 1.0)
	var a: Dictionary = LOOKS[i]
	var b: Dictionary = LOOKS[(i + 1) % 4]
	for key in [["Glen Grass", "grass"], ["Leaves", "leaves"], ["Hill Grass", "hill"]]:
		var m := _mats.get(key[0]) as StandardMaterial3D
		if m:
			m.albedo_color = (a[key[1]] as Color).lerp(b[key[1]], f)
	var snowy := i == 3 and f < 0.5 or i == 2 and f > 0.5
	for s in _snow:
		if is_instance_valid(s):
			(s as Node3D).visible = snowy
	if _sky:
		_sky.sky_top_color = (a.top as Color).lerp(b.top, f)
		_sky.sky_horizon_color = (a.horizon as Color).lerp(b.horizon, f)
		_sky.ground_horizon_color = _sky.sky_horizon_color
	if _env:
		_env.fog_light_color = (a.fog as Color).lerp(b.fog, f)
	if _sun:
		_sun.light_color = (a.light as Color).lerp(b.light, f)
		_sun.light_energy = lerpf(a.energy, b.energy, f)


func _spin(delta: float) -> void:
	if is_mended():
		return
	var was := int(floor(season_k))
	set_season(season_k + delta / spin_len())
	if int(floor(season_k)) != was:
		_show_season()
		if not has_meta("preview"):
			Juice.blip("whoosh", 1.3, -16.0)


# The Spring Bells --------------------------------------------------------------------------------------------------
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
	Fx.burst(self, at + Vector3(0, 1.5, 0), BELL_GOLD, 36, 0.1, 4.5, -1.0, 1.2)
	Juice.blip("chime", 0.9 + bells() * 0.15, -2.0)
	Juice.rumble(0.3, 0.2)
	var n := bells()
	var what: String = ["the Fold's Spring Bell", "the garden's Spring Bell", "the hill's Spring Bell"][i]
	Game.message(("You rang %s! (%d of 3) The seasons slow down a little..." % [what, n]) if n < 3
		else "That's all three Spring Bells! Over at the Standing Stones, something big and woolly lets out a grumpy BLEAT.")
	_show_season()


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
		var out := d.normalized() * (r + 0.9)
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
		Game.message("A Fluffkin trots into the Fold! (%d of %d) Moo-ve along, the rest of you!" % [n, FLUFFS])
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


func grow_phase(i: int) -> float:
	# 0 sprout, then growing, full bloom (BLOOM_FROM to BLOOM_TO), then wilting, and round again. Held: always in bloom.
	if is_held(i):
		return 0.65
	return fposmod(_t / GROW_CYCLE + i * 0.23, 1.0)


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
		Game.message("Not yet: it's only a sprout! Wait till it's in full bloom, then sing." if p < BLOOM_FROM
			else "Oh no, it's wilting already! It'll come round again. Catch it when it's in full bloom.")
		return false
	Portals.note_found(world_id, "bed_%d" % (i + 1))
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.2, 0), BLOSSOM, 22, 0.08, 3.0, -1.0, 0.9)
	Juice.blip("chime", 1.0 + held() * 0.12, -4.0)
	_show_plants()
	var n := held()
	if n < BEDS:
		Game.message("You sing, Heather hums along, and the plant stays in bloom! (%d of %d)" % [n, BEDS])
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
	# Isla's from up the glen: bouncy, cheeky and a wee bit competitive (a first draft for Hayden)
	if not Portals.has_found(world_id, "met_isla"):
		Portals.note_found(world_id, "met_isla")
		return ["Och, hiya! You must be Heather's pal from the Void. I'm Isla! Her best friend. Since we were wee calves.",
			"See that hill? That's Ben Bonnie. Every spring there's a race up it, and the winner rings the hill's Spring Bell.",
			"Only spring keeps whizzing past before anyone can start! Summer, autumn, winter, spring, summer...",
			"So we'll race right now. Past all six cairns, in order, up to the cairn on the top. Ready when you are!"]
	if is_mended():
		return [["Spring's stopped spinning! Spring's STAYING! I could do cartwheels. I am doing cartwheels. Look!",
			"(She does one cartwheel and falls over in the heather, giggling.)"],
			["Heather says your Earth has a whole spring all to itself, in turn with the other seasons. Fancy!",
			"Here we just had all four in a minute. Very tiring. Very."],
			["Rematch up Ben Bonnie some time? I've been practising. Mostly the falling over bit."]].pick_random()
	if has_bell(2):
		return ["You're FAST. I'm telling everyone. I'm telling the Fluffkins first.",
			"The hill's bell is rung! Heather's got the other two to sort out with you."]
	return ["Back for another go? Past the six cairns, in order, then the top!", "On your marks..."]


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
			end_race(false, "You ran off the course! Come and have another go.")
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
			Game.message("You beat Isla to the top of Ben Bonnie! Isla: \"Och, you're like the wind!\"")
			ring_bell(2, top.global_position if top else Vector3.ZERO)
		else:
			Game.message("You beat Isla to the top again!")
	else:
		Game.message(why if why != "" else "Isla gets to the top first! Isla: \"Ha! Best of three? Come back down and have another go!\"")
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
	# Heather's the farm girl from the lowlands of Glenmoor: warm, stubborn and Southern ("sugar", "y'all").
	# A first draft for Hayden.
	if is_mended() and not Portals.has_found(world_id, "thanked"):
		Portals.note_found(world_id, "thanked")
		return thank_lines()
	if is_mended():
		return [["Smell that? Blossom. Real, stay-put, spring blossom. I could cry. I might! Don't look.",
			"Thank you, sugar. You and Isla and them Fluffkins saved the whole glen."],
			["The Fluffkins have wandered out of the Fold again. That's how you know it's spring: they get frisky.",
			"Leave 'em be. They'll come home for supper."],
			["Remember your growin'! Stand on the grass and {grow_how}, and up you go on a big ol' flower.",
			"Try it on the hills here. Or by your garden back in the Void: your crops'll love it."],
			["My plants are just growin' now, nice and slow, like plants are meant to.",
			"Back home my mama always said: you can't hurry a seed. Turns out you can, with a big ol' whirlwind. You just shouldn't."]].pick_random()
	if not Portals.has_found(world_id, "met_heather"):
		Portals.note_found(world_id, "met_heather")
		return ["{player}! You came all the way to Glenmoor! Welcome to my home, sugar!",
			"Well... it's usually prettier than this. Hold your hat: here comes summer. And there it goes. Autumn. Brrr, winter!",
			"The Stormram's been at it again. He's a big woolly grump who curls up and charges in a WHIRLWIND, and he's got the seasons spinnin' round with him.",
			"My crops come up and wilt before I can blink, and spring hasn't stayed put in for ever.",
			"There's an old tale here: ring the three Spring Bells and spring comes back to stay. One's at the Fold, one's in my garden, one's on top of Ben Bonnie.",
			"Round up the Fluffkins into the Fold, help me catch my plants in bloom, and beat Isla up the hill. Y'all can do it!"]
	var left: Array = []
	for i in 3:
		if not has_bell(i):
			left.append(["herd the Fluffkins into the Fold (%d of %d in: walk round behind 'em, they trot away from you)" % [penned(), FLUFFS],
				"sing to my plants when they're in full bloom (%d of %d)" % [held(), BEDS], "beat Isla up Ben Bonnie"][i])
	if left.size() > 0:
		return ["%s Feel that? The seasons are slowin' down a touch." % ("Two bells rung!" if left.size() == 1 else "One bell rung!")
			if left.size() < 3 else "Every bell you ring slows the seasons a little. Ain't that somethin'?",
			"Still to do: %s." % "; and ".join(left)]
	return ["All three bells! The Stormram's wakin' up over at the Standing Stones...",
		"When he curls up and charges, get out of the way of that whirlwind! When he hits the ground he sends out a gust: jump it!",
		"After a charge he's all dizzy. That's when you pop him, sugar! His wool's too thick any other time."]


func thank_lines() -> Array:
	return ["{player}! You did it! Look: blossom on the rowans, the Fluffkins frolickin', and it's STAYIN' spring!",
		"The Stormram's just a big ol' sheepish lump now. He'll be fine. Grumpy, but fine.",
		"And back on your Earth, spring can come round too now, in its turn. Y'all are gonna love it.",
		"Oh! Before you go: hold out your hands. Back home we say a friend who helps the glen grow gets a bit of the glen's growin' in 'em.",
		"There. Now YOU can grow things! Stand on grass or soil and {grow_how} for a moment.",
		"A great big springy flower'll shoot up under you and fling you high! Land back on it and it bounces you again.",
		"And near your garden it'll give your crops a growin' boost. Thank you, sugar. From me, Isla, and every last Fluffkin."]


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
	s.set("stomps_to_defeat", 8)
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
	# The Stormram's popped: the seasons stop spinning and settle on spring, and blossom bursts out everywhere
	Portals.clear(world_id)
	racing = false
	var to: float = ceil(season_k / 4.0) * 4.0
	var tw := create_tween()
	tw.tween_method(set_season, season_k, to, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		set_season(0.0)
		_show_season())
	for t in get_children():
		if str(t.name).begins_with("Rowan"):
			Fx.burst(self, (t as Node3D).global_position + Vector3(0, 4.5, 0), BLOSSOM, 16, 0.08, 3.0, -1.0, 1.4)
	_show_plants()
	_show_season()
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


# The HUD: which season it is, and the race ------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Glen HUD"
	_hud.layer = 5
	add_child(_hud)
	var box := PanelContainer.new()
	box.name = "Season"
	box.add_theme_stylebox_override("panel", UiStyle.card(Color(0.15, 0.22, 0.18, 0.85)))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(280, 0)
	box.position = Vector2(-140, 64)
	_season_label = Label.new()
	_season_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_season_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_season_label)
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


func season_words() -> String:
	var i := int(floor(season_k)) % 4
	if is_mended():
		return "%s  (here to stay!)" % SEASON_WORDS[0]
	return "%s  · spinning!  (%d of 3 bells)" % [SEASON_WORDS[i], bells()]


func _show_season() -> void:
	if _season_label == null:
		return
	_season_label.text = season_words()
	var box := _season_label.get_parent() as Control
	box.position.x = box.get_parent_area_size().x / 2.0 - box.size.x / 2.0 if box.get_parent_area_size().x > 0 else box.position.x
	var race := _race_label.get_parent() as Control
	race.position.x = race.get_parent_area_size().x / 2.0 - race.size.x / 2.0 if race.get_parent_area_size().x > 0 else race.position.x


# Every frame ---------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_spin(delta)
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
	_show_season()


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
	var blooms := [Color(1.0, 0.55, 0.7), Color(1.0, 0.85, 0.3), Color(0.7, 0.5, 1.0), Color(1.0, 0.6, 0.3), Color(0.5, 0.75, 1.0)]
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
	var petal := _mat(blooms[k % blooms.size()], 0.15, 0.6)
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
			m.emission_energy_multiplier = 0.15 * (1.0 - wilt)
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
