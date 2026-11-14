extends Node

# Autoload "Races": racing round the Void on whatever you ride (your board, or a friend's ride from the Skaters'
# Corner: scripts/rides.gd). Each track (TRACKS) is placed in its scene at runtime by scripts/race_track.gd: a start
# arch, Zippy the pink little alien who starts the races, a race board, boost pads that are there all the time, and,
# while racing, glowing rings at the checkpoints, Star Boxes and goo puddles.
#
# Talk to Zippy and say you're ready: you're put on the line with three friends on their own rides
# (scripts/race_rival.gd), a 3-2-1 countdown, then laps round the checkpoints in order (the next ring glows gold).
# Boost pads shoot you forward. Star Boxes give a power-up to use when you like (the Aim button, which is free while
# riding): the Zoom Star (a burst of speed), the Bubble Shield (no falls and no goo for a while) or the Super Spring
# (a huge hop). Goo puddles are slow going. Everyone who finishes wins sparkles (more for a better place), and beating
# your best time pays a bonus. Stepping off your ride, wandering far off the track or leaving the place ends the race
# with no harm done.
#
# Kept apart from the Star Popper and other gadgets on purpose: power-ups are things on the track, used up in a race.
#
# Zippy's Tune-Up, a workbench beside the race board, sells ride upgrades through the shared shop (scripts/shop.gd,
# the "Tune-Up" stall, kind "ride_upgrade" in res://shop/items.json): Speedy Wheels, Power Push, Grippy Grip and
# Turbo Tank, three levels each, and the Starter Star. They work on every ride, on or off the track: tuned() turns a
# ride's numbers (scripts/rides.gd) into the upgraded ones, and the skating uses those (scenes/player/skate.gd).
# Best times, wins and upgrades are saved with the game (scripts/game.gd, "races").

signal finished(track_id: String, place: int)
signal upgraded

enum State { IDLE, INTRO, COUNTDOWN, RACING, RESULTS }

const TOWN := "res://scenes/town/town.tscn"
const EARTH := "res://scenes/earth/earth.tscn"
const DARK_HOLLOW := "res://scenes/portal_worlds/dark_hollow.tscn"
const FAR_FUTURE := "res://scenes/portal_worlds/far_future.tscn"
const COUNTDOWN := 3.0
const RESULTS_TIME := 7.0
const PASS_RADIUS := 6.0             # metres from a checkpoint's middle that counts as through its ring
const PAD_RADIUS := 1.9
const BOX_RADIUS := 1.7
const GOO_RADIUS := 2.0
const WANDER := 45.0                 # metres off the track and the race is off
const SHORTCUT_PRIZE := 3             # sparkles for finding a circuit's secret shortcut the first time
const BEST_BONUS := 5                # sparkles for beating your best time

