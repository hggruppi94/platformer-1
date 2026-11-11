extends "res://scripts/requests.gd"

# Autoload "EarthJobs": the notice board on Earth's town green, by the gazebo's steps. It's Void's nightly request
# board (scripts/requests.gd) with Earth's own jobs: every Earth day three cards go up, one easy, one medium and one
# harder, never the same kind twice, each paying sparkles (the one money the player has, on Earth too: Stars Hollow's
# shops take them, see shop/items.json). Jobs left undone just come down at midnight, with no penalty; finished ones
# not yet turned in are paid then.
#
# The jobs, all round the town the player already walks and skates through:
# - "deliver": take a parcel from a shop's door (a box of rolls from the bakery, a library book...) to someone in town.
# - "rake": rake the leaf piles round a house on Maple Lane: walk (or skate) through each pile to sweep it up.
# - "cat": find someone's cat, hiding somewhere about town, glowing eyes and all. It follows you home.
# - "bakery": pick pumpkins at the pumpkin patch for Poppy's pies, then take them to her.
# - "grind" and "combo" (once there's a board to ride): the skating ones, as in the Void, done on Earth.
# In winter (r.winter, set when the job's made) raking is shovelling snow drifts, Poppy wants winterberries from the
# Snowman Field (the pumpkin patch under snow) instead of pumpkins, and there's a winter-only kind:
# - "snowman": build snowmen on the town green for the Frost Fair: walk into a big snowball and up pops a snowman.
# In summer (r.summer) raking is watering the thirsty flowers round a house (walk into a droopy one and it perks up),
# Poppy wants baskets of strawberries from the Sunflower Field (the pumpkin patch in summer) for her shortcakes, and
# there's a summer-only kind:
# - "sandcastle": build sandcastles on the beach at Willow Pond for the Summer Fair (scripts/summer_splash.gd
#   CASTLE_SPOTS): walk into a heap of sand and up pops a sandcastle.
# In spring (r.spring) raking is planting tulip bulbs round a house (walk into each little dug hole and a tulip pops
# up), Poppy wants bundles of rhubarb from the Tulip Field (the pumpkin patch in spring) for her rhubarb tarts, and the
# diner's pumpkin pie is a rhubarb crumble.
# Talking to the person a delivery, cat or pumpkins are for finishes it (Dialogue.finished), and Interact at the board
# turns finished jobs in. Saved as "earth_jobs" (scripts/game.gd). Leaf piles, pumpkins and the cat are put in the
# Earth scene while a job wants them (scripts/earth_job_prop.gd), so the town's builder doesn't change.

const SummerSplash := preload("res://scripts/summer_splash.gd")   # (the beach, for the sandcastle job)
const BOARD_AT := Vector3(-3.7, 0, 6.6)     # on the green, beside the gazebo's steps, facing the street to the south
const EARTH_KINDS := {
	"deliver": {"easy": 1, "medium": 1},
	"rake": {"easy": 4, "medium": 6, "hard": 9},             # leaf piles
	"cat": {"medium": 1, "hard": 1},
	"bakery": {"easy": 3, "medium": 5, "hard": 7},           # pumpkins
	"grind": {"medium": 10, "hard": 20},                     # metres, in one grind
	"combo": {"medium": 1500, "hard": 3000},                 # points, in one combo
	"snowman": {"easy": 2, "medium": 3, "hard": 4},          # snowmen on the green (winter only)
	"sandcastle": {"easy": 2, "medium": 3, "hard": 4},       # sandcastles on Willow Pond's beach (summer only)
}
# Where the snowballs for the snowmen wait: round the town green, inside its ring of grass (x, z)
const SNOWMAN_SPOTS := [Vector2(8.5, -3.0), Vector2(6.0, -8.5), Vector2(-1.5, -10.0), Vector2(-8.0, -6.5),
	Vector2(-10.0, 1.0), Vector2(-8.0, 7.5), Vector2(4.0, 9.5), Vector2(9.5, 5.0)]
# Who's who on Earth: dialogue id -> what the board calls them (names made up for Hayden to rename, like the people)
const PEOPLE := {"gus": "Gus", "dottie": "Dottie", "barnaby": "Barnaby", "marigold": "Miss Marigold", "poppy": "Poppy",
	"otis": "Mr. Gumdrop", "wren": "Mrs. Wren", "hank": "Hank", "kip": "Kip", "lionel": "Mr. Page", "juniper": "Juniper",
	"ozzie": "Ozzie", "ivy": "Miss Ivy", "theo": "Theo", "palmer_earth": "Mr. Palmer", "nina_earth": "Nina"}
