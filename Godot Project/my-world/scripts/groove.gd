extends Node

# Melody's groove, the player's own: Rhythm Springs' reward (scripts/rhythm_springs.gd). Like Bramble's burrow and
# Flurry's frost breath it's locked until her world's mended: before Portals.is_cleared("rhythm_springs"), pressing
# Groove does nothing and the Controls list doesn't show it (Settings.action_shown()). Melody teaches it as the
# Off-Beat shrinks back into time (rhythm_springs.gd _teach_groove()).
#
# Press Groove on foot and the hero spins and hops into a little dance, and a ring of music notes bursts out round
# them. Any enemy the ring reaches can't help it: they stop chasing and dance on the spot for DANCE_TIME seconds
# (like the Disco Ball, scripts/disco_ball.gd), so you can slip past or pop them.
#
# Melody's beat (BEAT, the same steady beat as her Dance Floor) is always ticking. Groove ON the beat, beat after beat,
# and you're in the groove: each one in a row (streak) throws the ring further (RING + RING_GROWS a step, at most
# STREAK_TOP steps), and from STREAK_RUSH in a row, if you're on the move, the music carries you along in a speed
# rush (Player.boost()). A
# little beat card at the bottom of the screen pulses with the beat for a few seconds after each groove, so you can
# find it. Off the beat it's still a dance, just a small one, and the streak starts again.
#
# Melody's Stage in the Void (scripts/melody_stage.gd) listens to `grooved` for its dance-off.
# Made by the player (scenes/player/player.gd _ready).

signal grooved(on_beat: bool, streak: int)

const WORLD := "rhythm_springs"           # the world whose mending unlocks it
const BEAT := 0.8                          # Melody's steady beat (rhythm_springs.gd DANCE_BEAT)
const WINDOW := 0.2                        # seconds either side of a beat that count as on it
const COOLDOWN := 0.3
const RING := 5.0                          # how far the notes reach off the beat
const RING_GROWS := 1.5                    # ...and how much further for each on-beat groove in a row
const STREAK_TOP := 4
const STREAK_RUSH := 4                     # this many in a row and the music carries you along
const RUSH_SPEED := 3.0
const RUSH_TIME := 1.6
const DANCE_TIME := 4.0                    # how long an enemy dances
const SHOW_BEAT_FOR := 3.0                 # the beat card stays up this long after a groove
const SPIN_TIME := 0.42
const NOTE_COLOURS := [Color(1.0, 0.55, 0.85), Color(0.7, 0.55, 1.0), Color(1.0, 0.85, 0.35), Color(0.5, 0.9, 1.0),
	Color(0.6, 1.0, 0.6)]

var player: CharacterBody3D
var cooldown := 0.0
var streak := 0                            # on-beat grooves in a row
var grooves := 0                           # every groove so far (for the tests)
var last_ring := 0.0                       # how far the last one reached (for the tests)
var dancers := {}                          # enemy -> {visual, pos, rot, phase, note, until}; tests read it
var clock_offset := 0.0                    # tests nudge the beat clock with this
var _last_at := -100.0
var _spinning := false
var _hud: CanvasLayer
var _card: PanelContainer
var _beat_dot: Label
var _streak_label: Label
var _shown_until := 0.0


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func can_groove() -> bool:
	if not unlocked() or player == null or cooldown > 0.0:
		return false
	if Game.riding or player.carried or player.input_locked:
		return false
	if player.burrow and player.burrow.active:
		return false
	return true


# The beat -------------------------------------------------------------------------------------------------------
func now() -> float:
	return Time.get_ticks_msec() / 1000.0 + clock_offset


func beat_phase() -> float:
	# 0 on a beat, rising to 1 just before the next
	return fposmod(now(), BEAT) / BEAT


func off_by() -> float:
	# Seconds from the nearest beat
	var into := fposmod(now(), BEAT)
	return minf(into, BEAT - into)


func on_beat() -> bool:
	return off_by() <= WINDOW


func ring_for(n: int) -> float:
	return RING + RING_GROWS * mini(n, STREAK_TOP)


# Grooving -------------------------------------------------------------------------------------------------------
func try_groove() -> bool:
	# Called by the player when Groove is pressed
	if not can_groove():
		return false
	groove()
	return true


