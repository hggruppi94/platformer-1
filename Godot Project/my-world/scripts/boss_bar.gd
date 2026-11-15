class_name BossBar
extends Node3D

# A little meter with a name over a boss, the same as the Gloop King's goo meter (scripts/gloop_king.gd), shared by the
# newer bosses (Grandfather Tock, the Crocodillo boss, the Agent of Chaos). It faces the camera and shows while the
# player is near.
#
#   var bar := BossBar.make(self, "Grandfather Tock", Color(...), 3.2)
#   bar.fill = 0.5

var fill := 1.0:
	set(v):
		if fill > 0.001 and v <= 0.001 and not finished:
			_finish_blow()
		fill = v
var finished := false                      # the last hit's flourish has played (scripts/juice.gd does the feel)
var show_within := 22.0
var _fill: MeshInstance3D
var _boss: Node3D
var _colour := Color.WHITE
var _seen_up := false


static func make(boss: Node3D, title: String, col: Color, height: float, width := 1.6) -> BossBar:
	var bar := BossBar.new()
	bar.name = "BossMeter"
	bar._boss = boss
	boss.add_child(bar)
	bar.position = Vector3(0, height, 0)
	bar._build(title, col, width)
	return bar


func _build(title: String, col: Color, width: float) -> void:
	_colour = col
	var back := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, 0.16)
	back.mesh = q
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.no_depth_test = true
	bm.albedo_color = Color(0.08, 0.05, 0.12)
	bm.render_priority = 1
	back.material_override = bm
	add_child(back)
	var holder := Node3D.new()
	add_child(holder)
	holder.scale = Vector3(width - 0.1, 0.1, 1.0)
	_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, 1.0)
	_fill.mesh = fq
	var fm := bm.duplicate() as StandardMaterial3D
	fm.albedo_color = col
	fm.render_priority = 2
	_fill.position.z = 0.01
	_fill.material_override = fm
	holder.add_child(_fill)
	var label := Label3D.new()
	label.text = title
	label.font_size = 40
	label.pixel_size = 0.01
	label.outline_size = 10
	label.modulate = col.lightened(0.3)
	label.outline_modulate = Color(0.1, 0.05, 0.1)
	label.no_depth_test = true
	label.position.y = 0.28
	add_child(label)
	visible = false


func _process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var down: bool = _boss.get("defeated") == true
	if down and not finished and _seen_up:
		_finish_blow()                                 # (most bosses stop moving their meter once they're popped)
	elif not down:
		_seen_up = true                                # (a boss already beaten when the place loads gets no flourish)
		if fill > 0.001:
			finished = false                           # back up for another go (Tock winds himself up again)
	visible = not down and p != null and p.global_position.distance_to(_boss.global_position) < show_within
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_basis = cam.global_basis
	_fill.scale.x = maxf(0.001, clampf(fill, 0.0, 1.0))
	_fill.position.x = -0.5 * (1.0 - _fill.scale.x)


func _finish_blow() -> void:
	# The last hit on a boss: a moment that feels as big as the fight did, the same for every boss with a meter (each
	# boss's own ending, words and rewards carry on after it). A tiny freeze, a shake, a deep pop and a sparkle, and a
	# shower of gold and the boss's own colour, and a ring of light. Juice leaves out the freeze and shake with Reduce motion.
	finished = true
	if _boss == null or not is_instance_valid(_boss) or not _boss.is_inside_tree():
		return
	var scene := get_tree().current_scene
	var at := _boss.global_position + Vector3(0, 1.4, 0)
	Juice.hitstop(0.1)
	Juice.shake(0.7)
	Juice.kick(Vector2(0, -1), 0.6)
	Juice.rumble(0.6, 0.35, 0.8)
	Juice.blip("pop", 0.55, -3.0)
	Juice.blip("sparkle", 1.0, -5.0)
	Juice.burst(scene, at, Color(1.0, 0.86, 0.38), 40, 0.14, 7.5, 1.3)
	_flash_ring(scene, at)


func _flash_ring(scene: Node, at: Vector3) -> void:
	# A ring of light that rolls out and a spray of glowing gold and boss-coloured stars. Plain shapes moved by one
	# tween, not one-shot particles, so it shows every time (those can drop their first frames: see Juice.dust)
	var root := Node3D.new()
	root.name = "Boss Finish"
	scene.add_child(root)
	root.global_position = at
	var tw := root.create_tween().set_parallel()
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	ring.mesh = torus
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.92, 0.55, 0.9)
	ring.material_override = rm
	root.add_child(ring)
	ring.scale = Vector3.ONE * 0.4
	tw.tween_property(ring, "scale", Vector3(7.0, 2.0, 7.0), 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	var star := SphereMesh.new()
	star.radius = 0.24
	star.height = 0.48
	star.radial_segments = 8
	star.rings = 4
	for i in 22:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.88, 0.4) if i % 3 != 0 else _colour.lightened(0.25)
		var b := MeshInstance3D.new()
		b.mesh = star
		b.material_override = m
		root.add_child(b)
		var a := TAU * i / 22.0 + randf_range(-0.12, 0.12)
		var out := Vector3(cos(a), randf_range(0.25, 1.1), sin(a)) * randf_range(2.6, 4.4)
		var life := randf_range(0.7, 1.0)
		tw.tween_property(b, "position", out, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(b, "scale", Vector3.ONE * 0.2, life).set_ease(Tween.EASE_IN)
		tw.tween_property(m, "albedo_color:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(root.queue_free)
