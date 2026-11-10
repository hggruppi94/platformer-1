extends Node

# Heather's grow, the player's own: Glenmoor's reward (scripts/glenmoor.gd). Like Bramble's burrow, Flurry's frost
# breath and Melody's groove it's locked until her world's mended: before Portals.is_cleared("glenmoor"), pressing
# Grow does nothing and the Controls list doesn't show it (Settings.action_shown()). Heather teaches it as spring
# settles over the glen (glenmoor.gd _teach_grow()).
#
# Press Grow (H) on foot, or hold Interact for a moment with nothing about to talk to or use (that's how it works on a
# controller: every pad button already has a job, and holding B is easy for small hands), standing on soft ground (the same soil Bramble burrows in: Burrow.soil()), and a giant springy
# blossom shoots up out of the ground right under the hero and flings them up high (LAUNCH). The Bloomstalk stays
# there for LASTS seconds as a flower to stand on, and its cap's bouncy: drop back onto it and it springs you up again.
# Only MAX_STALKS at once (the oldest wilts away first). On paving, wood or water nothing can grow, and it says so.
#
# Near your garden in the Void (Farm), it gives every planted bed a drink and GARDEN_BOOST Void minutes of growing, at
# most once a Void hour.
# Made by the player (scenes/player/player.gd _ready).

const WORLD := "glenmoor"                 # the world whose mending unlocks it
const LAUNCH := 13.0                      # metres a second up (about 8 m high)
const BOUNCE := 11.0                      # landing on a Bloomstalk's cap
const HEIGHT := 2.6                       # how tall a Bloomstalk's cap stands
const CAP_R := 1.3
const LASTS := 30.0
const MAX_STALKS := 3
const COOLDOWN := 0.8
const HOLD := 0.4                         # seconds of holding Interact (with nothing to interact with) to grow
const GARDEN_NEAR := 9.0
const GARDEN_BOOST := 60.0                # Void minutes
const PETALS := [Color(1.0, 0.72, 0.85), Color(1.0, 0.85, 0.4), Color(0.85, 0.7, 1.0), Color(1.0, 0.55, 0.6)]

var player: CharacterBody3D
var cooldown := 0.0
var stalks: Array[Node3D] = []            # the Bloomstalks out there now, oldest first
var grows := 0                            # (for the tests)
var bounces := 0                          # (for the tests)
var _told_hard := false
var _garden_at := -1000.0                 # the Void minute the garden last got a boost
var _hold := -1.0                         # how long Interact's been held with nothing near (-1: not counting)
var _foot := 0.8                          # how far the hero's middle is above their feet


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func can_grow() -> bool:
	if not unlocked() or player == null or cooldown > 0.0:
		return false
	if Game.riding or player.carried or player.input_locked or not player.is_on_floor():
		return false
	if player.burrow and player.burrow.active:
		return false
	if player.swim and player.swim.active:
		return false
	return true


func on_soil() -> bool:
	var kind: String = player.ground_kind()
	if kind == "water" or kind == "cloud":
		return false
	return preload("res://scripts/burrow.gd").soil(player._floor_node)


func try_grow() -> bool:
	# Called by the player when Grow is pressed on foot
	if not can_grow():
		return false
	if not on_soil():
		cooldown = COOLDOWN
		Juice.blip("tick", 0.7, -8.0)
		if not _told_hard:
			_told_hard = true
			Game.message("Nothing can grow in that! Find some grass or soil, then Grow.")
		return false
	grow()
	return true


