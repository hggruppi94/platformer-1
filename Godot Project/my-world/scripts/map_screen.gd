extends Node

# Autoload "TownMap": the maps. M (or LB on a controller; rebindable) opens the big map on the player menu's Map sheet
# (scripts/player_menu.gd), which Tab opens too; the round corner minimap is on by default (Settings > Display can
# switch it off).
#
# Which map:
#   - the Void: a picture of the town from above (res://ui/town_map.png, drawn from the real town by tools/make_map.gd),
#     labelled by district and building
#   - Earth (Stars Hollow): drawn instead of pictured, from res://ui/earth_map.json (written by tools/build_earth.gd)
#   - the places you go through a door or a portal into (the portal worlds, the race circuits, the Secret Garden, the
#     Gloop Kingdom, the Scary World): a picture taken from straight above the first time the map's wanted there
#     (_take_snap()), so every new place gets a map by itself. Indoors there's no map, just where you are.
#
# The big map zooms and moves (Hayden, 11 Nov 2026): the mouse wheel, + and -, the triggers on a controller or the
# buttons under the list zoom; drag it, WASD or the right stick move it; "Find me" (or R3) puts you back in the middle.
# The list on the right ("Show on the map") is the legend: each kind of thing on the map with its own picture, and
# clicking one (or A on it) hides it or shows it again, on the minimap too (Settings.map_hide, kept between games).
# Every quest you follow gets a star of its own colour with its name, listed under "Quest stars" so each can be hidden
# on its own; a star off the edge of a zoomed map sits on the edge, pointing the way.
#
# Nothing on the maps gives away what's not been found yet: portals only once their world is open, races only once
# they're open, watches only where they were found, people only once you've talked to them, and Earth's old oak only
# says it's a portal once it has opened (HummingOak.awake()).
#
# Markers for quests come from the quest spots that are open right now (scripts/quest_spot.gd) and from a step's
# "where" in res://quests/<id>.json: people (a character id) or places (a point in res://routines/places.json), each
# optionally {"who": "dash", "unless": "asked_dash"} to drop off once done.
# Only what the player follows gets stars (Quests.followed: the Follow buttons on the Quests sheet), several at once
# if they like, side jobs from the boards too (Requests/EarthJobs markers()).

const MAP_TEXTURE := "res://ui/town_map.png"
const MAP_INFO := "res://ui/town_map.json"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const EARTH_INFO := "res://ui/earth_map.json"
const MINI_SIZE := 220.0
const MINI_RING := 12.0                             # the compass ring's width round the round minimap
# Places with a shop in them, shown on the minimap with a little bag (looked up in the scene by name)
const SHOPS := ["Potion Shop", "Cafe", "Clothing Boutique", "Book Store", "Pet Shop", "Restaurant & Cafe", "Gaming Station",
	"Gadget Stall", "Hollow Diner", "Bookshop", "Corner Market", "Bakery", "Toy Shop", "Antiques", "Hardware Store"]
const MINI_METRES := 70.0                           # how much of the town the minimap shows across

# Districts (big labels), at fixed spots; buildings (small labels) are looked up in the town by name
const DISTRICTS := [["Market Square", Vector2(-72, 30)], ["Homes", Vector2(80, 20)], ["Castle & School", Vector2(15, -205)],
	["Secret Gardens", Vector2(-78, -60)], ["Observatory Hill", Vector2(105, -104)], ["Sports & Play", Vector2(66, 74)],
	["Spooky Woods", Vector2(-118, -146)], ["The Lake", Vector2(4, 8)]]
const BUILDINGS := ["Town Hall", "Library", "Museum", "Aquarium", "Potion Shop", "Cafe", "Clothing Boutique", "Book Store",
	"Pet Shop", "Restaurant & Cafe", "Gaming Station", "My House", "Nina's House", "Dash's House", "Melanie's House", "Observatory",
	"Haunted House", "Tree House", "Skate Park", "Magic Bubble Bath", "Portal to Earth"]

# Places that get a picture of their own from above (_take_snap()): folders, and single scenes
const SNAP_FOLDERS := ["res://scenes/portal_worlds/", "res://scenes/races/", "res://scenes/secret_garden/", "res://scenes/scary_world/",
	"res://scenes/bosses/"]
const SNAP_PIXELS := 1024

# Zoom: 1 shows the whole map; ZOOM_MAX is that much closer
const ZOOM_MAX := 6.0
const ZOOM_STEP := 1.5                              # a button, a key or a click of the wheel (the wheel goes in smaller steps)

# The kinds of things on the maps, in the order the list shows them: [id, name in the list]
const KINDS := [["quests", "Quest stars"], ["people", "People"], ["homes", "People at home"], ["places", "Places & shops"],
	["portals", "Portals"], ["races", "Races"], ["boosters", "Boosters"], ["watches", "Watches found"]]
# Each followed quest's star colour, in the order they were followed
const STAR_COLOURS := [Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.75), Color(0.4, 0.9, 1.0), Color(0.6, 1.0, 0.45),
	Color(1.0, 0.62, 0.3), Color(0.8, 0.65, 1.0)]

var _texture: Texture2D
var _center := Vector2(-8, -32)
var _size_m := 300.0
var _view: Control                                  # the big map, shown on the player menu's Map sheet
var _map: TextureRect
var _overlay: Control
var _legend_box: PanelContainer                     # "Show on the map": the legend, a toggle for each kind
var _legend_list: VBoxContainer
var _legend_scroll: ScrollContainer
var _legend_sig := ""                               # what the list was last built for (rebuilt when that changes)
var _mini_layer: CanvasLayer
var _mini: Control
var _mini_tex: TextureRect
var _mini_overlay: Control
var _mini_frame: Control                             # the compass ring, drawn over the round minimap
var _font: Font
var _time := 0.0
var _placed: Array[Rect2] = []                       # labels already drawn on the big map (so they don't overlap)
var _earth := {}                                     # the Earth town's map (EARTH_INFO)
var _earth_center := Vector2(-30, -25)
var _earth_size := 260.0
# The picture of the place she's in, from above: {path, scene (instance id), center, size, tex}
var _snap := {}
var _snapping := false
var _snap_failed := 0                                # the scene whose picture couldn't be taken
var _scene_id := 0
var _scene_age := 0.0                                # seconds since the scene she's in started
# The big map's view
var zoom := 2.0                                      # opens a little zoomed in on you; kept as the player leaves it
var _focus := Vector2(0.5, 0.5)                      # the map point (0..1) in the middle of the view
var _dragging := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS                # the map works while the game is paused under it
	_font = UiStyle.font()                               # the menus' comic lettering (scripts/ui_style.gd)
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
	Quests.follow_changed.connect(func() -> void: _legend_sig = "")
	_apply_settings()


# -----------------------------------------------------------------------------
# Where things are on the map (0..1 across and down)
# -----------------------------------------------------------------------------
func to_map(world: Vector3) -> Vector2:
	if on_earth():
		return Vector2((world.x - _earth_center.x) / _earth_size + 0.5, (world.z - _earth_center.y) / _earth_size + 0.5)
	if has_snap():
		return Vector2((world.x - _snap.center.x) / _snap.size + 0.5, (world.z - _snap.center.y) / _snap.size + 0.5)
	return Vector2((world.x - _center.x) / _size_m + 0.5, (world.z - _center.y) / _size_m + 0.5)


