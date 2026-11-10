extends CanvasLayer

# The ending cutscene of the Agent of Chaos's final fight (scripts/chaos_fight.gd), played the first time his chaos
# runs out (Hayden, Nov 10, 2026: "Okay lets do it", after the friends' sections). About 34 seconds, and Jump,
# Interact or Accept skips straight to how it ends:
#
#   crack    (0 s)   the camera comes in on his chest clock; it cracks, flickering, time stuttering
#   shatter  (3 s)   it shatters into glitch cubes and a golden ring of mended time rolls out over the field
#   fade     (6 s)   he sinks to his knees and his glitch armour peels away, smaller and smaller...
#   light    (10 s)  ...till only a small figure of light is left. It looks at the hero, then drifts up into motes,
#                    and something small drops into the grass: an old pocket watch, stopped at midnight
#   sky      (14.5 s) the crack in the sky over the field (the crack in the Shift) zips shut in a flash of gold
#   friends  (18.5 s) everyone who taught you a move comes through to the field, and Dash, Rex, Bramble and Pip talk
#   title    (30 s)  "The Agent of Chaos is sent out of time. The Void is safe... for now."
#
# Then the player has the controls back, with the friends still standing round for a while (they fade away once
# you've walked off), and the pocket watch to pick up (flag "chaos_watch_found"; it waits in the field on later visits
# until it's found). Who the figure of light was is left a mystery on purpose: it's a first draft for Hayden, like
# every line here.
#
# It uses its own camera, so the player's camera is untouched; the player's HUD steps away and the minimap waits
# (group "cutscene_playing", scripts/map_screen.gd). The music is "chaos_ending" while it plays (scripts/soundscape.gd).

signal done

const BAR := 0.11
const SKIP_ACTIONS := ["jump", "interact", "ui_accept"]
const T_SHATTER := 3.0
const T_FADE := 6.0
const T_LIGHT := 10.0
const T_SKY := 14.5
const T_FRIENDS := 18.5
const T_TITLE := 30.5
const LENGTH := 34.5
const LINE_TIME := 2.4
const CRACK_HEIGHT := 70.0                       # the crack in the sky, over his field
const FRIEND_FADE_FAR := 30.0                    # the friends go once you're this far off
const WATCH_FLAG := "chaos_watch_found"
const FRIENDS := [
	# [name, model (a .glb, or "script:method" for one made in code), line said in the friends' beat or ""]
	["Dash", "res://models/characters/bike_boy.glb"],
	["Rex", "res://models/characters/wolf.glb"],
	["Rook", "res://models/characters/rook.glb"],
	["Bramble", "res://models/characters/plant_girl.glb"],
	["Flurry", "res://scripts/frozen_moment.gd:flurry_model"],
	["Pip", "res://models/characters/moth_kid.glb"],
	["Melody", "res://models/characters/melody.glb"],
	["Otto", "res://scripts/tide_reef.gd:otto_model"],
	["Heather", "res://models/characters/cattle_girl.glb"],
]
# What's said when the friends arrive (first drafts): [who, line]
const LINES := [
	["Dash", "His clock's stopped. All the broken time he was holding just... let go."],
	["Rex", "The knot in my tummy's gone! Dash. DASH. Does this mean...?"],
	["Dash", "It means the Swap-o-Tron can finally finish what it started. Soon, Rex. I promise."],
	["Bramble", "The whole hive felt that, all the way from the Rootmind. Every plant just breathed out."],
	["Pip", "And look up. The sky's mended. We did that. All of us, together."],
]

