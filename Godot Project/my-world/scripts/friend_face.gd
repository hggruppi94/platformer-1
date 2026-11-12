extends CanvasLayer

# The friend's face on the HUD (plan item 26, the party system's second slice). Party (scripts/party.gd) puts one on
# the player as "FriendFace", so a cutscene that puts the player's HUD away (scripts/chaos_ending.gd _hide_hud() and
# friends) puts this away too, and it goes with the scene.
#
# Bottom left: a round badge with the face of whoever's with you (FriendWheel.face()) and the Friend button under it,
# so a kid always knows who's along and what to press. With nobody along it's an empty circle with the wheel's button.
# When someone else could help right here (Flurry by water: Party.helper()), a little face bubble pops up beside the
# badge and bobs, with a "!": pressing Friend swaps them in and they do it (Party.use()).

const SIZE := 64.0                    # the badge's width at text size 1
const MARGIN := 20.0
const UP := 120.0                     # how far its bottom sits above the screen's bottom (sound captions go below)

var shown := ""                       # whose face the badge shows ("" nobody); for tests
var helper := ""                      # who the bubble shows ("" none)
var _draw_node: Control
var _bob := 0.0
var _check := 0.0


func _ready() -> void:
	layer = 5
	_draw_node = Control.new()
	_draw_node.name = "Badge"
	_draw_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_paint)
	add_child(_draw_node)


func badge_shown() -> bool:
	return visible and _draw_node.visible


func _process(delta: float) -> void:
	_bob += delta
	_check -= delta
	if _check <= 0.0:
		_check = 0.1
		var want := Party.badge_wanted()
		_draw_node.visible = want
		if want:
			shown = Party.badge_who()
			helper = Party.helper()
	if _draw_node.visible:
		_draw_node.queue_redraw()


func badge_rect() -> Rect2:
	# Where the badge is on screen
	var s := Settings.text_scale
	var vp := _draw_node.size
	var d := SIZE * s
	return Rect2(Vector2(MARGIN, vp.y - UP - d - 24.0 * s), Vector2(d, d))


func _paint() -> void:
	var s := Settings.text_scale
	var r := badge_rect()
	var c := r.get_center()
	var rad := r.size.x / 2.0
	var font := UiStyle.font()
	_draw_node.draw_circle(c, rad + 4.0, UiStyle.INK)
	_draw_node.draw_circle(c, rad + 2.0, UiStyle.TEAL if shown != "" else Color(0.45, 0.4, 0.55))
	FriendWheel.face(_draw_node, shown, c, rad)
	# The button under it: Friend with someone along, the wheel with nobody
	var key := Settings.prompt("friend" if shown != "" else "friend_wheel")
	var fs := roundi(16 * s)
	var w := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0 * s
	var kr := Rect2(Vector2(c.x - w / 2.0, r.end.y + 2.0 * s), Vector2(w, 22.0 * s))
	_draw_node.draw_rect(kr, UiStyle.INK)
	_draw_node.draw_rect(kr.grow(-2.0), Color(0.95, 0.9, 1.0))
	_draw_node.draw_string(font, Vector2(kr.position.x, kr.position.y + 17.0 * s), key, HORIZONTAL_ALIGNMENT_CENTER, w,
		fs, UiStyle.INK)
	if helper == "":
		return
	# Someone who could help here: a bobbing bubble with their face, up and to the right of the badge
	var bc := c + Vector2(rad * 1.55, -rad * 0.9 + sin(_bob * 5.0) * 4.0 * s)
	var br := rad * 0.62
	_draw_node.draw_line(c + Vector2(rad * 0.7, -rad * 0.5), bc + Vector2(-br * 0.7, br * 0.6), Color(1, 1, 1, 0.8),
		3.0 * s, true)
	_draw_node.draw_circle(bc, br + 4.0, UiStyle.GOLD)
	FriendWheel.face(_draw_node, helper, bc, br)
	var tip := bc + Vector2(br * 0.8, -br * 0.8)
	_draw_node.draw_circle(tip, 11.0 * s, UiStyle.GOLD)
	_draw_node.draw_string(font, tip + Vector2(-11.0 * s, 6.0 * s), "!", HORIZONTAL_ALIGNMENT_CENTER, 22.0 * s,
		roundi(17 * s), UiStyle.INK)
