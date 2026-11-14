class_name SprayCan
extends Node3D

# Spray paint (Hayden's 14 Nov 2026 playtest: "spray painting that stays put until it is washed off, allowing the
# character to create any permanent design they want"). The paint itself, and where it's kept, is the Paint autoload
# (scripts/paint.gd); this is the cans in her hand, on the player like the Star Popper.
#
#   Spray paint (V / R3)            cans out (and away again). Bought at the Toy Shop on Earth or the Toys stall in
#                                   the Void (shop item "spray_can"); until then the button does nothing.
#   Shoot (left click / RT), held   sprays where the crosshair is. Closer is a fine line, further a fat one.
#   Aim (right click / LT), held    sprays water, which washes paint off. (So does the water drop on the palette.)
#   Mouse wheel, 1-0, D-pad L/R     the colour.
#
# With the cans out the camera sits over her shoulder like aiming (StarPopper.painting), her arm points the can and
# gadgets are put away. Only on foot: not on a ride, burrowing, swimming or in a talk or menu. A stroke joins up from
# one puff to the next, so a quick sweep is a line, not dots.

const REACH := 9.0                        # metres from her the paint gets to
const PUFF := 0.022                       # seconds between puffs while Shoot is held
const WASH_PUFF := 0.05
const WASH_RADIUS := 0.5
const NEAR_SIZE := 0.12                   # a dab's size right up close...
const FAR_SIZE := 0.5                     # ...and at the far end of REACH
const JOIN := 1.4                         # a puff this close to the last one fills the gap between them
const WATER := -1                         # the palette's water drop (washing)

var player: Player
var active := false
var colour := 0                           # Paint.COLOURS index, or WATER
var dabs := 0                             # puffs that stuck (tests read it)
var washed := 0                           # dabs washed off
var _puff := 0.0
var _last := {}                           # the last puff's spot and normal, for joining a stroke up
var _told_full := false
var _hud: CanvasLayer
var _bar: Palette
var _cross: SprayCross
var _hiss: AudioStreamPlayer


func setup(p: Player) -> void:
	player = p
	name = "SprayCan"
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	_cross = SprayCross.new()
	_cross.can = self
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.visible = false
	_hud.add_child(_cross)
	_bar = Palette.new()
	_bar.can = self
	_bar.visible = false
	_hud.add_child(_bar)
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = hiss_sound()
	_hiss.bus = "SFX"
	_hiss.volume_db = -14.0
	add_child(_hiss)


func owned() -> bool:
	return Game.has_item("spray_can")


func can_paint() -> bool:
	if player == null or player.carried or player.input_locked or not owned():
		return false
	if Game.riding:
		return false
	for move in ["burrow", "swim"]:
		var m = player.get(move)
		if m and m.get("active"):
			return false
	if Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or Shop.is_open() or get_tree().paused:
		return false
	return true


func set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	_last = {}
	if player and player.popper:
		player.popper.set_painting(on)
	_cross.visible = on
	_bar.visible = on
	if not on:
		_hiss.stop()
	Audio.play("ui_accept" if on else "ui_back", -8.0, 0.0)
	if on:
		Tips.show_tip("spray_on")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var ok := can_paint()
	if active and not ok:
		set_active(false)
	if ok and Input.is_action_just_pressed("spray"):
		set_active(not active)
	if not active:
		return
	_puff -= delta
	var spraying := Input.is_action_pressed("shoot") and _mouse_ok()
	var washing := Input.is_action_pressed("aim") or (spraying and colour == WATER)
	if not spraying and not washing:
		_last = {}
		if _hiss.playing:
			_hiss.stop()
		return
	if not _hiss.playing:
		_hiss.pitch_scale = 0.8 if washing else 1.0
		_hiss.play()
	if _puff > 0.0:
		return
	_puff = WASH_PUFF if washing else PUFF
	var hit := aim_hit()
	if hit.is_empty():
		_last = {}
		return
	if washing:
		wash_at(hit.position)
	else:
		spray_at(hit.position, hit.normal, hit.collider)


func _mouse_ok() -> bool:
	# The click that grabs the mouse back into the game window isn't paint (as for Shoot: StarPopper.can_shoot)
	return Settings.last_device != "keyboard" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		or get_tree().get_script() != null


