extends Node

# Autoload "Portals": time quakes and the portal worlds, the levels of the game (plan items 19 and 19a, agreed with
# Hayden on 8 Nov 2026). The Void is the hub, and staying there never costs anything. Every so often in the story a
# **time quake** shakes the Void (the camera shakes, the pad rumbles, the Remnant veins flare), a **crevice** cracks
# open in the ground at that world's spot, and a **portal** rises out of it. Each portal leads to one chosen one's
# home planet, where time has gone wrong and needs putting right.
#
# Walking up to a portal shows a **preview**: a little live window into the world, slowly circling it (a copy of the
# world's scene in its own SubViewport, without a player). Dark Hollow's will show only dark (its "preview" is false).
# Going in is free for FREE_SECONDS; Remnants at the portal (or at the Time Stone inside) buy SECONDS_PER_REMNANT
# more each. A gentle **timer** shows top-centre while you're there. When it runs out you float back to the portal in
# the Void with everything you found (found things are saved the moment they're picked up, so nothing is ever done
# twice). The Void's clock stands still while you're away: its time doesn't pass on another planet, so a trip never
# eats into the Shift.
#
# Clearing a world (scripts/portal_world.gd calls clear()) fixes its time, gives its reward and **changes the hub**:
# _hub_changes() puts the new things into the Void each time the town loads (nothing is built into town.tscn).
# Saved with the game as "portals" (scripts/game.gd). Saves from before have had no quakes; the first one comes
# once the First Night is done, so old saves past it get theirs on their next visit to the Void.
#
# Worlds so far: Shard Isle (the tutorial). The rest of 19a plug in by adding an entry to WORLDS, a builder for the
# scene, and a script that extends portal_world.gd.

signal changed
signal quaked(id: String)
signal cleared(id: String)

const USE_SPOT := preload("res://scripts/use_spot.gd")

const TOWN := "res://scenes/town/town.tscn"
const FREE_SECONDS := 240.0             # every trip starts with 4 free minutes...
const SECONDS_PER_REMNANT := 60.0       # ...and each Remnant spent adds one more
const EXTRA_AT_PORTAL := 2              # the portal's "take extra time" choice spends this many
const WARN_AT := 30.0                   # "nearly time to go" with this many seconds left
const QUAKE_DELAY := 6.0                # seconds after arriving in the Void before a due quake shakes it
const PREVIEW_NEAR := 14.0              # the preview window wakes up this close to a portal...
const PREVIEW_FAR := 22.0               # ...and goes to sleep again past this

