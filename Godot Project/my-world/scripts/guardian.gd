extends CharacterBody3D

# The guardians: big optional bosses that sleep at three of the Void's hidden places (scripts/hidden_places.gd), part
# of the "feels bigger" plan's learnable bosses (Hayden, 15 Nov 2026: "Yes to both"). Nothing shows before the place
# is found (no spoilers); once it is, its guardian curls up beside it, and coming close wakes it. Walking away (more
# than LEASH metres from its spot) any time calms it back to sleep, with no harm done, so it's never in the way.
#
#   Glimmerwing     at the Star Well: a great star moth. Rains a falling star on you (a shadow grows: move off it),
#                   then swoops low along the ground (arrows: step aside).
#   Old Bubblebeard at Bubble Spring: a huge mossy toad with a beard of bubbles. Belly-flops (a ring: jump it), then
#                   gulps the air in (arrows pointing in: jump free).
#   Ribbontail      on Kite Hill: a paper kite dragon with a long ribbon tail. Swoops (arrows), then flaps down a
#                   gust (a ring: jump it).
#
# Every move is warned with the shared boss tells (scripts/boss_tell.gd), always the same shape for the same thing.
# After each move it's puffed out for a moment: then bubbles, stomps and rolls count, up to MAX_PER_DAZE a time.
# HITS and it's calmed: it shrinks to a happy little self, gives sparkles, Remnants and a hat once (flag
# guardian_<id>) and isn't seen again. Kid-safe: a bump, never more.
#
# No class_name (tools run with --script compile class_name scripts before the autoloads exist): preload it.
#   GUARDIAN.place(scene, holder)       every found guardian's place in this scene (Hidden._place_all)
#   GUARDIAN.wake_for(id)               a place was just found: its guardian curls up there (Hidden.find)

const TELL := preload("res://scripts/boss_tell.gd")

const KINDS := {
	"star_well": {"name": "Glimmerwing", "hat": "glimmer_antennae", "colour": Color(0.55, 0.62, 1.0),
		"moves": ["drop", "dash"], "height": 3.4, "floats": 1.6, "spot": Vector2(-116, -230)},
	"bubble_spring": {"name": "Old Bubblebeard", "hat": "lily_pad_hat", "colour": Color(0.45, 0.85, 0.7),
		"moves": ["jump", "pull"], "height": 3.0, "floats": 0.0, "spot": Vector2(-132, -86)},
	"kite_hill": {"name": "Ribbontail", "hat": "kite_hat", "colour": Color(1.0, 0.45, 0.4),
		"moves": ["dash", "jump"], "height": 3.2, "floats": 2.2, "spot": Vector2(130, 81)},
}
const OUT := 11.0                     # metres from the place's middle, towards the town, where it sleeps
const WAKE := 12.0
const LEASH := 30.0
const ROAM := 13.0                    # it keeps within this of its spot
const HITS := 9
const MAX_PER_DAZE := 3
const SPARKLES := 15
const REMNANTS := 2
const IDLE_TIME := 1.6
const DAZE_TIME := 3.0
const SWOOP_LEN := 16.0
const SWOOP_SPEED := 16.0
const RING_REACH := 9.0
const DROP_R := 2.6
const PULL_REACH := 10.0
const PULL_TIME := 1.6
const PULL_SPEED := 3.6

enum State { SLEEP, IDLE, WARN, ACT, DAZED, CALMED }

var id := ""
var title := ""
var colour := Color.WHITE
var moves: Array = []
var height := 3.0
var floats := 0.0
var home := Vector3.ZERO
var state := State.SLEEP
var hits := 0
var defeated := false
var visual: Node3D
var player: CharacterBody3D
var _t := 0.0
var _state_t := 0.0
var _move_i := 0
var _move := ""
var _daze_hits := 0
var _dir := Vector3.FORWARD
var _target := Vector3.ZERO
var _bar: BossBar
var _hitbox: Area3D
var _told := 0.0
var _parts := {}                      # bits that move: wings, tail, throat


static func flag(place: String) -> String:
	return "guardian_" + place


static func beaten(place: String) -> bool:
	return bool(Dialogue.flags.get(flag(place), false))


