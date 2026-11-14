extends Node

# Swimming, the player's own: Otto's gift once the Tide Reef is mended (scripts/tide_reef.gd). Hayden: "a quest that
# starts above water and allows you to unlock [Otto's] ability that allows you to swim underwater".
#
# Any water deep enough to be out of her depth (scripts/water.gd nodes, in the "water" group: the flooded Tide Reef,
# Willow Pond's deep middle, Otto's Reef Pool in the Void) takes over her physics from walking:
#   - Before the Tide Reef's mended she can only paddle along the top, head out, like any kid who can't swim yet.
#     Nobody ever walks along the bottom with their head under.
#   - Once Otto's taught her (Portals.is_cleared("tide_reef")) she can go under: hold Jump to rise, hold Roll to dive,
#     steer as on foot. She's slow and floaty, she stays at whatever depth she's left at, and a bubble Otto blew sits
#     round her head. There's no breath meter: nobody ever drowns (Hayden's "no drowning" choice, my reading of it).
#   - At the top, Jump hops her out, so she can climb out onto a ledge or a dock.
# Underwater, the camera's view goes blue-green and wobbly, the sound goes muffled, and bubbles trail up from her.
# No new button: Jump and Roll do it, so nothing in Controls changes.
#
# Made by the player (scenes/player/player.gd _ready), which hands its physics over to physics() while active.

const WORLD := "tide_reef"                # the world whose mending unlocks diving
const ENTER_DEPTH := 1.45                 # water at least this deep (surface to bed) is out of her depth
const LEAVE_DEPTH := 1.2                  # ...and she finds her feet again once it's shallower than this
const FLOAT := 0.5                        # at the top, her middle sits this far under the surface (head out)
const SPEED := 0.85                       # times her running speed, swimming
const PADDLE := 0.6                       # ...and paddling along the top before she can swim
const ACCEL := 9.0                        # floaty: it takes a moment to get going and to stop
const RISE := 3.4                         # metres a second, holding Jump
const DIVE := 3.4                         # ...and holding Roll
const VACCEL := 10.0
const HOP := 0.95                         # times her jump, hopping out at the top
const LEAN := 1.15                        # radians she leans forward into a stroke
const BUBBLE_EVERY := 0.45
const SEA := Color(0.2, 0.58, 0.7)
const CAM_DROP := -1.3                    # how far the camera comes down while she's under
const DRY_TIME := 14.0                    # seconds she takes to dry off after a swim
const DRIP_TIME := 6.0                    # ...dripping for the first few of them
const WET_SHADE := Color(0.6, 0.62, 0.7)  # how much darker soaked clothes (and hair) look
const HELMET_R := 0.42                    # the bubble round her head...
const HELMET_UP := 0.26                   # ...its middle this far up from the head bone (the bone sits at the neck)

var player: CharacterBody3D
var active := false
var under := false                        # her head's under (the bubble helmet's on)
var surface := 0.0                        # the top of the water she's in
var bed := -1000.0                        # the bottom under her
var water: Node                           # the water she's in
var _bubble_t := 0.0
var _helmet: MeshInstance3D
var _stroke := 0.0
var _just := 0.0                          # seconds since she went in (no hopping straight back out)
var _dropped := false                     # the camera's been brought down

# The view from under the water (whoever's camera is in it, swimming or not)
var view_under := false
var _layer: CanvasLayer
var _rect: ColorRect
var _env: Environment
var _env_was := {}
var _lowpass := -1

# Wet after a swim (Hayden, 14 Nov: "you should drip and be noticeably wet, maybe dampen your clothes"): her clothes
# and hair go darker and drip, and dry off over DRY_TIME. A darkening overlay (multiply) goes over her model's meshes.
var wet := 0.0                            # 1 = soaked, just out; 0 = dry
var _drip_t := 0.0
var _wet_mat: StandardMaterial3D
var _wet_on: Array = []                   # the meshes wearing the overlay


func setup(p: CharacterBody3D) -> void:
	player = p
	_make_helmet()


func _make_helmet() -> void:
	_helmet = MeshInstance3D.new()
	_helmet.name = "Bubble Helmet"
	var s := SphereMesh.new()
	s.radius = HELMET_R
	s.height = HELMET_R * 2.0
	s.radial_segments = 20
	s.rings = 10
	_helmet.mesh = s
	_helmet.material_override = helmet_mat()
	_helmet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_helmet.visible = false
	player.tumble.add_child(_helmet)
	_helmet.position = Vector3(0, 0.36, 0.02)           # round her head (the tumble's pivot is her middle)


