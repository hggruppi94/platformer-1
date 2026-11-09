extends "res://scripts/portal_world.gd"

# Rhythm Springs, Melody's home world (plan item 19a world 4; scene built by tools/build_rhythm_springs.gd). A sunny
# summer valley of sandstone, cool spring pools, parasol palms and a big waterfall, where music used to play all day.
# The Off-Beat (a stage-sized metronome stuck between tempos, scripts/off_beat.gd) broke the beat, so time keeps
# speeding up and slowing down, and the summer sun is stuck at its hottest.
#
# The heat (Hayden, 9 Nov 2026: "add a summer element like fire or extreme heat to the challenge of the world"):
#   Out in the sun your Heat meter fills (it shows top-centre). Shade (parasol palms, the Dance Floor's awning, the
#   parasol halfway up the mesa) cools you slowly, and wading into a cool pool cools you right down. The hot springs
#   are boiling (step in and you're out again, warmer). If the meter fills right up you don't get hurt: you're "too
#   hot!", and you pop out of the nearest cool pool with a splash. Kid-safe, and it never costs HP.
# Three Song Shells start the beat again:
#   Shell1  across the Sizzle Steps: stepping stones over hot coals that flare with fire in time with the broken beat
#           (each stone burns one beat in three, with a warning glow the beat before). Touch the coals or a flaring
#           stone and you hop back to the start, a bit hotter
#   Shell2  on top of Waterfall Mesa: climb the pads up its side in the blazing sun, then ride the water slide down
#   Shell3  dance with Melody on the Dance Floor: jump on her beat 8 times (she keeps a steady one)
# With all three, the Off-Beat wakes on the Bandstand when you come near. Jump on the drum pad that lights up (or pop
# a bubble at his red-hot weight) to knock him back into time; he ticks heat rings out across the stage to jump.
# When he's back in time the world mends (Portals.clear, which also opens summer on Earth): the beat goes steady, the
# heat breaks and the sun eases down to a golden evening.

const OFF_BEAT := preload("res://scripts/off_beat.gd")
const STONES := 9
const SHELL_NAMES := ["the Sizzle Steps' shell", "the shell on top of Waterfall Mesa", "the Dance Floor's shell"]
const HEAT_MAX := 100.0
const HEAT_SUN := 2.2                    # a second in the sun (so about 45 seconds to fill up)
const HEAT_BOSS := 1.6                   # extra, close to the Off-Beat (he's hot work)
const COOL_SHADE := 7.0                  # a second in the shade
const COOL_WATER := 35.0                 # a second wading in a cool pool
const HEAT_SPRING := 30.0                # a second in a boiling hot spring
const HEAT_BURN := 15.0                  # touching the hot coals or a flaring stone
const AFTER_TOO_HOT := 20.0
const BOSS_NEAR := 14.0
const WAKE_NEAR := 18.0
const DANCE_BEAT := 0.8                  # Melody's beat: steady, unlike the world's
const DANCE_WINDOW := 0.2                # seconds either side of her beat that count as on it
const DANCE_NEEDED := 8
const DANCE_LONGEST := 32                # beats before she needs a breather (then you can go again)
const TEACH_AFTER := 3.0                 # seconds after he's back in time before Melody teaches her groove
const SLIDE_START := 5.0
const SLIDE_TOP := 15.0
const SLIDE_ACCEL := 5.0
const NOTES := 26
const HOT := Color(1.0, 0.45, 0.15)
const SHELL_PINK := Color(1.0, 0.62, 0.72)

# Noon (stuck) and evening (mended): the sky, the light and the fog lerp between these (set_cool)
const NOON := {"top": Color(0.35, 0.62, 0.95), "horizon": Color(1.0, 0.9, 0.7), "ambient": Color(1.0, 0.88, 0.75),
	"fog": Color(1.0, 0.85, 0.65), "light": Color(1.0, 0.95, 0.82), "energy": 1.0, "pitch": -72.0}
const EVENING := {"top": Color(0.3, 0.38, 0.75), "horizon": Color(1.0, 0.62, 0.5), "ambient": Color(0.9, 0.72, 0.75),
	"fog": Color(1.0, 0.7, 0.6), "light": Color(1.0, 0.78, 0.55), "energy": 0.85, "pitch": -22.0}

var heat := 0.0
var cool := 0.0                          # 0 = the stuck, blazing noon; 1 = the mended golden evening
var beat_n := 0                          # the world's beats so far (the Sizzle Steps' stones flare on these)
var beat_phase := 0.0
var dancing := false
var dance_good := 0
var riding_slide := false
var off_beat: Node3D
var _t := 0.0
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _stones: Array = []                  # [body, material, flame] for each stepping stone
var _burn_cd := 0.0
var _hot_cd := 0.0
var _dance_phase := 0.0
var _dance_beats := 0
var _dance_scored := -1
var _slide_d := 0.0
var _slide_speed := 0.0
var _slide_path: Path3D
var _notes: Array = []
var _melody_anim: AnimationPlayer
var _hud: CanvasLayer
var _heat_bar: ProgressBar
var _heat_label: Label
var _dance_box: Control
var _dance_label: Label
var _dance_ring: Label
var _tiles: Array = []


