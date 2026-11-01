extends CanvasLayer

# Bobbing for apples at the Autumn Festival (scripts/festival.gd starts it from the apple barrel). The other seasons'
# fairs play it the same way with their own words: ice fishing at the Frost Fair, hooking a duck at the Spring Fair. Three goes: an apple
# bobs back and forth across the barrel, and Interact (or Jump) bites. Bite while it's over the green ripple to get it;
# each go the apple's quicker and the ripple's smaller. Then the score, and Festival pays for the apples once a
# festival. The player can't move while their face is in the barrel.

const GOES := 3
const WIDTH := 520.0
const ZONES := [110.0, 80.0, 56.0]          # the ripple's width, each go
const SPEEDS := [1.7, 2.3, 3.0]             # how fast the apple bobs, each go

var go := 0
var apples := 0
var marker := 0.0                           # where the apple is, 0..1 across the barrel
var zone := 0.5                             # the middle of the ripple, 0..1
var finished := false

var _t := 0.0
var _wait := 0.0                            # a moment after each bite to see how it went
var _bar: Control
var _title: Label
var _say: Label


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(WIDTH + 80, 230)
	panel.position = -panel.custom_minimum_size / 2.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.12, 0.08, 0.92)
	style.border_color = Color(0.95, 0.55, 0.15)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	_title = _label(box, 30, Color(1.0, 0.85, 0.5))
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(WIDTH, 60)
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	_say = _label(box, 22, Color(1, 0.97, 0.9))
	_lock(true)
	_next_go()


func _label(parent: Node, size: int, c: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	parent.add_child(l)
	return l


func _next_go() -> void:
	zone = randf_range(0.2, 0.8)
	_t = randf() * TAU
	var f: Dictionary = Festival.fair()
	_title.text = "%s!   Go %d of %d   %s: %d" % [f.game, go + 1, GOES, _plural(), apples]
	_say.text = "Press %s to %s when the %s's over the green!" % [Settings.prompt("interact"), _act(), f.catch]


func _process(delta: float) -> void:
	if finished:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			if go >= GOES:
				_finish()
			else:
				_next_go()
		return
	_t += delta * SPEEDS[mini(go, GOES - 1)]
	marker = 0.5 + 0.5 * sin(_t)
	_bar.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if finished or _wait > 0.0:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		bite()


static func _plural() -> String:
	return {"apple": "Apples", "fish": "Fish", "duck": "Ducks"}.get(str(Festival.fair().catch), "Got")


static func _act() -> String:
	# What the button does in this season's barrel game
	return {"apple": "bite", "fish": "pull the line", "duck": "hook it"}.get(str(Festival.fair().catch), "go")


func in_zone() -> bool:
	return absf(marker - zone) * WIDTH <= ZONES[mini(go, GOES - 1)] / 2.0


func bite() -> bool:
	# One go: true if it got an apple
	if finished or go >= GOES:
		return false
	var got := in_zone()
	go += 1
	if got:
		apples += 1
		Audio.play("pop", -3.0)
		_say.text = {"apple": "CRUNCH! Got one!", "fish": "A bite! You reel it in!", "duck": "Hooked it! Quack!"}.get(
			str(Festival.fair().catch), "Got one!")
	else:
		Audio.play("splash", -4.0)
		_say.text = {"apple": "Splash! It bobbed away.", "fish": "Splash! It swam off.", "duck": "Missed! It floated by."}.get(
			str(Festival.fair().catch), "Missed!")
	var f: Dictionary = Festival.fair()
	_title.text = "%s!   Go %d of %d   %s: %d" % [f.game, go, GOES, _plural(), apples]
	_wait = 1.0
	_bar.queue_redraw()
	return got


func _finish() -> void:
	finished = true
	_say.text = Festival.apples_done(apples)
	_title.text = "%s!   You got %d of %d" % [Festival.fair().game, apples, GOES]
	get_tree().create_timer(2.0).timeout.connect(close)


func close() -> void:
	_lock(false)
	queue_free()


func _exit_tree() -> void:
	_lock(false)


func _lock(on: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	if player and "input_locked" in player:
		player.set("input_locked", on)


func _draw_bar() -> void:
	# The barrel's water, the green ripple and the bobbing apple
	var h := _bar.size.y
	_bar.draw_rect(Rect2(0, 8, WIDTH, h - 16), Color(0.25, 0.45, 0.6))
	var zw: float = ZONES[mini(go, GOES - 1)]
	_bar.draw_rect(Rect2(zone * WIDTH - zw / 2.0, 8, zw, h - 16), Color(0.45, 0.85, 0.4, 0.85))
	var at := Vector2(marker * WIDTH, h / 2.0)
	_bar.draw_circle(at, 17.0, Color(0.85, 0.12, 0.12))
	_bar.draw_circle(at + Vector2(-5, -5), 5.0, Color(1, 0.6, 0.6, 0.8))
	_bar.draw_line(at + Vector2(0, -16), at + Vector2(3, -26), Color(0.4, 0.25, 0.1), 3.0)
