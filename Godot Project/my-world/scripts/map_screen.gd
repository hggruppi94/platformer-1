extends Node

# Autoload "TownMap": the town map. M (or LB on a controller; rebindable) opens it on the player menu's Map sheet
# (scripts/player_menu.gd), which Tab opens too: the town from above
# (res://ui/town_map.png, drawn from the real town by tools/make_map.gd), labelled by district and building, with an
# arrow for Nina and which way she's facing, a star on where the current quest steps want her, everyone's spot
# (or their home, when they're tucked up inside) and, in the Shift, the open portal.
# A small corner minimap can be switched on in Settings > Display.
#
# On Earth the map is drawn instead of pictured: the streets, buildings, the pond and creek, the hill and the park,
# from res://ui/earth_map.json (written by tools/build_earth.gd), with the same arrow, people and quest stars.
#
# Markers for quests come from the quest spots that are open right now (scripts/quest_spot.gd) and from a step's
# "where" in res://quests/<id>.json: people (a character id) or places (a point in res://routines/places.json), each
# optionally {"who": "dash", "unless": "asked_dash"} to drop off once done.

const MAP_TEXTURE := "res://ui/town_map.png"
const MAP_INFO := "res://ui/town_map.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const EARTH_INFO := "res://ui/earth_map.json"
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
var _view: Control                                  # the big map, shown on the player menu's Map sheet
var _map: TextureRect
var _overlay: Control
var _mini_layer: CanvasLayer
var _mini: Control
var _mini_tex: TextureRect
var _mini_overlay: Control
var _font: Font
var _time := 0.0
var _placed: Array[Rect2] = []                       # labels already drawn on the big map (so they don't overlap)
var _earth := {}                                     # the Earth town's map (EARTH_INFO)
var _earth_center := Vector2(-30, -25)
var _earth_size := 260.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS                # the map works while the game is paused under it
	_font = ThemeDB.fallback_font
	_texture = load(MAP_TEXTURE) as Texture2D
	var info = JSON.parse_string(FileAccess.get_file_as_string(MAP_INFO)) if FileAccess.file_exists(MAP_INFO) else null
	if info is Dictionary:
		_center = Vector2(float(info.center[0]), float(info.center[1]))
		_size_m = float(info.size_m)
	var earth = JSON.parse_string(FileAccess.get_file_as_string(EARTH_INFO)) if FileAccess.file_exists(EARTH_INFO) else null
	if earth is Dictionary:
		_earth = earth
		var b: Array = _earth.bounds
		_earth_center = Vector2((float(b[0]) + float(b[2])) / 2.0, (float(b[1]) + float(b[3])) / 2.0)
		_earth_size = maxf(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])) + 8.0
	_build()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


# -----------------------------------------------------------------------------
# Where things are on the map (0..1 across and down)
# -----------------------------------------------------------------------------
func to_map(world: Vector3) -> Vector2:
	if on_earth():
		return Vector2((world.x - _earth_center.x) / _earth_size + 0.5, (world.z - _earth_center.y) / _earth_size + 0.5)
	return Vector2((world.x - _center.x) / _size_m + 0.5, (world.z - _center.y) / _size_m + 0.5)


func in_town() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == TOWN


func on_earth() -> bool:
	var s := get_tree().current_scene if is_inside_tree() else null
	return s != null and s.scene_file_path == EARTH and not _earth.is_empty()


func nina() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func nina_facing() -> float:
	# Her model's yaw (it faces +Z): the direction she's looking, on the map
	var p := nina()
	if p == null or not p.has_node("Visual"):
		return 0.0
	return (p.get_node("Visual") as Node3D).global_rotation.y


func people() -> Array:
	# [{id, name, pos, home}] for everyone with a daily routine
	var out := []
	for r in get_tree().get_nodes_in_group("routines"):
		var body := r.get_parent() as Node3D
		var id := str(r.get("character_id"))
		var talk := body.get_node_or_null("Talk")
		if talk == null and get_tree().current_scene:
			talk = _talker(get_tree().current_scene, id)     # Mr. Palmer talks from his window, not his body
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
# The player menu (scripts/player_menu.gd) opens and closes it, pausing the game under it, and keeps it out of the way
# of the pause menu, a bed and conversations.
func is_open() -> bool:
	return PlayerMenu.showing("map")


func toggle() -> void:
	PlayerMenu.toggle_sheet("map")


func map_view() -> Control:
	_map.visible = not on_earth()                      # (Earth's map is drawn, not a picture)
	_overlay.queue_redraw()
	return _view


