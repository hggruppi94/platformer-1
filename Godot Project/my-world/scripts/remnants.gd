extends Node

# Autoload "Remnants": the Void's second, rarer money, and Bramble's harvesting tool (plan items 17 and 18, Hayden's
# 7 Nov 2026 notes). Sparkles stay the everyday money. Remnants are sparkles squeezed together over a very long time:
# little glowing crystals, uranium green on obsidian black. They grow in the ground like roots of time, in big
# **Remnant veins** round the Void that nobody can open by hand. Bramble, who grew up on a world where every plant
# shares one mind, can coax them out, so she and the player build a **harvesting tool** together (the quest "Bramble's
# Harvest", res://quests/brambles_harvest.json), and from then on she burrows over to help whenever the player
# harvests a vein. Each vein gives a handful once a Void day, then regrows.
#
# Remnants pay for bigger things in the shops (an item with "currency": "remnant", scripts/shop.gd) and the Remnant
# sprout seed for the garden (scripts/farm.gd), and later they'll buy extra time inside portal worlds (plan item 19).
# The HUD shows them under the sparkles once there are any (scripts/hud.gd), and the Bag sheet has a line for them.
#
# The quest's three tool parts, the veins and Bramble's helping visits aren't in the built town: like the lost
# watches (scripts/watches.gd), this puts them in at play time. Saved with the game as "remnants" (scripts/game.gd);
# saves from before have none. The quest's progress is all Dialogue flags, so that's saved too.

signal changed

const USE_SPOT := preload("res://scripts/use_spot.gd")

const TOWN := "res://scenes/town/town.tscn"
const QUEST := "brambles_harvest"
const PER_VEIN := 3                     # Remnants a vein gives when it's harvested
const BRAMBLE_MODEL := "res://models/characters/plant_girl.glb"

# The veins: where they are in the Void ([x, z]; the ground's height is found at play time) and what to call them.
# (The lake shore's sat right on the Lake Loop's racing line at (-40, 14), so racers ran into its crystals; since the
# 10 Nov playthrough it's 7 m further back from the water, off every lane, path and tree.)
const VEINS := [
	{"id": "castle_rock", "name": "the castle rock", "at": Vector2(20, -105)},
	{"id": "spooky_woods", "name": "the Spooky Woods", "at": Vector2(-125, -95)},
	{"id": "lake_shore", "name": "the lake shore", "at": Vector2(-45, 20)},
	{"id": "gardens", "name": "the Secret Gardens", "at": Vector2(-70, -35)},
	{"id": "rock_wall", "name": "the rock wall", "at": Vector2(118, 48)},
]

# The harvesting tool's three parts (the quest's first step): each one lies about while that step's on.
const PARTS := [
	{"id": "handle", "name": "Rootwood Handle", "flag": "harvest_part_handle", "at": Vector2(-88, -38),
		"found": "A rootwood handle! It's warm, and it hums a little, like it's happy to be held."},
	{"id": "scoop", "name": "Moonshell Scoop", "flag": "harvest_part_scoop", "at": Vector2(17, 25),
		"found": "A moonshell scoop, washed up by the dock. It's shiny on the inside, like a rainbow."},
	{"id": "crystal", "name": "Hum Crystal", "flag": "harvest_part_crystal", "at": Vector2(96, -74),
		"found": "A hum crystal from the Observatory hill! Hold it near the ground and it buzzes."},
]

# What the tool can look like (the player picks when Bramble puts it together)
const LOOKS := {"leaf": "Leafy Trowel", "crystal": "Crystal Pick", "star": "Star Scoop"}

var count := 0                          # Remnants in the player's pocket
var veins_taken := {}                   # vein id -> the Void day it was last harvested

var _scene: Node
var _holder: Node3D
var _busy := false                      # Bramble's on her way to a vein


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_busy = false
		if s and s.scene_file_path == TOWN:
			_place_in.call_deferred(s)


