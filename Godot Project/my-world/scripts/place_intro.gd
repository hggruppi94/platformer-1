extends CanvasLayer

# A little "here's where you are" cutscene for the first time the player arrives somewhere (Hayden's 11 Nov 2026
# playtest: the job board's tutorial "carries over into the Void with a cutscene showing the location when you enter
# for the first time"). Black bars slide in and a camera of its own glides through a list of shots, each with a
# caption, then hands back to the player's camera. The player's camera and spring arm are left as they were.
# Jump, Interact or Accept skips it. While it plays the player's controls are held (`place_intro`), the HUD steps away
# and the minimap waits (group "cutscene_playing", scripts/map_screen.gd).
#
# A shot is {"from": Vector3, "look": Vector3, "time": seconds, "title": "", "caption": ""}: the camera moves from the
# last shot's spot to this one's over its time, easing, looking from the last target to this one. A shot can also have
# "start" (and "start_look"): the camera cuts there first and glides on from it (the opening's first shot, scripts/
# opening.gd), and "sound": a sound played as the shot begins (the knock at the door). No class_name on purpose
# (preload it), so --script tools can load it before the autoloads exist.

signal done

const BAR := 0.11
const SKIP_ACTIONS := ["jump", "interact", "ui_accept"]

var shots: Array = []
var cam: Camera3D
var _old_cam: Camera3D
var _t := 0.0
var _i := 0
var _from := Vector3.ZERO
var _look_from := Vector3.ZERO
var _playing := false
var _title: Label
var _caption: Label
var _skip: Label
var _hidden: Array = []


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_bar(true)
	_bar(false)
	_title = _label(60, Color(1.0, 0.85, 0.3))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 110
	_caption = _label(32, Color(1.0, 0.97, 0.85))
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
	for l in [_title, _caption]:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
		l.grow_vertical = Control.GROW_DIRECTION_BOTH
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	visible = false


func playing() -> bool:
	return _playing


func length() -> float:
	var total := 0.0
	for s in shots:
		total += float(s.get("time", 2.0))
	return total


func play(list: Array) -> void:
	# Starts at the player's camera, so the first shot glides away from where they're looking
	shots = list
	if shots.is_empty():
		done.emit()
		return
	var scene := get_tree().current_scene
	_old_cam = get_viewport().get_camera_3d()
	cam = Camera3D.new()
	cam.name = "Place Intro Camera"
	cam.fov = 60.0
	cam.far = 1500.0
	scene.add_child(cam)
	if _old_cam:
		_from = _old_cam.global_position
		_look_from = _old_cam.global_position - _old_cam.global_basis.z * 10.0
	else:
		_from = shots[0].from
		_look_from = shots[0].look
	_t = 0.0
	_i = 0
	_cut_in()
	cam.global_position = _from
	cam.make_current()
	_playing = true
	visible = true
	add_to_group("cutscene_playing")
	Game.hold_controls(&"place_intro", true)
	_skip.text = "%s to skip" % Settings.prompt("jump")
	_hide_hud()
	_show_words()


func stop() -> void:
	if not _playing:
		return
	_playing = false
	visible = false
	remove_from_group("cutscene_playing")
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	if is_instance_valid(cam):
		cam.queue_free()
	if is_instance_valid(_old_cam):
		_old_cam.make_current()
	cam = null
	Game.hold_controls(&"place_intro", false)
	done.emit()


func _process(delta: float) -> void:
	if not _playing:
		return
	if not is_instance_valid(cam):
		stop()
		return
	_t += delta
	for a in SKIP_ACTIONS:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a) and (_t > 0.3 or _i > 0):
			stop()
			return
	var shot: Dictionary = shots[_i]
	var time := float(shot.get("time", 2.0))
	var k := smoothstep(0.0, 1.0, clampf(_t / time, 0.0, 1.0))
	var at := _from.lerp(shot.from, k)
	var look := _look_from.lerp(shot.look, k)
	cam.global_position = at
	if at.distance_to(look) > 0.01:
		cam.look_at(look, Vector3.UP)
	if _t >= time:
		_t = 0.0
		_from = shot.from
		_look_from = shot.look
		_i += 1
		if _i >= shots.size():
			stop()
			return
		_cut_in()
		_show_words()


func _cut_in() -> void:
	# A shot that starts somewhere of its own (a cut, not a glide from the last one), and its sound
	var shot: Dictionary = shots[_i]
	if shot.has("start"):
		_from = shot.start
		_look_from = shot.get("start_look", shot.look)
	if str(shot.get("sound", "")) != "":
		Audio.play(str(shot.sound), -2.0, 0.0)


func _show_words() -> void:
	var shot: Dictionary = shots[_i]
	for pair in [[_title, str(shot.get("title", "")), 60], [_caption, Settings.fill(str(shot.get("caption", ""))), 32]]:
		var l: Label = pair[0]
		if str(pair[1]) == l.text:
			continue
		l.text = str(pair[1])
		l.add_theme_font_size_override("font_size", int(int(pair[2]) * Settings.text_scale))
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.4)
	if str(shot.get("caption", "")) != "":
		Audio.play("swish", -12.0, 0.1)


func _hide_hud() -> void:
	_hidden.clear()
	var p := get_tree().current_scene.find_child("Player", true, false)
	if p == null:
		return
	for c in p.find_children("*", "CanvasLayer", true, false):
		if (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(c)


func _bar(top: bool) -> void:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.02, 0.06)
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	r.anchor_top = 0.0 if top else 1.0 - BAR
	r.anchor_bottom = BAR if top else 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.12, 0.05, 0.2))
	l.add_theme_constant_override("outline_size", 12)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
