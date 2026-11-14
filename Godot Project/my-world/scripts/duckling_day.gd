extends Node

# Spring fun in Stars Hollow, and the quest "Duckling Day" (quests/duckling_day.json): a node "DucklingDay" under the
# EarthTown autoload (scripts/earth_town.gd), so dialogue can reach it as "EarthTown/DucklingDay.<method>" with no new
# autoload. Spring waits in Glenmoor, Heather's portal world, until it's mended (scripts/portals.gd "season"), and then
# Stars Hollow gets its first proper spring. A spring shower in the night scattered Mother Duck's five ducklings round
# town: find each one (walk up to it and it falls in behind you, waddling in a line), lead them all back to her on
# Willow Pond's bank, splash in three puddles on the green with Nina, then share honey buns at Crumb & Cauldron.
#
# All spring there are puddles on the green to jump in (land in one for a splash, any time), and once the ducklings are
# home the whole family paddles round Willow Pond in a line. Everything's put in the Earth scene at play time, and only
# in spring.

const QUEST := "duckling_day"
const DUCKLINGS := 5
# Where each lost duckling waits (x, z): by the gazebo, in the playground's sandbox, outside the bakery, by the creek
# at the footbridge, and in the Tulip Field. All outdoors on dry, open ground (tools/test_spring.gd checks).
const LOST_AT := [Vector2(4.5, 9.5), Vector2(-51.0, 25.5), Vector2(-1.5, -44.5), Vector2(-89.0, -34.0), Vector2(-116.0, 33.0)]
const LOST_NAMES := ["by the gazebo", "in the playground", "outside the bakery", "by the footbridge", "in the Tulip Field"]
const MOTHER_AT := Vector2(-67.5, 9.0)         # Mother Duck, waiting on Willow Pond's east bank
const HOME_NEAR := 4.0                         # how close to her you lead them
const FIND_NEAR := 1.3                         # how close you walk to a duckling to pick it up
const SPACING := 0.6                           # metres between ducklings in the line behind you
const SWIM := Vector4(-85.0, 0.0, 9.0, 6.0)    # the family's paddle round Willow Pond: centre x, z, radius x, z
const SWIM_SPEED := 0.015                      # times round the loop a second (about a minute a lap)
# Puddles on the green from the spring shower (x, _, z): clear of the gazebo, the old oak, the bench and the notice board
const PUDDLES := [Vector3(12.0, 0, 13.0), Vector3(11.0, 0, -9.0), Vector3(-9.5, 0, -12.0)]
const PUDDLE_R := 1.1

var _trail: Array[Vector3] = []                # where the hero's feet have been, newest first (for the line)
var _was_floor := true
var _swim_t := 0.0
var splashes := 0                              # (for the tests: puddle splashes made)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Dialogue.flag_set.connect(func(_f: String) -> void: _refresh.call_deferred())


func _earth() -> Node3D:
	var scene := get_tree().current_scene
	return scene as Node3D if scene and scene.scene_file_path == EarthTown.EARTH else null


func _group() -> Node3D:
	var scene := _earth()
	return scene.get_node_or_null("Duckling Day") as Node3D if scene else null


func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _on_scene_changed() -> void:
	_trail.clear()
	var scene := _earth()
	if scene == null or Clock.season() != "spring" or scene.get_node_or_null("Duckling Day") != null:
		return
	var g := Node3D.new()
	g.name = "Duckling Day"
	scene.add_child(g)
	for i in PUDDLES.size():
		var p: Vector3 = PUDDLES[i]
		var puddle := puddle_model(PUDDLE_R)
		puddle.name = "Puddle %d" % (i + 1)
		g.add_child(puddle)
		puddle.global_position = ground(Vector2(p.x, p.z)) + Vector3(0, 0.03, 0)
	var mother := duck_model(1.0)
	mother.name = "Mother Duck"
	g.add_child(mother)
	mother.global_position = ground(MOTHER_AT)
	for i in DUCKLINGS:
		var d := duck_model(0.5)
		d.name = "Duckling %d" % (i + 1)
		g.add_child(d)
		d.global_position = lost_spot(i)
	_refresh()