# -----------------------------------------------------------------------------
# The money
# -----------------------------------------------------------------------------
func add(n: int, why := "") -> void:
	count += n
	changed.emit()
	if why != "":
		Game.message("%s +%d Remnant%s" % [why, n, "" if n == 1 else "s"])


func spend(n: int) -> bool:
	if count < n:
		return false
	count -= n
	changed.emit()
	return true


static func words(n: int) -> String:
	return "◆ %d Remnant%s" % [n, "" if n == 1 else "s"]


func shown() -> bool:
	# The HUD's line: once there are any, or once Bramble's told the player about them
	return count > 0 or Quests.is_started(QUEST) or Quests.is_done(QUEST)


# -----------------------------------------------------------------------------
# The tool
# -----------------------------------------------------------------------------
func has_tool() -> bool:
	return Dialogue.flags.has("harvest_tool_built")


func tool_look() -> String:
	for k in LOOKS:
		if Dialogue.flags.has("harvest_look_" + k):
			return k
	return "leaf"


func tool_name() -> String:
	return str(LOOKS[tool_look()])


func parts_found() -> int:
	return PARTS.filter(func(p: Dictionary) -> bool: return Dialogue.flags.has(p.flag)).size()


# -----------------------------------------------------------------------------
# The veins
# -----------------------------------------------------------------------------
func vein(id: String) -> Dictionary:
	for v in VEINS:
		if v.id == id:
			return v
	return {}


func is_ready(id: String) -> bool:
	# Regrown? A vein comes back the Void day after it was harvested
	return int(veins_taken.get(id, -999)) != Clock.day


func harvest(id: String) -> bool:
	# Take a vein's Remnants (the quick way, with no Bramble visit: tests, and the end of the visit below)
	if not has_tool() or not is_ready(id) or vein(id).is_empty():
		return false
	veins_taken[id] = Clock.day
	add(PER_VEIN, "Remnants from %s!" % vein(id).name)
	if not Dialogue.flags.has("harvest_first_vein"):
		Dialogue.set_flag("harvest_first_vein")
	_refresh_veins()
	Game.save_game()
	return true


func _vein_offer(id: String) -> String:
	if _busy:
		return ""
	if not has_tool():
		return "look at the glowing crystals"
	return "harvest Remnants" if is_ready(id) else ""


func _use_vein(id: String) -> void:
	if not has_tool():
		Game.message("Glowing crystals, deep in the rock. Too deep to dig out by hand... Bramble might know how.")
		Audio.play("ui_back", -8.0)
		return
	if not is_ready(id) or _busy:
		return
	_bramble_visit(id)


func _bramble_visit(id: String) -> void:
	# Bramble burrows over (a little mound of soil racing along), sprouts up by the vein, coaxes the crystals out with
	# a wave, and burrows off home again (her model, like scripts/burrower.gd does it)
	var spot := _holder.get_node_or_null("Vein " + id) as Node3D if is_instance_valid(_holder) else null
	if spot == null:
		harvest(id)
		return
	_busy = true
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var side := Vector3.RIGHT
	if player:
		var to := player.global_position - spot.global_position
		to.y = 0.0
		if to.length() > 0.1:
			side = to.normalized().cross(Vector3.UP)
	var at := spot.global_position + side * 1.8
	var helper := Node3D.new()
	helper.name = "Bramble Helps"
	_holder.add_child(helper)
	helper.global_position = at + side * 7.0
	var mound := _mound()
	helper.add_child(mound)
	var model := (load(BRAMBLE_MODEL) as PackedScene).instantiate() as Node3D
	model.visible = false
	model.position.y = -2.3
	helper.add_child(model)
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	Juice.dust(_holder, helper.global_position, 0.5, Color(0.36, 0.24, 0.16))
	var tw := create_tween()
	tw.tween_property(helper, "global_position", at, 0.9).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(mound, "rotation:y", TAU * 2.0, 0.9)
	tw.tween_callback(func() -> void:
		mound.visible = false
		model.visible = true
		if player:
			helper.look_at(Vector3(player.global_position.x, helper.global_position.y, player.global_position.z), Vector3.UP, true)
		if anim and anim.has_animation("sprout"):
			anim.play("sprout", 0.1)
		Juice.dust(_holder, at, 0.6, Color(0.36, 0.24, 0.16))
		Audio.play("pickup", -10.0, 0.1))
	tw.tween_property(model, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if anim and anim.has_animation("wave"):
			anim.play("wave", 0.15)
		Game.message("Bramble: \"Come on out, little ones... gently...\""))
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void:
		var top := spot.global_position + Vector3(0, 1.0, 0)
		Fx.burst(_holder, top, Color(0.55, 1.0, 0.35), 22, 0.08, 3.5, -3.0, 0.9)
		Fx.burst(_holder, top, Color(0.2, 0.15, 0.3), 8, 0.06, 2.0, -4.0, 0.6)
		Juice.blip("sparkle", 1.4, -6.0)
		Juice.shake(0.12)
		Juice.rumble(0.3, 0.15)
		harvest(id))
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void:
		if anim and anim.has_animation("burrow"):
			anim.play("burrow", 0.1)
		Juice.dust(_holder, at, 0.6, Color(0.36, 0.24, 0.16)))
	tw.tween_property(model, "position:y", -2.3, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		helper.queue_free()
		_busy = false)