func aim_hit() -> Dictionary:
	# Where the crosshair is, if it's on something within reach: {position, normal, collider}
	var cam := player.spring_arm.get_node_or_null("Camera3D") as Camera3D
	if cam == null:
		return {}
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(o, o + d * (REACH + o.distance_to(player.global_position) + 1.0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit.position as Vector3).distance_to(player.global_position) > REACH:
		return {}
	return hit


func size_at(at: Vector3) -> float:
	var k := clampf(at.distance_to(player.global_position) / REACH, 0.0, 1.0)
	return lerpf(NEAR_SIZE, FAR_SIZE, k)


func spray_at(at: Vector3, normal: Vector3, collider: Object = null) -> int:
	# One puff: a dab where it lands, and the gap from the last puff filled in. Returns how many dabs stuck.
	if collider != null and not Paint.paintable(collider, at):
		_last = {}
		return 0
	var size := size_at(at)
	var spots: Array[Vector3] = [at]
	if not _last.is_empty() and (_last.at as Vector3).distance_to(at) < JOIN \
			and (_last.normal as Vector3).dot(normal) > 0.8:
		var from: Vector3 = _last.at
		var step := size * 0.35
		var n := int(from.distance_to(at) / step)
		spots.clear()
		for i in range(1, n + 1):
			spots.append(from.lerp(at, float(i) / n))
		if spots.is_empty():
			spots.append(at)
	var got := 0
	for p in spots:
		# a touch of spread, like a real can
		var jitter := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * size * 0.15
		jitter -= normal * jitter.dot(normal)
		if Paint.dab(p + jitter, normal, colour, size * randf_range(0.9, 1.1), randf() * TAU):
			got += 1
	dabs += got
	_last = {"at": at, "normal": normal}
	if got == 0 and Paint.full() and not _told_full:
		_told_full = true
		Game.message("Full of paint! Wash some off.")
	var scene := get_tree().current_scene
	if scene and got > 0 and randf() < 0.3:
		Juice.burst(scene, at + normal * 0.05, Paint.COLOURS[colour], 2, 0.03, 0.6, 0.25)
	return got


func wash_at(at: Vector3) -> int:
	var gone := Paint.wash(at, WASH_RADIUS)
	washed += gone
	if gone > 0:
		_told_full = false
	var scene := get_tree().current_scene
	if scene:
		Juice.burst(scene, at + Vector3(0, 0.05, 0), Color(0.75, 0.9, 1.0, 0.8), 3, 0.04, 1.4, 0.3)
	return gone


func pick(c: int) -> void:
	# A colour off the palette (WATER for the water drop)
	colour = c if c == WATER else clampi(c, 0, Paint.COLOURS.size() - 1)
	_last = {}
	_bar.queue_redraw()
	_cross.queue_redraw()
	Audio.play("ui_move", -10.0, 0.0)


func cycle(step: int) -> void:
	var n := Paint.COLOURS.size() + 1           # the colours, then the water drop
	var i := Paint.COLOURS.size() if colour == WATER else colour
	i = posmod(i + step, n)
	pick(WATER if i == Paint.COLOURS.size() else i)


func _unhandled_input(event: InputEvent) -> void:
	if not active or event.is_echo():
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle(-1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_0 and k <= KEY_9 and not k in Settings.bindings.values():
			pick(9 if k == KEY_0 else k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_MINUS and not k in Settings.bindings.values():
			pick(WATER)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var b := (event as InputEventJoypadButton).button_index
		if b == JOY_BUTTON_DPAD_LEFT or b == JOY_BUTTON_DPAD_RIGHT:
			cycle(-1 if b == JOY_BUTTON_DPAD_LEFT else 1)
			get_viewport().set_input_as_handled()


func current_colour() -> Color:
	return Color(0.75, 0.9, 1.0) if colour == WATER else Paint.COLOURS[colour]


static func hiss_sound() -> AudioStreamWAV:
	# A soft looping hiss, made here (wav files go through Git LFS: see gadget_sfx.gd)
	var sr := 22050
	var n := sr / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var lp := 0.0
	for i in n:
		var w := rng.randf_range(-1.0, 1.0)
		lp = lp * 0.55 + w * 0.45                # takes the harsh top off
		var v := (w - lp) * 0.35 + lp * 0.15
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = sr
	s.data = bytes
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = n
	return s


static func build_prop() -> Node3D:
	# The can in her hand: a little can with a cap and nozzle, made in code. Its nozzle points +Z like the popper's.
	var root := Node3D.new()
	root.name = "SprayCanProp"
	root.set_meta("gadget", "spray")
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.2
	body.mesh = cyl
	body.rotation.x = PI / 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.35, 0.95)
	m.metallic = 0.5
	m.roughness = 0.35
	body.material_override = m
	root.add_child(body)
	var band := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = 0.047
	b.bottom_radius = 0.047
	b.height = 0.05
	band.mesh = b
	band.rotation.x = PI / 2.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1.0, 0.85, 0.3)
	band.material_override = bm
	root.add_child(band)
	var cap := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.02
	c.bottom_radius = 0.035
	c.height = 0.05
	cap.mesh = c
	cap.rotation.x = PI / 2.0
	cap.position = Vector3(0, 0, 0.125)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.95, 0.95, 0.98)
	cap.material_override = cm
	root.add_child(cap)
	return root


