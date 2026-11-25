extends Node3D

# What makes the swamps hard (Hayden, 24 Nov 2026: "make it very confusing and have traps, hidden enemies, giant things
# that chase you"). Made by scripts/swamp.gd at the end of its _ready() as its "Dangers" child, from its layout. Still
# kid-sized like the rest of the game: nothing worse than a bump, and every danger shows itself a moment before.
#  - Dead ends: islands that go nowhere (the layout's "decoys"), each with a Muck Mimic, a chest that snaps at you and
#    giggles out Mucklings when you open it. A sign by the way in fibs about which way the chest is ("fib_sign").
#  - Snap Traps: mossy jaws hidden in the reeds on the islands. Step close and they rattle (time to hop clear), then
#    SNAP: a bump and a shove. They open again a few seconds later.
#  - Lurkers: only two eyes in the water beside a way across, seen close up. Come near and a Muckling bursts out.
#  - The giant ("giant": Old Mossback in the Mothmire, the Gulper in the Poison Mire): asleep under the mud as a mossy
#    hump. Come near and it heaves itself up and wades after you, slower than a run. If it catches you it gulps you
#    and spits you back out at the Mire Edge (swamp.float_home()). It gives up if you leave the swamp or get well away.
# swamp.hazards false (tests) keeps all of it still.

const WAILER := preload("res://scripts/bog_wailer.gd")
const USE_SPOT := preload("res://scripts/use_spot.gd")

const TRAP_NEAR := 1.4                   # a Snap Trap rattles when she's this close...
const TRAP_TELL := 0.6                   # ...for this long...
const TRAP_REACH := 1.5                  # ...then snaps on her if she's still this close
const TRAP_SHUT := 3.0
const TRAP_SHOVE := 7.0
const LURK_SEEN := 7.0                   # a Lurker's eyes only show this close
const LURK_NEAR := 4.0                   # and it bursts out this close
const LURK_AGAIN := 45.0
const MIMIC_AGAIN := 60.0
const GIANT_WAKE := 12.0                 # metres from its lair
const GIANT_SPEED := 3.2                 # she runs at 5, sprints at 8 (slower in the murk)
const GIANT_CATCH := 2.3
const GIANT_GIVE_UP := 28.0              # seconds of chasing
const GIANT_LEASH := 34.0                # metres from its lair
const GIANT_REST := 10.0
const GIANT_SUNK := -3.4                 # how far under it sleeps

const SURFACE := -0.12                   # (the same as scripts/swamp.gd's: its constants can't be read with get())
const BED := -0.8
var sw: Node3D                           # the swamp (scripts/swamp.gd)
var traps: Array[Node3D] = []
var lurkers: Array[Node3D] = []
var mimics: Array[Node3D] = []
var giant: Node3D
var giant_state := "sleep"               # sleep, wake, chase, gulp, home, sink
var giant_name := ""
var lair := Vector3.ZERO
var snaps := 0                           # (tests read these)
var gulps := 0
var _rng := RandomNumberGenerator.new()
var _gt := 0.0                           # time in the giant's state
var _g_rest := 0.0
var _told_giant := false


func _ready() -> void:
	_rng.seed = hash(str(sw.get("kind")) + "dangers")
	_decoys()
	_fib_sign()
	_traps()
	_lurkers()
	_giant()


func _lay() -> Dictionary:
	return sw.get("lay")


func _islands() -> Array:
	return sw.get("islands")


func _player() -> CharacterBody3D:
	return sw.get("player") as CharacterBody3D


func _col(n: String) -> Color:
	return _lay()[n] as Color