func groove() -> void:
	cooldown = COOLDOWN
	grooves += 1
	var t := now()
	var hit := on_beat()
	if hit:
		# In a row if the last groove was on the beat before this one, or the one before that (so a kid can take a
		# breath between)
		streak = streak + 1 if streak > 0 and t - _last_at <= BEAT * 2.0 + WINDOW * 2.0 else 1
	else:
		streak = 0
	_last_at = t
	last_ring = ring_for(streak)
	_shown_until = t + SHOW_BEAT_FOR
	_spin()
	_ring(last_ring, hit)
	_set_dancing(last_ring)
	if streak >= STREAK_RUSH and Vector2(player.velocity.x, player.velocity.z).length() > 1.0:
		player.boost(RUSH_SPEED, RUSH_TIME)            # (only on the move: dancing on the spot keeps you on the spot)
	Juice.blip("sparkle" if hit else "chime", 0.9 + 0.1 * mini(streak, STREAK_TOP), -6.0)
	if hit and streak >= 2:
		Juice.squash(player.visual, 0.12)
	_show_card()
	grooved.emit(hit, streak)


func _spin() -> void:
	# A twirl and a hop on the hero's model (the model's own turn and height are put back exactly afterwards)
	var model := player.get("model") as Node3D
	if model == null or _spinning:
		return
	_spinning = true
	var r0 := model.rotation.y
	var y0 := model.position.y
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(model):
			model.rotation.y = r0 + TAU * k
			model.position.y = y0 + sin(k * PI) * 0.35, 0.0, 1.0, SPIN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(model):
			model.rotation.y = r0
			model.position.y = y0
		_spinning = false)


func _ring(radius: float, hit: bool) -> void:
	# A ring of music notes bursting out round the hero, and a bright hoop on the ground that grows to show how far
	var scene := get_tree().current_scene
	if scene == null:
		return
	var at := player.global_position
	var n := 10 + mini(streak, STREAK_TOP) * 2
	for k in n:
		var l := Label3D.new()
		l.name = "GrooveNote"
		l.text = ["♪", "♫", "♬"][k % 3]
		l.font_size = 96
		l.pixel_size = 0.006
		l.outline_size = 14
		l.outline_modulate = Color(0.15, 0.06, 0.2)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = NOTE_COLOURS[(k + streak) % NOTE_COLOURS.size()]
		scene.add_child(l)
		var a := k * TAU / n
		l.global_position = at + Vector3(0, 1.0, 0)
		var to := at + Vector3(sin(a) * radius, 1.0 + randf() * 0.8, cos(a) * radius)
		var tw := l.create_tween().set_parallel()
		tw.tween_property(l, "global_position", to, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
		tw.chain().tween_callback(l.queue_free)
	var hoop := MeshInstance3D.new()
	hoop.name = "GrooveRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	hoop.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.75, 0.95, 0.8) if hit else Color(0.9, 0.85, 1.0, 0.5)
	hoop.material_override = m
	scene.add_child(hoop)
	hoop.global_position = at + Vector3(0, 0.15, 0)
	hoop.scale = Vector3(0.3, 1, 0.3)
	var tw2 := hoop.create_tween().set_parallel()
	tw2.tween_property(hoop, "scale", Vector3(radius, 1, radius), 0.5).set_ease(Tween.EASE_OUT)
	tw2.tween_property(m, "albedo_color:a", 0.0, 0.25).set_delay(0.35)
	tw2.chain().tween_callback(hoop.queue_free)


# Enemies dancing --------------------------------------------------------------------------------------------------
func _set_dancing(radius: float) -> void:
	var until := now() + DANCE_TIME
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or e.get("defeated") or not (e as Node3D).is_visible_in_tree():
			continue
		var n := e as Node3D
		var flat := Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z)
		if flat.length() > radius or absf(n.global_position.y - player.global_position.y) > 4.0:
			continue
		if n.has_method("shelled") and n.shelled():
			continue                                   # a rolled-up Crocodillo can't hear the music in its shell
		if Arsenal.is_plush(n):
			continue                                   # a plushie is a toy just now
		if dancers.has(n):
			dancers[n].until = until                   # dancing already: the song goes on
			continue
		var v := n.get_node_or_null("Visual") as Node3D
		dancers[n] = {"visual": v, "pos": v.position if v else Vector3.ZERO, "rot": v.rotation if v else Vector3.ZERO,
			"phase": randf() * TAU, "note": _note(n), "until": until}
		n.set_physics_process(false)                   # no chasing or bumping into anyone while they dance
		if n is CharacterBody3D:
			(n as CharacterBody3D).velocity = Vector3.ZERO


