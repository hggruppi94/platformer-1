extends Area3D

# A spot the player can walk up to and use with Interact, made in code by a system that looks after it: a garden bed
# (scripts/farm.gd), a Remnant vein or a part for Bramble's harvesting tool (scripts/remnants.gd). It works like a
# quest spot (scripts/quest_spot.gd): the nearest one in reach gets the "Press F to ..." prompt (Dialogue.enter_range),
# and Interact calls use(). What it says and does come from the system, as two Callables:
#   offer: () -> String   what to show after "Press F to " right now, or "" when there's nothing to do here
#   act:   () -> void     what using it does
# It also answers begin_talk() / end_talk(), so the system can open a little conversation from it with Dialogue.say().
# (No class_name: tools run with --script compile class_name scripts before the autoloads exist, and this one uses
# Dialogue. Make one with make() below.)

var offer: Callable
var act: Callable
var radius := 2.0
var prompt_height := 1.6

var _prompt: Label3D
var _inside := false
var _offered := false


static func make(where: Vector3, offer_: Callable, act_: Callable, radius_ := 2.0, height := 1.6) -> Area3D:
	var s = (load("res://scripts/use_spot.gd") as GDScript).new()
	s.position = where
	s.offer = offer_
	s.act = act_
	s.radius = radius_
	s.prompt_height = height
	return s


func _ready() -> void:
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	shape.position.y = 1.0
	add_child(shape)
	_prompt = Label3D.new()
	_prompt.font_size = 20
	_prompt.pixel_size = 0.01
	_prompt.outline_size = 10
	_prompt.modulate = Color(1, 0.95, 0.7)
	_prompt.outline_modulate = Color(0.15, 0.08, 0.2)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.position.y = prompt_height
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_inside = true)
	body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			_inside = false)


func _exit_tree() -> void:
	Dialogue.exit_range(self)


func what() -> String:
	return str(offer.call()) if offer.is_valid() else ""


func _process(_delta: float) -> void:
	var now := _inside and what() != ""
	if now != _offered:
		_offered = now
		if now:
			Dialogue.enter_range(self)
		else:
			Dialogue.exit_range(self)
			set_prompt(false)
	elif now and _prompt.visible:
		set_prompt(true)                        # (what it offers can change while she stands there: "Water it", "Harvest it")


func set_prompt(on: bool) -> void:
	_prompt.text = "Press %s to %s" % [Settings.prompt("interact"), what()]
	_prompt.visible = on


func use() -> void:
	if what() != "" and act.is_valid():
		act.call()


func begin_talk() -> void:
	pass


func end_talk() -> void:
	pass
