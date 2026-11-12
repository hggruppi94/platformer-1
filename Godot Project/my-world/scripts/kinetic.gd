extends Node

# Dash's kinetic energy, the hero's to borrow (Hayden, 12 Nov 2026: "give dash kinetic energy"; the lore bible: he
# stores motion and lets it out in bursts). Dash teaches it once you've popped the Gloop King and told him about it
# (scripts/meetings.gd king_from_dash(), or kinetic_from_dash() for saves already past that): flag TAUGHT.
#
# No new button (every pad button's busy, and it's kinder for small hands). Moving fast on foot STORES motion: every
# metre run faster than STORE_ABOVE fills the charge a little (sprinting fills it quicker, since you go further), a
# big landing adds a bit, and riding fills it slowly too. When it's full, the next Roll lets it all out at once: a
# KINETIC BURST. The roll shoots off BURST_ROLL times as fast, a gold shock ring rolls out round the hero, and every
# enemy it reaches takes BURST_POWER (a Gloop pops, a big one wobbles), and it all goes back to empty.
#
# The charge never drains by itself (nothing to lose by stopping for a chat). A little meter at the bottom of the
# screen shows it while it's filling and when it's full ("Roll to let it go!").
#
# Made by the player (scenes/player/player.gd _ready). The player asks roll_boost() as a roll starts.

signal burst(at: Vector3, hit: int)

const TAUGHT := "kinetic_taught"
const STORE_ABOVE := 3.0                  # metres a second: walking doesn't count, running does
const METRES_TO_FILL := 32.0              # running this far fills it
const RIDE_METRES_TO_FILL := 90.0         # on a ride it fills slower (rides go a long way)
const LANDING_SPEED := 9.0                # landing faster than this...
const LANDING_ADDS := 0.12                # ...adds this much
const BURST_ROLL := 1.8                   # how much faster the roll goes when it lets the charge out
const BURST_RADIUS := 6.5
const BURST_POWER := 2                    # what a burst does to an enemy, in bubbles (scripts/star_bubble.gd shot())
const SHOW_FOR := 2.5                     # the meter stays up this long after the charge last changed
const GOLD := Color(1.0, 0.82, 0.25)

var player: CharacterBody3D
var charge := 0.0                         # 0 to 1
var bursts := 0                           # every burst so far (for the tests)
var last_hit := 0                         # how many enemies the last burst reached (for the tests)
var _was_on_floor := true
var _fall := 0.0
var _changed_at := -100.0
var _hud: CanvasLayer
var _card: PanelContainer
var _bar: ProgressBar
var _label: Label


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	return Dialogue.flags.has(TAUGHT)


func full() -> bool:
	return charge >= 1.0


static func teach_lines() -> Array:
	# Dash shows the hero how he does it. Said after whatever led up to it; sets the flag as it's read.
	Dialogue.set_flag(TAUGHT)
	return [
		"Ooh, wait, wait. Before you go. Want to see my best trick? Not a gadget. A ME trick.",
		"(Dash pedals a quick circle round you. Little gold sparks crackle off his wheels.)",
		"Everything that moves has got go in it. Running, rolling, falling, all of it. Most people let it slip away. I keep mine.",
		"I store it up. And then... (He hops off and rolls. WHUMP! A gold ring bursts out across the grass.) ...I let it ALL out at once!",
		"Here, you try. Run about and the go builds up in you. When it's full, roll with {dash} and it all comes out in one big burst. Gloops HATE it.",
		"{player}: It tickles!",
		"That's the go! Where I come from, everything runs on it. Er. Lots of places. Probably.",
	]


func add(amount: float) -> void:
	if amount <= 0.0 or not unlocked():
		return
	var was := charge
	charge = clampf(charge + amount, 0.0, 1.0)
	if charge != was:
		_changed_at = _now()
		if charge >= 1.0 and was < 1.0:
			Juice.blip("sparkle", 1.4, -8.0)
			if player and player.get("visual"):
				Juice.squash(player.visual as Node3D, 0.1)


func roll_boost() -> float:
	# The player's roll is starting: with a full charge it's a burst
	if not unlocked() or not full() or player == null:
		return 1.0
	_burst()
	return BURST_ROLL


