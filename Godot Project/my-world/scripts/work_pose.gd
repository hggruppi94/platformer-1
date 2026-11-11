extends SkeletonModifier3D

# Working poses for people at their jobs (scripts/work_job.gd): reaching up to a high shelf, kneeling to plant, stirring
# a bowl, sweeping, hammering, carrying a crate... None of the bodies have animations for those, and every body in the
# game (the Earth kid, Nina, Bramble, Pip, Mr. Palmer, the cat, bunny and dino...) has the same named arm and leg
# bones, so the poses are made here in code, on top of whatever the AnimationPlayer is playing:
#
# - each hand is put on a target with a two-bone reach (upper arm and forearm), the elbow bending down and out;
# - the hips can drop, with each leg bending at the knee so the feet stay where they were (crouching, kneeling);
# - the spine can lean forward over the work.
#
# Targets are in the body's own frame (+Y up, +Z the way they face, x out to that arm's own side), measured from the
# shoulder in arm lengths, so one pose fits a little kid and a tall grown-up alike. A pose can move with time (`t`),
# so stirring goes round and a hammer goes up and down.
#
# `influence` (SkeletonModifier3D's own) blends it in and out: set `pose` and it eases in; set it to "" and it eases
# out, then the modifier switches itself off.

const EASE := 4.0                       # how fast a pose blends in and out (influence per second)

var pose := ""                          # what they're doing: a name from targets()
var t := 0.0                            # seconds into the pose, for the ones that move

var _side := 1.0                        # +1 if the left arm is on +X in the skeleton's space
var _ready_bones := false
var _bones := {}                        # name -> index


func _ready() -> void:
	influence = 0.0
	active = false


func set_pose(p: String) -> void:
	if p != pose:
		pose = p
		t = 0.0
	if p != "":
		active = true


func _process(delta: float) -> void:
	t += delta
	var goal := 1.0 if pose != "" else 0.0
	influence = move_toward(influence, goal, EASE * delta)
	if influence <= 0.0 and pose == "":
		active = false


