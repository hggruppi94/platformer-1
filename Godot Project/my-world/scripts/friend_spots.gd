extends Node3D

# Friend spots: one secret in each of five mended portal worlds that only a friend's move can open, and the Seam, a
# hidden crack between two worlds (slice 3 of the "feels bigger" plan, https://claude.ai/artifact/KaGrzJgy9bvxU891Bchtog:
# "friend-move-only spots in mended portal worlds, maybe a hidden crack between two worlds"; Hayden's standing rule,
# 17 Nov 2026: when a section's done, start the next one from the plan).
#
# Before writing it we read open-source metroidvania work (Hayden's rule): KoBeWi/Metroidvania-System (MIT: every
# switch, wall or chest that stays changed gets a lasting id of its own, and collectibles are a list you can count and
# show) and gdquest-demos/godot-platformer-2d (MIT: a gate just asks "has the player got this ability?"). So here it's
# one list (SPOTS), each spot's state is two Dialogue flags (saved like everything else), and a spot simply watches
# for its friend's move being done next to it. Nothing in the move scripts changed.
#
# Each spot is in a world whose own friend ISN'T the one it needs, so you come back later with someone new:
#   lonely_shard    Shard Isle      Nina and Bruno   Make at the stone on the rim and a bridge of their pink and blue
#                                                   planks builds itself up to a crystal islet floating out of reach
#   sleepy_bud      the Rootmind    Melody           a giant flower bud, fast asleep: Groove by it three times and it
#                                                   wakes up dancing and blooms
#   ice_chest       Frozen Moment   Heather          a chest frozen in a block of ice: April Showers on it and the
#                                                   warm rain melts it free
#   buried_lantern  Lanternmoor     Bramble          a ring of glowcaps round a heap of soft soil: Burrow into it and
#                                                   dig up a lantern chest
#   hot_spring      Glenmoor        Flurry           a hot spring geyser roaring in the mouth of a rocky nook: Frost
#                                                   breath freezes it solid and you can walk in
# The friend's name glows over the spot's stone when you're close (no other words), and once that friend's joined, the
# Friend button by the spot calls them in to help, whoever's with you (scripts/party.gd _who_for(); the HUD's face
# bubble shows who). Opening it (flag friend_spot_<id>_open) shows a chest; the chest (flag friend_spot_<id>) gives
# SPARKLES and REMNANTS once, and all five give the Friendship Circlet hat and SET_SPARKLES.
#
# The Seam: at the back of the hot spring's nook in Glenmoor (once Lanternmoor's mended too) a little violet crack
# leads straight to Lanternmoor, the night world, coming out by the buried lantern; after that a twin crack there leads
# back. The first time through: SEAM_SPARKLES (flag seam_found).
#
# Only in a mended world, and never on a practice trip (worlds are played from the start there). Put in by
# scripts/portal_world.gd _place_shared() at play time, so no built scene changed. No class_name: preload it.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const SPARKLES := 10
const REMNANTS := 2
const SET_SPARKLES := 20
const SET_HAT := "friendship_circlet"
const SEAM_SPARKLES := 10
const HELP_R := 7.0                      # the Friend button calls the spot's friend in this close
const NAME_R := 12.0                     # the friend's name shows over the stone this close
const GROOVES := 3                       # grooves the bud needs to wake
const PERCH_UP := 4.5                    # the Lonely Shard floats this far above the main island
const PERCH_OUT := 13.0                  # ...this far out from the rim
const LANDING_Z := PERCH_OUT - 2.8       # the bridge's flat last plank, half on the perch (no lip at the top)
const LANDING_LONG := 1.8

# id, world, the friend it needs, its name (for the Bag), where (on the ground: the stone the move's done at), and
# which way the spot faces (yaw: its front, where you stand). Every name, look and spot is a first draft for Hayden.
const SPOTS := [
	{"id": "lonely_shard", "world": "shard_isle", "friend": "nina_bruno", "name": "The Lonely Shard",
		"at": Vector3(9.2, 0.0, 9.2), "yaw": PI * 0.25},
	{"id": "sleepy_bud", "world": "rootmind", "friend": "melody", "name": "The Sleepy Bud",
		"at": Vector3(24.0, 0.0, 12.0), "yaw": -PI * 0.5},
	{"id": "ice_chest", "world": "frozen_moment", "friend": "heather", "name": "The Frozen Chest",
		"at": Vector3(24.0, 0.0, 6.0), "yaw": -PI * 0.6},
	{"id": "buried_lantern", "world": "lanternmoor", "friend": "bramble", "name": "The Buried Lantern",
		"at": Vector3(30.0, 0.0, 0.0), "yaw": -PI * 0.6},
	{"id": "hot_spring", "world": "glenmoor", "friend": "flurry", "name": "The Hot Spring",
		"at": Vector3(20.0, 0.0, -4.0), "yaw": PI * 0.5},
]
# The Seam: from the hot spring's nook (Glenmoor) to beside the buried lantern (Lanternmoor), and back
const SEAM := {
	"glenmoor": {"to": "lanternmoor", "spot": "hot_spring", "local": Vector3(1.4, 0, -4.6), "turn": PI * 0.5},
	"lanternmoor": {"to": "glenmoor", "spot": "buried_lantern", "local": Vector3(-6.5, 0, -1.5), "turn": PI * 0.5},
}
const SEAM_COLOUR := Color(0.7, 0.45, 1.0)