func map_view_node() -> Control:
	return _view


func _process(delta: float) -> void:
	_time += delta
	if is_open():
		_overlay.queue_redraw()
	# The minimap is always up in a race (scripts/races.gd), to see the bends coming
	var show_mini := (Settings.minimap or Races.racing()) and (in_town() or on_earth()) and not is_open() and not get_tree().paused \
		and nina() != null
	_mini_layer.visible = show_mini
	if show_mini:
		_mini_tex.visible = not on_earth()
		_mini_tex.size = Vector2.ONE * _mini_scale_px()
		var at := to_map(nina().global_position) * _mini_scale_px()
		_mini_tex.position = Vector2(MINI_SIZE, MINI_SIZE) / 2.0 - at
		_mini_overlay.queue_redraw()


func _mini_scale_px() -> float:
	return MINI_SIZE * (_earth_size if on_earth() else _size_m) / MINI_METRES    # the whole map's width in minimap pixels


# -----------------------------------------------------------------------------
# Drawing
# -----------------------------------------------------------------------------
func _build() -> void:
	_view = Control.new()
	_view.name = "MapView"
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.1, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.add_child(dim)
	_map = TextureRect.new()
	_map.texture = _texture
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.add_child(_map)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_full)
	_view.add_child(_overlay)
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
	if on_earth():
		_draw_earth_full(c, r)
		return
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
		# Things that roam about and name themselves (the Agent of Chaos, scripts/chaos_giant.gd): in the
		# "map_landmarks" group with a map_name().
		for n in get_tree().get_nodes_in_group("map_landmarks"):
			var at := r.position + to_map((n as Node3D).global_position) * r.size
			c.draw_circle(at, 7.0, Color(1.0, 0.3, 0.45))
			c.draw_arc(at, 7.0, 0, TAU, 16, Color(0.25, 0.05, 0.1), 1.5)
			_text(c, at + Vector2(0, -_fs(15)), str(n.call("map_name")), _fs(15), Color(1.0, 0.55, 0.6), true, true)
		# Lost watches she's found (scripts/watches.gd), where she found them: never the ones still out there
		for w in Watches.found_in_town():
			var at := r.position + to_map(w.pos) * r.size
			c.draw_circle(at, 6.0, Color(1.0, 0.82, 0.3))
			c.draw_arc(at, 6.0, 0, TAU, 16, Color(0.3, 0.15, 0.35), 1.5)
			c.draw_line(at, at + Vector2(0, -4), Color(0.3, 0.15, 0.35), 1.5)
			c.draw_line(at, at + Vector2(3, 1), Color(0.3, 0.15, 0.35), 1.5)
		if portal_open():
			var portal := s.get_node_or_null("Portal to Earth") as Node3D
			if portal:
				var at := r.position + to_map(portal.global_position) * r.size
				var glow := 0.6 + 0.4 * sin(_time * 4.0)
				c.draw_circle(at, 16.0, Color(0.6, 0.3, 1.0, 0.35 * glow))
				c.draw_arc(at, 12.0, 0, TAU, 32, Color(0.75, 0.5, 1.0), 4.0)
				_text(c, at + Vector2(0, -_fs(26)), "The portal is open!", _fs(18), Color(0.85, 0.7, 1.0))
		_draw_races(c, r.position, r.size.x, true)
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
			where = "You're at home on Earth. In the Shift, the portal by the old oak opens to Galaxity."
			var portal := r.position + to_map(Vector3(36, 0, 13)) * r.size
			_star(c, portal, 10.0)
		_text(c, r.get_center(), where, _fs(22), Color(1, 0.95, 0.75))
	var legend := Dialogue.player_name() + "    ★ Quest    ● People    ⌂ Home    ◷ Watch found    ⚑ Race    (%s to close)" % Settings.prompt("map")
	_text(c, Vector2(r.position.x + r.size.x / 2, r.end.y - _fs(18)), legend, _fs(16), Color(1, 1, 1, 0.85))


func _draw_mini() -> void:
	var c := _mini_overlay
	var scale := _mini_scale_px()
	var offset := _mini_tex.position
	if on_earth():
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)), Color(0.32, 0.36, 0.2))
		_draw_earth(c, offset, scale, false)
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)), Color(0.1, 0.06, 0.15), false, 3.0)
	_draw_races(c, offset, scale, false)
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


