extends Node

# Rex and Dash's lab, and their lab quest (res://quests/rex_lab.json). The node is "Lab" under the Watches autoload
# (scripts/watches.gd makes it), so dialogue reaches it as "Watches/Lab.<method>" and no new autoload was needed.
#
# The story (story/how-it-fits.md, the time arc): Rex and Dash come from the furthest future, where everyone runs
# experiments. At the very same moment Rex swapped bodies with their dog and Dash ran a time experiment, which sent
# all three of them to Galaxity, and here the swap won't undo. In their lab, a shed in the yard past Dash's house, Rex has built
# the Swap-o-Tron to switch back. It needs three time ripples (little bits of broken time) to push it, and the hero's
# watch is what can feel them: Dash tunes it, and while the quest needs ripples a pink pointer on the watch's rim
# points to the nearest (scripts/watch_face.gd). Then Rook has to be coaxed into the other pod, and the hero pulls the
# big lever. It nearly works: for a moment Rex and Rook swap voices, and Dash's reading says the swap is knotted into
# the crack in the Shift that their experiments made, so it can't come undone until that's fixed. Which is a much
# bigger job (Dash's arc, for later).
#
# Like the lost watches and the schematics, everything's put into the town at play time, so no builder or .tscn
# changed: the lab itself (always there, it's their lab), the ripples (only while the quest wants them) and the lever
# (a quest spot, scripts/quest_spot.gd). Progress is the quest's own flags, so the save needs nothing new.

const QUEST := "rex_lab"
const TOWN := "res://scenes/town/town.tscn"
const AT := Vector3(99.0, 0.0, -16.0)          # the middle of the lab's floor, in the yard past Dash's house
const TURN := -PI / 2.0                       # its open front faces west, back towards his house
const PICK_RADIUS := 1.9                      # how near her middle has to come to catch a ripple
const RIPPLES := [
	{"id": "1", "at": Vector2(-70.0, 71.0), "place": "at the south end of the Market Square"},
	{"id": "2", "at": Vector2(-11.0, -16.0), "place": "in the town square by the boardwalk"},
	{"id": "3", "at": Vector2(96.0, -56.0), "place": "on the path up Observatory Hill"},
]
const CHARGE_TIME := 2.8                      # seconds the Swap-o-Tron hums up before the flash

var _scene: Node
var _lab: Node3D
var _coil_mat: StandardMaterial3D
var _pod_lights: Array[OmniLight3D] = []
var _ripples := {}                            # id -> its node, while it's out
var _running := false
var _flash: ColorRect
var _t := 0.0


func _ready() -> void:
	Dialogue.flag_set.connect(_on_flag)
	var layer := CanvasLayer.new()
	layer.layer = 47
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_flash.visible = false
	layer.add_child(_flash)


func _process(delta: float) -> void:
	_t += delta
	var s := get_tree().current_scene
	if s != _scene:
		_scene = s
		_lab = null
		_ripples.clear()
		if s and s.scene_file_path == TOWN:
			_place_in.call_deferred(s)
		return
	if _lab == null or not is_instance_valid(_lab):
		return
	_update_ripples()
	if _coil_mat and not _running:
		_coil_mat.emission_energy_multiplier = 1.2 + 0.5 * sin(_t * 2.0)


# -----------------------------------------------------------------------------
# Where the quest is
# -----------------------------------------------------------------------------
func hunting() -> bool:
	# The ripples step, with the watch tuned to them
	return Quests.on_step(QUEST, "ripples")


func caught(id: String) -> bool:
	return Dialogue.flags.has("lab_ripple_" + id)


func caught_count() -> int:
	return RIPPLES.filter(func(r: Dictionary) -> bool: return caught(str(r.id))).size()


func nearest_ripple() -> Variant:
	# Where the nearest ripple still to catch is (for the watch's pointer), or null
	if not hunting() or _scene == null or _scene.scene_file_path != TOWN:
		return null
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var best: Variant = null
	var best_d := INF
	for id in _ripples:
		var n: Node3D = _ripples[id]
		if not is_instance_valid(n):
			continue
		var d := n.global_position.distance_to(player.global_position) if player else 0.0
		if d < best_d:
			best_d = d
			best = n.global_position
	return best


func tune_watch() -> Array:
	# Rex's "do" when the hero first sees the lab (res://dialogue/rex.json): Dash tunes their watch to the ripples.
	# Someone who skipped The First Night might not have one yet, so the Shift Watch turns up now.
	if not TimeWatch.has_watch():
		Game.items.append("shop:" + TimeWatch.SHIFT)
		if str(Game.outfit.get("hands", "")) == "":
			Game.outfit["hands"] = TimeWatch.SHIFT
		Game.equipment_changed.emit()
	Dialogue.set_flag("lab_tuned")
	return []


