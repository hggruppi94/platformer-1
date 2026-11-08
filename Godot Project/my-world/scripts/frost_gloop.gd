extends "res://scripts/gloop_king.gd"

# The Frost Gloop, the Gloop King's icy cousin and the Frozen Moment's boss (plan item 23, scripts/frozen_moment.gd).
# The same goo as the King, but pale blue and frosted silver, with a crown of icicles. It's been sitting frozen on its
# throne hoarding the stopped moment, and wakes once the three frozen moments are thawed. It belly-flops like the King,
# but its ring is frost (jump it), it calls in little Snow Gloops, and popping it doesn't count as popping the King:
# it tells the world, which mends (Portals.clear). Kid-safe like every Gloop: a normal bump, no falling damage.

const FROST := Color(0.6, 0.85, 1.0)

var world: Node                               # the Frozen Moment, told when it's popped


func _ready() -> void:
	title = "Frost Gloop"
	ring_colour = FROST
	super()
	_frost(self)
	var crown := get_node_or_null("Visual/Body/Crown")
	if crown:
		_ice_crown(crown)


func _frost(n: Node) -> void:
	# Its goo, pale blue swirled with silver
	for m in _goo:
		m.set_shader_parameter("deep", Color(0.16, 0.3, 0.55))
		m.set_shader_parameter("green", Color(0.5, 0.75, 0.95))
		m.set_shader_parameter("gold", Color(0.9, 0.95, 1.0))
	var puddle := n.get_node_or_null("Puddle") as MeshInstance3D
	if puddle and puddle.material_override is StandardMaterial3D:
		var pm := (puddle.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		pm.albedo_color = Color(0.55, 0.75, 0.95, 0.5)
		puddle.material_override = pm


func _ice_crown(crown: Node) -> void:
	# The King's gold crown and gem turned to ice
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.8, 0.93, 1.0, 0.85)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.roughness = 0.05
	ice.emission_enabled = true
	ice.emission = Color(0.5, 0.8, 1.0)
	ice.emission_energy_multiplier = 0.6
	for c in crown.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = ice
	if crown is MeshInstance3D:
		(crown as MeshInstance3D).material_override = ice


func _call_court(count: int) -> void:
	var before := _court.size()
	super(count)
	for i in range(before, _court.size()):
		var g := _court[i] as Node
		if is_instance_valid(g):
			g.name = "Snow Gloop %d" % randi_range(100, 999)
			for m in g.get("_goo"):
				m.set_shader_parameter("deep", Color(0.25, 0.4, 0.6))
				m.set_shader_parameter("green", Color(0.75, 0.88, 1.0))
				m.set_shader_parameter("gold", Color(1, 1, 1))


func _hurt_message(stomped: bool) -> void:
	super(stomped)
	var left := stomps_to_defeat - hits
	Game.message("The Frost Gloop shivers! %d more to pop it." % left if left > 1 else "One more and the Frost Gloop pops!")


func _defeated() -> void:
	Game.message("You popped the Frost Gloop! The moment it was holding on to slips free...")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()
