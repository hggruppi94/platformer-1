class_name JellyMine
extends Node3D

# A Jelly Mine (scripts/arsenal.gd): Shoot drops a wobbly dome of pink jelly on the ground just in front of her. An
# enemy that walks into it gets stuck (it stops, sinks in a little and wobbles about), and after a moment it pops
# (Arsenal.hit), and the jelly splats. A mine waits for 40 seconds, and only five can be out at once (the oldest
# melts). The Jelly Jamboree (V5) leaves two little jellies behind when one splats. A rolled-up Crocodillo rolls
# straight over it.
# Mods: Bounce makes a mine hop towards the nearest enemy every couple of seconds, Freeze leaves a frosty puff where it
# splats, and Split drops two smaller ones side by side (StarPopper.shoot).

const LIFE := 40.0
const MAX_OUT := 5
const HOP_EVERY := 2.0
const HOP_REACH := 8.0
const PINK := Color(0.95, 0.4, 0.55)

var radius := 1.6
var stick_time := 1.5
var leaves_two := false                   # the Jelly Jamboree
var shooter: Node3D
var stuck := {}                           # enemy -> seconds stuck (tests read it)
var popped := 0
var _life := LIFE
var _t := 0.0
var _hop := HOP_EVERY
var _dome: MeshInstance3D
var _mat: StandardMaterial3D
var _done := false


static func drop(parent: Node, at: Vector3, by: Node3D, stats: Dictionary) -> JellyMine:
	var out := parent.get_tree().get_nodes_in_group("jelly_mines")
	if out.size() >= MAX_OUT:
		(out[0] as JellyMine).melt()
	var j := JellyMine.new()
	j.shooter = by
	j.radius = float(stats.get("radius", 1.6))
	j.stick_time = float(stats.get("time", 1.5))
	j.leaves_two = bool(stats.get("leaves_two", false))
	j.set_meta("gadget", "jelly")
	parent.add_child(j)
	j.global_position = at
	Audio.play_at("jelly", at, -4.0, 0.15)
	return j


func _ready() -> void:
	name = "JellyMine"
	add_to_group("jelly_mines")
	_dome = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 1.0
	s.is_hemisphere = true
	_dome.mesh = s
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(PINK, 0.6)
	_mat.emission_enabled = true
	_mat.emission = PINK
	_mat.emission_energy_multiplier = 0.35
	_mat.rim_enabled = true
	_mat.roughness = 0.05
	_mat.metallic_specular = 1.0
	_dome.material_override = _mat
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dome)
	# A few bubbles and a gold star stuck in the jelly
	for k in 4:
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.06
		bs.height = 0.12
		b.mesh = bs
		b.material_override = StarBubble._flat(Color(1.0, 0.85, 0.9, 0.8))
		var a := TAU * k / 4.0 + 0.4
		b.position = Vector3(cos(a) * 0.45, 0.2 + 0.08 * k, sin(a) * 0.45)
		_dome.add_child(b)
	var star := MeshInstance3D.new()
	star.mesh = StarBubble.star_mesh()
	star.material_override = StarBubble._flat(Color(1.0, 0.82, 0.3))
	star.position = Vector3(0, 0.3, 0)
	star.scale = Vector3.ONE * 0.4
	_dome.add_child(star)
	_dome.scale = Vector3(0.1, 0.1, 0.1)
	create_tween().tween_property(_dome, "scale", _size(), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _size() -> Vector3:
	return Vector3(radius * 0.7, radius * 0.45, radius * 0.7)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_life -= delta
	if _life <= 0.0:
		melt()
		return
	if stuck.is_empty() and _dome.scale.x > radius * 0.6:
		var w := 1.0 + 0.05 * sin(_t * 6.0)
		_dome.scale = Vector3(radius * 0.7 * w, radius * 0.45 / w, radius * 0.7 * w)
	# Anyone walking in gets stuck
	for e in get_tree().get_nodes_in_group("enemies"):
		if stuck.has(e) or not e is Node3D or e.get("defeated") == true or e.is_in_group("bosses"):
			continue
		if e.has_method("shelled") and e.shelled():
			continue
		var n := e as Node3D
		var flat := Vector2(n.global_position.x - global_position.x, n.global_position.z - global_position.z).length()
		if flat < radius * 0.7 + 0.3 and absf(n.global_position.y - global_position.y) < 1.5:
			_stick(n)
	for e in stuck.keys():
		if not is_instance_valid(e):
			stuck.erase(e)
			continue
		stuck[e] = float(stuck[e]) + delta
		var v := (e as Node3D).get_node_or_null("Visual") as Node3D
		if v:
			var f: float = stuck[e]
			v.rotation.z = sin(f * 18.0) * 0.2
			v.scale = Vector3(1.0 + 0.1 * sin(f * 20.0), 1.0 - 0.1 * sin(f * 20.0), 1.0) \
				* float(e.get("size") if e.get("size") != null else 1.0)
		var wob := 1.0 + 0.15 * sin(_t * 16.0)
		_dome.scale = Vector3(radius * 0.7 * wob, radius * 0.45 / wob, radius * 0.7 * wob)
		if float(stuck[e]) >= stick_time:
			_pop_one(e)
	if _done:
		return
	if stuck.is_empty() and Arsenal.has_mod("jelly", "bounce"):
		_hop -= delta
		if _hop <= 0.0:
			_hop = HOP_EVERY
			_hop_to_enemy()


func _stick(e: Node3D) -> void:
	stuck[e] = 0.0
	e.set_physics_process(false)
	if e is CharacterBody3D:
		(e as CharacterBody3D).velocity = Vector3.ZERO
	Audio.play_at("jelly", e.global_position, -2.0, 0.2)
	Arsenal.add_xp("jelly")


func _pop_one(e: Node3D) -> void:
	var v := e.get_node_or_null("Visual") as Node3D
	var size := float(e.get("size") if e.get("size") != null else 1.0)
	if v:
		v.rotation.z = 0.0
		v.scale = Vector3.ONE * size
	stuck.erase(e)
	e.set_physics_process(true)
	Arsenal.hit(e, 99, Vector3.UP, "jelly")
	popped += 1
	splat()


func splat() -> void:
	# The jelly bursts in a pink splash (and the Jamboree leaves two little ones)
	if _done:
		return
	_done = true
	for e in stuck.keys():
		if is_instance_valid(e):
			(e as Node3D).set_physics_process(true)
	stuck = {}
	var parent := get_parent()
	Fx.burst(parent, global_position + Vector3(0, 0.3, 0), PINK, 20, 0.08, 4.0, -4.0, 0.7)
	Fx.burst(parent, global_position + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.9), 10, 0.05, 3.0, -2.0, 0.6)
	Audio.play_at("jelly", global_position, 0.0, 0.1)
	Arsenal.impact(global_position + Vector3(0, 0.3, 0), "jelly", parent)
	if leaves_two:
		for side in [-1, 1]:
			var at := global_position + Vector3(side * radius * 1.2, 0, 0.3)
			var j := JellyMine.drop(parent, at, shooter, {"radius": radius * 0.6, "time": stick_time, "leaves_two": false})
			j._life = LIFE * 0.5
	queue_free()


