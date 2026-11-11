extends CanvasLayer

# Dash's goodbye at the Tomorrow Clock, the story's ending (Hayden, Nov 11, 2026: "we can add the ending next"; the
# story docs: "Dash learns he must repair the Shift, and the cost is never seeing his friends again", told
# "bittersweet with hope: he leaves something behind, or they'll meet again"). Played by scripts/far_future.gd when
# you walk up to Dash on the clock's dais once he's told everyone (flag "dash_told"). About a minute, and Jump,
# Interact or Accept skips straight to how it ends:
#
#   gather  (0 s)    the camera comes in over Lumen City to the clock; everyone who taught you a move comes through
#   talk    (3.5 s)  Dash says goodbye: to everyone, to Rex, and to you (he gives you his cap: shop/items.json dash_cap)
#   go      (43.5 s) he walks up to the clock, a door of light opens in its spire, he turns round and waves...
#   inside  (48.5 s) ...and steps through. The clock's faces blaze gold
#   beam    (49.5 s) a beam of gold goes up the spire into the sky: the far end of the Shift, being stitched
#   stitch  (52 s)   a golden seam draws itself across the sky, end to end, and the Shift is whole
#   title   (56 s)   "SEE YOU LATER" "Every goodbye is a see-you-later."
#
# Then the player has the controls back, the friends go home in a sparkle, and Dash's letter waits on his workbench
# (far_future.gd said_goodbye(), letter_lines()). Every line is a first draft for Hayden. Its own camera, a
# "dash_goodbye" hold on the controls, the HUD hidden and the minimap waiting (group "cutscene_playing"); the portal
# trip's timer stands still meanwhile (scripts/portals.gd), and the music is the Agent of Chaos's gentle ending tune
# (group "goodbye_playing", scripts/soundscape.gd).

signal done

const BAR := 0.11
const SKIP_ACTIONS := ["jump", "interact", "ui_accept"]
const T_TALK := 3.5
const LINE_TIME := 3.3
const T_GO := 43.5
const T_TURN := 46.0                 # he turns round at the door and waves
const T_IN := 48.5
const T_BEAM := 49.5
const T_STITCH := 52.0
const T_TITLE := 56.0
const LENGTH := 62.0
const CAP := "dash_cap"
const PLAYER_AT := Vector3(0, 0, 12.5)           # where the hero stands for it, from the clock
const DOOR_AT := Vector3(0, 0, 2.7)              # the door of light in the spire's front, from the clock
const SEAM_AT := Vector3(0, 62, -70)             # the golden seam in the sky, from the clock
# The friends who come through for it (Rex and Rook are already there: the world's own): [name, model, where from
# the clock]. A model is a .glb, or "script:method" for one made in code, as in scripts/chaos_ending.gd
const FRIENDS := [
	["Bramble", "res://models/characters/plant_girl.glb", Vector3(3.2, 0, 7.5)],
	["Pip", "res://models/characters/moth_kid.glb", Vector3(4.8, 0, 8.6)],
	["Melody", "res://models/characters/melody.glb", Vector3(-6.4, 0, 10.2)],
	["Heather", "res://models/characters/cattle_girl.glb", Vector3(6.4, 0, 10.2)],
	["Flurry", "res://scripts/frozen_moment.gd:flurry_model", Vector3(-7.4, 0, 12.6)],
	["Otto", "res://scripts/tide_reef.gd:otto_model", Vector3(7.4, 0, 12.6)],
]
# What's said (first drafts): [who, line]. Line GIFT_LINE is when he gives you his cap
const LINES := [
	["Dash", "Everyone came. Even Otto. His chair HATES stairs."],
	["Otto", "It's fine. I blew myself a bubble ramp."],
	["Dash", "I'm rubbish at speeches, so I'll be quick. When I go into the clock, the far end of the Shift gets stitched shut."],
	["Bramble", "And you can't come back through. Not ever?"],
	["Dash", "Not for a long, long time. But time goes round, Bramble. Like a wheel. And wheels come round."],
	["Pip", "Then this isn't goodbye. It's see you later."],
	["Flurry", "My watch stopped once. For ages. Then it started again. Yours will too."],
	["Dash", "Rex. You've got hands now. Look after the lab. And the stall. And Rook. And everyone."],
	["Rex", "...You're the annoying one. Who am I going to be annoyed at now?"],
	["Dash", "Mr. Palmer, probably. Practise on him. You're going to be a brilliant mayor."],
	["Dash", "{player}. You found me first, remember? Gold tyre tracks. Here. My cap. It's a time detective's cap now."],
	["Dash", "See you later, everyone."],
]
const GIFT_LINE := 10

