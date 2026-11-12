extends Node

# Autoload "Party": the friends who walk with you and carry their own moves (plan item 26; Hayden, 12 Nov 2026: "Go
# ahead and start on the party system", from the design doc https://claude.ai/artifact/GQRGrPw2dmzQiC2fhJeMpU).
#
# Before this, every friend's move went straight onto the hero with a button of its own, and on a controller the
# on-foot buttons had grown to 18. Now the five moves that need a button (Bramble's Burrow, Flurry's Frost breath,
# Heather's April Showers, Melody's Groove, Nina and Bruno's Make) are done by ONE Friend button (Z, RB): whoever's
# walking with you does theirs. Switch friend (X, LB) swaps to the next friend who's joined with a tap, and held opens
# the friend wheel (scripts/friend_wheel.gd) to pick anyone; the HUD shows their face (scripts/friend_face.gd). Moves with no
# button (Pip's glow, Otto's swim, the centipede's wall crawl, Heather's Spring Step, Dash's kinetic energy) stay the
# hero's for good: nothing about them changes.
#
# Joining: a friend asks to come along once their world's mended, the next time you talk to them (their dialogue
# file's "party_ask" conversation; Flurry's in Portals.flurry_hub_lines()). Yes sets the flag party_yes_<id> and they
# join (recorded in Dialogue.choice_log as "party_join"); "Not yet" is fine, and they ask again now and then. Nina and
# Bruno join as they share Make with you (flag make_taught). Saves from before the party system have everyone whose
# world is mended joined already (load_data(null)).
#
# Walking with you: in the Void town the friend's own town self leaves their routine and follows you
# (scripts/routine.gd TAG_ALONG), so they can still be talked to and quests still find them. Anywhere else in the Void
# (portal worlds, the school, the rooms) a copy follows you (scripts/party_follower.gd). Not in their own home world
# (they're already there), and nobody follows you on Earth: the friends are from other worlds. Nina and Bruno live
# on Earth, so their Make still works there.
#
# Helping out: press Friend next to water with Flurry joined and she swaps in and freezes it, whoever was with you.
# In the Agent of Chaos's final fight each friend's section brings that friend along for it (bring_for(), from
# scripts/chaos_trials.gd), whether or not they've joined.

signal changed

const FRIENDS := {
	"nina_bruno": {"name": "Nina and Bruno", "move": "make", "verb": "Make", "flag": "make_taught", "earth": true,
		"models": ["res://models/characters/nina.glb", "res://models/characters/bruno.glb"], "town": ["nina", "bruno_alien"],
		"colour": Color(1.0, 0.45, 0.75)},
	"bramble": {"name": "Bramble", "move": "burrow", "verb": "Burrow", "world": "rootmind",
		"models": ["res://models/characters/plant_girl.glb"], "town": ["bramble"], "colour": Color(0.45, 0.85, 0.4)},
	"flurry": {"name": "Flurry", "move": "frost_breath", "verb": "Frost breath", "world": "frozen_moment",
		"models": ["res://scripts/frozen_moment.gd:flurry_model"], "town": [], "colour": Color(0.6, 0.85, 1.0)},
	"heather": {"name": "Heather", "move": "showers", "verb": "April Showers", "world": "glenmoor",
		"models": ["res://models/characters/cattle_girl.glb"], "town": ["clover"], "colour": Color(1.0, 0.75, 0.35)},
	"melody": {"name": "Melody", "move": "groove", "verb": "Groove", "world": "rhythm_springs",
		"models": ["res://models/characters/melody.glb"], "town": ["melody"], "colour": Color(0.75, 0.5, 1.0)},
}
const ORDER := ["nina_bruno", "bramble", "flurry", "heather", "melody"]       # the order Switch friend goes round
# The final fight's sections (scripts/chaos_trials.gd SECTIONS) that need a friend's move
const SECTION_FRIEND := {"burrow": "bramble", "frost": "flurry", "spring": "heather", "groove": "melody"}
const RECORD := "party_join"
const WATER_AHEAD := [2.0, 4.0, 6.0]           # metres in front of you Flurry looks for water to freeze
const HINT_AFTER := 4.0                         # seconds in town before "Bramble wants a word" (once)
const CARD_TIME := 3.5
const HOLD := 0.2                               # holding Switch friend this long opens the friend wheel; a tap switches
const SLOW := 0.2                               # the game's speed while the wheel's open (like the outfit wheel)

