extends Node

# Autoload "Wilds": the new enemies out in the Void (Hayden, 12 Nov 2026: "I want to make more enemies"). Put into the
# town at play time (like the Goblin Clockyard, scripts/bosses.gd), so nothing needs the town rebuilt:
#   - Glorp Meadow, on the flat west of the castle hill: Glorps (scripts/glorp.gd), Gloops that split in two when
#     popped, and again, until the littlest pop for good. The big ones come back later.
#   - The Static Field, out in the far north-east fields: a crack in the ground fizzing with static, and the Fizzlers
#     (scripts/fizzler.gd) that zip about round it. They come back later too.
#   - The Spooky Woods at night: shadow ghosts (scripts/shadow_ghost.gd, Dark Hollow's little enemy) come out among the
#     trees once it's dark in the Void, and fade away when the sun comes up. A new lot comes out each night.
# Every spot was checked flat, dry, off the townsfolk's paths, clear of the races and the trees (tools/test_wilds.gd).
# Their bosses live in the Star Arena (scripts/arena.gd).

const TOWN := "res://scenes/town/town.tscn"
const GLORP := preload("res://scripts/glorp.gd")
const FIZZLER := preload("res://scripts/fizzler.gd")
const SHADOW_GHOST := preload("res://scripts/shadow_ghost.gd")

const MEADOW := Vector2(-58, -120)             # x, z: Glorp Meadow
const GLORP_SPOTS := [Vector2(-58, -122), Vector2(-62, -117), Vector2(-54, -118), Vector2(-59, -126)]
const FIELD := Vector2(80, -218)               # x, z: the Static Field (the crack in the middle)
const FIZZLER_SPOTS := [Vector2(76, -222), Vector2(84, -214), Vector2(78, -210), Vector2(86, -224), Vector2(72, -226)]
const WOODS := Vector2(-108, -124)             # x, z: where the shadow ghosts come out at night
const GHOST_SPOTS := [Vector2(-112, -112), Vector2(-116, -108), Vector2(-104, -138), Vector2(-96, -132),
	Vector2(-108, -128), Vector2(-120, -116)]
const GHOST_CHECK := 2.0                       # seconds between looks at whether it's dark yet

var _ghost_t := 0.0
var _ghost_night := -1                         # the Void day whose night's ghosts are out (-1: none out)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _town() -> Node3D:
	var scene := get_tree().current_scene as Node3D
	return scene if scene != null and scene.scene_file_path == TOWN else null


func _on_scene_changed() -> void:
	_ghost_night = -1
	var scene := _town()
	if scene == null or scene.get_node_or_null("Glorp Meadow") != null:
		return
	_place_meadow(scene)
	_place_field(scene)
	var woods := Node3D.new()
	woods.name = "Night Ghosts"
	scene.add_child(woods)
	_ghost_t = 0.0


func _ground(scene: Node3D, at: Vector2) -> Vector3:
	return Bosses.ground(scene, at.x, at.y)


func _landmark(scene: Node3D, name: String, at: Vector2) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.set_script(load("res://scripts/landmark.gd"))
	n.set("label", name)
	scene.add_child(n)
	n.global_position = _ground(scene, at)
	return n


# -----------------------------------------------------------------------------
# Glorp Meadow
# -----------------------------------------------------------------------------
func _place_meadow(scene: Node3D) -> void:
	var meadow := _landmark(scene, "Glorp Meadow", MEADOW)
	var i := 0
	for at in GLORP_SPOTS:
		i += 1
		var g := GLORP.make(1.5)
		g.name = "Glorp %d" % i
		g.set("wander_radius", 5.0)
		g.position = _ground(scene, at) + Vector3(0, 0.3, 0) - meadow.global_position   # (before it's in: its home is where it starts)
		meadow.add_child(g)
	# A few purple puddles, so the meadow looks like Glorps live there
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.3, 0.8, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	for k in 5:
		var p := MeshInstance3D.new()
		p.name = "Glorp Puddle"
		var cm := CylinderMesh.new()
		cm.top_radius = randf_range(0.5, 1.0)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.04
		p.mesh = cm
		p.material_override = m
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		meadow.add_child(p)
		var a := k * TAU / 5.0 + 0.4
		p.global_position = _ground(scene, MEADOW + Vector2(cos(a), sin(a)) * 6.5) + Vector3(0, 0.03, 0)