# -----------------------------------------------------------------------------
# The ripples
# -----------------------------------------------------------------------------
func _update_ripples() -> void:
	var want := hunting()
	for r in RIPPLES:
		var id := str(r.id)
		var out := _ripples.has(id) and is_instance_valid(_ripples[id])
		if want and not caught(id) and not out:
			var n := _ripple_model()
			n.name = "Time Ripple " + id
			_scene.add_child(n)
			var xz: Vector2 = r.at
			n.global_position = _ground(Vector3(xz.x, 0, xz.y)) + Vector3(0, 1.1, 0)
			_ripples[id] = n
		elif out and (not want or caught(id)):
			_ripples[id].queue_free()
			_ripples.erase(id)
	if not want:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var middle := player.global_position + Vector3(0, 0.9, 0)
	for id in _ripples.keys():
		var n: Node3D = _ripples[id]
		n.rotation.y += get_process_delta_time() * 1.4
		var wobble := 1.0 + 0.08 * sin(_t * 5.0 + float(id) * 2.0)
		n.get_node("Rings").scale = Vector3.ONE * wobble
		if n.global_position.distance_to(middle) < PICK_RADIUS:
			catch(id)


func catch(id: String) -> void:
	if caught(id):
		return
	var at := Vector3.ZERO
	if _ripples.has(id) and is_instance_valid(_ripples[id]):
		at = _ripples[id].global_position
		_ripples[id].queue_free()
		_ripples.erase(id)
	Dialogue.set_flag("lab_ripple_" + id)
	Audio.play("beam", -8.0, 0.0)
	Juice.blip("chime", 1.2, -6.0)
	Juice.shake(0.1)
	Juice.rumble(0.3, 0.2)
	if _scene and at != Vector3.ZERO:
		Fx.burst(_scene, at, Color(1.0, 0.45, 0.85), 18, 0.07, 3.0, -1.0, 0.8)
		Fx.burst(_scene, at, Color(0.8, 0.7, 1.0), 10, 0.05, 2.0, -0.5, 0.7)
	var n := caught_count()
	if n >= RIPPLES.size():
		Game.message("Your watch gulps up the last time ripple! That's all three. Back to the lab past Dash's house.")
	else:
		Game.message("Your watch gulps up a time ripple! (%d of %d) It's still humming..." % [n, RIPPLES.size()])
	Game.save_game()


func _ripple_model() -> Node3D:
	# A wobbling knot of broken time: two rings turning against each other round a faint bubble, pink and lavender
	var root := Node3D.new()
	var rings := Node3D.new()
	rings.name = "Rings"
	root.add_child(rings)
	var pink := _glow(Color(1.0, 0.4, 0.8), 2.5)
	var lav := _glow(Color(0.75, 0.65, 1.0), 2.0)
	for i in 3:
		var t := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.42 + 0.12 * i
		tm.outer_radius = tm.inner_radius + 0.05
		t.mesh = tm
		t.material_override = pink if i % 2 == 0 else lav
		t.rotation = Vector3(PI / 2.0 + i * 0.7, i * 1.1, i * 0.4)
		rings.add_child(t)
	var bubble := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.35
	bm.height = 0.7
	bubble.mesh = bm
	var mat := _glow(Color(1.0, 0.8, 1.0, 0.25), 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble.material_override = mat
	root.add_child(bubble)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.9)
	light.light_energy = 1.6
	light.omni_range = 6.0
	root.add_child(light)
	var label := Label3D.new()
	label.text = "~ time ripple ~"
	label.font_size = 28
	label.pixel_size = 0.008
	label.outline_size = 8
	label.modulate = Color(1.0, 0.8, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 0.95
	root.add_child(label)
	return root


# -----------------------------------------------------------------------------
# The big lever and the Swap-o-Tron
# -----------------------------------------------------------------------------
func _on_flag(f: String) -> void:
	if f == "lab_lever" and _lab and is_instance_valid(_lab):
		run_machine()


func run_machine() -> void:
	# The Swap-o-Tron hums up, the coil glows brighter and brighter, a flash, and a puff of lavender smoke
	if _running:
		return
	_running = true
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player:
		player.set("input_locked", true)
	Audio.play("beam", -4.0, 0.0)
	var tw := create_tween()
	tw.tween_method(_charge, 0.0, 1.0, CHARGE_TIME).set_ease(Tween.EASE_IN)
	tw.tween_callback(_bang)
	tw.tween_interval(1.0)
	tw.tween_callback(_done_running)


func is_running() -> bool:
	return _running


func _charge(v: float) -> void:
	if _coil_mat:
		_coil_mat.emission_energy_multiplier = 1.2 + 9.0 * v
	for l in _pod_lights:
		if is_instance_valid(l):
			l.light_energy = 0.6 + 4.0 * v
	if Engine.get_process_frames() % 8 == 0:
		Juice.shake(0.04 + 0.12 * v)


func _bang() -> void:
	var soft := Settings.reduce_flashing
	_flash.visible = true
	_flash.color = Color(0.85, 0.75, 1.0, 0.55) if soft else Color(1, 1, 1, 0.95)
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 1.2 if soft else 0.8)
	tw.tween_callback(func() -> void: _flash.visible = false)
	Audio.play("pop", -2.0, 0.0)
	Juice.shake(0.35)
	Juice.rumble(0.6, 0.35, 0.4)
	if _lab and is_instance_valid(_lab):
		for x in [-3.5, -0.5]:
			var at := _lab.to_global(Vector3(x, 1.4, -1.8))
			Fx.burst(_scene, at, Color(0.8, 0.7, 1.0), 26, 0.12, 2.5, 0.6, 1.4)          # lavender smoke, drifting up
			Fx.burst(_scene, at, Color(1.0, 0.5, 0.85), 14, 0.06, 4.0, -2.0, 0.8)