func in_town() -> bool:
	var s := get_tree().current_scene
	return s != null and s.scene_file_path == TOWN


func on_earth() -> bool:
	var s := get_tree().current_scene if is_inside_tree() else null
	return s != null and s.scene_file_path == EARTH and not _earth.is_empty()


func snap_scene() -> bool:
	# A place that gets its own picture from above (SNAP_FOLDERS)
	var s := get_tree().current_scene if is_inside_tree() else null
	if s == null or s.scene_file_path == "":
		return false
	return SNAP_FOLDERS.any(func(f: String) -> bool: return s.scene_file_path.begins_with(f))


func has_snap() -> bool:
	# The picture of the place she's in is ready
	var s := get_tree().current_scene if is_inside_tree() else null
	return s != null and not _snap.is_empty() and _snap.scene == s.get_instance_id()


func has_map() -> bool:
	# Somewhere with a map (not indoors)
	return in_town() or on_earth() or has_snap()


func place_name() -> String:
	# The big title over the map
	var s := get_tree().current_scene
	if on_earth():
		return "Home on Earth"
	if in_town() or s == null:
		return "The Void"
	var path := s.scene_file_path
	if Portals.is_world_scene(path):
		return str(Portals.world_for_scene(path).name)
	if path == Farm.SECRET_GARDEN:
		return "The Secret Garden"
	if path == Bosses.KINGDOM:
		return "The Gloop Kingdom"
	if path == Arena.LEVEL:
		return "The Star Arena"
	if path.begins_with("res://scenes/scary_world/"):
		return "The Scary World"
	if path.begins_with("res://scenes/races/"):
		return path.get_file().get_basename().capitalize()
	return s.name.capitalize()


func nina() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func nina_facing() -> float:
	# Her model's yaw (it faces +Z): the direction she's looking, on the map
	var p := nina()
	if p == null or not p.has_node("Visual"):
		return 0.0
	return (p.get_node("Visual") as Node3D).global_rotation.y


func people() -> Array:
	# [{id, name, pos, home, met}] for everyone with a daily routine
	var out := []
	for r in get_tree().get_nodes_in_group("routines"):
		var body := r.get_parent() as Node3D
		var id := str(r.get("character_id"))
		var talk := body.get_node_or_null("Talk")
		if talk == null and get_tree().current_scene:
			talk = _talker(get_tree().current_scene, id)     # Mr. Palmer talks from his window, not his body
		var name := Quests.display_name(id, str(talk.get("display_name")) if talk else id.capitalize())
		out.append({"id": id, "name": name, "pos": body.global_position, "home": not r.call("is_present"),
			"met": Dialogue.talk_count(id) > 0})
	return out


func _paths() -> TownPaths:
	# The named places where she is: Earth's (written by tools/build_earth.gd) or the Void's
	return TownPaths.get_shared(TownPaths.EARTH_FILE if on_earth() else TownPaths.FILE)


func quest_markers() -> Array:
	# [{pos, label, key}] for every followed quest step that's ready to be done right now, and every followed side job
	var out := []
	var s := get_tree().current_scene
	if s == null:
		return out
	var follow := Quests.live_followed()
	for key in follow:
		var job := Quests.job_of(key)
		if not job.is_empty():
			for pos in job.board.markers(job.r):
				out.append({"pos": pos, "label": str(job.board.text_of(job.r)), "key": key})
	for id in Quests._order:
		if not follow.is_empty() and not id in follow:
			continue
		if follow.is_empty() and id != Quests.tracked_quest():
			continue
		var step: Dictionary = Quests.current_step(id)
		if step.is_empty() or Quests.is_waiting(id):
			continue
		var name := str(Quests.quest(id).get("name", id))
		for spot in s.find_children("*", "Area3D", true, false):
			if spot.get("quest") == id and spot.has_method("is_open") and spot.call("is_open"):
				out.append({"pos": (spot as Node3D).global_position, "label": name, "key": id})
		for w in step.get("where", []):
			var entry: Dictionary = w if w is Dictionary else ({"who": w} if _talker(s, str(w)) else {"place": w})
			if entry.has("unless") and Dialogue.flags.has(str(entry.unless)):
				continue
			var pos = null
			if entry.has("at"):
				# A spot of its own ([x, z]: the Gloop King's court out in the west fields), in the Void unless it says
				# "world": "earth" (the First Night's glowing acorns)
				if (str(entry.get("world", "")) == "earth") == on_earth() and (in_town() or on_earth()):
					pos = Vector3(float(entry.at[0]), 0, float(entry.at[1]))
			elif entry.has("who"):
				var t := _talker(s, str(entry.who))
				if t:
					pos = (t.get_parent() as Node3D).global_position
			elif entry.has("place") and (in_town() or on_earth()) and _paths().has(str(entry.place)):
				var p2: Vector2 = _paths().points[str(entry.place)]
				pos = Vector3(p2.x, 0, p2.y)
			if pos != null:
				out.append({"pos": pos, "label": name, "key": id})
	return out


func star_keys() -> Array:
	# The quests and jobs with stars, in the order they were followed (each gets its colour from that)
	var keys := Quests.live_followed()
	if keys.is_empty() and Quests.tracked_quest() != "":
		keys = [Quests.tracked_quest()]
	return keys


func star_colour(key: String) -> Color:
	var i := star_keys().find(key)
	return STAR_COLOURS[maxi(i, 0) % STAR_COLOURS.size()]


func star_name(key: String) -> String:
	var job := Quests.job_of(key)
	if not job.is_empty():
		return str(job.board.text_of(job.r))
	return str(Quests.quest(key).get("name", key))


func _talker(s: Node, id: String) -> Node:
	for t in s.find_children("Talk", "Area3D", true, false):
		if t.get("character_id") == id:
			return t
	return null


func portal_open() -> bool:
	return Clock.in_shift()


# -----------------------------------------------------------------------------
# What's switched on (the legend's toggles, Settings.map_hide)
# -----------------------------------------------------------------------------
func shows(kind: String) -> bool:
	return not kind in Settings.map_hide


func set_shown(kind: String, on: bool) -> void:
	var hide: Array = Settings.map_hide.duplicate()
	if on:
		hide.erase(kind)
	elif not kind in hide:
		hide.append(kind)
	Settings.set_value("map_hide", hide)
	_legend_sig = ""
	_overlay.queue_redraw()


func shows_star(key: String) -> bool:
	return shows("quests") and shows("quest:" + key)


func open_tracks() -> Array:
	# The race tracks the map may show: only open ones (one not open yet stays a surprise)
	return Races.map_tracks().filter(func(t: Dictionary) -> bool: return t.open)


