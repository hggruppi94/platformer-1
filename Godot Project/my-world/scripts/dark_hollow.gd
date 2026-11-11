extends "res://scripts/portal_world.gd"

# Dark Hollow, the centipede's home world (plan items 19a world 7 and 21; scene built by tools/build_dark_hollow.gd).
# The opt-in scary world, and its way in is a secret: there's no portal. Behind the Walls in the castle school, at the
# far end of the passage, the centipede has her corner (scripts/centipede_corner.gd). Talk to her, say yes, and she
# circles round you and gulps you up: a long soft slide down, and out you pop here. (Saying no is fine: it's
# recorded either way, like the old Scary World gate.)
#
# A misty, moonlit hollow, cozy-spooky, ringed by crooked trees. Shadows are eating up its moments of time: the Moon
# Clock in the sky is stuck at midnight with three dark pieces missing. Three Moon Pieces mend it:
#   Piece1  the Ghost Glade: pop its eight shadow ghosts (scripts/shadow_ghost.gd, lost bits of time), and their
#           wisps of light gather into the first piece
#   Piece2  on top of the Crooked Spire, far too sheer to climb: jump into the Big Hole in the middle of the hollow and
#           it spits you out up there (after that it spits you out somewhere else each time)
#   Piece3  the Hollow Run (scripts/races.gd "hollow_run", started by Pip by the line): finish it, any place
# With all three, the Hush (scripts/the_hush.gd, a big shadow ghost) wakes over Hush Hill when you come near. It's
# only shadow in the dark, so lure it into the light of the four moon lamps round the hill (or your own Pip's glow) and
# pop it there. Then the pieces fly home, the Moon Clock ticks past midnight, the mist thins and the stars come out.
# The centipede gulps you in but doesn't stay (she's only ever in one place: Hayden, 11 Nov 2026): by the hollow log
# where you land she's left a note saying what to do. Mending it makes her your friend for good (flag
# "dark_hollow_friend"), and she thanks you at home, by her hollow log behind the old Scary World gate.
# The way home never takes you back through the scary bit: it comes out at the castle school's front gate in the Void.
# Nothing here hurts more than a normal bump.

const SHADOW_GHOST := preload("res://scripts/shadow_ghost.gd")
const THE_HUSH := preload("res://scripts/the_hush.gd")
const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const CENTIPEDE_WALKER := preload("res://scripts/centipede_walker.gd")
const GHOSTS := 8
const PIECE_NAMES := ["the Ghost Glade's Moon Piece", "the Moon Piece on the Crooked Spire", "the Hollow Run's Moon Piece"]
const HOLE_R := 4.5
const HOLE_CATCH := -3.0                  # fall this far into the Big Hole and it spits you out
const SPIT_UP := 9.5                      # m/s up out of a ground spout
const PICK_NEAR := 1.6
const WAKE_NEAR := 16.0                   # this close to Hush Hill with all three pieces and the Hush wakes
const LAMPS := 4
const LIT_NEAR := 6.0                     # (the_hush.gd LIT_NEAR)
const RELIGHT_AFTER := 14.0               # a hushed lamp comes back on by itself after this long
const MEND_TIME := 5.0
const SPIT_ORDER := ["Spout2", "Spout3", "Spout4", "Spout1"]
const STARS := 300
const RACE := "hollow_run"
const MOON := Color(1.0, 0.95, 0.75)
const LAMP_GLOW := Color(0.75, 0.95, 1.0)

# Midnight (stuck) and mended: the sky, the light and the fog lerp between these (set_mended)
const STUCK := {"top": Color(0.04, 0.04, 0.12), "horizon": Color(0.2, 0.17, 0.33), "ambient": Color(0.36, 0.4, 0.62),
	"fog": Color(0.26, 0.26, 0.42), "density": 0.012, "height_density": 0.12, "energy": 0.5}
const MENDED := {"top": Color(0.06, 0.1, 0.26), "horizon": Color(0.3, 0.32, 0.55), "ambient": Color(0.5, 0.55, 0.8),
	"fog": Color(0.36, 0.38, 0.6), "density": 0.005, "height_density": 0.04, "energy": 0.75}

var hush_awake := false
var mended := 0.0                         # 0 = stuck at midnight, 1 = mended
var lamps_lit: Array[bool] = []
var _relight: Array[float] = []
var _hush: CharacterBody3D
var _ghosts: Array = []                   # the glade's ghosts still out (index -> node or null)
var _pieces: Array = []                   # the Moon Piece pickups showing (index -> node or null)
var _clock: Node3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _moon_light: DirectionalLight3D
var _spit_next := 0                       # where in SPIT_ORDER the hole spits you out next (once the spire's piece is found)
var _spitting := false
var _t := 0.0
var spits := 0                            # times the hole spat you out this visit (tests read it)
var last_spout := ""


