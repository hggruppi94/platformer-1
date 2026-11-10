extends Node3D

# A lantern stone in the Agent of Chaos's "Lights Out" section (scripts/chaos_trials.gd): dark until Pip's glow reaches
# it (group "glow_wake", woken by scripts/pip_glow.gd), then its lamp blazes gold and stays lit.

var awake := false


func glow_wake() -> void:
	if awake:
		return
	awake = true
	var lamp := get_node_or_null("Lamp") as MeshInstance3D
	if lamp:
		var m := lamp.material_override as StandardMaterial3D
		if m:
			m.albedo_color = Color(1.0, 0.86, 0.62)
			m.emission = Color(1.0, 0.8, 0.45)
			m.emission_energy_multiplier = 4.0
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.position.y = 1.7
	add_child(light)
	Fx.burst(get_parent(), global_position + Vector3(0, 1.7, 0), Color(1.0, 0.86, 0.62), 16, 0.08, 2.5, -1.0, 0.8)
	Juice.blip("chime", 1.2, -4.0)
	Game.message("A lantern stone blazes into light!")
