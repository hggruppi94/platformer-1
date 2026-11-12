extends SceneTree

# Checks Dark Hollow, the centipede's world (scripts/dark_hollow.gd, scenes/portal_worlds/dark_hollow.tscn) and its
# secret way in (scripts/centipede_corner.gd): it never quakes and has no portal or map mark in the Void; at the far end
# of Behind the Walls in the castle school, only after a yes at the old Scary World gate, the centipede comes walking
# along the ceiling over your head and drops into her nest (full size, coiled up); talking to her asks Yes / No, and
# both answers are recorded; no keeps you in the school, yes gulps you up and you land in Dark Hollow; inside, she
# follows you round and says what to do; the eight shadow ghosts pop (and sometimes
# dodge), and popping all of them brings out the first Moon Piece; the Big Hole spits you out on top of the Crooked
# Spire (too high to get to otherwise) and then somewhere else; the Hollow Run's line is clear and finishing it gives
# the third piece; the Hush sleeps until you have all three and come near, can't be hurt in the dark, can in a moon
# lamp's light, puts lamps out, and popping it mends the world (Remnants); she cheers, asks you to come to her home and
# burrows off; the way home takes you to her home behind the old gate the first time, then to the school's front gate; it all stays done after loading; practice trips list it.
#
#   godot --headless --path "Godot Project/my-world" --script res://tools/test_dark_hollow.gd
#
# Your own save and settings are put aside (under their own names) and put back at the end.

const SAVE := "user://save.json"
const BACKUP := "user://save.dark_hollow_test_backup.json"
const SETTINGS := "user://settings.cfg"
const SETTINGS_BACKUP := "user://settings.dark_hollow_test_backup.cfg"
const TOWN := "res://scenes/town/town.tscn"
const SCHOOL := "res://scenes/school/school.tscn"
const WORLD := "res://scenes/portal_worlds/dark_hollow.tscn"
const SCARY := "res://scenes/scary_world/scary_world.tscn"
const ID := "dark_hollow"

var failures := 0
var game: Node
var portals: Node
var rem: Node
var dialogue: Node
var races: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	create_timer(420.0, true, false, true).timeout.connect(func() -> void:
		print("RESULT FAILED (timed out)")
		_finish())
	_run.call_deferred()


func _run() -> void:
	if FileAccess.file_exists(SAVE) and not FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(SAVE, BACKUP)
	if FileAccess.file_exists(SETTINGS) and not FileAccess.file_exists(SETTINGS_BACKUP):
		DirAccess.copy_absolute(SETTINGS, SETTINGS_BACKUP)
	game = root.get_node("Game")
	portals = root.get_node("Portals")
	rem = root.get_node("Remnants")
	dialogue = root.get_node("Dialogue")
	races = root.get_node("Races")
	var settings := root.get_node("Settings")
	settings.use_layout("classic")
	settings.last_device = "keyboard"
	settings.tips = false
	settings.set("race_intros", false)
	game._reset_state()
	game.needs_creator = false
	game.pending_message = ""
	var clock := root.get_node("Clock")
	clock.set("pulls_home", false)
	clock.set_time(3, 9 * 60.0, true)
	root.get_node("Quests").state[root.get_node("FirstNight").ID] = {"step": 0, "done": true, "since_day": 1}
	if not game.has_item("skateboard"):
		game.items.append("skateboard")

	check(ResourceLoader.exists(WORLD) and portals.is_built(ID), "Dark Hollow's scene is built")
	check(not portals.has_portal(ID) and not portals.quake_due(ID), "it has no portal and never quakes")
	change_scene_to_file(TOWN)
	await _frames(10)
	await _physics(4)
	for w in portals.WORLDS:
		if str(w.id) != ID and portals.is_built(str(w.id)) and not portals.is_open(str(w.id)):
			portals.quake(str(w.id), true)
	await _frames(4)
	check(current_scene.get_node_or_null("Portals/Portal dark_hollow") == null and portals.next_due() == "",
		"with every other world's portal up, there's still none to Dark Hollow")
	check(not portals.open_worlds().any(func(w: Dictionary) -> bool: return str(w.id) == ID), "...and nothing on the map")
	await _check_corner()
	await _check_inside()
	await _check_ghosts()
	await _check_hole()
	await _check_race()
	await _check_hush()
	await _check_home()
	_check_saving()
	_check_practice()
	_finish()


