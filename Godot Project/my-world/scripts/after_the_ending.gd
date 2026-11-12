extends RefCounted

# What's different once the story's ending has happened. The ending itself plays in the Far Future
# (scripts/far_future.gd slice three, and the homecoming at the Tomorrow Clock: scripts/dash_goodbye.gd). First built
# Nov 11, 2026 as Dash's sacrifice; rewritten Nov 12, 2026 for Hayden's lore bible v2: "dash doesnt sacrifice himself.
# fixing the time shift sets everyone back in their homeworld", and only Dash, Rex and Rook could ever stay in the Void,
# stuck there until it was fixed. This file is the "after": no class_name on purpose (preload it), so --script tools can
# load it before the autoloads exist.
#
#   REX_HOME      Rex and Rook are swapped back for good: Rex is the boy, Rook is the husky again. In the Void their
#                 two models change places as the town loads (swap_in_void()), and each is dressed as the body he's in
#   DASH_GOODBYE  (the flag's old name, kept for saves) the Tomorrow Clock has struck and everyone's home. Dash, Rex
#                 and Rook live in Lumen City (the Far Future) now, so in the Void they and Dash's bike aren't there
#                 any more (void_changes()), they're left out of the Void's races and notice board requests
#                 (everyone_home()), and Dash takes the lost watches and the Pieces of That Night in Lumen City
#                 (far_future.gd hand_ins()). His gadget stall keeps going: they're still his gadgets
#
# Nothing earlier in the game says any of this is coming (Hayden's no-spoilers rule): the quest "Loose Ends" only
# starts once the Agent of Chaos's ending is over, and each step only says what's next.

const START_FLAG := "loose_ends_start"      # the quest "Loose Ends" (quests/loose_ends.json)
const REX_HOME := "rex_home"                # Rex is in his own body for good
const TWIST_FLAG := "dash_told"             # Dash has told everyone the Shift will send them all home
const DASH_GOODBYE := "dash_goodbye"        # the clock's struck and everyone's home (the old name, kept for saves)
const LETTER_FLAG := "dash_letter_read"     # you've read the letter he left in his lab
const CAP := "dash_cap"                     # what he gives you (shop/items.json, scripts/cosmetics.gd)
const HOME_IN_LUMEN := ["dash", "rex", "rook"]   # who lives in Lumen City, and isn't in the Void any more after


const TWIN_MODEL := "res://models/characters/bike_boy.glb"
const UPRIGHT := ["idle", "walk", "run"]


static func upright(model: Node, on: bool) -> void:
	# Rex's own body (rook.glb) only knows how to get about on all fours: that's Rook, a dog, inside it. With Rex back
	# in it he stands up and walks like a boy: his twin's idle, walk and run (bike_boy.glb has the same 17 bones), put
	# into a copy of this one model's animations, so Rook's crawl everywhere else is untouched. Off puts them back.
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model else null
	if ap == null or not ap.has_animation_library(""):
		return
	if on == ap.has_meta("dog_lib"):
		return
	var playing := ap.current_animation
	var lib: AnimationLibrary
	if on:
		var own := ap.get_animation_library("")
		ap.set_meta("dog_lib", own)
		lib = own.duplicate() as AnimationLibrary
		var twin := (load(TWIN_MODEL) as PackedScene).instantiate()
		var tap := twin.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var rig := str(ap.get_node(ap.root_node).get_path_to(model.find_children("*", "Skeleton3D", true, false)[0]))
		for n in UPRIGHT:
			if not tap.has_animation(n):
				continue
			var a := tap.get_animation(n).duplicate(true) as Animation
			for i in a.get_track_count():
				var path := str(a.track_get_path(i))
				a.track_set_path(i, NodePath(rig + path.substr(path.find(":"))))
			a.loop_mode = Animation.LOOP_LINEAR
			if lib.has_animation(n):
				lib.remove_animation(n)
			lib.add_animation(n, a)
		twin.free()
	else:
		lib = ap.get_meta("dog_lib") as AnimationLibrary
		ap.remove_meta("dog_lib")
	ap.stop()
	ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	ap.play(playing if playing != "" and ap.has_animation(playing) else "idle")


static func _d() -> Node:
	# The Dialogue autoload, looked up when it's needed (named straight out, this file wouldn't compile for a --script
	# tool that loads it before the autoloads are there)
	return (Engine.get_main_loop() as SceneTree).root.get_node("Dialogue")


static func everyone_home() -> bool:
	return _d().flags.has(DASH_GOODBYE)


static func rex_home() -> bool:
	return _d().flags.has(REX_HOME)


static func start_if_due() -> void:
	# The quest starts once the Agent of Chaos is beaten (scripts/chaos_ending.gd starts it as his ending finishes;
	# this catches a save from before there was an ending to come)
	if _d().flags.has("beat_agent_of_chaos") and not _d().flags.has(START_FLAG):
		_d().set_flag(START_FLAG)


static func void_changes(s: Node) -> void:
	# Portals._hub_changes() calls this each time the Void loads
	start_if_due()
	if s == null:
		return
	if everyone_home():
		# Dash, Rex and Rook are home in Lumen City: none of them is in the Void any more
		for r in s.find_children("Routine", "", true, false):
			if not str(r.get("character_id")) in HOME_IN_LUMEN:
				continue
			var bike := r.get("_bike") as Node
			if bike:
				bike.queue_free()
			var body := r.get_parent()
			# (out of the group straight away, so anything looking for him this frame doesn't find him)
			for g in body.get_groups():
				body.remove_from_group(g)
			body.queue_free()
		return
	if rex_home():
		swap_in_void(s)


static func routine_of(s: Node, id: String) -> Node:
	for r in s.find_children("Routine", "", true, false):
		if r.get("character_id") == id:
			return r
	return null


static func swap_in_void(s: Node) -> void:
	# Rex (in the husky's body all game) and Rook (in Rex's) change models, once per load
	var rex := routine_of(s, "rex")
	var rook := routine_of(s, "rook")
	if rex == null or rook == null:
		return
	var a := rex.get_parent() as Node3D
	var b := rook.get_parent() as Node3D
	if a.has_meta("own_body"):
		return
	var ma := a.get_node_or_null("Model") as Node3D
	var mb := b.get_node_or_null("Model") as Node3D
	if ma == null or mb == null:
		return
	a.remove_child(ma)
	b.remove_child(mb)
	a.add_child(mb)
	b.add_child(ma)
	mb.owner = null
	ma.owner = null
	a.set_meta("own_body", true)
	b.set_meta("own_body", true)
	# Rex walks now (a boy's legs, no paw skates) and Rook skates about on all fours (Rex's old paw-skate run: it's
	# the only way that body knows how to get about, and he loves it)
	upright(mb, true)
	rex.call("use_model", "rook", "walk", "run")
	rook.call("use_model", "rex", "skate", "skate")
	# The name over each one's head sits at the new body's height
	var ta := a.get_node_or_null("Talk")
	var tb := b.get_node_or_null("Talk")
	if ta and tb and "name_height" in ta and "name_height" in tb:
		var h: float = ta.get("name_height")
		ta.set("name_height", tb.get("name_height"))
		tb.set("name_height", h)
		for t in [ta, tb]:
			var l := t.get("_name_label") as Node3D
			var p := t.get("_prompt") as Node3D
			if l:
				l.position.y = float(t.get("name_height"))
			if p:
				p.position.y = float(t.get("name_height")) - 0.22