static func spot_for(place: Dictionary) -> Vector2:
	# Each guardian has its own spot, picked by hand on open, flat ground with no trees or courts round it; a place
	# without one falls back to OUT metres towards the town.
	if KINDS.has(place.id) and KINDS[place.id].has("spot"):
		return KINDS[place.id].spot
	var at: Vector2 = place.at
	return at + (Vector2.ZERO - at).normalized() * OUT


static func place(scene: Node3D, holder: Node3D) -> void:
	for p in Hidden.places_in("void"):
		if KINDS.has(p.id) and Hidden.is_found(p.id) and not beaten(p.id):
			_make(scene, holder, p)


static func wake_for(place_id: String) -> void:
	# A place was just found: its guardian curls up beside it a moment later
	if not KINDS.has(place_id) or beaten(place_id):
		return
	var scene := Hidden.get_tree().current_scene as Node3D
	var holder := scene.get_node_or_null("Hidden Places") as Node3D if scene else null
	if holder == null or holder.get_node_or_null("Guardian " + place_id) != null:
		return
	for p in Hidden.places_in("void"):
		if p.id == place_id:
			var g := _make(scene, holder, p)
			Fx.burst(g, Vector3(0, 1.5, 0), g.colour, 20, 0.1, 3.0, 0.0, 0.9)
			Game.message("Something big is sleeping nearby...")


static func _make(scene: Node3D, holder: Node3D, p: Dictionary) -> CharacterBody3D:
	var g: CharacterBody3D = (load("res://scripts/guardian.gd") as GDScript).new()
	var k: Dictionary = KINDS[p.id]
	g.name = "Guardian " + str(p.id)
	g.id = str(p.id)
	g.title = str(k.name)
	g.colour = k.colour
	g.moves = k.moves
	g.height = float(k.height)
	g.floats = float(k.floats)
	var s := spot_for(p)
	g.home = Bosses.ground(scene, s.x, s.y)
	holder.add_child(g)
	g.global_position = g.home
	return g


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	add_to_group("guardians")
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_mask = 0                         # it keeps to its own ground height
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.1
	cap.height = height
	cs.shape = cap
	cs.position.y = height * 0.5
	add_child(cs)
	_hitbox = Area3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.monitorable = false
	var hcs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 1.35
	hcap.height = height + 0.4
	hcs.shape = hcap
	hcs.position.y = height * 0.5
	_hitbox.add_child(hcs)
	add_child(_hitbox)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	Callable(self, "_look_" + id).call(visual)
	_bar = BossBar.make(self, title, colour, height + floats + 1.0, 2.0)
	_bar.visible = false
	_sleep_pose(true)


func _find_player() -> void:
	if player and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _physics_process(delta: float) -> void:
	if defeated:
		return
	_find_player()
	if player == null:
		return
	_t += delta
	_state_t -= delta
	_told = maxf(_told - delta, 0.0)
	var from_home := _flat(player.global_position - home)
	if state == State.SLEEP:
		if from_home < WAKE and not Dialogue.is_active():
			_wake()
		_animate(delta)
		return
	if from_home > LEASH:
		_calm_down()
		return
	var h := Vector3.ZERO
	var want_y := home.y + floats
	match state:
		State.IDLE:
			var to := player.global_position - global_position
			to.y = 0
			if to.length() > 4.0:
				h = to.normalized() * 2.2 * Arsenal.slow(self)
			if _state_t <= 0.0:
				_start_move()
		State.WARN:
			if _move == "dash":
				_face(_dir, delta)
			if _state_t <= 0.0:
				_do_move()
		State.ACT:
			match _move:
				"dash":
					h = _dir * SWOOP_SPEED
					want_y = home.y + 0.6
				"pull":
					_pull_step(delta)
			if _state_t <= 0.0:
				_daze()
		State.DAZED:
			want_y = home.y
			if _state_t <= 0.0 or _daze_hits >= MAX_PER_DAZE:
				state = State.IDLE
				_state_t = IDLE_TIME
	# Keep near its spot
	var off := global_position - home
	off.y = 0
	if off.length() > ROAM and state != State.ACT:
		h += -off.normalized() * 4.0
	velocity.x = h.x if state == State.ACT else move_toward(velocity.x, h.x, 14.0 * delta)
	velocity.z = h.z if state == State.ACT else move_toward(velocity.z, h.z, 14.0 * delta)
	var bob := 0.0 if state == State.DAZED else sin(_t * 2.4) * 0.2 * (0.3 if Settings.reduce_motion else 1.0)
	velocity.y = (want_y + bob - global_position.y) * 6.0
	move_and_slide()
	if state == State.IDLE or state == State.DAZED:
		_face(player.global_position - global_position, delta)
	_animate(delta)
	_bar.fill = 1.0 - float(hits) / HITS
	if _hitbox.overlaps_body(player):
		_touch_player()