var joined: Array = []                          # friend ids, in the order they joined
var with_you := ""                              # who's walking with you ("" nobody)
var visiting := ""                              # who's come along for a final-fight section (bring_for())

var _followers: Array = []                      # copies following you (scripts/party_follower.gd)
var _built_for := ""                            # "<scene path>|<who>" the followers were made for
var _hid: Array = []                            # nodes hidden while a copy walks with you (Flurry on the plaza)
var _town_time := 0.0
var _tick := 0.0
var _card: CanvasLayer
var _card_label: Label
var _card_left := 0.0
var wheel: FriendWheel                          # the friend wheel (scripts/friend_wheel.gd)
var _wheel_layer: CanvasLayer
var _pressed := false
var _held := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Dialogue.flag_set.connect(_on_flag)
	_make_card()
	_wheel_layer = CanvasLayer.new()
	_wheel_layer.layer = 34
	add_child(_wheel_layer)
	wheel = FriendWheel.new()
	wheel.name = "Friend Wheel"
	_wheel_layer.add_child(wheel)


# ----------------------------------------------------------------------------- who's who
func friend(id: String) -> Dictionary:
	return FRIENDS.get(id, {})


func learned(id: String) -> bool:
	# Their move's been taught (their world mended, or Nina and Bruno's quest)
	var f := friend(id)
	if f.is_empty():
		return false
	if f.has("flag"):
		return Dialogue.flags.has(str(f.flag))
	return Portals.is_cleared(str(f.world))


func has_joined(id: String) -> bool:
	return id in joined


func current() -> String:
	# Who's along right now: someone brought for a final-fight section, else whoever's walking with you
	return visiting if visiting != "" else with_you


func tags_along(character_id: String) -> bool:
	# Asked by scripts/routine.gd: should this townsperson leave their schedule and walk with the player?
	var who := current()
	if who == "" or not _in_void():
		return false
	return character_id in friend(who).get("town", [])


func join(id: String, quiet := false) -> void:
	if friend(id).is_empty() or has_joined(id):
		return
	joined.append(id)
	Dialogue.flags["party_asked_" + id] = true
	Dialogue.flags["party_yes_" + id] = true
	with_you = id
	if not quiet:
		Game.message("%s %s with you now! Press %s for %s." % [friend(id).name, "are" if id == "nina_bruno" else "is",
			Settings.prompt("friend"), friend(id).verb] + ("  %s switches friend." % Settings.prompt("friend_wheel")
			if joined.size() >= 2 else ""))
		Juice.blip("chime", 1.2, -4.0)
	changed.emit()


func switch(step := 1) -> String:
	# Switch friend: round everyone who's joined, and nobody
	var r := ring()
	if r.is_empty():
		return with_you
	var at := r.find(with_you)
	return pick(str(r[posmod(at + step, r.size())]))


func ring() -> Array:
	# Who Switch friend and the wheel go round: everyone who's joined, in ORDER, then nobody
	var r: Array = ORDER.filter(func(i: String) -> bool: return has_joined(i))
	if not r.is_empty():
		r.append("")
	return r


func pick(id: String) -> String:
	# Make this friend (or nobody) the one walking with you
	if id != "" and not has_joined(id):
		return with_you
	with_you = id
	visiting = ""
	_show_card()
	Juice.blip("pop", 1.1, -6.0)
	changed.emit()
	return with_you