func picture() -> void:
	# In a preview (a practice trip's list doesn't show one, but keep it right): the stuck Moon Clock and the lamps
	_own_sky()
	_add_clock()
	_add_stars()
	set_mended(1.0 if Portals.is_cleared(world_id) else 0.0)


func setup() -> void:
	_own_sky()
	_add_clock()
	_add_stars()
	_add_lamps()
	_add_centipede()
	for i in GHOSTS:
		_ghosts.append(null)
		if not Portals.has_found(world_id, "ghost_%d" % (i + 1)) and not Portals.is_cleared(world_id):
			_add_ghost(i)
	for i in 3:
		_pieces.append(null)
		_show_piece(i)
	if not Portals.is_cleared(world_id):
		_add_hush()
	set_mended(1.0 if Portals.is_cleared(world_id) else 0.0)
	Races.finished.connect(_on_race_finished)
	if not Portals.is_cleared(world_id) and pieces_found() == 0 and not Portals.has_found(world_id, "met_centipede"):
		Game.message.call_deferred("Dark Hollow. Misty, moonlit and very quiet... The centipede scuttles out of the mist behind you. She's coming too!")


func _own_sky() -> void:
	# Each copy of the world gets its own sky, so mending it here never changes the next trip's start
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		_env = we.environment.duplicate(true) as Environment
		we.environment = _env
		_sky = _env.sky.sky_material as ProceduralSkyMaterial if _env.sky else null
	_moon_light = get_node_or_null("Moonlight") as DirectionalLight3D


func set_mended(k: float) -> void:
	mended = clampf(k, 0.0, 1.0)
	if _sky:
		_sky.sky_top_color = (STUCK.top as Color).lerp(MENDED.top, mended)
		_sky.sky_horizon_color = (STUCK.horizon as Color).lerp(MENDED.horizon, mended)
		_sky.ground_horizon_color = _sky.sky_horizon_color
	if _env:
		_env.ambient_light_color = (STUCK.ambient as Color).lerp(MENDED.ambient, mended)
		_env.fog_light_color = (STUCK.fog as Color).lerp(MENDED.fog, mended)
		_env.fog_density = lerpf(float(STUCK.density), float(MENDED.density), mended)
		_env.fog_height_density = lerpf(float(STUCK.height_density), float(MENDED.height_density), mended)
	if _moon_light:
		_moon_light.light_energy = lerpf(float(STUCK.energy), float(MENDED.energy), mended)
	if _clock:
		var face := _clock.get_node("Face") as MeshInstance3D
		(face.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(0.5, 1.4, mended)
	var stars := get_node_or_null("Stars") as Node3D
	if stars:
		var m := (stars.get_child(0) as MultiMeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color.a = lerpf(0.35, 1.0, mended)


func is_mended() -> bool:
	return mended >= 0.99


# The Moon Clock ---------------------------------------------------------------------------------------------------
func _add_clock() -> void:
	var m := get_node_or_null("MoonClock") as Node3D
	if m == null:
		return
	_clock = moon_clock_model()
	_clock.name = "Moon Clock"
	m.add_child(_clock)
	_clock.look_at(Vector3(0, m.global_position.y * 0.3, 40), Vector3.UP, true)      # its face to the hollow
	for i in 3:
		_light_wedge(i, Portals.has_found(world_id, "piece_%d" % (i + 1)) or Portals.is_cleared(world_id))


func _light_wedge(i: int, on: bool) -> void:
	if _clock == null:
		return
	var w := _clock.get_node_or_null("Wedge%d" % (i + 1)) as MeshInstance3D
	if w:
		var m := w.material_override as StandardMaterial3D
		m.albedo_color = MOON if on else Color(0.05, 0.04, 0.1)
		m.emission_enabled = on
		m.emission = MOON
		m.emission_energy_multiplier = 1.4


static func moon_clock_model() -> Node3D:
	# The hollow's moon is a clock: a great pale face with twelve marks and two hands, and three wedges of it gone
	# dark (eaten by the shadows). Its own materials each time, so lighting a wedge never changes another copy.
	var g := Node3D.new()
	var face := MeshInstance3D.new()
	face.name = "Face"
	var fc := CylinderMesh.new()
	fc.top_radius = 16.0
	fc.bottom_radius = 16.0
	fc.height = 0.4
	fc.radial_segments = 48
	face.mesh = fc
	face.rotation.x = PI / 2.0
	var fm := _mat(MOON, 0.5)
	face.material_override = fm
	g.add_child(face)
	for i in 3:                                    # the three wedges, over the face (a third of the rim each, gaps between)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a0 := i * TAU / 3.0 + 0.25
		var a1 := a0 + TAU / 3.0 - 0.5
		var steps := 12
		for k in steps:
			var b0 := lerpf(a0, a1, float(k) / steps)
			var b1 := lerpf(a0, a1, float(k + 1) / steps)
			for p in [Vector3(cos(b0) * 6.0, sin(b0) * 6.0, 0), Vector3(cos(b0) * 15.0, sin(b0) * 15.0, 0),
					Vector3(cos(b1) * 15.0, sin(b1) * 15.0, 0), Vector3(cos(b0) * 6.0, sin(b0) * 6.0, 0),
					Vector3(cos(b1) * 15.0, sin(b1) * 15.0, 0), Vector3(cos(b1) * 6.0, sin(b1) * 6.0, 0)]:
				st.set_normal(Vector3.BACK)
				st.add_vertex(p)
		var w := MeshInstance3D.new()
		w.name = "Wedge%d" % (i + 1)
		w.mesh = st.commit()
		var wm := _mat(Color(0.05, 0.04, 0.1))
		wm.cull_mode = BaseMaterial3D.CULL_DISABLED
		w.material_override = wm
		w.position.z = 0.25
		g.add_child(w)
	var mark := _mat(Color(0.35, 0.3, 0.45))
	for k in 12:
		var a := k * TAU / 12.0
		var t := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.6, 2.0 if k % 3 == 0 else 1.2, 0.2)
		t.mesh = b
		t.material_override = mark
		t.position = Vector3(sin(a) * 14.2, cos(a) * 14.2, 0.4)
		t.rotation.z = -a
		g.add_child(t)
	for k in 2:                                    # both hands straight up: midnight
		var hand := Node3D.new()
		hand.name = "Hour Hand" if k == 0 else "Minute Hand"
		hand.position.z = 0.5 + k * 0.1
		g.add_child(hand)
		var h := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9 - k * 0.3, 8.0 + k * 4.0, 0.2)
		h.mesh = b
		h.material_override = mark
		h.position.y = (8.0 + k * 4.0) / 2.0
		hand.add_child(h)
	var light := OmniLight3D.new()
	light.light_color = MOON
	light.light_energy = 0.0                       # (just a glow on its own face: it's far away)
	g.add_child(light)
	return g


