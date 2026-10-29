class_name WatchPickup
extends Node3D

# One lost watch where it fell (scripts/watches.gd puts them in): it glows, spins and bobs, with a soft light round
# it so it can be spotted from a way off. Come close enough and it's yours. The ones high in the sky ("sky") can only
# be reached in the mothership, so those are picked up by flying the ship through them.

const SIZE := 2.2                         # the models are about 0.3 m: this makes them easy to see

var id := ""
var sky := false
var _model: Node3D
var _t := 0.0
var _player: Node3D


func _ready() -> void:
	_t = randf() * TAU
	_model = Watches.model(id)
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	var halo := MeshInstance3D.new()                   # a soft golden glow behind it
	var ball := SphereMesh.new()
	ball.radius = 0.42
	ball.height = 0.84
	halo.mesh = ball
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.85, 0.4, 0.18)
	hm.emission_enabled = true
	hm.emission = Color(1.0, 0.85, 0.4)
	hm.emission_energy_multiplier = 1.5
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.name = "Halo"
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.2
	light.omni_range = 4.0 if not sky else 14.0
	add_child(light)
	if sky:                                            # big enough to spot from the cockpit
		_model.scale *= 4.0
		halo.scale = Vector3.ONE * 4.0


func _process(delta: float) -> void:
	_t += delta
	_model.rotation.y = _t * 1.6
	_model.position.y = sin(_t * 2.0) * 0.1
	Watches.animate(_model, _t)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
	if _reached():
		Watches.pick_up(id, global_position)
		queue_free()


func _reached() -> bool:
	if sky:
		for ship in get_tree().get_nodes_in_group("mothership"):
			if ship.get("pilot") != null and (ship as Node3D).global_position.distance_to(global_position) < Watches.SKY_RADIUS:
				return true
		return false
	return _player.global_position.distance_to(global_position) < Watches.PICK_RADIUS
