extends Node

# Granny Purl's Knitting Class in the castle school (Hayden, 21 Nov 2026: "Witch lady is a teacher"). She's a yarn
# witch granny: lavender skin, silver curls with knitting needles in her bun, a dark knit dress, pearls, gold yarn
# looped round her, and Snag, her little green goblin pet, on her shoulder (models/characters/yarn_granny.glb, built by
# tools/build_yarn_granny.py; Hayden's TV still was only inspiration, she's our own). Her name and Snag's are working
# names until Hayden picks.
#
# A "KnittingClass" node under the Watches autoload, like the Council (scripts/council.gd): when the school loads it
# turns the 2nd floor's empty Classroom C (x 12..25, z -10..3, doors on its west and south sides) into her classroom,
# with a yarn board on the north wall, nine little desks with yarn and needles, baskets of wool and a rocking chair.
# She stands at the front knitting (her "idle"), and talks from dialogue/yarn_granny.json. Nothing's rebuilt: it's all
# put in at play time.

const SCHOOL := "res://scenes/school/school.tscn"
const FLOOR_2 := "Floor 2"
const ROOM_MIN := Vector2(12.0, -10.0)
const ROOM_MAX := Vector2(25.0, 3.0)
const GRANNY_AT := Vector2(18.5, -7.6)        # at the front, by the yarn board, looking down at the desks
const MODEL := "res://models/characters/yarn_granny.glb"
const NAME := "Granny Purl"
const ID := "yarn_granny"
const ROOM_NAME := "Knitting Class"
# The desks keep a clear way between the two doors (west door at z -3.5, south door at x 18.5) and round her
const DESKS := [Vector2(14.6, -5.2), Vector2(22.4, -5.2),
	Vector2(14.6, -1.8), Vector2(22.4, -1.8),
	Vector2(14.6, 1.2), Vector2(22.4, 1.2)]
const YARN := [Color(0.85, 0.3, 0.45), Color(0.35, 0.55, 0.9), Color(0.95, 0.75, 0.3), Color(0.45, 0.75, 0.45),
	Color(0.7, 0.45, 0.85)]

var _scene: Node


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s == _scene:
		return
	_scene = s
	if s and s.scene_file_path == SCHOOL:
		_place.call_deferred(s)


func granny() -> Node3D:
	var s := get_tree().current_scene
	if s == null or s.scene_file_path != SCHOOL:
		return null
	return s.get_node_or_null("%s/%s/%s" % [FLOOR_2, ROOM_NAME, NAME]) as Node3D


