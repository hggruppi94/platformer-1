extends Node

# Keeps merged pieces honest (16 Nov 2026, the whole game gets the detailed props treatment). scripts/static_batch.gd
# merges still builder pieces into one mesh per material and only stops drawing the pieces themselves. If anything
# later moves, hides, recolours, swaps or frees one of those pieces (a world script spinning a crystal it kept in a
# variable, a season hiding a decoration), the merged mesh wouldn't show it. So this looks over every merged piece a
# few hundred a frame, and the moment one has changed it puts that whole group back the way it was: the pieces are
# drawn again and their merged meshes go. A big game would mark such things "dynamic" by hand; here the game finds out
# for itself, so no world's code has to know about batching.

const PER_FRAME := 400

var groups: Array = []          # {parent, pieces, made, snap, live}
var undone := 0                 # how many groups were put back (tests and the survey read it)
var _g := 0                     # which group and piece we're up to
var _i := 0


static func on(scene: Node) -> Node:
	var w := scene.get_node_or_null("Batch Watch")
	if w == null:
		w = load("res://scripts/batch_watch.gd").new()
		w.name = "Batch Watch"
		scene.add_child(w)
	return w


func add(parent: Node3D, pieces: Array, made: Array) -> void:
	var snap := []
	for mi: MeshInstance3D in pieces:
		snap.append(_state(mi))
	groups.append({"parent": parent, "pieces": pieces, "made": made, "snap": snap, "live": true})


static func _state(mi: MeshInstance3D) -> Array:
	var mats := []
	if mi.mesh:
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s))
	return [mi.transform, mi.visible, mi.mesh, mi.material_override, mats, mi.get_parent()]


func _process(_delta: float) -> void:
	if groups.is_empty():
		return
	var budget := PER_FRAME
	var tries := groups.size() + 1
	while budget > 0 and tries > 0:
		if _g >= groups.size():
			_g = 0
			_i = 0
		var gr: Dictionary = groups[_g]
		if not gr.live or _i >= gr.pieces.size():
			_g += 1
			_i = 0
			tries -= 1
			continue
		var mi = gr.pieces[_i]
		if not is_instance_valid(mi) or not _same(mi, gr.snap[_i]):
			undo(gr)
			_g += 1
			_i = 0
			tries -= 1
			continue
		_i += 1
		budget -= 1


func _same(mi: MeshInstance3D, was: Array) -> bool:
	var now := _state(mi)
	return now[0] == was[0] and now[1] == was[1] and now[2] == was[2] and now[3] == was[3] and now[4] == was[4] \
		and now[5] == was[5]


func undo(gr: Dictionary) -> void:
	# Draw the pieces again and drop their merged meshes
	if not gr.live:
		return
	gr.live = false
	undone += 1
	for mi in gr.pieces:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).layers = 1
			(mi as MeshInstance3D).remove_meta("static_batch")
	for out in gr.made:
		if is_instance_valid(out):
			(out as Node).queue_free()


func check_all() -> int:
	# Looks over every piece at once (tests); returns how many groups were put back
	var before := undone
	for gr: Dictionary in groups:
		if not gr.live:
			continue
		for i in gr.pieces.size():
			if not is_instance_valid(gr.pieces[i]) or not _same(gr.pieces[i], gr.snap[i]):
				undo(gr)
				break
	return undone - before
