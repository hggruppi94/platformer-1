extends Node

# Autoload "Paint": the spray paint the hero puts on walls, floors, rocks and roofs (scripts/spray_can.gd). Hayden's
# 14 Nov 2026 playtest: "spray painting that stays put until it is washed off, allowing the character to create any
# permanent design they want."
#
# Every puff of paint is a "dab": a little round splat stuck flat on a surface. Each place (scene) keeps its own dabs,
# saved in the save file ("paint"), so a design is still there next time she comes back, on any day, until she washes
# it off with water (the water drop on the palette, or holding Aim with the cans out).
# One MultiMeshInstance3D per place draws them all ("Paint Layer", added when the place loads), so thousands of dabs
# cost about as much as one mesh. A dab on top of another sits a hair further out from the wall (its "lift"), so the
# newest paint always shows. Painting over the same spot again recolours the dab that's there instead of adding one,
# so a place never fills up from going over and over; at MAX_DABS it says it's full until some's washed off.
# Only things that never move take paint (StaticBody3D, CSG, GridMap): not people, rides, doors or moving platforms.

signal changed                            # paint added or washed off here

const STRIDE := 10                        # x, y, z (the spot on the surface), nx, ny, nz, colour, size, spin, lift
const MAX_DABS := 9000                    # per place
const CELL := 1.0                         # metres: the grid used to find dabs near a spot
const LIFT := 0.012                       # how far out from the surface the first coat sits
const LIFT_STEP := 0.0008                 # each coat on top a little further
const LIFT_MAX := 0.04
const SAME_SPOT := 0.2                    # a new dab this close (times its size) to one the same size recolours it
const CHUNK := 512                        # the MultiMesh grows this many at a time
const TEMPORARY := ["made_thing", "frost_ice", "ice"]   # groups of solid things that only last a while (no paint)
const NOT_PAINT := ["WorldBounds", "Edge", "Fence", "Garden Wall"]   # invisible walls round the worlds (as wall_crawl.gd)
# The palette (spray_can.gd shows it). The water drop after the last one washes.
const COLOURS := [
	Color(0.95, 0.22, 0.3),    # red
	Color(1.0, 0.55, 0.15),    # orange
	Color(1.0, 0.88, 0.2),     # yellow
	Color(0.35, 0.85, 0.3),    # green
	Color(0.2, 0.8, 0.9),      # sky blue
	Color(0.28, 0.38, 0.95),   # blue
	Color(0.62, 0.35, 0.95),   # purple
	Color(1.0, 0.5, 0.8),      # pink
	Color(0.97, 0.97, 0.95),   # white
	Color(0.12, 0.1, 0.14),    # black
]

var places := {}                          # scene path -> PackedFloat32Array of dabs (STRIDE floats each)
var place := ""                           # the place loaded now ("" where there's nowhere to paint)
var layer: MultiMeshInstance3D
var _grid := {}                           # Vector3i cell -> Array of dab numbers, for this place
var _material: StandardMaterial3D


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	# The cans are sold at the Toy Shop in Stars Hollow and the Void's Toys stall (shop/items.json, kind "spray")
	Shop.register_kind("spray", {"can_buy": func(_it: Dictionary) -> String:
			return "You have some" if Game.has_item("spray_can") else "",
		"buy": func(_it: Dictionary) -> String:
			Game.give_item("spray_can")
			Tips.show_tip("spray")
			return "Spray paint! %s to get the cans out." % Settings.prompt("spray"),
		"button": "Get it!"})


func _on_scene_changed() -> void:
	layer = null
	place = ""
	_grid.clear()
	var scene := get_tree().current_scene
	if not scene is Node3D or scene.scene_file_path == "":
		return
	place = scene.scene_file_path
	layer = MultiMeshInstance3D.new()
	layer.name = "Paint Layer"
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.material_override = material()
	scene.add_child(layer)
	_rebuild()


# ----------------------------------------------------------------------------- painting
func count(where := "") -> int:
	var d: PackedFloat32Array = places.get(where if where != "" else place, PackedFloat32Array())
	return d.size() / STRIDE


func full() -> bool:
	return count() >= MAX_DABS