func _place(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null(FLOOR_2) == null:
		return
	var floor_2 := s.get_node(FLOOR_2) as Node3D
	if floor_2.get_node_or_null(ROOM_NAME) != null:
		return
	var room := Node3D.new()
	room.name = ROOM_NAME
	floor_2.add_child(room)
	var c := (ROOM_MIN + ROOM_MAX) / 2
	for l in floor_2.find_children("*", "Label3D", true, false):
		var at := floor_2.to_local((l as Label3D).global_position)
		if (l as Label3D).text == "Classroom C" and Vector2(at.x, at.z).distance_to(c) < 0.5:
			(l as Label3D).text = ROOM_NAME
	_sign(room, "KNITTING CLASS\n%s" % NAME, Vector3(ROOM_MIN.x - 0.25, 2.9, -1.6), -PI / 2)
	_furnish(room)
	# (25 Nov 2026) The desks and chair wear the baked maple, the rug, cushions and baskets the woven cloth
	load("res://scripts/detail_props.gd").dress_place(room, CLASS_SURFACES)
	room.add_child(_granny())


func _granny() -> Node3D:
	var p := Node3D.new()
	p.name = NAME
	p.set_script(load("res://scripts/npc.gd"))
	p.set("animation", "idle")                    # knitting
	var packed := load(MODEL) as PackedScene
	if packed:
		var m := packed.instantiate() as Node3D
		m.name = "Model"
		p.add_child(m)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", ID)
	talk.set("display_name", NAME)
	talk.set("name_height", 2.0)
	p.add_child(talk)
	# Solid, so nobody walks through her
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.8
	body.add_child(cs)
	p.add_child(body)
	p.position = Vector3(GRANNY_AT.x, 0, GRANNY_AT.y)
	p.rotation.y = 0.0                            # the model faces +Z: down the room, at the desks
	return p


# Which of the room's materials wear which baked patch (detail_props.gd dress_place)
const CLASS_SURFACES := [["Class Wood", "maple", 0.6], ["Class Rug", "tweed", 0.8], ["Class Cushion", "tweed", 0.5],
	["Class Wicker", "tweed", 0.4]]


func _furnish(room: Node3D) -> void:
	var c := (ROOM_MIN + ROOM_MAX) / 2
	var wood := _mat(Color(0.5, 0.32, 0.2), 0.8, 0.0, "Class Wood")
	_box(room, Vector3(11.0, 0.03, 10.0), Vector3(c.x, 0.015, c.y), _mat(Color(0.55, 0.32, 0.5), 0.8, 0.0, "Class Rug"))      # rug
	# The yarn board on the north wall: a cork board with a knitted heart, a star and a scarf pinned on it
	_box(room, Vector3(5.0, 2.0, 0.08), Vector3(c.x, 2.2, ROOM_MIN.y + 0.12), _mat(Color(0.72, 0.55, 0.38)))
	_box(room, Vector3(5.2, 2.2, 0.06), Vector3(c.x, 2.2, ROOM_MIN.y + 0.08), wood)
	for k in 3:
		var bit := _ball(room, 0.28, Vector3(c.x - 1.6 + k * 1.6, 2.3, ROOM_MIN.y + 0.2), _mat(YARN[k]))
		bit.scale = Vector3(1.2, 1.0, 0.3)
	_label(room, "Knit one, purl one!", Vector3(c.x, 3.45, ROOM_MIN.y + 0.18), 0.0, 40)
	# Her rocking chair and a basket of wool beside it
	_box(room, Vector3(0.8, 0.12, 0.8), Vector3(GRANNY_AT.x + 1.6, 0.5, GRANNY_AT.y - 0.6), _mat(Color(0.45, 0.25, 0.5), 0.8, 0.0, "Class Cushion"))
	_box(room, Vector3(0.8, 1.1, 0.1), Vector3(GRANNY_AT.x + 1.6, 1.0, GRANNY_AT.y - 1.0), wood)
	for side in [-1, 1]:
		_box(room, Vector3(0.06, 0.1, 1.1), Vector3(GRANNY_AT.x + 1.6 + side * 0.36, 0.08, GRANNY_AT.y - 0.6), wood)
	_basket(room, Vector3(GRANNY_AT.x - 1.6, 0, GRANNY_AT.y - 0.4))
	_basket(room, Vector3(ROOM_MAX.x - 1.0, 0, ROOM_MIN.y + 1.0))
	# Little desks in two columns (the middle's an aisle from the south door up to her), each with a ball of yarn, two needles stuck in it and a stool
	for i in DESKS.size():
		var d: Vector2 = DESKS[i]
		_box(room, Vector3(1.3, 0.06, 0.8), Vector3(d.x, 0.75, d.y), wood)
		for sx in [-0.55, 0.55]:
			for sz in [-0.32, 0.32]:
				_box(room, Vector3(0.06, 0.75, 0.06), Vector3(d.x + sx, 0.375, d.y + sz), wood)
		var col: Color = YARN[i % YARN.size()]
		_ball(room, 0.13, Vector3(d.x - 0.2, 0.9, d.y), _mat(col, 0.9))
		for k in 2:
			var n := _box(room, Vector3(0.02, 0.02, 0.4), Vector3(d.x - 0.2 + (k - 0.5) * 0.06, 0.98, d.y + 0.05),
				_mat(Color(0.85, 0.75, 0.55), 0.4, 0.6))
			n.rotation = Vector3(0.6, (k - 0.5) * 0.4, 0)
		_box(room, Vector3(0.45, 0.45, 0.45), Vector3(d.x, 0.225, d.y + 0.75), _mat(col.darkened(0.25), 0.8, 0.0, "Class Cushion"))
		var desk := StaticBody3D.new()
		desk.name = "Desk %d" % (i + 1)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.3, 0.8, 0.8)
		cs.shape = box
		cs.position = Vector3(d.x, 0.4, d.y)
		desk.add_child(cs)
		room.add_child(desk)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.86, 0.72)
	lamp.light_energy = 0.9
	lamp.omni_range = 9.0
	lamp.position = Vector3(c.x, 4.2, c.y)
	room.add_child(lamp)


func _basket(room: Node3D, at: Vector3) -> void:
	var b := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.34
	cyl.height = 0.45
	b.mesh = cyl
	b.material_override = _mat(Color(0.65, 0.48, 0.28), 0.8, 0.0, "Class Wicker")
	b.position = at + Vector3(0, 0.225, 0)
	room.add_child(b)
	for k in 4:
		var a := k * TAU / 4.0
		_ball(room, 0.16, at + Vector3(cos(a) * 0.17, 0.5, sin(a) * 0.17), _mat(YARN[(k + 1) % YARN.size()], 0.9))


func _sign(parent: Node3D, text: String, at: Vector3, yaw: float, size := 34) -> Label3D:
	var l := _label(parent, text, at, yaw, size)
	l.name = "Class Sign"
	return l


func _label(parent: Node3D, text: String, at: Vector3, yaw: float, size := 34) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = Color(1.0, 0.92, 0.98)
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l


func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi


func _mat(colour: Color, rough := 0.8, metal := 0.0, id := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = id                     # (named ones get the detail pipeline's patches: CLASS_SURFACES)
	m.albedo_color = colour
	m.roughness = rough
	m.metallic = metal
	return m
