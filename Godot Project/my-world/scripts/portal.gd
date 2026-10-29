extends Node3D

# The portal to Earth (built by tools/build_town.gd). It's open during the Shift, Earth's midnight to 1 AM
# (scripts/clock.gd): the swirl grows in the ring, sparkles drift out of it and it lights up the ground around it.
# The player only comes to Galaxity in the Shift, so here it's open: walk in to go home to Earth early (the Shift goes
# on there until 1 AM, and the portal on Earth brings them back). When the Shift ends it pulls them home anyway.
# It stands by the homes, so when it opens its glow lights up the whole neighbourhood (NeighbourhoodGlow).

const OPEN_TIME := 2.5               # seconds for the swirl to grow in or shrink away
const ARRIVE_FURTHER := 5.0          # metres further out than the door marker that arrivals from Earth appear

@onready var _swirl: Node3D = $Swirl
@onready var _glow: OmniLight3D = $Glow
@onready var _hood: OmniLight3D = get_node_or_null("NeighbourhoodGlow")
@onready var _sparkles: CPUParticles3D = $Sparkles
@onready var _door: Area3D = $Door
@onready var _ring_mat: StandardMaterial3D = ($Ring as MeshInstance3D).material_override

var _open := 0.0                     # 0 closed .. 1 fully open
var _glow_energy := 1.0
var _hood_energy := 1.0
var _ring_energy := 1.0
var _t := 0.0


func _ready() -> void:
	_glow_energy = _glow.light_energy
	if _hood:
		_hood_energy = _hood.light_energy
	_ring_energy = _ring_mat.emission_energy_multiplier
	_open = 1.0 if Clock.in_shift() else 0.0
	# Arrivals from Earth come out a few steps further from the ring than the builder's door marker, which left the
	# camera behind her inside the open swirl and the whole screen white. (Now the portal's always open in Galaxity, so
	# every arrival would see it.)
	var arrive := get_node_or_null("FromPortaltoEarth") as Node3D
	if arrive:
		arrive.position.z += ARRIVE_FURTHER
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_open = move_toward(_open, 1.0 if Clock.in_shift() else 0.0, delta / OPEN_TIME)
	_apply()


func _apply() -> void:
	var k := smoothstep(0.0, 1.0, _open)
	var pulse := 1.0 if Settings.reduce_flashing else 0.85 + 0.15 * sin(_t * 2.2)
	_swirl.visible = k > 0.01
	_swirl.scale = Vector3.ONE * maxf(k, 0.01)
	_glow.visible = k > 0.01
	_glow.light_energy = _glow_energy * k * pulse
	if _hood:
		_hood.visible = k > 0.01
		_hood.light_energy = _hood_energy * k * pulse
	_sparkles.emitting = k > 0.5
	_ring_mat.emission_energy_multiplier = lerpf(_ring_energy * 0.3, _ring_energy * 2.5, k)
	# Whether she can go through follows the clock itself, not the swirl fading in or out: when the time jumps (a
	# save loaded during the Shift, sleeping, the Shift ending) the swirl takes a moment to catch up, and in that
	# moment the portal used to let her through to an Earth that sent her straight back.
	if Clock.in_shift():
		var earth_ready := ResourceLoader.exists(_door.destination)
		_door.closed_message = "" if earth_ready else \
			"The portal is open and swirling... but the way through isn't ready yet. Maybe one day!"
	else:
		_door.closed_message = "The portal is asleep. It only opens during the Shift, from midnight to 1 AM."
