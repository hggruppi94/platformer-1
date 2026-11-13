extends Node3D

# The portal to Earth (built by tools/build_town.gd). It's open during the Shift, Earth's midnight to 1 AM
# (scripts/clock.gd): the swirl grows in the ring, sparkles drift out of it and it lights up the ground around it.
# The player only comes to the Void in the Shift, so here it's open: walk in to go home to Earth early (the Shift goes
# on there until 1 AM, and the portal on Earth brings them back). When the Shift ends it pulls them home anyway.
# It stands by the homes, so when it opens its glow lights up the whole neighbourhood (NeighbourhoodGlow).
#
# Since 12 Nov 2026 (Hayden, lore bible v2: "the cracks ARE the portals") the builder's ring on its stone base is
# taken away at play time and a crack in the ground opens where it stood (scripts/crack.gd): jump in to go home. The
# builder's door is moved down into the crack, so falling in is walking through it. Nothing in town.tscn changed.

const OPEN_TIME := 2.5               # seconds for the swirl to grow in or shrink away
const ARRIVE_FURTHER := 5.0          # metres further out than the door marker that arrivals from Earth appear

@onready var _swirl: Node3D = $Swirl
@onready var _glow: OmniLight3D = $Glow
@onready var _hood: OmniLight3D = get_node_or_null("NeighbourhoodGlow")
@onready var _sparkles: CPUParticles3D = $Sparkles
@onready var _door: Area3D = $Door
@onready var _ring_mat: StandardMaterial3D = ($Ring as MeshInstance3D).material_override

const CRACK := preload("res://scripts/crack.gd")
const COLOUR := Color(0.5, 0.75, 1.0)
var crack: Node3D

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
	_make_crack.call_deferred()
	# Arrivals from Earth come out a few steps further from the ring than the builder's door marker, which left the
	# camera behind her inside the open swirl and the whole screen white. (Now the portal's always open in the Void, so
	# every arrival would see it.)
	var arrive := get_node_or_null("FromPortaltoEarth") as Node3D
	if arrive:
		arrive.position.z += ARRIVE_FURTHER
	_apply()


func _make_crack() -> void:
	# Away with the ring, its stone base and its swirl; in with a crack, with the door down inside it
	for c in get_children():
		if c is MeshInstance3D or c is CPUParticles3D:
			(c as Node3D).visible = false
		elif c is StaticBody3D:
			c.free()                       # (the base's slab: gone before the ground's cut, so the cut skips it)
	crack = CRACK.make(COLOUR)
	crack.name = "Crack"
	add_child(crack)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 10, 0), global_position + Vector3(0, -10, 0))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit:
		crack.global_position = hit.position
	CRACK.sink(crack, get_tree().current_scene)
	_door.set_meta("crack", crack)            # (falling in: the crack's tumble, then through)
	_door.global_position = crack.global_position + Vector3(0, -1.0, 0)
	var shape := (_door.get_child(0) as CollisionShape3D) if _door.get_child_count() > 0 else null
	if shape and shape.shape is BoxShape3D:
		var b := (shape.shape as BoxShape3D).duplicate() as BoxShape3D
		b.size = Vector3(CRACK.R * 1.3, 2.4, CRACK.R * 1.3)
		shape.shape = b
		shape.position = Vector3.ZERO
	_glow.global_position = crack.global_position + Vector3(0, 0.6, 0)
	_apply()


func _process(delta: float) -> void:
	_t += delta
	_open = move_toward(_open, 1.0 if Clock.in_shift() else 0.0, delta / OPEN_TIME)
	_apply()


func _apply() -> void:
	var k := smoothstep(0.0, 1.0, _open)
	var pulse := 1.0 if Settings.reduce_flashing else 0.85 + 0.15 * sin(_t * 2.2)
	_swirl.visible = k > 0.01 and crack == null     # (the crack has its own swirl, down inside it)
	_swirl.scale = Vector3.ONE * maxf(k, 0.01)
	_glow.visible = k > 0.01
	_glow.light_energy = _glow_energy * k * pulse
	if _hood:
		_hood.visible = k > 0.01
		_hood.light_energy = _hood_energy * k * pulse
	_sparkles.emitting = false
	if crack:
		CRACK.set_open(crack, k)
	_ring_mat.emission_energy_multiplier = lerpf(_ring_energy * 0.3, _ring_energy * 2.5, k)
	# Whether she can go through follows the clock itself, not the swirl fading in or out: when the time jumps (a
	# save loaded during the Shift, sleeping, the Shift ending) the swirl takes a moment to catch up, and in that
	# moment the portal used to let her through to an Earth that sent her straight back.
	if Clock.in_shift():
		var earth_ready := ResourceLoader.exists(_door.destination)
		_door.closed_message = "" if earth_ready else \
			"The crack is open and swirling... but the way through isn't ready yet. Maybe one day!"
	else:
		_door.closed_message = "The crack is closed. It only opens during the Shift, from midnight to 1 AM."
