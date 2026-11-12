extends Node

# Autoload "HummingOak": the old oak on the green, where the door to the Void is (tools/build_earth.gd _portal builds
# the tree, its hollow, its runes and roots). On a new game's first day ("The First Night", res://quests/first_night.json)
# it's just a tree with a secret: listen to it and something ticks inside; three glowing acorns turn up round town
# (Mossy Falls, the pumpkin patch, Lookout Hill), and each one sets off a little tremor; laid in the nook in its roots
# at dusk, they wake the runes; and at midnight, when the player comes to it, the oak opens for the first time (the
# reveal: the camera swings round to the oak, fireflies spiral up the trunk, the runes light one by one, the roots lift
# and the ground in front of it cracks open: the way to the Void). After that the crack opens every Shift
# (scripts/earth_world.gd).
#
# Since 12 Nov 2026 (Hayden, lore bible v2) the oak hums because the **Divine Mind** is there, and once it's awake you
# can **touch it for a hint** about what to do next: the Divine Mind's voice answers in your mind (DivineMind.hint()).
#
# Old saves and anyone who isn't on the First Night's early steps find it awake already, so nobody is ever locked out.
# Everything is kept as Dialogue flags ("fn_oak_listen", "fn_acorn_1".."3", "fn_acorns", "fn_acorns_placed",
# "oak_woken"), so there's nothing of its own to save.

const EARTH := "res://scenes/earth/earth.tscn"
const ID := "first_night"
# The three acorns, the same spots as the quest's map stars ([x, z] on Earth; the ground's found under each)
const ACORNS := [Vector2(-97.5, -71.5), Vector2(-117, 30), Vector2(-106, -104)]
const ACORN_PLACES := ["by Mossy Falls", "in the pumpkin patch", "on top of Lookout Hill"]
# Steps of the First Night before the oak's woken (it's asleep for them), and the one where it wakes
const ASLEEP_STEPS := ["morning", "oak", "clues", "dusk", "wait", "awaken"]
const REVEAL_RANGE := 16.0         # metres from the oak at midnight that the reveal starts
const REVEAL_TIME := 8.0           # seconds the reveal lasts (Jump or Interact skips it)
const FLIES := 26

var revealing := false
var _scene: Node3D
var _oak: Node3D                   # "Portal Home/Old Oak"
var _spot: Area3D
var _rune_mat: StandardMaterial3D
var _rune_light: OmniLight3D
var _rune_glow := 0.0
var _flies: Array[MeshInstance3D] = []
var _fly_t := 0.0
var _fly_gather := 0.0             # 0: drifting about, 1: spiralling up the trunk (the reveal)
var _nook_acorns: Node3D
var _cam: Camera3D
var _old_cam: Camera3D
var _reveal_t := 0.0
var _caption_layer: CanvasLayer
var _caption: Label
var _roots: Array[Node3D] = []
var _root_rest: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Quests.changed.connect(func(q: String) -> void:
		if q == ID:
			_refresh())
	Dialogue.flag_set.connect(func(_f: String) -> void: _refresh())
	_build_caption()


# -----------------------------------------------------------------------------
# Is the oak awake?
# -----------------------------------------------------------------------------
func awake() -> bool:
	# Asleep only on a First Night that hasn't reached its door yet; awake for everyone else, for good
	if Dialogue.flags.has("oak_woken"):
		return true
	if not FirstNight.running():
		return true
	return not FirstNight.step() in ASLEEP_STEPS


func acorns_found() -> int:
	var n := 0
	for i in ACORNS.size():
		if Dialogue.flags.has("fn_acorn_%d" % (i + 1)):
			n += 1
	return n


func acorn_spot(i: int) -> Vector3:
	# Where acorn i sits, on the ground under its spot (in the Earth scene)
	var p: Vector2 = ACORNS[i]
	var at := Vector3(p.x, EarthLand.height(p.x, p.y), p.y)
	if _scene and _scene.is_inside_tree():
		var space := _scene.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 60.0, p.y), Vector3(p.x, -30.0, p.y))
		var hit := space.intersect_ray(q)
		if hit:
			at = hit.position
	return at + Vector3(0, 0.55, 0)