func _draw_races(c: Control, origin: Vector2, size: float, full: bool) -> void:
	# The race tracks (scripts/races.gd): each one's route with a flag at its start, the one being raced in gold with
	# the next ring and the friends racing, the ones not open yet faint. The minimap only shows the race being run.
	for tr in Races.map_tracks():
		if not full and not tr.racing:
			continue
		var line: PackedVector3Array = tr.line
		var pts := PackedVector2Array()
		for i in range(0, line.size(), 3):
			pts.append(origin + to_map(line[i]) * size)
		if pts.size() > 2:
			pts.append(pts[0])
			var col := Color(1.0, 0.82, 0.3, 0.95) if tr.racing else (Color(0.4, 0.95, 0.9, 0.8) if tr.open else Color(0.8, 0.8, 0.9, 0.35))
			c.draw_polyline(pts, Color(0.12, 0.05, 0.2, 0.6), 6.0 if tr.racing else 4.5, true)
			c.draw_polyline(pts, col, 3.5 if tr.racing else 2.5, true)
		var at := origin + to_map(tr.start) * size
		c.draw_line(at, at + Vector2(0, -16), Color(0.15, 0.08, 0.25), 2.0)
		c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -16), at + Vector2(11, -12), at + Vector2(0, -8)]),
			Color(1.0, 0.82, 0.3) if tr.open else Color(0.8, 0.8, 0.9, 0.6))
		if full:
			_text(c, at + Vector2(0, -_fs(26)), str(tr.name) + ("" if tr.open else " (not open yet)"), _fs(15),
				Color(1.0, 0.9, 0.55) if tr.open else Color(0.85, 0.85, 0.95, 0.7), true, true)
	if Races.racing():
		_star(c, origin + to_map(Races.map_next()) * size, 9.0 if full else 7.0)
		for pos in Races.map_rivals():
			c.draw_circle(origin + to_map(pos) * size, 5.0 if full else 4.0, Color(1.0, 0.55, 0.75))
			c.draw_arc(origin + to_map(pos) * size, 5.0 if full else 4.0, 0, TAU, 12, Color(0.25, 0.05, 0.15), 1.5)


func _apply_settings() -> void:
	_overlay.queue_redraw()


func _exit_tree() -> void:
	if _view.get_parent() == null:
		_view.free()                                   # put away (not on the player menu) when the game quits


# -----------------------------------------------------------------------------
# Earth's map, drawn from res://ui/earth_map.json
# -----------------------------------------------------------------------------
const EARTH_COLORS := {
	"grass": Color(0.42, 0.48, 0.24), "hill": Color(0.5, 0.52, 0.28), "hill_top": Color(0.58, 0.57, 0.32),
	"water": Color(0.3, 0.55, 0.75), "street": Color(0.3, 0.3, 0.34), "path": Color(0.78, 0.7, 0.55),
	"bridge": Color(0.62, 0.22, 0.18), "green": Color(0.38, 0.62, 0.3), "inside": Color(0.98, 0.72, 0.38),
	"building": Color(0.85, 0.78, 0.66), "home": Color(1.0, 0.6, 0.75), "skate": Color(0.65, 0.55, 0.85),
	"park": Color(0.55, 0.62, 0.3), "dock": Color(0.62, 0.45, 0.3),
}


func _ep(origin: Vector2, size: float, x: float, z: float) -> Vector2:
	return origin + to_map(Vector3(x, 0, z)) * size


