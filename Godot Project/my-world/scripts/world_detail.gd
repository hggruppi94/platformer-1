extends Node

# WorldDetail (autoload): the 14 Nov 2026 look pass (Hayden: "Im a little concerned with the current state of the
# ground. It's just a flat color and I'd like it to have more detail, that goes for everywhere in the game", "The
# mountains are just upside-down cones", "put little secret coves behind all the waterfalls, and make them much larger
# and more impressive", "Dusk's embrace entrance needs to be in a spot that makes more sense").
#
# Every time a new place loads it's looked over once, at play time, so no built scene had to change:
#   - every big flat ground mesh gets scripts/ground_detail.gdshader in place of its plain colour (ground_meshes())
#   - in the Void and from the school's window: the cone mountains become jagged icy ones (scripts/alien_mountains.gd)
#   - the waterfalls (the Void's four, Stars Hollow's Mossy Falls, Rhythm Springs' mesa) become big ones with a secret
#     cove behind each (scripts/big_falls.gd)
#   - the gate to Dusk's Embrace moves behind the Haunted House (scripts/dusk_gate.gd)
# Portal previews (a world copied into a crack's window) are left alone: they aren't the current scene.

const GROUND_SHADER := preload("res://scripts/ground_detail.gdshader")
const MOUNTAINS := preload("res://scripts/alien_mountains.gd")
const FALLS := preload("res://scripts/big_falls.gd")
const DUSK_GATE := preload("res://scripts/dusk_gate.gd")
const STATIC_BATCH := preload("res://scripts/static_batch.gd")
const DETAIL_PROPS := preload("res://scripts/detail_props.gd")
const TOWN_OCCLUDERS := preload("res://scripts/town_occluders.gd")

const MIN_SPAN := 10.0          # a ground mesh is at least this wide both ways...
const FLAT := 0.4               # ...and no taller than this much of its narrower side
const NOT_GROUND := ["water", "lake", "sea", "pond", "pool", "goo", "slime", "lava", "cloud", "glass", "mist", "fog",
	"sky", "ice sheet", "beam", "light", "glow", "shadow", "paint", "road", "track", "rail", "roof", "trim", "wall",
	"partition", "gazebo", "dome", "stand", "tunnel", "white"]

var enabled := true             # tests can switch the whole pass off
var batching := true            # merge still builder pieces in Stars Hollow (scripts/static_batch.gd)
var detail_props := true        # the baked detailed props on the town green (scripts/detail_props.gd)
var occluders := true           # invisible boxes in Stars Hollow's buildings for occlusion culling (town_occluders.gd)
var last_batch := {}            # what the last merge did (tests read it)
var last_props := {}            # and what detailed props went in
var _last: Node
var _cache := {}                # source material -> its detailed ShaderMaterial


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s != _last:
		_last = s
		if s and enabled:
			_dress.call_deferred(s)


func _dress(scene: Node) -> void:
	if not is_instance_valid(scene) or scene != get_tree().current_scene:
		return
	var path := scene.scene_file_path
	if path == "res://scenes/town/town.tscn":
		MOUNTAINS.dress(scene)
		DUSK_GATE.move(scene)
		FALLS.dress_void(scene)
	elif path == "res://scenes/school/school.tscn":
		MOUNTAINS.dress(scene)
	elif path == "res://scenes/earth/earth.tscn":
		FALLS.dress_earth(scene)
	elif path == "res://scenes/portal_worlds/rhythm_springs.tscn":
		FALLS.dress_rhythm(scene)
	detail_ground(scene)
	if path == "res://scenes/earth/earth.tscn":
		if detail_props:
			last_props = DETAIL_PROPS.dress_earth(scene)
		if batching:
			last_batch = STATIC_BATCH.batch(scene)
		if occluders and scene is Node3D and scene.get_node_or_null("Town Occluders") == null:
			var occ := TOWN_OCCLUDERS.new()
			occ.name = "Town Occluders"
			scene.add_child(occ)


