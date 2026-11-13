extends CanvasLayer

# The night the sky cracked: how a new game's hero first gets to the Void (Hayden, 13 Nov 2026: "The intro to the void
# needs to be much more significant ... This needs to be a unprecedented event that has people worried... the little
# aliens creatures can greet all of the chosen as they are thrown into the new world all at once ... the glowing tree
# quest should be scrapped and getting pulled into the void should be a seemingly more random occurrence which you
# find out was caused by dash and rex later on"). A node "Arrival" under the FirstNight autoload
# (scripts/first_night.gd): FirstNight.arrival.
#
#   fall()    Earth, the first midnight, wherever the hero happens to be (most likely asleep: the bed's sleep stops at
#             midnight on that night, scripts/bed.gd). The ground shakes, the lights flicker, a crack splits open right
#             under their feet and they drop through. Nothing leads up to it: no oak, no countdown. Sets "fn_fell" (The
#             First Night's "evening" step is done) and "oak_woken" (from now on the crack by the old oak opens every
#             Shift, scripts/earth_world.gd), then lands them in the Void's Market Square.
#   arrive()  the Void, straight after: the cutscene. A quiet dawn over the Market Square, then the green sky splits in
#             seven places at once and seven streaks of light fall: the hero, Nina with Bruno hanging on to her hand,
#             Pip, Bramble, Melody and Heather (the chosen, all thrown in together; their real town selves stand at their
#             landing spots while the step's on: quests/first_night.json "shift" overrides). The Void folk stop and
#             stare (Mr. Palmer, the Green Man, Rex and Rook: Rex's ears go flat, the only hint of who's to blame). Then
#             the little aliens come running from every lane to greet each newcomer, the only ones who aren't scared,
#             and Tally runs up counting. The little aliens stay round the hero, waving, and Tally waits beside them
#             until they've talked (flag "fn_met_tally"), then everyone scatters and the sky's cracks close.
#
# Skippable (Jump, Interact or Accept). Headless runs (the tests) skip the pictures but not what happens (the flags, the
# watch, the greeters and Tally waiting), unless `force` is set. Every line is a first draft.

const CRACK := preload("res://scripts/crack.gd")
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const FELL_FLAG := "fn_fell"
const ARRIVED_FLAG := "fn_arrived"
const TALLY_FLAG := "fn_met_tally"
const SQUARE := Vector3(-72.0, 0.0, 42.0)        # the Market Square's middle (its fountain), in case the node's missing
const HERO_LANDS := Vector2(-74.7, 34.5)          # where the hero lands: the square's north side, by Tally's board
# The other chosen, in the order they land, and where (the same spots as routines/places.json "arrival_<id>")
const ARRIVALS := [
	["nina", "Nina", Vector2(-77.4, 36.1)],
	["bruno_alien", "Bruno", Vector2(-79.0, 37.4)],
	["pip", "Pip", Vector2(-69.9, 34.3)],
	["bramble", "Bramble", Vector2(-66.9, 35.9)],
	["melody", "Melody", Vector2(-64.3, 38.4)],
	["clover", "Heather", Vector2(-80.0, 39.6)],
]
const ONLOOKERS := ["mr_palmer", "green_man", "rex", "rook"]
const CRACK_COLOUR := Color(0.75, 0.5, 1.0)
const SKY_HEIGHT := 34.0                           # the sky's cracks, over the square
const GREETERS := 22                               # little aliens that come running
const HERO_GREETERS := 8                           # ...of them round the hero; the rest round the others
const COLOURS := ["blue", "purple", "yellow", "red", "pink", "orange", "green"]
const SCATTER_FAR := 45.0                          # the greeters go home once the hero's this far away
# The cutscene's beats (seconds)
const T_CRACKS := 3.6
const T_LAND := 7.2
const LAND_GAP := 0.55
const T_REX := 11.8
const T_ALIENS := 14.2
const T_TALLY := 19.6
const T_TITLE := 25.4
const LENGTH := 29.0
const BAR := 0.11
const FALL_LENGTH := 4.6

