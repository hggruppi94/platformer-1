extends Node

# Autoload "TownMap": the town map. M (or LB on a controller; rebindable) opens it full screen: the town from above
# (res://ui/town_map.png, drawn from the real town by tools/make_map.gd), labelled by district and building, with an
# arrow for Nina and which way she's facing, a star on where the current quest steps want her, everyone's spot
# (or their home, when they're tucked up inside) and, in the Shift, the open portal.
# A small corner minimap can be switched on in Settings > Display.
#
# Markers for quests come from the quest spots that are open right now (scripts/quest_spot.gd) and from a step's
# "where" in res://quests/<id>.json: people (a character id) or places (a point in res://routines/places.json), each
# optionally {"who": "dash", "unless": "asked_dash"} to drop off once done.

const MAP_TEXTURE := "res://ui/town_map.png"
const MAP_INFO := "res://ui/town_map.json"
const TOWN := "res://scenes/town/town.tscn"
const MINI_SIZE := 220.0
const MINI_METRES := 70.0                           # how much of the town the minimap shows across

# Districts (big labels), at fixed spots; buildings (small labels) are looked up in the town by name
const DISTRICTS := [["Market Square", Vector2(-72, 30)], ["Homes", Vector2(80, 20)], ["Castle & School", Vector2(15, -205)],
	["Secret Gardens", Vector2(-78, -60)], ["Observatory Hill", Vector2(105, -104)], ["Sports & Play", Vector2(66, 74)],
	["Spooky Woods", Vector2(-118, -146)], ["The Lake", Vector2(4, 8)]]
const BUILDINGS := ["Town Hall", "Library", "Museum", "Aquarium", "Potion Shop", "Cafe", "Clothing Boutique", "Book Store",
	"Pet Shop", "Restaurant & Cafe", "Gaming Station", "My House", "Nina's House", "Dash's House", "Melanie's House", "Observatory",
	"Haunted House", "Tree House", "Skate Park", "Magic Bubble Bath", "Portal to Earth"]

var _texture: Texture2D
var _center := Vector2(-8, -32)
var _size_m := 300.0
var _layer: CanvasLayer
var _map: TextureRect
var _overlay: Control
var _mini_layer: CanvasLayer
var _mini: Control
var _mini_tex: TextureRect
var _mini_overlay: Control
var _font: Font
var _time := 0.0
var _placed: Array[Rect2] = []                       # labels already drawn on the big map (so they don't overlap)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS                # the map works while the game is paused under it
	_font = ThemeDB.fallback_font
	_texture = load(MAP_TEXTURE) as Texture2D
	var info = JSON.parse_string(FileAccess.get_file_as_string(MAP_INFO)) if FileAccess.file_exists(MAP_INFO) else null
	if info is Dictionary:
		_center = Vector2(float(info.center[0]), float(info.center[1]))
		_size_m = float(info.size_m)
	_build()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


# -----------------------------------------------------------------------------
# Where things are on the map (0..1 across and down)
# -----------------------------------------------------------------------------
func to_map(world: Vector3) -> Vector2:
	return Vector2((world.x - _center.x) / _size_m + 0.5, (world.z - _center.y) / _size_m + 0.5)


func in_town() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == TOWN


func nina() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func nina_facing() -> float:
	# Her model's yaw (it faces +Z): the direction she's looking, on the map
	var p := nina()
	if p == null or not p.has_node("Visual"):
		return 0.0
	return (p.get_node("Visual") as Node3D).global_rotation.y


func people() -> Array:
	# [{id, name, pos, home}] for everyone with a daily routine, plus Mr. Palmer at his window
	var out := []
	for r in get_tree().get_nodes_in_group("routines"):
		var body := r.get_parent() as Node3D
		var id := str(r.get("character_id"))
		var talk := body.get_node_or_null("Talk")
		var name := Quests.display_name(id, str(talk.get("display_name")) if talk else id.capitalize())
		out.append({"id": id, "name": name, "pos": body.global_position, "home": not r.call("is_present")})
	return out


func quest_markers() -> Array:
	# [{pos, label}] for every quest step that's ready to be done right now
	var out := []
	var s := get_tree().current_scene
	if s == null:
		return out
	for id in Quests._order:
		var step: Dictionary = Quests.current_step(id)
		if step.is_empty() or Quests.is_waiting(id):
			continue
		var name := str(Quests.quest(id).get("name", id))
		for spot in s.find_children("*", "Area3D", true, false):
			if spot.get("quest") == id and spot.has_method("is_open") and spot.call("is_open"):
				out.append({"pos": (spot as Node3D).global_position, "label": name})
		for w in step.get("where", []):
			var entry: Dictionary = w if w is Dictionary else ({"who": w} if _talker(s, str(w)) else {"place": w})
			if entry.has("unless") and Dialogue.flags.has(str(entry.unless)):
				continue
			var pos = null
			if entry.has("who"):
				var t := _talker(s, str(entry.who))
				if t:
					pos = (t.get_parent() as Node3D).global_position
			elif entry.has("place") and TownPaths.get_shared().has(str(entry.place)):
				var p2: Vector2 = TownPaths.get_shared().points[str(entry.place)]
				pos = Vector3(p2.x, 0, p2.y)
			if pos != null:
				out.append({"pos": pos, "label": name})
	return out