# The worlds, in story order (plan item 19a). "at" is the portal's spot in the Void ([x, z], the ground's height is
# found at play time), "yaw" which way it faces. (Only Shard Isle's spot is checked; the others are rough guesses from
# 19a, to be checked against the town when each world is built.) "scene" is "" until a world is built: it never quakes before then.
const WORLDS := [
	{"id": "shard_isle", "name": "Shard Isle", "owner": "", "scene": "res://scenes/portal_worlds/shard_isle.tscn",
		"at": Vector2(62, -58), "yaw": -0.72, "preview": true, "colour": Color(0.55, 1.0, 0.75),
		"blurb": "A little floating island of crystals: a broken bit of the brain land, humming out of tune.",
		"reward_remnants": 5,
		"cleared_text": "Shard Isle hums in tune again! Back in the Void, a Portal Plaza has grown round its portal."},
	{"id": "rootmind", "name": "The Rootmind", "owner": "Bramble", "scene": "res://scenes/portal_worlds/rootmind.tscn",
		"at": Vector2(-70, -24), "yaw": -1.3, "preview": true, "colour": Color(0.5, 0.95, 0.4),
		"blurb": "Bramble's home, where every plant has eyes, and time is running backwards.",
		"reward_remnants": 6,
		"cleared_text": "The Rootmind blinks in step again! Back in the Void, watching flowers have sprung up round its portal and your garden."},
	{"id": "frozen_moment", "name": "The Frozen Moment", "owner": "Flurry",
		"scene": "res://scenes/portal_worlds/frozen_moment.tscn", "at": Vector2(46, -226), "yaw": 0.0, "preview": true,
		"colour": Color(0.7, 0.9, 1.0), "blurb": "Flurry's home, where time has stopped mid-moment: snowflakes hang in the air.",
		"reward_remnants": 7, "season": "winter",
		"cleared_text": "The Frozen Moment ticks again! Snow is falling for the first time in for ever, and winter can come to Stars Hollow at last."},
	{"id": "lanternmoor", "name": "Lanternmoor", "owner": "Pip", "scene": "", "at": Vector2(-110, -120), "yaw": 0.0,
		"preview": true, "colour": Color(0.75, 0.6, 1.0), "blurb": "Pip's home, where the sun won't rise."},
	{"id": "rhythm_springs", "name": "Rhythm Springs", "owner": "Melody", "scene": "", "at": Vector2(-36, 64),
		"yaw": 0.0, "preview": true, "colour": Color(1.0, 0.6, 0.9), "blurb": "Melody's home, where the beat is broken.", "season": "summer"},
	{"id": "tide_reef", "name": "The Tide Reef", "owner": "the octopus", "scene": "", "at": Vector2(-48, 10),
		"yaw": 0.0, "preview": true, "colour": Color(0.4, 0.8, 1.0), "blurb": "A reef city whose tide is stuck out."},
	{"id": "glenmoor", "name": "Glenmoor", "owner": "Heather", "scene": "", "at": Vector2(-96, -38), "yaw": 0.0,
		"preview": true, "colour": Color(1.0, 0.85, 0.5), "blurb": "Heather's misty hills, where the seasons spin.", "season": "spring"},
	{"id": "far_future", "name": "The Far Future", "owner": "Dash and Rex", "scene": "", "at": Vector2(84, 90),
		"yaw": 0.0, "preview": true, "colour": Color(0.4, 1.0, 1.0), "blurb": "Dash and Rex's home, fading away."},
]
# (Dark Hollow isn't here: you get in through the Sliver in the castle school, not a crevice. Plan item 21.)

var quakes: Array = []                  # world ids whose quake has happened (their portal stands in the Void)
var cleared_worlds: Array = []          # world ids whose time is fixed
var found := {}                         # world id -> ids of the things found there (scripts/portal_world.gd)
var here := ""                          # the world the player's in right now ("" in the Void or anywhere else)
var time_left := 0.0                    # seconds left on this trip

var _scene: Node
var _holder: Node3D                     # the portals in the Void
var _in_town_for := 0.0
var _quaking := false
var _froze_clock := false               # we stopped the Void's clock, so we start it again
var _warned := false
var _pulling := false
var _ask_world := ""                    # the portal whose "go in?" question is open
var _hud: CanvasLayer
var _timer_label: Label
var practice := false                   # on a practice trip (practice_trip()): no time limit, and nothing is kept
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
	elif here != "" and not _pulling:
		if not Dialogue.is_active() and not get_tree().paused and not practice:
			time_left = maxf(time_left - delta, 0.0)
		if time_left <= WARN_AT and not _warned:
			_warned = true
			Game.message("Your portal time is nearly up! Spend a Remnant at the Time Stone for more, or head home.")
		if time_left <= 0.0:
			time_up()
	_show_timer()


func _arrived(s: Node) -> void:
	_in_town_for = 0.0
	_quaking = false
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
			if time_left <= 0.0:
				time_left = FREE_SECONDS    # (a save made inside keeps its time; arriving fresh gets the free stretch)
			changed.emit()
		_warned = time_left <= WARN_AT
		_pulling = false
		if Clock.running:
			Clock.running = false
			_froze_clock = true
	if s and s.scene_file_path == TOWN:
		_place_in.call_deferred(s)
		if came_from != "":
			_land_by.call_deferred(came_from)


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


func is_open(id: String) -> bool:
	return id in quakes


func is_cleared(id: String) -> bool:
	return id in cleared_worlds


func open_worlds() -> Array:
	return WORLDS.filter(func(w: Dictionary) -> bool: return is_open(str(w.id)))


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
	return false


func next_due() -> String:
	for w in WORLDS:
		if quake_due(str(w.id)):
			return str(w.id)
	return ""


