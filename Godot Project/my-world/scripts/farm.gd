extends Node

# Autoload "Farm": the player's garden in the Void (plan item 18, from Hayden's 7 Nov 2026 notes), looked after with
# Bramble, the plant girl. It's a fenced plot of twelve beds up on the Secret Gardens' hill, in front of the greenhouse
# where the nursery is on Sofi's town map (source_art/reference/world/town - map with labels.jpg; Hayden, 8 Nov 2026),
# put into the town at play time (like the lost watches: scripts/watches.gd), so town.tscn doesn't change. The
# builder's own row-crop beds in that spot (tools/build_town.gd _plateau_features) are hidden while the garden's there,
# so the player's garden IS the nursery rather than sitting on top of it.
#
# How it goes: Bramble's quest "Bramble's Harvest" (res://quests/brambles_harvest.json, with scripts/remnants.gd)
# ends with her meeting the player at the garden. She digs the first two beds, hands over some seeds and explains the
# rest (her "do": "Farm.tour" in dialogue/bramble.json). From then on:
#   - **Dig** a bed (Interact, with the harvesting tool Bramble helped make).
#   - **Plant** a seed in a dug bed. Seeds come from the Flowers stall in the Market (the Remnant sprout's from the
#     Crystals stall, for a Remnant). With more than one kind of seed in the bag, a little question asks which.
#   - **Water** it (Interact again; with the watering can, the quest's reward, every bed in one go). Water lasts
#     WATER_LASTS Void minutes; a plant only grows while it has some, and when it runs dry it waits, drooping a little
#     with a water drop over it. Plants never die and never go off, however long they wait (Hayden: "never a chore
#     wall"), and they only grow while the Void's clock runs, in the Shift.
#   - **Harvest** it when it's ripe: the crop pops into the bag (or, for a Remnant sprout, Remnants into the pocket)
#     and the bed is ready for the next seed.
# The crops are alien plants that look back at you: each has a pair of little eyes that blink and follow the player
# about (a nod to Bramble's world, where every plant has eyes).
#
# Crops sell at the Fruit stall, make snacks at the Sweets stall (both through Shop.register_kind), and the nightly
# request board can ask for a harvest (scripts/requests.gd, kind "harvest"). Seasons (plan item 20) can change what
# grows once they're in: CROPS has room for a "season".
#
# Saved with the game as "farm" (scripts/game.gd); saves from before have no garden yet.

signal changed

const USE_SPOT := preload("res://scripts/use_spot.gd")

const TOWN := "res://scenes/town/town.tscn"
const GARDEN := Vector2(-80.0, -34.5)    # the plot's middle: on the Secret Gardens' hill, south of the greenhouse
const SECRET_GARDEN := "res://scenes/secret_garden/secret_garden.tscn"   # the real one (scripts/secret_garden.gd)
const SECRET_DOOR := Vector2(-74.0, -75.6)  # its way in: an old ivy wall at the foot of the hill's north cliff
const GARDEN_YAW := -PI / 2.0           # turned so the gate (the plot's local +x side) faces south, to the hill's ramp
const BEDS := 12
const COLS := 3                          # beds across the plot's local x (north to south), rows along its local z
const BED_SIZE := Vector2(1.4, 1.1)
const FIRST_BOOST := 8.0                # how much faster the very first crops grow (first_boost())
const WATER_LASTS := 360.0              # Void minutes a watering lasts (about 4 real minutes in the Shift)
const DAY := 1440.0

# The crops. grow: Void minutes of watered growing to ripen (an hour of the Void goes by in about 42 real seconds);
# gives: how many come off one plant; sells: sparkles each at the Fruit stall. colour/look build the plant (_plant()).
const CROPS := {
	"blinkberry": {"name": "Blinkberry", "plural": "Blinkberries", "grow": 240.0, "gives": 3, "sells": 2,
		"colour": Color(1.0, 0.35, 0.75), "look": "berry", "seed": 2,
		"says": "Blinking pink berries. Quick to grow!"},
	"peekaroot": {"name": "Peekaroot", "plural": "Peekaroots", "grow": 480.0, "gives": 2, "sells": 5,
		"colour": Color(0.3, 0.95, 0.85), "look": "root", "seed": 4,
		"says": "A root that peeks out at you."},
	"gogglegourd": {"name": "Goggle Gourd", "plural": "Goggle Gourds", "grow": 720.0, "gives": 1, "sells": 14,
		"colour": Color(0.7, 0.45, 1.0), "look": "gourd", "seed": 6,
		"says": "A big goggly-eyed gourd. Slow, but worth it."},
	"remnant_sprout": {"name": "Remnant Sprout", "plural": "Remnant Sprouts", "grow": 1440.0, "gives": 2,
		"sells": 0, "colour": Color(0.45, 1.0, 0.3), "look": "crystal", "remnant_seed": 1,
		"says": "Grows Remnant crystals. Takes a day."},
	# From the Old Taproot in the Undergardens (scripts/garden_caves.gd): no shop sells the seeds, only he has them
	"glowcap": {"name": "Glowcap", "plural": "Glowcaps", "grow": 600.0, "gives": 2, "sells": 9,
		"colour": Color(0.55, 0.95, 1.0), "look": "mushroom", "seed": 0,
		"says": "A sleepy mushroom that glows at night."},
}
const ORDER := ["blinkberry", "peekaroot", "gogglegourd", "remnant_sprout", "glowcap"]

