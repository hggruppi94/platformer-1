class_name RainbowRay
extends Node3D

# The Rainbow Ray (scripts/arsenal.gd): hold Shoot and a short striped rainbow beam shines from it. An enemy in the
# beam fills up with colour (a glowing rainbow bubble round it that grows and changes hue), and once it's full it
# pops (Arsenal.hit). Let go and the colour slowly drains out of anyone half full. The Double Rainbow (V5) shines
# right through everyone in a row; before that, the first one in the way stops it. A rolled-up Crocodillo's shell
# keeps the colour out. It uses ammo while it's on (StarPopper drains it).
# Mods: Bounce bends the beam once off a wall or the ground, Split makes it two beams a little apart, and Freeze leaves
# a frosty puff where someone pops.
# StarPopper keeps one of these while the Rainbow Ray is out and calls shine() every physics frame Shoot is held.

const WIDTH := 0.05
const SPREAD := 0.12                      # radians between the two beams with Split
const STRIPES := [Color(1.0, 0.45, 0.6), Color(1.0, 0.85, 0.3), Color(0.45, 1.0, 0.6), Color(0.4, 0.8, 1.0),
	Color(0.75, 0.55, 1.0)]

var shooter: CollisionObject3D
var length := 10.0
var fill_time := 1.4
var pierce := false
var fills := {}                           # enemy -> 0..1 (tests read it)
var on := false                           # shining this frame
var ends: Array[Vector3] = []             # where each beam piece ended last frame (tests read them)
var _lit := {}                            # enemies in the beam this frame
var _beams: Array[Node3D] = []
var _hum: AudioStreamPlayer3D


func _ready() -> void:
	name = "RainbowRay"
	top_level = true
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = GadgetSfx.stream("rainbow_hum")
	_hum.bus = "SFX"
	_hum.volume_db = -10.0
	add_child(_hum)


func shine(from: Vector3, dir: Vector3, stats: Dictionary) -> void:
	# One frame of the beam, from `from` along `dir`
	length = float(stats.get("radius", 10.0))
	fill_time = float(stats.get("time", 1.4))
	pierce = bool(stats.get("pierce", false))
	on = true
	_lit = {}
	ends = []
	var pieces: Array = []                # [from, to] pairs to draw
	var dirs := [dir]
	if Arsenal.has_mod("rainbow", "split"):
		var side := dir.cross(Vector3.UP).normalized()
		dirs = [(dir + side * SPREAD).normalized(), (dir - side * SPREAD).normalized()]
	for d in dirs:
		var bends := 1 if Arsenal.has_mod("rainbow", "bounce") else 0
		var start := from
		var go: Vector3 = d
		var left := length
		while left > 0.1:
			var hit := _cast(start, go, left)
			var stop: Vector3 = hit.get("position", start + go * left)
			pieces.append([start, stop])
			ends.append(stop)
			if hit.is_empty() or bends <= 0:
				break
			bends -= 1                     # the Bounce mod: off the wall it goes
			left -= start.distance_to(stop)
			go = go.bounce(hit.normal)
			start = stop + hit.normal * 0.05
	_draw_beams(pieces)
	if not _hum.playing:
		_hum.play()
	_hum.global_position = from


func _cast(from: Vector3, dir: Vector3, reach: float) -> Dictionary:
	# Along the beam: lights up enemies (all of them with pierce, else just the first) and stops at scenery
	var skip: Array[RID] = []
	if shooter:
		skip.append(shooter.get_rid())
	for k in 8:
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
		q.exclude = skip
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return {}
		var t := StarBubble._target(hit.collider as Node)
		if t == null:
			return hit
		if t.is_in_group("ammo_crates"):
			t.shot(1, hit.position, dir)
			return hit
		if t.get("defeated") != true:
			_lit[t] = true
		if not pierce:
			return hit
		skip.append((hit.collider as CollisionObject3D).get_rid())
	return {}


func _physics_process(delta: float) -> void:
	# Fill the ones in the beam, drain the rest; pop any that are full
	for e in _lit.keys():
		if not is_instance_valid(e) or e.get("defeated") == true:
			continue
		if e.has_method("shelled") and e.shelled():
			continue                                  # the shell keeps the colour out
		fills[e] = float(fills.get(e, 0.0)) + delta / maxf(fill_time, 0.1)
	for e in fills.keys():
		if not is_instance_valid(e) or e.get("defeated") == true:
			_clear(e)
			continue
		if not _lit.has(e):
			fills[e] = float(fills[e]) - delta / maxf(fill_time, 0.1) * 0.5
			if float(fills[e]) <= 0.0:
				_clear(e)
				continue
		_aura(e, float(fills[e]))
		if float(fills[e]) >= 1.0:
			var at := (e as Node3D).global_position + Vector3(0, 0.5, 0)
			_clear(e)
			Arsenal.hit(e, 99, Vector3.UP, "rainbow")
			Arsenal.impact(at, "rainbow", get_parent())
			for c in STRIPES:
				Fx.burst(get_parent(), at, c, 6, 0.06, 3.0, -1.0, 0.6)
			Audio.play_at("rainbow_pop", at, -3.0, 0.1)
	if not on:
		_draw_beams([])
		if _hum.playing:
			_hum.stop()
	on = false
	_lit = {}