func _burst() -> void:
	charge = 0.0
	bursts += 1
	_changed_at = _now()
	var at := player.global_position
	var dir: Vector3 = player.facing_dir() if player.has_method("facing_dir") else Vector3.FORWARD
	last_hit = 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or e.get("defeated") == true or not (e as Node3D).is_visible_in_tree():
			continue
		var n := e as Node3D
		var flat := Vector2(n.global_position.x - at.x, n.global_position.z - at.z)
		if flat.length() > BURST_RADIUS or absf(n.global_position.y - at.y) > 3.5:
			continue
		if Arsenal.is_plush(n):
			continue                                   # a plushie's a toy just now: leave it be
		if n.has_method("shot"):
			var away := Vector3(flat.x, 0.0, flat.y)
			n.shot(BURST_POWER, n.global_position, away.normalized() if away.length() > 0.01 else dir)
			last_hit += 1
	_ring(at)
	Audio.play("boing", -2.0, 0.05)
	Juice.blip("chime", 0.7, -4.0)
	Juice.shake(0.3)
	Juice.rumble(0.5, 0.25, 0.4)
	Juice.hitstop(0.05)
	burst.emit(at, last_hit)


func _ring(at: Vector3) -> void:
	# A gold shock ring across the ground and crackling sparks
	var scene := get_tree().current_scene
	if scene == null:
		return
	var hoop := MeshInstance3D.new()
	hoop.name = "KineticRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 6
	hoop.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(GOLD, 0.9)
	hoop.material_override = m
	scene.add_child(hoop)
	hoop.global_position = at + Vector3(0, -0.6, 0)
	hoop.scale = Vector3(0.4, 1.0, 0.4)
	var tw := hoop.create_tween().set_parallel()
	tw.tween_property(hoop, "scale", Vector3(BURST_RADIUS, 2.0, BURST_RADIUS), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25).set_delay(0.25)
	tw.chain().tween_callback(hoop.queue_free)
	Juice.burst(scene, at + Vector3(0, 0.3, 0), GOLD, 22, 0.09, 6.0, 0.6)
	Juice.burst(scene, at + Vector3(0, 0.3, 0), Color(1.0, 1.0, 0.85), 10, 0.06, 3.0, 0.4)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# Every frame ------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if player == null or not unlocked() or player.get("carried"):
		return
	var on_floor := player.is_on_floor()
	var flat_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if Game.riding:
		add(flat_speed * delta / RIDE_METRES_TO_FILL)
	elif on_floor and flat_speed > STORE_ABOVE and not player.call("is_rolling"):
		add(flat_speed * delta / METRES_TO_FILL)
	if not on_floor:
		_fall = maxf(_fall, -player.velocity.y)
	elif not _was_on_floor:
		if _fall >= LANDING_SPEED:
			add(LANDING_ADDS)
		_fall = 0.0
	_was_on_floor = on_floor


func _process(_delta: float) -> void:
	var want := unlocked() and (full() or (charge > 0.0 and _now() - _changed_at < SHOW_FOR)) \
		and get_tree().current_scene != null and not Dialogue.is_active()
	if not want:
		if _card:
			_card.visible = false
		return
	if _card == null:
		_make_card()
	_card.visible = true
	_bar.value = charge * 100.0
	if full():
		_label.text = "⚡ Full! Roll to let it go!"
		var k := 0.5 + 0.5 * sin(_now() * 8.0)
		_label.modulate = Color(1, 1, 1).lerp(GOLD, k)
	else:
		_label.text = "⚡ Kinetic"
		_label.modulate = Color(1, 1, 1)


func meter_shown() -> bool:
	return _card != null and _card.visible


func _make_card() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Kinetic HUD"
	_hud.layer = 5
	add_child(_hud)
	_card = PanelContainer.new()
	_card.name = "Kinetic"
	_card.add_theme_stylebox_override("panel", UiStyle.card(Color(0.3, 0.2, 0.05, 0.85)))
	_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_card.custom_minimum_size = Vector2(250, 0)
	_card.position = Vector2(-125, -210)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_card.add_child(col)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 20)
	col.add_child(_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(220, 12)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(_bar)
	_hud.add_child(_card)
