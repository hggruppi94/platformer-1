extends Node3D

# The centipede's corner: the secret way into Dark Hollow (plan item 21; Hayden, 10 Nov 2026: "The entrance to dark
# hollow will actually be hidden until you interact with the centipede in the sliver. She will eat you and that will
# transport you there"). There's no portal and nothing on the map. Through a Sliver into Behind the Walls on the castle
# school's 2nd floor (tools/build_school.gd), right along the dark passage to its far west end, past where the
# centipede crawls on the ceiling, is her corner: roots coming through the ceiling, glowing fungi on the walls, layered
# old stone, and her nest of things the school lost (odd socks, a lunchbox, pencils, a backpack).
#
# Walk up and she drops down from the ceiling into her nest (the ceiling crawler, scripts/centipede.gd, steps out of
# sight meanwhile) and turns to look at you. Talk to her and she asks if you want to go to Dark Hollow: a clear Yes /
# No, recorded either way (Dialogue.choice_log "dark_hollow_gulp", like the old Scary World gate: the therapist marker).
# On yes she circles round you and GULPS you up: the screen closes like a mouth, "GULP!", a long glowing slide down,
# and you land in Dark Hollow (Portals.enter_dark_hollow()). A cartoon gulp: no teeth, no chewing, nothing scary-gory.
#
# Put into the school scene at play time by Portals (scripts/portals.gd _arrived), so school.tscn isn't rebuilt.

const FRIEND := preload("res://scripts/centipede_friend.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")
const RECORD := "dark_hollow_gulp"
# In the passage's own frame ("Floor 2/Behind The Walls", tools/build_school.gd: X_W -30, Z_N -24, the lane runs from
# Z_N + 0.3 to Z_N + 2.85 along the north wall): the far west end, as far from both Slivers as you can get
const CORNER := Vector3(-28.4, 0.0, -22.45)
const SPOT_AT := Vector3(-26.0, 0.0, -22.45)
const SHOW_NEAR := 9.0                     # she drops into her nest when you're this close...
const HIDE_FAR := 13.0                     # ...and climbs back up to the ceiling when you're this far
const NEST_SCALE := 0.5                    # her curl is 4.8 m across at home; the lane here is 2.5 m
const CIRCLE_TIME := 1.3
const IRIS_TIME := 0.6
const SLIDE_TIME := 2.2

var her: Node3D                            # the curled centipede in her nest
var crawler: Node3D                        # the one on the ceiling (scenes/creatures/centipede.tscn)
var spot: Area3D
var shown := false
var gulping := false
var gulps := 0                             # (tests read these)
var _log_before := 0
var _overlay: CanvasLayer
var _t := 0.0


static func place(school: Node) -> Node3D:
	var behind := school.get_node_or_null("Floor 2/Behind The Walls") as Node3D
	if behind == null or behind.get_node_or_null("Centipede's Corner") != null:
		return null
	var c := (load("res://scripts/centipede_corner.gd") as GDScript).new() as Node3D
	c.name = "Centipede's Corner"
	behind.add_child(c)
	return c


func _ready() -> void:
	crawler = get_parent().get_node_or_null("Centipede") as Node3D
	_decorate()
	her = FRIEND.new() as Node3D
	her.name = "Her"
	her.set("head_height", 1.4)
	add_child(her)
	her.position = CORNER
	her.scale = Vector3.ONE * NEST_SCALE
	her.rotation.y = PI / 2.0                 # her face (the curl's head end, +Z) towards the passage, east
	her.visible = false
	spot = USE_SPOT.make(SPOT_AT, _offer, talk, 2.4, 2.0)
	spot.name = "Spot"
	add_child(spot)
	Dialogue.finished.connect(_on_talked)


func _offer() -> String:
	return "talk to %s" % _name().replace("The C", "the c") if shown and not gulping else ""


func _name() -> String:
	var n := str(Dialogue.names.get("centipede", ""))
	return n if n != "" else "The Centipede"


