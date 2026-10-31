extends Node3D

# The Autumn Festival on Earth's town green (scripts/festival.gd puts this up on Saturday evenings and takes it down at
# 10 PM). Everything's built from shapes, round the gazebo in the gaps between the green's ring of trees, each facing
# the gazebo: Poppy's treats stall, the pie contest table, the apple barrel, Miss Marigold's lantern stall and Gus's
# cider cart, with hay bales to sit on, a banner over the path in, and strings of paper lanterns from the gazebo's
# roof out over the stalls. The hayride's little tractor (a friendly scarecrow drives it) pulls a hay wagon round the
# street that rings the green, stopping by the Maple Inn; hop on for a lap. At 9 PM a sky full of paper lanterns
# floats up from the green.

const STALL_R := 9.6                # how far out the stalls stand (the trees are at 11.5)
# Each spot: what's there, and its angle round the gazebo (degrees, the gaps between the trees; 90 is due south). The
# people who run them stand beside them, at the festival's own points in routines/earth_places.json (tools/build_earth.gd
# FESTIVAL has the same angles).
const SPOTS := {"treats": 314.6, "pies": 278.6, "apples": 350.6, "lanterns": 242.6, "cider": 206.6, "hay": 62.6}
const WAGON_SPEED := 3.5
const WAGON_WAIT := 8.0             # seconds at the stop between laps
const LOOP_HALF := 21.0             # the street round the green (tools/build_earth.gd STREET)
const LOOP_CORNER := 3.0
const STOP := Vector2(21.0, 12.0)   # where the tractor waits, by the Maple Inn, facing north
const LANTERN_COUNT := 56

var wagon: Node3D
var tractor: Node3D
var riding := false
var lanterns_released := false

var _loop: PackedVector3Array
var _loop_d: PackedFloat32Array
var _d := 0.0                       # how far round the loop the tractor is
var _wait := WAGON_WAIT
var _player: CharacterBody3D
var _lanterns: Array[Node3D] = []
var _mats := {}


func _ready() -> void:
	_make_loop()
	for what in SPOTS:
		var a := deg_to_rad(float(SPOTS[what]))
		var at := Vector3(cos(a), 0, sin(a)) * STALL_R
		var node := Node3D.new()
		node.name = what.capitalize()
		add_child(node)
		node.position = at + Vector3(0, EarthLand.height(at.x, at.z), 0)
		node.rotation.y = atan2(-at.x, -at.z)                    # its front (+Z) to the gazebo
		match what:
			"treats":
				_stall(node, "Festival Treats", [Color(0.95, 0.5, 0.15), Color(1.0, 0.95, 0.85)], "Festival Treats")
				_treats(node)
			"cider":
				_stall(node, "Cider Cart", [Color(0.55, 0.25, 0.15), Color(0.95, 0.8, 0.45)], "Gus's Cider Cart")
				for k in 3:
					_barrel(node, Vector3(-0.8 + k * 0.8, 1.0, -0.05), 0.22, 0.4)
			"lanterns":
				_stall(node, "", [Color(0.45, 0.25, 0.6), Color(0.95, 0.75, 0.3)], "Lanterns for Nine O'Clock")
				_talk_spot(node, "Lantern Stall", "get a lantern", Vector3(0, 0, 1.3))
				for k in 7:
					_paper_lantern(node, Vector3(-1.1 + k * 0.37, 2.15 - (k % 2) * 0.15, 0.2), k)
			"pies":
				_pie_table(node)
			"apples":
				_apple_barrel(node)
			"hay":
				_hay_seats(node)
	_banner()
	_strings()
	_hayride()


func _process(delta: float) -> void:
	for l in _lanterns:
		var v: Vector3 = l.get_meta("v")
		l.position += v * delta
		l.position.x += sin(l.position.y * 0.35 + float(l.get_meta("phase"))) * delta * 0.4
	if not lanterns_released and Festival.lanterns_up():
		release_lanterns(Clock.earth_minutes > Festival.LANTERNS + 3.0)


func _physics_process(delta: float) -> void:
	_drive(delta)


