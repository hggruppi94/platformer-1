extends Node

# Autoload "Arsenal": the hero's toy gadgets, Ratchet and Clank style. Every gadget is a toy and nothing is ever hurt:
# enemies get bubbled and pop, or dance, like everywhere else in the game.
#
#   Star Popper   (scripts/star_popper.gd, star_bubble.gd) the bubble blaster she starts with. It never runs out.
#   Fizz Flinger  (scripts/fizz_bomb.gd) lobs a fizzy soda bomb in an arc that pops everything close to where it lands.
#   Disco Ball    (scripts/disco_ball.gd) floats up and spins, and every enemy near it dances till the music stops.
#   Plushinator   (scripts/plush_bolt.gd) a fluffy bolt that turns an enemy into a soft toy for a few seconds. A
#                 plushie pops at one touch of anything and gives a sparkle or two.
#   Buzz Bots     (scripts/buzz_bots.gd) three little helper bots that orbit her and bubble enemies nearby.
#   Rainbow Ray   (scripts/rainbow_ray.gd) a short beam she holds on an enemy; it fills up with colour and pops.
#   Jelly Mines   (scripts/jelly_mine.gd) wobbly jelly she drops; enemies that walk in get stuck, wobble and pop.
#
# Mods (slice 2) are bought at Dash's workbench, beside his stall, and slot into any gadget, two to a gadget:
#   Freeze          every pop or splash leaves a frosty puff (scripts/frost_puff.gd) that slows enemies near it.
#   Split           every shot is two smaller ones.
#   Bounce          shots bounce once off the ground or a wall before they go off.
#   Sparkle Magnet  while that gadget is out, sparkles and ammo bubbles fly to her from further away.
# Two mods together make a combo with a name of its own (COMBOS): Freeze and Split are Icy Shards (each frosty puff
# throws icy shards at enemies near it), and so on. A mod she owns can go in every gadget at once. The workbench also
# sells upgrades for each gadget, three levels each (UPGRADES): a bigger tank (more ammo), quick hands (shorter
# wait between shots) and a big splash (a bigger splash, dance floor, bubble, beam or reach).
# Ammo crates round Galaxity (scripts/ammo_crate.gd, placed below) pop open for ammo.
#
# The gadget wheel (scripts/gadget_wheel.gd, hold R or D-pad up) picks one; 1-8 pick one straight away and a tap of the
# wheel button swaps back to the last one. Shoot fires whichever is out.
#
# Gadgets get better with use: every enemy a gadget pops (or sets dancing) is a point for it, and at LEVEL_XP points it
# grows a version, V1 to V5. Each version means more ammo and a stronger gadget (stat() below), and V5 is a Mega
# version with a trick of its own. Ammo comes from Dash's gadget stall in the Market Square (Shop, stall "Gadget",
# shop/items.json), and popped enemies sometimes leave a little ammo bubble behind (scripts/ammo_drop.gd).
#
# Saved with the game (Game.save_game: "arsenal").

signal changed                    # a gadget was picked, bought, used up, refilled or grew a version
signal levelled(id: String, level: int)

