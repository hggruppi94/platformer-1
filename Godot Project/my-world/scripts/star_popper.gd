class_name StarPopper
extends Node3D

# The Star Popper: the hero's toy bubble blaster, for popping Gloops and Crocodillos from a distance (stomping still
# works too). It blows shiny star bubbles (scripts/star_bubble.gd); nothing gets hurt, enemies get caught in a bubble
# and pop away.
#
#   Shoot (left click / RT)        a bubble straight ahead. Not aiming, it finds an enemy in front of her by itself.
#   Aim (right click / LT, held)   the camera moves in over her right shoulder, a crosshair shows, she faces where
#                                  the camera looks and walks slower. Bubbles go where the crosshair is (a controller
#                                  gets a little help onto an enemy near it).
#   Hold Shoot                     charges a big bubble (1 MP) that counts for three pops and carries on through.
#
# On the board (or a friend's ride) Shoot works too: rolling, in the air, on a grind or in a manual. From the hip it
# finds an enemy ahead of where she's going. Aim works too (not in a race, where Aim uses the power-up): the camera is
# then the player's to look round with and the board steers from where she's going. Each one popped is a "Pop!" trick
# in the combo (Skate.on_pop, SkateTricks.pop). Riders with no hand free (Rides "popper": false) can't. Not on the
# zipline or in the mothership, and not while talking, in a menu or the creator.
# Her right arm points the popper where the bubbles go (PopperArm below), and the popper shows in her hand while she
# aims and for a moment after each shot. Keys and buttons are in Settings > Controls ("aim", "shoot").
#
# The Star Popper is the first of her gadgets (scripts/arsenal.gd). Shoot fires whichever one is out: the Fizz
# Flinger lobs a fizz bomb (scripts/fizz_bomb.gd) and the Disco Ball throws a mirror ball (scripts/disco_ball.gd) at
# what she's aiming at, or at an enemy in front of her. Only the Star Popper charges a big bubble. Each gadget shows
# in her hand while it's out, and the gadget wheel (scripts/gadget_wheel.gd) picks one.
# The Plushinator fires a fluffy bolt (scripts/plush_bolt.gd), the Buzz Bots send out helper bots (buzz_bots.gd), the
# Rainbow Ray shines while Shoot is held (rainbow_ray.gd) and the Jelly Mines drop jelly at her feet (jelly_mine.gd).
# The Split mod fires two of anything a little apart (more bots for the Buzz Bots); the other mods are worked by the
# shots themselves (Arsenal: mods).

signal popped(enemy: Node3D, bubble: Node3D)   # one of her bubbles popped an enemy (StarBubble)

const COOLDOWN := 0.2                     # seconds between bubbles
const CHARGE_START := 0.3                 # holding Shoot this long starts charging a big bubble...
const CHARGE_TIME := 0.8                  # ...and it's ready this much later
const BIG_COST := 1                       # MP for a big bubble
const MAX_FLYING := 14                    # bubbles in the air at once
const AIM_MOVE := 0.55                    # walking speed while aiming
const AIM_RANGE := 60.0                   # how far the crosshair looks for something to aim at
const AUTO_RANGE := 24.0                  # not aiming: enemies this close...
const AUTO_ANGLE := 32.0                  # ...and within this many degrees of where she faces get aimed at
const ASSIST_ANGLE := {"pad": 4.0, "keyboard": 1.5}   # aiming: how close to the crosshair counts as on an enemy
const SHOW_AFTER_SHOT := 1.2              # seconds the popper stays in her hand after a shot
const BOARD_RANGE := 26.0                 # on the board: enemies this close...
const BOARD_ANGLE := 40.0                 # ...and within this many degrees of where she's going get aimed at
const THROW_REACH := 9.0                  # a throw (fizz, disco) with nothing to aim at lands this far in front
# Its colours (Game.popper_colour): body, nozzle, grip, trim. "classic" is how it comes; the rest are earned (Dash
# gives "clockwork" for ten lost watches, scripts/watches.gd) and owned as items "popper_colour:<id>".
const COLOURS := {
	"classic": [Color(0.72, 0.58, 0.98), Color(0.3, 0.9, 0.82), Color(1.0, 0.5, 0.78), Color(1.0, 0.82, 0.3)],
	"clockwork": [Color(0.95, 0.75, 0.35), Color(0.25, 0.75, 0.7), Color(0.45, 0.25, 0.55), Color(0.85, 0.9, 1.0)],
}

