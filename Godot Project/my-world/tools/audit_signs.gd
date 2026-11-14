extends SceneTree

# Lists the signs you can't read as you walk into a place: every flat (not billboard) Label3D near where you arrive whose
# writing faces away from you. Hayden, 14 Nov 2026: "the signs arent always orientated the right way for you to read them
# when entering a new area (the gloop kingdom sign when you enter)". A Label3D's writing faces along its own +Z, so it reads
# right from the side its +Z points to; from behind it's mirrored (or hidden by the board it's on).
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/audit_signs.gd
#   (add `-- --all` to list every sign near the arrival point, not just the backwards ones)
#
# It fails (exit 1) if any arrival sign faces away. Your own save and settings are put aside and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.signs_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.signs_backup.cfg"
const NEAR := 120.0                    # metres from where you arrive: the signs you walk up to
# Places you arrive in (each puts the player at its way in)
const PLACES := [
	"res://scenes/bosses/gloop_kingdom.tscn",
	"res://scenes/bosses/arena.tscn",
	"res://scenes/portal_worlds/shard_isle.tscn",
	"res://scenes/portal_worlds/rootmind.tscn",
	"res://scenes/portal_worlds/frozen_moment.tscn",
	"res://scenes/portal_worlds/lanternmoor.tscn",
	"res://scenes/portal_worlds/rhythm_springs.tscn",
	"res://scenes/portal_worlds/tide_reef.tscn",
	"res://scenes/portal_worlds/glenmoor.tscn",
	"res://scenes/portal_worlds/dark_hollow.tscn",
	"res://scenes/portal_worlds/far_future.tscn",
	"res://scenes/races/lake_loop.tscn",
	"res://scenes/races/meadow_wiggle.tscn",
	"res://scenes/races/observatory_hill.tscn",
	"res://scenes/races/pumpkin_run.tscn",
	"res://scenes/scary_world/scary_world.tscn",
	"res://scenes/secret_garden/secret_garden.tscn",
	"res://scenes/school/school.tscn",
	"res://scenes/interiors/observatory.tscn",
]

var bad := 0
var all := false


func _initialize() -> void:
	all = "--all" in OS.get_cmdline_user_args()
	create_timer(600.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	var game := root.get_node("Game")
	game.set("hold_saves", true)
	var clock := root.get_node_or_null("Clock")
	if clock:
		clock.set("pulls_home", false)
	for path in PLACES:
		if not ResourceLoader.exists(path):
			continue
		change_scene_to_file(path)
		for i in 10:
			await process_frame
		var place := current_scene
		var player := get_first_node_in_group("player") as Node3D
		if player == null:
			print("SKIP  %s (no player)" % path)
			continue
		var eye := player.global_position + Vector3(0, 1.5, 0)
		var flat: Array[Label3D] = []
		for l in place.find_children("*", "Label3D", true, false):
			var label := l as Label3D
			if label.billboard == BaseMaterial3D.BILLBOARD_DISABLED and label.text.strip_edges() != "" and label.is_visible_in_tree():
				flat.append(label)
		for label in flat:
			var to := eye - label.global_position
			var dist := to.length()
			if "Race Board" in str(place.get_path_to(label)):
				continue                       # race boards face the road, where you stand to start the race
			if dist > NEAR or absf(to.y) > 6.0:
				continue                       # too far off, or up on another floor
			if flat.any(func(o: Label3D) -> bool: return o != label and o.text == label.text \
					and o.global_position.distance_to(label.global_position) < 1.5 and o.global_basis.z.dot(label.global_basis.z) < 0.0):
				continue                       # written on both sides (an arch, a board): the other side's the one you read
			var facing := label.global_basis.z.normalized()
			var dot := Vector2(facing.x, facing.z).normalized().dot(Vector2(to.x, to.z).normalized())
			var ok := dot > 0.0
			if not ok:
				bad += 1
			if all or not ok:
				print("%s  %s  \"%s\"  %.0fm  facing %.2f  (%s)" % ["OK  " if ok else "BACK", path.get_file(),
					label.text.replace("\n", " / "), dist, dot, place.get_path_to(label)])
	print("RESULT " + ("PASSED" if bad == 0 else "FAILED (%d backwards)" % bad))
	_finish()


func _finish() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	if FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS_BACKUP, SETTINGS)
		DirAccess.remove_absolute(SETTINGS_BACKUP)
	quit(1 if bad > 0 else 0)
