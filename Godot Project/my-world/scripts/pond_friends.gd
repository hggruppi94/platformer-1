extends Node

# The Lily Pond in the Void's south meadow, and the two who hang about it (Nov 25, 2026, the Meshy trial): Hermez, a
# red-crowned crane who carries letters all over the Void (models/characters/hermez.glb, built our usual way by
# tools/build_hermez.py), and Rolo, a small curious rhino kid (models/characters/rolo.glb, made with Meshy's AI tool for
# the trial). Both are from Sofi's show notes; neither has a routine yet, so like the Astronaut and Granny Purl they
# stand in one spot playing their "idle" (scripts/npc.gd) and talk from dialogue/hermez.json and dialogue/rolo.json.
# Rolo only appears once his model is in the project, so the pond works with or without him.
#
# A "PondFriends" node under the Watches autoload, like the Knitting Class: nothing's built into town.tscn. When the
# town loads it puts in a little raised garden pond (a ring of mossy stones you can't walk through, still water, lily
# pads with pink flowers, reeds), shows it on the map, and stands the two of them on its shore facing the meadow.

const TOWN := "res://scenes/town/town.tscn"
const POND := Vector2(-5.0, 79.0)             # flat open meadow south of the lake, 26 m+ from any path (checked)
const POND_R := 3.6                           # the water's radius; the stones sit just outside it
const ROOT := "Lily Pond"
const FRIENDS := {
	"hermez": {"name": "Hermez", "model": "res://models/characters/hermez.glb", "at": Vector2(-2.6, -4.3),
		"face": -0.35, "height": 1.7, "radius": 0.34},
	"rolo": {"name": "Rolo", "model": "res://models/characters/rolo.glb", "at": Vector2(2.4, -4.6),
		"face": 0.3, "height": 1.3, "radius": 0.38},
}

var _scene: Node


func _process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s == _scene:
		return
	_scene = s
	if s and s.scene_file_path == TOWN:
		_place.call_deferred(s)


func pond() -> Node3D:
	var s := get_tree().current_scene
	return s.get_node_or_null(ROOT) as Node3D if s and s.scene_file_path == TOWN else null


func friend(id: String) -> Node3D:
	var p := pond()
	return p.get_node_or_null(str(FRIENDS[id].name)) as Node3D if p else null


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(str(FRIENDS[id].model))


func _place(s: Node) -> void:
	if not is_instance_valid(s) or s.get_node_or_null(ROOT) != null:
		return
	var root := Node3D.new()
	root.name = ROOT
	root.set_script(load("res://scripts/landmark.gd"))
	root.set("label", ROOT)
	s.add_child(root)
	root.global_position = _ground(s as Node3D, POND)
	_build_pond(root)
	for id in FRIENDS:
		if has_model(id):
			root.add_child(_friend(id, root))


func _ground(s: Node3D, at: Vector2) -> Vector3:
	var space := s.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, 40, at.y), Vector3(at.x, -20, at.y))
	var hit := space.intersect_ray(q)
	return hit.position if hit else Vector3(at.x, 0, at.y)