var player: Player
var aiming := false
var aim_blend := 0.0                      # 0..1, eases in and out (the camera and her arm follow it)
var charge := 0.0                         # 0..1 while a big bubble charges
var shots := 0                            # every bubble she's blown (tests read it)
var _cooldown := 0.0
var _held := 0.0                          # how long Shoot has been held
var _raise := 0.0                         # her arm comes up for a moment after a shot from the hip
var _shot_dir := Vector3.FORWARD          # ...pointing where that shot went
var _arm: PopperArm
var _prop: Node3D                         # the popper itself, in her hand
var _hud: CanvasLayer
var _cross: Control
var _on_target := false                   # the crosshair is on an enemy (it turns pink)
var _tipped := false
var _wheel: GadgetWheel
var _told_empty := 0.0                    # seconds till "out of ammo" can be said again
var ray: RainbowRay                       # the Rainbow Ray's beam (made the first time it shines)
var _ray_drain := 0.0                     # seconds till the ray uses another shot of ammo


func setup(p: Player) -> void:
	player = p
	name = "StarPopper"
	_prop = _hand_prop()
	_prop.top_level = true
	_prop.visible = false
	add_child(_prop)
	Game.equipment_changed.connect(_recolour)
	Arsenal.changed.connect(_recolour)
	popped.connect(Arsenal.on_pop)            # pops make gadgets grow versions (and sometimes leave ammo)
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	_cross = Crosshair.new()
	_cross.popper = self
	_cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.visible = false
	_hud.add_child(_cross)
	_wheel = GadgetWheel.new()
	_wheel.name = "GadgetWheel"
	_wheel.popper = self
	_hud.add_child(_wheel)


func attach(model: Node3D) -> void:
	# A new model (the hero's made or remade, or a friend's riding): her arm's mover goes on its skeleton
	if _arm and is_instance_valid(_arm):
		_arm.queue_free()
	_arm = null
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	var skel := skels[0] as Skeleton3D
	if skel.find_bone("upper_arm.R") < 0:
		return
	_arm = PopperArm.new()
	_arm.name = "PopperArm"
	_arm.popper = self
	skel.add_child(_arm)


func can_shoot() -> bool:
	if player == null or player.carried or player.input_locked:
		return false
	if Game.riding and not player.skate.can_shoot():
		return false
	if Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or Shop.is_open() or get_tree().paused:
		return false
	# The click that grabs the mouse back into the game window isn't a shot
	if Settings.last_device == "keyboard" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _in_test():
		return false
	return true


func _in_test() -> bool:
	return get_tree().get_script() != null       # tests and screenshot tools run their own main loop


func move_scale() -> float:
	return lerpf(1.0, AIM_MOVE, aim_blend)


func aim_yaw() -> float:
	# Which way she faces while aiming: where the camera looks
	var f := -player.spring_arm.global_transform.basis.z
	return atan2(f.x, f.z)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var ok := can_shoot()
	# Aiming works on a ride too (the board then steers from where she's going, not the camera: skate.gd
	# _camera_dir), except in a race, where Aim uses the power-up (scripts/races.gd)
	aiming = ok and Input.is_action_pressed("aim") and not (Game.riding and Races.racing())
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta / 0.16)
	player.spring_arm.aim = aim_blend * aim_blend * (3.0 - 2.0 * aim_blend)      # eased
	_cooldown -= delta
	_told_empty -= delta
	_raise = maxf(_raise - delta, 0.0)
	if not ok:
		_held = 0.0
		charge = 0.0
	else:
		if not _tipped:
			_tipped = true
			if not get_tree().get_nodes_in_group("enemies").is_empty():
				Tips.show_tip("shoot")             # the first time there's something to pop (scripts/tips.gd)
		if Game.riding and not Tips.seen("skate_shoot") and _enemy_near(BOARD_RANGE):
			Tips.show_tip("skate_shoot")
		if Arsenal.current == "rainbow":
			_held = 0.0
			if Input.is_action_pressed("shoot"):
				shine(delta)                       # the Rainbow Ray shines while Shoot is held
		elif Input.is_action_just_pressed("shoot"):
			_held = 0.0
			shoot(false)
		elif Input.is_action_pressed("shoot") and Arsenal.current != "popper":
			_held = 0.0                            # only the Star Popper charges up
		elif Input.is_action_pressed("shoot"):
			_held += delta
			if _held > CHARGE_START:
				var was := charge
				charge = clampf((_held - CHARGE_START) / CHARGE_TIME, 0.0, 1.0)
				if charge >= 1.0 and was < 1.0:
					Audio.play("bubbles", -8.0, 0.0)  # ready!
		elif Input.is_action_just_released("shoot") or charge > 0.0:
			if charge >= 1.0:
				if Game.spend_mp(BIG_COST):
					shoot(true)
				else:
					Game.message("Not enough MP for a big bubble. MP refills in a moment.")
			_held = 0.0
			charge = 0.0
	_update_target()
	_cross.visible = aim_blend > 0.5
	_cross.queue_redraw()
	# The popper's in her hand while she aims, and for a moment after a shot
	_prop.visible = _arm != null and (aim_blend > 0.05 or _raise > 0.0 or charge > 0.0)
	if _arm:
		# Eased in and out over PopperArm.EASE, so the pose never pops on or off
		var arm_on := clampf(maxf(aim_blend, minf(_raise / PopperArm.EASE, 1.0) if _raise > 0.0 else 0.0), 0.0, 1.0)
		if charge > 0.0:
			arm_on = 1.0
		_arm.influence = move_toward(_arm.influence, arm_on, delta / PopperArm.EASE)