func dab(at: Vector3, normal: Vector3, colour: int, size: float, spin := 0.0) -> bool:
	# One splat of paint on the surface at `at` facing `normal`. False if there's nowhere to paint or it's full.
	if layer == null or not is_instance_valid(layer) or normal.length() < 0.1:
		return false
	normal = normal.normalized()
	colour = clampi(colour, 0, COLOURS.size() - 1)
	var d: PackedFloat32Array = places.get(place, PackedFloat32Array())
	var top := 0.0
	var same := -1
	var same_d := INF
	var near := _near(at, size * 1.2)
	for i in near:
		var o: int = i * STRIDE
		var nn := Vector3(d[o + 3], d[o + 4], d[o + 5])
		if nn.dot(normal) < 0.6:
			continue                       # round a corner: not on top of each other
		var p := Vector3(d[o], d[o + 1], d[o + 2])
		var gap := p.distance_to(at)
		if gap > (size + d[o + 7]) * 0.5:
			continue                       # not touching
		top = maxf(top, d[o + 9])
		if gap < size * SAME_SPOT and d[o + 7] < size * 1.4 and gap < same_d:
			same = i
			same_d = gap
	var lift := LIFT if top <= 0.0 else top + LIFT_STEP
	if lift > LIFT_MAX:
		_settle(near)                      # squash that pile of coats back down (keeping their order)
		d = places[place]
		top = 0.0
		for i in near:
			top = maxf(top, d[i * STRIDE + 9])
		lift = minf(top + LIFT_STEP, LIFT_MAX)
	var row := PackedFloat32Array([at.x, at.y, at.z, normal.x, normal.y, normal.z, colour, size, spin, lift])
	var i := same
	if i < 0:
		if count() >= MAX_DABS:
			return false
		i = d.size() / STRIDE
		d.append_array(row)
		_grid_add(i, at)
	else:
		for k in STRIDE:
			d[i * STRIDE + k] = row[k]
	places[place] = d
	_show(i, d)
	changed.emit()
	return true


func wash(at: Vector3, radius: float) -> int:
	# Water washes off every dab within `radius` of `at`. Returns how many came off.
	if layer == null or place == "":
		return 0
	var d: PackedFloat32Array = places.get(place, PackedFloat32Array())
	var gone := {}
	for i in _near(at, radius):
		var o: int = i * STRIDE
		if Vector3(d[o], d[o + 1], d[o + 2]).distance_to(at) <= radius + d[o + 7] * 0.3:
			gone[i] = true
	if gone.is_empty():
		return 0
	var kept := PackedFloat32Array()
	var n := d.size() / STRIDE
	for i in n:
		if not gone.has(i):
			kept.append_array(d.slice(i * STRIDE, i * STRIDE + STRIDE))
	if kept.is_empty():
		places.erase(place)
	else:
		places[place] = kept
	_rebuild()
	changed.emit()
	return gone.size()


func wash_all(where := "") -> void:
	# Every dab in a place gone (tests; nothing in the game washes a whole place at once)
	places.erase(where if where != "" else place)
	if where == "" or where == place:
		_rebuild()
	changed.emit()


func colour_at(at: Vector3, reach := 0.2) -> int:
	# The colour of the top dab at a spot, or -1 (tests read it)
	var d: PackedFloat32Array = places.get(place, PackedFloat32Array())
	var best := -1
	var top := -1.0
	for i in _near(at, reach + 0.5):
		var o: int = i * STRIDE
		if Vector3(d[o], d[o + 1], d[o + 2]).distance_to(at) <= reach + d[o + 7] * 0.5 and d[o + 9] > top:
			top = d[o + 9]
			best = int(d[o + 6])
	return best


static func paintable(collider: Object, at = null) -> bool:
	# Only things that stay put and can be seen: the ground, walls, rocks, roofs. Not anyone or anything that moves,
	# nothing that's only there for a while (Make's bridges, frost's ice floes), and not the invisible walls round the
	# edge of a world. Given the spot (`at`), something needs a mesh that reaches it to count as seen.
	if collider == null or not is_instance_valid(collider):
		return false
	if collider is AnimatableBody3D:
		return false
	if not (collider is StaticBody3D or collider is CSGShape3D or collider is GridMap):
		return false
	var n := collider as Node
	for g in TEMPORARY:
		if n.is_in_group(g):
			return false
	var up := n
	for i in 3:
		if up == null:
			break
		if up.is_in_group("no_paint") or up.is_in_group("no_climb"):
			return false
		for bit in NOT_PAINT:
			if String(up.name).begins_with(bit):
				return false
		up = up.get_parent()
	if collider is CSGShape3D or collider is GridMap or at == null:
		return true
	return seen(n, at as Vector3)


static func seen(body: Node, at: Vector3) -> bool:
	# A mesh near the body (under it, over it, or beside it under the same parent) that reaches the spot
	var looks: Array[Node] = []
	looks.append_array(body.find_children("*", "GeometryInstance3D", true, false))
	var parent := body.get_parent()
	if parent is GeometryInstance3D:
		looks.append(parent)
	if parent and parent.get_child_count() < 400:
		for c in parent.get_children():
			if c is GeometryInstance3D:
				looks.append(c)
			elif c is Node3D and c != body and c.get_child_count() < 40:
				for cc in c.get_children():
					if cc is GeometryInstance3D:
						looks.append(cc)
	for g in looks:
		var gi := g as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi is MultiMeshInstance3D and gi.name == "Paint Layer":
			continue
		var box := gi.global_transform * gi.get_aabb()
		if box.grow(0.3).has_point(at):
			return true
	return false