func _done_running() -> void:
	_running = false
	var player := get_tree().get_first_node_in_group("player")
	if player and "input_locked" in player and not Dialogue.is_active():
		player.set("input_locked", false)
	Game.message("FZZZT! The pods hiss open, and Rex and Rook stagger out in a puff of lavender smoke. Did it work?")


# -----------------------------------------------------------------------------
# Building the lab (at play time, from shapes, in the alien palette)
# -----------------------------------------------------------------------------
func _place_in(s: Node) -> void:
	if not is_instance_valid(s) or not s is Node3D or s.get_node_or_null("Rex and Dash's Lab"):
		return
	_scene = s
	_lab = _build()
	s.add_child(_lab)
	_lab.global_position = _ground(AT)
	_lab.rotation.y = TURN
	_clear_plot(s)
	_add_lever(s)


func _clear_plot(s: Node) -> void:
	# The town's trees and undergrowth are scattered by the builder (scenes/town/trees.gd, foliage.gd, both built from
	# lists when the scene loads), and a couple grow where the lab stands. Rather than rebuild the whole town for a
	# shed, the ones inside its walls (and a step round them) are shrunk away and lose their solid parts.
	var half := Vector2(6.0 + 1.6, 4.5 + 1.6)                 # the lab's walls, plus room for a canopy
	for holder_name in ["Trees", "Foliage"]:
		var holder := s.find_child(holder_name, true, false)
		if holder == null:
			continue
		for n in holder.get_children():
			if n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
				var mm := (n as MultiMeshInstance3D).multimesh
				for i in mm.instance_count:
					var t := mm.get_instance_transform(i)
					if _on_plot((n as Node3D).global_transform * t.origin, half):
						mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.0001), t.origin))
			elif n is CollisionObject3D and _on_plot((n as Node3D).global_position, half):
				n.queue_free()
			elif n is Light3D and _on_plot((n as Node3D).global_position, half):
				n.queue_free()


func _on_plot(p: Vector3, half: Vector2) -> bool:
	var local := _lab.to_local(p)
	return absf(local.x) < half.x and absf(local.z) < half.y


func _ground(p: Vector3) -> Vector3:
	var space := (_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 60, 0), p + Vector3(0, -40, 0))
	var got := space.intersect_ray(q)
	return got.position if not got.is_empty() else p


func _add_lever(s: Node) -> void:
	var spot := Area3D.new()
	spot.name = "Lab Lever"
	spot.set_script(load("res://scripts/quest_spot.gd"))
	spot.set("quest", QUEST)
	spot.set("step", "try")
	spot.set("flag", "lab_lever")
	spot.set("action", "pull the big lever")
	spot.set("radius", 2.0)
	s.add_child(spot)
	spot.global_position = _lab.to_global(Vector3(2.2, 0, 0.2))