const ORDER := ["popper", "fizz", "disco", "plush", "buzz", "rainbow", "jelly"]
const MAX_LEVEL := 5
const LEVEL_XP := [0, 5, 14, 28, 48]      # points to reach V1..V5
const GADGETS := {
	"popper": {"name": "Star Popper", "mega": "Mega Popper", "colour": Color(0.72, 0.58, 0.98), "ammo": [-1, -1, -1, -1, -1],
		"cooldown": [0.2, 0.18, 0.16, 0.14, 0.12],
		"says": ["", "Bubbles come quicker.", "Even quicker bubbles!", "Bigger bubbles!", "It blows two bubbles at once!"]},
	"fizz": {"name": "Fizz Flinger", "mega": "Mega Fizz", "colour": Color(0.35, 0.9, 1.0), "ammo": [8, 10, 12, 14, 16],
		"cooldown": [0.75, 0.7, 0.65, 0.6, 0.55], "radius": [2.6, 3.0, 3.4, 3.8, 4.2], "power": [1, 1, 2, 2, 3],
		"says": ["", "A bigger splash.", "Fizz pops big Gloops in one go!", "An even bigger splash!",
			"Each splash throws three little fizz bombs!"]},
	"disco": {"name": "Disco Ball", "mega": "Disco Fever", "colour": Color(1.0, 0.55, 0.85), "ammo": [3, 3, 4, 4, 5],
		"cooldown": [1.0, 1.0, 1.0, 1.0, 1.0], "radius": [6.0, 7.0, 8.0, 9.0, 10.0], "time": [5.0, 6.0, 7.0, 8.0, 9.0],
		"says": ["", "It dances longer.", "A bigger dance floor!", "One more song!",
			"When the music stops, everyone who danced pops!"]},
	"plush": {"name": "Plushinator", "mega": "Plush Party", "colour": Color(1.0, 0.72, 0.85), "ammo": [6, 8, 10, 12, 14],
		"cooldown": [0.6, 0.55, 0.5, 0.45, 0.4], "time": [4.0, 5.0, 6.0, 7.0, 8.0], "radius": [0.6, 0.6, 0.8, 0.8, 3.5],
		"sparkles": [1, 1, 2, 2, 2],
		"says": ["", "Plushies stay soft longer.", "Plush pops give two sparkles!", "Even longer cuddles!",
			"Every bolt turns everyone round it into plushies!"]},
	"buzz": {"name": "Buzz Bots", "mega": "Buzz Swarm", "colour": Color(1.0, 0.85, 0.3), "ammo": [2, 2, 3, 3, 4],
		"cooldown": [1.0, 1.0, 1.0, 1.0, 1.0], "time": [12.0, 14.0, 16.0, 18.0, 20.0], "radius": [7.0, 8.0, 9.0, 10.0, 11.0],
		"rate": [1.4, 1.3, 1.15, 1.0, 0.8], "bots": [3, 3, 3, 3, 5],
		"says": ["", "The bots stay out longer.", "They blow bubbles quicker!", "They see further!",
			"A whole swarm: five bots, buzzing quick!"]},
	"rainbow": {"name": "Rainbow Ray", "mega": "Double Rainbow", "colour": Color(0.55, 1.0, 0.6), "ammo": [30, 36, 42, 48, 60],
		"cooldown": [0.25, 0.25, 0.25, 0.25, 0.25], "radius": [10.0, 11.0, 12.0, 13.0, 14.0], "time": [1.4, 1.2, 1.0, 0.9, 0.7],
		"says": ["", "A longer ray.", "Enemies fill up quicker!", "Even quicker!",
			"The ray goes right through everyone in a row!"]},
	"jelly": {"name": "Jelly Mines", "mega": "Jelly Jamboree", "colour": Color(0.95, 0.4, 0.55), "ammo": [4, 5, 6, 7, 8],
		"cooldown": [0.5, 0.5, 0.45, 0.45, 0.4], "radius": [1.6, 1.8, 2.0, 2.2, 2.4], "time": [1.5, 1.4, 1.3, 1.2, 1.0],
		"says": ["", "Bigger jelly.", "Stuck ones pop quicker!", "Even bigger jelly!",
			"Every jelly that pops leaves two little ones behind!"]},
}
# Mods: any mod fits any gadget, two slots each (slot 2 opens once she has two mods)
const MOD_ORDER := ["freeze", "split", "bounce", "magnet"]
const SLOTS := 2
const MODS := {
	"freeze": {"name": "Freeze", "colour": Color(0.6, 0.9, 1.0), "says": "Pops and splashes leave a frosty puff that slows enemies."},
	"split": {"name": "Split", "colour": Color(1.0, 0.6, 0.85), "says": "Every shot splits into two smaller ones."},
	"bounce": {"name": "Bounce", "colour": Color(0.55, 1.0, 0.55), "says": "Shots bounce once off the ground or a wall."},
	"magnet": {"name": "Sparkle Magnet", "colour": Color(1.0, 0.85, 0.3), "says": "Sparkles and ammo bubbles fly to you."},
}
const COMBOS := {               # two mods in one gadget (sorted, joined with +)
	"freeze+split": {"name": "Icy Shards", "says": "Each frosty puff throws icy shards at enemies near it."},
	"bounce+freeze": {"name": "Snowball Bounce", "says": "Every bounce leaves a frosty puff too."},
	"bounce+split": {"name": "Pinball", "says": "Split shots bounce twice."},
	"freeze+magnet": {"name": "Frosty Magnet", "says": "Ammo bubbles drop twice as often."},
	"magnet+split": {"name": "Lucky Split", "says": "Ammo bubbles drop twice as often."},
	"bounce+magnet": {"name": "Lucky Bounce", "says": "Ammo bubbles drop twice as often."},
}
# Upgrades from the workbench: three levels each. "ammo" doesn't go on the Star Popper (it never runs out).
const UPGRADE_ORDER := ["ammo", "reload", "splash"]
const UPGRADES := {
	"ammo": {"name": "Bigger Tank", "says": "+25% ammo a level", "price": [4, 8, 12]},
	"reload": {"name": "Quick Hands", "says": "10% less wait between shots a level", "price": [5, 9, 14]},
	"splash": {"name": "Big Splash", "says": "12% bigger a level", "price": [5, 10, 15]},
}
const UPGRADE_MAX := 3
const MAGNET_RANGE := 9.0                 # with a Sparkle Magnet: sparkles this close fly to her
const CRATES := [                         # ammo crates round Galaxity (x, z; dropped onto the ground): ammo_crate.gd
	Vector2(-60, 52), Vector2(-84, 30),                      # the Market Square
	Vector2(-121, 16), Vector2(-136, 2), Vector2(-127, 24),   # by the Gloop King's court, out west
	Vector2(47, 66),                                         # the Skate Park
	Vector2(116, 12),                                        # under the tree house
	Vector2(-112, -100),                                     # the Spooky Woods
	Vector2(130, -198),                                      # the far field, where the Agent of Chaos stomps
	Vector2(20, 40),                                         # the lake's south shore
]
const STALL_ANGLE := 105.0                # Dash's stall: degrees round the fountain, just off the south way in...
const STALL_RING := 15.5                  # ...out past the market stalls' ring (12 m), so it's in nobody's way
const DROP_CHANCE := 0.35                 # a gadget pop leaves an ammo bubble this often (for a gadget that isn't full)