# ---------------------------------------------------------------- the pond
func _build_pond(root: Node3D) -> void:
	var water := MeshInstance3D.new()
	water.name = "Water"
	var disc := CylinderMesh.new()
	disc.top_radius = POND_R + 0.15
	disc.bottom_radius = POND_R + 0.15
	disc.height = 0.12
	disc.radial_segments = 48
	water.mesh = disc
	var wm := _mat(Color(0.05, 0.2, 0.42), 0.35)        # a deep blue, so it reads against the teal meadow
	wm.metallic_specular = 0.25
	water.material_override = wm
	water.position.y = 0.12
	root.add_child(water)
	# A ring of mossy stones round the edge, solid, so you step over to the water's edge rather than into it
	var stones := StaticBody3D.new()
	stones.name = "Stones"
	root.add_child(stones)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2511
	var n := 22
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.04, 0.04)
		var r := POND_R + 0.35
		var size := Vector3(rng.randf_range(0.7, 0.95), rng.randf_range(0.32, 0.45), rng.randf_range(0.55, 0.7))
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		stone.mesh = sm
		stone.scale = size
		stone.position = Vector3(cos(a) * r, size.y * 0.35, sin(a) * r)
		stone.rotation.y = -a
		stone.material_override = _mat(Color(0.47, 0.45, 0.52).lerp(Color(0.38, 0.5, 0.35), rng.randf() * 0.5), 0.9)
		stones.add_child(stone)
	var ring := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = POND_R + 0.7
	cyl.height = 0.5
	ring.shape = cyl
	ring.position.y = 0.25
	stones.add_child(ring)
	# Lily pads with a few pink flowers
	var pad_m := _mat(Color(0.2, 0.55, 0.22), 0.7)
	var petal_m := _mat(Color(0.95, 0.55, 0.75), 0.6)
	var heart_m := _mat(Color(1.0, 0.85, 0.3), 0.5)
	for i in 11:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (POND_R - 0.6)
		var pad := MeshInstance3D.new()
		pad.name = "Lily Pad %d" % i
		var pm := CylinderMesh.new()
		var pr := rng.randf_range(0.28, 0.48)
		pm.top_radius = pr
		pm.bottom_radius = pr
		pm.height = 0.02
		pm.radial_segments = 20
		pad.mesh = pm
		pad.material_override = pad_m
		pad.position = Vector3(cos(a) * r, 0.19, sin(a) * r)
		root.add_child(pad)
		if i % 3 == 0:
			for k in 6:
				var petal := MeshInstance3D.new()
				var pe := SphereMesh.new()
				pe.radius = 0.06
				pe.height = 0.12
				petal.mesh = pe
				petal.scale = Vector3(0.9, 0.7, 1.8)
				var b := TAU * k / 6
				petal.position = Vector3(cos(b) * 0.08, 0.06, sin(b) * 0.08)
				petal.rotation = Vector3(0.5, -b + PI / 2, 0)
				petal.material_override = petal_m
				pad.add_child(petal)
			var heart := MeshInstance3D.new()
			var hm := SphereMesh.new()
			hm.radius = 0.04
			hm.height = 0.08
			heart.mesh = hm
			heart.position.y = 0.07
			heart.material_override = heart_m
			pad.add_child(heart)
	# Reeds on the far side
	var reed_m := _mat(Color(0.35, 0.5, 0.2), 0.8)
	var cat_m := _mat(Color(0.35, 0.2, 0.1), 0.8)
	for i in 14:
		var a := PI * 0.15 + rng.randf() * PI * 0.7
		var r := POND_R + rng.randf_range(-0.4, 0.9)
		var reed := MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.015
		rm.bottom_radius = 0.025
		var h := rng.randf_range(0.9, 1.5)
		rm.height = h
		reed.mesh = rm
		reed.material_override = reed_m
		reed.position = Vector3(cos(a) * r, h / 2, sin(a) * r)
		reed.rotation = Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
		root.add_child(reed)
		if i % 2 == 0:
			var cat := MeshInstance3D.new()
			var cm := CapsuleMesh.new()
			cm.radius = 0.045
			cm.height = 0.26
			cat.mesh = cm
			cat.material_override = cat_m
			cat.position.y = h / 2 - 0.12
			reed.add_child(cat)


# ---------------------------------------------------------------- the friends
func _friend(id: String, root: Node3D) -> Node3D:
	var f: Dictionary = FRIENDS[id]
	var p := Node3D.new()
	p.name = str(f.name)
	p.set_script(load("res://scripts/npc.gd"))
	p.set("animation", "idle")
	var m := (load(str(f.model)) as PackedScene).instantiate() as Node3D
	m.name = "Model"
	p.add_child(m)
	var talk := Area3D.new()
	talk.name = "Talk"
	talk.set_script(load("res://scripts/talker.gd"))
	talk.set("character_id", id)
	talk.set("display_name", str(f.name))
	talk.set("name_height", float(f.height) + 0.3)
	p.add_child(talk)
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = float(f.radius)
	cap.height = float(f.height)
	cs.shape = cap
	cs.position.y = float(f.height) / 2
	body.add_child(cs)
	p.add_child(body)
	var at: Vector2 = f.at
	p.position = Vector3(at.x, 0, at.y)
	var g := _ground(get_tree().current_scene as Node3D, POND + at)
	p.position.y = g.y - root.global_position.y
	p.rotation.y = PI + float(f.face)             # the models face +Z; PI turns them out of the pond, to the meadow
	return p


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m