func legend_kinds() -> Array:
	# The kinds the list offers here: only ones there are any of on this map
	var out := ["quests"]
	var folks := people().filter(func(p: Dictionary) -> bool: return p.met)
	if folks.any(func(p: Dictionary) -> bool: return not p.home):
		out.append("people")
	if in_town() and folks.any(func(p: Dictionary) -> bool: return p.home):
		out.append("homes")
	if in_town() or on_earth():
		out.append("places")
	if (in_town() and (not Portals.open_worlds().is_empty() or portal_open())) or (on_earth() and HummingOak.awake()) \
			or (has_snap() and _home_portal() != null):
		out.append("portals")
	if not open_tracks().is_empty():
		out.append("races")
	if not Boosters.marks().is_empty() and (in_town() or on_earth()):
		out.append("boosters")
	if in_town() and not Watches.found_in_town().is_empty():
		out.append("watches")
	return out


func _home_portal() -> Node3D:
	var s := get_tree().current_scene
	return s.find_child("Portal Home", true, false) as Node3D if s else null


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
	if snap_scene() and not has_snap() and _snap_failed != _scene_id:
		_take_snap()
	_place_picture()
	find_me()
	_legend_sig = ""
	_refresh_legend()
	_overlay.queue_redraw()
	return _view


func map_view_node() -> Control:
	return _view


func _process(delta: float) -> void:
	_time += delta
	var s := get_tree().current_scene
	if s and s.get_instance_id() != _scene_id:
		_scene_id = s.get_instance_id()
		_scene_age = 0.0
		_legend_sig = ""
	_scene_age += delta
	# A new place gets its picture once it's had a moment to build itself (the worlds put most things in at the start)
	if snap_scene() and not has_snap() and not _snapping and _snap_failed != _scene_id and _scene_age > 0.6 and (Settings.minimap or Races.racing() or is_open()):
		_take_snap()
	if is_open():
		_steer(delta)
		_place_picture()
		if fmod(_time, 0.5) < delta:
			_refresh_legend()
		_overlay.queue_redraw()
	# The minimap is always up in a race (scripts/races.gd), to see the bends coming
	var show_mini := (Settings.minimap or Races.racing()) and has_map() and not is_open() and not get_tree().paused \
		and nina() != null and not (Races.intro and Races.intro.playing()) \
		and get_tree().get_nodes_in_group("cutscene_playing").is_empty()
	_mini_layer.visible = show_mini
	if show_mini:
		# Settings > Display > Screen stuff size: the whole corner map scales from the bottom-right corner
		var hs := Settings.hud_size
		_mini_layer.scale = Vector2(hs, hs)
		_mini_layer.offset = _mini_layer.get_viewport().get_visible_rect().size * (1.0 - hs)
		_mini_tex.visible = not on_earth()
		_mini_tex.texture = _snap.tex if has_snap() else _texture
		_mini_tex.size = Vector2.ONE * _mini_scale_px()
		var at := to_map(nina().global_position) * _mini_scale_px()
		_mini_tex.position = Vector2(MINI_SIZE, MINI_SIZE) / 2.0 - at
		_mini_overlay.queue_redraw()
		_mini_frame.queue_redraw()


func _map_metres() -> float:
	if on_earth():
		return _earth_size
	if has_snap():
		return float(_snap.size)
	return _size_m


func _mini_scale_px() -> float:
	return MINI_SIZE * _map_metres() / MINI_METRES    # the whole map's width in minimap pixels


# -----------------------------------------------------------------------------
# Zooming and moving the big map
# -----------------------------------------------------------------------------
func _area() -> Rect2:
	# Where the map goes on the sheet: left of the list, above the hint along the bottom
	var w := _overlay.size.x - _legend_width()
	var top := _title_height()
	return Rect2(Vector2(0, top), Vector2(maxf(w, 100.0), maxf(_overlay.size.y - _hint_height() - top, 100.0)))


func _title_height() -> float:
	return _fs(34) * 1.3


func _legend_width() -> float:
	return (_legend_box.size.x + 16.0) if _legend_box and _legend_box.visible else 0.0


func _hint_height() -> float:
	return _fs(16) * 2.0


func _map_rect() -> Rect2:
	# Where the whole (square) map is on screen at this zoom: bigger than the view once zoomed in
	var a := _area()
	var side := minf(a.size.x, a.size.y) * zoom
	var f := _clamp_focus(_focus, side, a)
	return Rect2(a.get_center() - f * side, Vector2(side, side))


func _clamp_focus(f: Vector2, side: float, a: Rect2) -> Vector2:
	# Keep the map filling the view: no running off past its edges
	var out := Vector2(0.5, 0.5)
	if side > a.size.x:
		var hx := a.size.x / side / 2.0
		out.x = clampf(f.x, hx, 1.0 - hx)
	if side > a.size.y:
		var hy := a.size.y / side / 2.0
		out.y = clampf(f.y, hy, 1.0 - hy)
	return out


func zoom_by(by: float, at := Vector2(-1, -1)) -> void:
	# Closer (by > 1) or further out, keeping the spot under the mouse (or the middle of the view) where it is
	var a := _area()
	if at.x < 0:
		at = a.get_center()
	var r := _map_rect()
	var u := (at - r.position) / r.size.x
	zoom = clampf(zoom * by, 1.0, ZOOM_MAX)
	var side := minf(a.size.x, a.size.y) * zoom
	_focus = _clamp_focus((a.get_center() - at) / side + u, side, a)
	_overlay.queue_redraw()


func move_by(px: Vector2) -> void:
	var r := _map_rect()
	_focus = _clamp_focus(_focus + px / r.size.x, r.size.x, _area())
	_overlay.queue_redraw()


func find_me() -> void:
	# The view to the middle of where she is
	var p := nina()
	_focus = to_map(p.global_position) if p and has_map() else Vector2(0.5, 0.5)
	if _view and _overlay.size.x > 0:
		_focus = _clamp_focus(_focus, _map_rect().size.x, _area())


func _steer(delta: float) -> void:
	# Held keys and sticks: WASD or the right stick move it, the triggers zoom
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		move.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		move.y += 1
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		move += stick
	if move != Vector2.ZERO:
		move_by(move.limit_length(1.0) * 700.0 * delta)
	var trig := Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) - Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(trig) > 0.2:
		zoom_by(pow(2.0, trig * delta * 1.5))


func _on_map_input(event: InputEvent) -> void:
	# The mouse on the map: the wheel zooms where it points, dragging moves it
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.2, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.2, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		_overlay.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		move_by(-(event as InputEventMouseMotion).relative)
		_overlay.accept_event()


