extends "res://scripts/portal_world.gd"

# Shard Isle, the first portal world (plan item 19a, world 0; scene built by tools/build_shard_isle.gd). It belongs to
# nobody: it's a broken bit of the brain land, knocked loose by the first time quake, and it hums out of tune (the
# little floating shards over it stutter, as if time keeps skipping). It teaches how portal worlds work: the timer,
# the Time Stone, the way home, and a Remnant vein inside a world. The goal: find the three **Echo Crystals**, one
# on each islet, and set them in the **Heart Stone** in the middle. Then the island hums in tune again, the shards
# float calmly, and Portals.clear() gives the reward (Remnants, and the Portal Plaza back in the Void).

const ECHOES := ["Echo1", "Echo2", "Echo3"]
const ECHO_COLOURS := [Color(0.55, 1.0, 0.75), Color(0.7, 0.8, 1.0), Color(1.0, 0.75, 0.95)]

var _t := 0.0


func picture() -> void:
	# In the portal's preview: show the Echo Crystals waiting on their islets
	for i in ECHOES.size():
		var m := get_node_or_null(ECHOES[i]) as Node3D
		if m:
			m.add_child(echo_model(ECHO_COLOURS[i]))


func setup() -> void:
	var heart := get_node_or_null("HeartStone") as Node3D
	if heart:
		var g := heart_model()
		g.name = "Heart"
		heart.add_child(g)
		var spot := USE_SPOT.make(Vector3.ZERO, _heart_offer, _use_heart, 2.6, 3.2)
		spot.name = "Spot"
		g.add_child(spot)
	for i in ECHOES.size():
		var m := get_node_or_null(ECHOES[i]) as Node3D
		if m == null:
			continue
		var e := echo_model(ECHO_COLOURS[i])
		e.name = "Echo"
		m.add_child(e)
		var spot := USE_SPOT.make(Vector3(0, 0, 0), _echo_offer.bind(i), _take_echo.bind(i), 2.0, 2.2)
		spot.name = "Spot"
		m.add_child(spot)
	_refresh()
	if not Portals.is_cleared(world_id) and echoes_found() == 0:
		Game.message.call_deferred("Shard Isle hums out of tune. Find the three Echo Crystals on the little islets, and bring their song back to the Heart Stone.")


# The Echo Crystals -------------------------------------------------------------------------------------------------
func echo_id(i: int) -> String:
	return "echo_%d" % (i + 1)


func has_echo(i: int) -> bool:
	return Portals.has_found(world_id, echo_id(i))


func echoes_found() -> int:
	var n := 0
	for i in ECHOES.size():
		if has_echo(i):
			n += 1
	return n


func _echo_offer(i: int) -> String:
	return "take the Echo Crystal" if not has_echo(i) else ""


func _take_echo(i: int) -> void:
	if has_echo(i):
		return
	Portals.note_found(world_id, echo_id(i))
	var m := get_node_or_null(ECHOES[i]) as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.3, 0), ECHO_COLOURS[i], 22, 0.07, 3.0, -1.5, 0.9)
	Audio.play("pickup", -2.0, 0.0)
	Juice.blip("chime", 0.9 + i * 0.2, -5.0)
	var n := echoes_found()
	Game.message("An Echo Crystal! It sings one clear note. (%d of 3)" % n if n < 3
		else "The third Echo Crystal! All three are singing. Take them to the Heart Stone in the middle of the island.")
	_refresh()


# The Heart Stone ---------------------------------------------------------------------------------------------------
func _heart_offer() -> String:
	if Portals.is_cleared(world_id):
		return "listen to the Heart Stone"
	return "set the Echo Crystals in the Heart Stone" if echoes_found() == 3 else "look at the Heart Stone"


func _use_heart() -> void:
	if Portals.is_cleared(world_id):
		Game.message("The Heart Stone hums a calm, steady tune. Shard Isle's time is right again.")
		return
	if echoes_found() < 3:
		Game.message("The Heart Stone has three empty hollows, and it hums a wobbly, broken tune. (%d of 3 Echo Crystals found)" % echoes_found())
		Audio.play("ui_back", -8.0)
		return
	mend()


func mend() -> void:
	# All three in: the island hums in tune again
	Portals.clear(world_id)
	var heart := get_node_or_null("HeartStone/Heart") as Node3D
	if heart:
		var at := heart.global_position + Vector3(0, 2.0, 0)
		for k in 3:
			Fx.burst(self, at, ECHO_COLOURS[k], 26, 0.08, 4.0, -1.0, 1.2)
	Juice.shake(0.2)
	Juice.rumble(0.3, 0.3)
	Juice.blip("chime", 1.0, -3.0)
	_refresh()