# Dead ends and the fibbing sign -----------------------------------------------------------------------------------------
func _decoys() -> void:
	var g := Node3D.new()
	g.name = "Muck Mimics"
	add_child(g)
	for i in (_lay().get("decoys", []) as Array):
		var isl: Dictionary = _islands()[int(i)]
		var at: Vector3 = (isl.at as Vector3)
		var c: Vector3 = sw.get("centre")
		var m := Node3D.new()
		m.name = "Muck Mimic"
		m.position = at + (at - c).normalized() * float(isl.r) * 0.3
		m.rotation.y = atan2(c.x - m.position.x, c.z - m.position.z)
		g.add_child(m)
		# Looks just like the real chest, but its trim's a shade off and the keyhole winks
		var wood: Material = sw.call("_mat", "Chest Wood", _col("bark").lightened(0.3))
		var trim: Material = sw.call("_mat", "Mimic Trim", (Color(0.7, 0.85, 0.4) if sw.get("poison") else Color(0.75, 0.7, 0.95)).darkened(0.1), 0.4, 0.5)
		sw.call("_mesh", sw.call("_box", Vector3(1.1, 0.6, 0.7)), wood, Vector3(0, 0.3, 0), m)
		for x: float in [-0.45, 0.45]:
			sw.call("_mesh", sw.call("_box", Vector3(0.08, 0.62, 0.72)), trim, Vector3(x, 0.3, 0), m)
		var lid := Node3D.new()
		lid.name = "Lid"
		lid.position = Vector3(0, 0.6, -0.35)
		m.add_child(lid)
		sw.call("_mesh", sw.call("_box", Vector3(1.12, 0.22, 0.72)), wood, Vector3(0, 0.11, 0.35), lid)
		var teeth: Material = sw.call("_mat", "Mimic Teeth", Color(0.95, 0.92, 0.8), 0.5)
		for k in 6:
			var t: MeshInstance3D = sw.call("_mesh", sw.call("_cyl", 0.0, 0.06, 0.14, 6), teeth,
				Vector3(-0.42 + k * 0.168, -0.06, 0.68), lid, Vector3(PI, 0, 0))
			t.name = "Tooth"
		var eye: Material = sw.call("_mat", "Mimic Eye", Color(1.0, 0.9, 0.3), 0.3, 2.0)
		for x: float in [-0.2, 0.2]:
			var e: MeshInstance3D = sw.call("_mesh", sw.call("_ball", 0.07, 8), eye, Vector3(x, 0.05, 0.5), lid)
			e.name = "Mimic Eye"
			e.visible = false
		sw.call("_solid", sw.call("_box_shape", Vector3(1.1, 0.8, 0.7)), Vector3(0, 0.4, 0), m)
		m.set_meta("again", 0.0)
		var spot := USE_SPOT.make(Vector3(0, 0.2, 0.9), _mimic_offer.bind(m), open_mimic.bind(m), 2.2, 2.4)
		spot.name = "Chest Spot"
		m.add_child(spot)
		mimics.append(m)


func _mimic_offer(m: Node3D) -> String:
	return "open the chest" if float(m.get_meta("again")) <= 0.0 else ""


