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
const FALLS_MUSEUM := preload("res://scripts/falls_museum.gd")
const DUSK_GATE := preload("res://scripts/dusk_gate.gd")
const STATIC_BATCH := preload("res://scripts/static_batch.gd")
const DETAIL_PROPS := preload("res://scripts/detail_props.gd")
const TOWN_OCCLUDERS := preload("res://scripts/town_occluders.gd")
const MESH_LODS := preload("res://scripts/mesh_lods.gd")
const INSIDES := preload("res://scripts/insides.gd")
const WORLD_LIGHT := preload("res://scripts/world_light.gd")
const FIRE := preload("res://scripts/fire_fx.gd")
const COSMIC := preload("res://scripts/cosmic_dust.gd")

const MIN_SPAN := 10.0          # a ground mesh is at least this wide both ways...
const FLAT := 0.4               # ...and no taller than this much of its narrower side
const NOT_GROUND := ["water", "lake", "sea", "pond", "pool", "goo", "slime", "lava", "cloud", "glass", "mist", "fog",
	"sky", "ice sheet", "beam", "light", "glow", "shadow", "paint", "road", "track", "rail", "roof", "trim", "wall",
	"partition", "gazebo", "dome", "stand", "tunnel", "white"]

var enabled := true             # tests can switch the whole pass off
var batching := true            # merge still builder pieces in every place (scripts/static_batch.gd)
var detail_props := true        # the baked detailed props on the town green (scripts/detail_props.gd)
var lods := true                # distance LODs for big meshes made in code (scripts/mesh_lods.gd)
var plant_shadows := false      # ferns and grass cast no shadows (their shadows were 60% of the Void's triangles)
var lighting := true           # the lighting levels' SSAO, haze and bounced light (scripts/world_light.gd, Settings.lighting)
var insides := true            # Stars Hollow's plain buildings become rooms you walk into (scripts/insides.gd)
var fire := true                # moving pixel flames on every torch, lamp, candle and bonfire (scripts/fire_fx.gd)
var last_fire := 0              # how many flames the last place got
var cosmic := true              # cosmic dust floating in the air (scripts/cosmic_dust.gd)
var occluders := true           # invisible boxes in Stars Hollow's buildings for occlusion culling (town_occluders.gd)
const SMALL_PLANTS := ["Ferns", "Grass"]   # the plant patches (scenes/town/foliage.gd) whose shadows are left out
const LATER_BATCH := [1.0, 2.0]          # waits in turn (1 s, then 3 s after it loads) to merge what was put in since
var last_batch := {}            # what the last merge did (tests read it)
var last_props := {}            # and what detailed props went in
var last_nature := {}           # and which trees and plants got their baked shapes (detail_props.gd dress_nature)
var last_surfaces := {}         # and which walls and roofs got baked siding, shingles... (dress_buildings)
var _last: Node
var _cache := {}                # source material -> its detailed ShaderMaterial


func _ready() -> void:
	# Flames put in after a place is dressed (a beacon lit, a stone flaring) get theirs as they arrive.
	get_tree().node_added.connect(_on_added)


func _on_added(node: Node) -> void:
	if fire and enabled and node is Node3D and (node.name == "Flame" or node is MeshInstance3D):
		_fire_later.call_deferred(node.get_instance_id())


