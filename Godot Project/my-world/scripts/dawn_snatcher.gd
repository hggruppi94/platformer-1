extends "res://scripts/time_goblin_boss.gd"

# The Dawn Snatcher, Lanternmoor's boss (plan item 19a world 3, scripts/lanternmoor.gd): a big Time Goblin, Grandfather
# Tock's moody night-owl cousin, who caught the dawn and shut it in the clock he wears as a hat. That's why the sun
# won't rise. You can see it through his clock's glass, glowing gold. He fights like Tock (blinks back in time and
# undoes a hit, chimes rings to jump, whistles up goblins), but popping him doesn't count as popping Tock: he tells the
# world, which mends (Portals.clear) and lets the dawn out. Kid-safe like every goblin: bumps, and a bubble at the end.

const DAWN := Color(1.0, 0.72, 0.35)

var world: Node                               # Lanternmoor, told when he's popped


func _ready() -> void:
	title = "The Dawn Snatcher"
	short_title = "The Snatcher"
	bar_colour = Color(1.0, 0.7, 0.35)
	ring_colour = Color(1.0, 0.75, 0.4)
	super()
	_dawn_in_clock()


func _dawn_in_clock() -> void:
	# The caught dawn, glowing gold through the clock's window and face, with a warm light round him
	var glow := StandardMaterial3D.new()
	glow.albedo_color = DAWN
	glow.emission_enabled = true
	glow.emission = DAWN
	glow.emission_energy_multiplier = 3.0
	for n in ["Visual/Head/Clock/Window", "Visual/Head/Clock/Face"]:
		var m := get_node_or_null(n) as MeshInstance3D
		if m:
			m.material_override = glow
	var clock := get_node_or_null("Visual/Head/Clock") as Node3D
	if clock:
		var light := OmniLight3D.new()
		light.name = "Dawn Glow"
		light.light_color = DAWN
		light.light_energy = 1.6
		light.omni_range = 6.0
		light.position = Vector3(0, 0.4, 0.3)
		clock.add_child(light)


func _blinked() -> void:
	if hits > 0:
		hits -= 1
		Game.message("The Dawn Snatcher rewound his clock! Pop him while he's dizzy.")
	Fx.burst(get_parent(), global_position + Vector3(0, 1.6 * size, 0), DAWN, 18, 0.1, 3.0, 0.0, 0.7)


func _defeated() -> void:
	Game.message("You popped the Dawn Snatcher! His clock springs open, and something golden floats out...")
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	if world and world.has_method("mend"):
		world.mend()
