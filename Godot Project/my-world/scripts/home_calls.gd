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
	# Errands (overnight polish, 15 Nov 2026: "going home always has something fun to do"): little jobs for
	# neighbours, any time once the old oak's woken. They never open or shut the crack. First drafts for Hayden.
	["errand_song", "find", "song_1", Vector2(19.5, -19.0), "pick up the song sheet", "song"],
	["errand_song", "find", "song_2", Vector2(1.8, -33.0), "pick up the song sheet", "song"],
	["errand_song", "find", "song_3", Vector2(-45.0, -16.0), "pick up the song sheet", "song"],
	["errand_books", "find", "book_1", Vector2(-50.0, 23.0), "pick up the book", "book"],
	["errand_books", "find", "book_2", Vector2(-26.0, 60.0), "pick up the book", "book"],
	["errand_books", "find", "book_3", Vector2(-1.8, -79.0), "pick up the book", "book"],
	["errand_newts", "find", "newt_1", Vector2(-55.0, 13.0), "catch the newt", "newt"],
	["errand_newts", "find", "newt_2", Vector2(-24.5, 40.0), "catch the newt", "newt"],
	["errand_newts", "find", "newt_3", Vector2(-45.0, 11.5), "catch the newt", "newt"],
	["errand_toys", "find", "toy_1", Vector2(1.8, -57.0), "catch the toy", "toy"],
	["errand_toys", "find", "toy_2", Vector2(-1.8, -68.0), "catch the toy", "toy"],
	["errand_toys", "find", "toy_3", Vector2(6.0, -92.0), "catch the toy", "toy"],
	["errand_leaves", "jump", "leaves_1", Vector2(-19.0, 19.0), "jump in the leaves", "leaves"],
	["errand_leaves", "jump", "leaves_2", Vector2(-10.0, 60.0), "jump in the leaves", "leaves"],
	["errand_leaves", "jump", "leaves_3", Vector2(-1.8, -96.0), "jump in the leaves", "leaves"],
]
const FOUND := {"chime": "A wind chime! %d of 3.", "plush": "A plushie! %d of 3.", "lamp": "Lamp lit! %d of 3.",
	"bottle": "A bottle! %d of 3.", "song": "A song sheet! %d of 3.", "book": "A book! %d of 3.",
	"newt": "Got a newt! %d of 3.", "toy": "Got a toy! %d of 3.", "leaves": "WHUMPF! %d of 3."}
# errand quest -> who gives it (they get a bobbing "!" over their head while it's on offer) and the season it's only
# offered in ("" for any)
const ERRANDS := {
	"errand_song": {"giver": "barnaby", "season": ""},
	"errand_books": {"giver": "marigold", "season": ""},
	"errand_newts": {"giver": "juniper", "season": ""},
	"errand_toys": {"giver": "otis", "season": ""},
	"errand_leaves": {"giver": "kip", "season": "autumn"},
}

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
	_bob_marks()
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_marks(s)
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
	# The chapter's quest (and the seasonal quest a chapter leads to) goes to the top of what's followed, so it's the
	# first thing on the to-do list and the map. The to-do list shows only the first few things followed, and a player
	# following a pile of board jobs never saw it (Hayden, 15 Nov 2026: "how do I know?").
	if chapter == "":
		return
	var c: Dictionary = CHAPTERS[chapter]
	if id != str(c.quest) and id != str(c.until):
		return
	if Quests.is_started(id) and not Quests.is_done(id):
		_to_top(id)


func _to_top(id: String) -> void:
	if Quests.followed.size() > 0 and Quests.followed[0] == id:
		return
	Quests.followed.erase(id)
	Quests.followed.insert(0, id)
	Quests.chose_none = false
	Quests.follow_changed.emit()


func current_quest() -> String:
	# The quest that's on now in this chapter: the seasonal one it leads to once that's started, else its own
	if chapter == "":
		return ""
	var c: Dictionary = CHAPTERS[chapter]
	var until := str(c.until)
	if Quests.is_started(until) and not Quests.is_done(until):
		return until
	var own := str(c.quest)
	if Quests.is_started(own) and not Quests.is_done(own):
		return own
	return ""


func goal() -> String:
	# What to do next to open the crack again, in the to-do list's own words ("" when no chapter's on)
	var id := current_quest()
	if id == "":
		return ""
	var o := Quests.objectives_of(id)
	for item in o.get("items", []):
		if not bool(item[1]):
			return str(item[0])
	return ""


