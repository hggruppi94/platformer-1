class_name MultiFill
extends MultiMeshInstance3D

# Fills this node's MultiMesh when the scene loads, from the transforms and colours the builder saved here.
# (A MultiMesh's own instance data lives in the renderer, and a builder run with --headless has no real renderer, so
# the data never reached the saved scene: tools/build_earth.gd's fallen leaves, string lights and trees.)

@export var transforms := PackedFloat32Array()      # 12 floats an instance: basis x, y, z columns, then origin
@export var colors := PackedColorArray()


func _ready() -> void:
	fill()


func fill() -> void:
	var mm := multimesh
	if mm == null:
		return
	var n := transforms.size() / 12
	mm.instance_count = n
	for i in n:
		var k := i * 12
		var t := Transform3D(Vector3(transforms[k], transforms[k + 1], transforms[k + 2]),
			Vector3(transforms[k + 3], transforms[k + 4], transforms[k + 5]),
			Vector3(transforms[k + 6], transforms[k + 7], transforms[k + 8]),
			Vector3(transforms[k + 9], transforms[k + 10], transforms[k + 11]))
		mm.set_instance_transform(i, t)
		if mm.use_colors and i < colors.size():
			mm.set_instance_color(i, colors[i])


static func pack(mi: MultiMeshInstance3D, xforms: Array, cols: Array) -> void:
	# For builders: store the instances on mi (and set its script) so fill() can put them back at load time
	var data := PackedFloat32Array()
	data.resize(xforms.size() * 12)
	for i in xforms.size():
		var t: Transform3D = xforms[i]
		var vals := [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
			t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]
		for j in 12:
			data[i * 12 + j] = vals[j]
	mi.set_script(load("res://scripts/multi_fill.gd"))
	mi.set("transforms", data)
	mi.set("colors", PackedColorArray(cols))