func _add_stars() -> void:
	var g := Node3D.new()
	g.name = "Stars"
	add_child(g)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := SphereMesh.new()
	q.radius = 0.35
	q.height = 0.7
	q.radial_segments = 6
	q.rings = 3
	mm.mesh = q
	mm.instance_count = STARS
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in STARS:
		var a := rng.randf() * TAU
		var up := rng.randf_range(0.25, 1.3)
		var p := Vector3(cos(a) * cos(up), sin(up), sin(a) * cos(up)) * 220.0
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.6, 1.6)), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := _mat(Color(0.9, 0.92, 1.0), 2.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.add_child(mi)


# The shadow ghosts -------------------------------------------------------------------------------------------------
func _add_ghost(i: int) -> void:
	var m := get_node_or_null("Ghost%d" % (i + 1)) as Node3D
	if m == null:
		return
	var g := SHADOW_GHOST.new() as CharacterBody3D
	g.name = "Shadow Ghost %d" % (i + 1)
	g.set("wander_radius", 3.0)
	g.set("leash_range", 13.0)
	add_child(g)
	g.global_position = m.global_position
	g.popped.connect(_on_ghost_popped.bind(i))
	_ghosts[i] = g


func ghost_node(i: int) -> Node3D:
	var g = _ghosts[i] if i < _ghosts.size() else null
	return g as Node3D if g != null and is_instance_valid(g) else null


func ghosts_popped() -> int:
	var n := 0
	for i in GHOSTS:
		if Portals.has_found(world_id, "ghost_%d" % (i + 1)):
			n += 1
	return n


func _on_ghost_popped(_g: Node3D, i: int) -> void:
	_ghosts[i] = null
	if Portals.has_found(world_id, "ghost_%d" % (i + 1)):
		return
	Portals.note_found(world_id, "ghost_%d" % (i + 1))
	var n := ghosts_popped()
	if n >= GHOSTS:
		Game.message("All eight shadow ghosts popped! Their wisps of light are gathering in the middle of the glade...")
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if is_inside_tree():
				_show_piece(0, true))
	else:
		Game.message("A shadow ghost popped into a wisp of light! %d of %d." % [n, GHOSTS])


