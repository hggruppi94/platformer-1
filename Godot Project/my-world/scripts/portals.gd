extends Node

# Autoload "Portals": time quakes and the portal worlds, the levels of the game (plan items 19 and 19a, agreed with
# Hayden on 8 Nov 2026). The Void is the hub, and staying there never costs anything. Every so often in the story a
# **time quake** shakes the Void (the camera shakes, the pad rumbles, the Remnant veins flare) and a **crack** splits
# the ground open at that world's spot. Since 12 Nov 2026 (Hayden, lore bible v2) **the cracks ARE the portals**: a
# jagged glowing hole you jump into (scripts/crack.gd), nothing rises out of it. The cracks are an effect of the
# broken Shift. Each one leads to a friend's home world, where time has gone wrong and needs putting right, and the
# Divine Mind's voice (scripts/divine_mind.gd) says so when one opens.
#
# Walking up to a crack and looking down it shows a **preview** at its bottom: a little live window into the world,
# slowly circling it (a copy of the world's scene in its own SubViewport, without a player). Dark Hollow's will show
# only dark (its "preview" is false). Jumping in (or "Jump in!" at its edge) takes you there, and there's **no time
# limit** (Hayden, 12 Nov 2026: the old timer and buying minutes with Remnants are gone; Remnants are still money).
# The way home, a crack of its own in each world, takes you back to the Void with everything you found (found things
# are saved the moment they're picked up, so nothing is ever done twice). The Void's clock stands still while you're
# away: its time doesn't pass on another planet, so a trip never eats into the Shift.
#
# Clearing a world (scripts/portal_world.gd calls clear()) fixes its time, gives its reward and **changes the hub**:
# _hub_changes() puts the new things into the Void each time the town loads (nothing is built into town.tscn).
# Saved with the game as "portals" (scripts/game.gd). Saves from before have had no quakes; the first one comes
# once the First Night is done, so old saves past it get theirs on their next visit to the Void.
#
# Worlds so far: Shard Isle (the tutorial), the Rootmind, the Frozen Moment, Lanternmoor, Rhythm Springs, the Tide Reef,
# Glenmoor, Dark Hollow (no portal: the centipede gulps you down to it) and the Far Future, the last. A new world plugs
# in by adding an entry to WORLDS, a builder for the scene, and a script that extends portal_world.gd.

signal changed
signal quaked(id: String)
signal cleared(id: String)

const USE_SPOT := preload("res://scripts/use_spot.gd")

const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const CENTIPEDE_CORNER := preload("res://scripts/centipede_corner.gd")
const CENTIPEDE_HOLES := preload("res://scripts/centipede_holes.gd")
const CRACK := preload("res://scripts/crack.gd")
const QUAKE_DELAY := 6.0                # seconds after arriving in the Void before a due quake shakes it
const PREVIEW_NEAR := 14.0              # the preview window wakes up this close to a portal...
const PREVIEW_FAR := 22.0               # ...and goes to sleep again past this

# The worlds, in story order (plan item 19a). "at" is the portal's spot in the Void ([x, z], the ground's height is
# found at play time), "yaw" which way it faces. (The built worlds' spots are checked; the others are rough guesses from
# 19a, to be checked against the town when each world is built.) "scene" is "" until a world is built: it never quakes before then.
const WORLDS := [
	{"id": "shard_isle", "name": "Shard Isle", "owner": "", "scene": "res://scenes/portal_worlds/shard_isle.tscn",
		"at": Vector2(62, -58), "yaw": -0.72, "preview": true, "colour": Color(0.55, 1.0, 0.75),
		"blurb": "A floating crystal island, humming out of tune.",
		"reward_remnants": 5,
		"cleared_text": "Shard Isle hums in tune again!"},
	{"id": "rootmind", "name": "The Rootmind", "owner": "Bramble", "scene": "res://scenes/portal_worlds/rootmind.tscn",
		"at": Vector2(-70, -24), "yaw": -1.3, "preview": true, "colour": Color(0.5, 0.95, 0.4),
		"blurb": "Bramble's home. Time runs backwards!",
		"reward_remnants": 6,
		"cleared_text": "The Rootmind blinks in step again!"},
	{"id": "frozen_moment", "name": "The Frozen Moment", "owner": "Flurry",
		"scene": "res://scenes/portal_worlds/frozen_moment.tscn", "at": Vector2(46, -226), "yaw": 0.0, "preview": true,
		"colour": Color(0.7, 0.9, 1.0), "blurb": "Flurry's home. Time has stopped!",
		"reward_remnants": 7, "season": "winter",
		"cleared_text": "The Frozen Moment ticks again! Winter can come!"},
	{"id": "lanternmoor", "name": "Lanternmoor", "owner": "Pip", "scene": "res://scenes/portal_worlds/lanternmoor.tscn",
		"at": Vector2(-100, -104), "yaw": 0.77, "preview": true, "colour": Color(0.75, 0.6, 1.0),
		"blurb": "Pip's home. The sun won't rise!",
		"reward_remnants": 8,
		"cleared_text": "The sun's up over Lanternmoor!"},
	{"id": "glenmoor", "name": "Glenmoor", "owner": "Heather", "scene": "res://scenes/portal_worlds/glenmoor.tscn",
		"at": Vector2(-120, -48), "yaw": 1.19, "preview": true, "colour": Color(1.0, 0.75, 0.85),
		"blurb": "Heather's home. Day and night spin round!",
		"reward_remnants": 11, "season": "spring",
		"cleared_text": "Glenmoor's fixed! Spring can come!"},
	{"id": "tide_reef", "name": "The Tide Reef", "owner": "Otto", "scene": "res://scenes/portal_worlds/tide_reef.tscn",
		"at": Vector2(50, 28), "yaw": -2.08, "preview": true, "colour": Color(0.4, 0.8, 1.0),
		"blurb": "Otto's home. The sea's gone!",
		"reward_remnants": 10,
		"cleared_text": "The tide's back in the Tide Reef!"},
	{"id": "rhythm_springs", "name": "Rhythm Springs", "owner": "Melody", "scene": "res://scenes/portal_worlds/rhythm_springs.tscn",
		"at": Vector2(-34, 34), "yaw": 2.36, "preview": true, "colour": Color(1.0, 0.6, 0.9),
		"blurb": "Melody's home. The beat is broken!",
		"reward_remnants": 9, "season": "summer",
		"cleared_text": "The beat's back! Summer can come!"},
	# Dark Hollow (plan items 19a world 7 and 21) has no portal and never quakes: its way in is a secret, through the
	# centipede in her corner Behind the Walls in the castle school (scripts/centipede_corner.gd), who gulps you down to
	# it (enter_dark_hollow()). Going home comes out at the school's front gate ("home_spawn"), never back through the
	# dark passage. Opt-in and fully optional. ("at" is the school gate, for anything that asks where it is.)
	{"id": "dark_hollow", "name": "Dark Hollow", "owner": "the centipede", "scene": "res://scenes/portal_worlds/dark_hollow.tscn",
		"at": Vector2(15, -84), "yaw": 0.0, "preview": false, "portal": false, "home_spawn": "FromSchool",
		"colour": Color(0.6, 0.5, 1.0),
		"blurb": "The centipede's home. Shadows eat time!",
		"reward_remnants": 8,
		"cleared_text": "The Moon Clock ticks again in Dark Hollow!"},
	# The Far Future (19a world 8, the last): its portal rises out of the fault line Rex and Dash's experiments cracked,
	# just past the hedge behind their lab (scripts/lab.gd), facing back past it towards town.
	{"id": "far_future", "name": "The Far Future", "owner": "Dash and Rex", "scene": "res://scenes/portal_worlds/far_future.tscn",
		"at": Vector2(117, -18), "yaw": -1.42, "preview": true, "colour": Color(0.4, 1.0, 1.0),
		"blurb": "Dash and Rex's home. It's fading!",
		"reward_remnants": 12,
		"cleared_text": "Lumen City is lit up again!"},
]

