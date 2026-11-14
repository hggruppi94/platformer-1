extends Node3D

# The root of every portal world (plan items 19 and 19a): Shard Isle (scripts/shard_isle.gd), and the chosen ones'
# home worlds as they're built. It puts in what every world has, at markers its builder made:
#   WayHome    a crack back to the Void, open any time: jump in (Portals.go_home())
#   TimeStone  nothing now: it was a crystal where Remnants bought more time, and there's no time limit since
#              12 Nov 2026 (Hayden). The builders' markers are left alone.
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
	var home := get_node_or_null("WayHome") as Node3D
	if home:
		# A crack in the ground, gold like the way home always was: jump in to go back to the Void. It sits on the
		# ground under the marker (the ground's found at play time) and the ground's cut away under it.
		_way_home = Portals.portal_model(Color(1.0, 0.85, 0.55), _jump_home)
		_way_home.name = "Way Home"
		home.add_child(_way_home)
		_way_home.global_position = _ground_under(home.global_position)
		Portals.CRACK.sink(_way_home, self)
		Portals.CRACK.add_prompt(_way_home, func() -> String: return "to go home", "Spot")
		var sign := Label3D.new()
		sign.text = "Way home"
		sign.font_size = 64
		sign.pixel_size = 0.01
		sign.outline_size = 12
		sign.modulate = Color(1, 0.95, 0.75)
		sign.position = Vector3(0, 2.6, 0)
		sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_way_home.add_child(sign)
		_way_home.rotation.y = PI                  # its edge spot facing in, towards the world
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


func _jump_home() -> void:
	Portals.go_home()


func _ground_under(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 20, 0), p + Vector3(0, -30, 0))
	var hit := space.intersect_ray(q)
	return hit.position if hit else p


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player == null or has_meta("preview"):
		return
	if is_instance_valid(_way_home) and not _way_home.has_meta("falling") and player.global_position.y < _way_home.global_position.y - 0.8 \
			and Vector2(player.global_position.x - _way_home.global_position.x,
				player.global_position.z - _way_home.global_position.z).length() < Portals.CRACK.R:
		Portals.CRACK.fall_in(_way_home, player, _jump_home)     # (down the way home however they got in)
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
		Game.message("Too deep! Bramble's tool could do it.")
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