func picture() -> void:
	# In the portal's preview: the stones, the shells waiting, the Off-Beat asleep on his stage, the notes
	_own_sky()
	set_cool(1.0 if Portals.is_cleared(world_id) else 0.0)
	_add_stones()
	for i in 3:
		var m := get_node_or_null("Shell%d" % (i + 1)) as Node3D
		if m:
			m.add_child(shell_model())
	var ob := get_node_or_null("OffBeat") as Node3D
	if ob:
		ob.add_child(OFF_BEAT.model())
	_add_notes()


func setup() -> void:
	_own_sky()
	_add_stones()
	_add_shells()
	_add_dance_floor()
	_add_melody()
	_add_slide()
	_add_notes()
	_make_hud()
	if not Portals.is_cleared(world_id):
		_add_off_beat()
	set_cool(1.0 if Portals.is_cleared(world_id) else 0.0)
	if not Portals.is_cleared(world_id) and shells() == 0 and not Portals.has_found(world_id, "met_melody"):
		Game.message.call_deferred("Rhythm Springs: phew, it's HOT! The sun's stuck at noon. Someone's dancing by the way in...")


func _own_sky() -> void:
	# Each copy of the world gets its own sky, so the evening here never changes the portal's preview
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_sun = get_node_or_null("Sun") as DirectionalLight3D


func is_mended() -> bool:
	return Portals.is_cleared(world_id)


# The beat ------------------------------------------------------------------------------------------------------------
func beat_len() -> float:
	# The broken beat: it drifts from quick to slow and back (time speeding up and slowing down). Mended: steady.
	if is_mended():
		return 0.7
	return 0.55 + 0.5 * (0.5 + 0.5 * sin(_t * 0.45))


func _beat(delta: float) -> void:
	beat_phase += delta / beat_len()
	while beat_phase >= 1.0:
		beat_phase -= 1.0
		on_beat()


func on_beat() -> void:
	beat_n += 1
	_show_stones()
	for n in _notes:
		var l := n as Label3D
		if is_instance_valid(l):
			l.scale = Vector3.ONE * 1.35
	if not has_meta("preview") and not dancing:
		Juice.blip("tick", 1.5 if beat_n % 4 == 0 else 1.1, -22.0)


# The heat ------------------------------------------------------------------------------------------------------------
func in_shade(p: Vector3) -> bool:
	for c in get_children():
		if c is Marker3D and str(c.name).begins_with("Shade"):
			var m := c as Marker3D
			var flat := Vector2(p.x - m.global_position.x, p.z - m.global_position.z).length()
			if flat < float(m.get_meta("radius", 3.0)) and p.y < m.global_position.y + float(m.get_meta("height", 4.0)) \
					and p.y > m.global_position.y - 0.5:
				return true
	return false


func in_cool_pool(p: Vector3) -> bool:
	var pools := get_node_or_null("Cool Pools")
	return pools != null and pools.call("covers", p.x, p.z) and p.y - 0.8 < float(pools.get("water_y"))


func in_hot_spring(p: Vector3) -> bool:
	for c in get_children():
		if c is Marker3D and str(c.name).begins_with("Hot"):
			var m := c as Marker3D
			if Vector2(p.x - m.global_position.x, p.z - m.global_position.z).length() < float(m.get_meta("radius", 3.0)) and p.y < 1.6:
				return true
	return false


func heat_step(player: Node3D, delta: float) -> void:
	# How the heat changes this frame where the player is (nothing once the beat's back, or while dancing or sliding)
	if is_mended() or player == null or dancing or riding_slide:
		return
	var p := player.global_position
	var was := heat
	if in_cool_pool(p):
		heat -= COOL_WATER * delta
		if was >= 30.0 and heat < 30.0:
			Game.message("Ahh, cool water! That's better.")
	elif in_hot_spring(p):
		heat += HEAT_SPRING * delta
		if _hot_cd <= 0.0:
			_hot_cd = 3.0
			Game.message("Ouch, that spring's BOILING! The broken beat's turned it right up.")
			Audio.play("splash", -4.0)
	elif in_shade(p):
		heat -= COOL_SHADE * delta
	else:
		heat += HEAT_SUN * delta
		if off_beat and is_instance_valid(off_beat) and off_beat.get("awake") \
				and p.distance_to(off_beat.global_position) < BOSS_NEAR:
			heat += HEAT_BOSS * delta
	heat = clampf(heat, 0.0, HEAT_MAX)
	if was < 70.0 and heat >= 70.0:
		Game.message("You're getting really hot! Find some shade, or splash into a cool pool.")
	if heat >= HEAT_MAX:
		too_hot(player)


func add_heat(amount: float) -> void:
	if is_mended():
		return
	heat = clampf(heat + amount, 0.0, HEAT_MAX)