func _talker(s: Node, id: String) -> Node:
	for t in s.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func portal_open() -> bool:
	return Clock.in_shift()


# -----------------------------------------------------------------------------
# Opening and closing
# -----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		toggle()
	elif is_open() and event.is_action_pressed("ui_cancel"):     # (Pause closes it too: scripts/pause_menu.gd)
		get_viewport().set_input_as_handled()
		toggle()


func is_open() -> bool:
	return _layer.visible


func toggle() -> void:
	if not is_open() and (get_tree().paused or Dialogue.is_active()):
		return                                             # not over the pause menu, a bed, the quest log or a conversation
	_layer.visible = not _layer.visible
	get_tree().paused = _layer.visible
	if _layer.visible:
		Audio.play("ui_accept", -4.0, 0.0)
	_overlay.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if is_open():
		_overlay.queue_redraw()
	var show_mini := Settings.minimap and in_town() and not is_open() and not get_tree().paused and nina() != null
	_mini_layer.visible = show_mini
	if show_mini:
		var at := to_map(nina().global_position) * _mini_scale_px()
		_mini_tex.position = Vector2(MINI_SIZE, MINI_SIZE) / 2.0 - at
		_mini_overlay.queue_redraw()


func _mini_scale_px() -> float:
	return MINI_SIZE * _size_m / MINI_METRES             # the whole map's width in minimap pixels


# -----------------------------------------------------------------------------
# Drawing
# -----------------------------------------------------------------------------
func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 34
	_layer.visible = false
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.1, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	_map = TextureRect.new()
	_map.texture = _texture
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_map)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_full)
	_layer.add_child(_overlay)
	# The corner minimap
	_mini_layer = CanvasLayer.new()
	_mini_layer.layer = 5
	add_child(_mini_layer)
	_mini = Control.new()
	_mini.clip_contents = true
	_mini.custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini.offset_left = -MINI_SIZE - 16
	_mini.offset_top = -MINI_SIZE - 16
	_mini.offset_right = -16
	_mini.offset_bottom = -16
	_mini_layer.add_child(_mini)
	_mini_tex = TextureRect.new()
	_mini_tex.texture = _texture
	_mini_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_tex.size = Vector2.ONE * _mini_scale_px()
	_mini.add_child(_mini_tex)
	_mini_overlay = Control.new()
	_mini_overlay.size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_overlay.draw.connect(_draw_mini)
	_mini.add_child(_mini_overlay)


func _map_rect() -> Rect2:
	# Where the (square) picture sits on screen
	var vp := _overlay.size
	var side := minf(vp.x, vp.y)
	return Rect2((vp - Vector2(side, side)) / 2.0, Vector2(side, side))


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _text(c: Control, at: Vector2, s: String, size: int, color: Color, centered := true, nudge := false) -> void:
	# nudge: if it would cover a label already there, try just below or above it, or leave it out
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at - Vector2(w / 2.0 if centered else 0.0, -size * 0.35)
	if nudge:
		var found := false
		for dy in [0.0, size * 1.1, -size * 1.1, size * 2.2]:
			var rect := Rect2(pos + Vector2(0, dy - size), Vector2(w, size * 1.1))
			if not _placed.any(func(o: Rect2) -> bool: return o.intersects(rect)):
				pos.y += dy
				_placed.append(rect)
				found = true
				break
		if not found:
			return
	else:
		_placed.append(Rect2(pos - Vector2(0, size), Vector2(w, size * 1.1)))
	c.draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 4), Color(0.08, 0.04, 0.12, 0.95))
	c.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _arrow(c: Control, at: Vector2, yaw: float, size: float) -> void:
	# Nina: a pink arrow pointing the way she faces (+Z of her model; on the map +x is right and +z is down)
	var fwd := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([at + fwd * size, at - fwd * size * 0.6 + side * size * 0.7, at - fwd * size * 0.25,
		at - fwd * size * 0.6 - side * size * 0.7])
	c.draw_colored_polygon(pts, Color(1.0, 0.4, 0.6))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(1, 1, 1), 2.0)