signal finished

var force := false                                 # tests: play the pictures even in a headless run
var greeters: Array = []
var sky_cracks: Array = []
var cam: Camera3D
var _old_cam: Camera3D
var _t := 0.0
var _playing := false
var _falling := false
var _scene: Node3D
var _square := SQUARE
var _hero := Vector3.ZERO
var _landed: Array[Node3D] = []                    # who's been shown so far (the hero's model included)
var _to_land: Array = []                           # [node, at, time]
var _streaks: Array = []                           # [mesh, from, to, t0]
var _tally: Node3D
var _hidden: Array[CanvasLayer] = []
var _said := {}
var _scattering := false
var _caption: Label
var _title: Label
var _sub: Label
var _dark: ColorRect
var _bars: Array[ColorRect] = []
var _fall_crack: Node3D


func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_PAUSABLE
	visible = false
	_dark = ColorRect.new()
	_dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dark.color = Color(0.02, 0.01, 0.05, 0.0)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dark)
	_bars = [_bar(true), _bar(false)]
	_caption = _label(34, Color(1, 0.97, 1))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # (before sizing it, or a long line widens it off screen)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.anchor_left = 0.08
	_caption.anchor_right = 0.92
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.offset_left = 0
	_caption.offset_right = 0
	_caption.offset_top = -230
	_caption.offset_bottom = -100
	_title = _label(64, Color(1.0, 0.92, 0.6))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_left = -700
	_title.offset_right = 700
	_title.offset_top = -90
	_title.offset_bottom = -10
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _label(30, Color(0.92, 0.85, 1.0))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_left = -700
	_sub.offset_right = 700
	_sub.offset_top = 0
	_sub.offset_bottom = 60
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Dialogue.flag_set.connect(_on_flag)
	get_tree().scene_changed.connect(func() -> void:
		greeters.clear()
		sky_cracks.clear()
		_scattering = false
		_tally = null)


func headless() -> bool:
	return DisplayServer.get_name() == "headless" and not force


func playing() -> bool:
	return _playing or _falling


# -----------------------------------------------------------------------------
# Earth: the fall
# -----------------------------------------------------------------------------
func due() -> bool:
	# Midnight on a new game's first night, before they've ever been through (FirstNight._process asks every frame)
	return FirstNight.running() and FirstNight.step() == "evening" and Clock.in_shift() \
		and not Dialogue.flags.has(FELL_FLAG) and not _falling and not Dialogue.is_active() \
		and get_tree().get_first_node_in_group("player") != null and not get_tree().paused


func fall() -> void:
	if _falling or Dialogue.flags.has(FELL_FLAG):
		return
	_falling = true
	if headless():
		_drop()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	Game.hold_controls(&"first_fall", true)
	add_to_group("cutscene_playing")
	visible = true
	for b in _bars:
		b.visible = false
	_title.text = ""
	_sub.text = ""
	_dark.color.a = 0.0
	_say("", "Midnight.")
	Audio.play("beam", -10.0, 0.0)
	Juice.rumble(0.3, 0.6, 0.2)
	var calm := Settings.reduce_flashing
	var tw := create_tween()
	# The shaking builds, and the lights flicker
	for i in 6:
		tw.tween_callback(func() -> void:
			Juice.shake(0.12 + 0.07 * i)
			Juice.rumble(0.2 + 0.1 * i, 0.3, 0.1 * i)
			if i == 2:
				_say("", "Everything's shaking...")
			_dark.color.a = 0.3 if calm else (0.55 if i % 2 == 0 else 0.1))
		tw.tween_interval(0.36)
	tw.tween_callback(func() -> void:
		_dark.color.a = 0.15
		_open_fall_crack(player)
		_say("", "CRACK!")
		Juice.shake(0.6)
		Juice.rumble(0.8, 0.6, 0.8)
		Audio.play("level_up", -8.0, 0.0))
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void:
		_say("", "Aaaaaaah!")
		Juice.blip("whoosh", 0.7, -4.0))
	tw.tween_property(_dark, "color:a", 1.0, 0.6)
	tw.tween_interval(0.4)
	tw.tween_callback(_drop)