func _input(event: InputEvent) -> void:
	# + and - zoom, R3 finds you (the list's buttons do it too)
	if not is_open() or PauseMenu.is_rebinding():
		return
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).physical_keycode
		if k in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			zoom_by(ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif k in [KEY_MINUS, KEY_KP_SUBTRACT]:
			zoom_by(1.0 / ZOOM_STEP)
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_STICK:
		find_me()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# The list: "Show on the map"
# -----------------------------------------------------------------------------
func _refresh_legend() -> void:
	var kinds := legend_kinds()
	var keys := star_keys()
	var sig := "%s|%s|%s|%s|%.2f" % [kinds, keys, Settings.map_hide, has_map(), Settings.text_scale]
	if sig == _legend_sig:
		return
	_legend_sig = sig
	var had_focus := _legend_list.get_viewport() != null and _legend_list.get_viewport().gui_get_focus_owner() != null \
		and _legend_list.is_ancestor_of(_legend_list.get_viewport().gui_get_focus_owner())
	var focus_name := str(_legend_list.get_viewport().gui_get_focus_owner().name) if had_focus else ""
	for c in _legend_list.get_children():
		_legend_list.remove_child(c)
		c.queue_free()
	_legend_box.visible = has_map()
	if not has_map():
		return
	var title := Label.new()
	title.text = "Show on the map"
	title.add_theme_font_size_override("font_size", _fs(20))
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_legend_list.add_child(title)
	for k in KINDS:
		if not k[0] in kinds:
			continue
		_legend_list.add_child(_toggle_row(str(k[0]), str(k[1]), shows(str(k[0])), false))
		if k[0] == "quests":
			for key in keys:
				_legend_list.add_child(_toggle_row("quest:" + key, star_name(key), shows("quest:" + key), true))
			if keys.is_empty():
				var none := Label.new()
				none.text = "  (Follow a quest to get a star)"
				none.add_theme_font_size_override("font_size", _fs(14))
				none.add_theme_color_override("font_color", Color(0.85, 0.8, 0.95))
				_legend_list.add_child(none)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, _fs(6))
	_legend_list.add_child(gap)
	var zooms := HBoxContainer.new()
	zooms.add_theme_constant_override("separation", _fs(6))
	for b in [["ZoomOut", "−", func() -> void: zoom_by(1.0 / ZOOM_STEP)], ["ZoomIn", "+", func() -> void: zoom_by(ZOOM_STEP)],
			["FindMe", "Find me", find_me]]:
		var btn := Button.new()
		btn.name = b[0]
		btn.text = b[1]
		btn.add_theme_font_size_override("font_size", _fs(20 if b[0] != "FindMe" else 17))
		btn.custom_minimum_size = Vector2(_fs(44), _fs(40))
		if b[0] == "FindMe":
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(b[2])
		zooms.add_child(btn)
	_legend_list.add_child(zooms)
	_legend_scroll.custom_minimum_size.x = _legend_list.get_combined_minimum_size().x + 4.0
	if focus_name != "":
		var again := _legend_list.find_child(focus_name, true, false) as Control
		if again:
			again.grab_focus.call_deferred()


func _toggle_row(kind: String, text: String, on: bool, sub: bool) -> Button:
	# A row of the list: the kind's own picture, its name and a tick box; clicking it switches the kind on or off
	var b := Button.new()
	b.name = "Show_" + kind.replace(":", "_")
	b.toggle_mode = true
	b.set_pressed_no_signal(on)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = text
	b.clip_text = true
	b.tooltip_text = ("Hide " if on else "Show ") + text
	b.add_theme_font_size_override("font_size", _fs(15 if sub else 17))
	var h := float(_fs(30 if sub else 34))
	b.custom_minimum_size = Vector2(_fs(250), h)
	# Calm rows: the tick box says what's on, so on and off look the same apart from it (and off fades)
	var calm := UiStyle.box(Color(0.2, 0.13, 0.32, 0.95), 10, Color(0.36, 0.27, 0.52), 1)
	var lit := UiStyle.box(Color(0.27, 0.18, 0.42, 1.0), 10, Color(0.45, 0.95, 0.95), 3)
	for st in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, calm)
	for st in ["hover", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, lit)
	for st in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, Color(1.0, 0.95, 0.85) if not sub else star_colour(kind.substr(6)).lightened(0.45))
	# A clear square where the picture goes, so the words start after it (the picture's drawn over it)
	var blank := Image.create(int(h * 0.7) + (_fs(14) if sub else 0), int(h * 0.7), false, Image.FORMAT_RGBA8)
	b.icon = ImageTexture.create_from_image(blank)
	b.add_theme_constant_override("icon_max_width", 0)
	b.modulate = Color(1, 1, 1) if on else Color(1, 1, 1, 0.6)
	b.set_meta("kind", kind)
	b.toggled.connect(func(now: bool) -> void:
		Audio.play("ui_move", -8.0, 0.0)
		set_shown(kind, now))
	var pic := Control.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.draw.connect(func() -> void: _draw_row_pictures(pic, kind, on, sub))
	b.add_child(pic)
	b.resized.connect(pic.queue_redraw)
	return b


func _draw_row_pictures(c: Control, kind: String, on: bool, sub: bool) -> void:
	var h := c.size.y
	var at := Vector2(_fs(10) + h * 0.35 + (_fs(14) if sub else 0), h / 2.0)
	var r := h * 0.28
	_legend_icon(c, kind, at, r)
	if not on:
		c.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), Color(0.1, 0.05, 0.15), 4.0)
		c.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), Color(1, 0.45, 0.5), 2.0)
	# The tick box on the right
	var bs := h * 0.42
	var box := Rect2(Vector2(c.size.x - bs - _fs(10), (h - bs) / 2.0), Vector2(bs, bs))
	c.draw_rect(box, Color(0.08, 0.04, 0.14, 0.9))
	c.draw_rect(box, Color(1.0, 0.85, 0.35) if on else Color(0.7, 0.65, 0.8), false, 2.0)
	if on:
		var p := box.position
		c.draw_polyline(PackedVector2Array([p + Vector2(bs * 0.2, bs * 0.55), p + Vector2(bs * 0.42, bs * 0.78),
			p + Vector2(bs * 0.82, bs * 0.25)]), Color(0.55, 1.0, 0.55), 3.0)


func _legend_icon(c: Control, kind: String, at: Vector2, r: float) -> void:
	# The same pictures the map uses
	if kind.begins_with("quest:"):
		_star(c, at, r * 1.1, star_colour(kind.substr(6)), false)
		return
	match kind:
		"quests":
			_star(c, at, r * 1.15, STAR_COLOURS[0], false)
		"people":
			c.draw_circle(at, r * 0.6, Color(0.55, 0.9, 1.0))
			c.draw_arc(at, r * 0.6, 0, TAU, 16, Color(0.1, 0.2, 0.3), 1.5)
		"homes":
			_house(c, at, r * 0.9, Color(0.75, 0.85, 1.0))
		"places":
			_bag(c, at, r * 0.75)
		"portals":
			c.draw_circle(at, r, Color(0.6, 0.3, 1.0, 0.45))
			c.draw_arc(at, r * 0.8, 0, TAU, 20, Color(0.8, 0.55, 1.0), 3.0)
		"races":
			_flag(c, at + Vector2(-r * 0.4, r), true, r * 2.0)
		"boosters":
			_booster(c, at, r * 1.1, PI / 2.0, "strip")
		"watches":
			_watch(c, at, r * 0.8)