func open_mimic(m: Node3D) -> void:
	# It was never a chest
	if float(m.get_meta("again")) > 0.0:
		return
	m.set_meta("again", MIMIC_AGAIN)
	var lid := m.get_node("Lid") as Node3D
	for e in lid.find_children("Mimic Eye", "", false, false):
		(e as Node3D).visible = true
	var tw := lid.create_tween()
	tw.tween_property(lid, "rotation:x", -0.9, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(lid, "rotation:x", 0.0, 0.08)
	tw.tween_property(lid, "rotation:x", -0.7, 0.12)
	tw.tween_property(lid, "rotation:x", 0.0, 0.08)
	Juice.blip("clunk", 0.7, -2.0)
	Juice.shake(0.25)
	var p := _player()
	if p and not p.call("is_invulnerable"):
		p.call("hurt", 1, m.global_position)
	for k in 2:
		var a := m.rotation.y + (-0.9 if k == 0 else 0.9)
		_muckling(m.global_position + Vector3(sin(a), 0, cos(a)) * 1.8 + Vector3(0, 0.5, 0))
	Game.message("It's a Muck Mimic! Not the real chest.")


func _fib_sign() -> void:
	var f: Array = _lay().get("fib_sign", [])
	if f.is_empty():
		return
	var isl: Dictionary = _islands()[int(f[0])]
	var to: Vector3 = (_islands()[int(f[1])] as Dictionary).at
	var at: Vector3 = isl.at
	var dir := (to - at)
	dir.y = 0.0
	dir = dir.normalized()
	var s := Node3D.new()
	s.name = "Fibbing Sign"
	s.position = at + dir * float(isl.r) * 0.7 + Vector3(dir.z, 0, -dir.x) * 1.0
	add_child(s)
	var wood: Material = sw.call("_mat", "Sign Wood", _col("bark").lightened(0.35))
	sw.call("_mesh", sw.call("_cyl", 0.07, 0.08, 1.8, 8), wood, Vector3(0, 0.9, 0), s)
	# An arrow-shaped board that points along dir (its +X)
	var board := Node3D.new()
	board.position = Vector3(0, 1.55, 0)
	board.rotation.y = atan2(-dir.z, dir.x)
	s.add_child(board)
	sw.call("_mesh", sw.call("_box", Vector3(1.2, 0.34, 0.06)), wood, Vector3(0.2, 0, 0), board)
	sw.call("_mesh", sw.call("_box", Vector3(0.32, 0.32, 0.06)), wood, Vector3(0.82, 0, 0), board, Vector3(0, 0, PI / 4.0))
	for side: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.text = str(f[2])
		l.font_size = 40
		l.pixel_size = 0.0042
		l.modulate = Color(1.0, 0.95, 0.8)
		l.outline_size = 8
		l.position = Vector3(0.25, 0, 0.04 * side)
		l.rotation.y = 0.0 if side > 0 else PI
		board.add_child(l)


# Snap Traps -------------------------------------------------------------------------------------------------------------
func _traps() -> void:
	var g := Node3D.new()
	g.name = "Snap Traps"
	add_child(g)
	var jaw_m: Material = sw.call("_mat", "Snap Trap Jaw", _col("moss").darkened(0.15))
	var gum: Material = sw.call("_mat", "Snap Trap Gum", Color(0.55, 0.2, 0.3), 0.7)
	var teeth: Material = sw.call("_mat", "Snap Trap Teeth", Color(0.92, 0.9, 0.78), 0.5)
	var isl_list := _islands()
	for i in range(1, isl_list.size()):
		var isl: Dictionary = isl_list[i]
		var at: Vector3 = isl.at
		var a := _rng.randf() * TAU
		var p := at + Vector3(cos(a), 0, sin(a)) * float(isl.r) * 0.6
		# keep clear of the chest, the hut and a mimic
		var ch: Node3D = sw.get("chest")
		if ch and Vector2(p.x, p.z).distance_to(Vector2(ch.global_position.x, ch.global_position.z)) < 2.6:
			p = at - (p - at)
		var t := Node3D.new()
		t.name = "Snap Trap"
		t.position = Vector3(p.x, 0.04, p.z)
		t.rotation.y = _rng.randf() * TAU
		g.add_child(t)
		sw.call("_mesh", sw.call("_cyl", 0.62, 0.7, 0.08, 14), gum, Vector3.ZERO, t)
		for side: float in [1.0, -1.0]:
			var hinge := Node3D.new()
			hinge.name = "Jaw" if side > 0 else "Jaw2"
			t.add_child(hinge)
			var half := Node3D.new()
			half.rotation.y = 0.0 if side > 0 else PI
			hinge.add_child(half)
			var jaw: MeshInstance3D = sw.call("_mesh", sw.call("_box", Vector3(1.1, 0.42, 0.08)), jaw_m, Vector3(0, 0.21, 0.04), half)
			jaw.name = "Look"
			for k in 5:
				sw.call("_mesh", sw.call("_cyl", 0.0, 0.05, 0.16, 5), teeth, Vector3(-0.4 + k * 0.2, 0.48, 0.04), half)
			# a few reeds stuck to it, so it hides in the reeds round it
			for k in 3:
				sw.call("_mesh", sw.call("_cyl", 0.012, 0.018, 0.6, 4), jaw_m, Vector3(-0.35 + k * 0.35, 0.6, 0.06), half,
					Vector3(0.2 * (k - 1), 0, 0))
			hinge.set_meta("side", side)
		t.set_meta("state", "open")
		t.set_meta("t", 0.0)
		_set_jaws(t, 1.0)
		traps.append(t)


func _set_jaws(t: Node3D, open: float) -> void:
	# open 1: lying flat out, 0: snapped shut upright
	for h in [t.get_node("Jaw"), t.get_node("Jaw2")]:
		var side := float((h as Node3D).get_meta("side"))
		var half := (h as Node3D).get_child(0) as Node3D
		half.rotation.x = 0.0
		(h as Node3D).rotation = Vector3(0, 0, 0)
		(h as Node3D).rotation.x = 1.35 * open * side if side > 0 else 0.0
		if side < 0:
			(h as Node3D).rotation.x = -1.35 * open


func _traps_step(delta: float, p: CharacterBody3D) -> void:
	for t in traps:
		var st := str(t.get_meta("state"))
		var tt := float(t.get_meta("t")) + delta
		var d := Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(t.global_position.x, t.global_position.z))
		var low := absf(p.global_position.y - t.global_position.y) < 1.6
		match st:
			"open":
				if d < TRAP_NEAR and low and bool(sw.get("hazards")):
					st = "rattle"
					tt = 0.0
					Juice.blip("tick", 0.6, -4.0)
			"rattle":
				var shake := sin(tt * 60.0) * 0.08
				_set_jaws(t, 1.0 - tt / TRAP_TELL * 0.15)
				(t.get_node("Jaw") as Node3D).rotation.z = shake
				(t.get_node("Jaw2") as Node3D).rotation.z = -shake
				if tt >= TRAP_TELL:
					st = "shut"
					tt = 0.0
					_set_jaws(t, 0.0)
					Juice.blip("clunk", 1.2, -2.0)
					Fx.burst(self, t.global_position + Vector3(0, 0.4, 0), _col("moss"), 8, 0.06, 2.0, -6.0, 0.4)
					if d < TRAP_REACH and low:
						snaps += 1
						if not p.call("is_invulnerable"):
							p.call("hurt", 1, t.global_position)
						var away := p.global_position - t.global_position
						away.y = 0.0
						p.velocity = away.normalized() * TRAP_SHOVE + Vector3.UP * 4.0 if away.length() > 0.01 \
							else Vector3.UP * 5.0
						Juice.shake(0.3)
						Game.message("SNAP! A Snap Trap in the reeds!")
			"shut":
				if tt >= TRAP_SHUT:
					st = "opening"
					tt = 0.0
			"opening":
				_set_jaws(t, minf(tt / 0.8, 1.0))
				if tt >= 0.8:
					st = "open"
		t.set_meta("state", st)
		t.set_meta("t", tt)