func nearest_cool(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for c in get_children():
		if c is Marker3D and str(c.name).begins_with("Cool"):
			var d := (c as Node3D).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = (c as Node3D).global_position
	return best


func too_hot(player: Node3D) -> void:
	# Never hurts: you pop out of the nearest cool pool with a splash, cooled down a lot
	var to := nearest_cool(player.global_position)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.global_position = to + Vector3(0, 0.9, 0)
	heat = AFTER_TOO_HOT
	Fx.burst(self, to + Vector3(0, 0.4, 0), Color(0.75, 0.95, 1.0), 26, 0.1, 4.0, -8.0, 0.9)
	Audio.play("splash", -1.0)
	Juice.shake(0.15)
	Game.message("Phew, TOO HOT! You dived into the nearest cool pool. Stay in the shade when you can!")


# The Sizzle Steps --------------------------------------------------------------------------------------------------
func _add_stones() -> void:
	_stones = []
	for i in STONES:
		var m := get_node_or_null("Stone%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var body := StaticBody3D.new()
		body.name = "Stone"
		body.set_meta("stone", i)
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.9
		c.height = 0.6
		cs.shape = c
		cs.position.y = 0.3
		body.add_child(cs)
		var mat := _mat(Color(0.45, 0.3, 0.28), 0.0, 0.9)
		var stone := _put(body, _cyl(0.85, 0.95, 0.6, 12), mat, Vector3(0, 0.3, 0))
		stone.name = "Rock"
		var flame := flame_model()
		flame.name = "Flame"
		flame.position.y = 0.6
		flame.visible = false
		body.add_child(flame)
		m.add_child(body)
		_stones.append([body, mat, flame])
	_show_stones()


func stone_hot(i: int) -> bool:
	# Each stone flares one beat in three, in a wave rolling back towards the start
	return not is_mended() and (beat_n + i) % 3 == 0


func stone_warm(i: int) -> bool:
	return not is_mended() and (beat_n + i) % 3 == 2


func _show_stones() -> void:
	for i in _stones.size():
		var s: Array = _stones[i]
		var mat := s[1] as StandardMaterial3D
		var hot := stone_hot(i)
		var warm := stone_warm(i)
		mat.emission_enabled = hot or warm
		mat.emission = HOT
		mat.emission_energy_multiplier = 2.0 if hot else 0.5
		mat.albedo_color = Color(0.85, 0.35, 0.2) if hot else (Color(0.6, 0.35, 0.28) if warm else Color(0.45, 0.3, 0.28))
		(s[2] as Node3D).visible = hot
		if hot and not has_meta("preview") and is_inside_tree():
			Fx.burst(self, (s[0] as Node3D).global_position + Vector3(0, 0.8, 0), HOT, 6, 0.08, 2.0, 1.5, 0.5)


func stone_under(player: Node3D) -> int:
	# Which stepping stone the player's standing on (-1: none)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0, -1.6, 0))
	q.exclude = [(player as CollisionObject3D).get_rid()] if player is CollisionObject3D else []
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return -1
	var c := hit.collider as Node
	return int(c.get_meta("stone")) if c and c.has_meta("stone") else -1


func in_pit(p: Vector3) -> bool:
	var pit := get_node_or_null("SizzlePit") as Node3D
	if pit == null:
		return false
	var yaw := float(pit.get_meta("yaw"))
	var along_dir := Vector3(sin(yaw), 0, cos(yaw))
	var rel := p - pit.global_position
	rel.y = 0.0
	var along := rel.dot(along_dir)
	var side := rel.dot(along_dir.cross(Vector3.UP))
	return absf(along) < float(pit.get_meta("length")) / 2.0 and absf(side) < float(pit.get_meta("width")) / 2.0


func sizzle_step(player: CharacterBody3D) -> void:
	# Standing on the coals, or on a stone while it flares: back to the start, a bit hotter
	if is_mended() or player == null or _burn_cd > 0.0 or not in_pit(player.global_position) or not player.is_on_floor():
		return
	var i := stone_under(player)
	if i < 0 or stone_hot(i):
		burn(player, i < 0)


func burn(player: CharacterBody3D, coals: bool) -> void:
	_burn_cd = 0.6
	add_heat(HEAT_BURN)
	var start := get_node_or_null("SizzleStart") as Node3D
	Fx.burst(self, player.global_position, HOT, 14, 0.08, 3.0, 2.0, 0.6)
	Juice.blip("pop", 0.6, -4.0)
	Juice.shake(0.12)
	if start:
		player.global_position = start.global_position + Vector3(0, 0.9, 0)
		player.velocity = Vector3.ZERO
	Game.message("Ouch! Hot hot HOT! %s" % ("The coals are much too hot to stand on: hop from stone to stone." if coals
		else "That stone was flaring! Watch them glow, and hop when the fire's gone."))


# The Song Shells ---------------------------------------------------------------------------------------------------
func has_shell(i: int) -> bool:
	return is_mended() or Portals.has_found(world_id, "shell_%d" % (i + 1))


func shells() -> int:
	var n := 0
	for i in 3:
		if has_shell(i):
			n += 1
	return n


func _add_shells() -> void:
	for i in 2:                                                # (the third one comes from the dance)
		var m := get_node_or_null("Shell%d" % (i + 1)) as Node3D
		if m == null or has_shell(i):
			continue
		var s := shell_model()
		s.name = "Song Shell"
		m.add_child(s)
		var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if has_shell(i) else "pick up the Song Shell",
			func() -> void: take_shell(i), 1.8, 2.2)
		spot.name = "Spot"
		m.add_child(spot)


func take_shell(i: int) -> void:
	if has_shell(i):
		return
	Portals.note_found(world_id, "shell_%d" % (i + 1))
	var m := get_node_or_null("Shell%d" % (i + 1)) as Node3D
	if m:
		for n in ["Song Shell", "Spot"]:
			var x := m.get_node_or_null(n)
			if x:
				x.queue_free()
		Fx.burst(self, m.global_position + Vector3(0, 1.0, 0), SHELL_PINK, 30, 0.1, 4.0, -1.0, 1.0)
	Juice.blip("sparkle", 1.0 + shells() * 0.15, -3.0)
	Juice.rumble(0.3, 0.2)
	var n := shells()
	var extra := " Now ride the water slide down: it's at the falls' edge!" if i == 1 else ""
	Game.message(("You found %s! (%d of 3)%s" % [SHELL_NAMES[i], n, extra]) if n < 3
		else "That's all three Song Shells! Over on the Bandstand, something big just went TICK... TOCK... TICK-TICK.")


func _process_shells(player: Node3D) -> void:
	# Walking into a shell picks it up too (not just Interact)
	for i in 2:
		if has_shell(i):
			continue
		var m := get_node_or_null("Shell%d" % (i + 1)) as Node3D
		if m and player.global_position.distance_to(m.global_position + Vector3(0, 0.9, 0)) < 1.3:
			take_shell(i)


# The water slide ---------------------------------------------------------------------------------------------------
func _add_slide() -> void:
	_slide_path = get_node_or_null("Slide") as Path3D
	var top := get_node_or_null("SlideTop") as Node3D
	if top == null or _slide_path == null:
		return
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if riding_slide else "ride the water slide",
		func() -> void: ride_slide(), 2.0, 2.2)
	spot.name = "Spot"
	top.add_child(spot)