func _star(c: Control, at: Vector2, r: float) -> void:
	var pulse := 1.0 + 0.15 * sin(_time * 5.0)
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		pts.append(at + Vector2(cos(a), sin(a)) * r * pulse * (1.0 if k % 2 == 0 else 0.45))
	c.draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(0.35, 0.2, 0.05), 2.0)


func _draw_full() -> void:
	var r := _map_rect()
	var c := _overlay
	var s := get_tree().current_scene
	var town_here := in_town()
	_placed.clear()
	_text(c, Vector2(r.position.x + r.size.x / 2, r.position.y + _fs(24)), "Galaxity", _fs(34), Color(1, 0.95, 0.75))
	for d in DISTRICTS:
		_text(c, r.position + to_map(Vector3(d[1].x, 0, d[1].y)) * r.size, d[0], _fs(24), Color(1, 1, 0.85))
	if town_here:
		for p in people():
			var at := r.position + to_map(p.pos) * r.size
			if p.home:
				c.draw_rect(Rect2(at - Vector2(5, 3), Vector2(10, 8)), Color(0.75, 0.85, 1.0))
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -3), at + Vector2(0, -9), at + Vector2(7, -3)]), Color(0.75, 0.85, 1.0))
				_text(c, at + Vector2(0, _fs(14)), "%s (home)" % p.name, _fs(13), Color(0.75, 0.85, 1.0), true, true)
			else:
				c.draw_circle(at, 6.0, Color(0.55, 0.9, 1.0))
				c.draw_arc(at, 6.0, 0, TAU, 16, Color(0.1, 0.2, 0.3), 1.5)
				_text(c, at + Vector2(0, -_fs(14)), p.name, _fs(14), Color(0.7, 0.95, 1.0), true, true)
		for b in BUILDINGS:
			var n := s.get_node_or_null(b) as Node3D
			if n:
				var at := r.position + to_map(n.global_position) * r.size
				c.draw_circle(at, 3.0, Color(1, 1, 1, 0.9))
				_text(c, at + Vector2(0, _fs(13)), b, _fs(14), Color(1, 1, 1, 0.95), true, true)
		if portal_open():
			var portal := s.get_node_or_null("Portal to Earth") as Node3D
			if portal:
				var at := r.position + to_map(portal.global_position) * r.size
				var glow := 0.6 + 0.4 * sin(_time * 4.0)
				c.draw_circle(at, 16.0, Color(0.6, 0.3, 1.0, 0.35 * glow))
				c.draw_arc(at, 12.0, 0, TAU, 32, Color(0.75, 0.5, 1.0), 4.0)
				_text(c, at + Vector2(0, -_fs(26)), "The portal is open!", _fs(18), Color(0.85, 0.7, 1.0))
		for q in quest_markers():
			_star(c, r.position + to_map(q.pos) * r.size, 13.0)
		var player := nina()
		if player:
			_arrow(c, r.position + to_map(player.global_position) * r.size, nina_facing(), 14.0)
	else:
		var where := "You're inside. Step outside to see where you are!"
		if s and s.scene_file_path == "res://scenes/scary_world/scary_world.tscn":
			where = "You're in the Scary World, behind the gate in the Spooky Woods. The gate behind you leads home."
			var gate := r.position + to_map(Vector3(-128, 0, -150)) * r.size
			_star(c, gate, 10.0)
		elif s and s.scene_file_path == "res://scenes/earth/earth.tscn":
			where = "You're on Earth, through the portal! The way home is the portal by the old oak."
			var portal := r.position + to_map(Vector3(36, 0, 13)) * r.size
			_star(c, portal, 10.0)
		_text(c, r.get_center(), where, _fs(22), Color(1, 0.95, 0.75))
	var legend := Dialogue.player_name() + "    ★ Quest    ● People    ⌂ Home    (%s to close)" % Settings.prompt("map")
	_text(c, Vector2(r.position.x + r.size.x / 2, r.end.y - _fs(18)), legend, _fs(16), Color(1, 1, 1, 0.85))


func _draw_mini() -> void:
	var c := _mini_overlay
	var scale := _mini_scale_px()
	var offset := _mini_tex.position
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)), Color(0.1, 0.06, 0.15), false, 3.0)
	for q in quest_markers():
		var at: Vector2 = offset + to_map(q.pos) * scale
		at = at.clamp(Vector2(10, 10), Vector2(MINI_SIZE - 10, MINI_SIZE - 10))   # off the edge: pinned to it
		_star(c, at, 8.0)
	for p in people():
		if not p.home:
			var at: Vector2 = offset + to_map(p.pos) * scale
			if Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)).has_point(at):
				c.draw_circle(at, 4.0, Color(0.55, 0.9, 1.0))
	_arrow(c, Vector2(MINI_SIZE, MINI_SIZE) / 2.0, nina_facing(), 10.0)


func _apply_settings() -> void:
	_overlay.queue_redraw()