var owned: Array[String] = ["popper"]
var current := "popper"
var last := "popper"                      # the one before, for a quick swap
var ammo := {}                            # id -> how many shots are left
var xp := {}                              # id -> points (pops) towards its next version
var mods_owned: Array[String] = []
var slots := {}                           # id -> [mod or "", mod or ""]
var upgrades := {}                        # id -> {"ammo": 0..3, "reload": 0..3, "splash": 0..3}
var _credit := {}                         # id -> a node standing in for a gadget's shot, for pops with no shot


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	_register_shop()


# ----------------------------------------------------------------------------- what she has
func owns(id: String) -> bool:
	return id in owned


func give(id: String, say := true) -> void:
	if owns(id) or not GADGETS.has(id):
		return
	owned.append(id)
	owned.sort_custom(func(a: String, b: String) -> bool: return ORDER.find(a) < ORDER.find(b))
	ammo[id] = max_ammo(id)
	select(id)
	Tips.show_tip("gadgets")                  # the first time there's a wheel to pick from (scripts/tips.gd)
	if say:
		Game.message("You got the %s! Hold %s to pick gadgets." % [gadget_name(id), Settings.prompt("gadget_wheel")])


func select(id: String) -> void:
	if not owns(id) or id == current:
		return
	last = current
	current = id
	changed.emit()


func quick_swap() -> void:
	# A tap of the wheel button: back to the one she had before
	if owns(last) and last != current:
		select(last)


func cycle(step: int) -> void:
	var i := owned.find(current)
	select(owned[(i + step + owned.size()) % owned.size()])


func gadget_name(id: String) -> String:
	if not GADGETS.has(id):
		return id
	return str(GADGETS[id].mega) if level(id) >= MAX_LEVEL else str(GADGETS[id].name)


func colour(id: String) -> Color:
	return GADGETS[id].colour if GADGETS.has(id) else Color.WHITE


