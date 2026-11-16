extends SceneTree

# Loads every place in the game and counts how many meshes it draws, before and after merging still pieces
# (scripts/static_batch.gd), and why the pieces left over weren't merged. Used to pick where the detailed props
# pipeline helps most (16 Nov 2026, Hayden: "Can you give the whole game this treatment?").
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/survey_batching.gd [-- <scene> ...]
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.survey_batching_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.survey_batching_backup.cfg"
const STATIC_BATCH := preload("res://scripts/static_batch.gd")

const SCENES := [
	"res://scenes/town/town.tscn", "res://scenes/earth/earth.tscn", "res://scenes/school/school.tscn",
	"res://scenes/secret_garden/secret_garden.tscn", "res://scenes/scary_world/scary_world.tscn",
	"res://scenes/portal_worlds/shard_isle.tscn", "res://scenes/portal_worlds/rootmind.tscn",
	"res://scenes/portal_worlds/frozen_moment.tscn", "res://scenes/portal_worlds/lanternmoor.tscn",
	"res://scenes/portal_worlds/glenmoor.tscn", "res://scenes/portal_worlds/tide_reef.tscn",
	"res://scenes/portal_worlds/rhythm_springs.tscn", "res://scenes/portal_worlds/dark_hollow.tscn",
	"res://scenes/portal_worlds/far_future.tscn", "res://scenes/bosses/gloop_kingdom.tscn",
	"res://scenes/bosses/arena.tscn", "res://scenes/bosses/clock_tower.tscn", "res://scenes/bosses/boulder_canyon.tscn",
	"res://scenes/bosses/skyreach_trail.tscn", "res://scenes/races/lake_loop.tscn",
	"res://scenes/races/meadow_wiggle.tscn", "res://scenes/races/observatory_hill.tscn",
	"res://scenes/races/pumpkin_run.tscn", "res://scenes/races/hollow_run.tscn",
	"res://scenes/interiors/my_house.tscn", "res://scenes/interiors/ninas_house.tscn",
	"res://scenes/interiors/aquarium.tscn", "res://scenes/interiors/cafe.tscn",
	"res://scenes/interiors/restaurant_and_cafe.tscn", "res://scenes/interiors/clothing_boutique.tscn",
	"res://scenes/interiors/observatory.tscn", "res://scenes/skate/test_park.tscn",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	game.hold_saves = true
	root.get_node("Settings").tips = false
	var detail := root.get_node("WorldDetail")
	detail.batching = false
	detail.detail_props = false
	detail.occluders = false
	detail.lods = false
	var list: Array = SCENES
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		list = args
	for path in list:
		change_scene_to_file(path)
		for i in 30:
			await process_frame
		var s := current_scene
		if s == null:
			print("SURVEY %s  could not load" % path)
			continue
		var before := _drawn(s)
		var why := _why(s)
		if OS.has_environment("SURVEY_DETAIL"):
			_detail(s)
		# Again with merging on, the way the game does it, and give the place 6 s to move things about
		detail.batching = true
		detail.lods = true
		change_scene_to_file(path)
		for i in 30:
			await process_frame
		await create_timer(6.0).timeout
		s = current_scene
		var lw := s.get_node_or_null("Mesh LODs")
		var t0 := Time.get_ticks_msec()
		while lw and lw.busy() and Time.get_ticks_msec() - t0 < 120000:
			await process_frame
		var lod_line := "lods %d meshes (%d tris) %.1f s after" % [lw.done if lw else 0, lw.saved if lw else 0, (Time.get_ticks_msec() - t0) / 1000.0]
		var r: Dictionary = detail.last_batch
		var watch := s.get_node_or_null("Batch Watch")
		var undone := 0
		if watch:
			watch.check_all()
			undone = watch.undone
		await process_frame
		var after := _drawn(s)
		detail.batching = false
		detail.lods = false
		print("     ", lod_line)
		print("SURVEY %-26s drawn %5d -> %5d  merged %5d into %4d  put back %d  left: %s" % [path.get_file(), before,
			after, r.get("pieces", 0), r.get("meshes", 0), undone, why])
		if watch and undone > 0:
			for gr in watch.groups:
				if not gr.live and is_instance_valid(gr.parent):
					print("   put back: ", s.get_path_to(gr.parent))
	_finish()


func _drawn(s: Node) -> int:
	var n := 0
	for c in s.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if g.is_visible_in_tree() and g.layers != 0:
			n += 1
	return n


func _why(s: Node) -> Dictionary:
	# Of the drawn meshes, why each wouldn't be merged (named, under a script, see-through/shader, other)
	var out := {"named": 0, "scripted": 0, "shader_or_clear": 0, "other": 0, "ok": 0}
	var sky := s.get_node_or_null("Sky")
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.layers == 0:
			continue
		var n := String(mi.name)
		if not (n.begins_with("@") or n.begins_with("MeshInstance3D")):
			out.named += 1
			continue
		var p := mi.get_parent()
		var scripted := false
		while p and p != s:
			if p.get_script() != null or not p.get_groups().is_empty() or not (p.get_class() in STATIC_BATCH.BODY_OK):
				scripted = true
				break
			p = p.get_parent()
		if scripted:
			out.scripted += 1
			continue
		var clear := false
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m: Material = STATIC_BATCH._material(mi, i)
				if m == null or STATIC_BATCH._see_through(m):
					clear = true
		if clear and not (sky and sky.is_ancestor_of(mi)):
			out.shader_or_clear += 1
		elif STATIC_BATCH._piece_ok(mi, sky != null and sky.is_ancestor_of(mi)):
			out.ok += 1
		else:
			out.other += 1
	return out


func _detail(s: Node) -> void:
	# Which scripted nodes hold back the most mergeable pieces, and which parents hold the most named meshes
	var blockers := {}
	var named := {}
	for c in s.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.layers == 0:
			continue
		var n := String(mi.name)
		if not (n.begins_with("@") or n.begins_with("MeshInstance3D")):
			var k := String(s.get_path_to(mi.get_parent()))
			named[k] = named.get(k, 0) + 1
			continue
		var p := mi.get_parent()
		while p and p != s:
			if p.get_script() != null or not p.get_groups().is_empty() or not (p.get_class() in STATIC_BATCH.BODY_OK):
				var k2 := "%s [%s %s]" % [s.get_path_to(p), p.get_class(), (p.get_script() as Script).resource_path.get_file() if p.get_script() else str(p.get_groups())]
				blockers[k2] = blockers.get(k2, 0) + 1
				break
			p = p.get_parent()
	for d: Dictionary in [blockers, named]:
		var keys: Array = (d as Dictionary).keys()
		keys.sort_custom(func(a, b): return d[a] > d[b])
		for k in keys.slice(0, 14):
			print("   %5d  %s" % [d[k], k])
		print("   --")


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	else:
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(0)