func _fit_helmet() -> void:
	if not is_instance_valid(_helmet):
		_make_helmet()                                  # (her model was rebuilt with the bubble on it)
	# The bubble sits on her head bone, so it stays round her head as she strokes and leans, whoever she is (Hayden,
	# 14 Nov playtest: it didn't cover her head properly; it used to float a fixed height over her middle)
	var model: Node3D = player.get("model")
	var skel: Skeleton3D = null
	var bone := -1
	if model:
		for sk in model.find_children("*", "Skeleton3D", true, false):
			var k := (sk as Skeleton3D).find_bone("head")
			if k >= 0:
				skel = sk
				bone = k
				break
	if skel == null:
		if _helmet.get_parent() != player.tumble:
			_helmet.reparent(player.tumble, false)
			_helmet.position = Vector3(0, 0.36, 0.02)
			_helmet.scale = Vector3.ONE
		return
	var mount := skel.get_node_or_null("Helmet Mount") as BoneAttachment3D
	if mount == null:
		mount = BoneAttachment3D.new()
		mount.name = "Helmet Mount"
		skel.add_child(mount)
	mount.bone_idx = bone
	if _helmet.get_parent() != mount:
		_helmet.reparent(mount, false)
	var grow := mount.global_basis.get_scale()
	var k := Vector3(1.0 / maxf(grow.x, 0.001), 1.0 / maxf(grow.y, 0.001), 1.0 / maxf(grow.z, 0.001))
	_helmet.scale = k                                   # the same size whatever size the model's built at
	_helmet.position = Vector3(0, HELMET_UP, 0.02) * k


static func helmet_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.8, 0.95, 1.0, 0.18)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	m.rim_enabled = true
	m.rim = 0.9
	m.rim_tint = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


static func water_at(tree: SceneTree, p: Vector3) -> Node:
	# The water (a scripts/water.gd node) over this spot, highest first, or null
	var best: Node = null
	for w in tree.get_nodes_in_group("water"):
		if not w.has_method("covers") or not w.covers(p.x, p.z):
			continue
		if best == null or float(w.get("water_y")) > float(best.get("water_y")):
			best = w
	return best