var fight: Node                                  # scripts/chaos_fight.gd
var off := false                                 # tests that don't want the cutscene (tools/test_chaos_fight.gd)
var cam: Camera3D
var root: Node3D                                 # everything the cutscene puts in the scene
var friends: Array[Node3D] = []
var watch: Node3D
var figure: Node3D
var crack: Node3D
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
var _cubes: Array[Node3D] = []
var _model: Node3D
var _model_scale := Vector3.ONE
var _g := Vector3.ZERO                           # where he stood
var _f := Vector3.FORWARD                        # the way he faced
var _shown_line := -1
var _next_crack := 0.0
var _friends_from := Vector3.ZERO
var _cube_mats: Array[StandardMaterial3D] = []


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
	for c in [Color(0.62, 0.25, 0.95), Color(0.95, 0.35, 0.75), Color(0.35, 0.95, 0.9), Color(1.0, 0.82, 0.35)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
		_cube_mats.append(m)
	visible = false


func playing() -> bool:
	return _playing


# -----------------------------------------------------------------------------
# Playing it
# -----------------------------------------------------------------------------
func play() -> void:
	var giant := fight.get("giant") as Node3D
	_g = giant.global_position
	_f = giant.global_basis.z.normalized()
	_f.y = 0.0
	_f = _f.normalized() if _f.length() > 0.01 else Vector3.FORWARD
	_model = giant.get_node_or_null("Model") as Node3D
	if _model:
		_model_scale = _model.scale
	var scene := giant.get_tree().current_scene
	root = Node3D.new()
	root.name = "Chaos Ending"
	scene.add_child(root)
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "Chaos Ending Camera"
	cam.fov = 55.0
	cam.far = 1500.0
	root.add_child(cam)
	cam.make_current()
	_clear_fight_bits()
	_make_crack()
	_t = 0.0
	_next_crack = 0.0
	_shown_line = -1
	_playing = true
	played = true
	beat = "crack"
	visible = true
	add_to_group("cutscene_playing")
	_title.text = ""
	_sub.text = ""
	_caption.text = ""
	_skip.text = "%s to skip" % Settings.prompt("jump")
	Game.hold_controls(&"chaos_ending", true)
	_hide_hud()
	var anim := _model.find_child("AnimationPlayer", true, false) as AnimationPlayer if _model else null
	if anim:
		anim.speed_scale = 0.25                  # time's stuttering: he moves like he's stuck in it
	_place_camera()


func _process(delta: float) -> void:
	if not _playing:
		_tidy_friends()
		_check_watch()
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
	_place_camera()


func skip() -> void:
	# Straight to how it ends: whatever hasn't happened yet happens now
	if not _playing:
		return
	_t = LENGTH
	_run_beats()
	_finish()


func _run_beats() -> void:
	# Each beat starts once; skipping runs every beat not yet run, in order
	if _t >= 0.0 and _t < T_SHATTER and _t >= _next_crack:
		_next_crack += 0.6
		_crackle()
	if _t >= T_SHATTER and beat == "crack":
		beat = "shatter"
		_shatter()
	if _t >= T_FADE and beat == "shatter":
		beat = "fade"
		_fade_out()
	if _t >= T_LIGHT and beat == "fade":
		beat = "light"
		_light()
	if _t >= T_SKY and beat == "light":
		beat = "sky"
		_mend_sky()
	if _t >= T_FRIENDS and beat == "sky":
		beat = "friends"
		_bring_friends()
	if beat == "friends" or beat == "title":
		var i := int((_t - T_FRIENDS - 1.2) / LINE_TIME)
		if i >= 0 and i < LINES.size() and i != _shown_line and _t < T_TITLE:
			_shown_line = i
			_say(LINES[i][0], LINES[i][1])
	if _t >= T_TITLE and beat == "friends":
		beat = "title"
		_title_card()


func _finish() -> void:
	_playing = false
	visible = false
	beat = "done"
	remove_from_group("cutscene_playing")
	for layer_node in _hidden:
		if is_instance_valid(layer_node):
			layer_node.visible = true
	_hidden.clear()
	for c in _cubes:
		if is_instance_valid(c):
			c.queue_free()
	_cubes.clear()
	if is_instance_valid(figure):
		figure.queue_free()
	if is_instance_valid(crack):
		crack.queue_free()
	if is_instance_valid(cam):
		cam.queue_free()
	cam = null
	if is_instance_valid(_old_cam):
		_old_cam.make_current()
	Game.hold_controls(&"chaos_ending", false)
	var p := _player()
	if p and _friends_from != Vector3.ZERO:
		Game.message("The friends who taught you every move are here with you. Go and say hi... or just look at the sky.")
	done.emit()


# -----------------------------------------------------------------------------
# The beats
# -----------------------------------------------------------------------------
func _crackle() -> void:
	# His clock cracks: a flicker of the glow, a spit of glitch cubes and a tick
	var heart: Vector3 = fight.call("heart_position")
	Fx.burst(root, heart, Color(0.75, 0.3, 1.0), 8, 0.12, 3.0, -1.0, 0.6)
	_cube_spray(heart, 3, 4.0)
	Juice.blip("tick", 0.8)
	Juice.shake(0.15)


func _shatter() -> void:
	var heart: Vector3 = fight.call("heart_position")
	Juice.hitstop(0.1)
	Juice.shake(0.8)
	Juice.rumble(0.9, 0.6, 0.9)
	for i in 4:
		Fx.burst(root, heart + Vector3(randf_range(-2, 2), randf_range(-2, 3), randf_range(-2, 2)),
			[Color(0.75, 0.3, 1.0), Color(1.0, 0.8, 0.3), Color(0.4, 1.0, 0.9), Color(1.0, 0.4, 0.6)][i], 24, 0.2,
			5.0, -1.0, 1.2)
	_cube_spray(heart, 40, 9.0)
	_ring()
	Audio.play("pop", 2.0, 0.0)
	Juice.blip("thud", 0.6, -2.0)
	_show_title("CRACK!", "His clock shatters!")


func _fade_out() -> void:
	# He sinks down and his glitch armour peels away, till only a small figure of light is left
	_title_out()
	if _model:
		var tw := create_tween()
		tw.tween_property(_model, "scale", _model_scale * Vector3(1.06, 0.55, 1.06), 1.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_model, "scale", _model_scale * 0.13, 2.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for i in 6:
		get_tree().create_timer(0.55 * i).timeout.connect(func() -> void:
			if is_instance_valid(root):
				var k := 1.0 - 0.15 * i
				_cube_spray(_g + Vector3(0, 4.0 * k + 1.0, 0) + _f * 0.8, 6, 5.0))
	figure = _figure()
	figure.global_position = _g + _f * 0.6
	figure.scale = Vector3.ONE * 0.01
	var grow := create_tween()
	grow.tween_interval(2.6)
	grow.tween_property(figure, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_SINE)
	Juice.blip("whoosh", 0.7)


func _light() -> void:
	# He's gone; the little figure of light looks at the hero, then drifts up and away, and something drops
	var giant := fight.get("giant") as Node3D
	giant.visible = false
	giant.remove_from_group("map_landmarks")
	if _model:
		_model.scale = _model_scale
	if is_instance_valid(figure):
		var p := _player()
		if p:
			var to := p.global_position - figure.global_position
			figure.rotation.y = atan2(to.x, to.z)
		var tw := create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(figure, "position:y", figure.position.y + 6.0, 2.2).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(figure, "scale", Vector3(0.2, 1.6, 0.2), 2.2)
		tw.tween_callback(func() -> void:
			if is_instance_valid(figure):
				Fx.burst(root, figure.global_position, Color(0.85, 0.8, 1.0), 30, 0.1, 2.0, 0.5, 1.6)
				figure.visible = false)
	place_watch(_g + _f * 1.4)
	Juice.blip("chime", 0.8)
	_say("", "...")


func _mend_sky() -> void:
	# The crack in the sky over his field zips shut, and time ripples out gold
	_caption.text = ""
	_show_title("", "All the broken time comes loose.")
	if is_instance_valid(crack):
		var tw := create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(crack, "scale", Vector3(0.01, 1.0, 1.0), 1.4).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(crack):
				Fx.burst(root, crack.global_position, Color(1.0, 0.85, 0.4), 60, 0.6, 14.0, 0.0, 1.6)
				crack.visible = false
				_flash()
				Juice.shake(0.3)
				Juice.blip("sparkle", 1.0, -4.0))


func _bring_friends() -> void:
	_title_out()
	_spawn_friends()


func _title_card() -> void:
	_caption.text = ""
	_show_title("THE AGENT OF CHAOS", "is sent out of time.\nThe Void is safe... for now.")
	for f in friends:
		_anim(f, "dance" if f.name == "Melody" else "idle")
	var p := _player()
	if p:
		for i in 5:
			get_tree().create_timer(0.5 * i).timeout.connect(func() -> void:
				if is_instance_valid(root):
					Fx.burst(root, p.global_position + Vector3(randf_range(-8, 8), randf_range(7, 12), randf_range(-8, 8)),
						[Color(1.0, 0.8, 0.3), Color(0.5, 1.0, 0.9), Color(1.0, 0.45, 0.75)][i % 3], 40, 0.18, 6.0, -2.0, 1.4))


# -----------------------------------------------------------------------------
# The friends
# -----------------------------------------------------------------------------
func _spawn_friends() -> void:
	if not friends.is_empty():
		return
	var p := _player()
	var from := p.global_position if p else _g + _f * 16.0
	_friends_from = from
	var to_him := _g - from
	to_him.y = 0.0
	to_him = to_him.normalized() if to_him.length() > 0.1 else -_f
	var side := to_him.cross(Vector3.UP).normalized()
	var n := FRIENDS.size()
	for i in n:
		var info: Array = FRIENDS[i]
		var m := _friend_model(str(info[1]))
		if m == null:
			continue
		var k := (float(i) / float(n - 1)) * 2.0 - 1.0              # -1..1 across the arc
		var at := from - to_him * (3.5 + 2.0 * (1.0 - absf(k))) + side * k * 7.0
		var holder := Node3D.new()
		holder.name = str(info[0])
		root.add_child(holder)
		holder.global_position = fight.call("_ground", at) + Vector3(0, 0.05, 0)
		holder.add_child(m)
		var look := from + to_him * 6.0 - holder.global_position
		holder.rotation.y = atan2(look.x, look.z)
		holder.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if is_instance_valid(holder):
				Fx.burst(root, holder.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.5), 14, 0.1, 2.5, -1.0, 0.8))
		_anim(holder, "wave" if str(info[0]) in ["Dash", "Pip"] else "idle")
		friends.append(holder)
	Juice.blip("sparkle", 1.2)