# The secret way in ------------------------------------------------------------------------------------------------
func _check_corner() -> void:
	change_scene_to_file(SCHOOL)
	await _frames(10)
	await _physics(6)
	var s := current_scene
	var corner := s.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner") as Node3D
	check(corner != null, "her corner is at the far end of Behind the Walls in the castle school")
	if corner == null:
		return
	var crawler := s.get_node_or_null("Floor 2/Behind The Walls/Centipede") as Node3D
	var player := _player()
	var at: Vector3 = corner.to_global(corner.CORNER)
	var space := (s as Node3D).get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.0, 0), at + Vector3(0, -1.0, 0)))
	check(not down.is_empty() and absf(down.position.y - at.y) < 0.2, "her nest is on the 2nd floor, in the passage")
	# The passage really leads there: walk the lane from the north-east Sliver's side to the corner, nothing solid across it
	var blocked := 0
	for x in range(-25, 18, 2):
		var p := corner.to_global(Vector3(float(x), 1.0, -22.45))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(-2, 0, 0)))
		if not hit.is_empty() and not (hit.collider as Node).is_in_group("player"):
			blocked += 1
	check(blocked == 0, "the dark passage runs all the way to her corner (%d things in the way)" % blocked)
	check(not corner.shown and not corner.her.visible and crawler.visible, "from far off she's up on the ceiling, crawling")
	player.global_position = corner.to_global(Vector3(-21.0, 1.0, -22.45))
	player.velocity = Vector3.ZERO
	await _physics(10)
	await _frames(4)
	check(not corner.shown, "before a yes at the old gate, her nest stays empty")
	dialogue.set_flag("scary_world_said_yes")
	await _physics(10)
	await _frames(4)
	var walker := corner.walker as Node3D
	check(corner.shown and corner.arriving and walker != null and walker.visible and walker.upside_down and not corner.her.visible
		and not crawler.visible, "after a yes, come near and she comes walking along the ceiling...")
	var wy: float = (walker.get("head_at") as Vector3).y
	check(wy > corner.to_global(corner.CORNER).y + 5.0, "...right up on the ceiling (%.1f m up)" % (wy - corner.to_global(corner.CORNER).y))
	check(corner.get_node("Spot").what() == "", "...(no talking till she's down)")
	await create_timer(corner.WALK_FROM / corner.WALK_SPEED + 1.0).timeout
	check(corner.shown and not corner.arriving and corner.her.visible and not walker.visible, "...then drops down into her nest")
	check(is_equal_approx(corner.her.scale.x, 1.0), "she's full size, like everywhere else (coiled up tight)")
	check(corner.get_node("Spot").what() == "talk to the centipede", "...and you can talk to her")
	check(corner.get_node_or_null("Decor/Corner Glow") != null, "...in her corner, with roots, glowing fungi and her nest")
	# Saying no
	player.global_position = corner.to_global(corner.SPOT_AT) + Vector3(1.0, 1.0, 0)
	await _physics(6)
	var heard := await _talk(corner, 1)
	check(" ".join(heard).contains("Dark Hollow") and " ".join(heard).contains("gulp"), "she tells you about Dark Hollow and the gulp")
	var last: Dictionary = dialogue.choice_log.back() if dialogue.choice_log.size() > 0 else {}
	check(str(last.get("what", "")) == "dark_hollow_gulp" and str(last.get("answer", "")) == "no", "saying no is recorded")
	await create_timer(1.0).timeout
	check(current_scene.scene_file_path == SCHOOL and not corner.gulping, "...and you stay in the school")
	# Saying yes
	await _talk(corner, 0)
	last = dialogue.choice_log.back()
	check(str(last.get("answer", "")) == "yes" and dialogue.choice_log.size() >= 2, "saying yes is recorded too")
	await _frames(2)
	check(corner.gulping and player.input_locked, "she circles round you and gulps you up (you can't walk off mid-gulp)")
	await create_timer(1.6).timeout
	check(root.get_node_or_null("Gulp") != null, "GULP! The screen closes like a mouth")
	await _wait_for_scene(WORLD)
	check(current_scene.scene_file_path == WORLD and portals.here == ID, "...and you slide down to Dark Hollow")
	await create_timer(1.0).timeout
	check(root.get_node_or_null("Gulp") == null, "...and the gulp's gone once you're there")


