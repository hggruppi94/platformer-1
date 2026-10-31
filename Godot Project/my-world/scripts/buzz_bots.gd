class_name BuzzBots
extends Node3D

# The Buzz Bots (scripts/arsenal.gd): Shoot sends out three little round helper bots that buzz in a ring round her
# head for a while. Every so often each bot looks for an enemy in reach and blows a star bubble at it (the bubbles
# are StarBubbles from the Buzz Bots, so their pops are points for them and the mods on the Buzz Bots work on them:
# Bounce, Freeze, and Split gives two more bots). The Buzz Swarm (V5) is five bots, quicker. Shooting again while
# they're out sends a fresh lot. Nothing gets hurt: they only blow bubbles.

const RING := 1.3                         # metres round her
const HEIGHT := 1.5
const SPIN := 2.2                         # how quickly they go round (radians a second)
const YELLOW := Color(1.0, 0.85, 0.3)

var player: Node3D
var time := 12.0
var reach := 7.0
var rate := 1.4                           # seconds between each bot's bubbles
var count := 3
var shots := 0                            # tests read it
var bots: Array[Node3D] = []
var _t := 0.0
var _cool: Array[float] = []


static func deploy(parent: Node, by: Node3D, stats: Dictionary) -> BuzzBots:
	for old in parent.get_tree().get_nodes_in_group("buzz_bots"):
		(old as BuzzBots).finish()
	var b := BuzzBots.new()
	b.player = by
	b.time = float(stats.get("time", 12.0))
	b.reach = float(stats.get("radius", 7.0))
	b.rate = float(stats.get("rate", 1.4))
	b.count = int(stats.get("bots", 3))
	b.set_meta("gadget", "buzz")
	parent.add_child(b)
	b.global_position = by.global_position
	return b


func _ready() -> void:
	name = "BuzzBots"
	add_to_group("buzz_bots")
	for i in count:
		var bot := build_bot()
		add_child(bot)
		bots.append(bot)
		_cool.append(rate * (0.3 + 0.7 * i / maxf(count, 1)))     # they take turns
		bot.scale = Vector3.ONE * 0.1
		bot.create_tween().tween_property(bot, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("buzz", -4.0, 0.1)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_t += delta
	time -= delta
	global_position = player.global_position
	for i in bots.size():
		var a := _t * SPIN + TAU * i / bots.size()
		var bot := bots[i]
		bot.position = Vector3(cos(a) * RING, HEIGHT + sin(_t * 5.0 + i) * 0.12, sin(a) * RING)
		bot.rotation.y = -a
		(bot.get_node("Wings") as Node3D).scale.y = 0.6 + 0.4 * absf(sin(_t * 40.0 + i))      # buzzing wings
		_cool[i] -= delta
		if _cool[i] <= 0.0:
			_cool[i] = rate
			_shoot(bot)
	if time <= 0.0:
		finish()


func _shoot(bot: Node3D) -> void:
	var e := _nearest(bot.global_position)
	if e == null:
		return
	var to := e.global_position + Vector3(0, 0.45 * float(e.get("size") if e.get("size") != null else 1.0), 0)
	var b := StarBubble.fire(get_parent(), bot.global_position, (to - bot.global_position).normalized(),
		player as CollisionObject3D, false, 0.8)
	b.set_meta("gadget", "buzz")
	shots += 1
	Audio.play_at("bloop", bot.global_position, -10.0, 0.25)


func _nearest(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e is Node3D or e.get("defeated") == true or not (e as Node3D).is_visible_in_tree():
			continue
		var d := (e as Node3D).global_position.distance_to(from)
		if d < best_d:
			best = e
			best_d = d
	return best


func finish() -> void:
	if is_queued_for_deletion():
		return
	for bot in bots:
		Fx.burst(get_parent(), bot.global_position, YELLOW, 6, 0.04, 2.0, -1.0, 0.4)
	queue_free()


static func build_bot() -> Node3D:
	# A round little bot: a gold ball with a teal visor and a happy face, two clear buzzing wings and an aerial
	var root := Node3D.new()
	root.name = "Bot"
	var gold := StarPopper._mat(YELLOW, 0.35, 0.4)
	var teal := StarPopper._mat(Color(0.3, 0.9, 0.82), 0.2)
	teal.emission_enabled = true
	teal.emission = Color(0.3, 0.9, 0.82)
	teal.emission_energy_multiplier = 0.6
	var ball := StarPopper._part(root, SphereMesh.new(), gold, Vector3.ZERO, Vector3.ZERO)
	(ball.mesh as SphereMesh).radius = 0.13
	(ball.mesh as SphereMesh).height = 0.26
	var visor := StarPopper._part(root, SphereMesh.new(), teal, Vector3(0, 0.02, 0.07), Vector3.ZERO)
	(visor.mesh as SphereMesh).radius = 0.08
	(visor.mesh as SphereMesh).height = 0.1
	var aerial := StarPopper._part(root, CylinderMesh.new(), gold, Vector3(0, 0.17, 0), Vector3.ZERO)
	(aerial.mesh as CylinderMesh).top_radius = 0.008
	(aerial.mesh as CylinderMesh).bottom_radius = 0.008
	(aerial.mesh as CylinderMesh).height = 0.08
	var tip := StarPopper._part(root, SphereMesh.new(), StarPopper._mat(Color(1.0, 0.5, 0.78), 0.4),
		Vector3(0, 0.22, 0), Vector3.ZERO)
	(tip.mesh as SphereMesh).radius = 0.025
	(tip.mesh as SphereMesh).height = 0.05
	var wings := Node3D.new()
	wings.name = "Wings"
	root.add_child(wings)
	var glass := StarPopper._glass()
	for side in [-1, 1]:
		var w := StarPopper._part(wings, SphereMesh.new(), glass, Vector3(side * 0.14, 0.08, -0.03), Vector3(0, 0, side * 0.5))
		(w.mesh as SphereMesh).radius = 0.08
		(w.mesh as SphereMesh).height = 0.04
	return root


static func build_prop() -> Node3D:
	# In her hand: a gold launcher with a bot sitting on top, ready to go. Nozzle towards +Z.
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "buzz")
	var lilac := StarPopper._mat(Color(0.62, 0.5, 0.95), 0.4)
	var gold := StarPopper._mat(YELLOW, 0.35, 0.4)
	var body := StarPopper._part(root, BoxMesh.new(), lilac, Vector3(0, 0.02, 0.1), Vector3.ZERO)
	(body.mesh as BoxMesh).size = Vector3(0.1, 0.08, 0.26)
	var ring := StarPopper._part(root, TorusMesh.new(), gold, Vector3(0, 0.07, 0.12), Vector3.ZERO)
	(ring.mesh as TorusMesh).inner_radius = 0.05
	(ring.mesh as TorusMesh).outer_radius = 0.07
	var grip := StarPopper._part(root, BoxMesh.new(), StarPopper._mat(Color(1.0, 0.5, 0.78), 0.5),
		Vector3(0, -0.06, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	var bot := build_bot()
	bot.position = Vector3(0, 0.14, 0.12)
	bot.scale = Vector3.ONE * 0.6
	root.add_child(bot)
	return root