func _friend_model(source: String) -> Node3D:
	if source.contains(".gd:"):
		var bits := source.rsplit(":", true, 1)
		var s := load(bits[0]) as GDScript
		if s == null:
			return null
		return s.call(bits[1]) as Node3D
	var packed := load(source) as PackedScene
	return packed.instantiate() as Node3D if packed else null


func _anim(holder: Node3D, want: String) -> void:
	var a := holder.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if a == null:
		return
	var use := want if a.has_animation(want) else ("idle" if a.has_animation("idle") else "")
	if use == "":
		return
	a.get_animation(use).loop_mode = Animation.LOOP_LINEAR
	a.play(use)


func _tidy_friends() -> void:
	# Once the player's walked off, the friends go home (a little sparkle each)
	if friends.is_empty():
		return
	var p := _player()
	if p and p.global_position.distance_to(_friends_from) < FRIEND_FADE_FAR:
		return
	for f in friends:
		if is_instance_valid(f):
			Fx.burst(root, f.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.9, 0.5), 10, 0.1, 2.0, -1.0, 0.7)
			f.queue_free()
	friends.clear()


# -----------------------------------------------------------------------------
# The pocket watch he leaves behind
# -----------------------------------------------------------------------------
func place_watch(at: Vector3) -> void:
	if Dialogue.flags.has(WATCH_FLAG) or is_instance_valid(watch):
		return
	var scene := fight.get_tree().current_scene
	if root == null or not is_instance_valid(root):
		root = Node3D.new()
		root.name = "Chaos Ending"
		scene.add_child(root)
	watch = _watch_model()
	watch.name = "Stopped Watch"
	root.add_child(watch)
	watch.global_position = fight.call("_ground", at) + Vector3(0, 0.35, 0)