# Inside -----------------------------------------------------------------------------------------------------------
func _check_inside() -> void:
	await _frames(10)
	await _physics(6)
	var s := current_scene
	var names := ["WayHome/Way Home/Spot", "Vein1/Remnant Vein/Spot", "Centipede/Model",
		"Centipede/Model/Head/Spot", "The Hush", "Hush/Snoring", "Stars", "MoonClock/Moon Clock", "Piece2/Moon Piece", "Race hollow_run"]
	for i in 4:
		names.append("Lamp%d/Spot" % (i + 1))
		names.append("Lamp%d/Hit" % (i + 1))
	for i in 8:
		names.append("Shadow Ghost %d" % (i + 1))
	for n in names:
		check(s.get_node_or_null(n) != null, "Dark Hollow has %s" % n)
	var player := _player()
	check(player.global_position.distance_to((s.get_node("Entrance") as Node3D).global_position) < 2.0, "you land at the way in")
	check(not player.input_locked, "...free to move")
	check(s.mended == 0.0 and s.get_node_or_null("Piece1/Moon Piece") == null, "it's stuck at midnight, and the glade's piece isn't out yet")
	var first: Array = s.centipede_lines()
	check(" ".join(first).contains("Ptoo") and " ".join(first).contains("Moon Clock"), "the centipede says hello and what's wrong")
	check(" ".join(s.centipede_lines()).contains("Still to do"), "...then what's left to do")
	# She follows you round
	var cw := s.get_node("Centipede/Model") as Node3D
	var go_to := player.global_position + Vector3(8, 0, 0)
	for k in 30:
		player.global_position = player.global_position.lerp(go_to, 0.1)
		player.velocity = Vector3.ZERO
		await _physics(2)
	await create_timer(2.0).timeout
	var ch: Vector3 = cw.get("head_at")
	var dd := Vector2(ch.x - player.global_position.x, ch.z - player.global_position.z).length()
	check(cw.follow == player and dd < 5.5 and dd > 1.5, "she follows you round, a few steps behind (%.1f m)" % dd)
	var space := (s as Node3D).get_world_3d().direct_space_state
	for n in ["Vein1", "Centipede", "Lamp1", "Lamp2", "Lamp3", "Lamp4", "Spout2", "Spout3", "Spout4"]:
		var at := (s.get_node(n) as Node3D).global_position
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.3, 0), at + Vector3(0, -1.2, 0)))
		check(not hit.is_empty(), "%s is on solid ground" % n)
	var glow = player.get_node_or_null("PipGlow")
	check(glow != null and glow._night(), "it's always night here (Pip's glow, once it's yours, shines)")


func _check_ghosts() -> void:
	var s := current_scene
	var g: Node = s.ghost_node(0)
	var dodged := false
	var hit := false
	g.set("dodge_chance", 1.0)
	check(g.shot(1, g.global_position, Vector3.FORWARD) == "miss", "a shadow ghost can flicker aside from a bubble")
	g.set("dodge_chance", 0.0)
	check(g.shot(1, g.global_position, Vector3.FORWARD) == "hit" and g.defeated, "...and pops when one gets it")
	await _frames(2)
	check(s.ghosts_popped() == 1, "one ghost popped (%d)" % s.ghosts_popped())
	# One by stomping
	var player := _player()
	g = s.ghost_node(1)
	await _physics(2)
	player.global_position = g.global_position + Vector3(0, 2.2, 0)
	player.velocity = Vector3(0, -3.0, 0)
	for k in 40:
		await physics_frame
		if g.defeated:
			break
	check(g.defeated and player.velocity.y > 0.0 or g.defeated, "a stomp pops one too")
	for i in range(2, 8):
		var x: Node = s.ghost_node(i)
		if x:
			x.pop(true)
	await _frames(2)
	check(s.ghosts_popped() == 8 and s.get_node_or_null("Piece1/Moon Piece") == null, "all eight popped...")
	await create_timer(1.5).timeout
	check(s.get_node_or_null("Piece1/Moon Piece") != null, "...and their wisps gather into the glade's Moon Piece")
	player.global_position = (s.get_node("Piece1") as Node3D).global_position + Vector3(0, -0.4, 0)
	await _frames(4)
	check(s.is_piece_found(0) and s.pieces_found() == 1, "walk into it and it's yours")


