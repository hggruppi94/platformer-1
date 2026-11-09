extends Node3D

# Melody's Stage: Rhythm Springs' change to the Void (Portals._hub_changes(), once it's mended). A round stage beside
# her portal on the lake's south-west shore, under a pink and cream striped canopy, with speakers, a ring of
# footlights and a sign. Nothing is built into town.tscn: Portals puts it in each time the town loads.
#
# Its footlights pulse on Melody's beat (the same clock as the player's groove, scripts/groove.gd), all day, and flash
# brighter whenever someone grooves on the stage. Every evening once her world's mended, Melody puts on a **show**
# here (routines/melody.json "mended": 6 to 9 PM, label "show"): she dances in the middle, the spotlights swing and
# music notes float up. Come up on the stage while she's on and it's a **dance-off**: groove on the beat DANCE_OFF
# times in a row and the crowd (well, Melody) shouts for an encore: PRIZE sparkles, once a visit
# (Portals.stage_prize_day, saved).

const RADIUS := 3.6                      # the stage floor's radius
const TOP := 0.5                         # how high its floor is
const DANCE_OFF := 8                     # grooves on the beat in a row for the encore
const PRIZE := 6
const BEAT := 0.8                        # Melody's beat (scripts/groove.gd BEAT)
const LIGHTS := 14
const PINK := Color(1.0, 0.55, 0.82)
const CREAM := Color(1.0, 0.93, 0.8)
const PURPLE := Color(0.5, 0.3, 0.7)
const LIGHT_COLOURS := [Color(1.0, 0.45, 0.8), Color(0.65, 0.5, 1.0), Color(1.0, 0.85, 0.3), Color(0.45, 0.9, 1.0),
	Color(0.55, 1.0, 0.55)]

var flash := 0.0                         # 1 just after a groove on the stage, fading
var best := 0                            # the best streak in this show (for the tests and the message)
var told_today := -1                     # the visit the dance-off was explained on
var encores := 0                         # (for the tests)
var _player: Node3D
var _groove: Node
var _melody: Node                        # her Routine, in the town
var _lights: Array = []                  # [mesh, material] round the rim
var _spots: Array = []                   # the two spotlights
var _notes: Array = []
var _t := 0.0
var cleared_plants := 0                  # undergrowth moved out of the way (for the tests)


func _ready() -> void:
	var model := build_model()
	add_child(model)
	_lights = model.get_meta("lights", [])
	_spots = model.get_meta("spots", [])
	_clear_round.call_deferred()


func _clear_round() -> void:
	# The town's trees and undergrowth are scattered by the builder (scenes/town/trees.gd, foliage.gd, built from lists
	# when the scene loads), and a few grow where the stage and its audience go. Like the lab's plot
	# (scripts/lab.gd _clear_plot), the ones on the stage or in front of it are shrunk away and lose their solid parts.
	var s := get_tree().current_scene
	if s == null:
		return
	for holder_name in ["Trees", "Foliage"]:
		var holder := s.find_child(holder_name, true, false)
		if holder == null:
			continue
		for n in holder.get_children():
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
				var mm := (n as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var t := mm.get_instance_transform(i)
					if in_the_way((n as Node3D).global_transform * t.origin) and t.basis.get_scale().x > 0.001:
						mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin))
						cleared_plants += 1
			elif (n is CollisionObject3D or n is Light3D) and in_the_way((n as Node3D).global_position):
				n.queue_free()


func in_the_way(p: Vector3) -> bool:
	# On the stage (and a step round it), or where the audience stands in front
	var local := to_local(p)
	var flat := Vector2(local.x, local.z)
	return flat.length() < RADIUS + 1.8 or (local.z > 0.0 and local.z < RADIUS + 7.0 and absf(local.x) < RADIUS + 1.0)