# Parcels: id, what it is, the place (routines/earth_places.json) it waits at, the shop, and who it's from (never
# sent to themselves)
const PARCELS := [
	["rolls", "a box of cinnamon rolls", "bakery_door", "the bakery", "poppy"],
	["library_book", "a library book", "library_steps", "the library", "marigold"],
	["bulbs", "a bag of light bulbs", "hardware", "the hardware store", "hank"],
	["diner_pie", "a pumpkin pie", "diner", "the Hollow Diner", "gus"],
	["yoyo", "a glow-in-the-dark yo-yo", "toy_shop_door", "the toy shop", "otis"],
	["teapot", "a tiny teapot", "antiques", "the antiques shop", "wren"],
]
# Houses whose leaves need raking: the house's node, and the family on its mailbox
const YARDS := [["Maple House 1", "Hollis"], ["Maple House 2", "Okafor"], ["Maple House 3", "Larkspur"],
	["Maple House 4", "Quill"], ["Maple House 5", "Pemberton"], ["Maple House 6", "Bramblewood"],
	["Palmer House", "Palmer"]]
# Where piles go round a house, in its own space (its front, +Z, faces Maple Lane): along the sidewalk outside the
# picket fence (missing the gate and the mailbox), and down both sides
const PILE_SPOTS := [Vector2(-3.8, 8.0), Vector2(-2.4, 8.0), Vector2(3.0, 8.0), Vector2(4.3, 8.0), Vector2(-6.3, -2.2),
	Vector2(-6.3, 0.8), Vector2(-6.3, 3.8), Vector2(-6.1, 6.2), Vector2(6.3, -2.2), Vector2(6.3, 0.8), Vector2(6.3, 3.8),
	Vector2(6.1, 6.2)]
# Cats: owner, the cat's name, what it looks like
const CATS := [["wren", "Duchess", "grey"], ["marigold", "Footnote", "black"], ["dottie", "Marmalade", "orange"]]
# Where a cat might be hiding: the place, what the card says, and the tier (far ones are the harder job)
const HIDEOUTS := [
	["playground", "by the playground slide", "medium"],
	["library_steps", "on the library steps", "medium"],
	["skate_gate", "at the skate yard gate", "medium"],
	["footbridge_e", "by the footbridge in the park", "medium"],
	["dock", "out on the dock at Willow Pond", "hard"],
	["hill_top", "up on Lookout Hill", "hard"],
	["pumpkin_patch", "in the pumpkin patch", "hard"],
	["school", "by Old Oak Elementary", "hard"],
]
# Pumpkins to pick, in the pumpkin patch's own space, between the rows of the ones that stay
const PUMPKIN_SPOTS := [Vector2(-5.4, -2.4), Vector2(-1.2, -2.4), Vector2(3.0, -2.4), Vector2(-3.3, 0.0), Vector2(0.9, 0.0),
	Vector2(5.1, 0.0), Vector2(-5.4, 2.4), Vector2(-1.2, 2.4), Vector2(3.0, 2.4), Vector2(6.3, 2.4)]

var _told_day := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Dialogue.finished.connect(_on_talked)
	Dialogue.finished.connect(_on_follow_picked)
	Requests.noted.connect(note)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()
	changed.connect(_refresh_log)


# -----------------------------------------------------------------------------
# Today's three
# -----------------------------------------------------------------------------
func visit_day() -> int:
	return Clock.earth_day()


func is_live() -> bool:
	return rolled_visit == Clock.earth_day() and not list.is_empty()


func kinds() -> Dictionary:
	return EARTH_KINDS


func kinds_for(tier: String) -> Array[String]:
	# Snowmen only in winter, sandcastles only in summer
	var out := super.kinds_for(tier)
	if Clock.season() != "winter":
		out.erase("snowman")
	if Clock.season() != "summer":
		out.erase("sandcastle")
	return out


static func winter_of(r: Dictionary) -> bool:
	return bool(r.get("winter", false))


static func summer_of(r: Dictionary) -> bool:
	return bool(r.get("summer", false))


static func spring_of(r: Dictionary) -> bool:
	return bool(r.get("spring", false))


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	if rolled_visit != Clock.earth_day():
		roll(hash("earth_jobs:%d" % Clock.earth_day()))
	_announce()


func roll(seed_value := -1) -> void:
	super.roll(seed_value)
	_place_props.call_deferred()


