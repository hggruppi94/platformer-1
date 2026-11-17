extends SceneTree

# Checks the secret volcano tunnel in Rhythm Springs (scripts/volcano_depths.gd) and Old Ember, the optional boss in
# its magma chamber (scripts/old_ember.gd). Before the world's mended the crack at the peak's foot is just a crack;
# after, it lets you squeeze in. The whole cave is under the ground. You really walk from the crack's mouth to it, and
# down the tunnel to the chamber. Steam vents bounce you, the lava ring, the stream and a flaring lava crack bump you
# back. Old Ember sleeps till you come close, warns before it moves, goes back to sleep if you leave, its phases only
# go forwards (a burst never skips one), its red-hot crust needs the three Geyser Stones, and calming it pays once.
# Then the Ember Chest (once a visit), the steam lift to the crater's rim and the way back down.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_volcano.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.volcano_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.volcano_test_backup.cfg"
const WORLD := "res://scenes/portal_worlds/rhythm_springs.tscn"
var V: GDScript    # loaded once the autoloads are up (it reads Portals)
const L := preload("res://scripts/rhythm_land.gd")

var failures := 0
var game: Node
var portals: Node
var world: Node3D
var depths: Node3D
var boss: CharacterBody3D
var p: CharacterBody3D


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _load() -> void:
	change_scene_to_file(WORLD)
	await _frames(10)
	await _physics(10)
	world = current_scene as Node3D
	p = get_first_node_in_group("player") as CharacterBody3D
	depths = world.get_node_or_null(V.NODE) as Node3D if world else null
	boss = depths.get("boss") as CharacterBody3D if depths else null


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	V = load("res://scripts/volcano_depths.gd")
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals.home_calls.enabled = false
	portals.cleared_worlds.erase("rhythm_springs")

	# --- Before the world's mended: just a crack ---
	await _load()
	check(depths != null and boss != null and p != null, "Rhythm Springs has its Volcano Depths and Old Ember")
	if depths == null or p == null:
		_finish()
		return
	var spot := depths.find_child("Crack Spot", true, false)
	check(spot != null and str(spot.offer.call()) == "", "before the world's mended the crack offers nothing")
	check(not (depths.find_child("Ember Crack", true, false).get_node("Glow") as Node3D).visible, "...and doesn't glow")
	_check_shape()

	# --- Mended: the way in ---
	portals.cleared_worlds.append("rhythm_springs")
	await _load()
	spot = depths.find_child("Crack Spot", true, false)
	check(str(spot.offer.call()) != "", "once it's mended the crack offers \"%s\"" % str(spot.offer.call()))
	var out: Vector3 = depths.call("outside")
	var f: Vector3 = depths.call("_crack_facing")
	await _route("up to the crack's mouth across the tier", out + f * 7.0, [out + f * 3.0, out], -1.0)
	var sign := depths.find_child("Crack Sign", true, false) as GeometryInstance3D
	check(sign != null and sign.visibility_range_end > 0.0 and sign.visibility_range_end <= 12.0, "its sign only shows up close")
	var on_map := false
	for n in get_nodes_in_group("map_landmarks"):
		on_map = on_map or depths.is_ancestor_of(n)
	check(not on_map, "it isn't on the map")

	spot.act.call()
	await _wait(1.2)
	var hall: Vector3 = V.mark("hall")
	check(p.global_position.distance_to(hall) < 3.5, "squeezing in puts you in the Ember Hall (%.1f m off)" % p.global_position.distance_to(hall))
	await _settle()
	check(p.is_on_floor(), "...standing on its floor")

	# Down the tunnel to the chamber, on foot (vents may bounce you on the way: that's fine)
	var steps: Array = []
	for r in V.ROUTE:
		steps.append(V.pt(r))
	steps.append(V.mark("chamber") + (V.pt(V.ROUTE[V.ROUTE.size() - 1]) - V.mark("chamber")).normalized() * 9.5)
	await _route("down the whole tunnel to the chamber's edge", hall, steps, -1.0)
	check(int(boss.get("state")) == 0, "Old Ember's still asleep at the chamber's edge")

	# --- Hazards ---
	var vents: Array = depths.get("_vents")
	check(vents.size() == 3, "three steam vents in the tunnel")
	if vents.size() > 0:
		var v: Node3D = vents[0]
		p.global_position = v.global_position + Vector3(0, 1.0, 0)
		await _settle()
		depths.call("puff", v)
		await _physics(2)
		check(p.velocity.y > 5.0, "standing on a vent when it puffs bounces you up (%.1f m/s, feet %.2f over it)" % [p.velocity.y, _feet() - v.global_position.y])
	var c: Vector3 = V.mark("chamber")
	var outd: Vector3 = V._out_dir()
	await _wait(2.5)
	p.global_position = c + outd * (V.LAVA_R + 0.8) + Vector3(0, 1.5, 0)
	await _physics(6)
	var flat: float = Vector2(p.global_position.x - c.x, p.global_position.z - c.z).length()
	check(flat < V.ARENA_R, "stepping into the lava ring bumps you back onto the floor (%.1f m out)" % flat)
	p.global_position = V.pt(V.ROUTE[4]) + Vector3(0, 1.0, 0)      # (that woke it: back up the tunnel to let it sleep)
	await _physics(10)

	# --- Old Ember ---
	check(depths.get("cracks").size() == 3, "three lava cracks across the arena floor")
	await _wait(2.5)
	var mouth: Vector3 = (V.pt(V.ROUTE[V.ROUTE.size() - 1]) - c)
	mouth.y = 0
	p.global_position = c + mouth.normalized() * 9.5 + Vector3(0, 1.0, 0)
	await _settle()
	check(int(boss.get("state")) == 0, "it stays asleep while you're on the causeway at the edge")
	p.global_position = c + outd * 5.0 + Vector3(0, 1.0, 0)
	await _physics(5)
	check(int(boss.get("state")) != 0, "come close and it wakes")
	var tells := false
	for i in 60 * 6:
		await physics_frame
		game.hp = 10
		var bt: Variant = boss.get_meta("boss_tell") if boss.has_meta("boss_tell") else null
		tells = bt != null and is_instance_valid(bt)
		if tells:
			break
	check(tells, "it warns before its first move")
	# A flaring lava crack bumps you (once it's awake)
	await _wait(2.5)
	var crack: Node3D = depths.get("cracks")[0]
	var ca: Vector3 = crack.get_meta("a")
	var cb: Vector3 = crack.get_meta("b")
	p.global_position = (ca + cb) * 0.5 + Vector3(0, 1.0, 0)
	await _physics(3)
	depths.call("flare_crack", 0)
	await _physics(3)
	var q: Vector3 = Geometry3D.get_closest_point_to_segment(p.global_position, ca, cb)
	check(Vector2(p.global_position.x - q.x, p.global_position.z - q.z).length() > 1.0, "a flaring lava crack bumps you off it")
	await _wait(1.0)
	# Leave and it goes back to sleep
	boss.set("hits", 0)
	p.global_position = V.pt(V.ROUTE[4]) + Vector3(0, 1.0, 0)
	await _physics(5)
	check(int(boss.get("state")) == 0 and int(boss.get("hits")) == 0, "go back up the tunnel and it settles back to sleep")

	# Phases: a burst never skips one, and the latch only goes forward
	var sparkles: int = game.sparkles
	var rem: int = root.get_node("Remnants").count
	p.global_position = c + outd * 7.5 + Vector3(0, 1.0, 0)
	await _settle()
	p.global_position = c + outd * 5.0 + Vector3(0, 1.0, 0)
	await _physics(5)
	check(str(boss.call("shot", 1, boss.global_position, Vector3.FORWARD)) == "miss", "bubbles bounce off it while it's up")
	boss.set("state", 4)                    # dazed
	boss.call("hurt", 15)
	check(int(boss.get("hits")) == 5 and int(boss.get("phase")) == 1, "a huge burst only takes it to the next phase (%d hits, phase %d)" % [boss.get("hits"), boss.get("phase")])
	await _wait(3.0)
	game.hp = 10
	check(bool(boss.get("shield_on")), "phase 2 starts with its crust red hot")
	boss.set("state", 4)
	check(str(boss.call("shot", 1, boss.global_position, Vector3.FORWARD)) == "miss", "...and red hot it can't be popped")
	boss.set("state", 1)
	var st: Array = boss.get("stones")
	check(st.size() == 3, "three Geyser Stones")
	var lit := 0
	for s in st:
		lit += 1 if bool(s.get_meta("lit", false)) else 0
	check(lit == 3, "...all glowing")
	for s in st:
		s.shot(1, s.global_position, Vector3.FORWARD)
	check(int(boss.get("state")) == 6 and not bool(boss.get("shield_on")), "all three geysers cool it and knock it over")
	boss.call("hurt", 15)
	check(int(boss.get("hits")) == 10 and int(boss.get("phase")) == 2, "...and again the next phase is as far as a burst goes")
	check(int(boss.call("phase_for", 3)) == 0 and int(boss.get("phase")) == 2, "the phase never goes back")
	await _wait(3.0)
	game.hp = 10
	boss.set("state", 4)
	boss.set("_daze_hits", 0)
	boss.call("hurt", 5)
	check(bool(boss.get("defeated")), "15 hits calm it down")
	check(game.sparkles == sparkles + 40 and root.get_node("Remnants").count == rem + 5, "calming it: 40 sparkles and 5 Remnants")
	check(game.has_item("shop:ember_frills"), "...and the Ember Frills")
	check(bool(root.get_node("Dialogue").flags.get("old_ember_calmed", false)), "...and it's remembered")

	# The chest, once a visit
	await _physics(5)
	var lift := depths.find_child("Steam Lift", true, false) as Node3D
	check(lift != null and lift.visible, "the steam lift opens once it's calm")
	sparkles = game.sparkles
	depths.call("open_chest")
	check(game.sparkles == sparkles + V.TREASURE, "the Ember Chest pays %d sparkles" % V.TREASURE)
	depths.set("_chest_open", false)
	depths.call("open_chest")
	check(game.sparkles == sparkles + V.TREASURE, "...only once a visit")

	# Up the steam and back down
	depths.call("ride_steam")
	await _wait(1.2)
	var look := depths.find_child("Crater Lookout", true, false) as Node3D
	var stand: Vector3 = look.get_meta("stand")
	check(p.global_position.distance_to(stand) < 2.5, "the steam carries you up to the Crater Lookout")
	await _settle()
	check(p.is_on_floor() and p.global_position.y > L.height(stand.x, stand.z) - 3.0, "...and you stand on its deck, %.0f m up" % p.global_position.y)
	depths.call("way_down")
	await _wait(1.2)
	check(p.global_position.distance_to(depths.call("outside")) < 2.5, "the way down puts you back by the crack")

	# Next visit: it's back, but the reward's only once
	await _load()
	check(boss != null and not bool(boss.get("defeated")) and int(boss.get("state")) == 0, "next visit Old Ember's asleep in its chamber again")
	sparkles = game.sparkles
	boss.call("_wake")
	boss.set("phase", 2)
	boss.set("hits", 14)
	boss.set("state", 4)
	boss.set("_daze_hits", 0)
	boss.call("hurt", 1)
	check(bool(boss.get("defeated")) and game.sparkles == sparkles, "calming it again gives no second reward")
	var frills := 0
	for it in game.items:
		frills += 1 if it == "shop:ember_frills" else 0
	check(frills == 1, "only one pair of Ember Frills")
	_finish()