func _refresh() -> void:
	for i in ECHOES.size():
		var e := get_node_or_null("%s/Echo" % ECHOES[i]) as Node3D
		if e:
			e.visible = not has_echo(i)
	var heart := get_node_or_null("HeartStone/Heart") as Node3D
	if heart:
		var mended := Portals.is_cleared(world_id)
		for i in 3:
			var socket := heart.get_node_or_null("Socket%d" % i) as Node3D
			if socket:
				socket.visible = mended
		(heart.get_node("Song") as OmniLight3D).light_energy = 3.0 if mended else 0.4


func _process(delta: float) -> void:
	# Until it's mended the little floating shards stutter (time skipping); afterwards they bob gently
	_t += delta
	var jitter := get_node_or_null("Jitter") as Node3D
	if jitter == null:
		return
	var mended := not has_meta("preview") and Portals.is_cleared(world_id)
	var k := 0
	for s in jitter.get_children():
		k += 1
		if not s.has_meta("home"):
			s.set_meta("home", (s as Node3D).position)
		var home: Vector3 = s.get_meta("home")
		if mended:
			(s as Node3D).position = home + Vector3(0, sin(_t * 1.2 + k) * 0.25, 0)
			(s as Node3D).rotation.y += delta * 0.4
		else:
			var step := floorf(_t * 3.0 + k * 0.37)        # jumps, a few times a second, like a skipping record
			var wob := Vector3(sin(step * 1.7 + k), sin(step * 2.3 + k) * 0.5, cos(step * 1.3 + k)) * 0.35
			(s as Node3D).position = home + wob
	var heart := get_node_or_null("HeartStone/Heart") as Node3D
	if heart and mended:
		(heart.get_node("Orb") as Node3D).rotation.y += delta * 0.8


# Looks ------------------------------------------------------------------------------------------------------------
static func echo_model(colour: Color) -> Node3D:
	# An Echo Crystal: a tall singing crystal on a little stand, with rings of light round it
	var g := Node3D.new()
	var gem := MeshInstance3D.new()
	gem.mesh = Remnants.crystal_mesh(0.22, 0.9)
	var m := Remnants.crystal_mat()
	m.albedo_color = colour
	m.emission = colour
	m.emission_energy_multiplier = 2.2
	gem.material_override = m
	gem.position.y = 1.3
	g.add_child(gem)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.48
	ring.mesh = t
	ring.material_override = m
	ring.position.y = 1.3
	g.add_child(ring)
	var stand := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.25
	c.bottom_radius = 0.35
	c.height = 0.7
	c.radial_segments = 6
	stand.mesh = c
	stand.material_override = Remnants.obsidian_mat()
	stand.position.y = 0.35
	g.add_child(stand)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position.y = 1.4
	g.add_child(light)
	return g


static func heart_model() -> Node3D:
	# The Heart Stone: a broad obsidian plinth with three hollows and a big pale orb over it that lights up when mended
	var g := Node3D.new()
	var base := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.4
	c.bottom_radius = 1.8
	c.height = 1.2
	c.radial_segments = 6
	base.mesh = c
	base.material_override = Remnants.obsidian_mat()
	base.position.y = 0.6
	g.add_child(base)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 1.7
	cy.height = 1.2
	cs.shape = cy
	cs.position.y = 0.6
	body.add_child(cs)
	g.add_child(body)
	for i in 3:
		var a := i * TAU / 3.0
		var socket := MeshInstance3D.new()
		socket.name = "Socket%d" % i
		socket.mesh = Remnants.crystal_mesh(0.16, 0.6)
		var m := Remnants.crystal_mat()
		m.albedo_color = ECHO_COLOURS[i]
		m.emission = ECHO_COLOURS[i]
		socket.material_override = m
		socket.position = Vector3(cos(a) * 0.9, 1.5, sin(a) * 0.9)
		g.add_child(socket)
	var orb := MeshInstance3D.new()
	orb.name = "Orb"
	var s := SphereMesh.new()
	s.radius = 0.6
	s.height = 1.2
	s.radial_segments = 8
	s.rings = 4
	orb.mesh = s
	var om := Remnants.crystal_mat()
	om.albedo_color = Color(0.9, 0.95, 1.0)
	om.emission = Color(0.8, 1.0, 0.9)
	orb.material_override = om
	orb.position.y = 2.4
	g.add_child(orb)
	var song := OmniLight3D.new()
	song.name = "Song"
	song.light_color = Color(0.8, 1.0, 0.9)
	song.omni_range = 9.0
	song.position.y = 2.4
	g.add_child(song)
	var sign := Label3D.new()
	sign.text = "Heart Stone"
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position.y = 3.6
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.add_child(sign)
	return g