static func ground(at: Vector2) -> Vector3:
	return Vector3(at.x, EarthLand.height(at.x, at.y), at.y)


static func lost_spot(i: int) -> Vector3:
	return ground(LOST_AT[i])


# --- Who's where ---------------------------------------------------------------------------------------------------
func found(i: int) -> bool:
	return Dialogue.flags.has("duckling_%d" % (i + 1))


func home() -> bool:
	return Dialogue.flags.has("ducks_home")


func following() -> Array[int]:
	# The ducklings waddling behind you: found, and not home yet
	var out: Array[int] = []
	if home() or not (Quests.on_step(QUEST, "find") or Quests.on_step(QUEST, "home")):
		return out
	for i in DUCKLINGS:
		if found(i):
			out.append(i)
	return out


func _refresh() -> void:
	var g := _group()
	if g == null:
		return
	var player := _player()
	var started := Quests.on_step(QUEST, "find") or Quests.on_step(QUEST, "home")
	for i in DUCKLINGS:
		var d := g.get_node("Duckling %d" % (i + 1)) as Node3D
		# A lost duckling only shows while the quest's looking for it; once home it's with its mother
		d.visible = home() or (started and (not found(i) or player != null))
		if found(i) and not home() and player and _trail.is_empty():
			_trail.append(player.global_position - Vector3(0, 0.8, 0))   # (back after a trip: they're right behind you)
		if not found(i) and not home():
			d.global_position = lost_spot(i)


func _process(delta: float) -> void:
	var g := _group()
	if g == null:
		return
	var player := _player()
	_watch(player)
	var t := Time.get_ticks_msec() / 1000.0
	if home():
		_swim(g, delta)
	else:
		_line(g, player)
		# Lost ones peep and look about, bobbing on the spot
		for i in DUCKLINGS:
			if not found(i):
				var d := g.get_node("Duckling %d" % (i + 1)) as Node3D
				d.rotation.y = sin(t * 1.3 + i) * 1.2
				d.position.y = lost_spot(i).y + absf(sin(t * 5.0 + i)) * 0.05
		var mother := g.get_node("Mother Duck") as Node3D
		mother.rotation.y = sin(t * 0.7) * 0.8 + PI / 2
	_puddles(g, player)


func _watch(player: CharacterBody3D) -> void:
	if player == null:
		return
	var feet := player.global_position - Vector3(0, 0.8, 0)
	if Quests.on_step(QUEST, "find"):
		for i in DUCKLINGS:
			if not found(i) and feet.distance_to(lost_spot(i)) < FIND_NEAR + 0.8:
				pick_up(i)
	elif Quests.on_step(QUEST, "home") and not home():
		if Vector2(feet.x, feet.z).distance_to(MOTHER_AT) < HOME_NEAR:
			bring_home()


func pick_up(i: int) -> void:
	# A lost duckling falls in at the back of the line behind you
	if found(i) or not Quests.on_step(QUEST, "find"):
		return
	var player := _player()
	if _trail.is_empty() and player:
		_trail.append(player.global_position - Vector3(0, 0.8, 0))
	Dialogue.set_flag("duckling_%d" % (i + 1))
	var n := 0
	for k in DUCKLINGS:
		if found(k):
			n += 1
	Game.message("Peep! The duckling %s waddles in behind you. (%d of %d)" % [LOST_NAMES[i], n, DUCKLINGS])
	Juice.blip("pop", 1.8, -4.0)
	var g := _group()
	if g:
		Fx.burst(g, lost_spot(i) + Vector3.UP * 0.3, Color(1.0, 0.9, 0.4), 10, 0.05, 1.5, -2.0, 0.5)