func _check_shape() -> void:
	# The cave stays under the ground everywhere: at least 1.5 m of rock over the tunnel's top and the chamber's roof
	var worst := INF
	var where := ""
	for i in V.ROUTE.size() - 1:
		for k in 8:
			var q: Vector3 = V.pt(V.ROUTE[i]).lerp(V.pt(V.ROUTE[i + 1]), k / 8.0)
			for s in [-1.0, 0.0, 1.0]:
				var side: Vector3 = (V.pt(V.ROUTE[i + 1]) - V.pt(V.ROUTE[i])).cross(Vector3.UP).normalized() * V.TUBE * s
				var top: float = q.y + V.TUBE
				var cover: float = L.height(q.x + side.x, q.z + side.z) - top
				if cover < worst:
					worst = cover
					where = "tunnel %d" % i
	var c: Vector3 = V.mark("chamber")
	for k in 16:
		var a := TAU * k / 16.0
		for r in [0.0, V.CHAMBER_R * 0.5, V.CHAMBER_R]:
			var at: Vector3 = c + Vector3(sin(a), 0, cos(a)) * r
			var cover: float = L.height(at.x, at.z) - (V.CHAMBER_FLOOR + 3.2 + 9.0 * (1.0 - pow(r / V.CHAMBER_R, 2.0) * 0.6))
			if cover < worst:
				worst = cover
				where = "chamber"
	var h: Vector3 = V.mark("hall")
	var hc: float = L.height(h.x, h.z) - (h.y + 4.8)
	if hc < worst:
		worst = hc
		where = "hall"
	check(worst >= 1.5, "the whole cave is under the ground (the thinnest roof is %.1f m, at the %s)" % [worst, where])
	check(L.height(V.mark("entrance").x, V.mark("entrance").z) > 20.0, "the crack is up on the North Highlands' upper tier")