func _announce() -> void:
	# Once a day, on Earth and awake: there are new jobs
	if not Clock.on_earth or _told_day == rolled_visit or not is_live() or Clock.hour() < 6 or Clock.in_shift():
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EARTH:
		return
	_told_day = rolled_visit
	Game.message("New jobs are pinned up on the notice board by the gazebo!")


func _make(kind: String, tier: String, rng: RandomNumberGenerator) -> Dictionary:
	var n: float = EARTH_KINDS[kind][tier]
	var r := {"kind": kind, "tier": tier, "progress": 0.0, "done": false, "paid": false,
		"sparkles": int(PAY[tier]) + mini(nights / 4, 3), "winter": Clock.season() == "winter",
		"summer": Clock.season() == "summer", "spring": Clock.season() == "spring"}
	match kind:
		"deliver":
			r.goal = 1
			var p: Array = PARCELS[rng.randi() % PARCELS.size()]
			var people := PEOPLE.keys().filter(func(id: String) -> bool: return id != p[4])
			r.item = p[0]
			r.item_name = p[1]
			r.from = p[2]
			r.shop = p[3]
			r.who = people[rng.randi() % people.size()]
			r.carrying = false
		"rake":
			r.goal = int(n)
			var y: Array = YARDS[rng.randi() % YARDS.size()]
			r.house = y[0]
			r.family = y[1]
			var spots := range(PILE_SPOTS.size())
			_shuffle(spots, rng)
			r.piles = spots.slice(0, int(n))
			r.raked = []
		"cat":
			r.goal = 1
			var c: Array = CATS[rng.randi() % CATS.size()]
			r.who = c[0]
			r.cat = c[1]
			r.coat = c[2]
			var hides := HIDEOUTS.filter(func(h: Array) -> bool: return h[2] == tier)
			var h: Array = hides[rng.randi() % hides.size()]
			r.hideout = h[0]
			r.where = h[1]
			r.carrying = false
		"bakery":
			r.goal = int(n)
			r.who = "poppy"
			var spots := range(PUMPKIN_SPOTS.size())
			_shuffle(spots, rng)
			r.pumpkins = spots.slice(0, int(n))
			r.picked = []
			r.carrying = false
		"snowman", "sandcastle":
			r.goal = int(n)
			var spots := range((SNOWMAN_SPOTS if kind == "snowman" else SummerSplash.CASTLE_SPOTS).size())
			_shuffle(spots, rng)
			r.balls = spots.slice(0, int(n))
			r.built = []
		"grind":
			r.goal = _nice(n * scale(), 1)
		"combo":
			r.goal = _nice(n * scale(), 100)
	return r


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	# (Array.shuffle() uses the global random numbers; this follows the day's seed)
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# -----------------------------------------------------------------------------
# What a job says
# -----------------------------------------------------------------------------
func text_of(r: Dictionary) -> String:
	match str(r.kind):
		"deliver":
			var what := str(r.item_name)
			if winter_of(r) and what == "a pumpkin pie":
				what = "a warm blueberry pie"
			elif summer_of(r) and what == "a pumpkin pie":
				what = "a strawberry shortcake"
			elif spring_of(r) and what == "a pumpkin pie":
				what = "a rhubarb crumble"
			return "Take %s from %s to %s" % [what, r.shop, friend_name(str(r.who))]
		"rake":
			if winter_of(r):
				return "Shovel the snow at the %s house (%d drifts)" % [r.family, int(r.goal)]
			if summer_of(r):
				return "Water the thirsty flowers at the %s house (%d flowers)" % [r.family, int(r.goal)]
			if spring_of(r):
				return "Plant tulip bulbs at the %s house (%d bulbs)" % [r.family, int(r.goal)]
			return "Rake up the leaves at the %s house (%d piles)" % [r.family, int(r.goal)]
		"cat":
			var where := str(r.where)
			if winter_of(r):
				where = where.replace("in the pumpkin patch", "in the Snowman Field")
			elif summer_of(r):
				where = where.replace("in the pumpkin patch", "in the Sunflower Field")
			elif spring_of(r):
				where = where.replace("in the pumpkin patch", "in the Tulip Field")
			return "Find %s's cat %s (last seen %s)" % [friend_name(str(r.who)), r.cat, where]
		"bakery":
			if winter_of(r):
				return "Pick %d bunches of winterberries in the Snowman Field for Poppy's tarts" % int(r.goal)
			if summer_of(r):
				return "Pick %d baskets of strawberries in the Sunflower Field for Poppy's shortcakes" % int(r.goal)
			if spring_of(r):
				return "Pick %d bundles of rhubarb in the Tulip Field for Poppy's rhubarb tarts" % int(r.goal)
			return "Pick %d pumpkins at the patch for Poppy's pies" % int(r.goal)
		"snowman":
			return "Build %d snowmen on the town green for the Frost Fair" % int(r.goal)
		"sandcastle":
			return "Build %d sandcastles on the beach at Willow Pond for the Summer Fair" % int(r.goal)
	return super.text_of(r)


