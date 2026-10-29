extends Node3D

# Earth (scenes/earth/earth.tscn, built by tools/build_earth.gd): the small cozy town where the player lives. Their
# house is on the south side of the green, with their bed (a new game starts there). Earth's clock is the one that
# always runs (scripts/clock.gd). Every night from midnight to 1 AM, the Shift, the portal by the old oak opens to
# Galaxity; the rest of the time it's a quiet ring and walking into it says when it opens.
#
# In the show, kids are people on Earth and creatures in Galaxity. The player keeps their Galaxity look here for now.

const PORTAL_OPEN_TIME := 2.5                      # seconds for the swirl to grow in or shrink away
const SUN_HIGH := 58.0                              # degrees above the horizon at noon
const SUN_NOON := Color(1.0, 0.96, 0.88)
const SUNRISE := Color(1.0, 0.68, 0.5)              # soft peach and gold
const SUNSET := Color(1.0, 0.48, 0.26)              # deep orange
const MOON_LIGHT := Color(0.58, 0.66, 1.0)
const DAY_SKY := {"top": Color(0.2, 0.47, 0.9), "horizon": Color(0.72, 0.85, 0.98)}
const NIGHT_SKY := {"top": Color(0.015, 0.02, 0.07), "horizon": Color(0.07, 0.09, 0.2)}
# How see-through each part of the moon is at full night ("Earth Moon Glow" is its soft halo)
const MOON_ALPHA := {"Earth Moon": 1.0, "Earth Moon Sea": 1.0, "Earth Moon Glow": 0.14}

var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment
var _moon: Node3D
var _cloud_mat: StandardMaterial3D
var _star_mat: StandardMaterial3D
var _moon_mats := {}                               # material -> its alpha at night
var _last_minute := -1
var _portal_door: Area3D
var _swirl: Node3D
var _portal_glow: OmniLight3D
var _glow_energy := 1.5
var _open := 0.0                                   # the portal's swirl: 0 closed .. 1 fully open


func _ready() -> void:
	Clock.on_earth = true
	Dialogue.set_flag("visited_earth")
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
		if _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_moon = get_node_or_null("Sky/Moon") as Node3D
	_cloud_mat = _first_material(get_node_or_null("Sky/Clouds"))
	_star_mat = _first_material(get_node_or_null("Sky/Stars"))
	if _moon:
		for mi in _moon.get_children():
			var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if m and MOON_ALPHA.has(m.resource_name):
				_moon_mats[m] = MOON_ALPHA[m.resource_name]
	_portal_door = find_child("PortalToGalaxity", true, false) as Area3D
	_swirl = find_child("Portal Swirl", true, false) as Node3D
	_portal_glow = find_child("Portal Glow", true, false) as OmniLight3D
	if _portal_glow:
		_glow_energy = _portal_glow.light_energy
	_open = 1.0 if Clock.in_shift() else 0.0
	_light()
	_portal()


func _exit_tree() -> void:
	Clock.on_earth = false


func _process(delta: float) -> void:
	var m := int(Clock.earth_minutes)
	if m != _last_minute:
		_last_minute = m
		_light()
	_open = move_toward(_open, 1.0 if Clock.in_shift() else 0.0, delta / PORTAL_OPEN_TIME)
	_portal()


func _portal() -> void:
	# The swirl and its glow grow in at midnight and fade away at 1 AM. Whether she can go through follows the clock
	# itself, not the swirl (as in Galaxity's portal, scripts/portal.gd).
	var k := smoothstep(0.0, 1.0, _open)
	if _swirl:
		_swirl.visible = k > 0.01
		_swirl.scale = Vector3.ONE * maxf(k, 0.01)
	if _portal_glow:
		_portal_glow.light_energy = _glow_energy * k
		_portal_glow.visible = k > 0.01
	if _portal_door:
		_portal_door.set("closed_message", "" if Clock.in_shift() else
			"The portal is asleep. It opens to Galaxity during the Shift, from midnight to 1 AM.")