# Each track: its checkpoints (x, z; the first is the start and finish line), laps, prizes by place, and where its
# boost pads, Star Boxes (three across the track) and goo puddles are, as a checkpoint number plus how far on to the
# next one (2.5 is halfway from checkpoint 2 to 3) and metres to the right of the racing line.
const TRACKS := {
	# The Void's three ground races and Stars Hollow's are circuits of their own (scripts/race_circuit.gd builds them,
	# scenes/races/<id>.tscn): you start them at a race gate in town ("hub", HUBS) and the game takes you there. Their
	# points are x, height, z (the road climbs and dips), and they have obstacles: [where, kind, metres to the right].
	# Eight racers (seven friends) in the Void, seven in Stars Hollow.
	"lake_loop": {
		"name": "Lake Loop",
		"blurb": "three laps round the lake, over the bridge hump and through the zappers",
		"scene": "res://scenes/races/lake_loop.tscn",
		"hub": "void",
		"circuit": {"theme": "void", "feature": "lake"},
		"width": 14.0,
		"ring": 8.6,
		"laps": 3,
		"points": [Vector3(-40, 0.2, 48), Vector3(0, 0.2, 50), Vector3(40, 0.2, 48), Vector3(72, 0.2, 36), Vector3(88, 0.2, 8),
			Vector3(84, 1.5, -22), Vector3(62, 3.0, -42), Vector3(34, 3.0, -50), Vector3(14, 1.5, -42), Vector3(-4, 0.2, -46),
			Vector3(-26, 0.2, -56), Vector3(-54, 0.2, -48), Vector3(-76, 0.2, -26), Vector3(-84, 0.2, 4), Vector3(-72, 0.2, 32)],
		"boosts": [[0.5, 0.0], [3.5, -3.0], [7.5, 0.0], [10.5, 3.0], [13.5, 0.0]],
		"boxes": [[1.5], [5.0], [8.5], [12.0]],
		"goo": [[4.4, -3.0], [9.4, 3.0], [11.4, -2.5], [14.0, 2.0]],
		"obstacles": [[2.5, "bumper", -3.5], [2.6, "bumper", 3.5], [4.0, "slider", 0.0], [6.0, "ramp", 0.0], [6.8, "zapper", -3.4],
			[7.2, "zapper", 3.4], [9.0, "sweeper", 0.0], [11.0, "bumper", 0.0], [12.2, "popup", 0.0], [13.0, "ramp", 0.0],
			[13.8, "bumper", -3.0]],
		# (Hayden's 13 Nov 2026 playtest: "moving maps, obstacles, secret shortcuts, tunnels". A secret shortcut leaves the
		# road through a curtain of vines on the inside of a bend and comes back further round (scripts/race_circuit.gd);
		# a tunnel roofs the road between two checkpoints.)
		"shortcuts": [{"name": "Lily Tunnel", "from": 3.1, "to": 8.1}],
		"tunnels": [[9.6, 10.7]],
		"tunnel_name": "CRYSTAL TUNNEL",
		"prizes": [20, 15, 11, 8, 6, 4, 3, 2],
		"rivals": ["dash", "rex", "clover", "rook", "pip", "green_man", "nina"],
		"starter": {"name": "Zippy", "model": "res://models/characters/little_alien_pink.glb"},
	},
	"meadow_wiggle": {
		"name": "Meadow Wiggle",
		"blurb": "three laps of wiggly bends through the flower meadow, with ramps and a spinning sweeper",
		"scene": "res://scenes/races/meadow_wiggle.tscn",
		"hub": "void",
		"circuit": {"theme": "void", "feature": "meadow"},
		"width": 14.0,
		"ring": 8.6,
		"laps": 3,
		"after": "lake_loop",
		"points": [Vector3(-62, 0.2, 62), Vector3(-20, 0.2, 59), Vector3(11, 0.2, 61), Vector3(33, 0.2, 66), Vector3(58, 0.2, 62),
			Vector3(69, 0.2, 43), Vector3(64, 0.2, 19), Vector3(74, 0.2, -4), Vector3(65, 0.2, -30), Vector3(43, 0.2, -37),
			Vector3(20, 0.2, -32), Vector3(-1, 0.2, -38), Vector3(-26, 0.2, -32), Vector3(-49, 0.2, -39), Vector3(-72, 0.2, -30),
			Vector3(-80, 0.2, -3), Vector3(-70, 0.2, 20), Vector3(-75, 0.2, 47)],
		"boosts": [[0.5, 0.0], [4.5, 0.0], [8.5, 0.0], [12.5, 0.0], [16.5, 0.0]],
		"boxes": [[2.0], [6.0], [10.0], [14.0]],
		"goo": [[3.5, 2.5], [7.5, -2.5], [11.5, 2.5], [15.5, -2.5]],
		"obstacles": [[1.3, "bumper", -2.5], [1.5, "bumper", 3.0], [3.0, "ramp", 0.0], [5.3, "bumper", 0.0], [6.6, "sweeper", 0.0],
			[8.0, "slider", 0.0], [9.3, "ramp", 0.0], [10.6, "bumper", -3.5], [10.8, "bumper", 3.5], [13.3, "zapper", 3.4],
			[13.6, "zapper", -3.4], [14.4, "popup", 0.0], [15.0, "sweeper", 0.0], [16.2, "ramp", 0.0]],
		"shortcuts": [{"name": "Root Run", "from": 6.0, "to": 9.9}],
		"tunnels": [[11.6, 12.9]],
		"tunnel_name": "MUSHROOM TUNNEL",
		"prizes": [22, 16, 12, 9, 6, 4, 3, 2],
		"rivals": ["rook", "pip", "green_man", "clover", "bruno", "mr_palmer", "nina"],
		"starter": {"name": "Dart", "model": "res://models/characters/little_alien_orange.glb"},
	},
	"sky_rings": {
		"name": "Sky Rings",
		"blurb": "one big lap of the sky in the mothership",
		"scene": TOWN,
		"laps": 1,
		"after": "lake_loop",
		"sky": true,
		"ring": 24.0,
		# x, height, z: over the lake, the Homes, the Observatory, round the castle, the Spooky Woods and the Market
		"points": [Vector3(0, 48, 0), Vector3(60, 44, 24), Vector3(104, 58, -18), Vector3(112, 66, -88),
			Vector3(64, 74, -150), Vector3(-24, 80, -168), Vector3(-84, 62, -112), Vector3(-104, 58, -40),
			Vector3(-82, 38, 30), Vector3(-40, 42, 52)],
		"boosts": [[1.5], [4.5], [7.5]],
		"prizes": [25, 16, 10, 5],
		"rivals": [{"id": "blip", "name": "Blip", "colour": "green"}, {"id": "nova", "name": "Nova", "colour": "purple"},
			{"id": "zoomi", "name": "Zoomi", "colour": "yellow"}],
		"pace": [23.0, 22.0, 21.0],               # metres a second (the mothership flies at 24, more in a boost)
	},
	"observatory_hill": {
		"name": "Observatory Hill",
		"blurb": "three laps up round the Observatory's hill and down again, fast",
		"scene": "res://scenes/races/observatory_hill.tscn",
		"hub": "void",
		"circuit": {"theme": "void", "feature": "hill"},
		"width": 14.0,
		"ring": 8.6,
		"laps": 3,
		"after": "meadow_wiggle",
		"points": [Vector3(4, 0.2, 69), Vector3(36, 0.2, 62), Vector3(72, 2.0, 53), Vector3(86, 5.0, 17), Vector3(81, 9.0, -8),
			Vector3(59, 12.0, -38), Vector3(31, 14.0, -47), Vector3(-1, 14.0, -46), Vector3(-26, 12.0, -41), Vector3(-42, 8.0, -13),
			Vector3(-46, 5.0, 8), Vector3(-62, 3.0, 24), Vector3(-73, 1.0, 49), Vector3(-58, 0.2, 68), Vector3(-22, 0.2, 73)],
		"boosts": [[0.5, 0.0], [3.5, 0.0], [7.5, 0.0], [10.5, 0.0], [13.5, 0.0]],
		"boxes": [[1.6], [5.0], [8.6], [12.0]],
		"goo": [[4.3, -2.5], [6.4, 2.5], [11.3, -2.5]],
		"obstacles": [[2.4, "bumper", 0.0], [3.3, "slider", 0.0], [4.7, "zapper", -3.4], [5.6, "zapper", 3.4], [7.0, "sweeper", 0.0],
			[8.0, "ramp", 0.0], [8.95, "bumper", -3.0], [9.15, "bumper", 3.0], [10.8, "popup", 0.0], [11.7, "ramp", 0.0],
			[13.1, "sweeper", 0.0], [13.4, "bumper", 0.0]],
		"shortcuts": [{"name": "Star Tunnel", "from": 10.0, "to": 13.9}],
		"tunnels": [[2.6, 3.9]],
		"tunnel_name": "STARGAZER TUNNEL",
		"prizes": [24, 17, 12, 9, 6, 4, 3, 2],
		"rivals": ["dash", "rex", "mr_palmer", "bruno", "pip", "clover", "green_man"],
		"starter": {"name": "Comet", "model": "res://models/characters/little_alien_blue.glb"},
	},
	# Stars Hollow's: kids are people on Earth, so the friends racing are Earth kids from town (copied from the townsfolk
	# when you set off from there, scripts/race_rival.gd) on the rides in TOWNSFOLK_RIDES, and the starter is an Earth
	# kid too ("look", the same hero-style look tools/build_earth.gd gives townsfolk). Open from the start: it's at home.
	"pumpkin_run": {
		"name": "Pumpkin Run",
		"blurb": "three laps of the farm lanes outside Stars Hollow, past the barn, the windmill and the sprinklers",
		"scene": "res://scenes/races/pumpkin_run.tscn",
		"hub": "earth",
		"circuit": {"theme": "earth", "feature": "farm"},
		"width": 14.0,
		"ring": 8.6,
		"laps": 3,
		"points": [Vector3(-50, 0.2, 61), Vector3(-13, 0.2, 59), Vector3(28, 0.2, 59), Vector3(60, 0.2, 42), Vector3(67, 0.2, 17),
			Vector3(60, 0.2, -5), Vector3(66, 0.2, -30), Vector3(49, 0.2, -56), Vector3(18, 0.2, -55), Vector3(-4, 0.2, -48),
			Vector3(-24, 0.2, -55), Vector3(-55, 0.2, -57), Vector3(-73, 0.2, -32), Vector3(-66, 0.2, -3), Vector3(-72, 0.2, 26)],
		"boosts": [[0.5, 0.0], [4.5, 0.0], [8.5, 0.0], [12.5, 0.0]],
		"boxes": [[2.0], [6.0], [10.0], [13.5]],
		"goo": [[3.4, -2.5], [7.4, 2.5], [11.4, -2.5], [12.0, 2.5]],
		"obstacles": [[1.4, "bumper", -3.0], [1.6, "bumper", 3.0], [3.0, "ramp", 0.0], [4.0, "slider", 0.0], [5.0, "sweeper", 0.0],
			[6.6, "bumper", 0.0], [7.0, "popup", 0.0], [7.7, "zapper", -3.4], [9.4, "ramp", 0.0], [10.7, "bumper", -3.5],
			[10.9, "bumper", 3.5], [12.5, "sweeper", 0.0], [13.0, "zapper", 3.4], [14.15, "ramp", 0.0]],
		"shortcuts": [{"name": "Corn Cut", "from": 8.5, "to": 13.6}],
		"tunnels": [[3.5, 4.6]],
		"tunnel_name": "COVERED BRIDGE",
		"prizes": [20, 15, 11, 8, 5, 3, 2],
		"rivals": ["nina_earth", "bruno", "ozzie", "juniper", "theo", "prue"],
		"spares": [],
		"starter": {"name": "Pepper", "look": {"colors": {"fur": 3, "hair": 6, "brows": 6, "top": 9, "bottoms": 6,
			"shoes": 7}, "hairstyle": 2, "extras": false, "height": 0.95, "head": 1.0, "build": 1.0},
			"extras": [{"kind": "cap", "color": Color(0.1, 0.1, 0.12)}, {"kind": "scarf", "color": Color(0.95, 0.55, 0.15)}]},
	},
	# Dark Hollow's (Hayden's 14 Nov 2026 playtest: "The dark hollow race is pretty lame and needs a rework like the
	# other races"): a circuit of its own like the Void's and Earth's, started at Pip's race gate in Dark Hollow (HUBS),
	# a night-time run past crooked trees, glowing mushrooms and lamp posts, round the misty hollow with the Moon Clock
	# in the middle. Open from the start; finishing it at all still gives you the third Moon Piece (scripts/dark_hollow.gd
	# gives it when you're back). Its first win's the Lantern Hat (FIRST_HATS).
	"hollow_run": {
		"name": "Hollow Run",
		"blurb": "three spooky laps round the misty hollow at midnight, past the crooked trees and the glowing mushrooms",
		"scene": "res://scenes/races/hollow_run.tscn",
		"hub": "dark_hollow",
		"circuit": {"theme": "dark", "feature": "hollow"},
		"width": 14.0,
		"ring": 8.6,
		"laps": 3,
		"points": [Vector3(0, 0.2, 72), Vector3(-36, 0.2, 66), Vector3(-66, 2.0, 48), Vector3(-80, 5.0, 18), Vector3(-74, 6.0, -14),
			Vector3(-58, 4.0, -40), Vector3(-30, 1.0, -58), Vector3(4, 3.0, -66), Vector3(36, 6.0, -60), Vector3(62, 8.0, -36),
			Vector3(78, 5.0, -6), Vector3(70, 2.0, 24), Vector3(48, 0.2, 44), Vector3(26, 0.2, 62)],
		"boosts": [[0.5, 0.0], [3.5, 0.0], [7.0, 0.0], [10.5, 0.0]],
		"boxes": [[1.8], [5.2], [8.4], [12.2]],
		"goo": [[4.2, -2.5], [6.6, 2.5], [11.4, -2.5]],
		"obstacles": [[1.2, "sweeper", 0.0], [2.4, "bumper", 0.0], [5.0, "zapper", -3.4], [5.8, "sweeper", 0.0], [7.6, "ramp", 0.0],
			[9.6, "slider", 0.0], [10.1, "bumper", -3.0], [10.3, "bumper", 3.0], [11.0, "popup", 0.0], [11.9, "zapper", 3.4]],
		"shortcuts": [{"name": "Root Tunnel", "from": 8.4, "to": 12.8}],
		"tunnels": [[3.0, 4.0]],
		"tunnel_name": "HOLLOW LOG",
		"prizes": [22, 16, 12, 9, 6, 4, 3, 2],
		"rivals": ["rook", "green_man", "dash", "bruno", "clover", "nina", "rex"],
		"starter": {"name": "Pip", "model": "res://models/characters/moth_kid.glb", "scale": 1.0},
	},
	# In the Far Future (scripts/far_future.gd): the Skyway, a sky road ten metres up that rings Lumen City (built by
	# tools/build_far_future.gd from these same points, so the line lies on its deck). Dash, Rex and Rook race; the
	# starter, Countdown, waits on the ground under it, and saying go lifts you up onto the grid. The boost pads are
	# rocket boosts. Open from the start; finishing it at all brings the second Time Core home.
	"skyway_run": {
		"name": "Skyway Run",
		"blurb": "two rocket-fast laps of the sky road round Lumen City, ten metres up",
		"scene": FAR_FUTURE,
		"laps": 2,
		"points": [Vector2(52, 8), Vector2(40, 32), Vector2(20, 47), Vector2(0, 50), Vector2(-24, 46), Vector2(-42, 32),
			Vector2(-52, 10), Vector2(-50, -14), Vector2(-38, -36), Vector2(-16, -50), Vector2(10, -52), Vector2(34, -40),
			Vector2(50, -18)],
		"boosts": [[0.5, 0.0], [3.5, 0.0], [6.5, 0.0], [9.5, 0.0]],
		"boxes": [[2.0], [5.0], [8.0], [11.0]],
		"goo": [[4.2, -2.2], [10.2, 2.2]],
		"prizes": [18, 12, 7, 4],
		"rivals": ["dash", "rex", "rook"],
		"starter": {"name": "Countdown", "model": "res://models/characters/little_alien_blue.glb"},
	},
}
# The race gates: where the circuits are started from, out in the world. Each stands where the old track's start was
# (the arch, the starter, the board, and at the Void's, Zippy's Tune-Up): "at" is the arch, "toward" the way it faces.
# Talking to the starter offers every circuit there that's open, and takes you to it (enter_circuit()).
const HUBS := {
	"void": {"name": "Races", "scene": TOWN, "at": Vector2(-4, 24), "toward": Vector2(16, 25), "tune_up": true,
		"place": "the Void", "starter": {"name": "Zippy", "model": "res://models/characters/little_alien_pink.glb"}},
	"earth": {"name": "Races", "scene": EARTH, "at": Vector2(-6, 58), "toward": Vector2(20, 58), "place": "Stars Hollow",
		"starter": {"name": "Pepper", "look": {"colors": {"fur": 3, "hair": 6, "brows": 6, "top": 9, "bottoms": 6,
			"shoes": 7}, "hairstyle": 2, "extras": false, "height": 0.95, "head": 1.0, "build": 1.0},
			"extras": [{"kind": "cap", "color": Color(0.1, 0.1, 0.12)}, {"kind": "scarf", "color": Color(0.95, 0.55, 0.15)}]}},
	# Where the old Hollow Run started, in Dark Hollow: Pip's glow knows the way in the dark
	"dark_hollow": {"name": "Races", "scene": DARK_HOLLOW, "at": Vector2(8, 40), "toward": Vector2(-14, 40), "place": "Dark Hollow",
		"starter": {"name": "Pip", "model": "res://models/characters/moth_kid.glb", "scale": 1.0}},
}
# Earth kids who race, and the ride from scripts/rides.gd each one rides (Nina's board, Bruno's SK8 Deck...)
const TOWNSFOLK_RIDES := {"nina_earth": "nina", "bruno": "bruno", "ozzie": "nina", "juniper": "nina", "theo": "nina", "prue": "nina"}
# What an Earth kid looks like if they can't be copied from town (a race started some other way, like a test)
const KID_LOOKS := {
	"nina_earth": {"name": "Nina", "colors": {"fur": 2, "hair": 4, "brows": 4, "top": 12, "bottoms": 6, "shoes": 7}, "hairstyle": 3},
	"bruno": {"name": "Bruno", "colors": {"fur": 2, "hair": 11, "brows": 4, "top": 15, "bottoms": 6, "shoes": 6}, "hairstyle": 5},
	"ozzie": {"name": "Ozzie", "colors": {"fur": 1, "hair": 10, "brows": 1, "top": 9, "bottoms": 15, "shoes": 6}, "hairstyle": 1},
	"juniper": {"name": "Juniper", "colors": {"fur": 5, "hair": 6, "brows": 8, "top": 11, "bottoms": 15, "shoes": 18}, "hairstyle": 2},
	"theo": {"name": "Theo", "colors": {"fur": 4, "hair": 6, "brows": 10, "top": 12, "bottoms": 15, "shoes": 7}, "hairstyle": 0},
	"prue": {"name": "Prue", "colors": {"fur": 1, "hair": 4, "brows": 2, "top": 17, "bottoms": 18, "shoes": 18}, "hairstyle": 4},
}
# Who rides in a friend's place when you're riding as them (a track can say its own: "spares")
const SPARE_RIVALS := ["nina", "green_man", "pip", "bruno", "mr_palmer", "rook", "dash", "rex", "clover"]
# How fast each rival rides on the flat (metres per second), front of the grid to back. The player's board pushes at 9.
const RIVAL_PACE := [9.2, 8.8, 8.4]
const CIRCUIT_PACE := [9.5, 9.3, 9.1, 8.9, 8.7, 8.5, 8.3]
# Settings > Assist > Skating landings also sets how hard the races are: Relaxed, Normal, Pro
const PACE_BY_ASSIST := [0.9, 1.0, 1.1]
# On a circuit you start in the middle of the pack (the fifth place on the grid), so there's racing to do
const GRID := [[-4.0, -3.0], [-4.0, 3.0], [-10.0, -3.0], [-10.0, 3.0], [-16.0, -3.0], [-16.0, 3.0], [-22.0, -3.0], [-22.0, 3.0]]
const OLD_GRID := [[-4.0, -2.2], [-4.0, 2.2], [-9.0, -2.2], [-9.0, 2.2]]