func _open_fall_crack(player: Node3D) -> void:
	# The split, right under their feet, on whatever floor they're on (it isn't cut into anything: it's only there a
	# moment, before the screen goes dark)
	if player == null or not player.is_inside_tree():
		return
	_fall_crack = CRACK.make(CRACK_COLOUR)
	_fall_crack.name = "First Crack"
	player.get_parent().add_child(_fall_crack)
	var at := player.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 4.0)
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	_fall_crack.global_position = (hit.position if hit else at) + Vector3(0, 0.03, 0)
	var view := get_viewport().get_camera_3d()
	if view:
		_fall_crack.rotation.y = view.global_rotation.y            # (across the view, so it's seen splitting)
	CRACK.set_open(_fall_crack, 0.0)
	var glow := OmniLight3D.new()                   # (it's midnight: a glow up out of it, so the split shows)
	glow.light_color = CRACK_COLOUR
	glow.omni_range = 6.0
	glow.light_energy = 0.0
	glow.position = Vector3(0, 0.4, 0)
	_fall_crack.add_child(glow)
	glow.create_tween().tween_property(glow, "light_energy", 4.0, 0.7)
	var tw := _fall_crack.create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(_fall_crack):
			CRACK.set_open(_fall_crack, k), 0.0, 1.0, 0.7)
	Fx.burst(_fall_crack, _fall_crack.global_position + Vector3(0, 0.3, 0), CRACK_COLOUR, 24, 0.08, 4.0, -2.0, 0.9)


func _drop() -> void:
	# Off they go: the Void's Market Square
	Dialogue.set_flag("oak_woken")                  # (the oak's crack opens every Shift from now on)
	Dialogue.set_flag(FELL_FLAG)
	Game.hold_controls(&"first_fall", false)
	remove_from_group("cutscene_playing")
	_falling = false
	_fall_crack = null
	var at := Vector3(HERO_LANDS.x, 0.6, HERO_LANDS.y)
	var to := SQUARE - at
	Game.go_to_point(TOWN, at, atan2(-to.x, -to.z), "Void")
	# (the dark screen stays up until the Void's loaded and the arrival takes over)
	if headless():
		_reset_screen()


func _reset_screen() -> void:
	visible = false
	_dark.color.a = 0.0
	_caption.text = ""
	_title.text = ""
	_sub.text = ""


# -----------------------------------------------------------------------------
# The Void: the arrival
# -----------------------------------------------------------------------------
func arrive() -> void:
	# The first time they land in the Void (FirstNight._on_scene_changed, deferred so Tally and the board are in)
	var scene := get_tree().current_scene as Node3D
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if scene == null or player == null or Dialogue.flags.has(ARRIVED_FLAG):
		_reset_screen()
		return
	Dialogue.set_flag(ARRIVED_FLAG)
	for n in greeters + sky_cracks:
		if is_instance_valid(n):
			n.queue_free()
	greeters.clear()
	sky_cracks.clear()
	_scattering = false
	_scene = scene
	var sq := scene.get_node_or_null("Market Square") as Node3D
	_square = sq.global_position if sq else SQUARE
	_square.y = _ground(_square).y
	_hero = player.global_position
	_tally = scene.get_node_or_null("Tally") as Node3D
	_make_sky_cracks()
	_spawn_greeters()
	if _tally and _tally.has_method("stand_by"):
		_tally.call("stand_by", tally_spot(), _hero)
	if headless():
		_settle()
		_reset_screen()
		return
	_play()