func _first_material(n: Node) -> StandardMaterial3D:
	# The material on the first mesh under n (all the clouds share one, all the stars another)
	if n == null:
		return null
	if n is MeshInstance3D:
		return (n as MeshInstance3D).material_override as StandardMaterial3D
	for c in n.get_children():
		var m := _first_material(c)
		if m:
			return m
	return null


func _light() -> void:
	# A whole Earth day from Earth's clock: a blue sky with white clouds by day, a warm sunrise and sunset, then a dark
	# night with stars and the moon. The sun crosses from east to west; the moon follows it round at night. The street
	# lamps come on at dusk.
	var h := Clock.earth_minutes / 60.0
	var day := smoothstep(5.0, 7.5, h) * (1.0 - smoothstep(17.5, 20.0, h))     # 0 night .. 1 day
	var night := 1.0 - day
	var low_sun := clampf(1.0 - absf(day - 0.5) * 2.0, 0.0, 1.0)              # strongest at sunrise and sunset
	var glow: Color = SUNRISE if h < 12.0 else SUNSET
	if _sun:
		var arc := sin(PI * (h - 6.0) / 12.0)                                     # +1 at noon, -1 at midnight
		var heading := 90.0 - (h - 6.0) / 12.0 * 180.0                            # east in the morning, west at evening
		if arc >= 0.0:
			_sun.rotation_degrees = Vector3(-maxf(arc * SUN_HIGH, 3.0), heading, 0.0)
			_sun.light_color = SUN_NOON.lerp(glow, low_sun * 0.85)
			_sun.light_energy = 1.15 * smoothstep(-0.02, 0.15, arc)
		else:
			_sun.rotation_degrees = Vector3(-maxf(-arc * 50.0, 8.0), heading + 180.0, 0.0)
			_sun.light_color = MOON_LIGHT
			_sun.light_energy = 0.22 * smoothstep(-0.02, 0.15, -arc)
		_sun.shadow_enabled = _sun.light_energy > 0.03
		if _moon:
			# The moon sits where the night light comes from, facing the town
			var from := _sun.global_transform.basis.z * (1.0 if arc < 0.0 else -1.0)      # by day: under the far horizon
			_moon.position = from.normalized() * 700.0
			_moon.look_at(Vector3.ZERO)
	if _sky:
		var top: Color = DAY_SKY.top.lerp(glow.lerp(DAY_SKY.top, 0.6), low_sun * 0.5).lerp(NIGHT_SKY.top, night)
		var horizon: Color = DAY_SKY.horizon.lerp(glow, low_sun * 0.85).lerp(NIGHT_SKY.horizon, night * (1.0 - low_sun * 0.5))
		_sky.sky_top_color = top
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.ground_bottom_color = Color(0.3, 0.24, 0.18).lerp(Color(0.03, 0.03, 0.06), night)
	if _env:
		_env.fog_light_color = Color(0.82, 0.86, 0.92).lerp(glow, low_sun * 0.6).lerp(Color(0.1, 0.11, 0.2), night * 0.9)
		_env.ambient_light_energy = lerpf(0.32, 0.8, day)
	# Clouds: white by day, rosy gold at sunrise and sunset, dim grey-blue at night
	if _cloud_mat:
		var c := Color.WHITE.lerp(glow.lightened(0.35), low_sun * 0.8).lerp(Color(0.24, 0.26, 0.38), night * (1.0 - low_sun * 0.6))
		_cloud_mat.albedo_color = Color(c, lerpf(0.55, 0.92, day))
	var stars := smoothstep(0.45, 0.05, day)
	if _star_mat:
		_star_mat.albedo_color.a = stars
	for m: StandardMaterial3D in _moon_mats:
		m.albedo_color.a = _moon_mats[m] * stars
	for l in get_tree().get_nodes_in_group("earth_lamps"):
		(l as Light3D).visible = day < 0.6