# Who's about -----------------------------------------------------------------------------------------------------
func _find() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		_groove = null
	if is_instance_valid(_player) and not is_instance_valid(_groove):
		_groove = _player.get_node_or_null("Groove")
		if _groove and not _groove.is_connected("grooved", _on_grooved):
			_groove.connect("grooved", _on_grooved)
	if not is_instance_valid(_melody):
		for r in get_tree().get_nodes_in_group("routines"):
			if str(r.get("character_id")) == "melody":
				_melody = r
				break


func melody() -> Node3D:
	_find()
	return _melody.get_parent() as Node3D if is_instance_valid(_melody) else null


func show_on() -> bool:
	# Melody's on her stage doing her show
	_find()
	if not is_instance_valid(_melody):
		return false
	return _melody.call("activity") == "show" and _melody.call("is_present") and not _melody.call("is_travelling")


func on_stage(p: Node3D) -> bool:
	if p == null:
		return false
	var local := to_local(p.global_position)
	return Vector2(local.x, local.z).length() < RADIUS - 0.1 and local.y > TOP - 0.25 and local.y < TOP + 3.0


func beat_phase() -> float:
	if is_instance_valid(_groove):
		return float(_groove.call("beat_phase"))
	return fposmod(Time.get_ticks_msec() / 1000.0, BEAT) / BEAT


# The dance-off ---------------------------------------------------------------------------------------------------
func _on_grooved(hit: bool, streak: int) -> void:
	if not on_stage(_player):
		return
	flash = 1.0 if hit else 0.5
	if not show_on():
		return
	best = maxi(best, streak)
	var today: int = Requests.visit_day()
	if streak >= DANCE_OFF and Portals.stage_prize_day != today:
		encore()
	elif hit and streak > 1 and streak < DANCE_OFF and Portals.stage_prize_day != today and streak % 2 == 0:
		Game.message("Melody: \"%s\" (%d of %d on the beat)" % [["Yes!", "Ooh, nice!", "Keep going!"][(streak / 2) % 3], streak, DANCE_OFF])


func encore() -> void:
	# The dance-off's won: an encore!
	Portals.stage_prize_day = Requests.visit_day()
	encores += 1
	Game.add_sparkles(PRIZE, "Melody's dance-off")
	Game.message("Melody: \"ENCORE! ENCORE! You're a STAR, %s!\"" % Dialogue.player_name() + "  (+%d sparkles)" % PRIZE)
	Fx.burst(get_parent(), global_position + Vector3(0, TOP + 2.5, 0), PINK, 40, 0.1, 5.0, -2.0, 1.4)
	Fx.burst(get_parent(), global_position + Vector3(0, TOP + 2.5, 0), Color(1.0, 0.85, 0.3), 30, 0.08, 4.0, -2.0, 1.2)
	Juice.blip("sparkle", 1.2, -3.0)
	Juice.rumble(0.3, 0.25)


func _explain() -> void:
	# The first time you step up during a show (each visit), say what to do
	var today: int = Requests.visit_day()
	if told_today == today:
		return
	told_today = today
	if Portals.stage_prize_day == today:
		Game.message("Melody: \"Dance with me again! Just for fun this time.\"")
	else:
		Game.message("Melody's show! Groove on the beat with her (%s), %d in a row, for an encore." % [Settings.prompt("groove"), DANCE_OFF])


# Every frame ------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_find()
	flash = maxf(0.0, flash - delta * 2.0)
	var live := show_on()
	if live and on_stage(_player):
		_explain()
	var k := 1.0 - beat_phase()
	var pulse := k * k
	var step := int(floor(_t / BEAT))
	for i in _lights.size():
		var pair: Array = _lights[i]
		var m: StandardMaterial3D = pair[1]
		var c: Color = LIGHT_COLOURS[(i + step) % LIGHT_COLOURS.size()]
		m.albedo_color = c
		m.emission = c
		m.emission_energy_multiplier = 0.6 + (1.6 if live else 0.6) * pulse + 2.5 * flash
	for i in _spots.size():
		var s := _spots[i] as OmniLight3D
		s.visible = live or flash > 0.0
		s.light_energy = 1.2 + 1.8 * pulse + 2.0 * flash
		s.light_color = LIGHT_COLOURS[(step + i * 2) % LIGHT_COLOURS.size()]
		s.position.x = (1.0 if i == 0 else -1.0) * (1.6 + sin(_t * 1.3 + i) * 0.9)
	_float_notes(live, delta)