func _build() -> Node3D:
	var lab := Node3D.new()
	lab.name = "Rex and Dash's Lab"
	var wall := _mat(Color(0.62, 0.55, 0.8), 0.8)
	var trim := _mat(Color(0.3, 0.8, 0.75), 0.5)
	var roof := _mat(Color(0.85, 0.35, 0.7), 0.6)
	var floor_mat := _mat(Color(0.32, 0.28, 0.42), 0.9)
	var metal := _mat(Color(0.75, 0.78, 0.85), 0.3, 0.8)
	var dark := _mat(Color(0.15, 0.12, 0.22), 0.7)

	# The shed: an open front so everyone can see in, three walls, a roof with a radar dish
	_solid(lab, Vector3(12, 0.12, 9), Vector3(0, 0.06, 0), floor_mat)
	_solid(lab, Vector3(12, 4, 0.3), Vector3(0, 2, -4.35), wall)
	for sx in [-1, 1]:
		_solid(lab, Vector3(0.3, 4, 9), Vector3(sx * 5.85, 2, 0), wall)
		_box(lab, Vector3(0.4, 4.1, 0.4), Vector3(sx * 5.85, 2.05, 4.4), trim)
	# (the roof isn't solid: people find their feet by looking straight down, and must land on the floor, not up here)
	_box(lab, Vector3(12.8, 0.3, 9.8), Vector3(0, 4.15, 0), roof)
	_box(lab, Vector3(12.9, 0.2, 0.3), Vector3(0, 3.9, 4.6), trim)
	var dish_pole := _cyl(lab, 0.08, 1.2, Vector3(4.5, 4.9, -2.5), metal)
	dish_pole.name = "DishPole"
	var dish := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.9
	dm.height = 0.6
	dm.is_hemisphere = true
	dish.mesh = dm
	dish.material_override = metal
	dish.position = Vector3(4.5, 5.6, -2.5)
	dish.rotation = Vector3(-2.4, 0.4, 0)
	lab.add_child(dish)

	# The sign over the front
	_box(lab, Vector3(6.4, 1.3, 0.15), Vector3(0, 4.95, 4.55), _mat(Color(0.12, 0.1, 0.3), 0.7))
	_label(lab, "REX & DASH'S LAB", Vector3(0, 5.1, 4.66), 64, Color(1.0, 0.92, 0.5))
	_label(lab, "(Rook allowed. Mostly.)", Vector3(0, 4.55, 4.66), 26, Color(0.9, 0.95, 1.0))

	# The Swap-o-Tron: two glass pods (no walls to bump: people stand in them), a glowing coil arch between
	_coil_mat = _glow(Color(1.0, 0.4, 0.8), 1.2)
	for x in [-3.5, -0.5]:
		_cyl(lab, 0.9, 0.3, Vector3(x, 0.27, -1.8), trim, false)
		var glass := _mat(Color(0.8, 0.75, 1.0, 0.22), 0.1, 0.0)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cyl(lab, 0.8, 2.4, Vector3(x, 1.62, -1.8), glass, false)
		_cyl(lab, 0.9, 0.3, Vector3(x, 2.97, -1.8), trim, false)
		var ring := MeshInstance3D.new()
		var rm := TorusMesh.new()
		rm.inner_radius = 0.78
		rm.outer_radius = 0.86
		ring.mesh = rm
		ring.material_override = _coil_mat
		ring.position = Vector3(x, 1.6, -1.8)
		lab.add_child(ring)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.9)
		l.light_energy = 0.6
		l.omni_range = 3.5
		l.position = Vector3(x, 2.2, -1.8)
		lab.add_child(l)
		_pod_lights.append(l)
	var arch := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 1.35
	am.outer_radius = 1.5
	arch.mesh = am
	arch.material_override = _coil_mat
	arch.position = Vector3(-2.0, 3.1, -1.8)
	arch.rotation = Vector3(PI / 2.0, 0, 0)
	lab.add_child(arch)
	_label(lab, "SWAP-O-TRON", Vector3(-2.0, 3.4, -0.9), 36, Color(1.0, 0.8, 1.0))
	for x in [-3.5, -0.5]:                                      # cables from the pods to the console
		_box(lab, Vector3(abs(2.2 - x), 0.08, 0.08), Vector3((x + 2.2) / 2.0, 0.16, -1.2), dark)

	# The console and its big lever
	_solid(lab, Vector3(1.4, 1.0, 0.8), Vector3(2.2, 0.5, -1.3), metal)
	_box(lab, Vector3(1.2, 0.05, 0.6), Vector3(2.2, 1.03, -1.3), dark)
	for i in 4:
		var b := _glow([Color(1.0, 0.4, 0.4), Color(0.4, 1.0, 0.5), Color(0.4, 0.7, 1.0), Color(1.0, 0.9, 0.3)][i], 2.0)
		_cyl(lab, 0.06, 0.05, Vector3(1.75 + i * 0.22, 1.07, -1.45), b, false)
	var lever := Node3D.new()
	lever.position = Vector3(2.55, 1.05, -1.15)
	lever.rotation.x = -0.5
	lab.add_child(lever)
	_cyl(lever, 0.04, 0.6, Vector3(0, 0.3, 0), metal, false)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.1
	km.height = 0.2
	knob.mesh = km
	knob.material_override = _mat(Color(1.0, 0.25, 0.35), 0.4)
	knob.position.y = 0.62
	lever.add_child(knob)

	# Dash's workbench, with beakers
	_solid(lab, Vector3(3.0, 0.9, 1.0), Vector3(3.9, 0.45, -3.4), _mat(Color(0.55, 0.4, 0.3), 0.8))
	for i in 5:
		var col: Color = [Color(0.6, 1.0, 0.35), Color(0.3, 0.9, 0.82), Color(1.0, 0.4, 0.8), Color(1.0, 0.85, 0.3),
			Color(0.6, 0.6, 1.0)][i]
		_cyl(lab, 0.1 + 0.03 * (i % 2), 0.3 + 0.1 * (i % 3), Vector3(2.9 + i * 0.5, 1.05 + 0.05 * (i % 3), -3.3), _glow(col, 1.5), false)

	# The chalkboard
	_box(lab, Vector3(3.2, 1.8, 0.08), Vector3(3.0, 2.4, -4.15), _mat(Color(0.12, 0.25, 0.2), 0.9))
	_label(lab, "REX + ROOK = ???\n3 time ripples!!\nDO NOT PULL LEVER\n(yet)", Vector3(3.0, 2.4, -4.08), 30,
		Color(0.95, 0.95, 0.9), false)

	# A framed picture on the wall: Hound Hero, a dog who's also a hero. Has someone tried this before?
	_box(lab, Vector3(1.3, 1.6, 0.08), Vector3(-4.6, 2.5, -4.15), _mat(Color(0.95, 0.75, 0.3), 0.4, 0.6))
	_box(lab, Vector3(1.1, 1.4, 0.04), Vector3(-4.6, 2.5, -4.1), _mat(Color(0.55, 0.75, 1.0), 0.8))
	var cape := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.6, 0.7, 0.02)
	cape.mesh = pm
	cape.material_override = _mat(Color(0.95, 0.3, 0.35), 0.7)
	cape.position = Vector3(-4.6, 2.35, -4.07)
	lab.add_child(cape)
	_box(lab, Vector3(0.3, 0.45, 0.03), Vector3(-4.6, 2.35, -4.05), _mat(Color(0.25, 0.35, 0.8), 0.7))
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.3
	head.mesh = hm
	var fur := _mat(Color(0.85, 0.7, 0.5), 0.8)
	head.material_override = fur
	head.position = Vector3(-4.6, 2.78, -4.04)
	head.scale.z = 0.3
	lab.add_child(head)
	for sx in [-1, 1]:
		var ear := MeshInstance3D.new()
		var em := PrismMesh.new()
		em.size = Vector3(0.12, 0.16, 0.02)
		ear.mesh = em
		ear.material_override = fur
		ear.position = Vector3(-4.6 + sx * 0.13, 2.95, -4.04)
		lab.add_child(ear)
	_label(lab, "HOUND HERO", Vector3(-4.6, 1.92, -4.05), 22, Color(0.2, 0.15, 0.3), false)

	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.85, 1.0)
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.position = Vector3(0, 3.4, -1.0)
	lab.add_child(light)
	return lab


# -----------------------------------------------------------------------------
# Shapes
# -----------------------------------------------------------------------------
func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(c, 0.4)
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	# A box you can't walk through
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	_box(body, size, Vector3.ZERO, mat)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, solid := true) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	if not solid:
		mi.position = pos
		parent.add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = radius
	cs.height = height
	shape.shape = cs
	body.add_child(shape)
	return body


func _label(parent: Node3D, text: String, pos: Vector3, px: int, col: Color, outline := true) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = px
	l.pixel_size = 0.01
	l.modulate = col
	l.position = pos
	if outline:
		l.outline_size = 10
		l.outline_modulate = Color(0.15, 0.08, 0.25)
	else:
		l.outline_size = 0
	parent.add_child(l)