# -----------------------------------------------------------------------------
# A place's own picture from above
# -----------------------------------------------------------------------------
func snap_bounds(s: Node) -> Dictionary:
	# {center: Vector2, size: metres, top: y} round everything you can reach or meet there: anything you can walk into
	# or talk to (Area3D), anyone (CharacterBody3D) and the way home, with room round the edge
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var n := 0
	for k in s.find_children("*", "Node3D", true, false):
		if not (k is Area3D or k is CharacterBody3D) or not (k as Node3D).is_visible_in_tree():
			continue
		var p := (k as Node3D).global_position
		if absf(p.x) > 1000.0 or absf(p.z) > 1000.0 or p.y < -200.0:
			continue
		lo = lo.min(p)
		hi = hi.max(p)
		n += 1
	# A place's walls (the Secret Garden's, a world's fence: "WorldBounds..." bodies) and a race circuit's whole road
	var edge_pts: Array[Vector3] = []
	for k in s.find_children("WorldBounds*", "", true, false):
		for cs in k.find_children("*", "CollisionShape3D", true, false):
			edge_pts.append((cs as Node3D).global_position)
		if k is Node3D:
			edge_pts.append((k as Node3D).global_position)
	if s.scene_file_path.begins_with("res://scenes/races/"):
		for tr in Races.map_tracks():
			for p in (tr.line as PackedVector3Array):
				edge_pts.append(p)
	for p in edge_pts:
		if absf(p.x) > 1000.0 or absf(p.z) > 1000.0:
			continue
		lo = lo.min(Vector3(p.x, lo.y if n > 0 else p.y, p.z))
		hi = hi.max(Vector3(p.x, hi.y if n > 0 else p.y, p.z))
		n += 1
	if n == 0:
		return {"center": Vector2.ZERO, "size": 120.0, "top": 40.0}
	var size := clampf(maxf(hi.x - lo.x, hi.z - lo.z) + 30.0, 80.0, 420.0)
	return {"center": Vector2((lo.x + hi.x) / 2.0, (lo.z + hi.z) / 2.0), "size": size, "top": hi.y}


func _take_snap() -> void:
	# Renders the place she's in from straight above, once, into a picture for both maps: no fog, a little brighter
	# than it really is (so night worlds still read), with whatever hangs high overhead left out (the camera starts
	# above everything you can reach, so a cave's roof and the sky stay out)
	var s := get_tree().current_scene
	if s == null or _snapping or not (s is Node3D):
		return
	_snapping = true
	var b := snap_bounds(s)
	var vp := SubViewport.new()
	vp.size = Vector2i(SNAP_PIXELS, SNAP_PIXELS)
	vp.world_3d = get_tree().root.world_3d
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_2X
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(b.size)
	cam.near = 0.05
	cam.far = 800.0
	var we := s.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we and we.environment:
		var env := we.environment.duplicate() as Environment
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		if env.ambient_light_energy < 0.6 or env.ambient_light_color.get_luminance() < 0.35:
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = env.ambient_light_color.lerp(Color(1, 1, 1), 0.5)
			env.ambient_light_energy = maxf(env.ambient_light_energy, 0.8)
		cam.environment = env
	vp.add_child(cam)
	add_child(vp)
	cam.global_position = Vector3(b.center.x, float(b.top) + 30.0, b.center.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)                 # straight down, north (-z) at the top
	cam.current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image() if is_instance_valid(vp) else null
	if is_instance_valid(vp):
		vp.queue_free()
	_snapping = false
	if not is_instance_valid(s) or get_tree().current_scene != s:
		return
	if img == null or img.is_empty():
		_snap_failed = s.get_instance_id()             # (no rendering: a headless run) so no map here, and no retrying
		return
	_snap = {"path": s.scene_file_path, "scene": s.get_instance_id(), "center": b.center, "size": float(b.size),
		"tex": ImageTexture.create_from_image(img)}
	_legend_sig = ""
	if is_open():
		find_me()


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
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(dim)
	_map = TextureRect.new()
	_map.texture = _texture
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_map)
	_overlay = Control.new()
	_overlay.name = "MapOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP           # the wheel zooms, dragging moves it (_on_map_input)
	_overlay.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_overlay.draw.connect(_draw_full)
	_overlay.gui_input.connect(_on_map_input)
	_overlay.resized.connect(func() -> void: _legend_sig = "")
	_view.add_child(_overlay)
	# The list on the right
	_legend_box = PanelContainer.new()
	_legend_box.name = "Legend"
	_legend_box.anchor_left = 1.0
	_legend_box.anchor_right = 1.0
	_legend_box.anchor_bottom = 1.0
	_legend_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_legend_box.offset_right = -8
	_legend_box.offset_top = 8
	_legend_box.offset_bottom = -8
	var sb := UiStyle.box(Color(0.12, 0.07, 0.2, 0.92), 14, Color(0.7, 0.6, 0.95), 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_legend_box.add_theme_stylebox_override("panel", sb)
	_view.add_child(_legend_box)
	# A long list (lots of quests followed, big text) scrolls rather than running off the bottom
	_legend_scroll = ScrollContainer.new()
	_legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_legend_scroll.follow_focus = true
	_legend_box.add_child(_legend_scroll)
	_legend_list = VBoxContainer.new()
	_legend_list.add_theme_constant_override("separation", 4)
	_legend_scroll.add_child(_legend_list)
	# The corner minimap
	_mini_layer = CanvasLayer.new()
	_mini_layer.layer = 5
	add_child(_mini_layer)
	_mini = Control.new()
	_mini.name = "Minimap"
	# The minimap never takes the mouse. Its map picture is far bigger than the circle (only clipped to it on screen),
	# and with the mouse captured every mouse move lands in the middle of the screen: in the Void that was on the
	# picture, so the minimap ate every mouse move and the camera wouldn't turn after coming through the portal.
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Round: the minimap draws a filled circle and everything in it is clipped to that circle
	_mini.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mini.draw.connect(func() -> void: _mini.draw_circle(Vector2(MINI_SIZE, MINI_SIZE) / 2.0, MINI_SIZE / 2.0, Color.WHITE))
	_mini.custom_minimum_size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini.offset_left = -MINI_SIZE - 16 - MINI_RING
	_mini.offset_top = -MINI_SIZE - 16 - MINI_RING
	_mini.offset_right = -16 - MINI_RING
	_mini.offset_bottom = -16 - MINI_RING
	_mini_layer.add_child(_mini)
	var under := ColorRect.new()                                  # round a place's picture: dusk
	under.color = Color(0.1, 0.08, 0.16)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini.add_child(under)
	_mini_tex = TextureRect.new()
	_mini_tex.texture = _texture
	_mini_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini_tex.size = Vector2.ONE * _mini_scale_px()
	_mini.add_child(_mini_tex)
	_mini_overlay = Control.new()
	_mini_overlay.size = Vector2(MINI_SIZE, MINI_SIZE)
	_mini_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_overlay.draw.connect(_draw_mini)
	_mini.add_child(_mini_overlay)
	_mini_frame = Control.new()
	_mini_frame.name = "Compass"
	_mini_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini_frame.offset_left = _mini.offset_left
	_mini_frame.offset_top = _mini.offset_top
	_mini_frame.offset_right = _mini.offset_right
	_mini_frame.offset_bottom = _mini.offset_bottom
	_mini_frame.draw.connect(_draw_compass)
	_mini_layer.add_child(_mini_frame)


func _place_picture() -> void:
	# The picture under the drawing: the Void's, or the place's own; Earth's is drawn
	_map.visible = (in_town() or has_snap()) and not on_earth()
	_map.texture = _snap.tex if has_snap() else _texture
	var r := _map_rect()
	_map.position = r.position
	_map.size = r.size


func _fs(px: float) -> int:
	return roundi(px * Settings.text_scale)


func _text(c: Control, at: Vector2, s: String, size: int, color: Color, centered := true, nudge := false) -> void:
	# nudge: if it would cover a label already there, try just below or above it, or leave it out
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := at - Vector2(w / 2.0 if centered else 0.0, -size * 0.35)
	if nudge:
		var found := false
		for dy in [0.0, size * 1.1, -size * 1.1, size * 2.2, -size * 2.2]:
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


func _star(c: Control, at: Vector2, r: float, col := Color(1.0, 0.85, 0.2), pulse_it := true) -> void:
	var pulse := (1.0 + 0.15 * sin(_time * 5.0)) if pulse_it and not Settings.reduce_motion else 1.0
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		pts.append(at + Vector2(cos(a), sin(a)) * r * pulse * (1.0 if k % 2 == 0 else 0.45))
	c.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	c.draw_polyline(pts, col.darkened(0.7), 2.0)


func _house(c: Control, at: Vector2, r: float, col: Color) -> void:
	c.draw_rect(Rect2(at - Vector2(r * 0.7, r * 0.3), Vector2(r * 1.4, r * 1.0)), col)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, -r * 0.3), at + Vector2(0, -r * 1.1), at + Vector2(r, -r * 0.3)]), col)


