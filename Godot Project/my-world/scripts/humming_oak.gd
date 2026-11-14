extends Node

# Autoload "HummingOak": the old oak on the green (tools/build_earth.gd _portal builds the tree, its hollow, its runes
# and roots). It hums because the **Divine Mind** is there (Hayden, lore bible v2, 12 Nov 2026), and once the hero's
# been chosen you can **touch it for a hint** about what to do next: the Divine Mind's voice answers in your mind
# (DivineMind.hint()). From then on the crack to the Void opens in front of it every Shift (scripts/earth_world.gd).
#
# On a new game's first day it's just a big old tree. Since 13 Nov 2026 there's no quest to wake it (Hayden: "the
# glowing tree quest should be scrapped and getting pulled into the void should be a seemingly more random
# occurrence"): at the first midnight a crack opens right under the hero, wherever they are (scripts/void_arrival.gd),
# and that sets "oak_woken". Old saves and anyone who isn't on the First Night's Earth day find it awake already, so
# nobody is ever locked out. Nothing of its own to save.

const EARTH := "res://scenes/earth/earth.tscn"
const ID := "first_night"
# Steps of the First Night before the hero's first fall (it's just a tree for them)
const ASLEEP_STEPS := ["morning", "board", "evening", "oak", "clues", "dusk", "wait", "awaken"]
const FLIES := 26

var _scene: Node3D
var _oak: Node3D                   # "Portal Home/Old Oak"
var _spot: Area3D
var _rune_mat: StandardMaterial3D
var _rune_light: OmniLight3D
var _rune_glow := 0.0
var _flies: Array[MeshInstance3D] = []
var _fly_t := 0.0
var _fly_gather := 0.0             # 0: drifting about, 1: spiralling up the trunk (the Shift)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().scene_changed.connect(_on_scene_changed)
	Quests.changed.connect(func(q: String) -> void:
		if q == ID:
			_refresh())
	Dialogue.flag_set.connect(func(_f: String) -> void: _refresh())


# -----------------------------------------------------------------------------
# Is the oak awake?
# -----------------------------------------------------------------------------
func awake() -> bool:
	# Asleep only on a First Night that hasn't had its fall yet; awake for everyone else, for good
	if Dialogue.flags.has("oak_woken"):
		return true
	# (a new game whose hero isn't made yet is about to start The First Night: no crack showing on its first morning)
	if Game.needs_creator:
		return false
	if not FirstNight.running():
		return true
	return not FirstNight.step() in ASLEEP_STEPS


# -----------------------------------------------------------------------------
# Setting it up on Earth
# -----------------------------------------------------------------------------
func _on_scene_changed() -> void:
	var s := get_tree().current_scene
	_scene = null
	_oak = null
	_flies.clear()
	if s == null or s.scene_file_path != EARTH:
		return
	_scene = s as Node3D
	_oak = s.get_node_or_null("Portal Home/Old Oak") as Node3D
	if _oak == null:
		return
	var rune := _oak.get_node_or_null("Oak Runes")
	if rune and rune.get_child_count() > 0:
		_rune_mat = (rune.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	_rune_light = _oak.get_node_or_null("Rune Glow") as OmniLight3D
	_spot = (load("res://scripts/request_spot.gd") as GDScript).new() as Area3D
	_spot.name = "Oak Spot"
	_spot.set("verb", "look at the old oak")
	_spot.set("radius", 1.8)
	_spot.set("jobs", self)
	_spot.position = Vector3(0.9, 0.0, 2.3)
	_oak.add_child(_spot)
	var flies := Node3D.new()
	flies.name = "Fireflies"
	_oak.add_child(flies)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.85, 1.0, 0.5)
	fm.emission_enabled = true
	fm.emission = Color(0.85, 1.0, 0.45)
	fm.emission_energy_multiplier = 4.0
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	sm.radial_segments = 6
	sm.rings = 3
	for k in FLIES:
		var f := MeshInstance3D.new()
		f.mesh = sm
		f.material_override = fm
		f.set_meta("seed", randf() * 100.0)
		flies.add_child(f)
		_flies.append(f)
	_refresh()


func _refresh() -> void:
	if _scene == null or not is_instance_valid(_scene) or _oak == null:
		return
	if _spot:
		_spot.set("verb", "touch the old oak" if awake() else "look at the old oak")


# -----------------------------------------------------------------------------
# Talking to the oak (its spot: scripts/request_spot.gd calls talk())
# -----------------------------------------------------------------------------
func talk(spot: Node3D) -> void:
	Dialogue.say(spot, "The Old Oak", lines(), "old_oak")


func lines() -> Array:
	if not awake():
		return ["(It's a big old oak tree, much older than the town. Its leaves are every colour of autumn.)",
			"(For a moment you'd swear it hummed. Then it's just a tree again.)"]
	return touch_lines()


func touch_lines() -> Array:
	# Touching the awake oak: its hum goes right through you, and a voice in your mind gives a hint
	var out: Array = ["(You lay your hand on the old oak's bark. It's humming, deep and warm, and the hum goes right through you...)"]
	if not Dialogue.flags.has("oak_voice_heard"):
		Dialogue.set_flag("oak_voice_heard")
		out.append({"speaker": DivineMind.SPEAKER, "text": "Don't be afraid. I chose you, {player}. Whenever you're lost, come and touch the old oak, and I'll help you find the way."})
	for l in DivineMind.hint():
		out.append({"speaker": DivineMind.SPEAKER, "text": str(l)})
	return out


# -----------------------------------------------------------------------------
# Every frame: the runes and the fireflies
# -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _oak == null or not is_instance_valid(_oak):
		return
	_fly_t += delta
	# The runes: dark until the hero's been chosen, then a faint glow by day and bright in the Shift
	var want := 0.0
	if awake():
		want = 2.4 if Clock.in_shift() else 0.35
	_rune_glow = move_toward(_rune_glow, want, delta * 1.5)
	if _rune_mat:
		_rune_mat.emission_energy_multiplier = _rune_glow
	if _rune_light:
		_rune_light.light_energy = _rune_glow * 0.9
		_rune_light.visible = _rune_glow > 0.01
	_fireflies(delta)


func _fireflies(delta: float) -> void:
	# Fireflies drift round the oak at night, and spiral up its trunk while the crack's open in the Shift
	var night := Clock.earth_minutes >= 19 * 60.0 or Clock.earth_minutes < 5 * 60.0
	var show := night or Clock.in_shift()
	_fly_gather = move_toward(_fly_gather, 1.0 if Clock.in_shift() and awake() else 0.0, delta * 0.6)
	for k in _flies.size():
		var f := _flies[k]
		f.visible = show
		if not show:
			continue
		var sd := float(f.get_meta("seed"))
		var t := _fly_t * 0.4 + sd
		var drift := Vector3(sin(t * 1.3) * 2.8 + cos(t * 0.7 + sd) * 1.2, 1.2 + sin(t * 0.9) * 0.9 + 0.6 * sin(sd),
			cos(t * 1.1) * 2.8 + sin(t * 0.5) * 1.2)
		drift += drift.normalized() * 1.2 * signf(drift.length() - 1.6)
		var a := _fly_t * 2.2 + k * TAU / _flies.size()
		var climb := fmod(_fly_t * 0.9 + float(k) / _flies.size() * 7.0, 7.0)
		var spiral := Vector3(cos(a) * (1.75 - climb * 0.08), 0.3 + climb, sin(a) * (1.75 - climb * 0.08))
		f.position = drift.lerp(spiral, smoothstep(0.0, 1.0, _fly_gather))