func _fire_later(id: int) -> void:
	# By id, since a piece can be freed again before the frame's out.
	var node := instance_from_id(id) as Node
	if node:
		FIRE.check(node)


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
		FALLS_MUSEUM.place(scene)          # before the falls, so they see it where it ends up
		FALLS.dress_void(scene)
	elif path == "res://scenes/school/school.tscn":
		MOUNTAINS.dress(scene)
	elif path == "res://scenes/earth/earth.tscn":
		FALLS.dress_earth(scene)
	elif path == "res://scenes/portal_worlds/rhythm_springs.tscn":
		FALLS.dress_rhythm(scene)
	detail_ground(scene)
	if lighting:
		WORLD_LIGHT.place(scene)
	if path == "res://scenes/earth/earth.tscn" and insides:
		INSIDES.dress_earth(scene)
	if path == "res://scenes/earth/earth.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_earth(scene)
	elif path == "res://scenes/town/town.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_void(scene)
	elif path == "res://scenes/portal_worlds/rhythm_springs.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_rhythm(scene)
	elif path == "res://scenes/portal_worlds/glenmoor.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_glenmoor(scene)
	elif path == "res://scenes/portal_worlds/tide_reef.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_tide_reef(scene)
	elif path == "res://scenes/portal_worlds/dark_hollow.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_dark_hollow(scene)
	elif path == "res://scenes/portal_worlds/lanternmoor.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_lanternmoor(scene)
	elif path == "res://scenes/portal_worlds/frozen_moment.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_frozen_moment(scene)
	elif path == "res://scenes/portal_worlds/far_future.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_far_future(scene)
	elif path == "res://scenes/portal_worlds/shard_isle.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_shard_isle(scene)
	elif path == "res://scenes/bosses/gloop_kingdom.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_gloop_kingdom(scene)
	elif path == "res://scenes/portal_worlds/rootmind.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_rootmind(scene)
	elif path == "res://scenes/secret_garden/secret_garden.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_secret_garden(scene)
	elif path == "res://scenes/bosses/arena.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_star_arena(scene)
	elif path == "res://scenes/bosses/clock_tower.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_clock_tower(scene)
	elif path == "res://scenes/bosses/boulder_canyon.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_boulder_canyon(scene)
	elif path == "res://scenes/bosses/skyreach_trail.tscn" and detail_props:
		last_props = DETAIL_PROPS.dress_skyreach(scene)
	if detail_props:
		last_nature = DETAIL_PROPS.dress_nature(scene)
		last_surfaces = DETAIL_PROPS.dress_buildings(scene)
	if fire:
		last_fire = FIRE.dress(scene)
	if cosmic:
		COSMIC.place(scene, 0.0 if Settings.reduce_motion else 1.0)
	if batching:
		last_batch = STATIC_BATCH.batch(scene)
	if lods:
		MESH_LODS.on(scene).scan(scene)
	if not plant_shadows:
		small_plants_unshadowed(scene)
	if batching or lods:
		_batch_later(scene)
	if path == "res://scenes/earth/earth.tscn":
		if occluders and scene is Node3D and scene.get_node_or_null("Town Occluders") == null:
			var occ := TOWN_OCCLUDERS.new()
			occ.name = "Town Occluders"
			scene.add_child(occ)


func small_plants_unshadowed(scene: Node) -> int:
	# Big games don't let grass and little plants cast shadows: there are thousands of them, each shadow is drawn
	# again for every split of the sun's shadow map, and on the ground under them nobody can tell. Measured in the
	# Void on 16 Nov 2026 the ferns' and grass's shadows were 8.6M of the 14.4M triangles drawn a frame. The giant
	# leaves, mushrooms and trees keep theirs. Returns how many were changed (tests read it).
	var n := 0
	for node in scene.find_children("*", "MultiMeshInstance3D", true, false):
		if String(node.name) in SMALL_PLANTS:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n += 1
	return n


func _batch_later(scene: Node) -> void:
	# Some places are dressed a moment after they load (the Gloop Gate's view, the boss lairs' doors, the wilds, a
	# world's own setup): merge those pieces too once they're in. Anything that moves later is put back by the
	# scene's Batch Watch (scripts/batch_watch.gd).
	for wait in LATER_BATCH:
		await get_tree().create_timer(wait, false).timeout
		if not is_instance_valid(scene) or scene != get_tree().current_scene:
			return
		if batching:
			var more: Dictionary = STATIC_BATCH.batch(scene)
			for k in more:
				last_batch[k] = int(last_batch.get(k, 0)) + int(more[k])
		if lods:
			MESH_LODS.on(scene).scan(scene)


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