# Power-ups from the Star Boxes. Since 11 Nov 2026 (Hayden: "more powerups that attack/defend with racers that attack
# you") there are three to throw at the others as well (scripts/race_attacks.gd), and the friends use them too.
const POWERS := {
	"zoom": {"name": "Zoom Star", "say": "Zoom!"},
	"shield": {"name": "Bubble Shield", "say": "Bubble Shield!"},
	"spring": {"name": "Super Spring", "say": "Boing!"},
	"goo": {"name": "Goo Bomb", "say": "Splat!"},
	"seeker": {"name": "Bubble Seeker", "say": "Bubble away!"},
	"zap": {"name": "Zap Ring", "say": "ZAP!"},
}
# What each level of an upgrade adds, as a share of the ride's own number (Speedy Wheels 2 = 10% faster)
const UPGRADES := {
	"wheels": {"push_speed": 0.05, "max_speed": 0.05},
	"push": {"push_accel": 0.15, "push_kick": 0.15},
	"grip": {"carve": 0.12},
	"turbo": {},                     # boosts last TURBO longer a level (boost_time())
	"starter": {},                   # every race starts with a Zoom Star in hand
}
const TURBO := 0.25

# First prizes (Hayden, 13 Nov 2026: "unique rewards for finishing first, something to incentivize the player to race",
# "make [blueprints] rewards for completing races/quests"): winning a race the first time gives something you can't get
# any other way. The four circuits give a gadget's blueprint (Schematics.LIST "reward": {"race": ...}); the others a
# hat (shop/items.json, scripts/cosmetics.gd). Winning all four circuits makes you the Race Champion, with a helmet.
const FIRST_HATS := {"sky_rings": "aviator_cap", "hollow_run": "lantern_hat", "skyway_run": "rocket_helmet"}
const CHAMPION_TRACKS := ["lake_loop", "meadow_wiggle", "observatory_hill", "pumpkin_run"]
const CHAMPION_HAT := "racing_helmet"

const SHIELD_TIME := 8.0
const ZOOM_SPEED := 8.0
const ZOOM_TIME := 2.2
const SPRING_POWER := 11.0
const PAD_SPEED := 6.5
const PAD_TIME := 1.3
const SKY_BOOST := 2.0
const RAMP_POP := 8.0                # a circuit's jump ramp (metres a second up)
const KNOCK_SAFE := 2.5              # after being knocked over, a moment when nothing can knock you again
const ATTACKS := preload("res://scripts/race_attacks.gd")
const TUTORIAL := preload("res://scripts/race_tutorial.gd")
const FLOW := preload("res://scripts/race_flow.gd")
const COIN_RADIUS := 1.6             # speed coins (circuits only: race_track.gd _place_coins)
const COIN_SPEED := 2.5              # each coin's little push...
const COIN_TIME := 0.5
const COIN_BACK := 12.0              # ...and how long until a taken coin comes back (so once a lap)

var best := {}                       # track id -> best time in seconds
var wins := {}                       # track id -> how many times you came 1st
var raced := 0                       # races finished, all told
var upgrades := {}                   # upgrade -> level bought (see UPGRADES)
var finished_once := {}              # track id -> true once you've finished it (opens the next track)

var state := State.IDLE
var track_id := ""
var track: RaceTrack                 # the one we're racing on
var rivals: Array[RaceRival] = []
var lap := 1
var last_cp := 0                     # the last checkpoint passed (0: the line)
var next_cp := 1
var time := 0.0
var power := ""                      # the power-up being held ("" for none)
var place := 1
var progress := 0.0                  # how far round the player is, all laps together
var hud: RaceHud
var intro: RaceIntro                 # the cutscene before a race (scripts/race_intro.gd)
var tutorial: CanvasLayer            # how races work, the first time (scripts/race_tutorial.gd)
var flow: CanvasLayer                # a whole set of speed coins: quicker, and the screen's edges melt (race_flow.gd)
var _coin_got := {}                  # coin set (its index on the track) -> coins taken from it this time round
var _count := 0.0
var _results := 0.0
var _shield := 0.0
var _bubble: Node3D
var _wrong := 0.0
var _last_d := 0.0
var _pad_wait := {}                  # pad -> seconds until it boosts again (so one pad is one boost)
var _goo_wait := 0.0
var _rival_pad := {}                 # rival -> the last pad they were boosted by
var _along := 0.0                    # the player's last side of the next checkpoint (- before it, + past it)
var _sc := -1                         # the secret shortcut the player's in (-1: none): see _in_shortcut()
var _sc_ok := false                   # ...whether they went in at its front, from the right bit of the lap
var _sc_done := false                 # ...and whether it's moved them on past the rings it skips yet
var _rng := RandomNumberGenerator.new()
var _sky_side := {}                  # sky track -> which side of its start ring the mothership was last frame
var attacks: Node                    # the thrown power-ups and the obstacles (scripts/race_attacks.gd)
var circuit := ""                    # the circuit we're in ("" when out in the world)
var _pending := ""                   # a circuit to start the race on as soon as it's ready
var _pending_intro := true           # ...and whether to play its intro (not when it's "race again")
var _return := {}                    # where to go back to from a circuit: {scene, position, yaw}
var _kids := {}                      # Earth kids to race, copied from town on the way out: id -> their look
var _froze_clock := false
var _knock_safe := 0.0
var _choosing := false               # the results' (or a race called off's) "race again / go back" is up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	hud = RaceHud.new()
	hud.name = "RaceHUD"
	add_child(hud)
	intro = RaceIntro.new()
	intro.name = "RaceIntro"
	add_child(intro)
	intro.done.connect(_after_intro)
	tutorial = TUTORIAL.new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	attacks = ATTACKS.new()
	attacks.name = "Attacks"
	add_child(attacks)
	flow = FLOW.new()
	flow.name = "Flow"
	add_child(flow)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	Dialogue.finished.connect(_on_talked)
	_rng.randomize()
	_register_shop.call_deferred()            # Shop comes after this in the autoloads


func _register_shop() -> void:
	Shop.register_kind("ride_upgrade", {"can_buy": _can_upgrade, "buy": _buy_upgrade, "button": "Tune up",
		"show": _show_upgrade})


func _show_upgrade(item: Dictionary) -> bool:
	# Only the next level of each upgrade is on the bench (the top level stays once it's bought, as "Got it!")
	var lv := level(str(item.upgrade))
	return int(item.level) == lv + 1 or (int(item.level) == lv and lv == _top_level(str(item.upgrade)))


func _top_level(upgrade: String) -> int:
	var top := 0
	for it in Shop.items.values():
		if it.get("upgrade", "") == upgrade:
			top = maxi(top, int(it.level))
	return top


func _can_upgrade(item: Dictionary) -> String:
	var lv := level(str(item.upgrade))
	if lv >= int(item.level):
		return "You have this one"
	if lv < int(item.level) - 1:
		return "Needs level %d first" % (int(item.level) - 1)
	return ""


func _buy_upgrade(item: Dictionary) -> String:
	upgrades[str(item.upgrade)] = int(item.level)
	upgraded.emit()
	return "Zippy tightens a bolt or two. %s: %s!" % [item.name, str(item.text).split(" (")[0].to_lower()]


func level(upgrade: String) -> int:
	return int(upgrades.get(upgrade, 0))


func tuned(ride: Dictionary) -> Dictionary:
	# A ride's numbers with the upgrades bought so far
	if upgrades.is_empty():
		return ride
	var out := ride.duplicate()
	for u in UPGRADES:
		var lv := level(u)
		for key in UPGRADES[u]:
			if out.has(key) and lv > 0:
				out[key] = float(out[key]) * (1.0 + float(UPGRADES[u][key]) * lv)
	return out


func boost_time(seconds: float) -> float:
	return seconds * (1.0 + TURBO * level("turbo"))


func ride_of(who: String) -> Dictionary:
	# The ride a racer rides: their own (scripts/rides.gd), or, for an Earth kid, the one in TOWNSFOLK_RIDES
	return Rides.ride(str(TOWNSFOLK_RIDES.get(who, who)))


func choosing() -> bool:
	# The results' "race again / go back" buttons are up: they need the mouse cursor (scripts/race_hud.gd)
	return _choosing


func racing() -> bool:
	return state != State.IDLE


func save_data() -> Dictionary:
	return {"best": best.duplicate(), "wins": wins.duplicate(), "raced": raced, "upgrades": upgrades.duplicate(),
		"finished": finished_once.keys()}