# Snacks made from crops at the Sweets stall: shop item -> what goes in (scripts/shop.gd sells them; they're eaten
# there and then, like the other snacks)
const RECIPES := {
	"snack_blinkberry_tart": {"blinkberry": 2},
	"snack_peekaroot_fries": {"peekaroot": 2},
	"snack_gourd_soup": {"gogglegourd": 1},
}

var beds: Array = []                    # one per bed: {tilled, crop, grown (minutes), water_until, last} (Void minutes)
var seeds := {}                         # crop -> how many seeds in the bag
var crops := {}                         # crop -> how many harvested and not yet sold or eaten
var harvested := 0                      # crops picked, all told

var _scene: Node
var _holder: Node3D
var _plant_bed := -1                    # the bed a "which seed?" question is for
var _shown := []                        # what each bed shows now, so it's only rebuilt when that changes
var _tick := 0.0
var _blink := []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	reset()
	var caves := Node.new()                     # the Undergardens under the hill (scripts/garden_caves.gd): "Farm/Caves"
	caves.name = "Caves"
	caves.set_script(preload("res://scripts/garden_caves.gd"))
	add_child(caves)
	var secret := Node.new()                    # the real Secret Garden's hidden door and the wren (secret_garden_way.gd)
	secret.name = "SecretGarden"
	secret.set_script(preload("res://scripts/secret_garden_way.gd"))
	add_child(secret)
	Dialogue.finished.connect(_on_talked)
	Shop.register_kind.call_deferred("seed", {"can_buy": _can_buy_seed, "buy": _buy_seed, "show": _shop_show,
		"note": _seed_note})
	Shop.register_kind.call_deferred("crop_sell", {"can_buy": _can_sell, "buy": _sell, "show": _shop_show,
		"sells": true, "button": "Sell one", "note": _crop_note})
	Shop.register_kind.call_deferred("crop_snack", {"can_buy": _can_cook, "buy": _cook, "show": _shop_show,
		"button": "Make it!"})


# -----------------------------------------------------------------------------
# Time
# -----------------------------------------------------------------------------
static func now() -> float:
	# The Void's clock as one long count of minutes
	return Clock.day * DAY + Clock.minutes


func update() -> void:
	# Grow each planted bed by however long it's had water since it was last looked at
	var t := now()
	for b in beds:
		if str(b.crop) == "":
			continue
		if t < float(b.last):                        # the clock went back (a test, or an old save): start from now
			b.last = t
			b.water_until = minf(float(b.water_until), t)
		var wet := clampf(minf(t, float(b.water_until)) - float(b.last), 0.0, DAY * 30.0)
		b.grown = minf(float(b.grown) + wet * first_boost(), grow_time(str(b.crop)))
		b.last = t


var boost_first := true                 # (tests that time the garden's own pace turn the first-crop boost off)


func first_boost() -> float:
	# Bramble's Harvest waits on the first crop: until it's picked, Bramble's green fingers make everything grow
	# FIRST_BOOST times as fast, so a Blinkberry's ready in about half a minute (Hayden, 14 Nov 2026: no waiting on the
	# clock to get through the story). After that it's the garden's own pace.
	return 1.0 if Dialogue.flags.has("farm_first_harvest") or not boost_first else FIRST_BOOST


static func grow_time(crop: String) -> float:
	return float(CROPS.get(crop, {}).get("grow", 240.0))


func ripe(i: int) -> bool:
	var b: Dictionary = beds[i]
	return str(b.crop) != "" and float(b.grown) >= grow_time(str(b.crop))


func thirsty(i: int) -> bool:
	var b: Dictionary = beds[i]
	return str(b.crop) != "" and not ripe(i) and now() >= float(b.water_until)