func shoot(charged: bool) -> Node3D:
	# Fires whichever gadget is out (Arsenal.current). Returns the bubble, fizz bomb or disco ball, or null.
	if _cooldown > 0.0 and not charged:
		return null
	var id := Arsenal.current
	if id == "rainbow":
		return null                                # the ray shines while Shoot is held (shine())
	if id == "popper" and StarBubble.flying() >= MAX_FLYING:
		return null
	if id != "popper" and not Arsenal.use_ammo(id):
		_cooldown = 0.3
		Audio.play("ui_back", -8.0, 0.0)
		if _told_empty <= 0.0:
			_told_empty = 4.0
			Game.message("The %s is empty! Pop enemies for ammo bubbles, or get a refill at Dash's gadget stall."
				% Arsenal.gadget_name(id))
		return null
	_cooldown = float(Arsenal.stat(id, "cooldown"))
	var from := muzzle()
	var dir := aim_dir(from)
	var to := Vector3.ZERO
	if id in ["fizz", "disco"]:
		to = throw_point(from)
		dir = (to - from).normalized()
	_shot_dir = dir
	if not aiming:
		_raise = SHOW_AFTER_SHOT
		# From the hip she turns to face the shot (not on the board: the board goes where it's going)
		if not Game.riding:
			player.visual.rotation.y = atan2(dir.x, dir.z)
	var scene := get_tree().current_scene if get_tree().current_scene else player.get_parent()
	var mega := Arsenal.level(id) >= Arsenal.MAX_LEVEL
	var split := Arsenal.has_mod(id, "split")
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	# With the Split mod, two of whatever it is, a little apart: thrown ones land either side of the spot, shot ones
	# fan out. Each is a bit smaller.
	var aims: Array = [[to, dir]] if not split else [[to + side * 1.6, (dir + side * 0.08).normalized()],
		[to - side * 1.6, (dir - side * 0.08).normalized()]]
	var shrink := 0.75 if split else 1.0
	var b: Node3D
	match id:
		"fizz":
			for a in aims:
				b = FizzBomb.fire(scene, from, a[0], player, {"radius": float(Arsenal.stat(id, "radius")) * shrink,
					"power": Arsenal.stat(id, "power"), "splits": mega})
			Audio.play("fwump", -5.0, 0.15)
			Juice.rumble(0.25, 0.08)
		"disco":
			for a in aims:
				b = DiscoBall.fire(scene, from, a[0], player, {"radius": float(Arsenal.stat(id, "radius")) * shrink,
					"time": Arsenal.stat(id, "time"), "pops_at_end": mega})
			Audio.play("swish", -4.0, 0.1)
			Juice.rumble(0.2, 0.08)
		"plush":
			for a in aims:
				b = PlushBolt.fire_bolt(scene, from, a[1], player, {"time": Arsenal.stat(id, "time"),
					"radius": Arsenal.stat(id, "radius"), "scale": shrink})
			Audio.play("plush_poof", -6.0, 0.15)
		"buzz":
			b = BuzzBots.deploy(scene, player, {"time": Arsenal.stat(id, "time"), "radius": Arsenal.stat(id, "radius"),
				"rate": Arsenal.stat(id, "rate"), "bots": int(Arsenal.stat(id, "bots")) + (2 if split else 0)})
		"jelly":
			var at := _feet_ahead()
			var stats := {"radius": float(Arsenal.stat(id, "radius")) * shrink, "time": Arsenal.stat(id, "time"),
				"leaves_two": mega}
			if split:
				var flat := Vector3(side.x, 0, side.z).normalized()
				b = JellyMine.drop(scene, at + flat * 0.9, player, stats)
				JellyMine.drop(scene, at - flat * 0.9, player, stats)
			else:
				b = JellyMine.drop(scene, at, player, stats)
		_:
			var lv := Arsenal.level("popper")
			var grow := (1.35 if lv >= 4 else 1.0) * Arsenal.boost("popper") * shrink     # V4: bigger bubbles
			for a in aims:
				b = StarBubble.fire(scene, from, a[1], player, charged, grow)
				if lv >= Arsenal.MAX_LEVEL and not charged:
					# The Mega Popper blows two at once, a little apart
					StarBubble.fire(scene, from + side * 0.15, (a[1] + side * 0.06).normalized(), player, false, grow)
			Audio.play("bloop", -4.0 if charged else -7.0, 0.15)
			Juice.rumble(0.25 if charged else 0.08, 0.1 if charged else 0.04)
			if charged:
				Juice.shake(0.08)
	if Game.riding and player.skate.grinding():
		b.set_meta("from_grind", true)            # popping something with it counts as off a grind (skate goals)
	shots += 1
	if _arm:
		_arm.kick(charged)                         # her body kicks back a little (PopperArm, on a ride)
	if charged and not Settings.reduce_motion:
		player.spring_arm.fov_kick = 4.0
	return b