func ride_slide() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or riding_slide or _slide_path == null:
		return
	riding_slide = true
	_slide_d = 0.0
	_slide_speed = SLIDE_START
	player.set("carried", true)
	Game.hold_controls(&"slide", true, player)
	player.velocity = Vector3.ZERO
	Audio.play("splash", -4.0)
	Juice.blip("whoosh", 1.0, -6.0)


func _slide_step(player: CharacterBody3D, delta: float) -> void:
	if not riding_slide or player == null:
		return
	var curve := _slide_path.curve
	var length := curve.get_baked_length()
	_slide_speed = minf(_slide_speed + SLIDE_ACCEL * delta, SLIDE_TOP)
	_slide_d = minf(_slide_d + _slide_speed * delta, length)
	var at := _slide_path.to_global(curve.sample_baked(_slide_d))
	var ahead := _slide_path.to_global(curve.sample_baked(minf(_slide_d + 0.5, length)))
	player.global_position = at + Vector3(0, 0.95, 0)
	var visual := player.get_node_or_null("Visual") as Node3D
	if visual and ahead.distance_to(at) > 0.01:
		visual.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
	if int(_slide_d * 2.0) % 3 == 0:
		Fx.burst(self, at + Vector3(0, 0.3, 0), Color(0.75, 0.95, 1.0, 0.8), 2, 0.07, 1.5, -6.0, 0.4)
	if _slide_d >= length - 0.05:
		end_slide(player)


func end_slide(player: CharacterBody3D) -> void:
	riding_slide = false
	player.set("carried", false)
	var curve := _slide_path.curve
	var length := curve.get_baked_length()
	var a := curve.sample_baked(length - 1.0)
	var b := curve.sample_baked(length)
	var dir := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	player.velocity = dir * 3.0 + Vector3.UP * 2.0
	heat = 0.0
	Fx.burst(self, player.global_position, Color(0.75, 0.95, 1.0), 30, 0.12, 5.0, -8.0, 1.0)
	Audio.play("splash", 0.0)
	Juice.shake(0.12)
	if not Portals.has_found(world_id, "slid"):
		Portals.note_found(world_id, "slid")
		Game.message("WHEEEE! SPLASH! All cooled down.")
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(player):
			Game.hold_controls(&"slide", false, player))


