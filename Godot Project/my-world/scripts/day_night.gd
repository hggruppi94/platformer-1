extends Node

# Day and night for an outdoor scene, driven by the Clock autoload (scripts/clock.gd).
#
# The colours the scene was built with (tools/build_town.gd) are its noon look. From those it works out dawn, dusk
# and night: the sun rises in the east and sets in the west, then a soft blue moonlight takes over. Nights stay bright
# enough to play in. During the Shift the sky takes on a violet glow.
#
# Lamps and windows: OmniLights in the "night_lights" group switch on at dusk, and glowing materials named in
# NIGHT_GLOW (lamp bulbs, windows) glow brighter at night.

@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"

const SUN_YAW := -35.0               # degrees: the sun's compass heading at noon, as built
const SUN_MAX_ELEVATION := 62.0      # degrees above the horizon at noon
const MOON_ENERGY := 0.28
const MOON_COLOR := Color(0.62, 0.7, 1.0)
const NIGHT_AMBIENT := 0.55          # ambient light energy at night (1.0 in the day): low enough to feel like night,
                                     # high enough that kids can still see where they're going
const NIGHT_SKY := {"top": Color(0.03, 0.02, 0.1), "horizon": Color(0.16, 0.08, 0.3), "bottom": Color(0.03, 0.02, 0.07)}
const DUSK_HORIZON := Color(1.0, 0.45, 0.3)
const DUSK_SUN := Color(1.0, 0.55, 0.35)
const SHIFT_GLOW := Color(0.55, 0.2, 0.85)   # violet tint on the night sky during the Shift
# Material name -> emission energy at night (the day value is whatever it was built with)
const NIGHT_GLOW := {"Lamp": 4.0, "Window": 1.6, "Castle Window": 2.6, "Haunted Window": 1.8, "Castle Door Glow": 2.2,
	"Castle Rose Window": 3.2}

var _sun: DirectionalLight3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _day := {}                       # the scene's own (noon) look
var _glow_mats := {}                 # material -> day emission energy
var _cloud_mats := {}                # cloud material ("Sky Cloud") -> its daytime see-through-ness
var _shift := 0.0                    # 0..1, eased in and out


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var we := get_node_or_null(environment_path) as WorldEnvironment
	if we:
		_env = we.environment
		if _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	if _sun:
		_day["sun_color"] = _sun.light_color
		_day["sun_energy"] = _sun.light_energy
	if _env:
		_day["ambient"] = _env.ambient_light_energy
		_day["fog_color"] = _env.fog_light_color
	if _sky:
		_day["top"] = _sky.sky_top_color
		_day["horizon"] = _sky.sky_horizon_color
		_day["bottom"] = _sky.ground_bottom_color
	_find_glow_materials(get_parent())
	_shift = 1.0 if Clock.in_shift() else 0.0
	_update(0.0)


func _find_glow_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var found: Array = [mi.material_override]
		if mi.mesh:                                      # merged meshes (the castle) keep theirs per surface
			for i in mi.mesh.get_surface_count():
				found.append(mi.mesh.surface_get_material(i))
		for m in found:
			var sm := m as StandardMaterial3D
			if sm and sm.resource_name == "Sky Cloud" and not _cloud_mats.has(sm):
				_cloud_mats[sm] = sm.albedo_color.a
			if sm and sm.emission_enabled and NIGHT_GLOW.has(sm.resource_name) and not _glow_mats.has(sm):
				_glow_mats[sm] = sm.emission_energy_multiplier
	for c in n.get_children():
		_find_glow_materials(c)


func _process(delta: float) -> void:
	_update(delta)


func _update(delta: float) -> void:
	var h := Clock.hours()
	var day := Clock.daylight()                          # 0 night .. 1 day
	var night := 1.0 - day
	# Dusk/dawn: strongest while the sun is low, gone at noon and midnight
	var low_sun := clampf(1.0 - absf(day - 0.5) * 2.0, 0.0, 1.0)
	var target_shift := 1.0 if Clock.in_shift() else 0.0
	_shift = move_toward(_shift, target_shift, delta * 0.5) if delta > 0.0 else target_shift

	# Sun and moon share one light: the sun by day, the moon (on the opposite side of the sky) by night
	if _sun:
		var arc := sin(PI * (h - 6.0) / 12.0)            # +1 at noon, 0 at 6 AM/PM, -1 at midnight
		var sun_up := smoothstep(-0.02, 0.12, arc)
		var moon_up := smoothstep(-0.02, 0.12, -arc)
		var heading := SUN_YAW + 90.0 - (h - 6.0) / 12.0 * 180.0      # east in the morning, west in the evening
		if arc >= 0.0:
			_sun.rotation_degrees = Vector3(-maxf(arc * SUN_MAX_ELEVATION, 4.0), heading, 0.0)
			_sun.light_color = (_day.get("sun_color", Color.WHITE) as Color).lerp(DUSK_SUN, low_sun * 0.8)
			_sun.light_energy = _day.get("sun_energy", 1.0) * sun_up
		else:
			_sun.rotation_degrees = Vector3(-maxf(-arc * 50.0, 4.0), heading + 180.0, 0.0)
			_sun.light_color = MOON_COLOR.lerp(SHIFT_GLOW, _shift * 0.4)
			_sun.light_energy = MOON_ENERGY * moon_up
		_sun.shadow_enabled = _sun.light_energy > 0.02

	if _env:
		_env.ambient_light_energy = lerpf(NIGHT_AMBIENT, _day.get("ambient", 1.0), day)
		if _day.has("fog_color"):
			_env.fog_light_color = (_day["fog_color"] as Color).lerp(NIGHT_SKY.horizon, night * 0.8)
	if _sky:
		var night_top: Color = NIGHT_SKY.top.lerp(SHIFT_GLOW * 0.45, _shift)
		var night_horizon: Color = NIGHT_SKY.horizon.lerp(SHIFT_GLOW, _shift * 0.7)
		var horizon: Color = (_day.horizon as Color).lerp(DUSK_HORIZON, low_sun * 0.6)
		_sky.sky_top_color = (_day.top as Color).lerp(night_top, night)
		_sky.sky_horizon_color = horizon.lerp(night_horizon, night)
		_sky.ground_horizon_color = _sky.sky_horizon_color
		_sky.ground_bottom_color = (_day.bottom as Color).lerp(NIGHT_SKY.bottom, night)
		_sky.sun_curve = 0.15

	# Clouds fade away at night
	for m: StandardMaterial3D in _cloud_mats:
		m.albedo_color.a = _cloud_mats[m] * smoothstep(0.1, 0.6, day)

	# Lamps and windows
	var lamps_on := smoothstep(0.55, 0.2, day)           # in as the sun goes down, out after sunrise
	for m: StandardMaterial3D in _glow_mats:
		m.emission_energy_multiplier = lerpf(_glow_mats[m], NIGHT_GLOW[m.resource_name], lamps_on)
	for l in get_tree().get_nodes_in_group("night_lights"):
		var light := l as Light3D
		if light:
			if not light.has_meta("night_energy"):
				light.set_meta("night_energy", light.light_energy)
			light.visible = lamps_on > 0.01
			light.light_energy = light.get_meta("night_energy") * lamps_on
