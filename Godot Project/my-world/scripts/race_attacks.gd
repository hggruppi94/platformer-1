extends Node

# Races' "Attacks" node (scripts/races.gd makes it): everything in a race that knocks racers about. Hayden's day 1
# playtest (11 Nov 2026): "more obstacles, more racers, and more powerups that attack/defend with racers that attack
# you". Three power-ups to throw (from the Star Boxes, Races.POWERS):
#   Goo Bomb       a puddle of goo dropped behind you: whoever rides through it is slowed
#   Bubble Seeker  a big bubble that chases the racer just ahead and knocks them over
#   Zap Ring       a ring of static round you: everyone close by is knocked over
# A Bubble Shield stops any one of them (and pops). The friends pick power-ups up from the boxes too, and use them, on
# each other and on you, though never on you too often (ASSIST_WAIT: how long after one gets you before another may
# aim at you, by Settings > Assist). The obstacles on a circuit (scripts/race_track.gd) are worked out here as well:
# bumpers bounce you off, sweepers and zappers knock you over, ramps throw you in the air. The friends steer round
# bumpers, goo and zappers they can see coming, and get knocked about by the rest like anyone.
#
# Knocked over, the player has a comedy wipeout (Races.knock_player(), the skating's bail()); a friend spins round
# and slows right down for a moment (RaceRival.hit()).

const SEEKER_SPEED := 21.0           # metres a second (the fastest board, boosted, is about 17)
const SEEKER_LIFE := 7.0
const SEEKER_REACH := 1.5
const ZAP_RADIUS := 7.0
const DROP_LIFE := 20.0
const DROP_RADIUS := 2.1
const HIT_TIME := 1.6                # a friend's spin-out
const SLOW_TIME := 1.4               # ...and their slow going in goo
const ASSIST_WAIT := [18.0, 11.0, 7.0]       # seconds between the friends' attacks on the player: Relaxed, Normal, Pro
const RIVAL_POWERS := {"zoom": 2, "shield": 2, "goo": 3, "seeker": 3, "zap": 2}
const LOOK_AHEAD := 16.0             # metres ahead the friends look for things to steer round
const BUMP_OUT := 5.0                # how hard a bumper throws you back out (m/s)

var seekers: Array = []              # {node, by, target, life}
var drops: Array = []                # {node, by, life, safe}: Goo Bombs on the track
var _aim_wait := 4.0                 # until a friend may aim at the player
var _bump_wait := 0.0
var _ramp_wait := 0.0
var _hit_wait := {}                  # obstacle -> seconds before it can knock the player again
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func clear() -> void:
	for s in seekers:
		if is_instance_valid(s.node):
			s.node.queue_free()
	for d in drops:
		if is_instance_valid(d.node):
			d.node.queue_free()
	seekers.clear()
	drops.clear()
	_hit_wait.clear()
	_aim_wait = 4.0


# -----------------------------------------------------------------------------
# Who's racing, and where
# -----------------------------------------------------------------------------
func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func racers() -> Array:
	var out: Array = []
	for r in Races.rivals:
		if is_instance_valid(r):
			out.append(r)
	var p := _player()
	if p:
		out.append(p)
	return out


func progress_of(n: Node) -> float:
	return Races.progress if n is Player else float((n as RaceRival).d)


func name_of(n: Node) -> String:
	return "you" if n is Player else (n as RaceRival).display_name()


func ahead_of(user: Node, reach := 80.0) -> Node:
	# The racer just in front (the closest one ahead within reach), or null
	var mine := progress_of(user)
	var best: Node = null
	var gap := reach
	for r in racers():
		if r == user:
			continue
		var g := progress_of(r) - mine
		if g > 0.0 and g < gap:
			gap = g
			best = r
	return best


# -----------------------------------------------------------------------------
# Throwing things
# -----------------------------------------------------------------------------
func fire(user: Node, kind: String) -> void:
	var t := Races.track
	if t == null:
		return
	match kind:
		"goo":
			_drop_goo(user)
		"seeker":
			_seeker(user, ahead_of(user))
		"zap":
			_zap(user)
	if user is RaceRival and kind != "goo":
		user.say(Races.POWERS[kind].say)


func _lane_of(user: Node) -> Array:
	# [how far round, metres to the right of the line]
	var t := Races.track
	var d := progress_of(user)
	var pos := (user as Node3D).global_position
	return [d, clampf((pos - t.point_at(d)).dot(t.side_at(d)), -t.width / 2.0 + 1.5 if t.width > 0.0 else -3.0,
		t.width / 2.0 - 1.5 if t.width > 0.0 else 3.0)]