var quakes: Array = []                  # world ids whose quake has happened (their portal stands in the Void)
var cleared_worlds: Array = []          # world ids whose time is fixed
var found := {}                         # world id -> ids of the things found there (scripts/portal_world.gd)
var here := ""                          # the world the player's in right now ("" in the Void or anywhere else)

var _scene: Node
var _holder: Node3D                     # the portals in the Void
var _in_town_for := 0.0
var _quaking := false
var _froze_clock := false               # we stopped the Void's clock, so we start it again
var _pulling := false
var _ask_world := ""                    # the portal whose "go in?" question is open
var _hud: CanvasLayer
var _card_label: Label
var stage_prize_day := -1              # the visit Melody's dance-off encore was last won (scripts/melody_stage.gd)
var practice := false                   # on a practice trip (practice_trip()): nothing is kept
var _held_before := false               # Game.hold_saves before the practice trip (tools set it), put back after


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Dialogue.finished.connect(_on_talked)
	_make_hud()


func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_arrived(s)
	if s == null:
		return
	if s.scene_file_path == TOWN:
		_process_flowers()
		_process_flurry(delta)
		_in_town_for += delta
		if not _quaking and _in_town_for >= QUAKE_DELAY and not Dialogue.is_active():
			var due := next_due()
			if due != "":
				quake(due)
		_update_previews()
		_check_down_a_crack()
	_show_card()


func _arrived(s: Node) -> void:
	_in_town_for = 0.0
	_quaking = false
	if s == null:
		return                                 # (between two scenes for a frame: wait and see where we land)
	if CRACK.came_through():
		CRACK.pop_out(get_tree())             # down one crack, up out of the one here (scripts/crack.gd)
	var came_from := here
	var w := world_for_scene(s.scene_file_path if s else "")
	if w.is_empty():
		if practice and s != null:
			end_practice.call_deferred()     # left a practice trip some other way: back to the save, just the same
			return
		if here != "":
			here = ""
			changed.emit()
		if _froze_clock:
			_froze_clock = false
			Clock.running = true
	else:
		if here != str(w.id):
			here = str(w.id)
			changed.emit()
		_pulling = false
		if Clock.running:
			Clock.running = false
			_froze_clock = true
	if s and s.scene_file_path == TOWN:
		_place_in.call_deferred(s)
		if came_from != "" and has_portal(came_from):
			_land_by.call_deferred(came_from)
	if s and s.scene_file_path == SCHOOL:
		_place_corner.call_deferred(s)                   # the secret way into Dark Hollow


func _place_corner(s: Node) -> void:
	if is_instance_valid(s):
		CENTIPEDE_CORNER.place(s)


func _land_by(id: String) -> void:
	# Back from a world: stand on the ground just in front of its portal. (go_home() can't measure the ground from
	# inside the world, so the resume point is only roughly right: on a hill like the Rootmind's it'd be inside it.)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var w := world(id)
	if player == null or w.is_empty():
		return
	var front := Vector2(sin(float(w.yaw)), cos(float(w.yaw))) * 3.2
	player.global_position = Remnants.ground_at(w.at + front) + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO


# -----------------------------------------------------------------------------
# The worlds
# -----------------------------------------------------------------------------
func world(id: String) -> Dictionary:
	for w in WORLDS:
		if w.id == id:
			return w
	return {}


func world_for_scene(path: String) -> Dictionary:
	if path == "":
		return {}
	for w in WORLDS:
		if str(w.scene) == path:
			return w
	return {}


func is_world_scene(path: String) -> bool:
	return not world_for_scene(path).is_empty()


func is_built(id: String) -> bool:
	var w := world(id)
	return not w.is_empty() and str(w.scene) != "" and ResourceLoader.exists(str(w.scene))


func has_portal(id: String) -> bool:
	# Every world but Dark Hollow has a portal in the Void
	return bool(world(id).get("portal", true))


func is_open(id: String) -> bool:
	return id in quakes


func is_cleared(id: String) -> bool:
	return id in cleared_worlds


func open_worlds() -> Array:
	return WORLDS.filter(func(w: Dictionary) -> bool: return is_open(str(w.id)) and has_portal(str(w.id)))


func spot(id: String) -> Vector3:
	# Where its portal stands in the Void (on the ground)
	var w := world(id)
	return Remnants.ground_at(w.at) if get_tree().current_scene else Vector3(w.at.x, 0.0, w.at.y)


