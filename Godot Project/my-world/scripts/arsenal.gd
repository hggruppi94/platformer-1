extends Node

# Autoload "Arsenal": the hero's toy gadgets, Ratchet and Clank style. Every gadget is a toy and nothing is ever hurt:
# enemies get bubbled and pop, or dance, like everywhere else in the game.
#
#   Star Popper   (scripts/star_popper.gd, star_bubble.gd) the bubble blaster she starts with. It never runs out.
#   Fizz Flinger  (scripts/fizz_bomb.gd) lobs a fizzy soda bomb in an arc that pops everything close to where it lands.
#   Disco Ball    (scripts/disco_ball.gd) floats up and spins, and every enemy near it dances till the music stops.
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

const ORDER := ["popper", "fizz", "disco"]
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
}
const STALL_ANGLE := 105.0                # Dash's stall: degrees round the fountain, just off the south way in...
const STALL_RING := 15.5                  # ...out past the market stalls' ring (12 m), so it's in nobody's way
const DROP_CHANCE := 0.35                 # a gadget pop leaves an ammo bubble this often (for a gadget that isn't full)

var owned: Array[String] = ["popper"]
var current := "popper"
var last := "popper"                      # the one before, for a quick swap
var ammo := {}                            # id -> how many shots are left
var xp := {}                              # id -> points (pops) towards its next version


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
	# One of a gadget's numbers at its current version (GADGETS: cooldown, radius, power, time, ammo)
	var list: Array = GADGETS[id].get(what, [0])
	return list[clampi(level(id) - 1, 0, list.size() - 1)]


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
	var want := hungry()
	if enemy and enemy.is_inside_tree() and not want.is_empty() and randf() < DROP_CHANCE:
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


# ----------------------------------------------------------------------------- Dash's gadget stall
func _register_shop() -> void:
	# Gadgets and ammo are bought at the market like everything else (scripts/shop.gd, shop/items.json)
	Shop.register_kind("gadget", {"can_buy": _can_buy_gadget, "buy": _buy_gadget, "button": "Get it!"})
	Shop.register_kind("ammo", {"can_buy": _can_buy_ammo, "buy": _buy_ammo, "button": "Refill"})


func _can_buy_gadget(it: Dictionary) -> String:
	return "You have this one" if owns(str(it.gadget)) else ""


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
	return {"owned": owned, "current": current, "last": last, "ammo": ammo, "xp": xp}


func load_data(d: Dictionary) -> void:
	reset()
	for id in d.get("owned", []):
		if GADGETS.has(str(id)) and not owns(str(id)):
			owned.append(str(id))
	owned.sort_custom(func(a: String, b: String) -> bool: return ORDER.find(a) < ORDER.find(b))
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
	changed.emit()