# Lurkers ---------------------------------------------------------------------------------------------------------------
func _lurkers() -> void:
	var g := Node3D.new()
	g.name = "Lurkers"
	add_child(g)
	var eye: Material = sw.call("_mat", "Lurker Eye", (_lay().wailer as Dictionary).eye as Color, 0.3, 2.5)
	var pupil: Material = sw.call("_mat", "Lurker Pupil", Color(0.02, 0.02, 0.03))
	var skin: Material = sw.call("_mat", "Lurker Skin", (_lay().water as Dictionary).scum as Color, 0.5)
	var ways: Array = []
	for w in ["walks", "stones", "logs"]:
		for i in (_lay()[w] as Array).size():
			ways.append([w, i])
	var k := 0
	for i in range(0, ways.size(), 2):
		var ends: Array = sw.call("way", str(ways[i][0]), int(ways[i][1]))
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var dir := (b - a).normalized()
		var side := 1.0 if k % 2 == 0 else -1.0
		var at := a.lerp(b, 0.55) + Vector3(dir.z, 0, -dir.x) * side * 2.6
		var l := Node3D.new()
		l.name = "Lurker"
		l.position = Vector3(at.x, SURFACE + 0.02, at.z)
		g.add_child(l)
		var look := Node3D.new()
		look.name = "Eyes"
		l.add_child(look)
		sw.call("_mesh", sw.call("_ball", 0.3, 10), skin, Vector3(0, -0.12, 0), look, Vector3.ZERO, Vector3(1.6, 0.5, 1.0))
		for x: float in [-0.16, 0.16]:
			sw.call("_mesh", sw.call("_ball", 0.1, 8), eye, Vector3(x, 0.05, 0.1), look)
			sw.call("_mesh", sw.call("_ball", 0.045, 6), pupil, Vector3(x, 0.06, 0.19), look)
		look.visible = false
		l.set_meta("again", 0.0)
		l.set_meta("out", null)
		lurkers.append(l)
		k += 1