func _check_hole() -> void:
	var s := current_scene
	var player := _player()
	var spire := (s.get_node("Spout1") as Node3D).global_position
	check(spire.y > 12.0, "the Crooked Spire's top is far too high to jump to (%.0f m)" % spire.y)
	player.global_position = Vector3(0.0, 1.5, 0.0)                     # over the Big Hole
	player.velocity = Vector3.ZERO
	var n := 0
	while n < 300 and s.spits == 0:
		await physics_frame
		n += 1
	check(s.spits == 1 and s.last_spout == "Spout1", "fall into the Big Hole and it spits you out on top of the spire")
	n = 0
	while n < 300 and not (player.is_on_floor() and n > 20):
		await physics_frame
		n += 1
	check(player.global_position.y > 13.0 and Vector2(player.global_position.x - spire.x, player.global_position.z - spire.z).length() < 4.0,
		"...and you land up there (%s)" % player.global_position)
	await _frames(4)
	check(s.is_piece_found(1) and s.pieces_found() == 2, "the spire's Moon Piece is yours")
	player.global_position = Vector3(0.0, 1.5, 0.0)
	player.velocity = Vector3.ZERO
	n = 0
	while n < 300 and s.spits == 1:
		await physics_frame
		n += 1
	check(s.spits == 2 and s.last_spout == "Spout2", "jump in again and it spits you out somewhere else (%s)" % s.last_spout)
	await _physics(30)
	n = 0
	while n < 300 and not player.is_on_floor():
		await physics_frame
		n += 1
	var sp := (s.get_node("Spout2") as Node3D).global_position
	check(player.is_on_floor() and player.global_position.distance_to(sp) < 4.0, "...safely on the ground by a little spout (%.1f s in the air)" % (n / 60.0 + 0.5))


func _check_race() -> void:
	var s := current_scene
	var t: Node3D = races.track_node("hollow_run")
	for k in 30:
		if t and t.ready_to_race:
			break
		await physics_frame
	check(t != null and t.ready_to_race, "the Hollow Run is laid out in Dark Hollow")
	if t == null:
		return
	check(races.unlocked("hollow_run") and races.track_node("lake_loop") == null, "it's open, and the Void's tracks aren't here")
	var pip := t.get_node_or_null("Pip") as Node3D
	check(pip != null and pip.global_position.distance_to(t.point_at(0.0)) > 6.0, "Pip starts it, standing off the track")
	var L: float = t.length
	check(L > 180.0 and L < 420.0, "a lap is a good length (%.0f m)" % L)
	var space: PhysicsDirectSpaceState3D = (s as Node3D).get_world_3d().direct_space_state
	var blocked: Array[String] = []
	var low := 0
	for i in t.line.size():
		var a: Vector3 = t.line[i]
		var b: Vector3 = t.line[(i + 1) % t.line.size()]
		if a.y < -0.2:
			low += 1
		for side in [-2.2, 0.0, 2.2]:
			var off: Vector3 = t.side_at(t.dist[i]) * side
			for h in [0.6, 1.3]:
				var q := PhysicsRayQueryParameters3D.create(a + off + Vector3.UP * h, b + off + Vector3.UP * h)
				q.exclude = [_player().get_rid()]
				var hit: Dictionary = space.intersect_ray(q)
				if not hit.is_empty() and hit.collider is StaticBody3D and blocked.size() < 12:
					blocked.append("%s at (%.0f, %.0f)" % [(hit.collider as Node).get_parent().name, a.x, a.z])
	check(blocked.is_empty(), "nothing in the way, in any lane (%s)" % ", ".join(blocked))
	check(low == 0, "...and never near the Big Hole (%d low points)" % low)
	var far := 0.0
	for a in t.line:
		far = maxf(far, Vector2(a.x, a.z).length())
	check(far < 52.0, "...and well inside the hollow's edge (%.0f m out)" % far)
	# A whole race, round the rings
	var p := _player()
	p.global_position = t.point_at(-3.0) + Vector3.UP * 0.9
	await _physics(4)
	check(races.start("hollow_run"), "saying yes to Pip starts the race")
	await _physics(int(races.COUNTDOWN * 60) + 10)
	check(races.state == races.State.RACING, "GO: the race is on")
	for lap in int(races.TRACKS.hollow_run.laps):
		for i in range(1, t.cp_dist.size() + 1):
			var d: float = t.cp_dist[i % t.cp_dist.size()]
			p.global_position = t.point_at(d - 2.0) + Vector3.UP * 0.85
			p.velocity = t.dir_at(d) * 7.0
			await _physics(4)
			p.global_position = t.point_at(d) + Vector3.UP * 0.85
			await _physics(3)
			if races.state != races.State.RACING:
				break
	check(races.state == races.State.RESULTS, "two laps and it's finished")
	await _frames(2)
	check(s.is_piece_found(2) and s.pieces_found() == 3, "finishing gives you the third Moon Piece")
	await _physics(int(races.RESULTS_TIME * 60) + 20)
	if game.riding:
		game.toggle_skateboard()
	await _physics(10)