# -----------------------------------------------------------------------------
# The hayride
# -----------------------------------------------------------------------------
func _make_loop() -> void:
	# The street round the green as a rounded square, a point every half metre, starting at the stop going north
	var pts: Array[Vector3] = []
	var h := LOOP_HALF
	var c := h - LOOP_CORNER
	var corners := [Vector2(c, -c), Vector2(-c, -c), Vector2(-c, c), Vector2(c, c)]
	var starts := [0.0, -PI / 2, PI, PI / 2]                 # the angle round each corner where its arc starts
	pts.append(Vector3(STOP.x, 0, STOP.y))
	var z := STOP.y
	while z > -c:
		z -= 0.5
		pts.append(Vector3(h, 0, z))
	for k in 4:
		for s in 13:
			var a: float = starts[k] - s * (PI / 2) / 12.0
			pts.append(Vector3(corners[k].x + cos(a) * LOOP_CORNER, 0, corners[k].y + sin(a) * LOOP_CORNER))
		var from: Vector3 = pts[pts.size() - 1]
		var to: Vector2 = [Vector2(-c, -h), Vector2(-h, c), Vector2(c, h), Vector2(h, STOP.y)][k]
		var steps := int(Vector2(from.x, from.z).distance_to(to) / 0.5)
		for s in steps:
			var p := Vector2(from.x, from.z).lerp(to, (s + 1.0) / steps)
			pts.append(Vector3(p.x, 0, p.y))
	_loop = PackedVector3Array(pts)
	_loop_d.resize(pts.size())
	var d := 0.0
	for i in pts.size():
		if i > 0:
			d += pts[i].distance_to(pts[i - 1])
		_loop_d[i] = d


func loop_length() -> float:
	return _loop_d[_loop_d.size() - 1]


func point_at(d: float) -> Vector3:
	d = fposmod(d, loop_length())
	var i := _loop_d.bsearch(d)
	i = clampi(i, 1, _loop.size() - 1)
	var t := inverse_lerp(_loop_d[i - 1], _loop_d[i], d)
	var p := _loop[i - 1].lerp(_loop[i], t)
	p.y = EarthLand.height(p.x, p.z)
	return p


func _drive(delta: float) -> void:
	if wagon == null:
		return
	if _wait > 0.0:
		_wait -= delta
	else:
		_d += WAGON_SPEED * delta
		if _d >= loop_length():
			_d = 0.0
			_wait = WAGON_WAIT
			if riding:
				hop_off(true)
	_place_on_loop(tractor, _d)
	_place_on_loop(wagon, _d - 4.2)
	if riding and is_instance_valid(_player):
		_player.global_position = wagon.global_transform * Vector3(0, 1.0, -0.6)
		var visual := _player.get_node_or_null("Visual") as Node3D
		if visual:
			visual.global_rotation.y = wagon.global_rotation.y + PI / 2       # sitting sideways, looking out
	var wheel_turn := WAGON_SPEED * delta / 0.45 if _wait <= 0.0 else 0.0
	for w in get_tree().get_nodes_in_group("hayride_wheels"):
		(w as Node3D).rotate_object_local(Vector3.UP, wheel_turn)


func _place_on_loop(n: Node3D, d: float) -> void:
	var p := point_at(d)
	var ahead := point_at(d + 0.8)
	n.position = p
	n.rotation.y = atan2(ahead.x - p.x, ahead.z - p.z)


func is_waiting() -> bool:
	return _wait > 0.0


func hop_on() -> void:
	if riding:
		return
	if Game.riding:
		Game.message("Hop off your board to ride the hayride!")
		return
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return
	riding = true
	_player.set("carried", true)
	_player.set("input_locked", true)
	_player.velocity = Vector3.ZERO
	var anim := _player.get("anim") as AnimationPlayer
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	Audio.play("rustle", -2.0)
	Game.message("All aboard the hayride! (%s to hop off.)" % Settings.prompt("jump"))


func hop_off(lap_done := false) -> void:
	if not riding:
		return
	riding = false
	if is_instance_valid(_player):
		_player.global_position = wagon.global_transform * Vector3(2.2, 0.3, 0)
		_player.set("carried", false)
		_player.velocity = Vector3.ZERO
		var p := _player
		get_tree().create_timer(0.25).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.set("input_locked", false))
	if lap_done:
		Festival.hayrides += 1
		Game.message("Round the whole green! Scarecrow Sam tips his hat to you.")