func call_ghosts(at: Vector3, n: int) -> void:
	# The Hush calls up a few little ghosts round it (they don't come back once popped)
	for k in n:
		var g := SHADOW_GHOST.new() as CharacterBody3D
		g.name = "Hush Ghost"
		g.add_to_group("hush_helpers")         # (siblings with the same name get renamed, so go by the group)
		g.set("wander_radius", 5.0)
		g.set("sight_range", 12.0)
		g.set("leash_range", 20.0)
		add_child(g)
		var a := k * TAU / n + randf()
		g.global_position = ground_below(at + Vector3(cos(a), 0, sin(a)) * 3.5)
		Fx.burst(self, g.global_position + Vector3(0, 1, 0), SHADOW_GHOST.SHEEN, 8, 0.06, 1.5, 0.0, 0.4)


func helpers() -> Array:
	return get_tree().get_nodes_in_group("hush_helpers")


# The Moon Pieces ---------------------------------------------------------------------------------------------------
func is_piece_found(i: int) -> bool:
	return Portals.has_found(world_id, "piece_%d" % (i + 1)) or Portals.is_cleared(world_id)


func pieces_found() -> int:
	var n := 0
	for i in 3:
		if is_piece_found(i):
			n += 1
	return n


func piece_ready(i: int) -> bool:
	# Is this piece out to pick up? (The glade's once its ghosts are popped; the spire's always; the race's never: you're
	# given it at the finish.)
	if is_piece_found(i):
		return false
	match i:
		0:
			return ghosts_popped() >= GHOSTS
		1:
			return true
	return false


func piece_node(i: int) -> Node3D:
	var p = _pieces[i] if i < _pieces.size() else null
	return p as Node3D if p != null and is_instance_valid(p) else null


func _show_piece(i: int, fanfare := false) -> void:
	if piece_node(i) != null or not piece_ready(i):
		return
	var m := get_node_or_null("Piece%d" % (i + 1)) as Node3D
	if m == null:
		return
	var p := moon_piece_model()
	p.name = "Moon Piece"
	m.add_child(p)
	_pieces[i] = p
	if fanfare:
		Fx.burst(self, m.global_position, MOON, 30, 0.08, 4.0, -1.0, 1.0)
		Juice.blip("chime", 1.2, -4.0)
		Game.message("A Moon Piece! Grab it.")


func pick_piece(i: int) -> bool:
	if is_piece_found(i):
		return false
	Portals.note_found(world_id, "piece_%d" % (i + 1))
	var p := piece_node(i)
	var at := p.global_position if p else _player_pos()
	if p:
		p.queue_free()
	_pieces[i] = null
	_light_wedge(i, true)
	Fx.burst(self, at, MOON, 30, 0.08, 4.0, -1.0, 1.0)
	Juice.chime_pickup()
	Juice.blip("chime", 1.0, -4.0)
	var n := pieces_found()
	if n >= 3:
		Game.message("All three Moon Pieces! Up in the sky the Moon Clock's whole again, but something's stirring on Hush Hill...")
	else:
		Game.message("%s! The Moon Clock's a little brighter. (%d of 3)" % [PIECE_NAMES[i].capitalize(), n])
	return true


static func moon_piece_model() -> Node3D:
	# A glowing slice of moon, turning slowly, with a soft light
	var g := Node3D.new()
	var spin := Node3D.new()
	spin.name = "Spin"
	g.add_child(spin)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.55
	c.bottom_radius = 0.55
	c.height = 0.14
	c.radial_segments = 24
	mi.mesh = c
	mi.rotation.x = PI / 2.0
	mi.material_override = _mat(MOON, 2.2)
	spin.add_child(mi)
	var bite := MeshInstance3D.new()                # a bite out of one side, so it reads as a piece of moon
	var bc := CylinderMesh.new()
	bc.top_radius = 0.42
	bc.bottom_radius = 0.42
	bc.height = 0.16
	bc.radial_segments = 24
	bite.mesh = bc
	bite.rotation.x = PI / 2.0
	bite.position.x = 0.36
	bite.material_override = _mat(Color(0.08, 0.06, 0.16))
	spin.add_child(bite)
	var light := OmniLight3D.new()
	light.light_color = MOON
	light.light_energy = 1.4
	light.omni_range = 5.0
	g.add_child(light)
	return g


