extends Area3D

# A walk-through place (built by tools/build_town.gd): a cloud, the bubble bath, a hot spring pool. While Nina is
# inside it slows her (speed_scale), makes her floaty (gravity_scale, fall_cap), and sets her footsteps
# (scenes/player/player.gd reads these). It also puffs, bubbles or steams around her, with sounds to match:
#   cloud:  soft "fwump" going in, little puffs of cloud as she moves
#   bath:   a splash going in, bubbles bursting round her and popping, a bubbly gurgle while she's in
#   spring: steam puffs and bubbling; warms her up (+1 HP every heal_every seconds)

@export_enum("cloud", "bath", "spring") var kind := "cloud"
@export var speed_scale := 0.75
@export var gravity_scale := 0.6
@export var fall_cap := 6.0
@export var color := Color(1, 1, 1, 0.9)
@export var heal_every := 0.0

const FX_EVERY := 0.18                              # seconds between puffs while she moves
const ENTER_SOUND := {"cloud": "fwump", "bath": "splash", "spring": "splash"}
const LOOP_SOUND := {"bath": "bubbles", "spring": "steam"}
const LOOP_EVERY := {"bath": 1.3, "spring": 1.8}

var _player: CharacterBody3D
var _fx := 0.0
var _loop := 0.0
var _heal := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player = body as CharacterBody3D
	_player.call("enter_zone", self)
	_loop = 0.3
	_heal = heal_every
	Audio.play_at(ENTER_SOUND[kind], _feet(), -3.0)
	Fx.burst(get_parent(), _feet(), color, 16, 0.18 if kind == "cloud" else 0.1, 2.2, -2.0 if kind == "cloud" else -4.0)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player.call("exit_zone", self)
		_player = null


func _exit_tree() -> void:
	if _player and is_instance_valid(_player):
		_player.call("exit_zone", self)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var moving := Vector2(_player.velocity.x, _player.velocity.z).length() > 1.0
	_fx -= delta
	if moving and _fx <= 0.0:
		_fx = FX_EVERY
		match kind:
			"cloud":
				Fx.burst(get_parent(), _feet() + Vector3(0, 0.3, 0), color, 5, 0.22, 0.8, -0.5, 1.0)
			"bath":
				Fx.burst(get_parent(), _feet() + Vector3(0, 0.7, 0), color, 6, 0.09, 1.6, 1.2, 1.1, 50.0)
				if randf() < 0.5:
					Audio.play_at("pop", _feet() + Vector3(0, 0.8, 0), -8.0, 0.2)
			"spring":
				Fx.burst(get_parent(), _feet() + Vector3(0, 0.4, 0), color, 4, 0.25, 0.7, 1.0, 1.4, 30.0)
	if LOOP_SOUND.has(kind):
		_loop -= delta
		if _loop <= 0.0:
			_loop = LOOP_EVERY[kind]
			Audio.play_at(LOOP_SOUND[kind], _feet() + Vector3(0, 0.6, 0), -6.0, 0.1)
	if heal_every > 0.0 and Game.hp < Game.max_hp:
		_heal -= delta
		if _heal <= 0.0:
			_heal = heal_every
			Game.hp += 1
			Game.stats_changed.emit()


func _feet() -> Vector3:
	return _player.global_position - Vector3(0, 0.8, 0) if _player else global_position