var info: Dictionary = {}
var opened := false
var progress := 0                        # grooves so far (the bud)
var chest: Node3D
var _counts := {}                        # each move's counter last frame, to spot a new one
var _name_tag: Label3D
var _blocker: Node                       # what's in the way till it opens (removed then)
var _t := 0.0
var _opening := false


# -----------------------------------------------------------------------------
# Putting them in
# -----------------------------------------------------------------------------
static func place(world: Node3D, world_id: String) -> void:
	if world == null or world.has_meta("preview") or Portals.practice or not Portals.is_cleared(world_id):
		return
	for s in SPOTS:
		if s.world != world_id:
			continue
		var spot: Node3D = (load("res://scripts/friend_spots.gd") as GDScript).new()
		spot.info = s
		world.add_child(spot)
		spot.name = str(s.name)
		spot.global_position = _ground(world, s.at)
		spot.rotation.y = float(s.yaw)
	_place_seam(world, world_id)


static func flag_open(id: String) -> String:
	return "friend_spot_%s_open" % id


static func flag_found(id: String) -> String:
	return "friend_spot_%s" % id


static func is_open(id: String) -> bool:
	return bool(Dialogue.flags.get(flag_open(id), false))


static func is_found(id: String) -> bool:
	return bool(Dialogue.flags.get(flag_found(id), false))


static func found_count() -> int:
	var n := 0
	for s in SPOTS:
		if is_found(str(s.id)):
			n += 1
	return n


static func spot_info(id: String) -> Dictionary:
	for s in SPOTS:
		if s.id == id:
			return s
	return {}


static func needed_here(player: Node3D) -> String:
	# The friend an unopened spot right here needs (for the Friend button and the HUD's face bubble), or ""
	if player == null or not player.is_inside_tree():
		return ""
	for n in player.get_tree().get_nodes_in_group("friend_spots"):
		if n.opened:
			continue
		var d := Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z)
		if d.length() < HELP_R and absf(n.global_position.y - player.global_position.y) < 4.0:
			return str(n.info.friend)
	return ""


static func _ground(world: Node3D, at: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 30, 0), at + Vector3(0, -30, 0))
	var hit := space.intersect_ray(q)
	return hit.position if hit else at


# -----------------------------------------------------------------------------
# One spot
# -----------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("friend_spots")
	opened = is_open(str(info.id))
	_stone()
	match str(info.id):
		"lonely_shard":
			_build_shard()
		"sleepy_bud":
			_build_bud()
		"ice_chest":
			_build_ice()
		"buried_lantern":
			_build_lantern()
		"hot_spring":
			_build_spring()
	if opened:
		_show_open(true)


func friend_colour() -> Color:
	return Party.friend(str(info.friend)).get("colour", Color(1, 0.85, 0.5))


func _stone() -> void:
	# The marker every spot has: a low round stone with a ring glowing in the friend's colour, and their name over it
	# when you're close
	var stone := MeshInstance3D.new()
	stone.name = "Friend Stone"
	stone.mesh = _cyl(0.75, 0.9, 0.35, 20)
	stone.material_override = _mat(Color(0.55, 0.52, 0.62))
	stone.position = Vector3(0, 0.17, 0)
	add_child(stone)
	var ring := MeshInstance3D.new()
	ring.name = "Glow Ring"
	var t := TorusMesh.new()
	t.inner_radius = 0.48
	t.outer_radius = 0.62
	t.rings = 24
	ring.mesh = t
	ring.material_override = _mat(friend_colour(), 2.2)
	ring.position = Vector3(0, 0.36, 0)
	ring.scale = Vector3(1, 0.4, 1)
	add_child(ring)
	_name_tag = Label3D.new()
	_name_tag.name = "Friend Name"
	_name_tag.text = str(Party.friend(str(info.friend)).get("name", ""))
	_name_tag.font_size = 72
	_name_tag.pixel_size = 0.01
	_name_tag.outline_size = 14
	_name_tag.modulate = friend_colour().lightened(0.35)
	_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_tag.position = Vector3(0, 1.6, 0)
	_name_tag.visible = false
	add_child(_name_tag)


func _process(delta: float) -> void:
	_t += delta
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if _name_tag and p:
		_name_tag.visible = not opened and global_position.distance_to(p.global_position) < NAME_R
		_name_tag.position.y = 1.6 + sin(_t * 2.0) * 0.08
	_animate(delta)


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p == null or opened or _opening:
		_remember(p)
		return
	var near := target().distance_to(p.global_position)
	match str(info.friend):
		"nina_bruno":
			if _new(p, "make", "made_count") and near < 4.5:
				open_up()
		"melody":
			if _new(p, "groove", "grooves") and near < 6.5:
				progress += 1
				_wake_a_bit()
				if progress >= GROOVES:
					open_up()
		"heather":
			if _new(p, "showers", "showers") and near < 6.0:
				_opening = true
				# (the warm rain falls first: the ice melts as the sun comes out)
				get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
					_opening = false
					open_up())
		"bramble":
			var b = p.get("burrow")
			if b != null and b.active and near < 2.8:
				open_up()
		"flurry":
			if _new(p, "frost_breath", "huffs") and near < 8.0 and _facing(p):
				open_up()
	_remember(p)