func _mound() -> Node3D:
	var g := Node3D.new()
	var hump := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	hump.mesh = s
	hump.scale = Vector3(1.0, 0.5, 1.0)
	hump.material_override = _mat(Color(0.36, 0.24, 0.16), 1.0)
	g.add_child(hump)
	var sprig := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.02
	c.bottom_radius = 0.04
	c.height = 0.5
	sprig.mesh = c
	sprig.position.y = 0.4
	sprig.material_override = _mat(Color(0.5, 0.95, 0.4), 0.6)
	g.add_child(sprig)
	return g


# -----------------------------------------------------------------------------
# Putting it all in the town
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null("Remnants") != null:
		return
	_holder = Node3D.new()
	_holder.name = "Remnants"
	s.add_child(_holder)
	for v in VEINS:
		var g := vein_model()
		g.name = "Vein " + str(v.id)
		g.position = _ground(s, v.at)
		g.rotation.y = hash(v.id) % 628 / 100.0
		_holder.add_child(g)
		var id := str(v.id)
		var spot := USE_SPOT.make(Vector3.ZERO, _vein_offer.bind(id), _use_vein.bind(id), 2.6, 2.6)
		spot.name = "Spot"
		g.add_child(spot)
	for p in PARTS:
		var part := part_model(str(p.id))
		part.name = "Part " + str(p.id)
		part.position = _ground(s, p.at) + Vector3(0, 0.6, 0)
		_holder.add_child(part)
		var pick := USE_SPOT.make(Vector3(0, -0.6, 0), _part_offer.bind(p), _pick_part.bind(p), 1.8, 1.6)
		pick.name = "Spot"
		part.add_child(pick)
	_refresh_veins()


func _ground(s: Node, at: Vector2) -> Vector3:
	# The ground's height there (the town's terrain, or whatever's built on it)
	var space := (s as Node3D).get_world_3d().direct_space_state if s is Node3D else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 300.0, at.y), Vector3(at.x, -60.0, at.y))
		var hit := space.intersect_ray(q)
		if hit:
			return hit.position
	return Vector3(at.x, 0.0, at.y)


func ground_at(at: Vector2) -> Vector3:
	return _ground(get_tree().current_scene, at)


func _refresh_veins() -> void:
	# A harvested vein shows only its stubs (and the big crystals come back the next Void day)
	if not is_instance_valid(_holder):
		return
	for v in VEINS:
		var g := _holder.get_node_or_null("Vein " + str(v.id)) as Node3D
		if g:
			var full := is_ready(str(v.id))
			(g.get_node("Crystals") as Node3D).visible = full
			(g.get_node("Stubs") as Node3D).visible = not full
			(g.get_node("Glow") as OmniLight3D).visible = full