func load_data(data: Dictionary) -> void:
	reset()
	var b = data.get("best", {})
	var w = data.get("wins", {})
	if b is Dictionary:
		for k in b:
			best[str(k)] = float(b[k])
	if w is Dictionary:
		for k in w:
			wins[str(k)] = int(w[k])
	raced = int(data.get("raced", 0))
	var done = data.get("finished", [])
	if done is Array:
		for k in done:
			finished_once[str(k)] = true
	for k in best:
		finished_once[k] = true                       # (a best time means it was finished)
	var u = data.get("upgrades", {})
	if u is Dictionary:
		for k in u:
			upgrades[str(k)] = int(u[k])
	upgraded.emit()
	_refresh_boards()


func reset() -> void:
	if racing():
		_end(false)
	best.clear()
	wins.clear()
	raced = 0
	finished_once.clear()
	upgrades.clear()
	upgraded.emit()


# -----------------------------------------------------------------------------
# Placing the tracks
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	if racing():
		_end(false)                                   # the scene the race was in is gone: no harm done
	_close_choice()
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id in TRACKS:
		if TRACKS[id].scene == scene.scene_file_path and scene.get_node_or_null("Race " + id) == null:
			var t := RaceTrack.new()
			t.name = "Race " + id
			t.setup(TRACKS[id])
			t.set_meta("track_id", id)
			scene.add_child(t)
	for id in HUBS:
		if HUBS[id].scene == scene.scene_file_path and scene.get_node_or_null("Race Gate " + id) == null:
			var g := RaceTrack.new()
			g.name = "Race Gate " + id
			var cfg: Dictionary = HUBS[id].duplicate()
			cfg["hub_gate"] = true
			g.setup(cfg)
			g.set_meta("hub_id", id)
			scene.add_child(g)
	# In a circuit the clocks wait (a race doesn't use up the Shift, and the portal can't pull you home mid-lap)
	circuit = ""
	for id in TRACKS:
		if TRACKS[id].has("circuit") and TRACKS[id].scene == scene.scene_file_path:
			circuit = id
	if circuit != "":
		if Clock.running:
			Clock.running = false
			_froze_clock = true
		if _pending == "":
			_pending = circuit                        # (loaded straight in: race anyway)
	else:
		_pending = ""
		_return = {}
		if _froze_clock:
			_froze_clock = false
			Clock.running = true
	_refresh_boards.call_deferred()


func track_node(id: String) -> RaceTrack:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Race " + id) as RaceTrack if scene else null


func hub_node(id: String) -> RaceTrack:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Race Gate " + id) as RaceTrack if scene else null


func is_circuit(scene_path: String) -> bool:
	for id in TRACKS:
		if TRACKS[id].has("circuit") and TRACKS[id].scene == scene_path:
			return true
	return false


func hub_of(id: String) -> String:
	return str(TRACKS[id].get("hub", ""))


func starter_name(id: String) -> String:
	# Who to talk to for this race: a circuit's is started at its race gate
	var h := hub_of(id)
	return str(HUBS[h].starter.name) if h != "" else str(TRACKS[id].get("starter", {}).get("name", "the starter"))


func _refresh_boards() -> void:
	for id in TRACKS:
		var t := track_node(id)
		if t and t.sky and t.ready_to_race and not (racing() and track_id == id):
			t.show_race(false)                        # its start ring shows once it's open
		if t == null or t.board_text == null:
			continue
		t.board_text.text = board_text(id)
	for id in HUBS:
		var g := hub_node(id)
		if g and g.board_text:
			g.board_text.text = hub_board_text(id)


func first_prize(id: String) -> String:
	# What winning this race the first time gives you, in words ("" if nothing special)
	var e: Dictionary = Schematics.for_race(id)
	if not e.is_empty():
		return Schematics.blueprint_of(e)
	if FIRST_HATS.has(id):
		return "the %s" % _hat_name(str(FIRST_HATS[id]))
	return ""


func _hat_name(hat: String) -> String:
	return str(Shop.items.get(hat, {}).get("name", hat.capitalize()))


func champion() -> bool:
	# Every circuit won at least once
	return CHAMPION_TRACKS.all(func(k: String) -> bool: return int(wins.get(k, 0)) > 0)


func _give_hat(hat: String) -> bool:
	if Game.has_item("shop:" + hat):
		return false
	Game.items.append("shop:" + hat)                   # (worn from the wardrobe like the Champion's Cup: scripts/arena.gd)
	return true


func _prize_line(id: String, short := false) -> String:
	# The board's line about the first prize: what it is, or that it's yours (short: the gate's board, no room)
	var what := first_prize(id)
	if what == "":
		return ""
	if short:
		what = what.trim_prefix("the ").replace("'s blueprint", "").replace("' blueprint", "")
		return ("  ★ won" if int(wins.get(id, 0)) > 0 else "  ★ " + what)
	if int(wins.get(id, 0)) > 0:
		return "\n★ Won: %s" % what
	return "\n★ WIN IT for %s!" % what


func board_text(id: String) -> String:
	var tr: Dictionary = TRACKS[id]
	var prizes: Array = tr.prizes
	var blurb := str(tr.blurb)
	var out := "%s\n%s\n\n1st ✦ %d   2nd ✦ %d\n3rd ✦ %d   4th ✦ %d\n\n" % [str(tr.name).to_upper(), blurb[0].to_upper() + blurb.substr(1),
		prizes[0], prizes[1], prizes[2], prizes[3]]
	out += "Best time: %s" % (RaceHud.clock(float(best[id])) if best.has(id) else "not yet!")
	out += "\nBeat it for ✦ %d more" % BEST_BONUS if best.has(id) else ""
	out += "\nWins: %d" % int(wins.get(id, 0))
	if not tr.get("shortcuts", []).is_empty():
		out += "\nSecret shortcut: %s" % ("found!" if shortcuts_found(id) > 0 else "???")
	out += _prize_line(id)
	return out


func hub_board_text(hub: String) -> String:
	# The race gate's board: every circuit started there, open or not, with its best time
	var out := "RACES  (talk to %s)\n" % HUBS[hub].starter.name
	for id in TRACKS:
		if hub_of(id) != hub:
			continue
		var tr: Dictionary = TRACKS[id]
		out += "\n%s%s\n" % [str(tr.name).to_upper(), _prize_line(id, true)]
		if not unlocked(id):
			out += "Opens after the %s" % TRACKS[str(tr.after)].name
		else:
			out += "Best: %s   Wins: %d" % [RaceHud.clock(float(best[id])) if best.has(id) else "not yet!", int(wins.get(id, 0))]
	out += "\n\n%s" % ("★ RACE CHAMPION! ★" if champion() else "Win all four: the Champion's Helmet")
	return out


# -----------------------------------------------------------------------------
# The sky race: the mothership (scripts/mothership.gd) through rings in the air
# -----------------------------------------------------------------------------
func _ship() -> Node3D:
	return get_tree().get_first_node_in_group("mothership") as Node3D


func _watch_sky() -> void:
	# Flying the mothership through an open sky track's start ring starts its race, straight away
	var ship := _ship()
	if ship == null or not ship.is_piloted():
		_sky_side.clear()
		return
	for id in TRACKS:
		var t := track_node(id)
		if t == null or not t.sky or not t.ready_to_race or not unlocked(id):
			continue
		var c := t.point_at(0.0)
		var rel := ship.global_position - c
		var along := rel.dot(t.dir_at(0.0))
		var before := float(_sky_side.get(id, along))
		_sky_side[id] = along
		if before < 0.0 and along >= 0.0 and rel.length() < t.ring_radius + 6.0:
			start_sky(id)
			return


func fly_to_sky(id: String) -> bool:
	# From Zippy: the mothership comes down over you, beams you up, and you're at the start ring with the race on (no
	# need to find the Mothership Pad and fly through the ring yourself, though that still works)
	var t := track_node(id)
	var ship := _ship()
	var p := _player()
	if racing() or t == null or not t.sky or ship == null or p == null or not unlocked(id):
		return false
	if not ship.is_piloted():
		if int(ship.get("state")) != 0:                    # (on its way somewhere, or beaming: try again in a moment)
			return false
		ship.global_position = p.global_position + Vector3(0, float(ship.get("hover_height")), 0)
		ship.call("board", p)
		var wait := 0.0
		while is_instance_valid(ship) and not ship.is_piloted() and wait < 4.0:
			await get_tree().process_frame
			wait += get_process_delta_time()
		if not is_instance_valid(ship) or not ship.is_piloted():
			return false
	# Just behind the start ring, facing through it
	var f := t.dir_at(0.0)
	ship.global_position = t.point_at(0.0) - f * 18.0
	ship.set("velocity", f * 6.0)
	ship.rotation.y = atan2(f.x, f.z)
	p.global_position = ship.call("_seat_position")
	var arm := p.get_node_or_null("SpringArm3D") as Node3D
	if arm:
		arm.rotation.y = atan2(-f.x, -f.z)
	return start_sky(id)


func start_sky(id: String) -> bool:
	var t := track_node(id)
	var ship := _ship()
	if racing() or t == null or not t.sky or ship == null or not ship.is_piloted() or not unlocked(id):
		return false
	track_id = id
	track = t
	var pace: Array = TRACKS[id].pace
	var who: Array = TRACKS[id].rivals
	for k in who.size():
		var rival := RaceRival.new()
		rival.name = "Racer " + str(who[k].name)
		rival.saucer = who[k]
		rival.setup(str(who[k].id), t, -12.0 - 10.0 * k, [-12.0, 12.0, 0.0][k % 3], float(pace[k]))
		get_tree().current_scene.add_child(rival)
		rivals.append(rival)
	lap = 1
	last_cp = 0
	next_cp = 1
	time = 0.0
	power = ""
	place = 1
	progress = 0.0
	_wrong = 0.0
	_along = -1.0
	_rival_pad.clear()
	t.show_race(true)
	t.light_rings(1)
	hud.clear()
	if Settings.race_intros:
		state = State.INTRO
		_set_ship_frozen(true)
		intro.play(t, rivals, str(TRACKS[id].name), str(TRACKS[id].blurb))
	else:
		for r in rivals:
			r.go()
		_go_sky()
	return true


func _go_sky() -> void:
	state = State.RACING
	_along = -1.0
	hud.clear()
	hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.6)
	Audio.play("level_up")
	_status()