func target() -> Vector3:
	# What the move has to be done at: the stone for Make, otherwise the thing itself (the bud, the ice, the soil, the
	# geyser), at the height of someone standing by it
	var at := Vector3(0, 0, 0)
	match str(info.id):
		"sleepy_bud":
			at = Vector3(0, 0, -3.4)
		"ice_chest":
			at = Vector3(0, 0, -3.0)
		"buried_lantern":
			at = Vector3(0, 0, -2.6)
		"hot_spring":
			at = Vector3(0, 0, -1.9)
	return global_transform * at + Vector3(0, 1.0, 0)


func _new(p: Node, move: String, counter: String) -> bool:
	# Has that move just been done? (its counter went up since last frame)
	var m = p.get(move)
	if m == null:
		return false
	var now := int(m.get(counter))
	var was := int(_counts.get(move, now))
	return now > was


func _remember(p: Node) -> void:
	if p == null:
		return
	for pair in [["make", "made_count"], ["groove", "grooves"], ["showers", "showers"], ["frost_breath", "huffs"]]:
		var m = p.get(pair[0])
		if m != null:
			_counts[pair[0]] = int(m.get(pair[1]))


func _facing(p: Node3D) -> bool:
	# Frost breath goes the way she faces: the spring has to be in front of her
	var fb = p.get("frost_breath")
	if fb == null or not fb.has_method("forward"):
		return true
	var to := target() - p.global_position
	to.y = 0
	return to.length() < 1.5 or (fb.forward() as Vector3).dot(to.normalized()) > 0.3


func open_up() -> bool:
	# The friend's move worked: the spot opens (for good). Returns whether it was new (tests call it).
	if opened:
		return false
	opened = true
	Dialogue.flags[flag_open(str(info.id))] = true
	var f := Party.friend(str(info.friend))
	Game.message("%s did it!" % str(f.get("name", "Your friend")))
	Audio.play_at("pickup", global_position)
	Juice.blip("sparkle", 1.2, -4.0)
	Fx.burst(self, global_position + Vector3(0, 1.2, 0), friend_colour(), 26, 0.1, 3.5, -2.5, 1.2)
	if Juice.has_method("rumble"):
		Juice.rumble(0.3, 0.25)
	_show_open(false)
	Game.save_game()
	return true


func open_chest() -> bool:
	# The chest the spot opened: the reward the first time. Returns whether it gave anything (tests call it).
	var id := str(info.id)
	if not opened or is_found(id):
		return false
	Dialogue.flags[flag_found(id)] = true
	var lid := chest.get_node_or_null("Lid") as Node3D
	if lid:
		var tw := chest.create_tween()
		tw.tween_property(lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_at("pickup", chest.global_position)
	Fx.burst(chest, chest.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.85, 0.4), 20, 0.08, 2.5, -2.0, 1.0)
	Game.add_sparkles(SPARKLES, "a friend spot")
	Remnants.add(REMNANTS, "a friend spot")
	var gifts := ["+%d sparkles" % SPARKLES, "+%d Remnants" % REMNANTS]
	var all := found_count() == SPOTS.size()
	if all:
		Game.add_sparkles(SET_SPARKLES, "every friend spot")
		if not Game.has_item("shop:" + SET_HAT):
			Game.items.append("shop:" + SET_HAT)
			gifts.append("the " + str(Shop.items.get(SET_HAT, {}).get("name", "Friendship Circlet")))
	var line := "%s!\n%s" % [str(info.name), ", ".join(gifts)]
	line += "\nAll five friend spots!" if all else "\n%d of %d friend spots" % [found_count(), SPOTS.size()]
	Game.message(line)
	Game.save_game()
	return true