# Dancing with Melody -----------------------------------------------------------------------------------------------
func _add_dance_floor() -> void:
	var m := get_node_or_null("DanceFloor") as Node3D
	if m == null:
		return
	var colours := [Color(1.0, 0.5, 0.7), Color(0.45, 0.8, 1.0), Color(1.0, 0.85, 0.35), Color(0.65, 0.55, 1.0)]
	_tiles = []
	var r := float(m.get_meta("radius", 4.5))
	var k := 0
	for ring in 3:
		var n := 6 + ring * 6
		for j in n:
			var a := (j + 0.5) * TAU / n
			var d := (ring + 0.6) * r / 3.3
			var mat := _mat(colours[(j + ring) % colours.size()], 0.2, 0.5)
			var t := _put(m, _cyl(0.55, 0.55, 0.04, 10), mat, Vector3(cos(a) * d, 0.02, sin(a) * d))
			t.name = "Tile %d" % k
			_tiles.append(mat)
			k += 1
	var spot := USE_SPOT.make(Vector3.ZERO, _dance_offer, start_dance, r * 0.8, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func _dance_offer() -> String:
	if dancing:
		return ""
	return "dance with Melody" if not has_shell(2) else "dance with Melody (just for fun)"


func start_dance() -> void:
	if dancing:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	dancing = true
	dance_good = 0
	_dance_phase = 0.0
	_dance_beats = 0
	_dance_scored = -1
	if player:
		Game.hold_controls(&"dance", true, player)
		player.velocity = Vector3.ZERO
	_melody_play("dance")
	if _dance_box:
		_dance_box.visible = true
	_show_dance()
	Game.message(Settings.fill("Melody: \"Listen to MY beat, not the broken one! Press {jump} when the ring closes. Eight in a row-ish!\""))


func dance_press() -> bool:
	# A press while dancing: on Melody's beat (near enough) scores, once per beat. Says whether it scored.
	if not dancing:
		return false
	var off := minf(_dance_phase, 1.0 - _dance_phase) * DANCE_BEAT
	var nearest := _dance_beats + (1 if _dance_phase > 0.5 else 0)
	if off > DANCE_WINDOW or nearest == _dance_scored:
		Juice.blip("tick", 0.7, -10.0)
		if _dance_label:
			_dance_label.text = "Oops, off the beat! Listen for it...  %d / %d" % [dance_good, DANCE_NEEDED]
		return false
	_dance_scored = nearest
	dance_good += 1
	Juice.blip("chime", 1.0 + dance_good * 0.1, -5.0)
	var m := get_node_or_null("DanceFloor") as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.0, 0), SHELL_PINK, 10, 0.08, 3.0, -1.0, 0.6)
	_show_dance()
	if dance_good >= DANCE_NEEDED:
		end_dance(true)
	return true


func _dance_step(delta: float) -> void:
	if not dancing:
		return
	_dance_phase += delta / DANCE_BEAT
	while _dance_phase >= 1.0:
		_dance_phase -= 1.0
		_dance_beats += 1
		Juice.blip("tick", 1.4 if _dance_beats % 4 == 0 else 1.0, -12.0)
		for i in _tiles.size():
			var mat := _tiles[i] as StandardMaterial3D
			mat.emission_energy_multiplier = 1.8 if (i + _dance_beats) % 3 == 0 else 0.2
		if _dance_beats >= DANCE_LONGEST:
			end_dance(false)
			return
	if Input.is_action_just_pressed("jump"):
		dance_press()
	if _dance_ring:
		var k := 1.0 - _dance_phase
		_dance_ring.scale = Vector2.ONE * (1.0 + k * 1.6)
		_dance_ring.modulate = Color(1, 1, 1, 0.3 + 0.7 * (1.0 - k))


func end_dance(won: bool) -> void:
	dancing = false
	var player := get_tree().get_first_node_in_group("player")
	if player:
		Game.hold_controls(&"dance", false, player)
	if _dance_box:
		_dance_box.visible = false
	_melody_play("idle")
	for mat in _tiles:
		(mat as StandardMaterial3D).emission_energy_multiplier = 0.2
	if won and not has_shell(2):
		Portals.note_found(world_id, "shell_3")
		var m := get_node_or_null("DanceFloor") as Node3D
		if m:
			Fx.burst(self, m.global_position + Vector3(0, 1.5, 0), SHELL_PINK, 40, 0.12, 5.0, -1.0, 1.2)
		Juice.blip("sparkle", 1.2, -3.0)
		var n := shells()
		Game.message(("Melody: \"You've GOT it! Here, the Dance Floor's Song Shell!\" (%d of 3)" % n) if n < 3
			else "Melody: \"That's all three Song Shells!\" Over on the Bandstand, something big just went TICK... TOCK... TICK-TICK.")
	elif won:
		Game.message("Melody: \"Woo! Best dance partner EVER.\"")
	else:
		Game.message("Melody: \"Phew! Let's catch our breath. Come and dance again when you're ready!\"")


func _show_dance() -> void:
	if _dance_label:
		_dance_label.text = Settings.fill("Press {jump} on Melody's beat!  %d / %d" % [dance_good, DANCE_NEEDED])


# Melody ------------------------------------------------------------------------------------------------------------
func _add_melody() -> void:
	var m := get_node_or_null("Melody") as Node3D
	if m == null:
		return
	var packed := load("res://models/characters/melody.glb") as PackedScene
	if packed:
		var p := packed.instantiate() as Node3D
		p.name = "Model"
		m.add_child(p)
		_melody_anim = p.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _melody_anim:
			for a in ["idle", "dance"]:
				if _melody_anim.has_animation(a):
					_melody_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_melody_play("idle")
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "" if dancing else "talk to Melody", _talk_melody, 2.4, 2.4)
	spot.name = "Spot"
	m.add_child(spot)


func _melody_play(anim: String) -> void:
	if _melody_anim and _melody_anim.has_animation(anim):
		_melody_anim.play(anim)