func _unhandled_input(event: InputEvent) -> void:
	if riding and (event.is_action_pressed("jump") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		hop_off()


func _exit_tree() -> void:
	hop_off()


func _hayride() -> void:
	tractor = Node3D.new()
	tractor.name = "Tractor"
	add_child(tractor)
	var red := _mat(Color(0.8, 0.18, 0.15), 0.4)
	var black := _mat(Color(0.12, 0.12, 0.13))
	var hub := _mat(Color(0.95, 0.8, 0.3))
	_box(tractor, Vector3(1.1, 0.7, 1.8), Vector3(0, 0.95, 0.3), red)               # the bonnet and body
	_box(tractor, Vector3(1.0, 0.9, 0.7), Vector3(0, 1.55, -0.55), red)             # the seat's back
	_cyl(tractor, 0.06, 0.06, 0.6, Vector3(0.25, 1.6, 0.9), black)                   # the chimney
	for side in [-1, 1]:
		_wheel(tractor, Vector3(side * 0.75, 0.6, -0.6), 0.6, 0.35, black, hub)
		_wheel(tractor, Vector3(side * 0.62, 0.36, 0.95), 0.36, 0.25, black, hub)
	_scarecrow_driver(tractor, Vector3(0, 1.3, -0.35))
	wagon = Node3D.new()
	wagon.name = "Hay Wagon"
	add_child(wagon)
	var wood := _mat(Color(0.55, 0.36, 0.2))
	var hay := _mat(Color(0.9, 0.76, 0.38))
	_box(wagon, Vector3(2.0, 0.15, 3.4), Vector3(0, 0.75, 0), wood)
	for side in [-1, 1]:
		_box(wagon, Vector3(0.08, 0.5, 3.4), Vector3(side * 1.0, 1.05, 0), wood)
		_wheel(wagon, Vector3(side * 1.05, 0.42, 1.1), 0.42, 0.18, black, hub)
		_wheel(wagon, Vector3(side * 1.05, 0.42, -1.1), 0.42, 0.18, black, hub)
	_box(wagon, Vector3(0.1, 0.1, 1.6), Vector3(0, 0.6, 2.4), wood)                  # the hitch
	for p in [Vector3(-0.45, 1.05, -0.6), Vector3(0.45, 1.05, -0.6), Vector3(0, 1.05, 0.7), Vector3(-0.5, 1.05, 1.2)]:
		_box(wagon, Vector3(0.8, 0.5, 1.0), p, hay)
	for p in [Vector3(0.6, 0.83, 1.35), Vector3(-0.65, 0.83, -1.4)]:
		_pumpkin(wagon, p, 0.22)
	var sign_node := Label3D.new()
	sign_node.text = "HAYRIDE"
	sign_node.font_size = 48
	sign_node.pixel_size = 0.006
	sign_node.outline_size = 10
	sign_node.modulate = Color(1.0, 0.85, 0.4)
	sign_node.outline_modulate = Color(0.25, 0.12, 0.05)
	sign_node.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign_node.position = Vector3(0, 2.0, -1.7)
	wagon.add_child(sign_node)
	_talk_spot(wagon, "Hayride", "ride the hayride", Vector3(0, 0, 0), 2.8)
	_place_on_loop(tractor, 0.0)
	_place_on_loop(wagon, -4.2)


func _wheel(parent: Node3D, at: Vector3, r: float, w: float, tyre: Material, hub: Material) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.z = PI / 2
	holder.add_to_group("hayride_wheels")
	parent.add_child(holder)
	_cyl(holder, r, r, w, Vector3.ZERO, tyre)
	_cyl(holder, r * 0.45, r * 0.45, w + 0.02, Vector3.ZERO, hub)


func _scarecrow_driver(parent: Node3D, at: Vector3) -> void:
	# Scarecrow Sam: a sack head with a stitched smile, a straw hat, a plaid shirt and straw at his cuffs
	var shirt := _mat(Color(0.75, 0.2, 0.2))
	var sack := _mat(Color(0.85, 0.75, 0.55))
	var straw := _mat(Color(0.92, 0.8, 0.4))
	_box(parent, Vector3(0.5, 0.55, 0.3), at + Vector3(0, 0.3, 0), shirt)
	_ball(parent, 0.2, at + Vector3(0, 0.78, 0), sack)
	_cyl(parent, 0.34, 0.34, 0.03, at + Vector3(0, 0.95, 0), straw)
	_cyl(parent, 0.13, 0.17, 0.18, at + Vector3(0, 1.04, 0), straw)
	for sx in [-0.07, 0.07]:
		_ball(parent, 0.03, at + Vector3(sx, 0.82, 0.18), _mat(Color(0.1, 0.08, 0.06)))
	_box(parent, Vector3(0.18, 0.02, 0.02), at + Vector3(0, 0.71, 0.19), _mat(Color(0.1, 0.08, 0.06)))
	for sx in [-1, 1]:
		_box(parent, Vector3(0.12, 0.12, 0.45), at + Vector3(sx * 0.3, 0.35, 0.2), shirt)             # arms to the wheel
		_ball(parent, 0.06, at + Vector3(sx * 0.3, 0.35, 0.44), straw)
	_cyl(parent, 0.2, 0.2, 0.04, at + Vector3(0, 0.45, 0.6), _mat(Color(0.12, 0.12, 0.13)))       # the steering wheel


# -----------------------------------------------------------------------------
# Lanterns at nine
# -----------------------------------------------------------------------------
func release_lanterns(already_up := false) -> void:
	# Up they go from all round the green (already high in the sky if the player arrives after nine)
	if lanterns_released:
		return
	lanterns_released = true
	var rng := RandomNumberGenerator.new()
	rng.seed = Clock.earth_day()
	var cols := [Color(1.0, 0.65, 0.25), Color(1.0, 0.85, 0.5), Color(0.95, 0.5, 0.2), Color(0.85, 0.55, 0.95)]
	for k in LANTERN_COUNT:
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.5, 14.0)
		var l := Node3D.new()
		l.name = "Sky Lantern %d" % k
		add_child(l)
		l.position = Vector3(cos(a) * r, rng.randf_range(1.6, 3.0) + (rng.randf_range(15.0, 45.0) if already_up else 0.0), sin(a) * r)
		l.set_meta("v", Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.55, 1.0), rng.randf_range(-0.15, 0.15)))
		l.set_meta("phase", rng.randf() * TAU)
		_cyl(l, 0.2, 0.15, 0.4, Vector3.ZERO, _mat(cols[k % cols.size()], 0.0, 2.4))
		if k % 7 == 0:
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.7, 0.35)
			glow.light_energy = 1.2
			glow.omni_range = 6.0
			l.add_child(glow)
		_lanterns.append(l)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not already_up and player and Vector2(player.global_position.x, player.global_position.z).length() < 40.0:
		Festival.let_lanterns_go()


