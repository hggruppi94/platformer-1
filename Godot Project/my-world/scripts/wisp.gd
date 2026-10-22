extends Node3D

# Spooky-but-friendly bits of the Scary World: a glowing wisp that bobs and drifts, or (blink = true) a pair of eyes
# in the dark that blink now and then. Up close, the eyes are just glow-bugs.

@export var blink := false
@export var drift := 0.6

var _t := 0.0
var _home := Vector3.ZERO
var _next_blink := 0.0


func _ready() -> void:
	_t = randf() * TAU
	_home = position
	_next_blink = randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	_t += delta
	if blink:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_next_blink = randf_range(2.5, 6.0)
		scale.y = 0.1 if _next_blink < 0.15 else 1.0
	else:
		position = _home + Vector3(sin(_t * 0.7) * drift, sin(_t * 1.3) * 0.25, cos(_t * 0.5) * drift)
