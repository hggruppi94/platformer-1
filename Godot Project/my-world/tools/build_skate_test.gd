extends SceneTree

# Builds res://scenes/skate/test_park.tscn: a small practice park for trying out the skating (scenes/player/skate.gd).
# A halfpipe, a big quarter pipe, a kicker, a funbox with ledges, flat rails, a ledge, and a platform with stairs and a
# handrail going down, on a big flat lavender slab under the green Galaxity sky. The pieces come from
# tools/skate_kit.gd (the town's Skate Park uses the same ones). Logic: scripts/skate_test_park.gd.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/build_skate_test.gd
#
# Play it from the editor (open the scene, F6) or straight from the command line:
#   godot --path "Godot Project/my-world" res://scenes/skate/test_park.tscn

const OUT := "res://scenes/skate/test_park.tscn"
const HALF := 45.0                                # the slab is 90 m across; a low wall round the edge

var world: Node3D
var kit := SkateKit.new()
var mats := {}


func _initialize() -> void:
	world = Node3D.new()
	world.name = "SkateTestPark"
	world.set_script(load("res://scripts/skate_test_park.gd"))
	_environment()
	_ground()
	# The halfpipe: two quarter pipes facing each other across a 6 m flat bottom, east of the start
	kit.quarter_pipe(world, "Halfpipe East", Vector3(27, 0, -6), PI / 2, 12.0, 3.4, 78.0)
	kit.quarter_pipe(world, "Halfpipe West", Vector3(21, 0, -6), -PI / 2, 12.0, 3.4, 78.0)
	# One big quarter pipe across the north end
	kit.quarter_pipe(world, "North Quarter", Vector3(-4, 0, -30), PI, 26.0, 4.0, 78.0)
	# A low quarter pipe to learn on, in the west
	kit.quarter_pipe(world, "Little Quarter", Vector3(-33, 0, 8), -PI / 2, 10.0, 2.2, 65.0)
	kit.kicker(world, "Kicker", Vector3(-14, 0, 4), PI, 3.0, 1.1, 4.0)
	kit.funbox(world, "Funbox", Vector3(0, 0, -8))
	kit.flat_rail(world, "Flat Rail", Vector3(-9, 0, 16), Vector3(1, 0, 0), 10.0, 0.5)
	kit.flat_rail(world, "Long Rail", Vector3(10, 0, 2), Vector3(0, 0, 1), 14.0, 0.6)
	kit.ledge(world, "Ledge", Vector3(-20, 0, -12), Vector3(0, 0, 1), 10.0, 0.5)
	kit.stairs_and_handrail(world, "Stair Set", Vector3(-24, 0, 24))
	_signs()
	var start := Marker3D.new()
	start.name = "Start"
	start.position = Vector3(0, 1.0, 30)
	world.add_child(start)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	player.position = start.position
	world.add_child(player)
	_own(world)
	var scene := PackedScene.new()
	print("SAVED ", OUT, " pack=", scene.pack(world), " save=", ResourceSaver.save(scene, OUT))
	quit()


func _own(n: Node) -> void:
	for c in n.get_children():
		c.owner = world
		if c.scene_file_path == "":
			_own(c)


func mat(name: String, color: Color, rough := 0.7) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = color
	m.roughness = rough
	mats[name] = m
	return m


func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.2, 0.6, 0.3)               # the same green midday sky as the town
	sky_mat.sky_horizon_color = Color(0.86, 0.93, 0.6)
	sky_mat.ground_horizon_color = Color(0.86, 0.93, 0.6)
	sky_mat.ground_bottom_color = Color(0.1, 0.04, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.75, 0.68, 0.95)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-55, -35, 0)
	world.add_child(sun)


func _ground() -> void:
	var g := kit.group(world, "Ground", Vector3.ZERO)
	kit.box_at(Vector3(HALF * 2, 1.0, HALF * 2), mat("Slab", Color(0.78, 0.74, 0.88), 0.85), Vector3(0, -0.5, 0), g)
	# Painted lines on the slab, just for looks
	var paint := mat("Paint", Color(0.98, 0.55, 0.85), 0.6)
	for k in 5:
		kit.box_at(Vector3(0.25, 0.01, HALF * 2 - 4), paint, Vector3(-36 + k * 18, 0.005, 0), g, false)
	# A low wall round the edge so she can't roll off the world
	var wall := mat("Wall", Color(0.55, 0.45, 0.75), 0.8)
	for side in [-1, 1]:
		kit.box_at(Vector3(HALF * 2, 1.2, 0.6), wall, Vector3(0, 0.6, side * HALF), g)
		kit.box_at(Vector3(0.6, 1.2, HALF * 2), wall, Vector3(side * HALF, 0.6, 0), g)


func _signs() -> void:
	var s := Label3D.new()
	s.name = "Welcome"
	s.text = "Practice Park\nHold Jump to crouch, let go to ollie\nGrind near rails and ledges\nLeft and right to spin in the air"
	s.font_size = 64
	s.pixel_size = 0.006
	s.outline_size = 14
	s.modulate = Color(1.0, 0.95, 0.75)
	s.position = Vector3(8, 2.6, 25)                    # beside the start, turned toward it
	s.rotation.y = atan2(-8.0, 5.0)
	world.add_child(s)
