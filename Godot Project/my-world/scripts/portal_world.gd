extends Node3D

# The root of every portal world (plan items 19 and 19a): Shard Isle (scripts/shard_isle.gd), and the chosen ones'
# home worlds as they're built. It puts in what every world has, at markers its builder made:
#   WayHome    a portal back to the Void, free and open any time (Portals.go_home())
#   TimeStone  a crystal where Remnants buy more time (Portals.add_time())
#   Vein*      small Remnant veins: with Bramble's harvesting tool they give a couple of Remnants once a Void day
# and it catches the player if they fall off the edge (below fall_below), putting them back where they last stood
# safely. A world's own script extends this one and adds its goal, calling Portals.clear(world_id) when it's done.
#
# The same scene is also used as the picture in its portal's preview window (Portals.preview_scene()), with the
# "preview" meta set and no player: then only picture() runs, so nothing gets saved, found or said.

const USE_SPOT := preload("res://scripts/use_spot.gd")
const VEIN_GIVES := 2

@export var world_id := ""
@export var fall_below := -20.0          # below this, the player's fallen off: put them back

var _safe := Vector3.ZERO
var _safe_timer := 0.0
var _way_home: Node3D


func _ready() -> void:
	if has_meta("preview"):
		picture()
		return
	var entrance := get_node_or_null("Entrance") as Node3D
	_safe = entrance.global_position if entrance else Vector3(0, 2, 0)
	_place_shared()
	setup()


func picture() -> void:
	# Override to make the preview look right (show what's there to find, say)
	pass


func setup() -> void:
	# Override: the world's own things
	pass


func info() -> Dictionary:
	return Portals.world(world_id)


func _place_shared() -> void:
	var colour: Color = info().get("colour", Color(0.6, 1.0, 0.8))
	var home := get_node_or_null("WayHome") as Node3D
	if home:
		_way_home = Portals.portal_model(Color(1.0, 0.85, 0.55))
		_way_home.name = "Way Home"
		home.add_child(_way_home)
		var spot := USE_SPOT.make(Vector3(0, 0, -1.2), func() -> String: return "go home to the Void",
			func() -> void: Portals.go_home(), 2.8, 4.2)
		spot.name = "Spot"
		_way_home.add_child(spot)
		var sign := Label3D.new()
		sign.text = "Way home"
		sign.font_size = 64
		sign.pixel_size = 0.01
		sign.outline_size = 12
		sign.modulate = Color(1, 0.95, 0.75)
		sign.position = Vector3(0, 5.6, 0)
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_way_home.add_child(sign)
		_way_home.rotation.y = PI                  # facing in, so you see its front as you turn round
	var stone := get_node_or_null("TimeStone") as Node3D
	if stone:
		var g := time_stone_model(colour)
		g.name = "Time Stone"
		stone.add_child(g)
		var spot := USE_SPOT.make(Vector3.ZERO, _stone_offer, _use_stone, 2.2, 2.6)
		spot.name = "Spot"
		g.add_child(spot)
	for m in get_children():
		if m is Marker3D and str(m.name).begins_with("Vein"):
			var v := Remnants.vein_model()
			v.scale = Vector3.ONE * 0.6
			v.name = "Remnant Vein"
			m.add_child(v)
			var id := str(m.name)
			var spot := USE_SPOT.make(Vector3.ZERO, _vein_offer.bind(id), _use_vein.bind(id), 2.2, 2.2)
			spot.name = "Spot"
			v.add_child(spot)
			_show_vein(m)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or has_meta("preview"):
		return
	if player.global_position.y < fall_below:
		player.global_position = _safe + Vector3(0, 0.5, 0)
		player.velocity = Vector3.ZERO
		Game.message("Whoops! The island's magic caught you and floated you back up.")
		Audio.play("boing", -6.0)
		return
	# Remember the last good place to stand (on the ground and not moving down)
	_safe_timer -= delta
	if _safe_timer <= 0.0 and player.is_on_floor():
		_safe_timer = 0.5
		_safe = player.global_position


# The Time Stone ----------------------------------------------------------------
func _stone_offer() -> String:
	return "add a minute of portal time (%s)" % Remnants.words(1) if Remnants.count > 0 else "look at the Time Stone"


func _use_stone() -> void:
	if Remnants.count <= 0:
		Game.message("The Time Stone hums. Give it a Remnant and it holds the portal open a minute longer. (You have none yet.)")
		Audio.play("ui_back", -8.0)
		return
	if Portals.add_time(1):
		var g := get_node_or_null("TimeStone/Time Stone") as Node3D
		if g:
			Fx.burst(self, g.global_position + Vector3(0, 1.4, 0), Color(0.55, 1.0, 0.35), 16, 0.06, 2.5, -2.0, 0.8)
		Juice.blip("chime", 1.3, -6.0)


# Remnant veins ----------------------------------------------------------------
func _vein_key(id: String) -> String:
	return "vein_%s_day%d" % [id, Clock.day]


func vein_ready(id: String) -> bool:
	return not Portals.has_found(world_id, _vein_key(id))


func _vein_offer(id: String) -> String:
	if not Remnants.has_tool():
		return "look at the glowing crystals"
	return "harvest Remnants" if vein_ready(id) else ""


func _use_vein(id: String) -> void:
	if not Remnants.has_tool():
		Game.message("Remnant crystals! Too deep to pull out by hand. Bramble's harvesting tool could do it.")
		Audio.play("ui_back", -8.0)
		return
	if not vein_ready(id):
		return
	Portals.note_found(world_id, _vein_key(id))
	Remnants.add(VEIN_GIVES, "Remnants!")
	var m := get_node_or_null(id) as Node3D
	if m:
		Fx.burst(self, m.global_position + Vector3(0, 1.0, 0), Color(0.55, 1.0, 0.35), 20, 0.08, 3.5, -3.0, 0.9)
		_show_vein(m)
	Juice.blip("sparkle", 1.4, -6.0)


func _show_vein(m: Node3D) -> void:
	var v := m.get_node_or_null("Remnant Vein") as Node3D
	if v == null:
		return
	var full := vein_ready(str(m.name))
	(v.get_node("Crystals") as Node3D).visible = full
	(v.get_node("Stubs") as Node3D).visible = not full
	(v.get_node("Glow") as OmniLight3D).visible = full


# Looks ----------------------------------------------------------------------
static func time_stone_model(colour: Color) -> Node3D:
	# A waist-high obsidian stone with an hourglass-shaped crystal floating over it
	var g := Node3D.new()
	var base := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.45
	c.bottom_radius = 0.6
	c.height = 1.0
	c.radial_segments = 6
	base.mesh = c
	base.material_override = Remnants.obsidian_mat()
	base.position.y = 0.5
	g.add_child(base)
	var gem := Remnants.crystal_mat()
	gem.albedo_color = colour
	gem.emission = colour
	for k in 2:
		var half := MeshInstance3D.new()
		half.mesh = Remnants.crystal_mesh(0.28, 0.45)
		half.material_override = gem
		half.position.y = 1.55 + (0.22 if k == 0 else -0.22)
		half.rotation.x = 0.0 if k == 0 else PI
		g.add_child(half)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.55
	cy.height = 1.0
	cs.shape = cy
	cs.position.y = 0.5
	body.add_child(cs)
	g.add_child(body)
	var sign := Label3D.new()
	sign.text = "Time Stone"
	sign.font_size = 40
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.position.y = 2.3
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	g.add_child(sign)
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = 1.0
	light.omni_range = 4.0
	light.position.y = 1.6
	g.add_child(light)
	return g
