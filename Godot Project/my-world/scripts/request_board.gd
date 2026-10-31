extends Node3D

# The nightly request board in the Market Square (scripts/requests.gd places it and fills it). A lilac board on two
# posts under a little gold-trimmed roof, with a glowing star on top, tonight's three requests and how far along they
# are written on it (live, like the Skate Park's goals board), and a talk spot: Interact turns finished requests in.
# Built from shapes here, in the town's alien palette, so it needs no model. On Earth (scripts/earth_jobs.gd, "earthy")
# it's the town's notice board instead: old wood, cream cards pinned on cork, and a glowing jack-o'-lantern on top.

const WIDTH := 3.4
const HEIGHT := 2.3

var jobs: Node                    # the board it shows: Requests, or EarthJobs on Earth (set before it's added)
var earthy := false
var text: Label3D
var _star: Node3D
var _t := 0.0


func _ready() -> void:
	if jobs == null:
		jobs = Requests
	var wood := _mat(Color(0.45, 0.3, 0.2) if earthy else Color(0.36, 0.22, 0.42))
	var board := _mat(Color(0.62, 0.45, 0.3) if earthy else Color(0.22, 0.16, 0.34))
	var trim := _mat(Color(0.3, 0.2, 0.14), 0.0) if earthy else _mat(Color(1.0, 0.82, 0.35), 0.3)
	var roof := _mat(Color(0.35, 0.2, 0.18) if earthy else Color(0.62, 0.5, 0.95))
	for side in [-1, 1]:
		_box(Vector3(0.14, 3.3, 0.14), Vector3(side * (WIDTH / 2.0 + 0.05), 1.65, 0), wood)
	_box(Vector3(WIDTH, HEIGHT, 0.12), Vector3(0, 2.0, 0), board)
	_box(Vector3(WIDTH + 0.2, 0.08, 0.16), Vector3(0, 2.0 + HEIGHT / 2.0, 0.01), trim)
	_box(Vector3(WIDTH + 0.2, 0.08, 0.16), Vector3(0, 2.0 - HEIGHT / 2.0, 0.01), trim)
	var r := _box(Vector3(WIDTH + 0.6, 0.1, 0.9), Vector3(0, 3.4, 0.1), roof)
	r.rotation.x = 0.18
	# A star on top that spins and glows, so the board can be spotted from across the square (on Earth, a jack-o'-lantern)
	_star = Node3D.new()
	_star.position = Vector3(0, 3.95, 0.1)
	add_child(_star)
	if earthy:
		_lantern()
	var star_mat := _mat(Color(1.0, 0.85, 0.3), 2.5)
	for k in (0 if earthy else 5):
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.22, 0.32, 0.08)
		spike.mesh = prism
		spike.material_override = star_mat
		spike.rotation.z = TAU * k / 5.0
		spike.position = Vector3(sin(TAU * k / 5.0) * -0.16, cos(TAU * k / 5.0) * 0.16, 0)
		_star.add_child(spike)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.85, 0.5)
	glow.light_energy = 0.8
	glow.omni_range = 5.0
	glow.position = Vector3(0, 3.0, 1.0)
	add_child(glow)
	# A solid back, so nobody walks through it
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 3.3, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, 1.65, 0)
	body.add_child(cs)
	add_child(body)
	# The writing
	text = Label3D.new()
	text.name = "Requests"
	text.font_size = 36
	text.pixel_size = 0.0036
	text.outline_size = 8
	text.modulate = Color(0.2, 0.12, 0.08) if earthy else Color(1, 0.97, 0.88)
	text.outline_modulate = Color(1.0, 0.95, 0.82) if earthy else Color(0.12, 0.06, 0.2)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.position = Vector3(0, 2.0, 0.1 if earthy else 0.07)               # (in front of the notice board's cards)
	add_child(text)
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = "Request Talk"
	spot.set("verb", "read the notice board" if earthy else "see the requests")
	spot.set("jobs", jobs)
	spot.position = Vector3(0, 0, 1.4)
	add_child(spot)
	add_to_group("map_landmarks")
	jobs.changed.connect(_refresh)
	_refresh()


func _lantern() -> void:
	# Cream cards pinned in rows on the cork, behind the writing, and a jack-o'-lantern grinning on the roof
	var card := _mat(Color(1.0, 0.96, 0.85))
	for row in 3:
		var c := _box(Vector3(WIDTH - 0.4, 0.62, 0.02), Vector3(0, 2.72 - row * 0.72, 0.065), card)
		c.rotation.z = [0.012, -0.01, 0.008][row]
		_box(Vector3(0.07, 0.07, 0.04), Vector3(0, 3.0 - row * 0.72, 0.08), _mat(Color(0.85, 0.2, 0.2)))   # a pin
	var orange := _mat(Color(0.95, 0.5, 0.12), 0.6)
	var pumpkin := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.32
	ball.height = 0.5
	pumpkin.mesh = ball
	pumpkin.material_override = orange
	_star.add_child(pumpkin)
	var face := _mat(Color(1.0, 0.8, 0.3), 3.0)
	for sx in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.1, 0.09, 0.05)
		eye.mesh = p
		eye.material_override = face
		eye.position = Vector3(sx, 0.06, 0.29)
		_star.add_child(eye)
	var mouth := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.24, 0.05, 0.05)
	mouth.mesh = mb
	mouth.material_override = face
	mouth.position = Vector3(0, -0.08, 0.29)
	_star.add_child(mouth)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.05
	sm.height = 0.14
	stem.mesh = sm
	stem.material_override = _mat(Color(0.3, 0.45, 0.2))
	stem.position.y = 0.28
	_star.add_child(stem)


func map_name() -> String:
	return "Notice Board" if earthy else "Request Board"


func _process(delta: float) -> void:
	_t += delta
	_star.rotation.y = sin(_t * 0.8) * 0.5 if earthy else _t * 1.2      # (a pumpkin only looks round)
	if fmod(_t, 1.0) < delta:
		_refresh()                                            # "the board's asleep" turns into tonight's list by itself


func _refresh() -> void:
	text.text = jobs.board_text()


func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


static func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m