func quake(id: String, instant := false) -> void:
	# The Void shakes, a crevice cracks open and the portal rises out of it. (instant: no show, for tests and tools.)
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
	Game.message("The ground shakes... a TIME QUAKE! Something is cracking open by %s." % _near_words(id))
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
		Game.message("A portal has risen out of the crack! Go and look: it leads to %s." % w.name)
		changed.emit()
		quaked.emit(id)
		Game.save_game())


func _near_words(id: String) -> String:
	match id:
		"shard_isle":
			return "the field below Observatory Hill"
		"rootmind":
			return "the Secret Gardens, by your garden"
		"frozen_moment":
			return "the foot of the mountains, far north past the castle"
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
func enter(id: String, extra_remnants := 0) -> bool:
	# Through the portal. Extra Remnants buy more time on top of the free stretch.
	if not is_open(id) or not is_built(id):
		return false
	if extra_remnants > 0 and not Remnants.spend(extra_remnants):
		return false
	time_left = FREE_SECONDS + extra_remnants * SECONDS_PER_REMNANT
	_warned = false
	var w := world(id)
	Game.pending_message = "%s! You've got %s here. The portal behind you goes home any time." % [w.name, time_words(time_left)]
	Game.go(str(w.scene), "Entrance", str(w.name))
	return true


func add_time(remnants: int) -> bool:
	# The Time Stone inside a world: Remnants for more time
	if remnants <= 0 or not Remnants.spend(remnants):
		return false
	time_left += remnants * SECONDS_PER_REMNANT
	_warned = time_left <= WARN_AT
	Game.message("+%s of portal time! (%s left)" % [time_words(remnants * SECONDS_PER_REMNANT), time_words(time_left)])
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
	time_left = 0.0
	Game.pending_message = why if why != "" else "Back in the Void, by the portal to %s." % world(id).name
	var w := world(id)
	var face := float(w.yaw)
	var out := Vector3(sin(face), 0, cos(face)) * 3.2           # just in front of the portal
	# (a little above the ground, which can't be measured from here: the player drops gently onto it)
	Game.go_to_point(TOWN, Vector3(w.at.x, 1.5, w.at.y) + out, face, "the Void")


func time_up() -> void:
	go_home("Your portal time ran out, so the portal pulled you gently home. Everything you found came with you!")