func shut_words() -> String:
	# The crack's door, while it's shut: what to do, so nobody has to guess
	var g := goal()
	return SHUT_DOOR if g == "" else "%s %s" % [SHUT_DOOR, g]


func _pop_at(flag: String, kind: String) -> void:
	# A little moment as each one's found: a puff of colour and a sound. Jumping in the leaves sends them flying.
	var s := get_tree().current_scene
	var holder := s.get_node_or_null("Home Calls") if s else null
	var spot := holder.get_node_or_null("Home Spot " + flag) as Node3D if holder else null
	if spot == null:
		return
	if kind == "leaves":
		for c in [Color(0.95, 0.5, 0.15), Color(0.9, 0.25, 0.15), Color(1.0, 0.75, 0.2)]:
			Juice.burst(s, spot.global_position + Vector3(0, 0.4, 0), c, 14, 0.12, 4.5, 1.4)
		Audio.play("rustle", -2.0)
		Juice.shake(0.15)
		var p := get_tree().get_first_node_in_group("player") as Node3D
		var model := p.get_node_or_null("Visual") as Node3D if p else null
		if model:
			Juice.squash(model, 0.3)
	else:
		Juice.burst(s, spot.global_position + Vector3(0, 0.3, 0), Color(1.0, 0.92, 0.6), 10, 0.08, 2.5, 0.7)
		Juice.chime_pickup()


# -----------------------------------------------------------------------------
# Errands: a bobbing "!" over a neighbour with a job for you
# -----------------------------------------------------------------------------
func errand_open(id: String) -> bool:
	# Can this errand be offered right now? After the oak's woken, not started yet, and in its season if it has one
	var e: Dictionary = ERRANDS[id]
	return Dialogue.flags.has("oak_woken") and not Quests.is_started(id) \
		and (str(e.season) == "" or Clock.season() == str(e.season))


func _marks(s: Node) -> void:
	if s == null or s.scene_file_path != EARTH:
		return
	var want := {}
	for id in ERRANDS:
		if errand_open(id):
			want[str(ERRANDS[id].giver)] = true
	for t in get_tree().get_nodes_in_group("errand_givers"):
		if not want.has(str(t.get("character_id"))):
			var old := t.get_node_or_null("Errand Mark")
			if old:
				old.queue_free()
			t.remove_from_group("errand_givers")
	var missing := false
	for who in want:
		if not get_tree().get_nodes_in_group("errand_givers").any(func(t: Node) -> bool: return str(t.get("character_id")) == who):
			missing = true
	if not missing:
		return
	for t in s.find_children("*", "Area3D", true, false):
		var who := str(t.get("character_id")) if "character_id" in t else ""
		if want.has(who) and t.get_node_or_null("Errand Mark") == null:
			var mark := Label3D.new()
			mark.name = "Errand Mark"
			mark.text = "!"
			mark.font_size = 64
			mark.pixel_size = 0.01
			mark.outline_size = 14
			mark.modulate = Color(1.0, 0.85, 0.3)
			mark.outline_modulate = Color(0.25, 0.1, 0.3)
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.position.y = float(t.get("name_height")) + 0.55
			t.add_child(mark)
			t.add_to_group("errand_givers")


func _bob_marks() -> void:
	var bob := sin(Time.get_ticks_msec() / 250.0) * 0.08
	for t in get_tree().get_nodes_in_group("errand_givers"):
		var m := t.get_node_or_null("Errand Mark") as Node3D
		if m:
			m.position.y = float(t.get("name_height")) + 0.55 + bob


