extends Node

# Pip's glow, the player's own: Lanternmoor's reward (scripts/lanternmoor.gd). Like Bramble's burrow, Flurry's frost
# breath and Melody's groove it's locked until Pip's world is mended: before Portals.is_cleared("lanternmoor") nothing
# here happens at all. Pip teaches it as the sun comes up (lanternmoor.gd _teach_glow()).
#
# There's no button (every controller button is already something, and it's kinder for small hands): once it's yours
# the glow comes on by itself whenever it's dark. Inside a dark place (a "cave_dark" zone, made by
# scripts/cave_kit.gd dark_zone()) the hero shines brightly, lighting RADIUS metres round them, with little motes of
# light drifting round; out of doors at night (the Void's night, Earth's evening) it's a soft little glow.
#
# Caves are built for it:
#   - "cave_dark" zones: while the hero's inside one the screen's edges go dark. Without the glow it's nearly black.
#     The caves' own rock never sees the sun or the sky's light (scripts/cave_kit.gd shade_from_sun()), so only the
#     glow and the caves' own crystals and mushrooms light it.
#   - "glow_reveal" things are only there while the glow reaches them (they fade in and out): moth-dust markings,
#     hidden things to find.
#   - "glow_solid" things (StaticBody3Ds: the planks of a glow bridge) are only there, and only solid, while the glow
#     reaches them, so a bridge seems to grow out ahead of you as you walk.
#   - "glow_wake" things get glow_wake() called the first time the glow reaches them (crystals that wake and keep
#     shining: scripts/glow_crystal.gd).
# Other scripts can ask shining() and lights(pos).
#
# Made by the player (scenes/player/player.gd _ready).

signal glow_changed(on: bool)

const WORLD := "lanternmoor"              # the world whose mending unlocks it
const RADIUS := 9.0                       # how far it reaches in the dark
const NIGHT_RADIUS := 5.0                 # ...and out of doors at night
const COLOUR := Color(1.0, 0.86, 0.62)    # Pip's warm lantern gold
const ENERGY := 2.0
const NIGHT_ENERGY := 0.7
const FADE := 3.0                         # how quickly things fade in and out of the glow (per second)
const MOTES := 8

var player: CharacterBody3D
var in_dark := false                      # inside a cave_dark zone (tests read it)
var at_night := false
var force := false                        # tests: shine whatever the time, once unlocked
var strength := 0.0                       # 0 off, 1 full: eased
var shown := {}                           # glow_reveal / glow_solid node -> how shown it is, 0..1
var woken := 0                            # glow_wake things woken (for the tests)
var _on := false
var _light: OmniLight3D
var _motes: Node3D
var _t := 0.0
var _overlay: CanvasLayer
var _shade: ColorRect
var _dark := 0.0                          # eased in_dark


func setup(p: CharacterBody3D) -> void:
	player = p
	_light = OmniLight3D.new()
	_light.name = "Pip Glow"
	_light.light_color = COLOUR
	_light.light_energy = 0.0
	_light.omni_range = RADIUS
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = false
	_light.visible = false
	_light.position = Vector3(0, 1.1, 0)
	player.add_child.call_deferred(_light)
	_motes = Node3D.new()
	_motes.name = "Glow Motes"
	_motes.visible = false
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOUR
	m.emission_enabled = true
	m.emission = COLOUR
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	ball.radial_segments = 6
	ball.rings = 3
	for i in MOTES:
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.add_child(mi)
	player.add_child.call_deferred(_motes)


func unlocked() -> bool:
	var portals := get_node_or_null("/root/Portals")
	return portals != null and portals.is_cleared(WORLD)


func shining() -> bool:
	return _on


func radius() -> float:
	return RADIUS if in_dark or force else NIGHT_RADIUS


func lights(pos: Vector3) -> bool:
	return _on and player != null and player.global_position.distance_to(pos) <= radius()


func _night() -> bool:
	var clock := get_node_or_null("/root/Clock")
	if clock == null:
		return false
	var scene := get_tree().current_scene
	if scene and scene.get("world_id") != null:
		return false                                   # a portal world keeps its own sky, whatever the clock says
	if clock.get("on_earth"):
		var h: int = clock.hour()
		return h >= 20 or h < 6
	return clock.is_night()


