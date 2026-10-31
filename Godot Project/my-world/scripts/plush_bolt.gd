class_name PlushBolt
extends StarBubble

# One shot from the Plushinator (scripts/arsenal.gd): a fluffy pink pompom that flies like a bubble and turns what it
# hits into a soft toy for a few seconds (Arsenal.plush): the enemy sits still as a cuddly plushie, and one touch of
# anything (a bubble, a splash, a stomp of a bubble...) pops it for a sparkle or two (Arsenal.on_pop). The Plush Party
# (V5) turns everyone close round it into plushies too. What can't be a plushie (the Gloop King, a Crocodillo rolled
# up in its shell, an ammo crate) just gets a bubble's worth of a hit.
# The mods work as they do on bubbles (Bounce, Freeze), and Split fires two (StarPopper.shoot).

const PINK := Color(1.0, 0.72, 0.85)

var plush_time := 4.0
var reach := 0.6                          # everyone this close to what it hits goes plush too
var plushed: Array[Node] = []             # tests read it


static func fire_bolt(parent: Node, from: Vector3, dir: Vector3, by: CollisionObject3D, stats: Dictionary) -> PlushBolt:
	var b := PlushBolt.new()
	b.power = 1
	b.velocity = dir.normalized() * SPEED * 0.85
	b.shooter = by
	b.color = PINK
	b.size_scale = float(stats.get("scale", 1.0))
	b.plush_time = float(stats.get("time", 4.0))
	b.reach = float(stats.get("radius", 0.6))
	b.set_meta("gadget", "plush")
	parent.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	super()
	name = "PlushBolt"
	add_to_group("plush_bolts")
	# Fluff: a few soft pink and white puffs round it
	var fluff := StarPopper._mat(Color(1.0, 0.85, 0.92), 1.0)
	for k in 6:
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = RADIUS * 0.55 * size_scale
		s.height = s.radius * 2.0
		s.radial_segments = 8
		s.rings = 4
		puff.mesh = s
		puff.material_override = fluff
		var a := TAU * k / 6.0
		puff.position = Vector3(cos(a), sin(a * 2.0) * 0.5, sin(a)) * RADIUS * 0.8 * size_scale
		add_child(puff)


func _hit_target(target: Node, at: Vector3) -> String:
	if not Arsenal.can_plush(target):
		return super(target, at)
	Arsenal.plush(target as Node3D, plush_time)
	plushed.append(target)
	if reach > 1.0:
		# The Plush Party: everyone round it is a plushie too
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != target and e is Node3D and Arsenal.can_plush(e) \
					and (e as Node3D).global_position.distance_to((target as Node3D).global_position) < reach:
				Arsenal.plush(e as Node3D, plush_time)
				plushed.append(e)
	Arsenal.add_xp("plush")
	return "hit"