func grow() -> Node3D:
	cooldown = COOLDOWN
	grows += 1
	var at := feet()
	_foot = player.global_position.y - at.y
	var s := stalk_model(PETALS[grows % PETALS.size()])
	get_tree().current_scene.add_child(s)
	s.global_position = at
	s.rotation.y = randf() * TAU
	s.set_meta("until", Time.get_ticks_msec() / 1000.0 + LASTS)
	stalks.append(s)
	while stalks.size() > MAX_STALKS:
		_wilt(stalks[0])
	var look := s.get_node("Look") as Node3D
	look.scale = Vector3(0.3, 0.05, 0.3)
	var tw := s.create_tween()
	tw.tween_property(look, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Up you go: the flower lifts the hero onto its cap as it shoots up, and flings them on up from there
	player.global_position.y = at.y + HEIGHT + _foot + 0.05
	player.velocity.y = maxf(player.velocity.y, LAUNCH)
	Juice.squash(player.get("model"), 0.2, 0.25)
	Juice.dust(get_tree().current_scene, at, 1.0)
	Fx.burst(get_tree().current_scene, at + Vector3(0, HEIGHT, 0), s.get_meta("petal"), 18, 0.08, 3.5, -1.0, 0.9)
	Audio.play("boing", -4.0, 0.15)
	Juice.blip("chime", 1.3, -6.0)
	_boost_garden(at)
	return s


func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	_hold_interact(delta)
	var now := Time.get_ticks_msec() / 1000.0
	for s in stalks.duplicate():
		if not is_instance_valid(s):
			stalks.erase(s)
			continue
		var left: float = float(s.get_meta("until")) - now
		if left <= 0.0:
			_wilt(s)
		elif left < 3.0:
			# About to wilt: it droops and sways, so nobody's surprised
			(s.get_node("Look") as Node3D).rotation.z = sin(left * 9.0) * 0.08


func _hold_interact(delta: float) -> void:
	# Holding Interact grows too, but only a press that started with nobody and nothing in reach (so finishing a talk
	# or using a spot never flings you up)
	if not unlocked() or player == null:
		return
	if Input.is_action_just_pressed("interact"):
		_hold = 0.0 if nothing_near() else -1.0
	if _hold < 0.0:
		return
	if not Input.is_action_pressed("interact") or not nothing_near():
		_hold = -1.0
		return
	_hold += delta
	if _hold >= HOLD:
		_hold = -1.0
		try_grow()


func nothing_near() -> bool:
	return not Dialogue.is_active() and Dialogue._near.is_empty()


func feet() -> Vector3:
	# Where the hero's feet are: the ground straight under them
	var q := PhysicsRayQueryParameters3D.create(player.global_position, player.global_position + Vector3(0, -2.5, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else player.global_position - Vector3(0, 0.8, 0)


func on_cap(s: Node3D) -> bool:
	# Is the hero standing on (or dropping onto) this Bloomstalk's cap?
	if player == null or not is_instance_valid(s):
		return false
	var d := player.global_position - s.global_position
	return Vector2(d.x, d.z).length() < CAP_R and absf(d.y - _foot - HEIGHT) < 0.6


func _physics_process(_delta: float) -> void:
	# Bouncy caps: drop onto one and it springs you up again
	if player == null or Game.riding:
		return
	if player.velocity.y > 0.5 and not player.is_on_floor():
		return
	for s in stalks:
		if on_cap(s) and (player.is_on_floor() or player.velocity.y < -1.0):
			bounce(s)
			return


func bounce(s: Node3D) -> void:
	bounces += 1
	player.velocity.y = BOUNCE
	Juice.squash(s.get_node("Look/Cap"), -0.3, 0.25)
	Audio.play("boing", -6.0, 0.2)


func _wilt(s: Node3D) -> void:
	stalks.erase(s)
	if not is_instance_valid(s):
		return
	Fx.burst(s.get_parent(), s.global_position + Vector3(0, HEIGHT, 0), s.get_meta("petal"), 10, 0.07, 1.5, -2.0, 0.6)
	var tw := s.create_tween()
	tw.tween_property(s.get_node("Look"), "scale", Vector3(0.2, 0.02, 0.2), 0.35)
	tw.tween_callback(s.queue_free)


func _boost_garden(at: Vector3) -> int:
	# Heather's touch near your garden: every planted bed gets a drink and an hour's growing (once a Void hour)
	var farm := get_node_or_null("/root/Farm")
	if farm == null or not farm.call("unlocked"):
		return 0
	var g := get_tree().current_scene.get_node_or_null("Garden") as Node3D
	if g == null or g.global_position.distance_to(at) > GARDEN_NEAR:
		return 0
	var now: float = farm.call("now")
	if now < _garden_at + 60.0:
		return 0
	farm.call("update")
	var n := 0
	for b in farm.get("beds"):
		var crop := str(b.crop)
		if crop == "" or float(b.grown) >= farm.call("grow_time", crop):
			continue
		b.grown = minf(float(b.grown) + GARDEN_BOOST, farm.call("grow_time", crop))
		b.water_until = maxf(float(b.water_until), now + 60.0)
		n += 1
	if n > 0:
		_garden_at = now
		farm.emit_signal("changed")
		Game.message("Your garden shoots up a whole hour's worth! Thanks, Heather.")
	return n


static func stalk_model(petal: Color) -> Node3D:
	# A giant springy blossom: a fat green stem with two leaves and a wide flat flower on top, solid all the way up so
	# it's somewhere to stand
	var s := StaticBody3D.new()
	s.name = "Bloomstalk"
	s.add_to_group("bloomstalk")
	s.set_meta("petal", petal)
	var stem_cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = HEIGHT
	stem_cs.shape = cyl
	stem_cs.position.y = HEIGHT / 2.0
	s.add_child(stem_cs)
	var cap_cs := CollisionShape3D.new()
	var cap := CylinderShape3D.new()
	cap.radius = CAP_R
	cap.height = 0.25
	cap_cs.shape = cap
	cap_cs.position.y = HEIGHT - 0.12
	s.add_child(cap_cs)
	var look := Node3D.new()
	look.name = "Look"
	s.add_child(look)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.35, 0.68, 0.3)
	green.roughness = 0.8
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.22
	sm.bottom_radius = 0.32
	sm.height = HEIGHT
	sm.radial_segments = 8
	stem.mesh = sm
	stem.material_override = green
	stem.position.y = HEIGHT / 2.0
	look.add_child(stem)
	for k in 2:
		var leaf := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.45
		lm.height = 0.2
		lm.radial_segments = 8
		lm.rings = 4
		leaf.mesh = lm
		leaf.material_override = green
		leaf.scale = Vector3(1.0, 1.0, 0.45)
		var side := -1.0 if k == 0 else 1.0
		leaf.position = Vector3(side * 0.45, 0.7 + k * 0.6, 0)
		leaf.rotation.z = side * -0.5
		look.add_child(leaf)
	var cap_node := Node3D.new()
	cap_node.name = "Cap"
	cap_node.position.y = HEIGHT
	look.add_child(cap_node)
	var pm := StandardMaterial3D.new()
	pm.resource_name = "Petal"
	pm.albedo_color = petal
	pm.roughness = 0.6
	pm.emission_enabled = true
	pm.emission = petal
	pm.emission_energy_multiplier = 0.15
	for k in 8:
		var p := MeshInstance3D.new()
		var pmesh := SphereMesh.new()
		pmesh.radius = 0.55
		pmesh.height = 0.22
		pmesh.radial_segments = 8
		pmesh.rings = 4
		p.mesh = pmesh
		p.material_override = pm
		var a := k * TAU / 8.0
		p.position = Vector3(cos(a), 0, sin(a)) * 0.75
		p.scale = Vector3(1.0, 1.0, 0.65)
		p.rotation.y = -a + PI / 2.0
		cap_node.add_child(p)
	var middle := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.45
	mm.height = 0.3
	mm.radial_segments = 10
	mm.rings = 5
	middle.mesh = mm
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.82, 0.3)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.75, 0.25)
	gold.emission_energy_multiplier = 0.3
	middle.material_override = gold
	middle.position.y = 0.06
	cap_node.add_child(middle)
	return s
