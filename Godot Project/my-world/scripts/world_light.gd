extends Node

# World Light (23 Nov 2026, Hayden: "it may be time to start looking into more advanced shading and lighting vfx").
# A "World Light" node that WorldDetail puts in every place as it loads. It gives the place's own Environment and sun
# the newer lighting Godot's Forward+ renderer has, at the level Settings.lighting asks for, and takes it all back off
# if the player picks "Simple":
#   - SSAO (screen-space ambient occlusion): soft contact shadows where things meet: under benches, in corners, round
#     every builder box sitting on the ground. Nice and Best.
#   - Volumetric fog: a thin haze in the air the sun and every lamp light up, so low sun makes shafts of light through
#     trees and buildings, and lamps, torches and crystals glow in the air at night. Its colour follows the place's own
#     fog colour every moment (day_night.gd, earth_world.gd and the portal worlds change that), and it's kept off the
#     sky so the dream skies look as they did. Nice and Best.
#   - SSIL (screen-space indirect light): bright things bounce a little of their colour onto what's near them. Best.
#   - Soft sun shadows (the sun's angular size: shadows sharp at the foot, blurring further out) and a finer haze. Best.
#
# Before building we read open-source Godot work (Hayden's rule):
#   - godotengine/tps-demo (MIT): graphics presets the player picks, each switching the Environment's SSAO, SSIL,
#     glow, volumetric fog and GI on or off at run time from one settings autoload. We do the same.
#   - RPicster/godot4-demo-desert-light (code MIT): volumetric fog plus GI for light shafts; its fog takes its colour
#     from the sky. Our haze follows each place's own fog colour.
#   - lucasbecker-dev/godot-smart-graphics-settings (MIT): presets from Ultra Low to Ultra, cheapest effects kept on
#     longest. SSAO stays on at Nice; the costlier SSIL and soft shadows only at Best.
#   - Left out on purpose: SDFGI and VoxelGI. SDFGI re-lights the whole place from its shapes (so every builder's tuned
#     ambient light would change) and costs the most of all; VoxelGI has to fit a box round the place, and the Void
#     and Stars Hollow are hundreds of metres across. LightmapGI needs baking, and our places are built when they load.
#
# Nothing here changes what anything else sets each frame (ambient light, fog colour and density, the sun's energy
# and whether it casts shadows): only effects that were off before. Each Environment remembers what it had
# (meta "world_light_base"), so "Simple" is exactly the old look.

const LEVELS := ["simple", "nice", "best"]

# How thick the haze is (volumetric fog density per metre). Rooms get less, so they don't look smoky.
const HAZE := {"nice": 0.022, "best": 0.026}
const HAZE_INSIDE := 0.008
const HAZE_LENGTH := 96.0              # metres of haze in front of the camera; the old depth fog takes over past it
const HAZE_SHAFTS := 0.72              # forward scattering: looking towards the sun, the haze glows and shafts show
const HAZE_AMBIENT := 0.35             # how much the sky's light fills the haze in the shade
const SUN_SOFTNESS := 0.55             # the sun's angular size in degrees at Best (soft shadows further out)
const SUN_HAZE := 1.4                  # how strongly the sun lights the haze (shafts)
const LAMP_HAZE := 4.0                 # and every lamp, torch and glowing thing with a light: a halo round it at night
const LAMP_LOOKS := [0.0, 1.0, 3.0, 6.0]   # seconds after it's placed to look for lights put in late (rooms, props)
const FOLLOW := 0.2                    # seconds between looks at the place's current Environment

# Environment settings we touch, so they can be put back exactly
const ENV_KEYS := ["ssao_enabled", "ssao_radius", "ssao_intensity", "ssao_power", "ssao_detail", "ssao_horizon",
	"ssao_light_affect", "ssil_enabled", "ssil_radius", "ssil_intensity", "volumetric_fog_enabled",
	"volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_length", "volumetric_fog_anisotropy",
	"volumetric_fog_ambient_inject", "volumetric_fog_sky_affect", "volumetric_fog_detail_spread",
	"volumetric_fog_temporal_reprojection_enabled"]
const SUN_KEYS := ["light_angular_distance", "light_volumetric_fog_energy", "shadow_blur"]

var level := "nice"
var inside := false                    # a room (scenes/interiors, the school): a lighter haze
var _env: Environment
var _wait := 0.0
var _age := 0.0
var _looks := 0


static func place(scene: Node) -> Node:
	# Puts the World Light in a place (once); WorldDetail calls it for every place it dresses
	var old := scene.get_node_or_null("World Light")
	if old:
		return old
	var n := Node.new()
	n.name = "World Light"
	n.set_script(load("res://scripts/world_light.gd"))
	var path := scene.scene_file_path
	n.set("inside", path.begins_with("res://scenes/interiors/") or path == "res://scenes/school/school.tscn")
	scene.add_child(n)
	return n


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level = _wanted()
	quality_for(level)
	var s := get_node_or_null("/root/Settings")
	if s:
		s.changed.connect(_on_settings)
	_follow()