func stage(i: int) -> int:
	# 0 dug and empty, 1 a seed under the soil, 2 a sprout, 3 growing, 4 nearly there, 5 ripe (-1 not dug yet)
	var b: Dictionary = beds[i]
	if not b.tilled:
		return -1
	if str(b.crop) == "":
		return 0
	if ripe(i):
		return 5
	var k := float(b.grown) / grow_time(str(b.crop))
	return 1 if k < 0.05 else (2 if k < 0.35 else (3 if k < 0.7 else 4))


func hours_left(i: int) -> int:
	var b: Dictionary = beds[i]
	return ceili(maxf(grow_time(str(b.crop)) - float(b.grown), 0.0) / 60.0 / first_boost())


# -----------------------------------------------------------------------------
# What the player does
# -----------------------------------------------------------------------------
func unlocked() -> bool:
	# Bramble's shown the player round the garden
	return Dialogue.flags.has("garden_tour")


func has_can() -> bool:
	return Game.has_item("watering_can")


func seed_total() -> int:
	var n := 0
	for c in seeds:
		n += int(seeds[c])
	return n


func till(i: int) -> bool:
	if beds[i].tilled:
		return false
	beds[i].tilled = true
	_fx(i, "dig")
	changed.emit()
	Game.save_game()
	return true


func plant(i: int, crop: String) -> bool:
	var b: Dictionary = beds[i]
	if not b.tilled or str(b.crop) != "" or int(seeds.get(crop, 0)) <= 0 or not CROPS.has(crop):
		return false
	seeds[crop] = int(seeds[crop]) - 1
	if int(seeds[crop]) <= 0:
		seeds.erase(crop)
	b.crop = crop
	b.grown = 0.0
	b.last = now()
	b.water_until = now()                       # a new seed wants a drink straight away
	if not Dialogue.flags.has("farm_planted"):
		Dialogue.set_flag("farm_planted")
	_fx(i, "plant")
	Game.message("Planted a %s! Now water it!" % CROPS[crop].name)
	changed.emit()
	Game.save_game()
	return true


func water(i: int) -> int:
	# Water this bed (with the can: every bed that's thirsty). Says how many got a drink.
	update()
	var which: Array = range(beds.size()) if has_can() else [i]
	var n := 0
	for k in which:
		if str(beds[k].crop) != "" and not ripe(k):
			beds[k].water_until = now() + WATER_LASTS
			_fx(k, "water")
			n += 1
	if n > 0:
		if not Dialogue.flags.has("farm_watered"):
			Dialogue.set_flag("farm_watered")
		Audio.play("splash", -8.0, 0.1)
		Game.message("Glug glug! %s" % ("The whole garden's had a drink." if n > 1 else "Grow, little one!"))
		changed.emit()
		Game.save_game()
	return n


func harvest(i: int) -> int:
	if not ripe(i):
		return 0
	var b: Dictionary = beds[i]
	var crop := str(b.crop)
	var n := int(CROPS[crop].gives)
	if crop == "remnant_sprout":
		Remnants.add(n, "A Remnant sprout!")
	else:
		crops[crop] = int(crops.get(crop, 0)) + n
		Game.message("You picked %d %s!" % [n, CROPS[crop].plural if n != 1 else CROPS[crop].name])
	b.crop = ""
	b.grown = 0.0
	harvested += n
	_fx(i, "harvest")
	if not Dialogue.flags.has("farm_first_harvest"):
		Dialogue.set_flag("farm_first_harvest")
	Requests.note("harvest", float(n))
	Game.add_xp(2 * n)
	changed.emit()
	Game.save_game()
	return n


func _offer(i: int) -> String:
	if not unlocked() and not beds[i].tilled:
		return ""
	update()
	match stage(i):
		-1:
			return "dig this bed" if Remnants.has_tool() else ""
		0:
			return "plant a seed"
		5:
			return "pick the %s" % CROPS[str(beds[i].crop)].name
	if thirsty(i):
		return "water the garden" if has_can() else "water it"
	return "check on it"


func _use(i: int) -> void:
	update()
	match stage(i):
		-1:
			till(i)
		0:
			_ask_seed(i)
		5:
			harvest(i)
		_:
			if thirsty(i):
				water(i)
			else:
				var c: Dictionary = CROPS[str(beds[i].crop)]
				Game.message("%s: %d more hour%s to go." % [c.name, hours_left(i),
					"" if hours_left(i) == 1 else "s"])


