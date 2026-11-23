extends Node

# Keeps merged pieces honest (16 Nov 2026, the whole game gets the detailed props treatment). scripts/static_batch.gd
# merges still builder pieces into one mesh per material and only stops drawing the pieces themselves. If anything
# later moves, hides, recolours, swaps or frees one of those pieces (a world script spinning a crystal it kept in a
# variable, a season hiding a decoration), the merged mesh wouldn't show it. So this looks over every merged piece a
# few hundred a frame, and the moment one has changed it puts that whole group back the way it was: the pieces are
# drawn again and their merged meshes go. A big game would mark such things "dynamic" by hand; here the game finds out
# for itself, so no world's code has to know about batching.
#
# 23 Nov 2026 (Hayden: "reduce frame drop in the market"): looking over 400 pieces a frame cost about 1.8 ms on
# Hayden's PC in the Void's Market. Now hiding or showing a piece is heard straight away (each piece's
# visibility_changed), and the slow look-over for moves, swaps and frees only gets BUDGET_USEC of each frame, so a
# piece that's moved is noticed within a second or two instead of within a few frames.

const BUDGET_USEC := 200        # time a frame for the look-over (after at least MIN_PER_FRAME pieces)
const MIN_PER_FRAME := 16

var groups: Array = []          # {parent, pieces, made, snap, live}
var undone := 0                 # how many groups were put back (tests and the survey read it)
var _g := 0                     # which group and piece we're up to
var _i := 0
var _in := {}                   # piece's instance id: [[group, index]...] for its visibility_changed


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
	var gr := {"parent": parent, "pieces": pieces, "made": made, "snap": snap, "live": true}
	groups.append(gr)
	for i in pieces.size():
		var mi := pieces[i] as MeshInstance3D
		var id := mi.get_instance_id()
		if not _in.has(id):
			_in[id] = []
			mi.visibility_changed.connect(_on_shown.bind(id), CONNECT_DEFERRED)
		_in[id].append([gr, i])


func _on_shown(id: int) -> void:
	for e: Array in _in.get(id, []):
		_check_shown(e[0], e[1])


func _check_shown(gr: Dictionary, i: int) -> void:
	# A piece of a merged group was hidden or shown (its own visible, not a parent's). Deferred, so set_layers()'s
	# hide-and-show-again in one go isn't taken for a change
	if gr.live and is_instance_valid(gr.pieces[i]) and (gr.pieces[i] as MeshInstance3D).visible != gr.snap[i][1]:
		undo(gr)


static func _state(mi: MeshInstance3D) -> Array:
	var mats := []
	if mi.mesh:
		for s in mi.mesh.get_surface_count():
			mats.append(mi.get_surface_override_material(s))
	return [mi.transform, mi.visible, mi.mesh, mi.material_override, mats, mi.get_parent()]


func _process(_delta: float) -> void:
	if groups.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var done := 0
	var tries := groups.size() + 1
	while tries > 0 and (done < MIN_PER_FRAME or Time.get_ticks_usec() - t0 < BUDGET_USEC):
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
		done += 1


func _same(mi: MeshInstance3D, was: Array) -> bool:
	# The cheap checks first, and no new arrays unless they all match
	if mi.transform != was[0] or mi.visible != was[1] or mi.mesh != was[2] or mi.material_override != was[3] \
			or mi.get_parent() != was[5]:
		return false
	var mats: Array = was[4]
	if mi.mesh == null:
		return mats.is_empty()
	var n := mi.mesh.get_surface_count()
	if n != mats.size():
		return false
	for s in n:
		if mi.get_surface_override_material(s) != mats[s]:
			return false
	return true


func undo(gr: Dictionary) -> void:
	# Draw the pieces again and drop their merged meshes
	if not gr.live:
		return
	gr.live = false
	undone += 1
	for mi in gr.pieces:
		if is_instance_valid(mi):
			set_layers(mi as MeshInstance3D, 1)
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


static func set_layers(mi: GeometryInstance3D, layers: int) -> void:
	# Changing an instance's render layers while it's in the world leaves it paired with the lights it was lit by
	# (Godot only unpairs when things stop overlapping), and when the place is freed those lights still point at it:
	# "BUG, indexing did not unpair geometries from light", then a crash on the next scene change (reloading Stars
	# Hollow, from the Season Dial). Taking it out of the world (hidden) and back in with the new layers pairs it again
	# properly. Children are hidden and shown with it, but only for this one line, so nothing sees the difference.
	if mi.layers == layers:
		return
	var was := mi.visible
	mi.visible = false
	mi.layers = layers
	mi.visible = was