var world: Node3D                                # scripts/far_future.gd
var cam: Camera3D
var root: Node3D
var friends: Array[Node3D] = []
var door: MeshInstance3D
var beam: MeshInstance3D
var seam: Node3D
var beat := ""                                   # which part it's on (for the tests)
var played := false

var _playing := false
var _t := 0.0
var _old_cam: Camera3D
var _hidden: Array = []
var _top: ColorRect
var _bottom: ColorRect
var _title: Label
var _sub: Label
var _caption: Label
var _skip: Label
var _shown_line := -1
var _c := Vector3.ZERO                           # the clock's foot
var _eye := Vector3.ZERO                         # where the camera's easing to, and what at
var _look_at := Vector3.ZERO
var _faces: Array[StandardMaterial3D] = []


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_top = _bar(true)
	_bottom = _bar(false)
	_title = _label(64, Color(1.0, 0.85, 0.35))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_top = -110
	_sub = _label(30, Color(1.0, 0.97, 0.88))
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_top = -20
	_caption = _label(34, Color(1.0, 0.97, 0.88))
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_bottom = -110
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.custom_minimum_size.x = 1000
	_skip = _label(20, Color(0.85, 0.85, 0.95))
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -24
	_skip.offset_bottom = -16
	for l in [_title, _sub, _caption]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.grow_vertical = Control.GROW_DIRECTION_END
	visible = false


func playing() -> bool:
	return _playing


# -----------------------------------------------------------------------------
# Playing it
# -----------------------------------------------------------------------------
func play() -> void:
	if _playing or world == null:
		return
	_c = world.get("CLOCK_AT")
	root = Node3D.new()
	root.name = "Goodbye Scene"
	world.add_child(root)
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "Goodbye Camera"
	cam.fov = 55.0
	cam.far = 1500.0
	root.add_child(cam)
	cam.make_current()
	_t = 0.0
	_shown_line = -1
	_playing = true
	played = true
	beat = "gather"
	visible = true
	add_to_group("cutscene_playing")
	add_to_group("goodbye_playing")
	_title.text = ""
	_sub.text = ""
	_caption.text = ""
	_skip.text = "%s to skip" % Settings.prompt("jump")
	var p := _player()
	if p:
		Game.hold_controls(&"dash_goodbye", true, p)
		p.global_position = world.call("ground_below", _c + PLAYER_AT + Vector3(0, 1.0, 0)) + Vector3(0, 0.1, 0)
		p.set("velocity", Vector3.ZERO)
		var visual := p.get_node_or_null("Visual") as Node3D
		if visual:
			visual.global_rotation.y = PI                    # facing the clock (-Z)
	_hide_hud()
	_place_world_friends()
	_spawn_friends()
	_say("", "(Everyone came to the Tomorrow Clock.)")
	_shot(_c + Vector3(0, 10, 34), _c + Vector3(0, 4, 6), true)


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_instance_valid(cam):
		_finish()
		return
	_t += delta
	for a in SKIP_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a) and _t > 1.0:
			skip()
			return
	_run_beats()
	if _t >= LENGTH:
		_finish()
		return
	_place_camera(delta)


func skip() -> void:
	# Straight to how it ends: whatever hasn't happened yet happens now (and the cap's still yours)
	if not _playing:
		return
	_t = LENGTH
	_run_beats()
	_finish()


func _run_beats() -> void:
	if _t >= T_TALK and beat == "gather":
		beat = "talk"
	if beat == "talk":
		var i := int((_t - T_TALK) / LINE_TIME)
		if i >= 0 and i < LINES.size() and i != _shown_line:
			_shown_line = i
			_say(LINES[i][0], LINES[i][1])
			if i == GIFT_LINE:
				_give_cap()
	if _t >= T_GO and beat == "talk":
		if _shown_line < GIFT_LINE:
			_give_cap()                                  # (skipped past it)
		beat = "go"
		_go()
	if _t >= T_TURN and beat == "go":
		beat = "turn"
		_turn_back()
	if _t >= T_IN and beat == "turn":
		beat = "inside"
		_step_in()
	if _t >= T_BEAM and beat == "inside":
		beat = "beam"
		_beam()
	if _t >= T_STITCH and beat == "beam":
		beat = "stitch"
		_stitch()
	if _t >= T_TITLE and beat == "stitch":
		beat = "title"
		_title_card()