func _on_race_finished(track_id: String, place: int) -> void:
	if track_id != RACE or not is_inside_tree():
		return
	if is_piece_found(2):
		return
	Game.message("You finished the Hollow Run%s! Pip hands you a Moon Piece." % (" in first place" if place == 1 else ""))
	pick_piece(2)


# The Big Hole ----------------------------------------------------------------------------------------------------
func _watch_hole(player: CharacterBody3D) -> void:
	if _spitting:
		return
	var p := player.global_position
	if p.y < HOLE_CATCH and Vector2(p.x, p.z).length() < HOLE_R + 0.6:
		spit(player)


func spit_spout() -> String:
	# Where the hole spits you out next: the spire's top until you've found its Moon Piece, then round the others
	if not is_piece_found(1):
		return "Spout1"
	var pick: String = SPIT_ORDER[_spit_next % SPIT_ORDER.size()]
	_spit_next += 1
	return pick


func spit(player: CharacterBody3D) -> void:
	# Swallowed... and spat out somewhere else, with a "ptoo!" and a puff
	_spitting = true
	spits += 1
	Portals.note_found(world_id, "hole_jumped")
	last_spout = spit_spout()
	var m := get_node_or_null(last_spout) as Node3D
	var to := m.global_position if m else Vector3(0, 1, 30)
	player.global_position = to + Vector3(0, 0.8, 0)
	player.velocity = Vector3(0, SPIT_UP if last_spout != "Spout1" else 6.0, 0)
	Fx.burst(self, to + Vector3(0, 0.5, 0), Color(0.6, 0.4, 1.0), 26, 0.1, 4.0, -2.0, 0.9)
	Juice.dust(self, to, 0.8)
	Juice.blip("pop", 0.6, -2.0)
	Juice.shake(0.15)
	Audio.play("boing", -4.0)
	if spits == 1 or last_spout == "Spout1":
		Game.message("PTOO! The Big Hole spat you out%s!" % (" on top of the Crooked Spire" if last_spout == "Spout1" else " somewhere else"))
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _spitting = false)


# The moon lamps round Hush Hill --------------------------------------------------------------------------------------
func _add_lamps() -> void:
	for i in LAMPS:
		lamps_lit.append(true)
		_relight.append(0.0)
		var m := get_node_or_null("Lamp%d" % (i + 1)) as Node3D
		if m == null:
			continue
		var model := moon_lamp_model(true)
		model.name = "Lamp"
		m.add_child(model)
		var spot := USE_SPOT.make(Vector3(0, 0.2, 0), func() -> String: return "" if is_lamp_lit(i) else "light the moon lamp",
			func() -> void: light_lamp(i), 2.2, 3.0)
		spot.name = "Spot"
		m.add_child(spot)
		var body := SHOT_TARGET.new() as StaticBody3D
		body.name = "Hit"
		body.on_shot = func() -> String: return "hit" if light_lamp(i) else "bounce"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.4
		cs.shape = sp
		body.add_child(cs)
		body.position.y = 2.6
		m.add_child(body)


func is_lamp_lit(i: int) -> bool:
	return i >= 0 and i < lamps_lit.size() and lamps_lit[i]


func lamp_pos(i: int) -> Vector3:
	var m := get_node_or_null("Lamp%d" % (i + 1)) as Node3D
	return m.global_position if m else Vector3.ZERO


func nearest_lit_lamp(at: Vector3, within := INF) -> int:
	var best := -1
	var best_d := within
	for i in lamps_lit.size():
		if not lamps_lit[i]:
			continue
		var p := lamp_pos(i)
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func light_lamp(i: int) -> bool:
	if is_lamp_lit(i) or i < 0 or i >= lamps_lit.size():
		return false
	lamps_lit[i] = true
	_relight[i] = 0.0
	_swap_lamp(i)
	Fx.burst(self, lamp_pos(i) + Vector3(0, 2.6, 0), LAMP_GLOW, 14, 0.06, 2.5, -1.0, 0.6)
	Juice.blip("chime", 1.4, -8.0)
	return true


func snuff_lamp(i: int) -> void:
	# The Hush hushes it out
	if not is_lamp_lit(i):
		return
	lamps_lit[i] = false
	_relight[i] = RELIGHT_AFTER
	_swap_lamp(i)
	Fx.burst(self, lamp_pos(i) + Vector3(0, 2.6, 0), Color(0.2, 0.15, 0.35), 12, 0.08, 1.5, 0.5, 0.8)
	Juice.blip("whoosh", 0.7, -8.0)
	Game.message("Shhh... the Hush put a moon lamp out! Light it again: Interact, or pop a bubble at it.")