func _float_notes(live: bool, delta: float) -> void:
	# Music notes drifting up from the stage while the show's on
	if live and _notes.size() < 10 and randf() < delta * 3.0:
		var l := Label3D.new()
		l.name = "StageNote"
		l.text = ["♪", "♫", "♬"][randi() % 3]
		l.font_size = 110
		l.pixel_size = 0.006
		l.outline_size = 14
		l.outline_modulate = Color(0.15, 0.06, 0.2)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = LIGHT_COLOURS[randi() % LIGHT_COLOURS.size()]
		add_child(l)
		l.position = Vector3(randf_range(-2.5, 2.5), TOP + 1.2, randf_range(-2.5, 1.0))
		_notes.append(l)
	for l in _notes.duplicate():
		var n := l as Label3D
		if not is_instance_valid(n):
			_notes.erase(l)
			continue
		n.position.y += delta * 0.9
		n.position.x += sin(_t * 2.0 + n.position.z) * delta * 0.4
		n.modulate.a = clampf(1.0 - (n.position.y - TOP - 3.0) / 2.0, 0.0, 1.0)
		if n.position.y > TOP + 5.0:
			_notes.erase(l)
			n.queue_free()


# The model ------------------------------------------------------------------------------------------------------
static func _mat(c: Color, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _put(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _stripes() -> ShaderMaterial:
	# The canopy's pink and cream stripes, round and round
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 a : source_color = vec3(1.0, 0.55, 0.82);
uniform vec3 b : source_color = vec3(1.0, 0.93, 0.8);
void fragment() {
	float s = step(0.5, fract(UV.x * 12.0));
	ALBEDO = mix(a, b, s);
	ROUGHNESS = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func build_model() -> Node3D:
	# The stage faces +Z (its steps and the audience); the canopy and speakers are round the back
	var g := Node3D.new()
	g.name = "Model"
	var body := StaticBody3D.new()
	body.name = "Floor"
	g.add_child(body)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = RADIUS
	cy.height = TOP
	cs.shape = cy
	cs.position.y = TOP * 0.5
	body.add_child(cs)
	# Two steps up at the front
	for k in 2:
		var h := TOP * (k + 1) / 3.0
		var st := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(2.6, h, 0.55)
		st.shape = bx
		st.position = Vector3(0, h * 0.5, RADIUS + 0.55 * (1 - k) + 0.1)
		body.add_child(st)
		var bm := BoxMesh.new()
		bm.size = bx.size
		_put(g, bm, _mat(PURPLE.lightened(0.15)), st.position)
	# The floor: a purple drum with a lighter top and a gold rim
	var base := CylinderMesh.new()
	base.top_radius = RADIUS
	base.bottom_radius = RADIUS + 0.05
	base.height = TOP
	base.radial_segments = 36
	_put(g, base, _mat(PURPLE), Vector3(0, TOP * 0.5, 0))
	var top := CylinderMesh.new()
	top.top_radius = RADIUS - 0.25
	top.bottom_radius = RADIUS - 0.25
	top.height = 0.02
	top.radial_segments = 36
	_put(g, top, _mat(Color(0.95, 0.75, 0.95), 0.35), Vector3(0, TOP + 0.01, 0))
	var star := CylinderMesh.new()
	star.top_radius = 1.0
	star.bottom_radius = 1.0
	star.height = 0.025
	star.radial_segments = 5
	_put(g, star, _mat(Color(1.0, 0.85, 0.35), 0.4, 0.4), Vector3(0, TOP + 0.02, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = RADIUS - 0.08
	rim.outer_radius = RADIUS + 0.06
	rim.rings = 40
	rim.ring_segments = 6
	_put(g, rim, _mat(Color(1.0, 0.82, 0.35), 0.3), Vector3(0, TOP, 0))
	# Footlights round the front of the rim
	var lights: Array = []
	var bulb := SphereMesh.new()
	bulb.radius = 0.13
	bulb.height = 0.26
	bulb.radial_segments = 10
	bulb.rings = 5
	for i in LIGHTS:
		var a := -PI * 0.6 + PI * 1.2 * i / (LIGHTS - 1)
		var m := _mat(LIGHT_COLOURS[i % LIGHT_COLOURS.size()], 0.3, 1.0)
		var mi := _put(g, bulb, m, Vector3(sin(a) * (RADIUS - 0.18), TOP + 0.1, cos(a) * (RADIUS - 0.18)))
		mi.name = "Footlight"
		lights.append([mi, m])
	g.set_meta("lights", lights)
	# Posts round the back and the striped canopy over it all
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.11
	post.height = 4.0
	post.radial_segments = 8
	var post_mat := _mat(Color(1.0, 0.85, 0.4), 0.4)
	for i in 5:
		var a := PI * 0.6 + PI * 0.8 * i / 4.0
		_put(g, post, post_mat, Vector3(sin(a) * (RADIUS - 0.2), TOP + 2.0, cos(a) * (RADIUS - 0.2)))
	var canopy := CylinderMesh.new()
	canopy.top_radius = 0.25
	canopy.bottom_radius = RADIUS + 0.5
	canopy.height = 1.5
	canopy.radial_segments = 48
	canopy.cap_bottom = false
	_put(g, canopy, _stripes(), Vector3(0, TOP + 4.6, 0))
	var bobble := SphereMesh.new()
	bobble.radius = 0.3
	bobble.height = 0.6
	_put(g, bobble, _mat(Color(1.0, 0.85, 0.35), 0.3, 0.3), Vector3(0, TOP + 5.45, 0))
	# A scalloped trim round the canopy's edge
	var scallop := SphereMesh.new()
	scallop.radius = 0.22
	scallop.height = 0.3
	for i in 24:
		var a := i * TAU / 24.0
		_put(g, scallop, _mat(PINK if i % 2 == 0 else CREAM, 0.7), Vector3(sin(a) * (RADIUS + 0.45), TOP + 3.8, cos(a) * (RADIUS + 0.45)))
	# A big speaker each side at the back
	for side in [-1.0, 1.0]:
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 1.5, 0.8)
		var at := Vector3(side * 2.4, TOP + 0.75, -1.9)
		_put(g, box, _mat(Color(0.18, 0.12, 0.25), 0.5), at, Vector3(0, side * -0.5, 0))
		for k in 2:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.26 - 0.1 * k
			cone.bottom_radius = 0.26 - 0.1 * k
			cone.height = 0.05
			cone.radial_segments = 16
			var off := Vector3(0, 0.35 - 0.7 * k, 0.41).rotated(Vector3.UP, side * -0.5)
			_put(g, cone, _mat(Color(0.45, 0.35, 0.6) if k == 0 else PINK, 0.4, 0.2 * k), at + off,
				Vector3(PI * 0.5, side * -0.5, 0))
	# Spotlights (the show's), and the sign over the front
	var spots: Array = []
	for i in 2:
		var o := OmniLight3D.new()
		o.name = "Spot%d" % (i + 1)
		o.omni_range = 7.0
		o.light_energy = 1.5
		o.position = Vector3(0, TOP + 3.2, 0.5)
		o.visible = false
		g.add_child(o)
		spots.append(o)
	g.set_meta("spots", spots)
	var sign := Label3D.new()
	sign.name = "Sign"
	sign.text = "♪ Melody's Stage ♪"
	sign.font_size = 110
	sign.pixel_size = 0.0035
	sign.outline_size = 22
	sign.outline_modulate = Color(0.3, 0.1, 0.35)
	sign.modulate = Color(1.0, 0.9, 0.98)
	sign.position = Vector3(0, TOP + 3.5, RADIUS + 0.3)
	g.add_child(sign)
	return g