func _show_open(at_once: bool) -> void:
	# Change the spot to how it looks once it's open (straight away when it was open already)
	if is_instance_valid(_blocker):
		if at_once:
			_blocker.queue_free()
		else:
			var b := _blocker as Node3D
			b.process_mode = Node.PROCESS_MODE_DISABLED
			for c in b.find_children("*", "CollisionShape3D", true, false):
				(c as CollisionShape3D).set_deferred("disabled", true)
			var tw := create_tween()
			tw.tween_property(b, "scale", Vector3(0.01, 0.01, 0.01), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tw.tween_callback(b.queue_free)
	match str(info.id):
		"lonely_shard":
			_bridge(at_once)
		"sleepy_bud":
			_bloom(at_once)
		"buried_lantern":
			_rise(at_once)
		"hot_spring":
			_freeze(at_once)
	if chest:
		chest.visible = true
		var spot := chest.get_node_or_null("Spot")
		if spot:
			spot.process_mode = Node.PROCESS_MODE_INHERIT


# -----------------------------------------------------------------------------
# The chest every spot gives
# -----------------------------------------------------------------------------
func _make_chest(parent: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Friend Chest"
	parent.add_child(c)
	c.position = pos
	c.rotation.y = yaw
	var wood := _mat(friend_colour().darkened(0.35))
	var gold := _mat(Color(1.0, 0.82, 0.3), 0.3, 0.8)
	_box(c, Vector3(0.9, 0.5, 0.6), wood, Vector3(0, 0.25, 0))
	_box(c, Vector3(0.94, 0.08, 0.64), gold, Vector3(0, 0.4, 0))
	var hinge := Node3D.new()
	hinge.name = "Lid"
	hinge.position = Vector3(0, 0.5, -0.3)
	c.add_child(hinge)
	var lid := MeshInstance3D.new()
	lid.mesh = _cyl(0.3, 0.3, 0.9, 12)
	lid.material_override = wood
	lid.rotation.z = PI / 2.0
	lid.position = Vector3(0, 0.0, 0.3)
	lid.scale = Vector3(0.6, 1.0, 1.0)
	hinge.add_child(lid)
	_box(c, Vector3(0.14, 0.16, 0.06), gold, Vector3(0, 0.42, 0.31))
	if is_found(str(info.id)):
		hinge.rotation.x = -1.9
	var spot := USE_SPOT.make(Vector3(0, 0.4, 0.6), func() -> String:
			return "open the chest" if opened and not is_found(str(info.id)) else "",
		func() -> void: open_chest(), 1.6, 1.4)
	spot.name = "Spot"
	c.add_child(spot)
	return c


# -----------------------------------------------------------------------------
# The Lonely Shard (Shard Isle, Nina and Bruno's Make)
# -----------------------------------------------------------------------------
var _planks: Array[Node3D] = []

func _build_shard() -> void:
	# A little crystal islet floating up off the rim, too high and far to jump or glide to, and the faint outline of a
	# bridge up to it (where the planks will go)
	var perch := Node3D.new()
	perch.name = "Perch"
	add_child(perch)
	perch.position = Vector3(0, PERCH_UP, PERCH_OUT)
	var top := MeshInstance3D.new()
	top.mesh = _cyl(3.0, 2.9, 0.6, 28)
	top.material_override = _mat(Color(0.36, 0.72, 0.6))
	top.position.y = -0.3
	perch.add_child(top)
	var rock := MeshInstance3D.new()
	rock.mesh = _cyl(2.85, 0.4, 3.6, 12)
	rock.material_override = _mat(Color(0.52, 0.46, 0.68))
	rock.position.y = -2.4
	perch.add_child(rock)
	var body := StaticBody3D.new()
	body.name = "Perch Floor"
	perch.add_child(body)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 3.0
	cy.height = 0.6
	cs.shape = cy
	cs.position.y = -0.3
	body.add_child(cs)
	var glow := _mat(Color(1.0, 0.7, 0.9), 1.6)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var cr := MeshInstance3D.new()
		cr.mesh = _cyl(0.0, 0.22, 1.0 + (i % 3) * 0.5, 6)
		cr.material_override = glow
		cr.position = Vector3(cos(a) * 2.3, 0.4 + (i % 3) * 0.25, sin(a) * 2.3)
		cr.rotation = Vector3(cos(a) * 0.3, 0, -sin(a) * 0.3)
		perch.add_child(cr)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.9)
	light.light_energy = 1.2
	light.omni_range = 6.0
	light.position.y = 1.5
	perch.add_child(light)
	chest = _make_chest(perch, Vector3(0, 0, 0.6), PI)
	# The ghost of the bridge: thin see-through planks
	for i in _plank_count() + 1:
		var g := MeshInstance3D.new()
		g.name = "Ghost %d" % i
		g.mesh = _boxmesh(Vector3(2.2, 0.08, _plank_size(i)))
		var m := _mat(Color(1.0, 0.85, 1.0, 0.18), 0.6)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.material_override = m
		g.transform = _plank_xf(i)
		g.add_to_group("plank_ghost")
		add_child(g)


func _plank_count() -> int:
	return 8


func _plank_len() -> float:
	var run := LANDING_Z - LANDING_LONG / 2.0 + 0.1 - 0.8
	return Vector2(run, PERCH_UP + 0.06).length() / _plank_count() + 0.12


func _plank_size(i: int) -> float:
	return LANDING_LONG if i >= _plank_count() else _plank_len()


func _plank_xf(i: int) -> Transform3D:
	# From just in front of the stone (z 0.8) up to the perch's rim (z PERCH_OUT - 3, height PERCH_UP)
	# (the line is the planks' middles: their tops start just under the ground and end a hair over the landing, so there's
	# no ledge to get stuck on at either end)
	if i >= _plank_count():
		return Transform3D(Basis(), Vector3(0, PERCH_UP - 0.125, LANDING_Z))     # the flat landing onto the perch
	var start := Vector3(0, -0.2, 0.8)
	var finish := Vector3(0, PERCH_UP - 0.09, LANDING_Z - LANDING_LONG / 2.0 + 0.1)
	var k := (i + 0.5) / _plank_count()
	var at := start.lerp(finish, k)
	var slope := atan2(finish.y - start.y, finish.z - start.z)
	return Transform3D(Basis(Vector3.RIGHT, -slope), at)


func _bridge(at_once: bool) -> void:
	for g in get_tree().get_nodes_in_group("plank_ghost") if is_inside_tree() else []:
		if is_ancestor_of(g):
			(g as Node3D).visible = false
	var cols := [Color(1.0, 0.3, 0.62), Color(0.25, 0.5, 1.0)]       # Nina's pink, Bruno's blue (scripts/make.gd)
	for i in _plank_count() + 1:
		var plank := StaticBody3D.new()
		plank.name = "Plank %d" % i
		plank.add_to_group("made_thing")
		add_child(plank)
		plank.transform = _plank_xf(i)
		var mi := MeshInstance3D.new()
		mi.mesh = _boxmesh(Vector3(2.2, 0.25, _plank_size(i)))
		mi.material_override = _mat(cols[i % 2], 0.35)
		plank.add_child(mi)
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(2.2, 0.25, _plank_size(i))
		cs.shape = b
		plank.add_child(cs)
		# Low rails each side, so nobody slips off on the way up
		for side in [-1.0, 1.0]:
			var rail := CollisionShape3D.new()
			var rb := BoxShape3D.new()
			rb.size = Vector3(0.12, 0.7, _plank_size(i))
			rail.shape = rb
			rail.position = Vector3(side * 1.08, 0.45, 0)
			plank.add_child(rail)
			var rm := MeshInstance3D.new()
			rm.mesh = _boxmesh(Vector3(0.1, 0.1, _plank_size(i)))
			rm.material_override = _mat(Color(1.0, 0.95, 1.0), 0.4)
			rm.position = Vector3(side * 1.08, 0.7, 0)
			plank.add_child(rm)
		_planks.append(plank)
		if not at_once:
			plank.scale = Vector3(0.01, 0.01, 0.01)
			var tw := create_tween()
			tw.tween_interval(0.12 * i)
			tw.tween_property(plank, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_callback(func() -> void:
				Juice.blip("pop", 0.9 + i * 0.06, -10.0)
				Fx.burst(self, plank.global_position, cols[i % 2], 6, 0.07, 1.6, -2.0, 0.6))


# -----------------------------------------------------------------------------
# The Sleepy Bud (the Rootmind, Melody's Groove)
# -----------------------------------------------------------------------------
var _petals: Array[Node3D] = []
var _bud: Node3D
var _zzz: Label3D

func _build_bud() -> void:
	# A giant flower bud sitting right on the ground (no ledge to climb: you can't step up one), on a round leafy pad,
	# big leaves round its foot
	_bud = Node3D.new()
	_bud.name = "Bud"
	add_child(_bud)
	_bud.position = Vector3(0, 0, -3.4)
	var pad := MeshInstance3D.new()
	pad.mesh = _cyl(1.7, 1.8, 0.06, 24)
	pad.material_override = _mat(Color(0.35, 0.68, 0.35))
	pad.position.y = 0.03
	_bud.add_child(pad)
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var leaf := MeshInstance3D.new()
		leaf.mesh = _sphere(1.0)
		leaf.material_override = _mat(Color(0.38, 0.75, 0.38))
		leaf.position = Vector3(cos(a) * 2.3, 0.05, sin(a) * 2.3)
		leaf.scale = Vector3(1.3, 0.1, 0.7)
		leaf.rotation.y = -a
		_bud.add_child(leaf)
	# Eight petals closed up round the middle (pivots at the pad's rim)
	var petal_mat := _mat(Color(0.95, 0.55, 0.85), 0.15)
	var tip_mat := _mat(Color(1.0, 0.85, 0.95), 0.4)
	for i in 8:
		var a := TAU * i / 8.0
		var pivot := Node3D.new()
		pivot.name = "Petal %d" % i
		pivot.position = Vector3(sin(a) * 1.1, 0.1, cos(a) * 1.1)
		pivot.rotation.y = a
		_bud.add_child(pivot)
		var petal := MeshInstance3D.new()
		petal.mesh = _sphere(1.0)
		petal.material_override = petal_mat
		petal.scale = Vector3(0.75, 1.7, 0.22)
		petal.position = Vector3(0, 1.5, 0)
		pivot.add_child(petal)
		var tip := MeshInstance3D.new()
		tip.mesh = _sphere(0.18)
		tip.material_override = tip_mat
		tip.position = Vector3(0, 3.0, 0)
		pivot.add_child(tip)
		pivot.rotation.x = -0.42                  # leaning in: closed
		_petals.append(pivot)
	# Shut tight, you can't get in: a solid core that goes when it blooms
	var core := StaticBody3D.new()
	core.name = "Closed Bud"
	_bud.add_child(core)
	var ccs := CollisionShape3D.new()
	var ccy := CylinderShape3D.new()
	ccy.radius = 1.55
	ccy.height = 3.6
	ccs.shape = ccy
	ccs.position.y = 1.8
	core.add_child(ccs)
	_blocker = core
	_zzz = Label3D.new()
	_zzz.text = "z z z"
	_zzz.font_size = 80
	_zzz.pixel_size = 0.012
	_zzz.outline_size = 12
	_zzz.modulate = Color(0.85, 0.8, 1.0)
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.position = Vector3(0.8, 4.0, 0)
	_bud.add_child(_zzz)
	chest = _make_chest(_bud, Vector3(0, 0.06, 0.2), 0.0)
	chest.visible = false


func _wake_a_bit() -> void:
	# Each groove wakes it a little: it wiggles, its petals part a bit, and the snoring stops for a moment
	Juice.blip("pop", 1.0 + progress * 0.15, -8.0)
	Fx.burst(self, _bud.global_position + Vector3(0, 2.6, 0), Color(1.0, 0.7, 0.95), 10, 0.08, 2.0, -1.5, 0.8)
	var tw := create_tween()
	tw.tween_property(_bud, "rotation:z", 0.08, 0.1)
	tw.tween_property(_bud, "rotation:z", -0.08, 0.15)
	tw.tween_property(_bud, "rotation:z", 0.0, 0.1)
	for p in _petals:
		create_tween().tween_property(p, "rotation:x", -0.42 + 0.12 * progress, 0.3)


func _bloom(at_once: bool) -> void:
	if _zzz:
		_zzz.visible = false
	for p in _petals:
		if at_once:
			p.rotation.x = 1.15
		else:
			create_tween().tween_property(p, "rotation:x", 1.15, 1.0).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# The Frozen Chest (the Frozen Moment, Heather's April Showers)
# -----------------------------------------------------------------------------
func _build_ice() -> void:
	var mound := MeshInstance3D.new()
	mound.mesh = _sphere(1.0)
	mound.material_override = _mat(Color(0.94, 0.97, 1.0))
	mound.scale = Vector3(2.4, 0.35, 2.4)
	mound.position = Vector3(0, 0.0, -3.0)
	add_child(mound)
	chest = _make_chest(self, Vector3(0, 0.05, -3.0), 0.0)
	var ice := StaticBody3D.new()
	ice.name = "Ice Block"
	add_child(ice)
	ice.position = Vector3(0, 0.0, -3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _boxmesh(Vector3(1.8, 1.5, 1.5))
	var m := _mat(Color(0.7, 0.88, 1.0, 0.55), 0.25)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	mi.material_override = m
	mi.position.y = 0.75
	ice.add_child(mi)
	for i in 6:
		var shard := MeshInstance3D.new()
		shard.mesh = _cyl(0.0, 0.18, 0.7 + (i % 3) * 0.2, 5)
		shard.material_override = m
		shard.position = Vector3(-0.8 + (i % 3) * 0.8, 1.5 + (i % 2) * 0.1, -0.5 + (i / 3) * 1.0)
		shard.rotation = Vector3(0.2 * (i % 2 * 2 - 1), 0, 0.15 * (i % 3 - 1))
		ice.add_child(shard)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.8, 1.8, 1.5)
	cs.shape = b
	cs.position.y = 0.9
	ice.add_child(cs)
	_blocker = ice


# -----------------------------------------------------------------------------
# The Buried Lantern (Lanternmoor, Bramble's Burrow)
# -----------------------------------------------------------------------------
var _lantern_rise: Node3D

func _build_lantern() -> void:
	# Soft dark soil to burrow into (group "soil": scripts/burrow.gd soil()), a little heap with a sprig and a faint
	# glow coming up through it, and a ring of glowcaps round it
	var soil := StaticBody3D.new()
	soil.name = "Soft Soil"
	soil.add_to_group("soil")
	add_child(soil)
	soil.position = Vector3(0, 0, -2.6)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 2.4
	cy.height = 0.3
	cs.shape = cy
	cs.position.y = -0.13
	soil.add_child(cs)
	var smi := MeshInstance3D.new()
	smi.mesh = _cyl(2.4, 2.5, 0.06, 24)
	smi.material_override = _mat(Color(0.25, 0.18, 0.14))
	smi.position.y = 0.03
	soil.add_child(smi)
	var heap := MeshInstance3D.new()
	heap.name = "Heap"
	heap.mesh = _sphere(1.0)
	heap.material_override = _mat(Color(0.3, 0.21, 0.15))
	heap.scale = Vector3(0.9, 0.3, 0.9)
	heap.position.y = 0.0
	soil.add_child(heap)
	var sprig := MeshInstance3D.new()
	sprig.mesh = _cyl(0.02, 0.03, 0.4, 5)
	sprig.material_override = _mat(Color(0.4, 0.75, 0.35))
	sprig.position = Vector3(0, 0.45, 0)
	soil.add_child(sprig)
	var light := OmniLight3D.new()
	light.name = "Glow Under"
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 0.3
	soil.add_child(light)
	var cap := _mat(Color(0.55, 0.85, 1.0), 1.5)
	var stalk := _mat(Color(0.85, 0.85, 0.8))
	for i in 10:
		var a := TAU * i / 10.0
		var r := 3.0 + (i % 2) * 0.3
		var m := Node3D.new()
		m.position = Vector3(cos(a) * r, 0, -2.6 + sin(a) * r)
		add_child(m)
		var st := MeshInstance3D.new()
		st.mesh = _cyl(0.06, 0.08, 0.35, 6)
		st.material_override = stalk
		st.position.y = 0.17
		m.add_child(st)
		var c := MeshInstance3D.new()
		c.mesh = _sphere(0.2)
		c.material_override = cap
		c.scale = Vector3(1, 0.5, 1)
		c.position.y = 0.36
		m.add_child(c)
	_lantern_rise = Node3D.new()
	_lantern_rise.name = "Lantern Chest"
	add_child(_lantern_rise)
	_lantern_rise.position = Vector3(0, -1.4, -2.6)
	chest = _make_chest(_lantern_rise, Vector3.ZERO, 0.0)
	var lamp := MeshInstance3D.new()
	lamp.mesh = _sphere(0.18)
	lamp.material_override = _mat(Color(1.0, 0.85, 0.45), 3.0)
	lamp.position = Vector3(0, 0.95, 0)
	_lantern_rise.add_child(lamp)
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.8, 0.45)
	ll.light_energy = 1.5
	ll.omni_range = 5.0
	ll.position.y = 1.0
	_lantern_rise.add_child(ll)
	chest.visible = false


func _rise(at_once: bool) -> void:
	var heap := get_node_or_null("Soft Soil/Heap") as Node3D
	if heap:
		heap.scale = Vector3(1.2, 0.08, 1.2)
	if at_once:
		_lantern_rise.position.y = 0.0
		return
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_lantern_rise, "position:y", 0.0, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.burst(self, global_position + global_basis * Vector3(0, 0.4, -2.6), Color(0.35, 0.25, 0.18), 24, 0.12, 3.0, -6.0, 1.0)


# -----------------------------------------------------------------------------
# The Hot Spring (Glenmoor, Flurry's Frost breath), and the Seam behind it
# -----------------------------------------------------------------------------
var _geyser: Node3D
var _jet: MeshInstance3D

func _build_spring() -> void:
	# A rocky nook (three walls of stone) facing the stone, with a hot spring roaring up in its mouth: too hot to pass
	var rock := _mat(Color(0.5, 0.48, 0.45))
	var walls := StaticBody3D.new()
	walls.name = "Nook"
	add_child(walls)
	for w in [[Vector3(-3.2, 1.6, -4.6), Vector3(1.2, 3.2, 6.0)], [Vector3(3.2, 1.6, -4.6), Vector3(1.2, 3.2, 6.0)],
			[Vector3(0, 1.6, -7.3), Vector3(7.6, 3.2, 1.2)], [Vector3(0, 3.4, -5.0), Vector3(7.6, 0.5, 5.6)]]:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = w[1]
		cs.shape = b
		cs.position = w[0]
		walls.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = _boxmesh(w[1])
		mi.material_override = rock
		mi.position = w[0]
		walls.add_child(mi)
	# Lumpy boulders over the walls so it reads as rock, not a box
	for i in 9:
		var bmi := MeshInstance3D.new()
		bmi.mesh = _sphere(1.0)
		bmi.material_override = rock
		var x := -3.6 + (i % 5) * 1.8
		bmi.position = Vector3(x, 3.6 + (i % 2) * 0.3, -6.2 + (i / 5) * 2.4)
		bmi.scale = Vector3(1.3, 0.7 + (i % 3) * 0.2, 1.2)
		walls.add_child(bmi)
	# ...and down its sides, so the walls look like a heap of rocks
	for side in [-1.0, 1.0]:
		for k in 3:
			var sb := MeshInstance3D.new()
			sb.mesh = _sphere(1.0)
			sb.material_override = rock
			sb.position = Vector3(side * 3.6, 0.9 + (k % 2) * 1.2, -2.4 - k * 2.0)
			sb.scale = Vector3(0.9, 1.1 + (k % 2) * 0.3, 1.2)
			walls.add_child(sb)
	# The spring's pool and the geyser in the nook's mouth
	var pool := MeshInstance3D.new()
	pool.mesh = _cyl(1.5, 1.6, 0.08, 24)
	pool.material_override = _mat(Color(0.45, 0.8, 0.85), 0.25)
	pool.position = Vector3(0, 0.04, -1.9)
	add_child(pool)
	_geyser = StaticBody3D.new()
	_geyser.name = "Geyser"
	add_child(_geyser)
	_geyser.position = Vector3(0, 0, -1.9)
	var gcs := CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(5.2, 3.0, 1.2)             # (the whole mouth: you can't slip past its spray)
	gcs.shape = gb
	gcs.position.y = 1.5
	_geyser.add_child(gcs)
	_jet = MeshInstance3D.new()
	_jet.name = "Jet"
	_jet.mesh = _cyl(0.5, 0.8, 4.5, 14)
	var jm := _mat(Color(0.85, 0.95, 1.0, 0.55), 0.4)
	jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_jet.material_override = jm
	_jet.position.y = 2.25
	_geyser.add_child(_jet)
	for side in [-1.0, 1.0]:
		var spray := MeshInstance3D.new()
		spray.mesh = _sphere(1.0)
		spray.material_override = jm
		spray.position = Vector3(side * 0.9, 1.0, 0)
		spray.scale = Vector3(0.55, 1.0, 0.3)
		_geyser.add_child(spray)
	var steam := CPUParticles3D.new()
	steam.name = "Steam"
	steam.amount = 26
	steam.lifetime = 2.4
	steam.direction = Vector3.UP
	steam.spread = 18.0
	steam.initial_velocity_min = 1.5
	steam.initial_velocity_max = 2.6
	steam.gravity = Vector3(0, 0.4, 0)
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.6
	var sm := _sphere(0.4)
	var smat := _mat(Color(1, 1, 1, 0.35))
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	steam.mesh = sm
	steam.position.y = 4.0
	_geyser.add_child(steam)
	_blocker = null                                # the geyser freezes rather than going away
	chest = _make_chest(self, Vector3(-1.6, 0.0, -5.9), 0.0)
	chest.visible = false


func _freeze(at_once: bool) -> void:
	# Frozen solid: the jet turns to an ice pillar (short, so you walk round it), the steam stops, and the mouth opens
	if not is_instance_valid(_geyser):
		return
	var steam := _geyser.get_node_or_null("Steam") as CPUParticles3D
	if steam:
		steam.emitting = false
	var cs := _geyser.get_child(0) as CollisionShape3D
	var ice := _mat(Color(0.7, 0.9, 1.0, 0.85), 0.5)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for c in _geyser.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = ice
	var narrow := BoxShape3D.new()
	narrow.size = Vector3(1.4, 3.0, 1.2)
	cs.set_deferred("shape", narrow)
	var pool := MeshInstance3D.new()
	pool.mesh = _cyl(1.55, 1.6, 0.1, 24)
	pool.material_override = ice
	pool.position.y = 0.06
	_geyser.add_child(pool)
	if at_once:
		_jet.scale = Vector3(1, 0.7, 1)
		_jet.position.y = 1.6
		return
	var tw := create_tween()
	tw.tween_property(_jet, "scale", Vector3(1, 0.7, 1), 0.6)
	tw.parallel().tween_property(_jet, "position:y", 1.6, 0.6)
	Fx.burst(self, _geyser.global_position + Vector3(0, 2.0, 0), Color(0.75, 0.92, 1.0), 30, 0.1, 3.0, -2.0, 1.2)


func _animate(_delta: float) -> void:
	if _jet and not opened:
		_jet.scale = Vector3(1.0 + sin(_t * 9.0) * 0.06, 1.0 + sin(_t * 5.0) * 0.08, 1.0 + cos(_t * 9.0) * 0.06)
	if _bud and not opened:
		_bud.scale = Vector3.ONE * (1.0 + sin(_t * 1.4) * 0.02)          # breathing in its sleep
	if _zzz and not opened:
		_zzz.position.y = 4.0 + fmod(_t * 0.4, 1.0) * 0.6
		_zzz.modulate.a = 1.0 - fmod(_t * 0.4, 1.0)


# -----------------------------------------------------------------------------
# The Seam: a hidden crack between Glenmoor and Lanternmoor
# -----------------------------------------------------------------------------
static func seam_open() -> bool:
	return Portals.is_cleared("glenmoor") and Portals.is_cleared("lanternmoor")


static func _place_seam(world: Node3D, world_id: String) -> void:
	if not SEAM.has(world_id) or not seam_open():
		return
	var s: Dictionary = SEAM[world_id]
	# Lanternmoor's end only shows once you've come through from Glenmoor (it's found from the hot spring's side)
	if world_id == "lanternmoor" and not Dialogue.flags.get("seam_found", false):
		return
	var host := world.get_node_or_null(str(spot_info(str(s.spot)).name)) as Node3D
	if host == null:
		return
	var g: Node3D = Portals.portal_model(SEAM_COLOUR, func() -> void: go_through(world_id))
	g.name = "The Seam"
	g.scale = Vector3.ONE * 0.6                    # (a little one: it fits in the nook, along its right-hand wall)
	g.add_to_group("seam")
	world.add_child(g)
	var at := host.global_transform * (s.local as Vector3)
	g.global_position = _ground(world, at)
	g.rotation.y = host.rotation.y + float(s.get("turn", 0.0))
	Portals.CRACK.sink(g, world)
	Portals.CRACK.add_prompt(g, func() -> String: return "to " + str(Portals.world(str(s.to)).get("name", "somewhere")), "Spot")


static func seam_landing(world_id: String) -> Dictionary:
	# Where you come out in world_id (beside its end of the Seam): {pos, yaw}, worked out from the spot's place
	var s: Dictionary = SEAM[world_id]
	var sp := spot_info(str(s.spot))
	var basis := Basis(Vector3.UP, float(sp.yaw))
	var crack_at: Vector3 = sp.at + basis * (s.local as Vector3)
	var out: Vector3 = basis * Vector3(-1.4, 0, 1.2) if world_id == "glenmoor" else basis * Vector3(0, 0, 2.6)   # beside it
	return {"pos": crack_at + out + Vector3(0, 1.0, 0), "yaw": float(sp.yaw)}


static func go_through(from_id: String) -> void:
	var to := str(SEAM[from_id].to)
	var w := Portals.world(to)
	if w.is_empty():
		return
	var first: bool = not Dialogue.flags.get("seam_found", false)
	Dialogue.flags["seam_found"] = true
	if first:
		Game.add_sparkles(SEAM_SPARKLES, "the Seam")
		Game.pending_message = "A crack between two worlds! +%d sparkles" % SEAM_SPARKLES
	else:
		Game.pending_message = "Through the Seam to %s." % str(w.name)
	var land := seam_landing(to)
	Game.save_game()
	Game.go_to_point(str(w.scene), land.pos, float(land.yaw), str(w.name))


# -----------------------------------------------------------------------------
# Shapes
# -----------------------------------------------------------------------------
static func _mat(c: Color, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	return m


static func _cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _boxmesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _box(parent: Node3D, size: Vector3, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _boxmesh(size)
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi
