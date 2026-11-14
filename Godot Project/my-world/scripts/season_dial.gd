extends Node

# The Season Dial (story flag 48: Hayden asked whether seasons are a progression or changed at will; the pick was
# both). Each season is still unlocked once, by mending its portal world in the Void (Clock.seasons_open,
# Portals.open_seasons()), and from then on the player can switch Stars Hollow to any season they've opened, here,
# so a season's things (its quest, its jobs, its fair) are never four weeks away. Left alone, the calendar runs on
# as before.
#
# The dial is an old stone sundial that has grown up out of the old oak's roots, its brass face split into the four
# seasons. It only shows once there's a second season to pick (a new game has autumn alone) and the oak is awake.
# Walk up, Interact, pick a season: the pointer spins, the screen washes over in that season's colour, and Stars
# Hollow comes back in the new season on the same date and weekday (Clock.dial_to(): the calendar moves on, never
# back). The town is loaded again where the player stands, so every seasonal thing (scripts/seasons.gd, the
# seasonal quests' props, the fair, the sun) is set up fresh, just as on arriving.
#
# A node under the EarthTown autoload ("EarthTown/SeasonDial"), so it lasts across that reload.

const EARTH := "res://scenes/earth/earth.tscn"
const DIAL_AT := Vector2(-14.0, 5.0)     # beside the old oak (PORTAL_AT (-10, 10)), on the grass off every path
const FACE_R := 0.62
const FACE_TILT := 0.6                   # radians: the face leans back so you can read it standing in front
const TOP := 1.0                         # height of the face's middle
const ORDER := ["spring", "summer", "autumn", "winter"]
const COLOURS := {"spring": Color(1.0, 0.6, 0.78), "summer": Color(1.0, 0.86, 0.3),
	"autumn": Color(1.0, 0.52, 0.18), "winter": Color(0.62, 0.84, 1.0)}
const FROST := Color(0.42, 0.46, 0.55)   # a locked season's quarter, frosted over and dim
const SPIN_TIME := 1.6
const WASH_IN := 0.45
const WASH_OUT := 0.8

var turning := false
var turns := 0                           # how many times it's been turned (this run: for tests)
var _holder: Node3D
var _pointer: Node3D
var _glow: OmniLight3D
var _wash: ColorRect
var _layer: CanvasLayer
var _reloading := false
var _pending_hello := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Dialogue.finished.connect(_on_talked)
	_layer = CanvasLayer.new()
	_layer.layer = 85                    # over the HUD, under the loading screen
	add_child(_layer)
	_wash = ColorRect.new()
	_wash.name = "Season Wash"
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash.visible = false
	_layer.add_child(_wash)
	_on_scene_changed.call_deferred()


static func available() -> bool:
	# Two seasons or more to choose from, and Stars Hollow's oak awake (not in the First Night's early steps)
	return Clock.seasons_open.size() >= 2 and HummingOak.awake()


static func spot() -> Vector3:
	return Vector3(DIAL_AT.x, EarthLand.height(DIAL_AT.x, DIAL_AT.y), DIAL_AT.y)


static func angle_of(season: String) -> float:
	# Where a season's quarter sits on the face, going round clockwise from the top
	return -ORDER.find(season) * PI / 2.0


func _on_scene_changed() -> void:
	_holder = null
	_pointer = null
	_glow = null
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != EARTH:
		return
	if _reloading:
		_reloading = false
		_wash_out()
		if _pending_hello != "":
			_say_later(_pending_hello)
			_pending_hello = ""
	if not available() or scene.get_node_or_null("Season Dial") != null:
		return
	_build(scene)
	if not Dialogue.flags.has("season_dial_seen"):
		Dialogue.flags["season_dial_seen"] = true
		_tell_new.call_deferred()


func _say_later(text: String) -> void:
	await get_tree().create_timer(0.6).timeout
	Game.message(text)


func _tell_new() -> void:
	await get_tree().create_timer(2.0).timeout
	Game.message("A Season Dial by the old oak!")