func lantern_count() -> int:
	return _lanterns.size()


# -----------------------------------------------------------------------------
# The stalls and the rest
# -----------------------------------------------------------------------------
func _stall(node: Node3D, shop_stall: String, stripes: Array, sign_text: String) -> void:
	# A counter under a striped awning on four posts, with a sign; a shop spot in front if it sells things
	var wood := _mat(Color(0.5, 0.33, 0.2))
	_solid(node, Vector3(2.6, 1.0, 0.8), Vector3(0, 0.5, 0), _mat(Color(0.62, 0.42, 0.26)))
	for sx in [-1.25, 1.25]:
		for sz in [-0.35, 0.35]:
			_box(node, Vector3(0.1, 2.6, 0.1), Vector3(sx, 1.3, sz), wood)
	for k in 7:
		_box(node, Vector3(0.4, 0.08, 1.3), Vector3(-1.2 + k * 0.4, 2.65, 0.15), _mat(stripes[k % 2]))
	var l := Label3D.new()
	l.text = sign_text
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.8)
	l.outline_modulate = Color(0.25, 0.12, 0.05)
	l.position = Vector3(0, 2.95, 0.5)
	node.add_child(l)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.45)
	light.light_energy = 1.0
	light.omni_range = 4.5
	light.position = Vector3(0, 2.3, 0.9)
	node.add_child(light)
	if shop_stall != "":
		var spot := (load("res://scripts/shop_stall.gd") as GDScript).new() as Area3D
		spot.name = "Shop " + shop_stall
		spot.set("stall", shop_stall)
		spot.position = Vector3(0, 0, 1.3)
		node.add_child(spot)


