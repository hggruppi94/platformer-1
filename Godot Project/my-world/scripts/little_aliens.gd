class_name LittleAliens
extends Node3D

# The little aliens: Galaxity's background crowd of tiny space kids in shiny hooded suits (Hayden's sheet,
# 2026-10-27; models from tools/build_little_aliens.py). Some potter about on the ground, on roofs and up walls
# (scripts/little_alien.gd), some zip round in tiny flying saucers, and a few just float along on boot jets
# (scripts/mini_saucer.gd). Pure scenery: nothing to talk to, nothing that gets in the way.
#
# They're scattered at random over the whole town when it loads. To keep the town feeling busy wherever the player
# goes, walkers that end up far away are quietly moved to a fresh random spot near them, behind the camera when it
# can manage it, and walkers too far off to see are hidden and stop thinking.

const COLOURS := ["blue", "purple", "yellow", "red", "pink", "orange", "green"]
const SHOW_DISTANCE := 70.0              # walkers further than this are hidden and paused
const MOVE_DISTANCE := 85.0              # ...and further than this get moved somewhere near the player
const WALL_CHANCE := 0.3                 # how many are put on a wall when they're placed...
const ROOF_CHANCE := 0.35                # ...and how many on a roof or the top of something

@export var walkers := 30
@export var saucers := 7
@export var jetpacks := 4
@export var area := Rect2(-135, -245, 270, 340)       # x, z of the town, clear of its edge walls

var _models: Array[PackedScene] = []
var _walkers: Array[Node3D] = []
var _flyers: Array[Node3D] = []
var _player: Node3D
var _exclude: Array[RID] = []
var _started := false
var _check := 0.0


# Whether a ray hit is something real an alien may stand on or land on: not the town's invisible edge walls, not
# water, not a character or anything that moves.
# Gives one alien a snout of its own size: each colour has its own snout shape (tools/build_little_aliens.py) on a
# "snout" bone, and here it's stretched longer or shorter, fatter or thinner, so no two in a crowd look the same.
# The bone's scale isn't animated, so any scale tracks the exporter baked for it are dropped first (the animations
# are shared by every alien of that colour, so this only does real work once).
static func vary_snout(model: Node) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var bone := skel.find_bone("snout") if skel else -1
	if bone < 0:
		return
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for a_name in anim.get_animation_list():
			var a := anim.get_animation(a_name)
			for t in range(a.get_track_count() - 1, -1, -1):
				if a.track_get_type(t) == Animation.TYPE_SCALE_3D and str(a.track_get_path(t)).ends_with(":snout"):
					a.remove_track(t)
	var length := randf_range(0.55, 1.8)                 # the bone runs out from the face along its own Y
	var width := lerpf(1.0, length, 0.45) * randf_range(0.8, 1.25)
	skel.set_bone_pose_scale(bone, Vector3(width, length, width))


static func walkable(hit: Dictionary) -> bool:
	var body := hit.get("collider") as Node
	if body == null or not (body is StaticBody3D) or body.is_in_group("player"):
		return false
	var path := str(body.get_path())
	if path.contains("WorldBounds") or path.contains("/Characters/"):
		return false
	if path.contains("Terrain") and (hit.position as Vector3).y < -0.45:   # the lake bed (the water's at -0.6)
		return false
	return true


func _ready() -> void:
	for c in COLOURS:
		_models.append(load("res://models/characters/little_alien_%s.glb" % c))


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player is CollisionObject3D:
			_exclude = [(_player as CollisionObject3D).get_rid()]
	if not _started:
		_started = true                                 # the physics world is ready by now, so rays can find roofs
		_spawn_all()
		return
	_check -= delta
	if _check > 0.0 or _player == null:
		return
	_check = 0.5
	var moved := 0
	for w in _walkers:
		var d := w.global_position.distance_to(_player.global_position)
		w.visible = d < SHOW_DISTANCE
		w.process_mode = Node.PROCESS_MODE_INHERIT if w.visible else Node.PROCESS_MODE_DISABLED   # animations too
		if d > MOVE_DISTANCE and moved < 2:              # a couple at a time, so nothing pops in a crowd
			moved += 1
			_drop(w, _near_player())


func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in walkers:
		var w: Node3D = _models[i % _models.size()].instantiate()
		w.name = "LittleAlien%d" % i
		w.set_script(load("res://scripts/little_alien.gd"))
		w.set("climbs", rng.randf() < 0.7)
		w.set("exclude", _exclude)
		add_child(w)
		_walkers.append(w)
		# A third start near the player so there's always someone about; the rest anywhere in town
		_drop(w, _near_player() if i < walkers / 3 else _anywhere())
	for i in saucers + jetpacks:
		var f := Node3D.new()
		f.name = ("MiniSaucer%d" % i) if i < saucers else ("Jetpack%d" % (i - saucers))
		f.set_script(load("res://scripts/mini_saucer.gd"))
		f.set("jetpack", i >= saucers)
		f.set("area", Rect2(area.position + Vector2(10, 10), area.size - Vector2(20, 20)))
		f.set("exclude", _exclude)
		f.set("pilot", _models[(i * 3 + 1) % _models.size()].instantiate())
		var at := _anywhere()
		f.position = at + Vector3(0, randf_range(8.0, 25.0), 0)
		f.scale = Vector3.ONE * 1.2
		add_child(f)
		_flyers.append(f)


# Puts a walker down on a random surface around a spot: the top of whatever's there, or the side of something.
func _drop(w: Node3D, centre: Vector3) -> void:
	# Most of the town is open grass, so it looks harder for the fun places: walls for the climbers, then roofs and
	# the tops of things, and only settles for the ground when it can't find those
	var space := get_world_3d().direct_space_state
	var r := randf()
	var want := "wall" if r < WALL_CHANCE and w.get("climbs") else ("top" if r < WALL_CHANCE + ROOF_CHANCE else "ground")
	var fallback := {}
	for attempt in 40:
		if attempt == 25:
			want = "ground"
		var spread := 14.0 * (1.0 + attempt / 8.0)
		var x := clampf(centre.x + randf_range(-spread, spread), area.position.x, area.end.x)
		var z := clampf(centre.z + randf_range(-spread, spread), area.position.y, area.end.y)
		var top := _ray(space, Vector3(x, 150, z), Vector3(x, -10, z))
		if top.is_empty():
			continue
		var on_ground := str(top.collider.get_path()).contains("Terrain")
		if fallback.is_empty() and (top.normal as Vector3).y > 0.5:
			fallback = top
		if want == "wall":
			var from: Vector3 = top.position + Vector3.UP * randf_range(0.8, 3.5)
			var a0 := randf() * TAU
			for k in 8:
				var a := a0 + k * TAU / 8.0
				var side := _ray(space, from, from + Vector3(cos(a), 0, sin(a)) * 25.0)
				if side and absf((side.normal as Vector3).y) < 0.4:
					w.place(side.position, side.normal)
					return
			continue
		if want == "top" and (on_ground or (top.normal as Vector3).y < 0.5):
			continue
		if (top.normal as Vector3).y < 0.5 and not w.get("climbs"):
			continue
		w.place(top.position, top.normal)
		return
	if not fallback.is_empty():
		w.place(fallback.position, fallback.normal)


func _near_player() -> Vector3:
	if _player == null:
		return _anywhere()
	# Somewhere 20 to 50 m off, behind the camera when there is one
	var back := Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	if cam:
		back = cam.global_transform.basis.z
		back.y = 0.0
	var a := atan2(back.z, back.x) + randf_range(-1.4, 1.4) if back.length() > 0.1 else randf() * TAU
	var r := randf_range(20.0, 50.0)
	return _player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)


func _anywhere() -> Vector3:
	return Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = _exclude
	var hit := space.intersect_ray(q)
	if hit and not walkable(hit):
		return {}
	return hit