func shine(delta: float) -> void:
	# One frame of the Rainbow Ray: it uses a shot of ammo every so often while it's on
	_ray_drain -= delta
	if _ray_drain <= 0.0:
		if not Arsenal.use_ammo("rainbow"):
			if _told_empty <= 0.0:
				_told_empty = 4.0
				Audio.play("ui_back", -8.0, 0.0)
				Game.message("The %s is empty! Pop enemies for ammo bubbles, or get a refill at Dash's gadget stall."
					% Arsenal.gadget_name("rainbow"))
			return
		_ray_drain = float(Arsenal.stat("rainbow", "cooldown"))
	if ray == null or not is_instance_valid(ray):
		ray = RainbowRay.new()
		ray.shooter = player
		var scene := get_tree().current_scene if get_tree().current_scene else player.get_parent()
		scene.add_child(ray)
	var from := muzzle()
	var dir := aim_dir(from)
	_shot_dir = dir
	if not aiming:
		_raise = SHOW_AFTER_SHOT
		if not Game.riding:
			player.visual.rotation.y = atan2(dir.x, dir.z)
	ray.shine(from, dir, {"radius": Arsenal.stat("rainbow", "radius"), "time": Arsenal.stat("rainbow", "time"),
		"pierce": Arsenal.level("rainbow") >= Arsenal.MAX_LEVEL})


func _feet_ahead() -> Vector3:
	# Where a jelly mine goes: on the ground a little in front of her
	var ahead := player.global_position + _ahead() * 1.4 + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3(0, -6, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else player.global_position + _ahead() * 1.4 - Vector3(0, 0.85, 0)


func throw_point(from: Vector3) -> Vector3:
	# Where a throw lands: where she's aiming, an enemy in front of her, or the ground a little way ahead
	if aiming:
		return aim_point()
	var e := auto_target(from)
	if e:
		return e.global_position
	var face := _ahead()
	var ahead := player.global_position + face * THROW_REACH + Vector3(0, 2.0, 0)
	var q := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3(0, -12, 0))
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else ahead - Vector3(0, 2.0, 0)


func muzzle() -> Vector3:
	# The popper's nozzle when it's in her hand; otherwise in front of her chest
	if _prop.visible and _arm and _arm.influence > 0.5:
		var tip := _prop.global_transform * Vector3(0, 0, 0.32)
		if tip.distance_to(player.global_position) < 2.0:     # (not left behind from before she was moved)
			return tip
	var face := player.visual.global_transform.basis.z
	return player.global_position + Vector3(0, 0.35, 0) + face.normalized() * 0.45


func aim_dir(from: Vector3) -> Vector3:
	if aiming:
		return (aim_point() - from).normalized()
	# From the hip: at the nearest enemy in front of her, or straight ahead
	var best := auto_target(from)
	if best:
		return (_centre(best) - from).normalized()
	return _ahead()


