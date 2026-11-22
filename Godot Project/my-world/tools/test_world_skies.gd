extends SceneTree

# Checks the portal worlds' dream skies (scripts/world_sky.gd): every world but Shard Isle (which has its own,
# shard_sky.gd) gets its own dream sky and far scenery, in the world and in its portal's preview; nothing in it is
# solid; the far things are out past where you can walk; the sky follows the world's own sky colours as they change
# (Lanternmoor's dawn checked through set_dawn); the Frozen Moment's ice shards hang still until it's mended; and the
# light the world gets from its sky is its own gradient.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_world_skies.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.world_skies_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.world_skies_test_backup.cfg"
const WORLDS := ["rootmind", "frozen_moment", "lanternmoor", "glenmoor", "tide_reef", "rhythm_springs", "dark_hollow",
	"far_future"]

var failures := 0
var game: Node
var portals: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _check_sky(w: Node3D, id: String, where: String) -> Node:
	var sky := w.get_node_or_null("Dream Sky")
	check(sky != null, "%s %s has a dream sky" % [id, where])
	if sky == null:
		return null
	check(sky.theme == id, "%s %s: its own theme" % [id, where])
	var we := w.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var smat := we.environment.sky.sky_material as ShaderMaterial if we and we.environment.sky else null
	check(smat != null and smat == sky.sky_mat and smat.shader.resource_path.ends_with("world_dream_sky.gdshader"),
		"%s %s: the sky is its dream sky" % [id, where])
	var want := 0
	var nearest := INF
	for f: Array in sky.THEMES[id].far:
		want += int(f[1])
		nearest = minf(nearest, float(f[2]))
	check(sky.far.size() == want and want > 0, "%s %s: %d far things" % [id, where, want])
	var close := 0
	for g: Node3D in sky.far:
		if Vector2(g.position.x, g.position.z).length() < nearest - 20.0:
			close += 1
	check(close == 0, "%s %s: every far thing is far out (%d too close)" % [id, where, close])
	check(sky.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s %s: nothing in it is solid" % [id, where])
	if sky.src:
		var top: Vector3 = smat.get_shader_parameter("light_top")
		var c: Color = sky.src.sky_top_color
		check(top.is_equal_approx(Vector3(c.r, c.g, c.b)), "%s %s: the light from the sky is the world's own" % [id, where])
	return sky


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	root.get_node("Settings").tips = false
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	portals.home_calls.enabled = false
	portals.practice = false
	for id: String in WORLDS:
		var path := str(portals.world(id).scene)
		# The portal's preview copy
		var pv := (load(path) as PackedScene).instantiate() as Node3D
		pv.set_meta("preview", true)
		root.add_child(pv)
		await _frames(3)
		_check_sky(pv, id, "preview")
		pv.queue_free()
		await _frames(2)
		# The world itself
		change_scene_to_file(path)
		await _frames(12)
		var w := current_scene as Node3D
		var sky := _check_sky(w, id, "world")
		if sky == null:
			continue
		# It follows the world's own sky as it changes
		if sky.src:
			sky.src.sky_top_color = Color(0.11, 0.22, 0.33)
			await _frames(2)
			var top: Vector3 = sky.sky_mat.get_shader_parameter("top_colour")
			var now: Color = sky.src.sky_top_color           # (Glenmoor's own day loop changes it again straight away)
			check(top.is_equal_approx(Vector3(now.r, now.g, now.b)), "%s: the dream sky follows the world's sky" % id)
		if id == "lanternmoor":
			w.set_dawn(1.0)
			await _frames(2)
			var top2: Vector3 = sky.sky_mat.get_shader_parameter("top_colour")
			var m: Color = w.MORNING.top
			check(top2.is_equal_approx(Vector3(m.r, m.g, m.b)), "lanternmoor: the dream sky goes to morning with the dawn")
		if id == "frozen_moment":
			var g: Node3D = sky.far[0]
			var at := g.position
			await _frames(30)
			check(g.position.is_equal_approx(at), "frozen_moment: the ice shards hang still while time's stopped")
			portals.cleared_worlds.append("frozen_moment")
			await _frames(30)
			check(not g.position.is_equal_approx(at), "frozen_moment: once it's mended they drift again")
			portals.cleared_worlds.erase("frozen_moment")
		else:
			var g: Node3D = sky.far[0]
			var at := g.position
			await _frames(30)
			check(not g.position.is_equal_approx(at), "%s: the far things move" % id)
	print("RESULT " + ("FAILED (%d)" % failures if failures else "PASSED"))
	_finish()


func _finish() -> void:
	game.hold_saves = true
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if failures else 0)