func _lurkers_step(delta: float, p: CharacterBody3D) -> void:
	for l in lurkers:
		var again := maxf(float(l.get_meta("again")) - delta, 0.0)
		l.set_meta("again", again)
		var out = l.get_meta("out") if l.has_meta("out") else null
		var eyes := l.get_node("Eyes") as Node3D
		var d := Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(l.global_position.x, l.global_position.z))
		var ready_ := again <= 0.0 and (out == null or not is_instance_valid(out))
		eyes.visible = ready_ and d < LURK_SEEN
		if eyes.visible:
			eyes.rotation.y = atan2(p.global_position.x - l.global_position.x, p.global_position.z - l.global_position.z)
			eyes.position.y = sin(Time.get_ticks_msec() * 0.003 + l.global_position.x) * 0.03
		if ready_ and d < LURK_NEAR and bool(sw.get("hazards")):
			var g := _muckling(l.global_position + Vector3(0, 0.2, 0))
			l.set_meta("out", g)
			l.set_meta("again", LURK_AGAIN)
			eyes.visible = false
			Fx.burst(self, l.global_position + Vector3(0, 0.2, 0), (_lay().water as Dictionary).scum as Color, 18, 0.1, 4.0, -8.0, 0.6)
			Juice.blip("squish", 0.8, -2.0)


func _muckling(at: Vector3) -> CharacterBody3D:
	# A Muckling, the same as a Bog Wailer calls up (scripts/bog_wailer.gd)
	at.y = maxf(at.y, BED + 0.3)
	return WAILER.make_muckling(self, at, (_lay().wailer as Dictionary).muck, BED, SURFACE)