# -----------------------------------------------------------------------------
# Time quakes
# -----------------------------------------------------------------------------
func quake_due(id: String) -> bool:
	# Has the story got to this world's quake? (Only built worlds ever quake.)
	if is_open(id) or not is_built(id):
		return false
	match id:
		"shard_isle":
			return Quests.is_done(FirstNight.ID)
		"rootmind":
			# After the tutorial world, once Bramble's Harvest has begun (so you know her, and her garden's yours)
			return is_cleared("shard_isle") and Quests.is_started(Remnants.QUEST)
		"frozen_moment":
			return is_cleared("rootmind")                 # the next world in the story, once Bramble's is mended
		"lanternmoor":
			return is_cleared("frozen_moment")            # and then Pip's, once Flurry's ticks again
		# Spring before summer (Hayden, 12 Nov 2026: "lets swap the order of the spring and summer worlds"):
		# Glenmoor is fifth, the Tide Reef sixth and Rhythm Springs seventh.
		"glenmoor":
			return is_cleared("lanternmoor")              # then Heather's, once Pip's sun is up
		"tide_reef":
			return is_cleared("glenmoor")                 # then Otto's, once Glenmoor's day and night settle
		"rhythm_springs":
			return is_cleared("tide_reef")                # then Melody's, once Otto's tide is in
		"far_future":
			# And last, Dash and Rex's (Dark Hollow's optional). All three of the middle worlds, not just Rhythm
			# Springs: a save from before the swap may have mended Melody's world and not yet Heather's.
			return is_cleared("glenmoor") and is_cleared("tide_reef") and is_cleared("rhythm_springs")
	return false


func next_due() -> String:
	for w in WORLDS:
		if quake_due(str(w.id)):
			return str(w.id)
	return ""


func quake(id: String, instant := false) -> void:
	# The Void shakes and the ground cracks open: the crack is the way through. (instant: no show, for tests and tools.)
	if is_open(id):
		return
	quakes.append(id)
	var w := world(id)
	if instant or not is_instance_valid(_holder):
		_place_portal(id, false)
		changed.emit()
		quaked.emit(id)
		Game.save_game()
		return
	_quaking = true
	Game.message("A TIME QUAKE! Something cracks open by %s." % near_words(id))
	Audio.play("stomp", -2.0)
	Juice.shake(0.5)
	Juice.rumble(0.6, 0.8, 0.4)
	_flare_veins()
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		Juice.shake(0.35)
		Juice.rumble(0.4, 0.5, 0.2)
		_place_portal(id, true))
	tw.tween_interval(3.0)
	tw.tween_callback(func() -> void:
		_quaking = false
		Game.message("A crack by %s! It leads to %s." % [near_words(id), w.name])
		DivineMind.say(["Feel that? Something broke.",
			"A world needs you!"])
		changed.emit()
		quaked.emit(id)
		Game.save_game())


func near_words(id: String) -> String:
	match id:
		"shard_isle":
			return "the field below Observatory Hill"
		"rootmind":
			return "the Secret Gardens, by your garden"
		"frozen_moment":
			return "the foot of the mountains, far north past the castle"
		"lanternmoor":
			return "the Spooky Woods, on the way to the Haunted House"
		"glenmoor":
			return "the meadow past the farm, west of the Secret Gardens"
		"tide_reef":
			return "the lake's south-east shore"
		"rhythm_springs":
			return "the lake's south-west shore"
		"far_future":
			return "the hedge behind the lab"
	return "the town"


func _flare_veins() -> void:
	# The Remnant veins glow brighter for a moment: the quake is time itself moving
	var veins := _scene.get_node_or_null("Remnants") if _scene else null
	if veins == null:
		return
	for v in veins.get_children():
		var glow := v.get_node_or_null("Glow") as OmniLight3D
		if glow and glow.visible:
			var was := glow.light_energy
			var tw := glow.create_tween()
			tw.tween_property(glow, "light_energy", was * 4.0, 0.3)
			tw.tween_property(glow, "light_energy", was, 2.0)


# -----------------------------------------------------------------------------
# Going in, and coming home
# -----------------------------------------------------------------------------
func enter(id: String) -> bool:
	# Down the crack, into the world. Stay as long as you like.
	if not is_open(id) or not is_built(id):
		return false
	var w := world(id)
	Game.pending_message = "%s! The crack behind you goes home." % w.name
	Game.go(str(w.scene), "Entrance", str(w.name))
	return true


func enter_dark_hollow() -> bool:
	# The centipede's gulp (scripts/centipede_corner.gd): no portal, no question here (she asked), just the free stretch
	var id := "dark_hollow"
	if not is_built(id):
		return false
	var w := world(id)
	Game.pending_message = "PTOO! The centipede spat you out, gently, in %s." % w.name
	if not is_cleared(id):
		Game.pending_message += " She waves and scuttles off."
	else:
		Game.pending_message += " The way home takes you to the school's front gate."

	Game.go(str(w.scene), "Entrance", str(w.name))
	return true


func go_home(why := "") -> void:
	# Back to the portal in the Void, with everything found (it's already saved). The way home is always free.
	var id := here
	if id == "" or _pulling:
		return
	if practice:
		end_practice()
		return
	_pulling = true
	var w := world(id)
	if not has_portal(id):
		if id == "dark_hollow" and is_cleared(id) and not CENTIPEDE_HOLES.gifts_given():
			# The first time home after mending it, the way out comes up by her hollow log behind the old gate, where
			# she lives now and is waiting to say thank you (scripts/scary_world.gd)
			Game.pending_message = why if why != "" else "Somewhere new... Somebody's waiting."
			Game.go_to_point(CENTIPEDE_HOLES.SCARY, CENTIPEDE_HOLES.HOME_AT, CENTIPEDE_HOLES.HOME_YAW, "Dusk's Embrace")
			return
		# No portal to land by (Dark Hollow): out at its "home_spawn", the castle school's front gate
		Game.pending_message = why if why != "" else "Back in the Void, out at the castle school's front gate."
		Game.go(TOWN, str(w.get("home_spawn", "")), "the Void")
		return
	Game.pending_message = why if why != "" else "Back in the Void, by the crack to %s." % w.name
	var face := float(w.yaw)
	var out := Vector3(sin(face), 0, cos(face)) * 3.2           # just in front of the portal
	# (a little above the ground, which can't be measured from here: the player drops gently onto it)
	Game.go_to_point(TOWN, Vector3(w.at.x, 1.5, w.at.y) + out, face, "the Void")


# -----------------------------------------------------------------------------
# Practice trips (playtesting, 9 Nov 2026: Hayden wanted to get into the worlds without waiting for the Shift, the
# quakes or the story). Pause menu > "Visit a portal world", once Settings > Assist > "Practice trips" is on.
# Any built world, from anywhere, at any time, played from the start (as if nothing was found there yet). Nothing done on a practice trip is kept: the game is saved just before it, saving is held all the way
# through (Game.hold_saves), and coming home loads that save again, back where they were. So a kid can try every
# world on their real save and it's just the same afterwards.
# -----------------------------------------------------------------------------
func can_practice(id: String) -> bool:
	return is_built(id) and not _pulling