# ----------------------------------------------------------------------------- versions
func level(id: String) -> int:
	var points := int(xp.get(id, 0))
	var v := 1
	for i in LEVEL_XP.size():
		if points >= LEVEL_XP[i]:
			v = i + 1
	return v


func stat(id: String, what: String) -> Variant:
	# One of a gadget's numbers at its current version (GADGETS: cooldown, radius, power, time, ammo), with the
	# workbench upgrades on top (more ammo, a shorter cooldown, a bigger radius)
	var list: Array = GADGETS[id].get(what, [0])
	var v = list[clampi(level(id) - 1, 0, list.size() - 1)]
	match what:
		"ammo":
			if int(v) > 0:
				v = ceili(int(v) * (1.0 + 0.25 * upgrade_level(id, "ammo")))
		"cooldown":
			v = float(v) * (1.0 - 0.1 * upgrade_level(id, "reload"))
		"radius":
			v = float(v) * boost(id)
	return v


func boost(id: String) -> float:
	# How much bigger the Big Splash upgrade makes this gadget's splash, bubble, beam or reach
	return 1.0 + 0.12 * upgrade_level(id, "splash")


func progress(id: String) -> float:
	# 0..1 towards the next version (1 at V5)
	var v := level(id)
	if v >= MAX_LEVEL:
		return 1.0
	var from: int = LEVEL_XP[v - 1]
	return clampf(float(int(xp.get(id, 0)) - from) / float(LEVEL_XP[v] - from), 0.0, 1.0)


func add_xp(id: String, points := 1) -> void:
	if not owns(id):
		return
	var was := level(id)
	xp[id] = int(xp.get(id, 0)) + points
	var now := level(id)
	if now > was:
		if max_ammo(id) > 0:
			ammo[id] = max_ammo(id)              # a new version comes full
		var says: String = GADGETS[id].says[now - 1]
		Game.message("%s grew to V%d! %s" % [str(GADGETS[id].name), now, says] if now < MAX_LEVEL else
			"%s grew to V5: it's the %s now! %s" % [str(GADGETS[id].name), str(GADGETS[id].mega), says])
		Audio.play("level_up", -4.0, 0.0)
		levelled.emit(id, now)
	changed.emit()


# ----------------------------------------------------------------------------- ammo
func max_ammo(id: String) -> int:
	return int(stat(id, "ammo")) if GADGETS.has(id) else 0


func ammo_of(id: String) -> int:
	return -1 if max_ammo(id) < 0 else int(ammo.get(id, 0))


func has_ammo(id := "") -> bool:
	id = id if id != "" else current
	return max_ammo(id) < 0 or ammo_of(id) > 0


func use_ammo(id := "") -> bool:
	id = id if id != "" else current
	if max_ammo(id) < 0:
		return true
	if ammo_of(id) <= 0:
		return false
	ammo[id] = ammo_of(id) - 1
	changed.emit()
	return true


func refill(id: String, amount: int) -> int:
	# Adds ammo up to the most it holds; says how much went in
	if not owns(id) or max_ammo(id) < 0:
		return 0
	var room := max_ammo(id) - ammo_of(id)
	var put := mini(room, amount)
	ammo[id] = ammo_of(id) + put
	changed.emit()
	return put


func hungry() -> Array[String]:
	# Gadgets she has that aren't full (the ones an ammo bubble could be for)
	var out: Array[String] = []
	for id in owned:
		if max_ammo(id) > 0 and ammo_of(id) < max_ammo(id):
			out.append(id)
	return out


# ----------------------------------------------------------------------------- pops
func on_pop(enemy: Node3D, by: Node) -> void:
	# A gadget popped something (StarPopper.popped): a point for that gadget, and maybe an ammo bubble
	var id := str(by.get_meta("gadget", "popper")) if by else "popper"
	add_xp(id)
	if enemy and enemy.has_meta("was_plush"):
		enemy.remove_meta("was_plush")
		var n := int(stat("plush", "sparkles")) if owns("plush") else 1
		Game.add_sparkles(n, "Plush pop!")
	var want := hungry()
	var chance := DROP_CHANCE * (2.0 if has_mod(id, "magnet") and mods(id).size() > 1 else 1.0)
	if enemy and enemy.is_inside_tree() and not want.is_empty() and randf() < chance:
		drop(enemy.global_position + Vector3(0, 0.6, 0), want[randi() % want.size()])