func tally_spot() -> Vector3:
	# Beside the hero, on the fountain's side
	var to := (_square - _hero) * Vector3(1, 0, 1)
	var dir := to.normalized() if to.length() > 0.1 else Vector3.BACK
	return _ground(_hero + dir * 2.6 + dir.cross(Vector3.UP) * 0.9)


func _play() -> void:
	_playing = true
	_t = 0.0
	_said.clear()
	add_to_group("cutscene_playing")
	Game.hold_controls(&"void_arrival", true)
	visible = true
	for b in _bars:
		b.visible = true
	_title.text = ""
	_sub.text = ""
	_caption.text = ""
	create_tween().tween_property(_dark, "color:a", 0.0, 1.2)       # (up from the fall's dark screen)
	_hide_hud()
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "Arrival Camera"
	cam.fov = 62.0
	_scene.add_child(cam)
	cam.make_current()
	# Everyone who's about to land is hidden until they do
	_landed.clear()
	_to_land.clear()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	_to_land.append([player, _hero, T_LAND])
	var i := 1
	for a in ARRIVALS:
		var who := _who(str(a[0]))
		if who:
			_to_land.append([who, who.global_position, T_LAND + LAND_GAP * i])
		i += 1
	for l in _to_land:
		(l[0] as Node3D).visible = false
	for c in sky_cracks:
		c.scale = Vector3(0.01, 1, 1)
	for g in greeters:
		g.visible = false
		g.global_position = g.get_meta("start")
		g.set_meta("there", false)
	if _tally:
		_tally.visible = false
	_place_camera()


func _process(delta: float) -> void:
	if _playing:
		_t += delta
		_beats()
		_place_camera()
		if _t >= LENGTH or (_t > 0.6 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact")
				or Input.is_action_just_pressed("ui_accept"))):
			_finish()
	_streak_step()
	_greeters_step(delta)


func _beats() -> void:
	if _once("calm", 0.3):
		_say("", "Dawn in the Void. A quiet morning in the Market Square...")
	if _t >= T_CRACKS - 0.6 and _once("rumble", T_CRACKS - 0.6):
		Juice.shake(0.25)
		Juice.rumble(0.3, 0.5, 0.2)
	for i in sky_cracks.size():
		if _once("crack_%d" % i, T_CRACKS + 0.4 * i):
			var c := sky_cracks[i] as Node3D
			c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Audio.play("beam", -12.0, 0.0)
			Juice.shake(0.15)
			if i == 0:
				_say("", "...until the sky split open.")
	for l in _to_land:
		var who := l[0] as Node3D
		var key := "land_%d" % who.get_instance_id()
		if _once(key, float(l[2]) - 0.8):
			_streak(who, l[1] as Vector3)
	if _once("palmer", T_LAND + 1.4):
		_say("Mr. Palmer", "What in the Void...?! Kids? Falling out of the SKY?")
	if _once("count", T_LAND + 3.0):
		_say("", "Seven of them. All at once. Nobody in the Void had ever seen anything like it.")
	if _once("rex", T_REX):
		_say("", "(Rex's ears go flat. He looks at Rook. Then he looks at the ground.)")
	if _once("aliens", T_ALIENS):
		_say("", "Only the little aliens weren't scared. They came running from every lane and rooftop...")
		for g in greeters:
			g.visible = true
			g.set_meta("go", _t + randf_range(0.0, 1.6))
	if _once("welcome", T_ALIENS + 2.8):
		_say("Little aliens", "Welcome! Welcome! WELCOME!")
		Juice.blip("sparkle", 1.4)
	if _once("tally", T_TALLY):
		if _tally:
			_tally.visible = true
			_tally.global_position = _ground(_hero + (tally_spot() - _hero).normalized() * 9.0)
		_say("Tally", "One, two, three, four, five, six... SEVEN?! All at ONCE?!")
	if _once("never", T_TALLY + 3.0):
		_say("Tally", "That's never happened. Not ever. Not in all my clipboards!")
	if _once("title", T_TITLE):
		_caption.text = ""
		_show_title("The Night the Sky Cracked", "")