# -----------------------------------------------------------------------------
# Setting it up on Earth
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var s := get_tree().current_scene
	_scene = null
	_oak = null
	_flies.clear()
	_roots.clear()
	_root_rest.clear()
	revealing = false
	_caption_layer.visible = false
	if s == null or s.scene_file_path != EARTH:
		return
	_scene = s as Node3D
	_oak = s.get_node_or_null("Portal Home/Old Oak") as Node3D
	if _oak == null:
		return
	var rune := _oak.get_node_or_null("Oak Runes")
	if rune and rune.get_child_count() > 0:
		_rune_mat = (rune.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	_rune_light = _oak.get_node_or_null("Rune Glow") as OmniLight3D
	for r in _oak.get_node("Oak Roots").get_children():
		_roots.append(r as Node3D)
		_root_rest.append((r as Node3D).rotation.x)
	_spot = (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	_spot.name = "Oak Spot"
	_spot.set("verb", "listen to the old oak")
	_spot.set("radius", 1.8)
	_spot.set("jobs", self)
	_spot.position = Vector3(0.9, 0.0, 2.3)
	_oak.add_child(_spot)
	_nook_acorns = Node3D.new()
	_nook_acorns.name = "Nook Acorns"
	_oak.add_child(_nook_acorns)
	var nook := _oak.get_node("Acorn Nook") as Node3D
	for k in 3:
		var a := _acorn_mesh()
		a.position = nook.position + Vector3((k - 1) * 0.16, 0.0, (k % 2) * 0.08)
		_nook_acorns.add_child(a)
	var flies := Node3D.new()
	flies.name = "Fireflies"
	_oak.add_child(flies)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.85, 1.0, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(0.85, 1.0, 0.45)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	for k in FLIES:
		var f := MeshInstance3D.new()
		f.mesh = sm
		f.material_override = fm
		f.set_meta("seed", randf() * 100.0)
		flies.add_child(f)
		_flies.append(f)
	_refresh()


func _refresh() -> void:
	if _scene == null or not is_instance_valid(_scene) or _oak == null:
		return
	_place_acorns()
	if _nook_acorns:
		_nook_acorns.visible = Dialogue.flags.has("fn_acorns_placed")
	if _spot:
		var step := FirstNight.step() if FirstNight.running() else ""
		_spot.set("verb", {"oak": "listen to the old oak", "dusk": "put the acorns in the roots"}.get(step,
			"touch the old oak" if awake() else "look at the old oak"))


func _place_acorns() -> void:
	# Out only while the First Night's looking for them, one at each spot not found yet
	var on := FirstNight.running() and FirstNight.step() == "clues"
	for i in ACORNS.size():
		var n := _scene.get_node_or_null("Glowing Acorn %d" % (i + 1))
		var want := on and not Dialogue.flags.has("fn_acorn_%d" % (i + 1))
		if n and not want:
			n.queue_free()
		elif n == null and want:
			_scene.add_child(_acorn_pickup(i))


func _acorn_pickup(i: int) -> Area3D:
	var a := Area3D.new()
	a.name = "Glowing Acorn %d" % (i + 1)
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.1
	cs.shape = sh
	a.add_child(cs)
	var look := _acorn_mesh(2.6)
	look.name = "Look"
	a.add_child(look)
	# A soft glow round it and a faint beam of light up into the sky, so it can be spotted from a way off
	var halo := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.38
	hs.height = 0.76
	halo.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.6, 1.0, 0.45, 0.25)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo.material_override = hm
	halo.name = "Halo"
	a.add_child(halo)
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.05
	bc.bottom_radius = 0.14
	bc.height = 14.0
	beam.mesh = bc
	var bm := hm.duplicate() as StandardMaterial3D
	bm.albedo_color = Color(0.6, 1.0, 0.45, 0.18)
	beam.material_override = bm
	beam.position.y = 7.2
	a.add_child(beam)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 1.0, 0.55)
	l.light_energy = 1.4
	l.omni_range = 4.0
	a.add_child(l)
	a.set_meta("i", i)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_pick_up(i))
	a.ready.connect(func() -> void: a.global_position = acorn_spot(i), CONNECT_ONE_SHOT)
	return a


