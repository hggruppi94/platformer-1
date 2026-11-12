extends Node3D

# A little crack that opens in the ground for a visitor coming into the Void or going home from it (Hayden, 12 Nov
# 2026: "void townsfolk also have to come and go. no one can stay indefinitely except rook, dash and rex"). The lore
# bible says the cracks ARE the doors between worlds: holes in the ground you go through. So when a friend from
# another world (or Mr. Palmer) heads home at night, a glowing crack zigzags open at their feet, they drop through it
# in a flash, and it zips shut; in the morning one opens and they pop up out of it.
#
# No class_name: preload it (scripts/routine.gd does, as VISITOR_CRACK). Made of plain meshes moved by a tween, so it
# costs nothing when it isn't playing and frees itself when it's done.
#
#   VISITOR_CRACK.open(parent, feet_position, going_home)

const LILAC := Color(0.8, 0.6, 1.0)
const GLOW := Color(1.0, 0.85, 1.0)
const LENGTH := 3.0                       # metres from end to end of the crack
const OPEN := 0.45                        # seconds to open
const HOLD := 0.7                         # seconds it stays open
const SHUT := 0.5                         # seconds to zip shut

var going := true                         # true: someone going home through it, false: someone arriving

var _bits: Array[MeshInstance3D] = []


static func open(parent: Node, pos: Vector3, going_home: bool) -> Node3D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var crack: Node3D = (load("res://scripts/visitor_crack.gd") as GDScript).new()
	crack.name = "Visitor Crack"
	crack.set("going", going_home)
	parent.add_child(crack)
	crack.global_position = pos + Vector3(0, 0.04, 0)
	crack.rotation.y = randf() * TAU
	return crack


func _ready() -> void:
	add_to_group("visitor_crack")
	_build()
	_play()


func _build() -> void:
	# A zigzag of thin glowing slabs lying flat on the ground, and a soft light in the middle
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LILAC
	mat.emission_enabled = true
	mat.emission = GLOW
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.02, 0.14)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var points := [Vector2(-LENGTH / 2, 0)]
	var steps := 5
	for i in range(1, steps):
		points.append(Vector2(-LENGTH / 2 + LENGTH * i / steps, 0.22 * (1 if i % 2 else -1)))
	points.append(Vector2(LENGTH / 2, 0))
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var mid := (a + b) / 2
		var along := b - a
		for layer in [[dark, 0.55, 0.0], [mat, 0.24, 0.015]]:
			var box := BoxMesh.new()
			box.size = Vector3(along.length() + 0.06, 0.02, float(layer[1]))
			var m := MeshInstance3D.new()
			m.mesh = box
			m.material_override = layer[0]
			m.position = Vector3(mid.x, float(layer[2]), mid.y)
			m.rotation.y = -along.angle()
			m.scale = Vector3(1, 1, 0.01)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			_bits.append(m)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(LILAC, 0.45)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	var col := CylinderMesh.new()
	col.top_radius = 0.5
	col.bottom_radius = 0.35
	col.height = 2.6
	beam.mesh = col
	beam.material_override = beam_mat
	beam.position = Vector3(0, 1.3, 0)
	beam.scale = Vector3(1, 0.01, 1)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = LILAC
	light.light_energy = 0.0
	light.omni_range = 4.0
	light.position = Vector3(0, 0.5, 0)
	add_child(light)


func _play() -> void:
	var light := get_node("Glow") as OmniLight3D
	var tw := create_tween()
	tw.set_parallel(true)
	for m in _bits:
		tw.tween_property(m, "scale:z", 1.0, OPEN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 2.0, OPEN)
	tw.set_parallel(false)
	var beam := get_node("Beam") as Node3D
	tw.tween_property(beam, "scale:y", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		# The flash as they go through (or come out): a puff of lilac dust and a soft whoosh
		var juice := get_node_or_null("/root/Juice")
		if juice:
			juice.call("dust", get_parent(), global_position, 0.6, Color(LILAC, 0.7))
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.call("play_at", "beam" if going else "bloop", global_position, -8.0))
	tw.tween_interval(HOLD)
	tw.set_parallel(true)
	tw.tween_property(beam, "scale:y", 0.01, SHUT * 0.6)
	for m in _bits:
		tw.tween_property(m, "scale:z", 0.01, SHUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 0.0, SHUT)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