static func time_words(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 60 and s % 60 == 0:
		return "%d minute%s" % [s / 60, "" if s / 60 == 1 else "s"]
	return "%d:%02d" % [s / 60, s % 60]


# -----------------------------------------------------------------------------
# Practice trips (playtesting, 9 Nov 2026: Hayden wanted to get into the worlds without waiting for the Shift, the
# quakes or the story). Pause menu > "Visit a portal world", once Settings > Assist > "Practice trips" is on.
# Any built world, from anywhere, at any time, played from the start (as if nothing was found there yet), with no
# time limit. Nothing done on a practice trip is kept: the game is saved just before it, saving is held all the way
# through (Game.hold_saves), and coming home loads that save again, back where they were. So a kid can try every
# world on their real save and it's just the same afterwards.
# -----------------------------------------------------------------------------
const PRACTICE_SECONDS := 99.0 * 60.0       # (the timer doesn't run on a practice trip; this is just "lots")


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
	time_left = PRACTICE_SECONDS
	_warned = false
	Playtest.note("practice_trip", {"world": id})
	Game.pending_message = "Practice trip to %s! No time limit, and nothing here is kept. The portal behind you, or Pause > End practice trip, takes you back." % w.name
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
	Game.pending_message = "Back from your practice trip. Everything's just as it was."
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
	if not is_instance_valid(_holder) or _holder.get_node_or_null("Portal " + id) != null:
		return
	var w := world(id)
	var g := portal_model(w.colour)
	g.name = "Portal " + id
	_holder.add_child(g)
	g.global_position = Remnants.ground_at(w.at)
	g.rotation.y = float(w.yaw)
	var spot := USE_SPOT.make(Vector3(0, 0, 1.2), _portal_offer.bind(id), _use_portal.bind(id), 2.8, 4.2)
	spot.name = "Spot"
	g.add_child(spot)
	if rising:
		var ring := g.get_node("Ring") as Node3D
		var crack := g.get_node("Crack") as Node3D
		ring.position.y = -6.0
		crack.scale = Vector3(0.05, 1.0, 0.05)
		var at := g.global_position
		Juice.dust(_holder, at, 1.0)
		Fx.burst(_holder, at + Vector3(0, 0.5, 0), w.colour, 30, 0.1, 5.0, -4.0, 1.2)
		var tw := g.create_tween()
		tw.tween_property(crack, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ring, "position:y", 0.0, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			Fx.burst(_holder, at + Vector3(0, 3.0, 0), w.colour, 26, 0.08, 3.0, -1.0, 1.0)
			Juice.blip("chime", 0.8, -6.0))


func _portal_offer(id: String) -> String:
	if _quaking or not is_built(id):
		return ""
	return "step through to %s" % world(id).name


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
		lines.append("You fixed its time already. You can still visit!")
	lines.append("The portal will hold you there for %s. A Remnant buys a minute more." % time_words(FREE_SECONDS))
	var choice: Array = [{"text": "Step through! (%s)" % time_words(FREE_SECONDS), "set": "portal_go", "say": false}]
	if Remnants.count >= EXTRA_AT_PORTAL:
		choice.append({"text": "Take extra time (%s for +%s)" % [Remnants.words(EXTRA_AT_PORTAL),
			time_words(EXTRA_AT_PORTAL * SECONDS_PER_REMNANT)], "set": "portal_go_extra", "say": false})
	choice.append({"text": "Not now.", "say": false})
	lines.append({"choice": choice})
	Dialogue.say(spot, "Portal to %s" % w.name, lines, "portal_ask")


func _on_talked(id: String) -> void:
	if id != "portal_ask":
		return
	var go := Dialogue.flags.has("portal_go")
	var extra := Dialogue.flags.has("portal_go_extra")
	Dialogue.flags.erase("portal_go")
	Dialogue.flags.erase("portal_go_extra")
	var w := _ask_world
	_ask_world = ""
	if w != "" and (go or extra):
		enter(w, EXTRA_AT_PORTAL if extra else 0)


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
				cam.position = c + Vector3(cos(t) * r, r * 0.45, sin(t) * r)
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
	var disc := g.get_node("Ring/Swirl") as MeshInstance3D
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
	var disc := g.get_node("Ring/Swirl") as MeshInstance3D
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
		lines = ["Oh! {player}! I... I came through after you. Is that OK?",
			"It's so warm here. And green! My snow keeps following me about, look.",
			"Dash says your Earth has seasons. Winter got stuck in my moment too, so now it can come to you.",
			"Oh! And... I want to give you something. Here. Breathe in, then huff, like this. (A puff of frost sparkles out of her.)",
			"Now you can do it too! Press {frost_breath}. It freezes water into ice you can walk on, and it makes Gloops go all slow.",
			"I'll stay here by the portals. Come and say hi?"]
	else:
		lines = [["Tick, tick, tick. I keep listening to my watch. I missed it.",
			"Do you have snow days on Earth? Real ones? With sledges?"],
			["Bramble showed me her garden. The plants stared at me. I stared back.",
			"I think we're friends now. The plants and me."],
			["If you go into another portal world... be careful, OK?",
			"Time's broken in lots of places. You're good at fixing it, though."],
			["It's winter in Stars Hollow when the calendar gets there. I made sure.",
			"(She looks very pleased with herself, then very shy about it.)"],
			["Have you tried your frost breath on a pond? {frost_breath}! Little ice islands, all the way across.",
			"They melt after a bit, so don't stand about. Hop hop hop!"]].pick_random()
	return lines


func _talk_flurry() -> void:
	var spot := _holder.get_node_or_null("Flurry/Spot") as Node3D if is_instance_valid(_holder) else null
	if spot:
		Dialogue.say(spot, "Flurry", flurry_hub_lines().map(func(l: String) -> String: return Settings.fill(l)), "hub_flurry")


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
# The timer on screen
# -----------------------------------------------------------------------------
func _make_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var box := PanelContainer.new()
	box.name = "Timer"
	box.add_theme_stylebox_override("panel", UiStyle.card(Color(0.16, 0.1, 0.26, 0.85)))
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-110, 12)
	box.custom_minimum_size = Vector2(220, 0)
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_timer_label)
	_hud.add_child(box)
	box.visible = false