# The model -------------------------------------------------------------------------------------------------------
func _build(scene: Node) -> void:
	_holder = Node3D.new()
	_holder.name = "Season Dial"
	scene.add_child(_holder)
	_holder.global_position = spot()
	_holder.rotation.y = atan2(-DIAL_AT.x, -DIAL_AT.y)        # its face turned to the green's middle
	var stone := _mat(Color(0.62, 0.6, 0.58), 0.9)
	var bark := _mat(Color(0.35, 0.24, 0.16), 0.95)
	var brass := _mat(Color(0.86, 0.66, 0.3), 0.35, 0.8)
	# The pedestal: a stone column on a step, with the oak's roots curling up round it
	_add(_holder, _cyl(0.55, 0.6, 0.14), stone, Vector3(0, 0.07, 0))
	_add(_holder, _cyl(0.24, 0.32, TOP - 0.2), stone, Vector3(0, 0.14 + (TOP - 0.2) / 2.0 - 0.07, 0))
	for k in 5:
		var a := k * TAU / 5.0 + 0.4
		var root := _add(_holder, _cyl(0.035, 0.07, 0.75), bark, Vector3(cos(a) * 0.36, 0.3, sin(a) * 0.36))
		root.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	var body := StaticBody3D.new()
	body.name = "Pedestal"
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = TOP + 0.1
	cs.shape = shape
	cs.position.y = (TOP + 0.1) / 2.0
	body.add_child(cs)
	_holder.add_child(body)
	# The face: four quarters in the seasons' colours (a locked one is frosted grey), each with its sign
	var face := Node3D.new()
	face.name = "Face"
	face.position = Vector3(0, TOP, 0)
	face.rotation.x = FACE_TILT
	_holder.add_child(face)
	_add(face, _cyl(FACE_R + 0.08, FACE_R + 0.1, 0.1), stone, Vector3(0, -0.04, 0))
	for s in ORDER:
		var open := Clock.season_open(str(s))
		var c: Color = COLOURS[s] if open else FROST
		var quarter := MeshInstance3D.new()
		quarter.name = "Quarter " + str(s).capitalize()
		quarter.mesh = _wedge(angle_of(s), FACE_R)
		var qm := _mat(c, 0.6 if open else 0.3, 0.0, 0.6 if open else 0.0)
		qm.cull_mode = BaseMaterial3D.CULL_DISABLED
		quarter.material_override = qm
		quarter.position.y = 0.02
		face.add_child(quarter)
		_sign(face, str(s), open)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = FACE_R - 0.02
	torus.outer_radius = FACE_R + 0.06
	rim.mesh = torus
	rim.material_override = brass
	rim.position.y = 0.03
	face.add_child(rim)
	# The pointer, turning about the face's middle
	_pointer = Node3D.new()
	_pointer.name = "Pointer"
	_pointer.position.y = 0.05
	face.add_child(_pointer)
	var arm := _add(_pointer, _box(Vector3(0.07, 0.03, FACE_R * 0.8)), brass, Vector3(0, 0, -FACE_R * 0.4))
	arm.name = "Arm"
	var tip := _add(_pointer, _cyl(0.0, 0.08, 0.14), brass, Vector3(0, 0, -FACE_R * 0.82))
	tip.rotation.x = -PI / 2.0
	_add(_pointer, _cyl(0.07, 0.07, 0.06), brass, Vector3.ZERO)
	_pointer.rotation.y = angle_of(Clock.season())
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = COLOURS[Clock.season()]
	_glow.light_energy = 0.6
	_glow.omni_range = 2.5
	_glow.position = Vector3(0, TOP + 1.0, 0.7)
	_holder.add_child(_glow)
	var label := Label3D.new()
	label.name = "Name"
	label.text = "Season Dial"
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 12
	label.modulate = Color(1, 0.92, 0.7)
	label.outline_modulate = Color(0.2, 0.12, 0.08)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, TOP + 0.75, 0)
	_holder.add_child(label)
	var use := (load("res://scripts/use_spot.gd") as GDScript).call("make", Vector3.ZERO,
		func() -> String: return "" if turning or Dialogue.is_active() else "turn the Season Dial",
		ask, 1.8, TOP + 1.1) as Area3D
	use.name = "Spot"
	_holder.add_child(use)


func _sign(face: Node3D, s: String, open: bool) -> void:
	# A little picture in the middle of each quarter: blossom, sun, leaf, snowflake
	var at := Vector3(0, 0.05, -FACE_R * 0.55).rotated(Vector3.UP, angle_of(s))
	var c := Color(1, 1, 1) if open else Color(0.6, 0.64, 0.72)
	var g := Node3D.new()
	g.name = "Sign " + s.capitalize()
	g.position = at
	face.add_child(g)
	match s:
		"spring":
			for k in 5:
				var a := k * TAU / 5.0
				_add(g, _ball(0.04), _mat(Color(1, 0.85, 0.92) if open else c), Vector3(cos(a) * 0.05, 0, sin(a) * 0.05))
			_add(g, _ball(0.03), _mat(Color(1, 0.85, 0.3) if open else c), Vector3.ZERO)
		"summer":
			_add(g, _ball(0.06), _mat(Color(1, 0.95, 0.5) if open else c, 0.5, 0.0, 1.0 if open else 0.0), Vector3.ZERO)
			for k in 8:
				var a := k * TAU / 8.0
				var ray := _add(g, _box(Vector3(0.015, 0.015, 0.05)), _mat(Color(1, 0.95, 0.5) if open else c),
					Vector3(cos(a) * 0.1, 0, sin(a) * 0.1))
				ray.rotation.y = -a + PI / 2.0
		"autumn":
			var leaf := _add(g, _ball(0.07), _mat(Color(0.85, 0.3, 0.1) if open else c), Vector3.ZERO)
			leaf.scale = Vector3(0.6, 0.25, 1.0)
			leaf.rotation.y = 0.6
		"winter":
			for k in 3:
				var bar := _add(g, _box(Vector3(0.02, 0.02, 0.18)), _mat(Color(0.3, 0.55, 0.95) if open else c), Vector3.ZERO)
				bar.rotation.y = k * PI / 3.0