func _finish() -> void:
	_playing = false
	visible = false
	beat = "done"
	remove_from_group("cutscene_playing")
	remove_from_group("goodbye_playing")
	for layer_node in _hidden:
		if is_instance_valid(layer_node):
			layer_node.visible = true
	_hidden.clear()
	for f in friends:
		if is_instance_valid(f):
			Fx.burst(world, f.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.5), 10, 0.1, 2.0, -1.0, 0.7)
	if is_instance_valid(root):
		root.queue_free()
	root = null
	friends.clear()
	cam = null
	if is_instance_valid(_old_cam):
		_old_cam.make_current()
	var p := _player()
	if p:
		Game.hold_controls(&"dash_goodbye", false, p)
	_give_cap()
	world.call("said_goodbye")
	Game.message("Dash has gone home to the furthest future. The Shift is whole again. (Dash's Cap is in your wardrobe.)")
	done.emit()


# -----------------------------------------------------------------------------
# The beats
# -----------------------------------------------------------------------------
func _place_world_friends() -> void:
	# Dash on the dais, Rex and Rook beside him (far_future.gd _to_the_clock()), everyone facing the way in
	world.call("_to_the_clock", false)
	_anim(world.get_node_or_null("Dash"), "idle")


func _spawn_friends() -> void:
	for i in FRIENDS.size():
		var info: Array = FRIENDS[i]
		var m := _friend_model(str(info[1]))
		if m == null:
			continue
		var holder := Node3D.new()
		holder.name = str(info[0])
		root.add_child(holder)
		holder.global_position = world.call("ground_below", _c + (info[2] as Vector3) + Vector3(0, 1.0, 0))
		holder.add_child(m)
		var look := _c + Vector3(0, 0, 5) - holder.global_position
		holder.rotation.y = atan2(look.x, look.z)
		holder.scale = Vector3.ONE * 0.01
		# (tweens on the friend itself, so a skip that tidies them away takes their tweens too)
		var tw := holder.create_tween()
		tw.tween_interval(0.4 + 0.25 * i)
		tw.tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			Fx.burst(world, holder.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.5), 14, 0.1, 2.5, -1.0, 0.8))
		_anim(holder, "idle")
		friends.append(holder)
	Juice.blip("sparkle", 1.2)


func _give_cap() -> void:
	if Game.has_item(CAP):
		return
	Game.give_item(CAP)
	var p := _player()
	if p and _playing and is_instance_valid(root):
		Fx.burst(root, p.global_position + Vector3(0, 1.8, 0), Color(0.55, 1.0, 0.4), 20, 0.08, 2.5, -1.0, 0.9)
		Juice.blip("chime", 1.2, -4.0)


func _go() -> void:
	# He walks up to the clock, and a door of light opens in its spire
	_caption.text = ""
	var dash := world.get_node_or_null("Dash") as Node3D
	_open_door()
	if dash:
		dash.rotation.y = PI
		var model := dash.get_node_or_null("Model") as Node3D
		if model:
			model.rotation.y = 0.0
		_anim(dash, "walk")
		var to: Vector3 = world.call("ground_below", _c + DOOR_AT + Vector3(0, 1.5, 0.4))
		var tw := dash.create_tween()
		tw.tween_property(dash, "global_position", to, 2.2).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func() -> void: _anim(dash, "idle"))
	for f in friends:
		_anim(f, "idle")
	Juice.blip("whoosh", 0.5, -6.0)


func _turn_back() -> void:
	# One last look back, and a wave
	var dash := world.get_node_or_null("Dash") as Node3D
	if dash:
		dash.create_tween().tween_property(dash, "rotation:y", 0.0, 0.5)
		world.call("_shout", dash, "See you later, {player}!")
	_say("Rex", "See you later, Dash.")


func _step_in() -> void:
	# Through the door of light: he goes small and bright and he's gone, and the clock's faces blaze gold
	_caption.text = ""
	var dash := world.get_node_or_null("Dash") as Node3D
	if dash:
		# (his talk spot goes first: physics can't squeeze a shape the way his model squeezes into the light)
		var spot := dash.get_node_or_null("Spot")
		if spot:
			spot.queue_free()
		var model := dash.get_node_or_null("Model") as Node3D
		var tw := dash.create_tween()
		tw.tween_property(dash, "rotation:y", PI, 0.3)
		if model:
			tw.tween_property(model, "scale", Vector3(0.05, 1.3, 0.05), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			Fx.burst(world, dash.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.9, 0.5), 40, 0.1, 3.0, 0.5, 1.2)
			dash.visible = false)
	for f in _clock_faces():
		create_tween().tween_property(f, "emission_energy_multiplier", 4.0, 1.2)
	Juice.blip("chime", 0.7)


