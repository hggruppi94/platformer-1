extends Node3D

# Dash's gadget stall at the edge of the Market Square (Arsenal places it): a little booth with a striped teal and pink
# awning, a sign, and his gadgets out on the counter (the Star Popper, a Fizz Flinger bottle and a spinning mirror
# ball). Interact opens the shop for the "Gadget" stall (scripts/shop_stall.gd, shop/items.json): new gadgets, and
# refills for the ones she has. Built from shapes here, in the town's alien palette, so it needs no model.

const WIDTH := 3.0

var _ball: Node3D
var _t := 0.0


func _ready() -> void:
	var wood := StarPopper._mat(Color(0.36, 0.22, 0.42), 0.7)
	var top := StarPopper._mat(Color(0.62, 0.5, 0.95), 0.5)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.3, 0.5)
	var stripes := [StarPopper._mat(Color(0.3, 0.9, 0.82), 0.6), StarPopper._mat(Color(1.0, 0.5, 0.78), 0.6)]
	# The counter, with a gold edge
	_box(Vector3(WIDTH, 1.0, 0.8), Vector3(0, 0.5, 0), wood)
	_box(Vector3(WIDTH + 0.1, 0.08, 0.9), Vector3(0, 1.04, 0), top)
	_box(Vector3(WIDTH + 0.12, 0.05, 0.05), Vector3(0, 1.0, 0.45), gold)
	# Posts and a striped awning
	for side in [-1, 1]:
		_box(Vector3(0.1, 2.6, 0.1), Vector3(side * (WIDTH / 2.0 - 0.05), 1.3, -0.35), wood)
		_box(Vector3(0.1, 2.6, 0.1), Vector3(side * (WIDTH / 2.0 - 0.05), 1.3, 0.35), wood)
	var n := 8
	for i in n:
		var strip := _box(Vector3(WIDTH / n + 0.01, 0.06, 1.3), Vector3(-WIDTH / 2.0 + (i + 0.5) * WIDTH / n, 2.65, 0.15),
			stripes[i % 2])
		strip.rotation.x = 0.22
	for i in n:                                  # a scalloped edge hanging off the front
		var flap := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = WIDTH / n / 2.0
		cyl.bottom_radius = WIDTH / n / 2.0
		cyl.height = 0.04
		flap.mesh = cyl
		flap.material_override = stripes[i % 2]
		flap.position = Vector3(-WIDTH / 2.0 + (i + 0.5) * WIDTH / n, 2.48, 0.8)
		flap.rotation.x = PI / 2
		add_child(flap)
	# The sign
	var board := _box(Vector3(2.2, 0.5, 0.06), Vector3(0, 3.1, 0.3), StarPopper._mat(Color(0.22, 0.16, 0.34), 0.6))
	board.rotation.x = -0.1
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "DASH'S GADGETS"
	sign.font_size = 48
	sign.pixel_size = 0.008
	sign.outline_size = 10
	sign.modulate = Color(1.0, 0.85, 0.35)
	sign.outline_modulate = Color(0.15, 0.08, 0.2)
	sign.position = Vector3(0, 3.1, 0.34)
	sign.rotation.x = -0.1
	add_child(sign)
	# His gadgets out on the counter
	var popper := StarPopper.build_prop()
	popper.position = Vector3(-0.8, 1.2, 0.1)
	popper.rotation.y = 0.6
	popper.scale = Vector3.ONE * 1.4
	add_child(popper)
	var bottle := FizzBomb.build_bottle()
	bottle.position = Vector3(0.0, 1.25, 0.1)
	bottle.scale = Vector3.ONE * 1.4
	add_child(bottle)
	_ball = DiscoBall.build_ball(0.2)
	_ball.position = Vector3(0.85, 2.15, 0.25)
	add_child(_ball)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.9)
	glow.light_energy = 0.7
	glow.omni_range = 4.5
	glow.position = Vector3(0, 2.0, 1.0)
	add_child(glow)
	# A solid counter, so nobody walks through it
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 1.1, 0.8)
	cs.shape = shape
	cs.position = Vector3(0, 0.55, 0)
	body.add_child(cs)
	add_child(body)
	# Where she stands to shop: in front of the counter
	var spot := (load("res://scripts/shop_stall.gd") as GDScript).new() as Area3D
	spot.name = "Gadget Shop Spot"
	spot.set("stall", "Gadget")
	spot.position = Vector3(0, 0, 1.4)
	add_child(spot)


func _process(delta: float) -> void:
	_t += delta
	_ball.rotation.y = _t * 1.2


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