func _acorn_mesh(size := 1.0) -> Node3D:
	# An acorn that glows lime green: a nut, a cap with a stalk, made from shapes
	var n := Node3D.new()
	var nut := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07 * size
	s.height = 0.17 * size
	nut.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.95, 0.4)
	m.emission_enabled = true
	m.emission = Color(0.55, 1.0, 0.4)
	m.emission_energy_multiplier = 2.2
	nut.material_override = m
	n.add_child(nut)
	var cap := MeshInstance3D.new()
	var c := SphereMesh.new()
	c.radius = 0.08 * size
	c.height = 0.08 * size
	c.is_hemisphere = true
	cap.mesh = c
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.4, 0.27, 0.15)
	cap.material_override = cm
	cap.position.y = 0.045 * size
	n.add_child(cap)
	var stalk := MeshInstance3D.new()
	var st := CylinderMesh.new()
	st.top_radius = 0.008 * size
	st.bottom_radius = 0.012 * size
	st.height = 0.05 * size
	stalk.mesh = st
	stalk.material_override = cm
	stalk.position.y = 0.11 * size
	n.add_child(stalk)
	return n


func _pick_up(i: int) -> void:
	var f := "fn_acorn_%d" % (i + 1)
	if Dialogue.flags.has(f):
		return
	Dialogue.set_flag(f)
	var n := acorns_found()
	Juice.chime_pickup()
	if n >= ACORNS.size():
		Dialogue.set_flag("fn_acorns")
		Game.message("That's all three glowing acorns! They're warm, and they're ticking. Back to the old oak!")
	else:
		Game.message("A glowing acorn %s! It's ticking, like a tiny clock. (%d of %d)" % [ACORN_PLACES[i], n, ACORNS.size()])
	EarthTown.tremor()                                   # the ground answers with a little rumble


# -----------------------------------------------------------------------------
# Talking to the oak (its spot: scripts/request_spot.gd calls talk())
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	Dialogue.say(spot, "The Old Oak", lines(), "old_oak")


func lines() -> Array:
	var step := FirstNight.step() if FirstNight.running() else ""
	match step:
		"oak":
			Dialogue.set_flag("fn_oak_listen")
			return ["(You put your ear to the old oak's bark. It's cool and rough, and it smells of rain.)",
				"(Tick... tock... tick... Deep inside the trunk, something is ticking. Slowly. Like a giant clock.)",
				{"speaker": "Nina", "text": "You hear it too! I KNEW it. Trees don't tick. Not normal trees."},
				{"speaker": "Nina", "text": "Mr. Page at the bookshop has a book about everything. And Mr. Palmer gets the strangest post. I saw it on his porch."},
				{"speaker": "Nina", "text": "Oh! And something was glowing out by Mossy Falls this morning. Let's find out what's going on before midnight!"}]
		"clues":
			return ["(Tick... tock... The ticking's a little louder now. Faint carvings in the bark catch the light, then don't.)"]
		"dusk":
			if acorns_found() < ACORNS.size():
				return ["(There's a little nook in the roots beside a mossy stone, just the size for three acorns.)",
					"(You've found %d of the glowing acorns. The oak waits.)" % acorns_found()]
			Dialogue.set_flag("fn_acorns_placed")
			return ["(You lay the three glowing acorns in the nook in the roots, beside the mossy stone.)",
				"(One by one, their light sinks into the wood. Tick. Tock. TICK.)",
				"(All over the trunk, carvings you never noticed begin to glow: runes, spiralling up the old oak, round a dark hollow in its front.)",
				{"speaker": "Nina", "text": "{player}... look at it. It's never done THAT before. Whatever happens, it happens at midnight."}]
		"wait":
			return ["(The runes glow softly, green and gold, all the way up the trunk. The hum is getting louder.)"]
		"awaken":
			return ["(The whole oak is humming. Something is about to happen...)"]
	if not awake():
		return ["(It's a big old oak tree, much older than the town. Its leaves are every colour of autumn.)"]
	return touch_lines()