func melody_lines() -> Array:
	# Melody's bouncy and musical, but the broken beat's got her flustered (and very hot)
	if is_mended() and not Portals.has_found(world_id, "thanked"):
		Portals.note_found(world_id, "thanked")
		return ["Hear that? Tick, tock, tick, tock... a STEADY beat! The springs are singing again!",
			"And feel that breeze! Summer's supposed to be warm, not boiling.",
			"Thank you, {player}! Come back for a soak in the hot springs any time. They're just right now."]
	if is_mended():
		return [["Hear that? Tick, tock, tick, tock... a STEADY beat! The springs are singing again!",
			"And feel that breeze! Summer's supposed to be warm, not boiling.",
			"Thank you, {player}! Come back for a soak in the hot springs any time. They're just right now."],
			["How's your groove? Press {groove} on the beat, then again, and again! The more in a row, the bigger the ring.",
			"Four in a row and the music carries you along. Wheee!"],
			["I've got a stage in the Void now, by my portal! I do a show every evening.",
			"Come up on the stage and groove with me. Eight on the beat and you get an encore prize!"]].pick_random()
	if not Portals.has_found(world_id, "met_melody"):
		Portals.note_found(world_id, "met_melody")
		return ["{player}! You came! Welcome to Rhythm Springs! Isn't it... phew... HOT?",
			"The Off-Beat's broken our beat. He's a great big metronome, and he's stuck between two speeds!",
			"So time goes fast, then slow, then fast... and the sun's got stuck at the hottest bit of noon.",
			"Watch your Heat meter! Shade cools you down, and the cool pools cool you right off. The hot springs are BOILING, so stay out!",
			"If we find the three Song Shells, we can put the beat back. One's over the Sizzle Steps, one's on top of Waterfall Mesa...",
			"...and one's right here! Dance with me on the Dance Floor and it's yours."]
	var left: Array = []
	for i in 3:
		if not has_shell(i):
			left.append(["hop across the Sizzle Steps (hop when the fire's gone)", "climb Waterfall Mesa and slide back down",
				"dance with me on the Dance Floor"][i])
	if left.size() > 0:
		return ["%d Song Shell%s! I can almost hear the beat coming back." % [3 - left.size(), "" if 3 - left.size() == 1 else "s"]
			if left.size() < 3 else "Stay cool! Shade, pools, shade, pools. That's the summer rule.",
			"Still to do: %s." % ", and ".join(left)]
	return ["All three Song Shells! The Off-Beat's waking up on the Bandstand...",
		"Jump on the drum that lights up, or pop a bubble at his red-hot weight! That knocks him back into time.",
		"When his arm swings, a heat ring rolls out across the stage. Jump it! And cool off in the pool by the stage."]


func _talk_melody() -> void:
	var spot := get_node_or_null("Melody/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Melody", melody_lines().map(func(l: String) -> String: return Settings.fill(l)), "rhythm_springs_melody")


# The Off-Beat ------------------------------------------------------------------------------------------------------
func _add_off_beat() -> void:
	var m := get_node_or_null("OffBeat") as Node3D
	if m == null:
		return
	var drums: Array = []
	for i in 4:
		var d := get_node_or_null("Drum%d" % (i + 1)) as Node3D
		if d:
			drums.append(d.global_position)
	off_beat = OFF_BEAT.new()
	off_beat.name = "The Off-Beat"
	off_beat.set("world", self)
	off_beat.set("drum_spots", drums)
	add_child(off_beat)
	off_beat.global_position = m.global_position


func wake_off_beat() -> void:
	if off_beat and is_instance_valid(off_beat) and not off_beat.get("awake"):
		off_beat.call("wake")


func mend() -> void:
	# He's back in time: the beat steadies, the heat breaks and the sun eases down to a golden evening
	Portals.clear(world_id)
	heat = 0.0
	_show_stones()
	var tw := create_tween()
	tw.tween_method(set_cool, cool, 1.0, 5.0).set_trans(Tween.TRANS_SINE)
	var m := get_node_or_null("OffBeat") as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 4.0, 0), Color(1.0, 0.85, 0.5), 60, 0.12, 6.0, -1.0, 1.6)
	for n in _notes:
		var l := n as Label3D
		if is_instance_valid(l):
			l.modulate = Color.from_hsv(randf(), 0.5, 1.0)
	Juice.shake(0.15)
	Juice.rumble(0.3, 0.3)
	Juice.blip("chime", 0.8, -3.0)
	get_tree().create_timer(TEACH_AFTER).timeout.connect(_teach_groove)


func teach_lines() -> Array:
	# Melody's thank-you: Rhythm Springs' reward is her groove (scripts/groove.gd)
	return ["{player}! You did it! You put the beat back! (Melody bounces all the way over, ponytail flying.)",
		"I want to give you something. My groove! Everybody has a beat inside, you just have to find it.",
		"Press {groove} to dance. A ring of music bursts out, and anyone grumpy nearby can't help dancing too. Gloops, goblins, anyone!",
		"Now press it ON the beat. Then again. And again! The more in a row, the bigger the ring.",
		"Four in a row and the music carries you along. Try it! One, two, three, four..."]