func practice_trip(id: String) -> bool:
	if not can_practice(id):
		return false
	var w := world(id)
	if not practice:
		Game.save_game()                    # everything up to now is kept...
		_held_before = Game.hold_saves
		Game.hold_saves = true              # ...and nothing from here on is
		practice = true
	# Played from the start: as if never found or mended (only in memory: the save on disk keeps the real ones)
	found.erase(id)
	cleared_worlds.erase(id)
	if not id in quakes:
		quakes.append(id)
	here = ""
	Playtest.note("practice_trip", {"world": id})
	Game.pending_message = "Practice trip to %s! Nothing is kept." % w.name
	Game.go(str(w.scene), "Entrance", str(w.name))
	changed.emit()
	return true


func end_practice() -> void:
	# Back to the save made just before the trip, exactly where they were
	if not practice:
		return
	practice = false
	Game.hold_saves = _held_before
	Playtest.note("practice_end", {"world": here})
	Game._reset_state()
	Game.load_game()
	Game.pending_message = "Back from your practice trip."
	Game.continue_game()


# -----------------------------------------------------------------------------
# Clearing a world
# -----------------------------------------------------------------------------
func clear(id: String) -> void:
	if is_cleared(id) or world(id).is_empty():
		return
	cleared_worlds.append(id)
	var w := world(id)
	open_seasons()
	var n := int(w.get("reward_remnants", 0))
	if n > 0:
		Remnants.add(n)
	Game.message(str(w.get("cleared_text", "%s's time is fixed!" % w.name)) + ("  (+%d Remnants)" % n if n > 0 else ""))
	Juice.blip("chime", 1.0, -4.0)
	DivineMind.say(["Well done. Time flows again."])
	changed.emit()
	cleared.emit(id)
	Game.save_game()


func open_seasons() -> void:
	# Each season but autumn waits in a portal world (WORLDS "season", plan item 20): mending it opens it on Earth
	for id in cleared_worlds:
		var season := str(world(str(id)).get("season", ""))
		if season != "":
			Clock.open_season(season)


func season_world(season: String) -> Dictionary:
	# The world a locked season waits in (the Calendar sheet's hint)
	for w in WORLDS:
		if str(w.get("season", "")) == season:
			return w
	return {}


func note_found(id: String, thing: String) -> void:
	# Something found in a world (a crystal, a part...): remembered for good, so it's never there to find twice
	var list: Array = found.get(id, [])
	if thing in list:
		return
	list.append(thing)
	found[id] = list
	changed.emit()
	Game.save_game()


func has_found(id: String, thing: String) -> bool:
	return thing in found.get(id, [])


# -----------------------------------------------------------------------------
# The portals in the Void
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null("Portals") != null:
		return
	_holder = Node3D.new()
	_holder.name = "Portals"
	s.add_child(_holder)
	for id in quakes:
		_place_portal(str(id), false)
	_hub_changes(s)


func _place_portal(id: String, rising: bool) -> void:
	# The crack itself, cut into the ground at the world's spot. Rising: it splits open in front of you.
	if not is_instance_valid(_holder) or _holder.get_node_or_null("Portal " + id) != null or not has_portal(id):
		return
	var w := world(id)
	var g := portal_model(w.colour, _jump_in.bind(id))
	g.name = "Portal " + id
	_holder.add_child(g)
	g.global_position = Remnants.ground_at(w.at)
	g.rotation.y = float(w.yaw)
	CRACK.sink(g, _scene if is_instance_valid(_scene) else get_tree().current_scene)
	var spot := USE_SPOT.make(Vector3(0, 0, CRACK.R + 1.0), _portal_offer.bind(id), _use_portal.bind(id), 2.4, 3.0)
	spot.name = "Spot"
	g.add_child(spot)
	if id == "far_future":
		g.add_child(fault_line(w.colour))
	if rising:
		var at := g.global_position
		CRACK.set_open(g, 0.0)
		Juice.dust(_holder, at, 1.0)
		Fx.burst(_holder, at + Vector3(0, 0.5, 0), w.colour, 30, 0.1, 5.0, -4.0, 1.2)
		var tw := g.create_tween()
		tw.tween_method(func(k: float) -> void: CRACK.set_open(g, k), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func() -> void:
			Fx.burst(_holder, at + Vector3(0, 0.8, 0), w.colour, 26, 0.08, 3.0, -1.0, 1.0)
			Juice.blip("chime", 0.8, -6.0))


func crack(id: String) -> Node3D:
	# A world's crack in the Void, if it's open and the Void's loaded
	return _holder.get_node_or_null("Portal " + id) as Node3D if is_instance_valid(_holder) else null


func _jump_in(id: String) -> void:
	# Dropped down the crack (scripts/crack.gd's fall area)
	if _quaking or not is_built(id) or Dialogue.is_active():
		return
	enter(id)


func _check_down_a_crack() -> void:
	# Anyone standing down in a crack goes through, even if they fell in while it couldn't take them (mid-quake, or
	# mid-talk): the fall area only notices someone coming in
	if _quaking or Dialogue.is_active() or not is_instance_valid(_holder):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for id in quakes:
		var g := crack(str(id))
		if g == null or g.has_meta("falling") or not CRACK.is_open(g):
			continue
		var d := Vector2(player.global_position.x - g.global_position.x, player.global_position.z - g.global_position.z)
		if d.length() < CRACK.R and player.global_position.y < g.global_position.y - 0.8:
			CRACK.fall_in(g, player, _jump_in.bind(str(id)))
			return


func _portal_offer(id: String) -> String:
	if _quaking or not is_built(id):
		return ""
	return "look down the crack to %s" % world(id).name


func _use_portal(id: String) -> void:
	var w := world(id)
	var spot := _holder.get_node_or_null("Portal %s/Spot" % id) as Node3D if is_instance_valid(_holder) else null
	if spot == null:
		enter(id)
		return
	_ask_world = id
	var lines: Array = [str(w.blurb)]
	if str(w.owner) != "":
		lines.append("It's %s's home world." % w.owner)
	if is_cleared(id):
		lines.append("Fixed already! Visit any time.")
	lines.append("Jump in!")
	lines.append({"choice": [{"text": "Jump in!", "set": "portal_go", "say": false}, {"text": "Not now.", "say": false}]})
	Dialogue.say(spot, "Crack to %s" % w.name, lines, "portal_ask")


