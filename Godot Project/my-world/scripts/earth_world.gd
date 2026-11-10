extends Node3D

# Earth (scenes/earth/earth.tscn, built by tools/build_earth.gd): the small cozy town where the player lives. Their
# house is on the south side of the green, with their bed (a new game starts there). Earth's clock is the one that
# always runs (scripts/clock.gd). Every night from midnight to 1 AM, the Shift, the portal by the old oak opens to
# The Void; the rest of the time it's a quiet ring and walking into it says when it opens.
#
# In the show, kids are people on Earth and creatures in the Void. The player keeps their Void look here for now.

const PORTAL_OPEN_TIME := 2.5                      # seconds for the swirl to grow in or shrink away
const SUN_HIGH := 58.0                              # degrees above the horizon at noon
const SUN_NOON := Color(1.0, 0.96, 0.88)
const SUNRISE := Color(1.0, 0.68, 0.5)              # soft peach and gold
const SUNSET := Color(1.0, 0.48, 0.26)              # deep orange
const MOON_LIGHT := Color(0.58, 0.66, 1.0)
const DAY_SKY := {"top": Color(0.2, 0.47, 0.9), "horizon": Color(0.72, 0.85, 0.98)}
const NIGHT_SKY := {"top": Color(0.015, 0.02, 0.07), "horizon": Color(0.07, 0.09, 0.2)}
# Summer (Earth's calendar, scripts/clock.gd): the sun climbs higher and shines brighter and whiter, a big glowing
# disc in a deep clear blue sky, and the days are long (up before 5, still light at 9 in the evening)
const SUMMER := {"high": 74.0, "energy": 1.45, "noon": Color(1.0, 0.98, 0.92), "ambient": 0.9,
	"top": Color(0.12, 0.42, 0.95), "horizon": Color(0.62, 0.84, 1.0), "sun_size": 50.0, "sun_glow": 0.07,
	"rise": [3.5, 6.0], "set": [19.5, 22.0]}
# Spring: a fresh, soft morning light, a pale washed blue sky after the showers, and days a little longer than autumn's
# (the sun's up from half past five till half past seven)
const SPRING := {"high": 62.0, "energy": 1.25, "noon": Color(1.0, 0.97, 0.9), "ambient": 0.85,
	"top": Color(0.28, 0.55, 0.92), "horizon": Color(0.8, 0.9, 1.0), "rise": [4.5, 7.0], "set": [18.5, 21.0],
	"up": 5.5, "down": 19.5}
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
var _sun_size := -1.0                              # the sky's sun disc as built (summer makes it bigger)
var _sun_curve := 0.15


func _ready() -> void:
	Clock.on_earth = true
	Dialogue.set_flag("visited_earth")
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
		if _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
			if _sky:
				_sun_size = _sky.sun_angle_max
				_sun_curve = _sky.sun_curve
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
	_open = 1.0 if _door_open() else 0.0
	_light()
	_portal()


func _exit_tree() -> void:
	Clock.on_earth = false


func _process(delta: float) -> void:
	var m := int(Clock.earth_minutes)
	if m != _last_minute:
		_last_minute = m
		_light()
	_open = move_toward(_open, 1.0 if _door_open() else 0.0, delta / PORTAL_OPEN_TIME)
	_portal()


func _portal() -> void:
	# The swirl and its glow grow in at midnight and fade away at 1 AM. Whether she can go through follows the clock
	# itself, not the swirl (as in the Void's portal, scripts/portal.gd).
	var k := smoothstep(0.0, 1.0, _open)
	if _swirl:
		_swirl.visible = k > 0.01
		_swirl.scale = Vector3.ONE * maxf(k, 0.01)
	if _portal_glow:
		_portal_glow.light_energy = _glow_energy * k
		_portal_glow.visible = k > 0.01
	if _portal_door:
		if not HummingOak.awake():
			_portal_door.set("closed_message", "It's just a big old oak tree... isn't it? Something's ticking inside it.")
		else:
			_portal_door.set("closed_message", "" if Clock.in_shift() else
				"The door in the old oak is asleep. It opens to the Void during the Shift, from midnight to 1 AM.")