func _sky_boosts(ship: Node3D) -> void:
	for ring in track.pads:
		if _pad_wait.has(ring) or ship.global_position.distance_to((ring as Node3D).global_position) > 16.0:
			continue
		_pad_wait[ring] = 2.0
		ship.boost(boost_time(SKY_BOOST))
		Audio.play("swish", 0.0, 0.1)
		hud.shout("Boost!", Color(0.5, 1.0, 1.0), 0.4)


# -----------------------------------------------------------------------------
# For the map (scripts/map_screen.gd)
# -----------------------------------------------------------------------------
func map_tracks() -> Array:
	var out: Array = []
	for id in TRACKS:
		var t := track_node(id)
		if t == null or not t.ready_to_race:
			continue
		out.append({"name": TRACKS[id].name, "line": t.line, "start": t.point_at(0.0), "open": unlocked(id),
			"racing": racing() and track_id == id})
	for id in HUBS:                                   # the race gates: a flag, no route (the races are elsewhere)
		var g := hub_node(id)
		if g and g.ready_to_race:
			out.append({"name": "Races", "line": PackedVector3Array(), "start": g.point_at(g.cp_dist[0]), "open": true,
				"racing": false})
	return out


func map_next() -> Vector3:
	return track.point_at(track.cp_dist[next_cp]) if racing() and is_instance_valid(track) else Vector3.ZERO


func map_rivals() -> Array:
	return rivals.filter(func(r: RaceRival) -> bool: return is_instance_valid(r)).map(func(r: RaceRival) -> Vector3: return r.global_position)


# -----------------------------------------------------------------------------
# The starters (Zippy at the Lake Loop, and one at each other track)
# -----------------------------------------------------------------------------
func unlocked(id: String) -> bool:
	# A track opens once you've finished the one before it (any place counts)
	var needs := str(TRACKS[id].get("after", ""))
	return needs == "" or finished_once.has(needs)


func talk(talker: Node3D) -> void:
	if racing():
		return
	tutorial.gate_talked()
	var holder := talker.get_parent()                                       # the talk spot is on the starter
	if holder.has_meta("hub_id") and str(holder.get_meta("hub_id")) != "":
		var hub := str(holder.get_meta("hub_id"))
		Dialogue.say(talker, str(HUBS[hub].starter.name), hub_lines(hub), "race_starter")
		return
	var id := str(holder.get_meta("track_id", "lake_loop"))
	Dialogue.say(talker, str(TRACKS[id].starter.name), lines(id), "race_starter")


func hub_lines(hub: String) -> Array:
	# The starter at a race gate: every circuit started here that's open, and off you go to it
	var me := str(HUBS[hub].starter.name)
	if not Game.has_item("skateboard"):
		return ["Vroom vroom, {player}! I'm %s, and I start the races." % me,
			"But {they}'ll need something to ride first! There's a skateboard waiting at the Skate Park."]
	var mine: Array = TRACKS.keys().filter(func(k: String) -> bool: return hub_of(k) == hub)
	var out: Array = []
	var prizes: Array = mine.filter(func(k: String) -> bool: return unlocked(k) and first_prize(k) != "" and int(wins.get(k, 0)) == 0)
	if raced == 0:
		out.append("Vroom vroom, {player}! I'm %s, and I start the races. Each race has a whole track of its own: say which and I'll whizz you there!" % me)
		out.append("Ride through every ring, in order: the next one glows gold. Star Boxes give you a power-up: a Zoom Star, a Bubble Shield, a Super Spring, or something to throw. Press %s to use it!" % Settings.prompt("aim"))
		out.append("Watch out: the others have power-ups too, and they'll throw them at you! A Bubble Shield stops one.")
	else:
		out.append("Back for more, {player}? Which one?")
	if not prizes.is_empty():
		# The first prize for each open race not won yet: something worth racing for
		out.append("Win the %s and you get %s! Nobody else has one of those." % [TRACKS[prizes[0]].name, first_prize(prizes[0])]
			if prizes.size() == 1 else "First prizes! " + " ".join(prizes.map(func(k: String) -> String:
				return "Win the %s for %s." % [TRACKS[k].name, first_prize(k)])))
	if raced > 0 and mine.any(func(k: String) -> bool: return unlocked(k) and not TRACKS[k].get("shortcuts", []).is_empty() \
			and shortcuts_found(k) == 0):
		out.append("Psst! Every track's got a secret shortcut. Look for a %s in the wall on the inside of a bend..." %
			("patch of cornstalks" if HUBS[hub].scene == EARTH else "leafy bit"))
	var choice: Array = []
	for id in mine:
		if unlocked(id):
			choice.append({"text": "The %s!" % TRACKS[id].name, "set": "race_go_" + id})
	var locked: Array = mine.filter(func(k: String) -> bool: return not unlocked(k))
	if not locked.is_empty():
		out.append("The %s opens once you've finished the %s." % [TRACKS[locked[0]].name, TRACKS[str(TRACKS[locked[0]].after)].name])
	# The Sky Rings start up in the air, so they're easy to miss (Hayden, 14 Nov 2026: "Im not sure how to start the
	# current spaceship race if it exists"): Zippy offers them too, and calls the mothership down for you
	if HUBS[hub].scene == TOWN and Game.has_item("skateboard"):
		if unlocked("sky_rings"):
			choice.append({"text": "The Sky Rings! (in the mothership)", "set": "race_go_sky_rings"})
			if not best.has("sky_rings"):
				out.append("The Sky Rings are open! A race in the sky, in the mothership.")
		else:
			out.append("Finish the Lake Loop and I'll open the Sky Rings: a race in the sky!")
	choice.append({"text": "Not right now."})
	out.append({"choice": choice})
	return out


func lines(id := "lake_loop") -> Array:
	var tr: Dictionary = TRACKS[id]
	if tr.has("hub") and circuit != id:
		return hub_lines(str(tr.hub))
	var me := str(tr.starter.name)
	if not Game.has_item("skateboard"):
		return ["Vroom vroom, {player}! I'm %s, and I start the races here." % me,
			"But {they}'ll need something to ride first! There's a skateboard waiting at the Skate Park."]
	var out: Array = []
	if circuit == id:
		# On a circuit: race again, or back to town
		out.append("Another go round the %s, {player}?" % tr.name)
		out.append({"choice": [{"text": "Race again!", "set": "race_again"},
			{"text": "Back to %s, please." % HUBS[str(tr.hub)].place, "set": "race_leave"}, {"text": "Not yet."}]})
		return out
	if raced == 0:
		out.append("Vroom vroom, {player}! I'm %s, and I start the %s: %s!" % [me, tr.name, tr.blurb])
		out.append("Ride through every ring, in order: the next one glows gold. Boost pads zoom you along, and the Star Boxes give you a power-up. Press %s to use it!" % Settings.prompt("aim"))
		out.append("Goo puddles are slow going, so steer round them. Everyone who finishes wins sparkles!")
	else:
		out.append("Back for more, {player}? The %s is %s." % [tr.name, tr.blurb])
		if best.has(id):
			out.append("Your best time here is %s. Beat it for ✦ %d more!" % [RaceHud.clock(float(best[id])), BEST_BONUS])
	if first_prize(id) != "" and int(wins.get(id, 0)) == 0:
		out.append("Win it and you get %s! Nobody else has one of those." % first_prize(id))
	if not unlocked(id):
		out.append("This one opens once you've finished the %s. %s starts that one!" % [TRACKS[str(tr.after)].name,
			starter_name(str(tr.after))])
	var choice: Array = []
	if unlocked(id):
		choice.append({"text": "Let's race!", "set": "race_go_" + id})
	choice.append({"text": "Not right now."})
	out.append({"choice": choice})
	return out


func _on_talked(id: String) -> void:
	if id != "race_starter":
		return
	if Dialogue.flags.has("race_again"):
		Dialogue.flags.erase("race_again")
		restart.call_deferred()
		return
	if Dialogue.flags.has("race_leave"):
		Dialogue.flags.erase("race_leave")
		leave_circuit.call_deferred()
		return
	for f in Dialogue.flags.keys():
		if str(f).begins_with("race_go_"):
			Dialogue.flags.erase(f)
			var tid := str(f).trim_prefix("race_go_")
			if TRACKS.has(tid) and TRACKS[tid].has("circuit"):
				enter_circuit.call_deferred(tid)
			elif TRACKS.has(tid) and TRACKS[tid].get("sky", false):
				fly_to_sky.call_deferred(tid)
			else:
				start.call_deferred(tid)
			return


# -----------------------------------------------------------------------------
# Circuits: off to a race's own track, and back
# -----------------------------------------------------------------------------
func enter_circuit(id: String) -> bool:
	# From a race gate to the circuit (the game loads it; the race starts as soon as it's laid out)
	var p := _player()
	var scene := get_tree().current_scene
	if racing() or not TRACKS.has(id) or not TRACKS[id].has("circuit") or not unlocked(id) or p == null \
			or not Game.has_item("skateboard") or not ResourceLoader.exists(str(TRACKS[id].scene)):
		return false
	if circuit == "" and scene:
		_return = {"scene": scene.scene_file_path, "position": p.global_position,
			"yaw": (p.get_node("Visual") as Node3D).rotation.y}
		_copy_kids(id)
	_pending = id
	_pending_intro = Settings.race_intros
	Game.pending_message = ""
	Game.go(str(TRACKS[id].scene), "Entrance", str(TRACKS[id].name))
	return true


func _copy_kids(id: String) -> void:
	# Earth kids race as themselves: their looks are copied from town on the way out (the circuit has no townsfolk)
	_kids.clear()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var want: Array = TRACKS[id].rivals + TRACKS[id].get("spares", [])
	for r in scene.find_children("Routine", "", true, false):
		var who := str(r.get("character_id"))
		if who in want and r.get_parent() is Townsfolk:
			var t := r.get_parent() as Townsfolk
			_kids[who] = {"look": t.look, "outfit": t.outfit, "model_path": t.model_path, "extras": t.extras, "name": str(t.name)}


func kid_look(id: String) -> Dictionary:
	# An Earth kid's look for racing: copied from town if we can, else a stand-in (KID_LOOKS)
	if _kids.has(id):
		return _kids[id]
	var k: Dictionary = KID_LOOKS.get(id, KID_LOOKS.nina_earth)
	return {"look": {"colors": k.colors, "hairstyle": int(k.hairstyle), "extras": false, "height": 0.95, "head": 1.0,
		"build": 1.0}, "outfit": {}, "model_path": "", "extras": [], "name": str(k.name)}


