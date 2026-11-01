class_name RaceIntro
extends CanvasLayer

# The little cutscene before a race (scripts/races.gd), like a racing game's track intro: black bars slide in, the
# track's name and what it is come up over a slow swing round the start arch, the camera flies the whole course along
# the racing line, then it says hello to each rival on the grid in turn ("Bruno, SK8 Deck"), and hands back to the
# player's camera for the countdown. Jump or Interact skips it. Settings > Assist > "Race intros" turns them off.
#
# It uses a camera of its own in the scene, so the player's camera and spring arm are left exactly as they were.

signal done

const TITLE_TIME := 2.6
const FLY_TIME := 5.5                    # the whole course, however long it is
const RIVAL_TIME := 1.3
const BAR := 0.11                        # the black bars' height, as a share of the screen
const SKIP_ACTIONS := ["jump", "interact", "ui_accept"]

var track: RaceTrack
var rivals: Array = []
var title := ""
var blurb := ""
var cam: Camera3D
var _old_cam: Camera3D
var _t := 0.0
var _playing := false
var _top: ColorRect
var _bottom: ColorRect
var _title: Label
var _blurb: Label
var _caption: Label
var _skip: Label
var _shown_rival := -1
var _fades: Array[Tween] = []
var _hidden: Array = []                  # the player's HUD layers put away for the intro, to put back after


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_top = _bar(true)
	_bottom = _bar(false)
	_title = _label(64, Color(1.0, 0.85, 0.3))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.offset_top = -120
	_blurb = _label(28, Color(1.0, 0.97, 0.85))
	_blurb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_blurb.offset_top = -40
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.custom_minimum_size.x = 900
	_caption = _label(40, Color(1.0, 0.97, 0.85))
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_bottom = -110
	_skip = _label(20, Color(0.85, 0.85, 0.95))
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -24
	_skip.offset_bottom = -16
	for l in [_title, _blurb, _caption]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false


func playing() -> bool:
	return _playing


func length() -> float:
	return TITLE_TIME + FLY_TIME + RIVAL_TIME * rivals.size()


func play(on: RaceTrack, who: Array, name: String, what: String) -> void:
	track = on
	rivals = who
	title = name.to_upper()
	blurb = what[0].to_upper() + what.substr(1) if what != "" else ""
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "Race Intro Camera"
	cam.fov = 60.0
	cam.far = 1500.0
	track.get_tree().current_scene.add_child(cam)
	cam.make_current()
	_t = 0.0
	_shown_rival = -1
	_playing = true
	visible = true
	_title.text = title
	_blurb.text = blurb
	_caption.text = ""
	_skip.text = "%s to skip" % Settings.prompt("jump")
	_fades.clear()
	for l in [_title, _blurb]:
		l.add_theme_font_size_override("font_size", int((64 if l == _title else 28) * Settings.text_scale))
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(l, "modulate:a", 1.0, 0.5)
		_fades.append(tw)
	_hide_hud()
	_place_camera()


func stop() -> void:
	# Over (or skipped, or the race was called off): back to the player's camera
	if not _playing:
		return
	_playing = false
	visible = false
	for layer_node in _hidden:
		if is_instance_valid(layer_node):
			layer_node.visible = true
	_hidden.clear()
	if is_instance_valid(cam):
		cam.queue_free()
	if is_instance_valid(_old_cam):
		_old_cam.make_current()
	cam = null


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_instance_valid(track) or not is_instance_valid(cam):
		stop()
		return
	_t += delta
	for a in SKIP_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a) and _t > 0.2:
			_finish()
			return
	if _t >= length():
		_finish()
		return
	_place_camera()


func skip() -> void:
	if _playing:
		_finish()


func _finish() -> void:
	stop()
	done.emit()


func _place_camera() -> void:
	var start := track.point_at(0.0)
	var f := track.dir_at(0.0)
	var right := track.side_at(0.0)
	var up := 1.0 if not track.sky else 6.0
	var size := 1.0 if not track.sky else 5.0             # the sky course and its saucers are a lot bigger
	if _t < TITLE_TIME:
		# A slow swing round the start arch, with the name up
		var k := _t / TITLE_TIME
		var a := lerpf(-0.9, 0.3, k)
		var off := (-f * cos(a) + right * sin(a)) * 15.0 * size + Vector3.UP * (6.0 + 3.0 * k) * size
		_look(start + off, start + Vector3.UP * 2.5 * up)
		_caption.text = ""
	elif _t < TITLE_TIME + FLY_TIME:
		# Flying the course along the racing line, a little above it, looking down the track ahead
		for tw in _fades:
			if tw.is_valid():
				tw.kill()
		for l in [_title, _blurb]:
			l.modulate.a = maxf(l.modulate.a - get_process_delta_time() * 3.0, 0.0)
		var k := smoothstep(0.0, 1.0, (_t - TITLE_TIME) / FLY_TIME)
		var d := k * track.length
		var height := 9.0 if not track.sky else 22.0
		var at := track.point_at(d - 6.0 * size) + Vector3.UP * height + track.side_at(d) * 3.0 * size
		_look(at, track.point_at(d + 16.0 * size) + Vector3.UP * up)
	else:
		# Hello to each rival on the grid, one at a time
		var i := clampi(int((_t - TITLE_TIME - FLY_TIME) / RIVAL_TIME), 0, rivals.size() - 1)
		var r := rivals[i] as Node3D
		if not is_instance_valid(r):
			return
		var rf := r.global_basis.z
		var rr := r.global_basis.x
		# (a saucer is seen from a little above and from its outer side, so the mothership waiting beside the grid
		# isn't in the way)
		var lift := 1.5 if not track.sky else 3.2
		var side := 1.4
		var ship := get_tree().get_first_node_in_group("mothership") as Node3D
		if track.sky and ship and rr.dot(ship.global_position - r.global_position) > 0.0:
			side = -1.4
		_look(r.global_position + rf * 4.2 * size + rr * side * size + Vector3.UP * lift * size, r.global_position + Vector3.UP * 0.9 * size)
		if i != _shown_rival:
			_shown_rival = i
			var ride := "Mini Saucer" if not r.get("saucer").is_empty() else str(Races.ride_of(str(r.get("id"))).name)
			_caption.text = "%s\n%s" % [r.call("display_name"), ride]
			_caption.add_theme_font_size_override("font_size", int(40 * Settings.text_scale))
			_caption.modulate.a = 0.0
			create_tween().tween_property(_caption, "modulate:a", 1.0, 0.25)
			Audio.play("swish", -10.0, 0.1)


func _hide_hud() -> void:
	# A cutscene is the whole screen: the player's HUD (sparkles, MP, the clock, messages) steps away while it plays,
	# and the corner minimap waits too (scripts/map_screen.gd asks playing()). The race's own HUD shows nothing yet.
	_hidden.clear()
	var p := track.get_tree().current_scene.find_child("Player", true, false)
	if p == null:
		return
	for c in p.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(c)


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
