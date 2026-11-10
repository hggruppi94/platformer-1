extends Node3D

# A cluster of cave crystals (made by scripts/cave_kit.gd crystals()). They sleep dim in the dark, and the first time
# Pip's glow reaches them (scripts/pip_glow.gd calls glow_wake() on anything in group "glow_wake") they wake: they
# brighten with a little chime and a sparkle, and keep shining with a light of their own, so the caves you've been
# through stay lit behind you.

@export var colour := Color(0.6, 0.75, 1.0)
var awake := false
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("glow_wake")
	_light = OmniLight3D.new()
	_light.name = "Crystal Light"
	_light.light_color = colour
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.position = Vector3(0, 0.8, 0)
	add_child(_light)


func glow_wake() -> void:
	if awake:
		return
	awake = true
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 1.3, 0.8)
	var lit: StandardMaterial3D = null
	for c in get_children():
		var mi := c as MeshInstance3D
		if mi and mi.material_override is StandardMaterial3D:
			if lit == null:                                     # one shared copy for the whole cluster
				lit = (mi.material_override as StandardMaterial3D).duplicate()
				tw.parallel().tween_property(lit, "emission_energy_multiplier", 2.2, 0.8)
			mi.material_override = lit
	# (the autoloads by path: tools run with --script compile this before they exist)
	var fx := get_node_or_null("/root/Fx")
	if fx:
		fx.burst(get_parent(), global_position + Vector3(0, 0.8, 0), colour, 12, 0.06, 2.0, 0.0, 0.6)
	var juice := get_node_or_null("/root/Juice")
	if juice:
		juice.blip("chime", 1.4, -12.0)