func touch_lines() -> Array:
	# Touching the awake oak: its hum goes right through you, and a voice in your mind gives a hint
	var out: Array = ["(You lay your hand on the old oak's bark. It's humming, deep and warm, and the hum goes right through you...)"]
	if not Dialogue.flags.has("oak_voice_heard"):
		Dialogue.set_flag("oak_voice_heard")
		out.append({"speaker": DivineMind.SPEAKER, "text": "Don't be afraid. I chose you, {player}. Whenever you're lost, come and touch the old oak, and I'll help you find the way."})
	for l in DivineMind.hint():
		out.append({"speaker": DivineMind.SPEAKER, "text": str(l)})
	return out


# -----------------------------------------------------------------------------
# Every frame: the runes, the fireflies, and the moment it wakes
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _oak == null or not is_instance_valid(_oak):
		return
	_fly_t += delta
	for i in ACORNS.size():                               # the acorns out round town bob and turn
		var n := _scene.get_node_or_null("Glowing Acorn %d" % (i + 1)) if _scene else null
		if n:
			var look := n.get_node("Look") as Node3D
			look.position.y = 0.12 * sin(_fly_t * 2.0 + i)
			look.rotation.y += delta * 1.2
			(n.get_node("Halo") as Node3D).scale = Vector3.ONE * (1.0 + 0.12 * sin(_fly_t * 3.0 + i))
	if revealing:
		_reveal_step(delta)
	elif FirstNight.running() and FirstNight.step() == "awaken" and Clock.in_shift() and _player_near(REVEAL_RANGE) \
			and not Dialogue.is_active():
		start_reveal()
	# The runes: dark asleep, a soft pulse once the acorns are in, bright in the Shift once it's awake
	var want := 0.0
	if revealing:
		want = _rune_glow
	elif awake():
		want = 2.4 if Clock.in_shift() else 0.35
	elif Dialogue.flags.has("fn_acorns_placed"):
		want = 0.9 + (0.0 if Settings.reduce_flashing else 0.35 * sin(_fly_t * 2.0))
	if not revealing:
		_rune_glow = move_toward(_rune_glow, want, delta * 1.5)
	if _rune_mat:
		_rune_mat.emission_energy_multiplier = _rune_glow
	if _rune_light:
		_rune_light.light_energy = _rune_glow * 0.9
		_rune_light.visible = _rune_glow > 0.01
	_fireflies(delta)


func _player_near(r: float) -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and _oak != null and Vector2(p.global_position.x - _oak.global_position.x,
		p.global_position.z - _oak.global_position.z).length() < r


func _fireflies(delta: float) -> void:
	# Fireflies drift round the oak at night (more once it's stirring); in the reveal they spiral up the trunk
	var night := Clock.earth_minutes >= 19 * 60.0 or Clock.earth_minutes < 5 * 60.0
	var show := revealing or (night and (Dialogue.flags.has("fn_acorns_placed") or awake()))
	_fly_gather = move_toward(_fly_gather, 1.0 if revealing else 0.0, delta * 0.6)
	for k in _flies.size():
		var f := _flies[k]
		f.visible = show
		if not show:
			continue
		var sd := float(f.get_meta("seed"))
		var t := _fly_t * 0.4 + sd
		var drift := Vector3(sin(t * 1.3) * 2.8 + cos(t * 0.7 + sd) * 1.2, 1.2 + sin(t * 0.9) * 0.9 + 0.6 * sin(sd),
			cos(t * 1.1) * 2.8 + sin(t * 0.5) * 1.2)
		drift += drift.normalized() * 1.2 * signf(drift.length() - 1.6)
		var a := _fly_t * 2.2 + k * TAU / _flies.size()
		var climb := fmod(_fly_t * 0.9 + float(k) / _flies.size() * 7.0, 7.0)
		var spiral := Vector3(cos(a) * (1.75 - climb * 0.08), 0.3 + climb, sin(a) * (1.75 - climb * 0.08))
		f.position = drift.lerp(spiral, smoothstep(0.0, 1.0, _fly_gather))