func _face(dir: Vector3, delta: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-5.0 * delta))


func _wake() -> void:
	state = State.IDLE
	_state_t = IDLE_TIME
	_bar.visible = true
	_sleep_pose(false)
	Juice.blip("whoosh", 0.6, -4.0)
	Juice.shake(0.2)
	Game.message("%s wakes up! Walk away to let it sleep." % title)


func _calm_down() -> void:
	# You walked off: no harm done, it settles back to sleep with all its puff back
	state = State.SLEEP
	hits = 0
	_bar.visible = false
	_bar.fill = 1.0
	velocity = Vector3.ZERO
	global_position = home
	for t in get_tree().get_nodes_in_group("boss_tells"):
		if is_instance_valid(t) and t.get("follow") == self:
			t.queue_free()
	_sleep_pose(true)
	Game.message("%s settles back to sleep." % title)


func _start_move() -> void:
	_move = str(moves[_move_i % moves.size()])
	_move_i += 1
	state = State.WARN
	var lead := TELL.lead()
	_state_t = lead
	var ground := home.y
	match _move:
		"jump":
			TELL.warn(self, "jump", RING_REACH, colour, lead + 0.3, {"visual": visual, "ground_y": ground})
		"dash":
			_dir = player.global_position - global_position
			_dir.y = 0
			_dir = _dir.normalized() if _dir.length() > 0.1 else -visual.global_basis.z
			TELL.warn(self, "dash", SWOOP_LEN, colour, lead, {"visual": visual, "dir": _dir, "follow": null,
				"at": Vector3(global_position.x, ground + 0.06, global_position.z)})
		"drop":
			_target = Vector3(player.global_position.x, ground, player.global_position.z)
			TELL.warn(self, "drop", DROP_R, colour, lead, {"visual": visual, "follow": null,
				"at": _target + Vector3(0, 0.06, 0)})
		"pull":
			TELL.warn(self, "pull", PULL_REACH, colour, lead, {"visual": visual, "ground_y": ground})


func _do_move() -> void:
	state = State.ACT
	match _move:
		"jump":
			_state_t = 0.35
			ShockRing.spawn(get_parent(), Vector3(global_position.x, home.y, global_position.z), RING_REACH, colour, 2, 0.9)
			Juice.shake(0.35)
			Juice.blip("thud", 0.7, -2.0)
			_squash(0.6)
		"dash":
			_state_t = SWOOP_LEN / SWOOP_SPEED
			Juice.blip("whoosh", 0.8, -3.0)
		"drop":
			_state_t = 0.4
			_star_fall(_target)
		"pull":
			_state_t = PULL_TIME
			Juice.blip("whoosh", 0.4, -3.0)


func _star_fall(at: Vector3) -> void:
	# A glowing star drops out of the sky where the shadow was, and bumps you if you're still on it
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	star.mesh = sm
	star.material_override = _mat(Color(1.0, 0.92, 0.6), 2.0)
	get_parent().add_child(star)
	star.global_position = at + Vector3(0, 12, 0)
	var tw := star.create_tween()
	tw.tween_property(star, "global_position", at + Vector3(0, 0.5, 0), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Fx.burst(get_parent(), at + Vector3(0, 0.4, 0), Color(1.0, 0.9, 0.5), 18, 0.08, 4.0, 0.0, 0.6)
		Juice.blip("thud", 1.2, -4.0)
		if is_instance_valid(player) and _flat(player.global_position - at) < DROP_R \
				and player.global_position.y < at.y + 2.0 and not player.call("is_invulnerable"):
			player.call("hurt", 2, at)
		star.queue_free())


func _pull_step(delta: float) -> void:
	# The gulp: it breathes in and drags you along the ground towards it. Jumping breaks free.
	if not player.is_on_floor():
		return
	var to := global_position - player.global_position
	to.y = 0
	var d := to.length()
	if d > PULL_REACH or d < 2.2:
		return
	player.global_position += to / d * PULL_SPEED * delta