func _once(key: String, at: float) -> bool:
	if _t < at or _said.has(key):
		return false
	_said[key] = true
	return true


func _finish() -> void:
	_playing = false
	remove_from_group("cutscene_playing")
	_settle()
	if _old_cam and is_instance_valid(_old_cam):
		_old_cam.make_current()
	if cam and is_instance_valid(cam):
		cam.queue_free()
	cam = null
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()
	_reset_screen()
	Game.hold_controls(&"void_arrival", false)
	finished.emit()


func _settle() -> void:
	# The end state, however it got here: everyone's landed, the greeters are round them, Tally's waiting
	for l in _to_land:
		if is_instance_valid(l[0]):
			(l[0] as Node3D).visible = true
	_to_land.clear()
	for s in _streaks:
		if is_instance_valid(s[0]):
			(s[0] as Node3D).queue_free()
	_streaks.clear()
	for c in sky_cracks:
		c.scale = Vector3.ONE
	for g in greeters:
		g.visible = true
		g.global_position = g.get_meta("target")
		g.set_meta("go", -1.0)
		g.set_meta("there", true)
	if _tally and is_instance_valid(_tally):
		_tally.visible = true
		_tally.global_position = tally_spot()


# -----------------------------------------------------------------------------
# The sky's cracks, and the streaks of light
# -----------------------------------------------------------------------------
func _make_sky_cracks() -> void:
	# A jagged glowing tear in the green sky over each landing spot (the first one over the hero)
	var spots: Array[Vector3] = [_hero]
	for a in ARRIVALS:
		var p: Vector2 = a[2]
		spots.append(Vector3(p.x, 0, p.y))
	var eye := _square + Vector3(0, 4, 26)
	for i in spots.size():
		var c := _tear(i)
		_scene.add_child(c)
		var s: Vector3 = spots[i]
		c.global_position = Vector3(s.x + (s.x - _square.x) * 1.4, _square.y + SKY_HEIGHT + (i % 3) * 4.0,
			s.z + (s.z - _square.z) * 1.4 - 6.0)
		c.look_at(eye, Vector3.UP)
		c.rotate_object_local(Vector3.FORWARD, deg_to_rad(-30.0 + 60.0 * fmod(i * 0.37, 1.0)))
		sky_cracks.append(c)


func _tear(seed: int) -> Node3D:
	var crack := Node3D.new()
	crack.name = "Sky Crack %d" % (seed + 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.7, 1.0)
	m.emission_enabled = true
	m.emission = CRACK_COLOUR
	m.emission_energy_multiplier = 2.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + seed * 7
	var x := -7.0
	var y := 0.0
	while x < 7.0:
		var nx := x + rng.randf_range(1.2, 2.2)
		var ny := clampf(y + rng.randf_range(-1.4, 1.4), -2.2, 2.2)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var a := Vector2(x, y)
		var b := Vector2(nx, ny)
		bm.size = Vector3(a.distance_to(b) + 0.25, maxf(1.1 - absf(x) / 7.0, 0.18), 0.1)
		seg.mesh = bm
		seg.material_override = m
		seg.position = Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, 0)
		seg.rotation.z = (b - a).angle()
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.add_child(seg)
		x = nx
		y = ny
	return crack


func _streak(who: Node3D, at: Vector3) -> void:
	# A streak of light from its crack down to where they land
	var i := 0
	for l in _to_land:
		if l[0] == who:
			break
		i += 1
	var from: Vector3 = (sky_cracks[mini(i, sky_cracks.size() - 1)] as Node3D).global_position if not sky_cracks.is_empty() \
		else at + Vector3(0, SKY_HEIGHT, 0)
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 4.0
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.95, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.9, 0.75, 1.0)
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	_scene.add_child(mi)
	mi.global_position = from
	_streaks.append([mi, from, at, _t, who])