func _check_watch() -> void:
	if not is_instance_valid(watch):
		return
	watch.rotation.y += get_process_delta_time() * 1.2
	var p := _player()
	if p == null or p.global_position.distance_to(watch.global_position) > 1.6:
		return
	Dialogue.set_flag(WATCH_FLAG)
	Fx.burst(root, watch.global_position, Color(0.85, 0.8, 1.0), 16, 0.1, 2.0, -1.0, 0.8)
	Juice.blip("chime", 1.2, -4.0)
	Game.message("A little old pocket watch, stopped at midnight. It's still warm. Whose was it...?")
	watch.queue_free()
	watch = null


func _watch_model() -> Node3D:
	var g := Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.68, 0.3)
	gold.metallic = 0.8
	gold.roughness = 0.3
	var case := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.22
	cm.bottom_radius = 0.22
	cm.height = 0.07
	case.mesh = cm
	case.material_override = gold
	case.rotation.x = PI / 2.0
	g.add_child(case)
	var face := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.18
	fm.bottom_radius = 0.18
	fm.height = 0.075
	face.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.95, 0.92, 1.0)
	fmat.emission_enabled = true
	fmat.emission = Color(0.8, 0.75, 1.0)
	fmat.emission_energy_multiplier = 0.6
	face.material_override = fmat
	face.rotation.x = PI / 2.0
	g.add_child(face)
	for hand in [[0.14, 0.0], [0.1, 0.0]]:                     # both hands on twelve: stopped at midnight
		var h := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.02, hand[0], 0.01)
		h.mesh = bm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.15, 0.1, 0.25)
		h.material_override = hm
		h.position = Vector3(0, hand[0] / 2.0, 0.045)
		g.add_child(h)
	var bow := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.04
	tm.outer_radius = 0.065
	bow.mesh = tm
	bow.material_override = gold
	bow.rotation.x = PI / 2.0
	bow.position = Vector3(0, 0.27, 0)
	g.add_child(bow)
	var glint := OmniLight3D.new()
	glint.light_color = Color(0.85, 0.8, 1.0)
	glint.light_energy = 1.2
	glint.omni_range = 2.5
	g.add_child(glint)
	return g