func leave_circuit() -> void:
	# Back to where you set off from (the race gate), whatever's going on
	if circuit == "":
		return
	if racing():
		_end(false)
	_close_choice()
	var hub: Dictionary = HUBS[hub_of(circuit)]
	var to := _return.duplicate()
	if to.is_empty():                                  # (came straight in: back to the race gate)
		var at: Vector2 = hub.at
		var f := (Vector2(hub.toward) - at).normalized()
		var side := Vector2(-f.y, f.x)
		var spot := at - f * 2.0 + side * 6.0
		to = {"scene": hub.scene, "position": Vector3(spot.x, 2.0, spot.y), "yaw": atan2(f.x, f.y)}
	_pending = ""
	Game.pending_message = "Back in %s, by the race gate." % hub.place
	Game.go_to_point(str(to.scene), to.position, float(to.yaw), str(hub.place))


func restart() -> bool:
	# "Race again": the same circuit, straight to the countdown (no intro the second time)
	if circuit == "":
		return false
	if racing():
		_end(false)
	_close_choice()
	return start(circuit, false)


func save_place() -> Dictionary:
	# Saving on a circuit saves you back at the race gate (scripts/game.gd): loading never drops you mid-race
	if circuit == "":
		return {}
	var to := _return
	if to.is_empty():
		var hub: Dictionary = HUBS[hub_of(circuit)]
		to = {"scene": hub.scene, "position": Vector3(Vector2(hub.at).x, 2.0, Vector2(hub.at).y + 6.0), "yaw": 0.0}
	var pos: Vector3 = to.position
	return {"scene": str(to.scene), "position": [pos.x, pos.y, pos.z], "yaw": float(to.yaw)}


func _offer_choice(text: String) -> void:
	# The results (or "race called off") with buttons: race again, or go back
	_choosing = true
	var p := _player()
	if p:
		Game.hold_controls(&"race_results", true, p)
	hud.show_choices(text, [["Race again", func() -> void: restart()],
		["Back to %s" % HUBS[hub_of(circuit)].place, func() -> void: leave_circuit()]])


func _close_choice() -> void:
	if not _choosing:
		return
	_choosing = false
	hud.hide_choices()
	var p := _player()
	if p:
		Game.hold_controls(&"race_results", false, p)


# -----------------------------------------------------------------------------
# A race
# -----------------------------------------------------------------------------
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func start(id: String, with_intro := true) -> bool:
	var t := track_node(id)
	var p := _player()
	if racing() or t == null or not t.ready_to_race or p == null or not Game.has_item("skateboard") or not unlocked(id):
		return false
	_close_choice()
	track_id = id
	track = t
	_coin_got.clear()
	if not Game.riding:
		Game.riding = true
		Game.equipment_changed.emit()
	# The grid, just behind the line. On a circuit you're fifth of eight, in the middle of the pack; on the old tracks
	# you're at the front on the left, the others beside and behind.
	var big: bool = TRACKS[id].rivals.size() > 3
	var grid: Array = GRID if big else OLD_GRID
	var mine := 4 if big else 0
	var start_at := t.point_at(grid[mine][0]) + t.side_at(grid[mine][0]) * float(grid[mine][1])
	var ground := t.ground_at(Vector2(start_at.x, start_at.z))
	var f := t.dir_at(0.0)
	p.global_position = ground + Vector3.UP * 0.85
	p.velocity = Vector3.ZERO
	var yaw := atan2(f.x, f.z)
	p.visual.rotation.y = yaw
	var skate = p.get("skate")
	skate.set("_yaw", yaw)
	skate.set("_shown_yaw", yaw)
	skate.set("fakie", false)
	skate.set("_boost_time", 0.0)                         # a boost from a booster on the way here (scripts/boosters.gd)
	skate.set("_boost_fade", 0.0)                         # ...doesn't carry her over the line before GO
	p.spring_arm.rotation.y = atan2(-f.x, -f.z)
	Game.hold_controls(&"race", true, p)
	# The friends lining up
	var who: Array = []
	var gone := _gone_home(id)
	for r in TRACKS[id].rivals:
		who.append(r if r != p.get("rider") and not r in gone else "")
	for k in who.size():
		if who[k] == "":
			for spare in TRACKS[id].get("spares", SPARE_RIVALS):
				if not spare in who and spare != p.get("rider") and not spare in gone:
					who[k] = spare
					break
	who = who.filter(func(w) -> bool: return str(w) != "")
	var pace := float(PACE_BY_ASSIST[clampi(Settings.skate_assist, 0, PACE_BY_ASSIST.size() - 1)])
	var paces: Array = CIRCUIT_PACE if big else RIVAL_PACE
	var slots: Array = range(grid.size()).filter(func(k: int) -> bool: return k != mine)
	for k in who.size():
		var rival := RaceRival.new()
		rival.name = "Racer " + str(who[k])
		var push := float(ride_of(who[k]).push_speed)
		var slot: int = slots[k]
		rival.setup(who[k], t, float(grid[slot][0]), float(grid[slot][1]), float(paces[mini(k, paces.size() - 1)]) * pace / push)
		get_tree().current_scene.add_child(rival)
		rivals.append(rival)
		_show_npc(who[k], false)
	lap = 1
	last_cp = 0
	next_cp = 1
	time = 0.0
	power = "zoom" if level("starter") > 0 else ""
	place = 1
	progress = grid[mine][0]
	_shield = 0.0
	_wrong = 0.0
	_last_d = 0.0
	_along = -1.0
	_sc = -1
	_sc_done = false
	_knock_safe = 0.0
	_rival_pad.clear()
	attacks.clear()
	t.show_race(true)
	hud.clear()
	hud.show_map(t)
	if not t.sky:
		tutorial.begin()                          # the first race teaches as you go (scripts/race_tutorial.gd)
	if Settings.race_intros and with_intro:
		state = State.INTRO                       # the cutscene first (scripts/race_intro.gd), then the countdown
		intro.play(t, rivals, str(TRACKS[id].name), str(TRACKS[id].blurb))
	else:
		_begin_countdown()
	return true


func _begin_countdown() -> void:
	state = State.COUNTDOWN
	_count = COUNTDOWN
	hud.clear()
	hud.show_power(POWERS[power].name if power != "" else "")
	hud.shout("3", Color(1.0, 0.85, 0.3), 0.5)
	Audio.play("ui_move")
	_status()


func _after_intro() -> void:
	# The cutscene's over (or skipped): on the ground the countdown starts; in the sky, the race is on straight away
	if state != State.INTRO:
		return
	if track and track.sky:
		_set_ship_frozen(false)
		for r in rivals:
			r.go()
		_go_sky()
	else:
		_begin_countdown()


func _set_ship_frozen(on: bool) -> void:
	# The mothership holds still in the air while the sky race's intro plays
	var ship := _ship()
	if ship:
		ship.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _physics_process(delta: float) -> void:
	_tick_pads(delta)
	_knock_safe -= delta
	if state == State.IDLE:
		_watch_sky()
		if _pending != "" and not _choosing:
			var t := track_node(_pending)
			if t and t.ready_to_race and _player() != null:
				var id := _pending
				_pending = ""
				start(id, _pending_intro)
				_pending_intro = Settings.race_intros
	match state:
		State.INTRO:
			var p := _player()
			if p == null:
				_end(false)
			elif not track.sky:
				p.velocity = Vector3.ZERO
				Game.hold_controls(&"race", true, p)
		State.COUNTDOWN:
			_countdown(delta)
		State.RACING:
			_race(delta)
		State.RESULTS:
			_results -= delta
			for r in rivals:
				r.race(delta, progress)
			attacks.tick(delta, true)
			if _results <= 0.0 and circuit == "":
				_end(true)


func _countdown(delta: float) -> void:
	var p := _player()
	if p == null:
		_end(false)
		return
	p.velocity = Vector3.ZERO
	Game.hold_controls(&"race", true, p)
	var before := ceili(_count)
	_count -= delta
	var now := ceili(_count)
	if now != before and now > 0:
		hud.shout(str(now), Color(1.0, 0.85, 0.3), 0.5)
		Audio.play("ui_move")
		Juice.blip("tick", 1.0, -6.0)
		Juice.rumble(0.15, 0.06)
	if _count <= 0.0:
		state = State.RACING
		Game.hold_controls(&"race", false, p)
		for r in rivals:
			r.go()
		hud.shout("GO!", Color(0.5, 1.0, 0.6), 0.5)
		Audio.play("level_up")
		Juice.blip("tick", 1.5, -4.0)
		Juice.shake(0.15)
		Juice.rumble(0.4, 0.15)