func _on_talked(id: String) -> void:
	if id != "portal_ask":
		return
	var go := Dialogue.flags.has("portal_go")
	Dialogue.flags.erase("portal_go")
	var w := _ask_world
	_ask_world = ""
	if w != "" and go:
		var g := crack(w)
		if g:
			CRACK.drop_player(g)            # over its middle: they drop in, and the fall takes them through
		else:
			enter(w)


func _update_previews() -> void:
	# A portal's live window wakes up when the player's near it and sleeps again when they walk off
	if not is_instance_valid(_holder):
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for id in quakes:
		var g := _holder.get_node_or_null("Portal " + str(id)) as Node3D
		if g == null:
			continue
		var d := player.global_position.distance_to(g.global_position)
		var view := g.get_node_or_null("Preview") as SubViewport
		if view == null and d < PREVIEW_NEAR and not _quaking:
			_open_preview(g, str(id))
		elif view and d > PREVIEW_FAR:
			_close_preview(g)
		view = g.get_node_or_null("Preview") as SubViewport
		if view:
			var cam := view.get_node_or_null("Cam") as Camera3D
			if cam:
				var t := Time.get_ticks_msec() / 1000.0 * 0.15
				var r: float = cam.get_meta("radius", 30.0)
				var c: Vector3 = cam.get_meta("centre", Vector3.ZERO)
				cam.position = c + Vector3(cos(t) * r * 0.35, r * 0.9, sin(t) * r * 0.35)
				cam.look_at(c, Vector3.UP)


func preview_scene(id: String) -> Node3D:
	# A copy of the world for the portal's window: the same scene, without anyone to play it
	var w := world(id)
	if not bool(w.preview) or not is_built(id):
		return null
	var copy := (load(str(w.scene)) as PackedScene).instantiate() as Node3D
	copy.set_meta("preview", true)          # (so its script knows it's only a picture: scripts/portal_world.gd)
	var player := copy.get_node_or_null("Player")
	if player:
		copy.remove_child(player)
		player.free()
	return copy


func _open_preview(g: Node3D, id: String) -> void:
	var copy := preview_scene(id)
	var disc := g.get_node("Swirl") as MeshInstance3D
	if copy == null:
		return                              # (Dark Hollow's shows only dark: the swirl stays as it is)
	var view := SubViewport.new()
	view.name = "Preview"
	view.size = Vector2i(320, 320)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	g.add_child(view)
	view.add_child(copy)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 60.0
	var centre := copy.get_node_or_null("PreviewCentre") as Node3D
	cam.set_meta("centre", centre.position if centre else Vector3.ZERO)
	cam.set_meta("radius", float(copy.get_meta("preview_radius", 30.0)))
	view.add_child(cam)
	cam.current = true
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = view.get_texture()
	m.emission_enabled = true
	m.emission_texture = view.get_texture()
	m.emission_energy_multiplier = 0.4
	disc.set_meta("swirl", disc.material_override)
	disc.material_override = m


func _close_preview(g: Node3D) -> void:
	var view := g.get_node_or_null("Preview")
	var disc := g.get_node("Swirl") as MeshInstance3D
	if disc.has_meta("swirl"):
		disc.material_override = disc.get_meta("swirl")
	if view:
		view.queue_free()
		view.name = "Closing"


func _hub_changes(s: Node) -> void:
	# What clearing worlds has changed in the Void
	if is_cleared("shard_isle"):
		var w := world("shard_isle")
		var plaza := plaza_model(w.colour)
		plaza.name = "Portal Plaza"
		_holder.add_child(plaza)
		plaza.global_position = Remnants.ground_at(w.at)
		plaza.rotation.y = float(w.yaw)
	if is_cleared("rootmind"):
		_watching_flowers()
	if is_cleared("frozen_moment"):
		_flurry_in_hub()
	if is_cleared("rhythm_springs"):
		_melody_stage()
	if is_cleared("tide_reef"):
		_otto_in_hub()
	if is_cleared("glenmoor"):
		_blossom_orchard()
	if is_cleared("dark_hollow") and CENTIPEDE_HOLES.gifts_given():
		_centipede_holes()                                    # once she's shared her gifts at home (scripts/scary_world.gd)
	# The story's ending: Rex and Rook back in their own bodies, and Dash gone home (scripts/after_the_ending.gd)
	(load("res://scripts/after_the_ending.gd") as GDScript).call("void_changes", s)


func _centipede_holes() -> void:
	# Dark Hollow's reward: the centipede's holes round the Void, to knock on and travel by her gulp
	# (scripts/centipede_holes.gd; her other gift, wall crawl, is the player's own: scripts/wall_crawl.gd)
	var h: Node3D = (load("res://scripts/centipede_holes.gd") as GDScript).new()
	h.name = "Centipede Holes"
	_holder.add_child(h)


func _watching_flowers() -> void:
	# The Rootmind's reward: a ring of flowers with eyes round its portal, and a row along your garden's fence, that
	# turn to watch you go by (scripts/rootmind.gd's eyeflower_model)
	var rootmind := load("res://scripts/rootmind.gd")
	var g := Node3D.new()
	g.name = "Watching Flowers"
	_holder.add_child(g)
	var colours := [Color(1.0, 0.55, 0.75), Color(0.75, 0.55, 1.0), Color(1.0, 0.8, 0.35), Color(0.55, 0.8, 1.0)]
	var w := world("rootmind")
	var spots: Array = []
	for k in 12:
		var a := k * TAU / 12.0
		if absf(wrapf(a - float(w.yaw), -PI, PI)) < 0.5:
			continue                         # leave the front of the portal clear
		spots.append(w.at + Vector2(sin(a), cos(a)) * 4.6)
	var fence: Vector2 = Farm.plot_half()
	for k in 8:
		var x := -7.0 + k * 2.0
		if absf(x) > 1.5:                    # the gate's in the middle of the south side: keep it clear
			spots.append(Farm.GARDEN + Vector2(x, fence.x + 1.0))
	for i in spots.size():
		var f: Node3D = rootmind.eyeflower_model(colours[i % colours.size()], 1.0 + (i % 3) * 0.2)
		f.name = "Watching Flower"
		g.add_child(f)
		f.global_position = Remnants.ground_at(spots[i])


# Melody's Stage, in the Void once Rhythm Springs is mended ------------------------------------------------------------
const MELODY_STAGE := Vector2(-32.5, 42.5)  # just behind her portal on the lake's south-west shore (checked flat, clear, off the races and paths)
const MELODY_STAGE_YAW := 2.49              # facing the lake over her portal