# -----------------------------------------------------------------------------
# Bits
# -----------------------------------------------------------------------------
func _clear_fight_bits() -> void:
	# Bursts still waiting to go off, and rings still rolling, would bump the hero mid-cutscene
	for n in get_tree().current_scene.find_children("*", "", true, false):
		if n is ChaosBurst or n is ShockRing:
			n.queue_free()


func _cube_spray(at: Vector3, count: int, speed: float) -> void:
	for i in count:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.15, 0.45)
		bm.size = Vector3(s, s, s)
		c.mesh = bm
		c.material_override = _cube_mats[i % _cube_mats.size()]
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(c)
		c.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 1.0), randf_range(-1, 1)).normalized()
		var end := at + dir * speed * randf_range(0.6, 1.0)
		end.y = maxf(end.y - randf_range(1.0, 4.0), _g.y + 0.2)
		var tw := c.create_tween()
		tw.tween_property(c, "global_position", end, randf_range(0.8, 1.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 1.2)
		tw.tween_property(c, "scale", Vector3.ONE * 0.01, 0.6)
		tw.tween_callback(c.queue_free)
		_cubes.append(c)
	var live: Array[Node3D] = []
	for n in _cubes:
		if is_instance_valid(n):
			live.append(n)
	_cubes = live


func _ring() -> void:
	# A golden ring of mended time rolls out over the field
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	r.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(r)
	r.global_position = _g + Vector3(0, 0.6, 0)
	r.scale = Vector3(1, 0.5, 1)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector3(45, 2.0, 45), 2.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 2.6)
	tw.tween_callback(r.queue_free)


func _figure() -> Node3D:
	# A small figure of light, about a child's height: a soft glow, no face. Who it was is a mystery (for now)
	var g := Node3D.new()
	g.name = "Figure Of Light"
	root.add_child(g)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.85, 1.0, 0.75)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.32
	cm.height = 1.1
	body.mesh = cm
	body.material_override = m
	body.position = Vector3(0, 0.6, 0)
	g.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	head.mesh = sm
	head.material_override = m
	head.position = Vector3(0, 1.4, 0)
	g.add_child(head)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 1.0
	hm.height = 2.0
	halo.mesh = hm
	var hmat := m.duplicate() as StandardMaterial3D
	hmat.albedo_color = Color(0.8, 0.7, 1.0, 0.18)
	halo.material_override = hmat
	halo.position = Vector3(0, 0.9, 0)
	g.add_child(halo)
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.8, 1.0)
	l.light_energy = 3.0
	l.omni_range = 6.0
	l.position = Vector3(0, 1.0, 0)
	g.add_child(l)
	return g