func _drop_goo(user: Node) -> void:
	var at := _lane_of(user)
	var node := Races.track.drop_goo(float(at[0]) - 3.0, float(at[1]))
	drops.append({"node": node, "by": user, "life": DROP_LIFE, "safe": 1.0})
	Audio.play("stomp", -6.0)


func _seeker(user: Node, target: Node) -> void:
	var b := MeshInstance3D.new()
	b.name = "Bubble Seeker"
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	b.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.85, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.85)
	m.emission_energy_multiplier = 1.2
	m.rim_enabled = true
	b.material_override = m
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(b)
	b.global_position = (user as Node3D).global_position + Vector3.UP * 1.2 + _forward_of(user) * 1.5
	seekers.append({"node": b, "by": user, "target": target, "life": SEEKER_LIFE, "d": progress_of(user)})
	Audio.play("bubbles", -4.0)
	if target is Player:
		Races.hud.warn("A Bubble Seeker's after you!")


func _forward_of(user: Node) -> Vector3:
	return Races.track.dir_at(progress_of(user))


func _zap(user: Node) -> void:
	var at := (user as Node3D).global_position
	var ring := MeshInstance3D.new()
	ring.name = "Zap Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.45, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	get_tree().current_scene.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.6
	var tw := ring.create_tween()
	tw.set_parallel()
	tw.tween_property(ring, "scale", Vector3(ZAP_RADIUS, 1.0, ZAP_RADIUS), 0.35)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(ring.queue_free)
	Audio.play("level_up", -6.0, 0.2)
	Juice.shake(0.12)
	for r in racers():
		if r != user and (r as Node3D).global_position.distance_to(at) < ZAP_RADIUS:
			hit(r, "Zapped!", user)


func hit(target: Node, why: String, by: Node = null) -> void:
	if target is Player:
		if Races.knock_player(why) and by is RaceRival:
			_aim_wait = _assist_wait()
	elif target is RaceRival:
		if (target as RaceRival).hit(HIT_TIME) and by is Player:
			Races.hud.warn("Got %s!" % (target as RaceRival).display_name())


func _assist_wait() -> float:
	return float(ASSIST_WAIT[clampi(Settings.skate_assist, 0, ASSIST_WAIT.size() - 1)])


# -----------------------------------------------------------------------------
# Every frame of a race
# -----------------------------------------------------------------------------
func tick(delta: float, results := false) -> void:
	var t := Races.track
	if t == null or not is_instance_valid(t):
		return
	_aim_wait -= delta
	_bump_wait -= delta
	_ramp_wait -= delta
	for o in _hit_wait.keys():
		_hit_wait[o] = float(_hit_wait[o]) - delta
	_tick_seekers(delta)
	_tick_drops(delta)
	_tick_obstacles(t)
	if not results:
		for r in Races.rivals:
			if is_instance_valid(r):
				_rival_think(r, delta)
				_rival_steer(r, t)


func _tick_seekers(delta: float) -> void:
	for s in seekers.duplicate():
		var node := s.node as Node3D
		s.life = float(s.life) - delta
		var target = s.target
		if not is_instance_valid(node) or s.life <= 0.0 or (target != null and not is_instance_valid(target)):
			_pop_seeker(s)
			continue
		var t := Races.track
		var want: Vector3
		if target == null:
			# Nobody ahead: off along the track and pop
			s.d = float(s.d) + SEEKER_SPEED * delta
			want = t.point_at(float(s.d)) + Vector3.UP * 1.2
		else:
			want = (target as Node3D).global_position + Vector3.UP * 0.9
			# Round the bends: aim along the line until it's close
			var gap := progress_of(target) - float(s.d)
			if gap > 10.0:
				s.d = float(s.d) + SEEKER_SPEED * delta
				want = t.point_at(float(s.d)) + Vector3.UP * 1.2
			else:
				s.d = progress_of(target)
		var to := want - node.global_position
		var step := SEEKER_SPEED * delta
		node.global_position += to.normalized() * minf(step, to.length()) if to.length() > 0.01 else Vector3.ZERO
		node.scale = Vector3.ONE * (1.0 + sin(float(s.life) * 14.0) * 0.08)
		if target != null and node.global_position.distance_to((target as Node3D).global_position + Vector3.UP * 0.9) < SEEKER_REACH:
			hit(target, "Bubbled!", s.by)
			_pop_seeker(s)


func _pop_seeker(s: Dictionary) -> void:
	seekers.erase(s)
	if is_instance_valid(s.node):
		Juice.burst(get_tree().current_scene, (s.node as Node3D).global_position, Color(0.75, 0.9, 1.0), 10, 0.06, 2.5, 0.4)
		(s.node as Node).queue_free()
	Audio.play("bubbles", -8.0, 0.2)