func drop(at: Vector3, id: String) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var d := (load("res://scripts/ammo_drop.gd") as GDScript).new() as Node3D
	d.set("gadget", id)
	scene.add_child(d)
	d.global_position = at
	return d


# ----------------------------------------------------------------------------- mods and upgrades
func owns_mod(m: String) -> bool:
	return m in mods_owned


func give_mod(m: String) -> void:
	if owns_mod(m) or not MODS.has(m):
		return
	mods_owned.append(m)
	mods_owned.sort_custom(func(a: String, b: String) -> bool: return MOD_ORDER.find(a) < MOD_ORDER.find(b))
	# It goes straight into the gadget that's out, if there's a free slot
	var s := slots_of(current)
	for i in SLOTS:
		if s[i] == "":
			fit(current, i, m)
			break
	changed.emit()


func slots_of(id: String) -> Array:
	var s: Array = slots.get(id, [])
	while s.size() < SLOTS:
		s.append("")
	slots[id] = s
	return s


func fit(id: String, slot: int, m: String) -> void:
	# Puts mod m (or "" for nothing) in one of a gadget's slots. A mod can't go in both slots of one gadget.
	if slot < 0 or slot >= SLOTS or (m != "" and not owns_mod(m)):
		return
	var s := slots_of(id)
	if m != "" and s[1 - slot] == m:
		s[1 - slot] = ""
	s[slot] = m
	changed.emit()


func cycle_mod(id: String, slot: int, step := 1) -> void:
	# The Bag's slot buttons: the next mod she owns (or nothing) in that slot
	var choices: Array[String] = [""]
	choices.append_array(mods_owned)
	var now: String = slots_of(id)[slot]
	fit(id, slot, choices[posmod(choices.find(now) + step, choices.size())])


func mods(id: String) -> Array[String]:
	var out: Array[String] = []
	for m in slots_of(id):
		if m != "":
			out.append(str(m))
	return out


func has_mod(id: String, m: String) -> bool:
	return m in slots_of(id)


func combo_key(id: String) -> String:
	var ms := mods(id)
	if ms.size() < 2:
		return ""
	ms.sort()
	return "+".join(ms)


func combo_name(id: String) -> String:
	var k := combo_key(id)
	return str(COMBOS[k].name) if COMBOS.has(k) else ""


func upgrade_level(id: String, kind: String) -> int:
	return int(upgrades.get(id, {}).get(kind, 0))


func upgrade_kinds(id: String) -> Array[String]:
	var out: Array[String] = []
	for k in UPGRADE_ORDER:
		if k == "ammo" and int(GADGETS[id].ammo[0]) < 0:
			continue
		out.append(k)
	return out


func upgrade(id: String, kind: String) -> void:
	if upgrade_level(id, kind) >= UPGRADE_MAX:
		return
	if not upgrades.has(id):
		upgrades[id] = {}
	upgrades[id][kind] = upgrade_level(id, kind) + 1
	if kind == "ammo":
		ammo[id] = max_ammo(id)                  # a bigger tank comes full
	changed.emit()


# ----------------------------------------------------------------------------- what a shot does when it lands
func credit(id: String) -> Node3D:
	# Something to say "this gadget did it" with (StarPopper.popped wants a node with a "gadget" meta)
	if not _credit.has(id) or not is_instance_valid(_credit[id]):
		var n := Node3D.new()
		n.set_meta("gadget", id)
		_credit[id] = n
	return _credit[id]


func hit(e: Node, power: int, dir: Vector3, id: String) -> String:
	# A gadget hits an enemy (or an ammo crate): a plushie pops at one touch; a pop is a point for the gadget
	if e == null or not is_instance_valid(e) or not e.has_method("shot"):
		return "miss"
	if is_plush(e):
		unplush(e, true)
		power = 99
	var was_down: bool = e.get("defeated") == true
	var at: Vector3 = (e as Node3D).global_position if e is Node3D else Vector3.ZERO
	var what := str(e.shot(power, at, dir))
	if what == "hit" and not was_down and e.get("defeated") == true:
		var p := get_tree().get_first_node_in_group("player")
		var popper = p.get("popper") if p else null
		if popper:
			popper.popped.emit(e, credit(id))
		else:
			on_pop(e as Node3D, credit(id))
	return what