func _teach_groove(tries := 0) -> void:
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:             # wait for a talk to finish first
		get_tree().create_timer(1.0).timeout.connect(_teach_groove.bind(tries + 1))
		return
	var spot := get_node_or_null("Melody/Spot") as Node3D
	if spot:
		Dialogue.say(spot, "Melody", teach_lines().map(func(l: String) -> String: return Settings.fill(l)), "rhythm_springs_groove")
	else:
		Game.message("New: Groove! Press %s to dance, and press it on the beat for a bigger groove." % Settings.prompt("groove"))


func set_cool(k: float) -> void:
	# The sky, the sun and the haze, from the stuck blazing noon (0) to the golden evening (1)
	cool = clampf(k, 0.0, 1.0)
	if _sky:
		_sky.sky_top_color = (NOON.top as Color).lerp(EVENING.top, cool)
		_sky.sky_horizon_color = (NOON.horizon as Color).lerp(EVENING.horizon, cool)
		_sky.ground_horizon_color = (NOON.horizon as Color).lerp(EVENING.horizon, cool)
	if _env:
		_env.ambient_light_color = (NOON.ambient as Color).lerp(EVENING.ambient, cool)
		_env.fog_light_color = (NOON.fog as Color).lerp(EVENING.fog, cool)
	if _sun:
		_sun.light_color = (NOON.light as Color).lerp(EVENING.light, cool)
		_sun.light_energy = lerpf(NOON.energy, EVENING.energy, cool)
		_sun.rotation_degrees = Vector3(lerpf(NOON.pitch, EVENING.pitch, cool), lerpf(20.0, 60.0, cool), 0)


# Music notes in the air --------------------------------------------------------------------------------------------
func _add_notes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var holder := Node3D.new()
	holder.name = "Notes"
	add_child(holder)
	_notes = []
	var colours := [Color(1.0, 0.55, 0.75), Color(0.45, 0.8, 1.0), Color(1.0, 0.85, 0.35), Color(0.7, 0.6, 1.0)]
	for i in NOTES:
		var l := Label3D.new()
		l.text = ["♪", "♫", "♩", "♬"][i % 4]
		l.font_size = 96
		l.pixel_size = 0.012
		l.outline_size = 14
		l.outline_modulate = Color(1, 1, 1, 0.9)
		l.modulate = colours[i % colours.size()]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var a := rng.randf() * TAU
		var d := rng.randf_range(6.0, 40.0)
		l.position = Vector3(cos(a) * d, rng.randf_range(2.5, 7.0), sin(a) * d)
		l.set_meta("home", l.position)
		l.set_meta("phase", rng.randf() * TAU)
		holder.add_child(l)
		_notes.append(l)


func _move_notes(delta: float) -> void:
	# They bob and drift, quick when the beat's quick, slow when it's slow, and spring back after each beat's pulse
	var speed := 0.7 / beat_len()
	for n in _notes:
		var l := n as Label3D
		if not is_instance_valid(l):
			continue
		var home: Vector3 = l.get_meta("home")
		var ph: float = l.get_meta("phase")
		l.position = home + Vector3(sin(_t * 0.3 * speed + ph) * 1.2, sin(_t * 1.5 * speed + ph) * 0.5, 0)
		l.scale = l.scale.lerp(Vector3.ONE, minf(1.0, delta * 6.0))


# The HUD: the Heat meter and the dance ring ------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Heat HUD"
	_hud.layer = 5
	add_child(_hud)
	var box := PanelContainer.new()
	box.name = "Heat"
	box.add_theme_stylebox_override("panel", UiStyle.card(Color(0.3, 0.12, 0.08, 0.85)))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.custom_minimum_size = Vector2(260, 0)
	box.position = Vector2(-130, 64)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_heat_label = Label.new()
	_heat_label.add_theme_font_size_override("font_size", 20)
	_heat_label.custom_minimum_size = Vector2(92, 0)
	row.add_child(_heat_label)
	_heat_bar = ProgressBar.new()
	_heat_bar.max_value = HEAT_MAX
	_heat_bar.show_percentage = false
	_heat_bar.custom_minimum_size = Vector2(140, 18)
	_heat_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_heat_bar.add_theme_stylebox_override("background", UiStyle.box(Color(0.15, 0.08, 0.06), 6, Color(1, 0.8, 0.6, 0.5), 1))
	_heat_bar.add_theme_stylebox_override("fill", UiStyle.box(Color(1.0, 0.6, 0.2), 6, Color(1, 0.9, 0.6), 1))
	row.add_child(_heat_bar)
	_hud.add_child(box)
	# The dance: Melody's beat as a ring closing in on a dot, and the count
	_dance_box = VBoxContainer.new()
	_dance_box.name = "Dance"
	_dance_box.set_anchors_preset(Control.PRESET_CENTER)
	_dance_box.position = Vector2(-220, 40)
	_dance_box.custom_minimum_size = Vector2(440, 0)
	_dance_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var ring_holder := Control.new()
	ring_holder.custom_minimum_size = Vector2(0, 120)
	_dance_box.add_child(ring_holder)
	var dot := Label.new()
	dot.text = "●"
	dot.add_theme_font_size_override("font_size", 40)
	dot.modulate = SHELL_PINK
	dot.position = Vector2(205, 32)
	ring_holder.add_child(dot)
	_dance_ring = Label.new()
	_dance_ring.text = "◯"
	_dance_ring.add_theme_font_size_override("font_size", 64)
	_dance_ring.position = Vector2(198, 20)
	_dance_ring.pivot_offset = Vector2(22, 38)
	ring_holder.add_child(_dance_ring)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.card(Color(0.25, 0.1, 0.3, 0.85)))
	_dance_label = Label.new()
	_dance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dance_label.add_theme_font_size_override("font_size", 22)
	card.add_child(_dance_label)
	_dance_box.add_child(card)
	_dance_box.visible = false
	_hud.add_child(_dance_box)
	_show_heat()


