extends CanvasLayer

# The flow: pick up a whole set of a race's speed coins (scripts/race_track.gd _place_coins, Races._take_coins) and
# for a while you're a little quicker (Skate.flow_speed) and the edges of the screen go blurry and a bit melty and
# colourful (race_flow.gdshader). Hayden, 14 Nov 2026: "Once the player picks up a full "set" of coins, they enter a
# "flow" state where their speed is slightly increased and the screen becomes a little bit blurred on the edges and
# maybe psychedelic-melty a little bit."
#
# A node "Flow" under Races. Another set while you're in the flow tops it back up. Reduce motion: no melting wobble;
# Reduce flashing: calmer colours. No class_name on purpose (preload it).

const SHADER := preload("res://scripts/race_flow.gdshader")
const TIME := 8.0                    # seconds in the flow
const SPEED := 2.0                   # how much quicker (metres a second on pushing and top speed)
const IN := 2.5                      # how quickly it fades in (strength a second)...
const OUT := 0.8                     # ...and out

var left := 0.0                      # seconds of flow left
var strength := 0.0                  # how far in the flow (0 to 1): the look and the speed follow it
var times := 0                       # how many times you've got into the flow (for tests)
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	layer = 1                                        # over the world, under the HUD and menus (like the underwater view)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Flow View"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


func start() -> void:
	left = TIME
	times += 1


func active() -> bool:
	return left > 0.0


func stop() -> void:
	# The race is over (or called off): straight out of it
	left = 0.0
	strength = 0.0
	_apply()


func _process(delta: float) -> void:
	left = maxf(0.0, left - delta)
	strength = move_toward(strength, 1.0 if left > 0.0 else 0.0, delta * (IN if left > 0.0 else OUT))
	_apply()


func _apply() -> void:
	_rect.visible = strength > 0.001
	_mat.set_shader_parameter("strength", strength)
	_mat.set_shader_parameter("melt", 0.0 if Settings.reduce_motion else 1.0)
	_mat.set_shader_parameter("colour", 0.35 if Settings.reduce_flashing else 1.0)
	var p := get_tree().get_first_node_in_group("player")
	var skate = p.get("skate") if p else null
	if skate != null and is_instance_valid(skate):
		skate.set("flow_speed", SPEED * strength)
