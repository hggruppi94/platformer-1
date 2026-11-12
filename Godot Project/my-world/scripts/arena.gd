extends Node

# Autoload "Arena": the Star Arena (Hayden, 12 Nov 2026: "I want to add an arena with unique bosses, and challenges like
# slay 100 gloops etc."). An open-air stadium of its own (scenes/bosses/arena.tscn, everything built at load by
# scripts/arena_level.gd), and the way in: the Arena Gate, put into the Void at play time on the flat ground at the foot
# of the castle school's hill (GATE), like the Gloop Gate (scripts/bosses.gd). It opens once The First Night's done.
#
# Blip runs it, a little yellow alien with a megaphone (the little aliens fill the stands). Talk to them, or the
# Round Board beside them, to pick a round:
#   - Challenge rounds (CHALLENGES kind "count" / "waves" / "timed"): pop 100 Gloops, pop 40 Glorps (every bit counts),
#     three waves of Time Goblins, 25 Fizzlers against the clock, and 20 shadow ghosts with the lights down.
#   - Boss rounds (kind "boss"): three bosses you only meet here, the big ones of the new enemies: Mama Glorp
#     (scripts/glorp_mother.gd), Big Buzz (scripts/big_buzz.gd) and the Gloam (scripts/the_gloam.gd). Each opens once
#     you've won the challenge round with its little ones. The Champion's Cup (all three, one after another) opens once
#     you've beaten all three.
# The first win of each round pays its "first" reward; any win after pays "again". Best times are kept. Fainting in a
# round ends it (the arena starts again, nothing lost). Saved as "arena" (records) in the save.

signal changed

const TOWN := "res://scenes/town/town.tscn"
const LEVEL := "res://scenes/bosses/arena.tscn"
const GATE := Vector2(-64, -96)                # x, z: the Arena Gate, on the flat at the foot of the castle hill (checked
                                              # flat, dry, off the paths, races and trees: tools/test_arena.gd)
const GATE_FACING := Vector2(0.5, 0.866)       # it looks south-east, back towards the town
const GATE_WIDE := 7.0                         # the gateway's half-width (to the pillars' middles)

# The rounds. "enemy": what comes out of the hatches. "goal": how many to pop (or waves: a list). "time": seconds
# (0: no clock). "needs": a round you must have won first.
const CHALLENGES := [
	{"id": "gloops", "name": "Pop 100 Gloops", "kind": "count", "enemy": "gloop", "goal": 100, "time": 0, "at_once": 10,
		"about": "One hundred Gloops, ten at a time. No clock: just keep popping!",
		"first": {"sparkles": 20, "remnants": 2}, "again": {"sparkles": 5}},
	{"id": "glorps", "name": "Glorp Splitter", "kind": "count", "enemy": "glorp", "goal": 40, "time": 0, "at_once": 4,
		"about": "Pop 40 Glorps. Every bit they split into counts!",
		"first": {"sparkles": 15, "remnants": 1}, "again": {"sparkles": 4}},
	{"id": "goblins", "name": "Goblin Waves", "kind": "waves", "enemy": "goblin", "goal": [4, 6, 8], "time": 0,
		"about": "Three waves of Time Goblins: 4, then 6, then 8. They blink back in time, so be quick!",
		"first": {"sparkles": 15, "remnants": 1}, "again": {"sparkles": 4}},
	{"id": "fizzlers", "name": "Fizzler Frenzy", "kind": "timed", "enemy": "fizzler", "goal": 25, "time": 180, "at_once": 6,
		"about": "Pop 25 Fizzlers before three minutes are up. Jump their little zaps!",
		"first": {"sparkles": 15, "remnants": 1}, "again": {"sparkles": 4}},
	{"id": "shadows", "name": "Shadow Night", "kind": "count", "enemy": "ghost", "goal": 20, "time": 0, "at_once": 5,
		"dark": true,
		"about": "The lights go down and 20 shadow ghosts come out. Pop them all!",
		"first": {"sparkles": 15, "remnants": 1}, "again": {"sparkles": 4}},
	{"id": "mama_glorp", "name": "Mama Glorp", "kind": "boss", "boss": "mama_glorp", "needs": "glorps",
		"about": "The biggest Glorp there is. Every hit, a little Glorp splits off her!",
		"first": {"sparkles": 25, "remnants": 3}, "again": {"sparkles": 6}},
	{"id": "big_buzz", "name": "Big Buzz", "kind": "boss", "boss": "big_buzz", "needs": "fizzlers",
		"about": "A storm cloud of static. Jump the zap, then pop him while he's fizzled out!",
		"first": {"sparkles": 25, "remnants": 3}, "again": {"sparkles": 6}},
	{"id": "gloam", "name": "The Gloam", "kind": "boss", "boss": "gloam", "needs": "shadows", "dark": true,
		"about": "A shadow too dark to touch, until the spotlights catch it.",
		"first": {"sparkles": 25, "remnants": 3}, "again": {"sparkles": 6}},
	{"id": "cup", "name": "Champion's Cup", "kind": "rush", "bosses": ["mama_glorp", "big_buzz", "gloam"],
		"needs": ["mama_glorp", "big_buzz", "gloam"],
		"about": "All three arena bosses, one after another. Win and the Champion's Cup is yours!",
		"first": {"sparkles": 50, "remnants": 5, "item": "champion_cup"}, "again": {"sparkles": 10}},
]