func detail_ground(scene: Node) -> int:
	# Puts the ground shader on every big flat ground mesh in the scene. Returns how many it changed (tests read it).
	var alien := _alien(scene)
	var n := 0
	for mi in ground_meshes(scene):
		var src := _source_material(mi)
		if src == null:
			continue
		mi.material_override = _detailed(src, alien)
		mi.set_meta("ground_detail", true)
		n += 1
	return n


static func ground_meshes(scene: Node) -> Array:
	# Big, flat, plain-coloured meshes: the ground, fields, floors, plazas. Not water, glass, glowing or see-through
	# things, nothing textured or with a shader of its own, nothing in a portal's preview window.
	var out := []
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_inside_tree() or mi.has_meta("ground_detail"):
			continue
		if _in_preview(mi, scene):
			continue
		var low := String(mi.name).to_lower()
		var skip := false
		for w in NOT_GROUND:
			if low.contains(w):
				skip = true
				break
		if skip:
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		var narrow := minf(box.size.x, box.size.z)
		if narrow < MIN_SPAN or box.size.y > maxf(2.5, narrow * FLAT):
			continue
		var m := _source_material(mi)
		if m == null:
			continue
		out.append(mi)
	return out


static func _in_preview(mi: Node, scene: Node) -> bool:
	var p := mi.get_parent()
	while p and p != scene:
		if p is SubViewport or p.has_meta("preview"):
			return true
		p = p.get_parent()
	return false


static func _source_material(mi: MeshInstance3D) -> StandardMaterial3D:
	# The one plain StandardMaterial3D it's drawn with, if that's all it has
	var m: Material = mi.material_override
	if m == null:
		if mi.mesh.get_surface_count() != 1:
			return null
		m = mi.get_surface_override_material(0)
		if m == null:
			m = mi.mesh.surface_get_material(0)
	var sm := m as StandardMaterial3D
	if sm == null:
		return null
	if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or sm.albedo_color.a < 0.99:
		return null
	if sm.emission_enabled or sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return null
	if sm.albedo_texture != null or sm.next_pass != null:
		return null
	var low := String(sm.resource_name).to_lower()
	for w in NOT_GROUND:
		if low.contains(w):
			return null
	return sm


func _detailed(src: StandardMaterial3D, alien: bool) -> ShaderMaterial:
	var key := [src, alien]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.resource_name = "Ground Detail"
	m.shader = _two_sided() if src.cull_mode == BaseMaterial3D.CULL_DISABLED else GROUND_SHADER
	m.set_shader_parameter("base", src.albedo_color)
	m.set_shader_parameter("use_vertex", src.vertex_color_use_as_albedo)
	m.set_shader_parameter("vertex_srgb", src.vertex_color_is_srgb)
	m.set_shader_parameter("roughness", src.roughness)
	m.set_shader_parameter("metallic", src.metallic)
	m.set_shader_parameter("glints", 1.0 if alien else 0.0)
	_cache[key] = m
	return m


var _two_sided_shader: Shader


func _two_sided() -> Shader:
	# The same shader drawn from both sides, for grounds whose own material was (Hayden's 14 Nov evening playtest:
	# with only front faces drawn, the school's floors could be seen through from the floor below)
	if _two_sided_shader == null:
		_two_sided_shader = Shader.new()
		_two_sided_shader.code = GROUND_SHADER.code.replace("shader_type spatial;", "shader_type spatial;\nrender_mode cull_disabled;")
	return _two_sided_shader


static func _alien(scene: Node) -> bool:
	# The Void and the portal worlds twinkle; Stars Hollow, its race circuit and the title screen don't
	var path := scene.scene_file_path
	return not (path.begins_with("res://scenes/earth/") or path.begins_with("res://scenes/title/")
		or path.contains("pumpkin_run"))
