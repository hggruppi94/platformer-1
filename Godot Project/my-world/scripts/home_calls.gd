extends Node

# Home calls (Hayden, 14 Nov 2026): "After completing worlds in the void, the player should be sucked back to earth,
# where they must complete more quests (can be season-related or one-off) in order to unlock the ability to go back to
# the void. That way earth stays relevant instead of being a place where you never have to go."
#
# A node "Home Calls" under the Portals autoload (scripts/portals.gd makes it, like the crack cutscenes); reach it as
# Portals.home_calls. No new autoload (and so no project.godot change).
#
#   1. Mending a world (Portals.clear()) owes Stars Hollow a visit. Dark Hollow (optional) and the Far Future (the
#      ending's right after it) don't.
#   2. Jumping into that world's way home doesn't take you to the Void: the crack pulls you all the way home to Earth,
#      out of the crack by the old oak, which snaps shut behind you.
#   3. Something's going on in Stars Hollow: a chapter quest. Seasonal ones when the world brought a season (winter after
#      the Frozen Moment, spring after Glenmoor, summer after Rhythm Springs: Stars Hollow turns to it, and Nina has
#      the quest she always has then); a one-off with a townsperson after the others.
#   4. Once it's done, the ground rumbles and the crack by the old oak opens again.
#
# Never a wait (Hayden, 14 Nov 2026: nothing waits on the clock): it's quest-gated only. Nothing here looks ahead (the
# no-spoilers rule): the words only say what's happening now. Saved inside Portals' own save ("home_calls"), so old
# saves just carry on (worlds mended before this owe nothing).

const EARTH := "res://scenes/earth/earth.tscn"
const SHUT_AFTER := 2.2                 # seconds after popping out of the crack before it snaps shut behind you

# world id -> its chapter: "quest" is the chapter's own quest (started when you're pulled home), "until" the quest
# whose end opens the crack again (the same, or the seasonal quest the chapter leads you to), "season" what Stars Hollow
# turns to.
const CHAPTERS := {
	"shard_isle": {"quest": "home_chimes", "until": "home_chimes"},
	"rootmind": {"quest": "home_plushies", "until": "home_plushies"},
	"frozen_moment": {"quest": "home_snow", "until": "first_snow", "season": "winter"},
	"lanternmoor": {"quest": "home_lamps", "until": "home_lamps"},
	"glenmoor": {"quest": "home_spring", "until": "duckling_day", "season": "spring"},
	"tide_reef": {"quest": "home_bottles", "until": "home_bottles"},
	"rhythm_springs": {"quest": "home_summer", "until": "summer_splash", "season": "summer"},
}
const PULLED := "Whoosh! The crack pulled you all the way home!"
const SHUT := "The crack snaps shut!"
const SHUT_DOOR := "The crack's shut tight. Not yet."
const REOPENED := "The ground rumbles by the old oak..."

# The chapters' things to find, put into Stars Hollow at play time (like the episode quests: no builder changes).
# [quest, step, flag, where (x, z), "Press F to ...", what it looks like]
const SPOTS := [
	["home_chimes", "find", "chime_1", Vector2(25.9, -8.0), "pick up the wind chime", "chime"],
	["home_chimes", "find", "chime_2", Vector2(-25.0, 14.0), "pick up the wind chime", "chime"],
	["home_chimes", "find", "chime_3", Vector2(-9.0, -25.9), "pick up the wind chime", "chime"],
	["home_plushies", "find", "plush_1", Vector2(-52.5, 27.5), "pick up the plushie", "plush_bear"],
	["home_plushies", "find", "plush_2", Vector2(-26.0, 30.0), "pick up the plushie", "plush_bunny"],
	["home_plushies", "find", "plush_3", Vector2(-45.0, 16.5), "pick up the plushie", "plush_frog"],
	["home_lamps", "fix", "lamp_1", Vector2(3.5, -30.0), "put in a new bulb", "lamp"],
	["home_lamps", "fix", "lamp_2", Vector2(3.5, -73.0), "put in a new bulb", "lamp"],
	["home_lamps", "fix", "lamp_3", Vector2(3.5, -104.0), "put in a new bulb", "lamp"],
	["home_bottles", "find", "bottle_1", Vector2(-60.5, 9.0), "pick up the bottle", "bottle"],
	["home_bottles", "find", "bottle_2", Vector2(-62.5, -4.0), "pick up the bottle", "bottle"],
	["home_bottles", "find", "bottle_3", Vector2(-75.0, 14.5), "pick up the bottle", "bottle"],
]
const FOUND := {"chime": "A wind chime! %d of 3.", "plush": "A plushie! %d of 3.", "lamp": "Lamp lit! %d of 3.",
	"bottle": "A bottle! %d of 3."}

var enabled := true                     # tests of one world alone can turn the pull off
var owed: Array = []                    # mended worlds whose pull home hasn't happened yet
var chapter := ""                       # the world whose chapter is on now ("" when the crack's open)
var done: Array = []                    # worlds whose chapter is over
var just_pulled := false                # popped out of the crack a moment ago: it's still open, about to snap shut
var reopen_due := false                 # the chapter's over: show the crack opening again when you're by it