func _daze() -> void:
	state = State.DAZED
	_state_t = DAZE_TIME
	_daze_hits = 0
	velocity = Vector3.ZERO
	_squash(0.4)
	if hits == 0 and _told <= 0.0:
		Game.message("%s's puffed out! Pop it now!" % title)
		_told = 20.0


func _touch_player() -> void:
	if state == State.DAZED:
		var feet := player.global_position.y - 0.8
		if player.velocity.y < 0.5 and feet > global_position.y + height * 0.6:
			player.call("bounce", 9.0)
			hurt(1)
			return
		if player.call("is_rolling"):
			hurt(1)
		return
	if state == State.SLEEP:
		return
	if not player.call("is_invulnerable"):
		player.call("hurt", 2, global_position)


func shot(power: int, point: Vector3, _dir_in: Vector3) -> String:
	if defeated or state == State.SLEEP:
		return "miss"
	if state != State.DAZED:
		Fx.burst(get_parent(), point, colour, 6, 0.05, 2.0, 0.0, 0.3)
		if _told <= 0.0:
			Game.message("Boing! Wait till it's puffed out.")
			_told = 8.0
		return "miss"
	hurt(mini(power, MAX_PER_DAZE - _daze_hits))
	return "hit"


func hurt(n: int) -> void:
	if defeated or n <= 0:
		return
	hits += n
	_daze_hits += n
	Juice.hitstop(0.05)
	Fx.burst(get_parent(), global_position + Vector3(0, height * 0.6, 0), colour, 10, 0.08, 3.0, 0.5, 0.5)
	Juice.blip("pop", 0.7, -4.0)
	_squash(0.3)
	if hits >= HITS:
		_calmed()


func _calmed() -> void:
	defeated = true
	state = State.CALMED
	velocity = Vector3.ZERO
	_bar.fill = 0.0
	_bar.visible = false
	_hitbox.set_deferred("monitoring", false)
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	Dialogue.flags[flag(id)] = true
	Game.add_sparkles(SPARKLES, title)
	Remnants.add(REMNANTS, title)
	var gifts := ["+%d sparkles" % SPARKLES, "+%d Remnants" % REMNANTS]
	var hat := str(KINDS[id].hat)
	if not Game.has_item("shop:" + hat):
		Game.items.append("shop:" + hat)
		gifts.append("the " + str(Shop.items.get(hat, {}).get("name", hat.capitalize())))
	Game.message("%s is calm and happy!\n%s" % [title, ", ".join(gifts)])
	Juice.rumble(0.4, 0.3)
	Fx.burst(get_parent(), global_position + Vector3(0, height * 0.6, 0), Color(1.0, 0.9, 0.5), 30, 0.1, 4.0, -1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3.ONE * 0.3, 1.2).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "position:y", 6.0, 1.4)
	tw.parallel().tween_property(visual, "scale", Vector3.ONE * 0.05, 1.4)
	tw.tween_callback(queue_free)
	Game.save_game()


# -----------------------------------------------------------------------------
# Looks, made from shapes (nothing solid; the body's capsule is the only collision)
# -----------------------------------------------------------------------------
func _sleep_pose(on: bool) -> void:
	# Curled up low with its eyes shut, breathing slowly
	if visual == null:
		return
	visual.position.y = -floats if on else 0.0
	for e in _parts.get("eyes", []):
		(e as Node3D).scale.y = 0.15 if on else 1.0
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz:
		zz.visible = on