func _streak_step() -> void:
	for s in _streaks.duplicate():
		var mi := s[0] as MeshInstance3D
		if not is_instance_valid(mi):
			_streaks.erase(s)
			continue
		var k := clampf((_t - float(s[3])) / 0.8, 0.0, 1.0)
		var p: Vector3 = (s[1] as Vector3).lerp(s[2] as Vector3 + Vector3(0, 1.0, 0), k * k)
		mi.global_position = p
		var dir := ((s[2] as Vector3) - (s[1] as Vector3)).normalized()
		if dir.length() > 0.1:
			mi.look_at(p + dir, Vector3.RIGHT if absf(dir.y) < 0.99 else Vector3.FORWARD)
			mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		if k >= 1.0:
			var who := s[4] as Node3D
			if is_instance_valid(who):
				who.visible = true
				_landed.append(who)
			Fx.burst(_scene, (s[2] as Vector3) + Vector3(0, 0.6, 0), Color(0.9, 0.75, 1.0), 22, 0.1, 4.0, -3.0, 0.9)
			Juice.dust(_scene, s[2] as Vector3, 0.8)
			Juice.shake(0.12)
			mi.queue_free()
			_streaks.erase(s)


func _close_sky() -> void:
	for cc in sky_cracks:
		if is_instance_valid(cc):
			var c := cc as Node3D
			var tw := c.create_tween()
			tw.tween_property(c, "scale", Vector3(1, 0.01, 1), 2.5).set_ease(Tween.EASE_IN)
			tw.tween_callback(c.queue_free)
	sky_cracks.clear()


# -----------------------------------------------------------------------------
# The little aliens who come to say hello
# -----------------------------------------------------------------------------
func _spawn_greeters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var round_who: Array[Vector3] = []
	for k in HERO_GREETERS:
		round_who.append(_hero)
	var others: Array[Vector3] = []
	for a in ARRIVALS:
		var p: Vector2 = a[2]
		others.append(Vector3(p.x, 0, p.y))
	var k2 := 0
	while round_who.size() < GREETERS:
		round_who.append(others[k2 % others.size()])
		k2 += 1
	var count := {}
	for i in round_who.size():
		var c: Vector3 = round_who[i]
		var nth := int(count.get(c, 0))
		count[c] = nth + 1
		var many := HERO_GREETERS if c == _hero else 3
		var ang := TAU * float(nth) / float(many) + rng.randf_range(-0.2, 0.2) + (0.0 if c == _hero else 1.2)
		var r := (2.2 if c == _hero else 1.5) + rng.randf_range(0.0, 0.5)
		var target := _ground(c + Vector3(cos(ang), 0, sin(ang)) * r)
		var out := (target - _square) * Vector3(1, 0, 1)
		out = out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		var start := _ground(_square + out.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)) * rng.randf_range(22.0, 30.0))
		var g := _greeter(str(COLOURS[i % COLOURS.size()]))
		g.name = "Greeter %d" % (i + 1)
		_scene.add_child(g)
		g.global_position = target
		g.set_meta("start", start)
		g.set_meta("target", target)
		g.set_meta("friend", c)
		g.set_meta("go", -1.0)
		g.set_meta("there", true)
		g.set_meta("hop", rng.randf() * TAU)
		_face(g, c)
		greeters.append(g)


func _greeter(colour: String) -> Node3D:
	var holder := Node3D.new()
	holder.add_to_group("void_greeter")
	var packed := load("res://models/characters/little_alien_%s.glb" % colour) as PackedScene
	if packed:
		var m := packed.instantiate() as Node3D
		m.name = "Model"
		m.scale = Vector3.ONE * 1.2
		holder.add_child(m)
		LittleAliens.vary_snout(m)
	return holder