func bring_for(section: String) -> void:
	# The final fight (scripts/chaos_trials.gd): a section's friend comes along for it, "" when it's over
	var want := str(SECTION_FRIEND.get(section, ""))
	if want == visiting:
		return
	visiting = want
	changed.emit()


# ----------------------------------------------------------------------------- the Friend button
func can_use(player: Node) -> bool:
	return _who_for(player) != ""


func use(player: Node) -> bool:
	# Friend pressed: whoever's along does their move. Returns whether anything happened.
	var who := _who_for(player)
	if who == "":
		return false
	if who != current():
		with_you = who                              # hopped in to help (Flurry by water)
		Game.message("%s hops in to help!" % friend(who).name)
		changed.emit()
	match str(friend(who).move):
		"burrow":
			var b = player.get("burrow")
			if b == null:
				return false
			if b.active:
				b.stop(b.POP)
				return true
			return b.try_start()
		"frost_breath":
			return player.get("frost_breath") != null and player.frost_breath.try_breathe()
		"groove":
			return player.get("groove") != null and player.groove.try_groove()
		"showers":
			return player.get("showers") != null and player.showers.try_shower()
		"make":
			return player.get("make") != null and player.make.try_make()
	return false


func _who_for(player: Node) -> String:
	# Who'd answer the Friend button right now
	if player == null:
		return ""
	if not _in_void():
		return "nina_bruno" if has_joined("nina_bruno") else ""   # (only Nina and Bruno live on Earth)
	if visiting != "":
		return visiting
	if has_joined("flurry") and with_you != "flurry" and _water_ahead(player):
		return "flurry"
	return with_you if learned(with_you) else ""


func _water_ahead(player: Node) -> bool:
	var fb = player.get("frost_breath")
	if fb == null or not fb.has_method("water_under"):
		return false
	var fwd: Vector3 = fb.forward()
	var at: Vector3 = (player as Node3D).global_position
	for d in WATER_AHEAD:
		var p: Vector3 = at + fwd * float(d)
		if fb.water_under(p.x, p.z) != null:
			return true
	return false


func _in_void() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return (load("res://scripts/void_look.gd") as GDScript).call("in_void", scene)


# ----------------------------------------------------------------------------- every frame
func _process(delta: float) -> void:
	_card_left -= delta
	if _card:
		_card.visible = _card_left > 0.0
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.has_node("FriendFace"):
		var face := CanvasLayer.new()
		face.set_script(load("res://scripts/friend_face.gd"))
		face.name = "FriendFace"
		player.add_child(face)
	_wheel_input(delta)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	_keep_followers()
	_hints(0.25)


# ----------------------------------------------------------------------------- the friend wheel
func wheel_ok() -> bool:
	# Switch friend works out in the Void, with two or more friends to pick from, but not in a talk, a menu, the
	# creator, a cutscene or with another wheel up
	var p := get_tree().get_first_node_in_group("player")
	if p == null or p.get("input_locked") or p.get("carried") or get_tree().paused:
		return false
	if joined.size() < 2 or not _in_void():
		return false
	if Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or Shop.is_open() or PauseMenu.is_open():
		return false
	if QuickOutfits.wheel and QuickOutfits.wheel.open:
		return false
	var gw: Node = p.find_child("GadgetWheel", true, false)
	return not (gw and gw.get("open"))


func _wheel_input(delta: float) -> void:
	# A tap of Switch friend goes to the next friend; holding it opens the wheel, and letting go picks
	var real := delta / maxf(Engine.time_scale, 0.01)        # the wheel's own timing ignores the slow-down
	if not InputMap.has_action("friend_wheel"):
		return
	if not wheel_ok():
		if wheel.open:
			close_wheel(false)
		_pressed = false
		_held = 0.0
		return
	if Input.is_action_just_pressed("friend_wheel"):
		_pressed = true
		_held = 0.0
	if _pressed and Input.is_action_pressed("friend_wheel"):
		_held += real
		if _held >= HOLD and not wheel.open:
			open_wheel()
	elif _pressed:
		_pressed = false
		if wheel.open:
			close_wheel(true)
		else:
			switch()
	if wheel.open:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if left.length() > stick.length():
			stick = left
		var moved := false
		if stick.length() > 0.5:
			moved = wheel.point(stick.angle())
		elif wheel.mouse.length() > FriendWheel.PICK:
			moved = wheel.point(wheel.mouse.angle())
		if moved:
			Audio.play("ui_move", -10.0, 0.0)