func _find() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for b in ["hips", "spine", "chest", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R",
			"thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
		_bones[b] = skel.find_bone(b)
	var l: int = _bones["upper_arm.L"]
	if l >= 0:
		_side = 1.0 if skel.get_bone_global_rest(l).origin.x >= 0.0 else -1.0
	_ready_bones = true


# -----------------------------------------------------------------------------
# The poses
# -----------------------------------------------------------------------------
static func names() -> Array:
	return ["reach_high", "reach_both", "shelve", "low_shelf", "kneel", "bend", "water", "stir", "knead", "wipe",
		"dust_high", "sweep", "hammer", "saw", "carry", "carry_low", "write", "stamp", "climb", "hand_out", "arrange",
		"read", "wash", "flip", "rake"]


func targets(p: String, time: float) -> Dictionary:
	# {"L": Vector3 or null, "R": ..., "lean": radians forward, "drop": hips down in leg lengths}. Hands are relative to
	# their shoulder in arm lengths: x outward, y up, z forward. A missing hand keeps its animation.
	var s := sin(time * TAU * 0.5)
	var fast := sin(time * TAU * 1.6)
	match p:
		"reach_high":                                   # taking something off a high shelf: up on tiptoe, right hand up
			return {"R": Vector3(0.0, 0.92 + 0.04 * s, 0.35), "L": Vector3(0.25, -0.55, 0.25), "lean": -0.08}
		"reach_both":                                   # both hands up (hanging a sign, tending a lamp)
			return {"R": Vector3(0.05, 0.9, 0.38 + 0.04 * s), "L": Vector3(0.05, 0.9, 0.38 - 0.04 * s), "lean": -0.06}
		"shelve":                                       # putting something on a shelf at chest height
			return {"R": Vector3(-0.05, 0.25 + 0.06 * s, 0.9), "L": Vector3(0.1, -0.15, 0.6), "lean": 0.08}
		"low_shelf":                                    # crouched at a bottom shelf
			return {"R": Vector3(-0.05, -0.55 + 0.05 * s, 0.75), "L": Vector3(0.15, -0.65, 0.55), "lean": 0.35, "drop": 0.35}
		"kneel":                                        # planting: down low, hands in the soil, digging in turn
			return {"R": Vector3(-0.05, -0.85 + 0.1 * maxf(fast, 0.0), 0.65), "L": Vector3(-0.05, -0.85 + 0.1 * maxf(-fast, 0.0), 0.6),
				"lean": 0.55, "drop": 0.5}
		"bend":                                         # bent over pulling weeds or picking something up
			return {"R": Vector3(-0.05, -1.0 + 0.12 * maxf(s, 0.0), 0.55), "L": Vector3(0.05, -0.95, 0.45), "lean": 0.75, "drop": 0.12}
		"water":                                        # a watering can held out, swinging gently along the bed
			return {"R": Vector3(0.05 + 0.15 * s, -0.25, 0.85), "L": Vector3(0.3, -0.6, 0.2), "lean": 0.12}
		"stir":                                         # a bowl in the left arm, the right hand going round in it
			return {"R": Vector3(-0.2 + 0.12 * cos(time * 5.0), -0.38, 0.62 + 0.1 * sin(time * 5.0)),
				"L": Vector3(-0.25, -0.42, 0.5), "lean": 0.12}
		"knead":                                        # both hands pushing the dough away and pulling it back
			var k := absf(sin(time * 2.6))
			return {"R": Vector3(-0.15, -0.5 + 0.12 * k, 0.55 + 0.2 * k), "L": Vector3(-0.15, -0.5 + 0.12 * k, 0.55 + 0.2 * k),
				"lean": 0.3}
		"wipe":                                         # wiping a counter or a table round and round
			return {"R": Vector3(-0.1 + 0.22 * cos(time * 4.0), -0.55, 0.75 + 0.15 * sin(time * 4.0)), "L": Vector3(0.2, -0.55, 0.55),
				"lean": 0.35}
		"dust_high":                                    # a feather duster flicking over things at head height
			return {"R": Vector3(-0.05 + 0.2 * cos(time * 6.0), 0.4 + 0.15 * sin(time * 6.0), 0.8), "L": Vector3(0.25, -0.6, 0.2)}
		"sweep":                                        # a broom swinging across in front, hands one above the other
			return {"R": Vector3(-0.05 + 0.35 * s, -0.75, 0.5), "L": Vector3(-0.25 - 0.35 * s, -0.3, 0.45), "lean": 0.2}
		"hammer":                                       # a hammer coming down on a nail held in the left hand
			var h := pow(absf(sin(time * 3.2)), 3.0)
			return {"R": Vector3(-0.05, -0.45 + 0.6 * h, 0.55 + 0.1 * h), "L": Vector3(-0.15, -0.55, 0.6), "lean": 0.3}
		"saw":                                          # sawing a plank across a sawhorse
			return {"R": Vector3(-0.15, -0.5, 0.45 + 0.3 * s), "L": Vector3(0.05, -0.6, 0.6), "lean": 0.4}
		"carry":                                        # carrying something in both hands in front (a tray, a box)
			return {"R": Vector3(-0.25, -0.35, 0.55), "L": Vector3(-0.25, -0.35, 0.55)}
		"carry_low":                                    # a heavy crate, low down
			return {"R": Vector3(-0.15, -0.55, 0.5), "L": Vector3(-0.15, -0.55, 0.5), "lean": -0.1}
		"write":                                        # writing at a desk or on a clipboard
			return {"R": Vector3(-0.2 + 0.05 * sin(time * 9.0), -0.48 + 0.02 * fast, 0.62), "L": Vector3(-0.15, -0.5, 0.55), "lean": 0.25}
		"stamp":                                        # stamping library cards: thump, thump
			var st := pow(absf(sin(time * 2.4)), 2.0)
			return {"R": Vector3(-0.15, -0.5 + 0.3 * st, 0.6), "L": Vector3(-0.1, -0.52, 0.55), "lean": 0.2}
		"climb":                                        # hand over hand up a ladder (the legs walk)
			return {"R": Vector3(-0.05, 0.55 + 0.25 * sin(time * 4.0), 0.4), "L": Vector3(-0.05, 0.55 - 0.25 * sin(time * 4.0), 0.4)}
		"hand_out":                                     # holding something out to someone (a flyer, a bouquet, a plate)
			return {"R": Vector3(0.0, -0.1 + 0.05 * s, 0.95), "L": Vector3(-0.2, -0.4, 0.5)}
		"arrange":                                      # arranging flowers or things on a stall, hands busy in front
			return {"R": Vector3(-0.05 + 0.15 * s, -0.35 + 0.1 * fast, 0.75), "L": Vector3(0.0 - 0.15 * s, -0.4, 0.7), "lean": 0.15}
		"read":                                         # a book open in both hands
			return {"R": Vector3(-0.3, -0.3, 0.5), "L": Vector3(-0.3, -0.3, 0.5), "lean": 0.1}
		"wash":                                         # washing something big (the fire truck): big circles at chest height
			return {"R": Vector3(-0.05 + 0.3 * cos(time * 2.5), 0.05 + 0.25 * sin(time * 2.5), 0.85), "L": Vector3(0.25, -0.5, 0.35)}
		"flip":                                         # flipping pancakes on the griddle
			var f := pow(maxf(sin(time * 2.0), 0.0), 4.0)
			return {"R": Vector3(-0.1, -0.4 + 0.3 * f, 0.7), "L": Vector3(0.1, -0.45, 0.6), "lean": 0.15}
		"rake":                                         # raking leaves (or soil) towards them
			return {"R": Vector3(-0.1, -0.55, 0.45 + 0.3 * s), "L": Vector3(-0.2, -0.2, 0.4 + 0.25 * s), "lean": 0.25}
	return {}


# -----------------------------------------------------------------------------
# Putting the body in the pose (after the animation, every frame)
# -----------------------------------------------------------------------------
func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null or pose == "":
		return
	if not _ready_bones:
		_find()
	var want := targets(pose, t)
	if want.is_empty():
		return
	var drop := float(want.get("drop", 0.0))
	var lean := float(want.get("lean", 0.0))
	# Where the feet are before anything moves: crouching keeps them there
	var feet := {}
	for side in ["L", "R"]:
		var f: int = _bones["foot." + side]
		if f >= 0:
			feet[side] = skel.get_bone_global_pose(f)
	var hips: int = _bones["hips"]
	if drop > 0.0 and hips >= 0:
		var hp := skel.get_bone_global_pose(hips)
		hp.origin.y -= drop * _leg_length(skel)
		skel.set_bone_global_pose(hips, hp)
	var spine: int = _bones["spine"]
	if absf(lean) > 0.001 and spine >= 0:
		var sp := skel.get_bone_global_pose(spine)
		var turn := Basis(Vector3.RIGHT, lean)
		sp.basis = turn * sp.basis
		skel.set_bone_global_pose(spine, sp)
	for side in ["L", "R"]:
		var target = want.get(side)
		if target is Vector3:
			_reach(skel, side, target)
	if drop > 0.0:
		for side in ["L", "R"]:
			if feet.has(side):
				_kneel_leg(skel, side, feet[side])


func _leg_length(skel: Skeleton3D) -> float:
	var th: int = _bones["thigh.L"]
	var sh: int = _bones["shin.L"]
	var ft: int = _bones["foot.L"]
	if th < 0 or sh < 0 or ft < 0:
		return 0.5
	var a := skel.get_bone_global_rest(th).origin
	var b := skel.get_bone_global_rest(sh).origin
	var c := skel.get_bone_global_rest(ft).origin
	return a.distance_to(b) + b.distance_to(c)


func _reach(skel: Skeleton3D, side: String, target: Vector3) -> void:
	# Upper arm and forearm swung so the hand lands on the target, the elbow bending down and out to its own side
	var up: int = _bones["upper_arm." + side]
	var fore: int = _bones["forearm." + side]
	var hand: int = _bones["hand." + side]
	if up < 0 or fore < 0 or hand < 0:
		return
	var out := _side * (1.0 if side == "L" else -1.0)        # +X or -X: that arm's own side
	var a := skel.get_bone_global_pose(up).origin
	var l1 := a.distance_to(skel.get_bone_global_pose(fore).origin)
	var l2 := skel.get_bone_global_pose(fore).origin.distance_to(skel.get_bone_global_pose(hand).origin)
	var reach := l1 + l2
	var goal := a + Vector3(target.x * out, target.y, target.z) * reach
	var pole := Vector3(out * 0.6, -1.0, -0.3)
	_two_bone(skel, up, fore, hand, goal, pole)


func _kneel_leg(skel: Skeleton3D, side: String, foot_was: Transform3D) -> void:
	# The hips came down: bend this leg at the knee (forward) so the foot stays on the ground where it was
	var th: int = _bones["thigh." + side]
	var sh: int = _bones["shin." + side]
	var ft: int = _bones["foot." + side]
	if th < 0 or sh < 0 or ft < 0:
		return
	_two_bone(skel, th, sh, ft, foot_was.origin, Vector3(0, 0.2, 1.0))
	var now := skel.get_bone_global_pose(ft)
	skel.set_bone_global_pose(ft, Transform3D(foot_was.basis, now.origin))


static func _turn(from: Vector3, to: Vector3) -> Basis:
	if from.length() < 0.0001 or to.length() < 0.0001:
		return Basis.IDENTITY
	var f := from.normalized()
	var g := to.normalized()
	if f.dot(g) > 0.99999:
		return Basis.IDENTITY
	if f.dot(g) < -0.99999:
		var axis := f.cross(Vector3.UP)
		if axis.length() < 0.001:
			axis = f.cross(Vector3.RIGHT)
		return Basis(axis.normalized(), PI)
	return Basis(Quaternion(f, g))


func _two_bone(skel: Skeleton3D, a_i: int, b_i: int, c_i: int, goal: Vector3, pole: Vector3) -> void:
	var a := skel.get_bone_global_pose(a_i)
	var b := skel.get_bone_global_pose(b_i)
	var c := skel.get_bone_global_pose(c_i)
	var l1 := a.origin.distance_to(b.origin)
	var l2 := b.origin.distance_to(c.origin)
	if l1 < 0.0001 or l2 < 0.0001:
		return
	var to_goal := goal - a.origin
	var d := clampf(to_goal.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var u := to_goal.normalized() if to_goal.length() > 0.0001 else Vector3.DOWN
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var high := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var v := pole - u * pole.dot(u)
	if v.length() < 0.0001:
		v = Vector3.FORWARD - u * Vector3.FORWARD.dot(u)
	v = v.normalized()
	var elbow := a.origin + u * along + v * high
	var end := a.origin + u * d
	# The upper bone: point it at the elbow
	var turn_a := _turn(b.origin - a.origin, elbow - a.origin)
	skel.set_bone_global_pose(a_i, Transform3D(turn_a * a.basis, a.origin))
	# The lower bone, from wherever the elbow now is: point it at the end
	var b2 := skel.get_bone_global_pose(b_i)
	var c2 := skel.get_bone_global_pose(c_i)
	var turn_b := _turn(c2.origin - b2.origin, end - b2.origin)
	skel.set_bone_global_pose(b_i, Transform3D(turn_b * b2.basis, b2.origin))