func bring_home() -> void:
	if home() or not Quests.on_step(QUEST, "home"):
		return
	Dialogue.set_flag("ducks_home")
	_swim_t = 0.0
	Game.message("QUACK! All five home!")
	Juice.blip("sparkle", 1.2, -4.0)
	var g := _group()
	if g:
		Fx.burst(g, ground(MOTHER_AT) + Vector3.UP * 0.6, Color(1.0, 0.95, 0.6), 18, 0.07, 2.2, -2.5, 0.9)


func _line(g: Node3D, player: CharacterBody3D) -> void:
	# The found ducklings follow the path your feet took, one behind the other, waddling
	var line := following()
	if line.is_empty() or player == null:
		return
	var feet := player.global_position - Vector3(0, 0.8, 0)
	if _trail.is_empty() or feet.distance_to(_trail[0]) > 0.15:
		_trail.push_front(feet)
		var keep := int((DUCKLINGS + 2) * SPACING / 0.15) + 4
		if _trail.size() > keep:
			_trail.resize(keep)
	var t := Time.get_ticks_msec() / 1000.0
	for k in line.size():
		var d := g.get_node("Duckling %d" % (line[k] + 1)) as Node3D
		var at := _along_trail((k + 1) * SPACING)
		var ahead := _along_trail(k * SPACING + 0.2)
		d.global_position = at + Vector3(0, absf(sin(t * 9.0 + k)) * 0.04, 0)
		if ahead.distance_to(at) > 0.01:
			d.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)
		d.rotation.z = sin(t * 9.0 + k) * 0.12                          # (a waddle)


func _along_trail(dist: float) -> Vector3:
	# The spot `dist` metres back along where you've walked
	if _trail.is_empty():
		return Vector3.ZERO
	var left := dist
	for j in range(1, _trail.size()):
		var step := _trail[j - 1].distance_to(_trail[j])
		if step >= left:
			return _trail[j - 1].lerp(_trail[j], left / maxf(step, 0.001))
		left -= step
	return _trail[_trail.size() - 1]


func _swim(g: Node3D, delta: float) -> void:
	# Home: Mother Duck leads the five of them round and round Willow Pond
	_swim_t += delta * SWIM_SPEED
	var y := EarthLand.WATER_Y + 0.05
	var t := Time.get_ticks_msec() / 1000.0
	for k in DUCKLINGS + 1:
		var a := _swim_t * TAU - k * (0.12 if k > 0 else 0.0) - (0.08 if k > 0 else 0.0)
		var d := g.get_node("Mother Duck" if k == 0 else "Duckling %d" % k) as Node3D
		d.visible = true
		d.global_position = Vector3(SWIM.x + cos(a) * SWIM.z, y + sin(t * 2.0 + k) * 0.02, SWIM.y + sin(a) * SWIM.w)
		var tangent := Vector3(-sin(a) * SWIM.z, 0, cos(a) * SWIM.w)
		d.rotation = Vector3(0, atan2(tangent.x, tangent.z), 0)


# --- Puddles -----------------------------------------------------------------------------------------------------------
func _puddles(g: Node3D, player: CharacterBody3D) -> void:
	# Land in a puddle from a jump and it splashes (and on Duckling Day, Nina counts them)
	if player == null:
		return
	var on := player.is_on_floor()
	if on and not _was_floor:
		var feet := player.global_position - Vector3(0, 0.8, 0)
		for i in PUDDLES.size():
			var p: Vector3 = PUDDLES[i]
			if Vector2(feet.x - p.x, feet.z - p.z).length() < PUDDLE_R + 0.2:
				splash(i)
				break
	_was_floor = on