func _route(what: String, start: Vector3, steps: Array, end_y: float) -> void:
	p.global_position = start + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _settle()
	var wpi := 0
	var got := false
	for i in 60 * 50:
		await physics_frame
		world.set("heat", 0.0)
		game.hp = 10
		var want: Vector3 = steps[wpi] - p.global_position
		want.y = 0
		if want.length() < 0.9:
			if wpi == steps.size() - 1:
				got = true
				break
			wpi += 1
		_steer(want.normalized())
	_release()
	await _physics(10)
	check(got and (end_y < -0.5 or absf(_feet() - end_y) < 0.6),
		"you can walk %s (step %d of %d, at %s)" % [what, wpi + 1, steps.size(), p.global_position.snapped(Vector3.ONE * 0.1)])


func _feet() -> float:
	var shape := (p.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	return p.global_position.y - shape.height / 2.0


func _settle() -> void:
	await _physics(40)


func _wait(s: float) -> void:
	await _physics(int(s * 60.0))


func _steer(want: Vector3) -> void:
	var b: Basis = p.get_node("SpringArm3D").global_transform.basis
	var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
	var rgt := Vector3(b.x.x, 0, b.x.z).normalized()
	var ix := rgt.dot(want)
	var iy := -fwd.dot(want)
	_release()
	if ix > 0:
		Input.action_press("move_right", ix)
	else:
		Input.action_press("move_left", -ix)
	if iy > 0:
		Input.action_press("move_back", iy)
	else:
		Input.action_press("move_forward", -iy)


func _release() -> void:
	for a in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	_release()
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