func _race(delta: float) -> void:
	var p := _player()
	if p == null:
		_end(false)
		return
	var t := track
	var ship := _ship()
	if t.sky:
		if ship == null or not ship.is_piloted():
			Game.message("You left the mothership, so the sky race is off. Fly through the gold ring to race again!")
			_end(false)
			return
	elif not Game.riding:
		if circuit != "":
			Game.riding = true                        # (on a circuit there's nowhere to walk to: straight back on)
			Game.equipment_changed.emit()
		else:
			Game.message("You stepped off your ride, so the race is off. Talk to the starter to race again!")
			_end(false)
			return
	time += delta
	var L := t.length
	var cps := t.cp_dist
	var pos := ship.global_position if t.sky else p.global_position
	var vel: Vector3 = ship.velocity if t.sky else p.velocity
	# Through the next ring? Either close to its middle, or across its line (fast riders can be between frames)
	# In a secret shortcut (scripts/race_circuit.gd)? Then the road's rules wait till you're back out on it
	var inside := circuit != "" and _in_shortcut(t, pos)
	var cp_d := cps[next_cp]
	var cp_pos := t.point_at(cp_d)
	var cp_dir := t.dir_at(cp_d)
	var rel := pos - cp_pos
	var along := rel.dot(cp_dir)
	var side := absf(rel.dot(t.side_at(cp_d)))
	var reach := t.ring_radius + 4.0 if t.sky else PASS_RADIUS
	var close := rel.length() if t.sky else Vector2(rel.x, rel.z).length()
	var through := close < reach or (_along < 0.0 and along >= 0.0 and side < reach + 2.0 and absf(rel.y) < (t.ring_radius if t.sky else 6.0))
	_along = along
	if through and not inside:
		_pass_checkpoint()
		if state != State.RACING:
			return
	# How far round: between the last checkpoint passed and the next
	var lo := cps[last_cp]
	var hi := cps[next_cp] if next_cp != 0 else L
	if inside:
		# (Through a shortcut, you're as far round as how far through it you are)
		var sc: Dictionary = _circuit_node().shortcuts[_sc]
		var f: float = _circuit_node().shortcut_progress(_sc, pos)
		if _sc_ok:
			progress = (lap - 1) * L + lerpf(float(sc.d0), float(sc.d1), f)
		_wrong = 0.0
	else:
		var raw := t.nearest(pos, (lo + hi) / 2.0, (hi - lo) / 2.0 + 20.0)
		var round_d := wrapf(raw - lo, -L / 2.0, L / 2.0)          # the loop wraps round at the line
		var here := lo + clampf(round_d, 0.0, hi - lo)
		progress = (lap - 1) * L + here
		# Going the wrong way for a while?
		var speed := Vector2(vel.x, vel.z).length()
		var fwd := Vector2(vel.x, vel.z).dot(Vector2(t.dir_at(here).x, t.dir_at(here).z))
		_wrong = _wrong + delta if speed > 3.0 and fwd < -2.0 else 0.0
		if _wrong > 1.2:
			_wrong = -2.0
			hud.shout("Wrong way!", Color(1.0, 0.55, 0.6), 0.6)
		# (How far off the road is measured from the nearest bit of road, even behind the last ring: on the grid you're
		# behind the line, and that's fine.)
		var near := fposmod(lo + clampf(round_d, -20.0, hi - lo), L)
		if circuit != "" and _sc < 0 and (t.off_line(pos, near) > t.width / 2.0 + 4.0 or pos.y < t.point_at(near).y - 5.0):
			# Over a wall, or off the edge: popped back on the road, a little short of the next ring so it isn't passed
			_back_on_track(p, fposmod(lo + clampf(round_d, -10.0, maxf(0.0, hi - lo - PASS_RADIUS - 2.0)), L))
		elif _sc < 0 and t.off_line(pos, here) > WANDER * (3.0 if t.sky else 1.0):
			Game.message("You went off the track, so the race is off. %s" % ("Fly through the gold ring to race again!" if t.sky else "Talk to the starter to race again!"))
			_end(false)
			return
	if t.sky:
		_sky_boosts(ship)
	else:
		_pick_up(p, t)
		_take_coins(p, t)
		_use_power(p)
		_tick_shield(p, delta)
		attacks.tick(delta)
	for r in rivals:
		r.race(delta, progress)
		_rival_pads(r)
		if not r.finished and r.d >= t.laps_length(int(TRACKS[track_id].laps)):
			r.finished = true
			r.finish_time = time
	place = 1
	for r in rivals:
		if r.d > progress:
			place += 1
	_status()


func _circuit_node() -> Node:
	var c := get_tree().current_scene
	return c if c != null and "shortcuts" in c else null


func _in_shortcut(t: RaceTrack, pos: Vector3) -> bool:
	# Secret shortcuts (scripts/race_circuit.gd): true while you're inside one, away from its mouths. Going in at its
	# front from the right bit of the lap and out of its far end moves you on past the rings it skips, as if you'd gone
	# round. (Going in at the far end just leads back, and the road's rules carry on once you're out.)
	var c := _circuit_node()
	if c == null or c.shortcuts.is_empty():
		return false
	var k: int = c.shortcut_at(pos)
	if k < 0:
		_sc = -1
		return false
	var sc: Dictionary = c.shortcuts[k]
	var f: float = c.shortcut_progress(k, pos)
	if _sc != k:
		_sc = k
		_sc_ok = f < 0.3 and last_cp >= int(floor(float(sc.from))) and last_cp < int(floor(float(sc.to)))
		_sc_done = false
	if f > 0.88 and _sc_ok and not _sc_done:
		_took_shortcut(t, k)
	return f > 0.12 and f < 0.88


func _took_shortcut(t: RaceTrack, k: int) -> void:
	var sc: Dictionary = _circuit_node().shortcuts[k]
	_sc_done = true
	last_cp = int(floor(float(sc.to)))
	next_cp = (last_cp + 1) % t.cp_dist.size()
	_along = -1.0
	t.light_rings(next_cp)
	var flag := "race_shortcut_%s_%d" % [track_id, k]
	if not Dialogue.flags.has(flag):
		Dialogue.set_flag(flag)
		hud.shout("SECRET SHORTCUT!", Color(0.5, 1.0, 0.6), 1.2)
		Game.add_sparkles(SHORTCUT_PRIZE, "You found the %s's secret shortcut!" % TRACKS[track_id].name)
		Audio.play("level_up", -2.0)
	else:
		hud.shout("Shortcut!", Color(0.5, 1.0, 0.6), 0.6)
		Audio.play("bloop", -2.0, 0.2)


func shortcuts_found(id: String) -> int:
	var n := 0
	for k in TRACKS[id].get("shortcuts", []).size():
		if Dialogue.flags.has("race_shortcut_%s_%d" % [id, k]):
			n += 1
	return n


func _pass_checkpoint() -> void:
	var t := track
	var cps := t.cp_dist
	last_cp = next_cp
	next_cp = (next_cp + 1) % cps.size()
	_along = -1.0
	Audio.play("bloop", -4.0, 0.1)
	if last_cp == 0:
		if lap >= int(TRACKS[track_id].laps):
			_finish()
			return
		lap += 1
		hud.shout("Final lap!" if lap == int(TRACKS[track_id].laps) else "Lap %d!" % lap, Color(0.75, 0.9, 1.0), 0.6)
		Audio.play("level_up", -4.0)
	t.light_rings(next_cp)


func _status() -> void:
	hud.show_status(lap, int(TRACKS[track_id].laps), place, rivals.size() + 1, time)


func _finish() -> void:
	# Over the line: places as they stand (friends already home are ahead), sparkles for everyone, a bonus for a best
	var laps_l := track.laps_length(int(TRACKS[track_id].laps))
	place = 1
	for r in rivals:
		if r.finished:
			place += 1
	var prizes: Array = TRACKS[track_id].prizes
	var prize := int(prizes[clampi(place - 1, 0, prizes.size() - 1)])
	var old_best := float(best.get(track_id, 0.0))
	var new_best := old_best <= 0.0 or time < old_best
	var bonus := BEST_BONUS if new_best and old_best > 0.0 else 0
	if new_best:
		best[track_id] = time
	var first_win := place == 1 and int(wins.get(track_id, 0)) == 0
	var was_champion := champion()
	if place == 1:
		wins[track_id] = int(wins.get(track_id, 0)) + 1
	var opens := TRACKS.keys().filter(func(k: String) -> bool: return str(TRACKS[k].get("after", "")) == track_id and not finished_once.has(track_id))
	finished_once[track_id] = true
	raced += 1
	Game.add_sparkles(prize + bonus, "%s in the %s!" % [RaceHud.ordinal(place), TRACKS[track_id].name])
	# The table: friends not home yet get the time they're on course for
	var rows: Array = [["You", time]]
	for r in rivals:
		var t_est := r.finish_time if r.finished else time + maxf(laps_l - r.d, 0.0) / maxf(r.speed, 4.0)
		rows.append([r.display_name(), maxf(t_est, time + 0.1) if not r.finished else t_est])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	# Your row stays where you really finished, whatever the guesses say
	rows.erase(rows.filter(func(row: Array) -> bool: return row[0] == "You")[0])
	rows.insert(place - 1, ["You", time])
	var text := "%s\n\n" % ("You won!" if place == 1 else "You came %s!" % RaceHud.ordinal(place))
	for k in rows.size():
		text += "%s   %s   %s\n" % [RaceHud.ordinal(k + 1), rows[k][0], RaceHud.clock(float(rows[k][1]))]
	text += "\nPrize: ✦ %d" % prize
	if bonus > 0:
		text += "\nNew best time! ✦ %d more" % bonus
	elif new_best:
		text += "\nYour first best time: %s" % RaceHud.clock(time)
	for k in opens:
		text += "\nThe %s is open now!" % TRACKS[k].name
	text += _first_prizes(first_win, was_champion)
	hud.shout("FINISH!", Color(1.0, 0.85, 0.3), 0.8)
	if circuit != "":
		_offer_choice(text)                           # on a circuit: race again, or go back (no hurry)
	else:
		hud.show_results(text)
	Audio.play("level_up")
	state = State.RESULTS
	_results = RESULTS_TIME
	for r in rivals:
		r.finished = true                             # a slow lap of honour while the results are up
	_clear_power()
	track.show_race(false)
	_refresh_boards()
	tutorial.finish()
	finished.emit(track_id, place)


func _first_prizes(first_win: bool, was_champion: bool) -> String:
	# A first win's prize (once ever, per race), and the Champion's Helmet for the last of the four circuits
	var text := ""
	if first_win:
		var e: Dictionary = Schematics.for_race(track_id)
		if not e.is_empty() and Schematics.award(str(e.id), true):
			text += "\n★ FIRST WIN PRIZE: %s! Dash can build it now." % Schematics.blueprint_of(e)
		elif FIRST_HATS.has(track_id) and _give_hat(str(FIRST_HATS[track_id])):
			text += "\n★ FIRST WIN PRIZE: the %s! Wear it from your wardrobe." % _hat_name(str(FIRST_HATS[track_id]))
	if not was_champion and champion() and _give_hat(CHAMPION_HAT):
		text += "\n★ All four circuits won: RACE CHAMPION! The %s is yours." % _hat_name(CHAMPION_HAT)
	return text


func _end(_done: bool) -> void:
	# Back to riding about: the friends ride off home (back in their usual places), the rings go
	for r in rivals:
		if is_instance_valid(r):
			_show_npc(r.id, true)
			r.queue_free()
	rivals.clear()
	_clear_power()
	attacks.clear()
	flow.stop()
	_coin_got.clear()
	hud.show_map(null)
	if is_instance_valid(track):
		track.show_race(false)
	var p := _player()
	if p:
		Game.hold_controls(&"race", false, p)
	if state == State.INTRO:
		intro.stop()
		_set_ship_frozen(false)
	state = State.IDLE
	hud.clear()
	_refresh_boards()


# -----------------------------------------------------------------------------
# Boost pads, Star Boxes, goo and power-ups
# -----------------------------------------------------------------------------
func _tick_pads(delta: float) -> void:
	# Boost pads work any time someone rides over them, race or no race
	for pad in _pad_wait.keys():
		_pad_wait[pad] = float(_pad_wait[pad]) - delta
		if float(_pad_wait[pad]) <= 0.0:
			_pad_wait.erase(pad)
	_goo_wait -= delta
	var p := _player()
	if p == null or not Game.riding:
		return
	var skate = p.get("skate")
	for id in TRACKS:
		var t := track_node(id)
		if t == null or t.sky:
			continue
		for pad in t.pads:
			if _pad_wait.has(pad) or not _over(p.global_position, (pad as Node3D).global_position, PAD_RADIUS, 1.5):
				continue
			_pad_wait[pad] = 1.0
			skate.call("boost", PAD_SPEED, boost_time(PAD_TIME))
			Audio.play("swish", 0.0, 0.1)
			Juice.blip("whoosh", 1.2, -8.0)
			Juice.shake(0.12)
			Juice.rumble(0.3, 0.2)
			Juice.burst(p.get_parent(), p.global_position + Vector3(0, 0.3, 0), Color(0.5, 1.0, 1.0, 0.8), 12, 0.06, 3.0, 0.5)
			skate.hud.shout("Boost!", Color(0.5, 1.0, 1.0))