func _draw_earth(c: Control, origin: Vector2, size: float, full: bool) -> void:
	# The town from above: grass, the hill, water, streets and paths, then the buildings (walk-in ones warm orange,
	# home pink, skate spots purple), the green and the portal
	var px := size / _earth_size                          # pixels a metre
	var b: Array = _earth.bounds
	var tl := _ep(origin, size, b[0], b[1])
	c.draw_rect(Rect2(tl, _ep(origin, size, b[2], b[3]) - tl), EARTH_COLORS.grass)
	var hill: Array = _earth.hill
	c.draw_circle(_ep(origin, size, hill[0], hill[1]), float(hill[3]) * px, EARTH_COLORS.hill)
	c.draw_circle(_ep(origin, size, hill[0], hill[1]), float(hill[2]) * px, EARTH_COLORS.hill_top)
	var pond: Array = _earth.pond
	var pts := PackedVector2Array()
	for k in 32:
		var a := k * TAU / 32
		pts.append(_ep(origin, size, pond[0] + cos(a) * pond[2], pond[1] + sin(a) * pond[3]))
	c.draw_colored_polygon(pts, EARTH_COLORS.water)
	var creek := PackedVector2Array()
	for p in _earth.creek:
		creek.append(_ep(origin, size, p[0], p[1]))
	c.draw_polyline(creek, EARTH_COLORS.water, maxf(float(_earth.creek_width) * px, 2.0), true)
	var pool: Array = _earth.pool
	c.draw_circle(_ep(origin, size, pool[0], pool[1]), float(pool[2]) * px, EARTH_COLORS.water)
	for kind in ["path", "street", "bridge"]:
		for st in _earth.streets:
			if st[5] == kind:
				c.draw_line(_ep(origin, size, st[0], st[1]), _ep(origin, size, st[2], st[3]), EARTH_COLORS[kind],
					maxf(float(st[4]) * px, 1.5))
	var g: Array = _earth.green
	c.draw_circle(_ep(origin, size, g[0], g[1]), float(g[2]) * px, EARTH_COLORS.green)
	for bd in _earth.buildings:
		var kind := str(bd[6])
		if kind == "bridge" and bd[0] == "":
			continue
		var at := Vector2(float(bd[1]), float(bd[2]))
		var half := Vector2(float(bd[3]), float(bd[4])) / 2.0
		var yaw := float(bd[5])
		var corners := PackedVector2Array()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			# local x/z back to the world: the inverse of the builder's rotation
			var w: Vector2 = (half * q).rotated(-yaw)
			corners.append(_ep(origin, size, at.x + w.x, at.y + w.y))
		var col: Color = EARTH_COLORS.get(kind, EARTH_COLORS.building)
		if kind == "park":
			corners.append(corners[0])
			c.draw_polyline(corners, col.lightened(0.2), 1.5)
		else:
			c.draw_colored_polygon(corners, col)
			corners.append(corners[0])
			c.draw_polyline(corners, Color(0.15, 0.1, 0.12, 0.8), 1.0)
	var portal: Array = _earth.portal
	var pp := _ep(origin, size, portal[0], portal[1])
	if portal_open():
		var glow := 0.6 + 0.4 * sin(_time * 4.0)
		c.draw_circle(pp, 14.0 if full else 9.0, Color(0.6, 0.3, 1.0, 0.35 * glow))
	c.draw_arc(pp, 8.0 if full else 5.0, 0, TAU, 24, Color(0.75, 0.5, 1.0), 3.0)
	if not full:
		return
	# Labels: the places you can go into and the big ones first, then the park's spots
	for bd in _earth.buildings:
		var kind := str(bd[6])
		if str(bd[0]) == "" or kind == "park" or kind == "dock":
			continue
		var at := _ep(origin, size, bd[1], bd[2])
		var col := Color(1.0, 0.88, 0.6) if kind == "inside" else (Color(1.0, 0.75, 0.85) if kind == "home" else Color(0.95, 0.95, 0.9))
		_text(c, at + Vector2(0, _fs(4)), str(bd[0]), _fs(13), col, true, true)
	for l in _earth.labels:
		_text(c, _ep(origin, size, l[1], l[2]), str(l[0]), _fs(16), Color(0.85, 0.95, 1.0), true, true)
	_text(c, pp + Vector2(0, -_fs(20)), "The portal is open!" if portal_open() else "Old oak portal", _fs(15), Color(0.85, 0.7, 1.0), true, true)


func _draw_earth_full(c: Control, r: Rect2) -> void:
	_text(c, Vector2(r.position.x + r.size.x / 2, r.position.y + _fs(24)), "Home on Earth", _fs(34), Color(1, 0.95, 0.75))
	_draw_earth(c, r.position, r.size.x, true)
	for p in people():
		var at := r.position + to_map(p.pos) * r.size
		if p.home:
			continue
		c.draw_circle(at, 6.0, Color(0.55, 0.9, 1.0))
		c.draw_arc(at, 6.0, 0, TAU, 16, Color(0.1, 0.2, 0.3), 1.5)
		_text(c, at + Vector2(0, -_fs(14)), p.name, _fs(14), Color(0.7, 0.95, 1.0), true, true)
	for q in quest_markers():
		_star(c, r.position + to_map(q.pos) * r.size, 13.0)
	var player := nina()
	if player:
		_arrow(c, r.position + to_map(player.global_position) * r.size, nina_facing(), 14.0)
	var legend := Dialogue.player_name() + "    ★ Quest    ● People    ■ Go inside    ■ Skate    (%s to close)" % Settings.prompt("map")
	_text(c, Vector2(r.position.x + r.size.x / 2, r.end.y - _fs(18)), legend, _fs(16), Color(1, 1, 1, 0.85))
