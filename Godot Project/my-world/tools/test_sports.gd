extends SceneTree

# Checks the sports corner's games (scripts/sports.gd): a host stands by each court on the ground, clear of anything
# solid, and talks in short lines; each game starts with a countdown that holds you still; Hoop Shoot scores 2 and 3, x2
# in the air on your ride and x3 mid-trick, a miss scores nothing, off the court or too far shoots nothing, and the ball
# always comes back; Goal Kicks: a kick at Bonk is saved, one by the post goes in, Interact kicks (and starts no talk),
# five kicks and it's over; Tennis Rally: standing in the ring hits it back by itself, standing away misses, three
# misses and it's over; Rock Wall Race: the ledges are where the way stars are and you can stand on them, ringing the
# bell gives a time; Sky Sweep (the broom sport): flying, grabbing, carrying and throwing the Sparkball through a hoop,
# Zip and Zap swiping it and scoring, the Glimmer Moth, landing; medals pay once, gold in all four wins the Champion
# Sweatband, best scores save and load, and going somewhere else ends a game with no harm done.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_sports.gd
#
# Your own save and settings are put aside (under names of their own) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.sports_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.sports_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"

var failures := 0
var game: Node
var sports: Node
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


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	sports = root.get_node("Sports")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	if not game.has_item("skateboard"):
		game.items.append("skateboard")
	var start_sparkles := int(game.sparkles)

	change_scene_to_file(TOWN)
	await _frames(12)
	await _physics(6)
	p = current_scene.find_child("Player", true, false) as CharacterBody3D
	var space := (current_scene as Node3D).get_world_3d().direct_space_state

	# The hosts
	check(sports.hosts.size() == 5, "five hosts in the Void (%d)" % sports.hosts.size())
	for id in sports.GAMES:
		var h := sports.hosts.get(id) as Node3D
		check(h != null and h.get_node_or_null("Sports Talk") != null, "%s: %s stands by the %s with a spot to talk to" % [id,
			sports.GAMES[id].host, sports.GAMES[id].place])
		if h == null:
			continue
		var q := PhysicsRayQueryParameters3D.create(h.global_position + Vector3(0, 3, 0), h.global_position + Vector3(0, -3, 0))
		var body := h.find_children("*", "StaticBody3D", true, false)
		if not body.is_empty():
			q.exclude = [(body[0] as StaticBody3D).get_rid()]
		var hit := space.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y - h.global_position.y) < 0.45,
			"...on the ground (%.2f above it)" % (h.global_position.y - float(hit.get("position", Vector3.ZERO).y)))
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 1.4, 1.0)
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = box
		sq.transform = Transform3D(Basis(), h.global_position + Vector3(0, 1.0, 0))
		if not body.is_empty():
			sq.exclude = [(body[0] as StaticBody3D).get_rid()]
		var inside := space.intersect_shape(sq, 4)
		check(inside.is_empty(), "...and not inside anything solid (%s)" % str(inside.map(func(d) -> String: return str(d.collider.name))))
		var lines: Array = sports.lines(id)
		var words_ok := true
		for l in lines:
			if l is String and (l as String).split(" ").size() > 8:
				words_ok = false
		check(lines.size() <= 5 and words_ok, "...talks in a few short lines")
		check(lines.any(func(l) -> bool: return l is Dictionary and str(l).contains("sports_go_" + id)), "...and asks if you'd like to play")

	# ----------------------------------------------------------------------------- Hoop Shoot
	check(sports.start("hoops"), "Hoop Shoot starts")
	check(p.input_locked and sports.state == sports.State.COUNTDOWN, "...held still for the countdown")
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	check(sports.state == sports.State.PLAYING and not p.input_locked, "...then GO and you can move")
	var hoops: Node3D = sports.game
	check(sports.meter.visible, "...with the shooting meter up")
	var rim: Vector3 = hoops.to_global(hoops.RIMS[0])
	var d := Vector2(p.global_position.x - rim.x, p.global_position.z - rim.z).length()
	hoops.shoot(true)
	await _until(func() -> bool: return hoops.phase == "held", 4.0)
	check(hoops.score == (3 if d >= hoops.THREE else 2) and hoops.made == 1, "a good shot %.1f m out scores %d (%d)" % [d,
		3 if d >= hoops.THREE else 2, hoops.score])
	check(hoops.b.global_position.distance_to(hoops.hand()) < 0.5, "...and the ball comes back to you")
	var before: int = hoops.score
	hoops.shoot(false)
	await _until(func() -> bool: return hoops.phase == "held", 4.0)
	check(hoops.score == before and hoops.shots == 2, "a miss scores nothing, and the ball still comes back")
	p.global_position = hoops.to_global(Vector3(9.0, 0.6, 0.5))
	await _physics(2)
	hoops.shoot(true)
	await _until(func() -> bool: return hoops.phase == "held", 4.0)
	check(hoops.score == before + 2, "close in it's 2 (%d)" % (hoops.score - before))
	# On your ride: in the air x2, mid-trick x3
	game.riding = true
	game.equipment_changed.emit()
	await _physics(3)
	var s = p.get("skate")
	check(s != null, "...on your ride")
	if s:
		before = hoops.score
		s.state = 1                                   # (Skate.State.AIR)
		hoops.shoot(true)
		s.state = 0
		await _until(func() -> bool: return hoops.phase == "held", 4.0)
		check(hoops.last_mult == 2 and hoops.score == before + hoops.last_points and hoops.last_points % 2 == 0,
			"in the air on your ride it's x2 (+%d)" % (hoops.score - before))
		before = hoops.score
		s.state = 1                                   # (Skate.State.AIR)
		s.tricks.flip = {"name": "Kickflip", "style": "flip", "time": 0.0, "duration": 0.5, "points": 100}
		hoops.shoot(true)
		s.state = 0
		s.tricks.flip = {}
		await _until(func() -> bool: return hoops.phase == "held", 4.0)
		check(hoops.last_mult == 3 and hoops.score == before + hoops.last_points, "mid-trick it's x3 (+%d)" % (hoops.score - before))
	game.riding = false
	game.equipment_changed.emit()
	await _physics(3)
	var shots: int = hoops.shots
	p.global_position = hoops.to_global(Vector3(0.0, 0.6, 14.0))
	await _physics(2)
	hoops.action()
	check(hoops.shots == shots and hoops.phase == "held", "off the court, nothing's shot")
	p.global_position = hoops.to_global(Vector3(2.0, 0.6, 0.0))
	await _physics(2)
	hoops.meter = hoops.CENTRE
	hoops.action()
	check(hoops.shots == shots + 1 and hoops.phase == "shot", "Interact with the needle in the green shoots")
	await _until(func() -> bool: return hoops.phase == "held", 4.0)
	var hoop_score: int = hoops.score
	var sp := int(game.sparkles)
	hoops.left = 0.05
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 2.0)
	check(sports.state == sports.State.RESULTS and int(sports.best.get("hoops", -1)) == hoop_score, "TIME! and the score's your best (%d)" % hoop_score)
	var hoop_medals := int(sports.medals.get("hoops", 0))
	check(hoop_medals == (2 if hoop_score >= 18 else (1 if hoop_score >= 8 else 0)), "...with the medals it reached (%d)" % hoop_medals)
	check(int(game.sparkles) - sp == [0, 3, 8, 16][hoop_medals], "...paid once (✦ %d)" % (int(game.sparkles) - sp))
	check(not sports.meter.visible, "...and the meter's put away")
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)
	check(not is_instance_valid(hoops) or hoops.is_queued_for_deletion() or hoops.get_parent() == null, "then the game's cleared away")
	check((sports.hosts.hoops as Node3D).position.is_equal_approx(sports.GAMES.hoops.at), "...and Coach Swish is back by the path")

	# ----------------------------------------------------------------------------- Goal Kicks
	check(sports.start("goals"), "Goal Kicks starts")
	var goals: Node3D = sports.game
	goals.guess_wrong = 0.0
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	check(sports.state == sports.State.PLAYING and p.input_locked, "...and you stay on the spot for the kicks")
	var bonk := sports.hosts.goals as Node3D
	check(goals.to_local(bonk.global_position).distance_to(Vector3(goals.GOALIE_X, 0.25, 0)) < 0.6, "Bonk's in goal")
	goals.kick_at(0.0)
	await _until(func() -> bool: return goals.phase == "aim" or sports.state != sports.State.PLAYING, 4.0)
	check(goals.goals == 0 and goals.last == "saved", "a kick straight at Bonk is saved")
	goals.kick_at(goals.POSTS)
	await _physics(20)
	var moved := absf(goals.to_local(bonk.global_position).z)
	await _until(func() -> bool: return goals.phase == "aim" or sports.state != sports.State.PLAYING, 4.0)
	check(goals.goals == 1 and goals.last == "goal", "one by the post goes in")
	check(moved > 0.3, "...though Bonk dives after it (%.1f m)" % moved)
	# Interact kicks, and doesn't start a talk with anyone
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _physics(2)
	var ev2 := InputEventAction.new()
	ev2.action = "interact"
	ev2.pressed = false
	Input.parse_input_event(ev2)
	check(goals.kick == 3 and not root.get_node("Dialogue").is_active(), "Interact kicks (kick %d), and starts no talk" % goals.kick)
	await _until(func() -> bool: return goals.phase == "aim" or sports.state != sports.State.PLAYING, 4.0)
	var g_before: int = goals.goals
	goals.kick_at(-goals.POSTS)
	await _until(func() -> bool: return goals.phase == "aim" or sports.state != sports.State.PLAYING, 4.0)
	goals.kick_at(goals.POSTS)
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 4.0)
	check(goals.kick == 5 and sports.state == sports.State.RESULTS, "five kicks and it's FULL TIME")
	check(int(sports.best.get("goals", -1)) == g_before + 2, "...%d goals" % int(sports.best.get("goals", -1)))
	check(not p.input_locked, "...and you can move again")
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)

	# ----------------------------------------------------------------------------- Tennis Rally
	check(sports.start("tennis"), "Tennis Rally starts")
	var tennis: Node3D = sports.game
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	var hits_seen := 0
	for k in 3:                                       # stand in the ring each time
		await _until(func() -> bool: return tennis.phase == "to_you", 5.0)
		check(tennis.marker.visible, "a ring shows where Volley's ball will bounce")
		p.global_position = tennis.to_global(tennis.landing) + Vector3(0, 0.4, 0)
		p.velocity = Vector3.ZERO
		await _until(func() -> bool: return tennis.phase == "to_them" or tennis.phase == "wait", 5.0)
		hits_seen = tennis.hits
	check(hits_seen == 3, "standing in the ring hits it back by itself, three times (%d)" % hits_seen)
	var volley := sports.hosts.tennis as Node3D
	check(tennis.to_local(volley.global_position).x < -2.0, "...and Volley's on the other side of the net")
	for k in 3:                                       # then stand well away
		await _until(func() -> bool: return tennis.phase == "to_you", 6.0)
		var far: Vector3 = tennis.landing + Vector3(0, 0.4, 0)
		far.z = -5.0 if tennis.landing.z > 0.0 else 5.0
		far.x = 11.5
		p.global_position = tennis.to_global(far)
		await _until(func() -> bool: return tennis.phase != "to_you" and tennis.phase != "after", 6.0)
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 3.0)
	check(tennis.balls == 0 and sports.state == sports.State.RESULTS, "three misses and it's GAME")
	check(int(sports.best.get("tennis", -1)) == 3, "...3 hits")
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)

	# ----------------------------------------------------------------------------- Rock Wall Race
	var wall: Node3D = sports.place_of("climb")
	var all_solid := true
	for l: Vector3 in load("res://scripts/sport_climb.gd").LEDGES:
		var top: Vector3 = wall.to_global(l + Vector3(0, 1.0, 0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -1.2, 0)))
		if hit.is_empty() or absf(hit.position.y - wall.to_global(l).y - 0.175) > 0.2:
			all_solid = false
	check(all_solid, "every way star's over a ledge you can stand on")
	sports.medals["hoops"] = 3                         # (gold in the other three, to see the hat)
	sports.medals["goals"] = 3
	sports.medals["tennis"] = 3
	check(sports.start("climb"), "Rock Wall Race starts")
	var climb: Node3D = sports.game
	check(climb.to_local(p.global_position).distance_to(Vector3(0, 0.6, 3.4)) < 1.0, "...from the crash mat")
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	await _physics(30)
	sp = int(game.sparkles)
	p.global_position = climb.bell.global_position + Vector3(0.0, 0.5, 1.0)
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 2.0)
	check(climb.rung and float(sports.best.get("climb", -1.0)) > 0.0 and float(sports.best.climb) < 2.0,
		"reaching the bell rings it: DING, %.1f s" % float(sports.best.get("climb", -1.0)))
	check(int(sports.medals.get("climb", 0)) == 3 and int(game.sparkles) - sp == 16, "...gold, with every medal paid (✦ %d)" % (int(game.sparkles) - sp))
	check(game.has_item("shop:champion_sweatband"), "gold in all four wins the Champion Sweatband")
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)
	# A slower time doesn't take your best
	sports.start("climb")
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	sports.game.clock = 30.0
	p.global_position = sports.game.bell.global_position + Vector3(0.0, 0.5, 1.0)
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 2.0)
	check(float(sports.best.climb) < 2.0 and int(sports.medals.climb) == 3, "a slower climb keeps your best and your medals")
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)

	# ----------------------------------------------------------------------------- Sky Sweep (the broom sport)
	check(sports.start("broom"), "Sky Sweep starts")
	var sw: Node3D = sports.game
	var field: Node3D = sports.place_of("broom")
	check(p.get("carried") == true and p.global_position.y - field.global_position.y > 4.0,
		"...up in the air on a broom (%.1f m up)" % (p.global_position.y - field.global_position.y))
	check(p.get_node_or_null("Visual/Broom") != null and p.find_children("Broom Seat", "", true, false).size() == 1,
		"...with the broom under her and her legs astride it")
	check(sw._hoop_nodes.size() == 6 and sw._hoop_nodes.all(func(h) -> bool: return h.get_parent() == sw) and sw.rivals.size() == 2, "...six gold hoops, Zip and Zap")
	check(sw.ball_node.position.is_equal_approx(sw.CENTRE) and sw.holder == null, "...and the Sparkball waiting in the middle")
	await _physics(int(sports.COUNTDOWN * 60) + 4)
	check(sports.state == sports.State.PLAYING, "...GO")
	sw.rivals_on = false
	var y0: float = p.global_position.y
	for i in 30:
		sw.steer(Vector3(0, sw.CLIMB, 0), 1.0 / 60.0)
	check(p.global_position.y > y0 + 1.0, "holding Jump flies you up (%.1f m)" % (p.global_position.y - y0))
	for i in 240:
		sw.steer(field.global_basis.z * sw.SPEED, 1.0 / 60.0)
	check(absf(sw.to_local(p.global_position).z - sw.BOX_MAX.z) < 0.2, "...and you can't fly off the pitch")
	sw.put_hero(sw.ball_node.position)
	await _physics(2)
	check(sw.holder == p, "flying into the Sparkball grabs it")
	var h1: Vector3 = sw.HOOPS[1]
	sw.put_hero(Vector3(sw.END_X - 0.6, h1.y, h1.z))
	await _physics(1)
	p.global_position = sw.to_global(Vector3(sw.END_X + 0.6, h1.y, h1.z)) - Vector3.UP * 0.7
	await _physics(2)
	check(sw.you == 1 and sw.last == "you", "carrying it through a gold hoop is a GOAL (%d)" % sw.you)
	check(sw.holder == null and sw.ball_node.position.is_equal_approx(sw.CENTRE), "...and the Sparkball's back in the middle")
	await _physics(80)
	# Throwing at a hoop near enough goes in; throwing away from them doesn't
	sw.put_hero(sw.ball_node.position)
	await _physics(2)
	var to_far: Vector3 = field.global_basis.x
	sw.put_hero(Vector3(sw.END_X - 9.0, h1.y, h1.z))
	(p.get_node("Visual") as Node3D).rotation.y = atan2(to_far.x, to_far.z)
	await _physics(1)
	sw.action()
	await _physics(60)
	check(sw.you == 2, "a throw at a hoop in front of you goes in (%d)" % sw.you)
	await _physics(80)
	sw.put_hero(sw.ball_node.position)
	await _physics(2)
	(p.get_node("Visual") as Node3D).rotation.y = atan2(-to_far.x, -to_far.z)
	await _physics(1)
	sw.action()
	await _physics(60)
	check(sw.you == 2 and sw.holder == null, "...a throw away from the hoops just floats loose")
	# Zip swipes it, and you can take it back; and they score at your end
	sw.put_hero(sw.ball_node.position)
	await _physics(2)
	sw._grace = 0.0
	sw.rivals[0].position = sw.to_local(p.global_position + Vector3.UP * 0.7)
	await _physics(2)
	check(sw.holder == sw.rivals[0] and sw.last == "swiped", "Zip flying into you swipes it")
	sw._grace = 0.0
	sw.put_hero(sw.rivals[0].position + Vector3.UP * 0.5)
	await _physics(2)
	check(sw.holder == p and sw.last == "took", "...and flying into Zip takes it back")
	sw.put_hero(Vector3(0, 12, -12))
	sw.holder = sw.rivals[1]
	sw.rivals[1].position = Vector3(-sw.END_X + 0.5, h1.y - 0.9, h1.z)
	sw._ball_prev = sw.rivals[1].position + Vector3(0, 0.9, 0)
	sw.rivals[1].position.x = -sw.END_X - 0.5
	await _physics(2)
	check(sw.them == 1 and sw.last == "them", "Zap flying it through a hoop at your end scores for them (%d)" % sw.them)
	await _physics(80)
	sw.rivals_on = true
	await _physics(120)
	check(sw.rivals.all(func(r) -> bool: return r.position.distance_to(sw.CENTRE) < 9.0 or sw.holder == r),
		"Zip and Zap go after a loose Sparkball")
	# The Glimmer Moth
	check(sw.moth == null, "no Glimmer Moth yet")
	sw.time = sw.TIME - sw.MOTH_AT + 0.05
	await _physics(2)
	check(sw.moth != null and is_instance_valid(sw.moth), "with half a minute left the Glimmer Moth comes out")
	var at_moth: Vector3 = sw.moth.position
	sw.put_hero(at_moth)
	await _until(func() -> bool: return sports.state == sports.State.RESULTS, 2.0)
	check(sw.moth_caught and sw.you == 5, "catching it is 3 goals and the match is over (%d)" % sw.you)
	check(p.get("carried") == false and p.get_node_or_null("Visual/Broom") == null and not p.input_locked,
		"...and you land back on the ground, off the broom")
	var hit_g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP, p.global_position + Vector3.DOWN * 2.0))
	check(not hit_g.is_empty() and absf(hit_g.position.y - p.global_position.y) < 0.8, "...by the field, on the ground")
	check(int(sports.medals.get("broom", 0)) == 2 and float(sports.best.broom) == 5.0, "5 goals is silver (%d)" % int(sports.medals.get("broom", 0)))
	await _until(func() -> bool: return sports.state == sports.State.IDLE, sports.RESULTS_TIME + 1.0)
	# Stopping halfway lands you too
	sports.start("broom")
	await _physics(int(sports.COUNTDOWN * 60) + 20)
	sports._end()
	await _physics(2)
	check(p.get("carried") == false and p.get_node_or_null("Visual/Broom") == null and p.find_children("Broom Seat", "", true, false).is_empty(),
		"ending it halfway puts you back on your feet")

	# Saved and loaded
	var data: Dictionary = sports.save_data()
	sports.reset()
	check(sports.best.is_empty() and sports.medals.is_empty(), "a new game has no scores")
	sports.load_data(JSON.parse_string(JSON.stringify(data)))
	check(int(sports.best.tennis) == 3 and int(sports.medals.climb) == 3, "scores and medals load back")
	check(str((sports.hosts.tennis.get_node("Best") as Label3D).text).contains("3"), "Volley shows your best")

	# Going somewhere else ends a game
	sports.start("tennis")
	await _physics(10)
	change_scene_to_file(EARTH)
	await _frames(10)
	check(not sports.running() and sports.hosts.is_empty() and not sports.hud.lap_label.text, "going to Earth ends the game, no hosts there")
	check(int(game.sparkles) >= start_sparkles, "(sparkles only ever went up)")
	_finish()


func _until(cond: Callable, seconds: float) -> void:
	var n := int(seconds * 60.0)
	for i in n:
		if cond.call():
			return
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	sports.reset()
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