func _greeters_step(delta: float) -> void:
	if greeters.is_empty():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not _playing and not _scattering and player and _hero != Vector3.ZERO \
			and player.global_position.distance_to(_hero) > SCATTER_FAR:
		scatter()
	var now := _t if _playing else 1.0e9
	greeters = greeters.filter(func(n) -> bool: return is_instance_valid(n))
	for gg in greeters:
		var g := gg as Node3D
		var go := float(g.get_meta("go", -1.0))
		var target: Vector3 = g.get_meta("target")
		var friend: Vector3 = g.get_meta("friend")
		if _scattering:
			var away := (g.global_position - _square) * Vector3(1, 0, 1)
			g.global_position += away.normalized() * 5.0 * delta
			_anim(g, "run")
			continue
		if go >= 0.0 and now >= go and not bool(g.get_meta("there", false)):
			var to := target - g.global_position
			var step := 6.5 * delta
			if to.length() <= step:
				g.global_position = target
				g.set_meta("there", true)
			else:
				g.global_position += to.normalized() * step
				_face(g, target)
				_anim(g, "run")
				continue
		if not g.visible:
			continue
		if bool(g.get_meta("there", false)):
			# Waving at whoever they came to see (the hero, wherever they've walked to), with a happy little bounce
			var look_at := player.global_position if player and friend == _hero else friend
			_face(g, look_at)
			var hop := float(g.get_meta("hop")) + delta * 6.0
			g.set_meta("hop", hop)
			var m := g.get_node_or_null("Model") as Node3D
			if m:
				m.position.y = maxf(0.0, sin(hop)) * 0.18
			_anim(g, "wave")


func scatter() -> void:
	# Off they go, back to their lanes and rooftops (once the hero's talked to Tally, or walked off)
	if _scattering:
		return
	_scattering = true
	_close_sky()
	if _tally and is_instance_valid(_tally) and _tally.has_method("stand_by"):
		_tally.call("stand_by", Vector3.INF, Vector3.ZERO)
	for gg in greeters:
		if is_instance_valid(gg):
			var g := gg as Node3D
			var tw := g.create_tween()
			tw.tween_interval(randf_range(1.6, 2.6))
			tw.tween_property(g, "scale", Vector3.ONE * 0.01, 0.35)
			tw.tween_callback(g.queue_free)


func _on_flag(f: String) -> void:
	if f == TALLY_FLAG and not greeters.is_empty():
		scatter.call_deferred()
		# ...and a voice in their mind, for the first time (it's the Divine Mind's: never named in the game)
		DivineMind.say(["Don't be afraid. You're exactly where you're meant to be."])


func _anim(holder: Node3D, want: String) -> void:
	var a := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if a == null:
		return
	var use := want if a.has_animation(want) else ("walk" if want == "run" and a.has_animation("walk") else "idle")
	if not a.has_animation(use) or a.current_animation == use:
		return
	a.get_animation(use).loop_mode = Animation.LOOP_LINEAR
	a.play(use, 0.2)


func _face(n: Node3D, at: Vector3) -> void:
	var d := at - n.global_position
	if Vector2(d.x, d.z).length() > 0.05:
		n.rotation.y = atan2(d.x, d.z)