# The giant -------------------------------------------------------------------------------------------------------------
func _giant() -> void:
	var gd: Array = _lay().get("giant", [])
	if gd.is_empty():
		return
	giant_name = str(gd[2])
	lair = Vector3(float(gd[0]), 0, float(gd[1]))
	giant = Node3D.new()
	giant.name = giant_name.trim_prefix("the ").capitalize()
	giant.position = lair + Vector3(0, GIANT_SUNK, 0)
	add_child(giant)
	var poison := bool(sw.get("poison"))
	var body_c: Color = _col("land").lerp((_lay().water as Dictionary).scum as Color, 0.35)
	var body: Material = sw.call("_mat", "Giant Mud", body_c, 0.95)
	var moss: Material = sw.call("_mat", "Giant Moss", _col("moss"), 0.95)
	var eye: Material = sw.call("_mat", "Giant Eye", (_lay().wailer as Dictionary).eye as Color, 0.3, 3.0)
	var dark: Material = sw.call("_mat", "Giant Mouth", Color(0.05, 0.02, 0.06))
	var drip: Material = sw.call("_mat", "Giant Drip", (_lay().water as Dictionary).scum as Color, 0.3, 0.6 if poison else 0.0)
	var look := Node3D.new()
	look.name = "Look"
	giant.add_child(look)
	# A huge lumpy mound of mud with a mossy back, long dripping arms and a wide, gappy grin (more goofy than gory)
	sw.call("_mesh", sw.call("_ball", 1.0, 18), body, Vector3(0, 2.6, 0), look, Vector3.ZERO, Vector3(2.6, 2.6, 2.2))
	sw.call("_mesh", sw.call("_ball", 1.0, 14), body, Vector3(0, 4.6, 0.3), look, Vector3.ZERO, Vector3(1.9, 1.5, 1.7))
	for k in 9:
		var a := _rng.randf_range(-2.4, 2.4)
		sw.call("_mesh", sw.call("_ball", 1.0, 8), moss, Vector3(sin(a) * 1.7, 4.0 + _rng.randf_range(0.0, 1.6), -cos(a) * 1.5 - 0.3),
			look, Vector3.ZERO, Vector3.ONE * _rng.randf_range(0.5, 0.9))
	for x: float in [-0.7, 0.7]:
		sw.call("_mesh", sw.call("_ball", 0.34, 12), eye, Vector3(x, 5.0, 1.75), look)
		sw.call("_mesh", sw.call("_ball", 0.14, 8), dark, Vector3(x, 5.0, 2.06), look)
	var mouth: MeshInstance3D = sw.call("_mesh", sw.call("_box", Vector3(1.8, 0.5, 0.3)), dark, Vector3(0, 4.1, 1.75), look)
	mouth.name = "Mouth"
	var teeth: Material = sw.call("_mat", "Giant Teeth", Color(0.9, 0.88, 0.7), 0.5)
	for k in 4:
		sw.call("_mesh", sw.call("_box", Vector3(0.22, 0.24, 0.1)), teeth, Vector3(-0.6 + k * 0.42 + (0.1 if k > 1 else 0.0), 4.28, 1.92), look)
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "Arm"
		arm.position = Vector3(side * 2.3, 3.6, 0.4)
		arm.set_meta("side", side)
		look.add_child(arm)
		sw.call("_mesh", sw.call("_cyl", 0.35, 0.55, 3.4, 10), body, Vector3(0, -1.6, 0.3), arm, Vector3(0.25, 0, side * 0.25))
		sw.call("_mesh", sw.call("_ball", 0.6, 10), body, Vector3(side * 0.4, -3.3, 0.8), arm)
		for k in 3:
			sw.call("_mesh", sw.call("_cyl", 0.1, 0.02, 0.6, 5), drip, Vector3(side * 0.4 + (k - 1) * 0.25, -3.9, 0.8), arm)
	# Baked detail: warty mud on its body and hands, a thick fuzz of moss on its back
	_dress_giant.call_deferred([[body, "boss_warts"], [moss, "boss_fuzz"]])
	var l := OmniLight3D.new()
	l.light_color = (_lay().wailer as Dictionary).eye as Color
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.position = Vector3(0, 5.0, 2.6)
	giant.add_child(l)


func _dress_giant(parts: Array) -> void:
	if giant:
		(load("res://scripts/detail_props.gd") as GDScript).call("dress_surfaces", giant, parts)