func progress_text(r: Dictionary) -> String:
	if r.get("paid", false) or r.get("done", false):
		return super.progress_text(r)
	match str(r.kind):
		"rake":
			return "%d / %d %s" % [int(r.progress), int(r.goal), "drifts" if winter_of(r) else ("flowers" if summer_of(r) else ("bulbs" if spring_of(r) else "piles"))]
		"snowman":
			return "%d / %d snowmen" % [int(r.progress), int(r.goal)]
		"sandcastle":
			return "%d / %d sandcastles" % [int(r.progress), int(r.goal)]
		"cat":
			return "found! Now take %s home to %s" % [r.cat, friend_name(str(r.who))] if r.get("carrying", false) else ""
		"bakery":
			if r.get("carrying", false):
				return "got them all, now take them to Poppy"
			return "%d / %d %s" % [r.picked.size(), int(r.goal), "bunches" if winter_of(r) else ("baskets" if summer_of(r) else ("bundles" if spring_of(r) else "pumpkins"))] \
				if not r.picked.is_empty() else ""
	return super.progress_text(r)


func friend_name(id: String) -> String:
	return str(PEOPLE.get(id, id.capitalize()))


func noun() -> String:
	return "Job"


func left_over_text() -> String:
	return "Sparkles for yesterday's jobs!"


func key_prefix() -> String:
	return "job"


func board_name() -> String:
	return "notice board by the gazebo"


func job_title() -> String:
	return "Notice board job"


func home_scene() -> String:
	return EARTH


func board_node() -> String:
	return "Notice Board"


func board_title() -> String:
	return "%s'S JOBS" % Clock.weekday().to_upper()


func asleep_text() -> Array:
	return ["No jobs pinned up yet.", "Come back in the morning!"]


func board_text() -> String:
	# Today's jobs, and a reminder of this season's fair along the bottom
	return super.board_text() + "\n\n★ %s on the green ★\nSaturdays, %s" % [Festival.fair_name(), Festival.hours_text()]


func log_title() -> String:
	return "[b]Today's jobs[/b] (the notice board by the gazebo)"


# -----------------------------------------------------------------------------
# Progress
# -----------------------------------------------------------------------------
func note(kind: String, amount := 1.0, how := "") -> void:
	# Grinds count on Earth only (the Void has its own board)
	if Clock.on_earth:
		super.note(kind, amount, how)


func _on_banked(points: int, names: String) -> void:
	if Clock.on_earth:
		super._on_banked(points, names)


func collect(r: Dictionary, spot: int) -> void:
	# A leaf pile walked through, a pumpkin picked or a cat found (scripts/earth_job_prop.gd)
	if r.done or not r in list:
		return
	match str(r.kind):
		"rake":
			if spot in r.raked.map(func(v) -> int: return int(v)):
				return
			r.raked.append(spot)
			r.progress = float(r.raked.size())
			Audio.play("splash" if summer_of(r) else ("pickup" if spring_of(r) else "rustle"), -6.0 if summer_of(r) or spring_of(r) else -2.0)
			_check_done(r)
		"snowman", "sandcastle":
			if spot in r.built.map(func(v) -> int: return int(v)):
				return
			r.built.append(spot)
			r.progress = float(r.built.size())
			Audio.play("pickup", -5.0)
			_check_done(r)
		"bakery":
			if r.carrying or spot in r.picked.map(func(v) -> int: return int(v)):
				return
			r.picked.append(spot)
			Audio.play("pickup", -5.0)
			if r.picked.size() >= int(r.goal):
				r.carrying = true
				Game.message("That's %d %s! Take them to Poppy at the bakery on Main Street." % [int(r.goal),
					"bunches of winterberries" if winter_of(r) else ("baskets of strawberries" if summer_of(r)
					else ("bundles of rhubarb" if spring_of(r) else "pumpkins"))])
		"cat":
			if r.carrying:
				return
			r.carrying = true
			Audio.play("pickup", -3.0)
			Game.message("You found %s! %s purrs and trots after you. Take %s home to %s." % [r.cat, r.cat,
				"her" if r.cat != "Footnote" else "him", friend_name(str(r.who))])
	changed.emit()


