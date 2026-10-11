extends Node3D

# Moves each child fish on its own lazy loop. With radius > 0 they circle the center (round tanks); otherwise they
# drift back and forth inside a box of half_size (wall tanks). Fish face the way they swim.

@export var radius := 0.0
@export var half_size := Vector3(0.5, 0.8, 1.2)

var t := 0.0
var phases: Array[float] = []


func _ready() -> void:
	for i in get_child_count():
		phases.append(i * 1.37)


func _process(delta: float) -> void:
	t += delta
	for i in get_child_count():
		var f := get_child(i) as Node3D
		var p := phases[i]
		var speed := 0.5 + 0.1 * (i % 3)
		var prev := f.position
		if radius > 0.0:
			var a := t * speed + p
			var rr := radius * (0.6 + 0.4 * sin(p * 3.0))
			f.position = Vector3(cos(a) * rr, sin(t * 0.7 + p) * half_size.y, sin(a) * rr)
		else:
			f.position = Vector3(sin(t * 0.6 + p) * half_size.x, sin(t * 0.9 + p * 2.0) * half_size.y,
				sin(t * speed + p) * half_size.z)
		var dir := f.position - prev
		if dir.length() > 0.0001:
			f.look_at(f.global_position + global_transform.basis * dir, Vector3.UP, true)