func _ask_seed(i: int) -> void:
	var have := ORDER.filter(func(c: String) -> bool: return int(seeds.get(c, 0)) > 0)
	if have.is_empty():
		Game.message("No seeds! Bramble's stall sells them.")
		Audio.play("ui_back", -8.0)
		return
	if have.size() == 1:
		plant(i, str(have[0]))
		return
	_plant_bed = i
	var choice: Array = []
	for c in have:
		choice.append({"text": "%s (%d)" % [CROPS[c].name, int(seeds[c])], "set": "farm_plant_" + str(c), "say": false})
	choice.append({"text": "Not now.", "say": false})
	var spot := _holder.get_node_or_null("Bed %d/Spot" % i) as Node3D if is_instance_valid(_holder) else null
	if spot == null:
		plant(i, str(have[0]))
		return
	Dialogue.say(spot, "Seed bag", ["(Which seed shall it be?)", {"choice": choice}], "farm_plant")


func _on_talked(id: String) -> void:
	if id != "farm_plant":
		return
	for f in Dialogue.flags.keys():
		if str(f).begins_with("farm_plant_"):
			Dialogue.flags.erase(f)
			if _plant_bed >= 0:
				plant(_plant_bed, str(f).trim_prefix("farm_plant_"))
	_plant_bed = -1


func give_seeds(crop: String, n: int) -> void:
	seeds[crop] = int(seeds.get(crop, 0)) + n
	changed.emit()


# -----------------------------------------------------------------------------
# Bramble's garden tour (a "do" in dialogue/bramble.json)
# -----------------------------------------------------------------------------
func tour() -> Array:
	# She digs the first two beds and gives the player a starter bag of seeds
	if Dialogue.flags.has("garden_tour"):
		return []
	for i in 2:
		beds[i].tilled = true
		_fx(i, "dig")
	give_seeds("blinkberry", 3)
	give_seeds("peekaroot", 1)
	changed.emit()
	Game.save_game()
	return ["(Bramble digs two beds for you!)",
		"Here are some seeds to start!",
		"Plant one, then water it!",
		"Dig more beds with your {tool}!"]


# -----------------------------------------------------------------------------
# The shop's side (scripts/shop.gd register_kind)
# -----------------------------------------------------------------------------
func _shop_show(_it: Dictionary) -> bool:
	return unlocked()


func _can_buy_seed(_it: Dictionary) -> String:
	return "" if unlocked() else "Bramble hasn't shown you your garden yet"


func _buy_seed(it: Dictionary) -> String:
	var crop := str(it.get("crop", ""))
	give_seeds(crop, 1)
	Game.save_game()
	return "A %s seed for your bag! (%d now.)" % [CROPS[crop].name, int(seeds[crop])]


func _seed_note(it: Dictionary) -> String:
	var n := int(seeds.get(str(it.get("crop", "")), 0))
	return "In your bag: %d" % n if n > 0 else ""


func _crop_note(it: Dictionary) -> String:
	return "You have %d" % int(crops.get(str(it.get("crop", "")), 0))


func _can_sell(it: Dictionary) -> String:
	return "" if int(crops.get(str(it.get("crop", "")), 0)) > 0 else "None to sell"


func _sell(it: Dictionary) -> String:
	var crop := str(it.get("crop", ""))
	crops[crop] = int(crops[crop]) - 1
	var pay := int(it.price)
	Game.add_sparkles(pay)
	changed.emit()
	return "Sold a %s for ✦ %d! (%d left.)" % [CROPS[crop].name, pay, int(crops[crop])]


func _can_cook(it: Dictionary) -> String:
	for crop in RECIPES.get(str(it.id), {}):
		if int(crops.get(crop, 0)) < int(RECIPES[str(it.id)][crop]):
			return "Needs %d %s" % [int(RECIPES[str(it.id)][crop]), CROPS[crop].plural]
	return ""


func _cook(it: Dictionary) -> String:
	for crop in RECIPES.get(str(it.id), {}):
		crops[crop] = int(crops[crop]) - int(RECIPES[str(it.id)][crop])
	Game.hp = mini(Game.hp + int(it.get("hp", 0)), Game.max_hp)
	Game.mp = mini(Game.mp + int(it.get("mp", 0)), Game.max_mp)
	Game.stats_changed.emit()
	changed.emit()
	return "Yum! %s, fresh from your own garden. %s" % [it.name, it.text]


