extends Node

# Autoload "QuickOutfits": the quick outfit wheel. The player saves up to six outfits in their wardrobe ("Save this
# outfit", scripts/shop.gd), then holds Outfit wheel (C, L3; Settings > Controls) anywhere outside a talk or a menu to
# open a wheel of them, points at one with the mouse or a stick and lets go to change into it, with a puff of
# sparkles. Like the gadget wheel (scripts/gadget_wheel.gd), the game slows right down while it's open.
#
# A saved outfit is what the hero wears in every slot (Game.outfits["hero"]), their creator colours and their skin
# (scripts/skins.gd), kept in Game.saved_outfits (six places, null for an empty one). Changing into one only puts
# on what the player still owns, so nothing they've lost (or never had, in an odd save) turns up.
#
# This autoload also hands out skins: once a second it checks what's been earned (requests turned in, watches given,
# races run and won) and gives any new one, with a message.

const MAX := 6
const HOLD := 0.2                   # how long the button is held before the wheel opens
const SLOW := 0.2                   # the game's speed while it's open
const PICK := 40.0                  # how far the mouse moves before it points at a slot
const PUFF_COLOURS := [Color(1.0, 0.85, 0.3), Color(0.8, 0.6, 1.0), Color(0.4, 0.95, 0.85), Color(1.0, 0.6, 0.85)]

signal outfit_worn(slot: int)              # the player changed into a saved outfit
signal skin_earned(id: String)

var wheel: OutfitWheel
var _layer: CanvasLayer
var _pressed := false
var _held := 0.0
var _hinted := false
var _skin_check := 0.0
var puffs := 0                      # how many sparkle puffs there have been (for tests)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 34
	add_child(_layer)
	wheel = OutfitWheel.new()
	wheel.name = "Outfit Wheel"
	_layer.add_child(wheel)


# -----------------------------------------------------------------------------
# Saved outfits
# -----------------------------------------------------------------------------
static func clean(data) -> Array:
	return SavedOutfits.clean(data)


func slots() -> Array:
	# Game.saved_outfits, always six places long (an old or odd save can be shorter)
	if Game.saved_outfits.size() != MAX:
		Game.saved_outfits = SavedOutfits.clean(Game.saved_outfits)
	return Game.saved_outfits


func get_slot(i: int):
	return slots()[i] if i >= 0 and i < MAX else null


func count() -> int:
	return slots().filter(func(o) -> bool: return o != null).size()


func save_slot(i: int, outfit_name := "") -> void:
	# What the hero has on now, kept in place i (whatever was there before goes)
	if i < 0 or i >= MAX:
		return
	slots()[i] = {"name": outfit_name if outfit_name != "" else "Outfit %d" % (i + 1),
		"outfit": (Game.outfits.get("hero", {}) as Dictionary).duplicate(),
		"colors": (Game.hero.get("colors", {}) as Dictionary).duplicate(),
		"skin": str(Game.hero.get("skin", ""))}
	Game.save_game()


func forget(i: int) -> void:
	if i >= 0 and i < MAX:
		slots()[i] = null
		Game.save_game()


func describe(o) -> String:
	# One line about a saved outfit: its skin and how many things are in it
	if o == null:
		return "(empty)"
	var n := (o.outfit as Dictionary).size()
	var bits := []
	if str(o.skin) != "":
		bits.append(Skins.skin_name(o.skin))
	bits.append("%d thing%s on" % [n, "" if n == 1 else "s"] if n > 0 else "their own clothes")
	return ", ".join(bits)


func wear(i: int) -> bool:
	# Change into saved outfit i: the clothes in it the player still owns, its colours and its skin
	var o = get_slot(i)
	if o == null:
		return false
	var worn := {}
	for slot in o.outfit:
		var id := str(o.outfit[slot])
		if Shop.owns(id) and Shop.wearable(id):
			worn[Shop.slot_of(id)] = id
	Game.outfits["hero"] = worn
	Game.hero["colors"] = (o.colors as Dictionary).duplicate()
	if str(o.skin) != "" and Skins.owns(o.skin):
		Game.hero["skin"] = str(o.skin)
	else:
		Game.hero.erase("skin")
	Game.equipment_changed.emit()
	Game.save_game()
	_puff()
	outfit_worn.emit(i)
	return true


func wear_skin(id: String) -> void:
	# Put a skin on (or "" to go back to the creator's colours)
	if not Skins.owns(id):
		return
	if id == "":
		Game.hero.erase("skin")
	else:
		Game.hero["skin"] = id
	Game.equipment_changed.emit()
	Game.save_game()


# -----------------------------------------------------------------------------
# The wheel
# -----------------------------------------------------------------------------
func player() -> Node3D:
	var scene := get_tree().current_scene
	return scene.find_child("Player", true, false) as Node3D if scene else null


func can_use() -> bool:
	# Anywhere out in the world, but not in a talk, a menu, the creator, a cutscene or with the gadget wheel up
	var p := player()
	if p == null or not "input_locked" in p or p.input_locked or p.get("carried"):
		return false
	if Dialogue.is_active() or Creator.is_open() or PlayerMenu.is_open() or Shop.is_open() or PauseMenu.is_open():
		return false
	if get_tree().paused:
		return false
	var gw: Node = p.find_child("GadgetWheel", true, false)
	if gw and gw.get("open"):
		return false
	return true