func _on_talked(id: String) -> void:
	# A cat home to its owner, pumpkins to Poppy; deliveries as on the Void's board
	if not is_live() or not Clock.on_earth:
		return
	for r in list:
		if r.done or not r.get("carrying", false) or r.get("who", "") != id:
			continue
		match str(r.kind):
			"cat":
				r.carrying = false
				r.progress = 1.0
				Game.message("%s is home! %s scoops %s up and says thank you, %s, about a hundred times." % [r.cat,
					friend_name(id), r.cat, Dialogue.player_name()])
				_check_done(r)
				changed.emit()
				_place_props.call_deferred()
				return
			"bakery":
				r.carrying = false
				r.progress = float(r.goal)
				Game.message("Poppy takes the winterberries: \"Perfect! These'll make the best tarts in town!\"" if winter_of(r)
					else ("Poppy takes the strawberries: \"Perfect! These'll make the best shortcakes in town!\"" if summer_of(r)
					else ("Poppy takes the rhubarb: \"Perfect! These'll make the best rhubarb tarts in town!\"" if spring_of(r)
					else "Poppy takes the pumpkins: \"Perfect! These'll make the best pies in town!\"")))
				_check_done(r)
				changed.emit()
				return
	super._on_talked(id)


func _check_done(r: Dictionary) -> void:
	if r.done or float(r.progress) < float(r.get("goal", 1)):
		return
	r.done = true
	Audio.play("pickup", -2.0, 0.0)
	Game.message("Job done: %s! Turn it in at the notice board for ✦ %d." % [text_of(r), int(r.sparkles)])


func wants_parcel(item_id: String) -> bool:
	if not is_live():
		return false
	for r in list:
		if r.kind == "deliver" and not r.done and not r.carrying and r.item == item_id:
			return true
	return false


# -----------------------------------------------------------------------------
# The board and what it says
# -----------------------------------------------------------------------------
func talk(talker: Node3D) -> void:
	Dialogue.say(talker, "Notice Board", lines(talker) + follow_choice(), "notice_board")


func lines(talker: Node3D = null) -> Array:
	if not is_live():
		return ["(The notice board's empty, apart from a note in Mr. Palmer's tidy writing: \"New jobs every morning!\")"]
	var out: Array = FirstNight.board_tutorial_lines()          # (Nina's how-to, on the First Night's board step)
	var paid := turn_in(talker)
	if paid > 0:
		out.append("(You pin your finished job cards in the \"Done!\" box. A little envelope drops out: ✦ %d!)" % paid)
		if list.all(func(r: Dictionary) -> bool: return r.paid):
			out.append("(Every card today says DONE. Someone's drawn a smiley face on the board. Was it Mr. Palmer?)")
			return out
	else:
		out.append("(Cards are pinned all over the notice board. Today's jobs:)")
	for r in list:
		if not r.paid:
			var extra := progress_text(r)
			out.append("%s, for ✦ %d.%s" % [text_of(r), int(r.sparkles), (" (%s)" % extra.capitalize()) if extra != "" else ""])
	out.append("(At the bottom: \"Thank you, helpers! Any job not done comes down at midnight, no worries. Mr. P.\")")
	return out


# -----------------------------------------------------------------------------
# Putting things in the Earth town: the board, parcels, leaf piles, pumpkins and the cat
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_hook_skater.call_deferred()
	if scene.scene_file_path == EARTH:
		if scene.get_node_or_null("Notice Board") == null:
			_place_board(scene)                           # (out from a new game's first morning: Nina shows it)
		_place_props.call_deferred()


func _place_board(scene: Node) -> void:
	var board := (load("res://scripts/request_board.gd") as GDScript).new() as Node3D
	board.name = "Notice Board"
	board.set("jobs", self)
	board.set("earthy", true)
	scene.add_child(board)
	board.global_position = BOARD_AT + Vector3(0, EarthLand.height(BOARD_AT.x, BOARD_AT.z), 0)