func _process(delta: float) -> void:
	if player == null or not player.is_inside_tree():
		return
	_t += delta
	in_dark = false
	for z in get_tree().get_nodes_in_group("cave_dark"):
		if z is Node3D and z.is_inside_tree() and CaveZone.in_zone(z, player.global_position + Vector3(0, 0.5, 0)):
			in_dark = true
			break
	at_night = _night()
	var on := unlocked() and (in_dark or at_night or force)
	if on != _on:
		_on = on
		glow_changed.emit(on)
	strength = move_toward(strength, 1.0 if on else 0.0, delta * 2.0)
	_dark = move_toward(_dark, 1.0 if in_dark else 0.0, delta * 1.5)
	var full := in_dark or force
	_light.visible = strength > 0.01
	_light.light_energy = strength * (ENERGY if full else NIGHT_ENERGY)
	_light.omni_range = radius()
	_light.position.y = 1.1 + sin(_t * 1.7) * 0.05
	_motes.visible = strength > 0.05 and full
	if _motes.visible:
		for i in _motes.get_child_count():
			var a := _t * (0.6 + i * 0.07) + i * TAU / MOTES
			var mo := _motes.get_child(i) as Node3D
			mo.position = Vector3(cos(a) * (0.7 + 0.15 * sin(_t + i)), 0.6 + 0.5 * sin(_t * 0.9 + i * 1.3),
				sin(a) * (0.7 + 0.15 * cos(_t + i)))
			mo.scale = Vector3.ONE * strength
	_reveal(delta)
	_darken()


func _reveal(delta: float) -> void:
	var tree := get_tree()
	var r := radius()
	var here := player.global_position
	for n in tree.get_nodes_in_group("glow_wake"):
		if n is Node3D and n.is_inside_tree() and _on and here.distance_to((n as Node3D).global_position) <= r:
			if not n.get("awake"):
				woken += 1
				n.call("glow_wake")
	var seen := {}
	for group in ["glow_reveal", "glow_solid"]:
		for n in tree.get_nodes_in_group(group):
			if not (n is Node3D) or not n.is_inside_tree():
				continue
			seen[n] = true
			var lit := _on and here.distance_to((n as Node3D).global_position) <= r
			var k: float = move_toward(shown.get(n, 0.0), 1.0 if lit else 0.0, delta * FADE)
			shown[n] = k
			_show(n as Node3D, k, group == "glow_solid")
	for n in shown.keys():
		if not seen.has(n):
			shown.erase(n)


static func _show(n: Node3D, k: float, solid: bool) -> void:
	n.visible = k > 0.03
	for c in n.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).transparency = 1.0 - k
	if solid:
		for c in n.find_children("*", "CollisionShape3D", true, false):
			var cs := c as CollisionShape3D
			var off := k < 0.5
			if cs.disabled != off:
				cs.set_deferred("disabled", off)


func is_shown(n: Node) -> bool:
	return shown.get(n, 0.0) > 0.5


# The dark round the edges of the screen in a cave: nearly black without the glow, a soft frame with it
func _darken() -> void:
	if _dark <= 0.001:
		if _overlay:
			_overlay.visible = false
		return
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.name = "Cave Dark"
		_overlay.layer = 1
		_shade = ColorRect.new()
		_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform float dark = 0.0;
uniform float hole = 0.5;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.55)) * vec2(1.6, 1.0);
	float edge = smoothstep(hole * 0.35, hole, length(d));
	COLOR = vec4(0.02, 0.01, 0.05, dark * mix(0.25, 1.0, edge));
}"""
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_shade.material = mat
		_overlay.add_child(_shade)
		player.add_child(_overlay)
	_overlay.visible = true
	var glowing := strength
	var mat := _shade.material as ShaderMaterial
	mat.set_shader_parameter("dark", _dark * lerpf(0.94, 0.55, glowing))
	mat.set_shader_parameter("hole", lerpf(0.35, 1.05, glowing))


# Shared with cave_kit.gd, which can't be referred to by class name here (no class_name on purpose)
class CaveZone:
	static func in_zone(zone: Node3D, p: Vector3) -> bool:
		var size: Vector3 = zone.get_meta("size", Vector3.ZERO)
		var q := zone.global_transform.affine_inverse() * p
		return absf(q.x) <= size.x * 0.5 and absf(q.y) <= size.y * 0.5 and absf(q.z) <= size.z * 0.5