var records := {}                              # round id -> {"wins": n, "best": seconds (0: none yet)}
var coming_out := false                        # on the way home from the arena (set by arena_level.gd go_home())


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


# -----------------------------------------------------------------------------
# The rounds and their records
# -----------------------------------------------------------------------------
func round_of(id: String) -> Dictionary:
	for c in CHALLENGES:
		if c.id == id:
			return c
	return {}


func wins(id: String) -> int:
	return int((records.get(id, {}) as Dictionary).get("wins", 0))


func best(id: String) -> float:
	return float((records.get(id, {}) as Dictionary).get("best", 0.0))


func is_open(id: String) -> bool:
	var c := round_of(id)
	if c.is_empty():
		return false
	var needs = c.get("needs", [])
	for n in (needs if needs is Array else [needs]):
		if wins(str(n)) == 0:
			return false
	return true


func needs_text(id: String) -> String:
	# What opens a round, for the board ("Win Glorp Splitter first")
	var c := round_of(id)
	var names: Array[String] = []
	var needs = c.get("needs", [])
	for n in (needs if needs is Array else [needs]):
		if wins(str(n)) == 0:
			names.append(str(round_of(str(n)).name))
	return "Win %s first." % " and ".join(names) if not names.is_empty() else ""


func won(id: String, seconds: float) -> Dictionary:
	# A round won: the record, and the prize (the first-time one the first time). Returns the prize.
	var r: Dictionary = records.get(id, {"wins": 0, "best": 0.0})
	var first := int(r.get("wins", 0)) == 0
	r["wins"] = int(r.get("wins", 0)) + 1
	var was := float(r.get("best", 0.0))
	r["best"] = seconds if was <= 0.0 or seconds < was else was
	records[id] = r
	var prize: Dictionary = round_of(id).get("first" if first else "again", {})
	if int(prize.get("sparkles", 0)) > 0:
		Game.add_sparkles(int(prize.sparkles))
	if int(prize.get("remnants", 0)) > 0:
		Remnants.add(int(prize.remnants))
	if prize.has("item") and not Game.has_item("shop:" + str(prize.item)):
		Game.items.append("shop:" + str(prize.item))           # a hat (shop/items.json, scripts/cosmetics.gd)
	Dialogue.set_flag("arena_won_" + id)
	changed.emit()
	return prize.merged({"first": first})


static func prize_text(prize: Dictionary) -> String:
	var bits: Array[String] = []
	if int(prize.get("sparkles", 0)) > 0:
		bits.append("✦ %d sparkles" % int(prize.sparkles))
	if int(prize.get("remnants", 0)) > 0:
		bits.append(Remnants.words(int(prize.remnants)))
	if prize.has("item"):
		bits.append("the Champion's Cup")
	return " and ".join(bits)


static func clock_text(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]


func medals() -> int:
	var n := 0
	for c in CHALLENGES:
		if wins(str(c.id)) > 0:
			n += 1
	return n


func save_data() -> Dictionary:
	return {"records": records.duplicate(true)}


func load_data(data: Dictionary) -> void:
	reset()
	var r = data.get("records", {})
	if r is Dictionary:
		for k in r:
			if r[k] is Dictionary:
				records[str(k)] = {"wins": maxi(int(r[k].get("wins", 0)), 0), "best": maxf(float(r[k].get("best", 0.0)), 0.0)}
	changed.emit()


func reset() -> void:
	records.clear()
	coming_out = false
	changed.emit()


# -----------------------------------------------------------------------------
# The Arena Gate, in the Void
# -----------------------------------------------------------------------------
func gate_open() -> bool:
	# Once The First Night's done (old saves from before it have it done)
	return Quests.is_done("first_night") or not Quests.is_started("first_night") and Dialogue.flags.has("popped_gloop_king")


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene as Node3D
	if scene == null or scene.scene_file_path != TOWN or scene.get_node_or_null("Arena Gate") != null:
		return
	_place_gate(scene)
	if coming_out:
		coming_out = false
		_land_by_gate.call_deferred()


