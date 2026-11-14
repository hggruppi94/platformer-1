extends RefCounted

# Bumps and boinks (Hayden, 14 Nov 2026: "sensory boinks and bumps when you collide with surfaces"). After the hero
# moves, on foot (scenes/player/player.gd) or on a ride (scenes/player/skate.gd), this looks at what she ran into from
# the side or bonked her head on, and how fast she was going straight into it. A real knock (not leaning on a wall,
# not a kerb she rolls up) bounces her back off it a little (Hayden: "a sort of bounce with a puff of smoke"), with a
# squash, a puff of smoke at the spot, a sound that fits the thing (a woody bonk, a
# stony clunk, a springy boink off a mushroom or a friend, a clink off ice), a nudge of the camera towards it and a
# buzz of the controller, all scaled by how hard. Landings already have their own (player.gd _sounds, skate.gd _land).
#
# Gentle on purpose: the bounce is small (and only for a real knock), there's a short wait between bumps so sliding
# along a wall doesn't rattle, and Settings > Assist has "Bumps and boinks" (off: none of this), "Screen shake" and "Rumble
# strength". Reduce motion stops the camera part (scripts/juice.gd).
#
#   const Bumps := preload("res://scripts/bumps.gd")
#   Bumps.after_slide(body, velocity_before, model, 3.5, 11.0)     # right after move_and_slide(); bounces body.velocity
#
# tools/test_bumps.gd checks it.

const WALL_MAX_Y := 0.6            # a contact this flat or steeper (normal.y below this) is a wall, not ground
const HEAD_Y := -0.6               # ...and a normal pointing down this much is a ceiling over her head
const WAIT_MS := 300               # the shortest gap between two bumps
const SOUNDS := {                  # surface -> [Juice.blip kind, pitch]
	"wood": ["bonk", 1.0], "stone": ["clunk", 1.0], "grass": ["thud", 1.25], "crystal": ["clink", 1.0],
	"metal": ["clink", 0.7], "soft": ["boink", 1.0], "water": ["squish", 1.0],
}
const PUFFS := {
	"wood": Color(0.78, 0.6, 0.42, 0.8), "stone": Color(0.78, 0.74, 0.84, 0.8), "grass": Color(0.62, 0.82, 0.52, 0.8),
	"crystal": Color(0.7, 0.92, 1.0, 0.9), "metal": Color(1.0, 0.86, 0.45, 0.9), "soft": Color(1.0, 0.72, 0.9, 0.85),
	"water": Color(0.6, 0.82, 1.0, 0.8),
}
const STARS := Color(1.0, 0.9, 0.35)
const SMOKE := Color(0.86, 0.83, 0.93, 0.9)       # a soft lilac grey, so it shows on the pale ground too
const BOUNCE := 0.45               # how much of the speed into the wall comes back out as a bounce
const BOUNCE_OUT := 1.6            # ...plus this push straight off it (m/s), more for a harder knock
const SPRINGY := 1.6               # soft things (mushrooms, hay, friends) bounce you further


static func _auto(name: String) -> Node:
	# The autoloads by name, not as identifiers, so this script also compiles where a test preloads it before they exist
	return (Engine.get_main_loop() as SceneTree).root.get_node(name)


static func _juice() -> Node:
	return _auto("Juice")


static func after_slide(body: CharacterBody3D, before: Vector3, model: Node3D, min_speed: float, full_speed: float,
		feet := 0.8, step := 0.36, wall_max_y := WALL_MAX_Y, bounce := 1.0) -> float:
	# Call straight after move_and_slide(), with the velocity she had going into it. Gives back how hard the bump
	# was (0..1), or -1 when there wasn't one.
	if body == null or not is_instance_valid(body) or not bool(_auto("Settings").get("bumps")):
		return -1.0
	var best := 0.0
	var hit: KinematicCollision3D
	var head := false
	var feet_y := body.global_position.y - feet
	for i in body.get_slide_collision_count():
		var c := body.get_slide_collision(i)
		var n := c.get_normal()
		if n.y >= wall_max_y:
			continue                                         # ground: landings have their own
		var is_head := n.y <= HEAD_Y
		if not is_head and c.get_position().y - feet_y < step:
			continue                                         # a kerb or a step at her feet: rolled or stepped up
		var who := c.get_collider() as Node
		if who and (who.is_in_group("enemies") or who.is_in_group("bosses")):
			continue                                         # enemies have their own hits (a stomp, a roll pops them)
		var into := -before.dot(n)
		if into > best:
			best = into
			hit = c
			head = is_head
	if hit == null or best < min_speed:
		return -1.0
	var now := Time.get_ticks_msec()
	if now < int(body.get_meta("bump_wait", 0)):
		return -1.0
	body.set_meta("bump_wait", now + WAIT_MS)
	var s := clampf((best - min_speed) / maxf(full_speed - min_speed, 0.01), 0.0, 1.0)
	var kind := Surfaces.wall_kind(hit.get_collider() as Node)
	bounce_off(body, before, hit.get_normal(), s, kind, head, bounce)
	bump(body, hit.get_position(), hit.get_normal(), s, kind, model, head)
	return s