func _flag(c: Control, at: Vector2, open: bool, h := 16.0) -> void:
	c.draw_line(at, at + Vector2(0, -h), Color(0.15, 0.08, 0.25), 2.0)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -h), at + Vector2(h * 0.7, -h * 0.75), at + Vector2(0, -h * 0.5)]),
		Color(1.0, 0.82, 0.3) if open else Color(0.8, 0.8, 0.9, 0.6))


func _watch(c: Control, at: Vector2, r: float) -> void:
	c.draw_circle(at, r, Color(1.0, 0.82, 0.3))
	c.draw_arc(at, r, 0, TAU, 16, Color(0.3, 0.15, 0.35), 1.5)
	c.draw_line(at, at + Vector2(0, -r * 0.7), Color(0.3, 0.15, 0.35), 1.5)
	c.draw_line(at, at + Vector2(r * 0.5, r * 0.15), Color(0.3, 0.15, 0.35), 1.5)


func _booster(c: Control, at: Vector2, r: float, yaw: float, kind: String) -> void:
	var fwd := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pts := PackedVector2Array([at + fwd * r, at - fwd * r * 0.7 + side * r * 0.75, at - fwd * r * 0.3,
		at - fwd * r * 0.7 - side * r * 0.75])
	c.draw_colored_polygon(pts, Color(1.0, 0.85, 0.35) if kind == "coins" else Color(0.3, 0.95, 0.95))
	pts.append(pts[0])
	c.draw_polyline(pts, Color(0.08, 0.15, 0.22, 0.9), 1.5)


func _draw_stars(c: Control, r: Rect2, size: float) -> void:
	# Every followed quest's stars in its own colour with its name; off the edge of the view, on the edge pointing out
	var view := _area().grow(-size * 1.6)
	var named := {}
	var edges := {}                                   # off the view: the nearest star of each quest, pointed at
	for q in quest_markers():
		var key := str(q.key)
		if not shows_star(key):
			continue
		var col := star_colour(key)
		var at: Vector2 = r.position + to_map(q.pos) * r.size
		if view.has_point(at):
			_star(c, at, size, col)
			if names_shown() and (not named.has(key) or at.distance_to(named[key]) > 80.0):
				named[key] = at
				_text(c, at + Vector2(0, size + _fs(12)), str(q.label), _fs(15), col.lightened(0.35), true, true)
		else:
			var mid := view.get_center()
			if not edges.has(key) or at.distance_to(mid) < (edges[key] as Vector2).distance_to(mid):
				edges[key] = at
	for key in edges:
		var col := star_colour(key)
		var at: Vector2 = edges[key]
		var mid := view.get_center()
		var d: Vector2 = (at - mid)
		var t := minf(absf(view.size.x / 2.0 / d.x) if d.x != 0.0 else INF, absf(view.size.y / 2.0 / d.y) if d.y != 0.0 else INF)
		var edge := mid + d * t
		_star(c, edge, size * 0.8, col)
		var dir := d.normalized()
		var tip := edge + dir * size * 1.5
		c.draw_colored_polygon(PackedVector2Array([tip, edge + dir * size * 0.9 + dir.orthogonal() * size * 0.45,
			edge + dir * size * 0.9 - dir.orthogonal() * size * 0.45]), col)


