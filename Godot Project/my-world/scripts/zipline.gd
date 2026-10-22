extends Area3D

# A zipline (the tree house's, built by tools/build_town.gd). Stand by the handle at the top and press Interact:
# Nina grabs the handle and rides the cable down to the landing post, speeding up as she goes, then lets go and
# drops to the ground. The cable runs from the ZipTop marker to the ZipEnd marker next to this area.

@export var top_path: NodePath = ^"../ZipTop"
@export var end_path: NodePath = ^"../ZipEnd"
@export var handle_path: NodePath = ^"../ZiplineHandle"
@export var top_speed := 12.0                       # metres a second along the cable
@export var accel := 6.0
@export var hang := 1.25                            # her middle hangs this far below the cable (hands on the handle)

var _near := false
var _riding := false
var _player: CharacterBody3D
var _dist := 0.0
var _speed := 0.0
var _whir := 0.0
@onready var _top: Node3D = get_node(top_path)
@onready var _end: Node3D = get_node(end_path)
@onready var _handle: Node3D = get_node_or_null(handle_path)
@onready var _handle_home := _handle.position if _handle else Vector3.ZERO
@onready var _prompt: Label3D = $Prompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.visible = false


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = true
		_prompt.text = "Press %s to ride the zipline" % Settings.key_name("interact")
		_prompt.visible = not _riding


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _near and not _riding and not get_tree().paused and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		ride(get_tree().get_first_node_in_group("player") as CharacterBody3D)


func is_riding() -> bool:
	return _riding


func ride(player: CharacterBody3D) -> void:
	if player == null or _riding:
		return
	_player = player
	_riding = true
	_dist = 0.0
	_speed = 2.0
	_whir = 0.0
	_prompt.visible = false
	_player.set("carried", true)
	_player.set("input_locked", true)
	_player.velocity = Vector3.ZERO
	var anim := _player.get("anim") as AnimationPlayer
	if anim and anim.has_animation("fall"):
		anim.play("fall")
	Audio.play("zipline")


func _physics_process(delta: float) -> void:
	if not _riding:
		return
	var a := _top.global_position
	var b := _end.global_position
	var length := a.distance_to(b)
	var dir := (b - a) / length
	_speed = minf(_speed + accel * delta, top_speed)
	_dist += _speed * delta
	var on_cable := a + dir * minf(_dist, length)
	_player.global_position = on_cable - Vector3(0, hang, 0)
	var visual := _player.get_node_or_null("Visual") as Node3D
	if visual:
		visual.rotation.y = atan2(dir.x, dir.z)        # models face +Z: face down the line
	if _handle:
		_handle.global_position = on_cable - Vector3(0, 0.4, 0)
	_whir -= delta
	if _whir <= 0.0:                                   # the cable keeps whirring as she goes
		_whir = 0.5
		Audio.play_at("zipline", on_cable, -6.0)
	if _dist >= length - 0.3:
		_let_go(dir)


func _let_go(dir: Vector3) -> void:
	# Off at the bottom: drop to the ground with a bit of the ride's speed still in her
	_riding = false
	_player.set("carried", false)
	_player.velocity = Vector3(dir.x, 0, dir.z).normalized() * 3.0 + Vector3.UP * 1.5
	get_tree().create_timer(0.3).timeout.connect(func() -> void:
		if is_instance_valid(_player):
			_player.set("input_locked", false))
	Audio.play("land")
	# The handle slides back up to the top for next time
	if _handle:
		var tw := create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(_handle, "position", _handle_home, 2.5).set_trans(Tween.TRANS_SINE)