# ----------------------------------------------------------------------------- the crosshair
class SprayCross extends Control:
	# A ring in the paint's colour, as big as the splat will be, with a dot in the middle
	var can: SprayCan

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if can == null or can.player == null:
			return
		var c := size / 2.0
		var hit := can.aim_hit()
		var r := 10.0 * Settings.text_scale
		var col := can.current_colour()
		var shadow := Color(0.1, 0.05, 0.2, 0.6)
		if hit.is_empty():
			col = Color(col, 0.35)                 # nothing in reach
		else:
			var cam := can.player.spring_arm.get_node("Camera3D") as Camera3D
			var s := can.size_at(hit.position)
			var d := cam.global_position.distance_to(hit.position)
			# the splat's size on screen, roughly
			r = clampf(s * 0.5 / maxf(d, 0.5) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5, 6.0, 80.0)
		draw_arc(c, r, 0.0, TAU, 40, shadow, 5.0, true)
		draw_arc(c, r, 0.0, TAU, 40, col, 3.0, true)
		draw_circle(c, 3.5, shadow)
		draw_circle(c, 2.5, Color(1, 1, 1))


# ----------------------------------------------------------------------------- the palette
class Palette extends Control:
	# The paint pots, the one in use bigger, then the water drop. Under them, the buttons with a word each (Hayden:
	# as little reading as possible).
	var can: SprayCan

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Settings.changed.connect(queue_redraw)
		Settings.device_changed.connect(queue_redraw)

	func _draw() -> void:
		# A column of pots down the right-hand side, clear of the stats, the minimap and the messages at the bottom,
		# with the buttons beside it
		if can == null:
			return
		var k := Settings.text_scale * Settings.hud_size
		var pot := 16.0 * k
		var gap := 7.0 * k
		var n := Paint.COLOURS.size() + 1
		var h := (n - 1) * (pot * 2.0 + gap)
		var x := size.x - 40.0 * k
		var y := maxf(100.0 * k, (size.y - h) / 2.0 - 70.0 * k)
		var shadow := Color(0.08, 0.04, 0.16, 0.7)
		draw_rect(Rect2(x - pot * 1.7, y - pot * 1.7, pot * 3.4, h + pot * 3.4), Color(0.1, 0.06, 0.2, 0.55), true)
		for i in n:
			var water := i == n - 1
			var on := (can.colour == SprayCan.WATER) if water else (can.colour == i)
			var r := pot * (1.3 if on else 0.9)
			var at := Vector2(x, y + i * (pot * 2.0 + gap))
			draw_circle(at, r + 3.0, shadow)
			if water:
				_drop(at, r)
			else:
				draw_circle(at, r, Paint.COLOURS[i])
			if on:
				draw_arc(at, r + 4.0, 0.0, TAU, 32, Color(1.0, 0.9, 0.4), 3.0, true)
		# the buttons, one under the other, just left of the pots (right-aligned to them)
		var font := get_theme_default_font()
		var fs := Settings.hud(17)
		var hints := [[Settings.prompt("shoot"), "Spray"], [Settings.prompt("aim"), "Wash"],
			["Wheel" if Settings.last_device != "pad" else "D-pad", "Colour"], [Settings.prompt("spray"), "Done"]]
		var hy := y - pot + fs
		for hint in hints:
			var a := font.get_string_size(str(hint[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0 * k
			var b := font.get_string_size(str(hint[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var hx := x - pot * 1.7 - 12.0 * k - a - b - 8.0 * k
			draw_rect(Rect2(hx - 2.0, hy - fs - 2.0, a + 4.0, fs * 1.35 + 4.0), shadow, true)
			draw_rect(Rect2(hx, hy - fs, a, fs * 1.35), Color(0.95, 0.92, 1.0), true)
			draw_string(font, Vector2(hx + 7.0 * k, hy + fs * 0.12), str(hint[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(0.15, 0.08, 0.3))
			var wx := hx + a + 8.0 * k
			draw_string_outline(font, Vector2(wx, hy + fs * 0.12), str(hint[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5,
				shadow)
			draw_string(font, Vector2(wx, hy + fs * 0.12), str(hint[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Color(1, 1, 1))
			hy += fs * 1.7

	func _drop(at: Vector2, r: float) -> void:
		# A water drop: a round bottom with a point on top
		var col := Color(0.55, 0.85, 1.0)
		draw_circle(at + Vector2(0, r * 0.25), r * 0.8, col)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.72, r * 0.05), at + Vector2(0, -r * 1.05),
			at + Vector2(r * 0.72, r * 0.05)]), col)
		draw_circle(at + Vector2(-r * 0.25, r * 0.15), r * 0.18, Color(1, 1, 1, 0.8))
