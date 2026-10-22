extends Node3D

# Earth, through the portal (scenes/earth/earth.tscn, built by tools/build_earth.gd): a small cozy town on an autumn
# evening. Nina can only come during the Shift. While she's here Galactopia's clock crawls (scripts/clock.gd,
# EARTH_SLOWDOWN), so one Shift hour is a whole Earth evening; when the Shift ends, the portal pulls her home.
# The portal she came through (by the old oak) takes her home sooner, any time.
#
# In the show, kids are people on Earth and creatures in Galactopia. Nina keeps her Galactopia look here for now.

const TOWN := "res://scenes/town/town.tscn"
const HOME_SPAWN := "FromPortaltoEarth"
const WARN_AT := 50.0                              # Galactopia minutes past midnight: "nearly time to go"

var _warned := false
var _leaving := false
var _last_minute := -1
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _env: Environment


func _ready() -> void:
	Clock.on_earth = true
	Dialogue.set_flag("visited_earth")
	_sun = get_node_or_null("Sun") as DirectionalLight3D
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
		if _env.sky:
			_sky = _env.sky.sky_material as ProceduralSkyMaterial
	_light()
	if not Clock.in_shift():
		go_home.call_deferred("The Shift is over, so the portal brought Nina home.")
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
		go_home("The Shift is over! The portal swirls up and pulls Nina home.")
	elif not _warned and Clock.minutes >= WARN_AT:
		_warned = true
		Game.message("The portal is flickering: the Shift is nearly over. Time to say goodbye!")


func go_home(why := "") -> void:
	if _leaving and why == "":
		return
	_leaving = true
	Game.pending_message = why
	Game.go(TOWN, HOME_SPAWN, "home")


func _light() -> void:
	# Late afternoon sun going down to evening, then night; the street lamps come on at dusk
	var h := Clock.earth_minutes / 60.0
	var dusk := clampf((h - 16.5) / 3.0, 0.0, 1.0)      # 4:30 PM -> 7:30 PM
	if _sun:
		_sun.light_energy = lerpf(1.1, 0.12, dusk)
		_sun.light_color = Color(1.0, 0.75, 0.45).lerp(Color(0.45, 0.5, 0.9), dusk)
	if _sky:
		_sky.sky_top_color = Color(0.35, 0.5, 0.8).lerp(Color(0.05, 0.06, 0.18), dusk)
		_sky.sky_horizon_color = Color(1.0, 0.65, 0.4).lerp(Color(0.3, 0.2, 0.35), dusk)
	if _env:
		_env.fog_light_color = Color(0.9, 0.7, 0.55).lerp(Color(0.12, 0.12, 0.22), dusk)
		_env.ambient_light_energy = lerpf(0.7, 0.3, dusk)
	for l in get_tree().get_nodes_in_group("earth_lamps"):
		(l as Light3D).visible = h >= 17.5 or h < 7.0