func _check_hush() -> void:
	var s := current_scene
	var player := _player()
	var h: CharacterBody3D = s.hush()
	player.global_position = Vector3(0, 1.0, 20)
	await _physics(10)
	check(not s.hush_awake and h.process_mode == Node.PROCESS_MODE_DISABLED, "the Hush sleeps until you come near")
	var hill := (s.get_node("Hush") as Node3D).global_position
	player.global_position = hill + Vector3(0, 1.0, 12)
	await _frames(4)
	check(s.hush_awake and h.process_mode == Node.PROCESS_MODE_INHERIT and s.get_node_or_null("Hush/Snoring") == null, "with all three pieces, it wakes")
	await _physics(10)
	# In the dark: nothing touches it
	for i in 4:
		s.lamps_lit[i] = false
	h.global_position = hill + Vector3(0, 0, 0)
	await _physics(3)
	check(not h.lit and h.shot(1, h.global_position, Vector3.FORWARD) == "miss" and h.hits == 0, "in the dark, bubbles go straight through it")
	for i in 4:
		s.light_lamp(i)
	# In a lamp's light: it can be popped
	var lamp: Vector3 = s.lamp_pos(0)
	var toward := (hill - lamp)
	toward.y = 0
	h.global_position = Vector3(lamp.x, h.global_position.y, lamp.z) + toward.normalized() * 4.0
	await _physics(3)
	check(h.lit and h.shot(1, h.global_position, Vector3.FORWARD) == "hit" and h.hits == 1, "in a moon lamp's light, a bubble hurts it")
	# It puts a lamp out when it gets right up to it
	s.light_lamp(1)
	h.global_position = Vector3(s.lamp_pos(1).x, h.global_position.y, s.lamp_pos(1).z)
	await _physics(3)
	check(not s.is_lamp_lit(1), "it hushes out a lamp it gets right up to")
	check(s.get_node("Lamp2/Spot").what() == "light the moon lamp", "...and you can light it again")
	s.get_node("Lamp2/Spot").use()
	check(s.is_lamp_lit(1), "...like that")
	var before: int = rem.count
	player.global_position = Vector3(0, 1.0, 20)
	for k in 12:
		if not is_instance_valid(h) or h.defeated:
			break
		h.global_position = Vector3(lamp.x, h.global_position.y, lamp.z) + toward.normalized() * 4.0
		s.light_lamp(0)
		await _physics(2)
		h.shot(1, h.global_position, Vector3.FORWARD)
	await _frames(4)
	check(portals.is_cleared(ID), "popping the Hush mends Dark Hollow")
	check(rem.count == before + int(portals.world(ID).reward_remnants), "...with its reward (%d Remnants)" % (rem.count - before))
	check(dialogue.flags.has("dark_hollow_friend"), "...and the centipede's glad")
	await create_timer(s.MEND_TIME + 0.5).timeout
	check(s.is_mended(), "the Moon Clock ticks on, the mist thins and the stars come out")
	await create_timer(1.5).timeout
	check(dialogue.is_active(), "she cheers, and asks you to come to her home")
	check(" ".join(s.thank_lines()).contains("old gate"), "...behind the old gate")
	dialogue.end()
	await create_timer(1.0).timeout
	check(s.get_node_or_null("Centipede/Model") == null, "...and burrows off home")
	await _physics(10)
	var left := s.get_tree().get_nodes_in_group("shadow_ghosts").filter(func(g: Node) -> bool: return not g.defeated)
	check(left.is_empty(), "no shadow ghosts are left about (%d)" % left.size())