# ----------------------------------------------------------------------------- drawing
func material() -> StandardMaterial3D:
	if _material:
		return _material
	_material = StandardMaterial3D.new()
	_material.albedo_texture = splat_texture()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true      # COLOURS are picked in sRGB (otherwise every colour comes out pale)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.roughness = 1.0
	_material.metallic_specular = 0.05         # matt: no shine washing the colours out when seen low along the ground
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR      # (mipmaps fade thin lines away in the distance)
	return _material


static func splat_texture() -> ImageTexture:
	# A round blob of spray paint with a speckled edge (alpha-scissored, so no sorting trouble with thousands)
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1414
	var wobble := []
	for k in 16:
		wobble.append(rng.randf_range(-0.035, 0.035))
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / n - Vector2(0.5, 0.5)
			var ang := fposmod(p.angle(), TAU) / TAU * 16.0
			var k0 := int(ang) % 16
			var edge := 0.4 + lerpf(wobble[k0], wobble[(k0 + 1) % 16], ang - floorf(ang))
			var r := p.length()
			var a := clampf((edge - r) * 30.0 + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	# a few fine speckles round the outside, like a real can
	for k in 26:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.42, 0.49)
		var c := (Vector2(cos(ang), sin(ang)) * r + Vector2(0.5, 0.5)) * n
		var rad := rng.randf_range(0.8, 1.8)
		for y in range(maxi(0, int(c.y - 3)), mini(n, int(c.y + 3))):
			for x in range(maxi(0, int(c.x - 3)), mini(n, int(c.x + 3))):
				if Vector2(x + 0.5, y + 0.5).distance_to(c) < rad:
					img.set_pixel(x, y, Color(1, 1, 1, 1))

	return ImageTexture.create_from_image(img)


func _mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE                    # faces +Z; each dab's transform turns and sizes it
	return q


func _rebuild() -> void:
	_grid.clear()
	if layer == null or not is_instance_valid(layer):
		return
	var d: PackedFloat32Array = places.get(place, PackedFloat32Array())
	var n := d.size() / STRIDE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh()
	mm.instance_count = maxi(CHUNK, ceili(float(n + 1) / CHUNK) * CHUNK)
	mm.visible_instance_count = n
	layer.multimesh = mm
	for i in n:
		_grid_add(i, Vector3(d[i * STRIDE], d[i * STRIDE + 1], d[i * STRIDE + 2]))
		_put(mm, i, d)


func _show(i: int, d: PackedFloat32Array) -> void:
	var mm := layer.multimesh
	var n := d.size() / STRIDE
	if mm == null or n > mm.instance_count:
		_rebuild()                          # (grows by a chunk)
		return
	mm.visible_instance_count = n
	_put(mm, i, d)


static func dab_transform(d: PackedFloat32Array, i: int) -> Transform3D:
	var o: int = i * STRIDE
	var at := Vector3(d[o], d[o + 1], d[o + 2])
	var z := Vector3(d[o + 3], d[o + 4], d[o + 5]).normalized()
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var b := Basis(x, y, z).rotated(z, d[o + 8]).scaled(Vector3.ONE * d[o + 7])
	return Transform3D(b, at + z * d[o + 9])


func _put(mm: MultiMesh, i: int, d: PackedFloat32Array) -> void:
	mm.set_instance_transform(i, dab_transform(d, i))
	mm.set_instance_color(i, COLOURS[clampi(int(d[i * STRIDE + 6]), 0, COLOURS.size() - 1)])


func _settle(near: Array) -> void:
	# Halve how far out the coats round here sit, keeping which is on top
	var d: PackedFloat32Array = places[place]
	for i in near:
		var o: int = i * STRIDE + 9
		d[o] = LIFT + (d[o] - LIFT) * 0.5
	places[place] = d
	for i in near:
		_put(layer.multimesh, i, d)


func _cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


func _grid_add(i: int, p: Vector3) -> void:
	var c := _cell(p)
	if not _grid.has(c):
		_grid[c] = []
	(_grid[c] as Array).append(i)


func _near(p: Vector3, r: float) -> Array:
	var out := []
	var lo := _cell(p - Vector3.ONE * r)
	var hi := _cell(p + Vector3.ONE * r)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				var c := Vector3i(x, y, z)
				if _grid.has(c):
					out.append_array(_grid[c])
	return out


# ----------------------------------------------------------------------------- saving
func save_data() -> Dictionary:
	var out := {}
	for k in places:
		var d: PackedFloat32Array = places[k]
		if not d.is_empty():
			out[k] = Marshalls.raw_to_base64(d.to_byte_array())
	return {"places": out}


func load_data(data: Dictionary) -> void:
	places.clear()
	var got = data.get("places", {})
	if got is Dictionary:
		for k in got:
			var d := Marshalls.base64_to_raw(str(got[k])).to_float32_array()
			if d.size() >= STRIDE:
				places[str(k)] = d.slice(0, d.size() - d.size() % STRIDE)
	_rebuild()


func reset() -> void:
	places.clear()
	_rebuild()