static func build_toy(size := 1.0) -> Node3D:
	# A plushie: a round pink bear-ish toy sitting on the ground, with ears, a lilac tummy, button eyes and a gold
	# heart. About 0.9 m tall for a normal-sized enemy.
	var root := Node3D.new()
	var pink := StarPopper._mat(PINK, 1.0)
	var lilac := StarPopper._mat(Color(0.8, 0.7, 1.0), 1.0)
	var dark := StarPopper._mat(Color(0.15, 0.08, 0.2), 0.3)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.3, 0.5)
	var body := StarPopper._part(root, SphereMesh.new(), pink, Vector3(0, 0.3, 0), Vector3.ZERO)
	(body.mesh as SphereMesh).radius = 0.3
	(body.mesh as SphereMesh).height = 0.58
	var tummy := StarPopper._part(root, SphereMesh.new(), lilac, Vector3(0, 0.28, 0.17), Vector3.ZERO)
	(tummy.mesh as SphereMesh).radius = 0.17
	(tummy.mesh as SphereMesh).height = 0.3
	var head := StarPopper._part(root, SphereMesh.new(), pink, Vector3(0, 0.7, 0), Vector3.ZERO)
	(head.mesh as SphereMesh).radius = 0.22
	(head.mesh as SphereMesh).height = 0.42
	for side in [-1, 1]:
		var ear := StarPopper._part(root, SphereMesh.new(), pink, Vector3(side * 0.16, 0.9, -0.02), Vector3.ZERO)
		(ear.mesh as SphereMesh).radius = 0.08
		(ear.mesh as SphereMesh).height = 0.16
		var inner := StarPopper._part(root, SphereMesh.new(), lilac, Vector3(side * 0.16, 0.9, 0.04), Vector3.ZERO)
		(inner.mesh as SphereMesh).radius = 0.045
		(inner.mesh as SphereMesh).height = 0.06
		var eye := StarPopper._part(root, SphereMesh.new(), dark, Vector3(side * 0.08, 0.74, 0.19), Vector3.ZERO)
		(eye.mesh as SphereMesh).radius = 0.03
		(eye.mesh as SphereMesh).height = 0.06
		var paw := StarPopper._part(root, SphereMesh.new(), pink, Vector3(side * 0.27, 0.35, 0.08), Vector3.ZERO)
		(paw.mesh as SphereMesh).radius = 0.09
		(paw.mesh as SphereMesh).height = 0.18
		var foot := StarPopper._part(root, SphereMesh.new(), pink, Vector3(side * 0.14, 0.07, 0.17), Vector3.ZERO)
		(foot.mesh as SphereMesh).radius = 0.09
		(foot.mesh as SphereMesh).height = 0.14
	var snout := StarPopper._part(root, SphereMesh.new(), lilac, Vector3(0, 0.66, 0.19), Vector3.ZERO)
	(snout.mesh as SphereMesh).radius = 0.07
	(snout.mesh as SphereMesh).height = 0.1
	var heart := MeshInstance3D.new()
	heart.mesh = StarBubble.star_mesh()
	heart.material_override = gold
	heart.scale = Vector3.ONE * 0.12
	heart.position = Vector3(0, 0.32, 0.34)
	root.add_child(heart)
	root.scale = Vector3.ONE * size
	return root


static func build_prop() -> Node3D:
	# The Plushinator in her hand: a soft pink blaster with a cloud-white puff on the end and a gold heart (star) on
	# the side. Nozzle towards +Z.
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "plush")
	var pink := StarPopper._mat(PINK, 0.8)
	var white := StarPopper._mat(Color(1.0, 0.95, 0.98), 1.0)
	var lilac := StarPopper._mat(Color(0.62, 0.5, 0.95), 0.4)
	var gold := StarPopper._mat(Color(1.0, 0.82, 0.3), 0.25, 0.6)
	var body := StarPopper._part(root, CapsuleMesh.new(), pink, Vector3(0, 0.03, 0.1), Vector3(PI / 2, 0, 0))
	(body.mesh as CapsuleMesh).radius = 0.065
	(body.mesh as CapsuleMesh).height = 0.26
	for k in 4:
		var puff := StarPopper._part(root, SphereMesh.new(), white,
			Vector3(cos(k * 1.6) * 0.04, 0.03 + sin(k * 1.6) * 0.04, 0.26), Vector3.ZERO)
		(puff.mesh as SphereMesh).radius = 0.045
		(puff.mesh as SphereMesh).height = 0.09
	var grip := StarPopper._part(root, BoxMesh.new(), lilac, Vector3(0, -0.06, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	for side in [-1, 1]:
		var star := MeshInstance3D.new()
		star.mesh = StarBubble.star_mesh()
		star.material_override = gold
		star.scale = Vector3.ONE * 0.07
		star.position = Vector3(side * 0.068, 0.03, 0.1)
		star.rotation = Vector3(0, PI / 2, 0)
		root.add_child(star)
	return root