func _exit_tree() -> void:
	# A scene's Environment is a shared resource Godot keeps loaded, so leave it as the place had it: the next visit
	# dresses it again (or not, if WorldDetail.lighting is off)
	if _env and _env.has_meta("world_light_base"):
		var base: Dictionary = _env.get_meta("world_light_base")
		for k in base:
			_env.set(k, base[k])


func _wanted() -> String:
	var s := get_node_or_null("/root/Settings")
	var want: String = str(s.get("lighting")) if s and s.get("lighting") != null else "nice"
	return want if want in LEVELS else "nice"


func _on_settings() -> void:
	var want := _wanted()
	if want != level:
		set_level(want)


func set_level(want: String) -> void:
	level = want if want in LEVELS else "nice"
	quality_for(level)
	if _env:
		_apply(_env)
	_apply_sun()
	_apply_lamps()


func _process(delta: float) -> void:
	_age += delta
	if _looks < LAMP_LOOKS.size() and _age >= LAMP_LOOKS[_looks]:
		_looks += 1
		_apply_lamps()
	_wait -= delta
	if _wait <= 0.0:
		_wait = FOLLOW
		_follow()


func _follow() -> void:
	# The place's Environment can be swapped at any time (the portal worlds copy theirs, the skies replace theirs), so
	# keep looking for whichever one is live and dress it once
	var w := get_viewport().find_world_3d() if is_inside_tree() else null
	var env: Environment = w.environment if w else null
	if env != _env:
		_env = env
		if env:
			_apply(env)
			_apply_sun()
	if _env and _env.volumetric_fog_enabled and level != "simple":
		# The haze takes the place's fog colour as it changes through the day
		_env.volumetric_fog_albedo = haze_colour(_env.fog_light_color)


static func haze_colour(fog: Color) -> Color:
	# The fog's hue, but always pale: the haze's colour is how much light it scatters, not how bright it is, so a dark
	# night fog colour would hide the lamps' glow. At night it's dark anyway, since only the lamps light it.
	return Color.from_hsv(fog.h, fog.s * 0.6, maxf(fog.v, 0.85))


func current_env() -> Environment:
	return _env


func _apply(env: Environment) -> void:
	if not env.has_meta("world_light_base"):
		var base := {}
		for k in ENV_KEYS:
			base[k] = env.get(k)
		env.set_meta("world_light_base", base)
	var base: Dictionary = env.get_meta("world_light_base")
	for k in base:
		env.set(k, base[k])                      # back to how it was, then add this level's
	env.set_meta("world_light_level", level)
	if level == "simple":
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.6
	env.ssao_power = 1.8
	env.ssao_detail = 0.8
	env.ssao_horizon = 0.06
	env.ssao_light_affect = 0.3                  # a touch in sunlight too, so contact shadows show by day
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = HAZE_INSIDE if inside else float(HAZE[level])
	env.volumetric_fog_albedo = haze_colour(env.fog_light_color)
	env.volumetric_fog_length = HAZE_LENGTH
	env.volumetric_fog_anisotropy = HAZE_SHAFTS
	env.volumetric_fog_ambient_inject = HAZE_AMBIENT
	env.volumetric_fog_sky_affect = 0.0          # the skies stay as they are
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_temporal_reprojection_enabled = true
	if level == "best":
		env.ssil_enabled = true
		env.ssil_radius = 4.0
		env.ssil_intensity = 0.9


func suns() -> Array:
	# The place's sun(s): directional lights that are in it
	var out := []
	var scene := get_parent()
	if scene:
		for n in scene.find_children("*", "DirectionalLight3D", true, false):
			out.append(n)
	return out


func _apply_sun() -> void:
	for sun in suns():
		var l := sun as DirectionalLight3D
		if not l.has_meta("world_light_base"):
			var base := {}
			for k in SUN_KEYS:
				base[k] = l.get(k)
			l.set_meta("world_light_base", base)
		var base: Dictionary = l.get_meta("world_light_base")
		for k in base:
			l.set(k, base[k])
		if level == "simple":
			continue
		l.light_volumetric_fog_energy = SUN_HAZE
		if level == "best":
			l.light_angular_distance = SUN_SOFTNESS
			l.shadow_blur = 1.4


func _apply_lamps() -> void:
	# Every other light in the place (lamps, torches, crystals, windows) lights the haze more, so it glows round them
	var scene := get_parent()
	if scene == null:
		return
	for n in scene.find_children("*", "Light3D", true, false):
		if n is DirectionalLight3D:
			continue
		var l := n as Light3D
		if not l.has_meta("world_light_base"):
			l.set_meta("world_light_base", {"light_volumetric_fog_energy": l.light_volumetric_fog_energy})
		var base: float = float(l.get_meta("world_light_base").light_volumetric_fog_energy)
		l.light_volumetric_fog_energy = base if level == "simple" else base * LAMP_HAZE


static func quality_for(want: String) -> void:
	# The haze's grid and the SSAO/SSIL quality are global (RenderingServer), so they're set for the whole game
	if want == "best":
		RenderingServer.environment_set_volumetric_fog_volume_size(96, 96)
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50, 300)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50, 300)
	else:
		RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50, 300)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW, true, 0.5, 4, 50, 300)