# Turning it ------------------------------------------------------------------------------------------------------
func lines() -> Array:
	# What the dial says, and the seasons it offers: every open one but this one
	var now := Clock.season()
	var out: Array = ["The Season Dial points to %s." % now.capitalize()]
	var choice: Array = []
	for s in ORDER:
		if s != now and Clock.season_open(str(s)):
			choice.append({"text": "Turn it to %s." % str(s).capitalize(), "set": "dial_" + str(s), "say": false})
	var locked := ORDER.filter(func(s) -> bool: return not Clock.season_open(str(s)))
	if not locked.is_empty():
		out.append("The %s quarter%s frosted over. %s still locked away in the Void." % [
			" and ".join(locked.map(func(s) -> String: return str(s).capitalize())),
			" is" if locked.size() == 1 else "s are", "It's" if locked.size() == 1 else "They're"])
	choice.append({"text": "Leave it as it is.", "say": false})
	out.append({"choice": choice})
	return out


func ask() -> void:
	if turning or Dialogue.is_active() or _holder == null:
		return
	Dialogue.say(_holder.get_node("Spot") as Node3D, "Season Dial", lines(), "season_dial")


func _on_talked(id: String) -> void:
	if id != "season_dial":
		return
	var pick := ""
	for s in ORDER:
		if Dialogue.flags.has("dial_" + str(s)):
			pick = str(s)
			Dialogue.flags.erase("dial_" + str(s))
	if pick != "":
		turn_to(pick)


func turn_to(season: String, quick := false) -> bool:
	# Spin the pointer round to the season, wash the screen over in its colour, and bring Stars Hollow back in it
	if turning or season == Clock.season() or not Clock.season_open(season):
		return false
	turning = true
	Game.hold_controls(&"season_dial", true)
	if _pointer and not quick:
		var to := angle_of(season)
		var from := _pointer.rotation.y
		while to > from - TAU:                    # round once and a bit more, clockwise, like winding a clock
			to -= TAU
		var tw := create_tween()
		tw.tween_property(_pointer, "rotation:y", to, SPIN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		var tg := create_tween()
		tg.tween_property(_glow, "light_color", COLOURS[season], SPIN_TIME)
		tg.parallel().tween_property(_glow, "light_energy", 2.5, SPIN_TIME)
		for k in 6:
			get_tree().create_timer(k * SPIN_TIME / 6.0).timeout.connect(func() -> void: Juice.blip("tick", 1.0 + k * 0.08))
		Juice.rumble(0.2, SPIN_TIME * 0.6)
		await tw.finished
		Juice.blip("chime")
		Juice.shake(0.25)
	_wash.color = Color(COLOURS[season], 0.0)
	_wash.visible = true
	var wi := create_tween()
	wi.tween_property(_wash, "color:a", 1.0, 0.05 if quick else WASH_IN)
	await wi.finished
	_change(season)
	return true


func _change(season: String) -> void:
	Clock.dial_to(season)
	turns += 1
	Dialogue.flags["season_dial_turned"] = true      # (Nina has something to say about that: dialogue/nina_earth.json)
	_fix_jobs()
	Game.hold_controls(&"season_dial", false)
	turning = false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if player == null or scene == null or scene.scene_file_path != EARTH:
		_wash_out()
		return
	var yaw := (player.get_node("Visual") as Node3D).rotation.y if player.has_node("Visual") else 0.0
	_reloading = true
	_pending_hello = _hello(season)
	Game.go_to_point(EARTH, player.global_position, yaw)


func _hello(season: String) -> String:
	return {"spring": "Spring!",
		"summer": "Summer!",
		"autumn": "Autumn!",
		"winter": "Winter!"}.get(season, "A new season in Stars Hollow!")


func _fix_jobs() -> void:
	# Today's notice board jobs were picked for the old season (snowmen, sandcastles...): any finished ones are paid,
	# and the board picks three for the new season
	var jobs := get_node_or_null("/root/EarthJobs")
	if jobs == null or not jobs.call("is_live"):
		return
	jobs.call("_pay_finished", "season")
	jobs.call("roll", hash("earth_jobs:%d:%s" % [Clock.earth_day(), Clock.season()]))


func _wash_out() -> void:
	if not _wash.visible:
		return
	await get_tree().create_timer(0.2).timeout
	var tw := create_tween()
	tw.tween_property(_wash, "color:a", 0.0, WASH_OUT)
	await tw.finished
	_wash.visible = false


# Little helpers --------------------------------------------------------------------------------------------------
func _mat(c: Color, rough := 0.8, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 20
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _wedge(mid: float, r: float) -> ArrayMesh:
	# A quarter of a flat disc, centred on the angle mid (0 points to -Z, the dial's top), facing up
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var steps := 10
	var a0 := mid - PI / 4.0 + 0.02
	var a1 := mid + PI / 4.0 - 0.02
	for k in steps:
		var p := lerpf(a0, a1, float(k) / steps)
		var q := lerpf(a0, a1, float(k + 1) / steps)
		st.add_vertex(Vector3(0, 0, 0))
		st.add_vertex(Vector3(0, 0, -r).rotated(Vector3.UP, q))
		st.add_vertex(Vector3(0, 0, -r).rotated(Vector3.UP, p))
	return st.commit()