func heat_words() -> String:
	if heat >= 85.0:
		return "Too hot!"
	if heat >= 60.0:
		return "Hot!"
	if heat >= 30.0:
		return "Warm"
	return "Cool"


func _show_heat() -> void:
	if _heat_bar == null:
		return
	var box := _heat_bar.get_parent().get_parent() as Control
	box.visible = not is_mended()
	box.position.x = box.get_parent_area_size().x / 2.0 - box.size.x / 2.0 if box.get_parent_area_size().x > 0 else box.position.x
	_heat_bar.value = heat
	_heat_label.text = "Heat: " + heat_words()
	var k := heat / HEAT_MAX
	_heat_label.modulate = Color(0.75, 0.95, 1.0).lerp(Color(1.0, 0.45, 0.3), k)
	var fill := _heat_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.3, 0.15), k)


# Every frame -------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_beat(delta)
	_move_notes(delta)
	var falls := get_node_or_null("Waterfall Mesa/Waterfall") as GeometryInstance3D
	if falls:
		falls.transparency = 0.15 + 0.1 * sin(_t * 6.0)
	if has_meta("preview"):
		return
	_burn_cd -= delta
	_hot_cd -= delta
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	_dance_step(delta)
	if player:
		_slide_step(player, delta)
		_process_shells(player)
		if not get_tree().paused and not Dialogue.is_active():
			heat_step(player, delta)
		sizzle_step(player)
		var m := get_node_or_null("OffBeat") as Node3D
		if not is_mended() and shells() == 3 and m and player.global_position.distance_to(m.global_position) < WAKE_NEAR:
			wake_off_beat()
	_show_heat()


# Looks --------------------------------------------------------------------------------------------------------------
static func _ball(r: float, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s


static func _mat(colour: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
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


static func flame_model() -> Node3D:
	# A little bonfire of flame tongues (orange outside, yellow in the middle) with a warm light
	var g := Node3D.new()
	var outer := _mat(Color(1.0, 0.45, 0.12), 2.5)
	var inner := _mat(Color(1.0, 0.85, 0.3), 3.0)
	for k in 5:
		var a := k * TAU / 5.0
		_put(g, _cyl(0.0, 0.22, 0.9, 6), outer, Vector3(cos(a) * 0.3, 0.45, sin(a) * 0.3), Vector3(1, 1.0 + 0.2 * (k % 2), 1)) \
			.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_put(g, _cyl(0.0, 0.3, 1.3, 8), inner, Vector3(0, 0.65, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.5
	light.omni_range = 3.5
	light.position.y = 0.8
	g.add_child(light)
	return g


static func shell_model() -> Node3D:
	# A Song Shell: a big pink spiral conch on a little drum, glowing, with a note floating over it
	var g := Node3D.new()
	var drum := _mat(Color(0.95, 0.45, 0.35), 0.0, 0.6)
	_put(g, _cyl(0.4, 0.45, 0.5, 14), drum, Vector3(0, 0.25, 0))
	_put(g, _cyl(0.42, 0.42, 0.05, 14), _mat(Color(1.0, 0.95, 0.85), 0.0, 0.5), Vector3(0, 0.52, 0))
	var shell := _mat(SHELL_PINK, 0.8, 0.4)
	var holder := Node3D.new()
	holder.name = "Shell"
	holder.position.y = 0.9
	g.add_child(holder)
	for k in 5:
		var s := 0.32 - k * 0.055
		_put(holder, _ball(s, 12), shell, Vector3(k * 0.08, 0.05 + k * 0.1, 0), Vector3(1.2, 1.0, 1.0))
	_put(holder, _cyl(0.0, 0.12, 0.3, 8), _mat(Color(1.0, 0.85, 0.85), 0.8, 0.4), Vector3(-0.3, -0.05, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	var note := Label3D.new()
	note.text = "♪"
	note.font_size = 72
	note.pixel_size = 0.01
	note.outline_size = 10
	note.modulate = SHELL_PINK
	note.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	note.position.y = 1.8
	g.add_child(note)
	var light := OmniLight3D.new()
	light.light_color = SHELL_PINK
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position.y = 1.0
	g.add_child(light)
	return g