func _melody_stage() -> void:
	# Her stage by her portal, where she puts on a show every evening (scripts/melody_stage.gd)
	var stage := Node3D.new()
	stage.set_script(load("res://scripts/melody_stage.gd"))
	stage.name = "Melody's Stage"
	_holder.add_child(stage)
	stage.global_position = Remnants.ground_at(MELODY_STAGE)
	stage.rotation.y = MELODY_STAGE_YAW


# Heather's blossom orchard, in the Void once Glenmoor's mended ----------------------------------------------------
const ORCHARD := Vector2(-125.5, -61.5)     # just south-west of Glenmoor's portal (checked flat, clear, off the races, paths and trees)
const ORCHARD_GAP := 4.5                    # metres between the trees
const ORCHARD_PETALS := [Color(1.0, 0.75, 0.85), Color(1.0, 0.86, 0.92), Color(0.98, 0.66, 0.8)]


func _blossom_orchard() -> void:
	# Glenmoor's spring came through with you: nine blossom trees in rows in the meadow by its portal, petals drifting
	# down, two Fluffkins grazing under them and a sign
	var g := Node3D.new()
	g.name = "Blossom Orchard"
	_holder.add_child(g)
	g.global_position = _still_ground(ORCHARD)
	# (Find every spot's ground first: new trunks aren't where they belong to the physics until the next step)
	var spots: Array[Vector3] = []
	for ix in [-1, 0, 1]:
		for iz in [-1, 0, 1]:
			spots.append(_still_ground(ORCHARD + Vector2(ix, iz) * ORCHARD_GAP + Vector2(0.4 * ((ix + iz) % 2), 0.3 * ix)))
	var grazing: Array[Vector3] = []
	for i in 2:
		grazing.append(_still_ground(ORCHARD + Vector2(-2.2 + i * 4.4, 2.3 - i * 4.6)))
	for k in spots.size():
		var t := blossom_tree_model(ORCHARD_PETALS[k % ORCHARD_PETALS.size()], 1.0 + 0.12 * ((k * 5) % 3))
		t.name = "Blossom Tree %d" % (k + 1)
		t.position = spots[k] - g.global_position
		t.rotation.y = k * 1.7
		g.add_child(t)
	var glen := load("res://scripts/glenmoor.gd")
	for i in 2:
		var f: Node3D = glen.fluffkin_model(i)
		f.name = "Fluffkin %d" % (i + 1)
		f.position = grazing[i] - g.global_position
		f.rotation.y = 0.8 + i * 2.5
		g.add_child(f)
	var petals := CPUParticles3D.new()
	petals.name = "Petals"
	petals.amount = 60
	petals.lifetime = 6.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(ORCHARD_GAP * 1.6, 0.5, ORCHARD_GAP * 1.6)
	petals.position.y = 4.5
	petals.direction = Vector3(0.3, -1, 0.1)
	petals.spread = 25.0
	petals.gravity = Vector3(0.2, -0.35, 0)
	petals.initial_velocity_min = 0.2
	petals.initial_velocity_max = 0.5
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	var pm := QuadMesh.new()
	pm.size = Vector2(0.12, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ORCHARD_PETALS[0]
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.material = mat
	petals.mesh = pm
	g.add_child(petals)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "Heather's Blossom Orchard"
	sign.font_size = 64
	sign.pixel_size = 0.01
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.9, 0.95)
	sign.position = Vector3(0, 5.6, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)


func _still_ground(at: Vector2) -> Vector3:
	# The ground there, looking past anyone who happens to be walking by (a Gloop, the player)
	var space := (_holder as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 300.0, at.y), Vector3(at.x, -60.0, at.y))
	var skip: Array[RID] = []
	for i in 6:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		if hit.collider is StaticBody3D:
			return hit.position
		skip.append(hit.rid)
	return Remnants.ground_at(at)


static func blossom_tree_model(petal: Color, size := 1.0) -> Node3D:
	# A round blossom tree: a short twisty trunk (solid, so you go round it) and a big soft crown of pink puffs
	var t := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.28 * size
	cy.height = 2.2 * size
	cs.shape = cy
	cs.position.y = 1.1 * size
	t.add_child(cs)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.42, 0.3, 0.24)
	bark.roughness = 0.9
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.18 * size
	tm.bottom_radius = 0.3 * size
	tm.height = 2.4 * size
	tm.radial_segments = 8
	trunk.mesh = tm
	trunk.material_override = bark
	trunk.position.y = 1.2 * size
	trunk.rotation.z = 0.08
	t.add_child(trunk)
	var bloom := StandardMaterial3D.new()
	bloom.albedo_color = petal
	bloom.roughness = 0.85
	bloom.emission_enabled = true
	bloom.emission = petal
	bloom.emission_energy_multiplier = 0.12
	var rng := RandomNumberGenerator.new()
	rng.seed = int(petal.r * 1000.0) + int(size * 100.0)
	for k in 7:
		var p := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.7, 1.0) * size
		sm.height = sm.radius * 1.7
		sm.radial_segments = 10
		sm.rings = 5
		p.mesh = sm
		p.material_override = bloom
		var a := k * TAU / 6.0
		p.position = (Vector3(cos(a) * 0.9, 2.9 + rng.randf_range(-0.2, 0.3), sin(a) * 0.9) if k < 6 else Vector3(0, 3.5, 0)) * size
		t.add_child(p)
	return t


# Otto, in the Void once the Tide Reef's mended --------------------------------------------------------------------
const OTTO_SPOT := Vector2(3.1, -1.8)      # on the Portal Plaza, round the side from Flurry and clear of the trees (in the plaza's frame)


func _otto_in_hub() -> void:
	# He came through in his bubble chair, with a friend floating it along, and waits on the Portal Plaza with the
	# other chosen ones (I looked for room for a reef pool by the lake for him, but the lakeside's full)
	var w := world("shard_isle")
	var at: Vector2 = w.at + OTTO_SPOT.rotated(-float(w.yaw))
	var g := Node3D.new()
	g.name = "Otto"
	_holder.add_child(g)
	g.global_position = Remnants.ground_at(at)
	g.rotation.y = float(w.yaw)
	var model: Node3D = load("res://scripts/tide_reef.gd").otto_model()
	model.name = "Model"
	g.add_child(model)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Otto", _talk_otto, 2.4, 2.4)
	spot.name = "Spot"
	g.add_child(spot)