# -----------------------------------------------------------------------------
# The camera
# -----------------------------------------------------------------------------
func _place_camera() -> void:
	if cam == null:
		return
	var s := _square
	var to_sq := (s - _hero) * Vector3(1, 0, 1)
	to_sq = to_sq.normalized() if to_sq.length() > 0.1 else Vector3.BACK
	var side := to_sq.cross(Vector3.UP).normalized()
	if _t < T_CRACKS:
		# A quiet, slow drift over the square
		var k := _t / T_CRACKS
		_look(s + Vector3(lerpf(-6.0, 0.0, k), 11.0, 30.0), s + Vector3(0, 1.0, -4.0))
	elif _t < T_LAND - 0.4:
		# Tilting up to the sky as it splits
		var k := smoothstep(0.0, 1.0, (_t - T_CRACKS) / 1.6)
		_look(s + Vector3(0, lerpf(11.0, 4.0, k), lerpf(30.0, 24.0, k)),
			(s + Vector3(0, 1.0, -4.0)).lerp(s + Vector3(0, SKY_HEIGHT - 4.0, -8.0), k))
	elif _t < T_REX:
		# Wide and high as they fall and land
		var k := smoothstep(0.0, 1.0, (_t - T_LAND + 0.4) / 2.0)
		_look(s + Vector3(lerpf(0.0, 9.0, k), lerpf(4.0, 15.0, k), lerpf(24.0, 18.0, k)),
			(s + Vector3(0, SKY_HEIGHT * 0.5, -8.0)).lerp(s + Vector3(0, 0.5, -6.0), k))
	elif _t < T_ALIENS:
		# Rex, close (his ears)
		var rex := _who("rex")
		var at := rex.global_position if rex else s
		var front := (s - at) * Vector3(1, 0, 1)
		front = front.normalized() if front.length() > 0.1 else Vector3.BACK
		_look(at + front * 3.4 + front.cross(Vector3.UP) * 1.0 + Vector3(0, 1.4, 0), at + Vector3(0, 0.7, 0))
	elif _t < T_TALLY:
		# Down with the hero as the little aliens pour in round them
		var k := (_t - T_ALIENS) / (T_TALLY - T_ALIENS)
		_look(_hero + to_sq * 6.5 + side * lerpf(-2.5, 2.5, k) + Vector3(0, 2.6, 0), _hero + Vector3(0, 0.9, 0))
	elif _t < T_TITLE:
		# Tally running up
		var t_at := _tally.global_position if _tally and is_instance_valid(_tally) else _hero + to_sq * 3.0
		var mid := (_hero + t_at) * 0.5
		_look(mid + side * 6.0 + Vector3(0, 2.4, 0), mid + Vector3(0, 1.0, 0))
	else:
		# Up and away over everyone
		var k := smoothstep(0.0, 1.0, (_t - T_TITLE) / (LENGTH - T_TITLE))
		_look(s + Vector3(0, lerpf(14.0, 24.0, k), lerpf(22.0, 30.0, k)), s + Vector3(0, 0.5, -5.0))


func _look(at: Vector3, target: Vector3) -> void:
	cam.global_position = at
	if at.distance_to(target) > 0.01:
		cam.look_at(target, Vector3.UP)


# -----------------------------------------------------------------------------
# Bits and pieces
# -----------------------------------------------------------------------------
func _who(id: String) -> Node3D:
	if _scene == null or not is_instance_valid(_scene):
		return null
	for t in _scene.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t.get_parent() as Node3D
	return null


func _ground(at: Vector3) -> Vector3:
	var w := _scene.get_world_3d() if _scene and _scene.is_inside_tree() else null
	if w == null:
		return at
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 30.0, at.z), Vector3(at.x, at.y - 30.0, at.z))
	q.collide_with_areas = false
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := w.direct_space_state.intersect_ray(q)
	return hit.position if hit else at


func _hide_hud() -> void:
	_hidden.clear()
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	for c in p.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(c)


func _say(who: String, line: String) -> void:
	_caption.text = ("%s: %s" % [who, line]) if who != "" else line
	_caption.add_theme_font_size_override("font_size", int(34 * Settings.text_scale))
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.25)
	if who != "":
		Juice.blip("chime", 1.5, -16.0)


func _show_title(big: String, small: String) -> void:
	_title.text = big
	_sub.text = small
	_title.add_theme_font_size_override("font_size", int(64 * Settings.text_scale))
	for l in [_title, _sub]:
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.5)


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.06)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR
	r.anchor_bottom = BAR if top else 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.visible = false
	add_child(r)
	return r


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