func _swap_lamp(i: int) -> void:
	var m := get_node_or_null("Lamp%d" % (i + 1)) as Node3D
	if m == null:
		return
	var old := m.get_node_or_null("Lamp")
	if old:
		m.remove_child(old)
		old.queue_free()
	var model := moon_lamp_model(lamps_lit[i])
	model.name = "Lamp"
	m.add_child(model)


func lights_hush(at: Vector3) -> bool:
	# Is this spot lit: near a lit moon lamp, or in the player's own Pip's glow?
	if nearest_lit_lamp(at, LIT_NEAR) >= 0:
		return true
	var player := get_tree().get_first_node_in_group("player")
	var glow = player.get_node_or_null("PipGlow") if player else null
	return glow != null and glow.has_method("lights") and glow.lights(at)


static func moon_lamp_model(lit: bool) -> Node3D:
	# A tall crooked iron post with a round glass globe on top, glowing pale moon-blue when it's lit
	var g := Node3D.new()
	var post := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.12
	c.height = 2.3
	c.radial_segments = 8
	post.mesh = c
	post.material_override = _mat(Color(0.14, 0.12, 0.2), 0.0, 0.5)
	post.position.y = 1.15
	g.add_child(post)
	var globe := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	globe.mesh = s
	globe.material_override = _mat(LAMP_GLOW if lit else Color(0.22, 0.2, 0.32), 2.4 if lit else 0.0, 0.3)
	globe.position.y = 2.6
	g.add_child(globe)
	var cap := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 0.05
	cc.bottom_radius = 0.3
	cc.height = 0.22
	cap.mesh = cc
	cap.material_override = post.material_override
	cap.position.y = 3.0
	g.add_child(cap)
	if lit:
		var light := OmniLight3D.new()
		light.light_color = LAMP_GLOW
		light.light_energy = 1.8
		light.omni_range = LIT_NEAR + 1.0
		light.position.y = 2.6
		g.add_child(light)
		var pool := MeshInstance3D.new()             # a faint pool of light on the ground: where the Hush gets caught
		var pc := CylinderMesh.new()
		pc.top_radius = LIT_NEAR
		pc.bottom_radius = LIT_NEAR
		pc.height = 0.04
		pc.radial_segments = 32
		pool.mesh = pc
		var pm := _mat(LAMP_GLOW, 0.6)
		pm.albedo_color.a = 0.12
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pool.material_override = pm
		pool.position.y = 0.05
		g.add_child(pool)
	return g


# The Hush ---------------------------------------------------------------------------------------------------------
func _add_hush() -> void:
	var m := get_node_or_null("Hush") as Node3D
	if m == null:
		return
	var h := THE_HUSH.new() as CharacterBody3D
	h.name = "The Hush"
	h.set("world", self)
	h.process_mode = Node.PROCESS_MODE_DISABLED              # curled up asleep until the pieces are found
	add_child(h)
	h.global_position = m.global_position
	_hush = h
	var zzz := Label3D.new()
	zzz.name = "Snoring"
	zzz.text = "shhh... z z z"
	zzz.font_size = 64
	zzz.pixel_size = 0.01
	zzz.outline_size = 12
	zzz.modulate = Color(0.75, 0.7, 1.0)
	zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	zzz.position = Vector3(1.5, 7.0, 0)
	m.add_child(zzz)
	var spot := USE_SPOT.make(Vector3(0, -0.2, 6.5), func() -> String: return "" if hush_awake else "look at the sleeping shadow",
		_look_at_hush, 2.6, 3.0)
	spot.name = "Spot"
	m.add_child(spot)


func hush() -> CharacterBody3D:
	return _hush if _hush and is_instance_valid(_hush) else null


func _look_at_hush() -> void:
	if hush_awake:
		return
	var left := 3 - pieces_found()
	Game.message("A huge shadow, curled up asleep on the hill, breathing \"shhh\"... It's the Hush. Find the %d Moon Piece%s first." % [left, "" if left == 1 else "s"]
		if left > 0 else "It's stirring...")
	Audio.play("ui_back", -8.0)


