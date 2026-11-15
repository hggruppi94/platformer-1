extends Node

# The friend walking with you cheers when something good happens (overnight polish, 15 Nov 2026): a lost watch found,
# a level gained, or a quest finished. They hop with a squash, a heart or a star pops up over their head and floats
# away, and a little chime plays. No words (Hayden's less-reading rule) and nothing stops play. A "Cheer" node under
# the Party autoload (scripts/party.gd). Tests: tools/test_friend_cheer.gd.

const EMOTES := {"watch": "★", "level": "★", "quest": "♥"}
const COLOURS := {"watch": Color(1.0, 0.85, 0.35), "level": Color(0.55, 1.0, 0.85), "quest": Color(1.0, 0.5, 0.75)}
const GAP := 1.2                               # seconds between cheers, so a pile of things at once is one cheer
const RISE := 1.1                              # metres the emote floats up
const LIFE := 1.1

var cheers := 0                                # how many times a friend has cheered (for tests)
var last_kind := ""
var _last_at := -10.0


func _ready() -> void:
	_hook.call_deferred()                     # after every autoload is in


func _hook() -> void:
	Watches.found_watch.connect(func(_id: String) -> void: cheer("watch"))
	Game.leveled_up.connect(func(_level: int) -> void: cheer("level"))
	Quests.changed.connect(func(id: String) -> void:
		if Quests.is_done(id):
			cheer("quest"))


func friends_here() -> Array:
	# The friend (or friends: Nina and Bruno go together) walking with you in this place: a copy following you, or
	# their own town self tagging along in the Void
	var out: Array = []
	for f in Party.followers():
		out.append(f)
	var who := Party.current()
	if who == "" or not is_inside_tree():
		return out
	var ids: Array = Party.friend(who).get("town", [])
	for r in get_tree().get_nodes_in_group("routines"):
		if str(r.get("character_id")) in ids and r.get_parent() is Node3D and (r.get_parent() as Node3D).is_visible_in_tree():
			out.append(r.get_parent())
	return out


func cheer(kind: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_at < GAP:
		return false
	var who := friends_here()
	if who.is_empty():
		return false
	_last_at = now
	cheers += 1
	last_kind = kind
	for f in who:
		_hop(f as Node3D, kind)
	Juice.blip("chime", 1.25, -10.0)
	return true


func _hop(f: Node3D, kind: String) -> void:
	if f == null or not is_instance_valid(f) or not f.is_inside_tree():
		return
	var look: Node3D = f.get("model") as Node3D if "model" in f and f.get("model") is Node3D else null
	if look == null:
		look = f.find_child("Model", false, false) as Node3D
	Juice.squash(look if look else f, 0.25, 0.25)
	var mark := Label3D.new()
	mark.name = "Cheer"
	mark.text = str(EMOTES.get(kind, "★"))
	mark.font_size = 120
	mark.pixel_size = 0.004
	mark.modulate = COLOURS.get(kind, Color.WHITE)
	mark.outline_size = 18
	mark.outline_modulate = Color(0.15, 0.05, 0.25)
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	f.add_child(mark)
	mark.position = Vector3(0, 2.2, 0)
	var tw := mark.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mark, "position:y", 2.2 + RISE, LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(mark, "modulate:a", 0.0, LIFE).set_delay(LIFE * 0.4)
	tw.chain().tween_callback(mark.queue_free)