func _beam() -> void:
	# A beam of gold up the spire into the sky: the far end of the Shift, being stitched from the inside
	if is_instance_valid(door):
		door.create_tween().tween_property(door, "scale", Vector3(0.01, 1.0, 1.0), 0.6)
	beam = MeshInstance3D.new()
	beam.name = "Beam"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.4
	cm.height = 1.0
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.85, 0.45, 0.7)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	beam.global_position = _c + Vector3(0, 1.0, 0)
	beam.scale = Vector3(1, 0.01, 1)
	var b := beam
	b.create_tween().tween_method(func(h: float) -> void:
		b.scale = Vector3(1, h, 1)
		b.global_position = _c + Vector3(0, h / 2.0, 0), 0.01, 260.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flash()
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.8)
	Juice.blip("sparkle", 0.8, -2.0)


func _stitch() -> void:
	# A golden seam draws itself across the sky, end to end, then breaks into sparkles: the Shift is whole
	_show_title("", "The far end of the Shift is stitched shut.")
	seam = Node3D.new()
	seam.name = "Seam"
	root.add_child(seam)
	seam.global_position = _c + SEAM_AT
	seam.look_at(_c + PLAYER_AT + Vector3(0, 2, 0), Vector3.UP)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.4)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := -60.0
	var y := 0.0
	var k := 0
	while x < 60.0:
		var nx := x + rng.randf_range(6.0, 10.0)
		var ny := clampf(y + rng.randf_range(-4.0, 4.0), -7.0, 7.0)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var a := Vector2(x, y)
		var b := Vector2(nx, ny)
		bm.size = Vector3(a.distance_to(b) + 0.6, 1.0, 0.3)
		seg.mesh = bm
		seg.material_override = m
		seg.position = Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, 0)
		seg.rotation.z = (b - a).angle()
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg.visible = false
		seam.add_child(seg)
		seg.create_tween().tween_callback(seg.show).set_delay(0.12 * k)
		x = nx
		y = ny
		k += 1
	var end := seam.create_tween()
	end.tween_interval(0.12 * k + 0.6)
	end.tween_callback(func() -> void:
		Fx.burst(world, seam.global_position, Color(1.0, 0.9, 0.55), 80, 0.6, 18.0, 0.0, 1.8)
		Juice.blip("sparkle", 1.0, -4.0))
	end.tween_property(seam, "scale", Vector3(1.0, 0.01, 1.0), 0.8)


func _title_card() -> void:
	_caption.text = ""
	_show_title("SEE YOU LATER", "Dash went home to the furthest future, to keep the Shift whole.\nEvery goodbye is a see-you-later.")
	for f in friends:
		_anim(f, "idle")
	var rex := world.get_node_or_null("Rex") as Node3D
	if rex:
		world.call("_shout", rex, "See you later...")


# -----------------------------------------------------------------------------
# The camera
# -----------------------------------------------------------------------------
func _place_camera(delta: float) -> void:
	var p := _player()
	var pp := p.global_position if p else _c + PLAYER_AT
	var dash := world.get_node_or_null("Dash") as Node3D
	var dp := dash.global_position if dash else _c + Vector3(0, 0.4, 5)
	match beat:
		"gather":
			var k := smoothstep(0.0, 1.0, _t / T_TALK)
			_shot(_c + Vector3(0, lerpf(14.0, 6.0, k), lerpf(40.0, 26.0, k)), _c + Vector3(0, lerpf(8.0, 2.5, k), 6))
		"talk":
			var who := str(LINES[maxi(_shown_line, 0)][0])
			var at := _who_at(who)
			if who == "Dash":
				# Over the hero's shoulder, at Dash
				_shot(pp + Vector3(1.4, 2.1, 2.6), dp + Vector3(0, 1.4, 0))
			else:
				# In front of whoever's talking, from Dash's side
				var to := (dp - at)
				to.y = 0.0
				to = to.normalized() if to.length() > 0.1 else Vector3.BACK
				_shot(at + to * 3.6 + Vector3(0, 1.8, 0) + to.cross(Vector3.UP) * 1.0, at + Vector3(0, 1.2, 0))
		"go", "turn":
			_shot(_c + Vector3(6.0, 3.0, 15.0), dp + Vector3(0, 1.4, 0))
		"inside", "beam":
			_shot(_c + Vector3(0, 3.0, 30.0), _c + Vector3(0, lerpf(4.0, 22.0, clampf((_t - T_IN) / 3.0, 0.0, 1.0)), 0))
		"stitch":
			var k := smoothstep(0.0, 1.0, (_t - T_STITCH) / 2.0)
			_shot(pp + Vector3(0, 2.5, 4.0), (_c + Vector3(0, 22, 0)).lerp(_c + SEAM_AT, k))
		"title":
			var k := (_t - T_TITLE) / (LENGTH - T_TITLE)
			_shot(pp + Vector3(lerpf(-5.0, 5.0, k), 4.5, 9.0), pp + Vector3(0, 1.8, -6.0))
	cam.global_position = cam.global_position.lerp(_eye, minf(1.0, delta * 2.5))
	var want := cam.global_transform.looking_at(_look_at, Vector3.UP) if cam.global_position.distance_to(_look_at) > 0.01 else cam.global_transform
	cam.global_basis = cam.global_basis.slerp(want.basis.orthonormalized(), minf(1.0, delta * 3.0)).orthonormalized()


