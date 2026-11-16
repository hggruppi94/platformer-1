extends Node

# Distance LODs for meshes made in code (16 Nov 2026, the whole game gets the detailed props treatment). A model
# imported from Blender gets "levels of detail" from Godot's importer: simpler copies of itself that it draws when
# it's small on the screen. Everything the builders and scripts make (spheres, cylinders, the meshes
# scripts/static_batch.gd merges) has none, so a far-off goo dome is drawn with every one of its triangles, and again
# for each shadow. In the Void that's 7M triangles a frame before shadows (the Gloop Kingdom's view alone is 1.2M).
#
# This gives each big still mesh in a place its own LODs with the same tool the importer uses
# (ImporterMesh.generate_lods, meshoptimizer), worked out on a worker thread one mesh at a time so loading isn't held
# up, then swaps the mesh in. The mesh's shape up close is exactly the same; only far away is it simpler. A mesh many
# things share is done once. Nothing with a skin or blend shapes (people, animals), nothing imported (it has LODs),
# and only meshes of MIN_TRIS or more.

const MIN_TRIS := 3000
const MERGE_ANGLE := 25.0
const SPLIT_ANGLE := 60.0

var queue: Array = []           # [mesh, users]
var done := 0                   # meshes given LODs (tests read it)
var saved := 0                  # their triangles (the full detail, for the survey)
var _busy := false
var _task := -1
var _job: Dictionary = {}
var _seen := {}                 # mesh -> true


static func on(scene: Node) -> Node:
	var w := scene.get_node_or_null("Mesh LODs")
	if w == null:
		w = load("res://scripts/mesh_lods.gd").new()
		w.name = "Mesh LODs"
		scene.add_child(w)
	return w


func scan(scene: Node) -> int:
	# Queues every big still mesh in the scene not seen before. Returns how many were queued.
	var by_mesh := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not _ok(mi):
			continue
		if not by_mesh.has(mi.mesh):
			by_mesh[mi.mesh] = []
		by_mesh[mi.mesh].append(mi)
	var n := 0
	for mesh in by_mesh:
		_seen[mesh] = true
		queue.append([mesh, by_mesh[mesh]])
		n += 1
	return n


func _ok(mi: MeshInstance3D) -> bool:
	if mi.layers == 0 or mi.skin != null or not mi.skeleton.is_empty() and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
		return false
	var mesh := mi.mesh
	if not (mesh is ArrayMesh) or _seen.has(mesh) or mesh.has_meta("lods"):
		return false
	var path := mesh.resource_path
	if path.contains(".glb") or path.contains(".gltf") or path.contains(".blend") or path.contains(".fbx") \
			or path.contains(".obj") or path.begins_with("res://.godot"):
		return false                                    # imported: it already has its LODs
	var am := mesh as ArrayMesh
	if am.get_blend_shape_count() > 0:
		return false
	return _tris(am) >= MIN_TRIS


static func _tris(am: ArrayMesh) -> int:
	var t := 0
	for s in am.get_surface_count():
		if am.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return 0
		var n := am.surface_get_array_index_len(s)
		t += (n if n > 0 else am.surface_get_array_len(s)) / 3
	return t


func _process(_delta: float) -> void:
	if _busy:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_busy = false
			_finish(_job)
			_job = {}
		return
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var mesh: ArrayMesh = item[0]
		var users: Array = item[1].filter(func(u): return is_instance_valid(u) and u.mesh == mesh)
		if users.is_empty():
			continue
		# Copied here (the main thread): the worker only does the sums
		var im := ImporterMesh.new()
		for s in mesh.get_surface_count():
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(s), [], {}, mesh.surface_get_material(s),
				mesh.surface_get_name(s))
		_job = {"mesh": mesh, "users": users, "im": im}
		_task = WorkerThreadPool.add_task(im.generate_lods.bind(MERGE_ANGLE, SPLIT_ANGLE, []))
		_busy = true
		return


func _finish(job: Dictionary) -> void:
	var im: ImporterMesh = job.im
	if im.get_surface_count() == 0 or im.get_surface_lod_count(0) == 0:
		return
	var out := im.get_mesh()
	if out == null:
		return
	out.set_meta("lods", true)
	var old: ArrayMesh = job.mesh
	for k in old.get_meta_list():
		out.set_meta(k, old.get_meta(k))
	for u in job.users:
		if is_instance_valid(u) and u.mesh == old:
			u.mesh = out
	done += 1
	saved += _tris(old)


func _exit_tree() -> void:
	# The place is going (a new scene, or the game closing): a sum still running on the worker would hold its mesh and
	# materials past the end, so wait for it and let them go with everything else
	if _busy:
		WorkerThreadPool.wait_for_task_completion(_task)
		_busy = false
	_job = {}
	queue.clear()


func busy() -> bool:
	return _busy or not queue.is_empty()