func _check_home() -> void:
	var s := current_scene
	s.get_node("WayHome/Way Home/Spot").use()
	await _wait_for_scene(SCARY)
	await _frames(10)
	await _physics(6)
	var player := _player()
	var her := current_scene.find_child("Centipede", true, false) as Node3D
	check(current_scene.scene_file_path == SCARY and her != null and her.visible and player.global_position.distance_to(her.global_position) < 6.0,
		"the first time, the way home takes you to her home, by her hollow log behind the old gate")
	# (her game and her thanks there: tools/test_scary_world.gd)
	dialogue.set_flag("centipede_fought")
	dialogue.set_flag("centipede_gifts")
	portals.enter_dark_hollow()
	await _wait_for_scene(WORLD)
	await _frames(10)
	check(current_scene.get_node_or_null("Centipede/Model") == null, "back in Dark Hollow she's not there: she's at home")
	current_scene.get_node("WayHome/Way Home/Spot").use()
	await _wait_for_scene(TOWN)
	await _frames(10)
	await _physics(6)
	player = _player()
	var gate := current_scene.find_child("FromSchool", true, false) as Node3D
	check(current_scene.scene_file_path == TOWN and gate != null and player.global_position.distance_to(gate.global_position) < 3.0,
		"the way home comes out at the castle school's front gate, not back in the passage")
	check(portals.here == "", "...and you're back in the Void")
	# The way back in: still the centipede
	change_scene_to_file(SCHOOL)
	await _frames(10)
	var corner := current_scene.get_node_or_null("Floor 2/Behind The Walls/Centipede's Corner")
	check(corner != null and corner.get_node("Spot").what().contains("note") and " ".join(corner.note_lines()).contains("old gate"),
		"her corner's empty now, with a note: she's gone home, behind the old gate")
	portals.enter_dark_hollow()
	await _wait_for_scene(WORLD)
	await _frames(10)
	var w := current_scene
	check(w.is_mended() and w.get_node_or_null("The Hush") == null and w.pieces_found() == 3 and w.ghosts_popped() == 8,
		"going back, it's all still mended")
	portals.go_home()          # (the way home: there's no time limit to run out any more)
	await _wait_for_scene(TOWN)
	await _frames(6)
	check(current_scene.scene_file_path == TOWN, "the way home takes you home to the Void too")


func _check_saving() -> void:
	game.save_game()
	var found: Dictionary = portals.found.duplicate(true)
	portals.reset()
	game.load_game()
	check(portals.is_cleared(ID) and portals.found == found and not portals.is_open(ID), "Dark Hollow's progress loads back (and still no portal)")


func _check_practice() -> void:
	check(portals.can_practice(ID), "practice trips can visit Dark Hollow")


# Helpers ----------------------------------------------------------------------------------------------------------
func _player() -> CharacterBody3D:
	return current_scene.get_tree().get_first_node_in_group("player") as CharacterBody3D


func _talk(corner: Node, pick: int) -> Array:
	var heard: Array = []
	var cb := func(_who: String, text: String) -> void: heard.append(text)
	dialogue.line_shown.connect(cb)
	corner.talk()
	await _frames(2)
	var guard := 400
	while dialogue.is_active() and guard > 0:
		guard -= 1
		if dialogue._choosing:
			var buttons: Array = dialogue.current_choices()
			buttons[mini(pick, buttons.size() - 1)].grab_focus()
			await _frames(1)
			_press("interact")
		else:
			_press("interact")
			await _frames(1)
			_press("interact")
		await _frames(2)
	dialogue.line_shown.disconnect(cb)
	await create_timer(0.25).timeout
	return heard


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)


func _wait_for_scene(path: String) -> void:
	for i in 600:
		if current_scene and current_scene.scene_file_path == path:
			await _frames(4)
			return
		await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("jump")
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
