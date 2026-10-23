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
	# Manuals: rolling on two wheels, balancing with forward and back
	"manual_drift": 0.8,
	"manual_control": 5.0,
	# Bails
	"bail_time": 1.4,           # seconds before she's back up on the board
	# Tricks (scenes/player/skate_tricks.gd), by stick direction ("" is no direction). How the board moves in each
	# is its style, played by scenes/player/skate.gd.
	"tricks": {
		# Flip + direction: [name, points, style, seconds]
		"flips": {
			"": ["Kickflip", 100, "kick", 0.42], "left": ["Kickflip", 100, "kick", 0.42],
			"right": ["Heelflip", 100, "heel", 0.42], "up": ["Impossible", 150, "impossible", 0.5],
			"down": ["Pop Shove-it", 100, "shove", 0.38],
		},
		# Grab + direction, held: [name, style]
		"grabs": {
			"": ["Indy", "indy"], "left": ["Indy", "indy"], "right": ["Melon", "melon"],
			"up": ["Nosegrab", "nose"], "down": ["Tailgrab", "tail"],
		},
		# Grind + direction, when she locks on: [name, style]
		"grinds": {
			"": ["50-50", "fifty"], "up": ["Nosegrind", "nose"], "down": ["5-0", "tail"],
			"left": ["Boardslide", "slide"], "right": ["Lipslide", "slide"],
		},
		"manual": "Manual",
		"nose_manual": "Nose Manual",
		# Flip + Grab together with a full special meter: [name, points, style, seconds]
		"special": ["Galaxy Twirl", 1000, "twirl", 0.8],
	},
}


static func ride(id: String) -> Dictionary:
	match id:
		_:
			return BOARD