func _squash(k: float) -> void:
	if visual == null:
		return
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.0 + 0.2 * k, 1.0 - 0.25 * k, 1.0 + 0.2 * k), 0.08)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _animate(_delta: float) -> void:
	var calm := 0.3 if Settings.reduce_motion else 1.0
	var sleeping := state == State.SLEEP
	var speed := 1.2 if sleeping else (9.0 if state == State.ACT else 4.0)
	var flap := sin(_t * speed) * calm
	for w in _parts.get("wings", []):
		var side := float((w as Node3D).get_meta("side"))
		(w as Node3D).rotation.z = side * (0.35 + flap * (0.12 if sleeping else 0.5))
	var i := 0
	for seg in _parts.get("tail", []):
		(seg as Node3D).position.x = sin(_t * 3.0 - i * 0.7) * 0.25 * i * 0.3 * calm
		i += 1
	var throat := _parts.get("throat") as Node3D
	if throat:
		var puff := 1.0 + (0.6 if state == State.WARN and _move == "pull" else 0.0) + 0.12 * sin(_t * speed * 0.6)
		throat.scale = Vector3(puff, puff * 0.8, puff)
	var zz := visual.get_node_or_null("Zzz") as Label3D
	if zz and zz.visible:
		zz.position.y = height * 0.7 + fmod(_t * 0.4, 1.0) * 0.6


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _put(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	return c


func _eyes(parent: Node3D, y: float, z: float, apart: float, r: float, col := Color(0.1, 0.08, 0.2)) -> void:
	var out: Array = []
	for side in [-1.0, 1.0]:
		var white := _put(parent, _ball(r), _mat(Color(1, 1, 1)), Vector3(side * apart, y, z))
		_put(white, _ball(r * 0.55), _mat(col), Vector3(0, 0, r * 0.6))
		_put(white, _ball(r * 0.18), _mat(Color(1, 1, 1), 1.5), Vector3(r * 0.2, r * 0.25, r * 0.95))
		out.append(white)
	_parts["eyes"] = out


func _zzz(parent: Node3D) -> void:
	var z := Label3D.new()
	z.name = "Zzz"
	z.text = "z z z"
	z.font_size = 72
	z.outline_size = 16
	z.modulate = Color(0.95, 0.9, 1.0)
	z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	z.position = Vector3(0.8, height * 0.7, 0)
	parent.add_child(z)


func _look_star_well(v: Node3D) -> void:
	# Glimmerwing: a big round moth, midnight blue and fluffy, with four wide wings speckled with stars, feathery
	# antennae with glowing tips, and big friendly eyes
	var body := Node3D.new()
	body.position.y = 1.6
	v.add_child(body)
	var fluff := _mat(Color(0.25, 0.27, 0.6))
	_put(body, _ball(0.9), fluff, Vector3(0, 0, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
	_put(body, _ball(0.75), _mat(Color(0.82, 0.85, 1.0)), Vector3(0, -0.2, 0.25), Vector3.ZERO, Vector3(1, 1, 0.8))
	_put(body, _ball(0.7), fluff, Vector3(0, 0.95, 0.15))
	_eyes(body, 1.05, 0.65, 0.32, 0.22)
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.set_meta("side", side)
		hinge.position = Vector3(side * 0.5, 0.4, -0.1)
		body.add_child(hinge)
		for k in 2:
			var w := _put(hinge, _ball(1.0), _mat(Color(0.35, 0.4, 0.85).lerp(Color(0.6, 0.45, 0.95), k * 0.6)),
				Vector3(side * 1.4, 0.3 - k * 1.0, 0), Vector3(0, 0, side * (0.3 + k * 0.6)), Vector3(1.5 - k * 0.4, 1.0 - k * 0.2, 0.06))
			for s in 6:
				_put(w, _ball(0.07), _mat(Color(1.0, 0.95, 0.6), 2.0),
					Vector3(cos(s * 1.7 + k) * 0.6, sin(s * 2.3) * 0.55, 0.9 * side), Vector3.ZERO, Vector3(1, 1, 8))
		wings.append(hinge)
	_parts["wings"] = wings
	for side in [-1.0, 1.0]:
		var stalk := _put(body, _cone(0.03, 0.05, 1.0), _mat(Color(0.3, 0.3, 0.65)), Vector3(side * 0.28, 1.75, 0.35),
			Vector3(0.4, 0, -side * 0.4))
		_put(stalk, _ball(0.12), _mat(Color(1.0, 0.92, 0.55), 2.5), Vector3(0, 0.55, 0))
	_zzz(v)


func _look_bubble_spring(v: Node3D) -> void:
	# Old Bubblebeard: a huge round mossy toad, sea green with paler spots, sat on a lily pad, a throat that puffs
	# up, and a long beard made of shiny bubbles
	var green := _mat(Color(0.35, 0.65, 0.5))
	_put(v, CylinderMesh.new(), _mat(Color(0.3, 0.6, 0.35)), Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(3.2, 0.05, 3.2))
	_put(v, _ball(1.4), green, Vector3(0, 1.3, 0), Vector3.ZERO, Vector3(1.15, 0.9, 1.0))
	for s in 9:
		_put(v, _ball(0.18), _mat(Color(0.55, 0.85, 0.6)), Vector3(cos(s * 2.1) * 1.2, 1.4 + sin(s * 1.3) * 0.6, sin(s * 2.1) * 1.0 - 0.2))
	for side in [-1.0, 1.0]:
		_put(v, _ball(0.55), green, Vector3(side * 1.1, 0.5, 0.6), Vector3.ZERO, Vector3(1, 0.5, 1.3))
		var bump := _put(v, _ball(0.42), green, Vector3(side * 0.6, 2.4, 0.7))
		bump.scale = Vector3(1, 0.9, 1)
	_eyes(v, 2.5, 0.95, 0.6, 0.3, Color(0.25, 0.15, 0.05))
	_put(v, _cone(0.6, 0.6, 0.05), _mat(Color(0.2, 0.35, 0.25)), Vector3(0, 1.85, 1.3), Vector3(PI / 2.0, 0, 0), Vector3(1.6, 1, 0.2))
	var throat := _put(v, _ball(0.6), _mat(Color(0.85, 0.95, 0.75)), Vector3(0, 1.35, 1.0), Vector3.ZERO, Vector3(1, 0.8, 0.6))
	_parts["throat"] = throat
	var bub := _mat(Color(0.75, 0.95, 1.0, 0.55), 0.4)
	bub.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for s in 12:
		_put(v, _ball(0.12 + 0.05 * (s % 3)), bub, Vector3(sin(s * 1.9) * 0.45, 0.95 - s * 0.07, 1.3 + cos(s * 1.3) * 0.12))
	_zzz(v)


func _look_kite_hill(v: Node3D) -> void:
	# Ribbontail: a dragon made of a paper kite, red and gold diamonds for a body and wings, a painted face with a
	# grin and whiskers, and a long ribbon tail of bows that waves behind it
	var red := _mat(Color(1.0, 0.38, 0.32))
	var gold := _mat(Color(1.0, 0.82, 0.3))
	var body := Node3D.new()
	body.position.y = 1.8
	v.add_child(body)
	_put(body, BoxMesh.new(), red, Vector3(0, 0, 0), Vector3(0, 0, PI / 4), Vector3(1.6, 1.6, 0.12))
	_put(body, BoxMesh.new(), gold, Vector3(0, 0, 0.07), Vector3(0, 0, PI / 4), Vector3(0.8, 0.8, 0.05))
	var head := _put(body, BoxMesh.new(), red, Vector3(0, 1.25, 0.25), Vector3(0, 0, PI / 4), Vector3(0.9, 0.9, 0.5))
	head.name = "Head"
	_eyes(body, 1.4, 0.55, 0.22, 0.17)
	for side in [-1.0, 1.0]:
		_put(body, _cone(0.0, 0.08, 0.5), gold, Vector3(side * 0.35, 1.85, 0.2), Vector3(0, 0, -side * 0.5))
		_put(body, _cone(0.01, 0.02, 0.9), _mat(Color(0.2, 0.1, 0.1)), Vector3(side * 0.6, 1.1, 0.5), Vector3(0, 0, side * 1.3))
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.set_meta("side", side)
		hinge.position = Vector3(side * 0.6, 0.2, 0)
		body.add_child(hinge)
		_put(hinge, BoxMesh.new(), gold, Vector3(side * 1.0, 0, 0), Vector3(0, 0, PI / 4), Vector3(1.3, 0.9, 0.06))
		_put(hinge, BoxMesh.new(), red, Vector3(side * 1.0, 0, 0.04), Vector3(0, 0, PI / 4), Vector3(0.6, 0.45, 0.04))
		wings.append(hinge)
	_parts["wings"] = wings
	var tail: Array = []
	for k in 8:
		var bow := Node3D.new()
		bow.position = Vector3(0, -1.1 - k * 0.15, -0.4 - k * 0.55)
		body.add_child(bow)
		var c := Color(1.0, 0.85, 0.3) if k % 2 == 0 else Color(0.45, 0.75, 1.0)
		for side in [-1.0, 1.0]:
			_put(bow, _cone(0.0, 0.2, 0.35), _mat(c), Vector3(side * 0.15, 0, 0), Vector3(0, 0, side * PI / 2.0))
		tail.append(bow)
	_parts["tail"] = tail
	_zzz(v)