func _show_timer() -> void:
	var box := _timer_label.get_parent() as Control
	var on := here != "" and not _pulling and get_tree().current_scene != null
	box.visible = on
	if on:
		_timer_label.text = "⏳ %s  %s" % [world(here).name, time_words(time_left)]
		if practice:
			_timer_label.text = "%s  practice: no time limit" % world(here).name
		var low := time_left <= WARN_AT and not practice
		_timer_label.modulate = Color(1.0, 0.7, 0.6) if low else Color(0.85, 1.0, 0.9)
		box.position.x = box.get_parent_area_size().x / 2.0 - box.size.x / 2.0 if box.get_parent_area_size().x > 0 else box.position.x


func timer_text() -> String:
	return _timer_label.text if (_timer_label.get_parent() as Control).visible else ""


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


static func portal_model(colour: Color) -> Node3D:
	# A jagged crack in the ground, glowing at its edges, and a standing ring of crystal-studded obsidian rising out of
	# it with a swirl inside (the swirl turns into the preview window when the player's near)
	var g := Node3D.new()
	var crack := Node3D.new()
	crack.name = "Crack"
	g.add_child(crack)
	var dark := _mat(Color(0.04, 0.02, 0.08), 0.9)
	var edge := _mat(colour, 0.3, 2.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var x := -5.5
	while x < 5.5:
		var w := rng.randf_range(0.5, 1.2)
		var len := rng.randf_range(1.2, 2.0)
		var seg := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(len, 0.06, w)
		seg.mesh = b
		seg.material_override = dark
		seg.position = Vector3(x + len / 2.0, 0.03, rng.randf_range(-0.6, 0.6))
		seg.rotation.y = rng.randf_range(-0.5, 0.5)
		crack.add_child(seg)
		var lip := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(len * 0.9, 0.08, 0.08)
		lip.mesh = lb
		lip.material_override = edge
		lip.position = seg.position + Vector3(0, 0.01, w * 0.5)
		lip.rotation.y = seg.rotation.y
		crack.add_child(lip)
		x += len * 0.8
	var ring := Node3D.new()
	ring.name = "Ring"
	g.add_child(ring)
	var torus := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.85
	t.outer_radius = 2.35
	t.rings = 32
	t.ring_segments = 10
	torus.mesh = t
	torus.material_override = Remnants.obsidian_mat()
	torus.rotation.x = PI / 2.0
	torus.position.y = 2.6
	ring.add_child(torus)
	var gem_mat := _mat(colour, 0.15, 1.6)
	for k in 10:
		var a := k * TAU / 10.0
		var gem := MeshInstance3D.new()
		gem.mesh = Remnants.crystal_mesh(0.16, 0.6 if k % 2 == 0 else 0.4)
		gem.material_override = gem_mat
		gem.position = Vector3(cos(a) * 2.4, 2.6 + sin(a) * 2.4, 0.0)
		gem.rotation.z = a - PI / 2.0
		ring.add_child(gem)
	var swirl := MeshInstance3D.new()
	swirl.name = "Swirl"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.9
	disc.bottom_radius = 1.9
	disc.height = 0.04
	disc.radial_segments = 32
	swirl.mesh = disc
	var sm := _mat(colour.darkened(0.3), 0.2, 1.4)
	sm.albedo_color.a = 0.85
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swirl.material_override = sm
	swirl.rotation.x = PI / 2.0
	swirl.position.y = 2.6
	ring.add_child(swirl)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0, 2.6, 1.0)
	ring.add_child(light)
	var body := StaticBody3D.new()
	for side in [-1, 1]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.5, 5.0, 0.6)
		cs.shape = bs
		cs.position = Vector3(side * 2.1, 2.5, 0)
		body.add_child(cs)
	ring.add_child(body)
	return g


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
		"here": here, "time_left": time_left}


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
	time_left = maxf(float(data.get("time_left", 0.0)), 0.0) if str(data.get("here", "")) != "" else 0.0
	changed.emit()


func reset() -> void:
	if practice:                            # (a new game started mid practice trip: saving goes back on)
		practice = false
		Game.hold_saves = _held_before
	quakes.clear()
	cleared_worlds.clear()
	found.clear()
	here = ""
	time_left = 0.0
	_warned = false
	_pulling = false
	if _froze_clock:
		_froze_clock = false
		Clock.running = true
	changed.emit()
