extends Node3D

# A shy little Peeper hiding in every portal world (overnight polish, 15 Nov 2026: "more juice and secrets in each
# portal world"; a first draft for Hayden): a round puffball in the world's colour with big eyes, tucked in beside the
# world's Remnant vein (every portal world has one "Vein" marker, so it's always somewhere you can walk to). It ducks
# down when you come near, peeks back up, and if you walk right up to it, it squeaks, spins and gives 3 sparkles, once
# (flag "peeper_<world>"). After that it hops and waves whenever you're close. Nothing to read. No class_name on
# purpose (tools compile class_name scripts before the autoloads exist): preload it.

const SPARKLES := 3
const SHY := 6.0                    # it ducks when you're this close...
const FOUND := 1.5                  # ...and is found when you're this close
const OUT := 2.4                    # how far from the vein it hides

var world_id := ""
var colour := Color(1, 0.8, 1)
var _player: Node3D
var _body: Node3D
var _t := 0.0
var _hop := 0.0
var _duck := 0.0


static func place(world: Node3D, vein: Node3D, id: String, col: Color) -> Node3D:
	# Finds a spot round the vein with floor under it and nothing in the way, and puts a Peeper there
	var space := world.get_world_3d().direct_space_state
	var base := vein.global_position
	var down := PhysicsRayQueryParameters3D.create(base + Vector3(0, 3, 0), base + Vector3(0, -6, 0))
	var floor_hit := space.intersect_ray(down)
	var floor_y: float = floor_hit.position.y if floor_hit else base.y
	for k in 12:
		var a := TAU * k / 12.0 + 0.4
		var at := base + Vector3(cos(a), 0, sin(a)) * OUT
		var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 2.5, 0), at + Vector3(0, -4, 0))
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(hit.position.y - floor_y) > 1.0 or hit.normal.y < 0.8:
			continue
		if hit.collider is Area3D or (hit.collider as Node).is_in_group("water"):
			continue
		var shape := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.35
		shape.shape = s
		shape.transform = Transform3D(Basis(), hit.position + Vector3(0, 0.5, 0))
		if not space.intersect_shape(shape, 1).is_empty():
			continue
		var p := (load("res://scripts/peeper.gd") as GDScript).new() as Node3D
		p.name = "Peeper"
		p.set("world_id", id)
		p.set("colour", col)
		world.add_child(p)
		p.global_position = hit.position
		return p
	return null


func found_flag() -> String:
	return "peeper_" + world_id


func is_found() -> bool:
	return Dialogue.flags.get(found_flag(), false)


func _ready() -> void:
	add_to_group("peepers")
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var fluff := _mat(colour, 0.35)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.44
	ball.mesh = sm
	ball.material_override = fluff
	ball.position.y = 0.24
	_body.add_child(ball)
	for k in 5:                                    # a little tuft on top
		var tuft := MeshInstance3D.new()
		var tm := SphereMesh.new()
		tm.radius = 0.06
		tm.height = 0.12
		tuft.mesh = tm
		tuft.material_override = fluff
		var a := TAU * k / 5.0
		tuft.position = Vector3(cos(a) * 0.06, 0.48, sin(a) * 0.06)
		_body.add_child(tuft)
	var white := _mat(Color(1, 1, 1))
	var black := _mat(Color(0.05, 0.03, 0.1))
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.08
		em.height = 0.16
		eye.mesh = em
		eye.material_override = white
		eye.position = Vector3(sx * 0.09, 0.3, 0.18)
		eye.name = "Eye"
		_body.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = 0.045
		pm.height = 0.09
		pupil.mesh = pm
		pupil.material_override = black
		pupil.position = Vector3(0, 0, 0.05)
		eye.add_child(pupil)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 0.6
	glow.omni_range = 2.0
	glow.position.y = 0.4
	add_child(glow)


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var to := _player.global_position - global_position
	var flat := Vector2(to.x, to.z).length()
	if flat > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), minf(1.0, 4.0 * delta))
	if not is_found() and flat < FOUND and absf(to.y) < 2.0:
		found()
	# Shy until found: it ducks down as you come near, and peeks up again now and then
	var want_duck := 0.0
	if not is_found() and flat < SHY:
		want_duck = 0.0 if fmod(_t, 2.4) < 0.5 else 0.75
	_duck = move_toward(_duck, want_duck, delta * 3.0)
	# Found, it hops when you're close
	if is_found() and flat < SHY and _hop <= 0.0 and fmod(_t, 1.6) < delta:
		_hop = 0.4
	var y := 0.0
	if _hop > 0.0:
		_hop -= delta
		y = sin((0.4 - _hop) / 0.4 * PI) * 0.35
	var breathe := 1.0 + 0.04 * sin(_t * 3.0)
	_body.position.y = y - _duck * 0.3
	_body.scale = Vector3(breathe, (1.0 - _duck * 0.5) / breathe, breathe)


func found() -> bool:
	if is_found():
		return false
	Dialogue.flags[found_flag()] = true
	_hop = 0.4
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", rotation.y + TAU, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.burst(get_parent(), global_position + Vector3(0, 0.5, 0), colour, 16, 0.07, 2.5, -2.0, 0.8)
		Juice.blip("chime", 1.6, -6.0)
	if not Portals.practice:
		Game.add_sparkles(SPARKLES, "a shy Peeper")
	return true


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m