func _giant_step(delta: float, p: CharacterBody3D) -> void:
	if giant == null:
		return
	_gt += delta
	_g_rest = maxf(_g_rest - delta, 0.0)
	var surface := SURFACE
	var floating := bool(sw.get("_floating"))
	var pf := Vector2(p.global_position.x, p.global_position.z)
	var gf := Vector2(giant.global_position.x, giant.global_position.z)
	var bob := sin(_gt * 3.0) * 0.12
	var look := giant.get_node("Look") as Node3D
	match giant_state:
		"sleep":
			giant.position.y = GIANT_SUNK + sin(_gt * 0.8) * 0.08       # a mossy hump breathing in the mud
			if _g_rest <= 0.0 and bool(sw.get("hazards")) and not floating and pf.distance_to(Vector2(lair.x, lair.z)) < GIANT_WAKE \
					and bool(sw.call("in_basin", p.global_position)):
				_set_giant("wake")
				Juice.blip("wail", 0.45, 0.0)
				Juice.shake(0.5)
				Juice.rumble(0.6, 0.4, 1.0)
				Fx.burst(self, giant.global_position + Vector3(0, -GIANT_SUNK, 0), (_lay().water as Dictionary).scum as Color, 30, 0.14, 5.0, -8.0, 1.0)
				Game.message(("%s wakes up! RUN!" % giant_name.capitalize()) if not _told_giant else "%s's after you again!" % giant_name.capitalize())
				_told_giant = true
		"wake":
			giant.position.y = lerpf(GIANT_SUNK, surface - 0.9, clampf(_gt / 1.6, 0.0, 1.0))
			_face(p.global_position, delta * 4.0)
			if _gt >= 1.6:
				_set_giant("chase")
		"chase":
			var to := pf - gf
			if to.length() > 0.01:
				var step := to.normalized() * GIANT_SPEED * delta
				gf += step
			# never out of the swamp
			var c: Vector3 = sw.get("centre")
			var cf := Vector2(c.x, c.z)
			var rr := float(sw.get("radius")) - 2.0
			if gf.distance_to(cf) > rr:
				gf = cf + (gf - cf).normalized() * rr
			giant.global_position = Vector3(gf.x, surface - 0.9 + bob, gf.y)
			_face(p.global_position, delta * 5.0)
			_swing(_gt)
			if pf.distance_to(gf) < GIANT_CATCH and p.global_position.y < surface + 3.0 and not floating:
				_gulp()
			elif _gt > GIANT_GIVE_UP or pf.distance_to(Vector2(lair.x, lair.z)) > GIANT_LEASH \
					or not bool(sw.call("in_basin", p.global_position)) or floating:
				_set_giant("home")
				Game.message("%s gives up and wades home." % giant_name.capitalize())
		"gulp":
			look.scale = Vector3.ONE * (1.0 + 0.1 * sin(_gt * 20.0) * maxf(1.0 - _gt, 0.0))
			if _gt > 1.0:
				look.scale = Vector3.ONE
				_set_giant("home")
		"home":
			var to := Vector2(lair.x, lair.z) - gf
			if to.length() > 0.3:
				gf += to.normalized() * minf(3.0 * delta, to.length())
				giant.global_position = Vector3(gf.x, surface - 0.9 + bob, gf.y)
				_face(Vector3(lair.x, 0, lair.z), delta * 3.0)
				_swing(_gt)
			else:
				_set_giant("sink")
		"sink":
			giant.position.y = lerpf(surface - 0.9, GIANT_SUNK, clampf(_gt / 1.5, 0.0, 1.0))
			if _gt >= 1.5:
				_set_giant("sleep")
				_g_rest = GIANT_REST


func _set_giant(s: String) -> void:
	giant_state = s
	_gt = 0.0


func _face(at: Vector3, w: float) -> void:
	var want := atan2(at.x - giant.global_position.x, at.z - giant.global_position.z)
	giant.rotation.y = lerp_angle(giant.rotation.y, want, clampf(w, 0.0, 1.0))


func _swing(t: float) -> void:
	for a in giant.get_node("Look").find_children("Arm", "", false, false):
		var side := float((a as Node3D).get_meta("side"))
		(a as Node3D).rotation.x = sin(t * 3.0 + (0.0 if side > 0 else PI)) * 0.4


func _gulp() -> void:
	# GULP... PTOO! Back to the Mire Edge in a bubble, no harm done
	gulps += 1
	_set_giant("gulp")
	Juice.blip("squish", 0.4, 0.0)
	Juice.shake(0.6)
	Juice.rumble(0.8, 0.6, 0.5)
	Game.message("GULP! ...PTOO! %s spat you out." % giant_name.capitalize())
	sw.call("float_home")


# Every frame -------------------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	for m in mimics:
		m.set_meta("again", maxf(float(m.get_meta("again")) - delta, 0.0))
		if float(m.get_meta("again")) <= 0.0:
			for e in (m.get_node("Lid") as Node3D).find_children("Mimic Eye", "", false, false):
				(e as Node3D).visible = false
	var p := _player()
	if p == null or not is_instance_valid(p):
		return
	var c: Vector3 = sw.get("centre")
	if Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(c.x, c.z)) > float(sw.get("radius")) + 12.0 \
			and giant_state == "sleep":
		return
	_traps_step(delta, p)
	_lurkers_step(delta, p)
	_giant_step(delta, p)
