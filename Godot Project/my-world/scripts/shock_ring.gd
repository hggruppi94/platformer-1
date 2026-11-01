class_name ShockRing
extends MeshInstance3D

# A ring that rolls out across the ground from a boss (Grandfather Tock's chimes, the Crocodillo boss's slams, the Agent
# of Chaos's chaos bursts). It only bumps the player if they're standing on the ground right where the ring's edge is
# passing, so jumping over it is always the trick. Kid-safe: a bump, like touching a Gloop.
#
#   ShockRing.spawn(parent, at, reach, colour, damage, time)

var reach := 6.0
var time := 0.8
var damage := 2
var colour := Color(1, 1, 1)
var _t := 0.0
var _hit := false
var _mat: StandardMaterial3D


static func spawn(parent: Node, at: Vector3, reach_m: float, col: Color, dmg := 2, secs := 0.8) -> ShockRing:
	var r := ShockRing.new()
	r.name = "ShockRing"
	r.reach = reach_m
	r.colour = col
	r.damage = dmg
	r.time = secs
	parent.add_child(r)
	r.global_position = at + Vector3(0, 0.15, 0)
	return r


func _ready() -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.88
	tm.outer_radius = 1.0
	tm.rings = 56
	tm.ring_segments = 8
	mesh = tm
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(colour.r, colour.g, colour.b, 0.85)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scale = Vector3(0.3, 3.0, 0.3)


func radius() -> float:
	return lerpf(0.3, reach, clampf(_t / time, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_t += delta
	var r := radius()
	scale = Vector3(r, 3.0, r)
	_mat.albedo_color.a = 0.85 * (1.0 - clampf((_t - time * 0.6) / (time * 0.4), 0.0, 1.0))
	if not _hit:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and p.is_on_floor() and not p.is_invulnerable():
			var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
			if absf(d - r) < 0.9 and absf(p.global_position.y - 0.8 - global_position.y) < 1.5:
				_hit = true
				p.hurt(damage, global_position)
	if _t >= time:
		queue_free()