func otto_hub_lines() -> Array:
	if not has_found("tide_reef", "otto_in_hub"):
		note_found("tide_reef", "otto_in_hub")
		return ["{player}! Over here! Dash floated me through.",
			"So THIS is the Void. Very... dry.",
			"You can swim in any deep water here!",
			"Try Willow Pond on Earth! {dash} dives.",
			"Deep water keeps secrets!"]
	return [["Flurry and me are best friends now!"],
		["Look! Eight cups of tea at once!"],
		["Your lake looks like a puddle trying its best."],
		["I've got lots of friends now!"],
		["Time drops things. Deep water keeps them.",
		"Try the Wishing Well past the plaza!"]].pick_random()


func _talk_otto() -> void:
	var spot := _holder.get_node_or_null("Otto/Spot") as Node3D if is_instance_valid(_holder) else null
	if spot:
		Dialogue.say(spot, "Otto", otto_hub_lines().map(func(l: String) -> String: return Settings.fill(l)), "hub_otto")


# Flurry, in the Void once the Frozen Moment's mended -------------------------------------------------------------
const FLURRY_SPOT := Vector2(3.3, 1.3)     # on the Portal Plaza, beside Shard Isle's portal (in the plaza's frame)
const FLURRY_FLAKES := 40


func _flurry_in_hub() -> void:
	# She comes back with you and waits on the Portal Plaza, where the chosen ones' portals gather, in a little
	# patch of snow with her own flurry falling over her (she's never without one now that snow can fall)
	var w := world("shard_isle")
	var at: Vector2 = w.at + FLURRY_SPOT.rotated(-float(w.yaw))
	var g := Node3D.new()
	g.name = "Flurry"
	_holder.add_child(g)
	g.global_position = Remnants.ground_at(at)
	g.rotation.y = float(w.yaw)
	var patch := MeshInstance3D.new()
	patch.name = "Snow Patch"
	var c := CylinderMesh.new()
	c.top_radius = 1.1
	c.bottom_radius = 1.25
	c.height = 0.08
	c.radial_segments = 24
	patch.mesh = c
	patch.material_override = _mat(Color(0.95, 0.97, 1.0), 0.9)
	patch.position.y = 0.11                  # just over the plaza's floor
	g.add_child(patch)
	var model: Node3D = load("res://scripts/frozen_moment.gd").flurry_model()
	model.position.y = 0.12
	g.add_child(model)
	var spot := USE_SPOT.make(Vector3.ZERO, func() -> String: return "talk to Flurry", _talk_flurry, 2.4, 2.4)
	spot.name = "Spot"
	g.add_child(spot)
	var flakes := MultiMeshInstance3D.new()
	flakes.name = "Her Flurry"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var fm := _mat(Color(1, 1, 1), 1.0, 0.6)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = fm
	mm.mesh = q
	mm.instance_count = FLURRY_FLAKES
	flakes.multimesh = mm
	flakes.set_meta("seeds", range(FLURRY_FLAKES).map(func(k) -> Vector3:
		return Vector3(randf_range(-1.5, 1.5), randf_range(0.0, 3.2), randf_range(-1.5, 1.5))))
	g.add_child(flakes)


func flurry_hub_lines() -> Array:
	# Flurry in the Void: still a bit shy, but she found you first this time
	var lines: Array = []
	if not has_found("frozen_moment", "flurry_in_hub"):
		note_found("frozen_moment", "flurry_in_hub")
		lines = ["Oh! {player}! I came through after you. OK?",
			"It's so warm and green here!",
			"Watch this! (Huff! Frost sparkles out.)",
			"My frost breath makes ice you can walk on!",
			"Can I come with you? Press {frost_breath} and I'll huff!"]
		Dialogue.flags["party_asked_flurry"] = true
		lines.append_array(Party.ask_lines("flurry"))
	elif not Dialogue.flags.has("party_yes_flurry") and (not Dialogue.flags.has("party_asked_flurry") or randi() % 3 == 0):
		# She'd like to come along with you (scripts/party.gd), and asks again now and then after a "not yet"
		Dialogue.flags["party_asked_flurry"] = true
		lines = ["{player}... can I come with you?",
			"I'll do my frost breath for you!"]
		lines.append_array(Party.ask_lines("flurry"))
	else:
		lines = [["Tick, tick. I missed my watch ticking.",
			"Do you have snow days on Earth?"],
			["Bramble's plants stared at me. I stared back."],
			["Be careful in the portal worlds, OK?"],
			["Winter comes to Stars Hollow now. I made sure!"],
			["At a pond, press {frost_breath} for ice islands!",
			"They melt, so hop hop hop!"]].pick_random()
	return lines


func _talk_flurry() -> void:
	var spot := _holder.get_node_or_null("Flurry/Spot") as Node3D if is_instance_valid(_holder) else null
	if spot:
		Dialogue.say(spot, "Flurry", flurry_hub_lines().map(func(l: Variant) -> Variant: return Settings.fill(l) if l is String else l),
			"hub_flurry")


func _process_flurry(delta: float) -> void:
	# Her snow keeps falling round her, and she turns to look at you when you come near
	var g := _holder.get_node_or_null("Flurry") as Node3D if is_instance_valid(_holder) else null
	if g == null:
		return
	var flakes := g.get_node("Her Flurry") as MultiMeshInstance3D
	var seeds: Array = flakes.get_meta("seeds")
	var t := Time.get_ticks_msec() / 1000.0
	for k in seeds.size():
		var p: Vector3 = seeds[k]
		var y := fposmod(p.y - t * 0.6, 3.2)
		flakes.multimesh.set_instance_transform(k, Transform3D(Basis(), Vector3(p.x + sin(t + k) * 0.15, y, p.z)))
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var m := g.get_node_or_null("Model") as Node3D
	if player == null or m == null:
		return
	var to := player.global_position - m.global_position
	if Vector2(to.x, to.z).length() < 9.0:
		m.rotation.y = lerp_angle(m.rotation.y, atan2(to.x, to.z) - g.global_rotation.y, minf(1.0, delta * 4.0))


func _process_flowers() -> void:
	# The watching flowers turn their heads to follow the player
	var g := _holder.get_node_or_null("Watching Flowers") if is_instance_valid(_holder) else null
	if g == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for f in g.get_children():
		var head := f.get_node("Head") as Node3D
		var to := player.global_position - head.global_position
		if Vector2(to.x, to.z).length() < 25.0:
			head.rotation.y = lerp_angle(head.rotation.y, atan2(to.x, to.z), 0.06)


