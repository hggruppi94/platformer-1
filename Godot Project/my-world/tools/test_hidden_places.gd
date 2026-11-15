extends SceneTree

# Checks the hidden places (scripts/hidden_places.gd): six in the Void and six in Stars Hollow, each on open ground
# inside the world, clear of buildings, trees and anything solid, and far enough from each other; nothing shows on the
# map or in the Bag before one's found; walking into one finds it (sparkles, a Remnant in the Void, a hat for some),
# only once; all six in a world gives that world's explorer hat; found places go on the map and in the Bag; and a
# save and load keeps them.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_hidden_places.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.hidden_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.hidden_test_backup.cfg"
const SCENES := {"void": "res://scenes/town/town.tscn", "earth": "res://scenes/earth/earth.tscn"}
const TREES := ["Trees", "Autumn Trees", "Foliage", "Crystals"]   # groups of things you'd see poking through
const CLEAR := 5.0                    # nothing solid within this of a place's middle (at body height)
const TREE_CLEAR := 4.5               # no tree's trunk this close
const APART := 40.0                   # places at least this far from each other

var failures := 0
var game: Node
var hidden: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(400.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	hidden = root.get_node("Hidden")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	root.get_node("Portals").home_calls.enabled = false
	var dialogue := root.get_node("Dialogue")
	check(hidden.PLACES.size() == 12, "twelve hidden places (%d)" % hidden.PLACES.size())
	for world in SCENES:
		check(hidden.places_in(world).size() == 6, "%s: six of them" % world)
		var ps: Array = hidden.places_in(world)
		var near := 1e9
		for i in ps.size():
			for j in range(i + 1, ps.size()):
				near = minf(near, (ps[i].at as Vector2).distance_to(ps[j].at))
		check(near >= APART, "%s: at least %d m apart (closest %.0f m)" % [world, APART, near])

	for world in SCENES:
		change_scene_to_file(SCENES[world])
		await _frames(12)
		await _physics(6)
		var scene := current_scene as Node3D
		var map := root.get_node("TownMap")
		check(not map.legend_kinds().has("hidden"), "%s: no hidden places on the map before any's found" % world)
		var roots := get_nodes_in_group("hidden_places")
		check(roots.size() == 6, "%s: six placed (%d)" % [world, roots.size()])
		var bounds := _bounds(scene)
		var space := scene.get_world_3d().direct_space_state
		for r in roots:
			var n := r as Node3D
			var id := str(n.get_meta("place_id"))
			var p := n.global_position
			check(bounds.grow(-10.0).has_point(Vector2(p.x, p.z)), "%s: %s is well inside the world (%s)" % [world, id, bounds])
			# On the ground
			var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3, 0), p + Vector3(0, -3, 0))
			var hit := space.intersect_ray(q)
			check(not hit.is_empty() and absf(hit.position.y - p.y) < 0.3, "...%s sits on the ground" % id)
			check(p.y > -1.0, "...%s isn't down in water or a hole (y %.1f)" % [id, p.y])
			# Nothing solid round it at body height (the ground itself is below the box)
			var box := BoxShape3D.new()
			box.size = Vector3(CLEAR * 2.0, 2.0, CLEAR * 2.0)
			var sq := PhysicsShapeQueryParameters3D.new()
			sq.shape = box
			sq.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, 1.9, 0))
			sq.collide_with_areas = false
			var hits := space.intersect_shape(sq, 8)
			var names := []
			for h in hits:
				var col := h.collider as Node
				if col and not col.is_in_group("player") and not (col is CharacterBody3D) and not _is_ground(col):
					names.append(str(col.get_path()).get_slice("/", 3) + "/" + str(col.name))
			check(names.is_empty(), "...%s: nothing solid within %d m %s" % [id, CLEAR, names])
			# Fairly flat, so nothing floats or sinks
			var lo := INF
			var hi := -INF
			for o in [Vector2.ZERO, Vector2(5, 0), Vector2(-5, 0), Vector2(0, 5), Vector2(0, -5)]:
				var y: float = (root.get_node("Bosses").ground(scene, p.x + o.x, p.z + o.y) as Vector3).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			check(hi - lo < 0.9, "...%s: the ground round it is fairly flat (%.1f m)" % [id, hi - lo])
			# No tree standing in it
			var close := ""
			for g in TREES:
				var holder := scene.get_node_or_null(g)
				if holder == null:
					continue
				for t in holder.find_children("*", "Node3D", false, false):
					var tp := (t as Node3D).global_position
					if Vector2(tp.x, tp.z).distance_to(Vector2(p.x, p.z)) < TREE_CLEAR:
						close = "%s/%s" % [g, t.name]
			check(close == "", "...%s: no tree in it %s" % [id, close])
			check(not hidden.is_found(id), "...%s isn't found yet" % id)

		# Walking into one finds it
		var player := scene.find_child("Player", true, false) as CharacterBody3D
		var first := roots[0] as Node3D
		var fid := str(first.get_meta("place_id"))
		var sp: int = game.sparkles
		var rem: int = root.get_node("Remnants").count
		player.global_position = (first.get_node("Find") as Node3D).global_position + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO
		await _physics(6)
		await _frames(2)
		check(hidden.is_found(fid) and dialogue.flags.get("hidden_" + fid, false), "%s: walking into %s finds it" % [world, fid])
		check(game.sparkles == sp + hidden.SPARKLES, "...+%d sparkles (%d)" % [hidden.SPARKLES, game.sparkles - sp])
		var want_rem: int = hidden.VOID_REMNANTS if world == "void" else 0
		check(root.get_node("Remnants").count == rem + want_rem, "...+%d Remnant" % want_rem)
		check(not hidden.find(fid) and game.sparkles == sp + hidden.SPARKLES, "...and only once")
		check(map.legend_kinds().has("hidden"), "%s: the map shows hidden places now" % world)
		check(map.hidden_found().size() == 1 and str(map.hidden_found()[0].id) == fid, "...just the one found")
		# The rest
		var set_hat: String = hidden.SET_HATS[world]
		for r in roots:
			var id := str(r.get_meta("place_id"))
			if id == fid:
				continue
			check(not game.has_item("shop:" + set_hat), "...no %s before the last one" % set_hat)
			hidden.find(id)
		check(hidden.found_count(world) == 6, "%s: all six found" % world)
		check(game.has_item("shop:" + set_hat), "...and that gives the %s" % set_hat)
		for p in hidden.places_in(world):
			if p.has("hat"):
				check(game.has_item("shop:" + str(p.hat)), "...%s gave the %s" % [p.id, p.hat])
	# Every hat is a real hat you can wear
	var shop := root.get_node("Shop")
	for hat in ["shell_crown", "acorn_cap", "starfinder_hat", "wanderer_hat"]:
		check(shop.items.has(hat) and str(shop.items[hat].get("kind", "")) == "hat", "%s is in the shop's list as a hat" % hat)
		var model = load("res://scripts/cosmetics.gd").hat(hat)
		check(model != null and model.get_child_count() > 0, "...and has a look")
		if model:
			model.free()
	# The Bag lists them
	var box := VBoxContainer.new()
	root.add_child(box)
	root.get_node("PlayerMenu")._hidden_page(box)
	var head := box.get_node_or_null("Hidden Places") as Label
	check(head != null and head.text.contains("12 of 12"), "the Bag says 12 of 12 (%s)" % (head.text if head else "none"))
	box.free()
	# Saved
	game.save_game()
	game._reset_state()
	check(hidden.found_count() == 0, "a fresh start has none found")
	game.load_game()
	check(hidden.found_count() == 12, "loading the save brings all twelve back (%d)" % hidden.found_count())
	_finish()


func _is_ground(c: Node) -> bool:
	var path := str(c.get_path())
	for g in ["/Ground", "/Terrain", "/Far Ground", "/Land"]:
		if path.contains(g):
			return true
	return false


func _bounds(scene: Node3D) -> Rect2:
	# The world's walls: the town's WorldBounds, Stars Hollow's Edge
	var holder := scene.get_node_or_null("WorldBounds")
	if holder == null:
		holder = scene.get_node_or_null("Edge")
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in holder.get_children():
		var p := (c as Node3D).global_position
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	# The walls sit on the four sides, so their middles span the inside
	return Rect2(Vector2(lo.x, lo.y), hi - lo)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	if game:
		game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	print("RESULT %s (%d failed)" % ["PASSED" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)
