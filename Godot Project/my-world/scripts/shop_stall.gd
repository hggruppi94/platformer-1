extends Area3D

# A market stall Nina can shop at: walking up shows "Press F to shop" (the nearest spot gets the prompt, the same as
# people: scripts/dialogue.gd), and Interact opens the shop for this stall (scripts/shop.gd).

@export var stall := ""
@export var radius := 2.2

var _prompt: Label3D


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
	_prompt.position.y = 2.0
	add_child(_prompt)
	body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			Dialogue.enter_range(self))
	body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("player"):
			Dialogue.exit_range(self)
			set_prompt(false))
	set_prompt(false)


func _exit_tree() -> void:
	Dialogue.exit_range(self)


func set_prompt(on: bool) -> void:
	var what := "change clothes" if stall == "Wardrobe" else "shop"
	_prompt.text = "Press %s to %s" % [Settings.key_name("interact"), what]
	_prompt.visible = on


func use() -> void:
	Shop.open(stall)