func _ahead() -> Vector3:
	# Which way is in front of her, flat. On the board, ahead is where she's going (she may be spinning in the air).
	var face := player.visual.global_transform.basis.z
	face.y = 0.0
	face = face.normalized() if face.length() > 0.01 else Vector3.FORWARD
	if Game.riding:
		var going := Vector3(player.velocity.x, 0, player.velocity.z)
		if going.length() > 2.0:
			face = going.normalized()
	return face


func auto_target(from: Vector3) -> Node3D:
	# The nearest enemy in front of her, for a shot from the hip. On the board it looks a bit wider and further,
	# since she can't stop and turn to line a shot up.
	var face := _ahead()
	var reach := BOARD_RANGE if Game.riding else AUTO_RANGE
	var angle := BOARD_ANGLE if Game.riding else AUTO_ANGLE
	var best: Node3D = null
	var best_d := reach
	for e in _targets():
		var to: Vector3 = _centre(e) - from
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() > best_d or flat.length() < 0.3:
			continue
		if rad_to_deg(face.angle_to(flat)) > angle or not _clear(from, _centre(e), e):
			continue
		best = e
		best_d = flat.length()
	return best


func aim_point() -> Vector3:
	# Where the crosshair is: the first thing straight out from the camera, or an enemy right by it
	var cam := player.spring_arm.get_node("Camera3D") as Camera3D
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var assist: float = ASSIST_ANGLE.get(Settings.last_device, 1.5)
	var best: Node3D = null
	for e in _targets():
		var to: Vector3 = _centre(e) - o
		if to.length() > AIM_RANGE:
			continue
		var a := rad_to_deg(d.angle_to(to))
		if a < assist and _clear(o, _centre(e), e):
			best = e
			assist = a
	if best:
		return _centre(best)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * AIM_RANGE)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else o + d * AIM_RANGE


func _update_target() -> void:
	_on_target = false
	if aim_blend < 0.5:
		return
	var p := aim_point()
	for e in _targets():
		if _centre(e).distance_to(p) < 0.9:
			_on_target = true
			return


func _targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_inside_tree() and not e.get("defeated") and (e as Node3D).is_visible_in_tree():
			out.append(e)
	return out


func _enemy_near(d: float) -> bool:
	for e in _targets():
		if e.global_position.distance_to(player.global_position) < d:
			return true
	return false


func _centre(e: Node3D) -> Vector3:
	return e.global_position + Vector3(0, 0.45 * float(e.get("size") if e.get("size") != null else 1.0), 0)


func _clear(from: Vector3, to: Vector3, target: Node) -> bool:
	# Nothing solid in the way (other than the target itself)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == target or (hit.collider as Node).is_ancestor_of(target) \
		or target.is_ancestor_of(hit.collider as Node)


func arm_dir() -> Vector3:
	# Where her arm points (PopperArm): the crosshair while aiming, otherwise the last shot
	if aiming or charge > 0.0:
		var from := player.global_position + Vector3(0, 0.4, 0)
		return (aim_point() - from).normalized() if aiming else player.visual.global_transform.basis.z.normalized()
	return _shot_dir


func place_prop(hand: Transform3D, dir: Vector3) -> void:
	# The popper sits in her hand, pointing where the bubbles go (PopperArm calls this as it poses the arm)
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var b := Basis.looking_at(-dir, up)        # looking_at points -Z; the popper's nozzle is on +Z
	var s := clampf(hand.basis.get_scale().x, 0.6, 1.6)
	_prop.global_transform = Transform3D(b.scaled(Vector3.ONE * s), hand.origin + dir * 0.06)


func _hand_prop() -> Node3D:
	# What's in her hand: the gadget that's out (the Star Popper in its colours)
	match Arsenal.current:
		"fizz":
			return FizzBomb.build_prop()
		"disco":
			return DiscoBall.build_prop()
		"plush":
			return PlushBolt.build_prop()
		"buzz":
			return BuzzBots.build_prop()
		"rainbow":
			return RainbowRay.build_prop()
		"jelly":
			return JellyMine.build_prop()
	var p := build_prop(Game.popper_colour)
	p.set_meta("gadget", "popper")
	return p


func _recolour() -> void:
	# A new colour picked (or earned), or another gadget picked: swap what's in her hand
	if _prop == null:
		return
	var gadget := str(_prop.get_meta("gadget", "popper"))
	if gadget == Arsenal.current and (gadget != "popper" or str(_prop.get_meta("colour", "")) == Game.popper_colour):
		return
	var shown := _prop.visible
	var at := _prop.global_transform
	_prop.queue_free()
	_prop = _hand_prop()
	_prop.top_level = true
	_prop.visible = shown
	add_child(_prop)
	_prop.global_transform = at
	if gadget != Arsenal.current and player and not aiming:
		_raise = SHOW_AFTER_SHOT              # a new gadget out: she holds it up for a moment, so you can see it
		_shot_dir = player.visual.global_transform.basis.z.normalized()