func _door_open() -> bool:
	# The oak's door opens in the Shift, once it's awake (on a new game's first day it's woken at midnight:
	# scripts/humming_oak.gd)
	return Clock.in_shift() and HummingOak.awake()


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
	var summer := Clock.season() == "summer"
	var spring := Clock.season() == "spring"
	var rise: Array = SUMMER.rise if summer else (SPRING.rise if spring else [5.0, 7.5])
	var dusk: Array = SUMMER.set if summer else (SPRING.set if spring else [17.5, 20.0])
	var day := smoothstep(rise[0], rise[1], h) * (1.0 - smoothstep(dusk[0], dusk[1], h))     # 0 night .. 1 day
	var night := 1.0 - day
	var low_sun := clampf(1.0 - absf(day - 0.5) * 2.0, 0.0, 1.0)              # strongest at sunrise and sunset
	var glow: Color = SUNRISE if h < 12.0 else SUNSET
	if _sun:
		# The sun's up from 6 to 6 (in summer from half past four till 9 at night, in spring from half past five till half
		# past seven): +1 at its highest, 0 at the horizon, and below it all night, -1 deepest in the middle of the night
		var up: float = 4.5 if summer else (SPRING.up if spring else 6.0)
		var down: float = 21.0 if summer else (SPRING.down if spring else 18.0)
		var arc: float
		var heading: float                                                        # east in the morning, west at evening
		if h >= up and h <= down:
			arc = sin(PI * (h - up) / (down - up))
			heading = 90.0 - (h - up) / (down - up) * 180.0
		else:
			var t := fposmod(h - down, 24.0) / (24.0 - (down - up))
			arc = -sin(PI * t)
			heading = -90.0 - t * 180.0
		if arc >= 0.0:
			_sun.rotation_degrees = Vector3(-maxf(arc * (SUMMER.high if summer else (SPRING.high if spring else SUN_HIGH)), 3.0), heading, 0.0)
			_sun.light_color = (SUMMER.noon if summer else (SPRING.noon if spring else SUN_NOON)).lerp(glow, low_sun * (0.6 if summer else 0.85))
			_sun.light_energy = (SUMMER.energy if summer else (SPRING.energy if spring else 1.15)) * smoothstep(-0.02, 0.15, arc)
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
		var day_top: Color = SUMMER.top if summer else (SPRING.top if spring else DAY_SKY.top)
		var day_horizon: Color = SUMMER.horizon if summer else (SPRING.horizon if spring else DAY_SKY.horizon)
		var top: Color = day_top.lerp(glow.lerp(day_top, 0.6), low_sun * 0.5).lerp(NIGHT_SKY.top, night)
		var horizon: Color = day_horizon.lerp(glow, low_sun * 0.85).lerp(NIGHT_SKY.horizon, night * (1.0 - low_sun * 0.5))
		_sky.sky_top_color = top
		_sky.sky_horizon_color = horizon
		_sky.ground_horizon_color = horizon
		_sky.ground_bottom_color = Color(0.3, 0.24, 0.18).lerp(Color(0.03, 0.03, 0.06), night)
		if _sun_size >= 0.0:
			_sky.sun_angle_max = SUMMER.sun_size if summer else _sun_size
			_sky.sun_curve = SUMMER.sun_glow if summer else _sun_curve
	if _env:
		_env.fog_light_color = Color(0.82, 0.86, 0.92).lerp(glow, low_sun * 0.6).lerp(Color(0.1, 0.11, 0.2), night * 0.9)
		_env.ambient_light_energy = lerpf(0.32, SUMMER.ambient if summer else (SPRING.ambient if spring else 0.8), day)
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
