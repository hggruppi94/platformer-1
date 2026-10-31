class_name FrostPuff
extends Node3D

# The Freeze mod's frosty puff (scripts/arsenal.gd): where a shot with Freeze fitted pops or splashes, a little cloud of
# frost swells and fades, and every enemy in it goes frosty for a few seconds: pale blue sparkles and a snowflake over
# its head, and it walks at a third of its speed (Arsenal.slow, read by gloop.gd and crocodillo.gd). Nothing gets
# hurt. With Split fitted as well (the Icy Shards combo) the puff also throws little icy shards at up to three enemies
# near it, and each one counts as a hit from that gadget.

const RADIUS := 3.0
const CHILL := 4.0                        # seconds an enemy stays frosty
const SLOW := 0.35                        # how fast a frosty enemy goes
const SHARD_REACH := 7.0
const SHARDS := 3
const ICE := Color(0.6, 0.9, 1.0)

var gadget := "popper"
var shards := false
var chilled: Array[Node] = []             # tests read it


static func spawn(parent: Node, at: Vector3, id: String, icy_shards := false) -> FrostPuff:
	var f := FrostPuff.new()
	f.gadget = id
	f.shards = icy_shards
	f.name = "FrostPuff"
	parent.add_child(f)
	f.global_position = at
	f.start()
	return f


func start() -> void:
	# (Once it's where it goes: everything here works from its position)
	add_to_group("frost_puffs")
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or e.get("defeated") == true:
			continue
		if (e as Node3D).global_position.distance_to(global_position) < RADIUS + 0.4 * float(e.get("size") if e.get("size") != null else 1.0):
			Arsenal.chill(e)
			chilled.append(e)
	# A cloud of frost that swells and fades
	var cloud := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	cloud.mesh = s
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.97, 1.0, 0.4)
	m.emission_enabled = true
	m.emission = ICE
	m.emission_energy_multiplier = 0.3 if Settings.reduce_flashing else 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud.material_override = m
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud)
	cloud.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(cloud, "scale", Vector3(1.0, 0.6, 1.0) * RADIUS, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
	Fx.burst(get_parent(), global_position, Color(0.9, 1.0, 1.0), 18, 0.06, 3.0, -1.0, 0.8)
	Fx.burst(get_parent(), global_position, ICE, 10, 0.05, 2.0, 1.0, 0.9)
	Audio.play_at("frost", global_position, -4.0, 0.1)
	if shards:
		_throw_shards.call_deferred()


func _throw_shards() -> void:
	# Icy Shards: a little spike of ice flies at each of the nearest few enemies
	var near: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.get("defeated") != true and (e as Node3D).is_visible_in_tree():
			var d := (e as Node3D).global_position.distance_to(global_position)
			if d < SHARD_REACH:
				near.append([d, e])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var parent := get_parent()
	var from := global_position
	var id := gadget
	for k in mini(SHARDS, near.size()):
		var e: Node3D = near[k][1]
		var shard := MeshInstance3D.new()
		shard.name = "IcyShard%d" % k
		var p := PrismMesh.new()
		p.size = Vector3(0.12, 0.4, 0.12)
		shard.mesh = p
		shard.material_override = StarBubble._flat(Color(0.8, 0.97, 1.0))
		parent.add_child(shard)
		shard.add_to_group("icy_shards")
		shard.global_position = from + Vector3(0, 0.4, 0)
		var to := e.global_position + Vector3(0, 0.5, 0)
		shard.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT)
		shard.rotate_object_local(Vector3.RIGHT, -PI / 2)
		var tw := shard.create_tween()
		tw.tween_property(shard, "global_position", to, 0.18 + 0.03 * k)
		tw.tween_callback(func() -> void:
			if is_instance_valid(e):
				Arsenal.hit(e, 1, (to - from).normalized(), id)
				Fx.burst(shard.get_parent(), to, Color(0.85, 1.0, 1.0), 8, 0.04, 2.0, -1.0, 0.4)
			shard.queue_free())


static func frost_on(e: Node3D, seconds: float) -> void:
	# A frosty look on an enemy while it's slowed: pale sparkles round it and a snowflake over its head
	if e == null or not is_instance_valid(e):
		return
	var old := e.get_node_or_null("Frost")
	if old:
		old.set_meta("left", seconds)
		return
	var frost := Node3D.new()
	frost.name = "Frost"
	frost.set_meta("left", seconds)
	e.add_child(frost)
	var size := float(e.get("size") if e.get("size") != null else 1.0)
	var flake := Label3D.new()
	flake.text = "❄"
	flake.font_size = 72
	flake.pixel_size = 0.006
	flake.outline_size = 10
	flake.modulate = Color(0.85, 0.97, 1.0)
	flake.outline_modulate = Color(0.15, 0.3, 0.5)
	flake.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flake.position.y = 1.3 * size
	frost.add_child(flake)
	var sparkle := CPUParticles3D.new()
	sparkle.amount = 12
	sparkle.lifetime = 0.8
	var bit := SphereMesh.new()
	bit.radius = 0.03
	bit.height = 0.06
	bit.radial_segments = 4
	bit.rings = 2
	bit.material = StarBubble._flat(Color(0.85, 0.97, 1.0))
	sparkle.mesh = bit
	sparkle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 0.5 * size
	sparkle.position.y = 0.5 * size
	sparkle.gravity = Vector3(0, -0.4, 0)
	sparkle.initial_velocity_max = 0.2
	frost.add_child(sparkle)
	var t := Timer.new()
	t.wait_time = 0.25
	t.autostart = true
	frost.add_child(t)
	t.timeout.connect(func() -> void:
		var left := float(frost.get_meta("left")) - 0.25
		frost.set_meta("left", left)
		if left <= 0.0 or e.get("defeated") == true:
			frost.queue_free())
