extends Node

# Nina and Bruno's making power, shared with the hero (Hayden, 12 Nov 2026: "nina and bruno share an ability to
# create, but its weaker for that reason"). Two of them share one power, and they share it with you too, so what it
# makes is small, wobbly and doesn't last. Taught in their quest "Making Things" (res://quests/make_together.json):
# Bruno gives it as the flag TAUGHT is set. Locked till then: pressing Make does nothing and Settings > Controls
# doesn't list it (Settings.SECRET_FLAGS).
#
# Press Make (Z, RB) and something pops into being in front of you, in Nina's pink or Bruno's blue by turns:
#   - on the ground: a wobbly BRIDGE, a plank PLANK_LONG metres long at your feet's height, stretching out ahead of
#     you (over a gap, a stream, a bit of goo);
#   - in the air: a STEP under your feet to land on and jump again from. Only once a jump (it comes back when you
#     land), so it's a little lift, never a ladder to the sky.
# Each lasts LASTS seconds, blinks for the last BLINK, then pops into sparkles. Only MAX_THINGS at once (one each for
# Nina and Bruno): making another pops the oldest. Not while riding, burrowing, swimming, climbing or in a race.
#
# Before it's unlocked RB still rolls (Settings._bind_pad gives Roll RB too); after, RB makes and the player skips the
# roll that same press (scenes/player/player.gd).
#
# Made by the player (scenes/player/player.gd _ready).

signal made(thing: Node3D, kind: String)

const TAUGHT := "make_taught"
const TRIED := "made_three"               # set after the first three things (the quest's "try it" step)
const LASTS := 6.0
const BLINK := 1.5
const MAX_THINGS := 2
const COOLDOWN := 0.5
const PLANK_LONG := 4.5
const PLANK_WIDE := 1.6
const PLANK_THICK := 0.25
const STEP_SIZE := 1.5
const STEP_THICK := 0.35
const COLOURS := [Color(1.0, 0.3, 0.62), Color(0.25, 0.5, 1.0)]     # Nina's pink, Bruno's blue
const WHO := ["Nina", "Bruno"]

var player: CharacterBody3D
var cooldown := 0.0
var things: Array = []                   # [{node, left (seconds), kind}] oldest first; tests read it
var made_count := 0
var _turn := 0                            # whose colour the next one is
var _air_step_used := false


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	return Dialogue.flags.has(TAUGHT)


func can_make() -> bool:
	if not unlocked() or player == null or cooldown > 0.0:
		return false
	if Game.riding or player.get("carried") or player.get("input_locked"):
		return false
	for n in ["burrow", "swim", "wall_crawl"]:
		var m = player.get(n)
		if m and m.get("active"):
			return false
	var races := get_node_or_null("/root/Races")
	if races and races.has_method("racing") and races.racing():
		return false
	if not player.is_on_floor() and _air_step_used:
		return false
	return get_tree().current_scene != null


func try_make() -> bool:
	if not can_make():
		return false
	make()
	return true


func make() -> Node3D:
	cooldown = COOLDOWN
	var on_floor := player.is_on_floor()
	var kind := "bridge" if on_floor else "step"
	if not on_floor:
		_air_step_used = true
	while things.size() >= MAX_THINGS:
		_pop(things[0])
	var colour: Color = COLOURS[_turn % COLOURS.size()]
	_turn += 1
	var feet := player.global_position + Vector3(0, -0.8, 0)          # (the player's middle is 0.8 m up its capsule)
	var fwd: Vector3 = player.facing_dir() if player.has_method("facing_dir") else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var size: Vector3
	var centre: Vector3
	if kind == "bridge":
		size = Vector3(PLANK_WIDE, PLANK_THICK, PLANK_LONG)
		centre = feet + fwd * (PLANK_LONG * 0.5 + 0.3) + Vector3(0, -PLANK_THICK * 0.5 + 0.03, 0)   # (a hair above the ground, so it shows on the flat; her round feet ride up onto it)
	else:
		size = Vector3(STEP_SIZE, STEP_THICK, STEP_SIZE)
		centre = feet + Vector3(0, -STEP_THICK * 0.5 - 0.15, 0)
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0                                    # caught: a gentle stop, not a thump
	var thing := _build(kind, size, colour)
	get_tree().current_scene.add_child(thing)
	thing.global_position = centre
	thing.look_at(centre + fwd, Vector3.UP)
	things.append({"node": thing, "left": LASTS, "kind": kind})
	made_count += 1
	if made_count >= 3 and not Dialogue.flags.has(TRIED):
		Dialogue.set_flag(TRIED)
	var scene := get_tree().current_scene
	Juice.burst(scene, centre + Vector3(0, 0.2, 0), colour, 14, 0.08, 2.5, 0.5)
	Juice.blip("sparkle", 1.2 if _turn % 2 == 0 else 1.0, -7.0)
	made.emit(thing, kind)
	return thing


func _build(kind: String, size: Vector3, colour: Color) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Made " + kind.capitalize()
	body.add_to_group("made_thing")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	# The look: a soft glowing slab with a lighter edge, wobbling a little on its own (only the picture moves: the
	# collision stays still so it's safe to stand on)
	var look := Node3D.new()
	look.name = "Look"
	body.add_child(look)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(colour, 0.92)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 0.25
	m.roughness = 0.4
	mesh.material_override = m
	look.add_child(mesh)
	var rim := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = size * Vector3(1.06, 0.4, 1.04) + Vector3(0, 0.02, 0)
	rim.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.albedo_color = Color(colour.lightened(0.35), 0.6)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim.material_override = rmat
	rim.position.y = size.y * 0.35
	look.add_child(rim)
	# Pops in with a wobble
	look.scale = Vector3(0.2, 0.2, 0.2)
	var tw := look.create_tween()
	tw.tween_property(look, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	body.set_meta("material", m)
	return body


func _pop(t: Dictionary) -> void:
	things.erase(t)
	var n: Node3D = t.node
	if not is_instance_valid(n):
		return
	var scene := get_tree().current_scene
	if scene and n.is_inside_tree():
		var m: StandardMaterial3D = n.get_meta("material")
		Juice.burst(scene, n.global_position, m.emission if m else Color.WHITE, 10, 0.07, 2.0, 0.45)
	n.queue_free()


func clear() -> void:
	for t in things.duplicate():
		_pop(t)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if player and player.is_on_floor():
		_air_step_used = false
	var t := _now()
	for th in things.duplicate():
		var n: Node3D = th.node
		if not is_instance_valid(n):
			things.erase(th)
			continue
		th.left = float(th.left) - delta                 # (game time, so a slow frame never eats one)
		var left: float = th.left
		if left <= 0.0:
			_pop(th)
			continue
		var look := n.get_node_or_null("Look") as Node3D
		if look == null:
			continue
		# A gentle wobble all the time (it's a shared power: it never quite holds still), blinking near the end
		look.rotation.z = sin(t * 5.0 + n.get_instance_id() % 7) * 0.025
		look.position.y = sin(t * 3.0) * 0.02
		look.visible = left > BLINK or Settings.reduce_flashing or fmod(left, 0.25) > 0.1


func _exit_tree() -> void:
	clear()
