extends Node

# Dash's kinetic energy, the hero's to borrow (Hayden, 12 Nov 2026: "give dash kinetic energy"; the lore bible: he
# stores motion and lets it out in bursts). Dash teaches it once you've popped the Gloop King and told him about it
# (scripts/meetings.gd king_from_dash(), or kinetic_from_dash() for saves already past that): flag TAUGHT.
#
# Moving fast STORES motion: every metre run faster than STORE_ABOVE fills the charge a little (sprinting fills it
# quicker, since you go further), a big landing adds a bit, and riding fills it too. When it's full, it's let out ON A
# RIDE: press Flip (Shift / pad X, the same button that rolls on foot, and it does nothing on the ground on a ride) while
# rolling along on the ground and the ride shoots off in a KINETIC BOOST: BOOST_SPEED past pushing speed for
# BOOST_TIME, through goo and all, with a gold ring and sparks. Then it's empty again.
# (Hayden's 13 Nov 2026 playtest: "I want it to give you a boost while ur riding a vehicle, not a roll attack", and the
# meter moved out of the way: it's a gold KE bar under SP in the stats corner now, scripts/hud.gd set_kinetic().)
# Not in a race (the races are fair: every rider has the same boost pads, scripts/races.gd).
#
# The charge never drains by itself (nothing to lose by stopping for a chat).
#
# Made by the player (scenes/player/player.gd _ready).

signal burst(at: Vector3)

const TAUGHT := "kinetic_taught"
const STORE_ABOVE := 3.0                  # metres a second: walking doesn't count, running does
const METRES_TO_FILL := 32.0              # running this far fills it
const RIDE_METRES_TO_FILL := 90.0         # on a ride it fills slower (rides go a long way)
const LANDING_SPEED := 9.0                # landing faster than this...
const LANDING_ADDS := 0.12                # ...adds this much
const BOOST_SPEED := 9.0                  # metres a second past the ride's pushing speed (a race's boost pad is 6.5)
const BOOST_TIME := 2.2                   # seconds (a boost pad is 1.3)
const RING_SIZE := 4.0
const GOLD := Color(1.0, 0.82, 0.25)

var player: CharacterBody3D
var charge := 0.0                         # 0 to 1
var bursts := 0                           # every boost so far (for the tests)
var _told_full := false                   # said "full!" for this charge
var _was_on_floor := true
var _fall := 0.0


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
		"Everything that moves has got go in it. Running, riding, falling, all of it. Most people let it slip away. I keep mine.",
		"I store it up. And then... (He stamps on the pedals. WHOOSH! He shoots off in a streak of gold and skids back round.) ...I let it ALL out at once!",
		"Here, you try. Run about and ride about and the go builds up in you. See the gold bar by your stats? When it's full, hop on your ride and press {skate_flip} while you're rolling along. Zoom!",
		"{player}: It tickles!",
		"That's the go! Where I come from, everything runs on it. Er. Lots of places. Probably.",
	]


func add(amount: float) -> void:
	if amount <= 0.0 or not unlocked():
		return
	var was := charge
	charge = clampf(charge + amount, 0.0, 1.0)
	if charge != was:
		if charge >= 1.0 and was < 1.0:
			Juice.blip("sparkle", 1.4, -8.0)
			if player and player.get("visual"):
				Juice.squash(player.visual as Node3D, 0.1)


func can_boost() -> bool:
	# Full, on a ride, rolling along on the ground (in the air Flip's a trick), and not in a race
	if not unlocked() or not full() or player == null or not Game.riding or player.get("input_locked"):
		return false
	var skate: Node = player.get("skate")
	if skate == null or int(skate.get("state")) != 0:          # skate.gd State.ROLL
		return false
	return not Races.racing()


func ride_boost() -> bool:
	# Let the charge out as a boost on the ride. True if it went.
	if not can_boost():
		return false
	var skate: Node = player.get("skate")
	skate.call("boost", BOOST_SPEED, BOOST_TIME)
	skate.set("_flip_press", 9.0)                              # the press was the boost, not a trick's start
	charge = 0.0
	_told_full = false
	bursts += 1
	var at := player.global_position
	_ring(at)
	Audio.play("boing", -2.0, 0.05)
	Juice.blip("chime", 0.7, -4.0)
	Juice.shake(0.2)
	Juice.rumble(0.5, 0.25, 0.4)
	if player.get("spring_arm") and not Settings.reduce_motion:
		player.spring_arm.set("fov_kick", 9.0)
	Game.message("⚡ Kinetic boost!")
	burst.emit(at)
	return true


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
	tw.tween_property(hoop, "scale", Vector3(RING_SIZE, 2.0, RING_SIZE), 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
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
	if Game.riding and full() and Input.is_action_just_pressed("skate_flip") and ride_boost():
		return
	var on_floor := player.is_on_floor()
	var flat_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if Game.riding:
		if not player.boosting():                             # a boost doesn't fill it straight back up
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
	var hud := _hud()
	if hud == null:
		return
	hud.set_kinetic(unlocked(), charge, full())
	if full() and not _told_full and unlocked() and not Dialogue.is_active():
		_told_full = true
		Game.message("⚡ Kinetic full! On a ride, press %s for a boost" % Settings.prompt("skate_flip"))


func _hud() -> Node:
	if player == null:
		return null
	var h := player.get_node_or_null("HUD")
	return h if h and h.has_method("set_kinetic") else null


func meter_shown() -> bool:
	var h := _hud()
	return h != null and h.kinetic_shown()
