extends RefCounted

# Looks over everything on the screen right now and lists any words that are cut off (Hayden, 14 Nov 2026: "we need to
# check every single windowed text in the game and make sure nothing is getting cut off"). Used by tools/audit_ui.gd
# (every menu, card and popup, opened one by one) and tools/playthrough.gd (the whole story played through, watching
# the screen as it goes), so the same rules catch a window wherever it pops up.
#
# Something counts as cut off when:
#   - it pokes off the edge of the screen,
#   - its words need more room than their box has (taller than the box, or a single line wider than it),
#   - its words spill out past the edge of the window (panel) they sit in.
# A box inside a scroll list is only checked for what the list shows: past that it scrolls, and that's fine.

const SLACK := 2.0                         # pixels a box may go past an edge before it counts


static func scan(root: Node) -> Array[String]:
	var out: Array[String] = []
	var vp := (root as Viewport).get_visible_rect() if root is Viewport else root.get_viewport().get_visible_rect()
	for c in _controls(root):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size.x < 1 or ctl.size.y < 1 or _faded(ctl):
			continue
		var text := _text_of(ctl)
		var is_text := ctl is Label or ctl is Button or ctl is RichTextLabel
		if is_text and text.strip_edges() == "":
			continue
		if not (is_text or ctl is PanelContainer or ctl is Panel or ctl is TextureRect):
			continue
		var r := _screen_rect(ctl)
		var clip := _clip_rect(ctl)
		var seen := r.intersection(clip) if r.intersects(clip) else Rect2()
		if seen.size == Vector2.ZERO:
			continue                               # scrolled out of its box: that's fine, it scrolls
		var why := ""
		if seen.position.x < vp.position.x - SLACK or seen.position.y < vp.position.y - SLACK \
				or seen.end.x > vp.end.x + SLACK or seen.end.y > vp.end.y + SLACK:
			why = "off the screen"
		elif is_text and _too_small(ctl):
			var need := ctl.get_minimum_size()
			why = "words don't fit in their box (need %dx%d)" % [need.x, need.y]
		elif is_text:
			var win := _window_of(ctl)
			if win:
				var wr := _screen_rect(win).grow(SLACK)
				var inside := seen.intersection(clip)
				if not wr.encloses(inside):
					why = "spills out of its window"
		if why != "":
			var what := "%s %s" % [ctl.get_class(), _short_path(ctl)]
			if text != "":
				what += " \"%s\"" % text.left(40).replace("\n", " ")
			out.append("%s: %s [%d,%d %dx%d]" % [why, what, r.position.x, r.position.y, r.size.x, r.size.y])
	return out


static func _text_of(ctl: Control) -> String:
	if ctl is Label:
		return (ctl as Label).text
	if ctl is Button:
		return (ctl as Button).text
	if ctl is RichTextLabel:
		return (ctl as RichTextLabel).get_parsed_text()
	return ""


static func _too_small(ctl: Control) -> bool:
	# Words that need more room than they were given (a box that clips them, or lets them run over what's below)
	var scale := ctl.get_global_transform_with_canvas().get_scale().y
	if ctl is Label:
		var l := ctl as Label
		if l.visible_characters == 0 or l.max_lines_visible > 0:
			return false
		var need := l.get_minimum_size()
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
				and not l.clip_text:
			# One line per line of text: its width is part of its minimum size already
			return need.x > l.size.x + SLACK or need.y > l.size.y + SLACK
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			# Trimmed with "..." or clipped: compare the real width of the longest line with the box
			var font := l.get_theme_font("font")
			var fs := l.get_theme_font_size("font_size")
			for line in (l.text.to_upper() if l.uppercase else l.text).split("\n"):
				if font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > l.size.x + SLACK:
					return true
			return false
		return l.get_line_count() * l.get_line_height() > l.size.y + SLACK + 1
	if ctl is Button:
		# Just the words (and a picture beside them) against the button's inside: a button squeezed a little
		# shorter than its padding wants still shows its words fine
		var b := ctl as Button
		if b.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return b.get_minimum_size().y > b.size.y + SLACK + 1
		var font := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var w := 0.0
		for line in b.text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var sb := b.get_theme_stylebox("normal")
		var side := (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)) if sb else 0.0
		if b.icon and b.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER and b.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER:
			w += b.icon.get_width() + b.get_theme_constant("h_separation")
		return w + side > b.size.x + SLACK or font.get_height(fs) * b.text.split("\n").size() > b.size.y + SLACK
	if ctl is RichTextLabel:
		var rt := ctl as RichTextLabel
		if rt.scroll_active:
			return false                           # it scrolls
		return rt.get_content_height() > rt.size.y + SLACK + 1
	return false


static func _window_of(ctl: Control) -> Control:
	# The panel (window, card, banner) round some words, if any
	var p := ctl.get_parent()
	while p:
		if p is PanelContainer or p is Panel:
			return p as Control
		if p is CanvasLayer or p is Viewport:
			return null
		p = p.get_parent()
	return null


static func _faded(n: Node) -> bool:
	while n:
		if n is CanvasItem and (n as CanvasItem).modulate.a < 0.02:
			return true
		n = n.get_parent()
	return false


static func _short_path(n: Node) -> String:
	# The first few nodes down from the root, then the node's own name, so it can be found
	var parts := str(n.get_path()).split("/")
	if parts.size() <= 6:
		return "/".join(parts.slice(2))
	return "/".join(parts.slice(2, 5)) + "/.../" + parts[-1]


static func _screen_rect(ctl: Control) -> Rect2:
	var xf := ctl.get_global_transform_with_canvas()
	return xf * Rect2(Vector2.ZERO, ctl.size)


static func _clip_rect(ctl: Control) -> Rect2:
	# What a ScrollContainer (or any box that clips) round it lets you see; past that it scrolls and that's fine
	var clip := Rect2(-1e6, -1e6, 2e6, 2e6)
	var p := ctl.get_parent()
	while p:
		if (p is Control and ((p as Control).clip_contents or p is ScrollContainer)) \
				or (p is CanvasItem and (p as CanvasItem).clip_children != CanvasItem.CLIP_CHILDREN_DISABLED):
			var pr := _screen_rect(p)
			clip = clip.intersection(pr) if clip.intersects(pr) else Rect2()
		p = p.get_parent()
	return clip


static func _controls(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is CanvasLayer and not (c as CanvasLayer).visible:
			continue
		if c is SubViewport:
			continue                               # pictures drawn off screen (icons, the minimap's world)
		if c is Control:
			out.append(c)
		out.append_array(_controls(c))
	return out