func bag_text() -> String:
	# For the Bag sheet (scripts/player_menu.gd)
	var s: PackedStringArray = []
	var c: PackedStringArray = []
	for k in ORDER:
		if int(seeds.get(k, 0)) > 0:
			s.append("%s x%d" % [CROPS[k].name, int(seeds[k])])
		if int(crops.get(k, 0)) > 0:
			c.append("%s x%d" % [CROPS[k].plural, int(crops[k])])
	return "Seeds: %s\nCrops: %s" % [", ".join(s) if not s.is_empty() else "none", ", ".join(c) if not c.is_empty() else "none yet"]


# -----------------------------------------------------------------------------
# In the town
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_shown = []
		if s and s.scene_file_path == TOWN:
			_place_in.call_deferred(s)
	if not is_instance_valid(_holder):
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		update()
		_refresh()
	_animate(delta)


func bed_local(i: int) -> Vector3:
	# Four rows of three, across the plot
	var col := i % COLS
	var row := i / COLS
	var rows := ceili(float(BEDS) / COLS)
	return Vector3((col - (COLS - 1) / 2.0) * 1.9, 0.0, (row - (rows - 1) / 2.0) * 1.7)


func plot_half() -> Vector2:
	# Half the fenced plot's size in its own space: the beds plus a path round them
	var rows := ceili(float(BEDS) / COLS)
	return Vector2((COLS - 1) * 0.95 + BED_SIZE.x / 2.0 + 0.95, (rows - 1) * 0.85 + BED_SIZE.y / 2.0 + 0.7)


func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null("Garden") != null:
		return
	_holder = Node3D.new()
	_holder.name = "Garden"
	s.add_child(_holder)
	_holder.global_position = Remnants.ground_at(GARDEN)
	_holder.rotation.y = GARDEN_YAW
	_clear_nursery(s)
	_build_plot(_holder)
	_shown.resize(BEDS)
	_shown.fill("")
	_blink.resize(BEDS)
	_blink.fill(0.0)
	for i in BEDS:
		var g := Node3D.new()
		g.name = "Bed %d" % i
		g.position = bed_local(i)
		_holder.add_child(g)
		var spot := USE_SPOT.make(Vector3.ZERO, _offer.bind(i), _use.bind(i), 1.1, 1.4)
		spot.name = "Spot"
		g.add_child(spot)
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_holder):
		return
	for i in BEDS:
		var key := "%d:%s:%s" % [stage(i), str(beds[i].crop), "dry" if thirsty(i) else "wet"]
		if i < _shown.size() and _shown[i] == key:
			continue
		if i < _shown.size():
			_shown[i] = key
		var g := _holder.get_node_or_null("Bed %d" % i) as Node3D
		if g == null:
			continue
		var old := g.get_node_or_null("Look")
		if old:
			g.remove_child(old)
			old.queue_free()
		var look := bed_look(stage(i), str(beds[i].crop), thirsty(i))
		look.name = "Look"
		g.add_child(look)


func _animate(delta: float) -> void:
	# The plants' eyes follow the player about and blink now and then; thirsty ones' water drops bob
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var t := Time.get_ticks_msec() / 1000.0
	for i in BEDS:
		var g := _holder.get_node_or_null("Bed %d/Look" % i) as Node3D
		if g == null:
			continue
		var eyes := g.find_child("Eyes", true, false) as Node3D
		if eyes:
			if player and player.global_position.distance_to(eyes.global_position) < 12.0:
				var to := player.global_position - eyes.global_position
				var want := atan2(to.x, to.z) - g.global_rotation.y
				eyes.rotation.y = lerp_angle(eyes.rotation.y, want, minf(delta * 4.0, 1.0))
			_blink[i] = float(_blink[i]) - delta
			if float(_blink[i]) <= 0.0:
				_blink[i] = randf_range(2.0, 5.0)
			eyes.scale.y = 0.15 if float(_blink[i]) < 0.12 else 1.0
		var drop := g.find_child("Drop", true, false) as Node3D
		if drop:
			drop.position.y = 1.2 + sin(t * 3.0 + i) * 0.08


func _fx(i: int, what: String) -> void:
	if not is_instance_valid(_holder):
		return
	var at := _holder.to_global(bed_local(i)) + Vector3(0, 0.3, 0)
	match what:
		"dig", "plant":
			Juice.dust(_holder, at, 0.5, Color(0.36, 0.24, 0.16))
			Audio.play("pickup", -12.0, 0.15)
		"water":
			Fx.burst(_holder, at + Vector3(0, 0.6, 0), Color(0.5, 0.8, 1.0), 12, 0.05, 1.6, -6.0, 0.6)
		"harvest":
			Fx.burst(_holder, at + Vector3(0, 0.5, 0), Color(1.0, 0.9, 0.5), 16, 0.07, 2.8, -3.0, 0.8)
			Juice.blip("chime", 1.3, -6.0)
			Juice.rumble(0.2, 0.08)
	_shown[i] = ""
	_refresh()