static func build_prop(colour := "classic") -> Node3D:
	# A chunky toy: a lilac body with a round bubble tank on top, a teal nozzle in front with a gold star on it, and a
	# pink grip (in the classic colours). About 0.4 m long, nozzle towards +Z.
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("colour", colour)
	var c: Array = COLOURS.get(colour, COLOURS.classic)
	var lilac := _mat(c[0], 0.4, 0.5 if colour == "clockwork" else 0.0)
	var teal := _mat(c[1], 0.3)
	var pink := _mat(c[2], 0.5)
	var gold := _mat(c[3], 0.25, 0.6)
	var body := _part(root, CapsuleMesh.new(), lilac, Vector3(0, 0.03, 0.1), Vector3(PI / 2, 0, 0))
	(body.mesh as CapsuleMesh).radius = 0.06
	(body.mesh as CapsuleMesh).height = 0.28
	var nozzle := _part(root, CylinderMesh.new(), teal, Vector3(0, 0.03, 0.27), Vector3(PI / 2, 0, 0))
	(nozzle.mesh as CylinderMesh).top_radius = 0.035
	(nozzle.mesh as CylinderMesh).bottom_radius = 0.05
	(nozzle.mesh as CylinderMesh).height = 0.09
	var rim := _part(root, TorusMesh.new(), gold, Vector3(0, 0.03, 0.315), Vector3(PI / 2, 0, 0))
	(rim.mesh as TorusMesh).inner_radius = 0.03
	(rim.mesh as TorusMesh).outer_radius = 0.045
	var tank := _part(root, SphereMesh.new(), _glass(), Vector3(0, 0.11, 0.08), Vector3.ZERO)
	(tank.mesh as SphereMesh).radius = 0.055
	(tank.mesh as SphereMesh).height = 0.11
	var grip := _part(root, BoxMesh.new(), pink, Vector3(0, -0.05, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	var star := MeshInstance3D.new()
	star.mesh = StarBubble.star_mesh()
	star.material_override = gold
	star.scale = Vector3.ONE * 0.07
	star.position = Vector3(0.062, 0.03, 0.12)
	star.rotation = Vector3(0, PI / 2, 0)
	root.add_child(star)
	var star2 := star.duplicate() as MeshInstance3D
	star2.position.x = -0.062
	root.add_child(star2)
	if colour == "clockwork":
		# Dash's tinkering: a little clock face on the tank, ticking, and a winding key at the back
		var dial := _part(root, CylinderMesh.new(), _mat(Color(1.0, 0.95, 0.85), 0.3), Vector3(0, 0.11, 0.135),
			Vector3(PI / 2, 0, 0))
		(dial.mesh as CylinderMesh).top_radius = 0.03
		(dial.mesh as CylinderMesh).bottom_radius = 0.03
		(dial.mesh as CylinderMesh).height = 0.008
		for k in 2:
			var hand := _part(root, BoxMesh.new(), _mat(Color(0.2, 0.12, 0.25), 0.4), Vector3(0, 0.11, 0.14),
				Vector3(0, 0, 0.6 + k * 2.2))
			(hand.mesh as BoxMesh).size = Vector3(0.004, 0.045 - k * 0.015, 0.003)
		var key := _part(root, TorusMesh.new(), gold, Vector3(0, 0.03, -0.09), Vector3(0, PI / 2, 0))
		(key.mesh as TorusMesh).inner_radius = 0.012
		(key.mesh as TorusMesh).outer_radius = 0.025
	return root


static func _part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi


static func _mat(c: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func _glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 1.0, 0.95, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.4, 0.9, 1.0)
	m.emission_energy_multiplier = 0.6
	m.roughness = 0.05
	return m


# ----------------------------------------------------------------------------- her arm
class PopperArm extends SkeletonModifier3D:
	# After her animation, swings her right arm (upper arm, forearm, hand) out straight to point where the bubbles
	# go. `influence` blends it in and out, so the arm eases up and back down.
	#
	# On a ride she shoots with her whole body, so it doesn't look like only an arm moving on a still skater: her
	# spine and chest twist towards the shot and her head turns to look at it, her left arm swings out for balance,
	# and each shot kicks her back a little (a big bubble more). All of it is turned in the skeleton's own space, so
	# it fits every body (they share the same bones) whichever way the bones point, and the skate pose underneath
	# (a grind's crouch, a flip, a grab) carries on. The arm eases round to a new direction rather than snapping, so
	# it follows through on grinds and mid-flip. Steering and the skate physics never see any of it.
	const EASE := 0.15                    # seconds the ride pose takes to blend in or out
	const FOLLOW := 18.0                  # how quickly the arm swings round to a new direction (per second)
	# Radians she twists at most (spine, chest and head together). Riding side-on, a shot straight ahead is about a
	# quarter turn round, and her popper hand is on the far side: twisting nearly all the way lets that arm reach
	# out in front of her instead of across her chest.
	const TWIST_MAX := 1.5
	const TWIST_SPLIT := [0.4, 0.35, 0.25]    # how much of the twist the spine, the chest and the head each take
	const KICK_TIME := 0.25               # seconds a shot's kick back lasts
	const KICK_LEAN := 0.14               # radians she leans back on a shot (twice that for a big bubble)

	var popper: StarPopper
	var hand_at := Vector3.ZERO           # where it last put her hand, and which way her arm went (tests read them)
	var points := Vector3.ZERO
	var ride_weight := 0.0                # 0..1: how much of the whole-body ride pose is on (eases with EASE)
	var twist := 0.0                      # how far round she's twisted right now, radians (tests read it)
	var chest_turned := 0.0               # radians the ride pose turned her chest, and her left arm, last time
	var left_arm_turned := 0.0            # (tests read them: the skeleton keeps its own poses between frames)
	var lean := 0.0                       # radians a shot's kick leans her back right now
	var _dir := Vector3.ZERO              # where the arm points now, in the world (eases towards popper.arm_dir())
	var _kick := 0.0                      # 1 straight after a shot, down to 0 over KICK_TIME
	var _kick_size := 1.0
	var _was_off := true                  # it wasn't showing last time: start the arm where it should point

	func kick(big: bool) -> void:
		_kick = 1.0
		_kick_size = 2.0 if big else 1.0

	func _process_modification_with_delta(delta: float) -> void:
		var skel := get_skeleton()
		if skel == null or popper == null or popper.player == null:
			return
		var ua := skel.find_bone("upper_arm.R")
		var fa := skel.find_bone("forearm.R")
		var hand := skel.find_bone("hand.R")
		if ua < 0 or fa < 0 or hand < 0:
			return
		_kick = maxf(_kick - delta / KICK_TIME, 0.0)
		var riding: bool = Game.riding and popper.player.skate.can_shoot()
		ride_weight = move_toward(ride_weight, 1.0 if riding else 0.0, delta / EASE)
		# Ease the arm round to where it should point, so a new target or a turn mid-flip doesn't snap it
		var want := popper.arm_dir()
		if _dir == Vector3.ZERO or _was_off:
			_dir = want
		else:
			_dir = _dir.slerp(want, 1.0 - exp(-FOLLOW * delta)).normalized()
		_was_off = influence < 0.01
		var world_dir := _dir
		var to_skel := skel.global_transform.basis.inverse()
		var d := (to_skel * world_dir).normalized()
		var kick := _kick * _kick * _kick_size        # eased: a sharp kick that settles
		if ride_weight > 0.0:
			_ride_pose(skel, d, kick)
		else:
			twist = 0.0
		# The arm lifts a touch with the kick
		d = (d + Vector3.UP * 0.12 * kick).normalized()
		# The forearm and hand go straight on from the upper arm, as they are in the model's rest pose
		skel.set_bone_pose_rotation(fa, skel.get_bone_rest(fa).basis.get_rotation_quaternion())
		skel.set_bone_pose_rotation(hand, skel.get_bone_rest(hand).basis.get_rotation_quaternion())
		_point(skel, ua, hand, d)
		var hand_g := skel.get_bone_global_pose(hand)
		hand_at = skel.global_transform * hand_g.origin
		points = (hand_at - skel.global_transform * skel.get_bone_global_pose(ua).origin).normalized()
		popper.place_prop(skel.global_transform * hand_g, world_dir)

	func _ride_pose(skel: Skeleton3D, d: Vector3, kick: float) -> void:
		# The twist, head turn, balancing arm and kick back, in the skeleton's space (the model faces +Z)
		var flat := Vector3(d.x, 0.0, d.z)
		var yaw := 0.0
		if flat.length() > 0.05:
			yaw = clampf(atan2(flat.x, flat.z), -TWIST_MAX, TWIST_MAX)
		twist = yaw * ride_weight
		var fwd := Vector3(sin(twist), 0.0, cos(twist))
		var lean_axis := fwd.cross(Vector3.UP).normalized()     # turning about this leans her back (or looks up)
		var chest := skel.find_bone("chest")
		var chest_was := skel.get_bone_global_pose(chest).basis.get_rotation_quaternion() if chest >= 0 else Quaternion()
		var parts := ["spine", "chest", "head"]
		for k in parts.size():
			var b := skel.find_bone(parts[k])
			if b < 0:
				continue
			var q := Quaternion(Vector3.UP, twist * float(TWIST_SPLIT[k]))
			if parts[k] == "chest":
				lean = KICK_LEAN * kick * ride_weight
				q = Quaternion(lean_axis, lean) * q
			elif parts[k] == "head":
				# Look up or down at it too, a little
				var up_down := clampf(asin(clampf(d.y, -1.0, 1.0)), -0.6, 0.6) * 0.6
				q = Quaternion(lean_axis, up_down * ride_weight) * q
			_turn(skel, b, q)
		# The other arm out to the side for balance: out, a bit down and a bit behind her
		if chest < 0:
			return
		chest_turned = chest_was.angle_to(skel.get_bone_global_pose(chest).basis.get_rotation_quaternion())
		var ual := skel.find_bone("upper_arm.L")
		var fal := skel.find_bone("forearm.L")
		var hl := skel.find_bone("hand.L")
		if ual < 0 or hl < 0:
			return
		var side := skel.get_bone_global_pose(ual).origin - skel.get_bone_global_pose(chest).origin
		side.y = 0.0
		if side.length() < 0.001:
			return
		var out := (side.normalized() * 0.8 + Vector3.DOWN * 0.5 - fwd * 0.3).normalized()
		if fal >= 0:
			# A softly bent elbow: halfway between the animation's and straight
			var now := skel.get_bone_pose_rotation(fal)
			skel.set_bone_pose_rotation(fal, now.slerp(skel.get_bone_rest(fal).basis.get_rotation_quaternion(), 0.6))
		var before := skel.get_bone_pose_rotation(ual)
		_point(skel, ual, hl, out)
		skel.set_bone_pose_rotation(ual, before.slerp(skel.get_bone_pose_rotation(ual), ride_weight))
		left_arm_turned = before.angle_to(skel.get_bone_pose_rotation(ual))

	func _turn(skel: Skeleton3D, bone: int, q: Quaternion) -> void:
		# Turns a bone by q, given in the skeleton's space (its children go with it)
		var g := skel.get_bone_global_pose(bone)
		var parent := skel.get_bone_parent(bone)
		var parent_g := skel.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
		var new_g := Basis(q) * g.basis.orthonormalized()
		var local := parent_g.basis.orthonormalized().inverse() * new_g
		skel.set_bone_pose_rotation(bone, local.get_rotation_quaternion())

	func _point(skel: Skeleton3D, upper: int, end: int, d: Vector3) -> void:
		# Turns the upper arm so `end` (the hand) ends up along d from the shoulder
		var g := skel.get_bone_global_pose(upper)
		var along := skel.get_bone_global_pose(end).origin - g.origin
		if along.length() < 0.001:
			return
		_turn(skel, upper, Quaternion(along.normalized(), d))


# ----------------------------------------------------------------------------- crosshair
class Crosshair extends Control:
	# A soft ring with a dot in the middle of the screen while aiming; it turns pink on an enemy, and a gold arc
	# fills round it as a big bubble charges.
	var popper: StarPopper

	func _draw() -> void:
		if popper == null:
			return
		var c := size / 2.0
		var r := 15.0 * Settings.text_scale
		var col := Color(1.0, 0.55, 0.85) if popper._on_target else Color(0.95, 0.95, 1.0)
		var shadow := Color(0.1, 0.05, 0.2, 0.6)
		var w := 3.0 if Settings.high_contrast else 2.0
		draw_arc(c, r, 0.0, TAU, 40, shadow, w + 2.0, true)
		draw_arc(c, r, 0.0, TAU, 40, col, w, true)
		draw_circle(c, 3.5, shadow)
		draw_circle(c, 2.5, col)
		if popper.charge > 0.0:
			var full := popper.charge >= 1.0
			draw_arc(c, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * popper.charge, 40,
				Color(1.0, 0.85, 0.3) if not full else Color(0.4, 1.0, 0.9), 4.0, true)
