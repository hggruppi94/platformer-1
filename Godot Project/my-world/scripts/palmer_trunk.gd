extends Node

# Mr. Palmer's trunk and his cup of tea (model: tools/build_mr_palmer_alien.py → models/characters/mr_palmer_alien.glb).
# Put this under MrPalmer in scenes/town/characters.tscn, after his Routine. His idle and walk actions already sway and
# swing the trunk; this adds the "grab" action. During office hours a little tea table stands in front of his spot by
# the Town Hall window, and every so often he reaches out with his trunk, curls it round his teacup, lifts it up for a
# sip and puts it back. The table and cup stay by the window when he goes off on his evening stroll.
# Models face +Z.

const GRAB := "grab"
const TABLE_AHEAD := 0.72                    # metres in front of him: where the trunk tip curls at the bottom of the reach
const TABLE_TOP := 0.78                      # the table top's height; the cup stands on it
const PICK_UP := 0.42                        # parts of the way through the grab action: tip curled round the cup...
const PUT_DOWN := 0.88                       # ...and back down at the table, letting go
const HANG := Vector3(0, -0.075, 0)          # the cup hangs this far under the trunk tip while he holds it
const TIP_BONE_LENGTH := 0.058               # trunk.7 runs this far to the tip (glTF keeps bone heads, not tails)
const WAIT := Vector2(9.0, 18.0)             # seconds between sips

var _body: Node3D
var _routine: Node
var _anim: AnimationPlayer
var _skeleton: Skeleton3D
var _tip: BoneAttachment3D                   # follows the end of the trunk, in step with what's drawn
var _table: Node3D
var _cup: Node3D
var _cup_home := Vector3.ZERO
var _wait := 4.0
var _sipping := false


func _ready() -> void:
	_body = get_parent() as Node3D
	_routine = _body.get_node_or_null("Routine")
	_anim = _body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_skeleton = _body.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton and _skeleton.find_bone("trunk.7") >= 0:
		_tip = BoneAttachment3D.new()
		_tip.name = "TrunkTip"
		_tip.bone_name = "trunk.7"
		_skeleton.add_child(_tip)
	if _anim == null or not _anim.has_animation(GRAB) or _tip == null:
		push_warning("Mr. Palmer: no trunk grab in his model")
		set_physics_process(false)
		return
	# The routine loops every action; the grab plays once and then he goes back to standing
	_anim.get_animation(GRAB).loop_mode = Animation.LOOP_NONE
	_build_table.call_deferred()


func _build_table() -> void:
	# In front of his office-hours spot, facing the way he faces there (his routine's "face" point)
	var paths := TownPaths.get_shared()
	var space := _body.get_world_3d().direct_space_state
	var skip := TownPaths.skip_rids(get_tree().current_scene if get_tree().current_scene else _body.owner)
	var block := _office_block()
	var spot := paths.position_of(str(block.get("place", "palmers_step")), space, skip)
	var f: Array = block.get("face", [spot.x, spot.z + 1.0])
	var ahead := Vector3(float(f[0]) - spot.x, 0, float(f[1]) - spot.z).normalized()
	var at := TownPaths.ground_at(spot + ahead * TABLE_AHEAD, space, skip, 2.0)

	_table = Node3D.new()
	_table.name = "PalmerTeaTable"
	_body.get_parent().add_child(_table)
	_table.global_position = at
	_table.rotation.y = atan2(ahead.x, ahead.z)
	var wood := _mat(Color(0.55, 0.36, 0.62))                  # lilac-stained wood, like the market stalls
	_part(_table, _cyl(0.2, 0.2, 0.04), wood, Vector3(0, TABLE_TOP - 0.02, 0))
	_part(_table, _cyl(0.035, 0.035, TABLE_TOP - 0.04), wood, Vector3(0, (TABLE_TOP - 0.04) / 2.0, 0))
	_part(_table, _cyl(0.14, 0.16, 0.03), wood, Vector3(0, 0.015, 0))

	_cup = Node3D.new()
	_cup.name = "Teacup"
	_table.add_child(_cup)
	var china := _mat(Color(0.98, 0.95, 1.0))
	_part(_cup, _cyl(0.075, 0.075, 0.012), china, Vector3(0, 0.006, 0))               # saucer
	_part(_cup, _cyl(0.05, 0.036, 0.065), china, Vector3(0, 0.044, 0))               # cup
	_part(_cup, _cyl(0.044, 0.044, 0.004), _mat(Color(0.75, 0.42, 0.2)), Vector3(0, 0.074, 0))   # tea
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.012
	ring.outer_radius = 0.022
	handle.mesh = ring
	handle.material_override = china
	handle.rotation.z = PI / 2.0
	handle.position = Vector3(0.055, 0.046, 0)
	_cup.add_child(handle)
	_cup.position = Vector3(0, TABLE_TOP, 0)
	_cup_home = _cup.position


func _process(delta: float) -> void:
	if _table == null:
		return
	var on_duty: bool = _routine == null or (_routine.call("activity") == "office_hours"
		and _routine.call("is_present") and not _routine.call("is_travelling"))
	if _sipping:
		var playing := _anim.current_animation == GRAB and _anim.is_playing()
		var t := _anim.current_animation_position / _anim.current_animation_length if playing else 1.0
		if playing and t >= PICK_UP and t < PUT_DOWN:
			_cup.global_position = tip_position() + HANG
		else:
			_cup.position = _cup_home
		if not playing:
			_sipping = false
			if on_duty:
				_anim.play("idle", 0.25)
		return
	if not on_duty or _body.get("talking"):
		_wait = maxf(_wait, 3.0)
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(WAIT.x, WAIT.y)
		sip()


func sip() -> void:
	# Reach for the teacup now (the test calls this too)
	if _table == null or _sipping:
		return
	_sipping = true
	_anim.play(GRAB, 0.2)


func tip_position() -> Vector3:
	# The very end of the trunk (the bone runs on past its attachment point to the tip)
	return _tip.global_transform * Vector3(0, TIP_BONE_LENGTH, 0)


func is_holding_cup() -> bool:
	return _sipping and _cup.position != _cup_home


func _office_block() -> Dictionary:
	if _routine:
		for b in _routine.get("blocks"):
			if b.get("label", "") == "office_hours":
				return b
	return {}


func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 24
	return m


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


func _part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