func _over(a: Vector3, b: Vector3, radius: float, height: float) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < radius and absf(a.y - 0.8 - b.y) < height


func _pick_up(p: Player, t: RaceTrack) -> void:
	for box in t.boxes:
		if float((box as Node3D).get_meta("gone", 0.0)) > 0.0 or not _over(p.global_position, (box as Node3D).global_position, BOX_RADIUS, 2.5):
			continue
		(box as Node3D).set_meta("gone", 5.0)
		if power != "":
			continue                                  # already holding one: the box just pops
		power = _roll_power()
		hud.show_power(POWERS[power].name)
		Audio.play("pickup")
		Juice.blip("sparkle", 1.2, -9.0)
		Juice.burst(p.get_parent(), (box as Node3D).global_position, Color(1.0, 0.85, 0.35), 14, 0.07, 3.0, 0.6)
		Juice.rumble(0.2, 0.08)
	for g in t.goo:
		if _over(p.global_position, (g as Node3D).global_position, GOO_RADIUS, 1.0):
			goo_hit(p)
			break


func _take_coins(p: Player, t: RaceTrack) -> void:
	# Speed coins: each a little push; all of one set (without missing one) and you're in the flow. A set starts
	# counting again once its coins have all come back.
	for si in t.coin_sets.size():
		var cs: Array = t.coin_sets[si]
		var all_back := true
		for c in cs:
			all_back = all_back and float((c as Node3D).get_meta("gone", 0.0)) <= 0.0
		if all_back:
			_coin_got.erase(si)
		for c in cs:
			var coin := c as Node3D
			if float(coin.get_meta("gone", 0.0)) > 0.0 or not coin.visible or not _over(p.global_position, coin.global_position, COIN_RADIUS, 2.0):
				continue
			coin.set_meta("gone", COIN_BACK)
			var got := int(_coin_got.get(si, 0)) + 1
			_coin_got[si] = got
			var skate = p.get("skate")
			skate.call("boost", COIN_SPEED, COIN_TIME)
			Juice.chime_pickup()
			Juice.burst(p.get_parent(), coin.global_position + Vector3.UP * 1.2, Color(1.0, 0.85, 0.3), 8, 0.06, 2.5, 0.4)
			if got >= cs.size():
				flow.start()
				skate.hud.shout("FLOW!", Color(0.85, 0.6, 1.0))
				Audio.play("level_up", -4.0)
				Juice.rumble(0.35, 0.25)
				Juice.burst(p.get_parent(), p.global_position + Vector3.UP, Color(0.75, 0.55, 1.0), 24, 0.08, 4.0, 0.7)
			else:
				skate.hud.shout("Coins %d/%d" % [got, cs.size()], Color(1.0, 0.85, 0.35))


func goo_hit(p: Player) -> void:
	# Rolling through goo (the track's own, or a Goo Bomb): slow going, unless shielded or boosting
	var skate = p.get("skate")
	if _goo_wait > 0.0 or not bool(skate.call("is_on_ground")):
		return
	_goo_wait = 1.5
	if _shield > 0.0 or bool(skate.call("boosting")):
		skate.hud.shout("Whoosh!", Color(0.7, 0.95, 1.0))
	else:
		skate.call("gooed", 1.3)
		skate.hud.shout("Gloopy!", Color(0.7, 0.95, 0.35))
		Audio.play("stomp", -4.0)


func _roll_power() -> String:
	# Further back, more Zoom Stars and Bubble Seekers: they help you catch up. Out in front, more Goo Bombs to drop
	# behind you and Bubble Shields.
	var weights: Dictionary
	var racers := rivals.size() + 1
	if racers <= 4:
		weights = {"zoom": 40, "seeker": 20, "shield": 20, "spring": 10, "goo": 5, "zap": 5} if place > 2 \
			else {"zoom": 25, "shield": 30, "spring": 20, "goo": 15, "zap": 10}
	elif place <= 2:
		weights = {"goo": 30, "shield": 30, "zap": 18, "zoom": 12, "spring": 10}
	elif place >= racers - 1:
		weights = {"zoom": 35, "seeker": 35, "shield": 12, "zap": 12, "spring": 6}
	else:
		weights = {"seeker": 28, "zoom": 22, "goo": 16, "shield": 14, "zap": 14, "spring": 6}
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := _rng.randi() % total
	for k in weights:
		roll -= int(weights[k])
		if roll < 0:
			return k
	return "zoom"


func _use_power(p: Player) -> void:
	if power == "" or p.get("input_locked") or not Input.is_action_just_pressed("aim"):
		return
	use_power()


func use_power() -> bool:
	# Use what's held. The Super Spring needs the ground under you, so in the air it waits.
	var p := _player()
	if power == "" or p == null:
		return false
	var skate = p.get("skate")
	match power:
		"zoom":
			skate.call("boost", ZOOM_SPEED, boost_time(ZOOM_TIME))
			Audio.play("swish")
		"shield":
			_shield = SHIELD_TIME
			skate.set("shielded", true)
			_add_bubble(p)
			Audio.play("bubbles")
		"spring":
			if not bool(skate.call("is_on_ground")):
				return false
			skate.call("spring", SPRING_POWER)
			Audio.play("boing")
		"goo", "seeker", "zap":
			attacks.fire(p, power)                    # thrown at the others (scripts/race_attacks.gd)
	skate.hud.shout(POWERS[power].say, Color(1.0, 0.85, 0.3))
	power = ""
	hud.show_power("")
	return true


func knock_player(why := "Bonk!") -> bool:
	# Something got you: a friend's Bubble Seeker or Zap Ring, a sweeper, a zapper. The Bubble Shield takes it for
	# you (and pops); otherwise it's a comedy wipeout (no harm, you're up again in a moment).
	var p := _player()
	if p == null or _knock_safe > 0.0 or not Game.riding:
		return false
	var skate = p.get("skate")
	if _shield > 0.0:
		_clear_shield(p)
		_knock_safe = 1.0
		skate.hud.shout("Shield popped!", Color(0.6, 0.9, 1.0))
		Audio.play("bubbles", -2.0)
		return false
	if bool(skate.call("is_bailing")):
		return false
	_knock_safe = KNOCK_SAFE
	skate.call("bail")
	hud.shout(why, Color(1.0, 0.55, 0.6), 0.5)
	return true


func knock_safe() -> bool:
	return _knock_safe > 0.0


func shielded() -> bool:
	return _shield > 0.0


func _back_on_track(p: Player, d: float) -> void:
	# Off the road on a circuit (over a wall after a ramp, say): back on it, facing the right way, still going
	var t := track
	var at := t.point_at(d)
	var f := t.dir_at(d)
	p.global_position = t.ground_at(Vector2(at.x, at.z)) + Vector3.UP * 0.9
	p.velocity = f * 5.0
	var yaw := atan2(f.x, f.z)
	p.visual.rotation.y = yaw
	var skate = p.get("skate")
	skate.set("_yaw", yaw)
	skate.set("_shown_yaw", yaw)
	skate.set("fakie", false)
	p.spring_arm.rotation.y = atan2(-f.x, -f.z)
	hud.shout("Back on track!", Color(0.75, 0.9, 1.0), 0.4)
	_along = -1.0


func _tick_shield(p: Player, delta: float) -> void:
	if _shield <= 0.0:
		return
	_shield -= delta
	if _bubble:
		_bubble.scale = Vector3.ONE * (1.0 + sin(time * 8.0) * 0.03)
		_bubble.visible = _shield > 1.5 or fmod(_shield, 0.3) > 0.12 or Settings.reduce_flashing
	if _shield <= 0.0:
		_clear_shield(p)


func _add_bubble(p: Player) -> void:
	if _bubble:
		return
	_bubble = MeshInstance3D.new()
	_bubble.name = "Bubble Shield"
	var s := SphereMesh.new()
	s.radius = 1.25
	s.height = 2.5
	(_bubble as MeshInstance3D).mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.9, 1.0, 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.6, 0.9, 1.0)
	m.emission_energy_multiplier = 0.6
	m.rim_enabled = true
	m.rim = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	(_bubble as MeshInstance3D).material_override = m
	(_bubble as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position.y = 0.2
	p.add_child(_bubble)


func _clear_shield(p: Player) -> void:
	_shield = 0.0
	if p:
		var skate = p.get("skate")
		if skate:
			skate.set("shielded", false)
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


func _clear_power() -> void:
	power = ""
	_clear_shield(_player())
	hud.show_power("")


func _rival_pads(r: RaceRival) -> void:
	# Friends get boosted by the pads they ride over too (and the saucers by the boost rings in the sky)
	for pad in track.pads:
		if _rival_pad.get(r) == pad:
			continue
		var gap := r.global_position.distance_to((pad as Node3D).global_position) if track.sky else \
			Vector2(r.global_position.x - (pad as Node3D).global_position.x, r.global_position.z - (pad as Node3D).global_position.z).length()
		if gap < (16.0 if track.sky else 2.5):
			_rival_pad[r] = pad
			r.boost(PAD_TIME)


# -----------------------------------------------------------------------------
func _gone_home(id := "") -> Array:
	# Friends who can't race in the Void any more: Dash, Rex and Rook, once everyone's home and they live in Lumen City
	# (scripts/after_the_ending.gd). They still race their own Skyway Run, in the Far Future
	if not Dialogue.flags.has("dash_goodbye") or str(TRACKS.get(id, {}).get("scene", "")) == FAR_FUTURE:
		return []
	return ["dash", "rex", "rook"]


func _show_npc(id: String, on: bool) -> void:
	# A friend racing steps out of their usual place in town while they race (the same as scenes/player/player.gd)
	var scene := get_tree().current_scene
	if scene == null:
		return
	for r in scene.find_children("Routine", "", true, false):
		if r.get("character_id") != id:
			continue
		for n in [r.get_parent(), r.get("_bike")]:
			if n is Node3D:
				(n as Node3D).visible = on
				(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