func gate_out() -> Dictionary:
	# Where you come out, back from the arena: just in front of the gate, facing the town
	var at := GATE + GATE_FACING * 4.5
	return {"position": Vector3(at.x, 2.0, at.y), "yaw": atan2(GATE_FACING.x, GATE_FACING.y)}


func _land_by_gate() -> void:
	await get_tree().physics_frame
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var scene := get_tree().current_scene as Node3D
	if player == null or scene == null:
		return
	var at: Vector3 = gate_out().position
	player.global_position = Bosses.ground(scene, at.x, at.z) + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO


func enter() -> void:
	if not gate_open():
		Game.message("The Star Arena's doors are shut. A sign says: \"Opening soon!\"")
		return
	Game.pending_message = ""
	Game.go(LEVEL, "Entrance", "the Star Arena")


func _mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.5 if metal == 0.0 else 0.3
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _place_gate(scene: Node3D) -> void:
	# A curved front of the stadium: a half-ring of lilac arches, two tall gold-topped pillars either side of the
	# gateway, a big star over it and a sign. The gateway itself is a dark tunnel mouth (going in is the spot in front).
	var gate := Node3D.new()
	gate.name = "Arena Gate"
	gate.set_script(load("res://scripts/landmark.gd"))
	gate.set("label", "Star Arena")
	scene.add_child(gate)
	gate.global_position = Bosses.ground(scene, GATE.x, GATE.y)
	gate.rotation.y = atan2(GATE_FACING.x, GATE_FACING.y)            # its +Z faces the town
	var stone := _mat(Color(0.78, 0.66, 0.92))
	var dark := _mat(Color(0.12, 0.08, 0.2))
	var gold := _mat(Color(1.0, 0.8, 0.3), 0.15, 0.8)
	var star_m := _mat(Color(1.0, 0.9, 0.4), 1.2)
	var body := StaticBody3D.new()
	body.name = "Gate Walls"
	gate.add_child(body)
	# The curved wall behind: arches round a half circle, opening towards +Z
	var r := 9.0
	for k in 9:
		var a := PI + PI * (k + 0.5) / 9.0                    # round the back half (-Z side)
		var at := Vector3(cos(a) * r, 0, sin(a) * r)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.3, 5.0, 0.8)
		seg.mesh = bm
		seg.material_override = stone
		seg.position = at + Vector3(0, 2.5, 0)
		seg.rotation.y = -a + PI / 2.0
		gate.add_child(seg)
		var hole := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(1.6, 2.4, 0.85)
		hole.mesh = hm
		hole.material_override = dark
		hole.position = at + Vector3(0, 2.6, 0)
		hole.rotation.y = seg.rotation.y
		gate.add_child(hole)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		cs.position = seg.position
		cs.rotation.y = seg.rotation.y
		body.add_child(cs)
	# The two pillars, with gold tops
	for side in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 1.0
		cm.height = 7.0
		p.mesh = cm
		p.material_override = stone
		p.position = Vector3(side * GATE_WIDE * 0.55, 3.5, -1.0)
		gate.add_child(p)
		var cap := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 1.4
		cap.mesh = sm
		cap.material_override = gold
		cap.position = p.position + Vector3(0, 3.8, 0)
		gate.add_child(cap)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 1.0
		cyl.height = 7.0
		cs.shape = cyl
		cs.position = p.position
		body.add_child(cs)
	# The big star over the gateway
	var star := MeshInstance3D.new()
	star.name = "Gate Star"
	star.mesh = StarBubble.star_mesh()
	star.material_override = star_m
	star.scale = Vector3.ONE * 2.6
	star.position = Vector3(0, 7.2, -1.0)
	gate.add_child(star)
	var sign := Label3D.new()
	sign.name = "Gate Sign"
	sign.text = "THE STAR ARENA" if gate_open() else "THE STAR ARENA\nOpening soon!"
	sign.font_size = 52
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.88, 0.45)
	sign.outline_size = 12
	sign.outline_modulate = Color(0.15, 0.08, 0.2)
	sign.position = Vector3(0, 5.2, 0.2)
	gate.add_child(sign)
	var spot = (load("res://scripts/use_spot.gd") as GDScript).call("make", Vector3(0, 0, 1.2),
		func() -> String: return "go in to the Star Arena" if gate_open() else "read the sign", enter, 2.8, 2.6)
	spot.name = "Gate Spot"
	gate.add_child(spot)