# -----------------------------------------------------------------------------
# The Static Field
# -----------------------------------------------------------------------------
func _place_field(scene: Node3D) -> void:
	var field := _landmark(scene, "Static Field", FIELD)
	_crack(field)
	var i := 0
	for at in FIZZLER_SPOTS:
		i += 1
		var f := FIZZLER.new() as CharacterBody3D
		f.name = "Fizzler %d" % i
		f.position = _ground(scene, at) - field.global_position
		field.add_child(f)


func _crack(field: Node3D) -> void:
	# A jagged crack in the ground, glowing and fizzing (the town only ever calls them "the cracks")
	var crack := Node3D.new()
	crack.name = "Fizzing Crack"
	field.add_child(crack)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.05, 0.18)
	m.emission_enabled = true
	m.emission = FIZZLER.STATIC
	m.emission_energy_multiplier = 1.8
	var pts := [Vector2(-4.0, -0.6), Vector2(-2.2, 0.5), Vector2(-0.6, -0.4), Vector2(0.8, 0.6), Vector2(2.4, -0.3),
		Vector2(4.0, 0.4)]
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28 - 0.03 * absf(k - 2.0), 0.05, a.distance_to(b) + 0.2)
		seg.mesh = bm
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		crack.add_child(seg)
		var mid := (a + b) * 0.5
		seg.position = Vector3(mid.x, 0.03, mid.y)
		seg.rotation.y = atan2(b.x - a.x, b.y - a.y)
	var sparks := CPUParticles3D.new()
	sparks.name = "Static Sparks"
	sparks.amount = 18
	sparks.lifetime = 0.8
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(4.0, 0.05, 0.4)
	sparks.direction = Vector3.UP
	sparks.spread = 30.0
	sparks.initial_velocity_min = 0.8
	sparks.initial_velocity_max = 2.0
	sparks.gravity = Vector3.ZERO
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	var spm := StandardMaterial3D.new()
	spm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spm.albedo_color = FIZZLER.STATIC
	sm.material = spm
	sparks.mesh = sm
	crack.add_child(sparks)


# -----------------------------------------------------------------------------
# Shadow ghosts in the Spooky Woods at night
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	_ghost_t -= delta
	if _ghost_t > 0.0:
		return
	_ghost_t = GHOST_CHECK
	var scene := _town()
	if scene == null:
		return
	var holder := scene.get_node_or_null("Night Ghosts") as Node3D
	if holder == null:
		return
	if Clock.is_night():
		# A new lot each night (the night belongs to the day it started on; just after midnight counts as last night)
		var night := Clock.day if Clock.hour() >= 12 else Clock.day - 1
		if night != _ghost_night:
			_ghost_night = night
			ghosts_out(scene, holder)
	elif holder.get_child_count() > 0:
		_ghost_night = -1
		ghosts_away(holder)


func ghosts_out(scene: Node3D, holder: Node3D) -> void:
	for c in holder.get_children():
		c.queue_free()
	var i := 0
	for at in GHOST_SPOTS:
		i += 1
		var g := SHADOW_GHOST.new() as CharacterBody3D
		g.name = "Night Ghost %d" % i
		g.set("wander_radius", 6.0)
		g.set("sight_range", 10.0)
		g.set("leash_range", 20.0)
		g.position = _ground(scene, at) - holder.global_position
		holder.add_child(g)


func ghosts_away(holder: Node3D) -> void:
	# Sunrise: they fade into the morning
	for g in holder.get_children():
		if g is Node3D and not bool(g.get("defeated")):
			var v := g.get("visual") as Node3D
			if v:
				var tw := (g as Node).create_tween()
				tw.tween_property(v, "scale", Vector3.ONE * 0.01, 0.8)
				tw.tween_callback((g as Node).queue_free)
				continue
		(g as Node).queue_free()


func ghosts_now() -> int:
	var scene := _town()
	var holder := scene.get_node_or_null("Night Ghosts") if scene else null
	if holder == null:
		return 0
	return holder.get_children().filter(func(n: Node) -> bool: return not bool(n.get("defeated")) \
		and not n.is_queued_for_deletion()).size()