func _make_crack() -> void:
	# The crack in the Shift, high over his field: a jagged glowing purple tear across the sky
	crack = Node3D.new()
	crack.name = "Sky Crack"
	root.add_child(crack)
	crack.global_position = _g + _f * 10.0 + Vector3(0, CRACK_HEIGHT, 0)
	crack.look_at(crack.global_position + _f, Vector3.UP)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.45, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.45, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var x := -40.0
	var y := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while x < 40.0:
		var nx := x + rng.randf_range(5.0, 9.0)
		var ny := clampf(y + rng.randf_range(-5.0, 5.0), -8.0, 8.0)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var a := Vector2(x, y)
		var b := Vector2(nx, ny)
		var thick := 1.6 - absf(x) / 40.0
		bm.size = Vector3(a.distance_to(b) + 0.6, maxf(thick, 0.3), 0.2)
		seg.mesh = bm
		seg.material_override = m
		seg.position = Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, 0)
		seg.rotation.z = (b - a).angle()
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.add_child(seg)
		x = nx
		y = ny


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


func _place_camera() -> void:
	var heart: Vector3 = fight.call("heart_position")
	var side := _f.cross(Vector3.UP).normalized()
	var p := _player()
	var pp := p.global_position if p else _g + _f * 16.0
	if _t < T_SHATTER:
		# In close on his chest clock, creeping closer
		var k := _t / T_SHATTER
		_look(heart + _f * lerpf(12.0, 8.0, k) + side * 2.0 + Vector3(0, -1.5, 0), heart)
	elif _t < T_FADE:
		# Pulling back as it shatters and the ring rolls out
		var k := smoothstep(0.0, 1.0, (_t - T_SHATTER) / (T_FADE - T_SHATTER))
		_look(heart + _f * lerpf(8.0, 22.0, k) + side * lerpf(2.0, 8.0, k) + Vector3(0, lerpf(-1.5, 3.0, k), 0),
			heart.lerp(_g + Vector3(0, 2.0, 0), k))
	elif _t < T_SKY:
		# Low and close as he sinks down and the figure of light is all that's left
		var k := smoothstep(0.0, 1.0, (_t - T_FADE) / (T_SKY - T_FADE))
		var target := _g + Vector3(0, lerpf(4.0, 1.2, k), 0)
		if is_instance_valid(figure) and _t > T_LIGHT:
			target = figure.global_position + Vector3(0, 1.0, 0)
		_look(_g + _f * lerpf(14.0, 6.0, k) - side * 3.0 + Vector3(0, lerpf(3.0, 1.6, k), 0), target)
	elif _t < T_FRIENDS:
		# Up at the sky, where the crack zips shut
		var k := smoothstep(0.0, 1.0, (_t - T_SKY) / 1.5)
		var up_at := crack.global_position if is_instance_valid(crack) else _g + Vector3(0, CRACK_HEIGHT, 0)
		var eye := _g + _f * 22.0 + Vector3(0, 2.5, 0)
		_look(eye, (_g + Vector3(0, 3.0, 0)).lerp(up_at, k))
	else:
		# The hero and everyone who came, from in front, slowly drifting round
		var k := (_t - T_FRIENDS) / (LENGTH - T_FRIENDS)
		var to_him := _g - pp
		to_him.y = 0.0
		to_him = to_him.normalized() if to_him.length() > 0.1 else -_f
		var across := to_him.cross(Vector3.UP).normalized()
		var eye := pp + to_him * 9.0 + across * lerpf(-4.0, 4.0, k) + Vector3(0, 3.2 + 1.5 * k, 0)
		_look(eye, pp - to_him * 3.0 + Vector3(0, 1.0, 0))


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
	_sub.add_theme_font_size_override("font_size", int(30 * Settings.text_scale))
	for l in [_title, _sub]:
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.4)


func _title_out() -> void:
	for l in [_title, _sub]:
		create_tween().tween_property(l, "modulate:a", 0.0, 0.4)


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


func _look(at: Vector3, target: Vector3) -> void:
	cam.global_position = at
	if at.distance_to(target) > 0.01:
		cam.look_at(target, Vector3.UP)


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