func is_dancing(e: Node) -> bool:
	return dancers.has(e)


func _note(e: Node3D) -> Label3D:
	var l := Label3D.new()
	l.name = "GrooveDanceNote"
	l.text = "♪ ♫"
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 12
	l.outline_modulate = Color(0.15, 0.08, 0.2)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	e.add_child(l)
	return l


func _dance(e: Node3D, d: Dictionary, t: float) -> void:
	var v: Node3D = d.visual
	if v == null or not is_instance_valid(v):
		return
	var ph: float = t * 6.0 + float(d.phase)
	v.position = d.pos + Vector3(sin(ph * 0.5) * 0.15, absf(sin(ph)) * 0.25, 0)
	v.rotation = d.rot + Vector3(0, ph * 0.35, sin(ph * 0.5) * 0.25)
	var note: Label3D = d.note
	if note and is_instance_valid(note):
		note.position.y = 1.4 * float(e.get("size") if e.get("size") != null else 1.0) + sin(ph * 0.5) * 0.15
		note.modulate = NOTE_COLOURS[int(t * 2.0 + float(d.phase)) % NOTE_COLOURS.size()]


func let_go(e: Variant) -> void:
	if not dancers.has(e):
		return
	var d: Dictionary = dancers[e]
	dancers.erase(e)
	if d.note and is_instance_valid(d.note):
		(d.note as Node).queue_free()
	if not is_instance_valid(e):
		return
	var v: Node3D = d.visual
	if v and is_instance_valid(v):
		v.rotation = d.rot
		if e.get("defeated") != true:
			v.position = d.pos            # (a popped one floats off in its bubble from where it was dancing)
	(e as Node3D).set_physics_process(true)


func _exit_tree() -> void:
	# The player's going (a scene change): nobody's left dancing
	for e in dancers.keys():
		let_go(e)


# Every frame ------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var t := now()
	for e in dancers.keys():
		if not is_instance_valid(e) or e.get("defeated") == true or t >= float(dancers[e].until):
			let_go(e)
		else:
			_dance(e, dancers[e], t)
	if streak > 0 and t - _last_at > BEAT * 2.0 + WINDOW * 2.0:
		streak = 0                                     # missed a couple of beats: the groove's gone
	_update_card(t)


# The beat card --------------------------------------------------------------------------------------------------
func _make_card() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Groove HUD"
	_hud.layer = 5
	add_child(_hud)
	_card = PanelContainer.new()
	_card.name = "Beat"
	_card.add_theme_stylebox_override("panel", UiStyle.card(Color(0.28, 0.1, 0.32, 0.85)))
	_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_card.custom_minimum_size = Vector2(230, 0)
	_card.position = Vector2(-115, -150)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	_beat_dot = Label.new()
	_beat_dot.text = "♪"
	_beat_dot.add_theme_font_size_override("font_size", 34)
	_beat_dot.pivot_offset = Vector2(12, 22)
	row.add_child(_beat_dot)
	_streak_label = Label.new()
	_streak_label.add_theme_font_size_override("font_size", 22)
	row.add_child(_streak_label)
	_hud.add_child(_card)
	_card.visible = false


func _show_card() -> void:
	if _card == null:
		_make_card()
	_card.visible = true
	_update_card(now())


func streak_words() -> String:
	if streak <= 0:
		return "Groove on the beat!"
	if streak >= STREAK_RUSH:
		return "In the groove! x%d" % streak
	return "On the beat! x%d" % streak


func _update_card(t: float) -> void:
	if _card == null:
		return
	_card.visible = t < _shown_until and get_tree().current_scene != null
	if not _card.visible:
		return
	var k := 1.0 - beat_phase()                          # 1 on the beat, fading till the next
	var pulse := 1.0 + 0.45 * k * k
	_beat_dot.scale = Vector2(pulse, pulse)
	_beat_dot.modulate = Color(1.0, 0.6, 0.9).lerp(Color(1, 1, 1), 1.0 - k)
	_streak_label.text = streak_words()


func card_shown() -> bool:
	return _card != null and _card.visible