func _part_offer(p: Dictionary) -> String:
	return "pick up the %s" % p.name if _part_open(p) else ""


func _part_open(p: Dictionary) -> bool:
	return Quests.is_ready(QUEST, "parts") and not Dialogue.flags.has(p.flag)


func _pick_part(p: Dictionary) -> void:
	if not _part_open(p):
		return
	Dialogue.set_flag(p.flag)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("chime", 1.2, -6.0)
	var n := parts_found()
	Game.message("%s (%d of 3)" % [p.found, n] if n < 3 else "%s That's all three! Take them to Bramble." % p.found)
	var node := _holder.get_node_or_null("Part " + str(p.id)) as Node3D if is_instance_valid(_holder) else null
	if node:
		Fx.burst(_holder, node.global_position, Color(0.6, 1.0, 0.5), 14, 0.06, 2.5, -2.0, 0.7)
	Game.save_game()


func _physics_process(delta: float) -> void:
	# Parts bob and spin while they're waiting to be found, and hide otherwise
	if not is_instance_valid(_holder):
		return
	var t := Time.get_ticks_msec() / 1000.0
	for p in PARTS:
		var node := _holder.get_node_or_null("Part " + str(p.id)) as Node3D
		if node:
			var open := _part_open(p)
			(node.get_node("Look") as Node3D).visible = open
			if open:
				var look := node.get_node("Look") as Node3D
				look.rotation.y += delta * 1.2
				look.position.y = sin(t * 2.0) * 0.12


# -----------------------------------------------------------------------------
# Looks, made from shapes
# -----------------------------------------------------------------------------
static func crystal_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 1.0, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.35, 1.0, 0.25)
	m.emission_energy_multiplier = 1.6
	m.metallic = 0.3
	m.roughness = 0.15
	return m


static func obsidian_mat() -> StandardMaterial3D:
	var m := _mat(Color(0.12, 0.08, 0.18), 0.2)
	m.metallic = 0.4
	return m


static func _mat(c: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func crystal_mesh(r: float, h: float) -> CylinderMesh:
	# A six-sided prism with a pointy top
	var c := CylinderMesh.new()
	c.top_radius = r * 0.15
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	return c


static func remnant(size := 1.0) -> Node3D:
	# One Remnant: a little green crystal on a chip of obsidian (the Remnant sprout grows one: scripts/farm.gd)
	var g := Node3D.new()
	var gem := MeshInstance3D.new()
	gem.mesh = crystal_mesh(0.09 * size, 0.32 * size)
	gem.material_override = crystal_mat()
	gem.position.y = 0.16 * size
	g.add_child(gem)
	for k in 2:
		var small := MeshInstance3D.new()
		small.mesh = crystal_mesh(0.05 * size, 0.18 * size)
		small.material_override = crystal_mat()
		small.position = Vector3((k * 2 - 1) * 0.07 * size, 0.08 * size, 0.02 * size)
		small.rotation.z = (1 - k * 2) * 0.5
		g.add_child(small)
	var chip := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1 * size
	s.height = 0.12 * size
	s.radial_segments = 6
	s.rings = 2
	chip.mesh = s
	chip.material_override = obsidian_mat()
	g.add_child(chip)
	return g


static func vein_model() -> Node3D:
	# A big Remnant vein: black glassy rock bursting with tall glowing green crystals (and, once harvested, just stubs)
	var g := Node3D.new()
	var rock := obsidian_mat()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 5:
		var r := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.6, 1.0)
		s.height = s.radius * 1.4
		s.radial_segments = 7
		s.rings = 3
		r.mesh = s
		var a := k * TAU / 5.0
		r.position = Vector3(cos(a) * 0.7, 0.15, sin(a) * 0.7)
		r.material_override = rock
		g.add_child(r)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 1.0
	shape.shape = cyl
	shape.position.y = 0.4
	body.add_child(shape)
	g.add_child(body)
	var crystals := Node3D.new()
	crystals.name = "Crystals"
	g.add_child(crystals)
	var stubs := Node3D.new()
	stubs.name = "Stubs"
	g.add_child(stubs)
	var glow_mat := crystal_mat()
	for k in 9:
		var a := k * TAU / 9.0 + rng.randf_range(-0.2, 0.2)
		var d := 0.15 + rng.randf_range(0.0, 0.8)
		var h := rng.randf_range(1.0, 2.4) * (1.3 if d < 0.4 else 1.0)
		var c := MeshInstance3D.new()
		c.mesh = crystal_mesh(rng.randf_range(0.14, 0.26), h)
		c.material_override = glow_mat
		c.position = Vector3(cos(a) * d, 0.4 + h * 0.5, sin(a) * d)
		c.rotation = Vector3(sin(a) * 0.35 * d, 0.0, -cos(a) * 0.35 * d)
		crystals.add_child(c)
		var stub := MeshInstance3D.new()
		stub.mesh = crystal_mesh(0.14, 0.3)
		stub.material_override = glow_mat
		stub.position = Vector3(cos(a) * d, 0.5, sin(a) * d)
		stubs.add_child(stub)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(0.45, 1.0, 0.35)
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position.y = 1.4
	g.add_child(light)
	return g


