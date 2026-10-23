class_name Rides
extends RefCounted

# How each rider rides. The skating itself (scenes/player/skate.gd) is the same for everyone; these numbers give
# each ride its own feel, so a heavy BMX and a set of paw skates can share one set of rules. Speeds are in metres
# per second, turning in radians per second.

const BOARD := {
	"name": "Skateboard",
	# Rolling
	"push_speed": 9.0,          # top speed from pushing on the flat
	"max_speed": 19.0,          # absolute cap (ramps and hills can take you past pushing speed)
	"push_accel": 6.0,          # how quickly pushing builds speed
	"coast": 0.7,               # rolling friction when you let go (low = long glide)
	"brake": 11.0,              # pulling back against where you're rolling
	"carve": 2.6,               # how quickly the board turns toward where you steer
	"slope": 1.0,               # how much of gravity pulls you along a slope (1 = all of it, for real ramps)
	# Ollie: hold Jump to crouch, let go to pop. A tap is a small hop; a full charge goes higher.
	"ollie_min": 4.2,
	"ollie_max": 6.2,
	"charge_time": 0.45,        # seconds of holding for a full charge
	# In the air
	"spin_speed": 7.5,          # turning with left and right (about 430 degrees a second)
	"air_drift": 2.5,           # how much you can nudge where you're flying
	"fall_gravity": 1.25,       # heavier on the way down than up, so airs feel snappy, not floaty
	"land_window": 0.7,         # radians: how far off straight (or straight backwards) she can land and ride away
	# Grinding
	"grind_reach": 1.1,         # how far from a rail (sideways) the grind button still snaps onto it
	"grind_min_speed": 4.0,     # snapping on slowly still gives a decent grind
	"grind_friction": 0.6,
	"balance_drift": 1.0,       # how hard the balance needle wanders (higher = harder to stay on)
	"balance_control": 6.0,     # how hard left and right push it back
	# Bails
	"bail_time": 1.4,           # seconds before she's back up on the board
}


static func ride(id: String) -> Dictionary:
	match id:
		_:
			return BOARD