# -----------------------------------------------------------------------------
# Looks, made from shapes
# -----------------------------------------------------------------------------
static func _mat(c: Color, rough := 0.7, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scale
	parent.add_child(m)
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sph(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	return c


func _build_plot(g: Node3D) -> void:
	# A low lilac picket fence round the beds with a gap facing the path, a little sign, a water barrel and a
	# wheelbarrow of soil
	var wood := _mat(Color(0.85, 0.75, 0.95))
	var path := _mat(Color(0.82, 0.78, 0.7), 0.9)
	var half := plot_half()
	_mesh(g, _box(Vector3(half.x * 2.0, 0.04, half.y * 2.0)), path, Vector3(0, 0.02, 0))
	for side in [-1, 1]:
		for k in 15:                                    # along the north and south sides
			var x := -half.x + k * (half.x * 2.0 / 14.0)
			_mesh(g, _box(Vector3(0.1, 0.6, 0.06)), wood, Vector3(x, 0.3, side * half.y))
		_mesh(g, _box(Vector3(half.x * 2.0, 0.07, 0.05)), wood, Vector3(0, 0.42, side * half.y))
	for side in [-1, 1]:
		var posts := int(half.y * 4.0) + 1
		for k in posts:                                 # west and east, with the gate gap in the east side's middle
			var z := -half.y + k * (half.y * 2.0 / (posts - 1))
			if side > 0 and absf(z) < 0.8:
				continue
			_mesh(g, _box(Vector3(0.06, 0.6, 0.1)), wood, Vector3(side * half.x, 0.3, z))
		if side < 0:
			_mesh(g, _box(Vector3(0.05, 0.07, half.y * 2.0)), wood, Vector3(-half.x, 0.42, 0))
		else:
			for end in [-1, 1]:
				_mesh(g, _box(Vector3(0.05, 0.07, half.y - 0.8)), wood, Vector3(half.x, 0.42, end * (half.y + 0.8) / 2.0))
	# The sign by the gate
	_mesh(g, _cyl(0.05, 0.05, 1.3), wood, Vector3(half.x + 0.4, 0.65, -1.1))
	_mesh(g, _box(Vector3(0.08, 0.5, 1.1)), _mat(Color(0.55, 0.35, 0.75)), Vector3(half.x + 0.42, 1.2, -1.1))
	var label := Label3D.new()
	label.text = "Your Garden"
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color(1.0, 0.95, 0.75)
	label.outline_modulate = Color(0.2, 0.08, 0.3)
	label.position = Vector3(half.x + 0.47, 1.2, -1.1)
	label.rotation.y = PI / 2.0
	g.add_child(label)
	# A water barrel in the north-west corner (lots of water in the Void) and a little wheelbarrow of soil
	_mesh(g, _cyl(0.38, 0.32, 0.8), _mat(Color(0.5, 0.33, 0.22)), Vector3(-half.x + 0.55, 0.4, -half.y + 0.55))
	_mesh(g, _cyl(0.34, 0.34, 0.04), _mat(Color(0.4, 0.75, 1.0), 0.05), Vector3(-half.x + 0.55, 0.79, -half.y + 0.55))
	_mesh(g, _box(Vector3(0.7, 0.3, 0.5)), _mat(Color(0.45, 0.85, 0.9)), Vector3(-half.x + 0.6, 0.35, half.y - 0.55), Vector3(0, 0, 0.1))
	_mesh(g, _sph(0.3, 0.25), _mat(Color(0.36, 0.24, 0.16), 1.0), Vector3(-half.x + 0.6, 0.5, half.y - 0.55))
	_mesh(g, _cyl(0.12, 0.12, 0.06), _mat(Color(0.2, 0.2, 0.25)), Vector3(-half.x + 0.95, 0.12, half.y - 0.55), Vector3(PI / 2, 0, 0))
	# The barrel stops you walking through it
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.38
	cyl.height = 0.8
	shape.shape = cyl
	body.position = Vector3(-half.x + 0.55, 0.4, -half.y + 0.55)
	body.add_child(shape)
	g.add_child(body)


func _clear_nursery(s: Node) -> void:
	# The builder's decorative soil rows and leafy balls in front of the greenhouse ("Garden Soil" and "Garden Leaf",
	# tools/build_town.gd) are where the garden goes now, so they're hidden (the greenhouse and sign stay).
	var g := s.get_node_or_null("Secret Gardens")
	if g == null:
		return
	for m in g.find_children("*", "MeshInstance3D", true, false):
		var mat := (m as MeshInstance3D).get_active_material(0)
		if mat and mat.resource_name in ["Garden Soil", "Garden Leaf"]:
			(m as MeshInstance3D).visible = false


static func bed_look(st: int, crop: String, dry: bool) -> Node3D:
	# One bed: grass with a few pebbles before it's dug, then brown soil in rows, then whatever's growing in it
	var g := Node3D.new()
	if st < 0:
		_mesh(g, _box(Vector3(BED_SIZE.x, 0.06, BED_SIZE.y)), _mat(Color(0.35, 0.85, 0.6)), Vector3(0, 0.05, 0))
		for k in 3:
			_mesh(g, _sph(0.08, 0.08), _mat(Color(0.6, 0.6, 0.7)), Vector3(-0.4 + k * 0.4, 0.09, 0.2 - k * 0.15))
		return g
	var soil := _mat(Color(0.36, 0.24, 0.16) if dry or crop == "" else Color(0.24, 0.15, 0.1), 1.0)
	_mesh(g, _box(Vector3(BED_SIZE.x + 0.1, 0.18, BED_SIZE.y + 0.1)), _mat(Color(0.6, 0.45, 0.8)), Vector3(0, 0.09, 0))
	_mesh(g, _box(Vector3(BED_SIZE.x, 0.06, BED_SIZE.y)), soil, Vector3(0, 0.19, 0))
	for k in 3:                                          # three soft rounded rows of earth
		_mesh(g, _cyl(0.09, 0.09, BED_SIZE.x - 0.15), soil, Vector3(0, 0.2, -0.35 + k * 0.35), Vector3(0, 0, PI / 2),
			Vector3(1.0, 1.0, 0.7))
	if crop == "" or st <= 0:
		return g
	var c: Dictionary = CROPS.get(crop, CROPS.blinkberry)
	var col: Color = c.colour
	var plant := Node3D.new()
	plant.name = "Plant"
	plant.position.y = 0.24
	g.add_child(plant)
	if dry:
		plant.rotation.z = 0.25                         # a little droop
		var drop := Node3D.new()
		drop.name = "Drop"
		g.add_child(drop)
		_mesh(drop, _sph(0.1), _mat(Color(0.45, 0.75, 1.0), 0.1, 0.8), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.3, 1))
		_mesh(drop, _cyl(0.0, 0.07, 0.14), _mat(Color(0.45, 0.75, 1.0), 0.1, 0.8), Vector3(0, 0.13, 0))
	if st == 1:
		_mesh(plant, _sph(0.12, 0.1), _mat(Color(0.3, 0.2, 0.12), 1.0), Vector3(0, 0.03, 0))
		_mesh(plant, _cyl(0.01, 0.02, 0.1), _mat(Color(0.5, 0.95, 0.4)), Vector3(0, 0.1, 0))
		return g
	var leaf := _mat(Color(0.45, 0.95, 0.55))
	var size: float = [0.0, 0.0, 0.35, 0.65, 0.85, 1.0][st]
	_mesh(plant, _cyl(0.025, 0.04, 0.5 * size), leaf, Vector3(0, 0.25 * size, 0))
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		_mesh(plant, _sph(0.18 * size, 0.06), leaf, Vector3(cos(a) * 0.18 * size, 0.12 * size + 0.05 * k * size, sin(a) * 0.18 * size),
			Vector3(0.0, -a, 0.5))
	if st == 2:
		return g
	# The crop itself, with its eyes, growing as it ripens
	var ripe := st == 5
	var fruit_mat := _mat(col, 0.4, 0.5 if ripe else 0.0)
	var head := Node3D.new()
	head.name = "Eyes"
	head.position.y = 0.5 * size + 0.1
	plant.add_child(head)
	var r := 0.0
	match str(c.look):
		"berry":
			r = 0.12 * size
			for k in 3:
				var a := k * TAU / 3.0
				_mesh(head, _sph(r), fruit_mat, Vector3(cos(a) * r * 1.3, 0.0, sin(a) * r * 1.3))
			_eyes(head, Vector3(0, r * 0.4, r * 2.2), r * 0.5)
		"root":
			r = 0.14 * size
			head.position.y = 0.08
			_mesh(head, _cyl(r * 0.5, r, r * 2.2), fruit_mat, Vector3(0, r * 0.6, 0))
			for k in 3:
				_mesh(head, _sph(0.1 * size, 0.04), leaf, Vector3(0, r * 1.9, 0), Vector3(0.5, k * 2.1, 0.0), Vector3(1.0, 1.0, 2.2))
			_eyes(head, Vector3(0, r * 1.0, r * 0.85), r * 0.45)
		"gourd":
			r = 0.32 * size
			head.position.y = r * 0.8
			_mesh(head, _sph(r), fruit_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.85, 1.1))
			_mesh(head, _cyl(0.03, 0.05, 0.15), _mat(Color(0.3, 0.6, 0.3)), Vector3(0, r * 0.9, 0))
			_eyes(head, Vector3(0, r * 0.2, r * 1.0), r * 0.32)
		"mushroom":
			# A fat stalk and a round glowing cap, eyes on the stalk under the cap. It glows a little all the time
			# and properly once it's ripe (Pip's caves are dark: Glowcaps never learned to switch off).
			r = 0.22 * size
			head.position.y = 0.05
			var cap := _mat(col, 0.3, 1.2 if ripe else 0.45)
			_mesh(head, _cyl(r * 0.45, r * 0.6, r * 1.6), _mat(Color(0.92, 0.9, 1.0)), Vector3(0, r * 0.8, 0))
			_mesh(head, _sph(r * 1.2, r * 0.7), cap, Vector3(0, r * 1.75, 0))
			for k in 5:
				var a := k * TAU / 5.0
				_mesh(head, _sph(r * 0.16), _mat(Color(1, 1, 1), 0.3, 0.8), Vector3(cos(a) * r * 0.7, r * 2.15, sin(a) * r * 0.7))
			_eyes(head, Vector3(0, r * 0.9, r * 0.55), r * 0.35)
			var glow := OmniLight3D.new()
			glow.light_color = col
			glow.light_energy = 0.35
			glow.omni_range = 1.4
			glow.position.y = r * 1.8
			head.add_child(glow)
		_:
			r = 0.15 * size
			var gem := Remnants.remnant(1.6 * size + 0.2)
			head.add_child(gem)
			_eyes(head, Vector3(0, r * 0.4, r * 0.9), r * 0.4)
	if ripe:
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.7
		light.omni_range = 1.6
		light.position.y = 0.3
		head.add_child(light)
	return g