func _talk_spot(parent: Node3D, spot_name: String, verb: String, at: Vector3, radius := 2.4) -> Area3D:
	var spot := (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	spot.name = spot_name
	spot.set("verb", verb)
	spot.set("radius", radius)
	spot.set("jobs", Festival)
	spot.position = at
	parent.add_child(spot)
	return spot


func _treats(node: Node3D) -> void:
	# Caramel apples on sticks, a bowl of kettle corn and a heap of cider donuts on the counter
	for k in 4:
		var p := Vector3(-1.0 + k * 0.25, 1.12, 0.15)
		_ball(node, 0.08, p, _mat(Color(0.75, 0.42, 0.15)))
		_cyl(node, 0.01, 0.01, 0.18, p + Vector3(0, 0.12, 0), _mat(Color(0.9, 0.85, 0.7)))
	_cyl(node, 0.22, 0.15, 0.14, Vector3(0.2, 1.07, 0.1), _mat(Color(0.85, 0.3, 0.25)))
	_ball(node, 0.2, Vector3(0.2, 1.13, 0.1), _mat(Color(1.0, 0.95, 0.8))).scale = Vector3(1, 0.5, 1)
	for k in 5:
		var d := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.03
		t.outer_radius = 0.08
		d.mesh = t
		d.material_override = _mat(Color(0.8, 0.55, 0.3))
		d.position = Vector3(0.75 + (k % 3) * 0.16, 1.03 + (k / 3) * 0.05, 0.1)
		node.add_child(d)


func _pie_table(node: Node3D) -> void:
	# A long table with a white cloth, pies in a row, ribbons waiting, and a banner on two poles behind
	_solid(node, Vector3(3.4, 0.85, 0.9), Vector3(0, 0.425, 0), _mat(Color(0.97, 0.96, 0.93)))
	var fillings := [Color(0.85, 0.42, 0.12), Color(0.95, 0.85, 0.35), Color(0.55, 0.15, 0.25), Color(0.85, 0.42, 0.12), Color(0.7, 0.5, 0.3)]
	for k in 5:
		var p := Vector3(-1.3 + k * 0.65, 0.9, 0.05)
		_cyl(node, 0.24, 0.2, 0.08, p, _mat(Color(0.85, 0.6, 0.3)))
		_cyl(node, 0.2, 0.2, 0.02, p + Vector3(0, 0.045, 0), _mat(fillings[k]))
	for k in 3:
		var c: Color = [Color(0.2, 0.35, 0.9), Color(0.85, 0.15, 0.15), Color(0.95, 0.8, 0.2)][k]
		_cyl(node, 0.09, 0.09, 0.02, Vector3(-0.4 + k * 0.4, 0.87, 0.38), _mat(c))
	var wood := _mat(Color(0.5, 0.33, 0.2))
	for sx in [-1.6, 1.6]:
		_box(node, Vector3(0.1, 2.8, 0.1), Vector3(sx, 1.4, -0.55), wood)
	_box(node, Vector3(3.3, 0.6, 0.05), Vector3(0, 2.45, -0.55), _mat(Color(0.95, 0.55, 0.15)))
	var l := Label3D.new()
	l.text = "PIE CONTEST"
	l.font_size = 52
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Color(1.0, 0.97, 0.88)
	l.outline_modulate = Color(0.45, 0.2, 0.05)
	l.position = Vector3(0, 2.45, -0.51)
	node.add_child(l)


func _apple_barrel(node: Node3D) -> void:
	# A big wooden barrel of water with apples bobbing in it, and a basket of towels
	_barrel(node, Vector3(0, 0.0, 0), 0.6, 0.95, true)
	_cyl(node, 0.55, 0.55, 0.02, Vector3(0, 0.88, 0), _mat(Color(0.3, 0.55, 0.75), 0.0, 0.3))
	for k in 6:
		var a := k * TAU / 6.0
		var apple := _ball(node, 0.09, Vector3(cos(a) * 0.32, 0.9, sin(a) * 0.32), _mat(Color(0.85, 0.12, 0.12) if k % 3 else
			Color(0.6, 0.8, 0.2)))
		apple.name = "Apple %d" % k
	_cyl(node, 0.32, 0.26, 0.3, Vector3(1.0, 0.15, 0.2), _mat(Color(0.7, 0.55, 0.3)))
	_box(node, Vector3(0.4, 0.1, 0.3), Vector3(1.0, 0.33, 0.2), _mat(Color(0.95, 0.95, 1.0)))
	var l := Label3D.new()
	l.text = "Bob for Apples!"
	l.font_size = 40
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = Color(1.0, 0.95, 0.8)
	l.outline_modulate = Color(0.45, 0.1, 0.05)
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.position = Vector3(0, 1.8, 0)
	node.add_child(l)
	_talk_spot(node, "Apple Barrel", "bob for apples", Vector3(0, 0, 1.0))


func _barrel(node: Node3D, at: Vector3, r: float, h: float, solid := false) -> void:
	var wood := _mat(Color(0.55, 0.35, 0.2))
	var band := _mat(Color(0.25, 0.22, 0.2), 0.0, 0.0, 0.6)
	_cyl(node, r, r * 0.92, h, at + Vector3(0, h / 2.0, 0), wood)
	for y in [0.2, 0.8]:
		_cyl(node, r + 0.015, r + 0.015, 0.05, at + Vector3(0, h * y, 0), band)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r
		shape.height = h
		cs.shape = shape
		cs.position = at + Vector3(0, h / 2.0, 0)
		body.add_child(cs)
		node.add_child(body)


func _hay_seats(node: Node3D) -> void:
	var hay := _mat(Color(0.9, 0.76, 0.38))
	for p in [Vector3(-1.4, 0.3, 0), Vector3(0, 0.3, -0.4), Vector3(1.4, 0.3, 0)]:
		_solid(node, Vector3(1.2, 0.6, 0.7), p, hay)
	_pumpkin(node, Vector3(0, 0.6, -0.4), 0.25)
	_pumpkin(node, Vector3(1.9, 0.0, 0.5), 0.3)


func _banner() -> void:
	# Over the path from the street to the gazebo's steps
	var wood := _mat(Color(0.5, 0.33, 0.2))
	var y := EarthLand.height(0, 13)
	for sx in [-2.8, 2.8]:
		_box(self, Vector3(0.14, 4.2, 0.14), Vector3(sx, y + 2.1, 13.0), wood)
		_pumpkin(self, Vector3(sx, y, 13.6), 0.32)
	_box(self, Vector3(5.6, 0.8, 0.06), Vector3(0, y + 3.7, 13.0), _mat(Color(0.45, 0.2, 0.55)))
	for side in [1, -1]:
		var l := Label3D.new()
		l.text = "AUTUMN FESTIVAL"
		l.font_size = 64
		l.pixel_size = 0.007
		l.outline_size = 12
		l.modulate = Color(1.0, 0.75, 0.3)
		l.outline_modulate = Color(0.2, 0.05, 0.25)
		l.position = Vector3(0, y + 3.7, 13.0 + side * 0.04)
		l.rotation.y = 0.0 if side > 0 else PI
		add_child(l)


func _strings() -> void:
	# Paper lanterns strung from the gazebo's roof out over each stall to a pole behind it
	var wood := _mat(Color(0.45, 0.3, 0.2))
	var cols := [Color(1.0, 0.6, 0.2), Color(0.8, 0.5, 1.0), Color(1.0, 0.9, 0.6)]
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.1
	mesh.bottom_radius = 0.12
	mesh.height = 0.22
	var k := 0
	for what in SPOTS:
		var a := deg_to_rad(float(SPOTS[what]))
		var dir := Vector3(cos(a), 0, sin(a))
		var pole := dir * 13.2
		var y := EarthLand.height(pole.x, pole.z)
		_box(self, Vector3(0.12, 4.6, 0.12), pole + Vector3(0, y + 2.3, 0), wood)
		var from := dir * 4.6 + Vector3(0, 3.5, 0)
		var to := pole + Vector3(0, y + 4.5, 0)
		for i in 11:
			var t := (i + 1) / 12.0
			var p := from.lerp(to, t) + Vector3(0, -sin(t * PI) * 0.7, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _mat(cols[(i + k) % 3], 0.0, 1.8)
			mi.position = p
			add_child(mi)
		k += 1


func _paper_lantern(node: Node3D, at: Vector3, k: int) -> void:
	_cyl(node, 0.1, 0.12, 0.22, at, _mat([Color(1.0, 0.6, 0.2), Color(0.8, 0.5, 1.0), Color(1.0, 0.9, 0.6)][k % 3], 0.0, 1.8))


func _pumpkin(parent: Node3D, at: Vector3, r: float) -> void:
	_ball(parent, r, at + Vector3(0, r * 0.7, 0), _mat(Color(0.95, 0.5, 0.12))).scale = Vector3(1.15, 0.8, 1.15)
	_cyl(parent, 0.03, 0.04, 0.14, at + Vector3(0, r * 1.4, 0), _mat(Color(0.3, 0.45, 0.2)))


# --- Shapes --------------------------------------------------------------------
func _mat(c: Color, rough := 0.0, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [c, glow, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75 if rough == 0.0 else rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	_box(parent, size, at, m)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = at
	body.add_child(cs)
	parent.add_child(body)


func _cyl(parent: Node3D, top: float, bottom: float, h: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 14
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi
