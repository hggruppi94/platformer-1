extends Node3D

# The Off-Beat, Rhythm Springs' boss (plan item 19a world 4, scripts/rhythm_springs.gd): a stage-sized wooden metronome
# with a grumpy face, stuck between two tempos. His arm swings with a red-hot weight on it, lurching from slow to quick
# and back, and that's what broke the world's beat. He stands at the back of the Bandstand, asleep until you've found
# all three Song Shells and come near.
#
# The fight (kid-safe, like every boss: bumps and no harm):
#   - Each time his arm reaches the end of a swing he ticks, and a heat ring rolls out across the stage (ShockRing):
#     jump it. When he's on his quick tempo only every other tick sends one.
#   - One of the four drum pads round the stage lights up on his tick. Jump onto it while it's lit and its BOOM knocks
#     him back towards the beat (a hit). A bubble at his red-hot weight counts too (once a second).
#   - He swaps tempo every few seconds, and under half he gets cross: his quick tempo's quicker.
#   - HITS hits put him back in time: he shrinks to a little metronome ticking steadily, and the world mends.

const SHOT_TARGET := preload("res://scripts/shot_target.gd")
const HITS := 8
const SLOW := 1.2                          # seconds a swing takes on his slow tempo...
const QUICK := 0.55                        # ...and his quick one (quicker still when he's cross)
const TEMPO_EVERY := Vector2(4.0, 6.0)     # seconds between tempo swaps
const RING_REACH := 13.0
const RING_DAMAGE := 1
const DRUM_R := 1.1
const DRUM_TOP := 0.5
const SHOT_GAP := 1.0
const WEIGHT_HOT := Color(1.0, 0.4, 0.15)
const WOOD := Color(0.62, 0.36, 0.26)

var world: Node                            # Rhythm Springs, told when he's back in time
var drum_spots: Array = []                 # where the four drum pads stand (global positions, on the stage)
var awake := false
var hits := 0
var defeated := false
var quick := false
var cross := false
var lit_drum := -1
var ticks := 0
var _swing := 0.0                          # 0..1 through one swing; the arm's angle follows it
var _side := 1.0
var _tempo_t := 5.0
var _lit_for := 0
var _used := false                         # the lit drum's been jumped on already
var _shot_cd := 0.0
var _wobble := 0.0
var _said_tempo := false
var _arm: Node3D
var _weight: Node3D
var _drums: Array = []                     # [Node3D, StandardMaterial3D]
var _bar: BossBar
var _zzz: Label3D
var _player: CharacterBody3D


func _ready() -> void:
	var m := model()
	m.name = "Model"
	add_child(m)
	_arm = m.get_node("Arm")
	_weight = m.get_node("Arm/Weight")
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.2, 7.0, 2.6)
	cs.shape = bs
	cs.position.y = 3.5
	body.add_child(cs)
	add_child(body)
	var hit := SHOT_TARGET.new() as StaticBody3D
	hit.name = "Hit"
	hit.on_shot = func() -> String: return "hit" if shot_weight() else "bounce"
	var hcs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.8
	hcs.shape = sp
	hit.add_child(hcs)
	_weight.add_child(hit)
	for i in drum_spots.size():
		var d := drum_model()
		d.name = "Drum %d" % (i + 1)
		get_parent().add_child.call_deferred(d)
		d.position = drum_spots[i]
		_drums.append([d, d.get_meta("skin")])
	_bar = BossBar.make(self, "The Off-Beat", Color(1.0, 0.55, 0.3), 8.4, 2.2)
	_bar.show_within = 0.0                 # (hidden while he sleeps: it shows once he wakes)
	_zzz = Label3D.new()
	_zzz.name = "Snoring"
	_zzz.text = "tick...  z z z  ...tock"
	_zzz.font_size = 64
	_zzz.pixel_size = 0.01
	_zzz.outline_size = 12
	_zzz.modulate = Color(1.0, 0.9, 0.75)
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.position = Vector3(0, 8.0, 0)
	add_child(_zzz)


func wake() -> void:
	if awake or defeated:
		return
	awake = true
	_bar.show_within = 26.0
	if _zzz:
		_zzz.queue_free()
		_zzz = null
	_tempo_t = randf_range(TEMPO_EVERY.x, TEMPO_EVERY.y)
	Juice.shake(0.35)
	Juice.rumble(0.5, 0.3, 0.5)
	Juice.blip("pop", 0.5, -2.0)
	Game.message("The Off-Beat wakes up: TICK... TOCK-TICK-TICK! Jump on the drum that lights up, and jump his heat rings!")


func swing_len() -> float:
	return (QUICK * (0.8 if cross else 1.0)) if quick else SLOW


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_shot_cd -= delta
	_wobble = maxf(_wobble - delta * 2.0, 0.0)
	var model := get_node_or_null("Model") as Node3D
	if model:
		model.rotation.z = sin(_wobble * 30.0) * _wobble * 0.15
	if defeated:
		_arm.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * PI / 0.7) * 0.4          # ticking steadily at last
		return
	if not awake:
		_arm.rotation.z = sin(Time.get_ticks_msec() / 1000.0 * 0.6) * 0.1                # dozing, barely swinging
		return
	_swing += delta / swing_len()
	if _swing >= 1.0:
		_swing -= 1.0
		_side = -_side
		tick()
	_arm.rotation.z = _side * lerpf(-0.55, 0.55, (1.0 - cos(_swing * PI)) / 2.0)
	_tempo_t -= delta
	if _tempo_t <= 0.0:
		_tempo_t = randf_range(TEMPO_EVERY.x, TEMPO_EVERY.y)
		quick = not quick
		if not _said_tempo:
			_said_tempo = true
			Game.message("He's lurched onto his %s tempo! He can't make up his mind." % ("QUICK" if quick else "slow"))
	_check_drum()


func tick() -> void:
	# The end of a swing: a heat ring (every tick when slow, every other when quick), and the lit drum moves on
	ticks += 1
	Juice.blip("tick", 0.6 if quick else 0.45, -2.0)
	if not quick or ticks % 2 == 0:
		ShockRing.spawn(get_parent(), global_position + Vector3(0, 0.05, 2.5), RING_REACH, WEIGHT_HOT, RING_DAMAGE, 1.1 if quick else 1.4)
		Fx.burst(get_parent(), _weight.global_position, WEIGHT_HOT, 8, 0.08, 2.0, 1.0, 0.5)
	_lit_for -= 1
	if _lit_for <= 0 or lit_drum < 0:
		_light_drum()


func _light_drum() -> void:
	var was := lit_drum
	var pick := randi() % maxi(_drums.size(), 1)
	if _drums.size() > 1 and pick == was:
		pick = (pick + 1 + randi() % (_drums.size() - 1)) % _drums.size()
	lit_drum = pick if _drums.size() > 0 else -1
	_lit_for = 3 if quick else 2
	_used = false
	_show_drums()


func _show_drums() -> void:
	for i in _drums.size():
		var mat := _drums[i][1] as StandardMaterial3D
		var on := i == lit_drum and not _used and awake and not defeated
		mat.emission_enabled = on
		mat.emission = Color(1.0, 0.6, 0.1)
		mat.emission_energy_multiplier = 1.6
		mat.albedo_color = Color(1.0, 0.65, 0.15) if on else Color(0.85, 0.8, 0.72)


func _check_drum() -> void:
	# Landing on the lit drum (on top of it, on your feet) is a hit
	if lit_drum < 0 or _used or _player == null or not _player.is_on_floor():
		return
	var d := _drums[lit_drum][0] as Node3D
	var p := _player.global_position
	if Vector2(p.x - d.global_position.x, p.z - d.global_position.z).length() < DRUM_R \
			and p.y > d.global_position.y + DRUM_TOP + 0.3:
		hit_drum(lit_drum)


func hit_drum(i: int) -> bool:
	if not awake or defeated or i != lit_drum or _used:
		return false
	_used = true
	_show_drums()
	var d := _drums[i][0] as Node3D
	Juice.squash(d, 0.35)
	Fx.burst(get_parent(), d.global_position + Vector3(0, 0.8, 0), Color(1.0, 0.85, 0.35), 20, 0.1, 4.0, -1.0, 0.8)
	Audio.play_at("stomp", d.global_position, 0.0, 0.0)
	if _player:
		_player.bounce(8.0)
	_hurt("BOOM! The drum's beat knocks him back towards the rhythm!")
	return true


func shot_weight() -> bool:
	if not awake or defeated or _shot_cd > 0.0:
		return false
	_shot_cd = SHOT_GAP
	_hurt("Your bubble pops on his red-hot weight with a hiss!")
	return true


func _hurt(why: String) -> void:
	hits += 1
	_wobble = 1.0
	_bar.fill = 1.0 - float(hits) / HITS
	Juice.hitstop(0.05)
	Juice.shake(0.2)
	Juice.blip("pop", 0.8, -3.0)
	if hits >= HITS:
		_back_in_time()
		return
	var left := HITS - hits
	Game.message("%s %s" % [why, ("%d more!" % left) if left > 1 else "One more!"])
	if not cross and hits * 2 >= HITS:
		cross = true
		Game.message("The Off-Beat's cross now! His quick tempo's even quicker.")