func open_wheel() -> void:
	wheel.slots = ring()
	wheel.hover = maxi(wheel.slots.find(with_you), 0)
	wheel.mouse = Vector2.ZERO
	wheel.open = true
	Engine.time_scale = SLOW
	Audio.play("ui_move", -6.0, 0.0)
	wheel.queue_redraw()


func close_wheel(take: bool) -> void:
	wheel.open = false
	Engine.time_scale = Settings.game_speed       # back to the speed in Settings > Assist
	wheel.queue_redraw()
	if take:
		Audio.play("ui_accept", -6.0, 0.0)
		pick(wheel.picked())


func _exit_tree() -> void:
	if wheel and wheel.open:
		Engine.time_scale = Settings.game_speed


# ----------------------------------------------------------------------------- the face on the HUD
func badge_wanted() -> bool:
	# The HUD's friend badge (scripts/friend_face.gd): once someone's joined, wherever their move works, and not over
	# a talk, a menu or a wheel
	var p := get_tree().get_first_node_in_group("player")
	if p == null or joined.is_empty() or (badge_who() == "" and not _in_void()):
		return false
	if Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or Shop.is_open() or PauseMenu.is_open():
		return false
	if wheel.open or (QuickOutfits.wheel and QuickOutfits.wheel.open):
		return false
	return get_tree().get_nodes_in_group("cutscene_playing").is_empty()


func badge_who() -> String:
	# Whose face is on it: whoever's along in the Void, Nina and Bruno on Earth
	if not _in_void():
		return "nina_bruno" if has_joined("nina_bruno") else ""
	return current()


func helper() -> String:
	# Someone who isn't along but would answer the Friend button right here (Flurry by water), for the face bubble
	var who := _who_for(get_tree().get_first_node_in_group("player"))
	return who if who != "" and who != badge_who() else ""


func _keep_followers() -> void:
	# Copies follow you where the friend has no town self in this scene (portal worlds, the school, a room)
	var scene := get_tree().current_scene
	var who := current()
	var key := "%s|%s" % [scene.scene_file_path if scene else "", who]
	if key == _built_for and _followers.all(func(f) -> bool: return is_instance_valid(f)):
		return
	_clear_followers()
	_built_for = key
	if scene == null or who == "" or not _in_void() or get_tree().get_first_node_in_group("player") == null:
		return
	var f := friend(who)
	if str(f.get("world", "")) != "" and Portals.here == str(f.world):
		return                                      # they're home: their world has them in it already
	var models: Array = f.models
	var town: Array = f.get("town", [])
	for i in models.size():
		var tid := str(town[i]) if i < town.size() else ""
		if tid != "" and _has_routine(tid):
			continue                                # their own town self walks with you (routine.gd)
		var fol := (load("res://scripts/party_follower.gd") as GDScript).new() as Node3D
		fol.name = "Party %s" % (tid if tid != "" else who)
		fol.set("source", str(models[i]))
		fol.set("gap", 3.0 + 1.4 * i)
		fol.set("side", -0.9 if i == 0 and models.size() > 1 else (0.9 if i > 0 else 0.0))
		scene.add_child(fol)
		_followers.append(fol)
	if who == "flurry" and is_instance_valid(Portals._holder):
		var g := Portals._holder.get_node_or_null("Flurry") as Node3D
		if g:
			g.visible = false
			g.process_mode = Node.PROCESS_MODE_DISABLED
			_hid.append(g)


