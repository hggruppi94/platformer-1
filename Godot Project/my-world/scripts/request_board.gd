extends Node3D

# The nightly request board in the Market Square (scripts/requests.gd places it and fills it). A lilac board on two
# posts under a little gold-trimmed roof, with a glowing star on top, tonight's three requests and how far along they
# are written on it (live, like the Skate Park's goals board), and a talk spot: Interact turns finished requests in.
# Built from shapes here, in the town's alien palette, so it needs no model.

const WIDTH := 3.4
const HEIGHT := 2.3

var text: Label3D
var _star: Node3D
var _t := 0.0


func _ready() -> void:
	var wood := _mat(Color(0.36, 0.22, 0.42))
	var board := _mat(Color(0.22, 0.16, 0.34))
	var trim := _mat(Color(1.0, 0.82, 0.35), 0.3)
	var roof := _mat(Color(0.62, 0.5, 0.95))
	for side in [-1, 1]:
		_box(Vector3(0.14, 3.3, 0.14), Vector3(side * (WIDTH / 2.0 + 0.05), 1.65, 0), wood)
	_box(Vector3(WIDTH, HEIGHT, 0.12), Vector3(0, 2.0, 0), board)
	_box(Vector3(WIDTH + 0.2, 0.08, 0.16), Vector3(0, 2.0 + HEIGHT / 2.0, 0.01), trim)
	_box(Vector3(WIDTH + 0.2, 0.08, 0.16), Vector3(0, 2.0 - HEIGHT / 2.0, 0.01), trim)
	var r := _box(Vector3(WIDTH + 0.6, 0.1, 0.9), Vector3(0, 3.4, 0.1), roof)
	r.rotation.x = 0.18
	# A star on top that spins and glows, so the board can be spotted from across the square
	_star = Node3D.new()
	_star.position = Vector3(0, 3.95, 0.1)
	add_child(_star)
	var star_mat := _mat(Color(1.0, 0.85, 0.3), 2.5)
	for k in 5:
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
	text.modulate = Color(1, 0.97, 0.88)
	text.outline_modulate = Color(0.12, 0.06, 0.2)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.position = Vector3(0, 2.0, 0.07)
	add_child(text)
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = "Request Talk"
	spot.set("verb", "see the requests")
	spot.position = Vector3(0, 0, 1.4)
	add_child(spot)
	add_to_group("map_landmarks")
	Requests.changed.connect(_refresh)
	_refresh()


func map_name() -> String:
	return "Request Board"


func _process(delta: float) -> void:
	_t += delta
	_star.rotation.y = _t * 1.2
	if fmod(_t, 1.0) < delta:
		_refresh()                                            # "the board's asleep" turns into tonight's list by itself


func _refresh() -> void:
	text.text = Requests.board_text()


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