func melt() -> void:
	# Nobody came: it slumps away
	if _done:
		return
	_done = true
	for e in stuck.keys():
		if is_instance_valid(e):
			(e as Node3D).set_physics_process(true)
	stuck = {}
	var tw := create_tween()
	tw.tween_property(_dome, "scale", Vector3(radius, 0.02, radius), 0.4)
	tw.tween_callback(queue_free)


func _hop_to_enemy() -> void:
	# Bouncy jelly: a hop towards whoever's nearest
	var best: Node3D = null
	var best_d := HOP_REACH
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.get("defeated") != true:
			var d := (e as Node3D).global_position.distance_to(global_position)
			if d < best_d:
				best = e
				best_d = d
	if best == null:
		return
	var to := best.global_position - global_position
	to.y = 0.0
	var land := global_position + to.normalized() * minf(to.length(), 3.0)
	var q := PhysicsRayQueryParameters3D.create(land + Vector3(0, 3, 0), land + Vector3(0, -6, 0))
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and StarBubble._target(hit.collider as Node) == null:
		land = hit.position
	var start := global_position
	var tw := create_tween()
	tw.tween_method(func(f: float) -> void:
		global_position = start.lerp(land, f) + Vector3(0, sin(f * PI) * 1.2, 0), 0.0, 1.0, 0.4)
	Audio.play_at("boing", start, -8.0, 0.2)


static func build_prop() -> Node3D:
	# In her hand: a squeezy pink bottle with a jelly blob at its nozzle. Nozzle towards +Z.
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "jelly")
	var pink := StarPopper._mat(PINK, 0.3)
	var white := StarPopper._mat(Color(1.0, 0.92, 0.95), 0.5)
	var body := StarPopper._part(root, CapsuleMesh.new(), pink, Vector3(0, 0.03, 0.08), Vector3(PI / 2, 0, 0))
	(body.mesh as CapsuleMesh).radius = 0.07
	(body.mesh as CapsuleMesh).height = 0.24
	var nozzle := StarPopper._part(root, CylinderMesh.new(), white, Vector3(0, 0.03, 0.23), Vector3(PI / 2, 0, 0))
	(nozzle.mesh as CylinderMesh).top_radius = 0.02
	(nozzle.mesh as CylinderMesh).bottom_radius = 0.04
	(nozzle.mesh as CylinderMesh).height = 0.07
	var blob := StarPopper._part(root, SphereMesh.new(), StarPopper._glass(), Vector3(0, 0.03, 0.29), Vector3.ZERO)
	(blob.mesh as SphereMesh).radius = 0.035
	(blob.mesh as SphereMesh).height = 0.06
	(blob.material_override as StandardMaterial3D).albedo_color = Color(PINK, 0.6)
	var grip := StarPopper._part(root, BoxMesh.new(), StarPopper._mat(Color(0.62, 0.5, 0.95), 0.4),
		Vector3(0, -0.06, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	return root