static func part_model(id: String) -> Node3D:
	# The three parts of the harvesting tool, each with a soft glow so they're easy to spot
	var g := Node3D.new()
	var look := Node3D.new()
	look.name = "Look"
	g.add_child(look)
	match id:
		"handle":
			var h := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.06
			c.bottom_radius = 0.08
			c.height = 0.7
			h.mesh = c
			h.material_override = _mat(Color(0.55, 0.35, 0.2), 0.8)
			h.rotation.z = 0.4
			look.add_child(h)
			for k in 3:
				var leaf := MeshInstance3D.new()
				var s := SphereMesh.new()
				s.radius = 0.08
				s.height = 0.05
				leaf.mesh = s
				leaf.material_override = _mat(Color(0.5, 0.95, 0.4))
				leaf.position = Vector3(0.05 * k - 0.05, 0.1 + 0.15 * k, 0.07)
				look.add_child(leaf)
		"scoop":
			var sh := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.25
			s.height = 0.25
			s.is_hemisphere = true
			sh.mesh = s
			var m := _mat(Color(0.95, 0.85, 1.0), 0.15)
			m.metallic = 0.6
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			sh.material_override = m
			sh.rotation.x = PI
			look.add_child(sh)
		_:
			var gem := MeshInstance3D.new()
			gem.mesh = crystal_mesh(0.14, 0.5)
			var m := crystal_mat()
			m.albedo_color = Color(0.6, 0.85, 1.0)
			m.emission = Color(0.5, 0.8, 1.0)
			gem.material_override = m
			look.add_child(gem)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 1.0, 0.7)
	light.light_energy = 0.8
	light.omni_range = 2.5
	look.add_child(light)
	return g


# -----------------------------------------------------------------------------
# Dialogue hooks
# -----------------------------------------------------------------------------
func fill() -> Dictionary:
	# Words dialogue can use: {remnants}, {tool}, {parts_found}
	return {"remnants": str(count), "tool": tool_name(), "parts_found": str(parts_found())}


# -----------------------------------------------------------------------------
# Saving
# -----------------------------------------------------------------------------
func save_data() -> Dictionary:
	return {"count": count, "veins_taken": veins_taken.duplicate()}


func load_data(data: Dictionary) -> void:
	reset()
	count = maxi(int(data.get("count", 0)), 0)
	var taken = data.get("veins_taken", {})
	if taken is Dictionary:
		for k in taken:
			veins_taken[str(k)] = int(taken[k])
	changed.emit()


func reset() -> void:
	count = 0
	veins_taken.clear()
	_refresh_veins()
	changed.emit()