func _clear_followers() -> void:
	for f in _followers:
		if is_instance_valid(f):
			f.queue_free()
	_followers.clear()
	for n in _hid:
		if is_instance_valid(n):
			n.visible = true
			n.process_mode = Node.PROCESS_MODE_INHERIT
	_hid.clear()


func followers() -> Array:
	return _followers.filter(func(f) -> bool: return is_instance_valid(f))


func _has_routine(character_id: String) -> bool:
	for r in get_tree().get_nodes_in_group("routines"):
		if str(r.get("character_id")) == character_id:
			return true
	return false


func _hints(delta: float) -> void:
	# A friend whose world you've mended wants a word: say so once, a few seconds into the Void town
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != Portals.TOWN or Dialogue.is_active():
		_town_time = 0.0
		return
	_town_time += delta
	if _town_time < HINT_AFTER:
		return
	for id in ORDER:
		if id == "nina_bruno" or has_joined(id) or not learned(id) or Dialogue.flags.has("party_hint_" + id):
			continue
		Dialogue.flags["party_hint_" + id] = true
		var where := "on the Portal Plaza" if id == "flurry" else "somewhere in town"
		Game.message("%s wants a word with you. Find her %s!" % [friend(id).name, where])   # (all four are she)
		return


func _on_flag(flag: String) -> void:
	if flag.begins_with("party_yes_"):
		join(flag.trim_prefix("party_yes_"))
	elif flag == "make_taught":
		join("nina_bruno")


# ----------------------------------------------------------------------------- asking to join
func ask_lines(id: String) -> Array:
	# The question a friend asks once their world's mended (Flurry's; the others' are in their dialogue files)
	var f := friend(id)
	return [{"choice": [
		{"text": "Yes! Come with me!", "answer": "yes", "record": RECORD, "set": "party_yes_" + id,
			"lines": ["Really? Yay! I'll be right behind you. Press %s and I'll do my %s!" % [Settings.prompt("friend"),
				str(f.verb).to_lower()]]},
		{"text": "Not yet.", "answer": "not_yet", "record": RECORD, "set": "party_asked_" + id,
			"lines": ["That's OK! Ask me any time. Well, I'll ask you. You know what I mean."]}]}]


# ----------------------------------------------------------------------------- the card
func _make_card() -> void:
	_card = CanvasLayer.new()
	_card.layer = 6
	_card.visible = false
	add_child(_card)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 112.0                    # beside the friend badge (scripts/friend_face.gd)
	panel.offset_top = -205.0
	panel.offset_bottom = -155.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme_type_variation = &"Card"
	_card.add_child(panel)
	_card_label = Label.new()
	_card_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(_card_label)


func card_text() -> String:
	var who := with_you
	if who == "":
		return "Nobody's with you.  (%s: switch friend, hold it for the wheel)" % Settings.prompt("friend_wheel")
	var f := friend(who)
	return "%s with you.  %s: %s" % [str(f.name) + (" are" if who == "nina_bruno" else " is"), Settings.prompt("friend"), f.verb]


func _show_card() -> void:
	if _card_label:
		_card_label.text = card_text()
		_card_left = CARD_TIME


func card_shown() -> bool:
	return _card != null and _card.visible


# ----------------------------------------------------------------------------- saving
func save_data() -> Dictionary:
	return {"joined": joined.duplicate(), "with": with_you}


func load_data(data: Variant) -> void:
	reset()
	if data is Dictionary:
		for id in data.get("joined", []):
			if not friend(str(id)).is_empty() and not str(id) in joined:
				joined.append(str(id))
		with_you = str(data.get("with", ""))
		if not with_you in joined:
			with_you = ""
	else:
		# A save from before the party system: everyone whose move you'd learned has joined, and the last of them is
		# with you (so nobody loses a move they had)
		for id in ORDER:
			if learned(id):
				join(id, true)
	changed.emit()


func reset() -> void:
	joined.clear()
	with_you = ""
	visiting = ""
	_built_for = ""
	_clear_followers()
	_card_left = 0.0
