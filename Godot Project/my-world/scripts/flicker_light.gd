extends OmniLight3D

# A light that buzzes and flickers now and then. Steady with "Reduce flashing" on.

var _base := 1.0
var _t := 0.0
var _next := 2.0


func _ready() -> void:
	_base = light_energy
	_t = randf() * 10.0
	_next = randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	if Settings.reduce_flashing:
		light_energy = _base
		return
	_t += delta
	_next -= delta
	var k := 0.92 + 0.08 * sin(_t * 31.0)            # constant faint buzz
	if _next < 0.0:
		k *= 0.15 if fmod(_t * 13.0, 1.0) < 0.5 else 1.0   # a burst of stutters
		if _next < -0.35:
			_next = randf_range(2.0, 7.0)
	light_energy = _base * k