# -----------------------------------------------------------------------------
# The world's name on screen on a practice trip (there's no timer: no time limit since 12 Nov 2026)
# -----------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var box := PanelContainer.new()
	box.name = "Card"
	box.add_theme_stylebox_override("panel", UiStyle.card(Color(0.16, 0.1, 0.26, 0.85)))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-110, 12)
	box.custom_minimum_size = Vector2(220, 0)
	_card_label = Label.new()
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_card_label)
	_hud.add_child(box)
	box.visible = false


func _show_card() -> void:
	var box := _card_label.get_parent() as Control
	var on := practice and here != "" and not _pulling and get_tree().current_scene != null
	box.visible = on
	box.modulate.a = 0.0 if get_tree().get_first_node_in_group("cutscene_playing") else 1.0
	if on:
		_card_label.text = "%s  practice trip" % world(here).name
		_card_label.modulate = Color(0.85, 1.0, 0.9)
		box.position.x = box.get_parent_area_size().x / 2.0 - box.size.x / 2.0 if box.get_parent_area_size().x > 0 else box.position.x


func card_text() -> String:
	return _card_label.text if (_card_label.get_parent() as Control).visible else ""


# -----------------------------------------------------------------------------
# Looks, made from shapes
# -----------------------------------------------------------------------------
static func _mat(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func fault_line(colour: Color) -> Node3D:
	# The Far Future's portal stands on the fault line Rex and Dash's experiments cracked open: a long zigzag crack in
	# the ground, glowing at its edges, running from the portal towards the back of their lab (the portal's front, +Z;
	# it stops short of the yard fence)
	var g := Node3D.new()
	g.name = "Fault Line"
	var dark := _mat(Color(0.04, 0.02, 0.08), 0.9)
	var edge := _mat(colour, 0.3, 2.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var at := Vector3(rng.randf_range(-0.3, 0.3), 0.0, 2.9)    # (starting past the crack's broken edge)
	while at.z < 6.2:
		var to := Vector3(clampf(at.x + rng.randf_range(-0.9, 0.9), -1.4, 1.4), 0.0, at.z + rng.randf_range(1.0, 1.8))
		var d := to - at
		var seg := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.3, 0.6), 0.05, d.length() + 0.2)
		seg.mesh = b
		seg.material_override = dark
		seg.position = (at + to) / 2.0 + Vector3(0, 0.03, 0)
		seg.rotation.y = atan2(d.x, d.z)
		g.add_child(seg)
		var lip := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(b.size.x + 0.12, 0.03, d.length() + 0.25)
		lip.mesh = lb
		lip.material_override = edge
		lip.position = seg.position + Vector3(0, -0.005, 0)
		lip.rotation.y = seg.rotation.y
		g.add_child(lip)
		at = to
	return g


static func portal_model(colour: Color, on_fall: Callable = Callable()) -> Node3D:
	# A crack in the ground: the way through (scripts/crack.gd). Call CRACK.sink() once it's in place to cut the ground.
	return CRACK.make(colour, on_fall)


static func plaza_model(colour: Color) -> Node3D:
	# The Portal Plaza (Shard Isle's reward): a round floor of pale stone round the portal, crystal pillars, little
	# benches and a sign. More portals' signs will join it as worlds are cleared.
	var g := Node3D.new()
	var floor := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 5.8
	c.bottom_radius = 5.9
	c.height = 0.12
	c.radial_segments = 40
	floor.mesh = c
	floor.material_override = _mat(Color(0.82, 0.78, 0.92), 0.8)
	floor.position.y = 0.04
	g.add_child(floor)
	var inlay := MeshInstance3D.new()
	var ti := TorusMesh.new()
	ti.inner_radius = 5.0
	ti.outer_radius = 5.3
	ti.rings = 40
	inlay.mesh = ti
	inlay.material_override = _mat(colour, 0.3, 1.2)
	inlay.scale = Vector3(1, 0.1, 1)
	inlay.position.y = 0.11
	g.add_child(inlay)
	var gem_mat := _mat(colour, 0.15, 1.4)
	for k in 6:
		var a := PI / 6.0 + k * TAU / 6.0
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.6:
			continue                         # leave the front open, where the portal faces
		var p := Vector3(cos(a) * 5.4, 0, sin(a) * 5.4)
		var base := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.35
		bc.bottom_radius = 0.45
		bc.height = 1.0
		bc.radial_segments = 8
		base.mesh = bc
		base.material_override = Remnants.obsidian_mat()
		base.position = p + Vector3(0, 0.5, 0)
		g.add_child(base)
		var gem := MeshInstance3D.new()
		gem.mesh = Remnants.crystal_mesh(0.3, 2.2)
		gem.material_override = gem_mat
		gem.position = p + Vector3(0, 2.1, 0)
		g.add_child(gem)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = 0.45
		cy.height = 3.2
		cs.shape = cy
		cs.position = p + Vector3(0, 1.6, 0)
		body.add_child(cs)
		g.add_child(body)
	var sign := Label3D.new()
	sign.text = "Portal Plaza"
	sign.font_size = 80
	sign.pixel_size = 0.01
	sign.outline_size = 14
	sign.modulate = Color(1, 0.95, 0.8)
	sign.position = Vector3(0, 5.8, 0)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	g.add_child(sign)
	return g


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"quakes": quakes.duplicate(), "cleared": cleared_worlds.duplicate(), "found": found.duplicate(true),
		"here": here, "stage_prize_day": stage_prize_day}


func load_data(data: Dictionary) -> void:
	reset()
	for id in data.get("quakes", []):
		if not world(str(id)).is_empty() and not str(id) in quakes:
			quakes.append(str(id))
	for id in data.get("cleared", []):
		if not world(str(id)).is_empty() and not str(id) in cleared_worlds:
			cleared_worlds.append(str(id))
	var f = data.get("found", {})
	if f is Dictionary:
		for k in f:
			if f[k] is Array:
				found[str(k)] = (f[k] as Array).map(func(x) -> String: return str(x))
	stage_prize_day = int(data.get("stage_prize_day", -1))
	changed.emit()


func reset() -> void:
	if practice:                            # (a new game started mid practice trip: saving goes back on)
		practice = false
		Game.hold_saves = _held_before
	quakes.clear()
	cleared_worlds.clear()
	found.clear()
	here = ""
	stage_prize_day = -1
	_pulling = false
	if _froze_clock:
		_froze_clock = false
		Clock.running = true
	changed.emit()