func _bed_below(from: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.5, 0), from + Vector3(0, -40.0, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else -1000.0


func _sample() -> bool:
	# Where's the water round her now? True when she's in water out of her depth.
	var p := player.global_position
	water = water_at(player.get_tree(), p)
	if water == null:
		return false
	surface = float(water.get("water_y"))
	bed = _bed_below(p)
	return surface - bed >= LEAVE_DEPTH and p.y < surface + 0.3


func check() -> bool:
	# Called by the player every physics frame on foot: should she be swimming? Starts it if so.
	if player == null or Game.riding or player.carried:
		return false
	if player.burrow and player.burrow.active:
		return false
	if not _sample():
		return false
	if surface - bed < ENTER_DEPTH or player.global_position.y > surface - 0.2:
		return false
	if player.velocity.y > 0.5:
		return false                                # on the way up out of it (a hop out at the top)
	start()
	return true


func start() -> void:
	active = true
	_just = 0.0
	player.velocity.y = maxf(player.velocity.y, -6.0)        # a big jump in only carries her down so far
	player.sprinting = false
	if player.get("_roll_timer") > 0.0:
		player.call("_end_roll")


func stop(hop := 0.0) -> void:
	if not active:
		return
	active = false
	under = false
	if not is_instance_valid(_helmet):
		_make_helmet()
	_helmet.visible = false
	if _dropped:
		_dropped = false
		var tw := player.create_tween()
		tw.tween_property(player.get("spring_arm"), "lift", 0.0, 0.4)
	soak()
	if hop > 0.0:
		player.velocity.y = player.jump_velocity * hop
		Audio.play_at("splash", player.global_position, -4.0)
		Fx.burst(player.get_parent(), Vector3(player.global_position.x, surface, player.global_position.z),
			Color(0.8, 0.95, 1.0, 0.85), 14, 0.08, 2.6, -8.0, 0.7, 40.0)


func physics(delta: float) -> void:
	# Her physics while she's swimming. The player calls this instead of its own walking.
	_just += delta
	if not is_instance_valid(_helmet):
		_make_helmet()
		under = false
	if Game.riding or player.carried:
		stop()
		return
	var can_dive := unlocked()
	var locked: bool = player.input_locked
	var input_dir := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis: Basis = player.spring_arm.global_transform.basis
	var forward := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
	var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
	var dir := (right * input_dir.x - forward * input_dir.y).normalized()
	var horizontal := Vector2(player.velocity.x, player.velocity.z)
	var target := Vector2(dir.x, dir.z) * float(player.speed) * (SPEED if can_dive else PADDLE)
	horizontal = horizontal.move_toward(target, ACCEL * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.y
	# Up and down
	var y := player.global_position.y
	var top := surface - FLOAT
	var rising := not locked and Input.is_action_pressed("jump")
	var diving := not locked and can_dive and Input.is_action_pressed("dash")
	if not locked and _just > 0.25 and Input.is_action_just_pressed("jump") and y > top - 0.45:
		stop(HOP)                                   # at the top: hop out
		return
	var vy := 0.0
	if diving:
		vy = -DIVE
	elif rising and y < top - 0.05:
		vy = RISE
	elif not can_dive:
		vy = clampf((top - y) * 3.0, -2.5, 5.0)     # can't swim yet: up you bob, to paddle along the top
	elif y > top - 0.7:
		vy = clampf((top - y) * 3.0, -2.5, 2.5)     # bob along at the top
	player.velocity.y = move_toward(player.velocity.y, vy, VACCEL * delta)
	if y >= top and player.velocity.y > 0.0:
		player.velocity.y = minf(player.velocity.y, (top - y) * 8.0 + 0.01)
	player.move_and_slide()
	if not _sample() or player.global_position.y > surface + 0.3:
		stop()
		return
	if surface - bed < LEAVE_DEPTH:
		stop()                                      # found her feet
		return
	# How she looks: leaning into a stroke, turning to face where she's going, a bubble round her head when under
	var going := horizontal.length()
	if dir != Vector3.ZERO:
		player.visual.rotation.y = lerp_angle(player.visual.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 6.0))
	var lean := LEAN * clampf(going / (float(player.speed) * SPEED), 0.0, 1.0)
	lean += clampf(-player.velocity.y / DIVE, -1.0, 1.0) * 0.5
	var k := 1.0 - exp(-6.0 * delta)
	player.tumble.rotation.x = lerp_angle(player.tumble.rotation.x, lean, k)
	player.tumble.scale = player.tumble.scale.lerp(Vector3.ONE, k)
	player.tumble.position.y = lerpf(player.tumble.position.y, 0.0, k)
	var was_under := under and is_instance_valid(_helmet)
	under = player.global_position.y + 0.6 < surface
	if under and not was_under:
		_fit_helmet()
	_helmet.visible = under
	# Under, the camera comes down closer behind her, so in a shallow pond you see the underwater too, not the top
	var arm: Node3D = player.get("spring_arm")
	arm.set("lift", move_toward(float(arm.get("lift")), CAM_DROP if under else 0.0, 2.0 * delta))
	_dropped = true
	_animate(going)
	if under:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble_t = BUBBLE_EVERY + randf() * 0.3
			Fx.burst(player.get_parent(), _helmet.global_position + Vector3(0, 0.35, 0), Color(0.85, 0.97, 1.0, 0.7),
				3, 0.05, 0.6, 1.5, 1.2, 25.0)
	else:
		_stroke -= delta
		if going > 1.0 and _stroke <= 0.0:              # ripples and splashes as she paddles along the top
			_stroke = 0.35
			var p := player.global_position
			Fx.ripple(player.get_parent(), Vector3(p.x, surface + 0.02, p.z))
			Fx.burst(player.get_parent(), Vector3(p.x, surface + 0.05, p.z), Color(0.8, 1.0, 0.9, 0.8), 4, 0.07, 2.0, -8.0, 0.6, 35.0)
			Audio.play_at("step_water", p, -10.0, 0.2)
	RenderingServer.global_shader_parameter_set("nina_pos", player.global_position)


func _animate(going: float) -> void:
	var anim: AnimationPlayer = player.anim
	if anim == null:
		return
	var target := "run" if going > 0.4 else "idle"         # (fall holds the arms straight out: it read as a T-pose)
	if not anim.has_animation(target):
		target = "idle"
	if anim.assigned_animation != target:
		anim.play(target, 0.3)
	anim.speed_scale = 0.55 if target == "run" else 0.6       # slow strokes; arms drifting out when still


# Wet after a swim ---------------------------------------------------------------------------------------------------
func soak() -> void:
	wet = 1.0
	_drip_t = 0.0
	_show_wet()


func _dry(delta: float) -> void:
	if wet <= 0.0:
		return
	if active:
		wet = 1.0                                         # (still in: soaked)
		_show_wet()
		return
	var was := wet
	wet = maxf(wet - delta / DRY_TIME, 0.0)
	_show_wet()
	if was > 1.0 - DRIP_TIME / DRY_TIME:
		_drip_t -= delta
		if _drip_t <= 0.0:
			var heavy := (was - (1.0 - DRIP_TIME / DRY_TIME)) / (DRIP_TIME / DRY_TIME)     # 1 just out, 0 done
			_drip_t = lerpf(0.25, 0.05, heavy)
			var p := player.global_position + Vector3(randf_range(-0.25, 0.25), randf_range(-0.4, 0.65), randf_range(-0.25, 0.25))
			Fx.burst(player.get_parent(), p, Color(0.75, 0.92, 1.0, 0.8), 1 + int(heavy * 2.0), 0.035, 0.2, -12.0, 0.45, 15.0)


func _show_wet() -> void:
	var model: Node3D = player.get("model")
	if wet <= 0.0 or model == null:
		for m in _wet_on:
			if is_instance_valid(m) and (m as GeometryInstance3D).material_overlay == _wet_mat:
				(m as GeometryInstance3D).material_overlay = null
		_wet_on = []
		return
	if _wet_mat == null:
		_wet_mat = StandardMaterial3D.new()
		_wet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_wet_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		_wet_mat.cull_mode = BaseMaterial3D.CULL_BACK
	var k := clampf(wet * 1.6, 0.0, 1.0)                  # stays soaked-looking a while, then fades as she dries
	_wet_mat.albedo_color = Color(1, 1, 1).lerp(WET_SHADE, k)
	if _wet_on.is_empty() or not is_instance_valid(_wet_on[0]) or not model.is_ancestor_of(_wet_on[0]):
		_wet_on = []
		for g in model.find_children("*", "MeshInstance3D", true, false):
			var mi := g as MeshInstance3D
			if mi.material_overlay == null and mi != _helmet and _solid(mi):
				mi.material_overlay = _wet_mat
				_wet_on.append(mi)


static func _solid(mi: MeshInstance3D) -> bool:
	# Only plain see-nothing-through meshes get darker (a see-through one, like a hair card or a glow, would darken
	# its whole square)
	if mi.mesh == null or not mi.is_visible_in_tree():
		return false
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i)
		if not (m is BaseMaterial3D) or (m as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return false
	return true


# The view from under the water -------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if player == null or not player.is_inside_tree():
		return
	_dry(delta)
	var cam := player.get_viewport().get_camera_3d()
	var now := false
	if cam:
		var c := cam.global_position
		var w := water_at(player.get_tree(), c)
		now = w != null and c.y < float(w.get("water_y")) - 0.05 and float(w.get("water_y")) - _bed_below(c) > 0.6
	if now != view_under:
		_set_view(now)


func _set_view(on: bool) -> void:
	view_under = on
	if on:
		if _layer == null:
			_layer = CanvasLayer.new()
			_layer.name = "Underwater"
			_layer.layer = 1                                  # over the world, under the HUD and menus
			_rect = ColorRect.new()
			_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sm := ShaderMaterial.new()
			sm.shader = load("res://scripts/underwater.gdshader")
			_rect.material = sm
			_layer.add_child(_rect)
			player.add_child(_layer)
		(_rect.material as ShaderMaterial).set_shader_parameter("wobble", 0.0 if Settings.reduce_motion else 0.0035)
		_layer.visible = true
		_fog(true)
		_muffle(true)
		Audio.play("splash", -10.0, 0.1)
	else:
		if _layer:
			_layer.visible = false
		_fog(false)
		_muffle(false)


func _fog(on: bool) -> void:
	# Thick blue-green haze under the water: the far side of the reef fades into the sea
	if on:
		var we := player.get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment \
			if player.get_tree().current_scene else null
		_env = we.environment if we else null
		if _env == null:
			return
		_env_was = {"fog_enabled": _env.fog_enabled, "fog_light_color": _env.fog_light_color,
			"fog_density": _env.fog_density, "fog_sky_affect": _env.fog_sky_affect,
			"ambient_light_color": _env.ambient_light_color}
		_env.fog_enabled = true
		_env.fog_light_color = SEA
		_env.fog_density = 0.035
		_env.fog_sky_affect = 1.0
		_env.ambient_light_color = Color(0.55, 0.85, 1.0)
	elif _env and is_instance_valid(_env):
		for k in _env_was:
			_env.set(k, _env_was[k])
		_env = null


func _muffle(on: bool) -> void:
	# Sounds go soft and far away under the water
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if on and _lowpass < 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 700.0
		AudioServer.add_bus_effect(bus, lp)
		_lowpass = AudioServer.get_bus_effect_count(bus) - 1
	elif not on and _lowpass >= 0:
		if _lowpass < AudioServer.get_bus_effect_count(bus):
			AudioServer.remove_bus_effect(bus, _lowpass)
		_lowpass = -1


func _exit_tree() -> void:
	if view_under:
		_set_view(false)                                   # through a door or a portal: everything back as it was