func _process(delta: float) -> void:
	_t += delta
	if gulping:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var c := to_global(CORNER)
	var d := Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length()
	var same_floor := absf(player.global_position.y - c.y) < 3.0
	if not shown and same_floor and d < SHOW_NEAR:
		show_her()
	elif shown and (d > HIDE_FAR or not same_floor):
		hide_her()


func show_her() -> void:
	# She drops down from the ceiling into her nest with a soft thump
	shown = true
	her.visible = true
	if crawler:
		crawler.visible = false
		crawler.process_mode = Node.PROCESS_MODE_DISABLED
	her.position = CORNER + Vector3(0, 4.6, 0)
	var tw := her.create_tween()
	tw.tween_property(her, "position", CORNER, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Audio.play_at("centipede_skitter", to_global(CORNER), -6.0)


func hide_her() -> void:
	shown = false
	her.visible = false
	if crawler:
		crawler.visible = true
		crawler.process_mode = Node.PROCESS_MODE_INHERIT


func talk() -> void:
	if not shown or gulping:
		return
	_log_before = Dialogue.choice_log.size()
	Dialogue.say(spot, _name(), lines(), "centipede_corner")


func lines() -> Array:
	var ask := {"choice": [
		{"text": "Yes. Gulp me up!", "answer": "yes", "record": RECORD, "set": "dark_hollow_said_yes",
			"lines": ["Hold your breath! (Not really. You don't need to.) Here we go..."]},
		{"text": "No, not today.", "answer": "no", "record": RECORD, "set": "dark_hollow_said_no",
			"lines": ["That's okay. Saying no is brave too. I'll be right here, in my corner."]}]}
	if Portals.is_cleared("dark_hollow"):
		return ["{player}! My friend! Have you come to visit?",
			"The Moon Clock's still ticking. I check it every night.",
			"Want to come home with me? Gulp, slide, ptoo!", ask]
	var said_no := Dialogue.flags.has("dark_hollow_said_no")
	var been := Dialogue.flags.has("dark_hollow_said_yes")
	if been:
		return ["You came back! The shadows are still nibbling at our moments down there.",
			"Shall I take you to Dark Hollow again? Same as before: gulp, a long soft slide, and out you pop.", ask]
	var out: Array = []
	if said_no:
		out.append("Oh! You came back to my corner. I'm glad.")
	else:
		out.append_array(["(Something drops from the ceiling with a soft thump. Lots and lots of legs. A pale face turns to look at {player}.)",
			"You came all the way to my corner. Nobody comes all the way to my corner.",
			"Don't be scared. Well... you can be a little bit scared. That's allowed.",
			"I'm not from here, you know. I'm from Dark Hollow. It's my home, and it's in trouble.",
			"The shadows are eating up its moments of time. The Moon Clock's stuck at midnight."])
	out.append_array(["There's no portal to Dark Hollow. Not one you can see. The only way in is... through me.",
		"I'd gulp you up. GULP! Then a long, soft, glowy slide, and out you pop in Dark Hollow. Not a scratch. Centipede's honour.",
		"And the way home takes you straight out to the school's front gate. No dark passage. Do you want to go?", ask])
	return out


func _on_talked(id: String) -> void:
	if id != "centipede_corner":
		return
	for k in range(_log_before, Dialogue.choice_log.size()):
		var e: Dictionary = Dialogue.choice_log[k]
		if str(e.get("what", "")) == RECORD and str(e.get("answer", "")) == "yes":
			gulp.call_deferred()
			return


func gulp() -> void:
	# She circles round you, lifts her head... GULP! Then the long glowy slide down to Dark Hollow.
	if gulping:
		return
	gulping = true
	gulps += 1
	Game.hold_controls(&"gulp", true)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var round_at := to_local(player.global_position) if player else CORNER
	round_at.y = 0.0
	var tw := create_tween()
	tw.tween_property(her, "position", round_at, 0.3).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(her, "scale", Vector3.ONE * 0.62, 0.3)
	tw.tween_property(her, "rotation:y", her.rotation.y + TAU * (0.75 if Settings.reduce_motion else 1.5), CIRCLE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(her, "head_height", 2.4, CIRCLE_TIME)
	Audio.play_at("centipede_skitter", to_global(round_at), -2.0)
	tw.tween_callback(_close_iris)
	tw.tween_interval(IRIS_TIME + 0.5)
	tw.tween_callback(_slide)
	tw.tween_interval(SLIDE_TIME)
	tw.tween_callback(_arrive)


func _close_iris() -> void:
	_overlay = Gulp.new()
	_overlay.name = "Gulp"
	_overlay.layer = 90
	get_tree().root.add_child(_overlay)
	(_overlay as Gulp).close(IRIS_TIME)
	Juice.blip("pop", 0.45, 0.0)
	Juice.blip("thud", 0.7, -4.0)
	Juice.shake(0.2)
	Juice.rumble(0.5, 0.3, 0.3)


func _slide() -> void:
	if _overlay:
		(_overlay as Gulp).slide()
	Juice.blip("whoosh", 0.8, -4.0)


func _arrive() -> void:
	Game.hold_controls(&"gulp", false)
	gulping = false
	var o := _overlay
	_overlay = null
	if o:
		get_tree().create_timer(0.8, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(o):
				o.queue_free())
	Portals.enter_dark_hollow()


func _decorate() -> void:
	# Roots through the ceiling, glowing fungi on the walls, layered old stone at the end, her nest of lost things,
	# a soft violet light and a little hand-made sign. Nothing solid: the passage is narrow.
	var g := Node3D.new()
	g.name = "Decor"
	add_child(g)
	var root_m := _mat(Color(0.22, 0.14, 0.16), 0.0, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 9:                                            # roots hanging down from the ceiling, along the last 8 m
		var x := CORNER.x + 0.8 + k * 0.9
		var z := rng.randf_range(-23.5, -21.4)
		var h := rng.randf_range(0.6, 1.8)
		_put(g, _cyl(0.03, 0.07, h), root_m, Vector3(x, 5.65 - h / 2.0, z), Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
	var fungus := [_mat(Color(0.4, 1.0, 0.85), 1.4, 0.5), _mat(Color(0.75, 0.5, 1.0), 1.4, 0.5)]
	for k in 16:                                           # glowing shelf fungi on both walls and the end wall
		var x := CORNER.x - 1.0 + rng.randf() * 7.0
		var on_north := k % 2 == 0
		var z := -23.66 if on_north else -21.2
		var p := Vector3(x, rng.randf_range(0.3, 3.2), z)
		var cap := _put(g, _ball(rng.randf_range(0.1, 0.2)), fungus[k % 2], p)
		cap.scale = Vector3(1.0, 0.45, 0.6)
	var slab_m := [_mat(Color(0.32, 0.28, 0.38), 0.0, 0.9), _mat(Color(0.25, 0.22, 0.3), 0.0, 0.9), _mat(Color(0.38, 0.33, 0.42), 0.0, 0.9)]
	for k in 10:                                           # layered stone on the end wall
		var y := 0.25 + k * 0.52
		_put(g, _box(Vector3(0.18, 0.48, rng.randf_range(1.6, 2.4))), slab_m[k % 3],
			Vector3(-29.62 + rng.randf_range(-0.05, 0.05), y, -22.45 + rng.randf_range(-0.3, 0.3)))
	# Her nest: a ring of soft lost things round her
	var sock_cols := [Color(1.0, 0.45, 0.6), Color(0.45, 0.8, 1.0), Color(1.0, 0.85, 0.3), Color(0.6, 1.0, 0.5)]
	for k in 8:
		var a := k * TAU / 8.0
		var p := CORNER + Vector3(cos(a) * 1.35, 0.06, sin(a) * 1.05)
		_put(g, _box(Vector3(0.32, 0.08, 0.12)), _mat(sock_cols[k % 4], 0.0, 0.9), p, Vector3(0, a, 0))
	_put(g, _box(Vector3(0.36, 0.26, 0.2)), _mat(Color(0.95, 0.35, 0.35)), CORNER + Vector3(1.1, 0.13, 0.75))      # a lunchbox
	_put(g, _box(Vector3(0.45, 0.5, 0.25)), _mat(Color(0.35, 0.45, 0.95)), CORNER + Vector3(-0.9, 0.25, -0.8))      # a backpack
	for k in 4:                                            # pencils
		_put(g, _cyl(0.02, 0.02, 0.4), _mat(Color(1.0, 0.82, 0.2)), CORNER + Vector3(0.6 + k * 0.1, 0.03, -0.9), Vector3(0, 0, PI / 2.0))
	for k in 3:                                            # crumpled paper
		_put(g, _ball(0.09), _mat(Color(0.95, 0.95, 0.9)), CORNER + Vector3(-1.2 + k * 0.4, 0.09, 0.9))
	var light := OmniLight3D.new()
	light.name = "Corner Glow"
	light.light_color = Color(0.7, 0.55, 1.0)
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position = CORNER + Vector3(1.0, 2.6, 0)
	g.add_child(light)
	var sign := Label3D.new()
	sign.text = "my corner\n(plees nock)"
	sign.font_size = 40
	sign.pixel_size = 0.01
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.9, 0.7)
	sign.position = Vector3(-29.5, 2.3, -22.45)
	sign.rotation.y = PI / 2.0
	g.add_child(sign)


func _mat(c: Color, emit := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	return c


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


# The gulp itself, drawn over everything: the screen closes like a mouth (a black ring closing in from the edges), a
# big "GULP!", then glowing rings rushing past on the long slide down.
class Gulp extends CanvasLayer:
	var canvas: Control
	var open := 1.0                        # 1 = the whole screen showing, 0 = shut
	var sliding := false
	var _t := 0.0
	var _word: Label

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		canvas = Control.new()
		canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.draw.connect(_draw_it)
		add_child(canvas)
		_word = Label.new()
		_word.set_anchors_preset(Control.PRESET_FULL_RECT)
		_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_word.add_theme_font_size_override("font_size", 120)
		_word.add_theme_color_override("font_color", Color(1.0, 0.85, 0.95))
		_word.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.4))
		_word.add_theme_constant_override("outline_size", 24)
		_word.visible = false
		add_child(_word)

	func close(secs: float) -> void:
		var tw := create_tween()
		tw.tween_method(func(k: float) -> void:
			open = k
			canvas.queue_redraw(), 1.0, 0.0, secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_word.text = "GULP!"
			_word.visible = true
			_word.pivot_offset = _word.size / 2.0
			_word.scale = Vector2.ONE * 0.4
			create_tween().tween_property(_word, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

	func slide() -> void:
		sliding = true
		_word.text = "Wheeeee..."
		_word.add_theme_font_size_override("font_size", 72)

	func _process(delta: float) -> void:
		_t += delta
		if sliding:
			canvas.queue_redraw()

	func _draw_it() -> void:
		var size := canvas.size
		var mid := size / 2.0
		var far := mid.length() + 4.0
		if not sliding:
			# A black ring from the edges in to the mouth's opening (an oval, a little wider than tall)
			var r := far * open
			if r < far:
				var pts := PackedVector2Array()
				var steps := 48
				for k in steps + 1:
					var a := k * TAU / steps
					pts.append(mid + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.85))
				for k in steps + 1:
					var a := -k * TAU / steps
					pts.append(mid + Vector2(cos(a) * far * 1.5, sin(a) * far * 1.5))
				canvas.draw_colored_polygon(pts, Color(0.03, 0.01, 0.05))
			return
		# The slide: rings of soft glow rushing out from the middle on black
		canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.01, 0.05))
		var speed := 0.35 if Settings.reduce_motion else 0.9
		var cols := [Color(0.55, 0.3, 0.95), Color(0.3, 0.9, 0.85), Color(0.95, 0.45, 0.8)]
		for k in 10:
			var f := fposmod(_t * speed + k / 10.0, 1.0)
			var r := far * f * f
			var c: Color = cols[k % 3]
			c.a = 0.25 + 0.6 * f
			canvas.draw_arc(mid, r, 0.0, TAU, 64, c, 6.0 + 30.0 * f, true)