func impact(at: Vector3, id: String, parent: Node = null) -> void:
	# Where a shot lands, pops or splashes: with Freeze fitted, a frosty puff (and with Split too, icy shards)
	if not has_mod(id, "freeze"):
		return
	parent = parent if parent else get_tree().current_scene
	if parent == null:
		return
	FrostPuff.spawn(parent, at, id, has_mod(id, "split"))


func chill(e: Node, seconds := FrostPuff.CHILL) -> void:
	# Slowed by frost: enemies read Arsenal.slow(self) for how fast they can go
	if e == null or not is_instance_valid(e):
		return
	e.set_meta("chill_until", Time.get_ticks_msec() + int(seconds * 1000.0))
	FrostPuff.frost_on(e as Node3D, seconds)


func slow(e: Node) -> float:
	# 1 normally, less while frosty
	if e.has_meta("chill_until") and int(e.get_meta("chill_until")) > Time.get_ticks_msec():
		return FrostPuff.SLOW
	return 1.0


# ----------------------------------------------------------------------------- plushies (the Plushinator)
func is_plush(e: Node) -> bool:
	return e != null and is_instance_valid(e) and e.has_meta("plush")


func can_plush(e: Node) -> bool:
	if e == null or not is_instance_valid(e) or e.get("defeated") == true or is_plush(e) or e.is_in_group("bosses"):
		return false
	return not (e.has_method("shelled") and e.shelled())


