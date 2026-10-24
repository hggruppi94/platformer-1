extends Node3D

# Earth, through the portal (scenes/earth/earth.tscn, built by tools/build_earth.gd): a small cozy town on an autumn
# evening. Nina can only come during the Shift. While she's here Galaxity's clock crawls (scripts/clock.gd,
# EARTH_SLOWDOWN), so one Shift hour is a whole Earth evening; when the Shift ends, the portal pulls her home.
# The portal she came through (by the old oak) takes her home sooner, any time.
#
# In the show, kids are people on Earth and creatures in Galaxity. Nina keeps her Galaxity look here for now.

const TOWN := "res://scenes/town/town.tscn"
const HOME_SPAWN := "FromPortaltoEarth"
const WARN_AT := 50.0                              # Galaxity minutes past midnight: "nearly time to go"

var _warned := false
var _leaving := false
var _last_minute := -1
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
	_light()
	if not Clock.in_shift():
		go_home.call_deferred("The Shift is over, so the portal brought %s home." % Dialogue.player_name())
	else:
		Game.message.call_deferred("Earth! A cozy little town on an autumn evening. When the Shift ends (1 AM back home), the portal will pull you home.")


func _exit_tree() -> void:
	Clock.on_earth = false


func _process(_delta: float) -> void:
	var m := int(Clock.earth_minutes)
	if m != _last_minute:
		_last_minute = m
		Clock.time_changed.emit()                      # the HUD shows Earth's time too
		_light()
	if _leaving:
		return
	if not Clock.in_shift():
		go_home("The Shift is over! The portal swirls up and pulls %s home." % Dialogue.player_name())
	elif not _warned and Clock.minutes >= WARN_AT:
		_warned = true
		Game.message("The portal is flickering: the Shift is nearly over. Time to say goodbye!")


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


func go_home(why := "") -> void:
	if _leaving and why == "":
		return
	_leaving = true
	Game.pending_message = why
	Game.go(TOWN, HOME_SPAWN, "home")


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