var _scene: Node
var _shut_in := -1.0
var _check := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Dialogue.flag_set.connect(_on_flag)
	Quests.changed.connect(_on_quest)


# -----------------------------------------------------------------------------
# Is the way back to the Void shut?
# -----------------------------------------------------------------------------
func sealed() -> bool:
	return chapter != ""


func is_due(id: String) -> bool:
	# Going home from this world pulls you all the way to Earth
	return enabled and id in owed and not Portals.practice


func on_mended(id: String) -> void:
	# Portals.clear(): this world's mended, so Stars Hollow's owed a visit (unless its chapter's quest is done already)
	if Portals.practice or not CHAPTERS.has(id) or id in owed or id in done:
		return
	if Quests.is_done(str(CHAPTERS[id].until)):
		return
	owed.append(id)


func pull(id: String) -> void:
	# The way home from a mended world: all the way to Stars Hollow, out of the crack by the old oak
	owed.erase(id)
	chapter = id
	just_pulled = true
	reopen_due = false
	var c: Dictionary = CHAPTERS[id]
	var season := str(c.get("season", ""))
	if season != "" and Clock.season_open(season):
		Clock.dial_to(season)                  # (the world brought a season: Stars Hollow turns to it)
	Dialogue.set_flag(str(c.quest) + "_start")
	Playtest.note("pulled_home", {"world": id})
	Game.pending_message = PULLED
	Game.go(EARTH, Clock.EARTH_ARRIVAL, "Stars Hollow")
	Game.save_game.call_deferred()


func _finish() -> void:
	# The chapter's quest is over: the crack by the old oak opens again
	if chapter == "":
		return
	if not chapter in done:
		done.append(chapter)
	chapter = ""
	just_pulled = false
	reopen_due = true
	var s := get_tree().current_scene
	if s and s.scene_file_path == EARTH:
		if EarthTown.has_method("tremor") and EarthTown.on_earth_scene():
			EarthTown.tremor()
		Juice.shake(0.3)
		Game.message(REOPENED)
	Game.save_game()


# -----------------------------------------------------------------------------
# Every frame
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		if s and s.scene_file_path == EARTH:
			_place.call_deferred(s)
			if just_pulled:
				_shut_in = SHUT_AFTER
		elif just_pulled and s != null:
			just_pulled = false               # (left Earth some other way meanwhile: nothing to snap shut)
	if s == null:
		return
	if _shut_in >= 0.0 and not Loading.showing and not _player_carried():
		_shut_in -= delta
		if _shut_in < 0.0:
			_snap_shut()
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		if chapter != "" and Quests.is_done(str(CHAPTERS[chapter].until)):
			_finish()


func _player_carried() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.get("carried") == true


func _snap_shut() -> void:
	just_pulled = false
	if not sealed():
		return
	Juice.shake(0.35)
	Juice.rumble(0.4, 0.4, 0.3)
	Audio.play("stomp", -6.0, 0.0)
	Game.message(SHUT)
	DivineMind.say([DivineMind.HINT_HOME])


func _on_quest(id: String) -> void:
	# A seasonal chapter leads to Nina's quest: once it starts, it's the one that's followed
	if chapter == "":
		return
	var until := str(CHAPTERS[chapter].until)
	if id == until and Quests.is_started(until) and not Quests.is_done(until):
		Quests.follow(until, true)


func _on_flag(f: String) -> void:
	for k in SPOTS:
		if str(k[2]) == f:
			var kind := str(k[5]).split("_")[0]
			var n := 0
			for j in SPOTS:
				if str(j[0]) == str(k[0]) and Dialogue.flags.has(str(j[2])):
					n += 1
			Game.message(str(FOUND.get(kind, "Found one! %d of 3.")) % n)
			return


# -----------------------------------------------------------------------------
# The things to find, in Stars Hollow
# -----------------------------------------------------------------------------
func _place(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.get_node_or_null("Home Calls") != null:
		return
	var holder := Node3D.new()
	holder.name = "Home Calls"
	s.add_child(holder)
	for k in SPOTS:
		_spot(holder, k)


func _spot(holder: Node3D, k: Array) -> Area3D:
	var spot := Area3D.new()
	spot.name = "Home Spot " + str(k[2])
	var kind := str(k[5])
	var before := _thing(kind, false)
	before.name = "Before"
	spot.add_child(before)
	if kind == "lamp":
		var lit := _thing(kind, true)          # (a lamp stays lit once its bulb's in)
		lit.name = "Done"
		spot.add_child(lit)
	spot.set_script(load("res://scripts/quest_spot.gd"))
	spot.set("quest", str(k[0]))
	spot.set("step", str(k[1]))
	spot.set("flag", str(k[2]))
	spot.set("action", str(k[4]))
	spot.set("radius", 2.0)
	holder.add_child(spot)
	var at: Vector2 = k[3]
	spot.global_position = _ground(Vector3(at.x, 0, at.y))
	return spot


func _ground(p: Vector3) -> Vector3:
	var s := get_tree().current_scene as Node3D
	if s == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 40, 0), p + Vector3(0, -40, 0))
	q.collide_with_areas = false
	var got := s.get_world_3d().direct_space_state.intersect_ray(q)
	return got.position if not got.is_empty() else Vector3(p.x, EarthLand.height(p.x, p.z), p.z)