func stop() -> void:
	on = false


func _clear(e: Variant) -> void:
	fills.erase(e)
	if is_instance_valid(e):
		var a := (e as Node).get_node_or_null("RainbowFill")
		if a:
			a.queue_free()


func _aura(e: Node3D, f: float) -> void:
	# A glowing bubble of colour round it that grows as it fills and goes round the rainbow
	var a := e.get_node_or_null("RainbowFill") as MeshInstance3D
	var size := float(e.get("size") if e.get("size") != null else 1.0)
	if a == null:
		a = MeshInstance3D.new()
		a.name = "RainbowFill"
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		a.mesh = s
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		a.material_override = m
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.add_child(a)
		a.position = Vector3(0, 0.45 * size, 0)
	var c: Color = STRIPES[int(f * 9.0) % STRIPES.size()]
	(a.material_override as StandardMaterial3D).albedo_color = Color(c, 0.25 + 0.35 * f)
	a.scale = Vector3.ONE * size * (0.6 + 0.8 * clampf(f, 0.0, 1.0))


func _draw_beams(pieces: Array) -> void:
	while _beams.size() < pieces.size():
		_beams.append(_beam())
	for i in _beams.size():
		var b := _beams[i]
		b.visible = i < pieces.size()
		if not b.visible:
			continue
		var a: Vector3 = pieces[i][0]
		var z: Vector3 = pieces[i][1]
		var span := a.distance_to(z)
		if span < 0.01:
			b.visible = false
			continue
		var up := Vector3.UP if absf((z - a).normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		b.global_transform = Transform3D(Basis.looking_at(z - a, up), (a + z) / 2.0)
		b.scale = Vector3(1, 1, span)


func _beam() -> Node3D:
	# Stripes of colour side by side, one metre long along -Z (scaled to length)
	var root := Node3D.new()
	add_child(root)
	for k in STRIPES.size():
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(WIDTH, WIDTH, 1.0)
		mi.mesh = bm
		var m := StarBubble._flat(STRIPES[k])
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((k - (STRIPES.size() - 1) / 2.0) * WIDTH, 0, 0)
		root.add_child(mi)
	return root


func _exit_tree() -> void:
	for e in fills.keys():
		_clear(e)


static func build_prop() -> Node3D:
	# In her hand: a white wand-blaster with a prism on the end and rainbow bands. Nozzle towards +Z.
	var root := Node3D.new()
	root.name = "Popper"
	root.set_meta("gadget", "rainbow")
	var white := StarPopper._mat(Color(0.95, 0.95, 1.0), 0.3)
	var body := StarPopper._part(root, CylinderMesh.new(), white, Vector3(0, 0.03, 0.1), Vector3(PI / 2, 0, 0))
	(body.mesh as CylinderMesh).top_radius = 0.04
	(body.mesh as CylinderMesh).bottom_radius = 0.055
	(body.mesh as CylinderMesh).height = 0.26
	for k in STRIPES.size():
		var band := StarPopper._part(root, TorusMesh.new(), StarPopper._mat(STRIPES[k], 0.3), Vector3(0, 0.03, 0.0 + 0.04 * k),
			Vector3(PI / 2, 0, 0))
		(band.mesh as TorusMesh).inner_radius = 0.045
		(band.mesh as TorusMesh).outer_radius = 0.058
	var prism := StarPopper._part(root, PrismMesh.new(), StarPopper._glass(), Vector3(0, 0.03, 0.27), Vector3(PI / 2, 0, 0))
	(prism.mesh as PrismMesh).size = Vector3(0.09, 0.09, 0.07)
	var grip := StarPopper._part(root, BoxMesh.new(), StarPopper._mat(Color(0.62, 0.5, 0.95), 0.4),
		Vector3(0, -0.06, 0.03), Vector3(-0.3, 0, 0))
	(grip.mesh as BoxMesh).size = Vector3(0.05, 0.12, 0.06)
	return root
