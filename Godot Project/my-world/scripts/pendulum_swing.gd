extends Node3D

# Swings to and fro like a clock's pendulum (the Town Hall's great clock). Gentler with reduce motion on.

@export var reach := 0.35                       # radians each way
@export var period := 2.0                        # seconds for a whole swing there and back

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation.z = sin(_t * TAU / period) * reach * (0.4 if Settings.reduce_motion else 1.0)