func _place_props() -> void:
	# Everything today's jobs want, and nothing else: old props come down first
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EARTH or not scene.is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group("earth_job_props"):
		n.get_parent().remove_child(n)                # (out of the way at once, so the new ones get their names)
		n.queue_free()
	if not is_live():
		return
	var paths := TownPaths.get_shared(TownPaths.EARTH_FILE)
	var space := (scene as Node3D).get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(scene)
	for r in list:
		if r.done and r.kind != "snowman" and r.kind != "sandcastle" and not (r.kind == "rake" and (summer_of(r) or spring_of(r))):
			# (snowmen and sandcastles built stay up all day, and so do the flowers you watered and the tulips you planted)
			continue
		match str(r.kind):
			"deliver":
				if not r.carrying:
					var parcel := (load("res://scripts/request_parcel.gd") as GDScript).new() as Node3D
					parcel.name = "Job Parcel " + str(r.item)
					parcel.set("item_id", str(r.item))
					parcel.set("jobs", self)
					parcel.add_to_group("earth_job_props")
					scene.add_child(parcel)
					parcel.global_position = paths.position_of(str(r.from), space, skip)
			"rake":
				var house := scene.get_node_or_null(str(r.house)) as Node3D
				var raked: Array = r.raked.map(func(v) -> int: return int(v))
				for v in r.piles:
					if house == null or (int(v) in raked and not summer_of(r) and not spring_of(r)):
						continue
					var s: Vector2 = PILE_SPOTS[int(v)]
					var at := house.global_transform * Vector3(s.x, 0, s.y)
					var kind := "drift" if winter_of(r) else ("thirsty" if summer_of(r) else ("bulb" if spring_of(r) else "leaves"))
					var p := _prop(scene, kind, r, int(v), TownPaths.ground_at(at, space, skip, 3.0))
					p.set("built", int(v) in raked)                 # (a flower that's been watered stays perked up, a tulip planted stays)
			"snowman":
				var built: Array = r.built.map(func(v) -> int: return int(v))
				for v in r.balls:
					var s: Vector2 = SNOWMAN_SPOTS[int(v)]
					var p := _prop(scene, "snowball", r, int(v), TownPaths.ground_at(Vector3(s.x, 0, s.y), space, skip, 2.0))
					p.set("built", int(v) in built)
			"sandcastle":
				var built: Array = r.built.map(func(v) -> int: return int(v))
				for v in r.balls:
					var s: Vector2 = SummerSplash.CASTLE_SPOTS[int(v)]
					var p := _prop(scene, "sandpile", r, int(v), SummerSplash.ground(s))
					p.set("built", int(v) in built)
			"bakery":
				var patch := scene.find_child("Pumpkin Patch", true, false) as Node3D
				var picked: Array = r.picked.map(func(v) -> int: return int(v))
				if patch == null or r.carrying:
					continue
				for v in r.pumpkins:
					if int(v) in picked:
						continue
					var s: Vector2 = PUMPKIN_SPOTS[int(v)]
					_prop(scene, "berries" if winter_of(r) else ("strawberries" if summer_of(r) else ("rhubarb" if spring_of(r) else "pumpkin")), r, int(v),
						TownPaths.ground_at(patch.global_transform * Vector3(s.x, 0, s.y), space, skip, 2.0))
			"cat":
				var player := get_tree().get_first_node_in_group("player") as Node3D
				if r.carrying and player:
					_prop(scene, "cat", r, 0, player.global_position + Vector3(1.0, 0, 1.0)).set("following", true)
				elif not r.carrying:
					var at := paths.position_of(str(r.hideout), space, skip) + Vector3(1.2, 0, 0.8)
					_prop(scene, "cat", r, 0, TownPaths.ground_at(at, space, skip, 2.0))


func _prop(scene: Node, kind: String, r: Dictionary, spot: int, at: Vector3) -> Node3D:
	var p := (load("res://scripts/earth_job_prop.gd") as GDScript).new() as Node3D
	p.name = "Job %s %d" % [kind.capitalize(), spot]
	p.set("kind", kind)
	p.set("job", r)
	p.set("spot", spot)
	p.set("coat", str(r.get("coat", "orange")))
	p.add_to_group("earth_job_props")
	scene.add_child(p)
	p.global_position = at
	return p


# -----------------------------------------------------------------------------
# Saving (scripts/game.gd keeps this in save.json as "earth_jobs")
# -----------------------------------------------------------------------------
func load_data(data: Dictionary) -> void:
	super.load_data(data)
	for r in list:
		for key in ["raked", "picked", "piles", "pumpkins", "balls", "built"]:
			if r.has(key) and r[key] is Array:
				r[key] = r[key].map(func(v) -> int: return int(v))
	_told_day = rolled_visit                  # (no "new jobs" news for a day that was already going)
	_place_props.call_deferred()
