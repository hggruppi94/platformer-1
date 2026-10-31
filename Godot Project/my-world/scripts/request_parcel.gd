extends Area3D

# A parcel waiting outside a building on Earth for a delivery request (scripts/requests.gd places it while a request
# wants it): a little present in the alien palette with a gold ribbon, bobbing and glowing so it's easy to spot.
# Walking into it picks it up for the friend it's for.

var item_id := ""
var jobs: Node                    # whose delivery it's for: Requests, or EarthJobs (scripts/earth_jobs.gd)
var _look: Node3D
var _t := 0.0


func _ready() -> void:
	monitorable = false
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	cs.shape = sphere
	cs.position.y = 0.6
	add_child(cs)
	_look = Node3D.new()
	add_child(_look)
	_box(Vector3(0.5, 0.4, 0.5), Vector3(0, 0.6, 0), Color(0.62, 0.5, 0.95), 0.4)
	_box(Vector3(0.52, 0.42, 0.1), Vector3(0, 0.6, 0), Color(1.0, 0.82, 0.35), 0.6)
	_box(Vector3(0.1, 0.42, 0.52), Vector3(0, 0.6, 0), Color(1.0, 0.82, 0.35), 0.6)
	_box(Vector3(0.2, 0.1, 0.2), Vector3(0, 0.85, 0), Color(1.0, 0.82, 0.35), 0.6)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.75, 1.0)
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position.y = 1.0
	add_child(light)
	body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			(jobs if jobs else Requests).pick_up(item_id)
			queue_free())


func settle() -> void:
	# Onto the ground under where it was put
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 10.0, global_position + Vector3.DOWN * 20.0)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position


func _process(delta: float) -> void:
	_t += delta
	_look.position.y = sin(_t * 2.0) * 0.1
	_look.rotation.y = _t * 0.8


func _box(size: Vector3, at: Vector3, c: Color, glow: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = glow
	mi.material_override = m
	mi.position = at
	_look.add_child(mi)
