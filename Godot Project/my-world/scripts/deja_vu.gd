extends Node

# The fuzzy deja vu of coming home (Hayden, 12 Nov 2026: "lets stick with the memories stay the same but you have a
# bit of fuzzy deja vu memory when you go back home"; lore bible v2, section 5). A node "DejaVu" under the EarthTown
# autoload (scripts/earth_town.gd).
#
# Every time the hero lands in Stars Hollow straight from the Void (the Shift's pull home, a portal trip's end, the
# oak's door, a bed in the Void...), the screen goes soft and dreamy for a few seconds: a gentle blur and a lilac haze
# that ripple and settle, and a line says how it feels. Nothing is forgotten: the quests, the friends and everything
# in the bag all stay. It just feels like waking from a dream you can still remember.
#
# Not on the First Night's way home: that one wakes up in bed with its own "Was it all a dream?" (scripts/first_night.gd).
# Coming home from the Earth race circuit or the title screen isn't coming back from the Void, so nothing happens then.

const VOID_LOOK := preload("res://scripts/void_look.gd")
const EARTH := "res://scenes/earth/earth.tscn"
const TIME := 3.6                         # seconds the haze takes to clear
const LINE_AFTER := 0.9                   # seconds before the line shows (after the loading screen's gone)
const LINES := [
	"Back home. The Void feels like a dream...",
	"Wasn't the sky green a minute ago?",
	"Home again. The watch is still ticking.",
	"Home. But it feels like you've been far away...",
]

var homecomings := 0                      # how many times it's played this session (picks the next line)
var off := false                          # tests and tools can turn it off
var _was_void := false                    # the scene before this one was in the Void
var _layer: CanvasLayer


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var from_void := _was_void
	_was_void = VOID_LOOK.in_void(scene)
	if scene.scene_file_path != EARTH or not from_void or off:
		return
	var first_night := get_node_or_null("/root/FirstNight")
	if first_night and first_night.call("running") and str(first_night.call("step")) == "home":
		return
	play()


func play() -> void:
	# The haze and the line (also callable on its own, for capture tools)
	homecomings += 1
	var who := Dialogue.player_name()
	var line := str(LINES[(homecomings - 1) % LINES.size()]).replace("{who}", who)
	_haze()
	get_tree().create_timer(LINE_AFTER).timeout.connect(func() -> void: Game.message(line))


func last_line() -> String:
	return str(LINES[(homecomings - 1) % LINES.size()]).replace("{who}", Dialogue.player_name()) if homecomings > 0 else ""


func _haze() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = CanvasLayer.new()
	_layer.name = "DejaVu Haze"
	_layer.layer = 0                      # over the world, under the HUD: the line itself stays sharp
	add_child(_layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	# A soft blur that ripples a little, washed in the Void's lilac, fading as the memory settles
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 1.0;
uniform float wobble = 1.0;
uniform float t = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * 18.0 + t * 3.0) * 0.006 * amount * wobble;
	uv.y += cos(uv.x * 14.0 + t * 2.4) * 0.004 * amount * wobble;
	vec3 col = textureLod(screen, uv, amount * 3.5).rgb;
	float r = length(SCREEN_UV - vec2(0.5));
	vec3 lilac = vec3(0.82, 0.72, 1.0);
	float haze = amount * (0.35 + 0.35 * smoothstep(0.2, 0.75, r));
	COLOR = vec4(mix(col, lilac, haze), 1.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("wobble", 0.0 if Settings.reduce_motion else 1.0)
	rect.material = mat
	_layer.add_child(rect)
	var layer := _layer
	var tw := layer.create_tween()
	tw.tween_method(func(v: float) -> void:
		mat.set_shader_parameter("amount", v)
		mat.set_shader_parameter("t", (1.0 - v) * TIME), 1.0, 0.0, TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)