func plush(e: Node3D, seconds: float) -> bool:
	# Turns an enemy into a soft toy for a while: it sits still, and one touch of anything pops it (for sparkles)
	if not can_plush(e):
		return false
	var v := e.get_node_or_null("Visual") as Node3D
	var toy := PlushBolt.build_toy(float(e.get("size") if e.get("size") != null else 1.0))
	toy.name = "Plushie"
	e.add_child(toy)
	e.set_meta("plush", {"visual": v, "toy": toy, "until": Time.get_ticks_msec() + int(seconds * 1000.0)})
	if v:
		v.visible = false
	e.set_physics_process(false)
	if e is CharacterBody3D:
		(e as CharacterBody3D).velocity = Vector3.ZERO
	toy.scale = Vector3.ONE * 0.2
	toy.create_tween().tween_property(toy, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(e.get_parent(), e.global_position + Vector3(0, 0.6, 0), Color(1.0, 0.75, 0.9), 14, 0.07, 2.5, -1.0, 0.6)
	Audio.play_at("plush_poof", e.global_position, -3.0, 0.1)
	return true


func unplush(e: Node, popping := false) -> void:
	if not is_plush(e):
		return
	var d: Dictionary = e.get_meta("plush")
	e.remove_meta("plush")
	if d.toy and is_instance_valid(d.toy):
		(d.toy as Node).queue_free()
	if d.visual and is_instance_valid(d.visual):
		(d.visual as Node3D).visible = true
	(e as Node).set_physics_process(true)
	if popping:
		e.set_meta("was_plush", true)            # on_pop gives the sparkles
	else:
		Fx.burst(e.get_parent(), (e as Node3D).global_position + Vector3(0, 0.6, 0), Color(1.0, 0.75, 0.9), 8, 0.05, 2.0, -1.0, 0.4)


func _physics_process(_delta: float) -> void:
	# Plushies going back to how they were, and the Sparkle Magnet pulling sparkles in
	var now := Time.get_ticks_msec()
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_plush(e) and int(e.get_meta("plush").until) < now:
			unplush(e)
	if has_mod(current, "magnet"):
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p:
			for s in get_tree().get_nodes_in_group("sparkles"):
				if s.visible and s.has_method("magnet_to") and (s as Node3D).global_position.distance_to(p.global_position) < MAGNET_RANGE:
					s.magnet_to(p)


func ammo_pull() -> float:
	# How close an ammo bubble has to be to drift to her (further with a Sparkle Magnet out)
	return MAGNET_RANGE if has_mod(current, "magnet") else 3.5


# ----------------------------------------------------------------------------- Dash's gadget stall
func _register_shop() -> void:
	# Gadgets and ammo are bought at the market like everything else (scripts/shop.gd, shop/items.json)
	Shop.register_kind("gadget", {"can_buy": _can_buy_gadget, "buy": _buy_gadget, "button": "Get it!",
		"note": func(it: Dictionary) -> String: return Schematics.note_for("gadget", str(it.gadget))})
	Shop.register_kind("ammo", {"can_buy": _can_buy_ammo, "buy": _buy_ammo, "button": "Refill",
		"show": func(it: Dictionary) -> bool: return owns(str(it.gadget))})
	Shop.register_kind("mod", {"can_buy": _can_buy_mod, "buy": _buy_mod, "button": "Get it!"})
	Shop.register_kind("gadget_upgrade", {"can_buy": _can_buy_upgrade, "buy": _buy_upgrade, "button": "Upgrade",
		"show": func(it: Dictionary) -> bool:
			return owns(str(it.gadget)) and upgrade_level(str(it.gadget), str(it.upgrade)) == int(it.level) - 1})
	# The workbench's upgrades: the next level of each, for each gadget she has (made here, not in items.json)
	for id in ORDER:
		for kind in upgrade_kinds(id):
			for lv in UPGRADE_MAX:
				var u: Dictionary = UPGRADES[kind]
				var item_id := "upgrade_%s_%s_%d" % [id, kind, lv + 1]
				Shop.items[item_id] = {"id": item_id, "name": "%s: %s %d" % [str(GADGETS[id].name), str(u.name), lv + 1],
					"stall": "Workbench", "kind": "gadget_upgrade", "gadget": id, "upgrade": kind, "level": lv + 1,
					"price": int(u.price[lv]), "text": str(u.says)}


func _can_buy_mod(it: Dictionary) -> String:
	return "You have this one" if owns_mod(str(it.mod)) else ""


func _buy_mod(it: Dictionary) -> String:
	give_mod(str(it.mod))
	return "You got the %s mod! %s Swap mods in the Bag (%s)." % [str(it.name), str(MODS[str(it.mod)].says),
		Settings.prompt("player_menu")]


func _can_buy_upgrade(it: Dictionary) -> String:
	var id := str(it.gadget)
	if not owns(id):
		return "Needs the %s" % str(GADGETS[id].name)
	if upgrade_level(id, str(it.upgrade)) >= int(it.level):
		return "You have this one"
	if upgrade_level(id, str(it.upgrade)) < int(it.level) - 1:
		return "Needs level %d first" % (int(it.level) - 1)
	return ""


func _buy_upgrade(it: Dictionary) -> String:
	upgrade(str(it.gadget), str(it.upgrade))
	return "%s upgraded! (%s %d of %d)" % [gadget_name(str(it.gadget)), str(UPGRADES[str(it.upgrade)].name),
		upgrade_level(str(it.gadget), str(it.upgrade)), UPGRADE_MAX]


func _can_buy_gadget(it: Dictionary) -> String:
	# A gadget's on Dash's stall from the start, but he can only build it once its schematic's been found
	# (scripts/schematics.gd)
	if owns(str(it.gadget)):
		return "You have this one"
	return "" if Schematics.gadget_unlocked(str(it.gadget)) else "Find its schematic"


func _buy_gadget(it: Dictionary) -> String:
	give(str(it.gadget), false)
	return "You got the %s! Hold %s to pick it, then %s to use it." % [str(it.name), Settings.prompt("gadget_wheel"),
		Settings.prompt("shoot")]


func _can_buy_ammo(it: Dictionary) -> String:
	var id := str(it.gadget)
	if not owns(id):
		return "Needs the %s" % str(GADGETS[id].name)
	if ammo_of(id) >= max_ammo(id):
		return "It's full"
	return ""


func _buy_ammo(it: Dictionary) -> String:
	var id := str(it.gadget)
	refill(id, max_ammo(id))
	return "%s filled up! (%d/%d)" % [gadget_name(id), ammo_of(id), max_ammo(id)]


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path == Requests.TOWN and scene.get_node_or_null("Gadget Stall") == null:
		_place_stall(scene)
		_place_crates(scene)


func _place_crates(scene: Node) -> void:
	# Ammo crates round Galaxity, each dropped onto the ground where it's listed (CRATES). They're added here like
	# the stall, so the town scene doesn't change.
	var space := (scene as Node3D).get_world_3d().direct_space_state if scene is Node3D else null
	for i in CRATES.size():
		var c := (load("res://scripts/ammo_crate.gd") as GDScript).new() as Node3D
		c.name = "Ammo Crate %d" % (i + 1)
		scene.add_child(c)
		var xz: Vector2 = CRATES[i]
		var at := Vector3(xz.x, 0.0, xz.y)
		if space:
			var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 40, 0), at + Vector3(0, -20, 0))
			var got := space.intersect_ray(q)
			if not got.is_empty():
				at = got.position
		c.global_position = at