static func _eyes(parent: Node3D, at: Vector3, size: float) -> void:
	# A pair of round white eyes with dark pupils, facing +z (the plant turns them toward the player)
	var white := _mat(Color(1, 1, 1), 0.3)
	var dark := _mat(Color(0.08, 0.04, 0.12), 0.2)
	for side in [-1, 1]:
		var e := at + Vector3(side * size * 0.9, 0, 0)
		_mesh(parent, _sph(size * 0.55), white, e)
		_mesh(parent, _sph(size * 0.3), dark, e + Vector3(0, 0, size * 0.35))


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	update()
	return {"beds": beds.duplicate(true), "seeds": seeds.duplicate(), "crops": crops.duplicate(), "harvested": harvested}


func load_data(data: Dictionary) -> void:
	reset()
	var saved = data.get("beds", [])
	if saved is Array:
		for i in mini(saved.size(), BEDS):
			var b = saved[i]
			if b is Dictionary:
				beds[i] = {"tilled": bool(b.get("tilled", false)),
					"crop": str(b.get("crop", "")) if CROPS.has(str(b.get("crop", ""))) else "",
					"grown": float(b.get("grown", 0.0)), "water_until": float(b.get("water_until", 0.0)),
					"last": float(b.get("last", 0.0))}
	for pair in [[seeds, data.get("seeds", {})], [crops, data.get("crops", {})]]:
		if pair[1] is Dictionary:
			for k in pair[1]:
				if CROPS.has(str(k)) and int(pair[1][k]) > 0:
					pair[0][str(k)] = int(pair[1][k])
	harvested = int(data.get("harvested", 0))
	_shown = []
	if is_instance_valid(_holder):
		_shown.resize(BEDS)
		_shown.fill("")
	changed.emit()


func reset() -> void:
	beds.clear()
	for i in BEDS:
		beds.append({"tilled": false, "crop": "", "grown": 0.0, "water_until": 0.0, "last": 0.0})
	seeds.clear()
	crops.clear()
	harvested = 0
	_shown = []
	if is_instance_valid(_holder):
		_shown.resize(BEDS)
		_shown.fill("")
	changed.emit()