func _draw_full() -> void:
	var c := _overlay
	var s := get_tree().current_scene
	_placed.clear()
	var a := _area()
	_placed.append(Rect2(0, a.end.y, c.size.x, _hint_height()))   # the hint's strip: labels keep out of it
	var r := _map_rect()
	if not has_map():
		_draw_indoors(c, s)
		return
	if snap_scene() and not has_snap() and _snap_failed != _scene_id:
		_text(c, a.get_center(), "Drawing the map...", _fs(22), Color(1, 0.95, 0.75))
		return
	if on_earth():
		_draw_earth(c, r.position, r.size.x, true)
	elif in_town():
		for d in DISTRICTS:
			_text(c, r.position + to_map(Vector3(d[1].x, 0, d[1].y)) * r.size, d[0], _fs(24 if names_shown() else 17), Color(1, 1, 0.85), true, true)
	_draw_people(c, r)
	if in_town() and shows("places"):
		for b in BUILDINGS:
			var n := s.get_node_or_null(b) as Node3D
			if n:
				var at := r.position + to_map(n.global_position) * r.size
				c.draw_circle(at, 3.0, Color(1, 1, 1, 0.9))
				if names_shown():
					_text(c, at + Vector2(0, _fs(13)), b, _fs(14), Color(1, 1, 1, 0.95), true, true)
	if in_town():
		# Things that roam about and name themselves: in the "map_landmarks" group with a map_name() (the Goblin
		# Clockyard; the Agent of Chaos once he's there, scripts/chaos_giant.gd)
		for n in get_tree().get_nodes_in_group("map_landmarks"):
			if not (n as Node3D).is_visible_in_tree():
				continue
			var at := r.position + to_map((n as Node3D).global_position) * r.size
			c.draw_circle(at, 7.0, Color(1.0, 0.3, 0.45))
			c.draw_arc(at, 7.0, 0, TAU, 16, Color(0.25, 0.05, 0.1), 1.5)
			_text(c, at + Vector2(0, -_fs(15)), str(n.call("map_name")), _fs(15), Color(1.0, 0.55, 0.6), true, true)
		# Lost watches she's found (scripts/watches.gd), where she found them: never the ones still out there
		if shows("watches"):
			for w in Watches.found_in_town():
				_watch(c, r.position + to_map(w.pos) * r.size, 6.0)
		if shows("portals"):
			if portal_open():
				var portal := s.get_node_or_null("Portal to Earth") as Node3D
				if portal:
					var at := r.position + to_map(portal.global_position) * r.size
					var glow := 0.6 + 0.4 * sin(_time * 4.0)
					c.draw_circle(at, 16.0, Color(0.6, 0.3, 1.0, 0.35 * glow))
					c.draw_arc(at, 12.0, 0, TAU, 32, Color(0.75, 0.5, 1.0), 4.0)
					_text(c, at + Vector2(0, -_fs(26)), "The portal is open!", _fs(18), Color(0.85, 0.7, 1.0), true, true)
			for w in Portals.open_worlds():       # the portal worlds' portals (scripts/portals.gd)
				var at := r.position + to_map(Vector3(w.at.x, 0, w.at.y)) * r.size
				c.draw_circle(at, 9.0, Color(w.colour, 0.45))
				c.draw_arc(at, 9.0, 0, TAU, 24, w.colour, 3.0)
				_text(c, at + Vector2(0, -_fs(16)), str(w.name), _fs(15), w.colour.lightened(0.3), true, true)
	elif has_snap() and shows("portals"):
		var home := _home_portal()
		if home:
			var at := r.position + to_map(home.global_position) * r.size
			c.draw_circle(at, 12.0, Color(0.6, 0.3, 1.0, 0.4))
			c.draw_arc(at, 10.0, 0, TAU, 24, Color(0.8, 0.55, 1.0), 3.0)
			_text(c, at + Vector2(0, -_fs(20)), "Way home", _fs(16), Color(0.85, 0.7, 1.0), true, true)
	_draw_races(c, r.position, r.size.x, true)
	_draw_boosters(c, r.position, r.size.x, true)
	_draw_stars(c, r, 13.0)
	var player := nina()
	if player:
		var at := r.position + to_map(player.global_position) * r.size
		_arrow(c, at, nina_facing(), 14.0)
		_text(c, at + Vector2(0, _fs(22)), Dialogue.player_name(), _fs(14), Color(1.0, 0.75, 0.85), true, true)
	# The place's name on top, and how to move about along the bottom
	_text(c, Vector2(a.get_center().x, _title_height() * 0.5), place_name(), _fs(34), Color(1, 0.95, 0.75))
	_hint(c, a)


func names_shown() -> bool:
	# Zoomed right out the map's too small for every name: only the big ones show (the districts, the stars' colours
	# are in the list); zoom in and the rest come in
	return zoom >= 1.6


func _draw_people(c: Control, r: Rect2) -> void:
	# People she's met: where they are, or (in the Void) a little house on their home when they're tucked up inside
	for p in people():
		if not p.met:
			continue
		var at := r.position + to_map(p.pos) * r.size
		if p.home:
			if in_town() and shows("homes"):
				_house(c, at, 7.0, Color(0.75, 0.85, 1.0))
				if names_shown():
					_text(c, at + Vector2(0, _fs(14)), "%s (home)" % p.name, _fs(13), Color(0.75, 0.85, 1.0), true, true)
		elif shows("people"):
			c.draw_circle(at, 6.0, Color(0.55, 0.9, 1.0))
			c.draw_arc(at, 6.0, 0, TAU, 16, Color(0.1, 0.2, 0.3), 1.5)
			if names_shown():
				_text(c, at + Vector2(0, -_fs(14)), p.name, _fs(14), Color(0.7, 0.95, 1.0), true, true)


func _hint(c: Control, a: Rect2) -> void:
	var how := "Zoom: mouse wheel or + −    Move: drag or WASD    (%s to close)" % Settings.prompt("map")
	if Settings.last_device == "pad":
		how = "Zoom: LT / RT    Move: right stick    Find me: R3    (%s to close)" % Settings.prompt("map")
	var size := _fs(16)
	var w := _font.get_string_size(how, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w > a.size.x - 16.0:
		size = maxi(8, floori(size * (a.size.x - 16.0) / w))
	_text(c, Vector2(a.get_center().x, a.end.y + _hint_height() / 2.0 - size * 0.1), how, size, Color(1, 1, 1, 0.85))


func _draw_indoors(c: Control, s: Node) -> void:
	var where := "You're inside. Step outside to see where you are!"
	if snap_scene():
		where = "You're in %s. The way home takes you back any time." % place_name()
	_text(c, _area().get_center(), where, _fs(22), Color(1, 0.95, 0.75))
	_hint(c, _area())


func _draw_mini() -> void:
	var c := _mini_overlay
	var scale := _mini_scale_px()
	var offset := _mini_tex.position
	if on_earth():
		c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)), Color(0.32, 0.36, 0.2))
		_draw_earth(c, offset, scale, false)
	_draw_races(c, offset, scale, false)
	_draw_mini_places(c, offset, scale)
	_draw_boosters(c, offset, scale, false)
	var mid := Vector2(MINI_SIZE, MINI_SIZE) / 2.0
	for q in quest_markers():
		if not shows_star(str(q.key)):
			continue
		var at: Vector2 = offset + to_map(q.pos) * scale
		if at.distance_to(mid) > MINI_SIZE / 2.0 - 12.0:
			at = mid + (at - mid).normalized() * (MINI_SIZE / 2.0 - 12.0)   # off the edge: pinned to the rim
		_star(c, at, 8.0, star_colour(str(q.key)))
	if shows("people"):
		for p in people():
			if not p.home and p.met:
				var at: Vector2 = offset + to_map(p.pos) * scale
				if Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)).has_point(at):
					c.draw_circle(at, 4.0, Color(0.55, 0.9, 1.0))
	_arrow(c, Vector2(MINI_SIZE, MINI_SIZE) / 2.0, nina_facing(), 10.0)


func _draw_mini_places(c: Control, origin: Vector2, size: float) -> void:
	# Shops (a little bag) and portals (a purple swirl, bright when it's open) near enough to be on the minimap
	var s := get_tree().current_scene
	if s == null:
		return
	var mid := Vector2(MINI_SIZE, MINI_SIZE) / 2.0
	if shows("places") and (in_town() or on_earth()):
		for name in SHOPS:
			var n := s.get_node_or_null(name) as Node3D
			if n == null:
				continue
			var at: Vector2 = origin + to_map(n.global_position) * size
			if at.distance_to(mid) < MINI_SIZE / 2.0 - 6.0:
				_bag(c, at, 6.0)
	if not shows("portals") or (on_earth() and not HummingOak.awake()):
		return
	var portal := s.get_node_or_null("Portal to Earth" if in_town() else "Portal Home") as Node3D
	if portal == null and has_snap():
		portal = _home_portal()
	if portal:
		var at: Vector2 = origin + to_map(portal.global_position) * size
		if at.distance_to(mid) < MINI_SIZE / 2.0 - 6.0:
			var open := portal_open() or has_snap()
			c.draw_circle(at, 8.0, Color(0.6, 0.3, 1.0, 0.45 if open else 0.2))
			c.draw_arc(at, 6.0, 0, TAU, 20, Color(0.8, 0.55, 1.0) if open else Color(0.7, 0.6, 0.85, 0.8), 2.5)
			c.draw_arc(at, 3.0, _time * 3.0, _time * 3.0 + PI * 1.4, 10, Color(1, 1, 1, 0.9), 1.5)