func _on_flag(f: String) -> void:
	for k in SPOTS:
		if str(k[2]) == f:
			var kind := str(k[5]).split("_")[0]
			var n := 0
			for j in SPOTS:
				if str(j[0]) == str(k[0]) and Dialogue.flags.has(str(j[2])):
					n += 1
			Game.message(str(FOUND.get(kind, "Found one! %d of 3.")) % n)
			_pop_at(str(k[2]), kind)
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
	elif kind == "leaves":
		var flat := _thing("leaves_done", false)   # (a pile you've jumped in stays spread about)
		flat.name = "Done"
		spot.add_child(flat)
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
		"song":
			# a sheet of music caught on the grass, propped up a little so it shows, with notes on it
			var sheet := Node3D.new()
			sheet.rotation = Vector3(-1.1, 0.4, 0)
			sheet.position = Vector3(0, 0.2, 0)
			g.add_child(sheet)
			_box(sheet, Vector3(0.34, 0.44, 0.01), Vector3.ZERO, _glow(Color(1.0, 0.97, 0.88), 0.25))
			for i in 4:
				_box(sheet, Vector3(0.28, 0.008, 0.012), Vector3(0, 0.12 - 0.07 * i, 0.006), _mat(Color(0.3, 0.25, 0.4)))
				_ball(sheet, 0.022, Vector3(-0.1 + 0.07 * i, 0.1 - 0.05 * (i % 2) - 0.07 * i, 0.012), _mat(Color(0.15, 0.1, 0.25)))
		"book":
			var col: Color = [Color(0.85, 0.3, 0.35), Color(0.3, 0.55, 0.9), Color(0.4, 0.75, 0.45)][randi() % 3]
			_box(g, Vector3(0.36, 0.07, 0.26), Vector3(0, 0.04, 0), _mat(col))
			_box(g, Vector3(0.34, 0.055, 0.24), Vector3(0.012, 0.04, 0), _mat(Color(0.98, 0.95, 0.85)))
			_box(g, Vector3(0.05, 0.075, 0.26), Vector3(-0.17, 0.04, 0), _mat(col.darkened(0.25)))
			_box(g, Vector3(0.1, 0.075, 0.03), Vector3(0.05, 0.04, 0.12), _glow(Color(1.0, 0.85, 0.4), 0.6))   # a gold label
		"newt":
			# a little orange newt with a curly tail, looking up at you
			var orange := _mat(Color(1.0, 0.5, 0.2))
			_ball(g, 0.09, Vector3(0, 0.07, 0), orange)
			_ball(g, 0.07, Vector3(0, 0.08, 0.13), orange)
			_ball(g, 0.06, Vector3(0, 0.06, -0.12), orange)
			_cyl(g, 0.025, 0.2, Vector3(0.05, 0.04, -0.25), orange, Vector3(PI / 2, 0.6, 0))
			for x in [-1.0, 1.0]:
				_ball(g, 0.022, Vector3(0.04 * x, 0.13, 0.18), _mat(Color(0.05, 0.05, 0.08)))
				for z in [0.06, -0.08]:
					_cyl(g, 0.018, 0.1, Vector3(0.09 * x, 0.03, z), orange, Vector3(0, 0, PI / 2))
			for i in 3:
				_ball(g, 0.018, Vector3(0, 0.155, 0.02 - 0.07 * i), _mat(Color(1.0, 0.85, 0.3)))     # spots
		"toy":
			# a wind-up tin robot with a key in its back
			var tin := _mat(Color(0.55, 0.75, 0.95))
			_box(g, Vector3(0.22, 0.24, 0.16), Vector3(0, 0.22, 0), tin)
			_box(g, Vector3(0.16, 0.14, 0.14), Vector3(0, 0.42, 0), tin)
			for x in [-1.0, 1.0]:
				_ball(g, 0.025, Vector3(0.04 * x, 0.44, 0.075), _glow(Color(1.0, 0.95, 0.5), 1.2))
				_box(g, Vector3(0.06, 0.1, 0.08), Vector3(0.06 * x, 0.05, 0), _mat(Color(0.3, 0.35, 0.5)))
				_cyl(g, 0.025, 0.16, Vector3(0.14 * x, 0.24, 0), tin)
			_cyl(g, 0.012, 0.1, Vector3(0, 0.52, 0), _mat(Color(0.3, 0.35, 0.5)))
			_ball(g, 0.03, Vector3(0, 0.58, 0), _glow(Color(1.0, 0.4, 0.5), 1.0))
			_box(g, Vector3(0.12, 0.06, 0.02), Vector3(0, 0.26, -0.11), _mat(Color(0.95, 0.8, 0.35)))     # the key
		"leaves", "leaves_done":
			# a big pile of autumn leaves (and once you've jumped in, the leaves spread flat all round)
			var cols := [Color(0.95, 0.5, 0.15), Color(0.9, 0.25, 0.15), Color(1.0, 0.75, 0.2), Color(0.7, 0.4, 0.2)]
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			if kind == "leaves":
				for i in 5:
					_ball(g, 0.42 - 0.05 * i, Vector3(rng.randf_range(-0.3, 0.3), 0.15 + 0.08 * i, rng.randf_range(-0.3, 0.3)),
						_mat(cols[i % cols.size()]))
			for i in 26:
				var a := rng.randf() * TAU
				var r := rng.randf_range(0.2, 1.4 if kind == "leaves_done" else 0.75)
				_box(g, Vector3(0.12, 0.012, 0.08), Vector3(cos(a) * r, 0.01, sin(a) * r), _mat(cols[i % cols.size()]))
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