func _shot(eye: Vector3, target: Vector3, snap := false) -> void:
	_eye = eye
	_look_at = target
	if snap and is_instance_valid(cam):
		cam.global_position = eye
		if eye.distance_to(target) > 0.01:
			cam.look_at(target, Vector3.UP)


func _who_at(who: String) -> Vector3:
	var n := world.get_node_or_null(who) as Node3D
	if n == null and is_instance_valid(root):
		n = root.get_node_or_null(who) as Node3D
	return n.global_position if n else _c + Vector3(0, 0, 8)


# -----------------------------------------------------------------------------
# Bits
# -----------------------------------------------------------------------------
func _open_door() -> void:
	door = MeshInstance3D.new()
	door.name = "Door Of Light"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 2.8, 0.12)
	door.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.92, 0.6, 0.9)
	door.material_override = m
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(door)
	door.global_position = world.call("ground_below", _c + DOOR_AT + Vector3(0, 1.5, 0)) + Vector3(0, 1.4, -0.2)
	door.scale = Vector3(0.01, 1.0, 1.0)
	door.create_tween().tween_property(door, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.5)
	l.light_energy = 3.0
	l.omni_range = 7.0
	l.position = Vector3(0, 0, 0.8)
	door.add_child(l)


func _clock_faces() -> Array[StandardMaterial3D]:
	# The clock's four faces, each given its own material first (the scene's is shared with the portal's preview)
	if _faces.is_empty():
		var clock := world.get_node_or_null("Tomorrow Clock")
		if clock:
			for n in clock.find_children("Face*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				var src := (mi.material_override if mi.material_override else mi.get_active_material(0)) as StandardMaterial3D
				if src == null:
					continue
				var m := src.duplicate() as StandardMaterial3D
				m.emission_enabled = true
				m.emission = Color(1.0, 0.82, 0.4)
				m.emission_energy_multiplier = 0.2
				mi.material_override = m
				_faces.append(m)
	return _faces


func _friend_model(source: String) -> Node3D:
	if source.contains(".gd:"):
		var bits := source.rsplit(":", true, 1)
		var s := load(bits[0]) as GDScript
		return s.call(bits[1]) as Node3D if s else null
	var packed := load(source) as PackedScene
	return packed.instantiate() as Node3D if packed else null


func _anim(holder: Node, want: String) -> void:
	if holder == null:
		return
	var a := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if a == null:
		return
	var use := want if a.has_animation(want) else ("idle" if a.has_animation("idle") else "")
	if use == "":
		return
	a.get_animation(use).loop_mode = Animation.LOOP_LINEAR
	a.play(use)


func _flash() -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(1.0, 0.9, 0.55, 0.2 if Settings.reduce_flashing else 0.6)
	add_child(r)
	move_child(r, 0)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 0.9)
	tw.tween_callback(r.queue_free)


func _say(who: String, line: String) -> void:
	var text := Settings.fill(line)
	_caption.text = ("%s: %s" % [who, text]) if who != "" else text
	_caption.add_theme_font_size_override("font_size", int(34 * Settings.text_scale))
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.25)
	if who != "":
		Juice.blip("chime", 1.5, -16.0)


func _show_title(big: String, small: String) -> void:
	_title.text = big
	_sub.text = small
	_title.add_theme_font_size_override("font_size", int(64 * Settings.text_scale))
	_sub.add_theme_font_size_override("font_size", int(30 * Settings.text_scale))
	for l in [_title, _sub]:
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.4)


func _hide_hud() -> void:
	_hidden.clear()
	var p := _player()
	if p == null:
		return
	for c in p.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(c)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.06)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR
	r.anchor_bottom = BAR if top else 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