func wake_hush() -> void:
	if hush_awake or hush() == null:
		return
	hush_awake = true
	for n in ["Hush/Snoring", "Hush/Spot"]:
		var x := get_node_or_null(n)
		if x:
			x.queue_free()
	for i in LAMPS:
		light_lamp(i)
	_hush.process_mode = Node.PROCESS_MODE_INHERIT
	Fx.burst(self, _hush.global_position + Vector3(0, 3.0, 0), Color(0.35, 0.25, 0.6), 30, 0.12, 4.0, 0.0, 1.0)
	Juice.shake(0.3)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("whoosh", 0.5, -2.0)
	Game.message("The Hush wakes up! In the dark it's only shadow: lure it into a moon lamp's light, then pop it!")


func mend() -> void:
	# The moments it swallowed float home, the Moon Clock ticks past midnight, the mist thins and the stars come out
	hush_awake = false
	for g in helpers():
		if is_instance_valid(g) and not g.defeated:
			g.pop()
	Portals.clear(world_id)
	Dialogue.set_flag("dark_hollow_friend")
	for i in LAMPS:
		light_lamp(i)
	for i in 3:
		_light_wedge(i, true)
	var from := _hush.global_position + Vector3(0, 3.0, 0) if hush() else _player_pos()
	for k in 12:                                             # wisps of light streaming up to the moon
		var w := moon_piece_model()
		w.scale = Vector3.ONE * 0.3
		add_child(w)
		w.global_position = from + Vector3(randf_range(-2, 2), randf_range(0, 2), randf_range(-2, 2))
		var to := _clock.global_position if _clock else from + Vector3(0, 60, -120)
		var tw := w.create_tween()
		tw.tween_interval(k * 0.12)
		tw.tween_property(w, "global_position", to, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(w.queue_free)
	var tw := create_tween()
	tw.tween_method(set_mended, mended, 1.0, MEND_TIME)
	Juice.blip("chime", 0.8, -3.0)
	get_tree().create_timer(MEND_TIME + 1.0).timeout.connect(_thank_you)


func _thank_you(tries := 0) -> void:
	# She cheers, then asks you to come and find her at home, behind the old gate (scripts/scary_world.gd), and
	# burrows off up her tunnels: the way home takes you there this first time (Portals.go_home()).
	if not is_inside_tree():
		return
	if Dialogue.is_active() and tries < 20:
		get_tree().create_timer(1.0).timeout.connect(_thank_you.bind(tries + 1))
		return
	var spot := get_node_or_null("Centipede/Model/Head/Spot") as Node3D
	if spot == null:
		return
	Dialogue.say(spot, centipede_name(), thank_lines().map(func(l: String) -> String: return Settings.fill(l)), "dark_hollow_thanks")
	Dialogue.finished.connect(_burrow_home, CONNECT_ONE_SHOT)


func thank_lines() -> Array:
	return ["{player}! Listen. Can you hear it? Tick... tick... tick...",
		"The Moon Clock's going again! It's past midnight in Dark Hollow for the first time in forever.",
		"You stayed with me. All the way through. Even with the shadows.",
		"Will you come to my home? Up in the Void, behind the old gate in the woods. It'll be open now.",
		"There's... one more thing I need to know. Before we're friends for keeps. I'll tell you there!",
		"The way home will take you. See you there! (Gulp, slide, scuttle...)"]


func _burrow_home(_id := "") -> void:
	# Off she goes, down into the ground and up her tunnels towards home
	var m := get_node_or_null("Centipede/Model") as Node3D
	if m == null:
		return
	m.set("follow", null)
	var spot := m.get_node_or_null("Head/Spot")
	if spot:
		spot.queue_free()
	var head := m.get_node_or_null("Head") as Node3D
	Fx.burst(self, (head.global_position if head else _player_pos()), Color(0.5, 0.4, 0.55), 16, 0.08, 3.0, -1.0, 0.6)
	Juice.blip("whoosh", 0.7, -4.0)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 0.05, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(m.queue_free)


# The centipede, following you round ----------------------------------------------------------------------------------
# She gulped you down here and came too (Hayden, 11 Nov 2026: "she can follow you to scary world"): she scuttles
# along behind you wherever you go (scripts/centipede_walker.gd), and talking to her says what to do next. She isn't
# anywhere else meanwhile (her school corner's empty while you're here). Once Dark Hollow's mended she goes home,
# behind the old gate, so she isn't down here any more.
func centipede_name() -> String:
	var n := str(Dialogue.names.get("centipede", ""))
	return n if n != "" else "The Centipede"


func _add_centipede() -> void:
	var m := get_node_or_null("Centipede") as Node3D
	if m == null or Portals.is_cleared(world_id):
		return
	var w := CENTIPEDE_WALKER.new() as Node3D
	w.name = "Model"
	w.set("head_height", 1.1)
	m.add_child(w)
	w.call("place", m.global_position, m.global_rotation.y)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		w.set("follow", player)
	var head := w.get_node("Head") as Node3D
	var spot := USE_SPOT.make(Vector3(0, -1.0, 0.6), func() -> String: return "talk to %s" % centipede_name().replace("The C", "the c"),
		_talk_centipede, 1.6, 2.2)
	spot.name = "Spot"
	head.add_child(spot)


func centipede_lines() -> Array:
	if not Portals.has_found(world_id, "met_centipede"):
		Portals.note_found(world_id, "met_centipede")
		return ["Ptoo! Sorry about that. Spitting out is the only way out of a gulp. Are you all right? Not a scratch?",
			"Welcome to Dark Hollow, {player}. My home, deep down. It looks spooky, I know. It's meant to be cosy.",
			"I'm coming with you! I know every corner. And it's much less scary with two. (Well. With one and a lot of legs.)",
			"Look up. The Moon Clock. It's stuck at midnight, and three pieces of it have gone dark.",
			"The shadows have been eating our moments. Little bits of time, gone dark and flittery. Shadow ghosts.",
			"One Moon Piece is in the Ghost Glade, where the shadow ghosts are. Pop them all!",
			"One's on top of the Crooked Spire. Nobody can climb it... but the Big Hole spits things out in funny places.",
			"And Pip came down to start the Hollow Run, the race round the hollow. Finish it and the last piece is yours."]
	var left: Array = []
	for i in 3:
		if not is_piece_found(i):
			left.append(["pop the shadow ghosts in the Ghost Glade (%d of %d)" % [ghosts_popped(), GHOSTS],
				"jump in the Big Hole and see where it spits you out", "finish the Hollow Run with Pip"][i])
	if left.size() > 0:
		return ["%d Moon Piece%s! The moon looks a little less hungry." % [3 - left.size(), "" if 3 - left.size() == 1 else "s"]
			if left.size() < 3 else "Don't be scared of the shadow ghosts. They're only lost little bits of time.",
			"Still to do: %s." % ", and ".join(left)]
	return ["All three Moon Pieces! But the Hush is waking up on Hush Hill. It's the one that swallowed our moments.",
		"In the dark it's only shadow: nothing can touch it. But it can't hide in the light!",
		"Lure it into a moon lamp's light, then pop it. If it puts a lamp out, light it again. I'll stay back and cheer. Shhh, it's coming!"]


func _talk_centipede() -> void:
	var spot := get_node_or_null("Centipede/Model/Head/Spot") as Node3D
	if spot:
		Dialogue.say(spot, centipede_name(), centipede_lines().map(func(l: String) -> String: return Settings.fill(l)), "dark_hollow_centipede")


# Every frame ------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if has_meta("preview"):
		return
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	for i in _pieces.size():
		var p := piece_node(i)
		if p:
			(p.get_node("Spin") as Node3D).rotation.y += delta * 1.5
			p.position.y = sin(_t * 2.0 + i) * 0.15
			if player and player.global_position.distance_to(p.global_position) < PICK_NEAR + 0.8:
				pick_piece(i)
	for i in _relight.size():
		if not lamps_lit[i] and _relight[i] > 0.0:
			_relight[i] -= delta
			if _relight[i] <= 0.0:
				light_lamp(i)
	var cw := get_node_or_null("Centipede/Model")
	if cw:
		cw.set("gap", 6.0 if hush_awake and hush() else 3.2)       # she keeps back while the Hush is awake
	if player:
		_watch_hole(player)
		if not hush_awake and hush() and pieces_found() >= 3:
			var hill := (get_node("Hush") as Node3D).global_position
			if Vector2(player.global_position.x - hill.x, player.global_position.z - hill.z).length() < WAKE_NEAR:
				wake_hush()
	if _clock and is_mended():                              # the hands go round again
		var mh := _clock.get_node("Minute Hand") as Node3D
		var hh := _clock.get_node("Hour Hand") as Node3D
		mh.rotation.z -= delta * 0.2
		hh.rotation.z -= delta * 0.2 / 12.0


# Helpers ----------------------------------------------------------------------------------------------------------
func _player_pos() -> Vector3:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player else Vector3.ZERO


func ground_below(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 3, 0), at + Vector3(0, -20, 0))
	q.collide_with_areas = false
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	var skip: Array[RID] = []
	if player:
		skip.append(player.get_rid())
	if hush():
		skip.append(_hush.get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return hit.position if not hit.is_empty() else Vector3(at.x, 0.0, at.z)


static func _mat(colour: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = emit
	return m
