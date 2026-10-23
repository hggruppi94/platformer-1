class_name Rides
extends RefCounted

# Who rides what, and how. The skating itself (scenes/player/skate.gd) is the same for everyone; these numbers give
# each ride its own feel, so a heavy BMX and a set of paw skates can share one set of rules. Speeds are in metres
# per second, turning in radians per second.
#
# Each rider has a model (their character), the ride it's on ("kit": built by scenes/player/ride_kit.gd), how they
# stand on it, their animations, and their own tricks. Anything a rider leaves out comes from BOARD (Nina's).
# Trick styles say how a trick looks: board styles (kick, heel, impossible, shove) turn the ride under her; whip
# spins the ride round its stem (a tailwhip); backflip, frontflip and cork turn the rider and ride together; twirl is a
# special's spin and somersault.

const ORDER := ["nina", "dash", "rex", "rook", "pip", "bramble", "green_man", "mr_palmer"]

const BOARD := {
	"rider": "Nina",
	"name": "Skateboard",
	"model": "res://models/characters/nina.glb",
	"kit": "board",
	"stance": -PI / 2,          # she rides side-on to the board
	"deck": 0.115,              # how high her feet are off the ground on it
	"anim": "skate",            # her riding pose
	"push_anim": "",            # an animation for pushing along (skaters stride), or "" to keep the riding pose
	# Rolling
	"push_speed": 9.0,          # top speed from pushing on the flat
	"max_speed": 19.0,          # absolute cap (ramps and hills can take you past pushing speed)
	"push_accel": 6.0,          # how quickly pushing builds speed
	"coast": 0.7,               # rolling friction when you let go (low = long glide)
	"brake": 11.0,              # pulling back against where you're rolling
	"carve": 2.6,               # how quickly the ride turns toward where you steer
	"slope": 1.0,               # how much of gravity pulls you along a slope (1 = all of it, for real ramps)
	# Ollie: hold Jump to crouch, let go to pop. A tap is a small hop; a full charge goes higher.
	"ollie_min": 4.2,
	"ollie_max": 6.2,
	"charge_time": 0.45,        # seconds of holding for a full charge
	# In the air
	"spin_speed": 7.5,          # turning with left and right (about 430 degrees a second)
	"air_drift": 2.5,           # how much you can nudge where you're flying
	"fall_gravity": 1.25,       # heavier on the way down than up, so airs feel snappy, not floaty
	"glide": 0.0,               # holding Jump while falling slows the fall to this (0: no gliding)
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
	"special_sound": "level_up",
	# Tricks (scenes/player/skate_tricks.gd), by stick direction ("" is no direction)
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

# Everyone else: only what's different from BOARD
const RIDERS := {
	"dash": {
		"rider": "Dash", "name": "BMX", "model": "res://models/characters/bike_boy.glb", "kit": "bmx",
		"stance": 0.0, "deck": 0.0, "anim": "ride",
		# Heavier and faster than a board, with big bunny hops, slower spins and a wobblier wheelie
		"push_speed": 11.0, "max_speed": 21.0, "push_accel": 7.0, "coast": 0.5, "carve": 2.2,
		"ollie_min": 4.6, "ollie_max": 6.8, "spin_speed": 6.2, "fall_gravity": 1.4,
		"manual_drift": 1.0, "balance_drift": 1.1,
		"tricks": {
			"flips": {
				"": ["Tailwhip", 150, "whip", 0.5], "left": ["Tailwhip", 150, "whip", 0.5],
				"right": ["Barspin", 120, "bar", 0.4], "up": ["Backflip", 300, "backflip", 0.75],
				"down": ["Can-Can", 120, "cancan", 0.45],
			},
			"grabs": {
				"": ["No-Hander", "nohander"], "left": ["Turndown", "turndown"], "right": ["Seat Grab", "indy"],
				"up": ["Superman", "superman"], "down": ["Tabletop", "turndown"],
			},
			"grinds": {
				"": ["Double Peg", "fifty"], "up": ["Icepick", "nose"], "down": ["Feeble", "tail"],
				"left": ["Smith", "fifty"], "right": ["Crooked", "fifty"],
			},
			"manual": "Wheelie", "nose_manual": "Endo",
			"special": ["Dash Tornado", 1000, "twirl", 0.85],
		},
	},
	"rex": {
		"rider": "Rex", "name": "Paw Skates", "model": "res://models/characters/wolf.glb", "kit": "paw_skates",
		"stance": 0.0, "deck": 0.07, "anim": "skate",
		# Four paws on four skates: quick and grippy, spins fast, steady on rails
		"push_speed": 9.5, "push_accel": 8.0, "carve": 3.6, "coast": 0.8,
		"ollie_min": 4.0, "ollie_max": 6.0, "spin_speed": 9.0, "balance_control": 7.5, "balance_drift": 0.8,
		"tricks": {
			"flips": {
				"": ["Tail Spin", 120, "cork", 0.55], "left": ["Tail Spin", 120, "cork", 0.55],
				"right": ["Husky Roll", 120, "roll", 0.5], "up": ["Front Flip", 250, "frontflip", 0.7],
				"down": ["Back Flip", 250, "backflip", 0.7],
			},
			"grabs": {
				"": ["Paw Grab", "nose"], "left": ["Tail Grab", "tail"], "right": ["Ear Grab", "indy"],
				"up": ["Victory Paws", "superman"], "down": ["Tuck", "tail"],
			},
			"grinds": {
				"": ["Soul", "fifty"], "up": ["Royale", "slide"], "down": ["Unity", "fifty"],
				"left": ["Mizou", "slide"], "right": ["Backslide", "slide"],
			},
			"manual": "Hind Roll", "nose_manual": "Front Roll",
			"special": ["Vote Rex Victory Lap", 1000, "twirl", 0.85],
		},
	},
	"rook": {
		# Four-paw roller skates: Rook rolls along on all fours, a skate on each hand and foot
		"rider": "Rook", "name": "Four-Paw Skates", "model": "res://models/characters/rook.glb", "kit": "paw_skates",
		"stance": 0.0, "deck": 0.07, "anim": "run", "push_anim": "run", "special_sound": "bark",
		"push_speed": 8.5, "push_accel": 7.5, "carve": 3.4, "coast": 0.8,
		"ollie_min": 4.2, "ollie_max": 6.2, "spin_speed": 8.5, "balance_control": 7.0,
		"tricks": {
			"flips": {
				"": ["Misty Flip", 200, "cork", 0.6], "left": ["Misty Flip", 200, "cork", 0.6],
				"right": ["Barrel Roll", 150, "roll", 0.55], "up": ["Front Flip", 250, "frontflip", 0.7],
				"down": ["Back Flip", 250, "backflip", 0.7],
			},
			"grabs": {
				"": ["Mute", "indy"], "left": ["Japan", "nose"], "right": ["Stale", "melon"],
				"up": ["Fetch!", "superman"], "down": ["Tail Wag", "tail"],
			},
			"grinds": {
				"": ["Soul", "fifty"], "up": ["Royale", "slide"], "down": ["Unity", "fifty"],
				"left": ["Mizou", "slide"], "right": ["Backslide", "slide"],
			},
			"manual": "Heel Roll", "nose_manual": "Toe Roll",
			"special": ["Zoomies", 1000, "twirl", 0.8],
		},
	},
	"pip": {
		"rider": "Pip", "name": "Hover Wings", "model": "res://models/characters/moth_kid.glb", "kit": "hover",
		"stance": 0.0, "deck": 0.25, "anim": "fly",
		# Floaty: big slow airs, glides while Jump is held on the way down, a little slower on the ground
		"push_speed": 8.0, "max_speed": 16.0, "coast": 0.4, "carve": 2.8,
		"ollie_min": 4.6, "ollie_max": 7.0, "fall_gravity": 0.7, "glide": 2.2, "air_drift": 5.0, "spin_speed": 6.5,
		"tricks": {
			"flips": {
				"": ["Wing Flip", 150, "backflip", 0.7], "left": ["Moth Spiral", 150, "cork", 0.6],
				"right": ["Moth Spiral", 150, "cork", 0.6], "up": ["Moonsault", 250, "frontflip", 0.75],
				"down": ["Hover Spin", 100, "shove", 0.4],
			},
			"grabs": {
				"": ["Antenna Grab", "superman"], "left": ["Wing Tuck", "indy"], "right": ["Wing Tuck", "melon"],
				"up": ["Star Reach", "superman"], "down": ["Dangle", "tail"],
			},
			"grinds": {
				"": ["Hover Grind", "fifty"], "up": ["Glow Grind", "nose"], "down": ["Glow Grind", "tail"],
				"left": ["Wing Slide", "slide"], "right": ["Wing Slide", "slide"],
			},
			"manual": "Low Hover", "nose_manual": "Nose Hover",
			"special": ["Moonbeam Loop", 1000, "twirl", 0.9],
		},
	},
	"bramble": {
		"rider": "Bramble", "name": "Scooter", "model": "res://models/characters/cattle_girl.glb", "kit": "scooter",
		"stance": 0.0, "deck": 0.12, "anim": "idle",
		"push_speed": 9.0, "carve": 3.0, "ollie_min": 4.3, "ollie_max": 6.3, "spin_speed": 7.5,
		"tricks": {
			"flips": {
				"": ["Tailwhip", 150, "whip", 0.5], "left": ["Tailwhip", 150, "whip", 0.5],
				"right": ["Barspin", 120, "bar", 0.4], "up": ["Backflip", 300, "backflip", 0.75],
				"down": ["Hoof Kick", 100, "cancan", 0.4],
			},
			"grabs": {
				"": ["Deck Grab", "indy"], "left": ["Heel Click", "turndown"], "right": ["Lasso", "nohander"],
				"up": ["Superman", "superman"], "down": ["Tail Grab", "tail"],
			},
			"grinds": {
				"": ["Deck Grind", "fifty"], "up": ["Nose Grind", "nose"], "down": ["Tail Grind", "tail"],
				"left": ["Feeble", "fifty"], "right": ["Smith", "fifty"],
			},
			"manual": "Wheelie", "nose_manual": "Nose Wheelie",
			"special": ["Flower Stampede", 1000, "twirl", 0.85],
		},
	},
	"green_man": {
		"rider": "Green Man", "name": "Leaf Board", "model": "res://models/characters/green_man.glb", "kit": "leaf",
		"stance": -PI / 2, "deck": 0.12, "anim": "idle",
		# Smooth and steady: long glides and carves, easy balance, a bit slower
		"push_speed": 8.0, "coast": 0.35, "carve": 3.0, "balance_drift": 0.7, "manual_drift": 0.6,
		"tricks": {
			"flips": {
				"": ["Leaf Flip", 100, "kick", 0.45], "left": ["Leaf Flip", 100, "kick", 0.45],
				"right": ["Petal Flip", 100, "heel", 0.45], "up": ["Seed Pop", 150, "impossible", 0.5],
				"down": ["Pollen Spin", 100, "shove", 0.4],
			},
			"grabs": {
				"": ["Stem Grab", "indy"], "left": ["Stem Grab", "indy"], "right": ["Root Grab", "melon"],
				"up": ["Sun Reach", "nose"], "down": ["Tail Leaf", "tail"],
			},
			"grinds": {
				"": ["Vine Grind", "fifty"], "up": ["Nose Vine", "nose"], "down": ["Tail Vine", "tail"],
				"left": ["Leaf Slide", "slide"], "right": ["Leaf Slide", "slide"],
			},
			"manual": "Sprout", "nose_manual": "Nose Sprout",
			"special": ["Photosynthesis", 1000, "twirl", 0.8],
		},
	},
	"mr_palmer": {
		"rider": "Mr. Palmer", "name": "Mayor-mobile", "model": "res://models/characters/mr_palmer.glb", "kit": "segway",
		"stance": 0.0, "deck": 0.18, "anim": "idle",
		# Steady as a mayor: slow, very hard to fall off rails, little hops
		"push_speed": 7.5, "max_speed": 15.0, "push_accel": 5.0, "carve": 2.2,
		"ollie_min": 3.8, "ollie_max": 5.4, "spin_speed": 6.0, "balance_drift": 0.5, "manual_drift": 0.5,
		"tricks": {
			"flips": {
				"": ["Ribbon Cutter", 120, "whip", 0.5], "left": ["Ribbon Cutter", 120, "whip", 0.5],
				"right": ["Wheel Wave", 120, "bar", 0.4], "up": ["Mayor Flip", 300, "backflip", 0.8],
				"down": ["Gavel Drop", 100, "cancan", 0.4],
			},
			"grabs": {
				"": ["Hat Tip", "nohander"], "left": ["Hat Tip", "nohander"], "right": ["Big Wave", "nohander"],
				"up": ["Speech!", "nohander"], "down": ["Bow", "turndown"],
			},
			"grinds": {
				"": ["Official Grind", "fifty"], "up": ["Nose Grind", "nose"], "down": ["Tail Grind", "tail"],
				"left": ["Red Tape Slide", "slide"], "right": ["Red Tape Slide", "slide"],
			},
			"manual": "Wheelie", "nose_manual": "Nose Wheelie",
			"special": ["Re-Election Spin", 1000, "twirl", 0.85],
		},
	},
}


static func ride(id: String) -> Dictionary:
	# A rider's full set: BOARD with their own differences on top
	if not RIDERS.has(id):
		return BOARD
	var out := BOARD.duplicate(true)
	out.merge(RIDERS[id], true)
	return out