func _process(delta: float) -> void:
	_skin_check -= delta
	if _skin_check <= 0.0:
		_skin_check = 1.0
		check_skins()
	var real := delta / maxf(Engine.time_scale, 0.01)        # the wheel's own timing ignores the slow-down
	if not InputMap.has_action("outfit_wheel"):
		return
	if not can_use():
		if wheel.open:
			close(false)
		_pressed = false
		_held = 0.0
		return
	if Input.is_action_just_pressed("outfit_wheel"):
		_pressed = true
		_held = 0.0
		_hinted = false
	if _pressed and Input.is_action_pressed("outfit_wheel"):
		_held += real
		if _held >= HOLD and not wheel.open:
			if count() > 0:
				open_wheel()
			elif not _hinted:
				_hinted = true
				Game.message("No saved outfits yet!")
	elif _pressed:
		_pressed = false
		if wheel.open:
			close(true)
	if wheel.open:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		var left := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
		if left.length() > stick.length():
			stick = left
		if stick.length() > 0.5:
			point(stick.angle())
		elif wheel.mouse.length() > PICK:
			point(wheel.mouse.angle())


func open_wheel() -> void:
	wheel.open = true
	wheel.mouse = Vector2.ZERO
	wheel.hover = -1
	for i in MAX:                       # start on the first saved one
		if get_slot(i) != null:
			wheel.hover = i
			break
	Engine.time_scale = SLOW
	Audio.play("ui_move", -6.0, 0.0)
	wheel.queue_redraw()


func close(pick: bool) -> void:
	wheel.open = false
	Engine.time_scale = Settings.game_speed       # back to the speed in Settings > Assist
	wheel.queue_redraw()
	if pick and get_slot(wheel.hover) != null:
		Audio.play("ui_accept", -6.0, 0.0)
		wear(wheel.hover)


func point(angle: float) -> void:
	# The saved outfit nearest this direction (empty places can't be picked)
	var best := -1
	var best_d := INF
	for i in MAX:
		if get_slot(i) == null:
			continue
		var d := absf(angle_difference(angle, slot_angle(i)))
		if d < best_d:
			best_d = d
			best = i
	if best != wheel.hover and best >= 0:
		wheel.hover = best
		Audio.play("ui_move", -10.0, 0.0)
		wheel.queue_redraw()


static func slot_angle(i: int) -> float:
	# The first place is at the top, then round clockwise
	return -PI / 2.0 + TAU * i / MAX


func _exit_tree() -> void:
	if wheel and wheel.open:
		Engine.time_scale = Settings.game_speed       # back to the speed in Settings > Assist


# -----------------------------------------------------------------------------
# The sparkle puff
# -----------------------------------------------------------------------------
func _puff() -> void:
	# Little sparkles swirling up round the hero as they change, moved by one tween (one-shot particles only show a few
	# of their bits in their first frames)
	var p := player()
	if p == null or not p.is_inside_tree():
		return
	puffs += 1
	Juice.blip("sparkle", 1.2, -6.0)
	var visual := p.get_node_or_null("Visual") as Node3D
	if visual:
		Juice.squash(visual, 0.18, 0.25)
	var root := Node3D.new()
	root.name = "Outfit Puff"
	p.get_parent().add_child(root)
	root.global_position = p.global_position
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var tw := root.create_tween().set_parallel()
	var n := 30
	var life := 1.0
	for i in n:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PUFF_COLOURS[i % PUFF_COLOURS.size()]
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.6
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(s)
		var ang := TAU * i / n
		var h := 0.2 + 1.4 * float(i) / n
		s.position = Vector3(cos(ang) * 0.35, h, sin(ang) * 0.35)
		s.scale = Vector3.ONE * 0.06
		var out := Vector3(cos(ang + 1.2) * 1.2, h + randf_range(0.3, 0.8), sin(ang + 1.2) * 1.2)
		tw.tween_property(s, "position", out, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ONE * randf_range(0.14, 0.22), life * 0.3).set_trans(Tween.TRANS_BACK)
		tw.tween_property(s, "scale", Vector3.ONE * 0.02, life * 0.6).set_delay(life * 0.4)
		tw.tween_property(mat, "albedo_color:a", 0.0, life * 0.5).set_delay(life * 0.5)
	tw.chain().tween_callback(root.queue_free)


# -----------------------------------------------------------------------------
# Skins
# -----------------------------------------------------------------------------
func check_skins() -> Array[String]:
	# Give any skin that's been earned and not given yet, and say so
	var new: Array[String] = []
	if get_tree().current_scene == null or not get_tree().current_scene.find_child("Player", true, false):
		return new                      # not on the title screen
	for id in Skins.ORDER:
		if not Skins.owns(id) and Skins.earned(id):
			Game.items.append("skin:" + id)
			new.append(id)
			skin_earned.emit(id)
	if not new.is_empty():
		var names := new.map(func(id: String) -> String: return Skins.skin_name(id))
		Game.message("New skin%s: %s! Try %s on in your wardrobe." % ["" if new.size() == 1 else "s", ", ".join(names),
			"it" if new.size() == 1 else "them"])
		Juice.blip("sparkle", 1.0, -6.0)
		Game.save_game()
	return new