func _thing(kind: String, lit: bool) -> Node3D:
	var g := Node3D.new()
	match kind:
		"chime":
			_cyl(g, 0.12, 0.05, Vector3(0, 0.62, 0), _mat(Color(0.55, 0.38, 0.25)))
			for i in 5:
				var a := TAU * i / 5.0
				_cyl(g, 0.018, 0.32 + 0.05 * i, Vector3(cos(a) * 0.09, 0.42 - 0.025 * i, sin(a) * 0.09),
					_glow(Color(0.75, 1.0, 0.9), 0.8))
			_cyl(g, 0.012, 0.3, Vector3(0, 0.78, 0), _mat(Color(0.8, 0.8, 0.85)))
		"plush_bear", "plush_bunny", "plush_frog":
			var col := {"plush_bear": Color(0.75, 0.52, 0.32), "plush_bunny": Color(1.0, 0.75, 0.88),
				"plush_frog": Color(0.45, 0.85, 0.4)}[kind] as Color
			_ball(g, 0.2, Vector3(0, 0.2, 0), _mat(col))
			_ball(g, 0.15, Vector3(0, 0.48, 0), _mat(col))
			for x in [-1.0, 1.0]:
				_ball(g, 0.03, Vector3(0.06 * x, 0.52, 0.13), _mat(Color(0.1, 0.08, 0.1)))
				if kind == "plush_bunny":
					_cyl(g, 0.04, 0.22, Vector3(0.07 * x, 0.7, 0), _mat(col))
				elif kind == "plush_bear":
					_ball(g, 0.06, Vector3(0.11 * x, 0.6, 0), _mat(col))
				else:
					_ball(g, 0.06, Vector3(0.08 * x, 0.6, 0.06), _mat(col))
		"lamp":
			_cyl(g, 0.07, 2.6, Vector3(0, 1.3, 0), _mat(Color(0.18, 0.2, 0.24)))
			_cyl(g, 0.2, 0.1, Vector3(0, 0.05, 0), _mat(Color(0.18, 0.2, 0.24)))
			_cyl(g, 0.22, 0.08, Vector3(0, 2.95, 0), _mat(Color(0.18, 0.2, 0.24)))
			_ball(g, 0.2, Vector3(0, 2.75, 0), _glow(Color(1.0, 0.88, 0.55), 3.0) if lit
				else _mat(Color(0.35, 0.35, 0.38, 0.8)))
			if lit:
				var l := OmniLight3D.new()
				l.light_color = Color(1.0, 0.85, 0.55)
				l.omni_range = 6.0
				l.light_energy = 1.2
				l.position = Vector3(0, 2.7, 0)
				g.add_child(l)
		"bottle":
			_cyl(g, 0.1, 0.32, Vector3(0, 0.1, 0), _mat(Color(0.45, 0.85, 0.75, 0.6)), Vector3(0, 0, PI / 2.3))
			_cyl(g, 0.04, 0.12, Vector3(0.2, 0.17, 0), _mat(Color(0.45, 0.85, 0.75, 0.6)), Vector3(0, 0, PI / 2.3))
			_cyl(g, 0.045, 0.05, Vector3(0.27, 0.2, 0), _mat(Color(0.7, 0.5, 0.3)), Vector3(0, 0, PI / 2.3))
			_box(g, Vector3(0.14, 0.05, 0.06), Vector3(0, 0.1, 0), _mat(Color(0.95, 0.9, 0.75)))
	return g


func _cyl(g: Node3D, r: float, h: float, at: Vector3, m: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	g.add_child(mi)


func _ball(g: Node3D, r: float, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	g.add_child(mi)


func _box(g: Node3D, size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	g.add_child(mi)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"owed": owed.duplicate(), "chapter": chapter, "done": done.duplicate(), "just_pulled": just_pulled}


func load_data(data: Dictionary) -> void:
	reset()
	for id in data.get("owed", []):
		if CHAPTERS.has(str(id)):
			owed.append(str(id))
	for id in data.get("done", []):
		if CHAPTERS.has(str(id)):
			done.append(str(id))
	var c := str(data.get("chapter", ""))
	chapter = c if CHAPTERS.has(c) else ""
	just_pulled = bool(data.get("just_pulled", false)) and chapter != ""


func reset() -> void:
	owed.clear()
	done.clear()
	chapter = ""
	just_pulled = false
	reopen_due = false
	_shut_in = -1.0
