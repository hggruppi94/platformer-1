class_name QuestPicture
extends Control

# A quest card's picture (scripts/quests.gd card()): a round badge in the giver's own colour with the first letter of
# their name, lettered like the rest of the menus (scripts/ui_style.gd), and a gold star on it; finished quests get a
# tick instead of the star.

var letter := "?"
var colour := Color(0.4, 0.8, 0.7)
var done := false


func _draw() -> void:
	var r := minf(size.x, size.y) / 2.0
	var mid := Vector2(r, r)
	draw_circle(mid, r, UiStyle.INK)
	draw_circle(mid, r - 3.0, colour.darkened(0.25))
	draw_circle(mid + Vector2(0, -r * 0.08), r - 6.0, colour)
	draw_arc(mid, r - 1.5, 0, TAU, 40, UiStyle.GOLD if not done else Color(0.6, 1.0, 0.7), 3.0, true)
	var f := UiStyle.font()
	var fs := int(r * 1.1)
	var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := mid + Vector2(-w / 2.0, fs * 0.33)
	draw_string_outline(f, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(4, int(r * 0.18)), UiStyle.INK)
	draw_string(f, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	# A badge on the bottom right: a star for a quest on the go, a tick once it's done
	var b := mid + Vector2(r * 0.68, r * 0.68)
	var br := r * 0.3
	draw_circle(b, br + 2.0, UiStyle.INK)
	draw_circle(b, br, UiStyle.GOLD if not done else Color(0.45, 0.85, 0.5))
	if done:
		draw_polyline(PackedVector2Array([b + Vector2(-br * 0.5, 0), b + Vector2(-br * 0.1, br * 0.4), b + Vector2(br * 0.55, -br * 0.45)]), UiStyle.INK, maxf(2.0, br * 0.25))
	else:
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + k * PI / 5
			pts.append(b + Vector2(cos(a), sin(a)) * br * (0.75 if k % 2 == 0 else 0.32))
		draw_colored_polygon(pts, Color(1, 1, 1))