func _back_in_time() -> void:
	defeated = true
	awake = false
	lit_drum = -1
	_show_drums()
	_bar.show_within = 0.0
	Juice.hitstop(0.09)
	Juice.shake(0.6)
	Juice.rumble(0.7, 0.4, 0.7)
	Game.message("The Off-Beat's back in time! TICK. TOCK. TICK. TOCK. He's shrinking down to a happy little metronome...")
	var model := get_node_or_null("Model") as Node3D
	var tw := create_tween()
	if model:
		tw.tween_property(model, "scale", Vector3.ONE * 0.3, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	var body := get_node_or_null("Body")
	if body:
		body.queue_free()
	if world and world.has_method("mend"):
		world.mend()


# Looks -------------------------------------------------------------------------------------------------------------
static func _m(c: Color, emit := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.scale = scale
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func model() -> Node3D:
	# A huge wooden metronome: a tall four-sided body narrowing to the top, a gold scale down its front, a grumpy face
	# with heavy brows, and an arm pivoting at the bottom with a red-hot weight on it. Faces +Z.
	var g := Node3D.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.9
	body.bottom_radius = 2.6
	body.height = 7.0
	body.radial_segments = 4
	_mesh(g, body, _m(WOOD, 0.0, 0.6), Vector3(0, 3.5, 0), Vector3.ONE, Vector3(0, PI / 4.0, 0))
	var base := BoxMesh.new()
	base.size = Vector3(4.6, 0.6, 3.0)
	_mesh(g, base, _m(Color(0.42, 0.24, 0.18), 0.0, 0.6), Vector3(0, 0.3, 0))
	var gold := _m(Color(1.0, 0.8, 0.4), 0.3, 0.3)
	var scale_strip := BoxMesh.new()
	scale_strip.size = Vector3(0.7, 4.6, 0.05)
	_mesh(g, scale_strip, gold, Vector3(0, 3.6, 1.5), Vector3.ONE, Vector3(-0.22, 0, 0))
	for k in 8:
		var tick := BoxMesh.new()
		tick.size = Vector3(0.5 if k % 2 == 0 else 0.3, 0.06, 0.06)
		_mesh(g, tick, _m(Color(0.3, 0.18, 0.12)), Vector3(0, 1.8 + k * 0.5, 1.6 - k * 0.11), Vector3.ONE, Vector3(-0.22, 0, 0))
	# The face, near the top
	var white := _m(Color(1, 0.98, 0.94))
	var dark := _m(Color(0.12, 0.08, 0.1))
	var eye := SphereMesh.new()
	eye.radius = 0.32
	eye.height = 0.64
	var pupil := SphereMesh.new()
	pupil.radius = 0.15
	pupil.height = 0.3
	var brow := BoxMesh.new()
	brow.size = Vector3(0.6, 0.14, 0.12)
	for s in [-1.0, 1.0]:
		_mesh(g, eye, white, Vector3(s * 0.45, 6.0, 0.95))
		_mesh(g, pupil, dark, Vector3(s * 0.42, 5.95, 1.22))
		_mesh(g, brow, dark, Vector3(s * 0.45, 6.42, 1.08), Vector3.ONE, Vector3(0, 0, s * 0.35))
	var mouth := TorusMesh.new()
	mouth.inner_radius = 0.18
	mouth.outer_radius = 0.26
	_mesh(g, mouth, dark, Vector3(0, 5.35, 1.1), Vector3(1.2, 1.0, 0.5), Vector3(PI / 2.0, 0, 0))
	# The arm: pivots at the bottom, out in front of the scale
	var arm := Node3D.new()
	arm.name = "Arm"
	arm.position = Vector3(0, 1.2, 1.9)
	g.add_child(arm)
	var rod := CylinderMesh.new()
	rod.top_radius = 0.08
	rod.bottom_radius = 0.1
	rod.height = 6.2
	_mesh(arm, rod, _m(Color(0.85, 0.85, 0.9), 0.0, 0.3), Vector3(0, 3.1, 0))
	var weight := Node3D.new()
	weight.name = "Weight"
	weight.position = Vector3(0, 4.2, 0)
	arm.add_child(weight)
	var w := CylinderMesh.new()
	w.top_radius = 0.45
	w.bottom_radius = 0.65
	w.height = 0.9
	w.radial_segments = 6
	_mesh(weight, w, _m(WEIGHT_HOT, 2.2, 0.4), Vector3.ZERO)
	var light := OmniLight3D.new()
	light.light_color = WEIGHT_HOT
	light.light_energy = 1.6
	light.omni_range = 5.0
	weight.add_child(light)
	var knob := SphereMesh.new()
	knob.radius = 0.4
	knob.height = 0.8
	_mesh(g, knob, gold, Vector3(0, 7.1, 0))
	return g


static func drum_model() -> Node3D:
	# A big floor drum to jump on: red sides with gold zigzags and a cream skin that glows gold when it's lit
	var g := Node3D.new()
	var side := CylinderMesh.new()
	side.top_radius = DRUM_R
	side.bottom_radius = DRUM_R
	side.height = DRUM_TOP
	side.radial_segments = 20
	_mesh(g, side, _m(Color(0.9, 0.3, 0.3), 0.0, 0.6), Vector3(0, DRUM_TOP / 2.0, 0))
	var skin_mat := _m(Color(0.95, 0.9, 0.82), 0.0, 0.5)
	var skin := CylinderMesh.new()
	skin.top_radius = DRUM_R - 0.05
	skin.bottom_radius = DRUM_R - 0.05
	skin.height = 0.04
	skin.radial_segments = 20
	_mesh(g, skin, skin_mat, Vector3(0, DRUM_TOP + 0.02, 0))
	g.set_meta("skin", skin_mat)
	var gold := _m(Color(1.0, 0.8, 0.4), 0.3, 0.3)
	for k in 10:
		var a := k * TAU / 10.0
		var zig := BoxMesh.new()
		zig.size = Vector3(0.08, DRUM_TOP * 0.8, 0.04)
		_mesh(g, zig, gold, Vector3(cos(a) * (DRUM_R + 0.01), DRUM_TOP / 2.0, sin(a) * (DRUM_R + 0.01)), Vector3.ONE,
			Vector3(0, -a, 0.5 if k % 2 == 0 else -0.5))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = DRUM_R
	c.height = DRUM_TOP
	cs.shape = c
	cs.position.y = DRUM_TOP / 2.0
	body.add_child(cs)
	g.add_child(body)
	return g