func _tick_drops(delta: float) -> void:
	var p := _player() as Player
	for d in drops.duplicate():
		d.life = float(d.life) - delta
		d.safe = float(d.safe) - delta
		var node := d.node as Node3D
		if not is_instance_valid(node) or d.life <= 0.0:
			drops.erase(d)
			if is_instance_valid(node):
				var tw := node.create_tween()
				tw.tween_property(node, "scale", Vector3.ONE * 0.05, 0.4)
				tw.tween_callback(node.queue_free)
			continue
		for r in Races.rivals:
			if is_instance_valid(r) and not (r == d.by and d.safe > 0.0) and _near(r.global_position, node.global_position, DROP_RADIUS):
				r.slow_down(SLOW_TIME)
		if p and not (p == d.by and d.safe > 0.0) and _near(p.global_position, node.global_position, DROP_RADIUS):
			Races.goo_hit(p)


func _near(a: Vector3, b: Vector3, r: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < r and absf(a.y - b.y) < 2.0


func _local(o: Node3D, pos: Vector3) -> Vector3:
	return o.global_transform.affine_inverse() * pos


func _tick_obstacles(t: RaceTrack) -> void:
	var p := _player() as Player
	for o in t.obstacles:
		var kind := str(o.get_meta("kind"))
		for r in racers():
			var pos := (r as Node3D).global_position
			if r is Player:
				pos.y -= 0.8                                  # (the player's middle; obstacles are measured from her feet)
			var l := _local(o, pos)
			if absf(l.y) > 3.0:
				continue
			match kind:
				"bumper":
					var rad := float(o.get_meta("radius")) + 0.4
					if Vector2(l.x, l.z).length() < rad:
						_bump(r, o)
				"sweeper":
					if _swept(o, l, t) and float(_hit_wait.get([o, r], 0.0)) <= 0.0:
						_hit_wait[[o, r]] = 1.2
						hit(r, "Swept!" if not t.earth else "Whoops, windmill!")
				"zapper":
					if t.zap_on(o) and absf(l.z) < 0.7 and absf(l.x) < float(o.get_meta("half")) + 0.3 \
							and float(_hit_wait.get([o, r], 0.0)) <= 0.0:
						_hit_wait[[o, r]] = 1.2
						hit(r, "Zapped!" if not t.earth else "Splash!")
				"ramp":
					if l.z > -0.6 and l.z < 1.6 and absf(l.x) < float(o.get_meta("half")):
						_ramp(r, o)


func _swept(o: Node3D, l: Vector3, t: RaceTrack) -> bool:
	var a := t.arm_angle(o)
	var u := Vector2(cos(a), -sin(a))
	var q := Vector2(l.x, l.z)
	var reach := float(o.get_meta("arm"))
	var along := clampf(q.dot(u), -reach, reach)
	return q.distance_to(u * along) < 0.75 and q.length() > 0.6


func _bump(r: Node, o: Node3D) -> void:
	var out := (r as Node3D).global_position - o.global_position
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else -Races.track.dir_at(float(o.get_meta("d")))
	if r is Player:
		if _bump_wait > 0.0:
			return
		_bump_wait = 0.4
		var p := r as Player
		var v := p.velocity
		var into := v.dot(out)
		if into < 0.0:
			v -= out * into * 1.6                     # bounce off it, keeping the speed along it
		v += out * BUMP_OUT
		p.velocity = v
		p.global_position += out * 0.3
		Races.track.squash(o)
		var skate = p.get("skate")
		skate.hud.shout("Boing!", Color(1.0, 0.6, 0.85))
		Audio.play("boing", -4.0, 0.1)
		Juice.rumble(0.25, 0.1)
	else:
		var rival := r as RaceRival
		if rival.bumped(out):
			Races.track.squash(o)


func _ramp(r: Node, o: Node3D) -> void:
	if r is Player:
		if _ramp_wait > 0.0:
			return
		var skate = (r as Player).get("skate")
		if not bool(skate.call("is_on_ground")):
			return
		_ramp_wait = 1.0
		skate.call("spring", Races.RAMP_POP)
		skate.call("boost", 2.0, 0.6)
		skate.hud.shout("Air!", Color(0.75, 0.9, 1.0))
	else:
		(r as RaceRival).hop()


# -----------------------------------------------------------------------------
# The friends: picking power-ups up, using them, and steering round trouble
# -----------------------------------------------------------------------------
func _rival_think(r: RaceRival, delta: float) -> void:
	var t := Races.track
	var L := t.length
	var now := fposmod(r.d, L)
	var before := fposmod(r.d - r.speed * delta - 0.01, L)
	if r.item == "" and r.d > 0.0:
		for b in t.boxes:
			var bd := float(b.get_meta("d"))
			if (before <= bd and bd < now) or (before > now and (bd >= before or bd < now)):
				r.item = _roll_rival()
				r.item_wait = _rng.randf_range(0.8, 2.6)
				r.item_held = 0.0
				break
		return
	if r.item == "":
		return
	r.item_wait -= delta
	r.item_held += delta
	if r.item_wait > 0.0 or r.stunned():
		return
	var p := _player()
	match r.item:
		"zoom":
			r.boost(Races.ZOOM_TIME)
			r.say("Zoom!")
			r.item = ""
		"shield":
			r.shield_up(Races.SHIELD_TIME)
			r.item = ""
		"goo":
			var behind := racers().any(func(o: Node) -> bool: return o != r and progress_of(o) < r.d and r.d - progress_of(o) < 30.0 \
				and (not o is Player or _aim_wait <= 0.0))
			if behind or r.item_held > 7.0:
				fire(r, "goo")
				r.item = ""
				if behind and p and progress_of(p) < r.d and r.d - progress_of(p) < 30.0:
					_aim_wait = _assist_wait() * 0.5
		"seeker":
			var target := ahead_of(r, 70.0)
			if target is Player and _aim_wait > 0.0:
				if r.item_held > 9.0:
					r.item = "zoom"                       # (fed up waiting: uses it to catch up instead)
				return
			if target != null or r.item_held > 9.0:
				_seeker(r, target)
				r.say("Bubble away!")
				r.item = ""
				if target is Player:
					_aim_wait = _assist_wait()
		"zap":
			var close := racers().filter(func(o: Node) -> bool: return o != r and (o as Node3D).global_position.distance_to(r.global_position) < ZAP_RADIUS - 0.5)
			var at_player := close.any(func(o: Node) -> bool: return o is Player)
			if (close.size() > 0 and (not at_player or _aim_wait <= 0.0)) or r.item_held > 9.0:
				fire(r, "zap")
				r.item = ""
				if at_player:
					_aim_wait = _assist_wait()


func _roll_rival() -> String:
	var total := 0
	for k in RIVAL_POWERS:
		total += int(RIVAL_POWERS[k])
	var roll := _rng.randi() % total
	for k in RIVAL_POWERS:
		roll -= int(RIVAL_POWERS[k])
		if roll < 0:
			return k
	return "zoom"


func _rival_steer(r: RaceRival, t: RaceTrack) -> void:
	# Look a little way ahead for a bumper, a goo puddle or a zapper that's on (or about to be) in their lane, and
	# pick a lane clear of them
	var hw := (t.width / 2.0 - 1.2) if t.width > 0.0 else 2.4
	var blocked: Array = []                         # [from, to] metres to the right
	var L := t.length
	var here := fposmod(r.d, L)
	var check := func(d: float, side: float, half: float) -> void:
		var ahead := fposmod(d - here, L)
		if ahead > 0.5 and ahead < LOOK_AHEAD:
			blocked.append([side - half, side + half])
	for o in t.obstacles:
		match str(o.get_meta("kind")):
			"bumper":
				check.call(float(o.get_meta("d")), float(o.get_meta("side")), 2.0)
			"zapper":
				if t.zap_on(o) or t.zap_warning(o):
					check.call(float(o.get_meta("d")), float(o.get_meta("side")), float(o.get_meta("half")) + 0.8)
	for g in t.goo:
		check.call(float(g.get_meta("d")), (g.global_position - t.point_at(float(g.get_meta("d")))).dot(t.side_at(float(g.get_meta("d")))), 2.4)
	for d in drops:
		if is_instance_valid(d.node) and d.by != r:
			var gd := t.nearest(d.node.global_position, here, 30.0)
			check.call(gd, (d.node.global_position - t.point_at(gd)).dot(t.side_at(gd)), 2.4)
	var goal := r.lane_goal
	if not _free(goal, blocked):
		var best := goal
		var best_gap := INF
		for k in 25:
			var lane := -hw + (2.0 * hw) * k / 24.0
			if _free(lane, blocked) and absf(lane - r.lane) < best_gap:
				best_gap = absf(lane - r.lane)
				best = lane
		r.lane_goal = best


func _free(lane: float, blocked: Array) -> bool:
	for b in blocked:
		if lane > float(b[0]) and lane < float(b[1]):
			return false
	return true