static func bounce_off(body: CharacterBody3D, before: Vector3, normal: Vector3, s: float, kind: String, head := false,
		scale := 1.0) -> void:
	# Bounce back off what she hit: keep the speed along it, send some of the speed into it back out, and a push off
	var n := normal
	if not head:
		n.y = 0.0
		if n.length() < 0.01:
			return
		n = n.normalized()
	var into := maxf(-before.dot(n), 0.0)
	var k := (SPRINGY if kind == "soft" else 1.0) * scale
	var v := body.velocity
	v -= n * minf(v.dot(n), 0.0)                             # nothing still going into it
	v += n * (into * BOUNCE + BOUNCE_OUT * (0.5 + s)) * k
	if head:
		v.y = minf(v.y, -1.0)                                # bonk: back down she comes
	body.velocity = v
	body.set_meta("bump_push", n)


static func bump(body: Node3D, at: Vector3, normal: Vector3, s: float, kind: String, model: Node3D, head := false) -> void:
	# The feedback itself, for a bump of strength s (0..1) against a `kind` surface
	body.set_meta("last_bump", {"kind": kind, "strength": s, "head": head, "at": Engine.get_physics_frames()})
	var sound: Array = SOUNDS.get(kind, SOUNDS.stone)
	# A softer thing sounds a bit higher and springier; a harder knock a bit lower and louder
	_juice().blip(sound[0], float(sound[1]) * (1.08 - 0.16 * s) * randf_range(0.95, 1.05), lerpf(-14.0, -6.0, s))
	if model:
		_juice().squash(model, (0.16 if kind == "soft" else 0.1) + 0.14 * s, 0.24 if kind == "soft" else 0.2)
	var parent := body.get_parent()
	_juice().burst(parent, at + normal * 0.1, PUFFS.get(kind, PUFFS.stone), 5 + int(9 * s), 0.05 + 0.04 * s, 1.2 + 2.0 * s, 0.4)
	# ...and a puff of smoke where she hit, rolling out round the spot
	smoke(parent, at + normal * 0.25, normal, 0.3 + 0.7 * s)
	if head or s > 0.75:
		_juice().burst(parent, body.global_position + Vector3.UP * 1.1, STARS, 6, 0.05, 1.6, 0.6)   # little stars: bonk!
	# The camera lurches a touch towards what she hit (and down for her head)
	var cam := body.get_viewport().get_camera_3d() if body.get_viewport() else null
	var side := 0.0
	if cam:
		side = -normal.dot(cam.global_transform.basis.x)
	var dir := Vector2(side, 1.0 if head else 0.35)
	_juice().kick(dir, 0.25 + 0.6 * s)
	if s > 0.55:
		_juice().shake(0.12 + 0.2 * s)
	_juice().rumble(0.2 + 0.4 * s, 0.07 + 0.08 * s, 0.35 * s)


static func smoke(parent: Node, at: Vector3, normal: Vector3, amount: float) -> void:
	# A little cloud of cartoon smoke: soft white balls that billow out from the wall and up, then fade. Like
	# Juice.dust, a few plain spheres on a tween, so the whole puff shows at once.
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var a := clampf(amount, 0.0, 1.0)
	var root := Node3D.new()
	root.name = "Bump Smoke"
	parent.add_child(root)
	root.global_position = at
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SMOKE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	var out := normal if normal.length() > 0.01 else Vector3.UP
	var side := out.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(out).normalized()
	var n := 5 + int(5 * a)
	var size := 0.32 + 0.3 * a
	var life := 0.45 + 0.25 * a
	var tw := root.create_tween().set_parallel()
	for i in n:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(puff)
		var ang := TAU * (i + randf() * 0.5) / n
		var to := (side * cos(ang) + up * sin(ang)) * (0.45 + 0.6 * a) * randf_range(0.7, 1.0) + out * randf_range(0.1, 0.35) \
			+ Vector3.UP * randf_range(0.05, 0.3)
		puff.scale = Vector3.ONE * size * 0.3
		tw.tween_property(puff, "position", to, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * size * randf_range(0.8, 1.25), life * 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "scale", Vector3.ONE * size * 0.15, life * 0.65).set_delay(life * 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)
