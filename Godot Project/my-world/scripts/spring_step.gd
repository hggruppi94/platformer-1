extends Node

# Heather's Spring Step, the player's own: one of Glenmoor's two rewards (scripts/glenmoor.gd; the other is April
# Showers, scripts/showers.gd). Locked until Glenmoor's mended, like the other taught moves.
#
# No button of its own (every pad button's taken, and it's easier for small hands): jump again just as you land (within
# WINDOW seconds, or press Jump a moment before landing: the player's jump buffer counts) and you bounce higher, like a
# spring lamb. Keep it going and the third bound in a row is the biggest, with a flip (BOOSTS). Land and wait, or walk
# off a ledge, and it starts again from an ordinary jump.
# The player asks bound() for how much higher each ground jump goes (scenes/player/player.gd).

const WORLD := "glenmoor"
const WINDOW := 0.2                        # seconds after landing that a jump still counts as a Spring Step
const BOOSTS := [1.0, 1.3, 1.65]           # each jump in a row goes this much higher than an ordinary one
const PUFF := Color(1.0, 0.85, 0.9, 0.85)

var player: CharacterBody3D
var chain := 0                             # 0 an ordinary jump, 1 and 2 Spring Steps
var steps := 0                             # (for the tests: Spring Steps made)
var _landed_at := -10.0
var _was_floor := true
var _from_jump := false                    # was the hero in the air from a jump (not a fall off a ledge)?


func setup(p: CharacterBody3D) -> void:
	player = p


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func bound() -> float:
	# A jump off the ground: how much higher it goes than an ordinary one
	if not unlocked() or player == null:
		return 1.0
	if _from_jump and now() - _landed_at <= WINDOW:
		chain = mini(chain + 1, BOOSTS.size() - 1)
	else:
		chain = 0
	_from_jump = true
	if chain > 0:
		steps += 1
		var scene := player.get_parent()
		Juice.dust(scene, player.global_position - Vector3(0, 0.8, 0), 0.5 + chain * 0.3)
		Fx.burst(scene, player.global_position - Vector3(0, 0.6, 0), PUFF, 6 + chain * 4, 0.06, 2.0, 0.3, 0.6)
		Audio.play("boing", -6.0 + chain, 0.1)
		Juice.blip("chime", 1.0 + chain * 0.25, -10.0)
		if chain == BOOSTS.size() - 1 and player.has_method("_spin"):
			player.call("_spin", player.get("flip_time"), 0.25, false)
	return BOOSTS[chain]


func _physics_process(_delta: float) -> void:
	# Runs after the player's own physics (a child), so is_on_floor() is this frame's
	if player == null:
		return
	var on := player.is_on_floor()
	if on and not _was_floor:
		_landed_at = now()
	if on and now() - _landed_at > WINDOW + 0.05:
		chain = 0
		_from_jump = false
	if not on and _was_floor and player.velocity.y <= 0.0:
		_from_jump = false                 # walked off an edge: that's a fall, not a jump
	_was_floor = on