func _bag(c: Control, at: Vector2, r: float) -> void:
	# A shopping bag: a rounded body and a handle
	var body := Rect2(at - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.6))
	c.draw_rect(body.grow(1.5), Color(0.08, 0.04, 0.14))
	c.draw_rect(body, Color(1.0, 0.55, 0.8))
	c.draw_arc(at - Vector2(0, r * 0.6), r * 0.55, PI, TAU, 10, Color(0.08, 0.04, 0.14), 2.0)


func _draw_compass(c: Control = null) -> void:
	# The ring round the minimap: ink, then lavender, a gold rim, and the four compass points (north is up the map)
	c = _mini_frame
	var mid := Vector2(MINI_SIZE, MINI_SIZE) / 2.0
	var r := MINI_SIZE / 2.0
	c.draw_arc(mid, r + MINI_RING / 2.0, 0, TAU, 64, Color(0.07, 0.03, 0.12, 0.95), MINI_RING + 4.0, true)
	c.draw_arc(mid, r + MINI_RING / 2.0, 0, TAU, 64, Color(0.29, 0.18, 0.5), MINI_RING - 2.0, true)
	c.draw_arc(mid, r + 1.0, 0, TAU, 64, Color(1.0, 0.85, 0.35), 2.5, true)
	for k in 4:
		var a := -PI / 2.0 + k * PI / 2.0
		var at := mid + Vector2(cos(a), sin(a)) * (r + MINI_RING / 2.0)
		var size := _fs(17) if k == 0 else _fs(14)
		var letter: String = ["N", "E", "S", "W"][k]
		var w := _font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var pos := at + Vector2(-w / 2.0, size * 0.35)
		if k == 0:
			c.draw_circle(at, size * 0.75, Color(1.0, 0.4, 0.6))      # north gets a pink marker, like a real compass
		c.draw_string_outline(_font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.07, 0.03, 0.12))
		c.draw_string(_font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1) if k == 0 else Color(1.0, 0.92, 0.7))


func _draw_races(c: Control, origin: Vector2, size: float, full: bool) -> void:
	# The race tracks that are open (scripts/races.gd): each one's route with a flag at its start, the one being raced
	# in gold with the next ring and the friends racing. The minimap only shows the race being run.
	if shows("races"):
		for tr in open_tracks():
			if not full and not tr.racing:
				continue
			var line: PackedVector3Array = tr.line
			var pts := PackedVector2Array()
			for i in range(0, line.size(), 3):
				pts.append(origin + to_map(line[i]) * size)
			if pts.size() > 2:
				pts.append(pts[0])
				var col := Color(1.0, 0.82, 0.3, 0.95) if tr.racing else Color(0.4, 0.95, 0.9, 0.8)
				c.draw_polyline(pts, Color(0.12, 0.05, 0.2, 0.6), 6.0 if tr.racing else 4.5, true)
				c.draw_polyline(pts, col, 3.5 if tr.racing else 2.5, true)
			var at := origin + to_map(tr.start) * size
			_flag(c, at, true)
			if full:
				_text(c, at + Vector2(0, -_fs(26)), str(tr.name), _fs(15), Color(1.0, 0.9, 0.55), true, true)
	if Races.racing():
		# (in a race the next ring and the other racers always show)
		_star(c, origin + to_map(Races.map_next()) * size, 9.0 if full else 7.0)
		for pos in Races.map_rivals():
			c.draw_circle(origin + to_map(pos) * size, 5.0 if full else 4.0, Color(1.0, 0.55, 0.75))
			c.draw_arc(origin + to_map(pos) * size, 5.0 if full else 4.0, 0, TAU, 12, Color(0.25, 0.05, 0.15), 1.5)


func _draw_boosters(c: Control, origin: Vector2, size: float, full: bool) -> void:
	# The boosters (scripts/boosters.gd): a small arrow each, the way it pushes; teal for strips and ramps, gold at
	# the start of a line of coins. The minimap only draws the ones in its window.
	if not shows("boosters") or not (in_town() or on_earth()):
		return
	var r := 6.0 if full else 4.5
	for m in Boosters.marks():
		var at: Vector2 = origin + to_map(m.pos) * size
		if not full and not Rect2(Vector2.ZERO, Vector2(MINI_SIZE, MINI_SIZE)).grow(-4.0).has_point(at):
			continue
		_booster(c, at, r, float(m.yaw), str(m.kind))


func _apply_settings() -> void:
	_legend_sig = ""
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
	for r in _earth.get("rolls", []):                     # the rolling hills: a soft hump each, lighter on top
		c.draw_circle(_ep(origin, size, r[0], r[1]), float(r[2]) * 0.8 * px, EARTH_COLORS.hill)
		c.draw_circle(_ep(origin, size, r[0], r[1]), float(r[2]) * 0.35 * px, EARTH_COLORS.hill_top)
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
	# The old oak only shows as a portal once it has opened for the first time (before that it's just a tree)
	var portal: Array = _earth.portal
	var pp := _ep(origin, size, portal[0], portal[1])
	var oak_open := HummingOak.awake()
	if oak_open and shows("portals"):
		if portal_open():
			var glow := 0.6 + 0.4 * sin(_time * 4.0)
			c.draw_circle(pp, 14.0 if full else 9.0, Color(0.6, 0.3, 1.0, 0.35 * glow))
		c.draw_arc(pp, 8.0 if full else 5.0, 0, TAU, 24, Color(0.75, 0.5, 1.0), 3.0)
	if not full:
		return
	# Labels: the places you can go into and the big ones first, then the park's spots
	if oak_open and shows("portals"):
		_text(c, pp + Vector2(0, -_fs(20)), "The portal is open!" if portal_open() else "Old oak portal", _fs(15), Color(0.85, 0.7, 1.0), true, true)
	if not shows("places"):
		return
	for bd in _earth.buildings:
		var kind := str(bd[6])
		if str(bd[0]) == "" or kind == "park" or kind == "dock":
			continue
		var at := _ep(origin, size, bd[1], bd[2])
		var col := Color(1.0, 0.88, 0.6) if kind == "inside" else (Color(1.0, 0.75, 0.85) if kind == "home" else Color(0.95, 0.95, 0.9))
		_text(c, at + Vector2(0, _fs(4)), str(bd[0]), _fs(13), col, true, true)
	for l in _earth.labels:
		_text(c, _ep(origin, size, l[1], l[2]), str(l[0]), _fs(16), Color(0.85, 0.95, 1.0), true, true)
