class_name BossBar
extends Node3D

# A little meter with a name over a boss, the same as the Gloop King's goo meter (scripts/gloop_king.gd), shared by the
# newer bosses (Grandfather Tock, the Crocodillo boss, the Agent of Chaos). It faces the camera and shows while the
# player is near.
#
#   var bar := BossBar.make(self, "Grandfather Tock", Color(...), 3.2)
#   bar.fill = 0.5

var fill := 1.0
var show_within := 22.0
var _fill: MeshInstance3D
var _boss: Node3D


static func make(boss: Node3D, title: String, col: Color, height: float, width := 1.6) -> BossBar:
	var bar := BossBar.new()
	bar.name = "BossMeter"
	bar._boss = boss
	boss.add_child(bar)
	bar.position = Vector3(0, height, 0)
	bar._build(title, col, width)
	return bar


func _build(title: String, col: Color, width: float) -> void:
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
	visible = not down and p != null and p.global_position.distance_to(_boss.global_position) < show_within
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_basis = cam.global_basis
	_fill.scale.x = maxf(0.001, clampf(fill, 0.0, 1.0))
	_fill.position.x = -0.5 * (1.0 - _fill.scale.x)