func _place_stall(scene: Node) -> void:
	# Dash's stall stands at the south side of the Market Square, beside the way in from the south, facing the
	# fountain. The six market stalls and both noticeboards fill the inner ring, so it stands a little further out.
	# It's added here rather than built into the town scene, the same as the board (scripts/requests.gd).
	var square := scene.get_node_or_null("Market Square") as Node3D
	if square == null:
		return
	var a := deg_to_rad(STALL_ANGLE)
	var stall := (load("res://scripts/gadget_stall.gd") as GDScript).new() as Node3D
	stall.name = "Gadget Stall"
	scene.add_child(stall)
	stall.global_position = square.global_position + Vector3(cos(a), 0, sin(a)) * STALL_RING + Vector3(0, 0.15, 0)
	stall.rotation.y = atan2(-cos(a), -sin(a))


# ----------------------------------------------------------------------------- saving
func save_data() -> Dictionary:
	return {"owned": owned, "current": current, "last": last, "ammo": ammo, "xp": xp, "mods": mods_owned,
		"slots": slots, "upgrades": upgrades}


func load_data(d: Dictionary) -> void:
	reset()
	for id in d.get("owned", []):
		if GADGETS.has(str(id)) and not owns(str(id)):
			owned.append(str(id))
	owned.sort_custom(func(a: String, b: String) -> bool: return ORDER.find(a) < ORDER.find(b))
	for m in d.get("mods", []):
		if MODS.has(str(m)) and not owns_mod(str(m)):
			mods_owned.append(str(m))
	mods_owned.sort_custom(func(a: String, b: String) -> bool: return MOD_ORDER.find(a) < MOD_ORDER.find(b))
	var up = d.get("upgrades", {})
	if up is Dictionary:
		for id in up:
			if GADGETS.has(str(id)) and up[id] is Dictionary:
				upgrades[str(id)] = {}
				for k in up[id]:
					if UPGRADES.has(str(k)):
						upgrades[str(id)][str(k)] = clampi(int(up[id][k]), 0, UPGRADE_MAX)
	var sl = d.get("slots", {})
	if sl is Dictionary:
		for id in sl:
			if GADGETS.has(str(id)) and sl[id] is Array:
				for i in mini((sl[id] as Array).size(), SLOTS):
					var m := str(sl[id][i])
					if m == "" or owns_mod(m):
						fit(str(id), i, m)
	var x = d.get("xp", {})
	if x is Dictionary:
		for id in x:
			xp[str(id)] = int(x[id])
	var am = d.get("ammo", {})
	for id in owned:
		ammo[id] = clampi(int(am.get(id, max_ammo(id))) if am is Dictionary else max_ammo(id), 0, maxi(max_ammo(id), 0))
	current = str(d.get("current", "popper")) if owns(str(d.get("current", "popper"))) else "popper"
	last = str(d.get("last", "popper")) if owns(str(d.get("last", "popper"))) else "popper"


func reset() -> void:
	owned = ["popper"]
	current = "popper"
	last = "popper"
	ammo = {}
	xp = {}
	mods_owned = []
	slots = {}
	upgrades = {}
	changed.emit()