# -----------------------------------------------------------------------------
# The reveal
# -----------------------------------------------------------------------------
func start_reveal() -> void:
	if revealing or _oak == null:
		return
	revealing = true
	_reveal_t = 0.0
	_rune_glow = 0.0
	Game.hold_controls(&"oak_reveal", true)
	_old_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.name = "Oak Reveal Camera"
	_cam.fov = 60.0
	_scene.add_child(_cam)
	if _old_cam:
		_cam.global_transform = _old_cam.global_transform
	_cam.make_current()
	_caption.text = "The old oak is waking up..."
	_caption.modulate.a = 0.0
	_caption_layer.visible = true
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.6)
	Audio.play("beam", -8.0, 0.0)


func _reveal_step(delta: float) -> void:
	_reveal_t += delta
	var t := _reveal_t
	# The camera: from the player's view round to the front of the oak, looking at its foot, where the ground cracks
	var front := _oak.global_transform * Vector3(2.0, 3.6, 10.0)
	var look := _oak.global_transform * Vector3(0.0, 1.0, 3.8)
	if _old_cam and is_instance_valid(_old_cam):
		var k := smoothstep(0.0, 2.2, t)
		var from := _old_cam.global_position
		var at := from.lerp(front, k)
		var aim := (_old_cam.global_position - _old_cam.global_basis.z * 5.0).lerp(look, k)
		_cam.global_position = at
		_cam.look_at(aim, Vector3.UP)
	# The runes light up from the foot of the trunk, one burst after another
	if t > 1.8:
		_rune_glow = move_toward(_rune_glow, 3.0, delta * 1.6)
	# The roots lift and shudder, then settle
	var lift := 0.0
	if t > 3.2 and t < 6.5:
		lift = sin(clampf((t - 3.2) / 3.3, 0.0, 1.0) * PI) * 0.32
	for i in _roots.size():
		var wob := 0.0 if Settings.reduce_motion else sin(t * 9.0 + i) * 0.03 * signf(lift)
		_roots[i].rotation.x = _root_rest[i] - lift - wob
	if t > 3.2 and t - delta <= 3.2:
		Juice.shake(0.45)
		Juice.rumble(0.5, 0.6)
		_caption.text = "The roots are moving!"
	if t > 5.0 and not Dialogue.flags.has("oak_woken"):
		Dialogue.set_flag("oak_woken")                    # the ground cracks open (scripts/earth_world.gd)
		Audio.play("level_up", -6.0, 0.0)
		Juice.shake(0.35)
		_caption.text = "The ground in front of the oak is cracking open!"
	if t >= REVEAL_TIME or (t > 0.5 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact"))):
		_end_reveal()


func _end_reveal() -> void:
	if not Dialogue.flags.has("oak_woken"):
		Dialogue.set_flag("oak_woken")
	revealing = false
	for i in _roots.size():
		_roots[i].rotation.x = _root_rest[i]
	if _old_cam and is_instance_valid(_old_cam):
		_old_cam.make_current()
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	Game.hold_controls(&"oak_reveal", false)                   # (a talk going on keeps its own hold)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void: _caption_layer.visible = false)
	Quests.check()                                        # (the quest banner says what to do next)


func _build_caption() -> void:
	_caption_layer = CanvasLayer.new()
	_caption_layer.layer = 47
	_caption_layer.visible = false
	add_child(_caption_layer)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_left = -500
	_caption.offset_right = 500
	_caption.offset_top = -300
	_caption.offset_bottom = -240
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_color_override("font_color", Color(1, 0.97, 1))
	_caption.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.25))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption_layer.add_child(_caption)