func splash(i: int) -> void:
	splashes += 1
	var g := _group()
	if g:
		var p := (g.get_node("Puddle %d" % (i + 1)) as Node3D).global_position
		Fx.burst(g, p + Vector3.UP * 0.1, Color(0.7, 0.85, 1.0), 16, 0.07, 3.0, -6.0, 0.7)
		Fx.ripple(g, p + Vector3.UP * 0.02, Color(0.8, 0.9, 1.0, 0.7))
		Audio.play_at("splash", p, -4.0)
	if Quests.on_step(QUEST, "puddles") and not Dialogue.flags.has("puddle_%d" % (i + 1)):
		Dialogue.set_flag("puddle_%d" % (i + 1))
		var n := 0
		for k in PUDDLES.size():
			if Dialogue.flags.has("puddle_%d" % (k + 1)):
				n += 1
		Game.message(["SPLOSH! Nina: \"One!\"", "SPLASH! Nina: \"Two! I'm soaked to my socks!\"",
			"KER-SPLASH! Nina: \"Three! The biggest one! Honey buns at Poppy's, go!\""][clampi(n - 1, 0, 2)])


# --- Models ---------------------------------------------------------------------------------------------------------
static func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _ball(parent: Node3D, r: float, c: StandardMaterial3D, at: Vector3, sc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	mi.mesh = s
	mi.material_override = c
	mi.position = at
	mi.scale = sc
	parent.add_child(mi)
	return mi


static func duck_model(size := 1.0) -> Node3D:
	# A duck facing +z: a round body with a tail tip, a head, an orange beak and two black eyes. Full size it's Mother
	# Duck (brown with a white neck ring); at half size it's a fluffy yellow duckling.
	var g := Node3D.new()
	var duckling := size < 0.8
	var body := _mat(Color(1.0, 0.86, 0.3) if duckling else Color(0.55, 0.4, 0.25), 1.0)
	var head := _mat(Color(1.0, 0.88, 0.35) if duckling else Color(0.15, 0.45, 0.3), 0.6)
	var s := size * (1.6 if duckling else 1.0)                    # (ducklings have big heads for their size)
	_ball(g, 0.24 * size, body, Vector3(0, 0.2 * size, 0), Vector3(0.85, 0.75, 1.2))
	_ball(g, 0.08 * size, body, Vector3(0, 0.27 * size, -0.27 * size), Vector3(1.0, 0.7, 1.4))      # tail
	var hr := 0.12 * s * (0.75 if duckling else 1.0)              # the head's radius: the beak and eyes go by it
	var h := _ball(g, hr, head, Vector3(0, 0.42 * size, 0.2 * size))
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = hr * 0.4
	cone.height = hr * 1.0
	cone.radial_segments = 8
	beak.mesh = cone
	beak.material_override = _mat(Color(0.98, 0.55, 0.15), 0.6)
	beak.rotation.x = PI / 2
	beak.scale = Vector3(1.0, 1.0, 0.6)
	beak.position = Vector3(0, -0.1, 1.05) * hr
	h.add_child(beak)
	for side in [-1.0, 1.0]:
		_ball(h, hr * 0.18, _mat(Color(0.05, 0.05, 0.08), 0.3), Vector3(side * 0.55, 0.25, 0.75) * hr)
	if not duckling:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.07
		t.outer_radius = 0.095
		ring.mesh = t
		ring.material_override = _mat(Color(0.97, 0.97, 0.95))
		ring.position = Vector3(0, 0.33 * size, 0.17 * size)
		ring.rotation.x = 0.5
		g.add_child(ring)
	return g


static func puddle_model(r: float) -> Node3D:
	# A shiny puddle: a flat blue-grey disc with a lighter ring, and two little ones beside it
	var g := Node3D.new()
	var water := StandardMaterial3D.new()
	water.resource_name = "Puddle Water"
	water.albedo_color = Color(0.45, 0.6, 0.78, 0.85)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.metallic = 0.3
	water.roughness = 0.05
	for k in 3:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		var rr: float = r * [1.0, 0.35, 0.25][k]
		c.top_radius = rr
		c.bottom_radius = rr
		c.height = 0.02
		c.radial_segments = 24
		mi.mesh = c
		mi.material_override = water
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = [Vector3.ZERO, Vector3(r * 1.15, 0, r * 0.4), Vector3(-r * 0.6, 0, r * 1.1)][k]
		mi.scale = Vector3(1.0, 1.0, [0.75, 1.0, 0.8][k])
		g.add_child(mi)
	return g
